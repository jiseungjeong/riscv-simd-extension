CC = gcc
CFLAGS = -O2 -Wall -Wextra -std=c99
LDFLAGS = -lm

WEIGHTS_DIR = weights

.PHONY: all clean run

all: benchmark_int8_relu benchmark_int32_relu

benchmark_int8_relu: benchmark_int8_relu.c $(WEIGHTS_DIR)/mnist_weights_int8_relu.h $(WEIGHTS_DIR)/test_data_int8_relu.h
	$(CC) $(CFLAGS) -I. -o $@ $< $(LDFLAGS)

benchmark_int32_relu: benchmark_int32_relu.c $(WEIGHTS_DIR)/mnist_weights_int32_relu.h $(WEIGHTS_DIR)/test_data.h
	$(CC) $(CFLAGS) -I. -o $@ $< $(LDFLAGS)

run: all
	./benchmark_int8_relu
	./benchmark_int32_relu

clean:
	rm -f benchmark_int8_relu benchmark_int32_relu
