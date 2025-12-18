# Wide Vector Extension Benchmark Results

## Project Overview

This project extends the Lab 7 vector unit from packed 8-bit operations on 32-bit registers to true SIMD operations on 64-bit vector registers (VLEN=64).

Based on [README.md](README.md) Topic 4: Wider-Width Vector Instructions.

📐 **Design Decisions**: See [DESIGN_DECISIONS.md](DESIGN_DECISIONS.md) for detailed rationale.

---

## Hardware Implementation Summary

| Component | File | Description |
|-----------|------|-------------|
| Vector Register File | `vreg_file.v` | 32 × 64-bit registers (v0-v31) |
| Vector ALU | `valu.v` | VADD, VSUB, VMUL, VMAC with SEW 8/16/32 |
| Vector Load/Store | `vlsu.v` | 2-cycle 64-bit transfers via 32-bit bus |
| Decoder Extension | `decoder_control.v` | New vector instruction decoding |
| Toolchain | `binutils-2.41` | Custom assembler support |

---

## Benchmark 1: Dot Product (64 elements × 100 iterations)

Comparison of Lab 7 PVMAC (32-bit) vs Wide Vector (64-bit) with different SEW values.

### Test Configuration
- **Data Size**: 64 elements
- **Iterations**: 100
- **Test Type**: Dot product (sum of element-wise products)

### Results

| Instruction | SEW | Lanes | Cycles | Speedup vs PVMAC |
|-------------|-----|-------|--------|------------------|
| **PVMAC** (Lab 7) | 8-bit | 4 | 200,508 | 1.00× (baseline) |
| **VMAC.B** (Wide) | 8-bit | 8 | 46,508 | **4.31×** |
| **VMAC.H** (Wide) | 16-bit | 4 | 46,908 | **4.27×** |
| **VMAC.W** (Wide) | 32-bit | 2 | 46,908 | **4.27×** |

### Analysis

The Wide Vector instructions show **4.3× speedup** over Lab 7 PVMAC due to:

1. **VLD instruction**: Directly loads 8 bytes from memory to vector register
2. **Eliminated packing overhead**: No manual byte packing required
3. **Reduced loop iterations**: 8 lanes vs 4 lanes

---

## Benchmark 2: MNIST MLP Inference (All SEW Comparison)

Full MNIST handwritten digit classification using a 2-layer MLP.

**Based on README.md 4.4.6**: "Compare scalar vs. vector implementations with cycle counts"

### Network Architecture
- **Layer 1**: 784 inputs → 32 hidden neurons (ReLU)
- **Layer 2**: 32 hidden → 10 output neurons
- **Total MAC operations**: 25,088 (Layer 1) + 320 (Layer 2) = **25,408**

### Test Configuration
- **Input**: 28×28 grayscale image (784 pixels)
- **Weights**: Pre-transposed for contiguous vector access
- **Measurement**: Single inference cycle count

### Results (All SEW Values)

| Implementation | SEW | Lanes | Cycles | Speedup vs Scalar |
|----------------|-----|-------|--------|-------------------|
| **Scalar** (no SIMD) | - | 1 | 916,946 | 1.00× (baseline) |
| **PVMAC** (Lab 7) | 8-bit | 4 | 275,250 | **3.33×** |
| **VMAC.B** (Wide) | 8-bit | 8 | 170,442 | **5.38×** |
| **VMAC.H** (Wide) | 16-bit | 4 | 338,938 | **2.70×** |
| **VMAC.W** (Wide) | 32-bit | 2 | 675,618 | **1.36×** |

### Speedup Visualization

```
Scalar:  ████████████████████████████████████████████████████ 916,946 cycles (1.00×)
VMAC.W:  ██████████████████████████████████████ 675,618 cycles (1.36×)
VMAC.H:  ██████████████████ 338,938 cycles (2.70×)
PVMAC:   ███████████████ 275,250 cycles (3.33×)
VMAC.B:  █████████ 170,442 cycles (5.38×)
```

### Performance Breakdown by SEW

| SEW | Element Width | Lanes | Layer 1 Iterations | Layer 2 Iterations | Memory Bandwidth |
|-----|---------------|-------|--------------------|--------------------|------------------|
| 8-bit (VMAC.B) | 1 byte | 8 | 784/8 × 32 = 3,136 | 32/8 × 10 = 40 | 8 bytes/load |
| 16-bit (VMAC.H) | 2 bytes | 4 | 784/4 × 32 = 6,272 | 32/4 × 10 = 80 | 8 bytes/load |
| 32-bit (VMAC.W) | 4 bytes | 2 | 784/2 × 32 = 12,544 | 32/2 × 10 = 160 | 8 bytes/load |

### Analysis

