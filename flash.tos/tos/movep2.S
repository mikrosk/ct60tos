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

	.globl	movep_e02b1e

movep_e02b1e:
	ori.w	#0x700,sr
	move.b	0x28(a2),d7
	lsl.l	#8,d7
	move.b	0x2A(a2),d7
	lsl.l	#8,d7
	move.b	0x2C(a2),d7
	lsl.l	#8,d7
	move.b	0x2E(a2),d7
	rts
