# build.prg is the Atari side of mkcpx.sh: it runs the command lines of
# build.txt inside the emulator and reports each exit code on the console.
# It is a plain TOS program, so any m68k-atari-mint cross compiler builds it.

CC     = m68k-atari-mint-gcc
CFLAGS = -O2 -Wall -s
TARGET = ../build.prg

$(TARGET): runner.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)

.PHONY: clean
