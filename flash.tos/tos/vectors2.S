/* Init Vectors, ISP/FPSP patchs on the CT60 board, Exception handler
 * 
 * Didier Mequignon 2001-2010, e-mail: aniplay@wanadoo.fr
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
#include "vars.h"
#ifdef COLDFIRE
#include "fire.h"
#else
#include "pci_bios.h"
#endif

// #define DEBUG

	.text

	.globl init_vectors
	.globl _init_emulation_vectors
	.globl exception

#ifdef COLDFIRE
	.globl null

null:
	clr.l 0x380        // not valid
	move.l SP,0x3C0
	move.l A6,0x3BC
	lea 0x384,A6
	movem.l D0-D7/A0-A5,(A6)
	clr.l 0x3C8        // USP
	moveq #-1,D1
	jmp exception

#endif /* COLDFIRE */
	
init_vectors:

	cmp.l (A1)+,D2
	bne.s .next_vect
#ifdef COLDFIRE
	ext.l D0
#endif
	move.l A0,-4(A1)
.next_vect:
	add.l D1,A0
#ifdef COLDFIRE
	subq.l #1,D0
	bpl.s init_vectors
#else /* !COLDFIRE */
	dbf D0,init_vectors
	move.l A0,0x100          // MFP IO0
	move.l A0,0x11C          // MFP IO5
	move.l A0,0x120          // MFP timer B
	move.l A0,0x134          // MFP timer A
	move.l A0,0x138          // MFP IO6
	move.l A0,0x13C          // MFP IO7
	move.l A1,-(SP)
	lea 0x140,A1
	moveq #15,D0
.int_vectors:
	move.l A0,(A1)+
#ifdef COLDFIRE
	subq.l #1,D0
	bpl.s .int_vectors
#else
	dbf D0,.int_vectors
#endif	
	lea 0x1C0,A1
	move.l #143,D0
.int_vectors2:
	cmp.l #0xE80000,(A1)
	bcs.s .bad_int_vect2
	cmp.l #0xF00000,(A1)
	bcs.s .next_vect2
	cmp.l #0xFC0000,(A1)
	bcs.s .bad_int_vect2
	cmp.l #0xFF0000,(A1)
	bcs.s .next_vect2
.bad_int_vect2:
	move.l A0,(A1)
.next_vect2:
	addq.l #4,A1
#ifdef COLDFIRE
	subq.l #1,D0
	bpl.s .int_vectors2
#else
	dbf D0,.int_vectors2
#endif	
	move.l (SP)+,A1	
#endif /* COLDFIRE */
	
_init_emulation_vectors:

#ifdef COLDFIRE
	move.l A0,-(SP)
	move.l A1,-(SP)
	lea 0,A1
#if 1
	lea FLASH_ADR,A0
	move.l #0x4E714EF9,(A1)+ // JMP
	move.l 4(A0),(A1)        // reset PC
#else
	move.l #0x4E714EF9,(A1)+ // JMP
	lea null,A0           // for debug null pointer
	add.l #FLASH_ADR+0x80000,A0
	sub.l #_ct60tos_half_flash,A0
	move.l A0,(A1)
#endif
	move.l (SP)+,A1
	move.l (SP)+,A0
	rts
#else /* ATARI */
	movem.l D0/A0,-(SP)
	lea.l _top_isp+0x80(PC),A0
	cmp.l 0xF4,A0
	beq.s .ok1
	move.l 0xF4,0x7D8
	move.l A0,0xF4        // Unimplemented Integer Instruction
.ok1:
	movec.l PCR,D0
	btst #16,D0
	bne .no_fpu           // EC or LC
	move.l cookie,D0
	beq.s .fpu
	move.l D0,A0
.loop_cookie:
		move.l (A0),D0
		beq.s .fpu
		cmp.l #0x5F465055,D0    // _FPU cookie
		bne.s .next_cookie
		tst.l 4(A0)
		beq .no_fpu
		bra.s .fpu
.next_cookie:
		addq.l #8,A0
	bra.s .loop_cookie
.fpu:
	lea.l _top_fpsp+0x80(PC),A0
	cmp.l 0xD8,A0
	beq.s .ok2
	move.l 0xD8,0x7DC
	move.l A0,0xD8        // Floating-Point SNAN
