#include "hack.h"

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

Hack *hack_new(uint16_t *shared_ram)
{
    Hack *h = calloc(1, sizeof *h);
    if (!h) return NULL;
    if (shared_ram) {
        h->ram = shared_ram;
    } else {
        h->ram = calloc(HACK_RAM_WORDS, sizeof *h->ram);
        if (!h->ram) { free(h); return NULL; }
        h->ram_owned = true;
    }
    return h;
}

void hack_free(Hack *h)
{
    if (!h) return;
    if (h->ram_owned) free(h->ram);
    free(h);
}

void hack_reset(Hack *h)
{
    uint16_t key = h->ram[HACK_KBD];
    memset(h->ram, 0, HACK_RAM_WORDS * sizeof *h->ram);
    h->ram[HACK_KBD] = key;
    h->pc = h->a = h->d = 0;
    h->cycles = 0;
    h->wr.valid = false;
    h->screen_gen++;
}

void hack_set_bp(Hack *h, uint16_t addr, bool on)
{
    addr &= 0x7FFF;
    if (on) h->bp[addr >> 3] |= (uint8_t)(1u << (addr & 7));
    else    h->bp[addr >> 3] &= (uint8_t)~(1u << (addr & 7));
}

bool hack_has_bp(const Hack *h, uint16_t addr)
{
    addr &= 0x7FFF;
    return (h->bp[addr >> 3] >> (addr & 7)) & 1;
}

int hack_load_file(Hack *h, const char *path, char *err, size_t errlen)
{
    FILE *f = fopen(path, "r");
    if (!f) { snprintf(err, errlen, "%s: %s", path, strerror(errno)); return -1; }

    char line[512];
    unsigned lineno = 0;
    uint32_t n = 0;
    static uint16_t tmp[HACK_ROM_WORDS];

    while (fgets(line, sizeof line, f)) {
        lineno++;
        char *p = strstr(line, "//");
        if (p) *p = 0;
        p = line;
        while (isspace((unsigned char)*p)) p++;
        if (!*p || *p == '(') continue;              /* blank or (LABEL) */

        char *q = p;                                  /* optional "addr:" */
        while (isxdigit((unsigned char)*q)) q++;
        if (q > p && *q == ':') p = q + 1;

        uint32_t w = 0;
        int nbits = 0;
        bool bad = false;
        for (; *p; p++) {
            if (*p == '0' || *p == '1') { w = (w << 1) | (uint32_t)(*p - '0'); nbits++; }
            else if (!isspace((unsigned char)*p)) { bad = true; break; }
        }
        if (bad || nbits != 16) {
            snprintf(err, errlen, "%s:%u: expected 16 binary digits", path, lineno);
            fclose(f);
            return -1;
        }
        if (n >= HACK_ROM_WORDS) {
            snprintf(err, errlen, "%s:%u: program exceeds %d instructions",
                     path, lineno, HACK_ROM_WORDS);
            fclose(f);
            return -1;
        }
        tmp[n++] = (uint16_t)w;
    }
    fclose(f);
    memset(h->rom, 0, sizeof h->rom);
    memcpy(h->rom, tmp, n * sizeof tmp[0]);
    h->rom_len = n;
    return (int)n;
}

/* The Hack ALU, as the six control bits zx nx zy ny f no (c1..c6). */
static inline uint16_t alu(uint16_t x, uint16_t y, unsigned c)
{
    if (c & 0x20) x = 0;
    if (c & 0x10) x = (uint16_t)~x;
    if (c & 0x08) y = 0;
    if (c & 0x04) y = (uint16_t)~y;
    uint16_t out = (c & 0x02) ? (uint16_t)(x + y) : (uint16_t)(x & y);
    if (c & 0x01) out = (uint16_t)~out;
    return out;
}

static void ram_write(Hack *h, uint16_t addr, uint16_t v)
{
    if (addr == HACK_KBD) return;                     /* keyboard is read-only */
    h->wr.valid = true;
    h->wr.addr = addr;
    h->wr.old = h->ram[addr];
    h->wr.val = v;
    if (addr >= HACK_SCREEN && h->ram[addr] != v) h->screen_gen++;
    h->ram[addr] = v;
}

HackStatus hack_step(Hack *h)
{
    if (h->pc >= h->rom_len) return HACK_STOP_END;

    const uint16_t pc = h->pc;
    const uint16_t ins = h->rom[pc];
    h->wr.valid = false;

    if (!(ins & 0x8000)) {                            /* A-instruction */
        h->a = ins;
        h->pc = (uint16_t)((pc + 1) & 0x7FFF);
        h->cycles++;
        return HACK_OK;
    }
    if ((ins & 0x6000) != 0x6000) return HACK_ERR_BAD_INSTR;

    const unsigned c = (ins >> 6) & 0x3F;
    const unsigned dest = (ins >> 3) & 7;
    const unsigned jmp = ins & 7;
    const bool use_m = (ins & 0x1000) != 0;
    const uint16_t old_a = h->a;

    if ((use_m || (dest & 1)) && old_a > HACK_KBD) return HACK_ERR_BAD_ADDR;

    const uint16_t y = use_m ? h->ram[old_a] : old_a;
    const uint16_t out = alu(h->d, y, c);

    if (dest & 1) ram_write(h, old_a, out);
    if (dest & 2) h->d = out;
    if (dest & 4) h->a = out;

    const int16_t s = (int16_t)out;
    const bool taken = ((jmp & 4) && s < 0) || ((jmp & 2) && s == 0) || ((jmp & 1) && s > 0);
    const uint16_t target = old_a & 0x7FFF;
    h->pc = taken ? target : (uint16_t)((pc + 1) & 0x7FFF);
    h->cycles++;

    /* "(END) @END / 0;JMP": the jump lands on the A-instruction right before it */
    if (jmp == 7 && (target == pc ||
                     (target + 1u == pc && target < h->rom_len && h->rom[target] == target)))
        return HACK_STOP_HALT;
    return HACK_OK;
}

HackStatus hack_run(Hack *h, uint64_t max_steps)
{
    for (uint64_t i = 0; i < max_steps; i++) {
        HackStatus st = hack_step(h);
        if (st != HACK_OK) return st;
        if (hack_has_bp(h, h->pc)) return HACK_STOP_BREAK;
    }
    return HACK_STOP_MAX;
}

const char *hack_status_str(HackStatus s)
{
    switch (s) {
    case HACK_OK:            return "ok";
    case HACK_STOP_HALT:     return "halted (infinite loop)";
    case HACK_STOP_BREAK:    return "breakpoint";
    case HACK_STOP_MAX:      return "cycle limit reached";
    case HACK_STOP_END:      return "ran past the end of the program";
    case HACK_ERR_BAD_INSTR: return "invalid instruction";
    case HACK_ERR_BAD_ADDR:  return "M access with A beyond the keyboard word";
    }
    return "?";
}
