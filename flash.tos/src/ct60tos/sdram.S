/*  Configure the CT60-SDRAM and more
 * 
 * Didier Mequignon 2001-2004, e-mail: aniplay@wanadoo.fr
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
	.text
 
	.globl init_060
	.globl init_sdram
	.globl add_sdram
	.globl boot_drive
	.globl menu_boot
	.globl init_flash_parameters
	.globl fix_bug_nvdi
	.globl display_ram_test
	.globl ct60_read_info_sdram
	.globl ct60_configure_sdram

#include "main.h"
#include "ct60.h"
#include "vars.h"

// #define DEBUG

// #define RESET // removed because not works with some motherboards/SDR60 versions
#define XFRB_SIZE 0x10000
#define SPEED_BUFFER_SIZE 0x10000 // mini 512 bytes
#define CT60_COOKIE_SIZE 256
#define DEFAULT_BOOT_DELAY 800 // 4 seconds
#define TIME_OUT_CMD 200       // 1 second
#define TIME_OUT_4S 800
#define TIME_OUT_10S 2000

#define rw_parameter 0xc60b
	
#define SLAVE_ADRESS            0xA0 // 7 bits 1010xxx + r/w

#define CT60_READ_ERROR         -1
#define CT60_CHIP_DENSITY_ERROR -2
#define CT60_NUM_BANK_ERROR     -3
#define CT60_MOD_DENSITY_ERROR  -4
#define CT60_BURST_LENGTH_ERROR -5
#define CT60_DATA_WIDTH_ERROR   -6
#define CT60_VOLTAGE_ERROR      -7
#define CT60_SDRAM_TYPE_ERROR   -8
#define CT60_REFRESH_RATE_ERROR -9

#define _gpip_mfp 0xfffffa01
#define _ddr_mfp  0xfffffa05
#define _iera_mfp 0xfffffa07      // MFP registers
#define _ipra_mfp 0xfffffa0b
#define _isra_mfp 0xfffffa0f
#define _imra_mfp 0xfffffa13
#define _tbcr_mfp 0xfffffa1b
#define _tbdr_mfp 0xfffffa21      // timer B
#define _tcdr_mfp 0xfffffa23      // timer C
#define _scl_low 0xf0000000       // write 0 to SCL line (clock)
#define _scl_high 0xf0400000      // write 1 to SCL line (clock)
#define _sda_low 0xf0800000       // write 0 to SDA line (data)
#define _sda_high 0xf0c00000      // write 1 to SDA line (data) 
#define _sda 0xf0000000           // read from SDA line on the D0 CPU data bus
#define _sdcnf 0xf2000000         // SDRAM configuration 0xf2xx0000 

#define  WAIT_US bsr wait_26us  

init_060:

	move.w #0x2700,SR
#ifdef RESET
	move.w 0xFFFF8006,D0
	reset
#endif
	move.w 0xFFFF8006,D0
	move.w #7,0xFFFF8940	
	movec.l PCR,D0
	bclr #1,D0               // enable PFU
	bset #0,D0               // superscalar
	movec.l D0,PCR
	moveq #0,D0
	movec.l D0,VBR
	movec.l D0,CACR
	cinva BC
	pflusha
	move.l #0x00000108,D0    // default zone in copyback for 68060 EC
	movec.l D0,TCR
	move.l #0x0000E000,D0    // zone at $00000000 to $00FFFFFF in writethrough for 68060 EC
	movec.l D0,DTT1
	movec.l D0,ITT1
	move.l #0x807FE040,D0    // excepted external CI signal =>  cache inhibit imprecise
	                         // and the zone $80000000-$FFFFFFFF in cache inhibit precise
	movec.l D0,DTT0
	movec.l D0,ITT0
	cmp.l #0xFA52235F,0x00FA0000
	bne.s .no_cartrige
	lea .no_cartrige(PC),A6
	jmp 0x00FA0004
.no_cartrige:
	move.w #0x20,0xFFFF828C
	move.w #0x10,0xFFFF8282
	or.b #0x21,0xFFFF8007
	btst #6,0xFFFF8007
	beq .end_init_060
	lea .ret(PC),A6
	jmp 0x00E00C1C
.ret:
	bne .end_init_060
	move.b memctrl,0xFFFF8001 // config STRAM
	cmp.l #0x31415926,resvalid
	bne .end_init_060
	move.l resvector,D0
	btst #0,D0
	bne .end_init_060
	cmp.l #0x1357BD13,ramvalid
	bne .not_sdram_found
	lea _sdcnf,A0
	moveq #0,D0
	move.b memctrl+1,D0      // config SDRAM saved A23-A16
	swap D0
	add.l D0,A0
	clr.l (A0)               // config SDRAM
	move.l resvector,A0
	cmp.l #0x01000000,A0     // base SDRAM
	beq .end_init_060
.not_sdram_found:
	cmp.l #0x31415926,resvalid
	bne .end_init_060
	move.l resvector,D0
	btst #0,D0
	bne .end_init_060
	move.l D0,A0
	lea .not_sdram_found(PC),A6
	jmp (A0)                 // resvector
.end_init_060:
	jmp 0x00E000C8

init_sdram:

	movem.l D1-A6,-(SP)
	bclr #5,0xFFFFFA07       // mask timer A
	move.w SR,-(SP)
	or #0x700,SR             // no interrupts
	cpusha BC
	move.l #0xA0808000,D0    // caches on
	movec.l D0,CACR
	move.w (SP)+,SR
	move.l #0x00E00FB6,8     // set access fault vector
	move.b 0xFFFF8006,D0
	lsr.b #6,D0              // 0:ST nomo, 1:ST col, 2:VGA, 3:TV
	cmp.b #2,D0              // VGA
	beq.s .ok_screen
	move.l #0x5F465251,D0    // _FRQ cookie, internal clock
	bsr get_cookie
	cmp.l #32,D0
	bls.s .ok_screen
	move.l #0x5F465245,D0    // _FRE cookie, external clock
	bsr get_cookie
	cmp.l #32,D0
	bne.s .ok_screen
	bset #0,0xFFFF820A       // external clock
.ok_screen:	
	clr.l -(SP)
	move.l #CT60_BLITTER_SPEED,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	btst #0,D0
	beq.s .blitter_slow
	bset #2,0xFFFF8007       // blitter 16 MHz
.blitter_slow:
	lea spaces(PC),A0
	bsr display_string_single
	lea message0(PC),A0
	cmp.w #2,0x3E86          // number of planes
	bhi.s .title_colors
	lea message0b(PC),A0
.title_colors:
	bsr display_string_single
	lea spaces(PC),A0
	bsr display_string_single
	movec.l PCR,D0
	swap D0
	lea message8(PC),A0      // 68060
	cmp.w #0x0430,D0
	beq.s .full_060
	lea message9(PC),A0
	cmp.w #0x0431,D0
	beq.s .ec_lc_060
	lea message10(PC),A0
.full_060:
.ec_lc_060:
	bsr display_string
	clr.w D0
	swap D0
	lsr.w #8,D0              // revision
	divu #10,D0
	and.w #7,D0
	beq.s .rev_less_10
	or.w #0x30,D0
	bsr display_char
.rev_less_10:
	swap d0
	or.w #0x30,D0
	bsr display_char
	movec.l PCR,D0
	move.l D0,D1
	lsr.l #8,D1
	lea message11(PC),A0
	and.w #0x1FF,D1
	beq.s .display_mask      // revision 0, mask D00W/D11W
	lea message13(PC),A0
	cmp.w #2,D1              // revision 2, mask F84W
	beq.s .display_mask
	lea message14(PC),A0	
	cmp.w #1,D1              // revision 1, mask F43G/G65V 
	bhi.s .display_mask      // revision 3 and more, mask E41J ?
	bset #5,D0               // disable store/load bypass
	movec.l D0,PCR
	lea message12(PC),A0
.display_mask:
	btst #8,D1
	bne.s .mask_060_ok       // mask info only for 060 full
	bsr display_string
.mask_060_ok:
	move.w SR,-(SP)
	move.w #0x2500,SR
	moveq #0,D0
	move.l _hz_200,D1
.sync_timer:
	cmp.l _hz_200,D1
	beq.s .sync_timer
	moveq #9,D2
.next_mes:
		move.l _hz_200,D1
		moveq #0,D3
.loop_mes:
		addq.l #1,D3
		cmp.l _hz_200,D1
		beq.s .loop_mes
		cmp.l D0,D3
		bcs.s .not_maxi
		move.l D3,D0
.not_maxi:
	dbf D2,.next_mes
	move.w (SP)+,SR
	divu #250,D0             // MHz * 10
	swap D0
	tst.w D0
	beq.s .end_mes
	add.l #0x10000,D0
.end_mes:
	clr.w D0
	swap D0
	link A6,#-6
	move.l D0,-4(A6)
	move.l #0x43543630,D0    // CT60
	bsr get_cookie
	move.l A0,D0
	beq.s .no_cookie_ct60
	move.l -4(A6),4(A0)      // value
.no_cookie_ct60:
	move.l -4(A6),D0
	clr.w -2(A6)
             cmp.w #1000,D0
             bcs.s .low_100
             move.l D0,-(SP)
             moveq #0x20,D0
             bsr display_char
             move.l (SP)+,D0
.low_100:     
	lea -6(A6),A0
	moveq #4,D1
	bsr conv_ascii_value
	move.b -3(A6),-2(A6)
	move.b #0x2E,-3(A6)
	bsr display_string_single
	unlk A6
	lea message18(PC),A0     // MHz
	bsr display_string_single
	link A6,#-48
	pea -48(A6)              // buffer
	move.w #48,-(SP)         // size
	clr.w -(SP)              // start
	clr.w -(SP)              // read
	move.w #46,-(SP)         // NVMaccess
	trap #14
	lea 12(SP),SP
	lea -48(A6),A0           // buffer
	movem.l 32(A0),D3/D4     // ABE code, SDR code
	unlk A6
	move.l D3,D0
	move.l D4,D1
	and.l #0xFF000000,D0
	and.l #0xFF000000,D1
	cmp.l #0x41000000,D0
	beq.s .code_hard
	cmp.l #0x53000000,D1
	bne .no_code
.code_hard:
	cmp.l #0x41000000,D0
	bne.s .no_abe_code
	clr.l -(SP)
	move.l #CT60_ABE_CODE,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP 
	cmp.l D0,D3
	beq.s .no_abe_code
	move.l D3,-(SP)
	move.l #CT60_ABE_CODE,-(SP)
	move.w #CT60_MODE_WRITE,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP 
.no_abe_code:
	move.l D4,D1
	and.l #0xFF000000,D1
	cmp.l #0x53000000,D1
	bne.s .no_code
	clr.l -(SP)
	move.l #CT60_SDR_CODE,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP 
	cmp.l D0,D4
	beq.s .no_code
	move.l D4,-(SP)
	move.l #CT60_SDR_CODE,-(SP)
	move.w #CT60_MODE_WRITE,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP 
.no_code:
	clr.l -(SP)
	move.l #CT60_ABE_CODE,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	move.l D0,D3 
	clr.l -(SP)
	move.l #CT60_SDR_CODE,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	move.l D0,D4
	move.l D3,D0
	move.l D4,D1
	and.l #0xFF000000,D0
	and.l #0xFF000000,D1
	cmp.l #0x41000000,D0
	beq.s .code_hard_display
	cmp.l #0x53000000,D1
	bne.s .no_code_display
.code_hard_display:
	lea message38(PC),A0
	bsr display_string_single
	cmp.l #0x41000000,D0
	bne.s .no_abe_code_display
	lea message39(PC),A0
	bsr display_string_single
	move.w D3,D0
	lsr.w #8,D0
	bsr display_char
	move.w D3,D0
	and.w #0xFF,D0
	bsr display_char
.no_abe_code_display:
	cmp.l #0x53000000,D1
	bne.s .no_code_display
	lea message40(PC),A0
	bsr display_string_single
	move.w D4,D0
	lsr.w #8,D0
	bsr display_char
	move.w D4,D0
	and.w #0xFF,D0
	bsr display_char
.no_code_display:
	lea crlf(PC),A0
	bsr display_string_single
	clr.l ramtop
	clr.l ramvalid
	move.l phystop,D0
	sub.l _memtop,D0
	cmp.l #RESERVE_MEM,D0
	beq .init_mmu            // pmmu tree in STRAM & no SDRAM
	bsr ct60_configure_sdram
	tst.l d0
	bpl .ok_sdram
	move.w D0,D1
	lea error9(PC),A0
	cmp.w #CT60_REFRESH_RATE_ERROR,D1
	beq.s .error_sdram
	lea error8(PC),A0
	cmp.w #CT60_SDRAM_TYPE_ERROR,D1
	beq.s .error_sdram
	lea error7(PC),A0	
	cmp.w #CT60_VOLTAGE_ERROR,D1
	beq.s .error_sdram
	lea error6(PC),A0	
	cmp.w #CT60_DATA_WIDTH_ERROR,D1
	beq.s .error_sdram
	lea error5(PC),A0	
	cmp.w #CT60_BURST_LENGTH_ERROR,D1
	beq.s .error_sdram
	lea error4(PC),A0	
	cmp.w #CT60_MOD_DENSITY_ERROR,D1
	beq.s .error_sdram
	lea error3(PC),A0	
	cmp.w #CT60_NUM_BANK_ERROR,D1
	beq.s .error_sdram
	lea error2(PC),A0	
	cmp.w #CT60_CHIP_DENSITY_ERROR,D1
	beq.s .error_sdram
	lea error1(PC),A0	
.error_sdram:
	move.l A0,-(SP)
	lea crlf_spaces(PC),A0
	bsr display_string_single
	move.l (SP)+,A0
	bsr display_string
.error_sdram2:
	move.w #7,-(SP)          // Crawcin
	trap #1
	addq.w #2,SP
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
	bsr display_char
	bsr display_infos_sdram
.halt_no_sdram:
	bra.s .halt_no_sdram
.ok_sdram:
	move.l D0,D4
	add.w #26,D0             // size 0-3 for 64MB-512MB
	moveq #0,D5
	bset D0,D5
	lea crlf_spaces(PC),A0
	bsr display_string_single
	lea message1(PC),A0
	bsr display_string_single
	lea message5(PC),A0
	cmp.w #3,D4
	beq.s .ok_sdram2
	lea message4(PC),A0
	cmp.w #2,D4
	beq.s .ok_sdram2
	lea message3(PC),A0
	cmp.w #1,D4
	beq.s .ok_sdram2
	lea message2(PC),A0
.ok_sdram2:
	bsr display_string_single
	lea message6(PC),A0
	bsr display_string
	lea 0x1000000,A0
	move.l A0,A1
	add.l D5,A1              // end SDRAM
	move.l #0x01234567,D0
	move.l #0x89ABCDEF,D1
.loop_sdram_write:
		movem.l D0-D1,(A0)       // long
		movem.w D0-D1,8(A0)      // word
		move.b D0,12(A0)         // byte
		rol.l #3,D0
		rol.l #3,D1
		add.l #0x2000,A0         // 8K step
	cmp.l A1,A0
	bcs.s .loop_sdram_write
	lea 0x1000000,A0
	move.l #0x01234567,D0
	move.l #0x89ABCDEF,D1
	cpusha BC                // flush
.loop_sdram_test:
		movem.l (A0),D2-D3
		cmp.l D0,D2
		bne.s .error_test
		cmp.l D1,D3
		bne.s .error_test
		movem.w 8(A0),D2-D3
		cmp.w D0,D2
		bne.s .error_test
		cmp.w D1,D3
		bne.s .error_test
		cmp.b 12(A0),D0
		bne.s .error_test
		rol.l #3,D0
		rol.l #3,D1
		add.l #0x2000,A0         // 8K step
	cmp.l A1,A0
	bcs.s .loop_sdram_test
	moveq #18,D0             // CAS laytency
	bsr read_i2c_sdram
	bmi.s .test_ok           // error
	btst #1,D0               // CAS latency = 2
	bne.s .test_ok
	moveq #9,D0              // cycle time
	bsr read_i2c_sdram
	bmi .test_ok             // error
	cmp.b #0x70,D0
	bls.s .test_ok           // PC150
	lea message54(PC),A0     // warning CAS latency
	bsr display_string
 	bra.s .test_ok
 .error_test:
	move.l A0,-(SP)
	lea error10(PC),A0
	bsr display_string
	move.l (SP)+,D0
	bsr hex_long
	moveq #6,D0              // module data width
	bsr read_i2c_sdram
	bmi .error_sdram2        // error
	cmp.w #0x40,D0           // 64
	beq.s .data_width_ok
	lea message55(PC),A0
	bsr display_string
	bra .error_sdram2
.data_width_ok:
	moveq #18,D0             // CAS laytency
	bsr read_i2c_sdram
	bmi .error_sdram2        // error
	btst #1,D0               // CAS latency = 2
	bne .error_sdram2
	lea message54(PC),A0
	bsr display_string
	bra .error_sdram2
.test_ok:
	add.l #0x01000000,D5
	move.l D5,ramtop
	move.l #0x1357BD13,ramvalid
.init_mmu:
	moveq #0,D7
	movec.l PCR,D0
	btst #16,D0
	bne.s .end_sdram         // EC or LC
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D0
	and.b #0xF,D0
	cmp.b #0x6,D0            // CTRL-LSHIFT
	beq.s .end_sdram
	lea _init_mmu_tree,A0
	add.l #0xE80000,A0
	sub.l #_ct60tos_half_flash,A0
	jsr (A0)
	tst.l D0
	beq.s .end_sdram
	lea message51(PC),A0     // TOS in RAM
	bsr display_string
	moveq #-1,D7
.end_sdram:
	clr.l -(SP)
	move.l #CT60_SAVE_NVRAM_1,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	swap D0
	cmp.w #0x4E56,D0         // NV magic code
	bne .no_nvm_read_saved
	lea crlf_spaces(PC),A0
             tst.w d7
             beq .no_tos_in_ram
	lea separator(PC),A0
.no_tos_in_ram:
	bsr display_string_single
	lea message51b(PC),A0    // NVRAM restored
	bsr display_string
.no_nvm_read_saved:
	lea crlf(PC),A0
	bsr display_string_single
	movem.l (SP)+,D1-A6
	rts

display_infos_sdram:

	movem.l D0-D2/A0-A1,-(SP)
	link A6,#-134
	clr.w -130(A6)
	lea -128(A6),A0
	bsr ct60_read_info_sdram
	bmi .error_eeprom_sdram
	lea -128(A6),A1
	lea message20(PC),A0     // type
	bsr display_string
	moveq #0,D0
	move.b 2(A1),D0
	lea -133(A6),A0
             moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	cmp.b #4,2(A1)
	bne.s .no_sdram
	lea message20b(PC),A0
	bsr display_string_single
.no_sdram:	
	lea message21(PC),A0     // row
	bsr display_string
	moveq #0,D0
	move.b 3(A1),D0
	lea -133(A6),A0
             moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message22(PC),A0     // column
	bsr display_string
	moveq #0,D0
	move.b 4(A1),D0
	lea -133(A6),A0
             moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message23(PC),A0     // banks
	bsr display_string
	moveq #0,D0
	move.b 5(A1),D0
	lea -133(A6),A0
             moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message24(PC),A0     // data width
	bsr display_string
	moveq #0,D0
	move.w 6(A1),D0
	ror.w #8,D0
	lea -134(A6),A0
             moveq #4,D1
	bsr conv_ascii_value_optimized
	lea -134(A6),A0
	bsr display_string_single
	lea message24b(PC),A0
	bsr display_string_single
	lea message25(PC),A0     // voltage
	bsr display_string
	moveq #0,D0
	move.b 8(A1),D0
	lea -133(A6),A0
             moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	cmp.b #1,8(A1)
	bne.s .not_lvttl
	lea message25b(PC),A0
	bsr display_string_single
.not_lvttl:	
	lea message26(PC),A0     // cycle time
	bsr display_string
	move.b 9(A1),D0
	bsr display_value_ns_10
	lea message73(PC),A0
	cmp.b #0xA0,9(A1)
	bcc.s .pc100
	lea message74(PC),A0
.pc100:
	bsr display_string_single
	lea message27(PC),A0     // access from clock
	bsr display_string
	move.b 10(A1),D0
	bsr display_value_ns_10
	lea message28(PC),A0     // configuration type
	bsr display_string
	moveq #0,D0
	move.b 11(A1),D0
	lea -133(A6),A0
             moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message60(PC),A0
	move.b 11(A1),D0
	beq.s .parity
	lea message61(PC),A0
	cmp.b #1,D0
	beq.s .parity
	lea message62(PC),A0
	cmp.b #2,D0
	bne.s .no_ecc	
.parity:
	bsr display_string
.no_ecc:	
	lea message29(PC),A0     // refresh
	bsr display_string
	lea message63(PC),A0
	move.b 12(A1),D0
	and.b #0x7F,D0
	beq.s .refresh_rate
	lea message64(PC),A0
	cmp.b #1,D0
	beq.s .refresh_rate
	lea message65(PC),A0
	cmp.b #2,D0
	beq.s .refresh_rate
	lea message66(PC),A0
	cmp.b #3,D0
	beq.s .refresh_rate
	lea message67(PC),A0
	cmp.b #4,D0
	beq.s .refresh_rate
	lea message68(PC),A0
	cmp.b #5,D0
	bne.s .no_refresh_rate	
.refresh_rate:
	bsr display_string_single
	tst.b 12(A1)
	bpl.s .no_refresh_rate
	lea message71(PC),A0
	bsr display_string_single
	bra.s .end_refresh_rate
.no_refresh_rate:
	moveq #0x24,D0
	bsr display_char
	move.b 12(A1),D0
	bsr hex_byte		
.end_refresh_rate:
	lea message30(PC),A0     // banks device
	bsr display_string
	moveq #0,D0
	move.b 17(A1),D0
	lea -133(A6),A0
             moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message53(PC),A0     // CAS latency
	bsr display_string
	move.b 18(A1),D0
	add.b D0,D0
	bsr display_latency
	lea message56(PC),A0     // CS latency
	bsr display_string
	move.b 19(A1),D0
	bsr display_latency
	lea message57(PC),A0     // WE latency
	bsr display_string
	move.b 20(A1),D0
	bsr display_latency	
	lea message37(PC),A0     // module attributes
	bsr display_string
	move.b 21(A1),D0
	bsr hex_byte
	tst.b 21(A1)
	bne.s .not_unbuffered
	lea message72(PC),A0
	bsr display_string
.not_unbuffered:	
	lea message31(PC),A0     // precharge time
	bsr display_string
	move.b 27(A1),D0
	bsr display_value_ns
	lea message32(PC),A0     // minimum row active
	bsr display_string
	move.b 28(A1),D0
	bsr display_value_ns
	lea message33(PC),A0     // minimum RAS to CAS delay
	bsr display_string
	move.b 29(A1),D0
	bsr display_value_ns
	lea message70(PC),A0     // minimum RAS pulse width
	bsr display_string
	move.b 30(A1),D0
	bsr display_value_ns
	lea message34(PC),A0     // bank density
	bsr display_string
	moveq #0,D0
	move.b 31(A1),D0
	asl.w #2,D0
	lea -134(A6),A0
             moveq #4,D1
	bsr conv_ascii_value_optimized
	lea -134(A6),A0
	bsr display_string_single
	lea message69(PC),A0
	bsr display_string
	lea message35(PC),A0     // ID
	bsr display_string
	move.b 64(A1),D0
	bsr hex_byte
	moveq #0x20,D0
	bsr display_char
	lea list_manufacturers(PC),A0
.manufacturer_loop1:
		move.b (A0)+,D0
		beq.s .manufacturer_not_found
		cmp.b 64(A1),D0
		bne.s .next_manufacturer
		moveq #31,D1
		bra.s .manufacturer_loop2
.next_manufacturer:
		tst.b (A0)+
		bne.s .next_manufacturer
	bra.s .manufacturer_loop1
.manufacturer_not_found:
	lea 65(A1),A0            // manufacturer
	moveq #6,D1
.manufacturer_loop2:
		move.b (A0)+,D0
		beq.s .end_manufacturer
		cmp.b #0x20,D0
		bcs.s .end_manufacturer
		cmp.b #0x7F,D0
		bcc.s .end_manufacturer
		bsr display_char
	dbf D1,.manufacturer_loop2
.end_manufacturer:	
	lea message58(PC),A0     // part number
	bsr display_string
	lea 73(A1),A0
	moveq #17,D1
.part_number:
		move.b (A0)+,D0
		bsr display_char
	dbf D1,.part_number	
	lea message36(PC),A0     // date
	bsr display_string
	moveq #0,D0
	move.b 93(A1),D0         // week
	move.b D0,D1
	and.b 94(A1),D1
	cmp.b #0xFF,D1
	beq .no_date
	cmp.b #0x52,94(A1)       // week 52
	bls.s .date_jedec_format
	lea -132(A6),A0          // IBM format
             moveq #2,D1
	bsr conv_ascii_value_optimized
	lea -132(A6),A0          // date
	bsr display_string_single
	moveq #0x2F,D0
	bsr display_char
             moveq #2,D1
	bsr conv_ascii_value_optimized
	bsr display_string_single
	moveq #0,D0
	move.b 94(A1),D0         // year
	add.w #1900,D0
	lea -134(A6),A0
             moveq #4,D1
	bsr conv_ascii_value_optimized
	lea -134(A6),A0	
	bsr display_string_single
	bra.s .no_date
.date_jedec_format:
	move.b 94(A1),D0         // week
	bsr hex_byte
	moveq #0x2F,D0
	bsr display_char
	cmp.b #0x90,93(A1)       // year
	bcs.s .year_20xx
	moveq #0x31,D0
	bsr display_char
	moveq #0x39,D0
	bsr display_char         // 19xx
	bra.s .year
.year_20xx:
	moveq #0x32,D0
	bsr display_char
	moveq #0x30,D0
	bsr display_char         // 20xx	
.year:		
	move.b 93(A1),D0         // year	
	bsr hex_byte
.no_date:	
//	lea -128(A6),A1
//	moveq #7,D1
//	bsr dump
.error_eeprom_sdram:
	unlk A6
	movem.l (SP)+,D0-D2/A0-A1
	rts

#ifdef DEBUG
dump:
	movem.l D0-D2/A0-A1,-(SP)
.loop_dump1:
		lea crlf(PC),A0
		bsr display_string_single		
		moveq #15,D2
.loop_dump2:
			move.b (A1)+,D0
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
		dbf D2,.loop_dump2
		lea -16(A1),A1
		moveq #15,D2
.loop_dump3:
			move.b (A1)+,D0
			cmp.b #0x20,D0
			bcs.s .dump_bad_char
			cmp.b #0x7F,D0
			bcs.s .dump_ok
.dump_bad_char:
			moveq #0x2E,D0
.dump_ok:
			bsr display_char
		dbf D2,.loop_dump3
	dbf D1,.loop_dump1
	movem.l (SP)+,D0-D2/A0-A1
	rts
#endif

get_cookie:

	move.l D1,-(SP)
	move.l D0,D1
	move.l cookie,D0
	beq.s .cookie_not_found
	move.l D0,A0
.loop_cookie:
		tst.l (A0)
		beq.s .cookie_not_found
		cmp.l (A0),D1
		bne.s .next_cookie
		move.l 4(A0),D0
		bra.s .end_cookie
.next_cookie:
		addq.l #8,A0
	bra.s .loop_cookie
.cookie_not_found:
	moveq #0,D0
	move.l D0,A0
.end_cookie:
	move.l (SP)+,D1
	tst.l D0
	rts

error1:	.asciz "            SDRAM not found"
	.asciz "            SDRAM non trouv‚e"
error2:	.asciz "            SDRAM chip density error"
	.asciz "            SDRAM erreur densit‚ puces"
error3:	.asciz "            SDRAM number of banks error" 
	.asciz "            SDRAM erreur nombre de banques" 
error4:	.asciz "            SDRAM density error" 
	.asciz "            SDRAM erreur densit‚" 
error5:	.asciz "            SDRAM burst length error" 
	.asciz "            SDRAM erreur longueur burst" 
error6:	.asciz "            SDRAM data width error"
	.asciz "            SDRAM erreur largeur donn‚es"
error7:	.asciz "            SDRAM voltage error"
	.asciz "            SDRAM erreur tension"
error8:	.asciz "            SDRAM type error"
	.asciz "            SDRAM erreur type"
error9:	.asciz "            SDRAM refresh rate error"
	.asciz "            SDRAM refresh rate error"
error10:	.byte 13,10
	.asciz "            SDRAM read failure at $"
	.byte 13,10
	.asciz "            SDRAM erreur v‚rification en $"
name1:	.asciz "Eiffel"
message0:	.byte 0x1B,0x62,0x34,0x41
	.byte 0x1B,0x62,0x32,0x54
	.byte 0x1B,0x62,0x33,0x41
	.byte 0x1B,0x62,0x31,0x52
	.byte 0x1B,0x62,0x35,0x49,0x20
	.byte 0x1B,0x62,0x3F
	.ascii "FALCON/"
	.byte 0x1B,0x62,0x31
	.ascii "CT60"
	.byte 0x1B,0x62,0x3F
	.ascii " TOS4.04"
	.byte 13,10,0
message0b:	.ascii "ATARI FALCON/CT60 TOS4.04"
crlf:	.byte 13,10,0
separator:	.asciz ", "
crlf_spaces:	.byte 13,10
spaces:	.asciz "            "
message1:	.asciz "SDRAM "
message2:	.asciz "64"
message3:	.asciz "128"
message4:	.asciz "256"
message5:	.asciz "512"
message6:	.asciz "MB detected"
	.asciz "Mo d‚tect‚e" 
message8:	.asciz "68060 Rev."
	.asciz "68060 R‚v."
message9:	.asciz "68EC060 / 68LC060 Rev."
	.asciz "68EC060 / 68LC060 R‚v."
message10:	.asciz "unknown CPU "
	.asciz "CPU inconnu"
message11:	.asciz " Mask D00W/D11W" // revision 0
	.asciz " Masque D00W/D11W"
message12:	.asciz " Mask F43G/G65V" // revision 1
	.asciz " Masque F43G/G65V"
message13:	.asciz " Mask F84W"      // revision 2
	.asciz " Masque F84W"
message14:	.asciz " Mask E41J"      // revision 6 (3 -> 5 ?)
	.asciz " Masque E41J" 
message15:	.byte 27 
	.ascii "p Boot v"
	.byte ((VERSION/256) & 0xF) + 0x30
	.ascii "."
	.byte ((VERSION/16) & 0xF) + 0x30
	.byte (VERSION & 0xF) + 0x30
	.asciz "b "
message15b:	
	.ascii "2004 October "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.ascii "Octobre 2004 "
	.byte 27
	.ascii "q"
	.byte 13,10,0
message16:	.byte 13,10
	.asciz "Initialization SDRAM"
	.byte 13,10 
	.asciz "Initialisation SDRAM" 
message17:   .ascii "MB/S"
	.byte 13,10,0
	.ascii "Mo/S"
	.byte 13,10,0
message18:	.asciz "MHz"
message19:	.byte 13,10,27 
	.ascii "p SDRAM EEPROM DATA "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p SDRAM DONNEES EEPROM "
	.byte 27
	.ascii "q"
	.byte 13,10,0
message20:	.byte 13,10
	.asciz "Byte 2, Memory Type : "
	.byte 13,10
	.asciz "Octet 2, Type de m‚moire : "
message20b:	.asciz " SDRAM"
message21:	.byte 13,10
	.asciz "Byte 3, Number of Row Addresses : "
	.byte 13,10
	.asciz "Octet 3, Nombre de lignes d'adresses : "
message22:	.byte 13,10
	.asciz "Byte 4, Number of Column Addresses : "
	.byte 13,10
	.asciz "Octet 4, Nombre de colonnes d'adresses : "
message23:	.byte 13,10
	.asciz "Byte 5, Number of DIMM Banks : "
	.byte 13,10
	.asciz "Octet 5, Nombre de banques DIMM : "
message24:	.byte 13,10
	.asciz "Bytes 6-7, Module Data Width : "
	.byte 13,10
	.asciz "Octets 6-7, Largeur donn‚es module : "
message24b:	.asciz " bits"
message25:	.byte 13,10
	.asciz "Byte 8, Voltage Interface Level : "
	.byte 13,10
	.asciz "Octet 8, Niveau de tension interface : "
message25b:	.asciz " LVTTL"
message26:	.byte 13,10
	.asciz "Byte 9, SDRAM Cycle Time : "
	.byte 13,10
	.asciz "Octet 9, SDRAM Temps cycle : "
message27:	.byte 13,10
	.asciz "Byte 10, SDRAM Access from Clock : "
	.byte 13,10
	.asciz "Octet 10, SDRAM AccŠs de l'horloge : "
message28:	.byte 13,10
	.asciz "Byte 11, SDRAM Configuration Type : "
	.byte 13,10
	.asciz "Octet 11, SDRAM Type : "
message29:	.byte 13,10
	.asciz "Byte 12, Refresh Rate : "
	.byte 13,10
	.asciz "Octet 12, Fr‚quence rafraichissement : "
message30:	.byte 13,10
	.asciz "Byte 17, Number of Banks : "
	.byte 13,10
	.asciz "Octet 17, Nombre de banques : "
message31:	.byte 13,10
	.asciz "Byte 27, Minimum Row Precharge Time : "
	.byte 13,10
	.asciz "Octet 27, Temps de pr‚chage mini lignes : "
message32:	.byte 13,10
	.asciz "Byte 28, Minimum Row Active to Active Delay : "
	.byte 13,10
	.asciz "Octet 28, D‚lais mini entre activations de lignes : "
message33:	.byte 13,10
	.asciz "Byte 29, Minimum RAS to CAS Delay : "
	.byte 13,10
	.asciz "Octet 29, D‚lais mini entre RAS et CAS : "
message34:	.byte 13,10
	.asciz "Byte 31, Module Bank Density : "
	.byte 13,10
	.asciz "Octet 31, Densit‚ banque du module : "
message35:	.byte 13,10
	.asciz "Bytes 64-71, Module Manufacturers ID : $"
	.byte 13,10
	.asciz "Octets 64-71, ID fabriquant du module : $"
message36:	.byte 13,10
	.asciz "Bytes 93-94, Module Manufacturing Date : "
	.byte 13,10
	.asciz "Octets 93-94, Date de fabrication du module : "
message37:	.byte 13,10
	.asciz "Byte 21, SDRAM Module Attributes : $" 
	.byte 13,10
	.asciz "Octet 21, Attributs du module : $" 
message38:	.byte 13,10
	.asciz "            CT60 hardware"
message39:	.asciz " ABEv"
message40:	.asciz " SDRv"
message41:	.byte 13,10
	.asciz "SCSI "
message42:	.byte 13,10
	.asciz "IDE  "
message43:	.asciz " ... "
message44:	.asciz "no answer"
	.asciz "pas de r‚ponse"
message45:	.asciz "error"
	.asciz "erreur"
message46:	.asciz "read error"
	.asciz "erreur lecture"
message47:	.asciz "no boot found"
	.asciz "boot non trouv‚"
message48:	.asciz "boot in progress"
	.asciz "boot en cours"
message49:	.asciz " -> "
message50:	.asciz "no XBRA"
	.asciz "pas de XBRA"
message51:	.byte 13,10
//	.asciz "            TOS copied to SDRAM (0-1FFF E00000-EEFFFF)"
	.asciz "            TOS copied to SDRAM"
	.byte 13,10
//	.asciz "            TOS copi‚ en SDRAM (0-1FFF E00000-EEFFFF)"
	.asciz "            TOS copi‚ en SDRAM"
message51b:	.asciz "NVRAM unused"
	.asciz "NVRAM non utilis‚e"
message52:	.byte 13,10
	.asciz "Reset"
message53:	.byte 13,10
	.asciz "Byte 18, CAS Latency : " 
	.byte 13,10
	.asciz "Octet 18, CAS Latence : "
message54:	.asciz ", CAS Latency unsupported"
	.asciz ", CAS Latence non support‚e"
message55:	.asciz ", Data Width unsupported"
	.asciz ", Largeur donn‚es non support‚e"
message56:	.byte 13,10
	.asciz "Byte 19, CS Latency : " 
	.byte 13,10
	.asciz "Octet 19, CS Latence : "
message57:	.byte 13,10
	.asciz "Byte 20, WE Latency : " 
	.byte 13,10
	.asciz "Octet 20, WE Latence : "
message58:	.byte 13,10
	.asciz "Bytes 73-90, Module Part Number : " 
	.byte 13,10
	.asciz "Octets 73-90, R‚f‚rence du module : "
message59:	.asciz " nS"
message60:	.asciz " no parity"
	.asciz " pas de parit‚"
message61:	.asciz " parity"
	.asciz " parit‚"
message62:	.asciz " ECC"
	.asciz " ECC"
message63:	.asciz "15.625 uS"
message64:	.asciz "3.9 uS"
message65:	.asciz "7.8 uS"
message66:	.asciz "31.3 uS"
message67:	.asciz "62.5 uS"
message68:	.asciz "125 uS"
message69:	.asciz " MB"
	.asciz " Mo"
message70:	.byte 13,10
	.asciz "Byte 30, Minimum RAS Pulse Width : "
	.byte 13,10
	.asciz "Octet 30, Largeur mini impulsion RAS : "
message71:	.asciz ", self refresh"
message72:	.asciz " unbuffered"
	.asciz " sans buffers" 
message73:	.asciz " PC100"
message74:	.asciz " PC133"
message75:	.byte 13,10
	.asciz "Keyboard OK  "
	.byte 13,10 
	.asciz "Clavier OK  " 
message76:	.byte 13,10
	.asciz "Keyboard failure"
	.byte 13,10 
	.asciz "Pas de r‚ponse du clavier" 
message77:	.byte 13,10,27
	.ascii "p Choice of the system : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p Choix du systŠme : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
message78:	.byte 13
	.asciz "Starting in "
	.byte 13
	.asciz "D‚marrage dans "
message79:	.asciz " seconds  "
	.asciz " secondes  "
message80:	.asciz " TOS   "
message81:	.asciz " MagiC "
message82:	.asciz " Linux "
message83:	.asciz " removable"
	.asciz " amovible"
message84:	.asciz "no logical unit"
	.asciz "pas d'unit‚ logique"
message85:	.asciz "not ready"
	.asciz "pas prˆt"
message86:	.asciz "media not present"
	.asciz "support non pr‚sent"
message87:	.asciz "boot impossible"
	.asciz "boot impossible"
message88:	.byte 13,10
	.asciz " Abnormal asnwer => Reset SCSI..."
	.byte 13,10
	.asciz " R‚ponse anormale => Reset SCSI..."
message89:	.asciz "MB/S "
	.asciz "Mo/S "
message90:	.asciz "boot MSDOS"
	.asciz "boot MSDOS"
message91:	.byte 13,10
	.asciz " Found "
	.byte 13,10
	.asciz " Trouv‚ "
message92:	.byte 13,10
	.ascii "Boot drive has a BPB invalid!"
	.byte 13,10,0
	.byte 13,10
	.ascii "Le lecteur de boot a un BPB invalide !"
	.byte 13,10,0
message93:	.asciz " ... is not a TOS binary!"
	.asciz " ... n'est pas un ex‚cutable TOS !"
message94:	.byte 13,10
	.asciz "Error TOS : "
	.byte 13,10
	.asciz "Erreur TOS : "
message95:	.byte 13,10,27 
	.ascii "p START AUTO FOLDER "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p LANCEMENT DOSSIER AUTO "
	.byte 27
	.ascii "q"
	.byte 13,10,0
message96:	.byte 13,10,27 
	.ascii "p START GEM "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p LANCEMENT DU GEM "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	
blue:	.byte 0x1B,0x62,0x34,0
black:	.byte 0x1B,0x62,0x3F,0
	
#ifdef DEBUG
debug1:	.byte 13,10
	.asciz "Set Features: "
debug2:	.byte 13,10
	.asciz "Get Media Status: "	
debug3:	.byte 13,10
	.asciz "Test Unit Ready: "
debug4:	.byte 13,10
	.asciz "Request Sense: "	
debug5:	.byte 13,10
	.asciz "Read IDE LBA: "	
debug6:	.byte 13,10
	.asciz "Identify Device Packet: "
debug7:	.byte 13,10
	.asciz "Identify Device: "
debug8:	.byte 13,10
	.asciz "Inquiry: "
debug9:	.byte 13,10
	.asciz "Read TOS: "
debug10:	.byte 13,10
	.asciz "Packet: "
debug11:	.byte 13,10
	.asciz "Read SCSI: "
debug12:	.byte 13,10
	.asciz "TOS partition found: "
debug13:	.byte 13,10
	.asciz "Boot TOS partition: "
debug14:	.byte 13,10
	.asciz "Read directory: "
debug15:	.byte 13,10
	.asciz "MSDOS partition found: "
debug16:	.byte 13,10
	.asciz "Error code: "
#endif

boot_scsi:	.byte 8,9,10,11,12,13,14,15,16,17,255
boot_ide:	.byte 16,17,8,9,10,11,12,13,14,15,255
boot_scsi_2:	.byte 15,14,13,12,11,10,9,8,17,16,255
boot_ide_2:	.byte 17,16,15,14,13,12,11,10,9,8,255

tab_os:	.byte 0x80,8,0x10

list_manufacturers:
	.byte 0x1C
	.asciz "MITSUBISHI"
	.byte 0x25
	.asciz "KINGMAX"
	.byte 0x2C
	.asciz "MICRON"
	.byte 0x4A
	.asciz "COMPAQ"
	.byte 0x54
	.asciz "HP"
	.byte 0x98
	.asciz "KINGSTON"
	.byte 0x9E
	.asciz "CORSAIR"
	.byte 0xA4
	.asciz "IBM"
	.byte 0xC1
	.asciz "INFINEON"
	.byte 0xCE
	.asciz "SAMSUNG"
	.byte 0xDA
	.asciz "DANE-ELEC"
	.byte 0xAD     // jedec source
	.asciz "HYUNDAI" 
	.byte 0xE0     // module source ?
	.asciz "HYUNDAI"
null:	.byte 0,0

list_device_type:

	.asciz "magnetic disk"  // Direct-access Device
	.asciz "magnetic tape"  // Sequential Access Device
	.asciz "printer"        // Printer Device
	.asciz "processor"      // Processor Device
	.asciz "optical disk"   // Write Once Block Device
	.asciz "CD/DVD"         // CD/DVD Device
	.asciz "scanner"        // Scanner Device
	.asciz "optical memory" // Optical Memory Block Device
	.asciz "juke-box"       // Media Changer Device
	.asciz "communication"  // Communication Device
	.asciz "CompactFlash"
	
	.asciz "disque magn‚tique"
	.asciz "bande magn‚tique"
	.asciz "imprimante"
	.asciz "processeur"
	.asciz "disque optique"
	.asciz "CD/DVD"
	.asciz "scanner"
	.asciz "m‚moire optique"
	.asciz "juke-box"
	.asciz "communication"
	.asciz "CompactFlash"

	.align 2

boot_drive:

	movem.l D0-A5,-(SP)
	link A6,#-18
	clr.l -(SP)
	move.l #CT60_BOOT_ORDER,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	move.b D0,-18(A6)
	lea boot_scsi(PC),A5
	and.w #3,D0
	beq.s .loop_drive
	lea boot_ide(PC),A5
	cmp.w #1,D0
	beq.s .loop_drive
	lea boot_scsi_2(PC),A5
	cmp.w #2,D0
	beq.s .loop_drive
	lea boot_ide_2(PC),A5
.loop_drive:
		clr.w -(SP)                       // stram
		move.l #SPEED_BUFFER_SIZE,-(SP)   // size
		move.w #0x44,-(SP)                // Mxalloc
		trap #1 
		addq.w #8,SP
		move.l D0,-12(A6)                 // SCSI buffer
		move.w #3,-(SP)                   // TT ram if possible
		move.l #SPEED_BUFFER_SIZE,-(SP)   // size
		move.w #0x44,-(SP)                // Mxalloc
		trap #1 
		addq.w #8,SP
		move.l D0,-16(A6)                 // IDE buffer normally in SDRAM    
		moveq #1,D1                       // counter logical unit
.loop2_drive:
			move.w D1,-(SP)      // logical unit
			move.w 0x840,D4
			move.b (A5,D4.w),D4
			cmp.w #2,0x3E86      // number of planes
			bls.s .black_and_white
			lea blue(PC),A0
			bsr display_string_single
.black_and_white:
			lea message41(PC),A0
			btst #4,D4
			beq.s .scsi_drive
			moveq #0,D1          // no logical unit on IDE drives
			clr.w (SP)
			lea message42(PC),A0
.scsi_drive:
			bsr display_string_single
			move.w D4,D0
			and.w #7,D0
			or.w #0x30,D0
			bsr display_char
			moveq #0x2E,D0
			bsr display_char
			moveq #0x30,D0
			or.w (SP),D0         // logical unit
			bsr display_char
			cmp.w #2,0x3E86      // number of planes
			bls.s .black_and_white_2
			lea black(PC),A0
			bsr display_string_single
.black_and_white_2:
			moveq #0,D7          // flags
			btst #2,-18(A6)      // old boot
			beq.s .new_boot
			lea message43(PC),A0 // ...
			bsr display_string_single
			bra .default_tos_routine
.new_boot:
			btst #4,D4
			bne .ide_drive
#ifdef DEBUG
			lea debug8(PC),A0
			bsr display_string_single
#endif	
			move.w D4,D0         // drive
			move.l _dskbufp,A0   // DMA buffer
			lea -6(A6),A1        // cmd buffer
			move.b #0x12,(A1)    // inquiry
			asl.w #5,D1
			move.b D1,1(A1)      // logical unit
			clr.w 2(A1)
			moveq #96,D1         // DMA bytes length
			move.b D1,4(A1)      // length
			clr.b 5(A1)
			moveq #6,D2          // cmd bytes length
			bsr scsi_read
			bmi .no_answer       // time-out
#ifdef DEBUG
			move.l _dskbufp,A1
			moveq #5,D1
			bsr dump
			move.w #7,-(SP)      // Crawcin
			trap #1
			addq.w #2,SP
			moveq #13,D0
			bsr display_char
			moveq #10,D0
			bsr display_char			
#endif			
			move.l _dskbufp,A0
			cmp.b #0x7F,(A0)     // qualifier = 3 & no device type
			beq .no_logical_unit
			addq.w #8,A0
			lea 24(A0),A1
			moveq #23,D1
.last_space_infos_device_scsi:
				cmp.b #0x20,-(A1)
			dbne D1,.last_space_infos_device_scsi
			addq.w #1,A1
			clr.b (a1)
			moveq #0x20,D0
			bsr display_char
			moveq #23,D1         // vendor & product identification
.infos_device_scsi:
				move.b (A0)+,D0
				beq.s .end_infos_device_scsi
				bsr display_char			
			dbf D1,.infos_device_scsi
.end_infos_device_scsi:
			move.l _dskbufp,A0   // DMA buffer
			moveq #0x1F,D0
			and.b (A0),D0        // device type
			cmp.w #10,D0
			bcc .read_root
			bra .infos_device_type
.ide_drive:
#ifdef RESET
			move.l _dskbufp,A0   // IDE buffer
			lea -8(A6),A1        // cmd buffer
			move.b #0x08,(A1)    // device reset
			moveq #7,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			or.b #0xA0,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			moveq #0,D0          // bytes
			bsr ide_read
#endif
#ifdef DEBUG
			lea debug6(PC),A0
			bsr display_string_single
#endif	
			bset #16,D7          // flag PACKET
			move.l _dskbufp,A0   // IDE buffer
			lea -8(A6),A1        // cmd buffer
			move.b #0xA1,(A1)    // identify packet device
			moveq #7,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			or.b #0xA0,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			move.l #512,D0       // bytes
			bsr ide_read
			beq.s .found_ide_drive
#ifdef DEBUG
			lea debug7(PC),A0
			bsr display_string_single
#endif	
			bclr #16,D7          // flag PACKET
			move.l _dskbufp,A0   // IDE buffer
			clr.w (A0)
			lea -8(A6),A1        // cmd buffer
			move.b #0xEC,(A1)    // identify device
			moveq #7,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			or.b #0xA0,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			move.l #512,D0       // bytes
			bsr ide_read
			move.l _dskbufp,A0   // IDE buffer	
			cmp.w #0x848A,(A0)   // CompactFlash
			beq.s .compactflash_found
			and.b #0xE0,(A0)     // force to 0 command packet set (identify device packet) 	
.compactflash_found:                                            			                     // this word =  0x848A for Compact flash
			tst.w D0
			beq.s .found_ide_drive
.no_answer:
			move.w (SP)+,D1
			lea message43(PC),A0 // ...
			bsr display_string_single
			lea message44(PC),A0 // time-out
			moveq #-1,D0
			bra .no_read_error
.no_logical_unit:
			move.w (SP)+,D1
			lea message43(PC),A0 // ...
			bsr display_string_single
			lea message84(PC),A0 // no logical unit
			moveq #0,D0
			bra .no_read_error
.found_ide_drive:	
#ifdef DEBUG
			move.l _dskbufp,A1
			moveq #15,D1
			bsr dump
			move.w #7,-(SP)      // Crawcin
			trap #1
			addq.w #2,SP
			moveq #13,D0
			bsr display_char
			moveq #10,D0
			bsr display_char			
//			move.l _dskbufp,A0   // IDE buffer
//			move.w (A0),D0
//			bsr hex_word	
#endif
			move.l _dskbufp,A0
			add.w #54,A0
			lea 24(A0),A1
			moveq #23,D1
.last_space_infos_device_ide:
				cmp.b #0x20,-(A1)
			dbne D1,.last_space_infos_device_ide
			addq.w #1,A1
			clr.b (a1)
			moveq #0x20,D0
			bsr display_char
			moveq #23,D1         // model number
.infos_device_ide:
				move.b (A0)+,D0
				beq.s .end_infos_device_ide
				bsr display_char
			dbf D1,.infos_device_ide
.end_infos_device_ide:
			move.l _dskbufp,A0   // IDE buffer
			btst #1,98(A0)       // capabilities, LBA supported
			sne.b D7
			ext.w D7             // LBA flag
			moveq #10,D0
			cmp.w #0x848A,(A0)   // CompactFlash
			beq.s .infos_device_type
			moveq #0x1F,D0
			and.b (A0),D0        // command packet set
			cmp.w #10,D0 
			bcc .read_root
.infos_device_type:
			move.w D0,-(SP)
			moveq #0x2C,D0
			bsr display_char
			moveq #0x20,D0
			bsr display_char
			move.w (SP)+,D0
			bsr display_device_type
			tst.b 1(A0)
			bpl.s .read_root     // RMB
			bset #31,D7          // removable media flags
			lea message83(PC),A0 // removable
			bsr display_string
.read_root:
			lea message43(PC),A0 // ...
			bsr display_string_single
			cmp.w #10,D0         // device type
			beq.s .direct_access 
			tst.w D0             // device type <> Direct-access
			bne .boot_impossible
.direct_access:
			tst.l D7             // removable media flag
			bpl .no_removable_media
			btst #4,D4
			bne .ide_drive_2
.test_media_scsi:
#ifdef DEBUG
			move.l #200,D0
			bsr delay_hz_200
			lea debug3(PC),A0
			bsr display_string_single
#endif	
			move.w D4,D0         // drive
			move.l _dskbufp,A0   // DMA buffer
			lea -6(A6),A1        // cmd buffer
			clr.b (A1)           // test unit ready
			move.w (SP),D1       // logical unit
			asl.w #5,D1
			move.b D1,1(A1)      // logical unit
			clr.w 2(A1)
			clr.w 4(A1)          // length
			moveq #6,D2          // cmd bytes length
			bsr scsi_read
			bmi .no_answer_2     // time-out
			beq .no_removable_media // good
#ifdef DEBUG
			bsr hex_byte
			lea debug4(PC),A0
			bsr display_string_single
#endif	
			move.w D4,D0         // drive
			move.l _dskbufp,A0   // DMA buffer
			lea -6(A6),A1        // cmd buffer
			move.b #3,(A1)       // request sense
			move.w (SP),D1       // logical unit
			asl.w #5,D1
			move.b D1,1(A1)      // logical unit
			clr.w 2(A1)
			clr.w 2(A1)
			move.l #252,D1       // DMA bytes length
			move.b D1,4(A1)      // length
			clr.b 5(A1)
			moveq #6,D2          // cmd bytes length
			bsr scsi_read
			bmi .no_answer_2     // time-out
			move.l _dskbufp,A0   // DMA buffer
#ifdef DEBUG
			move.b 2(A0),D0
			bsr hex_byte
			move.b 12(A0),D0
			bsr hex_byte
			move.b 13(A0),D0
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
#endif	
			moveq #0xF,D0
			and.b 2(A0),D0       // sense key
			beq .no_removable_media
			cmp.w #2,D0          // not ready
			beq.s .sense_not_ready_scsi
			cmp.w #6,D0          // unit attention
			bne .no_removable_media
.sense_not_ready_scsi:
			cmp.b #0x28,12(A0)   // ASC, medium changed
			bne.s .test_not_changed_scsi
			tst.b 13(A0)
			beq .test_media_scsi
.test_not_changed_scsi:
			cmp.b #0x29,12(A0)   // ASC, reset bus occured
			bne.s .test_not_ready_scsi
			tst.b 13(A0)
			beq .test_media_scsi 
.test_not_ready_scsi:
			cmp.b #4,12(A0)      // ASC, in progress
			bne.s .test_media_present_scsi
			cmp.b #1,13(A0)      // ASCQ
			beq .test_media_scsi	
.test_media_present_scsi:
			cmp.b #0x3A,12(A0)   // ASC, medium not present
			bne.s .not_ready_scsi
			tst.b 13(A0)         // ASCQ
			beq.s .no_media_scsi
			cmp.b #1,13(A0)      // ASCQ, try closed
			bne.s .not_ready_scsi
.no_media_scsi:
			move.w (SP)+,D1
			lea message86(PC),A0 // no media
			moveq #0,D0
			bra .no_read_error	
.not_ready_scsi:		
			cmp.w #2,D0          // not ready
			bne .no_removable_media
			move.w (SP)+,D1
			lea message85(PC),A0 // not ready
			moveq #0,D0
			bra .no_read_error
.no_answer_2:		                     // abnormal time-out on test unit ready or request sense command
			lea message44(PC),A0 // time-out
			bsr display_string
			jsr 0xE01C8C         // reset the bus a 2nd time for other drives
			move.w (SP)+,D1
			lea message88(PC),A0 // reset SCSI
			moveq #-1,D0
			bra .no_read_error
.boot_impossible:
			move.w (SP)+,D1
			lea message87(PC),A0 // boot impossible
			moveq #0,D0
			bra .no_read_error
.ide_drive_2:		
			move.l _dskbufp,A0   // IDE buffer
			moveq #3,D0
			and.w 254(A0),D0
			cmp.w #1,D0          // removable media status supported
			bne .no_removable_media
#ifdef DEBUG
			lea debug1(PC),A0
			bsr display_string_single
#endif	
			move.l _dskbufp,A0   // IDE buffer
			clr.w (A0)
			lea -8(A6),A1        // cmd buffer
			move.b #0xEF,(A1)    // set features
			moveq #7,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			or.b #0xA0,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			move.b #0x95,6(A1)   // features, enable media status notification
			moveq #0,D0          // bytes
			bsr ide_read
//			bmi .no_answer_3
#ifdef DEBUG
			bsr hex_byte
#endif			
.test_media_ide:
#ifdef DEBUG
			move.l #200,D0
			bsr delay_hz_200
			lea debug2(PC),A0
			bsr display_string_single
#endif			
			move.l _dskbufp,A0   // IDE buffer
			lea -8(A6),A1        // cmd buffer
			move.b #0xDA,(A1)    // get media status
			moveq #7,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			or.b #0xA0,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			moveq #0,D0          // bytes
			bsr ide_read
			bmi.s .no_answer_3
#ifdef DEBUG
			move.w D0,-(SP)
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
			move.w (SP)+,D0
#endif	
			btst #5,D0           // media change MC
			bne.s .test_media_ide
			btst #1,D0           // no media NM
			beq.s .no_removable_media
			move.w (SP)+,D1
			lea message86(PC),A0 // no media
			moveq #0,D0
			bra .no_read_error
.no_answer_3:
			move.w (SP)+,D1
			lea message44(PC),A0 // time-out
			moveq #-1,D0
			bra .no_read_error
.no_removable_media:
			btst #4,D4
			beq .scsi_drive_2    // SCSI
			tst.w D7
			bpl .default_tos_routine // LBA not supported			
			btst #16,D7
			beq.s .no_packet
#ifdef DEBUG
			lea debug10(PC),A0
			bsr display_string_single
#endif	
			move.l _dskbufp,A0   // IDE buffer
			lea -8(A6),A1        // cmd buffer
			move.b #0xA0,(A1)    // packet
			moveq #7,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			or.b #0xA0,D0
			move.b D0,1(A1)      // drive (C/D/H)
			move.w #0x200,2(A1)  // cyl high & low, byte count limit
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			moveq #0,D0          // bytes
			bsr ide_read
.no_packet:
			tst.l -16(A6)        // IDE buffer
			beq .default_tos_routine 
#ifdef DEBUG
			lea debug5(PC),A0
			bsr display_string_single
#endif			
			moveq #1,D3
.loop_speed_ide:
				move.l -16(A6),A0    // IDE buffer normally in SDRAM
				lea -8(A6),A1        // cmd buffer
				move.b #0x20,(A1)    // read sector(s)
				moveq #7,D0
				and.w D4,D0          // drive
				asl.w #4,D0
				or.b #0xE0,D0        // LBA
				move.b D0,1(A1)      // drive (C/D/H)
				clr.w 2(A1)          // cyl high & low
				clr.b 4(A1)          // sec num
				move.b #SPEED_BUFFER_SIZE/512,5(A1) // sec count
				clr.b 6(A1)          // features
				move.l #SPEED_BUFFER_SIZE,D0 // bytes
				bsr ide_read
				bne.s .drive_not_ok_2
			dbf D3,.loop_speed_ide 	
			move.l D1,D0
			bsr display_mb_by_sec_disk
			moveq #0,D0          // no error
			move.l -16(A6),A0    // IDE buffer
			move.l _dskbufp,A1
			moveq #127,D1        // 512 bytes
.copy_buffer_ide:
				move.l (A0)+,(A1)+
			dbf D1,.copy_buffer_ide
.drive_not_ok_2:
			move.w (SP)+,D1
			tst.l D0
			beq .drive_ok
			bgt.s .read_error
			lea message44(PC),A0 // time-out
			bra .no_read_error
.read_error:
			lea message46(PC),A0 // read error
#ifdef DEBUG
			btst #16,D7          // flag PACKET
			beq .no_read_error
			btst #0,D0           // state, ERR
			beq .no_read_error
			moveq #0,D0
			move.b 0xFFF00005,D0 // error register
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
			moveq #0,D0
#endif		
			bra .no_read_error
.scsi_drive_2:
			tst.l -12(A6)        // SCSI buffer
			beq .default_tos_routine 
#ifdef DEBUG
			lea debug11(PC),A0
			bsr display_string_single
			move.l -12(A6),A0
			moveq #127,D0
.loop_raz_buffer:
				clr.l (A0)+
			dbf D0,.loop_raz_buffer			
#endif
			moveq #1,D3
.loop_speed_scsi:
				move.w D4,D0         // drive
				move.l -12(A6),A0    // DMA buffer
				lea -6(A6),A1        // cmd buffer
				move.b #0x08,(A1)    // read
				move.w (SP),D1       // logical unit
				asl.w #5,D1
				move.b D1,1(A1)      // logical unit
				clr.w 2(A1)          // logical block adress
				move.b #SPEED_BUFFER_SIZE/512,4(A1) // num blocks
				clr.b 5(A1)          // control
				move.l #SPEED_BUFFER_SIZE,D1 // DMA bytes length
				moveq #6,D2          // cmd bytes length
				bsr scsi_read
				bne .drive_not_ok    // error
			dbf D3,.loop_speed_scsi
			move.l D1,D0
			bsr display_mb_by_sec_disk
			moveq #0,D0          // no error
			move.l -12(A6),A0    // SCSI buffer
			move.l _dskbufp,A1
			moveq #127,D1        // 512 bytes
.copy_buffer_scsi:
				move.l (A0)+,(A1)+
			dbf D1,.copy_buffer_scsi
.drive_not_ok:
#ifdef DEBUG
			move.l D0,-(SP)
			move.l -12(A6),A1
			moveq #15,D1
			bsr dump
			move.w #7,-(SP)      // Crawcin
			trap #1
			addq.w #2,SP
			lea debug16(PC),A0
			bsr display_string_single
			move.l (SP),D0
			bsr hex_long	
			moveq #13,D0
			bsr display_char
			moveq #10,D0
			bsr display_char
			move.l (SP)+,D0
#endif
			move.w (SP)+,D1
			tst.l D0
			beq .drive_ok
			lea message44(PC),A0 // time-out
			tst.l D0
			bmi.s .no_read_error
			lea message46(PC),A0 // read error
			bra.s .no_read_error
.default_tos_routine:
#ifdef DEBUG
			lea debug9(PC),A0
			bsr display_string_single
#endif
			movem.l D3/A5/A6,-(SP)
			move.w D4,-(SP)
			move.l _dskbufp,-(SP)
			move.w #1,-(SP)
			clr.l -(SP)
			jsr 0xE017CE         // read root sector
			lea 12(SP),SP
			movem.l (SP)+,D3/A5/A6
			move.w (SP)+,D1
			tst.l D0
			beq .drive_ok
			lea message44(PC),A0 // time-out
			cmp.l #-1,D0
			beq.s .no_read_error
			lea message45(PC),A0 // error
			cmp.l #-11,D0
			bne.s .no_read_error
			lea message46(PC),A0 // read error
.no_read_error:
			bsr display_string
			addq.l #1,D0
		dbeq D1,.loop2_drive
		move.l -16(A6),D0        // IDE buffer
		beq.s .no_ide_buffer_2
		move.l D0,-(SP)
		move.w #0x49,-(SP)       // Mfree
		trap #1 
		addq.w #6,SP
.no_ide_buffer_2:
		move.l -12(A6),D0        // SCSI buffer
		beq .next_drive
		move.l D0,-(SP)
		move.w #0x49,-(SP)       // Mfree
		trap #1 
		addq.w #6,SP
		bra .next_drive
.root_msdos_combined:
		btst #4,D4
		beq .not_ide_drive       // SCSI
		tst.w D7
		bpl .next_drive          // LBA not supported (needed by read_sectors)			
.not_ide_drive:
		move.l _dskbufp,A0
		moveq #1,D0
		bsr swap_buffer
		lea message90(PC),A0     // boot MSDOS combined
		bsr display_string
#ifdef DEBUG
		move.l _dskbufp,A1
		moveq #15,D1
		bsr dump
		move.w #7,-(SP)          // Crawcin
		trap #1
		addq.w #2,SP
		move.l _dskbufp,A1
		lea 256(A1),A1
		moveq #15,D1
		bsr dump
		move.w #7,-(SP)          // Crawcin
		trap #1
		addq.w #2,SP
#endif
		move.l _sysbase,A0       // header ROM
		move.l 0x24(A0),A0       // kbshift
		move.b (A0),D0
		move.l #0x444D4172,D3    // DMAr
		move.w D4,D7
		asl.w #5,D7
		move.w 0xA80,D5          // bootpref NVM
		btst #3,D0               // ALT 
		bne .next_drive
		btst #2,D0               // CTRL
		bne .normal_bootpref_2
		and.w #0x67,D5           // remove TOS, Linux, MagiC flags for menu_boot
.normal_bootpref_2:
		move.l _dskbufp,A0
		bsr check_boot
		beq .root_combined_valid
		move.l _dskbufp,A0
		lea 0x1BE(A0),A0         // infos partitions MSDOS
		moveq #0,D2              // ext sector
		moveq #3,D0              // 4 partitions
.loop_partition_msdos:
			tst.l 12(A0)       // nr sect
			beq.s .next_partition_msdos
			move.b 4(A0),D1    // partition type
			cmp.b #0x5,D1      // extended partition
			beq.s .extended_partition_msdos
			cmp.b #0xF,D1      // WIN95 extended partition
			beq.s .extended_partition_msdos
			cmp.b #0x80,(A0)   // active partition bootable
			bne.s .next_partition_msdos
			cmp.b #0x4,D1      // FAT16 up to 32M
			beq.s .partition_ok_msdos
			cmp.b #0x6,D1      // FAT16 over 32M
			beq.s .partition_ok_msdos
			cmp.b #0xE,D1      // WIN95 FAT16
			beq.s .partition_ok_msdos
			bra.s .next_partition_msdos
.extended_partition_msdos:
			move.l 8(A0),D2    // start sect = extended partition
			ror.w #8,D2
			swap D2
	 		ror.w #8,D2						
.next_partition_msdos:
			lea 16(A0),A0
		dbf D0,.loop_partition_msdos
		tst.l D2
		beq .next_drive          // no extended partition
		moveq #1,D1              // 1 sector
		moveq #-1,D0             // swap bytes
		move.w D4,D0             // drive
		move.l _dskbufp,A0       // read extended partition
		bsr read_sectors
		bmi .next_drive
		move.l _dskbufp,A0
		cmp.w #0x55AA,510(A0)    // magic
		bne .next_drive
		lea 0x1BE(A0),A0         // infos partitions
		moveq #0,D2
		moveq #1,D0              // 1 entry by ext sector
		bra .loop_partition_msdos
.partition_ok_msdos:		
		move.l 8(A0),D2          // start sect
		ror.w #8,D2
		swap D2
	 	ror.w #8,D2
#ifdef DEBUG
		lea debug15(PC),A0
		bsr display_string_single
		move.l D2,D0
		bsr hex_long
#endif
		moveq #1,D1              // 1 sector
		moveq #-1,D0             // swap bytes
		move.w D4,D0             // drive
		move.l _dskbufp,A0       // read boot sector
		bsr read_sectors
		bmi .next_drive
		move.l _dskbufp,A0  
		cmp.w #0x55AA,510(A0)    // magic
		bne .next_drive
	 	bra .boot_tos_partition
.root_combined_valid:
		move.l _dskbufp,A0
		lea 0x1C6(A0),A0         // infos partitions TOS
		moveq #0,D2              // ext sector for XGM
		moveq #3,D0              // 4 partitions
.loop_partition:
			btst #0,(A0)       // active partition
			beq.s .next_partition
			move.b (A0),D1
			tst.b D5
			beq.s .all_types
			and.b #0xF8,D1     // remove unused bits
			cmp.b D5,D1        // partition type
			beq.s .partition_bootable
			bra.s .next_partition			
.all_types:
			and.b #0xF8,D1     // remove unused bits
			beq.s .next_partition
.partition_bootable:
			move.l (A0),D1
			and.l #0xFFFFFF,D1 // ID
			cmp.l #0x47454D,D1 // GEM
			beq.s .partition_ok
			cmp.l #0x42474D,D1 // BGM
			beq.s .partition_ok
			cmp.l #0x58474D,D1 // XGM
			bne.s .next_partition
			move.l 4(A0),D2    // start of partition = ext sector for XGM
.next_partition:
			lea 12(A0),A0
		dbf D0,.loop_partition
		tst.l D2
		beq .next_drive          // no ext sector for XGM
		moveq #1,D1              // 1 sector
		moveq #-1,D0             // swap bytes
		move.w D4,D0             // drive
		move.l _dskbufp,A0       // read ext sector for XGM
		bsr read_sectors
		bmi .next_drive
		move.l _dskbufp,A0
		lea 0x1C6(A0),A0         // infos partitions
		moveq #0,D2              // ext sector for XGM
		moveq #1,D0              // 1 entry by ext sector
		bra .loop_partition
.partition_ok:
		move.l 4(A0),D2          // start of partition
#ifdef DEBUG
		lea debug12(PC),A0
		bsr display_string_single
		move.l D2,D0
		bsr hex_long
#endif
		moveq #1,D1              // 1 sector
		moveq #-1,D0             // swap bytes
		move.w D4,D0             // drive
		move.l _dskbufp,A0       // read boot sector
		bsr read_sectors
		bmi .next_drive
		move.l _dskbufp,A0       // buffer
		bsr check_boot
		bne .next_drive
.boot_tos_partition:
#ifdef DEBUG
		lea debug13(PC),A0
		bsr display_string_single
		move.l D2,D0
		bsr hex_long
#endif
		move.l hdv_rw,-(SP)
		move.l D2,D1             // start of partition
		moveq #-1,D0             // swap bytes
		move.w D4,D0             // drive
		bsr exec_boot
		move.l (SP)+,D0
		cmp.l hdv_rw,D0
		beq .next_drive
		move.w _bootdev,-(SP)
		move.w #7,-(SP)          // Getbpb
		trap #13
		addq.w #4,SP
		tst.l D0
		bne .end_boot_drive
		lea message92(PC),A0
		bsr display_string
		move.w #7,-(SP)          // Crawcin
		trap #1
		addq.w #2,SP
		clr.w _bootdev
		bra .end_boot_drive
.root_ok:
		lea message48(PC),A0
		bsr display_string
#ifdef DEBUG
		move.w #7,-(SP)          // Crawcin
		trap #1
		addq.w #2,SP
#endif
		move.l _sysbase,A0       // header ROM
		move.l 0x24(A0),A0       // kbshift
		move.b (A0),D0
		move.l _dskbufp,A0
		move.l #0x444D4172,D3    // DMAr
		move.w D4,D7
		asl.w #5,D7
		move.w 0xA80,D5          // bootpref NVM
		btst #2,D0               // CTRL
		bne .normal_bootpref
		and.w #0x67,D5           // remove TOS, Linux, MagiC flags for menu_boot
.normal_bootpref:
		movem.l A5/A6,-(SP)
		move.l hdv_rw,-(SP)
		jsr (A0)
		move.l (SP)+,D0
		movem.l (SP)+,A5/A6
		cmp.l hdv_rw,D0
		beq.s .next_drive
		bra.s .end_boot_drive
.drive_ok:
		move.l -16(A6),D0        // IDE buffer
		beq.s .no_ide_buffer
		move.l D0,-(SP)
		move.w #0x49,-(SP)       // Mfree
		trap #1 
		addq.w #6,SP
.no_ide_buffer:
		move.l -12(A6),D0        // SCSI buffer
		beq.s .no_scsi_buffer
		move.l D0,-(SP)
		move.w #0x49,-(SP)       // Mfree
		trap #1 
		addq.w #6,SP
.no_scsi_buffer:
		move.l _dskbufp,A0
		bsr check_boot
		beq.s .root_ok
		btst #2,-18(A6)          // old boot
		bne .no_boot_found
		move.l _dskbufp,A0
		cmp.w #0xAA55,510(A0)
		beq .root_msdos_combined
.no_boot_found:
		lea message47(PC),A0     // no boot found
		bsr display_string
.next_drive:
#ifdef DEBUG
		move.w #7,-(SP)          // Crawcin
		trap #1
		addq.w #2,SP
#endif
		move.w 0x840,D4
		addq.w #1,D4
		move.w D4,0x840
	tst.b (A5,D4)
	bpl .loop_drive
.end_boot_drive:
//	cmp.l #0x31415926,resvalid
//	bne.s .no_resvector
//	tst.l resvector
//	beq.s .no_resvector
//	lea message52(PC),A0
//	bsr display_string_single
//	move.l resvector,A0
//	bsr display_xbra
//	lea crlf(PC),A0
//	bsr display_string_single
//.no_resvector:
	unlk A6
	movem.l (SP)+,D0-A5
	rts
	
check_boot:

	movem.l D0-D1/A0,-(SP)
	move.w #255,D0
	moveq #0,D1
.loop_checksum:
		add.w (A0)+,D1
	dbf D0,.loop_checksum
	cmp.w #0x1234,D1
	movem.l (SP)+,D0-D1/A0
	rts
	
exec_boot:  		// D0 drive, D0.H: flag swap bytes, D1.L: start of partition

	movem.l D1-D7/A4,-(SP)
	link A6,#-32
	move.l D0,D4             // drive & flag swap bytes
	move.l D1,D6             // start of partition
	move.w #3,-(SP)          // TT ram if possible
	move.l #-1,-(SP)         // size
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.w #8,SP
	move.l D0,D5             // greater block
	move.l D0,-4(A6)
	move.w #3,-(SP)          // TT ram if possible
	move.l D5,-(SP)          // size
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.w #8,SP
	tst.l D0
	beq .boot_error
	move.l D0,A4             // buffer
	move.l D0,-16(A6)
	move.l _dskbufp,A0       // boot sector
	moveq #0,D1
	move.b 0xC(A0),D1        // BPS * 256
	lsr.w #1,D1              // / 512
	move.l D1,-12(A6)        // BPS / 512
	moveq #0,D2
	move.b 0x12(A0),D2
	lsl.w #8,D2
	move.b 0x11(A0),D2       // NDIRS
	move.w 0xE(A0),D3        // RES
	ror.w #8,D3
	mulu d1,D3               // * (BPS / 512)
	add.l D6,D3
	move.l D3,-8(A6)
	move.w 0x16(A0),D6       // SPF
	ror.w #8,D6
	mulu D1,D6               // * (BPS / 512)
	moveq #0,D1
	move.b 0x10(A0),D1       // NFATS
	mulu D1,D6
	add.l D3,D6              // + RES + start sector of partition
	lsr.l #4,D2              // NDIRS / 32
	add.l D6,D2
#ifdef DEBUG
	lea debug14(PC),A0
	bsr display_string_single
	move.l D6,D0
	bsr hex_long
	moveq #0x20,D0
	bsr display_char
	move.l D2,D0
	bsr hex_long
#endif
	move.l D2,-20(A6)        // end directory
	move.l D6,D2             // 1st sector directory
.loop_read_dir:	
		move.l -16(A6),A0               // buffer Mxalloc
		moveq #1,D1                     // 1 sector
		move.l D4,D0                    // drive & flag swap bytes
		bsr read_sectors                // read directory
		bmi .mfree_boot
		move.l -16(A6),A0               // buffer Mxalloc
		moveq #15,D1
.next_entry_dir:
			cmp.b #0x53,8(A0)  // S
			bne.s .bad_ext
			cmp.b #0x59,9(A0)  // Y
			bne.s .bad_ext
			cmp.b #0x53,10(A0) // S
			beq.s .ext_ok
.bad_ext:
			lea 32(A0),A0
		dbf D1,.next_entry_dir
		addq.l #1,D2
	cmp.l -20(A6),D2
	bcs.s .loop_read_dir
	bra .mfree_boot
.bad_file:
	lea message93(PC),A0     // not a TOS binary
	bsr display_string       
	move.l -16(A6),A0        // buffer Mxalloc
	moveml -28(A6),D2        // restore loop_read_dir context
	moveq #1,D1              // 1 sector
	move.l D4,D0             // drive & flag swap bytes
	bsr read_sectors         // reload directory
	bmi .mfree_boot
	movem.l -32(A6),D1/D2/A0 // restore loop_read_dir context
	bra.s .bad_ext 
.ext_ok:
	movem.l D1/D2/A0,-32(A6) // save loop_read_dir context
	move.l A0,-(SP)
	lea message91(PC),A0
	bsr display_string       // display driver name
	move.l (SP)+,A0
	moveq #10,D1
	moveq #0,D2
.loop_name_driver:	
		cmp.w #8,D2
		bne.s .not_point
		moveq #0x2E,D0
		bsr display_char
.not_point:
	             move.b (A0,D2),D0
		bsr display_char
		addq.w #1,D2
	dbf D1,.loop_name_driver
	move.l 28(A0),D5         // size file
	ror.w #8,D5
	swap D5
	ror.w #8,D5
	add.l #0x1800,D5         // stack size
	cmp.l -4(A6),D5          // size block Mxalloc
	bhi .mfree_boot
	move.l -16(A6),A4        // buffer Mxalloc
	add.l -4(A6),A4          // size block Mxalloc
	lea -0x8000(A4),A4       // top of the block
	move.l -16(A6),A2        // buffer Mxalloc
	move.w 26(A0),D6         // 1st cluster
	ror.w #8,D6
	moveq #-1,D3
.loop_read_file:
		move.l _dskbufp,A0       // boot sector
		moveq #0,D1
		move.b 0xD(A0),D1        // SPC
		mulu -10(A6),D1          // BPS / 512 = sec count
		move.w D6,D2             // cluster
		subq.w #2,D2
		mulu D1,D2               // * sec count * SPC
		add.l -20(A6),D2         // + end directory = start sector
                          move.l A2,A0             // buffer file
                          move.l D4,D0             // drive & flag swap bytes
		bsr read_sectors
		bmi.s .mfree_boot
		asl.l #8,D1              // * 512
		add.l D1,D1              // bytes
		add.l D1,A2              // + file offset
		move.w D6,D2
		ext.l D2
		lsr.l #8,D2
		add.l -8(A6),D2          // + RES + start sector of partition
		cmp.l D3,D2              // start sector
		beq.s .not_reload_fat
		move.l D2,D3
                          move.l A4,A0             // buffer FAT
		moveq #1,D1              // sec count
                          move.l D4,D0             // drive & flag swap bytes
		bsr read_sectors
		bmi.s .mfree_boot
.not_reload_fat:
		and.w #255,D6
		add.w D6,D6
		move.w (A4,D6),D6        // cluster from FAT entry
	ror.w #8,D6
	bpl.s .loop_read_file
	move.l -16(A6),A2        // buffer Mxalloc
	move.l A2,A0             // buffer file
	cmp.w #0x601A,(A0)+      // binary test
	bne .bad_file
	lea 0x1C(A2),A1          // + header size
	add.l (A0)+,A1           // + text segment
	add.l (A0)+,A1           // + data segment
	add.l 4(A0),A1           // + bss segment
	tst.l (A1)
	beq.s .end_reloc
	lea 0x1C(A2),A0          // + header size
	move.l A0,D1
	moveq #0,D0
	add.l (A1)+,A0
.loop_reloc:
		add.l D1,(A0)
.loop_reloc_2:
			move.b (A1)+,D0
			beq.s .end_reloc
			cmp.b #1,D0
			bne.s .next_reloc
			lea 254(A0),A0
		bra.s .loop_reloc_2
.next_reloc:
		add.w D0,A0
	bra.s .loop_reloc
.end_reloc:
	cpusha BC                // flush
	move.l -4(A6),D0         // size block Mxalloc
	unlk A6
	movem.l (SP)+,D1-D7/A4
	jmp 0x20(A2)	            // start file after the 1st BRA
.mfree_boot:
	move.l -16(A6),-(SP)     // buffer Mxalloc
	move.w #0x49,-(SP)       // Mfree
	trap #1
	addq.w #6,SP
.boot_error:
	unlk A6
	movem.l (SP)+,D1-D7/A4
	rts

swap_buffer:		// A0: buffer, D0: count

	movem.l D0-D2/A0,-(SP)
	bra.s .end_loop_swap
.loop_swap:
	move.w #255,D2
.loop_swap_2:
			move.w (A0),D1
			ror.w #8,D1
			move.w D1,(A0)+		
		dbf D2,.loop_swap_2
.end_loop_swap:
	dbf D0,.loop_swap
	movem.l (SP)+,D0-D2/A0
	rts

read_sectors: 	// A0: buffer, D0: drive, D0.H: flag swap bytes, D1: count, D2.L: start sector
		// return error code inside D0
	movem.l D1-D4/A0-A4,-(SP)
	move.l A0,A4             // buffer
	move.l D0,D4             // physical drive & flag swap bytes
	move.w D1,D3             // count
	btst #4,D4
	beq .use_DMAread         // SCSI
	link A6,#-8
	move.l A4,A0             // IDE buffer
	lea -8(A6),A1            // cmd buffer
	move.b #0x20,(A1)        // read sector(s)
	moveq #7,D0
	and.w D4,D0              // physical drive
	asl.w #4,D0
	or.b #0xE0,D0            // LBA
	move.b D0,1(A1)          // drive (C/D/H)
	move.l D2,D0             // LBA
	move.b D0,4(A1)          // sec num, LBA low
	lsr.l #8,D0
	move.w D0,2(A1)          // cyl high & low, LBA high & mid
	move.b D1,5(A1)          // sec count
	clr.b 6(A1)              // features
	moveq #0,D0
	move.b D1,D0             // count
	add.l D0,D0
	asl.l #8,D0              // * 512 = bytes
	bsr ide_read
	unlk A6
	ble.s .end_read_sectors  // OK or time-out
	moveq #-11,D0            // read error
	bra.s .end_read_sectors		
.use_DMAread:
	move.w D4,-(SP)          // physical drive
	move.l A4,-(SP)          // buffer
	move.w D1,-(SP)          // count
	move.l D2,-(SP)          // sector
	move.w #0x2A,-(SP)       // DMAread
	trap #14
	lea 14(SP),SP
	ext.l D0
.end_read_sectors:
	tst.l D0
	bmi.s .end_read_sectors_swap
	tst.l D4                 // flag swap bytes
	bpl.s .end_read_sectors_swap
	move.l D0,-(SP)
	move.l A4,A0             // buffer
	move.w D3,D0             // count
	bsr swap_buffer
#if 0
#ifdef DEBUG
	bra.s .end_dump_sectors
.loop_dump_sectors:
		move.l A4,A1
		moveq #15,D1
		bsr dump
		move.w #7,-(SP)          // Crawcin
		trap #1
		addq.w #2,SP
		lea 256(A4),A1
		moveq #15,D1
		bsr dump
		move.w #7,-(SP)          // Crawcin
		trap #1
		addq.w #2,SP
		lea 512(A4),A4
.end_dump_sectors:
	dbf D3,.loop_dump_sectors
#endif	
#endif
	move.l (SP)+,D0
.end_read_sectors_swap:
	movem.l (SP)+,D1-D4/A0-A4
	rts
	
scsi_read:	// D0: drive, D1.L: DMA bytes, D2: bytes cmd, A0: DMA buffer, A1: buffer bytes cmd
	// return error code inside D0, and time speed test inside D1.L

	movem.l D2-D3/A0,-(SP)
	moveq #0,D3
	st.b flock
	bsr cmd_scsi
	bmi .sr4                // time-out
	move.w #0x89,0xFFFF8606 // Init-Command Register NCR5380
	move.w #0,0xFFFF8604
	move.w #0x8B,0xFFFF8606 // Target-Command Register
	move.w #1,0xFFFF8604
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w 0xFFFF8604,D0
	move.w #0x8A,0xFFFF8606 // Mode Register
	move.w #2,0xFFFF8604    // enable DMA
	move.l A0,-(SP)
	move.b 3(SP),0xFFFF860D
	move.b 2(SP),0xFFFF860B
	move.b 1(SP),0xFFFF8609
	addq #4,SP
	move.w #0x190,0xFFFF8606
	bsr mfp_delay
	move.w #0x90,0xFFFF8606 // DMA reading
	bsr mfp_delay
	move.l D1,D0            // num bytes DMA
	and.w #0x1FF,D1
	lsr.l #8,D0
	lsr.l #1,D0             // /512
	tst.w D1
	beq.s .sr3
	addq #1,D0
.sr3:
	move.w D0,0xFFFF8604    // sectors
.sr1:
	btst #3,0xFFFF860F
	bne.s .sr1
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w #0,0xFFFF8604
	move.w #0,0xFFFF8606    // read transfer
	bsr get_timer_c
	move.l D0,D3            // speed test	
	bsr wait_end_cmd_scsi
	bmi.s .sr4              // time-out
	and #0xF,D1
	beq.s .sr2
	move.w #0x20,0xFFFF8606
.sr2:
	bsr get_timer_c
	sub.l D3,D0
	move.l D0,D3	           // time speed test
	cpusha DC
	bsr get_status_scsi
	and.l #0xFF,D0          // error code
.sr4:
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w 0xFFFF8604,D1
	move.w #0x180,0xFFFF8606
	bsr mfp_delay
	move.w #0x80,0xFFFF8606 // Data register
	clr.w flock
	move.l D3,D1            // time speed test
	tst.l D0
	movem.l (SP)+,D2-D3/A0
	rts

get_status_scsi:

	move.l D1,-(SP)
	move.w #0x8B,0xFFFF8606 // Target-Command Register
	move.w #3,0xFFFF8604
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w 0xFFFF8604,D0
	move.w #0x8C,0xFFFF8606 // ID Select/SCSI Control Register
	move.l _hz_200,D1
.gs5:
		move.w 0xFFFF8604,D0 // DMA state
		btst #5,D0
		bne.s .gs2
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #TIME_OUT_CMD,D0
	blt.s .gs5
	bra.s .gs6
.gs2:
	move.w #0x88,0xFFFF8606           // Data register
	move.w 0xFFFF8604,D0
	and.l #0xFF,D0
	move.l D0,-(SP)
	bsr attention_scsi
	move.w #0x8C,0xFFFF8606           // ID Select/SCSI Control Register
	move.l _hz_200,d1
.gs3:
		move.w 0xFFFF8604,D0 // DMA state
		btst #5,D0
		bne.s .gs4
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #TIME_OUT_CMD,D0            // time-out 500 mS
	blt.s .gs3
	addq #4,SP
.gs6:
	moveq #-1,D0
	bra.s .gs1
.gs4:
	move.w #0x88,0xFFFF8606           // Data register
	move.w 0xFFFF8604,D0
	bsr attention_scsi
	move.l (SP)+,D0
.gs1:
	move.l (SP)+,D1
	tst.l D0
	rts
	
cmd_scsi: // D0: drive, D2: bytes cmd, A1: buffer bytes cmd
// return D0 < 0 => time-out

	movem.l D1-D3/A1,-(SP)
	move.w #0x8C,0xFFFF8606           // ID Select/SCSI Control Register
	move.l _hz_200,D1
.cs1:
		move.w 0xFFFF8604,D3 // DMA state
		btst #6,D3
		beq.s .cs2
		move.l _hz_200,D3
		sub.l D1,D3
		cmp.l #TIME_OUT_CMD,D3
	blt.s .cs1
	bra .cs7
.cs2:
	move.w #0x8B,0xFFFF8606 // Target-Command Register
	move.w #0,0xFFFF8604
	move.w #0x8C,0xFFFF8606 // ID Select/SCSI Control Register
	move.w #0,0xFFFF8604
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #0x0C,0xFFFF8604 
	moveq #0,D1
	and.w #7,D0 // SCSI drive
	bset D0,D1
	move.w #0x88,0xFFFF8606 // Data register
	move.w D1,0xFFFF8604
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #5,0xFFFF8604
	move.w #0x8A,0xFFFF8606 // Mode Register
	move.w 0xFFFF8604,D0
	and.b #0xFE,D0          // disable arbitration
	move.w D0,0xFFFF8604
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w 0xFFFF8604,D0
	and.w #0xF7,D0
	move.w D0,0xFFFF8604
	bsr mfp_delay
	move.w #0x8C,0xFFFF8606 // ID Select/SCSI Control Register
	move.l _hz_200,D1
.cs6:
		move.w 0xFFFF8604,D0 // DMA state
		btst #6,D0
		bne.s .cs3
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #TIME_OUT_CMD,D0
	blt.s .cs6
.cs7:
	move.w #0x89,0xFFFF8606      // Init-Command Register
	move.w #0,0xFFFF8604
	moveq #-1,D0                 // time-out
 	bra .cs5
.cs3:
	move.w #0x89,0xFFFF8606      // Init-Command Register
	move.w #0,0xFFFF8604
	move.w #0x8B,0xFFFF8606      // Target-Command Register
	move.w #2,0xFFFF8604
	move.w #0x89,0xFFFF8606      // Init-Command Register
	move.w #1,0xFFFF8604
	subq.w #1,D2                 // bytes cmd counter
	bmi.s .cs8
.cs4:                        
		move.l #TIME_OUT_CMD,D0
		bsr wait_hdc
		bmi.s .cs5      // time-out
		moveq #0,D0
		move.b (A1)+,D0 // byte cmd
		move.w #0x88,0xFFFF8606 // Data register
		move.w D0,0xFFFF8604
		bsr attention_scsi
	dbf D2,.cs4
.cs8:
	moveq #0,D0
.cs5:
	movem.l (SP)+,D1-D3/A1
	rts

attention_scsi:

	move.w D0,-(SP)
	move.w #0x89,0xFFFF8606      // Init-Command Register
	move.w 0xFFFF8604,D0
	or.b #0x11,D0
	move.w D0,0xFFFF8604
	and.b #0xEF,D0
	move.w D0,0xFFFF8604
	move.w (SP)+,D0
	rts

mfp_delay:

	tst.b 0xFFFFFA01
	tst.b 0xFFFFFA01
	tst.b 0xFFFFFA01
	tst.b 0xFFFFFA01
	rts

delay_hz_200: // inside D0.L

	movem.l D1/D2,-(SP)
	move.l _hz_200,D1
.dh1:	move.l _hz_200,D2
		sub.l D1,D2
	cmp.l D0,D2
	blt.s .dh1
	movem.l (SP)+,D1/D2
	rts

wait_hdc: // time-out inside D0.L, return D0 < 0 => time-out

	movem.l D1/D2,-(SP)
	move.l D0,D2 // time-out
	move.w #0x8C,0xFFFF8606 // ID Select/SCSI Control Register
	move.l _hz_200,D1
.wh1:
		move.w 0xFFFF8604,D0
		btst #5,D0
		bne.s .wh2
		move.l _hz_200,D0
		sub.l D1,D0
		cmp.l D2,D0
	blt.s .wh1
	moveq #-1,D0 // time-out
	bra.s .wh3
.wh2:
	moveq #0,D0
.wh3:
	movem.l (SP)+,D1/D2
	rts

wait_end_cmd_scsi: // return D0 < 0 => time-out

	move.l #TIME_OUT_4S,D0
	cmp #6,D2 // bytes cmd
	beq.s .wec3
	move.l #TIME_OUT_10S,D0
.wec3:
	move.l _hz_200,D1
.wec5:
		btst #5,0xFFFFFA01 // GPIP MFP 68901
		beq .wec2
		move.l _hz_200,D2
		sub.l D1,D2
	cmp.l D0,D2
	blt.s .wec5
.wec4:
	btst #3,0xFFFF860F
	bne.s .wec4
	move.w #0x190,0xFFFF8606
	bsr mfp_delay
	move.w #0x90,0xFFFF8606 // DMA reading
	bsr mfp_delay
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #0x80,0xFFFF8604
	move.l #TIME_OUT_CMD,D0
	bsr delay_hz_200        // reset
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #0,0xFFFF8604
	move.l #200,D0          // 1 S
	bsr delay_hz_200
	moveq #-1,D0            // error
	bra.s .wec1
.wec2:
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w 0xFFFF8604,D0
	move.w #0x8A,0xFFFF8606 // Mode Register
	move.w #0,0xFFFF8604    // disable DMA
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #0,0xFFFF8604
	moveq #0,D0             // OK
.wec1:
	rts

ide_read: 	// D0.L: bytes, A0: IDE buffer, A1: cmd buffer
	// return error code inside D0, and time speed test inside D1.L

	movem.l D2-D3/A0-A1,-(SP)
	st.b flock
	move.l D0,D2             // 0: non-data
	move.b 1(A1),0xFFF00019  // C/D/H
	moveq #0,D1
	move.b 2(A1),0xFFF00015  // cyl high
	move.b 3(A1),0xFFF00011  // cyl low
	move.b 4(A1),0xFFF0000D  // sector num
	move.b 5(A1),0xFFF00009  // sector count
	beq.s .ir7	
	move.w D0,D1             // bytes
	and.w #0x1FF,D1
	lsr.l #8,D0
	lsr.l #1,D0              // /512
	tst.w D1
	beq.s .ir6
	addq #1,D0
.ir6:
	moveq #0,D1
	move.b D0,D1
	beq.s .ir5
	subq.w #1,D1             // sector counter
.ir7:
	move.b 6(A1),0xFFF00005  // features (error when read)
	move.b #0,0xFFF00039     // control device, INTRQ on MFP IO5
 	move.b (A1),0xFFF0001D   // command
	bsr get_timer_c
	move.l D0,D3             // speed test
.ir4:
		move.l #TIME_OUT_CMD,D0
		tst.b 5(A1)       // sector count
		beq.s .ir8
		move.l #TIME_OUT_10S,D0
.ir8:
		bsr wait_end_cmd_ide
		bmi.s .ir1        // time-out
 		tst.l D2
 	             beq.s .ir9 	     // no data
		moveq #9,D0       // DRQ & ERR
		and.b 0xFFF0001D,D0   // state
		btst #3,D0        // DRQ
		beq.s .ir1        // error
		lea 0xFFF00000,A1 // IDE buffer
		moveq #15,D0      // 512 bytes
.ir3:
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
		dbf D0,.ir3
	dbf D1,.ir4
	bsr get_timer_c
	sub.l D3,D0
	move.l D0,D3	           // time speed test
.ir5:
	moveq #0,D0
	bra.s .ir1
.ir9:
	btst #0,0xFFF0001D        // state, ERR
	beq.s .ir5
	moveq #0,D0
	move.b 0xFFF00005,D0      // error register
	and.b #0x6E,D0            // WP, MC, MCR, ABRT, NM
	bra.s .ir1	
.ir2:
	moveq #-1,D0              // error, time-out
.ir1:
	move.b #2,0xFFF00039      // control device, no INTRQ on MFP IO5
	clr.w flock
	move.l D3,D1              // time speed test
	tst.l D0
	movem.l (SP)+,D2-D3/A0-A1
	rts
	
wait_end_cmd_ide:	// time-out inside D0.L, return D0 < 0 => time-out

	movem.l D1/D2,-(SP)
	move.l _hz_200,D1
.weci1:
		btst #5,0xFFFFFA01     // GPIP MFP 68901
		beq.s .weci2
		move.l _hz_200,D2
		sub.l D1,D2
	cmp.l D0,D2
	blt.s .weci1
	moveq #-1,D0 // time-out
	bra.s .weci3
.weci2:
	moveq #0,D0
.weci3:
	movem.l (SP)+,D1/D2
	rts
	
menu_boot:

	link A6,#-12
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	moveq #0xC,D0            // ALT or CTRL
	and.b (A0),D0
	bne .normal_boot
	pea -12(A6)              // buffer
	move.w #12,-(SP)         // size
	clr.w -(SP)              // start
	clr.w -(SP)              // read
	move.w #46,-(SP)         // NVMaccess
	trap #14
	lea 12(SP),SP
	move.w -12(A6),D5        // bootpref
	beq .normal_boot
	moveq #0,D4
	move.b -2(A6),D4         // bootdelay in seconds
	cmp.w #99,D4
	bcs.s .delay_ok
	moveq #99,D4             // bootdelay maxi
.delay_ok:
	mulu #200,D4             // timer 200 Hz
	bne.s .display_menu
	move.w #DEFAULT_BOOT_DELAY,D4
.display_menu:
	lea message77(PC),A0     // boot menu
	bsr display_string
.display_menu_again:
		lea tab_os(PC),A1
		moveq #2,D1
		moveq #0,D2
		moveq #0,D3
.display_menu_loop:	
			moveq #0x20,D0
			bsr display_char
			moveq #0x20,D0
			bsr display_char			
			move.b (A1),D0
			cmp.b -11(A6),D0     // bootpref
			bne.s .no_display_inv
			moveq #27,D0
			bsr display_char
			moveq #0x70,D0
			bsr display_char
.no_display_inv:
			lea message80(PC),A0 // TOS
			cmp.w #2,D1
			beq.s .display_line_os
			lea message81(PC),A0 // MagiC
			cmp.w #1,D1
			beq.s .display_line_os
			lea message82(PC),A0 // Linux
.display_line_os:
			bsr display_string_single
			move.b (A1)+,D0
			cmp.b -11(A6),D0     // bootpref
			bne.s .no_display_inv2
			moveq #27,D0
			bsr display_char
			moveq #0x71,D0
			bsr display_char
			move.w D2,D3
.no_display_inv2:
			lea crlf(PC),A0
			bsr display_string_single
			addq.w #1,D2
		dbf D1,.display_menu_loop
		move.l _hz_200,D7
		moveq #-1,D6
.wait_menu:
			move.l _hz_200,D0
			sub.l D7,D0
			cmp.l D4,D0
			bcc .end_boot_delay
			neg.l D0
			add.l D4,D0
			divu #200,D0
			cmp.w D0,D6
			beq.s .no_display_second
			move.w D0,D6
			lea message78(PC),A0
			bsr display_string
			moveq #0,D0
			move.w D6,D0
			divu #10,D0
			tst.w D0
			beq.s .delay_less_10
			or.w #0x30,D0
			bsr display_char
.delay_less_10:
			swap d0
			or.w #0x30,D0
			bsr display_char
			lea message79(PC),A0
			bsr display_string
.no_display_second:
			move.w #0xB,-(SP) //  Cconis
			trap #1
			addq.w #2,SP
			tst.w D0
			beq.s .wait_menu
			move.w #7,-(SP)   // Crawcin
			trap #1
			addq.w #2,SP
			cmp.w #0x20,D0    // SPACE
			beq .end_boot_delay
			cmp.w #13,D0      // ENTER
			beq .end_boot_delay
			swap D0           // scan-code
			cmp.w #0x48,D0    // UP
			beq.s .key_up
			cmp.w #0x50,D0    // DOWN
			beq.s .key_down
		bra.s .wait_menu
.key_up:
		moveq #2,D1
		subq.w #1,D3
		bpl.s .cursor_up_loop
		moveq #2,D3
		bra.s .cursor_up_loop
.key_down:	
		moveq #2,D1
		addq.w #1,D3
		cmp.w #3,D3
		bcs.s .cursor_up_loop
		moveq #0,D3
.cursor_up_loop:
			moveq #27,D0
			bsr display_char
			moveq #0x41,D0
			bsr display_char
		dbf D1,.cursor_up_loop
		moveq #13,D0
		bsr display_char
		lea tab_os(PC),A0
		move.b (A0,D3),-11(A6) // bootpref
	bra .display_menu_again
.end_boot_delay:
	cmp.w -12(A6),D5         // bootpref
	beq.s .unchanged
	pea -12(A6)              // buffer
	move.w #2,-(SP)          // size
	clr.w -(SP)              // start
	move.w #1,-(SP)          // write
	move.w #46,-(SP)         // NVMaccess
	trap #14
	lea 12(SP),SP
.unchanged:
	move.w -12(A6),D0        // bootpref
	cmp.w #0x80,D0           // TOS
	beq.s .normal_boot
	lea magxboot,A1	
	cmp.w #8,D0              // MagiC
	beq.s .call_boot
	cmp.w #0x10,D0           // Linux
	bne.s .normal_boot
	lea ataboot,A1
.call_boot:
	move.l #0x5F465245,D0    // _FRE cookie, external clock
	bsr get_cookie
	move.l D0,D2
	move.l #0x5F465251,D0    // _FRQ cookie, internal clock
	bsr get_cookie
	move.l D0,D1
	move.l #0x5F465055,D0    // _FPU cookie
	bsr get_cookie
	add.l #0xE80000,A1
	sub.l #_ct60tos_half_flash,A1
	jsr (A1)
.normal_boot:
	unlk A6
	tst.w _cmdload
	beq.s .no_command
	lea message95(PC),A0     // start AUTO folder
	bsr display_string
	bsr auto_exec
	move.l #0xE00000,_sysbase
	pea null(PC)             // env
	pea null(PC)             // command
	pea 0xE00842             // file COMMAND.PRG
	clr.w -(SP)              // load'n go
	bra .go_pexec
.no_command:
	lea message95(PC),A0     // start AUTO folder
	bsr display_string
	bsr auto_exec
	move.l #0xE00000,_sysbase
	lea 0xE00836,A0          // PATH= ...
	lea 0x840,A1
	move.l A1,A2
.loop_copy_env:
		cmp.b #0x23,(A0)
		bne.s .no_drive_letter
		move.l A1,A2
.no_drive_letter:
		move.b (A0)+,(A1)+
	bpl.s .loop_copy_env
	move.w _bootdev,D0
	add.b #0x41,D0
	move.b D0,(A2)
	lea message96(PC),A0     // start GEM
	bsr display_string
	pea 0x840                // env
	pea null(PC)             // command
	pea null(PC)             // file
	move.w #5,-(SP)          // create basepage
	move.w #0x4B,-(SP)       // Pexec
	trap #1
	add.w #16,SP
	tst.l D0
	bpl.s .basepage_ok
	bsr error_tos
	jmp 0xE00030             // reset
.basepage_ok:
	move.l D0,A0             // basepage
	move.l exec_os,8(A0)
	pea 0x840                // env
	pea (A0)                 // command
	pea null(PC)             // file
	move.w #4,-(SP)          // run GEM
.go_pexec:
	move.w #0x4B,-(SP)       // Pexec
	trap #1
	add.w #16,SP
	jmp 0xE00030             // reset

error_tos:

	move.l D0,-(SP)
	pea message94(PC)        // error TOS
	move.w #9,-(SP)          // Cconws
	trap #1
	addq.w #6,SP
	move.l (SP)+,D0
	neg.l d0
	link A6,#-4
	clr -2(A6)
	lea -4(A6),A0
             moveq #3,D1
	bsr conv_ascii_value_optimized
	pea -4(A6)
	move.w #9,-(SP)          // Cconws
	trap #1
	addq.w #6,SP
	unlk a6
	move.w #7,-(SP)          // Crawcin
	trap #1
	addq.w #2,SP
	rts

auto_exec:

	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D0
	btst #2,D0               // CTRL
	bne.s .end_auto_exec
	move.l _drvbits,D0
	move.w _bootdev,D1
	btst D1,D0
	beq.s .end_auto_exec     // no boot drive
	lea 0xE010EE,A0          // \AUTO\*.PRG
	lea 0xE010F4,A1          // *.PRG
	move.l (SP)+,0xAE4       // PC
	move.l A0,0xAE8          // path
	move.l A1,0xAEC          // file
	lea null(PC),A0
	pea (A0)
	pea (A0)
	pea (A0)	
	move.w #5,-(SP)          // create basepage
	move.w #0x4B,-(SP)       // Pexec
	trap #1
	add.w #16,SP
	tst.l D0
	bpl.s .basepage_ok_2
	bsr error_tos
	bra.s .end_auto_exec_2
.basepage_ok_2:
	move.l D0,A0             // basepage
	lea auto_exec_prg(PC),A1
	move.l A1,8(A0)
	pea null(PC)             // env
	pea (A0)                 // command
	pea null(PC)             // file
	move.w #4,-(SP)          // run prg
	move.w #0x4B,-(SP)       // Pexec
	trap #1
	add.w #16,SP
	tst.l D0
	bpl.s .end_auto_exec_2
	bsr error_tos
.end_auto_exec_2:
	move.l 0xAE4,-(SP)       // return adress
.end_auto_exec:
	rts
	
auto_exec_prg:
	
	clr.l -(SP)
	move.w #0x20,-(SP)       // Super
	trap #1
	addq.w #6,SP
	move.l 4(SP),A6          // basepage
	lea 256(A6),SP
	move.l #256,-(SP)        // size
	pea (A6)                 // old stack
	clr.w -(SP)              // dummy
	move.w #0x4A,-(SP)       // Mshrink
	trap #1
	add.w #12,SP
	tst.w D0
	bne .end_auto_prg        // error
	move.w #7,-(SP)          // all files
	move.l 0xAE8,-(SP)       // path
	move.w #0x4E,-(SP)       // Fsfirst
	moveq #8,D7              // for fix stack
.loop_auto_folder:
		pea 0xAF0            // buffer
		move.w #0x1A,-(SP)   // Fsetdta
		trap #1
		addq.w #6,SP
		trap #1              // Fsfirst or Fsnext
		add.w D7,SP
		tst.w D0
		bne .end_auto_prg    // error
		move.l 0xAE8,A0      // path
		move.l 0xAEC,A2      // file
		lea 0xB1C,A1         // auto name
.loop_copy_path:
			move.b (A0)+,(A1)+
		cmp.l A2,A0
		bcs.s .loop_copy_path
		lea 0xB0E,A0         // name from dta buffer
.loop_copy_name:
		move.b (A0)+,(A1)+
		bne.s .loop_copy_name
		move.w #13,-(SP)
		move.w #2,-(SP)      // Cconout
		trap #1
		move.w #10,-(SP)
		move.w #2,-(SP)      // Cconout
		trap #1
		addq.w #8,SP
		cmp.w #2,0x3E86      // number of planes
		bls.s .black_and_white_3
		pea blue(PC)
		move.w #9,-(SP)      // Cconws
		trap #1
		addq.w #6,SP
.black_and_white_3:
		pea 0xB1C            // auto name
		move.w #9,-(SP)      // Cconws
		trap #1
		addq.w #6,SP
		cmp.w #2,0x3E86      // number of planes
		bls.s .black_and_white_4
		pea black(PC)
		move.w #9,-(SP)      // Cconws
		trap #1
		addq.w #6,SP
.black_and_white_4:
		move.w #13,-(SP)
		move.w #2,-(SP)      // Cconout
		trap #1
		move.w #10,-(SP)
		move.w #2,-(SP)      // Cconout
		trap #1
		addq.w #8,SP
		pea null(PC)        // env
		pea null(PC)        // command
		pea 0xB1C           // auto name
		clr.w -(SP)         // load'n go
		move.w #0x4B,-(SP)  // Pexec
		trap #1
		add.w #16,SP
		tst.l D0
		bpl.s .pexec_ok
		cmp.l #-66,D0
		beq.s .pexec_ok
		bsr error_tos
		bra.s .end_auto_prg
.pexec_ok:
		moveq #2,D7         // for fix stack
		move.w #0x4F,-(SP)  // Fsnext
	bra .loop_auto_folder
.end_auto_prg:
	lea 0x8870,SP            // stack
	move.l 0xAE4,-(SP)       // return adress
	rts	

init_flash_parameters:

	moveq #14,D7
.loop_init_params:
		move.l #-1,-(SP)
		move.l D7,-(SP)
		move.w #CT60_MODE_WRITE,-(SP)
		move.w #rw_parameter,-(SP)
		trap #14
		lea 12(SP),SP
		cmp.l #-1,D0
             dblt D7,.loop_init_params
	jmp 0xE0398C             // reset
	
fix_bug_nvdi:

	movec.l CACR,D0
	move.l D0,-(SP)
	jsr 0xE0085A             // caches off
	moveq #3,D0
	jsr 0xE34348             // v_opnwk
	cmp.l #0xA0808000,(SP)+
	bne.s .no_caches	
	jsr 0xE250C8             // caches on	
.no_caches:
	rts

display_device_type:	// type inside D0
		
	movem.l D0-D3/A0,-(SP)
	move.w D0,D3	
	moveq #10,D1
	move.l #0x5F414B50,D0    // _AKP cookie
	bsr get_cookie
	lsr.w #8,D0
	cmp.w #2,D0              // FRA
	beq.s .display_french
	cmp.w #7,D0              // SWF
	bne.s .display_english
.display_french:
	add.w #11,D3
	add.w #11,D1
.display_english:
	lea list_device_type(PC),A0
	moveq #0,D2
.device_type_loop:
		cmp.b D2,D3
		beq.s .device_type_found
.next_device_type:        
		tst.b (A0)+
		bne.s .next_device_type
		addq.w #1,D2
	dbf D1,.device_type_loop
	bra .read_root
.device_type_found:
		move.b (A0),D0
		bsr display_char
	tst.b (A0)+
	bne.s .device_type_found
             movem.l (SP)+,D0-D3/A0
	rts
	
display_ram_test:

	movem.l D0/D1/A0,-(SP)
	link A6,#-8
	clr -2(A6)
	lea -8(A6),A0
	moveq #6,D1
	bsr conv_ascii_value
	lea -8(A6),A0
	bsr display_string_single
	unlk A6
	movem.l (SP)+,D0/D1/A0
	rts

conv_ascii_value_optimized:           // A0:target ascii, D0.L:value, D1:len

	move.l A1,-(SP)
	link A6,#-16
	move.l A0,-(SP)
	lea -16(A6),A0
	move.w D1,-(SP)
	bsr conv_ascii_value
	move.w (SP)+,D1
	move.l (SP)+,A0
	lea -16(A6),A1
	subq.w #1,D1
	bmi.s .co3
.co1:
		move.b (A1)+,D0
		cmp.b #0x20,D0
		beq.s .co2
		move.b D0,(A0)+
.co2:
	dbf D1,.co1
	clr.b (A0)
.co3:
	unlk A6
	move.l (SP)+,A1
	rts
	
conv_ascii_value:                     // A0:target ascii, D0.L:value, D1:len

	move.w D1,-(SP)
	subq.w #1,D1
	move.l D0,-(SP)
.dv1:
		moveq #0,D0
		move.w (SP),D0
		divu #10,D0
		move.w D0,(SP)
		move.w 2(SP),D0
		divu #10,D0
		move.w D0,2(SP)
		swap D0
		or.w #0x30,D0
		move.b D0,(A0,D1.w)
	dbf D1,.dv1
	addq.w #4,SP
	move.w (SP)+,D1
	subq.w #1,D1
	beq.s .dv2
	swap D0
	tst.w D0
	bne.s .dv3
	moveq #0,D0
.dv4:
		cmp.b #0x30,(A0,D0.w)
		bne.s .dv2
		move.b #0x20,(A0,D0.w)
		addq.w #1,D0
	cmp.w D1,D0
	bne.s .dv4
	bra.s .dv2
.dv3:
	move.b #0x3F,(A0,D1.w)
	dbf D1,.dv3
.dv2:
	rts

display_xbra:

	movem.l D0/A0/A1,-(SP)
	link A6,#-6
	clr.w -2(A6)
	move.l A0,A1
.loop_xbra:
		lea message49(PC),A0
		bsr display_string_single
		cmp.l #0x58425241,-12(A1) // XBRA
		bne.s .no_xbra
		move.l -8(A1),-6(A6)
		lea -6(A6),A0
		bsr display_string_single // ID
		move.l -4(A1),D0          // next
		beq.s .end_xbra
		move.l D0,A1
	bra.s .loop_xbra
.no_xbra:
	lea message50(PC),A0
	bsr display_string
.end_xbra:
	unlk A6
	movem.l (SP)+,D0/A0/A1
	rts
	
get_timer_c:

	move.l D1,-(SP)
	move SR,-(SP)
	or #0x700,SR             // no interrupts
	move.l _hz_200,D0
	asl.l #8,D0
	moveq #0,D1
	move.b 0xFFFFFA23,D1     // TCDR timer C MFP
	subq.b #1,D1             // 0-191
	asl.l #8,D1              // * 256
	divu #192,D1             // 0-255
	not.b D1
	move.b D1,D0
	move.w (SP)+,SR
	move.l (SP)+,D1
	rts
	
display_mb_by_sec_disk:                // D0: total time
	
	movem.l D0-D1/A0,-(SP)
	move.l #(SPEED_BUFFER_SIZE*256)/500,D1 // buffer test size * 256
	divu D0,D1
	link A6,#-6
	clr.w -2(A6)
	lea -4(A6),A0
	moveq #0,D0
	move.w D1,D0
	moveq #2,D1
	bsr conv_ascii_value
	move.b -3(A6),-2(A6)
	move.b #0x2E,-3(A6)
	bsr display_string_single
	unlk A6
	lea message89(PC),A0     // MB/S
	bsr display_string
	movem.l (SP)+,D0-D1/A0
	rts
	
display_value_ns_10:

	movem.l D0/A0,-(SP)
	link A6,#-4
	clr -2(A6)
	move.w D0,-(SP)
	and.l #0xFF,D0
	lsr.w #4,D0
	lea -4(A6),A0
             moveq #2,D1
	bsr conv_ascii_value_optimized
	lea -4(A6),A0
	bsr display_string_single
	moveq #0x2E,D0
	bsr display_char
	moveq #0x0F,D0
	and.w (SP)+,D0
	lea -3(A6),A0
             moveq #1,D1
	bsr conv_ascii_value_optimized
	lea -3(A6),A0
	bsr display_string_single
	lea message59(PC),A0
	bsr display_string_single
	unlk A6
	movem.l (SP)+,D0/A0
	rts
	
display_value_ns:

	movem.l D0/A0,-(SP)
	link A6,#-4
	clr -2(A6)
	and.l #0xFF,D0
	lea -4(A6),A0
             moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -4(A6),A0
	bsr display_string_single
	lea message59(PC),A0
	bsr display_string_single
	unlk A6
	movem.l (SP)+,D0/A0
	rts	
	
display_latency:

	movem.l D0-D4/A0,-(SP)
	move.l D0,D4	
	moveq #0,D1
	moveq #0,D2
	moveq #6,D3
.loop_latency:
		btst D1,D4
		beq.s .next_latency
		tst.w D2
		beq.s .first_latency
		moveq #0x2F,D0
		bsr display_char
.first_latency:
	             moveq #-1,D2
		moveq #0x30,D0
		add.w D1,D0
		bsr display_char
.next_latency:
		addq.w #1,D1
	dbf D3,.loop_latency	
	movem.l (SP)+,D0-D4/A0
	rts

display_string:

	movem.l D0/A0,-(SP)	
	move.l A0,-(SP)
	move.l #0x5F414B50,D0    // _AKP cookie
	bsr get_cookie
	move.l (SP)+,A0
	lsr.w #8,D0
	cmp.w #2,D0              // FRA
	beq.s .french
	cmp.w #7,D0              // SWF
	bne.s .english
.french:
	tst.b (A0)+
	bne.s .french
.english:
	bsr display_string_single	
	movem.l (SP)+,D0/A0
	rts

display_string_single:

	movem.l D0/A0,-(SP)
.os2:
	move.b (A0)+,D0
	beq.s .os1
	bsr display_char
	bra.s .os2
.os1:
	movem.l (SP)+,D0/A0
	rts

hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s hex_word
	move.l (SP)+,D0
hex_word:
	move.w D0,-(SP)
	lsr.w #8,D0          
	bsr.s hex_byte     
	move.w (SP)+,D0
hex_byte:
	move.w D0,-(SP)
	lsr.b #4,D0        
	bsr.s hex_char      
	move.w (SP)+,D0      
hex_char:
	and.b #0xF,D0      
	or.b #0x30,D0      
	cmp.b #0x3A,D0     
	bcs.s display_char  
	addq.b #7,D0   

display_char:

	movem.l D0-D2/A0-A2,-(SP)
	move.w D0,-(SP)
	move.w #2,-(SP)
	move.w #3,-(SP)          // Bconout
	trap #13
	addq.w #6,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts
	
//conv_bcd:

//	and.l #0xFFFF,D0
//	divu #10,D0
//	move.w D0,D1
//	swap D0
//	asl.w #4,D1
//	or.w D1,D0
//	move.b D0,(A0)
//	rts
	
//settime_ikbd:

//	movem.l D0-A2,-(SP)
//	link A6,#-8
//	move.l D0,D5
//	move.b #0x1B,-8(A6)      // Settime IKBD
//	move.w D5,D0
//	and.w #0x1F,D0
//	add.w D0,D0
//	lea -2(A6),A0
//	bsr conv_bcd             // seconds
//	lsr.l #5,D5
//	move.w D5,D0
//	and.w #0x3F,D0
//	lea -3(A6),A0
//	bsr conv_bcd             // mn
//	lsr.l #6,D5
//	move.w D5,D0
//	and.w #0x1F,D0
//	lea -4(A6),A0
//	bsr conv_bcd             // hours
//	lsr.l #5,D5
//	move.w D5,D0
//	and.w #0x1F,D0
//	lea -5(A6),A0
//	bsr conv_bcd             // day
//	lsr.l #5,D5
//	move.w D5,D0
//	and.w #0xF,D0
//	lea -6(A6),A0
//	bsr conv_bcd             // month
//	lsr.l #4,D5
//	move.w D5,D0
//	and.w #0x7F,D0
//	add.w #80,D0
//	cmp.w #100,D0
//	bcs.s .year_ikbd
//	sub.w #100,D0
//.year_ikbd:
//	lea -7(A6),A0
//	bsr conv_bcd             // year
//	pea -8(A6)	
//	move.w #6,-(SP)
//	move.w #0x19,-(SP)       // Ikbdws
//	trap #14 
//	addq.w #8,SP
//	unlk A6
//	movem.l (SP)+,D0-A2
//	rts
	
test_keyboard:
	
	movem.l D0-A5,-(SP)
	link A6,#-8
	clr.l -(SP)
	move.l #CT60_SAVE_NVRAM_1,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	swap D0
	cmp.w #0x4E56,D0         // NV magic code
	beq .rtc_bypass
	move.w #0x17,-(SP)       // Gettime
	trap #14
	addq.w #2,SP
	move.l D0,D7
	move.l D0,-(SP)
	jsr 0xE022CA             // Settime IKBD
	addq.w #4,SP
//	bsr settime_ikbd
	jsr 0xE022A0             // Gettime IKBD
//	and.l #0x01FFFFFF,D0     // remove year because this call has a year 2000 bug 
	tst.b 0x11C4
	bpl.s .keyboard_answer
.keyboard_error_2:
	lea message76(PC),A0     // keyboard failure
	bsr display_string
	bra .no_buffer
.keyboard_answer:
//	and.l #0x01FFFFFF,D7
	sub.l D7,D0
	bmi.s .keyboard_error_2
	cmp.l #1,D0
	bhi.s .keyboard_error_2
.rtc_bypass:	
	clr.w -(SP)              // stram
	move.l #0x2000,-(SP)     // 8K
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.w #8,SP
	tst.l D0
	ble .no_buffer
	move.l D0,A5             // buffer
	move.l phystop,A4        // use internal statvec
	move.l A5,pbuf_statvec(A4)
	move.l #0xCAFEFADE,flag_statvec(A4)
	move.b #0x12,-4(A6)      // IKBD mouse off
	move.b #0x21,-3(A6)      // IKBD read memory
	move.b #0x8F,-2(A6)      // Eiffel 0x0FFF flash memory
	move.b #0xFF,-1(A6)
	pea -4(A6)
	move.w #3,-(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.w #8,SP
	move.l _hz_200,D1
.wait_answer:
		move.l _hz_200,D0
		sub.l D1,D0
		cmp.l #20,D0          // time-out 100 mS
		bge .keyboard_error
	cmp.l pbuf_statvec(A4),A5
	beq.s .wait_answer
	lea message75(PC),A0     // keyboard OK
	bsr display_string
	move.l A5,pbuf_statvec(A4)
	move.b #0x21,-4(A6)      // IKBD read memory
	move.b #0x90,-3(A6)      // Eiffel 0x1000 flash memory
	clr.b -2(A6)
	tst.w (A5)
	beq.s .eiffel_2nd_bank_ok
	cmp.w #0x3FFF,(A5)
	bne .end_test_keyboard
	move.b #0x80,-3(A6)      // Eiffel 0x0000 flash memory
.eiffel_2nd_bank_ok:
	move.l A5,A3
	move.w #(256/6),D7
.loop_read_eiffel:
		pea -4(A6)
		move.w #2,-(SP)
		move.w #0x19,-(SP)    // Ikbdws
		trap #14 
		addq.w #8,SP
		move.l _hz_200,D1
.wait_answer_keyb:
			move.l _hz_200,D0
			sub.l D1,D0
			cmp.l #20,D0 // time-out 100 mS
			bge .keyboard_error
		cmp.l pbuf_statvec(A4),A3
		beq.s .wait_answer_keyb
		move.l pbuf_statvec(A4),A3
		add.w #3,-3(A6)       // next word
	dbf D7,.loop_read_eiffel
	move.l A5,A0             // buffer
	move.w #(256/2)-7,D1
.loop_find_name:
		move.l A0,A2
		lea name1(PC),A1
		moveq #5,D0
.compare_name:
			addq.l #1,A2
			cmpm.b (A1)+,(A2)+
		dbne D0,.compare_name
		beq.s .eiffel_found			
		addq.l #2,A0
	dbf D1,.loop_find_name
	bra .end_test_keyboard
.eiffel_found:                        // display eiffel version
		addq.l #1,A0
		move.b (A0)+,D0
		beq.s .end_eiffel_found
		bsr display_char
	bra.s .eiffel_found
.end_eiffel_found:
	move.b #0x20,-4(A6)      // IKBD load memory
	move.b #0x01,-3(A6)      // Eiffel 0x120 ram memory
	move.b #0x20,-2(A6)
	move.b #8,-1(A6)         // 8 bytes
	pea -4(A6)
	move.w #3,-(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.w #8,SP
	move.l #0x43543630,D0    // CT60
	bsr get_cookie
	lea -8(A6),A0
	moveq #4,D1              // CPU speed * 10 saved inside init_sdram
	bsr conv_ascii_value
	move.b -5(A6),-4(A6)
	move.b #0x2E,-5(A6)
	move.b #0x4D,-3(A6)      // MHz
	move.b #0x48,-2(A6)
	move.b #0x7A,-1(A6)
	pea -8(A6)
	move.w #7,-(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.w #8,SP
	bra.s .end_test_keyboard
.keyboard_error:	
	lea message76(PC),A0     // keyboard failure
	bsr display_string
.end_test_keyboard:
	move.b #0x08,-4(A6)      // IKBD mouse on
	pea -4(A6)
	clr.w -(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.w #8,SP
	clr.l flag_statvec(A4)   //  not use internal statvec
	move.l A5,D0
	beq.s .no_buffer
	move.l D0,-(SP)
	move.w #0x49,-(SP)       // Mfree
	trap #1 
	addq.w #6,SP
.no_buffer:
	unlk A6
	movem.l (SP)+,D0-A5
	rts

add_sdram:

	movem.l D1-D7/A1-A5,-(SP)
	lea message15(PC),A0     // boot version
	bsr display_string_single
	lea message15b(PC),A0
	bsr display_string
	clr.l -(SP)
	move.l #CT60_BOOT_ORDER,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	btst #2,D0               // old boot
	bne.s .old_boot
	bsr test_keyboard
.old_boot:
	cmp.l #0x1357BD13,ramvalid
	bne .not_sdram
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D0
	and.b #0xF,D0
	cmp.b #0x1,D0            // RSHIFT
	bne.s .not_infos
	lea message19(PC),A0
	bsr display_string
	bsr display_infos_sdram
	move.w #7,-(SP)          // Crawcin
	trap #1
	addq.w #2,SP
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
.not_infos:
	move.l #0x01000000,D1
	move.l ramtop,D0
	sub.l D1,D0
	ble .not_sdram
	move.l D0,-(SP)          // size
	move.l D1,-(SP)          // start
	move.l D1,A4
	add.l D0,A4
	move.l D0,D7
	lsr.l #8,D7
	lea message16(PC),A0
	bsr display_string       // init SDRAM
	move.l _hz_200,A5
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
.init_sdram:
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
		dbf D6,.init_sdram
		moveq #0x2E,D0	
		bsr display_char
		moveq #0,D0
	dbf D7,.init_sdram
	move.l _hz_200,D1
	sub.l A5,D1
	move.l 4(SP),D0          // size
	divu.l D1,D0
	divu.l #500,D0
	link A6,#-6
	clr.w -2(A6)
	lea -6(A6),A0
	moveq #4,D1
	bsr conv_ascii_value
	move.b -3(A6),-2(A6)
	move.b #0x2E,-3(A6)
	bsr display_string_single
	unlk A6
	lea message17(PC),A0     // MB/S
	bsr display_string
	move.w #0x14,-(SP)       // Maddalt
	trap #1 
	lea 10(SP),SP	
             tst.l D0
             bmi .not_sdram
	clr.w -(SP)              // stram
	move.l #0x10000+16,-(SP) // 64K
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.w #8,SP
	tst.l D0
	ble.s .not_sdram
	addq.l #8,D0
	addq.l #7,D0
	and.b #0xF0,D0           // 16 bytes alignment
	move.l D0,A1             // fastram buffer
	clr.w -(SP)              // stram
	move.l #XFRB_SIZE+16+20,-(SP) // 64K
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.w #8,SP
	tst.l D0
	ble.s .not_sdram
	move.l D0,A2             // XFRB struct
	lea 18(A2),A0
	move.w #0x101,(A2)       // version
	move.l A0,2(A2)          // xflock
	clr.w (A0)+
	move.l A0,D0
	addq.l #8,D0
	addq.l #7,D0
	and.b #0xF0,D0           // 16 bytes alignment
	move.l D0,6(A2)          // buffer
	move.l #XFRB_SIZE,10(A2) // size buffer
	clr.l 14(A2)             // next XFRB struct
	move.l cookie,D0
	beq.s .not_sdram
	move.l D0,A0
.find_cookie:
		tst.l (A0)
		beq.s .cookie_free
		addq.w #8,A0
	bra.s .find_cookie
.cookie_free:
	move.l 4(A0),12(A0)      // copy size
	move.l #0x5F465242,(A0)+ // _FRB
	move.l A1,(A0)+
	move.l 4(A0),12(A0)      // copy size
	move.l #0x58465242,(A0)+ // XFRB
	move.l A2,(A0)+
	clr.l (A0)
.not_sdram:
	bsr init_cookie_ct60
	moveq #3,D0
	jsr 0xE00BD2
	move.l hdv_boot,A0
	jsr (A0)
	tst.w D0
	bne.s .no_boot
	move.l _dskbufp,A0
	jsr (A0)
.no_boot:
	movem.l (SP)+,D1-D7/A1-A5
	rts
 
ct60_read_info_sdram:        // A0: 128 bytes buffer, D0 return error

	movem.l D1-D3/A0-A3,-(SP) 
	move.l A0,A3
	move.w SR,-(SP)
	or #0x700,SR             // no interrupts
	lea .i1(PC),A0
	move.l 8,A1              // bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         // timer C value changed at each 26 uS (clock 19,2 KHz)
	tst.b _tbcr_mfp
	bne.s .i6                // timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           // clock = 78,125 KHz (value changed at each 6,4 uS)
	move.b #3,_tbcr_mfp      // 2,4576MHz/16
.i6:
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	bsr write_device_i2c
	moveq #0,D0              // write adress
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne .i3                  // no acknoledge
	moveq #0,D0
	bsr write_bit_wait_slave_i2c // adress 1st bit
	moveq #6,D2              // 8 bits
.i4:         	moveq #0,D0          // adress
		bsr write_bit_i2c
	dbf D2,.i4
	bsr read_bit_i2c         // ack
	bne.s .i3                // no acknoledge
	bsr start_bit_wait_slave_i2c
	bsr write_device_i2c
	moveq #1,D0              // read data
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne.s .i3                // no acknoledge
	moveq #127,D3            // 128 bytes
.i8:
		moveq #0,D1          // data
		bsr read_bit_wait_slave_i2c  // 1st bit
		lsr.l #1,D0          // data
		addx.w D1,D1
		moveq #6,D2          // 8 bits
.i5:
			bsr read_bit_i2c
			lsr.l #1,D0      // data
			addx.w D1,D1
		dbf D2,.i5
		move.b D1,(A3)+
		tst D3
		seq.b D0
		and #1,D0            // ack master = 1 => no other byte
		bsr write_bit_i2c
	dbf D3,.i8
	bsr stop_bit_i2c
	moveq #0,D0                  //  OK
	bra.s .i2
.i3:
	bsr stop_bit_i2c
	moveq #CT60_READ_ERROR,D0    // error
	bra.s .i2
.i1:
	moveq #CT60_READ_ERROR,D0    // bus error
	move.l A1,8
	move.l A2,SP
.i2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s .i7
	clr.b _tbcr_mfp          // timer B stopped
.i7:
	move.w (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D3/A0-A3
	rts

ct60_configure_sdram:

	movem.l D1-D2/A0-A1,-(SP)
	lea _sdcnf,A0
	moveq #2,D0              // memory type
	bsr read_i2c_sdram
	bmi .c1                  // error
	cmp #4,D0                // SDRAM
	beq.s .c13
	moveq #CT60_SDRAM_TYPE_ERROR,D0
	bra .c1 
.c13:
	moveq #3,D0              // number of row adresses
	bsr read_i2c_sdram
	bmi .c1                  // error
	move.w D0,D1
	moveq #4,D0              // number of column adresses
	bsr read_i2c_sdram
	bmi .c1                  // error
	lea chip_density(PC),A1
.c3:
		tst.w (a1)
		ble.s .c2                // not found => chip density error
		cmp.w (A1),D1            // number of raw adresses
		bne.s .c4
		cmp.w 2(A1),D0           // number of column adresses
		beq.s .c5                // found
.c4:
		addq.w #8,A1
	bra.s .c3
.c2: 
	moveq #CT60_CHIP_DENSITY_ERROR,D0
	bra .c1
.c5:
	add.l 4(A1),A0           // chip density on A23-A22 cdy2-1
	moveq #12,D0             // refresh rate
	bsr read_i2c_sdram
	bmi .c1                  // error
	and.w #0x7F,D0
	cmp.w #5,D0
	bhi.s .c16               // error
	cmp.w #1,D0
	beq.s .c16               // 3.9 uS => error
	cmp.w #2,D0
	bne.s .c17
	add.l #0x10000,A0        // A16 7.81 uS
	bra.s .c17	
.c16:
	moveq #CT60_REFRESH_RATE_ERROR,D0
	bra .c1
.c17:		
	moveq #5,D0              // number of DIMM banks
	bsr read_i2c_sdram
	bmi .c1                  // error
	cmp.w #1,D0
	beq.s .c6
	cmp.w #2,D0
	bne.s .c7                // num bank error
	add.l #0x100000,A0       // A20
	bra.s .c6
.c7: 
	moveq #CT60_NUM_BANK_ERROR,D0
	bra .c1
.c6:
	move.w d0,d1             // number of DIMM banks
	moveq #6,D0              // module data width
	bsr read_i2c_sdram
	bmi .c1                  // error
	cmp.w #0x40,D0
	beq.s .c18               // 64
	cmp.w #0x48,D0           // 72
	bne.s .c11               // data width error
.c18:
	moveq #7,D0              // module data width
	bsr read_i2c_sdram
	bmi .c1                  // error
	beq.s .c14
.c11:
	moveq #CT60_DATA_WIDTH_ERROR,D0
	bra .c1
.c14:
	moveq #8,D0              // voltage interface
	bsr read_i2c_sdram
	bmi .c1                  // error
	cmp.w #1,D0              // LVTTL
	beq.s .c12
	moveq #CT60_VOLTAGE_ERROR,D0
	bra .c1
.c12:
	moveq #17,D0             // number of banks on SDRAM device
	bsr read_i2c_sdram
	bmi.s .c1                // error
	cmp.w #4,D0
	bne.s .c7                // num bank error
	moveq #31,D0             // module density
	bsr read_i2c_sdram
	bmi.s .c1                // error
	cmp.w #8,D0
	beq.s .c10               // 32
	cmp.w #16,D0
	beq.s .c10               // 64
	cmp.w #32,D0
	beq.s .c10               // 128
	cmp.w #64,D0
	beq.s .c10               // 256
	cmp.w #128,D0	
	bne.s .c8                // <> 512 => module density error
.c10:
	mulu D1,D0               // * number of DIMM banks
	asl.w #2,D0              // MB
	cmp.w #64,D0
	beq.s .c9
	cmp.w #128,D0
	beq.s .c9
	cmp.w #256,D0
	beq.s .c9
	cmp.w #512,D0
	beq.s .c9
.c8: 
	moveq #CT60_MOD_DENSITY_ERROR,D0
	bra.s .c1
.c9:
	lsr.w #7,d0
	cmp.w #3,d0
	bcs.s .c15
	moveq #3,D0
.c15:
	move.l D0,D1
	swap D1
	asl.l #2,D1
	add.l D1,A0              // size on A19-A18 mdy2-1
	clr.l (A0)               // write config
	move.l A0,D1
	swap D1
	move.b D1,memctrl+1      // save config A23-A16
	tst.l D0                 // return size 0-3 for 64MB-512MB
.c1:
	movem.l (SP)+,D1-D2/A0-A1
	rts
 
read_i2c_sdram:              // D0: adress, D0 return data or error

	movem.l D1-D2/A0-A2,-(SP)
	move.w SR,-(SP)
	or #0x700,SR             // no interrupts
	lea .r1(PC),A0
	move.l 8,A1              // bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         // timer C value changed at each 26 uS (clock 19,2 KHz)
	tst.b _tbcr_mfp
	bne.s .r6                // timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           // clock = 78,125 KHz (value changed at each 6,4 uS)
	move.b #3,_tbcr_mfp      // 2,4576MHz/16
.r6:
	move.w D0,D1             // adress
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	bsr write_device_i2c
	moveq #0,D0              // write adress
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne .r3                  // no acknoledge
	moveq #0,D0
	add.b D1,D1  
	addx.b D0,D0             // adress 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              // 8 bits
.r4:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         // adress
		bsr write_bit_i2c
	dbf D2,.r4
	bsr read_bit_i2c         // ack
	bne.s .r3                // no acknoledge
	bsr start_bit_wait_slave_i2c
	bsr write_device_i2c
	moveq #1,D0              // read data
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne.s .r3                // no acknoledge
	moveq #0,D1              // data
	bsr read_bit_wait_slave_i2c // 1st bit
	lsr.l #1,D0              // data
	addx.w D1,D1
	moveq #6,D2              // 8 bits
.r5:
		bsr read_bit_i2c
		lsr.l #1,D0          // data
		addx.w D1,D1
	dbf D2,.r5
	moveq #1,D0              // ack master = 1 => no other byte
	bsr write_bit_i2c
	bsr stop_bit_i2c
	moveq #0,D0
	move.w D1,D0             // 8 bits data
	bra.s .r2
.r3:
	bsr stop_bit_i2c
	moveq #CT60_READ_ERROR,D0    // error
	bra.s .r2
.r1:
	moveq #CT60_READ_ERROR,D0    // bus error
	move.l A1,8
	move.l A2,SP
.r2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s .r7
	clr.b _tbcr_mfp          // timer B stopped
.r7:
	move.w (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D2/A0-A2
	rts
 
write_device_i2c:

	movem.l D0-D2,-(SP)
	move.w #SLAVE_ADRESS,D1
	moveq #6,D2              // 7 bits 0xA0    7 bits 1010xxx
.wd1:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         // device
		bsr write_bit_i2c
	dbf D2,.wd1
	movem.l (SP)+,D0-D2
	rts

read_bit_i2c:

	clr.l _sda_high          // data=1 initial state (open drain)
	WAIT_US                  // 100 KHz max !  
	clr.l _scl_high          // clk=1  
	WAIT_US
	move.l _sda,d0           // data on D0  
	clr.l _scl_low           // clk=0
	btst #0,D0
	rts 
 
read_bit_wait_slave_i2c:

	move.l D1,-(SP)
	clr.l _sda_high          // data=1 initial state (open drain)
	WAIT_US
	clr.l _scl_high          // clk=1 
	moveq #31,D1             // time-out slave busy
.rs1:
		WAIT_US              // 100 KHz max !
		move.l _sda,d0       // SCL slave on B1
		btst #1,D0
	dbne D1,.rs1
	move.l _sda,d0           // data on B0  
	clr.l _scl_low           // clk=0  
	move.l (SP)+,D1   
	btst #0,D0
	rts 
 
write_bit_i2c:

	tst.w D0
	bne.s .w1
	clr.l _sda_low           // data=0  
	bra.s .w2
.w1:
	clr.l _sda_high          // data=1  
.w2:
	WAIT_US                  // 100 KHz max !  
	clr.l _scl_high          // clk=1
	WAIT_US
	clr.l _scl_low           // clk=0  
	rts 
 
write_bit_wait_slave_i2c:

	move.l D1,-(SP)
	tst.w D0
	bne.s .ws1
	clr.l _sda_low           // data=0  
	bra.s .ws2
.ws1:
	clr.l _sda_high          // data=1  
.ws2:
	WAIT_US
	clr.l _scl_high          // clk=1
	moveq #31,D1             // time-out slave busy
.ws3:
		WAIT_US              // 100 KHz max !  
		move.l _sda,d0       // SCL slave on B1
		btst #1,D0
	dbne D1,.ws3 
	clr.l _scl_low           // clk=0
	move.l (SP)+,D1  
	rts 
 
start_bit_i2c:

	clr.l _sda_high          // data=1 initial state
	clr.l _scl_high          // clk=1  
	WAIT_US                  // 100 KHz max !  
	clr.l _sda_low           // data=0 => start condition 
	WAIT_US
	clr.l _scl_low           // clk=0
	rts

start_bit_wait_slave_i2c:

	move.l D1,-(SP)
	clr.l _sda_high          // data=1 initial state
	WAIT_US                  // 100 KHz max !  
	clr.l _scl_high          // clk=1  
	moveq #31,D1             // time-out slave busy
.s1:
		WAIT_US              // 100 KHz max !  
		move.l _sda,D0       // SCL slave on B1
		btst #1,D0
	dbne D1,.s1  
	clr.l _sda_low           // data=0 => start condition 
	WAIT_US
	clr.l _scl_low           // clk=0
	move.l (SP)+,D1
	rts
 
stop_bit_i2c:

	clr.l _sda_low           // data=0 
	WAIT_US                  // 100 KHz max !
	clr.l _scl_high          // clk=1  
	WAIT_US 
	clr.l _sda_high          // data=1 => stop condition
	WAIT_US
	rts

wait_26us:                            // 26uS (timer C) or 6,5uS (timer B)

	move.b (A0),D0
.wu1:
	cmp.b (A0),D0       
	beq.s .wu1
	rts

chip_density:                         // A23-A22 cdy2-1

	dc.w 0xC,0x9,0x00,0      // 8Mx8b / 8Mx16b
	dc.w 0xC,0xA,0x40,0      // 16Mx8b
	dc.w 0xD,0x9,0x80,0      // 16Mx16b
	dc.w 0xD,0xA,0xC0,0      // 32Mx8b / 32Mx16b
	dc.w 0,0,0,0             // end
	
init_cookie_ct60:	

	movem.l D0-D2/A0-A2,-(SP)
	move.w #3,-(SP)          // TT ram if possible
	move.l #CT60_COOKIE_SIZE,-(SP)
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.w #8,SP
	tst.l D0
	ble.s .error_cookie_ct60
	move.l D0,A1
	move.l #0x43543630,D0    // CT60
	bsr get_cookie
	move.l A0,D0
	beq.s .error_cookie_ct60
	move.l 4(A0),D2          // CPU speed * 10 saved inside init_sdram
	move.l A1,4(A0)          // buffer
	moveq #(CT60_COOKIE_SIZE/4)-1,D0
.clear_data_ct60_cookie:
		clr.l (A1)+
	dbf D0,.clear_data_ct60_cookie
	move.l 4(A0),A0          // buffer
	move.w D2,8(A0)          // CPU speed
	move.l phystop,A0
	clr.w count_io3_mfp(A0)
	move.l _hz_200,start_hz_200(A0)
	pea inter_io3_mfp(PC)
	move.w #67,-(SP)         // IO3 MFP
	move.w #5,-(SP)          // Setexec
	trap #13
	addq.w #8,SP
	move.w #3,-(SP)          // IO3 MFP
	move.w #27,-(SP)         // Jenabint
	trap #14
	addq.w #4,SP
	move.l _hz_200,D0
	add.l #100,D0            // tempo 0.5 S
.tempo_test_fan:
		move.l _hz_200,D1
		cmp.l D0,D1
	blt.s .tempo_test_fan
	move.l phystop,A0
	cmp.w #5,count_io3_mfp(A0)
	bcc.s .error_cookie_ct60
	move.w #3,-(SP)          // IO3 MFP
	move.w #26,-(SP)         // Jdisint
	trap #14
	addq.w #4,SP
.error_cookie_ct60:	
	movem.l (SP)+,D0-D2/A0-A2
	RTS	

	dc.l 0x58425241          // XBRA
	dc.l 0x43543630          // CT60
	dc.l 0
	
inter_io3_mfp:

	movem.l D0/A0,-(SP)
	move.l phystop,A0
	addq.w #1,count_io3_mfp(A0)
	move.l _hz_200,D0
	sub.l start_hz_200(A0),D0
	cmp.l #1000,D0           // 5 S
	bcs.s .end_inter
	move.l _hz_200,start_hz_200(A0)
	move.l cookie,D0
	beq.s .end_inter
	move.l D0,A0
.loop_cookie_inter:
		tst.l (A0)
		beq.s .end_inter
		cmp.l #0x43543630,(A0)      // CT60
		bne.s .next_cookie_inter
		move.l 4(A0),D0
		beq.s .end_inter
		move.l phystop,A0
		move.w count_io3_mfp(A0),-(SP)
		clr.w count_io3_mfp(A0)
		move.l D0,A0
		move.w (SP)+,D0
		mulu #6,D0                  // tr/mn
		move.w D0,6(A0)             // speed_fan
		bra.s .end_inter
.next_cookie_inter:
		addq.l #8,A0
	bra.s .loop_cookie_inter
.end_inter:
	movem.l (SP)+,D0/A0
	bclr #3,0xFFFFFA11       // ISRB
	rte
	
