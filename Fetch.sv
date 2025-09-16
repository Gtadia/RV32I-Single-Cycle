import CORE_PKG::*;

module Fetch(
  // General Inputs
  input logic clock,
  input logic reset,
  input logic instr_gnt_ip,               // Input signal from DRAM to grant access

  // Inputs from Decode
  input pc_mux pc_mux_ip,
  input logic [31:0] pc_branch_offset_ip,

  // Inputs from ALU
  input logic [31:0] alu_result_ip,

  // Outputs to MEM
  output logic instr_req_op,              // Addr. signal sent is valid
  output logic [31:0] instr_addr_op,      // Addr. containing the instruction in memory to fetch

  // Outputs to decode
  output logic [31:0] next_instr_addr_op
);

  // Internal Signals
  logic [31:0] PC, Next_PC;               // need 8 bits to encode 0-255 for DRAM access but for 32 bit address

  assign Instr_or_Data_op = 0;            // drive low to inform memory that request if for instruction

  always_comb begin
    unique case (pc_mux_ip)
      NEXTPC: Next_PC = PC + 4;
      OFFSET: Next_PC = PC + pc_branch_offset_ip;
      default: Next_PC = PC;
    endcase
  end

  // When Test bench first loads, it won't execute 
  always_ff @(posedge clock) begin
    if (reset == 1'b1)
      PC <= 0;
    else
      PC <= Next_PC;
  end

  always_ff @(posedge clock) begin
    if (reset == 1'b1) begin
      instr_addr_op <= 0;
      next_instr_addr_op <= 0;
      instr_req_op <= 0;
    end
    else begin
      instr_addr_op <= Next_PC;
      instr_req_op <= 1;
      next_instr_addr_op <= Next_PC + 4;
    end
  end

endmodule