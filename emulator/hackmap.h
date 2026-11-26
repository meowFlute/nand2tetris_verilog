/* hackmap.h -- reader for the debug map written by `hackasm.py asm -g`.
 *
 *   # hackmap 1
 *   file <idx> <path, relative to the map file>
 *   line <rom addr> <file idx> <source line>
 *   label <name> <rom addr>
 *   var <name> <ram addr>
 */
#ifndef HACKMAP_H
#define HACKMAP_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct { char *name; uint16_t addr; } HackSym;

typedef struct HackMap {
    char    **files;          /* paths already resolved against the map's directory */
    int       nfiles;
    uint16_t *line_file;      /* [rom addr] -> file index                           */
    uint32_t *line_no;        /* [rom addr] -> 1-based source line, 0 = none        */
    HackSym  *labels;  int nlabels;
    HackSym  *vars;    int nvars;
} HackMap;

HackMap *hackmap_load(const char *path, char *err, size_t errlen);
void     hackmap_free(HackMap *m);

/* source location of a ROM address */
bool        hackmap_line(const HackMap *m, uint16_t rom_addr, const char **file, uint32_t *line);
/* first label / variable at an address, or NULL */
const char *hackmap_label_at(const HackMap *m, uint16_t rom_addr);
const char *hackmap_var_at(const HackMap *m, uint16_t ram_addr);
/* look a user symbol up by name; *is_label tells which table it came from */
bool        hackmap_lookup(const HackMap *m, const char *name, uint16_t *addr, bool *is_label);

#endif
