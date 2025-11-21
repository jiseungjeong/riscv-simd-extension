RISCV_TOOLS_PREFIX = riscv64-unknown-elf-
CXX = $(RISCV_TOOLS_PREFIX)g++
CC = $(RISCV_TOOLS_PREFIX)gcc
AS = $(RISCV_TOOLS_PREFIX)gcc
CXXFLAGS = -MD -Os -Wall -std=c++11
CFLAGS = -MD -Os -Wall -std=c++11
LDFLAGS = -Wl,--gc-sections -Wl,-m,elf32lriscv
LDLIBS = -lstdc++

test: testbench.vvp firmware32.hex
	vvp -N testbench.vvp

testbench.vvp: testbench.v ../../picorv32.v
	iverilog -o testbench.vvp testbench.v ../../picorv32.v
	chmod -x testbench.vvp

firmware.bin: firmware.elf
	riscv64-unknown-elf-objcopy -O binary $< $@


firmware32.hex: firmware.elf start.elf hex8tohex32.py
	$(RISCV_TOOLS_PREFIX)objcopy -O verilog start.elf start.tmp
	$(RISCV_TOOLS_PREFIX)objcopy -O verilog firmware.elf firmware.tmp
	cat start.tmp firmware.tmp > firmware.hex
	python3 hex8tohex32.py firmware.hex > firmware32.hex
	rm -f start.tmp firmware.tmp

firmware.elf: firmware.o syscalls.o
	$(CC) $(LDFLAGS) -march=rv32im -mabi=ilp32 -o $@ $^ -T riscv.ld $(LDLIBS)
	chmod -x firmware.elf

%.o : %.c
	$(CC) -c $(CFLAGS) -march=rv32im -mabi=ilp32 -o $@ $<

%.o : %.cc
	$(CXX) -c $(CXXFLAGS) -march=rv32im -mabi=ilp32 -o $@ $<


start.elf: start.S start.ld
	$(CC) -march=rv32im -mabi=ilp32 -nostdlib -o start.elf start.S -T start.ld $(LDLIBS)
	chmod -x start.elf

clean:
	rm -f *.o *.d *.tmp start.elf
	rm -f firmware.elf firmware.hex firmware32.hex
	rm -f testbench.vvp testbench.vcd

-include *.d
.PHONY: test clean
