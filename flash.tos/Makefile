#   Flashing tool for the CT60 board
#   Copyright (C) 2000 Xavier Joubert
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#
#   To contact author write to Xavier Joubert, 5 Cour aux Chais, 44 100 Nantes,
#   FRANCE or by e-mail to xavier.joubert@free.fr.
#
#

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

FLASH_BINARY=		$(PROGRAM).ttp
FLASH_STACKSIZE=	64k
FLASH_OBJS=	\
		$(OBJDIR)/flash.o \
		$(OBJDIR)/write.o

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
		\
		$(OBJDIR)/ct60tos/movep2.o \
		\
		$(OBJDIR)/ct60tos/blitter2.o \
		\
		$(OBJDIR)/ct60tos/bios2.o \
		\
		$(OBJDIR)/ct60tos/xbios2.o \
		\
		$(OBJDIR)/ct60tos/gemdos2.o \
		\
		$(OBJDIR)/ct60tos/aes2.o \
		\
		$(OBJDIR)/ct60tos/vectors2.o \
		\
		$(OBJDIR)/ct60tos/videl2.o \
		\
		$(OBJDIR)/ct60tos/debug2.o \
		\
		$(OBJDIR)/ct60tos/ataboot.o \
		$(OBJDIR)/ct60tos/extvidel.o \
		\
		$(OBJDIR)/ct60tos/magxboot.o \
		\
		$(OBJDIR)/ct60tos/sdram.o \
		$(OBJDIR)/ct60tos/pmmu2.o \
		\
		$(OBJDIR)/ct60tos/end.o

TOS=	ct60tos.bin

BINARCHIVE=	$(PROGRAM).zip
BINDISTDIR=	./$(PROGRAM)
BINDISTFILES=	\
		LICENSE \
		$(FLASH_BINARY) \
		$(TOS)
BINDISTFILES2=	$(foreach FILE,$(BINDISTFILES),$(BINDISTDIR)/$(FILE))

SRCARCHIVE=	$(PROGRAM).tgz
SRCDISTDIR=	./$(PROGRAM)
SRCDISTFILES=	\
		LICENSE \
		Makefile \
		src \
		include
SRCDISTFILES2=	$(foreach FILE,$(SRCDISTFILES),$(SRCDISTDIR)/$(FILE))

NFARCHIVE=	$(PROGRAM)_nf.tgz
NFDISTDIR=	./nonfree
NFDISTFILES=	\
		$(NFDISTDIR)/tos404.bin

all:	 $(FLASH_BINARY) $(TOS)

bindist:	$(BINARCHIVE)
$(BINARCHIVE):	$(BINDISTFILES)
	cd .. && zip -9 $(BINDISTDIR)/$(BINARCHIVE) $(BINDISTFILES2)

srcdist:	$(SRCARCHIVE)
$(SRCARCHIVE):	$(SRCDISTFILES)
	cd .. && tar -cv $(SRCDISTFILES2) | gzip -9 > $(SRCDISTDIR)/$(SRCARCHIVE)

nonfreedist:	$(NFARCHIVE)
$(NFARCHIVE):	$(NFDISTFILES)
	tar -cv $(NFDISTFILES) | gzip -9 > $(NFARCHIVE)

clean:
	rm -rf $(OBJDIR)
	rm -f $(FLASH_BINARY) $(GENTOS_BINARY) $(TOS)
	rm -f $(BINARCHIVE) $(SRCARCHIVE) $(NFARCHIVE)

$(FLASH_BINARY):	$(FLASH_OBJS)
	$(CC) $(FLASH_OBJS) -o $(FLASH_BINARY)
	$(STRIP) $(FLASH_BINARY)
	$(STACK) -S $(FLASH_STACKSIZE) $(FLASH_BINARY)

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

$(OBJDIR)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIR)/ct60tos/%.o:	$(SRCDIR)/ct60tos/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@
