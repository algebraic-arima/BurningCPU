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
    output reg [`ROB_WIDTH-1:0] rob_id,
    output reg [31:0] value
);

    always @(posedge clk_in) begin
        if (rst_in || (rdy_in && clear)) begin
            ready <= 1'b0;
            value <= 32'b0;
            rob_id <= 0;
        end else if (rdy_in && calc_enable) begin
            ready <= 1'b1;
            rob_id <= rob_dep;
            case (op)
                `BEQ:   value <= (lhs == rhs) ? true_jaddr : false_jaddr;
                `BNE:   value <= (lhs != rhs) ? true_jaddr : false_jaddr;
                `BLT:   value <= ($signed(lhs) < $signed(rhs)) ? true_jaddr : false_jaddr;
                `BGE:   value <= ($signed(lhs) >= $signed(rhs)) ? true_jaddr : false_jaddr;
                `BLTU:  value <= (lhs < rhs) ? true_jaddr : false_jaddr;
                `BGEU:  value <= (lhs >= rhs) ? true_jaddr : false_jaddr;

                `ADD:   value <= lhs + rhs;
                `SUB:   value <= lhs - rhs;
                `SLL:   value <= lhs << rhs[4:0];
                `SLT:   value <= {{31{1'b0}}, $signed(lhs) < $signed(rhs)};
                `SLTU:  value <= {{31{1'b0}}, lhs < rhs};
                `XOR:   value <= lhs ^ rhs;
                `SR:    value <= rhs[10] ? lhs >>> rhs[4:0] : lhs >> rhs[4:0];
                `OR:    value <= lhs | rhs;
                `AND:   value <= lhs & rhs;

                default: value <= 32'b0;
            endcase
        end else begin
            ready <= 1'b0;
            value <= 32'b0;
            rob_id <= 0;
        end
    end

endmodule
