`include "params.v"

module rs (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    output wire rs_full,

    input wire clear,

    // from decoder
    input wire dec_ready,
    input wire [31:0] inst_addr,

    // from rs
    input wire rs_ready,
    input wire [`ROB_WIDTH-1:0] rs_rob_id,
    input wire [31 : 0] rs_value,

    // from lsb
    input wire lsb_ready,
    input wire [`ROB_WIDTH-1:0] lsb_rob_id,
    input wire [31 : 0] lsb_value,

    // broadcast that a rob is ready
    output reg ready,
    output reg [`ROB_WIDTH-1:0] rob_id,
    output reg [31:0] value,

    
);

    reg busy [0:`RS_SIZE-1];
    reg [3:0] inst_type[0:`RS_SIZE-1];
    reg [8:0] inst_op[0:`RS_SIZE-1];
    reg [31:0] vj[0:`RS_SIZE-1];
    reg [31:0] vk[0:`RS_SIZE-1];
    reg has_dj[0:`RS_SIZE-1];
    reg has_dk[0:`RS_SIZE-1];
    reg [`ROB_WIDTH-1:0] qj[0:`RS_SIZE-1]; // dependence of vj
    reg [`ROB_WIDTH-1:0] qk[0:`RS_SIZE-1];
    reg [31:0] a[0:`RS_SIZE-1];
    reg [`ROB_WIDTH-1:0] rob_dest[0:`RS_SIZE-1]; // which rob depends on this
    reg val_ready [0:`RS_SIZE-1];

    wire [`RS_WIDTH-1:0] calc;
    wire [`RS_WIDTH-1:0] idle;

    genvar i;
    generate 
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            assign calc[i] = busy[i] && (!has_dj[i] && !has_dk[i]);
        end
    endgenerate



endmodule
