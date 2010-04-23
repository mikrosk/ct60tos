# Free spaces in TOS 4.04 ROM
#	Offset	Length
#	0x4df9c 0x2078
#	0x5050a 0x02dc
#	0x7aad0 0x552e

CROSS_PREFIX=
#CROSS_PREFIX=/home/patrice/local/bin/

CC=$(CROSS_PREFIX)m68k-atari-mint-gcc
STRIP=$(CROSS_PREFIX)m68k-atari-mint-strip
OBJCOPY=$(CROSS_PREFIX)m68k-atari-mint-objcopy
BIN2SRC=./bin2src.pl

TARGET = setup.tos
FIRMWARE_TARGET = setup_firmware.S

CSRCS = setup.c form_vt.c form_nvram.c form_cpu.c form_devices.c \
	form_bootorder.c form_exit.c misc.c video.c ct60_ctcm.c \
	form_sdram.c form_ct60.c

SSRCS = entry.S ct60.S ct60_sdram.S hw_regs.S

HEADERS = ct60_ctcm.h ct60.h ct60_sdram.h form_bootorder.h form_cpu.h \
	form_devices.h form_exit.h form_nvram.h form_sdram.h form_vt.h \
	misc.h nvram.h scancodes.h video.h form_ct60.h hw_regs.h config.h

EXTRA_DIST = $(HEADERS) setup_loader.S bin2src.pl

CFLAGS  = -O2 -fomit-frame-pointer -Wall
LDFLAGS = -nostdlib -Wl,--entry -Wl,_init_setup -lgcc
## If gcc generates some memcpy calls:
#LDFLAGS = -nostdlib -Wl,--entry -Wl,_init_setup -lgcc -lc -lgcc
OBJCOPY_FLAGS = -I binary -O a.out-mint -B m68k

COBJECTS = $(CSRCS:.c=.o)
SOBJECTS = $(SSRCS:.S=.o)

DEPEND = .depend

VERSION = 1.1

all:	$(TARGET)

.S.o:
	${CC} -o $@ -c $<

.c.o:
	${CC} ${CFLAGS} -o $@ -c $<

$(TARGET):	$(COBJECTS) $(SOBJECTS)
	${CC} -o $@ $(SOBJECTS) $(COBJECTS) ${LDFLAGS}
	${STRIP} $(TARGET)

clean:
	rm -f $(COBJECTS) $(SOBJECTS) $(TARGET) $(DEPEND)

dist:
	cd .. ; tar cvzf \
		ct60_setup-$(VERSION).tar.gz \
		ct60_setup/*.c \
		ct60_setup/*.h \
		ct60_setup/*.S \
		ct60_setup/*.pl \
		ct60_setup/Makefile \
		ct60_setup/COPYING \
		ct60_setup/README \
		--exclude=ct60_setup/$(FIRMWARE_TARGET)

firmware:	$(FIRMWARE_TARGET)

$(FIRMWARE_TARGET):	$(TARGET)
	$(BIN2SRC) $< > $@

dep:	$(DEPEND)

$(DEPEND): $(CSRCS) $(SSRCS)
	$(CC) -M $(CFLAGS) $^ > $@

# Include dependencies

ifneq ($(wildcard $(DEPEND)),)
include $(DEPEND)
endif
