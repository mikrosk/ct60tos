/* XBIOS CT60 functions
*  - Read on the CT60, the 68060 temperature on the TLV0831 DC from Texas I.
*    2,8 deg celcius / step 
*  - Parameters in flash
*  - Cache
*  Eiffel keyboard XBIOS
*
*  Didier Mequignon 2001-2004, e-mail: aniplay@wanadoo.fr
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

	.globl det_xbios
	.globl new_ikbdvect
	.globl new_statvec

#include "main.h"
#include "ct60.h"
#include "command.h"
#include "vars.h"

#define MES_TEMP_0 197
#define MES_TEMP_25 208
#define MES_TEMP_50 218
#define MES_TEMP_100 236
#define MES_TEMP_ERROR 255
#define CT60_READ_ERROR -1

#define _iera_mfp 0xfffffa07						// MFP registers
#define _ipra_mfp 0xfffffa0b
#define _isra_mfp 0xfffffa0f
#define _imra_mfp 0xfffffa13
#define _tbcr_mfp 0xfffffa1b
#define _tbdr_mfp 0xfffffa21						// timer B
#define _tcdr_mfp 0xfffffa23						// value changed at each 26 uS by system (timer C at 200 Hz)
#define _texas_tlv0831_data     0xf1000000                       // read from D0 (THDA)
#define _texas_tlv0831_cs_low   0xf1400000                       // CS at 0      (/THCS)
#define _texas_tlv0831_cs_high  0xf1000000                       // CS at 1      (THCS)
#define _texas_tlv0831_clk_low  0xf1800000                       // CLK at 0     (/THCK)
#define _texas_tlv0831_clk_high 0xf1c00000                       // CLK at 1     (THCK)

#define FLASH_UNLOCK1 (FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0xAAA)
#define FLASH_UNLOCK2 (FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0x554)

#define MAX_PARAM_FLASH 16
#define NB_BLOCK_PARAM (PARAM_SIZE/(MAX_PARAM_FLASH*4))
#define SIZE_BLOCK_PARAM (PARAM_SIZE/NB_BLOCK_PARAM) 

#define read_core_temperature 0xc60a
#define rw_parameter 0xc60b
#define cache 0xc60c
#define flush_cache 0xc60d
#define read_core_temperature_bis 0x0c6a
#define rw_parameter_bis 0x0c6b
#define cache_bis 0x0c6c
#define flush_cache_bis 0x0c6d

	dc.l 0x58425241  /* XBRA */
	dc.l 0x43543630  /* CT60 */
	dc.l 0x00E00D76
 
det_xbios:

	move.l USP,A0
	btst #5,(SP)                                        // call in supervisor state
	beq.s xb2
	lea.l 8(SP),A0
xb2:
	move.w (A0),D0                                      // function
	cmp.w #0x40,D0                                      // Blitmode
	bne.s xb10
	move.l 2(SP),D0                                     // PC
	and.l #0xFFF00000,D0
	cmp.l #0x00E00000,D0                                // TOS
	beq xb1
	moveq #0,D0                                         // no blitter
	rte
xb10:
	cmp.w #160,D0                                       // CacheCtrl MilanTOS
	bne.s xb15
	move.w 2(A0),D0                                     // OpCode
	bne.s xb16
	moveq #0,D0                                         // function is implemented
	rte
xb16:
	cmp.w #1,D0                                         // flush data cache
	bne.s xb17
	cpusha DC
	moveq #0,D0
	rte	
xb17:
	cmp.w #2,D0                                         // flush instruction cache
	bne.s xb18
	cpusha IC
	moveq #0,D0
	rte
xb18:
	cmp.w #3,D0                                         // flush data and instruction caches
	beq xb14
	cmp.w #4,D0                                         // inquire data cache mode
	bne.s xb19
	movec.l CACR,D0
	btst #31,D0
	bra.s xb20
xb19:
	cmp.w #6,D0                                         // inquire instruction cache mode
	bne.s xb21
	movec.l CACR,D0
	btst #15,D0
xb20:
	sne.b D0
	and.w #1,D0
	ext.l D0
	rte
xb21:
	cmp.w #5,D0                                         // set data cache mode
	beq.s xb22
	cmp.w #7,D0                                         // set instruction cache mode
	bne.s xb23
xb22:	
	tst.w 4(A0)                                         // mode
	beq xb24                                            // disable
	bra xb8                                             // enable
xb23:
	moveq #-5,D0                                        // error
	rts
xb15:	
	cmp.w #read_core_temperature,D0
	beq.s xb11
	cmp.w #read_core_temperature_bis,D0
	bne.s xb5
xb11:
	move.w 2(A0),-(SP)			// deg_type
	bsr ct60_read_temp
	cmp.w #CT60_CELCIUS,(SP)
	beq.s xb3
	cmp.w #CT60_FARENHEIT,(SP)
	bne.s xb4
	mulu #9,D0
	divu #5,D0
	add.w #32,D0
	bra.s xb3
xb4:
	moveq #CT60_READ_ERROR,D0                           // error
xb3:
	addq.l #2,SP
	rte
xb5:
	cmp.w #rw_parameter,D0
	beq.s xb12
	cmp.w #rw_parameter_bis,D0
	bne.s xb6
xb12:
	move.w 2(A0),D0                                     // mode
	move.l 4(A0),D1                                     // type_param
	move.l 8(A0),D2                                     // value
	bsr ct60_rw_param 
	rte
xb6:
	cmp.w #cache,D0
	beq.s xb13
	cmp.w #cache_bis,D0
	bne.s xb9
xb13:
	move.w 2(A0),D0
	bmi.s xb7
	bne.s xb8
xb24:
	jsr 0xE0085A                                        // caches off
	rte
xb8:
	jsr 0xE250C8                                        // caches on
	rte
xb7:
	movec.l CACR,D0
	rte
xb9:
	cmp.w #flush_cache,D0
	beq.s xb14
	cmp.w #flush_cache_bis,D0
	bne.s xb1
xb14:
	cpusha BC
	moveq #0,D0
	rte
xb1:
	move.l det_xbios-4,-(SP)
	rts

ct60_read_temp:

	movem.l D1-D3/A0-A2,-(SP)
	move.w SR,-(SP)
	or.w #0x700,SR								// no interrupts
	lea.l ct1(PC),A0
	move.l 8,A1								// bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0						// timer C value changed at each 26 uS (clock 19,2 KHz)
	tst.b _tbcr_mfp
	bne ct8									// timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)							// clock = 307,2 KHz 1,6 uS
	move.b #1,_tbcr_mfp						// 2,4576MHz/4
ct8:
	clr.l _texas_tlv0831_cs_low                         // cs=0
	move.b (A0),D0
wait1:
	cmp.b (A0),D0                                       // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait1
	clr.l _texas_tlv0831_clk_high                       // clk=1	(10 to 600 KHz for the tlv0831)
	move.b (A0),D0
wait2:
	cmp.b (A0),D0                                       // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait2
	clr.l _texas_tlv0831_clk_low                        // clk=0
	move.b (A0),D0
wait3:
	cmp.b (A0),D0                                       // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait3
	clr.l _texas_tlv0831_clk_high                       // clk=1
	move.b (A0),D0
wait4:
	cmp.b (A0),D0                                       // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait4
	clr.l _texas_tlv0831_clk_low                        // clk=0
	move.b (A0),D0
wait5:
	cmp.b (A0),D0                                       // 26uS (timer C) or 1,6uS (timer B)
	beq.s wait5
	move.l A1,8
	move.l A2,SP
	move.w (SP),SR
	moveq #0,D3								// data
	moveq #7,D2								// 8 bits
ct4:	clr.l _texas_tlv0831_clk_high                       // clk=1
		move.l _texas_tlv0831_data,d1
		lsr.l #1,D1							// data
		addx.w D3,D3
		move.b (A0),D0
wait6:
		cmp.b (A0),D0                          // 26uS (timer C) or 1,6uS (timer B)
		beq.s wait6
		clr.l _texas_tlv0831_clk_low           // clk=0
		move.b (A0),D0
wait7:
		cmp.b (A0),D0                          // 26uS (timer C) or 1,6uS (timer B)
		beq.s wait7
	dbf D2,ct4
	clr.l _texas_tlv0831_cs_high                        // cs=1
	cmp.w #MES_TEMP_ERROR,D3                            // error
	beq.s ct3
	moveq #0,D2                                         // value
	moveq #CT60_PARAM_OFFSET_TLV,D1                     // type_param
	moveq #CT60_MODE_READ,D0                            // read
	bsr ct60_rw_param
	add.l D3,D0                                         // offset
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
	moveq #CT60_READ_ERROR,D0                           // error
	bra.s ct2
ct1:
	moveq #CT60_READ_ERROR,D0                           // bus error
	move.l A1,8
	move.l A2,SP
