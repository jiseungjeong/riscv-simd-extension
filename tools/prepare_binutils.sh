#!/bin/bash
#
# Extract the GNU binutils tarball and apply the custom vector-instruction patch.
# Run after download_binutils.sh and before configure_binutils.sh.
#
# Usage: ./prepare_binutils.sh [version]
#

set -e

BINUTILS_VERSION="${1:-2.41}"
TARBALL="binutils-${BINUTILS_VERSION}.tar.xz"
SRC_DIR="binutils-${BINUTILS_VERSION}"
PATCH_FILE="$(pwd)/binutils-${BINUTILS_VERSION}-simd.patch"

if [ ! -f "$PATCH_FILE" ]; then
    echo "[ERROR] Patch not found: $PATCH_FILE"
    echo "[INFO]  Run this script from the tools/ directory"
    exit 1
fi

if [ ! -d "$SRC_DIR" ]; then
    if [ ! -f "$TARBALL" ]; then
        echo "[ERROR] $TARBALL not found. Run ./download_binutils.sh first"
        exit 1
    fi
    echo "[INFO] Extracting $TARBALL..."
    tar -xf "$TARBALL"
fi

cd "$SRC_DIR"

if patch -p1 -R --dry-run -s -f < "$PATCH_FILE" > /dev/null 2>&1; then
    echo "[INFO] Custom instruction patch already applied"
else
    echo "[INFO] Applying custom instruction patch..."
    patch -p1 < "$PATCH_FILE"
fi

echo "[INFO] Source ready: $(pwd)"
