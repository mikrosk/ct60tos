MES_TEMP_0 equ 197
MES_TEMP_25 equ 208
MES_TEMP_50 equ 218
MES_TEMP_100 equ 236
MES_TEMP_ERROR equ 255

_texas_tlv0831_data equ $f1000000   ;read from D0 (THDA)
_texas_tlv0831_cs_low equ $f1400000   ;CS at 0      (/THCS)
_texas_tlv0831_cs_high equ $f1000000  ;CS at 1      (THCS)
_texas_tlv0831_clk_low equ $f1800000  ;CLK at 0     (/THCK)
_texas_tlv0831_clk_high equ $f1c00000  ;CLK at 1     (THCK)
 
ct60_read_temp:

 movem.l D1-D3/A0-A2,-(SP)
 move SR,-(SP)
 or #$700,SR        ;no interrupts
 lea \1(PC),A0
 move.l 8,A1        ;bus error
 move.l A0,8
 move.l SP,A2
 lea _tcdr_mfp,A0      ;timer C value changed at each 26 uS (clock 19,2 KHz)
 tst.b _tbcr_mfp
 bne.s \8        ;timer B used
 bclr #0,_imra_mfp
 bclr #0,_iera_mfp
 bclr #0,_ipra_mfp
 bclr #0,_isra_mfp    
 lea _tbdr_mfp,A0 
 move.b #2,(A0)       ;clock = 307,2 KHz (value changed at each 1,6 uS)
 move.b #2,_tbcr_mfp  ; 2,4576MHz/10 => 122KHz (value changed at each 4 uS)  
; move.b  #1,_tbcr_mfp      ;2,4576MHz/4
\8: clr.l _texas_tlv0831_cs_low    ;cs=0
 WAIT_US
 clr.l _texas_tlv0831_clk_high   ;clk=1 (10 to 600 KHz for the tlv0831)
 WAIT_US
 clr.l _texas_tlv0831_clk_low   ;clk=0
 WAIT_US
 clr.l _texas_tlv0831_clk_high   ;clk=1
 WAIT_US
 clr.l _texas_tlv0831_clk_low   ;clk=0
 WAIT_US
 move.l A1,8
 move.l A2,SP
 move (SP),SR
 moveq #0,D3        ;data
 moveq #7,D2        ;8 bits
\4:  clr.l _texas_tlv0831_clk_high  ;clk=1
  move.l _texas_tlv0831_data,d1
  lsr.l #1,D1       ;data
  addx.w D3,D3
  WAIT_US
  clr.l _texas_tlv0831_clk_low  ;clk=0
  WAIT_US
 dbf D2,\4
 clr.l _texas_tlv0831_cs_high   ;cs=1
 move.l D3,D0
 cmp.w #MES_TEMP_ERROR,D0    ;error
 beq.s \3
 cmp.w #MES_TEMP_0,D0
 bcs.s \5
 cmp.w #MES_TEMP_25,D0
 bcc.s \6
 sub.w #MES_TEMP_0,D0
 mulu #25,D0
 divu #(MES_TEMP_25-MES_TEMP_0),D0
 ext.l D0
 bra.s \2
\6: cmp.w #MES_TEMP_50,D0
 bcc.s \7
 sub.w #MES_TEMP_25,D0
 mulu #25,D0
 divu #(MES_TEMP_50-MES_TEMP_25),D0
 add.w #25,D0
 ext.l D0
 bra.s \2
\7: sub.w #MES_TEMP_50,D0
 mulu #50,D0
 divu #(MES_TEMP_100-MES_TEMP_50),D0
 add.w #50,D0
 ext.l D0
 bra.s \2
\5: moveq #0,D0
 bra.s \2
\3: moveq #CT60_READ_ERROR,D0    ;error
 bra.s \2
\1: moveq #CT60_READ_ERROR,D0    ;bus error
 move.l A1,8
 move.l A2,SP
\2: lea _tbdr_mfp,A1
 cmp.l A0,A1
 bne.s \9
 clr.b _tbcr_mfp       ;timer B stopped
\9: move (SP)+,SR
 tst.l D0
 movem.l (SP)+,D1-D3/A0-A2
 rts
 
 end

