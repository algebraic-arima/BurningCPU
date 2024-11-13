`include "params.v"

module decoder(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire clear,
    input [31:0] new_inst_addr,
    input wire freeze,

    // from to memctrl
    output wire if_enable,
    output wire [31:0] if_addr,
    input wire inst_ready,
    input wire [31:0] inst, // current instruction

    // from rob
    input wire rob_full,
    input wire [`ROB_WIDTH-1:0] empty_rob_id,
    input wire [31:0] corr_inst_addr, // pc_bus
    // to rob
    output wire rob_issue_ready,
    output wire [31:0] rob_inst_addr,
    output wire [31:0] rob_jump_addr,
    output wire [2:0] rob_type,
    output wire [7:0] rob_op,
    output wire [4:0] rob_rd,
    output wire [31:0] rob_val,// for branch, true jump addr; for others, the value of rd
    
    // from rs
    input wire rs_full,
    // to rs
    output wire rs_issue_ready,
    output wire [2:0] rs_type,
    output wire [7:0] rs_op,
    output wire [31:0] rs_val_j,
    output wire [31:0] rs_val_k,
    output wire rs_has_dep_j,
    output wire rs_has_dep_k,
    output wire [`ROB_WIDTH-1:0] rs_dep_j,
    output wire [`ROB_WIDTH-1:0] rs_dep_k,
    output wire [`ROB_WIDTH-1:0] rs_rob_id,

    // from lsb
    input wire lsb_full,
    // to lsb
    output wire lsb_issue_ready,
    output wire [2:0] lsb_type,
    output wire [7:0] lsb_op,
    output wire [31:0] lsb_val_j,
    output wire [31:0] lsb_val_k,
    output wire lsb_has_dep_j,
    output wire lsb_has_dep_k,
    output wire [`ROB_WIDTH-1:0] lsb_dep_j,
    output wire [`ROB_WIDTH-1:0] lsb_dep_k,
    output wire [`ROB_WIDTH-1:0] lsb_rob_id,
    output wire [31:0] lsb_imm,

    // search regfile
    output wire [4:0] get_reg_1,
    output wire [4:0] get_reg_2,
    input wire [31:0] get_val_1,
    input wire [31:0] get_val_2,
    input wire has_dep_1,
    input wire has_dep_2,
    input wire [`ROB_WIDTH-1:0] get_dep_1,
    input wire [`ROB_WIDTH-1:0] get_dep_2

);

    reg freezed;
    reg [31:0] inst_addr; // the addr next inst

    wire [6:0] op_code = inst[6:0];
    wire [4:0] rd = inst[11:7];
    wire [3:0] op_type = {inst[30], inst[14:12]};
    wire [4:0] rs1 = inst[19:15];
    wire [4:0] rs2 = inst[24:20];
    wire [31:12] imm_u = inst[31:12];
    wire [20:1] imm_j = {inst[31], inst[19:12], inst[20], inst[30:21]};
    wire [11:0] imm_i = inst[31:20];
    wire [12:1] imm_b = {inst[31], inst[7], inst[30:25], inst[11:8]};
    wire [11:0] imm_s = {inst[31:25], inst[11:7]};
    wire [4:0] shamt = inst[24:20];

    reg [31:0] rs1_val;
    reg [31:0] rs2_val;
    reg rs1_has_dep, rs2_has_dep;
    reg [`ROB_WIDTH-1:0] rs1_dep, rs2_dep;

    assign get_reg_1 = rs1;
    assign get_reg_2 = rs2;
    
    assign rs_val_j = rs1_val;
    assign rs_val_k = rs2_val;
    assign rs_has_dep_j = rs1_has_dep;
    assign rs_has_dep_k = rs2_has_dep;
    assign rs_dep_j = rs1_dep;
    assign rs_dep_k = rs2_dep;
    assign rs_rob_id = empty_rob_id;

    assign lsb_val_j = rs1_val;
    assign lsb_val_k = rs2_val;
    assign lsb_has_dep_j = rs1_has_dep;
    assign lsb_has_dep_k = rs2_has_dep;
    assign lsb_dep_j = rs1_dep;
    assign lsb_dep_k = rs2_dep;
    assign lsb_rob_id = empty_rob_id;

    always @(posedge clk_in) begin: Main
        if (rst_in) begin
            
        end
    end




endmodule