ct2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s ct9								// timer C
	clr.b _tbcr_mfp							// timer B stopped
ct9:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D3/A0-A2
	rts
	
ct60_rw_param: // D0.W: mode, D1.L: type_param, D2.L: value	

	movem.l D1-A5,-(SP)
	link A6,#-MAX_PARAM_FLASH*4 
	tst.l D1
	bmi out_param     
	cmp.l #MAX_PARAM_FLASH-1,D1                         // type_param
	bcc out_param
	addq.l #1,D1
	asl.l #2,D1                                         // param * 4
	lea.l FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0xFF000000,A2
	moveq #-1,D3
	move.l #NB_BLOCK_PARAM-1,D4
	moveq #0,D6
find_last_block:
		cmp.l (A2),D3
		beq.s test_free_block
next_block:
		lea.l SIZE_BLOCK_PARAM(A2),A2
		add.l #SIZE_BLOCK_PARAM,D6             // offset free block
	dbf D4,find_last_block
	moveq #0,D6                                         // offset free block
	lea.l -SIZE_BLOCK_PARAM(A2),A2
	moveq #-1,D7                                        // erase sector if writing
	bra.s test_read
test_free_block:
	lea.l 4(A2),A3
	moveq #MAX_PARAM_FLASH-2,D5
loop_test_free_block:
		cmp.l (A3)+,D3
	dbne D5,loop_test_free_block
	bne.s next_block 
	lea.l -SIZE_BLOCK_PARAM(A2),A2
	moveq #0,D7                                         // writing inside the next block
test_read:
	and #1,D0                                           // mode
	beq read_param
	move.l (A2,D1.l),D0
	cmp.l D0,D2
	beq end_param                                       // no change	
	lea -MAX_PARAM_FLASH*4(A6),A3
	addq.l #4,A2
	clr.l (A3)+                                         // block used
	moveq #MAX_PARAM_FLASH-2,D0
save_param:
		move.l (A2)+,(A3)+                     // save params in the stack	
	dbf D0,save_param                                   // before erase sector command
	move.l D2,-MAX_PARAM_FLASH*4(A6,D1.L)               // value	
	move.w SR,-(SP)
	or #0x700,SR                                        // lock interrupts
	lea.l ct60_write_param(PC),A0
	lea.l end_ct60_write_param(PC),A2
	move.l phystop,A1
	movec.l SRP,D3
	sub.l #RESERVE_MEM_FONTS-0x6800,A1
	cmp.l #0x1000000,D3
	bcc.s .sdram
	sub.l #RESERVE_MEM-RESERVE_MEM_FONTS,A1
.sdram:
	sub.l A0,A2
	move.l A2,D3
	move.l A1,A2
	lsr.l #1,D3
	subq.l #1,D3
copy_prog:
		move.w (A0)+,(A1)+                     // copy program in the top of the STRAM
	dbf D3,copy_prog                                    // after the copy of Atari logo
	movec.l CACR,D3
	move.l D3,A5                                        // save CACR
	cpusha DC
	bclr.l #31,D3
	movec.l D3,CACR                                     // no cache
	cinva DC
	jsr (A2)                                            // ct60_write_param
	cpusha DC
	move.l A5,D2
	movec.l D2,CACR
	move.w (SP)+,SR
	bra.s end_param
read_param:
	move.l (A2,D1.l),D0
	bra.s end_param
out_param:
	moveq #-5,D0                                        // unimplemented opcode
end_param:
	unlk A6
	movem.l (SP)+,D1-A5
	rts

ct60_write_param:
	
	moveq #3,D3
	movec.l D3,SFC                                      // CPU space 3
	movec.l D3,DFC
	move.l D2,-(SP)                                     // save value
	lea.l FLASH_UNLOCK1+0xFF000000,A0
	lea.l FLASH_UNLOCK2+0xFF000000,A1
	lea.l FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0xFF000000,A2
	move.w #CMD_UNLOCK1,D3
	move.w #CMD_UNLOCK2,D4
	move.w #CMD_AUTOSELECT,D5
	move.w #CMD_READ,D1
	moves.w D3,(A0)
	moves.w D4,(A1)
	moves.w D5,(A0)                                     // Autoselect command
	move.l (A2),D0                                      // Manufacturer code / Device code
	moves.w D1,(A2)                                     // Read/Reset command
	lea.l devices(PC),A3
loop_dev:
		tst.l (A3)
		beq no_dev
		cmp.l (A3),D0
		beq.s found_dev
		addq.l #8,A3
	bra.s loop_dev
no_dev:
	addq.w #4,SP
	moveq #-15,D0                                       // device error
	bra program_param_loop_end_2
found_dev:
	lea.l devices(PC),A1
	add.l 4(A3),A1                                      // sector of device
	movem.l (A1),A2-A4                                  // sector, flash_unlock1, flash_unlock2
	add.l D6,A2                                         // offset free block
	tst.w D7
	beq.s erase_sector_end
	move.w #CMD_SECTOR_ERASE1,D5
	move.w #CMD_SECTOR_ERASE2,D6
	moves.w D3,(A3)
	moves.w D4,(A4)
	moves.w D5,(A3)
	moves.w D3,(A3)
	moves.w D4,(A4)
	moves.w D6,(A2)                                     // Erase sector command
wait_erase_loop:
		move.w (A2),D0
		btst.l #7,D0
		bne.s erase_sector_end
	btst.l #5,D0
	beq.s wait_erase_loop
	move.w (A2),D0
	btst.l #7,D0
	bne.s erase_sector_end
	addq.w #4,SP
	moveq #-10,D0                                       // write error
	bra.s program_param_loop_end
erase_sector_end:
	lea -MAX_PARAM_FLASH*4(A6),A0                       // buffer
	move.w #CMD_PROGRAM,D5
	moveq #(MAX_PARAM_FLASH*2)-1,D6                     // word counter
program_byte_loop:
		moveq #15,D7                           // retry counter
program_byte_retry:
			moves.w D3,(A3)
			moves.w D4,(A4)
			moves.w D5,(A3)           // Byte program command
			move.w (A0),D0
			moves.w D0,(A2)
			andi.b #0x80,D0
wait_program_loop:
				move.w (A2),D1
				eor.b D0,D1
				bpl.s wait_program_loop_end
			btst.l #5,D1
			beq.s wait_program_loop
			move.w (A2),D1
			eor.b D0,D1
			bpl.s wait_program_loop_end
program_byte_error:
		dbf D7,program_byte_retry
		addq.w #4,SP
		moveq #-10,D0                          // write error
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
	moves.w D3,(A3)
	moves.w D4,(A4)
	moves.w D5,(A3)                                     // Read/Reset command
program_param_loop_end_2:
	rts
	
devices:
	.long 0x000422AB, fujitsu_mbm29f400bc-devices
	.long 0x00042258, fujitsu_mbm29f800ba-devices
	.long 0x00012258, amd_am29f800bb-devices
	.long 0
	
fujitsu_mbm29f400bc:
	.long FLASH_ADR+0xFF0F0000, FLASH_UNLOCK1+0xFF000000, FLASH_UNLOCK2+0xFF000000

fujitsu_mbm29f800ba:
amd_am29f800bb:
	.long FLASH_ADR+0xFF0F0000, FLASH_UNLOCK1+0xFF000000, FLASH_UNLOCK2+0xFF000000

end_ct60_write_param:


new_ikbdvect:                                                    // test Eiffel keys

	move.b D0,D1
	bclr #7,D1
	cmp.b #0x45,D1                                      // PAGE UP
	bne.s .test_page_down
	btst #7,D0
	bne.s .break_page_up
	bset.b #0,0x1187                                    // SHIFT
	move.b #0x48,D0                                     // ^
	bra .test_shift
.break_page_up:
	bclr.b #0,0x1187                                    // SHIFT
	move.b #0xC8,D0                                     // ^
	bra .test_shift
.test_page_down:
	cmp.b #0x46,D1                                      // PAGE DOWN
	bne.s .test_print_screen
	btst #7,D0
	bne.s .break_page_down
	bset.b #0,0x1187                                    // SHIFT
	move.b #0x50,D0                                     // v
	bra .test_shift
.break_page_down:
	bclr.b #0,0x1187                                    // SHIFT
	move.b #0xD0,D0                                     // v
	bra .test_shift	
.test_print_screen:
	cmp.b #0x49,D1                                      // PRINT SCREEN
	bne.s .test_end
	btst #7,D0
	bne.s .break_print_screen
	bset.b #3,0x1187                                    // ALT
	move.b #0x62,D0                                     // HELP
	bra.s .test_shift
.break_print_screen:
	bclr.b #3,0x1187                                    // ALT
	move.b #0xE2,D0                                     // HELP
	bra.s .test_shift
