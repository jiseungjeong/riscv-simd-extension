# Hardware Abstraction Layer for Exercise 5.1
# Custom instructions for cycle counter access

.global pvadd
pvadd:
   // pvadd a0, a0, a1
   // pvadd x10, x10, x11
   // 0000000 01011 01010 001 01010 1011011
   // 0000 0000 1011 0101 0001 0101 0101 1011
   // 00B5155B
   .word 0x00B5155B
   // pvadd a0, a0, a1
   ret

.global pvmul
pvmul:
    // pvmul a0, a0, a0
    // pvmul x10, x10, x11
    // 0000001 01011 01010 001 01010 1011011
    // 0000 0010 1011 0101 0001 0101 0101 1011
    // 02B5155B
    .word 0x02B5155B
    // pvmul a0, a0, a1
    ret

.global pvmul_upper
pvmul_upper:
    // pvmul.upper a0, a0, a1
    // pvmul.upper x10, x10, x11
    // 0000011 01011 01010 001 01010 1011011
    // 0000 0110 1011 0101 0001 0101 0101 1011
    // 06B5155B
    .word 0x06B5155B
    // pvmul_upper a0, a0, a1
    
    ret

.global pvmac
pvmac:
    // pvmac a0, a0, a1
    // pvmac x10, x10, x11
    // 0000010 01011 01010 001 01010 1011011
    // 0000 0100 1011 0101 0001 0101 0101 1011
    // 02B5155B
    .word 0x04B5155B
    // pvmac a0, a0, a1
    ret


.global illegal_instruction
illegal_instruction:
  .word 0x00000000  // This will cause an illegal instruction exception

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


.global getchar
getchar:
  lui  x31, 0x10000
getchar_wait:
  lh   t0, 0x4(x31)
  sra  t1, t0, 8
  beq  t1, zero, getchar_wait
  andi a0, t0, 0xFF
  ret

.global putchar
putchar:
  lui  x31, 0x10000
  sb   a0, 0(x31)
  addi a0, x0, 0
  ret

.global fflush
fflush:
  lui  x31, 0x10000
fflush_wait:
  lb   t0, 0x8(x31)
  bne  t0, zero, fflush_wait
  addi a0, x0, 0
  ret



.global ebreak
ebreak:
  ebreak
halt:
  j halt


.global set_timer
set_timer:
    lui   t0, 0x20000
    sw    a0, 8(t0)
    sw    a1, 12(t0)
    ret

.global read_timer
read_timer:
    lui   t0, 0x20000
    lw    t1, 8(t0)
    lw    t2, 12(t0)
    sw    t1, 0(a0)
    sw    t2, 0(a1)
    ret

.global clear_timer
clear_timer:
    lui   t0, 0x20000
    sw    zero, 8(t0)
    sw    zero, 12(t0)
    ret
