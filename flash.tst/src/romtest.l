
 ILABEL TOS.Q
 
FLASH EQU 1  ; 0:.PRG, 1:TEST CT60, 2:test cartouche F030
INCLUDE_VIDEO_MODE EQU 1

 IFNE 0,FLASH
my_stack equ $10000
 ELSE
my_stack equ fin
 ENDIF
 
TIME_OUT_DSP EQU 200*5;1 seconde

CLOCKS_PER_SEC equ 200
_FRCLOCK EQU $466
_hz_200 equ $4ba

screen_adr equ my_stack+$100
screen_width equ screen_adr+4
screen_height equ screen_adr+6
cursor_x equ screen_adr+8
cursor_y equ screen_adr+10
flag equ screen_adr+12
VECT_EXC equ screen_adr+14
SAUVE_RESVALID equ screen_adr+16
SAUVE_REG equ screen_adr+20
SAUVE_USP equ screen_adr+80
SAUVE_SSP equ screen_adr+84
buffer_info_eeprom_flash equ screen_adr+88
CLAV equ screen_adr+216
JOY equ screen_adr+218
XJOY equ screen_adr+220
YJOY equ screen_adr+222
M_XJOY equ screen_adr+224
M_YJOY equ screen_adr+226
CURJOY equ screen_adr+228
M_CURJOY equ screen_adr+230
FLAG_JOY equ screen_adr+232
FLAG_CACHE equ screen_adr+234
FLAG_AFF equ screen_adr+236
FLAG_SDRAM equ screen_adr+238
SAUVE_STACK equ screen_adr+240
SAUVE_CACR equ screen_adr+256
INFO_DEBUG_DSP equ screen_adr+260
ABIL equ screen_adr+264
TIME_OUT equ screen_adr+266
OK_IRQ_DSP equ screen_adr+268
BUFFER_DSP equ screen_adr+270
COMPT_DSP equ screen_adr+274
offset equ screen_adr+276
buffer_dsp_bliter equ screen_adr+278
flag_blitter equ screen_adr+282
flag_pmmu equ screen_adr+284
flag_move16 equ screen_adr+286

PILE_CRASH equ screen_adr+$200
MES_DELAY_STRAM equ screen_adr+$200

TABVEC_SCC_B EQU screen_adr+$300
TAB_SPEED_REG_SCC_B EQU TABVEC_SCC_B+28
TAB_SPEED_SCC_B EQU TABVEC_SCC_B+60
IOREC_SCC_B EQU TABVEC_SCC_B+124
IBUF_RX_SCC_B EQU TABVEC_SCC_B+124
IBUFSIZE_RX_SCC_B EQU TABVEC_SCC_B+128
IBUFHD_RX_SCC_B EQU TABVEC_SCC_B+130
IBUFTL_RX_SCC_B EQU TABVEC_SCC_B+132
IBUFLOW_RX_SCC_B EQU TABVEC_SCC_B+134
IBUFHI_RX_SCC_B EQU TABVEC_SCC_B+136
IOREC_TX_SCC_B EQU TABVEC_SCC_B+138
IBUF_TX_SCC_B EQU TABVEC_SCC_B+138
IBUFSIZE_TX_SCC_B EQU TABVEC_SCC_B+142
IBUFHD_TX_SCC_B EQU TABVEC_SCC_B+144
IBUFTL_TX_SCC_B EQU TABVEC_SCC_B+146
IBUFLOW_TX_SCC_B EQU TABVEC_SCC_B+148
IBUFHI_TX_SCC_B EQU TABVEC_SCC_B+150
UCR_SCC_B EQU TABVEC_SCC_B+152
PAR_CTRL_SCC_B EQU TABVEC_SCC_B+153
FLAG_TX_XOFF_SCC_B  EQU TABVEC_SCC_B+154
FLAG_RX_XOFF_SCC_B EQU TABVEC_SCC_B+155
FLOW_SCC_B EQU TABVEC_SCC_B+156
SEND_NOW_SCC_B EQU TABVEC_SCC_B+157
INDEX_SPEED_SCC_B EQU TABVEC_SCC_B+158
MASK_RX_SCC_B EQU TABVEC_SCC_B+159
SPEED_SCC_B EQU TABVEC_SCC_B+160
FLAGS_SCC_B EQU TABVEC_SCC_B+164
MODE_PAR_SCC_B EQU TABVEC_SCC_B+168
MCTRL_SCC_B EQU TABVEC_SCC_B+169
TABVEC_SCC_A EQU TABVEC_SCC_B+170  
TAB_SPEED_REG_SCC_A EQU TABVEC_SCC_B+198  
TAB_SPEED_SCC_A EQU TABVEC_SCC_B+230 
IOREC_SCC_A EQU TABVEC_SCC_B+294 
IBUF_RX_SCC_A EQU TABVEC_SCC_B+294
IBUFSIZE_RX_SCC_A EQU TABVEC_SCC_B+298
IBUFHD_RX_SCC_A EQU TABVEC_SCC_B+300
IBUFTL_RX_SCC_A EQU TABVEC_SCC_B+302
IBUFLOW_RX_SCC_A EQU TABVEC_SCC_B+304
IBUFHI_RX_SCC_A EQU TABVEC_SCC_B+306
IOREC_TX_SCC_A EQU TABVEC_SCC_B+308
IBUF_TX_SCC_A EQU TABVEC_SCC_B+308
IBUFSIZE_TX_SCC_A EQU TABVEC_SCC_B+312
IBUFHD_TX_SCC_A EQU TABVEC_SCC_B+314
IBUFTL_TX_SCC_A EQU TABVEC_SCC_B+316
IBUFLOW_TX_SCC_A EQU TABVEC_SCC_B+318
IBUFHI_TX_SCC_A EQU TABVEC_SCC_B+320
UCR_SCC_A EQU TABVEC_SCC_B+322
PAR_CTRL_SCC_A EQU TABVEC_SCC_B+323
FLAG_TX_XOFF_SCC_A EQU TABVEC_SCC_B+324
FLAG_RX_XOFF_SCC_A EQU TABVEC_SCC_B+325
FLOW_SCC_A EQU TABVEC_SCC_B+326
SEND_NOW_SCC_A EQU TABVEC_SCC_B+327
INDEX_SPEED_SCC_A EQU TABVEC_SCC_B+328
MASK_RX_SCC_A EQU TABVEC_SCC_B+329
SPEED_SCC_A EQU TABVEC_SCC_B+330
FLAGS_SCC_A EQU TABVEC_SCC_B+334
MODE_PAR_SCC_A EQU TABVEC_SCC_B+338
MCTRL_SCC_A EQU TABVEC_SCC_B+339
PTR_END EQU TABVEC_SCC_B+340
FLAGS_LAN_SERIAL2 EQU TABVEC_SCC_B+344

out equ screen_adr+$800 
my_screen equ my_stack+$1000
MES_DELAY_SDRAM equ $1000000

WAIT_US:MACRO

 move.b (A0),D0
\1: cmp.b (A0),D0       ;26uS (timer C) or 1,6/6,5uS (timer B)
 beq.s \1
 ENDM

DEVCONNECT2:MACRO $\1,$\2,$\3,$\4;handshake d‚sactiv‚

 MOVE \1,-(SP);prescale pr‚diviseur de l'horloge source
; … 25 MHz: 0: fr‚quences STE
;           1: /2  49170 Hz
;           2: /3  32780 Hz
;           3: /4  24585 Hz
;           4: /5  19668 Hz
;           5: /6  16390 Hz
;           7: /8  12292 Hz
;           9: /10  9834 Hz
;          11: /12  8195 Hz
 MOVE \2,-(SP);source clock: interne 25MHz(0)/externe(1)/DSP 32MHz(2)
 MOVE \3,-(SP);destination:
; enregistrement DMA(1)/DSP r‚ception(2)/sortie externe(4)/DAC(8)
 MOVE \4,-(SP);source:
; lecture DMA(0)/DSP transmission(1)/entr‚e externe(2)/ADC ou Yamaha(3)
 BSR DEVCONNECT_2
 ADDQ #8,SP
 ENDM

CACHE_OFF:MACRO

 pea string4a(pc)
 bsr display_string
 addq.w #4,sp
 MOVE SR,-(SP)
 OR #$700,SR;masque IRQ
 MOVEQ #0,D0;inhibe & vide caches
 DC.L $4E7B0002;MOVEC.L D0,CACR
 IFEQ 1,FLASH
  DC.W $F4F8;CPUSHA BC
 ENDIF 
 MOVE (SP)+,SR
 CLR.B FLAG_CACHE
 pea string4(pc)
 bsr display_string
 addq.w #4,sp
 ENDM

CACHE_ON:MACRO

 movem.l D0-D1/A0,-(SP)
 pea string4a(pc)
 bsr display_string
 addq.w #4,sp
 MOVE SR,-(SP)
 OR #$700,SR;masque IRQ
 IFEQ 1,FLASH
  DC.W $F4F8;CPUSHA BC
  MOVE.L #$A0808000,D0;68060
  TST.B FLAG_CACHE+1
  SNE.B D1
  EXT.W D1
  EXT.L D1
  OR.L #$7FFFFFFF,D1
  AND.L D1,D0;Data Cache ON/OFF
; B31:EDC Enable Data Cache
; B29:ESB Enable Store Buffer
; B23:EBC Enable Branch Cache
; B22:CABC Clear All Entries Branch Cache
; B15:EIC Enable Instruction Cache
 ELSE
  MOVE.L #$3111,D0;68030
 ENDIF
 DC.L $4E7B0002;MOVEC.L D0,CACR
 MOVE (SP)+,SR
 ST.B FLAG_CACHE
 lea string4b(pc),A0
 TST.B FLAG_CACHE+1
 SNE.B D1
 EXT.W D1
 EXT.L D1
 and.l #string4c-string4b,d1
 add.l d1,a0
 pea (A0)
 bsr display_string
 addq.w #4,sp
 movem.l (SP)+,D0-D1/A0
 ENDM
 
PMMU_OFF:MACRO

 movem.l D0-D1/A0,-(SP)
 MOVE SR,-(SP)
 OR #$700,SR;masque IRQ
 IFEQ 1,FLASH
  DC.W $F4F8;CPUSHA BC
  MOVEQ #0,D0
  DC.L $4E7B0007;MOVEC.L D0,DTT1
  DC.L $4E7B0005;MOVEC.L D0,ITT1
  DC.L $4E7B0006;MOVEC.L D0,DTT0
  DC.L $4E7B0004;MOVEC.L D0,ITT0
 ENDIF
 MOVE (SP)+,SR
 CLR FLAG_PMMU
 pea string14(pc)
 bsr display_string
 addq.w #4,sp
 movem.l (SP)+,D0-D1/A0
 ENDM  
 
PMMU_ON:MACRO

 movem.l D0-D1/A0,-(SP)
 MOVE SR,-(SP)
 OR #$700,SR;masque IRQ
 IFEQ 1,FLASH
  DC.W $F4F8;CPUSHA BC
  MOVE.L #$807FE040,D0;zone $00000000-$7FFFFFFF en mode writethrough
  ;sauf signal CI venant de l'exterieur =>  cache inhibit imprecise)
  ;et la zone $80000000-$FFFFFFFF en cache inhibit precise
  DC.L $4E7B0006;MOVEC.L D0,DTT0
  DC.L $4E7B0004;MOVEC.L D0,ITT0
 ENDIF
 MOVE (SP)+,SR
 ST.B FLAG_PMMU
 pea string14p(pc)
 bsr display_string
 addq.w #4,sp
 movem.l (SP)+,D0-D1/A0
 ENDM  

DEBUT:

 IFEQ 0,FLASH
  MOVE.L 4(SP),A5;D‚but de la basepage
  MOVE.L $C(A5),D0
  ADD.L $14(A5),D0
  ADD.L $1C(A5),D0
  ADD.L #256,D0
  SETBLOCK D0,(A5)
  SUPER 0

;----Start------------------------------

 IFEQ 0,INCLUDE_VIDEO_MODE
  move.l #mode,-(sp)
  bsr videl_save_mode
  addq.l #4,sp
 ENDIF
 move.w #$2700,sr;Coupe les interruptions
;Coupe le cache
 move.l #$808,d0
 dc.l $4E7B0002; movec.l d0,cacr
 clr.l d0
 dc.l $4E7B0002; movec.l d0,cacr
;R‚initialise le VBR
 clr.l d0
 dc.l $4E7B0801; movec.l d0,vbr
;D‚sactive la PMMU
; lea $8,a0; On croise les doigts pour que $8 soit
; clr.l (a0)
; dc.l $F0104000; pmove.l (a0),tc
; dc.l $F0100800; pmove.l (a0),tt0
; dc.l $F0100C00; pmove.l (a0),tt1 
;; move.l #$00FF8507,(a0);accessible en ‚criture...
;; dc.l $F0100800; pmove.l (a0),tt0
 ENDIF
 
 IFEQ 2,FLASH    
 DC.L $FA52235F   ;En-tete Cartouche
 ENDIF

 bra.s \reset;   En-tete ROM
 dc.w $0404
 dc.l $00E00030
 DS.b $28,0
\reset:
 move.w #$2700,sr; Coupe interruptions

 IFNE 0,FLASH
 move.w $FFFF8006,d0;  Init du combel
 reset
 move.w $FFFF8006,d0; Les 2 instructions indispensables
 move.w #7,$FFFF8940;  apr‚s un reset sur Falcon
 ori.b #$25,$FFFF8007; Passage … 25 MHz
 ENDIF

;pmmu

 IFEQ 1,FLASH
  DC.L $4E7A0808;MOVEC.L PCR,D0
  BSET #0,D0; active architecture superscalaire
  DC.L $4E7B0808;MOVEC.L D0,PCR
;init PMMU 68060
  MOVEQ #0,D0
  DC.L $4E7B0003;MOVEC.L D0,TCR
  MOVE.L #$0100E020,D0;zone $01000000-$01FFFFFF en mode copyback
  DC.L $4E7B0007;MOVEC.L D0,DTT1
  DC.L $4E7B0005;MOVEC.L D0,ITT1
  MOVE.L #$807FE040,D0;zone $00000000-$7FFFFFFF en mode writethrough
  ;sauf signal CI venant de l'exterieur =>  cache inhibit imprecise)
  ;et la zone $80000000-$FFFFFFFF en cache inhibit precise
  DC.L $4E7B0006;MOVEC.L D0,DTT0
  DC.L $4E7B0004;MOVEC.L D0,ITT0
 ENDIF
 
;cache 

; IFEQ 1,FLASH
;  DC.W $F4F8;CPUSHA BC
;  MOVE.L #$A0808000,D0;68060
;  TST.B FLAG_CACHE+1
;  SNE.B D1
;  EXT.W D1
;  EXT.L D1
;  OR.L #$7FFFFFFF,D1
;  AND.L D1,D0;Data Cache ON/OFF
; B31:EDC Enable Data Cache
; B29:ESB Enable Store Buffer
; B23:EBC Enable Branch Cache
; B22:CABC Clear All Entries Branch Cache
; B15:EIC Enable Instruction Cache
; ELSE
;  MOVE.L #$3111,D0;68030
; ENDIF
; DC.L $4E7B0002;MOVEC.L D0,CACR
; ST.B FLAG_CACHE 

;Init du videl : copie du type de moniteur connect‚
 move.b $FFFF8006,d0
 move.b d0,d1
 lsl.b #6,d1
 and.b #$80,d1
 lsr.b #6,d0
 or.b d0,d1
 move.w d1,$FFFF82C0

;--------------------
 lea my_screen,A0
 move.l a0,screen_adr
 move.w #80,screen_width
 move.w #60,screen_height

 move.l screen_adr,d0
 swap d0
 move.b d0,$FFFF8201
 rol.l #8,d0
 move.b d0,$FFFF8203
 rol.l #8,d0
 move.b d0,$FFFF820D

 lea my_stack+$100,sp

 lea $ffff8800,a0
 move.b #7,(a0);port A & B
 move.b #$c0,2(a0);en sortie
 move.b #14,(a0);port A
 move.b #7,2(a0);d‚s‚lection disquettes
 MOVE.L #$90C,SAVPTR
 CLR.L _HZ_200
 bsr INIT_EXC
 bsr init_mfp
 pea mode(pc)
 bsr videl_set_mode
 addq.l #4,sp

 lea colors(pc),a0
 lea $FFFF9800,a1
 move.l (a0)+,(a1)+
 move.l (a0)+,(a1)+

 clr.w cursor_x
 clr.w cursor_y
 bsr clear_screen

 lea MES_DELAY(pc),a0
 lea MES_DELAY_STRAM,a1
 moveq #((END_MES_DELAY-MES_DELAY)/2)-1,D0
\cp:move.w (a0)+,(a1)+
 dbra d0,\cp

 MOVE #$80,D0
 BSR ENVOI_CLAVIER
 MOVEQ #1,D0
 BSR ENVOI_CLAVIER
 bsr tempo_2s
 MOVEQ #$12,D0;d‚connecte la souris
 BSR ENVOI_CLAVIER
 
 clr.w cursor_x
 clr.w cursor_y
 clr FLAG_SDRAM
 CLR FLAG
 CLR M_XJOY
 CLR M_YJOY
 CLR M_CURJOY
 CLR CURJOY
 CLR FLAG_JOY
 MOVE #-1,CLAV
 MOVE #-1,FLAG_CACHE
 MOVE #-1,flag_pmmu
 st.b FLAG_AFF

 bra \stram_bad
 
 bsr clear_screen
 pea string17(pc)
 bsr display_string
 addq.w #4,SP 
 clr.l _hz_200
 MOVE #$2500,SR;autorise interruptions
\wait_key_r:
 bsr read_clav
 bmi \wait_key_r 
 cmp #$23,D0;R
 bne \stram_bad 
 LEA $E00000,A0
 LEA $200000,A1
 MOVE.L #$100000/2,D0
\copy_stram:
  MOVE (A0)+,(A1)+
 SUB.L #1,D0
 BGT.S \copy_stram
 LEA $E00000,A0
 LEA $200000,A1
 MOVE.L #$100000/4,D1
\verify_stram:
  move.l (a0)+,d6
  move.l (a1)+,d0
  cmp.l d0,d6
  bne.s \erreur_st_ram 
 SUB.L #1,D1
 BGT.S \verify_stram
 bra.s \stram_ok
\erreur_st_ram:
 move.l d0,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 subq #4,A1
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR AFF_HEX_LONG_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_LONG_D0 
 pea string9(pc);at
 bsr display_string
 addq.w #4,sp  
 MOVE.L a1,D0
 BSR AFF_HEX_LONG_D0
 bsr tempo_2s
 bsr tempo_2s
 bsr tempo_2s
 bsr tempo_2s
 bsr tempo_2s
 bra.s \stram_bad
\stram_ok:
 pea string10(pc)
 bsr display_string
 addq.w #4,SP 
 bsr tempo_2s
 lea \start_stram(pc),a0
 sub.l #$E00000-$200000,A0
 jmp (a0)
\start_stram:
 pea string11(pc)
 bsr display_string
 addq.w #4,SP 
 bsr tempo_2s

\stram_bad:
 clr.l _hz_200
 CACHE_ON
 MOVE #$2300,SR;autorise interruptions
; pea string_dsp1(pc)
; bsr display_string
; addq.w #4,sp
; bsr init_dsp
; bpl \menu
; pea error3(pc);time-out
; bsr display_string
; addq.w #4,sp
; bsr tempo_2S

\menu:

 st.b FLAG_SDRAM
 MOVE #-1,CLAV
 clr.w cursor_x
 clr.w cursor_y
 clr.w offset
 bsr clear_screen
 bsr aff_logo
 moveq #0,D7
 IFEQ 1,FLASH
  DC.L $4E7A0808;MOVEC.L PCR,D0
  move.l D0,D7
 ENDIF
 pea string_pcr(pc)
 bsr display_string
 addq.w #4,SP 
 move.l d7,D0
 BSR AFF_HEX_LONG_D0
 move.l d7,D0 
 swap d0
 lea proc_full(pc),A0
 cmp.w #$0430,d0
 beq.s \full
 lea proc_ec_lc(pc),A0
 cmp.w #$0431,d0
 beq.s \ec_ou_lc
 lea proc_inconnu(pc),A0
\full:
\ec_ou_lc:
 pea (a0)
 bsr display_string
 addq.w #4,sp
 pea menu(pc)
 bsr display_string
 addq.w #4,sp
\wait:
  clr.w cursor_x
  move.l _hz_200,d0
  BSR AFF_HEX_LONG_D0
  move #" ",-(sp)
  bsr display_char
  addq #2,sp  
 bsr read_clav
 bmi.s \wait
 cmp #$A,D0;CLR HOME
 bne \suite_clav
 tst.b FLAG_CACHE
 BNE.S \c0
 CACHE_ON
 bsr tempo_2S
 bra \menu
\c0:CACHE_OFF
 bsr tempo_2S
 bra \menu
\suite_clav:
 cmp #$1B,D0;INSERT
 BNE \suite_clav0
 tst.b FLAG_PMMU
 BNE.S \c00
 PMMU_ON
 bsr tempo_2S
 bra \menu
\c00:PMMU_OFF
 bsr tempo_2S
 bra \menu
\suite_clav0:cmp #$C,D0;
 bne \suite_clav3
 move SR,D0
 lsr #8,D0
 and #7,D0
 cmp #4,d0
 bcc.s \ipl0
 pea string6b(pc)
 bsr display_string
 addq.w #4,sp
 MOVE #$2500,SR
 bsr tempo_2S
 bra \menu
\ipl0:
 pea string6(pc)
 bsr display_string
 addq.w #4,sp
 MOVE #$2300,SR
 bsr tempo_2S
 bra \menu
\suite_clav3:
 cmp #$D,D0;
 bne \suite_clav4
 NOT.B FLAG_CACHE+1
 CACHE_ON
 bsr tempo_2S
 bra \menu
\suite_clav4:
 cmp #$F,D0;BACKSPACE
 bne \suite_clav2
 tst FLAG_AFF
 BNE.S \aff0
; bsr inith_port_mfp
 st.b FLAG_AFF
 pea string5b(pc)
 bsr display_string
 addq.w #4,sp
 bsr tempo_2S
 bra \menu
\aff0:
 clr FLAG_AFF  
; bsr initl_port_mfp
 pea string5(pc)
 bsr display_string
 addq.w #4,sp
 bsr tempo_2S
 bra \menu
\suite_clav2:
 clr.w cursor_x
 clr.w cursor_y
 bsr clear_screen
; tst D0
; beq \infos_crash
 tst d0
 beq \test_scc
 cmp #1,D0
 beq \temperature
 cmp #2,D0
 beq \config_sdram
 cmp #3,D0
 beq \read_info_sdram
 cmp #4,D0
 beq \test_dsp
 cmp #5,D0
 beq \test_berr
 cmp #$10,D0;F1
 beq \sdram_write_page
 cmp #$11,D0;F2
 beq \sdram_read_page
 cmp #$12,D0;F3
 beq \sdram_write_page_long
 cmp #$13,D0;F4
 beq \sdram_read_page_long
 clr flag_move16
 cmp #$14,D0;F5
 beq \sdram_verify_page
 cmp #$15,D0;F6
 beq \sdram_write
 cmp #$16,D0;F7
 beq \sdram_read
 cmp #$17,D0;F8
 beq \sdram_write_long
 cmp #$18,D0;F9
 beq \sdram_read_long
 cmp #$19,D0;F10
 beq \sdram_verify
; bne.s \XXXX
; bsr ct60_configure_eeprom
; bsr tempo_2S
; bra \menu
;\XXXX:
 cmp #$24,D0;T
 beq \sdram_write_page_word
 cmp #$25,D0;Y
 beq \sdram_write_word
 st.b flag_move16
 st.b flag_move16+1
 cmp #$20,D0;A
 beq \sdram_verify_page
 cmp #$21,D0;Z
 beq \sdram_verify
 clr.b flag_move16
 cmp #$22,D0;E
 beq \sdram_verify_page
 cmp #$23,D0;R
 beq \sdram_verify 
 CMP #$26,D0;U
 beq \flash_write_move
 CMP #$27,D0;I
 beq \flash_write_moves
 CMP #$28,D0;O
 beq \test_dma
 cmp #$29,D0;P
 beq \dump
 cmp #6,D0
 beq \mips
 clr flag
 cmp #7,D0
 beq \blitter
 st.b flag
 cmp #8,D0
 beq \blitter
 CMP #9,D0
 beq \test_stram
 bne \menu
 
\infos_crash:
 lea my_stack+$100,A0
 MOVE.L SAUVE_SSP,D0
 CMP.L A0,D0
 BHI.S \erreur_infos;erreur
 lea my_stack,A0
 CMP.L A0,D0
 BCC.S \suite_infos
\erreur_infos:
 pea error2(pc)
 bsr display_string
 addq.w #4,sp
 bsr tempo_2S
 bra \menu
\suite_infos:
 LEA SAUVE_STACK,A6
 BSR INFOS_CRASH
 move #-1,CLAV
\wait_infos:
 bsr read_clav
 bmi.s \wait_infos 
 bra \menu
 
\dump:

 pea string16(pc);register
 bsr display_string
 addq.w #4,sp 
 moveq #7,d1
 moveq #0,d2
 move #-1,CLAV
\dump2:
  bsr read_clav
  bmi.s \dump2
  cmp #$E,d0
  beq \menu
  cmp #$20,d0;A
  bne.s \dump6
  moveq #$A,d0
  bra.s \dump8
\dump6:cmp #$44,d0;B
  bne.s \dump7
  moveq #$B,d0
  bra.s \dump8
\dump7:cmp #$42,d0;C
  bne.s \dump9
  moveq #$C,d0
  bra.s \dump8
\dump9:cmp #$32,d0;D
  bne.s \dump10
  moveq #$D,d0
  bra.s \dump8
\dump10:cmp #$22,d0;E
  bne.s \dump11
  moveq #$E,d0
  bra.s \dump8
\dump11:cmp #$33,d0;F
  bne.s \dump12
  moveq #$F,d0
  bra.s \dump8
\dump12:
  cmp #$A,D0
  bcc.s \dump2
\dump8:
  move d0,d3
  add.b #"0",d3
  cmp.b #"9",d3
  bls.s \dump5
  addq.b #7,d3
\dump5:
  move d3,-(sp)
  bsr display_char
  addq #2,sp
  asl.l #4,d2  
  or.b d0,d2
 dbra d1,\dump2
 move.l d2,a1
 moveq #15,d2
\dump3:
  move #13,-(sp)
  bsr display_char
  addq #2,sp
  move.l a1,d0
  BSR AFF_HEX_LONG_D0 
  move #":",-(sp)
  bsr display_char
  addq #2,sp
  move #" ",-(sp)
  bsr display_char
  addq #2,sp
  moveq #3,d1
\dump4:
   move.l (a1)+,d0
   BSR AFF_HEX_LONG_D0 
   move #" ",-(sp)
   bsr display_char
   addq #2,sp
  dbra d1,\dump4
 dbra d2,\dump3
 move #-1,CLAV
\dump1:
 bsr read_clav
 bmi.s \dump1
 bra \menu
 
\flash_write_move:

 move.l #$10001,D0;write
 moveq #0,D1
 moveq #0,D2
 bsr ct60_rw_param
 tst.l d0
 bmi \error_flash
 move.l #$10001,D0;write
 moveq #0,D1
 moveq #1,D2
 bsr ct60_rw_param
 tst.l d0
 bmi \error_flash
 bsr tempo_2s
 bra \menu
 
\flash_write_moves:
                    
 moveq #1,D0;write
 moveq #0,D1
 moveq #0,D2
 bsr ct60_rw_param
 tst.l d0
 bmi.s \error_flash
 moveq #1,D0;write
 moveq #0,D1
 moveq #1,D2
 bsr ct60_rw_param
 tst.l d0
 bmi.s \error_flash
 bsr tempo_2s
 bra \menu
 
\error_flash:
 cmp.l #-15,d0;Flash device error
 bne.S \error_flash1
 pea error10(pc)
 bsr display_string
 addq.w #4,sp  
 MOVE.L d1,d0
 BSR AFF_HEX_LONG_D0
 bsr tempo_2s
 bra \menu
\error_flash1:
 cmp.l #-11,D0;Flash erase error
 bne.s \error_flash2
 pea error11(pc)
 bsr display_string
 addq.w #4,sp  
 bsr tempo_2s
 bra \menu 
\error_flash2:
 cmp.l #-10,D0;Flash program error
 bne.s \flash_ok
 pea error12(pc)
 bsr display_string
 addq.w #4,sp  
\flash_ok:
 bsr tempo_2s
 bra \menu 
 
\test_dma:

 lea $100000,A0;STRAM
 move.l A0,A1
 lea sample(PC),A2
 lea end_sample(PC),A3
\dma2:move (A2)+,D0
  move (A2)+,D1
  move D0,(A1)+
  move D1,(A1)+
  move D0,(A1)+
  move D1,(A1)+
  move D0,(A1)+
  move D1,(A1)+
  move D0,(A1)+
  move D1,(A1)+
 cmp.l A3,A2
 bcs.s \dma2
 clr.b $FFFF8900
 clr.b $FFFF8901
 move.b #3,$FFFF8920;4 tracks
 clr.b $FFFF8921
 move.w #$11,$FFFF8930
 clr.w $FFFF8932
 clr.b $FFFF8934
 clr.b $FFFF8935
 clr.b $FFFF8936
 move.b #3,$FFFF8937
 move.b #3,$FFFF8938
 move.b #$88,$FFFF8939
 move.w #$550,$FFFF893A
 DEVCONNECT2 #1,#0,#8,#0;lecture DMA -> DAC 
 bsr play_dma
 move #-1,CLAV
\dma1:
 bsr read_clav
 bmi.s \dma1
 bsr stop_dma
 bra \menu
 
\test_scc:

 bsr init_scc
 move #13,-(sp)
 bsr display_char
 addq #2,sp
\test_scc1:
  cmp #$E,CLAV
  beq \menu 
  move #13,-(sp)
  bsr display_char
  addq #2,sp
  moveq #"A",d0
  move d0,-(sp)
  bsr display_char
  move (sp)+,d0
  bsr BCONOUT_SCC_B 
  moveq #"T",d0
  move d0,-(sp)
  bsr display_char
  move (sp)+,d0
  bsr BCONOUT_SCC_B
  moveq #"D",d0
  move d0,-(sp)
  bsr display_char
  move (sp)+,d0
  bsr BCONOUT_SCC_B
  moveq #"L",d0
  move d0,-(sp)
  bsr display_char
  move (sp)+,d0
  bsr BCONOUT_SCC_B
  moveq #13,d0
  move d0,-(sp)
  bsr display_char
  move (sp)+,d0
  bsr BCONOUT_SCC_B  
  bsr tempo_2S
\test_scc2:
   bsr BCONSTAT_SCC_B
   tst d0
   beq.s \test_scc1
   bsr BCONIN_SCC_B
   cmp.b #10,d0
   beq.s \test_scc2
   move d0,-(sp)
   bsr display_char
   addq #2,sp
 bra.s \test_scc2
; bsr verify_scc
; bpl.s \test_scc
; pea string15(pc);register
; bsr display_string
; addq.w #4,sp 
; BSR HEX_D0 
; pea string7(pc);write
; bsr display_string
; addq.w #4,sp  
; MOVE D1,D0
; BSR HEX_D0 
; pea string8(pc);read
; bsr display_string
; addq.w #4,sp  
; MOVE d2,D0
; BSR HEX_D0
 bra \test_scc

\test_stram:

 OR #$700,SR
 clr.B FLAG_CACHE+1
 CACHE_ON
 clr $100000
 MOVE #$101,$100002
\st1:MOVE $100000,D0
  MOVE $100002,D0
 BRA.S \st1
  
\test_dsp:

 pea string_dsp1(pc)
 bsr display_string
 addq.w #4,sp
 bsr init_dsp
 bpl \menu_dsp2
\dsp_err:
 pea error3(pc);time-out
 bsr display_string
 addq.w #4,sp
 bsr AFF_REG_DSP 
\wait_clav_dsp:
 bsr read_clav
 bmi.s \wait_clav_dsp
 bra.s \menu_dsp3
