TOP_DIR		= ..

include $(TOP_DIR)/CONFIGVARS

SRCDIR = .
INCDIR = ./include
INCDIRFVDI = ./fvdi/include
OBJDIR = ./obj
OBJDIRCF = ./obj_cf
OBJDIRCF2 = ./obj_cf2
OBJDIRCF3 = ./obj_cf3

SUBOBJDIRS=	\
		$(OBJDIR)/radeon \
		$(OBJDIR)/emulator \
		$(OBJDIR)/emulator/pcbios \
		$(OBJDIR)/emulator/x86emu \
		$(OBJDIR)/fvdi \
		$(OBJDIR)/fvdi/common \
		$(OBJDIR)/dma_utils \
		$(OBJDIR)/usb

SUBOBJDIRSCF=	\
		$(OBJDIRCF)/radeon \
		$(OBJDIRCF)/emulator \
		$(OBJDIRCF)/emulator/pcbios \
		$(OBJDIRCF)/emulator/x86emu \
		$(OBJDIRCF)/fvdi \
		$(OBJDIRCF)/fvdi/common \
		$(OBJDIRCF)/mcdapi \
		$(OBJDIRCF)/dma_utils \
		$(OBJDIRCF)/net \
		$(OBJDIRCF)/lwip \
		$(OBJDIRCF)/usb_dev \
		$(OBJDIRCF)/usb \
		$(OBJDIRCF)/ac97 \
		$(OBJDIRCF)/rtc \
		$(OBJDIRCF)/bdos \
		$(OBJDIRCF)/freertos

SUBOBJDIRSCF2=	\
		$(OBJDIRCF2)/radeon \
		$(OBJDIRCF2)/emulator \
		$(OBJDIRCF2)/emulator/pcbios \
		$(OBJDIRCF2)/emulator/x86emu \
		$(OBJDIRCF2)/fvdi \
		$(OBJDIRCF2)/fvdi/common \
		$(OBJDIRCF2)/dma_utils \
		$(OBJDIRCF2)/net \
		$(OBJDIRCF2)/lwip \
		$(OBJDIRCF2)/usb \
		$(OBJDIRCF2)/bdos \
		$(OBJDIRCF2)/freertos

SUBOBJDIRSCF3=	\
		$(OBJDIRCF3)/radeon \
		$(OBJDIRCF3)/emulator \
		$(OBJDIRCF3)/emulator/pcbios \
		$(OBJDIRCF3)/emulator/x86emu \
		$(OBJDIRCF3)/fvdi \
		$(OBJDIRCF3)/fvdi/common \
		$(OBJDIRCF3)/mcdapi \
		$(OBJDIRCF3)/dma_utils \
		$(OBJDIRCF3)/net \
		$(OBJDIRCF3)/lwip \
		$(OBJDIRCF3)/usb \
		$(OBJDIRCF3)/ac97 \
		$(OBJDIRCF3)/bdos \
		$(OBJDIRCF3)/freertos

INCLUDE = -I$(INCDIR)
INCLUDEFVDI = -I$(INCDIRFVDI)
INCLUDEUSB = -I$(INCDIRUSB)
CFLAGS = -m68060 -Os -fno-builtin -fomit-frame-pointer -Wall -Wno-multichar -g
CFLAGSCF = -m5200 -Os -fno-builtin -fomit-frame-pointer -Wall -Wno-multichar -g -Wa,-m5200 -DCOLDFIRE
CFLAGSCF2 = $(CFLAGSCF) -DMCF5445X
CFLAGSCF3 = $(CFLAGSCF) -DMCF547X
LDFLAGS = -nostdlib --entry _init -s

OBJSDRIVERFVDI=	\
		$(OBJDIR)/radeon/mouse.o \
		$(OBJDIR)/radeon/8b_pal.o \
		$(OBJDIR)/radeon/16b_pal.o \
		$(OBJDIR)/radeon/32b_pal.o \
		$(OBJDIR)/radeon/radeon_accel.o \
		$(OBJDIR)/radeon/radeon_render.o \
		$(OBJDIR)/radeon/radeon_pm.o \
		$(OBJDIR)/radeon/radeon_monitor.o \
		$(OBJDIR)/radeon/radeon_i2c.o \
		$(OBJDIR)/radeon/radeon_cursor.o \
		$(OBJDIR)/radeon/radeon_mem.o \
		$(OBJDIR)/radeon/i2c-algo-bit.o \
		$(OBJDIR)/radeon/modedb.o \
		$(OBJDIR)/radeon/fbmem.o \
		$(OBJDIR)/radeon/fbmon.o \
		$(OBJDIR)/radeon/access.o \
		$(OBJDIR)/radeon/videl_test.o \
		$(OBJDIR)/fvdi/common/init.o \
		$(OBJDIR)/fvdi/common/common.o \
		$(OBJDIR)/fvdi/common/c_common.o \
		$(OBJDIR)/fvdi/common/clip.o \
		$(OBJDIR)/fvdi/common/lineachk.o \
		$(OBJDIR)/fvdi/common/colours.o \
		$(OBJDIR)/fvdi/common/falc_pal.o \
		$(OBJDIR)/gcc.o

OBJSDRIVERFVDICF=	\
		$(OBJDIRCF)/radeon/mouse.o \
		$(OBJDIRCF)/radeon/8b_pal.o \
		$(OBJDIRCF)/radeon/16b_pal.o \
		$(OBJDIRCF)/radeon/32b_pal.o \
		$(OBJDIRCF)/radeon/radeon_accel.o \
		$(OBJDIRCF)/radeon/radeon_render.o \
		$(OBJDIRCF)/radeon/radeon_pm.o \
		$(OBJDIRCF)/radeon/radeon_monitor.o \
		$(OBJDIRCF)/radeon/radeon_i2c.o \
		$(OBJDIRCF)/radeon/radeon_cursor.o \
		$(OBJDIRCF)/radeon/radeon_mem.o \
		$(OBJDIRCF)/radeon/i2c-algo-bit.o \
		$(OBJDIRCF)/radeon/modedb.o \
		$(OBJDIRCF)/radeon/fbmem.o \
		$(OBJDIRCF)/radeon/fbmon.o \
		$(OBJDIRCF)/radeon/access.o \
		$(OBJDIRCF)/fvdi/common/init.o \
		$(OBJDIR)/fvdi/common/common.o \
		$(OBJDIRCF)/fvdi/common/c_common.o \
		$(OBJDIRCF)/fvdi/common/clip.o \
		$(OBJDIRCF)/fvdi/common/lineachk.o \
		$(OBJDIRCF)/fvdi/common/colours.o \
		$(OBJDIRCF)/fvdi/common/falc_pal.o \
		$(OBJDIRCF)/gcc.o

OBJSDRIVERFVDICF2=	\
		$(OBJDIRCF)/radeon/mouse.o \
		$(OBJDIRCF)/radeon/8b_pal.o \
		$(OBJDIRCF)/radeon/16b_pal.o \
		$(OBJDIRCF)/radeon/32b_pal.o \
		$(OBJDIRCF2)/radeon/radeon_accel.o \
		$(OBJDIRCF)/radeon/radeon_pm.o \
		$(OBJDIRCF)/radeon/radeon_monitor.o \
		$(OBJDIRCF)/radeon/radeon_i2c.o \
		$(OBJDIRCF)/radeon/radeon_cursor.o \
		$(OBJDIRCF)/radeon/radeon_mem.o \
		$(OBJDIRCF)/radeon/i2c-algo-bit.o \
		$(OBJDIRCF)/radeon/modedb.o \
		$(OBJDIRCF)/radeon/fbmem.o \
		$(OBJDIRCF)/radeon/fbmon.o \
		$(OBJDIRCF)/radeon/access.o \
		$(OBJDIRCF)/fvdi/common/init.o \
		$(OBJDIR)/fvdi/common/common.o \
		$(OBJDIRCF)/fvdi/common/c_common.o \
		$(OBJDIRCF)/fvdi/common/clip.o \
		$(OBJDIRCF)/fvdi/common/lineachk.o \
		$(OBJDIRCF)/fvdi/common/colours.o \
		$(OBJDIRCF)/fvdi/common/falc_pal.o \
		$(OBJDIRCF2)/gcc.o

OBJSDRIVERFVDICF3=	\
		$(OBJDIRCF)/radeon/mouse.o \
		$(OBJDIRCF)/radeon/8b_pal.o \
		$(OBJDIRCF)/radeon/16b_pal.o \
		$(OBJDIRCF)/radeon/32b_pal.o \
		$(OBJDIRCF)/radeon/radeon_accel.o \
		$(OBJDIRCF)/radeon/radeon_render.o \
		$(OBJDIRCF)/radeon/radeon_pm.o \
		$(OBJDIRCF)/radeon/radeon_monitor.o \
		$(OBJDIRCF)/radeon/radeon_i2c.o \
		$(OBJDIRCF)/radeon/radeon_cursor.o \
		$(OBJDIRCF)/radeon/radeon_mem.o \
		$(OBJDIRCF)/radeon/i2c-algo-bit.o \
		$(OBJDIRCF)/radeon/modedb.o \
		$(OBJDIRCF)/radeon/fbmem.o \
		$(OBJDIRCF)/radeon/fbmon.o \
		$(OBJDIRCF)/radeon/access.o \
		$(OBJDIRCF)/fvdi/common/init.o \
		$(OBJDIR)/fvdi/common/common.o \
		$(OBJDIRCF)/fvdi/common/c_common.o \
		$(OBJDIRCF)/fvdi/common/clip.o \
		$(OBJDIRCF)/fvdi/common/lineachk.o \
		$(OBJDIRCF)/fvdi/common/colours.o \
		$(OBJDIRCF)/fvdi/common/falc_pal.o \
		$(OBJDIRCF)/gcc.o

OBJSNETCF=	\
		$(OBJDIRCF)/net/tftp.o \
		$(OBJDIRCF)/net/ip.o \
		$(OBJDIRCF)/net/arp.o \
		$(OBJDIRCF)/net/icmp.o \
		$(OBJDIRCF)/net/udp.o \
		$(OBJDIRCF)/net/net_timer.o \
		$(OBJDIRCF)/net/queue.o \
		$(OBJDIRCF)/net/nbuf.o \
		$(OBJDIRCF)/net/nif.o \
		$(OBJDIRCF)/net/fec.o \
		$(OBJDIRCF)/net/fecbd.o \
		$(OBJDIRCF)/net/bcm5222.o \
		$(OBJDIRCF)/net/init.o

OBJSNETCF2=	\
		$(OBJDIRCF2)/net/tftp.o \
		$(OBJDIRCF2)/net/ip.o \
		$(OBJDIRCF2)/net/arp.o \
		$(OBJDIRCF2)/net/icmp.o \
		$(OBJDIRCF2)/net/udp.o \
		$(OBJDIRCF2)/net/net_timer.o \
		$(OBJDIRCF2)/net/queue.o \
		$(OBJDIRCF2)/net/nbuf.o \
		$(OBJDIRCF2)/net/nif.o \
		$(OBJDIRCF2)/net/fec.o \
		$(OBJDIRCF2)/net/fecbd.o \
		$(OBJDIRCF2)/net/init.o

OBJSNETCF3=	\
		$(OBJDIRCF)/net/tftp.o \
		$(OBJDIRCF)/net/ip.o \
		$(OBJDIRCF)/net/arp.o \
		$(OBJDIRCF)/net/icmp.o \
		$(OBJDIRCF)/net/udp.o \
		$(OBJDIRCF)/net/net_timer.o \
		$(OBJDIRCF)/net/queue.o \
		$(OBJDIRCF)/net/nbuf.o \
		$(OBJDIRCF)/net/nif.o \
		$(OBJDIRCF3)/net/fec.o \
		$(OBJDIRCF3)/net/fecbd.o \
		$(OBJDIRCF3)/net/am79c874.o \
		$(OBJDIRCF3)/net/init.o


OBJSLWIPCF=	\
		$(OBJDIRCF)/lwip/tcp_out.o \
		$(OBJDIRCF)/lwip/inet.o \
		$(OBJDIRCF)/lwip/chksum.o \
		$(OBJDIRCF)/lwip/mem.o \
		$(OBJDIRCF)/lwip/memp.o \
		$(OBJDIRCF)/lwip/netif.o \
		$(OBJDIRCF)/lwip/pbuf.o \
		$(OBJDIRCF)/lwip/raw.o \
		$(OBJDIRCF)/lwip/stats.o \
		$(OBJDIRCF)/lwip/sys.o \
		$(OBJDIRCF)/lwip/tcp.o \
		$(OBJDIRCF)/lwip/tcp_in.o \
		$(OBJDIRCF)/lwip/udp.o \
		$(OBJDIRCF)/lwip/ip.o \
		$(OBJDIRCF)/lwip/ip_addr.o \
		$(OBJDIRCF)/lwip/icmp.o \
		$(OBJDIRCF)/lwip/ip_frag.o \
		$(OBJDIRCF)/lwip/tcpip.o \
		$(OBJDIRCF)/lwip/api_msg.o \
		$(OBJDIRCF)/lwip/err.o \
		$(OBJDIRCF)/lwip/api_lib.o \
		$(OBJDIRCF)/lwip/loopif.o \
		$(OBJDIRCF)/lwip/sockets.o \
		$(OBJDIRCF)/lwip/etharp.o \
		$(OBJDIRCF)/lwip/resolv.o \
		$(OBJDIRCF)/lwip/sys_arch.o \
		$(OBJDIRCF)/lwip/nbuf.o \
		$(OBJDIRCF)/lwip/fec.o \
		$(OBJDIRCF)/lwip/bcm5222.o \
		$(OBJDIRCF)/lwip/gs_func.o \
		$(OBJDIRCF)/lwip/gs_mem.o \
		$(OBJDIRCF)/lwip/gs_stik.o \
		$(OBJDIRCF)/lwip/intel_c3_flash.o \
		$(OBJDIRCF)/lwip/tftp.o \
		$(OBJDIRCF)/lwip/ftpd.o \
		$(OBJDIRCF)/lwip/web.o \
		$(OBJDIRCF)/lwip/gif.o \
		$(OBJDIRCF)/lwip/init.o \
		$(OBJDIRCF)/dma_utils/dma_utils.o \
		$(OBJDIRCF)/mcdapi/MCD_dmaApi.o \
		$(OBJDIRCF)/mcdapi/MCD_tasksInit.o \
		$(OBJDIRCF)/mcdapi/MCD_tasks.o \
		$(OBJDIRCF)/bdos/bdos.o \
		$(OBJDIRCF)/stdlib.o \
		$(OBJDIRCF)/printk.o

OBJSLWIPCF2=	\
		$(OBJDIRCF)/lwip/tcp_out.o \
		$(OBJDIRCF)/lwip/inet.o \
		$(OBJDIRCF)/lwip/chksum.o \
		$(OBJDIRCF)/lwip/mem.o \
		$(OBJDIRCF)/lwip/memp.o \
		$(OBJDIRCF)/lwip/netif.o \
		$(OBJDIRCF2)/lwip/pbuf.o \
		$(OBJDIRCF)/lwip/raw.o \
		$(OBJDIRCF)/lwip/stats.o \
		$(OBJDIRCF)/lwip/sys.o \
		$(OBJDIRCF)/lwip/tcp.o \
		$(OBJDIRCF2)/lwip/tcp_in.o \
		$(OBJDIRCF2)/lwip/udp.o \
		$(OBJDIRCF2)/lwip/ip.o \
		$(OBJDIRCF)/lwip/ip_addr.o \
		$(OBJDIRCF)/lwip/icmp.o \
		$(OBJDIRCF)/lwip/ip_frag.o \
		$(OBJDIRCF)/lwip/tcpip.o \
		$(OBJDIRCF)/lwip/api_msg.o \
		$(OBJDIRCF)/lwip/err.o \
		$(OBJDIRCF)/lwip/api_lib.o \
		$(OBJDIRCF)/lwip/loopif.o \
		$(OBJDIRCF)/lwip/sockets.o \
		$(OBJDIRCF)/lwip/etharp.o \
		$(OBJDIRCF)/lwip/resolv.o \
		$(OBJDIRCF2)/lwip/sys_arch.o \
		$(OBJDIRCF2)/lwip/nbuf.o \
		$(OBJDIRCF2)/lwip/fec.o \
		$(OBJDIRCF2)/lwip/dp83849.o \
		$(OBJDIRCF)/lwip/gs_func.o \
		$(OBJDIRCF)/lwip/gs_mem.o \
		$(OBJDIRCF)/lwip/gs_stik.o \
		$(OBJDIRCF2)/lwip/flash.o \
		$(OBJDIRCF)/lwip/tftp.o \
		$(OBJDIRCF)/lwip/ftpd.o \
		$(OBJDIRCF2)/lwip/web.o \
		$(OBJDIRCF)/lwip/gif.o \
		$(OBJDIRCF2)/lwip/init.o \
		$(OBJDIRCF2)/dma_utils/dma_utils.o \
		$(OBJDIRCF)/bdos/bdos.o \
		$(OBJDIRCF2)/stdlib.o \
		$(OBJDIRCF)/printk.o

OBJSLWIPCF3=	\
		$(OBJDIRCF)/lwip/tcp_out.o \
		$(OBJDIRCF)/lwip/inet.o \
		$(OBJDIRCF)/lwip/chksum.o \
		$(OBJDIRCF)/lwip/mem.o \
		$(OBJDIRCF)/lwip/memp.o \
		$(OBJDIRCF)/lwip/netif.o \
		$(OBJDIRCF)/lwip/pbuf.o \
		$(OBJDIRCF)/lwip/raw.o \
		$(OBJDIRCF)/lwip/stats.o \
		$(OBJDIRCF)/lwip/sys.o \
		$(OBJDIRCF)/lwip/tcp.o \
		$(OBJDIRCF)/lwip/tcp_in.o \
		$(OBJDIRCF)/lwip/udp.o \
		$(OBJDIRCF)/lwip/ip.o \
		$(OBJDIRCF)/lwip/ip_addr.o \
		$(OBJDIRCF)/lwip/icmp.o \
		$(OBJDIRCF)/lwip/ip_frag.o \
		$(OBJDIRCF)/lwip/tcpip.o \
		$(OBJDIRCF)/lwip/api_msg.o \
		$(OBJDIRCF)/lwip/err.o \
		$(OBJDIRCF)/lwip/api_lib.o \
		$(OBJDIRCF)/lwip/loopif.o \
		$(OBJDIRCF)/lwip/sockets.o \
		$(OBJDIRCF)/lwip/etharp.o \
		$(OBJDIRCF)/lwip/resolv.o \
		$(OBJDIRCF)/lwip/sys_arch.o \
		$(OBJDIRCF)/lwip/nbuf.o \
		$(OBJDIRCF3)/lwip/fec.o \
		$(OBJDIRCF3)/lwip/am79c874.o \
		$(OBJDIRCF)/lwip/gs_func.o \
		$(OBJDIRCF)/lwip/gs_mem.o \
		$(OBJDIRCF)/lwip/gs_stik.o \
		$(OBJDIRCF3)/lwip/amd_flash.o \
		$(OBJDIRCF)/lwip/tftp.o \
		$(OBJDIRCF)/lwip/ftpd.o \
		$(OBJDIRCF3)/lwip/web.o \
		$(OBJDIRCF)/lwip/gif.o \
		$(OBJDIRCF3)/lwip/init.o \
		$(OBJDIRCF)/dma_utils/dma_utils.o \
		$(OBJDIRCF)/mcdapi/MCD_dmaApi.o \
		$(OBJDIRCF)/mcdapi/MCD_tasksInit.o \
		$(OBJDIRCF)/mcdapi/MCD_tasks.o \
		$(OBJDIRCF)/bdos/bdos.o \
		$(OBJDIRCF)/stdlib.o \
		$(OBJDIRCF)/printk.o \

OBJSBUSB=

OBJSBUSBCF=	\
		$(OBJDIRCF)/usb_dev/msc.o \
		$(OBJDIRCF)/usb_dev/msc_desc.o \
		$(OBJDIRCF)/usb_dev/usb.o

OBJSBUSBCF2=

OBJSBUSBCF3=

OBJSAC97CF=	\
		$(OBJDIRCF)/ac97/control.o \
		$(OBJDIRCF)/ac97/ac97_codec.o \
		$(OBJDIRCF)/ac97/mcf548x_ac97.o

OBJSAC97CF3=	\
		$(OBJDIRCF)/ac97/control.o \
		$(OBJDIRCF)/ac97/ac97_codec.o \
		$(OBJDIRCF)/ac97/mcf548x_ac97.o

OBJSBDOSCF=	\
		$(OBJDIRCF)/bdos/fsbuf.o \
		$(OBJDIRCF)/bdos/fsfat.o \
		$(OBJDIRCF)/bdos/fsio.o \
		$(OBJDIRCF)/bdos/fsdir.o \
		$(OBJDIRCF)/bdos/fsglob.o \
		$(OBJDIRCF)/bdos/fsmain.o \
		$(OBJDIRCF)/bdos/fsdrive.o \
		$(OBJDIRCF)/bdos/fshand.o \
		$(OBJDIRCF)/bdos/fsopnclo.o \
		$(OBJDIRCF)/bdos/osmem.o \
		$(OBJDIRCF)/bdos/umem.o \
		$(OBJDIRCF)/bdos/iumem.o \
		$(OBJDIRCF)/bdos/console.o \
		$(OBJDIRCF)/bdos/bdosmain.o \
		$(OBJDIRCF)/bdos/proc.o \
		$(OBJDIRCF)/bdos/kpgmld.o \
		$(OBJDIRCF)/bdos/time.o \
		$(OBJDIRCF)/bdos/rwa.o \
		$(OBJDIRCF)/bdos/setjmp.o

OBJSBDOSCF2=	\
		$(OBJDIRCF)/bdos/fsbuf.o \
		$(OBJDIRCF)/bdos/fsfat.o \
		$(OBJDIRCF)/bdos/fsio.o \
		$(OBJDIRCF)/bdos/fsdir.o \
		$(OBJDIRCF)/bdos/fsglob.o \
		$(OBJDIRCF)/bdos/fsmain.o \
		$(OBJDIRCF)/bdos/fsdrive.o \
		$(OBJDIRCF)/bdos/fshand.o \
		$(OBJDIRCF)/bdos/fsopnclo.o \
		$(OBJDIRCF)/bdos/osmem.o \
		$(OBJDIRCF)/bdos/umem.o \
		$(OBJDIRCF)/bdos/iumem.o \
		$(OBJDIRCF)/bdos/console.o \
		$(OBJDIRCF)/bdos/bdosmain.o \
		$(OBJDIRCF)/bdos/proc.o \
		$(OBJDIRCF)/bdos/kpgmld.o \
		$(OBJDIRCF)/bdos/time.o \
		$(OBJDIRCF)/bdos/rwa.o \
		$(OBJDIRCF)/bdos/setjmp.o

OBJSBDOSCF3=	\
		$(OBJDIRCF)/bdos/fsbuf.o \
		$(OBJDIRCF)/bdos/fsfat.o \
		$(OBJDIRCF)/bdos/fsio.o \
		$(OBJDIRCF)/bdos/fsdir.o \
		$(OBJDIRCF)/bdos/fsglob.o \
		$(OBJDIRCF)/bdos/fsmain.o \
		$(OBJDIRCF)/bdos/fsdrive.o \
		$(OBJDIRCF)/bdos/fshand.o \
		$(OBJDIRCF)/bdos/fsopnclo.o \
		$(OBJDIRCF)/bdos/osmem.o \
		$(OBJDIRCF)/bdos/umem.o \
		$(OBJDIRCF)/bdos/iumem.o \
		$(OBJDIRCF)/bdos/console.o \
		$(OBJDIRCF)/bdos/bdosmain.o \
		$(OBJDIRCF)/bdos/proc.o \
		$(OBJDIRCF)/bdos/kpgmld.o \
		$(OBJDIRCF)/bdos/time.o \
		$(OBJDIRCF)/bdos/rwa.o \
		$(OBJDIRCF)/bdos/setjmp.o

OBJSRTOSCF=	\
		$(OBJDIRCF)/freertos/tasks.o \
		$(OBJDIRCF)/freertos/queue.o \
		$(OBJDIRCF)/freertos/list.o \
		$(OBJDIRCF)/freertos/heap_2.o \
		$(OBJDIRCF)/freertos/heap_2b.o \
		$(OBJDIRCF)/freertos/port.o

OBJSRTOSCF2=	\
		$(OBJDIRCF)/freertos/tasks.o \
		$(OBJDIRCF)/freertos/queue.o \
		$(OBJDIRCF)/freertos/list.o \
		$(OBJDIRCF)/freertos/heap_2.o \
		$(OBJDIRCF)/freertos/heap_2b.o \
		$(OBJDIRCF2)/freertos/port.o

OBJSRTOSCF3=	\
		$(OBJDIRCF)/freertos/tasks.o \
		$(OBJDIRCF)/freertos/queue.o \
		$(OBJDIRCF)/freertos/list.o \
		$(OBJDIRCF)/freertos/heap_2.o \
		$(OBJDIRCF)/freertos/heap_2b.o \
		$(OBJDIRCF3)/freertos/port.o

OBJS=	\
		$(OBJDIR)/header.o \
		$(OBJDIR)/init.o \
		$(OBJDIR)/videocnf.o \
		$(OBJDIR)/gemform.o \
		$(OBJDIR)/xbios.o \
		$(OBJDIR)/detxbios.o \
		$(OBJDIR)/detlinea.o \
		$(OBJDIR)/stdlib.o \
		$(OBJDIR)/detvdi.o \
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
		$(OBJDIR)/radeon/accel_rom.o \
		$(OBJDIR)/radeon/spec_rom.o \
		$(OBJDIR)/radeon/radeon_base_rom.o \
		$(OBJDIR)/radeon/radeon_video.o \
		$(OBJDIR)/radeon/radeon_theatre.o \
		$(OBJDIR)/radeon/radeon_vid.o \
		$(OBJDIR)/dma_utils/dma_utils.o \
		$(OBJDIR)/lz.o \
		$(OBJSDRIVERFVDI)

