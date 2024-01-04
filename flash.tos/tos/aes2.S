/* TOS 4.04 AES patch for Eiffel POWER OFF alert for the CT60 board
*                     color icons and GEM dispatcher on Coldfire
*  Didier Mequignon 2004-2011, e-mail: aniplay@wanadoo.fr
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

#include "vars.h"

#undef DEBUG
	
#define saddr        0x08
#define daddr        0x0C
#define mask         0x10
#define splanes      0x14
#define dplanes      0x16
#define width        0x18
#define height       0x1A


	.text

alert_power_en:
	.asciz "[2][ |Do you want cut the|power of your computer?][Yes|No]" 

alert_power_fr:
	.asciz "[2][ |Voulez vous ‚teindre|votre ordinateur ?][Oui|Non]" 

	
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
.no_pci_drivers:
	movem.l (SP)+,D0-D2/A0-A2
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
	cmp.w #1,D0                                         // delay
	bne.s .cancel
	clr.b 0xFA800000                                    // power off
	dc.w 0xF800,0x01C0,0x2700
.cancel:
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

