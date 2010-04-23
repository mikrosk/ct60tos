/* TOS 4.04 Videl patch for the CT60 board
*  Didier Mequignon 2003-2006, e-mail: aniplay@wanadoo.fr
*
*  This library is free software; you can redistribute it and/or
*  modify it under the terms of the GNU Lesser General Public
*  License as published by the Free Software Foundation; either
*  version 2.1 of the License, or (at your option) any later version.
*
*  This library is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
*  Lesser General Public License for more details.
*
*  You should have received a copy of the GNU Lesser General Public
*  License along with this library; if not, write to the Free Software
*  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

	.text
	
#include "vars.h"

	.globl	picture_boot

	.align	2
	.long	0x57E
	.long	end1-begin1+0x80000000
begin1:
	jsr	picture_boot
end1:

#ifdef COLDFIRE

	.align	2
	.long	0xCB0
	.long	end2-begin2
begin2:	// VBL without palette and new screen
	addq.l	#1,_frclock
	tst.w	vblsem
	bgt.s	.vbl_ok
	rte
.vbl_ok:
	lea	-60(SP),SP
	movem.l	D0-D7/A0-A6,(SP)
	addq.l	#1,_vbclock
	clr.l	colorptr
	moveq	#0,D7
	move.w	nvbls,D7
	beq.s	begin2-0xCB0+0xD1C
	subq.l	#1,D7
	move.l	_vblqueue,A0
.loop_vbl:
	move.l	(A0)+,A1
	move.l	A1,D0
	beq.s	.no_vbl
	move.l	D7,-(SP)
	move.l	A0,-(SP)
	jsr	(A1)
	move.l	(SP)+,A0
	move.l	(SP)+,D7
.no_vbl:
	subq.l	#1,D7
	bpl.s	.loop_vbl
	bra.s	begin2-0xCB0+0xD16 // blink cursor BIOS
end2:

	.align	2
	.long	0xD1C // just after blink JSR
	.long	end3-begin3
begin3:	// VBL without palette and new screen (end)
	tst.w	_dumpflg
	bne.s	.no_dump
	move.l	dump_vec,A0
	jsr	(A0)
	moveq	#-1,D0
	move.w	D0,_dumpflg
.no_dump:
	movem.l	(SP),D0-D7/A0-A6
	lea	60(SP),SP
	rte
end3:

#endif