1. **VMAC.B is optimal** for INT8 MNIST: Maximum lanes (8) = minimum iterations
2. **VMAC.H slower than PVMAC**: Despite same 4 lanes, INT16 data requires 2× memory
3. **VMAC.W slowest vector**: Only 2 lanes, 4× memory footprint vs INT8
4. **Memory bandwidth is key**: All vector instructions load 8 bytes, but wider SEW = fewer elements

### Key Optimizations

1. **Weight Transposition**: Converted column-major weights to row-major for contiguous access
2. **VLD Direct Load**: 8 bytes loaded per instruction vs manual packing
3. **SEW-optimized data types**: Use smallest SEW that maintains accuracy
4. **Eliminated Loop Overhead**: Fewer iterations = less branch/counter overhead

---

## Instruction Encoding

All vector instructions use custom opcode `0x5B` with `funct3=010`:

```
31       25  24  20  19  15  14  12  11   7  6    0
+----------+------+------+-------+------+--------+
|  funct7  |  vs2 |  vs1 | funct3|  vd  | opcode |
+----------+------+------+-------+------+--------+
   7 bits   5 bits 5 bits 3 bits  5 bits  7 bits

funct7[6:5] = SEW (00=8bit, 01=16bit, 10=32bit)
funct7[4:0] = Operation code
  00000 = VADD
  00001 = VSUB
  00010 = VMUL
  00011 = VMAC (multiply-accumulate, result is 32-bit scalar)
  00100 = VLD
  00101 = VST
```

### Instruction Examples

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| `vld v1, a0` | `.insn r 0x5B, 2, 4, x1, a0, x0` | Load 64-bit to v1 |
| `vmac.b a0, v1, v2` | `.insn r 0x5B, 2, 3, a0, x1, x2` | 8×int8 MAC → scalar |
| `vmac.h a0, v1, v2` | `.insn r 0x5B, 2, 0x23, a0, x1, x2` | 4×int16 MAC → scalar |
| `vmac.w a0, v1, v2` | `.insn r 0x5B, 2, 0x43, a0, x1, x2` | 2×int32 MAC → scalar |

---

## Performance Counters

Cycle counts measured using custom `RDWRCTR` instruction from Lab 5:

```c
static inline unsigned int read_cycle_counter(void) {
    unsigned int count;
    asm volatile (".insn i 0x5B, 0, %0, x0, 0" : "=r"(count));
    return count;
}
```

---

## Execution Commands

### Build and Run SEW Comparison
```bash
cd /Users/wjdwl/riscv-simd-extension
make -C sw/mnist-newlib firmware32_sew_compare.hex
bash test_top.sh sw/mnist-newlib/firmware32_sew_compare.hex 2>&1 | grep "RDWRCTR"
```

### Build and Run MNIST SEW Comparison
```bash
cd /Users/wjdwl/riscv-simd-extension
make -C sw/mnist-newlib firmware32_mnist_sew.hex
bash test_top.sh sw/mnist-newlib/firmware32_mnist_sew.hex 2>&1 | grep "RDWRCTR"
```

### Build and Run Original Benchmarks
```bash
# Lab 7 PVMAC version
bash test_top.sh sw/mnist-newlib/firmware32_pvmac.hex

# Wide Vector version
bash test_top.sh sw/mnist-newlib/firmware32_wide_vec.hex
```

---

## Conclusion

The 64-bit Wide Vector Extension provides significant performance improvements:

### Scalar vs Vector Comparison (README.md 4.4.6 Requirement)

| Benchmark | Scalar | VMAC.W | VMAC.H | PVMAC | VMAC.B |
|-----------|--------|--------|--------|-------|--------|
| Lanes | 1 | 2 | 4 | 4 | 8 |
| Dot Product | - | 4.27× | 4.27× | 1.00× | **4.31×** |
| MNIST MLP | 1.00× | 1.36× | 2.70× | 3.33× | **5.38×** |

### Key Findings

1. **Vector instructions provide 1.4-5.4× speedup** over scalar code
2. **VMAC.B (8 lanes) is optimal** for INT8 workloads like MNIST
3. **SEW selection matters**: Wider elements = fewer lanes = lower throughput
4. **VMAC.H < PVMAC**: Despite same lane count, INT16 memory overhead hurts
5. **VLD + VMAC.B combination** eliminates data packing overhead

### Future Optimizations
1. Hardware support for strided vector loads (eliminate weight transposition)
2. Vector register file banking for higher throughput
3. Pipelined VMAC for back-to-back operations

---

## Files Modified/Created

| File | Status | Description |
|------|--------|-------------|
| `vreg_file.v` | New | 32×64-bit vector register file |
| `valu.v` | New | Vector ALU with VADD/VSUB/VMUL/VMAC |
| `vlsu.v` | New | Vector load/store unit |
| `decoder_control.v` | Modified | Vector instruction decoding |
| `ucrv32.v` | Modified | CPU integration |
| `tools/binutils-2.41/` | Modified | Custom instruction support |
| `sw/mnist-newlib/benchmark_*.c` | New | Benchmark programs |

