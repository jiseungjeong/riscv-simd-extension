module top (
  input clk,
  input resetn,

  output reg    break_hit,

  output [31:0] trace_insn,
  output [31:0] trace_pc,

  output reg [7:0]  par_tx,
  output reg        par_tx_valid,
  input  [7:0]  par_rx,
  input         par_rx_valid,
  output reg    par_rx_ack,

  output       tx,
  input        rx
);

  reg sim_use_par_txrx;
  always @ (posedge clk) begin
    if (!resetn) begin
      sim_use_par_txrx <= 1'b0;
    end else begin
      sim_use_par_txrx <= sim_use_par_txrx;
    end
  end

  wire [31:0] dmem_req_addr;
  wire [31:0] dmem_req_wdata;
  wire [3:0]  dmem_req_wmask;
  wire        dmem_req_write;
  wire        dmem_req_valid;
  wire        dmem_req_ready;


  wire dmem_resp_valid;
  wire dmem_resp_ready;
  wire [31:0] dmem_resp_rdata;

  wire [31:0] imem_addr;
  wire [31:0] imem_rdata;

  wire cpu_break;

  always @ (posedge clk) begin
    if (!resetn) begin
      break_hit <= 1'b0;
    end else if (cpu_break) begin
      break_hit <= 1'b1;
    end
  end

  ucrv32 cpu(
    .clk(clk),
    .resetn(resetn),
    .imem_addr(imem_addr),
    .imem_rdata(imem_rdata),

    .dmem_req_addr(dmem_req_addr),
    .dmem_req_wdata(dmem_req_wdata),
    .dmem_req_wmask(dmem_req_wmask),
    .dmem_req_write(dmem_req_write),
    .dmem_req_valid(dmem_req_valid),
    .dmem_req_ready(dmem_req_ready),

    .dmem_resp_valid(dmem_resp_valid),
    .dmem_resp_ready(dmem_resp_ready),
    .dmem_resp_rdata(dmem_resp_rdata),
    .ebreak_hit(cpu_break),

    .trace_pc(trace_pc),
    .trace_insn(trace_insn)
  );

  wire [31:0] sram_dmem_rdata;
  wire sram_dmem_resp_valid;

  sram sram0 (
    .clk(clk),
    .resetn(resetn),
    .imem_addr(imem_addr),
    .imem_rdata(imem_rdata),
    .dmem_addr(dmem_req_addr),
    .dmem_wdata(dmem_req_wdata),
    .dmem_wmask(dmem_req_wmask),
    .dmem_write(dmem_req_write),
    .dmem_valid(dmem_req_valid),
    .dmem_rdata(sram_dmem_rdata),
    .dmem_resp_valid(sram_dmem_resp_valid)
  );


  reg [31:0] dmem_raddr_reg;
  always @ (posedge clk) begin
    if (dmem_req_valid && !dmem_req_write) begin
      dmem_raddr_reg <= dmem_req_addr;
    end
  end

  wire [31:0] uart_resp_rdata;
  wire uart_resp_valid;
  wire uart_resp_ready;
  reg  par_rx_valid_latch;
  reg [7:0] par_rx_latch;
  
  assign dmem_resp_rdata = (dmem_raddr_reg[31:12] == 20'h10000 && !sim_use_par_txrx) ? uart_resp_rdata : 
                           (dmem_raddr_reg[31:12] == 20'h10000 && sim_use_par_txrx) ? (
                            (dmem_raddr_reg[11:0] == 12'h008) ? 32'd0 : {23'd0, par_rx_valid_latch, par_rx_latch})
                             : sram_dmem_rdata;
  assign dmem_resp_valid = (dmem_raddr_reg[31:12] == 20'h10000 && !sim_use_par_txrx) ? uart_resp_valid : sram_dmem_resp_valid;
  assign uart_resp_ready = dmem_resp_ready;
  assign dmem_req_ready = (dmem_req_addr[31:12] == 20'h10000 && !sim_use_par_txrx) ? uart_req_ready : 
                          (dmem_req_addr[31:12] == 20'h10000 && sim_use_par_txrx) ? 1'b1 : 1'b1;

  always @ (posedge clk) begin
    if (!resetn) begin
      par_rx_ack <= 1'b0;
    end else begin
      if (dmem_req_valid && !dmem_req_write && (dmem_req_addr[31:12] == 20'h10000) && sim_use_par_txrx && par_rx_valid) begin
        par_rx_ack <= 1'b1;
        par_rx_valid_latch <= par_rx_valid;
        par_rx_latch <= par_rx;
      end else begin
        par_rx_ack <= 1'b0;
        par_rx_valid_latch <= 1'b0;
        par_rx_latch <= 8'd0;
      end
    end
  end

  always @ (posedge clk) begin
    if (!resetn) begin
      par_tx <= 8'd0;
      par_tx_valid <= 1'b0;
    end else begin
      if (dmem_req_valid && dmem_req_write && (dmem_req_addr[31:12] == 20'h10000) && sim_use_par_txrx) begin
        par_tx <= dmem_req_wdata[7:0];
        par_tx_valid <= 1'b1;
      end else begin
        par_tx_valid <= 1'b0;
      end
    end
  end

  wire uart_req_ready;
  wire uart_req_valid;
  wire [7:0] uart_rx_mailbox_data;

  assign uart_req_valid = (dmem_req_addr[31:12] == 20'h10000 && !sim_use_par_txrx) && dmem_req_valid;

  uart uart0 (
    .clk(clk),
    .resetn(resetn),
    .rx(rx),
    .tx(tx),

    .req_ready(uart_req_ready),
    .req_valid(uart_req_valid),
    .req_addr(dmem_req_addr[7:0]),
    .req_write(dmem_req_write),
    .req_data(dmem_req_wdata),

    .resp_data(uart_resp_rdata),
    .resp_valid(uart_resp_valid),
    .resp_ready(uart_resp_ready)
  );


endmodule
