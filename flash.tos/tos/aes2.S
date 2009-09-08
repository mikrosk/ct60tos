/* TOS 4.04 AES patch for Eiffel POWER OFF alert for the CT60 board
*                     color icons and GEM dispatcher on Coldfire
*  Didier Mequignon 2004 February, e-mail: aniplay@wanadoo.fr
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

	.globl det_evnt_multi,patch_tran_check,patch_gr_cicon,patch_set_video
#ifdef COLDFIRE
	.globl det_aes
	.globl _dsptch,_savestate,_switchto,_gotopgm,_psetup
	.globl _far_mchange,_far_bchange,_forkq
#include "fire.h"
#endif

#include "vars.h"

//#define DEBUG
	
#define saddr        0x08
#define daddr        0x0C
#define mask         0x10
#define splanes      0x14
#define dplanes      0x16
#define width        0x18
#define height       0x1A

#ifdef COLDFIRE

#define _savea0      0x979C
#define srsave       0x97A0
#define savsr        0x97A2
#define psetsr       0x97A4
#define dspstk       0x9A26
#define gstksave     0x9A3A
#define gstack       0x9AAE
#define _gl_bdelay   0x9C7A
#define _gl_bclick   0x9CE2
#define _gl_dclick   0x9D9A
#define _gl_bdesired 0x9DB0
#define _gl_bpend    0x9E14
#define _gl_btrue    0xA3D0
#define _gl_button   0xA3F2
#define _fpcnt       0xB5FC
#define _fpt         0xF7B4
#define _rlr         0xF7BA
#define _indisp      0xF8CE
#define _disp        0xE21D90
#define _bchange     0xE25B76
#define _mchange     0xE25CE0

#define NFORKS       0x60

/* AES PD struct */
#define PD_UDA       0x08
#define PD_LDADDR    0x18

/* BDOS PD struct */
#define P_TBASE      0x08 // address of TEXT segment
#define P_BBASE      0x18 // address of BSS segment
#define P_BLEN       0x1C // length of BSS
                
	.chip 68060
#endif
	.text

alert_power_en:
	.asciz "[2][ |Do you want cut the|power of your computer?][Yes|No]" 

alert_power_fr:
	.asciz "[2][ |Voulez vous ‚teindre|votre ordinateur ?][Oui|Non]" 

#ifdef COLDFIRE
#ifdef DEBUG

debug1:	.ascii "AES dsptch"
	.byte 13,10,0
debug2:	.ascii "AES switchto"
	.byte 13,10,0
debug3:	.asciz "AES gotopgm 0x"
debug4:	.ascii "AES psetup"
	.byte 13,10,0
debug5:	.asciz "AES #0x"

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
	
#endif // DEBUG
#endif // COLDFIRE
	
	.align 2
	
det_evnt_multi:

	movem.l D0-D2/A0-A2,-(SP)
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
	jsr 46(A0)               // drivers PCI in flash, call event_aes
	movem.l (SP)+,D0-D2/A0-A2
.no_pci_drivers:
	move.l phystop,A1
	cmp.l #0xCAFEFADE,power_flag(A1)
	bne.s .no_power_off
	clr.l power_flag(A1)
	movem.l D0-A5,-(SP)
	link A6,#-48
	pea.l -48(A6)                                       // buffer
	move.w #48,-(SP)                                    // size
	clr.w -(SP)                                         // start
	clr.w -(SP)                                         // read
	move.w #46,-(SP)                                    // NVMaccess
	trap #14
	lea.l 12(SP),SP
	lea.l -48(A6),A0                                    // buffer
	move.b 6(A0),D0                                     // language
	unlk A6
	lea.l alert_power_en(PC),A0
	cmp.b #2,D0                                         // french
	bne.s .no_french
	lea.l alert_power_fr(PC),A0	
.no_french:                                      
	pea.l (A0)
	move.w #1,-(SP)
	jsr 0xE22A68                                        // form_alert
	addq.l #6,SP
#ifndef COLDFIRE
	cmp.w #1,D0                                         // delay
	bne.s .cancel
	clr.b 0xFA800000                                    // power off
	dc.w 0xF800,0x01C0,0x2700
.cancel:
#endif
	movem.l (SP)+,D0-A5
.no_power_off:
	swap D0
	clr.w D0
	swap D0
	rts
	
patch_tran_check:

	cmp.w #16,0x18(A6)       // nplanes
	bne.s .not_65K_colors
	jmp 0xE2E920
.not_65K_colors:
	cmp.w #32,0x18(A6)       // nplanes
	bne .not_16M_colors
	move.w 0x14(A6),D0       // W
	ext.l D0
	asr.l #4,D0              // /16
	muls 0x16(A6),D0         // H
	muls 0x18(A6),D0         // nplanes
	asr.l #1,D0
	move.w D0,-2(A6)         // no_longs
	move.l 0xC(A6),A1
	clr.w -6(A6)             // index
	bra .next_16M
.loop_16M:
		move.l (A1),D0
		cmp.l #0xFFFFFFFF,D0
		bne.s .not_white
		moveq #0,D0
		bra.s .inc_16M
.not_white:
		tst.l D0
		bne.s .not_black
		move.l #0xFFFFFF,D0
		bra.s .inc_16M
.not_black:
		bsr get_rgb        // 16M reversed
.inc_16M:
		move.l D0,(A1)+
		addq.w #1,-6(A6)   // index
.next_16M:
	move.w -6(A6),D0         // index
	cmp.w -2(A6),D0          // no_longs
	blt .loop_16M
.not_16M_colors:
	unlk A6
	rts
	
get_rgb:

	bsr reverse
	lea tab_rgb(PC),A0
	asl.l #2,D0
	move.l (A0,D0.w),D0
	rts
	
reverse:
 	move.l D3,-(SP) // save D3 since we clobber it
	move.l D0,D3    // D3 = source
	moveq #0,D1     // target bit position
	moveq #0,D0     // target
	moveq #31,D2    // source bit position
.dobit:
		btst D2,D3
		beq.s .nextbit
		bset D1,D0
.nextbit:
		addq.l #1,D1 // update target bit position
	subq.l #1,D2
	bpl.s .dobit    // dbra updates source bit position
	move.l (SP)+,D3 // restore d3
	rts
	
tab_rgb:
/*--- 16 standard colors */
	dc.l 0xffffff // 0 white
	dc.l 0xff0000 // 1 red
	dc.l 0x00ff00 // 2 green
	dc.l 0xffff00 // 3 yellow
	dc.l 0x0000ff // 4 blue
	dc.l 0xff00ff // 5 magenta
	dc.l 0x00ffff // 6 cyan
	dc.l 0xbbbbbb // 7 "low white"
	dc.l 0x888888 // 8 grey
	dc.l 0xaa0000 // 9 dark red
	dc.l 0x00aa00 // 10 dark green
	dc.l 0xaaaa00 // 11 dark yellow
	dc.l 0x0000aa // 12 dark blue
	dc.l 0xaa00aa // 13 dark magenta
	dc.l 0x00aaaa // 14 dark cyan
	dc.l 0x000000 // 15 black

/*--- 16 shades off gray */
	dc.l 0xffffff // white
	dc.l 0xeeeeee
	dc.l 0xdddddd
	dc.l 0xcccccc
	dc.l 0xbbbbbb
	dc.l 0xaaaaaa
	dc.l 0x999999
	dc.l 0x888888
	dc.l 0x777777
	dc.l 0x666666
	dc.l 0x555555
	dc.l 0x444444
	dc.l 0x333333
	dc.l 0x222222
	dc.l 0x111111
	dc.l 0x000000 // black

/*+
* HSV level 15 (90 hues)
*-*/
	dc.l 0xff0000 // red
	dc.l 0xff0011
	dc.l 0xff0022
	dc.l 0xff0033
	dc.l 0xff0044
	dc.l 0xff0055
	dc.l 0xff0066
	dc.l 0xff0077
	dc.l 0xff0088
	dc.l 0xff0099
	dc.l 0xff00aa
	dc.l 0xff00bb
	dc.l 0xff00cc
	dc.l 0xff00dd
	dc.l 0xff00ee

	dc.l 0xff00ff // magenta
	dc.l 0xee00ff
	dc.l 0xdd00ff
	dc.l 0xcc00ff
	dc.l 0xbb00ff
	dc.l 0xaa00ff
	dc.l 0x9900ff
	dc.l 0x8800ff
	dc.l 0x7700ff
	dc.l 0x6600ff
	dc.l 0x5500ff
	dc.l 0x4400ff
	dc.l 0x3300ff
	dc.l 0x2200ff
	dc.l 0x1100ff

	dc.l 0x0000ff // blue
	dc.l 0x0011ff
	dc.l 0x0022ff
	dc.l 0x0033ff
	dc.l 0x0044ff
	dc.l 0x0055ff
	dc.l 0x0066ff
	dc.l 0x0077ff
	dc.l 0x0088ff
	dc.l 0x0099ff
	dc.l 0x00aaff
	dc.l 0x00bbff
	dc.l 0x00ccff
	dc.l 0x00ddff
	dc.l 0x00eeff

	dc.l 0x00ffff // cyan
	dc.l 0x00ffee
	dc.l 0x00ffdd
	dc.l 0x00ffcc
	dc.l 0x00ffbb
	dc.l 0x00ffaa
	dc.l 0x00ff99
	dc.l 0x00ff88
	dc.l 0x00ff77
	dc.l 0x00ff66
	dc.l 0x00ff55
	dc.l 0x00ff44
	dc.l 0x00ff33
	dc.l 0x00ff22
	dc.l 0x00ff11

	dc.l 0x00ff00 // green
	dc.l 0x11ff00
	dc.l 0x22ff00
	dc.l 0x33ff00
	dc.l 0x44ff00
	dc.l 0x55ff00
	dc.l 0x66ff00
	dc.l 0x77ff00
	dc.l 0x88ff00
	dc.l 0x99ff00
	dc.l 0xaaff00
	dc.l 0xbbff00
	dc.l 0xccff00
	dc.l 0xddff00
	dc.l 0xeeff00

	dc.l 0xffff00 // yellow
	dc.l 0xffee00
	dc.l 0xffdd00
	dc.l 0xffcc00
	dc.l 0xffbb00
	dc.l 0xffaa00
	dc.l 0xff9900
	dc.l 0xff8800
	dc.l 0xff7700
	dc.l 0xff6600
	dc.l 0xff5500
	dc.l 0xff4400
	dc.l 0xff3300
	dc.l 0xff2200
	dc.l 0xff1100

/*+
* HSV level 11 (66 hues)
*-*/
	dc.l 0xbb0000 // red
	dc.l 0xbb0011
	dc.l 0xbb0022
	dc.l 0xbb0033
	dc.l 0xbb0044
	dc.l 0xbb0055
	dc.l 0xbb0066
	dc.l 0xbb0077
	dc.l 0xbb0088
	dc.l 0xbb0099
	dc.l 0xbb00aa

	dc.l 0xbb00bb // magenta
	dc.l 0xaa00bb
	dc.l 0x9900bb
	dc.l 0x8800bb
	dc.l 0x7700bb
	dc.l 0x6600bb
	dc.l 0x5500bb
	dc.l 0x4400bb
	dc.l 0x3300bb
	dc.l 0x2200bb
	dc.l 0x1100bb

	dc.l 0x0000bb // blue
	dc.l 0x0011bb
	dc.l 0x0022bb
	dc.l 0x0033bb
	dc.l 0x0044bb
	dc.l 0x0055bb
	dc.l 0x0066bb
	dc.l 0x0077bb
	dc.l 0x0088bb
	dc.l 0x0099bb
	dc.l 0x00aabb

	dc.l 0x00bbbb // cyan
	dc.l 0x00bbaa
	dc.l 0x00bb99
	dc.l 0x00bb88
	dc.l 0x00bb77
	dc.l 0x00bb66
	dc.l 0x00bb55
	dc.l 0x00bb44
	dc.l 0x00bb33
	dc.l 0x00bb22
	dc.l 0x00bb11

	dc.l 0x00bb00 // green
	dc.l 0x11bb00
	dc.l 0x22bb00
	dc.l 0x33bb00
	dc.l 0x44bb00
	dc.l 0x55bb00
	dc.l 0x66bb00
	dc.l 0x77bb00
	dc.l 0x88bb00
	dc.l 0x99bb00
	dc.l 0xaabb00

	dc.l 0xbbbb00 // yellow
	dc.l 0xbbaa00
	dc.l 0xbb9900
	dc.l 0xbb8800
	dc.l 0xbb7700
	dc.l 0xbb6600
	dc.l 0xbb5500
	dc.l 0xbb4400
	dc.l 0xbb3300
	dc.l 0xbb2200
	dc.l 0xbb1100

/*+
* HSV level 7 (42 hues)
*-*/
	dc.l 0x770000 // red
	dc.l 0x770011
	dc.l 0x770022
	dc.l 0x770033
	dc.l 0x770044
	dc.l 0x770055
	dc.l 0x770066

	dc.l 0x770077 // magenta
	dc.l 0x660077
	dc.l 0x550077
	dc.l 0x440077
	dc.l 0x330077
	dc.l 0x220077
	dc.l 0x110077

	dc.l 0x000077 // blue
	dc.l 0x001177
	dc.l 0x002277
	dc.l 0x003377
	dc.l 0x004477
	dc.l 0x005577
	dc.l 0x006677

	dc.l 0x007777 // cyan
	dc.l 0x007766
	dc.l 0x007755
	dc.l 0x007744
	dc.l 0x007733
	dc.l 0x007722
	dc.l 0x007711

	dc.l 0x007700 // green
	dc.l 0x117700
	dc.l 0x227700
	dc.l 0x337700
	dc.l 0x447700
	dc.l 0x557700
	dc.l 0x667700

	dc.l 0x777700 // yellow
	dc.l 0x776600
	dc.l 0x775500
	dc.l 0x774400
	dc.l 0x773300
	dc.l 0x772200
	dc.l 0x771100

/*+
* HSV level 4 (24 hues)
*-*/
	dc.l 0x440000 // red
	dc.l 0x440011
	dc.l 0x440022
	dc.l 0x440033

	dc.l 0x440044 // magenta
	dc.l 0x330044
	dc.l 0x220044
	dc.l 0x110044

	dc.l 0x000044 // blue
	dc.l 0x001144
	dc.l 0x002244
	dc.l 0x003344

	dc.l 0x004444 // cyan
	dc.l 0x004433
	dc.l 0x004422
	dc.l 0x004411

	dc.l 0x004400 // green
	dc.l 0x114400
	dc.l 0x224400
	dc.l 0x334400

	dc.l 0x444400 // yellow
	dc.l 0x443300
	dc.l 0x442200
	dc.l 0x441100

/*+
* Registers 254, 255
*-*/
	dc.l 0xffffff // white
	dc.l 0x000000
	
patch_set_video:

	move.w #3,-(SP)          // Logbase
	trap #14
	addq.l #2,SP
        	cmp.l #0x01000000,D0
        	bcs.s .no_pci_drivers2
	move.l #0x5F504349,D0
	lea 0xED0000,A0          // 128 KB
	cmp.l (A0),D0            // _PCI
	beq.s .pci_drivers2
	lea 0xEC0000,A0          // 192 KB
	cmp.l (A0),D0            // _PCI
	beq.s .pci_drivers2
	lea 0xEB0000,A0          // 256 KB
	cmp.l (A0),D0            // _PCI
	beq.s .pci_drivers2
	lea 0xEA0000,A0          // 320 KB
	cmp.l (A0),D0            // _PCI
	bne.s .no_pci_drivers2
.pci_drivers2:
	jsr 64(A0)               // set_video
	tst.w D0
	bmi.s .no_pci_drivers2
	rts
.no_pci_drivers2:
	link A6,#-0x42
	movem.l D4-D7/A5,-(SP)
	jmp 0xE48014             // TOS 4.04 set_video

#ifdef COLDFIRE

	dc.l 0x58425241          // XBRA
	dc.l 0x5F43465F          // _CF_
	dc.l 0x00E346A8          // TOS AES entry point

det_aes:

	cmp.w #0xC8,D0
	beq.s .a2
	cmp.w #0xC9,D0   // AES
	bne.s .a1
.a2:
	movem.l D0/A0,-(SP)
	move.l D1,A0
	move.l (A0),A0   // CONTRL
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug5(PC),A0
	bsr debug_display_string
	move.l (SP),A0
	move.w (A0),D0   // function
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,A0
#endif
	movem.l (SP)+,D0/A0
.a1:
	move.l det_aes-4(PC),-(SP)
	rts
	
#undef DEBUG

/****************************************************************
*								*
* _dsptch, called from lots of places to do context switching.	*
* We want to return to super from switchto (see below) by using	*
* an rte.  Return is already on stack, just push current sr...	*
* OR fix stack frame then push the sr if CPU uses long frames.	*
*								*
*****************************************************************/
_dsptch:
	tas.b _indisp            // be atomic
	.chip 5200
	beq.s dsp1               // if clear, enter with _indisp set
	rts                      // else just forget the whole thing
dsp1:
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug1(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	tst.w proc_type
	beq.s dsp2
	subq.l #2,SP             // bump up the stack pointer
	move.l 2(SP),(SP)        // move up the return address
	clr.w 4(SP)	
dsp2:
	clr.w -(SP)
	move.l D0,-(SP)
	move.w SR,D0
	move.w D0,4(SP)          // and finish the stack frame with SR
	move.l (SP)+,D0
	
/*
* Now save the context of the machine
*/
_savestate:
	move.l D0,-(SP)
	move.w SR,D0
	move.w D0,srsave         // save interrupts
	or.l #0x700,D0           // turn them off
	move.w D0,SR
	move.l (SP)+,D0
	move.l A0,_savea0
	move.l _rlr,A0           // Get the current PD
#ifdef DEBUG
	move.l A0,-(SP)
	move.l D0,-(SP)
	move.l D1,-(SP)
	lea 12(A0),A0
	moveq #7,D1
.display_p_name:
	move.b (A0)+,D0
	bsr debug_display_char
	subq.l #1,D1
	bpl.s .display_p_name
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l _rlr,A0           // get pd
	move.l 0x18(A0),D0       // pd->ldaddr is base page of program
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l 8(A0),D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w 28(A0),D0         // p_pid
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	move.l (SP)+,D1
	move.l (SP)+,D0
	move.l (SP)+,A0	
#endif	
	move.l 8(A0),A0          // Get the UDA from PD
	addq.l #2,A0
	movem.l D0-D7/A0-A7,(A0) // save everything
	move.l _savea0,A1
	move.l A1,32(A0)
	.chip 68060
	move.l USP,A1
	.chip 5200
	move.l A1,64(A0)
	lea dspstk,SP            // Load a dispatcher stack
	move.w srsave,D0
	move.w D0,SR             // Restore interrupts
	jsr _disp                // Go to the Sub dispatcher

/* ================================================================
* gemdisp.c:disp() determines who to run next, makes him rlr,
* then comes back to us to do the actual context switch
* ================================================================

*	For reference purposes
*	UDA
*	{
*		WORD	u_insuper;		// in supervisor flag
*		ULONG	u_regs[15];		// D0-D7,A0-A6
*		ULONG	*u_spsuper;		// supervisor stack
*		ULONG	*u_spuser;		// user stack
*		ULONG	u_super[STACK_SIZE];
*		ULONG	u_supstk;
*	} ;
*/
_switchto:
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug2(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	move.w SR,D0
	move.w D0,srsave
	or.l #0x700,D0           // no interrupts while on bogus stack!
	move.w D0,SR
	move.l _rlr,A0
	move.l 8(A0),A0          // Get the UDA
	addq.l #2,A0             // Points the D0 area	
	move.l 64(A0),A1         // Get the USP
	.chip 68060
	move.l A1,USP
	.chip 5200
	movem.l (A0),D0-D7/A0-A7 // Pull regs from uda
#ifdef DEBUG
	move.l D0,-(SP)
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
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l A1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif
	clr.b _indisp            // Can enter dispatcher now
	rte	

/****************************************************************
* _gotopgm:							*
*	Run an accessory and not giving him the basepage	*
*****************************************************************/
_gotopgm:
#ifdef DEBUG
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug3(PC),A0
	bsr debug_display_string
	move.l _rlr,A0           // get pd
	move.l 0x18(A0),A0       // pd->ldaddr is base page of program
	move.l 8(A0),D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	.chip 68060
	move.l USP,A0
	.chip 5200
	move.l A0,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
#endif
	move.l D0,-(SP)
	move.w SR,D0
	move.w D0,savsr          // save sr
	or.l #0x700,D0           // turn interrupts off
	move.w D0,SR
	move.l (SP)+,D0
#if 0
	move.l _rlr,A0           // get pd
	move.l PD_LDADDR(A0),A0  // pd->ldaddr is base page of program
	// set the user stack to the top of BSS for this process
	move.l P_BBASE(A0),A1
	add.l P_BLEN(A0),A1
	// push basepage and return address
	move.l A0,-(A1)
	move.l #_back,-(A1)
	.chip 68060
	move A1,USP	
	.chip 5200
#else
	.chip 68060
	move.l USP,A0
	.chip 5200
	cmp.l #0,A0
	bne.s .user_stack_ok
	lea ustack_aes,A0        // USP (add here, else crash !)
	.chip 68060
	move.l A0,USP
	.chip 5200
.user_stack_ok:
	move.l _rlr,A0           // get pd
	move.l PD_LDADDR(A0),A0  // pd->ldaddr is base page of program
#endif
	tst.w proc_type
	beq.s g_1
	clr.w -(SP)              // format
g_1:
	move.l P_TBASE(A0),-(SP) // get beg of text on our sp
	clr.w -(SP)              // reserve for SR
	move.l D0,-(SP)
	move.w savsr,D0          // get current irq's
	eor.l #0x2000,D0         // run him in user mode (SR = 0, IPL0)
	move.w D0,4(SP)          // SR
	move.l (SP)+,D0
	rte

/****************************************************************
*		VOID						*
*	psetup(p, codevalue)					*
*		PD		*p;				*
*		CODE		*codevalue;			*
*								*
*	Set up a process' stack frame in preparation        *
*	for an RTE that will start this process executing.	*
*****************************************************************/
_psetup:
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug4(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	move.w SR,D0
	move.w D0,psetsr         // save interrupts
	or.l #0x700,D0           // turn them off
	move.w D0,SR
	move.l 4(SP),A0          // *pd
	move.l 8(SP),D0          // val
	move.l PD_UDA(A0),A1     // A1 = pd->uda
	move.l 62(A1),A2         // A2 = uda->SUPSTK
	tst.w proc_type
	beq.s p_1
	clr.w -(A2)              // format
p_1:
	move.l D0,-(A2)          // predecrement and store val on stack
	move.w #0x2000,-(A2)     // predecrement and store status word
	move.l A2,62(A1)         // restore stack ptr
	move psetsr,D0
	move.w D0,SR             // restore interrupts
	rts

/****************************************************************
*
*	far_mchange
*
*	  called far with interrupts off
*	  d0 = xposition, d1 = yposition in absolute pixels
*****************************************************************/
_far_mchange:
	move.l SP,gstksave       // save stack
	lea gstack,SP
             lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP) // save regs that C will crunch
	move.w D1,-(SP)          // delta y
	move.w D0,-(SP)          // delta x
	move.l #_mchange,-(sp)
	bsr _forkq               // call forkq
	addq.l #8,SP
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	move.l gstksave,SP
	rts
	
/****************************************************************
*
*	far_bchange
*
*	  called far with d0 = button state
*	  interrupts should be off and in supervisor mode
*	  calls b_click
*****************************************************************/
_far_bchange:
	move.l SP,gstksave       // save stack, paranoid code
	lea gstack,SP
             lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP) // save regs that c will crunch
	move.w D0,_gl_button
	ext.l D0
	move.w _gl_btrue,D1
	ext.l D1
	cmp.l D1,D0              // if state != gl_btrue
	beq.s bout1              // no change and exit
	tst.w _gl_bdelay         // do we have to wait
	beq.s bout2
	move.w _gl_bdesired,D1
	ext.l D1	
	cmp.l D1,D0              // state == gl_bdesired
	bne.s bout3
	move.w _gl_bclick,D1
	addq.l #1,D1
	move.w D1,_gl_bclick     // gl_bclick++
	move.w _gl_bdelay,D1
	addq.l #3,D1
	move.w D1,_gl_bdelay     // gl_bdelay += 3
	bra.s bout3
bout2:	
	tst.w _gl_bpend          // if ( gl_bpend && state )
	beq.s bout4
	tst.w D0
	beq.s bout4
	moveq #1,D1
	move.w D1,_gl_bclick     // gl_bclick = 1
	move.w D0,_gl_bdesired   // gl_bdesired = state
	move.w _gl_dclick,D1
	move.w D1,_gl_bdelay
	bra.s bout3		
bout4:
	move.w D0,-(SP)          // save the d0
	move.w #1,-(SP)
	move.w D0,-(SP)
	pea _bchange
	bsr _forkq
	add.l #8,SP
	move.w (SP)+,D0          // restore d0	
bout3:
	move.w D0,_gl_btrue      // gl_btrue = state	
bout1:
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	move.l gstksave,SP
	rts

/****************************************************************/

_forkq:
	link.w A6,#0
	move.l A5,-(SP)
	moveq #0,D0
	moveq #0,D1
	move.w _fpcnt,D1
	cmp.l #NFORKS,D1
	bge.s .fq1
	move.w _fpt,D0
	move.l D0,D1
	asl.l #3,D0
	move.l D0,A5
	add.l #0xBF2A+0x1F20,A5
	addq.l #1,D1
	cmp.l #NFORKS,D1
	bne.s .fq2
	moveq #0,D1
.fq2:
	move.w D1,_fpt
	move.l 8(A6),(A5)        // fcode
	move.l 12(A6),4(A5)      // fdata
	move.w _fpcnt,D1
	addq.l #1,D1
	move.w D1,_fpcnt
	moveq #1,D0
.fq1:
	move.l (SP)+,A5
	unlk a6
	rts	

#endif
