module vmac(
    input wire clk,
    input wire rst_n, // for active low reset
    input wire [1:0] ctrl,
    input wire [31:0] a,
    input wire [31:0] b,
    input wire valid_in,
    output reg valid_out,
    output reg [31:0] result
);

    // byte segmentation
    wire [7:0] a0 = a[7:0];
    wire [7:0] a1 = a[15:8];
    wire [7:0] a2 = a[23:16];
    wire [7:0] a3 = a[31:24];

    wire [7:0] b0 = b[7:0];
    wire [7:0] b1 = b[15:8];
    wire [7:0] b2 = b[23:16];
    wire [7:0] b3 = b[31:24];

    // sign extension
    wire [15:0] a0_signed = {{8{a0[7]}}, a0};
    wire [15:0] a1_signed = {{8{a1[7]}}, a1};
    wire [15:0] a2_signed = {{8{a2[7]}}, a2};
    wire [15:0] a3_signed = {{8{a3[7]}}, a3};
    wire [15:0] b0_signed = {{8{b0[7]}}, b0};
    wire [15:0] b1_signed = {{8{b1[7]}}, b1};
    wire [15:0] b2_signed = {{8{b2[7]}}, b2};
    wire [15:0] b3_signed = {{8{b3[7]}}, b3};

    // fsm and coutner
    reg [2:0] cycle_counter; // for counting cycles
    reg computing; // indicates if computation is ongoing

    // save the intermediate results
    reg [15:0] mult_results [0:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 3'b0;
            computing <= 1'b0;
            result <= 32'b0;
            valid_out <= 1'b0;
        end else if (valid_in && !computing) begin
            case (ctrl)
                2'b00, 2'b01, 2'b10, 2'b11: begin
                    computing <= 1'b1;
                    cycle_counter <= 3'b0;
                end
            endcase
        end
        else if (computing) begin // after 1 cycle , 컴퓨팅 처리 똑바로
            case (ctrl)
                2'b00: begin // PVADD 1 cycle
                    result[7:0] <= (a0_signed + b0_signed)[7:0];
                    result[15:8] <= (a1_signed + b1_signed)[7:0];
                    result[23:16] <= (a2_signed + b2_signed)[7:0];
                    result[31:24] <= (a3_signed + b3_signed)[7:0];
                    valid_out <= 1'b1;
                    computing <= 1'b0;
                end
                2'b01: begin // PVMUL 4 cycles
                    case (cycle_counter)
                        3'd0: begin
                            mult_results[0] <= a0_signed * b0_signed;
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd1: begin
                            mult_results[1] <= a1_signed * b1_signed;
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd2: begin
                            result[15:0] <= mult_results[0];
                            result[31:16] <= mult_results[1];
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd3: begin
                            valid_out <= 1'b1;
                            computing <= 1'b0;
                            cycle_counter <= 3'b0;
                        end
                    endcase
                end
                2'b10: begin // PVMAC 5 cycles
                    case (cycle_counter)
                        3'd0: begin
                            mult_results[0] <= a0_signed * b0_signed;
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd1: begin
                            mult_results[1] <= a1_signed * b1_signed;
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd2: begin
                            mult_results[2] <= a2_signed * b2_signed;
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd3: begin
                            mult_results[3] <= a3_signed * b3_signed;
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd4: begin
                            // sign extend 16-bit to 32-bit and accumulate
                            result <= {mult_results[0][15] ? 16'hFFFF : 16'h0000, mult_results[0]} +
                                      {mult_results[1][15] ? 16'hFFFF : 16'h0000, mult_results[1]} +
                                      {mult_results[2][15] ? 16'hFFFF : 16'h0000, mult_results[2]} +
                                      {mult_results[3][15] ? 16'hFFFF : 16'h0000, mult_results[3]};
                            valid_out <= 1'b1;
                            computing <= 1'b0;
                            cycle_counter <= 3'b0;
                        end
                    endcase
                end
                2'b11: begin // PVMUL_UPPER 4 cycles
                    case (cycle_counter)
                        3'd0: begin
                            mult_results[0] <= a2_signed * b2_signed;
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd1: begin
                            mult_results[1] <= a3_signed * b3_signed;
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd2: begin
                            result[15:0] <= mult_results[0];
                            result[31:16] <= mult_results[1];
                            cycle_counter <= cycle_counter + 1'b1;
                        end
                        3'd3: begin
                            valid_out <= 1'b1;
                            computing <= 1'b0;
                            cycle_counter <= 3'b0;
                        end
                    endcase
                end
            endcase
        end 
        else begin if (valid_out) 
            begin
            valid_out <= 1'b0;
            end
        end
    end
endmodule