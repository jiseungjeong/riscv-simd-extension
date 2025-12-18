

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

  // CSR 주소는 12비트
  wire [11:0] csr_addr;
  assign csr_addr = imm_reg[11:0];

  always @ (posedge clk) begin
    if(!resetn) begin
      mtvec <= 32'd0;
      mepc <= 32'd0;
      mcause <= 32'd0;
      mstatus <= 32'd0;
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
  // 7.3 VMAC control signals
  reg        is_vmac_reg;
  reg [1:0]  vmac_ctrl_reg;

  // 7.6 Performance counters (from Lab 5)
  reg [31:0] cycle_counter;
  reg [31:0] insn_counter;
  reg [31:0] load_counter;
  reg [31:0] store_counter;

  // 7.6 Performance counter control signals
  reg        is_rdwrctr_reg;
  reg        rdwrctr_wen_reg;
  reg [1:0]  rdwrctr_ctr_id_reg;

  // new vector extension control registers
  reg        is_vec_op_reg;
  reg [2:0]  vec_op_reg;
  reg [1:0]  vec_sew_reg;
  reg        is_vec_load_reg;
  reg        is_vec_store_reg;
  reg        is_vec_vmac_reg;  // VMAC.B: result goes to scalar register
  reg        vec_reg_write_reg;
  reg [4:0] vd_reg; // vector destination register
  reg vec_busy;
  reg vec_valid_in_reg; // start signal for vector units
  reg vlsu_start_reg; // start signal for vector load/store unit

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
  // 7.3 VMAC decoder outputs
  wire        dec_is_vmac;
  wire [1:0]  dec_vmac_ctrl;

  // 7.6 Performance counter decoder outputs
  wire        dec_is_rdwrctr;
  wire        dec_rdwrctr_wen;
  wire [1:0]  dec_rdwrctr_ctr_id;

  // new vector decoder outputs
  wire        dec_is_vec_op;
  wire [2:0]  dec_vec_op;
  wire [1:0]  dec_vec_sew;
  wire        dec_is_vec_load;
  wire        dec_is_vec_store;
  wire        dec_vec_reg_write;
  wire        dec_is_vec_vmac;

  // 7.3 VMAC handshake + result wires
  reg        vmac_valid_in_reg;
  wire       vmac_valid_out;
  wire [31:0] vmac_result_wire;
  reg vmac_busy; // CPU-side busy flag while vmac running, computing flag role

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
    .ebreak_hit(dec_ebreak_hit),
    // 7.3 VMAC decoder outputs
    .is_vmac(dec_is_vmac),
    .vmac_ctrl(dec_vmac_ctrl),
    // 7.6 Performance counter decoder outputs
    .is_rdwrctr(dec_is_rdwrctr),
    .rdwrctr_wen(dec_rdwrctr_wen),
    .rdwrctr_ctr_id(dec_rdwrctr_ctr_id),
    // new vector decoder outputs
    .is_vec_op(dec_is_vec_op),
    .vec_op(dec_vec_op),
    .vec_sew(dec_vec_sew),
    .is_vec_load(dec_is_vec_load),
    .is_vec_store(dec_is_vec_store),
    .vec_reg_write(dec_vec_reg_write),
    .is_vec_vmac(dec_is_vec_vmac)
  );

  // 7.3 VMAC instance
  vmac vmac_inst (
    .clk(clk),
    .rst_n(resetn),
    .ctrl(vmac_ctrl_reg),
    .a(rdata1_reg),        // use saved operands from decode
    .b(rdata2_reg),
    .valid_in(vmac_valid_in_reg),
    .valid_out(vmac_valid_out),
    .result(vmac_result_wire)
  );

  // new vector register file instance
  wire [63:0] vrf_rdata1, vrf_rdata2;
  wire [63:0] vrf_wdata;
  wire vrf_wen;

  vreg_file vreg_file_inst(
    .clk(clk),
    .wen(vrf_wen),
    .vs1(dec_rs1),
    .vs2(dec_rs2),
    .vd(vd_reg),
    .wdata(vrf_wdata),
    .rdata1(vrf_rdata1),
    .rdata2(vrf_rdata2)
  );

  // new vector alu
  wire valu_valid_out;
  wire [63:0] valu_result;
  reg [63:0] vs1_data_reg;
  reg [63:0] vs2_data_reg;
  
  valu valu_inst(
    .clk(clk),
    .rst_n(resetn),
    .op(vec_op_reg[1:0]), // 00=VADD, 01=VSUB, 10=VMUL
    .sew(vec_sew_reg),
    .vs1_data(vs1_data_reg),
    .vs2_data(vs2_data_reg),
    .valid_in(vec_valid_in_reg && !is_vec_load_reg && !is_vec_store_reg),
    .valid_out(valu_valid_out),
    .result(valu_result)
  );

  // new vector load/store unit
  wire vlsu_done;
  wire [63:0] vlsu_load_data;
  wire [31:0] vlsu_mem_addr;
  wire [31:0] vlsu_mem_wdata;
  wire [3:0] vlsu_mem_wmask;
  wire vlsu_mem_write;
  wire vlsu_mem_valid;

  vlsu vlsu_inst(
    .clk(clk),
    .rst_n(resetn),
    .start(vlsu_start_reg),
    .is_store(is_vec_store_reg),
    .base_addr(rdata1_reg),
    .store_data(vs2_data_reg),
    .done(vlsu_done),
    .load_data(vlsu_load_data),
    .mem_addr(vlsu_mem_addr),
    .mem_wdata(vlsu_mem_wdata),
    .mem_wmask(vlsu_mem_wmask),
    .mem_write(vlsu_mem_write),
    .mem_valid(vlsu_mem_valid),
    .mem_ready(dmem_req_ready),
    .mem_resp_valid(dmem_resp_valid),
    .mem_resp_rdata(dmem_resp_rdata)
  );

  // vector result storage
  reg [63:0] vec_result_reg;


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

  // memory interface, mux between scalar and vector access
  wire vec_mem_active = (is_vec_load_reg || is_vec_store_reg) && vec_busy;

  assign dmem_req_valid = vec_mem_active ? vlsu_mem_valid : dmem_req_valid_reg;
  assign dmem_req_write = vec_mem_active ? vlsu_mem_write : dmem_req_write_reg;
  assign dmem_req_addr  = vec_mem_active ? vlsu_mem_addr : dmem_req_addr_reg;
  assign dmem_req_wdata = vec_mem_active ? vlsu_mem_wdata : dmem_req_wdata_reg;
  assign dmem_req_wmask = vec_mem_active ? vlsu_mem_wmask : dmem_req_wmask_reg;
  assign dmem_resp_ready = 1'b1;

  // new vector register file write logic
  assign vrf_wen = (cpu_state == STATE_WB) && vec_reg_write_reg;
  assign vrf_wdata = vec_result_reg;

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
                   is_vmac_reg ? alu_out_reg :  // VMAC result stored in alu_out_reg
                   is_rdwrctr_reg ? alu_out_reg :  // RDWRCTR result
                   is_vec_vmac_reg ? alu_out_reg :  // VMAC.B (wide vec) result
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
      // 7.3 VMAC reset
      vmac_busy <= 1'b0;
      vmac_valid_in_reg <= 1'b0;
      is_vmac_reg <= 1'b0;
      vmac_ctrl_reg <= 2'b00;
      
      // 7.6 Performance counter reset
      cycle_counter <= 32'd0;
      insn_counter <= 32'd0;
      load_counter <= 32'd0;
      store_counter <= 32'd0;
      is_rdwrctr_reg <= 1'b0;
      rdwrctr_wen_reg <= 1'b0;
      rdwrctr_ctr_id_reg <= 2'b00;

      // new vector reset
      is_vec_op_reg <= 1'b0;
      vec_op_reg <= 3'b000;
      vec_sew_reg <= 2'b00;
      is_vec_load_reg <= 1'b0;
      is_vec_store_reg <= 1'b0;
      is_vec_vmac_reg <= 1'b0;
      vec_reg_write_reg <= 1'b0;
      vd_reg <= 5'd0;
      vec_busy <= 1'b0;
      vec_valid_in_reg <= 1'b0;
      vlsu_start_reg <= 1'b0;
      vs1_data_reg <= 64'd0;
      vs2_data_reg <= 64'd0;
      vec_result_reg <= 64'd0;
    end else begin
      // 7.6 Performance counters: always increment cycle counter
      cycle_counter <= cycle_counter + 32'd1;
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
          // 7.3 VMAC control signals
          is_vmac_reg <= dec_is_vmac;
          vmac_ctrl_reg <= dec_vmac_ctrl;

          // 7.6 Performance counter control signals
          is_rdwrctr_reg <= dec_is_rdwrctr;
          rdwrctr_wen_reg <= dec_rdwrctr_wen;
          rdwrctr_ctr_id_reg <= dec_rdwrctr_ctr_id;

          // new vector control signals
          is_vec_op_reg <= dec_is_vec_op;
          vec_op_reg <= dec_vec_op;
          vec_sew_reg <= dec_vec_sew;
          is_vec_load_reg <= dec_is_vec_load;
          is_vec_store_reg <= dec_is_vec_store;
          is_vec_vmac_reg <= dec_is_vec_vmac;
          vec_reg_write_reg <= dec_vec_reg_write;
          vd_reg <= dec_rd;
          vs1_data_reg <= vrf_rdata1; // read vector operands
          vs2_data_reg <= vrf_rdata2;

          cpu_state <= STATE_EXEC;
        end

        STATE_EXEC: begin
          // 7.6 RDWRCTR operation
          if (is_rdwrctr_reg) begin
            // DEBUG: Print RDWRCTR execution
            $display("[RDWRCTR] PC=%h, wen=%b, ctr_id=%d, cycle=%d, rd=%d", pc_saved, rdwrctr_wen_reg, rdwrctr_ctr_id_reg, cycle_counter, rd_reg);
            if (rdwrctr_wen_reg) begin
              // Write rs1 to selected counter
              case (rdwrctr_ctr_id_reg)
                2'b00: cycle_counter <= rdata1_reg;
                2'b01: insn_counter <= rdata1_reg;
                2'b10: load_counter <= rdata1_reg;
                2'b11: store_counter <= rdata1_reg;
              endcase
            end else begin
              // Read selected counter to rd
              case (rdwrctr_ctr_id_reg)
                2'b00: alu_out_reg <= cycle_counter;
                2'b01: alu_out_reg <= insn_counter;
                2'b10: alu_out_reg <= load_counter;
                2'b11: alu_out_reg <= store_counter;
                default: alu_out_reg <= 32'h0;
              endcase
            end
            pc_reg <= pc_plus_4;
            cpu_state <= STATE_WB;

          // new vector operation
          end else if (is_vec_op_reg) begin
            if (!vec_busy) begin
              // start vector operation
              vec_busy <= 1'b1;
              if (is_vec_load_reg || is_vec_store_reg) begin
                vlsu_start_reg <= 1'b1;
              end else begin
                vec_valid_in_reg <= 1'b1;
              end
            end else begin
              vlsu_start_reg <= 1'b0;
              vec_valid_in_reg <= 1'b0;
            end

            // check for completion
            if (is_vec_load_reg || is_vec_store_reg) begin
              if (vlsu_done) begin
                if (is_vec_load_reg) begin
                  vec_result_reg <= vlsu_load_data;
                end
                pc_reg <= pc_plus_4;
                vec_busy <= 1'b0;
                vlsu_start_reg <= 1'b0;
                cpu_state <= STATE_WB;
              end else begin
                cpu_state <= STATE_EXEC;
              end
            end else begin
              // VALU operation (VADD, VSUB, VMUL, VMAC)
              if (valu_valid_out) begin
                if (is_vec_vmac_reg) begin
                  // VMAC.B: result is 32-bit scalar in lower bits
                  alu_out_reg <= valu_result[31:0];
                end else begin
                  vec_result_reg <= valu_result;
                end
                pc_reg <= pc_plus_4;
                vec_busy <= 1'b0;
                vec_valid_in_reg <= 1'b0;
                cpu_state <= STATE_WB;
              end else begin
                cpu_state <= STATE_EXEC;
              end
            end
          end
          
          // 7.3 VMAC operation
          else if (is_vmac_reg) begin
            if (!vmac_busy) begin 
              vmac_valid_in_reg <= 1'b1; // if not busy, start vmac
              vmac_busy <= 1'b1;
            end else begin
              vmac_valid_in_reg <= 1'b0; // if busy, keep valid_in low
            end
            if (vmac_valid_out) begin // vmac done
              alu_out_reg <= vmac_result_wire; // get result
              pc_reg <= pc_plus_4; // next pc
              vmac_busy <= 1'b0; // clear busy flag
              vmac_valid_in_reg <= 1'b0; // clear valid_in
              cpu_state <= STATE_WB; // go to WB
            end else begin
              // stay in EXEC while vmac is running
              cpu_state <= STATE_EXEC;
            end

          end else begin
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
        end
        STATE_MEM: begin

          // Handle memory operations
          if (dmem_req_valid_reg && dmem_req_ready) begin
            dmem_req_valid_reg <= 1'b0;
            if (!mem_read_reg) begin
              // Store completes when request is accepted
              pc_reg <= pc_plus_4;
              cpu_state <= STATE_WB;
              // 7.6 Performance counter: increment store counter
              store_counter <= store_counter + 32'd1;
            end
            // For loads, stay in MEM and wait for response
          end else if (!dmem_req_valid_reg && mem_read_reg) begin
            // Waiting for load response
            if (dmem_resp_valid) begin
              mem_data_reg <= dmem_resp_rdata;
              pc_reg <= pc_plus_4;
              cpu_state <= STATE_WB;
              // 7.6 Performance counter: increment load counter
              load_counter <= load_counter + 32'd1;
            end
          end
        
        end

        STATE_WB: begin
          // DEBUG: Print RDWRCTR writeback
          if (is_rdwrctr_reg && reg_write_reg) begin
            $display("[RDWRCTR_WB] rd=x%0d, wb_data=%d, alu_out=%d", rd_reg, wb_data, alu_out_reg);
          end
          reg_write_reg <= 1'b0;
          vec_reg_write_reg <= 1'b0;
          cpu_state <= STATE_FETCH;
          // 7.6 Performance counter: increment instruction counter
          insn_counter <= insn_counter + 32'd1;
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
