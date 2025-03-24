#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <omp.h>

int main(int argc, char *argv[]) {
    // Now accepts an optional 4th argument: num_threads (only for parallel mode)
    if (argc != 4 && argc != 5) {
        fprintf(stderr, "Usage: %s <N> <seq|par> <flat|transposed> [num_threads]\n", argv[0]);
        return 1;
    }

    int N = atoi(argv[1]);
    if (N <= 0) {
        fprintf(stderr, "N must be a positive integer.\n");
        return 1;
    }

    char *mode = argv[2];         // "seq" or "par"
    char *multType = argv[3];     // "flat" or "transposed"

    int useParallel = 0, useTransposed = 0;
    if (strcmp(mode, "seq") == 0) {
        useParallel = 0;
    } else if (strcmp(mode, "par") == 0) {
        useParallel = 1;
    } else {
        fprintf(stderr, "Second argument must be 'seq' or 'par'\n");
        return 1;
    }

    if (strcmp(multType, "flat") == 0) {
        useTransposed = 0;
    } else if (strcmp(multType, "transposed") == 0) {
        useTransposed = 1;
    } else {
        fprintf(stderr, "Third argument must be 'flat' or 'transposed'\n");
        return 1;
    }

    int num_threads = 0;
    if (useParallel) {
        if (argc == 5) {
            num_threads = atoi(argv[4]);
            if (num_threads <= 0) {
                fprintf(stderr, "num_threads must be a positive integer.\n");
                return 1;
            }
        } else {
            // Default to all available logical cores
            num_threads = omp_get_max_threads();
        }
    }

    // Allocate and initialize matrices A and B (always needed)
    double *A = (double *) malloc(N * N * sizeof(double));
    double *B = (double *) malloc(N * N * sizeof(double));
    if (!A || !B) {
        fprintf(stderr, "Error allocating memory for A or B.\n");
        return 1;
    }
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            A[i*N + j] = i + j;  // example initialization
            B[i*N + j] = i - j;  // example initialization
        }
    }

    // If transposed multiplication is chosen, allocate and compute B_T.
    double *B_T = NULL;
    if (useTransposed) {
        B_T = (double *) malloc(N * N * sizeof(double));
        if (!B_T) {
            fprintf(stderr, "Error allocating memory for B_T.\n");
            free(A);
            free(B);
            return 1;
        }
        for (int i = 0; i < N; i++) {
            for (int j = 0; j < N; j++) {
                B_T[i*N + j] = B[j*N + i];
            }
        }
    }

    // Allocate the result matrix C (only one result array is needed)
    double *C = (double *) calloc(N * N, sizeof(double));
    if (!C) {
        fprintf(stderr, "Error allocating memory for C.\n");
        free(A);
        free(B);
        if (B_T) free(B_T);
        return 1;
    }

    double start_time, end_time, elapsed_time;
    start_time = omp_get_wtime();

    if (!useParallel) { // Sequential execution
        if (!useTransposed) { // Sequential flat multiplication: C = A * B
            for (int i = 0; i < N; i++) {
                for (int j = 0; j < N; j++) {
                    double sum = 0.0;
                    for (int k = 0; k < N; k++) {
                        sum += A[i*N + k] * B[k*N + j];
                    }
                    C[i*N + j] = sum;
                }
            }
        } else { // Sequential transposed multiplication: C = A * B_T
            for (int i = 0; i < N; i++) {
                for (int j = 0; j < N; j++) {
                    double sum = 0.0;
                    for (int k = 0; k < N; k++) {
                        sum += A[i*N + k] * B_T[j*N + k];
                    }
                    C[i*N + j] = sum;
                }
            }
        }
    } else { // Parallel execution
        omp_set_num_threads(num_threads);  // Set the desired number of threads
        if (!useTransposed) { // Parallel flat multiplication: C = A * B
            #pragma omp parallel for
            for (int i = 0; i < N; i++) {
                for (int j = 0; j < N; j++) {
                    double sum = 0.0;
                    for (int k = 0; k < N; k++) {
                        sum += A[i*N + k] * B[k*N + j];
                    }
                    C[i*N + j] = sum;
                }
            }
        } else { // Parallel transposed multiplication: C = A * B_T
            #pragma omp parallel for
            for (int i = 0; i < N; i++) {
                for (int j = 0; j < N; j++) {
                    double sum = 0.0;
                    for (int k = 0; k < N; k++) {
                        sum += A[i*N + k] * B_T[j*N + k];
                    }
                    C[i*N + j] = sum;
                }
            }
        }
    }

    end_time = omp_get_wtime();
    elapsed_time = end_time - start_time;

    // Print the timing result according to mode and multiplication type
    if (!useParallel) {
        if (!useTransposed)
            printf("Sequential flat: %.6f\n", elapsed_time);
        else
            printf("Sequential transposed: %.6f\n", elapsed_time);
    } else {
        if (!useTransposed)
            printf("Parallel flat: %.6f\n", elapsed_time);
        else
            printf("Parallel transposed: %.6f\n", elapsed_time);
    }

    // Clean up allocated memory
    free(A);
    free(B);
    if (B_T)
        free(B_T);
    free(C);

    return 0;
}
