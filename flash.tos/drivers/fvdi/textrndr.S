/****
* fVDI text rendering functions
*
* Copyright 1999-2000, Johan Klockars 
* This software is licensed under the GNU General Public License.
* Please, see LICENSE.TXT for further information.
*/

#define only_16	1


#include		"vdi.inc"

	.xdef		text_area,_text_area


#define locals	40
#define length	locals-2
#define h_w		length-4
#define font_addr	h_w-4
#define text_addr	font_addr-4
#define code_low	text_addr-2
#define screen_addr	code_low-4
#define dest_x	screen_addr-2
#define wraps	dest_x-4
#define offset_tab	wraps-4
#define offset_mods	offset_tab-4


	.data

/* In:	a1	pointer to clip rectangle or zero
*	a2	offset table
*	d0	string length
*	d3-d4	destination coordinates
*	d6	vertical alignment
*	a3	buffer
*	d5	buffer wrap
*	a4	pointer to first character
*	a5	font structure address  
*/
// Needs to do its own clipping
_text_area:
text_area:
//	cmp.l		#0,a2
//	beq		.no_offsets
//	moveq		#0,d0			// Can't deal with this yet
//	rts
//.no_offsets:
	lea		-locals(sp),sp

	cmp.l		#0,a2
	beq		.no_offset_mods0
	add.w		(a2),d3
	addq.l		#4,a2
.no_offset_mods0:
	move.l		a2,offset_mods(sp)

	move.w		d0,length(sp)		// String length to stack
	beq		no_draw

	move.w		d5,wraps+2(sp)
	add.w		d6,d6
	add.w		font_extra_distance(a5,d6.w),d4
	move.w		font_width(a5),d5	// Source wrap (later high word)
	sub.l		a0,a0
	move.l		font_table_character(a5),a6
	move.l		a6,offset_tab(sp)

	move.w		font_height(a5),d0	// d0 - lines to blit (later high word)
	moveq		#0,d1			// d1 - source x-coordinate

	move.l		a1,d6
	beq		no_clip

	move.w		6(a1),d6		// y2
	sub.w		d0,d6
	sub.w		d4,d6
	addq.w		#1,d6			// d6 = max_y - (dest_y + font_height - 1)
	bge		.way_down		// No bottom clipping needed if >=0
	add.w		d6,d0			//  else fewer lines to blit
.way_down:
	move.w		2(a1),d6		// y1
	move.w		d6,d7
	sub.w		d4,d7			// d7 = min_y - dest_y
	ble		.from_top		// No top clipping needed if <=0
	sub.w		d7,d0			//  else fewer lines to blit
	move.w		d7,a0			//  and start on a lower line
	move.w		d6,d4
.from_top:
	tst.w		d0
	ble		no_draw

	swap		d0
	swap		d5

	move.w		4(a1),d0		// x2
	cmp.w		d0,d3
	bgt		no_draw

	sub.w		d3,d0
	move.w		0(a1),d7		// x1
	addq.w		#1,d0			// d0.w width of clip window
	cmp.w		d7,d3
	bge		clip_done		// If not within clip window
	move.w		d7,d1			//  calculate distance to first visible pixel
	sub.w		d3,d1
	sub.w		d1,d0
	move.w		d7,d3			//  and set new destination start x-coordinate

	move.w		font_code_low(a5),d5
	move.w		length(sp),d2

	move.w		font_flags(a5),d6
	and.w		#8,d6
	bne		monospace_first
.next_char:
	subq.w		#1,d2
	bmi		no_draw
	move.w		(a4)+,d6
	sub.w		d5,d6
	add.w		d6,d6
	move.w		2(a6,d6.w),d7		// Start of next character
	sub.w		0(a6,d6.w),d7		// Start of this character
	sub.w		d7,d1
	bgt		.next_char
	beq		first_char
	add.w		d7,d1
	subq.l		#2,a4
	addq.w		#1,d2
first_char:
	move.w		d2,length(sp)

