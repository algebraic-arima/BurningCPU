`include "params.v"

module rob(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire clear,
    output wire rob_empty,
    output wire rob_full,

    // issue: from decoder, to regfile
    output wire [`ROB_WIDTH-1:0] empty_rob_id,
    input wire [31:0] addr,
    input wire [3:0] type,
    input wire [8:0] op,

    // from rs
    input wire ready,
    input wire [`ROB_WIDTH-1:0] rob_id,
    input wire [31 : 0] value,

    // commit to regfile
    output wire [`ROB_WIDTH-1:0] commit_rob_id,
    output wire [4:0] commit_reg_id,
    output wire [31:0] commit_val,

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

    reg [1:0] status[0:`ROB_SIZE-1];
    reg [4:0] dest[0:`ROB_SIZE-1];
    reg [31:0] val[0:`ROB_SIZE-1];
    reg [31:0] inst_addr[0:`ROB_SIZE-1];
    reg [`ROB_WIDTH-1:0] head;
    reg [`ROB_WIDTH-1:0] tail;

    // instruction
    reg [3:0] inst_type[0:`ROB_SIZE-1];
    reg [8:0] inst_op[0:`ROB_SIZE-1];

    assign search_ready_1 = status[search_rob_id_1] == WR;
    assign search_ready_2 = status[search_rob_id_2] == WR;
    assign search_val_1 = val[search_rob_id_1];
    assign search_val_2 = val[search_rob_id_2];
    assign rob_empty = head == tail;
    assign rob_full = tail + 1 == head || tail == `ROB_SIZE - 1 && head == 0;
    assign empty_rob_id = tail;


endmodule