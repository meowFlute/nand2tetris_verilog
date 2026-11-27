/* hackdbg.c -- TUI debugger for the Hack CPU.
 *
 *   hackdbg [-m map] prog.hack
 *
 * A GDB-inspired ncurses interface with registers, ROM disassembly, source
 * code, and a command prompt.  Reuses hack.c (CPU core) and hackmap.c (debug
 * map reader) from the headless emulator.
 */
#define _POSIX_C_SOURCE 200809L

#include "hack.h"
#include "hackmap.h"

#include <ctype.h>
#include <locale.h>
#include <ncurses.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

/* ---------------------------------------------------------------- config */

#define CONTINUE_CHUNK 10000      /* instructions per UI refresh in continue */
#define MSG_MAX        128        /* ring buffer of command output lines      */
#define MSG_LEN        256
#define HIST_MAX       64         /* command history depth                    */
#define CMD_LEN        256

/* ---------------------------------------------------------------- colors */

enum {
    CP_TITLE = 1,
    CP_CHANGED,
    CP_CURLINE,
    CP_BREAKPT,
    CP_ERROR,
    CP_PROMPT,
    CP_STATUS,
    CP_LABEL,
    CP_BIN_OP,
    CP_BIN_VAL,
    CP_BIN_ABIT,
    CP_BIN_COMP,
    CP_BIN_DEST,
    CP_BIN_JUMP,
};

/* ---------------------------------------------------------- disassembler */

static const char *comp_mne[128];
static const char *dest_mne[8] = { "", "M", "D", "MD", "A", "AM", "AD", "AMD" };
static const char *jump_mne[8] = { "", "JGT", "JEQ", "JGE", "JLT", "JNE", "JLE", "JMP" };

static void init_comp_table(void)
{
    memset(comp_mne, 0, sizeof comp_mne);
    /* a=0 entries */
    comp_mne[0x2A] = "0";      comp_mne[0x3F] = "1";
    comp_mne[0x3A] = "-1";     comp_mne[0x0C] = "D";
    comp_mne[0x30] = "A";      comp_mne[0x0D] = "!D";
    comp_mne[0x31] = "!A";     comp_mne[0x0F] = "-D";
    comp_mne[0x33] = "-A";     comp_mne[0x1F] = "D+1";
    comp_mne[0x37] = "A+1";    comp_mne[0x0E] = "D-1";
    comp_mne[0x32] = "A-1";    comp_mne[0x02] = "D+A";
    comp_mne[0x13] = "D-A";    comp_mne[0x07] = "A-D";
    comp_mne[0x00] = "D&A";    comp_mne[0x15] = "D|A";
    /* a=1 entries (M replaces A) */
    comp_mne[0x70] = "M";      comp_mne[0x71] = "!M";
    comp_mne[0x73] = "-M";     comp_mne[0x77] = "M+1";
    comp_mne[0x72] = "M-1";    comp_mne[0x42] = "D+M";
    comp_mne[0x53] = "D-M";    comp_mne[0x47] = "M-D";
    comp_mne[0x40] = "D&M";    comp_mne[0x55] = "D|M";
}

/* Disassemble a single 16-bit word into buf.  Returns buf.
 * If next_is_jump is true, an A-instruction prefers label symbols; otherwise
 * it prefers variable / predefined RAM symbols. */
static char *disasm(uint16_t w, char *buf, size_t len, const HackMap *map,
                    bool next_is_jump)
{
    if (!(w & 0x8000)) {
        const char *sym = NULL;
        if (map) {
            if (next_is_jump) {
                sym = hackmap_label_at(map, w);
            } else {
                sym = hackmap_var_at(map, w);
            }
        }
        if (!sym && !next_is_jump) {
            if (w < 16) { snprintf(buf, len, "@R%d", w); return buf; }
            if (w == HACK_SCREEN) { snprintf(buf, len, "@SCREEN"); return buf; }
            if (w == HACK_KBD)    { snprintf(buf, len, "@KBD"); return buf; }
        }
        if (sym) snprintf(buf, len, "@%s", sym);
        else     snprintf(buf, len, "@%d", w);
        return buf;
    }
    if ((w & 0x6000) != 0x6000) {
        snprintf(buf, len, "<invalid>");
        return buf;
    }
    unsigned ac = ((w >> 6) & 0x3F) | (((w >> 12) & 1) << 6);
    unsigned d  = (w >> 3) & 7;
    unsigned j  = w & 7;
    const char *c = comp_mne[ac];
    if (!c) { snprintf(buf, len, "<invalid>"); return buf; }

    char *p = buf;
    char *end = buf + len - 1;
    if (d && p < end) {
        int n = snprintf(p, (size_t)(end - p), "%s=", dest_mne[d]);
        p += n;
    }
    if (p < end) {
        int n = snprintf(p, (size_t)(end - p), "%s", c);
        p += n;
    }
    if (j && p < end) {
        snprintf(p, (size_t)(end - p), ";%s", jump_mne[j]);
    }
    return buf;
}

/* ----------------------------------------------------- source file cache */

typedef struct {
    char  *path;
    char **lines;        /* 1-indexed: lines[1] is the first line */
    int    nlines;       /* total line count */
} SrcFile;

static SrcFile *srcfiles;
static int      nsrcfiles;

