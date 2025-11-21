#include "test.h"

void init_trap() {
  // Set mtvec to the address of the trap handler (here we use main as a placeholder)
  write_csr(mtvec, (int)trap_vector);
}

void trap_entry() {
  // Simple trap handler that just loops indefinitely
  puts("Trap occurred!\n");
  puts("mcause: ");
  int cause = read_csr(mcause);
  printint(cause, 16, 0);
  puts("\n");
  if(cause == 2) {
    puts("Illegal instruction trap detected.\n");
    ebreak();
  } else if (cause == 11) {
    puts("ECALL detected.\n");
  } else if (cause == 7) {
    puts("Timer interrupt detected.\n");
    clear_timer();
  } else {
    puts("Unknown trap cause.\n");
  }
  return;
}