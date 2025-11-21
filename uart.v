module uart(
  input wire clk,
  input wire resetn,
  input wire rx,
  output wire tx,

  output wire req_ready,
  input wire req_valid,
  input wire [7:0] req_addr,
  input wire req_write,
  input wire [31:0] req_data,

  output reg [31:0] resp_data,
  output reg resp_valid,
  input wire resp_ready

);

// address map
// 000: tx
// 004: rx
// 008: status
// 00c: config

reg config_loopback = 1'b0;

localparam BAUD_RATE = 115200;
localparam CLOCK_FREQ = 50000000;
localparam CLOCK_DIV = 434;

// Sanity check: verify CLOCK_DIV matches the baud rate calculation
// Expected CLOCK_DIV = CLOCK_FREQ / BAUD_RATE = 50000000 / 115200 ≈ 434
localparam EXPECTED_CLOCK_DIV = CLOCK_FREQ / BAUD_RATE;

initial begin
  if (CLOCK_DIV != EXPECTED_CLOCK_DIV) begin
    $display("Warning: CLOCK_DIV=%d does not match calculated value %d for %d baud at %d Hz",
             CLOCK_DIV, EXPECTED_CLOCK_DIV, BAUD_RATE, CLOCK_FREQ);
    
  end
end

// TX state
assign req_ready = (tx_state == TX_IDLE) ? 1'b1 : 1'b0;
reg [7:0] data_to_send;

// RX state
reg [1:0] rx_state;
reg [1:0] rx_next_state;
localparam RX_IDLE = 2'd0;
localparam RX_START = 2'd1;
localparam RX_DATA = 2'd2;
localparam RX_STOP = 2'd3;

reg [2:0] rx_counter;
reg [9:0] rx_baud_counter;
reg [7:0] rx_byte;
reg rx_line_prev;
reg rx_byte_valid;

wire [31:0] status;
assign status[1:0] = tx_state;
assign status[9:8] = rx_state;

always @ (posedge clk) begin
  if (!resetn) begin
    resp_data <= 32'hdeadbeef;
    resp_valid <= 1'b0;
  end
  else begin
    resp_valid <= 1'b0;
    resp_data <= 32'hdeadbeef;
    if (req_valid && resp_ready) begin
      case (req_addr)
        8'h00: begin // TX
          // handled in TX state machine
        end
        8'h04: begin // RX
          resp_data <= {23'd0, rx_byte_valid, rx_byte};
          resp_valid <= 1'b1;
        end
        8'h08: begin // STATUS
          resp_data <= status;
          resp_valid <= 1'b1;
        end
        8'h0c: begin // CONFIG
        end
        default: begin
          // do nothing
        end
      endcase
    end
  end
end


// TX state machine
reg [1:0] tx_state;
localparam TX_IDLE = 2'd0;
localparam TX_START = 2'd1;
localparam TX_DATA = 2'd2;
localparam TX_STOP = 2'd3;

reg [2:0] tx_counter;
reg [9:0] tx_baud_counter;

always @(posedge clk) begin
  if (!resetn) begin
    tx_state <= TX_IDLE;
    data_to_send <= 8'd0;
  end
  else begin
    case(tx_state)
      TX_IDLE: begin
        if (config_loopback && rx_byte_valid) begin
          data_to_send <= rx_byte;
          tx_state <= TX_START;
          tx_baud_counter <= 10'd0;
          tx_counter <= 3'd0;
          
        end
        else if (!config_loopback && req_valid && req_write && (req_addr == 8'h00)) begin
          data_to_send <= req_data[7:0];
          tx_state <= TX_START;
          tx_baud_counter <= 10'd0;
          tx_counter <= 3'd0;
        end
        else begin
          tx_state <= TX_IDLE;
        end
      end
      TX_START: begin
        if (tx_baud_counter == CLOCK_DIV - 1) begin
          tx_state <= TX_DATA;
          tx_baud_counter <= 10'd0;
        end
        else begin
          tx_baud_counter <= tx_baud_counter + 10'd1;
        end
      end
      TX_DATA: begin
        if (tx_baud_counter == CLOCK_DIV - 1) begin
          if (tx_counter == 3'd7) begin
            tx_state <= TX_STOP;
            tx_baud_counter <= 10'd0;
            tx_counter <= 3'd0;
          end
          else begin
            tx_counter <= tx_counter + 3'd1;
            tx_baud_counter <= 10'd0;
          end
        end
        else begin
          tx_baud_counter <= tx_baud_counter + 10'd1;
        end
      end
      TX_STOP: begin
        if (tx_baud_counter == CLOCK_DIV - 1) begin
          tx_state <= TX_IDLE;
          tx_baud_counter <= 10'd0;
        end
        else begin
          tx_baud_counter <= tx_baud_counter + 10'd1;
        end
      end
      default: begin
        tx_state <= TX_IDLE;
      end
    endcase
  end
end

assign tx = (tx_state == TX_IDLE) ? 1'b1 :
            (tx_state == TX_START) ? 1'b0 :
            (tx_state == TX_STOP) ? 1'b1 :
            data_to_send[tx_counter];

// RX state machine
always @ (posedge clk) begin
  if (!resetn) begin
    rx_state <= RX_IDLE;
    rx_baud_counter <= 10'd0;
    rx_counter <= 3'd0;
    rx_byte <= 8'd0;
    rx_line_prev <= 1'b1;
    rx_byte_valid <= 1'b0;
  end
  else begin
    rx_line_prev <= rx;
    rx_byte_valid <= 1'b0;

    case (rx_state)
      RX_IDLE: begin
        // Detect start bit (falling edge)
        if (rx_line_prev && !rx) begin
          rx_state <= RX_START;
          rx_baud_counter <= 10'd0;
          rx_byte <= 8'd0;
        end
      end

      RX_START: begin
        // Wait half a bit period to sample in the middle
        if (rx_baud_counter == (CLOCK_DIV / 2)) begin
          if (!rx) begin
            // Valid start bit, move to data
            rx_state <= RX_DATA;
            rx_counter <= 3'd0;
            rx_baud_counter <= 10'd0;
          end
          else begin
            // Framing error
            rx_state <= RX_IDLE;
            rx_baud_counter <= 10'd0;
          end
        end
        else begin
          rx_baud_counter <= rx_baud_counter + 10'd1;
        end
      end

      RX_DATA: begin
        if (rx_baud_counter == CLOCK_DIV - 1) begin
          // Sample data bit in the middle of the bit period
          if (rx) begin
            rx_byte[rx_counter] <= 1'b1;
          end
          else begin
            rx_byte[rx_counter] <= 1'b0;
          end

          rx_baud_counter <= 10'd0;

          if (rx_counter == 3'd7) begin
            rx_state <= RX_STOP;
          end
          else begin
            rx_counter <= rx_counter + 3'd1;
          end
        end
        else begin
          rx_baud_counter <= rx_baud_counter + 10'd1;
        end
      end

      RX_STOP: begin
        if (rx_baud_counter == CLOCK_DIV - 1) begin
          // Sample stop bit
          if (rx) begin
            // Valid byte received
            rx_byte_valid <= 1'b1;
          end
          rx_state <= RX_IDLE;
          rx_baud_counter <= 10'd0;
        end
        else begin
          rx_baud_counter <= rx_baud_counter + 10'd1;
        end
      end

      default: begin
        rx_state <= RX_IDLE;
      end
    endcase
  end
end

endmodule
