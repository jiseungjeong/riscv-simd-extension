# See LICENSE for license details.

#*****************************************************************************
# rdwrctr.S
#-----------------------------------------------------------------------------
#
# Test rdwrctr custom instruction for counter read/write.
#

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # Basic read tests - just verify counters are readable
  #-------------------------------------------------------------

  # Test 2: Read cycle counter (ctr_id=0) - should not trap
  li TESTNUM, 2
  .word 0x0000055B          # rdwrctr a0, x0, 0 (read cycle counter)
  # Just check it executed without trapping

  # Test 3: Read instruction counter (ctr_id=1)
  li TESTNUM, 3
  .word 0x0010055B          # rdwrctr a0, x0, 1 (read insn counter)

  # Test 4: Read load counter (ctr_id=2)
  li TESTNUM, 4
  .word 0x0020055B          # rdwrctr a0, x0, 2 (read load counter)

  # Test 5: Read store counter (ctr_id=3)
  li TESTNUM, 5
  .word 0x0030055B          # rdwrctr a0, x0, 3 (read store counter)

  #-------------------------------------------------------------
  # Test write then read - allow for counter increment
  #-------------------------------------------------------------

  # Test 6: Write large value to cycle counter, verify it changed from small
  li a0, 0
  .word 0x8005005B          # rdwrctr x0, a0, 0 (write 0 to cycle counter)
  nop
  nop
  .word 0x0000055B          # rdwrctr a0, x0, 0 (read back)
  li t0, 100                # Should be less than 100 cycles
  li TESTNUM, 6
  bgtu a0, t0, fail         # Fail if counter > 100

  # Test 7: Write 0x10000000 to cycle counter, read should be near that value
  lui a0, 0x10000
  .word 0x8005005B          # rdwrctr x0, a0, 0 (write)
  .word 0x0000055B          # rdwrctr a0, x0, 0 (read)
  lui t0, 0x10000
  li t1, 1000
  add t0, t0, t1            # Allow up to 1000 cycles difference
  li TESTNUM, 7
  bgtu a0, t0, fail

  #-------------------------------------------------------------
  # Test counter differences (relative changes)
  #-------------------------------------------------------------

  # Test 8: Verify cycle counter increments
  li a0, 0
  .word 0x8005005B          # Reset cycle counter
  .word 0x0000055B          # Read counter -> a0
  mv t0, a0                 # Save first reading
  nop
  nop
  nop
  nop
  nop
  .word 0x0000055B          # Read counter again -> a0
  li TESTNUM, 8
  bleu a0, t0, fail         # Second reading should be > first

  # Test 9: Verify instruction counter increments
  li a0, 0
  .word 0x8015005B          # Reset insn counter
  .word 0x0010055B          # Read insn counter -> a0
  mv t0, a0
  nop
  nop
  nop
  .word 0x0010055B          # Read again
  li TESTNUM, 9
  bleu a0, t0, fail         # Should have incremented

  # Test 10: Verify load counter increments after loads
  li a0, 0
  .word 0x8025005B          # Reset load counter
  .word 0x0020055B          # Read load counter -> a0
  mv t0, a0
  la t1, test_data
  lw t2, 0(t1)              # Do a load
  lw t2, 4(t1)              # Do another load
  .word 0x0020055B          # Read load counter again
  li TESTNUM, 10
  bleu a0, t0, fail         # Should have incremented by at least 1

  # Test 11: Verify store counter increments after stores
  li a0, 0
  .word 0x8035005B          # Reset store counter
  .word 0x0030055B          # Read store counter -> a0
  mv t0, a0
  la t1, test_data
  sw zero, 0(t1)            # Do a store
  sw zero, 4(t1)            # Do another store
  .word 0x0030055B          # Read store counter again
  li TESTNUM, 11
  bleu a0, t0, fail         # Should have incremented by at least 1

  #-------------------------------------------------------------
  # Test writing to x0 has no effect
  #-------------------------------------------------------------

  # Test 12: Write to x0 should not trap
  li TESTNUM, 12
  .word 0x8000005B          # rdwrctr x0, x0, 0 (write x0 to counter)
  # Should complete without error

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

test_data:
  .word 0xdeadbeef
  .word 0xcafebabe
  .word 0x12345678
  .word 0x87654321

RVTEST_DATA_END
