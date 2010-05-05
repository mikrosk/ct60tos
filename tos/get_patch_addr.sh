#!/bin/sh
# usage: get_patch_addr.sh <map file> <output file>

echo "#ifndef CT60TOS_PATCH_ADDR_H_" > $2
echo "#define CT60TOS_PATCH_ADDR_H_" >> $2
echo -e "\r" >> $2

grep _ct60tos_patch $1 | sed 's/[ \t]*\(0x[a-f0-9]*\)[ \t]*_\([a-z0-9_]*\)/#define\t\2\t\t\1L/' >> $2
grep _ct60tos_half_flash $1 | sed 's/[ \t]*\(0x[a-f0-9]*\)[ \t]*_\([a-z0-9_]*\)/#define\t\2\t\1L/' >> $2

echo -e "\r" >> $2
echo "#endif" >> $2
