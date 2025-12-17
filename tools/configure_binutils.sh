#!/bin/bash
#
# Configure script for GNU binutils RISC-V toolchain
# Prepares the build directory with configure script
#
# Usage: ./configure_binutils.sh [binutils_version]
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

# Platform detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    # On macOS, force x86_64 architecture for compatibility
    ARCH_PREFIX="arch -x86_64"

    # Detect if we're on Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        ARCH_INFO="Apple Silicon (ARM64) - Building for x86_64 via Rosetta 2"
    else
        ARCH_INFO="Intel Mac (x86_64) - Native build"
    fi
else
    ARCH_PREFIX=""
    ARCH_INFO="Linux $(uname -m) - Native build"
fi

# Find binutils source directory
BINUTILS_VERSION="${1:-2.41}"
BINUTILS_SRC=$(find "$(pwd)" -maxdepth 1 -type d -name "binutils-${BINUTILS_VERSION}" | head -n 1)

if [ -z "$BINUTILS_SRC" ]; then
    print_error "binutils source directory not found in $(pwd)"
    print_info "Please run download_binutils.sh first to download binutils sources"
    print_info "Then extract with: tar -xf binutils-${BINUTILS_VERSION}.tar.xz"
    exit 1
fi

BUILD_DIR=$(pwd)/binutils-build
INSTALL_DIR=$(pwd)/binutils-install
CONFIG_LOG_FILE=$(pwd)/binutils-configure.log

# Create/clear log file
> "$CONFIG_LOG_FILE"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          ${BOLD}GNU Binutils RISC-V Configuration Script${NC}${CYAN}           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_info "Configuration Settings:"
print_info "  Platform: $ARCH_INFO"
print_info "  Source:   $BINUTILS_SRC"
print_info "  Build:    $BUILD_DIR"
print_info "  Install:  $INSTALL_DIR"
print_info "  Target:   riscv64-unknown-elf"
print_info "  Log:      $CONFIG_LOG_FILE"
echo ""

# macOS specific checks and patches
if [[ "$OSTYPE" == "darwin"* ]]; then
    print_step "Checking macOS compatibility..."

    PATCH_FILE="$BINUTILS_SRC/zlib/zutil.h"

    # Check if patch is needed
    if [ -f "$PATCH_FILE" ]; then
        if grep -q '#if (defined(_MSC_VER) && (_MSC_VER > 600)) && !defined __INTERIX' "$PATCH_FILE" 2>/dev/null; then
            print_progress "Applying macOS zlib patch..."

            # Backup original file
            cp "$PATCH_FILE" "$PATCH_FILE.backup" 2>> "$CONFIG_LOG_FILE"

            # Apply patch using sed
            sed -i.tmp 's/#if (defined(_MSC_VER) && (_MSC_VER > 600)) && !defined __INTERIX/#if 0/' "$PATCH_FILE" 2>> "$CONFIG_LOG_FILE"
            rm -f "$PATCH_FILE.tmp"

            print_progress "✓ macOS patch applied successfully"
        else
            print_progress "✓ macOS patch already applied or not needed"
        fi
    fi
    echo ""
fi

# Check if already configured
if [ -d "$BUILD_DIR" ]; then
    if [ -f "$BUILD_DIR/Makefile" ]; then
        print_warn "Build directory already exists and is configured at $BUILD_DIR"
        read -p "Do you want to reconfigure? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Configuration skipped. Use build_binutils.sh to build."
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

# Configure
print_step "Configuring GNU binutils..."
print_info "This may take a moment..."
echo ""

echo "$(date): Configuration started" >> "$CONFIG_LOG_FILE"
echo "Command: $BINUTILS_SRC/configure \\" >> "$CONFIG_LOG_FILE"
echo "  --prefix=$INSTALL_DIR \\" >> "$CONFIG_LOG_FILE"
echo "  --target=riscv64-unknown-elf \\" >> "$CONFIG_LOG_FILE"
echo "  --enable-multilib \\" >> "$CONFIG_LOG_FILE"
echo "  --disable-nls \\" >> "$CONFIG_LOG_FILE"
echo "  --disable-werror" >> "$CONFIG_LOG_FILE"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  --with-system-zlib" >> "$CONFIG_LOG_FILE"
fi
echo "" >> "$CONFIG_LOG_FILE"

# Configure with platform-specific flags
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Use system zlib on macOS to avoid conflicts
    # Disable zstd to avoid x86_64/arm64 architecture mismatch on Apple Silicon
    if $ARCH_PREFIX env MAKEINFO="${MAKEINFO:-missing}" \
        $BINUTILS_SRC/configure \
        --prefix=$INSTALL_DIR \
        --target=riscv64-unknown-elf \
        --enable-multilib \
        --disable-nls \
        --disable-werror \
        --with-system-zlib \
        --without-zstd >> "$CONFIG_LOG_FILE" 2>&1; then

        print_progress "✓ Configuration completed successfully"
        echo "$(date): Configuration completed successfully" >> "$CONFIG_LOG_FILE"
    else
        print_error "✗ Configuration failed"
        print_info "Check log file for details: $CONFIG_LOG_FILE"
        echo "$(date): Configuration failed" >> "$CONFIG_LOG_FILE"
        exit 1
    fi
else
    if MAKEINFO="${MAKEINFO:-missing}" \
        $BINUTILS_SRC/configure \
        --prefix=$INSTALL_DIR \
        --target=riscv64-unknown-elf \
        --enable-multilib \
        --disable-nls \
        --disable-werror >> "$CONFIG_LOG_FILE" 2>&1; then

        print_progress "✓ Configuration completed successfully"
        echo "$(date): Configuration completed successfully" >> "$CONFIG_LOG_FILE"
    else
        print_error "✗ Configuration failed"
        print_info "Check log file for details: $CONFIG_LOG_FILE"
        echo "$(date): Configuration failed" >> "$CONFIG_LOG_FILE"
        exit 1
    fi
fi

echo ""

# Save configuration info
CONFIG_INFO_FILE="$BUILD_DIR/configure.info"
cat > "$CONFIG_INFO_FILE" << EOF
# Binutils Configuration Info
# Generated: $(date)
BINUTILS_VERSION="$BINUTILS_VERSION"
BINUTILS_SRC="$BINUTILS_SRC"
BUILD_DIR="$BUILD_DIR"
INSTALL_DIR="$INSTALL_DIR"
PLATFORM="$ARCH_INFO"
TARGET="riscv64-unknown-elf"
ARCH_PREFIX="$ARCH_PREFIX"
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
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Build: ${CYAN}./build_binutils.sh${NC}"
echo -e "  2. Or manually: ${CYAN}cd $BUILD_DIR && make -j\$(nproc)${NC}"
echo ""
print_info "To reconfigure with different options, run this script again"