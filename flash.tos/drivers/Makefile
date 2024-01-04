CC = m68k-atari-mint-gcc
CC_TOOLS = m68k-atari-mint-gcc
LD = m68k-atari-mint-ld
STRIP = m68k-atari-mint-strip
STACK =	m68k-atari-mint-stack

CFLAGS = -m68060 -Os -fno-builtin -fomit-frame-pointer -fno-strict-aliasing -fno-inline-small-functions -Wall -Wno-multichar
CFLAGS_TOOLS = -m68060 -Os -fno-builtin -fomit-frame-pointer -Wall -Wno-multichar
LDFLAGS = -nostdlib -s

VERSION = 0x0102

ATICOD = ../nonfree/ativcm20.cod

SRCDIR = ./
INCDIR = ./include
INCDIRFVDI = ./fvdi/include
OBJDIR = ./obj

SUBOBJDIRS=	\
		$(OBJDIR)/tools \
		$(OBJDIR)/radeon \
		$(OBJDIR)/video \
		$(OBJDIR)/emulator \
		$(OBJDIR)/emulator/pcbios \
		$(OBJDIR)/emulator/x86emu \
		$(OBJDIR)/fvdi \
		$(OBJDIR)/fvdi/common \
		$(OBJDIR)/fvdi/1_plane \
		$(OBJDIR)/dma_utils \
		$(OBJDIR)/usb \
		$(OBJDIR)/cd \
		$(OBJDIR)/lwip \
		$(OBJDIR)/freertos

INCLUDE = -I$(INCDIR)
INCLUDEFVDI = -I$(INCDIRFVDI)
INCLUDEUSB = -I$(INCDIRUSB)

OBJSDRIVERFVDI=	\
		$(OBJDIR)/radeon/radeon_accel.o \
		$(OBJDIR)/radeon/radeon_render.o \
		$(OBJDIR)/radeon/radeon_pm.o \
		$(OBJDIR)/radeon/radeon_monitor.o \
		$(OBJDIR)/radeon/radeon_i2c.o \
		$(OBJDIR)/radeon/radeon_cursor.o \
		$(OBJDIR)/video/i2c-algo-bit.o \
		$(OBJDIR)/video/modedb.o \
		$(OBJDIR)/video/fbmem.o \
		$(OBJDIR)/video/fbmon.o \
		$(OBJDIR)/video/offscreen.o \
		$(OBJDIR)/video/1b_pal.o \
		$(OBJDIR)/video/8b_pal.o \
		$(OBJDIR)/video/16b_pal.o \
		$(OBJDIR)/video/32b_pal.o \
		$(OBJDIR)/video/access.o \
		$(OBJDIR)/video/debug.o \
		$(OBJDIR)/video/mouse.o \
		$(OBJDIR)/fvdi/common/init.o \
		$(OBJDIR)/fvdi/common/common.o \
		$(OBJDIR)/fvdi/common/c_common.o \
		$(OBJDIR)/fvdi/common/clip.o \
		$(OBJDIR)/fvdi/common/lineachk.o \
		$(OBJDIR)/fvdi/common/colours.o \
		$(OBJDIR)/fvdi/common/falc_pal.o \
		$(OBJDIR)/fvdi/1_plane/1_line.o \
		$(OBJDIR)/fvdi/1_plane/1_fill.o \
		$(OBJDIR)/gcc.o

OBJSLWIP=	\
		$(OBJDIR)/lwip/tcp_out.o \
		$(OBJDIR)/lwip/inet.o \
		$(OBJDIR)/lwip/chksum.o \
		$(OBJDIR)/lwip/mem.o \
		$(OBJDIR)/lwip/memp.o \
		$(OBJDIR)/lwip/netif.o \
		$(OBJDIR)/lwip/pbuf.o \
		$(OBJDIR)/lwip/raw.o \
		$(OBJDIR)/lwip/stats.o \
		$(OBJDIR)/lwip/sys.o \
		$(OBJDIR)/lwip/tcp.o \
		$(OBJDIR)/lwip/tcp_in.o \
		$(OBJDIR)/lwip/udp.o \
		$(OBJDIR)/lwip/ip.o \
		$(OBJDIR)/lwip/ip_addr.o \
		$(OBJDIR)/lwip/icmp.o \
		$(OBJDIR)/lwip/ip_frag.o \
		$(OBJDIR)/lwip/tcpip.o \
		$(OBJDIR)/lwip/api_msg.o \
		$(OBJDIR)/lwip/err.o \
		$(OBJDIR)/lwip/api_lib.o \
		$(OBJDIR)/lwip/loopif.o \
		$(OBJDIR)/lwip/sockets.o \
		$(OBJDIR)/lwip/etharp.o \
		$(OBJDIR)/lwip/resolv.o \
		$(OBJDIR)/lwip/sys_arch.o \
		$(OBJDIR)/lwip/rtl8139.o \
		$(OBJDIR)/lwip/gs_func.o \
		$(OBJDIR)/lwip/gs_mem.o \
		$(OBJDIR)/lwip/gs_stik.o \
		$(OBJDIR)/lwip/init.o
		
OBJSUSB=	\
		$(OBJDIR)/usb/usb.o \
		$(OBJDIR)/usb/ohci-hcd.o \
		$(OBJDIR)/usb/ehci-hcd.o \
		$(OBJDIR)/usb/usb_kbd.o \
		$(OBJDIR)/usb/usb_mouse.o \
		$(OBJDIR)/usb/usb_storage.o \
		$(OBJDIR)/usb/usb_mem.o \
		$(OBJDIR)/usb/cmd_usb.o
    
OBJSSCSI=	\
		$(OBJDIR)/cd/cd_scsi.o \
		$(OBJDIR)/cd/cd_disk.o \
		$(OBJDIR)/cd/cd_dos.o \
		$(OBJDIR)/cd/cd_iso.o

OBJSRTOS=	\
		$(OBJDIR)/freertos/tasks.o \
		$(OBJDIR)/freertos/queue.o \
		$(OBJDIR)/freertos/list.o \
		$(OBJDIR)/freertos/heap_2.o \
		$(OBJDIR)/freertos/port.o


OBJS=	\
		$(OBJDIR)/header.o \
		$(OBJDIR)/init.o \
		$(OBJDIR)/videocnf.o \
		$(OBJDIR)/gemform.o \
		$(OBJDIR)/xbios.o \
		$(OBJDIR)/detxbios.o \
		$(OBJDIR)/detgemdos.o \
		$(OBJDIR)/detlinea.o \
		$(OBJDIR)/detvdi.o \
		$(OBJDIR)/work.o \
		$(OBJDIR)/timer_rom.o \
		$(OBJDIR)/debug.o \
		$(OBJDIR)/m68k_disasm.o \
		$(OBJDIR)/emulator/biosemu.o \
		$(OBJDIR)/emulator/pcbios/pcibios.o \
		$(OBJDIR)/emulator/x86emu/debug.o \
		$(OBJDIR)/emulator/x86emu/decode.o \
		$(OBJDIR)/emulator/x86emu/fpu.o \
		$(OBJDIR)/emulator/x86emu/ops.o \
		$(OBJDIR)/emulator/x86emu/ops2.o \
		$(OBJDIR)/emulator/x86emu/prim_ops.o \
		$(OBJDIR)/emulator/x86emu/sys.o \
		$(OBJDIR)/fvdi/utility.o \
		$(OBJDIR)/fvdi/fonts.o \
		$(OBJDIR)/fvdi/text.o \
		$(OBJDIR)/fvdi/textrndr.o \
		$(OBJDIR)/fvdi/blit.o \
		$(OBJDIR)/fvdi/line.o \
		$(OBJDIR)/fvdi/draw.o \
		$(OBJDIR)/fvdi/polygon.o \
		$(OBJDIR)/fvdi/conic.o \
		$(OBJDIR)/fvdi/contourfill.o \
		$(OBJDIR)/fvdi/vdi_misc.o \
		$(OBJDIR)/video/accel_rom.o \
		$(OBJDIR)/video/spec_rom.o \
		$(OBJDIR)/radeon/radeon_base_rom.o \
		$(OBJDIR)/radeon/radeon_video.o \
		$(OBJDIR)/radeon/radeon_theatre_dsp.o \
		$(OBJDIR)/radeon/radeon_theatre.o \
		$(OBJDIR)/radeon/radeon_vid.o \
		$(OBJDIR)/dma_utils/dma_utils.o \
		$(OBJDIR)/stdlib.o \
		$(OBJDIR)/printk.o \
		$(OBJDIR)/malloc.o \
		$(OBJSUSB) \
		$(OBJSSCSI) \
		$(OBJSDRIVERFVDI)

HEX = drivers.hex
DRIVERFVDI = radeon.sys
FLASH_DRIVERS = 0xEC0000

BINHEX_BINARY= binhex.ttp
COMPRESS_BINARY= compress.ttp
STACKSIZE= 64k

ctpci: $(BINHEX_BINARY) $(COMPRESS_BINARY) version.h $(HEX) $(DRIVERFVDI)

clean:
	rm -rf $(OBJDIR)
	rm -f $(BINHEX_BINARY) $(COMPRESS_BINARY) $(HEX) drivers.map $(DRIVERFVDI)

