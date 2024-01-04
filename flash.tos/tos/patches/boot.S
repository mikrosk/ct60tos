/* TOS 4.04 Boot order patch for the CT60 / Coldfire board(s)
*  HD vectors patchs for the Fire Engine Coldfire board
*  Didier Mequignon 2001-2010, e-mail: aniplay@wanadoo.fr
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

#include "main.h"
#include "vars.h"

	.text
	
	.globl	init_060
	
	.align	2
	.long	0x30
	.long	end1-begin1
begin1:
	jmp	init_060
end1:

	.globl	init_sdram

	.align	2
	.long	0x632
	.long	end2-begin2
begin2:
	jsr	init_sdram
end2:

	.globl	add_sdram

	.align	2
	.long	0x96E
	.long	end3-begin3
begin3:
	jmp	add_sdram
end3:

	.globl	init_ram_test

	.align	2
	.long	0x7952
	.long	end4-begin4
begin4:
	jsr	init_ram_test
	nop
	nop
end4:

	.globl	display_ram_test

	.align	2
	.long	0x7D5A
	.long	end5-begin5
begin5:
	jmp	display_ram_test
end5:

	.globl	menu_boot

	.align	2
	.long	0x798
	.long	end6-begin6
begin6:
	jsr	menu_boot
end6:

	.globl	boot_drive

	.align	2
	.long	0xB42
	.long	end7-begin7
begin7:
	jmp	boot_drive
end7:

	.align	2
	.long	0x17EA
	.long	end8-begin8
begin8:
	.short	0x11
end8:

