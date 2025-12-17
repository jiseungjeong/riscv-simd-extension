
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
  output            ebreak_hit,
  // 7.2 VMAC signals
  output is_vmac,
  output reg [1:0] vmac_ctrl

  // new vector extension signals
  output is_vec_op,
  output reg [2:0] vec_op,
  output reg [1:0] vec_sew, // element width (00=8, 01=16, 10=32)
  output is_vec_load,
  output is_vec_store,
  output vec_reg_write
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
  // 7.2 VMAC type
  wire is_vmac_type = (opcode == 7'b1011011) && (funct3 == 3'b001);  // Opcode=0x5B, funct3=001

  // new vector extension types
  // opcode=0x5B, funct3=010 for new vector instructions
  wire is_vec_type = (opcode == 7'b1011011) && (funct3 == 3'b010);

  // vector operation codes from funct7[4:0]
  localparam VOP_VADD = 5'b00000;
  localparam VOP_VSUB = 5'b00001;
  localparam VOP_VMUL = 5'b00010;
  localparam VOP_VLD = 5'b00100;
  localparam VOP_VST = 5'b00101;
  localparam VOP_VMOV_S2V = 5'b01000; // scalar to vector
  localparam VOP_VMOV_V2S = 5'b01001; // vector to scalar

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
    // 7.2 VMAC ALU control
    end else if (is_vmac_type || is_vec_type) begin
      alu_ctrl = 4'bxxxx;  
    end else begin
      alu_ctrl = 4'b0000; // ADD (default for loads, stores, LUI, AUIPC)
    end
  end

  // new vector extension control signals
  // SEW decoding from funct7[6:5]
  always @(*) begin
    if (is_vec_type) begin
      vec_sew = funct7[6:5]; // 00=8bit, 01=16bit, 10=32bit
    end else begin
      vec_sew = 2'b00;
    end
  end
  
  // vector operation decoding from funct7[4:0]
  always @(*) begin
    if (is_vec_type) begin
      case (funct7[4:0])
        VOP_VADD: vec_op = 3'b000; // VADD
        VOP_VSUB: vec_op = 3'b001; // VSUB
        VOP_VMUL: vec_op = 3'b010; // VMUL
        VOP_VLD: vec_op = 3'b011; // VLD
        VOP_VST: vec_op = 3'b100; // VST
        VOP_VMOV_S2V: vec_op = 3'b101; // VMOV_S2V
        VOP_VMOV_V2S: vec_op = 3'b110; // VMOV_V2S
        default: vec_op = 3'b111; // invalid
      endcase
    end else begin
      vec_op = 3'b000;
    end
  end

  // vector conrol signal assignments
  assign is_vec_op = is_vec_type;
  assign is_vec_load = is_vec_type && (funct7[4:0] == VOP_VLD);
  assign is_vec_store = is_vec_type && (funct7[4:0] == VOP_VST);

  // write to vector register for: VADD, VSUB, VMUL, VLD, VMOV_S2V
  assign vec_reg_write = is_vec_type &&
                          (funct7[4:0] == VOP_VADD ||
                           funct7[4:0] == VOP_VSUB ||
                           funct7[4:0] == VOP_VMUL ||
                           funct7[4:0] == VOP_VLD ||
                           funct7[4:0] == VOP_VMOV_S2V);
  
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

  // 7.2 VMAC control signals
  always @(*) begin
    if (is_vmac_type) begin
      case (funct7)
        7'b0000000: vmac_ctrl = 2'b00; // PVADD
        7'b0000001: vmac_ctrl = 2'b01; // PVMUL
        7'b0000010: vmac_ctrl = 2'b10; // PVMAC
        7'b0000011: vmac_ctrl = 2'b11; // PVMUL_UPPER
        default:    vmac_ctrl = 2'bxx;
      endcase
    end else begin
      vmac_ctrl = 2'b00;
    end
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
  
  // 7.2 modified reg_write
  assign reg_write = (!is_b_type && !is_s_type && !is_vec_type) || is_vmac_type;

  assign ebreak_hit = (is_i_type && opcode == 7'b1110011) && (funct3 == 3'b000);

  // 7.2 modified is_vmac
  assign is_vmac = is_vmac_type;

endmodule
