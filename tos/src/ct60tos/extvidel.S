/*  Extended videl screens CT60
 * 
 * Didier Mequignon May 2004, e-mail: aniplay@wanadoo.fr
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
	
	.globl init_screen
 
#include "vars.h"

#define BPS1 0
#define BTS2 1
#define BPS4 2
#define BPS8 3
#define BPS16 4
#define COL80 3
#define VGA_FALCON 4
#define PAL 5
#define OVERSCAN 6
#define STMODES 7
#define VERTFLAG 8
// extended flags
#define HORFLAG 9      // double width (TV)
#define HORFLAG2 10    // width increased (TV, VGA or MONO SM1xx)
#define VESA_FALCON 11 // SVGA 608 lines                |1024 * 768 interlaced
#define ULTRA_VGA_FALCON 12 // SVGA 768 lines interlaced|

#define CLOCK_FORCED 15 // internal

#define internal_clock_frequency -32
#define external_clock_frequency -30
#define words_by_line   -28
#define number_of_lines -26
#define params_line     -24
#define params_frame    -12

init_screen: // modecode inside D0.W, if D0.L < 0 => new allocation memory screen
             // internal clock frequency inside D1.L
             // external clock frequency inside D2.L
             // return error if D0 < 0 (-2 if no external clock) else clock selected in MHz

	movem.l D1-A2,-(SP)
	link A5,#-32
	move.l D0,D7
	move D1,internal_clock_frequency(A5)
	move D2,external_clock_frequency(A5)
	bsr videl_parameters
	move D0,D5       // clock frequency in MHz
	moveq #0,D0
	move D7,D0
	bsr size_screen  // => words_by_line(A5) & number_of_lines(A5) & screen size inside D0.L
	moveq #-1,D6     // physical screen adress unchanged
	tst.l D7
	bpl.s isc2
	move.l D0,-(SP)  // size of screen
	move #0x15,-(SP) // Srealloc
	trap #1
	addq #6,SP
	move.l D0,D6     // adress of screen
	ble isc1
	move.l D0,_v_bas_ad
isc2:
	move D7,D0
	bsr init_linea_vars
	move #27,-(SP)   // ESC
	move #2,-(SP)    // Cconout
	trap #1
	addq #4,SP
	move #0x45,-(SP) // clear screen
	move #2,-(SP)    // Cconout
	trap #1
	addq #4,SP
	move.l D6,A0
	move D7,D0
	move D5,D1
	bsr init_videl
	bmi.s isc4       // no external clock
	moveq #0,D0      // OK
	move D5,D0       // clock selected
	bra.s isc3
isc4:
	moveq #-2,D0     // no external clock
	bra.s isc3
isc1:
	moveq #-1,D0     // error
isc3:
	unlk A5
	movem.l (SP)+,D1-A2
	rts

size_screen: // modecode inside D0
             // and flag monochrome monitor inside D0.H (D0.L < 0)
             // return size in bytes inside D0.L

	movem.l D1/D7,-(SP)
	bsr fix_stmodes
	move.l D0,D7
	move D7,D1
	and #7,D1 //  0: monochrome, 1: 4 colors, 2: 16 colors, 3: 256 colors, 4: 65536 colors
	//       planes: 1              2            4          8                 16
	btst #STMODES,D7
	beq.s ss9
	tst.l D7
	bmi.s ss28           // no test => monochrome monitor
	move.b 0xFFFF8006,D0 // read connector video
	and.b #0xC0,D0
	beq.s ss28   // monitor ST monochrome
	btst #VGA_FALCON,D7
	beq.s ss9
	cmp #4,D1    // NTC 640 * 400 multisync
	bne.s ss9
	moveq #40,D0 // number of words / line
	bra ss3
ss28:
	moveq #40,D0 // number of words / line
	btst #HORFLAG2,D7
	bne.s ss17
	btst #OVERSCAN,D7
	bne ss20
	bra ss4
ss17:
	btst #OVERSCAN,D7
	bne ss4      // no horizontal overscan in ST monochrome
	moveq #56,D0 // number of words by line with external clock 38 MHz
	bra ss4
ss9:
	moveq #20,D0
	btst #COL80,D7
	beq.s ss2
	add D0,D0
ss2:
	btst #STMODES,D7
	bne.s ss3
	btst #VGA_FALCON,D7
	bne.s ss11 // VGA
	btst #HORFLAG2,D7 // 120 columns
	bne.s ss6
	btst #HORFLAG,D7  // 160 columns
	beq.s ss3
	bra.s ss15
ss6:
	moveq #30,D0
	bra.s ss10
ss11:
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines 96, 112 & 128 columns
	bne.s ss25
	btst #VESA_FALCON,D7      // SVGA 608 lines 96 & 112 columns
	bne.s ss14
	btst #HORFLAG2,D7         // VGA 112 columns
	beq.s ss3
	bra.s ss21
ss25:
	btst #VESA_FALCON,D7
	beq.s ss14
	moveq #32,D0
	bra.s ss10
ss14:
	btst #HORFLAG2,D7         // SVGA 112 columns
	beq.s ss18
ss21:
	moveq #28,D0
ss10:
	btst #COL80,D7
	beq.s ss3
ss15:
	add D0,D0                 // double width
	bra.s ss3
ss18:
	mulu #6,D0
	divu #5,D0
ss3:
	asl D1,D0 // number of words / line
	btst #STMODES,D7
	bne.s ss4 // no overscan in mode ST (low & middle)
	btst #VGA_FALCON,D7
	beq.s ss22
	btst #ULTRA_VGA_FALCON,D7
	bne.s ss4 // no overscan simulation in SVGA
	btst #VESA_FALCON,D7
	bne.s ss4 // no overscan simulation in SVGA
	btst #HORFLAG2,D7
	bne.s ss4
ss22:
	btst #OVERSCAN,D7
	beq.s ss4
ss20:
	mulu #6,D0
	divu #5,D0 // * 1.2 in horizontal overscan
ss4:
	move D0,words_by_line(A5) // number of words by line
	btst #STMODES,D7
	beq.s ss5
	tst.l D7
	bmi.s ss29           // no test => monochrome monitor
	move.b 0xFFFF8006,D1 // read connector video
	and.b #0xC0,D1
	bne.s ss7            // <> monitor ST monochrome
ss29:
	move #400,D1         // monochrome ST high (400 lines)
	btst #OVERSCAN,D7
	bne.s ss19
	btst #HORFLAG2,D7
	beq.s ss12
	bset #OVERSCAN,D7
ss19:
	bset #PAL,D7
	bra.s ss12
ss5:
	btst #VGA_FALCON,D7
	beq.s ss7
	bclr #PAL,D7
	move #240,D1
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines 96, 112 & 128 columns
	beq.s ss24
	move #384,D1
	bra.s ss16
ss24:
	btst #VESA_FALCON,D7 // SVGA 608 lines 96 & 112 columns
	beq.s ss16
	move #304,D1
ss16:
	btst #VERTFLAG,D7 // line double in VGA
	bne.s ss8
	bra.s ss13
ss7:
	move #200,D1      // 200 lines in not interlaced on TV
	btst #STMODES,D7
	beq.s ss12
	btst #VGA_FALCON,D7
	beq.s ss26
	and #7,D7
	cmp #4,D7
	bne.s ss26
	bra.s ss27        // 640 * 400 multisync NTC
ss26:
	tst D7
	bne.s ss1         // no overscan in mode ST (low & middle)
ss27:
	add D1,D1         // emulation ST monochrome 400 lines
	bra.s ss1
ss12:
	btst #VERTFLAG,D7 // interlaced
	beq.s ss8
ss13:
	add D1,D1         // double high
ss8:
	btst #VGA_FALCON,D7
	beq.s ss23
	btst #ULTRA_VGA_FALCON,D7
	bne.s ss1 // no overscan simulation in SVGA
	btst #VESA_FALCON,D7
	bne.s ss1 // no overscan simulation in SVGA
	btst #HORFLAG2,D7
	bne.s ss1
ss23:
	btst #OVERSCAN,D7
	beq.s ss1
	btst #PAL,D7
	sne.b D7
	and #1,D7   // 0:NTSC 1:PAL
	addq #6,D7
	mulu D7,D1
	divu #5,D1  // * 1.2 (or 1.4 in PAL) in vertical overscan
ss1:
	move D1,number_of_lines(A5)
	mulu D1,D0  // lines * words/lines
	add.l D0,D0 // screen size in bytes
	movem.l (SP)+,D1/D7
	rts

videl_parameters: // modecode inside D0
                  // return clock frequency in MHz inside D0

	movem.l D1-A3,-(SP)
	bsr fix_stmodes
	move D0,D7
	lea params_line(A5),A0
	lea tab_shift(PC),A1
	moveq #0,D2
	moveq #0,D3 // flag monochrome monitor
	move D7,D0
	and #7,D0
	bne.s vp17 // color
	btst #STMODES,D7
	beq.s vp17
	move.b 0xFFFF8006,D1 // read connector video
	and.b #0xC0,D1
	bne.s vp17  // <> ST monochrome
	move #-1,D3 // flag monochrome monitor            *** MONO ***
	moveq #40,D4
	move #32,A3 // MHz
	lea tab_time_MONO32(PC),A2
	btst #HORFLAG2,D7
	bne.s vp12
	btst #OVERSCAN,D7
	beq vp10
	lea tab_time_MONO_O(PC),A2
	bra vp10
vp12:
	btst #OVERSCAN,D7
	bne vp10 // no horizontal overscan on monochrome monitor
	addq #8,D4
	move #38,A3 // MHz
	lea tab_time_MONO38(PC),A2 // external clock 38 MHz
	bra vp10
vp17:
	move D7,D4
	and #0xF,D4
	btst #VGA_FALCON,D7 //                             *** VGA ***
	beq vp9 // TV
	add #56,D4
	move #25,A3 // MHz
	lea tab_time_VGA25(PC),A2 // clock 25.175 MHz
	btst #STMODES,D7
	beq.s vp47
	cmp #4,D0 // NTC 640 * 400 multisync
	bne vp10
	add #64,D4 // table ULTRA_VGA
	move #40,A3 // MHz
	lea tab_time_NTCVGA40(PC),A2 // clock 40 MHz
	bra vp10
vp47:
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines 96, 112 & 128 columns
	bne.s vp40
	btst #VESA_FALCON,D7 // SVGA 608 lines 96 & 112 columns
	bne.s vp23
	btst #HORFLAG2,D7 // VGA 112 columns 480 lines
	beq vp10
	add #16,D4
	move #32,A3 // MHz
	lea tab_time_VGA32(PC),A2 // clock 32 MHz VGA 480 lines in 112 columns
	bsr test_clock_36
	bpl.s vp51
	move #36,A3 // MHz
	lea tab_time_VGA36(PC),A2 // clock 36 MHz VGA 480 lines in 112 columns 
	bra vp10
vp51:
	bsr test_clock_40
	bpl vp10
	move #40,A3 // MHz
	lea tab_time_VGA40(PC),A2 // clock 40 MHz VGA 480 lines in 112 columns 
	bra vp10
vp40:
	btst #VESA_FALCON,D7 //  + ULTRA_VGA_FALCON => SVGA 768 lines
	bne vp44
vp23:
	add #32,D4
	move #32,A3 // MHz
	lea tab_time_UVGA32(PC),A2 // clock 32 MHz SVGA 608 or 768 lines in 96 columns
	btst #HORFLAG2,D7 // SVGA in 112 columns
	bne.s vp50
	bsr test_clock_36
	bpl.s vp49
	move #36,A3 // MHz
	lea tab_time_UVGA36(PC),A2 // clock 36 MHz SVGA 608 or 768 lines in 96 columns 
	bra vp10
vp49:
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines
	beq.s vp58
	bsr test_clock_50
	bmi.s vp57
vp58:
	bsr test_clock_40
	bpl vp10
	move #40,A3 // MHz
	lea tab_time_UVGA40(PC),A2 // clock 40 MHz SVGA 608 or 768 lines in 96 columns 
	bra vp10
vp57:
	add #48,D4
	move #50,A3 // MHz
	lea tab_time_UVGA50(PC),A2 // clock 50 MHz SVGA 768 lines in 96 columns with CT60
	bra vp10
vp50:
	add #16,D4
	move #38,A3 // MHz
	lea tab_time_UVGA38(PC),A2 // external clock 38 MHz SVGA 608 or 768 lines in 112 columns
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines
	beq vp10
	bsr test_clock_50
	bpl vp10
	add #48,D4
	move #50,A3 // MHz
	lea tab_time_UVGA50B(PC),A2 // clock 50 MHz SVGA 768 lines in 112 columns with CT60 
	bra vp10
vp44:
	add #64,D4
	move #38,A3 // MHz
	lea tab_time_VVGA38(PC),A2 // external clock 38 MHz SVGA 768 lines in 128 columns
	bsr test_clock_50
	bpl.s vp10
	cmp #60,external_clock_frequency(A5)
	bcs.s vp10
	add #48,D4
	move #60,A3 // MHz
	lea tab_time_VVGA60(PC),A2 // external clock 60 MHz SVGA 768 lines in 128 columns with CT60
	bra.s vp10
vp9:
	lea tab_time_PAL32(PC),A2 // clock 32 MHz           *** TV ***
	move #32,A3 // MHz
	tst D0
	beq.s vp18 // horizontal tables PAL for problem in 2 colors NTSC
	btst #PAL,D7 // PAL
	bne.s vp18
	lea tab_time_NTSC32(PC),A2
vp18:
	btst #STMODES,D7
	bne.s vp10
	btst #HORFLAG2,D7 // 120 columns
	bne.s vp19
	btst #HORFLAG,D7  // 160 columns
	beq.s vp10
	btst #COL80,D7
	beq.s vp11
	and #7,D4
	add #16,D4
	bra.s vp10
vp11:
	bset #COL80,D4
	bra.s vp10
vp19:
	add #24,D4
	move #25,A3 // MHz
	lea tab_time_PAL25(PC),A2 // clock 25.175 MHz in 120 columns
	tst D0
	beq.s vp10 // horizontal tables PAL for problem in 2 colors NTSC
	btst #PAL,D7 // PAL
	bne.s vp10
	lea tab_time_NTSC25(PC),A2
vp10:
	btst #STMODES,D7 //                             *** COMMON ***
	beq.s vp20
	move D7,D0
	and #7,D0
	bne.s vp21 // <> 2 colors
	tst D3
	beq.s vp20 // <> monochrome monitor
	btst #HORFLAG2,D7
	bne.s vp26
	btst #OVERSCAN,D7
	bne.s vp20 // overscan horizontal on monochrome monitor
	bra.s vp25
vp26:
	btst #OVERSCAN,D7
	beq.s vp20
vp25:
	btst #VERTFLAG,D7 // interlaced
	beq.s vp22
	and #0xFFF8,D4
	or #6,D4
	bra.s vp20
vp21:
	cmp #3,D0
	bcs.s vp22 // <256 colors
	beq.s vp20 // 256 colors
	btst #VGA_FALCON,D7
	beq.s vp20
vp22:
	or #7,D4 // if mode ST => different table
vp20:
	move.b (A1,D4),D2
	move.l (A2),D1   // clock video in nS * 100
	move.l 28(A2),D0 // line period in nS * 100
	divu D1,D0       // number of clock cycles by line
	lsr D2,D0
	lsr #1,D0
	subq #2,D0
	move D0,(A0)     // number of clock cycles by line (n-2)
	move.l 4(A2),D0  // top synchro duration line in nS * 100
	divu D1,D0
	lsr D2,D0
	neg D0
	add (A0),D0      // number of clock cycles by line (n-2)
	subq #1,D0
	move D0,10(A0)   // top synchro line
	move.l 8(A2),D0  // pre-synchro duration in nS * 100 (end line)
	divu D1,D0
	lsr D2,D0
	neg D0
	add 10(A0),D0    // value counter at the end of top synchro line
	subq #1,D0
	move D0,2(A0)    // end of screen BLANK
	move.l 12(A2),D0 // post-synchro duration in nS * 100 (begin line)
	divu D1,D0
	lsr D2,D0
	subq #1,D0
	move D0,4(A0)    // begin of screen BLANK
	move.l 24(A2),D0 // width used image in nS * 100
	divu D1,D0
	lsr D2,D0
	moveq #0,D5
	btst #VGA_FALCON,D7
	bne.s vp3 // no overscan in VGA
	btst #STMODES,D7
	bne.s vp3
	btst #OVERSCAN,D7
	beq.s vp3
	move D0,D5
	divu #5,D5       // + 20 % in overscan horizontal
	add D5,D0
	lsr #1,D5
vp3:
	move.l 20(A2),D6 // left edge duration in nS * 100 (begin line)
	divu D1,D6
	lsr D2,D6
	sub D5,D6        // - 10 % left overscan (5 % on monochrome monitor)
	add 4(A0),D6     // + begin of screen BLANK => beginning of used image DE
	add D6,D0
	sub (A0),D0      // number of clock cycles by line (n-2)
	move D0,D5       // end of used image DE
	moveq #1,D0
	move D7,D1
	and #7,D1
	btst #VGA_FALCON,D7
	bne.s vp33
	btst #STMODES,D7 //                                *** TV ***
	bne vp27
	btst #HORFLAG2,D7
	beq vp27
	btst #COL80,D7
	beq vp27
	tst D1
	bne vp27 // >2 colors
	btst #OVERSCAN,D7
	bne.s vp35
	move #232,2(A0) // end of screen BLANK in 2 colors 120 columns (pb trembling if normal DE)
	move #154,4(A0) // begin of screen BLANK
	move #48,6(A0)  // begin used image DE
	move #196,8(A0) // end used image DE
	bra vp34
vp35:
	move #280,2(A0) // end of screen BLANK
	move #106,4(A0) // begin of screen BLANK
	clr 6(A0)       // begin used image DE
	move #271,8(A0) // end used image DE
	bra vp34
vp33:
	btst #STMODES,D7 //                             *** VGA ***
	beq.s vp28      // fix horizontal BLANK
	tst D1
	bne.s vp37 // > 2 colors
	moveq #2,D0
	bra vp27
vp28:
	btst #ULTRA_VGA_FALCON,D7
	bne vp43 // SVGA 768 lines 96, 112 & 128 columns
	btst #VESA_FALCON,D7
	bne.s vp30 // SVGA 608 lines 96 & 112 columns
	btst #HORFLAG2,D7
	bne.s vp32 // VGA 112 columns
	moveq #2,D0
	cmp #1,D1 // 4 colors
	bne vp27
vp37:
	moveq #3,D1
	moveq #1,D0
	bra vp29
vp32:
	cmp #1,D1
	beq.s vp14 // 4 colors
	moveq #2,D1
	moveq #-1,D0
	bsr test_clock_40
	bpl vp29
	addq #3,D1
	bra vp29
vp14:
	moveq #2,D1
	moveq #1,D0
	bsr test_clock_40
	bpl vp53
	addq #1,D1
	bra vp29
vp30:
	cmp #1,D1 // 4 colors SVGA 608 lines 96 columns
	beq.s vp46
	moveq #0,D1
	btst #HORFLAG2,D7
	bne.s vp8 // SVGA 608 lines 112 columns (external clock 37,98 MHz)
	bsr test_clock_40
	bmi.s vp48 // bus at 40 MHz or more for SVGA 608 lines 96 columns
vp8:
	move D7,D0
	btst #HORFLAG2,D7
	bne.s vp48 // SVGA 608 lines 112 columns
	bsr test_clock_36
	bpl.s vp48
	addq #1,D1
vp48:
	moveq #2,D0
	addq #6,D5 // fix DE because it's the same table than SVGA 768 lines 96 columns
	addq #6,D6
	bra vp29
vp46:
	addq #1,D5 // fix DE
	addq #1,D6
	moveq #2,D1
	moveq #1,D0
	btst #HORFLAG2,D7
	bne vp29 // SVGA 608 lines 112 columns
vp53:
	bsr test_clock_36
	bpl vp29
	addq #1,D1
	bra vp29
vp43:
	btst #VESA_FALCON,D7
	bne vp45   // SVGA 768 lines 128 columns
	cmp #1,D1  // SVGA 768 lines 96 & 112 columns
	beq.s vp52 // 4 colors
	moveq #-6,D1
	moveq #8,D0
	btst #HORFLAG2,D7
	bne.s vp62 // 112 columns
	bsr test_clock_50
	bpl.s vp59
	moveq #2,D0 // SVGA 50 MHz 768 lines in 96 columns with CT60
	moveq #7,D1
	and D7,D1
	beq.s vp60 // 2 colors 
	moveq #1,D1
	bra vp29
vp60:
	moveq #1,D1
	add (A0),D1
	bclr #0,D1   // odd alignment (pb trembling)
	move D1,(A0) // number of clock cycles by line (n-2)
	moveq #0,D1
	bra.s vp29 
vp59:
	bsr test_clock_36
	bpl.s vp29
	addq #1,D1
	bra.s vp29
vp62:
	bsr test_clock_50
	bpl.s vp29
	moveq #7,D1 // SVGA 50 MHz 768 lines in 112 columns with CT60
	and D7,D1
	beq.s vp64 // 2 colors
	moveq #2,D0
	moveq #1,D1
	bra.s vp29
vp64:
	moveq #3,D1
	add (A0),D1
	bclr #0,D1   // odd alignment (pb trembling)
	move D1,(A0) // number of clock cycles by line (n-2)
	moveq #4,D0
	moveq #-4,D1
	bra.s vp29
vp52:
	moveq #1,D1 // 4 colors
	moveq #2,D0
	btst #HORFLAG2,D7
	bne.s vp63 // 112 columns
	bsr test_clock_50
	bpl.s vp61
	moveq #1,D0 // SVGA 50 MHz 768 lines in 96 columns with CT60
	moveq #4,D1 
	bra.s vp29
vp61:
	bsr test_clock_36
	bpl.s vp29
	addq #1,D1
	bra.s vp29
vp63:
	bsr test_clock_50
	bpl.s vp29
	moveq #0,D0 // SVGA 50 MHz 768 lines in 112 columns with CT60
	moveq #3,D1
	bra.s vp29 
vp45:
	cmp #1,D1 // SVGA 768 lines 128 columns
	beq.s vp31 // 4 colors
	moveq #2,D1
	moveq #0,D0
	bra.s vp29
vp31:
	moveq #2,D1
	moveq #1,D0
	bsr test_clock_50
	bpl.s vp29
	cmp #60,A3 // MHz
	bcs.s vp29
// SVGA 60 MHz 768 lines in 128 columns with CT60
	addq #1,(A0) // number of clock cycles by line (n-2)
vp29:
	add D1,2(A0) // end of screen BLANK
vp27:
	sub D0,4(A0) // begin of screen BLANK
	lea tab_offset_begin_de(PC),A1
	moveq #0,D1
	move.b (A1,D4),D1
	move D1,D0
	sub D6,D0
	ble.s vp5
	move #514,D0
	add (A0),D0 // number of clock cycles by line (n-2)
	add D0,D6
vp5:
	sub D1,D6
	move D6,6(A0) // begin used image DE ajusted
	lea tab_offset_end_de(PC),A1
	moveq #0,D1
	move.b (A1,D4),D1
	cmp #200,D1
	bcs.s vp54
	ext.w D1 // >>> value between 200 and 255 < 0 <<<
vp54:
	sub D1,D5
	move D5,8(A0) // end used image DE adjusted
vp34:
	move D7,D0
	bsr test_256_ntc
	bpl.s vp39
	bsr test_clock_40
	bmi.s vp39 // bus at 40 MHz or more
	btst #ULTRA_VGA_FALCON,D7
	bne.s vp39
	moveq #10,D0 // fix sweeping line if external clock impossible in 256 colors 80 columns and NTC
	sub D0,(A0)  // number of clock cycles by line (n-2) fixed
	add D0,2(A0) // end of screen BLANK fixed
	add D0,8(A0) // end used image DE fixed
vp39:
	lea params_frame(A5),A0
	tst D3
	beq.s vp15 // <> monochrome monitor
	lea tab_frame_MONO_O(PC),A1
	btst #HORFLAG2,D7
	bne.s vp7
	btst #OVERSCAN,D7
	bne.s vp7
	lea tab_frame_MONO(PC),A1
	bra.s vp7
vp15:
	btst #VGA_FALCON,D7
	beq.s vp24
	lea tab_frame_VGA(PC),A1 // 480 lines 80 & 112 columns
	btst #STMODES,D7
	beq.s vp55
	move D7,D0
	and #7,D0
	cmp #4,D0 // NTC 640 * 400 multisync
	bne.s vp7
	lea tab_frame_NTCVGA(PC),A1 // 400 lines
	bra.s vp7
vp55:
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines 96, 112 & 128 columns
	bne.s vp41
	btst #VESA_FALCON,D7 // SVGA 608 lines 96 & 112 columns
	beq.s vp7
	lea tab_frame_VESA(PC),A1
	bra.s vp7
vp41:
	lea tab_frame_UVGA(PC),A1
	cmp #50,A3 // SVGA 50 MHz 768 lines in 96 or 112 columns with CT60
	bcs.s vp7
	lea tab_frame_UVGA_NI(PC),A1 // or SVGA 60 MHz 768 lines in 128 columns with CT60
	bra.s vp7
vp24:
	lea tab_frame_PAL(PC),A1
	btst #PAL,D7
	bne.s vp7
	lea tab_frame_NTSC(PC),A1
vp7:
	move (A1)+,(A0)  // number of lines by image
	move (A1)+,2(A0) // end of screen BLANK
	move (A1)+,4(A0) // begin of screen BLANK
	move (A1)+,D1    // begin used image DE
	move (A1)+,D2    // end used image DE
	tst D3
	bne.s vp6        // monochrome monitor
	btst #STMODES,D7
	beq.s vp4
	btst #VGA_FALCON,D7
	beq.s vp6 // modes ST TV
	move D7,D0
	and #7,D0
	cmp #4,D0 // NTC 640 * 400 multisync
	beq.s vp6
	add D2,D1
	lsr #1,D1
	move D1,D2
	move #400,D0 // 200 lines in ST basse & moyenne, 400 lines in ST high
	sub D0,D1
	add D0,D2
	bset #0,D2
	bset #0,D1
	move D2,2(A0) // end of screen BLANK
	move D1,4(A0) // begin of screen BLANK
	bra.s vp6
vp4:
	btst #VGA_FALCON,D7
	bne.s vp6
	btst #OVERSCAN,D7
	beq.s vp6
	moveq #0,D0
	move D2,D0
	sub D1,D0
	btst #PAL,D7
	beq.s vp16
	add D0,D0
vp16:
	divu #10,D0 // + 20% with vertical overscan (and 40% in PAL)
	add D0,D2
	sub D0,D1
	bmi.s vp13
	cmp (A1),D2
	bcs.s vp6
vp13:
	sub D1,D2    // if overflow => screen center
	move (A0),D1 // number of lines by image
	sub D2,D1
	lsr #1,D1
	add D1,D2
vp6:
	move D1,6(A0) // begin used image DE
	move D2,8(A0) // end used image DE
	move (A1)+,10(A0) // top frame
	tst D3
	bne.s vp36    // monochrome monitor
	btst #VGA_FALCON,D7
	beq.s vp42
	btst #STMODES,D7
	bne.s vp56
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines 96, 112 & 128 columns
	beq.s vp2     // not interlaced
	cmp #50,A3    // SVGA 50 MHz 768 lines in 96 columns with CT60
//      or external clock 60 MHz SVGA 768 lines in 128 columns with CT60
	bcc.s vp2     // not interlaced
	btst #VERTFLAG,D7 // line double
	bne.s vp2     // not interlaced
	subq #1,4(A0) // begin of screen BLANK
	bra.s vp38    // interlaced
vp56:
	move D7,D0
	and #7,D0
	cmp #4,D0     // NTC 640 * 400 multisync
	bne.s vp2
	bsr test_clock_50
	bpl.s vp2
	lea params_line(A5),A1 // fix on CT60 50 MHz
	move.l #0x01890126,(A1)+
	move.l #0x00310000,(A1)+
	move.l #0x01600135,(A1)
	move #50,A3 // MHz
	bra.s vp2
vp42:
	btst #STMODES,D7
	beq.s vp36
	move D7,D0
	and #7,D0
	beq.s vp38    // monochrome emulation on TV in interlaced
	bra.s vp2
vp36:
	btst #VERTFLAG,D7 // interlaced
	beq.s vp2     // not interlaced
vp38:
	bclr #0,1(A0) // number of odd lines
	bclr #0,7(A0) // begin used odd image DE
	bclr #0,9(A0) // end used odd image DE
	bra.s vp1
vp2:
	bset #0,1(A0) // number of even lines
	bset #0,7(A0) // begin used even image DE (else half-line)
	bset #0,9(A0) // end used even image DE (else half-line)
vp1:
	move A3,D0    // clock frequency in MHz
	movem.l (SP)+,D1-A3
	rts

init_videl: // modecode inside D0, frequency in Hz inside D1
            // ptr screen inside A0 (unchanged if < 0)
            // return inside D0 < 0 => no external frequency

	movem.l D1-A1,-(SP)
	move D1,D6 // frequency in MHz
	move SR,-(SP)
	OR #0x700,SR // lock IRQ
	bsr fix_stmodes
	move D0,D7
	move.l A0,D1
	lea 0xFFFF8200,A0 // VIDEL
	bsr wait_vbl
	lea params_line(A5),A1
	move.l (A1)+,0x82(A0)
	move.l (A1)+,0x86(A0)
	move.l (A1),0x8A(A0)
	lea params_frame(A5),A1
	move.l (A1)+,0xA2(A0)
	move.l (A1)+,0xA6(A0)
	move.l (A1),0xAA(A0)
	moveq #0,D0 // horizontal shift in words
	tst.l D1
	bmi.s iv29  // physical adress unchanged
	btst #VGA_FALCON,D7
	beq.s iv13
	btst #STMODES,D7
	bne.s iv13
	btst #ULTRA_VGA_FALCON,D7
	bne.s iv13
	btst #VESA_FALCON,D7
	bne.s iv13
	btst #HORFLAG2,D7
	bne.s iv13
	btst #OVERSCAN,D7
	beq.s iv13
	moveq #6,D2 // + 20 % in VGA 480 lines 80 columns
	moveq #0,D0
	move number_of_lines(A5),D0
	divu D2,D0
	mulu words_by_line(A5),D0 // overscan space not visible in VGA
	add.l D0,D1
	moveq #0,D0
	move words_by_line(A5),D0
	divu D2,D0
	ext.L D0
	add.l D0,D1
	sub D0,words_by_line(A5)
iv13:
	move.l D1,-(SP)
	move.b 1(SP),1(A0)   // high adress
	move.b 2(SP),3(A0)   // midle adress
	move.b 3(SP),0xD(A0) // low adress
	addq #4,SP
iv29:
	move D0,0xE(A0) // shift word horizontal scrolling
	bclr #0,0xA(A0) // internal clock
	move D7,D2
	and #7,D2
	btst #STMODES,D7
	beq iv9
	tst D2
	bne iv9 // couleur
	move.b 0xFFFF8006,D0 // read video connector if 2 colors or monochrome
	and.b #0xC0,D0
	bne iv9 // <> ST monochrome
	clr.l 0x84(A0) //               *** MONO ***
	moveq #8,D1 // predivisor clock video direct (pixel duration)
	btst #VERTFLAG,D7 // interlaced
	beq.s iv28
	bset #1,D1 // interlaced
iv28:
	btst #HORFLAG2,D7
	bne.s iv25
	btst #OVERSCAN,D7
	bne.s iv26
	bra.s iv23
iv25:
	btst #OVERSCAN,D7
	bne.s iv23
	btst #CLOCK_FORCED,D7
	beq.s iv37 // internal clock not forced
	bsr test_clock_40
	bmi.s iv46 // bus acceleration, 40 MHz or more
iv37:
	bset #0,0xA(A0) // external clock 38 MHz
iv46:
	move #0x180,0xC0(A0) // monochrome monitor
	move.b #2,0x60(A0)   // ST haute
	move words_by_line(A5),0x10(A0) // words by line
	move D1,0xC2(A0)     // predivisor clock video (pixel duration)
	bra iv1
iv26:
	btst #CLOCK_FORCED,D7
	bne.s iv45           // internal clock forced
	bsr test_clock_32
	bmi.s iv45           // OK
	bset #0,0xA(A0)      // try external clock 32 MHz on TV (CT2, CT60, etc...)
iv45:
	move #0x180,0xC0(A0) // monochrome monitor: clock 32 MHz
	move.b #2,0x60(A0)   // ST haute
	move words_by_line(A5),0x10(A0) // words by line
	move D1,0xC2(A0)     // predivisor clock video (pixel duration)
	bra iv1
iv23:
	btst #VERTFLAG,D7
	bne.s iv26           // interlaced
	btst #CLOCK_FORCED,D7
	bne.s iv44           // internal clock forced
	bsr test_clock_32
	bmi.s iv44           // OK
	bset #0,0xA(A0)      // try external clock 32 MHz on TV (CT2, CT60, etc...)
iv44:
	move D1,0xC2(A0)     // predivisor clock video (pixel duration)
	move #0x80,0xC0(A0)  // monochrome monitor: clock 32 MHz
	move.b #2,0x60(A0)   // ST haute
	bra iv1
iv9:
	move words_by_line(A5),0x10(A0) // words by line
	moveq #0,D1     // clock /4
	btst #COL80,D7  // 80 columns
	beq.s iv2
	addq #4,D1      // clock /2
iv2:
	btst #VGA_FALCON,D7 //       *** VGA ***
	beq iv11
	addq #4,D1      // clock or clock /2
	btst #STMODES,D7
	beq.s iv30
	tst D2
	beq.s iv12      // ST monochrome emulation
	cmp #4,D2       // NTC 640 * 400 multisync
	beq.s iv12
	bra.s iv19
iv30:
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines 96, 112 & 128 columns
	beq.s iv18
	btst #VESA_FALCON,D7
	beq.s iv50 // <>128 columns
	cmp #60,D6
	beq.s iv18 // SVGA 60 MHz 768 lines in 128 columns with CT60 
	bra.s iv49
iv50:
	cmp #50,D6
	beq.s iv18 // SVGA 50 MHz 768 lines in 96 or 112 columns with CT60
iv49:
	btst #VERTFLAG,D7 // line double in VGA
	bne.s iv12
	bset #1,D1 // interlaced
	bra.s iv12
iv18:
	btst #VERTFLAG,D7 // line double in VGA
	beq.s iv12
iv19:
	bset #0,D1 // double line
iv12:
	move D1,0xC2(A0) // predivisor clock video (pixel duration)
	move #0x186,D0 // monitor VGA: clock 25.175 MHz
	btst #STMODES,D7
	beq.s iv40
	cmp #4,D2 // NTC 640 *400 multisync
	bne iv14
	move #0x182,D0 // clock 40 MHz normally
	bra iv14
iv40:
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines 96, 112 & 128 columns
	bne.s iv31
	btst #VESA_FALCON,D7 // SVGA 608 lines 96 & 112 columns
	bne.s iv24
	btst #HORFLAG2,D7 // VGA 112 columns
	beq iv14
	move #0x182,D0 // clock 32 MHz, SVGA 608 lines 96 columns
	bra iv47
iv31:
	move #0x182,D0 // clock 32 MHz
	btst #VESA_FALCON,D7
	bne.s iv32 // 128 columns
iv24:
	move #0x182,D0 // clock 32 MHz
	cmp #50,D6
	beq iv14 // SVGA 50 MHz 768 lines in 96 or 112 columns with CT60 (internal clock)
	btst #HORFLAG2,D7
	bne.s iv32 // SVGA 768 lines 112 columns with external clock 38 MHz
iv47:
	btst #CLOCK_FORCED,D7
	bne iv14 // internal clock forced
	bsr test_clock_32
	bmi iv14 // OK
	bset #0,0xA(A0) // try external clock 32 MHz on TV (CT2, CT60, etc...) 
	bra iv14
iv32:
	bsr test_clock_40
	bpl.s iv38
	btst #CLOCK_FORCED,D7
	beq.s iv39 // internal clock 40 MHz not forced
	bra iv14   // external clock 38 MHz possible whith bus acceleration at 40 MHz or more
//                    same in 256 colors > 80 columns or NTC
iv38:        // bus < 40 MHz: 256 colors need bandwidth -> use 32 MHz
	move D0,D2
	move D7,D0
	bsr test_256_ntc
	exg D0,D2
	tst D2
	bmi iv14 // no external clock if 256 colors and > 80 columns, or NTC
iv39:
	bset #0,0xA(A0) // external clock 38 MHz
	bra.s iv14
iv11:
	btst #PAL,D7 //             *** TV ***
	beq.s iv34
	bset #1,0xA(A0) // PAL 50 Hz
	bra.s iv35
iv34:
	bclr #1,0xA(A0) // NTSC 60 Hz
iv35:
	btst #STMODES,D7
	beq.s iv20
	tst D2
	beq.s iv21 // ST monochrome emulation
	bra.s iv8
iv20:
	btst #HORFLAG2,D7 // 120 columns on TV
	bne.s iv17
	btst #HORFLAG,D7 // 160 columns on TV
	beq.s iv10
iv17:
	addq #4,D1 // direct clock if 120 or 160 columns
iv10:
	btst #VERTFLAG,D7 // interlaced
	beq.s iv8
iv21:
	bset #1,D1 // interlaced
iv8:
	move D1,0xC2(A0) // predivisor clock video (pixel duration)
	move #0x181,D0 // clock 32 MHz
	btst #STMODES,D7
	bne.s iv42 // mode ST
	btst #HORFLAG2,D7 // 120 columns
	beq.s iv15
	move #0x186,D0 // clock 25.175 MHz (& predivisor /2 compteur line if direct clock)
	bra.s iv14
iv15:
	btst #COL80,D7
	beq.s iv42
	btst #HORFLAG,D7 // 160 columns
	beq.s iv42
	move #0x182,D0 // clock 32 MHz (& predivisor /2 compteur line if direct clock)
iv42:
	btst #CLOCK_FORCED,D7
	bne.s iv14 // internal clock forced
	bsr test_clock_32
	bmi.s iv14 // OK
	bset #0,0xA(A0) // try external clock 32 MHz on TV (CT2, CT60, etc...)
iv14:
	move D0,0xC0(A0) // clock & monitor
iv7:
	clr 0x66(A0) // 16 colors or mode ST
	move D7,D0 //                  *** COLORS ***
	and #7,D0
	cmp #4,D0
	bhi iv1 // more than 65536 colors
	bne.s iv3
	move #0x100,0x66(A0) // 65536 colors => no palette
	bra iv1
iv3:
	cmp #3,D0
	bne.s iv4
	move #0x10,0x66(A0) // 256 colors => extended palette
	bra iv1
iv4:
	cmp #2,D0 // 16 colors
	bne.s iv5
	btst #STMODES,D7
	beq iv1 // mode FALCON
	clr.b 0x60(A0) // 16 colors or ST basse
	bra.s iv22
iv5:
	cmp #1,D0 // 4 colors
	bne.s iv6
	move.b #1,0x60(A0) // 4 colors or ST moyenne
	btst #STMODES,D7
	beq.s iv16 // mode FALCON
iv22:
	btst #VGA_FALCON,D7
	beq.s iv16 // TV
	bset #0,D1 // line double VGA
iv16:
	move words_by_line(A5),0x10(A0) // words by line
	move D1,0xC2(A0) // predivisor clock video (pixel duration)
	bra.s iv1
iv6:
	move #0x400,0x66(A0) // 2 colors
	lea params_line(A5),A1
	move 8(A1),D0
	addq #8,D0
	btst #VGA_FALCON,D7
	beq.s iv33
	btst #ULTRA_VGA_FALCON,D7
	beq.s iv33
	btst #VESA_FALCON,D7
	beq.s iv33
	sub #16,D0
iv33:
	move D0,0x8A(A0) // stabilize
	bsr wait_vbl
	move 8(A1),0x8A(A0) // end used image DE ajusted
iv1:
	btst #0,0xA(A0) // external clock 38 MHz
	beq.s iv27 // no external clock
	bsr wait_vbl
	bmi.s iv36 // time-out
	move external_clock_frequency(A5),D0
	cmp #32,D0
	bcs.s iv43 // error, no external clock
	cmp #37,D6 // clock requested
	bcc.s iv48 // 38 MHz or more
	cmp #32,D0
	beq.s iv41
	bra.s iv43 // error
iv48:
	cmp #37,D0
	bcs.s iv43 // error, external clock < 37 MHz
	cmp #60,D6 // clock requested
	bcc.s iv41 // OK
	cmp #37,internal_clock_frequency(A5)
	bcs.s iv41 // OK, internal clock < 37 MHz & external clock > 37 MHz
	cmp internal_clock_frequency(A5),D0
	bcs.s iv41 // OK, external clock < internal clock & external clock > 37 MHz
iv43:
	moveq #-1,D0 // error
	bra.s iv36
iv27:
iv41:
	moveq #0,D0 // OK
iv36:
	move (SP)+,SR
	movem.l (SP)+,D1-A1
	tst.l D0
	rts
 
wait_vbl: // return time-out if D0 < 0

	movem.l D1-D2,-(SP)
	move SR,-(SP)
	move.l _frclock,D2
	move.l _hz_200,D1
	and #0xFBFF,SR // autorise IRQ VBL
wb1:
		moveq #0,D0
		cmp.l _frclock,D2 // VSYNC
		bne.s wb2
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #20,D0 // time-out 100 mS
	blt.s wb1
	moveq #-1,D0 // time-out
wb2:
	move (SP)+,SR
	movem.l (SP)+,D1-D2
	tst.l D0
	rts
 
test_clock_32: // return < 0 if bus at 16/32 MHz

	movem.l D0,-(SP)
	cmp #32,internal_clock_frequency(A5) // MHz
	seq.b D0
	ext.w D0
	movem.l (SP)+,D0
	rts

test_clock_36:

	movem.l D0,-(SP)
	cmp #36,internal_clock_frequency(A5) // MHz
	seq.b D0
	ext.w D0
	movem.l (SP)+,D0
	rts

test_clock_40:

	movem.l D0,-(SP)
	cmp #40,internal_clock_frequency(A5) // MHz
	scc.b D0
	ext.w D0
	movem.l (SP)+,D0
	rts

test_clock_50:

	movem.l D0,-(SP)
	cmp #50,internal_clock_frequency(A5) // MHz
	scc.b D0
	ext.w D0
	movem.l (SP)+,D0
	rts

fix_stmodes: //  modecode inside D0

	btst #STMODES,D0
	beq.s fst1
	move D1,-(SP)
	move D0,D1
	and #7,D1
	cmp #2,D1 // 16 colors
	bcc.s fst2
	bset #COL80,D0
	bra.s fst3
fst2:
	btst #VGA_FALCON,D0
	beq.s fst4
	bsr test_clock_40
	bpl.s fst4 // no bus at 40 MHz or more
	cmp #4,D1  // mode multisync ST NTC VGA
	bne.s fst4
	bclr #COL80,D0
	bclr #VERTFLAG,D0
	bra.s fst3
fst4:
	and #0xFFF0,D0
	or #2,D0 // ST basse 16 colors
fst3:
	move (SP)+,D1
fst1:
	rts

width_points: // modecode inside D0
              // return width of point in mm/1000 inside D0

	movem.l D1/D7,-(SP)
	move D0,D7
	move #744,D0
	btst #COL80,D7
	beq.s wp4
	lsr #1,D0
wp4:
	btst #STMODES,D7
	beq.s wp6
	move.b 0xFFFF8006,D1 // read connector video
	and.b #0xC0,D1
	bne.s wp9 // <> monitor ST monochrome
	btst #HORFLAG2,D7
	beq wp2
	btst #OVERSCAN,D7
	bne.s wp2
	bra.s wp3
wp9:
	btst #VGA_FALCON,D7
	beq.s wp2
	move D7,D1
	and #7,D1
	cmp #4,D1 // NTC 640 * 400 multisync
	bne.s wp2
	bsr test_clock_40
	bpl.s wp2
	lsr #1,D0
	bra.s wp2
wp6:
	btst #VGA_FALCON,D7
	beq.s wp5
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines 96, 112 & 128 columns
	bne.s wp8
	btst #VESA_FALCON,D7 // SVGA 608 lines 96 & 112 columns
	bne.s wp7
	btst #HORFLAG2,D7
	beq.s wp2
	bra.s wp3
wp8:
	btst #VESA_FALCON,D7
	beq.s wp7
	mulu #5,D0
	divu #8,D0 // /1.6 in 128 columns SVGA
	bra.s wp2
wp7:
	btst #HORFLAG2,D7
	bne.s wp3
	mulu #5,D0
	divu #6,D0 // /1.2 in 96 columns SVGA
	bra.s wp2
	wp3:mulu #5,D0
	divu #7,D0 // /1.4 in 112 columns (S)VGA and ST monochrome
	bra.s wp2
	wp5:btst #HORFLAG2,D7
	bne.s wp1
	btst #HORFLAG,D7
	beq.s wp2
	lsr #1,D0
	bra.s wp2
wp1:
	mulu #2,D0
	divu #3,D0 // /1.5 in 60 or 120 columns
wp2:
	movem.l (SP)+,D1/D7
	rts

height_points: // modecode inside D0
 // return high of point in mm/1000 inside D0

	movem.l D1/D7,-(SP)
	move D0,D7
	move #744,D0
	cmp #390,number_of_lines(A5)
	bcs.s hp3
	lsr #1,D0
hp3:
	cmp #780,number_of_lines(A5)
	bcs.s hp2
	lsr #1,D0
hp2:
	btst #STMODES,D7
	beq.s hp5
	move.b 0xFFFF8006,D1 // read connector video
	and.b #0xC0,D1
	bne.s hp1 // <> monitor ST monochrome
	btst #HORFLAG2,D7
	bne.s hp6
	btst #OVERSCAN,D7
	beq.s hp1
hp6:
	mulu #5,D0
	divu #7,D0 // /1.4 in 112 columns ST monochrome
	bra.s hp1
hp5:
	btst #VGA_FALCON,D7
	beq.s hp1
	btst #ULTRA_VGA_FALCON,D7 // SVGA 768 lines 96, 112 & 128 columns
	bne.s hp4
	btst #VESA_FALCON,D7 // SVGA 608 lines 96 & 112 columns
	beq.s hp1
	mulu #4,D0
	divu #5,D0 // /1.25 in SVGA
	bra.s hp1
hp4:
	mulu #5,D0
	divu #8,D0 // /1.6 in SVGA
hp1:
	movem.l (SP)+,D1/D7
	rts

init_linea_vars: // modecode inside D0

	movem.l D0-D2/D7/A0-A2,-(SP)
	move D0,D7
	moveq #0,D0
	move D7,D0
	bsr size_screen       // => words_by_line(A5) & number_of_lines(A5)
	.short 0xA000         // lineA
	move D7,D1
	and #7,D1 //  0: monochrome, 1: 4 colors, 2: 16 colors, 3: 256 colors, 4: 65536 colors
//               planes: 1              2            4             8              16
	moveq #0,D0
	bset D1,D0
	move D0,(A0)          // number of planes
	move words_by_line(A5),D0
	lsr D1,D0
	asl #4,D0 // *16
	move D0,dev_tab(A0)
	subq #1,dev_tab(A0)  // width pixels workstation info
	moveq #0,D1
	move number_of_lines(A5),D1
	move D1,dev_tab+2(A0)
	subq #1,dev_tab+2(A0) // high pixels workstation info
	move D1,v_cel_vt(A0)  // high screen in bits VDI ESC
	divu v_cel_ht(A0),D1  // high character VDI ESC
	subq #1,D1
	move D1,v_cel_my(A0)  // line of cursor maxi VDI ESC
	move D0,v_rez_hz(A0)  // width in bits VDI ESC
	lsr #3,D0
	move D0,v_cel_mx(A0)
	subq #1,v_cel_mx(A0)  // column of cursor maxi VDI ESC
	mulu (A0),D0          // planes line A
	move D0,v_lin_wr(A0)  // bytes/line de read line A
	move D0,bytes_ln(A0)  // bytes/line VDI ESC
	mulu v_cel_ht(A0),D0  // high character VDI ESC
	move D0,v_cel_wr(A0)  // bytes/line de characters VDI ESC
	move D7,D0
	bsr width_points
	move D0,dev_tab+6(A0) // width of point in mm/1000
	move D7,D0
	bsr height_points
	move D0,dev_tab+8(A0) // high of point in mm/1000
	btst #STMODES,D7
	beq.s ivv1
	btst #VGA_FALCON,D7
	beq.s ivv1
	and #7,D7
	cmp #4,D7             // NTC 640 * 400 multisync
	bne.s ivv1
	move.b #2,sshiftmd
ivv1:
	movem.l (SP)+,D0-D2/D7/A0-A2
	rts

test_256_ntc: // modecode inside D0
              // return D0 < 0 => external clock not possible (pb access time ram ?)

	btst #STMODES,D0
	bne.s tn4
	btst #VGA_FALCON,D0
	beq.s tn4
	btst #ULTRA_VGA_FALCON,D0
	bne.s tn6
	btst #VESA_FALCON,D0
	beq.s tn4
	bra.s tn7
tn6:
	btst #VESA_FALCON,D0
	bne.s tn5
tn7:
	btst #HORFLAG2,D0
	beq.s tn4
tn5:
	btst #COL80,D0
	beq.s tn2
	and #7,D0
	cmp #3,D0 // 256 colors
	bcs.s tn4
	bra.s tn3
tn2:
	and #7,D0
	cmp #4,D0 // NTC
	bcs.s tn4
tn3:
	moveq #-1,D0
	bra.s tn1
tn4:
	moveq #0,D0
tn1:
	rts

tab_shift:
	.byte 2,4,2,2,2,0,0,4 // TV 40 columns 32 MHz
	.byte 1,4,1,1,1,0,0,4 // TV 80 columns 32 MHz
	.byte 1,4,1,1,0,0,0,0 // TV 160 columns 32 MHz
	.byte 1,4,1,1,1,0,0,0 // TV 60 columns 25.175 MHz
	.byte 1,4,1,1,0,0,0,0 // TV 120 columns 25.175 MHz
	.byte 4,0,0,0,0,0,4,4 // MONO 80 columns 32 MHz
	.byte 4,0,0,0,0,0,0,0 // MONO 112 columns 38 MHz external clock
	.byte 1,4,1,1,1,0,0,4 // VGA 40 columns 25.175 MHz
	.byte 1,4,1,1,0,0,0,4 // VGA 80 columns 25.175 MHz
	.byte 1,4,1,1,1,0,0,0 // VGA 56 columns 32 MHz 
	.byte 1,4,1,1,0,0,0,0 // VGA 112 columns 32 MHz
	.byte 1,4,1,1,1,0,0,0 // ULTRA VGA & VESA 48 columns 32 MHz
	.byte 1,4,1,1,0,0,0,0 // ULTRA VGA & VESA 96 columns 32 MHz
	.byte 1,4,1,1,1,0,0,0 // ULTRA VGA & VESA 56 columns 38 MHz
	.byte 1,4,1,1,0,0,0,0 // ULTRA VGA & VESA 112 columns 38 MHz
	.byte 1,4,1,1,1,0,0,1 // ULTRA VGA 64 columns 38 MHz external clock
	.byte 1,4,1,1,0,0,0,0 // ULTRA VGA 128 columns 38 MHz external clock
	.byte 1,4,1,1,1,0,0,0 // ULTRA VGA 48 columns 50 MHz CT60
	.byte 1,4,1,1,0,0,0,0 // ULTRA VGA 96 columns 50 MHz CT60
	.byte 1,4,1,1,1,0,0,0 // ULTRA VGA 56 columns 50 MHz CT60
	.byte 1,4,1,1,0,0,0,0 // ULTRA VGA 112 columns 50 MHz CT60
	.byte 1,4,1,1,1,0,0,1 // ULTRA VGA 64 columns 60 MHz CT60, external clock
	.byte 1,4,1,1,0,0,0,0 // ULTRA VGA 128 columns 60 MHz CT60, external clock

tab_offset_begin_de:
	.byte 158,25,64,48,30,0, 0,17 // TV 40 columns 32 MHz
	.byte 172,16,76,60,40,0, 0,16 // TV 80 columns 32 MHz
	.byte  98,12,50,42,37,0, 0, 0 // TV 160 columns 32 MHz
	.byte 176,17,83,67,49,0, 0, 0 // TV 60 columns 25.175 MHz
	.byte 106,13,56,48,43,0, 0, 0 // TV 120 columns 25.175 MHz
	.byte  21, 0, 0, 0, 0,0,15,19 // MONO 80 columns 32 MHz
	.byte  21, 0, 0, 0, 0,0, 0, 0 // MONO 112 columns 38 MHz external clock
	.byte 178,17,85,69,51,0, 0,13 // VGA 40 columns 25.175 MHz
	.byte 108,13,60,52,47,0, 0,13 // VGA 80 columns 25.175 MHz
	.byte 175,18,82,66,48,0, 0, 0 // VGA 56 columns 32 MHz
	.byte 105,14,57,49,44,0, 0, 0 // VGA 112 columns 32 MHz
	.byte 184,19,91,75,57,0, 0, 0 // ULTRA VGA & VESA 48 columns 32 MHz
	.byte 114,15,66,58,53,0, 0, 0 // ULTRA VGA & VESA 96 columns 32 MHz
	.byte 184,19,91,75,57,0, 0, 0 // ULTRA VGA & VESA 56 columns 38 MHz external clock
	.byte 114,15,66,58,53,0, 0, 0 // ULTRA VGA & VESA 112 columns 38 MHz external clock
	.byte 176,18,83,67,49,0, 0,49 // ULTRA VGA 64 columns 38 MHz external clock
	.byte 106,14,58,50,45,0, 0, 0 // ULTRA VGA 128 columns 38 MHz external clock
	.byte 178,18,85,69,51,0, 0, 0 // ULTRA VGA 48 columns 50 MHz CT60
	.byte 108,14,60,52,47,0, 0, 0 // ULTRA VGA 96 columns 50 MHz CT60
	.byte 180,17,85,69,51,0, 0, 0 // ULTRA VGA 56 columns 50 MHz CT60
	.byte 110,13,60,52,47,0, 0, 0 // ULTRA VGA 112 columns 50 MHz CT60
	.byte 176,18,83,67,49,0, 0,49 // ULTRA VGA 64 columns 60 MHz CT60, external clock
	.byte 106,14,58,50,45,0, 0, 0 // ULTRA VGA 128 columns 60 MHz CT60, external clock

tab_offset_end_de:
	.byte  76,18,33,17,-1,0,0,10 // TV 40 columns 32 MHz
	.byte 101, 8,29,13,-7,0,0, 8 // TV 80 columns 32 MHz
	.byte  38, 5,11, 3,-2,0,0, 0 // TV 160 columns 32 MHz
	.byte 103, 5,36,20, 2,0,0, 0 // TV 60 columns 25.175 MHz
	.byte  40, 6,17, 9, 0,0,0, 0 // TV 120 columns 25.175 MHz
	.byte  13, 0, 0, 0, 0,0,4, 7 // MONO 80 columns 32 MHz
	.byte   9, 0, 0, 0, 0,0,0, 0 // MONO 112 columns 38 MHz external clock
	.byte 128,10,38,22, 0,0,0, 6 // VGA 40 columns 25.175 MHz
	.byte  65, 6,21,13, 8,0,0, 6 // VGA 80 columns 25.175 MHz
	.byte 129,11,35,19,-3,0,0, 0 // VGA 56 columns 32 MHz 
	.byte  66, 7,18,10, 5,0,0, 0 // VGA 112 columns 32 MHz
	.byte 138,12,44,28, 6,0,0, 0 // ULTRA VGA & VESA 48 columns 32 MHz 
	.byte  75, 8,27,19,14,0,0, 0 // ULTRA VGA & VESA 96 columns 32 MHz
	.byte 138,12,44,28, 6,0,0, 0 // ULTRA VGA & VESA 56 columns 38 MHz external clock
	.byte  75, 8,27,19,14,0,0, 0 // ULTRA VGA & VESA 112 columns 38 MHz external clock
	.byte 130,11,36,20,-2,0,0, 0 // ULTRA VGA 64 columns 38 MHz external clock
	.byte  67, 7,19,11, 6,0,0,-2 // ULTRA VGA 128 columns 38 MHz external clock
	.byte 128,11,38,22, 0,0,0, 0 // ULTRA VGA 48 columns 50 MHz II & CT60
	.byte  65, 7,21,13, 8,0,0, 0 // ULTRA VGA 96 columns 50 MHz CT60
	.byte 130,10,38,22, 0,0,0, 0 // ULTRA VGA 56 columns 50 MHz CT60
	.byte  67, 6,21,13, 8,0,0, 0 // ULTRA VGA 112 columns 50 MHz CT60
	.byte 130,11,36,20,-2,0,0, 0 // ULTRA VGA 64 columns 60 MHz CT60, external clock
	.byte  67, 7,19,11, 6,0,0,-2 // ULTRA VGA 128 columns 60 MHz CT60, external clock 

	.align 2

 // VIDEO INFOS LIGNE >>>>>
 //         _______________         __
 //         |<-----L----->|         |  VIDEO, DISPLAY ENABLE (used image)
 // ________|             |_________|
 //       <C>             <D>
 // _     ___________________      ___
 // |     |                 |     |    BLANK (screen)
 // |_____|                 |_____|
 //     <A>                 <B>
 // ___ _______________________ ______
 //   |T|                     | |      SYNCHRO LINE
 //   |_|                     |_|                    A,B,C,D,L,P,T in nS

 //   <------------P---------->        Video clock H in nS
 // 
 //                                              D:unused
 //                     H*100  T*100  B*100  A*100  D*100  C*100   L*100   P*100   clock      points
tab_time_PAL32:   .long 3125,470000,150000,514500,665500,600000,4000000,6400000 //  32 MHz     640/1280
tab_time_PAL25:   .long 3972,470000,150000,514500,726190,726190,3813120,6400000 //  25.175 MHz 960
tab_time_NTSC32:  .long 3104,460500,174500,514500,646900,600000,3973120,6369520 //  32.2 MHz   640/1280
tab_time_NTSC25:  .long 3972,470000,150000,514500,695710,726190,3813120,6369520 //  25.175 MHz 960
tab_time_VGA25:   .long 3972,381000, 64000,191000,     0,     0,2542080,3178000 //  25.175 MHz 640
tab_time_VGA32:   .long 3125,115000, 24000,361000,     0,     0,2800000,3300000 //  32 MHz     896
tab_time_VGA36:   .long 2777,381000,110000,198808,     0,     0,2488192,3178000 //  36 MHz     896
tab_time_VGA40:   .long 2500,381000,215000,342000,     0,     0,2240000,3178000 //  40 MHz     896
tab_time_UVGA32:  .long 3125,115000, 24000,391000,     0,     0,2400000,2930000 //  32 MHz     768
tab_time_UVGA36:  .long 2777,115000, 97632,464632,     0,     0,2132736,2810000 //  36 MHz     768
tab_time_UVGA40:  .long 2500,115000,204000,571000,     0,     0,1920000,2810000 //  40 MHz     768
tab_time_UVGA50:  .long 2000,172300, 98500,236300,     0,     0,1536000,2043100 //  50 MHz     768
tab_time_UVGA38:  .long 2633,115000, 24000,391000,     0,     0,2359168,2889168 //  38 MHz     896
tab_time_UVGA50B: .long 2000,115000, 67000,280000,     0,     0,1792000,2254000 //  50 MHz     896
tab_time_VVGA38:  .long 2633,115000, 24000,391000,     0,     0,2696192,3226192 //  38 MHz     1024
tab_time_VVGA60:  .long 1666,172300, 98500,196900,     0,     0,1705984,2173684 //  60 MHz     1024
tab_time_NTCVGA40:.long 2500,100000,     0,250000,     0,     0,3200000,3550000 //  40 MHz     640 NTC multisync
tab_time_MONO32:  .long 3125,250000,200000,350000,     0,     0,2000000,2800000 //  32 MHz     640
tab_time_MONO38:  .long 2633,250000,170000,320832,     0,     0,2359168,3100000 //  38 MHz     896
tab_time_MONO_O:  .long 3125,250000,150000,300000,     0,     0,2400000,3100000 //  32 MHz     768

 // VIDEO INFOS TRAME >>>>>
 //                nbre lines,end BLANK,beg BLANK,beg DE,end DE,top frame
tab_frame_PAL:    .short  625,      613,       47,   127,   527,      619 //  50 Hz 200 lines PAL SECAM
tab_frame_NTSC:   .short  525,      513,       22,    77,   477,      519 //  60 Hz 200 lines NTSC
tab_frame_VGA:    .short 1049,     1023,       63,    63,  1023,     1045 //  60 Hz 480 lines VGA
tab_frame_NTCVGA: .short  889,      863,       63,    63,   863,      885
tab_frame_VESA:   .short 1243,     1237,       21,    21,  1237,     1239 //  56 Hz 608 lines VESA (60 with clock 36/40 MHz)
tab_frame_UVGA:   .short  797,      787,       19,    19,   787,      789 //  86/77 Hz 768 lines ULTRA VGA 8514A interlaced
tab_frame_UVGA_NI:.short 1643,     1601,       65,    65,  1601,     1631 //  60 Hz 768 lines ULTRA VGA NI
tab_frame_MONO:   .short 1001,        0,        0,    67,   867,      999 //  71 Hz 400 lines SM124
tab_frame_MONO_O: .short 1243,        0,        0,    27,  1147,     1241 //  52 Hz 560 lines SM124

 