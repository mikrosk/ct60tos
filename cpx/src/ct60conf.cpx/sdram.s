; Configure the CT60-SDRAM
;
; Didier Mequignon 2001 December, e-mail: didier.mequignon@wanadoo.fr
;
;  This library is free software; you can redistribute it and/or
;  modify it under the terms of the GNU Lesser General Public
;  License as published by the Free Software Foundation; either
;  version 2.1 of the License, or (at your option) any later version.
;
;  This library is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;  Lesser General Public License for more details.
;
;  You should have received a copy of the GNU Lesser General Public
;  License along with this library; if not, write to the Free Software
;  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

	.export ct60_read_info_sdram
	.export ct60_configure_sdram
	
SLAVE_ADRESS            equ $A0 ;7 bits 1010xxx + r/w

CT60_READ_ERROR         equ -1
CT60_CHIP_DENSITY_ERROR equ -2
CT60_NUM_BANK_ERROR     equ -3
CT60_MOD_DENSITY_ERROR  equ -4
CT60_BURST_LENGTH_ERROR equ -5
CT60_DATA_WIDTH_ERROR   equ -6
CT60_VOLTAGE_ERROR      equ -7
CT60_SDRAM_TYPE_ERROR   equ -8
CT60_REFRESH_RATE_ERROR equ -9

_gpip_mfp equ $fffffa01
_ddr_mfp  equ $fffffa05
_iera_mfp equ $fffffa07      ;MFP registers
_ipra_mfp equ $fffffa0b
_isra_mfp equ $fffffa0f
_imra_mfp equ $fffffa13
_tbcr_mfp equ $fffffa1b
_tbdr_mfp equ $fffffa21      ;timer B
_tcdr_mfp equ $fffffa23      ;timer C
_scl_low equ $f0000000       ;write 0 to SCL line (clock)
_scl_high equ $f0400000      ;write 1 to SCL line (clock)
_sda_low equ $f0800000       ;write 0 to SDA line (data)
_sda_high equ $f0c00000      ;write 1 to SDA line (data) 
_sda equ $f0000000           ;read from SDA line on the D0 CPU data bus
_sdcnf equ $f2000000         ;SDRAM configuration $f2xx0000 

macro WAIT_US

	local wait
	move.b (A0),D0
wait:
	cmp.b (A0),D0            ;26uS (timer C) or 6,5uS (timer B)
	beq.s wait
	endm 
 
ct60_read_info_sdram:        ;A0: 128 bytes buffer, D0 return error

	movem.l D1-D3/A0-A3,-(SP) 
	move.l A0,A3
	move SR,-(SP)
	or #$700,SR              ;no interrupts
	lea .1(PC),A0
	move.l 8,A1              ;bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         ;timer C value changed at each 26 uS (clock 19,2 KHz)
	tst.b _tbcr_mfp
	bne.s .6                 ;timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           ;clock = 78,125 KHz (value changed at each 6,4 uS)
	move.b #3,_tbcr_mfp      ;2,4576MHz/16
.6:
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	bsr write_device_i2c
	moveq #0,D0              ;write adress
	bsr write_bit_i2c        ;r/w
	bsr read_bit_i2c         ;ack
	btst #0,D0 
	bne .3                   ;no acknoledge
	moveq #0,D0
	bsr write_bit_wait_slave_i2c ;adress 1st bit
	moveq #6,D2              ;8 bits
.4:		moveq #0,D0          ;adress
		bsr write_bit_i2c
	dbf D2,.4
	bsr read_bit_i2c         ;ack
	bne.s .3                 ;no acknoledge
	bsr start_bit_wait_slave_i2c
	bsr write_device_i2c
	moveq #1,D0              ;read data
	bsr write_bit_i2c        ;r/w
	bsr read_bit_i2c         ;ack
	btst #0,D0 
	bne.s .3                 ;no acknoledge
	moveq #127,D3            ;128 bytes
.8:
		moveq #0,D1          ;data
		bsr read_bit_wait_slave_i2c  ;1st bit
		lsr.l #1,D0          ;data
		addx.w D1,D1
		moveq #6,D2          ;8 bits
.5:
			bsr read_bit_i2c
			lsr.l #1,D0      ;data
			addx.w D1,D1
		dbf D2,.5
		move.b D1,(A3)+
		tst D3
		seq.b D0
		and #1,D0            ;ack master = 1 => no other byte
		bsr write_bit_i2c
	dbf D3,.8
	bsr stop_bit_i2c
	moveq #0,D0 ; OK
	bra.s .2
.3:
	bsr stop_bit_i2c
	moveq #CT60_READ_ERROR,D0    ;error
	bra.s .2
.1:
	moveq #CT60_READ_ERROR,D0    ;bus error
	move.l A1,8
	move.l A2,SP
.2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s .7
	clr.b _tbcr_mfp          ;timer B stopped
.7:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D3/A0-A3
	rts

ct60_configure_sdram:

	movem.l D1-D2/A0-A1,-(SP)
	lea _sdcnf,A0
	moveq #2,D0              ;memory type
	bsr read_i2c_sdram
	bmi .1                   ;error
	cmp #4,D0                ;SDRAM
	beq.s .13
	moveq #CT60_SDRAM_TYPE_ERROR,D0
	bra .1 