.test_end:
	cmp.b #0x55,D1                                      // END
	bne.s .test_power
	btst #7,D0
	bne.s .break_end
	bset.b #0,0x1187                                    // SHIFT
	move.b #0x47,D0                                     // CLR HOME
	bra.s .test_shift
.break_end:
	bclr.b #0,0x1187                                    // SHIFT
	move.b #0xC7,D0                                     // CLR HOME
	bra.s .test_shift
.test_power:
	cmp.b #0x73,D1                                      // POWER
	bne.s .test_shift
	btst #7,D0
	bne.s .test_shift
	move.l A0,-(SP)
	move.l phystop,A0
	move.l #0xCAFEFADE,power_flag(A0)                   // tested inside evnt_multi AES
	move.l (SP)+,A0
.test_shift:
	move.b 0x1187,D1                                    // Shift state
	cmp.b #0x2A,D0
	rts

new_statvec:

	move.l A0,-(SP)
	lea det_statvec(PC),A0
	move.l A0,0x1142
	move.l #0xE02750,D0
	move.l (SP)+,A0
	rts

	dc.l 0x58425241  /* XBRA */
	dc.l 0x43543630  /* CT60 */
	dc.l 0x00E02750  /* RTS */
	
det_statvec:

	cmp.b #0x05,(A0)
	bne .no_eiffel_key
	movem.l D0/A0,-(SP)
	cmp.b #0x32,6(A0)                                   // VOLUME UP
	bne.s .not_volume_up
	move.w #-1,-(SP)
	clr.w -(SP)                  	             // LTATTEN
	jsr 0xE0620C                                        // soundcmd
	addq.l #4,SP
	sub.w #0x10,D0
	and.w #0xF0,D0
	cmp.w #0xF0,D0
	bne.s .not_lmax
	moveq #0,D0
.not_lmax:
	move.w D0,-(SP)
	clr.w -(SP)                  	             // LTATTEN
	jsr 0xE0620C                                        // soundcmd
	addq.l #4,SP
	move.w #-1,-(SP)
	move.w #1,-(SP)                  	             // RTATTEN
	jsr 0xE0620C                                        // soundcmd
	addq.l #4,SP
	sub.w #0x10,D0
	and.w #0xF0,D0
	cmp.w #0xF0,D0
	bne.s .not_rmax
	moveq #0,D0
.not_rmax:
	move.w D0,-(SP)
	move.w #1,-(SP)                  	             // RTATTEN
	jsr 0xE0620C                                        // soundcmd
	addq.l #4,SP
	bra.s .not_volume_down
.not_volume_up:
	cmp.b #0x21,6(A0)                                   // VOLUME DOWN
	bne.s .not_volume_down
	move.w #-1,-(SP)
	clr.w -(SP)                  	             // LTATTEN
	jsr 0xE0620C                                        // soundcmd
	addq.l #4,SP
	add.w #0x10,D0
	and.w #0xF0,D0
	bne.s .not_lmin
	move.w #0xF0,D0
.not_lmin:
	move.w D0,-(SP)
	clr.w -(SP)                  	             // LTATTEN
	jsr 0xE0620C                                        // soundcmd
	addq.l #4,SP
	move.w #-1,-(SP)
	move.w #1,-(SP)                  	             // RTATTEN
	jsr 0xE0620C                                        // soundcmd
	addq.l #4,SP
	add.w #0x10,D0
	and.w #0xF0,D0
	bne.s .not_rmin
	move.w #0xF0,D0
.not_rmin:
	move.w D0,-(SP)
	move.w #1,-(SP)                  	             // RTATTEN
	jsr 0xE0620C                                        // soundcmd
	addq.l #4,SP
.not_volume_down:	
	movem.l (SP)+,D0/A0
	bra.s .not_read_memory
.no_eiffel_key:
	cmp.b #0x20,(A0)
	bne.s .not_read_memory
	movem.l A0-A2,-(SP)
	move.l phystop,A2
	cmp.l #0xCAFEFADE,flag_statvec(A2)
	bne.s .not_read_memory
	move.l pbuf_statvec(A2),A1
	addq.l #1,A0
	move.b (A0)+,(A1)+
	move.b (A0)+,(A1)+
	move.b (A0)+,(A1)+
	move.b (A0)+,(A1)+
	move.b (A0)+,(A1)+		
	move.b (A0)+,(A1)+
	move.l A1,pbuf_statvec(A2)
	movem.l (SP)+,A0-A2
.not_read_memory:	
	rts
	
	