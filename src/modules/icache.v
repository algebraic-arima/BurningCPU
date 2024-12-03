module icache #(
    parameter ICACHE_SIZE = 256,
    parameter ICACHE_LINE = 4,
    parameter ICACHE_ASSOC = 4
)(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    // query
    input wire if_enable,
    input wire [31:0] get_addr,  // address to read
    output wire hit,
    output wire [31:0] return_inst,  // data output bus

    // write
    input wire inst_ready,
    input wire [31:0] wr_addr,
    input wire [31:0] wr_inst

);




endmodule