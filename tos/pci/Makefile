TOP_DIR		= ..

include $(TOP_DIR)/CONFIGVARS

SRCDIR = .
INCDIR = ./include
INCDIRFVDI = ./fvdi/include
OBJDIR = ./obj

SUBOBJDIRS=	\
		$(OBJDIR)/radeon \
		$(OBJDIR)/emulator \
		$(OBJDIR)/emulator/pcbios \
		$(OBJDIR)/emulator/x86emu \
		$(OBJDIR)/fvdi \
		$(OBJDIR)/fvdi/common \
		$(OBJDIR)/dma_utils

INCLUDE = -I$(INCDIR)
INCLUDEFVDI = -I$(INCDIRFVDI)
CFLAGS = -m68060 -Os -fno-builtin -fomit-frame-pointer -Wall -Wno-multichar
LDFLAGS = -nostdlib

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
		$(OBJDIR)/radeon/radeon_vid.o \
		$(OBJDIR)/dma_utils/dma_utils.o \
		$(OBJSDRIVERFVDI)

HEX = pci.bin
DRIVERFVDI = radeon.sys

all: $(HEX) $(DRIVERFVDI)

ctpci: $(HEX) $(DRIVERFVDI)

clean:
	rm -f *~ */*~
	rm -f *.o $(OBJDIR)/*.o $(OBJDIR)/*/*.o $(OBJDIR)/*/*/*.o
	rm -f $(HEX) $(DRIVERFVDI)

$(HEX):	$(OBJS)
	$(LD) -L../linker -T pci.ld -o $(HEX) $(OBJS)

$(DRIVERFVDI): $(OBJDIR)/radeon/spec.o $(OBJDIR)/radeon/accel.o $(OBJDIR)/radeon/radeon_base.o $(OBJSDRIVERFVDI)
	$(LD) $(LDFLAGS) -o $(DRIVERFVDI) $(OBJDIR)/radeon/spec.o $(OBJDIR)/radeon/accel.o $(OBJDIR)/radeon/radeon_base.o $(OBJSDRIVERFVDI)

$(OBJDIR)/radeon/radeon_base_rom.o:	$(SRCDIR)/radeon/radeon_base.c
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/radeon/spec_rom.o:	$(SRCDIR)/radeon/spec.c
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/radeon/accel_rom.o:	$(SRCDIR)/radeon/accel.c
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -DDRIVER_IN_ROM -c $< -o $@

$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.c
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.S
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.c
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.S
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/%.o:	$(SRCDIR)/fvdi/%.c
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/%.o:	$(SRCDIR)/fvdi/%.S
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.c
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.S
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@
