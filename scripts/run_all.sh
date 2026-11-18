#!/usr/bin/env bash
# ==============================================================================
# run_all.sh - Automated Execution Pipeline for Experiment 4
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
BIN_DIR="$ROOT_DIR/bin"
RESULTS_DIR="$ROOT_DIR/results"

mkdir -p "$RESULTS_DIR"

echo "======================================================================"
echo "  Executing Experiment 4 Benchmark Suite"
echo "======================================================================"

# Ensure programs are compiled
if [ ! -f "$BIN_DIR/false_sharing" ] || [ ! -f "$BIN_DIR/numa_sweep" ] || [ ! -f "$BIN_DIR/compare_numa" ]; then
    echo "Binaries missing. Running compile_all.sh first..."
    bash "$SCRIPT_DIR/compile_all.sh"
fi

# 1. Cache Coherence Simulation
echo ""
echo "[Step 1/4] Running Cache Coherence Simulator (coherence_sim.py)..."
python3 "$SRC_DIR/coherence_sim.py" 1000 | tee "$RESULTS_DIR/coherence_results.txt"

# 2. False Sharing Benchmark
echo ""
echo "[Step 2/4] Running False Sharing Benchmark (false_sharing)..."
{
    echo "=== False Sharing Benchmark (100,000,000 increments) ==="
    echo "Configuration: 2 threads"
    echo ""
    echo "--- Adjacent Layout (False Sharing active) ---"
    for i in 1 2 3; do
        echo -n "Run $i: "
        OMP_NUM_THREADS=2 "$BIN_DIR/false_sharing" adjacent
    done
    echo ""
    echo "--- Padded Layout (64-byte aligned, False Sharing eliminated) ---"
    for i in 1 2 3; do
        echo -n "Run $i: "
        OMP_NUM_THREADS=2 "$BIN_DIR/false_sharing" padded
    done
} | tee "$RESULTS_DIR/false_sharing_results.txt"

# 3. NUMA Memory Access Benchmark
echo ""
echo "[Step 3/4] Running NUMA Memory Sweep (numa_sweep)..."
NUMA_NODES=$(numactl --hardware 2>/dev/null | grep "available:" | awk '{print $2}')
{
    echo "=== NUMA Memory Sweep Benchmark (512 MB, 4 passes) ==="
    echo "Detected NUMA nodes: ${NUMA_NODES:-1}"
    echo ""
    echo "--- Standard Execution (Default Placement) ---"
    OMP_NUM_THREADS=1 "$BIN_DIR/numa_sweep" 512
    OMP_NUM_THREADS=2 "$BIN_DIR/numa_sweep" 512

    if [ "$NUMA_NODES" -ge 2 ] 2>/dev/null; then
        echo ""
        echo "--- Local Node Binding (cpu=0, mem=0) ---"
        OMP_NUM_THREADS=1 numactl --cpunodebind=0 --membind=0 "$BIN_DIR/numa_sweep" 512
        OMP_NUM_THREADS=2 numactl --cpunodebind=0 --membind=0 "$BIN_DIR/numa_sweep" 512

        echo ""
        echo "--- Remote Node Binding (cpu=0, mem=1) ---"
        OMP_NUM_THREADS=1 numactl --cpunodebind=0 --membind=1 "$BIN_DIR/numa_sweep" 512
        OMP_NUM_THREADS=2 numactl --cpunodebind=0 --membind=1 "$BIN_DIR/numa_sweep" 512
    else
        echo ""
        echo "Note: Only 1 NUMA node is available on this system/VM."
        echo "Remote memory binding (--membind=1) is unsupported in single-node topologies."
        echo "Testing Local Binding on Node 0 only:"
        OMP_NUM_THREADS=1 numactl --cpunodebind=0 --membind=0 "$BIN_DIR/numa_sweep" 512 || true
        OMP_NUM_THREADS=2 numactl --cpunodebind=0 --membind=0 "$BIN_DIR/numa_sweep" 512 || true
    fi
} | tee "$RESULTS_DIR/numa_results.txt"

# 4. Scalability & Integrated Benchmark
echo ""
echo "[Step 4/4] Running Comprehensive Comparison Benchmark (compare_numa)..."
"$BIN_DIR/compare_numa" | tee "$RESULTS_DIR/comparison_results.txt"

echo ""
echo "======================================================================"
echo "  All experiments completed! Outputs saved to $RESULTS_DIR"
echo "======================================================================"
