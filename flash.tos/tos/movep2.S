/* TOS 4.04 patch for the CT60 / Coldfire board(s)
*  Copyright (C) 2001 Xavier Joubert
*                2006 Didier Mequignon
*
*  This library is free software; you can redistribute it and/or
*  modify it under the terms of the GNU Lesser General Public
*  License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
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
	.globl	movep_e02b1e

 	.text

movep_e02b1e:
#ifdef COLDFIRE
	move.w	SR,D7
	or.l	#0x700,D7
	move.w	D7,SR
#else
	or.w	#0x700,SR
#endif
	move.b	0x28(A2),D7
	lsl.l	#8,D7
	move.b	0x2A(A2),D7
	lsl.l	#8,D7
	move.b	0x2C(A2),D7
	lsl.l	#8,D7
	move.b	0x2E(A2),D7
	rts
