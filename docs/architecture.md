# System Architecture & Technical Diagrams

## 1. Multicore Shared-Memory Architecture

```mermaid
flowchart TD
    subgraph Sockets ["Multiprocessor System Interconnect"]
        subgraph Node0 ["NUMA Node 0 / Core Complex"]
            C0["Core 0\n(Thread 0)"] <--> L1_0["L1/L2 Cache\n(Private)"]
            C1["Core 1\n(Thread 1)"] <--> L1_1["L1/L2 Cache\n(Private)"]
            L1_0 <--> Bus0["Snooping Interconnect / Crossbar"]
            L1_1 <--> Bus0
            Bus0 <--> MC0["Integrated Memory Controller 0"]
            MC0 <--> Mem0[("Local Physical DRAM\n(Node 0)")]
        end

        subgraph Node1 ["NUMA Node 1 / Core Complex (Remote)"]
            C2["Core 2\n(Thread 2)"] <--> L1_2["L1/L2 Cache\n(Private)"]
            C3["Core 3\n(Thread 3)"] <--> L1_3["L1/L2 Cache\n(Private)"]
            L1_2 <--> Bus1["Snooping Interconnect / Crossbar"]
            L1_3 <--> Bus1
            Bus1 <--> MC1["Integrated Memory Controller 1"]
            MC1 <--> Mem1[("Remote Physical DRAM\n(Node 1)")]
        end

        Bus0 <== "High-Speed Inter-Socket Link (UPI / Infinity Fabric)" ==> Bus1
    end
```

---

## 2. Cache Coherence Protocol State Transition Diagrams

### 2.1 MSI Protocol State Machine
```mermaid
stateDiagram-v2
    [*] --> Invalid: Line Allocation
    Invalid --> Shared: PrRd / BusRd
    Invalid --> Modified: PrWr / BusRdX
    Shared --> Modified: PrWr / BusUpgr
    Shared --> Invalid: BusRdX
    Modified --> Shared: BusRd / Flush to Memory
    Modified --> Invalid: BusRdX / Flush to Memory
```

### 2.2 MESI Protocol State Machine
```mermaid
stateDiagram-v2
    [*] --> Invalid: Line Allocation
    Invalid --> Exclusive: PrRd (No other copies) / BusRd
    Invalid --> Shared: PrRd (Other copies exist) / BusRd
    Invalid --> Modified: PrWr / BusRdX
    Exclusive --> Modified: PrWr (Silent Transition, 0 Bus Tx)
    Exclusive --> Shared: BusRd
    Exclusive --> Invalid: BusRdX
    Shared --> Modified: PrWr / BusUpgr
    Shared --> Invalid: BusRdX
    Modified --> Shared: BusRd / Flush to Memory
    Modified --> Invalid: BusRdX / Flush to Memory
```

### 2.3 MOESI Protocol State Machine
```mermaid
stateDiagram-v2
    [*] --> Invalid: Line Allocation
    Invalid --> Exclusive: PrRd (No copies) / BusRd
    Invalid --> Shared: PrRd (Supplied by Memory or Owner)
    Invalid --> Modified: PrWr / BusRdX
    Exclusive --> Modified: PrWr (Silent, 0 Bus Tx)
    Modified --> Owned: BusRd / Cache-to-Cache Transfer (No Memory Flush)
    Owned --> Modified: PrWr / BusUpgr
    Owned --> Invalid: BusRdX / Cache-to-Cache Transfer
    Shared --> Modified: PrWr / BusUpgr
    Shared --> Invalid: BusRdX
```

---

## 3. Cache-Line Memory Layout: Adjacent vs. Padded

```mermaid
flowchart LR
    subgraph AdjacentLayout ["Adjacent Layout (False Sharing Active)"]
        direction TB
        CL1["64-Byte Cache Line A"]
        CL1 --- V0["Counter 0 (Core 0)\nOffset: 0B (8 bytes)"]
        CL1 --- V1["Counter 1 (Core 1)\nOffset: 8B (8 bytes)"]
        CL1 --- Rem["Unused Line Space\nOffsets: 16B - 63B"]
    end

    subgraph PaddedLayout ["Padded Layout (False Sharing Eliminated)"]
        direction TB
        CL_A["64-Byte Cache Line A\n(Core 0 Private)"] --- VP0["Counter 0 (Core 0)\nOffset: 0B (8 bytes)"]
        CL_A --- Pad0["Padding: 56 bytes"]
        CL_B["64-Byte Cache Line B\n(Core 1 Private)"] --- VP1["Counter 1 (Core 1)\nOffset: 0B (8 bytes)"]
        CL_B --- Pad1["Padding: 56 bytes"]
    end
```

---

## 4. NUMA Memory Placement and Access Latency

```mermaid
sequenceDiagram
    autonumber
    actor T0 as Thread 0 (Node 0)
    participant LMC as Local Memory Controller
    participant LDRAM as Local DRAM (Node 0)
    participant QPI as Cross-Socket Interconnect
    participant RDRAM as Remote DRAM (Node 1)

    Note over T0,LDRAM: Scenario A: Local Memory Access (Low Latency, High Bandwidth)
    T0->>LMC: Memory Request (Address on Node 0)
    LMC->>LDRAM: Read Request
    LDRAM-->>T0: Return Data (~60-80 ns)

    Note over T0,RDRAM: Scenario B: Remote Memory Access (Higher Latency via Interconnect)
    T0->>LMC: Memory Request (Address on Node 1)
    LMC->>QPI: Packetize across Interconnect Link
    QPI->>RDRAM: Inter-Socket Crossbar Routing
    RDRAM-->>QPI: Return Data Packet
    QPI-->>T0: Return Data (~120-160 ns)
```
