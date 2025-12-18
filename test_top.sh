#!/bin/bash

# =============================================================================
# Exercise Configuration
# =============================================================================
# Set ENABLE_TRACE=1 to enable VCD tracing (creates large files!)
# Default: disabled for long simulations like MNIST
ENABLE_TRACE=${ENABLE_TRACE:-0}

# =============================================================================
# Verilator Compilation
# =============================================================================
# Enable warnings and treat unused signals as errors
# -Wno-DECLFILENAME: Allow module names not matching filename (multiple modules per file)
# -Wno-PINCONNECTEMPTY: Allow unconnected output ports (like unused cout)
# -Werror-UNUSED: Treat unused signals (wire/reg) as errors

TRACE_FLAG=""
if [ "$ENABLE_TRACE" = "1" ]; then
    TRACE_FLAG="--trace"
    echo "VCD tracing ENABLED (warning: large files for long simulations)"
fi

verilator -Wall \
   -Wno-DECLFILENAME \
   -Wno-PINCONNECTEMPTY \
   -Werror-UNUSED \
   --cc --exe --build --top top --public -j 0 $TRACE_FLAG \
   -CFLAGS "-std=c++17" \
   top.v ucrv32.v efu.v alu.v decoder_control.v top.cc sim/libSimHelper.cc

if [ $? -eq 0 ]; then
    echo "Compilation successful. Running simulation..."
    ./obj_dir/Vtop "$@"

else
    echo "Compilation failed!"
    exit 1
fi