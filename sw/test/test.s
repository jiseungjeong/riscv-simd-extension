	.text
	.attribute	4, 16
	.attribute	5, "rv32i2p1_m2p0"
	.file	"test_pvmac_pattern.c"
	.option	push
	.option	arch, +m
	.globl	test_pattern_exact              # -- Begin function test_pattern_exact
	.p2align	2
	.type	test_pattern_exact,@function
test_pattern_exact:                     # @test_pattern_exact
# %bb.0:                                # %entry
	mul	a2, a1, a0
	andi	a2, a2, 255
	slli	a3, a0, 16
	srai	a3, a3, 24
	slli	a4, a1, 16
	srai	a4, a4, 24
	mul	a3, a4, a3
	lui	a4, 16
	addi	a4, a4, -256
	and	a3, a3, a4
	slli	a4, a0, 8
	srai	a4, a4, 24
	slli	a5, a1, 8
	srai	a5, a5, 24
	mul	a4, a5, a4
	lui	a5, 4080
	and	a4, a4, a5
	srai	a0, a0, 24
	srai	a1, a1, 24
	mul	a0, a1, a0
	lui	a1, 1044480
	and	a0, a0, a1
	or	a0, a0, a2
	or	a0, a0, a3
	or	a0, a0, a4
	ret
.Lfunc_end0:
	.size	test_pattern_exact, .Lfunc_end0-test_pattern_exact
                                        # -- End function
	.option	pop
	.option	push
	.option	arch, +m
	.globl	test_pattern_simple             # -- Begin function test_pattern_simple
	.p2align	2
	.type	test_pattern_simple,@function
test_pattern_simple:                    # @test_pattern_simple
# %bb.0:                                # %entry
	mul	a2, a1, a0
	andi	a2, a2, 255
	slli	a3, a0, 16
	srai	a3, a3, 24
	slli	a4, a1, 16
	srai	a4, a4, 24
	mul	a3, a4, a3
	lui	a4, 16
	addi	a4, a4, -256
	and	a3, a3, a4
	slli	a4, a0, 8
	srai	a4, a4, 24
	slli	a5, a1, 8
	srai	a5, a5, 24
	mul	a4, a5, a4
	lui	a5, 4080
	and	a4, a4, a5
	srai	a0, a0, 24
	srai	a1, a1, 24
	mul	a0, a1, a0
	lui	a1, 1044480
	and	a0, a0, a1
	or	a0, a0, a2
	or	a0, a0, a3
	or	a0, a0, a4
	ret
.Lfunc_end1:
	.size	test_pattern_simple, .Lfunc_end1-test_pattern_simple
                                        # -- End function
	.option	pop
	.ident	"clang version 18.1.8 (ssh://git@elsa.unist.ac.kr:4001/teaching/cse302-admin.git a167157865ac067d53ca67580a4ac220b9eb54c3)"
	.section	".note.GNU-stack","",@progbits
