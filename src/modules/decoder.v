module decoder(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire clear,

    input wire melt,

    // from to memctrl
    output wire if_enable,
    output wire [31:0] if_addr,
    input wire inst_ready,
    input wire is_c,
    input wire [31:0] inst_val, // current instruction

    // to reg
    output reg reg_issue_ready,
    output reg [4:0] reg_rd,
    output wire [`ROB_WIDTH-1:0] reg_rob_id,

    // from rob
    input wire rob_full,
    input wire [`ROB_WIDTH-1:0] empty_rob_id,
    input wire [31:0] corr_jump_addr, // pc_bus
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
    output reg [31:0] lsb_imm,  // only for store

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
    wire [31:0] c_inst_val;
    wire [31:0] inst = is_c ? c_inst_val : inst_val;

    wire [6:0] op_code = inst[6:0];
    wire [4:0] rd = inst[11:7];
    wire [2:0] op_type = inst[14:12];
    wire [4:0] rs1 = inst[19:15];
    wire [4:0] rs2 = inst[24:20];
    wire [31:0] imm_u = {inst[31:12], 12'b0};
    wire [31:0] imm_j = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
    wire [31:0] imm_b = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};

    wire [1:0] c_op_code = inst_val[1:0];
    wire [2:0] c_funct3 = inst_val[15:13];
    wire c_funct_flag = inst_val[12];
    wire [1:0] c_funct2 = inst_val[11:10];
    wire [1:0] c_op_type = inst_val[6:5];
    wire [11:0] c_lsw_uimm = {5'b00000, inst_val[5], inst_val[12:10], inst_val[6], 2'b00};
    wire [11:0] c_lwsp_uimm = {4'b0000, inst_val[3:2], inst_val[12], inst_val[6:4], 2'b00};
    wire [11:0] c_swsp_uimm = {4'b0000, inst_val[8:7], inst_val[12:9], 2'b00};
    wire [11:0] c_addi_nzimm = {{7{inst_val[12]}}, inst_val[6:2]};
    wire [12:0] c_b_offset = {{4{inst_val[12]}}, inst_val[6:5], inst_val[2], inst_val[11:10], inst_val[4:3], 1'b0};
    wire [20:0] c_j_offset = {{10{inst_val[12]}}, inst_val[8], inst_val[10:9], inst_val[6], inst_val[7], inst_val[2], inst_val[11], inst_val[5:3], 1'b0};
    wire [4:0] c_rs1 = inst_val[11:7];
    wire [4:0] c_rs2 = inst_val[6:2];
    wire [4:0] c_rs1_p = {2'b01, inst_val[9:7]};
    wire [4:0] c_rs2_p = {2'b01, inst_val[4:2]}; 

    assign c_inst_val = 
                    (c_op_code == 2'b00) ? (
                        (c_funct3 == 3'b000) ? {2'b00, inst_val[10:7], inst_val[12:11], inst_val[5], inst_val[6], 2'b00, 5'b00010, 3'b000, c_rs2_p, im} :
                        (c_funct3 == 3'b010) ? {c_lsw_uimm, c_rs1_p, 3'b010, c_rs2_p, l} :
                        (c_funct3 == 3'b110) ? {c_lsw_uimm[11:5], c_rs2_p, c_rs1_p, 3'b010, c_lsw_uimm[4:0], s} :
                        0
                    ) :
                    (c_op_code == 2'b01) ? (
                        (c_funct3 == 3'b000) ? {c_addi_nzimm, c_rs1_p, 3'b000, c_rs1, im} :
                        (c_funct3 == 3'b001) ? {c_j_offset[20], c_j_offset[10:1], c_j_offset[11], c_j_offset[19:12], 5'b1, jal} :
                        (c_funct3 == 3'b010) ? {c_addi_nzimm, 5'b000, 3'b000, c_rs1, im} :
                        (c_funct3 == 3'b011) ? (
                            (c_rs1 == 5'b00010) ? {{3{inst_val[12]}}, inst_val[4:3], inst_val[5], inst_val[2], inst_val[6], 4'b0000, 5'b00010, 3'b000, 5'b00010, im} :
                            {8'b0, c_addi_nzimm, c_rs1, lui}
                        ) :
                        (c_funct3 == 3'b100) ? (
                            (c_funct2 == 2'b00) ? {7'b0, inst_val[6:2], c_rs1_p, 3'b101, c_rs1_p, im} :
                            (c_funct2 == 2'b01) ? {7'b0100000, inst_val[6:2], c_rs1_p, 3'b101, c_rs1_p, im} :
                            (c_funct2 == 2'b10) ? {c_addi_nzimm, c_rs1_p, 3'b111, c_rs1_p, im} :
                            (c_funct2 == 2'b11) ? (
                                (c_op_type == 2'b00) ? {7'b0100000, c_rs2_p, c_rs1_p, 3'b000, c_rs1_p, r} :
                                (c_op_type == 2'b01) ? {7'b0, c_rs2_p, c_rs1_p, 3'b100, c_rs1_p, im} :
                                (c_op_type == 2'b10) ? {7'b0, c_rs2_p, c_rs1_p, 3'b110, c_rs1_p, im} :
                                {7'b0, c_rs2_p, c_rs1_p, 3'b111, c_rs1_p, im}
                            ) :
                            0
                        ) :
                        (c_funct3 == 3'b101) ? {c_j_offset[20], c_j_offset[10:1], c_j_offset[11], c_j_offset[19:12], 5'b0, jal} :
                        (c_funct3 == 3'b110) ? {c_b_offset[12], c_b_offset[10:5], 5'b0, c_rs1_p, 3'b000, c_b_offset[4:1], c_b_offset[11], b} :
                        (c_funct3 == 3'b111) ? {c_b_offset[12], c_b_offset[10:5], 5'b0, c_rs1_p, 3'b001, c_b_offset[4:1], c_b_offset[11], b} :
                        0
                    ) :
                    (c_op_code == 2'b10) ? (
                        (c_funct3 == 3'b000) ? {7'b0, inst_val[6:2], c_rs1, 3'b001, c_rs1, im} :
                        (c_funct3 == 3'b010) ? {c_lwsp_uimm, 5'b00010, 3'b010, c_rs2, l} :
                        (c_funct3 == 3'b100) ? (
                            (!c_funct_flag) ? (
                                (c_rs2 == 5'b0) ? {12'b0, c_rs1, 3'b000, 5'b0, jalr} :
                                {7'b0, c_rs2, 5'b0, 3'b000, c_rs1, r}
                            ) :
                            (
                                (c_rs2 == 5'b0) ? {12'b0, c_rs1, 3'b000, 5'b1, jalr} :
                                {7'b0, c_rs2, c_rs1, 3'b000, c_rs1, r}
                            )
                        ) :
                        (c_funct3 == 3'b110) ? {c_swsp_uimm[11:5], c_rs2, 5'b00010, 3'b010, c_swsp_uimm[4:0], s} :
                        0
                    ) :
                    0;


    wire push_rs, push_lsb;

    reg [31:0] rs1_val;
    reg [31:0] rs2_val;
    reg rs1_has_dep, rs2_has_dep;
    reg [`ROB_WIDTH-1:0] rs1_dep, rs2_dep;

    reg working;

    assign get_reg_1 = rs1;
    assign get_reg_2 = rs2;

    assign reg_rob_id = empty_rob_id;
    
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

    assign push_reg_dep = !(op_code == s || op_code == b);
    assign push_rs = !push_lsb;
    assign push_lsb = op_code == l || op_code == s;
    assign work_enable = !freezed && !rob_full && !rs_full && !lsb_full;

    wire j = 1'b1;
    assign next_addr = clear ? corr_jump_addr : (!inst_ready) ? inst_addr : (op_code == jal ? inst_addr + imm_j : (op_code == b && j) ? inst_addr + imm_b : (is_c ? inst_addr + 2 : inst_addr + 4));
    // always predict jump

    assign if_enable = work_enable && !(inst_ready && op_code == jalr);
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
            reg_issue_ready <= 0;
            reg_rd <= 0;

            rob_issue_ready <= 0;
            rob_inst_addr <= 0;
            rob_jump_addr <= 0;
            rob_type <= 2'b00;
            rob_rd <= 5'b00000;

            rs_issue_ready <= 0;
            rs_type <= 5'b0;
            rs_true_addr <= 0;
            rs_false_addr <= 0;

            lsb_issue_ready <= 0;
            lsb_type <= 4'b0;
            lsb_imm <= 0;
            
            working <= 0;
        end else if (rdy_in && clear) begin
            working <= 0;
            rob_issue_ready <= 0;
            // clear will cause memctrl to pause
            inst_addr <= corr_jump_addr;
        end else if (inst_ready) begin
            working <= 1;
            freezed <= 0;
            inst_addr <= next_addr;
            reg_issue_ready <= push_reg_dep;
            rob_issue_ready <= 1;
            rs_issue_ready <= push_rs;
            lsb_issue_ready <= push_lsb;

            reg_rd <= rd;

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
            rs2_val <= (op_code == lui || op_code == auipc) ? imm_u : (op_code == jal) ? is_c ? 2 : 4 : (op_code == jalr || op_code == l || op_code == im) ? imm_i : get_val_2;
            rs1_has_dep <= (op_code == lui || op_code == auipc || op_code == jal) ? 0 : has_dep_1;
            rs2_has_dep <= (op_code == b || op_code == s || op_code == r) ? has_dep_2 : 0;
            rs1_dep <= get_dep_1;
            rs2_dep <= get_dep_2;
            if (op_code == b) begin
                rs_true_addr <= inst_addr + imm_b;
                rs_false_addr <= inst_addr + 4;
            end else begin
                rs_true_addr <= 0;
                rs_false_addr <= 0;
            end
            if (op_code == s) begin
                lsb_imm <= imm_s;
            end else begin
                lsb_imm <= 0;
            end
            if (op_code == jalr) begin
                freezed <= 1;
            end
        end else if (melt) begin
            freezed <= 0;
            inst_addr <= corr_jump_addr;
        end else begin
            reg_issue_ready <= 0;
            rob_issue_ready <= 0;
            rs_issue_ready <= 0;
            lsb_issue_ready <= 0;
        end
    end

endmodule
