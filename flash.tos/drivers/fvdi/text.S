/****
* fVDI text drawing functions
*
* $Id: text.s,v 1.8 2005/05/07 18:38:55 standa Exp $
*
* Copyright 1997-2003, Johan Klockars 
* This software is licensed under the GNU General Public License.
* Please, see LICENSE.TXT for further information.
****/

#define transparent	1		// Fall through?

#include	"vdi.inc"
#include	"macros.inc"

	.xref	lib_vrt_cpyfm
	.xref	_allocate_block,_free_block
	.xref	text_area

	.xdef	_default_text

	.data

	
/* _default_text - Buffer rendering or individual character mono-expand text routine
* Todo:	Add effects of effects to the size
* In:	a0	VDI struct
*	a1	Pointer to string
*	a2	Pointer to character offset table or zero
*	d0	String length
*	d1	Coordinates
* Call:	a0	VDI struct
*	a1	Parameters for lib_vrt_cpyfm
*/
_default_text:
	movem.l	d3-d7/a3-a6,-(sp)

/* Some other method should be used for this! */
	move.l	vwk_text_current_font(a0),a3

	moveq	#0,d4		// Offset extension of length
	move.l	a2,d3
	beq	.no_offsets
	move.l	a2,a3
	move.w	d0,d3
	subq.w	#1,d3
.test_offsets:
	move.l	(a3)+,d5
	beq	.no_offset_here
	tst.w	d5
	bne	.single_char
	swap	d5
	add.w	d5,d4
.no_offset_here:
	dbra	d3,.test_offsets
.no_offsets:

	move.l	d0,a3
	movem.l      d1-d2/a0-a2,-(sp)
	clr.l	-(sp)			// Get a memory block of any size (hopefully large)
	jsr	_allocate_block
	addq.l	#4,sp
	movem.l      (sp)+,d1-d2/a0-a2
	tst.l	d0
	exg	d0,a3
	beq	.single_char
	move.l	a3,-(sp)			// For free_block below

	move.l	vwk_text_current_font(a0),a5	// Font structure
	move.w	font_height(a5),d5
	swap	d5

	btst	#3,font_flags(a5)		// Proportional?
	bne	.nonproportional

	movem.l	d0-d2/d4/a1/a3,-(sp)
	move.l	font_table_character(a5),a3
	move.w	font_code_low(a5),d2
	move.w	font_code_high(a5),d4
	moveq	#0,d3			// Width total
	lbra	.no_char2
.size_loop1:
	move.w	(a1)+,d1
	sub.w	d2,d1			// Negative numbers are higher
	cmp.w	d4,d1			//  than code_high
	lbhi	.no_char2
	add.w	d1,d1
	add.w	2(a3,d1.w),d3
	sub.w	0(a3,d1.w),d3
.no_char2:
	ldbra	d0,.size_loop1
	movem.l	(sp)+,d0-d2/d4/a1/a3
	bra	.width_done
	
.nonproportional:
	move.w	font_widest_cell(a5),d3
	mulu	d0,d3

.width_done:

	tst.w	d4
	beq	.keep_width
	move.w	d4,d3
	add.w	font_widest_cell(a5),d3
.keep_width:
	move.w	d3,d5
	add.w	#15,d5
	lsr.w	#4,d5
	addq.w	#1,d5
	and.w	#0xfffe,d5	// Even number of words wide
	add.w	d5,d5		// d5 - height, bytes wide

	movem.l	d1/d3,-(sp)
	movem.l	d5/a0/a3/a5,-(sp)

	tst.w	d4
	beq	.no_clear
	move.l	d5,d1
	swap	d1
	mulu	d5,d1
	lsr.w	#4,d1
	moveq	#0,d3
	moveq	#0,d4
	moveq	#0,d5
	moveq	#0,d6
.loop_1:
	movem.l	d3-d6,(a3)
	add.l	#16,a3
	ldbra	d1,.loop_1
	movem.l	(sp),d5/a0/a3/a5
