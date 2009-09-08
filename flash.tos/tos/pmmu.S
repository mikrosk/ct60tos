/*  TOS 4.04 patch for the CT60 board
 *  Copyright (C) 2001 Xavier Joubert
 *                2002-2006 Didier Mequignon
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
 
#include "main.h"
#ifdef COLDFIRE
#include "fire.h"
#endif

	.text            

#ifdef COLDFIRE
	.globl	init_cf
#else	
	.globl	init_060
#endif
	
	.align	2
	.long	0x30
	.long	end1-begin1+0x80000000
begin1:
#ifdef COLDFIRE
	move.l	#init_cf-FLASH_ADR+FLASH_TOS_FIRE_ENGINE,D1
	and.l 	#0xFFFFFF,D1
	lea	end1(PC),A0
	move.l	A0,D0
	and.l	#0xFF000000,D0
	or.l	D1,D0
	move.l	D0,A0
	jmp	(A0)
#else
	jmp	init_060
#endif
end1:

	.globl	init_sdram

	.align	2
	.long	0x632
	.long	end2-begin2+0x80000000
begin2:
	jsr	init_sdram
end2:

#ifdef COLDFIRE

	.align	2
	.long	0x2BC
	.long	end3-begin3
begin3:
	nop
	nop
end3:

#else

	.align	2
	.long	0x14E6
	.long	end3-begin3
begin3:
	//	bra.s	begin3-0x14E6+0x1506
	rts
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
end3:

#endif

	.align	2
	.long	0x39A0
	.long	end4-begin4
begin4:
	bra.s	begin4-0x39A0+0x39B8
end4:

	.globl	add_sdram

	.align	2
	.long	0x96E
	.long	end5-begin5+0x80000000
begin5:
	jmp	add_sdram
end5:

	.align	2
	.long	0x7A08
	.long	end6-begin6
begin6:
	moveq	#9,D7
end6:

	.align	2
	.long	0x7B1C
	.long	end7-begin7
begin7:
	moveq	#9,D7
end7:

	.globl	display_ram_test

	.align	2
	.long	0x7D5A
	.long	end8-begin8+0x80000000
begin8:
	jmp	display_ram_test
end8:

