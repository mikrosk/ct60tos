/* TOS 4.04 Gemdos Pexec patch for the CT60 board
*  Didier Mequignon 2002-2006, e-mail: aniplay@wanadoo.fr
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

#include "main.h"
#include "ct60.h"	
#include "vars.h"
#ifdef COLDFIRE
#include "fire.h"

	.globl _gouser,_termuser,_xsuper
#endif
	.globl flush_cache_pexec
	.globl det_gemdos
	.globl det_vbl

// #define DEBUG

#define DELAY_CACHE 1000   /* 5 Sec */

#define rw_parameter 0xc60b

	.text

	dc.l 0x58425241          // XBRA
#ifdef COLDFIRE
	dc.l 0x5F43465F          // _CF_
#else
	dc.l 0x43543630          // CT60
#endif
	dc.l 0x00E1C2EA
 
det_gemdos:

#ifdef COLDFIRE
	.chip 68060
	move.l USP,A0
	.chip 5200
#else
	move.l USP,A0
#endif
	btst #5,(SP)                                        // call in supervisor state
	beq.s .gd2
	lea.l 8(SP),A0
.gd2:
#ifdef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	moveq #0,D0
	move.w (A0),D0
	cmp.l #9,D0
	beq.s .cconws
	lea debug1(PC),A0
	bsr debug_display_string
	move.l (SP),A0
	move.w (A0),D0         // function
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
.cconws:
	move.l (SP)+,A0
#endif
	moveq #0,D0
	move.w (A0),D0
	cmp.l #0x3F,D0         // Fread function
#else
	cmp.w #0x3F,(A0)       // Fread function     
#endif
	bne.s .gd1
	move.l 8(A0),-(SP)     // buffer
	move.l 4(A0),-(SP)     // size
	move.l (A0),-(SP)      // function, handle
	clr.w -(SP)            // format
	pea.l end_fread(PC)    // return
#ifndef COLDFIRE
	move.w SR,-(SP)
.gd1:
	move.l det_gemdos-4(PC),-(SP)
	rts
#else /* COLDFIRE */
	move.w SR,D0
	move.w D0,-(SP)
.gd1:
	tst.l old_gemdos
	ble.s .gd3
	move.l old_gemdos,-(SP)
	rts
.gd3:

//==== _enter - Front end of TRAP #1 handler =================================

#define _run  0x6EE4
#define fstrt 0x5686

_enter:

	moveq #0,D0
	btst #5,(SP)           // are we in supervisor mode?
	bne.s enter_sup        // yes, go check sup stack
	.chip 68060
	move.l USP,A0          // no, check user stack
	.chip 5200
	move.w (A0),D0
	cmp.l #0x20,D0
	beq x20_usr
	bra.s enter_2
enter_sup:
	tst.w proc_type
	bne.s enter_sup_030
	move.w 6(SP),D0
	cmp.l #0x20,D0         // toggle/inquire state?
	beq x20_sup            // yes, go perform function
	bra.s enter_2
enter_sup_030:
	move.w 8(SP),D0
	cmp.l #0x20,D0         // toggle/inquire state?
	beq x20_sup
enter_2:
	move.l A6,-(SP)
	move.l _run,A6
	movem.l D0/A3-A5,104(A6)
	move.l (SP)+,120(A6)   // old A6
	move.w (SP)+,D0        // status reg
	move.l (SP)+,A4        // retadd
	tst.w proc_type
	beq.s enter_000        // 68000 stack format
	addq.l #2,SP           // stack format
enter_000:
	btst #13,D0
	bne.s systk            // if he is in system state, use his stack
	.chip 68060
	move.l USP,A5
	.chip 5200
	lea -40(A5),A5
	movem.l D1-A2,(A5)
	move.l A4,-(A5)        // retadd
	move.w D0,-(A5)        // SR
	movea.l SP,A0
	move.l A0,-(A5)
	move.l A5,124(A6)
// now switch to fs stack
	move.l #fstrt,SP
	lea 50(A5),A0
	bra.s callos
// he was using his own ssp
systk:
	lea -40(SP),SP
	movem.l D1-A2,(SP)
	move.l A4,-(SP)
	move.w D0,-(SP)
	.chip 68060
	move.l USP,A0
	.chip 5200
	move.l A0,-(SP)
	move.l SP,124(A6)
	lea 50(SP),A0
	move.l #fstrt,SP
callos:
	move.l A0,-(SP)
	jsr 0xE1DC30           // osif
	addq.l #4,SP
_gouser:
	move.l _run,A5
	move.l D0,104(A5)
	move.l 124(A5),A6      // stack pointer (maybe usp, maybe
	move.l (A6)+,A4        // other stack pointer
	move.w (A6)+,D0
	move.l (A6)+,A3        // retadd
	movem.l (A6),D1-A2
        	lea 40(A6),A6
	btst #13,D0            // A6 is (user-supplied) system stack
	bne.s retsys
	move.l A4,SP
	.chip 68060
	move.l A6,USP
	.chip 5200
gousr:
	tst.w proc_type
	beq.s gousr_000        // 68000 stack format
	clr.w  -(SP)
gousr_000:
	move.l A3,-(SP)
	move.w D0,-(SP)
	movem.l 104(A5),D0/A3-A6
	rte

retsys:
	move.l A6,SP
	.chip 68060
	move.l A4,USP
	.chip 5200
	bra.s gousr

_termuser:
	move.l _run,A5
	move.l 104(A5),D0
	bra.s _gouser

//==== function 0x20 handler - toggle/inquire processor/stack state ==========

_xsuper:
x20_usr:    
	move.l 2(A0),D1        // get parameter
	beq.s xu_0             // already have new SSP from
	subq.l #1,D1           // check for +1L entry
	beq x20_inq
	move.l 2(A0),A0        // get new SSP from parameter
xu_0:
	move.w (SP)+,D0        // pop SR
	move.l (SP)+,D1        // pop return address
	tst.w proc_type
	beq.s xu_0_000         // 68000 stack format
	move.w (SP)+,-(A0)     // transport stack format
xu_0_000:
	move.l D1,-(A0)        // push return address
	or.l #0x2000,D0        // set supervisor mode
	move.w D0,-(A0)        // push SR
	move.l SP,D0           // set return value (old SSP)
	move.l A0,SP           // set new SSP	
	rte

// supervisor mode gemdos(20) entry point

x20_sup:
	tst.w proc_type
	beq.s x20_sup_000       // 68000 stack format
	move.l 10(SP),D1        // get parameter
	beq.s xs_0              // go handle 0L entry
	subq.l #1,D1            // check for +1L entry
	beq.s x20_inq           // go handle inquiry
	move.l 10(SP),A1        // point to new SSP
	move.w (SP)+,D0         // pop SR
	move.l (SP)+,D1         // pop return address
	move.w (SP)+,-(A1)      // transport stack format
	move.l D1,-(A1)         // push return address
	bra.s x20_sup_common
x20_sup_000:
	move.l 8(SP),D1         // get parameter
	beq.s xs_0              // go handle 0L entry
	subq.l #1,D1            // check for +1L entry
	beq.s x20_inq           // go handle inquiry
	move.l 8(SP),A1         // point to new SSP
	move.w (SP)+,D0         // pop SR
	move.l (SP)+,-(A1)      // transport the return address
x20_sup_common:
	move.w D0,-(A1)         // push SR
        	.chip 68060
	move USP,A0
	.chip 5200
	cmp.l A0,SP             // already at old USP?
        	beq.s xs_usp            // don't play with stack
	move.l (SP)+,-(A0)      // transport func # and parm
	move.l A1,SP            // update SSP
	bra.s xs_exit

xs_usp:
	move.l A1,SP            // update SSP
	bra.s xs_scram

xs_0:
	lea 6(SP),A0
	tst.w proc_type
	beq.s xs_exit            // 68000 stack format
	lea 8(SP),A0
xs_exit:
	.chip   68060
	move.l  A0,USP           // update USP
	.chip   5200
xs_scram:
	move.l D0,-(SP)
	move.w 4(SP),D0
	and.l #0xDFFF,D0         // set user mode
	move.w D0,4(SP)
	move.l (SP)+,D0
	rte

// gemdos(20) inquiry mode entry point

x20_inq:
	moveq.l #0,D0            // return 0L for user mode
	btst.b #5,(SP)           // supervisor mode?
	beq xi_exit              // no, user mode
	subq.l #1,D0             // return -1L for sup mode
xi_exit:
	rte

#if 1 // #ifdef DEBUG

debug1:	.asciz "GEMDOS #0x"
	
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
	move.b D0,MCF_UART_UTB0                             // send the character
	move.l (SP)+,D1
.no_debug:
	rts
	
#endif /* DEBUG */

#endif /* COLDFIRE */

flush_cache_pexec:

#ifdef COLDFIRE
	lea -28(SP),SP
	movem.l D0-D2/A0-A2/A5,(SP)
	move.l 0xC(A5),D1                                   // p_tlen
	lsr.l #1,D1
	lea 256(A5),A0                                      // text
	lea memset_purec(PC),A1
.loop_search_memset:
		move.l (A0),D0
		cmp.l (A1),D0
		bne.s .next_search_memset
		addq.l #4,A1
		lea 4(A0),A2
		moveq #(12*4)-1,D2
.loop_search_memset_2:
			move.l (A2)+,D0
			cmp.l (A1)+,D0
			bne.s .bad_cmp_memset
		subq.l #1,D2
		bgt.s .loop_search_memset_2
		// patch for incompatible instructions
		lea 0x14(A0),A0                        // move.b D0,-(SP) move.w (SP)+,D2
		move.l #0x1400E18A,(A0)                // => move.b D0,D2 lsl.l #8,D2 
		bra.s .test_cacr
.bad_cmp_memset:
		lea memset_purec(PC),A1	
.next_search_memset:
		addq.l #2,A0
	subq.l #1,D1
	bgt.s .loop_search_memset
.test_cacr:
	.chip 68060
	movec.l CACR,D0
	.chip 5200
	cmp.l #CACHE_ENABLE_MODE,D0
#else
	movem.l D0-D2/A0-A2/A5,-(SP)
	movec.l CACR,D0
	cmp.l #0xA0808000,D0
#endif
	bne.s .normal
	clr.l -(SP)
	move.l #CT60_CACHE_DELAY,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	cmp.l #-1,D0
	beq.s .normal
	btst #0,D0
	beq.s .normal
#ifdef COLDFIRE
	jsr caches_disable
#else
	jsr 0xE0085A                                        // caches off
#endif
	move.l phystop,A0
	clr.l save_hz_200(A0)
	move.l #0x12345678,D0
	move.l D0,flag_cache(A0)                            // flag delay	
	bra .end_pexec
.normal:
	lea.l 256(A5),A0                                    // begin of the program
#ifdef COLDFIRE
	moveq #0,D0
	move.w (A0)+,D0
	cmp.l #0x6008,D0                                    // fix problems with Ice Packer
	bne .no_ice
	move.l (A0)+,D0
	cmp.l #0x5061636B,D0                                // Pack
	bne.s .no_ice
	move.l (A0)+,D0
	cmp.l #0x2D496365,D0                                // _Ice
	bne.s .no_ice
	moveq #0,D0
	move.w 0x86(A0),D0
	cmp.l #0x4ED2,D0                                    // jmp (A2)
	bne.s .no_ice
	move.w 0xA4(A0),D0
	cmp.l #0x4ED6,D0                                    // jmp (A6)
	bne.s .no_ice
	move.w #0x4AFC,D0                                   // illegal
	move.w D0,0x86(A0)
	move.w D0,0xA4(A0)                                  // illegal
	lea.l .new_illegal(PC),A0
	move.l 0x10,D0
	move.l D0,0x380                                     // save illegal vector
#else
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
#endif
	clr.l 0x384                                         // illegal counter
	move.l A0,0x10
	bra.s .no_ice
.new_illegal:
#ifdef COLDFIRE
	.chip 68060
	cpusha BC                                           // flush
	.chip 5200
	addq.l #1,0x384                                     // illegal counter
	move.l 0x384,D0
	cmp.l #2,D0
	bcs.s .jmp_a2
	move.l 0x380,D0
	move.l D0,0x10                                      // restore illegal vector
#else
	cpusha BC                                           // flush
	addq.l #1,0x384                                     // illegal counter
	cmp.l #2,0x384
	bcs.s .jmp_a2
	move.l 0x380,0x10                                   // restore illegal vector
#endif
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
#ifdef COLDFIRE
	.chip 68060
	cpusha BC                                           // flush
	.chip 5200
.end_pexec:
	move.l A5,0x6EE4
	movem.l (SP),D0-D2/A0-A2/A5
	lea 28(SP),SP
#else
	cpusha BC                                           // flush
.end_pexec:
	move.l A5,0x6EE4
	movem.l (SP)+,D0-D2/A0-A2/A5
#endif
	rts
	
	
#ifdef COLDFIRE /* memset PUREC patch for solve stack byte access */

memset_purec:
	dc.l 0x2F08D1C1,0x24080802,0x00006708,0x53816500
	dc.l 0x00AC1100,0x1F00341F,0x14003002,0x48423400
	dc.l 0x2001E088,0xE4886778,0x48E75F3E,0x22022602
	dc.l 0x28022A02,0x2C022E02,0x22422442,0x26422842
	dc.l 0x2A422C42,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F7E,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F7E,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F7E,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F7E,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F60,0x538066AC,0x4CDF7CFA,0xC27C03FF
	dc.l 0x3001E448,0x67085340,0x210251C8,0xFFFCC27C
	dc.l 0x00036708,0x53411102,0x51C9FFFC,0x205F4E75
