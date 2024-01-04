/* TOS 4.04 Bios bconout patch for the CT60 and Coldfire boards
*  Didier Mequignon 2001-2012, e-mail: aniplay@wanadoo.fr
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

#include "vars.h"


#undef DEBUG

	.text

	.globl _test_accel
	.globl _sb_scrup,_sb_scrdn,_sb_neg_cell,_sb_move_cursor,_sb_cell,_sb_blank
	.globl _sb_scrup_c,_sb_scrdn_c,_sb_neg_cell_c,_sb_move_cursor_c,_sb_cell_c,_sb_blank_c,_sb_blank_internal
	.globl get_cookie


_test_accel:
test_accel:

	move.l phystop,A0
	move.l hardware_type(a0),D0
	and.l #SUPERVIDEL,D0
	bne.s .no_pci_drivers
	move.l _v_bas_ad,D0
	cmp.l #0x01000000,D0
	bcs.s .no_pci_drivers
	move.l #0x5F504349,D0    // cookie _PCI
	jsr get_cookie
	beq.s .no_pci_drivers
	move.l #0x5F504349,D0
	lea 0xED0000,A0          // 128 KB
	cmp.l (A0),D0            // _PCI
	beq.s .pci_drivers
	lea 0xEC0000,A0          // 192 KB
	cmp.l (A0),D0            // _PCI
	beq.s .pci_drivers
	lea 0xEB0000,A0          // 256 KB
	cmp.l (A0),D0            // _PCI
	beq.s .pci_drivers
	lea 0xEA0000,A0          // 320 KB
	cmp.l (A0),D0            // _PCI
	bne.s .no_pci_drivers
.pci_drivers:
	moveq #1,D0
	rts
.no_pci_drivers:
	moveq #0,D0
	rts


#define LINEA_VAR 0x3E86
#define _v_planes LINEA_VAR          // number of planes
#define _v_rez_hz LINEA_VAR-12       // width screen
#define _v_col_bg LINEA_VAR-38       // current background color
#define _v_cel_mx LINEA_VAR-44       // maximum cell # in x (minimum is 0)
#define _v_cel_my LINEA_VAR-42       // maximum cell # in y (minimum is 0)
#define _v_cel_ht LINEA_VAR-46       // cell height (width is 8)
#define _v_lcol_bg LINEA_VAR+0xB0A

_sb_scrup:

	move.l A0,-(SP)
	move.l A1,-(SP)
	ext.l D1
	move.l D1,-(SP)         // top_line
	bsr test_accel
	beq.s .no_accel_up
	moveq #0,D0
	move.w _v_cel_my,D0
	sub.l D1,D0             // top_line
	mulu _v_cel_ht,D0
	move.l D0,-(SP)         // h
	moveq #0,D0
	move.w _v_rez_hz,D0
	move.l D0,-(SP)         // w
	move.l D1,D0
	move.l D0,-(SP)         // dst_y
	mulu _v_cel_ht,D0        
	clr.l -(SP)             // dst_x
	move.l D1,D0
	addq.l #1,D0
	mulu _v_cel_ht,D0
	move.l D0,-(SP)         // src_y      
	clr.l -(SP)             // src_x
	jsr 28(A0)              // move_screen
	lea 24(SP),SP
	tst.w D0
	beq.s .no_accel_up
	move.w _v_cel_my,D3     // boty
	move.w _v_cel_mx,D2     // botx
	move.w D3,D1            // topy
	moveq #0,D0             // topx
	bsr _sb_blank
	bra.s .sb_scrup_end
.no_accel_up:
	jsr _sb_scrup_c
.sb_scrup_end:
	addq.l #4,SP
	move.l (SP)+,A1
	move.l (SP)+,A0
	rts

_sb_scrdn:

	move.l A0,-(SP)
	move.l A1,-(SP)
	ext.l D1                // start_line
	move.l D1,-(SP)
	bsr test_accel
	beq.s .no_accel_dwn
	moveq #0,D0
	move.w _v_cel_my,D0
	sub.l D1,D0             // start_line
	mulu _v_cel_ht,D0
	move.l D0,-(SP)         // h
	moveq #0,D0
	move _v_rez_hz,D0
	move.l D0,-(SP)         // w
	move.l D1,D0
	addq.l #1,D0
	move.l D0,-(SP)         // dst_y
	mulu _v_cel_ht,D0
	clr.l -(SP)             // dst_x
	move.l D1,D0
	mulu _v_cel_ht,D0
	move.l D0,-(SP)         // src_y      
	clr.l -(SP)             // src_x
	jsr 28(A0)              // move_screen
	lea 24(SP),SP
	tst.w D0
	beq.s .no_accel_dwn
	move.l D1,D3            // topy, boty  
	move.w _v_cel_mx,D2     // botx
	moveq #0,D0             // topx
  	bsr _sb_blank
  	bra.s .sb_scrdn_end
.no_accel_dwn:
	jsr _sb_scrdn_c
.sb_scrdn_end:
	addq.l #4,SP
	move.l (SP)+,A1
	move.l (SP)+,A0
	rts

_sb_neg_cell:

	move.l D0,-(SP)
	move.l D1,-(SP)
	move.l A1,-(SP)
	jsr _sb_neg_cell_c
	addq.l #4,SP
	move.l (SP)+,D1
	move.l (SP)+,D0
	rts

_sb_move_cursor:

	movem.l D0-D1/A0-A1,-(SP)
	move.l D1,-(sp)
	move.l D0,-(sp)
	jsr _sb_move_cursor_c
	addq.l #8,SP
	movem.l (SP)+,D0-D1/A0-A1
	rts

_sb_cell:

	move.l A0,-(SP)
	move.l A1,-(SP)
	move.l D7,-(SP)
	move.l D6,-(SP)
	move.l A1,-(SP)
	move.l A0,-(SP)
	jsr _sb_cell_c
	lea 16(SP),SP
	move.l (SP)+,A1
	move.l (SP)+,A0
	rts

_sb_blank:

	movem.l D0-D1/A0-A1,-(SP)
	ext.l D0
	ext.l D1
	ext.l D2
	ext.l D3
	move.l D3,-(SP)         // boty
	move.l D2,-(SP)         // botx
	move.l D1,-(SP)         // topy
	move.l D0,-(SP)         // topx
	bsr test_accel
	beq.s .no_blank_accel
	move.l D3,D0            // boty
	sub.l D1,D0             // topy
	addq.l #1,D0
	mulu _v_cel_ht,D0
	move.l D0,-(SP)         // h
	move.l D2,D0            // botx
	sub.l 4(SP),D0          // topx
	addq.l #1,D0
	asl.l #3,D0             // * 8
	move.l D0,-(SP)         // w
	move.l D1,D0            // topy
	mulu _v_cel_ht,D0
	move.l D0,-(SP)         // y
	moveq #0,D0
	move.l 12(SP),D0        // topx
	asl.l #3,D0             // * 8
	move.l D0,-(SP)         // x
	moveq #0,D0
	move.w _v_col_bg,D0     // for 256 colors
	cmp.w #16,_v_planes
	bcs.s .sb_blank_256
	move.l _v_lcol_bg,D0    // for 65K et 16M colors
.sb_blank_256:
	move.l D0,-(SP)
	jsr 22(A0)              // clear_screen
	lea 20(SP),SP
	tst.w D0
	bne.s .sb_blank_end
.no_blank_accel:
	jsr _sb_blank_c
.sb_blank_end:
	lea 16(SP),SP
	movem.l (SP)+,D0-D1/A0-A1
	rts
  
/* wrapper used when calling the blanking primitive from C */
/* void sb_blank_internal(short x1, short y1, short x2, short y2) */
_sb_blank_internal:

	movem.l D2-D7/A2-A6,-(SP)
	movem.l 48(SP),D0-D4
	bsr _sb_blank
	movem.l (SP)+,D2-D7/A2-A6
	rts


	.globl _memmove,_memcpy

