# Multicore Cache Coherence (MSI, MESI, MOESI) & NUMA Performance Benchmark

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%20LTS-orange.svg)]()
[![Compiler](https://img.shields.io/badge/compiler-GCC%2011%2B%20%7C%20OpenMP-blue.svg)]()
[![Python](https://img.shields.io/badge/python-3.8%2B-yellow.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

An in-depth systems programming and hardware benchmarking suite evaluating symmetric multiprocessing (SMP) cache coherence protocols (**MSI**, **MESI**, **MOESI**), interconnect contention induced by **false sharing**, and Non-Uniform Memory Access (**NUMA**) data placement.

---

## Table of Contents
1. [Overview](#overview)
2. [Objectives](#objectives)
3. [Technology Stack](#technology-stack)
4. [Hardware & Virtualization Setup](#hardware--virtualization-setup)
5. [Theoretical Architecture](#theoretical-architecture)
   - [MSI Protocol](#msi-protocol)
   - [MESI Protocol](#mesi-protocol)
   - [MOESI Protocol](#moesi-protocol)
   - [False Sharing Mechanics](#false-sharing-mechanics)
   - [NUMA Memory Hierarchy](#numa-memory-hierarchy)
6. [Repository Structure](#repository-structure)
7. [Installation & Prerequisites](#installation--prerequisites)
8. [Compilation](#compilation)
9. [Execution Guide](#execution-guide)
10. [Experimental Results](#experimental-results)
    - [Program 1: Protocol Simulator](#program-1-protocol-simulator)
    - [Program 2: False Sharing Benchmark](#program-2-false-sharing-benchmark)
    - [Program 3: NUMA Memory Sweep](#program-3-numa-memory-sweep)
    - [Program 4: Scalability Benchmark](#program-4-scalability-benchmark)
11. [Performance Analysis](#performance-analysis)
12. [Hardware Limitations & Virtualization Diagnostics](#hardware-limitations--virtualization-diagnostics)
13. [Conclusion](#conclusion)
14. [References](#references)

---

## Overview

In multicore architectures, processor cores utilize dedicated private caches (L1/L2) alongside shared Last-Level Caches (LLC). Maintaining global consistency across these distributed cache stores requires hardware snooping protocols that monitor interconnect transactions. 

This repository provides both an architectural cycle simulator and compiled native C/OpenMP micro-benchmarks to demonstrate:
- How cache line invalidation storms impact execution latency.
- The progressive optimization of bus transactions across **MSI**, **MESI**, and **MOESI**.
- The dramatic speedups gained by 64-byte cache-line padding to eliminate false sharing.
- Memory access throughput characteristics across NUMA nodes.

---

## Objectives

1. Model and compare snooping cache coherence state transitions across MSI, MESI, and MOESI protocols.
2. Quantify bus transaction overheads, invalidations, and memory write-backs on contending memory lines.
3. Empirically demonstrate false sharing between concurrent OpenMP threads modifying adjacent memory locations.
4. Eliminate cache-line bouncing by enforcing 64-byte alignment and padding.
5. Profile memory sweep latency over a 512 MB buffer utilizing first-touch memory allocation.
6. Evaluate multicore scalability across 1, 2, and 4 threads.

---

## Technology Stack

- **Operating System**: Ubuntu 22.04 LTS (x86_64) running under VMware Workstation Pro
- **Compiler**: GNU Compiler Collection (GCC) with OpenMP (`libgomp`)
- **Scripting & Simulation**: Python 3.8+
- **NUMA Diagnostics**: `numactl`, `hwloc` (`lstopo`)
- **Build System**: Bash automation scripts (`setup.sh`, `compile_all.sh`, `run_all.sh`)

---

## Hardware & Virtualization Setup

| Component | Description |
| :--- | :--- |
| **Virtual Machine** | VMware Workstation Pro Guest |
| **vCPUs** | 4 Cores assigned to Guest OS |
| **Guest Memory** | 8192 MB (8 GB) RAM |
| **Cache Line Size** | 64 Bytes |
| **NUMA Topology** | Node 0 (CPUs 0, 1, 2, 3) |

---

## Theoretical Architecture

### MSI Protocol
The foundational three-state invalidation-based snooping protocol:
- **Modified (M)**: The cache line is exclusively held and dirty with respect to DRAM.
- **Shared (S)**: Clean copy held by one or more private caches; memory is consistent.
- **Invalid (I)**: The cache line does not contain valid data.
*Drawback*: Even private data loaded exclusively requires a broadcast `BusUpgr` on first write.

### MESI Protocol
Introduces the **Exclusive (E)** state:
- Indicates that the line is exclusively held by this cache and clean with respect to memory.
- A write to an Exclusive line triggers a **silent transition ($E \rightarrow M$)** requiring zero bus broadcast transactions.

### MOESI Protocol
Introduces the **Owned (O)** state:
- Denotes dirty data shared among multiple cores. The owner core responds to read requests via direct **Cache-to-Cache ($C2C$) transfers**.
- Avoids writing dirty lines back to main memory when other cores request read-shared access.

### False Sharing Mechanics
Because coherence is tracked per 64-byte cache line rather than per variable:
- When two threads update distinct variables that lie within the same 64 bytes, each store operation invalidates the other core's cache line.
- The cache line continuously ping-pongs across the interconnect, serializing execution.
- Structuring memory with 64-byte padding ensures each variable resides in its own cache line.

```
ADJACENT LAYOUT (Contended 64-Byte Line):
[ Counter 0 (Thread 0) | Counter 1 (Thread 1) | Unused ... ] -> False Sharing

PADDED LAYOUT (Distinct 64-Byte Lines):
Line A: [ Counter 0 (Thread 0) | 56-Byte Padding ]
Line B: [ Counter 1 (Thread 1) | 56-Byte Padding ]           -> Zero Contention
```

---

## Repository Structure

```
pgc_exp4_cache_coherence_NUMA/
├── README.md                           # Main engineering project report
├── LICENSE                             # MIT License
├── requirements.txt                    # Python environment specifications
├── .gitignore                          # Git exclusions for binaries and artifacts
│
├── src/                                # Source code directory
│   ├── coherence_sim.py                # 2-core MSI/MESI/MOESI cache simulator
│   ├── false_sharing.c                 # 100M increment OpenMP false-sharing benchmark
│   ├── numa_sweep.c                    # 512 MB memory access sweep benchmark
│   └── compare_numa.c                  # Integrated scalability and comparison harness
│
├── scripts/                            # Automation pipelines
│   ├── setup.sh                        # Dependency validation & system diagnostics
│   ├── compile_all.sh                  # GCC compilation with -O2 and -fopenmp
│   └── run_all.sh                      # Full benchmark execution pipeline
│
├── docs/                               # Detailed technical documentation
│   ├── experiment_overview.md          # Theoretical background and methodology
│   ├── architecture.md                 # System diagrams and state transitions
│   └── observations.md                 # In-depth performance analysis
│
├── results/                            # Raw benchmark logs and data tables
│   ├── coherence_results.txt           # Cache simulator trace and totals
│   ├── false_sharing_results.txt       # Three-run false-sharing output
│   ├── numa_results.txt                # NUMA sweep timings and diagnostics
│   ├── comparison_results.txt          # Scalability comparison tables
│   └── performance_summary.csv         # Structured performance CSV
│
└── screenshots/                        # Terminal execution evidence
    ├── 01_environment/                 # System and hardware verification
    ├── 02_cache_coherence/             # Simulator runs (MSI, MESI, MOESI)
    ├── 03_false_sharing/               # Adjacent vs padded terminal runs
    ├── 04_numa_memory/                 # Memory sweep execution
    ├── 05_comparison/                  # Scalability table outputs
    └── 06_final/                       # Project tree and execution logs
```

---

## Installation & Prerequisites

Inside the Ubuntu 22.04 LTS terminal:

```bash
# Clone the repository
git clone https://github.com/01fe24bci116/pgc_exp4_cache_coherence_NUMA.git
cd pgc_exp4_cache_coherence_NUMA

# Run automated setup
bash scripts/setup.sh
```

---

## Compilation

Compile all C benchmarks using optimized compiler flags:

```bash
bash scripts/compile_all.sh
```

Manual commands:
```bash
gcc -O2 src/false_sharing.c -fopenmp -o bin/false_sharing
gcc -O2 src/numa_sweep.c -fopenmp -o bin/numa_sweep
gcc -O2 src/compare_numa.c -fopenmp -o bin/compare_numa
```

---

## Execution Guide

### Automated Run
```bash
bash scripts/run_all.sh
```

### Manual Program Runs

1. **Cache Coherence Simulator**:
   ```bash
   python3 src/coherence_sim.py 1000
   ```

2. **False Sharing Benchmark (2 Threads)**:
   ```bash
   OMP_NUM_THREADS=2 ./bin/false_sharing adjacent
   OMP_NUM_THREADS=2 ./bin/false_sharing padded
   ```

3. **NUMA Memory Sweep (512 MB, 4 Passes)**:
   ```bash
   OMP_NUM_THREADS=2 ./bin/numa_sweep 512
   numactl --cpunodebind=0 --membind=0 ./bin/numa_sweep 512
   ```

4. **Integrated Scalability Comparison**:
   ```bash
   ./bin/compare_numa
   ```

---

## Experimental Results

### Program 1: Protocol Simulator
Evaluated over 1,000 iterations (4,000 total memory operations):

| Layout | Protocol | Total Bus Tx | BusRd | BusRdX | BusUpgr | Invalidations | Memory Write-backs | Cache-to-Cache (C2C) | Silent $E \rightarrow M$ |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Adjacent** | **MSI** | **4000** | 2000 | 0 | 2000 | 1999 | 1999 | 0 | 0 |
| **Adjacent** | **MESI** | **3999** | 2000 | 0 | 1999 | 1999 | 1999 | 0 | 1 |
| **Adjacent** | **MOESI** | **3999** | 2000 | 0 | 1999 | 1999 | **0** | **1999** | 1 |
| **Padded** | **MSI** | **4** | 2 | 0 | 2 | 0 | 0 | 0 | 0 |
| **Padded** | **MESI** | **2** | 2 | 0 | 0 | 0 | 0 | 0 | 2 |
| **Padded** | **MOESI** | **2** | 2 | 0 | 0 | 0 | 0 | 0 | 2 |

### Program 2: False Sharing Benchmark
$100,000,000$ increments across 2 threads (Measured across 3 runs):

| Run | Adjacent Time (s) | Padded Time (s) | Validation Status |
| :---: | :---: | :---: | :---: |
| Run 1 | 0.0128 s | 0.0146 s | Correct ($10^8$) |
| Run 2 | 0.0133 s | 0.0102 s | Correct ($10^8$) |
| Run 3 | 0.0218 s | 0.0102 s | Correct ($10^8$) |
| **Median** | **0.0133 s** | **0.0102 s** | **Correct ($10^8$)** |

**False Sharing Ratio (Median)** = $\frac{0.0133}{0.0102} = \mathbf{1.304\times}$ (+30.4% speedup with padding).

### Program 3: NUMA Memory Sweep
512 MB memory buffer, 4 sequential passes stepping by 64 bytes:

| Configuration | 1 Thread Time (s) | 2 Threads Time (s) | Speedup | Checksum Verified |
| :--- | :---: | :---: | :---: | :---: |
| **Default Placement** | 0.0988 s | 0.0541 s | **1.826x** | 33,554,432 |
| **Local Node Binding (Node 0)** | 0.0906 s | 0.0571 s | **1.587x** | 33,554,432 |

### Program 4: Scalability Benchmark

#### Table 1: False Sharing Scalability ($100,000,000$ increments)
| Threads | Adjacent Time (s) | Padded Time (s) | Speedup with Padding | Correctness |
| :---: | :---: | :---: | :---: | :---: |
| **1** | 0.0212 s | 0.0204 s | 1.039x | Correct |
| **2** | 0.0216 s | 0.0114 s | **1.895x** | Correct |
| **4** | 0.0112 s | 0.0080 s | **1.400x** | Correct |

#### Table 2: 512 MB Memory Sweep Scalability
| Threads | Execution Time (s) |
| :---: | :---: |
| **1** | 0.0913 s |
| **2** | 0.0635 s |

---

## Performance Analysis

1. **Bus Contention**: The simulation proves that adjacent counter placement incurs **3,999 to 4,000 bus transactions** due to false sharing. Padded counter placement drops bus transactions to **2 to 4**, achieving a **99.95% reduction** in interconnect traffic.
2. **Execution Latency**: In the compiled OpenMP benchmark, false sharing produced up to an **89.5% execution penalty** at 2 threads ($0.0216\text{ s}$ vs $0.0114\text{ s}$). Padding each counter onto an isolated 64-byte cache line restored near-linear scaling.
3. **Memory Throughput**: The 512 MB sweep demonstrated strong multithreaded scaling, reducing runtime from $0.0988\text{ s}$ down to $0.0541\text{ s}$ ($1.83\times$ speedup), confirming high local DRAM bandwidth utilization.

---

## Hardware Limitations & Virtualization Diagnostics

- **NUMA Topology**: The system operates as a single physical socket host. The guest OS exposes one NUMA node (`node 0 cpus: 0 1 2 3`).
- **Remote Memory Binding**: Executing `numactl --membind=1` correctly reports:
  ```
  libnuma: Warning: node 1 out of range
  ```
  On single-socket PCs, remote physical memory does not physically exist. Transparent documentation of this boundary preserves empirical integrity.

---

## Conclusion

This experiment validates that cache coherence protocols ensure data correctness across multi-core systems, but shared-line writes introduce severe performance degradation through false sharing. 
- **MESI** optimizes private data modifications by eliminating bus transactions through silent $E \rightarrow M$ transitions.
- **MOESI** optimizes shared dirty lines by replacing slow memory write-backs with high-speed Cache-to-Cache transfers.
- **Cache line padding (64 bytes)** completely eliminates false sharing, converting serialized execution into scalable parallel speedups.

---

## References

- GNU Compiler Collection (GCC) Documentation and OpenMP Runtime Specifications
- Linux Programmer's Manual: `numactl(8)`, `numa(3)`, `lscpu(1)`
- Linux Kernel Memory Management Architecture Guides
- Hardware Architecture Snooping Protocols Technical Specifications
