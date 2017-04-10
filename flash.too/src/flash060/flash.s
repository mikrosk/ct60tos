;  Flashing CT60
;  Didier Mequignon 2003-2010, e-mail: aniplay@wanadoo.fr
;
;  This program is free software; you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation; either version 2 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program; if not, write to the Free Software
;  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

FLASH_ADR equ 0xFFE00000; under 060 write moves.w in ALT3 cpu space works only at 0xFFExxxxx 

FLASH_UNLOCK1 equ (FLASH_ADR+0xAAA)
FLASH_UNLOCK2 equ (FLASH_ADR+0x554)

ERR_DEVICE  equ -1
ERR_ERASE   equ -2
ERR_PROGRAM equ -3
ERR_VERIFY  equ -4
ERR_CT60    equ -5

CMD_UNLOCK1	equ 0xAA
CMD_UNLOCK2	equ 0x55
CMD_SECTOR_ERASE1 equ 0x80
CMD_SECTOR_ERASE2 equ 0x30
CMD_PROGRAM equ 0xA0
CMD_AUTOSELECT equ 0x90
CMD_READ equ 0xF0

	.export get_date_flash
	.export get_version_flash
	.export get_checksum_flash
	.export read_flash
	.export program_flash
	.import flash_device

get_date_flash:

	bsr get_version_flash
	move.l D0,D2
	move.w SR,-(SP)
	or #0x700,SR                                        ; lock interrupts
	moveq #0,D0
	lea.l .no_flash(PC),A0
	move.l 8,A1                                         ; bus error
	move.l A0,8
	move.l SP,A2
	moveq #3,D1
	movec.l D1,SFC                                      ; CPU space 3
	movec.l D1,DFC
	moveq #0,D1
	cmp.l #0x200,D2                                     ; boot 2.0
	bcc.s .new_boot                                     ; boot patches TOS, so date of flash TOS is unchanged
	move.l FLASH_ADR+0x18,D1                             ; TOS date
	cmp.w #60,0x59E
	beq .end_read_date
	moves.l 0xE00018,D1                                 ; TOS date
	bra .end_read_date
.new_boot:
	moveq #0,D0
	move.w FLASH_ADR+0x80004,D0                         ; month
	cmp.w #60,0x59E
	beq.s .month_ok
	moves.w 0xE80004,D0                                 ; month
.month_ok:
	divu #10,D0
	moveq #0,D1
	move.w D0,D1
	asl.l #4,D1
	swap D0
	or.l D1,D0
	move.b D0,D3
	asl.l #8,D3
	moveq #0,D0
	move.w FLASH_ADR+0x80002,D0                         ; day
	cmp.w #60,0x59E
	beq.s .day_ok
	moves.w 0xE80002,D0                                 ; day
.day_ok:
	divu #10,D0
	moveq #0,D1
	move.w D0,D1
	asl.l #4,D1
	swap D0
	or.l D1,D0
	move.b D0,D3
	asl.l #8,D3
	moveq #0,D0
	move.w FLASH_ADR+0x80006,D0                         ; year
	cmp.w #60,0x59E
	beq.s .year_ok
	moves.w 0xE80006,D0                                 ; year
.year_ok:
	divu #100,D0
	move.l D0,D2
	and.l #0xFFFF,D0
	divu #10,D0
	moveq #0,D1
	move.w D0,D1
	asl.l #4,D1
	swap D0
	or.l D1,D0
	move.b D0,D3
	asl.l #8,D3
	clr.w D2
	swap D2
	move.l D2,D0
	divu #10,D0
	moveq #0,D1
	move.w D0,D1
	asl.l #4,D1
	swap D0
	or.l D1,D0
	move.b D0,D3
	move.l D3,D1
.end_read_date:
	move.l D1,D0
	bne.s .no_flash
	moveq #-1,D0
.no_flash:
	move.l A1,8
	move.l A2,SP
	move.w (SP)+,SR
	rts

get_version_flash:

	move.w SR,-(SP)
	or #0x700,SR                                        ; lock interrupts
	moveq #0,D0
	lea.l .no_flash(PC),A0
	move.l 8,A1                                         ; bus error
	move.l A0,8
	move.l SP,A2
	moveq #3,D1
	movec.l D1,SFC                                      ; CPU space 3
	movec.l D1,DFC
	moveq #0,D1
	move.w FLASH_ADR+0x80000,D1                         ; Boot version
	cmp.w #60,0x59E
	beq.s .end_read_version
	moves.w 0xE80000,D1                                 ; Boot version
.end_read_version:
	move.l D1,D0
	bne.s .no_flash
	moveq #-1,D0
.no_flash:
	move.l A1,8
	move.l A2,SP
	move.w (SP)+,SR
	rts

get_checksum_flash:

	move.w SR,-(SP)
	or #0x700,SR                                        ; lock interrupts
	moveq #0,D0
	lea.l .no_flash(PC),A0
	move.l 8,A1                                         ; bus error
	move.l A0,8
	move.l SP,A2
	moveq #3,D1
	movec.l D1,SFC                                      ; CPU space 3
	movec.l D1,DFC
	moveq #0,D1
	move.w FLASH_ADR+0x7FFFE,D1                         ; checksum
	cmp.w #60,0x59E
	beq.s .end_read_checksum
	moves.w 0xE7FFFE,D1                                 ; checksum
.end_read_checksum:
	move.l D1,D0
	bne.s .no_flash
	moveq #-1,D0
.no_flash:
	move.l A1,8
	move.l A2,SP
	move.w (SP)+,SR
	rts
	
read_flash: ; D0.L: offset, D1.L: total size, A0: target

	movem.l D1-A6,-(SP)
	move.w SR,-(SP)
	or #0x700,SR                                        ; lock interrupts
	lea.l FLASH_ADR,A2
	add.l D0,A2                                         ; offset
	move.l D1,D7                                        ; size
	lsr.l #2,D7                                         ; /4
	lea.l .no_flash(PC),A1
	move.l 8,A5                                         ; bus error
	move.l A1,8
	move.l SP,A6	
	moveq #ERR_CT60,D0
	moveq #3,D3
	movec.l D3,SFC                                      ; CPU space 3
	movec.l D3,DFC
	move.l (A2),D0
	cmp.w #60,0x59E
	beq.s .end_test_read
	moves.l (A2),D1
.end_test_read:		
	move.l A5,8                                         ; bus error
	move.l A6,SP
	move.w (SP)+,SR
	cmp.w #60,0x59E
	beq.s .read_060
.loop_030:
		moves.l (A2)+,D0
		move.l D0,(A0)+
	subq.l #1,D7
	bgt.s .loop_030
	moveq #0,D0	
	bra .read_end
.read_060:
		move.l (A2)+,(A0)+
	subq.l #1,D7
	bgt.s .read_060
	moveq #0,D0	
	bra .read_end
.no_flash:
	move.l A5,8                                         ; bus error
	move.l A6,SP
	move.w (SP)+,SR
.read_end:
	movem.l (SP)+,D1-A6
	rts

program_flash: ; D0.L: offset, D1.L: total size, A0: source, D2: lock_interrupts

	movem.l D1-A6,-(SP)
	tst.w D2
	beq.s .not_locked1
	move.w SR,-(SP)
	or #0x700,SR                                        ; lock interrupts
.not_locked1:
	move.w D2,-(SP)
	move.l D0,D6                                        ; offset
	add.l D0,A0                                         ; source
	move.l D1,D7                                        ; total size
	movec.l CACR,D3
	move.l D3,-(SP)                                     ; save CACR
	cmp.w #60,0x59E
	beq.s .cache060
	bclr.l #8,D3                                        ; disable data cache
	bset.l #11,D3                                       ; clear data cache
	movec.l D3,CACR                                     ; no cache
	bra.s .test_berr
.cache060:
	cpusha DC
	bclr.l #31,D3
	movec.l D3,CACR                                     ; no data cache
	cinva DC
