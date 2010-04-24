;  Didier Mequignon 2003 February, e-mail: aniplay@wanadoo.fr
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

TCK equ 0
TMS equ 1
TDI equ 2
	
TEST_BIT    equ 6 ; D6
PROG_BIT    equ 4 ; D4
CTRL_BIT    equ 3 ; D3
TMS_BIT     equ 2 ; D2
TCK_BIT     equ 1 ; D1
TDI_BIT     equ 0 ; D0
TDO_BIT_MFP equ 6 ; ACK/  

	.export setPort
	.export pulseClock
	.export readTDOBit
	.export test_cable
	
setPort:

	cmp.w #TDI,D0
	bne.s .no_tdi
	btst #0,D1
	bne.s .set_tdi
	bclr #TDI_BIT,out_bits+1
	rts
.set_tdi:
	bset #TDI_BIT,out_bits+1
	rts	
.no_tdi:
	cmp.w #TMS,D0
	bne.s .no_tms
	btst #0,D1
	bne.s .set_tms
	bclr #TMS_BIT,out_bits+1
	rts
.set_tms:
	bset #TMS_BIT,out_bits+1
	rts	
.no_tms:
	move.w out_bits,D0
	btst #0,D1
	bne.s .set_tck
	bclr #TCK_BIT,D0
	bra.s .out_port
.set_tck:
	bset #TCK_BIT,D0
.out_port:
	move.w SR,-(SP)
	or.w #$700,SR
	move.b #15,$FFFF8800      ; port B PSG
	move.b D0,$FFFF8802
	move.w (SP)+,SR
	move.w D0,out_bits
	rts

pulseClock:                   ; toggle TCK LH 

	add.w D0,D0
	subq.w #1,D0
	bmi.s .end_clock
	move.w out_bits,D1
	bclr #TCK_BIT,D1
	move.w SR,-(SP)
	or.w #$700,SR
	move.b #15,$FFFF8800      ; port B PSG
.loop_clock:
		move.b D1,$FFFF8802   ; toggle TCK
		bchg #TCK_BIT,D1
	dbf D0,.loop_clock
	move.w (SP)+,SR
.end_clock:
	rts

readTDOBit:

	move.b $FFFFFA01,D0   ; gpip MFP
	asl.b #TDO_BIT_MFP,D0
	and.w #0x80,D0
	rts

test_cable:

	move.w SR,-(SP)
	or.w #$700,SR
	move.b #15,$FFFF8800  ; port B PSG
	move.b $FFFF8800,D0
	bclr #TEST_BIT,D0
	move.b D0,0xFFFF8802
	bset #TEST_BIT,D0
	btst #0,$FFFFFA01     ; gpip MFP busy
	bne.s .error_test
	move.b D0,0xFFFF8802
	moveq #1,D0
	btst #0,$FFFFFA01     ; gpip MFP busy
	bne.s .end_test
.error_test:
	moveq #0,D0
.end_test:
	move.w (SP)+,SR
	rts
	
out_bits:	dc.w $10      ; PROG_BIT=1 & CTRL_BIT=0
	
	end
