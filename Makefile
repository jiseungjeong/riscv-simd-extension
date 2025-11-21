FIRMWARE_OBJS=firmware/main.o firmware/print.o firmware/start.o firmware/hal.o
TEST_OBJS = $(addsuffix .o,$(basename $(wildcard tests/*.S)))
CUSTOM_BIN := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/tools/riscv-toolchain-sources/binutils-install/bin/
CLANG_BIN := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/tools/riscv-toolchain-sources/llvm-install/bin/
CUSTOM_BIN:=
export PATH := $(CLANG_BIN):$(CUSTOM_BIN):$(PATH)


# =============================================================================
# Exercise Configuration
# =============================================================================
# Set to 1 to enable Exercise 5.1 (Cycle Counter with Custom Instructions)
ENABLE_EXERCISE_5_1=1

.SUFFIXES:


# Build C/Assembly defines
CFLAGS_EXERCISE=
CFLAGS_EXERCISE += -DEXERCISE_5_1 -DLAB_5_1  -DLAB_5_3

.PHONY: all clean check-binutils
CC=riscv64-unknown-elf-gcc
#CC=clang
#LD=riscv64-unknown-elf-gcc
AS := riscv64-unknown-elf-as
LD := riscv64-unknown-elf-ld
OBJCOPY := riscv64-unknown-elf-objcopy
OBJDUMP := riscv64-unknown-elf-objdump

# AS := $(CUSTOM_BIN)/riscv64-unknown-elf-as
# LD := $(CUSTOM_BIN)/riscv64-unknown-elf-ld
# OBJCOPY := $(CUSTOM_BIN)/riscv64-unknown-elf-objcopy
# OBJDUMP := $(CUSTOM_BIN)/riscv64-unknown-elf-objdump

# Force use of custom binutils
CFLAGS += -B$(CUSTOM_BIN)
LDFLAGS += -B$(CUSTOM_BIN)

# Strict assembly mode: use numeric registers (x0-x31) and avoid pseudo-instructions
# -mno-arch-attr: Don't add arch attribute to object files
# These flags discourage (but don't completely prevent) pseudo-instructions
STRICT_ASM_FLAGS := -mno-arch-attr
ASFLAGS += $(STRICT_ASM_FLAGS)
CFLAGS += $(addprefix -Wa$(comma),$(STRICT_ASM_FLAGS))

# Helper for comma-separated lists
comma := ,

.PHONY: all sim

all: $(TEST_OBJS) firmware/firmware.hex firmware/firmware.d 

sim: firmware/firmware.hex
	bash test_top.sh

firmware/firmware.elf: $(FIRMWARE_OBJS) $(TEST_OBJS)  firmware/firmware.lds
	$(CC) -Os -mabi=ilp32 -march=rv32im -ffreestanding -nostdlib -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,firmware/firmware.lds,-Map,firmware/firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) $(TEST_OBJS) -lgcc
	chmod -x $@


# Step 1: Preprocess .S -> .asm (expand macros, handle #include and #ifdef)
tests/%.asm: tests/%.S tests/riscv_test.h tests/test_macros.h
	$(CC) -E -mabi=ilp32 -march=rv32im -DTEST_FUNC_NAME=$(notdir $(basename $<)) \
		-DTEST_FUNC_TXT='"$(notdir $(basename $<))"' -DTEST_FUNC_RET=$(notdir $(basename $<))_ret $< \
		| grep -v '^#' > $@

# Step 2: Assemble .asm -> .o (pure assembly, no preprocessing)
tests/%.o: tests/%.asm
	$(AS) -mabi=ilp32 -march=rv32im $(ASFLAGS) -o $@ $<


#%.o: %.c
#	$(CC) -c -mabi=ilp32 -march=rv32i $(CFLAGS_EXERCISE) -ffreestanding -nostdlib -o $@ $<


firmware/%.s: firmware/%.c
	$(CC) -S -mabi=ilp32 -march=rv32i $(CFLAGS_EXERCISE) -o $@ $< \-ffreestanding -nostdlib \
		-Wl,--build-id=none,-Bstatic,-T,firmware/firmware.lds,-Map,firmware/firmware.map,--strip-debug \

firmware/%.o: firmware/%.s
	$(CC) -c -mabi=ilp32 -march=rv32i $(CFLAGS_EXERCISE) $(CFLAGS) -o $@ $<

# Step 1: Preprocess firmware .S -> .asm
firmware/%.asm: firmware/%.S
	$(CC) -E -mabi=ilp32 -march=rv32i $(CFLAGS_EXERCISE) $< | grep -v '^#' > $@

# Step 2: Assemble firmware .asm -> .o
firmware/%.o: firmware/%.asm
	$(AS) -mabi=ilp32 -march=rv32i $(ASFLAGS) -o $@ $<

firmware/firmware.hex: firmware/firmware.elf $(FIRMWARE_OBJS)
	$(OBJCOPY) -O verilog $< $@
	chmod -x $@

firmware/firmware.d: firmware/firmware.elf $(FIRMWARE_OBJS)
	$(OBJDUMP) -d $< > $@

# firmware/%.o: firmware/%.c
# 	$(CC) -c -mabi=ilp32 -march=rv32i -Os --std=c99 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<


clean:
	rm -f firmware/firmware.elf firmware/firmware.bin firmware/firmware.hex firmware/firmware.d $(FIRMWARE_OBJS) $(TEST_OBJS)
	rm -rf obj_dir
	rm -f *.vcd
	rm -f firmware_instruction_trace.txt
	rm -f firmware_trace.txt
	rm -f *_trace.txt

# Debug target: verify custom binutils is being used
check-binutils:
	@echo "=== Custom binutils directory ==="
	@echo "$(CUSTOM_BIN)"
	@echo ""
	@echo "=== PATH ==="
	@echo "$(PATH)" | tr ':' '\n' | head -5
	@echo ""
	@echo "=== Which assembler found in PATH? ==="
	@which riscv32-unknown-elf-as || echo "Not found in PATH"
	@echo ""
	@echo "=== Which assembler will GCC use? ==="
	@$(CC) $(CFLAGS) -print-prog-name=as
	@echo ""
	@echo "=== Custom assembler version ==="
	@$(AS) --version | head -1
	@echo ""
	@echo "=== CFLAGS ==="
	@echo "$(CFLAGS)"
	@echo ""
	@echo "=== ASFLAGS ==="
	@echo "$(ASFLAGS)"