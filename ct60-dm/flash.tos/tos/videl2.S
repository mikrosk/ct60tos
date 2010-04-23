/* TOS 4.04 Videl patch for the CT60 board
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

	.globl	picture_boot

#include "vars.h"

#ifdef COLDFIRE
#include "fire.h"
#endif

//#define DEBUG

#define measure_frame 0x3EC
#define measure_line  0x3F0
#define measure_clock 0x3F4
#define vbl_count     0x3F8
#define count_measure 0x3FA
#define modecode      0x184C

#define WIDTH  320          // TGA uncompressed picture & screen 
#define HEIGHT 240
#define LOGO_CT60_WIDTH  15 // words
#define LOGO_CT60_HEIGHT 50 // lines
#define LOGO_MOT_WIDTH    4 // words
#define LOGO_MOT_HEIGHT  56 // lines

picture_boot:

#ifdef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug1(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#else
	move.l #0x8000,D0                         // instruction cache
	movec.l D0,CACR
#endif
	move.w #0x2300,SR                         // enable interrupts
	bsr fix_modecode
#ifndef COLDFIRE
	bsr screen_ntc_boot
#endif
	moveq #0,D0
	rts
	
fix_modecode:

	move.l D1,-(SP)
#ifdef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug2(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
	move.w modecode,D0
#ifdef COLDFIRE
	and.l #0x1FF,D0                           // valid bits
	moveq #0,D1                               // mono
#else
	and.w #0x1FF,D0                           // valid bits
	move.b 0xFFFF8006,D1
	lsr.w #6,D1                               // 0:ST nomo, 1:ST col, 2:VGA, 3:TV
#endif
	bclr #4,D0                                // VGA
#ifndef COLDFIRE
	cmp.w #2,D1                               // VGA
	bne.s .no_vga_monitor
	bset #4,D0                                // VGA
.no_vga_monitor:	
#endif
	moveq #7,D1	
#ifdef COLDFIRE
	and.l D0,D1                               // bits/pixel code
#else
	and.w D0,D1                               // bits/pixel code
#endif
	btst #7,D0                                // STMODES
	beq.s .normal_mode
	bclr #6,D0                                // no OVERSCAN with STMODES
#ifndef COLDFIRE
	cmp.w #3,D1
	bcs.s .st_modes
	bclr #7,D0                                // remove STMODES in 256 or 65K colors
	bra.s .normal_mode
.st_modes:
	tst.w D1
	bne.s .not_640x400
#endif
	bset #3,D0                                // COL80
	bclr #8,D0                                // VERTFLAG
	btst #4,D0                                // VGA
	bne.s .normal_mode
	bset #8,D0                                // VERTFLAG interlaced
#ifndef COLDFIRE
	bra.s .normal_mode
.not_640x400:
	cmp.w #1,D1
	bne.s .not_640x200
	bset #3,D0                                // COL80
	bra.s .x200
.not_640x200:
	bclr #3,D0                                // no COL80 
.x200:
	bset #8,D0                                // VERTFLAG double line
	btst #4,D0                                // VGA
	bne.s .normal_mode
	bclr #8,D0                                // VERTFLAG
#endif
.normal_mode:
	btst #4,D0                                // VGA
	beq.s .no_vga
	bclr #6,D0                                // no OVERSCAN in VGA
.no_vga:
	move.w D0,modecode
	move.l (SP)+,D1
	rts

#ifdef COLDFIRE

#ifdef DEBUG

debug1:	.ascii "Enable interrupts"
	.byte 13,10,13,13,0
debug2:	.ascii "Fix modecode"
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
	
#endif // DEBUG

#else  // ATARI

picture_build:                                         // target A0

	movem.l D0-D4/A0-A3,-(SP)
	lea pic_boot(PC),A1                       // source XIMG 65K colors 320 x 240
	cmp.w #1,(A1)                             // version
	bne.s .pb1                                // error
	cmp.w #WIDTH,12(A1)
	bne.s .pb1                                // error
	cmp.w #HEIGHT,14(A1)
	bne.s .pb1                                // error
	cmp.w #16,4(A1)                           // planes
	bne.s .pb1                                // error
	move.l #WIDTH*HEIGHT*2,-(SP)              // size picture in bytes
	move.w #WIDTH,-(SP)                       // words/line target
	move.w 14(A1),-(SP)                       // height
	move.w 12(A1),-(SP)                       // width
	move.w 6(A1),-(SP)                        // pattern
	move.w 4(A1),-(SP)                        // planes
	pea (A0)                                  // target = screen
	move.w 2(A1),D0                           // header size in words
	add.w D0,D0
	pea (A1,D0)                               // compressed data
	bsr decompress_img
	add.w #22,SP	
.pb1:
	lea pic_logo_ct60(PC),A1
	move.l A0,A3                              // target = screen
	add.l #(HEIGHT-LOGO_CT60_HEIGHT)*WIDTH*2,A3
	moveq #LOGO_CT60_HEIGHT-1,D1
.pb3:
		move.l A3,A2
		moveq #LOGO_CT60_WIDTH-1,D2
.pb4:
			move.w (A1)+,D0
			moveq #15,D3
.pb5:				
				btst D3,D0
				beq.s .pb6
				move.w #0xF800,(A2) // red
.pb6:				addq.w #2,A2
			dbf D3,.pb5
		dbf D2,.pb4
		add.w #WIDTH*2,A3
	dbf D1,.pb3	
	lea pic_logo_mot(PC),A1
	move.l A0,A3                              // target = screen
	add.l #(WIDTH-(LOGO_MOT_WIDTH*16))*2,A3
	moveq #LOGO_MOT_HEIGHT-1,D1
.pb7:
		move.l A3,A2
		moveq #LOGO_MOT_WIDTH-1,D2
.pb8:
			move.w (A1)+,D0
			moveq #15,D3
.pb9:				
				btst D3,D0
				beq.s .pb2
				move.w #0x001F,(A2) // blue
.pb2:
				addq.w #2,A2
			dbf D3,.pb9
		dbf D2,.pb8
		add.w #WIDTH*2,A3
	dbf D1,.pb7	
	movem.l (SP)+,D0-D4/A0-A3
	rts

decompress_img:

	link A6,#0
	movem.l D1-A5,-(SP)
	subq.w #1,22(A6)        // height in pixels
	bmi .error_img
	subq.w #1,18(A6)        // PATTERN_RUN counter
	bmi .error_img
	moveq #0,D6
	move.w 20(A6),D6        // width in pixels
	cmp.w #16,16(A6)        // planes
	bne .error_img
	lea store_ntc(PC),A1
	add.l D6,D6             // bytes/line screen
	move.w 22(A6),D4        // lines
	move.l 8(A6),A2         // source
	move.l 12(A6),D0        // target
	move.l D0,A4
	move.l D0,A3            // save target
	add.l D0,26(A6)         // + size = end target
	bra.s .loop_img
.error_img:
	moveq #-1,D0            // error
	bra .end_img	
.loop_img:
		move.l A3,A0     // save line target
		moveq #0,D3      // bytes/line counter
		moveq #0,D0      // counter line repeated
		moveq #1,D5      // counter byte color TC16
		tst.b (A2)       // if 0x0000FF => line repeated
		bne.s .next_bytes
		tst.b 1(A2)
		bne.s .next_bytes
		cmp.b #-1,2(A2)
		bne.s .next_bytes
		move.b 3(A2),D0  // number of lines repeated
		subq.w #1,D0
		addq.w #4,A2     // jump line header
.next_bytes:
		cmp.l 26(A6),A3  // end target
		bcc .end_img_ok
		move.w 20(A6),D7 // width in pixels
		and.b #0xF0,D7   // 16 pixels alignment
		move.w 20(A6),D2
		and.w #0xF,D2
		beq.s .alignment_ok
		add.w #16,D7
.alignment_ok:
		moveq #0,D2
		cmp.w D7,D3      // end of line
		bge .end_of_line
		moveq #0,D1
		move.b (A2)+,D1
		beq.s .pattern_run // if 0 => pattern-run
		cmp.b #128,D1
		beq.s .bit_string  // if 128 => bit-string
		// solid-run
		bclr #7,D1         // clear b7
		sne.b D2
		subq.w #1,D1
		bmi.s .next_bytes
.loop_solid_run:
			move.b D2,D7
			jsr (A1)
		dbf D1,.loop_solid_run
		bra.s .next_bytes
.pattern_run:
		move.b (A2)+,D2  // number of repeats pattern-run
		move.l A2,A5     // save start adr pattern-run
		subq.w #1,D2
		bmi.s .next_bytes
.loop_pattern_run:
			move.l A5,A2     // adr start pattern-run
			move.w 18(A6),D1 // pattern-run counter
.loop_pattern_run_2:
				move.b (A2)+,D7 // pattern-run byte
				jsr (A1)
			dbf D1,.loop_pattern_run_2
		dbf D2,.loop_pattern_run      // pattern-run counter
		bra.s .next_bytes
.bit_string:
		move.b (A2)+,D2 // bytes to read
		subq.w #1,D2
		bmi.s .next_bytes
.loop_bit_string:
			move.b (A2)+,D7 // byte transfer
			jsr (A1)
		dbf D2,.loop_bit_string
		bra.s .next_bytes
.end_of_line:
		move.w 24(A6),D2 // width target in words
		add.l D2,D2      // bytes
		add.l D2,12(A6)  // begin line
		move.l 12(A6),A4 // new target
		move.l A4,A3
		subq.w #1,D0     // repeat line ?
		bmi.s .next_line
		// copy line decompressed
.loop_copy_line:
			move.l A0,A5  // restore adr target
			move.w D6,D1  // bytes/ligne target
			subq.w #1,D1
.loop_copy_line_2:
				move.b (A5)+,(A3)+
			dbf D1,.loop_copy_line_2    // byte counter
			add.l D2,A4   // next line target
			move.l A4,A3  // new target
			subq.w #1,D4  // next line
		dbmi D0,.loop_copy_line    // repeat counter
		bmi.s .end_img_ok
		move.l A4,12(A6) // fix target
.next_line:
		cmp.l 26(A6),A3  // end target
		bcc.s .end_img_ok
	subq.w #1,D4            // next line
	bpl .loop_img
.end_img_ok:
	moveq #0,D0             // OK
.end_img:
	movem.l (SP)+,D1-A5
	unlk A6
	rts
	
store_ntc:

	subq.w #1,D5            // byte counter NTC
	ble.s .first_bytes
	cmp.w 20(A6),D3         // width in pixels
	bcc.s .no_end_of_line
	move.b D7,(A3)+
.no_end_of_line:
	moveq #1,D5             // byte counter NTC for 2 bytes
	addq.w #1,D3            // pixel counter
	rts
.first_bytes:
	cmp.w 20(A6),D3         // width in pixels
	bcc.s .ret_ntc
	move.b D7,(A3)+
.ret_ntc:
	rts
	
test_tests:

	move.l _sysbase,A0      // header ROM
	move.l 0x24(A0),A0      // kbshift
	move.b (A0),D0
	and.b #0xF,D0
	cmp.b #0xF,D0           // ALT-CTRL-LSHIFT-RSHIFT
	bne.s .no_tests
	cmp.l #0xFA52235F,0x00ED0000
	bne.s .no_tests
	lea 0x00E00030,A6
	jmp 0x00ED0004          // tests in flash
.no_tests:
	rts

screen_ntc_boot:                     // 320 * 240 * 65K colors */

	movem.l D0-A6,-(SP)
	lea 0x10000,A0
	moveq #0,D7
	move.b 0xFFFF8006,D7
	lsr.w #6,D7             // 0:ST nomo, 1:ST col, 2:VGA, 3:TV
	beq .v7                 // monochrome
	move.l A0,A1
	move.w #38399,D0        // 154KB for test videl clock
