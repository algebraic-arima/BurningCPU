`include "params.v"

`define ADDSUB 4'd0
`define SLL 4'd1
`define SLT 4'd2
`define SLTU 4'd3
`define XOR 4'd4
`define SR 4'd5
`define OR 4'd6
`define AND 4'd7
`define EQ 4'd8
`define NE 4'd9

`define LT 4'd12
`define GE 4'd13
`define LTU 4'd14
`define GEU 4'd15

module alu_rs(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire calc_enable,

    input wire clear, // clear signal for prediction

    input wire [31:0] lhs,
    input wire [31:0] rhs,
    input wire [3:0] op,
    input wire is_jalr,
    input wire op_30,
    input wire [`ROB_WIDTH-1:0] rob_dep,
    
    output reg ready,
    output reg [`ROB_WIDTH-1:0] rob_id,
    output reg [31 : 0] value

);

    wire [31:0] calc[15:0];
    assign calc[`AND]  = lhs & rhs;
    assign calc[`OR]   = lhs | rhs;
    assign calc[`XOR]  = lhs ^ rhs;
    assign calc[`ADDSUB]  = is_jalr ? (lhs + rhs) & {{31{1'b1}}, 1'b0} : (op_30 ? lhs - rhs : lhs + rhs);
    assign calc[`SR]  = op_30 ? lhs >>> rhs[4:0] : lhs >> rhs[4:0];
    assign calc[`SLL]  = lhs << rhs[4:0];
    assign calc[`LT]   = {{31{1'b0}}, {$signed(lhs) < $signed(rhs)}};
    assign calc[`LTU]  = {{31{1'b0}}, {lhs < rhs}};
    assign calc[`EQ]   = {32{lhs == rhs}};
    assign calc[`NE]   = {32{lhs != rhs}};
    assign calc[`GE]   = {32{$signed(lhs) >= $signed(rhs)}};
    assign calc[`GEU]  = {32{lhs >= rhs}};

    
    always @(posedge clk_in) begin
        if(rst_in | (rdy_in & clear)) begin
            ready <= 1'b0;
        end else if (rdy_in & calc_enable) begin
            ready <= 1'b1;
            value <= calc[op];
        end else begin
            ready <= 1'b0;
        end
    end


endmodule