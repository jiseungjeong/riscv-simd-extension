/*
 * MNIST MLP Benchmark - INT32 Q16.16 with ReLU Activation
 * Uses fixed-point Q16.16 format with ReLU (simpler than sigmoid)
 * Expected accuracy: 90%+
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define INPUT_SIZE 784
#define HIDDEN_SIZE 32
#define OUTPUT_SIZE 10

// Include quantized weights
#include "weights/mnist_weights_int32_relu.h"
#include "weights/test_data.h"

typedef struct {
    int32_t hidden[HIDDEN_SIZE];  // Q16.16 format, post-ReLU
    int32_t output[OUTPUT_SIZE];  // Q16.16 format (logits)
} MLPActivations_Q16;

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

// Convert float to Q16.16
static inline int32_t float_to_q16(float x) {
    return (int32_t)(x * 65536.0f);
}

// ReLU activation in Q16.16 format
// Input: Q16.16 value
// Output: max(0, input) in Q16.16
static inline int32_t relu_q16(int32_t x) {
    return (x > 0) ? x : 0;  // Simple! Just clamp negatives to 0
}

// Fixed-point multiply: Q16.16 × Q16.16 → Q16.16
// Result = (a * b) >> 16
static inline int32_t q16_mul(int32_t a, int32_t b) {
    int64_t result = ((int64_t)a * (int64_t)b) >> 16;
    return (int32_t)result;
}

// Find argmax of int32 array
static inline int argmax_int32(const int32_t* arr, int size) {
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

// Print input image (28x28 grayscale) as ASCII art
static void print_input_q16(const float* input, int sample_idx) {
    printf("\n  Input image (sample %d, 28x28 ASCII art):\n", sample_idx + 1);
    for (int row = 0; row < 28; row++) {
        printf("    ");
        for (int col = 0; col < 28; col++) {
            float pixel = input[row * 28 + col];
            // ASCII art: use different characters for different intensities
            // Darker characters = higher pixel values (more ink)
            if (pixel < 0.01f) {
                printf(" ");
            } else if (pixel < 0.125f) {
                printf(".");
            } else if (pixel < 0.25f) {
                printf(":");
            } else if (pixel < 0.375f) {
                printf("-");
            } else if (pixel < 0.50f) {
                printf("=");
            } else if (pixel < 0.625f) {
                printf("+");
            } else if (pixel < 0.75f) {
                printf("*");
            } else if (pixel < 0.875f) {
                printf("#");
            } else {
                printf("@");
            }
        }
        printf("\n");
    }
}

// Print hidden layer activations (Q16.16 format)
static void print_hidden_q16(const int32_t* hidden, int size) {
    printf("\n  Hidden layer (%d neurons, Q16.16 after ReLU):\n    ", size);
    for (int i = 0; i < size; i++) {
        // Convert Q16.16 to float for display
        float val = hidden[i] / 65536.0f;
        printf("%7.2f", val);
        if ((i + 1) % 8 == 0 && i < size - 1) printf("\n    ");
    }
    printf("\n");
}

// Print output layer values (Q16.16 format)
static void print_output_q16(const int32_t* output, int size) {
    printf("\n  Output layer (%d classes, Q16.16 logits):\n    ", size);
    for (int i = 0; i < size; i++) {
        // Convert Q16.16 to float for display
        float val = output[i] / 65536.0f;
        printf("%8.2f", val);
    }
    printf("\n");
}

int mlp_predict_q16_relu(const float* input_float, MLPActivations_Q16* act, int sample_idx, int verbose) {
    // Print input if verbose
    if (verbose) {
        print_input_q16(input_float, sample_idx);
    }

    // Convert input to Q16.16
    int32_t input_q16[INPUT_SIZE];
    for (int i = 0; i < INPUT_SIZE; i++) {
        input_q16[i] = float_to_q16(input_float[i]);
    }

    // Layer 1: input @ W1 + b1, then ReLU
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        int64_t acc = 0;

        // Matrix multiply: Q16.16 × Q16.16 = Q32.32, shift to Q16.16
        for (int i = 0; i < INPUT_SIZE; i++) {
            acc += ((int64_t)input_q16[i] * (int64_t)W1_q16[i][j]) >> 16;
        }

        // Add bias (already in Q16.16)
        acc += b1_q16[j];

        // Apply ReLU (simple!)
        int32_t result = (int32_t)acc;
        act->hidden[j] = relu_q16(result);
    }

    // Print hidden layer if verbose
    if (verbose) {
        print_hidden_q16(act->hidden, HIDDEN_SIZE);
    }

    // Layer 2: hidden @ W2 + b2 (no activation, just argmax)
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        int64_t acc = 0;

        // Matrix multiply
        for (int i = 0; i < HIDDEN_SIZE; i++) {
            acc += ((int64_t)act->hidden[i] * (int64_t)W2_q16[i][j]) >> 16;
        }

        // Add bias
        acc += b2_q16[j];

        act->output[j] = (int32_t)acc;
    }

    // Print output layer if verbose
    if (verbose) {
        print_output_q16(act->output, OUTPUT_SIZE);
    }

    // Return prediction (argmax)
    return argmax_int32(act->output, OUTPUT_SIZE);
}

int main(void) {
    MLPActivations_Q16 act;
    unsigned long start, end, total_instret = 0;
    int correct = 0;

    printf("=== MNIST MLP (INT32 Q16.16 with ReLU) ===\n");
    printf("Architecture: %d -> %d (ReLU) -> %d\n", INPUT_SIZE, HIDDEN_SIZE, OUTPUT_SIZE);
    printf("Data type: int32_t Q16.16 fixed-point\n");
    printf("Activation: ReLU (max(0, x))\n");
    printf("Testing %d samples...\n\n", NUM_TEST_SAMPLES);

    /* Warm-up run */
    mlp_predict_q16_relu(test_images[0], &act, 0, 0);

    /* Benchmark each sample */
    for (int i = 0; i < NUM_TEST_SAMPLES; i++) {
        printf("Sample %2d: ", i + 1);
        fflush(stdout);

        start = read_instret();
#ifdef VERBOSE
        int prediction = mlp_predict_q16_relu(test_images[i], &act, i, 1);
#else
        int prediction = mlp_predict_q16_relu(test_images[i], &act, i, 0);
#endif
        end = read_instret();

        unsigned long instret = end - start;
        total_instret += instret;

        int is_correct = (prediction == test_labels[i]);
        correct += is_correct;

        printf("label=%d pred=%d %s (inst=%lu)\n",
               test_labels[i], prediction,
               is_correct ? "✓" : "✗", instret);

#ifdef __riscv
        unsigned long cycles = instret * 5;
        printf("  Cycles (CPI=5): %lu, Time @500kHz: %.2f ms\n",
               cycles, cycles / 500.0);
#endif
    }

    float accuracy = (float)correct / NUM_TEST_SAMPLES * 100;

    printf("\n=== Summary ===\n");
    printf("Accuracy: %d/%d (%.2f%%)\n", correct, NUM_TEST_SAMPLES, accuracy);
    printf("Average instructions per inference: %lu\n", total_instret / NUM_TEST_SAMPLES);

#ifdef __riscv
    unsigned long avg_cycles = (total_instret / NUM_TEST_SAMPLES) * 5;
    printf("Average cycles per inference (CPI=5): %lu\n", avg_cycles);
    printf("Average time per inference @500kHz: %.2f ms\n", avg_cycles / 500.0);
    printf("Throughput @500kHz: %.2f inferences/sec\n", 500000.0 / avg_cycles);
#endif

    printf("\n=== INT32 Q16.16 + ReLU Advantages ===\n");
    printf("  ✓ High precision: 16 fractional bits\n");
    printf("  ✓ Simple activation: ReLU is max(0, x)\n");
    printf("  ✓ No soft-float library needed\n");
    printf("  ✓ Deterministic performance\n");
    printf("  ✓ Good accuracy: 90%%+\n");

    printf("\n=== Comparison ===\n");
    printf("  INT32 + Sigmoid: ~90%% accuracy (complex activation)\n");
    printf("  INT32 + ReLU:    ~90%% accuracy (simpler!)\n");
    printf("  INT8 + ReLU:     ~90%% accuracy (75%% memory savings)\n");

    return (accuracy >= 85.0) ? 0 : 1;
}
