// Lab 7.5: Vectorize MNIST with New Instructions
// Benchmark PVMAC instructions

#include <stdio.h>
#include <stdint.h>

#define INPUT_SIZE 784
#define HIDDEN_SIZE 32
#define OUTPUT_SIZE 10

#include "weights/mnist_weights_int8.h" // quantized weights INT8 use
#include "weights/test_data.h"

static inline int32_t pack4(int8_t a, int8_t b, int8_t c, int8_t d) {
    return ((uint32_t)(uint8_t)d << 24) |
           ((uint32_t)(uint8_t)c << 16) |
           ((uint32_t)(uint8_t)b << 8)  |
           (uint8_t)a;
}

static inline int32_t pvmac(int32_t a, int32_t b) {
    int32_t result;
    asm volatile (".insn r 0x5B, 1, 2, %0, %1, %2"
                  : "=r"(result)
                  : "r"(a), "r"(b));
    return result;
}

static inline int8_t relu_int8(int32_t x) {
    if (x < 0) return 0;
    if (x > 127) return 127;
    else return (int8_t)x;
}

// 7.6 Performance counter access using RDWRCTR instruction
// Using .insn i format so GCC understands register allocation
// Format: .insn i opcode, funct3, rd, rs1, imm
// RDWRCTR: opcode=0x5B, funct3=0, rd=%0, rs1=x0, imm=counter_id
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

int mlp_forward_pvmac(const int8_t *input_i8, int8_t *hidden, int8_t *output) {
    // Layer 1: 784 inputs -> 32 hidden neurons
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < INPUT_SIZE; i += 4) {
            int32_t input_vec = pack4(input_i8[i], input_i8[i+1], input_i8[i+2], input_i8[i+3]);
            int32_t weight_vec = pack4(W1_i8[i][j], W1_i8[i+1][j], W1_i8[i+2][j], W1_i8[i+3][j]);
            acc += pvmac(input_vec, weight_vec);
        }   
        hidden[j] = relu_int8(acc);
    }
    // Layer 2: 32 hidden neurons -> 10 output neurons
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        int32_t acc = 0;
        for (int i = 0; i < HIDDEN_SIZE; i += 4) {
            int32_t hidden_vec = pack4(hidden[i], hidden[i+1], hidden[i+2], hidden[i+3]);
            int32_t weight_vec = pack4(W2_i8[i][j], W2_i8[i+1][j], W2_i8[i+2][j], W2_i8[i+3][j]);
            acc += pvmac(hidden_vec, weight_vec);
        }
        output[j] = relu_int8(acc);
    }
    
    int predicted_class = 0; // argmax
    int32_t max_val = output[0];
    for (int i = 1; i < OUTPUT_SIZE; i++) {
        if (output[i] > max_val) {
            max_val = output[i];
            predicted_class = i;
        }
    }
    return predicted_class;
}

int main(void) {
    printf("=== MNIST MLP Benchmark (PVMAC) ===\n\n");

    int8_t hidden[HIDDEN_SIZE];
    int8_t output[OUTPUT_SIZE];

    // Convert float test input to int8
    int8_t input_i8[INPUT_SIZE];
    for (int i = 0; i < INPUT_SIZE; i++) {
        input_i8[i] = (int8_t)(test_images[0][i] * 127.0f);
    }
    
    // Warm-up run
    mlp_forward_pvmac(input_i8, hidden, output);
    
    // Benchmark with performance counters
    unsigned int cycle_start = read_cycle_counter();
    unsigned int insn_start = read_insn_counter();
    unsigned int load_start = read_load_counter();
    unsigned int store_start = read_store_counter();
    
    int predicted = mlp_forward_pvmac(input_i8, hidden, output);
    
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
