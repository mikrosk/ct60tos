
;DSPXBIOS

TOS4 EQU 0 ;avec les variables systŠme du TOS4
TOS402 EQU 0

INC EQU ADDQ #1,
DEC EQU SUBQ #1,

TAILLE_PILE EQU 1800

MAX_SUBROUT_DSP EQU 8

;variables systŠme
SAVPTR EQU $4A2
_HZ_200 EQU $4BA
PROC_TYPE EQU $59E
_COOKIE EQU $5A0

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
_DATA_START_DSP EQU $17E2

_START_DSP_TOS404 EQU $E4AC82
_START_DSP_TOS402 EQU $E4AC22
TOS404_DSP_EXECBOOT EQU $E05E74
TOS402_DSP_EXECBOOT EQU $E05E1A

 ILABEL TOS.Q

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

DEBUT:

 MOVE.L 4(SP),A5;d‚but de la basepage
 MOVE.L $C(A5),D0;taille segment TEXT
 ADD.L $14(A5),D0;taille segment DATA
 ADD.L $1C(A5),D0;taille segment BSS
 ADD.L #TAILLE_PILE,D0;pour la pile et la basepage
 AND.B #$FE,D0
 LEA -104(A5,D0.L),SP
 SETBLOCK D0,(A5)
 MOVE.L #"_MCH",D0
 BSR GET_COOKIE
 BMI \1;pas de cookie-jar
 MOVE.L D0,A0
 CMP.L #$30000,(A0);FALCON
 BNE \1;ST(E) ou TT
; MOVE.L #"PICD",D0
; BSR GET_COOKIE
; BPL \1;install‚ avec PICDESK
 PRINTLINE MESS1
 SUPEXEC INIT_DSP
 SETEXEC DET_XBIOS,#46;TRAP #14
 MOVE.L D0,DET_XBIOS-4
 CONOUT #13
 CONOUT #10
 CONOUT #10
 KEEPPROC #0,#FIN-DEBUT+TAILLE_PILE;programme r‚sidant
\1:TERM
 ILLEGAL
 RTS
 
GET_COOKIE:;nom dans D0.L, au retour si < 0 pas de cookie
;retourne le pointeur sur donn‚e cookie dans D0

 MOVEM.L D1-A1/A6,-(SP)
 MOVE.L D0,D6
 SUB.L A6,A6
 SUPER 1
 TST.L D0
 BMI.S \5;mode superviseur
 SUPER 0
 MOVE.L D0,A6;sauve SSP
\5:MOVEQ #0,D7
 MOVE.L _COOKIE,D0
 BEQ.S \1
 MOVE.L D0,A0
\2:TST.L (A0)
  BEQ.S \1
  CMP.L (A0),D6
  BNE.S \3
  MOVE.L A0,D7
  ADDQ #4,D7
  BRA.S \1
\3:ADDQ #8,A0
 BRA.S \2
\1:MOVE.L A6,D0
 BEQ.S \4
 SUPER (A6)
\4:MOVEQ #-1,D6
 MOVE.L D7,D0
 BEQ.S \6
 MOVEQ #0,D6
\6:TST D6
 MOVEM.L (SP)+,D1-A1/A6
 RTS

INIT_DSP:

 MOVEM.L D0-D2/A0-A2,-(SP)
 MOVEQ #0,D1
 IFNE 0,TOS4
  LEA _TAB_SUBROUT_DSP,A0
 ELSE
  LEA TAB_SUBROUT_DSP,A0
 ENDIF 
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
 IFNE 0,TOS4
  MOVE.L D0,_HIMEM_INIT
  MOVE.L D0,_HIMEM_DSP
  CLR.L _RESERVE_DSP
  CLR _ABILITY
  CLR _COMPT_SUBROUT
  MOVE #$8000,_COMPT_ABILITY
 ELSE
  MOVE.L D0,HIMEM_INIT
  MOVE.L D0,HIMEM_DSP
  CLR.L RESERVE_DSP
  CLR ABILITY
  CLR COMPT_SUBROUT
  MOVE #$8000,COMPT_ABILITY
 ENDIF
 MOVEQ #82,D0
 MOVE.L D0,-(SP);taille start
 PEA BOOT_INIT_DSP;buffer start
 BSR DET_DSP_EXECBOOT
 ADDQ #8,SP
 CLR.L -(SP);taille r‚ception
 CLR.L -(SP);buffer r‚ception
 MOVE.L #152,-(SP);taille ‚mission
 PEA DATA_INIT_DSP;buffer ‚mission
 BSR DET_DSP_BLKHANDSHAKE
 LEA 16(SP),SP
 MOVEM.L (SP)+,D0-D2/A0-A2
 RTS

 DC.L "XBRA"
 DC.L "HDSP"
 DC.L 0

