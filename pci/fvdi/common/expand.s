*-------------------------------------------------------*
*	Mono->mono (MFDB) operations			*
*	Uses almost exactly the same code as		*
*	the monochrome driver (see 'outside' notes)	*
*							*
*	This file currently can't be assembled by	*
*	Lattice C, since it includes files that use	*
*	DevPac type local lables.			*
*-------------------------------------------------------*
*
* Copyright 1997-2000, Johan Klockars 
* This software is licensed under the GNU General Public License.
* Please, see LICENSE.TXT for further information.
*****

both		set	0	; Not applicable outside driver
longs		equ	1
get		equ	1
mul		equ	1	; Multiply rather than use table
shift		equ	1

	include		"vdi.inc"
	include		"pixelmac.inc"

	xdef		expand_area,_expand_area

	xdef		mode_table

	xdef		mreplace,replace	; temporary

	xref		get_colour

  ifeq shift
	xref		dot,lline,rline
  endc
  ifeq mul
	xref		row
  endc


	text

* In:	a1	VDI struct, destination MFDB, VDI struct, source MFDB
*	d0	height and width to move (high and low word)
*	d1-d2	source coordinates
*	d3-d4	destination coordinates
*	d6	background and foreground colour
*	d7	logic operation
_expand_area:
expand_area:
  ifne 0
	exg		d0,d6
	bsr		get_colour
	exg		d0,d6
  else
	neg.w		d6			; Appropriate outside driver
	swap		d6
	neg.w		d6
	swap		d6
;	not.l		d6
  endc
	move.l		d6,-(a7)		; Colours to stack
	lsl.w		#3,d7
	lea		mode_table,a0
;	pea		(a0,d7.w)		; Pointer to address of correct output routine on stack
	lea		(a0,d7.w),a6

	move.l		12(a1),a0		; source MFDB calculations
	move.w		mfdb_wdwidth(a0),d5
	move.w		mfdb_bitplanes(a0),d7
	move.l		mfdb_address(a0),a0

	add.w		d5,d5
	mulu.w		d5,d7
	mulu.w		d2,d7
	add.l		d7,a0
	swap		d5			; d5 - source wrap (high word)

	move.w		d1,d2
	and.w		#$0f,d1			; d1 - bit number in source

	lsr.w		#4,d2
	lsl.w		#1,d2
	add.w		d2,a0			; a0 - start address in source MFDB
	move.l		a0,d2			; d2 copies a0, but is then scratch

	sub.l		#$10000,d0		; Height only used via dbra

	move.l		4(a1),d6		; destination MFDB calculations
	beq		normal

	move.l		d6,a0
	move.l		mfdb_address(a0),d6
	beq		normal
	move.w		mfdb_wdwidth(a0),d5
	move.w		mfdb_bitplanes(a0),d7
	move.l		(a1),a1
	move.l		vwk_real_address(a1),a1
	move.l		wk_screen_mfdb_address(a1),a0
	cmp.l		a0,d6
	beq		xnormal

	move.l		d6,a1
	add.w		d5,d5			; d5 - wraps (source dest)
	mulu.w		d5,d7
	mulu.w		d7,d4			; Was d4,d7  (980211)
	add.l		d4,a1

no_shadow:
	move.w		d3,d4
	and.w		#$0f,d3			; d3 - first bit number in dest MFDB

	lsr.w		#4,d4
	lsl.w		#1,d4
	add.w		d4,a1			; a1 - start address in dest MFDB
						; d4 scratch
	move.l		d2,a0

	add.w		d3,d0
	subq.w		#1,d0
	move.w		d0,d2
	move.w		d0,d4

	lsr.w		#4,d4
	lsl.w		#1,d4
	swap		d5
	sub.w		d4,d5
	move.w		d5,a2
	swap		d5

	sub.w		d4,d5			; d5 - wrap-blit
	move.w		d5,a3
;	swap		d5
;	sub.w		d4,d5
;	move.w		d5,a2
;	swap		d5			; d5 - wrap-blit

	and.w		#$0f,d2
	addq.w		#1,d2			; d2 - final bit number in dest MFDB

;	move.l		a0,d7
;	move.l		(a7)+,a0
;	move.l		4(a0),-(a7)
;	move.l		d7,a0
;	rts					; Call correct routine
	move.l		(a7)+,d7

	move.l		4(a6),a6
	jmp		(a6)

normal:
	move.l		(a1),a1
	move.l		vwk_real_address(a1),a1

	ifne	mul
	move.l		wk_screen_mfdb_address(a1),a0
	endc

xnormal:
	ifne	mul
	move.w		wk_screen_wrap(a1),d5	; d5 - wraps (source dest)
	mulu.w		d5,d4
	add.l		d4,a0
;	 ifne	both
;	move.l		wk_screen_shadow_address(a1),a4
;	add.l		d4,a4
;	 endc
	endc
	ifeq	mul
	lea		row(pc),a0
	move.l		(a0,d4.w*4),a0
	endc

	exg		a0,a1			; Workstation used below

	ifne	both
;	move.l		wk_screen_shadow_address(a0),a4
	move.l		wk_screen_shadow_address(a0),d7
	beq		no_shadow
	move.l		d7,a4
	add.l		d4,a4
	endc

	move.w		d3,d4
	and.w		#$0f,d3			; d3 - first bit number in dest MFDB

	lsr.w		#4,d4
	lsl.w		#1,d4
	add.w		d4,a1			; a1 - start address in dest MFDB
	ifne	both
	add.w		d4,a4			; a4 - start address in shadow
	endc					; d4 scratch

	move.l		d2,a0

	add.w		d3,d0
	subq.w		#1,d0
	move.w		d0,d2
	move.w		d0,d4

	lsr.w		#4,d4
	lsl.w		#1,d4
	swap		d5
	sub.w		d4,d5
	move.w		d5,a2
	swap		d5

	sub.w		d4,d5			; d5 - wrap-blit
	move.w		d5,a3
;	swap		d5
;	sub.w		d4,d5
;	move.w		d5,a2
;	swap		d5			; d5 - wrap-blit

	and.w		#$0f,d2
	addq.w		#1,d2			; d2 - final bit number in dest MFDB

;	move.l		a0,d7
;	move.l		(a7)+,a0
;	move.l		(a0),-(a7)
;	move.l		d7,a0
;	rts					; Call correct routine
	move.l		(a7)+,d7

	move.l		(a6),a6
	jmp		(a6)

mreplace:
	lsr.w		#4,d0
	beq		mfdb_single
	subq.w		#1,d0			; d0.w - number of 16 pixel blocks to blit

	sub.w		d3,d1			; d1 - shift length
	blt		mfdb_right

	bra		mfdb_left

mtransparent:
	lsr.w		#4,d0
	beq		mfdb_single_transp
	subq.w		#1,d0			; d0.w - number of 16 pixel blocks to blit

	sub.w		d3,d1			; d1 - shift length
	blt		mfdb_right_transp

	bra		mfdb_left_transp

mxor:
	lsr.w		#4,d0
	beq		mfdb_single_xor
	subq.w		#1,d0			; d0.w - number of 16 pixel blocks to blit

	sub.w		d3,d1			; d1 - shift length
	blt		mfdb_right_xor

	bra		mfdb_left_xor

mrevtransp:
	lsr.w		#4,d0
	beq		mfdb_single_revtransp
	subq.w		#1,d0			; d0.w - number of 16 pixel blocks to blit

	sub.w		d3,d1			; d1 - shift length
	blt		mfdb_right_revtransp

	bra		mfdb_left_revtransp

	ifne	both
replace:
	lsr.w		#4,d0
	beq		shadow_single
	subq.w		#1,d0			; d0.w - number of 16 pixel blocks to blit

	sub.w		d3,d1			; d1 - shift length
	blt		shadow_right

	bra		shadow_left

transparent:
	lsr.w		#4,d0
	beq		shadow_single_transp
	subq.w		#1,d0			; d0.w - number of 16 pixel blocks to blit

	sub.w		d3,d1			; d1 - shift length
	blt		shadow_right_transp

	bra		shadow_left_transp

xor:
	lsr.w		#4,d0
	beq		shadow_single_xor
	subq.w		#1,d0			; d0.w - number of 16 pixel blocks to blit

	sub.w		d3,d1			; d1 - shift length
	blt		shadow_right_xor

	bra		shadow_left_xor

revtransp:
	lsr.w		#4,d0
	beq		shadow_single_revtransp
	subq.w		#1,d0			; d0.w - number of 16 pixel blocks to blit

	sub.w		d3,d1			; d1 - shift length
	blt		shadow_right_revtransp

	bra		shadow_left_revtransp
	endc
  ifeq both
replace:					; Dummy routines
transparent:
xor:
revtransp:
	rts
  endc

**********
*
* Import the actual drawing routines
*
**********

; Standard mode
shadow	set	0
oldboth	set	both
both	set	0
	include		"1_expand.inc"

; Shadow mode, if asked for
both	set	oldboth
  ifne both
shadow	set	1
	include		"1_expand.inc"
  endc


	data

mode_table:
	dc.l		0,0,replace,mreplace,transparent,mtransparent
	dc.l		xor,mxor,revtransp,mrevtransp

	end