static SrcFile *load_source(const char *path)
{
    FILE *f = fopen(path, "r");
    if (!f) return NULL;

    /* grow the srcfiles array */
    SrcFile *sf = realloc(srcfiles, (size_t)(nsrcfiles + 1) * sizeof *sf);
    if (!sf) { fclose(f); return NULL; }
    srcfiles = sf;
    sf = &srcfiles[nsrcfiles++];
    memset(sf, 0, sizeof *sf);
    sf->path = strdup(path);

    /* read all lines (1-indexed: lines[0] is unused) */
    int cap = 256, n = 0;
    sf->lines = malloc((size_t)cap * sizeof *sf->lines);
    sf->lines[n++] = strdup("");  /* placeholder for index 0 */

    char line[4096];
    while (fgets(line, (int)sizeof line, f)) {
        line[strcspn(line, "\r\n")] = '\0';
        if (n >= cap) { cap *= 2; sf->lines = realloc(sf->lines, (size_t)cap * sizeof *sf->lines); }
        sf->lines[n++] = strdup(line);
    }
    fclose(f);
    sf->nlines = n - 1;  /* line count (1..nlines are valid) */
    return sf;
}

static SrcFile *find_source(const char *path)
{
    for (int i = 0; i < nsrcfiles; i++)
        if (!strcmp(srcfiles[i].path, path)) return &srcfiles[i];
    return load_source(path);
}

/* ------------------------------------------------------- global state    */

static Hack    *cpu;
static HackMap *map;

/* Previous register snapshot for change highlighting */
static struct {
    uint16_t pc, a, d, m;
    uint16_t r[16];           /* R0..R15 (R0..R4 = SP, LCL, ARG, THIS, THAT) */
    uint64_t cycles;
} prev;

static void save_prev(void)
{
    prev.pc = cpu->pc;
    prev.a  = cpu->a;
    prev.d  = cpu->d;
    prev.m  = (cpu->a <= HACK_KBD) ? cpu->ram[cpu->a] : 0;
    for (int i = 0; i < 16; i++) prev.r[i] = cpu->ram[i];
    prev.cycles = cpu->cycles;
}

/* Command messages ring buffer */
static char msgbuf[MSG_MAX][MSG_LEN];
static int  msg_count;
static int  msg_scroll;  /* lines scrolled up from bottom (0 = latest) */

static void msg(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(msgbuf[msg_count % MSG_MAX], MSG_LEN, fmt, ap);
    va_end(ap);
    msg_count++;
    msg_scroll = 0;
}

/* Command history */
static char history[HIST_MAX][CMD_LEN];
static int  hist_count;

/* Last command for repeat on empty Enter */
static char last_cmd[CMD_LEN];

/* Signal flag for Ctrl-C during continue */
static volatile sig_atomic_t interrupted;
static void sigint_handler(int sig) { (void)sig; interrupted = 1; }

static bool running = true;             /* main loop flag */

/* ------------------------------------------------------------ pane data  */

typedef struct {
    WINDOW *win;
    int y, x, h, w;
} Pane;

static Pane reg_pane, rom_pane, src_pane, cmd_pane;
static bool has_colors_;

static void pane_create(Pane *p, int h, int w, int y, int x)
{
    if (p->win) { delwin(p->win); p->win = NULL; }
    p->y = y; p->x = x; p->h = h; p->w = w;
    if (h > 0 && w > 0) {
        p->win = newwin(h, w, y, x);
        keypad(p->win, TRUE);
    }
}

static void draw_title(Pane *p, const char *title)
{
    wattron(p->win, A_REVERSE);
    wmove(p->win, 0, 0);
    for (int i = 0; i < p->w; i++) waddch(p->win, ' ');
    mvwprintw(p->win, 0, 1, " %.*s ", p->w > 4 ? p->w - 4 : 0, title);
    wattroff(p->win, A_REVERSE);
}

static void do_layout(void)
{
    int rows = LINES, cols = COLS;

    int reg_h = (rows >= 18) ? 4 : 3;    /* title + 2 or 3 register lines */
    int cmd_h = rows / 4;
    if (cmd_h < 6) cmd_h = 6;
    if (cmd_h > 12) cmd_h = 12;
    int mid_h = rows - reg_h - cmd_h;
    if (mid_h < 4) {
        cmd_h = rows - reg_h - 4;
        if (cmd_h < 3) cmd_h = 3;
        mid_h = rows - reg_h - cmd_h;
        if (mid_h < 2) mid_h = 2;
    }

    int rom_w = cols * 46 / 100;
    if (rom_w < 48) rom_w = 48;
    int src_w = cols - rom_w;
    /* collapse source pane on narrow terminals */
    if (cols < 78 || src_w < 28) {
        rom_w = cols;
        src_w = 0;
    }

    pane_create(&reg_pane, reg_h, cols, 0, 0);
    pane_create(&rom_pane, mid_h, rom_w, reg_h, 0);
    pane_create(&src_pane, mid_h, src_w, reg_h, rom_w);
    pane_create(&cmd_pane, cmd_h, cols, reg_h + mid_h, 0);
}

/* -------------------------------------------------------- drawing helpers */

static bool is_jump_instr(uint16_t w)
{
    return (w & 0xE000) == 0xE000 && (w & 7) != 0;
}

/* Print a register value, highlighted if changed from previous */
static void draw_reg(WINDOW *win, int max_w, int y, int x, const char *name,
                     int16_t val, int16_t prev_val)
{
    if (x + 10 > max_w) return;
    bool changed = (val != prev_val);
    if (changed && has_colors_)
        wattron(win, COLOR_PAIR(CP_CHANGED) | A_BOLD);
    else if (changed)
        wattron(win, A_BOLD);
    mvwprintw(win, y, x, "%s:%-6d", name, val);
    wattroff(win, COLOR_PAIR(CP_CHANGED) | A_BOLD);
}