clip_done:
	sub.l		#0x10000,d0		// Height only used via dbra
	move.l		d0,h_w(sp)		// Height and width to display
	move.w		a0,d2			// Number of lines down to start draw from in font
	move.w		(a4)+,d6
	move.l		a4,text_addr(sp)	// Address of next character
	move.w		font_code_low(a5),code_low(sp)
	move.w		d3,dest_x(sp)

	move.l		a3,a0			// Buffer address

	move.w		wraps+2(sp),d5		// d5 - wraps (source dest)
	move.l		d5,wraps(sp)
	mulu.w		d5,d4
	add.l		d4,a0
	move.l		a0,a1
	move.l		a1,screen_addr(sp)

	tst.l		offset_mods(sp)
	bne		.no_display4
	tst.w		font_extra_unpacked_format(a5)	// Quick display applicable?
	bne		display4
.no_display4:

	swap		d5			// Not nice that I have to do this
	mulu		d5,d2			// Perhaps there is a better way?
	swap		d5
	add.l		font_data(a5),d2
	move.l		d2,font_addr(sp)

	move.w		d1,d2
	sub.w		code_low(sp),d6
	add.w		d6,d6
	move.w		0(a6,d6.w),d4		// Start of this character
	add.w		d4,d1
	sub.w		2(a6,d6.w),d4
	neg.w		d4
	sub.w		d2,d4
	cmp.w		d4,d0
	bls		.last_char1		// If not last character (clipping)
	move.w		d4,d0			//  blit full character width
.last_char1:
	sub.w		d0,h_w+2(sp)		// Lower free width

	move.l		offset_mods(sp),d6
	beq		.no_offset_mods1
	move.l		d6,a2
	move.w		d3,d4
	add.w		(a2),d4
	addq.l		#4,d6
	move.l		d6,offset_mods(sp)
	bra		.had_offset_mods1
.no_offset_mods1:

	add.w		d3,d4
.had_offset_mods1:
	move.w		d4,dest_x(sp)

	move.l		font_addr(sp),a0
	bsr		draw_char

.loop:
	subq.w		#1,length(sp)
	ble		no_draw
	move.l		h_w(sp),d0
	tst.w		d0
	beq		no_draw

	move.l		text_addr(sp),a0
	move.w		(a0)+,d6
	move.l		a0,text_addr(sp)
	move.l		screen_addr(sp),a1
	move.w		dest_x(sp),d3
	move.l		wraps(sp),d5

	move.l		offset_tab(sp),a0
	sub.w		code_low(sp),d6
	add.w		d6,d6
	move.w		0(a0,d6.w),d4		// Start of this character
	move.w		d4,d1
	sub.w		2(a0,d6.w),d4
	neg.w		d4
	cmp.w		d4,d0
	bls		.last_char		// If not last character (clipping)
	move.w		d4,d0			//  blit full character width
.last_char:
	sub.w		d0,h_w+2(sp)		// Lower free width

	move.l		offset_mods(sp),d6
	beq		.no_offset_mods2
	move.l		d6,a2
	move.w		d3,d4
	add.w		(a2),d4
	addq.l		#4,d6
	move.l		d6,offset_mods(sp)
	bra		.had_offset_mods2
.no_offset_mods2:

	add.w		d3,d4
.had_offset_mods2:
	move.w		d4,dest_x(sp)

	move.l		font_addr(sp),a0

	bsr		draw_char
	bra		.loop

no_clip:
	moveq		#-1,d0
	move.w		font_height(a5),d0
	swap		d0
	swap		d5
	bra		clip_done

no_draw:
	lea		locals(sp),sp

	moveq		#1,d0			// Return as completed
	rts
	

monospace_first:
	move.w		font_widest_cell(a5),d6
	.chip		68060
	divu		d6,d1
	sub.w		d1,d2
	ble		no_draw
	add.w		d1,d1
	add.w		d1,a4
	swap		d1
	bra		first_char


/* In:	a0	font line address
*	a1	screen line address
*	d0	lines to draw, width
*	d1	source x-coordinate
*	d3	destination x-coordinate
*	d5	source wrap, destination wrap
* XXX:	all
*/
draw_char:
	move.w		d1,d2
	and.w		#0x0f,d1			// d1 - bit number in source

	lsr.w		#4,d2
	lsl.w		#1,d2
	add.w		d2,a0			// a0 - start address in source MFDB

	move.w		d3,d4
	and.w		#0x0f,d3			// d3 - first bit number in dest MFDB

	lsr.w		#4,d4
	lsl.w		#1,d4
	add.w		d4,a1			// a1 - start address in dest MFDB

	add.w		d3,d0
	subq.w		#1,d0
	move.w		d0,d2
	move.w		d0,d4

	lsr.w		#4,d4
	lsl.w		#1,d4
	sub.w		d4,d5
	move.w		d5,a3
	swap		d5
	sub.w		d4,d5
	move.w		d5,a2
	swap		d5			// d5 - wrap-blit

	and.w		#0x0f,d2
	addq.w		#1,d2			// d2 - final bit number in dest MFDB

// mreplace
	moveq		#-1,d5			// More can be moved out here!
	lsr.w		d3,d5

	lsr.w		#4,d0
	beq		single
	subq.w		#1,d0			// d0.w - number of 16 pixel blocks to blit

	sub.w		d3,d1			// d1 - shift length
	blt		right

left:
	move.w		d5,d6
	not.w		d6
	moveq		#-1,d3
	lsr.w		d2,d3
	move.w		d3,d4
	not.w		d3
	swap		d3
	move.w		d4,d3

	move.l		d0,d2
	swap		d2
.loop1_l:
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	and.w		d5,d7

	move.w		(a1),d4
	and.w		d6,d4
	or.w		d7,d4
	move.w		d4,(a1)+

	move.w		d0,d4			// Good idea?
	beq		.loop2_l_end
	subq.w		#1,d4
.loop2_l:
	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	move.w		d7,(a1)+
	dbra		d4,.loop2_l
.loop2_l_end:
	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	and.l		d3,d7		// Only top word interesting
	swap		d7

	move.w		(a1),d4
	and.w		d3,d4
	or.w		d7,d4
	move.w		d4,(a1)
	
	add.w		a3,a1
	add.w		a2,a0
	dbra		d2,.loop1_l
	rts


right:
	addq.l		#2,a2
	neg.w		d1

	move.w		d5,d6
	not.w		d6
	moveq		#-1,d3
	lsr.w		d2,d3
	not.w		d3

	move.l		d0,d2
	swap		d2
.loop1_r:
	move.w		(a0),d7
	lsr.w		d1,d7
	and.w		d5,d7

	move.w		(a1),d4
	and.w		d6,d4
	or.w		d7,d4
	move.w		d4,(a1)+

	move.w		d0,d4			// Good idea?
	beq		.loop2_r_end
	subq.w		#1,d4
.loop2_r:
	move.l		(a0),d7
	lsr.l		d1,d7
	move.w		d7,(a1)+
	addq.l		#2,a0
	dbra		d4,.loop2_r
.loop2_r_end:
	move.l		(a0),d7
	lsr.l		d1,d7
	and.w		d3,d7
	not.w		d3		// Not needed before RandorW

	move.w		(a1),d4
	and.w		d3,d4
	or.w		d7,d4
	move.w		d4,(a1)

	not.w		d3
	add.w		a3,a1
	add.w		a2,a0
	dbra		d2,.loop1_r
	rts


single:
	swap		d0
	move.w		#-1,d4
	lsr.w		d2,d4
	not.w		d4
	and.w		d4,d5

	sub.w		d3,d1			// d1 - shift length
	blt		sright

	move.w		d5,d3
	not.w		d5
.loop1_s:
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	and.w		d3,d7

	move.w		(a1),d4
	and.w		d5,d4
	or.w		d7,d4
	move.w		d4,(a1)

	add.w		a3,a1
	add.w		a2,a0
	dbra		d0,.loop1_s
	rts


sright:
	neg.w		d1
	move.w		d5,d3
	not.w		d5
.loop1_sr:
	move.w		(a0),d7
	lsr.w		d1,d7
	and.w		d3,d7

	move.w		(a1),d4
	and.w		d5,d4
	or.w		d7,d4
	move.w		d4,(a1)

	add.w		a3,a1
	add.w		a2,a0
	dbra		d0,.loop1_sr
	rts

/*********
*
* Actual drawing routines
*
*********/

 	.macro	calc_addr dreg,treg
	move.w		(\treg)+,d0
	sub.w		code_low(sp),d0
    .ifne	only_16
	lsl.w		#4,d0
    .endc
    .ifeq	only_16
	mulu		d4,d0
    .endc
	add.w		d0,\dreg
	.endm