.13:
	moveq #3,D0              ;number of row adresses
	bsr read_i2c_sdram
	bmi .1                   ;error
	move D0,D1
	moveq #4,D0              ;number of column adresses
	bsr read_i2c_sdram
	bmi .1                   ;error
	lea chip_density(PC),A1
.3:
	tst.w (a1)
	ble.s .2                 ;not found => chip density error
	cmp.w (A1),D1            ;number of raw adresses
	bne.s .4
	cmp.w 2(A1),D0           ;number of column adresses
	beq.s .5                 ;found
.4:
	addq #8,A1
	bra.s .3
.2: 
	moveq #CT60_CHIP_DENSITY_ERROR,D0
	bra .1
.5:
	add.l 4(A1),A0           ;chip density on A23-A22
	moveq #12,D0             ; refresh rate
	bsr read_i2c_sdram
	bmi .1                   ; error
	and.w #$7F,D0
	cmp.w #5,D0
	bhi.s .16                ; error
	cmp.w #1,D0
	beq.s .16                ; 3.9 uS => error
	cmp.w #2,D0
	bne.s .17
	add.l #$10000,A0         ; A16 7.81 uS
	bra.s .17	
.16:
	moveq #CT60_REFRESH_RATE_ERROR,D0
	bra .1
.17:		
	moveq #5,D0              ;number of DIMM banks
	bsr read_i2c_sdram
	bmi .1                   ;error
	cmp.w #1,D0
	beq.s .6
	cmp.w #2,D0
	bne.s .7                 ;num bank error
	add.l #$100000,A0        ;A20
	bra.s .6
.7: 
	moveq #CT60_NUM_BANK_ERROR,D0
	bra .1
.6:
	move d0,d1               ;number of DIMM banks
	moveq #6,D0              ;module data width
	bsr read_i2c_sdram
	bmi .1                   ;error
	cmp.w #$40,D0
	bne.s .11                ;data width error
	moveq #7,D0              ;module data width
	bsr read_i2c_sdram
	bmi .1                   ;error
	beq.s .14
.11:
	moveq #CT60_DATA_WIDTH_ERROR,D0
	bra .1
.14:
	moveq #8,D0              ;voltage interface
	bsr read_i2c_sdram
	bmi .1                   ;error
	cmp.w #1,D0              ;LVTTL
	beq.s .12
	moveq #CT60_VOLTAGE_ERROR,D0
	bra.s .1
.12:
	moveq #17,D0             ;number of banks on SDRAM device
	bsr read_i2c_sdram
	bmi.s .1                 ;error
	cmp.w #4,D0
	bne.s .7                 ;num bank error
	moveq #31,D0             ;module density
	bsr read_i2c_sdram
	bmi.s .1                 ;error
	cmp.w #8,D0
	beq.s .10                ;32
	cmp.w #16,D0
	beq.s .10                ;64
	cmp.w #32,D0
	beq.s .10                ;128
	cmp.w #64,D0
	beq.s .10                ;256
	cmp.w #128,D0
	bne.s .8                 ;<> 512 => module density error
.10:
	mulu D1,D0               ;* number of DIMM banks
	asl.w #2,D0              ;MB
	cmp.w #64,D0
	beq.s .9
	cmp.w #128,D0
	beq.s .9
	cmp.w #256,D0
	beq.s .9
	cmp.w #512,D0
	beq.s .9
.8: 
	moveq #CT60_MOD_DENSITY_ERROR,D0
	bra.s .1
.9:
	lsr.w #7,d0
	cmp.w #3,d0
	bcs.s .15
	moveq #3,D0
.15:
	move.l D0,D1
	swap D1
	asl.l #2,D1
	add.l D1,A0              ;size on A19-A18
	clr.l (A0)               ;write config
	tst.l D0                 ;return size 0-3 for 64MB-512MB
.1:
	movem.l (SP)+,D1-D2/A0-A1
	rts
 
read_i2c_sdram:              ;D0: adress, D0 return data or error

	movem.l D1-D2/A0-A2,-(SP)
	move SR,-(SP)
	or #$700,SR              ;no interrupts
	lea .1(PC),A0
	move.l 8,A1              ;bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         ;timer C value changed at each 26 uS (clock 19,2 KHz)
	tst.b _tbcr_mfp
	bne.s .6                 ;timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           ;clock = 78,125 KHz (value changed at each 6,4 uS)
	move.b #3,_tbcr_mfp      ;2,4576MHz/16
.6:
	move D0,D1               ;adress
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	bsr write_device_i2c
	moveq #0,D0              ;write adress
	bsr write_bit_i2c        ;r/w
	bsr read_bit_i2c         ;ack
	btst #0,D0 
	bne .3                   ;no acknoledge
	moveq #0,D0
	add.b D1,D1  
	addx.b D0,D0             ;adress 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              ;8 bits
.4:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         ;adress
		bsr write_bit_i2c
	dbf D2,.4
	bsr read_bit_i2c         ;ack
	bne.s .3                 ;no acknoledge
	bsr start_bit_wait_slave_i2c
	bsr write_device_i2c
	moveq #1,D0              ;read data
	bsr write_bit_i2c        ;r/w
	bsr read_bit_i2c         ;ack
	btst #0,D0 
	bne.s .3                 ;no acknoledge
	moveq #0,D1              ;data
	bsr read_bit_wait_slave_i2c ;1st bit
	lsr.l #1,D0              ;data
	addx.w D1,D1
	moveq #6,D2              ;8 bits
.5:
		bsr read_bit_i2c
		lsr.l #1,D0          ;data
		addx.w D1,D1
	dbf D2,.5
	moveq #1,D0              ;ack master = 1 => no other byte
	bsr write_bit_i2c
	bsr stop_bit_i2c
	moveq #0,D0
	move D1,D0               ;8 bits data
	bra.s .2
.3:
	bsr stop_bit_i2c
	moveq #CT60_READ_ERROR,D0    ;error
	bra.s .2
.1:
	moveq #CT60_READ_ERROR,D0    ;bus error
	move.l A1,8
	move.l A2,SP
.2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s .7
	clr.b _tbcr_mfp          ;timer B stopped
.7:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D2/A0-A2
	rts
 
write_device_i2c:

	movem.l D0-D2,-(SP)
	move #SLAVE_ADRESS,D1
	moveq #6,D2              ;7 bits $A0      ;7 bits 1010xxx
.1:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         ;device
		bsr write_bit_i2c
	dbf D2,.1
	movem.l (SP)+,D0-D2
	rts

read_bit_i2c:

	clr.l _sda_high          ;data=1 initial state (open drain)
	WAIT_US                  ;100 KHz max !  
	clr.l _scl_high          ;clk=1  
	WAIT_US
	move.l _sda,d0           ;data on D0  
	clr.l _scl_low           ;clk=0
	btst #0,D0
	rts 
 
read_bit_wait_slave_i2c:

	move.l D1,-(SP)
	clr.l _sda_high          ;data=1 initial state (open drain)
	WAIT_US
	clr.l _scl_high          ;clk=1 
	moveq #31,D1             ;time-out slave busy
r1:
		WAIT_US              ;100 KHz max !
		move.l _sda,d0       ;SCL slave on B1
		btst #1,D0
	dbne D1,r1
	move.l _sda,d0           ;data on B0  
	clr.l _scl_low           ;clk=0  
	move.l (SP)+,D1   
	btst #0,D0
	rts 
 
write_bit_i2c:

	tst.w D0
	bne.s .w1
	clr.l _sda_low           ;data=0  
	bra.s .w2
.w1:
	clr.l _sda_high          ;data=1  
.w2:
	WAIT_US                  ;100 KHz max !  
	clr.l _scl_high          ;clk=1
	WAIT_US
	clr.l _scl_low           ;clk=0  
	rts 
 
write_bit_wait_slave_i2c:

	move.l D1,-(SP)
	tst.w D0
	bne.s w1
	clr.l _sda_low           ;data=0  
	bra.s w2
w1:
	clr.l _sda_high          ;data=1  
w2:
	WAIT_US
	clr.l _scl_high          ;clk=1
	moveq #31,D1             ;time-out slave busy
w3:
		WAIT_US              ;100 KHz max !  
		move.l _sda,d0       ;SCL slave on B1
		btst #1,D0
	dbne D1,w3 
	clr.l _scl_low           ;clk=0
	move.l (SP)+,D1  
	rts 
 
start_bit_i2c:

	clr.l _sda_high          ;data=1 initial state
	clr.l _scl_high          ;clk=1  
	WAIT_US                  ;100 KHz max !  
	clr.l _sda_low           ;data=0 => start condition 
	WAIT_US
	clr.l _scl_low           ;clk=0
	rts

start_bit_wait_slave_i2c:

	move.l D1,-(SP)
	clr.l _sda_high          ;data=1 initial state
	WAIT_US                  ;100 KHz max !  
	clr.l _scl_high          ;clk=1  
	moveq #31,D1             ;time-out slave busy
s1:
		WAIT_US              ;100 KHz max !  
		move.l _sda,D0       ;SCL slave on B1
		btst #1,D0
	dbne D1,s1  
	clr.l _sda_low           ;data=0 => start condition 
	WAIT_US
	clr.l _scl_low           ;clk=0
	move.l (SP)+,D1
	rts
 
stop_bit_i2c:

	clr.l _sda_low           ;data=0 
	WAIT_US                  ;100 KHz max !
	clr.l _scl_high          ;clk=1  
	WAIT_US 
	clr.l _sda_high          ;data=1 => stop condition
	WAIT_US
	rts

chip_density:                      ; A23-A22 cdy2-1

	dc.w $C,$9,$00,0      ; 8Mx8b / 8Mx16b
	dc.w $C,$A,$40,0      ; 16Mx8b
	dc.w $D,$9,$80,0      ; 16Mx16b
	dc.w $D,$A,$C0,0      ; 32Mx8b / 32Mx16b
	dc.w 0,0,0,0          ; end

	end
