
`define ROB_SIZE 16
`define ROB_WIDTH 4

`define RS_SIZE 8
`define RS_WIDTH 3

`define LSB_SIZE 8
`define LSB_WIDTH 3

// OpType
`define U 3'b000
`define J 3'b001
`define B 3'b010
`define I 3'b011
`define S 3'b100
`define R 3'b101
`define NT 3'b111

// OpCode
`define LUI 8'b0
`define AUIPC 8'b1
`define JAL 8'b10
`define JALR 8'b11
`define BEQ 8'b100
`define BNE 8'b101
`define BLT 8'b110
`define BGE 8'b111
`define BLTU 8'b1000
`define BGEU 8'b1001
`define LB 8'b1010
`define LH 8'b1011
`define LW 8'b1100
`define LBU 8'b1101
`define LHU 8'b1110
`define SB 8'b1111
`define SH 8'b10000
`define SW 8'b10001
`define ADDI 8'b10010
`define SLTI 8'b10011
`define SLTIU 8'b10100
`define XORI 8'b10101
`define ORI 8'b10110
`define ANDI 8'b10111
`define SLLI 8'b11000
`define SRLI 8'b11001
`define SRAI 8'b11010
`define ADD 8'b11011
`define SUB 8'b11100
`define SLL 8'b11101
`define SLT 8'b11110
`define SLTU 8'b11111
`define XOR 8'b100000
`define SRL 8'b100001
`define SRA 8'b100010
`define OR 8'b100011
`define AND 8'b100100
`define NOP 8'b11111111
