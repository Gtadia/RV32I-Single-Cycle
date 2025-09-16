import CORE_PKG::*;

module ALU (
  // General Inputs
  input logic reset,

  // Inputs from decode
  input logic alu_enable_ip,
  input alu_opcode_e alu_operator_ip,
  input logic [31:0] alu_operand_a_ip,
  input logic [31:0] alu_operand_b_ip,

  // Outputs to LSU, MEM, and Fetch
  output logic [31:0] alu_result_op,
  output logic alu_valid_op
);

  always_comb begin
    case(alu_operator_ip) 
      ALU_ADD: begin
        alu_result_op = alu_operand_a_ip + alu_operand_b_ip;
        alu_valid_op = 1;
      end
      ALU_SUB: begin
        alu_result_op = alu_operand_a_ip - alu_operand_b_ip;
        alu_valid_op = 1;
      end
      ALU_SLTS: begin
        alu_result_op = ($signed(alu_operand_a_ip) < $signed(alu_operand_b_ip)) ? 1'b1 : 1'b0;
        alu_valid_op = 1;
      end
      default: begin
        alu_result_op = 0;
        alu_valid_op = 0;
      end
    endcase
  end


endmodule
