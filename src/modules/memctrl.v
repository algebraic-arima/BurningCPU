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
    output reg if_ready,
    output wire [31:0] inst,
    output wire is_c,

    // from to lsb
    input wire ls_enable,
    input wire [31:0] ls_addr,
    input wire [31:0] store_val,
    input wire [3:0] lsb_type, // 0 for byte, 1 for half, 2 for word
    output reg ls_finished,
    output wire [31:0] load_val,

    // from to icache
    output wire icache_enable,
    output wire [31:0] icache_addr,
    input wire icache_hit,
    input wire [31:0] icache_data,
    output wire [31:0] write_ready,
    output wire [31:0] write_addr,
    output wire [31:0] write_inst

);

    reg active;
    reg is_if;

    reg [2:0] state; // 5 states, 000 for idle
    reg [3:0] type; // {inst[5], inst[14:12]}; 1111 for doing nothing

    reg [31:0] base_addr; // base addr
    reg [31:0] cur_addr; // now it is fetching the byte of cur_addr
    reg [31:0] cur_store_val;
    reg [31:0] cur_read_result;
    reg [7:0] cur_store_byte;

    assign mem_a = cur_addr;
    // assign en_in = state == 2'b00 ? (lsb_read_enable || if_read_enable) : 1;
    assign inst = load_val;
    assign load_val = state == 3'b000 ? 
                        icache_hit ? icache_data :
                        type[2:0] == 3'b000 ? {24'b0, mem_din} :
                        type[2:0] == 3'b001 ? {16'b0, mem_din, cur_read_result[7:0]} :
                        type[2:0] == 3'b010 ? {mem_din, cur_read_result[23:0]} :
                        type[2:0] == 3'b100 ? {{24{mem_din[7]}}, mem_din} :
                        type[2:0] == 3'b101 ? {{16{mem_din[7]}}, mem_din, cur_read_result[7:0]} :
                        0 : 0;
    assign mem_dout = cur_store_val[7:0];
    assign mem_wr = type[3] && (state != 2'b00);
    assign is_c = is_if && type == 4'b0001;

    always @(posedge clk_in) begin: Main
        if (rst_in || rdy_in && clear) begin
            active <= 0;
            state <= 3'b000;
            type <= 4'b0111;
            base_addr <= 0;
            cur_addr <= 0;
            cur_store_val <= 0;
            cur_read_result <= 0;
            is_if <= 0;
            ls_finished <= 0;
            if_ready <= 0;
        end else if (rdy_in) begin
            case(state)
                3'b000: begin // idle, see if ready to read
                    ls_finished <= 0;
                    if_ready <= 0;
                    if (!io_buffer_full && ls_enable) begin
                        state <= 3'b001;
                        type <= lsb_type;
                        base_addr <= ls_addr;
                        cur_addr <= ls_addr;
                        cur_store_val <= store_val;
                        is_if <= 0;
                    end else if (!io_buffer_full && if_enable) begin
                        state <= 3'b001;
                        type <= 4'b0010;
                        base_addr <= inst_addr;
                        cur_addr <= inst_addr;
                        is_if <= 1;
                    end
                end
                3'b001: begin // the first byte fetched/stored
                    if (type[3]) begin
                        if (type[1:0] == 2'b00) begin
                            state <= 3'b000;
                            ls_finished <= 1;
                            if_ready <= 0; // sb
                        end else begin
                            state <= 3'b010;
                            cur_store_val <= {8'b0, cur_store_val[31:8]};
                            cur_addr <= cur_addr + 1;
                        end
                    end else begin
                        if (type[1:0] == 2'b00) begin
                            state <= 3'b000;
                            ls_finished <= 1;
                            if_ready <= 0; // lb
                        end else begin
                            state <= 3'b010;
                            cur_addr <= cur_addr + 1;
                        end
                    end
                end
                3'b010: begin // the second byte fetched/stored
                    if (type[3]) begin
                        if (type[1:0] == 2'b01) begin
                            state <= 3'b000;
                            ls_finished <= 1;
                            if_ready <= 0; // sh
                        end else begin
                            cur_store_val <= {8'b0, cur_store_val[31:8]};
                            cur_addr <= cur_addr + 1;
                            state <= 3'b011;
                        end
                    end else begin
                        cur_read_result[7:0] <= mem_din;
                        if (type[1:0] == 2'b01) begin
                            state <= 3'b000;
                            ls_finished <= 1;
                            if_ready <= 0; // lh
                        end else begin
                            if (is_if && !(mem_din[0] && mem_din[1])) begin
                                type <= 3'b001;
                                state <= 3'b000;
                                ls_finished <= 0;
                                if_ready <= 1; // rv32c inst
                            end else begin
                                cur_addr <= cur_addr + 1;
                                state <= 3'b011;
                            end
                        end
                    end
                end
                3'b011: begin // the third byte fetched/stored
                    if (type[3]) begin
                        cur_store_val <= {8'b0, cur_store_val[31:8]};
                        cur_addr <= cur_addr + 1;
                        state <= 3'b100;
                    end else begin
                        cur_read_result[15:8] <= mem_din;
                        cur_addr <= cur_addr + 1;
                        state <= 3'b100;
                    end
                end
                3'b100: begin // the last byte fetched/stored
                    if (type[3]) begin
                        state <= 3'b000;
                    end else begin
                        cur_read_result[23:16] <= mem_din;
                        state <= 3'b000;
                    end
                    if (is_if) begin
                        if_ready <= 1;
                        ls_finished <= 0;
                    end else begin
                        if_ready <= 0;
                        ls_finished <= 1;
                    end
                end
                default: begin
                    state <= 3'b000;
                    ls_finished <= 0;
                    if_ready <= 0;
                end
            endcase
        end

    end

    

endmodule