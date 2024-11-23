`define LB 4'b0000
`define LH 4'b0001
`define LW 4'b0010
`define LBU 4'b0100
`define LHU 4'b0101
`define SB 4'b1000
`define SH 4'b1001
`define SW 4'b1010

module lsb(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    output wire lsb_full,

    input wire clear,

    // from decoder
    input wire dec_ready,
    input wire [3:0] type,
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

    // to memctrl
    output reg re,
    output reg we,
    output reg [31:0] addr,
    output reg [31:0] store_val,
    input wire ls_finished,
    input wire [31:0] read_val,

    // broadcast that a rob is ready
    output wire ready,
    output wire [`ROB_WIDTH-1:0] dest_rob_id,
    output wire [31:0] value

);

    reg [`LSB_WIDTH-1:0] head,tail;

    reg busy [0:`LSB_SIZE-1];
    reg is_write [0:`LSB_SIZE-1];
    reg [3:0] inst_op[0:`LSB_SIZE-1];
    reg [31:0] vj[0:`LSB_SIZE-1];
    reg [31:0] vk[0:`LSB_SIZE-1];
    reg dj[0:`LSB_SIZE-1];
    reg dk[0:`LSB_SIZE-1];
    reg [`ROB_WIDTH-1:0] qj[0:`LSB_SIZE-1]; // dependence of vj
    reg [`ROB_WIDTH-1:0] qk[0:`LSB_SIZE-1];
    reg [31:0] a[0:`LSB_SIZE-1];
    reg [`ROB_WIDTH-1:0] rob_dest[0:`LSB_SIZE-1]; // which rob depends on this
    reg val_ready [0:`LSB_SIZE-1];
    reg working;

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
            // update dependence
            for (i = 0; i < `ROB_SIZE; ++i) begin
                if (busy[i] && rs_ready) begin
                    if(dj[i] && qj[i] == rs_rob_id) begin
                        vj[i] <= rs_value;
                        dj[i] <= 0;
                    end
                    if(dk[i] && qk[i] == rs_rob_id) begin
                        vk[i] <= rs_value;
                        dk[i] <= 0;
                    end
                end
                if (busy[i] && lsb_ready) begin
                    if(dj[i] && qj[i] == lsb_rob_id) begin
                        vj[i] <= lsb_value;
                        dj[i] <= 0;
                    end
                    if(dk[i] && qk[i] == lsb_rob_id) begin
                        vk[i] <= lsb_value;
                        dk[i] <= 0;
                    end
                end
            end
            // issue
            if (dec_ready) begin
                busy[tail] <= 1;
                is_write[tail] <= type[3];
                inst_op[tail] <= type;
                vj[tail] <= val_j;
                vk[tail] <= val_k;
                dj[tail] <= has_dep_j && !(rs_ready && dep_j == rs_rob_id) && !(lsb_ready && dep_j == lsb_rob_id);
                dk[tail] <= has_dep_k && !(rs_ready && dep_k == rs_rob_id) && !(lsb_ready && dep_k == lsb_rob_id);
                qj[tail] <= dep_j;
                qk[tail] <= dep_k;
                a[tail] <= imm;
                rob_dest[tail] <= rob_id;
                val_ready[tail] <= 0;
                tail <= tail + 1;
            end
            // read from ram
            if ((!working || ls_finished) && busy[head] && dj[head] == 0 && dk[head] == 0 && !val_ready[head]) begin
                re <= 1;
                we <= 0;
                addr <= a[head];
                store_val <= 0;

            end
            if (!working) begin
                working <= 1;
            end
        end
    end

endmodule