module alu_rs(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire calc_enable,

    input wire clear, // clear signal for prediction

    input wire [31:0] lhs,
    input wire [31:0] rhs,
    input wire [8:0] op,
    input wire [`ROB_WIDTH-1:0] rob_dep,
    
    output reg ready,
    output reg [`ROB_WIDTH-1:0] rob_id,
    output reg [31 : 0] value

);

    wire [31:0] calc[0:63];
    assign calc[`LUI] = lhs;
    assign calc[`AUIPC] = lhs + rhs;
    assign calc[`JAL] = lhs + rhs;
    assign calc[`JALR] = (lhs + rhs) & {{31{1'b1}}, 1'b0};

    assign calc[`BEQ]   = {32{lhs == rhs}};
    assign calc[`BNE]   = {32{lhs != rhs}};
    assign calc[`BLT]   = {32{$signed(lhs) < $signed(rhs)}};
    assign calc[`BGE]   = {32{$signed(lhs) >= $signed(rhs)}};
    assign calc[`BLTU]  = {32{lhs < rhs}};
    assign calc[`BGEU]  = {32{lhs >= rhs}};

    assign calc[`ADDI] = lhs + rhs;
    assign calc[`SLTI] = {{31{1'b0}}, {$signed(lhs) < $signed(rhs)}};
    assign calc[`SLTIU] = {{31{1'b0}}, {lhs < rhs}};
    assign calc[`XORI] = lhs ^ rhs;
    assign calc[`ORI] = lhs | rhs;
    assign calc[`ANDI] = lhs & rhs;
    assign calc[`SLLI] = lhs << rhs[4:0];
    assign calc[`SRLI] = lhs >> rhs[4:0];
    assign calc[`SRAI] = lhs >>> rhs[4:0];

    assign calc[`ADD]  = calc[`ADDI];
    assign calc[`SUB]  = lhs - rhs;
    assign calc[`SLL]  = calc[`SLLI];
    assign calc[`SLT]   = calc[`SLTI];
    assign calc[`SLTU]  = calc[`SLTIU];
    assign calc[`XOR]  = calc[`XORI];
    assign calc[`SRL]  = calc[`SRLI];
    assign calc[`SRA]  = calc[`SRAI];
    assign calc[`OR]   = calc[`ORI];
    assign calc[`AND]  = calc[`ANDI];
    
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