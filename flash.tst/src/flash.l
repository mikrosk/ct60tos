
CMD_UNLOCK1 EQU $AA
CMD_UNLOCK2 EQU $55
CMD_SECTOR_ERASE1 EQU $80
CMD_SECTOR_ERASE2 EQU $30
CMD_PROGRAM EQU $A0
CMD_AUTOSELECT EQU $90
CMD_READ EQU $F0

FLASH_ADR EQU $00E00000
FLASH_SIZE EQU $00100000
PARAM_SIZE EQU (64*1024)

FLASH_UNLOCK1 EQU (FLASH_ADR+FLASH_SIZE-PARAM_SIZE+$AAA)
FLASH_UNLOCK2 EQU (FLASH_ADR+FLASH_SIZE-PARAM_SIZE+$554)

MAX_PARAM_FLASH EQU 16
NB_BLOCK_PARAM EQU (PARAM_SIZE/(MAX_PARAM_FLASH*4))
SIZE_BLOCK_PARAM EQU (PARAM_SIZE/NB_BLOCK_PARAM) 

ct60_rw_param: ; D0.W: mode, D1.L: type_param, D2.L: value

 movem.l D2-A5,-(SP)
 link A6,#-MAX_PARAM_FLASH*4 
 tst.l D1
 bmi out_param     
 cmp.l #MAX_PARAM_FLASH-1,D1                         ; type_param
 bcc out_param
 addq.l #1,D1
 asl.l #2,D1                                         ; param * 4
 lea FLASH_ADR+FLASH_SIZE-PARAM_SIZE,A2
 moveq #-1,D3
 move.l #NB_BLOCK_PARAM-1,D4
 moveq #0,D6
find_last_block:
  cmp.l (A2),D3
  beq.s test_free_block
next_block:
  lea SIZE_BLOCK_PARAM(A2),A2
  add.l #SIZE_BLOCK_PARAM,D6             ; offset free block
 dbf D4,find_last_block
 moveq #0,D6                                         ; offset free block
 lea -SIZE_BLOCK_PARAM(A2),A2
 moveq #-1,D7                                        ; erase sector if writing
 bra.s test_read
test_free_block:
 lea 4(A2),A3
 moveq #MAX_PARAM_FLASH-2,D5
loop_test_free_block:
  cmp.l (A3)+,D3
 dbne D5,loop_test_free_block
 bne.s next_block 
 lea -SIZE_BLOCK_PARAM(A2),A2
 moveq #0,D7                                         ; writing inside the next block
test_read:
 and #1,D0                                           ; mode
 beq read_param
 move.l d0,d3
 swap d3
 move.l (A2,D1.l),D0
 cmp.l D0,D2
 beq end_param                                       ; no change 
 lea -MAX_PARAM_FLASH*4(A6),A3
 addq.l #4,A2
 clr.l (A3)+                                         ; block used
 moveq #MAX_PARAM_FLASH-2,D0
save_param:
  move.l (A2)+,(A3)+                     ; save params in the stack 
 dbf D0,save_param                                   ; before erase sector command
 move.l D2,-MAX_PARAM_FLASH*4(A6,D1.L)               ; value 
 move.w SR,-(SP)
 or #$700,SR                                        ; lock interrupts
 lea ct60_write_param(PC),A0
 lea end_ct60_write_param(PC),A2
 tst d3
 beq.s moves
 lea ct60_write_param_move(PC),A0
 lea end_ct60_write_param_move(PC),A2
moves:
 lea $100000,A1
 sub.l A0,A2
 move.l A2,D3
 move.l A1,A2
 lsr.l #1,D3
 subq.l #1,D3
copy_prog:
  move.w (A0)+,(A1)+                     ; copy program in the top of the STRAM
 dbf D3,copy_prog
 dc.l $4E7A3002; movec.l CACR,D3
 move.l D3,A5                                        ; save CACR
 dc.w $F478; cpusha DC
 bclr #31,D3
 dc.l $4E7B3002; movec.l D3,CACR                                     ; no cache
 dc.w $F458; cinva DC
 jsr (A2)                                            ; ct60_write_param
 dc.w $F478; cpusha DC
 move.l A5,D2
 dc.l $4E7B2002; movec.l D2,CACR
 move.w (SP)+,SR
 bra.s end_param
read_param:
 move.l (A2,D1.l),D0
 bra.s end_param
out_param:
 moveq #-5,D0                                        ; unimplemented opcode
end_param:
 unlk A6
 movem.l (SP)+,D2-A5
 rts

