module adder_2_cycles(
    input  wire         clk,
    input  wire         rst_n,
    input  wire [31:0]  a,
    input  wire [31:0]  b,
    input  wire         valid_in,
    output reg  [31:0]  sum,
    output reg          valid_out
);

    reg         valid_reg;
    reg [31:0]  a_reg;
    reg [31:0]  b_reg;

endmodule
