#CC = gcc
CC = /usr/local/bin/gcc
LD = ld
STRIP = strip
STACK =	stack

VERSION = 0x0202

FIREBEE_COD = ./nonfree/firebee1.rbf

SRCDIR = .
INCDIR = ./include
OBJDIR = ./obj
OBJDIRCF = ./obj_cf
OBJDIRCF2 = ./obj_cf2
OBJDIRCF3 = ./obj_cf3

SUBOBJDIRS=	\
		$(OBJDIR)/tos \
		$(OBJDIR)/tos/patches

SUBOBJDIRSCF=	\
		$(OBJDIRCF)/tos \
		$(OBJDIRCF)/tos/patches \
		$(OBJDIRCF)/desk \
		$(OBJDIRCF)/aes

SUBOBJDIRSCF2=	\
		$(OBJDIRCF2)/tos \
		$(OBJDIRCF2)/tos/patches

SUBOBJDIRSCF3=	\
		$(OBJDIRCF3)/tos \
		$(OBJDIRCF3)/tos/patches

INCLUDE=	-I$(INCDIR)
CFLAGS=		-m68060 -Wall -O2 -fomit-frame-pointer
CFLAGSCF=	-m5200 -Wall -O2 -fomit-frame-pointer -Wa,-m5200 -DCOLDFIRE
CFLAGSCF2=	$(CFLAGSCF) -DMCF5445X
CFLAGSCF3=	$(CFLAGSCF) -DMCF547X
CFLAGS_TOS=	-m68060 -Wall -O2 -fomit-frame-pointer
CFLAGSCF_TOS=	-m5200 -Wall -O2 -fomit-frame-pointer -Wa,-m5200 -DCOLDFIRE
CFLAGSCF2_TOS=	$(CFLAGSCF_TOS) -DMCF5445X
CFLAGSCF3_TOS=	$(CFLAGSCF_TOS) -DMCF547X
CFLAGSDESK=     -D_MINT_=0 -D_MORE_AV=0 -D_EDITLABELS=0 -D_OVSCAN=0 -D__USE_MACROS=0 -DCFGEMP=0 -DPALETTES=0 -D_PREDEF=0 -D_SHOWFIND=0 -D_MENUDEL=0 -D_FONT_SEL=0 -DAES_RECT=0 -D_LOGFILE=0

FLASH_BOOT=             0x00E80000
FLASH_DIAG=             0x00ED0000
FLASH_TOS=              0x00E00000
FLASH_TOS_FIRE_ENGINE=	0xFF900000
FLASH_TOS_M54455EVB=	0xC0000000
FLASH_BOOT_TOS_FIREBEE=	0xE0000000
FLASH_TOS_FIREBEE=	0xE0400000
FLASH_COD_FIREBEE=	0xE0700000

FLASH_CF68KLIB=         0x00E90000
FLASH_CF68KLIB2=        0x00E90000
FLASH_CF68KLIB3=        0x00E90000
FLASH_AES=              0x00E1F38A
FLASH2_AES=             0x00E5050A
RAM_AES=                0x8F9A

TOS=	   ct60tos.bin
TOSPCI=    ctpcitos.bin
ATARIDIAG= sparrow.out 
CF68KLIB=  cf68klib.hex
CF68KLIB2= cf68klib2.hex
CF68KLIB3= cf68klib3.hex
AESCF=     aes_m5484lite.hex
TOSCF=     firetos_m5484lite.bin
TOSCF2=    firetos_m54455evb.bin
TOSCF3=    firetos_firebee.bin
TOSCFHEX=  firetos_m5484lite.hex
TOSCFHEX2= firetos_m54455evb.hex
TOSCFHEX3= firetos_firebee.hex
TOSCFHEX3B= rescuetos_firebee.hex
BOOT=         boot.hex
BOOTCF=       boot_cf.hex
BOOTCF2=      boot_cf2.hex
BOOTCF3=      boot_cf3.hex
DIAG=         diag.hex
FPGACF3=      fpga_cf3.hex
DRIVERS=      drivers.hex
DRIVERSCF=    drivers_cf.hex
DRIVERSCF2=   drivers_cf2.hex
DRIVERSCF3=   drivers_cf3.hex
GENTOS_BINARY= gentos.ttp
GENTOS_BINARYCF= gentoscf.ttp
GENTOS_BINARYCF2= gentoscf2.ttp
GENTOS_BINARYCF3= gentoscf3.ttp
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

BOOT_OBJSCF=	\
		$(OBJDIRCF)/tos/version.o  \
		$(OBJDIRCF)/tos/boot2.o \
		\
		$(OBJDIRCF)/tos/patches/start.o \
		$(OBJDIRCF)/tos/patches/boot.o \
		$(OBJDIRCF)/tos/patches/pmmu.o \
		$(OBJDIRCF)/tos/patches/cookies.o \
		$(OBJDIRCF)/tos/patches/dsp.o \
		$(OBJDIRCF)/tos/patches/periph.o \
		$(OBJDIRCF)/tos/patches/cartridge.o \
		$(OBJDIRCF)/tos/patches/cache.o \
		$(OBJDIRCF)/tos/patches/movep.o \
		$(OBJDIRCF)/tos/patches/params.o \
		$(OBJDIRCF)/tos/patches/blitter.o \
		$(OBJDIRCF)/tos/patches/bios.o \
		$(OBJDIRCF)/tos/patches/xbios.o \
		$(OBJDIRCF)/tos/patches/gemdos.o \
		$(OBJDIRCF)/tos/patches/aes.o \
		$(OBJDIRCF)/tos/patches/vectors.o \
		$(OBJDIRCF)/tos/patches/videl.o \
		$(OBJDIRCF)/tos/patches/end.o \
		\
		$(OBJDIRCF)/tos/cache2.o \
		$(OBJDIRCF)/tos/movep2.o \
		$(OBJDIRCF)/tos/blitter2.o \
		$(OBJDIRCF)/tos/bios2.o \
		$(OBJDIRCF)/tos/conout.o \
		$(OBJDIRCF)/tos/xbios2.o \
		$(OBJDIRCF)/tos/gemdos2.o \
		$(OBJDIRCF)/tos/aes2.o \
		$(OBJDIRCF)/tos/vectors2.o \
		$(OBJDIRCF)/tos/pmmu2.o \
		$(OBJDIRCF)/tos/params2.o \
		$(OBJDIRCF)/tos/ide_scsi.o \
		$(OBJDIRCF)/tos/lz.o \
		$(OBJDIRCF)/tos/LzmaDecode.o \
		$(OBJDIRCF)/tos/videl2.o

BOOT_OBJSCF2=	\
		$(OBJDIRCF2)/tos/version.o \
		$(OBJDIRCF2)/tos/boot2.o \
		\
		$(OBJDIRCF)/tos/patches/start.o \
		$(OBJDIRCF2)/tos/patches/boot.o \
		$(OBJDIRCF)/tos/patches/pmmu.o \
		$(OBJDIRCF2)/tos/patches/cookies.o \
		$(OBJDIRCF)/tos/patches/dsp.o \
		$(OBJDIRCF)/tos/patches/periph.o \
		$(OBJDIRCF)/tos/patches/cartridge.o \
		$(OBJDIRCF)/tos/patches/cache.o \
		$(OBJDIRCF)/tos/patches/movep.o \
		$(OBJDIRCF)/tos/patches/params.o \
		$(OBJDIRCF)/tos/patches/blitter.o \
		$(OBJDIRCF)/tos/patches/bios.o \
		$(OBJDIRCF)/tos/patches/xbios.o \
		$(OBJDIRCF)/tos/patches/gemdos.o \
		$(OBJDIRCF)/tos/patches/aes.o \
		$(OBJDIRCF)/tos/patches/vectors.o \
		$(OBJDIRCF)/tos/patches/videl.o \
		$(OBJDIRCF)/tos/patches/end.o \
		\
		$(OBJDIRCF)/tos/cache2.o \
		$(OBJDIRCF)/tos/movep2.o \
		$(OBJDIRCF2)/tos/blitter2.o \
		$(OBJDIRCF2)/tos/bios2.o \
		$(OBJDIRCF2)/tos/conout.o \
		$(OBJDIRCF2)/tos/xbios2.o \
		$(OBJDIRCF2)/tos/gemdos2.o \
		$(OBJDIRCF2)/tos/aes2.o \
		$(OBJDIRCF2)/tos/vectors2.o \
		$(OBJDIRCF2)/tos/pmmu2.o \
		$(OBJDIRCF2)/tos/params2.o \
		$(OBJDIRCF2)/tos/ide_scsi.o \
		$(OBJDIRCF)/tos/lz.o \
		$(OBJDIRCF)/tos/LzmaDecode.o \
		$(OBJDIRCF2)/tos/videl2.o
		