ct60_write_param:
 
 moveq #3,D3
 dc.l $4E7B3000; movec.l D3,SFC                                      ; CPU space 3
 dc.l $4E7B3001; movec.l D3,DFC
 move.l D2,-(SP)                                     ; save value
; moveq #1,D2                                         ; ct60 bug moves counter
;loop_err_dev:
 lea FLASH_UNLOCK1,A0
 lea FLASH_UNLOCK2,A1
 lea FLASH_ADR+FLASH_SIZE-PARAM_SIZE,A2
 move.w #CMD_UNLOCK1,D3
 move.w #CMD_UNLOCK2,D4
 move.w #CMD_AUTOSELECT,D5
 move.w #CMD_READ,D1
 dc.l $0E503800; moves.w D3,(A0)
 dc.l $0E514800; moves.w D4,(A1)
 dc.l $0E505800; moves.w D5,(A0)                                     ; Autoselect command
 move.l (A2),D0                                      ; Manufacturer code / Device code
 dc.l $0E521800; moves.w D1,(A2)                                     ; Read/Reset command
 lea devices(PC),A3
loop_dev:
  tst.l (A3)
  beq no_dev
  cmp.l (A3),D0
  beq.s found_dev
  addq.l #8,A3
 bra.s loop_dev
no_dev:
; dbf D2,loop_err_dev
 addq.w #4,SP
 move.l d0,d1;device
 moveq #-15,D0                                       ; device error
 bra program_param_loop_end_2
found_dev:
 lea devices(PC),A1
 add.l 4(A3),A1                                      ; sector of device
 movem.l (A1),A2-A4                                  ; sector, flash_unlock1, flash_unlock2
 add.l D6,A2                                         ; offset free block
 tst.w D7
 beq.s erase_sector_end
 move.w #CMD_SECTOR_ERASE1,D5
 move.w #CMD_SECTOR_ERASE2,D6
 dc.l $0E533800; moves.w D3,(A3)
 dc.l $0E544800; moves.w D4,(A4)
 dc.l $0E535800; moves.w D5,(A3)
 dc.l $0E533800; moves.w D3,(A3)
 dc.l $0E544800; moves.w D4,(A4)
 dc.l $0E526800; moves.w D6,(A2)                                     ; Erase sector command
wait_erase_loop:
  move.w (A2),D0
  btst #7,D0
  bne.s erase_sector_end
 btst #5,D0
 beq.s wait_erase_loop
 addq.w #4,SP
 moveq #-11,D0                                       ; write error
 bra.s program_param_loop_end
erase_sector_end:
; moveq #1,D2                                         ; ct60 bug moves counter
;loop_err_prog:
 lea -MAX_PARAM_FLASH*4(A6),A0                       ; buffer
 move.w #CMD_PROGRAM,D5
 moveq #(MAX_PARAM_FLASH*2)-1,D6                     ; word counter
program_byte_loop:
  moveq #15,D7                           ; retry counter
program_byte_retry:
   dc.l $0E533800; moves.w D3,(A3)
   dc.l $0E544800; moves.w D4,(A4)
   dc.l $0E535800; moves.w D5,(A3)           ; Byte program command
   move.w (A0),D0
   dc.l $0E520800; moves.w D0,(A2)
   andi.b #$80,D0
wait_program_loop:
    move.w (A2),D1
    eor.b D0,D1
    bpl.s wait_program_loop_end
   btst #5,D1
   beq.s wait_program_loop
program_byte_error:
  dbf D7,program_byte_retry
;  dbf D2,loop_err_prog
  addq.w #4,SP
  moveq #-10,D0                          ; write error
  bra.s program_param_loop_end
wait_program_loop_end:
  move.w (A2),D1
  cmp.w (A0),D1
  bne.s program_byte_error
  addq.l #2,A2
  addq.l #2,A0
 dbf D6,program_byte_loop
 move.l (SP)+,D0
program_param_loop_end:
 move.w #CMD_READ,D5
 dc.l $0E533800; moves.w D3,(A3)
 dc.l $0E544800; moves.w D4,(A4)
 dc.l $0E535800; moves.w D5,(A3)                                     ; Read/Reset command
program_param_loop_end_2:
 rts

devices:
 DC.L $000422AB, fujitsu_mbm29f400bc-devices
 DC.L $00042258, fujitsu_mbm29f800ba-devices
 DC.L 0

fujitsu_mbm29f400bc:
 DC.L FLASH_ADR+$F0000, FLASH_UNLOCK1, FLASH_UNLOCK2

