## Topic 4: Wider-Width Vector Instructions

### 4.1 Overview

This project extends your Lab 7 vector unit from packed 8-bit operations on 32-bit registers to true SIMD operations on 64-bit or 128-bit vector registers. Wider vectors are fundamental to modern processors (AVX, NEON, RISC-V V extension) because they increase arithmetic throughput proportionally—a 128-bit datapath processes 4× more data per instruction than 32-bit. You will design the register file extension, implement vector arithmetic, and demonstrate speedup on a real workload.

### 4.2 Background

Before starting, review:

- **RISC-V Vector Extension (RVV) specification** — Focus on VLEN concept, vector register organization, and vsetvl semantics (you won't implement full RVV, but understanding the design space helps)
- **Lab 7 VMAC unit** — Your existing packed arithmetic implementation and decoder modifications
- **Lab 1 register file** — Synchronous write, asynchronous read architecture you'll extend
- **SIMD fundamentals** — Lane concept, element width (SEW), and how pack/unpack maps between scalar and vector views
- **Data alignment** — How multi-register reads/writes interact with memory interfaces

### 4.3 Building on Your Lab Work

|   Project Requirement   | Relevant Lab |                    Specific Components to Reuse/Extend                    |
| ----------------------- | ------------ | ------------------------------------------------------------------------- |
| Vector register file    | Lab 1        | 4×8 register file design → extend to 32×64 or 32×128 with dual-port reads |
| Vector ALU              | Lab 7        | PVADD parallel adder → widen to 8 or 16 lanes                             |
| Multi-cycle operations  | Lab 5, 7     | EFUADD stall logic, PVMUL pipeline → vector multiply pipeline             |
| Instruction decoding    | Lab 7        | Custom opcode 0x5B decoder → add new funct7 variants                      |
| Toolchain extension     | Lab 7        | Binutils MATCH/MASK, LLVM TableGen → new mnemonics                        |
| Memory interface        | Lab 3        | Load/store unit → vector load/store (multiple cycles or wider bus)        |
| Performance measurement | Lab 5        | Cycle counters → measure vectorization speedup                            |

### 4.4 Core Requirements

#### 4.4.1 Extended Vector Register File

**What it is**: A register file holding 32 vector registers, each 64-bit (VLEN=64) or 128-bit (VLEN=128) wide, replacing or supplementing the scalar x0-x31 registers for vector operations.

**Design decisions**:
- **Separate vs. unified**: Dedicated vector registers (v0-v31) or overlay on scalar file?
- **Read ports**: Two source operands require 2 read ports × VLEN bits wide
- **Write port**: One destination requires 1 write port × VLEN bits wide
- **Implementation**: Array of registers with mux-based selection (extend Lab 1 approach)

**Lab reference**: Lab 1 register file used 4×8 with synchronous write—scale to 32×VLEN with same timing model.

#### 4.4.2 Vector Arithmetic Unit

**What it is**: A datapath that performs parallel operations across all lanes of vector registers simultaneously.

**Required operations** (minimum):
- **VADD**: Vector add (e.g., 4×int32 for VLEN=128, or 8×int16, or 16×int8)
- **VSUB**: Vector subtract
- **VMUL**: Vector multiply (specify element width and result handling)

**Design decisions**:
- **Element width (SEW)**: Support one width (e.g., int32 only) or multiple (8/16/32)?
- **Multiply result width**: int32×int32→int32 (truncate) or →int64 (widening)?
- **Pipeline depth**: Single-cycle add/sub, multi-cycle multiply (reuse Lab 7 timing)

**Lab reference**: Lab 7 PVADD processed 4×int8 in one cycle—extend to more lanes or wider elements.

#### 4.4.3 Vector Load/Store

**What it is**: Instructions to move entire vector registers to/from memory.

**Design decisions**:
- **Memory bus width**: Keep 32-bit bus (multiple cycles per vector) or widen?
- **Alignment**: Require aligned addresses or handle misalignment?
- **Addressing modes**: Unit-stride only, or strided/indexed?

**Lab reference**: Lab 3 load/store unit handles byte/half/word—extend to multi-beat transfers.

#### 4.4.4 Decoder and Control Extension

**What it is**: Modifications to instruction decoder to recognize new vector instructions and generate appropriate control signals.

**Implementation**:
- Use existing custom opcode 0x5B with new funct3/funct7 combinations
- Add vector register file read/write enables
- Generate stall signals for multi-cycle vector operations

**Lab reference**: Lab 7 decoder extension for PVMAC—same approach for new instructions.

#### 4.4.5 Toolchain Support

**What it is**: Assembler support for your new instructions.

**Minimum requirement**: GNU Binutils extension (MATCH/MASK in riscv-opc.h/c)

**Optional**: LLVM TableGen patterns for compiler auto-vectorization

**Lab reference**: Lab 7 binutils and LLVM modifications.

#### 4.4.6 Demonstration Application

**What it is**: A real workload showing measurable speedup from vector instructions.

**Options**:
- **Signal processing**: FIR filter, FFT butterfly
- **Graphics**: Color space conversion, alpha blending
- **ML inference**: Vectorized matrix multiply (extend Lab 6 MNIST)

**Requirement**: Compare scalar vs. vector implementations with cycle counts from Lab 5 performance counters.

### 4.5 Design Decisions to Document

- **VLEN choice**: Why 64-bit or 128-bit? Tradeoff between register file area and throughput
- **Element width flexibility**: Fixed SEW vs. configurable? Impact on mux complexity
- **Register file organization**: How many read/write ports? Banking strategy?
- **Multiply implementation**: Pipelined depth, resource sharing across lanes
- **Memory interface**: Widen bus vs. multi-cycle transfers—area vs. complexity tradeoff
- **Instruction encoding**: How vector registers are specified (reuse rs1/rs2/rd or new fields?)
- **Pack/unpack granularity**: Lane-by-lane vs. full-width transfers

### 4.6 Suggested Progression

1. **Step 1**: Design vector register file, implement read/write with testbench
2. **Step 2**: Implement VADD/VSUB (single-cycle), integrate with decoder
3. **Step 3**: Add pack/unpack instructions, test scalar↔vector data movement
4. **Step 4**: Implement VMUL (multi-cycle), add stall logic
5. **Step 5**: Add vector load/store, extend toolchain
6. **Step 6**: Port application, measure performance, documentation

### 4.7 Resources

- **RISC-V Vector Extension spec**: github.com/riscv/riscv-v-spec (reference only, not implementing full RVV)
- **Lab 7 code**: Your VMAC unit, decoder modifications, binutils patches
- **Lab 1 code**: Register file implementation
- **Lab 5 code**: Stall logic for multi-cycle operations
- **Intel Intrinsics Guide**: Reference for SIMD operation semantics
- **Custom opcode map**: 0x5B with funct3=001 (Lab 7), extend with funct3=010 or new funct7 values
- **Performance counter CSRs**: 0x7E0-0x7E3 (cycle, instret, load, store from Lab 5)

### 4.8 Complexity Assessment

**Rating: 5/5**

This project requires substantial hardware additions (new register file, widened ALU, multi-cycle multiply across multiple lanes) plus pack/unpack logic that has no direct Lab 7 equivalent. The vector load/store extension adds memory interface complexity beyond single-word transfers. While students have relevant experience from Labs 1, 5, and 7, integrating all components into a working system with a real application is comparable to 2-3 labs combined. Consider offering VLEN=64 as the baseline requirement with 128-bit as an extension to calibrate difficulty.