/* In:	a1	screen line address
*	a5	font structure address
*	d0	lines to draw, width
*	d1	source x-coordinate
*	d3	destination x-coordinate
*	d5	source wrap, destination wrap
* XXX:	all
*
* In:	d1	Source x-coordinate
*	d2	Source y-coordinate (starting line in font)
*	d3	Destination x-coordinate
*/
display4:

	move.l		font_extra_unpacked_data(a5),a0		// Font line address
	add.w		d2,a0
	move.l		a0,font_addr(sp)
	tst.w		d1
	beq		fast_draw

	swap		d5			// Not nice that I have to do this
	mulu		d5,d2			// Perhaps there is a better way?
	swap		d5
	move.l		font_data(a5),a0
	add.l		d2,a0

	move.w		d1,d2
	sub.w		code_low(sp),d6
	add.w		d6,d6
	move.w		0(a6,d6.w),d4		// Start of this character
	add.w		d4,d1
	sub.w		2(a6,d6.w),d4
	neg.w		d4
	sub.w		d2,d4
	cmp.w		d4,d0
	bls		.last_char1_4		// If not last character (clipping)
	move.w		d4,d0			//  blit full character width
.last_char1_4:
	sub.w		d0,h_w+2(sp)		// Lower free width
	add.w		d3,d4
	move.w		d4,dest_x(sp)

	bsr		draw_char

	subq.w		#1,length(sp)
	addq.l		#2,text_addr(sp)	// Silly way to do it!


fast_draw:
	subq.l		#2,text_addr(sp)
	move.w		dest_x(sp),d1

	move.w		font_widest_cell(a5),d7
	cmp.w		#6,d7
	beq		fast_draw_6

	move.w		length(sp),d7
	and.w		#0xfffc,d7
	beq		.d1_st_loop
	lsr.w		#2,d7
	subq.w		#1,d7
	move.w		d1,d6
.d4_loop:
	move.w		h_w(sp),d4	// Height to draw (not necessarily character height)

	move.w		wraps+2(sp),a6	// Try to move this out of the loop!

	move.l		font_addr(sp),a0
	move.l		text_addr(sp),a1
	move.l		a0,a2
	move.l		a0,a3
	move.l		a0,a5
	calc_addr	a0,a1
	calc_addr	a2,a1
	calc_addr	a3,a1
	calc_addr	a5,a1
	move.l		a1,text_addr(sp)
	
	move.l		screen_addr(sp),a1

	move.w		d6,d1
	bsr		multi_outchar_8

	add.w		#4*8,d6
	dbra		d7,.d4_loop

	move.w		d6,d1
.d1_st_loop:
	move.w		length(sp),d7
	and.w		#0x0003,d7
	beq		.disp4_end
	subq.w		#1,d7
	move.w		wraps+2(sp),a6	// Screen wrap (hopefully)

	move.l		text_addr(sp),a5
	move.l		screen_addr(sp),a2
	move.w		d1,d6
.d1_loop:
	move.w		h_w(sp),d4	// Height to draw (not necessarily character height)
	move.l		font_addr(sp),a0
	calc_addr	a0,a5

	move.l		a2,a1

	move.w		d6,d1
	bsr		outchar_8

	addq.w		#8,d6
	dbra		d7,.d1_loop
	
	move.l		a5,text_addr(sp)
	move.w		d6,d1
.disp4_end:
	lea		locals(sp),sp

	moveq		#1,d0			// Return as completed
	rts


fast_draw_6:
	move.w		length(sp),d7
	and.w		#0xfffc,d7
	beq		.d1_st_loop_fd6
	lsr.w		#2,d7
	subq.w		#1,d7
	move.w		d1,d6
.d4_loop_fd6:
	move.w		h_w(sp),d4	// Height to draw (not necessarily character height)

	move.w		wraps+2(sp),a6	// Try to move this out of the loop!

	move.l		font_addr(sp),a0
	move.l		text_addr(sp),a1
	move.l		a0,a2
	move.l		a0,a3
	move.l		a0,a5
	calc_addr	a0,a1
	calc_addr	a2,a1
	calc_addr	a3,a1
	calc_addr	a5,a1
	move.l		a1,text_addr(sp)
	
	move.l		screen_addr(sp),a1

	move.w		d6,d1
	bsr		multi_outchar_6

	add.w		#4*6,d6
	dbra		d7,.d4_loop_fd6

	move.w		d6,d1
.d1_st_loop_fd6:
	move.w		length(sp),d7
	and.w		#0x0003,d7
	beq		.disp4_end_fd6
	subq.w		#1,d7
	move.w		wraps+2(sp),a6	// Screen wrap (hopefully)

	move.l		text_addr(sp),a5
	move.l		screen_addr(sp),a2
	move.w		d1,d6
.d1_loop_fd6:
	move.w		h_w(sp),d4	// Height to draw (not necessarily character height)
	move.l		font_addr(sp),a0
	calc_addr	a0,a5

	move.l		a2,a1

	move.w		d6,d1
	bsr		outchar_6

	addq.w		#6,d6
	dbra		d7,.d1_loop_fd6
	
	move.l		a5,text_addr(sp)
	move.w		d6,d1
.disp4_end_fd6:
	lea		locals(sp),sp

	moveq		#1,d0			// Return as completed
	rts
	
	
outchar_8:
	move.w		d1,d2		// Calculate column offset
	lsr.w		#4,d2
	add.w		d2,d2
	add.w		d2,a1
	and.w		#0x000f,d1	
	beq		even_align_8	// Character at even word....
	cmp.w		#8,d1
	beq		odd_align_8	// ...even byte
	ble		word_align_8	// ...msb of word
no_align_8:
	move.l		#0x00ffffff,d0	// ...lsb of word
	ror.l		d1,d0
	subq.w		#8,d1
.loop_na8:
	moveq		#0,d2
	move.b		(a0)+,d2
	ror.l		d1,d2
	swap		d2
	move.l		(a1),d3
	and.l		d0,d3
	or.l		d2,d3
	move.l		d3,(a1)
	add.w		a6,a1
	dbra		d4,.loop_na8
	rts

word_align_8:
	move.w		#0x00ff,d0
	ror.w		d1,d0
	moveq		#8,d5
	sub.w		d1,d5
.loop_wa8:
	moveq		#0,d2
	move.b		(a0)+,d2
	lsl.l		d5,d2
	move.w		(a1),d3
	and.w		d0,d3
	or.w		d2,d3
	move.w		d3,(a1)
	add.w		a6,a1
	dbra		d4,.loop_wa8
	rts

odd_align_8:
	addq.l		#1,a1
even_align_8:
.loop_ea8:
	move.b		(a0)+,d2
	move.b		d2,(a1)
	add.w		a6,a1
	dbra		d4,.loop_ea8
	rts


outchar_6:
	move.w		d1,d2		// Calculate column offset
	lsr.w		#4,d2
	add.w		d2,d2
	add.w		d2,a1
	and.w		#0x000f,d1	
	beq		even_align_6	// Character at even word....
	cmp.w		#8,d1
	beq		odd_align_6	// ...even byte
	ble		word_align_6	// ...msb of word
no_align_6:
	move.l		#0x03ffffff,d0	// ...lsb of word
	ror.l		d1,d0
	subq.w		#8,d1
.loop_na6:
	moveq		#0,d2
	move.b		(a0)+,d2
	ror.l		d1,d2
	swap		d2
	move.l		(a1),d3
	and.l		d0,d3
	or.l		d2,d3
	move.l		d3,(a1)
	add.w		a6,a1
	dbra		d4,.loop_na6
	rts

word_align_6:
	move.w		#0x03ff,d0
	ror.w		d1,d0
	moveq		#8,d5
	sub.w		d1,d5
.loop_wa6:
	moveq		#0,d2
	move.b		(a0)+,d2
	lsl.l		d5,d2
	move.w		(a1),d3
	and.w		d0,d3
	or.w		d2,d3
	move.w		d3,(a1)
	add.w		a6,a1
	dbra		d4,.loop_wa6
	rts

odd_align_6:
	addq.l		#1,a1
even_align_6:
	moveq		#0x03,d0
.loop_ea6:
	move.b		(a0)+,d2
	move.b		(a1),d3
	and.b		d0,d3
	or.b		d2,d3
	move.b		d3,(a1)
	add.w		a6,a1
	dbra		d4,.loop_ea6
	rts


multi_outchar_8:
	move.w		d1,d2		// Calculate column offset
	lsr.w		#4,d2
	add.w		d2,d2
	add.w		d2,a1
	and.w		#0x000f,d1	
	beq		m_even_align_8	// Character at even word....
	subq.w		#8,d1
	beq		m_odd_align_8	// ...even byte
	ble		m_msb_8		// ...msb of word
	subq.w		#6,a6
m_lsb8:
	moveq		#8,d5		// Fix these later
	sub.w		d1,d5
.loop_ml8:
	move.w		(a1),d2
	lsl.l		d1,d2
	move.b		(a0)+,d2
	ror.l		d1,d2
	move.w		d2,(a1)+
	move.w		2(a1),d2
	rol.l		d1,d2
	swap		d2
	move.b		(a3)+,d2
	lsl.l		#8,d2
	move.b		(a5)+,d2
	swap		d2
	move.b		(a2)+,d2
	swap		d2
	rol.l		d5,d2
	move.l		d2,(a1)+
	add.w		a6,a1
	dbra		d4,.loop_ml8
	rts
	
m_even_align_8:			// Characters word aligned
	subq.l		#4,a6
.loop_mea8:			// 8 pixels wide characters
	move.b		(a0)+,d2
	lsl.w		#8,d2
	move.b		(a2)+,d2
	move.w		d2,(a1)+
	move.b		(a3)+,d2
	lsl.w		#8,d2
	move.b		(a5)+,d2
	move.w		d2,(a1)+
	add.w		a6,a1
	dbra		d4,.loop_mea8
	rts

m_odd_align_8:			// Characters byte aligned (not word)
	subq.l		#4,a6
	addq.l		#1,a1
.loop_moa8:			// 8 pixels wide characters
	move.b		(a0)+,d2
	move.b		d2,(a1)+
	move.b		(a2)+,d2
	lsl.w		#8,d2
	move.b		(a3)+,d2
	move.w		d2,(a1)+
	move.b		(a5)+,d2
	move.b		d2,(a1)+
	add.w		a6,a1
	dbra		d4,.loop_moa8
	rts

m_msb_8:
	neg.w		d1
	subq.w		#6,a6
	moveq		#8,d5
	sub.w		d1,d5	
.loop_mm8:			// 8 pixels wide characters
	move.w		(a1),d2
	lsr.w		d1,d2
	move.b		(a0)+,d2
	swap		d2
	move.b		(a2)+,d2
	lsl.w		#8,d2
	move.b		(a3)+,d2
	lsl.l		d1,d2
	swap		d2
	move.w		d2,(a1)+
	move.w		2(a1),d2
	swap		d2
	lsl.l		d5,d2
	move.b		(a5)+,d2
	ror.l		d5,d2
	swap		d2
	move.l		d2,(a1)+
	add.w		a6,a1
	dbra		d4,.loop_mm8
	rts


multi_outchar_6:
	move.w		d1,d2		// Calculate column offset
	lsr.w		#4,d2
	add.w		d2,d2
	add.w		d2,a1
	and.w		#0x000f,d1	
	beq		m_even_align_6	// Character at even word....
	subq.w		#8,d1
	beq		m_odd_align_6	// ...even byte
	ble		m_msb_6		// ...msb of word
	subq.w		#6,a6
	move.w		d1,d3
	addq.w		#2,d3
	moveq		#4,d5
	moveq		#0x03,d0
	sub.w		d1,d5
	beq		m_lsb64
	ble		m_lsb6h
m_lsb6l:
.loop_ml6l:
	move.w		(a1),d2
	lsl.l		d1,d2
	move.b		(a0)+,d2
	lsl.l		#6,d2
	move.b		(a2)+,d2
	lsl.l		#6,d2
	move.b		(a3)+,d2
	lsl.l		d5,d2
	swap		d2
	move.w		d2,(a1)+
	move.w		2(a1),d2
	rol.l		d3,d2
	swap		d2
	and.b		d0,d2
	or.b		(a5)+,d2
	swap		d2
	ror.l		d3,d2
	move.l		d2,(a1)+
	add.w		a6,a1
	dbra		d4,.loop_ml6l
	rts

m_lsb64:
.loop_ml64:
	move.w		(a1),d2
	lsl.l		#4,d2
	move.b		(a0)+,d2
	lsl.l		#6,d2
	move.b		(a2)+,d2
	lsl.l		#6,d2
	move.b		(a3)+,d2
	swap		d2
	move.w		d2,(a1)+
	move.w		2(a1),d2
	rol.l		#6,d2
	swap		d2
	and.b		d0,d2
	or.b		(a5)+,d2
	swap		d2
	ror.l		#6,d2
	move.l		d2,(a1)+
	add.w		a6,a1
	dbra		d4,.loop_ml64
	rts

m_lsb6h:

	addq.w		#6,d5
	subq.w		#6,d3
