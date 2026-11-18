/*
 * false_sharing.c - Experiment 4: Adjacent vs Padded Cache Layout Benchmark
 *
 * Demonstrates the cache-line bouncing effect (false sharing) when multiple
 * threads update independent variables located on the same 64-byte cache line
 * compared to when each counter is padded onto its own private cache line.
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

int main(int argc, char **argv) {
    /* stride = 1 for adjacent (false sharing); stride = 8 for padded (8 * 8 bytes = 64 bytes) */
    int stride = (argc > 1 && argv[1][0] == 'p') ? 8 : 1;
    int nt = omp_get_max_threads();
    
    /* Ensure allocation size is a multiple of cache line size (64 bytes) */
    size_t bytes = ((size_t)nt * stride * sizeof(long) + 63) / 64 * 64;
    if (bytes < 64) bytes = 64;

    long *cnt = (long *)ALIGNED_ALLOC(64, bytes);
    if (!cnt) {
        fprintf(stderr, "Error: Memory allocation failed!\n");
        return 1;
    }

    memset(cnt, 0, bytes);

    double t0 = omp_get_wtime();
    #pragma omp parallel
    {
        int tid = omp_get_thread_num();
        volatile long *p = &cnt[tid * stride];
        long iters = N / nt;
        for (long i = 0; i < iters; i++) {
            (*p)++;  /* read-modify-write own counter */
        }
    }
    double t = omp_get_wtime() - t0;

    long total = 0;
    for (int i = 0; i < nt; i++) {
        total += cnt[i * stride];
    }

    printf("%s | threads=%d | total=%ld | time=%.4f s | %s\n",
           stride == 1 ? "adjacent" : "padded  ", 
           nt, total, t, 
           total == N ? "Correct" : "INCORRECT");

    ALIGNED_FREE(cnt);
    return 0;
}