BOOT_OBJSCF3=	\
		$(OBJDIRCF3)/tos/version.o \
		$(OBJDIRCF3)/tos/boot2.o \
		\
		$(OBJDIRCF)/tos/patches/start.o \
		$(OBJDIRCF3)/tos/patches/boot.o \
		$(OBJDIRCF)/tos/patches/pmmu.o \
		$(OBJDIRCF3)/tos/patches/cookies.o \
		$(OBJDIRCF)/tos/patches/dsp.o \
		$(OBJDIRCF)/tos/patches/periph.o \
		$(OBJDIRCF)/tos/patches/cartridge.o \
		$(OBJDIRCF)/tos/patches/cache.o \
		$(OBJDIRCF)/tos/patches/movep.o \
		$(OBJDIRCF)/tos/patches/params.o \
		$(OBJDIRCF)/tos/patches/blitter.o \
		$(OBJDIRCF)/tos/patches/bios.o \
		$(OBJDIRCF3)/tos/patches/xbios.o \
		$(OBJDIRCF)/tos/patches/gemdos.o \
		$(OBJDIRCF)/tos/patches/aes.o \
		$(OBJDIRCF)/tos/patches/vectors.o \
		$(OBJDIRCF3)/tos/patches/videl.o \
		$(OBJDIRCF)/tos/patches/end.o \
		\
		$(OBJDIRCF)/tos/cache2.o \
		$(OBJDIRCF)/tos/movep2.o \
		$(OBJDIRCF)/tos/blitter2.o \
		$(OBJDIRCF3)/tos/bios2.o \
		$(OBJDIRCF3)/tos/conout.o \
		$(OBJDIRCF3)/tos/xbios2.o \
		$(OBJDIRCF3)/tos/gemdos2.o \
		$(OBJDIRCF3)/tos/aes2.o \
		$(OBJDIRCF3)/tos/vectors2.o \
		$(OBJDIRCF3)/tos/pmmu2.o \
		$(OBJDIRCF3)/tos/params2.o \
		$(OBJDIRCF3)/tos/ide_scsi.o \
		$(OBJDIRCF)/tos/lz.o \
		$(OBJDIRCF)/tos/LzmaDecode.o \
		$(OBJDIRCF3)/tos/videl2.o
		
AES_OBJSCF=	\
		$(OBJDIRCF)/aes/gcc.o \
		$(OBJDIRCF)/aes/hard_dep.o \
		$(OBJDIRCF)/aes/trap_aes.o \
		$(OBJDIRCF)/aes/phandle3.o \
		$(OBJDIRCF)/aes/mouse2.o \
		$(OBJDIRCF)/aes/userdef2.o \
		$(OBJDIRCF)/aes/flagset2.o \
		$(OBJDIRCF)/aes/setjmp2.o \
		$(OBJDIRCF)/aes/aes_main.o \
		$(OBJDIRCF)/aes/initstru.o \
		$(OBJDIRCF)/aes/appl.o \
		$(OBJDIRCF)/aes/evnt.o \
		$(OBJDIRCF)/aes/form.o \
		$(OBJDIRCF)/aes/fsel.o \
		$(OBJDIRCF)/aes/graf.o \
		$(OBJDIRCF)/aes/menu.o \
		$(OBJDIRCF)/aes/objc.o \
		$(OBJDIRCF)/aes/rsrc2.o \
		$(OBJDIRCF)/aes/scrp.o \
		$(OBJDIRCF)/aes/shel.o \
		$(OBJDIRCF)/aes/wind.o \
		$(OBJDIRCF)/aes/utils.o \
		$(OBJDIRCF)/aes/wdlg.o \
		$(OBJDIRCF)/aes/pdlg.o \
		$(OBJDIRCF)/aes/memory.o \
		$(OBJDIRCF)/aes/myaesrsc.o \
		$(OBJDIRCF)/aes/config.o \
		$(OBJDIRCF)/aes/stdlib.o \
		$(OBJDIRCF)/aes/printk.o