_memmove:
	lea -36(SP),SP	
	movem.l D2-D6/A2-A5,(SP)
	move.l 4+36(SP),A5       // d
	move.l 8+36(SP),A4       // s
	move.l 12+36(SP),D5      // size
	ble.s .mm1
	cmp.l A4,A5
	bls.s .cp0
	move.l A4,A0             // s
	add.l D5,A0              // + size
	cmp.l A0,A5
	bcc.s .cp0
	move.l A5,A1             // d, if inc copy overlap
	add.l D5,A1              // + size
.mm2:
		move.b -(A0),-(A1)
	subq.l #1,D5
	bgt.s .mm2
	bra.s .mm1
.mm3:
	cmp.l #16,D5
	bhi.s .cp0               // fast memcpy
.mm4:
		move.b (A4)+,(A5)+
	subq.l #1,D5
	bgt.s .mm4
.mm1:
	movem.l (SP),D2-D6/A2-A5
	lea 36(SP),SP
	rts

_memcpy:

	lea -36(SP),SP	
	movem.l D2-D6/A2-A5,(SP)
	move.l 4+36(SP),A5       // d
	move.l 8+36(SP),A4       // s
	move.l 12+36(SP),D5      // size
	ble .cp1
.cp0:
	move.l D5,D6
	move.l #256,D4
	bra.s .cp7
.cp4:
		movem.l (A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,(A5)
		movem.l 32(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,32(A5)
		movem.l 64(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,64(A5)
		movem.l 96(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,96(A5)
		movem.l 128(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,128(A5)
		movem.l 160(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,160(A5)
		movem.l 192(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,192(A5)
		movem.l 224(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,224(A5)
		add.l D4,A4
		add.l D4,A5
.cp7:
	sub.l D4,D5
	bpl.s .cp4
	add.l D4,D5
	beq.s .cp1
	moveq #32,D4
	lsr.l #5,D5              // / 32
	beq.s .cp6
	bra.s .cp5
.cp3:
		movem.l (A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,(A5)
		add.l D4,A4
		add.l D4,A5
.cp5:
	subq.l #1,D5
	bpl.s .cp3
.cp6:
	moveq #31,D0
	and.l D6,D0
	lea .cp2(PC),A0
	move.l D0,D2
	bclr #0,D2
	sub.l D2,A0
	jmp (A0)
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
	move.w (A4)+,(A5)+
.cp2:
	bclr #0,D0
	beq.s .cp1
	move.b (A4)+,(A5)+
.cp1:
	movem.l (SP),D2-D6/A2-A5
	lea 36(SP),SP
	rts

