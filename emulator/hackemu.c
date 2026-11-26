/* hackemu -- headless Hack emulator: run a program, trace it, inspect RAM.
 *
 *   hackemu [options] prog.hack
 *
 * Exit status: 0 halted (infinite-loop idiom), 1 usage/IO error, 2 cycle limit,
 *              3 breakpoint, 4 ran past end of program, 5 invalid instruction,
 *              6 bad M address
 */
#define _POSIX_C_SOURCE 200809L
#include "hack.h"
#include "hackmap.h"

#include <ctype.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { RC_HALT = 0, RC_USAGE = 1, RC_MAX = 2, RC_BREAK = 3, RC_END = 4, RC_BADINS = 5, RC_BADADDR = 6 };

static HackMap *map;

typedef struct { unsigned long long cycle; uint16_t code; } KeyEvent;

static void usage(FILE *out)
{
    fputs(
"usage: hackemu [options] prog.hack\n"
"\n"
"  -n, --max-cycles N   stop after N instructions (default 1000000)\n"
"  -m, --map FILE       debug map from `hackasm.py asm -g` (symbols, source lines)\n"
"  -r, --ram A=V        set RAM before running; A is a number, R0-R15, SP, LCL, ARG,\n"
"                       THIS, THAT, SCREEN, KBD or a map symbol; V may be negative\n"
"                       or 0x..; repeatable\n"
"  -b, --break A        breakpoint at a ROM address or label; repeatable\n"
"  -k, --key N          hold key code N in RAM[KBD] from the start\n"
"  -K, --key-at C=N     once C instructions have executed, set RAM[KBD] to N (0 = release);\n"
"                       repeatable, any order\n"
"  -t, --trace          print one line per instruction, before it executes\n"
"  -d, --dump A[:B]     print RAM[A..B] (inclusive) at exit; repeatable\n"
"  -p, --pbm FILE       write the final screen as an ascii PBM image\n"
"  -h, --help\n", out);
}

/* ---- symbol / number parsing ------------------------------------------ */

static bool parse_num(const char *s, long *out)
{
    char *end;
    int base = (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) ? 16 : 10;
    long v = strtol(s, &end, base);
    if (end == s || *end) return false;
    *out = v;
    return true;
}

static bool resolve_addr(const char *s, uint16_t *out)
{
    static const struct { const char *n; uint16_t v; } pre[] = {
        {"SP", 0}, {"LCL", 1}, {"ARG", 2}, {"THIS", 3}, {"THAT", 4},
        {"SCREEN", HACK_SCREEN}, {"KBD", HACK_KBD},
    };
    long v;
    if (parse_num(s, &v)) {
        if (v < 0 || v > 0xFFFF) return false;
        *out = (uint16_t)v;
        return true;
    }
    if (s[0] == 'R' && parse_num(s + 1, &v) && v >= 0 && v <= 15) { *out = (uint16_t)v; return true; }
    for (size_t i = 0; i < sizeof pre / sizeof pre[0]; i++)
        if (!strcmp(s, pre[i].n)) { *out = pre[i].v; return true; }
    bool is_label;
    return map && hackmap_lookup(map, s, out, &is_label);
}

/* ---- output ------------------------------------------------------------ */

static void trace_line(const Hack *h)
{
    uint16_t m = h->a <= HACK_KBD ? h->ram[h->a] : 0;
    printf("%7llu  PC=%04X  %04X  A=%04X D=%04X M=%04X",
           (unsigned long long)h->cycles, h->pc, h->rom[h->pc], h->a, h->d, m);
    const char *file;
    uint32_t ln;
    if (map && hackmap_line(map, h->pc, &file, &ln)) {
        const char *lab = hackmap_label_at(map, h->pc);
        printf("  // %s:%u%s%s", file, ln, lab ? "  <" : "", lab ? lab : "");
        if (lab) putchar('>');
    }
    putchar('\n');
}

static void dump_range(const Hack *h, uint16_t lo, uint16_t hi)
{
    for (unsigned a = lo; a <= hi && a <= HACK_KBD; a++) {
        char rname[8];
        const char *name = "";
        if (a < 16) { snprintf(rname, sizeof rname, "R%u", a); name = rname; }
        else if (map && hackmap_var_at(map, (uint16_t)a)) name = hackmap_var_at(map, (uint16_t)a);
        else if (a == HACK_SCREEN) name = "SCREEN";
        else if (a == HACK_KBD) name = "KBD";
        printf("RAM[%5u] = %6d  0x%04X  %s\n", a, (int16_t)h->ram[a], h->ram[a], name);
    }
}

static int write_pbm(const Hack *h, const char *path)
{
    FILE *f = fopen(path, "w");
    if (!f) { perror(path); return -1; }
    fprintf(f, "P1\n%d %d\n", HACK_SCREEN_W, HACK_SCREEN_H);
    for (int y = 0; y < HACK_SCREEN_H; y++) {
        for (int x = 0; x < HACK_SCREEN_W; x++) fputc(hack_pixel(h, x, y) ? '1' : '0', f);
        fputc('\n', f);
    }
    fclose(f);
    return 0;
}

/* ---- main -------------------------------------------------------------- */

