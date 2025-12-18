RISCV_TOOLS_PREFIX = riscv64-unknown-elf-
CC = $(RISCV_TOOLS_PREFIX)gcc
AS = $(RISCV_TOOLS_PREFIX)gcc
OBJCOPY = $(RISCV_TOOLS_PREFIX)objcopy

# C flags for RV32IM
CFLAGS = -MD -Os -Wall -std=gnu99
CFLAGS += -march=rv32im -mabi=ilp32
CFLAGS += -I.

# Linker flags
LDFLAGS = -Wl,--gc-sections -Wl,-m,elf32lriscv

# Default target: build INT32 fixed-point version (no soft-float library)
all: firmware32_int32.hex firmware32_matmul.hex firmware32_pvmac.hex firmware32_wide_vec.hex firmware32_sew_compare.hex firmware32_mnist_sew.hex

# INT32 Q16.16 version (no floating-point library needed)
# NOTE: firmware already linked at 0x10000, so no --change-addresses needed
firmware32_int32.hex: firmware_int32.elf start.elf hex8tohex32.py
	$(OBJCOPY) -O verilog start.elf start.tmp
	$(OBJCOPY) -O verilog firmware_int32.elf firmware.tmp
	cat start.tmp firmware.tmp > firmware.hex
	python3 hex8tohex32.py firmware.hex > firmware32_int32.hex
	rm -f start.tmp firmware.tmp

firmware_int32.elf: benchmark_int32.o syscalls.o
	$(CC) $(LDFLAGS) -march=rv32im -mabi=ilp32 -o $@ $^ -T riscv.ld
	chmod -x firmware_int32.elf
	$(RISCV_TOOLS_PREFIX)objdump -D $@ > firmware_int32.dis
	$(RISCV_TOOLS_PREFIX)objdump -S $@ > firmware_int32.asm

benchmark_int32.o: benchmark_int32.c weights/mnist_weights.h weights/test_data.h
	$(CC) -c $(CFLAGS) -o $@ $<

# Floating-point version (uses soft-float library from newlib)
firmware32_float.hex: firmware_float.elf start.elf hex8tohex32.py
	$(OBJCOPY) -O verilog start.elf start.tmp
	$(OBJCOPY) -O verilog firmware_float.elf firmware.tmp
	cat start.tmp firmware.tmp > firmware.hex
	python3 hex8tohex32.py firmware.hex > firmware32_float.hex
	rm -f start.tmp firmware.tmp

firmware_float.elf: benchmark.o syscalls.o
	$(CC) $(LDFLAGS) -march=rv32im -mabi=ilp32 -o $@ $^ -T riscv.ld -lm
	chmod -x firmware_float.elf
	$(RISCV_TOOLS_PREFIX)objdump -D $@ > firmware_float.dis
	$(RISCV_TOOLS_PREFIX)objdump -S $@ > firmware_float.asm

benchmark.o: benchmark.c weights/mnist_weights.h weights/test_data.h
	$(CC) -c $(CFLAGS) -o $@ $<

# Matrix multiply benchmark
firmware32_matmul.hex: firmware_matmul.elf start.elf hex8tohex32.py
	$(OBJCOPY) -O verilog start.elf start.tmp
	$(OBJCOPY) -O verilog firmware_matmul.elf firmware.tmp
	cat start.tmp firmware.tmp > firmware.hex
	python3 hex8tohex32.py firmware.hex > firmware32_matmul.hex
	rm -f start.tmp firmware.tmp

firmware_matmul.elf: matmul.o syscalls.o
	$(CC) $(LDFLAGS) -march=rv32im -mabi=ilp32 -o $@ $^ -T riscv.ld
	chmod -x firmware_matmul.elf
	$(RISCV_TOOLS_PREFIX)objdump -D $@ > firmware_matmul.dis
	$(RISCV_TOOLS_PREFIX)objdump -S $@ > firmware_matmul.asm

matmul.o: matmul.c
	$(CC) -c $(CFLAGS) -o $@ $<

# Lab7 PVMAC vectorized benchmark
firmware32_pvmac.hex: firmware_pvmac.elf start.elf hex8tohex32.py
	$(OBJCOPY) -O verilog start.elf start.tmp
	$(OBJCOPY) -O verilog firmware_pvmac.elf firmware.tmp
	cat start.tmp firmware.tmp > firmware.hex
	python3 hex8tohex32.py firmware.hex > firmware32_pvmac.hex
	rm -f start.tmp firmware.tmp

