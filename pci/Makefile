CROSS = N

CROSSBINDIR_IS_Y = m68k-atari-mint-
CROSSBINDIR_IS_N =

CROSSBINDIR = $(CROSSBINDIR_IS_$(CROSS))

CC = $(CROSSBINDIR)gcc
LD = $(CROSSBINDIR)ld
rm = rm

SRCDIR = ./
INCDIR = ./include
INCDIRFVDI = ./fvdi/include
INCDIRUSB = ./usb
OBJDIR = ./obj

SUBOBJDIRS=	\
		$(OBJDIR)/radeon \
		$(OBJDIR)/fvdi \
		$(OBJDIR)/fvdi/common \
		$(OBJDIR)/usb \
		$(OBJDIR)/usb/core \
		$(OBJDIR)/usb/host \
		$(OBJDIR)/usb/input \
		$(OBJDIR)/usb/storage

INCLUDE = -I$(INCDIR)
INCLUDEFVDI = -I$(INCDIRFVDI)
INCLUDEUSB = -I$(INCDIRUSB)
CFLAGS = -m68060 -O2 -fomit-frame-pointer -Wall -Wno-multichar
LDFLAGS = -nostdlib --entry _init -s

OBJSDRIVERFVDI=	\
		$(OBJDIR)/radeon/spec.o \
		$(OBJDIR)/radeon/accel.o \
		$(OBJDIR)/radeon/8b_pal.o \
		$(OBJDIR)/radeon/16b_pal.o \
		$(OBJDIR)/radeon/32b_pal.o \
		$(OBJDIR)/radeon/radeon_base.o \
		$(OBJDIR)/radeon/radeon_pm.o \
		$(OBJDIR)/radeon/radeon_monitor.o \
		$(OBJDIR)/radeon/radeon_i2c.o \
		$(OBJDIR)/radeon/radeon_accel.o \
		$(OBJDIR)/radeon/radeon_cursor.o \
		$(OBJDIR)/radeon/radeon_mem.o \
		$(OBJDIR)/radeon/i2c-algo-bit.o \
		$(OBJDIR)/radeon/modedb.o \
		$(OBJDIR)/radeon/fbmem.o \
		$(OBJDIR)/radeon/fbmon.o \
		$(OBJDIR)/fvdi/common/init.o \
		$(OBJDIR)/fvdi/common/common.o \
		$(OBJDIR)/fvdi/common/c_common.o \
		$(OBJDIR)/fvdi/common/clip.o \
		$(OBJDIR)/fvdi/common/lineachk.o \
		$(OBJDIR)/fvdi/common/colours.o \
		$(OBJDIR)/fvdi/common/falc_pal.o

OBJSDRIVERUSB=	\
		$(OBJDIR)/usb/dmapool.o \
		$(OBJDIR)/usb/host/ohci-hcd.o \
		$(OBJDIR)/usb/host/ehci-hcd.o \
		$(OBJDIR)/usb/core/usb.o \
		$(OBJDIR)/usb/core/hub.o \
		$(OBJDIR)/usb/core/hcd.o \
		$(OBJDIR)/usb/core/urb.o

OBJS=	\
		$(OBJDIR)/header.o \
		$(OBJDIR)/init.o \
		$(OBJDIR)/xbios.o \
		$(OBJDIR)/detxbios.o \
		$(OBJDIR)/fvdi_init.o \
		$(OBJDIR)/detvdi.o \
		$(OBJDIR)/fvdi/text.o \
		$(OBJDIR)/fvdi/textrndr.o \
		$(OBJDIR)/fvdi/blit.o \
		$(OBJDIR)/fvdi/expand.o \
		$(OBJDIR)/fvdi/line.o \
		$(OBJDIR)/fvdi/polygon.o \
		$(OBJDIR)/fvdi/conic.o \
		$(OBJDIR)/fvdi/escape.o \
		$(OBJDIR)/fvdi/vdi_misc.o \
		$(OBJDIR)/fvdi/math.o \
		$(OBJSDRIVERFVDI)

HEX = pci.hex
DRIVERFVDI = radeon.sys

all: $(HEX) $(DRIVERFVDI)

clean:
	rm -rf $(OBJDIR)
	rm -f $(HEX) pci.map $(DRIVERFVDI)

$(HEX):	$(OBJS)
	$(LD) -oformat srec -Map pci.map --cref -T pci.lk \
	--entry Start -o $(HEX) $(OBJS)

$(DRIVERFVDI):	$(OBJSDRIVERFVDI)
	$(LD) $(LDFLAGS) -o $(DRIVERFVDI) $(OBJSDRIVERFVDI)

define CREATEOBJDIRS
	@for d in $(OBJDIR) $(SUBOBJDIRS); do \
		if [ ! -d $$d ] ; then \
			mkdir $$d ; \
		fi ; \
	done
endef

$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/radeon/%.o:	$(SRCDIR)/radeon/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@
	
$(OBJDIR)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/common/%.o:	$(SRCDIR)/fvdi/common/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/%.o:	$(SRCDIR)/fvdi/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/fvdi/%.o:	$(SRCDIR)/fvdi/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/usb/host/%.o:	$(SRCDIR)/usb/host/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEUSB) $(CFLAGS) -c $< -o $@

$(OBJDIR)/usb/host/%.o:	$(SRCDIR)/usb/host/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEUSB) $(CFLAGS) -c $< -o $@

$(OBJDIR)/usb/core/%.o:	$(SRCDIR)/usb/core/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEUSB) $(CFLAGS) -c $< -o $@

$(OBJDIR)/usb/core/%.o:	$(SRCDIR)/usb/core/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEUSB) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.c
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o:	$(SRCDIR)/%.S
	$(CREATEOBJDIRS)
	$(CC) $(INCLUDE) $(INCLUDEFVDI) $(CFLAGS) -c $< -o $@
