
;DSPXBIOS

INC EQU ADDQ #1,
DEC EQU SUBQ #1,

TAILLE_PILE EQU 1800

MAX_SUBROUT_DSP EQU 8

;variables systŠme
SAVPTR EQU $4A2

_TRANSMITTER EQU $16F0
_RECEIVER EQU $16F4
_PARAMS_IRQ_DSP EQU $16F8
_TAB_SUBROUT_DSP EQU $1720
_HIMEM_DSP EQU $1780
_HIMEM_INIT EQU $1784
_RESERVE_DSP EQU $1788
_ABILITY EQU $178C
_COMPT_SUBROUT EQU $178E
_COMPT_ABILITY EQU $1790
_D_LOCK EQU $17DE

;              Falcon DSP Host Interface
;-------+-----+-----------------------------------------------------+---
;$FFA200|byte |Interrupt Ctrl Register           BIT 7 6 5 4 3 . 1 0|R/W
;X:$FFE9|     |INIT bit -----------------------------' | | | |   | ||
;       |     |00 - Interupt mode (DMA off) -----------+-+ | |   | ||
;       |     |01 - 24-bit DMA mode -------------------+-+ | |   | ||
;       |     |10 - 16-bit DMA mode -------------------+-+ | |   | ||
;       |     |11 - 8-bit DMA mode --------------------+-' | |   | ||
;       |     |Host Flag 1 --------------------------------' |   | ||
;       |     |Host Flag 0 ----------------------------------'   | ||
;       |     |         Host mode Data transfers:                | ||
;       |     |              Interrupt mode                      | ||
;       |     |00 - No interrupts (Polling) ---------------------+-+|
;       |     |01 - RXDF Request (Interrupt) --------------------+-+|
;       |     |10 - TXDE Request (Interrupt) --------------------+-+|
;       |     |11 - RXDF and TXDE Request (Interrupts) ----------+-+|
;       |     |                 DMA Mode                         | ||
;       |     |00 - No DMA --------------------------------------+-+|
;       |     |01 - DSP to Host Request (RX) --------------------+-+|
;       |     |10 - Host to DSP Request (TX) --------------------+-+|
;       |     |11 - Undefined (Illegal) -------------------------+-'|
;$FFA201|byte |Command Vector Register           BIT 7 . . 4 3 2 1 0|R/W
;X:$FFE9|     |Host Command Bit (Handshake)----------'     | | | | ||
;       |     |Host Vector (0-31) -------------------------+-+-+-+-'|
;$FFA202|byte |Interrupt Status Reg              BIT 7 6 . 4 3 2 1 0|R  
;X:$FFE8|     |ISR Host Request ---------------------' |   | | | | ||
;       |     |ISR DMA Status -------------------------'   | | | | ||
;       |     |Host Flag 3 --------------------------------' | | | ||
;       |     |Host Flag 2 ----------------------------------' | | ||
;       |     |ISR Transmitter Ready (TRDY) -------------------' | ||
;       |     |ISR Transmit Data Register Empty (TXDE) ----------' ||
;       |     |ISR Receive Data Register Full (RXDF) --------------'|
;$FFA203|byte |Interrupt Vector Register                            |R/W
;$FFA204|byte |Unused                                               |   
;$FFA205|byte |DSP-Word High                                        |R/W
;X:$FFEB|     |                                                     |
;$FFA206|byte |DSP-Word Mid                                         |R/W
;X:$FFEB|     |                                                     |
;$FFA207|byte |DSP-Word Low                                         |R/W
;X:$FFEB|     |                                                     |


INIT_DSP:

 MOVEM.L D1-D2/A0-A2,-(SP)
 MOVEQ #0,D1
 LEA _TAB_SUBROUT_DSP,A0
 MOVEQ #MAX_SUBROUT_DSP-1,D2
\1:CLR.L (A0)
  MOVE D1,D0
  ADD #23,D0
  MOVE D0,8(A0)
  CLR 10(A0)                                                                            
  INC D1
  LEA 12(A0),A0
 DBRA D2,\1
 MOVE.L #$7EA8,D0
 MOVE.L D0,_HIMEM_INIT
 MOVE.L D0,_HIMEM_DSP
 CLR.L _RESERVE_DSP
 CLR _ABILITY
 CLR _COMPT_SUBROUT
 MOVE #$8000,_COMPT_ABILITY
 MOVEQ #82,D0
 MOVE.L D0,-(SP);taille start
 PEA BOOT_INIT_DSP(PC);buffer start
 BSR DET_DSP_EXECBOOT
 ADDQ #8,SP
 bmi.s \3

; pea string12(pc)
; bsr display_string
; addq.w #4,SP 
; BSR AFF_REG_DSP
 
 CLR.L -(SP);taille r‚ception
 CLR.L -(SP);buffer r‚ception
 MOVE.L #152,-(SP);taille ‚mission
 PEA DATA_INIT_DSP(PC);buffer ‚mission
 BSR DET_DSP_BLKHANDSHAKE
 LEA 16(SP),SP
 bmi.s \3
 LEA XBIOS_DSP(PC),A0
 MOVE.L A0,$B8;TRAP #14
 moveq #0,D0
 BRA.S \2
\3:LEA XBIOS_DSP(PC),A0
 MOVE.L A0,$B8;TRAP #14
 moveq #-1,D0
\2:MOVEM.L (SP)+,D1-D2/A0-A2
 RTS

XBIOS_DSP:;sur FALCON

 LEA TAB_DSP(PC),A0
 MOVE.L USP,A1
 BTST #5,(SP);appel en superviseur
 BEQ.S \2
 LEA 6(SP),A1
 TST (A1)+;mot suppl‚mentaire sur la pile si > 68000
\2:MOVE (A1)+,D0;fonction
 SUB (A0)+,D0;DSP_DOBLOCK
 BMI.S \1;<> fonctions DSP
 CMP (A0)+,D0
 BCC.S \1;<> fonctions DSP
 ASL #2,D0
 MOVE.L (A0,D0),D0
 BLE.S \1;routine d'origine
 LEA TAB_DSP(PC),A0
 ADD.L A0,D0
 MOVE.L SAVPTR,A0
 MOVE (SP)+,-(A0);SR
 MOVE.L (SP)+,-(A0);PC
 TST (SP)+;mot suppl‚mentaire sur la pile si > 68000
 MOVEM.L D3-D7/A3-A7,-(A0)
 MOVE.L A0,SAVPTR
 MOVE.L A1,SP
 MOVE.L D0,A0
 JSR (A0)
 MOVE.L SAVPTR,A1
 MOVEM.L (A1)+,D3-D7/A3-A7
 CLR -(SP);mot suppl‚mentaire sur la pile si > 68000
 MOVE.L (A1)+,-(SP);PC
 MOVE (A1)+,-(SP);SR
 MOVE.L A1,SAVPTR
\1:RTE

TAB_DSP:
 DC.W 96,32;index de d‚part, nbre de fonctions
 DC.L DET_DSP_BLKHANDSHAKE-TAB_DSP;DSP_DOBLOCK (96)
 DC.L DET_DSP_BLKHANDSHAKE-TAB_DSP
 DC.L DET_DSP_BLKUNPACKED-TAB_DSP
 DC.L DET_DSP_INSTREAM-TAB_DSP
 DC.L DET_DSP_OUTSTREAM-TAB_DSP
 DC.L DET_DSP_IOSTREAM-TAB_DSP
 DC.L DET_DSP_REMOVEINTERRUPTS-TAB_DSP
 DC.L DET_DSP_GETWORDSIZE-TAB_DSP
 DC.L DET_DSP_LOCK-TAB_DSP
 DC.L DET_DSP_UNLOCK-TAB_DSP
 DC.L DET_DSP_AVAILABLE-TAB_DSP
 DC.L DET_DSP_RESERVE-TAB_DSP
 DC.L DET_DSP_LOADPROG-TAB_DSP
 DC.L DET_DSP_EXECPROG-TAB_DSP
 DC.L DET_DSP_EXECBOOT-TAB_DSP
 DC.L 0
 DC.L DET_DSP_TRIGGERHC-TAB_DSP
 DC.L DET_DSP_REQUESTUNIQUEABILITY-TAB_DSP
 DC.L DET_DSP_GETPROGABILITY-TAB_DSP
 DC.L DET_DSP_FLUSHSUBROUTINES-TAB_DSP
 DC.L DET_DSP_LOADSUBROUTINE-TAB_DSP
 DC.L DET_DSP_INQSUBRABILITY-TAB_DSP
 DC.L DET_DSP_RUNSUBROUTINE-TAB_DSP
 DC.L DET_DSP_HF0-TAB_DSP
 DC.L DET_DSP_HF1-TAB_DSP
 DC.L DET_DSP_HF2-TAB_DSP
 DC.L DET_DSP_HF3-TAB_DSP
 DC.L DET_DSP_BLKWORDS-TAB_DSP
 DC.L DET_DSP_BLKBYTES-TAB_DSP
 DC.L DET_DSP_HSTAT-TAB_DSP
 DC.L DET_DSP_SETVECTORS-TAB_DSP
 DC.L DET_DSP_MULTBLOCKS-TAB_DSP;(127)

DET_DSP_BLKHANDSHAKE:

 MOVE.L 4(SP),A0;buffer ‚mission
 MOVE.L 8(SP),D0;taille ‚mission
 MOVE.L 12(SP),A1;buffer r‚ception
 MOVE.L 16(SP),D1;taille r‚ception
 MOVE #TIME_OUT_DSP,time_out
 SUBQ.L #1,D0
 BMI.S \2
\3:TST time_out
   BMI.S \5;time-out
  BTST #1,$FFFFA202
  BEQ.S \3
  MOVE.B (A0)+,$FFFFA205
  MOVE.B (A0)+,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\3
\2:SUBQ.L #1,D1
 BMI.S \1
\4:TST time_out
   BMI.S \5;time-out
  BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.B $FFFFA205,(A1)+
  MOVE.B $FFFFA206,(A1)+
  MOVE.B $FFFFA207,(A1)+
 DBRA D1,\4
\1:clr compt_dsp
 moveq #0,d0
 bra.s \6
\5:move d0,compt_dsp
 moveq #-1,d0
\6:RTS

DET_DSP_BLKUNPACKED:

 MOVE.L 4(SP),A0;buffer ‚mission
 MOVE.L 8(SP),D0;taille ‚mission
 MOVE.L 12(SP),A1;buffer r‚ception
 MOVE.L 16(SP),D1;taille r‚ception
 MOVE #TIME_OUT_DSP,time_out
 SUBQ.L #1,D0
 BMI.S \2
\3:TST time_out
   BMI.S \5;time-out
  BTST #1,$FFFFA202
  BEQ.S \3
  MOVE.L (A0)+,$FFFFA204
 DBRA D0,\3
\2:SUBQ.L #1,D1
 BMI.S \1
\4:TST time_out
   BMI.S \5;time-out
  BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.L $FFFFA204,(A1)+
 DBRA D1,\4
\1:moveq #0,d0
 bra.s \6
