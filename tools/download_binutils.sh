#!/bin/bash
#
# Simple script to download GNU binutils tarball for RISC-V
# Only downloads - does not extract or build
#
# Usage: ./download_binutils.sh [version] [output_dir]
#

set -e  # Exit on error

# Configuration
BINUTILS_VERSION="${1:-2.41}"
OUTPUT_DIR="${2:-.}"

# URL
BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz"
BINUTILS_TARBALL="binutils-${BINUTILS_VERSION}.tar.xz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check for curl
if ! command -v curl &> /dev/null; then
    print_error "curl not found"
    print_info "Install with:"
    print_info "  macOS: brew install curl"
    print_info "  Ubuntu/Debian: sudo apt-get install curl"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Download if not already present
if [ -f "$BINUTILS_TARBALL" ]; then
    print_warn "$BINUTILS_TARBALL already exists in $(pwd)"
    print_info "File size: $(du -h "$BINUTILS_TARBALL" | cut -f1)"
    print_info "To re-download, remove the file first: rm $BINUTILS_TARBALL"
    exit 0
fi

print_info "Downloading GNU binutils ${BINUTILS_VERSION}..."
print_info "URL: $BINUTILS_URL"
print_info "Output: $(pwd)/$BINUTILS_TARBALL"
echo ""

# Download with progress bar
curl -L -o "$BINUTILS_TARBALL" "$BINUTILS_URL" --progress-bar

if [ $? -eq 0 ]; then
    print_info "Download successful!"
    print_info "File: $(pwd)/$BINUTILS_TARBALL"
    print_info "Size: $(du -h "$BINUTILS_TARBALL" | cut -f1)"
    echo ""
    print_info "To extract: tar -xf $BINUTILS_TARBALL"
    print_info "Or use: ../collect_riscv_toolchain_sources.sh"
else
    print_error "Download failed"
    exit 1
fi