firmware_pvmac.elf: benchmark_pvmac.o syscalls.o
	$(CC) $(LDFLAGS) -march=rv32im -mabi=ilp32 -o $@ $^ -T riscv.ld
	chmod -x firmware_pvmac.elf
	$(RISCV_TOOLS_PREFIX)objdump -D $@ > firmware_pvmac.dis
	$(RISCV_TOOLS_PREFIX)objdump -S $@ > firmware_pvmac.asm

benchmark_pvmac.o: benchmark_pvmac.c weights/mnist_weights_int8.h weights/test_data.h
	$(CC) -c $(CFLAGS) -o $@ $<

# Wide Vector (64-bit) benchmark
firmware32_wide_vec.hex: firmware_wide_vec.elf start.elf hex8tohex32.py
	$(OBJCOPY) -O verilog start.elf start.tmp
	$(OBJCOPY) -O verilog firmware_wide_vec.elf firmware.tmp
	cat start.tmp firmware.tmp > firmware.hex
	python3 hex8tohex32.py firmware.hex > firmware32_wide_vec.hex
	rm -f start.tmp firmware.tmp

firmware_wide_vec.elf: benchmark_wide_vec.o syscalls.o
	$(CC) $(LDFLAGS) -march=rv32im -mabi=ilp32 -o $@ $^ -T riscv.ld
	chmod -x firmware_wide_vec.elf
	$(RISCV_TOOLS_PREFIX)objdump -D $@ > firmware_wide_vec.dis
	$(RISCV_TOOLS_PREFIX)objdump -S $@ > firmware_wide_vec.asm

benchmark_wide_vec.o: benchmark_wide_vec.c weights/mnist_weights_int8.h weights/test_data.h
	$(CC) -c $(CFLAGS) -o $@ $<

# SEW Comparison benchmark
firmware32_sew_compare.hex: firmware_sew_compare.elf start.elf hex8tohex32.py
	$(OBJCOPY) -O verilog start.elf start.tmp
	$(OBJCOPY) -O verilog firmware_sew_compare.elf firmware.tmp
	cat start.tmp firmware.tmp > firmware.hex
	python3 hex8tohex32.py firmware.hex > firmware32_sew_compare.hex
	rm -f start.tmp firmware.tmp

firmware_sew_compare.elf: benchmark_sew_compare.o syscalls.o
	$(CC) $(LDFLAGS) -march=rv32im -mabi=ilp32 -o $@ $^ -T riscv.ld
	chmod -x firmware_sew_compare.elf
	$(RISCV_TOOLS_PREFIX)objdump -D $@ > firmware_sew_compare.dis
	$(RISCV_TOOLS_PREFIX)objdump -S $@ > firmware_sew_compare.asm

benchmark_sew_compare.o: benchmark_sew_compare.c
	$(CC) -c $(CFLAGS) -o $@ $<

# MNIST SEW comparison benchmark
firmware32_mnist_sew.hex: firmware_mnist_sew.elf start.elf hex8tohex32.py
	$(OBJCOPY) -O verilog start.elf start.tmp
	$(OBJCOPY) -O verilog firmware_mnist_sew.elf firmware.tmp
	cat start.tmp firmware.tmp > firmware.hex
	python3 hex8tohex32.py firmware.hex > firmware32_mnist_sew.hex
	rm -f start.tmp firmware.tmp

firmware_mnist_sew.elf: benchmark_mnist_sew.o syscalls.o
	$(CC) $(LDFLAGS) -march=rv32im -mabi=ilp32 -o $@ $^ -T riscv.ld
	chmod -x firmware_mnist_sew.elf
	$(RISCV_TOOLS_PREFIX)objdump -D $@ > firmware_mnist_sew.dis
	$(RISCV_TOOLS_PREFIX)objdump -S $@ > firmware_mnist_sew.asm

benchmark_mnist_sew.o: benchmark_mnist_sew.c weights/mnist_weights_int8.h weights/test_data.h
	$(CC) -c $(CFLAGS) -o $@ $<

# Common files
syscalls.o: syscalls.c
	$(CC) -c $(CFLAGS) -o $@ $<

start.elf: start.S start.ld
	$(CC) -march=rv32im -mabi=ilp32 -nostdlib -o start.elf start.S -T start.ld
	chmod -x start.elf
	$(RISCV_TOOLS_PREFIX)objdump -D start.elf > start.dis

clean:
	rm -f *.o *.d *.tmp start.elf
	rm -f firmware_int32.elf firmware_float.elf firmware_matmul.elf firmware.hex
	rm -f firmware_pvmac.elf firmware_wide_vec.elf firmware_sew_compare.elf
	rm -f firmware32_int32.hex firmware32_float.hex firmware32_matmul.hex
	rm -f firmware32_pvmac.hex firmware32_wide_vec.hex firmware32_sew_compare.hex
	rm -f *.dis *.asm

-include *.d
.PHONY: all clean
