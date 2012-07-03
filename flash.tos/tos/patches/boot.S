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
#ifdef COLDFIRE
#include "fire.h"
#endif

	.text
	
#ifdef COLDFIRE
	.globl	init_cf
#else	
	.globl	init_060
#endif
	
	.align	2
	.long	0x30
	.long	end1-begin1
begin1:
#ifdef COLDFIRE
	move.l	#init_cf-FLASH_ADR+FLASH_TOS_FIRE_ENGINE,D1
	lea	end1(PC),A0
	cmp.l	#FLASH_ADR,A0
	bcs.s	.not_original_space
	cmp.l	#FLASH_ADR+0x100000,A0
	bcc.s	.not_original_space
	sub.l	#FLASH_TOS_FIRE_ENGINE,D1
	add.l	#FLASH_ADR,D1
	move.l	D1,A0          // started from TOS space (copy by a boot)
	jmp	(A0)
.not_original_space:	               // started from flash or 0x1000000 offset (RAM)
	move.l	A0,D0
	and.l	#0xFF000000,D0 // flash base
	and.l 	#0x00FFFFFF,D1 // offset
	or.l	D1,D0
	move.l	D0,A0
	jmp	(A0)           // init_cf
#else
	jmp	init_060
#endif
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

#ifdef COLDFIRE
	.chip 68060

#ifndef MCF547X
	// Floppy BIOS routines removed

	.globl	error_unknow_device
	.globl	error_ok

	.align	2
	.long	0x312
	.long	end9-begin9
begin9:
	move.l	#error_unknow_device,hdv_rw
end9:

	.align	2
	.long	0x31A
	.long	end10-begin10
begin10:
	move.l	#error_ok,hdv_bpb
end10:

	.align	2
	.long	0x322
	.long	end11-begin11
begin11:
	move.l	#error_unknow_device,hdv_mediach
end11:

	.align	2
	.long	0x30A
	.long	end12-begin12
begin12:
	move.l	#error_unknow_device,hdv_init
end12:

	.align	2
	.long	0x760
	.long	end13-begin13
begin13:	// FDC/HDC
	nop
	nop
	nop
end13:

#endif /* MCF547X */

	.globl	check_tos_crc

	.align	2
	.long	0x1508
	.long	end14-begin14
begin14:
	jmp	check_tos_crc
end14:

#if 1 // not used
	.globl	bootload

	.align	2
	.long	0x32A
	.long	end15-begin15
begin15:
	move.l	#bootload,hdv_boot
end15:
#endif

#endif /* COLDFIRE */
