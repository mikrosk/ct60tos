TOP_DIR		= $(PWD)

include $(TOP_DIR)/CONFIGVARS

# flags for CT60 TOS compilation (m68k)
ASFLAGS		= -m68060 -Iinclude -I.
CFLAGS		= -m68060 -Wall -O2 -fomit-frame-pointer -Iinclude -Ilz77

# flags for host gcc
#HOSTCFLAGS	= -Wall -O2 -fomit-frame-pointer -Iinclude -Ilz77 -D$(PLATFORM)
HOSTCFLAGS	= -Wall -g -Iinclude -Ilz77 -D$(PLATFORM)

# directories
TOS_DIR		= tos
OBJ_DIR		= obj
PCI_DIR		= pci
LINKER_DIR	= $(TOP_DIR)/linker

# main targets
CT60_TOS	= ct60tos.bin
CTPCI_TOS	= ctpcitos.bin
CTPCI_1GB_TOS	= ctpci1gb.bin

TOS_PATCHER	= gentos
CT60_PATCHES	= ct60_patches.bin
CTPCI_PATCHES	= ctpci_patches.bin
CTPCI_1GB_PATCHES = ctpci_1gb_patches.bin
TOS_VERSION_H	= version.h

include $(TOS_DIR)/SRCFILES
# order is no longer important, it matters what's in linker script!
SRCS		= $(patsubst %.c,,$(SRCFILES:%.S=$(TOS_DIR)/%.S)) $(patsubst %.S,,$(SRCFILES:%.c=$(TOS_DIR)/%.c))
CT60_OBJS	= $(patsubst %.c,,$(SRCFILES:%.S=$(OBJ_DIR)/%.o)) $(patsubst %.S,,$(SRCFILES:%.c=$(OBJ_DIR)/%.o))
CTPCI_OBJS	= $(CT60_OBJS)
CTPCI_1GB_OBJS	= $(CTPCI_OBJS)
# we can do this since linker script uses '*' notation ...
CTPCI_1GB_OBJS	:= $(subst pmmu2.o,pmmu2_1gb.o,$(CTPCI_1GB_OBJS))
CTPCI_1GB_OBJS	:= $(subst sdram.o,sdram_1gb.o,$(CTPCI_1GB_OBJS))
CTPCI_1GB_OBJS	:= $(subst xbios2.o,xbios2_1gb.o,$(CTPCI_1GB_OBJS))

# user defs
TOS_VERSION	= 0x0104

all: setup $(CT60_TOS) $(CTPCI_TOS) $(CTPCI_1GB_TOS)

# '#include' dependencies
$(OBJ_DIR)/bios2.o: $(TOS_DIR)/bios2.S $(TOS_DIR)/conout.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/vectors2.o: $(TOS_DIR)/vectors2.S nonfree/isp.S nonfree/fpsp.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/videl2.o: $(TOS_DIR)/videl2.S $(TOS_DIR)/pic_boot.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/xbios2.o: $(TOS_DIR)/xbios2.S $(TOS_DIR)/pci_bios.S
	$(CC) $(ASFLAGS) -o $@ -c $<

# common build rules
$(OBJ_DIR)/%.o:	$(TOS_DIR)/%.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/%.o:	$(TOS_DIR)/%.c
	$(CC) $(CFLAGS) -o $@ -c $<

$(OBJ_DIR)/lz.o: lz77/lz.c
	$(CC) $(CFLAGS) -DONLY_UNCOMPRESS -o $@ -c $<

# CTPCI 1GB rules ... unfortunately, not working :( Crash occurs at:
# PC:   0x00e82962 (inside xbios2_1gb.o)
# addr: 0x80000000 (most probably has something to do with that PCI_* values changed by CTPCI_1GB)
$(OBJ_DIR)/pmmu2_1gb.o: $(TOS_DIR)/pmmu2.c
	$(CC) $(CFLAGS) -DCTPCI_1GB -o $@ -c $<

