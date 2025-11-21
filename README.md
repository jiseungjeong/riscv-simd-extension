## Lab 7: Vector Instructions for MNIST Acceleration

### Overview

In this lab, you will implement custom **packed vector instructions** to accelerate neural network inference. You will start by implementing the hardware module, then decode the new instructions, test them with assembly code, extend the toolchain (binutils and LLVM), and finally accelerate the MNIST neural network using the new vector capabilities.

**Learning Objectives:**
- Implement SIMD (Single Instruction Multiple Data) hardware acceleration
- Extend the RISC-V ISA with custom vector instructions
- Modify GNU binutils and LLVM to support new instructions
- Optimize neural network inference with vectorization
- Measure and analyze performance improvements

### Labs

#### Lab 7.1: Implement vmac.v Module

Implement the vector multiply-accumulate unit that performs operations on packed int8 values.

- **Hardware Module**: Create [vmac.v](../vmac.v) with four operations:
  - PVADD: Packed vector add (4×int8 parallel addition)
  - PVMUL: Packed vector multiply, lower lanes (2×int8 multiply)
  - PVMUL_UPPER: Packed vector multiply, upper lanes (2×int8 multiply)
  - PVMAC: Packed vector multiply-accumulate (4×int8 dot product → int32)

- **Interface**:
  ```verilog
  module vmac(
      input wire clk,
      input wire rst_n,
      input wire [1:0] ctrl,          // Operation select
      input wire [31:0] a,            // rs1 (packed int8)
      input wire [31:0] b,            // rs2 (packed int8)
      input wire valid_in,            // Start operation
      output reg valid_out,           // Result ready
      output reg [31:0] result        // Output
  );
  ```

- **Operation Control**:
  - ctrl=2'b00: PVADD (1 cycle)
  - ctrl=2'b01: PVMUL (4 cycles)
  - ctrl=2'b10: PVMAC (5 cycles)
  - ctrl=2'b11: PVMUL_UPPER (4 cycles)

- **Critical**: Use proper signed arithmetic with sign extension for int8×int8→int16→int32

#### Lab 7.2: Extend Decoder for New Instructions

Modify the processor to decode the four new vector instructions.

- **Instruction Encoding** (Opcode=0x5B, funct3=001):
  - PVADD: funct7=0x00
  - PVMUL: funct7=0x01
  - PVMAC: funct7=0x02
  - PVMUL_UPPER: funct7=0x03

- **Hardware**: Modify [decoder_control.v](../decoder_control.v) to recognize new opcodes and generate control signals

- **Assembly Directives**: Initially use `.word` directives in [sw/test/hal.S](../sw/test/hal.S):
  ```asm
  pvadd:
      .word 0x0005A5B | (12 << 15) | (10 << 20) | (11 << 7)  # rd=a1, rs1=a0, rs2=a1
      jr ra

  pvmul:
      .word 0x0205A5B | (12 << 15) | (10 << 20) | (11 << 7)
      jr ra

  pvmac:
      .word 0x0405A5B | (12 << 15) | (10 << 20) | (11 << 7)
      jr ra

  pvmul_upper:
      .word 0x0605A5B | (12 << 15) | (10 << 20) | (11 << 7)
      jr ra
  ```

#### Lab 7.3: Connect vmac Module and Test

Integrate the vmac module with the processor and verify functionality.

- **Hardware**: Connect vmac.v in [ucrv32.v](../ucrv32.v):
  - Wire vmac control signals from decoder
  - Connect operands from register file
  - Stall pipeline during multi-cycle operations
  - Write result back to register file

- **Software Test**: Run test program in [sw/test/main.c](../sw/test/main.c):
  ```c
  int a = (1 << 24) | (2 << 16) | (3 << 8) | 4;      // {1, 2, 3, 4}
  int b = (10 << 24) | (20 << 16) | (30 << 8) | 40;  // {10, 20, 30, 40}

  int pvadd_result = pvadd(a, b);     // Expect {11, 22, 33, 44} = 0x0B162128
  int pvmac_result = pvmac(a, b);     // Expect 300 (1*10 + 2*20 + 3*30 + 4*40)
  ```

- **Verification**:
  ```bash
  cd sw/test
  make clean && make
  bash test_top.sh test/test.hex
  ```

#### Lab 7.4: Build and Use Custom Binutils

Fetch, build and use custom-built binutils to assemble the new instructions.

- **Fetch and Build**:
  ```bash
  cd tools
  ./download_binutils.sh        # Download binutils source
  ./configure_binutils.sh       # Configure for RISC-V
  ./build_binutils.sh          # Build (~10 minutes)
  ```

- **Test Makefile**: Uncomment the custom toolchain lines in [sw/test/Makefile](../sw/test/Makefile):
  ```makefile
  # Uncomment these lines to use custom binutils
  TOOLCHAIN_PREFIX = ../../tools/install/bin/riscv32-unknown-elf-
  AS = $(TOOLCHAIN_PREFIX)as
  LD = $(TOOLCHAIN_PREFIX)ld
  OBJCOPY = $(TOOLCHAIN_PREFIX)objcopy
  OBJDUMP = $(TOOLCHAIN_PREFIX)objdump
  ```

- **Rebuild and Test**:
  ```bash
  cd sw/test
  make clean && make
  bash test_top.sh sw/test/test.hex
  ```

#### Lab 7.5: Vectorize MNIST with New Instructions

Modify the INT8 MNIST implementation to use the vector instructions.

- **Create Vectorized Version**: [sw/mnist-newlib-int8/benchmark_pvmac.c](../sw/mnist-newlib-int8/benchmark_pvmac.c)

- **Pack Helper Function**:
  ```c
  static inline int32_t pack4(int8_t a, int8_t b, int8_t c, int8_t d) {
      return ((uint32_t)(uint8_t)d << 24) |
             ((uint32_t)(uint8_t)c << 16) |
             ((uint32_t)(uint8_t)b << 8)  |
             (uint8_t)a;
  }
  ```

- **PVMAC Wrapper** (inline assembly):
  ```c
  static inline int32_t pvmac(int32_t a, int32_t b) {
      int32_t result;
      asm volatile (".insn r 0x5B, 1, 2, %0, %1, %2"
                    : "=r"(result)
                    : "r"(a), "r"(b));
      return result;
  }
  ```

- **Vectorized Matrix Multiply**:
  ```c
  // Layer 1: 784 inputs -> 32 hidden neurons
  for (int j = 0; j < HIDDEN_SIZE; j++) {
      int32_t acc = 0;

      // Process 4 elements at a time
      for (int i = 0; i < INPUT_SIZE; i += 4) {
          int32_t input_vec = pack4(input_i8[i], input_i8[i+1],
                                    input_i8[i+2], input_i8[i+3]);
          int32_t weight_vec = pack4(W1_i8[i][j], W1_i8[i+1][j],
                                     W1_i8[i+2][j], W1_i8[i+3][j]);

          acc += pvmac(input_vec, weight_vec);  // 4 MAC ops in 1 instruction!
      }

      hidden[j] = relu_int8(acc);
  }
  ```

#### Lab 7.6: Measure Performance with Counters

Use the performance counters from Lab 5 to measure and compare performance.

#### Lab 7.7: Extend Assembler for New Instructions

Modify GNU binutils to recognize the new instruction mnemonics.

- **Copy Code Snippets**: Add to [binutils-2.41/include/opcode/riscv-opc.h](../tools/binutils-2.41/include/opcode/riscv-opc.h):
  ```c
  // Add these defines (copy from lab7.md model solution)
  #define MATCH_PVADD       0x0000005b
  #define MASK_PVADD        0xfe00707f
  #define MATCH_PVMUL       0x0200005b
  #define MASK_PVMUL        0xfe00707f
  #define MATCH_PVMAC       0x0400005b
  #define MASK_PVMAC        0xfe00707f
  #define MATCH_PVMUL_UPPER 0x0600005b
  #define MASK_PVMUL_UPPER  0xfe00707f
  ```

- **Copy Opcode Table Entries**: Add to [binutils-2.41/opcodes/riscv-opc.c](../tools/binutils-2.41/opcodes/riscv-opc.c):
  ```c
  // Add these to riscv_opcodes[] array (copy from lab7.md)
  {"pvadd",       0, INSN_CLASS_I, "d,s,t", MATCH_PVADD, MASK_PVADD, match_opcode, 0},
  {"pvmul",       0, INSN_CLASS_I, "d,s,t", MATCH_PVMUL, MASK_PVMUL, match_opcode, 0},
  {"pvmac",       0, INSN_CLASS_I, "d,s,t", MATCH_PVMAC, MASK_PVMAC, match_opcode, 0},
  {"pvmul_upper", 0, INSN_CLASS_I, "d,s,t", MATCH_PVMUL_UPPER, MASK_PVMUL_UPPER, match_opcode, 0},
  ```

- **Rebuild Binutils**:
  ```bash
  cd tools
  ./build_binutils.sh
  ```

- **Update Assembly**: Replace `.word` directives with mnemonics in [sw/test/hal.S](../sw/test/hal.S):
  ```asm
  pvadd:
      pvadd a1, a0, a1
      jr ra

  pvmac:
      pvmac a1, a0, a1
      jr ra
  ```

#### Lab 7.8: Build and Use Custom LLVM/Clang

Fetch, build and use custom-built LLVM with RISC-V backend.

- **Fetch and Build LLVM** (this will take ~30 minutes):
  ```bash
  cd tools
  ./download_llvm.sh          # Download LLVM source
  ./configure_llvm.sh         # Configure for RISC-V
  ./build_llvm.sh            # Build (be patient!)
  ```

- **Update Test Makefile** to use custom Clang:
  ```makefile
  # Uncomment for custom LLVM
  CC = ../../tools/install/bin/clang
  CFLAGS = -target riscv32-unknown-elf -march=rv32im -O2
  ```

- **Rebuild and Test**:
  ```bash
  cd sw/test
  make clean && make
  bash test_top.sh test/test.hex
  ```

#### Lab 7.9: Implement Pattern Matching

Add pattern matching rules to LLVM backend for automatic instruction selection.

- **Copy LLVM Backend Modifications**:

  Create [llvm-project-llvmorg-18.1.8/llvm/lib/Target/RISCV/RISCVCustomVector.td](../tools/llvm-project-llvmorg-18.1.8/llvm/lib/Target/RISCV/RISCVCustomVector.td):
  ```tablegen
// Custom Packed-SIMD Instructions for Lab 7
// These are enabled when the M extension is present (rv32im)

let Predicates = [HasStdExtM] in {
  // Instruction definitions for all packed-SIMD operations
  let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {
    def PVADD : RVInstR<0b0000000, 0b001, OPC_CUSTOM_1, (outs GPR:$rd),
                        (ins GPR:$rs1, GPR:$rs2), "pvadd", "$rd, $rs1, $rs2">;
    def PVMUL : RVInstR<0b0000001, 0b001, OPC_CUSTOM_1, (outs GPR:$rd),
                        (ins GPR:$rs1, GPR:$rs2), "pvmul", "$rd, $rs1, $rs2">;
    def PVMAC : RVInstR<0b0000010, 0b001, OPC_CUSTOM_1, (outs GPR:$rd),
                        (ins GPR:$rs1, GPR:$rs2), "pvmac", "$rd, $rs1, $rs2">;
    def PVMUL_UPPER : RVInstR<0b0000011, 0b001, OPC_CUSTOM_1, (outs GPR:$rd),
                              (ins GPR:$rs1, GPR:$rs2), "pvmul_upper", "$rd, $rs1, $rs2">;
  }

  // Complex patterns with highest priority
  let AddedComplexity = 1000 in {

  // Pattern for test_pattern_simple_pvmac - matches LLVM IR exactly:
  // Extract using lshr+and, multiply, then add in order: (((p3+p0)+p1)+p2)
  def : Pat<(i32 (add
              (add
                (add
                  // p3 + p0: (va>>24)*(vb>>24) + (va&0xFF)*(vb&0xFF)
                  (mul (srl GPR:$rs1, (i32 24)), (srl GPR:$rs2, (i32 24))),
                  (mul (and GPR:$rs1, 255), (and GPR:$rs2, 255))),
                // p1: ((va>>8)&0xFF) * ((vb>>8)&0xFF)
                (mul (and (srl GPR:$rs1, (i32 8)), 255),
                     (and (srl GPR:$rs2, (i32 8)), 255))),
              // p2: ((va>>16)&0xFF) * ((vb>>16)&0xFF)
              (mul (and (srl GPR:$rs1, (i32 16)), 255),
                   (and (srl GPR:$rs2, (i32 16)), 255)))),
            (PVMAC GPR:$rs1, GPR:$rs2)>;
  }  // End AddedComplexity
} // End Predicates = [HasStdExtM]
  ```

- **Include in RISCV Backend**: Add to [llvm-project-llvmorg-18.1.8/llvm/lib/Target/RISCV/RISCV.td](../tools/llvm-project-llvmorg-18.1.8/llvm/lib/Target/RISCV/RISCV.td):
  ```tablegen
  include "RISCVCustomVector.td"
  ```
  around at line 54

- **Rebuild LLVM**:
  ```bash
  cd tools
  ./build_llvm.sh   # Rebuild with vector support
  ```

#### Lab 7.12: Test Pattern Matching

Create test code to verify LLVM's pattern matching for automatic instruction selection.

