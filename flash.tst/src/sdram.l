
SLAVE_ADRESS equ $A0      ;7 bits 1010xxx + r/w

CT60_READ_ERROR equ -1
CT60_CHIP_DENSITY_ERROR equ -2
CT60_NUM_BANK_ERROR equ -3
CT60_MOD_DENSITY_ERROR equ -4
CT60_BURST_LENGTH_ERROR equ -5
CT60_DATA_WIDTH_ERROR equ -6
CT60_VOLTAGE_ERROR equ -7
CT60_SDRAM_TYPE_ERROR equ -8
CT60_REFRESH_RATE_ERROR equ -9

 IFEQ 0,FLASH
_gpip_mfp equ $fffffa01
_ddr_mfp  equ $fffffa05
 ENDIF
_iera_mfp equ $fffffa07      ;MFP registers
_ipra_mfp equ $fffffa0b
_isra_mfp equ $fffffa0f
_imra_mfp equ $fffffa13
_tbcr_mfp equ $fffffa1b
_tbdr_mfp equ $fffffa21      ;timer B
_tcdr_mfp equ $fffffa23     ;timer C
_scl_low equ $f0000000      ;write 0 to SCL line (clock)
_scl_high equ $f0400000      ;write 1 to SCL line (clock)
_sda_low equ $f0800000      ;write 0 to SDA line (data)
_sda_high equ $f0c00000      ;write 1 to SDA line (data) 
_sda equ $f0000000       ;read from SDA line on the D0 CPU data bus
_sdcnf equ $f2000000      ;SDRAM configuration $f2xx0000 

READ_SDA:MACRO

 IFNE 0,FLASH
  move.l _sda,d0       ;data on D0 
 ELSE
  move.b _gpip_mfp,d0
 ENDIF 
 ENDM
 
SDA_LOW:MACRO

 IFNE 0,FLASH
  clr.l _sda_low
 ELSE
  BCLR #0,_gpip_mfp
 ENDIF
 ENDM

SDA_HIGH:MACRO

 IFNE 0,FLASH
  clr.l _sda_high
 ELSE
  BSET #0,_gpip_mfp
 ENDIF
 ENDM
 
SCL_LOW:MACRO      

 IFNE 0,FLASH
  clr.l _scl_low
 ELSE
  BCLR #1,_gpip_mfp
 ENDIF
 ENDM

SCL_HIGH:MACRO

 IFNE 0,FLASH
  clr.l _scl_high
 ELSE
  BSET #1,_gpip_mfp
 ENDIF
 ENDM
 
SDA_IN:MACRO

 IFEQ 0,FLASH
  BCLR #0,_ddr_mfp
 ENDIF
 ENDM
 
SDA_OUT:MACRO

 IFEQ 0,FLASH
  BSET #0,_ddr_mfp
 ENDIF
 ENDM
 
SCL_IN:MACRO

 IFEQ 0,FLASH
  BCLR #1,_ddr_mfp
 ENDIF
 ENDM
 
SCL_OUT:MACRO

 IFEQ 0,FLASH
  BSET #1,_ddr_mfp
 ENDIF
 ENDM


ct60_read_info_sdram:        ;A0: 128 bytes buffer, D0 return error

 movem.l D1-D3/A0-A4,-(SP) 
 lea out,A3

 move.l A0,A4
 move SR,-(SP)
 or #$700,SR        ;no interrupts
 lea \1(PC),A0
 move.l 8,A1        ;bus error
 move.l A0,8
 move.l SP,A2
 lea _tcdr_mfp,A0      ;timer C value changed at each 26 uS (clock 19,2 KHz)
 tst.b _tbcr_mfp

 bra.s \6

 bne.s \6        ;timer B used
 bclr #0,_imra_mfp
 bclr #0,_iera_mfp
 bclr #0,_ipra_mfp
 bclr #0,_isra_mfp    
 lea _tbdr_mfp,A0 
 move.b #2,(A0)       ;clock = 78,125 KHz (value changed at each 6,4 uS)
 move.b #3,_tbcr_mfp      ;2,4576MHz/16
 SCL_OUT
 SDA_OUT
\6:bsr start_bit_i2c
 move.l A1,8
 move.l A2,SP
 bsr write_device_i2c
 moveq #0,D0        ;write adress
 bsr write_bit_i2c      ;r/w
 bsr read_bit_i2c      ;ack

 move.b #"A",-1(A3)  
 
 btst #0,D0 
 bne \3        ;no acknoledge
 
 move.b #" ",(A3)+ 
 
 moveq #0,D0
 bsr write_bit_wait_slave_i2c ;adress 1st bit
 moveq #6,D2        ;8 bits
\4:  moveq #0,D0  ;adress
  bsr write_bit_i2c
 dbf D2,\4
 bsr read_bit_i2c      ;ack
 bne.s \3        ;no acknoledge

 move.b #"A",-1(A3) 
 move.b #" ",(A3)+ 
 move.b #13,(A3)+ 

 bsr start_bit_wait_slave_i2c
 bsr write_device_i2c
 moveq #1,D0        ;read data
 bsr write_bit_i2c      ;r/w
 bsr read_bit_i2c      ;ack

 move.b #"A",-1(A3) 
 
 btst #0,D0 
 bne.s \3        ;no acknoledge

 move.b #" ",(A3)+

 moveq #127,D3       ;128 bytes
\8:
  moveq #0,D1        ;data
  bsr read_bit_wait_slave_i2c  ;1st bit
  lsr.l #1,D0       ;data
  addx.w D1,D1
  moveq #6,D2        ;8 bits
\5:
   bsr read_bit_i2c
   lsr.l #1,D0       ;data
   addx.w D1,D1
  dbf D2,\5
  move.b D1,(A4)+
  tst D3
  seq.b D0
  and #1,D0    ;ack master = 1 => no other byte
  bsr write_bit_i2c

  move.b #"a",-1(A3)

  tst d3
  beq.s \9
  move.b #" ",(A3)+ 
  move.b #13,(A3)+  
\9:

 dbra D3,\8
 bsr stop_bit_i2c

 move.b #" ",(A3)+ 
 move.b #13,(A3)+  

 moveq #0,D0 ; OK
 bra.s \2
\3: bsr stop_bit_i2c
 moveq #CT60_READ_ERROR,D0    ;error
 bra.s \2
\1: moveq #CT60_READ_ERROR,D0    ;bus error
 move.l A1,8
 move.l A2,SP
\2: lea _tbdr_mfp,A1
 cmp.l A0,A1
 bne.s \7
 clr.b _tbcr_mfp       ;timer B stopped
\7: move (SP)+,SR
 clr.b (A3)
 tst.l D0
 movem.l (SP)+,D1-D3/A0-A4
 rts

ct60_configure_sdram:

 movem.l D1-D2/A0-A1/A3,-(SP)
 lea out,A3
 
 lea _sdcnf,A0
 moveq #2,D0        ;memory type
 bsr read_i2c_sdram
 bmi \1         ;error
 cmp #4,D0        ;SDRAM
 beq.s \13
 moveq #CT60_SDRAM_TYPE_ERROR,D0
 bra \1 
\13:
 moveq #3,D0        ;number of row adresses
 bsr read_i2c_sdram
 bmi \1         ;error
 move D0,D1
 moveq #4,D0        ;number of column adresses
 bsr read_i2c_sdram
 bmi \1         ;error
 lea chip_density(PC),A1
\3:  tst.w (a1)
  ble.s \2       ;not found => chip density error
  cmp.w (A1),D1      ;number of raw adresses
  bne.s \4
  cmp.w 2(A1),D0     ;number of column adresses
  beq.s \5       ;found
\4:  addq #8,A1
 bra.s \3
\2: 
 moveq #CT60_CHIP_DENSITY_ERROR,D0
 bra \1
\5:
 add.l 4(A1),A0       ;chip density on A23-A22
 moveq #12,D0             ; refresh rate
 bsr read_i2c_sdram
 bmi \1                   ; error
 and.w #$7F,D0
 cmp.w #5,D0
 bhi.s \16                ; error
 cmp.w #1,D0
 beq.s \16                ; 3.9 uS => error
 cmp.w #2,D0
 bne.s \17
 add.l #$10000,A0         ; A16 7.81 uS
 bra.s \17
\16:
 moveq #CT60_REFRESH_RATE_ERROR,D0
 bra \1
\17:
 moveq #5,D0        ;number of DIMM banks
 bsr read_i2c_sdram
 bmi \1         ;error
 cmp.w #1,D0
 beq.s \6
 cmp.w #2,D0
 bne.s \7        ;num bank error
 add.l #$100000,A0      ;A20
 bra.s \6
\7: 
 moveq #CT60_NUM_BANK_ERROR,D0
 bra \1
\6:
 move d0,d1        ;number of DIMM banks
 moveq #6,D0        ;module data width
 bsr read_i2c_sdram
 bmi \1        ;error
 cmp.w #$40,D0
 bne.s \11        ;data width error
 moveq #7,D0        ;module data width
 bsr read_i2c_sdram
 bmi \1        ;error
 beq.s \14
\11:
 moveq #CT60_DATA_WIDTH_ERROR,D0
 bra \1
\14:
 moveq #8,D0        ;voltage interface
 bsr read_i2c_sdram
 bmi \1        ;error
 cmp.w #1,D0        ;LVTTL
 beq.s \12
 moveq #CT60_VOLTAGE_ERROR,D0
 bra.s \1
\12:
 moveq #17,D0       ;number of banks on SDRAM device
 bsr read_i2c_sdram
 bmi.s \1        ;error
 cmp.w #4,D0
 bne.s \7        ;num bank error
 moveq #31,D0       ;module density
 bsr read_i2c_sdram
 bmi.s \1        ;error
 cmp.w #8,D0
 beq.s \10        ;32
 cmp.w #16,D0
 beq.s \10        ;64
 cmp.w #32,D0
 beq.s \10        ;128
 cmp.w #64,D0
 beq.s \10        ;256
 cmp.w #128,D0
 bne.s \8         ;<> 512 => module density error
\10:
 mulu D1,D0       ;* number of DIMM banks
 asl.w #2,D0      ;MB
 cmp.w #64,D0
 beq.s \9
 cmp.w #128,D0
 beq.s \9
 cmp.w #256,D0
 beq.s \9
 cmp.w #512,D0
 beq.s \9
\8: 
 moveq #CT60_MOD_DENSITY_ERROR,D0
 bra.s \1
\9:
 lsr.w #7,d0
 cmp.w #3,d0
 bcs.s \15
 moveq #3,D0
\15:
 move.l D0,D1
 swap D1
 asl.l #2,D1
 add.l D1,A0        ;size on A19-A18
 IFNE 0,FLASH 
  clr.l (A0)        ;write config
 ENDIF
 tst.l D0        ;return size 0-3 for 64MB-512MB
\1:
 clr.b (A3)
 movem.l (SP)+,D1-D2/A0-A1/A3
 rts
 
read_i2c_sdram:        ;D0: adress, D0 return data or error

 movem.l D1-D2/A0-A2,-(SP)
 move SR,-(SP)
 or #$700,SR        ;no interrupts
 lea \1(PC),A0
 move.l 8,A1        ;bus error
 move.l A0,8
 move.l SP,A2
 lea _tcdr_mfp,A0      ;timer C value changed at each 26 uS (clock 19,2 KHz)
 tst.b _tbcr_mfp

 bra.s \6

 bne.s \6        ;timer B used
 bclr #0,_imra_mfp
 bclr #0,_iera_mfp
 bclr #0,_ipra_mfp
 bclr #0,_isra_mfp    
 lea _tbdr_mfp,A0 
 move.b #2,(A0)       ;clock = 78,125 KHz (value changed at each 6,4 uS)
 move.b #3,_tbcr_mfp      ;2,4576MHz/16
 SCL_OUT
 SDA_OUT
