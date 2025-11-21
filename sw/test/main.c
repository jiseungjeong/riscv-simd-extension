#include "test.h"
#include <stdint.h>

void echo() {
  puts("Echo test started. Type characters to echo them back. Press Ctrl+C to exit.\n");
  for(int i = 0; i < 10; i = i * 3) {
    puts("Type a character: ");
    char c = getchar();
    putchar(c);
    putchar('\n');
    fflush();
  }
}

void csr_test() {
  puts("=== CSR Test Suite ===\n");
  int passed = 0;
  int failed = 0;

  // Test 1: mtvec (0x305)
  puts("Test 1: mtvec... ");
  int test_val1 = 0xdeadbeef;
  write_csr(mtvec, test_val1);
  int read_val1 = read_csr(mtvec);
  if (read_val1 == test_val1) {
    puts("PASSED\n");
    passed++;
  } else {
    puts("FAILED\n");
    printf("  Expected: 0x%x, Got: 0x%x\n", test_val1, read_val1);
    failed++;
  }

  // Test 2: mepc (0x341)
  puts("Test 2: mepc... ");
  int test_val2 = 0x12345678;
  write_csr(mepc, test_val2);
  int read_val2 = read_csr(mepc);
  if (read_val2 == test_val2) {
    puts("PASSED\n");
    passed++;
  } else {
    puts("FAILED\n");
    printf("  Expected: 0x%x, Got: 0x%x\n", test_val2, read_val2);
    failed++;
  }

  // Test 3: mstatus (0x300)
  puts("Test 3: mstatus... ");
  int test_val3 = 0x00001800;
  write_csr(mstatus, test_val3);
  int read_val3 = read_csr(mstatus);
  if (read_val3 == test_val3) {
    puts("PASSED\n");
    passed++;
  } else {
    puts("FAILED\n");
    printf("  Expected: 0x%x, Got: 0x%x\n", test_val3, read_val3);
    failed++;
  }
  write_csr(mstatus, 0x8);

  // Test 4: mcause (0x342)
  puts("Test 4: mcause... ");
  int test_val4 = 0xfaceface;
  write_csr(mcause, test_val4);
  int read_val4 = read_csr(mcause);
  if (read_val4 == test_val4) {
    puts("PASSED\n");
    passed++;
  } else {
    puts("FAILED\n");
    printf("  Expected: 0x%x, Got: 0x%x\n", test_val4, read_val4);
    failed++;
  }

  // Test 5: mie (0x304)
  puts("Test 5: mie... ");
  int test_val5 = 0x00000888;
  write_csr(mie, test_val5);
  int read_val5 = read_csr(mie);
  if (read_val5 == test_val5) {
    puts("PASSED\n");
    passed++;
  } else {
    puts("FAILED\n");
    printf("  Expected: 0x%x, Got: 0x%x\n", test_val5, read_val5);
    failed++;
  }

  // Test 6: mip (0x344)
  puts("Test 6: mip... ");
  int test_val6 = 0x00000080;
  write_csr(mip, test_val6);
  int read_val6 = read_csr(mip);
  if (read_val6 == test_val6) {
    puts("PASSED\n");
    passed++;
  } else {
    puts("FAILED\n");
    printf("  Expected: 0x%x, Got: 0x%x\n", test_val6, read_val6);
    failed++;
  }

  // Summary
  puts("\n=== CSR Test Summary ===\n");
  printf("Passed: %d\n", passed);
  printf("Failed: %d\n", failed);
  if (failed == 0) {
    puts("All CSR tests PASSED!\n");
  } else {
    puts("Some CSR tests FAILED!\n");
  }
}



int main(int argc, char** argv) {

  //puts("Hello, World!");
  puts("Hello, RISC-V World!\n");
  
  csr_test();
  init_trap();
  //echo();
  //fflush();
  //for(int i = 0; i < 10000; i+=1);
  insn_tests();
  puts("Instruction tests completed.\n");

  // set_timer(100, 0);
  // int lower, upper;
  // read_timer(&lower, &upper);
  // printf("Timer set to: lower=%d, upper=%d\n", lower, upper);
  // for(int i = 0; i < 500000; i++);
  // read_timer(&lower, &upper);
  // printf("Timer read after delay: lower=%d, upper=%d\n", lower, upper);
  // clear_timer();
  puts("begin: pvadd test\n");
  int a = 0;
  int b = 0;
  a = (1 << 24) | (2 << 16) | (3 << 8) | 4; // a = [1,2,3,4]
  b = (10 << 24) | (20 << 16) | (30 << 8) | 40; // b = [10,20,30,40]
  int pvadd_result = pvadd(a, b); // Expect [11,22,33,44]
  printf("PVADD result: %d %d %d %d + %d %d %d %d = %d %d %d %d\n", (a & 0xFF000000) >> 24, (a & 0x00FF0000) >> 16, (a & 0x0000FF00) >> 8, a & 0x000000FF,
         (b & 0xFF000000) >> 24, (b & 0x00FF0000) >> 16, (b & 0x0000FF00) >> 8, b & 0x000000FF,
         (pvadd_result & 0xFF000000) >> 24, (pvadd_result & 0x00FF0000) >> 16,
         (pvadd_result & 0x0000FF00) >> 8, pvadd_result & 0x000000FF);
  
  a = (1 << 24) | (2 << 16) | (3 << 8) | 4; // a = [1,2,3,4]
  b = (10 << 24) | (20 << 16) | (30 << 8) | 40; // b = [10,20,30,40]
  int pvmul_result = pvmul(a, b); // Expect [10,40,90,160]
  printf("PVMUL result: %d * %d + %d * %d = %d %d\n", (a & 0xFF00) >> 8, 
         (b & 0xFF00) >> 8, a & 0x00FF, b & 0x00FF,
         (pvmul_result & 0xFFFF0000) >> 16, pvmul_result & 0x0000FFFF);

  int pvmul_upper_result = pvmul_upper(a, b); // Expect [20,60]
  printf("PVMUL_UPPER result: %d * %d + %d * %d = %d %d\n", (a & 0xFF000000) >> 24, 
         (b & 0xFF000000) >> 24, (a & 0x00FF0000) >> 16, (b & 0x00FF0000) >> 16,
         (pvmul_upper_result & 0xFFFF0000) >> 16, pvmul_upper_result & 0x0000FFFF);
  int pvmac_result = pvmac(a, b); // Expect 10+40+90+160 = 300
  printf("PVMAC result: %d * %d + %d * %d + %d * %d + %d * %d = %d\n",
         (a & 0xFF000000) >> 24, (b & 0xFF000000) >> 24,
         (a & 0x00FF0000) >> 16, (b & 0x00FF0000) >> 16,
         (a & 0x0000FF00) >> 8, (b & 0x0000FF00) >> 8,
         a & 0x000000FF, b & 0x000000FF,
         pvmac_result);
  puts("end: pvadd test\n");

  int32_t packed_multiply_accumulate_exact = ((((int8_t)(a & 0xFF) * (int8_t)(b & 0xFF)) & 0xFF) +
            (((int8_t)((a >> 8) & 0xFF) * (int8_t)((b >> 8) & 0xFF)) & 0xFF00)) +
           ((((int8_t)((a >> 16) & 0xFF) * (int8_t)((b >> 16) & 0xFF)) & 0xFF0000) +
            (((int8_t)(a >> 24) * (int8_t)(b >> 24)) & 0xFF000000));
  printf("PVMAC exact result: %d\n", packed_multiply_accumulate_exact);


  
  
  ecall();
  illegal_instruction();

  ebreak();
  return 0;
}