// Macro to write a value to a CSR (Control and Status Register)
// Usage: write_csr(csr_name, value)
// Example: write_csr(mstatus, 0x1800)
#define write_csr(csr, val) ({ \
    asm volatile ("csrw " #csr ", %0" :: "r"((int)(val))); \
})

// Macro to read a value from a CSR (Control and Status Register)
// Usage: int value = read_csr(csr_name)
// Example: int status = read_csr(mstatus)
#define read_csr(csr) ({ \
    int __value; \
    asm volatile ("csrr %0, " #csr : "=r"(__value)); \
    __value; \
})

extern int putchar(char c);
extern char getchar(void);
extern void puts(const char *s);
extern void ebreak();
extern void fflush();
extern void insn_tests(void);
extern int printint(int xx, int base, int sgn);
extern int printf(char *fmt, ...);
extern void trap_vector();
extern void illegal_instruction();
extern void ecall();
extern void init_trap();
extern void set_timer(int ticks_lower, int ticks_upper);
extern void read_timer(int *ticks_lower, int *ticks_upper);
extern void clear_timer(void);
extern int  pvadd(int a, int b);
extern int pvmul(int a, int b);
extern int  pvmul_upper(int a, int b);
extern int  pvmac(int a, int b);

