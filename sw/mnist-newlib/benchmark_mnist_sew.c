// MNIST Scalar vs Vector Comparison Benchmark
// Compare: Scalar (no SIMD) vs Lab7 PVMAC (4 lanes) vs Wide Vector (8 lanes)
// Based on README.md 4.4.6: "Compare scalar vs. vector implementations"

#include <stdio.h>
#include <stdint.h>

#define INPUT_SIZE 784
#define HIDDEN_SIZE 32
#define OUTPUT_SIZE 10

#include "weights/mnist_weights_int8.h"
#include "weights/test_data.h"

// Pre-packed weights for vector access (INT8)
int8_t W1_packed[HIDDEN_SIZE][INPUT_SIZE] __attribute__((aligned(8)));
int8_t W2_packed[OUTPUT_SIZE][HIDDEN_SIZE] __attribute__((aligned(8)));

// Pre-packed weights for VMAC.H (INT16)
int16_t W1_packed_h[HIDDEN_SIZE][INPUT_SIZE] __attribute__((aligned(8)));
int16_t W2_packed_h[OUTPUT_SIZE][HIDDEN_SIZE] __attribute__((aligned(8)));

// Pre-packed weights for VMAC.W (INT32)
int32_t W1_packed_w[HIDDEN_SIZE][INPUT_SIZE] __attribute__((aligned(8)));
int32_t W2_packed_w[OUTPUT_SIZE][HIDDEN_SIZE] __attribute__((aligned(8)));

// Input buffers for different SEWs
int16_t input_h[INPUT_SIZE] __attribute__((aligned(8)));
int32_t input_w[INPUT_SIZE] __attribute__((aligned(8)));

void prepare_weights(void) {
    // Transpose and align W1/W2 for vector access (all SEWs)
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        for (int i = 0; i < INPUT_SIZE; i++) {
            W1_packed[j][i] = W1_i8[i][j];
            W1_packed_h[j][i] = (int16_t)W1_i8[i][j];
            W1_packed_w[j][i] = (int32_t)W1_i8[i][j];
        }
    }
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        for (int i = 0; i < HIDDEN_SIZE; i++) {
            W2_packed[j][i] = W2_i8[i][j];
            W2_packed_h[j][i] = (int16_t)W2_i8[i][j];
            W2_packed_w[j][i] = (int32_t)W2_i8[i][j];
        }
    }
}

// Performance counter
static inline unsigned int read_cycle_counter(void) {
    unsigned int count;
    asm volatile (".insn i 0x5B, 0, %0, x0, 0" : "=r"(count));
    return count;
}

static inline int8_t relu_int8(int32_t x) {
    if (x < 0) return 0;
    if (x > 127) return 127;
    return (int8_t)x;
}

// ============================================================
// SCALAR: Pure scalar implementation (no SIMD)
// ============================================================
int mlp_forward_scalar(const int8_t *input, int8_t *hidden, int8_t *output) {
    // Layer 1: 784 multiplies per neuron, 32 neurons = 25,088 multiplies
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < INPUT_SIZE; i++) {
            acc += (int32_t)input[i] * (int32_t)W1_packed[j][i];
        }
        hidden[j] = relu_int8(acc);
    }
    
    // Layer 2: 32 multiplies per neuron, 10 neurons = 320 multiplies
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < HIDDEN_SIZE; i++) {
            acc += (int32_t)hidden[i] * (int32_t)W2_packed[j][i];
        }
        output[j] = relu_int8(acc);
    }
    
    int pred = 0;
    for (int i = 1; i < OUTPUT_SIZE; i++) {
        if (output[i] > output[pred]) pred = i;
    }
    return pred;
}

// ============================================================
// Lab 7: PVMAC (32-bit, 4 x int8 lanes)
// ============================================================
static inline int32_t pvmac(int32_t a, int32_t b) {
    int32_t result;
    asm volatile (".insn r 0x5B, 1, 2, %0, %1, %2"
                  : "=r"(result)
                  : "r"(a), "r"(b));
    return result;
}

