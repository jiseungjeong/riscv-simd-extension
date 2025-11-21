# LLVM/Clang RISC-V Cross-Compiler Build Guide

This directory contains scripts to build LLVM/Clang as a cross-compiler for the ucsoc RISC-V target (rv32im_zicsr).

## Quick Start

```bash
cd tools
./build_llvm.sh
```

This will:
1. Download LLVM sources (version 18.1.8 by default)
2. Configure for RISC-V rv32im_zicsr target
3. Build LLVM, Clang, LLD, and compiler-rt
4. Install to `tools/riscv-toolchain-sources/llvm-install/`
5. Create and compile a test program

## Prerequisites

### macOS
```bash
brew install cmake ninja python3 git
xcode-select --install
```

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install cmake ninja-build python3 git curl build-essential
```

### Fedora/RHEL
```bash
sudo dnf install cmake ninja-build python3 git curl gcc-c++
```

## System Requirements

- **Time**: 30-90 minutes (depending on your system)
- **RAM**: 16GB+ recommended (8GB minimum)
- **Disk**: 40GB+ free space
- **CPU**: Multi-core recommended for parallel builds

## Usage

### Build with Default Settings

```bash
./build_llvm.sh
```

### Build Specific LLVM Version

```bash
./build_llvm.sh 17.0.6
```

### Specify Custom Install Directory

```bash
./build_llvm.sh 18.1.8 /opt/llvm-riscv32
```

## After Building

### Add to PATH

Add the following to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="/path/to/ucsoc/tools/riscv-toolchain-sources/llvm-install/bin:$PATH"
```

Or for the current session only:

```bash
export PATH="$(pwd)/riscv-toolchain-sources/llvm-install/bin:$PATH"
```

### Verify Installation

```bash
clang --version
ld.lld --version
llvm-objdump --version
```

## Compiling for ucsoc (rv32im_zicsr)

### Compile C Code

```bash
clang --target=riscv32-unknown-elf \
      -march=rv32im_zicsr \
      -mabi=ilp32 \
      -ffreestanding \
      -nostdlib \
      -O2 \
      -c program.c -o program.o
```

### Compile Assembly

```bash
clang --target=riscv32-unknown-elf \
      -march=rv32im_zicsr \
      -mabi=ilp32 \
      -c start.S -o start.o
```

### Link with LLD

```bash
ld.lld -T linker.ld start.o program.o -o program.elf
```

### Generate Binary

```bash
llvm-objcopy -O binary program.elf program.bin
```

### Disassemble

```bash
llvm-objdump -d program.elf
llvm-objdump -D -S program.elf  # with source interleaving
```

## Integration with Existing Makefiles

To use LLVM/Clang in your existing Makefiles, update the toolchain variables:

```makefile
# Use LLVM/Clang instead of GCC
CC = clang
AS = clang
LD = ld.lld
OBJCOPY = llvm-objcopy
OBJDUMP = llvm-objdump
AR = llvm-ar

# Architecture and ABI
ARCH = rv32im_zicsr
ABI = ilp32

# Compiler flags for Clang
CFLAGS = --target=riscv32-unknown-elf -march=$(ARCH) -mabi=$(ABI) \
         -ffreestanding -nostdlib -O2

# Assembler flags for Clang
ASFLAGS = --target=riscv32-unknown-elf -march=$(ARCH) -mabi=$(ABI)

# Linker flags for LLD
LDFLAGS = -T linker.ld
```

## Advantages of LLVM/Clang vs GCC

1. **Integrated toolchain**: All tools (compiler, linker, binutils) from single source
2. **Better error messages**: More helpful diagnostics
3. **Faster compilation**: Often faster than GCC for small projects
4. **Modern C/C++**: Excellent C11/C17/C++17/C++20 support
5. **Easy cross-compilation**: Built-in multi-target support
6. **LLD linker**: Faster linking than GNU ld
7. **Better optimization**: Advanced optimization passes

## Architecture Details

### rv32im_zicsr

- **rv32**: 32-bit RISC-V base integer instruction set
- **i**: Base integer instructions (implicitly included in rv32)
- **m**: Integer multiplication and division extension
- **zicsr**: Control and Status Register (CSR) instructions

### ABI: ilp32

- **i**: Integer calling convention
- **lp**: Long and pointers are 32-bit
- **32**: 32-bit architecture

## Troubleshooting

### Build Fails with "Out of Memory"

Reduce parallel jobs:
```bash
# Edit build_llvm.sh and change:
ninja -j4  # instead of -j$(nproc)
```

Or add swap space:
```bash
# Linux
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### CMake Version Too Old

```bash
# Ubuntu/Debian
sudo apt-get install cmake