.v9:
		clr.l (A1)+
	dbf D0,.v9
	move.w SR,-(SP)
	or.w #0x700,SR          // no IRQ
	move.l A0,-(SP)         // screen address
	lea.l 0xFFFF8200,A0     // VIDEL
	move.w #HEIGHT*2,D1
	lea.l videl_tv_320_240(PC),A1  
	cmp.w #2,D7             // VGA
	bne.s .v2               // TV
	lea.l videl_vga_320_240(PC),A1
	add.w D1,D1
.v2:
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
	cmp.w #2,D7
	bne.s .v3               // TV
	move.w D0,D3            // vbe
	move.w D1,D2            // vbb
.v3:
	movem.w D2/D3,0xA4(A0)  // vbb,vbe
	movem.w D0/D1,0xA8(A0)  // vdb,vde
	move.w (A1)+,0xAC(A0)   // vss
	move.b 1(SP),1(A0)      // high address
	move.b 2(SP),3(A0)      // middle
	move.b 3(SP),0xD(A0)    // low
	addq.w #4,SP
	clr.w 0xE(A0)           // offset for next line (in words)
	bclr #0,0xA(A0)         // internal clock
	move.w #WIDTH,0x10(A0)  // words/line
	cmp.w #2,D7             // VGA
	beq.s .v4               // VGA
	btst #5,modecode+1      // PAL
	beq.s .v5
	bset #1,0xA(A0)         // PAL 50 Hz
	bra.s .v4
