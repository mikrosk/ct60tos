/* TOS 4.04 Gemdos Pexec patch for the CT60 board
*  Didier Mequignon 2003 March, e-mail: didier-mequignon@wanadoo.fr
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

	.globl flush_cache_pexec
	.globl det_gemdos
	.globl det_vbl
	
#include "ct60.h"	

#define DELAY_CACHE 1000   /* 5 Sec */

#define rw_parameter 0xc60b

#define flag_cache  -48
#define save_hz_200 -44

#define etv_critic 0x404
#define phystop    0x42E	
#define _hz_200    0x4BA
	
flush_cache_pexec:

	movem.l D0/A0/A1,-(SP)
	movec.l CACR,D0
	cmp.l #0xA0808000,D0
	bne.s .normal
	clr.l -(SP)
	move.l #CT60_CACHE_DELAY,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	btst #0,D0
	beq.s .normal
	jsr 0xE0085A                                        // caches off
	move.l phystop,A0
	clr.l save_hz_200(A0)
	move.l #0x12345678,flag_cache(A0)                   // flag delay	
	bra.s .end_pexec
.normal:
	lea.l 256(A5),A0                                    // begin of the program
	cmp.w #0x6008,(A0)+                                 // fix problems with Ice Packer
	bne.s .no_ice
	cmp.l #0x5061636B,(A0)+                             // Pack
	bne.s .no_ice
	cmp.l #0x2D496365,(A0)+                             // _Ice
	bne.s .no_ice
	cmp.w #0x4ED2,0x86(A0)                              // jmp (A2)
	bne.s .no_ice
	cmp.w #0x4ED6,0xA4(A0)                              // jmp (A6)
	bne.s .no_ice
	move.w #0x4AFC,0x86(A0)                             // illegal
	move.w #0x4AFC,0xA4(A0)                             // illegal
	lea.l .new_illegal(PC),A0
	move.l 0x10,0x380                                   // save illegal vector
	clr.l 0x384                                         // illegal counter
	move.l A0,0x10
	bra.s .no_ice
.new_illegal:
	cpusha BC                                           // flush
	addq.l #1,0x384                                     // illegal counter
	cmp.l #2,0x384
	bcs.s .jmp_a2
	move.l 0x380,0x10                                   // restore illegal vector
	addq.l #8,SP
	moveq #0,D0
	move D0,SR
	jmp (A6)
.jmp_a2:
	addq.l #8,SP
	moveq #0,D0
	move D0,SR
	jmp (A2)
.no_ice:	
	cpusha BC                                           // flush
.end_pexec:
	move.l A5,0x6EE4
	movem.l (SP)+,D0/A0/A1
	rts
	
	dc.l 0x58425241  /* XBRA */
	dc.l 0x43543630  /* CT60 */
	dc.l 0x00E1C2EA
 
det_gemdos:

	move.l USP,A0
	btst #5,(SP)                                        // call in supervisor state
	beq.s .gd2
	lea.l 8(SP),A0
.gd2:
	cmp.w #0x3F,(A0)                                    // Fread function
	bne.s .gd1
	move.l 8(A0),-(SP)                                  // buffer
	move.l 4(A0),-(SP)                                  // size
	move.l (A0),-(SP)                                   // function, handle
	clr.w -(SP)                                         // format
	pea.l end_fread(PC)                                 // return
	move.w SR,-(SP)
.gd1:
	move.l det_gemdos-4,-(SP)
	rts

	dc.l 0x58425241  /* XBRA */
	dc.l 0x43543630  /* CT60 */
	dc.l 0x00E00CB0

det_vbl:
 
 	movem.l D0/A0,-(SP)
 	move.l etv_critic,A0                                // AES valid ?
 	cmp.l #0xE00000,A0
 	bcs.s .vb2
 	cmp.l #0xEFFFFF,A0
 	bhi.s .vb2
 	cmp.l #0xE3449C,A0
 	beq.s .vb2
	move.l phystop,A0
	cmp.l #0xCAFEFADE,flag_cache(A0)
	beq.s .vb3                                          // ignore
	clr.l save_hz_200(A0)
	bra.s .vb3
