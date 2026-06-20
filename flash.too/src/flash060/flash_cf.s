;  Flashing Firebee
;  Didier Mequignon 2010, e-mail: aniplay@wanadoo.fr
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

FLASH_ADR equ 0xE0000000

MCF_FBCS_CSAR0 equ 0xFF000500
MCF_FBCS_CSMR0 equ 0xFF000504
MCF_FBCS_CSCR0 equ 0xFF000508

FLASH_UNLOCK1 equ (FLASH_ADR+0xAAA)
FLASH_UNLOCK2 equ (FLASH_ADR+0x554)

ERR_DEVICE  equ -1
ERR_ERASE   equ -2
ERR_PROGRAM equ -3
ERR_VERIFY  equ -4
ERR_CT60    equ -5

/* amd - mx devices */
CMD_UNLOCK1	             equ 0xAA
CMD_UNLOCK2              equ 0x55
CMD_SECTOR_ERASE1        equ 0x80
CMD_SECTOR_ERASE2        equ 0x30
CMD_SECTOR_ERASE_SUSPEND equ 0xB0
CMD_SECTOR_ERASE_RESUME  equ 0x30
CMD_PROGRAM              equ 0xA0
CMD_AUTOSELECT           equ 0x90
CMD_READ                 equ 0xF0

	.export get_date_flash_cf
	.export get_version_flash_cf
	.export get_checksum_flash_cf
	.export read_flash_cf
	.export program_flash_cf
	.import flash_device

get_date_flash_cf:

	move.l FLASH_ADR+0x400018,D0                        ; TOS date
	rts

get_version_flash_cf:

	moveq #0,D0
	move.w FLASH_ADR+0x480000,D0                        ; Boot version
	rts

get_checksum_flash_cf:

	moveq #0,D0
	move.w FLASH_ADR+0x47FFFE,D0                        ; checksum
	rts
	
read_flash_cf: ; D0.L: offset, D1.L: total size, A0: target

	move.l D1,-(SP)
	move.l A0,-(SP)
	move.l A1,-(SP)
	lea.l FLASH_ADR,A1
	add.l D0,A1                                         ; offset
	lsr.l #4,D1                                         ; size/16
	moveq #ERR_CT60,D0
.read_cf:
		move.l (A1)+,(A0)+
		move.l (A1)+,(A0)+
		move.l (A1)+,(A0)+
		move.l (A1)+,(A0)+
	subq.l #1,D1
	bgt.s .read_cf
	move.l (SP)+,A1
	move.l (SP)+,A0
	move.l (SP)+,A1
	moveq #0,D0	
	rts

program_flash_cf: ; D0.L: offset, D1.L: total size, A0: source

	lea -56(SP),SP
	movem.l D1-A6,(SP)
	move.l D0,D6                                        ; offset
	add.l D0,A0                                         ; source
	move.l D1,D7                                        ; total size
	move.l #0x00151180,D0                               ; flexbus timmings
	move.l D0,MCF_FBCS_CSCR0
	move.l MCF_FBCS_CSMR0,D0
	bclr.l #8,D0                                        ; unprotect flash
	move.l D0,MCF_FBCS_CSMR0
	moveq #ERR_CT60,D0
	lea.l FLASH_UNLOCK1,A3
	lea.l FLASH_UNLOCK2,A1
	lea.l FLASH_ADR,A2
	move.w #CMD_UNLOCK1,D3
	move.w #CMD_UNLOCK2,D4
	move.w #CMD_AUTOSELECT,D5
	move.w #CMD_READ,D1
	move.w D3,(A3)
	move.w D4,(A1)
	move.w D5,(A3)                                      ; Autoselect command
	move.l (A2),D0
	move.w D1,(A2)                                      ; Read/Reset command
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
.test_free:
		cmp.l (A5)+,D2                                  ; verify sector free
		bne.s .erase_sector
	subq.l #1,D0
	bpl.s.test_free
	bra .erase_sector_end
.erase_sector:
	move.w #CMD_SECTOR_ERASE1,D5
	move.w #CMD_SECTOR_ERASE2,D6

;	cmp.l #0xE0100000,A2
;	bcs.s .erase_error
;	cmp.l #0xE0700000,A2
;	bcs.s .erase_ok
;.erase_error:
;	illegal
;.erase_ok:

	move.w D3,(A3)
	move.w D4,(A4)
	move.w D5,(A3)
	move.w D3,(A3)
	move.w D4,(A4)
	move.w D6,(A2)                                      ; Erase sector command
.wait_erase_loop:
		move.w (A2),D0
		btst.l #7,D0
		bne.s .erase_sector_end
	btst.l #5,D0
	beq.s .wait_erase_loop
	move.w (A2),D0
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

;			cmp.l #0xE0100000,A2
;			bcs.s .program_error
;			cmp.l #0xE0700000,A2
;			bcs.s .program_ok
;.program_error:
;			illegal
;.program_ok:

			move.w D3,(A3)
			move.w D4,(A4)
			move.w D5,(A3)                              ; Byte program command
			move.w (A0),D0
			move.w D0,(A2)
			andi.l #0x80,D0
.wait_program_loop:
				move.w (A2),D2
				eor.l D0,D2
				btst.l #7,D2
				beq.s .wait_program_loop_end
			btst.l #5,D2
			beq.s .wait_program_loop
			move.w (A2),D2
			eor.l D0,D2
			btst.l #7,D2
			beq.s .wait_program_loop_end
.program_byte_error:
		subq.l #1,D6
		bpl.s .program_byte_retry
		moveq #ERR_PROGRAM,D0                           ; error
		bra.s .program_loop_end
.wait_program_loop_end:
		move.w (A2),D2
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
.verify_sector_loop:
		move.w (A2)+,D2
		cmp.w (A5)+,D2                          ; verify sector
		bne.s .verify_error
	subq.l #1,D6
	bpl.s .verify_sector_loop 
	bra.s .program_loop_end
.verify_error:
	moveq #ERR_VERIFY,D0                                ; verify error
.program_loop_end:
	move.w #CMD_READ,D5
	move.w D3,(A3)
	move.w D4,(A4)
	move.w D5,(A3)                                      ; Read/Reset command
.program_end:
	move.l MCF_FBCS_CSMR0,D1
	bset.l #8,D1                                        ; protect flash
	move.l D1,MCF_FBCS_CSMR0
	movem.l (SP),D1-A6
	lea 56(SP),SP
	rts
	
devices:
	dc.l 0x00C222CB, mx_29lv640-devices
	dc.l 0

mx_29lv640:	
	; Bottom Boot
	dc.l FLASH_ADR+0x00000000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA0
	dc.l FLASH_ADR+0x00002000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA1
	dc.l FLASH_ADR+0x00004000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA2
	dc.l FLASH_ADR+0x00006000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA3 
	dc.l FLASH_ADR+0x00008000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA4 
	dc.l FLASH_ADR+0x0000A000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA5 
	dc.l FLASH_ADR+0x0000C000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA6 
	dc.l FLASH_ADR+0x0000E000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA7 
	dc.l FLASH_ADR+0x00010000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA8  
	dc.l FLASH_ADR+0x00020000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA9  
	dc.l FLASH_ADR+0x00030000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA10  
	dc.l FLASH_ADR+0x00040000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA11  
	dc.l FLASH_ADR+0x00050000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA12  
	dc.l FLASH_ADR+0x00060000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA13  
	dc.l FLASH_ADR+0x00070000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA14  
	dc.l FLASH_ADR+0x00080000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA15  
	dc.l FLASH_ADR+0x00090000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA16  
	dc.l FLASH_ADR+0x000A0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA17  
	dc.l FLASH_ADR+0x000B0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA18  
	dc.l FLASH_ADR+0x000C0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA19  
	dc.l FLASH_ADR+0x000D0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA20  
	dc.l FLASH_ADR+0x000E0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA21  
	dc.l FLASH_ADR+0x000F0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA22  
	dc.l FLASH_ADR+0x00100000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA23  
	dc.l FLASH_ADR+0x00110000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA24  
	dc.l FLASH_ADR+0x00120000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA25  
	dc.l FLASH_ADR+0x00130000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA26  
	dc.l FLASH_ADR+0x00140000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA27  
	dc.l FLASH_ADR+0x00150000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA28  
	dc.l FLASH_ADR+0x00160000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA29  
  	dc.l FLASH_ADR+0x00170000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA30  
	dc.l FLASH_ADR+0x00180000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA31  
	dc.l FLASH_ADR+0x00190000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA32  
	dc.l FLASH_ADR+0x001A0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA33  
	dc.l FLASH_ADR+0x001B0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA34  
	dc.l FLASH_ADR+0x001C0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA35  
	dc.l FLASH_ADR+0x001D0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA36  
	dc.l FLASH_ADR+0x001E0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA37  
	dc.l FLASH_ADR+0x001F0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA38                  
	dc.l FLASH_ADR+0x00200000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA39 
	dc.l FLASH_ADR+0x00210000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA40 
	dc.l FLASH_ADR+0x00220000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA41 
	dc.l FLASH_ADR+0x00230000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA42 
	dc.l FLASH_ADR+0x00240000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA43 
	dc.l FLASH_ADR+0x00250000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA44 
	dc.l FLASH_ADR+0x00260000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA45 
	dc.l FLASH_ADR+0x00270000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA46 
	dc.l FLASH_ADR+0x00280000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA47 
	dc.l FLASH_ADR+0x00290000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA48 
	dc.l FLASH_ADR+0x002A0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA49 
	dc.l FLASH_ADR+0x002B0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA50 
	dc.l FLASH_ADR+0x002C0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA51 
	dc.l FLASH_ADR+0x002D0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA52 
	dc.l FLASH_ADR+0x002E0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA53 
	dc.l FLASH_ADR+0x002F0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA54 
	dc.l FLASH_ADR+0x00300000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA55 
	dc.l FLASH_ADR+0x00310000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA56 
	dc.l FLASH_ADR+0x00320000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA57 
	dc.l FLASH_ADR+0x00330000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA58 
	dc.l FLASH_ADR+0x00340000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA59 
	dc.l FLASH_ADR+0x00350000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA60 
	dc.l FLASH_ADR+0x00360000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA61 
	dc.l FLASH_ADR+0x00370000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA62 
	dc.l FLASH_ADR+0x00380000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA63
	dc.l FLASH_ADR+0x00390000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA64 
	dc.l FLASH_ADR+0x003A0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA65 
	dc.l FLASH_ADR+0x003B0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA66 
	dc.l FLASH_ADR+0x003C0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA67 
	dc.l FLASH_ADR+0x003D0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA68 
	dc.l FLASH_ADR+0x003E0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA69 
	dc.l FLASH_ADR+0x003F0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA70 
 	dc.l FLASH_ADR+0x00400000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA71 
	dc.l FLASH_ADR+0x00410000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA72 
	dc.l FLASH_ADR+0x00420000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA73 
	dc.l FLASH_ADR+0x00430000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA74 
	dc.l FLASH_ADR+0x00440000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA75 
	dc.l FLASH_ADR+0x00450000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA76 
	dc.l FLASH_ADR+0x00460000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA77 
	dc.l FLASH_ADR+0x00470000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA78 
	dc.l FLASH_ADR+0x00480000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA79 
	dc.l FLASH_ADR+0x00490000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA80 
	dc.l FLASH_ADR+0x004A0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA81 
	dc.l FLASH_ADR+0x004B0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA82 
	dc.l FLASH_ADR+0x004C0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA83 
	dc.l FLASH_ADR+0x004D0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA84 
	dc.l FLASH_ADR+0x004E0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA85 
	dc.l FLASH_ADR+0x004F0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA86 
	dc.l FLASH_ADR+0x00500000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA87 
	dc.l FLASH_ADR+0x00510000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA88 
	dc.l FLASH_ADR+0x00520000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA89 
	dc.l FLASH_ADR+0x00530000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA90 
	dc.l FLASH_ADR+0x00540000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA91 
	dc.l FLASH_ADR+0x00550000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA92 
	dc.l FLASH_ADR+0x00560000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA93 
	dc.l FLASH_ADR+0x00570000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA94
	dc.l FLASH_ADR+0x00580000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA95
	dc.l FLASH_ADR+0x00590000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA96
   	dc.l FLASH_ADR+0x005A0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA97
	dc.l FLASH_ADR+0x005B0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA98
	dc.l FLASH_ADR+0x005C0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA99
	dc.l FLASH_ADR+0x005D0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA100
	dc.l FLASH_ADR+0x005E0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA101
	dc.l FLASH_ADR+0x005F0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA102
	dc.l FLASH_ADR+0x00600000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA103
	dc.l FLASH_ADR+0x00610000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA104
	dc.l FLASH_ADR+0x00620000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA105
 	dc.l FLASH_ADR+0x00630000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA106
	dc.l FLASH_ADR+0x00640000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA107
	dc.l FLASH_ADR+0x00650000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA108
	dc.l FLASH_ADR+0x00660000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA109
	dc.l FLASH_ADR+0x00670000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA110 
	dc.l FLASH_ADR+0x00680000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA111 
	dc.l FLASH_ADR+0x00690000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA112 
	dc.l FLASH_ADR+0x006A0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA113 
	dc.l FLASH_ADR+0x006B0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA114 
	dc.l FLASH_ADR+0x006C0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA115 
	dc.l FLASH_ADR+0x006D0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA116 
	dc.l FLASH_ADR+0x006E0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA117
	dc.l FLASH_ADR+0x006F0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA118
	dc.l FLASH_ADR+0x00700000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA119
	dc.l FLASH_ADR+0x00710000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA120
	dc.l FLASH_ADR+0x00720000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA121
	dc.l FLASH_ADR+0x00730000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA122
	dc.l FLASH_ADR+0x00740000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA123
	dc.l FLASH_ADR+0x00750000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA124 
	dc.l FLASH_ADR+0x00760000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA125 
	dc.l FLASH_ADR+0x00770000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA126 
	dc.l FLASH_ADR+0x00780000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA127 
	dc.l FLASH_ADR+0x00790000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA128 
	dc.l FLASH_ADR+0x007A0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA129 
	dc.l FLASH_ADR+0x007B0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA130 
	dc.l FLASH_ADR+0x007C0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA131 
	dc.l FLASH_ADR+0x007D0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA132 
	dc.l FLASH_ADR+0x007E0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA133 
	dc.l FLASH_ADR+0x007F0000, FLASH_UNLOCK1, FLASH_UNLOCK2 ; SA134 
	dc.l FLASH_ADR+0x00800000, 0, 0
	
	end