\6:move D0,D1        ;adress
 bsr start_bit_i2c
 move.l A1,8
 move.l A2,SP
 bsr write_device_i2c
 moveq #0,D0        ;write adress
 bsr write_bit_i2c      ;r/w
 bsr read_bit_i2c      ;ack

 move.b #"A",-1(A3)  
 
 btst #0,D0 
 bne \3        ;no acknoledge
 
 move.b #" ",(A3)+ 
 
 moveq #0,D0
 add.b D1,D1  
 addx.b D0,D0 ;adress 1st bit
 bsr write_bit_wait_slave_i2c
 moveq #6,D2        ;8 bits
\4:  moveq #0,D0
    add.b D1,D1  
  addx.b D0,D0      ;adress
  bsr write_bit_i2c
 dbf D2,\4
 bsr read_bit_i2c      ;ack
 bne.s \3        ;no acknoledge

 move.b #"A",-1(A3) 
 move.b #" ",(A3)+ 
 move.b #13,(A3)+ 

 bsr start_bit_wait_slave_i2c
 bsr write_device_i2c
 moveq #1,D0        ;read data
 bsr write_bit_i2c      ;r/w
 bsr read_bit_i2c      ;ack

 move.b #"A",-1(A3) 
 
 btst #0,D0 
 bne.s \3        ;no acknoledge

 move.b #" ",(A3)+

 moveq #0,D1        ;data
 bsr read_bit_wait_slave_i2c ;1st bit
 lsr.l #1,D0        ;data
 addx.w D1,D1
 moveq #6,D2        ;8 bits
\5:
  bsr read_bit_i2c
  lsr.l #1,D0       ;data
  addx.w D1,D1
 dbf D2,\5
 moveq #1,D0        ;ack master = 1 => no other byte
 bsr write_bit_i2c

 move.b #"a",-1(A3)
 
 bsr stop_bit_i2c

 move.b #" ",(A3)+ 
 move.b #13,(A3)+  

 moveq #0,D0
 move D1,D0        ;8 bits data
 bra.s \2
\3: bsr stop_bit_i2c
 moveq #CT60_READ_ERROR,D0    ;error
 bra.s \2
\1: moveq #CT60_READ_ERROR,D0    ;bus error
 move.l A1,8
 move.l A2,SP
\2: lea _tbdr_mfp,A1
 cmp.l A0,A1
 bne.s \7
 clr.b _tbcr_mfp       ;timer B stopped
\7: move (SP)+,SR
 tst.l D0
 movem.l (SP)+,D1-D2/A0-A2
 rts
 
write_device_i2c:

 movem.l D0-D2,-(SP)
 move #SLAVE_ADRESS,D1
 moveq #6,D2        ;7 bits $A0      ;7 bits 1010xxx
\1:  moveq #0,D0
    add.b D1,D1  
  addx.b D0,D0      ;device
  bsr write_bit_i2c
 dbf D2,\1
 movem.l (SP)+,D0-D2
 rts

read_bit_i2c:

 SDA_HIGH       ;data=1 initial state (open drain)
 SDA_IN
 WAIT_US       ;100 KHz max !  
 SCL_HIGH       ;clk=1  
 WAIT_US
 READ_SDA       ;data on D0  
 SCL_LOW       ;clk=0
 
 move.b d0,(a3)
 and.b #1,(A3)
 or.b #"0",(A3)+
 
 btst #0,D0
 rts 
 
read_bit_wait_slave_i2c:

 move.l D1,-(SP)
 SDA_HIGH;data=1 initial state (open drain)
 SDA_IN
 WAIT_US
 SCL_HIGH;clk=1 
 SCL_IN 
 moveq #31,D1;time-out slave busy
\1:WAIT_US;100 KHz max !
  READ_SDA;SCL slave on B1
  btst #1,D0
 dbne D1,\1
 READ_SDA;data on B0  
 SCL_OUT
 SCL_LOW;clk=0  
 move.l (SP)+,D1   

 move.b d0,(a3)
 and.b #1,(A3)
 or.b #"0",(A3)+
 
 btst #0,D0
 rts 
 
