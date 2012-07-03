/* XBIOS CT60 / Coldfire board(s) Parameters in Flash
*
*  Didier Mequignon 2001-2010, e-mail: aniplay@wanadoo.fr
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

#include "main.h"
#include "ct60.h"
#include "command.h"

#ifdef COLDFIRE
#include "fire.h"
#else
#define FLASH_UNLOCK1 (FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0xAAA)
#define FLASH_UNLOCK2 (FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0x554)
#endif

#define MAX_PARAM_FLASH 16
#define NB_BLOCK_PARAM (PARAM_SIZE/(MAX_PARAM_FLASH*4))
#define SIZE_BLOCK_PARAM (PARAM_SIZE/NB_BLOCK_PARAM) 

#ifdef COLDFIRE
	.globl fire_rw_param
#else
	.globl ct60_rw_param
#endif
	.globl init_flash_parameters

	.text

#ifdef COLDFIRE

	.chip 68060 // some code to fix

fire_rw_param: // D0.W: mode, D1.L: type_param, D2.L: value	

	lea -52(SP),SP
	movem.l D1-A5,(SP)
	link A6,#-MAX_PARAM_FLASH*4 
	tst.l D1
	bmi out_param     
	cmp.l #MAX_PARAM_FLASH-1,D1 // type_param
	bcc out_param
	addq.l #1,D1
	asl.l #2,D1              // param * 4
	move.l MCF_FBCS_CSAR0,D3
	and.l #0xFFFF0000,D3
	lea FLASH_TOS_FIRE_ENGINE-BOOT_FLASH_BASE+FLASH_SIZE-PARAM_SIZE,A2
	add.l D3,A2              // base parameters
	moveq #-1,D3
	move.l #NB_BLOCK_PARAM-1,D4
	moveq #0,D6
find_last_block:
		cmp.l (A2),D3
		beq.s test_free_block
next_block:
		lea SIZE_BLOCK_PARAM(A2),A2
		add.l #SIZE_BLOCK_PARAM,D6 // offset free block
	subq.l #1,D4
	bpl.s find_last_block
	moveq #0,D6              // offset free block
	lea -SIZE_BLOCK_PARAM(A2),A2
	moveq #-1,D7             // erase sector if writing
	bra.s test_read
test_free_block:
	lea 4(A2),A3
	moveq #MAX_PARAM_FLASH-2,D5
loop_test_free_block:
		cmp.l (A3)+,D3
		bne.s next_block
	subq.l #1,D5 
	bpl.s loop_test_free_block
	moveq #0,D7              // writing inside the next block
	tst.l D6
	beq.s test_read          // 1st block is free block
	lea -SIZE_BLOCK_PARAM(A2),A2
test_read:
	and.l #1,D0              // mode
	beq read_param
	move.l (A2,D1.l),D0
	cmp.l D0,D2
	beq end_param            // no change	
	lea -MAX_PARAM_FLASH*4(A6),A3
	addq.l #4,A2
	clr.l (A3)+              // block used
	moveq #MAX_PARAM_FLASH-2,D0
save_param:
		move.l (A2)+,(A3)+   // save params in the stack	
	subq.l #1,D0
	bpl.s save_param         // before erase sector command
	move.l D2,-MAX_PARAM_FLASH*4(A6,D1.L) // value	
	bsr fire_write_param
	bra.s end_param
read_param:
	move.l (A2,D1.l),D0
	bra.s end_param
out_param:
	moveq #-5,D0             // unimplemented opcode
end_param:
	unlk A6
	movem.l (SP),D1-A5
	lea 52(SP),SP
	rts

fire_write_param:

#ifdef MCF5445X /* M54455EVB */
	
	move.l D2,-(SP)          // save value
	lea devices(PC),A1
	add.l 4(A1),A1           // sector of device
	movem.l (A1),A2-A4       // sector, flash_unlock1, flash_unlock2
	moveq #FLASH_WP,D3
	move.b D3,CPLD_FLASHCFG  // unprotect flash
	move.l MCF_FBCS_CSAR0,D3 // boot flash
	and.l #0xFFFF0000,D3
	add.l D3,A2              // base parameters	
	add.l D6,A2              // offset free block
	add.l D3,A3              // base parameters (last sector)
	move.w #CMD_UNLOCK1,(A3)
	move.w #CMD_UNLOCK2,(A3)
	tst.w D7
	beq.s erase_sector_end
	move.w #CMD_SECTOR_ERASE1,(A3)
	move.w #CMD_SECTOR_ERASE2,(A3) // Erase sector command
wait_erase_loop:
		move.w #CMD_STATUS,(A3)
		move.w (A3),D0
	btst #7,D0
	beq.s wait_erase_loop
	move.w #CMD_READ,(A3)
erase_sector_end:
	lea -MAX_PARAM_FLASH*4(A6),A0   // buffer
	moveq #(MAX_PARAM_FLASH*2)-1,D6 // word counter
program_byte_loop:
		move.w #CMD_PROGRAM,(A2)  // Byte program command
		move.w (A0),(A2)
wait_program_loop:
			move.w #CMD_STATUS,(A2)
			move.w (A2),D0
		btst #7,D0
		beq.s wait_program_loop
		move.w #CMD_READ,(A2)
		move.w (A2),D0
		cmp.w (A0),D0
		beq.s program_byte_ok
		addq.l #4,SP
		moveq #-10,D0      // write error
		bra.s program_param_loop_end		
program_byte_ok:
		addq.l #2,A2
		addq.l #2,A0
	subq.l #1,D6
	bpl.s program_byte_loop
	move.l (SP)+,D0
program_param_loop_end:
	move.w #CMD_LOCK1,(A3)
	move.w #CMD_LOCK2,(A3)
	move.w #CMD_READ,(A3)
	moveq #0,D1
	move.b D1,CPLD_FLASHCFG  // protect flash
	rts
	
devices:
	dc.l 0x00890018, intel_28f128j3d-devices
	dc.l 0
	
intel_28f128j3d:
	dc.l FLASH_TOS_FIRE_ENGINE-BOOT_FLASH_BASE+FLASH_SIZE-PARAM_SIZE
	dc.l FLASH_UNLOCK1, FLASH_UNLOCK2

#else
#ifdef MCF547X /* FIREBEE */

	move.l D2,-(SP)          // save value
	lea devices(PC),A1
	add.l 4(A1),A1           // sector of device
	move.l (A1),A2           // sector
	move.l 4(A1),A0          // flash_unlock1
	move.l 8(A1),A1          // flash_unlock2
	move.l MCF_FBCS_CSMR0,D3
	and.l #~MCF_FBCS_CSMR_WP,D3 // unprotect flash
	move.l D3,MCF_FBCS_CSMR0
	move.l MCF_FBCS_CSAR0,D5 // boot flash
	and.l #0xFFFF0000,D5
	add.l D5,A2              // base parameters
	add.l D5,A0
	add.l D5,A1
	move.w #CMD_UNLOCK1,D3
	move.w #CMD_UNLOCK2,D4
	move.w #CMD_AUTOSELECT,D5
	move.w #CMD_READ,D1
	move.w D3,(A0)           // unlock
	move.w D4,(A1)
	move.w D5,(A0)           // Autoselect command
	move.l (A2),D0           // Manufacturer code / Device code
	move.w D1,(A2)           // Read/Reset command
	lea devices(PC),A3
loop_dev:
		tst.l (A3)
		beq no_dev
		cmp.l (A3),D0
		beq.s found_dev
		addq.l #8,A3
	bra.s loop_dev
no_dev:
	addq.l #4,SP
	moveq #-15,D0            // device error
	bra program_param_loop_end_2
found_dev:
	lea devices(PC),A1
	add.l 4(A1),A1           // sector of device
	movem.l (A1),A2-A4       // sector, flash_unlock1, flash_unlock2
	move.l MCF_FBCS_CSAR0,D5 // boot flash
	and.l #0xFFFF0000,D5
	add.l D5,A2              // base parameters	
	add.l D6,A2              // offset free block
	add.l D5,A3              // base parameters (last sector)
	add.l D5,A4
	tst.w D7
	beq.s erase_sector_end
	move.w #CMD_SECTOR_ERASE1,D5
	move.w #CMD_SECTOR_ERASE2,D6
	move.w D3,(A3)           // unlock
	move.w D4,(A4)
	move.w D5,(A3)
	move.w D3,(A3)           // unlock
	move.w D4,(A4)
	move.w D6,(A2)           // Erase sector command
wait_erase_loop:
		move.w (A2),D0
		btst #7,D0
		bne.s erase_sector_end
	btst #5,D0
	beq.s wait_erase_loop
	move.w (A2),D0
	btst #7,D0
	bne.s erase_sector_end
	addq.l #4,SP
	moveq #-10,D0            // write error
	bra program_param_loop_end
erase_sector_end:
	lea -MAX_PARAM_FLASH*4(A6),A0   // buffer
	move.w #CMD_PROGRAM,D5
	moveq #(MAX_PARAM_FLASH*2)-1,D6 // word counter
program_byte_loop:
		moveq #15,D7       // retry counter
program_byte_retry:
			move.w D3,(A3)  // unlock
			move.w D4,(A4)
			move.w D5,(A3)  // Byte program command
			move.w (A0),D0
			move.w D0,(A2)
			and.l #0x80,D0
wait_program_loop:
				move.w (A2),D1
				eor.l D0,D1
				btst #7,D1
				beq.s wait_program_loop_end
			btst #5,D1       // error
			beq.s wait_program_loop
			move.w (A2),D1
			eor.l D0,D1
			btst #7,D1
			beq.s wait_program_loop_end
program_byte_error:
		subq.l #1,D7
		bpl.s program_byte_retry
		addq.l #4,SP
		moveq #-10,D0        // write error
		bra.s program_param_loop_end
wait_program_loop_end:
		move.w (A2),D1
		cmp.w (A0),D1
		bne.s program_byte_error
		addq.l #2,A2
		addq.l #2,A0
	subq.l #1,D6
	bpl program_byte_loop
	move.l (SP)+,D0
program_param_loop_end:
	move.w #CMD_READ,D5
	move.w D3,(A3)
	move.w D4,(A4)
	move.w D5,(A3)           // Read/Reset command
program_param_loop_end_2:
	move.l MCF_FBCS_CSMR0,D3
	or.l #MCF_FBCS_CSMR_WP,D3 // protect flash
	move.l D3,MCF_FBCS_CSMR0
	rts
	
devices:
	dc.l 0x00C222CB, mx_29lv640-devices
	dc.l 0

mx_29lv640:	
	dc.l FLASH_TOS_FIRE_ENGINE-BOOT_FLASH_BASE+FLASH_SIZE-PARAM_SIZE /* bottom boot block */
	dc.l FLASH_UNLOCK1, FLASH_UNLOCK2

#else /* MCF548X - M5484LITE */

	move.l D2,-(SP)          // save value
	lea devices(PC),A1
	add.l 4(A1),A1           // sector of device
	move.l MCF_SIU_JTAGID,D0 // check the processor (not a good method => must check the flash device !)
	and.l #MCF_SIU_JTAGID_PROCESSOR,D0
	cmp.l #MCF_SIU_JTAGID_MCF5485,D0
             beq.s .m5485evb          // M5485EVB  16F160C3
	lea devices(PC),A1       // M5484LITE 28F320C3
	add.l 4+8(A1),A1         // sector of device
.m5485evb:
	movem.l (A1),A2-A4       // sector, flash_unlock1, flash_unlock2
	move.l MCF_FBCS_CSAR0,D3 // boot flash
	and.l #0xFFFF0000,D3
	add.l D3,A2              // base parameters	
	add.l D6,A2              // offset free block
	add.l D3,A3              // base parameters (last sector)
	move.w #CMD_UNLOCK1,(A3)
	move.w #CMD_UNLOCK2,(A3)
	tst.w D7
	beq.s erase_sector_end
	move.w #CMD_SECTOR_ERASE1,(A3)
	move.w #CMD_SECTOR_ERASE2,(A3) // Erase sector command
wait_erase_loop:
		move.w #CMD_STATUS,(A3)
		move.w (A3),D0
	btst #7,D0
	beq.s wait_erase_loop
	move.w #CMD_READ,(A3)
erase_sector_end:
	lea -MAX_PARAM_FLASH*4(A6),A0   // buffer
	moveq #(MAX_PARAM_FLASH*2)-1,D6 // word counter
program_byte_loop:
		move.w #CMD_PROGRAM,(A2)  // Byte program command
		move.w (A0),(A2)
wait_program_loop:
			move.w #CMD_STATUS,(A2)
			move.w (A2),D0
		btst #7,D0
		beq.s wait_program_loop
		move.w #CMD_READ,(A2)
		move.w (A2),D0
		cmp.w (A0),D0
		beq.s program_byte_ok
		addq.l #4,SP
		moveq #-10,D0      // write error
		bra.s program_param_loop_end		
program_byte_ok:
		addq.l #2,A2
		addq.l #2,A0
	subq.l #1,D6
	bpl.s program_byte_loop
	move.l (SP)+,D0
program_param_loop_end:
	move.w #CMD_LOCK1,(A3)
	move.w #CMD_LOCK2,(A3)
	move.w #CMD_READ,(A3)
	rts
	
devices:
	dc.l 0x008988C2, intel_28f160c3b-devices // M5485EVB
	dc.l 0x008988C4, intel_28f320c3b-devices // M5484LITE
	dc.l 0

intel_28f160c3b:
	dc.l FLASH_TOS_FIRE_ENGINE-BOOT_FLASH_BASE+FLASH_SIZE-PARAM_SIZE
	dc.l FLASH_UNLOCK1, FLASH_UNLOCK2
	
intel_28f320c3b:
	dc.l FLASH_TOS_FIRE_ENGINE-BOOT_FLASH_BASE+FLASH_SIZE-PARAM_SIZE
	dc.l FLASH_UNLOCK1, FLASH_UNLOCK2

#endif /* MCF547X */
#endif /* MCF5445X */

#else /* ATARI - CT60 */

ct60_rw_param: // D0.W: mode, D1.L: type_param, D2.L: value	

	movem.l D1-A5,-(SP)
	link A6,#-MAX_PARAM_FLASH*4 
	tst.l D1
	bmi out_param     
	cmp.l #MAX_PARAM_FLASH-1,D1 // type_param
	bcc out_param
	addq.l #1,D1
	asl.l #2,D1              // param * 4
	lea FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0xFF000000,A2
	moveq #-1,D3
	move.l #NB_BLOCK_PARAM-1,D4
	moveq #0,D6
find_last_block:
		cmp.l (A2),D3
		beq.s test_free_block
next_block:
		lea SIZE_BLOCK_PARAM(A2),A2
		add.l #SIZE_BLOCK_PARAM,D6 // offset free block
	dbf D4,find_last_block
	moveq #0,D6              // offset free block
	lea -SIZE_BLOCK_PARAM(A2),A2
	moveq #-1,D7             // erase sector if writing
	bra.s test_read
test_free_block:
	lea 4(A2),A3
	moveq #MAX_PARAM_FLASH-2,D5
loop_test_free_block:
		cmp.l (A3)+,D3
	dbne D5,loop_test_free_block
	bne.s next_block 
	moveq #0,D7              // writing inside the next block
	tst.l D6
	beq.s test_read          // 1st block is free block
	lea -SIZE_BLOCK_PARAM(A2),A2
test_read:
	and #1,D0                // mode
	beq read_param
	move.l (A2,D1.l),D0
	cmp.l D0,D2
	beq end_param            // no change	
	lea -MAX_PARAM_FLASH*4(A6),A3
	addq.l #4,A2
	clr.l (A3)+              // block used
	moveq #MAX_PARAM_FLASH-2,D0
save_param:
		move.l (A2)+,(A3)+   // save params in the stack	
	dbf D0,save_param        // before erase sector command
	move.l D2,-MAX_PARAM_FLASH*4(A6,D1.l) // value
//	move.w SR,-(SP)
//	or #0x700,SR             // lock interrupts
	bsr ct60_write_param     // since boot 2.0 TOS run always in RAM so it's possible to write flash without run flasher in RAM and lock interrupts
//	move.w (SP)+,SR
	bra.s end_param
read_param:
	move.l (A2,D1.l),D0
	bra.s end_param
out_param:
	moveq #-5,D0             // unimplemented opcode
end_param:
	unlk A6
	movem.l (SP)+,D1-A5
	rts