/* ---- Register pane ---- */
static void draw_registers(void)
{
    Pane *p = &reg_pane;
    if (!p->win) return;
    werase(p->win);
    draw_title(p, "Registers");

    int16_t ma = (cpu->a <= HACK_KBD) ? (int16_t)cpu->ram[cpu->a] : 0;

    draw_reg(p->win, p->w, 1, 1,  "PC",   (int16_t)cpu->pc,   (int16_t)prev.pc);
    draw_reg(p->win, p->w, 1, 12, "A",    (int16_t)cpu->a,     (int16_t)prev.a);
    draw_reg(p->win, p->w, 1, 23, "D",    (int16_t)cpu->d,     (int16_t)prev.d);
    draw_reg(p->win, p->w, 1, 34, "M[A]", ma,                  (int16_t)prev.m);

    if (48 + 14 <= p->w) {
        bool cyc_changed = (cpu->cycles != prev.cycles);
        if (cyc_changed) wattron(p->win, A_BOLD);
        mvwprintw(p->win, 1, 48, "cyc:%-10llu", (unsigned long long)cpu->cycles);
        wattroff(p->win, A_BOLD);
    }

    /* disassemble current instruction */
    if (cpu->pc < cpu->rom_len && 65 < p->w) {
        char dis_buf[32];
        bool next_jmp = ((uint32_t)cpu->pc + 1 < cpu->rom_len) &&
                        is_jump_instr(cpu->rom[cpu->pc + 1]);
        disasm(cpu->rom[cpu->pc], dis_buf, sizeof dis_buf, map, next_jmp);
        mvwprintw(p->win, 1, 63, "| %.*s", p->w - 65, dis_buf);
    }

    static const char *rn[16] = {
        "SP", "LCL", "ARG", "THIS", "THAT", "R5", "R6", "R7",
        "R8", "R9", "R10", "R11", "R12", "R13", "R14", "R15"
    };
    int step = (p->w >= 96) ? 12 : 11;
    for (int i = 0; i < 8; i++)
        draw_reg(p->win, p->w, 2, 1 + i * step, rn[i],
                 (int16_t)cpu->ram[i], (int16_t)prev.r[i]);

    if (p->h >= 4) {
        for (int i = 8; i < 16; i++)
            draw_reg(p->win, p->w, 3, 1 + (i - 8) * step, rn[i],
                     (int16_t)cpu->ram[i], (int16_t)prev.r[i]);
    }

    wnoutrefresh(p->win);
}

/* Print a 16-bit instruction word as color-coded split binary fields
 * (matching `hackasm.py dis -S`), padded to 20 columns. */
static void draw_bin_fields(WINDOW *win, int y, int x, uint16_t w, int max_x)
{
    char bits[17];
    for (int i = 0; i < 16; i++)
        bits[i] = ((w >> (15 - i)) & 1) ? '1' : '0';
    bits[16] = '\0';

    typedef struct { int start, len, cp; } BinField;
    BinField fields[5];
    int nf;
    if (!(w & 0x8000)) {
        fields[0] = (BinField){ 0,  1, CP_BIN_OP  };
        fields[1] = (BinField){ 1, 15, CP_BIN_VAL };
        nf = 2;
    } else if ((w & 0x6000) == 0x6000) {
        fields[0] = (BinField){  0, 3, CP_BIN_OP   };
        fields[1] = (BinField){  3, 1, CP_BIN_ABIT };
        fields[2] = (BinField){  4, 6, CP_BIN_COMP };
        fields[3] = (BinField){ 10, 3, CP_BIN_DEST };
        fields[4] = (BinField){ 13, 3, CP_BIN_JUMP };
        nf = 5;
    } else {
        fields[0] = (BinField){ 0, 16, CP_BREAKPT };
        nf = 1;
    }

    int cx = x;
    for (int i = 0; i < nf && cx < max_x; i++) {
        if (i > 0 && cx < max_x) mvwaddch(win, y, cx++, ' ');
        if (has_colors_) wattron(win, COLOR_PAIR(fields[i].cp));
        for (int k = 0; k < fields[i].len && cx < max_x; k++)
            mvwaddch(win, y, cx++, bits[fields[i].start + k]);
        if (has_colors_) wattroff(win, COLOR_PAIR(fields[i].cp));
    }
}