write_bit_i2c:

 move.b d0,(a3)
 and.b #1,(A3)
 or.b #"0",(A3)+

 SDA_OUT  
 tst.w D0
 bne.s \w1
 SDA_LOW       ;data=0  
 bra.s \w2
\w1:
 SDA_HIGH       ;data=1  
\w2:
 WAIT_US       ;100 KHz max !  
 SCL_HIGH       ;clk=1
 WAIT_US
 SCL_LOW       ;clk=0  
 rts 
 
write_bit_wait_slave_i2c:

 move.b d0,(a3)
 and.b #1,(A3)
 or.b #"0",(A3)+

 move.l D1,-(SP)
 SDA_OUT
 tst.w D0
 bne.s \1
 SDA_LOW;data=0  
 bra.s \2
\1:
 SDA_HIGH;data=1  
\2:
 WAIT_US
 SCL_HIGH;clk=1
 SCL_IN
 moveq #31,D1;time-out slave busy
\3:
  WAIT_US;100 KHz max !  
  READ_SDA;SCL slave on B1
 btst #1,D0
 dbne D1,\3 
 SCL_OUT
 SCL_LOW;clk=0
 move.l (SP)+,D1  
 rts 
 
start_bit_i2c:

 SDA_OUT
 SDA_HIGH       ;data=1 initial state
 SCL_HIGH       ;clk=1  
 WAIT_US       ;100 KHz max !  
 SDA_LOW       ;data=0 => start condition 
 WAIT_US
 SCL_LOW       ;clk=0

 move.b #"S",(A3)+

 rts

start_bit_wait_slave_i2c:

 move.l D1,-(SP)
 SDA_OUT
 SDA_HIGH;data=1 initial state
 WAIT_US;100 KHz max !  
 SCL_HIGH;clk=1  
 SCL_IN
 moveq #31,D1;time-out slave busy
\1:WAIT_US;100 KHz max !  
  move.l _sda,D0;SCL slave on B1
  btst #1,D0
 dbne D1,\1  
 SCL_OUT
 SDA_LOW;data=0 => start condition 
 WAIT_US
 SCL_LOW;clk=0
 move.l (SP)+,D1

 move.b #"S",(A3)+

 rts
 
stop_bit_i2c:

 SDA_OUT
 SDA_LOW       ;data=0 
 WAIT_US       ;100 KHz max !
 SCL_HIGH       ;clk=1  
 WAIT_US 
 SDA_HIGH       ;data=1 => stop condition
 WAIT_US

 move.b #"X",(A3)+
 
 rts


;*************************************************

ct60_configure_eeprom:

 movem.l D1-D2/A0-A1/A3,-(SP)
 lea out,A3

 moveq #2,D0        ;memory type
 moveq #4,D1;SDRAM
 bsr write_i2c_sdram
 bmi \1         ;error
 moveq #3,D0        ;number of row adresses
 moveq #$C,D1              ;4Mx16b
 bsr write_i2c_sdram
 bmi \1         ;error
 moveq #4,D0        ;number of column adresses
 moveq #8,D1              ;4Mx16b
 bsr write_i2c_sdram
 bmi \1         ;error
 moveq #5,D0        ;number of DIMM banks
 moveq #1,D1  
 bsr write_i2c_sdram
 bmi \1         ;error
 moveq #6,D0        ;module data width
 moveq #$40,d1
 bsr write_i2c_sdram
 bmi \1        ;error
 moveq #7,D0        ;module data width
 moveq #0,D1
 bsr write_i2c_sdram
 bmi \1        ;error
 moveq #8,D0        ;voltage interface
 moveq #1,D1        ;LVTTL
 bsr write_i2c_sdram
 bmi.s \1        ;error
 moveq #17,D0       ;number of banks on SDRAM device
 moveq #4,D1
 bsr write_i2c_sdram
 bmi.s \1        ;error
 moveq #31,D0       ;module density
 moveq #8,D1                ;32MB
 bsr write_i2c_sdram
\1:
 clr.b (A3)
 movem.l (SP)+,D1-D2/A0-A1/A3
 rts

write_i2c_sdram:        ;D0: adress, D1: data, D0 return data or error

 movem.l D1-D3/A0-A2,-(SP)
 move SR,-(SP)
 or #$700,SR        ;no interrupts
 lea \1(PC),A0
 move.l 8,A1        ;bus error
 move.l A0,8
 move.l SP,A2
 lea _tcdr_mfp,A0      ;timer C value changed at each 26 uS (clock 19,2 KHz)
 tst.b _tbcr_mfp

 bra.s \6

 bne.s \6        ;timer B used
 bclr #0,_imra_mfp
 bclr #0,_iera_mfp
 bclr #0,_ipra_mfp
 bclr #0,_isra_mfp    
 lea _tbdr_mfp,A0 
 move.b #2,(A0)       ;clock = 78,125 KHz (value changed at each 6,4 uS)
 move.b #3,_tbcr_mfp      ;2,4576MHz/16
 SCL_OUT
 SDA_OUT
\6:move D0,D3        ;adress
 bsr start_bit_i2c
 move.l A1,8
 move.l A2,SP
 bsr write_device_i2c
 moveq #0,D0        ;write adress & data
 bsr write_bit_i2c      ;r/w
 bsr read_bit_i2c      ;ack

 move.b #"A",-1(A3)  
 
 btst #0,D0 
 bne \3        ;no acknoledge
 
 move.b #" ",(A3)+ 
 
 moveq #0,D0
 add.b D3,D3  
 addx.b D0,D0 ;adress 1st bit
 bsr write_bit_wait_slave_i2c
 moveq #6,D2        ;8 bits
\4:  moveq #0,D0
    add.b D3,D3  
  addx.b D0,D0      ;adress
  bsr write_bit_i2c
 dbf D2,\4
 bsr read_bit_i2c      ;ack

 move.b #"A",-1(A3)  
 
 btst #0,D0 
 bne.s \3        ;no acknoledge

 move.b #" ",(A3)+

 moveq #0,D0
 add.b D1,D1  
 addx.b D0,D0 ;adress 1st bit
 bsr write_bit_wait_slave_i2c
 moveq #6,D2        ;8 bits
\5:  moveq #0,D0
    add.b D1,D1  
  addx.b D0,D0      ;data
  bsr write_bit_i2c
 dbf D2,\5
 bsr read_bit_i2c      ;ack

 move.b #"A",-1(A3)  
 
 btst #0,D0 
 bne.s \3        ;no acknoledge

 bsr stop_bit_i2c

 move.b #" ",(A3)+ 
 move.b #13,(A3)+  

 moveq #0,D0
 bra.s \2
\3: bsr stop_bit_i2c
 moveq #CT60_READ_ERROR,D0    ;error
 bra.s \2
\1: moveq #CT60_READ_ERROR,D0    ;bus error
 move.l A1,8
 move.l A2,SP
\2: bsr wait_16scl 
 lea _tbdr_mfp,A1
 cmp.l A0,A1
 bne.s \7
 clr.b _tbcr_mfp       ;timer B stopped
\7: move (SP)+,SR
 tst.l D0
 movem.l (SP)+,D1-D3/A0-A2
 rts

wait_16scl:

 movem.l d0/d1,-(sp)
 moveq #31,D1;time-out slave busy
\1:WAIT_US;100 KHz max !  
 dbra D1,\1  
 movem.l (sp)+,d0/d1
 rts

;*************************************************

 
chip_density:          ; A23-A22 cdy2-1

 dc.w $C,$9,$00,0      ; 8Mx8b / 8Mx16b
 dc.w $C,$A,$40,0      ; 16Mx8b
 dc.w $D,$9,$80,0      ; 16Mx16b
 dc.w $D,$A,$C0,0      ; 32Mx8b / 32Mx16b
 dc.w 0,0,0,0          ; end


 end
