// Verilator testbench for RISC-V SoC
//
// PTY Support (optional):
//   By default, PTY support is disabled for better portability.
//   To enable PTY mode (screen command), compile with:
//     make CXXFLAGS="-DENABLE_PTY"
//   On Ubuntu, you'll also need: sudo apt-get install libutil-dev
//
// Without PTY: Uses stdin/stdout directly (use_local_pty = 1)
// With PTY:    Creates virtual terminal device (use_local_pty = 0)

#include <verilated.h>
#if VM_TRACE
#include <verilated_vcd_c.h>
#endif
#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <errno.h>
#include <signal.h>
#include <pthread.h>
#include "Vtop.h"
#include "Vtop___024root.h"

// PTY support (optional, only needed for use_local_pty = 0)
#ifdef ENABLE_PTY
  #ifdef __APPLE__
    #include <util.h>
  #else
    #include <pty.h>
  #endif
  #include <termios.h>
#endif

void init();
void print_imem(int size);
int load_elf(const char* filename, uint8_t* buffer, size_t buffer_size);
int validate_and_load_binary(const char* bin_filename, const char* disasm_filename,
                              uint8_t* buffer, size_t buffer_size);

#define MAX_CYCLES 100;
#define EBREAK_INSTR 0x00100073
uint8_t imem[0x1000000]; // 16MB instruction memory buffer (matches SRAM hardware)

// UART PTY globals (only used when ENABLE_PTY is defined)
#ifdef ENABLE_PTY
int master_fd, slave_fd;
char slave_name[128];
#endif

// Global variables for signal handler
volatile sig_atomic_t interrupted = 0;
volatile sig_atomic_t ebreak_hit = 0;
#if VM_TRACE
VerilatedVcdC* global_tfp = nullptr;
#endif
Vtop* global_dut = nullptr;

void signal_handler(int signum) {
  if (signum == SIGINT) {
    printf("\n[UART] Ctrl+C received, dumping VCD and terminating...\n");
    interrupted = 1;
  }
}

// Thread to monitor for EBREAK
void* ebreak_monitor_thread(void* arg) {
  while (!interrupted && !ebreak_hit) {
    sleep(1);

    if (global_dut != nullptr && global_dut->break_hit) {
      fflush(stdout);
      printf("\n[EBREAK] Break detected, terminating simulation...\n");
      // Note: cycle count will be printed in main loop
      ebreak_hit = 1;
      break;
    }
  }
  return nullptr;
}

#ifdef ENABLE_PTY
void setup_pty() {
  struct termios tio{};
  openpty(&master_fd, &slave_fd, slave_name, NULL, NULL);
  tcgetattr(slave_fd, &tio);
  cfmakeraw(&tio);
  tcsetattr(slave_fd, TCSANOW, &tio);
  fcntl(master_fd, F_SETFL, O_NONBLOCK);
  printf("[UART] Connect with: screen %s 115200\n", slave_name);
}
#endif

// UART bit timing simulation
class UARTBitDriver {
private:
  uint64_t cycle_counter;
  uint64_t cycles_per_bit;  // Number of clock cycles per UART bit

  // TX state
  uint8_t tx_byte;
  int tx_bit_index;  // -1: idle, 0: start, 1-8: data, 9: stop
  uint64_t tx_bit_start_cycle;

  // RX state
  int rx_bit_index;  // -1: idle, 0: start, 1-8: data, 9: stop
  uint64_t rx_bit_start_cycle;
  uint8_t rx_byte;
  bool rx_line_prev;

public:
  UARTBitDriver(uint64_t clk_freq = 50000000, uint64_t baud_rate = 115200)
    : cycle_counter(0),
      tx_bit_index(-1),
      tx_bit_start_cycle(0),
      rx_bit_index(-1),
      rx_bit_start_cycle(0),
      rx_byte(0),
      rx_line_prev(true) {
    cycles_per_bit = clk_freq / baud_rate;
  }

  // Call this every clock cycle
  void tick() {
    cycle_counter++;
  }

  // Start transmitting a byte (Host -> UART RX)
  bool start_tx(uint8_t byte) {
    if (tx_bit_index != -1) return false;  // Already transmitting
    tx_byte = byte;
    tx_bit_index = 0;  // Start bit
    tx_bit_start_cycle = cycle_counter;
    return true;
  }

  // Get current TX line state (this drives UART RX input)
  bool get_tx_line() {
    if (tx_bit_index == -1) return true;  // Idle high

    // Check if we need to advance to next bit
    if (cycle_counter - tx_bit_start_cycle >= cycles_per_bit) {
      tx_bit_index++;
      tx_bit_start_cycle = cycle_counter;

      if (tx_bit_index >= 10) {  // Done with stop bit
        tx_bit_index = -1;
      }
    }

    if (tx_bit_index == 0) return false;  // Start bit
    if (tx_bit_index >= 1 && tx_bit_index <= 8) {
      return (tx_byte >> (tx_bit_index - 1)) & 1;  // Data bits
    }
    return true;  // Stop bit
  }

