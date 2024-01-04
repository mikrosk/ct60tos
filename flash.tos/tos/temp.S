/* XBIOS CT60, Read the 68060 temperature on the TLV0831 DC from Texas I.
*
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


#include "ct60.h"

#define MES_TEMP_0 197
#define MES_TEMP_25 208
#define MES_TEMP_50 218
#define MES_TEMP_100 236
#define MES_TEMP_ERROR 255

#define _iera_mfp 0xfffffa07               // MFP registers
#define _ipra_mfp 0xfffffa0b
#define _isra_mfp 0xfffffa0f
#define _imra_mfp 0xfffffa13
#define _tbcr_mfp 0xfffffa1b
#define _tbdr_mfp 0xfffffa21               // timer B
#define _tcdr_mfp 0xfffffa23               // value changed at each 26 uS by system (timer C at 200 Hz)
#define _texas_tlv0831_data     0xf1000000 // read from D0 (THDA)
#define _texas_tlv0831_cs_low   0xf1400000 // CS at 0      (/THCS)
#define _texas_tlv0831_cs_high  0xf1000000 // CS at 1      (THCS)
#define _texas_tlv0831_clk_low  0xf1800000 // CLK at 0     (/THCK)
#define _texas_tlv0831_clk_high 0xf1c00000 // CLK at 1     (THCK)

#define CT60_READ_ERROR -1

	.globl ct60_read_temp
	
	.text

ct60_read_temp:

	movem.l D1-D3/A0-A2,-(SP)
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
	lea ct1(PC),A0
	move.l 8,A1              // bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         // timer C value changed at each 26 uS (clock 19,2 KHz)
	tst.b _tbcr_mfp
	bne ct8                  // timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           // clock = 307,2 KHz 1,6 uS
	move.b #1,_tbcr_mfp      // 2,4576MHz/4
ct8:
	clr.l _texas_tlv0831_cs_low // cs=0
	move.b (A0),D0
wait1:
	cmp.b (A0),D0            // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait1
	clr.l _texas_tlv0831_clk_high // clk=1	(10 to 600 KHz for the tlv0831)
	move.b (A0),D0
wait2:
	cmp.b (A0),D0            // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait2
	clr.l _texas_tlv0831_clk_low // clk=0
	move.b (A0),D0
wait3:
	cmp.b (A0),D0            // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait3
	clr.l _texas_tlv0831_clk_high // clk=1
	move.b (A0),D0
wait4:
	cmp.b (A0),D0            // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait4
	clr.l _texas_tlv0831_clk_low // clk=0
	move.b (A0),D0
wait5:
	cmp.b (A0),D0            // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait5
	move.l A1,8
	move.l A2,SP
	move.w (SP),SR
	moveq #0,D3              // data
	moveq #7,D2              // 8 bits
ct4:	clr.l _texas_tlv0831_clk_high // clk=1
		move.l _texas_tlv0831_data,d1
		lsr.l #1,D1          // data
		addx.w D3,D3
		move.b (A0),D0
wait6:
		cmp.b (A0),D0        // 26uS (timer C) or 1,6uS (timer B)
		beq.s wait6
		clr.l _texas_tlv0831_clk_low // clk=0
		move.b (A0),D0
wait7:
		cmp.b (A0),D0        // 26uS (timer C) or 1,6uS (timer B)
		beq.s wait7
	dbf D2,ct4
	clr.l _texas_tlv0831_cs_high // cs=1
	cmp.w #MES_TEMP_ERROR,D3 // error
	beq.s ct3
	moveq #0,D2              // value
	moveq #CT60_PARAM_OFFSET_TLV,D1 // type_param
	moveq #CT60_MODE_READ,D0 // read
	bsr ct60_rw_param
	add.l D3,D0              // offset
	bmi.s ct5
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
	moveq #CT60_READ_ERROR,D0 // error
	bra.s ct2
ct1:
	moveq #CT60_READ_ERROR,D0 // bus error
	move.l A1,8
	move.l A2,SP
ct2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s ct9                // timer C
	clr.b _tbcr_mfp          // timer B stopped
ct9:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D3/A0-A2
	rts
	
