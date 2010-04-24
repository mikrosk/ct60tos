#include "config.h"
#include "vdi.inc"
#include "types.inc"

	.xref	_me

	.xdef	mouse_draw,_mouse_draw
	.xdef	_mouse_pos


	.text

#ifdef TEST_NOPCI
/*	d0.w	x
*	d1.w	y
*	d2	0 - move shown  1 - move hidden  2 - hide  3 - show  >7 - change shape (pointer to mouse struct)
*/
_mouse_draw:
mouse_draw:
	sub.w	hotspot_x,d0
	bpl	.x_positive
	move.w	#0,d0
.x_positive:
	sub.w	hotspot_y,d1
	bpl	.y_positive
	moveq	#0,d1
.y_positive:
	swap	d1
	move.w	d0,d1
	move.l	d1,_mouse_pos
	
//	tas	here_already
//	bne	.in_use

	swap	d0

	cmp.l	#8,d2
	bcs	.skip_shape_setup
//	bcc	.shape_setup
//	btst	#4,d0
//	beq	.skip_shape_setup
//	move.l	shape_data,d2
//.shape_setup:
	move.l	d2,a0				// Points to mouse structure
	move.l	mouse_hotspot(a0),hotspot_x	// Both coordinates

	lea	mouse_data(a0),a1
	move.l	a1,cursor
	lea	mouse_mask(a0),a1
	move.l	a1,mask
	move.l	mouse_colour(a0),d0
	move.l	_me,a0
	move.l	driver_default_vwk(a0),a0
	move.l	vwk_real_address(a0),a1
	move.l	wk_r_get_colour(a1),a1 // Index to real colour
	jsr	(a1)		
	move.l	d0,colour
	bra	.finish
.skip_shape_setup:

	cmp.w	#0,d2		// move shown
	beq	.move
	cmp.w	#1,d2		// mode hidden
	beq	.finish
	cmp.w	#2,d2		// hide
	beq	.restore
	cmp.w	#3,d2		// show 
	beq	.draw
	cmp.w	#4,d2		// Check for forced moves
	beq	.move
	cmp.w	#5,d2
	beq	.finish
.restore:
	bsr	restore_mouse
	bra	.finish
.move:
	bsr	restore_mouse
.draw:
	bsr	draw_cursor

.finish:
	moveq	#0,d0
//	clr.b	here_already
.end:
	rts

//.in_use:
//	cmp.l	#7,d2
//	bhi	.wanted_shape
//	bset	d0,d2
//	or.l	#0xffff0000,d0
//	bra	.end

//.wanted_shape:
//	or.l	#0xffff0010,d0
//	move.l	d2,shape_data
//	bra	.end



/* Restore old mouse background */
restore_mouse:
	movem.l	d3-d7/a2-a4,-(a7)
	move.l	back_pos,d1
	moveq	#0,d0
	move.w	d1,d0
	swap	d1
	lea	back_buffer,a0	
	move.l	_me,a1
	move.l	driver_default_vwk(a1),a1
	move.l	vwk_real_address(a1),a1
	move.l	back_address,a3
	move.w	d0,d7
	move.w	wk_screen_mfdb_height(a1),d5
	sub.w	d1,d5
	cmp.w	#16,d5
	bls	.at_bottom_hide
	moveq	#16,d5
.at_bottom_hide:
	subq.w	#1,d5
.rows_hide:
	moveq	#15,d6
	move.w	d7,d1
	move.l	a3,a4
.cols_hide:
//	cmp.w	wk_screen_coordinates_min_x(a1),d1
//	blt	.next
	cmp.w	wk_screen_coordinates_max_x(a1),d1
	bgt	.next
//	cmp.w	wk_screen_coordinates_min_y(a1),d2
//	blt	.next
//	cmp.w	wk_screen_coordinates_max_y(a1),d2
//	bgt	.next
	move.w	(a0)+,(a4)+
.next:
	addq.w	#1,d1
	dbra	d6,.cols_hide
	add.w	wk_screen_wrap(a1),a3
	addq.w	#1,d2
	dbra	d5,.rows_hide
	movem.l	(a7)+,d3-d7/a2-a4
	rts

/* This routine both draws a new cursor and
* moves the background to the backbuffer
*
* In:	d0.w	cursor x-pos
*	d1.w	cursor y-pos
*
* Set d5 to lineoffset
* d6 is a mask used to mask off the cursor on the right side 
*    it is 1 where the cursor should be seen
*/
draw_cursor:
	movem.l	d3-d7/a2-a5,-(a7)
	move.l	_mouse_pos,d1
	move.l	d1,back_pos
	moveq	#0,d0
	move.w	d1,d0
	swap	d1
	move.l	_me,a1
	move.l	driver_default_vwk(a1),a1
	move.l	vwk_real_address(a1),a1
	lea	back_buffer,a0
	move.l	mask,a2
	move.l	cursor,a5	
	move.l	wk_screen_mfdb_address(a1),a3
	move.w	d1,d2
	mulu	wk_screen_wrap(a1),d2
	add.l	d2,a3
	add.l	d0,a3
	add.l	d0,a3
	move.w	wk_screen_mfdb_height(a1),d5
	sub.w	d1,d5
	cmp.w	#16,d5
	bls	.at_bottom
	moveq	#16,d5
.at_bottom:
	subq.w	#1,d5
	move.w	d0,d7
	move.w	d1,d2
	move.l	a3,back_address
	move.l	colour,d0
.rows_show:
	moveq	#15,d6
	move.w	(a2)+,d3
	move.w	(a5)+,d4
	move.w	d7,d1
	move.l	a3,a4
.cols_show:
//	cmp.w	wk_screen_coordinates_min_x(a1),d1
//	blt	.plotted
	cmp.w	wk_screen_coordinates_max_x(a1),d1
	bgt	.plotted
//	cmp.w	wk_screen_coordinates_min_y(a1),d2
//	blt	.plotted
//	cmp.w	wk_screen_coordinates_max_y(a1),d2
//	bgt	.plotted
	move.w	(a4),(a0)+		// Save old data
	add.w	d3,d3		//  and then write new
	bcc	.no_pixel
	add.w	d4,d4
	bcc	.background
	move.w       d0,(a4)
	bra	.plotted
.background:
	swap	d0
	move.w       d0,(a4)
	swap	d0
.plotted:
	lsr.w	#1,d4		// Shift back again
.no_pixel:
	addq.w	#2,a4
	add.w	d4,d4		//  to make this possible
	addq.w	#1,d1
	dbra	d6,.cols_show
	add.w	wk_screen_wrap(a1),a3
	addq.w	#1,d2
	dbra	d5,.rows_show
	movem.l	(a7)+,d3-d7/a2-a5
	rts

	.lcomm hotspot_x,2
	.lcomm hotspot_y,2
	.lcomm mask,4
	.lcomm cursor,4
	.lcomm colour,4
//	.lcomm here_already,2
	.lcomm _mouse_pos,4
	.lcomm back_pos,4
//	.lcomm shape_data,4
	.lcomm back_address,4 	// Address at which to replace background
	.lcomm back_buffer,16*16*2	// Maximal backbuffer needed for mouse
				// 2*8*16 words are needed for 8 bpp modes
				// 16*16, words for 16 bpps modes

#endif
