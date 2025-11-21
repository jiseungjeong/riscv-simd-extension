# LLVM/Clang Quick Start Guide for ucsoc

This guide will help you quickly set up and use LLVM/Clang to cross-compile for the ucsoc RISC-V processor (rv32im_zicsr).

## Step 1: Build LLVM (One-Time Setup)

From the `tools` directory:

```bash
cd tools
./build_llvm.sh
```

This will take 30-90 minutes. Go grab a coffee! ☕

## Step 2: Set Up Your Environment

### Option A: One-Time Session Setup

For the current terminal session only:

```bash
source tools/llvm-env.sh
```

### Option B: Permanent Setup

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="/path/to/ucsoc/tools/riscv-toolchain-sources/llvm-install/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.bashrc  # or ~/.zshrc
```

### Option C: Use in Makefile Only

No PATH setup needed! Just use the example Makefile provided.

## Step 3: Verify Installation

```bash
clang --version
```

You should see something like:
```
clang version 18.1.8
Target: x86_64-unknown-linux-gnu
...
```

## Step 4: Compile Your First Program

### Quick Test

Create a simple test file:

```c
// test.c
int add(int a, int b) {
    return a + b;
}

int _start(void) {
    return add(3, 4);
}
```

Compile it:

```bash
clang --target=riscv32-unknown-elf \
      -march=rv32im_zicsr \
      -mabi=ilp32 \
      -ffreestanding \
      -nostdlib \
      -O2 \
      -c test.c -o test.o
```

Check the output:

```bash
llvm-objdump -d test.o
```

You should see RISC-V assembly!

## Step 5: Use with Your Projects

### Copy the Example Makefile

```bash
cp tools/Makefile.llvm.example your_project/Makefile
```

### Edit for Your Project

Update the source files in the Makefile:

```makefile
C_SRCS = main.c your_file1.c your_file2.c
ASM_SRCS = start.S
```

### Build

```bash
# Build with LLVM (default)
make

# Build with GCC (for comparison)
make USE_LLVM=0

# See all options
make help
```

## Common Commands

### Compile C file
```bash
clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 \
      -ffreestanding -nostdlib -O2 -c input.c -o output.o
```

### Compile Assembly file
```bash
clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 \
      -c input.S -o output.o
```

### Link
```bash
ld.lld -T linker.ld start.o main.o -o program.elf
```

### Create Binary
```bash
llvm-objcopy -O binary program.elf program.bin
```

### Disassemble
```bash
llvm-objdump -d program.elf
```

### View Symbol Table
```bash
llvm-readelf -s program.elf
```

## Using the Convenience Alias

After running `source tools/llvm-env.sh`, you get a handy alias:

```bash
# Instead of typing the full command:
clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 -c test.c

# Just use:
riscv32-clang -c test.c
```

## Architecture Flags Explained

### `-march=rv32im_zicsr`

- `rv32` - 32-bit RISC-V
- `i` - Base integer instructions (implicit)
- `m` - Multiplication and division instructions
- `zicsr` - CSR (Control and Status Register) instructions

### `-mabi=ilp32`

- `i` - Integer calling convention
- `lp` - Longs and pointers are 32-bit
- `32` - 32-bit architecture

## Troubleshooting

### "command not found: clang"

Your PATH is not set up. Run:
```bash
source tools/llvm-env.sh
```

### "linker not found"

Use `ld.lld` instead of `ld`:
```bash
ld.lld -T linker.ld ...
```

### "undefined reference to ..."

You're missing startup code or trying to link against standard libraries. Make sure:
1. You have `start.S` or equivalent startup code
2. You use `-nostdlib` flag
3. You don't call any standard library functions

### Build was successful but binary doesn't work

Check your linker script matches your hardware memory map:
- ROM/Flash start address
- RAM start address and size
- Stack pointer initialization

## Next Steps

1. ✅ Build LLVM
2. ✅ Verify with test program
3. ✅ Set up your environment
4. ⬜ Convert your existing project to use LLVM
5. ⬜ Compare performance with GCC
6. ⬜ Optimize your code

## Comparing LLVM vs GCC

Build the same code with both and compare:

```bash
# Build with LLVM
make USE_LLVM=1 clean all
cp program.bin program-llvm.bin
llvm-size program.elf

# Build with GCC
make USE_LLVM=0 clean all
cp program.bin program-gcc.bin
riscv64-unknown-elf-size program.elf

# Compare
ls -lh program-*.bin
```

## Advanced Topics

### Enable Link-Time Optimization (LTO)

In your Makefile, add:
```makefile
CFLAGS += -flto
LDFLAGS += --lto-O2
```

### Generate Optimization Reports

```bash
clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 \
      -O2 -Rpass=inline -Rpass-analysis=loop-vectorize \
      -c program.c
```

### Cross-Compile from macOS to Linux

LLVM makes this easy (GCC requires separate builds):
```bash
# Same command works on macOS and Linux!
clang --target=riscv32-unknown-elf -march=rv32im_zicsr ...
```

## Getting Help

### Check Documentation
- [tools/README_LLVM.md](README_LLVM.md) - Comprehensive documentation
- `make help` - Show Makefile targets
- `clang --help` - Compiler options

### Verify Toolchain
```bash
make check-toolchain
```

### Debug Variables
```bash
make debug-vars
```

## Resources

- [LLVM RISC-V Target](https://llvm.org/docs/RISCVUsage.html)
- [Clang Cross-Compilation](https://clang.llvm.org/docs/CrossCompilation.html)
- [RISC-V Specs](https://riscv.org/technical/specifications/)
- [LLD Linker Docs](https://lld.llvm.org/)

---

**Pro Tip**: Keep both GCC and LLVM installed. Use LLVM for development (faster compile times, better error messages) and test with both to catch toolchain-specific issues!
