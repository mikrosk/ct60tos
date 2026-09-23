/*
	CT60 setup loader

	Copyright (C) 2009-2010	Patrice Mandin
	Copyright (C) 2019 Daniel Illgen

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

#define SETUP_PROG_START	0xe7c000

	.text

	.globl setup_loader
	.globl loadtos
	.globl loadtos_halt

#include "vars.h"
#define DELAY	400
#define	SCANCODE_DELETE	0x53

setup_loader:
	movem.l	d0-d7/a0-a6,-(sp)
	pea	msg_setup_delkey
	move.w	#9,-(sp)
	trap	#1		//tos_cconws
	addq.l	#6,sp

	moveq	#0,d7
	lea	_hz_200,a6
	move.l	#DELAY/2,d5
	move.l	#DELAY/1,d6
	add.l	(a6),d5
	add.l	(a6),d6
.lp:
	move.w	#11,-(sp)
	trap	#1		//tos_cconis
	addq.l	#2,sp

	tst.l	d0
	beq	.nokey

	move.w	#8,-(sp)
	trap	#1		//tos_cnecin
	addq.l	#2,sp

	swap	d0
	cmp.b	#SCANCODE_DELETE,d0	//del pressed?
	bne	.done		//abort when any other key is pressed
	moveq	#1,d7
	bra	.done
.nokey:
	cmp.l	(a6),d5
	bhi	.skpdel

	move.w	#'.',-(sp)
	move.w	#2,-(sp)
	trap	#1		//tos_cconout
	addq.l	#4,sp

	moveq	#-1,d5
.skpdel:
	cmp.l	(a6),d6
	bhi	.lp
.done:
	pea	msg_setup_cleanup
	move.w	#9,-(sp)
	trap	#1		//tos_cconws
	addq.l	#6,sp

	tst.l	d7
	beq	setup_loader_stop

	lea	SETUP_PROG_START,a0
	lea	versionstring,a1
	bra	loadtos

setup_loader_stop:
	movem.l	(sp)+,d0-d7/a0-a6

	rts
null:
	.long	0
	
msg_setup_delkey:
	.byte	0x1b,0x6a,0x1b,0x59,0xff,0x20,0x1b,0x6c
	.asciz	"Press DEL to enter setup."
msg_setup_cleanup:	
	.byte	0x1b,0x6c,0x1b,0x6b,0x00
msg_halt:
	.byte	13,10,27
	.asciz	"l*** SYSTEM HALTED ***"
	.align	2


loadtos:	//a0=pointer to binary boot code
		//a1=pointer to commandline
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	a0,a5

	/* Create basepage */
	lea	null(pc),a0

	pea	(a0)
	move.l	a1,-(sp)
	move.l	(a0),-(sp)
	move.w	#5,-(sp)
	move.w	#0x4b,-(sp)
	trap	#1
	lea	16(sp),sp	

	tst.l	d0
	bmi	loadtos_stop
	move.l	d0,a6

	/* Init basepage */
	lea	4(a5),a0
	add.l	#256,d0

	move.l	d0,8(a6)
	move.l	2(a0),d1
	add.l	#28,d0
	add.l	d1,d0
	move.l	d1,12(a6)
	
	move.l	d0,16(a6)
	move.l	6(a0),d1
	add.l	d1,d0
	move.l	d1,20(a6)

	move.l	d0,24(a6)
	move.l	10(a0),d1
	add.l	d1,d0
	move.l	d1,28(a6)

	/* Copy executable */
	move.l	(a5),d0
	lea	256(a6),a1
	moveq	#16,d1
copy_setup:
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	sub.l	d1,d0
	bgt.s	copy_setup

	/* Relocate it */
	lea	256(a6),a0
	tst.l	0x1a(a0)
	beq.s	no_relocate

	moveq.l	#0x1c,d0
	add.l	2(a0),d0
	add.l	6(a0),d0
	add.l	14(a0),d0
	tst.l	(a0,d0.l)
	beq.s	no_relocate

	lea	4(a0,d0.l),a1
	move.l	(a0,d0.l),d0
	lea	0x1c(a0),a0
	move.l	a0,d2
	moveq	#0,d1
relocate_loop:
	add.l	d2,(a0,d0.l)
relocate_again:
	move.b	(a1)+,d1
	beq.s	no_relocate	

	cmp.b	#1,d1
	beq.s	adv254
	add.l	d1,d0
	bra.s	relocate_loop
adv254:
	add.l	#254,d0
	bra.s	relocate_again
no_relocate:

	/* Clear BSS */
	move.l	0x18(a6),a0
	move.l	0x1c(a6),d0
	beq.s	no_clear
	move.l	d0,d1
	and.l	#3,d0
	lsr.l	#2,d1
	beq.s	clear_bss
clear_bss_long:
	clr.l	(a0)+
	subq.l	#1,d1
	bne.s	clear_bss_long
clear_bss:
	tst.l	d0
	beq.s	no_clear
	clr.b	(a0)+
	subq.l	#1,d0
	bne.s	clear_bss
no_clear:

	/* Exec it */
	lea	null(pc),a0

	pea	(a0)
	pea	(a6)
	move.l	(a0),-(sp)
	move.w	#6,-(sp)
	move.w	#0x4b,-(sp)
	trap	#1
	lea	16(sp),sp
loadtos_halt:
	pea	msg_halt
	move.w	#9,-(sp)
	trap	#1		//tos_cconws
	addq.l	#6,sp

halt:	bra	halt

loadtos_stop:
	movem.l	(sp)+,d0-d7/a0-a6
	rts
