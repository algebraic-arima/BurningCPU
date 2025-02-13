module rs (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    output wire rs_full,

    input wire clear,

    // from decoder
    input wire dec_ready,
    input wire [4:0] type,
    input wire [`ROB_WIDTH-1:0] rob_id,
    input wire [31:0] tja,
    input wire [31:0] fja,

    // from rob, issue query
    input wire has_dep_j,
    input wire [`ROB_WIDTH-1:0] dep_j,
    input wire [31:0] val_j,
    input wire has_dep_k,
    input wire [`ROB_WIDTH-1:0] dep_k,
    input wire [31:0] val_k,

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
    output wire [31:0] value,

    // broadcast to lsb
    output wire ready_lsb,
    output wire [`ROB_WIDTH-1:0] dest_rob_id_lsb,
    output wire [31:0] value_lsb,

    // broadcast to rob
    output wire ready_rob,
    output wire [`ROB_WIDTH-1:0] dest_rob_id_rob,
    output wire [31:0] value_rob

);

    reg busy [0:`RS_SIZE-1];
    reg [4:0] inst_type[0:`RS_SIZE-1]; // [4] branch, [3] = inst[30], [2:0] = inst[14:12]
    reg [31:0] vj[0:`RS_SIZE-1];
    reg [31:0] vk[0:`RS_SIZE-1];
    reg dj[0:`RS_SIZE-1];
    reg dk[0:`RS_SIZE-1];
    reg [`ROB_WIDTH-1:0] qj[0:`RS_SIZE-1]; // dependence of vj
    reg [`ROB_WIDTH-1:0] qk[0:`RS_SIZE-1];
    reg [31:0] true_jaddr[0:`RS_SIZE-1];
    reg [31:0] false_jaddr[0:`RS_SIZE-1];
    reg [`ROB_WIDTH-1:0] rob_dest[0:`RS_SIZE-1]; // which rob depends on this

    wire calc_enable;
    wire [`RS_WIDTH-1:0] pos_calc;
    wire calc [`RS_SIZE-1:0];
    wire has_idle;
    wire [`RS_WIDTH-1:0] pos_idle;

    genvar i;
    generate 
        wire tmp_calc_enable[0:2*`RS_SIZE-1];
        wire tmp_is_idle[0:2*`RS_SIZE-1];
        wire [`RS_WIDTH-1:0] tmp_pos_calc[0:2*`RS_SIZE-1];
        wire [`RS_WIDTH-1:0] tmp_pos_idle[0:2*`RS_SIZE-1];
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            assign calc[i] = busy[i] && (!dj[i] && !dk[i]);
            assign tmp_calc_enable[i + `RS_SIZE] = calc[i];
            assign tmp_is_idle[i + `RS_SIZE] = !busy[i];
            assign tmp_pos_calc[i + `RS_SIZE] = i;
            assign tmp_pos_idle[i + `RS_SIZE] = i;
            if(i != 0) begin
                assign tmp_calc_enable[i] = tmp_calc_enable[i << 1] || tmp_calc_enable[i << 1 | 1];
                assign tmp_is_idle[i] = tmp_is_idle[i << 1] || tmp_is_idle[i << 1 | 1];
                assign tmp_pos_calc[i] = tmp_calc_enable[i << 1] ? tmp_pos_calc[i << 1] : tmp_pos_calc[i << 1 | 1];
                assign tmp_pos_idle[i] = tmp_is_idle[i << 1] ? tmp_pos_idle[i << 1] : tmp_pos_idle[i << 1 | 1];
            end
        end
        assign calc_enable = tmp_calc_enable[1];
        assign pos_calc = tmp_pos_calc[1];
        assign pos_idle = tmp_pos_idle[1];
        assign has_idle = tmp_is_idle[1];
        assign rs_full = !has_idle;
    endgenerate

    reg enable;
    reg [31:0] lhs,rhs;
    reg [4:0] op;
    reg [`ROB_WIDTH-1:0] rob_dep;
    reg [31:0] true_j, false_j;


    alu alu0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        
        .calc_enable(enable),
        .clear(clear),

        .lhs(lhs),
        .rhs(rhs),
        .op(op),
        .rob_dep(rob_dep),

        .true_jaddr(true_j),
        .false_jaddr(false_j),

        .ready(ready),
        .rob_id(dest_rob_id),
        .value(value),

        .ready_lsb(ready_lsb),
        .rob_id_lsb(dest_rob_id_lsb),
        .value_lsb(value_lsb),

        .ready_rob(ready_rob),
        .rob_id_rob(dest_rob_id_rob),
        .value_rob(value_rob)
        
    );


    always @(posedge clk_in) begin: Main
        integer i;
        if (rst_in  || (clear && rdy_in)) begin
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                busy[i] <= 0;
                inst_type[i] <= 0;
                vj[i] <= 0;
                vk[i] <= 0;
                dj[i] <= 0;
                dk[i] <= 0;
                qj[i] <= 0;
                qk[i] <= 0;
                rob_dest[i] <= 0;
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
                vj[pos_idle] <= !has_dep_j ? val_j : (rs_ready && has_dep_j && dep_j == rs_rob_id) ? rs_value : (lsb_ready && has_dep_j && dep_j == lsb_rob_id) ? lsb_value : 0;
                vk[pos_idle] <= !has_dep_k ? val_k : (rs_ready && has_dep_k && dep_k == rs_rob_id) ? rs_value : (lsb_ready && has_dep_k && dep_k == lsb_rob_id) ? lsb_value : 0;
                dj[pos_idle] <= has_dep_j && !(rs_ready && has_dep_j && dep_j == rs_rob_id) && !(lsb_ready && has_dep_j && dep_j == lsb_rob_id);
                dk[pos_idle] <= has_dep_k && !(rs_ready && has_dep_k && dep_k == rs_rob_id) && !(lsb_ready && has_dep_k && dep_k == lsb_rob_id);
                qj[pos_idle] <= dep_j;
                qk[pos_idle] <= dep_k;
                rob_dest[pos_idle] <= rob_id;
                true_jaddr[pos_idle] <= tja;
                false_jaddr[pos_idle] <= fja;
            end
            // calc
            if (calc_enable) begin
                busy[pos_calc] <= 0;
                enable <= 1;
                lhs <= vj[pos_calc];
                rhs <= vk[pos_calc];
                op <= inst_type[pos_calc];
                rob_dep <= rob_dest[pos_calc];
                true_j <= true_jaddr[pos_calc];
                false_j <= false_jaddr[pos_calc];
            end else begin
                enable <= 0;
            end
        end
    end
    
endmodule