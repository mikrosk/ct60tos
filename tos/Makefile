CROSS=		N

CROSSBINDIR_IS_Y=	m68k-atari-mint-
CROSSBINDIR_IS_N=

CROSSBINDIR=	$(CROSSBINDIR_IS_$(CROSS))

CC=		$(CROSSBINDIR)gcc
STRIP=		$(CROSSBINDIR)strip
STACK=		$(CROSSBINDIR)stack

VERSION=        0x0104

SRCDIR=		./
INCDIR=		./include
OBJDIR=		./obj
OBJDIRCF=	./obj_cf
OBJDIRCF2=	./obj_cf2
OBJDIRCF3=	./obj_cf3

SUBOBJDIRS=	\
		$(OBJDIR)/tos

SUBOBJDIRSCF=	\
		$(OBJDIRCF)/tos

SUBOBJDIRSCF2=	\
		$(OBJDIRCF2)/tos

SUBOBJDIRSCF3=	\
		$(OBJDIRCF3)/tos

INCLUDE=	-I$(INCDIR)
CFLAGS=		-m68060 -Wall -O2 -fomit-frame-pointer
CFLAGSCF=	-m5200 -Wall -O2 -fomit-frame-pointer -Wa,-m5200 -DCOLDFIRE
CFLAGSCF2=	$(CFLAGSCF) -DMCF5445X
CFLAGSCF3=	$(CFLAGSCF) -DMCF547X
CFLAGS_TOS=	-m68060 -Wall -O2 -fomit-frame-pointer
CFLAGSCF_TOS=	-m5200 -Wall -O2 -fomit-frame-pointer -Wa,-m5200 -DCOLDFIRE
CFLAGSCF2_TOS=	$(CFLAGSCF_TOS) -DMCF5445X
CFLAGSCF3_TOS=	$(CFLAGSCF_TOS) -DMCF547X

FLASH_TOS_FIRE_ENGINE=	0xFFB00000
FLASH_TOS_M54455EVB=	0xC0000000
FLASH_TOS_COLDARI=	0xFF700000
FLASH_CF68KLIB=         0x00E90000
FLASH_CF68KLIB2=        0x00E90000
FLASH_CF68KLIB3=        0x00E90000

TOS=	  ct60tos.bin
TOSPCI=   ctpcitos.bin
TOSPCI_1GB=   ctpci1gb.bin
CF68KLIB= cf68klib.bin
CF68KLIB2= cf68klib2.bin
CF68KLIB3= cf68klib3.bin
TOSCF=    firetos_m5484lite.bin
TOSCF2=   firetos_m54455evb.bin
TOSCF3=   firetos_coldari.bin
TOSCFHEX= firetos_m5484lite.hex
TOSCFHEX2=firetos_m54455evb.hex
TOSCFHEX3=firetos_coldari.hex
PCI=      pci.hex
PCICF=    pci_cf.hex
PCICF2=   pci_cf2.hex
PCICF3=   pci_cf3.hex

BINHEX_BINARY= binhex.ttp
COMPRESS_BINARY= compress.ttp
GENTOS_BINARY= gentos.ttp
GENTOS_BINARY_1GB= gentos1g.ttp
GENTOS_BINARYCF= gentoscf.ttp
GENTOS_BINARYCF2= gentoscf2.ttp
GENTOS_BINARYCF3= gentoscf3.ttp
GENTOS_STACKSIZE= 64k
GENTOS_OBJS=	\
		$(OBJDIR)/gentos.o \
		$(OBJDIR)/lz.o \
		$(OBJDIR)/srec.o \
		\
		$(OBJDIR)/tos/start.o \
		\
		$(OBJDIR)/tos/pmmu.o \
		$(OBJDIR)/tos/cookies.o \
		$(OBJDIR)/tos/dsp.o \
		$(OBJDIR)/tos/periph.o \
		$(OBJDIR)/tos/cache.o \
		$(OBJDIR)/tos/movep.o \
		$(OBJDIR)/tos/boot.o \
		$(OBJDIR)/tos/init_par.o \
		$(OBJDIR)/tos/blitter.o \
		$(OBJDIR)/tos/bios.o \
		$(OBJDIR)/tos/xbios.o \
		$(OBJDIR)/tos/gemdos.o \
		$(OBJDIR)/tos/aes.o \
		$(OBJDIR)/tos/vectors.o \
		$(OBJDIR)/tos/videl.o \
		$(OBJDIR)/tos/debug.o \
		\
		$(OBJDIR)/tos/half.o \
		\
		$(OBJDIR)/tos/version.o \
		$(OBJDIR)/tos/movep2.o \
		$(OBJDIR)/tos/blitter2.o \
		$(OBJDIR)/tos/bios2.o \
		$(OBJDIR)/tos/xbios2.o \
		$(OBJDIR)/tos/gemdos2.o \
		$(OBJDIR)/tos/aes2.o \
		$(OBJDIR)/tos/vectors2.o \
		$(OBJDIR)/tos/debug2.o \
		$(OBJDIR)/tos/ataboot.o \
		$(OBJDIR)/tos/extvidel.o \
		$(OBJDIR)/tos/magxboot.o \
		$(OBJDIR)/tos/sdram.o \
		$(OBJDIR)/tos/pmmu2.o \
		$(OBJDIR)/tos/lz.o \
		$(OBJDIR)/tos/videl2.o \
		\
		$(OBJDIR)/tos/end.o

GENTOS_OBJS_1GB=	\
		$(OBJDIR)/gentos.o \
		$(OBJDIR)/lz.o \
		$(OBJDIR)/srec.o \
		\
		$(OBJDIR)/tos/start.o \
		\
		$(OBJDIR)/tos/pmmu.o \
		$(OBJDIR)/tos/cookies.o \
		$(OBJDIR)/tos/dsp.o \
		$(OBJDIR)/tos/periph.o \
		$(OBJDIR)/tos/cache.o \
		$(OBJDIR)/tos/movep.o \
		$(OBJDIR)/tos/boot.o \
		$(OBJDIR)/tos/init_par.o \
		$(OBJDIR)/tos/blitter.o \
		$(OBJDIR)/tos/bios.o \
		$(OBJDIR)/tos/xbios.o \
		$(OBJDIR)/tos/gemdos.o \
		$(OBJDIR)/tos/aes.o \
		$(OBJDIR)/tos/vectors.o \
		$(OBJDIR)/tos/videl.o \
		$(OBJDIR)/tos/debug.o \
		\
		$(OBJDIR)/tos/half.o \
		\
		$(OBJDIR)/tos/version.o \
		$(OBJDIR)/tos/movep2.o \
		$(OBJDIR)/tos/blitter2.o \
		$(OBJDIR)/tos/bios2.o \
		$(OBJDIR)/tos/xbios2_1gb.o \
		$(OBJDIR)/tos/gemdos2.o \
		$(OBJDIR)/tos/aes2.o \
		$(OBJDIR)/tos/vectors2.o \
		$(OBJDIR)/tos/debug2.o \
		$(OBJDIR)/tos/ataboot.o \
		$(OBJDIR)/tos/extvidel.o \
		$(OBJDIR)/tos/magxboot.o \
		$(OBJDIR)/tos/sdram.o \
		$(OBJDIR)/tos/pmmu2.o \
		$(OBJDIR)/tos/lz.o \
		$(OBJDIR)/tos/videl2.o \
		\
		$(OBJDIR)/tos/end.o

GENTOS_OBJSCF=	\
		$(OBJDIRCF)/gentos.o \
		$(OBJDIRCF)/lz.o \
		$(OBJDIRCF)/srec.o \
		\
		$(OBJDIRCF)/tos/start.o \
		\
		$(OBJDIRCF)/tos/pmmu.o \
		$(OBJDIRCF)/tos/cookies.o \
		$(OBJDIRCF)/tos/dsp.o \
		$(OBJDIRCF)/tos/periph.o \
		$(OBJDIRCF)/tos/mfp.o \
		$(OBJDIRCF)/tos/cartridge.o \
		$(OBJDIRCF)/tos/cache.o \
		$(OBJDIRCF)/tos/movep.o \
		$(OBJDIRCF)/tos/boot.o \
		$(OBJDIRCF)/tos/init_par.o \
		$(OBJDIRCF)/tos/blitter.o \
		$(OBJDIRCF)/tos/bios.o \
		$(OBJDIRCF)/tos/xbios.o \
		$(OBJDIRCF)/tos/gemdos.o \
		$(OBJDIRCF)/tos/aes.o \
		$(OBJDIRCF)/tos/vectors.o \
		$(OBJDIRCF)/tos/videl.o \
		$(OBJDIRCF)/tos/debug.o \
		\
		$(OBJDIRCF)/tos/half.o \
		\
		$(OBJDIRCF)/tos/version.o \
		$(OBJDIRCF)/tos/movep2.o \
		$(OBJDIRCF)/tos/blitter2.o \
		$(OBJDIRCF)/tos/bios2.o \
		$(OBJDIRCF)/tos/xbios2.o \
		$(OBJDIRCF)/tos/gemdos2.o \
		$(OBJDIRCF)/tos/aes2.o \
		$(OBJDIRCF)/tos/vectors2.o \
		$(OBJDIRCF)/tos/debug2.o \
		$(OBJDIRCF)/tos/magxboot.o \
		$(OBJDIRCF)/tos/sdram.o \
		$(OBJDIRCF)/tos/pmmu2.o \
		$(OBJDIRCF)/tos/lz.o \
		$(OBJDIRCF)/tos/videl2.o \
		\
		$(OBJDIRCF)/tos/end.o

GENTOS_OBJSCF2=	\
		$(OBJDIRCF2)/gentos.o \
		$(OBJDIRCF)/lz.o \
		$(OBJDIRCF)/srec.o \
		\
		$(OBJDIRCF)/tos/start.o \
		\
		$(OBJDIRCF)/tos/pmmu.o \
		$(OBJDIRCF)/tos/cookies.o \
		$(OBJDIRCF)/tos/dsp.o \
		$(OBJDIRCF)/tos/periph.o \
		$(OBJDIRCF)/tos/mfp.o \
		$(OBJDIRCF)/tos/cartridge.o \
		$(OBJDIRCF)/tos/cache.o \
		$(OBJDIRCF)/tos/movep.o \
		$(OBJDIRCF)/tos/boot.o \
		$(OBJDIRCF)/tos/init_par.o \
		$(OBJDIRCF)/tos/blitter.o \
		$(OBJDIRCF)/tos/bios.o \
		$(OBJDIRCF)/tos/xbios.o \
		$(OBJDIRCF)/tos/gemdos.o \
		$(OBJDIRCF)/tos/aes.o \
		$(OBJDIRCF)/tos/vectors.o \
		$(OBJDIRCF)/tos/videl.o \
		$(OBJDIRCF)/tos/debug.o \
		\
		$(OBJDIRCF)/tos/half.o \
		\
		$(OBJDIRCF2)/tos/version.o \
		$(OBJDIRCF)/tos/movep2.o \
		$(OBJDIRCF2)/tos/blitter2.o \
		$(OBJDIRCF2)/tos/bios2.o \
		$(OBJDIRCF2)/tos/xbios2.o \
		$(OBJDIRCF2)/tos/gemdos2.o \
		$(OBJDIRCF2)/tos/aes2.o \
		$(OBJDIRCF2)/tos/vectors2.o \
		$(OBJDIRCF2)/tos/debug2.o \
		$(OBJDIRCF)/tos/magxboot.o \
		$(OBJDIRCF2)/tos/sdram.o \
		$(OBJDIRCF2)/tos/pmmu2.o \
		$(OBJDIRCF)/tos/lz.o \
		$(OBJDIRCF2)/tos/videl2.o \
		\
		$(OBJDIRCF)/tos/end.o
		
GENTOS_OBJSCF3=	\
		$(OBJDIRCF3)/gentos.o \
		$(OBJDIRCF)/lz.o \
		$(OBJDIRCF)/srec.o \
		\
		$(OBJDIRCF)/tos/start.o \
		\
		$(OBJDIRCF)/tos/pmmu.o \
		$(OBJDIRCF)/tos/cookies.o \
		$(OBJDIRCF)/tos/dsp.o \
		$(OBJDIRCF)/tos/periph.o \
		$(OBJDIRCF)/tos/mfp.o \
		$(OBJDIRCF)/tos/cartridge.o \
		$(OBJDIRCF)/tos/cache.o \
		$(OBJDIRCF)/tos/movep.o \
		$(OBJDIRCF)/tos/boot.o \
		$(OBJDIRCF)/tos/init_par.o \
		$(OBJDIRCF)/tos/blitter.o \
		$(OBJDIRCF)/tos/bios.o \
		$(OBJDIRCF)/tos/xbios.o \
		$(OBJDIRCF)/tos/gemdos.o \
		$(OBJDIRCF)/tos/aes.o \
		$(OBJDIRCF)/tos/vectors.o \
		$(OBJDIRCF)/tos/videl.o \
		$(OBJDIRCF)/tos/debug.o \
		\
		$(OBJDIRCF)/tos/half.o \
		\
		$(OBJDIRCF3)/tos/version.o \
		$(OBJDIRCF)/tos/movep2.o \
		$(OBJDIRCF)/tos/blitter2.o \
		$(OBJDIRCF3)/tos/bios2.o \
		$(OBJDIRCF3)/tos/xbios2.o \
		$(OBJDIRCF3)/tos/gemdos2.o \
		$(OBJDIRCF3)/tos/aes2.o \
		$(OBJDIRCF3)/tos/vectors2.o \
		$(OBJDIRCF3)/tos/debug2.o \
		$(OBJDIRCF)/tos/magxboot.o \
		$(OBJDIRCF3)/tos/sdram.o \
		$(OBJDIRCF3)/tos/pmmu2.o \
		$(OBJDIRCF)/tos/lz.o \
		$(OBJDIRCF3)/tos/videl2.o \
		\
		$(OBJDIRCF)/tos/end.o

