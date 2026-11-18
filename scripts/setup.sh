#!/usr/bin/env bash
# ==============================================================================
# setup.sh - Environment Verification & Dependency Setup
# Experiment 4: Cache Coherence (MSI, MESI, MOESI) & NUMA Performance
# ==============================================================================

set -e

echo "======================================================================"
echo "  Experiment 4: Environment Verification & Dependency Setup"
echo "======================================================================"

echo ""
echo "[1/5] Checking Kernel and Operating System..."
uname -a
if command -v lsb_release &> /dev/null; then
    lsb_release -a
fi

echo ""
echo "[2/5] Checking Required Packages..."
MISSING_PKGS=""
for pkg in gcc python3 numactl lstopo git; do
    if ! command -v "$pkg" &> /dev/null; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "Missing dependencies detected:$MISSING_PKGS"
    echo "Attempting installation via apt..."
    sudo apt update
    sudo apt install -y build-essential gcc python3 numactl hwloc git
else
    echo "All core binaries (gcc, python3, numactl, hwloc, git) are available."
fi

echo ""
echo "[3/5] Verifying GCC & OpenMP Support..."
gcc --version | head -n 1
if echo '#include <omp.h>' | gcc -E -fopenmp -xc - > /dev/null 2>&1; then
    echo "OpenMP support: OK (libgomp active)"
else
    echo "Error: OpenMP header <omp.h> could not be preprocessed with -fopenmp."
    exit 1
fi

echo ""
echo "[4/5] Checking Python 3..."
python3 --version

echo ""
echo "[5/5] Checking CPU Architecture & NUMA Topology..."
lscpu | grep -E "Model name|Socket|Thread|NUMA|CPU\(s\):" || true
echo ""
echo "NUMA Hardware Topology (numactl --hardware):"
numactl --hardware || echo "Warning: numactl query failed or single node system."

echo ""
echo "NUMA CPU List (lscpu -e):"
lscpu -e || true

echo ""
echo "System Memory Status:"
free -h

echo ""
echo "Disk Space Status:"
df -h .

echo ""
echo "======================================================================"
echo "  Setup Verification Complete! Ready to compile and execute benchmarks."
echo "======================================================================"
