/* TOS 4.04 AES patch for Eiffel POWER OFF alert for the CT60 board
*  Didier Mequignon 2004 February, e-mail: aniplay@wanadoo.fr
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

	.globl det_evnt_multi
	
#include "vars.h"

alert_power_en:
	.asciz "[2][ |Do you want cut the|power of your computer?][Yes|No]" 

alert_power_fr:
	.asciz "[2][ |Voulez vous ‚teindre|votre ordinateur ?][Oui|Non]" 
	
	.align 2	

det_evnt_multi:

	move.l phystop,A1
	cmp.l #0xCAFEFADE,power_flag(A1)
	bne.s .no_power_off
	clr.l power_flag(A1)
	movem.l D0-A5,-(SP)
	link A6,#-48
	pea.l -48(A6)                                       // buffer
	move.w #48,-(SP)                                    // size
	clr.w -(SP)                                         // start
	clr.w -(SP)                                         // read
	move.w #46,-(SP)                                    // NVMaccess
	trap #14
	lea.l 12(SP),SP
	lea.l -48(A6),A0                                    // buffer
	move.b 6(A0),D0                                     // language
	unlk A6
	lea.l alert_power_en(PC),A0
	cmp.b #2,D0                                         // french
	bne.s .no_french
	lea.l alert_power_fr(PC),A0	
.no_french:                                      
	pea.l (A0)
	move.w #1,-(SP)
	jsr 0xE22A68                                        // form_alert
	addq.l #6,SP
	cmp.w #1,D0                                         // delay
	bne.s .cancel
	clr.b 0xFA800000                                    // power off
	dc.w 0xF800,0x01C0,0x2700		
.cancel:
	movem.l (SP)+,D0-A5
.no_power_off:
	swap D0
	clr.w D0
	swap D0
	rts
 
PALETTE_565	=	0xE50BA4	// AES table, 256 colours in Falcon 5-6-5

	.globl fix_cicon_colours

fix_cicon_colours:
	cmp.w #32,24(A6)                                    // planes
	bne.s .not_ours

	movem.l D1-D7/A0-A1,-(SP)
	move.l 12(A6),A0                                    // icon data
	move.w 20(A6),D5
	lsr.w #3,D5                                         // width in bytes
	ext.l D5
	muls.w 22(A6),D5                                    // bytes in one plane
	lsl.l #3,D5                                         // pixels to convert
	beq.s .done

.long_loop:
	move.l (A0),D6
	beq.s .white
	addq.l #1,D6
	beq.s .black
	subq.l #1,D6
	rol.l #8,D6                                         // planes 0-7 are the top byte
	and.w #0xFF,D6
	add.w D6,D6
	lea.l PALETTE_565,A1
	move.w (A1,D6.w),D0
	bsr.s .widen
	move.l D0,(A0)
	bra.s .next
.white:
	move.l #0x00FFFFFF,(A0)
	bra.s .next
.black:
	clr.l (A0)
.next:
	addq.l #4,A0
	subq.l #1,D5
	bne.s .long_loop

.done:
	movem.l (SP)+,D1-D7/A0-A1
	moveq #0,D0                                         // Z set, ROM loop skipped
	rts

.not_ours:
	moveq #1,D0                                         // Z clear, ROM loop runs
	rts

// D0 5-6-5 -> D0 0x00RRGGBB, each channel repeated into the spare low bits
.widen:
	move.w D0,D1
	lsr.w #8,D1
	and.w #0xF8,D1
	move.b D1,D2
	lsr.b #5,D2
	or.b D2,D1                                          // red

	move.w D0,D3
	lsr.w #3,D3
	and.w #0xFC,D3
	move.b D3,D2
	lsr.b #6,D2
	or.b D2,D3                                          // green

	and.w #0x1F,D0
	lsl.w #3,D0
	move.b D0,D2
	lsr.b #5,D2
	or.b D2,D0                                          // blue

	and.l #0xFF,D0
	and.l #0xFF,D3
	lsl.l #8,D3
	or.l D3,D0
	and.l #0xFF,D1
	swap D1
	or.l D1,D0
	rts
