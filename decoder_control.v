
// Combined decoder and control unit
// Decodes instruction and generates all control signals
module decoder_control (
  input [31:0] insn,

  // Decoded fields (outputs for use in datapath)
  output [4:0]  rd,
  output [4:0]  rs1,
  output [4:0]  rs2,
  output [31:0] imm,

  // Control signals
  output reg [3:0]  alu_ctrl,
  output            alu_src2_sel,    // 0: rs2, 1: imm
  output            mem_write,
  output            mem_read,
  output            wb_from_mem,
  output reg [31:0] mem_mask,
  output            mem_sign_extend,
  output            is_branch,
  output            branch_if_set,
  output            is_branch_compare,
  output            is_jal,
  output            is_jalr,
  output            is_auipc,
  output            is_lui,
  output            reg_write,
  output            ebreak_hit

);

  // Extract fields from instruction
  wire [6:0] opcode = insn[6:0];
  wire [2:0] funct3 = insn[14:12];
  wire [6:0] funct7 = insn[31:25];

  // Decode instruction type
  wire is_r_type = (opcode == 7'b0110011);
  wire is_i_type = (opcode == 7'b0010011) || (opcode == 7'b0000011) ||
                   (opcode == 7'b1100111) || (opcode == 7'b1110011);
  wire is_s_type = (opcode == 7'b0100011);
  wire is_b_type = (opcode == 7'b1100011);
  wire is_u_type = (opcode == 7'b0110111) || (opcode == 7'b0010111);
  wire is_j_type = (opcode == 7'b1101111);


  assign rd  = insn[11:7];
  assign rs1 = is_u_type ? 5'b00000 : insn[19:15];
  assign rs2 = insn[24:20];

  // Generate immediates
  wire [31:0] imm_i = {{20{insn[31]}}, insn[31:20]};
  wire [31:0] imm_s = {{20{insn[31]}}, insn[31:25], insn[11:7]};
  wire [31:0] imm_b = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
  wire [31:0] imm_u = {insn[31:12], 12'b0};
  wire [31:0] imm_j = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};

  // Select appropriate immediate
  assign imm = is_i_type ? imm_i :
               is_s_type ? imm_s :
               is_b_type ? imm_b :
               is_u_type ? imm_u :
               is_j_type ? imm_j :
               32'd0;

  // ALU control
  always @(*) begin
    if (is_r_type) begin
      case ({funct7, funct3})
        10'b0000000_000: alu_ctrl = 4'b0000; // ADD
        10'b0100000_000: alu_ctrl = 4'b0001; // SUB
        10'b0000000_111: alu_ctrl = 4'b0010; // AND
        10'b0000000_110: alu_ctrl = 4'b0011; // OR
        10'b0000000_100: alu_ctrl = 4'b0100; // XOR
        10'b0000000_001: alu_ctrl = 4'b0101; // SLL
        10'b0000000_101: alu_ctrl = 4'b0110; // SRL
        10'b0100000_101: alu_ctrl = 4'b0111; // SRA
        10'b0000000_010: alu_ctrl = 4'b1000; // SLT
        10'b0000000_011: alu_ctrl = 4'b1001; // SLTU
        default:         alu_ctrl = 4'bxxxx;
      endcase
    end else if (is_i_type && opcode == 7'b0010011) begin // OP-IMM
      case (funct3)
        3'b000: alu_ctrl = 4'b0000; // ADDI
        3'b111: alu_ctrl = 4'b0010; // ANDI
        3'b110: alu_ctrl = 4'b0011; // ORI
        3'b100: alu_ctrl = 4'b0100; // XORI
        3'b010: alu_ctrl = 4'b1000; // SLTI
        3'b011: alu_ctrl = 4'b1001; // SLTIU
        3'b001: alu_ctrl = 4'b0101; // SLLI
        3'b101: alu_ctrl = (funct7 == 7'b0000000) ? 4'b0110 : // SRLI
                           (funct7 == 7'b0100000) ? 4'b0111 : // SRAI
                           4'bxxxx;
        default: alu_ctrl = 4'bxxxx;
      endcase
    end else if (is_b_type) begin
      case (funct3)
        3'b000, 3'b001: alu_ctrl = 4'b0001; // BEQ, BNE (SUB)
        3'b100, 3'b101: alu_ctrl = 4'b1000; // BLT, BGE (SLT)
        3'b110, 3'b111: alu_ctrl = 4'b1001; // BLTU, BGEU (SLTU)
        default:        alu_ctrl = 4'bxxxx;
      endcase
    end else begin
      alu_ctrl = 4'b0000; // ADD (default for loads, stores, LUI, AUIPC)
    end
  end

  // Memory mask
  always @(*) begin
    case (funct3)
      3'b000: mem_mask = 32'h000000FF; // Byte
      3'b001: mem_mask = 32'h0000FFFF; // Half
      3'b010: mem_mask = 32'hFFFFFFFF; // Word
      3'b100: mem_mask = 32'h000000FF; // LBU
      3'b101: mem_mask = 32'h0000FFFF; // LHU
      default: mem_mask = 32'd0;
    endcase
  end

  // Control signals
  assign alu_src2_sel = is_i_type || is_s_type || is_u_type;
  assign mem_write = is_s_type;
  assign mem_read  = (is_i_type && opcode == 7'b0000011);
  assign wb_from_mem = mem_read;
  assign mem_sign_extend = mem_read && !funct3[2];
  assign is_branch = is_b_type;
  assign branch_if_set = funct3[0];
  assign is_branch_compare = is_b_type && funct3[2];
  assign is_jal  = is_j_type;
  assign is_jalr = (is_i_type && opcode == 7'b1100111);
  assign is_auipc = (is_u_type && opcode == 7'b0010111);
  assign is_lui   = (is_u_type && opcode == 7'b0110111);
  

  assign reg_write = !is_b_type && !is_s_type;

  assign ebreak_hit = (is_i_type && opcode == 7'b1110011) && (funct3 == 3'b000);

endmodule
