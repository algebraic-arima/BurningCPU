`include "params.v"
`include "alu/alu_rs.v"

module rs (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    output wire rs_full,

    input wire clear,

    // from decoder
    input wire dec_ready,
    input wire [2:0] type,
    input wire [7:0] op,
    input wire [31:0] val_j,
    input wire [31:0] val_k,
    input wire has_dep_j,
    input wire has_dep_k,
    input wire [`ROB_WIDTH-1:0] dep_j,
    input wire [`ROB_WIDTH-1:0] dep_k,
    input wire [`ROB_WIDTH-1:0] rob_id,

    // from rs
    input wire rs_ready,
    input wire [`ROB_WIDTH-1:0] rs_rob_id,
    input wire [31 : 0] rs_value,

    // from lsb
    input wire lsb_ready,
    input wire [`ROB_WIDTH-1:0] lsb_rob_id,
    input wire [31 : 0] lsb_value,

    // broadcast that a rob is ready
    output wire ready,
    output wire [`ROB_WIDTH-1:0] dest_rob_id,
    output wire [31:0] value

    
);

    reg busy [0:`RS_SIZE-1];
    reg [3:0] inst_type[0:`RS_SIZE-1];
    reg [8:0] inst_op[0:`RS_SIZE-1];
    reg [31:0] vj[0:`RS_SIZE-1];
    reg [31:0] vk[0:`RS_SIZE-1];
    reg dj[0:`RS_SIZE-1];
    reg dk[0:`RS_SIZE-1];
    reg [`ROB_WIDTH-1:0] qj[0:`RS_SIZE-1]; // dependence of vj
    reg [`ROB_WIDTH-1:0] qk[0:`RS_SIZE-1];
    reg [31:0] a[0:`RS_SIZE-1];
    reg [`ROB_WIDTH-1:0] rob_dest[0:`RS_SIZE-1]; // which rob depends on this
    reg val_ready [0:`RS_SIZE-1];

    wire calc_enable;
    wire [`RS_WIDTH-1:0] pos_calc;
    wire calc [`RS_SIZE-1:0];
    wire has_idle;
    wire [`RS_WIDTH-1:0] pos_idle;

    genvar i;
    generate 
        wire fcalc_enable [`RS_SIZE-1:0];
        wire [`RS_WIDTH-1:0] fpos_calc [`RS_SIZE-1:0];
        wire fhas_idle [`RS_SIZE-1:0];
        wire [`RS_WIDTH-1:0] fpos_idle [`RS_SIZE-1:0];
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            assign calc[i] = busy[i] && (!dj[i] && !dk[i]);
            if (i != 0) begin
                assign fcalc_enable[i] = calc[i] || fcalc_enable[i-1];
                assign fpos_calc[i] = fcalc_enable[i] ? i : fpos_calc[i-1];
                assign fhas_idle[i] = !busy[i] && fhas_idle[i-1];
                assign fpos_idle[i] = fhas_idle[i] ? i : fpos_idle[i-1];
            end
        end
        assign calc_enable = fcalc_enable[`RS_SIZE-1];
        assign pos_calc = fpos_calc[`RS_SIZE-1];
        assign has_idle = fhas_idle[`RS_SIZE-1];
        assign pos_idle = fpos_idle[`RS_SIZE-1];
    endgenerate

    alu_rs alu(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        
        .calc_enable(calc_enable),
        .clear(clear),

        .lhs(vj[pos_calc]),
        .rhs(vk[pos_calc]),
        .op(inst_op[pos_calc]),
        .rob_dep(rob_dest[pos_calc]),

        .ready(ready),
        .rob_id(dest_rob_id),
        .value(value)
        
    );

    always @(posedge clk_in) begin: Main
        integer i;
        if (rst_in  || (clear && rdy_in)) begin
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                busy[i] <= 0;
                inst_type[i] <= 0;
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
        end else if (rdy_in) begin
            // update dependence
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                if(busy[i] && rs_ready) begin
                    if (dj[i] && qj[i] == rs_rob_id) begin
                        vj[i] <= rs_value;
                        dj[i] <= 0;
                    end
                    if (dk[i] && qk[i] == rs_rob_id) begin
                        vk[i] <= rs_value;
                        dk[i] <= 0;
                    end
                end
                if(busy[i] && lsb_ready) begin
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
                busy[pos_idle] <= 1;
                inst_type[pos_idle] <= type;
                inst_op[pos_idle] <= op;
                vj[pos_idle] = !has_dep_j ? val_j : (rs_ready && dep_j == rs_rob_id) ? rs_value : (lsb_ready && dep_j == lsb_rob_id) ? lsb_value : 0;
                vk[pos_idle] = !has_dep_k ? val_k : (rs_ready && dep_k == rs_rob_id) ? rs_value : (lsb_ready && dep_k == lsb_rob_id) ? lsb_value : 0;
                dj[pos_idle] <= has_dep_j && !(rs_ready && dep_j == rs_rob_id) && !(lsb_ready && dep_j == lsb_rob_id);
                dk[pos_idle] <= has_dep_k && !(rs_ready && dep_k == rs_rob_id) && !(lsb_ready && dep_k == lsb_rob_id);
                qj[pos_idle] <= dep_j;
                qk[pos_idle] <= dep_k;
                rob_dest[pos_idle] <= rob_id;
            end
        end
    end


endmodule
