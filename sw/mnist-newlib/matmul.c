/*
 * Matrix Multiplication Benchmark (8x8 int32)
 * Measures multiply/divide instruction performance
 */

#include <stdio.h>
#include <stdint.h>

#define N 8  // Matrix size

// Test matrices
int32_t A[N][N] = {
    {1, 2, 3, 4, 5, 6, 7, 8},
    {2, 3, 4, 5, 6, 7, 8, 1},
    {3, 4, 5, 6, 7, 8, 1, 2},
    {4, 5, 6, 7, 8, 1, 2, 3},
    {5, 6, 7, 8, 1, 2, 3, 4},
    {6, 7, 8, 1, 2, 3, 4, 5},
    {7, 8, 1, 2, 3, 4, 5, 6},
    {8, 1, 2, 3, 4, 5, 6, 7}
};

int32_t B[N][N] = {
    {8, 7, 6, 5, 4, 3, 2, 1},
    {7, 6, 5, 4, 3, 2, 1, 8},
    {6, 5, 4, 3, 2, 1, 8, 7},
    {5, 4, 3, 2, 1, 8, 7, 6},
    {4, 3, 2, 1, 8, 7, 6, 5},
    {3, 2, 1, 8, 7, 6, 5, 4},
    {2, 1, 8, 7, 6, 5, 4, 3},
    {1, 8, 7, 6, 5, 4, 3, 2}
};

int32_t C[N][N];  // Result matrix

// Performance counter functions (from Lab 5)
static inline unsigned long read_instret(void) {
#ifdef __riscv
    unsigned long count;
    asm volatile ("rdinstret %0" : "=r"(count));
    return count;
#else
    return 0;
#endif
}

static inline unsigned long read_cycle(void) {
#ifdef __riscv
    unsigned long count;
    asm volatile ("rdcycle %0" : "=r"(count));
    return count;
#else
    return 0;
#endif
}

// Matrix multiplication: C = A * B
void matmul(int32_t A[N][N], int32_t B[N][N], int32_t C[N][N]) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            int32_t sum = 0;
            for (int k = 0; k < N; k++) {
                sum += A[i][k] * B[k][j];  // MUL instruction
            }
            C[i][j] = sum;
        }
    }
}

// Print matrix (first 4x4 only for brevity)
void print_matrix(const char *name, int32_t M[N][N]) {
    printf("%s (first 4x4):\n", name);
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            printf("%6ld ", (long)M[i][j]);
        }
        printf("\n");
    }
    printf("\n");
}

int main() {
    printf("\n=== Matrix Multiplication Benchmark (%dx%d int32) ===\n", N, N);
    printf("Total multiplications: %d\n", N * N * N);
    printf("Operation: C = A * B\n\n");

    // Warm-up run
    matmul(A, B, C);

    // Benchmark run
    unsigned long start_cycle = read_cycle();
    unsigned long start_inst = read_instret();

    matmul(A, B, C);

    unsigned long end_cycle = read_cycle();
    unsigned long end_inst = read_instret();

    // Print results
    print_matrix("Matrix A", A);
    print_matrix("Matrix B", B);
    print_matrix("Result C", C);

    // Performance metrics
    unsigned long cycles = end_cycle - start_cycle;
    unsigned long instret = end_inst - start_inst;

    printf("=== Performance ===\n");
    printf("Instructions: %lu\n", instret);

#ifdef __riscv
    printf("Cycles: %lu\n", cycles);
    if (instret > 0) {
        printf("CPI: %.2f\n", (float)cycles / instret);
    }
    printf("Time @500kHz: %.2f ms\n", cycles / 500.0);
#endif

    // Expected result check (C[0][0] for 8x8 matrices above)
    int32_t expected = 204;  // Calculated offline
    if (C[0][0] == expected) {
        printf("\nResult verification: PASS (C[0][0]=%ld)\n", (long)C[0][0]);
    } else {
        printf("\nResult verification: FAIL (C[0][0]=%ld, expected %ld)\n",
               (long)C[0][0], (long)expected);
    }

    return 0;
}