.loop_ml6h:
	move.w		(a1),d2
	lsl.l		d1,d2
	move.b		(a0)+,d2
	lsl.l		#6,d2
	move.b		(a2)+,d2
	lsl.l		d5,d2
	swap		d2
	move.w		d2,(a1)+
	move.w		2(a1),d2
	rol.l		d3,d2
	swap		d2
	move.b		(a3)+,d2
	rol.l		#6,d2
	and.b		d0,d2
	or.b		(a5)+,d2
	rol.l		#4,d2
	rol.l		d5,d2
	move.l		d2,(a1)+
	add.w		a6,a1
	dbra		d4,.loop_ml6h
	rts

m_even_align_6:			// 6 pixels wide characters
.loop_mea6:
	move.b		(a0)+,d2
	lsl.w		#6,d2
	or.b		(a2)+,d2
	lsl.l		#6,d2
	or.b		(a3)+,d2
	lsl.l		#6,d2
	or.b		(a5)+,d2
	lsl.l		#6,d2
	move.b		3(a1),d2
	move.l		d2,(a1)
	add.w		a6,a1
	dbra		d4,.loop_mea6
	rts
	
m_odd_align_6:			// 6 pixels wide characters
.loop_moa6:
	move.w		(a1),d2
	move.b		(a0)+,d2
	lsl.l		#6,d2
	or.b		(a2)+,d2
	lsl.l		#6,d2
	or.b		(a3)+,d2
	lsl.l		#4,d2		// These two lines should be better
	rol.l		#2,d2
	or.b		(a5)+,d2
	ror.l		#2,d2
	move.l		d2,(a1)
	add.w		a6,a1
	dbra		d4,.loop_moa6
	rts
	
m_msb_6:				// Characters start in msb byte
	neg.w		d1		// Correct ?
.loop_mm6:				// 6 pixels wide characters
	move.l		(a1),d2
	ror.l		d1,d2
	clr.w		d2
	swap		d2
	move.b		(a0)+,d2
	lsl.l		#6,d2
	or.b		(a2)+,d2
	lsl.l		#6,d2
	or.b		(a3)+,d2
	rol.l		#6,d2
	or.b		(a5)+,d2
	ror.l		#2,d2
	rol.l		d1,d2
	move.l		d2,(a1)
	add.w		a6,a1
	dbra		d4,.loop_mm6
	rts


	.ifne	0
* ---
* Totally aligned 8 pixel output
* ---
display_byte:
	move.l		screen_addr(sp),a1

	move.w		d1,d2		// Calculate column offset
	lsr.w		#3,d2
	add.w		d2,a1
	move.l		a1,d6
	move.w		d7,d5
	and.w		#0xfffc,d5
	beq		db1_st_loop
	lsr.w		#2,d5
	subq.w		#1,d5
	subq.w		#4,a6
db4_loop:
	move.w		h_w(sp),d4	// Height to draw (not necessarily character height)

	move.l		font_addr(sp),a0
	move.l		text_addr(sp),a1
	move.l		a0,a2
	move.l		a0,a3
	move.l		a0,a5
	calc_addr	a0,a1
	calc_addr	a2,a1
	calc_addr	a3,a1
	calc_addr	a5,a1
	move.l		a1,text_addr(sp)
	
	subq.w		#1,d4
	move.l		d6,a1
	addq.l		#4,d6
db_out_loop:			// 8 pixels wide characters
	move.b		(a0)+,(a1)+
	move.b		(a2)+,(a1)+
	move.b		(a3)+,(a1)+
	move.b		(a5)+,(a1)+
	add.w		a6,a1
	dbra		d4,db_out_loop
	dbra		d5,db4_loop
	addq.w		#4,a6
	
db1_st_loop:
	and.w		#0x0003,d7
	beq		dispb_end
	subq.w		#1,d7
	move.l		text_addr(sp),a5
db1_loop:
	move.w		h_w(sp),d4	// Height to draw (not necessarily character height)

	move.l		font_addr(sp),a0

	calc_addr	a0,a5
	subq.w		#1,d4

	move.l		d6,a1
	addq.l		#1,d6
db1_out_loop:
	move.b		(a0)+,(a1)
	add.w		a6,a1
	dbra		d4,db1_out_loop
	dbra		d7,db1_loop
	move.l		a5,text_addr(sp)	
dispb_end:
	addq.l		#4,sp
	rts
	.endc
