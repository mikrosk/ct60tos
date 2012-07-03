/*  TOS 4.04 patch for the CT60 board
 *  Didier Mequignon 2001-2010, e-mail: aniplay@wanadoo.fr
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

#ifdef COLDFIRE

	.align	2
	.long	0x2BC
	.long	end1-begin1
begin1:
	nop
	nop
end1:

#else

	.align	2
	.long	0x14E6
	.long	end1-begin1
begin1:
	//	bra.s	begin1-0x14E6+0x1506
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
end1:

#endif

	.align	2
	.long	0x39A0
	.long	end2-begin2
begin2:
	bra.s	begin2-0x39A0+0x39B8
end2:

	.align	2
	.long	0x7A08
	.long	end3-begin3
begin3:
	moveq	#9,D7
end3:

	.align	2
	.long	0x7B1C
	.long	end4-begin4
begin4:
	moveq	#9,D7
end4:


