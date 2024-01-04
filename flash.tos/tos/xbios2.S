/* XBIOS CT60 board functions
*  - Read on the CT60, the 68060 temperature on the TLV0831 DC from Texas I.
*    2.8 deg celcius / step 
*  - Parameters in Flash
*  - Backup NVM stored in flash
*  - Cache
*  - PCI BIOS
*  - Eiffel keyboard XBIOS
*
*  XBIOS Coldfire board(s) functions
*  - Parameters in Flash
*  - Backup NVM (SRAM) stored in flash
*  - IKBD from CAN on MCF548X (special version of Eiffel) and UART2 on MCF5445X (serial port, normal)
*  - IKBD from UART2 on MCF5445X
*  - IKBD from PSC1 and FPGA on MCF547X
*  - Serial from PSC0/UART0 or serial mouse
*  - MFP timers replaced by GPT timers on MCF547X-MCF548X and PIT timers on MCF5445X
*  - VBL replaced by SLT0 timer on MCF547X-MCF548X and DTMR0 timer on MCF5445X
*  - Cache
*  - PCI BIOS
*  - Eiffel keyboard XBIOS
*
*  Didier Mequignon 2001-2012, e-mail: aniplay@wanadoo.fr
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
#include "vars.h"


// #define DEBUG_GEMDOS
// => move.b #0x01,0x5695 before the Gemdos call

#define CT60_READ_ERROR -1


#define read_core_temperature 0xc60a
#define rw_parameter 0xc60b
#define cache 0xc60c
#define flush_cache 0xc60d
#define vmalloc 0xc60e
#define read_core_temperature_bis 0x0c6a
#define rw_parameter_bis 0x0c6b
#define cache_bis 0x0c6c
#define flush_cache_bis 0x0c6d
#define vmalloc_bis 0xc6e

	.globl code_led
	.globl get_cookie
	.globl det_xbios
	.globl nvm_access
	.globl test_rtc
	.globl fix_settime
	.globl fix_gettime
	.globl new_ikbdvect
	.globl new_statvec
	.globl ct60_rw_param
	.globl ct60_read_temp

	.text
	

#ifdef DEBUG

debug1:	.asciz "PCICR 0x"
debug2:	.asciz "LAS0BA 0x"
debug3:	.asciz "LAS0RR 0x"
debug4:	.asciz "PCIBAR2 0x"
debug5:	.asciz "LAS1BA 0x"
debug10:	.asciz "DMLBAM 0x"
debug11:	.asciz "DMRR 0x"
debug12:	.asciz "DMLBAI 0x"
debug13:	.asciz "DMPBAM 0x"
debug20:	.asciz "BIGEND 0x"
debug21:	.asciz "LMISC 0x"
debug27:	.asciz "PCI PLX byte access failure, read: 0x"
debug28:	.asciz "PCI PLX word access failure, read: 0x"
debug29:	.byte 13,10
	.ascii "PCI init PLX registers"
	.byte 13,10,0
debug32:	.ascii "PCI init driver"
	.byte 13,10,0
debug33:	.ascii "PCI init devices"
	.byte 13,10,0
debug34:	.ascii "Add cookie _PCI"
	.byte 13,10,0
debug40:	.ascii "find_pci_device"
	.byte 13,10,0
debug41:	.ascii "find_pci_classcode"
	.byte 13,10,0
debug42:	.asciz "read_config_byte "
debug43:	.asciz "read_config_word "
debug44:	.asciz "read_config_longword "
debug45:	.asciz "fast_read_config_byte "
debug46:	.asciz "fast_read_config_word "
debug47:	.asciz "fast_read_config_longword "
debug48:	.asciz "write_config_byte "
debug49:	.asciz "write_config_word "
debug50:	.asciz "write_config_longword "
debug51:	.asciz "hook_interrupt "
debug52:	.ascii "unhook_interrupt"
	.byte 13,10,0
debug53:	.ascii "special_cycle"
	.byte 13,10,0
debug54:	.ascii "get_routing"
	.byte 13,10,0
debug55:	.ascii "set_interrupt"
	.byte 13,10,0
debug56:	.asciz "get_resource "
debug57:	.ascii "get_card_used"
	.byte 13,10,0
debug58:	.ascii "set_card_used"
	.byte 13,10,0
debug59:	.ascii "read_mem_byte"
	.byte 13,10,0
debug60:	.ascii "read_mem_word"
	.byte 13,10,0
debug61:	.ascii "read_mem_longword"
	.byte 13,10,0
debug62:	.ascii "fast_read_mem_byte"
	.byte 13,10,0
debug63:	.ascii "fast_read_mem_word"
	.byte 13,10,0
debug64:	.ascii "fast_read_mem_longword"
	.byte 13,10,0
debug65:	.asciz "write_mem_byte "
debug66:	.asciz "write_mem_word "
debug67:	.asciz "write_mem_longword "
debug68:	.ascii "read_io_byte"
	.byte 13,10,0
debug69:	.ascii "read_io_word"
	.byte 13,10,0
debug70:	.ascii "read_io_longword"
	.byte 13,10,0
debug71:	.ascii "fast_read_io_byte"
	.byte 13,10,0
debug72:	.ascii "fast_read_io_word"
	.byte 13,10,0
debug73:	.ascii "fast_read_io_longword"
	.byte 13,10,0
debug74:	.asciz "write_io_byte "
debug75:	.asciz "write_io_word "
debug76:	.asciz "write_io_longword "
debug77:	.ascii "get_machine_id"
	.byte 13,10,0
debug78:	.ascii "get_pagesize"
	.byte 13,10,0
debug79:	.ascii "virt_to_bus"
	.byte 13,10,0
debug80:	.ascii "bus_to_virt"
	.byte 13,10,0
debug81:	.ascii "virt_to_phys"
	.byte 13,10,0
debug82:	.ascii "phys_to_virt"
	.byte 13,10,0

	.align 2

debug_display_string:

	movem.l D0/A0,-(SP)
.dds2:
		move.b (A0)+,D0
		beq.s .dds1
		bsr debug_display_char
	bra.s .dds2
.dds1:
	movem.l (SP)+,D0/A0
	rts

debug_hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s debug_hex_word
	move.l (SP)+,D0
debug_hex_word:
	move.w D0,-(SP)
	lsr.w #8,D0          
	bsr.s debug_hex_byte     
	move.w (SP)+,D0
debug_hex_byte:
	move.w D0,-(SP)
	lsr.b #4,D0        
	bsr.s debug_hex_char      
	move.w (SP)+,D0      
debug_hex_char:
	and.b #0xF,D0      
	or.b #0x30,D0      
	cmp.b #0x3A,D0     
	bcs.s debug_display_char  
	addq.b #7,D0   

debug_display_char:

	movem.l D0-D2/A0-A2,-(SP)
	move.w D0,-(SP)
	move.l #0x5F504349,D0 
	lea 0xED0000,A0          // 128 KB
	cmp.l (A0),D0            // _PCI
	beq.s .ddc2
	lea 0xEC0000,A0          // 192 KB
	cmp.l (A0),D0            // _PCI
	beq.s .ddc2
	lea 0xEB0000,A0          // 256 KB
	cmp.l (A0),D0            // _PCI
	beq.s .ddc2
	lea 0xEA0000,A0          // 320 KB
	cmp.l (A0),D0            // _PCI
	bne.s .ddc3
.ddc2:
	move.w (SP),D0           // character
	swap D0
	move.w #0x0076,D0        // 'v'
	move.l D0,-(SP)
	jsr 40(A0)               // drivers PCI in flash, dbug
	addq.l #4,SP
	bne.s .ddc1
.ddc3:
	move.w #2,-(SP)
	move.w #3,-(SP)          // Bconout
	trap #13
	addq.l #4,SP
.ddc1:	
	addq.l #2,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts

#endif /* DEBUG */

	dc.l 0x58425241          // XBRA
	dc.l 0x43543630          // CT60
	dc.l 0x00E00D76


det_xbios:

	move.l USP,A0
	btst #5,(SP)             // call in supervisor state
	beq.s .xb2
	lea 8(SP),A0
.xb2:
	move.w (A0),D0           // function
#ifdef DEBUG_GEMDOS
	cmp.w #0xB,D0            // unused
	bne.s .xb25
	cmp.w #5,2(A0)
	bne.s .xb25
	cmp.w #0xF100,4(A0)
	bne.s .xb25
	move.l 6(A0),A0          // string
	bsr debug_gemdos
	rte
.xb25:
#endif
	cmp.w #0x40,D0           // Blitmode
	bne.s .xb10
	move.l 2(SP),D0          // PC
	and.l #0xFFF00000,D0
	cmp.l #0x00E00000,D0     // TOS
	beq .xb1
	moveq #0,D0              // no blitter
	rte
.xb10:
	cmp.w #160,D0            // CacheCtrl MilanTOS
	bne .xb15
	move.w 2(A0),D0          // OpCode
	bne.s .xb16
	moveq #0,D0              // function is implemented
	rte
.xb16:
	cmp.w #1,D0              // flush data cache
	bne.s .xb17	
	cpusha DC
	moveq #0,D0
	rte	
.xb17:
	cmp.w #2,D0              // flush instruction cache
	bne.s .xb18	
	cpusha IC
	moveq #0,D0
	rte
.xb18:
	cmp.w #3,D0              // flush data and instruction caches
	beq .xb14
	cmp.w #4,D0              // inquire data cache mode
	bne.s .xb19
	movec.l CACR,D0
	btst #31,D0
	bra.s .xb20
.xb19:
	cmp.w #6,D0              // inquire instruction cache mode
	bne.s .xb21
	movec.l CACR,D0
	btst #15,D0
.xb20:
	sne.b D0
	and.w #1,D0
	ext.l D0
	rte
.xb21:
	cmp.w #5,D0              // set data cache mode
	beq.s .xb22
	cmp.w #7,D0              // set instruction cache mode
	bne.s .xb23
.xb22:	
	tst.w 4(A0)              // mode
	beq .xb24                // disable
	bra .xb8                 // enable
.xb23:
	moveq #-5,D0             // error
	rte
.xb15:
	cmp.w #356,D0
	bhi .xb26
	cmp.w #299,D0            // BIOS PCI
	bcs .xb1
	sub.w #299,D0
	bne.s .xb27
	lea install_pci_bios_magic(PC),A1
	move.l A1,0x80           // trap #0
.xb27:	
	move.w tab_pci_bios(PC,D0.W*2),D0
	bmi .xb1                 // original TOS XBIOS
	jsr tab_pci_bios(PC,D0.W)
	rte

det_xbios_magic:

	move.l USP,A0
	btst #5,(SP)             // call in supervisor state
	beq.s .xb28
	lea 8(SP),A0
.xb28:
	move.w (A0),D0           // function
	cmp.w #read_core_temperature,D0
	beq.s .xb33
	cmp.w #read_core_temperature_bis,D0
	bne.s .xb34
.xb33:
	move.w 2(A0),-(SP)       // deg_type
	jsr ct60_read_temp
	cmp.w #CT60_CELCIUS,(SP)
	beq.s .xb35
	cmp.w #CT60_FARENHEIT,(SP)
	bne.s .xb36
	mulu #9,D0
	divu #5,D0
	add.w #32,D0
	ext.l D0
	bra.s .xb35
.xb36:
	moveq #CT60_READ_ERROR,D0 // error
.xb35:
	addq.l #2,SP
	rte
.xb34:
	cmp.w #rw_parameter,D0
	beq.s .xb37
	cmp.w #rw_parameter_bis,D0
	bne.s .xb38
.xb37:
	move.w 2(A0),D0          // mode
	move.l 4(A0),D1          // type_param
	move.l 8(A0),D2          // value
	jsr ct60_rw_param 
	rte
.xb38:
	cmp.w #cache,D0
	beq.s .xb39
	cmp.w #cache_bis,D0
	bne.s .xb40
.xb39:
	move.w 2(A0),D0
	bmi.s .xb42
	bne.s .xb41
	jsr 0xE0085A             // caches off
	bra.s .xb42
.xb41:
	jsr 0xE250C8             // caches on
.xb42:
	movec.l CACR,D0
	rte
.xb40:
	cmp.w #flush_cache,D0
	beq.s .xb43
	cmp.w #flush_cache_bis,D0
	bne.s .xb29
.xb43:
	cpusha BC
	moveq #0,D0
	rte
.xb29:
	cmp.w #356,D0
	bhi.s .xb30
	cmp.w #299,D0            // BIOS PCI
	bcs.s .xb30
	sub.w #299,D0
	move.w tab_pci_bios(PC,D0.W*2),D0
	bmi.s .xb30              // original TOS XBIOS
	jsr tab_pci_bios(PC,D0.W)
	rte
.xb30:
	move.l RESERVED_VEC,A0   // where old xbios XBRA vector is saved !
	cmp.l #0x58425241,(A0)   // XBRA
	bne.s .xb31              // invalid
	cmp.l #0x63743630,4(A0)  // ct60
	bne.s .xb31              // invalid
	move.l 8(A0),-(SP)       // jump to MagiC XBIOS vector 
	rts
.xb31:
	bra.s .xb31              // XBRA invalid => infinite loop !
tab_pci_bios:
	dc.w _install_pci_bios-tab_pci_bios // 299
	dc.w _find_pci_device-tab_pci_bios // 300
	dc.w _find_pci_classcode-tab_pci_bios // 301
	dc.w _read_config_byte-tab_pci_bios // 302
	dc.w _read_config_word-tab_pci_bios // 303
	dc.w _read_config_longword-tab_pci_bios // 304
	dc.w _fast_read_config_byte-tab_pci_bios // 305
	dc.w _fast_read_config_word-tab_pci_bios // 306
	dc.w _fast_read_config_longword-tab_pci_bios // 307
	dc.w _write_config_byte-tab_pci_bios // 308
	dc.w _write_config_word-tab_pci_bios // 309
	dc.w _write_config_longword-tab_pci_bios // 310
	dc.w _hook_interrupt-tab_pci_bios // 311
	dc.w _unhook_interrupt-tab_pci_bios // 312
	dc.w _special_cycle-tab_pci_bios // 313
	dc.w _get_routing-tab_pci_bios // 314
	dc.w _set_interrupt-tab_pci_bios // 315
	dc.w _get_resource-tab_pci_bios // 316
	dc.w _get_card_used-tab_pci_bios // 317
	dc.w _set_card_used-tab_pci_bios // 318
	dc.w _read_mem_byte-tab_pci_bios // 319
	dc.w _read_mem_word-tab_pci_bios // 320
	dc.w _read_mem_longword-tab_pci_bios // 321
	dc.w _fast_read_mem_byte-tab_pci_bios // 322
	dc.w _fast_read_mem_word-tab_pci_bios // 323
	dc.w _fast_read_mem_longword-tab_pci_bios // 324
	dc.w _write_mem_byte-tab_pci_bios // 325
	dc.w _write_mem_word-tab_pci_bios // 326
	dc.w _write_mem_longword-tab_pci_bios // 327
	dc.w _read_io_byte-tab_pci_bios // 328
	dc.w _read_io_word-tab_pci_bios // 329
	dc.w _read_io_longword-tab_pci_bios // 330
	dc.w _fast_read_io_byte-tab_pci_bios // 331
	dc.w _fast_read_io_word-tab_pci_bios // 332
	dc.w _fast_read_io_longword-tab_pci_bios // 333
	dc.w _write_io_byte-tab_pci_bios // 334
	dc.w _write_io_word-tab_pci_bios // 335
	dc.w _write_io_longword-tab_pci_bios // 336
	dc.w _get_machine_id-tab_pci_bios // 337
	dc.w _get_pagesize-tab_pci_bios // 338
	dc.w _virt_to_bus-tab_pci_bios // 339
	dc.w _bus_to_virt-tab_pci_bios // 340
	dc.w _virt_to_phys-tab_pci_bios // 341
	dc.w _phys_to_virt-tab_pci_bios  // 342
	dc.w -1 // 343
	dc.w -1 // 344
	dc.w -1 // 345
	dc.w -1 // 346
	dc.w -1 // 347
	dc.w -1 // 348
	dc.w -1 // 349
	dc.w _dma_setbuffer-tab_pci_bios // 350
	dc.w _dma_buffoper-tab_pci_bios  // 351
	dc.w _read_mailbox-tab_pci_bios  // 352
	dc.w _write_mailbox-tab_pci_bios // 353
	dc.w _dma_alloc-tab_pci_bios // 354
	dc.w _dma_free-tab_pci_bios // 355
	dc.w _dma_lock-tab_pci_bios // 356
.xb26:	
	cmp.w #read_core_temperature,D0
	beq.s .xb11
	cmp.w #read_core_temperature_bis,D0
	bne.s .xb5
.xb11:
	move.w 2(A0),-(SP)       // deg_type
	jsr ct60_read_temp
	cmp.w #CT60_CELCIUS,(SP)
	beq.s .xb3
	cmp.w #CT60_FARENHEIT,(SP)
	bne.s .xb4
	mulu #9,D0
	divu #5,D0
	add.w #32,D0
	ext.l D0
	bra.s .xb3
.xb4:
	moveq #CT60_READ_ERROR,D0 // error
.xb3:
	addq.l #2,SP
	rte
.xb5:
	cmp.w #rw_parameter,D0
	beq.s .xb12
	cmp.w #rw_parameter_bis,D0
	bne .xb6
.xb12:
	move.w 2(A0),D0          // mode
	move.l 4(A0),D1          // type_param
	move.l 8(A0),D2          // value
	jsr ct60_rw_param 
	rte
.xb6:
	cmp.w #cache,D0
	beq.s .xb13
	cmp.w #cache_bis,D0
	bne.s .xb9
.xb13:
	move.w 2(A0),D0
	bmi.s .xb7
	bne.s .xb8
.xb24:
	jsr 0xE0085A             // caches off
	rte
.xb8:
	jsr 0xE250C8             // caches on
	rte
.xb7:
	movec.l CACR,D0
	rte
.xb9:
	cmp.w #vmalloc,D0
	beq.s .xb32
	cmp.w #vmalloc_bis,D0
	beq.s .xb32
	cmp.w #flush_cache,D0
	beq.s .xb14
	cmp.w #flush_cache_bis,D0
	bne.s .xb1
.xb14:
	cpusha BC
.xb32:
	moveq #0,D0
	rte
.xb1:
	move.l det_xbios-4(PC),-(SP)
	rts
	
test_pci_drivers:

	move.l #0x5F504349,D0    // _PCI
	lea 0xED0000,A0          // 128 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_pci_ok
	lea 0xEC0000,A0          // 192 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_pci_ok
	lea 0xEB0000,A0          // 256 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_pci_ok
	lea 0xEA0000,A0          // 320 KB, 1st part
	cmp.l (A0),D0            // _PCI
.test_pci_ok:                         // (optional 2nd part inside 0xFC0000-0xFEFFFF)
	rts

magic_routine:                        // called before auto folder
	
	jmp install_scsidrv
end_magic_routine:

install_magic_routine:

	lea magic_routine(PC),A0
	pea end_magic_routine(PC)
	move.l phystop,A1
	lea -512(A1),A1
	move.l #0x12123456,(A1)      // magic key
	move.l A1,4(A1)
	move.w #((512-8)/2)-2,D1
	move.w (A1)+,D0
	add.w (A1)+,D0
	add.w (A1)+,D0
	add.w (A1)+,D0
.copy_magic_routine:
		cmp.l (SP),A0
		bcc.s .fill_end_magic_routine
		add.w (A0),D0
		move.w (A0)+,(A1)+
	dbf D1,.copy_magic_routine
	bra.s .end_copy_magic_routine
.fill_end_magic_routine:
		clr.w (A1)+
	dbf D1,.fill_end_magic_routine
.end_copy_magic_routine:
	move.w #0x5678,D1            // checksum
	sub.w D0,D1
	move.w D1,(A1)+
	addq.l #4,SP
	rts

install_pci_bios_magic:               // trap #0 handler called when MagiC enable interrupts (trap #1 not exist, seems always TOS)

	movem.l D1-A6,-(SP)
	move.l #0x4D616758,D0    // MagX
	bsr get_cookie
	beq .no_install          // not found
	move.l #0x5F504349,D0    // _PCI cookie
	bsr get_cookie
	bne .no_install          // found
	move.l #((3*4)+(3*2))*2,D0 // size for 2 x XBRA jumper
	move.l _membot,A0        // boot alloc
	add.l D0,_membot
	move.l #0x58425241,D0    // XBRA
	move.l D0,(A0)
	move.l D0,18(A0)
	move.l #0x63743630,D0    // ct60
	move.l D0,4(A0)
	move.l D0,22(A0)
	move.w SR,-(SP)
	or.w #0x700,SR
	move.l A0,RESERVED_VEC   // save address of XBRA jumper
	move.l XBIOS_VEC,8(A0)   // trap #14 vector saved
	move.w #0x4EF9,12(A0)    // JMP
	lea det_xbios_magic(PC),A1
	move.l A1,14(A0)
	lea 12(A0),A0
	move.l A0,XBIOS_VEC      // to jumper
	addq.l #6,A0             // 2nd jumper
	move.l hdv_boot,8(A0)    // hdv_boot vector saved
	move.w #0x4EF9,12(A0)    // JMP
	lea det_hdv_boot_magic(PC),A1
	move.l A1,14(A0)
	lea 12(A0),A6
	cpusha BC                // flush cache for JMP
	move.w (SP)+,SR
	move.w #2,-(SP)
	lea -2(SP),A0            // install PCI BIOS 2nd time (no PCI RESET)
	jsr _install_pci_bios(PC)
	addq.l #2,SP
	bmi .no_install
	lea 0xE00FB6,A0          // exception fault vectors handler
	lea 8,A1
	moveq #2,D0              // access fault, address fault, illegal instruction
.init_vectors:
		move.l A0,(A1)+
	dbf D0,.init_vectors
	bsr test_pci_drivers
	bne.s .no_install        // no PCI drivers
	movec.l CACR,D0
	move.l D0,-(SP)          // save CACR
	cpusha BC
	move.l #0xA0808000,D0    // enable caches
	movec.l D0,CACR
	move.l #2,-(SP)          // no reset (started a 2nd time) for MagiC
	jsr 4(A0)                // drivers PCI in flash, init_devices
	addq.l #4,SP
	cpusha BC
	move.l (SP)+,D0          // restore CACR
	movec.l D0,CACR
	clr.w -(SP)
	lea -2(SP),A0            // display devices
	jsr _install_pci_bios(PC)
	addq.l #2,SP
	move.l A6,hdv_boot       // to jumper
	cpusha BC                // flush cache for JMP
.no_install:
	movem.l (SP)+,D1-A6
	moveq #1,D0
	rte

det_hdv_boot_magic:
	
	movem.l D1-D2/A0-A2,-(SP)
	bsr install_magic_routine
	bsr test_pci_drivers
	bne.s .no_pci_drivers    // no PCI drivers
	jsr 10(A0)               // drivers PCI in flash, call after SDRAM added
.no_pci_drivers:
	move.l hdv_boot,A0
.loop_xbra:
		cmp.l #0x58425241,-12(A0) // XBRA
		bne.s .no_xbra
		cmp.l #0x63743630,-8(A0) // ct60
		bne.s .next_xbra
		move.l -4(A0),D0         // old vector
		movem.l (SP)+,D1-D2/A0-A2
		move.l D0,-(SP)          // old vector
		rts	
.next_xbra:
		move.l -4(A0),D0
		beq.s .no_xbra           // no vector
		move.l D0,A0
	bra.s .loop_xbra
.no_xbra:
	movem.l (SP)+,D1-D2/A0-A2
	moveq #0,D0
	rts


#include "pci_bios.S"

	.text
	
	.align 4

get_cookie:

	movem.l D1/A0,-(SP)
	move.l D0,D1             // cookie
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
.end_cookie:
	movem.l (SP)+,D1/A0
	tst.l D0
	rts

add_cookie:

	movem.l D1-D2/A0,-(SP)
	move.l cookie,D2
	beq.s .cookie_not_found_add
	move.l D2,A0
	moveq #0,D2
	bra.s .next_cookie_add
.loop_add_cookie:
		addq.l #8,A0
		addq.l #1,D2
.next_cookie_add:
	tst.l (A0)
	bne.s .loop_add_cookie
	cmp.l 4(A0),D2
	bcc.s .cookie_not_found_add
	move.l 4(A0),D2
	move.l D0,(A0)           // cookie
	move.l D1,4(A0)          // value
	addq.l #8,A0
	clr.l (A0)
	move.l D2,4(A0)
	moveq #1,D0              // OK
	bra.s .end_add_cookie
.cookie_not_found_add:
	moveq #0,D0              // error
.end_add_cookie:
	movem.l (SP)+,D1-D2/A0
	rts

#ifdef DEBUG_GEMDOS
debug_gemdos:

	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
.dg2:
		move.b (A0)+,D0
		beq .dg1
		cmp.l #0x28777065,-1(A0) // '(wpe'
		bne.s .dg4
		moveq #0,D2
		bra.s .dg3
.dg4:
		cmp.l #0x286C7065,-1(A0) // '(lpe'
		bne.s .dg5
		moveq #1,D2
.dg3:
		cmp.l #0x656B2028,3(A0)  // 'ek ('
		bne.s .dg5
		cmp.l #0x6136202B,8(A0)  // 'a6 +'
		beq.s .dg6
		cmp.l #0x6136202D,8(A0)  // 'a6 -'
		bne.s .dg5
		bset #31,D2
.dg6:
		moveq #0x30,D0
		bsr display_char
		moveq #0x78,D0
		bsr display_char
		add.w #13,A0
		bsr hex_value
		tst.l D2
		bpl.s .dg7
		neg.l D0
.dg7:
		tst.w D2
		bne.s .dg8
		move.w (A6,D0.l),D0
		bsr hex_word
		bra.s .dg9
.dg8:
		move.l (A6,D0.l),D0
		bsr hex_long
.dg9:
			move.b (A0)+,D0
			beq.s .dg1	
			cmp.b #0x29,D0       // )
			bne.s .dg9
		cmp.b #0x29,(A0)
		bne.s .dg9
		addq.w #1,A0
		bra .dg2
.dg5:	
		bsr display_char
	bra .dg2
.dg1:
	rts
	
hex_value:

	movem.l D1/A0,-(SP)
	moveq #0,D0
.hv2:	
		move.b (A0)+,D1
		cmp.b #0x30,D1
		bcs.s .hv1
		cmp.b #0x39,D1
		bhi.s .hv4
		and.b #0xF,D1
		bra.s .hv3
.hv4:
		cmp.b #0x41,D1
		bcs.s .hv1
		cmp.b #0x46,D1
		bls.s .hv5
		cmp.b #0x61,D1
		bcs.s .hv1
		cmp.b #0x66,D1
		bhi.s .hv1		
.hv5:
		and.b #0xF,D1
		add.b #0x9,D1
.hv3:
		asl.l #4,D0
		or.b D1,D0
	bra.s .hv2			
.hv1:
	movem.l (SP)+,D1/A0
	rts
#endif /* DEBUG_GEMDOS */

get_no_cache_memory:

	movem.l A0-A5,-(SP)
	move.w SR,-(SP)
	or.w #0x700,SR               // no interrupts
	lea .no_memory(PC),A1
	move.l 8,A5                  // bus error
	move.l A1,8
	move.l SP,A4                 // save ssp
	moveq #0,D0
	move.l ramtop,A0
	clr.l (A0)                   // if access fault it's PMMU tree
	move.l A0,D0                 // buffer
.no_memory:
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	movem.l (SP)+,A0-A5
	rts

get_no_cache_memory_size:

	move.l D1,-(SP)
	bsr get_no_cache_memory
	tst.l D0
	beq.s .no_memory_size
	move.l D0,D1
	movec.l SRP,D0               // PMMU tree
	sub.l D1,D0
	moveq #32,D1
.loop_find_first_msb:
		subq.l #1,D1
		add.l D0,D0 // search the first MSB to 1
		bcs.s .found_first_msb
	tst.l D1
	bne.s .loop_find_first_msb
	moveq #0,D0                  // not found ?
	bra.s .no_memory_size
.found_first_msb:
	moveq #0,D0
	bset D1,D0                   // size alignment
.no_memory_size:
	move.l (SP)+,D1
	rts

nvm_access:

	moveq #-5,D0             // error
	cmp.w #48,6(SP)          // start
	bcc .nvram_access 
	move.w 4(SP),D1          // mode
	bne .nvram_access        // <> read
	// fix NVRAM values from flash parameters if NV magic code
	move.w 6(SP),D0          // start
	move.w 8(SP),D1          // size
	move.l 10(SP),A0         // buffer
	movem.l D1-D4/A0-A3,-(SP)
	link A6,#-56
	move.l A0,-56(A6)        // buffer
	move.w D1,-52(A6)        // size
	move.w D0,-50(A6)        // start
	lea -48(A6),A3
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SAVE_NVRAM_1,D1 // type_param
	moveq #0,D2              // value
	jsr ct60_rw_param
	move.w D0,(A3)           // bootpref
	swap D0
	cmp.w #0x4E56,D0         // NV magic code
	bne .nvm_read
	                         // NVM values are stored in Flash
	pea (A3)                 // buffer: bootpref
	move.w #2,-(SP)          // size
	clr.w -(SP)              // start
	moveq #-5,D0
	moveq #1,D1
	move.w D1,-(SP)          // write
	jsr 0xE02172             // NVMaccess
	lea 10(SP),SP
	clr.l 2(A3) 
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SAVE_NVRAM_2,D1 // type_param
	moveq #0,D2              // value
	jsr ct60_rw_param 
	move.l D0,6(A3)          // language, keyboard, datetime, separator
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SAVE_NVRAM_3,D1 // type_param
	moveq #0,D2              // value
	jsr ct60_rw_param 
	rol.l #8,D0
	move.b D0,10(A3)         // bootdelay
	move.l D0,14(A3)         // vmode, scsi, bootdelay
	pea 6(A3)                // buffer: language, keyboard, datetime, separator, bootdelay
	move.w #5,-(SP)          // size
	move.w #6,-(SP)          // start
	moveq #-5,D0
	moveq #1,D1
	move.w D1,-(SP)          // write
	jsr 0xE02172             // NVMaccess
	lea 10(SP),SP
	clr.b 11(A3)
	clr.w 12(A3)
	pea 14(A3)               // buffer: vmode, scsi
	move.w #3,-(SP)          // size
	move.w #14,-(SP)         // start
	moveq #-5,D0
	moveq #1,D1
	move.w D1,-(SP)          // write
	jsr 0xE02172             // NVMaccess
	lea 10(SP),SP
	clr.b 17(A3)
	clr.l 18(A3)
	clr.l 24(A3)
	clr.l 28(A3)
	clr.l 32(A3)
	clr.l 36(A3)
	clr.l 40(A3)
	clr.l 44(A3)
	move.l -56(A6),A0        // target buffer
	move.w -52(A6),D1        // size
	move.w -50(A6),D0        // start
	add.w D0,A3
	bra.s .nvm_copy_buf
.loop_nvm_copy_buf:
		cmp.w #48,D0
		bcc.s .end_nvm_copy_buf 
		move.b (A3)+,(A0)+
		addq.w #1,D0	
.nvm_copy_buf:
	dbf D1,.loop_nvm_copy_buf
.end_nvm_copy_buf:
	unlk A6
	movem.l (SP)+,D1-D4/A0-A3
	moveq #0,D0
	rts
.nvm_read:
	unlk A6
	movem.l (SP)+,D1-D4/A0-A3
	moveq #-5,D0             // error
	move.w 4(SP),D1          // mode
.nvram_access:
	jmp 0xE02172             // NVMaccess
	
test_rtc:

	movem.l D0-D2,-(SP)
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SAVE_NVRAM_1,D1 // type_param
	moveq #0,D2              // value
	jsr ct60_rw_param 
	swap D0
	cmp.w #0x4E56,D0         // NV magic code
	movem.l (SP)+,D0-D2
	bne .use_rtc
	or.b #1,CCR              // use IKBD clock
	rts
.use_rtc:
	and.b #0xFE,CCR          // use RTC clock
	rts

	
fix_settime:

	move.b D2,D0
	and.w #0x7F,D0           // 1980
	add.w #80,D0
	cmp.w #100,D0
	bcs.s .year_before_2000_settime
	sub.w #100,D0
.year_before_2000_settime:
	rts
	

fix_gettime:

	sub.b #80,D0             // 1980
	bpl.s .year_before_2000_gettime
	add.b #100,D0
.year_before_2000_gettime:
	move.b D0,D2
	rts


power_key:

	move.l D0,-(SP)
	move.l A0,-(SP)
	move.l phystop,A0
	move.l #0xCAFEFADE,D0
	move.l D0,power_flag(A0) // tested inside evnt_multi AES
	move.l (SP)+,A0
	move.l (SP)+,D0
	rts

new_ikbdvect:                // test Eiffel keys

	move.b D0,D1
	bclr #7,D1
	cmp.b #0x45,D1           // PAGE UP
	bne.s .test_page_down
	btst #7,D0
	bne.s .break_page_up
	bset.b #0,0x1187         // SHIFT
	move.b #0x48,D0          // ^
	bra .test_shift
.break_page_up:
	bclr.b #0,0x1187         // SHIFT
	move.b #0xC8,D0          // ^
	bra .test_shift
.test_page_down:
	cmp.b #0x46,D1           // PAGE DOWN
	bne.s .test_print_screen
	btst #7,D0
	bne.s .break_page_down
	bset.b #0,0x1187         // SHIFT
	move.b #0x50,D0          // v
	bra .test_shift
.break_page_down:
	bclr.b #0,0x1187         // SHIFT
	move.b #0xD0,D0          // v
	bra .test_shift	
.test_print_screen:
	cmp.b #0x49,D1           // PRINT SCREEN
	bne.s .test_power
	btst #7,D0
	bne.s .break_print_screen
	bset.b #3,0x1187         // ALT
	move.b #0x62,D0          // HELP
	bra.s .test_shift
.break_print_screen:
	bclr.b #3,0x1187         // ALT
	move.b #0xE2,D0          // HELP
	bra.s .test_shift
.test_power:
	cmp.b #0x73,D1           // POWER
	bne.s .test_shift
	btst #7,D0
	bne.s .test_shift
	bsr power_key
.test_shift:
	move.b 0x1187,D1         // Shift state
	cmp.b #0x2A,D0
	rts

new_statvec:

	move.l A0,-(SP)
	lea det_statvec(PC),A0
	move.l A0,0x1142
	move.l #0xE02750,D0
	move.l (SP)+,A0
	rts

	dc.l 0x58425241          // XBRA
	dc.l 0x43543630          // CT60
	dc.l 0x00E02750          // RTS
	
det_statvec:

	cmp.b #0x05,(A0)
	bne .no_eiffel_key
	movem.l D0/A0,-(SP)
	cmp.b #0x73,6(A0)        // POWER
	bne.s .not_power
	bsr power_key
	bra .not_volume_down
.not_power:
	cmp.b #0x32,6(A0)        // VOLUME UP
	bne.s .not_volume_up
	move.w #-1,-(SP)
	clr.w -(SP)              // LTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	sub.w #0x10,D0
	and.w #0xF0,D0
	cmp.w #0xF0,D0
	bne.s .not_lmax
	moveq #0,D0
.not_lmax:
	move.w D0,-(SP)
	clr.w -(SP)              // LTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	move.w #-1,-(SP)
	move.w #1,-(SP)          // RTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	sub.w #0x10,D0
	and.w #0xF0,D0
	cmp.w #0xF0,D0
	bne.s .not_rmax
	moveq #0,D0
.not_rmax:
	move.w D0,-(SP)
	move.w #1,-(SP)          // RTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	bra.s .not_volume_down
.not_volume_up:
	cmp.b #0x21,6(A0)        // VOLUME DOWN
	bne.s .not_volume_down
	move.w #-1,-(SP)
	clr.w -(SP)              // LTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	add.w #0x10,D0
	and.w #0xF0,D0
	bne.s .not_lmin
	move.w #0xF0,D0
.not_lmin:
	move.w D0,-(SP)
	clr.w -(SP)              // LTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	move.w #-1,-(SP)
	move.w #1,-(SP)          // RTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	add.w #0x10,D0
	and.w #0xF0,D0
	bne.s .not_rmin
	move.w #0xF0,D0
.not_rmin:
	move.w D0,-(SP)
	move.w #1,-(SP)          // RTATTEN
	jsr 0xE0620C             // soundcmd
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

