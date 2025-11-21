/*
 * MNIST MLP Benchmark - INT32 Fixed-Point Version
 * Uses 32-bit integers with fixed-point arithmetic
 * No floating-point operations during inference
 * Q16.16 format: 16 integer bits + 16 fractional bits
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define INPUT_SIZE 784
#define HIDDEN_SIZE 32
#define OUTPUT_SIZE 10

// Q16.16 fixed-point format
#define FP_SHIFT 16
#define FP_ONE (1 << FP_SHIFT)  // 1.0 in fixed-point

#include "weights/mnist_weights_int32.h"
#include "weights/test_data.h"

typedef struct {
    int32_t hidden[HIDDEN_SIZE];
    int32_t output[OUTPUT_SIZE];
} MLPActivations_INT32;

/* Read instruction counter (RISC-V) */
#ifdef __riscv
static inline unsigned long read_instret(void) {
    unsigned long instret;
    __asm__ volatile ("rdinstret %0" : "=r" (instret));
    return instret;
}
#else
#include <time.h>
static unsigned long read_instret(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000000UL + ts.tv_nsec;
}
#endif

// Convert float to Q16.16 fixed-point
static inline int32_t float_to_fp(float x) {
    return (int32_t)(x * FP_ONE);
}

// Convert Q16.16 to float (for display)
static inline float fp_to_float(int32_t x) {
    return (float)x / FP_ONE;
}

// Q16.16 multiply: (a * b) >> 16
static inline int32_t fp_mul(int32_t a, int32_t b) {
    int64_t temp = ((int64_t)a * (int64_t)b);
    return (int32_t)(temp >> FP_SHIFT);
}

// Sigmoid approximation in fixed-point
static int32_t sigmoid_fp(int32_t x) {
    // x is in Q16.16 format
    // Piecewise linear approximation

    int32_t five_fp = 5 * FP_ONE;

    if (x < -five_fp) return 0;
    if (x > five_fp) return FP_ONE;

    // Linear region: sigmoid(x) ≈ 0.5 + 0.25*x for |x| < 5
    int32_t result = (FP_ONE >> 1) + (x >> 2);

    if (result < 0) return 0;
    if (result > FP_ONE) return FP_ONE;

    return result;
}

// Exp approximation for softmax (not used - we just need argmax)
// Find argmax
static int argmax_int32(const int32_t* arr, int size) {
    int max_idx = 0;
    int32_t max_val = arr[0];
    for (int i = 1; i < size; i++) {
        if (arr[i] > max_val) {
            max_val = arr[i];
            max_idx = i;
        }
    }
    return max_idx;
}

// Pre-quantized weights are loaded from mnist_weights_int32.h
// No runtime quantization needed!

// Global flag to control progress output
static int show_progress = 1;

int mlp_predict_int32(const float* input_float, MLPActivations_INT32* act) {
    // Convert input to fixed-point
    int32_t input_fp[INPUT_SIZE];
    for (int i = 0; i < INPUT_SIZE; i++) {
        input_fp[i] = float_to_fp(input_float[i]);
    }

    // Hidden layer: 784x32 matmul + bias + sigmoid
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        // Progress indicator every 8 neurons
        if (show_progress && j % 8 == 0) {
            printf(".");
            fflush(stdout);
        }

        int32_t acc = b1_fp[j];

        for (int i = 0; i < INPUT_SIZE; i++) {
            acc += fp_mul(input_fp[i], W1_fp[i][j]);
        }

        act->hidden[j] = sigmoid_fp(acc);
    }

    if (show_progress) {
        printf("H");  // Hidden layer complete
        fflush(stdout);
    }

    // Output layer: 32x10 matmul + bias
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        int32_t acc = b2_fp[j];

        for (int i = 0; i < HIDDEN_SIZE; i++) {
            acc += fp_mul(act->hidden[i], W2_fp[i][j]);
        }

        act->output[j] = acc;
    }

    if (show_progress) {
        printf("O ");  // Output layer complete
        fflush(stdout);
    }

    return argmax_int32(act->output, OUTPUT_SIZE);
}

int main(void) {
    MLPActivations_INT32 act;
    unsigned long start, end, total_instret = 0;
    int correct = 0;

    printf("=== MNIST MLP Benchmark (INT32 Q16.16 Fixed-Point) ===\n");
    printf("Architecture: %d -> %d -> %d\n", INPUT_SIZE, HIDDEN_SIZE, OUTPUT_SIZE);
    printf("Data type: int32_t (Q16.16: 16 integer + 16 fractional bits)\n");
    printf("Weights: Pre-quantized offline (no runtime quantization)\n");
    printf("Testing %d samples...\n\n", NUM_TEST_SAMPLES);

    /* Warm-up run (no progress output) */
    //show_progress = 0;
    //mlp_predict_int32(test_images[0], &act);
    show_progress = 1;

    /* Benchmark each sample */
    for (int i = 0; i < NUM_TEST_SAMPLES; i++) {
        printf("[%d/%d] ----HO\n", i + 1, NUM_TEST_SAMPLES);
        printf("[%d/%d] Processing...", i + 1, NUM_TEST_SAMPLES);
        fflush(stdout);  // Ensure progress is visible on slow simulators

        start = read_instret();
        int prediction = mlp_predict_int32(test_images[i], &act);
        end = read_instret();

        unsigned long instret = end - start;
        total_instret += instret;

        int is_correct = (prediction == test_labels[i]);
        correct += is_correct;

        printf("\rSample %d: label=%d pred=%d %s\n",
               i + 1, test_labels[i], prediction,
               is_correct ? "[OK]" : "[FAIL]");
        printf("  Instructions: %lu\n", instret);

#ifdef __riscv
        unsigned long cycles = instret * 5;
        printf("  Cycles (CPI=5): %lu\n", cycles);
        printf("  Time @500kHz: %.2f ms\n", cycles / 500.0);
#endif
    }

    printf("\n=== Summary ===\n");
    printf("Accuracy: %d/%d (%.2f%%)\n", correct, NUM_TEST_SAMPLES,
           (float)correct / NUM_TEST_SAMPLES * 100);
    printf("Average instructions per inference: %lu\n", total_instret / NUM_TEST_SAMPLES);

#ifdef __riscv
    unsigned long avg_cycles = (total_instret / NUM_TEST_SAMPLES) * 5;
    printf("Average cycles per inference (CPI=5): %lu\n", avg_cycles);
    printf("Average time per inference @500kHz: %.2f ms\n", avg_cycles / 500.0);
    printf("Throughput @500kHz: %.2f inferences/sec\n", 500000.0 / avg_cycles);
#endif

    printf("\n=== INT32 Q16.16 Advantages ===\n");
    printf("  - No soft-float library needed\n");
    printf("  - High precision (16 fractional bits)\n");
    printf("  - Wide range (±32K integer part)\n");
    printf("  - Simple multiply: (a*b)>>16\n");
    printf("  - RV32IM hardware multiply\n");
    printf("  - Good accuracy vs floating-point\n");

    return 0;
}
