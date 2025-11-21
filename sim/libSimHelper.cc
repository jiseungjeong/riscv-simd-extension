#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>

extern uint8_t imem[0x1000000];

void init() {
  uint32_t ebreak = 0x00100073;
  for(int i = 0; i < 0x1000000; i+=4) {
    imem[i + 0] = (ebreak >> 0) & 0xFF;
    imem[i + 1] = (ebreak >> 8) & 0xFF;
    imem[i + 2] = (ebreak >> 16) & 0xFF;
    imem[i + 3] = (ebreak >> 24) & 0xFF;
  }
}

void print_imem(int size) {
  if (size <= 0 || size > 0x1000000) {
    fprintf(stderr, "Invalid size for print_imem: %d\n", size);
    return;
  }

  // Create temporary binary file with imem contents
  char tmpfile[] = "/tmp/imem_XXXXXX";
  int fd = mkstemp(tmpfile);
  if (fd == -1) {
    fprintf(stderr, "Error: Cannot create temporary file\n");
    return;
  }
  write(fd, imem, size);
  close(fd);

  // Create temporary output file for objdump
  char outfile[] = "/tmp/objdump_XXXXXX";
  int out_fd = mkstemp(outfile);
  if (out_fd == -1) {
    fprintf(stderr, "Error: Cannot create output file\n");
    unlink(tmpfile);
    return;
  }
  close(out_fd);

  // Disassemble using riscv64-unknown-elf-objdump with rv32i, no pseudo, numeric register names
  char cmd[512];
  snprintf(cmd, sizeof(cmd),
           "riscv64-unknown-elf-objdump -b binary -m riscv:rv32 -M no-aliases,numeric -D %s > %s",
           tmpfile, outfile);
  system(cmd);

  // Read and print disassembly
  printf("Instruction memory contents (loaded %d bytes):\n", size);
  FILE* fp = fopen(outfile, "r");
  if (fp) {
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
      // Only print lines with instruction addresses (format: "   0:  ...")
      if (strstr(line, ":") && line[0] == ' ') {
        printf("%s", line);
      }
    }
    fclose(fp);
  }

  unlink(tmpfile);
  unlink(outfile);
}

int validate_and_load_binary(const char* bin_filename, const char* disasm_filename,
                              uint8_t* buffer, size_t buffer_size) {
    // Load Verilog hex file format
    FILE* hex_fp = fopen(bin_filename, "r");
    if (!hex_fp) {
        fprintf(stderr, "Error: Cannot open hex file %s\n", bin_filename);
        return -1;
    }

    char line[256];
    uint32_t current_addr = 0;
    uint32_t max_addr = 0;
    int line_num = 0;

    while (fgets(line, sizeof(line), hex_fp)) {
        line_num++;
        // Skip empty lines and comments
        if (line[0] == '\n' || line[0] == '\r' || line[0] == '#' || line[0] == '/') {
            continue;
        }

        // Check for address directive
        if (line[0] == '@') {
            if (sscanf(line + 1, "%x", &current_addr) != 1) {
                fprintf(stderr, "Error: Invalid address directive on line %d: %s", line_num, line);
                fclose(hex_fp);
                return -1;
            }
            continue;
        }

        // Parse hex data (can be space or newline separated)
        char* ptr = line;
        while (*ptr) {
            // Skip whitespace
            while (*ptr == ' ' || *ptr == '\t' || *ptr == '\r' || *ptr == '\n') {
                ptr++;
            }
            if (*ptr == '\0') break;

            // Parse hex value (either 2 digits for byte or 8 digits for word)
            uint32_t value;
            int chars_read = 0;

            // Try to read as many hex digits as possible
            if (sscanf(ptr, "%x%n", &value, &chars_read) == 1 && chars_read > 0) {
                // Determine size based on number of hex digits
                int num_hex_digits = chars_read;
                // Count actual hex digits (not including 0x prefix if present)
                char* hex_start = ptr;
                if (hex_start[0] == '0' && (hex_start[1] == 'x' || hex_start[1] == 'X')) {
                    hex_start += 2;
                    num_hex_digits = chars_read - 2;
                }

                int bytes_to_write;
                if (num_hex_digits <= 2) {
                    bytes_to_write = 1;  // Byte
                } else if (num_hex_digits <= 4) {
                    bytes_to_write = 2;  // Half-word
                } else {
                    bytes_to_write = 4;  // Word
                }

                // Check bounds
                if (current_addr + bytes_to_write > buffer_size) {
                    fprintf(stderr, "Error: Address 0x%x exceeds buffer size\n", current_addr);
                    fclose(hex_fp);
                    return -1;
                }

                // Write in little-endian format
                for (int i = 0; i < bytes_to_write; i++) {
                    buffer[current_addr + i] = (value >> (i * 8)) & 0xFF;
                }

                current_addr += bytes_to_write;
                if (current_addr > max_addr) {
                    max_addr = current_addr;
                }

                ptr += chars_read;
            } else {
                // Skip invalid character
                ptr++;
            }
        }
    }

    fclose(hex_fp);

    if (max_addr == 0) {
        fprintf(stderr, "Error: No data found in hex file\n");
        return -1;
    }

    printf("Loaded hex file: %d bytes (0x%x)\n", max_addr, max_addr);
    return (int)max_addr;
}

