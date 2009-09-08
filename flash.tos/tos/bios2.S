/* TOS 4.04 Bios bconout patch for the CT60 board
*  Didier Mequignon 2001 December, e-mail: aniplay@wanadoo.fr
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

	.globl _bconout2

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
#endif
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

_bconout2:
	move.w 6(SP),D1
#ifdef COLDFIRE
	tst.l con_state
	bne.s .con_state_ok     // to fix
	bsr _con_state_init     // normally in Setscreen	
.con_state_ok:
#endif
	move.w D1,-(SP)
	bsr _cputc
	addq.l #2,SP
	rts
	
get_cookie:

	move.l D1,-(SP)
	move.l D0,D1
	move.l cookie,D0
	beq.s .cookie_not_found
	move.l D0,A0
.loop_cookie:
		tst.l (A0)
		beq.s .cookie_not_found
		cmp.l (A0),D1
		bne.s .next_cookie
		move.l 4(A0),D0
		bra.s .end_cookie
.next_cookie:
		addq.l #8,A0
	bra.s .loop_cookie
.cookie_not_found:
	moveq #0,D0
	move.l D0,A0
.end_cookie:
	move.l (SP)+,D1
	tst.l D0
	rts
	
test_accel:

	move.l _v_bas_ad,D0
        	cmp.l #0x01000000,D0
        	bcs.s .no_pci_drivers
	move.l #0x5F504349,D0    // cookie _PCI
	bsr get_cookie
	move.l A0,D0
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
	
#include "conout.S"
