/* hack.h -- Hack CPU core.  No I/O, no UI: just state and step().
 *
 * Memory map (RAM, 16-bit words):
 *   0 .. 16383      data RAM (R0-R15, SP/LCL/ARG/THIS/THAT, statics, heap, stack)
 *   16384 .. 24575  screen: 512x256 1-bit, 32 words per row, LSB = leftmost pixel
 *   24576           keyboard (read-only; whoever drives the keyboard writes it)
 *
 * Semantics follow the hardware: M and the jump target both use the value of A
 * *before* the instruction (so "AM=A+1" writes RAM[old A]); jumps compare the
 * ALU output as a signed 16-bit value.
 */
#ifndef HACK_H
#define HACK_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define HACK_ROM_WORDS 32768
#define HACK_RAM_WORDS 24577            /* 0..24575 plus the keyboard word */
#define HACK_SCREEN    16384
#define HACK_KBD       24576
#define HACK_SCREEN_W  512
#define HACK_SCREEN_H  256

typedef enum {
    HACK_OK = 0,
    HACK_STOP_HALT,        /* executed the "(END) @END 0;JMP" idiom             */
    HACK_STOP_BREAK,       /* hack_run() reached a breakpoint                   */
    HACK_STOP_MAX,         /* hack_run() used up its step budget                */
    HACK_STOP_END,         /* PC ran past the end of the loaded program         */
    HACK_ERR_BAD_INSTR,    /* bit 15 set but bits 14:13 are not 11              */
    HACK_ERR_BAD_ADDR      /* M accessed while A > 24576                        */
} HackStatus;

typedef struct { bool valid; uint16_t addr, old, val; } HackWrite;

typedef struct Hack {
    uint16_t  rom[HACK_ROM_WORDS];
    uint32_t  rom_len;                  /* number of loaded instructions        */
    uint16_t *ram;                      /* HACK_RAM_WORDS entries               */
    bool      ram_owned;
    uint16_t  pc, a, d;
    uint64_t  cycles;
    uint32_t  screen_gen;               /* bumped whenever a screen word changes */
    HackWrite wr;                       /* the RAM write done by the last step  */
    uint8_t   bp[HACK_ROM_WORDS / 8];   /* breakpoint bitset, indexed by ROM addr */
} Hack;

/* shared_ram may be NULL (private RAM) or caller-owned memory of
 * HACK_RAM_WORDS words, e.g. a shared-memory block for a separate screen viewer. */
Hack *hack_new(uint16_t *shared_ram);
void  hack_free(Hack *h);

/* PC/A/D/cycles = 0, RAM cleared (keyboard word kept).  ROM and breakpoints kept. */
void  hack_reset(Hack *h);

/* Load a file of ascii 16-bit words.  Tolerates blank lines, // comments,
 * "(LABEL)" lines, an "addr:" prefix and spaces inside a word, so the output of
 * `hackasm.py dis` loads too.  Returns the instruction count, or -1 with a
 * message in err. */
int   hack_load_file(Hack *h, const char *path, char *err, size_t errlen);

/* Execute the instruction at PC.  On an ERR_* status the state is unchanged. */
HackStatus hack_step(Hack *h);

/* Step until a breakpoint (the instruction we start on is never a stop), a halt,
 * an error, or max_steps instructions have run. */
HackStatus hack_run(Hack *h, uint64_t max_steps);

void  hack_set_bp(Hack *h, uint16_t rom_addr, bool on);
bool  hack_has_bp(const Hack *h, uint16_t rom_addr);

static inline void hack_set_key(Hack *h, uint16_t code) { h->ram[HACK_KBD] = code; }
static inline bool hack_pixel(const Hack *h, int x, int y)
{
    return (h->ram[HACK_SCREEN + y * 32 + (x >> 4)] >> (x & 15)) & 1;
}

const char *hack_status_str(HackStatus s);

#endif