\menu_dsp2:
 bsr AFF_REG_DSP 
 pea string_dsp2(pc)
 bsr display_string
 addq.w #4,sp
 bsr charge_prog_dsp
 bmi \dsp_err;time-out 
 bsr AFF_REG_DSP 
 bra.s \menu_dsp3
 
\menu_dsp:
 MOVE #-1,CLAV
 clr.w cursor_x
 clr.w cursor_y
 bsr clear_screen
\menu_dsp3:
 pea string_menu_dsp(pc)
 bsr display_string
 addq.w #4,sp
\wait_dsp:
 bsr read_clav
 bmi.s \wait_dsp
 cmp #$E,D0
 beq \menu
 clr.w cursor_x
 clr.w cursor_y
 bsr clear_screen
 tst D0
 beq \3bytes_dsp
 cmp #1,D0
 beq \byte_dsp
 cmp #2,D0
 beq \word_dsp
 cmp #3,D0
 beq \long_dsp
 cmp #4,D0
 beq \inter_dsp
 cmp #5,D0
 beq \dsp_read_byte
 cmp #6,D0
 beq \dsp_write_byte
 cmp #$A,D0;CLR HOME
 bne \wait_dsp
 tst.b FLAG_CACHE
 BNE.S \c0_dsp
 CACHE_ON
 bsr tempo_2S
 bra \menu_dsp
\c0_dsp:CACHE_OFF
 bsr tempo_2S
 bra \menu_dsp
 
\dsp_read_byte:
 OR #$700,SR
 MOVE.B #$55,$FFFFA200
 MOVE.B #$AA,$FFFFA203
\dsp_read_byte1:
  MOVE.B $FFFFA200,D0
  MOVE.B $FFFFA203,D0
 BRA.S \dsp_read_byte1

\dsp_write_byte:
 OR #$700,SR
 MOVEQ #$55,D0
 MOVE #$AA,D1
\dsp_write_byte1:
  MOVE.B D0,$FFFFA200
  MOVE.B D1,$FFFFA203
 BRA.S \dsp_write_byte1 
 
\byte_dsp:
 MOVEQ.L #0,D0
 LEA $FFFFA202,A0;port host
 LEA 5(A0),A1
 LEA TIME_OUT,A6
 MOVEQ #0,D1
 moveq #$55,D2
 moveq #0,D3
 MOVE #$AA,D4
\dsp25:MOVE #TIME_OUT_DSP,(A6);time-out
  cmp #$E,CLAV
  beq \menu_dsp
\dsp23:TST (A6)
   BMI \dsp_err;time-out
  BTST #1,(A0)
  BEQ.S \dsp23
  MOVE.B D2,-2(A1)
  MOVE.B D4,-1(A1)
  MOVE.B D0,(A1)
\dsp24:TST (A6)
   BMI \dsp_err;time-out
  BTST #0,(A0)
  BEQ.S \dsp24
;  MOVE.B -3(A1),D1
;  ASL.L #8,D1
;  MOVE.B -2(A1),D1
;  ASL.L #8,D1
;  MOVE.B -1(A1),D1
;  ASL.L #8,D1
  MOVE.B (A1),D1
  CMP.B D0,D1
  BNE.S \dsp21
\dsp26:add #$11,D0
 addq.l #1,d3
 cmp #$100,D0
 bcs.s \dsp25
 moveq #0,d0
 BRA.S \dsp25
\dsp21:
 movem.l d0-d1/a0-a1,-(sp)
 move.l d0,d6
 move.l d1,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR HEX_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_LONG_D0 
 move #" ",-(sp)
 bsr display_char
 addq #2,sp
 MOVE.L d3,D0
 BSR AFF_HEX_LONG_D0 
 movem.l (sp)+,d0-d1/a0-a1
 bra \dsp26

\word_dsp:
 MOVE.L #$1100,D0
 LEA $FFFFA202,A0;port host
 LEA 4(A0),A1
 LEA TIME_OUT,A6
 MOVEQ #0,D1
 moveq #0,d3
\dsp15:MOVE #TIME_OUT_DSP,(A6);time-out
  cmp #$E,CLAV
  beq \menu_dsp
\dsp13:TST (A6)
   BMI \dsp_err;time-out
  BTST #1,(A0)
  BEQ.S \dsp13
   MOVE D0,(A1)
\dsp14:TST (A6)
   BMI \dsp_err;time-out
  BTST #0,(A0)
  BEQ.S \dsp14
  MOVE (A1),D1
  CMP D0,D1
  BNE.S \dsp11
\dsp16:add.l #$1111,D0
 addq.l #1,d3
 cmp.l #$10000,d0
 bcs.s \dsp15
 move.l #$1100,d0
 BRA.S \dsp15
\dsp11:
 movem.l d0-d1/a0-a1,-(sp)
 move.l d0,d6
 move.l d1,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR AFF_HEX_WORD_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_WORD_D0 
 move #" ",-(sp)
 bsr display_char
 addq #2,sp
 MOVE.L d3,D0
 BSR AFF_HEX_LONG_D0 
 movem.l (sp)+,d0-d1/a0-a1
 bra \dsp16 

\long_dsp:
 MOVE.L #$00221100,D0
 LEA $FFFFA202,A0;port host
 LEA 2(A0),A1
 LEA TIME_OUT,A6
 moveq #0,d5
\dsp5:MOVE #TIME_OUT_DSP,(A6);time-out
  cmp #$E,CLAV
  beq \menu_dsp
\dsp3:TST (A6)
   BMI \dsp_err;time-out
  BTST #1,(A0)
  BEQ.S \dsp3
   MOVE.L D0,(A1)
\dsp4:TST (A6)
   BMI \dsp_err;time-out
  BTST #0,(A0)
  BEQ.S \dsp4
  MOVE.L (A1),D1
  MOVE.L #$FFFFFF,D4
  MOVE.L D0,D2
  AND.L D4,D2
  MOVE.L D1,D3
  AND.L D4,D3
  CMP.L D2,D3
  BNE.S \dsp1
\dsp6:add.l #$111111,d0
 addq.l #1,d5
 cmp.l #$1000000,d0
 bcs.s \dsp5
 move.l #$221100,d0
 BRA.S \dsp5
\dsp1:
 movem.l d0-d1/a0-a1,-(sp)
 move.l d0,d6
 move.l d1,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR AFF_HEX_LONG_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_LONG_D0 
 move #" ",-(sp)
 bsr display_char
 addq #2,sp
 MOVE.L d5,D0
 BSR AFF_HEX_LONG_D0 
 movem.l (sp)+,d0-d1/a0-a1
 bra \dsp6
 
\3bytes_dsp:
 MOVE.L #$00221100,D0
 LEA $FFFFA202,A0;port host
 LEA 2(A0),A1
 LEA TIME_OUT,A6
 moveq #0,d5
\dsp35:MOVE #TIME_OUT_DSP,(A6);time-out
  cmp #$E,CLAV
  beq \menu_dsp
\dsp33:TST (A6)
   BMI \dsp_err;time-out
  BTST #1,(A0)
  BEQ.S \dsp33
  MOVE.L D0,-(SP)
  MOVE.B 1(SP),1(A1)
  MOVE.B 2(SP),2(A1)
  MOVE.B 3(SP),3(A1)
  ADDQ #4,SP
\dsp34:TST (A6)
   BMI \dsp_err;time-out
  BTST #0,(A0)
  BEQ.S \dsp34
  MOVEQ #0,D1
  MOVE.B 1(A1),D1
  ASL.L #8,D1
  MOVE.B 2(A1),D1
  ASL.L #8,D1
  MOVE.B 3(A1),D1
  MOVE.L #$FFFFFF,D4
  MOVE.L D0,D2
  AND.L D4,D2
  MOVE.L D1,D3
  AND.L D4,D3
  CMP.L D2,D3
  BNE.S \dsp31
\dsp36:add.l #$111111,d0
 addq.l #1,d5
 cmp.l #$1000000,d0
 bcs.s \dsp35
 move.l #$221100,d0
 BRA.S \dsp35
\dsp31:
 movem.l d0-d1/a0-a1,-(sp)
 move.l d0,d6
 move.l d1,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR AFF_HEX_LONG_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_LONG_D0 
 move #" ",-(sp)
 bsr display_char
 addq #2,sp
 MOVE.L d5,D0
 BSR AFF_HEX_LONG_D0 
 movem.l (sp)+,d0-d1/a0-a1
 bra \dsp36
 
\inter_dsp:
 pea string_dsp3(pc)
 bsr display_string
 addq.w #4,sp
 LEA IRQ_OUT_DSP(PC),A0
 MOVE.L A0,$3C0;vecteur
 MOVE.B #$F0,$FFFFA203
 MOVE.L #$221100,D0
 LEA $FFFFA202,A0;port host
 LEA 2(A0),A1
 LEA TIME_OUT,A6
\dsp05:MOVE #TIME_OUT_DSP,(A6);time-out
  cmp #$E,CLAV
  beq \menu_dsp
\dsp03:TST (A6)
   BMI \dsp_err;time-out
  BTST #1,(A0)
  BEQ.S \dsp03
  MOVE.L D0,(A1)
  CLR OK_IRQ_DSP
  OR.B #1,$FFFFA200;envoi du DSP
\dsp04:TST (A6)
   BMI \dsp_err_i;time-out
  TST OK_IRQ_DSP
  BEQ.S \dsp04
  MOVE.L BUFFER_DSP-1,D1
  MOVE.L #$FFFFFF,D4
  MOVE.L D0,D2
  AND.L D4,D2
  MOVE.L D1,D3
  AND.L D4,D3
  CMP.L D2,D3
  BNE.S \dsp01
\dsp06:add.l #$111111,d0
 cmp.l #$1000000,d0
 bcs \dsp05
 move.l #$221100,d0
 bra \dsp05  
\dsp01:
 movem.l d0-d1/a0-a1,-(sp)
 move.l d0,d6
 move.l d1,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR AFF_HEX_LONG_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_LONG_D0 
 movem.l (sp)+,d0-d1/a0-a1
 bra \dsp06
 
\dsp_err_i:
 pea error4(pc)
 bsr display_string
 addq.w #4,sp
 bsr AFF_REG_DSP 
\wait_clav_dsp_i:
 bsr read_clav
 bmi.s \wait_clav_dsp_i
 bra \menu_dsp
 
\test_berr:
 move sr,d4
 or #$700,sr
 move.l sp,a6
 move.l 8,a4
 pea string_berr_flashl(pc)
 bsr display_string
 addq.w #4,sp
 lea \be3(pc),a0
 move.l a0,8
 clr.l $E00000
 nop
 nop
 nop
 nop
 move.l a4,8
 move #"P",-(sp)
 bsr display_char
 addq #2,sp
 move #"B",-(sp)
 bsr display_char
 addq #2,sp
 bra.s \be4
\be3:move.l a4,8
 move.l a6,sp
 move #"O",-(sp)
 bsr display_char
 addq #2,sp
 move #"K",-(sp)
 bsr display_char
 addq #2,sp
\be4:pea string_berr_flashw(pc)
 bsr display_string
 addq.w #4,sp
 lea \be5(pc),a0
 move.l a0,8
 clr.w $E00000
 nop
 nop
 nop
 nop
 move.l a4,8
 move #"P",-(sp)
 bsr display_char
 addq #2,sp
 move #"B",-(sp)
 bsr display_char
 addq #2,sp
 bra.s \be6
\be5:move.l a4,8
 move.l a6,sp
 move #"O",-(sp)
 bsr display_char
 addq #2,sp
 move #"K",-(sp)
 bsr display_char
 addq #2,sp
\be6:pea string_berr0(pc)
 bsr display_string
 addq.w #4,sp
 lea \be1(pc),a0
 move.l a0,8
 clr.l 0
 nop
 nop
 nop
 nop
 move.l a4,8
 move #"P",-(sp)
 bsr display_char
 addq #2,sp
 move #"B",-(sp)
 bsr display_char
 addq #2,sp
 bra.s \be2
\be1:move.l a4,8
 move.l a6,sp
 move #"O",-(sp)
 bsr display_char
 addq #2,sp
 move #"K",-(sp)
 bsr display_char
 addq #2,sp
\be2:pea string_berr3fc(pc)
 bsr display_string
 addq.w #4,sp
 lea \be7(pc),a0
 move.l a0,8
 and #$DFFF,SR;user
\be8:clr.l $3FC
 nop
 nop
 nop
 nop
 move.l a4,8
 move #"P",-(sp)
 bsr display_char
 addq #2,sp
 move #"B",-(sp)
 bsr display_char
 addq #2,sp
 bra.s \be8
\be7:move.l a4,8
 move.l a6,sp
 move #"O",-(sp)
 bsr display_char
 addq #2,sp
 move #"K",-(sp)
 bsr display_char
 addq #2,sp
 move.l sp,a6
 move.l 8,a4
 pea string_berr_23040000(pc)
 bsr display_string
 addq.w #4,sp
 lea \be9(pc),a0
 move.l a0,8
 move.l $23040000,D0
 nop
 nop
 nop
 nop
 move.l a4,8
 move #"P",-(sp)
 bsr display_char
 addq #2,sp
 move #"B",-(sp)
 bsr display_char
 addq #2,sp
 bra.s \be10
\be9:move.l a4,8
 move.l a6,sp
 move #"O",-(sp)
 bsr display_char
 addq #2,sp
 move #"K",-(sp)
 bsr display_char
 addq #2,sp
\be10:move d4,sr
 bsr tempo_2S
 bra \menu

\mips:
 bsr config_sdram 
  tst FLAG_SDRAM
  bpl \mips1
  CACHE_OFF
  lea MES_DELAY_2(pc),a0
  lea MES_DELAY_SDRAM,a1
  moveq #((END_MES_DELAY_2-MES_DELAY_2)/2)-1,D0
\mv_mips:move.w (a0)+,(a1)+
  dbra d0,\mv_mips
  lea MES_DELAY_2(pc),a0
  lea MES_DELAY_SDRAM,a1
  moveq #((END_MES_DELAY_2-MES_DELAY_2)/4)-1,D1
\cp_mips:move.l (a0)+,d6
   move.l (a1)+,d0
   cmp.l d0,d6
   bne.s \erreur_prog 
 SUB.L #1,D1
 BGT.S \cp_mips
 bra \mips4
\erreur_prog:
 move.l d0,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 subq #4,A1
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR AFF_HEX_LONG_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_LONG_D0 
 pea string9(pc);at
 bsr display_string
 addq.w #4,sp  
 MOVE.L a1,D0
 BSR AFF_HEX_LONG_D0
  lea MES_DELAY_2(pc),a0
  lea MES_DELAY_SDRAM,a1
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+  
  move.l (a0)+,(a1)+  
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+  
  move.l (a0)+,(a1)+    
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+  
  move.l (a0)+,(a1)+  
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+  
  move.l (a0)+,(a1)+  
  lea MES_DELAY_2(pc),a0
  lea MES_DELAY_SDRAM,a1
  moveq #((END_MES_DELAY_2-MES_DELAY_2)/4)-1,D1
\cp_mips2:move.l (a0)+,d6
   move.l (a1)+,d0
   cmp.l d0,d6
   bne.s \erreur_prog2 
 SUB.L #1,D1
 BGT.S \cp_mips2
 bra.s \mips4
\erreur_prog2:
 move.l d0,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 subq #4,A1
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR AFF_HEX_LONG_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_LONG_D0 
 pea string9(pc);at
 bsr display_string
 addq.w #4,sp  
 MOVE.L a1,D0
 BSR AFF_HEX_LONG_D0
 bsr tempo_2s
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 bra.s \mips4
\mips1:
  CACHE_OFF
\mips4:
  move #13,-(sp)
  bsr display_char
  addq #2,sp
  cmp #$E,CLAV
  beq \menu
  clr.w flag;EEPROM
  pea string3ee(pc)
  bsr display_string
  addq.w #4,sp
  bsr aff_mips
  cmp #$E,CLAV
  beq \menu
  st.b flag;STRAM
  pea string3st(pc)
  bsr display_string
  addq.w #4,sp
  bsr aff_mips
  tst FLAG_SDRAM
  bpl.s \mips2
  st.b flag+1;SDRAM
  pea string3sd(pc)
  bsr display_string
  addq.w #4,sp
  bsr aff_mips
