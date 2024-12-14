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
    output reg [31:0] value,

    output reg ready_lsb,
    output reg [`ROB_WIDTH-1:0] rob_id_lsb,
    output reg [31:0] value_lsb,

    output reg ready_rob,
    output reg [`ROB_WIDTH-1:0] rob_id_rob,
    output reg [31:0] value_rob
);

    always @(posedge clk_in) begin
        if (rst_in || (rdy_in && clear)) begin
            ready <= 1'b0;
            value <= 32'b0;
            rob_id <= 0;
            ready_lsb <= 1'b0;
            value_lsb <= 32'b0;
            rob_id_lsb <= 0;
            ready_rob <= 1'b0;
            value_rob <= 32'b0;
            rob_id_rob <= 0;
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
            ready_lsb <= 1'b1;
            rob_id_lsb <= rob_dep;
            case (op)
                `BEQ:   value_lsb <= (lhs == rhs) ? true_jaddr : false_jaddr;
                `BNE:   value_lsb <= (lhs != rhs) ? true_jaddr : false_jaddr;
                `BLT:   value_lsb <= ($signed(lhs) < $signed(rhs)) ? true_jaddr : false_jaddr;
                `BGE:   value_lsb <= ($signed(lhs) >= $signed(rhs)) ? true_jaddr : false_jaddr;
                `BLTU:  value_lsb <= (lhs < rhs) ? true_jaddr : false_jaddr;
                `BGEU:  value_lsb <= (lhs >= rhs) ? true_jaddr : false_jaddr;

                `ADD:   value_lsb <= lhs + rhs;
                `SUB:   value_lsb <= lhs - rhs;
                `SLL:   value_lsb <= lhs << rhs[4:0];
                `SLT:   value_lsb <= {{31{1'b0}}, $signed(lhs) < $signed(rhs)};
                `SLTU:  value_lsb <= {{31{1'b0}}, lhs < rhs};
                `XOR:   value_lsb <= lhs ^ rhs;
                `SR:    value_lsb <= rhs[10] ? lhs >>> rhs[4:0] : lhs >> rhs[4:0];
                `OR:    value_lsb <= lhs | rhs;
                `AND:   value_lsb <= lhs & rhs;

                default: value_lsb <= 32'b0;
            endcase
            ready_rob <= 1'b1;
            rob_id_rob <= rob_dep;
            case (op)
                `BEQ:   value_rob <= (lhs == rhs) ? true_jaddr : false_jaddr;
                `BNE:   value_rob <= (lhs != rhs) ? true_jaddr : false_jaddr;
                `BLT:   value_rob <= ($signed(lhs) < $signed(rhs)) ? true_jaddr : false_jaddr;
                `BGE:   value_rob <= ($signed(lhs) >= $signed(rhs)) ? true_jaddr : false_jaddr;
                `BLTU:  value_rob <= (lhs < rhs) ? true_jaddr : false_jaddr;
                `BGEU:  value_rob <= (lhs >= rhs) ? true_jaddr : false_jaddr;

                `ADD:   value_rob <= lhs + rhs;
                `SUB:   value_rob <= lhs - rhs;
                `SLL:   value_rob <= lhs << rhs[4:0];
                `SLT:   value_rob <= {{31{1'b0}}, $signed(lhs) < $signed(rhs)};
                `SLTU:  value_rob <= {{31{1'b0}}, lhs < rhs};
                `XOR:   value_rob <= lhs ^ rhs;
                `SR:    value_rob <= rhs[10] ? lhs >>> rhs[4:0] : lhs >> rhs[4:0];
                `OR:    value_rob <= lhs | rhs;
                `AND:   value_rob <= lhs & rhs;

                default: value_rob <= 32'b0;
            endcase
        end else begin
            ready <= 1'b0;
            value <= 32'b0;
            rob_id <= 0;
            ready_lsb <= 1'b0;
            value_lsb <= 32'b0;
            rob_id_lsb <= 0;
            ready_rob <= 1'b0;
            value_rob <= 32'b0;
            rob_id_rob <= 0;
        end
    end

endmodule
