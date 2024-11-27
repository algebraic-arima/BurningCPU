module regfile(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire clear,

    // from rob commit
    input wire commit_ready,
    input wire [4:0]  commit_reg_id,
    input wire [31:0] commit_val,
    input wire [`ROB_WIDTH-1:0] commit_rob_id,

    // to rob from rob, search reg val
    output wire [`ROB_WIDTH-1:0] search_rob_id_1,
    input wire search_ready_1,
    input wire [31:0] search_val_1,
    output wire [`ROB_WIDTH-1:0] search_rob_id_2,
    input wire search_ready_2,
    input wire [31:0] search_val_2,

    // from decoder issue
    input wire issue_reg_ready,
    input wire [4:0]  issue_reg_rd,
    input wire [`ROB_WIDTH-1:0] issue_rob_id,

    // to decoder, search reg val and dep
    input wire [4:0] get_reg_1,
    output wire [31:0] get_val_1,
    output wire has_dep_1,
    output wire [`ROB_WIDTH-1:0] get_dep_1,
    input wire [4:0] get_reg_2,
    output wire [31:0] get_val_2,
    output wire has_dep_2,
    output wire [`ROB_WIDTH-1:0] get_dep_2

);

    reg [31:0] val[0:31];
    reg [`ROB_WIDTH-1:0] dep[0:31];
    reg has_dep[0:31];

    assign search_rob_id_1 = get_dep_1;
    assign search_rob_id_2 = get_dep_2;
    assign get_val_1 = !has_dep[get_reg_1] ? val[get_reg_1] : search_ready_1 ? search_val_1 : 0;
    assign get_val_2 = !has_dep[get_reg_2] ? val[get_reg_2] : search_ready_2 ? search_val_2 : 0;
    assign get_dep_1 = dep[get_reg_1];
    assign get_dep_2 = dep[get_reg_2];
    assign has_dep_1 = has_dep[get_reg_1] && !search_ready_1;
    assign has_dep_2 = has_dep[get_reg_2] && !search_ready_2;

    always @(posedge clk_in) begin: Main
        integer i;
        val[0] <= 0;
        dep[0] <= 0;
        has_dep[0] <= 0;
        if (rst_in) begin
            for (i = 1; i < 32; i = i + 1) begin
                val[i] <= 0;
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end else if (!rdy_in) begin
        end else if (clear) begin
            for (i = 1; i < 32; i = i + 1) begin
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end else begin
            if (commit_reg_id != 0) begin
                val[commit_reg_id] <= commit_val;
            end
            if (issue_reg_ready && commit_ready) begin
                if (commit_reg_id == issue_reg_rd) begin
                    dep[issue_reg_rd] <= issue_rob_id;
                    has_dep[issue_reg_rd] <= 1;
                end else begin
                    dep[issue_reg_rd] <= issue_rob_id;
                    has_dep[issue_reg_rd] <= 1;
                    if (has_dep[commit_reg_id] && dep[commit_reg_id] == commit_rob_id) begin
                        dep[commit_reg_id] <= 0;
                        has_dep[commit_reg_id] <= 0;
                    end
                end
            end else if (issue_reg_ready) begin
                dep[issue_reg_rd] <= issue_rob_id;
                has_dep[issue_reg_rd] <= 1;
            end else if (commit_ready) begin
                if (has_dep[commit_reg_id] && dep[commit_reg_id] == commit_rob_id) begin
                    dep[commit_reg_id] <= 0;
                    has_dep[commit_reg_id] <= 0;
                end
            end
        end
    
    end
    
    wire [31:0] zero = val[0];
    wire [31:0] ra = val[1];
    wire [31:0] sp = val[2];
    wire [31:0] gp = val[3];
    wire [31:0] tp = val[4];
    wire [31:0] t0 = val[5];
    wire [31:0] t1 = val[6];
    wire [31:0] t2 = val[7];
    wire [31:0] s0 = val[8];
    wire [31:0] s1 = val[9];
    wire [31:0] a0 = val[10];
    wire [31:0] a1 = val[11];
    wire [31:0] a2 = val[12];
    wire [31:0] a3 = val[13];
    wire [31:0] a4 = val[14];
    wire [31:0] a5 = val[15];
    wire [31:0] a6 = val[16];
    wire [31:0] a7 = val[17];
    wire [31:0] s2 = val[18];
    wire [31:0] s3 = val[19];
    wire [31:0] s4 = val[20];
    wire [31:0] s5 = val[21];
    wire [31:0] s6 = val[22];
    wire [31:0] s7 = val[23];
    wire [31:0] s8 = val[24];
    wire [31:0] s9 = val[25];
    wire [31:0] s10 = val[26];
    wire [31:0] s11 = val[27];
    wire [31:0] t3 = val[28];
    wire [31:0] t4 = val[29];
    wire [31:0] t5 = val[30];
    wire [31:0] t6 = val[31];

    wire [`ROB_WIDTH-1:0] zero_dep = dep[0];
    wire [`ROB_WIDTH-1:0] ra_dep = dep[1];
    wire [`ROB_WIDTH-1:0] sp_dep = dep[2];
    wire [`ROB_WIDTH-1:0] gp_dep = dep[3];
    wire [`ROB_WIDTH-1:0] tp_dep = dep[4];
    wire [`ROB_WIDTH-1:0] t0_dep = dep[5];
    wire [`ROB_WIDTH-1:0] t1_dep = dep[6];
    wire [`ROB_WIDTH-1:0] t2_dep = dep[7];
    wire [`ROB_WIDTH-1:0] s0_dep = dep[8];
    wire [`ROB_WIDTH-1:0] s1_dep = dep[9];
    wire [`ROB_WIDTH-1:0] a0_dep = dep[10];
    wire [`ROB_WIDTH-1:0] a1_dep = dep[11];
    wire [`ROB_WIDTH-1:0] a2_dep = dep[12];
    wire [`ROB_WIDTH-1:0] a3_dep = dep[13];
    wire [`ROB_WIDTH-1:0] a4_dep = dep[14];
    wire [`ROB_WIDTH-1:0] a5_dep = dep[15];
    wire [`ROB_WIDTH-1:0] a6_dep = dep[16];
    wire [`ROB_WIDTH-1:0] a7_dep = dep[17];
    wire [`ROB_WIDTH-1:0] s2_dep = dep[18];
    wire [`ROB_WIDTH-1:0] s3_dep = dep[19];
    wire [`ROB_WIDTH-1:0] s4_dep = dep[20];
    wire [`ROB_WIDTH-1:0] s5_dep = dep[21];
    wire [`ROB_WIDTH-1:0] s6_dep = dep[22];
    wire [`ROB_WIDTH-1:0] s7_dep = dep[23];
    wire [`ROB_WIDTH-1:0] s8_dep = dep[24];
    wire [`ROB_WIDTH-1:0] s9_dep = dep[25];
    wire [`ROB_WIDTH-1:0] s10_dep = dep[26];
    wire [`ROB_WIDTH-1:0] s11_dep = dep[27];
    wire [`ROB_WIDTH-1:0] t3_dep = dep[28];
    wire [`ROB_WIDTH-1:0] t4_dep = dep[29];
    wire [`ROB_WIDTH-1:0] t5_dep = dep[30];
    wire [`ROB_WIDTH-1:0] t6_dep = dep[31];

    wire zero_has_dep = has_dep[0];
    wire ra_has_dep = has_dep[1];
    wire sp_has_dep = has_dep[2];
    wire gp_has_dep = has_dep[3];
    wire tp_has_dep = has_dep[4];
    wire t0_has_dep = has_dep[5];
    wire t1_has_dep = has_dep[6];
    wire t2_has_dep = has_dep[7];
    wire s0_has_dep = has_dep[8];
    wire s1_has_dep = has_dep[9];
    wire a0_has_dep = has_dep[10];
    wire a1_has_dep = has_dep[11];
    wire a2_has_dep = has_dep[12];
    wire a3_has_dep = has_dep[13];
    wire a4_has_dep = has_dep[14];
    wire a5_has_dep = has_dep[15];
    wire a6_has_dep = has_dep[16];
    wire a7_has_dep = has_dep[17];
    wire s2_has_dep = has_dep[18];
    wire s3_has_dep = has_dep[19];
    wire s4_has_dep = has_dep[20];
    wire s5_has_dep = has_dep[21];
    wire s6_has_dep = has_dep[22];
    wire s7_has_dep = has_dep[23];
    wire s8_has_dep = has_dep[24];
    wire s9_has_dep = has_dep[25];
    wire s10_has_dep = has_dep[26];
    wire s11_has_dep = has_dep[27];
    wire t3_has_dep = has_dep[28];
    wire t4_has_dep = has_dep[29];
    wire t5_has_dep = has_dep[30];
    wire t6_has_dep = has_dep[31];

endmodule