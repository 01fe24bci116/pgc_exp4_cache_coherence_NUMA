# Experiment Overview: Cache Coherence and NUMA Memory Architecture

## 1. Abstract & Objectives
This research experiment investigates the low-level hardware coordination protocols and memory access characteristics governing symmetric multiprocessing (SMP) and non-uniform memory access (NUMA) systems. The study is bifurcated into two core domains:
1. **Cache Coherence Protocols**: Quantitative simulation and comparison of snooping-based coherence models including **MSI**, **MESI**, and **MOESI**.
2. **Memory Hierarchy & Layout Effects**: Empirical profiling of multicore cache-line contention (**false sharing**) and memory placement policies using compiled OpenMP implementations executed under Linux.

---

## 2. Theoretical Foundations

### 2.1 The Snooping Cache Coherence Problem
In modern multicore processors, each processor core incorporates private, high-speed L1/L2 caches to buffer frequently accessed data. When distinct cores operate on overlapping cache lines, concurrent reads and writes can lead to data inconsistency. A snooping protocol enforces global cache coherence by requiring all private caches to monitor a shared broadcast bus or ring interconnect.

### 2.2 Protocol Comparison: MSI vs. MESI vs. MOESI

| Feature | MSI Protocol | MESI Protocol | MOESI Protocol |
| :--- | :--- | :--- | :--- |
| **Supported States** | Modified (M), Shared (S), Invalid (I) | Modified (M), Exclusive (E), Shared (S), Invalid (I) | Modified (M), Owned (O), Exclusive (E), Shared (S), Invalid (I) |
| **Private Clean Line** | Stored as Shared ($S$) | Stored as Exclusive ($E$) | Stored as Exclusive ($E$) |
| **First Write to Private Line** | Requires `BusUpgr` transaction | Silent $E \rightarrow M$ transition (Zero bus traffic) | Silent $E \rightarrow M$ transition (Zero bus traffic) |
| **Remote Read to Dirty Line** | Flush dirty line to main memory; downgrade $M \rightarrow S$ | Flush dirty line to main memory; downgrade $M \rightarrow S$ | Owner downgrades $M \rightarrow O$; transfers directly via Cache-to-Cache ($C2C$) |
| **Memory Write-Back on Read** | Mandatory | Mandatory | Completely eliminated |

### 2.3 False Sharing Mechanisms
Cache coherence operates with cache-line granularity (typically 64 bytes) rather than individual variable granularity. When two threads concurrently write to independent variables mapped to the same 64-byte block:
- Every write by Thread 0 invalidates the entire cache line held by Core 1.
- Core 1 suffers an invalidation miss, necessitating a bus read/upgrade to regain ownership.
- The cache line continuously bounces across the interconnect (the "cache ping-pong" phenomenon).
- While algorithmic correctness is maintained, execution throughput degrades substantially.

Aligning and padding thread-private counters with $64$ bytes separates the data across isolated cache lines, permanently eliminating invalidation storm overhead.

---

## 3. Workload and Methodology

### Program 1: `coherence_sim.py`
Simulates a two-core private cache environment executing an alternating read-modify-write sequence across two counters ($x$ and $y$):
- **Adjacent Configuration**: Variables $x$ and $y$ share Cache Line $A$.
- **Padded Configuration**: Variable $x$ resides on Line $A$, while Variable $y$ resides on Line $B$.

### Program 2: `false_sharing.c`
Executes an OpenMP multithreaded loop executing $100,000,000$ iterations distributed equally across 2 threads. Each thread increments its allocated counter using pointer arithmetic with either:
- Stride of $1$ `long` ($8$ bytes) $\rightarrow$ adjacent false-sharing contention.
- Stride of $8$ `longs` ($64$ bytes) $\rightarrow$ padded cache-line isolation.

### Program 3: `numa_sweep.c`
Evaluates memory bandwidth and page placement across a configurable memory buffer ($512$ MB). Pages are initialized via first-touch semantics. Four sequential passes traverse the buffer with a 64-byte step, reading one byte per cache line and aggregating values with an OpenMP parallel reduction.

### Program 4: `compare_numa.c`
Integrates false-sharing evaluation across 1, 2, and 4 threads alongside 1-thread and 2-thread 512 MB memory sweep benchmarks into a unified diagnostic report.