DET_XBIOS:;sur FALCON

 LEA TAB_DSP(PC),A0
 MOVE.L USP,A1
 BTST #5,(SP);appel en superviseur
 BEQ.S \2
 LEA 6(SP),A1
 TST PROC_TYPE
 BEQ.S \2
 TST (A1)+;mot suppl‚mentaire sur la pile si > 68000
\2:MOVE (A1)+,D0;fonction
 SUB (A0)+,D0;DSP_DOBLOCK
 BMI.S \1;<> fonctions DSP
 CMP (A0)+,D0
 BCC.S \1;<> fonctions DSP
 ASL #2,D0
 MOVE.L (A0,D0),D0
 BLE.S \1;routine d'origine
 MOVE.L SAVPTR,A0
 MOVE (SP)+,-(A0);SR
 MOVE.L (SP)+,-(A0);PC
 TST PROC_TYPE
 BEQ.S \3
 TST (SP)+;mot suppl‚mentaire sur la pile si > 68000
\3:MOVEM.L D3-D7/A3-A7,-(A0)
 MOVE.L A0,SAVPTR
 MOVE.L A1,SP
 MOVE.L D0,A0
 JSR (A0)
 MOVE.L SAVPTR,A1
 MOVEM.L (A1)+,D3-D7/A3-A7
 TST PROC_TYPE
 BEQ.S \4
 CLR -(SP);mot suppl‚mentaire sur la pile si > 68000
\4:MOVE.L (A1)+,-(SP);PC
 MOVE (A1)+,-(SP);SR
 MOVE.L A1,SAVPTR
 RTE
\1:MOVE.L DET_XBIOS-4(PC),A0
 JMP (A0)

TAB_DSP:
 DC.W 96,32;index de d‚part, nbre de fonctions
 DC.L DET_DSP_BLKHANDSHAKE;DSP_DOBLOCK (96)
 DC.L DET_DSP_BLKHANDSHAKE
 DC.L DET_DSP_BLKUNPACKED
 DC.L DET_DSP_INSTREAM
 DC.L DET_DSP_OUTSTREAM
 DC.L DET_DSP_IOSTREAM
 DC.L DET_DSP_REMOVEINTERRUPTS
 DC.L DET_DSP_GETWORDSIZE
 DC.L DET_DSP_LOCK
 DC.L DET_DSP_UNLOCK
 DC.L DET_DSP_AVAILABLE
 DC.L DET_DSP_RESERVE
 DC.L DET_DSP_LOADPROG
 DC.L DET_DSP_EXECPROG
 DC.L DET_DSP_EXECBOOT
 DC.L 0
 DC.L DET_DSP_TRIGGERHC
 DC.L DET_DSP_REQUESTUNIQUEABILITY
 DC.L DET_DSP_GETPROGABILITY
 DC.L DET_DSP_FLUSHSUBROUTINES
 DC.L DET_DSP_LOADSUBROUTINE
 DC.L DET_DSP_INQSUBRABILITY
 DC.L DET_DSP_RUNSUBROUTINE
 DC.L DET_DSP_HF0
 DC.L DET_DSP_HF1
 DC.L DET_DSP_HF2
 DC.L DET_DSP_HF3
 DC.L DET_DSP_BLKWORDS
 DC.L DET_DSP_BLKBYTES
 DC.L DET_DSP_HSTAT
 DC.L DET_DSP_SETVECTORS
 DC.L DET_DSP_MULTBLOCKS;(127)

DET_DSP_BLKHANDSHAKE:

 MOVE.L 4(SP),A0;buffer ‚mission
 MOVE.L 8(SP),D0;taille ‚mission
 MOVE.L 12(SP),A1;buffer r‚ception
 MOVE.L 16(SP),D1;taille r‚ception
 SUBQ.L #1,D0
 BMI.S \2
\3:BTST #1,$FFFFA202
  BEQ.S \3
  MOVE.B (A0)+,$FFFFA205
  MOVE.B (A0)+,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\3
\2:SUBQ.L #1,D1
 BMI.S \1
\4:BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.B $FFFFA205,(A1)+
  MOVE.B $FFFFA206,(A1)+
  MOVE.B $FFFFA207,(A1)+
 DBRA D1,\4
\1:RTS

