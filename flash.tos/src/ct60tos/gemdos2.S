/* TOS 4.04 Gemdos Pexec patch for the CT60 board
*  Didier Mequignon 2003 March, e-mail: didier-mequignon@wanadoo.fr
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

	.globl flush_cache_pexec
	
flush_cache_pexec:

	movem.l A0/A1,-(SP)
	lea.l 256(A5),A0            // begin of the program
	cmp.w #0x6008,(A0)+         // fix problems with Ice Packer
	bne.s .no_ice
	cmp.l #0x5061636B,(A0)+     // Pack
	bne.s .no_ice
	cmp.l #0x2D496365,(A0)+     // _Ice
	bne.s .no_ice
	cmp.w #0x4ED2,0x86(A0)      // jmp (A2)
	bne.s .no_ice
	cmp.w #0x4ED6,0xA4(A0)      // jmp (A6)
	bne.s .no_ice
	move.w #0x4AFC,0x86(A0)     // illegal
	move.w #0x4AFC,0xA4(A0)     // illegal
	lea .new_illegal(PC),A0
	move.l 0x10,0x380           // save illegal vector
	clr.l 0x384                 // illegal counter
	move.l A0,0x10
	bra.s .no_ice
.new_illegal:
	cpusha BC                   // flush
	addq.l #1,0x384             // illegal counter
	cmp.l #2,0x384
	bcs.s .jmp_a2
	move.l 0x380,0x10           // restore illegal vector
	addq.l #8,SP
	moveq #0,D0
	move D0,SR
	jmp (A6)
.jmp_a2:
	addq.l #8,SP
	moveq #0,D0
	move D0,SR
	jmp (A2)
.no_ice:	
	cpusha BC                   // flush
	move.l A5,0x6EE4
	movem.l (SP)+,A0/A1
	rts
	