.no_clear:

	move.l	a1,a4				// String address
	sub.l	a1,a1				// Clip rectangle
	moveq	#5,d6				// Fake top line alignment
	moveq	#0,d3				// Coordinates
	moveq	#0,d4
	bsr	text_area
	move.l	4(sp),a0
	move.w	vwk_text_effects(a0),d0
	btst	#0,d0
	beq	.no_bold	
	movem.l	(sp),d5/a0/a3/a5
	move.l	a3,a0
	move.l	a3,a1
	move.w	d5,a6
	move.w	d5,d3
	lsr.w	#1,d3
	swap	d5
	move.w	d5,d7
	move.w	font_thickening(a5),d4
	bsr	bold
	move.l	4(sp),a0
	move.w	vwk_text_effects(a0),d0
.no_bold:

	btst	#3,d0
	beq	.no_underline
	movem.l	(sp),d5/a0/a3/a5
	move.w	d5,d0
	move.w	font_distance_top(a5),d1
	addq.w	#1,d1
	mulu	d0,d1
	add.l	d1,a3
	lsr.w	#2,d0
	subq.w	#1,d0
	move.w	font_underline(a5),d1
	subq.w	#1,d1
	moveq	#-1,d3
.loop11:
	move.l	a3,a0
	move.w	d0,d2
.loop22:
	move.l	d3,(a0)+
	ldbra	d2,.loop22
	add.w	d5,a3
	ldbra	d1,.loop11
	move.l	4(sp),a0
	move.w	vwk_text_effects(a0),d0
.no_underline:

	btst	#2,d0
	beq	.no_italic
	movem.l	(sp),d5/a0/a3/a5
	move.w	font_distance_top(a5),d1
	move.w	d5,d0
	add.w	font_distance_bottom(a5),d1
	addq.w	#1,d1
	mulu	d0,d1
	add.l	d1,a3
	lsr.w	#1,d0
	subq.w	#2,d0
	move.l	d5,d1
	swap	d1
	subq.w	#1,d1
	move.w	font_skewing(a5),d3
	moveq	#0,d4
.loop1b1:
	move.l	a3,a0
	move.w	d0,d2
.loop2b2:
	move.l	-4(a0),d6
	lsr.l	d4,d6
	move.w	d6,-(a0)
	ldbra	d2,.loop2b2
	moveq	#0,d6
	move.w	-(a0),d6
	lsr.l	d4,d6
	move.w	d6,(a0)
	sub.w	d5,a3
	rol.w	#1,d3
	lbcc	.skip3
	addq.w	#1,d4
.skip3:
	ldbra	d1,.loop1b1
	move.l	4(sp),a0
	move.w	vwk_text_effects(a0),d0
.no_italic:

	btst	#4,d0
	beq	.no_outline
	movem.l	(sp),d5/a0/a3/a5
	move.l	a3,a0
	move.l	a3,a1
	move.w	d5,a6
	move.w	d5,d3
	swap	d5
	move.w	d5,d7
	mulu	d3,d5
	add.l	d5,a1
	move.l	a1,8(sp)		// New bitmap address
	lsr.w	#1,d3
	bsr	outline
	move.l	4(sp),a0
	move.w	vwk_text_effects(a0),d0
.no_outline:

	btst	#1,d0
	beq	.no_light
	movem.l	(sp),d5/a0/a3/a5
	move.w	d5,d0
	lsr.w	#2,d0
	subq.w	#1,d0
	move.l	d5,d1
	swap	d1
	subq.w	#1,d1
	move.w	font_lightening(a5),d2
	move.w	d2,d3
	swap	d3
	move.w	d2,d3
.loop1c1:
	move.l	a3,a0
	move.w	d0,d2
.loop2c2:
	and.l	d3,(a0)+
	ldbra	d2,.loop2c2
	add.w	d5,a3
	rol.l	#1,d3
	ldbra	d1,.loop1c1