DESK_OBJSCF=	\
		$(OBJDIRCF)/desk/deskstart.o \
		$(OBJDIRCF)/desk/deskmain.o \
		$(OBJDIRCF)/desk/config.o \
		$(OBJDIRCF)/desk/resource.o \
		$(OBJDIRCF)/desk/icon.o \
		$(OBJDIRCF)/desk/window.o \
		$(OBJDIRCF)/desk/copy.o \
		$(OBJDIRCF)/desk/printer.o \
		$(OBJDIRCF)/desk/lists.o \
		$(OBJDIRCF)/desk/applik.o \
		$(OBJDIRCF)/desk/prgtype.o \
		$(OBJDIRCF)/desk/icontype.o \
		$(OBJDIRCF)/desk/filetype.o \
		$(OBJDIRCF)/desk/screen.o \
		$(OBJDIRCF)/desk/showinfo.o \
		$(OBJDIRCF)/desk/font.o \
		$(OBJDIRCF)/desk/va.o \
		$(OBJDIRCF)/desk/dragdrop.o \
		$(OBJDIRCF)/desk/environm.o \
		$(OBJDIRCF)/desk/startprg.o \
		$(OBJDIRCF)/desk/floppy.o \
		$(OBJDIRCF)/desk/video.o \
		$(OBJDIRCF)/desk/file.o \
		$(OBJDIRCF)/desk/dir.o \
		$(OBJDIRCF)/desk/open.o \
		$(OBJDIRCF)/desk/viewer.o \
		$(OBJDIRCF)/desk/events.o \
		$(OBJDIRCF)/desk/slider.o \
		$(OBJDIRCF)/desk/stringf.o \
		$(OBJDIRCF)/desk/error.o \
		$(OBJDIRCF)/desk/xerror.o \
		$(OBJDIRCF)/desk/xfilesys.o \
		$(OBJDIRCF)/desk/xdialog.o \
		$(OBJDIRCF)/desk/xdnmdial.o \
		$(OBJDIRCF)/desk/xdevent.o \
		$(OBJDIRCF)/desk/xddraw.o \
		$(OBJDIRCF)/desk/xdutil.o \
		$(OBJDIRCF)/desk/xdemodes.o \
		$(OBJDIRCF)/desk/xwindow.o \
		$(OBJDIRCF)/desk/pathutil.o \
		$(OBJDIRCF)/desk/gettos.o \
		$(OBJDIRCF)/desk/strsncpy.o \
		$(OBJDIRCF)/desk/minmax.o \
		$(OBJDIRCF)/desk/other.o \
		$(OBJDIRCF)/desk/qsort.o \
		$(OBJDIRCF)/desk/getenv.o

DIR =	./nonfree
FILES =	\
		$(DIR)/tos404.bin \
		$(BOOT) \
		$(DIR)/$(ATARIDIAG)

#FILESCF =	\
#		$(DIR)/tos404.bin \
#		$(BOOT) \
#		$(DESKCF) \
#		$(AESCF) \
#		$(CF68KLIB)
		
FILESCF =	\
		$(DIR)/tos404.bin \
		$(BOOTCF) \
		$(CF68KLIB)

FILESCF2 =	\
		$(DIR)/tos404.bin \
		$(BOOTCF2) \
		$(CF68KLIB2)
		
FILESCF3 =	\
		$(DIR)/tos404.bin \
		$(BOOTCF3) \
		$(CF68KLIB3)
		
all:	$(GENTOS_BINARY) $(GENTOS_BINARYCF) $(GENTOS_BINARYCF2) $(GENTOS_BINARYCF3) version.h $(BOOT) $(BOOTCF) $(BOOTCF2) $(BOOTCF3) $(DIAG) $(DRIVERS) $(DRIVERSCF) $(DRIVERSCF2) $(DRIVERSCF3) \
	$(TOS) $(TOSPCI) $(CF68KLIB) $(CF68KLIB2) $(CF68KLIB3) $(TOSCF) $(TOSCF2) $(TOSCF3) $(TOSCFHEX) $(TOSCFHEX2) $(TOSCFHEX3)

ct60:	$(GENTOS_BINARY) version.h $(BOOT) $(DRIVERS) $(DIAG) $(TOS) $(TOSPCI)

m5484lite:	version.h $(GENTOS_BINARYCF) $(BOOTCF) $(DRIVERSCF) $(CF68KLIB) $(TOSCF) $(TOSCFHEX)
#m5484lite:	version.h $(GENTOS_BINARYCF) $(BOOTCF) $(DRIVERSCF) $(CF68KLIB) $(AESCF) $(TOSCF) $(TOSCFHEX)