.ok2:
	addq.l #8,A0
	cmp.l 0xD0,A0
	beq.s .ok3
	move.l 0xD0,0x7E0
	move.l A0,0xD0        // Floating-Point Operand Error
.ok3:
	addq.l #8,A0
	cmp.l 0xD4,A0
	beq.s .ok4
	move.l 0xD4,0x7E4
	move.l A0,0xD4        // Floating-Point Overflow
.ok4:
	addq.l #8,A0
	cmp.l 0xCC,A0
	beq.s .ok5
	move.l 0xCC,0x7E8
	move.l A0,0xCC        // Floating-Point Underflow
.ok5:
	addq.l #8,A0
	cmp.l 0xC8,A0
	beq.s .ok6
	move.l 0xC8,0x7EC
	move.l A0,0xC8        // Floating-Point Divide-by-Zero
.ok6:
	addq.l #8,A0
 	cmp.l 0xC4,A0
	beq.s .ok7
	move.l 0xC4,0x7F0
	move.l A0,0xC4        // Floating-Point Inexact Result
.ok7:
	addq.l #8,A0
	cmp.l 0x2C,A0
	beq.s .ok8
	move.l 0x2C,0x7F4
	move.l A0,0x2C        // Floating-Point Unimplemented Instruction
.ok8:
	addq.l #8,A0
	cmp.l 0xDC,A0
	beq.s .ok9
	move.l 0xDC,0x7F8
	move.l A0,0xDC        // Floating-Point Unimplemented Data Type
.ok9:
	addq.l #8,A0
	cmp.l 0xF0,A0
	beq.s .no_fpu
	move.l 0xF0,0x7FC
	move.l A0,0xF0        // Unimplemented Effective Address 
.no_fpu:
	movem.l (SP)+,D0/A0
	rts

_060_mem_copy1:
	move.b (A0)+,(A1)+
_060_mem_copy:
	dbf D0,_060_mem_copy1
	clr.l D1
	rts

_060_mem_read_byte:
	clr.l D0
	move.b (A0),D0
	clr.l D1
	rts
	
_060_mem_read_word:
	clr.l D0
_060_mem_read_word1:
	move.w (A0),D0
	clr.l D1
	rts
		
_060_mem_read_long:
	move.l (A0),D0
	clr.l D1
	rts

_060_mem_write_byte:
	move.b D0,(A0)
	clr.l D1
	rts

_060_mem_write_word:
	move.w D0,(A0)
	clr.l D1
	rts
		
_060_mem_write_long:
	move.l D0,(A0)
	clr.l D1
	rts

_060_real_chk:
_060_real_divbyzero:
_060_real_trace:
_060_real_access:
_060_isp_done:
_060_real_lock_page:
_060_real_unlock_page:
	rte
	
_060_real_fline:
	jmp ([0x7F4])

_060_real_trap:
_060_fpsp_done:
	rte

_060_real_cas:
	bra.l _top_isp+0x80+0x08

_060_real_cas2:
	bra.l _top_isp+0x80+0x10

_060_real_bsun:
	fsave -(SP)
	fmovem.l FPSR,-(SP)
	andi.b #0xFE,(SP)
	fmovem.l (SP)+,FPSR
	lea 12(SP),SP
	fmovem.l #0,FPCR
	rte

_060_real_snan:
	fsave -(SP)
	move.w #0x6000,2(SP)
	frestore (SP)+
	fmovem.l #0,FPCR
	jmp ([0x7DC])
	
_060_real_operr:
	fsave -(SP)
	move.w #0x6000,2(SP)
	frestore (SP)+
	fmovem.l #0,FPCR
	jmp ([0x7E0])
	
_060_real_ovfl:
	fsave -(SP)
	move.w #0x6000,2(SP)
	frestore (SP)+
	fmovem.l #0,FPCR
	jmp ([0x7E4])
	
_060_real_unfl:
	fsave -(SP)
	move.w #0x6000,2(SP)
	frestore (SP)+
	fmovem.l #0,FPCR
	jmp ([0x7E8])

_060_real_dz:
	fsave -(SP)
	move.w #0x6000,2(SP)
	frestore (SP)+
	fmovem.l #0,FPCR
	jmp ([0x7EC])

_060_real_inex:
	fsave -(SP)
	move.w #0x6000,2(SP)
	frestore (SP)+
	fmovem.l #0,FPCR
	jmp ([0x7F0])
	
_060_real_fpu_disabled:
	move.l D0,-(SP)
	movec.l PCR,D0
	bclr #1,D0
	movec.l D0,PCR
	move.l (SP)+,D0
	move.l 12(SP),2(SP)
	fmovem.l #0,FPCR
	rte
	
_top_isp:
	.long _060_real_chk-_top_isp /* or 0xF4 */
	.long _060_real_divbyzero-_top_isp /* or 0xF4 */
	.long _060_real_trace-_top_isp
	.long _060_real_access-_top_isp
	.long _060_isp_done-_top_isp
	.long _060_real_cas-_top_isp
	.long _060_real_cas2-_top_isp
	.long _060_real_lock_page-_top_isp
	.long _060_real_unlock_page-_top_isp
	.long 0
	.long 0
	.long 0
	.long 0
	.long 0
	.long 0
	.long 0
	.long _060_mem_copy-_top_isp
	.long _060_mem_copy-_top_isp
	.long _060_mem_copy-_top_isp
	.long _060_mem_read_word1-_top_isp
	.long _060_mem_read_long-_top_isp
	.long _060_mem_read_byte-_top_isp
	.long _060_mem_read_word-_top_isp
	.long _060_mem_read_long-_top_isp
	.long _060_mem_write_byte-_top_isp
	.long _060_mem_write_word-_top_isp
	.long _060_mem_write_long-_top_isp
	.long 0
	.long 0
	.long 0
	.long 0
	.long 0
             
#include "../nonfree/isp.S"

_top_fpsp:
	.long _060_real_bsun-_top_fpsp
	.long _060_real_snan-_top_fpsp
	.long _060_real_operr-_top_fpsp
	.long _060_real_ovfl-_top_fpsp
	.long _060_real_unfl-_top_fpsp
	.long _060_real_dz-_top_fpsp
	.long _060_real_inex-_top_fpsp
	.long _060_real_fline-_top_fpsp /* or 0x2C */
	.long _060_real_fpu_disabled-_top_fpsp
	.long _060_real_trap-_top_fpsp
	.long _060_real_trace-_top_fpsp
	.long _060_real_access-_top_fpsp
	.long _060_fpsp_done-_top_fpsp
	.long 0
	.long 0
	.long 0
	.long _060_mem_copy-_top_fpsp
	.long _060_mem_copy-_top_fpsp
	.long _060_mem_copy-_top_fpsp
	.long _060_mem_read_word1-_top_fpsp
	.long _060_mem_read_long-_top_fpsp
	.long _060_mem_read_byte-_top_fpsp
	.long _060_mem_read_word-_top_fpsp
	.long _060_mem_read_long-_top_fpsp
	.long _060_mem_write_byte-_top_fpsp
	.long _060_mem_write_word-_top_fpsp
	.long _060_mem_write_long-_top_fpsp
	.long 0
	.long 0
	.long 0
	.long 0
	.long 0
	
#include "../nonfree/fpsp.S"

#endif // COLDFIRE

exception:

	clr.l memvalid
	lea.l mess1(PC),A0
	bsr display_string
#ifdef COLDFIRE
	ext.l D1
	addq.l #1,D1
	move.l D1,D7       // vector number
#else
	addq.w #1,D1
	move.w D1,D7       // vector number
#endif
	moveq #0,D0
	move.w D7,D0
#ifdef COLDFIRE
	.chip 68060
	divu #10,D0
	.chip 5200
	move.l D0,D1
	and.l #7,D0
	beq.s .ex1
	or.l #0x30,D0
	bsr display_char
.ex1:
	swap D1
	move.w D1,D0
	or.l #0x30,D0
#else
	divu #10,D0
	and.w #7,D0
	beq.s .ex1
	or.w #0x30,D0
	bsr display_char
.ex1:
	swap d0
	or.w #0x30,D0
