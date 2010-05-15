/*  TOS 4.04 patch for the CT60 board
 *  Copyright (C) 2001 Xavier Joubert, 2004-2006 Didier Mequignon
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
	
#include "ct60.h"	

#define rw_parameter 0xc60b

	.align	2
	.long	0x3C4
	.long	end1-begin1
begin1:
#ifdef COLDFIRE
	moveq.l	#60,d0             // cf68klib 68060
	move.l	d0,(a0)+
	move.w	d0,0x59E
	move.l	#0x5F43465F,d0     // _CF_
	move.l	d0,(a0)+
	clr.l	(a0)+
	move.l	#0x41303030,d0     // A000
	move.l	d0,(a0)+
	move.l	#0xE09512,d0       // address function Linea 0xA000
	move.l	d0,(a0)+           // MAC instruction on Coldfire use opcodes 0xAxxx
#else
	moveq.l	#60,d0             // 68060
	move.l	d0,(a0)+
	move.w	d0,0x59E
	move.l	#0x43543630,(a0)+  // CT60 
	clr.l	(a0)+
#endif
	bra.s	begin1-0x3C4+0x402
end1:

	.align	2
	.long	0x46A
	.long	end2-begin2
begin2:
#ifndef COLDFIRE
	movec.l	PCR,D0
	btst	#16,D0
	bne.s	.no_fpu            // EC or LC
	movem.l	D1-D2/A0-A2,-(SP)
#else
	lea	-20(SP),SP
	movem.l	D1-D2/A0-A2,(SP)
#endif
	clr.l	-(SP)
	move.l	#CT60_CPU_FPU,-(SP)
	move.w	#CT60_MODE_READ,-(SP)
	move.w	#rw_parameter,-(SP)
	trap	#14
	lea	12(SP),SP
#ifndef COLDFIRE
	movem.l	(SP)+,D1-D2/A0-A2
#else
	movem.l	(SP),D1-D2/A0-A2
	lea	20(SP),SP
#endif
	btst	#0,D0
	bne.s	.with_fpu
#ifndef COLDFIRE
	movec.l	PCR,D0
	bset	#1,D0              // disable the FPU
	fnop
	movec.l	D0,PCR
#endif
.no_fpu:
	clr.l	(a0)+
	bra.s	begin2-0x46A+0x4C2
.with_fpu:
	moveq.l	#0x10,D0
	swap	D0
	move.l	D0,(a0)+
	bra.s	begin2-0x46A+0x4C2
end2:

#ifdef COLDFIRE
	.align	2
	.long	0x436
	.long	end3-begin3
begin3:
	moveq	#0,D1              // no sound
end3:

	.align	2
	.long	0x274
	.long	end4-begin4
begin4:
	bra.s	begin4-0x274+0x29C
end4:	

	.align	2
	.long	0x2D2
	.long	end5-begin5
begin5:
	nop
	nop
	nop
	nop
	nop
	nop
end5:

	.align	2
	.long	0x42E
	.long	end6-begin6
begin6: 	// _SWI
	nop
	nop
	nop
end6:
	.globl	before_init_cookies

	.align	2
	.long	0x3B0
	.long	end7-begin7
begin7:
	jsr	before_init_cookies 
	nop
	nop
end7:

#endif // COLDFIRE
