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

CROSS=		Y

CROSSBINDIR_IS_Y= m68k-atari-mint-
CROSSBINDIR_IS_N=

CROSSBINDIR=	$(CROSSBINDIR_IS_$(CROSS))

PLATFORM_IS_Y=	LINUX
PLATFORM_IS_N=	ATARI
PLATFORM=	$(PLATFORM_IS_$(CROSS))

CC=		$(CROSSBINDIR)gcc
LD=		$(CROSSBINDIR)ld
STRIP=		$(CROSSBINDIR)strip
STACK=		$(CROSSBINDIR)stack

HOSTCC=		gcc

SRCDIR=		./src
INCDIR=		./include
OBJDIR=		./obj

INCLUDE=	-I$(INCDIR)
CFLAGS=		-m68060 -msoft-float -Wall -O2 -fomit-frame-pointer

CFLAGS_TOS=	-m68060 -msoft-float -Wall -O2 -fomit-frame-pointer

PROGRAM=	flash

FLASH_BINARY=	$(PROGRAM).ttp
FLASH_STACKSIZE=64k
FLASH_OBJS=	\
		$(OBJDIR)/flash.o \
		$(OBJDIR)/write.o

GENTOS=		gentos
TOS_PATCHES=	tos_patches.bin

# ct60.ld picks the files it needs, we don't care about order here
TOS_OBJS=	$(patsubst $(SRCDIR)/ct60tos/%,$(OBJDIR)/ct60tos/%.o, \
			$(basename $(wildcard $(SRCDIR)/ct60tos/*.[Sc])))

TOS=		ct60tos.bin

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
		$(NFDISTDIR)/tos404.bin \
		$(NFDISTDIR)/sparrow.out

all:	 	$(FLASH_BINARY) $(TOS)

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
	rm -f $(FLASH_BINARY) $(GENTOS) $(TOS)
	rm -f $(TOS_PATCHES)
	rm -f $(BINARCHIVE) $(SRCARCHIVE) $(NFARCHIVE)

$(FLASH_BINARY):	$(FLASH_OBJS)
	$(CC) $(FLASH_OBJS) -o $(FLASH_BINARY)
	$(STRIP) $(FLASH_BINARY)
	$(STACK) -S $(FLASH_STACKSIZE) $(FLASH_BINARY)

$(TOS_PATCHES):	$(TOS_OBJS) ct60.ld
	cd $(OBJDIR)/ct60tos && $(LD) -T ../../ct60.ld -o ../../$@

$(GENTOS):	$(SRCDIR)/gentos.c
	$(HOSTCC) -Wall -O2 $(INCLUDE) -D$(PLATFORM) -o $@ $(SRCDIR)/gentos.c

tos:	$(TOS)
$(TOS):	$(NFDISTFILES) $(TOS_PATCHES) $(GENTOS)
	./$(GENTOS) --tos $(NFDISTDIR)/tos404.bin --tospatch $(TOS_PATCHES) --tests $(NFDISTDIR)/sparrow.out --out $(TOS)

$(OBJDIR)/%.o:	$(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIR)/ct60tos/%.o:	$(SRCDIR)/ct60tos/%.S
	@mkdir -p $(@D)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.S
	@mkdir -p $(@D)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@
