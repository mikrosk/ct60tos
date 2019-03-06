/*  TOS 4.04 patch for the CT60 board
 *  Copyright (C) 2001 Xavier Joubert
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
 *
 *
 *  To contact author write to Xavier Joubert, 5 Cour aux Chais, 44 100 Nantes,
 *  FRANCE or by e-mail to xavier.joubert@free.fr.
 *
 */

	.text

	.align	2
	.long	0x638
	.long	end1-begin1
begin1:
	bsr.l	begin1-0x638+0x250C8
end1:

	.align	2
	.long	0x908
	.long	end2-begin2
begin2:
	cpusha	bc
	nop
end2:

	.align	2
	.long	0x92A
	.long	end3-begin3
begin3:
	cpusha	bc
	nop
end3:

	.align	2
	.long	0x94A
	.long	end4-begin4
begin4:
	cpusha	bc
	nop
end4:

	.align	2
	.long	0xDF6
	.long	end5-begin5
begin5:
	cpusha	bc
	nop
end5:

	.align	2
	.long	0x43B4
	.long	end6-begin6
begin6:
	cpusha	bc
	nop
end6:

	.align	2
	.long	0x46CC
	.long	end7-begin7
begin7:
	cpusha	bc
	nop
end7:

	.align	2
	.long	0x860
	.long	end8-begin8
begin8:
	cpusha	dc
	clr.l	d0
	movec.l	d0,cacr
	cinva	bc
	nop
             nop
end8:

	.align	2
	.long	0x18CA
	.long	end9-begin9
begin9:
	cpusha	bc
	bra.s	begin9-0x18CA+0x18DE
end9:

	.align	2
	.long	0x1944
	.long	end10-begin10
begin10:
	cpusha	dc
	bra.s	begin10-0x18CA+0x18DE
end10:

	.align	2
	.long	0x3990
	.long	end11-begin11
begin11:
	bsr.w	begin11-0x3990+0x85A
	nop
	nop
	nop
end11:

	.align	2
	.long	0x756
	.long	end12-begin12
begin12:
	bsr.w	begin12-0x756+0x85A
	nop
	nop
	nop
end12:

	.align	2
	.long	0x990C
	.long	end13-begin13
begin13:
	cinva	ic
	bra.s	begin13-0x990C+0x9918
end13:

	.align	2
	.long	0x11BCE
	.long	end14-begin14
begin14:
	rts
end14:

	.align	2
	.long	0x11C56
	.long	end15-begin15
begin15:
	rts
end15:

	.align	2
	.long	0x11D52
	.long	end16-begin16
begin16:
	moveq.l	#1,d0
	rts
end16:

	.align	2
	.long	0x125B8
	.long	end17-begin17
begin17:
	rts
end17:

	.align	2
	.long	0x1292E
	.long	end18-begin18
begin18:
	rts
end18:

	.align	2
	.long	0x1297A
	.long	end19-begin19
begin19:
	rts
end19:

	.align	2
	.long	0x129DE
	.long	end20-begin20
begin20:
	rts
end20:

	.align	2
	.long	0x12BF6
	.long	end21-begin21
begin21:
	rts
end21:

	.align	2
	.long	0x12C76
	.long	end22-begin22
begin22:
	rts
end22:

	.align	2
	.long	0x12CEE
	.long	end23-begin23
begin23:
	rts
end23:

	.align	2
	.long	0x12D6C
	.long	end24-begin24
begin24:
	bra.s	begin24-0x12D6C+0x12D78
end24:

	.align	2
	.long	0x12DD4
	.long	end25-begin25
begin25:
	bra.s	begin25-0x12DD4+0x12DE0
end25:

	.align	2
	.long	0x12E96
	.long	end26-begin26
begin26:
	rts
end26:

	.align	2
	.long	0x17B4C
	.long	end27-begin27
begin27:
	rts
end27:

	.align	2
	.long	0x17BE4
	.long	end28-begin28
begin28:
	rts
end28:

	.align	2
	.long	0x44528
	.long	end29-begin29
begin29:
	dc.w	60
end29:

	.align	2
	.long	0x44544
	.long	end30-begin30
begin30:
	bsr.l	begin30-0x44544+0x250C8
	bra.s	begin30-0x44544+0x44578
	nop
	bsr.l	begin30-0x44544+0x85A
	bra.s	begin30-0x44544+0x44584
end30:

	.align	2
	.long	0x250C8
	.long	end31-begin31
begin31:
	move.w	sr,-(sp)
	or.w	#0x700,sr
	cpusha	bc
	move.l	#0xA0808000,d0
	movec.l	d0,cacr
	move.w	(sp)+,sr
	rts
end31:

	.align	2
	.long	0x4456E
	.long	end32-begin32
begin32:
	cmp.l	#0xA0808000,d0
end32:
