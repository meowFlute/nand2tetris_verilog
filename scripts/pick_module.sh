#!/usr/bin/env bash
# Print a chapter-grouped picklist (to stderr), echo the chosen module name.
root=${1:-rtl}
mapfile -t entries < <(cd "$root" && ls -d chapter_*/*.v | sed 's/\.v$//' \
    | grep -v '/nand_gate$' | sort -V)

cur=""; i=0
for e in "${entries[@]}"; do
    i=$((i+1)); ch=${e%/*}
    if [ "$ch" != "$cur" ]; then echo "  $ch/" >&2; cur=$ch; fi
    printf "    %2d) %s\n" "$i" "${e#*/}" >&2
done

read -r -p "Module to view: " c
m=""
if [[ $c =~ ^[0-9]+$ ]] && ((c >= 1 && c <= i)); then
    m=${entries[c-1]#*/}
else
    for e in "${entries[@]}"; do [ "${e#*/}" = "$c" ] && m=$c; done
fi
[ -n "$m" ] || { echo "invalid selection: $c" >&2; exit 1; }
echo "$m"
