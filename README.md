# RISC-V Wide Vector Extension

64-bit SIMD vector extension for RISC-V, achieving **5.38× speedup** on MNIST inference.

## Platform

- **Tested**: macOS 14.x (Sonoma), Apple Silicon (M1/M2/M3)
- **Compatible**: Ubuntu 22.04, WSL2

## Prerequisites

```bash
# macOS
brew install verilator riscv64-elf-gcc python3

# Ubuntu
sudo apt install verilator gcc-riscv64-unknown-elf python3
```

## Quick Start

```bash
# 1. Build toolchain (first time only)
cd tools && ./download_binutils.sh && ./configure_binutils.sh && ./build_binutils.sh && cd ..

# 2. Build & run benchmark
cd sw/mnist-newlib && make firmware32_mnist_sew.hex && cd ../..
bash test_top.sh sw/mnist-newlib/firmware32_mnist_sew.hex
```

## Results

| Implementation | SEW | Lanes | Cycles | Speedup |
|----------------|-----|-------|--------|---------|
| Scalar | - | 1 | 916,946 | 1.00× |
| PVMAC (Lab7) | 8-bit | 4 | 275,250 | 3.33× |
| **VMAC.B** | 8-bit | 8 | 170,442 | **5.38×** |
| VMAC.H | 16-bit | 4 | 338,938 | 2.70× |
| VMAC.W | 32-bit | 2 | 675,618 | 1.36× |

## Project Structure

```
├── vreg_file.v          # 32×64-bit vector register file
├── valu.v               # Vector ALU (VADD/VSUB/VMUL/VMAC)
├── vlsu.v               # Vector load/store unit
├── decoder_control.v    # Instruction decoder
├── ucrv32.v             # CPU integration
├── sw/mnist-newlib/     # Benchmark programs
├── tools/binutils-2.41/ # Custom assembler
├── BENCHMARK_RESULTS.md # Detailed results
└── DESIGN_DECISIONS.md  # Design rationale
```

## Documentation

- [BENCHMARK_RESULTS.md](BENCHMARK_RESULTS.md) - Performance measurements
- [DESIGN_DECISIONS.md](DESIGN_DECISIONS.md) - Design choices and rationale

