#!/bin/bash
#
# ABOUTME: Builds flash060.prg without a GUI, via the Hatari harness in purec.sh.
# ABOUTME: Pure C compiles and links the sources; PLINK writes the .prg itself.
#
# The compiler and assembler flags in flash060.txt reproduce what the IDE passes
# for this project. PLINK drops the program next to the sources, so unlike the
# .cpx it does not come back to this directory.
#
set -u

DIR=$(cd "$(dirname "$0")" && pwd) || exit 1

if [ -z "$(find -L "$DIR" -maxdepth 2 -ipath "$DIR/src060/flash060.prj" -print -quit 2>/dev/null)" ]; then
	echo "mkflash: missing src060/flash060.prj" >&2
	exit 1
fi

rm -f "$DIR"/src060/*.o "$DIR"/src060/*.O

exec "$DIR/purec.sh" mkflash flash060.txt "$DIR/src060/flash060.prg"
