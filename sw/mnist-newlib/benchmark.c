/*
 * Benchmark MNIST MLP inference
 * Compile with -DBENCHMARK to enable instruction counting via rdinstret
 */

#include <stdio.h>
#include <math.h>

#define INPUT_SIZE 784
#define HIDDEN_SIZE 32
#define OUTPUT_SIZE 10

#include "weights/mnist_weights.h"
#include "weights/test_data.h"

typedef struct {
    const float (*W1)[HIDDEN_SIZE];
    const float *b1;
    const float (*W2)[OUTPUT_SIZE];
    const float *b2;
} MLPWeights;

typedef struct {
    float hidden[HIDDEN_SIZE];
    float output[OUTPUT_SIZE];
} MLPActivations;

/* Read instruction counter (RISC-V) */
#ifdef __riscv
static inline unsigned long read_instret(void) {
    unsigned long instret;
    asm volatile ("rdinstret %0" : "=r" (instret));
    return instret;
}
#else
/* x86/ARM fallback - use cycle counter or approximation */
#include <time.h>
static unsigned long read_instret(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000000UL + ts.tv_nsec;
}
#endif

static inline float sigmoid(float x) {
    if (x < -20.0f) return 0.0f;
    if (x > 20.0f) return 1.0f;
    return 1.0f / (1.0f + expf(-x));
}

void softmax(float* output, int size) {
    float max_val = output[0];
    for (int i = 1; i < size; i++) {
        if (output[i] > max_val) max_val = output[i];
    }

    float sum = 0.0f;
    for (int i = 0; i < size; i++) {
        output[i] = expf(output[i] - max_val);
        sum += output[i];
    }

    for (int i = 0; i < size; i++) {
        output[i] /= sum;
    }
}

int mlp_predict(const float* input, const MLPWeights* weights, MLPActivations* act) {
    /* Hidden layer: 784x32 matmul + 32 sigmoid */
    for (int j = 0; j < HIDDEN_SIZE; j++) {
        float z = weights->b1[j];
        for (int i = 0; i < INPUT_SIZE; i++) {
            z += input[i] * weights->W1[i][j];
        }
        act->hidden[j] = sigmoid(z);
    }

    /* Output layer: 32x10 matmul + softmax */
    for (int j = 0; j < OUTPUT_SIZE; j++) {
        float z = weights->b2[j];
        for (int i = 0; i < HIDDEN_SIZE; i++) {
            z += act->hidden[i] * weights->W2[i][j];
        }
        act->output[j] = z;
    }

    softmax(act->output, OUTPUT_SIZE);

    /* Find max */
    int predicted_class = 0;
    float max_prob = act->output[0];
    for (int i = 1; i < OUTPUT_SIZE; i++) {
        if (act->output[i] > max_prob) {
            max_prob = act->output[i];
            predicted_class = i;
        }
    }

    return predicted_class;
}

int main(void) {
    MLPWeights weights = {
        .W1 = W1,
        .b1 = b1,
        .W2 = W2,
        .b2 = b2
    };

    MLPActivations act;
    unsigned long start, end, total_instret = 0;
    int correct = 0;

    printf("=== MNIST MLP Benchmark ===\n");
    printf("Architecture: %d -> %d -> %d\n", INPUT_SIZE, HIDDEN_SIZE, OUTPUT_SIZE);
    printf("Testing %d samples...\n\n", NUM_TEST_SAMPLES);

    /* Warm-up run */
    mlp_predict(test_images[0], &weights, &act);

    /* Benchmark each sample */
    for (int i = 0; i < NUM_TEST_SAMPLES; i++) {
        start = read_instret();
        int prediction = mlp_predict(test_images[i], &weights, &act);
        end = read_instret();

        unsigned long instret = end - start;
        total_instret += instret;

        int is_correct = (prediction == test_labels[i]);
        correct += is_correct;

        printf("Sample %d: label=%d pred=%d %s\n",
               i + 1, test_labels[i], prediction,
               is_correct ? "✓" : "✗");
        printf("  Instructions: %lu\n", instret);

#ifdef __riscv
        /* Assume CPI = 5 for educational CPU */
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

    /* Theoretical operation count */
    printf("\n=== Theoretical Analysis ===\n");
    unsigned long matmul1_ops = INPUT_SIZE * HIDDEN_SIZE * 2; // multiply-add
    unsigned long sigmoid_ops = HIDDEN_SIZE * 10; // approx
    unsigned long matmul2_ops = HIDDEN_SIZE * OUTPUT_SIZE * 2;
    unsigned long softmax_ops = OUTPUT_SIZE * 10; // approx
    unsigned long total_ops = matmul1_ops + sigmoid_ops + matmul2_ops + softmax_ops;

    printf("Operations per inference:\n");
    printf("  Hidden layer matmul (784x32): %lu\n", matmul1_ops);
    printf("  Sigmoid activations (32): %lu\n", sigmoid_ops);
    printf("  Output layer matmul (32x10): %lu\n", matmul2_ops);
    printf("  Softmax (10): %lu\n", softmax_ops);
    printf("  Total: %lu operations\n", total_ops);
    printf("\nAssuming ~3 instructions per operation: ~%lu instructions\n", total_ops * 3);
    printf("With CPI=5: ~%lu cycles\n", total_ops * 3 * 5);
    printf("Time @500kHz: ~%.2f ms\n", (total_ops * 3 * 5) / 500.0);

    return 0;
}
