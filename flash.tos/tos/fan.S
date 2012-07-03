/* CT60 Speed FAN on IO3 MFP
 *
 * Didier Mequignon 2001-2010, e-mail: aniplay@wanadoo.fr
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

#include "vars.h"

#ifndef COLDFIRE

	.globl init_speed_fan

init_speed_fan:

	movem.l D0-D2/A0-A2,-(SP)
	move.l phystop,A0
	clr.w count_io3_mfp(A0)
	move.l _hz_200,start_hz_200(A0)
	pea inter_io3_mfp(PC)
	move.w #67,-(SP)         // IO3 MFP
	move.w #5,-(SP)          // Setexec
	trap #13
	addq.l #8,SP
	move.w #3,-(SP)          // IO3 MFP
	move.w #27,-(SP)         // Jenabint
	trap #14
	addq.l #4,SP
	move.l _hz_200,D0
	add.l #100,D0            // tempo 0.5 S
.tempo_test_fan:
		move.l _hz_200,D1
		cmp.l D0,D1
	blt.s .tempo_test_fan
	move.l phystop,A0
	cmp.w #5,count_io3_mfp(A0)
	bcc.s .no_int
	move.w #3,-(SP)          // IO3 MFP
	move.w #26,-(SP)         // Jdisint
	trap #14
	addq.l #4,SP
.no_int:	
	movem.l (SP)+,D0-D2/A0-A2
	rts

	dc.l 0x58425241          // XBRA
	dc.l 0x43543630          // CT60
	dc.l 0
	
inter_io3_mfp:

	movem.l D0/A0,-(SP)
	move.l phystop,A0
	addq.w #1,count_io3_mfp(A0)
	move.l _hz_200,D0
	sub.l start_hz_200(A0),D0
	cmp.l #1000,D0           // 5 S
	bcs.s .end_inter
	move.l _hz_200,start_hz_200(A0)
	move.l cookie,D0
	beq.s .end_inter
	move.l D0,A0
.loop_cookie_inter:
		tst.l (A0)
		beq.s .end_inter
		cmp.l #0x43543630,(A0)      // CT60
		bne.s .next_cookie_inter
		move.l 4(A0),D0
		beq.s .end_inter
		move.l phystop,A0
		move.w count_io3_mfp(A0),-(SP)
		clr.w count_io3_mfp(A0)
		move.l D0,A0
		move.w (SP)+,D0
		mulu #6,D0                  // tr/mn
		move.w D0,6(A0)             // speed_fan
		bra.s .end_inter
.next_cookie_inter:
		addq.l #8,A0
	bra.s .loop_cookie_inter
.end_inter:
	movem.l (SP)+,D0/A0
	bclr #3,0xFFFFFA11       // ISRB
	rte

#endif /* !COLDFIRE */

