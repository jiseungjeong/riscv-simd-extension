.global trap_vector
trap_vector:
    // ============================================================================
    // SAVE ALL REGISTERS (31 registers, 124 bytes)
    // We save all registers except x0 (hardwired zero)
    // ============================================================================
    addi sp, sp, -124       // Allocate stack space for 31 registers (31*4 = 124 bytes)

    // Save x1-x31 (skip x0 as it's always zero)
    sw x1,  0(sp)           // x1  = ra (return address)
    // Note: x2 = sp, we'll save the ORIGINAL sp value later
    sw x3,  8(sp)           // x3  = gp (global pointer)
    sw x4,  12(sp)          // x4  = tp (thread pointer)
    sw x5,  16(sp)          // x5  = t0 (temporary 0)
    sw x6,  20(sp)          // x6  = t1 (temporary 1)
    sw x7,  24(sp)          // x7  = t2 (temporary 2)
    sw x8,  28(sp)          // x8  = s0/fp (saved register 0 / frame pointer)
    sw x9,  32(sp)          // x9  = s1 (saved register 1)
    sw x10, 36(sp)          // x10 = a0 (argument/return 0)
    sw x11, 40(sp)          // x11 = a1 (argument/return 1)
    sw x12, 44(sp)          // x12 = a2 (argument 2)
    sw x13, 48(sp)          // x13 = a3 (argument 3)
    sw x14, 52(sp)          // x14 = a4 (argument 4)
    sw x15, 56(sp)          // x15 = a5 (argument 5)
    sw x16, 60(sp)          // x16 = a6 (argument 6)
    sw x17, 64(sp)          // x17 = a7 (argument 7)
    sw x18, 68(sp)          // x18 = s2 (saved register 2)
    sw x19, 72(sp)          // x19 = s3 (saved register 3)
    sw x20, 76(sp)          // x20 = s4 (saved register 4)
    sw x21, 80(sp)          // x21 = s5 (saved register 5)
    sw x22, 84(sp)          // x22 = s6 (saved register 6)
    sw x23, 88(sp)          // x23 = s7 (saved register 7)
    sw x24, 92(sp)          // x24 = s8 (saved register 8)
    sw x25, 96(sp)          // x25 = s9 (saved register 9)
    sw x26, 100(sp)         // x26 = s10 (saved register 10)
    sw x27, 104(sp)         // x27 = s11 (saved register 11)
    sw x28, 108(sp)         // x28 = t3 (temporary 3)
    sw x29, 112(sp)         // x29 = t4 (temporary 4)
    sw x30, 116(sp)         // x30 = t5 (temporary 5)
    sw x31, 120(sp)         // x31 = t6 (temporary 6)

    // Save original stack pointer (sp before trap)
    addi t0, sp, 124        // Calculate original sp
    sw t0, 4(sp)            // Save original sp at offset 4

    // ============================================================================
    // HANDLE TRAP
    // ============================================================================
    // TODO: Add your trap handling code here
    // You can read mcause CSR to determine the trap cause
    // You can read mepc CSR to get the faulting instruction address
    // For now, this is just a placeholder

    // Example: Infinite loop (replace with actual trap handling)
    jal trap_entry
    
    // ============================================================================
    // RESTORE ALL REGISTERS
    // ============================================================================
trap_return:
    // Restore x3-x31 (we'll restore x1 and x2 last)
    lw x3,  8(sp)           // x3  = gp (global pointer)
    lw x4,  12(sp)          // x4  = tp (thread pointer)
    lw x5,  16(sp)          // x5  = t0 (temporary 0)
    lw x6,  20(sp)          // x6  = t1 (temporary 1)
    lw x7,  24(sp)          // x7  = t2 (temporary 2)
    lw x8,  28(sp)          // x8  = s0/fp (saved register 0 / frame pointer)
    lw x9,  32(sp)          // x9  = s1 (saved register 1)
    lw x10, 36(sp)          // x10 = a0 (argument/return 0)
    lw x11, 40(sp)          // x11 = a1 (argument/return 1)
    lw x12, 44(sp)          // x12 = a2 (argument 2)
    lw x13, 48(sp)          // x13 = a3 (argument 3)
    lw x14, 52(sp)          // x14 = a4 (argument 4)
    lw x15, 56(sp)          // x15 = a5 (argument 5)
    lw x16, 60(sp)          // x16 = a6 (argument 6)
    lw x17, 64(sp)          // x17 = a7 (argument 7)
    lw x18, 68(sp)          // x18 = s2 (saved register 2)
    lw x19, 72(sp)          // x19 = s3 (saved register 3)
    lw x20, 76(sp)          // x20 = s4 (saved register 4)
    lw x21, 80(sp)          // x21 = s5 (saved register 5)
    lw x22, 84(sp)          // x22 = s6 (saved register 6)
    lw x23, 88(sp)          // x23 = s7 (saved register 7)
    lw x24, 92(sp)          // x24 = s8 (saved register 8)
    lw x25, 96(sp)          // x25 = s9 (saved register 9)
    lw x26, 100(sp)         // x26 = s10 (saved register 10)
    lw x27, 104(sp)         // x27 = s11 (saved register 11)
    lw x28, 108(sp)         // x28 = t3 (temporary 3)
    lw x29, 112(sp)         // x29 = t4 (temporary 4)
    lw x30, 116(sp)         // x30 = t5 (temporary 5)
    addi  t0, x0, 0x8
    csrrw x0, 0x300, t0   # set mstatus MIE bit
    lw x31, 120(sp)         // x31 = t6 (temporary 6)
    // Restore x1 (ra)
    lw x1,  0(sp)           // x1  = ra (return address)

    // Restore stack pointer (x2)
    addi sp, sp, 124        // Deallocate stack frame

    // Return from trap (using mret for machine mode)
    mret



.global ecall
ecall:
    ecall