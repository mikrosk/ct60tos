PROC_TYPE EQU $59E
_COOKIE EQU $5A0

 ILABEL TOS.Q

DEBUT:

 MOVE.L 4(SP),A5;d‚but de la basepage
 MOVE.L $C(A5),D0;taille segment TEXT
 ADD.L $14(A5),D0;taille segment DATA
 ADD.L $1C(A5),D0;taille segment BSS
 ADD.L #1800,D0;pour la pile et la basepage
 AND.B #$FE,D0
 LEA -104(A5,D0.L),SP
 SETBLOCK D0,(A5)
 MOVE.L #"_CPU",D0
 BSR GET_COOKIE
 BMI \1;pas de cookie-jar
 MOVE.L D0,A0
 CMP.L #60,(A0)
 BNE \1
 SUPEXEC CACHE_OFF
 EXEC ENV,COM,NOM,#0
 SUPEXEC CACHE_ON
 TERM
\1:EXEC ENV,COM,NOM,#0
 TERM
 ILLEGAL
 RTS
 
CACHE_OFF:

 MOVE SR,-(SP)
 OR #$700,SR;masque IRQ
 MOVEQ #0,D0;inhibe & vide caches
 DC.L $4E7B0002;MOVEC.L D0,CACR
 DC.W $F4F8;CPUSHA BC
 MOVE (SP)+,SR
 RTS

CACHE_ON:
 
 MOVE SR,-(SP)
 OR #$700,SR;masque IRQ
 DC.W $F4F8;CPUSHA BC
 MOVE.L #$A0C08000,D0;68060
; B31:EDC Enable Data Cache
; B29:ESB Enable Store Buffer
; B23:EBC Enable Branch Cache
; B22:CABC Clear All Entries Branch Cache
; B15:EIC Enable Instruction Cache
 DC.L $4E7B0002;MOVEC.L D0,CACR
 MOVE (SP)+,SR
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

 DATA

 ALIGN

NOM:DC.B "C:\GDOS\SPDGDOS.PRG",0
 ALIGN
COM:DC.B 0
ENV:DC.B 0 
 
 END
 