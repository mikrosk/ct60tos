/*
	Hardware registers test

	Copyright (C) 2003	Patrice Mandin

	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Lesser General Public License for more details.

	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
*/

/*
	Main detection code taken from Linux kernel
*/

	.text

	.globl	_HW_RegDetect

/*--- Defines ---*/

#define BUSERROR_VECTOR	2<<2

/*--- Detection ---*/

_HW_RegDetect:
	movel	sp@(4),d0	| cookie_cpu

	/* Check VBR ? */
	moveq	#0,d1

	cmp	#10,d0
	bmis	novbr
	.chip	68010
	movec	vbr,d1
	.chip	68000
novbr:
	movel	d1,current_vbr

	/* Save stack pointer */
	movel	sp,a1

	/* Save current vectors, and redirect it to end of routine */
	movel	current_vbr,a0
	movel	a0@(BUSERROR_VECTOR),save_vector0
	movel	#RegDetectEnd,a0@(BUSERROR_VECTOR)

	nop

	/* Check HW presence */
	movel	sp@(8),a0	| hardware address to check

	moveq	#0,d0		| No hardware present
	tstb	a0@		| Read access

	nop
	moveq	#1,d0		| No bus error: HW present

RegDetectEnd:
	movel	current_vbr,a0
	movel	save_vector0,a0@(BUSERROR_VECTOR)
	movel	a1,sp

	nop
	rts

/*--- Variables ---*/

	.data
	.even
	.comm	save_vector0,4	| Bus error instruction
	.comm	current_vbr,4
