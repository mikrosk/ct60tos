;  Flashing parameters for the CT60 board
;  Didier Mequignon 2003-2010, e-mail: aniplay@wanadoo.fr
;  Based on the flash tool Copyright (C) 2000 Xavier Joubert
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

FLASH_ADR equ $FFE00000; under 060 write moves.w in ALT3 cpu space works only at $FFExxxxx 
FLASH_SIZE equ $100000
PARAM_SIZE equ (64*1024)

FLASH_UNLOCK1 equ (FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0xAAA)
FLASH_UNLOCK2 equ (FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0x554)
 
CMD_UNLOCK1	equ $AA
CMD_UNLOCK2	equ $55
CMD_SECTOR_ERASE1 equ $80
CMD_SECTOR_ERASE2 equ $30
CMD_PROGRAM equ $A0
CMD_AUTOSELECT equ $90
CMD_READ equ $F0

MAX_PARAM_FLASH equ 16
NB_BLOCK_PARAM equ (PARAM_SIZE/(MAX_PARAM_FLASH*4))
SIZE_BLOCK_PARAM equ (PARAM_SIZE/NB_BLOCK_PARAM) 

	.export get_version_flash
	.export ct60_rw_param

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

ct60_rw_param: ; D0.W: mode, D1.L: type_param, D2.L: value	

	movem.l D1-A5,-(SP)
	link A6,#-MAX_PARAM_FLASH*4      
	move.w SR,-(SP)
	or #0x700,SR                                        ; lock interrupts
	tst.l D1
	bmi .out_param   
	cmp.l #MAX_PARAM_FLASH-1,D1                         ; type_param
	bcc .out_param
	movec.l CACR,D3
	move.l D3,-(SP)
	cmp.w #60,0x59E
	beq.s .cache_060
	bclr.l #8,D3                                        ; disable data cache
	bset.l #11,D3                                       ; clear data cache
	movec.l D3,CACR                                     ; no cache
.cache_060:
	addq.l #1,D1
	asl.l #2,D1                                         ; param * 4
	lea.l .no_flash(PC),A1
	move.l 8,A5                                         ; bus error
	move.l A1,8
	move.l A6,-(SP)
	move.l SP,A6
	moveq #3,D3
	movec.l D3,SFC                                      ; CPU space 3
	movec.l D3,DFC
	lea.l FLASH_ADR+FLASH_SIZE-PARAM_SIZE,A2
	moveq #-1,D3
	move.l #NB_BLOCK_PARAM-1,D4
	moveq #0,D6
	cmp.w #60,0x59E
	beq.s .find_last_block_060
	move.l A2,D7
	and.l #$FFFFFF,D7
	move.l D7,A2
.find_last_block:
		moves.l (A2),D7
		cmp.l D7,D3
		beq.s .test_free_block
.next_block:
		lea.l SIZE_BLOCK_PARAM(A2),A2
		add.l #SIZE_BLOCK_PARAM,D6                      ; offset free block
	dbf D4,.find_last_block
	moveq #0,D6                                         ; offset free block
	moveq #-1,D7                                        ; erase sector if writing
	bra.s .test_read
.find_last_block_060:
		cmp.l (A2),D3
		beq.s .test_free_block_060
.next_block_060:
		lea.l SIZE_BLOCK_PARAM(A2),A2
		add.l #SIZE_BLOCK_PARAM,D6                      ; offset free block
	dbf D4,.find_last_block_060
	moveq #0,D6                                         ; offset free block
	moveq #-1,D7                                        ; erase sector if writing
	bra.s .test_read	
.test_free_block:
	lea.l 4(A2),A3
	moveq #MAX_PARAM_FLASH-2,D5
.loop_test_free_block:
		moves.l (A3)+,D7
		cmp.l D7,D3
	dbne D5,.loop_test_free_block
	bne.s .next_block 
	moveq #0,D7                                         ; writing inside the next block
	bra.s .test_read
.test_free_block_060:
	lea.l 4(A2),A3
	moveq #MAX_PARAM_FLASH-2,D5
.loop_test_free_block_060:
		cmp.l (A3)+,D3
	dbne D5,.loop_test_free_block_060
	bne.s .next_block_060 
	moveq #0,D7                                         ; writing inside the next block
.test_read:
	move.l A5,8
	move.l A6,SP
	move.l (SP)+,A6
	lea.l -SIZE_BLOCK_PARAM(A2),A2
	move.w D0,D3                                        ; mode
	move.l (A2,D1.L),D0                                 ; actual value
	cmp.w #60,0x59E
	beq.s .read_060
	moves.l (A2,D1.L),D0                                ; actual value
.read_060:
	and.w #1,D3                                         ; mode
	beq .end_read                                       ; read
	cmp.l D0,D2
	beq .end_read                                       ; no change	
	lea -MAX_PARAM_FLASH*4(A6),A3
	addq.l #4,A2
	clr.l (A3)+                                         ; block used
	moveq #MAX_PARAM_FLASH-2,D0
	cmp.w #60,0x59E
	beq.s .save_param_060
.save_param:
		moves.l (A2)+,D3
		move.l D3,(A3)+                                 ; save params in the stack
	dbf D0,.save_param                                  ; before erase sector command
	bra.s .no_cache_060
