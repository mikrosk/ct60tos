
CC=gcc
LD=ld
RM=rm
#CFLAGS=-O2 -fomit-frame-pointer -Wall -Wno-multichar -m68030
CFLAGS=-O2 -fomit-frame-pointer -Wall -Wno-multichar -m5200 -Wa,-m5200

all: jpegsnap.acc

jpegsnap.acc: jpegsnap.o start.o
	$(CC) $(CFLAGS) -s -nostartfiles -o jpegsnap.acc start.o jpegsnap.o -ljpeg -lgem

clean:
	$(RM) -f *.o jpegsnap.acc

jpegsnap.o: jpegsnap.c

start.o: start.S
