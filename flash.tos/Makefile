CC = m68k-atari-mint-gcc
LD = m68k-atari-mint-ld
STRIP = m68k-atari-mint-strip
STACK =	m68k-atari-mint-stack

VERSION = 0x0202

SRCDIR = .
INCDIR = ./include
OBJDIR = ./obj

SUBOBJDIRS=	\
		$(OBJDIR)/tos \
		$(OBJDIR)/tos/patches

INCLUDE=	-I$(INCDIR)
CFLAGS=		-m68060 -Wall -O2 -fomit-frame-pointer
CFLAGS_TOS=	-m68060 -Wall -O2 -fomit-frame-pointer

FLASH_BOOT=             0x00E80000
FLASH_DIAG=             0x00ED0000
FLASH_TOS=              0x00E00000

TOS=	   ct60tos.bin
TOSPCI=    ctpcitos.bin
ATARIDIAG= sparrow.out 
BOOT=         boot.hex
DIAG=         diag.hex
DRIVERS=      drivers.hex
GENTOS_BINARY= gentos.ttp
GENTOS_STACKSIZE= 64k

BOOT_OBJS=	\
		$(OBJDIR)/tos/version.o \
		$(OBJDIR)/tos/boot2.o \
		\
		$(OBJDIR)/tos/patches/start.o \
		$(OBJDIR)/tos/patches/boot.o \
		$(OBJDIR)/tos/patches/pmmu.o \
		$(OBJDIR)/tos/patches/cookies.o \
		$(OBJDIR)/tos/patches/dsp.o \
		$(OBJDIR)/tos/patches/periph.o \
		$(OBJDIR)/tos/patches/cache.o \
		$(OBJDIR)/tos/patches/movep.o \
		$(OBJDIR)/tos/patches/params.o \
		$(OBJDIR)/tos/patches/blitter.o \
		$(OBJDIR)/tos/patches/bios.o \
		$(OBJDIR)/tos/patches/xbios.o \
		$(OBJDIR)/tos/patches/gemdos.o \
		$(OBJDIR)/tos/patches/aes.o \
		$(OBJDIR)/tos/patches/vectors.o \
		$(OBJDIR)/tos/patches/videl.o \
		$(OBJDIR)/tos/patches/end.o \
		\
		$(OBJDIR)/tos/cache2.o \
		$(OBJDIR)/tos/movep2.o \
		$(OBJDIR)/tos/blitter2.o \
		$(OBJDIR)/tos/bios2.o \
		$(OBJDIR)/tos/conout.o \
		$(OBJDIR)/tos/xbios2.o \
		$(OBJDIR)/tos/gemdos2.o \
		$(OBJDIR)/tos/aes2.o \
		$(OBJDIR)/tos/vectors2.o \
		$(OBJDIR)/tos/ataboot.o \
		$(OBJDIR)/tos/extvidel.o \
		$(OBJDIR)/tos/magxboot.o \
		$(OBJDIR)/tos/pmmu2.o \
		$(OBJDIR)/tos/params2.o \
		$(OBJDIR)/tos/ide_scsi.o \
		$(OBJDIR)/tos/i2c.o \
		$(OBJDIR)/tos/temp.o \
		$(OBJDIR)/tos/fan.o \
		$(OBJDIR)/tos/lz.o \
		$(OBJDIR)/tos/LzmaDecode.o \
		$(OBJDIR)/tos/videl2.o

DIR =	./nonfree
FILES =	\
		$(DIR)/tos404.bin \
		$(BOOT) \
		$(DIR)/$(ATARIDIAG)

ct60:	$(GENTOS_BINARY) version.h $(BOOT) $(DRIVERS) $(DIAG) $(TOS) $(TOSPCI)

clean:
	rm -rf $(OBJDIR) $(GENTOS_BINARY) $(BOOT) $(TOS) $(TOSPCI) $(DIAG) boot.map
	make clean -C drivers

$(BOOT):	$(BOOT_OBJS)
	$(LD) --oformat srec -Map boot.map --cref -Ttext $(FLASH_BOOT) -s -o $(BOOT) $(BOOT_OBJS)

$(DRIVERS):	
	make ctpci -C drivers

$(DIAG): $(DIR)/$(ATARIDIAG)
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_DIAG) $(DIR)/$(ATARIDIAG) $(DIAG) 

$(TOS):	$(GENTOS_BINARY) $(FILES)
	./$(GENTOS_BINARY) $(FILES) $(TOS)

$(TOSPCI):	$(GENTOS_BINARY) $(FILES) ./drivers/$(DRIVERS)
	./$(GENTOS_BINARY) $(FILES) ./drivers/$(DRIVERS) $(TOSPCI)

version.h:
	@date -u +%e,%_m,%Y,%k,%_M > date.tmp
	@echo "#define VERSION" $(VERSION) > $(INCDIR)/version.h
	@echo "#define DATE \\" > version.tmp
	@cat version.tmp >> $(INCDIR)/version.h
	@cat date.tmp >> $(INCDIR)/version.h
	@rm version.tmp
	@rm date.tmp
	@touch -m $(SRCDIR)/tos/version.S

$(GENTOS_BINARY):	$(OBJDIR)/gentos.o $(OBJDIR)/srec.o
	$(CC) $(OBJDIR)/gentos.o $(OBJDIR)/srec.o -o $(GENTOS_BINARY)
	$(STRIP) $(GENTOS_BINARY)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARY)

define CREATEOBJDIRS
	@for d in $(OBJDIR) $(SUBOBJDIRS); do \
		if [ ! -d $$d ] ; then \
			mkdir $$d ; \
		fi ; \
	done
endef

$(OBJDIR)/tos/version.o:	$(SRCDIR)/tos/version.S $(INCDIR)/version.h
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/tos/xbios2.o:	$(SRCDIR)/tos/xbios2.S $(SRCDIR)/tos/pci_bios.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/tos/bios2.o:	$(SRCDIR)/tos/bios2.S $(SRCDIR)/tos/conout.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/tos/videl2.o:	$(SRCDIR)/tos/videl2.S $(SRCDIR)/tos/pic_boot.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIR)/tos/%.o:	$(SRCDIR)/tos/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/tos/%.o:	$(SRCDIR)/tos/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/tos/patches/%.o:	$(SRCDIR)/tos/patches/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@
