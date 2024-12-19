// RISCV32 CPU top module
// port modification allowed for debugging purposes

module cpu(
  input  wire                 clk_in,   // system clock signal
  input  wire                 rst_in,   // reset signal
  input  wire                 rdy_in,   // ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,  // data input bus
  output wire [ 7:0]          mem_dout,  // data output bus
  output wire [31:0]          mem_a,   // address bus (only 17:0 is used)
  output wire                 mem_wr,   // write/read signal (1 for write)
 
  input  wire                 io_buffer_full, // 1 if uart buffer is full
 
  output wire [31:0]          dbgreg_dout  // cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

    
    wire clear;
    wire rob_full, rs_full, lsb_full;

    // mem dec
    wire dec2mem_if_enable;
    wire [31:0] dec2mem_if_addr;
    wire mem2dec_if_ready;
    wire [31:0] mem2dec_inst;
    wire mem2dec_is_c;

    // mem lsb
    wire lsb2mem_ls_enable;
    wire [31:0] lsb2mem_ls_addr;
    wire [31:0] lsb2mem_store_val;
    wire [3:0] lsb2mem_lsb_type;
    wire mem2lsb_ls_finished;
    wire [31:0] mem2lsb_load_val;

    // mem icache
    wire mem2ic_ready;
    wire [31:0] mem2ic_get_addr;
    wire ic2mem_hit;
    wire [31:0] ic2mem_get_inst;
    wire ic2mem_get_is_c;
    wire mem2ic_inst_ready;
    wire mem2ic_wr_is_c;
    wire [31:0] mem2ic_wr_addr;
    wire [31:0] mem2ic_wr_inst;

    memctrl mc0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .clear(clear),

        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),

        .io_buffer_full(io_buffer_full),

        .if_enable(dec2mem_if_enable),
        .inst_addr(dec2mem_if_addr),
        .if_ready(mem2dec_if_ready),
        .inst(mem2dec_inst),
        .is_c(mem2dec_is_c),

        .ls_enable(lsb2mem_ls_enable),
        .ls_addr(lsb2mem_ls_addr),
        .store_val(lsb2mem_store_val),
        .lsb_type(lsb2mem_lsb_type),
        .ls_finished(mem2lsb_ls_finished),
        .load_val(mem2lsb_load_val),

        .icache_get_ready(mem2ic_ready),
        .get_icache_addr(mem2ic_get_addr),
        .icache_hit(ic2mem_hit),
        .icache_data(ic2mem_get_inst),
        .icache_data_is_c(ic2mem_get_is_c),
        .wr_ready(mem2ic_inst_ready),
        .wr_is_c(mem2ic_wr_is_c),
        .wr_addr(mem2ic_wr_addr),
        .wr_inst(mem2ic_wr_inst)
    );

    icache ic0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .icache_get_ready(mem2ic_ready),
        .icache_get_addr(mem2ic_get_addr),
        .hit(ic2mem_hit),
        .icache_get_inst(ic2mem_get_inst),
        .icache_get_is_c(ic2mem_get_is_c),

        .wr_ready(mem2ic_inst_ready),
        .wr_is_c(mem2ic_wr_is_c),
        .wr_addr(mem2ic_wr_addr),
        .wr_inst(mem2ic_wr_inst)
    );

    
    // dec reg
    wire dec2reg_has_dep_1;
    wire [4:0] dec2reg_get_reg_1;
    wire [31:0] dec2reg_val_1;
    wire dec2reg_has_dep_2;
    wire [4:0] dec2reg_get_reg_2;
    wire [31:0] dec2reg_val_2;

    wire dec2reg_issue_ready;
    wire [4:0] dec2reg_rd;
    wire [`ROB_WIDTH-1:0] dec2reg_rob_id;

    // reg rob
    wire [`ROB_WIDTH-1:0] reg2rob_search_rob_id_1;
    wire reg2rob_search_in_has_dep_1;
    wire [31:0] reg2rob_search_in_val_1;
    wire [`ROB_WIDTH-1:0] reg2rob_search_rob_id_2;
    wire reg2rob_search_in_has_dep_2;
    wire [31:0] reg2rob_search_in_val_2;

    // rob reg
    wire rob2reg_commit_ready;
    wire [`ROB_WIDTH-1:0] rob2reg_commit_rob_id;
    wire [4:0] rob2reg_commit_reg_id;
    wire [31:0] rob2reg_commit_val;


    // dec rob
    wire [`ROB_WIDTH-1:0] rob2dec_empty_rob_id;
    wire dec2rob_issue_ready;
    wire [31:0] dec2rob_addr;
    wire [31:0] dec2rob_j_addr;
    wire [1:0] dec2rob_type;
    wire [4:0] dec2rob_rd;
    wire rob2dec_melt;
    wire [31:0] rob2dec_corr_jump_addr;

    // dec rs
    wire dec2rs_issue_ready;
    wire [4:0] dec2rs_type;
    wire [`ROB_WIDTH-1:0] dec2rs_rob_id;
    wire [31:0] dec2rs_true_jump_addr;
    wire [31:0] dec2rs_false_jump_addr;

    // rs broadcast to itself
    wire rs_broadcast_ready;
    wire [`ROB_WIDTH-1:0] rs_broadcast_rob_id;
    wire [31:0] rs_broadcast_value; 

    // rs broadcast to lsb
    wire rs_broadcast_ready_lsb;
    wire [`ROB_WIDTH-1:0] rs_broadcast_rob_id_lsb;
    wire [31:0] rs_broadcast_value_lsb;

    // rs broadcast to rob
    wire rs_broadcast_ready_rob;
    wire [`ROB_WIDTH-1:0] rs_broadcast_rob_id_rob;
    wire [31:0] rs_broadcast_value_rob;

    // dec lsb
    wire dec2lsb_issue_ready;
    wire [3:0] dec2lsb_type;
    wire [`ROB_WIDTH-1:0] dec2lsb_rob_id;
    wire [31:0] dec2lsb_imm;
    
    // lsb broadcast
    wire lsb_broadcast_ready;
    wire [`ROB_WIDTH-1:0] lsb_broadcast_rob_id;
    wire [31:0] lsb_broadcast_value;

    // rob lsb
    wire [`ROB_WIDTH-1:0] rob2lsb_head_rob_id;

    // rob rs
    wire rob2rs_search_has_dep_1;
    wire [`ROB_WIDTH-1:0] rob2rs_search_dep_1;
    wire [31:0] rob2rs_search_val_1;
    wire rob2rs_search_has_dep_2;
    wire [`ROB_WIDTH-1:0] rob2rs_search_dep_2;
    wire [31:0] rob2rs_search_val_2;

    // rob lsb
    wire rob2lsb_search_has_dep_1;
    wire [`ROB_WIDTH-1:0] rob2lsb_search_dep_1;
    wire [31:0] rob2lsb_search_val_1;
    wire rob2lsb_search_has_dep_2;
    wire [`ROB_WIDTH-1:0] rob2lsb_search_dep_2;
    wire [31:0] rob2lsb_search_val_2;

    decoder dec0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .clear(clear),

        .melt(rob2dec_melt),

        .if_enable(dec2mem_if_enable),
        .if_addr(dec2mem_if_addr),
        .inst_ready(mem2dec_if_ready),
        .inst_val(mem2dec_inst),
        .is_c(mem2dec_is_c),

        .reg_issue_ready(dec2reg_issue_ready),
        .reg_rd(dec2reg_rd),
        .reg_rob_id(dec2reg_rob_id),

        .rob_full(rob_full),
        .empty_rob_id(rob2dec_empty_rob_id),
        .corr_jump_addr(rob2dec_corr_jump_addr),
        .rob_issue_ready(dec2rob_issue_ready),
        .rob_inst_addr(dec2rob_addr),
        .rob_jump_addr(dec2rob_j_addr),
        .rob_type(dec2rob_type),
        .rob_rd(dec2rob_rd),

        .rs_full(rs_full),
        .rs_issue_ready(dec2rs_issue_ready),
        .rs_type(dec2rs_type),
        .rs_rob_id(dec2rs_rob_id),
        .rs_true_addr(dec2rs_true_jump_addr),
        .rs_false_addr(dec2rs_false_jump_addr),

        .lsb_full(lsb_full),
        .lsb_issue_ready(dec2lsb_issue_ready),
        .lsb_type(dec2lsb_type),
        .lsb_rob_id(dec2lsb_rob_id),
        .lsb_imm(dec2lsb_imm),

        .has_dep_1(dec2reg_has_dep_1),
        .get_reg_1(dec2reg_get_reg_1),
        .val_1(dec2reg_val_1),
        .has_dep_2(dec2reg_has_dep_2),
        .get_reg_2(dec2reg_get_reg_2),
        .val_2(dec2reg_val_2)
    );

    regfile reg0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .clear(clear),

        .commit_ready(rob2reg_commit_ready),
        .commit_reg_id(rob2reg_commit_reg_id),
        .commit_val(rob2reg_commit_val),
        .commit_rob_id(rob2reg_commit_rob_id),

        .issue_reg_ready(dec2reg_issue_ready),
        .issue_reg_rd(dec2reg_rd),
        .issue_rob_id(dec2reg_rob_id),

        .has_dep_1(dec2reg_has_dep_1),
        .get_reg_1(dec2reg_get_reg_1),
        .val_1(dec2reg_val_1),
        .has_dep_2(dec2reg_has_dep_2),
        .get_reg_2(dec2reg_get_reg_2),
        .val_2(dec2reg_val_2),

        .search_has_dep_1(reg2rob_search_in_has_dep_1),
        .search_rob_id_1(reg2rob_search_rob_id_1),
        .tmp_val_1(reg2rob_search_in_val_1),
        .search_has_dep_2(reg2rob_search_in_has_dep_2),
        .search_rob_id_2(reg2rob_search_rob_id_2),
        .tmp_val_2(reg2rob_search_in_val_2)

    );


    rob rob0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .clear(clear),
        .rob_full(rob_full),
        .empty_rob_id(rob2dec_empty_rob_id),

        .dec_ready(dec2rob_issue_ready),
        .addr(dec2rob_addr),
        .j_addr(dec2rob_j_addr),
        .type(dec2rob_type),
        .rd(dec2rob_rd),

        .melt(rob2dec_melt),
        .corr_jump_addr(rob2dec_corr_jump_addr),

        .rs_ready(rs_broadcast_ready_rob),
        .rs_rob_id(rs_broadcast_rob_id_rob),
        .rs_value(rs_broadcast_value_rob),

        .lsb_ready(lsb_broadcast_ready),
        .lsb_rob_id(lsb_broadcast_rob_id),
        .lsb_value(lsb_broadcast_value),

        .head_rob_id(rob2lsb_head_rob_id),

        .commit_ready(rob2reg_commit_ready),
        .commit_reg_id(rob2reg_commit_reg_id),
        .commit_val(rob2reg_commit_val),
        .commit_rob_id(rob2reg_commit_rob_id),

        .search_in_has_dep_1(reg2rob_search_in_has_dep_1),
        .search_rob_id_1(reg2rob_search_rob_id_1),
        .search_in_val_1(reg2rob_search_in_val_1),
        .search_in_has_dep_2(reg2rob_search_in_has_dep_2),
        .search_rob_id_2(reg2rob_search_rob_id_2),
        .search_in_val_2(reg2rob_search_in_val_2),

        .search_has_dep_1_rs(rob2rs_search_has_dep_1),
        .search_dep_1_rs(rob2rs_search_dep_1),
        .search_val_1_rs(rob2rs_search_val_1),
        .search_has_dep_2_rs(rob2rs_search_has_dep_2),
        .search_dep_2_rs(rob2rs_search_dep_2),
        .search_val_2_rs(rob2rs_search_val_2),

        .search_has_dep_1_lsb(rob2lsb_search_has_dep_1),
        .search_dep_1_lsb(rob2lsb_search_dep_1),
        .search_val_1_lsb(rob2lsb_search_val_1),
        .search_has_dep_2_lsb(rob2lsb_search_has_dep_2),
        .search_dep_2_lsb(rob2lsb_search_dep_2),
        .search_val_2_lsb(rob2lsb_search_val_2)

    );

    rs rs0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .rs_full(rs_full),

        .clear(clear),

        .dec_ready(dec2rs_issue_ready),
        .type(dec2rs_type),
        .rob_id(dec2rs_rob_id),
        .tja(dec2rs_true_jump_addr),
        .fja(dec2rs_false_jump_addr),

        .has_dep_j(rob2rs_search_has_dep_1),
        .dep_j(rob2rs_search_dep_1),
        .val_j(rob2rs_search_val_1),
        .has_dep_k(rob2rs_search_has_dep_2),
        .dep_k(rob2rs_search_dep_2),
        .val_k(rob2rs_search_val_2),

        .rs_ready(rs_broadcast_ready),
        .rs_rob_id(rs_broadcast_rob_id),
        .rs_value(rs_broadcast_value),

        .lsb_ready(lsb_broadcast_ready),
        .lsb_rob_id(lsb_broadcast_rob_id),
        .lsb_value(lsb_broadcast_value),

        .ready(rs_broadcast_ready),
        .dest_rob_id(rs_broadcast_rob_id),
        .value(rs_broadcast_value),

        .ready_lsb(rs_broadcast_ready_lsb),
        .dest_rob_id_lsb(rs_broadcast_rob_id_lsb),
        .value_lsb(rs_broadcast_value_lsb),

        .ready_rob(rs_broadcast_ready_rob),
        .dest_rob_id_rob(rs_broadcast_rob_id_rob),
        .value_rob(rs_broadcast_value_rob)
    );

    lsb lsb0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .lsb_full(lsb_full),

        .clear(clear),

        .dec_ready(dec2lsb_issue_ready),
        .type(dec2lsb_type),
        .rob_id(dec2lsb_rob_id),
        .imm(dec2lsb_imm),        

        .has_dep_j(rob2lsb_search_has_dep_1),
        .dep_j(rob2lsb_search_dep_1),
        .val_j(rob2lsb_search_val_1),
        .has_dep_k(rob2lsb_search_has_dep_2),
        .dep_k(rob2lsb_search_dep_2),
        .val_k(rob2lsb_search_val_2),

        .rs_ready(rs_broadcast_ready_lsb),
        .rs_rob_id(rs_broadcast_rob_id_lsb),
        .rs_value(rs_broadcast_value_lsb),

        .lsb_ready(lsb_broadcast_ready),
        .lsb_rob_id(lsb_broadcast_rob_id),
        .lsb_value(lsb_broadcast_value),

        .head_rob_id(rob2lsb_head_rob_id),

        .ls_enable(lsb2mem_ls_enable),
        .addr(lsb2mem_ls_addr),
        .store_val(lsb2mem_store_val),
        .lsb_type(lsb2mem_lsb_type),
        .ls_finished(mem2lsb_ls_finished),
        .load_val(mem2lsb_load_val),

        .ready(lsb_broadcast_ready),
        .dest_rob_id(lsb_broadcast_rob_id),
        .value(lsb_broadcast_value)

    );

    always @(posedge clk_in)
    begin
        if (rst_in)
        begin
        
        end
        else if (!rdy_in)
        begin
        
        end
        else
        begin
        
        end
    end

endmodule