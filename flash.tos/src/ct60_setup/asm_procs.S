/*
	CT60 Setup
	ASM Helper Routines

	Copyright (C) 2009	Patrice Mandin
	Copyright (C) 2019	Daniel Illgen

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

	.globl	_ct60_cpu_read_pcr
	.globl	_measure_cpu_frequency_asm
	.globl	_start_diag_asm
	.globl	_get_text_max
	.globl	_getCookie

	.text

_ct60_cpu_read_pcr:
	.chip	68060
	movec	pcr,d0
	.chip	68000
	rts

_get_text_max:
	.word	0xa000
	move.l	a0,d0
	move.l	-0x2c(a0),d0
	rts

_start_diag_asm:
	cmp.l	#0xFA52235F,0x00ED0000
	bne.s	.no_tests
	lea	0x00E00030,A6
	jmp	0x00ED0004          // tests in flash
.no_tests:
	rts


#define _hz_200    0x4BA

_measure_cpu_frequency_asm:                 // return CPU frequency in MHz * 10

	movem.l D1-D3,-(SP)
	move.w SR,-(SP)
	move.w #0x2500,SR
	moveq #0,D0
	move.l _hz_200,D1
.sync_timer:
	cmp.l _hz_200,D1
	beq.s .sync_timer
	moveq #9,D2
.next_mes:
		move.l _hz_200,D1
		moveq #0,D3
.loop_mes:
		addq.l #1,D3
		cmp.l _hz_200,D1
		beq.s .loop_mes
		cmp.l D0,D3
		bcs.s .not_maxi
		move.l D3,D0
.not_maxi:
	dbf D2,.next_mes
	move.w (SP)+,SR
	divu #250,D0             // MHz * 10
	swap D0
	tst.w D0
	beq.s .end_mes
	add.l #0x10000,D0
.end_mes:
	clr.w D0
	swap D0
	tst.l D0
	movem.l (SP)+,D1-D3
	rts

_getCookie:
	moveml %d2-%d3/%a2-%a3,%sp@-
	movel %sp@(20),%d3
	moveq #0,%d0
	movel %d0,%sp@-
	movew #32,%sp@-
	trap #1			// super visor
	addql #6,%sp
	moveal 0x5a0,%a3		// cookie jar
	movel %d0,%sp@-
	movew #32,%sp@-
	trap #1
	addql #6,%sp
	cmpaw #0,%a3
	bnes .jarfound
	bras .notfound		// no cookie jar
.checkcookie:
	cmpl %d0,%d3
	bnes .nomatch
	moveal %sp@(24),%a0
	movel %a3@(4),%a0@
	moveq #1,%d0
	bras .done
.nomatch:
	addql #8,%a3
.jarfound:
	movel %a3@,%d0
	bnes .checkcookie
.notfound:
	moveq #0,%d0
.done:
	moveml %sp@+,%d2-%d3/%a2-%a3
	rts

