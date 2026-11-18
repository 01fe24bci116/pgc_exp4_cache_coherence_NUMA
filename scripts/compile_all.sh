#!/usr/bin/env bash
# ==============================================================================
# compile_all.sh - Compilation Script for Experiment 4 C Programs
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
BIN_DIR="$ROOT_DIR/bin"

mkdir -p "$BIN_DIR"

echo "======================================================================"
echo "  Compiling Experiment 4 C Benchmarks (-O2 -fopenmp)"
echo "======================================================================"

echo ""
echo "[1/3] Compiling false_sharing.c..."
gcc -O2 "$SRC_DIR/false_sharing.c" -fopenmp -o "$BIN_DIR/false_sharing"
echo "  -> Successfully built: $BIN_DIR/false_sharing"

echo ""
echo "[2/3] Compiling numa_sweep.c..."
gcc -O2 "$SRC_DIR/numa_sweep.c" -fopenmp -o "$BIN_DIR/numa_sweep"
echo "  -> Successfully built: $BIN_DIR/numa_sweep"

echo ""
echo "[3/3] Compiling compare_numa.c..."
gcc -O2 "$SRC_DIR/compare_numa.c" -fopenmp -o "$BIN_DIR/compare_numa"
echo "  -> Successfully built: $BIN_DIR/compare_numa"

echo ""
echo "======================================================================"
echo "  All 3 C benchmark programs compiled successfully!"
echo "======================================================================"
