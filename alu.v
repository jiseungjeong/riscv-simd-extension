


module full_adder (
  input a,
  input b,
  input cin,
  output sum,
  output cout
);
  assign sum = a ^ b ^ cin;
  assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

module ripple_carry_adder_32 (
  input [31:0] a,
  input [31:0] b,
  input cin,
  output [31:0] sum,
  output cout
);
  wire [30:0] carry;

  full_adder fa0 (.a(a[0]), .b(b[0]), .cin(cin), .sum(sum[0]), .cout(carry[0]));
  full_adder fa1 (.a(a[1]), .b(b[1]), .cin(carry[0]), .sum(sum[1]), .cout(carry[1]));
  full_adder fa2 (.a(a[2]), .b(b[2]), .cin(carry[1]), .sum(sum[2]), .cout(carry[2]));
  full_adder fa3 (.a(a[3]), .b(b[3]), .cin(carry[2]), .sum(sum[3]), .cout(carry[3]));
  full_adder fa4 (.a(a[4]), .b(b[4]), .cin(carry[3]), .sum(sum[4]), .cout(carry[4]));
  full_adder fa5 (.a(a[5]), .b(b[5]), .cin(carry[4]), .sum(sum[5]), .cout(carry[5]));
  full_adder fa6 (.a(a[6]), .b(b[6]), .cin(carry[5]), .sum(sum[6]), .cout(carry[6]));
  full_adder fa7 (.a(a[7]), .b(b[7]), .cin(carry[6]), .sum(sum[7]), .cout(carry[7]));
  full_adder fa8 (.a(a[8]), .b(b[8]), .cin(carry[7]), .sum(sum[8]), .cout(carry[8]));
  full_adder fa9 (.a(a[9]), .b(b[9]), .cin(carry[8]), .sum(sum[9]), .cout(carry[9]));
  full_adder fa10 (.a(a[10]), .b(b[10]), .cin(carry[9]), .sum(sum[10]), .cout(carry[10]));
  full_adder fa11 (.a(a[11]), .b(b[11]), .cin(carry[10]), .sum(sum[11]), .cout(carry[11]));
  full_adder fa12 (.a(a[12]), .b(b[12]), .cin(carry[11]), .sum(sum[12]), .cout(carry[12]));
  full_adder fa13 (.a(a[13]), .b(b[13]), .cin(carry[12]), .sum(sum[13]), .cout(carry[13]));
  full_adder fa14 (.a(a[14]), .b(b[14]), .cin(carry[13]), .sum(sum[14]), .cout(carry[14]));
  full_adder fa15 (.a(a[15]), .b(b[15]), .cin(carry[14]), .sum(sum[15]), .cout(carry[15]));
  full_adder fa16 (.a(a[16]), .b(b[16]), .cin(carry[15]), .sum(sum[16]), .cout(carry[16]));
  full_adder fa17 (.a(a[17]), .b(b[17]), .cin(carry[16]), .sum(sum[17]), .cout(carry[17]));
  full_adder fa18 (.a(a[18]), .b(b[18]), .cin(carry[17]), .sum(sum[18]), .cout(carry[18]));
  full_adder fa19 (.a(a[19]), .b(b[19]), .cin(carry[18]), .sum(sum[19]), .cout(carry[19]));
  full_adder fa20 (.a(a[20]), .b(b[20]), .cin(carry[19]), .sum(sum[20]), .cout(carry[20]));
  full_adder fa21 (.a(a[21]), .b(b[21]), .cin(carry[20]), .sum(sum[21]), .cout(carry[21]));
  full_adder fa22 (.a(a[22]), .b(b[22]), .cin(carry[21]), .sum(sum[22]), .cout(carry[22]));
  full_adder fa23 (.a(a[23]), .b(b[23]), .cin(carry[22]), .sum(sum[23]), .cout(carry[23]));
  full_adder fa24 (.a(a[24]), .b(b[24]), .cin(carry[23]), .sum(sum[24]), .cout(carry[24]));
  full_adder fa25 (.a(a[25]), .b(b[25]), .cin(carry[24]), .sum(sum[25]), .cout(carry[25]));
  full_adder fa26 (.a(a[26]), .b(b[26]), .cin(carry[25]), .sum(sum[26]), .cout(carry[26]));
  full_adder fa27 (.a(a[27]), .b(b[27]), .cin(carry[26]), .sum(sum[27]), .cout(carry[27]));
  full_adder fa28 (.a(a[28]), .b(b[28]), .cin(carry[27]), .sum(sum[28]), .cout(carry[28]));
  full_adder fa29 (.a(a[29]), .b(b[29]), .cin(carry[28]), .sum(sum[29]), .cout(carry[29]));
  full_adder fa30 (.a(a[30]), .b(b[30]), .cin(carry[29]), .sum(sum[30]), .cout(carry[30]));
  full_adder fa31 (.a(a[31]), .b(b[31]), .cin(carry[30]), .sum(sum[31]), .cout(cout));