int mlp_forward_pvmac(const int8_t *input, int8_t *hidden, int8_t *output) {
    // Layer 1
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < INPUT_SIZE; i += 4) {
            uint32_t in = *(uint32_t*)&input[i];
            uint32_t wt = *(uint32_t*)&W1_packed[j][i];
            acc += pvmac(in, wt);
        }
        hidden[j] = relu_int8(acc);
    }
    
    // Layer 2
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < HIDDEN_SIZE; i += 4) {
            uint32_t hd = *(uint32_t*)&hidden[i];
            uint32_t wt = *(uint32_t*)&W2_packed[j][i];
            acc += pvmac(hd, wt);
        }
        output[j] = relu_int8(acc);
    }
    
    int pred = 0;
    for (int i = 1; i < OUTPUT_SIZE; i++) {
        if (output[i] > output[pred]) pred = i;
    }
    return pred;
}

// ============================================================
// Wide Vector: VLD and VMAC instructions
// ============================================================
// VLD (load 64-bit to vector register)
static inline void vld_v1(const void *addr) {
    asm volatile (".insn r 0x5B, 2, 4, x1, %0, x0" : : "r"(addr) : "memory");
}
static inline void vld_v2(const void *addr) {
    asm volatile (".insn r 0x5B, 2, 4, x2, %0, x0" : : "r"(addr) : "memory");
}

// VMAC.B: 8 x int8 lanes, funct7 = 0x03 (00_00011)
static inline int32_t vmac_b(void) {
    int32_t result;
    asm volatile (".insn r 0x5B, 2, 0x03, %0, x1, x2" : "=r"(result));
    return result;
}

// VMAC.H: 4 x int16 lanes, funct7 = 0x23 (01_00011)
static inline int32_t vmac_h(void) {
    int32_t result;
    asm volatile (".insn r 0x5B, 2, 0x23, %0, x1, x2" : "=r"(result));
    return result;
}

// VMAC.W: 2 x int32 lanes, funct7 = 0x43 (10_00011)
static inline int32_t vmac_w(void) {
    int32_t result;
    asm volatile (".insn r 0x5B, 2, 0x43, %0, x1, x2" : "=r"(result));
    return result;
}

int mlp_forward_vmac_b(const int8_t *input, int8_t *hidden, int8_t *output) {
    // Layer 1: 784 / 8 = 98 iterations per neuron (8 lanes)
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < INPUT_SIZE; i += 8) {
            vld_v1(&input[i]);
            vld_v2(&W1_packed[j][i]);
            acc += vmac_b();
        }
        hidden[j] = relu_int8(acc);
    }
    
    // Layer 2: 32 / 8 = 4 iterations per neuron
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < HIDDEN_SIZE; i += 8) {
            vld_v1(&hidden[i]);
            vld_v2(&W2_packed[j][i]);
            acc += vmac_b();
        }
        output[j] = relu_int8(acc);
    }
    
    int pred = 0;
    for (int i = 1; i < OUTPUT_SIZE; i++) {
        if (output[i] > output[pred]) pred = i;
    }
    return pred;
}

// ============================================================
// Wide Vector: VMAC.H (64-bit, 4 x int16 lanes)
// ============================================================
int16_t hidden_h[HIDDEN_SIZE] __attribute__((aligned(8)));
int16_t output_h[OUTPUT_SIZE] __attribute__((aligned(8)));

