`define BEQ 5'b10000
`define BNE 5'b10001
`define BLT 5'b10100
`define BGE 5'b10101
`define BLTU 5'b10110
`define BGEU 5'b10111

`define ADD 5'b00000
`define SUB 5'b01000
`define SLL 5'b00001
`define SLT 5'b00010
`define SLTU 5'b00011
`define XOR 5'b00100
`define SR 5'b00101
`define OR 5'b00110
`define AND 5'b00111

`define NOP 5'b11111

module alu(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire calc_enable,

    input wire clear, // clear signal for prediction

    input wire [31:0] lhs,
    input wire [31:0] rhs,
    input wire [4:0] op,
    input wire [`ROB_WIDTH-1:0] rob_dep,

    input wire [31:0] true_jaddr,
    input wire [31:0] false_jaddr,
    
    output reg ready,
    output reg [31 : 0] value

);   

    wire [31:0] calc[0:32];
    // assign calc[`JALR] = (lhs + rhs) & {{31{1'b1}}, 1'b0}; // even addr

    assign calc[`BEQ] = lhs == rhs ? true_jaddr : false_jaddr;
    assign calc[`BNE] = lhs != rhs ? true_jaddr : false_jaddr;
    assign calc[`BLT] = $signed(lhs) < $signed(rhs) ? true_jaddr : false_jaddr;
    assign calc[`BGE] = $signed(lhs) >= $signed(rhs) ? true_jaddr : false_jaddr;
    assign calc[`BLTU] = lhs < rhs ? true_jaddr : false_jaddr;
    assign calc[`BGEU] = lhs >= rhs ? true_jaddr : false_jaddr;

    assign calc[`ADD] = lhs + rhs;
    assign calc[`SUB]  = lhs - rhs;
    assign calc[`SLL] = lhs << rhs[4:0];
    assign calc[`SLT] = {{31{1'b0}}, {$signed(lhs) < $signed(rhs)}};
    assign calc[`SLTU] = {{31{1'b0}}, {lhs < rhs}};
    assign calc[`XOR] = lhs ^ rhs;
    assign calc[`SR] = rhs[10] ? lhs >>> rhs[4:0] : lhs >> rhs[4:0];
    assign calc[`OR] = lhs | rhs;
    assign calc[`AND] = lhs & rhs;
    
    always @(posedge clk_in) begin
        if(rst_in | (rdy_in & clear)) begin
            ready <= 1'b0;
            value <= 32'b0;
        end else if (rdy_in & calc_enable) begin
            ready <= 1'b1;
            value <= calc[op];
        end else begin
            ready <= 1'b0;
        end
    end

endmodule