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

#ifdef COLDFIRE
#include "fire.h"

	.chip 68060
#endif

#undef DEBUG

	.text

	.globl _test_accel
	.globl _sb_scrup,_sb_scrdn,_sb_neg_cell,_sb_move_cursor,_sb_cell,_sb_blank
	.globl _sb_scrup_c,_sb_scrdn_c,_sb_neg_cell_c,_sb_move_cursor_c,_sb_cell_c,_sb_blank_c,_sb_blank_internal
	.globl get_cookie

#ifdef COLDFIRE
	.globl det_bios
	
det_bios:

	move.l savptr,A1
	move.w (SP)+,D0
	move.w D0,-(A1)          // save SR
	move.l (SP)+,-(A1)       // save PC
	tst.w proc_type
	beq.s .proc_less_68020
	tst.w (SP)+
.proc_less_68020:
	lea -40(A1),A1
	movem.l D3-D7/A3-A7,(A1)
	move.l A1,savptr
	btst #13,D0              // call in supervisor state
	bne.s .call_super
	move.l USP,A0            // emulated instruction who as SP
	move.l A0,SP             // as target return bad SP !
.call_super:
	moveq #0,D0
	moveq #0,D1
	move.w (SP)+,D0          // function
	lea 0xE0153A,A0          // BIOS tab
	move.w (A0)+,D1          // max
	cmp.l D1,D0
	bge .call_error
#ifdef DEBUG
	cmp.l #1,D0
	beq .bconout
	cmp.l #2,D0
	beq .bconout
	cmp.l #3,D0
	beq .bconout
	cmp.l #9,D0
	beq .bconout
	move.l A0,-(SP)
	lea debug1(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
	move.l D0,-(SP)
	bsr debug_hex_byte
	move.l (SP),D0
	ext.l D0
	cmp.l #5,D0
	bne.s .not_setexec
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w 4(SP),D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l 6(SP),D0
	bsr debug_hex_long
.not_setexec:
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
.bconout:
#endif /* DEBUG */
	asl.l #2,D0
	add.l D0,A0
	move.l (A0),D0
	bclr #0,D0
	move.l D0,A0
	beq.s .not_indirect
	move.l (A0),A0
.not_indirect:
	sub.l A5,A5
	jsr (A0)                 // call function
.call_error:
	move.l savptr,A1
	movem.l (A1),D3-D7/A3-A7
	lea 40(A1),A1
	tst.w proc_type
	beq.s .proc_less_68020b
	clr.w -(SP)              // format
.proc_less_68020b:
	move.l (A1)+,-(SP)       // restore PC
	move.w (A1)+,-(SP)       // restore SR
	move.l A1,savptr
	rte
	
#ifdef DEBUG

debug1:	.asciz "BIOS #0x"
	
	.align 2
	
debug_display_string:

	move.l D0,-(SP)
	move.l A0,-(SP)
.dds2:
		move.b (A0)+,D0
		beq.s .dds1
		bsr debug_display_char
	bra.s .dds2
.dds1:
	move.l (SP)+,A0
	move.l (SP)+,D0
	rts

debug_hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s debug_hex_word
	move.l (SP)+,D0
debug_hex_word:
	move.w D0,-(SP)
	lsr.l #8,D0          
	bsr.s debug_hex_byte     
	move.w (SP)+,D0
debug_hex_byte:
	move.w D0,-(SP)
	lsr.l #4,D0        
	bsr.s debug_hex_char      
	move.w (SP)+,D0      
debug_hex_char:
	and.l #0xF,D0      
	or.l #0x30,D0      
	cmp.l #0x3A,D0     
	bcs.s debug_display_char  
	addq.l #7,D0   

debug_display_char:

	tst.b serial_mouse
	bne.s .no_debug
	move.l D1,-(SP)
.wait_uart:
	move.b MCF_UART_USR0,D1
	and.l  #MCF_UART_USR_TXRDY,D1
	beq.s .wait_uart
	move.b D0,MCF_UART_UTB0 // send the character
	move.l (SP)+,D1
.no_debug:
	rts
	
wait_key:

	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
#ifdef DEBUG
	move.w #1,-(SP)          // AUX
#else
	move.w #2,-(SP)          // CON
#endif
	move.w #2,-(SP)          // Bconin
	trap #13
	addq.l #4,SP
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	rts 
	
#endif /* DEBUG */

#endif /* COLDFIRE */

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

#ifndef COLDFIRE /* conout.c */

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
#ifndef COLDFIRE /* just for backward compatibility because the VDI driver part overwrite VT52 */
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
#endif /* COLDFIRE */
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
#ifndef COLDFIRE /* just for backward compatibility because the VDI driver part overwrite VT52 */
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
#endif /* COLDFIRE */
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

#ifdef COLDFIRE
	lea -16(SP),SP
	movem.l D0-D1/A0-A1,(SP)
#else
	movem.l D0-D1/A0-A1,-(SP)
#endif
	move.l D1,-(sp)
	move.l D0,-(sp)
	jsr _sb_move_cursor_c
	addq.l #8,SP
#ifdef COLDFIRE
	movem.l (SP),D0-D1/A0-A1
	lea 16(SP),SP
#else
	movem.l (SP)+,D0-D1/A0-A1
#endif
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

#ifdef COLDFIRE
	lea -16(SP),SP
	movem.l D0-D1/A0-A1,(SP)
#else
	movem.l D0-D1/A0-A1,-(SP)
#endif
	ext.l D0
	ext.l D1
	ext.l D2
	ext.l D3
	move.l D3,-(SP)         // boty
	move.l D2,-(SP)         // botx
	move.l D1,-(SP)         // topy
	move.l D0,-(SP)         // topx
#ifndef COLDFIRE /* just for backward compatibility because the VDI driver part overwrite VT52 */
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
#endif /* COLDFIRE */
	jsr _sb_blank_c
.sb_blank_end:
	lea 16(SP),SP
#ifdef COLDFIRE
	movem.l (SP),D0-D1/A0-A1
	lea 16(SP),SP
#else
	movem.l (SP)+,D0-D1/A0-A1
#endif
	rts
  
/* wrapper used when calling the blanking primitive from C */
/* void sb_blank_internal(short x1, short y1, short x2, short y2) */
_sb_blank_internal:

#ifdef COLDFIRE
	lea -44(SP),SP
	movem.l D2-D7/A2-A6,(SP)
#else
	movem.l D2-D7/A2-A6,-(SP)
#endif
	movem.l 48(SP),D0-D4
	bsr _sb_blank
#ifdef COLDFIRE
	movem.l (SP),D2-D7/A2-A6
	lea 44(SP),SP
#else
	movem.l (SP)+,D2-D7/A2-A6
#endif
	rts

#ifdef COLDFIRE	

	.globl _bconout2,_bconout5,normal_ascii,_blink

test_v_bas_ad:

	cmp.l #0x01000000,_v_bas_ad
	rts

_bconout2:

	tst.l con_state          // to fix, normally in Setscreen
	bne.s .con_state_ok	
	lea normal_ascii,A0
	move.l A0,con_state      // Init conout state machine	
.con_state_ok:	
//	cmp.w #16,_v_planes
//	bcc.s .bconout2
	bsr.s test_v_bas_ad
	bcc.s .bconout2          // graphic card
.wait_uart:
	move.w 6(SP),D1
.wait_uart2:
	move.b MCF_UART_USR0,D0
	and.b #MCF_UART_USR_TXRDY,D0
	beq.s .wait_uart2
	move.b D1,MCF_UART_UTB0  // send the character
	rts
.bconout2:
	jmp 0xE08D4C             // default TOS routine
	
_bconout5:

//	cmp.w #16,_v_planes
//	bcc.s .bconout5
	bsr.s test_v_bas_ad
	bcs.s .wait_uart         // no graphic card
.bconout5:
	jmp 0xE08D40             // default TOS routine
	
normal_ascii:

//	cmp.w #16,_v_planes
//	bcc.s .normal_ascii
	bsr.s test_v_bas_ad
	bcs.s .wait_uart2        // no graphic card
.normal_ascii:
	jmp 0xE08D62             // default TOS routine

_blink:

	bsr.s test_v_bas_ad
	bcs.s .bl_out            // no graphic card
	jmp 0xE090F2             // default TOS routine
.bl_out:
	rts

#endif /* COLDFIRE */

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

#else /* conout.S */

	.globl _bconout2

_bconout2:
#ifndef COLDFIRE
	move.l phystop,A0
	move.l hardware_type(A0),D1
	and.l #SUPERVIDEL,d1
	bne.s .bconout2
#endif /* COLDFIRE */
	move.w 6(SP),D1
#ifdef COLDFIRE
	tst.l con_state         // to fix
	bne.s .con_state_ok
	bsr _con_state_init     // normally in Setscreen	
.con_state_ok:
#endif /* COLDFIRE */
	move.w D1,-(SP)
	bsr _cputc
	addq.l #2,SP
	rts
#ifndef COLDFIRE
.bconout2:
	jmp 0xE08D4C            // default TOS routine for the Supervidel
#endif

#include "conout.S"

#endif /* conout.c */
