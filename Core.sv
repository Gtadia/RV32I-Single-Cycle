import CORE_PKG::*;

module Core (
	// Input signals
	input logic clock,
	input logic reset,
	input logic mem_en
);

	localparam INSTR_START_PC = 0;
	localparam DATA_START_PC = 127; 							// address that separates instruction from data

	//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// Signals and outputs
	//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	logic mem_gnt_req;														// Memory is ready to inputs. Sent to inputs of Fetch and LSU

	// Fetch Instruction Signals
	logic [31:0] instr_mem_addr;									// PC that gets sent to mem. Addr. of the instr. to fetch
	logic [31:0] next_instr_addr; 								// PC + 4
	logic [31:0] instr_mem_data;									// Instruction that memory loads out
	logic mem_instr_req_valid;										// Validity of the request sent to memory for instructions
	logic mem_instr_data_valid;										// Mem to decode to inform of validity of instruction data sent

	// Decode signals
	pc_mux pc_mux_select;													// Mux to select the address of the next instruction to execute
	logic [31:0] pc_branch_offset;								// Value of PC Address calculation needed for certain instructions

	// Load/Store Mem Signals
	logic [31:0] DRAM_wdata;
	logic [31:0] DRAM_load_mem_data;							// Data from DRAM after a load to sent to LSU for sign extensions and such
	logic [31:0] load_mem_data; 									// Data from LSU to Decode after a load instr.
	logic mem_data_req_valid;											// Validity of request sent to mem for store/load

	// ALU Signals 
	alu_opcode_e alu_operator;										// Operation that ALU should perform
	logic [31:0] alu_operand_a;										// A inputs of the ALU
	logic [31:0] alu_operand_b;										// B inputs of the ALU
	logic [31:0] alu_result;											// Result of the ALU operation
	logic alu_valid;															// If the result of the ALU operation is valid
	logic alu_en;																	// Enable the ALU

	// LSU Signals 
	load_store_func_code lsu_operator;						// Type of load/store instr. for LSU to interpret
	logic lsu_en;																	// Enable signal for the LSU

	Fetch FetchModule (
		// General Inputs
		.clock(clock),
		.reset(reset),
		.instr_gnt_ip(mem_gnt_req),

		// Inputs from Decode
		.pc_mux_ip(pc_mux_select),	// Done (1)
		.pc_branch_offset_ip(pc_branch_offset), // Done (2)

		// Inputs from ALU
		.alu_result_ip(alu_result),	// Done (3)

		// Outputs to MEM
		.instr_req_op(mem_instr_req_valid),		// Done (4)
		.instr_addr_op(instr_mem_addr),		    // Done (5)

		// Outputs to decode
		.next_instr_addr_op(next_instr_addr)		// Done (6)
	);

	Decode DecodeModule (
		// General Inputs
		.clock(clock),
		.reset(reset),
		.pc(instr_mem_addr),		// Done (5)
		.pc4(next_instr_addr),	// Done (6)

		// Inputs from MEM
		.instr_data_valid_ip(mem_instr_data_valid),		// Done (7)
		.instr_data_ip(instr_mem_data),						// Done (8)

		 // Inputs from ALU
		.alu_result_valid_ip(alu_valid),	// Done (9)
		.alu_result_ip(alu_result),		// Done (3)

		// Inputs from LSU
		.mem_data_ip(load_mem_data),	// Done (10)
		.mem_data_valid_ip(mem_data_req_valid),		// Done (11)

		// Outputs to ALU and Comparator
		.alu_operator_op(alu_operator),		// Done (12)
		.alu_en_op(alu_en),															// Done (13)
		.alu_operand_a_ex_op(alu_operand_a),		// Done (14)
		.alu_operand_b_ex_op(alu_operand_b),		// Done (15)

		// Outputs to LSU
		.en_lsu_op(lsu_en),													// Done (16)
		.lsu_operator_op(lsu_operator),							// Done (17)

		// Outputs to MEM
		.mem_wdata_op(DRAM_wdata),					// Done (18)

		// Outputs to Fetch
		.pc_branch_offset_op(pc_branch_offset),	// Done (2)
		.pc_mux_op(pc_mux_select)	// Done (1)
	);

	ALU ALUModule (
		// General Inputs
		.reset(reset),

		// Inputs from decode
		.alu_enable_ip(alu_en),			// Done (13)
		.alu_operator_ip(alu_operator),		// Done (12)
		.alu_operand_a_ip(alu_operand_a),		// Done (14)
		.alu_operand_b_ip(alu_operand_b),	// Done (15)

		// Outputs to LSU, MEM, and Fetch (and Decode)
		.alu_result_op(alu_result),		// Done (3)
		.alu_valid_op(alu_valid)		// Done (9)
	);

	LSU LoadStoreUnit (
		// General Inputs
		.clock(clock),
		.reset(reset),
		.data_gnt_i(mem_gnt_req),

		// Inputs from Decode
		.lsu_en_ip(lsu_en),		// Done (16)
		.lsu_operator_ip(lsu_operator),					// Done (17)

		// Inputs from ALU
		.alu_valid_ip(alu_valid),	// Done (9)
		.mem_addr_ip(alu_result),	// Done (3)

		// Inputs from DRAM
		.mem_data_ip(DRAM_load_mem_data),   // Done (19)

		// Output to Decode
		.data_req_op(mem_data_req_valid),	// Done (11)
		.load_mem_data_op(load_mem_data)	// Done (10)
	);

	DRAM MainMemory (
		// General Inputs
		.mem_en(mem_en),
		.clock(clock),
		
		// Inputs from LSU
		.data_req_ip(mem_data_req_valid),		// Done (11)

		// Inputs from Fetch
		.instr_req_ip(mem_instr_req_valid),		// Done (4)
		.instr_addr_ip(instr_mem_addr),			// Done (5)

		// Inputs from Decode
		.lsu_operator(lsu_operator),			// Done (17)
		.wdata_ip(DRAM_wdata),						// Done (18)

		// Inputs from ALU
		.data_addr_ip(alu_result),	// Done (3)

		//Outputs 
		.mem_gnt_op(mem_gnt_req),

		// Outputs to Decode
		.instr_valid_op(mem_instr_data_valid),		// Done (7)
		.instr_data_op(instr_mem_data),					// Done (8)
		.load_data_op(DRAM_load_mem_data)		// Done (19)
	);

endmodule