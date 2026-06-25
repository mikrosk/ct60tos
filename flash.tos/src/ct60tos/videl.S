/* TOS 4.04 Videl patch for the CT60 board
*  Didier Mequignon 2003 July, e-mail: aniplay@wanadoo.fr
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

	.globl	picture_boot
	.globl	fix_mono_shift

	.align	2
	.long	0x57E
	.long	end1-begin1
begin1:
	jsr	picture_boot
end1:

	.align	2
	.long	0x849C
	.long	end2-begin2
begin2:
	jsr	fix_mono_shift
	nop
end2:
