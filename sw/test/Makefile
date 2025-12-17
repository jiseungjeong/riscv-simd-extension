# Standalone Firmware Makefile
# Build test for RISC-V processor

# Source files
C_SRCS = main.c print.c trap_handler.c
ASM_SRCS = start.S hal.S trap.S

# Object files
C_OBJS = $(C_SRCS:.c=.o)
ASM_OBJS = $(ASM_SRCS:.S=.o)
ASM_ASMS = $(ASM_SRCS:.S=.asm)
OBJS = $(C_OBJS) $(ASM_OBJS)

# Test sources from tests subdirectory
TEST_OBJS = $(addsuffix .o,$(basename $(wildcard tests/*.S)))

# Toolchain
CC = riscv64-unknown-elf-gcc
# CC = clang
AS = riscv64-unknown-elf-as
LD = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

# Architecture and ABI
ARCH = rv32im_zicsr
ABI = ilp32

# Compiler flags
# Use -O3 for auto-vectorization (not -Os which disables it)
CFLAGS = -march=$(ARCH) -mabi=$(ABI) -ffreestanding -nostdlib -O3
ASFLAGS = -march=$(ARCH) -mabi=$(ABI)
# Enable vectorization explicitly
# CFLAGS += -fvectorize -fslp-vectorize

# Linker flags
LDFLAGS = -march=$(ARCH) -mabi=$(ABI) -nostdlib -T test.lds

.SUFFIXES:

.PHONY: all clean help

all: $(TEST_OBJS) test.bin test.hex test.dis

# Link test ELF
test.elf: $(OBJS) $(TEST_OBJS) test.lds
	$(LD) $(LDFLAGS) -o $@ $(OBJS) $(TEST_OBJS) -lgcc
	chmod -x $@

# Generate binary
test.bin: test.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

# Generate hex file (for Verilog $readmemh)
test.hex: test.elf
	$(OBJCOPY) -O verilog $< $@
	chmod -x $@

# Generate disassembly
test.dis: test.elf
	$(OBJDUMP) -d $< > $@

# Compile C files
%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Step 1: Preprocess tests .S -> .asm (expand macros, handle #include and #ifdef)
# This rule must come BEFORE the generic %.asm: %.S rule
tests/%.asm: tests/%.S tests/riscv_test.h tests/test_macros.h
	$(CC) -E -mabi=$(ABI) -march=$(ARCH) -DTEST_FUNC_NAME=$(notdir $(basename $<)) \
		-DTEST_FUNC_TXT='"$(notdir $(basename $<))"' -DTEST_FUNC_RET=$(notdir $(basename $<))_ret $< \
		| grep -v '^#' > $@

# Step 2: Assemble tests .asm -> .o (pure assembly, no preprocessing)
tests/%.o: tests/%.asm
	$(AS) -mabi=$(ABI) -march=$(ARCH) $(ASFLAGS) -o $@ $<

# Step 1: Preprocess test .S -> .asm
%.asm: %.S
	$(CC) -E -mabi=$(ABI) -march=$(ARCH) $< | grep -v '^#' > $@

# Step 2: Assemble test .asm -> .o
%.o: %.asm
	$(AS) -mabi=$(ABI) -march=$(ARCH) $(ASFLAGS) -o $@ $<

clean:
	rm -f *.o *.elf *.bin *.hex *.dis *.map *.asm tests/*.o tests/*.asm

help:
	@echo "Firmware Build System"
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build all outputs (default)"
	@echo "  test.bin - Binary test image"
	@echo "  test.hex - Hex test for Verilog"
	@echo "  test.d   - Disassembly listing"
	@echo "  clean        - Remove build artifacts"
	@echo "  help         - Show this message"
	@echo ""
	@echo "Tests:"
	@echo "  Test files in tests/*.S are automatically built and linked"
	@echo "  into the test when running 'make all'"