int load_elf(const char* filename, uint8_t* buffer, size_t buffer_size) {
    char cmd[512];
    char tmpfile[] = "/tmp/text_section_XXXXXX";
    int fd = mkstemp(tmpfile);
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);
    if (fd == -1) {
        fprintf(stderr, "Error: Cannot create temporary file\n");
        return -1;
    }
    close(fd);
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);
    // Check if _start is at address 0 using nm
    char nm_tmpfile[] = "/tmp/nm_output_XXXXXX";
    int nm_fd = mkstemp(nm_tmpfile);
    if (nm_fd == -1) {
        fprintf(stderr, "Error: Cannot create nm output file\n");
        unlink(tmpfile);
        return -1;
    }
    close(nm_fd);

    snprintf(cmd, sizeof(cmd), "riscv64-unknown-elf-nm %s > %s 2>&1", filename, nm_tmpfile);
    system(cmd);
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);

    FILE* nm_file = fopen(nm_tmpfile, "r");
    if (!nm_file) {
        fprintf(stderr, "Error: Cannot open nm output file\n");
        unlink(tmpfile);
        unlink(nm_tmpfile);
        return -1;
    }

    char line[256];
    uint32_t start_addr = 0xFFFFFFFF;
    int found_start = 0;
    while (fgets(line, sizeof(line), nm_file)) {
        if (strstr(line, "_start")) {
            if (sscanf(line, "%x", &start_addr) == 1) {
                found_start = 1;
                break;
            }
        }
    }
    fclose(nm_file);
    unlink(nm_tmpfile);
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);


    if (!found_start) {
        fprintf(stderr, "Error: _start symbol not found\n");
        unlink(tmpfile);
        return -1;
    }
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);

    if (start_addr != 0) {
        fprintf(stderr, "Error: _start is at address 0x%x, not at address 0\n", start_addr);
        unlink(tmpfile);
        return -1;
    }
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);

    // Extract .text section using objcopy
    snprintf(cmd, sizeof(cmd), "riscv64-unknown-elf-objcopy -O binary --only-section=.text %s %s",
             filename, tmpfile);
    if (system(cmd) != 0) {
        fprintf(stderr, "Error: Cannot extract .text section\n");
        unlink(tmpfile);
        return -1;
    }
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);

    // Read the extracted .text section
    FILE* fp = fopen(tmpfile, "rb");
    if (!fp) {
        fprintf(stderr, "Error: Cannot open temporary file\n");
        unlink(tmpfile);
        return -1;
    }
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);

    fseek(fp, 0, SEEK_END);
    size_t text_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);

    if (text_size == 0 || text_size % 4 != 0) {
        fprintf(stderr, "Error: Invalid .text section size\n");
        fclose(fp);
        unlink(tmpfile);
        return -1;
    }
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);

    if (text_size > buffer_size) {
        fprintf(stderr, "Error: Text section size %zu exceeds buffer size %zu\n", text_size, buffer_size);
        fclose(fp);
        unlink(tmpfile);
        return -1;
    }

    if (fread(buffer, 1, text_size, fp) != text_size) {
        fprintf(stderr, "Error: Cannot read instructions\n");
        fclose(fp);
        unlink(tmpfile);
        return -1;
    }
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);

    fclose(fp);
    unlink(tmpfile);
    printf("Loading ELF file: %s:%d\n", __FILE__, __LINE__);

    // Print instructions
    printf("Loaded %zu bytes:\n", text_size);
    for (size_t i = 0; i < text_size; i += 4) {
        uint32_t instr = buffer[i] | (buffer[i+1] << 8) | (buffer[i+2] << 16) | (buffer[i+3] << 24);
        printf("0x%08x: 0x%08x\n", (uint32_t)i, instr);
    }

    return (int)text_size;
}