module rob(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    output wire rob_full,

    // issue: from decoder, to regfile
    output wire [`ROB_WIDTH-1:0] empty_rob_id,
    input wire dec_ready,
    input wire [31:0] addr,
    input wire [31:0] j_addr,
    input wire [1:0] type,
    input wire [4:0] rd,

    // to decoder: freeze
    output reg melt,
    // to decoder: predict false
    output reg clear,
    // to decoder: next addr
    output reg [31:0] corr_jump_addr,


    // from rs
    input wire rs_ready,
    input wire [`ROB_WIDTH-1:0] rs_rob_id,
    input wire [31 : 0] rs_value, // if br. return the correct addr to jump

    // from lsb
    input wire lsb_ready,
    input wire [`ROB_WIDTH-1:0] lsb_rob_id,
    input wire [31 : 0] lsb_value,

    // commit to regfile
    output reg commit_ready,
    output reg [`ROB_WIDTH-1:0] commit_rob_id,
    output reg [4:0] commit_reg_id,
    output reg [31:0] commit_val,

    // search: from regfile
    input wire search_in_has_dep_1,
    input wire [`ROB_WIDTH-1:0] search_rob_id_1,
    input wire [31:0] search_in_val_1,
    input wire search_in_has_dep_2,
    input wire [`ROB_WIDTH-1:0] search_rob_id_2,
    input wire [31:0] search_in_val_2,

    // to rs
    output reg search_has_dep_1_rs,
    output reg [`ROB_WIDTH-1:0] search_dep_1_rs,
    output reg [31:0] search_val_1_rs,
    output reg search_has_dep_2_rs,
    output reg [`ROB_WIDTH-1:0] search_dep_2_rs,
    output reg [31:0] search_val_2_rs,

    // to lsb
    output reg search_has_dep_1_lsb,
    output reg [`ROB_WIDTH-1:0] search_dep_1_lsb,
    output reg [31:0] search_val_1_lsb,
    output reg search_has_dep_2_lsb,
    output reg [`ROB_WIDTH-1:0] search_dep_2_lsb,
    output reg [31:0] search_val_2_lsb,
    output wire [`ROB_WIDTH-1:0] head_rob_id

);

    localparam IS = 2'b01;
    localparam WR = 2'b10;
    // localparam CO = 2'b11;

    localparam BR = 2'b00;
    localparam ST = 2'b01;
    localparam JALR = 2'b10;
    localparam RG = 2'b11;

    // reg [31:0] inst_addr[0:`ROB_SIZE-1];
    reg busy[0:`ROB_SIZE-1];
    reg [1:0] status[0:`ROB_SIZE-1]; // IS, WR, CO
    reg [4:0] inst_rd[0:`ROB_SIZE-1];
    reg [31:0] inst_val[0:`ROB_SIZE-1]; // for branch, true jump addr; for others, the value of rd
    reg [31:0] jump_addr[0:`ROB_SIZE-1]; // for branch: predicted jump addr; for jalr: pc + 4 storage
    reg [`ROB_WIDTH-1:0] head;
    reg [`ROB_WIDTH-1:0] tail;

    assign head_rob_id = head;

    // instruction type: BR, ST, JALR, RG
    reg [1:0] inst_type[0:`ROB_SIZE-1];

    wire search_rs_hit1 = rs_ready && rs_rob_id == search_rob_id_1;
    wire search_lsb_hit1 = lsb_ready && lsb_rob_id == search_rob_id_1;
    wire search_rs_hit2 = rs_ready && rs_rob_id == search_rob_id_2;
    wire search_lsb_hit2 = lsb_ready && lsb_rob_id == search_rob_id_2;

    wire search_ready_1 = search_rs_hit1 || search_lsb_hit1 || (busy[search_rob_id_1] && status[search_rob_id_1] == WR);
    wire search_ready_2 = search_rs_hit2 || search_lsb_hit2 || (busy[search_rob_id_2] && status[search_rob_id_2] == WR);
    wire [31:0] local_val_1 = search_rs_hit1 ? rs_value : search_lsb_hit1 ? lsb_value : inst_val[search_rob_id_1];
    wire [31:0] local_val_2 = search_rs_hit2 ? rs_value : search_lsb_hit2 ? lsb_value : inst_val[search_rob_id_2];

    wire rob_empty = head == tail;
    assign rob_full = tail + 1 == head || tail == `ROB_SIZE - 1 && head == 0;
    assign empty_rob_id = tail;
    assign store_enable = !rob_empty && inst_type[head] == ST;

    // reg [31:0] commit_addr;

    always @(posedge clk_in) begin: Main
        integer i;
        if (rst_in || (clear && rdy_in)) begin
            head <= 0;
            tail <= 0;
            commit_ready <= 0;
            commit_reg_id <= 0;
            commit_rob_id <= 0;
            commit_val <= 0; 
            melt <= 0;
            corr_jump_addr <= 0;
            search_has_dep_1_rs <= 0;
            search_dep_1_rs <= 0;
            search_val_1_rs <= 0;
            search_has_dep_2_rs <= 0;
            search_dep_2_rs <= 0;
            search_val_2_rs <= 0;
            search_has_dep_1_lsb <= 0;
            search_dep_1_lsb <= 0;
            search_val_1_lsb <= 0;
            search_has_dep_2_lsb <= 0;
            search_dep_2_lsb <= 0;
            search_val_2_lsb <= 0;
            for (i = 0; i < `ROB_SIZE; i = i + 1) begin
                busy[i] <= 0;
                inst_rd[i] <= 0;
                inst_val[i] <= 0;
                // inst_addr[i] <= 0;
                jump_addr[i] <= 0;
                status[i] <= 0;
            end
            clear <= 0; // clear only appears for 1 cycle
        end else if (rdy_in) begin
            // answer query
            search_has_dep_1_rs <= search_in_has_dep_1 && !search_ready_1;
            search_dep_1_rs <= !search_in_has_dep_1 ? 0 : search_ready_1 ? 0 : search_rob_id_1;
            search_val_1_rs <= !search_in_has_dep_1 ? search_in_val_1 : search_ready_1 ? local_val_1 : 0;
            search_has_dep_2_rs <= search_in_has_dep_2 && !search_ready_2;
            search_dep_2_rs <= !search_in_has_dep_2 ? 0 : search_ready_2 ? 0 : search_rob_id_2;
            search_val_2_rs <= !search_in_has_dep_2 ? search_in_val_2 : search_ready_2 ? local_val_2 : 0;
            
            search_has_dep_1_lsb <= search_in_has_dep_1 && !search_ready_1;
            search_dep_1_lsb <= !search_in_has_dep_1 ? 0 : search_ready_1 ? 0 : search_rob_id_1;
            search_val_1_lsb <= !search_in_has_dep_1 ? search_in_val_1 : search_ready_1 ? local_val_1 : 0;
            search_has_dep_2_lsb <= search_in_has_dep_2 && !search_ready_2;
            search_dep_2_lsb <= !search_in_has_dep_2 ? 0 : search_ready_2 ? 0 : search_rob_id_2;
            search_val_2_lsb <= !search_in_has_dep_2 ? search_in_val_2 : search_ready_2 ? local_val_2 : 0;
            
            // update
            if(dec_ready) begin
                busy[tail] <= 1;
                inst_rd[tail] <= rd;
                inst_val[tail] <= 0;
                jump_addr[tail] <= j_addr;
                // inst_addr[tail] <= addr;
                inst_type[tail] <= type;
                status[tail] <= IS;
                tail <= tail + 1;
            end
            if(rs_ready) begin
                status[rs_rob_id] <= WR;
                inst_val[rs_rob_id] <= rs_value;
            end
            if(lsb_ready) begin
                status[lsb_rob_id] <= WR;
                inst_val[lsb_rob_id] <= lsb_value;
            end
            // commit
            if (busy[head] && status[head] == WR) begin
                // $write("%d ", $time);
                // $display("%h", inst_addr[head]);
                head <= head + 1;
                busy[head] <= 0;
                commit_rob_id <= head;
                // commit_addr <= inst_addr[head];
                melt <= inst_type[head] == JALR;
                if (inst_type[head] == BR) begin
                    commit_ready <= 0;
                    if (inst_val[head] != jump_addr[head]) begin
                        clear <= 1;
                        corr_jump_addr <= inst_val[head];
                    end
                end else if (inst_type[head] == ST) begin
                    commit_ready <= 0;
                end else if (inst_type[head] == JALR) begin
                    commit_ready <= 1;
                    commit_reg_id <= inst_rd[head];
                    commit_val <= jump_addr[head];
                    corr_jump_addr <= inst_val[head];
                end else begin
                    commit_ready <= 1;
                    commit_reg_id <= inst_rd[head];
                    commit_val <= inst_val[head];
                end
            end else begin
                commit_ready <= 0;
                melt <= 0;
            end
        end
    end

endmodule