m54455evb:	version.h $(GENTOS_BINARYCF2) $(BOOTCF2) $(DRIVERSCF2) $(CF68KLIB2) $(TOSCF2) $(TOSCFHEX2)

firebee:	version.h $(GENTOS_BINARYCF3) $(BOOTCF3) $(DRIVERSCF3) $(CF68KLIB3) $(TOSCF3) $(TOSCFHEX3)

clean:
	rm -rf $(OBJDIR) $(OBJDIRCF) $(OBJDIRCF2) $(OBJDIRCF3)
	rm -f $(GENTOS_BINARY) $(GENTOS_BINARYCF) $(GENTOS_BINARYCF2) $(GENTOS_BINARYCF3) $(BOOT) $(BOOTCF) $(BOOTCF2) $(BOOTCF3) $(CF68KLIB) $(CF68KLIB2) $(CF68KLIB3) \
	$(TOS) $(TOSPCI) $(TOSCF) $(TOSCF2) $(TOSCF3) $(TOSCFHEX) $(TOSCFHEX2) $(TOSCFHEX3) $(TOSCFHEX3B) $(DIAG) $(FPGACF3) boot.map boot_cf.map boot_cf2.map boot_cf3.map  
	make clean -C drivers

$(BOOT):	$(BOOT_OBJS)
	$(LD) --oformat srec -Map boot.map --cref -Ttext $(FLASH_BOOT) -s -o $(BOOT) $(BOOT_OBJS)

$(BOOTCF):	$(BOOT_OBJSCF)
	$(LD) --oformat srec -Map boot_cf.map --cref -Ttext $(FLASH_BOOT) -s -o $(BOOTCF) $(BOOT_OBJSCF)

$(BOOTCF2):	$(BOOT_OBJSCF2)
	$(LD) --oformat srec -Map boot_cf2.map --cref -Ttext $(FLASH_BOOT) -s -o $(BOOTCF2) $(BOOT_OBJSCF2)

$(BOOTCF3):	$(BOOT_OBJSCF3)
	$(LD) --oformat srec -Map boot_cf3.map --cref -Ttext $(FLASH_BOOT) -s -o $(BOOTCF3) $(BOOT_OBJSCF3)

$(DRIVERS):	
	make ctpci -C drivers

$(CF68KLIB):	$(OBJDIRCF)/tos/cf68klib.o
	$(LD) --oformat srec -Ttext $(FLASH_CF68KLIB) -s -o $(CF68KLIB) $(OBJDIRCF)/tos/cf68klib.o

$(CF68KLIB2):	$(OBJDIRCF2)/tos/cf68klib.o
	$(LD) --oformat srec -Ttext $(FLASH_CF68KLIB2) -s -o $(CF68KLIB2) $(OBJDIRCF2)/tos/cf68klib.o

$(CF68KLIB3):	$(OBJDIRCF3)/tos/cf68klib.o
	$(LD) --oformat srec -Ttext $(FLASH_CF68KLIB3) -s -o $(CF68KLIB3) $(OBJDIRCF3)/tos/cf68klib.o

$(AESCF):	$(AES_OBJSCF) $(DESK_OBJSCF)
	$(LD) --oformat srec -Ttext $(FLASH_AES) -Tdata $(FLASH2_AES) -Tbss $(RAM_AES) -Map aescf.map --cref -o $(AESCF) $(AES_OBJSCF) -lgem

$(DIAG): $(DIR)/$(ATARIDIAG)
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_DIAG) $(DIR)/$(ATARIDIAG) $(DIAG) 

$(TOS):	$(GENTOS_BINARY) $(FILES)
	./$(GENTOS_BINARY) $(FILES) $(TOS)

$(TOSPCI):	$(GENTOS_BINARY) $(FILES) ./drivers/$(DRIVERS)
	./$(GENTOS_BINARY) $(FILES) ./drivers/$(DRIVERS) $(TOSPCI)

$(TOSCF):	$(GENTOS_BINARYCF) $(FILESCF) ./drivers/$(DRIVERSCF)
	./$(GENTOS_BINARYCF) $(FILESCF) ./drivers/$(DRIVERSCF) $(TOSCF)

