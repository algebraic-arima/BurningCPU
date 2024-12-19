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
    input wire [`ROB_WIDTH-1:0] rob_id,
    input wire [31:0] imm, // store imm

    // from rob, issue query
    input wire has_dep_j,
    input wire [`ROB_WIDTH-1:0] dep_j,
    input wire [31:0] val_j, // store / load base addr reg
    input wire has_dep_k,
    input wire [`ROB_WIDTH-1:0] dep_k,
    input wire [31:0] val_k, // store val / load imm

    // from rs
    input wire rs_ready,
    input wire [`ROB_WIDTH-1:0] rs_rob_id,
    input wire [31 : 0] rs_value,

    // from lsb
    input wire lsb_ready,
    input wire [`ROB_WIDTH-1:0] lsb_rob_id,
    input wire [31 : 0] lsb_value,

    // from rob
    input wire [`ROB_WIDTH-1:0] head_rob_id,

    // to memctrl
    output wire ls_enable,
    output wire [31:0] addr,
    output wire [31:0] store_val,
    output wire [3:0] lsb_type,
    input wire ls_finished,
    input wire [31:0] load_val,

    // broadcast that a rob is ready
    output reg ready,
    output reg [`ROB_WIDTH-1:0] dest_rob_id,
    output reg [31:0] value

);

    reg [`LSB_WIDTH-1:0] head,tail;

    reg busy [0:`LSB_SIZE-1];
    reg [3:0] inst_op[0:`LSB_SIZE-1];
    reg [31:0] vj[0:`LSB_SIZE-1];
    reg [31:0] vk[0:`LSB_SIZE-1];
    reg dj[0:`LSB_SIZE-1];
    reg dk[0:`LSB_SIZE-1];
    reg [`ROB_WIDTH-1:0] qj[0:`LSB_SIZE-1]; // dependence of vj
    reg [`ROB_WIDTH-1:0] qk[0:`LSB_SIZE-1];
    reg [31:0] a[0:`LSB_SIZE-1];
    reg [`ROB_WIDTH-1:0] rob_dest[0:`LSB_SIZE-1]; // which rob depends on this
    reg exe_ready [0:`LSB_SIZE-1];

    assign lsb_full = head == tail + 1 || head == 0 && tail == `LSB_SIZE - 1;
    wire lsb_empty = head == tail;
    wire [`LSB_WIDTH-1:0] next_head = head + 1 == `LSB_SIZE ? 0 : head + 1;

    wire ls_e = !lsb_empty && (exe_ready[head] && !dj[head] && !dk[head]);
    wire ls_next_e = !(lsb_empty || next_head == tail) && 
                (exe_ready[next_head] && !dj[next_head] && !dk[next_head]);
    wire [31:0] ls_a = inst_op[head][3] ? (vj[head] + a[head]) : (vj[head] + vk[head]);
    wire [31:0] ls_next_a = inst_op[next_head][3] ? (vj[next_head] + a[next_head]) : (vj[next_head] + vk[next_head]);

    assign store_val = inst_op[head][3] ? vk[head] : 0;

    assign ls_enable = ls_finished ? ls_next_e : ls_e;
    assign addr = clear ? 0 : (!ls_finished) ? ls_a : ls_next_a;
    assign lsb_type = ls_finished ? inst_op[next_head] : inst_op[head];

    always @(posedge clk_in) begin: Main
        integer i;
        if (rst_in || (clear && rdy_in)) begin
            ready <= 0;
            dest_rob_id <= 0;
            value <= 0;
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                busy[i] <= 0;
                inst_op[i] <= 0;
                vj[i] <= 0;
                vk[i] <= 0;
                dj[i] <= 0;
                dk[i] <= 0;
                qj[i] <= 0;
                qk[i] <= 0;
                a[i] <= 0;
                rob_dest[i] <= 0;
                exe_ready[i] <= 0;
            end
            head <= 0;
            tail <= 0;
        end else if (rdy_in) begin
            // update dependence
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
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
                    if (dj[i] && qj[i] == lsb_rob_id) begin
                        vj[i] <= lsb_value;
                        dj[i] <= 0;
                    end
                    if (dk[i] && qk[i] == lsb_rob_id) begin
                        vk[i] <= lsb_value;
                        dk[i] <= 0;
                    end
                end
            end
            // issue
            if (dec_ready) begin
                busy[tail] <= 1;
                inst_op[tail] <= type;
                vj[tail] <= (rs_ready && has_dep_j && dep_j == rs_rob_id) ? rs_value : (lsb_ready && has_dep_j && dep_j == lsb_rob_id) ? lsb_value : val_j;
                vk[tail] <= (rs_ready && has_dep_k && dep_k == rs_rob_id) ? rs_value : (lsb_ready && has_dep_k && dep_k == lsb_rob_id) ? lsb_value : val_k;
                dj[tail] <= has_dep_j && !(rs_ready && has_dep_j && dep_j == rs_rob_id) && !(lsb_ready && has_dep_j && dep_j == lsb_rob_id);
                dk[tail] <= has_dep_k && !(rs_ready && has_dep_k && dep_k == rs_rob_id) && !(lsb_ready && has_dep_k && dep_k == lsb_rob_id);
                qj[tail] <= dep_j;
                qk[tail] <= dep_k;
                a[tail] <= imm;
                rob_dest[tail] <= rob_id;
                exe_ready[tail] <= !type[3] && !(type == 4'b0100); // sw, sh, sb and lbu
                tail <= tail + 1;
            end
            // ram
            if (ls_finished) begin
                head <= head + 1;
            end
            // from rob
            if (busy[head] && rob_dest[head] == head_rob_id) begin
                exe_ready[head] <= 1;
            end
            // broadcast
            if (busy[head] && ls_finished) begin
                ready <= 1;
                dest_rob_id <= rob_dest[head];
                head <= head + 1;
                if (inst_op[head][3]) begin
                    value <= 0;
                end else begin
                    value <= load_val;
                end
            end else begin
                ready <= 0;
            end
        end
    end

    wire [31:0] vj0 = vj[0];
    wire [31:0] vj1 = vj[1];
    wire [31:0] vj2 = vj[2];
    wire [31:0] vj3 = vj[3];
    wire [31:0] vj4 = vj[4];
    wire [31:0] vj5 = vj[5];
    wire [31:0] vj6 = vj[6];
    wire [31:0] vj7 = vj[7];
    wire [31:0] vk0 = vk[0];
    wire [31:0] vk1 = vk[1];
    wire [31:0] vk2 = vk[2];
    wire [31:0] vk3 = vk[3];
    wire [31:0] vk4 = vk[4];
    wire [31:0] vk5 = vk[5];
    wire [31:0] vk6 = vk[6];
    wire [31:0] vk7 = vk[7];
    wire dj0 = dj[0];
    wire dj1 = dj[1];
    wire dj2 = dj[2];
    wire dj3 = dj[3];
    wire dj4 = dj[4];
    wire dj5 = dj[5];
    wire dj6 = dj[6];
    wire dj7 = dj[7];
    wire dk0 = dk[0];
    wire dk1 = dk[1];
    wire dk2 = dk[2];
    wire dk3 = dk[3];
    wire dk4 = dk[4];
    wire dk5 = dk[5];
    wire dk6 = dk[6];
    wire dk7 = dk[7];
    wire [`ROB_WIDTH-1:0] qj0 = qj[0];
    wire [`ROB_WIDTH-1:0] qj1 = qj[1];
    wire [`ROB_WIDTH-1:0] qj2 = qj[2];
    wire [`ROB_WIDTH-1:0] qj3 = qj[3];
    wire [`ROB_WIDTH-1:0] qj4 = qj[4];
    wire [`ROB_WIDTH-1:0] qj5 = qj[5];
    wire [`ROB_WIDTH-1:0] qj6 = qj[6];
    wire [`ROB_WIDTH-1:0] qj7 = qj[7];
    wire [`ROB_WIDTH-1:0] qk0 = qk[0];
    wire [`ROB_WIDTH-1:0] qk1 = qk[1];
    wire [`ROB_WIDTH-1:0] qk2 = qk[2];
    wire [`ROB_WIDTH-1:0] qk3 = qk[3];
    wire [`ROB_WIDTH-1:0] qk4 = qk[4];
    wire [`ROB_WIDTH-1:0] qk5 = qk[5];
    wire [`ROB_WIDTH-1:0] qk6 = qk[6];
    wire [`ROB_WIDTH-1:0] qk7 = qk[7];
    wire [31:0] a0 = a[0];
    wire [31:0] a1 = a[1];
    wire [31:0] a2 = a[2];
    wire [31:0] a3 = a[3];
    wire [31:0] a4 = a[4];
    wire [31:0] a5 = a[5];
    wire [31:0] a6 = a[6];
    wire [31:0] a7 = a[7];

endmodule