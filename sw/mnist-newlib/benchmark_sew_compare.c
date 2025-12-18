// SEW Comparison Benchmark
// Compare Lab7 PVMAC (32-bit, 4 lanes) vs Wide Vector SEW=8/16/32

#include <stdio.h>
#include <stdint.h>

// Performance counter access
static inline unsigned int read_cycle_counter(void) {
    unsigned int count;
    asm volatile (".insn i 0x5B, 0, %0, x0, 0" : "=r"(count));
    return count;
}

// ============================================================
// Test data: Simple dot product of 64 elements
// ============================================================
#define TEST_SIZE 64

int8_t test_a[TEST_SIZE] __attribute__((aligned(8)));
int8_t test_b[TEST_SIZE] __attribute__((aligned(8)));
int16_t test_a16[TEST_SIZE/2] __attribute__((aligned(8)));
int16_t test_b16[TEST_SIZE/2] __attribute__((aligned(8)));
int32_t test_a32[TEST_SIZE/4] __attribute__((aligned(8)));
int32_t test_b32[TEST_SIZE/4] __attribute__((aligned(8)));

void init_test_data(void) {
    for (int i = 0; i < TEST_SIZE; i++) {
        test_a[i] = (i % 10) - 5;
        test_b[i] = (i % 7) - 3;
    }
    for (int i = 0; i < TEST_SIZE/2; i++) {
        test_a16[i] = (i % 100) - 50;
        test_b16[i] = (i % 70) - 35;
    }
    for (int i = 0; i < TEST_SIZE/4; i++) {
        test_a32[i] = (i % 1000) - 500;
        test_b32[i] = (i % 700) - 350;
    }
}

// ============================================================
// Lab 7: PVMAC (32-bit register, 4 x int8 lanes)
// ============================================================
static inline int32_t pvmac(int32_t a, int32_t b) {
    int32_t result;
    asm volatile (".insn r 0x5B, 1, 2, %0, %1, %2"
                  : "=r"(result)
                  : "r"(a), "r"(b));
    return result;
}

int32_t dot_product_pvmac(void) {
    int32_t sum = 0;
    for (int i = 0; i < TEST_SIZE; i += 4) {
        uint32_t a_packed = ((uint32_t)(uint8_t)test_a[i+3] << 24) |
                            ((uint32_t)(uint8_t)test_a[i+2] << 16) |
                            ((uint32_t)(uint8_t)test_a[i+1] << 8) |
                            (uint8_t)test_a[i];
        uint32_t b_packed = ((uint32_t)(uint8_t)test_b[i+3] << 24) |
                            ((uint32_t)(uint8_t)test_b[i+2] << 16) |
                            ((uint32_t)(uint8_t)test_b[i+1] << 8) |
                            (uint8_t)test_b[i];
        sum += pvmac(a_packed, b_packed);
    }
    return sum;
}

// ============================================================
// Wide Vector: VLD + VMAC
// ============================================================
static inline void vld_v1(const void *addr) {
    asm volatile (".insn r 0x5B, 2, 4, x1, %0, x0" : : "r"(addr) : "memory");
}
static inline void vld_v2(const void *addr) {
    asm volatile (".insn r 0x5B, 2, 4, x2, %0, x0" : : "r"(addr) : "memory");
}

// VMAC.B: SEW=8 (8 lanes)
static inline int32_t vmac_b(void) {
    int32_t result;
    asm volatile (".insn r 0x5B, 2, 3, %0, x1, x2" : "=r"(result));
    return result;
}

// VMAC.H: SEW=16 (4 lanes) - funct7 = 0x23
static inline int32_t vmac_h(void) {
    int32_t result;
    asm volatile (".insn r 0x5B, 2, 0x23, %0, x1, x2" : "=r"(result));
    return result;
}

// VMAC.W: SEW=32 (2 lanes) - funct7 = 0x43
static inline int32_t vmac_w(void) {
    int32_t result;
    asm volatile (".insn r 0x5B, 2, 0x43, %0, x1, x2" : "=r"(result));
    return result;
}

int32_t dot_product_vmac_b(void) {
    int32_t sum = 0;
    for (int i = 0; i < TEST_SIZE; i += 8) {
        vld_v1(&test_a[i]);
        vld_v2(&test_b[i]);
        sum += vmac_b();
    }
    return sum;
}

int32_t dot_product_vmac_h(void) {
    int32_t sum = 0;
    for (int i = 0; i < TEST_SIZE/2; i += 4) {
        vld_v1(&test_a16[i]);
        vld_v2(&test_b16[i]);
        sum += vmac_h();
    }
    return sum;
}

int32_t dot_product_vmac_w(void) {
    int32_t sum = 0;
    for (int i = 0; i < TEST_SIZE/4; i += 2) {
        vld_v1(&test_a32[i]);
        vld_v2(&test_b32[i]);
        sum += vmac_w();
    }
    return sum;
}

// ============================================================
// Main - No printf for results, use RDWRCTR output
// ============================================================
volatile int32_t result_pvmac;
volatile int32_t result_vmac_b;
volatile int32_t result_vmac_h;
volatile int32_t result_vmac_w;

int main(void) {
    printf("=== SEW Comparison ===\n");
    
    init_test_data();
    
    // Warm-up
    dot_product_pvmac();
    dot_product_vmac_b();
    dot_product_vmac_h();
    dot_product_vmac_w();
    
    unsigned int c0, c1, c2, c3, c4;
    
    // Benchmark PVMAC (4 x int8)
    c0 = read_cycle_counter();
    for (int iter = 0; iter < 100; iter++) {
        result_pvmac = dot_product_pvmac();
    }
    
    // Benchmark VMAC.B (8 x int8)
    c1 = read_cycle_counter();
    for (int iter = 0; iter < 100; iter++) {
        result_vmac_b = dot_product_vmac_b();
    }
    
    // Benchmark VMAC.H (4 x int16)
    c2 = read_cycle_counter();
    for (int iter = 0; iter < 100; iter++) {
        result_vmac_h = dot_product_vmac_h();
    }
    
    // Benchmark VMAC.W (2 x int32)
    c3 = read_cycle_counter();
    for (int iter = 0; iter < 100; iter++) {
        result_vmac_w = dot_product_vmac_w();
    }
    
    c4 = read_cycle_counter();
    
    printf("Done.\n");
    
    asm volatile ("ebreak");
    return 0;
}
