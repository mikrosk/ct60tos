/* TOS 4.04 Xbios dispatcher for the CT60/CTPCI boards
 * Didier Mequignon 2002-2005, e-mail: aniplay@wanadoo.fr
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with ARAnyM; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#define proc_type 0x59E

	.global _det_xbios,_old_vector_xbios,_video_found
	.global _physbase,_vsetscreen,_vsetmode,_montype,_vgetsize,_vsetrgb,_vgetrgb

	.text

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0                   // cannot store here because we are in flash

_det_xbios:

	move.l USP,A0
	btst #5,(SP)             // call in supervisor state
	beq.s .x2
	lea.l 6(SP),A0
	tst.w proc_type
	beq.s .x2
	tst.w (A0)+              // if > 68000
.x2:
	move.w (A0),D0           // function
	tst.w _video_found
	beq .x1
	cmp.w #2,D0              // Physbase
	bne.s .x9
	jsr _physbase
	rte	
.x9:
	cmp.w #5,D0              // Setscreen
	bne.s .x3
	move.l 10(A0),-(SP)      // rez & modecode
	move.l 6(A0),-(SP)       // logical address
	move.l 2(A0),-(SP)       // physical address
	jsr _vsetscreen
	lea 16(SP),SP
	rte
.x3:
	cmp.w #64,D0             // Blitmode
	bne.s .x4
	moveq #0,D0              // no blitter  
	rte
.x4:
	cmp.w #88,D0             // Vsetmode
	bne.s .x5
	move.w 2(A0),-(SP)       // modecode
	jsr _vsetmode
	addq.w #2,SP
	rte
.x5:
	cmp.w #89,D0             // Mon_type
	bne.s .x6
	jsr _montype
	rte
.x6:
	cmp.w #91,D0             // Vgetsize
	bne.s .x7
	move.w 2(A0),-(SP)       // modecode
	jsr _vgetsize
	addq.w #2,SP
	rte
.x7:
	cmp.w #93,D0             // Vsetrgb
	bne.s .x8
	move.l 6(A0),-(SP)       // array	
	move.l 2(A0),-(SP)       // index & count
	jsr _vsetrgb
	addq.w #8,SP
	rte
.x8:
	cmp.w #94,D0             // Vgetrgb
	bne.s .x1
	move.l 6(A0),-(SP)       // array	
	move.l 2(A0),-(SP)       // index & count
	jsr _vgetrgb
	addq.w #8,SP
	rte
.x1:
	move.l _old_vector_xbios,-(SP)
	rts	
