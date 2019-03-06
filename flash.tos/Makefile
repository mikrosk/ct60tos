TOP_DIR		= $(PWD)

include $(TOP_DIR)/CONFIGVARS

TOS_ROM		= tos404.bin

# directories
TOS_DIR		= tos
INC_DIR		= tosinclude
OBJ_DIR		= obj
LINKER_DIR	= $(TOP_DIR)/linker


# flags for CT60 TOS compilation (m68k)
ASFLAGS		= -m68060 -I$(INC_DIR) -I.
CFLAGS		= -m68060 -Wall -O2 -fomit-frame-pointer -I$(INC_DIR)

# flags for host gcc
#HOSTCFLAGS	= -Wall -O2 -fomit-frame-pointer -Iinclude -D$(PLATFORM)
HOSTCFLAGS	= -Wall -Os -g -Iinclude -D$(PLATFORM)

# main targets
CT60_TOS	= ct60tos.bin

TOS_PATCHER	= gentos
CT60_PATCHES	= ct60_patches.bin

include $(TOS_DIR)/SRCFILES
# order is no longer important, it matters what's in linker script!
SRCS		= $(patsubst %.c,,$(SRCFILES:%.S=$(TOS_DIR)/%.S)) $(patsubst %.S,,$(SRCFILES:%.c=$(TOS_DIR)/%.c))
CT60_OBJS	= $(patsubst %.c,,$(SRCFILES:%.S=$(OBJ_DIR)/%.o)) $(patsubst %.S,,$(SRCFILES:%.c=$(OBJ_DIR)/%.o))

all: setup $(CT60_TOS)

# '#include' dependencies
$(OBJ_DIR)/bios2.o: $(TOS_DIR)/bios2.S $(TOS_DIR)/conout.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/vectors2.o: $(TOS_DIR)/vectors2.S nonfree/isp.S nonfree/fpsp.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/videl2.o: $(TOS_DIR)/videl2.S $(TOS_DIR)/pic_boot.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/xbios2.o: $(TOS_DIR)/xbios2.S
	$(CC) $(ASFLAGS) -o $@ -c $<

# common build rules
$(OBJ_DIR)/%.o:	$(TOS_DIR)/%.S
	$(CC) $(ASFLAGS) -o $@ -c $<

$(OBJ_DIR)/%.o:	$(TOS_DIR)/%.c
	$(CC) $(CFLAGS) -o $@ -c $<

# setup, run just once
.PHONY: setup
setup: check_ld $(OBJ_DIR)

$(OBJ_DIR):
	mkdir $@


# we need this check because ld scripts wont be processed correctly
.PHONY: check_ld	
check_ld:
	@$(LD) -v > /dev/null || ( echo "$(LD) not found!"; false )
	@$(LD) -v | grep -v -q "2.13" || ( echo "Your binutils are too old!"; false )

# we need to enter OBJ_DIR else filename matching doesn't work correctly in link script
$(CT60_PATCHES): $(CT60_OBJS) $(LINKER_DIR)/ct60.ld
	cd $(OBJ_DIR) && $(LD) -o ../$@ $(notdir $(CT60_OBJS)) -L$(LINKER_DIR) -T $(LINKER_DIR)/ct60.ld

$(TOS_PATCHER): gentos.c
	gcc $(HOSTCFLAGS) -o $@ gentos.c

# main rules
$(CT60_TOS): nonfree/$(TOS_ROM) nonfree/sparrow.out $(CT60_PATCHES) $(TOS_PATCHER)
	./$(TOS_PATCHER) --tos nonfree/$(TOS_ROM) --tospatch $(CT60_PATCHES) --tests nonfree/sparrow.out --out $@

clean:
	rm -f $(OBJ_DIR)/*.o
	rm -f $(CT60_TOS)
	rm -f $(TOS_PATCHER) $(CT60_PATCHES)

distclean:
	$(MAKE) clean
	rm -rf $(OBJ_DIR)
	rm -f *~ */*~

.PHONY: backup
backup:
	find . -path ./obj -prune -o -path ./backup -prune -o ! -name \*.bin -type f -print0 | tar cfz `date +./backup/v%Y%m%d%H%M.tar.gz` --null -T -