$(OBJ_DIR)/sdram_1gb.o: $(TOS_DIR)/sdram.S
	$(CC) $(ASFLAGS) -DCTPCI_1GB -o $@ -c $<

$(OBJ_DIR)/xbios2_1gb.o: $(TOS_DIR)/xbios2.S $(TOS_DIR)/pci_bios.S
	$(CC) $(ASFLAGS) -DCTPCI_1GB -o $@ -c $<

# setup, run just once
.PHONY: setup
setup: check_ld $(TOS_VERSION_H) $(OBJ_DIR)

$(OBJ_DIR):
	mkdir $@

$(TOS_VERSION_H): $(subst $(TOS_DIR)/lz.c,lz77/lz.c,$(SRCS))
	./gen_version.sh $(TOS_VERSION) $@

# we need this check because ld scripts wont be processed correctly
.PHONY: check_ld	
check_ld:
	@$(LD) -v | grep -q "2.20" || ( echo "Your binutils are too old!" && false )

# we need to enter OBJ_DIR else filename matching doesn't work correctly in link script
$(CT60_PATCHES): $(TOS_VERSION_H) $(CT60_OBJS) $(LINKER_DIR)/ct60.ld
	cd $(OBJ_DIR) && $(LD) -o ../$@ $(notdir $(CT60_OBJS)) -L$(LINKER_DIR) -T $(LINKER_DIR)/ct60.ld

$(CTPCI_PATCHES): $(TOS_VERSION_H) $(CTPCI_OBJS) $(LINKER_DIR)/ctpci.ld
	cd $(OBJ_DIR) && $(LD) -o ../$@ $(notdir $(CTPCI_OBJS)) -L$(LINKER_DIR) -T $(LINKER_DIR)/ctpci.ld

$(CTPCI_1GB_PATCHES): $(TOS_VERSION_H) $(CTPCI_1GB_OBJS) $(LINKER_DIR)/ctpci.ld
	cd $(OBJ_DIR) && $(LD) -o ../$@ $(notdir $(CTPCI_1GB_OBJS)) -L$(LINKER_DIR) -T $(LINKER_DIR)/ctpci.ld

$(TOS_PATCHER): gentos.c lz77/lz.c
	gcc $(HOSTCFLAGS) -o $@ gentos.c lz77/lz.c

# main rules
$(CT60_TOS): nonfree/tos404.bin nonfree/sparrow.out $(CT60_PATCHES) $(TOS_PATCHER)
	./$(TOS_PATCHER) --tos nonfree/tos404.bin --tospatch $(CT60_PATCHES) --tests nonfree/sparrow.out --out $@

$(PCI_DIR)/pci.bin:
	make -C pci ctpci CROSS=$(CROSS)

$(CTPCI_TOS): nonfree/tos404.bin $(CTPCI_PATCHES) $(TOS_PATCHER) $(PCI_DIR)/pci.bin
	./$(TOS_PATCHER) --tos nonfree/tos404.bin --tospatch $(CTPCI_PATCHES) --pci $(PCI_DIR)/pci.bin --out $@

$(CTPCI_1GB_TOS): nonfree/tos404.bin $(CTPCI_1GB_PATCHES) $(TOS_PATCHER) $(PCI_DIR)/pci.bin
	./$(TOS_PATCHER) --tos nonfree/tos404.bin --tospatch $(CTPCI_1GB_PATCHES) --pci $(PCI_DIR)/pci.bin --out $@

clean:
	rm -f $(OBJ_DIR)/*.o
	rm -f $(CT60_TOS) $(CTPCI_TOS) $(CTPCI_1GB_TOS)
	rm -f $(TOS_PATCHER) $(CT60_PATCHES) $(CTPCI_PATCHES) $(CTPCI_1GB_PATCHES)

clean_pci:
	$(MAKE) -C pci clean

distclean:
	$(MAKE) clean clean_pci
	rm -rf $(OBJ_DIR)
	rm -f $(TOS_VERSION_H)
	rm -f *~ */*~
