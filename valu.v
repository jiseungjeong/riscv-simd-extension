// vector ALU for 64-bit VLEN
// VADD, VSUB, VMUL are supported
// SEW: 8-bit(int8, 8 lanes), 16-bit(int16, 4 lanes), 32-bit(int32, 2 lanes)

module valu(
    input wire clk,
    input wire rst_n,
    input wire [1:0] op, // 00=VADD, 01=VSUB, 10=VMUL
    input wire [1:0] sew, // 00=8bit, 01=16bit, 10=32bit
    input wire [63:0] vs1_data, // source operand 1
    input wire [63:0] vs2_data, // source operand 2
    input wire valid_in, // start operation
    output reg valid_out, // result ready
    output reg [63:0] result // output result
);

    // opcodes
    localparam OP_VADD = 2'b00;
    localparam OP_VSUB = 2'b01;
    localparam OP_VMUL = 2'b10;
    localparam OP_VMAC = 2'b11;  // 8-lane multiply-accumulate (result = sum of products)
    
    // SEW codes
    localparam SEW_8 = 2'b00;
    localparam SEW_16 = 2'b01;
    localparam SEW_32 = 2'b10;
    
    // 1. lane extraction based on SEW

    // SEW=8: 8 lanes
    wire signed [7:0] a8 [0:7];
    wire signed [7:0] b8 [0:7];
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin: gen_lanes_8
            // assign a8[i] = vs1_data[i*8 +: 8];
            // assign b8[i] = vs2_data[i*8 +: 8];
            assign a8[i] = vs1_data[i*8 +: 8];
            assign b8[i] = vs2_data[i*8 +:8];
        end
    endgenerate

    // SEW=16: 4 lanes
    wire signed [15:0] a16 [0:3];
    wire signed [15:0] b16 [0:3];
    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin: gen_lanes_16
            assign a16[j] = vs1_data[j*16 +: 16];
            assign b16[j] = vs2_data[j*16 +: 16];
        end
    endgenerate

    // SEW=32: 2 lanes
    wire signed [31:0] a32 [0:1];
    wire signed [31:0] b32 [0:1];
    genvar k;
    generate
        for (k = 0; k < 2; k = k + 1) begin: gen_lanes_32
            assign a32[k] = vs1_data[k*32 +: 32];
            assign b32[k] = vs2_data[k*32 +: 32];
        end
    endgenerate


    // 2. combinational results for VADD/VSUB (single cycle)

    // SEW=8 results
    wire [7:0] add8 [0:7];
    wire [7:0] sub8 [0:7];
    generate
        for (i = 0; i < 8; i = i + 1) begin: gen_addsub_8
            assign add8[i] = a8[i] + b8[i];
            assign sub8[i] = a8[i] - b8[i];
        end
    endgenerate

    // SEW=16 results
    wire [15:0] add16 [0:3];
    wire [15:0] sub16 [0:3];
    generate
        for (j = 0; j < 4; j = j + 1) begin: gen_addsub_16
            assign add16[j] = a16[j] + b16[j];
            assign sub16[j] = a16[j] - b16[j];
        end
    endgenerate

    // SEW=32 results
    wire [31:0] add32 [0:1];
    wire [31:0] sub32 [0:1];
    generate
        for (k = 0; k < 2; k = k + 1) begin: gen_addsub_32
            assign add32[k] = a32[k] + b32[k];
            assign sub32[k] = a32[k] - b32[k];
        end
    endgenerate

    // pack add/sub results
    wire [63:0] vadd_result;
    wire [63:0] vsub_result;

    assign vadd_result = (sew == SEW_8) ? {add8[7], add8[6], add8[5], add8[4],
                                             add8[3], add8[2], add8[1], add8[0]} :
                        (sew == SEW_16) ? {add16[3], add16[2], add16[1], add16[0]} :
                                        {add32[1], add32[0]};

    assign vsub_result = (sew == SEW_8) ? {sub8[7], sub8[6], sub8[5], sub8[4],
                                             sub8[3], sub8[2], sub8[1], sub8[0]} :
                        (sew == SEW_16) ? {sub16[3], sub16[2], sub16[1], sub16[0]} :
                                        {sub32[1], sub32[0]};
    
    // VMAC: multiply-accumulate (sum of products) - SEW dependent
    // Result is 32-bit scalar stored in lower 32 bits of result
    
    // SEW=8: 8 lanes, int8 * int8 = 16-bit products, sum to 32-bit
    wire signed [15:0] prod8_mac [0:7];
    generate
        for (i = 0; i < 8; i = i + 1) begin: gen_vmac_prod8
            assign prod8_mac[i] = $signed(a8[i]) * $signed(b8[i]);
        end
    endgenerate
    wire signed [31:0] vmac_sum_8;
    assign vmac_sum_8 = {{16{prod8_mac[0][15]}}, prod8_mac[0]} + {{16{prod8_mac[1][15]}}, prod8_mac[1]} + 
                        {{16{prod8_mac[2][15]}}, prod8_mac[2]} + {{16{prod8_mac[3][15]}}, prod8_mac[3]} +
                        {{16{prod8_mac[4][15]}}, prod8_mac[4]} + {{16{prod8_mac[5][15]}}, prod8_mac[5]} + 
                        {{16{prod8_mac[6][15]}}, prod8_mac[6]} + {{16{prod8_mac[7][15]}}, prod8_mac[7]};
    
    // SEW=16: 4 lanes, int16 * int16 = 32-bit products, sum to 32-bit (truncated)
    wire signed [31:0] prod16_mac [0:3];
    generate
        for (j = 0; j < 4; j = j + 1) begin: gen_vmac_prod16
            assign prod16_mac[j] = $signed(a16[j]) * $signed(b16[j]);
        end
    endgenerate
    wire signed [31:0] vmac_sum_16;
    assign vmac_sum_16 = prod16_mac[0] + prod16_mac[1] + prod16_mac[2] + prod16_mac[3];
    
    // SEW=32: 2 lanes, int32 * int32 = 64-bit products, sum to 32-bit (truncated)
    wire signed [63:0] prod32_mac [0:1];
    generate
        for (k = 0; k < 2; k = k + 1) begin: gen_vmac_prod32
            assign prod32_mac[k] = $signed(a32[k]) * $signed(b32[k]);
        end
    endgenerate
    wire signed [31:0] vmac_sum_32;
    assign vmac_sum_32 = prod32_mac[0][31:0] + prod32_mac[1][31:0];
    
    // Select VMAC result based on SEW
    wire signed [31:0] vmac_sum;
    assign vmac_sum = (sew == SEW_8)  ? vmac_sum_8  :
                      (sew == SEW_16) ? vmac_sum_16 :
                                        vmac_sum_32;

    // 3. multi-cycle VMUL

    reg [2:0] mul_counter;
    reg computing;

    // multiply results storage
    reg [7:0] mul8 [0:7];
    reg [15:0] mul16 [0:3];
    reg [31:0] mul32 [0:1];

    always @(posedge clk) begin
        if (!rst_n) begin
            mul_counter <= 3'b0;
            computing <= 1'b0;
            result <= 64'b0;
            valid_out <= 1'b0;
        end else if (valid_in && !computing) begin
            // start new op
            computing <= 1'b1;
            mul_counter <= 3'b0;
            valid_out <= 1'b0;
        end else if (computing) begin
            case (op)
                OP_VADD: begin
                    // single cycle
                    result <= vadd_result;
                    valid_out <= 1'b1;
                    computing <= 1'b0;
                end

                OP_VSUB: begin
                    // single cycle
                    result <= vsub_result;
                    valid_out <= 1'b1;
                    computing <= 1'b0;
                end

                OP_VMAC: begin
                    // single cycle: 8-lane MAC, result is 32-bit scalar
                    result <= {32'd0, vmac_sum};  // store in lower 32 bits
                    valid_out <= 1'b1;
                    computing <= 1'b0;
                end

                OP_VMUL: begin
                    // multi-cycle based on SEW
                    case (sew)
                        SEW_8: begin // 8 multiplies, 2 per cycle = 4 cycles
                            case (mul_counter)
                                3'd0: begin
                                    mul8[0] <= a8[0] * b8[0];
                                    mul8[1] <= a8[1] * b8[1];
                                    mul_counter <= mul_counter + 1'b1;
                                end
                                3'd1: begin
                                    mul8[2] <= a8[2] * b8[2];
                                    mul8[3] <= a8[3] * b8[3];
                                    mul_counter <= mul_counter + 1'b1;
                                end
                                3'd2: begin
                                    mul8[4] <= a8[4] * b8[4];
                                    mul8[5] <= a8[5] * b8[5];
                                    mul_counter <= mul_counter + 1'b1;
                                end
                                3'd3: begin
                                    mul8[6] <= a8[6] * b8[6];
                                    mul8[7] <= a8[7] * b8[7];
                                    mul_counter <= mul_counter + 1'b1;
                                end
                                3'd4: begin
                                    result <= {mul8[7], mul8[6], mul8[5], mul8[4],
                                             mul8[3], mul8[2], mul8[1], mul8[0]};
                                    valid_out <= 1'b1;
                                    computing <= 1'b0;
                                    mul_counter <= 3'd0;
                                end
                                default :mul_counter <= 3'd0;
                            endcase
                        end
                        SEW_16: begin // 4 multiplies, 2 per cycle = 2 cycles
                            case (mul_counter)
                                3'd0: begin
                                    mul16[0] <= a16[0] * b16[0];
                                    mul16[1] <= a16[1] * b16[1];
                                    mul_counter <= mul_counter + 1'b1;
                                end
                                3'd1: begin
                                    mul16[2] <= a16[2] * b16[2];
                                    mul16[3] <= a16[3] * b16[3];
                                    mul_counter <= mul_counter + 1'b1;
                                end
                                3'd2: begin
                                    result <= {mul16[3], mul16[2], mul16[1], mul16[0]};
                                    valid_out <= 1'b1;
                                    computing <= 1'b0;
                                    mul_counter <= 3'd0;
                                end
                                default :mul_counter <= 3'd0;
                            endcase
                        end
                        SEW_32: begin // 2 multiplies, 1 per cycle = 1 cycle
                            case (mul_counter)
                                3'd0: begin
                                    mul32[0] <= a32[0] * b32[0];
                                    mul_counter <= mul_counter + 1'b1;
                                end
                                3'd1: begin
                                    mul32[1] <= a32[1] * b32[1];
                                    mul_counter <= mul_counter + 1'b1;
                                end
                                3'd2: begin
                                    result <= {mul32[1], mul32[0]};
                                    valid_out <= 1'b1;
                                    computing <= 1'b0;
                                    mul_counter <= 3'd0;
                                end
                                default :mul_counter <= 3'd0;
                            endcase
                        end

                        default : begin
                            valid_out <= 1'b1;
                            computing <= 1'b0;
                        end
                    endcase
                end

                default : begin
                    valid_out <= 1'b0;
                    computing <= 1'b0;
                end
            endcase
        end
        else begin
            if (valid_out) begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule
