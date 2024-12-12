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
    output wire icache_get_ready,
    output reg [31:0] get_icache_addr,
    input wire icache_hit,
    input wire [31:0] icache_data,
    input wire icache_data_is_c,
    output wire wr_ready,
    output wire wr_is_c,
    output reg [31:0] wr_addr,
    output wire [31:0] wr_inst

);

    reg active;
    reg is_if;

    reg [2:0] state; // 5 states, 000 for idle
    reg [3:0] type; // {inst[5], inst[14:12]}; 0111 for doing nothing

    // reg [31:0] base_addr; // base addr is duplicated to get_icache_addr and wr_addr
    reg [31:0] cur_addr; // now it is fetching the byte of cur_addr
    reg [31:0] cur_store_val;
    reg [31:0] cur_read_result;
    reg [7:0] cur_store_byte;

    reg icache_hit_b;
    reg [31:0] icache_inst_b;

    assign mem_a = cur_addr;
    // assign en_in = state == 2'b00 ? (lsb_read_enable || if_read_enable) : 1;
    assign inst = load_val;
    assign load_val = state == 3'b000 ? 
                        icache_hit_b ? icache_inst_b :
                        type[2:0] == 3'b000 ? {24'b0, cur_read_result[7:0]} :
                        type[2:0] == 3'b001 ? {16'b0, cur_read_result[15:0]} :
                        type[2:0] == 3'b010 ? cur_read_result :
                        type[2:0] == 3'b100 ? {{24{cur_read_result[7]}}, cur_read_result[7:0]} :
                        type[2:0] == 3'b101 ? {{16{cur_read_result[15]}}, cur_read_result[15:0]} :
                        0 : 0;
    assign mem_dout = cur_store_val[7:0];
    assign mem_wr = type[3] && (state != 2'b00);
    assign is_c = is_if && type == 4'b0001;
    assign icache_get_ready = state == 3'b001 && is_if;
    assign wr_ready = if_ready;
    assign wr_is_c = is_c;
    assign wr_inst = inst;

    always @(posedge clk_in) begin: Main
        if (rst_in || rdy_in && clear) begin
            active <= 0;
            state <= 3'b000;
            type <= 4'b0111;
            get_icache_addr <= 0;
            wr_addr <= 0;
            cur_addr <= 0;
            cur_store_val <= 0;
            cur_read_result <= 0;
            is_if <= 0;
            ls_finished <= 0;
            if_ready <= 0;
            icache_hit_b <= 0;
            icache_inst_b <= 0;
        end else if (rdy_in) begin
            if (icache_hit_b) begin
                icache_hit_b <= 0;
            end
            case(state)
                3'b000: begin // idle, see if ready to read; 4 in cur_read
                    ls_finished <= 0;
                    if_ready <= 0;
                    if (!io_buffer_full && ls_enable) begin
                        state <= 3'b001;
                        type <= lsb_type;
                        get_icache_addr <= ls_addr;
                        wr_addr <= ls_addr;
                        cur_addr <= ls_addr;
                        cur_store_val <= store_val;
                        is_if <= 0;
                    end else if (!io_buffer_full && if_enable) begin
                        state <= 3'b001;
                        type <= 4'b0010;
                        get_icache_addr <= inst_addr;
                        wr_addr <= inst_addr;
                        cur_addr <= inst_addr;
                        is_if <= 1;
                    end
                end
                3'b001: begin // addr and type ready
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
                            state <= 3'b010;
                            cur_addr <= cur_addr + 1;
                        end else begin
                            if(is_if && icache_hit) begin
                                if (icache_data_is_c) begin
                                    type <= 3'b001;
                                end else begin
                                    type <= 3'b010;
                                end
                                state <= 3'b000;
                                ls_finished <= 0;
                                if_ready <= 1; 
                                icache_hit_b <= 1;
                                icache_inst_b <= icache_data; // rv32ic inst
                            end else begin
                                state <= 3'b010;
                                cur_addr <= cur_addr + 1;
                            end
                        end
                    end
                end
                3'b010: begin // 1 in mem_din, 1 stored
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
                        if (type[1:0] == 2'b00) begin
                            state <= 3'b000;
                            ls_finished <= 1;
                            if_ready <= 0; // lb
                        end else begin
                            if (is_if && !(mem_din[0] && mem_din[1])) begin
                                type <= 3'b001;
                            end 
                            cur_addr <= cur_addr + 1;
                            state <= 3'b011;
                        end
                    end
                end
                3'b011: begin // 1 in cur_read, 2 in mem_din, 2 stored
                    if (type[3]) begin
                        cur_store_val <= {8'b0, cur_store_val[31:8]};
                        cur_addr <= cur_addr + 1;
                        state <= 3'b100;
                    end else begin
                        cur_read_result[15:8] <= mem_din;
                        if (type[1:0] == 2'b01) begin
                            state <= 3'b000;
                            ls_finished <= !is_if;
                            if_ready <= is_if; // lh or rv32c
                        end else begin
                            cur_addr <= cur_addr + 1;
                            state <= 3'b100;
                        end
                    end
                end
                3'b100: begin // 2 in cur_read, 3 in mem_din, 3 stored
                    if (type[3]) begin // store
                        state <= 3'b000;
                        if_ready <= 0;
                        ls_finished <= 1;
                    end else begin // load or ifetch
                        cur_read_result[23:16] <= mem_din;
                        cur_addr <= cur_addr + 1;
                        state <= 3'b101;
                    end
                end
                3'b101: begin // 3 in cur_read, 4 in mem_din, 4 stored
                    cur_read_result[31:24] <= mem_din;
                    state <= 3'b000;
                    if (is_if) begin
                        ls_finished <= 0;
                        if_ready <= 1;
                    end else begin
                        ls_finished <= 1;
                        if_ready <= 0;
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