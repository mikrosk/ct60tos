/* TOS 4.04 Bios patch for the CT60 board
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

	.globl	_bconout2

	.align	2
	.long	0xEBE
	.long	end1-begin1+0xC0000000
begin1:
	.long	_bconout2
end1:

	.globl	_bconout5

	.align	2
	.long	0xECA
	.long	end2-begin2+0xC0000000
begin2:
	.long	_bconout5
end2:

	.globl	normal_ascii

	.align	2
	.long	0x1094C
	.long	end3-begin3+0xC0000000
begin3:
	.long	normal_ascii
end3:

	.globl	_blink
	
	.align	2
	.long	0xD18
	.long	end4-begin4+0xC0000000
begin4:
	.long	_blink
end4:

