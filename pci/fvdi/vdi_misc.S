/****
* fVDI miscellaneous functions
*
* Copyright 1997-2000, Johan Klockars 
* This software is licensed under the GNU General Public License.
* Please, see LICENSE.TXT for further information.
****/

#define always_clip_r	1		// Always clip rectangles?
#define always_clip_l	0		// Always clip lines?

#include	"vdi.inc"
#include	"macros.inc"

	.xdef	clip_rect,setup_blit,setup_plot


	.text

/* clip_rect - Internal function
*
* Clips coordinates according to currect clip settings
* Todo: Always clip against screen area?
* In:   d1,d2   x1,y1
*       d3,d4   x2,y2
* Out:  d1,d2   clipped x1,y1
*       d3,d4   clipped x2,y2
*       flags   set for BLO if no area left
*/
clip_rect:
  .ifeq always_clip_r
	tst.w	vwk_clip_on(a0)
	beq	.no_clip
  .endc
.do_clip:
	cmp.w	vwk_clip_rectangle_x1(a0),d1	// left
	bge	.left_ok
	move.w	vwk_clip_rectangle_x1(a0),d1
.left_ok:
	cmp.w	vwk_clip_rectangle_y1(a0),d2	// top
	bge	.top_ok
	move.w	vwk_clip_rectangle_y1(a0),d2
.top_ok:
	cmp.w	vwk_clip_rectangle_x2(a0),d3	// right
	ble	.right_ok
	move.w	vwk_clip_rectangle_x2(a0),d3
.right_ok:
	cmp.w	vwk_clip_rectangle_y2(a0),d4	// bottom
	ble	.bottom_ok
	move.w	vwk_clip_rectangle_y2(a0),d4
.bottom_ok:
	cmp.w	d1,d3
	blt	.end
	cmp.w	d2,d4
	blt	.end
.end:
	rts
.no_clip:
	rts


/* setup_blit - Internal function
*
* Sets up pointers to pixel blit functions
* In:	a0	VDI struct
*	4(a7)	drawing mode
* Out:	a1	blit function
*	a3	set pixel function
*	a4	get pixel function
*/
setup_blit:
	move.l	vwk_real_address(a0),a1
	move.l	wk_r_set_pixel(a1),a3
	move.l	wk_r_get_pixel(a1),a4
	lea	blit_routines,a1
	add.w	4(a7),a1
	add.w	4(a7),a1
	add.w	4(a7),a1
	add.w	4(a7),a1
	move.l	(a1),a1
	rts

/* blit_0 - Internal function
*
* D1 = 0 (clear destination block)
* In:	a0	-> VDI struct, destination MFDB, VDI struct, source MFDB
*	d1	Source x (high), destination x (low)
*	d2	Source y (high), destination y (low)
*	a3	set pixel function
*	a4	get pixel function
*/
blit_0:
	moveq	#0,d0
	jsr	(a3)
	rts

/* blit_1 - Internal function
*
* D1 = S and D
*/
blit_1:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	jsr	(a4)
	and.w	d7,d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_2 - Internal function
*
* D1 = S and (not D)
*/
blit_2:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	jsr	(a4)
	not.w	d0
	and.w	d7,d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_3 - Internal function
*
* D1 = S (replace mode)
*/
blit_3:
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	jsr	(a3)
	rts

/* blit_4 - Internal function
*
* D1 = (not S) and D (erase mode)
*/
blit_4:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	not.w	d7
	jsr	(a4)
	and.w	d7,d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_5 - Internal function
*
* D1 = D (no operation)
*/
blit_5:
	rts

/* blit_6 - Internal function
*
* D1 = S xor D (XOR mode)
*/
blit_6:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	jsr	(a4)
	eor.w	d7,d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_7 - Internal function
*
* D1 = S or D (transparent mode)
*/
blit_7:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	jsr	(a4)
	or.w	d7,d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_8 - Internal function
*
* D1 = not (S or D)
*/
blit_8:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	jsr	(a4)
	or.w	d7,d0
	not.w	d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_9 - Internal function
*
* D1 = not (S xor D)
*/
blit_9:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	jsr	(a4)
	eor.w	d7,d0
	not.w	d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_a - Internal function
*
* D1 = not D
*/
blit_a:
	jsr	(a4)
	not.w	d0
	jsr	(a3)
	rts	

/* blit_b - Internal function
*
* D1 = S or (not D)
*/
blit_b:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	jsr	(a4)
	not.w	d0
	or.w	d7,d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_c - Internal function
*
* D1 = not S
*/
blit_c:
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	not.w	d0
	jsr	(a3)
	rts

/* blit_d - Internal function
*
* D1 = (not S) or D (reverse transparent mode)
*/
blit_d:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	not.w	d7
	jsr	(a4)
	or.w	d7,d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_e - Internal function
*
* D1 = not (S and D)
*/
blit_e:
	move.l	d7,-(a7)
	swap	d1
	swap	d2
	addq.l	#8,a0
	jsr	(a4)
	subq.l	#8,a0
	swap	d1
	swap	d2
	move.w	d0,d7
	jsr	(a4)
	and.w	d7,d0
	not.w	d0
	jsr	(a3)
	move.l	(a7)+,d7
	rts	

/* blit_f - Internal function
*
* D1 = 1 (fill destination block)
*/
blit_f:
	moveq	#-1,d0
	jsr	(a3)
	rts
 

/* setup_plot - Internal function
*
* Sets up pointers to pixel draw functions
* In:	a0	VDI struct
*	4(a7)	drawing mode
* Out:	a1	draw function
*	a3	set pixel function
*	a4	get pixel function
*/
setup_plot:
	move.l	vwk_real_address(a0),a1
	move.l	wk_r_set_pixel(a1),a3
	move.l	wk_r_get_pixel(a1),a4
	lea	mode_routines,a1
	add.w	4(a7),a1
	add.w	4(a7),a1
	add.w	4(a7),a1
	add.w	4(a7),a1
	move.l	-4(a1),a1
	rts

/* p_replace - Internal function
*
* Draws in replace mode
* In:	a0	-> VDI struct, destination MFDB
*	d0	background.w and foreground.w colour
*	d1	x
*	d2	y
*	a3	set pixel function
*	a4	get pixel function
*	carry	current mask bit
*/
p_replace:
	bcc	.background
	jsr	(a3)
	rts
.background:
	swap	d0
	jsr	(a3)
	swap	d0
	rts

/*  - Internal function
*
* Draws in transparent mode
*/
p_transp:
	bcc	.nothing
	jsr	(a3)
.nothing:
	rts

/* p_xor - Internal function
*
* Draws in xor mode
* I don't think this does the right thing!
*/
p_xor:
	lbcc	.nothing1
	move.l	d0,-(a7)
	jsr	(a4)
	not.w	d0		// Is this right instead perhaps?
	jsr	(a3)
	move.l	(a7)+,d0
.nothing1:
	rts

/* p_revtransp - Internal function
*
* Draws in reverse transparent mode
*/
p_revtransp:
	lbcs	.nothing_1
	jsr	(a3)
.nothing_1:
	rts

	.data

mode_routines:
	dc.l	p_replace,p_transp,p_xor,p_revtransp

blit_routines:
	dc.l	blit_0,blit_1,blit_2,blit_3,blit_4,blit_5,blit_6,blit_7
	dc.l	blit_8,blit_9,blit_a,blit_b,blit_c,blit_d,blit_e,blit_f