/* ---- ROM pane ---- */
static void draw_rom(void)
{
    Pane *p = &rom_pane;
    if (!p->win) return;
    werase(p->win);
    draw_title(p, "ROM");

    int visible = p->h - 1;  /* subtract title */
    int center  = (int)cpu->pc;
    int top     = center - visible / 2;
    if (top < 0) top = 0;
    int max_top = (int)cpu->rom_len - visible;
    if (max_top < 0) max_top = 0;
    if (top > max_top) top = max_top;

    for (int row = 0; row < visible; row++) {
        int addr = top + row;
        if (addr < 0 || (uint32_t)addr >= cpu->rom_len) continue;

        int y = row + 1;
        bool is_pc = ((uint16_t)addr == cpu->pc);
        bool is_bp = hack_has_bp(cpu, (uint16_t)addr);

        /* markers */
        if (is_pc && is_bp) {
            if (has_colors_) wattron(p->win, COLOR_PAIR(CP_BREAKPT) | A_BOLD);
            mvwprintw(p->win, y, 1, "=>*");
            if (has_colors_) wattroff(p->win, COLOR_PAIR(CP_BREAKPT) | A_BOLD);
        } else if (is_pc) {
            wattron(p->win, A_BOLD);
            mvwprintw(p->win, y, 1, "=>");
            wattroff(p->win, A_BOLD);
        } else if (is_bp) {
            if (has_colors_) wattron(p->win, COLOR_PAIR(CP_BREAKPT));
            mvwprintw(p->win, y, 2, "*");
            if (has_colors_) wattroff(p->win, COLOR_PAIR(CP_BREAKPT));
        }

        /* address (0000:) */
        if (5 + 5 <= p->w) {
            wattron(p->win, A_DIM);
            mvwprintw(p->win, y, 5, "%04d:", addr);
            wattroff(p->win, A_DIM);
        }

        /* split color-coded binary fields (cols 12..31) */
        if (12 < p->w)
            draw_bin_fields(p->win, y, 12, cpu->rom[addr], p->w - 1);

        /* // disassembly */
        if (34 + 3 < p->w) {
            wattron(p->win, A_DIM);
            mvwprintw(p->win, y, 34, "//");
            wattroff(p->win, A_DIM);

            char dis_buf[32];
            bool next_jmp = ((uint32_t)addr + 1 < cpu->rom_len) &&
                            is_jump_instr(cpu->rom[addr + 1]);
            disasm(cpu->rom[addr], dis_buf, sizeof dis_buf, map, next_jmp);
            int avail = p->w - 37 - 1;
            if (avail > 0)
                mvwprintw(p->win, y, 37, "%.*s", avail, dis_buf);

            /* label, if any and room allows */
            if (map) {
                const char *lab = hackmap_label_at(map, (uint16_t)addr);
                if (lab) {
                    int lx = 37 + (int)strlen(dis_buf) + 2;
                    if (lx < 48) lx = 48;
                    if (lx + 3 < p->w) {
                        if (has_colors_) wattron(p->win, COLOR_PAIR(CP_LABEL));
                        mvwprintw(p->win, y, lx, "<%.*s>", p->w - lx - 3, lab);
                        if (has_colors_) wattroff(p->win, COLOR_PAIR(CP_LABEL));
                    }
                }
            }
        }

        /* highlight current line */
        if (is_pc)
            mvwchgat(p->win, y, 0, p->w,
                     has_colors_ ? A_BOLD : A_REVERSE,
                     has_colors_ ? CP_CURLINE : 0, NULL);
    }

    wnoutrefresh(p->win);
}

/* ---- Source pane ---- */
static void draw_source(void)
{
    Pane *p = &src_pane;
    if (!p->win || p->w <= 0) return;
    werase(p->win);
    const char *file = NULL;
    uint32_t cur_line = 0;
    if (map) hackmap_line(map, cpu->pc, &file, &cur_line);

    if (file) {
        const char *base = strrchr(file, '/');
        base = base ? base + 1 : file;
        char title[128];
        snprintf(title, sizeof title, "Source: %s", base);
        draw_title(p, title);
    } else {
        draw_title(p, "Source");
    }

    if (!map) {
        mvwprintw(p->win, 1, 2, "(no map file loaded)");
        mvwprintw(p->win, 2, 2, "use -m to load a .hack.map");
        wnoutrefresh(p->win);
        return;
    }

    if (!file || !cur_line) {
        mvwprintw(p->win, 1, 2, "(no source for PC=%d)", cpu->pc);
        wnoutrefresh(p->win);
        return;
    }

    SrcFile *sf = find_source(file);
    if (!sf) {
        mvwprintw(p->win, 1, 2, "cannot open: %s", file);
        wnoutrefresh(p->win);
        return;
    }

    int visible = p->h - 1;
    int center  = (int)cur_line;
    int top     = center - visible / 2;
    if (top < 1) top = 1;
    int max_top = sf->nlines - visible + 1;
    if (max_top < 1) max_top = 1;
    if (top > max_top) top = max_top;

    int num_w = 1;
    { int n = sf->nlines; while (n >= 10) { num_w++; n /= 10; } }

    for (int row = 0; row < visible; row++) {
        int ln = top + row;
        if (ln < 1 || ln > sf->nlines) continue;

        int y = row + 1;
        bool is_cur = ((uint32_t)ln == cur_line);

        /* line number and marker */
        char marker = is_cur ? '>' : ' ';
        mvwprintw(p->win, y, 1, "%c%*d: ", marker, num_w, ln);

        /* source text (truncate to fit) */
        int text_start = 1 + 1 + num_w + 2;
        int text_avail = p->w - text_start - 1;
        if (text_avail > 0) {
            mvwprintw(p->win, y, text_start, "%.*s", text_avail, sf->lines[ln]);
        }

        if (is_cur)
            mvwchgat(p->win, y, 0, p->w,
                     has_colors_ ? A_BOLD : A_REVERSE,
                     has_colors_ ? CP_CURLINE : 0, NULL);
    }

    wnoutrefresh(p->win);
}

static int max_msg_scroll(void)
{
    int msg_area = cmd_pane.h - 2;
    if (msg_area <= 0) return 0;
    int avail = msg_count < MSG_MAX ? msg_count : MSG_MAX;
    return avail > msg_area ? avail - msg_area : 0;
}

/* ---- Command pane ---- */
static void draw_cmd(void)
{
    Pane *p = &cmd_pane;
    if (!p->win) return;
    werase(p->win);

    int max_scr = max_msg_scroll();
    if (msg_scroll > max_scr) msg_scroll = max_scr;
    if (msg_scroll < 0) msg_scroll = 0;

    if (msg_scroll > 0) {
        char title[64];
        snprintf(title, sizeof title, "Command [-%d lines, PgUp/PgDn]", msg_scroll);
        draw_title(p, title);
    } else {
        draw_title(p, "Command");
    }

    int msg_area = p->h - 2;  /* title line + input line */
    if (msg_area > 0) {
        int end   = msg_count - msg_scroll;
        int start = end - msg_area;
        int oldest = msg_count > MSG_MAX ? msg_count - MSG_MAX : 0;
        if (start < oldest) start = oldest;
        for (int i = start; i < end; i++) {
            int y = 1 + (i - start);
            if (y >= p->h - 1) break;
            mvwprintw(p->win, y, 1, "%.*s", p->w - 2, msgbuf[i % MSG_MAX]);
        }
    }

    wnoutrefresh(p->win);
}

static void draw_all(void)
{
    draw_registers();
    draw_rom();
    draw_source();
    draw_cmd();
    doupdate();
}

/* ------------------------------------------------- address/sym resolvers */

static bool parse_num(const char *s, long *out)
{
    if (!s || !*s) return false;
    char *end;
    int base = (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) ? 16 : 10;
    long v = strtol(s, &end, base);
    if (end == s || *end) return false;
    *out = v;
    return true;
}

/* Resolve an address string to a uint16_t.  Understands R0-R15, SP, etc. */
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
    if ((s[0] == 'R' || s[0] == 'r') && isdigit((unsigned char)s[1]) &&
        parse_num(s + 1, &v) && v >= 0 && v <= 15) {
        *out = (uint16_t)v; return true;
    }
    for (size_t i = 0; i < sizeof pre / sizeof pre[0]; i++)
        if (!strcasecmp(s, pre[i].n)) { *out = pre[i].v; return true; }
    if (map) {
        bool is_label;
        return hackmap_lookup(map, s, out, &is_label);
    }
    return false;
}

/* ------------------------------------------------- command handlers      */

static void cmd_step(const char *arg)
{
    int n = 1;
    if (arg && *arg) {
        long v;
        if (!parse_num(arg, &v) || v < 1) {
            msg("usage: step [N]");
            return;
        }
        n = (int)v;
    }
    HackStatus st = HACK_OK;
    for (int i = 0; i < n; i++) {
        st = hack_step(cpu);
        if (st != HACK_OK) break;
        if (i < n - 1 && hack_has_bp(cpu, cpu->pc)) {
            st = HACK_STOP_BREAK;
            break;
        }
    }
    if (st != HACK_OK)
        msg("stopped: %s, PC=%d", hack_status_str(st), cpu->pc);
}

static void cmd_continue(void)
{
    interrupted = 0;
    nodelay(cmd_pane.win, TRUE);

    msg("running... (press any key or Ctrl-C to interrupt)");
    draw_all();

    HackStatus st = HACK_STOP_MAX;
    bool user_break = false;
    while (1) {
        st = hack_run(cpu, CONTINUE_CHUNK);
        if (st != HACK_STOP_MAX) break;
        if (interrupted) { user_break = true; break; }
        int ch = wgetch(cmd_pane.win);
        if (ch == KEY_RESIZE) {
            do_layout();
            nodelay(cmd_pane.win, TRUE);
            draw_all();
            continue;
        }
        if (ch != ERR) { user_break = true; break; }
        draw_registers();
        doupdate();
    }

    nodelay(cmd_pane.win, FALSE);
    interrupted = 0;
    if (user_break)
        msg("interrupted at PC=%d, Cycles=%llu",
            cpu->pc, (unsigned long long)cpu->cycles);
    else
        msg("stopped: %s, PC=%d, Cycles=%llu",
            hack_status_str(st), cpu->pc, (unsigned long long)cpu->cycles);
}

static void cmd_reset(void)
{
    hack_reset(cpu);
    save_prev();
    msg("CPU reset");
}

static void cmd_break(const char *arg)
{
    if (!arg || !*arg) {
        /* list breakpoints */
        int n = 0;
        for (uint32_t i = 0; i < cpu->rom_len; i++) {
            if (hack_has_bp(cpu, (uint16_t)i)) {
                const char *lab = map ? hackmap_label_at(map, (uint16_t)i) : NULL;
                msg("  breakpoint at %d%s%s%s", i,
                    lab ? " (" : "", lab ? lab : "", lab ? ")" : "");
                n++;
            }
        }
        if (!n) msg("no breakpoints set");
        return;
    }
    uint16_t addr;
    if (!resolve_addr(arg, &addr) || addr >= cpu->rom_len) {
        msg("cannot resolve '%s' as a ROM address", arg);
        return;
    }
    hack_set_bp(cpu, addr, true);
    const char *lab = map ? hackmap_label_at(map, addr) : NULL;
    msg("breakpoint set at %d%s%s%s", addr,
        lab ? " (" : "", lab ? lab : "", lab ? ")" : "");
}

static void cmd_delete(const char *arg)
{
    if (!arg || !*arg) {
        msg("usage: delete <addr|label>");
        return;
    }
    if (!strcmp(arg, "all") || !strcmp(arg, "*")) {
        memset(cpu->bp, 0, sizeof cpu->bp);
        msg("all breakpoints deleted");
        return;
    }
    uint16_t addr;
    if (!resolve_addr(arg, &addr)) {
        msg("cannot resolve '%s'", arg);
        return;
    }
    if (!hack_has_bp(cpu, addr)) {
        msg("no breakpoint at %d", addr);
        return;
    }
    hack_set_bp(cpu, addr, false);
    msg("breakpoint at %d deleted", addr);
}

