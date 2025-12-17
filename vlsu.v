// vector load/stor unit for 64 bit VLEN
// Uses existing 32-bit memory bus with multi-cycle transfers
// VLD: 2 cycles, VST: 2 cycles (both 32-bit x 2)

module vlsu(
    input wire clk,
    input wire rst_n,

    // control interface
    input wire start,
    input wire is_store, // 0=load, 1=store
    input wire [31:0] base_addr, // from scalar register
    input wire [63:0] store_data, // data to store from vector register

    output reg done,
    output reg [63:0] load_data, // loaded data to vector register

    // memory interface
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [3:0] mem_wmask,
    output reg mem_write,
    output reg mem_valid,
    input wire mem_ready,
    input wire mem_resp_valid,
    input wire [31:0] mem_resp_rdata
);

    // fsm states
    localparam IDLE = 3'd0;
    localparam REQ_WORD0 = 3'd1; // request first 32-bit word
    localparam WAIT_WORD0 = 3'd2; // wait for first word response
    localparam REQ_WORD1 = 3'd3; // request second 32-bit word
    localparam WAIT_WORD1 = 3'd4; // wait for second word response
    localparam COMPLETE = 3'd5; // signal completion

    reg [2:0] state;
    reg [31:0] addr_reg;
    reg [63:0] data_reg;
    reg is_store_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            done <=1'b0;
            load_data <= 64'b0;
            mem_addr <= 32'b0;
            mem_wdata <= 32'b0;
            mem_wmask <= 4'b0;
            mem_write <= 1'b0;
            mem_valid <= 1'b0;
            addr_reg <= 32'b0;
            data_reg <= 64'b0;
            is_store_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // save inputs
                        addr_reg <= base_addr;
                        data_reg <= store_data;
                        is_store_reg <= is_store;
                        state <= REQ_WORD0;
                    end
                end

                REQ_WORD0: begin
                    // request first word (lower 32 bits)
                    mem_addr <= addr_reg;
                    mem_valid <= 1'b1;
                    mem_write <= is_store_reg;


                    if (is_store_reg) begin
                        mem_wdata <= data_reg[31:0]; // lower 32bits
                        mem_wmask <= 4'b1111;
                    end else begin
                        mem_wdata <= 32'd0;
                        mem_wmask <= 4'b0000;
                    end

                    state <= WAIT_WORD0;
                end
                
                WAIT_WORD0: begin
                    if (mem_ready) begin
                        mem_valid <= 1'b0;

                        if (is_store_reg) begin
                            // store: request accepted, move to second word
                            state <= REQ_WORD1;
                        end else begin
                            // load: wait for response
                            if (mem_resp_valid) begin
                                data_reg[31:0] <= mem_resp_rdata; // save lower 32 bits
                                state <= REQ_WORD1;
                            end
                        end
                    end
                    else if (!is_store_reg && mem_resp_valid) begin
                        // load response came before ready (edge case)
                        data_reg[31:0] <= mem_resp_rdata;
                    end
                end

                REQ_WORD1: begin
                    // request second word (upper 32bits)
                    mem_addr <= addr_reg + 32'd4; // next 4 bytes
                    mem_valid <= 1'b1;
                    mem_write <= is_store_reg;

                    if (is_store_reg) begin
                        mem_wdata <= data_reg[63:32]; // upper 32bits
                        mem_wmask <= 4'b1111;
                    end else begin
                        mem_wdata <= 32'd0;
                        mem_wmask <= 4'b0000;
                    end

                    state <= WAIT_WORD1;
                end
                
                WAIT_WORD1: begin
                    if (mem_ready) begin
                        mem_valid <= 1'b0;

                        if (is_store_reg) begin
                            // store complete
                            state <= COMPLETE;
                        end else begin
                            // load, wait for response
                            if (mem_resp_valid) begin
                                data_reg[63:32] <= mem_resp_rdata; // save upper 32 bits
                                state <= COMPLETE;
                            end
                        end
                    end
                    else if (!is_store_reg && mem_resp_valid) begin
                        data_reg[63:32] <= mem_resp_rdata;
                    end
                end
                
                COMPLETE: begin
                    // output result and signal done
                    if (!is_store_reg) begin
                        load_data <= data_reg;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule