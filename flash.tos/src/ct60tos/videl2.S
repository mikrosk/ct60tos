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

	.globl	boot_screen
	.globl	detect_supervidel
	.globl	fix_mono_shift

#include "vars.h"

#define measure_frame 0x3EC
#define measure_line  0x3F0
#define measure_clock 0x3F4
#define vbl_count     0x3F8
#define count_measure 0x3FA
#define modecode      0x184C

#define WIDTH  320          // Videl screen the clock measure runs on
#define HEIGHT 240
#define IKBD_WAIT 60        // 300 ms in 200 Hz ticks, what TOS waits after its reset

boot_screen:

	move.l #0x8000,D0                         // instruction cache
	movec.l D0,CACR
	move.w #0x2300,SR                         // enable interrupts
	
	move.l A0,-(SP)                           // earliest CT60 code in the boot
	move.l phystop,A0                         // that any of this can reach, so
	move.l #-1,sv_present(A0)                 // set the variables up here
	clr.l sv_xbios_entry(A0)
	clr.l old_v_bas_ad(A0)
	move.l #-1,sdram_size(A0)
	clr.l ct60_info_shown(A0)
	clr.l sdram_warning(A0)
	move.l (SP)+,A0

	bsr fix_modecode
	bsr boot_video
	moveq #1,D0                               // the jsr to here overwrites TOS's
	rts                                       // moveq #1,D0, the next cartscan bit#
	
fix_modecode:

	movem.l D1/D2,-(SP)
	move.w modecode,D0
	and.w #0x1FF,D0                           // valid bits
	move.w D0,D2                              // save NVRAM mode (for VGA-change test)
	and.w #7,D2
	moveq #0,D1
	move.b 0xFFFF8006,D1
	lsr.w #6,D1                               // 0:ST nomo, 1:ST col, 2:VGA, 3:TV
	tst.w D2                                  // monochrome?
	bne.s .not_mono
	bset #3,D0                                // set COL80
.not_mono:
	cmp.w #2,D1                               // VGA?
	bne.s .no_vga
	bclr #6,D0                                // no OVERSCAN on VGA
	cmp.w #4,D2                               // hicolor+vga?
	bne.s .no_vga
	bclr #3,D0                                // clear COL80
.no_vga:
	move.w D0,modecode
	movem.l (SP)+,D1/D2
	rts

fix_mono_shift:                              // Replaces "move.w #0x400,0xFFFF8266"
	movem.l D0-D2,-(SP)
	bsr .wait_vbl_8266
	clr.w 0xFFFF8266
	bsr .wait_vbl_8266
	move.w #0x400,0xFFFF8266                  // 2 colors
	movem.l (SP)+,D0-D2
	rts
.wait_vbl_8266:
	move.l _frclock,D0                        // VBL frame counter
	move.l _hz_200,D1                         // 200 Hz time base
.wv8266:
		cmp.l _frclock,D0
		bne.s .wv8266_end                // a VBL occured
		move.l _hz_200,D2
		sub.l D1,D2
		cmp.l #20,D2                      // ~100 ms time-out
		blt.s .wv8266
.wv8266_end:
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

boot_video:

	movem.l D0-A6,-(SP)
	moveq #0,D7
	move.b 0xFFFF8006,D7
	lsr.w #6,D7             // 0:ST mono, 1:ST col, 2:VGA, 3:TV
	bsr detect_supervidel
	bne.s .sv_video         // a SuperVidel makes its own timing
	bsr videl_screen
	bsr ikbd_keys
	bra.s .clocks
.sv_video:
	bsr ikbd_keys
	move.l _sysbase,A0      // header ROM
	move.l 0x24(A0),A0      // kbshift
	moveq #0xF,D0
	and.b (A0),D0
	cmp.b #2,D0             // left shift alone: boot as if no SuperVidel
	bne.s .clocks           // were fitted
	bsr videl_screen
	bsr set_external_clock  // the board is still known here: no clock measure
	move.l phystop,A0
	clr.l sv_present(A0)    // what every later detect_supervidel returns
	bra.s .clocks_set
.clocks:
	bsr set_external_clock
.clocks_set:
	lea.l 0xFFFF8200,A0     // VIDEL
	bclr #0,0xA(A0)         // internal clock
	movem.l (SP)+,D0-A6
	rts

/* Program the Videl for a black 320x240 truecolor screen at 0x10000, or
 * 640x400 on a mono monitor (D7 = monitor type): measure_clock_videl works
 * from the timing registers, so there has to be a mode running.
 */
videl_screen:

	movem.l D0-D5/A0-A1,-(SP)
	lea 0x10000,A0
	tst.w D7
	beq .v7                 // monochrome
	move.l A0,A1
	move.w #38399,D0        // 154KB for test videl clock
.v9:
		clr.l (A1)+
	dbf D0,.v9
	move.w SR,-(SP)
	or.w #0x700,SR          // no IRQ
	move.l A0,-(SP)         // adress screen
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
	move.b 1(SP),1(A0)      // adress high
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
	bra .v1
.v7:
	move.l A0,A1
	move.w #7999,D0         // 32KB mono for test videl clock
.v8:		clr.l (A1)+
	dbf D0,.v8
	move.w SR,-(SP)
	or.w #0x700,SR          // no IRQ
	move.l A0,-(SP)         // adress screen
	lea.l 0xFFFF8200,A0     // VIDEL
	lea.l videl_mono_640_400(PC),A1  
	move.l (A1)+,0x82(A0)   // hht,hbb
	move.l (A1)+,0x86(A0)   // hbe,hdb
	move.l (A1)+,0x8A(A0)   // hde,hss
	move.w (A1)+,0xA2(A0)   // vft
	move.l (A1)+,0xA4(A0)   // vbb,vbe
	move.l (A1)+,0xA8(A0)   // vdb,vde
	move.w (A1)+,0xAC(A0)   // vss
	move.b 1(SP),1(A0)      // adress high
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
.v1:
	movem.l (SP)+,D0-D5/A0-A1
	rts

/* Reset the IKBD again, now with interrupts enabled, and wait as long as TOS
 * waits after its own reset.  A real IKBD answers a reset with a make code
 * for every key still held, within about 100 ms.  TOS sends its reset with
 * interrupts masked, so the ACIA overruns and those keys never reach kbshift;
 * after this they do, for test_tests and the key checks in init_sdram.
 */
ikbd_keys:

	movem.l D0-D2/A0-A2,-(SP)
	pea ikbd_reset(PC)
	move.w #1,-(SP)         // bytes - 1
	move.w #25,-(SP)        // Ikbdws
	trap #14
	addq.w #8,SP
	move.l _hz_200,D2
	add.l #IKBD_WAIT,D2
.ikbd_wait:
		bsr test_tests
		move.l _hz_200,D1
	cmp.l D2,D1
	blt.s .ikbd_wait
	movem.l (SP)+,D0-D2/A0-A2
	rts

ikbd_reset:
	.byte 0x80,0x01
	
set_external_clock:

	movem.l D0-D2/A0-A1,-(SP)
	lea.l 0xFFFF8200,A0     // VIDEL
	bsr detect_supervidel   // SuperVidel present ?
	beq.s .no_supervidel    // no => measure VIDEL clocks
	bclr #0,0xA(A0)         // SuperVidel: force internal (VGA) clock, skip measure
	move.l cookie,D1        // build _FRQ=25 / _FRE=0 cookies
	beq.s .sv_done          // no cookie jar
	move.l D1,A1
.sv_find_cookie:
		tst.l (A1)
		beq.s .sv_cookie_free
		addq.w #8,A1
	bra.s .sv_find_cookie
.sv_cookie_free:
	move.l 4(A1),12(A1)     // _FRQ internal clock = 25 MHz (VGA)
	move.l #0x5F465251,(A1)+
	move.l #25,(A1)+
	clr.l (A1)
	move.l 4(A1),12(A1)     // _FRE external clock = 0 (none)
	move.l #0x5F465245,(A1)+
	clr.l (A1)+
	clr.l (A1)
.sv_done:
	movem.l (SP)+,D0-D2/A0-A1
	rts
.no_supervidel:
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

detect_supervidel:
	move.l A0,-(SP)
	move.l phystop,A0
	move.l sv_present(A0),D0
	bpl.s .sv_answer         // 0 or 1: asked already
	bsr.s sv_probe
	move.l phystop,A0
	move.l D0,sv_present(A0)
.sv_answer:
	move.l (SP)+,A0
	tst.b D0
	rts

/* Read SV_CTRL with a bus error handler in place; D0 comes back 1 or 0.
 * Safe this early because init_060 leaves DTT0/ITT0 at 0x807FE040, which makes
 * everything from 0x80000000 up cache inhibited and precise, so an unclaimed
 * address faults synchronously.
 */
sv_probe:
	move.w SR,-(SP)
	or.w #0x0700,SR         // mask interrupts
	move.l A0,-(SP)
	move.l A1,-(SP)
	movec.l vbr,A0
	move.l 8(A0),-(SP)      // save bus error vector
	lea .sv_buserr(PC),A1
	move.l A1,8(A0)         // install temp handler (PC-relative => relocatable)
	move.l SP,A1            // SP marker to unwind the exception frame
	moveq #1,D0             // assume present
	nop
	tst.b 0x80010000        // probe SuperVidel SV_CTRL
	nop
	bra.s .sv_restore
.sv_buserr:
	move.l A1,SP            // bus error => discard 060 access frame
	moveq #0,D0             // SuperVidel absent
.sv_restore:
	movec.l vbr,A0
	move.l (SP)+,8(A0)      // restore bus error vector
	move.l (SP)+,A1
	move.l (SP)+,A0
	move.w (SP)+,SR
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
