module decoder(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire clear,

    input [31:0] new_inst_addr,
    input wire melt,

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
    output reg rob_issue_ready,
    output reg [31:0] rob_inst_addr,
    output reg [31:0] rob_jump_addr, // next jump addr
    output reg [1:0] rob_type,
    output reg [4:0] rob_rd,

    // from rs
    input wire rs_full,
    // to rs
    output reg rs_issue_ready,
    output reg [4:0] rs_type,
    output wire [31:0] rs_val_j,
    output wire [31:0] rs_val_k,
    output wire rs_has_dep_j,
    output wire rs_has_dep_k,
    output wire [`ROB_WIDTH-1:0] rs_dep_j,
    output wire [`ROB_WIDTH-1:0] rs_dep_k,
    output wire [`ROB_WIDTH-1:0] rs_rob_id,
    output reg [31:0] rs_true_addr,
    output reg [31:0] rs_false_addr,

    // from lsb
    input wire lsb_full,
    // to lsb
    output reg lsb_issue_ready,
    output reg [3:0] lsb_type,
    output wire [31:0] lsb_val_j,
    output wire [31:0] lsb_val_k,
    output wire lsb_has_dep_j,
    output wire lsb_has_dep_k,
    output wire [`ROB_WIDTH-1:0] lsb_dep_j,
    output wire [`ROB_WIDTH-1:0] lsb_dep_k,
    output wire [`ROB_WIDTH-1:0] lsb_rob_id,
    output reg [31:0] lsb_imm,

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

    localparam lui = 7'b0110111;
    localparam auipc = 7'b0010111;
    localparam jal = 7'b1101111;    
    localparam jalr = 7'b1100111;
    localparam b = 7'b1100011;
    localparam l = 7'b0000011;
    localparam s = 7'b0100011;
    localparam im = 7'b0010011;
    localparam r = 7'b0110011;    

    reg freezed;
    reg [31:0] last_inst;
    reg [31:0] inst_addr = 0; // the addr of cur inst
    wire [31:0] next_addr; // the addr of next inst

    wire [6:0] op_code = inst[6:0];
    wire [4:0] rd = inst[11:7];
    wire [3:0] op_type = inst[14:12];
    wire [4:0] rs1 = inst[19:15];
    wire [4:0] rs2 = inst[24:20];
    wire [31:0] imm_u = {inst[31:12], 12'b0};
    wire [20:0] imm_j = {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
    wire [11:0] imm_i = inst[31:20];
    wire [12:0] imm_b = {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    wire [11:0] imm_s = {inst[31:25], inst[11:7]};

    wire push_rs, push_lsb;

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

    assign push_rs = !push_lsb;
    assign push_lsb = op_code == l || op_code == s;
    assign work_enable = !freezed && !rob_full && !rs_full && !lsb_full;

    wire j = 1'b1;
    assign next_addr = clear ? new_inst_addr : (!inst_ready) ? inst_addr : (op_code == jal ? inst_addr + imm_j : (op_code == b && j) ? inst_addr + imm_b : inst_addr + 4);
    // always predict jump

    assign if_enable = (inst_ready) && work_enable;
    assign if_addr = next_addr;

    always @(posedge clk_in) begin: Main
        if (rst_in) begin
            freezed <= 0;
            rs1_val <= 0;
            rs2_val <= 0;
            rs1_has_dep <= 0;
            rs2_has_dep <= 0;
            rs1_dep <= 0;
            rs2_dep <= 0;
            last_inst <= 0;
            inst_addr <= 0;
        end else if (rdy_in && clear) begin
            freezed <= 0;
            // clear will cause memctrl to pause
            inst_addr <= corr_inst_addr;
        end else if (inst_ready) begin
            inst_addr <= next_addr;

            rob_issue_ready <= 1;
            rs_issue_ready <= push_rs;
            lsb_issue_ready <= push_lsb;

            rob_inst_addr <= inst_addr;
            rob_jump_addr <= next_addr;
            rob_type <= op_code == jalr ? 2'b10 : op_code == s ? 2'b01 : op_code == b ? 2'b00 : 2'b11;
            rob_rd <= rd;

            if (op_code == b) begin
                rs_type <= {2'b10, op_type};
            end else if (op_code == im) begin
                rs_type <= {2'b00, op_type};
                // the inst[30] = 1 in shamt(imm) is handled by alu
            end else if (op_code == r) begin
                rs_type <= {1'b0, inst[30], op_type};
            end else begin
                rs_type <= 5'b00000;
            end
            lsb_type <= {op_code == s ? 1'b1 : 1'b0, op_type};

            rs1_val <= op_code == lui ? 0 : (op_code == auipc || op_code == jal) ? inst_addr : get_val_1;
            rs2_val <= (op_code == lui || op_code == auipc) ? imm_u : (op_code == jal) ? imm_j : (op_code == jalr || op_code == l || op_code == im) ? imm_i : get_val_2;
            rs1_has_dep <= (op_code == lui || op_code == auipc || op_code == jal) ? 0 : has_dep_1;
            rs2_has_dep <= (op_code == b || op_code == s || op_code == r) ? has_dep_2 : 0;
            rs1_dep <= get_dep_1;
            rs2_dep <= get_dep_2;
            if (op_code == b) begin
                rs_true_addr <= inst_addr + imm_b;
                rs_false_addr <= inst_addr + 4;
            end
            if (op_code == s) begin
                lsb_imm <= imm_s;
            end
        end
    end

endmodule