NFDISTDIR =	./nonfree
NFDISTFILES =	\
		$(NFDISTDIR)/tos404.bin \
		$(NFDISTDIR)/sparrow.out

NFDISTFILESCF =	\
		$(NFDISTDIR)/tos404.bin \
		$(CF68KLIB)

NFDISTFILESCF2 =	\
		$(NFDISTDIR)/tos404.bin \
		$(CF68KLIB2)
		
NFDISTFILESCF3 =	\
		$(NFDISTDIR)/tos404.bin \
		$(CF68KLIB3)
		
all:	version.h $(BINHEX_BINARY) $(COMPRESS_BINARY) $(PCI) $(PCICF) $(PCICF2) $(PCICF3) $(TOS) $(TOSPCI) $(TOSPCI_1GB) $(CF68KLIB) $(CF68KLIB2) $(CF68KLIB3) $(TOSCF) $(TOSCF2) $(TOSCF3) $(TOSCFHEX) $(TOSCFHEX2) $(TOSCFHEX3)

ct60:	version.h $(BINHEX_BINARY) $(COMPRESS_BINARY) $(PCI) $(TOS) $(TOSPCI) $(TOSPCI_1GB)

m5484lite:	version.h $(BINHEX_BINARY) $(COMPRESS_BINARY) $(PCICF) $(CF68KLIB) $(TOSCF) $(TOSCFHEX)

m54455evb:	version.h $(BINHEX_BINARY) $(COMPRESS_BINARY) $(PCICF2) $(CF68KLIB2) $(TOSCF2) $(TOSCFHEX2)

coldari:	version.h $(BINHEX_BINARY) $(COMPRESS_BINARY) $(PCICF3) $(CF68KLIB3) $(TOSCF3) $(TOSCFHEX3)

clean:
	rm -rf $(OBJDIR) $(OBJDIRCF) $(OBJDIRCF2) $(OBJDIRCF3)
	rm -f $(BINHEX_BINARY) $(COMPRESS_BINARY) $(GENTOS_BINARY) $(GENTOS_BINARYCF) $(GENTOS_BINARYCF2) $(GENTOS_BINARYCF3) $(TOS) $(TOSPCI) $(TOSPCI_1GB) $(CF68KLIB) $(CF68KLIB2) $(CF68KLIB3) $(TOSCF) $(TOSCF2) $(TOSCF3) $(TOSCFHEX) $(TOSCFHEX2) $(TOSCFHEX3)
	make clean -C pci

$(BINHEX_BINARY):	$(OBJDIR)/binhex.o
	$(CC) $(OBJDIR)/binhex.o -o $(BINHEX_BINARY)
	$(STRIP) $(BINHEX_BINARY)
	$(STACK) -S $(GENTOS_STACKSIZE) $(BINHEX_BINARY)

$(COMPRESS_BINARY):	$(OBJDIR)/compress.o $(OBJDIR)/lz.o
	$(CC) $(OBJDIR)/compress.o $(OBJDIR)/lz.o -o $(COMPRESS_BINARY)
	$(STRIP) $(COMPRESS_BINARY)
	$(STACK) -S $(GENTOS_STACKSIZE) $(COMPRESS_BINARY)

$(GENTOS_BINARY):	$(GENTOS_OBJS)
	$(CC) $(GENTOS_OBJS) -o $(GENTOS_BINARY)
	$(STRIP) $(GENTOS_BINARY)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARY)

$(GENTOS_BINARY_1GB):	$(GENTOS_OBJS_1GB)
	$(CC) $(GENTOS_OBJS_1GB) -o $(GENTOS_BINARY_1GB)
	$(STRIP) $(GENTOS_BINARY_1GB)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARY_1GB)

