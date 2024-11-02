
module decoder(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire rs_full,
    input wire rob_full,
    input wire lsb_full,

    input wire [31:0] inst, // next instruction

    input wire clear,
    input wire [31:0] corr_inst_addr // pc_bus

    // Register File
    

);

    reg [31:0] inst_addr;

endmodule
