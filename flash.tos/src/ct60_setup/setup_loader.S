/*
	CT60 setup loader

	Copyright (C) 2009	Patrice Mandin

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

#define SETUP_PROG_START	0xe7ab00+0x150
#define SETUP_PROG_LENGTH	16720

	.text

	.align	2
	.long	0x00b3a
	.long	setup_jmp_end-setup_jmp_start
setup_jmp_start:
	jmp	0xe7ab00
setup_jmp_end:

	.align	2
	.long	0x007ab00
	.long	setup_loader_end-setup_loader

setup_loader:
	/* Code originally at 0xe00b3a */
	tst.w	d0
	beq.s	noclear1
	clr.w	0xa80.w
noclear1:

	/* Save registers and top of stack in memory */
	movem.l	d0-d7/a0-a6,-(sp)

	move.l	#256,-(sp)
	move	#0x48,-(sp)
	trap	#1
	addq.l	#6,sp

	tst.l	d0
	beq	setup_loader_stop_nomem
	move.l	d0,a5
	
	move.l	a5,a0
	moveq	#16-1,d0
loop_save:
	move.l	(sp)+,(a0)+
	dbra	d0,loop_save

	lea	-64(sp),sp

	/* Create basepage */
	lea	null(pc),a0

	pea	(a0)
	pea	(a0)
	pea	(a0)
	move.w	#5,-(sp)
	move.w	#0x4b,-(sp)
	trap	#1
	lea	16(sp),sp	

	tst.l	d0
	bmi	setup_loader_stop
	move.l	d0,a6

	/* Init basepage */
	lea	SETUP_PROG_START,a0
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
	move.l	#SETUP_PROG_LENGTH,d0
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
	clr.b	(a0)+
	subq.l	#1,d0
	bne.s	clear_bss
no_clear:

	/* Exec it */
	lea	null(pc),a0

	pea	(a0)
	pea	(a6)
	pea	(a0)
	move.w	#6,-(sp)
	move.w	#0x4b,-(sp)
	trap	#1
	lea	16(sp),sp

	/* Restore original stack and registers content */

setup_loader_stop:
	lea	64(sp),sp

	lea	64(a5),a0
	moveq	#16-1,d0
loop_restore:
	move.l	-(a0),-(sp)
	dbra	d0,loop_restore

	pea	0(a5)
	move	#0x49,-(sp)
	trap	#1
	addq.l	#6,sp

	movem.l	(sp)+,d0-d7/a0-a6

setup_loader_stop_nomem:
	jmp	0xe00b42

null:
	.byte	0,0

setup_loader_end:
