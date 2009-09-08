/* TOS 4.04 patch for the Fire Engine Coldfire board
*  Didier Mequignon 2006, e-mail: aniplay@wanadoo.fr
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
	
	.align	2
	.long	0x556
	.long	end1-begin1
begin1:
	nop
	nop
end1:

	.align	2
	.long	0x57A
	.long	end2-begin2
begin2:
	nop
	nop
end2:

	.align	2
	.long	0x584
	.long	end3-begin3
begin3:
	nop
	nop
end3:

	.align	2
	.long	0x2BD94
	.long	end4-begin4
begin4:
	bra.s	begin4-0x2BD94+0x2BDC6
	nop
end4:
