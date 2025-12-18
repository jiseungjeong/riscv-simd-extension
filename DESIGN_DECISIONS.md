# Wide Vector Extension Design Decisions

Based on README.md Section 4.5: Design Decisions to Document

---

## 1. VLEN Choice: 64-bit

### Decision
**VLEN = 64-bit** (not 128-bit)

### Rationale

| Factor | 64-bit | 128-bit |
|--------|--------|---------|
| Register file area | 32 × 64 = 2,048 bits | 32 × 128 = 4,096 bits |
| Memory bus cycles | 2 cycles (32-bit bus) | 4 cycles (32-bit bus) |
| ALU complexity | 8 lanes (8-bit SEW) | 16 lanes (8-bit SEW) |
| Implementation effort | Moderate | High |

### Justification
1. **2× improvement over Lab 7**: 64-bit provides 8 lanes vs Lab 7's 4 lanes (32-bit)
2. **Existing memory bus compatibility**: 32-bit bus requires only 2 cycles for 64-bit vector
3. **Balanced complexity**: Sufficient performance gain without excessive hardware cost
4. **MNIST workload fit**: 784 inputs ÷ 8 lanes = 98 iterations (good granularity)

---

## 2. Element Width Flexibility: Configurable SEW (8/16/32-bit)

### Decision
**Support multiple SEW values**: 8-bit, 16-bit, and 32-bit elements

### Encoding
```
funct7[6:5] = SEW encoding
  00 = 8-bit  (8 lanes for VLEN=64)
  01 = 16-bit (4 lanes for VLEN=64)
  10 = 32-bit (2 lanes for VLEN=64)
  11 = Reserved
```

### Rationale

| SEW | Lanes | Use Case |
|-----|-------|----------|
| 8-bit | 8 | INT8 quantized ML, image processing |
| 16-bit | 4 | INT16 audio, fixed-point DSP |
| 32-bit | 2 | INT32 general computation |

### Mux Complexity
- **Input muxes**: 3-way selection per lane boundary
- **Output muxes**: Lane result routing to destination
- **Trade-off**: ~15% area increase vs fixed SEW, but 3× workload flexibility

---

## 3. Register File Organization

### Decision
- **Separate vector register file** (v0-v31) from scalar (x0-x31)
- **2 read ports** (64-bit each) for vs1, vs2
- **1 write port** (64-bit) for vd
- **No banking** (simple implementation)

### Architecture
```
┌─────────────────────────────────────┐
│       Vector Register File          │
│         32 × 64-bit                 │
├─────────────────────────────────────┤
│  Read Port 1 ──────► vs1 (64-bit)   │
│  Read Port 2 ──────► vs2 (64-bit)   │
│  Write Port ◄────── vd  (64-bit)    │
└─────────────────────────────────────┘
```

### Rationale
1. **Separate file**: Avoids scalar register file modification, cleaner integration
2. **2 read ports**: Required for binary operations (VADD, VMUL, etc.)
3. **1 write port**: Single-issue pipeline, one result per cycle
4. **No banking**: Simpler design, sufficient for single-issue core

### Alternative Considered
- **Unified register file**: Would allow scalar↔vector aliasing but requires wider ports and complex hazard detection

---

## 4. Multiply Implementation

### Decision
- **Multi-cycle VMAC** with **4 multipliers** (fair comparison across SEW values)
- **Parallel multipliers** (4 multiplies per cycle)
- **Result truncation**: Product truncated to element width

### Implementation Details (4 Multipliers - Fair Comparison)

| Instruction | Lanes | Multiplies | Mul Cycles (4/cycle) | Sum Cycle | **Total** |
|-------------|-------|------------|----------------------|-----------|-----------|
| ~~PVMAC (1 mul)~~ | 4 | 4 | 4/1 = 4 | 1 | ~~5 cycles~~ |
| PVMAC (4 mul) | 4 | 4 | 4/4 = 1 | 1 | **2 cycles** |
| VMAC.B | 8 | 8 | 8/4 = 2 | 1 | **3 cycles** |
| VMAC.H | 4 | 4 | 4/4 = 1 | 1 | **2 cycles** |
| VMAC.W | 2 | 2 | 2/4 = 1 | 1 | **2 cycles** |

### Throughput Comparison (4 Multipliers)

| Instruction | Lanes | Latency | MACs/cycle |
|-------------|-------|---------|------------|
| VMAC.B | 8 | 3 cycles | 8/3 = **2.67** |
| PVMAC (4 mul) | 4 | 2 cycles | 4/2 = **2.00** |
| VMAC.H | 4 | 2 cycles | 4/2 = **2.00** |
| VMAC.W | 2 | 2 cycles | 2/2 = **1.00** |

### Rationale
1. **Fair comparison**: All Wide VMAC use 4 multipliers (consistent hardware cost)
2. **Resource efficiency**: 4 multipliers provide good balance of area vs performance
3. **Stall logic reuse**: Extends Lab 5/7 multi-cycle operation handling
4. **Predictable timing**: Clear latency for pipeline scheduling

### Execution Timeline (VMAC.B with 4 multipliers, 3 cycles)
```
Cycle 0: prod[0:3] = a[0:3] * b[0:3]  (4 parallel multiplies)
Cycle 1: prod[4:7] = a[4:7] * b[4:7]  (4 parallel multiplies)
Cycle 2: result = sum(prod[0:7])       (adder tree)
```

---

## 5. Memory Interface

### Decision
- **Keep 32-bit memory bus** (no widening)
- **Multi-cycle transfers**: 2 cycles for 64-bit vector load/store
- **Aligned access required**: Base address must be 8-byte aligned

### Transfer Sequence
```
VLD v1, (a0):
  Cycle 1: Load mem[a0+0:3] → v1[31:0]
  Cycle 2: Load mem[a0+4:7] → v1[63:32]

VST v1, (a0):
  Cycle 1: Store v1[31:0] → mem[a0+0:3]
  Cycle 2: Store v1[63:32] → mem[a0+4:7]
```

### Rationale

| Approach | Pros | Cons |
|----------|------|------|
| **Multi-cycle (chosen)** | No memory interface change, simpler integration | 2× latency per vector |
| Widen bus to 64-bit | Single-cycle transfer | Major infrastructure change |

### Justification
1. **Minimal change**: Reuses existing Lab 3 load/store unit
2. **Acceptable overhead**: 2 cycles still faster than 8 scalar loads
3. **Alignment simplification**: No complex byte-lane logic needed

---

## 6. Instruction Encoding

### Decision
- **Reuse custom opcode 0x5B** (same as Lab 7)
- **New funct3=010** for vector operations (Lab 7 used funct3=001)
- **funct7 encodes operation and SEW**

### Encoding Format (R-type)
```
31       25  24  20  19  15  14  12  11   7  6    0
+----------+------+------+-------+------+--------+
|  funct7  |  vs2 |  vs1 | funct3|  vd  | opcode |
+----------+------+------+-------+------+--------+
   7 bits   5 bits 5 bits 3 bits  5 bits  7 bits

opcode = 0x5B (custom-1)
funct3 = 010 (vector operations)
funct7[6:5] = SEW (00=8, 01=16, 10=32)
funct7[4:0] = Operation code
```

### Operation Codes

| funct7[4:0] | Operation | Description |
|-------------|-----------|-------------|
| 00000 | VADD | Vector add |
| 00001 | VSUB | Vector subtract |
| 00010 | VMUL | Vector multiply |
| 00011 | VMAC | Vector multiply-accumulate |
| 00100 | VLD | Vector load |
| 00101 | VST | Vector store |

### Rationale
1. **Opcode reuse**: Stays within custom instruction space
2. **funct3 separation**: Distinguishes from Lab 7 packed operations
3. **SEW in funct7**: Allows static decode, no dynamic configuration
4. **5-bit operation**: Room for 32 operations per SEW

---

## 7. Pack/Unpack Granularity

### Decision
- **Full-width VLD/VST only** (no lane-by-lane transfers)
- **Scalar↔Vector via memory** (no direct VMOV instruction)
- **Implicit packing**: VLD reads consecutive bytes as vector elements

### Data Movement Options

| Method | Implementation | Use Case |
|--------|----------------|----------|
| **VLD/VST (chosen)** | Memory-based | Bulk data movement |
| VMOV.S2V | Direct register | Single element insert |
| VMOV.V2S | Direct register | Single element extract |

### Rationale
1. **Simplified design**: No lane-select muxes for partial writes
2. **MNIST workload**: Data naturally aligned in memory (contiguous pixels)
3. **Memory-centric**: Fits typical vectorization pattern (load → compute → store)

### Trade-off
- **Pro**: Simpler hardware, fewer instructions to implement
- **Con**: Scalar↔vector requires memory round-trip (could add VMOV later)

---

## Summary Table

| Design Decision | Choice | Key Rationale |
|-----------------|--------|---------------|
| VLEN | 64-bit | 2× Lab 7, fits 32-bit bus |
| SEW | Configurable (8/16/32) | Workload flexibility |
| Register file | Separate, 2R/1W | Clean integration |
| Multiply | Single-cycle VMAC | Low latency for ML |
| Memory interface | Multi-cycle (2×32-bit) | Minimal change |
| Instruction encoding | funct7 = SEW + op | Static decode |
| Pack/unpack | Full-width VLD/VST | Simple, memory-centric |

---

## Performance Impact Summary

| Decision | Cycles Saved | Area Cost |
|----------|--------------|-----------|
| VLEN=64 (8 lanes) | 50% fewer iterations | 2× register file |
| Configurable SEW | Optimal for data type | 15% mux overhead |
| Multi-cycle VMAC | Lab 7 consistent | 2 shared multipliers |
| Multi-cycle VLD | 4× fewer than scalar | Minimal (FSM only) |

**Overall**: 5.01× speedup on MNIST vs scalar, with Lab 7 consistent design.