#endif
	
	dc.l 0x58425241          // XBRA
#ifdef COLDFIRE
	dc.l 0x5F43465F          // _CF_
#else
	dc.l 0x43543630          // CT60
#endif
	dc.l 0x00E00CB0

det_vbl:

#ifdef COLDFIRE
 	move.l D0,-(SP)
 	move.l A0,-(SP)
 	tst.l old_gemdos
 	bgt.s .no_test_vectors
 	move.l 0x84,A0                                      // trap #1
 	cmp.l #0xE80000,A0       // 1st part of flash
 	bcs.s .no_test_vectors
 	cmp.l #0xF00000,A0
 	bcs.s .vector_ok
 	cmp.l #0xFC0000,A0       // 2nd part of flash
 	bcs.s .no_test_vectors
 	cmp.l #0xFF0000,A0
 	bcc.s .no_test_vectors
.vector_ok:
	move.w SR,D0
	move.w D0,-(SP)
	or.l #0x700,D0                                      // mask interrupts
	move.w D0,SR 	
	move.l A0,D0 	
 	lea det_gemdos(PC),A0
 	cmp.l A0,D0
 	beq.s .no_bdos
 	move.l A0,0x84
	move.l D0,old_gemdos
.no_bdos:
	move.w (SP)+,D0
	move.w D0,SR
#else 
 	movem.l D0/A0,-(SP)
	tst.b _frclock+3
	bne.s .no_test_vectors
	jsr _init_emulation_vectors
#endif
.no_test_vectors:	
#ifdef COLDFIRE
	move.l current_tcb,D0
	cmp.l tid_tos,D0
	bne .vb3
#endif
 	move.l etv_critic,A0                                // AES valid ?
 	cmp.l #0xE00000,A0       // 1st part of flash
 	bcs.s .vb2
 	cmp.l #0xF00000,A0
 	bcs.s .vb4
 	cmp.l #0xFC0000,A0       // 2nd part of flash
 	bcs.s .vb2
 	cmp.l #0xFF0000,A0
 	bcc.s .vb2
.vb4:
 	cmp.l #0xE3449C,A0
 	beq.s .vb2
	move.l phystop,A0
#ifdef COLDFIRE
	move.l flag_cache(A0),D0
	cmp.l #0xCAFEFADE,D0
#else
	cmp.l #0xCAFEFADE,flag_cache(A0)
#endif
	beq.s .vb3                                          // ignore
	clr.l save_hz_200(A0)
	bra.s .vb3
.vb2:
	move.l phystop,A0
	tst.l save_hz_200(A0)
	bne.s .vb1
#ifdef COLDFIRE
	move.l _hz_200,D0
	move.l D0,save_hz_200(A0)
.vb1:
	.chip 68060
	movec.l CACR,D0
	.chip 5200
	cmp.l #CACHE_DISABLE_MODE,D0
#else
	move.l _hz_200,save_hz_200(A0)
.vb1:
	movec.l CACR,D0
	tst.l D0
#endif
	bne.s .vb3                                          // not disabled
	move.l phystop,A0
#ifdef COLDFIRE
	move.l flag_cache(A0),D0
	cmp.l #0x12345678,D0
#else
	cmp.l #0x12345678,flag_cache(A0)
#endif
	bne.s .vb3
	move.l _hz_200,D0
	sub.l save_hz_200(A0),D0
	cmp.l #DELAY_CACHE,D0                               // delay
	bcs.s .vb3	
	clr.l flag_cache(A0)
#ifdef COLDFIRE
	jsr caches_enable
#else
	jsr 0xE250C8                                        // caches on
#endif
.vb3:
#ifdef COLDFIRE
 	move.l (SP)+,A0
 	move.l (SP)+,D0
#else
	movem.l (SP)+,D0/A0
#endif
	move.l det_vbl-4(PC),-(SP)
	rts

alert_copyback_en:
	.asciz "[1][WARNING!|This program does not seem|to like copyback cache| |Try without cache?][Yes 5 S|No|Ignore]" 

alert_copyback_fr:
	.asciz "[1][ATTENTION !|Ce programme semble ne pas|aimer le cache en copyback| |Essayer sans le cache ?][Oui 5 S|Non|Ignore]"
	
	.align 2
	
end_fread:
	tst.l D0
	bmi .ef1                                            // error
#ifdef COLDFIRE
	move.l 14(SP),A0
 	cmp.l #0xE00000,A0       // 1st part of flash
 	bcs .ef7
 	cmp.l #0xF00000,A0
 	bcs .ef1
 	cmp.l #0xFC0000,A0       // 2nd part of flash
 	bcs .ef7
 	cmp.l #0xFF0000,A0
#else
 	cmp.l #0xE00000,14(SP)   // 1st part of flash                           // return = TOS call
 	bcs .ef7
 	cmp.l #0xF00000,14(SP)
 	bcs .ef1
 	cmp.l #0xFC0000,14(SP)   // 2nd part of flash
 	bcs .ef7
 	cmp.l #0xFF0000,14(SP)
#endif
 	bcs .ef1
.ef7:
#ifdef COLDFIRE
	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
	.chip 68060
	movec.l CACR,D0
	.chip 5200
	cmp.l #CACHE_ENABLE_MODE,D0
#else
	movem.l D0-D2/A0-A2,-(SP)
	movec.l CACR,D0
	cmp.l #0xA0808000,D0
#endif
	bne .ef2 
	move.l 32(SP),A0                                    // buffer
	move.l A0,D0
	beq .ef2
	cmp.l #0x1000000,D0
	bcs .ef2                                            // STRAM
	move.l 28(SP),D0                                    // size
	cmp.l #0x1C,D0
	bcs .ef2
#ifdef COLDFIRE
	moveq #0,D0
	move.w (A0),D0
 	cmp.l #0x601A,D0
 	bne .ef2
	tst.l old_gemdos
	bgt.s .ef8
#else
 	cmp.w #0x601A,(A0)
 	bne .ef2
#endif
	move.w 26(SP),D0                                    // handle
	move.w #1,-(SP)                                     // current position
	move.w D0,-(SP)                                     // handle
	clr.l -(SP)                                         // offset
	jsr 0xE1B246                                        // Fseek GEMDOS
	addq.l #8,SP
	cmp.l 28(SP),D0                                     // offset = size ?
	bne .ef2
.ef8:
	clr.l -(SP)
	move.l #CT60_CACHE_DELAY,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	cmp.l #-1,D0
	beq .ef2
	btst #1,D0
	beq .ef2                                            // no Fread test
 	move.l etv_critic,A0                                // AES valid ?
 	cmp.l #0xE00000,A0       // 1st part of flash
 	bcs.s .ef3
 	cmp.l #0xF00000,A0
 	bcs.s .ef9
 	cmp.l #0xFC0000,A0       // 2nd part of flash
 	bcs.s .ef3
 	cmp.l #0xFF0000,A0
 	bcc.s .ef3
.ef9:
 	cmp.l #0xE3449C,A0
 	bne .ef2
.ef3:
	move.l phystop,A0
#ifdef COLDFIRE
	move.l flag_cache(A0),D0
	cmp.l #0xCAFEFADE,D0
#else
	cmp.l #0xCAFEFADE,flag_cache(A0)
#endif
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
#ifdef COLDFIRE
	extb.l D0
	cmp.l #2,D0                                         // french
#else
	cmp.b #2,D0                                         // french
#endif
	bne.s .ef4
	lea.l alert_copyback_fr(PC),A0	
.ef4:                                      
	pea.l (A0)
	move.w #1,-(SP)
	jsr 0xE22A68                                        // form_alert
	addq.l #6,SP
#ifdef COLDFIRE
	ext.l D0
	cmp.l #1,D0                                         // delay
#else
	cmp.w #1,D0                                         // delay
#endif
	bne.s .ef5
#ifdef COLDFIRE
	jsr caches_disable
#else
	jsr 0xE0085A                                        // caches off
#endif
	move.l phystop,A0
	clr.l save_hz_200(A0)
#ifdef COLDFIRE
	move.l #0x12345678,D0
	move.l D0,flag_cache(A0)                            // flag delay
#else
	move.l #0x12345678,flag_cache(A0)                   // flag delay
#endif
	bra.s .ef2
.ef5:
	move.l phystop,A0
#ifdef COLDFIRE
	cmp.l #2,D0                                         // no
#else
	cmp.w #2,D0                                         // no
#endif
	bne.s .ef6
	clr.l save_hz_200(A0)
	bra.s .ef2	
.ef6:
#ifdef COLDFIRE
	cmp.l #3,D0                                         // ignore
#else
	cmp.w #3,D0                                         // ignore
#endif
	bne.s .ef2
	clr.l save_hz_200(A0)
#ifdef COLDFIRE
	move.l #0xCAFEFADE,D0
	move.l D0,flag_cache(A0)                            // flag ignore
.ef2:

	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
#else
	move.l #0xCAFEFADE,flag_cache(A0)                   // flag ignore
.ef2:

	movem.l (SP)+,D0-D2/A0-A2
#endif
.ef1:
	lea.l 12(SP),SP
	rte
