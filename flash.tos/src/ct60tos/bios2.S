/* TOS 4.04 Bios bconout patch for the CT60 board
*  Didier Mequignon 2001 December, e-mail: didier-mequignon@wanadoo.fr
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

	.globl _bconout2
	
_bconout2:
	move.w 6(SP),D1
	move.w D1,-(SP)
	bsr _cputc
	addq.w #2,SP
	rts
	
#include "conout.S"
