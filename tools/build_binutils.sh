#!/bin/bash
#
# Build script for GNU binutils RISC-V toolchain
# Builds and installs binutils from existing configuration
#
# Usage: ./build_binutils.sh [build_dir]
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

# Print functions with colors (output to both terminal and log)
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
    ARCH_INFO="Linux $(uname -m) - Native build"
fi

# Build directory (can be specified as argument)
BUILD_DIR="${1:-$(pwd)/binutils-build}"
LOG_FILE="$(pwd)/binutils-build.log"

# Check if build directory exists and is configured
if [ ! -d "$BUILD_DIR" ]; then
    print_error "Build directory not found: $BUILD_DIR"
    print_info "Please run configure_binutils.sh first to configure the build"
    exit 1
fi

if [ ! -f "$BUILD_DIR/Makefile" ]; then
    print_error "Build directory is not configured: $BUILD_DIR"
    print_info "Please run configure_binutils.sh first to configure the build"
    exit 1
fi

# Read configuration info if available
if [ -f "$BUILD_DIR/configure.info" ]; then
    source "$BUILD_DIR/configure.info"
    INSTALL_DIR="${INSTALL_DIR:-$(pwd)/binutils-install}"
    # Restore ARCH_PREFIX from configuration
    ARCH_PREFIX="${ARCH_PREFIX:-}"
else
    INSTALL_DIR="$(pwd)/binutils-install"
    print_warn "Could not read configuration info, using defaults"
fi

# Create/clear log file
> "$LOG_FILE"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║            ${BOLD}GNU Binutils RISC-V Build Script${NC}${CYAN}                 ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_info "Build Configuration:"
print_info "  Platform: $ARCH_INFO"
print_info "  Build:    $BUILD_DIR"
print_info "  Install:  $INSTALL_DIR"
print_info "  Jobs:     $JOBS parallel"
print_info "  Log:      $LOG_FILE"
echo ""

# Start build process
echo "$(date): Build started" >> "$LOG_FILE"
print_info "Build started at $(date)"
echo ""

TOTAL_STEPS=3
CURRENT_STEP=0

# Step 1: Build
((CURRENT_STEP++))
print_step "[$CURRENT_STEP/$TOTAL_STEPS] Building binutils..."
print_progress "Compiling with $JOBS parallel jobs..."
print_warn "This will take several minutes"
print_info "Build output will be shown below (and logged to $LOG_FILE)"
echo ""

cd "$BUILD_DIR"

# Build with output display
BUILD_START=$(date +%s)

# Run make with output display (make doesn't have as nice progress as ninja)
# We use tee to both display and log the output
$ARCH_PREFIX make -j$JOBS 2>&1 | tee -a "$LOG_FILE"
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
    print_info "  - Out of memory: Try reducing parallel jobs with: make -j4"
    print_info "  - Missing dependencies: Re-run configure_binutils.sh"
    exit 1
fi
echo "" | tee -a "$LOG_FILE"

# Step 2: Install
((CURRENT_STEP++))
print_step "[$CURRENT_STEP/$TOTAL_STEPS] Installing binutils..."
print_progress "Installing to $INSTALL_DIR..."

if $ARCH_PREFIX make install >> "$LOG_FILE" 2>&1; then
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
    local tools=(
        "riscv64-unknown-elf-as"
        "riscv64-unknown-elf-ld"
        "riscv64-unknown-elf-gcc"
        "riscv64-unknown-elf-ar"
        "riscv64-unknown-elf-objcopy"
        "riscv64-unknown-elf-objdump"
        "riscv64-unknown-elf-readelf"
        "riscv64-unknown-elf-nm"
        "riscv64-unknown-elf-strip"
    )

    for tool in "${tools[@]}"; do
        if [ -f "$INSTALL_DIR/bin/$tool" ]; then
            print_progress "✓ $tool installed"
        else
            # Some tools like gcc might not be installed by binutils alone
            if [[ "$tool" == *"gcc"* ]]; then
                print_warn "⚠ $tool not found (needs GCC installation)"
            else
                print_error "✗ $tool not found"
                errors=$((errors + 1))
            fi
        fi
    done

    if [ $errors -eq 0 ]; then
        print_progress "✓ All binutils tools verified successfully"
        return 0
    else
        print_error "$errors tool(s) missing"
        return 1
    fi
}

verify_installation
echo ""

# Get version info
if [ -f "$INSTALL_DIR/bin/riscv64-unknown-elf-as" ]; then
    VERSION_INFO=$("$INSTALL_DIR/bin/riscv64-unknown-elf-as" --version | head -n1 | tee -a "$LOG_FILE")
    print_info "Version: $VERSION_INFO"
fi

# Final summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ${BOLD}BUILD SUCCESSFUL!${NC}${GREEN}                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_info "Build completed at $(date)"
print_info "Binutils installed to: $INSTALL_DIR"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Add to PATH: ${CYAN}export PATH=\$PATH:$INSTALL_DIR/bin${NC}"
echo -e "  2. Verify: ${CYAN}riscv64-unknown-elf-as --version${NC}"
echo ""
echo -e "${YELLOW}Usage examples:${NC}"
echo -e "  Assemble: ${CYAN}riscv64-unknown-elf-as program.s -o program.o${NC}"
echo -e "  Link:     ${CYAN}riscv64-unknown-elf-ld program.o -o program.elf${NC}"
echo -e "  Objdump:  ${CYAN}riscv64-unknown-elf-objdump -d program.elf${NC}"
echo ""
echo -e "${YELLOW}For incremental rebuilds:${NC}"
echo -e "  After code changes: ${CYAN}cd $BUILD_DIR && make${NC}"
echo -e "  Full rebuild:       ${CYAN}./build_binutils.sh${NC}"
echo ""
print_info "Full build log: $LOG_FILE"

# Add completion timestamp to log
echo "" >> "$LOG_FILE"
echo "$(date): Build completed successfully" >> "$LOG_FILE"