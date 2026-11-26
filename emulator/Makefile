CC      ?= gcc
CFLAGS  ?= -O2 -g -std=c11 -Wall -Wextra
# hackasm.py lives next to this directory by default
HACKASM ?= $(abspath ../scripts/hackasm.py)

all: hackemu

hackemu: hackemu.o hack.o hackmap.o
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c hack.h hackmap.h
	$(CC) $(CFLAGS) -c -o $@ $<

test: hackemu
	HACKASM=$(HACKASM) python3 tests/test_emu.py

clean:
	rm -f hackemu *.o

.PHONY: all test clean
