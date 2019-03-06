/*  Init Vectors, ISP/FPSP patchs on the CT60 board
 * 
 * Didier Mequignon 2001-2004, e-mail: aniplay@wanadoo.fr
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
 
	.globl init_vectors
	.globl _init_emulation_vectors
	
#include "vars.h"
	
init_vectors:

	cmp.l (A1)+,D2
	bne.s next_vect
	move.l A0,-4(A1)
next_vect:
	add.l D1,A0
	dbf D0,init_vectors
	
_init_emulation_vectors:

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
             
#include "../../nonfree/isp.S"

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
	
#include "../../nonfree/fpsp.S"
