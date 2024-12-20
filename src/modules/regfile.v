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

    // from decoder issue
    input wire issue_reg_ready,
    input wire [4:0]  issue_reg_rd,
    input wire [`ROB_WIDTH-1:0] issue_rob_id,

    // from decoder, search regfile
    input wire has_dep_1,
    input wire [4:0] get_reg_1,
    input wire [31:0] val_1,
    input wire has_dep_2,
    input wire [4:0] get_reg_2,
    input wire [31:0] val_2,

    // to rob, search reg val
    output wire search_has_dep_1,
    output wire [`ROB_WIDTH-1:0] search_rob_id_1,
    output wire [31:0] tmp_val_1,
    output wire search_has_dep_2,
    output wire [`ROB_WIDTH-1:0] search_rob_id_2,
    output wire [31:0] tmp_val_2

);

    reg [31:0] val[0:31];
    reg [`ROB_WIDTH-1:0] dep[0:31];
    reg has_dep[0:31];

    assign search_rob_id_1 = dep[get_reg_1];
    assign search_rob_id_2 = dep[get_reg_2];

    wire commit_hit1 = commit_ready && commit_rob_id == dep[get_reg_1];
    wire commit_hit2 = commit_ready && commit_rob_id == dep[get_reg_2];
    
    wire [31:0] get_val_1 = !has_dep[get_reg_1] ? val[get_reg_1] : commit_hit1 ? commit_val : 0;
    wire [31:0] get_val_2 = !has_dep[get_reg_2] ? val[get_reg_2] : commit_hit2 ? commit_val : 0;

    assign search_has_dep_1 = has_dep_1 && has_dep[get_reg_1] && !commit_hit1;
    assign search_has_dep_2 = has_dep_2 && has_dep[get_reg_2] && !commit_hit2;
    
    assign tmp_val_1 = !has_dep_1 ? val_1 : get_val_1;
    assign tmp_val_2 = !has_dep_2 ? val_2 : get_val_2;

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
            if ((issue_reg_ready && issue_reg_rd != 0) && (commit_ready && commit_reg_id != 0)) begin
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
            end else if (issue_reg_ready && issue_reg_rd != 0) begin
                dep[issue_reg_rd] <= issue_rob_id;
                has_dep[issue_reg_rd] <= 1;
            end else if (commit_ready && commit_reg_id != 0) begin
                if (has_dep[commit_reg_id] && dep[commit_reg_id] == commit_rob_id) begin
                    dep[commit_reg_id] <= 0;
                    has_dep[commit_reg_id] <= 0;
                end
            end
        end
    end    
    
endmodule