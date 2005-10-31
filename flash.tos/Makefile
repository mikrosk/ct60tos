CROSS=		N

CROSSBINDIR_IS_Y=	m68k-atari-mint-
CROSSBINDIR_IS_N=

CROSSBINDIR=	$(CROSSBINDIR_IS_$(CROSS))

CC=		$(CROSSBINDIR)gcc
STRIP=		$(CROSSBINDIR)strip
STACK=		$(CROSSBINDIR)stack

SRCDIR=		./src
INCDIR=		./include
OBJDIR=		./obj

SUBOBJDIRS=	\
		$(OBJDIR)/ct60tos

INCLUDE=	-I$(INCDIR)
CFLAGS=		-m68060 -msoft-float -Wall -O2 -fomit-frame-pointer

CFLAGS_TOS=	-m68060 -msoft-float -Wall -O2 -fomit-frame-pointer

PROGRAM=	flash

GENTOS_BINARY=	gentos.ttp
GENTOS_STACKSIZE=	64k
GENTOS_OBJS=	\
		$(OBJDIR)/gentos.o \
		\
		$(OBJDIR)/ct60tos/start.o \
		\
		$(OBJDIR)/ct60tos/pmmu.o \
		$(OBJDIR)/ct60tos/cookies.o \
		$(OBJDIR)/ct60tos/dsp.o \
		$(OBJDIR)/ct60tos/periph.o \
		$(OBJDIR)/ct60tos/cache.o \
		$(OBJDIR)/ct60tos/movep.o \
		$(OBJDIR)/ct60tos/boot.o \
		$(OBJDIR)/ct60tos/init_par.o \
		$(OBJDIR)/ct60tos/blitter.o \
		$(OBJDIR)/ct60tos/bios.o \
		$(OBJDIR)/ct60tos/xbios.o \
		$(OBJDIR)/ct60tos/gemdos.o \
		$(OBJDIR)/ct60tos/aes.o \
		$(OBJDIR)/ct60tos/vectors.o \
		$(OBJDIR)/ct60tos/videl.o \
		$(OBJDIR)/ct60tos/debug.o \
		\
		$(OBJDIR)/ct60tos/half.o \
		\
		$(OBJDIR)/ct60tos/version.o \
		$(OBJDIR)/ct60tos/movep2.o \
		$(OBJDIR)/ct60tos/blitter2.o \
		$(OBJDIR)/ct60tos/bios2.o \
		$(OBJDIR)/ct60tos/xbios2.o \
		$(OBJDIR)/ct60tos/gemdos2.o \
		$(OBJDIR)/ct60tos/aes2.o \
		$(OBJDIR)/ct60tos/vectors2.o \
		$(OBJDIR)/ct60tos/debug2.o \
		$(OBJDIR)/ct60tos/ataboot.o \
		$(OBJDIR)/ct60tos/extvidel.o \
		$(OBJDIR)/ct60tos/magxboot.o \
		$(OBJDIR)/ct60tos/sdram.o \
		$(OBJDIR)/ct60tos/pmmu2.o \
		$(OBJDIR)/ct60tos/videl2.o \
		\
		$(OBJDIR)/ct60tos/end.o

TOS=	ct60tos.bin

NFDISTDIR=	./nonfree
NFDISTFILES=	\
		$(NFDISTDIR)/tos404.bin \
		$(NFDISTDIR)/sparrow.out

all:	 $(TOS)

clean:
	rm -rf $(OBJDIR)
	rm -f $(GENTOS_BINARY) $(TOS)

$(GENTOS_BINARY):	$(GENTOS_OBJS)
	$(CC) $(GENTOS_OBJS) -o $(GENTOS_BINARY)
	$(STRIP) $(GENTOS_BINARY)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARY)

tos:	$(TOS)
$(TOS):	$(GENTOS_BINARY) $(NFDISTFILES)
	./$(GENTOS_BINARY) $(NFDISTFILES) $(TOS)

define CREATEOBJDIRS
	@for d in $(OBJDIR) $(SUBOBJDIRS); do \
		if [ ! -d $$d ] ; then \
			mkdir $$d ; \
		fi ; \
	done
endef

$(OBJDIR)/version.o:	$(SRCDIR)/ct60tos/version.S $(INCDIR)/main.h
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIR)/xbios2.o:	$(SRCDIR)/ct60tos/xbios2.S $(SRCDIR)/ct60tos/pci_bios.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIR)/bios2.o:	$(SRCDIR)/ct60tos/bios2.S $(SRCDIR)/ct60tos/conout.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIR)/videl2.o:	$(SRCDIR)/ct60tos/videl2.S $(SRCDIR)/ct60tos/pic_boot.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o

$(OBJDIR)/ct60tos/%.o:	$(SRCDIR)/ct60tos/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/ct60tos/%.o:	$(SRCDIR)/ct60tos/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@