OBJSCF=	\
		$(OBJDIRCF)/init.o \
		$(OBJDIRCF)/videocnf.o \
		$(OBJDIRCF)/gemform.o \
		$(OBJDIRCF)/xbios.o \
		$(OBJDIRCF)/detxbios.o \
		$(OBJDIRCF)/detlinea.o \
		$(OBJDIRCF)/detvdi.o \
		$(OBJDIRCF)/m68k_disasm.o \
		$(OBJDIRCF)/emulator/biosemu.o \
		$(OBJDIRCF)/emulator/pcbios/pcibios.o \
		$(OBJDIRCF)/emulator/x86emu/debug.o \
		$(OBJDIRCF)/emulator/x86emu/decode.o \
		$(OBJDIRCF)/emulator/x86emu/fpu.o \
		$(OBJDIRCF)/emulator/x86emu/ops.o \
		$(OBJDIRCF)/emulator/x86emu/ops2.o \
		$(OBJDIRCF)/emulator/x86emu/prim_ops.o \
		$(OBJDIRCF)/emulator/x86emu/sys.o \
		$(OBJDIRCF)/fvdi/utility.o \
		$(OBJDIRCF)/fvdi/fonts.o \
		$(OBJDIRCF)/fvdi/text.o \
		$(OBJDIRCF)/fvdi/textrndr.o \
		$(OBJDIRCF)/fvdi/blit.o \
		$(OBJDIRCF)/fvdi/line.o \
		$(OBJDIRCF)/fvdi/draw.o \
		$(OBJDIRCF)/fvdi/polygon.o \
		$(OBJDIRCF)/fvdi/conic.o \
		$(OBJDIRCF)/fvdi/contourfill.o \
		$(OBJDIRCF)/fvdi/vdi_misc.o \
		$(OBJDIRCF)/radeon/spec_rom.o \
		$(OBJDIRCF)/radeon/accel_rom.o \
		$(OBJDIRCF)/radeon/radeon_base_rom.o \
		$(OBJDIRCF)/radeon/radeon_video.o \
		$(OBJDIRCF)/radeon/radeon_theatre.o \
		$(OBJDIRCF)/radeon/radeon_vid.o \
		$(OBJDIRCF)/get.o \
		$(OBJDIRCF)/lz.o \
		$(OBJDIRCF)/rtc/rtc5c387.o \
		$(OBJSDRIVERFVDICF) \
		$(OBJSBDOSCF) \
		$(OBJSNETCF)

OBJSCF2=	\
		$(OBJDIRCF2)/init.o \
		$(OBJDIRCF)/videocnf.o \
		$(OBJDIRCF)/gemform.o \
		$(OBJDIRCF2)/xbios.o \
		$(OBJDIRCF2)/detxbios.o \
		$(OBJDIRCF)/detlinea.o \
		$(OBJDIRCF)/detvdi.o \
		$(OBJDIRCF)/m68k_disasm.o \
		$(OBJDIRCF)/emulator/biosemu.o \
		$(OBJDIRCF)/emulator/pcbios/pcibios.o \
		$(OBJDIRCF)/emulator/x86emu/debug.o \
		$(OBJDIRCF)/emulator/x86emu/decode.o \
		$(OBJDIRCF)/emulator/x86emu/fpu.o \
		$(OBJDIRCF)/emulator/x86emu/ops.o \
		$(OBJDIRCF)/emulator/x86emu/ops2.o \
		$(OBJDIRCF)/emulator/x86emu/prim_ops.o \
		$(OBJDIRCF)/emulator/x86emu/sys.o \
		$(OBJDIRCF)/fvdi/utility.o \
		$(OBJDIRCF)/fvdi/fonts.o \
		$(OBJDIRCF)/fvdi/text.o \
		$(OBJDIRCF)/fvdi/textrndr.o \
		$(OBJDIRCF)/fvdi/blit.o \
		$(OBJDIRCF)/fvdi/line.o \
		$(OBJDIRCF)/fvdi/draw.o \
		$(OBJDIRCF)/fvdi/polygon.o \
		$(OBJDIRCF)/fvdi/conic.o \
		$(OBJDIRCF)/fvdi/contourfill.o \
		$(OBJDIRCF)/fvdi/vdi_misc.o \
		$(OBJDIRCF)/radeon/spec_rom.o \
		$(OBJDIRCF2)/radeon/accel_rom.o \
		$(OBJDIRCF2)/radeon/radeon_base_rom.o \
		$(OBJDIRCF)/get.o \
		$(OBJDIRCF)/lz.o \
		$(OBJSDRIVERFVDICF2) \
		$(OBJSBDOSCF2) \
		$(OBJSNETCF2)

OBJSCF3=	\
		$(OBJDIRCF3)/init.o \
		$(OBJDIRCF)/videocnf.o \
		$(OBJDIRCF)/gemform.o \
		$(OBJDIRCF3)/xbios.o \
		$(OBJDIRCF3)/detxbios.o \
		$(OBJDIRCF)/detlinea.o \
		$(OBJDIRCF)/detvdi.o \
		$(OBJDIRCF)/m68k_disasm.o \
		$(OBJDIRCF)/emulator/biosemu.o \
		$(OBJDIRCF)/emulator/pcbios/pcibios.o \
		$(OBJDIRCF)/emulator/x86emu/debug.o \
		$(OBJDIRCF)/emulator/x86emu/decode.o \
		$(OBJDIRCF)/emulator/x86emu/fpu.o \
		$(OBJDIRCF)/emulator/x86emu/ops.o \
		$(OBJDIRCF)/emulator/x86emu/ops2.o \
		$(OBJDIRCF)/emulator/x86emu/prim_ops.o \
		$(OBJDIRCF)/emulator/x86emu/sys.o \
		$(OBJDIRCF)/fvdi/utility.o \
		$(OBJDIRCF)/fvdi/fonts.o \
		$(OBJDIRCF)/fvdi/text.o \
		$(OBJDIRCF)/fvdi/textrndr.o \
		$(OBJDIRCF)/fvdi/blit.o \
		$(OBJDIRCF)/fvdi/line.o \
		$(OBJDIRCF)/fvdi/draw.o \
		$(OBJDIRCF)/fvdi/polygon.o \
		$(OBJDIRCF)/fvdi/conic.o \
		$(OBJDIRCF)/fvdi/contourfill.o \
		$(OBJDIRCF)/fvdi/vdi_misc.o \
		$(OBJDIRCF)/radeon/spec_rom.o \
		$(OBJDIRCF)/radeon/accel_rom.o \
		$(OBJDIRCF)/radeon/radeon_base_rom.o \
		$(OBJDIRCF)/radeon/radeon_video.o \
		$(OBJDIRCF)/radeon/radeon_theatre.o \
		$(OBJDIRCF)/radeon/radeon_vid.o \
		$(OBJDIRCF)/get.o \
		$(OBJDIRCF)/lz.o \
		$(OBJSDRIVERFVDICF3) \
		$(OBJSBDOSCF3) \
		$(OBJSNETCF3)

