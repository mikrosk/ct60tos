/* TOS 4.04 Blitter patch for the CT60 board
*  Didier Mequignon 2002 December, e-mail: aniplay@wanadoo.fr
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

	.globl	get_font_6x6_a0
	.globl	get_font_6x6_a6	
 	.globl	get_font_6x6_a5
 	.globl	get_font_6x6_a3
 	.globl	get_font_8x8_a1
 	.globl	get_font_8x16_a1
 	.globl	get_font_8x16_a1b 
 	.globl	get_font_ptr_a1		
	.globl	copy_fonts
	.globl	logo_atari
	.globl	det_vdi
	
#include "ct60_hw.h"
#include "vars.h"

#ifdef COLDFIRE
#include "fire.h"
#endif

// #define DEBUG

	.text
	
get_font_6x6_a0:

	move.l A2,-(SP)
	move.l phystop,A2
	move.l adr_fonts(A2),0x1C6(A0)
	move.l (SP)+,A2
	rts

get_font_6x6_a6:

	move.l A2,-(SP)
	move.l phystop,A2
	move.l adr_fonts(A2),-6(A6)
	move.l (SP)+,A2
	rts

get_font_6x6_a5:

	move.l phystop,A5
	move.l adr_fonts(A5),A5
	rts	

get_font_6x6_a3:

	move.l phystop,A3
	move.l adr_fonts(A3),A3
	rts	

get_font_8x8_a1:

	move.l phystop,A1
	move.l adr_fonts+4(A1),A1
#ifdef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug3(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
	rts	

get_font_8x16_a1:

	move.l phystop,A1
	move.l adr_fonts+8(A1),A1
#ifdef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug4(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
	rts	

get_font_8x16_a1b:

	move.l phystop,A1
	move.l adr_fonts+12(A1),A1
#ifdef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug4(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
	rts

get_font_ptr_a1:

	move.l phystop,A1
	lea.l adr_fonts(A1),A1
	rts

copy_fonts:

#ifdef COLDFIRE
	lea -28(SP),SP
	movem.l D0-D3/A0-A2,(SP)
#ifdef DEBUG
	lea debug1(PC),A0
	bsr debug_display_string
#endif
#else
	movem.l D0-D3/A0-A2,-(SP)
#endif
	move.l phystop,D0
	sub.l #RESERVE_MEM_FONTS,D0
#ifndef COLDFIRE
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D1
	and.b #0xF,D1
	cmp.b #0x3,D1            // SHIFT-SHIFT
	bne.s .sdram
	sub.l #RESERVE_MEM-RESERVE_MEM_FONTS,D0
.sdram:	
#endif
	move.l D0,_memtop
	move.l D0,A1
	move.l D0,D1
	lea 0xE4AFEC,A0
#ifdef COLDFIRE
	move.l #0xFFF,D0
cf1:
		move.l (A0)+,(A1)+
	subq.l #1,D0
	bpl.s cf1	
#else
	move.w #0xFFF,D0
cf1:
		move.l (A0)+,(A1)+
	dbf D0,cf1	
#endif
	move.l A1,D2
	lea 0xE09410,A0
	moveq #0x17,D0
cf2:
		move.l (A0)+,(A1)+
#ifdef COLDFIRE
	subq.l #1,D0
	bpl.s cf2
#else
	dbf D0,cf2
#endif
	lea (0x2000-0x60)(A1),A1
	move.l A1,D3
	lea 0xE49434,A0 /* logo ATARI */
#ifdef COLDFIRE
	move.l #0x101,D0
cf3:
		move.l (A0)+,(A1)+
	subq.l #1,D0
	bpl cf3
#else
	move.w #0x101,D0
cf3:
		move.l (A0)+,(A1)+
	dbf D0,cf3
#endif
	addq.l #4,A0 
	move.l D3,(A1)+
	move.l (A0)+,(A1)+
	move.l (A0)+,(A1)+		
	move.w (A0)+,(A1)+
	move.l phystop,A2
	clr.l flag_cache(A2)
	clr.l save_hz_200(A2)
	clr.l flag_statvec(A2)
	clr.l power_flag(A2)
	lea adr_fonts(A2),A2
	lea 0xE4AFEC,A0
	move.l D1,A1
	movem.l 0x48(A0),D0/D3
	sub.l A0,D0
	add.l D1,D0
	sub.l A0,D3
	add.l D1,D3
	movem.l D0/D3,0x48(A1)
	move.l A1,(A2)+
	add.l #0xE4B6C8-0xE4AFEC,D1
	add.l #0xE4B6C8-0xE4AFEC,A0
	move.l D1,A1
	movem.l 0x48(A0),D0/D3
	sub.l A0,D0
	add.l D1,D0
	sub.l A0,D3
	add.l D1,D3
	movem.l D0/D3,0x48(A1)	
	move.l A1,(A2)+
	add.l #0xE4D124-0xE4B6C8,D1
	add.l #0xE4D124-0xE4B6C8,A0
	move.l D1,A1
	movem.l 0x48(A0),D0/D3
	sub.l A0,D0
	add.l D1,D0
	sub.l A0,D3
	add.l D1,D3
	movem.l D0/D3,0x48(A1)
	move.l A1,(A2)+
	lea 0xE09410,A0
	move.l D2,A1
	movem.l D0/D3,0x48(A1)
	move.l A1,(A2)+
	clr.l (A2)+
#ifdef COLDFIRE
	movem.l (SP),D0-D3/A0-A2
	lea 28(SP),SP
#else
	cpusha dc		
	movem.l (SP)+,D0-D3/A0-A2
#endif
	rts
	
logo_atari:

#ifndef COLDFIRE
	cmp.l #0x01000000,_v_bas_ad
	bcc.s .no_logo
	move.l _memtop,A0
	add.l #0x6408,A0
	pea.l (A0)
	jmp 0xE00666
.no_logo:
#endif
	jmp 0xE0066E

//#ifndef COLDFIRE /* there are a new Coldfire VDI inside the PCI part */
	
	dc.l 0x58425241          // XBRA
#ifdef COLDFIRE
	dc.l 0x5F43465F          // _CF_
#else
	dc.l 0x43543630          // CT60
#endif
	dc.l 0x00E1C22C          // TOS VDI entry point

det_vdi:

#ifdef COLDFIRE
	ext.l D0
	cmp.l #0x73,D0   // VDI
	bne v1
	lea -16(SP),SP
	movem.l A0-A3,(SP)
#else
	cmp.w #0x73,D0   // VDI
	bne v1
	movem.l A0-A3,-(SP)
#endif
	move.l D1,A1
	move.l (A1),A3   // CONTRL
#ifdef COLDFIRE
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug2(PC),A0
	bsr debug_display_string
	move.w (A3),D0   // function
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,A0
	move.l (SP)+,D0
#endif
	move.w (A3),D0
	cmp.l #109,D0    // vro_cpyfm
	beq.s v10
	cmp.l #110,D0    // vr_trnfm
	beq.s v10
	cmp.l #121,D0    // vrt_cpyfm
#else
	cmp.w #109,(A3)  // vro_cpyfm
	beq.s v10
	cmp.w #110,(A3)  // vr_trnfm
	beq.s v10
	cmp.w #121,(A3)  // vrt_cpyfm
#endif
	bne v3
v10:
	move.l D2,-(SP)
	move.l phystop,A2
	move.l A3,save_contrl(A2)
	clr.l adr_source(A2)
	clr.l adr_target(A2)
	move.l 14(A3),A0 // MFDB source
	tst.l (A0)
	beq.s v4         // source = screen
#ifdef COLDFIRE
	move.l (A0),D2
	cmp.l #0xE00000,D2
#else
	cmp.l #0xE00000,(A0)
#endif
	bcs.s v4         // <> fast-ram or flash
	move.l (A0),adr_source(A2)
 	moveq #15,D2
#ifdef COLDFIRE
	moveq #0,D0
	move.w 4(A0),D0  // width
	add.l D0,D2
 	lsr.l #4,D2      // /16
#else 
 	add.w 4(A0),D2   // width
 	lsr.w #4,D2      // /16
#endif
	mulu 12(A0),D2   // number of planes
	mulu 6(A0),D2    // height
	add.l D2,D2      // size in bytes
	move.l D2,D0     // size
	add.l #32,D0
	bsr malloc_stram
	ble v7           // error
	move.l D0,save_source(A2)
	add.l #15,D0
#ifdef COLDFIRE
	and.l #0xFFFFFFF0,D0 // 16 bytes alignment
#else
	and.b #0xF0,D0   // 16 bytes alignment
#endif
	move.l D0,(A0)   // new source
	move.l D0,A1
	move.l adr_source(A2),A0 // source in fast-ram
	moveq #15,D0
	add.l D2,D0      // size
	lsr.l #4,D0      // /16
v11:                          // block copy
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
	subq.l #1,d0
	bgt.s v11      	
v4:
	move.l 18(A3),A0 // MFDB target
	tst.l (A0)
	beq.s v9         // target = screen
#ifdef COLDFIRE
	move.l (A0),D0
	cmp.l #0xE00000,D0
#else
	cmp.l #0xE00000,(A0)
#endif
	bcs.s v9         // <> fast-ram or flash
	move.l (A0),adr_target(A2)
 	moveq #15,D0
#ifdef COLDFIRE
	moveq #0,D2
	move.w 4(A0),D2  // width
	add.l D2,D0
 	lsr.l #4,D0      // /16
#else 
 	add.w 4(A0),D0   // width
 	lsr.w #4,D0      // /16
#endif
	mulu 12(A0),D0   // number of planes
	mulu 6(A0),D0    // height
	add.l D0,D0      // in bytes
	add.l #32,D0
	bsr malloc_stram
	ble v8
	move.l D0,save_target(A2)
	add.l #15,D0
