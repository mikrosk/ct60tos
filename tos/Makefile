CROSS		= yes

ifeq ($(CROSS),yes)
CROSS_PREFIX	= m68k-atari-mint-
PLATFORM	= LINUX
else
CROSS_PREFIX	=
PLATFORM	= ATARI
endif

CC		= $(CROSS_PREFIX)gcc
LD		= $(CROSS_PREFIX)ld
STRIP		= $(CROSS_PREFIX)strip

# flags for CT60 TOS compilation (m68k)
ASFLAGS		= -m68060 -Iinclude -I.
CFLAGS		= -m68060 -Wall -O2 -fomit-frame-pointer -Iinclude -Ilz77

# flags for host gcc
HOSTCFLAGS	= -Wall -O2 -fomit-frame-pointer -Iinclude -Ilz77 -D$(PLATFORM)

# main targets
CT60_TOS	= ct60tos.bin
CTPCI_TOS	= ctpcitos.bin
CTPCI_TOS_1GB	= ctpci1gb.bin

TOS_PATCHER	= gentos
TOS_PATCHES	= tos_patches.bin
TOS_PATCHES_MAP	= $(basename $(TOS_PATCHES)).map
TOS_ADDR_H	= tos_addr.h
TOS_VERSION_H	= version.h

TOS_DIR		= tos
OBJ_DIR		= obj
include $(TOS_DIR)/OBJFILES
# we must define it in this way since we can't randomly mix/separate C and S files, order is important
CT60_OBJS	= $(CT60_OBJFILES:%.o=$(OBJ_DIR)/%.o)
CTPCI_OBJS	= $(CTPCI_OBJFILES:%.o=$(OBJ_DIR)/%.o)
CTPCI_1GB_OBJS	= $(CTPCI_1GB_OBJFILES:%.o=$(OBJ_DIR)/%.o)

# user defs
TOS_VERSION	= 0x0104

default: $(TOS_VERSION_H) $(CT60_TOS) #$(CTPCI_TOS) $(CTPCI_TOS_1GB)

# build rules
$(OBJ_DIR)/%.o:	$(TOS_DIR)/%.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/%.o:	$(TOS_DIR)/%.c
	$(CC) $(CFLAGS) -o $@ -c $<

$(OBJ_DIR)/lz.o: lz77/lz.c
	$(CC) $(CFLAGS) -DONLY_UNCOMPRESS -o $@ -c $<

$(OBJ_DIR)/xbios2_1gb.o: $(TOS_DIR)/xbios2.S
	$(CC) $(ASFLAGS) -DCTPCI_1GB -o $@ -c $<

# helper rules
$(TOS_VERSION_H):
	./gen_version.sh $(TOS_VERSION) $@
	touch -m $(TOS_DIR)/version.S

$(OBJ_DIR):
	mkdir $@

$(TOS_PATCHES): $(OBJ_DIR) $(CT60_OBJS)
	$(LD) --oformat binary -Map=$(TOS_PATCHES_MAP) -o $@ $(CT60_OBJS)

$(TOS_PATCHES_MAP): $(TOS_PATCHES)

$(TOS_ADDR_H): $(TOS_PATCHES_MAP)
	./get_patch_addr.sh $(TOS_PATCHES_MAP) $(TOS_ADDR_H)

$(TOS_PATCHER): gentos.c lz77/lz.c $(TOS_ADDR_H)
	gcc $(HOSTCFLAGS) -o $@ gentos.c lz77/lz.c

# main rules
$(CT60_TOS): nonfree/tos404.bin nonfree/sparrow.out $(TOS_PATCHES) $(TOS_PATCHER)
	./$(TOS_PATCHER) --tos nonfree/tos404.bin --tospatch $(TOS_PATCHES) --tests nonfree/sparrow.out --out $@

$(PCI_DIR)/pci.hex:
	make -C pci ctpci

$(CTPCI_TOS): nonfree/tos404.bin nonfree/sparrow.out $(CTPCI_PATCHES) $(TOS_PATCHER) $(PCI_DIR)/pci.hex
	./$(TOS_PATCHER) --tos nonfree/tos404.bin --tospatch $(CTPCI_PATCHES) --tests nonfree/sparrow.out --pci $(PCI_DIR)/pci.hex --out $@

$(CTPCI_TOS_1GB): nonfree/tos404.bin nonfree/sparrow.out $(CTPCI_1GB_PATCHES) $(TOS_PATCHER) $(PCI_DIR)/pci.hex
	./$(TOS_PATCHER) --tos nonfree/tos404.bin --tospatch $(CTPCI_1GB_PATCHES) --tests nonfree/sparrow.out --pci $(PCI_DIR)/pci.hex --out $@
clean:
	rm -rf $(OBJ_DIR)
	rm -f $(CT60_TOS) $(CTPCI_TOS) $(CTPCI_TOS_1GB)
	rm -f  $(TOS_PATCHER) $(TOS_PATCHES) $(TOS_PATCHES_MAP) $(TOS_ADDR_H) $(TOS_VERSION_H)
	rm -f *~
