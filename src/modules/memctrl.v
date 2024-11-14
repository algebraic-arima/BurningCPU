module memctrl(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire clear,

    input  wire [ 7 : 0] mem_din,   // data input bus
    output wire [ 7 : 0] mem_dout,  // data output bus
    output wire [31 : 0] mem_a,     // address bus (only 17 : 0 is used)
    output wire          mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    // from to ifetcher
    input wire if_enable,
    input wire [31:0] inst_addr,
    output wire if_ready,
    output wire [31:0] inst,

    // from to lsb
    input wire ls_enable,
    input wire is_write,
    input wire [31:0] ls_addr,
    input wire [31:0] store_val,
    input wire is_signed,
    input wire [1:0] data_width, // 0 for byte, 1 for half, 2 for word
    output wire ls_finished,
    output wire [31:0] load_val

);

    

endmodule