/*
 * compare_numa.c - Experiment 4: Scalability & Execution Time Benchmark
 *
 * Table 1: two-counter false sharing benchmark across 1, 2, and 4 threads
 *          comparing adjacent (stride=1) vs padded (stride=8) cache layouts.
 * Table 2: 512 MB memory sweep across 1 and 2 threads (evaluated with numactl
 *          under local and remote memory binding policies).
 *
 * Compile: gcc -O2 compare_numa.c -fopenmp -o compare_numa
 * Run    : ./compare_numa
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <omp.h>

#if defined(_WIN32)
#include <malloc.h>
#define ALIGNED_ALLOC(alignment, size) _aligned_malloc((size), (alignment))
#define ALIGNED_FREE(ptr) _aligned_free(ptr)
#else
#define ALIGNED_ALLOC(alignment, size) aligned_alloc((alignment), (size))
#define ALIGNED_FREE(ptr) free(ptr)
#endif

#define N 100000000L
#define MB 512UL

double run_counters(int nt, int stride, long *total) {
    size_t bytes = ((size_t)nt * stride * sizeof(long) + 63) / 64 * 64;
    if (bytes < 64) bytes = 64;

    long *cnt = (long *)ALIGNED_ALLOC(64, bytes);
    if (!cnt) {
        fprintf(stderr, "Error: Memory allocation failed in run_counters\n");
        exit(1);
    }

    memset(cnt, 0, bytes);
    omp_set_num_threads(nt);

    double t0 = omp_get_wtime();
    #pragma omp parallel num_threads(nt)
    {
        int tid = omp_get_thread_num();
        volatile long *p = &cnt[tid * stride];
        long iters = N / nt;
        for (long i = 0; i < iters; i++) {
            (*p)++;
        }
    }
    double t = omp_get_wtime() - t0;

    *total = 0;
    for (int i = 0; i < nt; i++) {
        *total += cnt[i * stride];
    }

    ALIGNED_FREE(cnt);
    return t;
}

double run_sweep(char *buf, size_t n, int nt) {
    long sum = 0;
    omp_set_num_threads(nt);
    double t0 = omp_get_wtime();

    for (int pass = 0; pass < 4; pass++) {
        #pragma omp parallel for reduction(+:sum) schedule(static)
        for (size_t i = 0; i < n; i += 64) {
            sum += buf[i];
        }
    }

    double t = omp_get_wtime() - t0;
    if (sum == 0) {
        printf("Warning: unexpected sum=0\n");
    }
    return t;
}

int main(void) {
    int tc[] = {1, 2, 4};

    printf("Table 1: false sharing (%ld increments in total)\n", N);
    printf("Layout   | Threads | Final Count | Correctness | Time (s)\n");
    printf("---------------------------------------------------------\n");
    for (int i = 0; i < 3; i++) {
        for (int s = 1; s <= 8; s *= 8) {
            long total = 0;
            double t = run_counters(tc[i], s, &total);
            printf("%-8s | %7d | %11ld | %-11s | %8.4f\n",
                   s == 1 ? "adjacent" : "padded",
                   tc[i], total, total == N ? "Correct" : "INCORRECT", t);
        }
        printf("---------------------------------------------------------\n");
    }

    size_t n = MB << 20;
    char *buf = (char *)malloc(n);
    if (!buf) {
        fprintf(stderr, "Error: Memory allocation failed for %lu MB sweep\n", MB);
        return 1;
    }

    /* First touch decides NUMA memory placement under current numactl policy */
    memset(buf, 1, n);

    printf("\nTable 2: memory sweep of %lu MB (4 passes)\n", MB);
    printf("Threads | Time (s)\n");
    printf("-------------------\n");
    for (int i = 0; i < 2; i++) {
        printf("%7d | %8.4f\n", tc[i], run_sweep(buf, n, tc[i]));
    }

    free(buf);
    return 0;
}