endmodule




module barrel_shifter (
  input [31:0] data_in,
  input [4:0] shift_amt,
  input shift_left,
  input arithmetic,
  output [31:0] data_out
);
  wire [31:0] stage0, stage1, stage2, stage3, stage4;
  wire [31:0] reversed_data, final_data;
  wire fill_bit;

  // For left shifts, reverse the data, do right shift, then reverse back
  assign reversed_data[0] = data_in[31];
  assign reversed_data[1] = data_in[30];
  assign reversed_data[2] = data_in[29];
  assign reversed_data[3] = data_in[28];
  assign reversed_data[4] = data_in[27];
  assign reversed_data[5] = data_in[26];
  assign reversed_data[6] = data_in[25];
  assign reversed_data[7] = data_in[24];
  assign reversed_data[8] = data_in[23];
  assign reversed_data[9] = data_in[22];
  assign reversed_data[10] = data_in[21];
  assign reversed_data[11] = data_in[20];
  assign reversed_data[12] = data_in[19];
  assign reversed_data[13] = data_in[18];
  assign reversed_data[14] = data_in[17];
  assign reversed_data[15] = data_in[16];
  assign reversed_data[16] = data_in[15];
  assign reversed_data[17] = data_in[14];
  assign reversed_data[18] = data_in[13];
  assign reversed_data[19] = data_in[12];
  assign reversed_data[20] = data_in[11];
  assign reversed_data[21] = data_in[10];
  assign reversed_data[22] = data_in[9];
  assign reversed_data[23] = data_in[8];
  assign reversed_data[24] = data_in[7];
  assign reversed_data[25] = data_in[6];
  assign reversed_data[26] = data_in[5];
  assign reversed_data[27] = data_in[4];
  assign reversed_data[28] = data_in[3];
  assign reversed_data[29] = data_in[2];
  assign reversed_data[30] = data_in[1];
  assign reversed_data[31] = data_in[0];

  wire [31:0] shift_data;
  assign shift_data = shift_left ? reversed_data : data_in;

  // Fill bit: 0 for logical shifts, sign bit for arithmetic right shifts
  assign fill_bit = (arithmetic & ~shift_left) ? shift_data[31] : 1'b0;

  // 5-stage barrel shifter
  assign stage0 = shift_amt[0] ? {fill_bit, shift_data[31:1]} : shift_data;
  assign stage1 = shift_amt[1] ? {{2{fill_bit}}, stage0[31:2]} : stage0;
  assign stage2 = shift_amt[2] ? {{4{fill_bit}}, stage1[31:4]} : stage1;
  assign stage3 = shift_amt[3] ? {{8{fill_bit}}, stage2[31:8]} : stage2;
  assign stage4 = shift_amt[4] ? {{16{fill_bit}}, stage3[31:16]} : stage3;

  // For left shifts, reverse the result back
  assign final_data[0] = stage4[31];
  assign final_data[1] = stage4[30];
  assign final_data[2] = stage4[29];
  assign final_data[3] = stage4[28];
  assign final_data[4] = stage4[27];
  assign final_data[5] = stage4[26];
  assign final_data[6] = stage4[25];
  assign final_data[7] = stage4[24];
  assign final_data[8] = stage4[23];
  assign final_data[9] = stage4[22];
  assign final_data[10] = stage4[21];
  assign final_data[11] = stage4[20];
  assign final_data[12] = stage4[19];
  assign final_data[13] = stage4[18];
  assign final_data[14] = stage4[17];
  assign final_data[15] = stage4[16];
  assign final_data[16] = stage4[15];
  assign final_data[17] = stage4[14];
  assign final_data[18] = stage4[13];
  assign final_data[19] = stage4[12];
  assign final_data[20] = stage4[11];
  assign final_data[21] = stage4[10];
  assign final_data[22] = stage4[9];
  assign final_data[23] = stage4[8];
  assign final_data[24] = stage4[7];
  assign final_data[25] = stage4[6];
  assign final_data[26] = stage4[5];
  assign final_data[27] = stage4[4];
  assign final_data[28] = stage4[3];
  assign final_data[29] = stage4[2];
  assign final_data[30] = stage4[1];
  assign final_data[31] = stage4[0];

  assign data_out = shift_left ? final_data : stage4;
