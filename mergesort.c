// mergesort.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <omp.h>

#define PAR_THRESHOLD 1000  // subarray size below which sequential sort is used in parallel mode

// Merge two sorted subarrays arr[left..mid] and arr[mid+1..right]
void merge(int *arr, int left, int mid, int right) {
    int n1 = mid - left + 1;
    int n2 = right - mid;
    int *L = (int *) malloc(n1 * sizeof(int));
    int *R = (int *) malloc(n2 * sizeof(int));
    if (!L || !R) {
        fprintf(stderr, "Error allocating memory in merge().\n");
        exit(1);
    }

    for (int i = 0; i < n1; i++)
        L[i] = arr[left + i];
    for (int j = 0; j < n2; j++)
        R[j] = arr[mid + 1 + j];

    int i = 0, j = 0, k = left;
    while (i < n1 && j < n2) {
        if (L[i] <= R[j])
            arr[k++] = L[i++];
        else
            arr[k++] = R[j++];
    }
    while (i < n1)
        arr[k++] = L[i++];
    while (j < n2)
        arr[k++] = R[j++];

    free(L);
    free(R);
}

// Sequential mergesort
void mergesort_seq(int *arr, int left, int right) {
    if (left < right) {
        int mid = left + (right - left) / 2;
        mergesort_seq(arr, left, mid);
        mergesort_seq(arr, mid + 1, right);
        merge(arr, left, mid, right);
    }
}

// Parallel mergesort using OpenMP tasks
void mergesort_par(int *arr, int left, int right, int threshold) {
    if (left < right) {
        // For small subarrays, use sequential mergesort to avoid task overhead.
        if ((right - left) < threshold) {
            mergesort_seq(arr, left, right);
        } else {
            int mid = left + (right - left) / 2;
            #pragma omp task shared(arr) firstprivate(left, mid, threshold)
            {
                mergesort_par(arr, left, mid, threshold);
            }
            #pragma omp task shared(arr) firstprivate(mid, right, threshold)
            {
                mergesort_par(arr, mid + 1, right, threshold);
            }
            #pragma omp taskwait
            merge(arr, left, mid, right);
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <array_size> <seq|par>\n", argv[0]);
        return 1;
    }

    int N = atoi(argv[1]);
    if (N <= 0) {
        fprintf(stderr, "Array size must be a positive integer.\n");
        return 1;
    }

    char *mode = argv[2];
    int useParallel = 0;
    if (strcmp(mode, "seq") == 0) {
        useParallel = 0;
    } else if (strcmp(mode, "par") == 0) {
        useParallel = 1;
    } else {
        fprintf(stderr, "Second argument must be 'seq' or 'par'\n");
        return 1;
    }

    // Allocate and initialize the array with random integers.
    int *array = (int *) malloc(N * sizeof(int));
    if (!array) {
        fprintf(stderr, "Error allocating memory for array.\n");
        return 1;
    }
    // For reproducibility, we use a fixed seed.
    srand(42);
    for (int i = 0; i < N; i++) {
        array[i] = rand();
    }

    double start_time, end_time, elapsed_time;
    start_time = omp_get_wtime();

    if (!useParallel) {
        // Sequential mergesort.
        mergesort_seq(array, 0, N - 1);
    } else {
        // Parallel mergesort: start a parallel region with a single initial task.
        #pragma omp parallel
        {
            #pragma omp single nowait
            {
                mergesort_par(array, 0, N - 1, PAR_THRESHOLD);
            }
        }
    }

    end_time = omp_get_wtime();
    elapsed_time = end_time - start_time;

    // Print timing result.
    if (!useParallel)
        printf("Sequential: %.6f\n", elapsed_time);
    else
        printf("Parallel: %.6f\n", elapsed_time);

    free(array);
    return 0;
}