int mlp_forward_vmac_h(const int16_t *input, int16_t *hidden, int16_t *output) {
    // Layer 1: 784 / 4 = 196 iterations per neuron (4 lanes)
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < INPUT_SIZE; i += 4) {
            vld_v1(&input[i]);
            vld_v2(&W1_packed_h[j][i]);
            acc += vmac_h();
        }
        hidden[j] = (acc < 0) ? 0 : (acc > 32767 ? 32767 : (int16_t)acc);
    }
    
    // Layer 2: 32 / 4 = 8 iterations per neuron
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < HIDDEN_SIZE; i += 4) {
            vld_v1(&hidden[i]);
            vld_v2(&W2_packed_h[j][i]);
            acc += vmac_h();
        }
        output[j] = (acc < 0) ? 0 : (acc > 32767 ? 32767 : (int16_t)acc);
    }
    
    int pred = 0;
    for (int i = 1; i < OUTPUT_SIZE; i++) {
        if (output[i] > output[pred]) pred = i;
    }
    return pred;
}

// ============================================================
// Wide Vector: VMAC.W (64-bit, 2 x int32 lanes)
// ============================================================
int32_t hidden_w[HIDDEN_SIZE] __attribute__((aligned(8)));
int32_t output_w[OUTPUT_SIZE] __attribute__((aligned(8)));

int mlp_forward_vmac_w(const int32_t *input, int32_t *hidden, int32_t *output) {
    // Layer 1: 784 / 2 = 392 iterations per neuron (2 lanes)
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < INPUT_SIZE; i += 2) {
            vld_v1(&input[i]);
            vld_v2(&W1_packed_w[j][i]);
            acc += vmac_w();
        }
        hidden[j] = (acc < 0) ? 0 : acc;
    }
    
    // Layer 2: 32 / 2 = 16 iterations per neuron
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < HIDDEN_SIZE; i += 2) {
            vld_v1(&hidden[i]);
            vld_v2(&W2_packed_w[j][i]);
            acc += vmac_w();
        }
        output[j] = (acc < 0) ? 0 : acc;
    }
    
    int pred = 0;
    for (int i = 1; i < OUTPUT_SIZE; i++) {
        if (output[i] > output[pred]) pred = i;
    }
    return pred;
}

// ============================================================
// Main
// ============================================================
int main(void) {
    printf("=== SEW Compare ===\n");
    
    // Prepare input for INT8
    int8_t input[INPUT_SIZE] __attribute__((aligned(8)));
    int8_t hidden[HIDDEN_SIZE] __attribute__((aligned(8)));
    int8_t output[OUTPUT_SIZE] __attribute__((aligned(8)));
    
    for (int i = 0; i < INPUT_SIZE; i++) {
        int8_t val = (int8_t)(test_images[0][i] * 127.0f);
        input[i] = val;
        input_h[i] = (int16_t)val;  // Extend to INT16
        input_w[i] = (int32_t)val;  // Extend to INT32
    }
    
    // Prepare weights (transpose for vector access)
    prepare_weights();
    
    // Warm-up all implementations
    mlp_forward_scalar(input, hidden, output);
    mlp_forward_pvmac(input, hidden, output);
    mlp_forward_vmac_b(input, hidden, output);
    mlp_forward_vmac_h(input_h, hidden_h, output_h);
    mlp_forward_vmac_w(input_w, hidden_w, output_w);
    
    unsigned int c0, c1, c2, c3, c4, c5;
    
    // Benchmark Scalar (no SIMD, 1 lane)
    c0 = read_cycle_counter();
    mlp_forward_scalar(input, hidden, output);
    
    // Benchmark PVMAC (Lab7, 4 lanes)
    c1 = read_cycle_counter();
    mlp_forward_pvmac(input, hidden, output);
    
    // Benchmark VMAC.B (8 lanes, SEW=8)
    c2 = read_cycle_counter();
    mlp_forward_vmac_b(input, hidden, output);
    
    // Benchmark VMAC.H (4 lanes, SEW=16)
    c3 = read_cycle_counter();
    mlp_forward_vmac_h(input_h, hidden_h, output_h);
    
    // Benchmark VMAC.W (2 lanes, SEW=32)
    c4 = read_cycle_counter();
    mlp_forward_vmac_w(input_w, hidden_w, output_w);
    c5 = read_cycle_counter();
    
    printf("Done.\n");
    
    asm volatile ("ebreak");
    return 0;
}

