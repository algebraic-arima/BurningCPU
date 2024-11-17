module memctrl(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire clear,

    input  wire [ 7 : 0] mem_din,   // data input bus
    output wire en_in,    // chip enable
    output wire r_nw_in,  // read/write select (read: 1, write: 0)
    output wire [ 7 : 0] mem_dout,  // data output bus
    output wire [31 : 0] mem_a,     // address bus (only 17 : 0 is used)
    output wire          mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    // from to decoder
    input wire if_enable,
    input wire [31:0] inst_addr,
    output wire if_ready,
    output wire [31:0] inst,

    // from to lsb
    input wire ls_enable,
    input wire is_write,
    input wire [31:0] ls_addr,
    input wire [31:0] store_val,
    input wire [3:0] lsb_type, // 0 for byte, 1 for half, 2 for word
    output wire ls_finished,
    output wire [31:0] load_val

);

    reg active;
    reg is_if;

    reg [1:0] state;
    reg [3:0] type; // {inst[5], inst[14:12]} 

    reg [31:0] working_addr; // base addr
    reg [31:0] cur_addr; // now it is fetching the byte of cur_addr
    reg [7:0] cur_store_val;
    reg [31:0] cur_read_result;

    reg ready;

    wire if_read_ready = !io_buffer_full && if_enable;
    wire lsb_read_ready = !io_buffer_full && ls_enable && !lsb_type[3];
    wire write_ready = !io_buffer_full && ls_enable && lsb_type[3];
    wire next_is_if = !ls_enable && if_enable;
    wire [3:0] next_type = next_is_if ? 4'b0010 : lsb_type;
    assign mem_a = state == 2'b00 ? (lsb_read_ready ? ls_addr : (if_read_ready ? inst_addr : 0)) : cur_addr;
 
    always @(posedge clk_in) begin: Main
        if (rst_in || rdy_in && clear) begin
            active <= 0;
            state <= 2'b00;
        end else if (rdy_in) begin
            case(state)
                2'b00: begin // idle, see if ready to read
                    if (lsb_read_ready) begin
                        
                    end else if (if_read_ready) begin
                        if (next_type == 4'b0010) begin // load 4 bytes
                            working_addr <= inst_addr;
                            cur_addr <= inst_addr + 1;
                            state <= 2'b01;
                            cur_read_result[7:0] <= mem_dout;
                        end else if (next_type == 4'b0001) begin // load 2 bytes
                            working_addr <= inst_addr;
                            cur_addr <= inst_addr + 1;
                            state <= 2'b01;
                        end else if (next_type == 4'b0000) begin // load 1 bytes
                            working_addr <= inst_addr;
                            state <= 2'b00;

                        end
                    end else if (write_ready) begin
                        
                    end
                end
                2'b01: begin // the first byte fetched/stored
                    
                end
                2'b10: begin // the second byte fetched/stored
                    
                end
                2'b11: begin // the third byte fetched/stored
                    
                end
            endcase
        end

    end

    

endmodule