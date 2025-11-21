
  .section .text
  .extern main

reset_vec:
  j start


start:
  addi x1, x0, 0
  addi x2, x0, 0
  addi x3, x0, 0
  addi x4, x0, 0
  addi x5, x0, 0
  addi x6, x0, 0
  addi x7, x0, 0
  addi x8, x0, 0
  addi x9, x0, 0
  addi x10, x0, 0
  addi x11, x0, 0
  addi x12, x0, 0
  addi x13, x0, 0
  addi x14, x0, 0
  addi x15, x0, 0
  addi x16, x0, 0
  addi x17, x0, 0
  addi x18, x0, 0
  addi x19, x0, 0
  addi x20, x0, 0
  addi x21, x0, 0
  addi x22, x0, 0
  addi x23, x0, 0
  addi x24, x0, 0
  addi x25, x0, 0
  addi x26, x0, 0
  addi x27, x0, 0
  addi x28, x0, 0
  addi x29, x0, 0
  addi x30, x0, 0
  addi x31, x0, 0
	addi t0, x0, 0x8
	csrrw x0, 0x300, t0   # set mstatus MIE bit
  lui  sp,  0x0007F      # sp = 0x1000 (4KB) - Start stack at 4KB to avoid aliasing with test code
  jal main

.global insn_tests
insn_tests:
//#ifdef ENABLE_RVTST
#  define TEST(n) \
	.global n; \
	addi x1, zero, 10; \
	jal zero,n; \
	.global n ## _ret; \
	n ## _ret:
//#endif
	auipc x31, %hi(scratch_space)
	addi x31, x31, %lo(scratch_space)
	sw x1,  0(x31)   # save x1
	sw x2,  4(x31)   # save x2 (sp)
	sw x3,  8(x31)   # save x3
	sw x4,  12(x31)  # save x4
	sw x5,  16(x31)  # save x5
	sw x6,  20(x31)  # save x6
	sw x7,  24(x31)  # save x7
	sw x8,  28(x31)  # save x8
	sw x9,  32(x31)  # save x9
	sw x10, 36(x31)  # save x10
	sw x11, 40(x31)  # save x11
	sw x12, 44(x31)  # save x12
	sw x13, 48(x31)  # save x13
	sw x14, 52(x31)  # save x14
	sw x15, 56(x31)  # save x15
	sw x16, 60(x31)  # save x16
	sw x17, 64(x31)  # save x17
	sw x18, 68(x31)  # save x18
	sw x19, 72(x31)  # save x19
	sw x20, 76(x31)  # save x20
	sw x21, 80(x31)  # save x21
	sw x22, 84(x31)  # save x22
	sw x23, 88(x31)  # save x23
	sw x24, 92(x31)  # save x24
	sw x25, 96(x31)  # save x25
	sw x26, 100(x31) # save x26
	sw x27, 104(x31) # save x27
	sw x28, 108(x31) # save x28
	sw x29, 112(x31) # save x29
	sw x30, 116(x31) # save x30

	TEST(lui)
	TEST(auipc)
	TEST(j)
  TEST(jal)
	TEST(jalr)

	TEST(beq)
	TEST(bne)
	TEST(blt)
	TEST(bge)
	TEST(bltu)
	TEST(bgeu)

	TEST(lb)
	TEST(lh)
	TEST(lw)
	TEST(lbu)
	TEST(lhu)

	TEST(sb)
	TEST(sh)
	TEST(sw)

	TEST(addi)
	TEST(slti) 
	TEST(xori)
	TEST(ori)
	TEST(andi)
	TEST(slli)
	TEST(srli)
	TEST(srai)

	TEST(add)
	TEST(sub)
	TEST(sll)
	TEST(slt)
	TEST(xor)
	TEST(srl)
	TEST(sra)
	TEST(or)
	TEST(and)


	TEST(simple)
	TEST(rdwrctr)
	// comment out this to test m extensions.
	j m_tests

break:
  ebreak

repeat:
  sw   x1, 0(x31)
  j    repeat

m_tests:
	TEST(mulh)
	TEST(mulhsu)
	TEST(mulhu)
	TEST(mul)

	TEST(div)
	TEST(divu)
	TEST(rem)
	TEST(remu)
	# Restore all registers
	auipc x31, %hi(scratch_space)
	addi x31, x31, %lo(scratch_space)
	lw x1,  0(x31)   # restore x1
	lw x2,  4(x31)   # restore x2 (sp)
	lw x3,  8(x31)   # restore x3
	lw x4,  12(x31)  # restore x4
	lw x5,  16(x31)  # restore x5
	lw x6,  20(x31)  # restore x6
	lw x7,  24(x31)  # restore x7
	lw x8,  28(x31)  # restore x8
	lw x9,  32(x31)  # restore x9
	lw x10, 36(x31)  # restore x10
	lw x11, 40(x31)  # restore x11
	lw x12, 44(x31)  # restore x12
	lw x13, 48(x31)  # restore x13
	lw x14, 52(x31)  # restore x14
	lw x15, 56(x31)  # restore x15
	lw x16, 60(x31)  # restore x16
	lw x17, 64(x31)  # restore x17
	lw x18, 68(x31)  # restore x18
	lw x19, 72(x31)  # restore x19
	lw x20, 76(x31)  # restore x20
	lw x21, 80(x31)  # restore x21
	lw x22, 84(x31)  # restore x22
	lw x23, 88(x31)  # restore x23
	lw x24, 92(x31)  # restore x24
	lw x25, 96(x31)  # restore x25
	lw x26, 100(x31) # restore x26
	lw x27, 104(x31) # restore x27
	lw x28, 108(x31) # restore x28
	lw x29, 112(x31) # restore x29
	lw x30, 116(x31) # restore x30
	ret

scratch_space:
	.space 256



