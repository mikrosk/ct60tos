/*  TOS 4.04 patch for the CT60 board
 *  Copyright (C) 2001 Xavier Joubert
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

	.align	2
	.long	0x25DC
	.long	end1-begin1
begin1:
	.long	0x05018800
	lea	0xFFFFFA01.w,a0
	moveq	#-24,d0
loop1:	clr.b	24(a0,d0.w)
	addq.l	#2,d0
	bne.s	loop1
end1:

	.align	2
	.long	0x526
	.long	end2-begin2
begin2:
	bsr	begin2-0x526+0x25E0
end2:

	.align	2
	.long	0x2632
	.long	end3-begin3
begin3:
	lea	0xFFFFFA27.w,a0
	move.l	begin3-0x2632+0x25DC(pc),d0
loop2:	move.b	d0,(a0)
	addq.l	#2,a0
	lsr.l	#8,d0
	bne.s	loop2
	tst.b	0xA87.w
end3:

	.globl	movep_e02b1e

	.align	2
	.long	0x2B1E
	.long	end4-begin4
begin4:
	 jsr	movep_e02b1e
	nop
end4:
