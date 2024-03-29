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

#ifndef COLDFIRE /* conout.c */

#ifdef COLDFIRE

	.globl	_bconout2

	.align	2
	.long	0xEBE
	.long	end1-begin1
begin1:
	.long	_bconout2
end1:

	.globl	_bconout5

	.align	2
	.long	0xECA
	.long	end2-begin2
begin2:
	.long	_bconout5
end2:

	.globl	normal_ascii

	.align	2
	.long	0x1094C
	.long	end3-begin3
begin3:
	.long	normal_ascii
end3:

	.globl	_blink
	
	.align	2
	.long	0xD18
	.long	end4-begin4
begin4:
	.long	_blink
end4:

#endif /* COLDFIRE */

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

#else /* conout.S */

	.globl	_bconout2

	.align	2
	.long	0xEBE
	.long	end1-begin1
begin1:
	.long	_bconout2
end1:

	.globl	_bconout5

	.align	2
	.long	0xECA
	.long	end2-begin2
begin2:
	.long	_bconout5
end2:

	.globl	normal_ascii

	.align	2
	.long	0x1094C
	.long	end3-begin3
begin3:
	.long	normal_ascii
end3:

	.globl	_blink
	
	.align	2
	.long	0xD18
	.long	end4-begin4
begin4:
	.long	_blink
end4:

#endif /* conout.c */

#if defined(COLDFIRE) && !defined(MCF547X)

	.globl	auxistat
	
	.align	2
	.long	0xE5A
	.long	end5-begin5
begin5:
	.long	auxistat
end5:

	.globl	auxin

	.align	2
	.long	0xE7A
	.long	end6-begin6
begin6:
	.long	auxin
end6:

	.globl	auxostat

	.align	2
	.long	0xE9A
	.long	end7-begin7
begin7:
	.long	auxostat
end7:

	.globl	auxout

	.align	2
	.long	0xEBA
	.long	end8-begin8
begin8:
	.long	auxout
end8:

#endif  /* defined(COLDFIRE) && !defined(MCF547X) */

#ifdef COLDFIRE

	.globl	error_ok

	.align	2
	.long	0xE76
	.long	end9-begin9
begin9:      // centronics
	.long	error_ok
end9:

	.align	2
	.long	0xE96
	.long	end10-begin10
begin10:      // centronics
	.long	error_ok
end10:

	.align	2
	.long	0xEB6
	.long	end11-begin11
begin11:      // centronics
	.long	error_ok
end11:

	.align	2
	.long	0xE62
	.long	end12-begin12
begin12:      // MIDI
	.long	error_ok
end12:

	.align	2
	.long	0xE82
	.long	end13-begin13
begin13:      // MIDI
	.long	error_ok
end13:

	.align	2
	.long	0xEA6
	.long	end14-begin14
begin14:      // MIDI
	.long	error_ok
end14:

	.align	2
	.long	0xEC2
	.long	end15-begin15
begin15:      // MIDI
	.long	error_ok
end15:

	.align	2
	.long	0xEA2
	.long	end16-begin16
begin16:      // IKBD
	.long	error_ok
end16:

	.globl	ikbdwc

	.align	2
	.long	0xEC6
	.long	end17-begin17
begin17:      // IKBD
	.long	ikbdwc
end17:

	.globl	det_bios

	.align	2
	.long	0x228
	.long	end18-begin18
begin18:
	.short	0x21FC
	.long	det_bios
end18:

	.align	2
	.long	0x154C
	.long	end19-begin19
begin19:    	// vector table Rwabs
	.long	hdv_rw+1
end19:

#endif /* COLDFIRE */


