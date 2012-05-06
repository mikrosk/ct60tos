;*********************************************************************************
;* Helper functions for ST assembler programming					*
;*	Copyright 2001 Dr. Thomas Redelberger					*
;*	Use it under the terms of the GNU General Public License		*
;*	(See file COPYING.TXT)							*
;*********************************************************************************
;* $Id: uti.s 1.1 2002/03/24 13:48:44 Thomas Exp Thomas $
;*

;*
;* entry points and references in this module
;*

		.import main

		.export	prntStr		; (); debugging
		.export	prntLong	; (); "
		.export	prntWord	; (); "
		.export	prntByte	; (); "
		.export	prntSR		; (); "
		.export led_floppy	; (); "
		.export code_led	; (); "

		.export	swap_short
		.export	swap_long
		.export	udelay
		.export splx
		.export semaphore_take
		
        .export errno
        
        jmp	main

;**** Debugging code *************************************************************

;******** prntLong *****************************************************
;* print longword
;*	cdecl void prntLong(long arg);
;***********************************************************************

prntLong:

		movem.l	d0-d2/d6/d7/a0-a2,-(sp)		; save used regs.
		move.l	8*4+4(sp),d6		; get longword
		moveq.l	#7,d7
		bra.b	prntNibbles

;******** prntWord *****************************************************
;* print word
;*	cdecl void prntWord(short arg);
;***********************************************************************

prntWord:

		movem.l	d0-d2/d6/d7/a0-a2,-(sp)		; save used regs.
		move	8*4+4(sp),d6		; get word
		swap	d6			; in upper word
		moveq.l	#3,d7
		bra.b	prntNibbles

******** prntByte *****************************************************
* print byte
*	cdecl void prntByte(char arg);
***********************************************************************

prntByte:

		movem.l	d0-d2/d6/d7/a0-a2,-(sp)		; save used regs.
		move.b	8*4+4(sp),d6		; get byte
		swap	d6			; in upper word
		lsl.l	#8,d6			; in upper byte
		moveq.l	#1,d7
*		fall thru to prntNibbles

prntNibbles:

		moveq	#0,d0			; clear word
		lsl.l	#1,d6			; in extend bit
		roxl.b	#1,d0			; from extend bit
		lsl.l	#1,d6			; in extend bit
		roxl.b	#1,d0			; from extend bit
		lsl.l	#1,d6			; in extend bit
		roxl.b	#1,d0			; from extend bit
		lsl.l	#1,d6			; in extend bit
		roxl.b	#1,d0			; from extend bit
		move.b	.HexTab(pc,d0.w),d0	; get hex character
		move	d0,-(sp)		; arg: the char
		move.l	#$00030002,-(sp)	; 2 args: VT52-console (2), Bconout (3)
		trap	#13			; Bios
		addq.l	#6,sp			; pop args
		dbra	d7,prntNibbles

		movem.l	(sp)+,d0-d2/d6/d7/a0-a2
		rts

.HexTab:		DC.B	"0123456789abcdef"

;******** prntSR *******************************************************

prntSR:

		move	SR,-(sp)
		bsr.b	prntWord
		addq.l	#2,sp
		rts

;******** prntStr ****************************************************************
;* prints message on screen (VT52 codes)
;*	cdecl void prntStr(char *message);
;*********************************************************************************

prntStr:

		movem.l	d0-d2/a0-a2/a6,-(sp)
		move.l	4*7+4(sp),a6		; get pointer to string
		bra.b	.b1

.t1:
		move	d0,-(sp)		; arg: the char
		move.l	#$00030002,-(sp)	; 2 args: VT52-console, Bconout
		trap	#13			; Bios
		addq.l	#6,sp			; pop args
.b1:
		moveq	#0,d0			; unsigned extend
		move.b	(a6)+,d0
		bne.b	.t1

		movem.l	(sp)+,d0-d2/a0-a2/a6
		rts

;*********************************************************************************
;* visual debug
;*********************************************************************************

led_floppy:

		lea 0xFFFF8800,a0        ; PSG soun
		moveq #7,d0
		move.b d0,(a0)           ; ports A & B
		move.b #$c0,d0           ; are outputs
		move.b d0,2(a0)
		moveq #14,d0             ; port A
		move.b d0,(a0)
		tst.w 4(sp)
		seq.b d0
		and.b #7,d0              ; disable floppy: 7
		move.b d0,2(a0)
		rts
		
tempo_mfp:

		movem.l d0/a0,-(sp)
		lea $fffffa01,a0         ; MFP 68901
		clr.b 24(a0)             ; TACR stop timer A
		bclr #5,18(a0)           ; IMRA interrupt mask timer A
		bclr #5,6(a0)            ; IERA
		bclr #5,10(a0)           ; IPRA no pending
		bclr #5,14(a0)           ; ISRA
		moveq #49,d0             ; 0.5 S
.tm1:
			move.b #124,30(a0)       ; TADR init timer A MFP for 10091 uS
			move.b #7,24(a0)         ; TACR (prediv /200)
			bset #5,6(a0)            ; IERA enable
			bclr #5,10(a0)           ; IPRA clear timer A
.tm2:
			btst #5,10(a0)           ; IPRA wait timer A
			beq.s .tm2
			clr.b 24(a0)             ; TACR stop timer A
		dbf d0,.tm1
		movem.l (sp)+,d0/a0
		rts
		
code_led:

		move.w 4(sp),d0          ; code
		subq.w #1,d0
		bmi.s .cl1
.cl2:
			move.w d0,-(sp)
			move.w #1,-(sp)
			bsr led_floppy
			bsr tempo_mfp
			clr.w (sp)
			bsr led_floppy
			addq.l #2,sp
			bsr tempo_mfp
			move.w (sp)+,d0
		dbf D0,.cl2
.cl1:
		bsr tempo_mfp
		bsr tempo_mfp
		bsr tempo_mfp
		bsr tempo_mfp
		rts		

;*********************************************************************************
;**** Endian functions ***********************************************************
;*********************************************************************************

swap_short:

		move.w	4(sp),d0
		ror.w	#8,d0
		ext.l	d0
		rts

swap_long:

		move.l	4(sp),d0
		ror.w	#8,d0
		swap 	d0
		ror.w	#8,d0
		rts
	
;*********************************************************************************
;**** udelay *********************************************************************
;*********************************************************************************

udelay:

		move.w	4(sp),d0
.d3:
			tst.w	d0
			ble.s	.d1
			move.b	$fffffa23,d1
.d2:
			cmp.b	$fffffa23,d1		; 26 uS timer C MFP
			beq.s	.d2
			sub.w	#26,d0
		bra.s	.d3
.d1:
		rts

;*********************************************************************************
;**** splx ***********************************************************************
;*********************************************************************************

splx:

		move.w	d6,-(sp)
		move.w	d7,-(sp)
		move.w	8(sp),d6
		move.w	sr,d7
		move.w	d7,d0
		and.w	#$700,d0
		lsr.w	#8,d0
		and.w	#7,d6
		lsl.w	#8,d6
		and.w	#$F8FF,d7
		or.w	d6,d7
		move.w	d7,sr
		move.w	(sp)+,d7
		move.w	(sp)+,d6
		rts

;*********************************************************************************

        .data
        
errno:
        .DC.W   0
		
		.end

