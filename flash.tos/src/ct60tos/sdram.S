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

// #define RESET // removed because not works with some motherboards/SDR60 versions
#define XFRB_SIZE 0x10000
#define CT60_COOKIE_SIZE 256
#define DEFAULT_BOOT_DELAY 800 // 4 seconds

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
	bclr #5,0xFFFFFA07
	move.w SR,-(SP)
	or.w #0x700,SR
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
	lea message0(PC),A0
	cmp.w #2,0x3E86          // number of planes
	bhi.s .title_colors
	lea message0b(PC),A0
.title_colors:
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
	move D0,D1
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
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
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
	lea crlf(PC),A0
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
	cpusha bc                // flush
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
.end_sdram:
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
//.loop_dump1:
//		lea crlf(PC),A0
//		bsr display_string_single		
//		moveq #15,D2
//.loop_dump2:
//			move.b (A1)+,D0
//			bsr hex_byte
//			moveq #0x20,D0
//			bsr display_char
//		dbf D2,.loop_dump2
//	dbf D1,.loop_dump1
.error_eeprom_sdram:
	unlk A6
	movem.l (SP)+,D0-D2/A0-A1
	rts

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
message0:	.ascii "            "
	.byte 0x1B,0x62,0x34,0x41
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
message0b:	.ascii "            ATARI FALCON/CT60 TOS4.04"
crlf:	.byte 13,10,0
message1:	.asciz "            SDRAM "
message2:	.asciz "64"
message3:	.asciz "128"
message4:	.asciz "256"
message5:	.asciz "512"
message6:	.asciz "MB detected"
	.asciz "Mo d‚tect‚e" 
message8:	.asciz "            68060 Rev."
	.asciz "            68060 R‚v."
message9:	.asciz "            68EC060 / 68LC060 Rev."
	.asciz "            68EC060 / 68LC060 R‚v."
message10:	.asciz "            unknown CPU "
	.asciz "            CPU inconnu"
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
	.asciz "c "
message15b:	
	.ascii "2004 May "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.ascii "Mai 2004 "
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
	.asciz "pas de boot trouv‚"
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
message78:
	.byte 13
	.asciz "Starting in "
	.byte 13
	.asciz "D‚marrage dans "
message79:
	.asciz " seconds  "
	.asciz " secondes  "
message80:
	.asciz " TOS   "
message81:
	.asciz " MagiC "
message82:
	.asciz " Linux "

boot_ide:	.byte 16,8,9,10,11,12,13,14,15,255
boot_scsi:	.byte 8,9,10,11,12,13,14,15,16,255

tab_os:	.byte 0x80,8,0x10

list_manufacturers:
	.byte 0x1C
	.asciz "MITSUBISHI"
	.byte 0x25
	.asciz "KINGMAX
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
	.byte 0,0

	.align 2

boot_drive:

	movem.l D0-D2/A0-A2/A5,-(SP)
	clr.l -(SP)
	move.l #CT60_BOOT_ORDER,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	lea boot_scsi(PC),A5
	btst #0,D0
	beq.s .loop_drive
	lea boot_ide(PC),A5
.loop_drive:
		moveq #1,D1
.loop2_drive:
			move.l A5,-(SP)
			move.w D1,-(SP)
			move.w 0x840,D4
			move.b (A5,D4.w),D4
			lea message41(PC),A0
			btst #4,D4
			beq.s .scsi_drive
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
			or.w (SP),D0
			bsr display_char
			lea message43(PC),A0
			bsr display_string_single
			move.w D4,-(SP)
			move.l _dskbufp,-(SP)
			move.w #1,-(SP)
			clr.l -(SP)
			jsr 0xE017CE
			lea 12(SP),SP
			move.w (SP)+,D1
			move.l (SP)+,A5
			tst.l D0
			beq.s .drive_ok
			lea message44(PC),A0 // timeout
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
		bra.s .next_drive
.boot_ok:
		lea message48(PC),A0
		bsr display_string
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
		move.l A5,-(SP)
		move.l hdv_rw,-(SP)
		jsr (A0)
		move.l (SP)+,D0
		move.l (SP)+,A5
		cmp.l hdv_rw,D0
		beq.s .next_drive
		bra.s .end_boot_drive
.drive_ok:
		move.l _dskbufp,A0
		move.w #0xFF,D0
		moveq #0,D1
.loop_checksum:
			add.w (A0)+,D1
		dbf D0,.loop_checksum
		cmp.w #0x1234,D1
		beq.s .boot_ok
		lea message47(PC),A0
		bsr display_string
.next_drive:
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
	movem.l (SP)+,D0-D2/A0-A2/A5
	rts
	
menu_boot:

	movem.l D0-D7/A0-A2,-(SP)
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
	movem.l (SP)+,D0-D7/A0-A2
	tst.w _cmdload
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
	move D0,-(SP)
	move #2,-(SP)
	move #3,-(SP)
	trap #13
	addq.w #6,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts
	
conv_bcd:

	and.l #0xFFFF,D0
	divu #10,D0
	move.w D0,D1
	swap D0
	asl.w #4,D1
	or.w D1,D0
	move.b D0,(A0)
	rts
	
test_keyboard:
	
	movem.l D0-A5,-(SP)
	link A6,#-8
	move.w #0x17,-(SP)       // Gettime
	trap #14
	addq.w #2,SP
	move.l D0,D7
	move.l D7,D5
	move.b #0x1B,-8(A6)      // Settime IKBD
	move.w D5,D0
	and.w #0x1F,D0
	add.w D0,D0
	lea -2(A6),A0
	bsr conv_bcd             // seconds
	lsr.l #5,D5
	move.w D5,D0
	and.w #0x3F,D0
	lea -3(A6),A0
	bsr conv_bcd             // mn
	lsr.l #6,D5
	move.w D5,D0
	and.w #0x1F,D0
	lea -4(A6),A0
	bsr conv_bcd             // hours
	lsr.l #5,D5
	move.w D5,D0
	and.w #0x1F,D0
	lea -5(A6),A0
	bsr conv_bcd             // day
	lsr.l #5,D5
	move.w D5,D0
	and.w #0xF,D0
	lea -6(A6),A0
	bsr conv_bcd             // month
	lsr.l #4,D5
	move.w D5,D0
	and.w #0x3F,D0
	add.w #80,D0
	cmp.w #100,D0
	bcs.s .year_ikbd
	sub.w #100,D0
.year_ikbd:
	lea -7(A6),A0
	bsr conv_bcd             // year
	pea -8(A6)	
	move.w #6,-(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.w #8,SP
	jsr 0xE022A0             // Gettime IKBD
	and.l #0x01FFFFFF,D0     // remove year because this call has a year 2000 bug 
	tst.b 0x11C4
	bpl.s .keyboard_answer
.keyboard_error_2:
	lea message76(PC),A0     // keyboard failure
	bsr display_string
	bra .no_buffer
.keyboard_answer:
	and.l #0x01FFFFFF,D7
	sub.l D7,D0
	bmi.s .keyboard_error_2
	cmp.l #1,D0
	bhi.s .keyboard_error_2
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
	bra.s .end_test_keyboard
.eiffel_found:                        // display eiffel version
		addq.l #1,A0
		move.b (A0)+,D0
		beq.s .end_test_keyboard
		bsr display_char
	bra.s .eiffel_found
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
	move.l A0,-(SP)
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
	bsr test_keyboard
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
	jsr 0x00E00BD2
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
	move SR,-(SP)
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
	move (SP)+,SR
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
	move D0,D1
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
	move d0,d1               // number of DIMM banks
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
	move SR,-(SP)
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
	move D0,D1               // adress
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
	move D1,D0               // 8 bits data
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
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D2/A0-A2
	rts
 
write_device_i2c:

	movem.l D0-D2,-(SP)
	move #SLAVE_ADRESS,D1
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
	move.l A1,4(A0)
	moveq #(CT60_COOKIE_SIZE/4)-1,D0
.clear_data_ct60_cookie:
		clr.l (A1)+
	dbf D0,.clear_data_ct60_cookie
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
		cmp.l #0x43543630,(A0)
		bne.s .next_cookie_inter
		move.l 4(A0),D0
		beq.s .end_inter
		move.l phystop,A0
		move.w count_io3_mfp(A0),-(SP)
		clr.w count_io3_mfp(A0)
		move.l D0,A0
		move.w (SP)+,D0
		mulu #6,D0                  // tr/mn
		move D0,6(A0)               // speed_fan
		bra.s .end_inter
.next_cookie_inter:
		addq.l #8,A0
	bra.s .loop_cookie_inter
.end_inter:
	movem.l (SP)+,D0/A0
	bclr #3,0xFFFFFA11       // ISRB
	rte
	
