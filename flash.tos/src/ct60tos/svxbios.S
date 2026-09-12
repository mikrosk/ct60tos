/* SuperVidel XBIOS extensions, resident in the flash.
 *
 * The driver is built by sv_drivers as an ordinary GEMDOS executable
 * (nonfree/sv_xbios.bin) and included here verbatim.  sv_xbios_reserve takes
 * its memory off the top of the SDRAM, load_sv_xbios relocates it there and
 * install_sv_xbios enters it at the offset its program header names.  It
 * installs the XBIOS handler, the VDI primitives and the console, sets the
 * screen up and draws the Atari logo on it, and never gives anything back.
 *
 * init_sdram does all three where sv_present says there is a board to use,
 * before it puts anything on the screen.
 */

	.text

	.globl	sv_xbios_reserve
	.globl	fix_mt_end
	.globl	load_sv_xbios
	.globl	install_sv_xbios


#include "vars.h"

#define PRG_MAGIC   0x601A
#define SV_COOKIE   0x53757056           // 'SupV'
#define PAGESIZE    8192
#define SDRAM_BASE  0x01002000           // first SDRAM byte above the supervisor stack

/* Size of the driver in RAM: TEXT + DATA + BSS, rounded up to a page.
 * Returned in D0, zero if there is nothing to install.  Trashes D0/A0.
 */
sv_xbios_size:

	moveq #0,D0
	lea sv_xbios_image,A0
	cmp.w #PRG_MAGIC,(A0)
	bne.s .no_size
	tst.l 14(A0)             // symbol table, must be stripped
	bne.s .no_size
	move.l 2(A0),D0          // TEXT
	add.l 6(A0),D0           // DATA
	add.l 10(A0),D0          // BSS
	add.l #PAGESIZE-1,D0
	and.l #-PAGESIZE,D0
.no_size:
	rts

/* Take the driver's memory off the top of the SDRAM, below the MMU tree.
 * Called from init_sdram once ramtop is final, so the cold boot SDRAM clear
 * in add_sdram, Maddalt and both phases of the TOS memory test all stay
 * below it.  Nothing is reserved without a SuperVidel to use it.
 */
sv_xbios_reserve:

	movem.l D0-D7/A0-A6,-(SP)
	tst.l ramtop             // no SDRAM, nowhere to put it
	beq.s .no_reserve
	bsr sv_xbios_size
	tst.l D0
	beq.s .no_reserve
	move.l ramtop,D1
	sub.l D0,D1
	cmp.l #SDRAM_BASE,D1     // paranoia: leave the machine bootable
	bls.s .no_reserve
	move.l D1,ramtop
.no_reserve:
	movem.l (SP)+,D0-D7/A0-A6
	rts

/* The TOS boot memory test (bios/memtest.s) tests ST RAM from the end of the
 * OS up to the screen, which mstate0 reads out of _v_bas_ad.  With the driver
 * up that points into SuperVidel RAM, which would put the whole of ST RAM in
 * the test and wipe the fonts copy_fonts leaves below phystop along with the
 * CT60 variables under them.  Supply the screen the OS had instead.
 *
 * Patched over the three instructions of mstate0 that read _v_bas_ad, so D1
 * still holds the 128 KB mask and D0 is free.
 */

fix_mt_end:

	move.l _v_bas_ad,D0
	cmp.l phystop,D0
	bcs.s .screen_in_st_ram
	move.l A0,-(SP)
	move.l phystop,A0
	move.l old_v_bas_ad(A0),D0
	move.l (SP)+,A0
	bne.s .screen_in_st_ram
	move.l _memtop,D0        // nothing saved: the top of what the OS hands out
.screen_in_st_ram:
	and.l D1,D0              // round down to a 128 KB boundary
	move.l D0,mt_end
	rts

/* Relocate the image into the reserved area, whether or not there is a
 * SuperVidel: its logo routine is drawn on by every boot.  Sets
 * sv_xbios_entry, which is 0 if there was nowhere to put it.
 */
load_sv_xbios:

	movem.l D0-D7/A0-A6,-(SP)
	move.l phystop,A0
	tst.l sv_xbios_entry(A0)
	bne .end_load            // done already
	tst.l ramtop
	beq .end_load
	bsr sv_xbios_size
	tst.l D0
	beq .end_load

	lea sv_xbios_image,A0
	move.l 2(A0),D1          // TEXT
	move.l 6(A0),D2          // DATA
	move.l 10(A0),D3         // BSS
	lea 28(A0),A0            // TEXT starts after the program header
	move.l ramtop,A1         // reserved by sv_xbios_reserve
	move.l A1,D5             // relocation offset, the image is linked at 0

	move.l D1,D0
	add.l D2,D0              // TEXT + DATA
	move.l A1,A2
	lsr.l #1,D0
	bcc.s .copy_words
	move.b (A0)+,(A2)+       // odd size, can not happen but be safe
.copy_words:
	subq.l #1,D0
	bmi.s .copy_done
.loop_copy:
		move.w (A0)+,(A2)+
	dbf D0,.loop_copy
	swap D0
	subq.l #1,D0
	bpl.s .loop_copy
.copy_done:

	move.l D3,D0             // BSS, A2 already points at it
	lsr.l #1,D0
	bcc.s .clear_words
	clr.b (A2)+
.clear_words:
	subq.l #1,D0
	bmi.s .clear_done
.loop_clear:
		clr.w (A2)+
	dbf D0,.loop_clear
	swap D0
	subq.l #1,D0
	bpl.s .loop_clear
.clear_done:

	move.l (A0),D0           // A0 is at the fixup table (no symbols)
	beq.s .reloc_done        // nothing to relocate
	addq.l #4,A0
	move.l A1,A2
	add.l D0,A2
	add.l D5,(A2)
.loop_reloc:
		moveq #0,D0
		move.b (A0)+,D0
		beq.s .reloc_done
		cmp.b #1,D0
		bne.s .reloc_fixup
		lea 254(A2),A2       // skip 254 bytes, no fixup
	bra.s .loop_reloc
.reloc_fixup:
		add.l D0,A2
		add.l D5,(A2)
	bra.s .loop_reloc
.reloc_done:

	nop
	cpusha BC                // it was written through the data cache
	nop
	move.l 0x1C(A1),D0       // entry offset, from the program header
	add.l D0,A1
	move.l phystop,A0
	move.l A1,sv_xbios_entry(A0)
.end_load:
	movem.l (SP)+,D0-D7/A0-A6
	rts

/* Call the driver, which sets the screen up and draws the boot logo on it.
 * Only reached where there is a SuperVidel to do that with.
 */
install_sv_xbios:

	movem.l D0-D7/A0-A6,-(SP)   // the driver only honours the C register ABI
	move.l phystop,A0
	move.l sv_xbios_entry(A0),A1
	move.l A1,D0
	beq.s .no_install        // nowhere to relocate it to
	move.l _v_bas_ad,D0      // fix_mt_end wants the screen the OS still has
	move.l D0,old_v_bas_ad(A0)
	jsr (A1)                 // in supervisor mode
.no_install:
	movem.l (SP)+,D0-D7/A0-A6
	rts

	.align 2

sv_xbios_image:

	.incbin "nonfree/sv_xbios.bin"