.vb2:	
	move.l phystop,A0
	tst.l save_hz_200(A0)
	bne.s .vb1
	move.l _hz_200,save_hz_200(A0)    
.vb1:
	movec.l CACR,D0
	tst.l D0
	bne.s .vb3
	move.l phystop,A0
	cmp.l #0x12345678,flag_cache(A0)
	bne.s .vb3
	move.l _hz_200,D0
	sub.l save_hz_200(A0),D0
	cmp.l #DELAY_CACHE,D0                               // delay
	bcs.s .vb3	
	clr.l flag_cache(A0)
	jsr 0xE250C8                                        // caches on
.vb3:
	movem.l (SP)+,D0/A0
	move.l det_vbl-4,-(SP)
	rts

alert_copyback_en:
	.asciz "[1][WARNING !|This program seems|not like copyback cache| |Try without cache ?][Yes 5 S|No|Ignore]" 

alert_copyback_fr:
	.asciz "[1][ATTENTION !|Ce programme semble ne pas|aimer le cache en copyback| |Essayer sans le cache ?][Oui 5 S|Non|Ignore]" 
	
	.align 2	

end_fread:
	tst.l D0
	bmi .ef1                                            // error
 	cmp.l #0xE00000,14(SP)                              // return = TOS call
 	bcs .ef7
 	cmp.l #0xEFFFFF,14(SP)
 	bls .ef1
.ef7:
	movem.l D0-D2/A0-A2,-(SP)
	movec.l CACR,D0
	cmp.l #0xA0808000,D0
	bne .ef2 
	move.l 32(SP),A0                                    // buffer
	move.l A0,D0
	beq .ef2
	cmp.l #0x1000000,D0
	bcs .ef2                                            // STRAM
	move.l 28(SP),D0                                    // size
	cmp.l #0x1C,D0
	bcs .ef2
 	cmp.w #0x601A,(A0)
 	bne .ef2
	move.w 26(SP),D0                                    // handle
	move.w #1,-(SP)                                     // current position
	move.w D0,-(SP)                                     // handle
	clr.l -(SP)                                         // offset
	jsr 0xE1B246                                        // Fseek
	addq.l #8,SP
	cmp.l 28(SP),D0                                     // offset = size ?
	bne .ef2
 	move.l etv_critic,A0                                // AES valid ?
 	cmp.l #0xE00000,A0
 	bcs.s .ef3
 	cmp.l #0xEFFFFF,A0
 	bhi.s .ef3
 	cmp.l #0xE3449C,A0
 	beq.s .ef3
//	move #7,-(SP)                                       // bell
//	move #2,-(SP)
//	move #3,-(SP)
//	trap #13                                            // Bconout
//	addq.w #6,SP
	bra .ef2
.ef3:
	move.l phystop,A0
	cmp.l #0xCAFEFADE,flag_cache(A0)
	beq .ef2                                            // ignore
	tst.l save_hz_200(A0)
	beq .ef2
	move.l _hz_200,D0
	sub.l save_hz_200(A0),D0
	cmp.l #DELAY_CACHE,D0                               // delay for load CPX
	bcs .ef2                                            // after AES valid
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
	lea.l alert_copyback_en(PC),A0
	cmp.b #2,D0                                         // french
	bne.s .ef4
	lea.l alert_copyback_fr(PC),A0	
.ef4:                                      
	pea.l (A0)
	move.w #1,-(SP)
	jsr 0xE22A68                                        // form_alert
	addq.l #6,SP
	cmp.w #1,D0                                         // delay
	bne.s .ef5
	jsr 0xE0085A                                        // caches off
	move.l phystop,A0
	clr.l save_hz_200(A0)
	move.l #0x12345678,flag_cache(A0)                   // flag delay
	bra.s .ef2
.ef5:
	move.l phystop,A0
	cmp.w #2,D0                                         // no
	bne.s .ef6
	clr.l save_hz_200(A0)
	bra.s .ef2	
.ef6:
	cmp.w #3,D0                                         // ignore
	bne.s .ef2
	clr.l save_hz_200(A0)
	move.l #0xCAFEFADE,flag_cache(A0)                   // flag ignore
.ef2:
	movem.l (SP)+,D0-D2/A0-A2
.ef1:
	lea.l 12(SP),SP
	rte
 