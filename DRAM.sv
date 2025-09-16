import CORE_PKG::*;

module DRAM (
  // General Inputs
  input logic clock,
  input logic mem_en,

  // Inputs from LSU
  input logic data_req_ip,                    // Validity fo data addr sent from LSU 

  // Inputs from Fetch
  input logic instr_req_ip,                   // Validity of instr. addr sent from Fetch
  input logic [31:0] instr_addr_ip,           // Addr. in memory holding desired/speculated instruction. Multiples of 4

  // Input from ALU
  input logic [31:0] data_addr_ip,            // Address calcualted from MEM for memory access

  // Inputs from Decode
  input logic [31:0] wdata_ip,                // data to store into memory by a store instruction
  input load_store_func_code lsu_operator,

  // Module Outputs
  output logic mem_gnt_op,                    // DRAM is ready to output instruction data to decode (sent to Fetch Unit)

  // Outputs to Decode
  output logic instr_valid_op,                // Validity of the fetch instr. data output
  output logic [31:0] instr_data_op,          // Read instruction sent to decode 
  output logic [31:0] load_data_op            // Data to send to LSU for a load instr.
);

  // Static parameters to set memory during compile time
  localparam PARAM_MEM_length = 1024;
  localparam data_addr = 512;

  // Declare Byte Addressed DRAM
  logic [7:0] data_RAM [0:PARAM_MEM_length-1];

  // Big Endian variation since the MSB bit (bits 31) is stored at the lowest address
  // Not Synthesizable but for simulation, create a RAM memory system for access and writes
  initial begin
    for (int i = 0; i < PARAM_MEM_length; i++) 
      data_RAM[i] = 0; //initialize the RAM with all zeros
  end

  // Signal to Fetch Unit that memory is ready or not
  assign mem_gnt_op = mem_en ? 1 : 0;

  // Read Addr. Port 1 for instruction data
  always @ (*) begin
    case ({mem_en, instr_req_ip})
      3'b10:  begin
                  // only 00 if reset is high else either in 10 or 01 state
                  instr_valid_op = 0;
                  instr_data_op = 32'bz;
              end
      3'b11:  begin
                instr_valid_op = 1'b1;
                instr_data_op = { 
                  data_RAM[instr_addr_ip], 
                  data_RAM[instr_addr_ip+1],
                  data_RAM[instr_addr_ip+2],
                  data_RAM[instr_addr_ip+3]
                };
              end
      default: begin
                instr_valid_op = 0;
                instr_data_op = 32'bz;
              end
    endcase
  end

  // Read Addr. Port 2 for load data
  always @(*) begin
    if (data_req_ip == 1'b1) begin
      // address is aligned so can just read directly by adding
      case (lsu_operator)
        LW: begin
          load_data_op[31:24] = data_RAM[data_addr + data_addr_ip];
          load_data_op[23:16] = data_RAM[data_addr + data_addr_ip + 1];
          load_data_op[15:8] = data_RAM[data_addr + data_addr_ip + 2];
          load_data_op[7:0] = data_RAM[data_addr + data_addr_ip + 3];
        end
        default: 
          load_data_op[31:8] = 32'bz;
      endcase
    end
  end

  // Read Addr. Port 2 for store data and addresses
  always @(posedge clock) begin
    if (data_req_ip == 1'b1) begin
      // addr. is aligned so can just read and write data
      case (lsu_operator)
        SW: begin
          data_RAM[data_addr + data_addr_ip] = wdata_ip[31:24];
          data_RAM[data_addr + data_addr_ip + 1] = wdata_ip[23:16];
          data_RAM[data_addr + data_addr_ip + 2] = wdata_ip[15:8];
          data_RAM[data_addr + data_addr_ip + 3] = wdata_ip[7:0];
        end
      endcase
    end
  end

endmodule