  // Sample RX line and decode bytes (UART TX -> Host)
  bool sample_rx(bool rx_line, uint8_t* byte_out) {
    // Detect start bit (falling edge)
    if (rx_bit_index == -1 && rx_line_prev && !rx_line) {
      rx_bit_index = 0;
      rx_bit_start_cycle = cycle_counter;
      rx_byte = 0;
    }
    rx_line_prev = rx_line;

    if (rx_bit_index == -1) return false;  // No reception in progress

    // Sample at middle of bit period
    uint64_t bit_elapsed = cycle_counter - rx_bit_start_cycle;
    if (bit_elapsed >= cycles_per_bit / 2 && bit_elapsed < cycles_per_bit / 2 + 1) {
      if (rx_bit_index == 0) {
        // Start bit - should be 0
        if (rx_line) {
          // Framing error - abort
          rx_bit_index = -1;
          printf("[UART] Framing error: start bit not low\n");
          return false;
        }
      } else if (rx_bit_index >= 1 && rx_bit_index <= 8) {
        // Data bits
        if (rx_line) {
          rx_byte |= (1 << (rx_bit_index - 1));
        }
      } else if (rx_bit_index == 9) {
        // Stop bit - should be 1
        if (!rx_line) {
          // Framing error
          rx_bit_index = -1;
          return false;
        }
      }
    }

    // Advance to next bit
    if (bit_elapsed >= cycles_per_bit) {
      rx_bit_index++;
      rx_bit_start_cycle = cycle_counter;

      if (rx_bit_index >= 10) {  // Done with stop bit
        *byte_out = rx_byte;
        rx_bit_index = -1;
        return true;  // Byte received
      }
    }

    return false;
  }

  bool is_idle() {
    return tx_bit_index == -1;
  }
};

