#!/usr/bin/env python3
"""
Quantize MNIST MLP weights from float32 to Q16.16 fixed-point (int32)
Q16.16 format: 16 integer bits + 16 fractional bits
Range: -32768.0 to ~32767.99998, precision: 1/65536
"""

import numpy as np
import re

INPUT_SIZE = 784
HIDDEN_SIZE = 32
OUTPUT_SIZE = 10

def extract_floats(text):
    """Extract all float numbers from text"""
    # Match float literals like -0.123f, 0.456f, -1.23e-4f
    pattern = r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?f?'
    matches = re.findall(pattern, text)
    return [float(m.rstrip('f')) for m in matches if m not in ['784', '32', '10']]

def parse_weights_header(filename):
    """Parse the C header file and extract weight arrays"""
    with open(filename, 'r') as f:
        content = f.read()

    arrays = {}

    # Find W1 array
    w1_match = re.search(r'const float W1\[784\]\[32\] = \{(.*?)\};', content, re.DOTALL)
    if w1_match:
        floats = extract_floats(w1_match.group(1))
        arrays['W1'] = np.array(floats[:784*32], dtype=np.float32).reshape(784, 32)

    # Find b1 array
    b1_match = re.search(r'const float b1\[32\] = \{(.*?)\};', content, re.DOTALL)
    if b1_match:
        floats = extract_floats(b1_match.group(1))
        arrays['b1'] = np.array(floats[:32], dtype=np.float32)

    # Find W2 array
    w2_match = re.search(r'const float W2\[32\]\[10\] = \{(.*?)\};', content, re.DOTALL)
    if w2_match:
        floats = extract_floats(w2_match.group(1))
        arrays['W2'] = np.array(floats[:32*10], dtype=np.float32).reshape(32, 10)

    # Find b2 array
    b2_match = re.search(r'const float b2\[10\] = \{(.*?)\};', content, re.DOTALL)
    if b2_match:
        floats = extract_floats(b2_match.group(1))
        arrays['b2'] = np.array(floats[:10], dtype=np.float32)

    return arrays

def float_to_fp_int32(x):
    """Convert float to Q16.16 fixed-point (int32)"""
    FP_ONE = 65536  # 2^16
    return np.clip(np.round(x * FP_ONE), -2147483648, 2147483647).astype(np.int32)

def write_quantized_weights_header(arrays, output_file):
    """Write quantized weights to C header file"""
    with open(output_file, 'w') as f:
        f.write("#ifndef MNIST_WEIGHTS_INT32_H\n")
        f.write("#define MNIST_WEIGHTS_INT32_H\n\n")
        f.write("#include <stdint.h>\n\n")
        f.write("#define INPUT_SIZE 784\n")
        f.write("#define HIDDEN_SIZE 32\n")
        f.write("#define OUTPUT_SIZE 10\n\n")
        f.write("// Q16.16 fixed-point format: 16 integer bits + 16 fractional bits\n")
        f.write("// Range: -32768.0 to ~32767.99998, precision: 1/65536\n")
        f.write("// These weights are pre-quantized offline for efficiency\n\n")

        # Write W1
        W1_fp = float_to_fp_int32(arrays['W1'])
        f.write(f"const int32_t W1_fp[{INPUT_SIZE}][{HIDDEN_SIZE}] = {{\n")
        for i in range(784):
            f.write("    {")
            for j in range(32):
                f.write(f"{W1_fp[i,j]}")
                if j < 31:
                    f.write(", ")
            f.write("}")
            if i < 783:
                f.write(",\n")
            else:
                f.write("\n")
        f.write("};\n\n")

        # Write b1
        b1_fp = float_to_fp_int32(arrays['b1'])
        f.write(f"const int32_t b1_fp[{HIDDEN_SIZE}] = {{")
        for i in range(32):
            f.write(f"{b1_fp[i]}")
            if i < 31:
                f.write(", ")
        f.write("};\n\n")

        # Write W2
        W2_fp = float_to_fp_int32(arrays['W2'])
        f.write(f"const int32_t W2_fp[{HIDDEN_SIZE}][{OUTPUT_SIZE}] = {{\n")
        for i in range(32):
            f.write("    {")
            for j in range(10):
                f.write(f"{W2_fp[i,j]}")
                if j < 9:
                    f.write(", ")
            f.write("}")
            if i < 31:
                f.write(",\n")
            else:
                f.write("\n")
        f.write("};\n\n")

        # Write b2
        b2_fp = float_to_fp_int32(arrays['b2'])
        f.write(f"const int32_t b2_fp[{OUTPUT_SIZE}] = {{")
        for i in range(10):
            f.write(f"{b2_fp[i]}")
            if i < 9:
                f.write(", ")
        f.write("};\n\n")

        f.write("#endif\n")

    # Print statistics
    print(f"Quantization statistics:")
    print(f"W1: min={arrays['W1'].min():.6f}, max={arrays['W1'].max():.6f}")
    print(f"    Q16.16 min={W1_fp.min()}, max={W1_fp.max()}")
    print(f"b1: min={arrays['b1'].min():.6f}, max={arrays['b1'].max():.6f}")
    print(f"    Q16.16 min={b1_fp.min()}, max={b1_fp.max()}")
    print(f"W2: min={arrays['W2'].min():.6f}, max={arrays['W2'].max():.6f}")
    print(f"    Q16.16 min={W2_fp.min()}, max={W2_fp.max()}")
    print(f"b2: min={arrays['b2'].min():.6f}, max={arrays['b2'].max():.6f}")
    print(f"    Q16.16 min={b2_fp.min()}, max={b2_fp.max()}")

if __name__ == '__main__':
    print("Parsing weights from mnist_weights.h...")
    arrays = parse_weights_header('weights/mnist_weights.h')

    print(f"Found arrays: {list(arrays.keys())}")
    for name, arr in arrays.items():
        print(f"  {name}: shape={arr.shape}, dtype={arr.dtype}")

    print("\nQuantizing weights to Q16.16 format...")
    write_quantized_weights_header(arrays, 'weights/mnist_weights_int32.h')

    print("\nDone! Generated:")
    print("  - weights/mnist_weights_int32.h")
