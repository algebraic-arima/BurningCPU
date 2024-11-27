module memctrl(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input wire clear,

    input  wire [ 7 : 0] mem_din,   // data input bus
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
    input wire [31:0] ls_addr,
    input wire [31:0] store_val,
    input wire [3:0] lsb_type, // 0 for byte, 1 for half, 2 for word
    output wire ls_finished,
    output wire [31:0] load_val

);

    reg active;
    reg is_if;

    reg [1:0] state;
    reg [3:0] type; // {inst[5], inst[14:12]}; 1111 for doing nothing

    reg [31:0] working_addr; // base addr
    reg [31:0] cur_addr; // now it is fetching the byte of cur_addr
    reg [7:0] cur_store_val;
    reg [31:0] cur_read_result;

    reg working;

    assign if_ready = !working && is_if;
    assign ls_finished = !working && !is_if;

    wire if_read_enable = !io_buffer_full && if_enable;
    wire lsb_read_enable = !io_buffer_full && ls_enable && !lsb_type[3];
    wire lsb_write_enable = !io_buffer_full && ls_enable && lsb_type[3];
    wire next_is_if = !ls_enable && if_enable;
    wire [3:0] next_type = next_is_if ? 4'b0010 : lsb_type;
    assign mem_a = state == 2'b00 ? (lsb_read_enable ? ls_addr : (if_read_enable ? inst_addr : 0)) : cur_addr;
    // assign en_in = state == 2'b00 ? (lsb_read_enable || if_read_enable) : 1;
    assign inst = (state == 2'b00 && if_ready) ? 
                    type == 4'b0000 ? mem_din :
                    type == 4'b0001 ? {mem_din, cur_read_result[7:0]} :
                    type == 4'b0010 ? {mem_din[7:0], cur_read_result[23:0]} :
                    0 : 0;
    assign load_val = (state == 2'b00 && ls_finished) ? 
                    type == 4'b0000 ? mem_din :
                    type == 4'b0001 ? {mem_din, cur_read_result[7:0]} :
                    type == 4'b0010 ? {mem_din[7:0], cur_read_result[23:0]} :
                    0 : 0;
    assign mem_dout = store_val[7:0];
    assign mem_wr = lsb_write_enable;

    always @(posedge clk_in) begin: Main
        if (rst_in || rdy_in && clear) begin
            active <= 0;
            state <= 2'b00;
            type <= 4'b1111;
            working_addr <= 0;
            cur_addr <= 0;
            cur_store_val <= 0;
            cur_read_result <= 0;
            working <= 1;
            is_if <= 1;
        end else if (rdy_in) begin
            case(state)
                2'b00: begin // idle, see if ready to read
                    type <= next_type;
                    is_if <= next_is_if;
                    if (lsb_read_enable) begin
                        if (next_type == 4'b0010) begin // load 4 bytes
                            working_addr <= ls_addr;
                            cur_addr <= ls_addr + 1;
                            state <= 2'b01;
                            cur_read_result[7:0] <= mem_din;
                        end else if (next_type == 4'b0001) begin // load 2 bytes
                            working_addr <= ls_addr;
                            cur_addr <= ls_addr + 1;
                            state <= 2'b01;
                        end else if (next_type == 4'b0000) begin // load 1 bytes
                            working_addr <= ls_addr;
                            state <= 2'b00;
                        end
                    end else if (lsb_write_enable) begin
                        if (next_type == 4'b0010) begin // store 4 bytes
                            working_addr <= ls_addr;
                            cur_addr <= ls_addr + 1;
                            state <= 2'b01;
                            cur_read_result[7:0] <= mem_din;
                        end else if (next_type == 4'b0001) begin // store 2 bytes
                            working_addr <= ls_addr;
                            cur_addr <= ls_addr + 1;
                            state <= 2'b01;
                        end else if (next_type == 4'b0000) begin // store 1 bytes
                            working_addr <= ls_addr;
                            state <= 2'b00;
                        end
                    end else if (if_read_enable) begin
                        // load 4 bytes
                        working <= 1;
                        working_addr <= inst_addr;
                        cur_addr <= inst_addr + 1;
                        state <= 2'b01;
                        active <= 1;
                        is_if <= 1;
                    end 
                end
                2'b01: begin // the first byte fetched/stored
                    cur_read_result[7:0] <= mem_din;
                    cur_addr <= cur_addr + 1;
                    state <= 2'b10;
                end
                2'b10: begin // the second byte fetched/stored
                    cur_read_result[15:8] <= mem_din;
                    cur_addr <= cur_addr + 1;
                    state <= 2'b11;
                end
                2'b11: begin // the third byte fetched/stored
                    cur_read_result[23:16] <= mem_din;
                    cur_addr <= cur_addr + 1;
                    working <= 0;
                    state <= 2'b00;
                end
            endcase
        end

    end

    

endmodule