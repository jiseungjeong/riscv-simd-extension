module sram (
  input clk,
  input resetn,

  // Read-only interface (instruction port)
  input [31:0] imem_addr,
  output [31:0] imem_rdata,

  // Read-write interface (data port)
  input [31:0] dmem_addr,
  input [31:0] dmem_wdata,
  input [3:0] dmem_wmask,
  input dmem_write,
  input dmem_valid,
  output [31:0] dmem_rdata,
  output dmem_resp_valid
);

  reg [31:0] mem [0:32'h00400000-1];  // 4M words = 16MB

  // Instruction port: read-only, responds with data on next cycle
  reg [31:0] imem_addr_reg;
  always @(posedge clk) begin
    imem_addr_reg <= imem_addr;
  end
  assign imem_rdata = mem[imem_addr_reg[23:2]];

  // Data port: read-write, responds with read data on next cycle
  reg [31:0] dmem_addr_reg;
  reg dmem_resp_valid_reg;

  always @(posedge clk) begin
    if (dmem_valid && !dmem_write) begin
      dmem_addr_reg <= dmem_addr;
    end
  end

  always @(posedge clk) begin
    dmem_resp_valid_reg <= (dmem_valid && !dmem_write);
  end

  assign dmem_rdata = mem[dmem_addr_reg[23:2]];
  assign dmem_resp_valid = dmem_resp_valid_reg;

  // Write logic
  always @(posedge clk) begin
    if (dmem_valid && dmem_write) begin
      if (dmem_wmask[0]) begin
        mem[dmem_addr[23:2]][7:0] <= dmem_wdata[7:0];
      end
      if (dmem_wmask[1]) begin
        mem[dmem_addr[23:2]][15:8] <= dmem_wdata[15:8];
      end
      if (dmem_wmask[2]) begin
        mem[dmem_addr[23:2]][23:16] <= dmem_wdata[23:16];
      end
      if (dmem_wmask[3]) begin
        mem[dmem_addr[23:2]][31:24] <= dmem_wdata[31:24];
      end
    end
  end

endmodule
