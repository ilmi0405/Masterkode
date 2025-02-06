/******************************************************************************
 * File: matrix_mul_ext.c
 *
 * Description:
 *   Compares different approaches to matrix multiplication:
 *     1) Normal multiplication (A * B) using flat memory layout
 *     2) Multiplication with B transposed (A * B^T)
 *   Both are done in sequential and parallel modes.
 *   The code reports times and checks correctness.
 *
 *****************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <math.h>   // for fabs if you want approximate comparisons


// Optional: To compare floating-point results with a small tolerance
static int double_equals(double a, double b, double epsilon) {
    return fabs(a - b) < epsilon;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <N>\n", argv[0]);
        return 1;
    }

    int N = atoi(argv[1]);
    if (N <= 0) {
        fprintf(stderr, "N must be a positive integer.\n");
        return 1;
    }

    // Allocate flat memory for matrices (A, B, B_T)
    double *A       = (double *) malloc(N*N * sizeof(double));
    double *B       = (double *) malloc(N*N * sizeof(double));
    double *B_T     = (double *) malloc(N*N * sizeof(double)); // for B transposed

    // Allocate memory for results:
    //   C_seq_flat  : sequential normal multiplication
    //   C_par_flat  : parallel   normal multiplication
    //   C_seq_trans : sequential multiplication with B transposed
    //   C_par_trans : parallel   multiplication with B transposed
    double *C_seq_flat  = (double *) calloc(N*N, sizeof(double));
    double *C_par_flat  = (double *) calloc(N*N, sizeof(double));
    double *C_seq_trans = (double *) calloc(N*N, sizeof(double));
    double *C_par_trans = (double *) calloc(N*N, sizeof(double));

    if (!A || !B || !B_T || !C_seq_flat || !C_par_flat || !C_seq_trans || !C_par_trans) {
        fprintf(stderr, "Error allocating memory.\n");
        return 1;
    }

    // Initialize matrices A and B
    // For demonstration, we fill them deterministically
    // (You could also fill them randomly or read from file)
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            A[i*N + j] = i + j;    // example initialization
            B[i*N + j] = i - j;    // example initialization
        }
    }

    // Precompute the transpose of B in B_T
    //   B_T[i*N + j] = B[j*N + i]
    // so that B_T's (i, j) corresponds to B's (j, i)
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            B_T[i*N + j] = B[j*N + i];
        }
    }

    /*======================================================================
     * 1) NORMAL (FLAT) MULTIPLICATION: SEQUENTIAL
     *    C_seq_flat = A * B
     *====================================================================*/
    double start_seq_flat = omp_get_wtime();
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            double sum = 0.0;
            for (int k = 0; k < N; k++) {
                sum += A[i*N + k] * B[k*N + j];
            }
            C_seq_flat[i*N + j] = sum;
        }
    }
    double end_seq_flat = omp_get_wtime();
    double seq_flat_time = end_seq_flat - start_seq_flat;

    /*======================================================================
     * 2) NORMAL (FLAT) MULTIPLICATION: PARALLEL
     *    C_par_flat = A * B
     *====================================================================*/
    // Use all threads available
    omp_set_num_threads(omp_get_max_threads());

    double start_par_flat = omp_get_wtime();
    #pragma omp parallel for
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            double sum = 0.0;
            for (int k = 0; k < N; k++) {
                sum += A[i*N + k] * B[k*N + j];
            }
            C_par_flat[i*N + j] = sum;
        }
    }
    double end_par_flat = omp_get_wtime();
    double par_flat_time = end_par_flat - start_par_flat;

    /*======================================================================
     * 3) TRANSPOSED MULTIPLICATION: SEQUENTIAL
     *    C_seq_trans = A * B^T
     *
     *    i.e. C[i,j] = sum over k of A[i,k] * B^T[j,k]
     *                 = sum over k of A[i,k] * B[k,j]
     *    (We already stored B^T in B_T)
     *====================================================================*/
    double start_seq_trans = omp_get_wtime();
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            double sum = 0.0;
            for (int k = 0; k < N; k++) {
                // B^T[j*N + k] corresponds to B[k*N + j]
                sum += A[i*N + k] * B_T[j*N + k];
            }
            C_seq_trans[i*N + j] = sum;
        }
    }
    double end_seq_trans = omp_get_wtime();
    double seq_trans_time = end_seq_trans - start_seq_trans;

    /*======================================================================
     * 4) TRANSPOSED MULTIPLICATION: PARALLEL
     *    C_par_trans = A * B^T
     *====================================================================*/
    double start_par_trans = omp_get_wtime();
    #pragma omp parallel for
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            double sum = 0.0;
            for (int k = 0; k < N; k++) {
                sum += A[i*N + k] * B_T[j*N + k];
            }
            C_par_trans[i*N + j] = sum;
        }
    }
    double end_par_trans = omp_get_wtime();
    double par_trans_time = end_par_trans - start_par_trans;

    /*----------------------------------------------------------------------
     * Check correctness
     *   We’ll compare everything to C_seq_flat (our “reference”).
     *   If you prefer approximate checks, uncomment the double_equals() calls.
     *---------------------------------------------------------------------*/
    int all_match_seq_trans = 1;
    int all_match_par_flat  = 1;
    int all_match_par_trans = 1;

    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            double ref = C_seq_flat[i*N + j];
            // Compare with sequential trans
            if (C_seq_trans[i*N + j] != ref) {
            // if (!double_equals(C_seq_trans[i*N + j], ref, 1e-9)) {
                all_match_seq_trans = 0;
            }
            // Compare with parallel flat
            if (C_par_flat[i*N + j] != ref) {
            // if (!double_equals(C_par_flat[i*N + j], ref, 1e-9)) {
                all_match_par_flat = 0;
            }
            // Compare with parallel trans
            if (C_par_trans[i*N + j] != ref) {
            // if (!double_equals(C_par_trans[i*N + j], ref, 1e-9)) {
                all_match_par_trans = 0;
            }
        }
    }

    printf("\n=== CORRECTNESS CHECKS ===\n");
    if (all_match_seq_trans) {
        printf("Sequential-transposed   matches the sequential-flat results.\n");
    } else {
        printf("Sequential-transposed   differs from the sequential-flat results!\n");
    }
    if (all_match_par_flat) {
        printf("Parallel-flat           matches the sequential-flat results.\n");
    } else {
        printf("Parallel-flat           differs from the sequential-flat results!\n");
    }
    if (all_match_par_trans) {
        printf("Parallel-transposed     matches the sequential-flat results.\n");
    } else {
        printf("Parallel-transposed     differs from the sequential-flat results!\n");
    }

    /*----------------------------------------------------------------------
     * Print timing results
     *---------------------------------------------------------------------*/
    printf("\n=== TIMING (seconds) ===\n");
    printf("Sequential flat:        %.6f\n", seq_flat_time);
    printf("Parallel   flat:        %.6f\n", par_flat_time);
    printf("Sequential transposed:  %.6f\n", seq_trans_time);
    printf("Parallel   transposed:  %.6f\n", par_trans_time);

    /*----------------------------------------------------------------------
     * Clean up
     *---------------------------------------------------------------------*/
    free(A);
    free(B);
    free(B_T);
    free(C_seq_flat);
    free(C_par_flat);
    free(C_seq_trans);
    free(C_par_trans);

    return 0;
}