endmodule

module alu (
  input [31:0] op1,
  input [31:0] op2,
  input [3:0] alu_ctrl,
  output reg [31:0] alu_out,
  output zero
);
  wire [31:0] addsub_result;
  wire [31:0] shift_result;
  wire addsub_cout;
  wire [31:0] op2_modified;
  wire subtract;
  wire slt_result, sltu_result;

  // Shift control signals
  wire shift_left, shift_arith;

  // Determine if we need to subtract (for SUB, SLT, SLTU operations)
  assign subtract = (alu_ctrl == 4'b0001) | (alu_ctrl == 4'b1000) | (alu_ctrl == 4'b1001);

  // For subtraction: invert op2 and set carry-in to 1 (2's complement)
  assign op2_modified = subtract ? ~op2 : op2;

  // Single adder/subtractor unit
  ripple_carry_adder_32 adder_subtractor (
    .a(op1),
    .b(op2_modified),
    .cin(subtract ? 1'b1 : 1'b0),
    .sum(addsub_result),
    .cout(addsub_cout)
  );

  // Shift control logic
  assign shift_left = (alu_ctrl == 4'b0101);  // SLL
  assign shift_arith = (alu_ctrl == 4'b0111); // SRA

  // Single unified shifter
  barrel_shifter shifter (
    .data_in(op1),
    .shift_amt(op2[4:0]),
    .shift_left(shift_left),
    .arithmetic(shift_arith),
    .data_out(shift_result)
  );

  // Comparison results using adder output (no separate comparator needed)
  // For SLT: check if result is negative (sign bit) when both operands have same sign,
  // or if op1 is negative when operands have different signs
  assign slt_result = (op1[31] == op2[31]) ? addsub_result[31] : op1[31];

  // For SLTU: check carry out (if no carry, then op1 < op2)
  assign sltu_result = ~addsub_cout;

  always @(*) begin
    case (alu_ctrl)
      4'b0000: alu_out = addsub_result;        // ADD
      4'b0001: alu_out = addsub_result;        // SUB
      4'b0010: alu_out = op1 & op2;           // AND
      4'b0011: alu_out = op1 | op2;           // OR
      4'b0100: alu_out = op1 ^ op2;           // XOR
      4'b0101: alu_out = shift_result;        // SLL
      4'b0110: alu_out = shift_result;        // SRL
      4'b0111: alu_out = shift_result;        // SRA
      4'b1000: alu_out = {31'b0, slt_result}; // SLT
      4'b1001: alu_out = {31'b0, sltu_result};// SLTU
      default: alu_out = 32'b0;
    endcase
  end
  assign zero = (alu_out == 32'b0);
endmodule