.v5:
	bclr #1,0xA(A0)         // NTSC 60 Hz
.v4:
	move.w (A1)+,0xC2(A0)   // vco, pred video clock (pixel)
	move.w (A1),0xC0(A0)    // vco_hi, clock and monitor
	move.w #0x100,0x66(A0)  // 65536 colors => no palette
	clr.l 0xFFFF9800        // black border
	move.w (SP)+,SR
	bsr set_external_clock
	lea 0x40000,A0          // screen buffer
	cmp.l #0x58494D47,0x00ED0000 // XIMG picture/demo code
	bne.s .v11
	move.l A0,-(SP)         // screen address
	lea.l 0xFFFF8200,A0     // VIDEL
	move.b 1(SP),1(A0)      // high address
	move.b 2(SP),3(A0)      // middle
	move.b 3(SP),0xD(A0)    // low
	move.l (SP)+,A0         // screen address
	jsr 0xED0004            // picture/demo in flash
	lea.l 0xFFFF8200,A0     // VIDEL
	bra.s .v10
.v11:
	bsr picture_build
	move.l A0,-(SP)         // screen address
	lea.l 0xFFFF8200,A0     // VIDEL
	move.b 1(SP),1(A0)      // high address
	move.b 2(SP),3(A0)      // middle
	move.b 3(SP),0xD(A0)    // low
	addq.w #4,SP
.v10:
	move.l _hz_200,D2
	add.l #400,D2           // tempo 2 S
.v6:
		bsr test_tests
		move.l _hz_200,D1
	cmp.l D2,D1
	blt.s .v6
	bra.s .v1
.v7:	
	move.l A0,A1
	move.w #7999,D0         // 32KB mono for test videl clock
.v8:		clr.l (A1)+
	dbf D0,.v8
	move.w SR,-(SP)
	or.w #0x700,SR          // no IRQ
	move.l A0,-(SP)         // screen address
	lea.l 0xFFFF8200,A0     // VIDEL
	lea.l videl_mono_640_400(PC),A1  
	move.l (A1)+,0x82(A0)   // hht,hbb
	move.l (A1)+,0x86(A0)   // hbe,hdb
	move.l (A1)+,0x8A(A0)   // hde,hss
	move.w (A1)+,0xA2(A0)   // vft
	move.l (A1)+,0xA4(A0)   // vbb,vbe
	move.l (A1)+,0xA8(A0)   // vdb,vde
	move.w (A1)+,0xAC(A0)   // vss
	move.b 1(SP),1(A0)      // high address
	move.b 2(SP),3(A0)      // middle
	move.b 3(SP),0xD(A0)    // low
	addq.w #4,SP
	clr.w 0xE(A0)           // offset for next line (in words)
	bclr #0,0xA(A0)         // internal clock
	move.w 2(A1),0xC0(A0)   // vco_hi, clock and monitor
	move.b #2,0x60(A0)      // ST hight
	move.w #0x28,0x10(A0)   // words/line
	move.w (A1)+,0xC2(A0)   // vco, pred video clock (pixel)
	move.w (SP)+,SR
	bsr set_external_clock
