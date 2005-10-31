/****
* fVDI blit type functions
*
* $Id: blit.s,v 1.11 2005/07/26 21:39:06 johan Exp $
*
* Copyright 1997-2002, Johan Klockars 
* This software is licensed under the GNU General Public License.
* Please, see LICENSE.TXT for further information.
****/

#define lookup32	0		// Palette lookup for 32 bit vr_trn_fm?

#include	"vdi.inc"
#include	"macros.inc"

	.xref	clip_rect
	.xref	setup_blit,setup_plot
	.xref	expand_area
	.xref	_vr_transfer_bits,_colour_entry

	.xdef	lib_vrt_cpyfm,lib_vro_cpyfm
	.xdef	lib_vr_trn_fm

	.xdef	_lib_vrt_cpyfm,_lib_vro_cpyfm
	.xdef	_lib_vr_trn_fm
	.xdef	_default_expand,_default_blit

	.text

/* lib_vrt_cpyfm - Standard Library function
* Todo: ?
*	Clipping should probably not be done for non-screen destinations
* In:   a1      Parameters (mode, points, source, destination, pens)
*       a0      VDI struct
*/
_lib_vrt_cpyfm:
lib_vrt_cpyfm:
	move.l	14(a1),a2
	move.l	(a2),d0		// Background colour (top word)
	swap	d0		// Foreground colour (bottom word)

	move.l	vwk_real_address(a0),a2
	cmp.w	wk_screen_palette_size(a2),d0
	blo	.okf
	move.w	#BLACK,d0
.okf:
	swap	d0
	cmp.w	wk_screen_palette_size(a2),d0
	blo	.okb
	move.w	#WHITE,d0
.okb:
	swap	d0

	uses_d1
	movem.l	d2-d4/a3-a5,-(a7)

	sub.l	#16,a7		// VDI struct, destination MFDB, VDI struct, source MFDB
	move.l	a0,(a7)
	move.l	a0,8(a7)

	move.l	2(a1),a2	// Get rectangle coordinates
	movem.w	8(a2),d1-d4

	// This should not be done if bitmap scaling is possible!
	move.w	d1,d3		// Do not use lower right destination coordinates at all
	move.w	d2,d4
	sub.w	0(a2),d3
	add.w	4(a2),d3
	sub.w	2(a2),d4
	add.w	6(a2),d4

	bsr	clip_rect	// Clipping necessary?
	blt	.end_vrt_cpyfm	// .end

	movem.w	d1-d4,-(a7)
	sub.w	8(a2),d1	// Calculate clipped source coordinates
	sub.w	10(a2),d2
	add.w	0(a2),d1
	add.w	2(a2),d2

	move.l	10(a1),a2	// a2 - destination MFDB
	move.l	a2,8+4(a7)

	move.l	6(a1),a2	// a2 - source MFDB
	move.l	a2,8+12(a7)

	move.l	vwk_real_address(a0),a3
	move.l	wk_r_expand(a3),d3

	movem.l	d5-d7,-(a7)
	move.w	0(a1),d7	// Mode
	move.l	d3,a1
	movem.w	12(a7),d3-d6	// Destination coordinates
	lea	12+8(a7),a0	// a0 no longer -> VDI struct!
	jsr	(a1)
	move.l	(a0),a0
	movem.l	(a7)+,d5-d7
	addq.l	#8,a7

.end_vrt_cpyfm:			// .end:
	add.l	#16,a7
	movem.l	(a7)+,d2-d4/a3-a5
	used_d1
	moveq	#1,d0		// Successful
	rts

/* _default_expand - Pixel by pixel mono-expand routine
* In:	a0	VDI struct, destination MFDB, VDI struct, source MFDB
*	d0	Colours
*	d1-d2.w	Source coordinates
*	d3-d4.w	Destination start coordinates
*	d5-d6.w	Destination end coordinates
*	d7	Mode
* Call:	a0	VDI struct, destination MFDB
*	d0	Colour values
*	d1-d2.w	Coordinates
*	a3-a4	Set/get pixel
*/
_default_expand:
	movem.l	d0-d7/a0-a6,-(a7)
	movem.w	d3-d4,-(a7)

	move.l	4(a0),d3
	beq	.not2mono
	move.l	d3,a2
	move.l	mfdb_address(a2),d4
	beq	.not2mono
	cmp.w	#1,mfdb_bitplanes(a2)
	bne	.not2mono
	move.l	(a0),a2
	move.l	vwk_real_address(a2),a2
	cmp.l	wk_screen_mfdb_address(a2),d4
	bne	.to_mono
