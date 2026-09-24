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
#define CMDLINE_MAX	128             // what a basepage holds

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

	lea	-CMDLINE_MAX(sp),sp
	move.l	sp,a1
	bsr	build_cmdline
	lea	SETUP_PROG_START,a0
	move.l	sp,a1
	bsr	loadtos
	lea	CMDLINE_MAX(sp),sp

setup_loader_stop:
	movem.l	(sp)+,d0-d7/a0-a6

	rts
null:
	.long	0
	
/* The setup puts the boot banner in its title bar, taking it from the
 * command line: a length byte, then the text between an ESC p and an
 * ESC q.  message15 is that banner but starts with the CR LF the boot
 * display needs, so hand over a copy from the ESC on, with the closing
 * escape the setup expects to find.  a1 points at CMDLINE_MAX bytes.
 */
build_cmdline:
	movem.l	d0/a0/a2,-(sp)
	lea	message15+2,a0          // past the CR LF, at the ESC
	move.l	a1,a2
	addq.l	#1,a2                   // the text follows the length byte
	move.w	#CMDLINE_MAX-8,d0       // leave room for what is appended
.copy:
	move.b	(a0)+,(a2)+
	beq.s	.copied
	subq.w	#1,d0
	bne.s	.copy
	addq.l	#1,a2                   // ran out before the NUL
.copied:
	subq.l	#1,a2                   // back onto the NUL, overwrite it
	move.b	#27,(a2)+
	move.b	#'q',(a2)+
	move.b	#13,(a2)+
	move.b	#10,(a2)+
	clr.b	(a2)
	move.l	a2,d0
	sub.l	a1,d0                   // text length, the NUL counts
	move.b	d0,(a1)
	movem.l	(sp)+,d0/a0/a2
	rts

msg_setup_delkey:
	.byte	0x1b,0x6a,0x1b,0x59,0xff,0x20,0x1b,0x6c
	.asciz	"Press DEL to enter setup."
msg_setup_cleanup:	
	.byte	0x1b,0x6c,0x1b,0x6b,0x00
msg_halt:
	.byte	13,10,27
	.asciz	"l*** SYSTEM HALTED ***"
	.align	2


loadtos:	//a0=pointer to the program header
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

	/* Segments where Pexec puts them, TEXT straight after the basepage */
	lea	256(a6),a1
	move.l	a1,8(a6)		// p_tbase
	move.l	2(a5),d1
	move.l	d1,12(a6)		// p_tlen
	lea	(a1,d1.l),a0
	move.l	a0,16(a6)		// p_dbase
	move.l	6(a5),d1
	move.l	d1,20(a6)		// p_dlen
	add.l	d1,a0
	move.l	a0,24(a6)		// p_bbase
	move.l	10(a5),28(a6)		// p_blen

	move.l	a5,a0
	jsr	load_prg

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
