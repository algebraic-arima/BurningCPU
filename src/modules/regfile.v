module regfile(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire clear,

    // from rob commit
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

    // from issue
    input wire [4:0]  issue_reg_id,
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
    reg [`ROB_WIDTH-1:0] has_dep[0:31];

    assign search_rob_id_1 = get_dep_1;
    assign search_rob_id_2 = get_dep_2;
    assign get_val_1 = has_dep_1 ? search_val_1 : val[get_reg_1];
    assign get_val_2 = has_dep_2 ? search_val_2 : val[get_reg_2];
    assign get_dep_1 = dep[get_reg_1];
    assign get_dep_2 = dep[get_reg_2];
    assign has_dep_1 = has_dep[get_reg_1] && !search_ready_1;
    assign has_dep_2 = has_dep[get_reg_2] && !search_ready_2;

    always @(posedge clk_in) begin: Main
        integer i;
        if (rst_in) begin
            for (i = 0; i < 32; i = i + 1) begin
                val[i] <= 0;
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end else if (!rdy_in) begin
        end else if (clear) begin
            for (i = 0; i < 32; i = i + 1) begin
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end else begin
            if (commit_reg_id != 0) begin
                val[commit_reg_id] <= commit_val;
            end
            if (issue_reg_id != 0 && commit_reg_id != 0) begin
                if (commit_reg_id == issue_reg_id) begin
                    dep[issue_reg_id] <= issue_rob_id;
                    has_dep[issue_reg_id] <= 1;
                end else begin
                    dep[issue_reg_id] <= issue_rob_id;
                    has_dep[issue_reg_id] <= 1;
                    if (has_dep[commit_reg_id] && dep[commit_reg_id] == commit_rob_id) begin
                        dep[commit_reg_id] <= 0;
                        has_dep[commit_reg_id] <= 0;
                    end
                end
            end else if (issue_reg_id != 0) begin
                dep[issue_reg_id] <= issue_rob_id;
                has_dep[issue_reg_id] <= 1;
            end else if (commit_reg_id != 0) begin
                if (has_dep[commit_reg_id] && dep[commit_reg_id] == commit_rob_id) begin
                    dep[commit_reg_id] <= 0;
                    has_dep[commit_reg_id] <= 0;
                end
            end
        end
    
    end
    

endmodule