/*  Install and uncompress the PCI part of the TOS 
 *  and start the CF68KLIB
 * 
 * Didier Mequignon, 2006-2009, e-mail: aniplay@wanadoo.fr
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

#include "fire.h"

#define cookie 0x5A0
#define _run  0x6EE4                  /* TOS 404 PD */

#undef DEBUG

	.text

cf68klib:

	lea 0x8870,SP            // TOS 4.04 stack (destroyed by the CF68KLIB later)
	.chip 68060
	move.l SP,USP
	.chip 5200
	move.l A0,-(SP)          // init_mmu routine
	move.l A1,-(SP)          // update_tlb routine
#ifndef MCF5445X
#ifndef MCF547X
	/* Initialize RAMBAR0 - locate it on the data bus */
	move.l #SRAM_BASE+0x0035,D0
	movec.l D0,RAMBAR0
	/* Initialize RAMBAR1 - locate it on the data bus */
	move.l #SRAM_BASE2+0x0035,D0
	movec.l D0,RAMBAR1
#endif
#endif
	moveq #0,D0
	moveq #0,D1              // normal PCI drivers
	move.l #0x5F4C5A5F,D2    // _LZ_
	lea 0xED0000,A0          // 128 KB
	cmp.l (A0),D2            // _LZ_
	beq.s .uncompress_pci_drivers
	lea 0xEC0000,A0          // 192 KB
	cmp.l (A0),D2            // _LZ_
	beq.s .uncompress_pci_drivers
	lea 0xEB0000,A0          // 256 KB
	cmp.l (A0),D2            // _LZ_
	beq.s .uncompress_pci_drivers
	lea 0xEA0000,A0          // 320 KB
	cmp.l (A0),D2            // _LZ_
	bne.s .not_compressed_pci_drivers
.uncompress_pci_drivers:
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug24(PC),A0
	bsr debug_display_string
	move.l (SP),D0
	addq.l #8,D0
	bsr debug_hex_long
	lea debug24a(PC),A0
	bsr debug_display_string
	move.l (SP),A0
	move.l 4(A0),D0
	bsr debug_hex_long
	lea debug24b(PC),A0
	bsr debug_display_string	
	move.l (SP)+,A0
#endif
	move.l 4(A0),-(SP)       // insize
	pea 0x1000000            // out: SDRAM temp
	pea 8(A0)                // in
	jsr (A2)                 // LZ_Uncompress routine
	move.l (SP)+,D1
	subq.l #8,D1
	addq.l #8,SP
#ifdef DEBUG
	move.l D0,-(SP)
	bsr debug_hex_long
	lea debug24c(PC),A0
	bsr debug_display_string	
	move.l (SP)+,D0
#endif
.not_compressed_pci_drivers:
#ifdef DEBUG
	lea debug26(PC),A0
	bsr debug_display_string
#endif
	move.l (SP)+,A1          // update_tlb routine
	move.l (SP)+,A0          // init_mmu routine
	move.l D0,-(SP)          // size PCI drivers
	move.l D1,-(SP)          // base PCI drivers => force TOS in RAM
	move.l A0,-(SP)          // init_mmu routine
	move.l A1,-(SP)          // update_tlb routine
	lea coldfire_vector_base,A1
	movec.l A1,VBR
#ifndef MCF5445X
	/* Enable XL Bus Arbiter interrupt */	
	move.l #/* MCF_XARB_IMR_BAE + */ MCF_XARB_IMR_DTE /* + MCF_XARB_IMR_ATE */,D0
	move.l D0,MCF_XARB_IMR
	lea cf68k_xarbint(PC),A0
	move.l A0,(64+47)*4(A1)
	moveq #0x3F,D0           // level 7, priority 7
	move.b D0,MCF_INTC_ICR47
	move.l #~MCF_INTC_IMRH_INT_MASK47,D0
	and.l D0,MCF_INTC_IMRH
//	lea cf68k_debugint(PC),A0
//	move.l A0,12*4(A1)       // Non PC breakpoint debug interrupt
#ifndef MCF547X /* MCF548X - M5484LITE */
	move.b FIRE_ENGINE_CPLD_HW_REVISION,D0
	move.b D0,fire_engine_hw_rev // for IDE test (sdram.S)
#endif
#endif
	lea library_data_area,A0 // 1024 bytes
	jsr cf68k_initialize
	clr.l handler_fault
	clr.l address_fault
	clr.l save_mmuar
	lea coldfire_vector_base+8,A0
	lea save_coldfire_vector,A1
	move.l (A0),(A1)
	move.l (SP)+,A1          // update_tlb routine
	move.l A1,(A0)           // access fault vector CF68KLIB
	move.l (SP)+,A1
	jsr (A1)                 // init_mmu routine
	addq.l #8,SP
#ifdef DEBUG
	lea debug27(PC),A0
	bsr debug_display_string
#endif
	lea library_data_area,A0 // 1024 bytes
	clr.l reg_vbr(A0)
	lea 0x8870,A1
	move.l A1,reg_ssp(A0)
	lea start_emulation,A1
	move.l A1,reg_pc(A0)
	move.w #0x2700,D0
	move.w D0,reg_sr(A0)
	clr.b lock_cacr          // enable writing to Coldfire CACR from emulation
	clr.b debug_cf68klib
	clr.b debug_cf68klib_count
	clr.b debug_trap
	clr.b debug_trap_count
	clr.b trap_breakpoint
	clr.l old_cacr
	clr.l old_gemdos         // for store the BDOS/GEMDOS vector
	clr.l v_breakpoint_install
	clr.l v_breakpoint_deinstall
	clr.l v_breakpoint_remove
	clr.l v_suspend_task
	clr.l cpu_step_over
	clr.l cpu_trace_count
	clr.l cpu_trace_thru
	clr.l user_triggered
	clr.l current_tcb
	clr.l tid_tos
	bsr test_pci
	bne.s .no_rtos
	pea .no_rtos(PC)
	jsr 58(A0)               // drivers PCI in flash, init_rtos
	addq.l #4,SP
.no_rtos:
	lea library_data_area,A0 // 1024 bytes
	jmp cf68k_execute

test_pci:

	move.l #0x5F504349,D0 
	lea 0xED0000,A0          // 128 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_ok
	lea 0xEC0000,A0          // 192 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_ok
	lea 0xEB0000,A0          // 256 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_ok
	lea 0xEA0000,A0          // 320 KB, 1st part
	cmp.l (A0),D0            // _PCI
.test_ok:
	rts
	
start_emulation:
	
#ifdef DEBUG
	lea debug5(PC),A0
	bsr debug_display_string
#endif
	moveq #0,D0
	movec.l D0,VBR
	lea pseudo_nvram_data,A0
	moveq #47,D0
.clear_nvram:
		clr.b (A0)+
	subq.l #1,D0
	bpl.s .clear_nvram
	move.w #DEFAULT_LANG_KEYB,D0
	move.w D0,pseudo_nvram_data+6
#ifdef MCF547X
	lea 0xFFFF8800,A0        // PSG sound
	moveq #7,D0
	move.b D0,(A0)           // ports A & B
	move.b #0xC0,D0          // are outputs
	move.b D0,2(A0)
	moveq #14,D0             // port A
	move.b D0,(A0)
	moveq #7,D0              // disable floppy
	move.b D0,2(A0)	
#endif
	jmp 0xE001DA
	
#ifndef MCF5445X /* there are no XL bus and arbiter on MCF5445X */
	
cf68k_xarbint:

	.chip 68060
	move.w #0x2700,SR        // mask interrupts
	.chip 5200
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug17(PC),A0
	bsr debug_display_string
	move.l 12(SP),D0
	bsr debug_hex_long
	lea debug17sr(PC),A0
	bsr debug_display_string
	move.w 10(SP),D0
	bsr debug_hex_word
	lea debug17f(PC),A0
	bsr debug_display_string
	move.w 8(SP),D0
	bsr debug_hex_word
	lea crlf(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
	move.l (SP)+,D0
#endif
	move.l D0,-(SP)
	move.l 4(SP),D0
	and.l #0xF000FFFF,D0
	or.l  #0x00090000,D0     // Access fault
	move.l D0,4(SP)
	move.l #MCF_XARB_SR_BA + MCF_XARB_SR_DT + MCF_XARB_SR_AT,D0
	move.l D0,MCF_XARB_SR    // clear interrupt
	move.l (SP)+,D0
	move.l coldfire_vector_base+8,-(SP) // access fault
	rts

#if 0

cf68k_debugint:

	.chip 68060
	move.w #0x2700,SR        // mask interrupts
	.chip 5200
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug23(PC),A0
	bsr debug_display_string
	move.l 12(SP),D0
	bsr debug_hex_long
	lea debug17sr(PC),A0
	bsr debug_display_string
	move.w 10(SP),D0
	bsr debug_hex_word
	lea debug17f(PC),A0
	bsr debug_display_string
	move.w 8(SP),D0
	bsr debug_hex_word
	lea crlf(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
	move.l (SP)+,D0
#endif
	move.l D0,-(SP)
	move.l 4(SP),D0
	and.l #0xFC03FFFF,D0
	or.l  #0x00080000,D0     // Access fault
	move.l D0,4(SP)
	move.l (SP)+,D0
	move.l coldfire_vector_base+8,-(SP) // access fault
	rts	

	.align 2
tab_debug:
	.short 0x2C87,0,0,0           // Trigger Definition Register cleared
	.short 0x2C86,0,0xE700,0      // Address Attributes Trigger Register
	.short 0x2C8D                 // Address Breakpoint Low
	.long FALCON_ATA_DATA
	.short 0
	.short 0x2C8C                 // Address Breakpoint Hight
	.long FALCON_ATA_DATA+0x3F
	.short 0
	.short 0x2C87,0x8000,0x2008,0 // Trigger Definition Register armed
#endif

#endif /* MCF5445X */
	
//###############################################################################
//# CF68K_INSTALL_VECTOR - Callback from emulation library to install handler   #
//###############################################################################
	.align	2

cf68k_install_vector:

#ifndef MCF5445X
	cmp.l #64+47,D0               // XL Bus Arbiter interrupt
	beq.s .no_install
#endif
	move.l A1,-(SP)
	lea coldfire_vector_base,A1
	move.l A0,(A1,D0.l*4)
	move.l (SP)+,A1
.no_install:
	rts
	
//##############################################################################
//# CF68K_EMULATION_ERROR - Callback from emulation library if error occured   #
//##############################################################################
	.align	2

cf68k_emulation_error:
	// This function is called by the emulation library if it encountered a 680x0
	// instruction which cannot be emulated
	//
	// This error is normally fatal
	//
	//   On entry:
	//       D0 = opcode which caused the exception
	//       D2 = error code
	//       A0 -> RegList structure
	//
	//   Possible error codes are:
	//
	//       -1 : 680x0 instruction was something like "move.l -4(a7),(a0,d0.w)" where
	//            the exception frame overwrote the data at -4(a7)
	//       -2 : 680x0 instruction was something like "move.l (a7)+,(a0,d0.w)" where
	//            the exception occurred after (a7)+ and hence exception frame overwrote
	//            the data.
	//       -3 : Given by the User-Mode version of CF68KLib if you refused to handle an
	//            exception in a callback such as 'cf68k_zero_divide' (see below)
	//
	// This error is normally fatal - you should fix the 680x0 code
	
	move.l A0,-(SP)
	lea debug3(PC),A0
	bsr debug_display_string
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x2D,D0
	bsr debug_display_char
	move.l D2,D0
	neg.l D0
	or.l #0x30,D0
	bsr debug_display_char
	lea crlf(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
	bsr debug_display_fault
	halt
	
//#########################################################################
//# Callbacks from emulation library for exceptions                       #
//#########################################################################
	.align	2
	// Certain instructions which are handled by the emulation library can give rise
	// to 680x0 exceptions. For example an attempt to divide by zero will give a 
	// 'Zero Divide' exception
	//
	// When the emulation library detects that such an exception should be raised, 
	// it will call one of the front-end routines below.
	//
	// If you wish to do so you can handle the exception in the front-end routine.
	// If you choose not to do so, the library will emulate a 680x0 exception,
	// creating an exception stack frame and passing control to the 680x0
	// exception handler
	//
	//   On entry to front-end exception handler routines:
	//
	//       D0 = opcode which caused exception
	//       A0 -> RegList structure
	//
	//   Either (a) return with D0 = 1 if you handled exception. Execution will
	//              continue with next instruction
	//       or (b) return with D0 = 0 if you didn't handle the exception.
	//              Execution will switch to the appropriate 680x0 exception
	//              handler

cf68k_bus_error:

	bsr breakpoint_deinstall
	bsr debug_display_fault
	moveq #8,D0
	bra .error

cf68k_address_error:

	bsr breakpoint_deinstall
	bsr debug_display_fault
	moveq #0xC,D0
	bra .error

cf68k_illegal_instruction:

	bsr breakpoint_deinstall
	beq .not_a_breakpoint
	tst.l v_breakpoint_install
	beq .not_a_breakpoint
	tst.l cpu_trace_count
	bne .trace_count
	move.l reg_pc(A0),D0
	cmp.l cpu_step_over,D0
	beq .not_a_breakpoint
	tst.l user_triggered
	beq.s .no_trigger
	// display registers and suspend task ?
	move.l A0,-(SP)
	lea debug1(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
	move.l reg_pc(A0),D0
	bsr debug_hex_long
	move.l current_tcb,D0
	beq .display_registers_and_suspend_task
	cmp.l #SDRAM_SIZE,D0
	bcc .display_registers_and_suspend_task
	move.l A0,-(SP)
	lea debug18(PC),A0
	bsr debug_display_string
	move.l current_tcb,A0
	lea 0x138(A0),A0
	bsr debug_display_string
	move.l (SP)+,A0
	bra .display_registers_and_suspend_task
.no_trigger:
	bsr breakpoint_install   // reinstall breakpoint and continue
	beq.s .end_illegal       // not found
	// about to execute at a breakpoint trace thru this breakpoint rather breaking
	move.l reg_pc(A0),D0
	move.l D0,cpu_trace_thru
	bra.s .trace_count
.trace_count:
	bset #7,reg_sr(A0)       // SR: trace on
	bclr #0,trace_flag(A0) 
.end_illegal:
	moveq #1,D0
	rts
.not_a_breakpoint:
	bsr debug_display_fault
	moveq #0x10,D0
	bra .error

cf68k_zero_divide:

#if 0 // #ifdef DEBUG
	bsr debug_display_fault
#endif
	move.l D0,-(SP)
	and.l #0xF0C0,D0
	cmp.l #0x80C0,D0
	beq.s .div_w
	move.l (SP),D0
	and.l #0xFFC0,D0
	cmp.l #0x4C40,D0
	beq.s .div_l
.ret_div:
	addq.l #4,SP
	moveq #0x14,D0
	bra .error
.div_w:
	addq.l #2,reg_pc(A0)
	move.l (SP),D0
	and.l #0x3F,D0
	cmp.l #0x39,D0
	bne.s .not_long_abs
	addq.l #2,reg_pc(A0)
.not_long_abs:
	and.l #0x38,D0
	cmp.l #0x28,D0
	bcs.s .ret_div
	addq.l #2,reg_pc(A0)
	bra.s .ret_div
.div_l:
	addq.l #4,reg_pc(A0)
	move.l (SP),D0
	bra.s .not_long_abs

cf68k_chk_exception:

#ifdef DEBUG
	bsr debug_display_fault
#endif
	bra .vector_ok
	
cf68k_trapv_exception:

#ifdef DEBUG
	bsr debug_display_fault
#endif
	bra .vector_ok
	
cf68k_privilege_violation:

	move.l D0,-(SP)
	bsr breakpoint_deinstall
	move.l (SP)+,D0
	and.l #0xFFC0,D0
	cmp.l #0x40C0,D0 // move from SR
	beq.s .move_from_sr // 68000 emulation under TOS
	bsr debug_display_fault
.move_from_sr:
	moveq #0x20,D0
	bra .error
	
cf68k_line_a:

#ifdef DEBUG
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug13(PC),A0
	bsr debug_display_string
	bsr debug_hex_word
	lea crlf(PC),A0
	bsr debug_display_string
	move.l (SP)+,D0
	move.l (SP)+,A0
#endif
	bra .vector_ok

cf68k_line_f:

	move.l D0,-(SP)
	and.l #0xFFF8,D0         // fsave (Ax)
	cmp.l #0xF310,D0
	bne.s .not_fsave_ax
	moveq #7,D0
	and.l (SP),D0
	move.l A0,-(SP)
	move.l reg_a0(A0,D0.l*4),A0
	.chip 68060
	fsave (A0)
	.chip 5200
	moveq #2,D0
	bra.s .inc_pc
.not_fsave_ax:
	cmp.l #0xF328,D0         // fsave d(Ax)
	bne.s .not_fsave
	moveq #7,D0
	and.l (SP),D0
	move.l A0,-(SP)
	move.l A1,-(SP)
	move.l reg_pc(A0),A1
	move.w 2(A1),A1          // offset
	move.l reg_a0(A0,D0.l*4),A0
	add.l A1,A0
	.chip 68060
	fsave (A0)
	.chip 5200
	move.l (SP)+,A1
	moveq #4,D0
	bra.s .inc_pc
.not_fsave:
	cmp.l #0xF350,D0         // frestore (Ax)
	bne.s .not_frestore_ax
	moveq #7,D0
	and.l (SP),D0
	move.l A0,-(SP)
	move.l reg_a0(A0,D0.l*4),A0
	.chip 68060
	frestore (A0)
	.chip 5200
	moveq #2,D0
	bra.s .inc_pc
.not_frestore_ax:
	cmp.l #0xF368,D0
	bne.s .not_frestore
	moveq #7,D0
	and.l (SP),D0
	move.l A0,-(SP)
	move.l A1,-(SP)
	move.l reg_pc(A0),A1
	move.w 2(A1),A1          // offset
	move.l reg_a0(A0,D0.l*4),A0
	add.l A1,A0
	.chip 68060
	frestore (A0)
	.chip 5200
	move.l (SP)+,A1
	moveq #4,D0
.inc_pc:
	move.l (SP)+,A0
	add.l D0,reg_pc(A0)
	addq.l #4,SP
	moveq #1,D0
	rts
.not_frestore:
	move.l (SP),D0
#if 0
	cmp.l #0xF800,D0         // lpstop
	bne .not_lpstop
	move.l A0,-(SP)
	move.l reg_pc(A0),A0
	move.w 2(A0),D0
	cmp.l #0x01C0,D0
	bne .not_lpstop2
	move.w (A0)+,D0          // immediate data
	move.l (SP),A0
	addq.l #6,reg_pc(A0)
	move.w D0,stop_area+2(A0) // copy user's STOP #n instruction to scratchpad
	move.w #0x4E72,D0
	move.w D0,stop_area(A0)
	move.w #0x4E75,D0        // append an RTS
	move.w D0,stop_area+4(A0)
	bsr cpushl_dc
	bsr cpushl_ic
	// to do
	halt
.not_lpstop2:
	move.l (SP)+,A0
	move.l (SP),D0
.not_lpstop:
#endif
#if 0
	cmp.l #0xF438,D0
	bne.s .not_debug_int_on
	move.l A0,-(SP)
#ifdef DEBUG
	lea debug21(PC),A0
	bsr debug_display_string
#endif
	lea tab_debug(PC),A0
	dc.l 0xFBD00003          // wdebug.l (A0)
	addq.l #8,A0
	dc.l 0xFBD00003          // wdebug.l (A0)
	addq.l #8,A0
	dc.l 0xFBD00003          // wdebug.l (A0)
	addq.l #8,A0
	dc.l 0xFBD00003          // wdebug.l (A0)
	addq.l #8,A0
	dc.l 0xFBD00003          // wdebug.l (A0)
	moveq #2,D0
	bra.s .inc_pc
.not_debug_int_on:
	cmp.l #0xF418,D0
	bne.s .not_debug_int_off
	move.l A0,-(SP)
#ifdef DEBUG
	lea debug22(PC),A0
	bsr debug_display_string
#endif
	lea tab_debug(PC),A0
	dc.l 0xFBD00003          // wdebug.l (A0)
	moveq #2,D0
	bra.s .inc_pc
.not_debug_int_off:	
#endif
	and.l #0xFF3F,D0
	cmp.l #0xF418,D0 // cinva
	beq.s .is_cinva  // cinva DC (0xF458), cinva IC (0xF498), cinva BC (0xF4D8)
	cmp.l #0xF438,D0 // cpusha
	bne .no_cpushl
.is_cinva:
	move.l (SP),D0
	and.l #0xC0,D0
	beq .no_cpushl
	cmp.l #0x40,D0   // 0xF478
	beq.s .cpushl_dc 
	cmp.l #0x80,D0   // 0xF4B8
	beq.s .cpushl_ic
	cmp.l #0xC0,D0   // 0xF4F8
	beq.s .cpushl_bc
	bra.s .no_cpushl
.cpushl_dc:
	bsr cpushl_dc
	bra.s .inc2_pc
.cpushl_bc:
	bsr cpushl_dc
.cpushl_ic:
	bsr cpushl_ic
.inc2_pc:
	addq.l #2,reg_pc(A0)
	addq.l #4,SP
	moveq #1,D0
	rts
.no_cpushl:
	move.l (SP)+,D0
#ifdef DEBUG
#if 1
	bsr debug_display_fault
#else
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug14(PC),A0
	bsr debug_display_string
	bsr debug_hex_word
	lea crlf(PC),A0
	bsr debug_display_string
	move.l (SP)+,D0
	move.l (SP)+,A0
#endif
#endif
	bra .vector_ok
	
cf68k_trace:

	bsr breakpoint_deinstall
	tst.l v_breakpoint_remove
	beq .vector_ok
	tst.l v_suspend_task
	beq .vector_ok
	tst.l cpu_trace_thru
	beq.s .no_trace_thru
	// reinstall all breakpoints except for one a current address
	bsr breakpoint_install
//	jsr unprotect_code
	move.l A0,-(SP)
	move.l cpu_trace_thru,A0 // place breakpoint at current address
	move.w #0x4AFC,(A0)      // ILLEGAL
	bsr cpushl_dc
	bsr cpushl_ic
//	jsr protect_code
	move.l (SP)+,A0
	bclr #7,reg_sr(A0)       // SR: trace off
	clr.l cpu_trace_thru
	bra .end_trace
.no_trace_thru:
	subq.l #1,cpu_trace_count
	bgt .end_trace
	clr.l cpu_trace_count
	bclr #7,reg_sr(A0)       // SR: trace off
.display_registers_and_suspend_task:
	bsr debug_display_sr_pc
	bsr debug_display_registers
	move.l reg_pc(A0),D0
	bsr debug_display_disassemble_pc
	move.l cpu_step_over,D0
	beq.s .no_breakpoint_remove
	lea -20(SP),SP
	movem.l D1-D2/A0-A2,(SP)
	move.l D0,-(SP)
	move.l v_breakpoint_remove,A0
	jsr (A0)
	addq.l #4,SP
	movem.l (SP),D1-D2/A0-A2 
	lea 20(SP),SP
	clr.l cpu_step_over
.no_breakpoint_remove:
	lea -20(SP),SP
	movem.l D1-D2/A0-A2,(SP)
	clr.l -(SP)              // suspend current task
	move.l v_suspend_task,A0
	jsr (A0)
	addq.l #4,SP
	movem.l (SP),D1-D2/A0-A2 
	lea 20(SP),SP
	move.l cpu_trace_thru,D0
	or.l cpu_trace_count,D0
	beq.s .end_trace
	bset #7,reg_sr(A0)       // SR: trace on
.end_trace:
	moveq #1,D0
	rts

cf68k_format_error:

	bsr breakpoint_deinstall
	bsr debug_display_fault
	moveq #0x38,D0
	
.error:
	move.l D0,A1
	tst.l (A1)               // null vector
	bne.s .vector_ok
	move.l #0xE00FB6,D0
	move.l D0,(A1)           // restore vector
.vector_ok:
	move.l reg_pc(A0),D0
	move.l D0,save_pc
	move.w reg_sr(A0),D0
	move.w D0,save_sr 
	// Let 680x0 virtual machine handle all these exceptions
	moveq #0,D0
	rts

cf68k_trap0:
	moveq #0,D0
	bra .end_test_trap
cf68k_trap1:
#define BKPT_PERM 1
	moveq #1,D0
	tst.b trap_breakpoint
	beq .test_trap
	tst.l v_breakpoint_add	
	beq .test_trap
	tst.l v_breakpoint_install
	beq .test_trap
	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
	.chip 68060
	move.l USP,A1
	.chip 5200
	cmp.l #SDRAM_SIZE,A1
	bcc.s .not_mshrink
	moveq #0,D0
	move.w (A1),D0           // function
             cmp.l #0x4A,D0           // Mshrink
             bne.s .not_mshrink
	move.l #0x4D694E54,D0    // MiNT
	bsr get_cookie
	beq.s .not_mshrink
             move.l reg_pc(A0),D0
             beq.s .not_mshrink
	cmp.l #SDRAM_SIZE,D0
	bcc.s .not_mshrink
             cmp.l #0xE00000,D0
             bcs.s .mshrink_breakpoint_ok
             cmp.l #0x1000000,D0
             bcs.s .not_mshrink
.mshrink_breakpoint_ok:
	pea BKPT_PERM
	move.l D0,-(SP)          // address breakpoint
	bsr breakpoint_deinstall
	move.l v_breakpoint_add,A0
	jsr (A0)
	addq.l #8,SP
	pea -1
	move.l v_breakpoint_install,A0
	jsr (A0)
	addq.l #4,SP
.not_mshrink:
	movem.l (SP),D0-D2/A0-A2 
	lea 24(SP),SP
	bra.s .test_trap
cf68k_trap2:
	moveq #2,D0
	bra.s .test_trap
cf68k_trap3:
	moveq #3,D0
	bra.s .test_trap
cf68k_trap4:
	moveq #4,D0
	bra.s .test_trap
cf68k_trap5:
	moveq #5,D0
	bra.s .test_trap
cf68k_trap6:
	moveq #6,D0
	bra.s .test_trap
cf68k_trap7:
	moveq #7,D0
	bra.s .test_trap
cf68k_trap8:
	moveq #8,D0
	bra.s .test_trap
cf68k_trap9:
	moveq #9,D0
	bra.s .test_trap
cf68k_trap10:
	moveq #10,D0
	bra.s .test_trap
cf68k_trap11:
	moveq #11,D0
	bra.s .test_trap
cf68k_trap12:
	moveq #12,D0
	bra.s .test_trap
cf68k_trap13:
	moveq #13,D0
	bra.s .test_trap
cf68k_trap14:
	moveq #14,D0
	bra.s .test_trap
cf68k_trap15:
	moveq #15,D0
.test_trap:
	tst.b debug_trap
	beq.s .end_test_trap
	bsr debug_display_trap
.end_test_trap:
	// Let 680x0 virtual machine handle all these exceptions
	moveq #0,D0
	rts
	
//#########################################################################
//# Callbacks from emulation library for hardware-related instructions    #
//#########################################################################
	.align	2
	// Certain 680x0 instructions cannot easily be emulated because they are
	// hardware related. When the emulation library encounters one of these
	// instructions it calls the appropriate front-end routine below to handle it.
	//
	//   On entry to hardware-related instruction handler routines:
	//
	//       D0 = opcode which caused exception
	//       A0 -> RegList structure
	//
	//   You MUST handle the instruction and then return with D0 = 1 to indicate
	//   that you did so

cf68k_moves:
cf68k_bkpt:
cf68k_cas:
cf68k_cas2:
cf68k_callm:
cf68k_rtm:
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug4(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	bsr debug_display_fault
	halt
	
breakpoint_deinstall:

	move.l reg_pc(A0),D0
	move.l D0,save_pc
	move.w exception_frame0(A0),D0
	move.w D0,save_format
	moveq #0,D0              // not a breakpoint
	tst.l v_breakpoint_deinstall
	beq.s .no_v_breakpoint
	lea -20(SP),SP
	movem.l D1-D2/A0-A2,(SP)
	move.l current_tcb,-(SP) // pxCurrentTCB
	pea user_triggered
	move.l reg_pc(A0),-(SP)  // PC
	move.l v_breakpoint_deinstall,A0
	jsr (A0)
	lea 12(SP),SP
	movem.l (SP),D1-D2/A0-A2 
	lea 20(SP),SP
.no_v_breakpoint:
	tst.l D0
	rts
	
breakpoint_install:
	
	moveq #0,D0
	tst.l v_breakpoint_install
	beq.s .no_v_breakpoint
	lea -20(SP),SP
	movem.l D1-D2/A0-A2,(SP)
	move.l reg_pc(A0),-(SP)  // reinstall breakpoint and continue
	move.l v_breakpoint_install,A0
	jsr (A0)
	addq.l #4,SP
	movem.l (SP),D1-D2/A0-A2 
	lea 20(SP),SP
	tst.l D0
	rts
	
//#########################################################################
//# Callbacks from emulation library during MOVEC emulation               #
//#########################################################################
	.align	2
	// The emulation library calls the following routines during emulation of
	// the MOVEC instruction to allow you to do special processing if required.
	//
	// The routine 'cf68k_read_control_register' is called just before emulation
	// of 'MOVEC Rc,Rn' (read control register). Upon return from this routine
	// the value will be read from e.g. reg_cacr(a0)
	//
	// The routine 'cf68k_write_control_register' is called just after emulation
	// of 'MOVEC Rn,Rc' (write control register). The new value has been written
	// into e.g. reg_cacr(a0)
	//
	// On entry to each routine:
	//
	//       D0.L = 32-bit opcode of MOVEC instruction
	//       A0 -> RegList structure

cf68k_read_control_register:
	rts
	
cf68k_write_control_register:

#if 0 // #ifdef DEBUG
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug12(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	lea crlf(PC),A0
	bsr debug_display_string
	move.l (SP)+,D0
	move.l (SP)+,A0
#endif
	move.l D0,-(SP)
	and.l #0xFFF,D0
	cmp.l #0x002,D0
	bne .not_cacr // <> movec to CACR
	tst.b lock_cacr
	bne .not_cacr
	move.l reg_cacr(A0),D0
	or.l #CF_CACR_EUSP,D0
	cmp.l old_cacr,D0
	beq .not_cacr
#if 0 // #ifdef DEBUG
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug15(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	lea crlf(PC),A0
	bsr debug_display_string
	move.l (SP)+,D0
	move.l (SP)+,A0
#endif
	and.l #~CF_CACR_EUSP,D0
	cmp.l #(CF_CACR_DCINVA+CF_CACR_ICINVA),D0
	beq .cacr_ok
	cmp.l #(CF_CACR_DCINVA+CF_CACR_BCINVA+CF_CACR_ICINVA),D0
	beq .cacr_ok
	cmp.l #(CF_CACR_DEC+CF_CACR_DESB+CF_CACR_BEC+CF_CACR_IEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_DESB+CF_CACR_BEC+CF_CACR_IEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_DEC+CF_CACR_DESB+CF_CACR_BEC),D0
	beq.s .cacr_ok	
	cmp.l #(CF_CACR_DESB+CF_CACR_BEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_DEC+CF_CACR_BEC+CF_CACR_IEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_BEC+CF_CACR_IEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_DEC+CF_CACR_BEC),D0
	beq.s .cacr_ok	
	cmp.l #(CF_CACR_BEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_DEC+CF_CACR_DESB+CF_CACR_IEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_DESB+CF_CACR_IEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_DEC+CF_CACR_DESB),D0
	beq.s .cacr_ok	
	cmp.l #(CF_CACR_DESB),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_DEC+CF_CACR_IEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_IEC),D0
	beq.s .cacr_ok
	cmp.l #(CF_CACR_DEC),D0
	beq.s .cacr_ok	
	tst.l D0
	bne.s .not_cacr
.cacr_ok:
	bsr cpushl_dc
	bsr cpushl_ic
	or.l #CF_CACR_EUSP,D0
	movec.l D0,CACR
	move.l D0,old_cacr
.not_cacr:
	move.l (SP)+,D0
	rts

cpushl_dc:

	move.l A1,-(SP)
	lea 0,A1
.loop_cpushl_dc:
		dc.w 0xF469 // cpushl DC,(A1)
		addq.l #1,A1
		dc.w 0xF469 // cpushl DC,(A1)
		addq.l #1,A1
		dc.w 0xF469 // cpushl DC,(A1)
		addq.l #1,A1
		dc.w 0xF469 // cpushl DC,(A1)
		add.l #0x10-3,A1
	cmp.l #LAST_DCACHE_ADDR,A1
	ble.s .loop_cpushl_dc
	move.l (SP)+,A1
	rts

cpushl_ic:

	move.l A1,-(SP)
	lea 0,A1
.loop_cpushl_ic:
		dc.w 0xF4A9 // cpushl IC,(A1)
		addq.l #1,A1
		dc.w 0xF4A9 // cpushl IC,(A1)
		addq.l #1,A1
		dc.w 0xF4A9 // cpushl IC,(A1)
		addq.l #1,A1
		dc.w 0xF4A9 // cpushl IC,(A1)
		add.l #0x10-3,A1
	cmp.l #LAST_ICACHE_ADDR,A1
	ble.s .loop_cpushl_ic
	move.l (SP)+,A1
	rts
	
#if 0
cpushl_bc:

	move.l A1,-(SP)
	lea 0,A1
.loop_cpushl_bc:
		dc.w 0xF4A9 // cpushl IC,(A1)
		addq.l #1,A1
		dc.w 0xF4A9 // cpushl IC,(A1)
		addq.l #1,A1
		dc.w 0xF4A9 // cpushl IC,(A1)
		addq.l #1,A1
		dc.w 0xF4A9 // cpushl IC,(A1)
		add.l #0x10-3,A1
	cmp.l #LAST_ICACHE_ADDR,A1
	ble.s .loop_cpushl_ic
	move.l (SP)+,A1
	rts
#endif
	
debug_disassemble_pc:

	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
	lea library_data_area,A2
	move.l reg_pc(A2),D1
	cmp.l save_pc_cf68klib,D1
	beq .no_pc_changed
	move.l D1,save_pc_cf68klib
             cmp.l #SDRAM_SIZE,D1
             bcc .no_pc_changed
	cmp.l #0x00E00000,D1     // TOS
	bcs.s .debug_ok
	cmp.l #0x01000000,D1
	bcs .no_pc_changed
.debug_ok:
	moveq #0,D0
	move.b debug_cf68klib_count,D0
	beq.s .no_count
	subq.l #1,D0
	move.b D0,debug_cf68klib_count
	bne.s .no_count
	clr.b debug_cf68klib
.no_count:	
	lea debug19(PC),A0
	bsr debug_display_string
	moveq #28,D0
	add.l SP,D0              // CF68KLIB stack
	bsr debug_hex_long
	lea debug11+12(PC),A0
	bsr debug_display_string
	.chip 68060
	move.l USP,A0
	.chip 5200
	move.l A0,D0
	bsr debug_hex_long
	move.l A2,A0
	bsr debug_display_sr_pc
	bsr debug_display_registers
	move.l D1,D0
	bsr debug_display_disassemble_pc
.no_pc_changed:
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	rts
	
debug_display_trap:

	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
	move.l D0,D2             // TRAP #
	moveq #0,D0
	move.b debug_trap_count,D0
	beq.s .no_trap_count
	subq.l #1,D0
	move.b D0,debug_trap_count
	bne.s .no_trap_count
	clr.b debug_trap
.no_trap_count:	
	move.l reg_pc(A0),D0
	subq.l #2,D0
	bsr debug_display_disassemble_pc
	cmp.l #2,D2
	bne.s .not_trap2
	move.l reg_d0(A0),D0
	and.l #0xFFFF,D0         // code
	move.l reg_d1(A0),A1     // PB
	lea debug20(PC),A0
	cmp.l #0x73,D0           // VDI
	beq.s .info_trap2
	lea debug25(PC),A0
	cmp.l #0xC8,D0           // AES
	bne.s .no_info_trap
.info_trap2:
	bsr debug_display_string
	move.l (A1),A1           // contrl
	move.w (A1),D0           // opcode
	bsr debug_hex_word
	bra.s .crlf_trap
.not_trap2:	
	lea tab_mess_gemdos(PC),A0
	cmp.l #1,D2              // GEMDOS
	beq.s .info_trap
	lea tab_mess_bios(PC),A0
	cmp.l #13,D2             // BIOS
	beq.s .info_trap
	lea tab_mess_xbios(PC),A0
	cmp.l #14,D2             // XBIOS
	bne.s .no_info_trap
.info_trap:
	.chip 68060
	move.l USP,A1
	.chip 5200
	cmp.l #SDRAM_SIZE,A1
	bcc.s .no_info_trap
	moveq #0,D0
	move.w (A1),D0           // function
	bsr debug_display_tab
	moveq #0x20,D0
	bsr debug_display_char
	move.w (A1)+,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x2D,D0
	bsr debug_display_char
	moveq #7,D1
.loop_info_stack:
		moveq #0x20,D0
		bsr debug_display_char
		move.w (A1)+,D0
		bsr debug_hex_word
	subq.l #1,D1
	bpl.s .loop_info_stack
.crlf_trap:
	lea crlf(PC),A0
	bsr debug_display_string
.no_info_trap:
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	rts

debug_display_fault:
	
	lea -32(SP),SP
	movem.l D0-D3/A0-A3,(SP)
	move.l A0,A3
	lea debug6(PC),A0
	bsr debug_display_string
	move.w exception_frame0(A3),D0
	lsr.l #2,D0
	and.l #0xFF,D0
	move.l D0,D3             // vector
	.chip 68060
	divu #10,D0
	move.l D0,D1
	and.l #0xFF,D0
	beq.s .ex1
	divu #10,D0
	move.l D0,D2
	and.l #7,D0
	beq.s .ex2
	or.l #0x30,D0
	bsr debug_display_char
	.chip 5200
.ex2:
	swap D2
	move.w D2,D0
	or.l #0x30,D0
	bsr debug_display_char
.ex1:
	swap D1
	move.w D1,D0
	or.l #0x30,D0
	bsr debug_display_char
	lea twopoints(PC),A0
	bsr debug_display_string
	move.l D3,D0
	lea tab_mess_exc(PC),A0
	bsr debug_display_tab
	move.l current_tcb,D0
	beq.s .ex3
	cmp.l #SDRAM_SIZE,D0
	bcc.s .ex3
	lea debug18(PC),A0
	bsr debug_display_string
	move.l current_tcb,A0
	lea 0x138(A0),A0
	bsr debug_display_string
	move.l current_tcb,D0
	cmp.l tid_tos,D0
	bne.s .ex3
	move.l _run,A0
	cmp.l #SDRAM_SIZE,A0
	bcc.s .ex3
	tst.l 8(A0)              // base
	beq.s .ex3
	lea debug2(PC),A0
	bsr debug_display_string
	move.l _run,A0
	move.l 8(A0),D0          // base
	bsr debug_hex_long
.ex3:
	lea crlf(PC),A0
	bsr debug_display_string
	move.l A3,A0
	bsr debug_display_sr_pc
	cmp.l #2,D3
	bne.s .not_access_fault
	lea crlf(PC),A0
	bsr debug_display_string
	move.w exception_frame0(A3),D0
	move.w D0,D1
	and.l #0x0003,D0
	and.l #0x0C00,D1
	lsr.l #8,D1
	or.l D1,D0
	lea tab_mess_fault(PC),A0
	bsr debug_display_tab
	cmp.l #8,D0
	bcs.s .not_access_fault
	lea debug9(PC),A0        // address fault
	bsr debug_display_string
	move.l address_fault,D0
	bsr debug_hex_long
.not_access_fault:
	move.l A3,A0
	bsr debug_display_registers
	move.l reg_pc(A3),D0
	bsr debug_display_disassemble_pc
	cmp.l #64,D3             // interrupt
	bcs.s .not_an_interrupt
	tst.b debug_int7
	beq.s .no_handler_fault
	cmp.l #71,D3             // edge port flag 7 interrupt
	bne.s .no_handler_fault
	moveq #7,D0
	bset.b D0,MCF_EPORT_EPFR // clear interrupt
#ifdef MCF5445X
	move.l #~INTC_IMRL_INT_MASK7,D0
	and.l D0,MCF_INTC_IMRL0  // enable interrupt
#else /* MCF548X */
	move.l #~MCF_INTC_IMRL_INT_MASK7,D0
	and.l D0,MCF_INTC_IMRL   // enable interrupt
#endif
	bra.s .no_handler_fault
.not_an_interrupt:
	move.l handler_fault,D0
	beq.s .no_handler_fault
	move.l D3,-(SP)          // vector
	move.l reg_pc(A3),-(SP)
	move.l D0,A0
	jsr (A0)
	addq.l #8,SP
.no_handler_fault:
	movem.l (SP),D0-D3/A0-A3
	lea 32(SP),SP
	rts

debug_display_registers:

	lea -28(SP),SP
	movem.l D0-D2/A0-A3,(SP)
	move.l A0,A3
	lea debug10(PC),A0    // SSP
	bsr debug_display_string
	move.l reg_ssp(A3),D0 // SSP
	bsr debug_hex_long
	lea debug11(PC),A0    // USP
	bsr debug_display_string
	move.l reg_usp(A3),D0 // USP
	bsr debug_hex_long
	lea reg_d0(A3),A1
	lea reg_a0(A3),A2
	moveq #7,D1
.loop_reg:
		lea crlf(PC),A0
		bsr debug_display_string
		moveq #0x44,D0
		bsr debug_display_char
		moveq #7,D0
		sub.l D1,D0
		or.l #0x30,D0
		move.w D0,-(SP)
		bsr debug_display_char
		lea twopoints(PC),A0
		bsr debug_display_string
		move.l (A1)+,D0
		bsr debug_hex_long // data registers
		moveq #0x20,D0
		bsr debug_display_char
		bsr debug_display_char
		moveq #0x41,D0
		bsr debug_display_char
		move.w (SP),D0
		bsr debug_display_char
		lea twopoints(PC),A0
		bsr debug_display_string
		move.l (A2)+,D0
		bsr debug_hex_long // address registers
		addq.l #2,SP
	subq.l #1,D1
	bpl.s .loop_reg
	lea crlf(PC),A0
	bsr debug_display_string
	movem.l (SP),D0-D2/A0-A3
	lea 28(SP),SP
	rts
	
debug_display_disassemble_pc:

	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
	move.l D0,D1	
             cmp.l #SDRAM_SIZE,D1     // bad PC
             bcc.s .no_pci_drivers
	bsr test_pci
	bne.s .no_pci_drivers
	move.l D1,-(SP)
	jsr 52(A0)               // drivers PCI in flash, disassemble_pc
	addq.l #4,SP
	move.l D0,A0
	tst.b (A0)
	beq.s .no_pci_drivers
	bsr debug_display_string
	lea crlf(PC),A0
	bsr debug_display_string
.no_pci_drivers:
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	rts

debug_display_tab:

	move.l D1,-(SP)
	move.l D0,-(SP)
	moveq #0,D0
.dt1:
		move.b (A0),D1
		extb.l D1
		cmp.l #-1,D1
		beq.s .dt3
		move.l (SP),D1
		cmp.l D1,D0
		beq.s .dt4
.dt2:
		tst.b (A0)+
		bne.s .dt2
		addq.l #1,D0
	bra.s .dt1
.dt4:
	bsr debug_display_string
.dt3:
	move.l (SP)+,D0
	move.l (SP)+,D1
	rts
		
debug_display_string:

	move.l D0,-(SP)
	move.l A0,-(SP)
.dds2:
		move.b (A0)+,D0
		beq.s .dds1
		bsr debug_display_char
	bra.s .dds2
.dds1:
	move.l (SP)+,A0
	move.l (SP)+,D0
	rts

debug_display_sr_pc:

	move.l A0,-(SP)
	lea crlf(PC),A0
	bsr debug_display_string
	lea debug7(PC),A0        // SR
	bsr debug_display_string
	move.l (SP),A0
	move.w reg_sr(A0),D0     // SR
	bsr debug_hex_word
	lea debug8(PC),A0        // PC
	bsr debug_display_string
	move.l (SP)+,A0
	move.l reg_pc(A0),D0

debug_hex_long:

	move.l D0,-(SP)
	swap D0
	bsr.s debug_hex_word
	move.l (SP)+,D0

debug_hex_word:

	move.w D0,-(SP)
	lsr.l #8,D0          
	bsr.s debug_hex_byte     
	move.w (SP)+,D0

debug_hex_byte:

	move.w D0,-(SP)
	lsr.l #4,D0        
	bsr.s debug_hex_char      
	move.w (SP)+,D0      

debug_hex_char:

	and.l #0xF,D0      
	or.l #0x30,D0      
	cmp.l #0x3A,D0     
	bcs.s debug_display_char  
	addq.l #7,D0   

debug_display_char:

	move.l D1,-(SP)
.wait_uart:
	move.b MCF_UART_USR0,D1
	and.l  #MCF_UART_USR_TXRDY,D1
	beq.s .wait_uart
	move.b D0,MCF_UART_UTB0  // send the character
	move.l (SP)+,D1
	rts
	
get_cookie:

	move.l D1,-(SP)
	move.l A0,-(SP)
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
.end_cookie:
	move.l (SP)+,A0
	move.l (SP)+,D1
	tst.l D0
	rts

debug1:	.byte 13,10,10
	.asciz "Breakpoint encountered at 0x"
debug2:	.asciz " - Base: "
debug3:	.asciz "cf68k emulation error, opcode 0x"
debug4:	.ascii "Hardware-related instructions not emulated"
	.byte 13,10,0
debug5:	.ascii "CF68K emulation started"
	.byte 13,10,0
debug6:	.byte 13,10
	.asciz "Fault #"
debug7:	.byte 13,10
	.asciz "Status Register (SR): "
debug8:	.byte 13,10
	.asciz "Program Counter (PC): "
debug9:	.byte 13,10
	.asciz "Address Fault: "
debug10:	.byte 13,10
	.asciz "Supervisor Stack (SSP): "
debug11:	.byte 13,10
	.asciz "User Stack (USP): "
//debug12:	.asciz "movec opcode 0x"
debug13:	.asciz "Line A opcode 0x"
debug14:	.asciz "Line F opcode 0x"
//debug15:	.asciz "movec Dx,CACR 0x"
debug16:	.ascii "Format error"
	.byte 13,10,0
debug17:	.ascii "Interrupt"
	.byte 13,10
	.asciz "PC 0x"
debug17sr:	.asciz " SR 0x"
debug17f:	.asciz " Format 0x"
debug18:	.asciz " - Task: "
debug19:	.asciz "CF68KLIB stack (SP): "
debug20:	.asciz "VDI 0x"
#if 0
debug21:	.ascii "Debug interrupt ON"
	.byte 13,10,0
debug22:	.ascii "Debug interrupt OFF"
	.byte 13,10,0
debug23:	.ascii "Debug interrupt"
	.byte 13,10
	.asciz "PC 0x"
#endif
debug24:	.asciz "Uncompress PCI drivers from 0x"
debug24a:	.asciz " (size 0x"
debug24b:	.asciz ") to 0x01000000 (size 0x"
debug24c:	.ascii ")"
	.byte 13,10,0
debug25:	.asciz "AES 0x"
debug26:	.ascii "Init MMU"
	.byte 13,10,0
debug27:	.ascii "MMU OK"
	.byte 13,10,0
crlf:	.byte 13,10,0
twopoints:	.asciz ": "

tab_mess_exc:
	.byte 0
	.byte 0
	.asciz "Access Fault"            // 2
	.asciz "Address Error"           // 3
	.asciz "Illegal Instruction"     // 4
	.asciz "Integer Zero Divide"     // 5
	.byte 0
	.byte 0
	.asciz "Privilege Violation"     // 8
	.asciz "Trace"                   // 9
	.asciz "Line A"                  // 10
	.asciz "Line F"                  // 11
	.asciz "Non-PC Break Debug Int"  // 12
	.asciz "PC Breakpoint Debug Int" // 13
	.asciz "Format Error"            // 14
	.asciz "Uninitialised Interrupt" // 15
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.asciz "Spurious Interrupt"      // 24
	.byte 0 // asciz "Interrupt level 1"       // 25
	.byte 0 // asciz "Interrupt level 2"       // 26
	.byte 0 // asciz "Interrupt level 3"       // 27
	.byte 0 // asciz "Interrupt level 4"       // 28
	.byte 0 // asciz "Interrupt level 5"       // 29
	.byte 0 // asciz "Interrupt level 6"       // 30
	.byte 0 // asciz "Interrupt level 7"       // 31
	.asciz "Trap #0"                 // 32
	.asciz "Trap #1"                 // 33
	.asciz "Trap #2"                 // 34
	.asciz "Trap #3"                 // 35
	.asciz "Trap #4"                 // 36
	.asciz "Trap #5"                 // 37
	.asciz "Trap #6"                 // 38
	.asciz "Trap #7"                 // 39
	.asciz "Trap #8"                 // 40
	.asciz "Trap #9"                 // 41
	.asciz "Trap #10"                // 42
	.asciz "Trap #11"                // 43
	.asciz "Trap #12"                // 44
	.asciz "Trap #13"                // 45
	.asciz "Trap #14"                // 46
	.asciz "Trap #15"                // 47
#if 0 // too large 65KB max
	.byte 0
	.asciz "FPU Branch Cond"         // 49
	.asciz "FPU Zero Divide"         // 50
	.asciz "FPU Underflow"           // 51
	.asciz "FPU Operand Error"       // 52
	.asciz "FPU Overflow"            // 53
	.asciz "FPU NAN"                 // 54
	.asciz "FPU Denorm Number"       // 55
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.asciz "Unsupported Instruction" // 61
	.byte 0
	.byte 0
#if 0 /* unused since tables are moved with OFFSET_INT_CF68KLIB */
#ifndef MCF5445X
	.byte 0
	.asciz "Edge port flag 1 Int"    // 65
	.asciz "Edge port flag 2 Int"    // 66
	.asciz "Edge port flag 3 Int"    // 67
	.asciz "Edge port flag 4 Int"    // 68
	.asciz "Edge port flag 5 Int"    // 69
	.asciz "Edge port flag 6 Int"    // 70
	.asciz "Edge port flag 7 Int"    // 71
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.asciz "USB 2.0 Interrupt"       // 79
	.asciz "USB 2.0 Interrupt"       // 80
	.asciz "USB 2.0 Interrupt"       // 81
	.asciz "USB 2.0 Interrupt"       // 82
	.asciz "USB 2.0 Interrupt"       // 83
	.asciz "USB 2.0 Interrupt"       // 84
	.asciz "USB 2.0 Interrupt"       // 85
	.asciz "USB 2.0 Interrupt"       // 86
	.asciz "USB 2.0 Interrupt"       // 87
	.asciz "USB 2.0 Interrupt"       // 88
	.asciz "DSPI Interrupt"          // 89
	.asciz "DSPI Interrupt"          // 90
	.asciz "DSPI Interrupt"          // 91
	.asciz "DSPI Interrupt"          // 92
	.asciz "DSPI Interrupt"          // 93
	.asciz "DSPI Interrupt"          // 94
	.asciz "DSPI Interrupt"          // 95
	.asciz "PSC3 Interrupt"          // 96	
	.asciz "PSC2 Interrupt"          // 97
	.asciz "PSC1 Interrupt"          // 98
	.asciz "PSC0 Interrupt"          // 99
	.asciz "Comm Timer Interrupt"    // 100
	.asciz "SEC Interrupt"           // 101
	.asciz "FEC1 Interrupt"          // 102
	.asciz "FEC0 Interrupt"          // 103
	.asciz "I2C Interrupt"           // 104
	.asciz "PCIARB Interrupt"        // 105
	.asciz "CBPCI Interrupt"         // 106
	.asciz "XLBPCI Interrupt"        // 107
	.byte 0
	.byte 0
	.byte 0
	.asciz "XLBARB Interrupt"        // 111
	.asciz "DMA Interrupt"           // 112
	.asciz "CAN0 ERROR Interrupt"    // 113
	.asciz "CAN0 BUSOFF Interrupt"   // 114
	.asciz "CAN0 MBOR Interrupt"     // 115
	.byte 0
	.asciz "SLT1 Interrupt"          // 117
	.asciz "SLT0 Interrupt"          // 118
	.asciz "CAN1 ERROR Interrupt"    // 119
	.asciz "CAN1 BUSOFF Interrupt"   // 120
	.asciz "CAN1 MBOR Interrupt"     // 121
	.byte 0
	.asciz "GPT3 Interrupt"          // 123
	.asciz "GPT2 Interrupt"          // 124
	.asciz "GPT1 Interrupt"          // 125
	.asciz "GPT0 Interrupt"          // 126
#endif
#endif
#endif
	.byte -1

tab_mess_fault:
 	.asciz "Not an access or address error"
#ifndef MCF5445X
 	.asciz "Arbiter timeout interrupt"
#else
	.byte 0
#endif
 	.byte 0
 	.byte 0
 	.asciz "Protection fault"
 	.asciz "TLB miss on opword instruction"
 	.asciz "TLB miss on ext word instruction"
 	.byte 0
 	.asciz "Error on data write"
 	.asciz "Error to write-protected space"
 	.asciz "TLB miss on data write"
 	.byte 0
 	.asciz "Error on data read"
 	.asciz "Read error of protected space"
 	.asciz "TLB miss on data read"
 	.byte -1
 	
tab_mess_gemdos:
#ifndef DEBUG
	.asciz "Pterm0"   // 0
	.asciz "Cconin"   // 1
	.asciz "Cconout"  // 2
	.asciz "Cauxin"   // 3
	.asciz "Cauxout"  // 4
	.asciz "Cprnout"  // 5
	.asciz "Crawio"   // 6
	.asciz "Crawcin"  // 7
	.asciz "Cnecin"   // 8
	.asciz "Cconws"   // 9
	.asciz "Cconrs"   // 0xA
	.asciz "Cconis"   // 0xB
	.byte 0           // 0xC
	.byte 0           // 0xD
	.asciz "Dsetdrv"  // 0xE
	.byte 0           // 0xF
	.asciz "Cconos"   // 0x10
	.asciz "Cprnos"   // 0x11
	.asciz "Cauxis"   // 0x12
	.asciz "Cauxos"   // 0x13
	.asciz "Maddalt"  // 0x14
	.asciz "Srealloc" // 0x15
	.asciz "Slbopen"  // 0x16
	.asciz "Slbclose" // 0x17
	.byte 0           // 0x18
	.asciz "Dgetdrv"  // 0x19
	.asciz "Fsetdta"  // 0x1A
	.byte 0           // 0x1B
	.byte 0           // 0x1C
	.byte 0           // 0x1D
	.byte 0           // 0x1E
	.byte 0           // 0x1F
	.asciz "Super"    // 0x20
	.byte 0           // 0x21
	.byte 0           // 0x22
	.byte 0           // 0x23
	.byte 0           // 0x24
	.byte 0           // 0x25
	.byte 0           // 0x26
	.byte 0           // 0x27
	.byte 0           // 0x28
	.byte 0           // 0x29
	.asciz "Tgetdate" // 0x2A
	.asciz "Tsetdate" // 0x2B
	.asciz "Tgettime" // 0x2C
	.asciz "Tsettime  // 0x2D	(ushort date)
	.byte 0           // 0x2E
	.asciz "Fgetdta"  // 0x2F
	.asciz "Sversion" // 0x30
	.asciz "Ptermres" // 0x31
	.byte 0           // 0x32
	.asciz "Sconfig"  // 0x33
	.byte 0           // 0x34
	.byte 0           // 0x35
	.asciz "Dfree"    // 0x36
	.byte 0           // 0x37
	.byte 0           // 0x38
	.asciz "Dcreate"  // 0x39
	.asciz "Ddelete"  // 0x3A
	.asciz "Dsetpath" // 0x3B
	.asciz "Fcreate"  // 0x3C
	.asciz "Fopen"    // 0x3D
	.asciz "Fclose"   // 0x3E
	.asciz "Fread"    // 0x3F
	.asciz "Fwrite"   // 0x40
	.asciz "Fdelete"  // 0x41
	.asciz "Fseek"    // 0x42
	.asciz "Fattrib"  // 0x43
	.asciz "Mxalloc"  // 0x44
	.asciz "Fdup"     // 0x45
	.asciz "Fforce"   // 0x46
	.asciz "Dgetpath" // 0x47
	.asciz "Malloc"   // 0x48
	.asciz "Mfree"    // 0x49
	.asciz "Mshrink"  // 0x4A
	.asciz "Pexec"    // 0x4B
	.asciz "Pterm"    // 0x4C
	.byte 0           // 0x4D
	.asciz "Fsfirst"  // 0x4E
	.asciz "Fsnext"   // 0x4F
	.byte 0           // 0x50
	.byte 0           // 0x51
	.byte 0           // 0x52
	.byte 0           // 0x53
	.byte 0           // 0x54
	.byte 0           // 0x55
	.asciz "Frename"  // 0x56
	.asciz "Fdatime"  // 0x57
	.byte 0           // 0x58
	.byte 0           // 0x59
	.byte 0           // 0x5A
	.byte 0           // 0x5B
	.asciz "Flock"    // 0x5C
#if 0 // too large 65KB max
	.byte 0           // 0x5D
	.byte 0           // 0x5E
	.byte 0           // 0x5F
	.byte 0           // 0x60
	.byte 0           // 0x61
	.byte 0           // 0x62
	.byte 0           // 0x63
	.byte 0           // 0x64
	.byte 0           // 0x65
	.byte 0           // 0x66
	.byte 0           // 0x67
	.byte 0           // 0x68
	.byte 0           // 0x69
	.byte 0           // 0x6A
	.byte 0           // 0x6B
	.byte 0           // 0x6C
	.byte 0           // 0x6D
	.byte 0           // 0x6E
	.byte 0           // 0x6F
	.byte 0           // 0x70
	.byte 0           // 0x71
	.byte 0           // 0x72
	.byte 0           // 0x73
	.byte 0           // 0x74
	.byte 0           // 0x75
	.byte 0           // 0x76
	.byte 0           // 0x77
	.byte 0           // 0x78
	.byte 0           // 0x79
	.byte 0           // 0x7A
	.byte 0           // 0x7B
	.byte 0           // 0x7C
	.byte 0           // 0x7D
	.byte 0           // 0x7E
	.byte 0           // 0x7F
	.byte 0           // 0x80
	.byte 0           // 0x81
	.byte 0           // 0x82
	.byte 0           // 0x83
	.byte 0           // 0x84
	.byte 0           // 0x85
	.byte 0           // 0x86
	.byte 0           // 0x87
	.byte 0           // 0x88
	.byte 0           // 0x89
	.byte 0           // 0x8A
	.byte 0           // 0x8B
	.byte 0           // 0x8C
	.byte 0           // 0x8D
	.byte 0           // 0x8E
	.byte 0           // 0x8F
	.byte 0           // 0x90
	.byte 0           // 0x91
	.byte 0           // 0x92
	.byte 0           // 0x93
	.byte 0           // 0x94
	.byte 0           // 0x95
	.byte 0           // 0x96
	.byte 0           // 0x97
	.byte 0           // 0x98
	.byte 0           // 0x99
	.byte 0           // 0x9A
	.byte 0           // 0x9B
	.byte 0           // 0x9C
	.byte 0           // 0x9D
	.byte 0           // 0x9E
	.byte 0           // 0x9F
	.byte 0           // 0xA0
	.byte 0           // 0xA1
	.byte 0           // 0xA2
	.byte 0           // 0xA3
	.byte 0           // 0xA4
	.byte 0           // 0xA5
	.byte 0           // 0xA6
	.byte 0           // 0xA7
	.byte 0           // 0xA8
	.byte 0           // 0xA9
	.byte 0           // 0xAA
	.byte 0           // 0xAB
	.byte 0           // 0xAC
	.byte 0           // 0xAD
	.byte 0           // 0xAE
	.byte 0           // 0xAF
	.byte 0           // 0xB0
	.byte 0           // 0xB1
	.byte 0           // 0xB2
	.byte 0           // 0xB3
	.byte 0           // 0xB4
	.byte 0           // 0xB5
	.byte 0           // 0xB6
	.byte 0           // 0xB7
	.byte 0           // 0xB8
	.byte 0           // 0xB9
	.byte 0           // 0xBA
	.byte 0           // 0xBB
	.byte 0           // 0xBC
	.byte 0           // 0xBD
	.byte 0           // 0xBE
	.byte 0           // 0xBF
	.byte 0           // 0xC0
	.byte 0           // 0xC1
	.byte 0           // 0xC2
	.byte 0           // 0xC3
	.byte 0           // 0xC4
	.byte 0           // 0xC5
	.byte 0           // 0xC6
	.byte 0           // 0xC7
	.byte 0           // 0xC8
	.byte 0           // 0xC9
	.byte 0           // 0xCA
	.byte 0           // 0xCB
	.byte 0           // 0xCC
	.byte 0           // 0xCD
	.byte 0           // 0xCE
	.byte 0           // 0xCF
	.byte 0           // 0xD0
	.byte 0           // 0xD1
	.byte 0           // 0xD2
	.byte 0           // 0xD3
	.byte 0           // 0xD4
	.byte 0           // 0xD5
	.byte 0           // 0xD6
	.byte 0           // 0xD7
	.byte 0           // 0xD8
	.byte 0           // 0xD9
	.byte 0           // 0xDA
	.byte 0           // 0xDB
	.byte 0           // 0xDC
	.byte 0           // 0xDD
	.byte 0           // 0xDE
	.byte 0           // 0xDF
	.byte 0           // 0xE0
	.byte 0           // 0xE1
	.byte 0           // 0xE2
	.byte 0           // 0xE3
	.byte 0           // 0xE4
	.byte 0           // 0xE5
	.byte 0           // 0xE6
	.byte 0           // 0xE7
	.byte 0           // 0xE8
	.byte 0           // 0xE9
	.byte 0           // 0xEA
	.byte 0           // 0xEB
	.byte 0           // 0xEC
	.byte 0           // 0xED
	.byte 0           // 0xEE
	.byte 0           // 0xEF
	.byte 0           // 0xF0
	.byte 0           // 0xF1
	.byte 0           // 0xF2
	.byte 0           // 0xF3
	.byte 0           // 0xF4
	.byte 0           // 0xF5
	.byte 0           // 0xF6
	.byte 0           // 0xF7
	.byte 0           // 0xF8
	.byte 0           // 0xF9
	.byte 0           // 0xFA
	.byte 0           // 0xFB
	.byte 0           // 0xFC
	.byte 0           // 0xFD
	.byte 0           // 0xFE
	.asciz "Syield"   // 0xFF
	.asciz "Fpipe"    // 0x100
	.asciz "Ffchown"  // 0x101
	.asciz "Ffchmod"  // 0x102
	.asciz "Fsync"    // 0x103
	.asciz "Fcntl"    // 0x104
	.asciz "Finstat"  // 0x105
	.asciz "Foutstat" // 0x106
	.asciz "Fgetchar" // 0x107
	.asciz "Fputchar" // 0x108
	.asciz "Pwait"    // 0x109
	.asciz "Pnice"    // 0x10A
	.asciz "Pgetpid"  // 0x10B
	.asciz "Pgetppid" // 0x10C
	.asciz "Pgetpgrp" // 0x10D
	.asciz "Psetpgrp" // 0x10E
	.asciz "Pgetuid"  // 0x10F
	.asciz "Psetuid"  // 0x110
	.asciz "Pkill"    // 0x111
	.asciz "Psignal"  // 0x112
	.asciz "Pvfork"   // 0x113
	.asciz "Pgetgid"  // 0x114
	.asciz "Psetgid"  // 0x115
	.asciz "Psigblock" // 0x116
	.asciz "Psigsetmask" // 0x117
	.asciz "Pusrval"  // 0x118
	.asciz "Pdomain"  // 0x119
	.asciz "Psigreturn" // 0x11A
	.asciz "Pfork"    // 0x11B
	.asciz "Pwait3"   // 0x11C
	.asciz "Fselect"  // 0x11D
	.asciz "Prusage"  // 0x11E
	.asciz "Psetlimit" // 0x11F
	.asciz "Talarm"   // 0x120
	.asciz "Ppause"   // 0x121
	.asciz "Ssysconf" // 0x122
	.asciz "Psigpending" // 0x123
	.asciz "Dpathconf" // 0x124
	.asciz "Pmsg"     // 0x125
	.asciz "Fmidipipe" // 0x126
	.asciz "Prenice"  // 0x127		(short pid, short increment)
	.asciz "Dopendir" // 0x128
	.asciz "Dreaddir" // 0x129
	.asciz "Drewind"  // 0x12A
	.asciz "Dclosedir" // 0x12B
	.asciz "Fxattr"   // 0x12C
	.asciz "Flink"    // 0x12D
	.asciz "Fsymlink" // 0x12E
	.asciz "Freadlink" // 0x12F
	.asciz "Dcntl"    // 0x130
	.asciz "Fchown"   // 0x131
	.asciz "Fchmod"   // 0x132
	.asciz "Pumask"   // 0x133
	.asciz "Psemaphore" // 0x134
	.asciz "Dlock"    // 0x135
	.asciz "Psigpause" // 0x136
	.asciz "Psigaction" // 0x137
	.asciz "Pgeteuid" // 0x138
	.asciz "Pgetegid" // 0x139
	.asciz "Pwaitpid" // 0x13A
	.asciz "Dgetcwd"  // 0x13B
	.asciz "Salert"   // 0x13C
	.asciz "Tmalarm"  // 0x13D
	.asciz "Psigintr" // 0x13E
	.asciz "Suptime"  // 0x13F
	.asciz "Ptrace"   // 0x140
	.asciz "Mvalidate" // 0x141
	.asciz "Dxreaddir" // 0x142
	.asciz "Pseteuid" // 0x143
	.asciz "Psetegid" // 0x144
	.asciz "Pgetauid" // 0x145
	.asciz "Psetauid" // 0x146
	.asciz "Pgetgroups" // 0x147
	.asciz "Psetgroups" // 0x148
	.asciz "Tsetitimer" // 0x149
	.asciz "Dchroot"  // 0x14A
	.asciz "Fstat64"  // 0x14B
	.asciz "Fseek64"  // 0x14C
	.asciz "Dsetkey"  // 0x14D
	.asciz "Psetreuid" // 0x14E
	.asciz "Psetregid" // 0x14F
	.asciz "Ssync"    // 0x150
	.asciz "Shutdown"  // 0x151
	.asciz "Dreadlabel" // 0x152
	.asciz "Dwritelabel" // 0x153
	.asciz "Ssystem"  // 0x154
	.asciz "Tgettimeofday" // 0x155
	.asciz "Tsettimeofday" // 0x156
	.asciz "Tadjtime" // 0x157
	.asciz "Pgetpriority" // 0x158
	.asciz "Psetpriority" // 0x159
	.asciz "Fpoll"    // 0x15A
	.asciz "Fwritev"  // 0x15B
	.asciz "Freadv"   // 0x15C
	.asciz "Ffstat"   // 0x15D
	.asciz "Psysctl"  // 0x15E
	.asciz "Semulation" // 0x15F
	.asciz "Fsocket"  // 0x160
	.asciz "Fsocketpair" // 0x161
	.asciz "Faccept"  // 0x162
	.asciz "Fconnect" // 0x163
	.asciz "Fbind"    // 0x164
	.asciz "Flisten"  // 0x165
	.asciz "Frecvmsg" // 0x166
	.asciz "Fsendmsg" // 0x167
	.asciz "Frecvfrom" // 0x168
	.asciz "Fsendto"  // 0x169
	.asciz "Fsetsockopt" // 0x16A
	.asciz "Fgetsockopt" // 0x16B
	.asciz "Fgetpeername" // 0x16C
	.asciz "Fgetsockname" // 0x16D
	.asciz "Fshutdown" // 0x16E
	.byte 0           // 0x16F
	.asciz "Pshmget"  // 0x170
	.asciz "Pshmctl"  // 0x171
	.asciz "Pshmat"   // 0x172
	.asciz "Pshmdt"   // 0x173
	.asciz "Psemget"  // 0x174		(long key, long nsems, long semflg)
	.asciz "Psemctl"  // 0x175
	.asciz "Psemop"   // 0x176
	.asciz "Psemconfig" // 0x177
	.asciz "Pmsgget"  // 0x178
	.asciz "Pmsgctl"  // 0x179
	.asciz "Pmsgsnd"  // 0x17A
	.asciz "Pmsgrcv"  // 0x17B
	.byte 0           // 0x17C
	.asciz "Maccess"  // 0x17D
	.byte 0           // 0x17E
	.byte 0           // 0x17F
	.asciz "Fchown16" // 0x180
#endif
#endif /* DEBUG */
	.byte -1

tab_mess_bios:
#ifndef DEBUG
	.asciz "Getmpb"   // 0
	.asciz "Bconstat" // 1
	.asciz "Bconin"   // 2
	.asciz "Bconout"  // 3
	.asciz "Rwabs"    // 4
	.asciz "Setexc"   // 5
	.asciz "Tickcal"  // 6
	.asciz "Getbpb"   // 7
	.asciz "Bcostat"  // 8
	.asciz "Mediach"  // 9
	.asciz "Drvmap"   // 0xA
	.asciz "Kbshift"  // 0xB
#endif /* DEBUG */
	.byte -1

tab_mess_xbios:
#ifndef DEBUG
	.asciz "Initmouse" // 0
	.asciz "Ssbrk"    // 1
	.asciz "Physbase" // 2
	.asciz "Logbase"  // 3
	.asciz "Getrez"   // 4
	.asciz "Vsetscreen" // 5
	.asciz "Setpalette" // 6
	.asciz "Setcolor" // 7
	.asciz "Floprd"   // 8
	.asciz "Flopwr"   // 9
	.asciz "Flopfmt"  // 0xA
	.asciz "Dbmsg"    // 0xB
	.asciz "Midiws"   // 0xC
	.asciz "Mfpint"   // 0xD
	.asciz "Iorec"    // 0xE
	.asciz "Rsconf"   // 0xF
	.asciz "Keytbl"   // 0x10
	.asciz "Random"   // 0x11
	.asciz "Protobt"  // 0x12
	.asciz "Flopver"  // 0x13
	.asciz "Scrdmp"   // 0x14
	.asciz "Cursconf" // 0x15
	.asciz "Settime"  // 0x16
	.asciz "Gettime"  // 0x17
	.asciz "Bioskeys" // 0x18
	.asciz "Ikbdws"   // 0x19
	.asciz "Jdisint"  // 0x1A
	.asciz "Jenabint" // 0x1B
	.asciz "Giaccess" // 0x1C
	.asciz "Offgibit" // 0x1D
	.asciz "Ongibit"  // 0x1E
	.asciz "Xbtimer"  // 0x1F
	.asciz "Dosound"  // 0x20
	.asciz "Setprt"   // 0x21
	.asciz "Kbdvbase" // 0x22
	.asciz "Kbrate"   // 0x23
	.asciz "Prtblk"   // 0x24
	.asciz "Vsync"    // 0x25
	.asciz "Supexec"  // 0x26
	.asciz "Puntaes"  // 0x27
	.byte 0           // 0x28
	.asciz "Floprate" // 0x29
	.asciz "DMAread"  // 0x2A
	.asciz "DMAwrite" // 0x2B
	.asciz "Bconmap"  // 0x2C
	.byte 0           // 0x2D
	.asciz "NVMaccess" // 0x2E
	.asciz "Waketime" // 0x2F
	.asciz "Metainit" // 0x30
	.asciz "Metaopen" // 0x31
	.asciz "Metaclose" // 0x32
	.asciz "Metaread" // 0x33
	.asciz "Metawrite" // 0x34
	.asciz "Metaseek" // 0x35
	.asciz "Metastatus" // 0x36
	.asciz "Metaioctl" // 0x37
	.byte 0           // 0x38
	.byte 0           // 0x39
	.byte 0           // 0x3A
	.asciz "Metastartaudio" // 0x3B
	.asciz "Metastopaudio" // 0x3C
	.asciz "Metasetsongtime" // 0x3D
	.asciz "Metagettoc" // 0x3E
	.asciz "Metadiscinfo" // 0x3F
	.asciz "Blitmode" // 0x40
#if 0 // too large 65KB max
	.byte 0           // 0x41
	.byte 0           // 0x42
	.byte 0           // 0x43
	.byte 0           // 0x44
	.byte 0           // 0x45
	.byte 0           // 0x46
	.byte 0           // 0x47
	.byte 0           // 0x48
	.byte 0           // 0x49
	.byte 0           // 0x4A
	.byte 0           // 0x4B
	.byte 0           // 0x4C
	.byte 0           // 0x4D
	.byte 0           // 0x4E
	.byte 0           // 0x4F
	.asciz "EsetShift" // 0x50
	.asciz "EgetShift" // 0x51
	.asciz "EsetBank" // 0x52
	.asciz "EsetColor" // 0x53
	.asciz "EsetPalette" // 0x54
	.asciz "EgetPalette" // 0x55
	.asciz "EsetGray" // 0x56
	.asciz "EsetSmear" // 0x57
	.asciz "VsetMode" // 0x58
	.asciz "VgetMonitor" // 0x59
	.asciz "VsetSync" // 0x5A
	.asciz "VgetSize" // 0x5B
	.byte 0           // 0x5C
	.asciz "VsetRGB"  // 0x5D
	.asciz "VgetRGB"  // 0x5E
	.asciz "Validmode" // 0x5F
	.asciz "Dsp_DoBlock" // 0x60
	.asciz "Dsp_BlkHandShake" // 0x61
	.asciz "Dsp_BlkUnpacked" // 0x62
	.asciz "Dsp_InStream" // 0x63
	.asciz "Dsp_OutStream" // 0x64
	.asciz "Dsp_IOStream" // 0x65
	.asciz "Dsp_RemoveInterrupts" // 0x66
	.asciz "Dsp_GetWordSize" // 0x67
	.asciz "Dsp_Lock" // 0x68
	.asciz "Dsp_Unlock" // 0x69
	.asciz "Dsp_Available" // 0x6A
	.asciz "Dsp_Reserve" // 0x6B
	.asciz "Dsp_LoadProg" // 0x6C
	.asciz "Dsp_ExecProg" // 0x6D
	.asciz "Dsp_ExecBoot" // 0x6E
	.asciz "Dsp_LodToBinary" // 0x6F
	.asciz "Dsp_TriggerHC" // 0x70
	.asciz "Dsp_RequestUniqueAbility" // 0x71
	.asciz "Dsp_GetProgAbility" // 0x72
	.asciz "Dsp_FlushSubroutines" // 0x73
	.asciz "Dsp_LoadSubroutine"" // 0x74
	.asciz "Dsp_InqSubrAbility" // 0x75
	.asciz "Dsp_RunSubroutine" // 0x76
	.asciz "Dsp_Hf0"  // 0x77
	.asciz "Dsp_Hf1"  // 0x78
	.asciz "Dsp_Hf2"  // 0x79
	.asciz "Dsp_Hf3"  // 0x7A
	.asciz "Dsp_BlkWords" // 0x7B
	.asciz "Dsp_BlkBytes" //0x7C
	.asciz "Dsp_HStat" // 0x7D
	.asciz "Dsp_SetVectors" // 0x7E
	.asciz "Dsp_MultBlocks" // 0x7F
	.asciz "Locksnd"  // 0x80
	.asciz "Unlocksnd" // 0x81
	.asciz "Soundcmd" // 0x82
	.asciz "Setbuffer" // 0x83
	.asciz "Setmode"  // 0x84
	.asciz "Settracks" // 0x85
	.asciz "Setmontracks" // 0x86
	.asciz "Setinterrupt" // 0x87
	.asciz "Buffoper" // 0x88
	.asciz "Dsptristate" // 0x89
	.asciz "Gpio"     // 0x8A
	.asciz "Devconnect" // 0x8B
	.asciz "Sndstatus" // 0x8C
	.asciz "Buffptr"  // 0x8D
	.byte 0           // 0x8E
	.byte 0           // 0x8F
	.byte 0           // 0x90
	.byte 0           // 0x91
	.byte 0           // 0x92
	.byte 0           // 0x93
	.byte 0           // 0x94
	.byte 0           // 0x95
	.asciz "VsetMask" // 0x96
#endif
#endif /* DEBUG */
             .byte -1

	.align 2
	
	.chip 68060

#include "../nonfree/cf68klib060.S"