$(TOSCF2):	$(GENTOS_BINARYCF2) $(FILESCF2) ./drivers/$(DRIVERSCF2)
	./$(GENTOS_BINARYCF2) $(FILESCF2) ./drivers/$(DRIVERSCF2) $(TOSCF2)

$(TOSCF3):	$(GENTOS_BINARYCF3) $(FILESCF3) ./drivers/$(DRIVERSCF3)
	./$(GENTOS_BINARYCF3) $(FILESCF3) ./drivers/$(DRIVERSCF3) $(TOSCF3)

$(TOSCFHEX):	$(TOSCF)
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_TOS_FIRE_ENGINE) $(TOSCF) $(TOSCFHEX)
	cp  $(TOSCFHEX) /home/firetos.hex

$(TOSCFHEX2):	$(TOSCF2)
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_TOS_M54455EVB) $(TOSCF2) $(TOSCFHEX2)
	cp  $(TOSCFHEX2) /home/firetos.hex

$(TOSCFHEX3):	$(TOSCF3)
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_TOS_FIREBEE) $(TOSCF3) $(TOSCFHEX3)
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_BOOT_TOS_FIREBEE) $(TOSCF3) $(TOSCFHEX3B)
# FIREBEE_COD added, if INIT_FPGA_FROM_RAM defined inside boot2.S
#	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_COD_FIREBEE) $(FIREBEE_COD) $(FPGACF3)
#	@grep -E -v S7 $(TOSCFHEX3) > temp.hex
#	@grep -E S3 $(FPGACF3) > temp2.hex
#	@echo "S705E0400000DA" > temp3.hex
#	@cat temp.hex temp2.hex temp3.hex > /home/firetos.hex
#	@rm temp.hex temp2.hex temp3.hex
	cp  $(TOSCFHEX3) /home/firetos.hex

$(DRIVERSCF):	
	make m5484lite -C drivers

$(DRIVERSCF2):	
	make m54455evb -C drivers
	
$(DRIVERSCF3):	
	make firebee -C drivers

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

$(GENTOS_BINARYCF):	$(OBJDIRCF)/gentos.o $(OBJDIRCF)/srec.o
	$(CC) $(OBJDIRCF)/gentos.o $(OBJDIRCF)/srec.o -o $(GENTOS_BINARYCF)
	$(STRIP) $(GENTOS_BINARYCF)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARYCF)

$(GENTOS_BINARYCF2):	$(OBJDIRCF2)/gentos.o $(OBJDIRCF)/srec.o
	$(CC) $(OBJDIRCF2)/gentos.o $(OBJDIRCF)/srec.o -o $(GENTOS_BINARYCF2)
	$(STRIP) $(GENTOS_BINARYCF2)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARYCF2)

$(GENTOS_BINARYCF3):	$(OBJDIRCF3)/gentos.o $(OBJDIRCF)/srec.o
	$(CC) $(OBJDIRCF3)/gentos.o $(OBJDIRCF)/srec.o -o $(GENTOS_BINARYCF3)
	$(STRIP) $(GENTOS_BINARYCF3)
	$(STACK) -S $(GENTOS_STACKSIZE) $(GENTOS_BINARYCF3)

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

$(OBJDIR)/tos/patches/%.o:	$(SRCDIR)/tos/patches/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS_TOS) -c $< -o $@

$(OBJDIRCF)/tos/patches/%.o:	$(SRCDIR)/tos/patches/%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -c $< -o $@

$(OBJDIRCF2)/tos/patches/%.o:	$(SRCDIR)/tos/patches/%.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2_TOS) -c $< -o $@

$(OBJDIRCF3)/tos/patches/%.o:	$(SRCDIR)/tos/patches/%.S
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

$(OBJDIRCF)/aes/%.o:	$(SRCDIR)/aes/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -fno-builtin -Wno-multichar -c $< -o $@

$(OBJDIRCF)/aes/%o:	$(SRCDIR)/aes/%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) -fno-builtin -Wno-multichar -c $< -o $@

$(OBJDIRCF)/desk/%.o:	$(SRCDIR)/desk/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) $(CFLAGSDESK) -fno-builtin -Wno-multichar -c $< -o $@

$(OBJDIRCF)/desk/%o:	$(SRCDIR)/desk/%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF_TOS) $(CFLAGSDESK) -fno-builtin -Wno-multichar -c $< -o $@
	
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
