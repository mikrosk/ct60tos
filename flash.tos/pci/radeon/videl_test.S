/* TOS 4.04 Videl 64K colors fVDI screen test for the CT60 board
*  Didier Mequignon 2003-2004, e-mail: aniplay@wanadoo.fr
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

#include "config.h"

#ifdef TEST_NOPCI

	.global _init_videl_320_240_65K,_init_videl_640_480_65K
	
_init_videl_320_240_65K:

	movem.l D0-A6,-(SP)
	move.l 64(SP),A0        // screen address
	move.w SR,-(SP)
	or.w #0x700,SR          // no IRQ
	pea (A0)                // screen address
	lea 0xFFFF8200,A0       // VIDEL
	lea videl_vga_320_240(PC),A1
	move.w #240*4,D1        // height
	move.l (A1)+,0x82(A0)   // hht,hbb
	move.l (A1)+,0x86(A0)   // hbe,hdb
	move.l (A1)+,0x8A(A0)   // hde,hss
	move.w (A1)+,0xA2(A0)   // vft
	movem.w (A1),D2-D5      // vbb,vbe,vdb,vde
	addq.w #8,A1
	move.w D5,D0            // vde
	sub.w D4,D0             // vdb
	sub.w D1,D0             // nb lines
	lsr.w #1,D0
	add.w D4,D0             // vdb
	add.w D0,D1
	move.w D0,D3            // vbe
	move.w D1,D2            // vbb
	movem.w D2/D3,0xA4(A0)  // vbb,vbe
	movem.w D0/D1,0xA8(A0)  // vdb,vde
	move.w (A1)+,0xAC(A0)   // vss
	move.b 1(SP),1(A0)      // high address
	move.b 2(SP),3(A0)      // middle
	move.b 3(SP),0xD(A0)    // low
	addq.w #4,SP
	clr.w 0xE(A0)           // offset for next line (in words)
	bclr #0,0xA(A0)         // internal clock
	move.w #320,0x10(A0)    // words/line
	move.w (A1)+,0xC2(A0)   // vco, pred video clock (pixel)
	move.w (A1),0xC0(A0)    // vco_hi, clock and monitor
	move.w #0x100,0x66(A0)  // 65536 colors => no palette
	clr.l 0xFFFF9800        // black border
	move.w (SP)+,SR
	movem.l (SP)+,D0-A6
	rts

_init_videl_640_480_65K:

	movem.l D0-A6,-(SP)
	move.l 64(SP),A0        // screen address
	move.w SR,-(SP)
	or.w #0x700,SR          // no IRQ
	pea (A0)                // screen address
	lea 0xFFFF8200,A0       // VIDEL
	lea videl_vga_640_480(PC),A1
	move.w #480*2,D1        // height
	move.l (A1)+,0x82(A0)   // hht,hbb
	move.l (A1)+,0x86(A0)   // hbe,hdb
	move.l (A1)+,0x8A(A0)   // hde,hss
	move.w (A1)+,0xA2(A0)   // vft
	movem.w (A1),D2-D5      // vbb,vbe,vdb,vde
	addq.w #8,A1
	move.w D5,D0            // vde
	sub.w D4,D0             // vdb
	sub.w D1,D0             // nb lines
	lsr.w #1,D0
	add.w D4,D0             // vdb
	add.w D0,D1
	move.w D0,D3            // vbe
	move.w D1,D2            // vbb
	movem.w D2/D3,0xA4(A0)  // vbb,vbe
	movem.w D0/D1,0xA8(A0)  // vdb,vde
	move.w (A1)+,0xAC(A0)   // vss
	move.b 1(SP),1(A0)      // address high
	move.b 2(SP),3(A0)      // middle
	move.b 3(SP),0xD(A0)    // low
	addq.w #4,SP
	clr.w 0xE(A0)           // offset for next line (in words)
	bclr #0,0xA(A0)         // internal clock
	move.w #640,0x10(A0)    // words/line
	move.w (A1)+,0xC2(A0)   // vco, pred video clock (pixel)
	move.w (A1),0xC0(A0)    // vco_hi, clock and monitor
	move.w #0x100,0x66(A0)  // 65536 colors => no palette
	clr.l 0xFFFF9800        // black border
	move.w (SP)+,SR
	movem.l (SP)+,D0-A6
	rts
	
//	       nb_h  BK   BK  DE   DE   top   nb_v  BK   BK  DE  DE   top   
//	       hht   hbb   hbe  hdb   hde   hss   vft   vbb   vbe  vdb  vde   vss
videl_vga_320_240:
	.short 0xC6, 0x8D, 0x15,0x2AC,0x91, 0x96, 0x419,0x3FF,0x3F,0x3F,0x3FF,0x415,5,0x186 // 25 MHz
videl_vga_640_480:
	.short 0x189,0x126,0x31,0,    0x160,0x135,0x419,0x3FF,0x3F,0x3F,0x3FF,0x415,4,0x182 // 50 MHz

#endif