#ifdef COLDFIRE
	and.l #0xFFFFFFF0,D0 // 16 bytes alignment
#else
	and.b #0xF0,D0   // 16 bytes alignment
#endif
	move.l D0,(A0)   // new target
v9:
	move.l (SP)+,D2
#ifdef COLDFIRE
	movem.l (SP),A0-A3
	lea 16(SP),SP
#else
	movem.l (SP)+,A0-A3
	moveq #0x73,D0
#endif
	clr.w -(SP)      // format if > 68000
	pea.l v2(PC)
#ifdef COLDFIRE
	move.w SR,D0
	move.w D0,-(SP)
	moveq #0x73,D0	
#else
	move.w SR,-(SP)
#endif
	move.l det_vdi-4(PC),-(SP)
	rts
v2:
#ifdef COLDFIRE
	lea -28(SP),SP
	movem.l D0-D2/A0-A3,(SP)  // return after vro_cpyfm
#else
	movem.l D0-D2/A0-A3,-(SP) // return after vro_cpyfm
#endif
	move.l phystop,A2
	move.l save_contrl(A2),A3
	tst.l adr_source(A2)
	beq.s v5
	move.l 14(A3),A1 // MFDB source
	move.l save_source(A2),A0
	bsr free_stram
	move.l adr_source(A2),(A1)	
	clr.l adr_source(A2)
v5:
	move.l adr_target(A2),D0
	beq.s v6
	move.l 18(A3),A0 // MFDB target
	move.l D0,A1     // target in fast-ram
 	moveq #15,D0
#ifdef COLDFIRE
	moveq #0,D1
	move.w 4(A0),D1  // width
	add.l D1,D0
 	lsr.l #4,D0      // /16
#else 
 	add.w 4(A0),D0   // width
 	lsr.w #4,D0      // /16
#endif
	mulu 12(A0),D0   // number of planes
	mulu 6(A0),D0    // height
	add.l D0,D0      // size in bytes
	move.l (A0),A0   // new target => source
	add.l #15,D0
	lsr.l #4,D0      // /16
v12:                          // block copy
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
	subq.l #1,d0
	bgt.s v12
v13:
	move.l 18(A3),A1 // MFDB target
	move.l save_target(A2),A0
	bsr free_stram
	move.l adr_target(A2),(A1)
	clr.l adr_target(A2)
v6:
#ifdef COLDFIRE
	movem.l (SP),D0-D2/A0-A3
	lea 28(SP),SP
#else
	movem.l (SP)+,D0-D2/A0-A3
#endif
	rte	 
v8:
	tst.l adr_source(A2)
	beq.s v7
	move.l 14(A3),A1 // MFDB source
	move.l save_source(A2),A0
	bsr free_stram
	move.l adr_source(A2),(A1)	
	clr.l adr_source(A2)
v7:
	move.l (SP)+,D2
#ifdef COLDFIRE
	movem.l (SP),A0-A3
	lea 16(SP),SP
#else
	movem.l (SP)+,A0-A3
#endif
	rte
v3:
#ifdef COLDFIRE
	movem.l (SP),A0-A3
	lea 16(SP),SP
#else
	movem.l (SP)+,A0-A3
#endif
	moveq #0x73,D0
v1:
	move.l det_vdi-4(PC),-(SP)
	rts

malloc_stram:

#ifdef COLDFIRE
	lea -20(SP),SP
	movem.l D1-D2/A0-A2,(SP)
#else
	movem.l D1-D2/A0-A2,-(SP)
#endif
	clr.w -(SP)
	move.l D0,-(SP)
	move.w #0x44,-(SP)
	trap #1
	addq.l #8,SP
#ifdef COLDFIRE
	movem.l (SP),D1-D2/A0-A2
	lea 20(SP),SP
#else
	movem.l (SP)+,D1-D2/A0-A2
#endif
	tst.l D0
	rts

free_stram:

#ifdef COLDFIRE
	lea -20(SP),SP
	movem.l D1-D2/A0-A2,(SP)
#else
	movem.l D1-D2/A0-A2,-(SP)
#endif
	pea.l (A0)
	move.w #0x49,-(SP)
	trap #1
	addq.l #6,SP
#ifdef COLDFIRE
	movem.l (SP),D1-D2/A0-A2
	lea 20(SP),SP
#else
	movem.l (SP)+,D1-D2/A0-A2
#endif
	rts
	
//#endif /* COLDFIRE */

#ifdef COLDFIRE
#ifdef DEBUG

debug1:	.ascii "Copy fonts in STRAM"
	.byte 13,10,0
debug2:	.asciz "VDI #0x"
debug3:	.ascii "fonts 8x8"
	.byte 13,10,0
debug4:	.ascii "fonts 8x16"
	.byte 13,10,0
debug5:	.ascii "init_wk"
	.byte 13,10,0
debug6:	.ascii "text_init"
	.byte 13,10,0
debug7:	.ascii "INIT_G"
	.byte 13,10,0	
	
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
