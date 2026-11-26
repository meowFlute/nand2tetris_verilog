#define _POSIX_C_SOURCE 200809L
#include "hackmap.h"
#include "hack.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static bool push_sym(HackSym **arr, int *n, const char *name, uint16_t addr)
{
    HackSym *p = realloc(*arr, (size_t)(*n + 1) * sizeof **arr);
    if (!p) return false;
    *arr = p;
    p[*n].name = strdup(name);
    p[*n].addr = addr;
    if (!p[*n].name) return false;
    (*n)++;
    return true;
}

HackMap *hackmap_load(const char *path, char *err, size_t errlen)
{
    FILE *f = fopen(path, "r");
    if (!f) { snprintf(err, errlen, "%s: %s", path, strerror(errno)); return NULL; }

    HackMap *m = calloc(1, sizeof *m);
    if (!m) { fclose(f); return NULL; }
    m->line_file = calloc(HACK_ROM_WORDS, sizeof *m->line_file);
    m->line_no   = calloc(HACK_ROM_WORDS, sizeof *m->line_no);

    char dir[4096] = "";
    const char *slash = strrchr(path, '/');
    if (slash) {
        size_t n = (size_t)(slash - path) + 1;
        if (n < sizeof dir) { memcpy(dir, path, n); dir[n] = 0; }
    }

    char line[4352];
    unsigned lineno = 0;
    while (fgets(line, sizeof line, f)) {
        lineno++;
        line[strcspn(line, "\r\n")] = 0;
        if (!line[0] || line[0] == '#') continue;

        if (!strncmp(line, "file ", 5)) {
            int idx, off = 0;
            if (sscanf(line + 5, "%d %n", &idx, &off) != 1 || idx < 0 || idx > 255 || !line[5 + off])
                goto bad;
            if (idx >= m->nfiles) {
                char **nf = realloc(m->files, (size_t)(idx + 1) * sizeof *nf);
                if (!nf) goto bad;
                for (int i = m->nfiles; i <= idx; i++) nf[i] = NULL;
                m->files = nf;
                m->nfiles = idx + 1;
            }
            const char *p = line + 5 + off;
            char full[8192];
            snprintf(full, sizeof full, "%s%s", p[0] == '/' ? "" : dir, p);
            free(m->files[idx]);
            m->files[idx] = strdup(full);
        } else if (!strncmp(line, "line ", 5)) {
            unsigned a, fi, ln;
            if (sscanf(line + 5, "%u %u %u", &a, &fi, &ln) != 3 || a >= HACK_ROM_WORDS) goto bad;
            m->line_file[a] = (uint16_t)fi;
            m->line_no[a] = ln;
        } else if (!strncmp(line, "label ", 6) || !strncmp(line, "var ", 4)) {
            bool is_label = line[0] == 'l';
            char name[256];
            unsigned a;
            if (sscanf(line + (is_label ? 6 : 4), "%255s %u", name, &a) != 2 || a > 0xFFFF) goto bad;
            bool ok = is_label ? push_sym(&m->labels, &m->nlabels, name, (uint16_t)a)
                               : push_sym(&m->vars, &m->nvars, name, (uint16_t)a);
            if (!ok) goto bad;
        }
        /* unknown record types are ignored for forward compatibility */
    }
    fclose(f);
    return m;

bad:
    snprintf(err, errlen, "%s:%u: malformed map line", path, lineno);
    fclose(f);
    hackmap_free(m);
    return NULL;
}

void hackmap_free(HackMap *m)
{
    if (!m) return;
    for (int i = 0; i < m->nfiles; i++) free(m->files[i]);
    free(m->files);
    for (int i = 0; i < m->nlabels; i++) free(m->labels[i].name);
    for (int i = 0; i < m->nvars; i++) free(m->vars[i].name);
    free(m->labels);
    free(m->vars);
    free(m->line_file);
    free(m->line_no);
    free(m);
}

bool hackmap_line(const HackMap *m, uint16_t a, const char **file, uint32_t *line)
{
    if (a >= HACK_ROM_WORDS || !m->line_no[a]) return false;
    uint16_t fi = m->line_file[a];
    if (fi >= m->nfiles || !m->files[fi]) return false;
    if (file) *file = m->files[fi];
    if (line) *line = m->line_no[a];
    return true;
}

const char *hackmap_label_at(const HackMap *m, uint16_t a)
{
    for (int i = 0; i < m->nlabels; i++)
        if (m->labels[i].addr == a) return m->labels[i].name;
    return NULL;
}

const char *hackmap_var_at(const HackMap *m, uint16_t a)
{
    for (int i = 0; i < m->nvars; i++)
        if (m->vars[i].addr == a) return m->vars[i].name;
    return NULL;
}

bool hackmap_lookup(const HackMap *m, const char *name, uint16_t *addr, bool *is_label)
{
    for (int i = 0; i < m->nlabels; i++)
        if (!strcmp(m->labels[i].name, name)) {
            *addr = m->labels[i].addr; if (is_label) *is_label = true; return true;
        }
    for (int i = 0; i < m->nvars; i++)
        if (!strcmp(m->vars[i].name, name)) {
            *addr = m->vars[i].addr; if (is_label) *is_label = false; return true;
        }
    return false;
}
