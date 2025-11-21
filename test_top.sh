#!/bin/bash

# =============================================================================
# Exercise Configuration
# =============================================================================
# Set to 1 to enable Exercise 5.1 (Cycle Counter with Custom Instructions)

# =============================================================================
# Verilator Compilation
# =============================================================================
# Enable warnings and treat unused signals as errors
# -Wno-DECLFILENAME: Allow module names not matching filename (multiple modules per file)
# -Wno-PINCONNECTEMPTY: Allow unconnected output ports (like unused cout)
# -Werror-UNUSED: Treat unused signals (wire/reg) as errors
verilator -Wall \
   -Wno-DECLFILENAME \
   -Wno-PINCONNECTEMPTY \
   -Werror-UNUSED \
   --cc --exe --build --top top --public -j 0 --trace \
   top.v ucrv32.v efu.v alu.v decoder_control.v top.cc sim/libSimHelper.cc

if [ $? -eq 0 ]; then
    echo "Compilation successful. Running simulation..."
    ./obj_dir/Vtop "$@"

else
    echo "Compilation failed!"
    exit 1
fi