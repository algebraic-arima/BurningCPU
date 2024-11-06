`include "params.v"

module alu_lsb(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire [31:0] addr,
    input wire [31:0] imm,
    
    output reg [31 : 0] value

);

endmodule