.test_berr:	
	move.w SR,-(SP)
	or #0x700,SR                                        ; lock interrupts
	lea.l .no_flash(PC),A1
	move.l 8,A5                                         ; bus error
	move.l A1,8
	move.l SP,A6	
	moveq #ERR_CT60,D0
	moveq #3,D3
	movec.l D3,SFC                                      ; CPU space 3
	movec.l D3,DFC
	lea.l FLASH_UNLOCK1,A3
	lea.l FLASH_UNLOCK2,A1
	lea.l FLASH_ADR,A2
	move.w #CMD_UNLOCK1,D3
	move.w #CMD_UNLOCK2,D4
	move.w #CMD_AUTOSELECT,D5
	move.w #CMD_READ,D1
	moves.w D3,(A3)
	moves.w D4,(A1)
	moves.w D5,(A3)                                     ; Autoselect command
	move.l (A2),D0
	cmp.w #60,0x59E
	beq.s .read_id_060
	moves.l (A2),D0                                     ; Manufacturer code / Device code
.read_id_060:
	moves.w D1,(A2)                                     ; Read/Reset command
	move.l A5,8
	move.l A6,SP
	move.w (SP)+,SR
	move.l D0,flash_device
	lea.l devices(PC),A3
.loop_dev:
		tst.l (A3)
		beq .no_dev
		cmp.l (A3),D0
		beq.s .found_dev
		addq.l #8,A3
	bra.s .loop_dev
.no_dev:
	moveq #ERR_DEVICE,D0                                ; error
	bra .program_end
.no_flash:
	move.l A5,8                                         ; bus error
	move.l A6,SP
	move.w (SP)+,SR
	bra .program_end
.found_dev:
	lea.l devices(PC),A1
	add.l 4(A3),A1                                      ; sector of device
	moveq #0,D1                                         ; offset
.find_offset:
		movem.l (A1),A2-A4                              ; sector, flash_unlock1, flash_unlock2
		cmp.l D6,D1
		bcc.s .offset_ok
		lea.l 12(A1),A1
		move.l (A1),D0
		sub.l A2,D0                                     ; sector size
		add.l D0,D1                                     ; offset
	tst.l 4(A1)                                         ; next sector
	bne.s .find_offset
	moveq #ERR_DEVICE,D0                                ; error
	bra .program_end
.offset_ok:
	sub.l D1,D7                                         ; total size - offset
	move.l 12(A1),D0
	sub.l A2,D0                                         ; sector size   		
	add.l D0,D1                                         ; new offset
	cmp.l D0,D7
	ble.s .size_inf
	move.l D0,D7                                        ; sector size
.size_inf:	
	move.l A2,A5
	moveq #-1,D2
	lsr.l #2,D0                                         ; /4
	subq.l #1,D0
	cmp.w #60,0x59E
	beq.s .test_free_060
.test_free:
		moves.l (A5)+,D5
		cmp.l D5,D2                                     ; verify sector free
	dbne D0,.test_free  
	bra.s .end_test_free
.test_free_060:
		cmp.l (A5)+,D2                                  ; verify sector free
	dbne D0,.test_free_060
.end_test_free:
	beq .erase_sector_end
	move.w #CMD_SECTOR_ERASE1,D5
	move.w #CMD_SECTOR_ERASE2,D6
	moves.w D3,(A3)
	moves.w D4,(A4)
	moves.w D5,(A3)
	moves.w D3,(A3)
	moves.w D4,(A4)
	moves.w D6,(A2)                                     ; Erase sector command
.wait_erase_loop:
		move.w (A2),D0
		cmp.w #60,0x59E
		beq.s .wait_erase_sector_060
		moves.w (A2),D0
.wait_erase_sector_060:
		btst.l #7,D0
		bne.s .erase_sector_end
	btst.l #5,D0
	beq.s .wait_erase_loop
	move.w (A2),D0
	cmp.w #60,0x59E
	beq.s .test_erase_sector_060
	moves.w (A2),D0	
.test_erase_sector_060:
	btst.l #7,D0
	bne.s .erase_sector_end
	moveq #ERR_ERASE,D0                                 ; error
	bra .program_loop_end
.erase_sector_end:
	move.l D1,D0                                        ; new offset
	tst.l D7
	ble .program_loop_end	
	move.l A0,A5                                        ; source
	move.l D7,A6										; bytes used in this sector
	move.w #CMD_PROGRAM,D5
.program_byte_loop:
		moveq #15,D6                                    ; retry counter
.program_byte_retry:
			moves.w D3,(A3)
			moves.w D4,(A4)
			moves.w D5,(A3)                             ; Byte program command
			move.w (A0),D0
			moves.w D0,(A2)
			andi.b #0x80,D0
.wait_program_loop:
				move.w (A2),D2
				cmp.w #60,0x59E
				beq.s .wait_program_byte_060
				moves.w (A2),D2
.wait_program_byte_060:
				eor.b D0,D2
				bpl.s .wait_program_loop_end
			btst.l #5,D2
			beq.s .wait_program_loop
			move.w (A2),D2
			cmp.w #60,0x59E
			beq.s .test_program_byte_060
			moves.w (A2),D2
.test_program_byte_060:
			eor.b D0,D2
			bpl.s .wait_program_loop_end
.program_byte_error:
		dbf D6,.program_byte_retry
		moveq #ERR_PROGRAM,D0                           ; error
		bra.s .program_loop_end
.wait_program_loop_end:
		move.w (A2),D2
		cmp.w #60,0x59E
		beq.s .wait_program_loop_end_060
		moves.w (A2),D2
.wait_program_loop_end_060:
		cmp.w (A0),D2
		bne.s .program_byte_error
		addq.l #2,A2
		addq.l #2,A0
	subq.l #2,D7
	bgt .program_byte_loop
	move.l D1,D0                                        ; new offset
	move.l (A1),A2                                      ; sector, flash_unlock1, flash_unlock2
	moveq #-1,D2
	move.l A6,D6
	lsr.l #1,D6                                         ; /2
	subq.l #1,D6
	bmi.s .program_loop_end
	cmp.w #60,0x59E
	beq.s .verify_sector_loop_060
.verify_sector_loop:
		moves.w (A2)+,D2
		cmp.w (A5)+,D2                                  ; verify sector
	dbne D6,.verify_sector_loop  
	bra.s .end_verify_sector
.verify_sector_loop_060:
		move.w (A2)+,D2
		cmp.w (A5)+,D2                                  ; verify sector
	dbne D6,.verify_sector_loop_060  
.end_verify_sector:
	beq.s .program_loop_end
	moveq #ERR_VERIFY,D0                                ; verify error
.program_loop_end:
	move.w #CMD_READ,D5
	moves.w D3,(A3)
	moves.w D4,(A4)
	moves.w D5,(A3)                                     ; Read/Reset command
.program_end:
	move.l (SP)+,D2
	cmp.w #60,0x59E
	bne.s .no_cache060
	cpusha DC	
.no_cache060:	
	movec.l D2,CACR
	tst.w (SP)+
	beq.s .not_locked2
	move.w (SP)+,SR
.not_locked2:
	movem.l (SP)+,D1-A6
	rts
	
devices:
	dc.l 0x000422AB, fujitsu_mbm29f400bc-devices
	dc.l 0x00042258, fujitsu_mbm29f800ba-devices
	dc.l 0x00012258, amd_am29f800bb-devices
	dc.l 0x00202258, st_m29f800db-devices
	dc.l 0
	
fujitsu_mbm29f400bc:
	dc.l FLASH_ADR+0x00000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x04000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x06000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x08000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x10000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x20000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x30000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x40000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x50000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x60000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x70000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x80000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0x84000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0x86000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0x88000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0x90000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0xA0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0xB0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0xC0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0xD0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0xE0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0xF0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000
	dc.l FLASH_ADR+0x100000, 0, 0

fujitsu_mbm29f800ba:
amd_am29f800bb:
st_m29f800db:
	dc.l FLASH_ADR+0x00000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x04000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x06000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x08000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x10000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x20000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x30000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x40000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x50000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x60000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x70000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x80000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x90000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0xA0000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0xB0000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0xC0000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0xD0000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0xE0000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0xF0000, FLASH_UNLOCK1, FLASH_UNLOCK2
	dc.l FLASH_ADR+0x100000, 0, 0
	
	end