fujitsu_mbm29f800ba:
 DC.L FLASH_ADR+$F0000, FLASH_UNLOCK1, FLASH_UNLOCK2

end_ct60_write_param:

ct60_write_param_move:
 
 CLR.L $F9800000;enable writing
 move.l D2,-(SP)                                     ; save value
; moveq #1,D2                                         ; ct60 bug moves counter
;loop_err_dev_move:
 lea FLASH_UNLOCK1,A0
 lea FLASH_UNLOCK2,A1
 lea FLASH_ADR+FLASH_SIZE-PARAM_SIZE,A2
 move.w #CMD_UNLOCK1,D3
 move.w #CMD_UNLOCK2,D4
 move.w #CMD_AUTOSELECT,D5
 move.w #CMD_READ,D1
 move.w D3,(A0)
 move.w D4,(A1)
 move.w D5,(A0)                                     ; Autoselect command
 move.l (A2),D0                                      ; Manufacturer code / Device code
 move.w D1,(A2)                                     ; Read/Reset command
 lea devices_move(PC),A3
loop_dev_move:
  tst.l (A3)
  beq no_dev_move
  cmp.l (A3),D0
  beq.s found_dev_move
  addq.l #8,A3
 bra.s loop_dev_move
no_dev_move:
; dbf D2,loop_err_dev_move
 addq.w #4,SP
 move.l d0,d1;device
 moveq #-15,D0                                       ; device error
 bra program_param_loop_end_2_move
found_dev_move:
 lea devices_move(PC),A1
 add.l 4(A3),A1                                      ; sector of device
 movem.l (A1),A2-A4                                  ; sector, flash_unlock1, flash_unlock2
 add.l D6,A2                                         ; offset free block
 tst.w D7
 beq.s erase_sector_end_move
 move.w #CMD_SECTOR_ERASE1,D5
 move.w #CMD_SECTOR_ERASE2,D6
 move.w D3,(A3)
 move.w D4,(A4)
 move.w D5,(A3)
 move.w D3,(A3)
 move.w D4,(A4)
 move.w D6,(A2)                                     ; Erase sector command
wait_erase_loop_move:
  move.w (A2),D0
  btst #7,D0
  bne.s erase_sector_end_move
 btst #5,D0
 beq.s wait_erase_loop_move
 addq.w #4,SP
 moveq #-11,D0                                       ; write error
 bra.s program_param_loop_end_move
erase_sector_end_move:
; moveq #1,D2                                         ; ct60 bug moves counter
;loop_err_prog_move:
 lea -MAX_PARAM_FLASH*4(A6),A0                       ; buffer
 move.w #CMD_PROGRAM,D5
 moveq #(MAX_PARAM_FLASH*2)-1,D6                     ; word counter
program_byte_loop_move:
  moveq #15,D7                           ; retry counter
program_byte_retry_move:
   move.w D3,(A3)
   move.w D4,(A4)
   move.w D5,(A3)           ; Byte program command
   move.w (A0),D0
   move.w D0,(A2)
   andi.b #$80,D0
wait_program_loop_move:
    move.w (A2),D1
    eor.b D0,D1
    bpl.s wait_program_loop_end_move
   btst #5,D1
   beq.s wait_program_loop_move
program_byte_error_move:
  dbf D7,program_byte_retry_move
;  dbf D2,loop_err_prog_move
  addq.w #4,SP
  moveq #-10,D0                          ; write error
  bra.s program_param_loop_end_move
wait_program_loop_end_move:
  move.w (A2),D1
  cmp.w (A0),D1
  bne.s program_byte_error_move
  addq.l #2,A2
  addq.l #2,A0
 dbf D6,program_byte_loop_move
 move.l (SP)+,D0
program_param_loop_end_move:
 move.w #CMD_READ,D5
 move.w D3,(A3)
 move.w D4,(A4)
 move.w D5,(A3)                                     ; Read/Reset command
program_param_loop_end_2_move:
 CLR.L $F9000000
 rts

devices_move:
 DC.L $000422AB, fujitsu_mbm29f400bc_move-devices_move
 DC.L $00042258, fujitsu_mbm29f800ba_move-devices_move
 DC.L 0

fujitsu_mbm29f400bc_move:
 DC.L FLASH_ADR+$F0000, FLASH_UNLOCK1, FLASH_UNLOCK2

fujitsu_mbm29f800ba_move:
 DC.L FLASH_ADR+$F0000, FLASH_UNLOCK1, FLASH_UNLOCK2

end_ct60_write_param_move:

 END