int main(int argc, char **argv)
{
    static const struct option longopts[] = {
        {"max-cycles", required_argument, 0, 'n'}, {"map", required_argument, 0, 'm'},
        {"ram", required_argument, 0, 'r'},        {"break", required_argument, 0, 'b'},
        {"key", required_argument, 0, 'k'},        {"key-at", required_argument, 0, 'K'},
        {"trace", no_argument, 0, 't'},
        {"dump", required_argument, 0, 'd'},       {"pbm", required_argument, 0, 'p'},
        {"help", no_argument, 0, 'h'},             {0, 0, 0, 0},
    };
    enum { MAXOPT = 64 };
    const char *rams[MAXOPT], *brks[MAXOPT], *dumps[MAXOPT];
    KeyEvent kev[MAXOPT];
    int nram = 0, nbrk = 0, ndump = 0, nkev = 0;
    const char *mapfile = NULL, *pbm = NULL;
    unsigned long long max_cycles = 1000000;
    long key = 0;
    bool trace = false;

    int c;
    while ((c = getopt_long(argc, argv, "n:m:r:b:k:K:td:p:h", longopts, NULL)) != -1) {
        switch (c) {
        case 'n': max_cycles = strtoull(optarg, NULL, 10); break;
        case 'm': mapfile = optarg; break;
        case 'r': if (nram < MAXOPT) rams[nram++] = optarg; break;
        case 'b': if (nbrk < MAXOPT) brks[nbrk++] = optarg; break;
        case 'k': if (!parse_num(optarg, &key)) { usage(stderr); return RC_USAGE; } break;
        case 'K': {
            char *eq = strchr(optarg, '=');
            long code;
            if (!eq || nkev >= MAXOPT || !parse_num(eq + 1, &code) || code < 0 || code > 0xFFFF) {
                fprintf(stderr, "error: --key-at expects CYCLE=CODE, got '%s'\n", optarg);
                return RC_USAGE;
            }
            kev[nkev].cycle = strtoull(optarg, NULL, 10);
            kev[nkev].code = (uint16_t)code;
            nkev++;
            break;
        }
        case 't': trace = true; break;
        case 'd': if (ndump < MAXOPT) dumps[ndump++] = optarg; break;
        case 'p': pbm = optarg; break;
        case 'h': usage(stdout); return 0;
        default:  usage(stderr); return RC_USAGE;
        }
    }
    if (optind != argc - 1) { usage(stderr); return RC_USAGE; }

    char err[512];
    Hack *h = hack_new(NULL);
    if (!h) { fputs("out of memory\n", stderr); return RC_USAGE; }
    if (hack_load_file(h, argv[optind], err, sizeof err) < 0) { fprintf(stderr, "error: %s\n", err); return RC_USAGE; }
    if (mapfile && !(map = hackmap_load(mapfile, err, sizeof err))) { fprintf(stderr, "error: %s\n", err); return RC_USAGE; }

    for (int i = 0; i < nram; i++) {
        char *eq = strchr(rams[i], '=');
        uint16_t addr;
        long val;
        if (!eq) { fprintf(stderr, "error: --ram expects ADDR=VALUE, got '%s'\n", rams[i]); return RC_USAGE; }
        char name[256];
        snprintf(name, sizeof name, "%.*s", (int)(eq - rams[i]), rams[i]);
        if (!resolve_addr(name, &addr) || addr > HACK_KBD || !parse_num(eq + 1, &val) || val < -32768 || val > 65535) {
            fprintf(stderr, "error: bad --ram '%s'\n", rams[i]);
            return RC_USAGE;
        }
        h->ram[addr] = (uint16_t)val;
    }
    for (int i = 0; i < nbrk; i++) {
        uint16_t addr;
        if (!resolve_addr(brks[i], &addr)) { fprintf(stderr, "error: unknown breakpoint '%s'\n", brks[i]); return RC_USAGE; }
        hack_set_bp(h, addr, true);
    }
    hack_set_key(h, (uint16_t)key);

    /* key events, ascending by cycle (stable insertion sort) */
    for (int i = 1; i < nkev; i++) {
        KeyEvent e = kev[i];
        int j = i - 1;
        while (j >= 0 && kev[j].cycle > e.cycle) { kev[j + 1] = kev[j]; j--; }
        kev[j + 1] = e;
    }
    int ke = 0;

    HackStatus st;
    for (;;) {
        while (ke < nkev && kev[ke].cycle <= h->cycles) hack_set_key(h, kev[ke++].code);
        if (h->cycles >= max_cycles) { st = HACK_STOP_MAX; break; }
        if (trace) {
            if (h->pc >= h->rom_len) { st = HACK_STOP_END; break; }
            trace_line(h);
            st = hack_step(h);
            if (st != HACK_OK) break;
            if (hack_has_bp(h, h->pc)) { st = HACK_STOP_BREAK; break; }
        } else {
            /* run up to the next key event (or the cycle limit) */
            unsigned long long limit = max_cycles;
            if (ke < nkev && kev[ke].cycle < limit) limit = kev[ke].cycle;
            st = hack_run(h, limit - h->cycles);
            if (st != HACK_STOP_MAX) break;       /* halt, breakpoint or error */
        }
    }

    for (int i = 0; i < ndump; i++) {
        char spec[256], *colon;
        uint16_t lo, hi;
        snprintf(spec, sizeof spec, "%s", dumps[i]);
        colon = strchr(spec, ':');
        if (colon) *colon = 0;
        if (!resolve_addr(spec, &lo) || (colon && !resolve_addr(colon + 1, &hi))) {
            fprintf(stderr, "error: bad --dump '%s'\n", dumps[i]);
            return RC_USAGE;
        }
        if (!colon) hi = lo;
        dump_range(h, lo, hi);
    }
    if (pbm && write_pbm(h, pbm) < 0) return RC_USAGE;

    fprintf(stderr, "stopped: %s after %llu cycles, PC=%u\n", hack_status_str(st),
            (unsigned long long)h->cycles, h->pc);
    switch (st) {
    case HACK_STOP_BREAK:    return RC_BREAK;
    case HACK_STOP_MAX:      return RC_MAX;
    case HACK_STOP_END:      return RC_END;
    case HACK_ERR_BAD_INSTR: return RC_BADINS;
    case HACK_ERR_BAD_ADDR:  return RC_BADADDR;
    default:                 return RC_HALT;
    }
}
