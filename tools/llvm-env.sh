#!/bin/bash
#
# Environment setup for LLVM/Clang RISC-V cross-compiler
# Source this file to add LLVM tools to your PATH
#
# Usage:
#   source tools/llvm-env.sh
#   # or
#   . tools/llvm-env.sh
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLVM_INSTALL_DIR="$SCRIPT_DIR/riscv-toolchain-sources/llvm-install"

# Check if LLVM is installed
if [ ! -d "$LLVM_INSTALL_DIR/bin" ]; then
    echo "Error: LLVM installation not found at $LLVM_INSTALL_DIR"
    echo "Please run: $SCRIPT_DIR/build_llvm.sh"
    return 1 2>/dev/null || exit 1
fi

# Add LLVM to PATH
export PATH="$LLVM_INSTALL_DIR/bin:$PATH"

# Set convenience environment variables
export LLVM_DIR="$LLVM_INSTALL_DIR"
export RISCV_LLVM="$LLVM_INSTALL_DIR"

# Display confirmation
echo "LLVM/Clang RISC-V cross-compiler environment configured"
echo "LLVM installation: $LLVM_INSTALL_DIR"
echo ""
echo "Available tools:"
echo "  - clang (C/C++ compiler)"
echo "  - ld.lld (linker)"
echo "  - llvm-objcopy (binary utilities)"
echo "  - llvm-objdump (disassembler)"
echo "  - llvm-ar (archiver)"
echo ""
echo "Verify with: clang --version"
echo ""
echo "Compile example:"
echo "  clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 \\"
echo "        -ffreestanding -nostdlib -O2 -c program.c"
echo ""

# Optional: Set up aliases for easier use
alias riscv32-clang='clang --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32'
alias riscv32-clang++='clang++ --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32'

echo "Aliases created:"
echo "  - riscv32-clang  (clang with rv32im_zicsr defaults)"
echo "  - riscv32-clang++ (clang++ with rv32im_zicsr defaults)"
