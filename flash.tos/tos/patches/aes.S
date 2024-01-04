/* TOS 4.04 AES patchs for the CT60 / Coldfire boards
*  Didier Mequignon 2003-2008, e-mail: aniplay@wanadoo.fr
*  SHBUF patch from SHBUF.FIL / Martin Osieka
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

#define SHBUF_SIZE 0x7FFE                        /* 32 KB */

	.text

	.align	2
	.long	0x20B5E
	.long	end1-begin1
begin1:
	jsr	0xE28206
end1:

	.align	2
	.long	0x2510E
	.long	end2-begin2
begin2:
	move.l	#SHBUF_SIZE,(SP)
	bsr.s	sub2
	move.l	D0,0xE6D0
	bsr.s	sub2
	move.l	D0,0xA516
	bsr.s	sub2
	move.l	D0,-8(A6)
	clr.w	D5
	move.l	D0,-(SP)
	bra.s	next2
sub2:
	jmp	0xE34A12
next2:
	move.w	#3,-(SP)
	jsr	0xE2739E
	addq.l	#6,SP
end2:

	.align	2
	.long	0x25248
	.long	end3-begin3
begin3:
	move.w	#SHBUF_SIZE,-(SP)
end3:

	.align	2
	.long	0x254A8
	.long	end4-begin4
begin4:
	move.w	#SHBUF_SIZE,(SP)
	move.l	-8(A6),-(SP)
	jsr	0xE28206
	addq.l	#4,SP
end4:

	.align	2
	.long	0x281E4
	.long	end5-begin5
begin5:
	move.w	#SHBUF_SIZE,D0
	move.w	8(SP),D1
	cmp.w	#0xFFFF,D1
	beq.s	end5b
	cmp.w	D1,D0
	bcc.s	next5
	move.w	D0,D1
next5:
	move.w	D1,D0
	move.l	0xE6D0,A1
	move.l	4(SP),A0
	bra.s	next_loop5
	move.w	8(SP),D1
	move.l	0xE6D0,A0
	move.l	4(SP),A1
	moveq	#1,D0
	bra.s	next_loop5
loop5:
	move.b	(A1)+,(A0)+
next_loop5:
	dbf	D1,loop5
end5b:
	rts
	nop
	nop
end5:

	.align	2
	.long	0x3BE64
	.long	end6-begin6
begin6:
	link	A6,#-22
	movem.l	D6-D7/A5,-(SP)
	move.w	#SHBUF_SIZE,(SP)
	move.l	0xA516,-(SP)
	jsr	0xE49354
	addq.l	#4,SP
	nop
	move.l	0xA516,A0
	move.l	A0,(SP)
	cmp.b	#0x23,(A0)
	.long	0x670000E0
	clr.w	-(SP)
	move.w	#SHBUF_SIZE,-(SP)
	jsr	0xE34F62
	addq.l	#4,SP
end6:

	.align	2
	.long	0x3BF0A
	.long	end7-begin7
begin7:
	move.l	0xA516,(SP)
end7:

	.align	2
	.long	0x3BF10
	.long	end8-begin8
begin8:
	move.l	#SHBUF_SIZE,-(SP)
end8:

	.align	2
	.long	0x3BF28
	.long	end9-begin9
begin9:
	cmp.l	#SHBUF_SIZE,D7
end9:

	.align	2
	.long	0x3BF4E
	.long	end10-begin10
begin10:
	move.l	0xA516,-(SP)
end10:

	.align	2
	.long	0x3BF66
	.long	end11-begin11
begin11:
	add.l	0xA516,A0
end11:

	.align	2
	.long	0x3BF6E
	.long	end12-begin12
begin12:
	move.w	#SHBUF_SIZE,(SP)
end12:

	.align	2
	.long	0x3BF72
	.long	end13-begin13
begin13:
	move.l	0xA516,-(SP)
end13:

	.align	2
	.long	0x3BFBA
	.long	end14-begin14
begin14:
	move.l	0xA516,(SP)
end14:

	.align	2
	.long	0x3C1A8
	.long	end15-begin15
begin15:
	cmp.l	#SHBUF_SIZE,-0x1A(A6)
end15:

	.align	2
	.long	0x3C1E8
	.long	end16-begin16
begin16:
	move.l	0xA516,(SP)
end16:

	.align	2
	.long	0x3C1F0
	.long	end17-begin17
begin17:
	move.w	#SHBUF_SIZE,-(SP)
end17:

	.align	2
	.long	0x3C844
	.long	end18-begin18
begin18:
	cmp.w	#SHBUF_SIZE,-6(A6)
end18:

	.align	2
	.long	0x3C85C
	.long	end19-begin19
begin19:
	move.l	0xA516,(SP)
end19:

	.align	2
	.long	0x3C86E
	.long	end20-begin20
begin20:
	move.w	#SHBUF_SIZE,(SP)
end20:

	.align	2
	.long	0x3C872
	.long	end21-begin21
begin21:
	move.l	0xA516,-(SP)
end21:

	.align	2
	.long	0x3C8D6
	.long	end22-begin22
begin22:
	move.l	0xA516,(SP)
end22:

	.align	2
	.long	0x3C970
	.long	end23-begin23
begin23:
	move.l	0xA516,-(SP)
end23:

	.align	2
	.long	0x3E684
	.long	end24-begin24
begin24:
	move.l	0xA516,(SP)
end24:

	.align	2
	.long	0x3E68C
	.long	end25-begin25
begin25:
	move.w	#SHBUF_SIZE,-(SP)
end25:

	.align	2
	.long	0x3E698
	.long	end26-begin26
begin26:
	move.l	0xA516,(SP)
end26:

	.align	2
	.long	0x3E69E
	.long	end27-begin27
begin27:
	move.l	#SHBUF_SIZE,-(SP)
end27:

	.align	2
	.long	0x3E6C4
	.long	end28-begin28
begin28:
	move.l	0xA516,A0
	cmp.b	#0x23,(A0)
	bne.s	next28
	cmp.b	#0x61,1(A0)
next28:
	nop
	.long	0x6600003A
	move.w	#SHBUF_SIZE,(SP)
	move.l	0xA516,-(SP)
	jsr	0xE4935E
	addq.l	#4,SP
end28:

	.align	2
	.long	0x449B0
	.long	end29-begin29
begin29:
	 move.l	#SHBUF_SIZE,(SP)
end29:

	.align	2
	.long	0x449DA
	.long	end30-begin30
begin30:
	move.w	#SHBUF_SIZE,-(SP)
end30:

	.align	2
	.long	0x449EC
	.long	end31-begin31
begin31:
	move.l	0xA516,-(SP)
end31:

	.align	2
	.long	0x44B4A
	.long	end32-begin32
begin32:
	move.l	#SHBUF_SIZE,(SP)
end32:

	.align	2
	.long	0x44B68
	.long	end33-begin33
begin33:
	move.w	#SHBUF_SIZE,-(SP)
end33:

	.align	2
	.long	0x4935E
	.long	end34-begin34
begin34:
	lea.l	0xE28206,A0
end34:

	.globl	det_evnt_multi

	.align	2
	.long	0x20122
	.long	end35-begin35
begin35:
	jsr	det_evnt_multi
end35:


	.globl	patch_tran_check

	.align	2
	.long	0x2E91A
	.long	end48-begin48
begin48:
	jmp	patch_tran_check
end48:

	.align	2
	.long	0x2DE44
	.long	end49-begin49
begin49:
	dc.b	0x65 // bcs
end49:

	.align	2
	.long	0x34B6C
	.long	end50-begin50
begin50:
	dc.b	0x64 // bcc
end50:

	.globl	patch_set_video

	.align	2
	.long	0x4800C
	.long	end51-begin51
begin51:
	jmp	patch_set_video
end51:

	.align	2
	.long	0x24A5E
	.long	end52-begin52
begin52:	// setres gl_vdo test (cookie _VDO with 0x30000) removed
	nop
	nop
end52:



