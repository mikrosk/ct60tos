#!/bin/bash
#
# ABOUTME: Runs one Pure C build script inside Hatari with this directory as C:.
# ABOUTME: Shared back end of the per-project front ends, mkcpx.sh and mkflash.sh.
#
# This directory is the emulated C: drive:
#   C:\PURE_C            the Pure C installation
#   C:\SRC               symlink to cpx/src/ct60conf.cpx
#   C:\SRC060            symlink to flash.too/src/flash060
#   C:\CPX               symlink to this directory; CPXLINK has the output
#                        path <boot drive>:\CPX\ compiled in, so this is what
#                        drops the finished .cpx here
#   C:\BUILD.PRG         runs the command lines of C:\BUILD.TXT (source: runner/)
#   C:\BUILD.TXT         the build steps, copied here from the project script
#
# --auto takes no arguments, so BUILD.PRG always reads C:\BUILD.TXT and the
# project's own script is copied over it for the run.
#
# CPXLINK only finds C:\CPX\ because --drive-a no makes C: the boot drive.
#
# Usage: purec.sh <name> <project script> <expected output>
#
set -u

NAME=$1
SCRIPT=$2
OUT=$3

HATARI=${HATARI:-hatari}
TOS=${TOS:-$HOME/atari/roms/32-bit/tos404.img}
TIMEOUT=${TIMEOUT:-300}

DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
LOG=$DIR/build.log
FIFO=$DIR/build.fifo

# The emulated drive is case insensitive, the host is not: match either.
for f in pure_c/pcc.ttp build.prg "$SCRIPT"; do
	if [ -z "$(find -L "$DIR" -maxdepth 2 -ipath "$DIR/$f" -print -quit 2>/dev/null)" ]; then
		echo "$NAME: missing $f" >&2
		exit 1
	fi
done
if [ ! -f "$TOS" ]; then
	echo "$NAME: no TOS image at $TOS" >&2
	exit 1
fi

rm -f "$FIFO" "$LOG" "$OUT"
cp "$DIR/$SCRIPT" "$DIR/build.txt" || exit 1

SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy "$HATARI" \
	--machine falcon --monitor vga --tos "$TOS" \
	--memsize 14 --ttram 0 --cpulevel 3 --addr24 no --fpu 68882 \
	--drive-a no --drive-b no --sound off --dsp off \
	--fast-boot yes --fast-forward yes --gemdos-case lower \
	--harddrive "$DIR" --auto 'C:\BUILD.PRG' \
	--conout 2 --cmd-fifo "$FIFO" --log-level warn \
	> "$LOG" 2>/dev/null &
PID=$!

# The runner prints ###DONE <rc> when the last step has finished.
waited=0
while [ $waited -lt "$TIMEOUT" ]; do
	grep -q '###DONE' "$LOG" && break
	kill -0 $PID 2>/dev/null || break
	sleep 1
	waited=$((waited + 1))
done

[ -p "$FIFO" ] && echo "hatari-shortcut quit" > "$FIFO" 2>/dev/null
for i in 1 2 3 4 5; do
	kill -0 $PID 2>/dev/null || break
	sleep 1
done
kill -9 $PID 2>/dev/null
wait $PID 2>/dev/null
rm -f "$FIFO"

# The console log is VT-52 output: strip backspaces and turn CR into LF.
CONSOLE=$(tr -d '\010' < "$LOG" | sed 's/\r/\n/g')
echo "$CONSOLE" | grep -E '^(Error|Warning) ' | sed 's/^/  /'
echo "$CONSOLE" | grep -B1 -E '^###RC [^0]' |
	sed 's/^###RUN /  failed: /;s/^###RC /  exit code /'

rc=$(echo "$CONSOLE" | sed -n 's/^###DONE \(-*[0-9]*\).*/\1/p' | tail -1)
if [ -z "$rc" ]; then
	echo "$NAME: build did not finish, see $LOG" >&2
	exit 1
fi
if [ "$rc" != "0" ]; then
	echo "$NAME: build failed with $rc, see $LOG" >&2
	exit 1
fi
if [ ! -f "$OUT" ]; then
	echo "$NAME: no $OUT, see $LOG" >&2
	exit 1
fi

echo "$NAME: $(wc -c < "$OUT") bytes  $OUT"