\5:moveq #-1,d0
\6:RTS

DET_DSP_INSTREAM:

 LEA _PARAMS_IRQ_DSP,A1
 MOVE.L 4(SP),(A1);buffer ‚mission
 MOVE.L 8(SP),8(A1);taille buffer
 MOVE.L 12(SP),16(A1);nbre blocs
 MOVE.L 16(SP),24(A1);compteur bloc
 MOVE.L 24(A1),A0
 CLR.L (A0);raz compteur
 MOVE.L 8(A1),D0;taille buffer
 BEQ.S \1
 LEA IRQ_IN_OUT_DSP(PC),A0
 MOVE.L A0,$3FC;vecteur
 MOVE.B #-1,$FFFFA203
 OR.B #2,$FFFFA200;envoi vers DSP
\1:RTS

DET_DSP_OUTSTREAM:

 LEA _PARAMS_IRQ_DSP,A1
 MOVE.L 4(SP),4(A1);buffer r‚ception
 MOVE.L 8(SP),12(A1);taille buffer
 MOVE.L 12(SP),20(A1);nbre blocs
 MOVE.L 16(SP),28(A1);compteur bloc
 MOVE.L 28(A1),A0
 CLR.L (A0);raz compteur
 MOVE.L 12(A1),D0;taille buffer
 BEQ.S \1
 LEA IRQ_IN_OUT_DSP(PC),A0
 MOVE.L A0,$3FC;vecteur
 MOVE.B #-1,$FFFFA203
 OR.B #1,$FFFFA200;envoi du DSP
\1:RTS

IRQ_IN_OUT_DSP:

 MOVEM.L D0/A0/A1,-(SP)
 LEA _PARAMS_IRQ_DSP,A1
 BTST #0,$FFFFA202
 BEQ.S \2;pas de r‚ception
 MOVE.L 12(A1),D0;taille buffer r‚ception
 SUBQ.L #1,D0
 BMI.S \3
 MOVE.L 4(A1),A0;buffer r‚ception
\4:BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.B $FFFFA205,(A0)+
  MOVE.B $FFFFA206,(A0)+
  MOVE.B $FFFFA207,(A0)+
 DBRA D0,\4
 MOVE.L A0,4(A1);buffer r‚ception
\3:MOVE.L 28(A1),A0;compteur bloc
 ADDQ.L #1,(A0)
 MOVE.L (A0),D0
 CMP.L 20(A1),D0;nbre blocs
 BNE.S \1
 AND.B #$FE,$FFFFA200
 BRA.S \1
\2:MOVE.L 8(A1),D0;taille buffer ‚mission
 SUBQ.L #1,D0
 BMI.S \6
 MOVE.L (A1),A0;buffer ‚mission
\5:BTST #1,$FFFFA202
  BEQ.S \5
  MOVE.B (A0)+,$FFFFA205
  MOVE.B (A0)+,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\5
 MOVE.L A0,(A1);buffer ‚mission
\6:MOVE.L 24(A1),A0;compteur bloc
 ADDQ.L #1,(A0)
 MOVE.L (A0),D0
 CMP.L 16(A1),D0;nbre blocs
 BNE.S \1
 AND.B #$FD,$FFFFA200
\1:MOVEM.L (SP)+,D0/A0/A1
 RTE

DET_DSP_IOSTREAM:

 LEA _PARAMS_IRQ_DSP,A1
 MOVE.L 4(SP),(A1);buffer ‚mission
 MOVE.L 8(SP),4(A1);buffer r‚ception
 MOVE.L 12(SP),8(A1);taille buffer ‚mission
 MOVE.L 16(SP),12(A1);taille buffer r‚ception
 MOVE.L 20(SP),16(A1);nbre blocs
 MOVE.L 24(SP),24(A1);compteur bloc
 MOVE.L 24(A1),A0
 CLR.L (A0);raz compteur
 MOVE.L 8(A1),D0;taille buffer ‚mission
 BEQ.S \1
 MOVE.L (A1),A0;buffer ‚mission
\2:BTST #1,$FFFFA202
  BEQ.S \2
  MOVE.B (A0)+,$FFFFA205
  MOVE.B (A0)+,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\2
 MOVE.L A0,(A1);buffer ‚mission
\1:LEA IRQ_IO_DSP(PC),A0
 MOVE.L A0,$3FC;vecteur
 MOVE.B #-1,$FFFFA203
 OR.B #1,$FFFFA200;envoi du DSP
 RTS

IRQ_IO_DSP:

 MOVEM.L D0/A0/A1,-(SP)
 LEA _PARAMS_IRQ_DSP,A1
 MOVE.L 12(A1),D0;taille buffer r‚ception
 SUBQ.L #1,D0
 BMI.S \3
 MOVE.L 4(A1),A0;buffer r‚ception
\4:BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.B $FFFFA205,(A0)+
  MOVE.B $FFFFA206,(A0)+
  MOVE.B $FFFFA207,(A0)+
 DBRA D0,\4
 MOVE.L A0,4(A1);buffer r‚ception
\3:MOVE.L 24(A1),A0;compteur bloc
 ADDQ.L #1,(A0)
 MOVE.L (A0),D0
 CMP.L 16(A1),D0;nbre blocs
 BNE.S \2
 AND.B #$FE,$FFFFA200
 BRA.S \1
\2:MOVE.L 8(A1),D0;taille buffer ‚mission
 SUBQ.L #1,D0
 BMI.S \1
 MOVE.L (A1),A0;buffer ‚mission
\5:BTST #1,$FFFFA202
  BEQ.S \5
  MOVE.B (A0)+,$FFFFA205
  MOVE.B (A0)+,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\5
 MOVE.L A0,(A1);buffer ‚mission
\1:MOVEM.L (SP)+,D0/A0/A1
 RTE

DET_DSP_REMOVEINTERRUPTS:

 MOVE 4(SP),D0;masque
 NOT.B D0
 AND.B D0,$FFFFA200
 RTS

DET_DSP_GETWORDSIZE:

 MOVEQ #3,D0;24 bits sur DSP 56001
 RTS

DET_DSP_LOCK:

 MOVE _D_LOCK,D0
 BNE.S \1
 MOVE #-1,_D_LOCK
\1:RTS

DET_DSP_UNLOCK:

 CLR _D_LOCK
 RTS

DET_DSP_AVAILABLE:

 MOVE.L 4(SP),A0;m‚moire X
 MOVE.L 8(SP),A1;m‚moire Y
 MOVE.L #$3EFF,(A1)
 MOVE.L _HIMEM_DSP,D0
 SUB.L #$4000,D0
 MOVE.L D0,(A0)
 RTS

DET_DSP_RESERVE:

 MOVE.L 4(SP),D0;m‚moire X
 ADD.L #$4000,D0
 MOVE.L _HIMEM_DSP,D1
 CMP.L D1,D0
 BGT.S \2
 MOVE.L D0,_RESERVE_DSP
 MOVE.L 8(SP),D0;m‚moire Y
 CMP.L #$3EFF,D0
 BGT.S \2
 MOVEQ #0,D0
 BRA.S \1
\2:MOVEQ #-1,D0
\1:RTS
      
DET_DSP_LOADPROG:

 MOVE.L 4(SP),A0;nom
 MOVE 8(SP),D0
 MOVE.L 10(SP),A1;buffer
 MOVE D0,-(SP);ability
 DSP_LODTOBINARY (A1),(A0)
 MOVE.L D0,D2
 BGT.S \2
 ADDQ #2,SP
 MOVEQ #-1,D0;erreur
 BRA.S \1
\2:MOVE.L 12(SP),A1;buffer
 MOVE.L D2,-(SP);taille en mots DSP
 PEA (A1);buffer
 MOVE #109,-(SP);DSP_EXECPROG
 TRAP #14
 LEA 12(SP),SP
 MOVEQ #0,D0;OK
\1:RTS

DET_DSP_EXECPROG:

 MOVEQ #71,D0;taille start
 MOVE.L D0,-(SP)
 PEA START_DSP(PC);buffer start
 MOVE #110,-(SP);DSP_EXECBOOT
 TRAP #14
 LEA 10(SP),SP 
 bmi \2;time-out
 LEA 4(SP),A1
 MOVE.L (A1)+,A0;buffer
 MOVE.L (A1)+,D0;taille
 MOVE (A1),_ABILITY
 MOVE #TIME_OUT_DSP,time_out
 BSR.S \ENVOI_BLOC
 bmi.s \2;time-out
 MOVEQ #23,D0;taille data
 LEA DATA_START_DSP(PC),A0
\TB:TST time_out
   BMI.S \2;time-out
  BTST #1,$FFFFA202
  BEQ.S \TB
  MOVE.B (A0)+,$FFFFA205
  MOVE.B (A0)+,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
\ENVOI_BLOC:
 DBRA D0,\TB
 moveq #0,D0
 bra.s \1
\2:moveq #-1,d0
\1:RTS

DET_DSP_EXECBOOT:

 MOVE SR,-(SP)
 OR #$700,SR;interdit IRQ
 MOVE.B #14,$FFFF8800;PSG YAMAHA port A
 MOVE.B $FFFF8800,D0
 BCLR #4,D0;bit 4 port A … 0
 MOVE.B D0,$FFFF8802
 BSET #4,D0;bit 4 port A … 1
 MOVE.B D0,$FFFF8802
 MOVE (SP),SR
 MOVE.L _HZ_200,D0
 ADDQ.L #2,D0;tempo 10 mS
\4:MOVE.L _HZ_200,D1
 CMP.L D0,D1
 BLT.S \4
 OR #$700,SR;interdit IRQ
 MOVE.B #14,$FFFF8800;PSG YAMAHA port A
 MOVE.B $FFFF8800,D0
 BCLR #4,D0;bit 4 port A … 0
 MOVE.B D0,$FFFF8802
 MOVE (SP)+,SR
\8:CMP.L _HZ_200,D1
 BEQ.S \8
; MOVEQ #-1,D0
;\8:DBRA D0,\8
 MOVE.L 8(SP),D0;taille
 MOVE.L 4(SP),A0;buffer
 MOVE.L #512,D1;taille maxi de 512 mots DSP
 SUB.L D0,D1
 MOVE #TIME_OUT_DSP,time_out
 SUBQ.L #1,D0
 BMI.S \5
\2:TST time_out
   BMI.S \6;time-out
  BTST #1,$FFFFA202
  BEQ.S \2
  MOVE.B (A0)+,$FFFFA205
  MOVE.B (A0)+,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\2
\5:;bset #3,$FFFFA200;HF0 abort
; bra.S \1
 moveq #-1,d0
 SUBQ.L #1,D1
 BMI.S \1
 MOVEQ #0,D2
\3:TST time_out
   BMI.S \6;time-out
  BTST #1,$FFFFA202
  BEQ.S \3
  MOVE.B D2,$FFFFA205
  MOVE.B D2,$FFFFA206
  MOVE.B D2,$FFFFA207
 DBRA D1,\3
\1:clr compt_dsp
 moveq #0,d0
 bra.s \7
\6:move d0,compt_dsp
 moveq #-1,d0
\7:RTS

DET_DSP_TRIGGERHC:

 MOVE 4(SP),D0;vecteur
 BSET #7,D0
 MOVE.B D0,$FFFFA201 
 RTS

DET_DSP_REQUESTUNIQUEABILITY:

 MOVE _COMPT_ABILITY,D0
 INC D0
 MOVE D0,_COMPT_ABILITY
 RTS

DET_DSP_GETPROGABILITY:

 MOVE _ABILITY,D0
 RTS

DET_DSP_FLUSHSUBROUTINES:

 LEA _TAB_SUBROUT_DSP,A0
 MOVEQ #MAX_SUBROUT_DSP,D0
\1:CLR.L (A0)
  CLR 10(A0)
  LEA 12(A0),A0
 DBRA D0,\1
 MOVE.L _HIMEM_INIT,_HIMEM_DSP
 CLR _COMPT_SUBROUT
 RTS

DET_DSP_LOADSUBROUTINE:

 MOVE.L 8(SP),D2;taille
 CMP.L #$400,D2
 BGT.S \2
 MOVE.L _RESERVE_DSP,D0
 ADD.L D2,D0
 MOVE.L _HIMEM_DSP,D1
 CMP.L D1,D0
 BLE.S \3
\2:MOVEQ #0,D0;erreur
 BRA \1
\3:MOVE _COMPT_SUBROUT,D0
 MULU #12,D0
 LEA _TAB_SUBROUT_DSP,A0
 ADD.L D0,A0
 MOVE.L (A0),D0
 BEQ \5
 SUBQ.L #1,D0
 MOVE.B #$96,$FFFFA201
\8:BTST #7,$FFFFA201
 BNE.S \8
 BSR \ENVOI_D0
\12:BTST #1,$FFFFA202
 BEQ.S \12
 MOVE.L _HIMEM_INIT,$FFFFA204
 SUB.L D1,D0
 BSR \ENVOI_D0
 MOVE _COMPT_SUBROUT,D0
 MULU #12,D0
 LEA _TAB_SUBROUT_DSP,A0
 MOVE.L 4(A0,D0.L),D0
 BRA.S \7
\6:ADD.L D0,(A0)
  MOVE 8(A0),D1
  SUB #23,D1
  MULS #6,D1
  ADDQ #4,D1
  LEA DATA_START_DSP+21(PC),A1
  MOVE 2(A0),(A1,D1)
  LEA 12(A0),A0
\7:CMP.L #_TAB_SUBROUT_DSP+(12*MAX_SUBROUT_DSP),A0
 BCS.S \6
 ADD.L D0,_HIMEM_DSP
\5:MOVE.L _HIMEM_DSP,D0
 SUB.L D2,D0
 MOVE.L D0,_HIMEM_DSP
 ADDQ.L #1,D0
 MOVE _COMPT_SUBROUT,D1
 MULU #12,D1
 LEA _TAB_SUBROUT_DSP,A0
 ADD.L D1,A0
 MOVEM.L D0/D2,(A0)
 MOVE 12(SP),10(A0);ability  
 MOVE 8(A0),D1
 SUB #23,D1
 MULS #6,D1
 ADDQ #4,D1
 LEA DATA_START_DSP+21(PC),A0
 MOVE D0,(A0,D1)
 MOVE.B #$95,$FFFFA201
\9:BTST #7,$FFFFA201
 BNE.S \9
 MOVEQ #$2E,D0
 BSR.S \ENVOI_D0
 MOVEQ #16,D0
 BSR.S \ENVOI_D0
 LEA DATA_START_DSP+21(PC),A0
 BSR.S \ENVOI_BLOC
 MOVE.B #$95,$FFFFA201
\11:BTST #7,$FFFFA201
 BNE.S \11
 MOVE _COMPT_SUBROUT,D0
 MULU #12,D0
 LEA _TAB_SUBROUT_DSP,A0
 ADD.L D0,A0
 MOVE.L (A0)+,D0
 BSR.S \ENVOI_D0
 MOVE.L (A0),D0
 BSR.S \ENVOI_D0
 MOVE.L D2,D0;taille
 MOVE.L 4(SP),A0;buffer
 BSR.S \ENVOI_BLOC
 MOVE _COMPT_SUBROUT,D0
 INC _COMPT_SUBROUT
 CMP #8,_COMPT_SUBROUT
 BLT.S \4
 CLR _COMPT_SUBROUT
\4:MULU #12,D0
 LEA _TAB_SUBROUT_DSP,A0
 MOVE 8(A0,D0.L),D0
 BRA.S \1
\ENVOI_D0:
 BTST #1,$FFFFA202
 BEQ.S \ENVOI_D0
 MOVE.L D0,$FFFFA204
 BRA.S \1
\ENVOI_BLOC:
 DEC D0
 BMI.S \1
\TB:BTST #1,$FFFFA202
  BEQ.S \TB
  MOVE.B (A0)+,$FFFFA205
  MOVE.B (A0)+,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\TB
\1:RTS

DET_DSP_INQSUBRABILITY:

 MOVE 4(SP),D1;ability
 LEA _TAB_SUBROUT_DSP,A0
 MOVEQ #MAX_SUBROUT_DSP-1,D2
 MOVEQ #22,D0
\2:INC D0
  CMP 10(A0),D1
  BEQ.S \1
  LEA 12(A0),A0
 DBRA D2,\2
 MOVEQ #0,D0
\1:RTS

DET_DSP_RUNSUBROUTINE:

 MOVE 4(SP),D0;handle
 MOVE D0,D1
 CMP.B #23,D0
 BLT.S \2
 CMP.B #MAX_SUBROUT_DSP+22,D0
 BGT.S \2
 SUB #23,D1
 MULS #6,D1
 ADDQ #3,D1
 LEA DATA_START_DSP+21(PC),A0
 ADD D1,A0
\3:BTST #1,$FFFFA202
 BEQ.S \3 
 MOVE.B (A0)+,$FFFFA205 
 MOVE.B (A0)+,$FFFFA206 
 MOVE.B (A0)+,$FFFFA207 
 BSET #7,D0
 MOVE.B D0,$FFFFA201 
 MOVEQ #0,D0
 BRA.S \1
\2:MOVEQ #-1,D0
\1:RTS

DET_DSP_HF0:

 MOVE 4(SP),D0
 CMP #-1,D0
 BEQ.S \2
 CMP #1,D0
 BNE.S \3
 BSET #3,$FFFFA200
 BRA.S \1
\3:TST D0
 BNE.S \1
 BCLR #3,$FFFFA200
 BRA.S \1
\2:MOVEQ #0,D0
 BTST #3,$FFFFA200
 BEQ.S \1
 MOVEQ #1,D0
\1:RTS

DET_DSP_HF1:

 MOVE 4(SP),D0
 CMP #-1,D0
 BEQ.S \2
 CMP #1,D0
 BNE.S \3
 BSET #4,$FFFFA200
 BRA.S \1
\3:TST D0
 BNE.S \1
 BCLR #4,$FFFFA200
 BRA.S \1
\2:MOVEQ #0,D0
 BTST #4,$FFFFA200
 BEQ.S \1
 MOVEQ #1,D0
\1:RTS

DET_DSP_HF2:

 MOVEQ #0,D0
 BTST #3,$FFFFA202
 BEQ.S \1
 MOVEQ #1,D0
\1:RTS

DET_DSP_HF3:

 MOVEQ #0,D0
 BTST #4,$FFFFA202
 BEQ.S \1
 MOVEQ #1,D0
\1:RTS

DET_DSP_BLKWORDS:

 MOVE.L 4(SP),A0;buffer ‚mission
 MOVE.L 8(SP),D0;taille ‚mission
 MOVE.L 12(SP),A1;buffer r‚ception
 MOVE.L 16(SP),D1;taille r‚ception
 MOVE #TIME_OUT_DSP,time_out
 SUBQ.L #1,D0
 BMI.S \2
\3:TST time_out
   BMI.S \5;time-out
  BTST #1,$FFFFA202
  BEQ.S \3
  MOVE (A0)+,D2
  EXT.L D2
  MOVE.L D2,$FFFFA204
 DBRA D0,\3
\2:SUBQ.L #1,D1
 BMI.S \1
\4:TST time_out
   BMI.S \5;time-out
  BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.B $FFFFA206,(A1)+
  MOVE.B $FFFFA207,(A1)+
 DBRA D1,\4
\1:moveq #0,d0
 bra.s \6
\5:moveq #-1,d0
\6:RTS

DET_DSP_BLKBYTES:

 MOVE.L 4(SP),A0;buffer ‚mission
 MOVE.L 8(SP),D0;taille ‚mission
 MOVE.L 12(SP),A1;buffer r‚ception
 MOVE.L 16(SP),D1;taille r‚ception
 MOVE #TIME_OUT_DSP,time_out
 SUBQ.L #1,D0
 BMI.S \2
\3:TST time_out
   BMI.S \5;time-out
  BTST #1,$FFFFA202
  BEQ.S \3
  MOVE.B #0,$FFFFA205
  MOVE.B #0,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\3
\2:SUBQ.L #1,D1
 BMI.S \1
\4:TST time_out
   BMI.S \5;time-out
  BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.B $FFFFA206,D2
  MOVE.B $FFFFA207,(A1)+
 DBRA D1,\4
\1:moveq #0,d0
 bra.s \6
\5:moveq #-1,d0
\6:RTS

DET_DSP_HSTAT:

 MOVE.B $FFFFA202,D0
 MOVE.B $FFFFA201,D1
 RTS

DET_DSP_SETVECTORS:

 MOVE.L 4(SP),_RECEIVER
 BEQ.S \2
 LEA IRQ_SETVECTORS(PC),A0
 MOVE.L A0,$3FC
 MOVE.B #-1,$FFFFA203
 BSET #0,$FFFFA200
\2:MOVE.L 8(SP),_TRANSMITTER
 BEQ.S \1
 LEA IRQ_SETVECTORS(PC),A0
 MOVE.L A0,$3FC
 MOVE.B #-1,$FFFFA203
 BSET #1,$FFFFA200
\1:RTS

IRQ_SETVECTORS:

 MOVEM.L D0-D2/A0-A2,-(SP)
 BTST #0,$FFFFA202
 BEQ.S \2
 MOVE.L _RECEIVER,D0
 BEQ.S \2
 MOVE.L D0,A0
 MOVEQ #0,D0
 MOVE.B $FFFFA205,D0
 ROL.L #8,D0
 MOVE.B $FFFFA206,D0
 ROL.L #8,D0
 MOVE.B $FFFFA207,D0
 MOVE.L D0,-(SP)
 JSR (A0)
 ADDQ #4,SP
\2:BTST #1,$FFFFA202
 BEQ.S \1
 MOVE.L _TRANSMITTER,D0
 BEQ.S \1
 MOVE.L D0,A0
 JSR (A0)
 TST.L D0
 BEQ.S \1
 SWAP D0
 MOVE.B D0,$FFFFA205
 ROL.L #8,D0
 MOVE.B D0,$FFFFA206
 ROL.L #8,D0
 MOVE.B D0,$FFFFA207
\1:MOVEM.L (SP)+,D0-D2/A0-A2
 RTE

DET_DSP_MULTBLOCKS:

 MOVE.L 4(SP),D0;nbre blocs ‚mission
 BEQ.S \2
 MOVE.L 12(SP),A0;bloc ‚mission
 DEC D0
\3:MOVE (A0),D1;type bloc
  MOVE.L 2(A0),D2;nbre d'‚l‚ments
  SUBQ.L #1,D2
  MOVE.L 6(A0),A1;adresse bloc
  TST D1;mot long
  BNE.S \6
\4:BTST #1,$FFFFA202
   BEQ.S \4
   MOVE.L (A1)+,$FFFFA204
  DBRA D2,\4
  BRA.S \5
\6:CMP #1,D1;mot sign‚
  BNE.S \7
\8:BTST #1,$FFFFA202
   BEQ.S \8
   MOVE (A1)+,D1
   EXT.L D1
   MOVE.L D1,$FFFFA204
  DBRA D2,\8
  BRA.S \5
\7:CMP #2,D1;octet non sign‚
  BNE \1
\9:BTST #1,$FFFFA202
   BEQ.S \9
   MOVE.B #0,$FFFFA205
   MOVE.B #0,$FFFFA206
   MOVE.B (A1)+,$FFFFA207
  DBRA D2,\9
\5:LEA 10(A0),A0;bloc suivant
 DBRA D0,\3
\2:MOVE.L 8(SP),D0;nbre blocs r‚ception
 BEQ.S \1
 MOVE.L 16(SP),A0;bloc r‚ception
 DEC D0
\10:MOVE (A0),D1;type bloc
  MOVE.L 2(A0),D2;nbre d'‚l‚ments
  SUBQ.L #1,D2
  MOVE.L 6(A0),A1;adresse bloc
  TST D1;mot long
  BNE.S \11
\14:BTST #0,$FFFFA202
   BEQ.S \14
   MOVE.L $FFFFA204,(A1)+
  DBRA D2,\14
  BRA.S \13
\11:CMP #1,D1;mot sign‚
  BNE.S \12
\15:BTST #0,$FFFFA202
   BEQ.S \15
   MOVE.B $FFFFA206,(A1)+
   MOVE.B $FFFFA207,(A1)+
  DBRA D2,\15
  BRA.S \13
\12:CMP #2,D1;octet non sign‚
  BNE.S \1
\16:BTST #0,$FFFFA202
   BEQ.S \16
   MOVE.B $FFFFA206,D1
   MOVE.B $FFFFA207,(A1)+
  DBRA D2,\16
\13:LEA 10(A0),A0;bloc suivant
 DBRA D0,\10
\1:RTS

 DATA
 
BOOT_INIT_DSP:;82 mots DSP

 DC.B $0A,$F0,$80,$00,$00,$40; $00: JMP $0040
 DS.B 38*3
 DC.B $0B,$F0,$80,$00,$7F,$00; JSR $7F00
 DC.B $0B,$F0,$80,$00,$7E,$EF; JSR $7EEF
 DC.B $0B,$F0,$80,$00,$7E,$DC; JSR $7EDC
 DC.B $0B,$F0,$80,$00,$7F,$00; JSR $7F00
 DC.B $00,$00,$00,$00,$00,$00
 DC.B $00,$00,$00,$00,$00,$00
 DC.B $00,$00,$00,$00,$00,$00
 DC.B $00,$00,$00,$00,$00,$00
 DC.B $00,$00,$00,$00,$00,$00
 DC.B $00,$00,$00,$00,$00,$00
 DC.B $00,$00,$00,$00,$00,$00
 DC.B $00,$00,$00,$00,$00,$00
 DC.B $08,$F4,$A8,$00,$00,$0C; $40: MOVEP #>4,X:<<HCR interruptions port HOST    
 DC.B $08,$F4,$BF,$00,$0C,$00; $42: MOVEP #>$C00,X:<<IPR
 DC.B $00,$FE,$B8;             $44: ANDI #$FE,MR
 DC.B $08,$F4,$A0,$00,$00,$01; $45: MOVEP #>1,X:<<PBC init I/O port B = port HOST
 DC.B $08,$F4,$BE,$00,$00,$00; $47: MOVEP #>0,X:<<BCR
 DC.B $60,$F4,$00,$00,$7E,$A9; $49: MOVE #$7EA9,R0
 DC.B $31,$98,$00;             $4B: MOVE #152,R1
 DC.B $06,$D1,$00,$00,$00,$50; $4C: DO R1,$0051
 DC.B $0A,$A9,$80,$00,$00,$4E; $4E: JCLR #0,X:<<HSR,$004E
 DC.B $08,$58,$6B;             $50: MOVEP X:<<HRX,P:(R0)+
 DC.B $0C,$00,$51;             $51: JMP $0051

DATA_INIT_DSP:;152 mots DSP

 DC.B $08,$F4,$A0,$00,$00,$01
 DC.B $08,$F4,$BE,$00,$00,$00
 DC.B $0A,$A9,$80,$00,$7E,$AD
 DC.B $20,$00,$13,$08,$4C,$2B
 DC.B $45,$F4,$00,$00,$00,$03
 DC.B $20,$00,$65,$0E,$A0,$00
 DC.B $0A,$A9,$80,$00,$7E,$B5
 DC.B $08,$50,$2B,$0A,$A9,$80
 DC.B $00,$7E,$B8,$08,$51,$2B
 DC.B $45,$F4,$00,$00,$00,$01
 DC.B $20,$00,$65,$0A,$F0,$AA
 DC.B $00,$7E,$CE,$45,$F4,$00
 DC.B $00,$00,$02,$20,$00,$65
 DC.B $0A,$F0,$AA,$00,$7E,$D5
 DC.B $0A,$F0,$80,$00,$7E,$C7
 DC.B $06,$D1,$00,$00,$7E,$CB
 DC.B $0A,$A9,$80,$00,$7E,$C9
 DC.B $08,$58,$6B,$0A,$F0,$80
 DC.B $00,$7E,$AD,$06,$D1,$00
 DC.B $00,$7E,$D2,$0A,$A9,$80
 DC.B $00,$7E,$D0,$08,$58,$AB
 DC.B $0A,$F0,$80,$00,$7E,$AD
 DC.B $06,$D1,$00,$00,$7E,$D9
 DC.B $0A,$A9,$80,$00,$7E,$D7
 DC.B $08,$58,$EB,$0A,$F0,$80
 DC.B $00,$7E,$AD,$08,$F4,$A0
 DC.B $00,$00,$01,$08,$F4,$BE
 DC.B $00,$00,$00,$0A,$A9,$80
 DC.B $00,$7E,$E0,$08,$50,$2B
 DC.B $0A,$A9,$80,$00,$7E,$E3
 DC.B $08,$51,$2B,$0A,$A9,$80
 DC.B $00,$7E,$E6,$08,$52,$2B
 DC.B $06,$D2,$00,$00,$7E,$EC
 DC.B $07,$D0,$8C,$07,$51,$8C
 DC.B $00,$00,$00,$00,$00,$04
 DC.B $08,$F4,$A0,$00,$00,$01
 DC.B $08,$F4,$BE,$00,$00,$00
 DC.B $0A,$A9,$80,$00,$7E,$F3
 DC.B $08,$50,$2B,$0A,$A9,$80
 DC.B $00,$7E,$F6,$08,$51,$2B
 DC.B $06,$D1,$00,$00,$7E,$FD
 DC.B $0A,$A9,$80,$00,$7E,$FB
 DC.B $08,$58,$6B,$00,$00,$00
 DC.B $00,$00,$04,$08,$F4,$A0
 DC.B $00,$00,$01,$08,$F4,$BE
 DC.B $00,$00,$00,$0A,$A9,$80
 DC.B $00,$7F,$04,$20,$00,$13
 DC.B $08,$4C,$2B,$45,$F4,$00
 DC.B $00,$00,$01,$20,$00,$65
 DC.B $0A,$F0,$AA,$00,$7F,$23
 DC.B $45,$F4,$00,$00,$00,$02
 DC.B $20,$00,$65,$0A,$F0,$AA
 DC.B $00,$7F,$32,$0A,$F0,$80
 DC.B $00,$7F,$14,$0A,$A9,$80
 DC.B $00,$7F,$14,$08,$50,$2B
 DC.B $0A,$A9,$80,$00,$7F,$17
 DC.B $08,$51,$2B,$06,$D1,$00
 DC.B $00,$7F,$20,$07,$D8,$8C
 DC.B $0A,$A9,$81,$00,$7F,$1D
 DC.B $54,$70,$00,$00,$FF,$EB
 DC.B $00,$00,$00,$00,$00,$04
 DC.B $0A,$A9,$80,$00,$7F,$23
 DC.B $08,$50,$2B,$0A,$A9,$80
 DC.B $00,$7F,$26,$08,$51,$2B
 DC.B $06,$D1,$00,$00,$7F,$2F
 DC.B $54,$D8,$00,$0A,$A9,$81
 DC.B $00,$7F,$2C,$54,$70,$00
 DC.B $00,$FF,$EB,$00,$00,$00
 DC.B $00,$00,$04,$0A,$A9,$80
 DC.B $00,$7F,$32,$08,$50,$2B
 DC.B $0A,$A9,$80,$00,$7F,$35
 DC.B $08,$51,$2B,$06,$D1,$00
 DC.B $00,$7F,$3E,$5C,$D8,$00
 DC.B $0A,$A9,$81,$00,$7F,$3B
 DC.B $54,$70,$00,$00,$FF,$EB
 DC.B $00,$00,$00,$00,$00,$04

START_DSP:;71 mots DSP       

 DC.B $0A,$F0,$80,$00,$00,$40
 DS.B 62*3
 DC.B $08,$F4,$A8,$00,$00,$04
 DC.B $08,$F4,$BF,$00,$0C,$00
 DC.B $00,$FE,$B8,$0A,$F0,$80
 DC.B $00,$7E,$A9

DATA_START_DSP:;24 mots DSP            $17E2-$17F9

 DC.B $00,$00,$00,$00,$00,$2A
 DC.B $00,$00,$14,$0B,$F0,$80
 DC.B $00,$7E,$EF,$0B,$F0,$80
 DC.B $00,$7E,$DC,$0B,$F0,$80
 DC.B $00,$7F,$00,$0B,$F0,$80
 DC.B $00,$00,$00,$0B,$F0,$80
 DC.B $00,$00,$00,$0B,$F0,$80
 DC.B $00,$00,$00,$0B,$F0,$80
 DC.B $00,$00,$00,$0B,$F0,$80
 DC.B $00,$00,$00,$0B,$F0,$80
 DC.B $00,$00,$00,$0B,$F0,$80
 DC.B $00,$00,$00,$00,$00,$03

 ALIGN.W
  
  END