ct60_write_param:
	
	moveq #3,D3
	movec.l D3,SFC           // CPU space 3
	movec.l D3,DFC
	move.l D2,-(SP)          // save value
	lea FLASH_UNLOCK1+0xFF000000,A0
	lea FLASH_UNLOCK2+0xFF000000,A1
	lea FLASH_ADR+FLASH_SIZE-PARAM_SIZE+0xFF000000,A2
	move.w #CMD_UNLOCK1,D3
	move.w #CMD_UNLOCK2,D4
	move.w #CMD_AUTOSELECT,D5
	move.w #CMD_READ,D1
	moves.w D3,(A0)          // unlock
	moves.w D4,(A1)
	moves.w D5,(A0)          // Autoselect command
	move.l (A2),D0           // Manufacturer code / Device code
	moves.w D1,(A2)          // Read/Reset command
	lea devices(PC),A3
loop_dev:
		tst.l (A3)
		beq no_dev
		cmp.l (A3),D0
		beq.s found_dev
		addq.l #8,A3
	bra.s loop_dev
no_dev:
	addq.l #4,SP
	moveq #-15,D0            // device error
	bra program_param_loop_end_2
found_dev:
	lea devices(PC),A1
	add.l 4(A3),A1           // sector of device
	movem.l (A1),A2-A4       // sector, flash_unlock1, flash_unlock2
	add.l D6,A2              // offset free block
	tst.w D7
	beq.s erase_sector_end
	move.w #CMD_SECTOR_ERASE1,D5
	move.w #CMD_SECTOR_ERASE2,D6
	moves.w D3,(A3)          // unlock
	moves.w D4,(A4)
	moves.w D5,(A3)
	moves.w D3,(A3)          // unlock
	moves.w D4,(A4)
	moves.w D6,(A2)          // Erase sector command
wait_erase_loop:
		move.w (A2),D0
		btst #7,D0
		bne.s erase_sector_end
	btst #5,D0
	beq.s wait_erase_loop
	move.w (A2),D0
	btst #7,D0
	bne.s erase_sector_end
	addq.l #4,SP
	moveq #-10,D0            // write error
	bra.s program_param_loop_end
erase_sector_end:
	lea -MAX_PARAM_FLASH*4(A6),A0   // buffer
	move.w #CMD_PROGRAM,D5
	moveq #(MAX_PARAM_FLASH*2)-1,D6 // word counter
program_byte_loop:
		moveq #15,D7         // retry counter
program_byte_retry:
			moves.w D3,(A3)  // unlock
			moves.w D4,(A4)
			moves.w D5,(A3)  // Byte program command
			move.w (A0),D0
			moves.w D0,(A2)
			and.b #0x80,D0
wait_program_loop:
				move.w (A2),D1
				eor.b D0,D1
				bpl.s wait_program_loop_end
			btst #5,D1       // error
			beq.s wait_program_loop
			move.w (A2),D1
			eor.b D0,D1
			bpl.s wait_program_loop_end
program_byte_error:
		dbf D7,program_byte_retry
		addq.l #4,SP
		moveq #-10,D0        // write error
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
	moves.w D5,(A3)          // Read/Reset command
program_param_loop_end_2:
	rts
	
devices:
	dc.l 0x000422AB, fujitsu_mbm29f400bc-devices
	dc.l 0x00042258, fujitsu_mbm29f800ba-devices
	dc.l 0x00012258, amd_am29f800bb-devices
	dc.l 0x00202258, st_m29f800db-devices
	dc.l 0
	
fujitsu_mbm29f400bc:
	dc.l FLASH_ADR+0xFF0F0000, FLASH_UNLOCK1+0xFF000000, FLASH_UNLOCK2+0xFF000000

fujitsu_mbm29f800ba:
amd_am29f800bb:
st_m29f800db:
	dc.l FLASH_ADR+0xFF0F0000, FLASH_UNLOCK1+0xFF000000, FLASH_UNLOCK2+0xFF000000	

end_ct60_write_param:

#endif /* COLDFIRE */

	.chip 68060

init_flash_parameters:

	moveq #14,D7
.loop_init_params:
		moveq #-1,D2
		move.l D7,D1
		moveq #CT60_MODE_WRITE,D0
#ifdef COLDFIRE
		bsr fire_rw_param
#else
		bsr ct60_rw_param
#endif
		cmp.l #-1,D0
	dblt D7,.loop_init_params
	jmp 0xE0398C             // reset NVM