.save_param_060:
		move.l (A2)+,(A3)+                              ; save params in the stack
	dbf D0,.save_param_060                              ; before erase sector command
	movec.l CACR,D3
	cpusha DC
	bclr.l #31,D3
	movec.l D3,CACR                                     ; no data cache
	cinva DC
.no_cache_060:
	move.l D2,-MAX_PARAM_FLASH*4(A6,D1.L)
	move.l D2,-(SP)                                     ; save value
	lea.l FLASH_UNLOCK1,A0
	lea.l FLASH_UNLOCK2,A1
	lea.l FLASH_ADR+FLASH_SIZE-PARAM_SIZE,A2
	move.w #CMD_UNLOCK1,D3
	move.w #CMD_UNLOCK2,D4
	move.w #CMD_AUTOSELECT,D5
	move.w #CMD_READ,D1
	moves.w D3,(A0)
	moves.w D4,(A1)
	moves.w D5,(A0)                                     ; Autoselect command
	move.l (A2),D0                                      ; Manufacturer code / Device code
	cmp.w #60,0x59E
	beq.s .read_id_060
	moves.l (A2),D0                                     ; Manufacturer code / Device code
.read_id_060:
	moves.w D1,(A2)                                     ; Read/Reset command
	lea.l devices(PC),A3
.loop_dev:
		tst.l (A3)
		beq .no_dev
		cmp.l (A3),D0
		beq.s .found_dev
		addq.l #8,A3
	bra.s .loop_dev
.no_dev:
	addq.w #4,SP
	moveq #-15,D0                                       ; device error
	bra .program_param_end
.found_dev:
	lea.l devices(PC),A1
	add.l 4(A3),A1                                      ; sector of device
	movem.l (A1),A2-A4                                  ; sector, flash_unlock1, flash_unlock2
	add.l D6,A2                                         ; offset free block
	tst.w D7
	beq.s .erase_sector_end
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
	addq.w #4,SP
	moveq #-10,D0                                       ; write error
	bra.s .program_param_loop_end
.erase_sector_end:
	lea -MAX_PARAM_FLASH*4(A6),A0                       ; buffer
	move.w #CMD_PROGRAM,D5
	moveq #(MAX_PARAM_FLASH*2)-1,D6                     ; word counter
.program_byte_loop:
		moveq #15,D7                                    ; retry counter
.program_byte_retry:
			moves.w D3,(A3)
			moves.w D4,(A4)
			moves.w D5,(A3)                             ; Byte program command
			move.w (A0),D0
			moves.w D0,(A2)
			andi.b #0x80,D0
.wait_program_loop:
				move.w (A2),D1
				cmp.w #60,0x59E
				beq.s .wait_program_byte_060
				moves.w (A2),D1
.wait_program_byte_060:
				eor.b D0,D1
				bpl.s .wait_program_loop_end
			btst.l #5,D1
			beq.s .wait_program_loop
			move.w (A2),D1
			cmp.w #60,0x59E
			beq.s .test_program_byte_060
			moves.w (A2),D1
.test_program_byte_060:
			eor.b D0,D1
			bpl.s .wait_program_loop_end
.program_byte_error:
		dbf D7,.program_byte_retry
		addq.w #4,SP
		moveq #-10,D0                                   ; write error
		bra.s .program_param_loop_end
.wait_program_loop_end:
		move.w (A2),D1
		cmp.w #60,0x59E
		beq.s .wait_program_loop_end_060
		moves.w (A2),D1
.wait_program_loop_end_060:
		cmp.w (A0),D1
		bne.s .program_byte_error
		addq.l #2,A2
		addq.l #2,A0
	dbf D6,.program_byte_loop
	move.l (SP)+,D0
.program_param_loop_end:
	move.w #CMD_READ,D5
	moves.w D3,(A3)
	moves.w D4,(A4)
	moves.w D5,(A3)                                     ; Read/Reset command
.program_param_end:
	move.l (SP)+,D2
	cmp.w #60,0x59E
	bne.s .restore_cacr
	cpusha DC
	bra.s .restore_cacr
.out_param:
	moveq #-5,D0                                        ; unimplemented opcode
	bra.s .end_param
.no_flash:
	move.l A5,8                                         ; bus error
	move.l A6,SP
	move.l (SP)+,A6
	moveq #-1,D0                                        ; general error
.end_read:
	move.l (SP)+,D2
	cmp.w #60,0x59E
	beq.s .end_param
.restore_cacr:
	movec.l D2,CACR
.end_param:
	move.w (SP)+,SR
	unlk A6
	movem.l (SP)+,D1-A5
	rts
	
devices:
	dc.l 0x000422AB, fujitsu_mbm29f400bc-devices
	dc.l 0x00042258, fujitsu_mbm29f800ba-devices
	dc.l 0x00012258, amd_am29f800bb-devices
	dc.l 0x00202258, st_m29f800db-devices
	dc.l 0
	
fujitsu_mbm29f400bc:
	dc.l FLASH_ADR+0xF0000, FLASH_UNLOCK1, FLASH_UNLOCK2

fujitsu_mbm29f800ba:
amd_am29f800bb:
st_m29f800db:
	dc.l FLASH_ADR+0xF0000, FLASH_UNLOCK1, FLASH_UNLOCK2	

	end
