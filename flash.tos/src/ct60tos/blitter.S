/* TOS 4.04 Blitter patch for the CT60 board
*  Didier Mequignon 2002 December, e-mail: didier.mequignon@wanadoo.fr
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

	.globl	copy_fonts

	.align	2
	.long	0x00000590	/* offset ROM */
	.long	end1-begin1+0x80000000
begin1:
	jsr	copy_fonts
end1:

	.globl	get_font_6x6_a0

	.align	2
	.long	0x0000DB54	/* offset ROM */
	.long	end2-begin2+0x80000000
begin2:
	jsr	get_font_6x6_a0
	nop
end2:

	.globl	get_font_6x6_a6

	.align	2
	.long	0x0000DB78	/* offset ROM */
	.long	end3-begin3+0x80000000
begin3:
	jsr	get_font_6x6_a6
	nop
end3:

	.globl	get_font_6x6_a5

	.align	2
	.long	0x0000E272	/* offset ROM */
	.long	end4-begin4+0x80000000
begin4:
	jsr	get_font_6x6_a5
end4:

	.globl	get_font_6x6_a3

	.align	2
	.long	0x0000E786	/* offset ROM */
	.long	end5-begin5+0x80000000
begin5:
	jsr	get_font_6x6_a3
end5:

	.globl	get_font_8x8_a1

	.align	2
	.long	0x00010D5E	/* offset ROM */
	.long	end6-begin6+0x80000000
begin6:
	jsr	get_font_8x8_a1
end6:

	.align	2
	.long	0x00010F8E	/* offset ROM */
	.long	end7-begin7+0x80000000
begin7:
	jsr	get_font_8x8_a1
end7:

	.globl	get_font_8x16_a1

	.align	2
	.long	0x00010D72	/* offset ROM */
	.long	end8-begin8+0x80000000
begin8:
	jsr	get_font_8x16_a1
end8:

	.align	2
	.long	0x00010FA2	/* offset ROM */
	.long	end9-begin9+0x80000000
begin9:
	jsr	get_font_8x16_a1
end9:

	.globl	get_font_8x16_a1b

	.align	2
	.long	0x00010D86	/* offset ROM */
	.long	end10-begin10+0x80000000
begin10:
	jsr	get_font_8x16_a1b
end10:

	.align	2
	.long	0x00010FB6	/* offset ROM */
	.long	end11-begin11+0x80000000
begin11:
	jsr	get_font_8x16_a1b
end11:

	.globl	get_font_ptr_a1

	.align	2
	.long	0x0000951A	/* offset ROM */
	.long	end12-begin12+0x80000000
begin12:
	jsr	get_font_ptr_a1
end12:

	.align	2
	.long	0x000006AC	/* offset ROM */
	.long	end13-begin13
begin13:
	.short	0x6000       /* test checksum */
end13:

	.globl	logo_atari

	.align	2
	.long	0x00000660	/* offset ROM */
	.long	end14-begin14+0x80000000
begin14:
	jmp	logo_atari
end14:

	.globl	det_vdi

	.align	2
	.long	0x1DF48
	.long	end15-begin15+0x80000000
begin15:
	.short	0x41F9
	.long	det_vdi
end15:

