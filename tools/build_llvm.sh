#!/bin/bash
#
# Build script for LLVM/Clang RISC-V toolchain
# Builds and installs LLVM from existing configuration
#
# Usage: ./build_llvm.sh [build_dir]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} ${BOLD}$1${NC}" | tee -a "$LOG_FILE"
}

print_progress() {
    echo -e "${BLUE}[PROGRESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Number of parallel jobs - use all available CPU cores
if [[ "$OSTYPE" == "darwin"* ]]; then
    JOBS=$(sysctl -n hw.ncpu)
    # On macOS, force x86_64 architecture for compatibility
    ARCH_PREFIX="arch -x86_64"

    # Detect if we're on Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        ARCH_INFO="Apple Silicon (ARM64) - Building for x86_64 via Rosetta 2"
    else
        ARCH_INFO="Intel Mac (x86_64) - Native build"
    fi
else
    JOBS=$(nproc)
    ARCH_PREFIX=""
    ARCH_INFO="Linux $(uname -m)"
fi

# Build directory (can be specified as argument)
BUILD_DIR="${1:-$(pwd)/llvm-build}"
LOG_FILE="$(pwd)/llvm-build.log"

# Check if build directory exists and is configured
if [ ! -d "$BUILD_DIR" ]; then
    print_error "Build directory not found: $BUILD_DIR"
    print_info "Please run configure_llvm.sh first to configure the build"
    exit 1
fi

if [ ! -f "$BUILD_DIR/build.ninja" ]; then
    print_error "Build directory is not configured: $BUILD_DIR"
    print_info "Please run configure_llvm.sh first to configure the build"
    exit 1
fi

# Read configuration info if available
if [ -f "$BUILD_DIR/configure.info" ]; then
    source "$BUILD_DIR/configure.info"
    INSTALL_DIR="${INSTALL_DIR:-$(pwd)/llvm-install}"
else
    # Try to extract install directory from CMake cache
    if [ -f "$BUILD_DIR/CMakeCache.txt" ]; then
        INSTALL_DIR=$(grep "CMAKE_INSTALL_PREFIX" "$BUILD_DIR/CMakeCache.txt" | cut -d= -f2)
    else
        INSTALL_DIR="$(pwd)/llvm-install"
        print_warn "Could not determine install directory, using default: $INSTALL_DIR"
    fi
fi

# Create/clear log file
> "$LOG_FILE"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║             ${BOLD}LLVM/Clang RISC-V Build Script${NC}${CYAN}                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_info "Build Configuration:"
print_info "  Platform: $ARCH_INFO"
print_info "  Build:    $BUILD_DIR"
print_info "  Install:  $INSTALL_DIR"
print_info "  Jobs:     $JOBS parallel"
print_info "  Log:      $LOG_FILE"
echo ""

# Check for ninja
if ! command -v ninja &> /dev/null; then
    print_error "ninja not found"
    print_info "Please install ninja:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "  macOS: brew install ninja"
    else
        print_info "  Ubuntu/Debian: sudo apt-get install ninja-build"
        print_info "  Fedora: sudo dnf install ninja-build"
    fi
    exit 1
fi

# Start build process
echo "$(date): Build started" >> "$LOG_FILE"
print_info "Build started at $(date)"
echo ""

TOTAL_STEPS=3
CURRENT_STEP=0

# Step 1: Build
((CURRENT_STEP++))
print_step "[$CURRENT_STEP/$TOTAL_STEPS] Building LLVM/Clang..."
print_progress "Compiling with $JOBS parallel jobs..."
print_warn "This will take 30-90 minutes depending on your system"
print_info "Progress will be shown in real-time below"
echo ""

cd "$BUILD_DIR"

# Build with Ninja's built-in progress indicator
BUILD_START=$(date +%s)

# Ninja automatically detects if it's connected to a terminal and shows nice progress
print_info "Building... Ninja will show progress as [current/total]"
echo ""

# Run ninja with its built-in progress display
$ARCH_PREFIX ninja -j$JOBS 2>&1 | tee -a "$LOG_FILE"
BUILD_RESULT=${PIPESTATUS[0]}

if [ $BUILD_RESULT -eq 0 ]; then
    BUILD_END=$(date +%s)
    BUILD_TIME=$((BUILD_END - BUILD_START))
    BUILD_MINS=$((BUILD_TIME / 60))
    BUILD_SECS=$((BUILD_TIME % 60))
    print_progress "✓ Build completed successfully in ${BUILD_MINS}m ${BUILD_SECS}s"
else
    print_error "✗ Build failed - check $LOG_FILE for details"
    print_info "Common issues:"
    print_info "  - Out of memory: Try reducing parallel jobs with: ninja -j4"
    print_info "  - Missing dependencies: Re-run configure_llvm.sh"
    exit 1
fi
echo "" | tee -a "$LOG_FILE"

# Step 2: Install
((CURRENT_STEP++))
print_step "[$CURRENT_STEP/$TOTAL_STEPS] Installing LLVM/Clang..."
print_progress "Installing to $INSTALL_DIR..."

if $ARCH_PREFIX ninja install >> "$LOG_FILE" 2>&1; then
    print_progress "✓ Installation completed"
else
    print_error "✗ Installation failed - check $LOG_FILE for details"
    exit 1
fi
echo "" | tee -a "$LOG_FILE"

# Step 3: Verify installation
((CURRENT_STEP++))
print_step "[$CURRENT_STEP/$TOTAL_STEPS] Verifying installation..."

verify_installation() {
    local errors=0

    # Check for clang
    if [ -f "$INSTALL_DIR/bin/clang" ]; then
        print_progress "✓ clang installed"
        "$INSTALL_DIR/bin/clang" --version | head -n1 | tee -a "$LOG_FILE"
    else
        print_error "✗ clang not found"
        errors=$((errors + 1))
    fi

    # Check for lld
    if [ -f "$INSTALL_DIR/bin/ld.lld" ]; then
        print_progress "✓ lld linker installed"
    else
        print_error "✗ ld.lld not found"
        errors=$((errors + 1))
    fi

    # Check for llvm-ar
    if [ -f "$INSTALL_DIR/bin/llvm-ar" ]; then
        print_progress "✓ llvm-ar installed"
    else
        print_error "✗ llvm-ar not found"
        errors=$((errors + 1))
    fi

    # Check for llvm-objcopy
    if [ -f "$INSTALL_DIR/bin/llvm-objcopy" ]; then
        print_progress "✓ llvm-objcopy installed"
    else
        print_error "✗ llvm-objcopy not found"
        errors=$((errors + 1))
    fi

    # Check for llvm-objdump
    if [ -f "$INSTALL_DIR/bin/llvm-objdump" ]; then
        print_progress "✓ llvm-objdump installed"
    else
        print_error "✗ llvm-objdump not found"
        errors=$((errors + 1))
    fi

    if [ $errors -eq 0 ]; then
        print_progress "✓ All tools verified successfully"
        return 0
    else
        print_error "$errors tool(s) missing"
        return 1
    fi
}

verify_installation
echo ""

# Final summary
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ${BOLD}BUILD SUCCESSFUL!${NC}${GREEN}                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_info "Build completed at $(date)"
print_info "LLVM/Clang installed to: $INSTALL_DIR"
print_info "Target: riscv64-unknown-elf (rv32im_zicsr)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Add to PATH: ${CYAN}export PATH=\$PATH:$INSTALL_DIR/bin${NC}"
echo -e "  2. Verify: ${CYAN}clang --version${NC}"
echo ""
echo -e "${YELLOW}Usage examples:${NC}"
echo -e "  Compile: ${CYAN}clang --target=riscv64-unknown-elf -march=rv32im_zicsr -mabi=ilp32 -c program.c${NC}"
echo -e "  Link:    ${CYAN}ld.lld -T link.ld program.o -o program.elf${NC}"
echo -e "  Binary:  ${CYAN}llvm-objcopy -O binary program.elf program.bin${NC}"
echo ""
echo -e "${YELLOW}For incremental rebuilds:${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "  After code changes: ${CYAN}cd $BUILD_DIR && arch -x86_64 ninja${NC}"
else
    echo -e "  After code changes: ${CYAN}cd $BUILD_DIR && ninja${NC}"
fi
echo -e "  Full rebuild:       ${CYAN}./build_llvm.sh${NC}"
echo ""
print_info "Full build log: $LOG_FILE"

# Add completion timestamp to log
echo "" >> "$LOG_FILE"
echo "$(date): Build completed successfully" >> "$LOG_FILE"