/*
 * numa_sweep.c - Experiment 4: NUMA Memory Access Benchmark
 *
 * Allocates a configurable memory buffer (default 512 MB), initializes it
 * via first-touch policy, and performs 4 parallel memory sweep passes reading
 * one byte per 64-byte cache line. Used with numactl to measure local vs remote
 * memory access latency and bandwidth.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <omp.h>

int main(int argc, char **argv) {
    size_t mb = argc > 1 ? atol(argv[1]) : 512;
    if (mb == 0) mb = 512;
    size_t n = mb << 20;

    char *buf = (char *)malloc(n);
    if (!buf) {
        fprintf(stderr, "Error: Failed to allocate %zu MB memory buffer!\n", mb);
        return 1;
    }

    /* First-touch initialization: pages are placed on the NUMA node of the initializing thread */
    memset(buf, 1, n);

    long sum = 0;
    double t0 = omp_get_wtime();

    for (int pass = 0; pass < 4; pass++) {
        #pragma omp parallel for reduction(+:sum) schedule(static)
        for (size_t i = 0; i < n; i += 64) {  /* one read per 64-byte cache line */
            sum += buf[i];
        }
    }

    double t = omp_get_wtime() - t0;

    printf("buffer=%zu MB | threads=%d | sum=%ld | time=%.4f s\n",
           mb, omp_get_max_threads(), sum, t);

    free(buf);
    return 0;
}
