/* TOS 4.04 Xbios patch for the CT60 board
*  Didier Mequignon 2002-2004, e-mail: aniplay@wanadoo.fr
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
	
#ifdef COLDFIRE
	.chip	68060
#endif

	.globl	det_xbios

	.align	2
	.long	0x230
	.long	end1-begin1
begin1:
	.short	0x21FC
	.long	det_xbios
end1:

	.globl	new_statvec

	.align	2
	.long	0x26C4
	.long	end2-begin2
begin2:
	jsr	new_statvec
	nop
	nop
end2:

	.globl	new_ikbdvect

	.align	2
	.long	0x340A
	.long	end3-begin3
begin3:
	jsr	new_ikbdvect
	nop
end3:	

	.globl	nvm_access
	
	.align	2
	.long	0x216C
	.long	end4-begin4
begin4:
	jmp	nvm_access
end4:	

	.globl	test_rtc
	
	.align	2
#ifdef COLDFIRE
	.long	0x2112
#else	
	.long	0x212E
#endif
	.long	end5-begin5
begin5:
	jmp	test_rtc
end5:	

	.globl	fix_settime
	
	.align	2
	.long	0x230E
	.long	end6-begin6
begin6:
	jsr	fix_settime
end6:	

	.align	2
	.long	0x2316
	.long	end7-begin7
begin7:
	nop
	nop
end7:	

#ifndef COLDFIRE
	
	.globl	fix_gettime
	
	.align	2
	.long	0x2264
	.long	end8-begin8
begin8:
	jsr	fix_gettime
end8:

#else /* COLDFIRE */

	.globl	gettime

	.align	2
	.long	0x22A0
	.long	end9-begin9
begin9:
	jmp	gettime
end9:

	.globl	end_settime

	.align	2
	.long	0x231A
	.long	end10-begin10
begin10:
	jmp	end_settime
end10:

	.globl	error_ok

	.align	2
	.long	0x332
	.long	end11-begin11
begin11:
	move.l	#error_ok,dump_vec
end11:

	.align	2
	.long	0x33A
	.long	end12-begin12
begin12:
	move.l	#error_ok,ptr_stat
end12:

	.align	2
	.long	0x342
	.long	end13-begin13
begin13:
	move.l	#error_ok,ptr_vec
end13:
	
	.globl	auxostat

	.align	2
	.long	0x34A
	.long	end14-begin14
begin14:
	move.l	#auxostat,aux_sta
end14:
	
	.globl	auxout
	
	.align	2
	.long	0x352
	.long	end15-begin15
begin15:
	move.l	#auxout,aux_vec
end15:

	.align	2
	.long	0x532
	.long	end16-begin16
begin16:	// reset IKBD
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
end16:

	.align	2
	.long	0x429A
	.long	end17-begin17
begin17:	// flopvbl
	rts
end17:

	.globl _Setscreen

	.align	2
	.long	0x5A8
	.long	end18-begin18
begin18:
	jsr	_Setscreen
end18:

#endif
	
