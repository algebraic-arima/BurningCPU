`include "params.v"

module rs (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    output wire rs_full,

    // from decoder
    input wire dec_ready,
    input wire [31:0] inst_addr

    
);

    reg busy [0:`RS_SIZE-1];

endmodule
