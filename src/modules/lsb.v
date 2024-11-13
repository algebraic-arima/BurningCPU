module lsb(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    output wire lsb_full,

    input wire clear,

    // from decoder
    input wire dec_ready,
    input wire [2:0] type,
    input wire [7:0] op,
    input wire [31:0] val_j, // store val
    input wire [31:0] val_k, // store/load addr
    input wire has_dep_j,
    input wire has_dep_k,
    input wire [`ROB_WIDTH-1:0] dep_j,
    input wire [`ROB_WIDTH-1:0] dep_k,
    input wire [`ROB_WIDTH-1:0] rob_id,
    input wire [31:0] imm, // offset

    // from rs
    input wire rs_ready,
    input wire [`ROB_WIDTH-1:0] rs_rob_id,
    input wire [31 : 0] rs_value,

    // from lsb
    input wire lsb_ready,
    input wire [`ROB_WIDTH-1:0] lsb_rob_id,
    input wire [31 : 0] lsb_value,

    // from rob
    input wire store_enable,

    // to ram
    output wire re,
    output wire we,
    output wire [31:0] addr,
    output wire [31:0] store_val,
    input wire [31:0] read_val,

    // broadcast that a rob is ready
    output wire ready,
    output wire [`ROB_WIDTH-1:0] dest_rob_id,
    output wire [31:0] value

);

    reg [`LSB_WIDTH-1:0] head,tail;

    reg busy [0:`LSB_SIZE-1];
    reg is_write [0:`LSB_SIZE-1];
    reg [7:0] inst_op[0:`LSB_SIZE-1];
    reg [31:0] vj[0:`LSB_SIZE-1];
    reg [31:0] vk[0:`LSB_SIZE-1];
    reg dj[0:`LSB_SIZE-1];
    reg dk[0:`LSB_SIZE-1];
    reg [`ROB_WIDTH-1:0] qj[0:`LSB_SIZE-1]; // dependence of vj
    reg [`ROB_WIDTH-1:0] qk[0:`LSB_SIZE-1];
    reg [31:0] a[0:`LSB_SIZE-1];
    reg [`ROB_WIDTH-1:0] rob_dest[0:`LSB_SIZE-1]; // which rob depends on this
    reg val_ready [0:`LSB_SIZE-1];

    assign lsb_full = head == tail + 1 || head == 0 && tail == `LSB_SIZE - 1;

    always @(posedge clk_in) begin: Main
        integer i;
        if (rst_in || (clear && rdy_in)) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                busy[i] <= 0;
                is_write[i] <= 0;
                inst_op[i] <= 0;
                vj[i] <= 0;
                vk[i] <= 0;
                dj[i] <= 0;
                dk[i] <= 0;
                qj[i] <= 0;
                qk[i] <= 0;
                a[i] <= 0;
                rob_dest[i] <= 0;
                val_ready[i] <= 0;
            end
            head <= 0;
            tail <= 0;
        end else if (rdy_in) begin
            
        end
    end

endmodule