#endif
	bsr display_char
	moveq #0x3A,D0
	bsr display_char
	moveq #0x20,D0
	bsr display_char
	lea.l tab_mess_exc(PC),A0
	move.w D7,D0
	bsr display_tab
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
#ifdef COLDFIRE
	tst.w D7
	beq .ex0
#endif
	lea.l mess2(PC),A0 // SR
	bsr display_string
#ifdef COLDFIRE
	move.w save_sr,D0  // SR
#else
	move.l 0x3C0,A0    //SSP
	move.w (A0),D0
#endif
	bsr hex_word       // SR
	lea.l mess3(PC),A0
	bsr display_string
#ifdef COLDFIRE
	move.w save_sr,D2  // SR
	and.l #0xB71F,D2
#else
	move.l 0x3C0,A0    //SSP
	move.w (A0),D2     // SR
	and.w #0xB71F,D2
#endif
	lea.l tab_status(PC),A1
	moveq #15,D1
.ex5:
		btst.l D1,D2
		beq.s .ex6
		moveq #0,D0
		move.b (A1,D1),D0
		move.w D0,D3
#ifdef COLDFIRE
		and.l #0xF8,D3
		cmp.l #0x30,D3
#else
		and.w #0xF8,D3
		cmp.w #0x30,D3
#endif
		bne.s .ex4
		move.w D0,-(SP)
		moveq #0x49,D0 // I
		bsr display_char
		move.w (SP)+,D0
.ex4:
		bsr display_char
		moveq #0x20,D0
		bsr display_char
.ex6:
#ifdef COLDFIRE
	subq.l #1,D1
	bpl.s .ex5
.ex0:
#else
	dbf D1,.ex5
#endif
	lea.l mess4(PC),A0 // PC
	bsr display_string
#ifdef COLDFIRE
	move.l save_pc,D0  // PC
#else
	move.l 0x3C0,A0    // SSP
	move.l 2(A0),D0    // PC
#endif
	bsr hex_long
	lea.l mess10(PC),A0 // Basepage
	bsr display_string
	move.l 0x6EE4,D0
	bsr hex_long
#ifdef COLDFIRE
	tst.w D7
	beq .ex2
#endif
	lea.l mess5(PC),A0 // CACR
	bsr display_string  
#ifdef COLDFIRE
	.chip 68060
	movec.l CACR,D0    // from value stored in the CF68KLIB
	.chip 5200
	bsr hex_long
	cmp.l #2,D7
	bne.s .ex2
	lea.l mess6(PC),A0 // address fault
	bsr display_string
	move.l address_fault,D0 // from value stored in the CF68KLIB
	bsr hex_long
#else /* ATARI - CT60 */
	movec.l CACR,D0
	bsr hex_long
	cmp.w #2,D7
	beq.s .ex3         // Acces Fault
	cmp.w #3,D7
	beq.s .ex3         // Adress Error
	cmp.w #5,D7
	beq.s .ex3         // Zero Divide
	cmp.w #9,D7
	bne .ex2           // <> Trace
.ex3:
	lea.l mess6(PC),A0 // address fault
	bsr display_string
	move.l 0x3C0,A0    // SSP
	move.l 8(A0),D0    // address fault
	bsr hex_long
	cmp.w #2,D7
	bne .ex2           // <> Acces Fault
	lea.l mess7(PC),A0 // FSLW
	bsr display_string
	move.l 0x3C0,A0    // SSP
	move.l 12(A0),D0   // FSLW
	bsr hex_long
	lea.l mess3(PC),A0
	bsr display_string
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
	move.l 0x3C0,A0  // SSP
	move.l 12(A0),D2 // FSLW
	and.l #0x0BFFFFFD,D2
	lea.l tab_fslw1(PC),A1
	lea.l tab_fslw2(PC),A2
	lea.l tab_fslw3(PC),A3
	moveq #31,D1
	moveq #0,D3
.ex13:
		btst.l D1,D2
		beq.s .ex14
		moveq #0,D0
		move.b (A1,D3),D0
		bsr display_char
		moveq #0,D0
		move.b (A2,D3),D0
		cmp.b #0x20,D0
		beq.s .ex12
		bsr display_char
		moveq #0,D0
		move.b (A3,D3),D0
		cmp.b #0x20,D0
		beq.s .ex12
		bsr display_char
.ex12:
		moveq #0x20,D0
		bsr display_char
.ex14:
		addq.w #1,D3
	dbf D1,.ex13
#endif /* COLDFIRE */
.ex2:
	lea.l mess8(PC),A0 // SSP
	bsr display_string
	move.l 0x3C0,D0    // SSP
	bsr hex_long
	lea.l mess9(PC),A0 // USP
	bsr display_string
	move.l 0x3C8,D0    // USP
	bsr hex_long
	lea.l 0x384,A1     // registers
	lea.l 32(A1),A2
	moveq #7,D1
.ex8:
		moveq #13,D0
		bsr display_char
		moveq #10,D0
		bsr display_char
		moveq #0x44,D0
		bsr display_char
		moveq #7,D0
#ifdef COLDFIRE
		sub.l D1,D0
		or.l #0x30,D0
#else
		sub.w D1,D0
		or.w #0x30,D0
#endif
		move.w D0,-(SP)
		bsr display_nb
		move.l (A1),D0
		bsr hex_long // data registers
		moveq #0x20,D0
		bsr display_char
		tst.w D1
		beq.s .ex9
		moveq #0x41,D0
		bsr display_char
		move.w (SP),D0
		bsr display_nb
		move.l (A2),D0
		bsr hex_long // address registers
		moveq #0x20,D0
		bsr display_char
.ex9:		
		addq.l #2,SP
		addq.l #4,A1
		addq.l #4,A2
#ifdef COLDFIRE
	subq.l #1,D1
	bpl.s .ex8
#else
	dbf D1,.ex8
#endif
	moveq #13,D0
	bsr display_char
.loop_wait_key:
#ifdef COLDFIRE
#ifdef DEBUG
		move.w #1,-(SP)          // AUX
#else
		move.w #2,-(SP)          // CON
#endif
#else
		move.w #2,-(SP)          // CON
#endif
		move.w #2,-(SP)          // Bconin
		trap #13
		addq.l #4,SP
		ext.l D0
		move.l D0,-(SP)
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
		jsr 40(A0)               // drivers PCI in flash, add dbug (68k disassembler)
		move.l D0,(SP)
		bne .no_pci_drivers
		addq.l #4,SP
		bra.s .loop_wait_key
.no_pci_drivers:
		move.l (SP)+,D0
#ifdef COLDFIRE
		and.l #0xFF,D0
		cmp.l #0x6D,D0     // m
#else
		cmp.b #0x6D,D0     // m
#endif
		beq.s .memory_dump
#ifdef COLDFIRE
		cmp.l #0x70,D0     // p
#else
		cmp.b #0x70,D0     // p
#endif
		beq.s .patch_memory
#ifdef DEBUG
#ifdef COLDFIRE
		cmp.l #0x20,D0
#else
		cmp.b #0x20,D0
#endif	
		bne .loop_wait_key
		lea mess14(PC),A0
		bsr display_string
#endif
		rts
.memory_dump:
		lea mess11(PC),A0  // memory dump
		bsr display_string
		bsr get_hex_value	
		move.l D0,A0
		bsr dump
		bra .loop_wait_key
.patch_memory:
		lea mess12(PC),A0  // patch memory
		bsr display_string
		bsr get_hex_value
		move.l D0,A1
		lea mess13(PC),A0  // value
		bsr display_string		
		bsr get_hex_value
		cmp.l #0x100,D0
		bcc.s .word_value
		move.b D0,(A1)
		lea crlf(PC),A0
		bsr display_string
		move.l A1,D0
		bsr hex_long
		moveq #0x20,D0
		bsr display_char
		move.b (A1),D0
		bsr hex_byte
		bra .loop_wait_key
.word_value:
		cmp.l #0x10000,D0
		bcc.s .long_value
		move.w D0,(A1)
		lea crlf(PC),A0
		bsr display_string
		move.l A1,D0
		bsr hex_long
		moveq #0x20,D0
		bsr display_char
		move.w (A1),D0
		bsr hex_word	
		bra .loop_wait_key
.long_value:
		move.l D0,(A1)
		lea crlf(PC),A0
		bsr display_string
		move.l A1,D0
		bsr hex_long
		moveq #0x20,D0
		bsr display_char
		move.l (A1),D0
		bsr hex_long
	bra .loop_wait_key
	
display_nb:

	bsr display_char
	moveq #0x3A,D0
	bsr display_char
	moveq #0x24,D0
	bsr display_char
	rts
	
display_tab:

#ifdef COLDFIRE
	move.l D1,-(SP)
#endif
	move.w D0,-(SP)
	moveq #0,D0
.dt1:
#ifdef COLDFIRE
		move.b (A0),D1
		extb.l D1
		cmp.l #-1,D1
		beq.s .dt3
		moveq #0,D1
		move.w (SP),D1
		cmp.l D1,D0
#else
		cmp.b #-1,(A0)
		beq.s .dt3
		cmp.w (SP),D0
#endif
		beq.s .dt4
.dt2:
		tst.b (A0)+
		bne.s .dt2
#ifdef COLDFIRE
		addq.l #1,D0
#else
		addq.w #1,D0
#endif
	bra.s .dt1
.dt4:
	bsr display_string
.dt3:

	addq.l #2,SP
#ifdef COLDFIRE
	move.l (SP)+,D1
#endif
	rts
		
hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s hex_word
	move.l (SP)+,D0
hex_word:
	move.w D0,-(SP)
#ifdef COLDFIRE
	lsr.l #8,D0          
	bsr.s hex_byte     
	move.w (SP)+,D0
hex_byte:
	move.w D0,-(SP)
	lsr.l #4,D0
	bsr.s hex_char      
	move.w (SP)+,D0      
hex_char:
	and.l #0xF,D0      
	or.l #0x30,D0      
	cmp.l #0x3A,D0     
	bcs.s display_char  
	addq.l #7,D0
	    
display_char:
	and.l #0xFF,D0
#ifdef DEBUG /* warning !!! If serial mouse */
	move.l D1,-(SP)
.wait_uart:
	move.b MCF_UART_USR0,D1
	and.l  #MCF_UART_USR_TXRDY,D1
	beq.s .wait_uart
	move.b D0,MCF_UART_UTB0 // send the character
	move.l (SP)+,D1
#else
#if 1
	lea -60(SP),SP
	movem.l D0-A6,(SP)
	move.l D0,D1
	move.l con_state,A0
	jsr (A0)	
	movem.l (SP),D0-A6
	lea 60(SP),SP
#else
	lea -24(SP),SP     
	movem.l D0-D2/A0-A2,(SP)
	move.w D0,-(SP)
	move.w #2,-(SP)
	move.w #3,-(SP)       // Bconout
	trap #13
	addq.l #6,SP
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
#endif
#endif /* DEBUG */
	rts
#else  /* ATARI */
	lsr.w #8,D0          
	bsr.s hex_byte     
	move.w (SP)+,D0
hex_byte:
	move.w D0,-(SP)
	lsr.b #4,D0        
	bsr.s hex_char      
	move.w (SP)+,D0      
hex_char:
	and.b #0xF,D0      
	or.b #0x30,D0      
	cmp.b #0x3A,D0     
	bcs.s display_char  
	addq.b #7,D0   
	    
display_char:
	and.l #0xFF,D0  
#if 1
	lea -60(SP),SP
	movem.l D0-A6,(SP)
	move.l D0,D1
	move.l con_state,A0
	jsr (A0)	
	movem.l (SP),D0-A6
	lea 60(SP),SP
#else
	movem.l D0-D2/A0-A2,-(SP)
	move.w D0,-(SP)
	move.w #2,-(SP)
	move.w #3,-(SP)       // Bconout
	trap #13
	addq.l #6,SP
	movem.l (SP)+,D0-D2/A0-A2
#endif
	rts
#endif /* COLDFIRE */
	
display_string:

#ifdef COLDFIRE
	move.l D0,-(SP)
	move.l A0,-(SP)
#else
	movem.l D0/A0,-(SP)
#endif
.os2:
	move.b (A0)+,D0
	beq.s .os1
	bsr display_char
	bra.s .os2
.os1:
#ifdef COLDFIRE
	move.l (SP)+,A0
	move.l (SP)+,D0
#else
	movem.l (SP)+,D0/A0
#endif
	rts
	
get_hex_value:

#ifdef COLDFIRE
	lea -56(SP),SP
	movem.l D1-A5,(SP)
	link A6,#-8
	moveq #0,D7
.loop_get_value:
#ifdef DEBUG
		move.w #1,-(SP)          // AUX
#else
		move.w #2,-(SP)          // CON
#endif
		move.w #2,-(SP)          // Bconin
		trap #13
		addq.l #4,SP
		and.l #0xFF,D0
		cmp.l #13,D0
		beq.s .conv_get_value
		cmp.l #8,D0
		bne.s .not_backspace
		tst.w D7
		ble.s .loop_get_value
		bsr display_char	
		subq.l #1,D7
		bra.s .loop_get_value
.not_backspace:
		cmp.l #0x30,D0
		bcs.s .loop_get_value
		cmp.l #0x39,D0
		bls.s .number_value
		cmp.l #0x41,D0
		bcs.s .loop_get_value
		cmp.l #0x46,D0
		bls.s .letter_value
		cmp.l #0x61,D0
		bcs.s .loop_get_value
		cmp.l #0x66,D0
		bhi.s .loop_get_value
.letter_value:
		bsr display_char
		and.l #0x0F,D0
		add.l #9,D0
		bra.s .store_value		
.number_value:
		bsr display_char
		and.l #0x0F,D0
.store_value:
		move.b D0,-8(A6,D7)
		addq.l #1,D7
	cmp.l #8,D7
	bcs .loop_get_value
.conv_get_value:
	moveq #0,D0
	subq.l #1,D7
	bmi.s .end_get_value
	moveq #0,D6
.loop_value:
		asl.l #4,D0
		moveq #0,D1
		move.b -8(A6,D6),D1 
		or.l D1,D0
		addq.l #1,D6
	subq.l #1,D7
	bpl.s  .loop_value		
.end_get_value:	
	tst.l D0
	unlk A6
	movem.l (SP),D1-A5
	lea 56(SP),SP
#else /* ATARI */
	movem.l D1-A5,-(SP)
	link A6,#-8
	moveq #0,D7
.loop_get_value:
		move.w #2,-(SP)          // CON
		move.w #2,-(SP)          // Bconin
		trap #13
		addq.l #4,SP
		cmp.b #13,D0
		beq.s .conv_get_value
		cmp.b #8,D0
		bne.s .not_backspace
		tst.w D7
		ble.s .loop_get_value
		bsr display_char
		subq.w #1,D7
		bra.s .loop_get_value
.not_backspace:
		cmp.b #0x30,D0
		bcs.s .loop_get_value
		cmp.b #0x39,D0
		bls.s .number_value
		cmp.b #0x41,D0
		bcs.s .loop_get_value
		cmp.b #0x46,D0
		bls.s .letter_value
		cmp.b #0x61,D0
		bcs.s .loop_get_value
		cmp.b #0x66,D0
		bhi.s .loop_get_value
.letter_value:
		bsr display_char
		and.b #0x0F,D0
		add.b #9,D0
		bra.s .store_value		
.number_value:
		bsr display_char
		and.b #0x0F,D0
.store_value:
		move.b D0,-8(A6,D7)
		addq.w #1,D7
	cmp.w #8,D7
	bcs.s .loop_get_value
.conv_get_value:
	moveq #0,D0
	subq.w #1,D7
	bmi.s .end_get_value
	moveq #0,D6
.loop_value:
		asl.l #4,D0
		or.b -8(A6,D6),D0
		addq.w #1,D6
	dbf D7,.loop_value		
.end_get_value:	
	tst.l D0
	unlk A6
	movem.l (SP)+,D1-A5
#endif /* COLDFIRE */
	rts
	
dump:

#ifdef COLDFIRE
	lea -20(SP),SP
	movem.l D0-D2/A0-A1,(SP)
#else
	movem.l D0-D2/A0-A1,-(SP)
#endif
	move.l A0,A1
	moveq #3,D1
.loop_dump1:
		lea crlf(PC),A0
		bsr display_string
		move.l A1,D0
		bsr hex_long
		moveq #0x20,D0
		bsr display_char		
		moveq #15,D2
.loop_dump2:
			move.b (A1)+,D0
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
#ifdef COLDFIRE
		subq.l #1,D2
		bpl.s .loop_dump2
#else
		dbf D2,.loop_dump2
#endif
		lea -16(A1),A1
		moveq #15,D2
.loop_dump3:
			move.b (A1)+,D0
#ifdef COLDFIRE
			and.l #0xFF,D0
			cmp.l #0x20,D0
			bcs.s .dump_bad_char
			cmp.l #0x7F,D0
#else
			cmp.b #0x20,D0
			bcs.s .dump_bad_char
			cmp.b #0x7F,D0
#endif
			bcs.s .dump_ok
.dump_bad_char:
			moveq #0x2E,D0
.dump_ok:
			bsr display_char
#ifdef COLDFIRE
		subq.l #1,D2
		bpl.s .loop_dump3
	subq.l #1,D1
	bpl.s .loop_dump1
	movem.l (SP),D0-D2/A0-A1
	lea 20(SP),SP
#else
		dbf D2,.loop_dump3
	dbf D1,.loop_dump1
	movem.l (SP)+,D0-D2/A0-A1
#endif
	rts
	
crlf:	.byte 13,10,0
mess1:	.byte 13,10
	.asciz "EXCEPTION PROCESSING "
mess2:	.byte 13,10
	.asciz "Status Register (SR): $"
mess3:	.asciz ", bits to 1: "
mess4:	.byte 13,10
	.asciz "Program Counter (PC): $"
mess5:	.byte 13,10
	.asciz "Cache Register (CACR): $"
mess6:	.byte 13,10
	.asciz "Address Fault: $"	
mess7:	.byte 13,10
	.asciz "Fault Status Word (FSLW): "
mess8:	.byte 13,10
	.asciz "Supervisor Stack (SSP): $"
mess9:	.byte 13,10
	.asciz "User Stack (USP): $"
mess10:	.byte 13,10
	.asciz "Basepage: $"
mess11:	.byte 13,10	
	.asciz "Memory dump (hex) ? "
mess12:	.byte 13,10	
	.asciz "Patch memory (hex) ? "
mess13:	.byte 13,10	
	.asciz "Value (hex) ? "
mess14:	.byte 13,10	
	.ascii "Pterm"
	.byte 13,10,0
 
tab_mess_exc:
#ifdef COLDFIRE
	.asciz "Null (jump or call)"
#else
	.byte 0
#endif
	.byte 0
	.asciz "Access Fault"
	.asciz "Address Error"
	.asciz "Illegal Instruction"
	.asciz "Integer Zero Divide"
	.byte 0
	.byte 0
	.asciz "Privilege Violation"
	.asciz "Trace"
	.asciz "Line A"
	.asciz "Line F"
	.asciz "Emulator Interrupt"
	.byte 0
	.asciz "Format Error"
	.asciz "Uninitialised Interrupt"
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.asciz "Spurious Interrupt"
	.asciz "Interrupt level 1"
	.asciz "Interrupt level 2" 
	.asciz "Interrupt level 3" 
	.asciz "Interrupt level 4"
	.asciz "Interrupt level 5" 
	.asciz "Interrupt level 6"
	.asciz "Interrupt level 7"
	.asciz "Trap #0"
	.asciz "Trap #1"
	.asciz "Trap #2"
	.asciz "Trap #3"
	.asciz "Trap #4"
	.asciz "Trap #5"
	.asciz "Trap #6"
	.asciz "Trap #7"
	.asciz "Trap #8"
	.asciz "Trap #9"
	.asciz "Trap #10"
	.asciz "Trap #11"
	.asciz "Trap #12"
	.asciz "Trap #13"
	.asciz "Trap #14"
	.asciz "Trap #15"
	.byte -1

tab_status:	.ascii "CVZNX   012 MS T"

tab_fslw1:	.ascii "    M LRWSSTTTTTIPSPPIPSWTRWTB S"
tab_fslw2:	.ascii "    A K  ZZTTMMMOBBTTLFPPWEETP S"
tab_fslw3:	.ascii "         1010210 EEAB    E  RE E"

