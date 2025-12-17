// Vector Register File for 64-bit VLEN
// 32 vector registers, each 64-bit wide (VLEN=64)
// 2 read ports(rdata1, rdata2), 1 write port(wdata)
// v0 is hardwired to zero (same)

module vreg_file(
    input wire clk,
    input wire wen,
    input wire [4:0] vs1, // source register 1 index
    input wire [4:0] vs2, // source register 2 index
    input wire [4:0] vd, // destination register index
    input wire [63:0] wdata,
    output wire [63:0] rdata1,
    output wire [63:0] rdata2
);

    // 32 vector registers, each 64-bit wide
    reg [63:0] vregs [0:31];

    // non-zero index registers are read asynchronously
    assign rdata1 = (vs1 != 5'd0) ? vregs[vs1] : 64'd0;
    assign rdata2 = (vs2 != 5'd0) ? vregs[vs2] : 64'd0;

    // write operation, write enable & non-zero idx reg write synchronous
    always @(posedge clk) begin
        if (wen && (vd != 5'd0)) begin
            vregs[vd] <= wdata;
        end
    end
    
    // initialize all registers to zero
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            vregs[i] <= 64'd0;
        end
    end
endmodule

