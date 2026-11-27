CC      ?= gcc
CFLAGS  ?= -O2 -g -std=c11 -Wall -Wextra
# the assembler lives in the repo-level scripts/ directory
HACKASM ?= $(abspath ../scripts/hackasm.py)

all: hackemu hackdbg

hackemu: hackemu.o hack.o hackmap.o
	$(CC) $(CFLAGS) -o $@ $^

hackdbg: hackdbg.o hack.o hackmap.o
	$(CC) $(CFLAGS) -o $@ $^ -lncursesw

%.o: %.c hack.h hackmap.h
	$(CC) $(CFLAGS) -c -o $@ $<

TESTFLAGS ?=

test: hackemu
	HACKASM=$(HACKASM) python3 -m unittest discover -s tests $(TESTFLAGS)

clean:
	rm -f hackemu hackdbg *.o

.PHONY: all test clean
