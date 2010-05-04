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

ASFLAGS		= -m68060 -Iinclude
CFLAGS		= -m68060 -Wall -O2 -fomit-frame-pointer -Iinclude -I.

TARGET		= ct60tos.bin
TOS_PATCHER	= gentos
TOS_PATCHES	= tos_patches.bin
TOS_PATCHES_MAP	= $(subst .bin,.map,$(TOS_PATCHES))
TOS_ADDR_H	= tos_addr.h

TOS_DIR		= tos
OBJ_DIR		= obj_tos
include $(TOS_DIR)/TOS_CT60
TOS_OBJS	= $(OBJS:%.o=$(OBJ_DIR)/%.o)

# user defs
VERSION		= 0x0104

default: $(TARGET)

$(OBJ_DIR):
	mkdir $@

$(OBJ_DIR)/%.o:	$(TOS_DIR)/%.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/%.o:	$(TOS_DIR)/%.c
	$(CC) $(CFLAGS) -o $@ -c $<

$(TOS_PATCHES): $(OBJ_DIR) $(TOS_OBJS)
	$(LD) --oformat binary -Map=$(TOS_PATCHES_MAP) -o $@ $(TOS_OBJS)

$(TOS_PATCHES_MAP): $(TOS_PATCHES)

$(TOS_ADDR_H): $(TOS_PATCHES_MAP)
	./get_patch_addr.sh $(TOS_PATCHES_MAP) $@

$(TOS_PATCHER): gentos.c $(TOS_ADDR_H)
	gcc -Wall -g -o $@ gentos.c -D$(PLATFORM)	# -O2 -fomit-frame-pointer 

$(TARGET): nonfree/tos404.bin nonfree/sparrow.out $(TOS_PATCHES) $(TOS_PATCHER)
	./$(TOS_PATCHER) --tos nonfree/tos404.bin --tospatch $(TOS_PATCHES) --tests nonfree/sparrow.out --out $@

clean:
	rm -rf $(OBJ_DIR)
	rm -f  $(TOS_PATCHER) $(TOS_PATCHES) $(TOS_PATCHES_MAP) $(TOS_ADDR_H) $(TARGET)
	rm -f *~
