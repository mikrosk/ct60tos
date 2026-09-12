#!/bin/bash
#
# ABOUTME: Builds ct60conf.cpx without a GUI, via the Hatari harness in purec.sh.
# ABOUTME: Pure C compiles and links the sources, then CPXLINK makes the .cpx.
#
# The compiler and assembler flags in cpx.txt reproduce what the IDE passes for
# this project, so the output is byte for byte the same as a Make from inside
# PC.PRG, save for the Pure Debugger symbol table the shipped binary carries.
#
set -u

DIR=$(cd "$(dirname "$0")" && pwd) || exit 1

if [ -z "$(find -L "$DIR" -maxdepth 2 -ipath "$DIR/src/ct60conf.prj" -print -quit 2>/dev/null)" ]; then
	echo "mkcpx: missing src/ct60conf.prj" >&2
	exit 1
fi

rm -f "$DIR"/src/*.o "$DIR"/src/*.O "$DIR"/src/*.cp "$DIR"/src/*.CP

exec "$DIR/purec.sh" mkcpx cpx.txt "$DIR/ct60conf.cpx"
