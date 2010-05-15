/* TOS 4.04 Boot order patch for the CT60 board
*  HD vectors patchs for the Fire Engine Coldfire board
*  Didier Mequignon 2003-2006, e-mail: aniplay@wanadoo.fr
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
	
	.globl	menu_boot

	.align	2
	.long	0x798
	.long	end1-begin1
begin1:
	jsr	menu_boot
end1:

	.globl	boot_drive

	.align	2
	.long	0xB42
	.long	end2-begin2
begin2:
	jmp	boot_drive
end2:

	.align	2
	.long	0x17EA
	.long	end3-begin3
begin3:
	.short	0x11
end3:

#ifdef COLDFIRE

	.globl	error_unknow_device
	.globl	error_ok

	.align	2
	.long	0x312
	.long	end4-begin4
begin4:
	move.l	#error_unknow_device,hdv_rw
end4:

	.align	2
	.long	0x31A
	.long	end5-begin5
begin5:
	move.l	#error_ok,hdv_bpb
end5:

	.align	2
	.long	0x322
	.long	end6-begin6
begin6:
	move.l	#error_unknow_device,hdv_mediach
end6:

	.align	2
	.long	0x30A
	.long	end7-begin7
begin7:
	move.l	#error_unknow_device,hdv_init
end7:

	.align	2
	.long	0x760
	.long	end8-begin8
begin8:	// FDC/HDC
	nop
	nop
	nop
end8:

#endif
