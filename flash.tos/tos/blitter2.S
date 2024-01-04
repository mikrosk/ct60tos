/* TOS 4.04 Blitter patch for the CT60 and Coldfire boards
*  Didier Mequignon 2002/2011, e-mail: aniplay@wanadoo.fr
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
	
#include "vars.h"


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
	rts	

get_font_8x16_a1:

	move.l phystop,A1
	move.l adr_fonts+8(A1),A1
	rts	

get_font_8x16_a1b:

	move.l phystop,A1
	move.l adr_fonts+12(A1),A1
	rts

get_font_ptr_a1:

	move.l phystop,A1
	lea.l adr_fonts(A1),A1
	rts

copy_fonts:

	movem.l D0-D3/A0-A2,-(SP)
	move.l phystop,D0
	move.l D0,A1
	move.l D0,D1
	lea 0xE4AFEC,A0 // f6x6 FONT_HEAD
	move.w #0xFFF,D0
cf1:
		move.l (A0)+,(A1)+
	dbf D0,cf1	
	move.l A1,D2
	lea 0xE09410,A0 // f16x32 FONT_HEAD
	moveq #0x17,D0
cf2:
		move.l (A0)+,(A1)+
	dbf D0,cf2
	lea (0x2000-0x60)(A1),A1
	move.l A1,D3
	lea 0xE49434,A0 /* logo ATARI */
	move.w #0x101,D0
cf3:
		move.l (A0)+,(A1)+
	dbf D0,cf3
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
	lea 0xE4AFEC,A0 // f6x6 FONT_HEAD 
	move.l D1,A1
	movem.l 0x48(A0),D0/D3
	sub.l A0,D0
	add.l D1,D0
	sub.l A0,D3
	add.l D1,D3
	movem.l D0/D3,0x48(A1)
	move.l A1,(A2)+
	add.l #0xE4B6C8-0xE4AFEC,D1
	add.l #0xE4B6C8-0xE4AFEC,A0 // f8x8 FONT_HEAD
	move.l D1,A1
	movem.l 0x48(A0),D0/D3
	sub.l A0,D0
	add.l D1,D0
	sub.l A0,D3
	add.l D1,D3
	movem.l D0/D3,0x48(A1)	
	move.l A1,(A2)+
	add.l #0xE4D124-0xE4B6C8,D1
	add.l #0xE4D124-0xE4B6C8,A0 // f8x16 FONT_HEAD
	move.l D1,A1
	movem.l 0x48(A0),D0/D3
	sub.l A0,D0
	add.l D1,D0
	sub.l A0,D3
	add.l D1,D3
	movem.l D0/D3,0x48(A1)
	move.l A1,(A2)+
	lea 0xE09410,A0 // f16x32 FONT_HEAD
	move.l D2,A1
	movem.l D0/D3,0x48(A1)
	move.l A1,(A2)+
	clr.l (A2)+
	cpusha dc		
	movem.l (SP)+,D0-D3/A0-A2
	rts
	
	
logo_atari:

	cmp.l #0x01000000,_v_bas_ad
	bcc.s .no_logo
	move.l phystop,A0
	add.l #0x6408,A0
	pea.l (A0)
	jmp 0xE00666
.no_logo:
	jmp 0xE0066E


	dc.l 0x58425241          // XBRA
	dc.l 0x43543630          // CT60
	dc.l 0x00E1C22C          // TOS VDI entry point

det_vdi:

	cmp.w #0x73,D0   // VDI
	bne v1
	movem.l A0-A3,-(SP)
	move.l D1,A1
	move.l (A1),A3   // CONTRL
	cmp.w #109,(A3)  // vro_cpyfm
	beq.s v10
	cmp.w #110,(A3)  // vr_trnfm
	beq.s v10
	cmp.w #121,(A3)  // vrt_cpyfm
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
	cmp.l #0xE00000,(A0)
	bcs.s v4         // <> fast-ram or flash
	move.l (A0),adr_source(A2)
 	moveq #15,D2
 	add.w 4(A0),D2   // width
 	lsr.w #4,D2      // /16
	mulu 12(A0),D2   // number of planes
	mulu 6(A0),D2    // height
	add.l D2,D2      // size in bytes
	move.l D2,D0     // size
	add.l #32,D0
	bsr malloc_stram
	ble v7           // error
	move.l D0,save_source(A2)
	add.l #15,D0
	and.b #0xF0,D0   // 16 bytes alignment
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
	cmp.l #0xE00000,(A0)
	bcs.s v9         // <> fast-ram or flash
	move.l (A0),adr_target(A2)
 	moveq #15,D0
 	add.w 4(A0),D0   // width
 	lsr.w #4,D0      // /16
	mulu 12(A0),D0   // number of planes
	mulu 6(A0),D0    // height
	add.l D0,D0      // in bytes
	add.l #32,D0
	bsr malloc_stram
	ble v8
	move.l D0,save_target(A2)
	add.l #15,D0
	and.b #0xF0,D0   // 16 bytes alignment
	move.l D0,(A0)   // new target
v9:
	move.l (SP)+,D2
	movem.l (SP)+,A0-A3
	moveq #0x73,D0
	clr.w -(SP)      // format if > 68000
	pea.l v2(PC)
	move.w SR,-(SP)
	move.l det_vdi-4(PC),-(SP)
	rts
v2:
	movem.l D0-D2/A0-A3,-(SP) // return after vro_cpyfm
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
 	add.w 4(A0),D0   // width
 	lsr.w #4,D0      // /16
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
	movem.l (SP)+,D0-D2/A0-A3
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
	movem.l (SP)+,A0-A3
	rte
v3:
	movem.l (SP)+,A0-A3
	moveq #0x73,D0
v1:
	move.l det_vdi-4(PC),-(SP)
	rts

malloc_stram:

	movem.l D1-D2/A0-A2,-(SP)
	clr.w -(SP)
	move.l D0,-(SP)
	move.w #0x44,-(SP)
	trap #1
	addq.l #8,SP
	movem.l (SP)+,D1-D2/A0-A2
	tst.l D0
	rts

free_stram:

	movem.l D1-D2/A0-A2,-(SP)
	pea.l (A0)
	move.w #0x49,-(SP)
	trap #1
	addq.l #6,SP
	movem.l (SP)+,D1-D2/A0-A2
	rts
	
	