HEX = pci.bin
HEXCF = pci_cf.hex
HEXCF2 = pci_cf2.hex
HEXCF3 = pci_cf3.hex
DRIVERFVDI = radeon.sys
DRIVERFVDICF = radeoncf.sys
DRIVERFVDICF2 = radeoncf2.sys
DRIVERFVDICF3 = radeoncf3.sys

all: $(HEX) $(HEXCF) $(HEXCF2) $(HEXCF3) $(DRIVERFVDI) $(DRIVERFVDICF) $(DRIVERFVDICF2) $(DRIVERFVDICF3)

ctpci: $(HEX) $(DRIVERFVDI)

m5484lite: $(HEXCF) $(DRIVERFVDICF)

m54455evb: $(HEXCF2) $(DRIVERFVDICF2)

coldari: $(HEXCF3) $(DRIVERFVDICF3)

clean:
	rm -f *~
	rm -rf $(OBJDIR) $(OBJDIRCF) $(OBJDIRCF2) $(OBJDIRCF3)
	rm -f $(HEX) $(HEXCF) $(HEXCF2) $(HEXCF3) pci.map pci_cf.map pci_cf2.map pci_cf3.map $(DRIVERFVDI) $(DRIVERFVDICF) $(DRIVERFVDICF2) $(DRIVERFVDICF3)

$(HEX):	$(OBJS)
	$(LD) -Map pci.map -L../linker -T pci.ld -o $(HEX) $(OBJS)

$(HEXCF):	$(OBJDIRCF)/header.o $(OBJSCF) $(OBJSRTOSCF) $(OBJSLWIPCF) $(OBJSBUSBCF) $(OBJSAC97CF)
	$(LD) --oformat srec -Map pci_cf.map --cref -T pcicf.lk \
	--entry Start -o $(HEXCF) $(OBJSCF)

$(HEXCF2):	$(OBJDIRCF2)/header.o $(OBJSCF2) $(OBJSRTOSCF2) $(OBJSLWIPCF2)
	$(LD) --oformat srec -Map pci_cf2.map --cref -T pcicf2.lk \
	--entry Start -o $(HEXCF2) $(OBJSCF2)

$(HEXCF3):	$(OBJDIRCF3)/header.o $(OBJSCF3) $(OBJSRTOSCF3) $(OBJSLWIPCF3) $(OBJSAC97CF3)
	$(LD) --oformat srec -Map pci_cf3.map --cref -T pcicf3.lk
	--entry Start -o $(HEXCF3) $(OBJSCF3)

$(DRIVERFVDI): $(OBJDIR)/radeon/spec.o $(OBJDIR)/radeon/accel.o $(OBJDIR)/radeon/radeon_base.o $(OBJSDRIVERFVDI)
	$(LD) $(LDFLAGS) -o $(DRIVERFVDI) $(OBJDIR)/radeon/spec.o $(OBJDIR)/radeon/accel.o $(OBJDIR)/radeon/radeon_base.o $(OBJSDRIVERFVDI)

$(DRIVERFVDICF): $(OBJDIRCF)/radeon/spec.o $(OBJDIRCF)/radeon/accel.o $(OBJDIRCF)/radeon/radeon_base.o $(OBJSDRIVERFVDICF)
	$(LD) $(LDFLAGS) -o $(DRIVERFVDICF) $(OBJDIRCF)/radeon/spec.o $(OBJDIRCF)/radeon/accel.o $(OBJDIRCF)/radeon/radeon_base.o $(OBJSDRIVERFVDICF)

$(DRIVERFVDICF2): $(OBJDIRCF2)/radeon/spec.o $(OBJDIRCF2)/radeon/accel.o $(OBJDIRCF2)/radeon/radeon_base.o $(OBJSDRIVERFVDICF2)
	$(LD) $(LDFLAGS) -o $(DRIVERFVDICF2) $(OBJDIRCF2)/radeon/spec.o $(OBJDIRCF2)/radeon/accel.o $(OBJDIRCF2)/radeon/radeon_base.o $(OBJSDRIVERFVDICF2)

$(DRIVERFVDICF3): $(OBJDIRCF3)/radeon/spec.o $(OBJDIRCF3)/radeon/accel.o $(OBJDIRCF3)/radeon/radeon_base.o $(OBJSDRIVERFVDICF3)
	$(LD) $(LDFLAGS) -o $(DRIVERFVDICF3) $(OBJDIRCF3)/radeon/spec.o $(OBJDIRCF3)/radeon/accel.o $(OBJDIRCF3)/radeon/radeon_base.o $(OBJSDRIVERFVDICF3)

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