.v1:
	bclr #0,0xA(A0)         // internal clock
	movem.l (SP)+,D0-A6
	rts
	
set_external_clock:

	movem.l D0-D2/A0-A1,-(SP)
	lea.l 0xFFFF8200,A0     // VIDEL
	move.w 0xC0(A0),D0      // vco_hi
	move.w D0,D2
	bclr #2,D0              // 32 MHz
	move.w D0,0xC0(A0)
	bclr #0,0xA(A0)         // internal clock
	bsr measure_clock_videl
	move.l cookie,D1
	beq .external_clock_ok
	move.l D1,A1
.find_cookie:
		tst.l (A1)
		beq.s .cookie_free
		addq.w #8,A1
	bra.s .find_cookie
.cookie_free:
	move.l 4(A1),12(A1)     // copy size
	move.l #0x5F465251,(A1)+// _FRQ
	move.l D0,(A1)+
	move.w D0,D1            // internal clock
	clr.l (A1)
	bset #0,0xA(A0)         // external clock
	bsr measure_clock_videl
	move.l 4(A1),12(A1)     // copy size
	move.l #0x5F465245,(A1)+// _FRE
	move.l D0,(A1)+
	clr.l (A1)
	cmp.w #2,D7             // VGA
	beq.s .internal_clock_ok
	cmp.w #32,D1            // 32 MHz internal clock
	bls.s .internal_clock_ok
	cmp.w #32,D0            // 32 MHz
	beq.s .external_clock_ok
.internal_clock_ok:
	bclr #0,0xA(A0)         // internal clock
.external_clock_ok:
	move.w D2,0xC0(A0)      // restore vco_hi
	movem.l (SP)+,D0-D2/A0-A1
	rts
	
measure_clock_videl:                 // return value in MHz
                        
	movem.l D1-A6,-(SP)
	clr.l measure_frame     // nS
	clr.l measure_line      // nS * 100
	clr.l measure_clock     // nS * 100
	clr.w vbl_count
	move.w SR,-(SP)
	or.w #0x700,SR          // no IRQ
	lea irq_vbl_measure(PC),A0
	move.l 0x70,A4
	move.l A0,0x70
	lea irq_timer_b_measure(PC),A0
	move.l 0x120,A5
	move.l A0,0x120
	lea irq_timer_c_measure(PC),A0
	move.l 0x114,A6
	move.l A0,0x114
	move.w (SP)+,SR
	moveq #0,D1
	move.l _hz_200,D2
.wait_measure:
		bsr test_tests
		move.l _hz_200,D0
		sub.l D2,D0
		cmp.l #100,D0           // time-out
		bge.s .timeout_measure
	move.l measure_clock,D1
	beq.s .wait_measure
.timeout_measure:
	move.l A4,0x70
	move.l A5,0x120
	move.l A6,0x114
	moveq #0,D0
	tst.l D1
	beq.s .no_clock
	move.l #100000,D0
	divu D1,D0
	ext.l D0
	addq.w #1,D0
	bclr #0,D0
.no_clock:
	movem.l (SP)+,D1-A6
	rts

irq_vbl_measure:	

	movem.l D0-D2/A0,-(SP)
	move.w SR,-(SP)
	or.w #0x700,SR          // no IRQ
	tst.w vbl_count
	bne.s .no_first_vbl
	lea 0xFFFFFA01,A0       // MFP
	bclr #0,6(A0)           // IERA
	bclr #0,0xA(A0)         // IPRA
	bclr #0,0xE(A0)         // ISRA
	clr.b 0x1A(A0)          // TBCR stop timer B
	move.b #10,0x20(A0)     // TBDR
	move.b #1,0x1A(A0)      // TBCR prediv /4 IRQ TIMER B at each 16.275 uS
	                        // 16.275 uS = (10*4)/(2.4576*10^6)
	bset #0,6(A0)           // IERA
	bset #0,0x12(A0)        // IMRA
	clr.w count_measure
	bra .end_vbl
.no_first_vbl:
	move.w count_measure,D0
	beq.s .no_measure
	mulu #16275,D0          // time in nS of a frame 
	move.l D0,measure_frame
	move.w 0xFFFF82A2,D1    // VFT
	lsr.w #1,D1             // number of lines
	divu D1,D0              // time in nS of a line
	mulu #100,D0            // * 100
	move.l D0,measure_line
	lsr.l #1,D0             // /2
	move.w 0xFFFF8282,D1    // HHT
	addq.w #2,D1            // time of a line, video counter
	cmp.w #128,D1
	bcc.s .high_hht
	asl.w #4,D1
	bra.s .div_1_clock
.high_hht:
	move.w 0xFFFF82C2,D2    // VCO pred clock
	btst #2,D2              // /2
	bne.s .div_2_clock
	btst #3,D2
	bne.s .div_2_clock      // /1
	add.w D1,D1             // /4
.div_2_clock:
	add.w D1,D1
.div_1_clock:
	divu D1,D0
	swap D0
	tst.w D0
	beq.s .no_rest
	add.l #0x10000,D0
.no_rest:
	swap D0
.no_measure:
	move.w D0,measure_clock+2
	lea 0xFFFFFA01,A0       // MFP
	bclr #0,0x12(A0)        // IMRA
	bclr #0,6(A0)           // IERA
	bclr #0,0xA(A0)         // IPRA
	bclr #0,0xE(A0)         // ISRA
	clr.b 0x1A(A0)          // TBCR stop timer B
.end_vbl:
	addq.w #1,vbl_count
	move.w (SP)+,SR
	movem.l (SP)+,D0-D2/A0
	addq.l #1,_frclock
	rte

irq_timer_b_measure:

	addq.w #1,count_measure
	bclr #0,0xFFFFFA0F      // MFP ISRA
	rte
	
irq_timer_c_measure:

	addq.l #1,_hz_200
	bclr #5,0xFFFFFA11      // MFP ISRB
	rte

//	       nb_h  BK  BK   DE  DE  top  nb_v  BK   BK  DE   DE   top   
//	       hht   hbb  hbe   hdb  hde  hss  vft   vbb   vbe  vdb   vde   vss
videl_vga_320_240:
	.short 0xC6,0x8D,0x15,0x2AC,0x91,0x96,0x419,0x3FF,0x3F,0x3F,0x3FF,0x415,5,0x186 // 25 MHz
videl_tv_320_240:
	.short 0xFE,0xCB,0x27,0x03A,0x9B,0xD8,0x271,0x265,0x2F,0x57,0x237,0x26B,0,0x181 // 32 MHz
videl_mono_640_400:
	.short 0x1A,0x00,0x00,0x20F,0x0C,0x14,0x3E9,0x000,0x00,0x43,0x363,0x2E7,8,0x180 // 32 MHz

pic_logo_mot:
	.short 0x0000,0x0000,0x3800,0x0000 
	.short 0x0000,0x000F,0xFFF0,0x0000 
	.short 0x0000,0x007F,0xFFFE,0x0000 
	.short 0x0000,0x01FC,0x003F,0x8000 
	.short 0x0000,0x07C0,0x0007,0xE000 
	.short 0x0000,0x0F00,0x0001,0xF000 
	.short 0x0000,0x3C10,0x0010,0x7C00 
	.short 0x0000,0x7818,0x0018,0x1C00 
	.short 0x0000,0xE018,0x0018,0x0F00 
	.short 0x0001,0xC038,0x0018,0x0700 
	.short 0x0003,0x8038,0x003C,0x0380 
	.short 0x0007,0x003C,0x003C,0x01C0 
	.short 0x0007,0x007C,0x003C,0x00E0 
	.short 0x000E,0x007C,0x007E,0x0070 
	.short 0x001C,0x007E,0x007E,0x0070 
	.short 0x001C,0x00FE,0x007E,0x0038 
	.short 0x0018,0x00FE,0x00FE,0x0038 
	.short 0x0038,0x00FF,0x00FF,0x001C 
	.short 0x0030,0x00FF,0x00FF,0x001C 
	.short 0x0070,0x01FF,0x00FF,0x000C 
	.short 0x0070,0x01FF,0x01FF,0x800E 
	.short 0x0060,0x01FF,0x81FF,0x800E 
	.short 0x0060,0x03FF,0x81FF,0x8006 
	.short 0x00E0,0x03FF,0x83FF,0xC006 
	.short 0x00E0,0x03FF,0xC3FF,0xC006 
	.short 0x00C0,0x03FF,0xC3FF,0xC007 
	.short 0x00C0,0x07FF,0xC7FF,0xC007 
	.short 0x00C0,0x07FF,0xE7FF,0xE007 
	.short 0x00C0,0x07FF,0xE7FF,0xE007 
	.short 0x00C0,0x0F83,0xE7C3,0xE007 
	.short 0x00C0,0x0F00,0xEF00,0xF007 
	.short 0x00E0,0x0E00,0xFE00,0xF006 
	.short 0x00E0,0x1E00,0x7E00,0x7006 
	.short 0x0060,0x1C00,0x3C00,0x7806 
	.short 0x0060,0x1C00,0x3C00,0x380E 
	.short 0x0060,0x3800,0x1800,0x380E 
	.short 0x0070,0x3800,0x1800,0x1C0C 
	.short 0x0030,0x3800,0x1000,0x1C1C 
	.short 0x0038,0x3000,0x0000,0x1C1C 
	.short 0x0038,0x7000,0x0000,0x0C38 
	.short 0x001C,0x7000,0x0000,0x0E38 
	.short 0x001C,0x7000,0x0000,0x0E70 
	.short 0x000E,0x0000,0x0000,0x0070 
	.short 0x0007,0x0000,0x0000,0x00E0 
	.short 0x0003,0x0000,0x0000,0x01C0 
	.short 0x0003,0x8000,0x0000,0x0380 
	.short 0x0001,0xC000,0x0000,0x0700 
	.short 0x0000,0xF000,0x0000,0x0E00 
	.short 0x0000,0x7800,0x0000,0x1C00 
	.short 0x0000,0x3C00,0x0000,0x7800 
	.short 0x0000,0x0F00,0x0001,0xF000 
	.short 0x0000,0x07C0,0x0007,0xC000 
	.short 0x0000,0x01F8,0x003F,0x8000 
	.short 0x0000,0x007F,0xFFFE,0x0000 
	.short 0x0000,0x000F,0xFFF0,0x0000 
	.short 0x0000,0x0000,0xFC00,0x0000 

pic_logo_ct60:                                                                                                                          
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0001,0xFC27,0xFFFF,0x000E,0x03E0,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x000F,0x07E7,0x8F8F,0x0078,0x0E38,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x001C,0x01E7,0x0F87,0x03E0,0x1E3C,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0038,0x00E6,0x0F83,0x0780,0x1C1C,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0078,0x0064,0x0F81,0x0F00,0x3C1E,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x00F8,0x0064,0x0F81,0x1F00,0x3C1E,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x00F0,0x0020,0x0F80,0x1E00,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x3FF0,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000 
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x3C78,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x7C7C,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x7C3E,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x7C3E,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x7C3E,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x00F0,0x0000,0x0F80,0x7C3E,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x00F8,0x0000,0x0F80,0x7C3E,0x3C1E,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0078,0x0020,0x0F80,0x3C3E,0x3C1E,0x0000,0x0000,0x0000,0x0000,0x0000 
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x003C,0x0060,0x0F80,0x3C3C,0x1C1C,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x001E,0x00C0,0x0F80,0x1E38,0x1E3C,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x000F,0x0300,0x1FC0,0x0E70,0x0E38,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0001,0xFC00,0x7FF0,0x03E0,0x03E0,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000 
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000 
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x003F,0xFE00,0x0F00,0x0000,0x0000,0x007C,0x8000,0x0000,0x0000,0x007F,0xF000,0x0000,0x0000,0x0000,0x0000
	.short 0x000F,0x0E00,0x0700,0x0000,0x0000,0x00C7,0x8000,0x0000,0x0000,0x001E,0x3800,0x0000,0x0002,0x0000,0x0000
	.short 0x000F,0x0200,0x0700,0x0000,0x0000,0x0181,0x8000,0x0000,0x0000,0x001E,0x1C00,0x0000,0x0006,0x0000,0x0000
	.short 0x000F,0x1200,0x0700,0x0000,0x0000,0x0180,0x8000,0x0000,0x0000,0x001E,0x1C00,0x0000,0x000E,0x0000,0x0000 
	.short 0x000F,0x103F,0x0703,0xE0F0,0x79E0,0x01C0,0x8F1E,0x7BC0,0x787B,0xC01E,0x1C0F,0x00F0,0x1F9F,0x83C3,0xDE00
	.short 0x000F,0x30E1,0x8706,0x739C,0x3BF0,0x01F8,0x070E,0x3CE1,0xCC3F,0xC01E,0x3839,0xC39C,0x618E,0x0E61,0xFE00
	.short 0x000F,0xF0E1,0xC70C,0x730C,0x3C70,0x00FF,0x070E,0x3861,0x8639,0xC01F,0xF030,0xC30C,0x608E,0x0C31,0xCE00
	.short 0x000F,0x30E1,0xC71C,0x770E,0x3870,0x007F,0x870E,0x3873,0xFE38,0x001E,0x3C70,0xE70E,0x7C0E,0x1FF1,0xC000
	.short 0x000F,0x1007,0xC71C,0x070E,0x3870,0x000F,0xC70E,0x3873,0xBE38,0x001E,0x1E70,0xE70E,0x3F0E,0x1DF1,0xC000
	.short 0x000F,0x1039,0xC71C,0x070E,0x3870,0x0103,0xC70E,0x3873,0x8038,0x001E,0x1E70,0xE70E,0x0F8E,0x1C01,0xC000
	.short 0x000F,0x0061,0xC71C,0x070E,0x3870,0x0181,0xC70E,0x3873,0x8038,0x001E,0x1E70,0xE70E,0x438E,0x1C01,0xC000
	.short 0x000F,0x00E1,0xC70E,0x130C,0x3870,0x0181,0xC71E,0x3861,0xC238,0x001E,0x1E30,0xC30C,0x618E,0x4E11,0xC000 
	.short 0x000F,0x00E3,0xC70F,0x239C,0x3870,0x01C3,0x83EE,0x3CE1,0xFC38,0x001E,0x3C39,0xC39C,0x710F,0x8FE1,0xC000
	.short 0x003F,0xC07D,0xCF83,0xC0F0,0x7CF8,0x013E,0x03CF,0x3BC0,0x787E,0x007F,0xF00F,0x00F0,0x5E07,0x03C3,0xF000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x3800,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x3800,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x3800,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	.short 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x7E00,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000

#include "pic_boot.S"

#endif // COLDFIRE