.not2mono:

	move.l	a0,-(a7)
	move.l	(a0),a0
	move.l	vwk_real_address(a0),a2
	move.l	wk_r_get_colour(a2),a2	// Index to real colour
	jsr	(a2)
	move.l	(a7)+,a0

	move.l	a0,a2
	move.l	(a0),a0
	move.w	d7,-(a7)
	bsr	setup_plot
	addq.l	#2,a7
	move.l	a2,a0

	move.l	12(a0),a2	// Source MFDB

	move.l	0(a2),a5	// Point to bitmap
	mulu	8(a2),d2
	add.l	d2,d2
	add.l	d2,a5
	sub.w	8(a2),a5	// Added back below
	sub.w	8(a2),a5	// Added back below
	move.w	d1,d2
	lsr.w	#4,d2
	add.w	d2,d2
	add.w	d2,a5
	and.w	#0x0f,d1
	move.l	a5,-(a7)
	move.w	d1,-(a7)

	move.w	6+2(a7),d2
        
.loopy_pp_vrt:		// .loopy_pp:
	move.w	6+0(a7),d1
	move.l	2(a7),a5	// To start of next row
	add.w	8(a2),a5
	add.w	8(a2),a5
	move.l	a5,2(a7)
	move.w	(a5)+,d3	// Scroll to reach start pixel
	move.w	0(a7),d4
	lsl.w	d4,d3
	neg.w	d4		// Number of pixels left in word
	add.w	#16,d4

.loopx_pp_vrt:		// .loopx_pp:
	lsl.w	#1,d3
	jsr	(a1)
	subq.w	#1,d4		// Fetch new word when needed
	bne	.bits_left
	move.w	(a5)+,d3
	moveq	#16,d4
.bits_left:
	addq.w	#1,d1		// Increase x
	cmp.w	d5,d1
	ble	.loopx_pp_vrt	// .loopx_pp
	addq.w	#1,d2		// Increase y
	cmp.w	d6,d2
	ble	.loopy_pp_vrt	// .loopy_pp
	add.l	#10,a7

.dexp_end:
	movem.l	(a7)+,d0-d7/a0-a6
	rts

.to_mono:
	movem.w	(a7)+,d3-d4
	move.l	a0,a1
	exg	d0,d6
	sub.w	d4,d0
	addq.w	#1,d0
	swap	d0
	move.w	d5,d0
	sub.w	d3,d0
	addq.w	#1,d0
	bsr	expand_area
	bra	.dexp_end

* _default_blit - Pixel by pixel blit routine
* In:	a0	VDI struct, destination MFDB, VDI struct, source MFDB
*	d0	Mode
*	d1-d2.w	Source coordinates
*	d3-d4.w	Destination start coordinates
*	d5-d6.w	Destination end coordinates
* Call:	a0	VDI struct, destination MFDB, VDI struct, source MFDB
*	d1	Source x (high), destination x (low)
*	d2	Source y (high), destination y (low)
*	a3-a4	Set/get pixel
_default_blit:
	move.l	a0,a2
	move.l	(a0),a0
	move.w	d0,-(a7)
	bsr	setup_blit
	addq.l	#2,a7
	move.l	a2,a0

	cmp.w	d4,d2
	blo	.move_down
	bhi	.move_up
	cmp.w	d3,d1
	blo	.move_down

.move_up:
	swap	d2
	move.w	d4,d2
	swap	d1
	move.w	d3,d1
	move.l	d1,-(a7)
        
.loopy_upp:
	move.l	0(a7),d1
.loopx_upp:
	jsr	(a1)
	add.l	#0x10001,d1	// Increase x
	cmp.w	d5,d1
	ble	.loopx_upp
	add.l	#0x10001,d2	// Increase y
	cmp.w	d6,d2
	ble	.loopy_upp
	add.l	#4,a7
	rts

.move_down:
	add.w	d6,d2
	sub.w	d4,d2
	swap	d2
	move.w	d6,d2
	add.w	d5,d1
	sub.w	d3,d1
	swap	d1
	move.w	d5,d1
	move.l	d1,-(a7)

.loopy_dpp:
	move.l	0(a7),d1
.loopx_dpp:
	jsr	(a1)
	sub.l	#0x10001,d1	// Decrease x
	cmp.w	d3,d1
	bge	.loopx_dpp
	sub.l	#0x10001,d2	// Decrease y
	cmp.w	d4,d2
	bge	.loopy_dpp
	add.l	#4,a7
	rts

#if 0
* lib_vr_trn_fm - Standard Library function
* Todo: Should use C2P from MGIF instead of the current crap!
* In:   a1      Parameters   lib_vr_trn_fm(source, dest)
*       a0      VDI struct
_lib_vr_trn_fm:
lib_vr_trn_fm:
	uses_d1
	movem.l	d2-d7/a3-a6,-(a7)
	move.l	(a1)+,a2
	move.l	(a1),a1
	exg	a1,a2		// a1 - source, a2 - dest

	move.l	mfdb_address(a1),a3
	move.l	mfdb_address(a2),a4
	move.w	mfdb_height(a1),d0
	move.w	mfdb_wdwidth(a1),d1
	move.w	mfdb_bitplanes(a1),d2

	cmp.l	a3,a4
	beq	in_place

//	cmp.w	#1,d2			// Single plane is the same
//	beq	end_vr_trn_fm		//  but needs to copy

	tst.w	mfdb_standard(a1)
	beq	to_standard

* Reorganize standard bitplanes into device specific ones.
* Does not work in place.
* In:	d0.w	mfdb_height
*	d1.w	mfdb_wdwidth (pixels / 16)
*	d2.w	bitplanes
*	a3	mfdb_address source
*	a4	mfdb_address destination
	move.w	d0,d3
	mulu	d1,d3
	add.l	d3,d3			// d3 = pix/16 * height * 2 = words/plane

	move.l	a3,a5

	move.w	d0,d7
	subq.w	#1,d7

 label .loop1,1
	move.w	d1,d6
	subq.w	#1,d6

 label .loop2,2
	move.w	d2,d5
	subq.w	#1,d5

 label .loop3,3
	move.w	(a3),(a4)+
	add.l	d3,a3
	ldbra	d5,.loop3,3
	addq.w	#2,a5
	move.l	a5,a3
	ldbra	d6,.loop2,2
	ldbra	d7,.loop1,1
	bra	finish_up


to_standard:
	move.l	vwk_real_address(a0),a5
	move.l	wk_driver(a5),a5
	move.l	driver_device(a5),a5
	move.w	dev_format(a5),d6
	and.w	#2,d6
	beq	not_chunky_ts

	move.w	d0,d7
	mulu	d1,d7
	add.l	d7,d7			// d7 = pix/16 * height * 2 = words/plane
	moveq	#2,d6

	cmp.w	#16,d2
	bne	.not_16bit_ts
	bsr	to_standard_16
	bra	end_vr_trn_fm

.not_16bit_ts:
	cmp.w	#8,d2
	bne	.not_8bit_ts
	bsr	to_standard_8
	bra	end_vr_trn_fm

.not_8bit_ts:
//	move.w	d1,d6			// Copy source to destination since the
//	mulu	d2,d6			//  current dechunk routine is in-place
//	mulu	d0,d6			// d6 = pix/16 * planes * height * 2 = total words
//
//	subq.l	#1,d6
//	move.l	a3,a5
//	move.l	a4,a6
//5$:
//	move.w	(a5)+,(a6)+
//	dbra	d6,5$

	cmp.w	#32,d2
	bne	not_32bit_ts
	bsr	to_standard_32
	bra	end_vr_trn_fm


* Transform device specific to standard format.
* Works in place due to source copying.
* In:	d0.w	mfdb_height
*	d1.w	mfdb_wdwidth (pixels / 16)
*	d6.w	group result step (2 or 16/32/64)
*	d7.l	single result step (bytes per plane or 2)
*	a3	mfdb_address source
*	a4	mfdb_address destination
to_standard_8:
	sub.w	#16,a7			// This is specialized for 8 bit!
	move.l	a7,a6			// Doesn't seem to work correctly (Jinnee)
	move.l	a4,a5

	move.w	d6,d1

	subq.w	#1,d0

 label .loop0b,0
	swap	d0
	move.w	mfdb_wdwidth(a1),d0
	subq.w	#1,d0

 label .loop1b,1
	movem.l	(a3)+,d2-d5
	movem.l	d2-d5,(a6)
	moveq	#7,d3		// Was 15

 label .loop2b,2
	moveq	#15,d4		// Was 14

 label .loop3b,3
	move.b	0(a6,d4),d5	// Was .w
	add.b	d5,d5		// Was .w
	addx.w	d6,d6		// Was .b
//	roxr.b	#1,d6		// This _is_ the right one!???
	move.b	d5,0(a6,d4)	// Was .w
	subq.l	#1,d4		// Was 2
	lbpl	.loop3b,3
	move.w	d6,(a4)		// Was .b
	add.l	d7,a4

	ldbra	d3,.loop2b,2
	add.w	d1,a5
	move.l	a5,a4
	ldbra	d0,.loop1b,1
	swap	d0
	ldbra	d0,.loop0b,0

	add.w	#16,a7
	rts


to_standard_16:
	sub.w	#32,a7			// This is specialized for 16 bit!
	move.l	a7,a6
	move.l	a4,a5

	move.w	d6,d1

	subq.w	#1,d0			// d0 = height - 1

 label .loop0,0
	swap	d0
	move.w	mfdb_wdwidth(a1),d0
	subq.w	#1,d0			// d1 = width - 1

 label .loop1,1
	movem.l	(a3)+,d2-d5		// Copy 16 words due to bad dechunky routine
	movem.l	d2-d5,(a6)
	movem.l	(a3)+,d2-d5
	movem.l	d2-d5,16(a6)
	moveq	#15,d3			// d3 = bitplanes - 1 

 label .loop2,2
	moveq	#30,d4			// d4 = last word index

 label .loop3,3
	move.w	0(a6,d4),d5
	add.w	d5,d5
//	addx.w	d6,d6
	roxr.w	#1,d6		// This _is_ the right one!
	move.w	d5,0(a6,d4)
	subq.w	#2,d4
	lbpl	.loop3,3
	move.w	d6,(a4)
	add.l	d7,a4

	ldbra	d3,.loop2,2
	add.w	d1,a5
	move.l	a5,a4
	ldbra	d0,.loop1,1
	swap	d0
	ldbra	d0,.loop0,0

	add.w	#32,a7
	rts


to_standard_32:
	sub.w	#64,a7			// This is specialized for 32 bit!
	move.l	a7,a6			// Doesn't seem to work correctly (Jinnee)
	move.l	a4,a5

	move.w	d6,d1

	subq.w	#1,d0

 label .loop0c,0
	swap	d0
	move.w	mfdb_wdwidth(a1),d0
	subq.w	#1,d0

 label .loop1c,1
	movem.l	(a3)+,d2-d5
	movem.l	d2-d5,(a6)
	movem.l	(a3)+,d2-d5
	movem.l	d2-d5,16(a6)
	movem.l	(a3)+,d2-d5
	movem.l	d2-d5,32(a6)
	movem.l	(a3)+,d2-d5
	movem.l	d2-d5,48(a6)
	moveq	#31,d3		// Was 15

 label .loop2c,2
	moveq	#60,d4		// Was 62

 label .loop3c,3
	move.l	0(a6,d4),d5	// Was .w
	add.l	d5,d5		// Was .w
	addx.w	d6,d6		// Was .l
//	roxr.l	#1,d6		// This _is_ the right one!
	move.l	d5,0(a6,d4)	// Was .w
	subq.l	#4,d4		// Was 2
	lbpl	.loop3c,3
	move.w	d6,(a4)		// Was .l
	add.l	d7,a4

	ldbra	d3,.loop2c,2
	add.w	d1,a5
	move.l	a5,a4
	ldbra	d0,.loop1c,1
	swap	d0
	ldbra	d0,.loop0c,0

	add.w	#64,a7
	rts


not_32bit_ts:
not_chunky_ts:
	move.w	d2,d3			// Reorganize device specific
	add.w	d3,d3			//  bitplanes into standard ones

	move.l	a3,a5

	move.w	d2,d7
	subq.w	#1,d7

 label .loop1d,1
	move.w	d0,d6
	subq.w	#1,d6

 label .loop2d,2
	move.w	d1,d5
	subq.w	#1,d5

 label .loop3d,3
	move.w	(a3),(a4)+
	add.w	d3,a3
	ldbra	d5,.loop3d,3
	ldbra	d6,.loop2d,2
	addq.w	#2,a5
	move.l	a5,a3
	ldbra	d7,.loop1d,1
	bra	end_vr_trn_fm


in_place:
	cmp.w	#1,d2			// Single plane is the same
	beq	end_vr_trn_fm
	tst.w	mfdb_standard(a1)
	beq	to_standard_ip

* Reorganize standard bitplanes into device specific ones.
* In:	d0.w	mfdb_height
*	d1.w	mfdb_wdwidth (pixels / 16)
*	d2.w	bitplanes
*	a3	mfdb_address source
*	a4	mfdb_address destination
	move.w	d0,d7			// Reorganize standard bitplanes
	move.w	d1,d6			//  into device specific ones

	move.w	d1,d3
	mulu	d2,d3
	mulu	d0,d3
	add.l	d3,d3			// d0 = pix/16 * planes * height * 2 = total bytes

	mulu	d0,d1
	add.w	d1,d1			// d1 = bytes per standard line * height

	move.l	d3,d0
	subq.l	#2,d0
	subq.l	#2,d1
	addq.l	#2,a4

	move.l	a0,-(a7)

	subq.w	#1,d7

 label .loop1,1
	move.w	d6,d5
	subq.w	#1,d5

 label .loop2,2
	move.w	d2,d4
	subq.w	#1,d4

 label .loop3,3
	move.l	a4,a0
	bsr	rotate_mem
	addq.l	#2,a4
	subq.l	#2,d0
	ldbra	d4,.loop3,3
	subq.w	#2,d1
	ldbra	d5,.loop2,2
	ldbra	d7,.loop1,1

	move.l	(a7)+,a0
	bra	finish_up


to_standard_ip:			// Should have code for chunky modes (working on it)
	move.l	vwk_real_address(a0),a5
	move.l	wk_driver(a5),a5
	move.l	driver_device(a5),a5
	move.w	dev_format(a5),d6
	and.w	#2,d6
	beq	.not_chunky_ts_ip

	move.w	d0,d7
	mulu	d1,d7
	add.l	d7,d7			// d7 = pix/16 * height * 2 = words/plane
	moveq	#2,d6

	cmp.w	#16,d2
	bne	.not_16bit_ts_ip
	bsr	to_standard_16
	bra	end_vr_trn_fm

.not_16bit_ts_ip:
	cmp.w	#8,d2
	bne	.not_8bit_ts_ip
	bsr	to_standard_8
	bra	end_vr_trn_fm

.not_8bit_ts_ip:
//	move.w	d1,d6			// Copy source to destination since the
//	mulu	d2,d6			//  current dechunk routine is in-place
//	mulu	d0,d6			// d6 = pix/16 * planes * height * 2 = total words
//
//	subq.l	#1,d6
//	move.l	a3,a5
//	move.l	a4,a6
//5$:
//	move.w	(a5)+,(a6)+
//	dbra	d6,5$

	cmp.w	#32,d2
	bne	.not_32bit_ts_ip
	bsr	to_standard_32
	bra	end_vr_trn_fm


  .ifne 0
	cmp.w	#16,d2
	bne	.not_16bit_ts_ip

	cmp.w	#1,d1
	bne	.can_not_do_this_yet
	cmp.w	#16,mfdb_width(a1)
	bne	.can_not_do_this_yet

	move.w	(a3),d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7
	move.w	d7,d6
	and.w	#$8000,d6
	move.w	d6,(a4)+
	add.w	d7,d7

	bra	end_vr_trn_fm

.can_not_do_this_yet:
.not_16bit_ts_ip:
	bra	end_vr_trn_fm
  .endc


.not_32bit_ts_ip:
.not_chunky_ts_ip:
	exg	d1,d2

	move.w	d0,d7
	move.w	d1,d6

	move.w	d1,d3
	mulu	d2,d3
	mulu	d0,d3
	add.l	d3,d3			// d3 = pix/16 * planes * height * 2 = total bytes

	add.w	d1,d1			// d1 = bytes per 16 pixel block

	move.l	d3,d0
	subq.l	#2,d0
	subq.w	#2,d1
	ext.l	d1
	addq.l	#2,a4

	move.l	a0,-(a7)

	subq.w	#1,d6

 label .loop1,1
	move.w	d7,d5
	subq.w	#1,d5

 label .loop2,2
	move.w	d2,d4
	subq.w	#1,d4

 label .loop3,3
	move.l	a4,a0
	bsr	rotate_mem
	addq.l	#2,a4
	subq.l	#2,d0
	ldbra	d4,.loop3,3
	ldbra	d5,.loop2,2
	subq.w	#2,d1
	ldbra	d6,.loop1,1

	move.l	(a7)+,a0
	bra	end_vr_trn_fm


finish_up:
	move.l	vwk_real_address(a0),a4	// Should this really check driver?
	move.l	wk_driver(a4),a4
	move.l	driver_device(a4),a4
	move.w	dev_format(a4),d0
	and.w	#2,d0
	beq	.not_chunky

	move.w	mfdb_bitplanes(a1),d0
	cmp.w	#16,d0
	bne	.not_16bit
	move.l	mfdb_address(a2),a4
	move.l	a4,a3
	move.w	mfdb_height(a1),d0
	moveq	#32,d6
	moveq	#2,d7
	bsr	to_standard_16		// Is its own inverse!
	bra	end_vr_trn_fm


.not_16bit:
	cmp.w	#8,d0
	bne	.not_8bit

	sub.w	#16,a7			// This is specialized for 8 bit!
	move.l	a7,a3
	move.l	mfdb_address(a2),a4
	move.w	mfdb_height(a1),d0

	subq.w	#1,d0

 label .loop0,0
	move.w	mfdb_wdwidth(a1),d1
	subq.w	#1,d1

 label .loop1,1
	movem.l	(a4),d2-d5
	movem.l	d2-d5,(a3)
	moveq	#15,d3

 label .loop2,2
	moveq	#14,d4

 label .loop3,3
	move.w	0(a3,d4),d5
	add.w	d5,d5
	addx.b	d6,d6
//	roxr.b	#1,d6		// This _is_ the right one!???
	move.w	d5,0(a3,d4)
	subq.w	#2,d4
	lbpl	.loop3,3
	move.b	d6,(a4)+

	ldbra	d3,.loop2,2
	ldbra	d1,.loop1,1
	ldbra	d0,.loop0,0

	add.w	#16,a7
	bra	end_vr_trn_fm


.not_8bit:
	cmp.w	#32,d0
	bne	.not_32bit

	move.l	vwk_real_address(a0),a5
	lea	vdi_colours,a6

	move.l	vwk_palette(a0),d0
	bne	.local_palette
	move.l	wk_screen_palette_colours(a5),d0
.local_palette:
	move.l	d0,a5

	sub.w	#64,a7			// This is specialized for 32 bit!
	move.l	a7,a3
	move.l	mfdb_address(a2),a4
	move.w	mfdb_height(a1),d0

	subq.w	#1,d0

 label .loop0b,0
	move.w	mfdb_wdwidth(a1),d1
	subq.w	#1,d1

 label .loop1b,1
	movem.l	(a4),d2-d5
	movem.l	d2-d5,(a3)
	movem.l	16(a4),d2-d5
	movem.l	d2-d5,16(a3)
	movem.l	32(a4),d2-d5
	movem.l	d2-d5,32(a3)
	movem.l	48(a4),d2-d5
	movem.l	d2-d5,48(a3)
	moveq	#15,d3

 label .loop2b,2
	moveq	#62,d4

 label .loop3b,3
	move.w	0(a3,d4),d5
	add.w	d5,d5

  .ifne lookup32
	addx.l	d6,d6
	move.w	d5,0(a3,d4)
	subq.w	#2,d4
	lbpl	.loop3b,3

	and.w	#$00ff,d6		// Higher palette entries aren't possible (optimize above!)

	cmp.b	#16,d6
	lblo	.lookup,5		// 0-15
	cmp.b	#255,d6
	lbne	.colour_ok,6		// 16-254
	moveq	#1,d6
	lbra	.colour_ok,6

 label .lookup,5
	move.b	0(a6,d6),d6

 label .colour_ok,6

	lsl.w	#4,d6			// Assume 16 byte palette entries
	move.l	12(a5,d6),d5
	ror.w	#8,d5
	swap	d5
	ror.w	#8,d5
	swap	d5
	move.l	d5,(a4)+
  .else
	roxr.l	#1,d6		// This _is_ the right one!
	move.w	d5,0(a3,d4)
	subq.w	#2,d4
	lbpl	.loop3b,3

	move.l	d6,(a4)+
  .endc

 label .skipb,4
	ldbra	d3,.loop2b,2
	ldbra	d1,.loop1b,1
	ldbra	d0,.loop0b,0

	add.w	#64,a7
	bra	end_vr_trn_fm

.not_32bit:
.not_chunky:		

end_vr_trn_fm:
	moveq	#1,d0
	tst.w	mfdb_standard(a1)
	beq	.was_not_standard
	moveq	#0,d0
.was_not_standard:
	move.w	d0,mfdb_standard(a2)
	movem.l	(a7)+,d2-d7/a3-a6
	used_d1
	rts
#endif