static void cmd_key(const char *arg)
{
    if (!arg || !*arg) {
        msg("KBD = %d (0x%04X)", cpu->ram[HACK_KBD], cpu->ram[HACK_KBD]);
        return;
    }
    if (!strcmp(arg, "off") || !strcmp(arg, "none")) {
        hack_set_key(cpu, 0);
        msg("key released (KBD = 0)");
        return;
    }
    /* quoted character: 'A' or '0' */
    if (arg[0] == '\'' && arg[1] && arg[2] == '\'' && !arg[3]) {
        uint16_t code = (uint16_t)(unsigned char)arg[1];
        hack_set_key(cpu, code);
        msg("KBD = %d ('%c')", code, arg[1]);
        return;
    }
    /* numeric code (check before single-char so "0".."9" are numbers) */
    long v;
    if (parse_num(arg, &v) && v >= 0 && v <= 0xFFFF) {
        hack_set_key(cpu, (uint16_t)v);
        msg("KBD = %d (0x%04X)", (int)v, (unsigned)v);
        return;
    }
    /* single printable non-digit character */
    if (arg[0] && !arg[1] && isprint((unsigned char)arg[0])) {
        uint16_t code = (uint16_t)(unsigned char)arg[0];
        hack_set_key(cpu, code);
        msg("KBD = %d ('%c')", code, arg[0]);
        return;
    }
    msg("usage: key <code|char|'c'|off>");
}

static void cmd_examine(const char *arg)
{
    if (!arg || !*arg) {
        msg("usage: x [/N] <addr|sym>");
        return;
    }
    int count = 1;
    const char *p = arg;
    if (*p == '/') {
        p++;
        long v;
        char *end;
        v = strtol(p, &end, 10);
        if (end == p || v < 1 || v > 1000) { msg("bad count"); return; }
        count = (int)v;
        p = end;
        while (*p == ' ') p++;
        if (!*p) { msg("usage: x [/N] <addr|sym>"); return; }
    }
    uint16_t addr;
    if (!resolve_addr(p, &addr)) {
        msg("cannot resolve '%s'", p);
        return;
    }
    for (int i = 0; i < count && addr + i <= HACK_KBD; i++) {
        uint16_t a = (uint16_t)(addr + i);
        int16_t v = (int16_t)cpu->ram[a];
        const char *name = "";
        char rname[8];
        if (a < 16) { snprintf(rname, sizeof rname, "R%d", a); name = rname; }
        else if (map) {
            const char *var = hackmap_var_at(map, a);
            if (var) name = var;
        }
        if (a == HACK_SCREEN) name = "SCREEN";
        if (a == HACK_KBD)    name = "KBD";
        msg("  RAM[%5d] = %6d  0x%04X  %s", a, v, (uint16_t)v, name);
    }
}

static void cmd_set(const char *arg)
{
    if (!arg || !*arg) {
        msg("usage: set <reg>=<val>  (reg: A, D, PC, or RAM addr)");
        return;
    }
    char lhs[64];
    const char *eq = strchr(arg, '=');
    if (!eq) { msg("expected '=', e.g. set A=100"); return; }
    size_t llen = (size_t)(eq - arg);
    while (llen > 0 && arg[llen - 1] == ' ') llen--;
    if (llen == 0 || llen >= sizeof lhs) { msg("bad target"); return; }
    memcpy(lhs, arg, llen); lhs[llen] = '\0';

    const char *rhs = eq + 1;
    while (*rhs == ' ') rhs++;
    long val;
    if (!parse_num(rhs, &val) || val < -32768 || val > 65535) {
        msg("bad value '%s'", rhs);
        return;
    }
    uint16_t v = (uint16_t)val;

    /* special registers */
    if (!strcasecmp(lhs, "A"))  { cpu->a = v; msg("A = %d", (int16_t)v); return; }
    if (!strcasecmp(lhs, "D"))  { cpu->d = v; msg("D = %d", (int16_t)v); return; }
    if (!strcasecmp(lhs, "PC")) { cpu->pc = v; msg("PC = %d", v); return; }

    /* RAM address */
    uint16_t addr;
    if (resolve_addr(lhs, &addr) && addr <= HACK_KBD) {
        cpu->ram[addr] = v;
        msg("RAM[%d] = %d", addr, (int16_t)v);
        return;
    }
    msg("unknown register or address '%s'", lhs);
}

static void cmd_help(void)
{
    msg("Commands:");
    msg("  s [N]        step N instructions (default 1)");
    msg("  c            continue until breakpoint/halt");
    msg("  r            reset CPU (keep ROM and breakpoints)");
    msg("  b [addr]     set breakpoint (or list all)");
    msg("  del <addr>   delete breakpoint (del all = clear)");
    msg("  key <k>      set KBD (char, code, 'c', or 'off')");
    msg("  x [/N] addr  examine RAM (e.g. x/8 R0)");
    msg("  set reg=val  set A, D, PC, or RAM");
    msg("  PgUp / PgDn  scroll command output");
    msg("  q            quit");
    msg("  Enter        repeat last command");
}

/* less-style pager when a command produces more lines than fit in cmd_pane */
static void pager_loop(int top_scroll)
{
    int max_scr = max_msg_scroll();
    if (top_scroll > max_scr) top_scroll = max_scr;
    msg_scroll = top_scroll;

    for (;;) {
        draw_all();
        Pane *p = &cmd_pane;
        int prompt_y = p->h - 1;
        wmove(p->win, prompt_y, 0);
        wclrtoeol(p->win);
        wattron(p->win, A_REVERSE);
        if (msg_scroll > 0)
            mvwprintw(p->win, prompt_y, 1,
                      " -- More (%d below) [Space/j/PgDn, k/PgUp, g/G, q] -- ",
                      msg_scroll);
        else
            mvwprintw(p->win, prompt_y, 1,
                      " -- (END) [k/PgUp: up, Space/Enter/q: prompt] -- ");
        wattroff(p->win, A_REVERSE);
        wrefresh(p->win);

        int ch = wgetch(p->win);
        int page = (p->h - 2 > 1) ? p->h - 3 : 1;

        if (ch == 'q' || ch == 'Q' || ch == 27 || ch == 3) {
            msg_scroll = 0;
            return;
        } else if (ch == ' ' || ch == KEY_NPAGE || ch == 'f') {
            if (msg_scroll == 0) return;
            msg_scroll -= page;
            if (msg_scroll < 0) msg_scroll = 0;
        } else if (ch == '\n' || ch == '\r' || ch == KEY_ENTER) {
            if (msg_scroll == 0) return;
            msg_scroll--;
        } else if (ch == 'j' || ch == KEY_DOWN) {
            if (msg_scroll > 0) msg_scroll--;
        } else if (ch == 'k' || ch == KEY_UP) {
            if (msg_scroll < top_scroll) msg_scroll++;
        } else if (ch == 'b' || ch == KEY_PPAGE) {
            msg_scroll += page;
            if (msg_scroll > top_scroll) msg_scroll = top_scroll;
        } else if (ch == 'g') {
            msg_scroll = top_scroll;
        } else if (ch == 'G') {
            msg_scroll = 0;
        } else if (ch == KEY_RESIZE) {
            do_layout();
            int msg_area = cmd_pane.h - 2;
            int total = top_scroll + msg_area;
            (void)total;
        }
    }
}

/* ---- command dispatch ---- */

static void execute_command(const char *line)
{
    /* skip leading whitespace */
    while (*line == ' ') line++;
    if (!*line) {
        /* empty line: repeat last command */
        if (last_cmd[0])
            line = last_cmd;
        else
            return;
    } else {
        snprintf(last_cmd, sizeof last_cmd, "%s", line);
    }

    /* split command and argument */
    char cmd[CMD_LEN] = {0};
    const char *arg = NULL;
    const char *sp = strchr(line, ' ');
    if (sp) {
        size_t clen = (size_t)(sp - line);
        if (clen >= sizeof cmd) clen = sizeof cmd - 1;
        memcpy(cmd, line, clen); cmd[clen] = '\0';
        arg = sp + 1;
        while (*arg == ' ') arg++;
        if (!*arg) arg = NULL;
    } else {
        snprintf(cmd, sizeof cmd, "%s", line);
    }

    save_prev();
    int before_msgs = msg_count;

    if (!strcmp(cmd, "s") || !strcmp(cmd, "step"))
        cmd_step(arg);
    else if (!strcmp(cmd, "c") || !strcmp(cmd, "continue"))
        cmd_continue();
    else if (!strcmp(cmd, "r") || !strcmp(cmd, "reset"))
        cmd_reset();
    else if (!strcmp(cmd, "b") || !strcmp(cmd, "break"))
        cmd_break(arg);
    else if (!strcmp(cmd, "d") || !strcmp(cmd, "del") || !strcmp(cmd, "delete"))
        cmd_delete(arg);
    else if (!strcmp(cmd, "key"))
        cmd_key(arg);
    else if (!strcmp(cmd, "x") || !strcmp(cmd, "examine"))
        cmd_examine(arg);
    else if (cmd[0] == 'x' && cmd[1] == '/') {
        char combined[CMD_LEN];
        snprintf(combined, sizeof combined, "%s%s%s",
                 cmd + 1, arg ? " " : "", arg ? arg : "");
        cmd_examine(combined);
    }
    else if (!strcmp(cmd, "set"))
        cmd_set(arg);
    else if (!strcmp(cmd, "q") || !strcmp(cmd, "quit"))
        running = false;
    else if (!strcmp(cmd, "h") || !strcmp(cmd, "help") || !strcmp(cmd, "?"))
        cmd_help();
    else
        msg("unknown command: '%s'  (type 'h' for help)", cmd);

    int added = msg_count - before_msgs;
    int msg_area = cmd_pane.h - 2;
    if (running && msg_area > 0 && added > msg_area)
        pager_loop(added - msg_area);
}

/* --------------------------------------------------- input handling      */

static int read_command(char *buf, int maxlen)
{
    Pane *p = &cmd_pane;
    int len = 0;
    int hist_browse = hist_count;
    buf[0] = '\0';

    /* show prompt on the last line of the command pane */
    int prompt_y = p->h - 1;

    for (;;) {
        /* redraw prompt line */
        wmove(p->win, prompt_y, 0);
        wclrtoeol(p->win);
        wattron(p->win, A_BOLD);
        mvwprintw(p->win, prompt_y, 1, "(hack) ");
        wattroff(p->win, A_BOLD);
        mvwprintw(p->win, prompt_y, 8, "%s", buf);
        wrefresh(p->win);

        int ch = wgetch(p->win);

        if (ch == ERR) {
            if (interrupted) {
                interrupted = 0;
                buf[0] = '\0'; len = 0;
            }
            continue;
        }
        if (ch == '\n' || ch == '\r' || ch == KEY_ENTER) {
            msg_scroll = 0;
            if (len > 0) {
                snprintf(history[hist_count % HIST_MAX], CMD_LEN, "%s", buf);
                hist_count++;
            }
            return len;
        }
        else if (ch == KEY_PPAGE || ch == KEY_SR) {
            int step = (ch == KEY_SR) ? 1 : ((p->h - 2 > 1) ? p->h - 3 : 1);
            int max_scr = max_msg_scroll();
            msg_scroll += step;
            if (msg_scroll > max_scr) msg_scroll = max_scr;
            draw_cmd();
            doupdate();
        }
        else if (ch == KEY_NPAGE || ch == KEY_SF) {
            int step = (ch == KEY_SF) ? 1 : ((p->h - 2 > 1) ? p->h - 3 : 1);
            msg_scroll -= step;
            if (msg_scroll < 0) msg_scroll = 0;
            draw_cmd();
            doupdate();
        }
        else if (ch == KEY_BACKSPACE || ch == 127 || ch == 8) {
            if (len > 0) buf[--len] = '\0';
        }
        else if (ch == KEY_UP) {
            if (hist_browse > 0 && hist_browse > hist_count - HIST_MAX) {
                hist_browse--;
                snprintf(buf, maxlen, "%s", history[hist_browse % HIST_MAX]);
                len = (int)strlen(buf);
            }
        }
        else if (ch == KEY_DOWN) {
            if (hist_browse < hist_count - 1) {
                hist_browse++;
                snprintf(buf, maxlen, "%s", history[hist_browse % HIST_MAX]);
                len = (int)strlen(buf);
            } else {
                hist_browse = hist_count;
                buf[0] = '\0'; len = 0;
            }
        }
        else if (ch == KEY_RESIZE) {
            do_layout();
            draw_all();
            prompt_y = p->h - 1;
        }
        else if (ch == 4) {  /* Ctrl-D */
            if (len == 0) { running = false; return -1; }
        }
        else if (ch == 3) {  /* Ctrl-C */
            buf[0] = '\0'; len = 0;
        }
        else if (ch >= 32 && ch < 127 && len < maxlen - 1) {
            buf[len++] = (char)ch;
            buf[len] = '\0';
        }
    }
}

/* ----------------------------------------------------------------- main  */

static void usage(void)
{
    fprintf(stderr,
        "usage: hackdbg [-m map.hack.map] prog.hack\n"
        "\n"
        "  -m, --map FILE   load a debug map (symbols, source lines)\n"
        "  -h, --help       show this help\n");
}

int main(int argc, char **argv)
{
    const char *mapfile = NULL;
    const char *progfile = NULL;

    /* simple arg parsing */
    for (int i = 1; i < argc; i++) {
        if ((!strcmp(argv[i], "-m") || !strcmp(argv[i], "--map")) && i + 1 < argc)
            mapfile = argv[++i];
        else if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help"))
            { usage(); return 0; }
        else if (argv[i][0] == '-')
            { fprintf(stderr, "unknown option: %s\n", argv[i]); usage(); return 1; }
        else
            progfile = argv[i];
    }
    if (!progfile) { usage(); return 1; }

    /* load program */
    char err[512];
    cpu = hack_new(NULL);
    if (!cpu) { fprintf(stderr, "out of memory\n"); return 1; }
    int ninstr = hack_load_file(cpu, progfile, err, sizeof err);
    if (ninstr < 0) { fprintf(stderr, "error: %s\n", err); return 1; }

    /* load map (optional) */
    if (mapfile) {
        map = hackmap_load(mapfile, err, sizeof err);
        if (!map) { fprintf(stderr, "warning: %s\n", err); }
    } else {
        /* try progfile + ".map" automatically */
        char auto_map[4096];
        snprintf(auto_map, sizeof auto_map, "%s.map", progfile);
        map = hackmap_load(auto_map, err, sizeof err);
        /* silently ignore if not found */
    }

    /* pre-load source files referenced in the map */
    if (map) {
        for (int i = 0; i < map->nfiles; i++)
            if (map->files[i]) find_source(map->files[i]);
    }

    save_prev();
    init_comp_table();

    /* init curses */
    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    intrflush(stdscr, FALSE);

    has_colors_ = has_colors();
    if (has_colors_) {
        start_color();
        use_default_colors();
        init_pair(CP_TITLE,    COLOR_WHITE,   COLOR_BLUE);
        init_pair(CP_CHANGED,  COLOR_YELLOW,  -1);
        init_pair(CP_CURLINE,  COLOR_WHITE,   COLOR_BLUE);
        init_pair(CP_BREAKPT,  COLOR_RED,     -1);
        init_pair(CP_ERROR,    COLOR_RED,     -1);
        init_pair(CP_PROMPT,   COLOR_GREEN,   -1);
        init_pair(CP_STATUS,   COLOR_CYAN,    -1);
        init_pair(CP_LABEL,    COLOR_CYAN,    -1);
        init_pair(CP_BIN_OP,   COLOR_MAGENTA, -1);
        init_pair(CP_BIN_VAL,  COLOR_CYAN,    -1);
        init_pair(CP_BIN_ABIT, COLOR_YELLOW,  -1);
        init_pair(CP_BIN_COMP, COLOR_GREEN,   -1);
        init_pair(CP_BIN_DEST, COLOR_BLUE,    -1);
        init_pair(CP_BIN_JUMP, COLOR_RED,     -1);
    }

    /* Ctrl-C handler: only used during 'continue' */
    struct sigaction sa = {0};
    sa.sa_handler = sigint_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGINT, &sa, NULL);

    do_layout();

    msg("hackdbg: loaded %s (%d instructions)", progfile, ninstr);
    if (map) {
        msg("  map: %d labels, %d variables", map->nlabels, map->nvars);
    }
    msg("type 'h' for help");

    /* main loop */
    while (running) {
        draw_all();
        char cmdbuf[CMD_LEN];
        if (read_command(cmdbuf, CMD_LEN) < 0) break;
        execute_command(cmdbuf);
    }

    endwin();

    /* free resources */
    hack_free(cpu);
    if (map) hackmap_free(map);
    for (int i = 0; i < nsrcfiles; i++) {
        free(srcfiles[i].path);
        for (int j = 0; j <= srcfiles[i].nlines; j++) free(srcfiles[i].lines[j]);
        free(srcfiles[i].lines);
    }
    free(srcfiles);

    return 0;
}
