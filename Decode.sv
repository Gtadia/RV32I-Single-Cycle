import CORE_PKG::*;

module Decode (
  // General Inputs
  input logic clock,
  input logic reset,
  input logic [31:0] pc,
  input logic [31:0] pc4, 

  // Inputs from MEM
  input logic instr_data_valid_ip,            // If the instruction sent from MEM to decode is valid
  input logic [31:0] instr_data_ip,           // The instruction to deocde from the Fetch module

  // Inputs from ALU
  input logic [31:0] alu_result_ip,           // ALU result as calculation of operand a and b
  input logic alu_result_valid_ip,            // Validity of ALU result

  // Inputs from LSU
  input logic [31:0] mem_data_ip,              // Mem data from a load 
  input logic mem_data_valid_ip,               // Validity of Mem load data

  // Outputs to ALU
  output logic alu_en_op,
  output alu_opcode_e alu_operator_op,        // Selects the ALU operation to perform
  output logic [31:0] alu_operand_a_ex_op,    // First operand to ALU
  output logic [31:0] alu_operand_b_ex_op,    // Second operand to ALU

  // Outputs to LSU
  output logic en_lsu_op,
  output load_store_func_code lsu_operator_op,          // which type of load or stre instruction to execute

  // Outputs to MEM
  output logic [31:0] mem_wdata_op,

  // Outputs to Fetch for informing of Jump
  output logic [31:0] pc_branch_offset_op,
  output pc_mux pc_mux_op
);

  // Declare parameters to extract source and destination registers and immediate values
  localparam REG_S1_MSB = 19;
  localparam REG_S1_LSB = 15;

  localparam REG_S2_MSB = 24;
  localparam REG_S2_LSB = 20;

  localparam REG_DEST_MSB = 11;
  localparam REG_DEST_LSB = 7;

  localparam I_IMM_MSB = 31;
  localparam I_IMM_LSB = 20;

  localparam S_IMM_MSB = 31;
  localparam S_IMM_LSB = 25;
  localparam S_IMM_MSB_2 = 11;
  localparam S_IMM_LSB_2 = 7;

  logic [31:0] valid_instr_to_decode;

  // Inputs to RegFile Read ports to select data
  logic [4:0] regfile_read_addr_a_id;  // source register 1 based on MSB and LSB mask
  logic [4:0] regfile_read_addr_b_id;  // source register 2

  // Write Port to select which regfile
  logic [4:0] regfile_write_addr_a_id;

  // Reg File Outputs
  logic [31:0] regfile_a_out;
  logic [31:0] regfile_b_out;

  // Reg File Write enable
  write_back_mux_selector writeback_mux;
  logic regfile_write_data_valid;
  logic [31:0] regfile_write_data;

  // Mux to select values for operand 2 or source reg 1.
  operand_a_mux operand_a_select;

  // Mux to select which value to select as operand b or source reg 2. 
  operand_b_mux operand_b_select;

  assign valid_instr_to_decode = instr_data_valid_ip ? instr_data_ip : 32'bz;

  always @(*) begin
    alu_operator_op = ALU_NOP; // Default assignment

    operand_a_select = OPA_NOP;
    operand_b_select = OPB_NOP;

    writeback_mux = NO_WRITEBACK;
    mem_wdata_op = 32'bz;       // data to send to mem for store

    en_lsu_op = 1'b0;
    lsu_operator_op = LW; // Default Assignment. Fine as long as LSU is not enabled

    // PC Defaults
    pc_mux_op = NEXTPC;   // Set the PC Mux

    case(valid_instr_to_decode[6:0])

      OPCODE_OP: begin // Register-Register ALU operation
        operand_a_select = REG_A;
        operand_b_select = REG;
        writeback_mux = READ_ALU_RESULT;
        case({valid_instr_to_decode[31:25], valid_instr_to_decode[14:12]})
          10'b0000_000_000: alu_operator_op = ALU_ADD; // ADD
          10'b0100_000_000: alu_operator_op = ALU_SUB; // SUB
          10'b0000_000_010: alu_operator_op = ALU_SLTS; // SLT
        endcase
      end

      OPCODE_OPIMM: begin // Register-Immediate ALU operations
        operand_a_select = REG_A;
        operand_b_select = I_IMMD;
        writeback_mux = READ_ALU_RESULT;
        case(valid_instr_to_decode[14:12])
          3'b000: alu_operator_op = ALU_ADD; // ADDI
        endcase
      end

      OPCODE_JAL: begin // JAL instruction
        pc_mux_op = OFFSET;
        pc_branch_offset_op = $signed({valid_instr_to_decode[31], valid_instr_to_decode[19:12], valid_instr_to_decode[20], valid_instr_to_decode[30:21], 1'b0});

        // operand_a_select = PC;
        // operand_b_select = J_IMMD;
        writeback_mux = READ_PC4; // Write pc + 4 to rd
        // alu_operator_op = ALU_ADD; // ADD to calculate pc + 4
      end

      OPCODE_LOAD: begin
        /**
        * Control Signals to Specify for LOAD words.
        * Notice that there are a couple of different kinds of LOADs in RV32I, what differentiates them?
        */
        operand_a_select = REG_A;
        operand_b_select = I_IMMD;
        writeback_mux = READ_MEM_RESULT;
        case(valid_instr_to_decode[14:12])
          3'b010: begin
            alu_operator_op = ALU_ADD; // ADD to calculate address
            en_lsu_op = 1'b1;
            lsu_operator_op = LW; // Load Word
          end
        endcase
      end

      OPCODE_STORE: begin
        /**
        * Control Signals to Specify for STORE words.
        * Notice that there are a couple of different kinds of STOREs in RV32I, what differentiates them?
        */
        operand_a_select = REG_A;
        operand_b_select = S_IMMD;
        mem_wdata_op = regfile_b_out; // Data to store comes from source register 2
        case(valid_instr_to_decode[14:12])
          3'b010: begin
            alu_operator_op = ALU_ADD; // ADD to calculate address
            en_lsu_op = 1'b1;
            lsu_operator_op = SW; // Store Word
          end
        endcase

      end

    endcase
  end

  assign regfile_read_addr_a_id = valid_instr_to_decode[REG_S1_MSB:REG_S1_LSB];
  assign regfile_read_addr_b_id = valid_instr_to_decode[REG_S2_MSB:REG_S2_LSB];

  assign regfile_write_addr_a_id = valid_instr_to_decode[REG_DEST_MSB:REG_DEST_LSB];

  // Determine whether or not to enable the ALU
  assign alu_en_op = (alu_operator_op == ALU_NOP) ? 1'b0 : 1'b1;

  // Assign a and b operands to ALU 
  always @(*) begin
    case(operand_a_select)
      REG_A: alu_operand_a_ex_op = regfile_a_out;
      PC: alu_operand_a_ex_op = pc;
      PC4: alu_operand_b_ex_op = pc4;
      default: alu_operand_a_ex_op = 32'bz;
    endcase
  end

  always @(*) begin
    case(operand_b_select)
      REG: alu_operand_b_ex_op = regfile_b_out;
      I_IMMD: alu_operand_b_ex_op = $signed(valid_instr_to_decode[I_IMM_MSB:I_IMM_LSB]);
      S_IMMD: alu_operand_b_ex_op = $signed({valid_instr_to_decode[S_IMM_MSB:S_IMM_LSB], valid_instr_to_decode[S_IMM_MSB_2:S_IMM_LSB_2]});
      // J_IMMD: alu_operand_b_ex_op = $signed({valid_instr_to_decode[31], valid_instr_to_decode[19:12], valid_instr_to_decode[20], valid_instr_to_decode[30:21], 1'b0});
    endcase
  end
  // TODO — We handle the s_immd from the output of the registers (add s_immd_value to the output for rd_1)
  // Mux which data result to write back to memory if appropriate
  always_comb begin
    case (writeback_mux)
      // NO WRITE BACK FOR STORE!!!
      READ_ALU_RESULT: begin
        regfile_write_data_valid = alu_result_valid_ip;
        regfile_write_data = alu_result_ip;
      end
      READ_MEM_RESULT: begin
        /**
        * How do we write the result from the memory into the Register File for LOADs?
        */
        regfile_write_data_valid = mem_data_valid_ip;
        regfile_write_data = mem_data_ip; // TODO — check this...

      end
      READ_PC4: begin
        regfile_write_data_valid = 1'b1; // Always valid
        regfile_write_data = pc4;
      end
      default: begin
        regfile_write_data_valid = 1'b0;
        regfile_write_data = 32'hz;
      end
    endcase
  end

  Register_File #(
    .ADDR_WIDTH(5),
    .DATA_WIDTH(32)
  ) register_file (
    .clock(clock),
    .reset(reset),

    .raddr_a_ip(regfile_read_addr_a_id),
    .raddr_a_op(regfile_a_out),

    .raddr_b_ip(regfile_read_addr_b_id),
    .raddr_b_op(regfile_b_out),

    .waddr_a_ip(regfile_write_addr_a_id),
    .wdata_a_ip(regfile_write_data),
    .we_a_ip(regfile_write_data_valid)
  );

endmodule