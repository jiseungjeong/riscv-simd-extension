// Wide Vector Extension: Vectorize MNIST with 64-bit VLEN
// Uses actual VLD + VMAC.B hardware instructions (8 lanes)
// Compare with Lab 7 PVMAC (4 lanes)

#include <stdio.h>
#include <stdint.h>

#define INPUT_SIZE 784
#define HIDDEN_SIZE 32
#define OUTPUT_SIZE 10

#include "weights/mnist_weights_int8.h"
#include "weights/test_data.h"

// ============================================================
// Wide Vector Instructions (64-bit VLEN, 8 x int8 lanes)
// ============================================================

// VLD: Load 64-bit from memory to vector register
// Encoding: opcode=0x5B, funct3=010, funct7=0x04 (VOP_VLD=00100)
// Format: vld vd, rs1  -> .insn r opcode, funct3, funct7, vd, rs1, x0

// VMAC.B: 8-lane int8 multiply-accumulate, result to scalar register
// Encoding: opcode=0x5B, funct3=010, funct7=0x03 (VOP_VMAC=00011)
// Format: vmac.b rd, vs1, vs2  -> .insn r opcode, funct3, funct7, rd, vs1, vs2

// Load 8 bytes from memory to vector register v1
static inline void vld_v1(const int8_t *addr) {
    // vld v1, addr  (v1 = vector reg 1)
    // .insn r 0x5B, 2, 4, v1, rs1, x0
    // v1 = x1 in encoding (rd field = 1)
    asm volatile (
        ".insn r 0x5B, 2, 4, x1, %0, x0"
        : 
        : "r"(addr)
        : "memory"
    );
}

// Load 8 bytes from memory to vector register v2
static inline void vld_v2(const int8_t *addr) {
    asm volatile (
        ".insn r 0x5B, 2, 4, x2, %0, x0"
        : 
        : "r"(addr)
        : "memory"
    );
}

// VMAC.B: Multiply v1 and v2 (8 x int8), sum products to scalar
static inline int32_t vmac_b_v1_v2(void) {
    int32_t result;
    // vmac.b result, v1, v2
    // .insn r 0x5B, 2, 3, rd, v1, v2
    asm volatile (
        ".insn r 0x5B, 2, 3, %0, x1, x2"
        : "=r"(result)
        :
        :
    );
    return result;
}

// Combined: Load two vectors and compute MAC
static inline int32_t vec_mac_8(const int8_t *input_ptr, const int8_t *weight_ptr) {
    vld_v1(input_ptr);
    vld_v2(weight_ptr);
    return vmac_b_v1_v2();
}

// ============================================================
// ReLU activation
// ============================================================
static inline int8_t relu_int8(int32_t x) {
    if (x < 0) return 0;
    if (x > 127) return 127;
    return (int8_t)x;
}

// ============================================================
// Performance Counters (RDWRCTR)
// ============================================================
static inline unsigned int read_cycle_counter(void) {
    unsigned int count;
    asm volatile (".insn i 0x5B, 0, %0, x0, 0" : "=r"(count));
    return count;
}

static inline unsigned int read_insn_counter(void) {
    unsigned int count;
    asm volatile (".insn i 0x5B, 0, %0, x0, 1" : "=r"(count));
    return count;
}

static inline unsigned int read_load_counter(void) {
    unsigned int count;
    asm volatile (".insn i 0x5B, 0, %0, x0, 2" : "=r"(count));
    return count;
}

static inline unsigned int read_store_counter(void) {
    unsigned int count;
    asm volatile (".insn i 0x5B, 0, %0, x0, 3" : "=r"(count));
    return count;
}

// ============================================================
// MLP Forward Pass using Wide Vector Instructions
// ============================================================
int mlp_forward_wide_vec(const int8_t *input_i8, int8_t *hidden, int8_t *output) {
    // Prepare weight arrays in row-major order for vectorized access
    // W1: 784 x 32, need to access 8 weights at a time for each hidden neuron
    // For each hidden neuron j, weights are W1[0][j], W1[1][j], ... W1[783][j]
    // But these are not contiguous! We need transposed or strided access.
    
    // Simplified approach: Pack weights on the fly (same overhead as before)
    // Real optimization would require weight layout transformation
    
    // Layer 1: 784 inputs -> 32 hidden neurons
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        int32_t acc = 0;
        
        // Process 8 inputs at a time using vector instructions
        for (int i = 0; i < INPUT_SIZE; i += 8) {
            // Create aligned temporary arrays for vector load
            int8_t input_vec[8] __attribute__((aligned(8)));
            int8_t weight_vec[8] __attribute__((aligned(8)));
            
            // Pack 8 input values
            for (int k = 0; k < 8; k++) {
                input_vec[k] = input_i8[i + k];
                weight_vec[k] = W1_i8[i + k][j];
            }
            
            // Use VLD + VMAC.B hardware instructions
            acc += vec_mac_8(input_vec, weight_vec);
        }
        hidden[j] = relu_int8(acc);
    }
    
    // Layer 2: 32 hidden -> 10 output neurons
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        int32_t acc = 0;
        
        for (int i = 0; i < HIDDEN_SIZE; i += 8) {
            int8_t hidden_vec[8] __attribute__((aligned(8)));
            int8_t weight_vec[8] __attribute__((aligned(8)));
            
            for (int k = 0; k < 8; k++) {
                hidden_vec[k] = hidden[i + k];
                weight_vec[k] = W2_i8[i + k][j];
            }
            
            acc += vec_mac_8(hidden_vec, weight_vec);
        }
        output[j] = relu_int8(acc);
    }
    
    // Find predicted class
    int predicted_class = 0;
    int32_t max_val = output[0];
    for (int i = 1; i < OUTPUT_SIZE; i++) {
        if (output[i] > max_val) {
            max_val = output[i];
            predicted_class = i;
        }
    }
    return predicted_class;
}

// ============================================================
// Main
// ============================================================
int main(void) {
    printf("=== MNIST MLP Benchmark (Wide Vector 64-bit) ===\n\n");

    int8_t hidden[HIDDEN_SIZE];
    int8_t output[OUTPUT_SIZE];

    // Convert float test input to int8
    int8_t input_i8[INPUT_SIZE];
    for (int i = 0; i < INPUT_SIZE; i++) {
        input_i8[i] = (int8_t)(test_images[0][i] * 127.0f);
    }
    
    // Warm-up run
    mlp_forward_wide_vec(input_i8, hidden, output);
    
    // Benchmark with performance counters
    unsigned int cycle_start = read_cycle_counter();
    unsigned int insn_start = read_insn_counter();
    unsigned int load_start = read_load_counter();
    unsigned int store_start = read_store_counter();
    
    int predicted = mlp_forward_wide_vec(input_i8, hidden, output);
    
    unsigned int cycle_end = read_cycle_counter();
    unsigned int insn_end = read_insn_counter();
    unsigned int load_end = read_load_counter();
    unsigned int store_end = read_store_counter();

    printf("Predicted class: %d\n", predicted);
    printf("Done. See RDWRCTR output for counters.\n");
    
    // Trigger EBREAK to end simulation
    asm volatile ("ebreak");
    
    return 0;
}
