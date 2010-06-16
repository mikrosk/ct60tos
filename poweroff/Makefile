#CROSS_PREFIX=
CROSS_PREFIX=/home/patrice/local/bin/

AS=$(CROSS_PREFIX)m68k-atari-mint-as
CC=$(CROSS_PREFIX)m68k-atari-mint-gcc
STRIP=$(CROSS_PREFIX)m68k-atari-mint-strip
OBJCOPY=$(CROSS_PREFIX)m68k-atari-mint-objcopy

TARGET = poweroff.tos

CSRCS = poweroff.c misc.c

SSRCS = entry.S

HEADERS = misc.h

EXTRA_DIST = $(HEADERS)

CFLAGS  = -Os -fomit-frame-pointer -Wall
ASFLAGS =
LDFLAGS = -nostdlib -Wl,--entry -Wl,_init_setup -lgcc
## If gcc generates some memcpy calls:
#LDFLAGS = -nostdlib -Wl,--entry -Wl,_init_setup -lgcc -lc -lgcc

COBJECTS = $(CSRCS:.c=.o)
SOBJECTS = $(SSRCS:.S=.o)

DEPEND = .depend

VERSION = 1.0

all:	$(TARGET)

$(TARGET):	$(COBJECTS) $(SOBJECTS)
	${CC} -o $@ $(SOBJECTS) $(COBJECTS) ${LDFLAGS}
	${STRIP} $(TARGET)

clean:
	rm -f $(COBJECTS) $(SOBJECTS) $(TARGET) $(DEPEND) *~

dep:	$(DEPEND)

$(DEPEND): $(CSRCS) $(SSRCS)
	$(CC) -M $(CFLAGS) $^ > $@

# Include dependencies

ifneq ($(wildcard $(DEPEND)),)
include $(DEPEND)
endif
