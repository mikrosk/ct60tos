/* TOS 4.04 Xbios patch for the CT60 board
*  Didier Mequignon 2002-2010, e-mail: aniplay@wanadoo.fr
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

#include "vars.h"
#ifdef COLDFIRE
#include "fire.h"
#endif

	.text
	
#ifdef COLDFIRE
	.chip	68060
#endif

	.globl	det_xbios

	.align	2
	.long	0x230
	.long	end1-begin1
begin1:
	.short	0x21FC
	.long	det_xbios
end1:

	.globl	new_statvec

	.align	2
	.long	0x26C4
	.long	end2-begin2
begin2:
	jsr	new_statvec
	nop
	nop
end2:

	.globl	new_ikbdvect

	.align	2
	.long	0x340A
	.long	end3-begin3
begin3:
	jsr	new_ikbdvect
	nop
end3:	

	.globl	nvm_access
	
	.align	2
	.long	0x216C
	.long	end4-begin4
begin4:
	jmp	nvm_access
end4:	

	.globl	test_rtc
	
	.align	2
#ifdef COLDFIRE
	.long	0x2112
#else	
	.long	0x212E
#endif
	.long	end5-begin5
begin5:
	jmp	test_rtc
end5:	

	.globl	fix_settime
	
	.align	2
	.long	0x230E
	.long	end6-begin6
begin6:
	jsr	fix_settime
end6:	

	.align	2
	.long	0x2316
	.long	end7-begin7
begin7:
	nop
	nop
end7:	

#if !defined(COLDFIRE) || defined(MCF547X)
	
	.globl	fix_gettime
	
	.align	2
	.long	0x2264
	.long	end8-begin8
begin8:
	jsr	fix_gettime
end8:

#else /* COLDFIRE */

	.globl	gettime

	.align	2
	.long	0x22A0
	.long	end9-begin9
begin9:
	jmp	gettime
end9:

	.globl	end_settime

	.align	2
	.long	0x231A
	.long	end10-begin10
begin10:
	jmp	end_settime
end10:

#endif /* !defined(COLDFIRE) || defined(MCF547X) */

#ifdef COLDFIRE

	.globl	error_ok

	.align	2
	.long	0x332
	.long	end11-begin11
begin11:
	move.l	#error_ok,dump_vec
end11:

	.align	2
	.long	0x33A
	.long	end12-begin12
begin12:
	move.l	#error_ok,ptr_stat
end12:

	.align	2
	.long	0x342
	.long	end13-begin13
begin13:
	move.l	#error_ok,ptr_vec
end13:
	
	.globl	auxostat

	.align	2
	.long	0x34A
	.long	end14-begin14
begin14:
	move.l	#auxostat,aux_sta
end14:
	
	.globl	auxout
	
	.align	2
	.long	0x352
	.long	end15-begin15
begin15:
	move.l	#auxout,aux_vec
end15:

	.align	2
	.long	0x532
	.long	end16-begin16
begin16:	// reset IKBD
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
end16:

	// not need this patch since the VBL routine patch (videl.S) exist
#if 0 // #ifndef MCF547X
	.align	2
	.long	0x429A
	.long	end17-begin17
begin17:	// flopvbl
	rts
end17:
#endif /* MCF547X */

	.globl	_Setscreen

	.align	2
	.long	0x5A8
	.long	end18-begin18
begin18:
	jsr	_Setscreen
end18:

	.align	2
	.long	0x4654
	.long	end19-begin19
begin19:	// Floppy (setdmode)
	swap	D0
	move.w	0x1694,D0
	cmp.w	#1,_nflops
	bne.s	.b19
	move.w	0x88A0,D0
.b19:
	add.w	D0,A0
	swap	D0
	move.b	D0,(A0)
	rts
end19:

	.globl	delay_80us

	.align	2
	.long	0x45F0
	.long	end20-begin20
begin20:	// Floppy
	jmp	delay_80us
end20:

	.align	2
	.long	0x4542
	.long	end21-begin21
begin21:	// Floppy
	jsr	delay_80us
	nop
	nop
	nop
	nop
	nop
	nop
end21:

	.globl	replace_mfp

	.align	2
	.long	0x526
	.long	end22-begin22
begin22:
	jsr	replace_mfp
	nop
 	// tempo 5 mS MFP
	nop
	nop
end22:

	.globl	int_timer_c_mfp

	.align	2
	.long	0x3C50 
	.long	end23-begin23
begin23:	jmp	int_timer_c_mfp
end23:

	.globl	tempo_reset_ikbd

	.align	2
	.long	0x544
	.long	end24-begin24
begin24: 	// tempo 20mS *15 MFP after IKBD reset
	jsr	tempo_reset_ikbd
	nop
	nop
	nop
	nop
	nop
end24:

	.align	2
	.long	0x62E
	.long	end25-begin25
begin25:
	nop
	nop
end25:

	.align	2
	.long	0xCB0
	.long	end26-begin26
begin26:	// VBL without palette and new screen
	addq.l	#1,_frclock
	tst.w	vblsem
	bgt.s	.vbl_ok
	rte
.vbl_ok:
	lea	-60(SP),SP
	movem.l	D0-D7/A0-A6,(SP)
	addq.l	#1,_vbclock
	clr.l	colorptr
	moveq	#0,D7
	move.w	nvbls,D7
	beq.s	begin26-0xCB0+0xD1C
	subq.l	#1,D7
	move.l	_vblqueue,A0
.loop_vbl:
	move.l	(A0)+,A1
	move.l	A1,D0
	beq.s	.no_vbl
	move.l	D7,-(SP)
	move.l	A0,-(SP)
	jsr	(A1)
	move.l	(SP)+,A0
	move.l	(SP)+,D7
.no_vbl:
	subq.l	#1,D7
	bpl.s	.loop_vbl
	bra.s	begin26-0xCB0+0xD16 // blink cursor BIOS
end26:

#ifdef MCF547X
	.global	flopvbl

	.align	2
	.long	0xD1C // just after blink JSR
	.long	end27-begin27
begin27:
	jsr	flopvbl
#else /* MCF548X */
	.align	2
	.long	0xD1C // just after blink JSR
	.long	end27-begin27
begin27:
#endif /* MCF547X */
	// VBL without palette and new screen (end)
	tst.w	_dumpflg
	bne.s	.no_dump
	move.l	dump_vec,A0
	jsr	(A0)
	moveq	#-1,D0
	move.w	D0,_dumpflg
.no_dump:
	movem.l	(SP),D0-D7/A0-A6
	lea	60(SP),SP
	rte
end27:

	.globl	delay_5mS

	.align	2
	.long	0x2564
	.long	end28-begin28
begin28:	// ACIA 6850 Atari keyboard
	jsr	delay_5mS
	move.b 	D1,2(A1)
	rts
end28:

#ifdef MCF547X

	.globl	end_settime_rtc
	
	.align	2
	.long	0x210A
	.long	end29-begin29
begin29:
	jmp	end_settime_rtc
end29:

	.globl	setporta
	
	.align	2
	.long	0x459C
	.long	end30-begin30
begin30:
	jmp	setporta
end30:

	.globl	waitdma
	
	.align	2
	.long	0x3F1A
	.long	end31-begin31
begin31:
	jsr	waitdma
	nop
end31:

	.align	2
	.long	0x412A
	.long	end32-begin32
begin32:
	jsr	waitdma
	nop
end32:

#endif /* MCF547X */

#endif /* COLDFIRE */
	
