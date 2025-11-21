// External assembly function
extern void putchar(char c);

void puts(const char *s) {
    while (*s) {
        putchar(*s);
        s++;
    }
    putchar('\n');
}


// Simple printf for integers and strings
void
printint(int xx, int base, int sgn)
{
    static char digits[] = "0123456789ABCDEF";
    char buf[16];
    int i, neg;
    int x;

    neg = 0;
    if (sgn && xx < 0) {
        neg = 1;
        x = -xx;
    } else {
        x = xx;
    }

    i = 0;
    do {
        buf[i++] = digits[x % base];
    } while ((x /= base) != 0);

    if (neg)
        buf[i++] = '-';

    while (--i >= 0)
        putchar(buf[i]);
}

void
printf(char *fmt, ...)
{
    __builtin_va_list ap;
    char *s;
    int c;

    __builtin_va_start(ap, fmt);

    for (int i = 0; (c = fmt[i] & 0xff) != 0; i++) {
        if (c != '%') {
            putchar(c);
            continue;
        }
        c = fmt[++i] & 0xff;
        if (c == 0)
            break;
        switch (c) {
        case 'd':
            printint(__builtin_va_arg(ap, int), 10, 1);
            break;
        case 'x':
        case 'p':
            printint(__builtin_va_arg(ap, int), 16, 0);
            break;
        case 's':
            s = __builtin_va_arg(ap, char*);
            if (s == 0)
                s = "(null)";
            for (; *s; s++)
                putchar(*s);
            break;
        case '%':
            putchar('%');
            break;
        default:
            // Print unknown % sequence to aid debugging
            putchar('%');
            putchar(c);
            break;
        }
    }

    __builtin_va_end(ap);
}