$(OBJDIR)/lz.o:	../lz77/lz.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DONLY_UNCOMPRESS -I../lz77 -c $< -o $@

#$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.c
#	$(CREATEOBJDIRS)
#	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -Wa,-alhsd=x.ls -c $< -o $@

#$(OBJDIRCF)/emulator/biosemu.o:	$(SRCDIR)/emulator/biosemu.c
#	$(CREATEOBJDIRSCF)
#	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -Wa,-alhsd=biosemu.ls -c $< -o $@

$(OBJDIR)/radeon/radeon_base_rom.o:	$(SRCDIR)/radeon/radeon_base.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF)/radeon/radeon_base_rom.o:	$(SRCDIR)/radeon/radeon_base.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF2)/radeon/radeon_base_rom.o:	$(SRCDIR)/radeon/radeon_base.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF3)/radeon/radeon_base_rom.o:	$(SRCDIR)/radeon/radeon_base.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/radeon/radeon_accel_rom.o:	$(SRCDIR)/radeon/radeon_accel.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF)/radeon/radeon_accel_rom.o:	$(SRCDIR)/radeon/radeon_accel.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF2)/radeon/radeon_accel_rom.o:	$(SRCDIR)/radeon/radeon_accel.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF3)/radeon/radeon_accel_rom.o:	$(SRCDIR)/radeon/radeon_accel.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/radeon/spec_rom.o:	$(SRCDIR)/radeon/spec.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF)/radeon/spec_rom.o:	$(SRCDIR)/radeon/spec.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF2)/radeon/spec_rom.o:	$(SRCDIR)/radeon/spec.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF3)/radeon/spec_rom.o:	$(SRCDIR)/radeon/spec.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/radeon/accel_rom.o:	$(SRCDIR)/radeon/accel.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF)/radeon/accel_rom.o:	$(SRCDIR)/radeon/accel.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF2)/radeon/accel_rom.o:	$(SRCDIR)/radeon/accel.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIRCF3)/radeon/accel_rom.o:	$(SRCDIR)/radeon/accel.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/radeon/%.o:	$(SRCDIR)/radeon/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/radeon/%.o:	$(SRCDIR)/radeon/%.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/radeon/%.o:	$(SRCDIR)/radeon/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -c $< -o $@

$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/radeon/%.o:	$(SRCDIR)/radeon/%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/radeon/%.o:	$(SRCDIR)/radeon/%.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/radeon/%.o:	$(SRCDIR)/radeon/%.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -c $< -o $@

$(OBJDIR)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -c $< -o $@

$(OBJDIR)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -c $< -o $@

$(OBJDIR)/fvdi/%.o:	$(SRCDIR)/fvdi/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/fvdi/%.o:	$(SRCDIR)/fvdi/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/fvdi/%.o:	$(SRCDIR)/fvdi/%.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/fvdi/%.o:	$(SRCDIR)/fvdi/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -c $< -o $@

$(OBJDIR)/fvdi/%.o:	$(SRCDIR)/fvdi/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/fvdi/%.o:	$(SRCDIR)/fvdi/%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/fvdi/%.o:	$(SRCDIR)/fvdi/%.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/fvdi/%.o:	$(SRCDIR)/fvdi/%.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -c $< -o $@

$(OBJDIRCF)/net/%.o:	$(SRCDIR)/net/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/net/%.o:	$(SRCDIR)/net/%.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/net/%.o:	$(SRCDIR)/net/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3) -c $< -o $@

$(OBJDIRCF)/net//%.o:	$(SRCDIR)/net//%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/net//%.o:	$(SRCDIR)/net//%.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/net//%.o:	$(SRCDIR)/net//%.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3) -c $< -o $@

$(OBJDIRCF)/usb_dev/%.o:	$(SRCDIR)/usb_dev/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF) -c $< -o $@

$(OBJDIR)/usb/%.o:	$(SRCDIR)/usb/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/usb/%.o:	$(SRCDIR)/usb/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/usb/%.o:	$(SRCDIR)/usb/%.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/usb/%.o:	$(SRCDIR)/usb/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3) -c $< -o $@

$(OBJDIRCF)/ac97/%.o:	$(SRCDIR)/ac97/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF3)/ac97/%.o:	$(SRCDIR)/ac97/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3) -c $< -o $@

$(OBJDIRCF)/bdos/%.o:	$(SRCDIR)/bdos/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF) -mshort -c $< -o $@

$(OBJDIRCF2)/bdos/%.o:	$(SRCDIR)/bdos/%.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2) -mshort -c $< -o $@

$(OBJDIRCF3)/bdos/%.o:	$(SRCDIR)/bdos/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(CFLAGSCF3) -mshort -c $< -o $@

$(OBJDIRCF)/bdos//%.o:	$(SRCDIR)/bdos//%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(CFLAGSCF) -mshort -c $< -o $@

$(OBJDIRCF2)/bdos//%.o:	$(SRCDIR)/bdos//%.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(CFLAGSCF2) -mshort -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIRCF)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRSCF)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF) -c $< -o $@

$(OBJDIRCF2)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRSCF2)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF2) -c $< -o $@

$(OBJDIRCF3)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRSCF3)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGSCF3) -c $< -o $@
