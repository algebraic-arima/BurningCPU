module icache(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    // query
    input icache_get_ready,
    input wire [31:0] icache_get_addr,  // address to read
    output wire hit,
    output wire [31:0] icache_get_inst,  // data output bus
    output wire icache_get_is_c,

    // write
    input wire wr_ready,
    input wire wr_is_c,
    input wire [31:0] wr_addr,
    input wire [31:0] wr_inst

);

    localparam INDEX_SIZE = 256;
    localparam INDEX_WIDTH = 8;

    // direct mapping cache
    reg valid [0:INDEX_SIZE-1];
    reg is_c [0:INDEX_SIZE-1];
    reg [30-INDEX_WIDTH:0] tag[0:INDEX_SIZE-1];
    reg [31:0] data[0:INDEX_SIZE-1];

    assign hit = icache_get_ready && valid[icache_get_addr[INDEX_WIDTH:1]] && tag[icache_get_addr[INDEX_WIDTH:1]] == icache_get_addr[31:INDEX_WIDTH+1];
    assign icache_get_inst = data[icache_get_addr[INDEX_WIDTH:1]];
    assign icache_get_is_c = is_c[icache_get_addr[INDEX_WIDTH:1]];

    always @(posedge clk_in) begin: Main
        integer i;
        if (rst_in) begin
            for(i = 0; i < INDEX_SIZE; i = i + 1) begin
                valid[i] <= 1'b0;
                is_c[i] <= 1'b0;
                tag[i] <= 0;
                data[i] <= 0;
            end
        end else if (rdy_in && wr_ready) begin
            valid[wr_addr[INDEX_WIDTH:1]] <= 1'b1;
            is_c[wr_addr[INDEX_WIDTH:1]] <= wr_is_c;
            tag[wr_addr[INDEX_WIDTH:1]] <= wr_addr[31:INDEX_WIDTH+1];
            data[wr_addr[INDEX_WIDTH:1]] <= wr_inst;
        end
    end

endmodule