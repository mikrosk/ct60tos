; Read on the CT60, the 68060 temperature on the TLV0831 DC from Texas I.
; 2,8 deg celcius / step 
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

	.export ct60_read_temp
	.export ct60_stop
	.export mes_delay
	.export value_supexec
	.import ct60_rw_param

MES_TEMP_0 equ 197
MES_TEMP_25 equ 208
MES_TEMP_50 equ 218
MES_TEMP_100 equ 236
MES_TEMP_ERROR equ 255
CT60_READ_ERROR equ -1
CT60_PARAM_OFFSET_TLV equ 10

_hz_200 equ $4ba
_iera_mfp equ $fffffa07						;MFP registers
_ipra_mfp equ $fffffa0b
_isra_mfp equ $fffffa0f
_imra_mfp equ $fffffa13
_tbcr_mfp equ $fffffa1b
_tbdr_mfp equ $fffffa21						;timer B
_tcdr_mfp equ $fffffa23						;value changed at each 26 uS by system (timer C at 200 Hz)
_flash_space_3 equ $e00000
_texas_tlv0831_data equ $f1000000			;read from D0 (THDA)
_texas_tlv0831_cs_low equ $f1400000			;CS at 0      (/THCS)
_texas_tlv0831_cs_high equ $f1000000		;CS at 1      (THCS)
_texas_tlv0831_clk_low equ $f1800000		;CLK at 0     (/THCK)
_texas_tlv0831_clk_high equ $f1c00000		;CLK at 1     (THCK)
_slp_ct60 equ $fa800000						;sleep => power off (SLP) $f6800000
 
macro WAIT_US

	local wait
	move.b (A0),D0
wait:
	cmp.b (A0),D0							;26uS (timer C) or 1,6uS (timer B)
	beq.s wait
	endm 
 
ct60_read_temp:

	movem.l D1-D3/A0-A2,-(SP)
	move.w SR,-(SP)
	or.w #$700,SR								;no interrupts
	lea.l ct1(PC),A0
	move.l 8,A1								;bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0						;timer C value changed at each 26 uS (clock 19,2 KHz)
	tst.b _tbcr_mfp
	bne ct8									;timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)							;clock = 307,2 KHz 1,6 uS
	move.b #1,_tbcr_mfp						;2,4576MHz/4
ct8:
	clr.l _texas_tlv0831_cs_low				;cs=0
	WAIT_US
	clr.l _texas_tlv0831_clk_high			;clk=1	(10 to 600 KHz for the tlv0831)
	WAIT_US
	clr.l _texas_tlv0831_clk_low			;clk=0
	WAIT_US
	clr.l _texas_tlv0831_clk_high			;clk=1
	WAIT_US
	clr.l _texas_tlv0831_clk_low			;clk=0
	WAIT_US
	move.l A1,8
	move.l A2,SP
	move.w (SP),SR
	moveq #0,D3								;data
	moveq #7,D2								;8 bits
ct4:	clr.l _texas_tlv0831_clk_high		;clk=1
		move.l _texas_tlv0831_data,d1
		lsr.l #1,D1							;data
		addx.w D3,D3
		WAIT_US
		clr.l _texas_tlv0831_clk_low		;clk=0
		WAIT_US
	dbf D2,ct4
	clr.l _texas_tlv0831_cs_high			;cs=1
	cmp.w #MES_TEMP_ERROR,D3				;error
	beq.s ct3
	moveq #0,D2								;value
	moveq #CT60_PARAM_OFFSET_TLV,D1			;type_param
	moveq #0,D0								;read
	jsr ct60_rw_param
	add.l D3,D0								;offset
	cmp.w #MES_TEMP_ERROR,D0				;error
	beq.s ct3
	cmp.w #MES_TEMP_0,D0
	bcs.s ct5
	cmp.w #MES_TEMP_25,D0
	bcc.s ct6
	sub.w #MES_TEMP_0,D0
	mulu #25,D0
	divu #(MES_TEMP_25-MES_TEMP_0),D0
	ext.l D0
	bra.s ct2
ct6:
	cmp.w #MES_TEMP_50,D0
	bcc.s ct7
	sub.w #MES_TEMP_25,D0
	mulu #25,D0
	divu #(MES_TEMP_50-MES_TEMP_25),D0
	add.w #25,D0
	ext.l D0
	bra.s ct2
ct7:
	sub.w #MES_TEMP_50,D0
	mulu #50,D0
	divu #(MES_TEMP_100-MES_TEMP_50),D0
	add.w #50,D0
	ext.l D0
	bra.s ct2
ct5:
	moveq #0,D0
	bra.s ct2
ct3:
	moveq #CT60_READ_ERROR,D0				;error
	bra.s ct2
ct1:
	moveq #CT60_READ_ERROR,D0				;bus error
	move.l A1,8
	move.l A2,SP
ct2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s ct9								;timer C
	clr.b _tbcr_mfp							;timer B stopped
ct9:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D3/A0-A2
	rts
	
ct60_stop:

	or.w #$700,SR
	clr.b _slp_ct60							;power off
	dc.w $f800,$01c0,$2700					;fpstop #$2700
	rts

mes_delay:

	move.l value_supexec,D0
	move.l _hz_200,D1
.1:	subq.l #1,D0							;delay
	bne.s .1
	move.l _hz_200,D0
	sub.l D1,D0
	rts

value_supexec:	dc.l 0

	end