# Or install latest from cmake.org
wget https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-linux-x86_64.sh
sudo sh cmake-3.28.1-linux-x86_64.sh --prefix=/usr/local --skip-license
```

### Build Takes Too Long

This is normal. LLVM is a large project. On a modern 8-core CPU:
- Configure: 1-2 minutes
- Build: 30-60 minutes
- Install: 1-2 minutes

Enable compiler cache to speed up rebuilds:
```bash
sudo apt-get install ccache
export CC="ccache clang"
export CXX="ccache clang++"
```

### Linking Fails with "undefined reference"

When compiling bare-metal programs, you need to provide your own startup code and don't link against standard libraries:

```bash
# Correct (bare metal)
clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 \
      -ffreestanding -nostdlib program.c

# Wrong (tries to link against libc)
clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 program.c
```

## Comparison with GCC Toolchain

| Feature | LLVM/Clang | GCC |
|---------|------------|-----|
| Build Time | 30-60 min | 60-120 min |
| Disk Space | ~10GB | ~15GB |
| Cross-compilation | Native | Needs separate build per target |
| Linker | LLD (fast) | GNU ld (slower) |
| Error Messages | Excellent | Good |
| Optimization | Modern, aggressive | Mature, conservative |
| Binary Size | Similar | Similar |
| Standard Library | compiler-rt | libgcc |

## Using Both Toolchains

You can have both GCC and LLVM installed. Switch between them in your Makefile:

```makefile
# Toggle between toolchains
USE_CLANG ?= 1

ifeq ($(USE_CLANG),1)
    CC = clang
    LD = ld.lld
    OBJCOPY = llvm-objcopy
    CFLAGS = --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32
else
    CC = riscv64-unknown-elf-gcc
    LD = riscv64-unknown-elf-ld
    OBJCOPY = riscv64-unknown-elf-objcopy
    CFLAGS = -march=rv32im_zicsr -mabi=ilp32
endif
```

Then build with:
```bash
make USE_CLANG=1  # Use LLVM
make USE_CLANG=0  # Use GCC
```

## Directory Structure After Build

```
tools/
├── build_llvm.sh                  # This build script
├── README_LLVM.md                 # This file
└── riscv-toolchain-sources/
    ├── llvm-project-18.1.8.src/   # Source code
    ├── llvm-build/                # Build artifacts
    ├── llvm-install/              # Installed binaries
    │   └── bin/
    │       ├── clang              # C/C++ compiler
    │       ├── clang++            # C++ compiler
    │       ├── ld.lld             # Linker
    │       ├── llvm-ar            # Archiver
    │       ├── llvm-objcopy       # Object copy utility
    │       ├── llvm-objdump       # Disassembler
    │       ├── llvm-readelf       # ELF reader
    │       └── ...
    ├── test/                      # Test program
    │   ├── test.c
    │   ├── start.S
    │   ├── link.ld
    │   └── test.elf
    └── llvm-build.log            # Build log
```

## Advanced Usage

### Cross-Compile with Different Targets

LLVM can target multiple architectures from a single installation:

```bash
# RV32I (minimal)
clang --target=riscv32 -march=rv32i -mabi=ilp32 ...

# RV32IM (with multiply/divide)
clang --target=riscv32 -march=rv32im -mabi=ilp32 ...

# RV32IMC (with compressed instructions)
clang --target=riscv32 -march=rv32imc -mabi=ilp32 ...

# RV32IMAC (atomic instructions)
clang --target=riscv32 -march=rv32imac -mabi=ilp32 ...

# RV32GC (full general-purpose)
clang --target=riscv32 -march=rv32gc -mabi=ilp32d ...
```

### Generate Assembly Output

```bash
# Generate human-readable assembly
clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 \
      -S -o program.s program.c

# With optimization remarks
clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 \
      -S -Rpass=inline -Rpass-analysis=loop-vectorize program.c
```

### Link-Time Optimization (LTO)

```bash
# Compile with LTO
clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 \
      -flto -c program.c -o program.o

# Link with LTO
ld.lld -T linker.ld --lto-O2 program.o -o program.elf
```

## References

- [LLVM Documentation](https://llvm.org/docs/)
- [Clang Documentation](https://clang.llvm.org/docs/)
- [LLD Linker](https://lld.llvm.org/)
- [RISC-V Specifications](https://riscv.org/technical/specifications/)
- [RISC-V Toolchain Conventions](https://github.com/riscv-non-isa/riscv-toolchain-conventions)

## Support

For issues with this build script:
- Check `llvm-build.log` for detailed error messages
- Ensure all prerequisites are installed
- Try with a fresh build directory

For LLVM bugs:
- [LLVM Bug Tracker](https://github.com/llvm/llvm-project/issues)

For ucsoc-specific issues:
- Check the main ucsoc documentation
- Verify your linker script matches your memory layout