$(HEX):	$(OBJS) $(OBJSRTOS) $(OBJSLWIP) 
	$(LD) --oformat srec -Map drivers.map --cref -T drivers.lk \
	--entry Start -o $(HEX) $(OBJS)
	#./$(COMPRESS_BINARY) $(HEX) temp.bin
	mv $(HEX) temp.bin
	objcopy --verbose -I binary -O srec --adjust-vma=$(FLASH_DRIVERS) temp.bin $(HEX)
	rm temp.bin 

$(DRIVERFVDI):	$(OBJDIR)/video/spec.o $(OBJDIR)/video/accel.o $(OBJDIR)/radeon/radeon_base.o $(OBJDIR)/timer.o $(OBJSDRIVERFVDI)
	$(LD) $(LDFLAGS) -o $(DRIVERFVDI) $(OBJDIR)/video/spec.o $(OBJDIR)/video/accel.o $(OBJDIR)/radeon/radeon_base.o $(OBJDIR)/timer.o $(OBJSDRIVERFVDI)
	$(STRIP) $(DRIVERFVDI)

version.h:
	@date -u +%e,%_m,%Y,%k,%_M > date.tmp
	@echo "#define VERSION" $(VERSION) > $(INCDIR)/version.h
	@echo "#define DATE \\" > version.tmp
	@cat version.tmp >> $(INCDIR)/version.h
	@cat date.tmp >> $(INCDIR)/version.h
	@rm version.tmp
	@rm date.tmp
	@touch -m $(SRCDIR)/header.S

$(BINHEX_BINARY):	$(OBJDIR)/tools/binhex.o
	$(CC_TOOLS) $(OBJDIR)/tools/binhex.o -o $(BINHEX_BINARY)
	$(STRIP) $(BINHEX_BINARY)
	$(STACK) -S $(STACKSIZE) $(BINHEX_BINARY)

$(COMPRESS_BINARY):	$(OBJDIR)/tools/compress.o $(OBJDIR)/tools/lz.o $(OBJDIR)/tools/LzmaEnc.o $(OBJDIR)/tools/LzFind.o $(OBJDIR)/tools/srec.o
	$(CC_TOOLS) $(OBJDIR)/tools//compress.o $(OBJDIR)/tools/lz.o $(OBJDIR)/tools/LzmaEnc.o $(OBJDIR)/tools/LzFind.o $(OBJDIR)/tools/srec.o -o $(COMPRESS_BINARY)
	$(STRIP) $(COMPRESS_BINARY)
	$(STACK) -S $(STACKSIZE) $(COMPRESS_BINARY)

define CREATEOBJDIRS
	@for d in $(OBJDIR) $(SUBOBJDIRS); do \
		if [ ! -d $$d ] ; then \
			mkdir $$d ; \
		fi ; \
	done
endef

$(OBJDIR)/tools/%.o:	$(SRCDIR)/tools/%.c
	$(CREATEOBJDIRS)
	$(CC_TOOLS) $(INCLUDE) $(CFLAGS_TOOLS) -c $< -o $@

$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/video/%.o:	$(SRCDIR)/video/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/1_plane/%.o:	$(SRCDIR)/fvdi/1_plane/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/1_plane/%.o:	$(SRCDIR)/fvdi/1_plane/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/%.o:	$(SRCDIR)/fvdi/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/%.o:	$(SRCDIR)/fvdi/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/usb/%.o:	$(SRCDIR)/usb/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

#$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.c
#	$(CREATEOBJDIRS)
#	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -Wa,-alhsd=x.ls -c $< -o $@

$(OBJDIR)/radeon/radeon_base_rom.o:	$(SRCDIR)/radeon/radeon_base.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/radeon/radeon_accel_rom.o:	$(SRCDIR)/radeon/radeon_accel.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(SRCDIR)/radeon/radeon_theatre_dsp.txt: $(ATICOD)
	./$(COMPRESS_BINARY) $< ./ati.bin
	./$(BINHEX_BINARY) ./ati.bin $< theatre_dsp
	@rm ati.bin

$(OBJDIR)/radeon/radeon_theatre_dsp.c: $(SRCDIR)/radeon/radeon_theatre_dsp.txt
	@echo "#include \"config.h\"" > $@
	@echo "#ifdef RADEON_THEATRE" >> $@
	@cat $< >> $@
	@echo "#endif" >> $@
#	@rm $(SRCDIR)/radeon/radeon_theatre_dsp.txt

$(OBJDIR)/radeon/radeon_theatre_dsp.o: $(OBJDIR)/radeon/radeon_theatre_dsp.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $(SRCDIR)/radeon/radeon_theatre_dsp.c -o $@

$(OBJDIR)/video/spec_rom.o:	$(SRCDIR)/video/spec.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/video/accel_rom.o:	$(SRCDIR)/video/accel.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/timer_rom.o:	$(SRCDIR)/timer.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@
