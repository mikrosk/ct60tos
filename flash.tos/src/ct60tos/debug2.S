/*  Debug the CT60
 * 
 * Didier Mequignon, January 2003, e-mail: didier-mequignon@wanadoo.fr
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

	.globl	exception

exception:

	lea.l mess1(PC),A0
	bsr display_string
             addq.w #1,D1
	move.w D1,D7       // vector number
	moveq #0,D0
	move.w D7,D0
	divu #10,D0
	and.w #7,D0
	beq.s .ex1
	or.w #0x30,D0
	bsr display_char
.ex1:
	swap d0
	or.w #0x30,D0
	bsr display_char
	moveq #0x3A,D0
	bsr display_char
	moveq #0x20,D0
	bsr display_char
	lea.l tab_mess_exc(PC),A0
	move.w D7,D0
	bsr display_tab
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
	lea.l mess2(PC),A0 // SR
	bsr display_string
	move.l 0x3C0,A0    //SSP
	move.w (A0),D0
	bsr hex_word       // SR
	lea.l mess3(PC),A0
	bsr display_string
	move.l 0x3C0,A0    //SSP
	move.w (A0),D2     // SR
	and.w #0xB71F,D2
	lea.l tab_status(PC),A1
	moveq #15,D1
.ex5:
		btst.l D1,D2
		beq.s .ex6
		moveq #0,D0
		move.b (A1,D1),D0
		move.w D0,D3
		and.w #0xF8,D3
		cmp.w #0x30,D3
		bne.s .ex4
		move.w D0,-(SP)
		moveq #0x49,D0 // I
		bsr display_char
		move.w (SP)+,D0
.ex4:
		bsr display_char
		moveq #0x20,D0
		bsr display_char
.ex6:
	dbf D1,.ex5
	lea.l mess4(PC),A0 // PC
	bsr display_string
	move.l 0x3C0,A0    // SSP
	move.l 2(A0),D0    // PC
	bsr hex_long
	lea.l mess10(PC),A0 // Basepage
	bsr display_string
	move.l 0x6EE4,D0
	bsr hex_long
	lea.l mess5(PC),A0 // CACR
	bsr display_string  
	movec.l CACR,D0
	bsr hex_long
	cmp.w #2,D7
	beq.s .ex3         // Acces Fault
	cmp.w #3,D7
	beq.s .ex3         // Adress Error
	cmp.w #5,D7
	beq.s .ex3         // Zero Divide
	cmp.w #9,D7
	bne .ex2           // <> Trace
.ex3:
	lea.l mess6(PC),A0 // adress fault
	bsr display_string
	move.l 0x3C0,A0    // SSP
	move.l 8(A0),D0    // adress fault
	bsr hex_long
	cmp.w #2,D7
	bne .ex2           // <> Acces Fault
	lea.l mess7(PC),A0 // FSLW
	bsr display_string
	move.l 0x3C0,A0    // SSP
	move.l 12(A0),D0   // FSLW
	bsr hex_long
	lea.l mess3(PC),A0
	bsr display_string
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
	move.l 0x3C0,A0  // SSP
	move.l 12(A0),D2 // FSLW
	and.l #0x0BFFFFFD,D2
	lea.l tab_fslw1(PC),A1
	lea.l tab_fslw2(PC),A2
	lea.l tab_fslw3(PC),A3
	moveq #31,D1
	moveq #0,D3
.ex13:
		btst.l D1,D2
		beq.s .ex14
		moveq #0,D0
		move.b (A1,D3),D0
		bsr display_char
		moveq #0,D0
		move.b (A2,D3),D0
		cmp.b #0x20,D0
		beq.s .ex12
		bsr display_char
		moveq #0,D0
		move.b (A3,D3),D0
		cmp.b #0x20,D0
		beq.s .ex12
		bsr display_char
.ex12:
		moveq #0x20,D0
		bsr display_char
.ex14:
		addq.w #1,D3
	dbf D1,.ex13
.ex2:
	lea.l mess8(PC),A0 // SSP
	bsr display_string
	move.l 0x3C0,D0    // SSP
	bsr hex_long
	lea.l mess9(PC),A0 // USP
	bsr display_string
	move.l 0x3C8,D0    // USP
	bsr hex_long
	lea.l 0x384,A1     // registers
	lea.l 32(A1),A2
	moveq #7,D1
.ex8:
		moveq #13,D0
		bsr display_char
		moveq #10,D0
		bsr display_char
		moveq #0x44,D0
		bsr display_char
		moveq #7,D0
		sub.w D1,D0
		or.w #0x30,D0
		move.w D0,-(SP)
		bsr display_nb
		move.l (A1),D0
		bsr hex_long // data registers
		moveq #0x20,D0
		bsr display_char
		tst.w D1
		beq.s .ex9
		moveq #0x41,D0
		bsr display_char
		move.w (SP),D0
		bsr display_nb
		move.l (A2),D0
		bsr hex_long // adress registers
		moveq #0x20,D0
		bsr display_char
.ex9:		
		addq.l #2,SP
		addq.l #4,A1
		addq.l #4,A2
	dbf D1,.ex8
	move.w #2,-(SP)
	move.w #2,-(SP)           // Bconin
	trap #13
	addq.w #4,SP
	rts
	
display_nb:

	bsr display_char
	moveq #0x3A,D0
	bsr display_char
	moveq #0x24,D0
	bsr display_char
	rts
	
display_tab:

	move.w D0,-(SP)
	moveq #0,D0
.dt1:
		cmp.b #-1,(A0)
		beq.s .dt3
		cmp.w (SP),D0
		beq.s .dt4
.dt2:
		tst.b (A0)+
		bne.s .dt2
		addq.w #1,D0
	bra.s .dt1
.dt4:
	bsr display_string
.dt3:
	addq.l #2,SP
	rts
		
hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s hex_word
	move.l (SP)+,D0
hex_word:
	move.w D0,-(SP)
	lsr.w #8,D0          
	bsr.s hex_byte     
	move.w (SP)+,D0
hex_byte:
	move.w D0,-(SP)
	lsr.b #4,D0        
	bsr.s hex_char      
	move.w (SP)+,D0      
hex_char:
	and.b #0xF,D0      
	or.b #0x30,D0      
	cmp.b #0x3A,D0     
	bcs.s display_char  
	addq.b #7,D0   
	    
display_char:
	and.w #0xFF,D0  
	movem.l D0-D2/A0-A2,-(SP)    
	move.w D0,-(sp)
	move.w #2,-(SP)
	move.w #3,-(SP)       // Bconout
	trap #13
	addq.w #6,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts
	
display_string:

	movem.l D0/A0,-(SP)
.os2:
	move.b (A0)+,D0
	beq.s .os1
	bsr display_char
	bra.s .os2
.os1:
	movem.l (SP)+,D0/A0
	rts

mess1:	.byte 13,10
	.asciz "EXCEPTION PROCESSING "
mess2:	.byte 13,10
	.asciz "Status Register (SR): $"
mess3:	.asciz ", bits to 1: "
mess4:	.byte 13,10
	.asciz "Program Counter (PC): $"
mess5:	.byte 13,10
	.asciz "Cache Register (CACR): $"
mess6:	.byte 13,10
	.asciz "Adress Fault: $"	
mess7:	.byte 13,10
	.asciz "Fault Status Word (FSLW): "
mess8:	.byte 13,10
	.asciz "Supervisor Stack (SSP): $"
mess9:	.byte 13,10
	.asciz "User Stack (USP): $"
mess10:	.byte 13,10
	.asciz "Basepage: $"
 
tab_mess_exc:
	.byte 0
	.byte 0
	.asciz "Acces Fault"
	.asciz "Adress Error"
	.asciz "Illegal Instruction"
	.asciz "Integer Zero Divide"
	.byte 0
	.byte 0
	.asciz "Privilege Violation"
	.asciz "Trace"
	.asciz "Line A"
	.asciz "Line F"
	.asciz "Emulator Interrupt"
	.byte 0
	.asciz "Format Error"
	.asciz "Uninitialised Interrupt"
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.asciz "Spurious Interrupt"
	.asciz "Interrupt level 1"
	.asciz "Interrupt level 2" 
	.asciz "Interrupt level 3" 
	.asciz "Interrupt level 4"
	.asciz "Interrupt level 5" 
	.asciz "Interrupt level 6"
	.asciz "Interrupt level 7"
	.asciz "Trap #0"
	.asciz "Trap #1"
	.asciz "Trap #2"
	.asciz "Trap #3"
	.asciz "Trap #4"
	.asciz "Trap #5"
	.asciz "Trap #6"
	.asciz "Trap #7"
	.asciz "Trap #8"
	.asciz "Trap #9"
	.asciz "Trap #10"
	.asciz "Trap #11"
	.asciz "Trap #12"
	.asciz "Trap #13"
	.asciz "Trap #14"
	.asciz "Trap #15"
	.byte -1

tab_status:	.ascii "CVZNX   012 MS T"

tab_fslw1:	.ascii "    M LRWSSTTTTTIPSPPIPSWTRWTB S"
tab_fslw2:	.ascii "    A K  ZZTTMMMOBBTTLFPPWEETP S"
tab_fslw3:	.ascii "         1010210 EEAB    E  RE E"
	