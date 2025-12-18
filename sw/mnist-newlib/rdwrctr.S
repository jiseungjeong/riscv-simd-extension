# RDWRCTR performance counter functions
# Encoding: opcode=0x5B, funct3=000, rd=a0(x10), rs1=x0
# imm[1:0] = counter_id (00=cycle, 01=insn, 10=load, 11=store)
# imm[11] = wen (0=read, 1=write)

.globl read_cycle_counter
read_cycle_counter:
    .word 0x0000055B    # rdwrctr a0, x0, 0 (read cycle counter)
    ret

.globl read_insn_counter
read_insn_counter:
    .word 0x0010055B    # rdwrctr a0, x0, 1 (read insn counter)
    ret

.globl read_load_counter
read_load_counter:
    .word 0x0020055B    # rdwrctr a0, x0, 2 (read load counter)
    ret

.globl read_store_counter
read_store_counter:
    .word 0x0030055B    # rdwrctr a0, x0, 3 (read store counter)
    ret

.globl write_cycle_counter
write_cycle_counter:
    # a0 = value to write
    .word 0x8005005B    # rdwrctr x0, a0, 0x800 (write cycle counter)
    ret

