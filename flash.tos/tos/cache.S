/*  TOS 4.04 patch for the CT60 board
 *  Copyright (C) 2001 Xavier Joubert
 *                2005-2006 Didier Mequignon
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
 *
 *
 *  To contact author write to Xavier Joubert, 5 Cour aux Chais, 44 100 Nantes,
 *  FRANCE or by e-mail to xavier.joubert@free.fr.
 *
 */

	.text

#ifdef COLDFIRE

#include "fire.h"

	.globl	flush_caches_x
	.globl	flush_caches_z
	.globl	flush_caches
	.globl	flush_data_cache
	.globl	caches_disable
	.globl	caches_enable

	.align	2
	.long	0x638
	.long	end1-begin1
begin1:
	jsr	0xE250C8
	nop
	nop
end1:

	.align	2
	.long	0x904
	.long	end2-begin2+0x80000000
begin2:
	jsr	flush_caches_x
	nop
end2:

	.align	2
	.long	0x920
	.long	end3-begin3
begin3:
	jsr	flush_caches_z
	nop
	nop
	nop
	nop
end3:

	.align	2
	.long	0x946
	.long	end4-begin4+0x80000000
begin4:
	jsr	flush_caches_x
	nop
end4:

	.align	2
	.long	0xDF4
	.long	end5-begin5+0x80000000
begin5:
	jsr	flush_caches_x
	nop
end5:

	.align	2
	.long	0x43B0
	.long	end6-begin6+0x80000000
begin6:
	jsr	flush_caches_x
	clr.l	-(sp)
end6:

	.align	2
	.long	0x46CA
	.long	end7-begin7+0x80000000
begin7:
	jsr	flush_caches_x
	nop
end7:

	.align	2
	.long	0x85A
	.long	end8-begin8+0x80000000
begin8:
	jmp	caches_disable
end8:

	.align	2
	.long	0x18CA
	.long	end9-begin9+0x80000000
begin9:
	jsr	flush_caches
	bra.s	begin9-0x18CA+0x18DE
end9:

	.align	2
	.long	0x1944
	.long	end10-begin10
begin10:
	jsr	flush_data_cache+0x80000000
	bra.s	begin10-0x18CA+0x18DE
end10:

#else	// 68060 

	.align	2
	.long	0x638
	.long	end1-begin1
begin1:
	bsr.l	begin1-0x638+0x250C8
	nop
	nop
end1:

	.align	2
	.long	0x908
	.long	end2-begin2
begin2:
	cpusha	bc
	nop
end2:

	.align	2
	.long	0x92A
	.long	end3-begin3
begin3:
	cpusha	bc
	nop
end3:

	.align	2
	.long	0x94A
	.long	end4-begin4
begin4:
	cpusha	bc
	nop
end4:

	.align	2
	.long	0xDF6
	.long	end5-begin5
begin5:
	cpusha	bc
	nop
end5:

	.align	2
	.long	0x43B4
	.long	end6-begin6
begin6:
	cpusha	bc
	nop
end6:

	.align	2
	.long	0x46CC
	.long	end7-begin7
begin7:
	cpusha	bc
	nop
end7:

	.align	2
	.long	0x85A
	.long	end8-begin8
begin8:
	move.w	SR,-(SP)
	or.w	#0x700,SR	
	cpusha	DC
	clr.l	D0
	movec.l	D0,CACR
	cinva	BC
	move.w	(SP)+,SR
	rts
end8:

	.align	2
	.long	0x18CA
	.long	end9-begin9
begin9:
	cpusha	bc
	bra.s	begin9-0x18CA+0x18DE
end9:

	.align	2
	.long	0x1944
	.long	end10-begin10
begin10:
	cpusha	dc
	bra.s	begin10-0x18CA+0x18DE
end10:

#endif  // COLDFIRE

	.align	2
	.long	0x3990
	.long	end11-begin11
begin11:
	bsr.w	begin11-0x3990+0x85A
	nop
	nop
	nop
end11:

	.align	2
	.long	0x756
	.long	end12-begin12
begin12:
	bsr.w	begin12-0x756+0x85A
	nop
	nop
	nop
end12:

#ifndef COLDFIRE

	.align	2
	.long	0x990C
	.long	end13-begin13
begin13:	// v_pline, thanks to Roger Burrows
	subq.w	#1,D3
	movem.w	code13(PC),D0/D1/A1
	movea.l	A2,A0
	move.l	0x652(A4),D2
loop13:
	roxr.l	#1,D2
	bcs.s	set13
	move.w	D0,(A0)+
	dbf		D3,loop13
	move.w	A1,(A0)+
	cpusha	BC
	rts
set13:
	move.w	D1,(A0)+
	dbf		D3,loop13
	move.w	A1,(A0)+
	cpusha	BC
	rts
code13:
	and.w	D0,(A5)+
	or.w	D1,(A5)+
	jmp		(A3)
	nop
	nop
	nop
	nop
end13:

#endif

	.align	2
	.long	0x11BCE
	.long	end14-begin14
begin14:
	rts
end14:

	.align	2
	.long	0x11C56
	.long	end15-begin15
begin15:
	rts
end15:

	.align	2
	.long	0x11D52
	.long	end16-begin16
begin16:
	moveq.l	#1,d0
	rts
end16:

	.align	2
	.long	0x125B8
	.long	end17-begin17
begin17:
	rts
end17:

	.align	2
	.long	0x1292E
	.long	end18-begin18
begin18:
	rts
end18:

	.align	2
	.long	0x1297A
	.long	end19-begin19
begin19:
	rts
end19:

	.align	2
	.long	0x129DE
	.long	end20-begin20
begin20:
	rts
end20:

	.align	2
	.long	0x12BF6
	.long	end21-begin21
begin21:
	rts
end21:

	.align	2
	.long	0x12C76
	.long	end22-begin22
begin22:
	rts
end22:

	.align	2
	.long	0x12CEE
	.long	end23-begin23
begin23:
	rts
end23:

	.align	2
	.long	0x12D6C
	.long	end24-begin24
begin24:
	bra.s	begin24-0x12D6C+0x12D78
end24:

	.align	2
	.long	0x12DD4
	.long	end25-begin25
begin25:
	bra.s	begin25-0x12DD4+0x12DE0
end25:

	.align	2
	.long	0x12E96
	.long	end26-begin26
begin26:
	rts
end26:

	.align	2
	.long	0x17B4C
	.long	end27-begin27
begin27:
	rts
end27:

	.align	2
	.long	0x17BE4
	.long	end28-begin28
begin28:
	rts
end28:

#ifdef COLDFIRE

	.align	2
	.long	0x44544
	.long	end29-begin29
begin29:
	jsr	0xE250C8
	bra.s	begin29-0x44544+0x44578
end29:

	.align	2
	.long	0x4454E
	.long	end30-begin30
begin30:
	jsr	0xE0085A
	bra.s	begin30-0x4454E+0x44584
end30:

#else

	.align	2
	.long	0x44528
	.long	end29-begin29
begin29:
	dc.w	60
end29:

	.align	2
	.long	0x44544
	.long	end30-begin30
begin30:
	bsr.l	begin30-0x44544+0x250C8
	bra.s	begin30-0x44544+0x44578
	nop
	bsr.l	begin30-0x44544+0x85A
	bra.s	begin30-0x44544+0x44584
end30:

#endif

	.align	2
	.long	0x250C8
#ifdef COLDFIRE
	.long	end31-begin31+0x80000000
begin31:
	jmp	caches_enable
#else
	.long	end31-begin31
begin31:
	move.w	SR,-(SP)
	or.w	#0x700,SR
	cpusha	BC
	move.l	#0xA0808000,D0 
	movec.l	D0,CACR
	move.w	(SP)+,SR
	rts
#endif
end31:

	.align	2
	.long	0x4456E
	.long	end32-begin32
begin32:
#ifdef COLDFIRE
	cmp.l	#CACHE_ENABLE_MODE,D0
#else
	cmp.l	#0xA0808000,D0
#endif
end32:

