/*  MagXBoot for the CT60
 * 
 * Didier Mequignon 2004, e-mail: aniplay@wanadoo.fr
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
	.text
 
	.globl magxboot

#include "vars.h"

//#define MALLOC_STRAM

magxboot:

	movem.l D0-A6,-(SP)
	tst.l D0
	sne.b D4
	ext.w D4
	swap D4                  // flag _FPU cookie
	clr.w D4
	tst.l D1                 // _FRQ cookie, internal clock
	beq.s mb2
	cmp.l #32,D1
	bls mb2
	tst.l D2                 // _FRE cookie, external clock
             beq.s mb2
	cmp.l #32,D2
	seq.b D4
	ext.w D4                 // flag clock external patch
mb2:
	lea mess(PC),A0
	bsr printline
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	moveq #3,D0
	and.b (A0),D0            // SHIFTs
	cmp.w #3,D0 
	beq mb1
	clr.w -(SP)
 	pea magx_name+1(PC)
	move.w #0x3D,-(SP)       // Fopen
	trap #1
	addq.w #8,SP
	move.w D0,D7
	bpl.s mb3
	lea error(PC),A0
	bsr printline
	move.w #7,-(SP)          // Crawcin
	trap #1                  // Gemdos
	addq.w #2,SP
	bra mb1	
mb3:
 	move.w #2,-(SP)          // seek mode : end
	move.w D7,-(SP)          // handle
	clr.l -(SP)              // offset
	move.w #0x42,-(SP)       // Fseek
	trap #1                  // Gemdos
	lea 10(SP),SP
	move.l D0,D6
	ble mb1
 	clr.w -(SP)              // seek mode : begin
	move.w D7,-(SP)          // handle
	clr.l -(SP)              // offset
	move.w #0x42,-(SP)       // Fseek
	trap #1                  // Gemdos
	lea 10(SP),SP
	tst.l D0
	bmi mb1 
#ifdef MALLOC_STRAM
	clr -(SP)                // ST-RAM
#else
	move.w #3,-(SP)          // TT-RAM if possible
#endif
	move.l D6,-(SP)
	move.w #0x44,-(SP)       // Mxalloc
	trap #1                  // Gemdos 
	addq.w #8,SP
	tst.l D0
	ble mb1
	move.l D0,A6
	pea (A6)                 // buff
	move.l D6,-(SP)          // count
	move.w D7,-(SP)          // handle
	move.w #0x3F,-(SP)       // Fread
	trap #1                  // Gemdos
	lea 12(SP),SP
	move.l D0,-(SP)
	move.w D7,-(SP)// handle
	move.w #0x3E,-(SP)       // Fclose
	trap #1                  // Gemdos
	addq.w #4,SP
	cmp.l (SP)+,D6
	bne mb1
	tst.l D0
	bmi mb1
	cmp.w #0x601A,(A6)
	bne mb1
	move.l 0x30(A6),A0
	lea 0x1C(A6,A0.L),A0
	cmp.l #0x87654321,(A0)+
	bne mb1
	move.l (A0)+,A5
	addq.l #4,A0
	cmp.l #0x4D414758,(A0)   // MAGX
	bne mb1
	move.l #0x1000000,__md
	cmp.l #0x1357BD13,ramvalid
	bne.s mb4
	cmp.l #0x1080000,ramtop
	bcs.s mb4
	move.l #0x1000000,A5
mb4:
	move.w #0x400,0x1E(A6)   // machine FALCON
mb5:
	move.w #0x19,-(SP)       // Dgetdrv
	trap #1                  // Gemdos
	addq.w #2,SP
	move.l 0x30(A6),A0
	lea 0x1C(A6,A0.L),A0
	lea 0x7A(A0),A0
	cmp.l #0x5F5F5F5F,(A0)
	bne.s mb8
	add.b #0x41,D0
	move.b D0,(A0)+
	move.b #0x3A,(A0)+
	lea magx_name(PC),A1
mb7:
	move.b (A1)+,(A0)+
	bne.s mb7
mb8:
	move.l 2(A6),D0
	add.l 6(A6),D0
	move.l D0,D5
	add.l 0xE(A6),D0
	lea 0x1C(A6,D0.L),A3
	lea (A6,D6.L),A2
	cmp.l A2,A3
	bcc.s mb9
	lea 0x1C(A6),A0 // MagiC relocation
	move.l (A3)+,D0
mb10:
	add.l D0,A0
	move.l A5,D0
	add.l D0,(A0)
mb11:
		cmp.l A2,A3
		bhi.s mb9
		moveq #0,D0
		move.b (A3)+,D0
		beq.s mb9
		cmp.b #1,D0
		bne.s mb10
	lea 254(A0),A0
	bra.s mb11
mb9:
	lea 0x1C(A6),A0
	lea (A0,D5.L),A1
	moveq #0,D0
mb12:
		add.l (A0)+,D0
	cmp.l A0,A1
	bcs.s mb12
	move.l D0,trp14ret
	lea 0x1C(A6),A1 // patchs
	move.l D5,D1
	lsr.l #1,D1
	moveq #0,D2
mb22:
		move.l (A1),D0          // caches
		cmp.l #0x203C0000,D0    // MOVE.L #0x808,D0
		bne.s mb26
		cmp.l #0x08084E7B,4(A1) // MOVEC.L D0,CACR
		beq.s mb27
		cmp.l #0x31114E7B,4(A1) // move.l #0x3111,D0
		bne.s mb26
		move.l #0x203CA080,(A1)
		move.l #0x80004E7B,4(A1)
		lea mess1(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb27:
		move.l #0x70004E7B,(A1)
		move.l #0x00024E71,4(A1)
		move.w #0xF4F8,8(A1)    // CPUSHA BC
		lea mess2(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb26:
		cmp.l #0x4E7A0002,D0    // MOVE.L CACR,D0
		bne.s mb37
		cmp.l #0x08C00003,4(A1) // BSET #3,D0
		bne.s mb37
		cmp.l #0x4E7B0002,8(A1) // MOVEC.L D0,CACR
		bne.s mb37
		cmp.l #0x70021238,12(A1)
		bne.s mb37
		move.l #0x4E714E71,D0
		move.l D0,(A1)
		move.l D0,4(A1)
		move.l D0,8(A1)
		lea mess3(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb37:
		cmp.l #0x03C80000,D0    // MOVE.L D1,(A0)
		bne.s mb24
		cmp.l #0x03C80008,4(A1) // MOVEP.L D1,8(A0)
		bne.s mb24
		cmp.l #0x03C80010,8(A1) // MOVEP.L D1,16(A0)
		bne.s mb24
		move.l #0x72E84230,(A1)
		move.l #0x10185481,4(A1)
		move.l #0x66F84E71,8(A1)
		lea mess4(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb24:
		cmp.l #0x203C0088,D0    // MOVE.L #0x00880105,D0
		bne.s mb25
		cmp.l #0x010501C8,4(A1) // MOVEP.L D0,0x26(A0)
		bne.s mb25
		cmp.w #0x0026,8(A1)
		bne.s mb25
		move.l #0x42280026,(A1)
		move.l #0x117C0088,4(A1)
		move.l #0x0028117C,8(A1)
		move.l #0x0001002A,12(A1)
		move.l #0x117C0005,16(A1)
		move.l #0x002C6038,20(A1)
		lea mess5(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb25:
		cmp.l #0x204F7000,D0 // 060
		bne.s mb28
		cmp.w #0x21FC,4(A1)
		bne.s mb28
		move.l #0x703C4E75,(A1)
		lea mess6(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb28:
		cmp.l #0x41F80008,D0 // vectors
		bne.s mb31
		cmp.l #0x703D43FA,4(A1)
		bne.s mb31
		move.w #0x7008,4(A1)
		lea mess7(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb31:
		cmp.l #0x703D20C9,D0 // vectors
		bne.s mb32
		cmp.l #0xD3C151C8,4(A1)
		bne.s mb32
		move.w #0x7008,(A1)
		lea mess8(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb32:
		cmp.l #0x21C80010,D0 // vectors
		bne.s mb33
		cmp.l #0x21C8002C,4(A1)
		bne.s mb33
		move.l #0x4E714E71,4(A1)
		lea mess9(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb33:
		cmp.l #0x4E700CB8,D0 // reset
		bne.s mb34
		cmp.l #0x31415926,4(A1)
		bne mb23
		lea mess10(PC),A0
		bsr printline
		addq.w #1,D2
		bra.s mb36
mb34:
		cmp.l #0x4E7021F8,D0 // reset
		bne.s mb35
		cmp.l #0x00040008,4(A1)
		bne.s mb33
		lea mess11(PC),A0
		bsr printline
		addq.w #1,D2
mb36:
		move.w #0x4E71,(A1)
		bra mb23
mb35:
		cmp.l #0x4E7B0002,D0 // Init DSP
		bne.s mb38
		cmp.l #0x0C380004,4(A1)
		bne.s mb38
		cmp.w #0x665E,10(A1)
		bne.s mb38
		cmp.w #0x6100,12(A1)
		bne.s mb38
		move.l #0x4E714E71,12(A1) // Init DSP removed
		lea mess12(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb38:
		cmp.l #0x610008A6,D0 // floppy
		bne.s mb39
		cmp.l #0x61000AF2,4(A1)
		bne.s mb39
		cmp.l #0x3CBC0180,8(A1)
		bne.s mb39
		move.l #0x610008BA,4(A1)
		lea mess13(PC),A0
		bsr printline
		bra mb23
mb39:
		cmp.l #0x54415441,D0 // FPU cookie
		bne.s mb40
		cmp.l #0x54415441,4(A1)
		bne.s mb40
		cmp.w #0x50F8,8(A1)
		bne.s mb40
		move.w #0x7210,6(A1)
		lea mess14(PC),A0
		bsr printline
		addq.w #1,D2
		tst.l D4 // FPU
		bmi mb23
		move.w #0x7200,6(A1)
		bra mb23
mb40:
		cmp.l #0xF3274A17,D0 // context FPU
		bne.s mb45
		cmp.l #0x670CF227,4(A1)
		bne.s mb45
		cmp.l #0xE0FFF227,8(A1)
		bne.s mb45
		move.l #0x4E714E71,2(A1)
		lea mess18(PC),A0
		bsr printline
		addq.w #1,D2
		bra mb23
mb45:
		tst.l D4             // flag FPU
		bmi.s mb46
		cmp.l #0xF3790100,D0 // FPU FRESTORE
		bne.s mb46
		move.l #0x4E714E71,(A1)
		move.w #0x4E71,4(A1)
		bra mb23
mb46:
		cmp.l #0x703F20D9,D0 // PMMU tree 030
		bne.s mb43
		cmp.l #0x51C8FFFC,4(A1)
		bne.s mb43
		move.w #0x4E71,2(A1)
		lea mess15(PC),A0
		bsr printline
		addq.w #1,D2
		bra.s mb23
mb43:
		tst.w D4             // flag external clock
		bpl.s mb23
		cmp.l #0x720211C1,D0 // external clock
		bne.s mb44
		cmp.w #0x820A,4(A1)
		bne.s mb44
		move.l #0x4E714E71,(A1)
		move.w #0x4E71,4(A1)
  		lea mess16(PC),A0
		bsr printline
		addq.w #1,D2
		bra.s mb23 
mb44:
		cmp.l #0x31D8820A,D0 // external clock
		bne.s mb23
		cmp.w #0x4E75,4(A1)
		bne.s mb23 
		move.l #0x4E714E71,(A1)
		lea mess17(PC),A0
		bsr printline
		addq.w #1,D2
mb23:
		addq.w #2,A1
	subq.l #1,D1
	bgt mb22
	moveq #18,D3
	tst.w D4        // flag external clock
	bpl.s mb42
	addq.w #3,D3
mb42:
	cmp.w D3,D2
	beq mb21
	lea warning(PC),A0
	bsr printline
	move.l D2,D0
	bsr display_deci
	moveq #0x2F,D0
             bsr display_char
	move.l D3,D0
	bsr display_deci
	moveq #0x29,D0
	bsr display_char
	move.w #7,-(SP) // Crawcin
	trap #1         // Gemdos
	addq.w #2,SP
mb21:
	or #0x700,SR    // lock interrupts
	lea mb14(PC),A1
	lea 0x600,A0
	lea (mb1-mb14).w,A2
	move.l A2,D0
	lsr.l #2,D0
	subq.w #1,D0
mb13:
		move.l (A1)+,(A0)+
	dbf D0,mb13
	move.l _memtop,phystop
	cpusha DC      // flush and disable caches
	moveq #0,D0
	movec.l D0,CACR
	cinva BC
	nop
	jmp 0x600
mb14:
	move.l A5,A0
	lea 0x1C(A6),A1
	move.l D5,D0
	lsr.l #3,D0
	subq.l #1,D0
	cmp.l A0,A1    // MagiC mover
	bhi.s mb16
	beq.s mb18
	add.l D5,A1
	add.l D5,A0
mb17:
		move.l -(A1),-(A0)
		move.l -(A1),-(A0)
	dbf D0,mb17
	bra.s mb18
mb16:
		move.l (A1)+,(A0)+
		move.l (A1)+,(A0)+
	dbf D0,mb16
mb18:
	move.l #0x5555AAAA,memval3
	move.l #0x31415926,resvalid
	move.l A5,resvector
	cmp.l #0x1000000,A5
	bne.s mb19
	add.l D5,__md
	bra.s mb20
mb19:
	add.l D5,0xC(A5)
	move.l 0x14(A5),A0
	cmp.l #0x87654321,(A0)+
	bne.s mb20
	add.l D5,(A0)
mb20:
	clr.l _hz_200
	jmp (A5)
	nop
mb1:
	movem.l (SP)+,D0-A6
	rts

printline:

	movem.l D0-D2/A0-A2,-(SP)
	move.l A0,-(SP)
	move #9,-(SP) // Cconws
	trap #1       // Gemdos
	addq.w #6,SP
	movem.l (SP)+,D0-D2/A0-A2 
	rts
	
display_char:

	movem.l D0-D2/A0-A2,-(SP)
	move D0,-(SP)
	move #2,-(SP)
	move #3,-(SP)
	trap #13
	addq.w #6,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts
	
display_deci:           // D0.L:value

	movem.l	D0/D1/A0,-(SP)
	link A4,#-16
	moveq #9,D1
	link A6,#-16
	lea -16(A6),A0
	move.w D1,-(SP)
	bsr conv_deci
	move.w (SP)+,D1
	lea -16(A4),A0
	lea -16(A6),A1
	subq.w #1,D1
	bmi.s dd3
dd1:
		move.b (A1)+,D0
		cmp.b #0x20,D0
		beq.s dd2
		move.b D0,(A0)+
dd2:
	dbf D1,dd1
	clr.b (A0)
dd3:
	unlk A6
	lea -16(A4),A0
	bsr printline
	unlk A4
	movem.l (SP)+,D0/D1/A0
	rts
	
conv_deci:                     // A0:target ascii, D0.L:value, D1:len

	move.w D1,-(SP)
	subq.w #1,D1
	move.l D0,-(SP)
cd1:
		moveq #0,D0
		move.w (SP),D0
		divu #10,D0
		move.w D0,(SP)
		move.w 2(SP),D0
		divu #10,D0
		move.w D0,2(SP)
		swap D0
		or.w #0x30,D0
		move.b D0,(A0,D1.W)
	dbf D1,cd1
	addq.w #4,SP
	move.w (SP)+,D1
	subq.w #1,D1
	beq.s cd2
	swap D0
	tst.w D0
	bne.s cd3
	moveq #0,D0
cd4:
		cmp.b #0x30,(A0,D0.W)
		bne.s cd2
		move.b #0x20,(A0,D0.W)
		addq.w #1,D0
	cmp.w D1,D0
	bne.s cd4
	bra.s cd2
cd3:
	move.b #0x3F,(A0,D1.W)
	dbf D1,cd3
cd2:
	rts

mess:
	.byte	13,10,10,27
	.ascii	"p MagiC-BOOTER "
	.byte	27
	.ascii	"q"
	.byte	13,10,0
mess1:
	.byte	13,10
	.asciz	"Patch cache 1"
mess2:
	.byte	13,10
	.asciz	"Patch cache 2"
mess3:
	.byte	13,10
	.asciz	"Patch cache 3"
mess4:
	.byte	13,10
	.asciz	"Patch movep 1"
mess5:
	.byte	13,10
	.asciz	"Patch movep 2"
mess6:
	.byte	13,10
	.asciz	"Patch CPU type"
mess7:
	.byte	13,10
	.asciz	"Patch vectors 1"
mess8:
	.byte	13,10
	.asciz	"Patch vectors 2"
mess9:
	.byte	13,10
	.asciz	"Patch vectors 3"
mess10:
	.byte	13,10
	.asciz	"Patch reset 1"
mess11:
	.byte	13,10
	.asciz	"Patch reset 2"
mess12:
	.byte	13,10
	.asciz	"Patch DSP"
mess13:
	.byte	13,10
	.asciz	"Patch floppy"
mess14:
	.byte	13,10
	.asciz	"Patch FPU cookie"
mess15:
	.byte	13,10
	.asciz	"Patch PMMU 030 tree"
mess16:
	.byte	13,10
	.asciz	"Patch external clock 32MHz RGB monitor 1"
mess17:
	.byte	13,10
	.asciz	"Patch external clock 32MHz RGB monitor 2"
mess18:
	.byte	13,10
	.asciz	"Patch context FPU"
magx_name:
	.byte	0x5C
	.asciz	"magic.ram"
warning:
	.byte	13,10,10
	.asciz	"WARNING ! A part is not patched ! ("
error:
	.byte	13,10
	.asciz	"magic.ram file not found !"
	.byte	13,10,0 

