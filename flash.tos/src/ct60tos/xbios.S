/* TOS 4.04 Xbios patch for the CT60 board
*  Didier Mequignon 2002 December, e-mail: aniplay@wanadoo.fr
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

	.globl	det_xbios

	.align	2
	.long	0x230
	.long	end1-begin1+0x80000000
begin1:
	.short	0x21FC
	.long	det_xbios
end1:

	.globl	new_statvec

	.align	2
	.long	0x26C4
	.long	end2-begin2+0x80000000
begin2:
	jsr	new_statvec
	nop
	nop
end2:

	.globl	new_ikbdvect

	.align	2
	.long	0x340A
	.long	end3-begin3+0x80000000
begin3:
	jsr	new_ikbdvect
	nop
end3:	


