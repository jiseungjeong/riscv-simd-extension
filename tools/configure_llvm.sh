#!/bin/bash
#
# Configure script for LLVM/Clang RISC-V toolchain
# Prepares the build directory with CMake configuration
#
# Usage: ./configure_llvm.sh [--minimal] [llvm_version]
#        --minimal : Build only essential components (much faster)
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
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} ${BOLD}$1${NC}"
}

print_progress() {
    echo -e "${BLUE}[PROGRESS]${NC} $1"
}

# Parse arguments
MINIMAL_BUILD=true
LLVM_VERSION="18.1.8"

while [[ $# -gt 0 ]]; do
    case $1 in
        --minimal)
            MINIMAL_BUILD=true
            shift
            ;;
        *)
            LLVM_VERSION="$1"
            shift
            ;;
    esac
done

# Platform detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    # On macOS, force x86_64 architecture for compatibility
    ARCH_PREFIX="arch -x86_64"

    # On macOS, we might need to specify the SDK
    PLATFORM_FLAGS="-DDEFAULT_SYSROOT=$(xcrun --show-sdk-path 2>/dev/null || echo '')"

    # Disable ZSTD to avoid architecture mismatch issues
    PLATFORM_FLAGS="$PLATFORM_FLAGS -DLLVM_ENABLE_ZSTD=OFF"

    # Detect if we're on Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        ARCH_INFO="Apple Silicon (ARM64) - Building for x86_64 via Rosetta 2"
    else
        ARCH_INFO="Intel Mac (x86_64) - Native build"
    fi
else
    ARCH_PREFIX=""
    PLATFORM_FLAGS=""
    ARCH_INFO="Linux $(uname -m) - Native build"
fi

# Find LLVM source directory
LLVM_SRC=$(find "$(pwd)" -maxdepth 1 -type d -name "llvm-project-llvmorg-*" | head -n 1)

if [ -z "$LLVM_SRC" ]; then
    # Try alternate naming pattern
    LLVM_SRC=$(find "$(pwd)" -maxdepth 1 -type d -name "llvm-project-${LLVM_VERSION}*" | head -n 1)
fi

if [ -z "$LLVM_SRC" ]; then
    print_error "LLVM source directory not found in $(pwd)"
    print_info "Please run download_llvm.sh first to download LLVM sources"
    print_info "Then extract with: tar -xzf llvmorg-${LLVM_VERSION}.tar.gz"
    exit 1
fi

BUILD_DIR=$(pwd)/llvm-build
INSTALL_DIR=$(pwd)/llvm-install
CONFIG_LOG_FILE=$(pwd)/llvm-configure.log

# Create/clear log file
> "$CONFIG_LOG_FILE"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           ${BOLD}LLVM/Clang RISC-V Configuration Script${NC}${CYAN}            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$MINIMAL_BUILD" = true ]; then
    BUILD_TYPE="MINIMAL (fastest build)"
    print_warn "Minimal build selected - only essential components will be built"
    print_info "This significantly reduces build time but excludes:"
    print_info "  - compiler-rt (runtime libraries)"
    print_info "  - Extra LLVM tools"
    print_info "  - Documentation"
else
    BUILD_TYPE="FULL (all components)"
fi

print_info "Configuration Settings:"
print_info "  Build Type: $BUILD_TYPE"
print_info "  Platform:   $ARCH_INFO"
print_info "  Source:     $LLVM_SRC"
print_info "  Build:      $BUILD_DIR"
print_info "  Install:    $INSTALL_DIR"
print_info "  Target:     riscv64-unknown-elf (rv32im_zicsr)"
print_info "  Log:        $CONFIG_LOG_FILE"
echo ""

# Check for required dependencies
check_dependencies() {
    print_step "Checking dependencies..."

    local missing_deps=()

    # Check for required tools
    for cmd in cmake ninja python3; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install them using your package manager:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "  macOS: brew install cmake ninja python3"
        else
            print_info "  Ubuntu/Debian: sudo apt-get install cmake ninja-build python3"
            print_info "  Fedora: sudo dnf install cmake ninja-build python3"
        fi
        exit 1
    fi

    # Check CMake version (need at least 3.20)
    local cmake_version=$(cmake --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
    local cmake_major=$(echo $cmake_version | cut -d. -f1)
    local cmake_minor=$(echo $cmake_version | cut -d. -f2)

    if [ "$cmake_major" -lt 3 ] || ([ "$cmake_major" -eq 3 ] && [ "$cmake_minor" -lt 20 ]); then
        print_error "CMake version 3.20 or higher required (found $cmake_version)"
        exit 1
    fi

    print_progress "✓ All dependencies found"
    print_progress "✓ CMake version: $cmake_version"
    echo ""
}

# Check dependencies first
check_dependencies

# Check if already configured
if [ -d "$BUILD_DIR" ]; then
    if [ -f "$BUILD_DIR/build.ninja" ]; then
        print_warn "Build directory already exists and is configured at $BUILD_DIR"
        read -p "Do you want to reconfigure? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Configuration skipped. Use build_llvm.sh to build."
            exit 0
        fi
    fi
    print_info "Removing existing build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
print_step "Creating build directory..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
print_progress "✓ Build directory created"
echo ""

# Configure with CMake
print_step "Configuring LLVM/Clang with CMake..."
if [ "$MINIMAL_BUILD" = true ]; then
    print_warn "Minimal build: ~4-8GB disk space, 15-30 minutes build time"
else
    print_warn "Full build: ~40GB disk space, 30-90 minutes build time"
fi
print_info "This may take a few minutes..."
echo ""

echo "$(date): Configuration started" >> "$CONFIG_LOG_FILE"
echo "Build type: $BUILD_TYPE" >> "$CONFIG_LOG_FILE"

# Prepare CMake arguments based on build type
if [ "$MINIMAL_BUILD" = true ]; then
    # Minimal build - only clang and lld, no runtime libraries
    PROJECTS="clang;lld"
    EXTRA_FLAGS="-DLLVM_BUILD_LLVM_DYLIB=ON \
                 -DLLVM_LINK_LLVM_DYLIB=ON \
                 -DLLVM_BUILD_DOCS=OFF \
                 -DLLVM_BUILD_RUNTIME=OFF \
                 -DLLVM_BUILD_RUNTIMES=OFF \
                 -DLLVM_BUILD_UTILS=OFF \
                 -DLLVM_ENABLE_BINDINGS=OFF \
                 -DLLVM_ENABLE_OCAMLDOC=OFF \
                 -DLLVM_ENABLE_Z3_SOLVER=OFF \
                 -DLLVM_INCLUDE_DOCS=OFF \
                 -DLLVM_INCLUDE_GO_TESTS=OFF \
                 -DLLVM_INCLUDE_UTILS=OFF \
                 -DLLVM_INCLUDE_RUNTIMES=OFF \
                 -DLLVM_INSTALL_UTILS=OFF \
                 -DLLVM_ENABLE_ZLIB=OFF \
                 -DLLVM_ENABLE_LIBXML2=OFF \
                 -DLLVM_ENABLE_TERMINFO=OFF \
                 -DCLANG_BUILD_EXAMPLES=OFF \
                 -DCLANG_INCLUDE_DOCS=OFF \
                 -DCLANG_INCLUDE_TESTS=OFF \
                 -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
                 -DCLANG_ENABLE_ARCMT=OFF \
                 -DLLVM_ENABLE_PLUGINS=OFF"

    print_info "Minimal configuration: Only building clang and lld"
else
    # Full build - includes compiler-rt
    PROJECTS="clang;lld;compiler-rt"
    EXTRA_FLAGS="-DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=riscv64-unknown-elf \
                 -DCOMPILER_RT_BAREMETAL_BUILD=ON"

    print_info "Full configuration: Building clang, lld, and compiler-rt"
fi

echo "Command: cmake -G Ninja \\" >> "$CONFIG_LOG_FILE"
echo "  -DCMAKE_BUILD_TYPE=Release \\" >> "$CONFIG_LOG_FILE"
echo "  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \\" >> "$CONFIG_LOG_FILE"
echo "  -DLLVM_ENABLE_PROJECTS=$PROJECTS \\" >> "$CONFIG_LOG_FILE"
echo "  -DLLVM_TARGETS_TO_BUILD=RISCV \\" >> "$CONFIG_LOG_FILE"
echo "  -DLLVM_DEFAULT_TARGET_TRIPLE=riscv64-unknown-elf \\" >> "$CONFIG_LOG_FILE"
echo "  ... (see full command in log)" >> "$CONFIG_LOG_FILE"
echo "" >> "$CONFIG_LOG_FILE"

if $ARCH_PREFIX cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DLLVM_ENABLE_PROJECTS="$PROJECTS" \
    -DLLVM_TARGETS_TO_BUILD="RISCV" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="riscv64-unknown-elf" \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_ENABLE_LIBCXX=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_ENABLE_BACKTRACES=OFF \
    -DLLVM_ENABLE_WARNINGS=OFF \
    -DLLVM_ENABLE_PEDANTIC=OFF \
    -DLLVM_OPTIMIZED_TABLEGEN=ON \
    -DLLVM_PARALLEL_LINK_JOBS=2 \
    -DCLANG_DEFAULT_LINKER=lld \
    $EXTRA_FLAGS \
    $PLATFORM_FLAGS \
    "$LLVM_SRC/llvm" >> "$CONFIG_LOG_FILE" 2>&1; then

    print_progress "✓ Configuration completed successfully"
    echo "$(date): Configuration completed successfully" >> "$CONFIG_LOG_FILE"
else
    print_error "✗ Configuration failed"
    print_info "Check log file for details: $CONFIG_LOG_FILE"
    echo "$(date): Configuration failed" >> "$CONFIG_LOG_FILE"
    exit 1
fi

echo ""

# Save configuration info
CONFIG_INFO_FILE="$BUILD_DIR/configure.info"
cat > "$CONFIG_INFO_FILE" << EOF
# LLVM Configuration Info
# Generated: $(date)
LLVM_VERSION=$LLVM_VERSION
LLVM_SRC=$LLVM_SRC
BUILD_DIR=$BUILD_DIR
INSTALL_DIR=$INSTALL_DIR
PLATFORM=$ARCH_INFO
TARGET=riscv64-unknown-elf
ARCH=rv32im_zicsr
BUILD_TYPE=$BUILD_TYPE
MINIMAL_BUILD=$MINIMAL_BUILD
EOF

print_info "Configuration saved to: $CONFIG_INFO_FILE"

# Final summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║               ${BOLD}CONFIGURATION SUCCESSFUL!${NC}${GREEN}                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_info "Build directory configured at: $BUILD_DIR"
print_info "Installation will go to: $INSTALL_DIR"
print_info "Configuration log: $CONFIG_LOG_FILE"
echo ""

if [ "$MINIMAL_BUILD" = true ]; then
    echo -e "${YELLOW}Minimal Build Benefits:${NC}"
    echo -e "  • ${GREEN}3-5x faster build time${NC}"
    echo -e "  • ${GREEN}Much less disk space required${NC}"
    echo -e "  • ${GREEN}Lower memory usage during build${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} Minimal build excludes runtime libraries."
    echo -e "      For full functionality, use: ${CYAN}./configure_llvm.sh${NC} (without --minimal)"
else
    echo -e "${YELLOW}Tip:${NC} For faster builds, use: ${CYAN}./configure_llvm.sh --minimal${NC}"
fi

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Build: ${CYAN}./build_llvm.sh${NC}"
echo -e "  2. Or manually: ${CYAN}cd $BUILD_DIR && ninja -j\$(nproc)${NC}"
echo ""
print_info "To reconfigure with different options, run this script again"