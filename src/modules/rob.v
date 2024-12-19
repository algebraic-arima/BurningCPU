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
    localparam CO = 2'b11;

    localparam BR = 2'b00;
    localparam ST = 2'b01;
    localparam JALR = 2'b10;
    localparam RG = 2'b11;

    reg [31:0] inst_addr[0:`ROB_SIZE-1];
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

    reg [31:0] commit_addr;

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
                inst_addr[i] <= 0;
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
                inst_addr[tail] <= addr;
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
                commit_addr <= inst_addr[head];
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

    wire [31:0] val0 = inst_val[0];
    wire [31:0] val1 = inst_val[1];
    wire [31:0] val2 = inst_val[2];
    wire [31:0] val3 = inst_val[3];
    wire [31:0] val4 = inst_val[4];
    wire [31:0] val5 = inst_val[5];
    wire [31:0] val6 = inst_val[6];
    wire [31:0] val7 = inst_val[7];
    wire [31:0] val8 = inst_val[8];
    wire [31:0] val9 = inst_val[9];
    wire [31:0] val10 = inst_val[10];
    wire [31:0] val11 = inst_val[11];
    wire [31:0] val12 = inst_val[12];
    wire [31:0] val13 = inst_val[13];
    wire [31:0] val14 = inst_val[14];
    wire [31:0] val15 = inst_val[15];
    wire [1:0] status0 = status[0];
    wire [1:0] status1 = status[1];
    wire [1:0] status2 = status[2];
    wire [1:0] status3 = status[3];
    wire [1:0] status4 = status[4];
    wire [1:0] status5 = status[5];
    wire [1:0] status6 = status[6];
    wire [1:0] status7 = status[7];
    wire [1:0] status8 = status[8];
    wire [1:0] status9 = status[9];
    wire [1:0] status10 = status[10];
    wire [1:0] status11 = status[11];
    wire [1:0] status12 = status[12];
    wire [1:0] status13 = status[13];
    wire [1:0] status14 = status[14];
    wire [1:0] status15 = status[15];
    wire [31:0] ia0 = inst_addr[0];
    wire [31:0] ia1 = inst_addr[1];
    wire [31:0] ia2 = inst_addr[2];
    wire [31:0] ia3 = inst_addr[3];
    wire [31:0] ia4 = inst_addr[4];
    wire [31:0] ia5 = inst_addr[5];
    wire [31:0] ia6 = inst_addr[6];
    wire [31:0] ia7 = inst_addr[7];
    wire [31:0] ia8 = inst_addr[8];
    wire [31:0] ia9 = inst_addr[9];
    wire [31:0] ia10 = inst_addr[10];
    wire [31:0] ia11 = inst_addr[11];
    wire [31:0] ia12 = inst_addr[12];
    wire [31:0] ia13 = inst_addr[13];
    wire [31:0] ia14 = inst_addr[14];
    wire [31:0] ia15 = inst_addr[15];
    wire [31:0] ja0 = jump_addr[0];
    wire [31:0] ja1 = jump_addr[1];
    wire [31:0] ja2 = jump_addr[2];
    wire [31:0] ja3 = jump_addr[3];
    wire [31:0] ja4 = jump_addr[4];
    wire [31:0] ja5 = jump_addr[5];
    wire [31:0] ja6 = jump_addr[6];
    wire [31:0] ja7 = jump_addr[7];
    wire [31:0] ja8 = jump_addr[8];
    wire [31:0] ja9 = jump_addr[9];
    wire [31:0] ja10 = jump_addr[10];
    wire [31:0] ja11 = jump_addr[11];
    wire [31:0] ja12 = jump_addr[12];
    wire [31:0] ja13 = jump_addr[13];
    wire [31:0] ja14 = jump_addr[14];
    wire [31:0] ja15 = jump_addr[15];
    wire [1:0] it0 = inst_type[0];
    wire [1:0] it1 = inst_type[1];
    wire [1:0] it2 = inst_type[2];
    wire [1:0] it3 = inst_type[3];
    wire [1:0] it4 = inst_type[4];
    wire [1:0] it5 = inst_type[5];
    wire [1:0] it6 = inst_type[6];
    wire [1:0] it7 = inst_type[7];
    wire [1:0] it8 = inst_type[8];
    wire [1:0] it9 = inst_type[9];
    wire [1:0] it10 = inst_type[10];
    wire [1:0] it11 = inst_type[11];
    wire [1:0] it12 = inst_type[12];
    wire [1:0] it13 = inst_type[13];
    wire [1:0] it14 = inst_type[14];
    wire [1:0] it15 = inst_type[15];

endmodule