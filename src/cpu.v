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

    // mem lsb
    wire lsb2mem_ls_enable;
    wire [31:0] lsb2mem_ls_addr;
    wire [31:0] lsb2mem_store_val;
    wire [3:0] lsb2mem_lsb_type;
    wire mem2lsb_ls_finished;
    wire [31:0] mem2lsb_load_val;

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

        .ls_enable(lsb2mem_ls_enable),
        .ls_addr(lsb2mem_ls_addr),
        .store_val(lsb2mem_store_val),
        .lsb_type(lsb2mem_lsb_type),
        .ls_finished(mem2lsb_ls_finished),
        .load_val(mem2lsb_load_val)
    );

    
    // dec reg
    wire [4:0] dec2reg_get_reg_1;
    wire [4:0] dec2reg_get_reg_2;
    wire reg2dec_has_dep_1;
    wire reg2dec_has_dep_2;
    wire [31:0] reg2dec_val_1;
    wire [31:0] reg2dec_val_2;
    wire [`ROB_WIDTH-1:0] reg2dec_dep_1;
    wire [`ROB_WIDTH-1:0] reg2dec_dep_2;

    wire dec2reg_issue_ready;
    wire [4:0] dec2reg_rd;
    wire [`ROB_WIDTH-1:0] dec2reg_rob_id;

    // reg rob
    wire [`ROB_WIDTH-1:0] reg2rob_search_rob_id_1;
    wire reg2rob_search_ready_1;
    wire [31:0] reg2rob_search_val_1;
    wire [`ROB_WIDTH-1:0] reg2rob_search_rob_id_2;
    wire reg2rob_search_ready_2;
    wire [31:0] reg2rob_search_val_2;
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
    wire [31:0] dec2rs_val_j;
    wire [31:0] dec2rs_val_k;
    wire dec2rs_has_dep_j;
    wire dec2rs_has_dep_k;
    wire [`ROB_WIDTH-1:0] dec2rs_dep_j;
    wire [`ROB_WIDTH-1:0] dec2rs_dep_k;
    wire [`ROB_WIDTH-1:0] dec2rs_rob_id;
    wire [31:0] dec2rs_true_jump_addr;
    wire [31:0] dec2rs_false_jump_addr;

    // rs broadcast
    wire rs_broadcast_ready;
    wire [`ROB_WIDTH-1:0] rs_broadcast_rob_id;
    wire [31:0] rs_broadcast_value; 

    // dec lsb
    wire dec2lsb_issue_ready;
    wire [3:0] dec2lsb_type;
    wire [31:0] dec2lsb_val_j;
    wire [31:0] dec2lsb_val_k;
    wire dec2lsb_has_dep_j;
    wire dec2lsb_has_dep_k;
    wire [`ROB_WIDTH-1:0] dec2lsb_dep_j;
    wire [`ROB_WIDTH-1:0] dec2lsb_dep_k;
    wire [`ROB_WIDTH-1:0] dec2lsb_rob_id;
    wire [31:0] dec2lsb_imm;
    
    // lsb broadcast
    wire lsb_broadcast_ready;
    wire [`ROB_WIDTH-1:0] lsb_broadcast_rob_id;
    wire [31:0] lsb_broadcast_value;

    // rob lsb
    wire rob2lsb_store_enable;

    decoder dec0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .clear(clear),

        .melt(rob2dec_melt),

        .if_enable(dec2mem_if_enable),
        .if_addr(dec2mem_if_addr),
        .inst_ready(mem2dec_if_ready),
        .inst(mem2dec_inst),

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
        .rs_val_j(dec2rs_val_j),
        .rs_val_k(dec2rs_val_k),
        .rs_has_dep_j(dec2rs_has_dep_j),
        .rs_has_dep_k(dec2rs_has_dep_k),
        .rs_dep_j(dec2rs_dep_j),
        .rs_dep_k(dec2rs_dep_k),
        .rs_rob_id(dec2rs_rob_id),
        .rs_true_addr(dec2rs_true_jump_addr),
        .rs_false_addr(dec2rs_false_jump_addr),

        .lsb_full(lsb_full),
        .lsb_issue_ready(dec2lsb_issue_ready),
        .lsb_type(dec2lsb_type),
        .lsb_val_j(dec2lsb_val_j),
        .lsb_val_k(dec2lsb_val_k),
        .lsb_has_dep_j(dec2lsb_has_dep_j),
        .lsb_has_dep_k(dec2lsb_has_dep_k),
        .lsb_dep_j(dec2lsb_dep_j),
        .lsb_dep_k(dec2lsb_dep_k),
        .lsb_rob_id(dec2lsb_rob_id),
        .lsb_imm(dec2lsb_imm),

        .get_reg_1(dec2reg_get_reg_1),
        .get_reg_2(dec2reg_get_reg_2),
        .get_val_1(reg2dec_val_1),
        .get_val_2(reg2dec_val_2),
        .has_dep_1(reg2dec_has_dep_1),
        .has_dep_2(reg2dec_has_dep_2),
        .get_dep_1(reg2dec_dep_1),
        .get_dep_2(reg2dec_dep_2)
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

        .search_rob_id_1(reg2rob_search_rob_id_1),
        .search_ready_1(reg2rob_search_ready_1),
        .search_val_1(reg2rob_search_val_1),
        .search_rob_id_2(reg2rob_search_rob_id_2),
        .search_ready_2(reg2rob_search_ready_2),
        .search_val_2(reg2rob_search_val_2),

        .issue_reg_ready(dec2reg_issue_ready),
        .issue_reg_rd(dec2reg_rd),
        .issue_rob_id(dec2reg_rob_id),

        .get_reg_1(dec2reg_get_reg_1),
        .get_val_1(reg2dec_val_1),
        .has_dep_1(reg2dec_has_dep_1),
        .get_dep_1(reg2dec_dep_1),
        .get_reg_2(dec2reg_get_reg_2),
        .get_val_2(reg2dec_val_2),
        .has_dep_2(reg2dec_has_dep_2),
        .get_dep_2(reg2dec_dep_2)

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

        .rs_ready(rs_broadcast_ready),
        .rs_rob_id(rs_broadcast_rob_id),
        .rs_value(rs_broadcast_value),

        .lsb_ready(lsb_broadcast_ready),
        .lsb_rob_id(lsb_broadcast_rob_id),
        .lsb_value(lsb_broadcast_value),

        .store_enable(rob2lsb_store_enable),

        .commit_ready(rob2reg_commit_ready),
        .commit_reg_id(rob2reg_commit_reg_id),
        .commit_val(rob2reg_commit_val),
        .commit_rob_id(rob2reg_commit_rob_id),

        .search_rob_id_1(reg2rob_search_rob_id_1),
        .search_rob_id_2(reg2rob_search_rob_id_2),
        .search_ready_1(reg2rob_search_ready_1),
        .search_ready_2(reg2rob_search_ready_2),
        .search_val_1(reg2rob_search_val_1),
        .search_val_2(reg2rob_search_val_2)

    );

    rs rs0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .rs_full(rs_full),

        .clear(clear),

        .dec_ready(dec2rs_issue_ready),
        .type(dec2rs_type),
        .val_j(dec2rs_val_j),
        .val_k(dec2rs_val_k),
        .has_dep_j(dec2rs_has_dep_j),
        .has_dep_k(dec2rs_has_dep_k),
        .dep_j(dec2rs_dep_j),
        .dep_k(dec2rs_dep_k),
        .rob_id(dec2rs_rob_id),
        .tja(dec2rs_true_jump_addr),
        .fja(dec2rs_false_jump_addr),

        .rs_ready(rs_broadcast_ready),
        .rs_rob_id(rs_broadcast_rob_id),
        .rs_value(rs_broadcast_value),

        .lsb_ready(lsb_broadcast_ready),
        .lsb_rob_id(lsb_broadcast_rob_id),
        .lsb_value(lsb_broadcast_value),

        .ready(rs_broadcast_ready),
        .dest_rob_id(rs_broadcast_rob_id),
        .value(rs_broadcast_value)
    );

    lsb lsb0(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .lsb_full(lsb_full),

        .clear(clear),

        .dec_ready(dec2lsb_issue_ready),
        .type(dec2lsb_type),
        .val_j(dec2lsb_val_j),
        .val_k(dec2lsb_val_k),
        .has_dep_j(dec2lsb_has_dep_j),
        .has_dep_k(dec2lsb_has_dep_k),
        .dep_j(dec2lsb_dep_j),
        .dep_k(dec2lsb_dep_k),
        .rob_id(dec2lsb_rob_id),
        .imm(dec2lsb_imm),

        .rs_ready(rs_broadcast_ready),
        .rs_rob_id(rs_broadcast_rob_id),
        .rs_value(rs_broadcast_value),

        .lsb_ready(lsb_broadcast_ready),
        .lsb_rob_id(lsb_broadcast_rob_id),
        .lsb_value(lsb_broadcast_value),

        .store_enable(rob2lsb_store_enable),

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