$(GENTOS_BINARYCF):	$(GENTOS_OBJSCF)
	$(CC) $(GENTOS_OBJSCF) -o $(GENTOS_BINARYCF)
	$(STRIP) $(GENTOS_BINARYCF)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARYCF)

$(GENTOS_BINARYCF2):	$(GENTOS_OBJSCF2)
	$(CC) $(GENTOS_OBJSCF2) -o $(GENTOS_BINARYCF2)
	$(STRIP) $(GENTOS_BINARYCF2)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARYCF2)

$(GENTOS_BINARYCF3):	$(GENTOS_OBJSCF3)
	$(CC) $(GENTOS_OBJSCF3) -o $(GENTOS_BINARYCF3)
	$(STRIP) $(GENTOS_BINARYCF3)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARYCF3)

$(TOS):	$(GENTOS_BINARY) $(NFDISTFILES)
	./$(GENTOS_BINARY) $(NFDISTFILES) $(TOS)

$(TOSPCI):	$(GENTOS_BINARY) $(NFDISTFILES) ./pci/$(PCI)
	./$(GENTOS_BINARY) $(NFDISTFILES) ./pci/$(PCI) $(TOSPCI)

$(TOSPCI_1GB):	$(GENTOS_BINARY_1GB) $(NFDISTFILES) ./pci/$(PCI)
	./$(GENTOS_BINARY) $(NFDISTFILES) ./pci/$(PCI) $(TOSPCI_1GB)
	
$(PCI):	
	make ctpci -C pci

$(CF68KLIB):	$(OBJDIRCF)/tos/cf68klib.o
	$(LD) -oformat binary -Ttext $(FLASH_CF68KLIB) -s -o $(CF68KLIB) $(OBJDIRCF)/tos/cf68klib.o

$(CF68KLIB2):	$(OBJDIRCF2)/tos/cf68klib.o
	$(LD) -oformat binary -Ttext $(FLASH_CF68KLIB2) -s -o $(CF68KLIB2) $(OBJDIRCF2)/tos/cf68klib.o

$(CF68KLIB3):	$(OBJDIRCF3)/tos/cf68klib.o
	$(LD) -oformat binary -Ttext $(FLASH_CF68KLIB3) -s -o $(CF68KLIB3) $(OBJDIRCF3)/tos/cf68klib.o

$(TOSCF):	$(GENTOS_BINARYCF) $(NFDISTFILESCF) ./pci/$(PCICF)
	./$(GENTOS_BINARYCF) $(NFDISTFILESCF) ./pci/$(PCICF) $(TOSCF)

$(TOSCF2):	$(GENTOS_BINARYCF2) $(NFDISTFILESCF2) ./pci/$(PCICF2)
	./$(GENTOS_BINARYCF2) $(NFDISTFILESCF2) ./pci/$(PCICF2) $(TOSCF2)

$(TOSCF3):	$(GENTOS_BINARYCF3) $(NFDISTFILESCF3) ./pci/$(PCICF3)
	./$(GENTOS_BINARYCF3) $(NFDISTFILESCF3) ./pci/$(PCICF3) $(TOSCF3)

$(TOSCFHEX):	$(TOSCF)
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_TOS_FIRE_ENGINE) $(TOSCF) $(TOSCFHEX)

$(TOSCFHEX2):	$(TOSCF2)
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_TOS_M54455EVB) $(TOSCF2) $(TOSCFHEX2)

$(TOSCFHEX3):	$(TOSCF3)
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_TOS_COLDARI) $(TOSCF3) $(TOSCFHEX3)

$(PCICF):	
	make m5484lite -C pci

$(PCICF2):	
	make m54455evb -C pci
	
$(PCICF3):	
	make coldari -C pci

version.h:
	@date -u +%e,%_m,%Y,%k,%_M > date.tmp
	@echo "#define VERSION" $(VERSION) > $(INCDIR)/version.h
	@echo "#define DATE \\" > version.tmp
	@cat version.tmp >> $(INCDIR)/version.h
	@cat date.tmp >> $(INCDIR)/version.h
	@rm version.tmp
	@rm date.tmp
	@touch -m $(SRCDIR)/tos/version.S

define CREATEOBJDIRS
	@for d in $(OBJDIR) $(SUBOBJDIRS); do \
		if [ ! -d $$d ] ; then \
			mkdir $$d ; \
		fi ; \
	done
endef