.no_light:

	movem.l	(sp)+,d5/a0/a3/a5
	movem.l	(sp)+,d1/d3

	move.l	vwk_text_colour(a0),d0
	swap	d0
	move.l	d0,-(sp)
                                                    // Create pens
	sub.l	#20,sp		// Create source MFDB for rendering buffer
	move.l	a3,mfdb_address(sp)	// Start address of buffer
	move.w	d5,d0
	lsr.w	#1,d0
	move.w	d0,mfdb_wdwidth(sp)	// Width in words
	lsl.w	#4,d0
	move.w	d0,mfdb_width(sp)	// Width in pixels
	swap	d5
	move.w	d5,mfdb_height(sp)	// Height in pixels
	move.w	#1,mfdb_standard(sp)	// Standard format
	move.w	#1,mfdb_bitplanes(sp)	// Monochrome

	sub.l	#16,sp			// Create points
	clr.l	(sp)		// Source left, top
	subq.w	#1,d3
	move.w	d3,4(sp)		// Source right
	subq.w	#1,d5
	move.w	d5,6(sp)		// Source bottom

	move.l	vwk_text_current_font(a0),a5	// Font structure
	move.w	vwk_text_alignment_vertical(a0),d4
	add.w	d4,d4
	add.w	font_extra_distance(a5,d4.w),d1
	move.l	d1,8(sp)		// Destination left,top
	add.w	d5,d1
	move.w	d1,14(sp)		// Destination bottom
	swap	d1
	add.w	d3,d1
	move.w	d1,12(sp)		// Destination right

	sub.l	#18,sp			// Create parameters
	move.w	vwk_mode(a0),(sp)	// Mode
	lea	18(sp),a3
	move.l	a3,2(sp)		// Points
	lea	16(a3),a3
	move.l	a3,6(sp)		// Source MFDB
	clr.l	10(sp)		// Screen as destination
	lea	20(a3),a3
	move.l	a3,14(sp)		// Pens

	move.l	sp,a1
	jsr	lib_vrt_cpyfm

	add.l	#18+16+20+4,sp

	jsr	_free_block
	addq.l	#4,sp

	movem.l	(sp)+,d3-d7/a3-a6
	rts


.single_char:
	sub.l	#4,sp			// Create pens
	move.l	vwk_text_colour(a0),d5
	swap	d5
	move.l	d5,0(sp)

	sub.l	#20,sp			// Create source MFDB for font
	move.l	vwk_text_current_font(a0),a5	// Font structure
	move.l	font_data(a5),d5
	move.l	d5,mfdb_address(sp)	// Start address of font
	move.w	font_width(a5),d5
	lsr.w	#1,d5
	move.w	d5,mfdb_wdwidth(sp)	// Width in words
	lsl.w	#4,d5
	move.w	d5,mfdb_width(sp)	// Width in pixels
	move.w	font_height(a5),mfdb_height(sp)	// Height in pixels
	move.w	#1,mfdb_standard(sp)	// Standard format
	move.w	#1,mfdb_bitplanes(sp)	// Monochrome

	sub.l	#16,sp			// Create points
	clr.w	2(sp)		// Source top
	move.w	font_height(a5),d5
	subq.w	#1,d5
	move.w	d5,6(sp)		// Source bottom

	move.l	d1,d3

	move.w	vwk_text_alignment_vertical(a0),d4
	add.w	d4,d4
	add.w	font_extra_distance(a5,d4.w),d3
	move.l	d3,8(sp)		// Destination left,top
	add.w	d5,d3
	move.w	d3,14(sp)		// Destination bottom
	swap	d3
	subq.w	#1,d3			// Previous character's right edge,
	move.w	d3,12(sp)		//   current width is added below

	sub.l	#18,sp			// Create parameters
	move.w	vwk_mode(a0),0(sp)	// Mode
	lea	18(sp),a3
	move.l	a3,2(sp)		// Points
	lea	16(a3),a3
	move.l	a3,6(sp)		// Source MFDB
	clr.l	10(sp)		// Screen as destination
	lea	20(a3),a3
	move.l	a3,14(sp)		// Pens

	move.l	a1,a3			// String
	move.w	d0,d3			// Length
	move.w	font_code_low(a5),d1	// First character

	move.l	font_table_character(a5),a5	// Character offset table

	move.l	a2,d0
	bne	.loopend_offset
	bra	.loopend

.loop_char:			// .loop:
	move.w	(a3)+,d4	// Get character
	sub.w	d1,d4
	add.w	d4,d4
	move.w	0(a5,d4.w),d0
	move.w	d0,0+18(sp)	// Character source left coordinate
	move.w	2(a5,d4.w),d5
	move.w	d5,4+18(sp)	// Character source right coordinate
	sub.w	d0,d5		// Character width
	add.w	d5,12+18(sp)	// Character destination right coordinate
	
	move.l	sp,a1
	jsr	lib_vrt_cpyfm

	add.w	d5,8+18(sp)	// Increase destination x coordinate

.loopend:
	dbra	d3,.loop_char

.default_text_end:
	add.l	#18+16+20+4,sp
	movem.l	(sp)+,d3-d7/a3-a6
	rts

.loop_offset:			// .loop:
	move.w	(a3)+,d4	// Get character
	sub.w	d1,d4
	add.w	d4,d4
	move.w	0(a5,d4.w),d0
	move.w	d0,0+18(sp)	// Character source left coordinate
	move.w	2(a5,d4.w),d5
	move.w	d5,4+18(sp)	// Character source right coordinate
	sub.w	d0,d5		// Character width
	add.w	8+18(sp),d5
	subq.w	#1,d5
	move.w	d5,12+18(sp)	// Character destination right coordinate
	
	move.l	sp,a1
	move.l	a2,-(sp)
	jsr	lib_vrt_cpyfm
	move.l	(sp)+,a2

.loopend_offset:
	move.w	(a2)+,d4

	add.w	d4,8+18(sp)	// Increase destination x/y coordinates
	move.w	(a2)+,d4
	add.w	d4,10+18(sp)
	
	dbra	d3,.loop_offset
	bra	.default_text_end


/* In:	a0	area1
*	a1	area2
*	a6	wrap
*	d4	fattening
*	d3	words
*	d7	lines
*/
bold:
	move.w	d3,d0
	add.w	d0,d0
	sub.w	d0,a6
	subq.w	#1,d4
	subq.w	#1,d3
	subq.w	#1,d7
.lines_b:
	.ifne 1
	moveq	 #0,d1
	.endc
	move.w	d3,d6
.words_b:
	.ifne 1
	move.w	(a0)+,d0
	move.w	d0,d1
	swap	d0
	move.w	d1,d0		// Remember in top word
	.else
	move.l	(a0)+,d1	// Doesn't work in place
	addq.l	#2,a0  
	.endc
	move.w	d4,d5
.shifts_b:
	lsr.l	#1,d1
	or.w	d1,d0
	dbra	d5,.shifts_b
	move.w	d0,(a1)+
	.ifne 1
	move.l	d0,d1		// Restore top word
	.endc
	dbra	d6,.words_b
	add.l	a6,a0
	add.l	a6,a1
	dbra	d7,.lines_b
	rts


/* In:	a0	area1
*	a1	area2
*	a6	wrap
*	d3	words
*	d7	lines
*/
outline:
/* Do <-x-> expansion rather than bold(2) (x->->). Easier EOR stage. */
	move.l	a6,a3
	sub.w	d3,a3
	sub.w	d3,a3
	subq.w	#1,d7
	move.w	d7,d0
	swap	d7
	move.w	d0,d7
	subq.w	#1,d3
	move.l	a0,a4 // area1
	move.l	a1,a5 // area2
.lines_o1:
	move.w	d3,d6
	moveq	#0,d1
	move.w	(a0)+,d1
	move.w	d1,d2
.words_o1:
	move.w	d1,d0
	swap	d2
	move.w	(a0)+,d2
	lsr.l	#1,d1
	or.w	d1,d0
	move.l	d2,d1
	add.l	d1,d1
	swap	d1
	or.w	d1,d0
	move.l	d2,d1
	move.w	d0,(a1)+
	dbra	d6,.words_o1
	add.l	a3,a0
	subq.l	#2,a0
	add.l	a3,a1
	dbra	d7,.lines_o1

/* Optimization to think about:  combine EOR into vertical bold. */

	swap	d7
	addq.w	#2,d3
	and.w	#0xfffe,d3
	lsr.w	#1,d3
	subq.w	#1,d3
.longs_o2:
	move.l	a4,a1 // area1
	move.l	a5,a0 // area2
	move.w	d7,d6
	moveq	#0,d0
	move.l	(a0),d1
	add.l	a6,a0
.lines_o2:
	move.l	(a0),d2
	or.l	d1,d0
	or.l	d2,d0
	move.l	(a1),d5
	eor.l	d5,d0
	move.l	d0,(a0)
	move.l	d1,d0
	move.l	d2,d1	
	add.l	a6,a0
	add.l	a6,a1
	dbra	d6,.lines_o2
	or.l	d1,d0
	move.l	d0,(a0)
	addq.l	#4,a4
	addq.l	#4,a5
	dbra	d3,.longs_o2
	rts

#if 0

dscale:
  .ifne 0
	move.w	(a0)+,d0
	moveq	#15,d5
	moveq	#15,d7
	add.w	d0,d0
	scs	d6
.put_d:
	add.w	d3,d3
	sub.b	d6,d3
	subq.w	#1,d7
	bpl	.no_write_d
	move.w	d3,(a1)+
	moveq	#15,d7
.no_write_d:
	subq.w	#1,d5
	bpl	.no_fetch_d
	subq.w	#1,d4
	bmi	.finished_d
	move.w	(a0)+,d0
	moveq	 #15,d5
.no_fetch_d:
	add.w	d0,d0
	scs	d6
	add.w	d1,d2
	bvc	.no_write_d
	bra	.put_d	
  .else
	moveq	#15,d7
.not_finished_d:
	move.w	(a0)+,d0
	moveq	 #15,d5
.no_fetch_d:
	add.w	d1,d2
	bvc	.no_write_d
.put_d:
	add.w	d0,d0
	addx.w	d3,d3
	dbra	d7,.no_write_d1
	move.w	d3,(a1)+
	moveq	#15,d7
.no_write_d1:
	dbra	d5,.no_fetch_d
	dbra	d4,.not_finished_d
	bra	.finished_d
.no_write_d:
	add.w	d0,d0
	dbra	d5,.no_fetch_d
	dbra	d4,.not_finished_d
  .endc
.finished_d:
	cmp.w	#15,d7
	bne	.done_d
	lsl.w	d7,d3
	move.w	d3,(a1)+
.done_d:
	rts


uscale:
  .ifne 0
	move.w	(a0)+,d0
	moveq	#15,d5
	moveq	#15,d7
	add.w	d0,d0
	scs	d6
.put_u:
	add.w	d3,d3
	sub.b	d6,d3
	subq.w	#1,d7
	bpl	.no_write_u
	move.w	d3,(a1)+
	moveq	#15,d7
.no_write_u:
	add.w	d1,d2
	bvc	.put_u
	subq.w	#1,d5
	bpl	.no_fetch_u
	subq.w	#1,d4
	bmi	.finished_u
	move.w	(a0)+,d0
	moveq	 #15,d5
.no_fetch_u:
	add.w	d0,d0
	scs	d6
	bra	.put_u
  .else
	moveq	#15,d7
.not_finished_u:
	move.w	(a0)+,d0
	moveq	#15,d5
.no_fetch_u:
	add.w	d0,d0
	scs	d6
.put_u:
	add.w	d3,d3
	sub.b	d6,d3
	dbra	d7,.no_write_u
	move.w	d3,(a1)+
	moveq	#15,d7
.no_write_u:
	add.w	d1,d2
	bvc	.put_u
	dbra	d5,.no_fetch_u
	dbra	d4,.not_finished_u
	bra	.finished_u
  .endc
.finished_u:
	cmp.w	#15,d7
	bne	.done_u
	lsl.w	d7,d3
	move.w	d3,(a1)+
.done_u:
	rts

#endif
