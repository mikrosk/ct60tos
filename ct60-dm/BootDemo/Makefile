
TGAFILE=falcon.tga
CC=gcc
LD=ld
RM=rm
CFLAGS=-m68060 -O2 -Wall -pedantic

all: demo.hex picture tga_demo.hex

demo.hex: header.o test.o
	$(LD) -oformat srec -Ttext 0xed0000 -Tbss 0x100000 \
	-s -o demo.hex header.o test.o

picture:
	bintoc.ttp $(TGAFILE) pic_boot.h picture

tga_demo.hex: header.o tga_test.o tga.o tga_conv.o
	$(LD) -oformat srec -Map tga_demo.map -Ttext 0xed0000 -Tbss 0x100000 \
	-o tga_demo.hex header.o tga_test.o tga.o tga_conv.o

clean:
	$(RM) -f *.o demo.hex pic_boot.h tga_demo.hex

test.o: test.c

tga_test.o: tga_test.c

tga.o: tga.c

tga_conv.o: tga_conv.S

header.o: header.S