- **Create Pattern Matching Test**: [sw/test/test_pattern.c](../sw/test/test_pattern.c)
  ```c
  #include <stdint.h>
  

  int32_t test_pattern_simple_pvmac(int32_t va, int32_t vb) {
      // Extract bytes explicitly
      int32_t a0 = (int32_t)(va & 0xFF);
      int32_t a1 = (int32_t)(((va & 0xFF00) >> 8));
      int32_t a2 = (int32_t)(((va & 0xFF0000) >> 16));
      int32_t a3 = (int32_t)(((va & 0xFF000000) >> 24));

      int32_t b0 = (int32_t)(vb & 0xFF);
      int32_t b1 = (int32_t)(((vb & 0xFF00) >> 8));
      int32_t b2 = (int32_t)(((vb & 0xFF0000) >> 16));
      int32_t b3 = (int32_t)(((vb & 0xFF000000) >> 24));

      // Multiply and mask
      int32_t p0 = (a0 * b0);
      int32_t p1 = (a1 * b1);
      int32_t p2 = (a2 * b2);
      int32_t p3 = (a3 * b3);

      // Add with the same structure as the pattern
      return (p0 + p1) + (p2 + p3);
  }
  ...
  ```

- **Compile with Pattern Matching**:
  ```bash
  cd sw/test
  ../../tools/install/bin/clang \
      -target riscv32-unknown-elf \
      -march=rv32im \
      -O3 \
      -S -o test_pattern.s \
      test_pattern.c

  # Check for PVMAC instructions generated by pattern matching
  grep "pvmac" test_pattern.s
  ```

- **Update MNIST with Pattern Matching**: Modify [sw/mnist-newlib-int8/mnist_pattern.c](../sw/mnist-newlib-int8/mnist_pattern.c):
  ```c
  void mlp_forward_pattern(const int8_t *input, int8_t *output) {
      // Simple loop - let compiler's pattern matching select PVMAC
      for (int j = 0; j < HIDDEN_SIZE; j++) {
          int32_t acc = 0;

          for (int i = 0; i < INPUT_SIZE; i++) {
              acc += (int32_t)input[i] * W1_i8[i][j];
          }

          hidden[j] = relu_int8(acc);
      }
  }
  ```

### Performance Analysis

#### Expected Performance Improvements

| Implementation | Instructions/Inference | Speedup | Notes |
|----------------|----------------------|---------|-------|
| Scalar INT32 | ~19,000 | 1.0× | Baseline |
| Scalar INT8 | ~4,900 | 3.9× | From Lab 6 |
| Manual PVMAC | ~3,500 | 5.4× | This lab |
| Pattern-matched | ~3,600 | 5.3× | With compiler |

#### Bottleneck Analysis

- **Matrix Multiply**: 4× speedup (dominates computation)
- **Packing Overhead**: ~500 instructions (data reorganization)
- **Control Flow**: ~400 instructions (loops, branches)
- **Non-vectorizable**: ReLU, bias addition remain scalar

### Implementation Notes

#### Testing Strategy
1. Test vmac.v module in isolation with testbench
2. Verify instruction decode with waveforms
3. Test with simple assembly programs before MNIST
4. Compare vectorized results with scalar for correctness
5. Measure performance only after correctness verified

#### Common Issues and Solutions

- **Sign Extension**: Ensure proper sign extension in vmac.v for int8 arithmetic
- **Pipeline Stalls**: Implement proper handshaking between processor and vmac
- **Data Alignment**: Pack int8 values correctly (watch endianness)
- **Toolchain Paths**: Use absolute paths in Makefiles for custom toolchain

### **Submission**: After completing Lab 7.12, compress the entire directory and upload to Blackboard

### References

- **RISC-V ISA Manual**: Chapter 25 (Custom Extensions)
- **SIMD Examples**: ARM NEON Programming Guide
- **LLVM TableGen**: https://llvm.org/docs/TableGen/
- **GNU Binutils**: https://sourceware.org/binutils/docs/

### Appendix: Quick Command Reference

```bash
# Build and test hardware
cd sw/test
make clean && make
bash test_top.sh test/test.hex

# Build custom toolchain
cd tools
./download_binutils.sh && ./build_binutils.sh
./download_llvm.sh && ./build_llvm.sh

# Test MNIST vectorization
cd sw/mnist-newlib-int8
make benchmark_pvmac
bash test_top.sh test/test.hex < benchmark_pvmac.bin

# Check pattern matching
clang -target riscv32-unknown-elf -march=rv32im -O3 -Rpass=isel test.c
grep pvmac test.s
```