\mips2:
  move #13,-(sp)
  bsr display_char
  addq #2,sp
  CACHE_ON
  move #13,-(sp)
  bsr display_char
  addq #2,sp
  cmp #$E,CLAV
  beq \menu
  clr.w flag;EEPROM
  pea string3eec(pc)
  bsr display_string
  addq.w #4,sp
  bsr aff_mips
  cmp #$E,CLAV
  beq \menu
  st.b flag;STRAM
  pea string3stc(pc)
  bsr display_string
  addq.w #4,sp
  bsr aff_mips
  cmp #$E,CLAV
  beq \menu
  tst FLAG_SDRAM
  bpl.s \mips3
  st.b flag+1;SDRAM
  pea string3sdc(pc)
  bsr display_string
  addq.w #4,sp
  bsr aff_mips
\mips3:
  move #13,-(sp)
  bsr display_char
  addq #2,sp
 bra \mips1

\temperature:
  bsr read_clav
  cmp #$E,d0
  beq \menu
  clr.w cursor_x
  clr.w cursor_y
  bsr ct60_read_temp
  tst.l d0
  bmi \terror 
  link a6,#-4
  clr -2(a6)
  lea -4(a6),A0
  moveq #3,D1
  bsr conv_deci
  pea string2(pc)
  bsr display_string
  addq.w #4,sp
  pea -4(a6)
  bsr display_string
  addq.w #4,sp
  unlk a6 
 bra \temperature
\terror:
 bsr aff_error
 bra \temperature

\read_info_sdram:
  bsr read_clav
  cmp #$E,d0
  beq \menu
  lea buffer_info_eeprom_flash,a0
  bsr ct60_read_info_sdram
  tst FLAG_AFF
  bpl.s \ss_aff
  pea out
  bsr display_string
  addq.w #4,sp 
\ss_aff:  
  tst.l d0
  bpl \read_info_sdram
  bsr aff_error
  move #13,-(sp)
  bsr display_char
  addq #2,sp
  tst FLAG_AFF
  bpl \read_info_sdram
  move #13,-(sp)
  bsr display_char
  addq #2,sp
 bra \read_info_sdram
 
\config_sdram:
  bsr read_clav
  cmp #$E,d0
  beq \menu
  bsr ct60_configure_sdram
  tst FLAG_AFF
  bpl.s \s_aff
  pea out
  bsr display_string
  addq.w #4,sp
\s_aff:
  tst.l d0
  bmi \error_ram
  move.l D0,D4
  add.l #26,D4; size 0-3 for 64MB-512MB
  moveq #0,D5
  bset D4,D5
  st.b FLAG_SDRAM
  link a6,#-4
  clr -2(a6)
  lea -4(a6),A0
  moveq #2,D1
  bsr conv_deci
  pea string1(pc)
  bsr display_string
  addq.w #4,sp
  pea -4(a6)
  bsr display_string
  addq.w #4,sp
  unlk a6
  move #$20,-(sp)
  bsr display_char
  addq #2,sp
  move #$20,-(sp)
  bsr display_char
  addq #2,sp
  lea $01000000,A4
  add.l D5,A4
  move.l D5,D7
  lsr.l #8,D7
  moveq #0,D0
  moveq #0,D1
  moveq #0,D2
  moveq #0,D3
  move.l D0,A0
  move.l D1,A1
  move.l D2,A2
  move.l D3,A3
  subq.l #1,D7
  move.w D7,D6
  swap D7
\init_sdram:
    movem.l D0-D3/A0-A3,-(A4)
    movem.l D0-D3/A0-A3,-(A4)
    movem.l D0-D3/A0-A3,-(A4)
    movem.l D0-D3/A0-A3,-(A4)
    movem.l D0-D3/A0-A3,-(A4)
    movem.l D0-D3/A0-A3,-(A4)
    movem.l D0-D3/A0-A3,-(A4)
    movem.l D0-D3/A0-A3,-(A4)
   dbra D6,\init_sdram
   move #$2E,-(SP)
   bsr display_char
   ADDQ #2,SP
  dbra D7,\init_sdram
 bra \menu
\error_ram:
 bsr aff_error
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 tst FLAG_AFF
 bpl \config_sdram
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 bra \config_sdram

\sdram_write:
 bsr config_sdram 
 moveq #0,d7
\sdram_write2:
  cmp #$E,CLAV
  beq \menu 
  lea $100000,A0;STRAM
  lea $1000000,A1;SDRAM
  add.l d7,a1
;  moveq #15,D0
;\cp2:
   IFEQ 1,FLASH
    dc.l $f6209000;move16 (a0)+,(a1)+  
   ELSE
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
   ENDIF
   addq.l #8,D7
   addq.l #8,d7
   and.l #1023,d7
;  dbra d0,\cp2
  st.b FLAG_SDRAM
 bra \sdram_write2

\sdram_read:
 bsr config_sdram
 moveq #0,d7 
\sdram_read2:
  cmp #$E,CLAV
  beq \menu 
  lea $1000000,A0;SDRAM
  lea $100000,A1;STRAM
  add.l d7,a1
;  moveq #15,D0
;\cp3:
   IFEQ 1,FLASH
    dc.l $f6209000;move16 (a0)+,(a1)+  
   ELSE
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
   ENDIF
   addq.l #8,D7
   addq.l #8,d7
   and.l #1023,d7
;  dbra d0,\cp3
  st.b FLAG_SDRAM
 bra \sdram_read2

\sdram_write_page:
 bsr config_sdram
\sdram_write02:
  cmp #$E,CLAV
  beq \menu 
  lea $100000,A0;STRAM
  lea $1000000,A1;SDRAM
  IFEQ 1,FLASH
   dc.l $f6209000;move16 (a0)+,(a1)+  
  ELSE
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
  ENDIF
  lea $100000,A0;STRAM
  lea $1800000,A1;SDRAM
  IFEQ 1,FLASH
   dc.l $f6209000;move16 (a0)+,(a1)+  
  ELSE
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
  ENDIF
  st.b FLAG_SDRAM
 bra \sdram_write02

\sdram_read_page:
 bsr config_sdram 
\sdram_read02:
  cmp #$E,CLAV
  beq \menu 
  lea $1000000,A0;SDRAM
  lea $100000,A1;STRAM
  IFEQ 1,FLASH
   dc.l $f6209000;move16 (a0)+,(a1)+  
  ELSE
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
  ENDIF
  lea $1800000,A0;SDRAM
  lea $100000,A1;STRAM
  IFEQ 1,FLASH
   dc.l $f6209000;move16 (a0)+,(a1)+  
  ELSE
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
   move.l (a0)+,(a1)+
  ENDIF
  st.b FLAG_SDRAM
 bra \sdram_read02

\sdram_verify:      ;F10
 bsr config_sdram
 move.l #$01234567,D1
 move.l #$89ABCDEF,D2
 move.l #$55555555,D3
 move.l #$AAAAAAAA,D4
 move.l #$F0F0F0F0,D5
 moveq #0,d7
\sdram_verify3:
  bsr read_clav
  cmp #$E,d0
  beq \menu 
  lea $100000,A0;STRAM
  lea $1000000,A1;SDRAM
  add.l d7,a1
  movem.l D1-D4,(A0)
  tst flag_move16
  bpl.s \sdram6_move16
  movem.l D2-D5,16(A0)
  dc.l $f6209000;move16 (a0)+,(a1)+  
  dc.l $f6209000;move16 (a0)+,(a1)+  
  bra.s \sdram5_move16
\sdram6_move16:
  bne.s \sdram6_movew
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  bra.s \sdram5_move16
\sdram6_movew: 
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+  
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+  
\sdram5_move16:
  lea 0,a2
  lea $1000000,A1;SDRAM
  add.l d7,a1
  move.l (A1)+,D0
  move.l D1,D6
  cmp.l D0,D6
  bne \erreur_verify5
\next_100:
  lea 1,a2
  move.l (A1)+,D0
  move.l D2,D6
  cmp.l D0,D6
  bne \erreur_verify5
\next_101:
  lea 2,a2
  move.l (A1)+,D0
  move.l D3,D6
  cmp.l D0,D6
  bne \erreur_verify5
\next_102:
  lea 3,a2
  move.l (A1)+,D0
  move.l D4,D6
  cmp.l D0,D6
  bne \erreur_verify5
  tst flag_move16
  bpl.s \next_107
\next_103:
  lea 4,a2
  move.l (A1)+,D0
  move.l D2,D6
  cmp.l D0,D6
  bne \erreur_verify5
\next_104:
  lea 5,a2
  move.l (A1)+,D0
  move.l D3,D6
  cmp.l D0,D6
  bne \erreur_verify5
\next_105:
  lea 6,a2
  move.l (A1)+,D0
  move.l D4,D6
  cmp.l D0,D6
  bne \erreur_verify5
\next_106:
  lea 7,a2
  move.l (A1)+,D0
  move.l D5,D6
  cmp.l D0,D6
  bne \erreur_verify5
\next_107:
  move.l D5,D6
  move.l D4,D5
  move.l D3,D4
  move.l D2,D3
  move.l D1,D2
  move.l D6,D1
  addq.l #8,D7
  addq.l #8,d7
  and.l #65535,d7
  st.b FLAG_SDRAM
 bra \sdram_verify3

\erreur_verify5:
 movem.l d7/A0/A1,-(sp)
 move.l d0,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 subq #4,A1
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR AFF_HEX_LONG_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_LONG_D0 
 pea string9(pc);at
 bsr display_string
 addq.w #4,sp  
 MOVE.L a1,D0
 BSR AFF_HEX_LONG_D0
 movem.l (sp)+,d7/A0/A1
 move a2,d0
 tst d0
 beq \next_100
 subq #1,d0
 beq \next_101
 subq #1,d0
 beq \next_102
 subq #1,d0
 beq \next_103
 subq #1,d0
 beq \next_104
 subq #1,d0
 beq \next_105
 subq #1,d0
 beq \next_106
 bra \next_107

\sdram_verify_page:     ;F5
 bsr config_sdram
 move.l #$01234567,D1
 move.l #$89ABCDEF,D2
 move.l #$55555555,D3
 move.l #$AAAAAAAA,D4
 move.l #$F0F0F0F0,D5
\sdram_verify2:
  bsr read_clav
  cmp #$E,d0
  beq \menu 
  lea $100000,A0;STRAM
  lea $1000000,A1;SDRAM
  movem.l D1-D4,(A0)
  tst flag_move16
  bpl.s \sdram2_move16
  movem.l D2-D5,16(A0)
  dc.l $f6209000;move16 (a0)+,(a1)+  
  dc.l $f6209000;move16 (a0)+,(a1)+  
  bra.s \sdram1_move16
\sdram2_move16:
  bne.s \sdram2_movew
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  bra.s \sdram1_move16
\sdram2_movew:
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+  
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+  
\sdram1_move16:
  lea $1000000,A1;SDRAM
  moveq #0,D7
  move.l (A1)+,D0
  move.l D1,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_0:
  moveq #1,d7
  move.l (A1)+,D0
  move.l D2,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_1:
  moveq #2,d7
  move.l (A1)+,D0
  move.l D3,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_2:
  moveq #3,d7
  move.l (A1)+,D0
  move.l D4,D6
  cmp.l D0,D6
  bne \erreur_verify
  tst flag_move16
  bpl.s \next_7
\next_3:
  moveq #4,d7
  move.l (A1)+,D0
  move.l D2,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_4:
  moveq #5,d7
  move.l (A1)+,D0
  move.l D3,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_5:
  moveq #6,d7
  move.l (A1)+,D0
  move.l D4,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_6:
  moveq #7,d7
  move.l (A1)+,D0
  move.l D5,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_7:
  moveq #8,D7
  move.l D5,D6
  move.l D4,D5
  move.l D3,D4
  move.l D2,D3
  move.l D1,D2
  move.l D6,D1
  lea $100000,A0;STRAM
  lea $1800000,A1;SDRAM
  movem.l D1-D4,(A0)
  tst flag_move16
  bpl.s \sdram4_move16
  movem.l D2-D5,16(A0)
  dc.l $f6209000;move16 (a0)+,(a1)+  
  dc.l $f6209000;move16 (a0)+,(a1)+  
  bra.s \sdram3_move16
\sdram4_move16:
  bne.s \sdram4_movew
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  move.l (a0)+,(a1)+
  bra.s \sdram3_move16
\sdram4_movew:
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+  
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+
  move.w (a0)+,(a1)+  
\sdram3_move16:
  lea $1800000,A1;SDRAM
  move.l (A1)+,D0
  move.l D1,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_8:
  moveq #9,D7
  move.l (A1)+,D0
  move.l D2,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_9:
  moveq #10,D7
  move.l (A1)+,D0
  move.l D3,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_10:
  moveq #11,d7
  move.l (A1)+,D0
  move.l D4,D6
  cmp.l D0,D6
  bne \erreur_verify
  tst flag_move16
  bpl.s \next_15  
\next_11:
  moveq #12,D7
  move.l (A1)+,D0
  move.l D2,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_12:
  moveq #13,D7
  move.l (A1)+,D0
  move.l D3,D6
  cmp.l D0,D6
  bne \erreur_verify
\next_13:
  moveq #14,d7
  move.l (A1)+,D0
  move.l D4,D6
  cmp.l D0,D6
  bne \erreur_verify  
\next_14:
  moveq #15,d7
  move.l (A1)+,D0
  move.l D5,D6
  cmp.l D0,D6
  bne \erreur_verify  
\next_15:
  move.l D5,D6
  move.l D4,D5
  move.l D3,D4
  move.l D2,D3
  move.l D1,D2
  move.l D6,D1
  st.b FLAG_SDRAM
 bra \sdram_verify2

\erreur_verify:
 movem.l d7/a0/a1,-(sp)
 move.l d0,d7
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 subq #4,A1
 pea string7(pc);write
 bsr display_string
 addq.w #4,sp  
 MOVE.L d6,D0
 BSR AFF_HEX_LONG_D0 
 pea string8(pc);read
 bsr display_string
 addq.w #4,sp  
 MOVE.L d7,D0
 BSR AFF_HEX_LONG_D0 
 pea string9(pc);at
 bsr display_string
 addq.w #4,sp  
 MOVE.L a1,D0
 BSR AFF_HEX_LONG_D0
 movem.l (sp)+,d7/a0/a1
 tst d7
 beq \next_0
 subq #1,d7
 beq \next_1
 subq #1,d7
 beq \next_2
 subq #1,d7
 beq \next_3
 subq #1,d7
 beq \next_4
 subq #1,d7
 beq \next_5
 subq #1,d7
 beq \next_6
 subq #1,d7
 beq \next_7
 subq #1,d7
 beq \next_8
 subq #1,d7
 beq \next_9
 subq #1,d7
 beq \next_10
 subq #1,d7
 beq \next_11
 subq #1,d7
 beq \next_12
 subq #1,d7
 beq \next_13
 subq #1,d7
 beq \next_14
 bra \next_15

\sdram_write_long: ;F8
 bsr config_sdram
 moveq #0,d7
\sdram_write12:
  cmp #$E,CLAV
  beq \menu 
  lea $1000000,A1;SDRAM
  add.l d7,a1
;  moveq #15,D0
  move.l #$55555555,D1
;\cp12:
   move.l d1,(a1)+
   not.l d1
   move.l d1,(a1)+
   not.l d1
   move.l d1,(a1)+
   not.l d1
   move.l d1,(a1)+
   not.l d1
   addq.l #8,D7
   addq.l #8,d7
   and.l #65535,d7
;  dbra d0,\cp12
  st.b FLAG_SDRAM
 bra \sdram_write12

\sdram_read_long:
 bsr config_sdram 
 moveq #0,d7
\sdram_read12:
  cmp #$E,CLAV
  beq \menu 
  lea $1000000,A0;SDRAM
  add.l d7,a0
;  moveq #15,D0
;\cp13:
   move.l (a0)+,d0
   move.l (a0)+,d0
   move.l (a0)+,d0
   move.l (a0)+,d0
   addq.l #8,D7
   addq.l #8,d7
   and.l #65535,d7
;  dbra d0,\cp13
  st.b FLAG_SDRAM
 bra \sdram_read12

\sdram_write_page_long:  ;F3
 bsr config_sdram
 lea $1000000,A0;SDRAM
 move.l #$55555555,D0
\sdram_write3:
  cmp #$E,CLAV
  beq \menu 
  move.l d0,(a0)
  not.l d0
  add.l #$800000,A0
  move.l d0,(a0)
  not.l d0
  sub.l #$800000,A0
  st.b FLAG_SDRAM
 bra \sdram_write3

\sdram_read_page_long:
 bsr config_sdram
 lea $1000000,A0;SDRAM
\sdram_read3:
  cmp #$E,CLAV
  beq \menu 
  move.l (a0),D0
  add.l #$800000,A0
  move.l (a0),D0
  sub.l #$800000,A0
  st.b FLAG_SDRAM
 bra \sdram_read3
 
\sdram_write_word: ;Y
 or #$700,SR
 clr.B FLAG_CACHE+1
 CACHE_ON
 bsr config_sdram
 moveq #0,d7
\sdram_write12w:
;  cmp #$E,CLAV
;  beq \menu 
  lea $1000000,A1;SDRAM
  add.l d7,a1
;  moveq #15,D0
  move.w #$5555,D1
;\cp12w:
   move.w d1,(a1)+
   not.w d1
   move.w d1,(a1)+
   not.w d1
   move.w d1,(a1)+
   not.w d1
   move.w d1,(a1)+
   not.w d1
   addq.l #8,D7
   addq.l #8,d7
   and.l #65535,d7
;  dbra d0,\cp12w
  st.b FLAG_SDRAM
 bra \sdram_write12w

\sdram_write_page_word:  ;T
 or #$700,SR
 clr.B FLAG_CACHE+1
 CACHE_ON
 bsr config_sdram
 lea $1000000,A0;SDRAM
 move.w #$5555,D0
\sdram_write3w:
;  cmp #$E,CLAV
;  beq \menu 
  move.w d0,(a0)
  not.w d0
  add.l #$800000,A0
  move.w d0,(a0)
  not.w d0
  sub.l #$800000,A0
  st.b FLAG_SDRAM
 bra \sdram_write3w

\blitter:
\blitter2:
 bsr aff_logo
 LEA $FFFF8A20,A0;BLITTER
 MOVE screen_width,D2
 MOVE #36,D3;largeur image monochrome en octets
 MOVE #72,D4;nbre de lignes image monochrome
 MOVE D4,D6
 MULU D2,D6;* screen_width
 SUB D3,D2;incr‚ment vertical source/cible
 ADDQ #2,D2
 LSR #1,D3
 MOVEQ #-1,D1
 MOVE.L screen_adr,A1;source
 add.w offset,A1
 LEA (A1,D6.L),A2;cible
 MOVEQ #4,D5
 MOVE #$203,D7 
\blitter_loop:
  bsr read_clav
  cmp #$E,d0
  beq \menu 
  MOVE.L #$5555AAAA,-32(A0)
  MOVE.L #$5555AAAA,-28(A0)
  MOVE.L #$5555AAAA,-24(A0)
  MOVE.L #$5555AAAA,-20(A0)
  MOVE.L #$5555AAAA,-16(A0)
  MOVE.L #$5555AAAA,-12(A0)
  MOVE.L #$5555AAAA,-8(A0)
  MOVE.L #$5555AAAA,-4(A0)  
  MOVE #2,(A0);incr‚ment horizontal source en octets
  MOVE D2,2(A0);incr‚ment vertical source
  MOVE.L A1,4(A0);adresse source
  MOVE D1,8(A0);masque d‚but ligne
  MOVE D1,10(A0);masque interm‚diaire
  MOVE D1,12(A0);masque fin ligne
  MOVE #2,14(A0);incr‚ment horizontal cible en octets
  MOVE D2,16(A0);incr‚ment vertical cible
  MOVE.L A2,18(A0);adresse cible
  MOVE D3,22(A0);mots/ligne … transf‚rer
  MOVE D4,24(A0);nbre lignes
  MOVE D7,26(A0);transfert source => cible
  tst flag
  bne.s \full_blitter
  MOVE #$8000,28(A0);lance blitter
  bra.s \wait_blitter
\full_blitter:
   MOVE #$C000,28(A0);lance blitter
\wait_blitter:
    tas.b 28(a0);attente fin de transfert
    NOP
   bmi.s \wait_blitter
   ADD.L D6,A2;cible
  DBRA D5,\blitter_loop
  addq #2,offset
  addq.b #1,D7
  and.b #15,D7
  cmp #10,offset
  bcs \blitter2
  clr.w offset
 bra \blitter2

 RTS

config_sdram: 
 
 bsr ct60_configure_sdram
 tst.l d0
 bpl \ok_sdram
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 bsr aff_error
 pea error1(pc)
 bsr display_string
 addq.w #4,sp
 pea string13(pc)
 bsr display_string
 addq.w #4,sp
  lea $f2000000,A0
 clr.l (A0)         ;write config
\ok_sdram:
 rts

aff_mips:

 bsr bogomips
 MOVE.L D0,D2
 MOVE.L #500000,D1
 DC.L $4C410000;DIVU.L D1,D0;loops_per_sec/500000
 link a6,#-4
 clr -2(a6)
 lea -4(a6),A0
 moveq #3,D1
 bsr conv_deci
 pea -4(a6)
 bsr display_string
 addq.w #4,sp
 unlk a6
 move #".",-(sp)
 bsr display_char
 addq #2,sp
 MOVE.L D2,D0
 MOVE.L #5000,D1
 DC.L $4C410000;DIVU.L D1,D0;loops_per_sec/5000
 DIVU #100,D0
 CLR D0
 SWAP D0;reste
 link a6,#-4
 clr -2(a6)
 lea -4(a6),A0
 moveq #2,D1
 bsr conv_deci_simple
 pea -4(a6)
 bsr display_string
 addq.w #4,sp
 unlk a6 
 rts
 
aff_error:

 neg.l d0
 link a6,#-4
 clr -2(a6)
 lea -4(a6),A0
 moveq #2,D1
 bsr conv_deci
 pea error1(pc)
 bsr display_string
 addq.w #4,sp
 pea -4(a6)
 bsr display_string
 addq.w #4,sp
 unlk a6
 rts

menu:
 dc.b 13,13,"CT60 Tests:",13
; dc.b 13,"<0> See last crash"
 dc.b 13,"<0> SCC"
 dc.b 13,"<1> Read temperature"
 dc.b 13,"<2> Config SDRAM, read EEPROM, init SDRAM"
 dc.b 13,"<3> Read 128 bytes EEPROM (SDRAM)"
 dc.b 13,"<4> Tests DSP"
 dc.b 13,"<5> Tests BERR"
 dc.b 13,"<6> Mips FLASH/STRAM/[SDRAM] cache ON/OFF"
 dc.b 13,"<7> Blitter, Share bus (half speed)"
 dc.b 13,"<8> Blitter, Hog bus   (full speed)"
 dc.b 13,"<9> Read STRAM"
 dc.b 13,"<F1> SDRAM, test page, write (move16)"
 dc.b 13,"<F2> SDRAM, test page, read  (move16)"
 dc.b 13,"<F3> SDRAM, test page, write (move.l)"
 dc.b 13,"<F4> SDRAM, test page, read (move.l)"
 dc.b 13,"<F5> read/write SDRAM,test page,verify (4 move.l) <A> (2 move16) <E> (8 move.w)"
 dc.b 13,"<F6> SDRAM write (move16)"
 dc.b 13,"<F7> SDRAM read  (move16)"
 dc.b 13,"<F8> SDRAM write (move.l)"
 dc.b 13,"<F9> SDRAM read  (move.l)"
 dc.b 13,"<F10> read/write SDRAM, verify (4 move.l)         <Z> (2 move16) <R> (8 move.w)"
 dc.b 13,"<T> SDRAM, test page, write (move.w)"
 dc.b 13,"<Y> SDRAM write (move.w)" 
 dc.b 13,"<U> Flash programming test (move)"
 dc.b 13,"<I> Flash programming test (moves)"
 dc.b 13,"<O> DMA Sound"
 dc.b 13,"<P> Memory dump"
; dc.b 13,"<F10> Configure EEPROM SDRAM: value -> [adress]"
; dc.b 13,"     4->[2], $C->[3], 8->[4],  1->[5], $40->[6]"
; dc.b 13,"     0->[7],  1->[8], 4->[17], 8->[31]   !!!!!!"
 dc.b 13
 dc.b 13,"<INSERT> PMMU ON/OFF"
 dc.b 13,"<CLR HOME> Cache ON/OFF"
 dc.b 13,"<BACKSPACE> Display ON/OFF"
 dc.b 13,"<> Interrupt priority mask level 3/5"
 dc.b 13,"<> Cache data ON/OFF"
 dc.b 13
 dc.b 13,"<ENTER/ESC> Abort test, goto this menu",13,13,0

string_pcr:
 dc.b 13,13,13,13,13,13,13,13,13,13,"Type of 68060 (PCR: $",0
proc_full:
 dc.b ") : Full :-)",0
proc_ec_lc:
 dc.b ") : EC or LC :-(",0
proc_inconnu:
 dc.b ") : Unknow",0

string_menu_dsp:
 dc.b 13,13,"DSP Tests:",13
 dc.b 13,"<0> 3 Bytes acces, verify"
 dc.b 13,"<1> Byte acces, verify"
 dc.b 13,"<2> Word acces, verify"
 dc.b 13,"<3> Long acces, verify"
 dc.b 13,"<4> Inter DSP, verify"
 dc.b 13,"<5> Read bytes"
 dc.b 13,"<6> Write bytes"
 dc.b 13
 dc.b 13,"<CLR HOME> Cache ON/OFF" 
 dc.b 13
 dc.b 13,"<ENTER/ESC> Abort test, goto this/main menu",13,13,0

string_dsp1:dc.b 13,"Init DSP",0
string_dsp2:dc.b 13,"Load test DSP",0
string_dsp3:dc.b 13,"Vector $F0 ($3C0) used",0

string_dsp10:dc.b 13,"ICR:$",0
string_dsp11:dc.b " CVR:$",0
string_dsp12:dc.b " ISR:$",0
string_dsp13:dc.b " IVR:$",0
string_dsp14:dc.b " 0:$",0
string_dsp15:dc.b " TXH/RXH:$",0
string_dsp16:dc.b " THM/RXM:$",0
string_dsp17:dc.b " TXL/RXL:$",0

string_scc1:DC.B 13,"SCC ",0
string_scc2:DC.B " Speed:",0
string_scc3:dc.b 13,"Vector $",0
string_scc4:dc.B " used",0
 
string_berr0:dc.b 13,"write to $0 (long) : ",0
string_berr3fc:dc.b 13,"Write to $3FC in user mode (long) : ",0
string_berr_flashl:dc.b 13,"Write to $E00000 (long) : ",0
string_berr_flashw:dc.b 13,"Write to $E00000 (word) : ",0
string_berr_23040000:dc.b 13,"Read to $23040000 (long) : ",0
 
string1:dc.b " Size on SDCNF A19-18: ",0
string2:dc.b " Temp: ",0
string3ee:dc.b " Mips FLASH:",0; (3.2):",0
string3st:dc.b " Mips STRAM:",0; (1.6):",0
string3sd:dc.b " Mips SDRAM:",0; (32):",0
string3eec:dc.b " Mips FLASH:",0; (117):",0
string3stc:dc.b " Mips STRAM:",0; (117):",0
string3sdc:dc.b " Mips SDRAM:",0; (117):",0
string4:dc.b  " Cache OFF               ",0
string4b:dc.b " Cache ON (excepted data)",0
string4c:dc.b " Cache ON (all caches)   ",0
string4a:dc.b " Change cache...",0
string5:dc.b " Display OFF",0
string5b:dc.b " Display ON",0
string6:dc.b " Set IPL 3",0
string6b:dc.b " Set IPL 5",0
string7:dc.b " Write : $",0
string8:dc.b " Read : $",0
string9:dc.b " at $",0
string10:dc.b 13,"Start tests in STRAM",0
string11:dc.b 13,"Tests started in STRAM",0
string12:dc.b 13,"Bootstrap load",0
string13:dc.b 13,"Use default config 64MB",0
string14:dc.b  " PMMU OFF (default write through)                  ",0
string14p:dc.b " PMMU ON (no cache precise for $80000000-$FFFFFFFF)",0
string15:dc.b 13," Register : $",0
string16:dc.b 13,"MEMORY DUMP, Adress : $",0
string17:dc.b 13,"Press <R> key to start test in STRAM...",0 

error1:dc.b " Error: -",0
error2:dc.b " Stack not valid !",0
error3:dc.b " Time-out DSP !",0
error4:dc.b " Time-out IRQ DSP !",0
error5:dc.b 13,"Write error",0
 
error10:dc.b 13,"Flash device error : $",0; -15
error11:dc.b 13,"Flash erase error",0; -11
error12:dc.b 13,"Flash program error",0; -10
 
 ALIGN.W

CONV_DECI:;A0:pointeur cible chaŒne ASCII, D0:valeur sur 32 bits, D1:nombre de chiffres

 BSR CONV_DECI_SIMPLE
 SUBQ #1,D1
 BEQ.S \1
 SWAP D0
 TST D0
 BNE.S \3;d‚passement
 MOVEQ #0,D0
\2:CMP.B #"0",(A0,D0)
  BNE.S \1
  MOVE.B #" ",(A0,D0);enl‚ve les z‚ros inutiles
  ADDQ #1,D0
 CMP D1,D0
 BNE.S \2
 BRA.S \1
\3:MOVE.B #"?",(A0,D1)
 DBRA D1,\3
\1:RTS

CONV_DECI_SIMPLE:;A0:pointeur cible chaŒne ASCII, D0:valeur sur 32 bits, D1:nombre de chiffres

 MOVE D1,-(SP)
 SUBQ #1,D1
 MOVE.L D0,-(SP)
\1:MOVEQ #0,D0
  MOVE (SP),D0
  DIVU #10,D0;poids fort /10
  MOVE D0,(SP);r‚sultat poids fort
  MOVE 2(SP),D0
  DIVU #10,D0;((reste * 65536) + poids faible)/10
  MOVE D0,2(SP);r‚sultat poids faible
  SWAP D0
  OR #$30,D0
  MOVE.B D0,(A0,D1)
 DBRA D1,\1
 ADDQ.L #4,SP
 MOVE (SP)+,D1
 RTS

display_string: 
    
 movem.l d0/a0,-(sp)
 movea.l 12(sp),a0
 clr.l d0
\loop move.b (a0)+,d0
 beq.s \end
 move.w d0,-(sp)
 bsr.s display_char
 addq.l #2,sp
 bra.s \loop
\end:
 movem.l (sp)+,d0/a0
 rts

display_char:

 movem.l d0-d1/a0-a1,-(sp)
 move.l screen_adr,a0
 move.w cursor_x,d0
 add.w d0,a0
 clr.l d0
 move.w cursor_y,d0
 lsl.l #3,d0
 mulu screen_width,d0
 add.l d0,a0
 lea font(pc),a1
 clr.l d0
 move.w 20(sp),d0
 cmp.b #13,d0
 beq.s \crlf
 lsl.l #3,d0
 add.l d0,a1
 move.w #8-1,d0
 move.w screen_width,d1
\display_char_loop:
  move.b (a1)+,(a0)
  add.w d1,a0
 dbra d0,\display_char_loop
 move.w cursor_x,d0
 addq.w #1,d0
 move.w d0,cursor_x
 cmp.w d1,d0
 bcs.s \ok
\crlf:
 clr.w cursor_x
 addq.w #1,cursor_y
 move.w cursor_y,d0
 cmp.w screen_height,d0
 bcs.s \ok
 move.w screen_height,D0
 subq.w #1,D0
 move.w d0,cursor_y
 bsr scroll
\ok:cmp #$B,CLAV
 bne.s \ok2
 move #-1,CLAV
\wait:
  bsr read_clav
  cmp #$E,d0
  beq.s \ok2;ENTER
 cmp #$B,d0
 bne.s \wait;SPACE 
\ok2:movem.l (sp)+,d0-d1/a0-a1
 rts

clear_screen:

 movem.l d0/a0,-(sp)
 move.l screen_adr,a0
 move.w screen_width,d0
 mulu screen_height,d0
 subq.l #1,D0
\clear_screen_loop:
  clr.l (a0)+
  clr.l (a0)+
 dbra d0,\clear_screen_loop
 movem.l (sp)+,d0/a0
 rts
 
aff_logo:

 movem.l d0/d1/a0/a1,-(sp)
 move.l screen_adr,a0
 lea logo(pc),a1
 add.w offset,a0
 move.w screen_width,d1
 sub.w #36,d1
 moveq #72-1,d0
\aff_logo_loop:
  move.l (a1)+,(a0)+ 
  move.l (a1)+,(a0)+ 
  move.l (a1)+,(a0)+ 
  move.l (a1)+,(a0)+ 
  move.l (a1)+,(a0)+ 
  move.l (a1)+,(a0)+ 
  move.l (a1)+,(a0)+ 
  move.l (a1)+,(a0)+
  move.l (a1)+,(a0)+
  add d1,a0 
 dbra d0,\aff_logo_loop
 movem.l (sp)+,d0/d1/a0/a1
 rts
 
scroll:

 movem.l d0/a0/a1,-(sp)
 move.l screen_adr,a0;cible
 moveq #0,d0
 move.w screen_width,d0
 asl.l #3,d0;*8
 lea (a0,d0.l),a1;source
 move.w screen_height,d0
 subq.w #1,d0
 mulu screen_width,d0
 subq.l #1,D0 
\scroll1: 
  move.l (a1)+,(a0)+
  move.l (a1)+,(a0)+
 dbra d0,\scroll1
 move.w screen_width,d0
 subq.w #1,D0
\clear_line_loop:
  clr.l (a0)+
  clr.l (a0)+
 dbra d0,\clear_line_loop
 movem.l (sp)+,d0/a0/a1
 rts