define CREATEOBJDIRSCF
	@for d in $(OBJDIRCF) $(SUBOBJDIRSCF); do \
		if [ ! -d $$d ] ; then \
			mkdir $$d ; \
		fi ; \
	done
endef

define CREATEOBJDIRSCF2
	@for d in $(OBJDIRCF2) $(SUBOBJDIRSCF2); do \
		if [ ! -d $$d ] ; then \
			mkdir $$d ; \
		fi ; \
	done
endef

define CREATEOBJDIRSCF3
	@for d in $(OBJDIRCF3) $(SUBOBJDIRSCF3); do \
		if [ ! -d $$d ] ; then \
			mkdir $$d ; \
		fi ; \
	done
endef

$(OBJDIR)/tos/version.o:	$(SRCDIR)/tos/version.S $(INCDIR)/version.h
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIRCF)/tos/version.o:	$(SRCDIR)/tos/version.S $(INCDIR)/main.h
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -c $< -o $@

$(OBJDIR)/tos/xbios2.o:	$(SRCDIR)/tos/xbios2.S $(SRCDIR)/tos/pci_bios.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/tos/xbios2_1gb.o:	$(SRCDIR)/tos/xbios2.S $(SRCDIR)/tos/pci_bios.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -DCTPCI_1GB -c $< -o $@

$(OBJDIRCF)/tos/xbios2.o:	$(SRCDIR)/tos/xbios2.S $(SRCDIR)/tos/pci_bios.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -c $< -o $@

$(OBJDIRCF2)/tos/xbios2.o:	$(SRCDIR)/tos/xbios2.S $(SRCDIR)/tos/pci_bios.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2_TOS) -c $< -o $@

$(OBJDIRCF3)/tos/xbios2.o:	$(SRCDIR)/tos/xbios2.S $(SRCDIR)/tos/pci_bios.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3_TOS) -c $< -o $@

$(OBJDIR)/tos/bios2.o:	$(SRCDIR)/tos/bios2.S $(SRCDIR)/tos/conout.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIRCF)/tos/bios2.o:	$(SRCDIR)/tos/bios2.S $(SRCDIR)/tos/conout.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -c $< -o $@

$(OBJDIRCF2)/tos/bios2.o:	$(SRCDIR)/tos/bios2.S $(SRCDIR)/tos/conout.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2_TOS) -c $< -o $@

$(OBJDIRCF3)/tos/bios2.o:	$(SRCDIR)/tos/bios2.S $(SRCDIR)/tos/conout.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3_TOS) -c $< -o $@

$(OBJDIR)/tos/videl2.o:	$(SRCDIR)/tos/videl2.S $(SRCDIR)/tos/pic_boot.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/tos/videl2.o:	$(SRCDIR)/tos/videl2.S $(SRCDIR)/tos/pic_boot.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -c $< -o $@

$(OBJDIRCF2)/tos/videl2.o:	$(SRCDIR)/tos/videl2.S $(SRCDIR)/tos/pic_boot.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2_TOS) -c $< -o $@

$(OBJDIRCF3)/tos/videl2.o:	$(SRCDIR)/tos/videl2.S $(SRCDIR)/tos/pic_boot.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3_TOS) -c $< -o $@

$(OBJDIR)/tos/%.o:	$(SRCDIR)/tos/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIRCF)/tos/%.o:	$(SRCDIR)/tos/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -c $< -o $@

$(OBJDIRCF2)/tos/%.o:	$(SRCDIR)/tos/%.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2_TOS) -c $< -o $@

$(OBJDIRCF3)/tos/%.o:	$(SRCDIR)/tos/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3_TOS) -c $< -o $@

$(OBJDIR)/tos/%.o:	$(SRCDIR)/tos/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIRCF)/tos/%.o:	$(SRCDIR)/tos/%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -c $< -o $@

$(OBJDIRCF2)/tos/%.o:	$(SRCDIR)/tos/%.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2_TOS) -c $< -o $@

$(OBJDIRCF3)/tos/%.o:	$(SRCDIR)/tos/%.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3_TOS) -c $< -o $@

$(OBJDIRCF)/tos/cf68klib.o:	$(SRCDIR)/tos/cf68klib.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -c $< -o $@

$(OBJDIRCF2)/tos/cf68klib.o:	$(SRCDIR)/tos/cf68klib.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2_TOS) -c $< -o $@

$(OBJDIRCF3)/tos/cf68klib.o:	$(SRCDIR)/tos/cf68klib.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3_TOS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3) -c $< -o $@ 

$(OBJDIR)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3) -c $< -o $@