int main(int argc, char** argv) {

  int use_local_pty = 1;
  Verilated::commandArgs(argc, argv);

  // Setup signal handler for Ctrl+C
  signal(SIGINT, signal_handler);

  const char* hex_path = (argc >= 2) ? argv[1] : "firmware/firmware.hex";

  // Extract base name from hex path for output files
  const char* base_name = strrchr(hex_path, '/');
  base_name = base_name ? base_name + 1 : hex_path;

  // Remove .hex extension if present
  char test_name[256];
  strncpy(test_name, base_name, sizeof(test_name) - 1);
  test_name[sizeof(test_name) - 1] = '\0';
  char* ext = strstr(test_name, ".hex");
  if (ext) *ext = '\0';

  char disasm_path[256];
  char vcd_path[256];
  char trace_path[256];
  char instruction_trace_path[256];

  snprintf(disasm_path, sizeof(disasm_path), "%s.d", test_name);
  snprintf(vcd_path, sizeof(vcd_path), "%s.vcd", test_name);
  snprintf(trace_path, sizeof(trace_path), "%s_trace.txt", test_name);
  snprintf(instruction_trace_path, sizeof(instruction_trace_path), "%s_instruction_trace.txt", test_name);

  // Initialize imem with ebreak instructions first
  init();

  // Load and validate hex file (overwrites the beginning of imem)
  int bytes_loaded = validate_and_load_binary(hex_path, disasm_path, imem, sizeof(imem));
  if (bytes_loaded < 0) {
    fprintf(stderr, "Failed to load hex file: %s\n", hex_path);
    return 1;
  }

  //print_imem(bytes_loaded);

  // Setup PTY for UART
#ifdef ENABLE_PTY
  if (!use_local_pty) {
    setup_pty();
  } else {
    // Make stdin non-blocking
    fcntl(STDIN_FILENO, F_SETFL, fcntl(STDIN_FILENO, F_GETFL) | O_NONBLOCK);
  }
#else
  // PTY support disabled at compile time, forcing local PTY mode
  use_local_pty = 1;
  fcntl(STDIN_FILENO, F_SETFL, fcntl(STDIN_FILENO, F_GETFL) | O_NONBLOCK);
#endif

  Vtop* dut = new Vtop;
#if VM_TRACE
  Verilated::traceEverOn(true);
  VerilatedVcdC* tfp = new VerilatedVcdC;
  dut->trace(tfp, 99);
  printf("Opening %s for output...\n", vcd_path);
  tfp->open(vcd_path);
  global_tfp = tfp;
#endif
  global_dut = dut;

  // Start EBREAK monitor thread
  pthread_t monitor_thread;
  pthread_create(&monitor_thread, nullptr, ebreak_monitor_thread, nullptr);

  FILE* trace_file = fopen(trace_path, "w");
  if (!trace_file) {
    fprintf(stderr, "Failed to open trace file: %s\n", trace_path);
    return 1;
  }
  fprintf(trace_file, "# Cycle req_addr   req_wdata  req_wmask req_write req_valid resp_valid resp_rdata\n");

  UARTBitDriver uart_driver;

  dut->clk = 0;
  dut->resetn = 0;
  dut->rx = 1;  // UART idle is high

  // Load program into SRAM (no need to zero entire memory - only write what we need)
  printf("Loading %d bytes into SRAM (0x%x bytes, last word index: 0x%x)\n",
         bytes_loaded, bytes_loaded, (bytes_loaded >> 2));

  // Check if program fits in SRAM
  if (bytes_loaded > 0x1000000) {  // 16MB limit
    fprintf(stderr, "Warning: Program size (%d bytes) exceeds SRAM size (16MB)\n", bytes_loaded);
  }

  for (int i = 0; i < bytes_loaded && i < 0x1000000; i += 4) {
    uint32_t word = (imem[i + 0]) |
                    (imem[i + 1] << 8) |
                    (imem[i + 2] << 16) |
                    (imem[i + 3] << 24);
    dut->rootp->top__DOT__sram0__DOT__mem[i >> 2] = word;
  }


  dut->clk = 0;    dut->eval();
  dut->clk = 1;    dut->eval();
  dut->resetn = 1; dut->eval();
#if VM_TRACE
  tfp->dump(0); tfp->dump(1); tfp->dump(2);
#endif

  dut->rootp->top__DOT__sim_use_par_txrx = 1;
  auto par_txrx = dut->rootp->top__DOT__sim_use_par_txrx;

  printf("[UART] Simulation started. Connect with screen and type.\n");
  printf("[UART] Press Ctrl+C to terminate.\n");

  uint64_t tick_count = 0;
  uint8_t rx_fifo[256];
  int rx_fifo_head = 0, rx_fifo_tail = 0;

  int time_counter = 3;
  int cycle = 0;
  while (!Verilated::gotFinish() && !interrupted && !ebreak_hit) {
    // Tick UART driver
    uart_driver.tick();
    tick_count++;

    // Read from PTY (host -> UART)
    uint8_t ch;
    ssize_t n;
    if (use_local_pty) {
      n = read(STDIN_FILENO, &ch, 1);
    }
#ifdef ENABLE_PTY
    else {
      n = read(master_fd, &ch, 1);
    }
#endif
    if (n > 0) {
      //printf("[PTY RX] Read byte from terminal: 0x%02X ('%c')\n", ch,
      //       (ch >= 32 && ch <= 126) ? ch : '.');
      // Check for Ctrl+D (EOF character, ASCII 4)
      if (ch == 4) {
        printf("[UART] Ctrl+D received, terminating.\n");
        break;
      }
      // Queue byte for transmission
      int next_tail = (rx_fifo_tail + 1) % 256;
      if (next_tail != rx_fifo_head) {
        rx_fifo[rx_fifo_tail] = ch;
        rx_fifo_tail = next_tail;
      }
    }

    if (par_txrx) {
      if(dut->par_rx_ack) {
        dut->par_rx_valid = 0;
      }
      if (dut->par_rx_valid == 0 && rx_fifo_head != rx_fifo_tail) {
        dut->par_rx = rx_fifo[rx_fifo_head];
        dut->par_rx_valid = 1;
        rx_fifo_head = (rx_fifo_head + 1) % 256;
      }
    } else {
      if (rx_fifo_head != rx_fifo_tail && uart_driver.is_idle()) {
        uart_driver.start_tx(rx_fifo[rx_fifo_head]);
        rx_fifo_head = (rx_fifo_head + 1) % 256;
      }
    }

    // Update UART input
    dut->rx = uart_driver.get_tx_line();

    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
#if VM_TRACE
    tfp->dump(time_counter++);
    tfp->dump(time_counter++);
#else
    time_counter += 2;
#endif

    

    // Sample TX output
    uint8_t rx_byte;
    bool received;
    if (par_txrx) {
      received = dut->par_tx_valid;
      rx_byte = dut->par_tx;
    } else {
      received = uart_driver.sample_rx(dut->tx, &rx_byte);
    }
    if (received) {
      if (use_local_pty) {
        putchar(rx_byte);
        fflush(stdout);
      }
#ifdef ENABLE_PTY
      else {
        write(master_fd, &rx_byte, 1);
      }
#endif
    }

    // Small delay to avoid consuming 100% CPU
    if (tick_count % 1000 == 0) {
      usleep(1);
    }

    cycle++;
  }

  // Signal monitor thread to exit and wait for it
  interrupted = 1;
  pthread_join(monitor_thread, nullptr);

  // Print simulation statistics
  printf("\n=== Simulation Statistics ===\n");
  printf("Total cycles: %d\n", cycle);
  printf("==============================\n");

#if VM_TRACE
  tfp->close();
  delete tfp;
#endif

  // Print dmem contents from 0x0 to 0xc at end of simulation
  fprintf(trace_file, "\n# Data Memory Contents (0x0 to 0xc):\n");
  for (uint32_t addr = 0x0; addr <= 0xc; addr += 4) {
    uint32_t data = dut->rootp->top__DOT__sram0__DOT__mem[addr >> 2];
    fprintf(trace_file, "# dmem[0x%08x] = 0x%08x\n", addr, data);
  }

  delete dut;
  global_dut = nullptr;

  fclose(trace_file);
  printf("Trace written to %s\n", trace_path);

  // Only close PTY if it was opened
#ifdef ENABLE_PTY
  if (!use_local_pty) {
    close(master_fd);
    close(slave_fd);
  }
#endif

#if VM_TRACE
  printf("[UART] VCD saved to %s\n", vcd_path);
#endif
  return 0;
}
