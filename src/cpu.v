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


    wire dec2mem_if_enable;
    wire [31:0] dec2mem_if_addr;
    wire mem2dec_if_ready;
    wire [31:0] mem2dec_inst;

    memctrl mc(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .clear(1'b0),

        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),

        .io_buffer_full(io_buffer_full),

        .if_enable(dec2mem_if_enable),
        .inst_addr(dec2mem_if_addr),
        .if_ready(mem2dec_if_ready),
        .inst(mem2dec_inst),

        .ls_enable(1'b0),
        .is_write(1'b0),
        .ls_addr(32'h0),
        .store_val(32'h0),
        .lsb_type(4'b1111),
        .ls_finished(),
        .load_val()
    );

    decoder dec(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .clear(1'b0),

        .new_inst_addr(32'h0),
        .melt(1'b0),

        .if_enable(dec2mem_if_enable),
        .if_addr(dec2mem_if_addr),
        .inst_ready(mem2dec_if_ready),
        .inst(mem2dec_inst),

        .rob_full(1'b0),
        .empty_rob_id(4'b0),
        .corr_inst_addr(32'h0),
        .rob_issue_ready(),
        .rob_inst_addr(),
        .rob_jump_addr(),
        .rob_type(),
        .rob_rd(),

        .rs_full(1'b0),
        .rs_issue_ready(),
        .rs_type(),
        .rs_val_j(),
        .rs_val_k(),
        .rs_has_dep_j(),
        .rs_has_dep_k(),
        .rs_dep_j(),
        .rs_dep_k(),
        .rs_rob_id(),
        .rs_true_addr(),
        .rs_false_addr(),

        .lsb_full(1'b0),
        .lsb_issue_ready(),
        .lsb_type(),
        .lsb_val_j(),
        .lsb_val_k(),
        .lsb_has_dep_j(),
        .lsb_has_dep_k(),
        .lsb_dep_j(),
        .lsb_dep_k(),
        .lsb_rob_id(),
        .lsb_imm(),

        .get_reg_1(),
        .get_reg_2(),
        .get_val_1(),
        .get_val_2(),
        .has_dep_1(),
        .has_dep_2(),
        .get_dep_1(),
        .get_dep_2()


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