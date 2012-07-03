/* TOS 4.04 Vectors / exceptions patch for the CT60 / Coldfire board(s)
*  Didier Mequignon 2002-2010, e-mail: aniplay@wanadoo.fr
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

	.globl	init_vectors

	.align	2
	.long	0x77E
	.long	end1-begin1
begin1:
	jsr	init_vectors
	nop
	nop
	nop
	nop
end1:

	.globl	exception
	
	.align	2
	.long	0x100C
	.long	end2-begin2
begin2:
	jmp	exception
end2:

