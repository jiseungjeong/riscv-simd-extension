

module register_file (
  input clk,
  input wen,
  input [4:0] rs1,
  input [4:0] rs2,
  input [4:0] waddr,
  input [31:0] wdata,
  output [31:0] rdata1,
  output [31:0] rdata2
);
  reg [31:0] regs [0:31];
  assign rdata1 = (rs1 != 0) ? regs[rs1] : 32'd0;
  assign rdata2 = (rs2 != 0) ? regs[rs2] : 32'd0;
  always @(posedge clk) begin
    if (wen && (waddr != 0)) begin
      regs[waddr] <= wdata;
    end
  end
endmodule


module ucrv32 (
  // reset and clock
  input clk, resetn,

  // imem interface
  output [31:0] imem_addr,
  input [31:0] imem_rdata,

  // dmem interface
  output wire [31:0] dmem_req_addr,
  output wire [31:0] dmem_req_wdata,
  output wire [3:0]  dmem_req_wmask,
  output wire        dmem_req_write,
  output wire        dmem_req_valid,
  input  wire        dmem_req_ready,

  input              dmem_resp_valid,
  output wire        dmem_resp_ready,
  input       [31:0] dmem_resp_rdata,

  output wire ebreak_hit,

  // trace outputs
  output [31:0] trace_pc,
  output [31:0] trace_insn
);

  // FSM States
  localparam STATE_FETCH  = 3'd0;
  localparam STATE_DECODE = 3'd1;
  localparam STATE_EXEC   = 3'd2;
  localparam STATE_MEM    = 3'd3;
  localparam STATE_WB     = 3'd4;

  // State register
  reg [2:0] cpu_state;

  // Core registers
  reg [31:0] pc_reg;
  reg [31:0] pc_saved;  // PC of current instruction (saved during fetch)
  reg [31:0] insn_reg;
  reg [31:0] rdata1_reg;
  reg [31:0] rdata2_reg;
  reg [31:0] imm_reg;
  reg [31:0] alu_out_reg;
  reg [31:0] mem_data_reg;

  reg [31:0] mtvec;
  reg [31:0] mepc;
  reg [31:0] mcause;
  reg [31:0] mstatus;

  wire csr_addr;
  assign csr_addr = imm_reg[11:0];

  always @ (posedge clk) begin
    if(!resetn) begin
      mtvec <= 32'd0;
      mepc <= 32'd0;
      mcause <= 32'd0;
      mstatus <= 32'd0
    end
    else begin
      if(cpu_state == STATE_WB) begin
        case(csr_addr)
          12'h035: mtvec <= rdata1_reg;
          12'h341: mepc <= rdata1_reg;
          12'h342: mcause <= rdata1_reg;
          12'h300: mstatus <= rdata1_reg;
          default: mstatus <= mstatus;
        endcase
      end
    end
  end
  



  // Control signals stored
  reg [4:0]  rd_reg;
  reg [3:0]  alu_ctrl_reg;
  reg        alu_src2_sel_reg;
  reg        mem_write_reg;
  reg        mem_read_reg;
  reg        wb_from_mem_reg;
  reg [31:0] mem_mask_reg;
  reg        mem_sign_extend_reg;
  reg        is_branch_reg;
  reg        branch_if_set_reg;
  reg        is_branch_compare_reg;
  reg        is_jal_reg;
  reg        is_jalr_reg;
  reg        is_auipc_reg;
  reg        reg_write_reg;
  reg        ebreak_hit_reg;


  // Decoder and control outputs
  wire [4:0]  dec_rd;
  wire [4:0]  dec_rs1;
  wire [4:0]  dec_rs2;
  wire [31:0] dec_imm;
  wire [3:0]  dec_alu_ctrl;
  wire        dec_alu_src2_sel;
  wire        dec_mem_write;
  wire        dec_mem_read;
  wire        dec_wb_from_mem;
  wire [31:0] dec_mem_mask;
  wire        dec_mem_sign_extend;
  wire        dec_is_branch;
  wire        dec_branch_if_set;
  wire        dec_is_branch_compare;
  wire        dec_is_jal;
  wire        dec_is_jalr;
  wire        dec_is_auipc;
  wire        dec_is_lui;
  wire        dec_reg_write;
  wire        dec_ebreak_hit;

  decoder_control decoder_control_inst(
    .insn(insn_reg),
    .rd(dec_rd),
    .rs1(dec_rs1),
    .rs2(dec_rs2),
    .imm(dec_imm),
    .alu_ctrl(dec_alu_ctrl),
    .alu_src2_sel(dec_alu_src2_sel),
    .mem_write(dec_mem_write),
    .mem_read(dec_mem_read),
    .wb_from_mem(dec_wb_from_mem),
    .mem_mask(dec_mem_mask),
    .mem_sign_extend(dec_mem_sign_extend),
    .is_branch(dec_is_branch),
    .branch_if_set(dec_branch_if_set),
    .is_branch_compare(dec_is_branch_compare),
    .is_jal(dec_is_jal),
    .is_jalr(dec_is_jalr),
    .is_auipc(dec_is_auipc),
    .is_lui(dec_is_lui),
    .reg_write(dec_reg_write),
    .ebreak_hit(dec_ebreak_hit)
  );

  wire [31:0] rf_rdata1, rf_rdata2;
  wire [31:0] wb_data;
  wire        wb_enable;

  register_file regfile(
    .clk(clk),
    .wen(wb_enable),
    .rs1(dec_rs1),
    .rs2(dec_rs2),
    .waddr(rd_reg),
    .wdata(wb_data),
    .rdata1(rf_rdata1),
    .rdata2(rf_rdata2)
  );

  // ALU
  wire [31:0] alu_op1, alu_op2;
  wire [31:0] alu_out;
  wire        alu_zero;

  assign alu_op1 = is_auipc_reg ? pc_saved : rf_rdata1;
  assign alu_op2 = alu_src2_sel_reg ? imm_reg : rf_rdata2;

  alu alu_inst(
    .op1(alu_op1),
    .op2(alu_op2),
    .alu_ctrl(alu_ctrl_reg),
    .alu_out(alu_out),
    .zero(alu_zero)
  );

  // Memory interface
  reg dmem_req_valid_reg;
  reg dmem_req_write_reg;
  reg [31:0] dmem_req_addr_reg;
  reg [31:0] dmem_req_wdata_reg;
  reg [3:0]  dmem_req_wmask_reg;

  assign dmem_req_valid = dmem_req_valid_reg;
  assign dmem_req_write = dmem_req_write_reg;
  assign dmem_req_addr  = dmem_req_addr_reg;
  assign dmem_req_wdata = dmem_req_wdata_reg;
  assign dmem_req_wmask = dmem_req_wmask_reg;
  assign dmem_resp_ready = 1'b1;

  // Instruction memory interface
  assign imem_addr = pc_reg;

  // Branch/Jump logic
  wire branch_condition;
  assign branch_condition = is_branch_compare_reg ?
                            (alu_out[0] ^ branch_if_set_reg) :
                            (alu_zero ^ branch_if_set_reg);

  wire take_branch;
  assign take_branch = is_branch_reg && branch_condition;

  // Writeback data selection
  wire [7:0]  mem_byte;
  wire [15:0] mem_half;

  assign mem_byte = (alu_out_reg[1:0] == 2'b00) ? mem_data_reg[7:0] :
                    (alu_out_reg[1:0] == 2'b01) ? mem_data_reg[15:8] :
                    (alu_out_reg[1:0] == 2'b10) ? mem_data_reg[23:16] :
                    mem_data_reg[31:24];

  assign mem_half = (alu_out_reg[1] == 1'b0) ? mem_data_reg[15:0] :
                    mem_data_reg[31:16];

  wire [31:0] mem_data_extended;
  assign mem_data_extended = mem_sign_extend_reg ?
    (mem_mask_reg == 32'h000000FF ? {{24{mem_byte[7]}}, mem_byte} :
     mem_mask_reg == 32'h0000FFFF ? {{16{mem_half[15]}}, mem_half} :
     mem_data_reg) :
    (mem_mask_reg == 32'h000000FF ? {24'h0, mem_byte} :
     mem_mask_reg == 32'h0000FFFF ? {16'h0, mem_half} :
     mem_data_reg);

  wire [31:0] pc_plus_4;
  ripple_carry_adder_32 pc_plus_4_adder (
    .a(pc_saved),
    .b(32'd4),
    .cin(1'b0),
    .sum(pc_plus_4),
    .cout()
  );

  wire [31:0] pc_plus_imm;
  ripple_carry_adder_32 branch_target_adder (
    .a(pc_saved),
    .b(imm_reg),
    .cin(1'b0),
    .sum(pc_plus_imm),
    .cout()
  );

  assign wb_data = (is_jal_reg || is_jalr_reg) ? pc_plus_4 :
                   wb_from_mem_reg ? mem_data_extended :
                   alu_out_reg;

  assign wb_enable = (cpu_state == STATE_WB) && reg_write_reg;
  assign ebreak_hit = ebreak_hit_reg && (cpu_state == STATE_WB);

  //=============================================================================
  // Trace outputs
  //=============================================================================

  reg [31:0] trace_pc_reg;
  reg [31:0] trace_insn_reg;

  assign trace_pc = trace_pc_reg;
  assign trace_insn = trace_insn_reg;


  //=============================================================================
  // FSM State Machine
  //=============================================================================


  always @(posedge clk) begin
    if (!resetn) begin
      cpu_state <= STATE_FETCH;
      pc_reg <= 32'h00000000;
      dmem_req_valid_reg <= 1'b0;
      reg_write_reg <= 1'b0;
      ebreak_hit_reg <= 1'b0;
    end else begin
      case (cpu_state)
        STATE_FETCH: begin
          insn_reg <= imem_rdata;
          pc_saved <= pc_reg;  // Save PC for this instruction
          trace_pc_reg <= pc_reg;
          trace_insn_reg <= imem_rdata;
          cpu_state <= STATE_DECODE;
        end

        STATE_DECODE: begin
          // Decode instruction and read registers
          rd_reg <= dec_rd;
          rdata1_reg <= rf_rdata1;
          rdata2_reg <= rf_rdata2;
          imm_reg <= dec_imm;
          alu_ctrl_reg <= dec_alu_ctrl;
          alu_src2_sel_reg <= dec_alu_src2_sel;
          mem_write_reg <= dec_mem_write;
          mem_read_reg <= dec_mem_read;
          wb_from_mem_reg <= dec_wb_from_mem;
          mem_mask_reg <= dec_mem_mask;
          mem_sign_extend_reg <= dec_mem_sign_extend;
          is_branch_reg <= dec_is_branch;
          branch_if_set_reg <= dec_branch_if_set;
          is_branch_compare_reg <= dec_is_branch_compare;
          is_jal_reg <= dec_is_jal;
          is_jalr_reg <= dec_is_jalr;
          is_auipc_reg <= dec_is_auipc;
          reg_write_reg <= dec_reg_write;
          ebreak_hit_reg <= dec_ebreak_hit;

          cpu_state <= STATE_EXEC;
        end

        STATE_EXEC: begin
          // Execute ALU operation and determine branches
          alu_out_reg <= alu_out;
          // Handle branches and jumps
          if (is_jal_reg) begin
            pc_reg <= pc_plus_imm;
          end else if (is_jalr_reg) begin
            pc_reg <= {alu_out[31:1], 1'b0};
          end else if (take_branch) begin
            pc_reg <= pc_plus_imm;
          end else if (!mem_read_reg && !mem_write_reg) begin
            // No memory operation, go directly to WB
            pc_reg <= pc_plus_4;
          end

          // Set up memory request if needed
          if (mem_read_reg || mem_write_reg) begin
            dmem_req_valid_reg <= 1'b1;
            dmem_req_write_reg <= mem_write_reg;
            dmem_req_addr_reg <= alu_out;

            // Prepare write data with proper alignment
            if (mem_write_reg) begin

              if (mem_mask_reg == 32'h000000FF) begin
                // Byte store
                dmem_req_wdata_reg <= {4{rdata2_reg[7:0]}};
                dmem_req_wmask_reg <= (alu_out[1:0] == 2'b00) ? 4'b0001 :
                                       (alu_out[1:0] == 2'b01) ? 4'b0010 :
                                       (alu_out[1:0] == 2'b10) ? 4'b0100 : 4'b1000;
              end else if (mem_mask_reg == 32'h0000FFFF) begin
                // Halfword store
                dmem_req_wdata_reg <= {2{rdata2_reg[15:0]}};
                dmem_req_wmask_reg <= alu_out[1] ? 4'b1100 : 4'b0011;
              end else begin
                // Word store
                dmem_req_wdata_reg <= rdata2_reg;
                dmem_req_wmask_reg <= 4'b1111;
              end
            end
            cpu_state <= STATE_MEM;
          end else begin
            cpu_state <= STATE_WB;
          end
        end

        STATE_MEM: begin

          // Handle memory operations
          if (dmem_req_valid_reg && dmem_req_ready) begin
            dmem_req_valid_reg <= 1'b0;
            if (!mem_read_reg) begin
              // Store completes when request is accepted
              pc_reg <= pc_plus_4;
              cpu_state <= STATE_WB;


            end
            // For loads, stay in MEM and wait for response
          end else if (!dmem_req_valid_reg && mem_read_reg) begin
            // Waiting for load response
            if (dmem_resp_valid) begin
              mem_data_reg <= dmem_resp_rdata;
              pc_reg <= pc_plus_4;
              cpu_state <= STATE_WB;
            end
          end
        
        end

        STATE_WB: begin
          reg_write_reg <= 1'b0;
          cpu_state <= STATE_FETCH;
          
        end

        default: begin
          cpu_state <= STATE_FETCH;
        end
      endcase
    end
  end

  // File handle for instruction trace
  integer trace_file;

  initial begin
    trace_file = $fopen("insn_trace.txt", "w");
  end

  always @ (posedge clk) begin
    if (resetn && cpu_state == STATE_WB) begin
      if(reg_write_reg) begin
        $fwrite(trace_file, "WB: PC=%08x INSN=%08x x%0d <= %08x\n",
                trace_pc_reg, trace_insn_reg, rd_reg, wb_data);
        $fflush(trace_file);
      end else begin
        $fwrite(trace_file, "WB: PC=%08x INSN=%08x (no write)\n",
                trace_pc_reg, trace_insn_reg);
        $fflush(trace_file);
      end
    end
  end


endmodule
