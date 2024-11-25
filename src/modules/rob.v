module rob(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    output reg clear,
    output wire rob_full,

    // issue: from decoder, to regfile
    output wire [`ROB_WIDTH-1:0] empty_rob_id,
    input wire dec_ready,
    input wire [31:0] addr,
    input wire [31:0] j_addr,
    input wire [1:0] type,
    input wire [4:0] rd,
    input wire [31:0] val,

    // to decoder: freeze
    output wire melt,
    // to decoder: predict false
    output wire [31:0] corr_jump_addr,


    // from rs
    input wire rs_ready,
    input wire [`ROB_WIDTH-1:0] rs_rob_id,
    input wire [31 : 0] rs_value, // if br. return the correct addr to jump

    // from lsb
    input wire lsb_ready,
    input wire [`ROB_WIDTH-1:0] lsb_rob_id,
    input wire [31 : 0] lsb_value,

    // to lsb
    output reg store_enable,

    // commit to regfile
    output reg commit_ready,
    output reg [`ROB_WIDTH-1:0] commit_rob_id,
    output reg [4:0] commit_reg_id,
    output reg [31:0] commit_val,

    // search: from regfile, to regfile
    input wire [`ROB_WIDTH-1:0] search_rob_id_1,
    output wire search_ready_1,
    output wire [31:0] search_val_1,
    input wire [`ROB_WIDTH-1:0] search_rob_id_2,
    output wire search_ready_2,
    output wire [31:0] search_val_2

);

    localparam IS = 2'b00;
    localparam WR = 2'b01;
    localparam CO = 2'b11;

    localparam BR = 2'b00;
    localparam ST = 2'b01;
    localparam JALR = 2'b10;
    localparam RG = 2'b11;

    reg busy[0:`ROB_SIZE-1];
    reg [1:0] status[0:`ROB_SIZE-1]; // IS, WR, CO
    reg [4:0] inst_rd[0:`ROB_SIZE-1];
    reg [31:0] inst_val[0:`ROB_SIZE-1]; // for branch, true jump addr; for others, the value of rd
    reg [31:0] inst_addr[0:`ROB_SIZE-1];
    reg [31:0] jump_addr[0:`ROB_SIZE-1]; // for branch: predicted jump addr
    reg [`ROB_WIDTH-1:0] head;
    reg [`ROB_WIDTH-1:0] tail;

    // instruction type: BR, ST, JALR, RG
    reg [1:0] inst_type[0:`ROB_SIZE-1];

    reg has_jalr;

    assign search_ready_1 = status[search_rob_id_1] == WR;
    assign search_ready_2 = status[search_rob_id_2] == WR;
    assign search_val_1 = inst_val[search_rob_id_1];
    assign search_val_2 = inst_val[search_rob_id_2];
    wire rob_empty = head == tail;
    assign rob_full = tail + 1 == head || tail == `ROB_SIZE - 1 && head == 0;
    assign empty_rob_id = tail;
    assign melt = !has_jalr;
    assign corr_jump_addr = inst_val[head];

    always @(posedge clk_in) begin: Main
        integer i;
        if (rst_in || (clear && rdy_in)) begin
            head <= 0;
            tail <= 0;
            store_enable <= 0;
            commit_ready <= 0;
            commit_reg_id <= 0;
            commit_rob_id <= 0;
            commit_val <= 0; 

            for (i = 0; i < `ROB_SIZE; i = i + 1) begin
                busy[i] <= 0;
                inst_rd[i] <= 0;
                inst_val[i] <= 0;
                inst_addr[i] <= 0;
                jump_addr[i] <= 0;
            end
            clear <= 0; // clear only appears for 1 cycle
        end else if (rdy_in) begin
            // update
            if(dec_ready) begin
                if(rob_empty && type == ST) begin
                    store_enable <= 1;
                end else begin
                    store_enable <= 0;
                end 
                if(type == JALR) begin
                    has_jalr <= 1;
                end
                busy[tail] <= 1;
                inst_rd[tail] <= rd;
                inst_val[tail] <= val;
                inst_addr[tail] <= addr;
                jump_addr[tail] <= j_addr;
                inst_type[tail] <= type;
                status[tail] <= IS;
                tail <= tail + 1;
            end
            if(rs_ready) begin
                status[rs_rob_id] <= WR;
                inst_val[rs_rob_id] <= rs_value;
            end
            if(lsb_ready) begin
                status[lsb_rob_id] <= CO;
                inst_val[lsb_rob_id] <= lsb_value;
            end
            // commit
            if (busy[head] && (status[head] == CO || status[head] == WR)) begin
                head <= head + 1;
                busy[head] <= 0;
                if (inst_type[head] == BR) begin
                    if (inst_val[head] != jump_addr[head]) begin
                        clear <= 1;
                    end
                end else if (inst_type[head] == ST) begin
                end else begin
                    commit_rob_id <= head;
                    commit_reg_id <= inst_rd[head];
                    commit_val <= inst_val[head];
                end
                if (busy[head + 1] && inst_type[head + 1] == ST) begin
                    store_enable <= 1;
                end else begin
                    store_enable <= 0;
                end
                if (inst_type[head] == JALR) begin
                    has_jalr <= 0;
                end
            end
        end
    end

endmodule