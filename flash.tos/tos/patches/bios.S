/* TOS 4.04 Bios patch for the CT60 board
*  Didier Mequignon 2002-2012, e-mail: aniplay@wanadoo.fr
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

#include "vars.h"

	.text



 	.globl	_sb_cell
  	.globl	_sb_scrup
  	.globl	_sb_scrdn
  	.globl	_sb_blank
  	
	.align	2
	.long	0x13268
	.long	end20-begin20
begin20:
	.long	_sb_cell
  	.long	_sb_scrup
  	.long	_sb_scrdn
  	.long	_sb_blank
end20:

  	.globl	_sb_neg_cell
  	.globl	_sb_move_cursor

	.align	2
	.long	0x132A4
	.long	end21-begin21
begin21:
	.long	_sb_neg_cell
  	.long	_sb_move_cursor
end21:





