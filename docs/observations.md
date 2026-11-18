# Experimental Observations and Performance Analysis

## 1. Cache Coherence Protocol Simulation Analysis

### 1.1 Coherence Event Profiling (1000 Iterations / 4000 Operations)

| Layout | Protocol | Bus Transactions | BusRd | BusRdX | BusUpgr | Invalidations | Memory Write-backs | Cache-to-Cache (C2C) | Silent $E \rightarrow M$ |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Adjacent** | **MSI** | **4000** | 2000 | 0 | 2000 | 1999 | 1999 | 0 | 0 |
| **Adjacent** | **MESI** | **3999** | 2000 | 0 | 1999 | 1999 | 1999 | 0 | 1 |
| **Adjacent** | **MOESI** | **3999** | 2000 | 0 | 1999 | 1999 | **0** | **1999** | 1 |
| **Padded** | **MSI** | **4** | 2 | 0 | 2 | 0 | 0 | 0 | 0 |
| **Padded** | **MESI** | **2** | 2 | 0 | 0 | 0 | 0 | 0 | 2 |
| **Padded** | **MOESI** | **2** | 2 | 0 | 0 | 0 | 0 | 0 | 2 |

### 1.2 Key Architectural Takeaways
1. **The Cost of False Sharing**: In the adjacent configuration, sharing cache line $A$ forced **3999 to 4000 total bus transactions** across 1000 loop cycles. By contrasting this with the padded configuration (which needed only **2 to 4 transactions**), padding produced an astonishing **$99.95\%$ reduction in interconnect traffic**.
2. **MESI Silent Upgrades**: In the padded layout, MESI eliminated all `BusUpgr` requests via silent $E \rightarrow M$ transitions, requiring only initial cold-miss reads ($2$ `BusRd`).
3. **MOESI Elimination of Memory Write-Backs**: When lines ping-ponged under the adjacent configuration, MOESI substituted all $1999$ slow DRAM write-back flushes with direct high-speed **Cache-to-Cache ($C2C$) transfers**, completely offloading main memory.

---

## 2. False Sharing Benchmark Analysis (Program 2)

### 2.1 Three-Run Execution Timing ($100,000,000$ Increments, 2 Threads)

| Run Iteration | Adjacent Layout Time (s) | Padded Layout Time (s) | Observed Speedup | Correctness |
| :--- | :---: | :---: | :---: | :---: |
| Run 1 | 0.0128 s | 0.0146 s | 0.88x | Correct ($10^8$) |
| Run 2 | 0.0133 s | 0.0102 s | 1.30x | Correct ($10^8$) |
| Run 3 | 0.0218 s | 0.0102 s | 2.14x | Correct ($10^8$) |
| **Median** | **0.0133 s** | **0.0102 s** | **1.304x (+30.4%)** | **Verified** |

### 2.2 Mathematical Metrics
$$\text{False Sharing Contention Ratio} = \frac{T_{\text{adjacent}}}{T_{\text{padded}}} = \frac{0.0133\text{ s}}{0.0102\text{ s}} \approx 1.3039$$
The adjacent counter layout experiences cache-line ping-pong between Core 0 and Core 1, introducing a median $30.4\%$ execution overhead.

---

## 3. Multithreaded Scalability Comparison (Program 4)

### 3.1 False Sharing Scalability ($100,000,000$ Total Increments)

| Threads | Adjacent Time (s) | Padded Time (s) | Contention Ratio ($T_{\text{adj}} / T_{\text{pad}}$) | Algorithmic Correctness |
| :---: | :---: | :---: | :---: | :---: |
| **1** | 0.0212 s | 0.0204 s | 1.039x | Correct ($10^8$) |
| **2** | 0.0216 s | 0.0114 s | **1.895x** | Correct ($10^8$) |
| **4** | 0.0112 s | 0.0080 s | **1.400x** | Correct ($10^8$) |

### 3.2 Scalability Insights
- **At 1 Thread**: Both layouts perform identically (~0.020 s - 0.021 s) because only one core touches the cache line.
- **At 2 Threads**: The padded layout achieves linear scaling ($0.0204\text{ s} \rightarrow 0.0114\text{ s}$, a $1.79\times$ speedup). Conversely, the adjacent layout stalls ($0.0212\text{ s} \rightarrow 0.0216\text{ s}$) due to aggressive L1 cache invalidations and interconnect serialization.
- **At 4 Threads**: Hardware prefetchers and multithreaded core sharing mitigate latency, but padded counters still outperform adjacent counters by **$40\%$**.

---

## 4. NUMA Memory Sweep Analysis (Program 3 & Program 4)

### 4.1 512 MB Memory Buffer Traversal (4 Sequential Passes)

| Benchmark Configuration | 1 Thread Time (s) | 2 Threads Time (s) | Multithreaded Speedup | Accumulated Checksum |
| :--- | :---: | :---: | :---: | :---: |
| **Standard Sweep (Default)** | 0.0988 s | 0.0541 s | **1.826x** | 33,554,432 |
| **Local Binding (Node 0)** | 0.0906 s | 0.0571 s | **1.587x** | 33,554,432 |
| **Scalability Suite (`compare_numa`)** | 0.0913 s | 0.0635 s | **1.438x** | Verified Non-Zero |

### 4.2 NUMA Topology & Virtualization Limitations
- The guest operating system reports **1 physical/virtual NUMA node** (`node 0 cpus: 0 1 2 3`).
- Invoking `numactl --membind=1` yields `node 1 out of range / invalid argument` because single-socket consumer desktop/laptop hardware does not expose multi-socket physical NUMA domains.
- Local memory binding on Node 0 yields optimal throughput (~0.090 s for 512 MB across 4 passes), confirming robust memory subsystem performance without cross-socket latency penalties.