DET_DSP_BLKUNPACKED:

 MOVE.L 4(SP),A0;buffer ‚mission
 MOVE.L 8(SP),D0;taille ‚mission
 MOVE.L 12(SP),A1;buffer r‚ception
 MOVE.L 16(SP),D1;taille r‚ception
 SUBQ.L #1,D0
 BMI.S \2
\3:BTST #1,$FFFFA202
  BEQ.S \3
  MOVE.L (A0)+,$FFFFA204
 DBRA D0,\3
\2:SUBQ.L #1,D1
 BMI.S \1
\4:BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.L $FFFFA204,(A1)+
 DBRA D1,\4
\1:RTS

DET_DSP_INSTREAM:

 IFNE 0,TOS4
  LEA _PARAMS_IRQ_DSP,A1
 ELSE
  LEA PARAMS_IRQ_DSP,A1
 ENDIF 
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
\1:IFNE 0,TOS4
  NOP;important pour IRQ_IN_OUT_DSP point‚ par rapport PC
  NOP;DET_DSP_OUTSTREAM doit suivre DET_DSP_INSTREAM identique … la ROM !!!
  NOP
  NOP
  NOP
  NOP
  NOP
  NOP
 ENDIF
 RTS

DET_DSP_OUTSTREAM:

 IFNE 0,TOS4
  LEA _PARAMS_IRQ_DSP,A1
 ELSE
  LEA PARAMS_IRQ_DSP,A1
 ENDIF 
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
 IFNE 0,TOS4
  LEA _PARAMS_IRQ_DSP,A1
 ELSE
  LEA PARAMS_IRQ_DSP,A1
 ENDIF 
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

 IFNE 0,TOS4
  LEA _PARAMS_IRQ_DSP,A1
 ELSE
  LEA PARAMS_IRQ_DSP,A1
 ENDIF 
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
 IFNE 0,TOS4
  LEA _PARAMS_IRQ_DSP,A1
 ELSE
  LEA PARAMS_IRQ_DSP,A1
 ENDIF 
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

 IFNE 0,TOS4
  MOVE _D_LOCK,D0
 ELSE
  MOVE D_LOCK,D0
 ENDIF 
 BNE.S \1
 IFNE 0,TOS4
  MOVE #-1,_D_LOCK
 ELSE
  MOVE #-1,D_LOCK
 ENDIF
\1:RTS

DET_DSP_UNLOCK:

 IFNE 0,TOS4
  CLR _D_LOCK
 ELSE
  CLR D_LOCK
 ENDIF 
 RTS

DET_DSP_AVAILABLE:

 MOVE.L 4(SP),A0;m‚moire X
 MOVE.L 8(SP),A1;m‚moire Y
 MOVE.L #$3EFF,(A1)
 IFNE 0,TOS4
  MOVE.L _HIMEM_DSP,D0
 ELSE
  MOVE.L HIMEM_DSP,D0
 ENDIF 
 SUB.L #$4000,D0
 MOVE.L D0,(A0)
 RTS

DET_DSP_RESERVE:

 MOVE.L 4(SP),D0;m‚moire X
 ADD.L #$4000,D0
 IFNE 0,TOS4
  MOVE.L _HIMEM_DSP,D1
 ELSE
  MOVE.L HIMEM_DSP,D1
 ENDIF 
 CMP.L D1,D0
 BGT.S \2
 IFNE 0,TOS4
  MOVE.L D0,_RESERVE_DSP
 ELSE
  MOVE.L D0,RESERVE_DSP
 ENDIF 
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

 IFNE 0,TOS4
  CLR.L -(SP);pas de place !!! => 71
  CLR.L -(SP);pas de place !!! => _START_DSP_TOS40X
 ELSE
  MOVEQ #71,D0;taille start
  MOVE.L D0,-(SP)
  PEA START_DSP;buffer start
 ENDIF
 MOVE #110,-(SP);DSP_EXECBOOT
 TRAP #14
 LEA 10(SP),SP 
 LEA 4(SP),A1
 MOVE.L (A1)+,A0;buffer
 MOVE.L (A1)+,D0;taille
 IFNE 0,TOS4
  MOVE (A1),_ABILITY
 ELSE
  MOVE (A1),ABILITY
 ENDIF
 BSR.S \ENVOI_BLOC
 MOVEQ #23,D0;taille data
 IFNE 0,TOS4
  LEA _DATA_START_DSP,A0
 ELSE
  LEA DATA_START_DSP,A0
 ENDIF
\TB:BTST #1,$FFFFA202
  BEQ.S \TB
  DEC A0
  MOVE.L (A0)+,$FFFFA204
\ENVOI_BLOC:
 DBRA D0,\TB
\1:RTS

DET_DSP_EXECBOOT:

 MOVE SR,-(SP)
 OR #$700,SR;interdit IRQ
 LEA $FFFF8800,A0
 MOVE.B #14,(A0);PSG YAMAHA port A
 MOVE.B (A0),D0
 BCLR #4,D0;bit 4 port A … 0
 MOVE.B D0,2(A0)
 BSET #4,D0;bit 4 port A … 1
 MOVE.B D0,2(A0)
 MOVE (SP),SR
 MOVE.L _HZ_200,D0
 ADDQ.L #2,D0;tempo 10 mS
\4:MOVE.L _HZ_200,D1
 CMP.L D0,D1
 BLT.S \4
 OR #$700,SR;interdit IRQ
 MOVE.B #14,(A0);PSG YAMAHA port A
 MOVE.B (A0),D0
 BCLR #4,D0;bit 4 port A … 0
 MOVE.B D0,2(A0)
 MOVE (SP)+,SR
\7:CMP.L _HZ_200,D1
 BEQ.S \7
 MOVE.L 8(SP),D0;taille
 MOVE.L 4(SP),A0;buffer
 IFNE 0,TOS4
  MOVE.L A0,D1
  BNE.S \6
  MOVEQ #71,D0;taille start 
  IFNE 0,TOS402
   LEA _START_DSP_TOS402,A0;buffer start
  ELSE
   LEA _START_DSP_TOS404,A0;buffer start
  ENDIF
 ENDIF
\6:MOVE.L #512,D1;taille maxi de 512 mots DSP
 SUB.L D0,D1
 SUBQ.L #1,D0
 BMI.S \5
\2:BTST #1,$FFFFA202
  BEQ.S \2
  MOVE.B (A0)+,$FFFFA205
  MOVE.B (A0)+,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\2
\5:SUBQ.L #1,D1
 BMI.S \1
 MOVEQ #0,D0
\3:BTST #1,$FFFFA202
  BEQ.S \3
  MOVE.B D0,$FFFFA205
  MOVE.B D0,$FFFFA206
  MOVE.B D0,$FFFFA207
 DBRA D1,\3
\1:RTS

DET_DSP_TRIGGERHC:

 MOVE 4(SP),D0;vecteur
 BSET #7,D0
 MOVE.B D0,$FFFFA201 
 RTS

DET_DSP_REQUESTUNIQUEABILITY:

 IFNE 0,TOS4
  MOVE _COMPT_ABILITY,D0
  INC D0
  MOVE D0,_COMPT_ABILITY
 ELSE
  MOVE COMPT_ABILITY,D0
  INC D0
  MOVE D0,COMPT_ABILITY
 ENDIF
 RTS

DET_DSP_GETPROGABILITY:

 IFNE 0,TOS4
  MOVE _ABILITY,D0
 ELSE
  MOVE ABILITY,D0
 ENDIF
 RTS

DET_DSP_FLUSHSUBROUTINES:

 IFNE 0,TOS4
  LEA _TAB_SUBROUT_DSP,A0
 ELSE
  LEA TAB_SUBROUT_DSP,A0
 ENDIF
 MOVEQ #MAX_SUBROUT_DSP,D0
\1:CLR.L (A0)
  CLR 10(A0)
  LEA 12(A0),A0
 DBRA D0,\1
 IFNE 0,TOS4
  MOVE.L _HIMEM_INIT,_HIMEM_DSP
  CLR _COMPT_SUBROUT
 ELSE
  MOVE.L HIMEM_INIT,HIMEM_DSP
  CLR COMPT_SUBROUT
 ENDIF
 RTS

DET_DSP_LOADSUBROUTINE:

 MOVE.L 8(SP),D2;taille
 CMP.L #$400,D2
 BGT.S \2
 IFNE 0,TOS4
  MOVE.L _RESERVE_DSP,D0
  ADD.L D2,D0
  MOVE.L _HIMEM_DSP,D1
 ELSE
  MOVE.L RESERVE_DSP,D0
  ADD.L D2,D0
  MOVE.L HIMEM_DSP,D1
 ENDIF
 CMP.L D1,D0
 BLE.S \3
\2:MOVEQ #0,D0;erreur
 BRA \1
\3:IFNE 0,TOS4
  MOVE _COMPT_SUBROUT,D0
  MULU #12,D0
  LEA _TAB_SUBROUT_DSP,A0
 ELSE
  MOVE COMPT_SUBROUT,D0
  MULU #12,D0
  LEA TAB_SUBROUT_DSP,A0
 ENDIF
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
 IFNE 0,TOS4
  MOVE.L _HIMEM_INIT,$FFFFA204
 ELSE
  MOVE.L HIMEM_INIT,$FFFFA204
 ENDIF
 SUB.L D1,D0
 BSR \ENVOI_D0
 IFNE 0,TOS4
  MOVE _COMPT_SUBROUT,D0
  MULU #12,D0
  LEA _TAB_SUBROUT_DSP,A0
 ELSE
  MOVE COMPT_SUBROUT,D0
  MULU #12,D0
  LEA TAB_SUBROUT_DSP,A0
 ENDIF
 MOVE.L 4(A0,D0.L),D0
 BRA.S \7
\6:ADD.L D0,(A0)
  MOVE 8(A0),D1
  SUB #23,D1
  MULS #6,D1
  ADDQ #4,D1
  IFNE 0,TOS4
   LEA _DATA_START_DSP+21,A1
  ELSE
   LEA DATA_START_DSP+21,A1
  ENDIF
  MOVE 2(A0),(A1,D1)
  LEA 12(A0),A0
\7:IFNE 0,TOS4
  CMP.L #_TAB_SUBROUT_DSP+(12*MAX_SUBROUT_DSP),A0
 ELSE
  CMP.L #TAB_SUBROUT_DSP+(12*MAX_SUBROUT_DSP),A0
 ENDIF
 BCS.S \6
 IFNE 0,TOS4
  ADD.L D0,_HIMEM_DSP
 ELSE
  ADD.L D0,HIMEM_DSP
 ENDIF
\5:IFNE 0,TOS4
  MOVE.L _HIMEM_DSP,D0
  SUB.L D2,D0
  MOVE.L D0,_HIMEM_DSP
  ADDQ.L #1,D0
  MOVE _COMPT_SUBROUT,D1
  MULU #12,D1
  LEA _TAB_SUBROUT_DSP,A0
  ADD.L D1,A0
  MOVEM.L D0/D2,(A0)
  MOVE 12(SP),10(A0);ability  
 ELSE
  MOVE.L HIMEM_DSP,D0
  SUB.L D2,D0
  MOVE.L D0,HIMEM_DSP
  ADDQ.L #1,D0
  MOVE COMPT_SUBROUT,D1
  MULU #12,D1
  LEA TAB_SUBROUT_DSP,A0
  ADD.L D1,A0
  MOVEM.L D0/D2,(A0)
  MOVE 12(SP),10(A0);ability  
 ENDIF
 MOVE 8(A0),D1
 SUB #23,D1
 MULS #6,D1
 ADDQ #4,D1
 IFNE 0,TOS4
  LEA _DATA_START_DSP+21,A0
 ELSE
  LEA DATA_START_DSP+21,A0
 ENDIF
 MOVE D0,(A0,D1)
 MOVE.B #$95,$FFFFA201
\9:BTST #7,$FFFFA201
 BNE.S \9
 MOVEQ #$2E,D0
 BSR.S \ENVOI_D0
 MOVEQ #16,D0
 BSR.S \ENVOI_D0
 IFNE 0,TOS4
  LEA _DATA_START_DSP+21,A0
 ELSE
  LEA DATA_START_DSP+21,A0
 ENDIF
 BSR.S \ENVOI_BLOC
 MOVE.B #$95,$FFFFA201
\11:BTST #7,$FFFFA201
 BNE.S \11
 IFNE 0,TOS4
  MOVE _COMPT_SUBROUT,D0
  MULU #12,D0
  LEA _TAB_SUBROUT_DSP,A0
 ELSE
  MOVE COMPT_SUBROUT,D0
  MULU #12,D0
  LEA TAB_SUBROUT_DSP,A0
 ENDIF
 ADD.L D0,A0
 MOVE.L (A0)+,D0
 BSR.S \ENVOI_D0
 MOVE.L (A0),D0
 BSR.S \ENVOI_D0
 MOVE.L D2,D0;taille
 MOVE.L 4(SP),A0;buffer
 BSR.S \ENVOI_BLOC
 IFNE 0,TOS4
  MOVE _COMPT_SUBROUT,D0
  INC _COMPT_SUBROUT
  CMP #8,_COMPT_SUBROUT
 ELSE
  MOVE COMPT_SUBROUT,D0
  INC COMPT_SUBROUT
  CMP #8,COMPT_SUBROUT
 ENDIF
 BLT.S \4
 IFNE 0,TOS4
  CLR _COMPT_SUBROUT
 ELSE
  CLR COMPT_SUBROUT
 ENDIF
\4:MULU #12,D0
 IFNE 0,TOS4
  LEA _TAB_SUBROUT_DSP,A0
 ELSE
  LEA TAB_SUBROUT_DSP,A0
 ENDIF
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
 IFNE 0,TOS4
  LEA _TAB_SUBROUT_DSP,A0
 ELSE
  LEA TAB_SUBROUT_DSP,A0
 ENDIF
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
 IFNE 0,TOS4
  LEA _DATA_START_DSP+21,A0
 ELSE
  LEA DATA_START_DSP+21,A0
 ENDIF
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
 SUBQ.L #1,D0
 BMI.S \2
\3:BTST #1,$FFFFA202
  BEQ.S \3
  MOVE (A0)+,D2
  EXT.L D2
  MOVE.L D2,$FFFFA204
 DBRA D0,\3
\2:SUBQ.L #1,D1
 BMI.S \1
\4:BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.B $FFFFA206,(A1)+
  MOVE.B $FFFFA207,(A1)+
 DBRA D1,\4
\1:RTS

DET_DSP_BLKBYTES:

 MOVE.L 4(SP),A0;buffer ‚mission
 MOVE.L 8(SP),D0;taille ‚mission
 MOVE.L 12(SP),A1;buffer r‚ception
 MOVE.L 16(SP),D1;taille r‚ception
 SUBQ.L #1,D0
 BMI.S \2
\3:BTST #1,$FFFFA202
  BEQ.S \3
  MOVE.B #0,$FFFFA205
  MOVE.B #0,$FFFFA206
  MOVE.B (A0)+,$FFFFA207
 DBRA D0,\3
\2:SUBQ.L #1,D1
 BMI.S \1
\4:BTST #0,$FFFFA202
  BEQ.S \4
  MOVE.B $FFFFA206,D2
  MOVE.B $FFFFA207,(A1)+
 DBRA D1,\4
\1:RTS

DET_DSP_HSTAT:

 MOVE.B $FFFFA202,D0
 MOVE.B $FFFFA201,D1
 RTS

DET_DSP_SETVECTORS:

 IFNE 0,TOS4
  MOVE.L 4(SP),_RECEIVER
 ELSE
  MOVE.L 4(SP),RECEIVER
 ENDIF
 BEQ.S \2
 LEA IRQ_SETVECTORS(PC),A0
 MOVE.L A0,$3FC
 MOVE.B #-1,$FFFFA203
 BSET #0,$FFFFA200
\2:IFNE 0,TOS4
  MOVE.L 8(SP),_TRANSMITTER
 ELSE
  MOVE.L 8(SP),TRANSMITTER
 ENDIF 
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
 IFNE 0,TOS4
  MOVE.L _RECEIVER,D0
 ELSE
  MOVE.L RECEIVER,D0
 ENDIF
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
 IFNE 0,TOS4
  MOVE.L _TRANSMITTER,D0
 ELSE
  MOVE.L TRANSMITTER,D0
 ENDIF
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
 DC.B $08,$F4,$A8,$00,$00,$04; $40: MOVEP #>4,X:<<HCR pas d'interruptions port HOST    
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

START_DSP:;71 mots DSP                 $E4AC82:TOS404  $E4AC22:TOS402

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

MESS1:DC.B 13,10,10,27,"p DSPXBIOS v1.02 ",27,"q"
      DC.B 13,10,"December 2001 / MEQUIGNON Didier"
      DC.B 13,10,"XBIOS functions with handshake installed",0

 ALIGN.W
 BSS
TRANSMITTER:DS.L 1                    ;$16F0
RECEIVER:DS.L 1                       ;$16F4
PARAMS_IRQ_DSP:DS.L 8                 ;$16F8
TAB_SUBROUT_DSP:DS.L 3*MAX_SUBROUT_DSP;$1720
HIMEM_DSP:DS.L 1                      ;$1780
HIMEM_INIT:DS.L 1                     ;$1784
RESERVE_DSP:DS.L 1                    ;$1788
ABILITY:DS.W 1                        ;$178C
COMPT_SUBROUT:DS.W 1                  ;$178E
COMPT_ABILITY:DS.W 1                  ;$1790
D_LOCK:DS.W 1                         ;$17DE

FIN:

  END