INIT_EXC:

 MOVEM.L D0/A0/A1,-(SP)
 LEA 8,A0;Bus Error
 LEA ERREUR_BUS(PC),A1
 MOVE.L A1,(A0)+
 LEA ERREUR_ADRESSE(PC),A1
 MOVE.L A1,(A0)+
 LEA INSTRUCTION_ILLEGALE(PC),A1
 MOVE.L A1,(A0)+
 LEA ZERO_DIVIDE(PC),A1
 MOVE.L A1,(A0)+
 LEA SAUT_INTER(PC),A1
 MOVE.L A1,(A0)+
 MOVE.L A1,(A0)+
 LEA VIOLATION_PRIVILEGE(PC),A1
 MOVE.L A1,(A0)+
 LEA TRACE(PC),A1
 MOVE.L A1,(A0)+
 LEA LINEA(PC),A1
 MOVE.L A1,(A0)+
 LEA LINEF(PC),A1
 MOVE.L A1,(A0)+
 LEA EMULATOR_INT(PC),A1
 MOVE.L A1,(A0)+
 LEA SAUT_INTER(PC),A1
 MOVE.L A1,(A0)+
 LEA ERREUR_FORMAT(PC),A1
 MOVE.L A1,(A0)+
 LEA UNINIT_INT(PC),A1
 MOVE.L A1,(A0)+
 LEA SAUT_INTER(PC),A1
 MOVE.L A1,(A0)+
 MOVE.L A1,(A0)+
 MOVE.L A1,(A0)+
 MOVE.L A1,(A0)+ 
 MOVE.L A1,(A0)+
 MOVE.L A1,(A0)+
 MOVE.L A1,(A0)+
 MOVE.L A1,(A0)+  
 LEA SPURIOUS_INT(PC),A1
 MOVE.L A1,(A0)+ 
 LEA INT1(PC),A1
 MOVE.L A1,(A0)+ 
 LEA INT2(PC),A1
 MOVE.L A1,(A0)+ 
 LEA INT3(PC),A1
 MOVE.L A1,(A0)+ 
 LEA INT4(PC),A1
 MOVE.L A1,(A0)+ 
 LEA INT5(PC),A1
 MOVE.L A1,(A0)+ 
 LEA INT6(PC),A1
 MOVE.L A1,(A0)+ 
 LEA INT7(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP0(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP1(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP2(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP3(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP4(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP5(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP6(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP7(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP8(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP9(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP10(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP11(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP12(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP13(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP14(PC),A1
 MOVE.L A1,(A0)+ 
 LEA TRAP15(PC),A1
 MOVE.L A1,(A0)+  
 MOVE #255-48,D0
 LEA SAUT_INTER(PC),A1
\1:MOVE.L A1,(A0)+
 DBRA D0,\1
 MOVEM.L (SP)+,D0/A0/A1
 RTS

ERREUR_BUS:

 MOVE #2,VECT_EXC
 BRA PROC_EXC

ERREUR_ADRESSE:

 MOVE #3,VECT_EXC
 BRA PROC_EXC

INSTRUCTION_ILLEGALE:

 MOVE #4,VECT_EXC
 BRA PROC_EXC
 
ZERO_DIVIDE:

 MOVE #5,VECT_EXC
 BRA PROC_EXC
 
VIOLATION_PRIVILEGE:

 MOVE #8,VECT_EXC
 BRA PROC_EXC

TRACE:

 MOVE #9,VECT_EXC
 BRA PROC_EXC 

LINEA:

 MOVE #10,VECT_EXC
 BRA PROC_EXC 

LINEF:

 MOVE #11,VECT_EXC
 BRA PROC_EXC 

EMULATOR_INT:

 MOVE #12,VECT_EXC
 BRA PROC_EXC 

ERREUR_FORMAT:

 MOVE #14,VECT_EXC
 BRA PROC_EXC 

UNINIT_INT:

 MOVE #15,VECT_EXC
 BRA PROC_EXC 

SPURIOUS_INT:

 MOVE #24,VECT_EXC
 BRA PROC_EXC 

INT1:

 MOVE #25,VECT_EXC
 BRA PROC_EXC

INT2:

 MOVE #26,VECT_EXC
 BRA PROC_EXC

INT3:

 MOVE #27,VECT_EXC
 BRA PROC_EXC
 
INT4:

 MOVE #28,VECT_EXC
 BRA PROC_EXC 
 
INT5:

 MOVE #29,VECT_EXC
 BRA PROC_EXC

INT6:

 MOVE #30,VECT_EXC
 BRA PROC_EXC
   
INT7:

 MOVE #31,VECT_EXC
 BRA PROC_EXC
 
TRAP0:

 MOVE #32,VECT_EXC
 BRA PROC_EXC

TRAP1:

 MOVE #33,VECT_EXC
 BRA PROC_EXC
 
TRAP2:

 MOVE #34,VECT_EXC
 BRA PROC_EXC
 
TRAP3:

 MOVE #35,VECT_EXC
 BRA PROC_EXC 
 
TRAP4:

 MOVE #36,VECT_EXC
 BRA PROC_EXC

TRAP5:

 MOVE #37,VECT_EXC
 BRA PROC_EXC
 
TRAP6:

 MOVE #38,VECT_EXC
 BRA PROC_EXC
 
TRAP7:

 MOVE #39,VECT_EXC
 BRA PROC_EXC 
  
TRAP8:

 MOVE #40,VECT_EXC
 BRA PROC_EXC

TRAP9:

 MOVE #41,VECT_EXC
 BRA PROC_EXC
 
TRAP10:

 MOVE #42,VECT_EXC
 BRA PROC_EXC
 
TRAP11:

 MOVE #43,VECT_EXC
 BRA PROC_EXC 
 
TRAP12:

 MOVE #44,VECT_EXC
 BRA PROC_EXC

TRAP13:

 MOVE #45,VECT_EXC
 BRA PROC_EXC
 
TRAP14:

 MOVE #46,VECT_EXC
 BRA PROC_EXC
 
TRAP15:

 MOVE #47,VECT_EXC
 BRA PROC_EXC

SAUT_RTE:

 RTE
 
SAUT_INTER:

 MOVE #$2700,SR
 MOVE 6(SP),VECT_EXC;format + vecteur offset
 LSR VECT_EXC
 LSR VECT_EXC
 AND #$FF,VECT_EXC

PROC_EXC:

 MOVE #$2700,SR
 MOVEM.L D0-A6,SAUVE_REG
 MOVE.L USP,A6
 MOVE.L A6,SAUVE_USP
 MOVE.L SP,SAUVE_SSP
 DC.L $4E7A0002;MOVEC.L CACR,D0
 MOVE.L D0,SAUVE_CACR
 MOVE.L SP,D0
; AND.B #$FE,D0
 lea PILE_CRASH,sp
 MOVE.L D0,A6
 MOVE.L D0,A0
 LEA SAUVE_STACK,A1
 MOVE.L (A0)+,(A1)+
 MOVE.L (A0)+,(A1)+
 MOVE.L (A0)+,(A1)+
 MOVE.L (A0)+,(A1)+
 BSR INFOS_CRASH
\1:BRA.S \1
 RTS 
 
INFOS_CRASH:

 pea MESS3(pc)
 bsr display_string
 addq.w #4,sp
 MOVE VECT_EXC,D7;no de vecteur
 MOVEQ #0,D0
 MOVE D7,D0
 LINK A5,#-4
 CLR -2(A5)
 LEA -4(A5),A0
 MOVEQ #3,D1
 BSR CONV_DECI
 pea -4(A5)
 bsr display_string
 addq.w #4,sp  
 UNLK A5
 move #":",-(sp)
 bsr display_char
 addq #2,sp
 move #$20,-(sp)
 bsr display_char
 addq #2,sp
 LEA TAB_MESS_EXC(PC),A0
 MOVE D7,D0
 BSR PRINTLINE_TAB
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 pea MESS9(pc);registre d'‚tat
 bsr display_string
 addq.w #4,sp 
 MOVE (A6),D0
 BSR AFF_HEX_WORD_D0
 pea MESS10(pc)
 bsr display_string
 addq.w #4,sp
 MOVE (A6)+,D2
 AND #%1011011100011111,D2
 LEA TAB_STATUS(PC),A1
 MOVEQ #15,D1
\5:BTST D1,D2
  BEQ.S \6
  MOVEQ #0,D0
  MOVE.B (A1,D1),D0
  MOVE D0,D3
  AND #$F8,D3
  CMP #$30,D3
  BNE.S \11
  move #"I",-(sp)
  bsr display_char
  addq #2,sp
\11:move D0,-(sp)
  bsr display_char
  addq #2,sp
  move #$20,-(sp)
  bsr display_char
  addq #2,sp
\6:DBRA D1,\5
 pea MESS11(pc);PC
 bsr display_string
 addq.w #4,sp 
 MOVE.L (A6)+,D0;PC
 BSR AFF_HEX_LONG_D0
 ADDQ #2,A6;format + vecteur offset
 pea MESS8(pc);CACR
 bsr display_string
 addq.w #4,sp 
 MOVE.L SAUVE_CACR,D0
 BSR AFF_HEX_LONG_D0
 CMP #2,D7
 BEQ.S \3;Acces Fault
 CMP #3,D7
 BEQ.S \3;Adress Error
 CMP #5,D7
 BEQ.S \3;Zero Divide
 CMP #9,D7
 BNE \2;<> Trace
\3:pea MESS7(pc);adresse acc‚d‚e
 bsr display_string
 addq.w #4,sp  
 MOVE.L (A6)+,D0
 BSR AFF_HEX_LONG_D0
 CMP #2,D7
 BNE \2;<> Acces Fault
 pea MESS4(pc);FSLW
 bsr display_string
 addq.w #4,sp  
 MOVE.L (A6),D0;FSLW
 BSR AFF_HEX_LONG_D0
 pea MESS10(pc)
 bsr display_string
 addq.w #4,sp
 move #13,-(sp)
 bsr display_char
 addq #2,sp 
 MOVE.L (A6)+,D2
 AND.L #%00001011111111111111111111111101,D2
 LEA TAB_FSLW1(PC),A1
 LEA TAB_FSLW2(PC),A2
 LEA TAB_FSLW3(PC),A3
 MOVEQ #31,D1
 MOVEQ #0,D3
\13:BTST D1,D2
  BEQ.S \14
  MOVEQ #0,D0
  MOVE.B (A1,D3),D0
  move D0,-(sp)
  bsr display_char
  addq #2,sp
  MOVEQ #0,D0
  MOVE.B (A2,D3),D0
  CMP.B #" ",D0
  BEQ.S \12
  move D0,-(sp)
  bsr display_char
  addq #2,sp
  MOVEQ #0,D0
  MOVE.B (A3,D3),D0
  CMP.B #" ",D0
  BEQ.S \12
  move D0,-(sp)
  bsr display_char
  addq #2,sp
\12:move #" ",-(sp)
  bsr display_char
  addq #2,sp
\14:ADDQ #1,D3
 DBRA D1,\13 
\2:pea MESS14(pc);SSP
 bsr display_string
 addq.w #4,sp  
 MOVE.L SAUVE_SSP,D0
 BSR AFF_HEX_LONG_D0
 pea MESS15(pc);USP
 bsr display_string
 addq.w #4,sp  
 MOVE.L SAUVE_USP,D0
 BSR AFF_HEX_LONG_D0
 LEA SAUVE_REG,A1
 LEA 32(A1),A2
 MOVEQ #7,D1
\8:move #13,-(sp)
  bsr display_char
  addq #2,sp
  move #"D",-(sp)
  bsr display_char
  addq #2,sp
  MOVEQ #7,D0
  SUB D1,D0
  OR #$30,D0
  MOVE D0,-(SP)
  BSR AFF_NO
  MOVE.L (A1),D0
  BSR AFF_HEX_LONG_D0;registres de donn‚es
  move #$20,-(sp)
  bsr display_char
  addq #2,sp
  TST D1
  BEQ.S \9
  move #"A",-(sp)
  bsr display_char
  addq #2,sp
  MOVE (SP),D0
  BSR AFF_NO
  MOVE.L (A2),D0
  BSR AFF_HEX_LONG_D0;registres d'adresses
  move #$20,-(sp)
  bsr display_char
  addq #2,sp
\9:ADDQ.L #2,SP
  ADDQ.L #4,A1
  ADDQ.L #4,A2
 DBRA D1,\8
 RTS

AFF_NO:

 move D0,-(sp)
 bsr display_char
 addq #2,sp
 move #":",-(sp)
 bsr display_char
 addq #2,sp
 move #"$",-(sp)
 bsr display_char
 addq #2,sp
 RTS

PRINTLINE_TAB;tableau point‚ par A0, D0:no du message

 MOVE D0,-(SP)
 MOVEQ #0,D0
\1:CMP.B #-1,(A0)
  BEQ.S \3
  CMP (SP),D0
  BEQ.S \4
\2:TST.B (A0)+
  BNE.S \2
  ADDQ #1,D0
 BRA.S \1
\4:pea (A0);affiche le type de l'exception
 bsr display_string
 addq.w #4,sp 
\3:ADDQ.L #2,SP
 RTS

AFF_HEX_LONG_D0:

 MOVE.L D0,-(SP)
 SWAP D0
 BSR.S AFF_HEX_WORD_D0
 MOVE.L (SP)+,D0

AFF_HEX_WORD_D0:

 MOVE D0,-(SP)
 LSR #8,D0
 BSR.S HEX_D0
 MOVE (SP)+,D0
 BSR.S HEX_D0
 RTS

HEX_D0:

 MOVE D0,-(SP)
 LSR.B #4,D0
 BSR.S \2
 MOVE (SP)+,D0
\2:AND.B #$F,D0
 OR.B #$30,D0
 CMP.B #$3A,D0
 BCS.S \3
 ADD.B #7,D0
\3:AND #$FF,D0
 move D0,-(sp)
 bsr display_char
 addq #2,sp
 RTS

MESS3:DC.B 13,"EXCEPTION PROCESSING ",0
MESS4:DC.B 13,"Fault Status Word (FSLW): ",0
MESS7:DC.B 13,"Adress Fault: $",0
MESS8:DC.B 13,"Cache Register (CACR): $",0
MESS9:DC.B 13,"Status Register (SR): $",0
MESS10:DC.B ", bits to 1: ",0
MESS11:DC.B 13,"Program Counter (PC): $",0
MESS14:DC.B 13,"Supervisor Stack (SSP): $",0
MESS15:DC.B 13,"User Stack (USP): $",0

TAB_MESS_EXC:
 DC.B 0
 DC.B 0
 DC.B "Acces Fault",0
 DC.B "Adress Error",0
 DC.B "Illegal Instruction",0
 DC.B "Integer Zero Divide",0
 DC.B 0
 DC.B 0
 DC.B "Privilege Violation",0
 DC.B "Trace",0
 DC.B "Line A",0
 DC.B "Line F",0
 DC.B "Emulator Interrupt",0
 DC.B 0
 DC.B "Format Error",0
 DC.B "Uninitialised Interrupt",0
 DC.B 0
 DC.B 0
 DC.B 0
 DC.B 0
 DC.B 0
 DC.B 0
 DC.B 0
 DC.B 0
 DC.B "Spurious Interrupt",0
 DC.B "Interrupt level 1",0
 DC.B "Interrupt level 2",0 
 DC.B "Interrupt level 3",0 
 DC.B "Interrupt level 4",0
 DC.B "Interrupt level 5",0 
 DC.B "Interrupt level 6",0
 DC.B "Interrupt level 7",0
 DC.B "Trap #0",0
 DC.B "Trap #1",0
 DC.B "Trap #2",0
 DC.B "Trap #3",0
 DC.B "Trap #4",0
 DC.B "Trap #5",0
 DC.B "Trap #6",0
 DC.B "Trap #7",0
 DC.B "Trap #8",0
 DC.B "Trap #9",0
 DC.B "Trap #10",0
 DC.B "Trap #11",0
 DC.B "Trap #12",0
 DC.B "Trap #13",0
 DC.B "Trap #14",0
 DC.B "Trap #15",0
 DC.B -1

TAB_STATUS:DC.B "CVZNX   012 MS T"
TAB_FSLW1:DC.B "    M LRWSSTTTTTIPSPPIPSWTRWTB S"
TAB_FSLW2:DC.B "    A K  ZZTTMMMOBBTTLFPPWEETP S"
TAB_FSLW3:DC.B "         1010210 EEAB    E  RE E"

 ALIGN.W

videl_save_mode:

 movem.l d0/A0-A2,-(sp)
 move.l 20(sp),a0
 lea $FFFF8200,a1
 move.w $A(a1),(a0)+
 move.w $10(a1),(a0)+
 move.w $64(a1),(a0)+
 move.w $66(a1),(a0)+
 lea $80(a1),a2
 moveq #9-1,d0
\B1 move.w (a2)+,(a0)+
 dbra d0,\B1
 lea $A0(a1),a2
 moveq #7-1,d0
\B2 move.w (a2)+,(a0)+
 dbra d0,\B2
 move.l $C0(a1),(a0)+
 movem.l (sp)+,D0/A0-A2
 rts

videl_set_mode:

 movem.l D0-D1/A0-A2,-(sp)
 move.l 24(sp),a0
 lea $FFFF8200,a1
 move.w (a0)+,$A(a1)
 move.w (a0)+,$10(a1)
 move.w (a0)+,$64(a1)
 move.w (a0)+,$66(a1)
 lea $80(a1),a2
 move.w (a0)+,(a2)+
 move.w (a0)+,(a2)+;HHT
 move.w (a0)+,(a2)+;HBB
 move.w (a0)+,(a2)+;HBE 
 move.w (a0)+,(a2)+;HDB
 move.w (a0)+,(a2)+;HDE
 move.w (a0)+,(a2)+;HSS
 move.w (a0)+,(a2)+;HFS  
 move.w (a0)+,(a2)+;HEE
 lea $A0(a1),a2
 move.w (a0)+,(a2)+
 move.w (a0)+,(a2)+;VFT
 move.w (a0)+,(a2)+;VBB 
 move.w (a0)+,(a2)+;VBE
 move.w (a0)+,(a2)+;VDB
 move.w (a0)+,(a2)+;VDE
 move.w (a0)+,(a2)+;VSS 
 move.l (a0)+,$C0(a1);RCO
 movem.l (sp)+,D0-D1/A0-A2
 rts

tempo_2S:

 movem.l d0/a1/a0,-(sp)
 lea $fffffa23,A0      ;timer C value changed at each 26 uS 
 MOVEQ #-1,D1
\tempo:move.b (A0),D0
\tempo2:cmp.b (A0),D0       ;26uS (timer C)
  beq.s \tempo2
 dbra d1,\tempo
 movem.l (sp)+,d0/d1/a0
 rts
 
INIT_MFP:

 MOVE SR,-(SP)
 OR #$700,SR;interdit IRQ
 LEA $FFFFFA00,A0;68901
 MOVEQ #0,D0
 MOVEQ #11,D1
\1:CLR.B 1(A0,D0)
  ADDQ #2,D0
 DBRA D1,\1
 MOVE.B #$48,$17(A0);VR software end of interrupt,vecteur $40
 CLR.B $1F(A0);TADR
 CLR.B $19(A0);TACR timer A … l'arrˆt
 CLR.B $21(A0);TBDR
 CLR.B $1B(A0);TBCR timer B … l'arrˆt
 MOVE.B #192,$23(A0);TCDR;5 mS timer C
 MOVE.B #$51,$1D(A0);TCDCR timer C timer systŠme, timer D g‚n‚rateur de bauds (ST)
 MOVE.B #2,$25(A0);TDDR (9600 bauds ST)
; MOVE.B #$1F,7(A0);IERA
; MOVE.B #$1F,$13(A0);IMRA tampon r‚ception rempli,erreur r‚ception
;                         tampon d'‚mission vide,erreur d'‚mission,timer B valid‚s
 CLR.B 7(A0);IERA
 CLR.B $13(A0);IMRA
 MOVE.B #$60,9(A0);IERB ;timer C, et clavier (bit 4 port E/S)
 MOVE.B #$60,$15(A0);IMRB
 CLR.B $27(A0);SCR
 MOVE.B #$BC,$29(A0);UCR parit‚e impaire,asynchrone 1 start 2 stop,7 bits,fr‚quence TC/16
 MOVE.B #1,$2B(A0);RSR
 MOVE.B #1,$2D(A0);TSR
 LEA $FFFFFC00,A0;ACIA clavier
 MOVE.B #3,(A0);reset
 MOVE.B #$96,(A0)
 LEA $FFFFFC04,A0;ACIA midi
 MOVE.B #3,(A0);reset
 MOVE.B #$95,(A0)
 LEA INTER_TIMER_C(PC),A0
 MOVE.L A0,$114
 LEA INTER_CLAVIER(PC),A0 
 MOVE.L A0,$118
 LEA INTER_HBL(PC),A0
 MOVE.L A0,$68
 LEA INTER_VBL(PC),A0
 MOVE.L A0,$70
 MOVE (SP)+,SR
 RTS
 
INTER_TIMER_C:

 MOVEM.L D0-A6,-(SP)
 ADDQ.L #1,_HZ_200
 SUBQ #1,TIME_OUT
 MOVE.B #14,$FFFF8800;PSG YAMAHA port A
 MOVE.B $FFFF8800,D0
 BCLR #1,D0;bit 4 port A
 BTST #7,_HZ_200+3
 BEQ.S \1
 BSET #1,D0;bit 4 port A
\1:MOVE.B D0,$FFFF8802
 MOVEM.L (SP)+,D0-A6
 BCLR #5,$FFFFFA11;ISRB
 RTE

INTER_VBL:

 ADDQ.L #1,_FRCLOCK
INTER_HBL:
 RTE
 
INTER_CLAVIER:;bit 4 port E/S

 MOVEM.L D0/A0-A2,-(SP)
 LEA $FFFFFA00,A0;68901
\4:LEA $FFFFFC04,A1
 MOVE.B (A1),D0
 BTST #7,D0;IRQ midi ?
 BEQ.S \1
 MOVE.B 2(A1),D0;acquitte ACIA midi
\1:LEA $FFFFFC00,A1
 MOVE.B (A1),D0
 BTST #7,D0;IRQ clavier ?
 BEQ.S \2
 BTST #0,D0;receiver plein ?
 BEQ.S \3
 BTST #5,D0;overrun ?
 BEQ.S \5
 CLR FLAG_JOY
\5:BSR SP_INTER_CLAVIER
\3:MOVE.B 2(A1),D0;acquitte ACIA clavier
\2:BTST #4,1(A0);GPIP nouvelle IRQ clavier
 BEQ.S \4
 BCLR #6,$11(A0);acquitte ISRB
 MOVEM.L (SP)+,D0/A0-A2
 RTE

SP_INTER_CLAVIER:

 LEA CLAV,A2
 MOVE.B 2(A1),D0
 TST FLAG_JOY
 BMI.S \20
 CMP.B #$F6,D0
 BCS.S \1;pression d'une touche
 CMP.B #$FF,D0;header joystick 1
 BNE \2
 MOVE #-1,FLAG_JOY
 BRA \2
\20:BTST #7,D0
 BEQ.S \23
 BSET #4,D0
 MOVE #$B,(A2)
 BRA.S \19
\23:CMP #$B,(A2)
 BNE.S \19
 MOVE #-1,(A2)
\19:AND #$1F,D0
 MOVE D0,JOY
 CLR FLAG_JOY
 BRA \2
\1:BTST #7,D0
 BNE \21;touche relach‚e
 CMP.B #$47,D0;CLR HOME (A)cquittement
 BNE.S \3
 MOVE #$A,(A2)
 BRA \2
\3:CMP.B #$39,D0;SPACE
 BNE.S \4
 MOVE #$B,(A2)
 BSET #4,JOY+1
 BRA \2
\4:CMP.B #$52,D0;INSERT (B)outon
 BNE.S \24
 MOVE #$1B,(A2)   
 BRA \2  
\24:CMP.B #$48,D0; (C)
 BNE.S \5
 MOVE #$C,(A2)
 BRA \2
\5:CMP.B #$50,D0; (D)‚placement
 BNE.S \6
 MOVE #$D,(A2)
 BRA \2
\6:CMP.B #1,D0;ESC
 BEQ.S \7
 CMP.B #$1C,D0;RETURN
 BEQ.S \7
 CMP.B #$72,D0;ENTER (E)ntr‚e
 BNE.S \8
\7:MOVE #$E,(A2)
 BRA \2
\8:CMP.B #$E,D0;BACKSPACE (F)aux
 BNE.S \9
 MOVE #$F,(A2)
 BRA \2
\9:CMP.B #$B,D0
 BEQ.S \25
 CMP.B #$70,D0;touche 0
 BNE.S \10
\25:CLR (A2)
 BRA \2
\10:CMP.B #2,D0
 BEQ.S \26
 CMP.B #$6D,D0;touche 1
 BNE.S \11
\26:MOVE #1,(A2)
 BRA \2
\11:CMP.B #3,D0
 BEQ.S \27
 CMP.B #$6E,D0;touche 2
 BNE.S \12
\27:MOVE #2,(A2)
 BRA \2
\12:CMP.B #4,D0
 BEQ.S \28
 CMP.B #$6F,D0;touche 3
 BNE.S \13
\28:MOVE #3,(A2)
 BRA \2
\13:CMP.B #5,D0
 BEQ.S \29
 CMP.B #$6A,D0;touche 4
 BNE.S \14
\29:MOVE #4,(A2)
 BRA \2
\14:CMP.B #6,D0
 BEQ.S \30
 CMP.B #$6B,D0;touche 5
 BNE.S \15
\30:MOVE #5,(A2)
 BRA \2
\15:CMP.B #7,D0
 BEQ.S \31
 CMP.B #$6C,D0;touche 6
 BNE.S \16
\31:MOVE #6,(A2)
 BRA \2
\16:CMP.B #8,D0
 BEQ.S \32
 CMP.B #$67,D0;touche 7
 BNE.S \17
\32:MOVE #7,(A2)
 BRA \2
\17:CMP.B #9,D0
 BEQ.S \33
 CMP.B #$68,D0;touche 8
 BNE.S \18
\33:MOVE #8,(A2)
 BRA \2
\18:CMP.B #$A,D0
 BEQ.S \34
 CMP.B #$69,D0;touche 9
 BNE.S \35
\34:MOVE #9,(A2)
 BRA \2
\35:CMP.B #$10,D0;A
 BCS.S \36
 CMP.B #$19,D0;P
 BHI.S \36
 AND #$FF,D0
 ADD #$10,D0;$20-$29
 MOVE D0,(A2)
 BRA \2
\36:CMP.B #$1E,D0;Q
 BCS.S \37
 CMP.B #$27,D0;M
 BHI.S \37
 AND #$FF,D0
 ADD #$12,D0;$30-$39
 MOVE D0,(A2)
 BRA \2
\37:CMP.B #$2C,D0;W
 BCS.S \38
 CMP.B #$31,D0;N
 BHI.S \38
 AND #$FF,D0
 ADD #$14,D0;$40-$45
 MOVE D0,(A2)
 BRA \2
\38:CMP.B #$3B,D0;F1
 BCS \2
 CMP.B #$44,D0;F10
 BHI \2
 AND #$FF,D0
 SUB #$2B,D0;$10-$19
 MOVE D0,(A2)
 BRA \2
\21:CMP.B #$B9,D0;SPACE (B)outon relach‚
 BNE.S \22
 BCLR #4,JOY+1
\22:MOVE #-1,(A2);touche relach‚e
\2:RTS

READ_CLAV:

 MOVEM.L A0-A2,-(SP)
 MOVE SR,D0
 AND #$700,D0
 CMP #$700,D0
 bne.s \av_inter_clav
 LEA $FFFFFC00,A1
 MOVE.B (A1),D0
 BTST #7,D0;IRQ clavier ?
 BEQ.S \av_inter_clav
 BTST #0,D0;receiver plein ?
 BEQ.S \clav
 BSR SP_INTER_CLAVIER
\clav:MOVE.B 2(A1),D0;acquitte ACIA clavier
\av_inter_clav:
 move CLAV,D0
 bmi.s \rien
 move #-1,CLAV
 TST D0
\rien:MOVEM.L (SP)+,A0-A2
 RTS

;************************************************

CHARGE_PROG_DSP:

 MOVEM.L D1-D2/D7/A0-A2,-(SP)
 DSP_REMOVEINTERRUPTS #3;port host
 DSP_REQUESTUNIQUEABILITY
 MOVE D0,ABIL
 DSP_FLUSHSUBROUTINES;libŠre toute la RAM DSP
 LEA PROG_DSP_TEST(PC),A0
 LEA FIN_PROG_DSP_TEST(PC),A1
 SUB.L A0,A1
 MOVE.L A1,D0;taille en octets
 DIVU #3,D0;taille en mots DSP
 EXT.L D0
 DSP_EXECPROG ABIL,D0,(A0);charge et lance le programme dans le DSP
 bmi.s \1
 MOVE.L #$3E00,D0
 DSP_RESERVE D0,D0
 EXT.L D0  
 moveq #0,d0
\1:MOVEM.L (SP)+,D1-D2/D7/A0-A2
 RTS

ENLEVE_PROG_DSP:

 MOVEM.L D0-D2/A0-A2,-(SP)
 DSP_REQUESTUNIQUEABILITY
 MOVE D0,ABIL
 DSP_REMOVEINTERRUPTS #3;port host
 LEA PROG_DSP_DEBUG(PC),A0
 LEA FIN_PROG_DSP_DEBUG(PC),A1
 SUB.L A0,A1
 MOVE.L A1,D0;taille en octets
 DIVU #3,D0;taille en mots DSP
 EXT.L D0
 DSP_EXECPROG ABIL,D0,(A0);charge et lance le programme dans le DSP jmp *
 bmi.s \1
 DSP_BLKHANDSHAKE #1,INFO_DEBUG_DSP,#0,0;r‚ception
 bmi.s \1
 DSP_BLKHANDSHAKE #0,0,#1,INFO_DEBUG_DSP;OK pour stop
 bmi.s \1
 DSP_RESERVE #0,#0
\1:moveq #0,d0 
 MOVEM.L (SP)+,D0-D2/A0-A2
 RTS
 
IRQ_OUT_DSP:

 BTST #0,$FFFFA202
 BEQ.S \1;pas de r‚ception
 MOVE.L A0,-(SP)
 LEA BUFFER_DSP,A0;buffer r‚ception
\2:BTST #0,$FFFFA202
 BEQ.S \2
 MOVE.B $FFFFA205,(A0)+
 MOVE.B $FFFFA206,(A0)+
 MOVE.B $FFFFA207,(A0)+
 ST.B OK_IRQ_DSP
 MOVE.L (SP)+,A0
\1:AND.B #$FC,$FFFFA200
 RTE
 
AFF_REG_DSP:

 pea string_dsp10(pc)
 bsr display_string
 addq.w #4,sp  
 move.b $FFFFA200,d0
 bsr HEX_D0
 pea string_dsp11(pc)
 bsr display_string
 addq.w #4,sp  
 move.b $FFFFA201,d0
 bsr HEX_D0 
 pea string_dsp12(pc)
 bsr display_string
 addq.w #4,sp  
 move.b $FFFFA202,d0
 bsr HEX_D0
 pea string_dsp13(pc)
 bsr display_string
 addq.w #4,sp  
 move.b $FFFFA203,d0
 bsr HEX_D0
 pea string_dsp14(pc)
 bsr display_string
 addq.w #4,sp  
 move.b $FFFFA204,d0
 bsr HEX_D0
 pea string_dsp15(pc)
 bsr display_string
 addq.w #4,sp  
 move.b $FFFFA205,d0
 bsr HEX_D0
 pea string_dsp16(pc)
 bsr display_string
 addq.w #4,sp  
 move.b $FFFFA206,d0
 bsr HEX_D0
 pea string_dsp17(pc)
 bsr display_string
 addq.w #4,sp  
 move.b $FFFFA207,d0
 bsr HEX_D0
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 move.l $FFFFA200,d0
 bsr AFF_HEX_LONG_D0
 move.l $FFFFA204,d0
 bsr AFF_HEX_LONG_D0
 move #13,-(sp)
 bsr display_char
 addq #2,sp
 move COMPT_DSP,d0
 bsr AFF_HEX_WORD_D0
 rts

DEVCONNECT_2:

 MOVEM.L D0-A6,-(A7)
 MOVEM 64(SP),D0-D1/A1
 TST D1;destination:
;enregistrement DMA(1)/DSP r‚ception(2)/sortie externe(4)/DAC(8)
 BEQ \1
 MOVE 70(SP),D2;prescale
 LEA $FFFF8930,A2;matrice sonore
 MOVEM (A2),D6-D7
 ADD A1,A1;source clock: interne 25MHz(0)/externe(1)/DSP 32MHz(2)
 MOVE \DEVC_INDEX1(PC,A1),D5
 MOVE \DEVC_MASK1(PC,A1),D4
 ASL D0,D5
 ASL D0,D5
 ASL D0,D5
 ASL D0,D5
 CMP #3,D0
 BNE.S \7
 MOVE \DEVC_MASK1(PC,A1),D5
 BRA.S \7
\DEVC_MASK1:DC.W 0,$6000,0
\DEVC_MASK2:DC.W $FFF0,$FF8F,$F0FF,$0FFF
\DEVC_INDEX1:DC.W 1,3,5,7
\DEVC_INDEX2:DC.W 0,2,4,6
\7:ADD D0,D0;source:
;lecture DMA(0)/DSP transmission(1)/entr‚e externe(2)/ADC ou Yamaha(3)
 AND \DEVC_MASK2(PC,D0),D6
 OR D5,D6
 LEA \DEVC_INDEX1(PC),A4
 BTST #0,D1;enregistrement DMA
 BEQ.S \8
 AND #$FFF0,D7
 OR (A4,D0),D7
\8:BTST #1,D1;DSP r‚ception
 BEQ.S \9
 AND #$FF8F,D7
 MOVE (A4,D0),D5
 ASL #4,D5
 OR D5,D7
\9:BTST #2,D1;sortie externe
 BEQ.S \6
 AND #$F0FF,D7
 MOVE (A4,D0),D5
 ASL #8,D5
 OR D5,D7
\6:BTST #3,D1;DAC
 BEQ.S \4
 AND #$FFF,D6
 OR D4,D6
 AND #$FFF,D7
 LEA \DEVC_INDEX2(PC),A4
 MOVE (A4,D0),D5
 ASL #8,D5
 ASL #4,D5
 OR D5,D7
\4:MOVE 4(A2),D5
 CMP #2,A1;horloge externe
 BNE.S \3
 ASL #8,D2
 AND #$F0FF,D5
 OR D2,D5
 BRA.S \2
\3:AND #$FFF0,D5
 OR D2,D5
\2:MOVEM D6-D7,(A2)
 MOVE D5,4(A2)
\1:MOVEM.L (A7)+,D0-A6
 RTS

PLAY_DMA:

 MOVE SR,-(SP)
 OR #$700,SR
 MOVE.L A1,-(SP)
 MOVE.L A0,-(SP)
 LEA $FFFF8900,A0;DMA sonore
 CLR.B 1(A0);stoppe DMA
 MOVE.B 3(SP),7(A0);poids faible
 MOVE.B 2(SP),5(A0);moyen
 MOVE.B 1(SP),3(A0);fort
 ADDQ #4,SP
 MOVE.B 3(SP),$13(A0);poids faible
 MOVE.B 2(SP),$11(A0);moyen
 MOVE.B 1(SP),$F(A0);fort
 ADDQ #4,SP
 MOVE.B #$43,$21(A0);stereo 16 bits
 MOVE.B #3,1(A0);play loop mode
 MOVE (SP)+,SR
 RTS

STOP_DMA:

 CLR.B $FFFF8901;stoppe DMA
 RTS
 
 ALIGN.L

MES_DELAY:

 MOVE.L _HZ_200,D1      
\1:SUBQ.L #1,D0;delay
 BNE.S \1            
 MOVE.L _HZ_200,D0   
 SUB.L D1,D0         
 RTS                 
 NOP
 NOP
 NOP
END_MES_DELAY:

 ALIGN.L

MES_DELAY_2:

 MOVE.L A6,-(SP)
 lea $2000000,a6
 movem.l d1-d2/a1-a2,-(A6)
 MOVE.L _HZ_200,D1      
\1:SUBQ.L #1,D0;delay
 BNE.S \1            
 MOVE.L _HZ_200,D0   
 SUB.L D1,D0         
 movem.l (A6)+,d1-d2/a1-a2
 move.l (SP)+,A6
 rts
 NOP
 NOP
 NOP 
END_MES_DELAY_2:


BOGOMIPS:

 MOVEM.L D1/D2/A0,-(SP)
 MOVEQ #1,D2;loops_per_sec
\2:ADD.L D2,D2
  BEQ.S \1
  MOVE.L D2,D0
  TST FLAG
  BNE.S \3
  BSR MES_DELAY
  BRA.S \4  
\3:LEA MES_DELAY_STRAM,A0
  TST.B FLAG+1
  BEQ.S \5
  LEA MES_DELAY_SDRAM,A0
\5:JSR (A0)
\4:CMP.L #CLOCKS_PER_SEC,D0
 BCS.S \2
 MOVE.L D0,D1;ticks
 MOVE.L D2,D0;loops_per_sec
 DC.L $4C410000;DIVU.L D1,D0;loops_per_sec/ticks
 MOVE.L #CLOCKS_PER_SEC,D1
 DC.L $4C010000;MULU.L D1,D0
 MOVE.L D0,D2;loops_per_sec
\1:MOVE.L D2,D0;loops_per_sec
 MOVEM.L (SP)+,D1/D2/A0
 RTS
 
ENVOI_CLAVIER:

 MOVEM.L D0/D1/A0,-(SP)
 LEA $FFFFFC00,A0;ACIA clavier 6850
\1:MOVE.B (A0),D1;caractŠre en cours ?
 BTST #1,D1
 BEQ.S \1
 MOVE.B D0,2(A0);envoi caractŠre
 MOVEM.L (SP)+,D0/D1/A0
 RTS

;INIT_SCC:

; MOVEM.L D0/D1/A0/A1,-(SP)
; LEA $FFFF8C81,A0;SCC
; MOVE.B #9,(A0)
; MOVE.B #$C0,(A0)
; LEA tab_scc(pc),a1
;\1:move.b (a1)+,d0
;  bmi.s \2
;  move.b d0,(a0)
;  move.b (a1)+,(a0)
; bra.s \1
;\2:LEA $FFFF8C85,A0;SCC
; LEA tab_scc(pc),a1
;\3:move.b (a1)+,d0
;  bmi.s \4
;  move.b d0,(a0)
;  move.b (a1)+,(a0)
; bra.s \3
;\4:MOVEM.L (SP)+,D0/D1/A0/A1
; RTS

;VERIFY_SCC:

; MOVEM.L A0/A1,-(SP)
; LEA $FFFF8C81,A0;SCC
; moveq #0,d0
; moveq #0,d1
; moveq #0,d2
; LEA tab_scc(pc),a1
;\1:move.b (a1)+,d0
;  bmi.s \2
;  cmp.b #2,d0
;  beq.s \4
;  cmp.b #12,d0
;  beq.s \4
;  cmp.b #13,d0
;  beq.s \4
;  cmp.b #15,d0
;  bne.s \5
;\4:move.b d0,(a0)
;  move.b (a0),d2
;  move.b (a1)+,d1
;  cmp.b d1,d2
;  bne.s \6
; bra.s \1
;\5:addq #1,A1
; bra.s \1
;\6:bset #15,d0
;\2:tst d0
; MOVEM.L (SP)+,A0/A1
; RTS

 INCLUDE "sdram.l"
 INCLUDE "temp.l"
 INCLUDE "dspxbios.l"
 INCLUDE "scc.l"
 INCLUDE "flash.l"

;initl_port_mfp:
;
; SCL_OUT
; SDA_OUT
; SCL_LOW
; SDA_LOW
; rts
 
;inith_port_mfp:
;    
; SCL_OUT
; SDA_OUT
; SCL_HIGH
; SDA_HIGH
; rts

MODE:
 IFNE 0,INCLUDE_VIDEO_MODE
  IBYTES "video.dat"
 ELSE
  ds.w 22,0
 ENDIF

colors:dc.l $FFFF00FF,$00000000

;tab_scc:
; dc.b $04,$44,$01,$04,$02,$60,$03,$C0
; dc.b $05,$E2,$06,$00,$07,$00,$09,$01
; dc.b $0A,$00,$0B,$50,$0C,$18,$0D,$00
; dc.b $0E,$02,$0E,$03,$03,$C1,$05,$EA
; dc.b $0F,$20,$00,$10,$00,$10,$01,$17
; dc.b $09,$09,$FF,$00

logo:

 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0001,$FC27,$FFFF,$000E,$03E0,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$000F,$07E7,$8F8F,$0078,$0E38,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$001C,$01E7,$0F87,$03E0,$1E3C,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0038,$00E6,$0F83,$0780 
 dc.w $1C1C,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0078,$0064 
 dc.w $0F81,$0F00,$3C1E,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $00F8,$0064,$0F81,$1F00,$3C1E,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$00F0,$0020,$0F80,$1E00,$7C1F,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$01F0,$0000,$0F80,$3FF0,$7C1F,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$01F0,$0000,$0F80,$3C78,$7C1F,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$01F0,$0000,$0F80,$7C7C,$7C1F,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$01F0,$0000,$0F80,$7C3E,$7C1F,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$01F0,$0000,$0F80,$7C3E 
 dc.w $7C1F,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$01F0,$0000 
 dc.w $0F80,$7C3E,$7C1F,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $00F0,$0000,$0F80,$7C3E,$7C1F,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$00F8,$0000,$0F80,$7C3E,$3C1E,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0078,$0020,$0F80,$3C3E,$3C1E,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$003C,$0060,$0F80,$3C3C,$1C1C,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$001E,$00C0,$0F80,$1E38,$1E3C,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$000F,$0300,$1FC0,$0E70,$0E38,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0001,$FC00,$7FF0,$03E0 
 dc.w $03E0,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$2222,$2222,$2222,$2222,$2666,$6666,$6466,$6766,$77FF,$FDFF 
 dc.w $FFF7,$6566,$6466,$6462,$2022,$2022,$2000,$0000,$8888,$8888,$8999,$9999,$9BBB,$BBDB,$BFDD,$DDDD 
 dc.w $DDDD,$DDDD,$DDDD,$DDDD,$DFDB,$BBB9,$9988,$8880,$8880,$0000,$0000,$0066,$6666,$66EE,$EAAA,$B777 
 dc.w $7777,$7777,$7777,$7777,$7777,$7777,$7776,$AEAE,$66E6,$6660,$0000,$0000,$8888,$8888,$8888,$8991 
 dc.w $9999,$9999,$99D9,$9DDD,$DDDD,$DFDD,$DDDD,$DDD9,$9999,$9190,$8988,$8888,$8880,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$003F,$FE00,$0F00,$0000,$0000,$007C,$8000 
 dc.w $0000,$0000,$007F,$F000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$000F,$0E00,$0700,$0000,$0000 
 dc.w $00C7,$8000,$0000,$0000,$001E,$3800,$0000,$0002,$0000,$0000,$0000,$0000,$0000,$000F,$0200,$0700 
 dc.w $0000,$0000,$0181,$8000,$0000,$0000,$001E,$1C00,$0000,$0006,$0000,$0000,$0000,$0000,$0000,$000F 
 dc.w $1200,$0700,$0000,$0000,$0180,$8000,$0000,$0000,$001E,$1C00,$0000,$000E,$0000,$0000,$0000,$0000 
 dc.w $0000,$000F,$103F,$0703,$E0F0,$79E0,$01C0,$8F1E,$7BC0,$787B,$C01E,$1C0F,$00F0,$1F9F,$83C3,$DE00 
 dc.w $0000,$0000,$0000,$000F,$30E1,$8706,$739C,$3BF0,$01F8,$070E,$3CE1,$CC3F,$C01E,$3839,$C39C,$618E 
 dc.w $0E61,$FE00,$0000,$0000,$0000,$000F,$F0E1,$C70C,$730C,$3C70,$00FF,$070E,$3861,$8639,$C01F,$F030 
 dc.w $C30C,$608E,$0C31,$CE00,$0000,$0000,$0000,$000F,$30E1,$C71C,$770E,$3870,$007F,$870E,$3873,$FE38 
 dc.w $001E,$3C70,$E70E,$7C0E,$1FF1,$C000,$0000,$0000,$0000,$000F,$1007,$C71C,$070E,$3870,$000F,$C70E 
 dc.w $3873,$BE38,$001E,$1E70,$E70E,$3F0E,$1DF1,$C000,$0000,$0000,$0000,$000F,$1039,$C71C,$070E,$3870 
 dc.w $0103,$C70E,$3873,$8038,$001E,$1E70,$E70E,$0F8E,$1C01,$C000,$0000,$0000,$0000,$000F,$0061,$C71C 
 dc.w $070E,$3870,$0181,$C70E,$3873,$8038,$001E,$1E70,$E70E,$438E,$1C01,$C000,$0000,$0000,$0000,$000F 
 dc.w $00E1,$C70E,$130C,$3870,$0181,$C71E,$3861,$C238,$001E,$1E30,$C30C,$618E,$4E11,$C000,$0000,$0000 
 dc.w $0000,$000F,$00E3,$C70F,$239C,$3870,$01C3,$83EE,$3CE1,$FC38,$001E,$3C39,$C39C,$710F,$8FE1,$C000 
 dc.w $0000,$0000,$0000,$003F,$C07D,$CF83,$C0F0,$7CF8,$013E,$03CF,$3BC0,$787E,$007F,$F00F,$00F0,$5E07 
 dc.w $03C3,$F000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$3800,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$3800,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $3800,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$7E00,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000 
 dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

SAMPLE:
 IBYTES "1000HZ.SPL"
END_SAMPLE:

font:
 IBYTES "font.bin"

PROG_DSP_TEST:
 IBYTES TEST.P56
FIN_PROG_DSP_TEST:

PROG_DSP_DEBUG:
 IBYTES DEBUGDSP.P56
FIN_PROG_DSP_DEBUG:

 ALIGN.W     ;pour la pile
  
fin:

 END
