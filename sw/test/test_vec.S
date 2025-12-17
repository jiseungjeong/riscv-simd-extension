.global test_vadd
.global test_vld
.global test_vst

# Test VADD.B: vd = vs1 + vs2 (8 lanes of int8)
test_vadd:
    # a0 = pointer to vs1 data
    # a1 = pointer to vs2 data
    # a2 = pointer to result
    vld   a3, a0         # Load vs1 from memory to v3 (using a3 as temp)
    vld   a4, a1         # Load vs2 from memory to v4
    vadd.b a5, a3, a4    # v5 = v3 + v4
    vst   x0, a2, a5     # Store result (rd=x0 unused, base=a2, data=a5)
    ret

# Test VLD: Load 64-bit vector from memory
test_vld:
    # a0 = address
    # Returns loaded value in a0 (for verification, lower 32 bits)
    vld   a1, a0         # Load to v1
    ret

# Test VST: Store 64-bit vector to memory
test_vst:
    # a0 = address
    # a1 = value to store (as vector register index)
    vst   x0, a0, a1     # Store v1 to memory (rd=x0 unused, base=a0, data=a1)
    ret
