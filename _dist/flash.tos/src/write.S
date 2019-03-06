/*  Flashing tool for the CT60 board
 *  Copyright (C) 2000 Xavier Joubert
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *
 *  To contact author write to Xavier Joubert, 5 Cour aux Chais, 44 100 Nantes,
 *  FRANCE or by e-mail to xavier.joubert@free.fr.
 *
 */

#include "main.h"
#include "command.h"
#include "gemdos.S"

#define	reg_list	d2-d7/a2-a6
#define	params		48(sp)

	.text

|--------------------------------------------------------
| int detect_flash(Bit32u *device, Bit8u *flash_adr, Bit8u *flash_unlock1,
|                  Bit8u *flash_unlock2)
	.globl	_detect_flash
_detect_flash:
	movem.l	reg_list,-(sp)
	lea	params,a6
#undef	device
#define	device		(a6)
#undef	flash_adr
#define	flash_adr	4(a6)
#undef	flash_unlock1
#define flash_unlock1	8(a6)
#undef	flash_unlock2
#define flash_unlock2	12(a6)

	Super	0.w		| Switch to supervisor mode
	move.l	d0,save_ssp

	bsr.w	data_cache_off

	moveq.l	#0x3,d0
	movec.l	d0,sfc
	movec.l	d0,dfc

	move.l	flash_unlock1,a0
	move.l	flash_unlock2,a1
	move.l	flash_adr,a2
	move.w	#CMD_UNLOCK1,d0
	move.w	#CMD_UNLOCK2,d1
	move.w	#CMD_AUTOSELECT,d2
	move.w	#CMD_READ,d3

	clr.l	d7		| Return code

| Turn int off so we're sure we won't be disturbed until we restore
| bus error vector.
	move.w	sr,save_sr
	move.w	#0x2700,sr

	movec.l	vbr,a3
	move.l	8(a3),old_bus_error	| We catch bus error to detect
	move.l	#new_bus_error,8(a3)	| the CT60 board
	move.l	sp,a4			| Save sp

	moves.w	d0,(a0)
	moves.w	d1,(a1)
	moves.w	d2,(a0)		| Autoselect command

	moves.w	(a2),d0		| Manufacturer code
	swap	d0
	moves.w	2(a2),d0	| Device code

	moves.w	d3,(a2)		| Read/Reset command

	bra.s	end_detect_flash

	.even

	.byte	'X','B','R','A'
	.byte	'C','T','6','0'
old_bus_error:
	.long	0
new_bus_error:
| A bus error occured while we tried to write to adress space #3.
| This means there's no CT60 in the expansion slot. Let's return an error.
	move.l	a4,sp		| Restore sp

	clr.l	d0		| Default manufacturer/device code
	not.l	d7		| Error

end_detect_flash:
	move.l	old_bus_error,8(a3)	| Restore bus error
	move.w	save_sr(pc),sr		| Restore ints

	move.l	device,a0
	move.l	d0,(a0)		| Store manufacturer/device code

	bsr.w	data_cache_restore

	move.l	save_ssp,a0
	Super	(a0)		| Back to user mode
	move.l	d7,d0		| Return code

	movem.l	(sp)+,reg_list
	rts


|--------------------------------------------------------
| int erase_flash(t_sector *sectors)
	.globl	_erase_flash
_erase_flash:
	movem.l	reg_list,-(sp)
	lea	params,a6
#undef	sectors
#define	sectors		(a6)

	Super	0.w		| Switch to supervisor mode
	move.l	d0,save_ssp

	bsr.w	data_cache_off

	moveq.l	#0x3,d0
	movec.l	d0,sfc
	movec.l	d0,dfc

	move.l	sectors,a0
	move.w	#CMD_UNLOCK1,d0
	move.w	#CMD_UNLOCK2,d1
	move.w	#CMD_SECTOR_ERASE1,d2
	move.w	#CMD_SECTOR_ERASE2,d3

	clr.l	d7		| Return code

erase_sector_loop:
	move.l	(a0)+,a1
	cmpa.l	#(FLASH_ADR+FLASH_SIZE-PARAM_SIZE),a1
	beq.s	erase_sector_loop_end

	move.l	(a0)+,a2	| flash_unlock1
	move.l	(a0)+,a3	| flash_unlock2

	moves.w	d0,(a2)
	moves.w	d1,(a3)
	moves.w	d2,(a2)
	moves.w	d0,(a2)
	moves.w	d1,(a3)
	moves.w	d3,(a1)		| Erase sector command

wait_erase_loop:
	moves.w	(a1),d4
	btst.l	#7,d4
	bne.s	erase_sector_loop
	btst.l	#5,d4
	beq.s	wait_erase_loop
	moves.w	(a1),d4
	btst.l	#7,d4
	bne.s	erase_sector_loop
erase_sector_error:
	not.l	d7		| Error
erase_sector_loop_end:

	bsr.w	data_cache_restore

	move.l	save_ssp,a0
	Super	(a0)		| Back to user mode
	move.l	d7,d0		| Return code

	movem.l	(sp)+,reg_list
	rts

|--------------------------------------------------------
| int program_flash(t_sector *sectors, Bit8u *buffer, Bit32u size)
	.globl	_program_flash
_program_flash:
	movem.l	reg_list,-(sp)
	lea	params,a6
#undef	sectors
#define	sectors		(a6)
#undef	buffer
#define	buffer		4(a6)
#undef	size
#define	size		8(a6)

	Super	0.w		| Switch to supervisor mode
	move.l	d0,save_ssp

	bsr.w	data_cache_off

	moveq.l	#0x3,d0
	movec.l	d0,sfc
	movec.l	d0,dfc

	move.l	buffer,a0
	move.l	sectors,a1
	move.w	#CMD_UNLOCK1,d0
	move.w	#CMD_UNLOCK2,d1
	move.w	#CMD_PROGRAM,d2

	clr.l	d7		| Return code
	move.l	size,d6

program_sector_loop:
	move.l	(a1)+,a2
	move.l	(a1)+,a3	| flash_unlock1
	move.l	(a1)+,a4	| flash_unlock2
	move.l	(a1),a5		| Next sector start adress

program_byte_loop:
	moveq.l	#0xF,d5		| Tries minus 1
program_byte_retry:
	moves.w	d0,(a3)
	moves.w	d1,(a4)
	moves.w	d2,(a3)		| Byte program command
	move.w	(a0),d3
	moves.w	d3,(a2)

	andi.b	#0x80,d3
wait_program_loop:

	moves.w	(a2),d4
	eor.b	d3,d4
	bpl.s	wait_program_loop_end
	btst.l	#5,d4
	beq.s	wait_program_loop

	moves.w	(a2),d4
	eor.b	d3,d4
	bpl.s	wait_program_loop_end

program_byte_error:
	dbra	d5,program_byte_retry

	not.l	d7		| Error
	bra.s	program_sector_loop_end
wait_program_loop_end:

	moves.w	(a2),d4
	cmp.w	(a0),d4
	bne.s	program_byte_error

	addq.l	#2,a2
	addq.l	#2,a0

	subq.l	#2,d6
	bmi.s	program_sector_loop_end

	cmpa.l	a2,a5
	bne.w	program_byte_loop
	bra.w	program_sector_loop
program_sector_loop_end:

	bsr	data_cache_restore

	move.l	save_ssp,a0
	Super	(a0)		| Back to user mode
	move.l	d7,d0		| Return code

	movem.l	(sp)+,reg_list
	rts

|--------------------------------------------------------
| int verify_flash(Bit8u *buffer, Bit32u size)
	.globl	_verify_flash
_verify_flash:
	movem.l	reg_list,-(sp)
	lea	params,a6
#undef	buffer
#define	buffer		(a6)
#undef	size
#define	size		4(a6)

	Super	0.w		| Switch to supervisor mode
	move.l	d0,save_ssp

	bsr.w	data_cache_off

	moveq.l	#0x3,d0
	movec.l	d0,sfc
	movec.l	d0,dfc

	move.l	buffer,a0
	lea.l	0x00E00000,a1

	clr.l	d7		| Return code
	move.l	size,d6   
loop:        subq.l	#1,d6
	bmi.s	loop_end
	moves.b	(a1)+,d0
	cmp.b	(a0)+,d0
             beq.s	loop
             not.l	d7

loop_end:

	bsr.s	data_cache_restore

	move.l	save_ssp,a0
	Super	(a0)		| Back to user mode
	move.l	d7,d0		| Return code

	movem.l	(sp)+,reg_list
	rts

|--------------------------------------------------------
data_cache_off:
	move.l	d0,-(sp)
	movec.l	cacr,d0
	move.l	d0,save_cacr
	bclr.l	#8,d0
	bset.l	#11,d0
	movec.l	d0,cacr
	move.l	(sp)+,d0
	rts

|--------------------------------------------------------
data_cache_restore:
	move.l	d0,-(sp)
	move.l	save_cacr,d0
	movec.l	d0,cacr
	move.l	(sp)+,d0
	rts

|--------------------------------------------------------
	.data

	.even
	.comm	save_ssp,4
	.comm	save_sr,4
	.comm	save_cacr,4
