|#####################################################################
|#                                                                   #
|#           ColdFire 68060 Emulation Library - Version 1.3.4        #
|#                                                                   #
|#                 Copyright (c) MicroAPL Ltd 1998-2001              #
|#                    All Rights Reserved Worldwide                  #
|#                                                                   #
|#####################################################################
| Target assembler: Gnu
| ColdFire core:    Version 4
| Generated library with support for operating system code

|#########################################################################
|# Definition of RegList structure                                       #
|#########################################################################
	.set	reg_d0,              0
	.set	reg_d1,              4
	.set	reg_d2,              8
	.set	reg_d3,              12
	.set	reg_d4,              16
	.set	reg_d5,              20
	.set	reg_d6,              24
	.set	reg_d7,              28
	.set	reg_a0,              32
	.set	reg_a1,              36
	.set	reg_a2,              40
	.set	reg_a3,              44
	.set	reg_a4,              48
	.set	reg_a5,              52
	.set	reg_a6,              56
	.set	reg_a7,              60
	.set	reg_pc,              64
	.set	reg_sr,              68
	.set	reg_ccr,             reg_sr+1
	.set	reg_XNZVC,           reg_ccr       | These two are synonymous
	.set	reg_usp,             72
	.set	reg_ssp,             76
	.set	reg_vbr,             84
	.set	reg_sfc,             88
	.set	reg_dfc,             92
	.set	reg_cacr,            96
	.set	reg_tc,              104
	.set	reg_itt0,            108
	.set	reg_itt1,            112
	.set	reg_dtt0,            116
	.set	reg_dtt1,            120
	.set	reg_urp,             124
	.set	reg_srp,             128
	.set	reg_buscr,           132
	.set	reg_pcr,             132
	.set	new_irq_fence,       150
	.set	exception_frame0,    154
	.set	private_sp,          158
	.set	cf68klib_flags,      162
	.set	reg_a7_valid,        cf68klib_flags
	.set	reg_a7_changed,      cf68klib_flags+1
	.set	trace_flag,          cf68klib_flags+2
	.set	reserved_flags,      cf68klib_flags+3
	.set	previous_sr,         166
	.set	stop_area,           170
	.set	instruction_address, 178
	.set	return_address,      182
	.set	regList_size,        1024
	.set	SR_S_BIT,            5
	.set	SR_M_BIT,            4
	.set	illegal_offset,      16

|#########################################################################
|# Linkage for globally visible routines                                 #
|#########################################################################
	.globl	cf68k_initialize
	.globl	cf68k_execute
	.globl	cf68k_get_version
	.extern	cf68k_install_vector
	.extern	cf68k_emulation_error
	.extern	cf68k_address_error
	.extern	cf68k_illegal_instruction
	.extern	cf68k_zero_divide
	.extern	cf68k_chk_exception
	.extern	cf68k_trapv_exception
	.extern	cf68k_privilege_violation
	.extern	cf68k_line_a
	.extern	cf68k_line_f
	.extern	cf68k_bus_error
	.extern	cf68k_trace
	.extern	cf68k_format_error
	.extern	cf68k_trap0
	.extern	cf68k_trap1
	.extern	cf68k_trap2
	.extern	cf68k_trap3
	.extern	cf68k_trap4
	.extern	cf68k_trap5
	.extern	cf68k_trap6
	.extern	cf68k_trap7
	.extern	cf68k_trap8
	.extern	cf68k_trap9
	.extern	cf68k_trap10
	.extern	cf68k_trap11
	.extern	cf68k_trap12
	.extern	cf68k_trap13
	.extern	cf68k_trap14
	.extern	cf68k_trap15
	.extern	cf68k_moves
	.extern	cf68k_bkpt
	.extern	cf68k_cas
	.extern	cf68k_cas2
	.extern	cf68k_callm
	.extern	cf68k_rtm
	.extern	cf68k_read_control_register
	.extern	cf68k_write_control_register

|###################################################
|# static_data_area                                #
|###################################################
//	.data
//	.align	2
//static_data_area:
//library_data_ptr:
//	.space	4	| Pointer to data area allocated for us by client
//library_data_temp:
//	.space	4	| Temp store

|###################################################
|# cf68k_initialize                                #
|###################################################
	.text
	.align	2
cf68k_initialize:
	| Called by client code to initialize emulation library
	| Entry:
	|       ColdFire Processor must be in Supervisor Mode
	|       A0 -> data area of at least 500 bytes for library's exclusive future use
	|       A7 -> valid stack for use during routine
	|
	lea      (-20,%a7),%a7
	movem.l  %d0-%d1/%a0-%a1/%a6,(%a7)
	move.w   %sr,%d0
	move.l   %d0,-(%a7)
	ori.l    #0x0700,%d0              | no IRQs during vectab load
	move.w   %d0,%sr
	move.l   %a0,%a6                   | get %A6 -> data area
	move.l   %a6,library_data_ptr     | store ptr to data area
	
	| Clear the whole data area
	move.l   %a0,%a1
	move.l   #regList_size/4,%d0
init:
	clr.l    (%a1)+
	subq.l   #1,%d0
	bne.s    init
	
	add.l    #regList_size,%a0			| Initialise pointer to private stack
	move.l   %a0,(private_sp,%a6)
	| Set up the first few vectors using a table
	lea      -8(%a7),%a7
	lea      handlers_table,%a1
	moveq.l  #0,%d0
	
cf68k_init_vec_loop:
	move.l   (%a1,%d0.l*4),%d1
	beq.s    cf68k_init_vec_skip     | null means don't hook this vector
	cmp.l    #-1,%d1
	beq.s    cf68k_init_vec_done     | -1 means end of table
	move.l   %d1,%a0
	movem.l  %d0/%a1,(%a7)
	jsr      cf68k_install_vector    | call client setup code with handler/vector
	movem.l  (%a7),%d0/%a1
cf68k_init_vec_skip:
	addq.l   #1,%d0                   | next vector
	bra.s    cf68k_init_vec_loop
	
cf68k_init_vec_done:
	
	| Now do the grouped vectors lower down the vector table
	
	| 16 - 23:  Unassigned, reserved (don't hook these)
	| 24 - 31:  Spurious interrupt and autovector levels 1-7
	| 32 - 47:  TRAP #0-15
	| 48 - 55:  FPU
	| 56 - 63:  Unassigned, reserved (don't hook these)
	| 64 - 255: User-defined interrupts
	
	moveq.l  #24,%d0
install_vector_loop:
	lea      interrupt_handler,%a0
	cmp.l    #64,%d0
	bge.s    install_next_vector
	cmp.l    #32,%d0
	blt.s    install_next_vector
	
	lea      pass_thru_exception_handler,%a0
	cmp.l    #56,%d0
	bge.s    skip_vector
	
install_next_vector:
	move.l   %d0,(%a7)
	jsr      cf68k_install_vector    | call client setup code with handler/vector
	move.l   (%a7),%d0
skip_vector:
	addq.l   #1,%d0
	cmp.l    #255,%d0
	ble      install_vector_loop
	
	lea      8(%a7),%a7
	move.l   (%a7)+,%d0
	move.w   %d0,%sr                   | restore caller's IRQ level
	movem.l  (%a7),%d0-%d1/%a0-%a1/%a6
	lea      (20,%a7),%a7
	rts      
	
handlers_table:
	.long 	0                                       | vector 0, reset SSP
	.long 	0                                       | vector 1, reset PC
	.long 	pass_thru_exception_handler             | vector 2, bus error
	.long 	address_error_exception_handler         | vector 3, address error
	.long 	illegal_instruction_exception_handler   | vector 4, illegal
	.long 	pass_thru_exception_handler             | vector 5, zero divide
	.long 	0                                       | vector 6, reserved
	.long 	0                                       | vector 7, reserved
	.long 	privilege_violation_exception_handler   | vector 8, privilege violation
	.long 	pass_thru_exception_handler             | vector 9, trace
	.long 	illegal_instruction_exception_handler   | vector 10, A-line
	.long 	illegal_instruction_exception_handler   | vector 11, F-line
	.long 	0                                       | vector 12, debug interrupt
	.long 	0                                       | vector 13, debug interrupt
	.long 	pass_thru_exception_handler             | vector 14, format error
	.long 	interrupt_handler                       | vector 15, uninitialized irq
        	.long 	-1                                      | end of table

|###################################################
|# cf68k_execute                                   #
|###################################################
	.align	2
cf68k_execute:
	| Called by client code to begin executing an Operating System under emulation
	| Entry:
	|       ColdFire Processor must be in Supervisor Mode
	|       A0 -> library data area as passed to cf68k_initialize
	| *** DOES NOT RETURN ***
	|
	move     #0x2700,%sr
	move.l   %a0,%a6
	
	add.l    #regList_size,%a0                | Initialise pointer to private stack
	move.l   %a0,(private_sp,%a6)
	move.l   %a0,%a7                           | Switch to private stack
	
	clr.b    (trace_flag,%a6)                 | Initialise emulation library flags
	bset     #0,(reg_a7_valid,%a6)
	bset     #0,(reg_a7_changed,%a6)
	
	bsr      get_reg_a7_from_active_sp       | Figure out which stack we should be using
	
	bra      return_with_a7_changed          | Go start executing the user's code
	

|###################################################
|# cf68k_get_version                               #
|###################################################
	.align	2
cf68k_get_version:
	| Returns version information for library
	| Exit
	|       D0.L    Major version number
	|       D1.L    Minor version number
	|       D2.L    Revision number
	|       D3.L    Processor id:
	|                   1  -  68000
	|                   2  -  68010
	|                   3  -  CPU32
	|                   4  -  CPU32+
	|                   5  -  68020
	|                   6  -  68030
	|                   7  -  68040
	|                   8  -  68060
	
	move.l   #1,%d0
	move.l   #3,%d1
	move.l   #4,%d2
	move.l   #8,%d4
	rts      

|###################################################
|# illegal_instruction_exception_handler           #
|###################################################
	.align	2
illegal_instruction_exception_handler:
	| Called whenever client program hits an illegal ColdFire instruction. Attempts
	| to emulate the instruction. If it is an invalid 68K instruction, control will
	| be passed to 'illegal'.
	|	

	move.w   #0x2700,%sr
	bsr      save_regs_and_do_setup       | Set up our world
	
illegal_instruction_common:
	tst.w    (reg_sr,%a6)             | Trace bit set at start of instruction ?
	bpl.s    no_trace
	bset     #0,(trace_flag,%a6)      | Remember for later
no_trace:
	tst.b    debug_cf68klib
	beq.s    dispatch_instruction
	bsr      debug_disassemble_pc
	| Now dispatch the instruction
dispatch_instruction:
	move.l   (reg_pc,%a6),%d0
	move.l   %d0,save_pc_cf68klib
	.short	0x7bd0                   // mvz.w    (%a0),%d5                     | Get 16-bit opcode
	move.l   %d5,%d0
	lsr.l    #6,%d0                       | Dispatch using top ten bits...
	lea      dispatch_table,%a1
	move.l   (%a1,%d0.l*4),%a1
	jmp      (%a1)
	
	| After instruction has been handled, control will return here with:
	|       A0 -> next instruction
	|       D6 = mask of CCR bits to update
	|       D7 = new state of CCR bits
	
exception_handled:
	move.l   %a0,reg_pc(%a6)
	and.l    %d6,%d7
	not.l    %d6
	move.b   reg_XNZVC(%a6),%d0
	and.l    %d6,%d0
	or.l     %d7,%d0
	move.b   %d0,reg_XNZVC(%a6)
	
	tst.l    (cf68klib_flags,%a6)         | Can we just use an RTE to return ? Can do so if
	bne.s    return_with_a7_changed      | reg_a7 still points to ColdFire exception frame
	| and provided that T bit was not set
#if 1
	move.l   (reg_a7,%a6),%a1
	move.l   %a1,%usp
#else
	move.l   (reg_a7,%a6),%a7
#endif
	
return_with_a7_ok:
	move.w   (reg_sr,%a6),%d0
	and.l    #0x871f,%d0                  | Keep only T and IRQ bits plus %CCR bits
	move.w   %d0,(2,%a7)                   | Plug modified %SR
	move.l   %a0,(4,%a7)                   | Plug updated %PC
	movem.l  (reg_d0,%a6),%d0-%d7/%a0-%a6
	rte      
	
	| Need to do things the slow way, because A7 no longer points to old exception frame
	| Or maybe because we now need to execute a trace exception
return_with_a7_changed:
	bclr     #0,(trace_flag,%a6)
	bne.s    trace_instruction
#if 1
	move.l   (reg_a7,%a6),%a0
	move.l   %a0,%usp
	move.l   (private_sp,%a6),%d1             | Switch to our private stack
#else
	move.l   (reg_a7,%a6),%d1              | Get new user %A7 value
#endif
	move.l   %d1,%d0
	and.l    #0xfffffffc,%d1              | Make sure it's aligned
	move.l   %d1,%a7
	subq.l   #8,%a7                       | Leave room for four-word exception frame
	sub.l    %d1,%d0                       | Calculate alignment/format word
	addq.l   #4,%d0
	lsl.l    #8,%d0
	lsl.l    #4,%d0
	move.w   %d0,(%a7)

	move.l   (reg_pc,%a6),%a0
	bra.s    return_with_a7_ok
	
	
trace_instruction:
	moveq.l  #0x24,%d1                | Trace vector offset
	bra      take_680x0_exception_via_front_end
	

|###################################################
|# address_error_exception_handler                 #
|###################################################
	.align	2
address_error_exception_handler:
	| Called for one of two reasons:
	|    (a) A 68K code using a scale factor of 8 or a word-sized index reg
	|       is executed,
	| or (b) It's a real address error - the instruction fetch occurred
	|        from an odd address.
	|
	move.w   #0x2700,%sr
	bsr      save_regs_and_do_setup              | Set up our world
	
	move.l   %a0,%d0                               | Is this a real address error (%PC odd)?
	andi.l   #1,%d0
	bne      real_68K_address_error              | Yes

	| The CF5307 chip has a 'feature' which we need to cope with. For the two instructions..
	|
	|       MOVE.B/W/L  (An)+,<ea>
	|       MOVE.B/W/L  -(An),<ea>
	|
	| ...the postincrement or predecrement of An has already happened by the time the exception
	| occurs. We need to undo it here. In the case of "MOVE.B/W/L (A7)+,<ea>" we're too late
	| because the exception stack frame overwrote the operand!
	| Note that if any instruction other than MOVE uses predecrement/postincrement source addressing,
	| the other operand is not in memory and hence it can't have generated an address error exception.
	|
	move.w   (%a0),%d0                     | Get instruction
	and.l    #0x38,%d0
	cmpi.l   #0x20,%d0                    | Is <ea> predecrement?
	beq.s    fix_predecrement            | Yes
	cmpi.l   #0x18,%d0                    | Is <ea> postincrement?
	bne      illegal_instruction_common  | No,just normal

#if 1
fix_predecrement:

//	move.l d0,-(sp)
//	move.l reg_pc(a6),D0
//	bsr debug_display_disassemble_pc     /****************************************************/
//	move.l (sp)+,d0

#else
fix_postincrement:
	move.w   (%a0),%d0
	move.w   %d0,%d1

	lea      width_conv_tab,%a1           | Get %D1 = 1,2 or 4 for byte
	lsr.l    #8,%d1
	lsr.l    #4,%d1
	andi.l   #3,%d1
	move.b   (%a1,%d1.l),%d1
	
	and.l    #7,%d0                       | Get Dn = An number,0..7
	cmpi.l   #7,%d0                       | If it's %A7 we're in deep trouble
	beq      stack_fatally_stomped
	
	sub.l    %d1,(reg_a0,%a6,%d0.l*4)   | Undo the postincrement
	bra      illegal_instruction_common
	
fix_predecrement:
	move.w   (%a0),%d0
	move.w   %d0,%d1
	
	lea      width_conv_tab,%a1           | Get %D1 = 1,2 or 4 for byte
	lsr.l    #8,%d1
	lsr.l    #4,%d1
	andi.l   #3,%d1
	move.b   (%a1,%d1.l),%d1
	
	and.l    #7,%d0                       | Get Dn = An number,0..7
	cmpi.l   #7,%d0                       | If it's %A7 we'll need to compute user's value
	bne.s    fix_An
	bsr      compute_reg_a7
fix_An:
	add.l    %d1,(reg_a0,%a6,%d0.l*4)       | Undo the predecrement
#endif
	bra      illegal_instruction_common
	
	
real_68K_address_error:
	move.l   #12,%d1                      | Vector offset for 'Address Error'
	bra      take_680x0_exception_via_front_end
	
width_conv_tab:
	.byte	0,1,4,2
	

|###################################################
|# privilege_violation_exception_handler           #
|###################################################
	.align	2
privilege_violation_exception_handler:
	| Called when the client code tries to execute a privileged instruction
	| such as RTE, MOVE TO SR, etc.
	|
	| We just pass these off to the normal instruction dispatcher and let the
	| individual handlers take care of what happens next
	|
	| The only reason we need to hook this separately is so we can check if the
	| privilege violation was generated within our own code - by the logic
	| which handles the STOP instruction.
	|
	move.w   #0x2700,%sr
	bsr      save_regs_and_do_setup              | Set up our world

	tst.b    debug_cf68klib
	beq.s    privilege_violation_debug
	bsr      debug_disassemble_pc
privilege_violation_debug:
	move.l   (reg_pc,%a6),%d0
	move.l   %d0,save_pc_cf68klib	
	lea      handle_stop_nasty,%a1                | Privilege violation generated by
	cmpa.l   %a0,%a1                               |  our own STOP code ?
	bne      illegal_instruction_common          | No
	bra      handle_stop_got_exception           | Yes
	

|###################################################
|# pass_thru_exception_handler                     #
|###################################################
	.align	2
pass_thru_exception_handler:
	| This handler is called when a ColdFire exception occurs that we're not specially
	| interested in. We do still need to call the front end - e.g. cf68k_trap4 - and
	| then munge the stack frame to 680x0 format for the 68K handler.
	
	move.w   #0x2700,%sr
	bsr      save_regs_and_do_setup              | Set up our world

pass_thru_common:
	move.w   (exception_frame0,%a6),%d1            | Get exception vector offset
	and.l    #0x03fc,%d1
	bra      take_680x0_exception_via_front_end

|###################################################
|# interrupt_handler                               #
|###################################################
	.align	2
interrupt_handler:
	move.w   #0x2700,%sr
	bsr      save_regs_and_do_setup              | Set up our world

	move.w   (exception_frame0,%a6),%d1            | Get vector offset
	and.l    #0x03fc,%d1
	
	move.l   %d1,%d0                               | If this is autovector,convert
	lsr.l    #2,%d0                               | to fence level 1 to 7
	sub.l    #24,%d0
	bcs.s    not_autovector
	cmp.l    #0x8,%d0
	bcc      not_autovector
	lsl.l    #8,%d0
	bra.s    got_interrupt_fence
	
not_autovector:
	move.l   #0x0700,%d0                          | Default fence = Level 7
got_interrupt_fence:
	move.w   %d0,(new_irq_fence,%a6)               | Store for later
	bra      take_680x0_exception_via_front_end

|###################################################
|# take_680x0_exception_via_front_end              #
|###################################################
	.align	2
take_680x0_exception_via_front_end:
	| On arrival here, D1.L is vector offset for exception to take
	|                  D2.L may have extra parameter for front end routine.
	|
	| We first call any front-end routine such as 'cf68k_trap5', and then if
	| the exception has not been handled we convert the stack frame format to 680x0 and
	| invoke the 680x0 handler
	
	move.l   #0,%a1                               | In range for table lookup ?
	cmp.l    #48*4,%d1
	bcc.s    take_680x0_exception_via_known_front_end_routine
	lea      frontend_handlers_table,%a1          | Get address of user's front-end routine
	move.l   (%a1,%d1.l),%a1
	
take_680x0_exception_via_known_front_end_routine:
	bsr      compute_reg_a7                      | Calculate user's %A7 value
	bsr      set_active_sp_from_reg_a7           | Work out if this is USP,SSP,etc
	| and update appropriate field
	
	cmpa.l   #0,%a1                                | Any front-end routine to call ?
	beq      take_680x0_exception_post_front_end_offset  | None
	
	lea      -8(%a7),%a7
	movem.l  %d1/%a6,(%a7)
	move.l   (instruction_address,%a6),%a0         | Get %D0 = opcode
	.short	0x71d0                            // mvz.w    (%a0),%d0
	move.l   %a6,%a0                               | Get %A0 -> regList structure
	jsr      (%a1)                                | Go call user front end routine,CF68k_xxx
	movem.l  (%a7),%d1/%a6
	lea      8(%a7),%a7
	
	tst.l    %d0                                   | Did the user handle the exception
	beq      take_680x0_exception_post_front_end_offset  | No
	
user_handled_exception:
	bsr      get_reg_a7_from_active_sp           | Correct the current %A7 value in case it
	bra      return_with_a7_changed              | changed
	
	
frontend_handlers_table:
	.long 	0                               | 0 - reset SSP
	.long 	0                               | 1 - reset PC
	.long 	cf68k_bus_error                 | 2 - bus error
	.long 	cf68k_address_error             | 3 - address error
	.long 	cf68k_illegal_instruction       | 4 - illegal instruction
	.long 	cf68k_zero_divide               | 5 - Zero Divide
	.long 	cf68k_chk_exception             | 6 - CHK instruction
	.long 	cf68k_trapv_exception           | 7 - TRAPV instruction
	.long 	cf68k_privilege_violation       | 8 - privilege violation
	.long 	cf68k_trace                     | 9 - Trace
	.long 	cf68k_line_a                    | 10 - Line 1010 emulator
	.long 	cf68k_line_f                    | 11 - Line 1111 emulator
	.long 	0                               | 12 - Unassigned, reserved
	.long 	0                               | 13 - Unassigned, reserved
	.long 	cf68k_format_error              | 14 - Format error
	.long 	0                               | 15 - Uninitialized interrupt
	.long 	0                               | 16 - Unassigned, reserved
	.long 	0                               | 17 - Unassigned, reserved
	.long 	0                               | 18 - Unassigned, reserved
	.long 	0                               | 19 - Unassigned, reserved
	.long 	0                               | 20 - Unassigned, reserved
	.long 	0                               | 21 - Unassigned, reserved
	.long 	0                               | 22 - Unassigned, reserved
	.long 	0                               | 23 - Unassigned, reserved
	.long 	0                               | 24 - Spurious interrupt
	.long 	0                               | 25 - Level 1 interrupt autovector
	.long 	0                               | 26 - Level 2 interrupt autovector
	.long 	0                               | 27 - Level 3 interrupt autovector
	.long 	0                               | 28 - Level 4 interrupt autovector
	.long 	0                               | 29 - Level 5 interrupt autovector
	.long 	0                               | 30 - Level 6 interrupt autovector
	.long 	0                               | 31 - Level 7 interrupt autovector
	.long 	cf68k_trap0                     | 32 - TRAP #0 instruction
	.long 	cf68k_trap1                     | 33 - TRAP #1 instruction
	.long 	cf68k_trap2                     | 34 - TRAP #2 instruction
	.long 	cf68k_trap3                     | 35 - TRAP #3 instruction
	.long 	cf68k_trap4                     | 36 - TRAP #4 instruction
	.long 	cf68k_trap5                     | 37 - TRAP #5 instruction
	.long 	cf68k_trap6                     | 38 - TRAP #6 instruction
	.long 	cf68k_trap7                     | 39 - TRAP #7 instruction
	.long 	cf68k_trap8                     | 40 - TRAP #8 instruction
	.long 	cf68k_trap9                     | 41 - TRAP #9 instruction
	.long 	cf68k_trap10                    | 42 - TRAP #10 instruction
	.long 	cf68k_trap11                    | 43 - TRAP #11 instruction
	.long 	cf68k_trap12                    | 44 - TRAP #12 instruction
	.long 	cf68k_trap13                    | 45 - TRAP #13 instruction
	.long 	cf68k_trap14                    | 46 - TRAP #14 instruction
	.long 	cf68k_trap15                    | 47 - TRAP #15 instruction

|###################################################
|# take_680x0_exception_post_front_end             #
|###################################################
	.align	2
take_680x0_exception_post_front_end_offset:
	cmp.l    #64*4,%d1
	bcs.s    take_680x0_exception_post_front_end
	add.l    #OFFSET_INT_CF68KLIB*4,%d1
	tst.b    debug_int7
	beq.s    take_680x0_exception_post_front_end
	cmp.l    #(64+OFFSET_INT_CF68KLIB+7)*4,%d1
	bne.s    take_680x0_exception_post_front_end
	move.l   %a6,%a0
	bsr      debug_display_fault
take_680x0_exception_post_front_end:
	| This routine is called after we've asked the front end whether it wished to handle an
	| exception and it has declined - i.e. we should now take a 'real' 680x0 exception handler.
	| The routine builds a 680x0 exception frame of the correct type, then passes control to
	| the 680x0 handler.
	|
	| On entry:
	|       D1.L = vector offset of exception to take
	|       reg_xxx all valid
	
	move.w   (reg_sr,%a6),%d0                      | Save copy of current %SR,then update it
	move.w   %d0,(previous_sr,%a6)
	ori.l    #0x2000,%d0                          | Assert S bit
	andi.l   #0x3fff,%d0                          | Clear T (and T1 on 68020)
	move.w   (new_irq_fence,%a6),%d2               | Raise IRQ fence if we're now
	or.l     %d2,%d0                               |  servicing an interrupt
	move.w   %d0,(reg_sr,%a6)
	
	bsr      get_reg_a7_from_active_sp           | Get pointer to active stack
	move.l   (reg_a7,%a6),%a5
	
	bsr      build_68k_frame                     | Build a 68K exception frame of correct type
	move.l   %a5,(reg_a7,%a6)                      | Update %A7 to allow for frame
	bset     #0,(reg_a7_changed,%a6)
	
	
	move.l   (reg_vbr,%a6),%a0                     | Get address of 680x0 exception handler
	move.l   (%a0,%d1.l),%a0
	move.l   %a0,(reg_pc,%a6)
	bra      return_with_a7_changed              | Now join common exit routine

|###################################################
|# save_regs_and_do_setup                          #
|###################################################
	.align	2
save_regs_and_do_setup:
	| Called on entry to exception handler to do the following:
	|       Save d0-d7/a0-a7 and CCR
	|       Save first long word of exception frame
	|       Get return address from exception frame and save in 'reg_pc' and in A0
	|       Switch to our private stack
	|       Initialise various flags

	move.l   %a6,library_data_temp
	move.l   8(%a7),%a6                       | Get %PC
	cmp.l    #SDRAM_SIZE,%a6
	bcc.s    access_fault_inside_cf68klib     | bad PC
	cmp.l    #cf68k_initialize,a6
	bcs.s    pc_outside_cf68klib
	cmp.l    #dispatch_table,a6
	bcc.s    pc_outside_cf68klib
	move.l   %d0,%a6                          | save D0
	move.w   4(%a7),%d0                       | Get vector offset
	and.l    #0x03fc,%d0
	cmp.l    #2*4,%d0                         | Access fault
	bne.s    not_an_access_fault
	move.l   %a6,%d0                          | restore D0
	bra.s    access_fault_inside_cf68klib
not_an_access_fault:
	move.l   %a6,%d0                          | restore D0	
pc_outside_cf68klib:
             move.l   current_tcb,%a6
             cmp.l    tid_tos,%a6
             beq      save_regs_cf68klib
access_fault_inside_cf68klib:
             lea      save_regs,%a6
	movem.l  %d0-%d7/%a0-%a5,(reg_d0,%a6)     | Spill all registers
	tst.b    debug_int7
	beq.s    not_int7_not_cf68klib
	move.w   4(%a7),%d0                       | Get vector offset
	and.l    #0x03fc,%d0
	cmp.l    #(64+7)*4,%d0
	bne.s    not_int7_not_cf68klib
#ifdef MCF5445X
	move.l   #INTC_IMRL_INT_MASK7,%d0
	or.l     %d0,MCF_INTC_IMRL0               | mask interrupt
#else /* MCF548X */
	move.l   #MCF_INTC_IMRL_INT_MASK7,%d0
	or.l     %d0,MCF_INTC_IMRL                | mask interrupt
#endif
not_int7_not_cf68klib:
	move.l   library_data_temp,%d0
	move.l   %d0,(reg_a6,%a6)
	addq.l   #4,%a7
	move.l   %usp,%a0
	move.l   %a0,(reg_usp,%a6)
	move.l   %a7,(reg_ssp,%a6)
	move.l   %a7,(reg_a7,%a6)
	move.l   0(%a7),exception_frame0(%a6)     | Save first long of exception frame
	move.w   2(%a7),reg_sr(%a6)
	move.l   4(%a7),%a0                       | Get %PC
	move.l   %a0,reg_pc(%a6)
             move.l   %a6,%a0
	bsr      debug_display_fault
not_cf68klib:
	bra.s    not_cf68klib

save_regs_cf68klib:
	move.l   library_data_ptr,%a6             | Get %A6 -> our private data
	movem.l  %d0-%d7/%a0-%a5,(reg_d0,%a6)     | Spill all registers
	tst.b    debug_int7
	beq.s    not_int7_cf68klib
	move.w   4(%a7),%d0                       | Get vector offset
	and.l    #0x03fc,%d0
	cmp.l    #(64+7)*4,%d0
	bne.s    not_int7_cf68klib
#ifdef MCF5445X
	move.l   #INTC_IMRL_INT_MASK7,%d0
	or.l     %d0,MCF_INTC_IMRL0               | mask interrupt
#else /* MCF548X */
	move.l   #MCF_INTC_IMRL_INT_MASK7,%d0
	or.l     %d0,MCF_INTC_IMRL                | mask interrupt
#endif
not_int7_cf68klib:
	move.l   library_data_temp,%d0
	move.l   %d0,(reg_a6,%a6)
	move.l   (%a7)+,%a1                       |% A1 = return address
#if 1
	move.l   %usp,%a0
	move.l   %a0,(reg_a7,%a6)
#else
	move.l   %a7,(reg_a7,%a6)
#endif
	move.l   0(%a7),exception_frame0(%a6)     | Save first long of exception frame
	move.b   3(%a7),reg_XNZVC(%a6)            | Save XNZVC
	move.l   4(%a7),%a0                       | Get %PC
	move.l   %a0,reg_pc(%a6)
	move.l   %a0,(instruction_address,%a6)    | Remember instruction address
	clr.l    cf68klib_flags(%a6)              | Clear emulation library flags:
	|   trace_flag (byte)
	|   reg_a7_valid (byte)
	|   reg_a7_changed (byte)
	clr.w    new_irq_fence(%a6)
#if 1

#else
	move.l   (private_sp,%a6),%a7             | Switch to our private stack
#endif
	move.w   #0x20,%ccr                       | Branch prediction = forward
	jmp      (%a1)                            | Return to caller

|###################################################
|# compute_reg_a7                                  #
|###################################################
	.align	2
compute_reg_a7:
	| When a ColdFire exception first occurs, A7 points to the exception stack frame. The
	| value of A7 before the exception can be computed from this, but the computation
	| takes several instructions. We seek to avoid doing it if not needed.
	|
	| Initially, the field 'reg_a7' contains a pointer to the exception frame.
	| After 'compute_reg_a7' has been called, it contains the real client A7
	|
	| The meaning of 'reg_a7' is controlled by two flags:
	|
	|   reg_a7_valid         - 0 if reg_a7 points to exception frame
	|                        - <> 0 once it has been corrected to be client's A7
	|
	|   reg_a7_changed       - 0 if client's A7 has not been changed by instruction
	|                          <> 0 if instruction has changed A7
	|
	tst.b    (reg_a7_valid,%a6)
	bne.s    compute_reg_a7_done
#if 1
	move.l   %a0,-(%a7)
	move.l   %usp,%a0
	move.l   %a0,(reg_a7,%a6)
	bset     #0,(reg_a7_valid,%a6)        | Computed now
	move.l   (%a7)+,%a0
#else
	move.l   %d0,-(%a7)
	move.b   (exception_frame0,%a6),%d0   | Get %SP alignment bits from %A7 stack frame
	lsr.l    #4,%d0
	andi.l   #3,%d0
	addq.l   #8,%d0                       | Include size of exception frame itself
	add.l    %d0,(reg_a7,%a6)
	bset     #0,(reg_a7_valid,%a6)        | Computed now
	move.l   (%a7)+,%d0
#endif
compute_reg_a7_done:
	rts      

|###################################################
|# set_active_sp_from_reg_a7                       #
|###################################################
	.align	2
set_active_sp_from_reg_a7:
	| Copies 'reg_a7' into stack pointer which is currently in use
	|
	|   For 68000/68010/68060
	|       If S = 0 update USP else update SSP
	btst     #SR_S_BIT,(reg_sr,%a6)
	beq.s    set_USP
	
	move.l   (reg_a7,%a6),(reg_ssp,%a6)
	rts      
set_USP:
	move.l   (reg_a7,%a6),(reg_usp,%a6)
	rts      

|###################################################
|# get_reg_a7_from_active_sp                       #
|###################################################
	.align	2
get_reg_a7_from_active_sp:
	| Works out which stack pointer is currently in use:
	|
	|   For 68000/68010/68060
	|       If S = 0 use USP else use SSP
	bset     #0,(reg_a7_changed,%a6)
	btst     #SR_S_BIT,(reg_sr,%a6)
	beq.s    use_USP
	
	move.l   (reg_ssp,%a6),(reg_a7,%a6)
	rts      
use_USP:
	move.l   (reg_usp,%a6),(reg_a7,%a6)
	rts      

|###################################################
|# S_bit_changed                                   #
|###################################################
	.align	2
S_bit_changed:
	| Callback from main emulation library whenever S-bit (or M-bit) in the
	| virtual SR changes. We will have to switch stack and ensure all our
	| saved data is up-to-date.
	| Called with D7 = old value of reg_sr
	
	move.l   %d0,-(%a7)
	bsr      compute_reg_a7              | Calculate real %A7 value
	move.w   (reg_sr,%a6),%d0
	move.w   %d7,(reg_sr,%a6)              | Write it into correct stack pointer - USP,ISP
	bsr      set_active_sp_from_reg_a7
	move.w   %d0,(reg_sr,%a6)              | Update the %SR
	bsr      get_reg_a7_from_active_sp   | Get the corresponding stack pointer
	move.l   (%a7)+,%d0
	rts      

|###################################################
|# build_68k_frame                                 #
|###################################################
	.align	2
build_68k_frame:
	| This routine builds a 680x0 exception frame of the appropriate type
	|
	| Entry:-
	|           reg_pc          PC to stack
	|           previous_sr     SR to stack
	|           D1.W            vector offset
	|           A5              target SP
	|
	| Exit:-
	|           A5              updated target SP
	|
	lea      -8(%a7),%a7
	movem.l  %d0/%a0,(%a7)
	
	move.l   %d1,%d0                       | Get format code into %D0
	lsr.l    #2,%d0
	lea      exception_format_codes(%pc),%a0
	move.b   (%a0,%d0.l),%d0
	
	cmp.l    #0x2,%d0
	beq.s    build_frame_format_2
	cmp.l    #0xa,%d0                     | Bus or address error ?
	bne.s    build_simple_frame
	
	clr.l    -(%a5)                       | Internal Register
	clr.l    -(%a5)                       | Data Output Buffer
	clr.l    -(%a5)                       | Internal Register
	move.l   address_fault,-(%a5)         | Fault address 
	clr.l    -(%a5)                       | Instruction Pipe Stage B / C
	clr.l    -(%a5)                       | Special Status Word / Internal Register
	bra.s    build_simple_frame
	
build_frame_format_2:
	move.l   (instruction_address,%a6),-(%a5)  | Instruction Address
	
build_simple_frame:
	lsl.l    #8,%d0
	lsl.l    #4,%d0
	or.l     %d1,%d0
	move.w   %d0,-(%a5)                    | push [format]:[vector offset]
	move.l   (reg_pc,%a6),-(%a5)           | push %PC
	move.w   (previous_sr,%a6),-(%a5)      | push %SR
	
	movem.l  (%a7),%d0/%a0
	lea      8(%a7),%a7
	rts      
exception_format_codes:
	.byte	0x0     | 0:  Reset - Initial ISP
	.byte	0x0     | 1:  Reset - Initial PC
	.byte	0xa     | 2:  Bus Error (short BERR)
	.byte	0xa     | 3:  Address Error (short BERR)
	.byte	0x0     | 4:  Illegal Instruction
	.byte	0x2     | 5:  Zero Divide
	.byte	0x2     | 6:  CHK, CHK2
	.byte	0x2     | 7:  TRAPcc, TRAPV
	.byte	0x0     | 8:  Privilege Violation
	.byte	0x2     | 9:  Trace
	.byte	0x0     | 10: Line A Emulator
	.byte	0x0     | 11: Line F Emulator
	.byte	0x0     | 12: (Unassigned, Reserved)
	.byte	0x0     | 13:  Coprocessor Protocol Violation
	.byte	0x0     | 14:  Format Error
	.byte	0x0     | 15:  Uninitialized Interrupt
	.byte	0x0 | 16:  (Unassigned, Reserved)
	.byte	0x0 | 17:  (Unassigned, Reserved)
	.byte	0x0 | 18:  (Unassigned, Reserved)
	.byte	0x0 | 19:  (Unassigned, Reserved)
	.byte	0x0 | 20:  (Unassigned, Reserved)
	.byte	0x0 | 21:  (Unassigned, Reserved)
	.byte	0x0 | 22:  (Unassigned, Reserved)
	.byte	0x0 | 23:  (Unassigned, Reserved)
	.byte	0x0     | 24:  Spurious Interrupt
	.byte	0x0 | 25:  Level 1 Interrupt Auto Vector
	.byte	0x0 | 26:  Level 2 Interrupt Auto Vector
	.byte	0x0 | 27:  Level 3 Interrupt Auto Vector
	.byte	0x0 | 28:  Level 4 Interrupt Auto Vector
	.byte	0x0 | 29:  Level 5 Interrupt Auto Vector
	.byte	0x0 | 30:  Level 6 Interrupt Auto Vector
	.byte	0x0 | 31:  Level 7 Interrupt Auto Vector
	.byte	0x0 | 32:  Trap 0 Instruction Vector
	.byte	0x0 | 33:  Trap 1 Instruction Vector
	.byte	0x0 | 34:  Trap 2 Instruction Vector
	.byte	0x0 | 35:  Trap 3 Instruction Vector
	.byte	0x0 | 36:  Trap 4 Instruction Vector
	.byte	0x0 | 37:  Trap 5 Instruction Vector
	.byte	0x0 | 38:  Trap 6 Instruction Vector
	.byte	0x0 | 39:  Trap 7 Instruction Vector
	.byte	0x0 | 40:  Trap 8 Instruction Vector
	.byte	0x0 | 41:  Trap 9 Instruction Vector
	.byte	0x0 | 42:  Trap 10 Instruction Vector
	.byte	0x0 | 43:  Trap 11 Instruction Vector
	.byte	0x0 | 44:  Trap 12 Instruction Vector
	.byte	0x0 | 45:  Trap 13 Instruction Vector
	.byte	0x0 | 46:  Trap 14 Instruction Vector
	.byte	0x0 | 47:  Trap 15 Instruction Vector
	.byte	0x0 | 48:  (Unassigned, Reserved)
	.byte	0x0 | 49:  (Unassigned, Reserved)
	.byte	0x0 | 50:  (Unassigned, Reserved)
	.byte	0x0 | 51:  (Unassigned, Reserved)
	.byte	0x0 | 52:  (Unassigned, Reserved)
	.byte	0x0 | 53:  (Unassigned, Reserved)
	.byte	0x0 | 54:  (Unassigned, Reserved)
	.byte	0x0 | 55:  (Unassigned, Reserved)
	.byte	0x0 | 56:  (Unassigned, Reserved)
	.byte	0x0 | 57:  (Unassigned, Reserved)
	.byte	0x0 | 58:  (Unassigned, Reserved)
	.byte	0x0 | 59:  (Unassigned, Reserved)
	.byte	0x0 | 60:  (Unassigned, Reserved)
	.byte	0x0 | 61:  (Unassigned, Reserved)
	.byte	0x0 | 62:  (Unassigned, Reserved)
	.byte	0x0 | 63:  (Unassigned, Reserved)
	.byte	0x0 | 64:  User Defined Vector
	.byte	0x0 | 65:  User Defined Vector
	.byte	0x0 | 66:  User Defined Vector
	.byte	0x0 | 67:  User Defined Vector
	.byte	0x0 | 68:  User Defined Vector
	.byte	0x0 | 69:  User Defined Vector
	.byte	0x0 | 70:  User Defined Vector
	.byte	0x0 | 71:  User Defined Vector
	.byte	0x0 | 72:  User Defined Vector
	.byte	0x0 | 73:  User Defined Vector
	.byte	0x0 | 74:  User Defined Vector
	.byte	0x0 | 75:  User Defined Vector
	.byte	0x0 | 76:  User Defined Vector
	.byte	0x0 | 77:  User Defined Vector
	.byte	0x0 | 78:  User Defined Vector
	.byte	0x0 | 79:  User Defined Vector
	.byte	0x0 | 80:  User Defined Vector
	.byte	0x0 | 81:  User Defined Vector
	.byte	0x0 | 82:  User Defined Vector
	.byte	0x0 | 83:  User Defined Vector
	.byte	0x0 | 84:  User Defined Vector
	.byte	0x0 | 85:  User Defined Vector
	.byte	0x0 | 86:  User Defined Vector
	.byte	0x0 | 87:  User Defined Vector
	.byte	0x0 | 88:  User Defined Vector
	.byte	0x0 | 89:  User Defined Vector
	.byte	0x0 | 90:  User Defined Vector
	.byte	0x0 | 91:  User Defined Vector
	.byte	0x0 | 92:  User Defined Vector
	.byte	0x0 | 93:  User Defined Vector
	.byte	0x0 | 94:  User Defined Vector
	.byte	0x0 | 95:  User Defined Vector
	.byte	0x0 | 96:  User Defined Vector
	.byte	0x0 | 97:  User Defined Vector
	.byte	0x0 | 98:  User Defined Vector
	.byte	0x0 | 99:  User Defined Vector
	.byte	0x0 | 100:  User Defined Vector
	.byte	0x0 | 101:  User Defined Vector
	.byte	0x0 | 102:  User Defined Vector
	.byte	0x0 | 103:  User Defined Vector
	.byte	0x0 | 104:  User Defined Vector
	.byte	0x0 | 105:  User Defined Vector
	.byte	0x0 | 106:  User Defined Vector
	.byte	0x0 | 107:  User Defined Vector
	.byte	0x0 | 108:  User Defined Vector
	.byte	0x0 | 109:  User Defined Vector
	.byte	0x0 | 110:  User Defined Vector
	.byte	0x0 | 111:  User Defined Vector
	.byte	0x0 | 112:  User Defined Vector
	.byte	0x0 | 113:  User Defined Vector
	.byte	0x0 | 114:  User Defined Vector
	.byte	0x0 | 115:  User Defined Vector
	.byte	0x0 | 116:  User Defined Vector
	.byte	0x0 | 117:  User Defined Vector
	.byte	0x0 | 118:  User Defined Vector
	.byte	0x0 | 119:  User Defined Vector
	.byte	0x0 | 120:  User Defined Vector
	.byte	0x0 | 121:  User Defined Vector
	.byte	0x0 | 122:  User Defined Vector
	.byte	0x0 | 123:  User Defined Vector
	.byte	0x0 | 124:  User Defined Vector
	.byte	0x0 | 125:  User Defined Vector
	.byte	0x0 | 126:  User Defined Vector
	.byte	0x0 | 127:  User Defined Vector
	.byte	0x0 | 128:  User Defined Vector
	.byte	0x0 | 129:  User Defined Vector
	.byte	0x0 | 130:  User Defined Vector
	.byte	0x0 | 131:  User Defined Vector
	.byte	0x0 | 132:  User Defined Vector
	.byte	0x0 | 133:  User Defined Vector
	.byte	0x0 | 134:  User Defined Vector
	.byte	0x0 | 135:  User Defined Vector
	.byte	0x0 | 136:  User Defined Vector
	.byte	0x0 | 137:  User Defined Vector
	.byte	0x0 | 138:  User Defined Vector
	.byte	0x0 | 139:  User Defined Vector
	.byte	0x0 | 140:  User Defined Vector
	.byte	0x0 | 141:  User Defined Vector
	.byte	0x0 | 142:  User Defined Vector
	.byte	0x0 | 143:  User Defined Vector
	.byte	0x0 | 144:  User Defined Vector
	.byte	0x0 | 145:  User Defined Vector
	.byte	0x0 | 146:  User Defined Vector
	.byte	0x0 | 147:  User Defined Vector
	.byte	0x0 | 148:  User Defined Vector
	.byte	0x0 | 149:  User Defined Vector
	.byte	0x0 | 150:  User Defined Vector
	.byte	0x0 | 151:  User Defined Vector
	.byte	0x0 | 152:  User Defined Vector
	.byte	0x0 | 153:  User Defined Vector
	.byte	0x0 | 154:  User Defined Vector
	.byte	0x0 | 155:  User Defined Vector
	.byte	0x0 | 156:  User Defined Vector
	.byte	0x0 | 157:  User Defined Vector
	.byte	0x0 | 158:  User Defined Vector
	.byte	0x0 | 159:  User Defined Vector
	.byte	0x0 | 160:  User Defined Vector
	.byte	0x0 | 161:  User Defined Vector
	.byte	0x0 | 162:  User Defined Vector
	.byte	0x0 | 163:  User Defined Vector
	.byte	0x0 | 164:  User Defined Vector
	.byte	0x0 | 165:  User Defined Vector
	.byte	0x0 | 166:  User Defined Vector
	.byte	0x0 | 167:  User Defined Vector
	.byte	0x0 | 168:  User Defined Vector
	.byte	0x0 | 169:  User Defined Vector
	.byte	0x0 | 170:  User Defined Vector
	.byte	0x0 | 171:  User Defined Vector
	.byte	0x0 | 172:  User Defined Vector
	.byte	0x0 | 173:  User Defined Vector
	.byte	0x0 | 174:  User Defined Vector
	.byte	0x0 | 175:  User Defined Vector
	.byte	0x0 | 176:  User Defined Vector
	.byte	0x0 | 177:  User Defined Vector
	.byte	0x0 | 178:  User Defined Vector
	.byte	0x0 | 179:  User Defined Vector
	.byte	0x0 | 180:  User Defined Vector
	.byte	0x0 | 181:  User Defined Vector
	.byte	0x0 | 182:  User Defined Vector
	.byte	0x0 | 183:  User Defined Vector
	.byte	0x0 | 184:  User Defined Vector
	.byte	0x0 | 185:  User Defined Vector
	.byte	0x0 | 186:  User Defined Vector
	.byte	0x0 | 187:  User Defined Vector
	.byte	0x0 | 188:  User Defined Vector
	.byte	0x0 | 189:  User Defined Vector
	.byte	0x0 | 190:  User Defined Vector
	.byte	0x0 | 191:  User Defined Vector
	.byte	0x0 | 192:  User Defined Vector
	.byte	0x0 | 193:  User Defined Vector
	.byte	0x0 | 194:  User Defined Vector
	.byte	0x0 | 195:  User Defined Vector
	.byte	0x0 | 196:  User Defined Vector
	.byte	0x0 | 197:  User Defined Vector
	.byte	0x0 | 198:  User Defined Vector
	.byte	0x0 | 199:  User Defined Vector
	.byte	0x0 | 200:  User Defined Vector
	.byte	0x0 | 201:  User Defined Vector
	.byte	0x0 | 202:  User Defined Vector
	.byte	0x0 | 203:  User Defined Vector
	.byte	0x0 | 204:  User Defined Vector
	.byte	0x0 | 205:  User Defined Vector
	.byte	0x0 | 206:  User Defined Vector
	.byte	0x0 | 207:  User Defined Vector
	.byte	0x0 | 208:  User Defined Vector
	.byte	0x0 | 209:  User Defined Vector
	.byte	0x0 | 210:  User Defined Vector
	.byte	0x0 | 211:  User Defined Vector
	.byte	0x0 | 212:  User Defined Vector
	.byte	0x0 | 213:  User Defined Vector
	.byte	0x0 | 214:  User Defined Vector
	.byte	0x0 | 215:  User Defined Vector
	.byte	0x0 | 216:  User Defined Vector
	.byte	0x0 | 217:  User Defined Vector
	.byte	0x0 | 218:  User Defined Vector
	.byte	0x0 | 219:  User Defined Vector
	.byte	0x0 | 220:  User Defined Vector
	.byte	0x0 | 221:  User Defined Vector
	.byte	0x0 | 222:  User Defined Vector
	.byte	0x0 | 223:  User Defined Vector
	.byte	0x0 | 224:  User Defined Vector
	.byte	0x0 | 225:  User Defined Vector
	.byte	0x0 | 226:  User Defined Vector
	.byte	0x0 | 227:  User Defined Vector
	.byte	0x0 | 228:  User Defined Vector
	.byte	0x0 | 229:  User Defined Vector
	.byte	0x0 | 230:  User Defined Vector
	.byte	0x0 | 231:  User Defined Vector
	.byte	0x0 | 232:  User Defined Vector
	.byte	0x0 | 233:  User Defined Vector
	.byte	0x0 | 234:  User Defined Vector
	.byte	0x0 | 235:  User Defined Vector
	.byte	0x0 | 236:  User Defined Vector
	.byte	0x0 | 237:  User Defined Vector
	.byte	0x0 | 238:  User Defined Vector
	.byte	0x0 | 239:  User Defined Vector
	.byte	0x0 | 240:  User Defined Vector
	.byte	0x0 | 241:  User Defined Vector
	.byte	0x0 | 242:  User Defined Vector
	.byte	0x0 | 243:  User Defined Vector
	.byte	0x0 | 244:  User Defined Vector
	.byte	0x0 | 245:  User Defined Vector
	.byte	0x0 | 246:  User Defined Vector
	.byte	0x0 | 247:  User Defined Vector
	.byte	0x0 | 248:  User Defined Vector
	.byte	0x0 | 249:  User Defined Vector
	.byte	0x0 | 250:  User Defined Vector
	.byte	0x0 | 251:  User Defined Vector
	.byte	0x0 | 252:  User Defined Vector
	.byte	0x0 | 253:  User Defined Vector
	.byte	0x0 | 254:  User Defined Vector
	.byte	0x0 | 255:  User Defined Vector

|###################################################
|# handle_rte                                      #
|###################################################
	.align	2
handle_rte:
	| The main body of the emulation library branches back to here to handle the RTE instruction
	
	bsr      compute_reg_a7                  | Get pointer to 680x0 RTE exception frame
	move.l   (reg_a7,%a6),%a5

	move.w   (%a5),%d0                         |% D0 = new %SR value
	move.l   2(%a5),%a0                        |% A0 = new %PC value
	
	move.w   6(%a5),%d1                        | Get %D1 = format byte...
	lsr.l    #8,%d1
	lsr.l    #4,%d1
	and.l    #0xf,%d1
	cmp.l    #1,%d1                           | Throwaway stack frame ?
	beq.s    handle_throwaway_frame          | Yes,so do the whole thing again!
	
	lea      exception_frame_sizes,%a1        | Get number of extra words
	move.b   (%a1,%d1.l),%d1
	bmi.s    format_error
	
	adda.l   %d1,%a5
	move.l   %a5,(reg_a7,%a6)
	bsr      set_active_sp_from_reg_a7       | Update MSP or ISP
	move.l   %a0,(reg_pc,%a6)                  | Update %PC
	move.w   %d0,(reg_sr,%a6)                  | Now update %SR and switch to correct stack
	bsr      get_reg_a7_from_active_sp
	bra      return_with_a7_changed
	
handle_throwaway_frame:
	addq.l   #8,%a5
	move.l   %a5,(reg_a7,%a6)
	bsr      set_active_sp_from_reg_a7       | Update MSP or ISP
	move.w   %d0,(reg_sr,%a6)                  | Now update %SR and switch to correct stack
	bsr      get_reg_a7_from_active_sp
	bra      handle_rte                      | Go repeat with real stack frame
format_error:
	move.l   #14*4,%d1
	bra      take_680x0_exception_via_front_end
	
exception_frame_sizes:
	.byte	4*2,4*2,6*2,-1,-1,-1,-1,-1
	.byte	-1,10*2,16*2,44*2,-1,-1,-1,-1

|###################################################
|# handle_stop                                     #
|###################################################
	.align	2
handle_stop:
#if 1
	addq.l   #4,%a0                       | jump STOP instruction
	moveq.l  #0x0,%d6
	jmp      exception_handled
#else        // TO FIX problem with 680x0 interrupt (stack ???)
	| The STOP instruction is particularly difficult to handle. We need to drop the
	| interrupt fence, so must assume that our private data is invalid once we've executed STOP.
	| In addition, there's no STOP D0 instruction - in order to stop the processor we
	| have execute a real STOP #N instruction. Since we need to regain control immediately
	| afterwards, we have to build code on the fly.
	move.l   (%a0)+,(stop_area,%a6)        | copy user's STOP #n instruction to scratchpad
	move.l   %a0,(return_address,%a6)
	move.w   #0x4e75,%d0                  | append an RTS
	move.w   %d0,(stop_area+4,%a6)

	bsr      cpushl_dc
	bsr      cpushl_ic
	
	bsr      compute_reg_a7
#if 1

#else
	move.l   (reg_a7,%a6),%a7              |% A7 -> stack before STOP
#endif
	pea      handle_stop_handled(%pc)      | Push address to come back to after executing STOP
	pea      (stop_area,%a6)               | Push address of newly fabricated "STOP #N| RTS" sequence
	movem.l  (reg_d0,%a6),%d0-%d7/%a0-%a6     | Restore all regs
	rts      | Execute scratchpad code... return below
	
	| We just executed the STOP instruction. It's possible that we're now in supervisor mode
	| (if a native interrupt awoke us), or in user mode (if a 680x0 interrupt awoke us)
	| Need to get back to real user mode!
handle_stop_handled:
	subq.l   #4,%a7
	move.l   %d0,-(%a7)
	move.l   %a6,-(%a7)
	move.l   library_data_ptr,%a6             | Get %A6 -> our private data
	move.l   (return_address,%a6),%d0
	move.l   (%a7)+,%a6
	move.l   %d0,4(%a7)
#endif
handle_stop_nasty:
	move     %sr,%d0                       | This instruction may cause a privilege violation trap! If so
	| we'll come back to handle_stop_got_exception
handle_stop_done:
	and.l    #0x871f,%d0                  | Keep only T and IRQ bits plus %CCR bits
	move     %d0,%sr                       | Back into user mode please!
	move.l   (%a7)+,%d0
	rts                                    | return address
	
handle_stop_got_exception:
	bsr      compute_reg_a7              | Came here because we trapped.
	move.w   (reg_sr,%a6),%d0              | Get %D0 = virtual %SR
	movem.l  (reg_d1,%a6),%d1-%d7/%a0-%a7     | Restore all other regs
	bra.s    handle_stop_done

|###################################################
|# other_problem_instructions                      #
|###################################################
	.align	2
other_problem_instructions:
	| The main body of the emulator calls (or in fact jumps) back to here to handle
	| hardware-related instructions like MOVES and CALLM which need to be handled by
	| the user's front end
	
handle_moves:
	move.l   #illegal_offset,%d1
	lea      cf68k_moves(%pc),%a1
	bra      take_680x0_exception_via_known_front_end_routine
	
handle_bkpt:
	move.l   #illegal_offset,%d1
	lea      cf68k_bkpt(%pc),%a1
	bra      take_680x0_exception_via_known_front_end_routine
	
handle_cas:
	move.l   #illegal_offset,%d1
	lea      cf68k_cas(%pc),%a1
	bra      take_680x0_exception_via_known_front_end_routine
	
handle_cas2:
	move.l   #illegal_offset,%d1
	lea      cf68k_cas2(%pc),%a1
	bra      take_680x0_exception_via_known_front_end_routine
	
handle_callm:
	move.l   #illegal_offset,%d1
	lea      cf68k_callm(%pc),%a1
	bra      take_680x0_exception_via_known_front_end_routine
	
handle_rtm:
	move.l   #illegal_offset,%d1
	lea      cf68k_rtm(%pc),%a1
	bra      take_680x0_exception_via_known_front_end_routine
	
handle_divide_by_zero_exception:
	move.l   %a0,reg_pc(%a6)           | Update %PC
	moveq.l  #5,%d1                   | Vector number 5
	bra.s    handle_680x0_exception
handle_privilege_violation_exception:
	moveq.l  #8,%d1                   | Vector number 8
handle_680x0_exception:
	lsl.l    #2,%d1                   | Convert vector number to offset
	bra      take_680x0_exception_via_front_end
	
illegal:
	move.l   (instruction_address,%a6),%a1
	move.l   (%a1),%d1
	and.l    #0xf0000000,%d1
	cmpi.l   #0xa0000000,%d1
	beq.s    illegal_A_line
	cmpi.l   #0xf0000000,%d1
	beq.s    illegal_F_line
	move.l   #illegal_offset,%d1
	bra      take_680x0_exception_via_front_end
illegal_A_line:
	move.l   #40,%d1
	bra      take_680x0_exception_via_front_end
illegal_F_line:
	move.l   #44,%d1
	bra      take_680x0_exception_via_front_end
	
illegal_a7_relative_fetch:
	move.l   #illegal_offset,%d1
	lea      cf68k_emulation_error(%pc),%a1
	moveq.l  #-1,%d2                      | Error code
	bra      take_680x0_exception_via_known_front_end_routine
	
illegal_a7_relative_store:
	move.l   #illegal_offset,%d1
	lea      cf68k_emulation_error(%pc),%a1
	moveq.l  #-1,%d2                      | Error code
	bra      take_680x0_exception_via_known_front_end_routine
	
stack_fatally_stomped:
	move.l   #illegal_offset,%d1
	lea      cf68k_emulation_error(%pc),%a1
	moveq.l  #-2,%d2                      | Error code
	bra      take_680x0_exception_via_known_front_end_routine

|#########################################################################
|# Operand Fetch/Store Routines                                          #
|#########################################################################

|###################################################
|# fetch_long_D0                                   #
|###################################################
	.align	1
fetch_long_D0:
	move.l   reg_d0(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_D1                                   #
|###################################################
	.align	1
fetch_long_D1:
	move.l   reg_d1(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_D2                                   #
|###################################################
	.align	1
fetch_long_D2:
	move.l   reg_d2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_D3                                   #
|###################################################
	.align	1
fetch_long_D3:
	move.l   reg_d3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_D4                                   #
|###################################################
	.align	1
fetch_long_D4:
	move.l   reg_d4(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_D5                                   #
|###################################################
	.align	1
fetch_long_D5:
	move.l   reg_d5(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_D6                                   #
|###################################################
	.align	1
fetch_long_D6:
	move.l   reg_d6(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_D7                                   #
|###################################################
	.align	1
fetch_long_D7:
	move.l   reg_d7(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_A0                                   #
|###################################################
	.align	1
fetch_long_A0:
	move.l   reg_a0(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_A1                                   #
|###################################################
	.align	1
fetch_long_A1:
	move.l   reg_a1(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_A2                                   #
|###################################################
	.align	1
fetch_long_A2:
	move.l   reg_a2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_A3                                   #
|###################################################
	.align	1
fetch_long_A3:
	move.l   reg_a3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_A4                                   #
|###################################################
	.align	1
fetch_long_A4:
	move.l   reg_a4(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_A5                                   #
|###################################################
	.align	1
fetch_long_A5:
	move.l   reg_a5(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_A6                                   #
|###################################################
	.align	1
fetch_long_A6:
	move.l   reg_a6(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_A7                                   #
|###################################################
	.align	1
fetch_long_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_indirect_A0                          #
|###################################################
	.align	1
fetch_long_indirect_A0:
	move.l   reg_a0(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_indirect_A1                          #
|###################################################
	.align	1
fetch_long_indirect_A1:
	move.l   reg_a1(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_indirect_A2                          #
|###################################################
	.align	1
fetch_long_indirect_A2:
	move.l   reg_a2(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_indirect_A3                          #
|###################################################
	.align	1
fetch_long_indirect_A3:
	move.l   reg_a3(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_indirect_A4                          #
|###################################################
	.align	1
fetch_long_indirect_A4:
	move.l   reg_a4(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_indirect_A5                          #
|###################################################
	.align	1
fetch_long_indirect_A5:
	move.l   reg_a5(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_indirect_A6                          #
|###################################################
	.align	1
fetch_long_indirect_A6:
	move.l   reg_a6(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_indirect_A7                          #
|###################################################
	.align	1
fetch_long_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_postincrement_A0                     #
|###################################################
	.align	1
fetch_long_postincrement_A0:
	move.l   reg_a0(%a6),%a1
	move.l   (%a1)+,%d0
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_postincrement_A1                     #
|###################################################
	.align	1
fetch_long_postincrement_A1:
	move.l   reg_a1(%a6),%a1
	move.l   (%a1)+,%d0
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_postincrement_A2                     #
|###################################################
	.align	1
fetch_long_postincrement_A2:
	move.l   reg_a2(%a6),%a1
	move.l   (%a1)+,%d0
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_postincrement_A3                     #
|###################################################
	.align	1
fetch_long_postincrement_A3:
	move.l   reg_a3(%a6),%a1
	move.l   (%a1)+,%d0
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_postincrement_A4                     #
|###################################################
	.align	1
fetch_long_postincrement_A4:
	move.l   reg_a4(%a6),%a1
	move.l   (%a1)+,%d0
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_postincrement_A5                     #
|###################################################
	.align	1
fetch_long_postincrement_A5:
	move.l   reg_a5(%a6),%a1
	move.l   (%a1)+,%d0
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_postincrement_A6                     #
|###################################################
	.align	1
fetch_long_postincrement_A6:
	move.l   reg_a6(%a6),%a1
	move.l   (%a1)+,%d0
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_postincrement_A7                     #
|###################################################
	.align	1
fetch_long_postincrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.l   (%a1)+,%d0
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_predecrement_A0                      #
|###################################################
	.align	1
fetch_long_predecrement_A0:
	move.l   reg_a0(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_predecrement_A1                      #
|###################################################
	.align	1
fetch_long_predecrement_A1:
	move.l   reg_a1(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_predecrement_A2                      #
|###################################################
	.align	1
fetch_long_predecrement_A2:
	move.l   reg_a2(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_predecrement_A3                      #
|###################################################
	.align	1
fetch_long_predecrement_A3:
	move.l   reg_a3(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_predecrement_A4                      #
|###################################################
	.align	1
fetch_long_predecrement_A4:
	move.l   reg_a4(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_predecrement_A5                      #
|###################################################
	.align	1
fetch_long_predecrement_A5:
	move.l   reg_a5(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_predecrement_A6                      #
|###################################################
	.align	1
fetch_long_predecrement_A6:
	move.l   reg_a6(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_predecrement_A7                      #
|###################################################
	.align	1
fetch_long_predecrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.l   -(%a1),%d0
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_long_displacement_A0                      #
|###################################################
	.align	1
fetch_long_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
fetch_long_common:
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_displacement_A1                      #
|###################################################
	.align	1
fetch_long_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_displacement_A2                      #
|###################################################
	.align	1
fetch_long_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_displacement_A3                      #
|###################################################
	.align	1
fetch_long_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_displacement_A4                      #
|###################################################
	.align	1
fetch_long_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_displacement_A5                      #
|###################################################
	.align	1
fetch_long_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_displacement_A6                      #
|###################################################
	.align	1
fetch_long_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_displacement_A7                      #
|###################################################
	.align	1
fetch_long_displacement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	.long 	0x77680002               // mvs.w 2(%a0),%d3
	bmi      illegal_a7_relative_fetch
	adda.l   %d3,%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_indexed_A0                           #
|###################################################
	.align	1
fetch_long_indexed_A0:
	move.l   reg_a0(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_long_common

|###################################################
|# fetch_long_indexed_A1                           #
|###################################################
	.align	1
fetch_long_indexed_A1:
	move.l   reg_a1(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_long_common

|###################################################
|# fetch_long_indexed_A2                           #
|###################################################
	.align	1
fetch_long_indexed_A2:
	move.l   reg_a2(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_long_common

|###################################################
|# fetch_long_indexed_A3                           #
|###################################################
	.align	1
fetch_long_indexed_A3:
	move.l   reg_a3(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_long_common

|###################################################
|# fetch_long_indexed_A4                           #
|###################################################
	.align	1
fetch_long_indexed_A4:
	move.l   reg_a4(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_long_common

|###################################################
|# fetch_long_indexed_A5                           #
|###################################################
	.align	1
fetch_long_indexed_A5:
	move.l   reg_a5(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_long_common

|###################################################
|# fetch_long_indexed_A6                           #
|###################################################
	.align	1
fetch_long_indexed_A6:
	move.l   reg_a6(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_long_common

|###################################################
|# fetch_long_indexed_A7                           #
|###################################################
	.align	1
fetch_long_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_long_common

|###################################################
|# fetch_long_absolute_word                        #
|###################################################
	.align	1
fetch_long_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_absolute_long                        #
|###################################################
	.align	1
fetch_long_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_displacement_PC                      #
|###################################################
	.align	1
fetch_long_displacement_PC:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	add.l    %a0,%a1
	move.l   -2(%a1),%d0
	rts      

|###################################################
|# fetch_long_indexed_PC                           #
|###################################################
	.align	1
fetch_long_indexed_PC:
	lea      2(%a0),%a1
	bsr      calculate_indexed_address_alt
	move.l   (%a1),%d0
	rts      

|###################################################
|# fetch_long_immediate                            #
|###################################################
	.align	1
fetch_long_immediate:
	move.l   2(%a0),%d0
	addq.l   #6,%a0
	rts      

|###################################################
|# store_long_D0                                   #
|###################################################
	.align	1
store_long_D0:
	move.l   %d0,reg_d0(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_D1                                   #
|###################################################
	.align	1
store_long_D1:
	move.l   %d0,reg_d1(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_D2                                   #
|###################################################
	.align	1
store_long_D2:
	move.l   %d0,reg_d2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_D3                                   #
|###################################################
	.align	1
store_long_D3:
	move.l   %d0,reg_d3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_D4                                   #
|###################################################
	.align	1
store_long_D4:
	move.l   %d0,reg_d4(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_D5                                   #
|###################################################
	.align	1
store_long_D5:
	move.l   %d0,reg_d5(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_D6                                   #
|###################################################
	.align	1
store_long_D6:
	move.l   %d0,reg_d6(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_D7                                   #
|###################################################
	.align	1
store_long_D7:
	move.l   %d0,reg_d7(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_A0                                   #
|###################################################
	.align	1
store_long_A0:
	move.l   %d0,reg_a0(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_A1                                   #
|###################################################
	.align	1
store_long_A1:
	move.l   %d0,reg_a1(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_A2                                   #
|###################################################
	.align	1
store_long_A2:
	move.l   %d0,reg_a2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_A3                                   #
|###################################################
	.align	1
store_long_A3:
	move.l   %d0,reg_a3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_A4                                   #
|###################################################
	.align	1
store_long_A4:
	move.l   %d0,reg_a4(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_A5                                   #
|###################################################
	.align	1
store_long_A5:
	move.l   %d0,reg_a5(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_A6                                   #
|###################################################
	.align	1
store_long_A6:
	move.l   %d0,reg_a6(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_A7                                   #
|###################################################
	.align	1
store_long_A7:
	bset     #0,reg_a7_changed(%a6)
	move.l   %d0,reg_a7(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_indirect_A0                          #
|###################################################
	.align	1
store_long_indirect_A0:
	move.l   reg_a0(%a6),%a1
	move.l   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_indirect_A1                          #
|###################################################
	.align	1
store_long_indirect_A1:
	move.l   reg_a1(%a6),%a1
	move.l   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_indirect_A2                          #
|###################################################
	.align	1
store_long_indirect_A2:
	move.l   reg_a2(%a6),%a1
	move.l   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_indirect_A3                          #
|###################################################
	.align	1
store_long_indirect_A3:
	move.l   reg_a3(%a6),%a1
	move.l   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_indirect_A4                          #
|###################################################
	.align	1
store_long_indirect_A4:
	move.l   reg_a4(%a6),%a1
	move.l   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_indirect_A5                          #
|###################################################
	.align	1
store_long_indirect_A5:
	move.l   reg_a5(%a6),%a1
	move.l   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_indirect_A6                          #
|###################################################
	.align	1
store_long_indirect_A6:
	move.l   reg_a6(%a6),%a1
	move.l   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_indirect_A7                          #
|###################################################
	.align	1
store_long_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.l   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_postincrement_A0                     #
|###################################################
	.align	1
store_long_postincrement_A0:
	move.l   reg_a0(%a6),%a1
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_postincrement_A1                     #
|###################################################
	.align	1
store_long_postincrement_A1:
	move.l   reg_a1(%a6),%a1
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_postincrement_A2                     #
|###################################################
	.align	1
store_long_postincrement_A2:
	move.l   reg_a2(%a6),%a1
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_postincrement_A3                     #
|###################################################
	.align	1
store_long_postincrement_A3:
	move.l   reg_a3(%a6),%a1
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_postincrement_A4                     #
|###################################################
	.align	1
store_long_postincrement_A4:
	move.l   reg_a4(%a6),%a1
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_postincrement_A5                     #
|###################################################
	.align	1
store_long_postincrement_A5:
	move.l   reg_a5(%a6),%a1
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_postincrement_A6                     #
|###################################################
	.align	1
store_long_postincrement_A6:
	move.l   reg_a6(%a6),%a1
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_postincrement_A7                     #
|###################################################
	.align	1
store_long_postincrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	lea      4(%a1),%a1
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_predecrement_A0                      #
|###################################################
	.align	1
store_long_predecrement_A0:
	move.l   reg_a0(%a6),%a1
	move.l   %d0,-(%a1)
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_predecrement_A1                      #
|###################################################
	.align	1
store_long_predecrement_A1:
	move.l   reg_a1(%a6),%a1
	move.l   %d0,-(%a1)
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_predecrement_A2                      #
|###################################################
	.align	1
store_long_predecrement_A2:
	move.l   reg_a2(%a6),%a1
	move.l   %d0,-(%a1)
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_predecrement_A3                      #
|###################################################
	.align	1
store_long_predecrement_A3:
	move.l   reg_a3(%a6),%a1
	move.l   %d0,-(%a1)
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_predecrement_A4                      #
|###################################################
	.align	1
store_long_predecrement_A4:
	move.l   reg_a4(%a6),%a1
	move.l   %d0,-(%a1)
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_predecrement_A5                      #
|###################################################
	.align	1
store_long_predecrement_A5:
	move.l   reg_a5(%a6),%a1
	move.l   %d0,-(%a1)
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_predecrement_A6                      #
|###################################################
	.align	1
store_long_predecrement_A6:
	move.l   reg_a6(%a6),%a1
	move.l   %d0,-(%a1)
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_predecrement_A7                      #
|###################################################
	.align	1
store_long_predecrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	subq.l   #4,%a1
	move.l   %d0,(%a1)
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_long_displacement_A0                      #
|###################################################
	.align	1
store_long_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
store_long_common:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_long_displacement_A1                      #
|###################################################
	.align	1
store_long_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_long_displacement_A2                      #
|###################################################
	.align	1
store_long_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_long_displacement_A3                      #
|###################################################
	.align	1
store_long_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_long_displacement_A4                      #
|###################################################
	.align	1
store_long_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_long_displacement_A5                      #
|###################################################
	.align	1
store_long_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_long_displacement_A6                      #
|###################################################
	.align	1
store_long_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_long_displacement_A7                      #
|###################################################
	.align	1
store_long_displacement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	.long 	0x77680002               // mvs.w 2(%a0),%d3
	bmi      illegal_a7_relative_store
	adda.l   %d3,%a1
	addq.l   #4,%a0
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_long_indexed_A0                           #
|###################################################
	.align	1
store_long_indexed_A0:
	move.l   reg_a0(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_long_common

|###################################################
|# store_long_indexed_A1                           #
|###################################################
	.align	1
store_long_indexed_A1:
	move.l   reg_a1(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_long_common

|###################################################
|# store_long_indexed_A2                           #
|###################################################
	.align	1
store_long_indexed_A2:
	move.l   reg_a2(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_long_common

|###################################################
|# store_long_indexed_A3                           #
|###################################################
	.align	1
store_long_indexed_A3:
	move.l   reg_a3(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_long_common

|###################################################
|# store_long_indexed_A4                           #
|###################################################
	.align	1
store_long_indexed_A4:
	move.l   reg_a4(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_long_common

|###################################################
|# store_long_indexed_A5                           #
|###################################################
	.align	1
store_long_indexed_A5:
	move.l   reg_a5(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_long_common

|###################################################
|# store_long_indexed_A6                           #
|###################################################
	.align	1
store_long_indexed_A6:
	move.l   reg_a6(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_long_common

|###################################################
|# store_long_indexed_A7                           #
|###################################################
	.align	1
store_long_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_long_common

|###################################################
|# store_long_absolute_word                        #
|###################################################
	.align	1
store_long_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_long_absolute_long                        #
|###################################################
	.align	1
store_long_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_D0                        #
|###################################################
	.align	1
fetch_then_store_long_D0:
	move.l   reg_d0(%a6),%d0
	addq.l   #2,%a0
	lea      _store_140,%a3
	rts      
_store_140:
	move.l   %d0,reg_d0(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_D1                        #
|###################################################
	.align	1
fetch_then_store_long_D1:
	move.l   reg_d1(%a6),%d0
	addq.l   #2,%a0
	lea      _store_141,%a3
	rts      
_store_141:
	move.l   %d0,reg_d1(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_D2                        #
|###################################################
	.align	1
fetch_then_store_long_D2:
	move.l   reg_d2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_142,%a3
	rts      
_store_142:
	move.l   %d0,reg_d2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_D3                        #
|###################################################
	.align	1
fetch_then_store_long_D3:
	move.l   reg_d3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_143,%a3
	rts      
_store_143:
	move.l   %d0,reg_d3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_D4                        #
|###################################################
	.align	1
fetch_then_store_long_D4:
	move.l   reg_d4(%a6),%d0
	addq.l   #2,%a0
	lea      _store_144,%a3
	rts      
_store_144:
	move.l   %d0,reg_d4(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_D5                        #
|###################################################
	.align	1
fetch_then_store_long_D5:
	move.l   reg_d5(%a6),%d0
	addq.l   #2,%a0
	lea      _store_145,%a3
	rts      
_store_145:
	move.l   %d0,reg_d5(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_D6                        #
|###################################################
	.align	1
fetch_then_store_long_D6:
	move.l   reg_d6(%a6),%d0
	addq.l   #2,%a0
	lea      _store_146,%a3
	rts      
_store_146:
	move.l   %d0,reg_d6(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_D7                        #
|###################################################
	.align	1
fetch_then_store_long_D7:
	move.l   reg_d7(%a6),%d0
	addq.l   #2,%a0
	lea      _store_147,%a3
	rts      
_store_147:
	move.l   %d0,reg_d7(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_A0                        #
|###################################################
	.align	1
fetch_then_store_long_A0:
	move.l   reg_a0(%a6),%d0
	addq.l   #2,%a0
	lea      _store_148,%a3
	rts      
_store_148:
	move.l   %d0,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_A1                        #
|###################################################
	.align	1
fetch_then_store_long_A1:
	move.l   reg_a1(%a6),%d0
	addq.l   #2,%a0
	lea      _store_149,%a3
	rts      
_store_149:
	move.l   %d0,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_A2                        #
|###################################################
	.align	1
fetch_then_store_long_A2:
	move.l   reg_a2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_150,%a3
	rts      
_store_150:
	move.l   %d0,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_A3                        #
|###################################################
	.align	1
fetch_then_store_long_A3:
	move.l   reg_a3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_151,%a3
	rts      
_store_151:
	move.l   %d0,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_A4                        #
|###################################################
	.align	1
fetch_then_store_long_A4:
	move.l   reg_a4(%a6),%d0
	addq.l   #2,%a0
	lea      _store_152,%a3
	rts      
_store_152:
	move.l   %d0,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_A5                        #
|###################################################
	.align	1
fetch_then_store_long_A5:
	move.l   reg_a5(%a6),%d0
	addq.l   #2,%a0
	lea      _store_153,%a3
	rts      
_store_153:
	move.l   %d0,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_A6                        #
|###################################################
	.align	1
fetch_then_store_long_A6:
	move.l   reg_a6(%a6),%d0
	addq.l   #2,%a0
	lea      _store_154,%a3
	rts      
_store_154:
	move.l   %d0,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_A7                        #
|###################################################
	.align	1
fetch_then_store_long_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%d0
	addq.l   #2,%a0
	lea      _store_155,%a3
	rts      
_store_155:
	bset     #0,reg_a7_changed(%a6)
	move.l   %d0,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_indirect_A0               #
|###################################################
	.align	1
fetch_then_store_long_indirect_A0:
	move.l   reg_a0(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_156,%a3
	rts      
_store_156:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_indirect_A1               #
|###################################################
	.align	1
fetch_then_store_long_indirect_A1:
	move.l   reg_a1(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_157,%a3
	rts      
_store_157:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_indirect_A2               #
|###################################################
	.align	1
fetch_then_store_long_indirect_A2:
	move.l   reg_a2(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_158,%a3
	rts      
_store_158:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_indirect_A3               #
|###################################################
	.align	1
fetch_then_store_long_indirect_A3:
	move.l   reg_a3(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_159,%a3
	rts      
_store_159:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_indirect_A4               #
|###################################################
	.align	1
fetch_then_store_long_indirect_A4:
	move.l   reg_a4(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_160,%a3
	rts      
_store_160:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_indirect_A5               #
|###################################################
	.align	1
fetch_then_store_long_indirect_A5:
	move.l   reg_a5(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_161,%a3
	rts      
_store_161:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_indirect_A6               #
|###################################################
	.align	1
fetch_then_store_long_indirect_A6:
	move.l   reg_a6(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_162,%a3
	rts      
_store_162:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_indirect_A7               #
|###################################################
	.align	1
fetch_then_store_long_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_163,%a3
	rts      
_store_163:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_postincrement_A0          #
|###################################################
	.align	1
fetch_then_store_long_postincrement_A0:
	move.l   reg_a0(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_164,%a3
	rts      
_store_164:
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_postincrement_A1          #
|###################################################
	.align	1
fetch_then_store_long_postincrement_A1:
	move.l   reg_a1(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_165,%a3
	rts      
_store_165:
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_postincrement_A2          #
|###################################################
	.align	1
fetch_then_store_long_postincrement_A2:
	move.l   reg_a2(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_166,%a3
	rts      
_store_166:
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_postincrement_A3          #
|###################################################
	.align	1
fetch_then_store_long_postincrement_A3:
	move.l   reg_a3(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_167,%a3
	rts      
_store_167:
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_postincrement_A4          #
|###################################################
	.align	1
fetch_then_store_long_postincrement_A4:
	move.l   reg_a4(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_168,%a3
	rts      
_store_168:
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_postincrement_A5          #
|###################################################
	.align	1
fetch_then_store_long_postincrement_A5:
	move.l   reg_a5(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_169,%a3
	rts      
_store_169:
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_postincrement_A6          #
|###################################################
	.align	1
fetch_then_store_long_postincrement_A6:
	move.l   reg_a6(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_170,%a3
	rts      
_store_170:
	move.l   %d0,(%a1)+
	move.l   %a1,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_postincrement_A7          #
|###################################################
	.align	1
fetch_then_store_long_postincrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.l   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_171,%a3
	rts      
_store_171:
	lea      4(%a1),%a1
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_predecrement_A0           #
|###################################################
	.align	1
fetch_then_store_long_predecrement_A0:
	move.l   reg_a0(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	lea      _store_172,%a3
	rts      
_store_172:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_predecrement_A1           #
|###################################################
	.align	1
fetch_then_store_long_predecrement_A1:
	move.l   reg_a1(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	lea      _store_173,%a3
	rts      
_store_173:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_predecrement_A2           #
|###################################################
	.align	1
fetch_then_store_long_predecrement_A2:
	move.l   reg_a2(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	lea      _store_174,%a3
	rts      
_store_174:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_predecrement_A3           #
|###################################################
	.align	1
fetch_then_store_long_predecrement_A3:
	move.l   reg_a3(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	lea      _store_175,%a3
	rts      
_store_175:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_predecrement_A4           #
|###################################################
	.align	1
fetch_then_store_long_predecrement_A4:
	move.l   reg_a4(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	lea      _store_176,%a3
	rts      
_store_176:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_predecrement_A5           #
|###################################################
	.align	1
fetch_then_store_long_predecrement_A5:
	move.l   reg_a5(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	lea      _store_177,%a3
	rts      
_store_177:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_predecrement_A6           #
|###################################################
	.align	1
fetch_then_store_long_predecrement_A6:
	move.l   reg_a6(%a6),%a1
	move.l   -(%a1),%d0
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	lea      _store_178,%a3
	rts      
_store_178:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_predecrement_A7           #
|###################################################
	.align	1
fetch_then_store_long_predecrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.l   -(%a1),%d0
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	lea      _store_179,%a3
	rts      
_store_179:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_displacement_A0           #
|###################################################
	.align	1
fetch_then_store_long_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
fetch_then_store_long_common:
	move.l   (%a1),%d0
	lea      _store_180,%a3
	rts      
_store_180:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_displacement_A1           #
|###################################################
	.align	1
fetch_then_store_long_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	lea      _store_181,%a3
	rts      
_store_181:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_displacement_A2           #
|###################################################
	.align	1
fetch_then_store_long_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	lea      _store_182,%a3
	rts      
_store_182:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_displacement_A3           #
|###################################################
	.align	1
fetch_then_store_long_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	lea      _store_183,%a3
	rts      
_store_183:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_displacement_A4           #
|###################################################
	.align	1
fetch_then_store_long_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	lea      _store_184,%a3
	rts      
_store_184:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_displacement_A5           #
|###################################################
	.align	1
fetch_then_store_long_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	lea      _store_185,%a3
	rts      
_store_185:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_displacement_A6           #
|###################################################
	.align	1
fetch_then_store_long_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	lea      _store_186,%a3
	rts      
_store_186:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_displacement_A7           #
|###################################################
	.align	1
fetch_then_store_long_displacement_A7:
	.long 	0x77680002               // mvs.w 2(%a0),%d3
	bmi      illegal_a7_relative_fetch
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	adda.l   %d3,%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	lea      _store_187,%a3
	rts      
_store_187:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_indexed_A0                #
|###################################################
	.align	1
fetch_then_store_long_indexed_A0:
	move.l   reg_a0(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_long_common

|###################################################
|# fetch_then_store_long_indexed_A1                #
|###################################################
	.align	1
fetch_then_store_long_indexed_A1:
	move.l   reg_a1(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_long_common

|###################################################
|# fetch_then_store_long_indexed_A2                #
|###################################################
	.align	1
fetch_then_store_long_indexed_A2:
	move.l   reg_a2(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_long_common

|###################################################
|# fetch_then_store_long_indexed_A3                #
|###################################################
	.align	1
fetch_then_store_long_indexed_A3:
	move.l   reg_a3(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_long_common

|###################################################
|# fetch_then_store_long_indexed_A4                #
|###################################################
	.align	1
fetch_then_store_long_indexed_A4:
	move.l   reg_a4(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_long_common

|###################################################
|# fetch_then_store_long_indexed_A5                #
|###################################################
	.align	1
fetch_then_store_long_indexed_A5:
	move.l   reg_a5(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_long_common

|###################################################
|# fetch_then_store_long_indexed_A6                #
|###################################################
	.align	1
fetch_then_store_long_indexed_A6:
	move.l   reg_a6(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_long_common

|###################################################
|# fetch_then_store_long_indexed_A7                #
|###################################################
	.align	1
fetch_then_store_long_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_long_common

|###################################################
|# fetch_then_store_long_absolute_word             #
|###################################################
	.align	1
fetch_then_store_long_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	move.l   (%a1),%d0
	lea      _store_196,%a3
	rts      
_store_196:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_long_absolute_long             #
|###################################################
	.align	1
fetch_then_store_long_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	move.l   (%a1),%d0
	lea      _store_197,%a3
	rts      
_store_197:
	move.l   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_byte_D0                                   #
|###################################################
	.align	1
fetch_byte_D0:
	move.b   reg_d0+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_D1                                   #
|###################################################
	.align	1
fetch_byte_D1:
	move.b   reg_d1+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_D2                                   #
|###################################################
	.align	1
fetch_byte_D2:
	move.b   reg_d2+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_D3                                   #
|###################################################
	.align	1
fetch_byte_D3:
	move.b   reg_d3+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_D4                                   #
|###################################################
	.align	1
fetch_byte_D4:
	move.b   reg_d4+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_D5                                   #
|###################################################
	.align	1
fetch_byte_D5:
	move.b   reg_d5+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_D6                                   #
|###################################################
	.align	1
fetch_byte_D6:
	move.b   reg_d6+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_D7                                   #
|###################################################
	.align	1
fetch_byte_D7:
	move.b   reg_d7+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_A0                                   #
|###################################################
	.align	1
fetch_byte_A0:
	move.b   reg_a0+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_A1                                   #
|###################################################
	.align	1
fetch_byte_A1:
	move.b   reg_a1+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_A2                                   #
|###################################################
	.align	1
fetch_byte_A2:
	move.b   reg_a2+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_A3                                   #
|###################################################
	.align	1
fetch_byte_A3:
	move.b   reg_a3+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_A4                                   #
|###################################################
	.align	1
fetch_byte_A4:
	move.b   reg_a4+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_A5                                   #
|###################################################
	.align	1
fetch_byte_A5:
	move.b   reg_a5+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_A6                                   #
|###################################################
	.align	1
fetch_byte_A6:
	move.b   reg_a6+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_A7                                   #
|###################################################
	.align	1
fetch_byte_A7:
	jsr      compute_reg_a7
	move.b   reg_a7+3(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_indirect_A0                          #
|###################################################
	.align	1
fetch_byte_indirect_A0:
	move.l   reg_a0(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_indirect_A1                          #
|###################################################
	.align	1
fetch_byte_indirect_A1:
	move.l   reg_a1(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_indirect_A2                          #
|###################################################
	.align	1
fetch_byte_indirect_A2:
	move.l   reg_a2(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_indirect_A3                          #
|###################################################
	.align	1
fetch_byte_indirect_A3:
	move.l   reg_a3(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_indirect_A4                          #
|###################################################
	.align	1
fetch_byte_indirect_A4:
	move.l   reg_a4(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_indirect_A5                          #
|###################################################
	.align	1
fetch_byte_indirect_A5:
	move.l   reg_a5(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_indirect_A6                          #
|###################################################
	.align	1
fetch_byte_indirect_A6:
	move.l   reg_a6(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_indirect_A7                          #
|###################################################
	.align	1
fetch_byte_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_postincrement_A0                     #
|###################################################
	.align	1
fetch_byte_postincrement_A0:
	move.l   reg_a0(%a6),%a1
	move.b   (%a1)+,%d0
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_postincrement_A1                     #
|###################################################
	.align	1
fetch_byte_postincrement_A1:
	move.l   reg_a1(%a6),%a1
	move.b   (%a1)+,%d0
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_postincrement_A2                     #
|###################################################
	.align	1
fetch_byte_postincrement_A2:
	move.l   reg_a2(%a6),%a1
	move.b   (%a1)+,%d0
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_postincrement_A3                     #
|###################################################
	.align	1
fetch_byte_postincrement_A3:
	move.l   reg_a3(%a6),%a1
	move.b   (%a1)+,%d0
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_postincrement_A4                     #
|###################################################
	.align	1
fetch_byte_postincrement_A4:
	move.l   reg_a4(%a6),%a1
	move.b   (%a1)+,%d0
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_postincrement_A5                     #
|###################################################
	.align	1
fetch_byte_postincrement_A5:
	move.l   reg_a5(%a6),%a1
	move.b   (%a1)+,%d0
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_postincrement_A6                     #
|###################################################
	.align	1
fetch_byte_postincrement_A6:
	move.l   reg_a6(%a6),%a1
	move.b   (%a1)+,%d0
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_postincrement_A7                     #
|###################################################
	.align	1
fetch_byte_postincrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.b   (%a1)+,%d0
	addq.l   #1,%a1
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_predecrement_A0                      #
|###################################################
	.align	1
fetch_byte_predecrement_A0:
	move.l   reg_a0(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_predecrement_A1                      #
|###################################################
	.align	1
fetch_byte_predecrement_A1:
	move.l   reg_a1(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_predecrement_A2                      #
|###################################################
	.align	1
fetch_byte_predecrement_A2:
	move.l   reg_a2(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_predecrement_A3                      #
|###################################################
	.align	1
fetch_byte_predecrement_A3:
	move.l   reg_a3(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_predecrement_A4                      #
|###################################################
	.align	1
fetch_byte_predecrement_A4:
	move.l   reg_a4(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_predecrement_A5                      #
|###################################################
	.align	1
fetch_byte_predecrement_A5:
	move.l   reg_a5(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_predecrement_A6                      #
|###################################################
	.align	1
fetch_byte_predecrement_A6:
	move.l   reg_a6(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_predecrement_A7                      #
|###################################################
	.align	1
fetch_byte_predecrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	subq.l   #1,%a1
	move.b   -(%a1),%d0
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_byte_displacement_A0                      #
|###################################################
	.align	1
fetch_byte_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
fetch_byte_common:
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_displacement_A1                      #
|###################################################
	.align	1
fetch_byte_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_displacement_A2                      #
|###################################################
	.align	1
fetch_byte_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_displacement_A3                      #
|###################################################
	.align	1
fetch_byte_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_displacement_A4                      #
|###################################################
	.align	1
fetch_byte_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_displacement_A5                      #
|###################################################
	.align	1
fetch_byte_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_displacement_A6                      #
|###################################################
	.align	1
fetch_byte_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_displacement_A7                      #
|###################################################
	.align	1
fetch_byte_displacement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	.long 	0x77680002               // mvs.w 2(%a0),%d3
	bmi      illegal_a7_relative_fetch
	adda.l   %d3,%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_indexed_A0                           #
|###################################################
	.align	1
fetch_byte_indexed_A0:
	move.l   reg_a0(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_byte_common

|###################################################
|# fetch_byte_indexed_A1                           #
|###################################################
	.align	1
fetch_byte_indexed_A1:
	move.l   reg_a1(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_byte_common

|###################################################
|# fetch_byte_indexed_A2                           #
|###################################################
	.align	1
fetch_byte_indexed_A2:
	move.l   reg_a2(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_byte_common

|###################################################
|# fetch_byte_indexed_A3                           #
|###################################################
	.align	1
fetch_byte_indexed_A3:
	move.l   reg_a3(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_byte_common

|###################################################
|# fetch_byte_indexed_A4                           #
|###################################################
	.align	1
fetch_byte_indexed_A4:
	move.l   reg_a4(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_byte_common

|###################################################
|# fetch_byte_indexed_A5                           #
|###################################################
	.align	1
fetch_byte_indexed_A5:
	move.l   reg_a5(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_byte_common

|###################################################
|# fetch_byte_indexed_A6                           #
|###################################################
	.align	1
fetch_byte_indexed_A6:
	move.l   reg_a6(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_byte_common

|###################################################
|# fetch_byte_indexed_A7                           #
|###################################################
	.align	1
fetch_byte_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_byte_common

|###################################################
|# fetch_byte_absolute_word                        #
|###################################################
	.align	1
fetch_byte_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_absolute_long                        #
|###################################################
	.align	1
fetch_byte_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_displacement_PC                      #
|###################################################
	.align	1
fetch_byte_displacement_PC:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	add.l    %a0,%a1
	move.b   -2(%a1),%d0
	rts      

|###################################################
|# fetch_byte_indexed_PC                           #
|###################################################
	.align	1
fetch_byte_indexed_PC:
	lea      2(%a0),%a1
	bsr      calculate_indexed_address_alt
	move.b   (%a1),%d0
	rts      

|###################################################
|# fetch_byte_immediate                            #
|###################################################
	.align	1
fetch_byte_immediate:
	move.b   3(%a0),%d0
	addq.l   #4,%a0
	rts      

|###################################################
|# store_byte_D0                                   #
|###################################################
	.align	1
store_byte_D0:
	move.b   %d0,reg_d0+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_D1                                   #
|###################################################
	.align	1
store_byte_D1:
	move.b   %d0,reg_d1+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_D2                                   #
|###################################################
	.align	1
store_byte_D2:
	move.b   %d0,reg_d2+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_D3                                   #
|###################################################
	.align	1
store_byte_D3:
	move.b   %d0,reg_d3+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_D4                                   #
|###################################################
	.align	1
store_byte_D4:
	move.b   %d0,reg_d4+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_D5                                   #
|###################################################
	.align	1
store_byte_D5:
	move.b   %d0,reg_d5+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_D6                                   #
|###################################################
	.align	1
store_byte_D6:
	move.b   %d0,reg_d6+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_D7                                   #
|###################################################
	.align	1
store_byte_D7:
	move.b   %d0,reg_d7+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_A0                                   #
|###################################################
	.align	1
store_byte_A0:
	move.b   %d0,reg_a0+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_A1                                   #
|###################################################
	.align	1
store_byte_A1:
	move.b   %d0,reg_a1+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_A2                                   #
|###################################################
	.align	1
store_byte_A2:
	move.b   %d0,reg_a2+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_A3                                   #
|###################################################
	.align	1
store_byte_A3:
	move.b   %d0,reg_a3+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_A4                                   #
|###################################################
	.align	1
store_byte_A4:
	move.b   %d0,reg_a4+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_A5                                   #
|###################################################
	.align	1
store_byte_A5:
	move.b   %d0,reg_a5+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_A6                                   #
|###################################################
	.align	1
store_byte_A6:
	move.b   %d0,reg_a6+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_A7                                   #
|###################################################
	.align	1
store_byte_A7:
	bset     #0,reg_a7_changed(%a6)
	move.b   %d0,reg_a7+3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_indirect_A0                          #
|###################################################
	.align	1
store_byte_indirect_A0:
	move.l   reg_a0(%a6),%a1
	move.b   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_indirect_A1                          #
|###################################################
	.align	1
store_byte_indirect_A1:
	move.l   reg_a1(%a6),%a1
	move.b   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_indirect_A2                          #
|###################################################
	.align	1
store_byte_indirect_A2:
	move.l   reg_a2(%a6),%a1
	move.b   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_indirect_A3                          #
|###################################################
	.align	1
store_byte_indirect_A3:
	move.l   reg_a3(%a6),%a1
	move.b   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_indirect_A4                          #
|###################################################
	.align	1
store_byte_indirect_A4:
	move.l   reg_a4(%a6),%a1
	move.b   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_indirect_A5                          #
|###################################################
	.align	1
store_byte_indirect_A5:
	move.l   reg_a5(%a6),%a1
	move.b   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_indirect_A6                          #
|###################################################
	.align	1
store_byte_indirect_A6:
	move.l   reg_a6(%a6),%a1
	move.b   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_indirect_A7                          #
|###################################################
	.align	1
store_byte_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.b   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_postincrement_A0                     #
|###################################################
	.align	1
store_byte_postincrement_A0:
	move.l   reg_a0(%a6),%a1
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_postincrement_A1                     #
|###################################################
	.align	1
store_byte_postincrement_A1:
	move.l   reg_a1(%a6),%a1
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_postincrement_A2                     #
|###################################################
	.align	1
store_byte_postincrement_A2:
	move.l   reg_a2(%a6),%a1
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_postincrement_A3                     #
|###################################################
	.align	1
store_byte_postincrement_A3:
	move.l   reg_a3(%a6),%a1
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_postincrement_A4                     #
|###################################################
	.align	1
store_byte_postincrement_A4:
	move.l   reg_a4(%a6),%a1
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_postincrement_A5                     #
|###################################################
	.align	1
store_byte_postincrement_A5:
	move.l   reg_a5(%a6),%a1
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_postincrement_A6                     #
|###################################################
	.align	1
store_byte_postincrement_A6:
	move.l   reg_a6(%a6),%a1
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_postincrement_A7                     #
|###################################################
	.align	1
store_byte_postincrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	lea      2(%a1),%a1
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_predecrement_A0                      #
|###################################################
	.align	1
store_byte_predecrement_A0:
	move.l   reg_a0(%a6),%a1
	move.b   %d0,-(%a1)
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_predecrement_A1                      #
|###################################################
	.align	1
store_byte_predecrement_A1:
	move.l   reg_a1(%a6),%a1
	move.b   %d0,-(%a1)
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_predecrement_A2                      #
|###################################################
	.align	1
store_byte_predecrement_A2:
	move.l   reg_a2(%a6),%a1
	move.b   %d0,-(%a1)
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_predecrement_A3                      #
|###################################################
	.align	1
store_byte_predecrement_A3:
	move.l   reg_a3(%a6),%a1
	move.b   %d0,-(%a1)
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_predecrement_A4                      #
|###################################################
	.align	1
store_byte_predecrement_A4:
	move.l   reg_a4(%a6),%a1
	move.b   %d0,-(%a1)
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_predecrement_A5                      #
|###################################################
	.align	1
store_byte_predecrement_A5:
	move.l   reg_a5(%a6),%a1
	move.b   %d0,-(%a1)
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_predecrement_A6                      #
|###################################################
	.align	1
store_byte_predecrement_A6:
	move.l   reg_a6(%a6),%a1
	move.b   %d0,-(%a1)
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_predecrement_A7                      #
|###################################################
	.align	1
store_byte_predecrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	subq.l   #2,%a1
	move.b   %d0,(%a1)
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_byte_displacement_A0                      #
|###################################################
	.align	1
store_byte_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
store_byte_common:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_byte_displacement_A1                      #
|###################################################
	.align	1
store_byte_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_byte_displacement_A2                      #
|###################################################
	.align	1
store_byte_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_byte_displacement_A3                      #
|###################################################
	.align	1
store_byte_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_byte_displacement_A4                      #
|###################################################
	.align	1
store_byte_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_byte_displacement_A5                      #
|###################################################
	.align	1
store_byte_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_byte_displacement_A6                      #
|###################################################
	.align	1
store_byte_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_byte_displacement_A7                      #
|###################################################
	.align	1
store_byte_displacement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	.long 	0x77680002               // mvs.w 2(%a0),%d3
	bmi      illegal_a7_relative_store
	adda.l   %d3,%a1
	addq.l   #4,%a0
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_byte_indexed_A0                           #
|###################################################
	.align	1
store_byte_indexed_A0:
	move.l   reg_a0(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_byte_common

|###################################################
|# store_byte_indexed_A1                           #
|###################################################
	.align	1
store_byte_indexed_A1:
	move.l   reg_a1(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_byte_common

|###################################################
|# store_byte_indexed_A2                           #
|###################################################
	.align	1
store_byte_indexed_A2:
	move.l   reg_a2(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_byte_common

|###################################################
|# store_byte_indexed_A3                           #
|###################################################
	.align	1
store_byte_indexed_A3:
	move.l   reg_a3(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_byte_common

|###################################################
|# store_byte_indexed_A4                           #
|###################################################
	.align	1
store_byte_indexed_A4:
	move.l   reg_a4(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_byte_common

|###################################################
|# store_byte_indexed_A5                           #
|###################################################
	.align	1
store_byte_indexed_A5:
	move.l   reg_a5(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_byte_common

|###################################################
|# store_byte_indexed_A6                           #
|###################################################
	.align	1
store_byte_indexed_A6:
	move.l   reg_a6(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_byte_common

|###################################################
|# store_byte_indexed_A7                           #
|###################################################
	.align	1
store_byte_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_byte_common

|###################################################
|# store_byte_absolute_word                        #
|###################################################
	.align	1
store_byte_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_byte_absolute_long                        #
|###################################################
	.align	1
store_byte_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_D0                        #
|###################################################
	.align	1
fetch_then_store_byte_D0:
	move.b   reg_d0+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_317,%a3
	rts      
_store_317:
	move.b   %d0,reg_d0+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_D1                        #
|###################################################
	.align	1
fetch_then_store_byte_D1:
	move.b   reg_d1+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_318,%a3
	rts      
_store_318:
	move.b   %d0,reg_d1+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_D2                        #
|###################################################
	.align	1
fetch_then_store_byte_D2:
	move.b   reg_d2+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_319,%a3
	rts      
_store_319:
	move.b   %d0,reg_d2+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_D3                        #
|###################################################
	.align	1
fetch_then_store_byte_D3:
	move.b   reg_d3+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_320,%a3
	rts      
_store_320:
	move.b   %d0,reg_d3+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_D4                        #
|###################################################
	.align	1
fetch_then_store_byte_D4:
	move.b   reg_d4+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_321,%a3
	rts      
_store_321:
	move.b   %d0,reg_d4+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_D5                        #
|###################################################
	.align	1
fetch_then_store_byte_D5:
	move.b   reg_d5+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_322,%a3
	rts      
_store_322:
	move.b   %d0,reg_d5+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_D6                        #
|###################################################
	.align	1
fetch_then_store_byte_D6:
	move.b   reg_d6+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_323,%a3
	rts      
_store_323:
	move.b   %d0,reg_d6+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_D7                        #
|###################################################
	.align	1
fetch_then_store_byte_D7:
	move.b   reg_d7+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_324,%a3
	rts      
_store_324:
	move.b   %d0,reg_d7+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_A0                        #
|###################################################
	.align	1
fetch_then_store_byte_A0:
	move.b   reg_a0+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_325,%a3
	rts      
_store_325:
	move.b   %d0,reg_a0+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_A1                        #
|###################################################
	.align	1
fetch_then_store_byte_A1:
	move.b   reg_a1+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_326,%a3
	rts      
_store_326:
	move.b   %d0,reg_a1+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_A2                        #
|###################################################
	.align	1
fetch_then_store_byte_A2:
	move.b   reg_a2+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_327,%a3
	rts      
_store_327:
	move.b   %d0,reg_a2+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_A3                        #
|###################################################
	.align	1
fetch_then_store_byte_A3:
	move.b   reg_a3+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_328,%a3
	rts      
_store_328:
	move.b   %d0,reg_a3+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_A4                        #
|###################################################
	.align	1
fetch_then_store_byte_A4:
	move.b   reg_a4+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_329,%a3
	rts      
_store_329:
	move.b   %d0,reg_a4+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_A5                        #
|###################################################
	.align	1
fetch_then_store_byte_A5:
	move.b   reg_a5+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_330,%a3
	rts      
_store_330:
	move.b   %d0,reg_a5+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_A6                        #
|###################################################
	.align	1
fetch_then_store_byte_A6:
	move.b   reg_a6+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_331,%a3
	rts      
_store_331:
	move.b   %d0,reg_a6+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_A7                        #
|###################################################
	.align	1
fetch_then_store_byte_A7:
	jsr      compute_reg_a7
	move.b   reg_a7+3(%a6),%d0
	addq.l   #2,%a0
	lea      _store_332,%a3
	rts      
_store_332:
	bset     #0,reg_a7_changed(%a6)
	move.b   %d0,reg_a7+3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_indirect_A0               #
|###################################################
	.align	1
fetch_then_store_byte_indirect_A0:
	move.l   reg_a0(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_333,%a3
	rts      
_store_333:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_indirect_A1               #
|###################################################
	.align	1
fetch_then_store_byte_indirect_A1:
	move.l   reg_a1(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_334,%a3
	rts      
_store_334:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_indirect_A2               #
|###################################################
	.align	1
fetch_then_store_byte_indirect_A2:
	move.l   reg_a2(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_335,%a3
	rts      
_store_335:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_indirect_A3               #
|###################################################
	.align	1
fetch_then_store_byte_indirect_A3:
	move.l   reg_a3(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_336,%a3
	rts      
_store_336:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_indirect_A4               #
|###################################################
	.align	1
fetch_then_store_byte_indirect_A4:
	move.l   reg_a4(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_337,%a3
	rts      
_store_337:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_indirect_A5               #
|###################################################
	.align	1
fetch_then_store_byte_indirect_A5:
	move.l   reg_a5(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_338,%a3
	rts      
_store_338:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_indirect_A6               #
|###################################################
	.align	1
fetch_then_store_byte_indirect_A6:
	move.l   reg_a6(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_339,%a3
	rts      
_store_339:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_indirect_A7               #
|###################################################
	.align	1
fetch_then_store_byte_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_340,%a3
	rts      
_store_340:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_postincrement_A0          #
|###################################################
	.align	1
fetch_then_store_byte_postincrement_A0:
	move.l   reg_a0(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_341,%a3
	rts      
_store_341:
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_postincrement_A1          #
|###################################################
	.align	1
fetch_then_store_byte_postincrement_A1:
	move.l   reg_a1(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_342,%a3
	rts      
_store_342:
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_postincrement_A2          #
|###################################################
	.align	1
fetch_then_store_byte_postincrement_A2:
	move.l   reg_a2(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_343,%a3
	rts      
_store_343:
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_postincrement_A3          #
|###################################################
	.align	1
fetch_then_store_byte_postincrement_A3:
	move.l   reg_a3(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_344,%a3
	rts      
_store_344:
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_postincrement_A4          #
|###################################################
	.align	1
fetch_then_store_byte_postincrement_A4:
	move.l   reg_a4(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_345,%a3
	rts      
_store_345:
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_postincrement_A5          #
|###################################################
	.align	1
fetch_then_store_byte_postincrement_A5:
	move.l   reg_a5(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_346,%a3
	rts      
_store_346:
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_postincrement_A6          #
|###################################################
	.align	1
fetch_then_store_byte_postincrement_A6:
	move.l   reg_a6(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_347,%a3
	rts      
_store_347:
	move.b   %d0,(%a1)+
	move.l   %a1,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_postincrement_A7          #
|###################################################
	.align	1
fetch_then_store_byte_postincrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.b   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_348,%a3
	rts      
_store_348:
	lea      2(%a1),%a1
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_predecrement_A0           #
|###################################################
	.align	1
fetch_then_store_byte_predecrement_A0:
	move.l   reg_a0(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	lea      _store_349,%a3
	rts      
_store_349:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_predecrement_A1           #
|###################################################
	.align	1
fetch_then_store_byte_predecrement_A1:
	move.l   reg_a1(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	lea      _store_350,%a3
	rts      
_store_350:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_predecrement_A2           #
|###################################################
	.align	1
fetch_then_store_byte_predecrement_A2:
	move.l   reg_a2(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	lea      _store_351,%a3
	rts      
_store_351:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_predecrement_A3           #
|###################################################
	.align	1
fetch_then_store_byte_predecrement_A3:
	move.l   reg_a3(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	lea      _store_352,%a3
	rts      
_store_352:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_predecrement_A4           #
|###################################################
	.align	1
fetch_then_store_byte_predecrement_A4:
	move.l   reg_a4(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	lea      _store_353,%a3
	rts      
_store_353:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_predecrement_A5           #
|###################################################
	.align	1
fetch_then_store_byte_predecrement_A5:
	move.l   reg_a5(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	lea      _store_354,%a3
	rts      
_store_354:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_predecrement_A6           #
|###################################################
	.align	1
fetch_then_store_byte_predecrement_A6:
	move.l   reg_a6(%a6),%a1
	move.b   -(%a1),%d0
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	lea      _store_355,%a3
	rts      
_store_355:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_predecrement_A7           #
|###################################################
	.align	1
fetch_then_store_byte_predecrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	subq.l   #1,%a1
	move.b   -(%a1),%d0
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	lea      _store_356,%a3
	rts      
_store_356:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_displacement_A0           #
|###################################################
	.align	1
fetch_then_store_byte_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
fetch_then_store_byte_common:
	move.b   (%a1),%d0
	lea      _store_357,%a3
	rts      
_store_357:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_displacement_A1           #
|###################################################
	.align	1
fetch_then_store_byte_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	lea      _store_358,%a3
	rts      
_store_358:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_displacement_A2           #
|###################################################
	.align	1
fetch_then_store_byte_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	lea      _store_359,%a3
	rts      
_store_359:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_displacement_A3           #
|###################################################
	.align	1
fetch_then_store_byte_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	lea      _store_360,%a3
	rts      
_store_360:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_displacement_A4           #
|###################################################
	.align	1
fetch_then_store_byte_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	lea      _store_361,%a3
	rts      
_store_361:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_displacement_A5           #
|###################################################
	.align	1
fetch_then_store_byte_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	lea      _store_362,%a3
	rts      
_store_362:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_displacement_A6           #
|###################################################
	.align	1
fetch_then_store_byte_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	lea      _store_363,%a3
	rts      
_store_363:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_displacement_A7           #
|###################################################
	.align	1
fetch_then_store_byte_displacement_A7:
	.long 	0x77680002               // mvs.w 2(%a0),%d3
	bmi      illegal_a7_relative_fetch
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	adda.l   %d3,%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	lea      _store_364,%a3
	rts      
_store_364:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_indexed_A0                #
|###################################################
	.align	1
fetch_then_store_byte_indexed_A0:
	move.l   reg_a0(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_byte_common

|###################################################
|# fetch_then_store_byte_indexed_A1                #
|###################################################
	.align	1
fetch_then_store_byte_indexed_A1:
	move.l   reg_a1(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_byte_common

|###################################################
|# fetch_then_store_byte_indexed_A2                #
|###################################################
	.align	1
fetch_then_store_byte_indexed_A2:
	move.l   reg_a2(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_byte_common

|###################################################
|# fetch_then_store_byte_indexed_A3                #
|###################################################
	.align	1
fetch_then_store_byte_indexed_A3:
	move.l   reg_a3(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_byte_common

|###################################################
|# fetch_then_store_byte_indexed_A4                #
|###################################################
	.align	1
fetch_then_store_byte_indexed_A4:
	move.l   reg_a4(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_byte_common

|###################################################
|# fetch_then_store_byte_indexed_A5                #
|###################################################
	.align	1
fetch_then_store_byte_indexed_A5:
	move.l   reg_a5(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_byte_common

|###################################################
|# fetch_then_store_byte_indexed_A6                #
|###################################################
	.align	1
fetch_then_store_byte_indexed_A6:
	move.l   reg_a6(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_byte_common

|###################################################
|# fetch_then_store_byte_indexed_A7                #
|###################################################
	.align	1
fetch_then_store_byte_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_byte_common

|###################################################
|# fetch_then_store_byte_absolute_word             #
|###################################################
	.align	1
fetch_then_store_byte_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	move.b   (%a1),%d0
	lea      _store_373,%a3
	rts      
_store_373:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_byte_absolute_long             #
|###################################################
	.align	1
fetch_then_store_byte_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	move.b   (%a1),%d0
	lea      _store_374,%a3
	rts      
_store_374:
	move.b   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_word_D0                                   #
|###################################################
	.align	1
fetch_word_D0:
	move.w   reg_d0+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_D1                                   #
|###################################################
	.align	1
fetch_word_D1:
	move.w   reg_d1+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_D2                                   #
|###################################################
	.align	1
fetch_word_D2:
	move.w   reg_d2+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_D3                                   #
|###################################################
	.align	1
fetch_word_D3:
	move.w   reg_d3+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_D4                                   #
|###################################################
	.align	1
fetch_word_D4:
	move.w   reg_d4+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_D5                                   #
|###################################################
	.align	1
fetch_word_D5:
	move.w   reg_d5+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_D6                                   #
|###################################################
	.align	1
fetch_word_D6:
	move.w   reg_d6+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_D7                                   #
|###################################################
	.align	1
fetch_word_D7:
	move.w   reg_d7+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_A0                                   #
|###################################################
	.align	1
fetch_word_A0:
	move.w   reg_a0+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_A1                                   #
|###################################################
	.align	1
fetch_word_A1:
	move.w   reg_a1+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_A2                                   #
|###################################################
	.align	1
fetch_word_A2:
	move.w   reg_a2+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_A3                                   #
|###################################################
	.align	1
fetch_word_A3:
	move.w   reg_a3+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_A4                                   #
|###################################################
	.align	1
fetch_word_A4:
	move.w   reg_a4+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_A5                                   #
|###################################################
	.align	1
fetch_word_A5:
	move.w   reg_a5+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_A6                                   #
|###################################################
	.align	1
fetch_word_A6:
	move.w   reg_a6+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_A7                                   #
|###################################################
	.align	1
fetch_word_A7:
	jsr      compute_reg_a7
	move.w   reg_a7+2(%a6),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_indirect_A0                          #
|###################################################
	.align	1
fetch_word_indirect_A0:
	move.l   reg_a0(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_indirect_A1                          #
|###################################################
	.align	1
fetch_word_indirect_A1:
	move.l   reg_a1(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_indirect_A2                          #
|###################################################
	.align	1
fetch_word_indirect_A2:
	move.l   reg_a2(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_indirect_A3                          #
|###################################################
	.align	1
fetch_word_indirect_A3:
	move.l   reg_a3(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_indirect_A4                          #
|###################################################
	.align	1
fetch_word_indirect_A4:
	move.l   reg_a4(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_indirect_A5                          #
|###################################################
	.align	1
fetch_word_indirect_A5:
	move.l   reg_a5(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_indirect_A6                          #
|###################################################
	.align	1
fetch_word_indirect_A6:
	move.l   reg_a6(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_indirect_A7                          #
|###################################################
	.align	1
fetch_word_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_postincrement_A0                     #
|###################################################
	.align	1
fetch_word_postincrement_A0:
	move.l   reg_a0(%a6),%a1
	move.w   (%a1)+,%d0
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_postincrement_A1                     #
|###################################################
	.align	1
fetch_word_postincrement_A1:
	move.l   reg_a1(%a6),%a1
	move.w   (%a1)+,%d0
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_postincrement_A2                     #
|###################################################
	.align	1
fetch_word_postincrement_A2:
	move.l   reg_a2(%a6),%a1
	move.w   (%a1)+,%d0
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_postincrement_A3                     #
|###################################################
	.align	1
fetch_word_postincrement_A3:
	move.l   reg_a3(%a6),%a1
	move.w   (%a1)+,%d0
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_postincrement_A4                     #
|###################################################
	.align	1
fetch_word_postincrement_A4:
	move.l   reg_a4(%a6),%a1
	move.w   (%a1)+,%d0
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_postincrement_A5                     #
|###################################################
	.align	1
fetch_word_postincrement_A5:
	move.l   reg_a5(%a6),%a1
	move.w   (%a1)+,%d0
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_postincrement_A6                     #
|###################################################
	.align	1
fetch_word_postincrement_A6:
	move.l   reg_a6(%a6),%a1
	move.w   (%a1)+,%d0
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_postincrement_A7                     #
|###################################################
	.align	1
fetch_word_postincrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.w   (%a1)+,%d0
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_predecrement_A0                      #
|###################################################
	.align	1
fetch_word_predecrement_A0:
	move.l   reg_a0(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_predecrement_A1                      #
|###################################################
	.align	1
fetch_word_predecrement_A1:
	move.l   reg_a1(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_predecrement_A2                      #
|###################################################
	.align	1
fetch_word_predecrement_A2:
	move.l   reg_a2(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_predecrement_A3                      #
|###################################################
	.align	1
fetch_word_predecrement_A3:
	move.l   reg_a3(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_predecrement_A4                      #
|###################################################
	.align	1
fetch_word_predecrement_A4:
	move.l   reg_a4(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_predecrement_A5                      #
|###################################################
	.align	1
fetch_word_predecrement_A5:
	move.l   reg_a5(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_predecrement_A6                      #
|###################################################
	.align	1
fetch_word_predecrement_A6:
	move.l   reg_a6(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_predecrement_A7                      #
|###################################################
	.align	1
fetch_word_predecrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.w   -(%a1),%d0
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	rts      

|###################################################
|# fetch_word_displacement_A0                      #
|###################################################
	.align	1
fetch_word_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
fetch_word_common:
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_displacement_A1                      #
|###################################################
	.align	1
fetch_word_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_displacement_A2                      #
|###################################################
	.align	1
fetch_word_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_displacement_A3                      #
|###################################################
	.align	1
fetch_word_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_displacement_A4                      #
|###################################################
	.align	1
fetch_word_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_displacement_A5                      #
|###################################################
	.align	1
fetch_word_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_displacement_A6                      #
|###################################################
	.align	1
fetch_word_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_displacement_A7                      #
|###################################################
	.align	1
fetch_word_displacement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	.long 	0x77680002               // mvs.w 2(%a0),%d3
	bmi      illegal_a7_relative_fetch
	adda.l   %d3,%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_indexed_A0                           #
|###################################################
	.align	1
fetch_word_indexed_A0:
	move.l   reg_a0(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_word_common

|###################################################
|# fetch_word_indexed_A1                           #
|###################################################
	.align	1
fetch_word_indexed_A1:
	move.l   reg_a1(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_word_common

|###################################################
|# fetch_word_indexed_A2                           #
|###################################################
	.align	1
fetch_word_indexed_A2:
	move.l   reg_a2(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_word_common

|###################################################
|# fetch_word_indexed_A3                           #
|###################################################
	.align	1
fetch_word_indexed_A3:
	move.l   reg_a3(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_word_common

|###################################################
|# fetch_word_indexed_A4                           #
|###################################################
	.align	1
fetch_word_indexed_A4:
	move.l   reg_a4(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_word_common

|###################################################
|# fetch_word_indexed_A5                           #
|###################################################
	.align	1
fetch_word_indexed_A5:
	move.l   reg_a5(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_word_common

|###################################################
|# fetch_word_indexed_A6                           #
|###################################################
	.align	1
fetch_word_indexed_A6:
	move.l   reg_a6(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_word_common

|###################################################
|# fetch_word_indexed_A7                           #
|###################################################
	.align	1
fetch_word_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_word_common

|###################################################
|# fetch_word_absolute_word                        #
|###################################################
	.align	1
fetch_word_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_absolute_long                        #
|###################################################
	.align	1
fetch_word_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_displacement_PC                      #
|###################################################
	.align	1
fetch_word_displacement_PC:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	add.l    %a0,%a1
	move.w   -2(%a1),%d0
	rts      

|###################################################
|# fetch_word_indexed_PC                           #
|###################################################
	.align	1
fetch_word_indexed_PC:
	lea      2(%a0),%a1
	bsr      calculate_indexed_address_alt
	move.w   (%a1),%d0
	rts      

|###################################################
|# fetch_word_immediate                            #
|###################################################
	.align	1
fetch_word_immediate:
	move.w   2(%a0),%d0
	addq.l   #4,%a0
	rts      

|###################################################
|# store_word_D0                                   #
|###################################################
	.align	1
store_word_D0:
	move.w   %d0,reg_d0+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_D1                                   #
|###################################################
	.align	1
store_word_D1:
	move.w   %d0,reg_d1+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_D2                                   #
|###################################################
	.align	1
store_word_D2:
	move.w   %d0,reg_d2+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_D3                                   #
|###################################################
	.align	1
store_word_D3:
	move.w   %d0,reg_d3+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_D4                                   #
|###################################################
	.align	1
store_word_D4:
	move.w   %d0,reg_d4+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_D5                                   #
|###################################################
	.align	1
store_word_D5:
	move.w   %d0,reg_d5+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_D6                                   #
|###################################################
	.align	1
store_word_D6:
	move.w   %d0,reg_d6+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_D7                                   #
|###################################################
	.align	1
store_word_D7:
	move.w   %d0,reg_d7+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_A0                                   #
|###################################################
	.align	1
store_word_A0:
	move.w   %d0,reg_a0+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_A1                                   #
|###################################################
	.align	1
store_word_A1:
	move.w   %d0,reg_a1+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_A2                                   #
|###################################################
	.align	1
store_word_A2:
	move.w   %d0,reg_a2+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_A3                                   #
|###################################################
	.align	1
store_word_A3:
	move.w   %d0,reg_a3+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_A4                                   #
|###################################################
	.align	1
store_word_A4:
	move.w   %d0,reg_a4+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_A5                                   #
|###################################################
	.align	1
store_word_A5:
	move.w   %d0,reg_a5+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_A6                                   #
|###################################################
	.align	1
store_word_A6:
	move.w   %d0,reg_a6+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_A7                                   #
|###################################################
	.align	1
store_word_A7:
	bset     #0,reg_a7_changed(%a6)
	move.w   %d0,reg_a7+2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_indirect_A0                          #
|###################################################
	.align	1
store_word_indirect_A0:
	move.l   reg_a0(%a6),%a1
	move.w   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_indirect_A1                          #
|###################################################
	.align	1
store_word_indirect_A1:
	move.l   reg_a1(%a6),%a1
	move.w   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_indirect_A2                          #
|###################################################
	.align	1
store_word_indirect_A2:
	move.l   reg_a2(%a6),%a1
	move.w   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_indirect_A3                          #
|###################################################
	.align	1
store_word_indirect_A3:
	move.l   reg_a3(%a6),%a1
	move.w   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_indirect_A4                          #
|###################################################
	.align	1
store_word_indirect_A4:
	move.l   reg_a4(%a6),%a1
	move.w   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_indirect_A5                          #
|###################################################
	.align	1
store_word_indirect_A5:
	move.l   reg_a5(%a6),%a1
	move.w   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_indirect_A6                          #
|###################################################
	.align	1
store_word_indirect_A6:
	move.l   reg_a6(%a6),%a1
	move.w   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_indirect_A7                          #
|###################################################
	.align	1
store_word_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.w   %d0,(%a1)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_postincrement_A0                     #
|###################################################
	.align	1
store_word_postincrement_A0:
	move.l   reg_a0(%a6),%a1
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_postincrement_A1                     #
|###################################################
	.align	1
store_word_postincrement_A1:
	move.l   reg_a1(%a6),%a1
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_postincrement_A2                     #
|###################################################
	.align	1
store_word_postincrement_A2:
	move.l   reg_a2(%a6),%a1
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_postincrement_A3                     #
|###################################################
	.align	1
store_word_postincrement_A3:
	move.l   reg_a3(%a6),%a1
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_postincrement_A4                     #
|###################################################
	.align	1
store_word_postincrement_A4:
	move.l   reg_a4(%a6),%a1
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_postincrement_A5                     #
|###################################################
	.align	1
store_word_postincrement_A5:
	move.l   reg_a5(%a6),%a1
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_postincrement_A6                     #
|###################################################
	.align	1
store_word_postincrement_A6:
	move.l   reg_a6(%a6),%a1
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_postincrement_A7                     #
|###################################################
	.align	1
store_word_postincrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	lea      2(%a1),%a1
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_predecrement_A0                      #
|###################################################
	.align	1
store_word_predecrement_A0:
	move.l   reg_a0(%a6),%a1
	move.w   %d0,-(%a1)
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_predecrement_A1                      #
|###################################################
	.align	1
store_word_predecrement_A1:
	move.l   reg_a1(%a6),%a1
	move.w   %d0,-(%a1)
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_predecrement_A2                      #
|###################################################
	.align	1
store_word_predecrement_A2:
	move.l   reg_a2(%a6),%a1
	move.w   %d0,-(%a1)
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_predecrement_A3                      #
|###################################################
	.align	1
store_word_predecrement_A3:
	move.l   reg_a3(%a6),%a1
	move.w   %d0,-(%a1)
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_predecrement_A4                      #
|###################################################
	.align	1
store_word_predecrement_A4:
	move.l   reg_a4(%a6),%a1
	move.w   %d0,-(%a1)
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_predecrement_A5                      #
|###################################################
	.align	1
store_word_predecrement_A5:
	move.l   reg_a5(%a6),%a1
	move.w   %d0,-(%a1)
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_predecrement_A6                      #
|###################################################
	.align	1
store_word_predecrement_A6:
	move.l   reg_a6(%a6),%a1
	move.w   %d0,-(%a1)
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_predecrement_A7                      #
|###################################################
	.align	1
store_word_predecrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	subq.l   #2,%a1
	move.w   %d0,(%a1)
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	jmp      exception_handled

|###################################################
|# store_word_displacement_A0                      #
|###################################################
	.align	1
store_word_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
store_word_common:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_word_displacement_A1                      #
|###################################################
	.align	1
store_word_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_word_displacement_A2                      #
|###################################################
	.align	1
store_word_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_word_displacement_A3                      #
|###################################################
	.align	1
store_word_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_word_displacement_A4                      #
|###################################################
	.align	1
store_word_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_word_displacement_A5                      #
|###################################################
	.align	1
store_word_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_word_displacement_A6                      #
|###################################################
	.align	1
store_word_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_word_displacement_A7                      #
|###################################################
	.align	1
store_word_displacement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	.long 	0x77680002               // mvs.w 2(%a0),%d3
	bmi      illegal_a7_relative_store
	adda.l   %d3,%a1
	addq.l   #4,%a0
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_word_indexed_A0                           #
|###################################################
	.align	1
store_word_indexed_A0:
	move.l   reg_a0(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_word_common

|###################################################
|# store_word_indexed_A1                           #
|###################################################
	.align	1
store_word_indexed_A1:
	move.l   reg_a1(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_word_common

|###################################################
|# store_word_indexed_A2                           #
|###################################################
	.align	1
store_word_indexed_A2:
	move.l   reg_a2(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_word_common

|###################################################
|# store_word_indexed_A3                           #
|###################################################
	.align	1
store_word_indexed_A3:
	move.l   reg_a3(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_word_common

|###################################################
|# store_word_indexed_A4                           #
|###################################################
	.align	1
store_word_indexed_A4:
	move.l   reg_a4(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_word_common

|###################################################
|# store_word_indexed_A5                           #
|###################################################
	.align	1
store_word_indexed_A5:
	move.l   reg_a5(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_word_common

|###################################################
|# store_word_indexed_A6                           #
|###################################################
	.align	1
store_word_indexed_A6:
	move.l   reg_a6(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_word_common

|###################################################
|# store_word_indexed_A7                           #
|###################################################
	.align	1
store_word_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      store_word_common

|###################################################
|# store_word_absolute_word                        #
|###################################################
	.align	1
store_word_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# store_word_absolute_long                        #
|###################################################
	.align	1
store_word_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_D0                        #
|###################################################
	.align	1
fetch_then_store_word_D0:
	move.w   reg_d0+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_494,%a3
	rts      
_store_494:
	move.w   %d0,reg_d0+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_D1                        #
|###################################################
	.align	1
fetch_then_store_word_D1:
	move.w   reg_d1+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_495,%a3
	rts      
_store_495:
	move.w   %d0,reg_d1+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_D2                        #
|###################################################
	.align	1
fetch_then_store_word_D2:
	move.w   reg_d2+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_496,%a3
	rts      
_store_496:
	move.w   %d0,reg_d2+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_D3                        #
|###################################################
	.align	1
fetch_then_store_word_D3:
	move.w   reg_d3+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_497,%a3
	rts      
_store_497:
	move.w   %d0,reg_d3+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_D4                        #
|###################################################
	.align	1
fetch_then_store_word_D4:
	move.w   reg_d4+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_498,%a3
	rts      
_store_498:
	move.w   %d0,reg_d4+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_D5                        #
|###################################################
	.align	1
fetch_then_store_word_D5:
	move.w   reg_d5+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_499,%a3
	rts      
_store_499:
	move.w   %d0,reg_d5+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_D6                        #
|###################################################
	.align	1
fetch_then_store_word_D6:
	move.w   reg_d6+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_500,%a3
	rts      
_store_500:
	move.w   %d0,reg_d6+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_D7                        #
|###################################################
	.align	1
fetch_then_store_word_D7:
	move.w   reg_d7+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_501,%a3
	rts      
_store_501:
	move.w   %d0,reg_d7+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_A0                        #
|###################################################
	.align	1
fetch_then_store_word_A0:
	move.w   reg_a0+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_502,%a3
	rts      
_store_502:
	move.w   %d0,reg_a0+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_A1                        #
|###################################################
	.align	1
fetch_then_store_word_A1:
	move.w   reg_a1+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_503,%a3
	rts      
_store_503:
	move.w   %d0,reg_a1+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_A2                        #
|###################################################
	.align	1
fetch_then_store_word_A2:
	move.w   reg_a2+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_504,%a3
	rts      
_store_504:
	move.w   %d0,reg_a2+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_A3                        #
|###################################################
	.align	1
fetch_then_store_word_A3:
	move.w   reg_a3+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_505,%a3
	rts      
_store_505:
	move.w   %d0,reg_a3+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_A4                        #
|###################################################
	.align	1
fetch_then_store_word_A4:
	move.w   reg_a4+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_506,%a3
	rts      
_store_506:
	move.w   %d0,reg_a4+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_A5                        #
|###################################################
	.align	1
fetch_then_store_word_A5:
	move.w   reg_a5+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_507,%a3
	rts      
_store_507:
	move.w   %d0,reg_a5+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_A6                        #
|###################################################
	.align	1
fetch_then_store_word_A6:
	move.w   reg_a6+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_508,%a3
	rts      
_store_508:
	move.w   %d0,reg_a6+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_A7                        #
|###################################################
	.align	1
fetch_then_store_word_A7:
	jsr      compute_reg_a7
	move.w   reg_a7+2(%a6),%d0
	addq.l   #2,%a0
	lea      _store_509,%a3
	rts      
_store_509:
	bset     #0,reg_a7_changed(%a6)
	move.w   %d0,reg_a7+2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_indirect_A0               #
|###################################################
	.align	1
fetch_then_store_word_indirect_A0:
	move.l   reg_a0(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_510,%a3
	rts      
_store_510:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_indirect_A1               #
|###################################################
	.align	1
fetch_then_store_word_indirect_A1:
	move.l   reg_a1(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_511,%a3
	rts      
_store_511:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_indirect_A2               #
|###################################################
	.align	1
fetch_then_store_word_indirect_A2:
	move.l   reg_a2(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_512,%a3
	rts      
_store_512:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_indirect_A3               #
|###################################################
	.align	1
fetch_then_store_word_indirect_A3:
	move.l   reg_a3(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_513,%a3
	rts      
_store_513:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_indirect_A4               #
|###################################################
	.align	1
fetch_then_store_word_indirect_A4:
	move.l   reg_a4(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_514,%a3
	rts      
_store_514:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_indirect_A5               #
|###################################################
	.align	1
fetch_then_store_word_indirect_A5:
	move.l   reg_a5(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_515,%a3
	rts      
_store_515:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_indirect_A6               #
|###################################################
	.align	1
fetch_then_store_word_indirect_A6:
	move.l   reg_a6(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_516,%a3
	rts      
_store_516:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_indirect_A7               #
|###################################################
	.align	1
fetch_then_store_word_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_517,%a3
	rts      
_store_517:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_postincrement_A0          #
|###################################################
	.align	1
fetch_then_store_word_postincrement_A0:
	move.l   reg_a0(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_518,%a3
	rts      
_store_518:
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_postincrement_A1          #
|###################################################
	.align	1
fetch_then_store_word_postincrement_A1:
	move.l   reg_a1(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_519,%a3
	rts      
_store_519:
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_postincrement_A2          #
|###################################################
	.align	1
fetch_then_store_word_postincrement_A2:
	move.l   reg_a2(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_520,%a3
	rts      
_store_520:
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_postincrement_A3          #
|###################################################
	.align	1
fetch_then_store_word_postincrement_A3:
	move.l   reg_a3(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_521,%a3
	rts      
_store_521:
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_postincrement_A4          #
|###################################################
	.align	1
fetch_then_store_word_postincrement_A4:
	move.l   reg_a4(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_522,%a3
	rts      
_store_522:
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_postincrement_A5          #
|###################################################
	.align	1
fetch_then_store_word_postincrement_A5:
	move.l   reg_a5(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_523,%a3
	rts      
_store_523:
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_postincrement_A6          #
|###################################################
	.align	1
fetch_then_store_word_postincrement_A6:
	move.l   reg_a6(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_524,%a3
	rts      
_store_524:
	move.w   %d0,(%a1)+
	move.l   %a1,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_postincrement_A7          #
|###################################################
	.align	1
fetch_then_store_word_postincrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.w   (%a1),%d0
	addq.l   #2,%a0
	lea      _store_525,%a3
	rts      
_store_525:
	lea      2(%a1),%a1
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_predecrement_A0           #
|###################################################
	.align	1
fetch_then_store_word_predecrement_A0:
	move.l   reg_a0(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a0(%a6)
	addq.l   #2,%a0
	lea      _store_526,%a3
	rts      
_store_526:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_predecrement_A1           #
|###################################################
	.align	1
fetch_then_store_word_predecrement_A1:
	move.l   reg_a1(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a1(%a6)
	addq.l   #2,%a0
	lea      _store_527,%a3
	rts      
_store_527:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_predecrement_A2           #
|###################################################
	.align	1
fetch_then_store_word_predecrement_A2:
	move.l   reg_a2(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a2(%a6)
	addq.l   #2,%a0
	lea      _store_528,%a3
	rts      
_store_528:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_predecrement_A3           #
|###################################################
	.align	1
fetch_then_store_word_predecrement_A3:
	move.l   reg_a3(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a3(%a6)
	addq.l   #2,%a0
	lea      _store_529,%a3
	rts      
_store_529:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_predecrement_A4           #
|###################################################
	.align	1
fetch_then_store_word_predecrement_A4:
	move.l   reg_a4(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a4(%a6)
	addq.l   #2,%a0
	lea      _store_530,%a3
	rts      
_store_530:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_predecrement_A5           #
|###################################################
	.align	1
fetch_then_store_word_predecrement_A5:
	move.l   reg_a5(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a5(%a6)
	addq.l   #2,%a0
	lea      _store_531,%a3
	rts      
_store_531:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_predecrement_A6           #
|###################################################
	.align	1
fetch_then_store_word_predecrement_A6:
	move.l   reg_a6(%a6),%a1
	move.w   -(%a1),%d0
	move.l   %a1,reg_a6(%a6)
	addq.l   #2,%a0
	lea      _store_532,%a3
	rts      
_store_532:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_predecrement_A7           #
|###################################################
	.align	1
fetch_then_store_word_predecrement_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.w   -(%a1),%d0
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	addq.l   #2,%a0
	lea      _store_533,%a3
	rts      
_store_533:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_displacement_A0           #
|###################################################
	.align	1
fetch_then_store_word_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
fetch_then_store_word_common:
	move.w   (%a1),%d0
	lea      _store_534,%a3
	rts      
_store_534:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_displacement_A1           #
|###################################################
	.align	1
fetch_then_store_word_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	lea      _store_535,%a3
	rts      
_store_535:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_displacement_A2           #
|###################################################
	.align	1
fetch_then_store_word_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	lea      _store_536,%a3
	rts      
_store_536:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_displacement_A3           #
|###################################################
	.align	1
fetch_then_store_word_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	lea      _store_537,%a3
	rts      
_store_537:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_displacement_A4           #
|###################################################
	.align	1
fetch_then_store_word_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	lea      _store_538,%a3
	rts      
_store_538:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_displacement_A5           #
|###################################################
	.align	1
fetch_then_store_word_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	lea      _store_539,%a3
	rts      
_store_539:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_displacement_A6           #
|###################################################
	.align	1
fetch_then_store_word_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	lea      _store_540,%a3
	rts      
_store_540:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_displacement_A7           #
|###################################################
	.align	1
fetch_then_store_word_displacement_A7:
	.long 	0x77680002               // mvs.w 2(%a0),%d3
	bmi      illegal_a7_relative_fetch
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	adda.l   %d3,%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	lea      _store_541,%a3
	rts      
_store_541:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_indexed_A0                #
|###################################################
	.align	1
fetch_then_store_word_indexed_A0:
	move.l   reg_a0(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_word_common

|###################################################
|# fetch_then_store_word_indexed_A1                #
|###################################################
	.align	1
fetch_then_store_word_indexed_A1:
	move.l   reg_a1(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_word_common

|###################################################
|# fetch_then_store_word_indexed_A2                #
|###################################################
	.align	1
fetch_then_store_word_indexed_A2:
	move.l   reg_a2(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_word_common

|###################################################
|# fetch_then_store_word_indexed_A3                #
|###################################################
	.align	1
fetch_then_store_word_indexed_A3:
	move.l   reg_a3(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_word_common

|###################################################
|# fetch_then_store_word_indexed_A4                #
|###################################################
	.align	1
fetch_then_store_word_indexed_A4:
	move.l   reg_a4(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_word_common

|###################################################
|# fetch_then_store_word_indexed_A5                #
|###################################################
	.align	1
fetch_then_store_word_indexed_A5:
	move.l   reg_a5(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_word_common

|###################################################
|# fetch_then_store_word_indexed_A6                #
|###################################################
	.align	1
fetch_then_store_word_indexed_A6:
	move.l   reg_a6(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_word_common

|###################################################
|# fetch_then_store_word_indexed_A7                #
|###################################################
	.align	1
fetch_then_store_word_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	bsr      calculate_indexed_address_alt
	bra      fetch_then_store_word_common

|###################################################
|# fetch_then_store_word_absolute_word             #
|###################################################
	.align	1
fetch_then_store_word_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	move.w   (%a1),%d0
	lea      _store_550,%a3
	rts      
_store_550:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# fetch_then_store_word_absolute_long             #
|###################################################
	.align	1
fetch_then_store_word_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	move.w   (%a1),%d0
	lea      _store_551,%a3
	rts      
_store_551:
	move.w   %d0,(%a1)
	jmp      exception_handled

|###################################################
|# ea_indirect_A0                                  #
|###################################################
	.align	2
ea_indirect_A0:
	move.l   reg_a0(%a6),%a1
	addq.l   #2,%a0
	rts      

|###################################################
|# ea_indirect_A1                                  #
|###################################################
	.align	2
ea_indirect_A1:
	move.l   reg_a1(%a6),%a1
	addq.l   #2,%a0
	rts      

|###################################################
|# ea_indirect_A2                                  #
|###################################################
	.align	2
ea_indirect_A2:
	move.l   reg_a2(%a6),%a1
	addq.l   #2,%a0
	rts      

|###################################################
|# ea_indirect_A3                                  #
|###################################################
	.align	2
ea_indirect_A3:
	move.l   reg_a3(%a6),%a1
	addq.l   #2,%a0
	rts      

|###################################################
|# ea_indirect_A4                                  #
|###################################################
	.align	2
ea_indirect_A4:
	move.l   reg_a4(%a6),%a1
	addq.l   #2,%a0
	rts      

|###################################################
|# ea_indirect_A5                                  #
|###################################################
	.align	2
ea_indirect_A5:
	move.l   reg_a5(%a6),%a1
	addq.l   #2,%a0
	rts      

|###################################################
|# ea_indirect_A6                                  #
|###################################################
	.align	2
ea_indirect_A6:
	move.l   reg_a6(%a6),%a1
	addq.l   #2,%a0
	rts      

|###################################################
|# ea_indirect_A7                                  #
|###################################################
	.align	2
ea_indirect_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	addq.l   #2,%a0
	rts      

|###################################################
|# ea_displacement_A0                              #
|###################################################
	.align	2
ea_displacement_A0:
	movea.w  2(%a0),%a1
	add.l    reg_a0(%a6),%a1
	addq.l   #4,%a0
	rts      

|###################################################
|# ea_displacement_A1                              #
|###################################################
	.align	2
ea_displacement_A1:
	movea.w  2(%a0),%a1
	add.l    reg_a1(%a6),%a1
	addq.l   #4,%a0
	rts      

|###################################################
|# ea_displacement_A2                              #
|###################################################
	.align	2
ea_displacement_A2:
	movea.w  2(%a0),%a1
	add.l    reg_a2(%a6),%a1
	addq.l   #4,%a0
	rts      

|###################################################
|# ea_displacement_A3                              #
|###################################################
	.align	2
ea_displacement_A3:
	movea.w  2(%a0),%a1
	add.l    reg_a3(%a6),%a1
	addq.l   #4,%a0
	rts      

|###################################################
|# ea_displacement_A4                              #
|###################################################
	.align	2
ea_displacement_A4:
	movea.w  2(%a0),%a1
	add.l    reg_a4(%a6),%a1
	addq.l   #4,%a0
	rts      

|###################################################
|# ea_displacement_A5                              #
|###################################################
	.align	2
ea_displacement_A5:
	movea.w  2(%a0),%a1
	add.l    reg_a5(%a6),%a1
	addq.l   #4,%a0
	rts      

|###################################################
|# ea_displacement_A6                              #
|###################################################
	.align	2
ea_displacement_A6:
	movea.w  2(%a0),%a1
	add.l    reg_a6(%a6),%a1
	addq.l   #4,%a0
	rts      

|###################################################
|# ea_displacement_A7                              #
|###################################################
	.align	2
ea_displacement_A7:
	move.w   2(%a0),%d3
	ext.l    %d3
	bmi      illegal_a7_relative_fetch
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	adda.l   %d3,%a1
	addq.l   #4,%a0
	rts      

|###################################################
|# ea_indexed_A0                                   #
|###################################################
	.align	2
ea_indexed_A0:
	move.l   reg_a0(%a6),%a1
	move.w   2(%a0),%d3
	addq.l   #4,%a0
	bsr      calculate_indexed_address
	rts      

|###################################################
|# ea_indexed_A1                                   #
|###################################################
	.align	2
ea_indexed_A1:
	move.l   reg_a1(%a6),%a1
	move.w   2(%a0),%d3
	addq.l   #4,%a0
	bsr      calculate_indexed_address
	rts      

|###################################################
|# ea_indexed_A2                                   #
|###################################################
	.align	2
ea_indexed_A2:
	move.l   reg_a2(%a6),%a1
	move.w   2(%a0),%d3
	addq.l   #4,%a0
	bsr      calculate_indexed_address
	rts      

|###################################################
|# ea_indexed_A3                                   #
|###################################################
	.align	2
ea_indexed_A3:
	move.l   reg_a3(%a6),%a1
	move.w   2(%a0),%d3
	addq.l   #4,%a0
	bsr      calculate_indexed_address
	rts      

|###################################################
|# ea_indexed_A4                                   #
|###################################################
	.align	2
ea_indexed_A4:
	move.l   reg_a4(%a6),%a1
	move.w   2(%a0),%d3
	addq.l   #4,%a0
	bsr      calculate_indexed_address
	rts      

|###################################################
|# ea_indexed_A5                                   #
|###################################################
	.align	2
ea_indexed_A5:
	move.l   reg_a5(%a6),%a1
	move.w   2(%a0),%d3
	addq.l   #4,%a0
	bsr      calculate_indexed_address
	rts      

|###################################################
|# ea_indexed_A6                                   #
|###################################################
	.align	2
ea_indexed_A6:
	move.l   reg_a6(%a6),%a1
	move.w   2(%a0),%d3
	addq.l   #4,%a0
	bsr      calculate_indexed_address
	rts      

|###################################################
|# ea_indexed_A7                                   #
|###################################################
	.align	2
ea_indexed_A7:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a1
	move.w   2(%a0),%d3
	addq.l   #4,%a0
	bsr      calculate_indexed_address
	rts      

|###################################################
|# ea_absolute_word                                #
|###################################################
	.align	2
ea_absolute_word:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	rts      

|###################################################
|# ea_absolute_long                                #
|###################################################
	.align	2
ea_absolute_long:
	movea.l  2(%a0),%a1
	addq.l   #6,%a0
	rts      

|###################################################
|# ea_displacement_PC                              #
|###################################################
	.align	2
ea_displacement_PC:
	movea.w  2(%a0),%a1
	addq.l   #4,%a0
	add.l    %a0,%a1
	subq.l   #2,%a1
	rts      

|###################################################
|# ea_indexed_PC                                   #
|###################################################
	.align	2
ea_indexed_PC:
	lea      2(%a0),%a1
	move.w   (%a1),%d3
	addq.l   #4,%a0
	bsr      calculate_indexed_address
	rts      

|###################################################
|# memory_indirect_68020_0x10                      #
|###################################################
	.align	2
memory_indirect_68020_0x10:
i_is_0x0:
	adda.l   %a2,%a1
	rts      

|###################################################
|# memory_indirect_68020_0x11                      #
|###################################################
	.align	2
memory_indirect_68020_0x11:
i_is_0x1:
	adda.l   %a2,%a1
	move.l   (%a1),%a1
	rts      

|###################################################
|# memory_indirect_68020_0x12                      #
|###################################################
	.align	2
memory_indirect_68020_0x12:
i_is_0x2:
	adda.l   %a2,%a1
	movea.l  (%a1),%a1
	movea.w  (%a0)+,%a2
	adda.l   %a2,%a1
	rts      

|###################################################
|# memory_indirect_68020_0x13                      #
|###################################################
	.align	2
memory_indirect_68020_0x13:
i_is_0x3:
	adda.l   %a2,%a1
	movea.l  (%a1),%a1
	adda.l   (%a0)+,%a1
	rts      

|###################################################
|# memory_indirect_68020_0x15                      #
|###################################################
	.align	2
memory_indirect_68020_0x15:
i_is_0x5:
	move.l   (%a1),%a1
	adda.l   %a2,%a1
	rts      

|###################################################
|# memory_indirect_68020_0x16                      #
|###################################################
	.align	2
memory_indirect_68020_0x16:
i_is_0x6:
	movea.l  (%a1),%a1
	adda.l   %a2,%a1
	movea.w  (%a0)+,%a2
	adda.l   %a2,%a1
	rts      

|###################################################
|# memory_indirect_68020_0x17                      #
|###################################################
	.align	2
memory_indirect_68020_0x17:
i_is_0x7:
	movea.l  (%a1),%a1
	adda.l   %a2,%a1
	adda.l   (%a0)+,%a1
	rts      

|###################################################
|# memory_indirect_68020_0x20                      #
|###################################################
	.align	2
memory_indirect_68020_0x20:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x0

|###################################################
|# memory_indirect_68020_0x21                      #
|###################################################
	.align	2
memory_indirect_68020_0x21:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x1

|###################################################
|# memory_indirect_68020_0x22                      #
|###################################################
	.align	2
memory_indirect_68020_0x22:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x2

|###################################################
|# memory_indirect_68020_0x23                      #
|###################################################
	.align	2
memory_indirect_68020_0x23:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x3

|###################################################
|# memory_indirect_68020_0x25                      #
|###################################################
	.align	2
memory_indirect_68020_0x25:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x5

|###################################################
|# memory_indirect_68020_0x26                      #
|###################################################
	.align	2
memory_indirect_68020_0x26:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x6

|###################################################
|# memory_indirect_68020_0x27                      #
|###################################################
	.align	2
memory_indirect_68020_0x27:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x7

|###################################################
|# memory_indirect_68020_0x30                      #
|###################################################
	.align	2
memory_indirect_68020_0x30:
	adda.l   (%a0)+,%a1
	bra      i_is_0x0

|###################################################
|# memory_indirect_68020_0x31                      #
|###################################################
	.align	2
memory_indirect_68020_0x31:
	adda.l   (%a0)+,%a1
	bra      i_is_0x1

|###################################################
|# memory_indirect_68020_0x32                      #
|###################################################
	.align	2
memory_indirect_68020_0x32:
	adda.l   (%a0)+,%a1
	bra      i_is_0x2

|###################################################
|# memory_indirect_68020_0x33                      #
|###################################################
	.align	2
memory_indirect_68020_0x33:
	adda.l   (%a0)+,%a1
	bra      i_is_0x3

|###################################################
|# memory_indirect_68020_0x35                      #
|###################################################
	.align	2
memory_indirect_68020_0x35:
	adda.l   (%a0)+,%a1
	bra      i_is_0x5

|###################################################
|# memory_indirect_68020_0x36                      #
|###################################################
	.align	2
memory_indirect_68020_0x36:
	adda.l   (%a0)+,%a1
	bra      i_is_0x6

|###################################################
|# memory_indirect_68020_0x37                      #
|###################################################
	.align	2
memory_indirect_68020_0x37:
	adda.l   (%a0)+,%a1
	bra      i_is_0x7

|###################################################
|# memory_indirect_68020_0x50                      #
|###################################################
	.align	2
memory_indirect_68020_0x50:
i_is_0x8:
	rts      

|###################################################
|# memory_indirect_68020_0x51                      #
|###################################################
	.align	2
memory_indirect_68020_0x51:
i_is_0x9:
	movea.l  (%a1),%a1
	rts      

|###################################################
|# memory_indirect_68020_0x52                      #
|###################################################
	.align	2
memory_indirect_68020_0x52:
i_is_0xa:
	movea.l  (%a1),%a1
	movea.w  (%a0)+,%a2
	adda.l   %a2,%a1
	rts      

|###################################################
|# memory_indirect_68020_0x53                      #
|###################################################
	.align	2
memory_indirect_68020_0x53:
i_is_0xb:
	movea.l  (%a1),%a1
	adda.l   (%a0)+,%a1
	rts      

|###################################################
|# memory_indirect_68020_0x60                      #
|###################################################
	.align	2
memory_indirect_68020_0x60:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x8

|###################################################
|# memory_indirect_68020_0x61                      #
|###################################################
	.align	2
memory_indirect_68020_0x61:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x9

|###################################################
|# memory_indirect_68020_0x62                      #
|###################################################
	.align	2
memory_indirect_68020_0x62:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0xa

|###################################################
|# memory_indirect_68020_0x63                      #
|###################################################
	.align	2
memory_indirect_68020_0x63:
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0xb

|###################################################
|# memory_indirect_68020_0x70                      #
|###################################################
	.align	2
memory_indirect_68020_0x70:
	adda.l   (%a0)+,%a1
	bra      i_is_0x8

|###################################################
|# memory_indirect_68020_0x71                      #
|###################################################
	.align	2
memory_indirect_68020_0x71:
	adda.l   (%a0)+,%a1
	bra      i_is_0x9

|###################################################
|# memory_indirect_68020_0x72                      #
|###################################################
	.align	2
memory_indirect_68020_0x72:
	adda.l   (%a0)+,%a1
	bra      i_is_0xa

|###################################################
|# memory_indirect_68020_0x73                      #
|###################################################
	.align	2
memory_indirect_68020_0x73:
	adda.l   (%a0)+,%a1
	bra      i_is_0xb

|###################################################
|# memory_indirect_68020_0x90                      #
|###################################################
	.align	2
memory_indirect_68020_0x90:
	sub.l    %a1,%a1
	bra      i_is_0x0

|###################################################
|# memory_indirect_68020_0x91                      #
|###################################################
	.align	2
memory_indirect_68020_0x91:
	sub.l    %a1,%a1
	bra      i_is_0x1

|###################################################
|# memory_indirect_68020_0x92                      #
|###################################################
	.align	2
memory_indirect_68020_0x92:
	sub.l    %a1,%a1
	bra      i_is_0x2

|###################################################
|# memory_indirect_68020_0x93                      #
|###################################################
	.align	2
memory_indirect_68020_0x93:
	sub.l    %a1,%a1
	bra      i_is_0x3

|###################################################
|# memory_indirect_68020_0x95                      #
|###################################################
	.align	2
memory_indirect_68020_0x95:
	sub.l    %a1,%a1
	bra      i_is_0x5

|###################################################
|# memory_indirect_68020_0x96                      #
|###################################################
	.align	2
memory_indirect_68020_0x96:
	sub.l    %a1,%a1
	bra      i_is_0x6

|###################################################
|# memory_indirect_68020_0x97                      #
|###################################################
	.align	2
memory_indirect_68020_0x97:
	sub.l    %a1,%a1
	bra      i_is_0x7

|###################################################
|# memory_indirect_68020_0xa0                      #
|###################################################
	.align	2
memory_indirect_68020_0xa0:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x0

|###################################################
|# memory_indirect_68020_0xa1                      #
|###################################################
	.align	2
memory_indirect_68020_0xa1:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x1

|###################################################
|# memory_indirect_68020_0xa2                      #
|###################################################
	.align	2
memory_indirect_68020_0xa2:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x2

|###################################################
|# memory_indirect_68020_0xa3                      #
|###################################################
	.align	2
memory_indirect_68020_0xa3:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x3

|###################################################
|# memory_indirect_68020_0xa5                      #
|###################################################
	.align	2
memory_indirect_68020_0xa5:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x5

|###################################################
|# memory_indirect_68020_0xa6                      #
|###################################################
	.align	2
memory_indirect_68020_0xa6:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x6

|###################################################
|# memory_indirect_68020_0xa7                      #
|###################################################
	.align	2
memory_indirect_68020_0xa7:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x7

|###################################################
|# memory_indirect_68020_0xb0                      #
|###################################################
	.align	2
memory_indirect_68020_0xb0:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0x0

|###################################################
|# memory_indirect_68020_0xb1                      #
|###################################################
	.align	2
memory_indirect_68020_0xb1:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0x1

|###################################################
|# memory_indirect_68020_0xb2                      #
|###################################################
	.align	2
memory_indirect_68020_0xb2:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0x2

|###################################################
|# memory_indirect_68020_0xb3                      #
|###################################################
	.align	2
memory_indirect_68020_0xb3:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0x3

|###################################################
|# memory_indirect_68020_0xb5                      #
|###################################################
	.align	2
memory_indirect_68020_0xb5:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0x5

|###################################################
|# memory_indirect_68020_0xb6                      #
|###################################################
	.align	2
memory_indirect_68020_0xb6:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0x6

|###################################################
|# memory_indirect_68020_0xb7                      #
|###################################################
	.align	2
memory_indirect_68020_0xb7:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0x7

|###################################################
|# memory_indirect_68020_0xd0                      #
|###################################################
	.align	2
memory_indirect_68020_0xd0:
	sub.l    %a1,%a1
	bra      i_is_0x8

|###################################################
|# memory_indirect_68020_0xd1                      #
|###################################################
	.align	2
memory_indirect_68020_0xd1:
	sub.l    %a1,%a1
	bra      i_is_0x9

|###################################################
|# memory_indirect_68020_0xd2                      #
|###################################################
	.align	2
memory_indirect_68020_0xd2:
	sub.l    %a1,%a1
	bra      i_is_0xa

|###################################################
|# memory_indirect_68020_0xd3                      #
|###################################################
	.align	2
memory_indirect_68020_0xd3:
	sub.l    %a1,%a1
	bra      i_is_0xb

|###################################################
|# memory_indirect_68020_0xe0                      #
|###################################################
	.align	2
memory_indirect_68020_0xe0:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x8

|###################################################
|# memory_indirect_68020_0xe1                      #
|###################################################
	.align	2
memory_indirect_68020_0xe1:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0x9

|###################################################
|# memory_indirect_68020_0xe2                      #
|###################################################
	.align	2
memory_indirect_68020_0xe2:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0xa

|###################################################
|# memory_indirect_68020_0xe3                      #
|###################################################
	.align	2
memory_indirect_68020_0xe3:
	sub.l    %a1,%a1
	.short	0x7758                  // mvs.w    (%a0)+,%d3
	adda.l   %d3,%a1
	bra      i_is_0xb

|###################################################
|# memory_indirect_68020_0xf0                      #
|###################################################
	.align	2
memory_indirect_68020_0xf0:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0x8

|###################################################
|# memory_indirect_68020_0xf1                      #
|###################################################
	.align	2
memory_indirect_68020_0xf1:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0x9

|###################################################
|# memory_indirect_68020_0xf2                      #
|###################################################
	.align	2
memory_indirect_68020_0xf2:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0xa

|###################################################
|# memory_indirect_68020_0xf3                      #
|###################################################
	.align	2
memory_indirect_68020_0xf3:
	sub.l    %a1,%a1
	adda.l   (%a0)+,%a1
	bra      i_is_0xb

|#########################################################################
|# Equates for BCD Tables                                                #
|#########################################################################
	.set	_PA_BCDBIN,          -128
	.set	_PA_BINBCD,          32

	.set	_PA_BFEA,            0
	.set	_PA_BFOFFSET,        4
	.set	_PA_BFWIDTH,         8
	.set	_PA_BFMASK,          12
	.set	_PA_BFLEFT_PAD,      16
	.set	_PA_BFRIGHT_PAD,     20
	.set	_PA_BFREAD_VALUE,    24
	.set	_PA_BFWRITE_VALUE,   28
	.set	_PA_BFSTRUCT_SIZE,   32


|###################################################
|# Bitfield Support Routines                       #
|###################################################


	.globl	_PA_read_bitfield
_PA_read_bitfield:         
	lea      -20(%a7),%a7
	movem.l  %d0/%d1/%d2/%d3/%a0,(%a7)
	move.l   24+_PA_BFEA(%a7),%a0
	move.l   24+_PA_BFOFFSET(%a7),%d0
	move.l   %d0,%d1
	asr.l    #3,%d0
	and.l    #7,%d1
	add.l    %d0,%a0
	move.l   %a0,24+_PA_BFEA(%a7)
	moveq    #32,%d0
	move.l   24+_PA_BFWIDTH(%a7),%d3
	and.l    #31,%d3
	bne.s    _PA_r_bf1
	moveq    #32,%d3
_PA_r_bf1:         
	sub.l    %d3,%d0
	move.l   %d3,24+_PA_BFWIDTH(%a7)
	moveq    #-1,%d3
	lsl.l    %d0,%d3
	move.l   %d3,24+_PA_BFMASK(%a7)
	move.l   %d1,24+_PA_BFLEFT_PAD(%a7)
	move.l   %d0,24+_PA_BFRIGHT_PAD(%a7)
	move.l   (%a0),%d2
	lsl.l    %d1,%d2
	sub.l    %d1,%d0
	bge.s    _PA_r_bf2
	clr.l    %d0
	move.b   4(%a0),%d0
	lsl.l    %d1,%d0
	lsr.l    #8,%d0
	or.l     %d0,%d2
_PA_r_bf2:         
	and.l    %d3,%d2
	clr.l    24+_PA_BFWRITE_VALUE(%a7)
	move.l   %d2,24+_PA_BFREAD_VALUE(%a7)
	movem.l  (%a7),%d0/%d1/%d2/%d3/%a0
	lea      20(%a7),%a7
	rts      


	.globl	_PA_write_bitfield
_PA_write_bitfield:         
	lea      -20(%a7),%a7
	movem.l  %d0/%d1/%d2/%d3/%a0,(%a7)
	move.l   24+_PA_BFEA(%a7),%a0
	move.l   24+_PA_BFLEFT_PAD(%a7),%d1
	move.l   24+_PA_BFMASK(%a7),%d3
	move.l   24+_PA_BFWRITE_VALUE(%a7),%d2
	and.l    %d3,%d2
	moveq    #32,%d0
	sub.l    %d1,%d0
	sub.l    24+_PA_BFWIDTH(%a7),%d0
	bge.s    _PA_w_bf1
	lsl.l    #8,%d3
	lsr.l    %d1,%d3
	not.l    %d3
	lsl.l    #8,%d2
	lsr.l    %d1,%d2
	move.b   4(%a0),%d0
	and.l    %d3,%d0
	or.l     %d2,%d0
	move.b   %d0,4(%a0)
	move.l   24+_PA_BFMASK(%a7),%d3
	move.l   24+_PA_BFWRITE_VALUE(%a7),%d2
	and.l    %d3,%d2
_PA_w_bf1:         
	lsr.l    %d1,%d2
	lsr.l    %d1,%d3
	not.l    %d3
	move.l   (%a0),%d0
	and.l    %d3,%d0
	or.l     %d2,%d0
	move.l   %d0,(%a0)
	tst.l    24+_PA_BFREAD_VALUE(%a7)
	movem.l  (%a7),%d0/%d1/%d2/%d3/%a0
	lea      20(%a7),%a7
	rts      


	.globl	_PA_search_bitfield
_PA_search_bitfield:         
	lea      -20(%a7),%a7
	movem.l  %d0/%d1/%d2,(%a7)
	move.l   24+_PA_BFWIDTH(%a7),%d1
	move.l   24+_PA_BFOFFSET(%a7),%d2
	move.l   24+_PA_BFREAD_VALUE(%a7),%d0
	bmi.s    _PA_s_bf2
_PA_s_bf1:         
	addq.l   #1,%d2
	subq.l   #1,%d1
	ble.s    _PA_s_bf2
	lsl.l    #1,%d0
	bpl.s    _PA_s_bf1
_PA_s_bf2:         
	move.l   %d2,24+_PA_BFWRITE_VALUE(%a7)
	movem.l  (%a7),%d0/%d1/%d2
	lea      20(%a7),%a7
	rts      




|###################################################
|# Software Multiply Routines                      #
|###################################################


	.globl	_PA_mulu32
_PA_mulu32:         
	lea      -20(%a7),%a7
	movem.l  %d0/%d1/%d2/%d4,(%a7)
	move     %ccr,%d4
	move.l   24+0(%a7),%d1
	move.l   24+4(%a7),%d2
	bsr      _PA_mul_common
	move.l   %d0,24+0(%a7)
	move.l   %d1,24+4(%a7)
	move     %d4,%ccr
	movem.l  (%a7),%d0/%d1/%d2/%d4
	lea      20(%a7),%a7
	rts      


	.globl	_PA_muls32
_PA_muls32:         
	lea      -20(%a7),%a7
	movem.l  %d0/%d1/%d2/%d3/%d4,(%a7)
	move     %ccr,%d4
	move.l   24+0(%a7),%d1
	bpl.s    _PA_muls32_1
	neg.l    %d1
	bset     #15,%d4
_PA_muls32_1:         
	move.l   24+4(%a7),%d2
	bpl.s    _PA_muls32_2
	neg.l    %d2
	bchg     #15,%d4
_PA_muls32_2:         
	bsr      _PA_mul_common
	btst     #15,%d4
	beq.s    _PA_muls32_3
	neg.l    %d1
	negx.l   %d0
_PA_muls32_3:         
	move.l   %d0,24+0(%a7)
	move.l   %d1,24+4(%a7)
	move     %d4,%ccr
	movem.l  (%a7),%d0/%d1/%d2/%d3/%d4
	lea      20(%a7),%a7
	rts      


_PA_mul_common:         
	move.l   %d1,%d0
	or.l     %d2,%d0
	cmp.l    #32768,%d0
	bcs.s    _PA_mul_quick
	move.w   %d1,%d0
	mulu.w   %d2,%d0
	move.l   %d0,-(%a7)
	clr.w    -(%a7)
	move.l   %d1,%d0
	swap     %d0
	mulu.w   %d2,%d0
	add.l    %d0,(%a7)
	move.w   %d1,%d0
	swap     %d2
	mulu.w   %d2,%d0
	clr.w    -(%a7)
	add.l    %d0,2(%a7)
	bcc.s    _PA_mul_2
	move.w   #1,(%a7)
_PA_mul_2:         
	swap     %d1
	mulu.w   %d2,%d1
	add.l    %d1,(%a7)
	move.l   (%a7)+,%d0
	move.l   (%a7)+,%d1
	rts      
_PA_mul_quick:         
	clr.l    %d0
	mulu.w   %d2,%d1
	rts      




|###################################################
|# Software Divide Routines                        #
|###################################################


	.globl	_PA_divu64
_PA_divu64:         
	lea      -24(%a7),%a7
	movem.l  %d0/%d1/%d2/%d3/%d4/%d5,(%a7)
	move     %ccr,%d4
	move.l   28+0(%a7),%d2
	beq      _PA_divide_by_zero
	move.l   28+4(%a7),%d0
	move.l   28+8(%a7),%d5
	bsr      _PA_div64_common
	tst.l    %d0
	beq.s    _PA_divu64_ok
	bset     #1,%d4
_PA_divu64_ok:         
	move.l   %d5,28+4(%a7)
	move.l   %d1,28+0(%a7)
	move     %d4,%ccr
	movem.l  (%a7),%d0/%d1/%d2/%d3/%d4/%d5
	lea      24(%a7),%a7
	rts      


	.globl	_PA_divs64
_PA_divs64:         
	lea      -24(%a7),%a7
	movem.l  %d0/%d1/%d2/%d3/%d4/%d5,(%a7)
	move     %ccr,%d4
	move.l   28+0(%a7),%d2
	beq      _PA_divide_by_zero
	bpl.s    _PA_divs64_1
	bset     #15,%d4
	neg.l    %d2
	move.l   28+8(%a7),%d5
	move.l   28+4(%a7),%d0
	bpl.s    _PA_divs64_2
	bset     #14,%d4
	neg.l    %d5
	negx.l   %d0
	bclr     #15,%d4
	bra.s    _PA_divs64_2
_PA_divs64_1:         
	move.l   28+8(%a7),%d5
	move.l   28+4(%a7),%d0
	bpl.s    _PA_divs64_2
	bset     #15,%d4
	bset     #14,%d4
	neg.l    %d5
	negx.l   %d0
_PA_divs64_2:         
	bsr      _PA_div64_common
	tst.l    %d0
	bne.s    _PA_divs64_oflow
	btst     #15,%d4
	beq.s    _PA_divs64_3
	cmp.l    #0x80000000,%d5
	bhi.s    _PA_divs64_oflow
	neg.l    %d5
	bra.s    _PA_divs64_4
_PA_divs64_3:         
	cmp.l    #0x7fffffff,%d5
	bhi.s    _PA_divs64_oflow
_PA_divs64_4:         
	btst     #14,%d4
	beq.s    _PA_divs64_end
	neg.l    %d1
	bra.s    _PA_divs64_end
_PA_divs64_oflow:         
	bset     #1,%d4
_PA_divs64_end:         
	move.l   %d5,28+4(%a7)
	move.l   %d1,28+0(%a7)
	move     %d4,%ccr
	movem.l  (%a7),%d0/%d1/%d2/%d3/%d4/%d5
	lea      24(%a7),%a7
	rts      


_PA_div64_common:         
	moveq    #64,%d3
	clr.l    %d1
_PA_div64_1:         
	add.l    %d5,%d5
	addx.l   %d0,%d0
	addx.l   %d1,%d1
	bcs.s    _PA_div64_3
	cmp.l    %d2,%d1
	bcs.s    _PA_div64_2
	sub.l    %d2,%d1
	addq.l   #1,%d5
	bcc.s    _PA_div64_2
	addq.l   #1,%d0
_PA_div64_2:         
	subq.l   #1,%d3
	bne.s    _PA_div64_1
	rts      
_PA_div64_3:         
	sub.l    %d2,%d1
	addq.l   #1,%d5
	subq.l   #1,%d3
	bne.s    _PA_div64_1
	rts      


_PA_divide_by_zero:         
	jmp      handle_divide_by_zero_exception



|#########################################################################
|# Individual Instruction Handlers                                       #
|#########################################################################

|###################################################
|# or_immediate_byte                               #
|###################################################
	.align	1
second_level_dispatch_0:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      or_immediate_byte
	cmpi.l   #0x10,%d4
	bcs      illegal_0
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_0
or_immediate_byte:
	move.b   3(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_byte
	or.l     %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
dispatch_second_others_0:
	cmpi.l   #0x3c,%d4
	bcs      illegal_0
	cmpi.l   #0x3d,%d4
	bcs      ori_to_CCR
illegal_0:
	jmp      illegal

|###################################################
|# ori_to_CCR                                      #
|###################################################
	.align	1
ori_to_CCR:
	move.b   3(%a0),%d1
	addq.l   #2,%a0
	move.b   reg_XNZVC(%a6),%d2
	or.l     %d1,%d2
	addq.l   #2,%a0
	move.w   %d2,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# ori_to_SR                                       #
|###################################################
	.align	1
ori_to_SR:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1542
	jmp      handle_privilege_violation_exception
priv_ok_1542:
	addq.l   #2,%a0
	move.w   (%a0)+,%d1
	move.w   (reg_sr,%a6),%d0
	or.l     %d1,%d0
	bra      _store_SR

|###################################################
|# or_immediate_word                               #
|###################################################
	.align	1
second_level_dispatch_1:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      or_immediate_word
	cmpi.l   #0x10,%d4
	bcs      illegal_1
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_1
or_immediate_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_word
	or.l     %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
dispatch_second_others_1:
	cmpi.l   #0x3c,%d4
	bcs      illegal_1
	cmpi.l   #0x3d,%d4
	bcs      ori_to_SR
illegal_1:
	jmp      illegal

|###################################################
|# or_immediate_long                               #
|###################################################
	.align	1
or_immediate_long:
	move.l   2(%a0),%d1
	addq.l   #4,%a0
	bsr      read_then_write_operand_long
	or.l     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# chk2_and_cmp2                                   #
|###################################################
	.align	1
chk2_and_cmp2:
	move.l   (%a0),-(%a7)
	addq.l   #2,%a0
	bsr      calculate_effective_address
	move.l   %a1,-(%a7)
	subq.l   #2,%a0
	move.l   4(%a7),%d5
	lsr.l    #8,%d5
	lsr.l    #4,%d5
	and.l    #15,%d5
	bsr      read_operand_long
	move.l   (%a7)+,%a1
	move.l   (%a7)+,%d1
	btst     #26,%d1
	bne.s    cxx2_long
	btst     #25,%d1
	bne.s    cxx2_word
cxx2_byte:
	move.b   (0,%a1),%d2
	extb.l   %d2
	move.b   (1,%a1),%d3
	extb.l   %d3
	btst     #15,%d1
	bne.s    cxx2_common
	extb.l   %d0
	bra.s    cxx2_common
cxx2_word:
	move.w   (0,%a1),%d2
	ext.l    %d2
	move.w   (2,%a1),%d3
	ext.l    %d3
	btst     #15,%d1
	bne.s    cxx2_common
	ext.l    %d0
	bra.s    cxx2_common
cxx2_long:
	move.l   (0,%a1),%d2
	move.l   (4,%a1),%d3
cxx2_common:
	cmp.l    %d3,%d2
	bgt      cxx2_logical
cxx2_arithmetic:
	cmp.l    %d2,%d0
	blt.s    cxx2_out_of_bounds
	beq.s    cxx2_matches_bound
	cmp.l    %d3,%d0
	bgt.s    cxx2_out_of_bounds
	beq.s    cxx2_matches_bound
	bra.s    cxx2_in_bounds
cxx2_logical:
	cmp.l    %d3,%d0
	bcs.s    cxx2_out_of_bounds
	beq.s    cxx2_matches_bound
	cmp.l    %d2,%d0
	bhi.s    cxx2_out_of_bounds
	beq.s    cxx2_matches_bound
	bra.s    cxx2_in_bounds
cxx2_out_of_bounds:
	moveq.l  #0,%d2
	btst     #11,%d1
	beq.s    cxx2_done
	move.l   %a0,reg_pc(%a6)
	move.b   reg_XNZVC(%a6),%d1
	and.l    #0x10,%d1
	or.l     #0x1,%d1
	move.b   %d1,reg_XNZVC(%a6)
	moveq.l  #6,%d1
	jmp      handle_680x0_exception
cxx2_matches_bound:
	moveq.l  #1,%d2
	bra.s    cxx2_done
cxx2_in_bounds:
	moveq.l  #2,%d2
cxx2_done:
	cmp.l    #1,%d2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movep_from_memory_word                          #
|###################################################
	.align	1
movep_from_memory_word:
	move.l   %d5,%d1
	and.l    #0x7,%d5
	ori.l    #0x28,%d5
	bsr      calculate_effective_address
	move.b   (0,%a1),%d0
	lsl.l    #8,%d0
	move.b   (2,%a1),%d0
	moveq.l  #0x0,%d6
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bra      store_operand_word

|###################################################
|# btst_D0_ea                                      #
|###################################################
	.align	1
btst_D0_ea:
	move.l   reg_d0(%a6),%d1
	bsr      calculate_effective_address
	btst     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# btst_D0_Dn                                      #
|###################################################
	.align	1
btst_D0_Dn:
	move.l   reg_d0(%a6),%d1
	bsr      read_operand_long
	btst     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled
second_level_dispatch_4:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      btst_D0_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_word
	cmpi.l   #0x3a,%d4
	bcs      btst_D0_ea
illegal_2:
	jmp      illegal

|###################################################
|# movep_from_memory_long                          #
|###################################################
	.align	1
movep_from_memory_long:
	move.l   %d5,%d1
	and.l    #0x7,%d5
	ori.l    #0x28,%d5
	bsr      calculate_effective_address
	move.b   (0,%a1),%d0
	lsl.l    #8,%d0
	move.b   (2,%a1),%d0
	lsl.l    #8,%d0
	move.b   (4,%a1),%d0
	lsl.l    #8,%d0
	move.b   (6,%a1),%d0
	moveq.l  #0x0,%d6
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bra      store_operand_long

|###################################################
|# bchg_D0_ea                                      #
|###################################################
	.align	1
bchg_D0_ea:
	move.l   reg_d0(%a6),%d1
	bsr      calculate_effective_address
	bchg     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bchg_D0_Dn                                      #
|###################################################
	.align	1
bchg_D0_Dn:
	move.l   reg_d0(%a6),%d1
	bsr      read_then_write_operand_long
	bchg     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_5:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bchg_D0_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bchg_D0_ea
illegal_3:
	jmp      illegal

|###################################################
|# movep_to_memory_word                            #
|###################################################
	.align	1
movep_to_memory_word:
	move.l   %d5,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	bsr      read_operand_word
	move.l   %d1,%d5
	move.l   %d0,%d2
	subq.l   #2,%a0
	and.l    #0x7,%d5
	ori.l    #0x28,%d5
	bsr      calculate_effective_address
	move.l   %d2,%d1
	lsr.l    #8,%d1
	move.b   %d1,(0,%a1)
	move.b   %d2,(2,%a1)
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# bclr_D0_ea                                      #
|###################################################
	.align	1
bclr_D0_ea:
	move.l   reg_d0(%a6),%d1
	bsr      calculate_effective_address
	bclr     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bclr_D0_Dn                                      #
|###################################################
	.align	1
bclr_D0_Dn:
	move.l   reg_d0(%a6),%d1
	bsr      read_then_write_operand_long
	bclr     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_6:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bclr_D0_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_word
	cmpi.l   #0x3a,%d4
	bcs      bclr_D0_ea
illegal_4:
	jmp      illegal

|###################################################
|# movep_to_memory_long                            #
|###################################################
	.align	1
movep_to_memory_long:
	move.l   %d5,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	bsr      read_operand_long
	move.l   %d1,%d5
	move.l   %d0,%d2
	subq.l   #2,%a0
	and.l    #0x7,%d5
	ori.l    #0x28,%d5
	bsr      calculate_effective_address
	swap     %d2
	move.l   %d2,%d1
	lsr.l    #8,%d1
	move.b   %d1,(0,%a1)
	move.b   %d2,(2,%a1)
	swap     %d1
	move.b   %d1,(4,%a1)
	swap     %d2
	move.b   %d2,(6,%a1)
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# bset_D0_ea                                      #
|###################################################
	.align	1
bset_D0_ea:
	move.l   reg_d0(%a6),%d1
	bsr      calculate_effective_address
	bset     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bset_D0_Dn                                      #
|###################################################
	.align	1
bset_D0_Dn:
	move.l   reg_d0(%a6),%d1
	bsr      read_then_write_operand_long
	bset     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_7:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bset_D0_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bset_D0_ea
illegal_5:
	jmp      illegal

|###################################################
|# and_immediate_byte                              #
|###################################################
	.align	1
second_level_dispatch_8:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      and_immediate_byte
	cmpi.l   #0x10,%d4
	bcs      illegal_6
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_8
and_immediate_byte:
	move.b   3(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_byte
	and.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
dispatch_second_others_8:
	cmpi.l   #0x3c,%d4
	bcs      illegal_6
	cmpi.l   #0x3d,%d4
	bcs      andi_to_CCR
illegal_6:
	jmp      illegal

|###################################################
|# andi_to_CCR                                     #
|###################################################
	.align	1
andi_to_CCR:
	move.b   3(%a0),%d1
	addq.l   #2,%a0
	move.b   reg_XNZVC(%a6),%d2
	and.l    %d1,%d2
	addq.l   #2,%a0
	move.w   %d2,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# andi_to_SR                                      #
|###################################################
	.align	1
andi_to_SR:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1540
	jmp      handle_privilege_violation_exception
priv_ok_1540:
	addq.l   #2,%a0
	move.w   (%a0)+,%d1
	move.w   (reg_sr,%a6),%d0
	and.l    %d1,%d0
	bra      _store_SR

|###################################################
|# and_immediate_word                              #
|###################################################
	.align	1
second_level_dispatch_9:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      and_immediate_word
	cmpi.l   #0x10,%d4
	bcs      illegal_7
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_9
and_immediate_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_word
	and.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
dispatch_second_others_9:
	cmpi.l   #0x3c,%d4
	bcs      illegal_7
	cmpi.l   #0x3d,%d4
	bcs      andi_to_SR
illegal_7:
	jmp      illegal

|###################################################
|# and_immediate_long                              #
|###################################################
	.align	1
and_immediate_long:
	move.l   2(%a0),%d1
	addq.l   #4,%a0
	bsr      read_then_write_operand_long
	and.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# btst_D1_ea                                      #
|###################################################
	.align	1
btst_D1_ea:
	move.l   reg_d1(%a6),%d1
	bsr      calculate_effective_address
	btst     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# btst_D1_Dn                                      #
|###################################################
	.align	1
btst_D1_Dn:
	move.l   reg_d1(%a6),%d1
	bsr      read_operand_long
	btst     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled
second_level_dispatch_12:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      btst_D1_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_word
	cmpi.l   #0x3a,%d4
	bcs      btst_D1_ea
illegal_8:
	jmp      illegal

|###################################################
|# bchg_D1_ea                                      #
|###################################################
	.align	1
bchg_D1_ea:
	move.l   reg_d1(%a6),%d1
	bsr      calculate_effective_address
	bchg     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bchg_D1_Dn                                      #
|###################################################
	.align	1
bchg_D1_Dn:
	move.l   reg_d1(%a6),%d1
	bsr      read_then_write_operand_long
	bchg     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_13:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bchg_D1_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bchg_D1_ea
illegal_9:
	jmp      illegal

|###################################################
|# bclr_D1_ea                                      #
|###################################################
	.align	1
bclr_D1_ea:
	move.l   reg_d1(%a6),%d1
	bsr      calculate_effective_address
	bclr     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bclr_D1_Dn                                      #
|###################################################
	.align	1
bclr_D1_Dn:
	move.l   reg_d1(%a6),%d1
	bsr      read_then_write_operand_long
	bclr     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_14:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bclr_D1_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_word
	cmpi.l   #0x3a,%d4
	bcs      bclr_D1_ea
illegal_10:
	jmp      illegal

|###################################################
|# bset_D1_ea                                      #
|###################################################
	.align	1
bset_D1_ea:
	move.l   reg_d1(%a6),%d1
	bsr      calculate_effective_address
	bset     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bset_D1_Dn                                      #
|###################################################
	.align	1
bset_D1_Dn:
	move.l   reg_d1(%a6),%d1
	bsr      read_then_write_operand_long
	bset     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_15:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bset_D1_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bset_D1_ea
illegal_11:
	jmp      illegal

|###################################################
|# sub_immediate_byte                              #
|###################################################
	.align	1
sub_immediate_byte:
	move.b   3(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# sub_immediate_word                              #
|###################################################
	.align	1
sub_immediate_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# sub_immediate_long                              #
|###################################################
	.align	1
sub_immediate_long:
	move.l   2(%a0),%d1
	addq.l   #4,%a0
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# btst_D2_ea                                      #
|###################################################
	.align	1
btst_D2_ea:
	move.l   reg_d2(%a6),%d1
	bsr      calculate_effective_address
	btst     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# btst_D2_Dn                                      #
|###################################################
	.align	1
btst_D2_Dn:
	move.l   reg_d2(%a6),%d1
	bsr      read_operand_long
	btst     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled
second_level_dispatch_20:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      btst_D2_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_word
	cmpi.l   #0x3a,%d4
	bcs      btst_D2_ea
illegal_12:
	jmp      illegal

|###################################################
|# bchg_D2_ea                                      #
|###################################################
	.align	1
bchg_D2_ea:
	move.l   reg_d2(%a6),%d1
	bsr      calculate_effective_address
	bchg     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bchg_D2_Dn                                      #
|###################################################
	.align	1
bchg_D2_Dn:
	move.l   reg_d2(%a6),%d1
	bsr      read_then_write_operand_long
	bchg     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_21:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bchg_D2_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bchg_D2_ea
illegal_13:
	jmp      illegal

|###################################################
|# bclr_D2_ea                                      #
|###################################################
	.align	1
bclr_D2_ea:
	move.l   reg_d2(%a6),%d1
	bsr      calculate_effective_address
	bclr     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bclr_D2_Dn                                      #
|###################################################
	.align	1
bclr_D2_Dn:
	move.l   reg_d2(%a6),%d1
	bsr      read_then_write_operand_long
	bclr     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_22:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bclr_D2_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_word
	cmpi.l   #0x3a,%d4
	bcs      bclr_D2_ea
illegal_14:
	jmp      illegal

|###################################################
|# bset_D2_ea                                      #
|###################################################
	.align	1
bset_D2_ea:
	move.l   reg_d2(%a6),%d1
	bsr      calculate_effective_address
	bset     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bset_D2_Dn                                      #
|###################################################
	.align	1
bset_D2_Dn:
	move.l   reg_d2(%a6),%d1
	bsr      read_then_write_operand_long
	bset     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_23:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bset_D2_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bset_D2_ea
illegal_15:
	jmp      illegal

|###################################################
|# add_immediate_byte                              #
|###################################################
	.align	1
add_immediate_byte:
	move.b   3(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# add_immediate_word                              #
|###################################################
	.align	1
add_immediate_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# add_immediate_long                              #
|###################################################
	.align	1
add_immediate_long:
	move.l   2(%a0),%d1
	addq.l   #4,%a0
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# rtm                                             #
|###################################################
	.align	1
rtm:
	jmp      handle_rtm
second_level_dispatch_27:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x10,%d4
	bcs      rtm
	cmpi.l   #0x18,%d4
	bcs      callm
	cmpi.l   #0x28,%d4
	bcs      illegal_16
	cmpi.l   #0x3c,%d4
	bcs      callm
illegal_16:
	jmp      illegal

|###################################################
|# callm                                           #
|###################################################
	.align	1
callm:
	jmp      handle_callm

|###################################################
|# btst_D3_ea                                      #
|###################################################
	.align	1
btst_D3_ea:
	move.l   reg_d3(%a6),%d1
	bsr      calculate_effective_address
	btst     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# btst_D3_Dn                                      #
|###################################################
	.align	1
btst_D3_Dn:
	move.l   reg_d3(%a6),%d1
	bsr      read_operand_long
	btst     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled
second_level_dispatch_28:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      btst_D3_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_word
	cmpi.l   #0x3a,%d4
	bcs      btst_D3_ea
illegal_17:
	jmp      illegal

|###################################################
|# bchg_D3_ea                                      #
|###################################################
	.align	1
bchg_D3_ea:
	move.l   reg_d3(%a6),%d1
	bsr      calculate_effective_address
	bchg     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bchg_D3_Dn                                      #
|###################################################
	.align	1
bchg_D3_Dn:
	move.l   reg_d3(%a6),%d1
	bsr      read_then_write_operand_long
	bchg     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_29:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bchg_D3_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bchg_D3_ea
illegal_18:
	jmp      illegal

|###################################################
|# bclr_D3_ea                                      #
|###################################################
	.align	1
bclr_D3_ea:
	move.l   reg_d3(%a6),%d1
	bsr      calculate_effective_address
	bclr     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bclr_D3_Dn                                      #
|###################################################
	.align	1
bclr_D3_Dn:
	move.l   reg_d3(%a6),%d1
	bsr      read_then_write_operand_long
	bclr     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_30:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bclr_D3_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_word
	cmpi.l   #0x3a,%d4
	bcs      bclr_D3_ea
illegal_19:
	jmp      illegal

|###################################################
|# bset_D3_ea                                      #
|###################################################
	.align	1
bset_D3_ea:
	move.l   reg_d3(%a6),%d1
	bsr      calculate_effective_address
	bset     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bset_D3_Dn                                      #
|###################################################
	.align	1
bset_D3_Dn:
	move.l   reg_d3(%a6),%d1
	bsr      read_then_write_operand_long
	bset     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_31:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bset_D3_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bset_D3_ea
illegal_20:
	jmp      illegal

|###################################################
|# btst_N_ea                                       #
|###################################################
	.align	1
btst_N_ea:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      calculate_effective_address
	btst     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# btst_N_Dn                                       #
|###################################################
	.align	1
btst_N_Dn:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_operand_long
	btst     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled
second_level_dispatch_32:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      btst_N_Dn
	cmpi.l   #0x10,%d4
	bcs      illegal_21
	cmpi.l   #0x3a,%d4
	bcs      btst_N_ea
illegal_21:
	jmp      illegal

|###################################################
|# bchg_N_ea                                       #
|###################################################
	.align	1
bchg_N_ea:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      calculate_effective_address
	bchg     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bchg_N_Dn                                       #
|###################################################
	.align	1
bchg_N_Dn:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_long
	bchg     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_33:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bchg_N_Dn
	cmpi.l   #0x10,%d4
	bcs      illegal_22
	cmpi.l   #0x3a,%d4
	bcs      bchg_N_ea
illegal_22:
	jmp      illegal

|###################################################
|# bclr_N_ea                                       #
|###################################################
	.align	1
bclr_N_ea:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      calculate_effective_address
	bclr     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bclr_N_Dn                                       #
|###################################################
	.align	1
bclr_N_Dn:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_long
	bclr     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_34:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bclr_N_Dn
	cmpi.l   #0x10,%d4
	bcs      illegal_23
	cmpi.l   #0x3a,%d4
	bcs      bclr_N_ea
illegal_23:
	jmp      illegal

|###################################################
|# bset_N_ea                                       #
|###################################################
	.align	1
bset_N_ea:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      calculate_effective_address
	bset     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bset_N_Dn                                       #
|###################################################
	.align	1
bset_N_Dn:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_long
	bset     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_35:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bset_N_Dn
	cmpi.l   #0x10,%d4
	bcs      illegal_24
	cmpi.l   #0x3a,%d4
	bcs      bset_N_ea
illegal_24:
	jmp      illegal

|###################################################
|# btst_D4_ea                                      #
|###################################################
	.align	1
btst_D4_ea:
	move.l   reg_d4(%a6),%d1
	bsr      calculate_effective_address
	btst     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# btst_D4_Dn                                      #
|###################################################
	.align	1
btst_D4_Dn:
	move.l   reg_d4(%a6),%d1
	bsr      read_operand_long
	btst     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled
second_level_dispatch_36:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      btst_D4_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_word
	cmpi.l   #0x3a,%d4
	bcs      btst_D4_ea
illegal_25:
	jmp      illegal

|###################################################
|# bchg_D4_ea                                      #
|###################################################
	.align	1
bchg_D4_ea:
	move.l   reg_d4(%a6),%d1
	bsr      calculate_effective_address
	bchg     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bchg_D4_Dn                                      #
|###################################################
	.align	1
bchg_D4_Dn:
	move.l   reg_d4(%a6),%d1
	bsr      read_then_write_operand_long
	bchg     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_37:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bchg_D4_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bchg_D4_ea
illegal_26:
	jmp      illegal

|###################################################
|# bclr_D4_ea                                      #
|###################################################
	.align	1
bclr_D4_ea:
	move.l   reg_d4(%a6),%d1
	bsr      calculate_effective_address
	bclr     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bclr_D4_Dn                                      #
|###################################################
	.align	1
bclr_D4_Dn:
	move.l   reg_d4(%a6),%d1
	bsr      read_then_write_operand_long
	bclr     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_38:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bclr_D4_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_word
	cmpi.l   #0x3a,%d4
	bcs      bclr_D4_ea
illegal_27:
	jmp      illegal

|###################################################
|# bset_D4_ea                                      #
|###################################################
	.align	1
bset_D4_ea:
	move.l   reg_d4(%a6),%d1
	bsr      calculate_effective_address
	bset     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bset_D4_Dn                                      #
|###################################################
	.align	1
bset_D4_Dn:
	move.l   reg_d4(%a6),%d1
	bsr      read_then_write_operand_long
	bset     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_39:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bset_D4_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bset_D4_ea
illegal_28:
	jmp      illegal

|###################################################
|# eor_immediate_byte                              #
|###################################################
	.align	1
second_level_dispatch_40:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_immediate_byte
	cmpi.l   #0x10,%d4
	bcs      illegal_29
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_40
eor_immediate_byte:
	move.b   3(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_byte
	eor.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
dispatch_second_others_40:
	cmpi.l   #0x3c,%d4
	bcs      illegal_29
	cmpi.l   #0x3d,%d4
	bcs      eori_to_CCR
illegal_29:
	jmp      illegal

|###################################################
|# eori_to_CCR                                     #
|###################################################
	.align	1
eori_to_CCR:
	move.b   3(%a0),%d1
	addq.l   #2,%a0
	move.b   reg_XNZVC(%a6),%d2
	eor.l    %d1,%d2
	addq.l   #2,%a0
	move.w   %d2,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# eori_to_SR                                      #
|###################################################
	.align	1
eori_to_SR:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1541
	jmp      handle_privilege_violation_exception
priv_ok_1541:
	addq.l   #2,%a0
	move.w   (%a0)+,%d1
	move.w   (reg_sr,%a6),%d0
	eor.l    %d1,%d0
	bra      _store_SR

|###################################################
|# eor_immediate_word                              #
|###################################################
	.align	1
second_level_dispatch_41:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_immediate_word
	cmpi.l   #0x10,%d4
	bcs      illegal_30
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_41
eor_immediate_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_then_write_operand_word
	eor.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
dispatch_second_others_41:
	cmpi.l   #0x3c,%d4
	bcs      illegal_30
	cmpi.l   #0x3d,%d4
	bcs      eori_to_SR
illegal_30:
	jmp      illegal

|###################################################
|# eor_immediate_long                              #
|###################################################
	.align	1
eor_immediate_long:
	move.l   2(%a0),%d1
	addq.l   #4,%a0
	bsr      read_then_write_operand_long
	eor.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cas2_byte                                       #
|###################################################
	.align	1
cas2_byte:
	jmp      handle_cas2

|###################################################
|# cas_byte                                        #
|###################################################
	.align	1
second_level_dispatch_43:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      cas_byte
	cmpi.l   #0x10,%d4
	bcs      illegal_31
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_43
cas_byte:
	jmp      handle_cas
dispatch_second_others_43:
	cmpi.l   #0x3c,%d4
	bcs      illegal_31
	cmpi.l   #0x3d,%d4
	bcs      cas2_byte
illegal_31:
	jmp      illegal

|###################################################
|# btst_D5_ea                                      #
|###################################################
	.align	1
btst_D5_ea:
	move.l   reg_d5(%a6),%d1
	bsr      calculate_effective_address
	btst     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# btst_D5_Dn                                      #
|###################################################
	.align	1
btst_D5_Dn:
	move.l   reg_d5(%a6),%d1
	bsr      read_operand_long
	btst     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled
second_level_dispatch_44:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      btst_D5_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_word
	cmpi.l   #0x3a,%d4
	bcs      btst_D5_ea
illegal_32:
	jmp      illegal

|###################################################
|# bchg_D5_ea                                      #
|###################################################
	.align	1
bchg_D5_ea:
	move.l   reg_d5(%a6),%d1
	bsr      calculate_effective_address
	bchg     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bchg_D5_Dn                                      #
|###################################################
	.align	1
bchg_D5_Dn:
	move.l   reg_d5(%a6),%d1
	bsr      read_then_write_operand_long
	bchg     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_45:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bchg_D5_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bchg_D5_ea
illegal_33:
	jmp      illegal

|###################################################
|# bclr_D5_ea                                      #
|###################################################
	.align	1
bclr_D5_ea:
	move.l   reg_d5(%a6),%d1
	bsr      calculate_effective_address
	bclr     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bclr_D5_Dn                                      #
|###################################################
	.align	1
bclr_D5_Dn:
	move.l   reg_d5(%a6),%d1
	bsr      read_then_write_operand_long
	bclr     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_46:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bclr_D5_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_word
	cmpi.l   #0x3a,%d4
	bcs      bclr_D5_ea
illegal_34:
	jmp      illegal

|###################################################
|# bset_D5_ea                                      #
|###################################################
	.align	1
bset_D5_ea:
	move.l   reg_d5(%a6),%d1
	bsr      calculate_effective_address
	bset     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bset_D5_Dn                                      #
|###################################################
	.align	1
bset_D5_Dn:
	move.l   reg_d5(%a6),%d1
	bsr      read_then_write_operand_long
	bset     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_47:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bset_D5_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bset_D5_ea
illegal_35:
	jmp      illegal

|###################################################
|# cmp_immediate_byte                              #
|###################################################
	.align	1
cmp_immediate_byte:
	move.b   3(%a0),%d1
	addq.l   #2,%a0
	bsr      read_operand_byte
	cmp.b    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_immediate_word                              #
|###################################################
	.align	1
cmp_immediate_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      read_operand_word
	cmp.w    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_immediate_long                              #
|###################################################
	.align	1
cmp_immediate_long:
	move.l   2(%a0),%d1
	addq.l   #4,%a0
	bsr      read_operand_long
	cmp.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cas2_word                                       #
|###################################################
	.align	1
cas2_word:
	jmp      handle_cas2

|###################################################
|# cas_word                                        #
|###################################################
	.align	1
second_level_dispatch_51:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      cas_word
	cmpi.l   #0x10,%d4
	bcs      illegal_36
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_51
cas_word:
	jmp      handle_cas
dispatch_second_others_51:
	cmpi.l   #0x3c,%d4
	bcs      illegal_36
	cmpi.l   #0x3d,%d4
	bcs      cas2_word
illegal_36:
	jmp      illegal

|###################################################
|# btst_D6_ea                                      #
|###################################################
	.align	1
btst_D6_ea:
	move.l   reg_d6(%a6),%d1
	bsr      calculate_effective_address
	btst     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# btst_D6_Dn                                      #
|###################################################
	.align	1
btst_D6_Dn:
	move.l   reg_d6(%a6),%d1
	bsr      read_operand_long
	btst     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled
second_level_dispatch_52:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      btst_D6_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_word
	cmpi.l   #0x3a,%d4
	bcs      btst_D6_ea
illegal_37:
	jmp      illegal

|###################################################
|# bchg_D6_ea                                      #
|###################################################
	.align	1
bchg_D6_ea:
	move.l   reg_d6(%a6),%d1
	bsr      calculate_effective_address
	bchg     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bchg_D6_Dn                                      #
|###################################################
	.align	1
bchg_D6_Dn:
	move.l   reg_d6(%a6),%d1
	bsr      read_then_write_operand_long
	bchg     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_53:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bchg_D6_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bchg_D6_ea
illegal_38:
	jmp      illegal

|###################################################
|# bclr_D6_ea                                      #
|###################################################
	.align	1
bclr_D6_ea:
	move.l   reg_d6(%a6),%d1
	bsr      calculate_effective_address
	bclr     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bclr_D6_Dn                                      #
|###################################################
	.align	1
bclr_D6_Dn:
	move.l   reg_d6(%a6),%d1
	bsr      read_then_write_operand_long
	bclr     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_54:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bclr_D6_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_word
	cmpi.l   #0x3a,%d4
	bcs      bclr_D6_ea
illegal_39:
	jmp      illegal

|###################################################
|# bset_D6_ea                                      #
|###################################################
	.align	1
bset_D6_ea:
	move.l   reg_d6(%a6),%d1
	bsr      calculate_effective_address
	bset     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bset_D6_Dn                                      #
|###################################################
	.align	1
bset_D6_Dn:
	move.l   reg_d6(%a6),%d1
	bsr      read_then_write_operand_long
	bset     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_55:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bset_D6_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bset_D6_ea
illegal_40:
	jmp      illegal

|###################################################
|# moves_byte                                      #
|###################################################
	.align	1
moves_byte:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1551
	jmp      handle_privilege_violation_exception
priv_ok_1551:
	jmp      handle_moves

|###################################################
|# moves_word                                      #
|###################################################
	.align	1
moves_word:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1552
	jmp      handle_privilege_violation_exception
priv_ok_1552:
	jmp      handle_moves

|###################################################
|# moves_long                                      #
|###################################################
	.align	1
moves_long:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1553
	jmp      handle_privilege_violation_exception
priv_ok_1553:
	jmp      handle_moves

|###################################################
|# cas2_long                                       #
|###################################################
	.align	1
cas2_long:
	jmp      handle_cas2

|###################################################
|# cas_long                                        #
|###################################################
	.align	1
second_level_dispatch_59:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      cas_long
	cmpi.l   #0x10,%d4
	bcs      illegal_41
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_59
cas_long:
	jmp      handle_cas
dispatch_second_others_59:
	cmpi.l   #0x3c,%d4
	bcs      illegal_41
	cmpi.l   #0x3d,%d4
	bcs      cas2_long
illegal_41:
	jmp      illegal

|###################################################
|# btst_D7_ea                                      #
|###################################################
	.align	1
btst_D7_ea:
	move.l   reg_d7(%a6),%d1
	bsr      calculate_effective_address
	btst     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# btst_D7_Dn                                      #
|###################################################
	.align	1
btst_D7_Dn:
	move.l   reg_d7(%a6),%d1
	bsr      read_operand_long
	btst     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled
second_level_dispatch_60:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      btst_D7_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_word
	cmpi.l   #0x3a,%d4
	bcs      btst_D7_ea
illegal_42:
	jmp      illegal

|###################################################
|# bchg_D7_ea                                      #
|###################################################
	.align	1
bchg_D7_ea:
	move.l   reg_d7(%a6),%d1
	bsr      calculate_effective_address
	bchg     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bchg_D7_Dn                                      #
|###################################################
	.align	1
bchg_D7_Dn:
	move.l   reg_d7(%a6),%d1
	bsr      read_then_write_operand_long
	bchg     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_61:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bchg_D7_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_from_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bchg_D7_ea
illegal_43:
	jmp      illegal

|###################################################
|# bclr_D7_ea                                      #
|###################################################
	.align	1
bclr_D7_ea:
	move.l   reg_d7(%a6),%d1
	bsr      calculate_effective_address
	bclr     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bclr_D7_Dn                                      #
|###################################################
	.align	1
bclr_D7_Dn:
	move.l   reg_d7(%a6),%d1
	bsr      read_then_write_operand_long
	bclr     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_62:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bclr_D7_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_word
	cmpi.l   #0x3a,%d4
	bcs      bclr_D7_ea
illegal_44:
	jmp      illegal

|###################################################
|# bset_D7_ea                                      #
|###################################################
	.align	1
bset_D7_ea:
	move.l   reg_d7(%a6),%d1
	bsr      calculate_effective_address
	bset     %d1,(%a1)
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      exception_handled

|###################################################
|# bset_D7_Dn                                      #
|###################################################
	.align	1
bset_D7_Dn:
	move.l   reg_d7(%a6),%d1
	bsr      read_then_write_operand_long
	bset     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x4,%d6
	jmp      (%a3)
second_level_dispatch_63:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bset_D7_Dn
	cmpi.l   #0x10,%d4
	bcs      movep_to_memory_long
	cmpi.l   #0x3a,%d4
	bcs      bset_D7_ea
illegal_45:
	jmp      illegal

|###################################################
|# move_byte_D0                                    #
|###################################################
	.align	1
move_byte_D0:
	bsr      read_operand_byte
	move.b   %d0,reg_d0+3(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indirect_A0                           #
|###################################################
	.align	1
move_byte_indirect_A0:
	bsr      read_operand_byte
	move.l   reg_a0(%a6),%a2
	move.b   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_postincrement_A0                      #
|###################################################
	.align	1
move_byte_postincrement_A0:
	bsr      read_operand_byte
	move.l   reg_a0(%a6),%a2
	move.b   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_predecrement_A0                       #
|###################################################
	.align	1
move_byte_predecrement_A0:
	bsr      read_operand_byte
	move.l   reg_a0(%a6),%a2
	move.b   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_displacement_A0                       #
|###################################################
	.align	1
move_byte_displacement_A0:
	bsr      read_operand_byte
	move.l   reg_a0(%a6),%a2
	movea.w  (%a0)+,%a4
	move.b   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indexed_A0                            #
|###################################################
	.align	1
move_byte_indexed_A0:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_indexed_A0

|###################################################
|# move_byte_absolute_word                         #
|###################################################
	.align	1
move_byte_absolute_word:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_absolute_word

|###################################################
|# move_byte_D1                                    #
|###################################################
	.align	1
move_byte_D1:
	bsr      read_operand_byte
	move.b   %d0,reg_d1+3(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indirect_A1                           #
|###################################################
	.align	1
move_byte_indirect_A1:
	bsr      read_operand_byte
	move.l   reg_a1(%a6),%a2
	move.b   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_postincrement_A1                      #
|###################################################
	.align	1
move_byte_postincrement_A1:
	bsr      read_operand_byte
	move.l   reg_a1(%a6),%a2
	move.b   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_predecrement_A1                       #
|###################################################
	.align	1
move_byte_predecrement_A1:
	bsr      read_operand_byte
	move.l   reg_a1(%a6),%a2
	move.b   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_displacement_A1                       #
|###################################################
	.align	1
move_byte_displacement_A1:
	bsr      read_operand_byte
	move.l   reg_a1(%a6),%a2
	movea.w  (%a0)+,%a4
	move.b   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indexed_A1                            #
|###################################################
	.align	1
move_byte_indexed_A1:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_indexed_A1

|###################################################
|# move_byte_absolute_long                         #
|###################################################
	.align	1
move_byte_absolute_long:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_absolute_long

|###################################################
|# move_byte_D2                                    #
|###################################################
	.align	1
move_byte_D2:
	bsr      read_operand_byte
	move.b   %d0,reg_d2+3(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indirect_A2                           #
|###################################################
	.align	1
move_byte_indirect_A2:
	bsr      read_operand_byte
	move.l   reg_a2(%a6),%a2
	move.b   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_postincrement_A2                      #
|###################################################
	.align	1
move_byte_postincrement_A2:
	bsr      read_operand_byte
	move.l   reg_a2(%a6),%a2
	move.b   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_predecrement_A2                       #
|###################################################
	.align	1
move_byte_predecrement_A2:
	bsr      read_operand_byte
	move.l   reg_a2(%a6),%a2
	move.b   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_displacement_A2                       #
|###################################################
	.align	1
move_byte_displacement_A2:
	bsr      read_operand_byte
	move.l   reg_a2(%a6),%a2
	movea.w  (%a0)+,%a4
	move.b   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indexed_A2                            #
|###################################################
	.align	1
move_byte_indexed_A2:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_indexed_A2

|###################################################
|# move_byte_D3                                    #
|###################################################
	.align	1
move_byte_D3:
	bsr      read_operand_byte
	move.b   %d0,reg_d3+3(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indirect_A3                           #
|###################################################
	.align	1
move_byte_indirect_A3:
	bsr      read_operand_byte
	move.l   reg_a3(%a6),%a2
	move.b   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_postincrement_A3                      #
|###################################################
	.align	1
move_byte_postincrement_A3:
	bsr      read_operand_byte
	move.l   reg_a3(%a6),%a2
	move.b   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_predecrement_A3                       #
|###################################################
	.align	1
move_byte_predecrement_A3:
	bsr      read_operand_byte
	move.l   reg_a3(%a6),%a2
	move.b   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_displacement_A3                       #
|###################################################
	.align	1
move_byte_displacement_A3:
	bsr      read_operand_byte
	move.l   reg_a3(%a6),%a2
	movea.w  (%a0)+,%a4
	move.b   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indexed_A3                            #
|###################################################
	.align	1
move_byte_indexed_A3:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_indexed_A3

|###################################################
|# move_byte_D4                                    #
|###################################################
	.align	1
move_byte_D4:
	bsr      read_operand_byte
	move.b   %d0,reg_d4+3(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indirect_A4                           #
|###################################################
	.align	1
move_byte_indirect_A4:
	bsr      read_operand_byte
	move.l   reg_a4(%a6),%a2
	move.b   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_postincrement_A4                      #
|###################################################
	.align	1
move_byte_postincrement_A4:
	bsr      read_operand_byte
	move.l   reg_a4(%a6),%a2
	move.b   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_predecrement_A4                       #
|###################################################
	.align	1
move_byte_predecrement_A4:
	bsr      read_operand_byte
	move.l   reg_a4(%a6),%a2
	move.b   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_displacement_A4                       #
|###################################################
	.align	1
move_byte_displacement_A4:
	bsr      read_operand_byte
	move.l   reg_a4(%a6),%a2
	movea.w  (%a0)+,%a4
	move.b   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indexed_A4                            #
|###################################################
	.align	1
move_byte_indexed_A4:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_indexed_A4

|###################################################
|# move_byte_D5                                    #
|###################################################
	.align	1
move_byte_D5:
	bsr      read_operand_byte
	move.b   %d0,reg_d5+3(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indirect_A5                           #
|###################################################
	.align	1
move_byte_indirect_A5:
	bsr      read_operand_byte
	move.l   reg_a5(%a6),%a2
	move.b   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_postincrement_A5                      #
|###################################################
	.align	1
move_byte_postincrement_A5:
	bsr      read_operand_byte
	move.l   reg_a5(%a6),%a2
	move.b   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_predecrement_A5                       #
|###################################################
	.align	1
move_byte_predecrement_A5:
	bsr      read_operand_byte
	move.l   reg_a5(%a6),%a2
	move.b   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_displacement_A5                       #
|###################################################
	.align	1
move_byte_displacement_A5:
	bsr      read_operand_byte
	move.l   reg_a5(%a6),%a2
	movea.w  (%a0)+,%a4
	move.b   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indexed_A5                            #
|###################################################
	.align	1
move_byte_indexed_A5:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_indexed_A5

|###################################################
|# move_byte_D6                                    #
|###################################################
	.align	1
move_byte_D6:
	bsr      read_operand_byte
	move.b   %d0,reg_d6+3(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indirect_A6                           #
|###################################################
	.align	1
move_byte_indirect_A6:
	bsr      read_operand_byte
	move.l   reg_a6(%a6),%a2
	move.b   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_postincrement_A6                      #
|###################################################
	.align	1
move_byte_postincrement_A6:
	bsr      read_operand_byte
	move.l   reg_a6(%a6),%a2
	move.b   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_predecrement_A6                       #
|###################################################
	.align	1
move_byte_predecrement_A6:
	bsr      read_operand_byte
	move.l   reg_a6(%a6),%a2
	move.b   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# move_byte_displacement_A6                       #
|###################################################
	.align	1
move_byte_displacement_A6:
	bsr      read_operand_byte
	move.l   reg_a6(%a6),%a2
	movea.w  (%a0)+,%a4
	move.b   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indexed_A6                            #
|###################################################
	.align	1
move_byte_indexed_A6:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_indexed_A6

|###################################################
|# move_byte_D7                                    #
|###################################################
	.align	1
move_byte_D7:
	bsr      read_operand_byte
	move.b   %d0,reg_d7+3(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indirect_A7                           #
|###################################################
	.align	1
move_byte_indirect_A7:
	bsr      read_operand_byte
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.b   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_postincrement_A7                      #
|###################################################
	.align	1
move_byte_postincrement_A7:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_postincrement_A7

|###################################################
|# move_byte_predecrement_A7                       #
|###################################################
	.align	1
move_byte_predecrement_A7:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_predecrement_A7

|###################################################
|# move_byte_displacement_A7                       #
|###################################################
	.align	1
move_byte_displacement_A7:
	bsr      read_operand_byte
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	movea.w  (%a0)+,%a4
	move.b   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_byte_indexed_A7                            #
|###################################################
	.align	1
move_byte_indexed_A7:
	bsr      read_operand_byte
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.b    %d0
	move     %ccr,%d7
	bra      store_byte_indexed_A7

|###################################################
|# move_long_D0                                    #
|###################################################
	.align	1
move_long_D0:
	bsr      read_operand_long
	move.l   %d0,reg_d0(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_long_A0                                   #
|###################################################
	.align	1
movea_long_A0:
	bsr      read_operand_long
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# move_long_indirect_A0                           #
|###################################################
	.align	1
move_long_indirect_A0:
	bsr      read_operand_long
	move.l   reg_a0(%a6),%a2
	move.l   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_postincrement_A0                      #
|###################################################
	.align	1
move_long_postincrement_A0:
	bsr      read_operand_long
	move.l   reg_a0(%a6),%a2
	move.l   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# move_long_predecrement_A0                       #
|###################################################
	.align	1
move_long_predecrement_A0:
	bsr      read_operand_long
	move.l   reg_a0(%a6),%a2
	move.l   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# move_long_displacement_A0                       #
|###################################################
	.align	1
move_long_displacement_A0:
	bsr      read_operand_long
	move.l   reg_a0(%a6),%a2
	movea.w  (%a0)+,%a4
	move.l   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_indexed_A0                            #
|###################################################
	.align	1
move_long_indexed_A0:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_indexed_A0

|###################################################
|# move_long_absolute_word                         #
|###################################################
	.align	1
move_long_absolute_word:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_absolute_word

|###################################################
|# move_long_D1                                    #
|###################################################
	.align	1
move_long_D1:
	bsr      read_operand_long
	move.l   %d0,reg_d1(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_long_A1                                   #
|###################################################
	.align	1
movea_long_A1:
	bsr      read_operand_long
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# move_long_indirect_A1                           #
|###################################################
	.align	1
move_long_indirect_A1:
	bsr      read_operand_long
	move.l   reg_a1(%a6),%a2
	move.l   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_postincrement_A1                      #
|###################################################
	.align	1
move_long_postincrement_A1:
	bsr      read_operand_long
	move.l   reg_a1(%a6),%a2
	move.l   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# move_long_predecrement_A1                       #
|###################################################
	.align	1
move_long_predecrement_A1:
	bsr      read_operand_long
	move.l   reg_a1(%a6),%a2
	move.l   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# move_long_displacement_A1                       #
|###################################################
	.align	1
move_long_displacement_A1:
	bsr      read_operand_long
	move.l   reg_a1(%a6),%a2
	movea.w  (%a0)+,%a4
	move.l   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_indexed_A1                            #
|###################################################
	.align	1
move_long_indexed_A1:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_indexed_A1

|###################################################
|# move_long_absolute_long                         #
|###################################################
	.align	1
move_long_absolute_long:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_absolute_long

|###################################################
|# move_long_D2                                    #
|###################################################
	.align	1
move_long_D2:
	bsr      read_operand_long
	move.l   %d0,reg_d2(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_long_A2                                   #
|###################################################
	.align	1
movea_long_A2:
	bsr      read_operand_long
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# move_long_indirect_A2                           #
|###################################################
	.align	1
move_long_indirect_A2:
	bsr      read_operand_long
	move.l   reg_a2(%a6),%a2
	move.l   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_postincrement_A2                      #
|###################################################
	.align	1
move_long_postincrement_A2:
	bsr      read_operand_long
	move.l   reg_a2(%a6),%a2
	move.l   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# move_long_predecrement_A2                       #
|###################################################
	.align	1
move_long_predecrement_A2:
	bsr      read_operand_long
	move.l   reg_a2(%a6),%a2
	move.l   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# move_long_displacement_A2                       #
|###################################################
	.align	1
move_long_displacement_A2:
	bsr      read_operand_long
	move.l   reg_a2(%a6),%a2
	movea.w  (%a0)+,%a4
	move.l   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_indexed_A2                            #
|###################################################
	.align	1
move_long_indexed_A2:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_indexed_A2

|###################################################
|# move_long_D3                                    #
|###################################################
	.align	1
move_long_D3:
	bsr      read_operand_long
	move.l   %d0,reg_d3(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_long_A3                                   #
|###################################################
	.align	1
movea_long_A3:
	bsr      read_operand_long
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# move_long_indirect_A3                           #
|###################################################
	.align	1
move_long_indirect_A3:
	bsr      read_operand_long
	move.l   reg_a3(%a6),%a2
	move.l   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_postincrement_A3                      #
|###################################################
	.align	1
move_long_postincrement_A3:
	bsr      read_operand_long
	move.l   reg_a3(%a6),%a2
	move.l   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# move_long_predecrement_A3                       #
|###################################################
	.align	1
move_long_predecrement_A3:
	bsr      read_operand_long
	move.l   reg_a3(%a6),%a2
	move.l   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# move_long_displacement_A3                       #
|###################################################
	.align	1
move_long_displacement_A3:
	bsr      read_operand_long
	move.l   reg_a3(%a6),%a2
	movea.w  (%a0)+,%a4
	move.l   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_indexed_A3                            #
|###################################################
	.align	1
move_long_indexed_A3:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_indexed_A3

|###################################################
|# move_long_D4                                    #
|###################################################
	.align	1
move_long_D4:
	bsr      read_operand_long
	move.l   %d0,reg_d4(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_long_A4                                   #
|###################################################
	.align	1
movea_long_A4:
	bsr      read_operand_long
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# move_long_indirect_A4                           #
|###################################################
	.align	1
move_long_indirect_A4:
	bsr      read_operand_long
	move.l   reg_a4(%a6),%a2
	move.l   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_postincrement_A4                      #
|###################################################
	.align	1
move_long_postincrement_A4:
	bsr      read_operand_long
	move.l   reg_a4(%a6),%a2
	move.l   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# move_long_predecrement_A4                       #
|###################################################
	.align	1
move_long_predecrement_A4:
	bsr      read_operand_long
	move.l   reg_a4(%a6),%a2
	move.l   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# move_long_displacement_A4                       #
|###################################################
	.align	1
move_long_displacement_A4:
	bsr      read_operand_long
	move.l   reg_a4(%a6),%a2
	movea.w  (%a0)+,%a4
	move.l   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_indexed_A4                            #
|###################################################
	.align	1
move_long_indexed_A4:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_indexed_A4

|###################################################
|# move_long_D5                                    #
|###################################################
	.align	1
move_long_D5:
	bsr      read_operand_long
	move.l   %d0,reg_d5(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_long_A5                                   #
|###################################################
	.align	1
movea_long_A5:
	bsr      read_operand_long
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# move_long_indirect_A5                           #
|###################################################
	.align	1
move_long_indirect_A5:
	bsr      read_operand_long
	move.l   reg_a5(%a6),%a2
	move.l   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_postincrement_A5                      #
|###################################################
	.align	1
move_long_postincrement_A5:
	bsr      read_operand_long
	move.l   reg_a5(%a6),%a2
	move.l   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# move_long_predecrement_A5                       #
|###################################################
	.align	1
move_long_predecrement_A5:
	bsr      read_operand_long
	move.l   reg_a5(%a6),%a2
	move.l   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# move_long_displacement_A5                       #
|###################################################
	.align	1
move_long_displacement_A5:
	bsr      read_operand_long
	move.l   reg_a5(%a6),%a2
	movea.w  (%a0)+,%a4
	move.l   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_indexed_A5                            #
|###################################################
	.align	1
move_long_indexed_A5:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_indexed_A5

|###################################################
|# move_long_D6                                    #
|###################################################
	.align	1
move_long_D6:
	bsr      read_operand_long
	move.l   %d0,reg_d6(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_long_A6                                   #
|###################################################
	.align	1
movea_long_A6:
	bsr      read_operand_long
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# move_long_indirect_A6                           #
|###################################################
	.align	1
move_long_indirect_A6:
	bsr      read_operand_long
	move.l   reg_a6(%a6),%a2
	move.l   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_postincrement_A6                      #
|###################################################
	.align	1
move_long_postincrement_A6:
	bsr      read_operand_long
	move.l   reg_a6(%a6),%a2
	move.l   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# move_long_predecrement_A6                       #
|###################################################
	.align	1
move_long_predecrement_A6:
	bsr      read_operand_long
	move.l   reg_a6(%a6),%a2
	move.l   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# move_long_displacement_A6                       #
|###################################################
	.align	1
move_long_displacement_A6:
	bsr      read_operand_long
	move.l   reg_a6(%a6),%a2
	movea.w  (%a0)+,%a4
	move.l   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_indexed_A6                            #
|###################################################
	.align	1
move_long_indexed_A6:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_indexed_A6

|###################################################
|# move_long_D7                                    #
|###################################################
	.align	1
move_long_D7:
	bsr      read_operand_long
	move.l   %d0,reg_d7(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_long_A7                                   #
|###################################################
	.align	1
movea_long_A7:
	bsr      read_operand_long
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# move_long_indirect_A7                           #
|###################################################
	.align	1
move_long_indirect_A7:
	bsr      read_operand_long
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.l   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_postincrement_A7                      #
|###################################################
	.align	1
move_long_postincrement_A7:
	bsr      read_operand_long
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.l   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# move_long_predecrement_A7                       #
|###################################################
	.align	1
move_long_predecrement_A7:
	bsr      read_operand_long
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.l   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# move_long_displacement_A7                       #
|###################################################
	.align	1
move_long_displacement_A7:
	bsr      read_operand_long
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	movea.w  (%a0)+,%a4
	move.l   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_long_indexed_A7                            #
|###################################################
	.align	1
move_long_indexed_A7:
	bsr      read_operand_long
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.l    %d0
	move     %ccr,%d7
	bra      store_long_indexed_A7

|###################################################
|# move_word_D0                                    #
|###################################################
	.align	1
move_word_D0:
	bsr      read_operand_word
	move.w   %d0,reg_d0+2(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_word_A0                                   #
|###################################################
	.align	1
movea_word_A0:
	bsr      read_operand_word
	ext.l    %d0
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# move_word_indirect_A0                           #
|###################################################
	.align	1
move_word_indirect_A0:
	bsr      read_operand_word
	move.l   reg_a0(%a6),%a2
	move.w   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_postincrement_A0                      #
|###################################################
	.align	1
move_word_postincrement_A0:
	bsr      read_operand_word
	move.l   reg_a0(%a6),%a2
	move.w   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# move_word_predecrement_A0                       #
|###################################################
	.align	1
move_word_predecrement_A0:
	bsr      read_operand_word
	move.l   reg_a0(%a6),%a2
	move.w   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# move_word_displacement_A0                       #
|###################################################
	.align	1
move_word_displacement_A0:
	bsr      read_operand_word
	move.l   reg_a0(%a6),%a2
	movea.w  (%a0)+,%a4
	move.w   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_indexed_A0                            #
|###################################################
	.align	1
move_word_indexed_A0:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_indexed_A0

|###################################################
|# move_word_absolute_word                         #
|###################################################
	.align	1
move_word_absolute_word:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_absolute_word

|###################################################
|# move_word_D1                                    #
|###################################################
	.align	1
move_word_D1:
	bsr      read_operand_word
	move.w   %d0,reg_d1+2(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_word_A1                                   #
|###################################################
	.align	1
movea_word_A1:
	bsr      read_operand_word
	ext.l    %d0
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# move_word_indirect_A1                           #
|###################################################
	.align	1
move_word_indirect_A1:
	bsr      read_operand_word
	move.l   reg_a1(%a6),%a2
	move.w   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_postincrement_A1                      #
|###################################################
	.align	1
move_word_postincrement_A1:
	bsr      read_operand_word
	move.l   reg_a1(%a6),%a2
	move.w   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# move_word_predecrement_A1                       #
|###################################################
	.align	1
move_word_predecrement_A1:
	bsr      read_operand_word
	move.l   reg_a1(%a6),%a2
	move.w   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# move_word_displacement_A1                       #
|###################################################
	.align	1
move_word_displacement_A1:
	bsr      read_operand_word
	move.l   reg_a1(%a6),%a2
	movea.w  (%a0)+,%a4
	move.w   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_indexed_A1                            #
|###################################################
	.align	1
move_word_indexed_A1:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_indexed_A1

|###################################################
|# move_word_absolute_long                         #
|###################################################
	.align	1
move_word_absolute_long:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_absolute_long

|###################################################
|# move_word_D2                                    #
|###################################################
	.align	1
move_word_D2:
	bsr      read_operand_word
	move.w   %d0,reg_d2+2(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_word_A2                                   #
|###################################################
	.align	1
movea_word_A2:
	bsr      read_operand_word
	ext.l    %d0
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# move_word_indirect_A2                           #
|###################################################
	.align	1
move_word_indirect_A2:
	bsr      read_operand_word
	move.l   reg_a2(%a6),%a2
	move.w   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_postincrement_A2                      #
|###################################################
	.align	1
move_word_postincrement_A2:
	bsr      read_operand_word
	move.l   reg_a2(%a6),%a2
	move.w   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# move_word_predecrement_A2                       #
|###################################################
	.align	1
move_word_predecrement_A2:
	bsr      read_operand_word
	move.l   reg_a2(%a6),%a2
	move.w   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# move_word_displacement_A2                       #
|###################################################
	.align	1
move_word_displacement_A2:
	bsr      read_operand_word
	move.l   reg_a2(%a6),%a2
	movea.w  (%a0)+,%a4
	move.w   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_indexed_A2                            #
|###################################################
	.align	1
move_word_indexed_A2:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_indexed_A2

|###################################################
|# move_word_D3                                    #
|###################################################
	.align	1
move_word_D3:
	bsr      read_operand_word
	move.w   %d0,reg_d3+2(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_word_A3                                   #
|###################################################
	.align	1
movea_word_A3:
	bsr      read_operand_word
	ext.l    %d0
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# move_word_indirect_A3                           #
|###################################################
	.align	1
move_word_indirect_A3:
	bsr      read_operand_word
	move.l   reg_a3(%a6),%a2
	move.w   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_postincrement_A3                      #
|###################################################
	.align	1
move_word_postincrement_A3:
	bsr      read_operand_word
	move.l   reg_a3(%a6),%a2
	move.w   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# move_word_predecrement_A3                       #
|###################################################
	.align	1
move_word_predecrement_A3:
	bsr      read_operand_word
	move.l   reg_a3(%a6),%a2
	move.w   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# move_word_displacement_A3                       #
|###################################################
	.align	1
move_word_displacement_A3:
	bsr      read_operand_word
	move.l   reg_a3(%a6),%a2
	movea.w  (%a0)+,%a4
	move.w   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_indexed_A3                            #
|###################################################
	.align	1
move_word_indexed_A3:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_indexed_A3

|###################################################
|# move_word_D4                                    #
|###################################################
	.align	1
move_word_D4:
	bsr      read_operand_word
	move.w   %d0,reg_d4+2(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_word_A4                                   #
|###################################################
	.align	1
movea_word_A4:
	bsr      read_operand_word
	ext.l    %d0
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# move_word_indirect_A4                           #
|###################################################
	.align	1
move_word_indirect_A4:
	bsr      read_operand_word
	move.l   reg_a4(%a6),%a2
	move.w   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_postincrement_A4                      #
|###################################################
	.align	1
move_word_postincrement_A4:
	bsr      read_operand_word
	move.l   reg_a4(%a6),%a2
	move.w   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# move_word_predecrement_A4                       #
|###################################################
	.align	1
move_word_predecrement_A4:
	bsr      read_operand_word
	move.l   reg_a4(%a6),%a2
	move.w   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# move_word_displacement_A4                       #
|###################################################
	.align	1
move_word_displacement_A4:
	bsr      read_operand_word
	move.l   reg_a4(%a6),%a2
	movea.w  (%a0)+,%a4
	move.w   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_indexed_A4                            #
|###################################################
	.align	1
move_word_indexed_A4:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_indexed_A4

|###################################################
|# move_word_D5                                    #
|###################################################
	.align	1
move_word_D5:
	bsr      read_operand_word
	move.w   %d0,reg_d5+2(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_word_A5                                   #
|###################################################
	.align	1
movea_word_A5:
	bsr      read_operand_word
	ext.l    %d0
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# move_word_indirect_A5                           #
|###################################################
	.align	1
move_word_indirect_A5:
	bsr      read_operand_word
	move.l   reg_a5(%a6),%a2
	move.w   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_postincrement_A5                      #
|###################################################
	.align	1
move_word_postincrement_A5:
	bsr      read_operand_word
	move.l   reg_a5(%a6),%a2
	move.w   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# move_word_predecrement_A5                       #
|###################################################
	.align	1
move_word_predecrement_A5:
	bsr      read_operand_word
	move.l   reg_a5(%a6),%a2
	move.w   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# move_word_displacement_A5                       #
|###################################################
	.align	1
move_word_displacement_A5:
	bsr      read_operand_word
	move.l   reg_a5(%a6),%a2
	movea.w  (%a0)+,%a4
	move.w   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_indexed_A5                            #
|###################################################
	.align	1
move_word_indexed_A5:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_indexed_A5

|###################################################
|# move_word_D6                                    #
|###################################################
	.align	1
move_word_D6:
	bsr      read_operand_word
	move.w   %d0,reg_d6+2(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_word_A6                                   #
|###################################################
	.align	1
movea_word_A6:
	bsr      read_operand_word
	ext.l    %d0
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# move_word_indirect_A6                           #
|###################################################
	.align	1
move_word_indirect_A6:
	bsr      read_operand_word
	move.l   reg_a6(%a6),%a2
	move.w   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_postincrement_A6                      #
|###################################################
	.align	1
move_word_postincrement_A6:
	bsr      read_operand_word
	move.l   reg_a6(%a6),%a2
	move.w   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# move_word_predecrement_A6                       #
|###################################################
	.align	1
move_word_predecrement_A6:
	bsr      read_operand_word
	move.l   reg_a6(%a6),%a2
	move.w   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# move_word_displacement_A6                       #
|###################################################
	.align	1
move_word_displacement_A6:
	bsr      read_operand_word
	move.l   reg_a6(%a6),%a2
	movea.w  (%a0)+,%a4
	move.w   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_indexed_A6                            #
|###################################################
	.align	1
move_word_indexed_A6:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_indexed_A6

|###################################################
|# move_word_D7                                    #
|###################################################
	.align	1
move_word_D7:
	bsr      read_operand_word
	move.w   %d0,reg_d7+2(%a6)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movea_word_A7                                   #
|###################################################
	.align	1
movea_word_A7:
	bsr      read_operand_word
	ext.l    %d0
	move.l   %d0,%a2
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# move_word_indirect_A7                           #
|###################################################
	.align	1
move_word_indirect_A7:
	bsr      read_operand_word
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.w   %d0,(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_postincrement_A7                      #
|###################################################
	.align	1
move_word_postincrement_A7:
	bsr      read_operand_word
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.w   %d0,(%a2)+
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# move_word_predecrement_A7                       #
|###################################################
	.align	1
move_word_predecrement_A7:
	bsr      read_operand_word
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.w   %d0,-(%a2)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# move_word_displacement_A7                       #
|###################################################
	.align	1
move_word_displacement_A7:
	bsr      read_operand_word
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	movea.w  (%a0)+,%a4
	move.w   %d0,(%a2,%a4.l)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# move_word_indexed_A7                            #
|###################################################
	.align	1
move_word_indexed_A7:
	bsr      read_operand_word
	subq.l   #2,%a0
	moveq.l  #0x0f,%d6
	tst.w    %d0
	move     %ccr,%d7
	bra      store_word_indexed_A7

|###################################################
|# negx_byte                                       #
|###################################################
	.align	1
negx_byte:
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d1
	lsl.l    %d1,%d0
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	negx.l   %d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d1,%d0
	jmp      (%a3)

|###################################################
|# negx_word                                       #
|###################################################
	.align	1
negx_word:
	bsr      read_then_write_operand_word
	moveq.l  #16,%d1
	lsl.l    %d1,%d0
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	negx.l   %d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d1,%d0
	jmp      (%a3)

|###################################################
|# negx_long                                       #
|###################################################
	.align	1
negx_long:
	bsr      read_then_write_operand_long
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	negx.l   %d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# move_from_SR                                    #
|###################################################
	.align	1
move_from_SR:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1543
	jmp      handle_privilege_violation_exception
priv_ok_1543:
	move.w   (reg_sr,%a6),%d0
	andi.l   #0xf71f,%d0
	moveq.l  #0,%d6
	bra      store_operand_word

|###################################################
|# chk_long                                        #
|###################################################
	.align	1
chk_long:
	bsr      read_operand_long
	move.l   %d0,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bsr      read_operand_long
	tst.l    %d0
	bmi      chk_fail
	cmp.l    %d1,%d0
	ble.s    chk_long_ok
	bra      chk_fail
chk_long_ok:
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# chk_word                                        #
|###################################################
	.align	1
chk_word:
	bsr      read_operand_word
	move.l   %d0,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bsr      read_operand_word
	ext.l    %d1
	ext.l    %d0
	tst.l    %d0
	bmi.s    chk_fail
	cmp.l    %d1,%d0
	ble.s    chk_word_ok
chk_fail:
	move     %ccr,%d1
	move.b   %d1,reg_XNZVC(%a6)
	move.l   %a0,reg_pc(%a6)
	moveq.l  #6,%d1
	jmp      handle_680x0_exception
chk_word_ok:
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# lea_A0                                          #
|###################################################
	.align	1
lea_A0:
	bsr      calculate_effective_address
	moveq.l  #0x0,%d6
	move.l   %a1,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# clr_byte                                        #
|###################################################
	.align	1
clr_byte:
	clr.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	bra      store_operand_byte

|###################################################
|# clr_word                                        #
|###################################################
	.align	1
clr_word:
	clr.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	bra      store_operand_word

|###################################################
|# clr_long                                        #
|###################################################
	.align	1
clr_long:
	clr.l    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	bra      store_operand_long

|###################################################
|# move_from_CCR                                   #
|###################################################
	.align	1
move_from_CCR:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	move.w   %CCR,%d0
	andi.l   #0x1f,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	bra      store_operand_word

|###################################################
|# lea_A1                                          #
|###################################################
	.align	1
lea_A1:
	bsr      calculate_effective_address
	moveq.l  #0x0,%d6
	move.l   %a1,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# neg_byte                                        #
|###################################################
	.align	1
neg_byte:
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d1
	lsl.l    %d1,%d0
	neg.l    %d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d1,%d0
	jmp      (%a3)

|###################################################
|# neg_word                                        #
|###################################################
	.align	1
neg_word:
	bsr      read_then_write_operand_word
	moveq.l  #16,%d1
	lsl.l    %d1,%d0
	neg.l    %d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d1,%d0
	jmp      (%a3)

|###################################################
|# neg_long                                        #
|###################################################
	.align	1
neg_long:
	bsr      read_then_write_operand_long
	neg.l    %d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# move_to_CCR                                     #
|###################################################
	.align	1
move_to_CCR:
	bsr      read_operand_word
	move.w   %d0,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# lea_A2                                          #
|###################################################
	.align	1
lea_A2:
	bsr      calculate_effective_address
	moveq.l  #0x0,%d6
	move.l   %a1,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# not_byte                                        #
|###################################################
	.align	1
not_byte:
	bsr      read_then_write_operand_byte
	not.l    %d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# not_word                                        #
|###################################################
	.align	1
not_word:
	bsr      read_then_write_operand_word
	not.l    %d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# not_long                                        #
|###################################################
	.align	1
not_long:
	bsr      read_then_write_operand_long
	not.l    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# move_to_SR                                      #
|###################################################
	.align	1
move_to_SR:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1539
	jmp      handle_privilege_violation_exception
priv_ok_1539:
	bsr      read_operand_word
_store_SR:
	move.w   (reg_sr,%a6),%d6
	move.w   %d6,%d7
	move.w   %d0,(reg_sr,%a6)
	eor.l    %d0,%d6
	and.l    #0x2000,%d6
	beq.s    move_to_SR_nochgS
	jsr      S_bit_changed
move_to_SR_nochgS:
	move.w   %d0,%d7
	andi.l   #0x1f,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# lea_A3                                          #
|###################################################
	.align	1
lea_A3:
	bsr      calculate_effective_address
	moveq.l  #0x0,%d6
	move.l   %a1,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# link_long                                       #
|###################################################
	.align	1
link_long:
	and.l    #7,%d5
	ori.l    #0x08,%d5
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	move.l   (%a0)+,%d1
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a4
	move.l   %a2,-(%a4)
	move.l   %a4,%a2
	add.l    %d1,%a4
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a4,reg_a7(%a6)
	move.l   %a2,%d0
	jmp      (%a3)

|###################################################
|# nbcd                                            #
|###################################################
	.align	1
second_level_dispatch_288:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      nbcd
	cmpi.l   #0x10,%d4
	bcs      link_long
	cmpi.l   #0x3a,%d4
	bcc      illegal_46
nbcd:
	bsr      read_then_write_operand_byte
	and.l    #0x000000ff,%d0
	move.b   reg_XNZVC(%a6),%d1
	movea.l  #_PA_bcd_tables,%a2
	move.b   (_PA_BCDBIN,%a2,%d0.l),%d0
	move     %d1,%CCR
	negx.l   %d0
	move     %CCR,%d2
	add.l    #100,%d0
	move.b   (_PA_BINBCD+1,%a2,%d0.l*2),%d0
	beq.b    _M68k_970_
	bclr     #2,%d1
_M68k_970_:
	andi.l   #0x04,%d1
	bclr     #2,%d2
	or.l     %d1,%d2
	move     %d2,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# pea                                             #
|###################################################
	.align	1
pea:
	cmpi.l   #0x4848,%d5
	blt      swap_handler
	cmpi.l   #0x484f,%d5
	ble      bkpt_handler
	bsr      calculate_effective_address
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.l   %a1,-(%a2)
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# ext_word                                        #
|###################################################
	.align	1
ext_word:
	bsr      read_then_write_operand_word
	ext.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_290:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      ext_word
	cmpi.l   #0x10,%d4
	bcs      illegal_46
	cmpi.l   #0x18,%d4
	bcs      movem_to_memory_word_control
	cmpi.l   #0x20,%d4
	bcs      illegal_46
	cmpi.l   #0x27,%d4
	bcs      movem_to_memory_predecrement_word
	cmpi.l   #0x28,%d4
	bcs      pushm_word
	cmpi.l   #0x3a,%d4
	bcs      movem_to_memory_word_control
illegal_46:
	jmp      illegal

|###################################################
|# movem_to_memory_predecrement_word               #
|###################################################
	.align	1
movem_to_memory_predecrement_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	and.l    #7,%d5
	ori.l    #0x08,%d5
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	and.l    #0xffff,%d1
	lea      reg_a7(%a6),%a4
push_loop_1203:
	lsr.l    #1,%d1
	bcc      no_push_1203
	move.w   2(%a4),-(%a2)
	subq.l   #4,%a4
	bra      push_loop_1203
no_push_1203:
	beq      push_done_1203
	subq.l   #4,%a4
	bra      push_loop_1203
push_done_1203:
	moveq.l  #0x0,%d6
	move.l   %a2,%d0
	jmp      (%a3)

|###################################################
|# pushm_word                                      #
|###################################################
	.align	1
pushm_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	addq.l   #2,%a0
	and.l    #0xffff,%d1
	lea      reg_a7(%a6),%a4
push_loop_1202:
	lsr.l    #1,%d1
	bcc      no_push_1202
	move.w   2(%a4),-(%a2)
	subq.l   #4,%a4
	bra      push_loop_1202
no_push_1202:
	beq      push_done_1202
	subq.l   #4,%a4
	bra      push_loop_1202
push_done_1202:
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# movem_to_memory_word_control                    #
|###################################################
	.align	1
movem_to_memory_word_control:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      calculate_effective_address
	and.l    #0xffff,%d1
	lea      reg_d0(%a6),%a2
push_loop_1201:
	lsr.l    #1,%d1
	bcc      no_push_1201
	move.w   2(%a2),(%a1)+
	addq.l   #4,%a2
	bra      push_loop_1201
no_push_1201:
	beq      push_done_1201
	addq.l   #4,%a2
	bra      push_loop_1201
push_done_1201:
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# ext_long                                        #
|###################################################
	.align	1
ext_long:
	bsr      read_then_write_operand_long
	ext.l    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_291:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      ext_long
	cmpi.l   #0x10,%d4
	bcs      illegal_47
	cmpi.l   #0x18,%d4
	bcs      movem_to_memory_long_control
	cmpi.l   #0x20,%d4
	bcs      illegal_47
	cmpi.l   #0x27,%d4
	bcs      movem_to_memory_predecrement_long
	cmpi.l   #0x28,%d4
	bcs      pushm_long
	cmpi.l   #0x3a,%d4
	bcs      movem_to_memory_long_control
illegal_47:
	jmp      illegal

|###################################################
|# movem_to_memory_predecrement_long               #
|###################################################
	.align	1
movem_to_memory_predecrement_long:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	and.l    #7,%d5
	ori.l    #0x08,%d5
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	and.l    #0xffff,%d1
	lea      reg_a7+4(%a6),%a4
push_loop_1206:
	lsr.l    #1,%d1
	bcc      no_push_1206
	move.l   -(%a4),-(%a2)
	bra      push_loop_1206
no_push_1206:
	beq      push_done_1206
	subq.l   #4,%a4
	bra      push_loop_1206
push_done_1206:
	moveq.l  #0x0,%d6
	move.l   %a2,%d0
	jmp      (%a3)

|###################################################
|# pushm_long                                      #
|###################################################
	.align	1
pushm_long:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	addq.l   #2,%a0
	and.l    #0xffff,%d1
	lea      reg_a7+4(%a6),%a4
push_loop_1205:
	lsr.l    #1,%d1
	bcc      no_push_1205
	move.l   -(%a4),-(%a2)
	bra      push_loop_1205
no_push_1205:
	beq      push_done_1205
	subq.l   #4,%a4
	bra      push_loop_1205
push_done_1205:
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# movem_to_memory_long_control                    #
|###################################################
	.align	1
movem_to_memory_long_control:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      calculate_effective_address
	and.l    #0xffff,%d1
	lea      reg_d0(%a6),%a2
push_loop_1204:
	lsr.l    #1,%d1
	bcc      no_push_1204
	move.l   (%a2)+,(%a1)+
	bra      push_loop_1204
no_push_1204:
	beq      push_done_1204
	addq.l   #4,%a2
	bra      push_loop_1204
push_done_1204:
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# lea_A4                                          #
|###################################################
	.align	1
lea_A4:
	bsr      calculate_effective_address
	moveq.l  #0x0,%d6
	move.l   %a1,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# extb                                            #
|###################################################
	.align	1
extb:
	bsr      read_then_write_operand_long
	extb.l   %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_295:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      extb
	cmpi.l   #0x10,%d4
	bcs      illegal_48
	cmpi.l   #0x18,%d4
	bcs      lea_A4
	cmpi.l   #0x28,%d4
	bcs      illegal_48
	cmpi.l   #0x3c,%d4
	bcs      lea_A4
illegal_48:
	jmp      illegal

|###################################################
|# tst_byte                                        #
|###################################################
	.align	1
tst_byte:
	bsr      read_operand_byte
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# tst_word                                        #
|###################################################
	.align	1
tst_word:
	bsr      read_operand_word
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# tst_long                                        #
|###################################################
	.align	1
tst_long:
	bsr      read_operand_long
	tst.l    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# tas_Dn                                          #
|###################################################
	.align	1
tas_Dn:
	bsr      read_then_write_operand_byte
	move.b   %d0,%d1
	bset     #7,%d0
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_299:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      tas_Dn
	cmpi.l   #0x10,%d4
	bcs      illegal_49
	cmpi.l   #0x3a,%d4
	bcs      tas_mem
illegal_49:
	jmp      illegal

|###################################################
|# tas_mem                                         #
|###################################################
	.align	1
tas_mem:
	bsr      calculate_effective_address
	tas      (%a1)
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# lea_A5                                          #
|###################################################
	.align	1
lea_A5:
	bsr      calculate_effective_address
	moveq.l  #0x0,%d6
	move.l   %a1,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# muls_and_mulu_long                              #
|###################################################
	.align	1
muls_and_mulu_long:
	move.w   2(%a0),%d7
	addq.l   #2,%a0
	bsr      read_operand_long
	move.l   %d0,%d3
	move.l   %d7,%d1
	lsr.l    #8,%d7
	lsr.l    #4,%d7
	andi.l   #0x7,%d7
	btst     #10,%d1
	bne.s    mul_64_bit
mul_32bit:
	btst     #11,%d1
	beq.s    mulu_32bit
	.short	0xa93c,0,0			| move.l	#0,macsr
	bra.s    mul32_common
mulu_32bit:
	.short	0xa93c,0,0x40		| move.l	#0x40,macsr
mul32_common:
	.short	0xa13c,0,0			| move.l	#0,acc
	move.l   (reg_d0,%a6,%d7.l*4),%d2
	.short	0xa602, 0x0800		| mac.l		d3,d2
	.short	0xa182				| move.l	acc,d2
	move.l   %d2,(reg_d0,%a6,%d7.l*4)
	.short	0xa9c0				| move.l	macsr,ccr
	bra      mul_done
mul_64_bit:
	move.l   %d1,%d6
	andi.l   #0x7,%d6
	move.l   %d3,-(%a7)
	move.l   (reg_d0,%a6,%d7.l*4),-(%a7)
	btst     #11,%d1
	beq.s    mulu_64bit
	jsr      _PA_muls32
	bra.s    mul_64_done
mulu_64bit:
	jsr      _PA_mulu32
mul_64_done:
	clr.l    %d1
	move.l   4(%a7),%d2
	move.l   %d2,(reg_d0,%a6,%d7.l*4)
	sne      %d1
	move.l   (%a7),(reg_d0,%a6,%d6.l*4)
	bne.s    _M68k_1566_
	tst.l    %d1
_M68k_1566_:
	lea      8(%a7),%a7
mul_done:
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# divs_and_divu_long                              #
|###################################################
	.align	1
divs_and_divu_long:
	move.w   2(%a0),%d7
	addq.l   #2,%a0
	bsr      read_operand_long
	move.l   %d0,%d3
	beq      div_long_by_zero
	move.l   %d7,%d1
	lsr.l    #8,%d7
	lsr.l    #4,%d7
	andi.l   #0x7,%d7
	move.l   %d1,%d6
	andi.l   #0x7,%d6
	btst     #11,%d1
	beq.s    divu_long
	btst     #10,%d1
	bne.s    divs_64_bit
	move.l   (reg_d0,%a6,%d7.l*4),%d1
	.long 	0x4c431802				| rems.l	d3,d2:d1
	.long 	0x4c431801				| divs.l	d3,d1
	
	move     %ccr,%d3
	bvs.s    div_overflow
	move.l   %d2,(reg_d0,%a6,%d6.l*4)
	move.l   %d1,(reg_d0,%a6,%d7.l*4)
	bra      div_done
divs_64_bit:
	move.l   (reg_d0,%a6,%d7.l*4),-(%a7)
	move.l   (reg_d0,%a6,%d6.l*4),-(%a7)
	move.l   %d3,-(%a7)
	jsr      _PA_divs64
	move     %ccr,%d3
	bvs.s    div64_overflow
	move.l   (%a7)+,(reg_d0,%a6,%d6.l*4)
	move.l   (%a7)+,(reg_d0,%a6,%d7.l*4)
	move     %ccr,%d3
	addq.l   #4,%a7
	bra      div_done
div64_overflow:
	lea      12(%a7),%a7
div_overflow:
	bra      div_done
div_long_by_zero:
	jmp      handle_divide_by_zero_exception
divu_long:
	btst     #10,%d1
	bne.s    divu_64_bit
	move.l   (reg_d0,%a6,%d7.l*4),%d1
	.long 	0x4c431002				| remu.l	d3,d2:d1
	.long 	0x4c431001				| divu.l	d3,d1
	move     %ccr,%d3
	bvs.s    div_overflow
	move.l   %d2,(reg_d0,%a6,%d6.l*4)
	move.l   %d1,(reg_d0,%a6,%d7.l*4)
	bra      div_done
divu_64_bit:
	move.l   (reg_d0,%a6,%d7.l*4),-(%a7)
	move.l   (reg_d0,%a6,%d6.l*4),-(%a7)
	move.l   %d3,-(%a7)
	jsr      _PA_divu64
	move     %ccr,%d3
	bvs.s    div64_overflow
	move.l   (%a7)+,(reg_d0,%a6,%d6.l*4)
	move.l   (%a7)+,(reg_d0,%a6,%d7.l*4)
	move     %ccr,%d3
	addq.l   #4,%a7
div_done:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# movem_from_memory_postincrement_word            #
|###################################################
	.align	1
movem_from_memory_postincrement_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	and.l    #7,%d5
	ori.l    #0x08,%d5
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	and.l    #0xffff,%d1
	lea      reg_d0(%a6),%a4
pop_loop_1209:
	lsr.l    #1,%d1
	bcc      no_pop_1209
	move.w   (%a2)+,%a5
	move.l   %a5,(%a4)+
	bra      pop_loop_1209
no_pop_1209:
	beq      pop_done_1209
	addq.l   #4,%a4
	bra      pop_loop_1209
pop_done_1209:
	moveq.l  #0x0,%d6
	move.l   %a2,%d0
	jmp      (%a3)

|###################################################
|# popm_word                                       #
|###################################################
	.align	1
popm_word:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	addq.l   #2,%a0
	and.l    #0xffff,%d1
	lea      reg_d0(%a6),%a4
pop_loop_1208:
	lsr.l    #1,%d1
	bcc      no_pop_1208
	move.w   (%a2)+,%a5
	move.l   %a5,(%a4)+
	bra      pop_loop_1208
no_pop_1208:
	beq      pop_done_1208
	addq.l   #4,%a4
	bra      pop_loop_1208
pop_done_1208:
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# movem_from_memory_word_control                  #
|###################################################
	.align	1
movem_from_memory_word_control:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      calculate_effective_address
	and.l    #0xffff,%d1
	lea      reg_d0(%a6),%a2
pop_loop_1207:
	lsr.l    #1,%d1
	bcc      no_pop_1207
	move.w   (%a1)+,%a4
	move.l   %a4,(%a2)+
	bra      pop_loop_1207
no_pop_1207:
	beq      pop_done_1207
	addq.l   #4,%a2
	bra      pop_loop_1207
pop_done_1207:
	moveq.l  #0x0,%d6
	jmp      exception_handled
second_level_dispatch_306:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x10,%d4
	bcs      illegal_50
	cmpi.l   #0x18,%d4
	bcs      movem_from_memory_word_control
	cmpi.l   #0x1f,%d4
	bcs      movem_from_memory_postincrement_word
	cmpi.l   #0x20,%d4
	bcs      popm_word
	cmpi.l   #0x28,%d4
	bcs      illegal_50
	cmpi.l   #0x3c,%d4
	bcs      movem_from_memory_word_control
illegal_50:
	jmp      illegal

|###################################################
|# movem_from_memory_postincrement_long            #
|###################################################
	.align	1
movem_from_memory_postincrement_long:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	and.l    #7,%d5
	ori.l    #0x08,%d5
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	and.l    #0xffff,%d1
	lea      reg_d0(%a6),%a4
pop_loop_1212:
	lsr.l    #1,%d1
	bcc      no_pop_1212
	move.l   (%a2)+,(%a4)+
	bra      pop_loop_1212
no_pop_1212:
	beq      pop_done_1212
	addq.l   #4,%a4
	bra      pop_loop_1212
pop_done_1212:
	moveq.l  #0x0,%d6
	move.l   %a2,%d0
	jmp      (%a3)

|###################################################
|# popm_long                                       #
|###################################################
	.align	1
popm_long:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	jsr      compute_reg_a7
#if 1        // fix stack on odd address
	moveq    #1,%d0
	add.l   reg_a7(%a6),%d0
	bclr     #0,%d0
	move.l   %d0,%a2
#else
	move.l   reg_a7(%a6),%a2
#endif
	addq.l   #2,%a0
	and.l    #0xffff,%d1
	lea      reg_d0(%a6),%a4
pop_loop_1211:
	lsr.l    #1,%d1
	bcc      no_pop_1211
	move.l   (%a2)+,(%a4)+
	bra      pop_loop_1211
no_pop_1211:
	beq      pop_done_1211
	addq.l   #4,%a4
	bra      pop_loop_1211
pop_done_1211:
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# movem_from_memory_long_control                  #
|###################################################
	.align	1
movem_from_memory_long_control:
	move.w   2(%a0),%d1
	addq.l   #2,%a0
	bsr      calculate_effective_address
	and.l    #0xffff,%d1
	lea      reg_d0(%a6),%a2
pop_loop_1210:
	lsr.l    #1,%d1
	bcc      no_pop_1210
	move.l   (%a1)+,(%a2)+
	bra      pop_loop_1210
no_pop_1210:
	beq      pop_done_1210
	addq.l   #4,%a2
	bra      pop_loop_1210
pop_done_1210:
	moveq.l  #0x0,%d6
	jmp      exception_handled
second_level_dispatch_307:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x10,%d4
	bcs      illegal_51
	cmpi.l   #0x18,%d4
	bcs      movem_from_memory_long_control
	cmpi.l   #0x1f,%d4
	bcs      movem_from_memory_postincrement_long
	cmpi.l   #0x20,%d4
	bcs      popm_long
	cmpi.l   #0x28,%d4
	bcs      illegal_51
	cmpi.l   #0x3c,%d4
	bcs      movem_from_memory_long_control
illegal_51:
	jmp      illegal

|###################################################
|# lea_A6                                          #
|###################################################
	.align	1
lea_A6:
	bsr      calculate_effective_address
	moveq.l  #0x0,%d6
	move.l   %a1,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# escape                                          #
|###################################################
	.align	1
escape:
	addq.l   #2,%a0
	jmp      dispatch_instruction

|###################################################
|# rtd                                             #
|###################################################
	.align	1
rtd:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	.long 	0x73680002               // mvs.w 2(%a0),%d1
	move.l   (%a2)+,%a0
	adda.l   %d1,%a2
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# trapv                                           #
|###################################################
	.align	1
trapv:
	addq.l   #2,%a0
	move.b   reg_XNZVC(%a6),%d1
	move.w   %d1,%CCR
	bvc.s    no_trapv
	move.l   %a0,reg_pc(%a6)
	moveq.l  #7,%d1
	jmp      handle_680x0_exception
no_trapv:
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# movec_to_Rc                                     #
|###################################################
	.align	1
movec_to_Rc:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1550
	jmp      handle_privilege_violation_exception
priv_ok_1550:
	move.w   2(%a0),%d5
	lsr.l    #8,%d5
	lsr.l    #4,%d5
	andi.l   #0x000f,%d5
	bsr      read_operand_long
	moveq.l  #0,%d6
	move.w   (%a0)+,%d3
	and.l    #0x0fff,%d3
	cmpi.l   #0x800,%d3
	beq      movec_to_USP
	cmpi.l   #0x801,%d3
	beq      movec_to_VBR
	cmpi.l   #0x000,%d3
	beq      movec_to_SFC
	cmpi.l   #0x001,%d3
	beq      movec_to_DFC
	cmpi.l   #0x002,%d3
	beq      movec_to_CACR
	cmpi.l   #0x003,%d3
	beq      movec_to_TC
	cmpi.l   #0x004,%d3
	beq      movec_to_ITT0
	cmpi.l   #0x005,%d3
	beq      movec_to_ITT1
	cmpi.l   #0x006,%d3
	beq      movec_to_DTT0
	cmpi.l   #0x007,%d3
	beq      movec_to_DTT1
	cmpi.l   #0x806,%d3
	beq      movec_to_URP
	cmpi.l   #0x807,%d3
	beq      movec_to_SRP
	cmpi.l   #0x008,%d3
	beq      movec_to_BUSCR
	cmpi.l   #0x808,%d3
	beq      movec_to_PCR
	subq.l   #4,%a0
	jmp      illegal
movec_to_USP:
	move.l   %d0,reg_usp(%a6)
	bra      movec_to_Rc_done
movec_to_VBR:
	move.l   %d0,reg_vbr(%a6)
	bra      movec_to_Rc_done
movec_to_SFC:
	andi.l   #0x7,%d0
	move.l   %d0,reg_sfc(%a6)
	bra      movec_to_Rc_done
movec_to_DFC:
	andi.l   #0x7,%d0
	move.l   %d0,reg_dfc(%a6)
	bra      movec_to_Rc_done
movec_to_CACR:
	move.l   %d0,reg_cacr(%a6)
	bra      movec_to_Rc_done
movec_to_TC:
	move.l   %d0,reg_tc(%a6)
	bra      movec_to_Rc_done
movec_to_ITT0:
	move.l   %d0,reg_itt0(%a6)
	bra      movec_to_Rc_done
movec_to_ITT1:
	move.l   %d0,reg_itt1(%a6)
	bra      movec_to_Rc_done
movec_to_DTT0:
	move.l   %d0,reg_dtt0(%a6)
	bra      movec_to_Rc_done
movec_to_DTT1:
	move.l   %d0,reg_dtt1(%a6)
	bra      movec_to_Rc_done
movec_to_URP:
	move.l   %d0,reg_urp(%a6)
	bra      movec_to_Rc_done
movec_to_SRP:
	move.l   %d0,reg_srp(%a6)
	bra      movec_to_Rc_done
movec_to_BUSCR:
	move.l   %d0,reg_buscr(%a6)
	bra      movec_to_Rc_done
movec_to_PCR:
	move.l   %d0,reg_pcr(%a6)
	bra      movec_to_Rc_done
	nop      
movec_to_Rc_done:
	lea      -16(%a7),%a7
	movem.l  %d6-%d7/%a0/%a6,(%a7)
	move.l   -4(%a0),%d0
	move.l   %a6,%a0
	jsr      cf68k_write_control_register
	movem.l  (%a7),%d6-%d7/%a0/%a6
	lea      16(%a7),%a7
	jmp      exception_handled

|###################################################
|# movec_from_Rc                                   #
|###################################################
	.align	1
movec_from_Rc:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1549
	jmp      handle_privilege_violation_exception
priv_ok_1549:
	lea      -12(%a7),%a7
	movem.l  %d5/%a0/%a6,(%a7)
	move.l   (%a0),%d0
	move.l   %a6,%a0
	jsr      cf68k_read_control_register
	movem.l  (%a7),%d5/%a0/%a6
	lea      12(%a7),%a7
	addq.l   #2,%a0
	move.w   0(%a0),%d5
	move.w   %d5,%d3
	lsr.l    #8,%d5
	lsr.l    #4,%d5
	andi.l   #0x000f,%d5
	moveq.l  #0,%d6
	and.l    #0x0fff,%d3
	cmpi.l   #0x800,%d3
	beq      movec_from_USP
	cmpi.l   #0x801,%d3
	beq      movec_from_VBR
	cmpi.l   #0x000,%d3
	beq      movec_from_SFC
	cmpi.l   #0x001,%d3
	beq      movec_from_DFC
	cmpi.l   #0x002,%d3
	beq      movec_from_CACR
	cmpi.l   #0x003,%d3
	beq      movec_from_TC
	cmpi.l   #0x004,%d3
	beq      movec_from_ITT0
	cmpi.l   #0x005,%d3
	beq      movec_from_ITT1
	cmpi.l   #0x006,%d3
	beq      movec_from_DTT0
	cmpi.l   #0x007,%d3
	beq      movec_from_DTT1
	cmpi.l   #0x806,%d3
	beq      movec_from_URP
	cmpi.l   #0x807,%d3
	beq      movec_from_SRP
	cmpi.l   #0x008,%d3
	beq      movec_from_BUSCR
	cmpi.l   #0x808,%d3
	beq      movec_from_PCR
	subq.l   #2,%a0
	jmp      illegal
movec_from_USP:
	move.l   reg_usp(%a6),%d0
	jmp      store_operand_long
movec_from_VBR:
	move.l   reg_vbr(%a6),%d0
	jmp      store_operand_long
movec_from_SFC:
	move.l   reg_sfc(%a6),%d0
	andi.l   #0x7,%d0
	jmp      store_operand_long
movec_from_DFC:
	move.l   reg_dfc(%a6),%d0
	andi.l   #0x7,%d0
	jmp      store_operand_long
movec_from_CACR:
	move.l   reg_cacr(%a6),%d0
	jmp      store_operand_long
movec_from_TC:
	move.l   reg_tc(%a6),%d0
	jmp      store_operand_long
movec_from_ITT0:
	move.l   reg_itt0(%a6),%d0
	jmp      store_operand_long
movec_from_ITT1:
	move.l   reg_itt1(%a6),%d0
	jmp      store_operand_long
movec_from_DTT0:
	move.l   reg_dtt0(%a6),%d0
	jmp      store_operand_long
movec_from_DTT1:
	move.l   reg_dtt1(%a6),%d0
	jmp      store_operand_long
movec_from_URP:
	move.l   reg_urp(%a6),%d0
	jmp      store_operand_long
movec_from_SRP:
	move.l   reg_srp(%a6),%d0
	jmp      store_operand_long
movec_from_BUSCR:
	move.l   reg_buscr(%a6),%d0
	jmp      store_operand_long
movec_from_PCR:
	move.l   reg_pcr(%a6),%d0
	jmp      store_operand_long

|###################################################
|# rte                                             #
|###################################################
	.align	1
rte:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1548
	jmp      handle_privilege_violation_exception
priv_ok_1548:
	jmp      handle_rte

|###################################################
|# move_from_usp                                   #
|###################################################
	.align	1
move_from_usp:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1547
	jmp      handle_privilege_violation_exception
priv_ok_1547:
	addq.l   #2,%a0
	and.l    #7,%d5
	moveq.l  #0,%d6
	move.l   (reg_usp,%a6),%d0
	move.l   %d0,(reg_a0,%a6,%d5.l*4)
	jmp      exception_handled

|###################################################
|# move_to_usp                                     #
|###################################################
	.align	1
move_to_usp:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1546
	jmp      handle_privilege_violation_exception
priv_ok_1546:
	addq.l   #2,%a0
	and.l    #7,%d5
	moveq.l  #0,%d6
	move.l   (reg_a0,%a6,%d5.l*4),%d0
	move.l   %d0,(reg_usp,%a6)
	jmp      exception_handled

|###################################################
|# reset                                           #
|###################################################
	.align	1
reset:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1545
	jmp      handle_privilege_violation_exception
priv_ok_1545:
	jmp      exception_handled

|###################################################
|# stop                                            #
|###################################################
	.align	1
stop:
	btst     #5,reg_sr(%a6)
	bne.s    priv_ok_1544
	jmp      handle_privilege_violation_exception
priv_ok_1544:
	jmp      handle_stop

|###################################################
|# unlk                                            #
|###################################################
	.align	1
unlk:
	and.l    #7,%d5
	ori.l    #0x08,%d5
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	move.l   (%a2)+,%d0
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      (%a3)

|###################################################
|# rtr                                             #
|###################################################
	.align	1
rtr:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.w   (%a2)+,%d1
	move.l   (%a2)+,%a0
	move.w   %d1,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# _nop                                            #
|###################################################
	.align	1
_nop:
	addq.l   #2,%a0
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# link_word                                       #
|###################################################
	.align	1
link_word:
	and.l    #7,%d5
	ori.l    #0x08,%d5
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	move.w   (%a0)+,%d1
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a4
	move.l   %a2,-(%a4)
	move.l   %a4,%a2
	ext.l    %d1
	add.l    %d1,%a4
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a4,reg_a7(%a6)
	move.l   %a2,%d0
	jmp      (%a3)

|###################################################
|# rts                                             #
|###################################################
	.align	1
second_level_dispatch_313:
	cmpi.l   #0x4e75,%d5
	bne      dispatch_second_others_313
rts:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.l   (%a2)+,%a0
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled
dispatch_second_others_313:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x10,%d4
	bcs      illegal_52
	cmpi.l   #0x18,%d4
	bcs      link_word
	cmpi.l   #0x20,%d4
	bcs      unlk
	cmpi.l   #0x28,%d4
	bcs      move_to_usp
	cmpi.l   #0x30,%d4
	bcs      move_from_usp
	cmpi.l   #0x31,%d4
	bcs      reset
	cmpi.l   #0x32,%d4
	bcs      _nop
	cmpi.l   #0x33,%d4
	bcs      stop
	cmpi.l   #0x34,%d4
	bcs      rte
	cmpi.l   #0x35,%d4
	bcs      rtd
	cmpi.l   #0x36,%d4
	bcs      rts
	cmpi.l   #0x37,%d4
	bcs      trapv
	cmpi.l   #0x38,%d4
	bcs      rtr
	cmpi.l   #0x3a,%d4
	bcs      illegal_52
	cmpi.l   #0x3b,%d4
	bcs      movec_from_Rc
	cmpi.l   #0x3c,%d4
	bcs      movec_to_Rc
illegal_52:
	jmp      illegal

|###################################################
|# jsr                                             #
|###################################################
	.align	1
jsr:
	bsr      calculate_effective_address
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.l   %a0,(%a2)
	movea.l  %a1,%a0
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# jmp                                             #
|###################################################
	.align	1
jmp:
	bsr      calculate_effective_address
	movea.l  %a1,%a0
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# lea_A7                                          #
|###################################################
	.align	1
lea_A7:
	bsr      calculate_effective_address
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a1,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# add_quick_byte_8                                #
|###################################################
	.align	1
add_quick_byte_8:
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d1
	lsl.l    %d1,%d0
	addi.l   #(8<<24),%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d1,%d0
	jmp      (%a3)

|###################################################
|# add_quick_8_An                                  #
|###################################################
	.align	1
add_quick_8_An:
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	adda.l   #8,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,%d0
	jmp      (%a3)

|###################################################
|# add_quick_word_8                                #
|###################################################
	.align	1
second_level_dispatch_321:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_word_8
	cmpi.l   #0x10,%d4
	bcs      add_quick_8_An
	cmpi.l   #0x3d,%d4
	bcc      illegal_53
add_quick_word_8:
	bsr      read_then_write_operand_word
	moveq.l  #16,%d1
	lsl.l    %d1,%d0
	addi.l   #(8<<16),%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d1,%d0
	jmp      (%a3)

|###################################################
|# add_quick_long_8                                #
|###################################################
	.align	1
second_level_dispatch_322:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_long_8
	cmpi.l   #0x10,%d4
	bcs      add_quick_8_An
	cmpi.l   #0x3d,%d4
	bcc      illegal_53
add_quick_long_8:
	bsr      read_then_write_operand_long
	addq.l   #8,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# trapcc_t                                        #
|###################################################
	.align	1
trapcc_t:
	and.l    #3,%d5
	addq.l   #3,%d5
	bclr     #0,%d5
	add.l    %d5,%a0
	move.l   %a0,reg_pc(%a6)
	moveq.l  #7,%d1
	jmp      handle_680x0_exception

|###################################################
|# scc_t                                           #
|###################################################
	.align	1
second_level_dispatch_323:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_t
	cmpi.l   #0x10,%d4
	bcs      dbcc_t
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_323
scc_t:
	moveq.l  #-1,%d0
	moveq.l  #0x0,%d6
	bra      store_operand_byte
dispatch_second_others_323:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_t
illegal_53:
	jmp      illegal

|###################################################
|# dbcc_t                                          #
|###################################################
	.align	1
dbcc_t:
	addq.l   #4,%a0
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# sub_quick_byte_8                                #
|###################################################
	.align	1
sub_quick_byte_8:
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d1
	lsl.l    %d1,%d0
	subi.l   #(8<<24),%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d1,%d0
	jmp      (%a3)

|###################################################
|# sub_quick_8_An                                  #
|###################################################
	.align	1
sub_quick_8_An:
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	subq.l   #8,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,%d0
	jmp      (%a3)

|###################################################
|# sub_quick_word_8                                #
|###################################################
	.align	1
second_level_dispatch_325:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_word_8
	cmpi.l   #0x10,%d4
	bcs      sub_quick_8_An
	cmpi.l   #0x3d,%d4
	bcc      illegal_54
sub_quick_word_8:
	bsr      read_then_write_operand_word
	moveq.l  #16,%d1
	lsl.l    %d1,%d0
	subi.l   #(8<<16),%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d1,%d0
	jmp      (%a3)

|###################################################
|# sub_quick_long_8                                #
|###################################################
	.align	1
second_level_dispatch_326:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_long_8
	cmpi.l   #0x10,%d4
	bcs      sub_quick_8_An
	cmpi.l   #0x3d,%d4
	bcc      illegal_54
sub_quick_long_8:
	bsr      read_then_write_operand_long
	subq.l   #8,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# trapcc_f                                        #
|###################################################
	.align	1
trapcc_f:
	and.l    #3,%d5
	addq.l   #3,%d5
	bclr     #0,%d5
	add.l    %d5,%a0
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# scc_f                                           #
|###################################################
	.align	1
second_level_dispatch_327:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_f
	cmpi.l   #0x10,%d4
	bcs      dbcc_f
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_327
scc_f:
	clr.l    %d0
	moveq.l  #0x0,%d6
	bra      store_operand_byte
dispatch_second_others_327:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_f
illegal_54:
	jmp      illegal

|###################################################
|# dbcc_f                                          #
|###################################################
	.align	1
dbcc_f:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	addq.l   #4,%a0
dbcc_may_loop:
	and.l    #7,%d5
	move.w   (reg_d0+2,%a6,%d5.l*4),%d1
	bne      dbcc_will_loop
	moveq.l  #-1,%d1
	move.w   %d1,(reg_d0+2,%a6,%d5.l*4)
	bra      dbcc_done
dbcc_will_loop:
	subq.l   #1,%d1
	move.w   %d1,(reg_d0+2,%a6,%d5.l*4)
	move.w   -(%a0),%d1
	ext.l    %d1
	adda.l   %d1,%a0
dbcc_done:
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# add_quick_byte                                  #
|###################################################
	.align	1
add_quick_byte:
	move.l   %d5,%d1
	lsr.l    #8,%d1
	lsr.l    #1,%d1
	and.l    #7,%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# add_quick_An                                    #
|###################################################
	.align	1
add_quick_An:
	move.l   %d5,%d1
	lsr.l    #8,%d1
	lsr.l    #1,%d1
	and.l    #7,%d1
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	adda.l   %d1,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,%d0
	jmp      (%a3)
second_level_dispatch_337:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_word
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_word
illegal_57:
	jmp      illegal

|###################################################
|# add_quick_word                                  #
|###################################################
	.align	1
second_level_dispatch_329:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_word
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcc      illegal_55
add_quick_word:
	move.l   %d5,%d1
	lsr.l    #8,%d1
	lsr.l    #1,%d1
	and.l    #7,%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# add_quick_long                                  #
|###################################################
	.align	1
second_level_dispatch_330:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_long
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcc      illegal_55
add_quick_long:
	move.l   %d5,%d1
	lsr.l    #8,%d1
	lsr.l    #1,%d1
	and.l    #7,%d1
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# trapcc_hi                                       #
|###################################################
	.align	1
trapcc_hi:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bhi      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_hi                                          #
|###################################################
	.align	1
second_level_dispatch_331:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_hi
	cmpi.l   #0x10,%d4
	bcs      dbcc_hi
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_331
scc_hi:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bhi      scc_t
	bra      scc_f
dispatch_second_others_331:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_hi
illegal_55:
	jmp      illegal

|###################################################
|# dbcc_hi                                         #
|###################################################
	.align	1
dbcc_hi:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bls      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# sub_quick_byte                                  #
|###################################################
	.align	1
sub_quick_byte:
	move.l   %d5,%d1
	lsr.l    #8,%d1
	lsr.l    #1,%d1
	and.l    #7,%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# sub_quick_An                                    #
|###################################################
	.align	1
sub_quick_An:
	move.l   %d5,%d1
	lsr.l    #8,%d1
	lsr.l    #1,%d1
	and.l    #7,%d1
	bsr      read_then_write_operand_long
	move.l   %d0,%a2
	suba.l   %d1,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,%d0
	jmp      (%a3)
second_level_dispatch_341:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_word
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_word
illegal_60:
	jmp      illegal

|###################################################
|# sub_quick_word                                  #
|###################################################
	.align	1
second_level_dispatch_333:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_word
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcc      illegal_56
sub_quick_word:
	move.l   %d5,%d1
	lsr.l    #8,%d1
	lsr.l    #1,%d1
	and.l    #7,%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# sub_quick_long                                  #
|###################################################
	.align	1
second_level_dispatch_334:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_long
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcc      illegal_56
sub_quick_long:
	move.l   %d5,%d1
	lsr.l    #8,%d1
	lsr.l    #1,%d1
	and.l    #7,%d1
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# trapcc_ls                                       #
|###################################################
	.align	1
trapcc_ls:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bls      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_ls                                          #
|###################################################
	.align	1
second_level_dispatch_335:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_ls
	cmpi.l   #0x10,%d4
	bcs      dbcc_ls
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_335
scc_ls:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bls      scc_t
	bra      scc_f
dispatch_second_others_335:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_ls
illegal_56:
	jmp      illegal

|###################################################
|# dbcc_ls                                         #
|###################################################
	.align	1
dbcc_ls:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bhi      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_cc                                       #
|###################################################
	.align	1
trapcc_cc:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bcc      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_cc                                          #
|###################################################
	.align	1
second_level_dispatch_339:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_cc
	cmpi.l   #0x10,%d4
	bcs      dbcc_cc
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_339
scc_cc:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bcc      scc_t
	bra      scc_f
dispatch_second_others_339:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_cc
illegal_59:
	jmp      illegal

|###################################################
|# dbcc_cc                                         #
|###################################################
	.align	1
dbcc_cc:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bcs      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_cs                                       #
|###################################################
	.align	1
trapcc_cs:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bcs      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_cs                                          #
|###################################################
	.align	1
second_level_dispatch_343:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_cs
	cmpi.l   #0x10,%d4
	bcs      dbcc_cs
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_343
scc_cs:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bcs      scc_t
	bra      scc_f
dispatch_second_others_343:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_cs
illegal_62:
	jmp      illegal

|###################################################
|# dbcc_cs                                         #
|###################################################
	.align	1
dbcc_cs:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bcc      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_ne                                       #
|###################################################
	.align	1
trapcc_ne:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bne      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_ne                                          #
|###################################################
	.align	1
second_level_dispatch_347:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_ne
	cmpi.l   #0x10,%d4
	bcs      dbcc_ne
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_347
scc_ne:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bne      scc_t
	bra      scc_f
dispatch_second_others_347:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_ne
illegal_65:
	jmp      illegal

|###################################################
|# dbcc_ne                                         #
|###################################################
	.align	1
dbcc_ne:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	beq      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_eq                                       #
|###################################################
	.align	1
trapcc_eq:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	beq      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_eq                                          #
|###################################################
	.align	1
second_level_dispatch_351:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_eq
	cmpi.l   #0x10,%d4
	bcs      dbcc_eq
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_351
scc_eq:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	beq      scc_t
	bra      scc_f
dispatch_second_others_351:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_eq
illegal_68:
	jmp      illegal

|###################################################
|# dbcc_eq                                         #
|###################################################
	.align	1
dbcc_eq:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bne      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_vc                                       #
|###################################################
	.align	1
trapcc_vc:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bvc      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_vc                                          #
|###################################################
	.align	1
second_level_dispatch_355:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_vc
	cmpi.l   #0x10,%d4
	bcs      dbcc_vc
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_355
scc_vc:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bvc      scc_t
	bra      scc_f
dispatch_second_others_355:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_vc
illegal_71:
	jmp      illegal

|###################################################
|# dbcc_vc                                         #
|###################################################
	.align	1
dbcc_vc:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bvs      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_vs                                       #
|###################################################
	.align	1
trapcc_vs:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bvs      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_vs                                          #
|###################################################
	.align	1
second_level_dispatch_359:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_vs
	cmpi.l   #0x10,%d4
	bcs      dbcc_vs
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_359
scc_vs:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bvs      scc_t
	bra      scc_f
dispatch_second_others_359:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_vs
illegal_74:
	jmp      illegal

|###################################################
|# dbcc_vs                                         #
|###################################################
	.align	1
dbcc_vs:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bvc      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_pl                                       #
|###################################################
	.align	1
trapcc_pl:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bpl      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_pl                                          #
|###################################################
	.align	1
second_level_dispatch_363:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_pl
	cmpi.l   #0x10,%d4
	bcs      dbcc_pl
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_363
scc_pl:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bpl      scc_t
	bra      scc_f
dispatch_second_others_363:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_pl
illegal_77:
	jmp      illegal

|###################################################
|# dbcc_pl                                         #
|###################################################
	.align	1
dbcc_pl:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bmi      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_mi                                       #
|###################################################
	.align	1
trapcc_mi:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bmi      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_mi                                          #
|###################################################
	.align	1
second_level_dispatch_367:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_mi
	cmpi.l   #0x10,%d4
	bcs      dbcc_mi
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_367
scc_mi:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bmi      scc_t
	bra      scc_f
dispatch_second_others_367:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_mi
illegal_80:
	jmp      illegal

|###################################################
|# dbcc_mi                                         #
|###################################################
	.align	1
dbcc_mi:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bpl      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_ge                                       #
|###################################################
	.align	1
trapcc_ge:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bge      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_ge                                          #
|###################################################
	.align	1
second_level_dispatch_371:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_ge
	cmpi.l   #0x10,%d4
	bcs      dbcc_ge
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_371
scc_ge:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bge      scc_t
	bra      scc_f
dispatch_second_others_371:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_ge
illegal_83:
	jmp      illegal

|###################################################
|# dbcc_ge                                         #
|###################################################
	.align	1
dbcc_ge:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	blt      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_lt                                       #
|###################################################
	.align	1
trapcc_lt:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	blt      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_lt                                          #
|###################################################
	.align	1
second_level_dispatch_375:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_lt
	cmpi.l   #0x10,%d4
	bcs      dbcc_lt
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_375
scc_lt:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	blt      scc_t
	bra      scc_f
dispatch_second_others_375:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_lt
illegal_86:
	jmp      illegal

|###################################################
|# dbcc_lt                                         #
|###################################################
	.align	1
dbcc_lt:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bge      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_gt                                       #
|###################################################
	.align	1
trapcc_gt:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	bgt      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_gt                                          #
|###################################################
	.align	1
second_level_dispatch_379:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_gt
	cmpi.l   #0x10,%d4
	bcs      dbcc_gt
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_379
scc_gt:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bgt      scc_t
	bra      scc_f
dispatch_second_others_379:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_gt
illegal_89:
	jmp      illegal

|###################################################
|# dbcc_gt                                         #
|###################################################
	.align	1
dbcc_gt:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	ble      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# trapcc_le                                       #
|###################################################
	.align	1
trapcc_le:
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	ble      trapcc_t
	bra      trapcc_f

|###################################################
|# scc_le                                          #
|###################################################
	.align	1
second_level_dispatch_383:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      scc_le
	cmpi.l   #0x10,%d4
	bcs      dbcc_le
	cmpi.l   #0x3a,%d4
	bcc      dispatch_second_others_383
scc_le:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	ble      scc_t
	bra      scc_f
dispatch_second_others_383:
	cmpi.l   #0x3d,%d4
	bcs      trapcc_le
illegal_92:
	jmp      illegal

|###################################################
|# dbcc_le                                         #
|###################################################
	.align	1
dbcc_le:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addq.l   #4,%a0
	bgt      dbcc_may_loop
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# bra                                             #
|###################################################
	.align	1
bra:
	addq.l   #2,%a0
	extb.l   %d5
	beq      bra16
	cmp.l    #-1,%d5
	beq      bra32
	adda.l   %d5,%a0
	bra      bra_done
bra32:
	adda.l   (%a0),%a0
	bra      bra_done
bra16:
	.short	0x7350                   // mvs.w (%a0),%d1
	adda.l   %d1,%a0
bra_done:
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# bsr                                             #
|###################################################
	.align	1
bsr:
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	addq.l   #2,%a0
	extb.l   %d5
	beq      bsr16
	cmpi.l   #-1,%d5
	beq      bsr32
	move.l   %a0,-(%a2)
	adda.l   %d5,%a0
	bra      bsr_done
bsr16:
	.short	0x7358                   // mvs.w (%a0)+,%d1
	move.l   %a0,-(%a2)
	lea      -2(%a0,%d1.l),%a0
	bra      bsr_done
bsr32:
	move.l   (%a0)+,%d1
	move.l   %a0,-(%a2)
	lea      -4(%a0,%d1.l),%a0
bsr_done:
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# bcc_hi                                          #
|###################################################
	.align	1
bcc_hi:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bls      branch_not_taken
	bra      bra

|###################################################
|# bcc_ls                                          #
|###################################################
	.align	1
bcc_ls:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bhi      branch_not_taken
	bra      bra

|###################################################
|# bcc_cc                                          #
|###################################################
	.align	1
bcc_cc:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bcs      branch_not_taken
	bra      bra

|###################################################
|# bcc_cs                                          #
|###################################################
	.align	1
bcc_cs:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bcc      branch_not_taken
	bra      bra

|###################################################
|# bcc_ne                                          #
|###################################################
	.align	1
bcc_ne:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bne      bra
branch_not_taken:
	addq.l   #4,%a0
	and.l    #0x00ff,%d5
	beq      branch_not_taken_done
	lea      -2(%a0),%a0
	cmpi.l   #0x00ff,%d5
	bne      branch_not_taken_done
	addq.l   #4,%a0
branch_not_taken_done:
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# bcc_eq                                          #
|###################################################
	.align	1
bcc_eq:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bne      branch_not_taken
	bra      bra

|###################################################
|# bcc_vc                                          #
|###################################################
	.align	1
bcc_vc:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bvs      branch_not_taken
	bra      bra

|###################################################
|# bcc_vs                                          #
|###################################################
	.align	1
bcc_vs:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bvc      branch_not_taken
	bra      bra

|###################################################
|# bcc_pl                                          #
|###################################################
	.align	1
bcc_pl:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bmi      branch_not_taken
	bra      bra

|###################################################
|# bcc_mi                                          #
|###################################################
	.align	1
bcc_mi:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bpl      branch_not_taken
	bra      bra

|###################################################
|# bcc_ge                                          #
|###################################################
	.align	1
bcc_ge:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	blt      branch_not_taken
	bra      bra

|###################################################
|# bcc_lt                                          #
|###################################################
	.align	1
bcc_lt:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bge      branch_not_taken
	bra      bra

|###################################################
|# bcc_gt                                          #
|###################################################
	.align	1
bcc_gt:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	ble      branch_not_taken
	bra      bra

|###################################################
|# bcc_le                                          #
|###################################################
	.align	1
bcc_le:
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	bgt      branch_not_taken
	bra      bra

|###################################################
|# moveq_D0                                        #
|###################################################
	.align	1
moveq_D0:
	addq.l   #2,%a0
	extb.l   %d5
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d5,reg_d0(%a6)
	jmp      exception_handled

|###################################################
|# moveq_D1                                        #
|###################################################
	.align	1
moveq_D1:
	addq.l   #2,%a0
	extb.l   %d5
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d5,reg_d1(%a6)
	jmp      exception_handled

|###################################################
|# moveq_D2                                        #
|###################################################
	.align	1
moveq_D2:
	addq.l   #2,%a0
	extb.l   %d5
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d5,reg_d2(%a6)
	jmp      exception_handled

|###################################################
|# moveq_D3                                        #
|###################################################
	.align	1
moveq_D3:
	addq.l   #2,%a0
	extb.l   %d5
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d5,reg_d3(%a6)
	jmp      exception_handled

|###################################################
|# moveq_D4                                        #
|###################################################
	.align	1
moveq_D4:
	addq.l   #2,%a0
	extb.l   %d5
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d5,reg_d4(%a6)
	jmp      exception_handled

|###################################################
|# moveq_D5                                        #
|###################################################
	.align	1
moveq_D5:
	addq.l   #2,%a0
	extb.l   %d5
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d5,reg_d5(%a6)
	jmp      exception_handled

|###################################################
|# moveq_D6                                        #
|###################################################
	.align	1
moveq_D6:
	addq.l   #2,%a0
	extb.l   %d5
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d5,reg_d6(%a6)
	jmp      exception_handled

|###################################################
|# moveq_D7                                        #
|###################################################
	.align	1
moveq_D7:
	addq.l   #2,%a0
	extb.l   %d5
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d5,reg_d7(%a6)
	jmp      exception_handled

|###################################################
|# or_byte_ea_to_D0                                #
|###################################################
	.align	1
or_byte_ea_to_D0:
	bsr      read_operand_byte
	move.b   reg_d0+3(%a6),%d1
	or.l     %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d0+3(%a6)
	jmp      exception_handled

|###################################################
|# or_word_ea_to_D0                                #
|###################################################
	.align	1
or_word_ea_to_D0:
	bsr      read_operand_word
	move.w   reg_d0+2(%a6),%d1
	or.l     %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d0+2(%a6)
	jmp      exception_handled

|###################################################
|# index_68020_handlers                            #
|###################################################
	.align	2
index_68020_handlers:
index_68020_0x0:
	movea.w  reg_d0+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x1:
	movea.w  reg_d0+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x2:
	movea.w  reg_d0+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x3:
	movea.w  reg_d0+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x4:
	movea.w  reg_d0+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x5:
	movea.w  reg_d0+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x6:
	movea.w  reg_d0+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x7:
	movea.w  reg_d0+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x8:
	movea.l  reg_d0(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x9:
	movea.l  reg_d0(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xa:
	movea.l  reg_d0(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xb:
	movea.l  reg_d0(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xc:
	movea.l  reg_d0(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xd:
	movea.l  reg_d0(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xe:
	movea.l  reg_d0(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xf:
	movea.l  reg_d0(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x10:
	movea.w  reg_d1+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x11:
	movea.w  reg_d1+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x12:
	movea.w  reg_d1+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x13:
	movea.w  reg_d1+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x14:
	movea.w  reg_d1+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x15:
	movea.w  reg_d1+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x16:
	movea.w  reg_d1+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x17:
	movea.w  reg_d1+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x18:
	movea.l  reg_d1(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x19:
	movea.l  reg_d1(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x1a:
	movea.l  reg_d1(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x1b:
	movea.l  reg_d1(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x1c:
	movea.l  reg_d1(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x1d:
	movea.l  reg_d1(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x1e:
	movea.l  reg_d1(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x1f:
	movea.l  reg_d1(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x20:
	movea.w  reg_d2+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x21:
	movea.w  reg_d2+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x22:
	movea.w  reg_d2+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x23:
	movea.w  reg_d2+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x24:
	movea.w  reg_d2+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x25:
	movea.w  reg_d2+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x26:
	movea.w  reg_d2+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x27:
	movea.w  reg_d2+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x28:
	movea.l  reg_d2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x29:
	movea.l  reg_d2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x2a:
	movea.l  reg_d2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x2b:
	movea.l  reg_d2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x2c:
	movea.l  reg_d2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x2d:
	movea.l  reg_d2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x2e:
	movea.l  reg_d2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x2f:
	movea.l  reg_d2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x30:
	movea.w  reg_d3+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x31:
	movea.w  reg_d3+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x32:
	movea.w  reg_d3+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x33:
	movea.w  reg_d3+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x34:
	movea.w  reg_d3+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x35:
	movea.w  reg_d3+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x36:
	movea.w  reg_d3+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x37:
	movea.w  reg_d3+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x38:
	movea.l  reg_d3(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x39:
	movea.l  reg_d3(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x3a:
	movea.l  reg_d3(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x3b:
	movea.l  reg_d3(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x3c:
	movea.l  reg_d3(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x3d:
	movea.l  reg_d3(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x3e:
	movea.l  reg_d3(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x3f:
	movea.l  reg_d3(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x40:
	movea.w  reg_d4+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x41:
	movea.w  reg_d4+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x42:
	movea.w  reg_d4+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x43:
	movea.w  reg_d4+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x44:
	movea.w  reg_d4+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x45:
	movea.w  reg_d4+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x46:
	movea.w  reg_d4+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x47:
	movea.w  reg_d4+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x48:
	movea.l  reg_d4(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x49:
	movea.l  reg_d4(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x4a:
	movea.l  reg_d4(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x4b:
	movea.l  reg_d4(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x4c:
	movea.l  reg_d4(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x4d:
	movea.l  reg_d4(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x4e:
	movea.l  reg_d4(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x4f:
	movea.l  reg_d4(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x50:
	movea.w  reg_d5+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x51:
	movea.w  reg_d5+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x52:
	movea.w  reg_d5+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x53:
	movea.w  reg_d5+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x54:
	movea.w  reg_d5+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x55:
	movea.w  reg_d5+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x56:
	movea.w  reg_d5+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x57:
	movea.w  reg_d5+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x58:
	movea.l  reg_d5(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x59:
	movea.l  reg_d5(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x5a:
	movea.l  reg_d5(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x5b:
	movea.l  reg_d5(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x5c:
	movea.l  reg_d5(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x5d:
	movea.l  reg_d5(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x5e:
	movea.l  reg_d5(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x5f:
	movea.l  reg_d5(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x60:
	movea.w  reg_d6+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x61:
	movea.w  reg_d6+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x62:
	movea.w  reg_d6+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x63:
	movea.w  reg_d6+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x64:
	movea.w  reg_d6+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x65:
	movea.w  reg_d6+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x66:
	movea.w  reg_d6+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x67:
	movea.w  reg_d6+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x68:
	movea.l  reg_d6(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x69:
	movea.l  reg_d6(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x6a:
	movea.l  reg_d6(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x6b:
	movea.l  reg_d6(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x6c:
	movea.l  reg_d6(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x6d:
	movea.l  reg_d6(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x6e:
	movea.l  reg_d6(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x6f:
	movea.l  reg_d6(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x70:
	movea.w  reg_d7+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x71:
	movea.w  reg_d7+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x72:
	movea.w  reg_d7+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x73:
	movea.w  reg_d7+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x74:
	movea.w  reg_d7+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x75:
	movea.w  reg_d7+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x76:
	movea.w  reg_d7+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x77:
	movea.w  reg_d7+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x78:
	movea.l  reg_d7(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x79:
	movea.l  reg_d7(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x7a:
	movea.l  reg_d7(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x7b:
	movea.l  reg_d7(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x7c:
	movea.l  reg_d7(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x7d:
	movea.l  reg_d7(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x7e:
	movea.l  reg_d7(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x7f:
	movea.l  reg_d7(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x80:
	movea.w  reg_a0+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x81:
	movea.w  reg_a0+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x82:
	movea.w  reg_a0+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x83:
	movea.w  reg_a0+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x84:
	movea.w  reg_a0+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x85:
	movea.w  reg_a0+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x86:
	movea.w  reg_a0+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x87:
	movea.w  reg_a0+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x88:
	movea.l  reg_a0(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x89:
	movea.l  reg_a0(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x8a:
	movea.l  reg_a0(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x8b:
	movea.l  reg_a0(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x8c:
	movea.l  reg_a0(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x8d:
	movea.l  reg_a0(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x8e:
	movea.l  reg_a0(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x8f:
	movea.l  reg_a0(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x90:
	movea.w  reg_a1+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x91:
	movea.w  reg_a1+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x92:
	movea.w  reg_a1+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x93:
	movea.w  reg_a1+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x94:
	movea.w  reg_a1+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x95:
	movea.w  reg_a1+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x96:
	movea.w  reg_a1+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x97:
	movea.w  reg_a1+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0x98:
	movea.l  reg_a1(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0x99:
	movea.l  reg_a1(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0x9a:
	movea.l  reg_a1(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0x9b:
	movea.l  reg_a1(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0x9c:
	movea.l  reg_a1(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0x9d:
	movea.l  reg_a1(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0x9e:
	movea.l  reg_a1(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0x9f:
	movea.l  reg_a1(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xa0:
	movea.w  reg_a2+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xa1:
	movea.w  reg_a2+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xa2:
	movea.w  reg_a2+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xa3:
	movea.w  reg_a2+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xa4:
	movea.w  reg_a2+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xa5:
	movea.w  reg_a2+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xa6:
	movea.w  reg_a2+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xa7:
	movea.w  reg_a2+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xa8:
	movea.l  reg_a2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xa9:
	movea.l  reg_a2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xaa:
	movea.l  reg_a2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xab:
	movea.l  reg_a2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xac:
	movea.l  reg_a2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xad:
	movea.l  reg_a2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xae:
	movea.l  reg_a2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xaf:
	movea.l  reg_a2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xb0:
	movea.w  reg_a3+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xb1:
	movea.w  reg_a3+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xb2:
	movea.w  reg_a3+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xb3:
	movea.w  reg_a3+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xb4:
	movea.w  reg_a3+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xb5:
	movea.w  reg_a3+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xb6:
	movea.w  reg_a3+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xb7:
	movea.w  reg_a3+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xb8:
	movea.l  reg_a3(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xb9:
	movea.l  reg_a3(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xba:
	movea.l  reg_a3(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xbb:
	movea.l  reg_a3(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xbc:
	movea.l  reg_a3(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xbd:
	movea.l  reg_a3(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xbe:
	movea.l  reg_a3(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xbf:
	movea.l  reg_a3(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xc0:
	movea.w  reg_a4+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xc1:
	movea.w  reg_a4+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xc2:
	movea.w  reg_a4+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xc3:
	movea.w  reg_a4+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xc4:
	movea.w  reg_a4+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xc5:
	movea.w  reg_a4+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xc6:
	movea.w  reg_a4+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xc7:
	movea.w  reg_a4+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xc8:
	movea.l  reg_a4(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xc9:
	movea.l  reg_a4(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xca:
	movea.l  reg_a4(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xcb:
	movea.l  reg_a4(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xcc:
	movea.l  reg_a4(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xcd:
	movea.l  reg_a4(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xce:
	movea.l  reg_a4(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xcf:
	movea.l  reg_a4(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xd0:
	movea.w  reg_a5+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xd1:
	movea.w  reg_a5+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xd2:
	movea.w  reg_a5+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xd3:
	movea.w  reg_a5+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xd4:
	movea.w  reg_a5+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xd5:
	movea.w  reg_a5+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xd6:
	movea.w  reg_a5+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xd7:
	movea.w  reg_a5+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xd8:
	movea.l  reg_a5(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xd9:
	movea.l  reg_a5(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xda:
	movea.l  reg_a5(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xdb:
	movea.l  reg_a5(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xdc:
	movea.l  reg_a5(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xdd:
	movea.l  reg_a5(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xde:
	movea.l  reg_a5(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xdf:
	movea.l  reg_a5(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xe0:
	movea.w  reg_a6+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xe1:
	movea.w  reg_a6+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xe2:
	movea.w  reg_a6+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xe3:
	movea.w  reg_a6+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xe4:
	movea.w  reg_a6+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xe5:
	movea.w  reg_a6+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xe6:
	movea.w  reg_a6+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xe7:
	movea.w  reg_a6+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xe8:
	movea.l  reg_a6(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xe9:
	movea.l  reg_a6(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xea:
	movea.l  reg_a6(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xeb:
	movea.l  reg_a6(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xec:
	movea.l  reg_a6(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xed:
	movea.l  reg_a6(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xee:
	movea.l  reg_a6(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xef:
	movea.l  reg_a6(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xf0:
	bsr      compute_reg_a7
	movea.w  reg_a7+2(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xf1:
	bsr      compute_reg_a7
	movea.w  reg_a7+2(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xf2:
	bsr      compute_reg_a7
	movea.w  reg_a7+2(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xf3:
	bsr      compute_reg_a7
	movea.w  reg_a7+2(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xf4:
	bsr      compute_reg_a7
	movea.w  reg_a7+2(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xf5:
	bsr      compute_reg_a7
	movea.w  reg_a7+2(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xf6:
	bsr      compute_reg_a7
	movea.w  reg_a7+2(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xf7:
	bsr      compute_reg_a7
	movea.w  reg_a7+2(%a6),%a2
	bra      complex_index_scale_0x3
index_68020_0xf8:
	bsr      compute_reg_a7
	movea.l  reg_a7(%a6),%a2
	bra      simple_index_scale_0x0
index_68020_0xf9:
	bsr      compute_reg_a7
	movea.l  reg_a7(%a6),%a2
	bra      complex_index_scale_0x0
index_68020_0xfa:
	bsr      compute_reg_a7
	movea.l  reg_a7(%a6),%a2
	bra      simple_index_scale_0x1
index_68020_0xfb:
	bsr      compute_reg_a7
	movea.l  reg_a7(%a6),%a2
	bra      complex_index_scale_0x1
index_68020_0xfc:
	bsr      compute_reg_a7
	movea.l  reg_a7(%a6),%a2
	bra      simple_index_scale_0x2
index_68020_0xfd:
	bsr      compute_reg_a7
	movea.l  reg_a7(%a6),%a2
	bra      complex_index_scale_0x2
index_68020_0xfe:
	bsr      compute_reg_a7
	movea.l  reg_a7(%a6),%a2
	bra      simple_index_scale_0x3
index_68020_0xff:
	bsr      compute_reg_a7
	movea.l  reg_a7(%a6),%a2
	bra      complex_index_scale_0x3

|###################################################
|# index_68020_handler_table                       #
|###################################################
	.data
	.align	2
index_68020_handler_table:
	.long 	index_68020_0x0
	.long 	index_68020_0x1
	.long 	index_68020_0x2
	.long 	index_68020_0x3
	.long 	index_68020_0x4
	.long 	index_68020_0x5
	.long 	index_68020_0x6
	.long 	index_68020_0x7
	.long 	index_68020_0x8
	.long 	index_68020_0x9
	.long 	index_68020_0xa
	.long 	index_68020_0xb
	.long 	index_68020_0xc
	.long 	index_68020_0xd
	.long 	index_68020_0xe
	.long 	index_68020_0xf
	.long 	index_68020_0x10
	.long 	index_68020_0x11
	.long 	index_68020_0x12
	.long 	index_68020_0x13
	.long 	index_68020_0x14
	.long 	index_68020_0x15
	.long 	index_68020_0x16
	.long 	index_68020_0x17
	.long 	index_68020_0x18
	.long 	index_68020_0x19
	.long 	index_68020_0x1a
	.long 	index_68020_0x1b
	.long 	index_68020_0x1c
	.long 	index_68020_0x1d
	.long 	index_68020_0x1e
	.long 	index_68020_0x1f
	.long 	index_68020_0x20
	.long 	index_68020_0x21
	.long 	index_68020_0x22
	.long 	index_68020_0x23
	.long 	index_68020_0x24
	.long 	index_68020_0x25
	.long 	index_68020_0x26
	.long 	index_68020_0x27
	.long 	index_68020_0x28
	.long 	index_68020_0x29
	.long 	index_68020_0x2a
	.long 	index_68020_0x2b
	.long 	index_68020_0x2c
	.long 	index_68020_0x2d
	.long 	index_68020_0x2e
	.long 	index_68020_0x2f
	.long 	index_68020_0x30
	.long 	index_68020_0x31
	.long 	index_68020_0x32
	.long 	index_68020_0x33
	.long 	index_68020_0x34
	.long 	index_68020_0x35
	.long 	index_68020_0x36
	.long 	index_68020_0x37
	.long 	index_68020_0x38
	.long 	index_68020_0x39
	.long 	index_68020_0x3a
	.long 	index_68020_0x3b
	.long 	index_68020_0x3c
	.long 	index_68020_0x3d
	.long 	index_68020_0x3e
	.long 	index_68020_0x3f
	.long 	index_68020_0x40
	.long 	index_68020_0x41
	.long 	index_68020_0x42
	.long 	index_68020_0x43
	.long 	index_68020_0x44
	.long 	index_68020_0x45
	.long 	index_68020_0x46
	.long 	index_68020_0x47
	.long 	index_68020_0x48
	.long 	index_68020_0x49
	.long 	index_68020_0x4a
	.long 	index_68020_0x4b
	.long 	index_68020_0x4c
	.long 	index_68020_0x4d
	.long 	index_68020_0x4e
	.long 	index_68020_0x4f
	.long 	index_68020_0x50
	.long 	index_68020_0x51
	.long 	index_68020_0x52
	.long 	index_68020_0x53
	.long 	index_68020_0x54
	.long 	index_68020_0x55
	.long 	index_68020_0x56
	.long 	index_68020_0x57
	.long 	index_68020_0x58
	.long 	index_68020_0x59
	.long 	index_68020_0x5a
	.long 	index_68020_0x5b
	.long 	index_68020_0x5c
	.long 	index_68020_0x5d
	.long 	index_68020_0x5e
	.long 	index_68020_0x5f
	.long 	index_68020_0x60
	.long 	index_68020_0x61
	.long 	index_68020_0x62
	.long 	index_68020_0x63
	.long 	index_68020_0x64
	.long 	index_68020_0x65
	.long 	index_68020_0x66
	.long 	index_68020_0x67
	.long 	index_68020_0x68
	.long 	index_68020_0x69
	.long 	index_68020_0x6a
	.long 	index_68020_0x6b
	.long 	index_68020_0x6c
	.long 	index_68020_0x6d
	.long 	index_68020_0x6e
	.long 	index_68020_0x6f
	.long 	index_68020_0x70
	.long 	index_68020_0x71
	.long 	index_68020_0x72
	.long 	index_68020_0x73
	.long 	index_68020_0x74
	.long 	index_68020_0x75
	.long 	index_68020_0x76
	.long 	index_68020_0x77
	.long 	index_68020_0x78
	.long 	index_68020_0x79
	.long 	index_68020_0x7a
	.long 	index_68020_0x7b
	.long 	index_68020_0x7c
	.long 	index_68020_0x7d
	.long 	index_68020_0x7e
	.long 	index_68020_0x7f
	.long 	index_68020_0x80
	.long 	index_68020_0x81
	.long 	index_68020_0x82
	.long 	index_68020_0x83
	.long 	index_68020_0x84
	.long 	index_68020_0x85
	.long 	index_68020_0x86
	.long 	index_68020_0x87
	.long 	index_68020_0x88
	.long 	index_68020_0x89
	.long 	index_68020_0x8a
	.long 	index_68020_0x8b
	.long 	index_68020_0x8c
	.long 	index_68020_0x8d
	.long 	index_68020_0x8e
	.long 	index_68020_0x8f
	.long 	index_68020_0x90
	.long 	index_68020_0x91
	.long 	index_68020_0x92
	.long 	index_68020_0x93
	.long 	index_68020_0x94
	.long 	index_68020_0x95
	.long 	index_68020_0x96
	.long 	index_68020_0x97
	.long 	index_68020_0x98
	.long 	index_68020_0x99
	.long 	index_68020_0x9a
	.long 	index_68020_0x9b
	.long 	index_68020_0x9c
	.long 	index_68020_0x9d
	.long 	index_68020_0x9e
	.long 	index_68020_0x9f
	.long 	index_68020_0xa0
	.long 	index_68020_0xa1
	.long 	index_68020_0xa2
	.long 	index_68020_0xa3
	.long 	index_68020_0xa4
	.long 	index_68020_0xa5
	.long 	index_68020_0xa6
	.long 	index_68020_0xa7
	.long 	index_68020_0xa8
	.long 	index_68020_0xa9
	.long 	index_68020_0xaa
	.long 	index_68020_0xab
	.long 	index_68020_0xac
	.long 	index_68020_0xad
	.long 	index_68020_0xae
	.long 	index_68020_0xaf
	.long 	index_68020_0xb0
	.long 	index_68020_0xb1
	.long 	index_68020_0xb2
	.long 	index_68020_0xb3
	.long 	index_68020_0xb4
	.long 	index_68020_0xb5
	.long 	index_68020_0xb6
	.long 	index_68020_0xb7
	.long 	index_68020_0xb8
	.long 	index_68020_0xb9
	.long 	index_68020_0xba
	.long 	index_68020_0xbb
	.long 	index_68020_0xbc
	.long 	index_68020_0xbd
	.long 	index_68020_0xbe
	.long 	index_68020_0xbf
	.long 	index_68020_0xc0
	.long 	index_68020_0xc1
	.long 	index_68020_0xc2
	.long 	index_68020_0xc3
	.long 	index_68020_0xc4
	.long 	index_68020_0xc5
	.long 	index_68020_0xc6
	.long 	index_68020_0xc7
	.long 	index_68020_0xc8
	.long 	index_68020_0xc9
	.long 	index_68020_0xca
	.long 	index_68020_0xcb
	.long 	index_68020_0xcc
	.long 	index_68020_0xcd
	.long 	index_68020_0xce
	.long 	index_68020_0xcf
	.long 	index_68020_0xd0
	.long 	index_68020_0xd1
	.long 	index_68020_0xd2
	.long 	index_68020_0xd3
	.long 	index_68020_0xd4
	.long 	index_68020_0xd5
	.long 	index_68020_0xd6
	.long 	index_68020_0xd7
	.long 	index_68020_0xd8
	.long 	index_68020_0xd9
	.long 	index_68020_0xda
	.long 	index_68020_0xdb
	.long 	index_68020_0xdc
	.long 	index_68020_0xdd
	.long 	index_68020_0xde
	.long 	index_68020_0xdf
	.long 	index_68020_0xe0
	.long 	index_68020_0xe1
	.long 	index_68020_0xe2
	.long 	index_68020_0xe3
	.long 	index_68020_0xe4
	.long 	index_68020_0xe5
	.long 	index_68020_0xe6
	.long 	index_68020_0xe7
	.long 	index_68020_0xe8
	.long 	index_68020_0xe9
	.long 	index_68020_0xea
	.long 	index_68020_0xeb
	.long 	index_68020_0xec
	.long 	index_68020_0xed
	.long 	index_68020_0xee
	.long 	index_68020_0xef
	.long 	index_68020_0xf0
	.long 	index_68020_0xf1
	.long 	index_68020_0xf2
	.long 	index_68020_0xf3
	.long 	index_68020_0xf4
	.long 	index_68020_0xf5
	.long 	index_68020_0xf6
	.long 	index_68020_0xf7
	.long 	index_68020_0xf8
	.long 	index_68020_0xf9
	.long 	index_68020_0xfa
	.long 	index_68020_0xfb
	.long 	index_68020_0xfc
	.long 	index_68020_0xfd
	.long 	index_68020_0xfe
	.long 	index_68020_0xff

|###################################################
|# simple_index_scale_0x0                          #
|###################################################
	.text
	.align	2
simple_index_scale_0x0:
	adda.l   %a2,%a1
	extb.l   %d3
	adda.l   %d3,%a1
	rts      

|###################################################
|# simple_index_scale_0x1                          #
|###################################################
	.align	2
simple_index_scale_0x1:
	lea      (%a1,%a2.l*2),%a1
	extb.l   %d3
	adda.l   %d3,%a1
	rts      

|###################################################
|# simple_index_scale_0x2                          #
|###################################################
	.align	2
simple_index_scale_0x2:
	lea      (%a1,%a2.l*4),%a1
	extb.l   %d3
	adda.l   %d3,%a1
	rts      

|###################################################
|# simple_index_scale_0x3                          #
|###################################################
	.align	2
simple_index_scale_0x3:
	lea      (%a1,%a2.l*4),%a1
	lea      (%a1,%a2.l*4),%a1
	extb.l   %d3
	adda.l   %d3,%a1
	rts      

|###################################################
|# complex_index_scale_0x0                         #
|###################################################
	.align	2
complex_index_scale_0x0:
	and.l    #0xff,%d3
	lea      calculate_68020_indirect_address_dispatch,%a4
	move.l   0(%a4,%d3.l*4),%a4
	jmp      (%a4)

|###################################################
|# complex_index_scale_0x1                         #
|###################################################
	.align	2
complex_index_scale_0x1:
	adda.l   %a2,%a2
	bra      complex_index_scale_0x0

|###################################################
|# complex_index_scale_0x2                         #
|###################################################
	.align	2
complex_index_scale_0x2:
	adda.l   %a2,%a2
	adda.l   %a2,%a2
	bra      complex_index_scale_0x0

|###################################################
|# complex_index_scale_0x3                         #
|###################################################
	.align	2
complex_index_scale_0x3:
	adda.l   %a2,%a2
	adda.l   %a2,%a2
	adda.l   %a2,%a2
	bra      complex_index_scale_0x0

|###################################################
|# read_operand_byte                               #
|###################################################
	.align	4
read_operand_byte:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      fetch_byte_offset,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# read_operand_word                               #
|###################################################
	.align	4
read_operand_word:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      fetch_word_offset,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# read_operand_long                               #
|###################################################
	.align	4
read_operand_long:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      fetch_long_offset,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# store_operand_byte                              #
|###################################################
	.align	4
store_operand_byte:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      store_byte_offset,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# store_operand_word                              #
|###################################################
	.align	4
store_operand_word:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      store_word_offset,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# store_operand_long                              #
|###################################################
	.align	4
store_operand_long:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      store_long_offset,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# read_then_write_operand_byte                    #
|###################################################
	.align	4
read_then_write_operand_byte:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      fetch_then_store_byte_offset,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# read_then_write_operand_word                    #
|###################################################
	.align	4
read_then_write_operand_word:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      fetch_then_store_word_offset,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# read_then_write_operand_long                    #
|###################################################
	.align	4
read_then_write_operand_long:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      fetch_then_store_long_offset,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# calculate_effective_address                     #
|###################################################
	.align	4
calculate_effective_address:
	move.l   %d5,%d4
	and.l    #63,%d4
	lea      calculate_effective_address_dispatch,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# calculate_indexed_address_alt                   #
|###################################################
	.align	4
calculate_indexed_address_alt:
	| Alternative entry point for fetch/store indexed...
	move.w   2(%a0),%d3
	addq.l   #4,%a0
	|# Normal entry point...
calculate_indexed_address:
	move.l   %d3,%d4
	lsr.l    #8,%d4
	and.l    #255,%d4
	lea      index_68020_handler_table,%a4
	move.l   0(%a4,%d4.l*4),%a4
	jmp      (%a4)

|###################################################
|# fetch_byte_offset                               #
|###################################################
	.data
	.align	4
fetch_byte_offset:
	.long 	fetch_byte_D0
	.long 	fetch_byte_D1
	.long 	fetch_byte_D2
	.long 	fetch_byte_D3
	.long 	fetch_byte_D4
	.long 	fetch_byte_D5
	.long 	fetch_byte_D6
	.long 	fetch_byte_D7
	.long 	fetch_byte_A0
	.long 	fetch_byte_A1
	.long 	fetch_byte_A2
	.long 	fetch_byte_A3
	.long 	fetch_byte_A4
	.long 	fetch_byte_A5
	.long 	fetch_byte_A6
	.long 	fetch_byte_A7
	.long 	fetch_byte_indirect_A0
	.long 	fetch_byte_indirect_A1
	.long 	fetch_byte_indirect_A2
	.long 	fetch_byte_indirect_A3
	.long 	fetch_byte_indirect_A4
	.long 	fetch_byte_indirect_A5
	.long 	fetch_byte_indirect_A6
	.long 	fetch_byte_indirect_A7
	.long 	fetch_byte_postincrement_A0
	.long 	fetch_byte_postincrement_A1
	.long 	fetch_byte_postincrement_A2
	.long 	fetch_byte_postincrement_A3
	.long 	fetch_byte_postincrement_A4
	.long 	fetch_byte_postincrement_A5
	.long 	fetch_byte_postincrement_A6
	.long 	fetch_byte_postincrement_A7
	.long 	fetch_byte_predecrement_A0
	.long 	fetch_byte_predecrement_A1
	.long 	fetch_byte_predecrement_A2
	.long 	fetch_byte_predecrement_A3
	.long 	fetch_byte_predecrement_A4
	.long 	fetch_byte_predecrement_A5
	.long 	fetch_byte_predecrement_A6
	.long 	fetch_byte_predecrement_A7
	.long 	fetch_byte_displacement_A0
	.long 	fetch_byte_displacement_A1
	.long 	fetch_byte_displacement_A2
	.long 	fetch_byte_displacement_A3
	.long 	fetch_byte_displacement_A4
	.long 	fetch_byte_displacement_A5
	.long 	fetch_byte_displacement_A6
	.long 	fetch_byte_displacement_A7
	.long 	fetch_byte_indexed_A0
	.long 	fetch_byte_indexed_A1
	.long 	fetch_byte_indexed_A2
	.long 	fetch_byte_indexed_A3
	.long 	fetch_byte_indexed_A4
	.long 	fetch_byte_indexed_A5
	.long 	fetch_byte_indexed_A6
	.long 	fetch_byte_indexed_A7
	.long 	fetch_byte_absolute_word
	.long 	fetch_byte_absolute_long
	.long 	fetch_byte_displacement_PC
	.long 	fetch_byte_indexed_PC
	.long 	fetch_byte_immediate
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# fetch_word_offset                               #
|###################################################
	.align	4
fetch_word_offset:
	.long 	fetch_word_D0
	.long 	fetch_word_D1
	.long 	fetch_word_D2
	.long 	fetch_word_D3
	.long 	fetch_word_D4
	.long 	fetch_word_D5
	.long 	fetch_word_D6
	.long 	fetch_word_D7
	.long 	fetch_word_A0
	.long 	fetch_word_A1
	.long 	fetch_word_A2
	.long 	fetch_word_A3
	.long 	fetch_word_A4
	.long 	fetch_word_A5
	.long 	fetch_word_A6
	.long 	fetch_word_A7
	.long 	fetch_word_indirect_A0
	.long 	fetch_word_indirect_A1
	.long 	fetch_word_indirect_A2
	.long 	fetch_word_indirect_A3
	.long 	fetch_word_indirect_A4
	.long 	fetch_word_indirect_A5
	.long 	fetch_word_indirect_A6
	.long 	fetch_word_indirect_A7
	.long 	fetch_word_postincrement_A0
	.long 	fetch_word_postincrement_A1
	.long 	fetch_word_postincrement_A2
	.long 	fetch_word_postincrement_A3
	.long 	fetch_word_postincrement_A4
	.long 	fetch_word_postincrement_A5
	.long 	fetch_word_postincrement_A6
	.long 	fetch_word_postincrement_A7
	.long 	fetch_word_predecrement_A0
	.long 	fetch_word_predecrement_A1
	.long 	fetch_word_predecrement_A2
	.long 	fetch_word_predecrement_A3
	.long 	fetch_word_predecrement_A4
	.long 	fetch_word_predecrement_A5
	.long 	fetch_word_predecrement_A6
	.long 	fetch_word_predecrement_A7
	.long 	fetch_word_displacement_A0
	.long 	fetch_word_displacement_A1
	.long 	fetch_word_displacement_A2
	.long 	fetch_word_displacement_A3
	.long 	fetch_word_displacement_A4
	.long 	fetch_word_displacement_A5
	.long 	fetch_word_displacement_A6
	.long 	fetch_word_displacement_A7
	.long 	fetch_word_indexed_A0
	.long 	fetch_word_indexed_A1
	.long 	fetch_word_indexed_A2
	.long 	fetch_word_indexed_A3
	.long 	fetch_word_indexed_A4
	.long 	fetch_word_indexed_A5
	.long 	fetch_word_indexed_A6
	.long 	fetch_word_indexed_A7
	.long 	fetch_word_absolute_word
	.long 	fetch_word_absolute_long
	.long 	fetch_word_displacement_PC
	.long 	fetch_word_indexed_PC
	.long 	fetch_word_immediate
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# fetch_long_offset                               #
|###################################################
	.align	4
fetch_long_offset:
	.long 	fetch_long_D0
	.long 	fetch_long_D1
	.long 	fetch_long_D2
	.long 	fetch_long_D3
	.long 	fetch_long_D4
	.long 	fetch_long_D5
	.long 	fetch_long_D6
	.long 	fetch_long_D7
	.long 	fetch_long_A0
	.long 	fetch_long_A1
	.long 	fetch_long_A2
	.long 	fetch_long_A3
	.long 	fetch_long_A4
	.long 	fetch_long_A5
	.long 	fetch_long_A6
	.long 	fetch_long_A7
	.long 	fetch_long_indirect_A0
	.long 	fetch_long_indirect_A1
	.long 	fetch_long_indirect_A2
	.long 	fetch_long_indirect_A3
	.long 	fetch_long_indirect_A4
	.long 	fetch_long_indirect_A5
	.long 	fetch_long_indirect_A6
	.long 	fetch_long_indirect_A7
	.long 	fetch_long_postincrement_A0
	.long 	fetch_long_postincrement_A1
	.long 	fetch_long_postincrement_A2
	.long 	fetch_long_postincrement_A3
	.long 	fetch_long_postincrement_A4
	.long 	fetch_long_postincrement_A5
	.long 	fetch_long_postincrement_A6
	.long 	fetch_long_postincrement_A7
	.long 	fetch_long_predecrement_A0
	.long 	fetch_long_predecrement_A1
	.long 	fetch_long_predecrement_A2
	.long 	fetch_long_predecrement_A3
	.long 	fetch_long_predecrement_A4
	.long 	fetch_long_predecrement_A5
	.long 	fetch_long_predecrement_A6
	.long 	fetch_long_predecrement_A7
	.long 	fetch_long_displacement_A0
	.long 	fetch_long_displacement_A1
	.long 	fetch_long_displacement_A2
	.long 	fetch_long_displacement_A3
	.long 	fetch_long_displacement_A4
	.long 	fetch_long_displacement_A5
	.long 	fetch_long_displacement_A6
	.long 	fetch_long_displacement_A7
	.long 	fetch_long_indexed_A0
	.long 	fetch_long_indexed_A1
	.long 	fetch_long_indexed_A2
	.long 	fetch_long_indexed_A3
	.long 	fetch_long_indexed_A4
	.long 	fetch_long_indexed_A5
	.long 	fetch_long_indexed_A6
	.long 	fetch_long_indexed_A7
	.long 	fetch_long_absolute_word
	.long 	fetch_long_absolute_long
	.long 	fetch_long_displacement_PC
	.long 	fetch_long_indexed_PC
	.long 	fetch_long_immediate
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# store_byte_offset                               #
|###################################################
	.align	4
store_byte_offset:
	.long 	store_byte_D0
	.long 	store_byte_D1
	.long 	store_byte_D2
	.long 	store_byte_D3
	.long 	store_byte_D4
	.long 	store_byte_D5
	.long 	store_byte_D6
	.long 	store_byte_D7
	.long 	store_byte_A0
	.long 	store_byte_A1
	.long 	store_byte_A2
	.long 	store_byte_A3
	.long 	store_byte_A4
	.long 	store_byte_A5
	.long 	store_byte_A6
	.long 	store_byte_A7
	.long 	store_byte_indirect_A0
	.long 	store_byte_indirect_A1
	.long 	store_byte_indirect_A2
	.long 	store_byte_indirect_A3
	.long 	store_byte_indirect_A4
	.long 	store_byte_indirect_A5
	.long 	store_byte_indirect_A6
	.long 	store_byte_indirect_A7
	.long 	store_byte_postincrement_A0
	.long 	store_byte_postincrement_A1
	.long 	store_byte_postincrement_A2
	.long 	store_byte_postincrement_A3
	.long 	store_byte_postincrement_A4
	.long 	store_byte_postincrement_A5
	.long 	store_byte_postincrement_A6
	.long 	store_byte_postincrement_A7
	.long 	store_byte_predecrement_A0
	.long 	store_byte_predecrement_A1
	.long 	store_byte_predecrement_A2
	.long 	store_byte_predecrement_A3
	.long 	store_byte_predecrement_A4
	.long 	store_byte_predecrement_A5
	.long 	store_byte_predecrement_A6
	.long 	store_byte_predecrement_A7
	.long 	store_byte_displacement_A0
	.long 	store_byte_displacement_A1
	.long 	store_byte_displacement_A2
	.long 	store_byte_displacement_A3
	.long 	store_byte_displacement_A4
	.long 	store_byte_displacement_A5
	.long 	store_byte_displacement_A6
	.long 	store_byte_displacement_A7
	.long 	store_byte_indexed_A0
	.long 	store_byte_indexed_A1
	.long 	store_byte_indexed_A2
	.long 	store_byte_indexed_A3
	.long 	store_byte_indexed_A4
	.long 	store_byte_indexed_A5
	.long 	store_byte_indexed_A6
	.long 	store_byte_indexed_A7
	.long 	store_byte_absolute_word
	.long 	store_byte_absolute_long
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# store_word_offset                               #
|###################################################
	.align	4
store_word_offset:
	.long 	store_word_D0
	.long 	store_word_D1
	.long 	store_word_D2
	.long 	store_word_D3
	.long 	store_word_D4
	.long 	store_word_D5
	.long 	store_word_D6
	.long 	store_word_D7
	.long 	store_word_A0
	.long 	store_word_A1
	.long 	store_word_A2
	.long 	store_word_A3
	.long 	store_word_A4
	.long 	store_word_A5
	.long 	store_word_A6
	.long 	store_word_A7
	.long 	store_word_indirect_A0
	.long 	store_word_indirect_A1
	.long 	store_word_indirect_A2
	.long 	store_word_indirect_A3
	.long 	store_word_indirect_A4
	.long 	store_word_indirect_A5
	.long 	store_word_indirect_A6
	.long 	store_word_indirect_A7
	.long 	store_word_postincrement_A0
	.long 	store_word_postincrement_A1
	.long 	store_word_postincrement_A2
	.long 	store_word_postincrement_A3
	.long 	store_word_postincrement_A4
	.long 	store_word_postincrement_A5
	.long 	store_word_postincrement_A6
	.long 	store_word_postincrement_A7
	.long 	store_word_predecrement_A0
	.long 	store_word_predecrement_A1
	.long 	store_word_predecrement_A2
	.long 	store_word_predecrement_A3
	.long 	store_word_predecrement_A4
	.long 	store_word_predecrement_A5
	.long 	store_word_predecrement_A6
	.long 	store_word_predecrement_A7
	.long 	store_word_displacement_A0
	.long 	store_word_displacement_A1
	.long 	store_word_displacement_A2
	.long 	store_word_displacement_A3
	.long 	store_word_displacement_A4
	.long 	store_word_displacement_A5
	.long 	store_word_displacement_A6
	.long 	store_word_displacement_A7
	.long 	store_word_indexed_A0
	.long 	store_word_indexed_A1
	.long 	store_word_indexed_A2
	.long 	store_word_indexed_A3
	.long 	store_word_indexed_A4
	.long 	store_word_indexed_A5
	.long 	store_word_indexed_A6
	.long 	store_word_indexed_A7
	.long 	store_word_absolute_word
	.long 	store_word_absolute_long
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# store_long_offset                               #
|###################################################
	.align	4
store_long_offset:
	.long 	store_long_D0
	.long 	store_long_D1
	.long 	store_long_D2
	.long 	store_long_D3
	.long 	store_long_D4
	.long 	store_long_D5
	.long 	store_long_D6
	.long 	store_long_D7
	.long 	store_long_A0
	.long 	store_long_A1
	.long 	store_long_A2
	.long 	store_long_A3
	.long 	store_long_A4
	.long 	store_long_A5
	.long 	store_long_A6
	.long 	store_long_A7
	.long 	store_long_indirect_A0
	.long 	store_long_indirect_A1
	.long 	store_long_indirect_A2
	.long 	store_long_indirect_A3
	.long 	store_long_indirect_A4
	.long 	store_long_indirect_A5
	.long 	store_long_indirect_A6
	.long 	store_long_indirect_A7
	.long 	store_long_postincrement_A0
	.long 	store_long_postincrement_A1
	.long 	store_long_postincrement_A2
	.long 	store_long_postincrement_A3
	.long 	store_long_postincrement_A4
	.long 	store_long_postincrement_A5
	.long 	store_long_postincrement_A6
	.long 	store_long_postincrement_A7
	.long 	store_long_predecrement_A0
	.long 	store_long_predecrement_A1
	.long 	store_long_predecrement_A2
	.long 	store_long_predecrement_A3
	.long 	store_long_predecrement_A4
	.long 	store_long_predecrement_A5
	.long 	store_long_predecrement_A6
	.long 	store_long_predecrement_A7
	.long 	store_long_displacement_A0
	.long 	store_long_displacement_A1
	.long 	store_long_displacement_A2
	.long 	store_long_displacement_A3
	.long 	store_long_displacement_A4
	.long 	store_long_displacement_A5
	.long 	store_long_displacement_A6
	.long 	store_long_displacement_A7
	.long 	store_long_indexed_A0
	.long 	store_long_indexed_A1
	.long 	store_long_indexed_A2
	.long 	store_long_indexed_A3
	.long 	store_long_indexed_A4
	.long 	store_long_indexed_A5
	.long 	store_long_indexed_A6
	.long 	store_long_indexed_A7
	.long 	store_long_absolute_word
	.long 	store_long_absolute_long
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# fetch_then_store_byte_offset                    #
|###################################################
	.align	4
fetch_then_store_byte_offset:
	.long 	fetch_then_store_byte_D0
	.long 	fetch_then_store_byte_D1
	.long 	fetch_then_store_byte_D2
	.long 	fetch_then_store_byte_D3
	.long 	fetch_then_store_byte_D4
	.long 	fetch_then_store_byte_D5
	.long 	fetch_then_store_byte_D6
	.long 	fetch_then_store_byte_D7
	.long 	fetch_then_store_byte_A0
	.long 	fetch_then_store_byte_A1
	.long 	fetch_then_store_byte_A2
	.long 	fetch_then_store_byte_A3
	.long 	fetch_then_store_byte_A4
	.long 	fetch_then_store_byte_A5
	.long 	fetch_then_store_byte_A6
	.long 	fetch_then_store_byte_A7
	.long 	fetch_then_store_byte_indirect_A0
	.long 	fetch_then_store_byte_indirect_A1
	.long 	fetch_then_store_byte_indirect_A2
	.long 	fetch_then_store_byte_indirect_A3
	.long 	fetch_then_store_byte_indirect_A4
	.long 	fetch_then_store_byte_indirect_A5
	.long 	fetch_then_store_byte_indirect_A6
	.long 	fetch_then_store_byte_indirect_A7
	.long 	fetch_then_store_byte_postincrement_A0
	.long 	fetch_then_store_byte_postincrement_A1
	.long 	fetch_then_store_byte_postincrement_A2
	.long 	fetch_then_store_byte_postincrement_A3
	.long 	fetch_then_store_byte_postincrement_A4
	.long 	fetch_then_store_byte_postincrement_A5
	.long 	fetch_then_store_byte_postincrement_A6
	.long 	fetch_then_store_byte_postincrement_A7
	.long 	fetch_then_store_byte_predecrement_A0
	.long 	fetch_then_store_byte_predecrement_A1
	.long 	fetch_then_store_byte_predecrement_A2
	.long 	fetch_then_store_byte_predecrement_A3
	.long 	fetch_then_store_byte_predecrement_A4
	.long 	fetch_then_store_byte_predecrement_A5
	.long 	fetch_then_store_byte_predecrement_A6
	.long 	fetch_then_store_byte_predecrement_A7
	.long 	fetch_then_store_byte_displacement_A0
	.long 	fetch_then_store_byte_displacement_A1
	.long 	fetch_then_store_byte_displacement_A2
	.long 	fetch_then_store_byte_displacement_A3
	.long 	fetch_then_store_byte_displacement_A4
	.long 	fetch_then_store_byte_displacement_A5
	.long 	fetch_then_store_byte_displacement_A6
	.long 	fetch_then_store_byte_displacement_A7
	.long 	fetch_then_store_byte_indexed_A0
	.long 	fetch_then_store_byte_indexed_A1
	.long 	fetch_then_store_byte_indexed_A2
	.long 	fetch_then_store_byte_indexed_A3
	.long 	fetch_then_store_byte_indexed_A4
	.long 	fetch_then_store_byte_indexed_A5
	.long 	fetch_then_store_byte_indexed_A6
	.long 	fetch_then_store_byte_indexed_A7
	.long 	fetch_then_store_byte_absolute_word
	.long 	fetch_then_store_byte_absolute_long
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# fetch_then_store_word_offset                    #
|###################################################
	.align	4
fetch_then_store_word_offset:
	.long 	fetch_then_store_word_D0
	.long 	fetch_then_store_word_D1
	.long 	fetch_then_store_word_D2
	.long 	fetch_then_store_word_D3
	.long 	fetch_then_store_word_D4
	.long 	fetch_then_store_word_D5
	.long 	fetch_then_store_word_D6
	.long 	fetch_then_store_word_D7
	.long 	fetch_then_store_word_A0
	.long 	fetch_then_store_word_A1
	.long 	fetch_then_store_word_A2
	.long 	fetch_then_store_word_A3
	.long 	fetch_then_store_word_A4
	.long 	fetch_then_store_word_A5
	.long 	fetch_then_store_word_A6
	.long 	fetch_then_store_word_A7
	.long 	fetch_then_store_word_indirect_A0
	.long 	fetch_then_store_word_indirect_A1
	.long 	fetch_then_store_word_indirect_A2
	.long 	fetch_then_store_word_indirect_A3
	.long 	fetch_then_store_word_indirect_A4
	.long 	fetch_then_store_word_indirect_A5
	.long 	fetch_then_store_word_indirect_A6
	.long 	fetch_then_store_word_indirect_A7
	.long 	fetch_then_store_word_postincrement_A0
	.long 	fetch_then_store_word_postincrement_A1
	.long 	fetch_then_store_word_postincrement_A2
	.long 	fetch_then_store_word_postincrement_A3
	.long 	fetch_then_store_word_postincrement_A4
	.long 	fetch_then_store_word_postincrement_A5
	.long 	fetch_then_store_word_postincrement_A6
	.long 	fetch_then_store_word_postincrement_A7
	.long 	fetch_then_store_word_predecrement_A0
	.long 	fetch_then_store_word_predecrement_A1
	.long 	fetch_then_store_word_predecrement_A2
	.long 	fetch_then_store_word_predecrement_A3
	.long 	fetch_then_store_word_predecrement_A4
	.long 	fetch_then_store_word_predecrement_A5
	.long 	fetch_then_store_word_predecrement_A6
	.long 	fetch_then_store_word_predecrement_A7
	.long 	fetch_then_store_word_displacement_A0
	.long 	fetch_then_store_word_displacement_A1
	.long 	fetch_then_store_word_displacement_A2
	.long 	fetch_then_store_word_displacement_A3
	.long 	fetch_then_store_word_displacement_A4
	.long 	fetch_then_store_word_displacement_A5
	.long 	fetch_then_store_word_displacement_A6
	.long 	fetch_then_store_word_displacement_A7
	.long 	fetch_then_store_word_indexed_A0
	.long 	fetch_then_store_word_indexed_A1
	.long 	fetch_then_store_word_indexed_A2
	.long 	fetch_then_store_word_indexed_A3
	.long 	fetch_then_store_word_indexed_A4
	.long 	fetch_then_store_word_indexed_A5
	.long 	fetch_then_store_word_indexed_A6
	.long 	fetch_then_store_word_indexed_A7
	.long 	fetch_then_store_word_absolute_word
	.long 	fetch_then_store_word_absolute_long
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# fetch_then_store_long_offset                    #
|###################################################
	.align	4
fetch_then_store_long_offset:
	.long 	fetch_then_store_long_D0
	.long 	fetch_then_store_long_D1
	.long 	fetch_then_store_long_D2
	.long 	fetch_then_store_long_D3
	.long 	fetch_then_store_long_D4
	.long 	fetch_then_store_long_D5
	.long 	fetch_then_store_long_D6
	.long 	fetch_then_store_long_D7
	.long 	fetch_then_store_long_A0
	.long 	fetch_then_store_long_A1
	.long 	fetch_then_store_long_A2
	.long 	fetch_then_store_long_A3
	.long 	fetch_then_store_long_A4
	.long 	fetch_then_store_long_A5
	.long 	fetch_then_store_long_A6
	.long 	fetch_then_store_long_A7
	.long 	fetch_then_store_long_indirect_A0
	.long 	fetch_then_store_long_indirect_A1
	.long 	fetch_then_store_long_indirect_A2
	.long 	fetch_then_store_long_indirect_A3
	.long 	fetch_then_store_long_indirect_A4
	.long 	fetch_then_store_long_indirect_A5
	.long 	fetch_then_store_long_indirect_A6
	.long 	fetch_then_store_long_indirect_A7
	.long 	fetch_then_store_long_postincrement_A0
	.long 	fetch_then_store_long_postincrement_A1
	.long 	fetch_then_store_long_postincrement_A2
	.long 	fetch_then_store_long_postincrement_A3
	.long 	fetch_then_store_long_postincrement_A4
	.long 	fetch_then_store_long_postincrement_A5
	.long 	fetch_then_store_long_postincrement_A6
	.long 	fetch_then_store_long_postincrement_A7
	.long 	fetch_then_store_long_predecrement_A0
	.long 	fetch_then_store_long_predecrement_A1
	.long 	fetch_then_store_long_predecrement_A2
	.long 	fetch_then_store_long_predecrement_A3
	.long 	fetch_then_store_long_predecrement_A4
	.long 	fetch_then_store_long_predecrement_A5
	.long 	fetch_then_store_long_predecrement_A6
	.long 	fetch_then_store_long_predecrement_A7
	.long 	fetch_then_store_long_displacement_A0
	.long 	fetch_then_store_long_displacement_A1
	.long 	fetch_then_store_long_displacement_A2
	.long 	fetch_then_store_long_displacement_A3
	.long 	fetch_then_store_long_displacement_A4
	.long 	fetch_then_store_long_displacement_A5
	.long 	fetch_then_store_long_displacement_A6
	.long 	fetch_then_store_long_displacement_A7
	.long 	fetch_then_store_long_indexed_A0
	.long 	fetch_then_store_long_indexed_A1
	.long 	fetch_then_store_long_indexed_A2
	.long 	fetch_then_store_long_indexed_A3
	.long 	fetch_then_store_long_indexed_A4
	.long 	fetch_then_store_long_indexed_A5
	.long 	fetch_then_store_long_indexed_A6
	.long 	fetch_then_store_long_indexed_A7
	.long 	fetch_then_store_long_absolute_word
	.long 	fetch_then_store_long_absolute_long
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# calculate_effective_address_dispatch            #
|###################################################
	.align	4
calculate_effective_address_dispatch:
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	ea_indirect_A0
	.long 	ea_indirect_A1
	.long 	ea_indirect_A2
	.long 	ea_indirect_A3
	.long 	ea_indirect_A4
	.long 	ea_indirect_A5
	.long 	ea_indirect_A6
	.long 	ea_indirect_A7
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	ea_displacement_A0
	.long 	ea_displacement_A1
	.long 	ea_displacement_A2
	.long 	ea_displacement_A3
	.long 	ea_displacement_A4
	.long 	ea_displacement_A5
	.long 	ea_displacement_A6
	.long 	ea_displacement_A7
	.long 	ea_indexed_A0
	.long 	ea_indexed_A1
	.long 	ea_indexed_A2
	.long 	ea_indexed_A3
	.long 	ea_indexed_A4
	.long 	ea_indexed_A5
	.long 	ea_indexed_A6
	.long 	ea_indexed_A7
	.long 	ea_absolute_word
	.long 	ea_absolute_long
	.long 	ea_displacement_PC
	.long 	ea_indexed_PC
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# calculate_68020_indirect_address_dispatch       #
|###################################################
	.align	4
calculate_68020_indirect_address_dispatch:
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0x10
	.long 	memory_indirect_68020_0x11
	.long 	memory_indirect_68020_0x12
	.long 	memory_indirect_68020_0x13
	.long 	illegal
	.long 	memory_indirect_68020_0x15
	.long 	memory_indirect_68020_0x16
	.long 	memory_indirect_68020_0x17
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0x20
	.long 	memory_indirect_68020_0x21
	.long 	memory_indirect_68020_0x22
	.long 	memory_indirect_68020_0x23
	.long 	illegal
	.long 	memory_indirect_68020_0x25
	.long 	memory_indirect_68020_0x26
	.long 	memory_indirect_68020_0x27
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0x30
	.long 	memory_indirect_68020_0x31
	.long 	memory_indirect_68020_0x32
	.long 	memory_indirect_68020_0x33
	.long 	illegal
	.long 	memory_indirect_68020_0x35
	.long 	memory_indirect_68020_0x36
	.long 	memory_indirect_68020_0x37
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0x50
	.long 	memory_indirect_68020_0x51
	.long 	memory_indirect_68020_0x52
	.long 	memory_indirect_68020_0x53
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0x60
	.long 	memory_indirect_68020_0x61
	.long 	memory_indirect_68020_0x62
	.long 	memory_indirect_68020_0x63
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0x70
	.long 	memory_indirect_68020_0x71
	.long 	memory_indirect_68020_0x72
	.long 	memory_indirect_68020_0x73
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0x90
	.long 	memory_indirect_68020_0x91
	.long 	memory_indirect_68020_0x92
	.long 	memory_indirect_68020_0x93
	.long 	illegal
	.long 	memory_indirect_68020_0x95
	.long 	memory_indirect_68020_0x96
	.long 	memory_indirect_68020_0x97
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0xa0
	.long 	memory_indirect_68020_0xa1
	.long 	memory_indirect_68020_0xa2
	.long 	memory_indirect_68020_0xa3
	.long 	illegal
	.long 	memory_indirect_68020_0xa5
	.long 	memory_indirect_68020_0xa6
	.long 	memory_indirect_68020_0xa7
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0xb0
	.long 	memory_indirect_68020_0xb1
	.long 	memory_indirect_68020_0xb2
	.long 	memory_indirect_68020_0xb3
	.long 	illegal
	.long 	memory_indirect_68020_0xb5
	.long 	memory_indirect_68020_0xb6
	.long 	memory_indirect_68020_0xb7
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0xd0
	.long 	memory_indirect_68020_0xd1
	.long 	memory_indirect_68020_0xd2
	.long 	memory_indirect_68020_0xd3
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0xe0
	.long 	memory_indirect_68020_0xe1
	.long 	memory_indirect_68020_0xe2
	.long 	memory_indirect_68020_0xe3
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	memory_indirect_68020_0xf0
	.long 	memory_indirect_68020_0xf1
	.long 	memory_indirect_68020_0xf2
	.long 	memory_indirect_68020_0xf3
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal
	.long 	illegal

|###################################################
|# setup_bitfield                                  #
|###################################################
	.text
	.align	2
setup_bitfield:
	move.w   2(%a0),%d3
	addq.l   #2,%a0
	move.l   %d3,%d7
	btst     #5,%d3
	bne.s    bf_width_in_reg
	and.l    #0x1f,%d7
	bne.s    bf_got_width
	moveq.l  #32,%d7
	bra.s    bf_got_width
bf_width_in_reg:
	and.l    #0x7,%d7
	move.l   (reg_d0,%a6,%d7.l*4),%d7
bf_got_width:
	lsr.l    #6,%d3
	move.l   %d3,%d6
	btst     #5,%d3
	bne.s    bf_offset_in_reg
	and.l    #0x1f,%d6
	bra.s    bf_got_offset
bf_offset_in_reg:
	and.l    #0x7,%d6
	move.l   (reg_d0,%a6,%d6.l*4),%d6
bf_got_offset:
	lsr.l    #6,%d3
	and.l    #0x7,%d3
	lea      (reg_d0,%a6,%d3.l*4),%a3
	rts      

|###################################################
|# _PA_bcdbin_table                                #
|###################################################
	.data
	.align	3
_PA_bcdbin_table:
	.byte	0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
	.byte	10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25
	.byte	20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35
	.byte	30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45
	.byte	40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55
	.byte	50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65
	.byte	60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75
	.byte	70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85
_PA_bcd_tables:
	.byte	80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95
	.byte	90, 91, 92, 93, 94, 95, 96, 97, 98, 99,100,101,102,103,104,105
	.short	0x0400,0x0001,0x0002,0x0003,0x0004,0x0005,0x0006,0x0007,0x0008,0x0009
	.short	0x0010,0x0011,0x0012,0x0013,0x0014,0x0015,0x0016,0x0017,0x0018,0x0019
	.short	0x0020,0x0021,0x0022,0x0023,0x0024,0x0025,0x0026,0x0027,0x0028,0x0029
	.short	0x0030,0x0031,0x0032,0x0033,0x0034,0x0035,0x0036,0x0037,0x0038,0x0039
	.short	0x0040,0x0041,0x0042,0x0043,0x0044,0x0045,0x0046,0x0047,0x0048,0x0049
	.short	0x0050,0x0051,0x0052,0x0053,0x0054,0x0055,0x0056,0x0057,0x0058,0x0059
	.short	0x0060,0x0061,0x0062,0x0063,0x0064,0x0065,0x0066,0x0067,0x0068,0x0069
	.short	0x0070,0x0071,0x0072,0x0073,0x0074,0x0075,0x0076,0x0077,0x0078,0x0079
	.short	0x0080,0x0081,0x0082,0x0083,0x0084,0x0085,0x0086,0x0087,0x0088,0x0089
	.short	0x0090,0x0091,0x0092,0x0093,0x0094,0x0095,0x0096,0x0097,0x0098,0x0099
	.short	0x1500,0x1101,0x1102,0x1103,0x1104,0x1105,0x1106,0x1107,0x1108,0x1109
	.short	0x1110,0x1111,0x1112,0x1113,0x1114,0x1115,0x1116,0x1117,0x1118,0x1119
	.short	0x1120,0x1121,0x1122,0x1123,0x1124,0x1125,0x1126,0x1127,0x1128,0x1129
	.short	0x1130,0x1131,0x1132,0x1133,0x1134,0x1135,0x1136,0x1137,0x1138,0x1139
	.short	0x1140,0x1141,0x1142,0x1143,0x1144,0x1145,0x1146,0x1147,0x1148,0x1149
	.short	0x1150,0x1151,0x1152,0x1153,0x1154,0x1155,0x1156,0x1157,0x1158,0x1159
	.short	0x1160,0x1161,0x1162,0x1163,0x1164,0x1165,0x1166,0x1167,0x1168,0x1169
	.short	0x1170,0x1171,0x1172,0x1173,0x1174,0x1175,0x1176,0x1177,0x1178,0x1179
	.short	0x1180,0x1181,0x1182,0x1183,0x1184,0x1185,0x1186,0x1187,0x1188,0x1189
	.short	0x1190,0x1191,0x1192,0x1193,0x1194,0x1195,0x1196,0x1197,0x1198,0x1199
	.align	2

|###################################################
|# Dispatcher_338                                  #
|###################################################
	.text
	.align	4
Dispatcher_338:
second_level_dispatch_338:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_long
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_long
illegal_58:
	jmp      illegal

|###################################################
|# Dispatcher_342                                  #
|###################################################
	.align	4
Dispatcher_342:
second_level_dispatch_342:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_long
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_long
illegal_61:
	jmp      illegal

|###################################################
|# Dispatcher_345                                  #
|###################################################
	.align	4
Dispatcher_345:
second_level_dispatch_345:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_word
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_word
illegal_63:
	jmp      illegal

|###################################################
|# Dispatcher_346                                  #
|###################################################
	.align	4
Dispatcher_346:
second_level_dispatch_346:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_long
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_long
illegal_64:
	jmp      illegal

|###################################################
|# Dispatcher_349                                  #
|###################################################
	.align	4
Dispatcher_349:
second_level_dispatch_349:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_word
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_word
illegal_66:
	jmp      illegal

|###################################################
|# Dispatcher_350                                  #
|###################################################
	.align	4
Dispatcher_350:
second_level_dispatch_350:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_long
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_long
illegal_67:
	jmp      illegal

|###################################################
|# Dispatcher_353                                  #
|###################################################
	.align	4
Dispatcher_353:
second_level_dispatch_353:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_word
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_word
illegal_69:
	jmp      illegal

|###################################################
|# Dispatcher_354                                  #
|###################################################
	.align	4
Dispatcher_354:
second_level_dispatch_354:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_long
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_long
illegal_70:
	jmp      illegal

|###################################################
|# Dispatcher_357                                  #
|###################################################
	.align	4
Dispatcher_357:
second_level_dispatch_357:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_word
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_word
illegal_72:
	jmp      illegal

|###################################################
|# Dispatcher_358                                  #
|###################################################
	.align	4
Dispatcher_358:
second_level_dispatch_358:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_long
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_long
illegal_73:
	jmp      illegal

|###################################################
|# Dispatcher_361                                  #
|###################################################
	.align	4
Dispatcher_361:
second_level_dispatch_361:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_word
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_word
illegal_75:
	jmp      illegal

|###################################################
|# Dispatcher_362                                  #
|###################################################
	.align	4
Dispatcher_362:
second_level_dispatch_362:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_long
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_long
illegal_76:
	jmp      illegal

|###################################################
|# Dispatcher_365                                  #
|###################################################
	.align	4
Dispatcher_365:
second_level_dispatch_365:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_word
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_word
illegal_78:
	jmp      illegal

|###################################################
|# Dispatcher_366                                  #
|###################################################
	.align	4
Dispatcher_366:
second_level_dispatch_366:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_long
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_long
illegal_79:
	jmp      illegal

|###################################################
|# Dispatcher_369                                  #
|###################################################
	.align	4
Dispatcher_369:
second_level_dispatch_369:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_word
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_word
illegal_81:
	jmp      illegal

|###################################################
|# Dispatcher_370                                  #
|###################################################
	.align	4
Dispatcher_370:
second_level_dispatch_370:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_long
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_long
illegal_82:
	jmp      illegal

|###################################################
|# Dispatcher_373                                  #
|###################################################
	.align	4
Dispatcher_373:
second_level_dispatch_373:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_word
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_word
illegal_84:
	jmp      illegal

|###################################################
|# Dispatcher_374                                  #
|###################################################
	.align	4
Dispatcher_374:
second_level_dispatch_374:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_long
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_long
illegal_85:
	jmp      illegal

|###################################################
|# Dispatcher_377                                  #
|###################################################
	.align	4
Dispatcher_377:
second_level_dispatch_377:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_word
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_word
illegal_87:
	jmp      illegal

|###################################################
|# Dispatcher_378                                  #
|###################################################
	.align	4
Dispatcher_378:
second_level_dispatch_378:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      add_quick_long
	cmpi.l   #0x10,%d4
	bcs      add_quick_An
	cmpi.l   #0x3d,%d4
	bcs      add_quick_long
illegal_88:
	jmp      illegal

|###################################################
|# Dispatcher_381                                  #
|###################################################
	.align	4
Dispatcher_381:
second_level_dispatch_381:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_word
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_word
illegal_90:
	jmp      illegal

|###################################################
|# Dispatcher_382                                  #
|###################################################
	.align	4
Dispatcher_382:
second_level_dispatch_382:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sub_quick_long
	cmpi.l   #0x10,%d4
	bcs      sub_quick_An
	cmpi.l   #0x3d,%d4
	bcs      sub_quick_long
illegal_91:
	jmp      illegal

|###################################################
|# or_long_ea_to_D0                                #
|###################################################
	.align	1
or_long_ea_to_D0:
	bsr      read_operand_long
	move.l   reg_d0(%a6),%d1
	or.l     %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d0(%a6)
	jmp      exception_handled

|###################################################
|# divu_word                                       #
|###################################################
	.align	1
divu_word:
	bsr      read_operand_word
	move.l   %d0,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_long
	tst.w    %d1
	bne.s    divu_word_non_zero
	jmp      handle_divide_by_zero_exception
divu_word_non_zero:
	.short	0x80c1			| divu.w		d1,d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# or_byte_D0_to_ea                                #
|###################################################
	.align	1
or_byte_D0_to_ea:
	move.b   reg_d0+3(%a6),%d1
	bsr      read_then_write_operand_byte
	or.l     %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# sbcd_AyAx                                       #
|###################################################
	.align	1
sbcd_AyAx:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_byte
	move.l   %d0,%d2
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_byte
	and.l    #0x000000ff,%d2
	and.l    #0x000000ff,%d0
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	movea.l  #_PA_bcd_tables,%a2
	move.b   (_PA_BCDBIN,%a2,%d2.l),%d2
	move.b   (_PA_BCDBIN,%a2,%d0.l),%d0
	move     %d1,%CCR
	subx.l   %d2,%d0
	move     %CCR,%d3
	bcc.b    _M68k_972_
	add.l    #200,%d0
_M68k_972_:
	move.b   (_PA_BINBCD+1,%a2,%d0.l*2),%d0
	move     %CCR,%d2
	and.l    %d2,%d1
	andi.l   #0x04,%d1
	bclr     #2,%d3
	or.l     %d1,%d3
	move     %d3,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)
second_level_dispatch_524:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sbcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      sbcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      or_byte_D1_to_ea
illegal_96:
	jmp      illegal

|###################################################
|# sbcd_DyDx                                       #
|###################################################
	.align	1
sbcd_DyDx:
	bsr      read_operand_byte
	move.l   %d0,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_byte
	and.l    #0x000000ff,%d1
	and.l    #0x000000ff,%d0
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	movea.l  #_PA_bcd_tables,%a2
	move.b   (_PA_BCDBIN,%a2,%d1.l),%d1
	move.b   (_PA_BCDBIN,%a2,%d0.l),%d0
	move     %d2,%CCR
	subx.l   %d1,%d0
	move     %CCR,%d3
	bcc.b    _M68k_971_
	add.l    #200,%d0
_M68k_971_:
	move.b   (_PA_BINBCD+1,%a2,%d0.l*2),%d0
	move     %CCR,%d1
	and.l    %d1,%d2
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
	move     %d3,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)
second_level_dispatch_516:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sbcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      sbcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      or_byte_D0_to_ea
illegal_93:
	jmp      illegal

|###################################################
|# pack_AxAy                                       #
|###################################################
	.align	1
pack_AxAy:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_word
	move.w   (%a0)+,%d2
	move.w   %d0,%d0
	add.l    %d2,%d0
	andi.l   #0x0f0f,%d0
	move.l   %d0,%d3
	lsr.l    #4,%d0
	or.l     %d3,%d0
	moveq.l  #0x0,%d6
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bra      store_operand_byte
second_level_dispatch_525:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      pack_DxDy
	cmpi.l   #0x10,%d4
	bcs      pack_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_word_D1_to_ea
illegal_97:
	jmp      illegal

|###################################################
|# pack_DxDy                                       #
|###################################################
	.align	1
pack_DxDy:
	bsr      read_operand_word
	move.w   (%a0)+,%d1
	move.w   %d0,%d0
	add.l    %d1,%d0
	andi.l   #0x0f0f,%d0
	move.l   %d0,%d2
	lsr.l    #4,%d0
	or.l     %d2,%d0
	moveq.l  #0x0,%d6
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bra      store_operand_byte
second_level_dispatch_517:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      pack_DxDy
	cmpi.l   #0x10,%d4
	bcs      pack_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_word_D0_to_ea
illegal_94:
	jmp      illegal

|###################################################
|# or_word_D0_to_ea                                #
|###################################################
	.align	1
or_word_D0_to_ea:
	move.w   reg_d0+2(%a6),%d1
	bsr      read_then_write_operand_word
	or.l     %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# unpk_AxAy                                       #
|###################################################
	.align	1
unpk_AxAy:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_byte
	move.w   (%a0)+,%d2
	move.b   %d0,%d3
	move.b   %d0,%d0
	lsl.l    #4,%d0
	move.b   %d3,%d0
	andi.l   #0x0f0f,%d0
	add.l    %d2,%d0
	moveq.l  #0x0,%d6
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bra      store_operand_word
second_level_dispatch_526:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      unpk_DxDy
	cmpi.l   #0x10,%d4
	bcs      unpk_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_long_D1_to_ea
illegal_98:
	jmp      illegal

|###################################################
|# unpk_DxDy                                       #
|###################################################
	.align	1
unpk_DxDy:
	bsr      read_operand_byte
	move.w   (%a0)+,%d1
	move.b   %d0,%d2
	move.b   %d0,%d0
	lsl.l    #4,%d0
	move.b   %d2,%d0
	andi.l   #0x0f0f,%d0
	add.l    %d1,%d0
	moveq.l  #0x0,%d6
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bra      store_operand_word
second_level_dispatch_518:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      unpk_DxDy
	cmpi.l   #0x10,%d4
	bcs      unpk_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_long_D0_to_ea
illegal_95:
	jmp      illegal

|###################################################
|# or_long_D0_to_ea                                #
|###################################################
	.align	1
or_long_D0_to_ea:
	move.l   reg_d0(%a6),%d1
	bsr      read_then_write_operand_long
	or.l     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# divs_word                                       #
|###################################################
	.align	1
divs_word:
	bsr      read_operand_word
	move.l   %d0,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_long
	tst.w    %d1
	bne.s    divs_word_non_zero
	jmp      handle_divide_by_zero_exception
divs_word_non_zero:
	.short	0x81c1			| divs.w		d1,d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# or_byte_ea_to_D1                                #
|###################################################
	.align	1
or_byte_ea_to_D1:
	bsr      read_operand_byte
	move.b   reg_d1+3(%a6),%d1
	or.l     %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d1+3(%a6)
	jmp      exception_handled

|###################################################
|# or_word_ea_to_D1                                #
|###################################################
	.align	1
or_word_ea_to_D1:
	bsr      read_operand_word
	move.w   reg_d1+2(%a6),%d1
	or.l     %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d1+2(%a6)
	jmp      exception_handled

|###################################################
|# or_long_ea_to_D1                                #
|###################################################
	.align	1
or_long_ea_to_D1:
	bsr      read_operand_long
	move.l   reg_d1(%a6),%d1
	or.l     %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d1(%a6)
	jmp      exception_handled

|###################################################
|# or_byte_D1_to_ea                                #
|###################################################
	.align	1
or_byte_D1_to_ea:
	move.b   reg_d1+3(%a6),%d1
	bsr      read_then_write_operand_byte
	or.l     %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# or_word_D1_to_ea                                #
|###################################################
	.align	1
or_word_D1_to_ea:
	move.w   reg_d1+2(%a6),%d1
	bsr      read_then_write_operand_word
	or.l     %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# or_long_D1_to_ea                                #
|###################################################
	.align	1
or_long_D1_to_ea:
	move.l   reg_d1(%a6),%d1
	bsr      read_then_write_operand_long
	or.l     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# or_byte_ea_to_D2                                #
|###################################################
	.align	1
or_byte_ea_to_D2:
	bsr      read_operand_byte
	move.b   reg_d2+3(%a6),%d1
	or.l     %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d2+3(%a6)
	jmp      exception_handled

|###################################################
|# or_word_ea_to_D2                                #
|###################################################
	.align	1
or_word_ea_to_D2:
	bsr      read_operand_word
	move.w   reg_d2+2(%a6),%d1
	or.l     %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d2+2(%a6)
	jmp      exception_handled

|###################################################
|# or_long_ea_to_D2                                #
|###################################################
	.align	1
or_long_ea_to_D2:
	bsr      read_operand_long
	move.l   reg_d2(%a6),%d1
	or.l     %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d2(%a6)
	jmp      exception_handled

|###################################################
|# or_byte_D2_to_ea                                #
|###################################################
	.align	1
or_byte_D2_to_ea:
	move.b   reg_d2+3(%a6),%d1
	bsr      read_then_write_operand_byte
	or.l     %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_532:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sbcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      sbcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      or_byte_D2_to_ea
illegal_99:
	jmp      illegal

|###################################################
|# or_word_D2_to_ea                                #
|###################################################
	.align	1
or_word_D2_to_ea:
	move.w   reg_d2+2(%a6),%d1
	bsr      read_then_write_operand_word
	or.l     %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_533:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      pack_DxDy
	cmpi.l   #0x10,%d4
	bcs      pack_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_word_D2_to_ea
illegal_100:
	jmp      illegal

|###################################################
|# or_long_D2_to_ea                                #
|###################################################
	.align	1
or_long_D2_to_ea:
	move.l   reg_d2(%a6),%d1
	bsr      read_then_write_operand_long
	or.l     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_534:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      unpk_DxDy
	cmpi.l   #0x10,%d4
	bcs      unpk_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_long_D2_to_ea
illegal_101:
	jmp      illegal

|###################################################
|# or_byte_ea_to_D3                                #
|###################################################
	.align	1
or_byte_ea_to_D3:
	bsr      read_operand_byte
	move.b   reg_d3+3(%a6),%d1
	or.l     %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d3+3(%a6)
	jmp      exception_handled

|###################################################
|# or_word_ea_to_D3                                #
|###################################################
	.align	1
or_word_ea_to_D3:
	bsr      read_operand_word
	move.w   reg_d3+2(%a6),%d1
	or.l     %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d3+2(%a6)
	jmp      exception_handled

|###################################################
|# or_long_ea_to_D3                                #
|###################################################
	.align	1
or_long_ea_to_D3:
	bsr      read_operand_long
	move.l   reg_d3(%a6),%d1
	or.l     %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d3(%a6)
	jmp      exception_handled

|###################################################
|# or_byte_D3_to_ea                                #
|###################################################
	.align	1
or_byte_D3_to_ea:
	move.b   reg_d3+3(%a6),%d1
	bsr      read_then_write_operand_byte
	or.l     %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_540:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sbcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      sbcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      or_byte_D3_to_ea
illegal_102:
	jmp      illegal

|###################################################
|# or_word_D3_to_ea                                #
|###################################################
	.align	1
or_word_D3_to_ea:
	move.w   reg_d3+2(%a6),%d1
	bsr      read_then_write_operand_word
	or.l     %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_541:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      pack_DxDy
	cmpi.l   #0x10,%d4
	bcs      pack_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_word_D3_to_ea
illegal_103:
	jmp      illegal

|###################################################
|# or_long_D3_to_ea                                #
|###################################################
	.align	1
or_long_D3_to_ea:
	move.l   reg_d3(%a6),%d1
	bsr      read_then_write_operand_long
	or.l     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_542:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      unpk_DxDy
	cmpi.l   #0x10,%d4
	bcs      unpk_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_long_D3_to_ea
illegal_104:
	jmp      illegal

|###################################################
|# or_byte_ea_to_D4                                #
|###################################################
	.align	1
or_byte_ea_to_D4:
	bsr      read_operand_byte
	move.b   reg_d4+3(%a6),%d1
	or.l     %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d4+3(%a6)
	jmp      exception_handled

|###################################################
|# or_word_ea_to_D4                                #
|###################################################
	.align	1
or_word_ea_to_D4:
	bsr      read_operand_word
	move.w   reg_d4+2(%a6),%d1
	or.l     %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d4+2(%a6)
	jmp      exception_handled

|###################################################
|# or_long_ea_to_D4                                #
|###################################################
	.align	1
or_long_ea_to_D4:
	bsr      read_operand_long
	move.l   reg_d4(%a6),%d1
	or.l     %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d4(%a6)
	jmp      exception_handled

|###################################################
|# or_byte_D4_to_ea                                #
|###################################################
	.align	1
or_byte_D4_to_ea:
	move.b   reg_d4+3(%a6),%d1
	bsr      read_then_write_operand_byte
	or.l     %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_548:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sbcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      sbcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      or_byte_D4_to_ea
illegal_105:
	jmp      illegal

|###################################################
|# or_word_D4_to_ea                                #
|###################################################
	.align	1
or_word_D4_to_ea:
	move.w   reg_d4+2(%a6),%d1
	bsr      read_then_write_operand_word
	or.l     %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_549:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      pack_DxDy
	cmpi.l   #0x10,%d4
	bcs      pack_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_word_D4_to_ea
illegal_106:
	jmp      illegal

|###################################################
|# or_long_D4_to_ea                                #
|###################################################
	.align	1
or_long_D4_to_ea:
	move.l   reg_d4(%a6),%d1
	bsr      read_then_write_operand_long
	or.l     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_550:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      unpk_DxDy
	cmpi.l   #0x10,%d4
	bcs      unpk_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_long_D4_to_ea
illegal_107:
	jmp      illegal

|###################################################
|# or_byte_ea_to_D5                                #
|###################################################
	.align	1
or_byte_ea_to_D5:
	bsr      read_operand_byte
	move.b   reg_d5+3(%a6),%d1
	or.l     %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d5+3(%a6)
	jmp      exception_handled

|###################################################
|# or_word_ea_to_D5                                #
|###################################################
	.align	1
or_word_ea_to_D5:
	bsr      read_operand_word
	move.w   reg_d5+2(%a6),%d1
	or.l     %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d5+2(%a6)
	jmp      exception_handled

|###################################################
|# or_long_ea_to_D5                                #
|###################################################
	.align	1
or_long_ea_to_D5:
	bsr      read_operand_long
	move.l   reg_d5(%a6),%d1
	or.l     %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d5(%a6)
	jmp      exception_handled

|###################################################
|# or_byte_D5_to_ea                                #
|###################################################
	.align	1
or_byte_D5_to_ea:
	move.b   reg_d5+3(%a6),%d1
	bsr      read_then_write_operand_byte
	or.l     %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_556:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sbcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      sbcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      or_byte_D5_to_ea
illegal_108:
	jmp      illegal

|###################################################
|# or_word_D5_to_ea                                #
|###################################################
	.align	1
or_word_D5_to_ea:
	move.w   reg_d5+2(%a6),%d1
	bsr      read_then_write_operand_word
	or.l     %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_557:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      pack_DxDy
	cmpi.l   #0x10,%d4
	bcs      pack_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_word_D5_to_ea
illegal_109:
	jmp      illegal

|###################################################
|# or_long_D5_to_ea                                #
|###################################################
	.align	1
or_long_D5_to_ea:
	move.l   reg_d5(%a6),%d1
	bsr      read_then_write_operand_long
	or.l     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_558:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      unpk_DxDy
	cmpi.l   #0x10,%d4
	bcs      unpk_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_long_D5_to_ea
illegal_110:
	jmp      illegal

|###################################################
|# or_byte_ea_to_D6                                #
|###################################################
	.align	1
or_byte_ea_to_D6:
	bsr      read_operand_byte
	move.b   reg_d6+3(%a6),%d1
	or.l     %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d6+3(%a6)
	jmp      exception_handled

|###################################################
|# or_word_ea_to_D6                                #
|###################################################
	.align	1
or_word_ea_to_D6:
	bsr      read_operand_word
	move.w   reg_d6+2(%a6),%d1
	or.l     %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d6+2(%a6)
	jmp      exception_handled

|###################################################
|# or_long_ea_to_D6                                #
|###################################################
	.align	1
or_long_ea_to_D6:
	bsr      read_operand_long
	move.l   reg_d6(%a6),%d1
	or.l     %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d6(%a6)
	jmp      exception_handled

|###################################################
|# or_byte_D6_to_ea                                #
|###################################################
	.align	1
or_byte_D6_to_ea:
	move.b   reg_d6+3(%a6),%d1
	bsr      read_then_write_operand_byte
	or.l     %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_564:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sbcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      sbcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      or_byte_D6_to_ea
illegal_111:
	jmp      illegal

|###################################################
|# or_word_D6_to_ea                                #
|###################################################
	.align	1
or_word_D6_to_ea:
	move.w   reg_d6+2(%a6),%d1
	bsr      read_then_write_operand_word
	or.l     %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_565:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      pack_DxDy
	cmpi.l   #0x10,%d4
	bcs      pack_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_word_D6_to_ea
illegal_112:
	jmp      illegal

|###################################################
|# or_long_D6_to_ea                                #
|###################################################
	.align	1
or_long_D6_to_ea:
	move.l   reg_d6(%a6),%d1
	bsr      read_then_write_operand_long
	or.l     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_566:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      unpk_DxDy
	cmpi.l   #0x10,%d4
	bcs      unpk_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_long_D6_to_ea
illegal_113:
	jmp      illegal

|###################################################
|# or_byte_ea_to_D7                                #
|###################################################
	.align	1
or_byte_ea_to_D7:
	bsr      read_operand_byte
	move.b   reg_d7+3(%a6),%d1
	or.l     %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d7+3(%a6)
	jmp      exception_handled

|###################################################
|# or_word_ea_to_D7                                #
|###################################################
	.align	1
or_word_ea_to_D7:
	bsr      read_operand_word
	move.w   reg_d7+2(%a6),%d1
	or.l     %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d7+2(%a6)
	jmp      exception_handled

|###################################################
|# or_long_ea_to_D7                                #
|###################################################
	.align	1
or_long_ea_to_D7:
	bsr      read_operand_long
	move.l   reg_d7(%a6),%d1
	or.l     %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d7(%a6)
	jmp      exception_handled

|###################################################
|# or_byte_D7_to_ea                                #
|###################################################
	.align	1
or_byte_D7_to_ea:
	move.b   reg_d7+3(%a6),%d1
	bsr      read_then_write_operand_byte
	or.l     %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_572:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      sbcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      sbcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      or_byte_D7_to_ea
illegal_114:
	jmp      illegal

|###################################################
|# or_word_D7_to_ea                                #
|###################################################
	.align	1
or_word_D7_to_ea:
	move.w   reg_d7+2(%a6),%d1
	bsr      read_then_write_operand_word
	or.l     %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_573:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      pack_DxDy
	cmpi.l   #0x10,%d4
	bcs      pack_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_word_D7_to_ea
illegal_115:
	jmp      illegal

|###################################################
|# or_long_D7_to_ea                                #
|###################################################
	.align	1
or_long_D7_to_ea:
	move.l   reg_d7(%a6),%d1
	bsr      read_then_write_operand_long
	or.l     %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_574:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      unpk_DxDy
	cmpi.l   #0x10,%d4
	bcs      unpk_AxAy
	cmpi.l   #0x3a,%d4
	bcs      or_long_D7_to_ea
illegal_116:
	jmp      illegal

|###################################################
|# sub_byte_ea_from_D0                             #
|###################################################
	.align	1
sub_byte_ea_from_D0:
	bsr      read_operand_byte
	move.b   reg_d0+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d0+3(%a6)
	jmp      exception_handled

|###################################################
|# sub_word_ea_from_D0                             #
|###################################################
	.align	1
sub_word_ea_from_D0:
	bsr      read_operand_word
	move.w   reg_d0+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d0+2(%a6)
	jmp      exception_handled

|###################################################
|# sub_long_ea_from_D0                             #
|###################################################
	.align	1
sub_long_ea_from_D0:
	bsr      read_operand_long
	move.l   reg_d0(%a6),%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d0(%a6)
	jmp      exception_handled

|###################################################
|# suba_word_ea_from_A0                            #
|###################################################
	.align	1
suba_word_ea_from_A0:
	bsr      read_operand_word
	move.l   reg_a0(%a6),%a2
	ext.l    %d0
	sub.l    %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# subx_byte_predecrement                          #
|###################################################
	.align	1
subx_byte_predecrement:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_byte
	move.l   %d0,%d2
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d4
	lsl.l    %d4,%d2
	lsl.l    %d4,%d0
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	subx.l   %d2,%d0
	move     %ccr,%d3
	and.l    #0xff000000,%d0
	bne.s    _M68k_949_
	andi.l   #0x04,%d1
	bclr     #2,%d3
	or.l     %d1,%d3
_M68k_949_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d0
	jmp      (%a3)

|###################################################
|# subx_byte_ea_from_D0                            #
|###################################################
	.align	1
subx_byte_ea_from_D0:
	bsr      read_operand_byte
	move.b   reg_d0+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xff000000,%d1
	bne.s    _M68k_941_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_941_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d0+3(%a6)
	jmp      exception_handled
second_level_dispatch_580:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_byte_ea_from_D0
	cmpi.l   #0x10,%d4
	bcs      subx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_byte_D0_to_ea
illegal_117:
	jmp      illegal

|###################################################
|# sub_byte_D0_to_ea                               #
|###################################################
	.align	1
sub_byte_D0_to_ea:
	move.b   reg_d0+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_word_predecrement                          #
|###################################################
	.align	1
subx_word_predecrement:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_word
	move.l   %d0,%d2
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_word
	moveq.l  #16,%d4
	lsl.l    %d4,%d2
	lsl.l    %d4,%d0
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	subx.l   %d2,%d0
	move     %ccr,%d3
	and.l    #0xffff0000,%d0
	bne.s    _M68k_958_
	andi.l   #0x04,%d1
	bclr     #2,%d3
	or.l     %d1,%d3
_M68k_958_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d0
	jmp      (%a3)

|###################################################
|# subx_word_ea_from_D0                            #
|###################################################
	.align	1
subx_word_ea_from_D0:
	bsr      read_operand_word
	move.w   reg_d0+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xffff0000,%d1
	bne.s    _M68k_950_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_950_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d0+2(%a6)
	jmp      exception_handled
second_level_dispatch_581:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_word_ea_from_D0
	cmpi.l   #0x10,%d4
	bcs      subx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_word_D0_to_ea
illegal_118:
	jmp      illegal

|###################################################
|# sub_word_D0_to_ea                               #
|###################################################
	.align	1
sub_word_D0_to_ea:
	move.w   reg_d0+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_long_predecrement                          #
|###################################################
	.align	1
subx_long_predecrement:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_long
	move.l   %d0,%d2
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_long
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	subx.l   %d2,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# subx_long_ea_from_D0                            #
|###################################################
	.align	1
subx_long_ea_from_D0:
	bsr      read_operand_long
	move.l   reg_d0(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d0(%a6)
	jmp      exception_handled
second_level_dispatch_582:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_long_ea_from_D0
	cmpi.l   #0x10,%d4
	bcs      subx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_long_D0_to_ea
illegal_119:
	jmp      illegal

|###################################################
|# sub_long_D0_to_ea                               #
|###################################################
	.align	1
sub_long_D0_to_ea:
	move.l   reg_d0(%a6),%d1
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# suba_long_ea_from_A0                            #
|###################################################
	.align	1
suba_long_ea_from_A0:
	bsr      read_operand_long
	move.l   reg_a0(%a6),%a2
	suba.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# sub_byte_ea_from_D1                             #
|###################################################
	.align	1
sub_byte_ea_from_D1:
	bsr      read_operand_byte
	move.b   reg_d1+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d1+3(%a6)
	jmp      exception_handled

|###################################################
|# sub_word_ea_from_D1                             #
|###################################################
	.align	1
sub_word_ea_from_D1:
	bsr      read_operand_word
	move.w   reg_d1+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d1+2(%a6)
	jmp      exception_handled

|###################################################
|# sub_long_ea_from_D1                             #
|###################################################
	.align	1
sub_long_ea_from_D1:
	bsr      read_operand_long
	move.l   reg_d1(%a6),%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d1(%a6)
	jmp      exception_handled

|###################################################
|# suba_word_ea_from_A1                            #
|###################################################
	.align	1
suba_word_ea_from_A1:
	bsr      read_operand_word
	move.l   reg_a1(%a6),%a2
	ext.l    %d0
	sub.l    %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# subx_byte_ea_from_D1                            #
|###################################################
	.align	1
subx_byte_ea_from_D1:
	bsr      read_operand_byte
	move.b   reg_d1+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xff000000,%d1
	bne.s    _M68k_942_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_942_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d1+3(%a6)
	jmp      exception_handled
second_level_dispatch_588:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_byte_ea_from_D1
	cmpi.l   #0x10,%d4
	bcs      subx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_byte_D1_to_ea
illegal_120:
	jmp      illegal

|###################################################
|# sub_byte_D1_to_ea                               #
|###################################################
	.align	1
sub_byte_D1_to_ea:
	move.b   reg_d1+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_word_ea_from_D1                            #
|###################################################
	.align	1
subx_word_ea_from_D1:
	bsr      read_operand_word
	move.w   reg_d1+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xffff0000,%d1
	bne.s    _M68k_951_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_951_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d1+2(%a6)
	jmp      exception_handled
second_level_dispatch_589:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_word_ea_from_D1
	cmpi.l   #0x10,%d4
	bcs      subx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_word_D1_to_ea
illegal_121:
	jmp      illegal

|###################################################
|# sub_word_D1_to_ea                               #
|###################################################
	.align	1
sub_word_D1_to_ea:
	move.w   reg_d1+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_long_ea_from_D1                            #
|###################################################
	.align	1
subx_long_ea_from_D1:
	bsr      read_operand_long
	move.l   reg_d1(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d1(%a6)
	jmp      exception_handled
second_level_dispatch_590:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_long_ea_from_D1
	cmpi.l   #0x10,%d4
	bcs      subx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_long_D1_to_ea
illegal_122:
	jmp      illegal

|###################################################
|# sub_long_D1_to_ea                               #
|###################################################
	.align	1
sub_long_D1_to_ea:
	move.l   reg_d1(%a6),%d1
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# suba_long_ea_from_A1                            #
|###################################################
	.align	1
suba_long_ea_from_A1:
	bsr      read_operand_long
	move.l   reg_a1(%a6),%a2
	suba.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# sub_byte_ea_from_D2                             #
|###################################################
	.align	1
sub_byte_ea_from_D2:
	bsr      read_operand_byte
	move.b   reg_d2+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d2+3(%a6)
	jmp      exception_handled

|###################################################
|# sub_word_ea_from_D2                             #
|###################################################
	.align	1
sub_word_ea_from_D2:
	bsr      read_operand_word
	move.w   reg_d2+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d2+2(%a6)
	jmp      exception_handled

|###################################################
|# sub_long_ea_from_D2                             #
|###################################################
	.align	1
sub_long_ea_from_D2:
	bsr      read_operand_long
	move.l   reg_d2(%a6),%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d2(%a6)
	jmp      exception_handled

|###################################################
|# suba_word_ea_from_A2                            #
|###################################################
	.align	1
suba_word_ea_from_A2:
	bsr      read_operand_word
	move.l   reg_a2(%a6),%a2
	ext.l    %d0
	sub.l    %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# subx_byte_ea_from_D2                            #
|###################################################
	.align	1
subx_byte_ea_from_D2:
	bsr      read_operand_byte
	move.b   reg_d2+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xff000000,%d1
	bne.s    _M68k_943_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_943_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d2+3(%a6)
	jmp      exception_handled
second_level_dispatch_596:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_byte_ea_from_D2
	cmpi.l   #0x10,%d4
	bcs      subx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_byte_D2_to_ea
illegal_123:
	jmp      illegal

|###################################################
|# sub_byte_D2_to_ea                               #
|###################################################
	.align	1
sub_byte_D2_to_ea:
	move.b   reg_d2+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_word_ea_from_D2                            #
|###################################################
	.align	1
subx_word_ea_from_D2:
	bsr      read_operand_word
	move.w   reg_d2+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xffff0000,%d1
	bne.s    _M68k_952_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_952_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d2+2(%a6)
	jmp      exception_handled
second_level_dispatch_597:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_word_ea_from_D2
	cmpi.l   #0x10,%d4
	bcs      subx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_word_D2_to_ea
illegal_124:
	jmp      illegal

|###################################################
|# sub_word_D2_to_ea                               #
|###################################################
	.align	1
sub_word_D2_to_ea:
	move.w   reg_d2+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_long_ea_from_D2                            #
|###################################################
	.align	1
subx_long_ea_from_D2:
	bsr      read_operand_long
	move.l   reg_d2(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d2(%a6)
	jmp      exception_handled
second_level_dispatch_598:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_long_ea_from_D2
	cmpi.l   #0x10,%d4
	bcs      subx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_long_D2_to_ea
illegal_125:
	jmp      illegal

|###################################################
|# sub_long_D2_to_ea                               #
|###################################################
	.align	1
sub_long_D2_to_ea:
	move.l   reg_d2(%a6),%d1
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# suba_long_ea_from_A2                            #
|###################################################
	.align	1
suba_long_ea_from_A2:
	bsr      read_operand_long
	move.l   reg_a2(%a6),%a2
	suba.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# sub_byte_ea_from_D3                             #
|###################################################
	.align	1
sub_byte_ea_from_D3:
	bsr      read_operand_byte
	move.b   reg_d3+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d3+3(%a6)
	jmp      exception_handled

|###################################################
|# sub_word_ea_from_D3                             #
|###################################################
	.align	1
sub_word_ea_from_D3:
	bsr      read_operand_word
	move.w   reg_d3+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d3+2(%a6)
	jmp      exception_handled

|###################################################
|# sub_long_ea_from_D3                             #
|###################################################
	.align	1
sub_long_ea_from_D3:
	bsr      read_operand_long
	move.l   reg_d3(%a6),%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d3(%a6)
	jmp      exception_handled

|###################################################
|# suba_word_ea_from_A3                            #
|###################################################
	.align	1
suba_word_ea_from_A3:
	bsr      read_operand_word
	move.l   reg_a3(%a6),%a2
	ext.l    %d0
	sub.l    %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# subx_byte_ea_from_D3                            #
|###################################################
	.align	1
subx_byte_ea_from_D3:
	bsr      read_operand_byte
	move.b   reg_d3+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xff000000,%d1
	bne.s    _M68k_944_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_944_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d3+3(%a6)
	jmp      exception_handled
second_level_dispatch_604:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_byte_ea_from_D3
	cmpi.l   #0x10,%d4
	bcs      subx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_byte_D3_to_ea
illegal_126:
	jmp      illegal

|###################################################
|# sub_byte_D3_to_ea                               #
|###################################################
	.align	1
sub_byte_D3_to_ea:
	move.b   reg_d3+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_word_ea_from_D3                            #
|###################################################
	.align	1
subx_word_ea_from_D3:
	bsr      read_operand_word
	move.w   reg_d3+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xffff0000,%d1
	bne.s    _M68k_953_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_953_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d3+2(%a6)
	jmp      exception_handled
second_level_dispatch_605:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_word_ea_from_D3
	cmpi.l   #0x10,%d4
	bcs      subx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_word_D3_to_ea
illegal_127:
	jmp      illegal

|###################################################
|# sub_word_D3_to_ea                               #
|###################################################
	.align	1
sub_word_D3_to_ea:
	move.w   reg_d3+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_long_ea_from_D3                            #
|###################################################
	.align	1
subx_long_ea_from_D3:
	bsr      read_operand_long
	move.l   reg_d3(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d3(%a6)
	jmp      exception_handled
second_level_dispatch_606:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_long_ea_from_D3
	cmpi.l   #0x10,%d4
	bcs      subx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_long_D3_to_ea
illegal_128:
	jmp      illegal

|###################################################
|# sub_long_D3_to_ea                               #
|###################################################
	.align	1
sub_long_D3_to_ea:
	move.l   reg_d3(%a6),%d1
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# suba_long_ea_from_A3                            #
|###################################################
	.align	1
suba_long_ea_from_A3:
	bsr      read_operand_long
	move.l   reg_a3(%a6),%a2
	suba.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# sub_byte_ea_from_D4                             #
|###################################################
	.align	1
sub_byte_ea_from_D4:
	bsr      read_operand_byte
	move.b   reg_d4+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d4+3(%a6)
	jmp      exception_handled

|###################################################
|# sub_word_ea_from_D4                             #
|###################################################
	.align	1
sub_word_ea_from_D4:
	bsr      read_operand_word
	move.w   reg_d4+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d4+2(%a6)
	jmp      exception_handled

|###################################################
|# sub_long_ea_from_D4                             #
|###################################################
	.align	1
sub_long_ea_from_D4:
	bsr      read_operand_long
	move.l   reg_d4(%a6),%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d4(%a6)
	jmp      exception_handled

|###################################################
|# suba_word_ea_from_A4                            #
|###################################################
	.align	1
suba_word_ea_from_A4:
	bsr      read_operand_word
	move.l   reg_a4(%a6),%a2
	ext.l    %d0
	sub.l    %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# subx_byte_ea_from_D4                            #
|###################################################
	.align	1
subx_byte_ea_from_D4:
	bsr      read_operand_byte
	move.b   reg_d4+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xff000000,%d1
	bne.s    _M68k_945_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_945_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d4+3(%a6)
	jmp      exception_handled
second_level_dispatch_612:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_byte_ea_from_D4
	cmpi.l   #0x10,%d4
	bcs      subx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_byte_D4_to_ea
illegal_129:
	jmp      illegal

|###################################################
|# sub_byte_D4_to_ea                               #
|###################################################
	.align	1
sub_byte_D4_to_ea:
	move.b   reg_d4+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_word_ea_from_D4                            #
|###################################################
	.align	1
subx_word_ea_from_D4:
	bsr      read_operand_word
	move.w   reg_d4+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xffff0000,%d1
	bne.s    _M68k_954_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_954_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d4+2(%a6)
	jmp      exception_handled
second_level_dispatch_613:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_word_ea_from_D4
	cmpi.l   #0x10,%d4
	bcs      subx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_word_D4_to_ea
illegal_130:
	jmp      illegal

|###################################################
|# sub_word_D4_to_ea                               #
|###################################################
	.align	1
sub_word_D4_to_ea:
	move.w   reg_d4+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_long_ea_from_D4                            #
|###################################################
	.align	1
subx_long_ea_from_D4:
	bsr      read_operand_long
	move.l   reg_d4(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d4(%a6)
	jmp      exception_handled
second_level_dispatch_614:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_long_ea_from_D4
	cmpi.l   #0x10,%d4
	bcs      subx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_long_D4_to_ea
illegal_131:
	jmp      illegal

|###################################################
|# sub_long_D4_to_ea                               #
|###################################################
	.align	1
sub_long_D4_to_ea:
	move.l   reg_d4(%a6),%d1
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# suba_long_ea_from_A4                            #
|###################################################
	.align	1
suba_long_ea_from_A4:
	bsr      read_operand_long
	move.l   reg_a4(%a6),%a2
	suba.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# sub_byte_ea_from_D5                             #
|###################################################
	.align	1
sub_byte_ea_from_D5:
	bsr      read_operand_byte
	move.b   reg_d5+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d5+3(%a6)
	jmp      exception_handled

|###################################################
|# sub_word_ea_from_D5                             #
|###################################################
	.align	1
sub_word_ea_from_D5:
	bsr      read_operand_word
	move.w   reg_d5+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d5+2(%a6)
	jmp      exception_handled

|###################################################
|# sub_long_ea_from_D5                             #
|###################################################
	.align	1
sub_long_ea_from_D5:
	bsr      read_operand_long
	move.l   reg_d5(%a6),%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d5(%a6)
	jmp      exception_handled

|###################################################
|# suba_word_ea_from_A5                            #
|###################################################
	.align	1
suba_word_ea_from_A5:
	bsr      read_operand_word
	move.l   reg_a5(%a6),%a2
	ext.l    %d0
	sub.l    %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# subx_byte_ea_from_D5                            #
|###################################################
	.align	1
subx_byte_ea_from_D5:
	bsr      read_operand_byte
	move.b   reg_d5+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xff000000,%d1
	bne.s    _M68k_946_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_946_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d5+3(%a6)
	jmp      exception_handled
second_level_dispatch_620:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_byte_ea_from_D5
	cmpi.l   #0x10,%d4
	bcs      subx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_byte_D5_to_ea
illegal_132:
	jmp      illegal

|###################################################
|# sub_byte_D5_to_ea                               #
|###################################################
	.align	1
sub_byte_D5_to_ea:
	move.b   reg_d5+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_word_ea_from_D5                            #
|###################################################
	.align	1
subx_word_ea_from_D5:
	bsr      read_operand_word
	move.w   reg_d5+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xffff0000,%d1
	bne.s    _M68k_955_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_955_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d5+2(%a6)
	jmp      exception_handled
second_level_dispatch_621:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_word_ea_from_D5
	cmpi.l   #0x10,%d4
	bcs      subx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_word_D5_to_ea
illegal_133:
	jmp      illegal

|###################################################
|# sub_word_D5_to_ea                               #
|###################################################
	.align	1
sub_word_D5_to_ea:
	move.w   reg_d5+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_long_ea_from_D5                            #
|###################################################
	.align	1
subx_long_ea_from_D5:
	bsr      read_operand_long
	move.l   reg_d5(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d5(%a6)
	jmp      exception_handled
second_level_dispatch_622:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_long_ea_from_D5
	cmpi.l   #0x10,%d4
	bcs      subx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_long_D5_to_ea
illegal_134:
	jmp      illegal

|###################################################
|# sub_long_D5_to_ea                               #
|###################################################
	.align	1
sub_long_D5_to_ea:
	move.l   reg_d5(%a6),%d1
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# suba_long_ea_from_A5                            #
|###################################################
	.align	1
suba_long_ea_from_A5:
	bsr      read_operand_long
	move.l   reg_a5(%a6),%a2
	suba.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# sub_byte_ea_from_D6                             #
|###################################################
	.align	1
sub_byte_ea_from_D6:
	bsr      read_operand_byte
	move.b   reg_d6+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d6+3(%a6)
	jmp      exception_handled

|###################################################
|# sub_word_ea_from_D6                             #
|###################################################
	.align	1
sub_word_ea_from_D6:
	bsr      read_operand_word
	move.w   reg_d6+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d6+2(%a6)
	jmp      exception_handled

|###################################################
|# sub_long_ea_from_D6                             #
|###################################################
	.align	1
sub_long_ea_from_D6:
	bsr      read_operand_long
	move.l   reg_d6(%a6),%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d6(%a6)
	jmp      exception_handled

|###################################################
|# suba_word_ea_from_A6                            #
|###################################################
	.align	1
suba_word_ea_from_A6:
	bsr      read_operand_word
	move.l   reg_a6(%a6),%a2
	ext.l    %d0
	sub.l    %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# subx_byte_ea_from_D6                            #
|###################################################
	.align	1
subx_byte_ea_from_D6:
	bsr      read_operand_byte
	move.b   reg_d6+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xff000000,%d1
	bne.s    _M68k_947_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_947_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d6+3(%a6)
	jmp      exception_handled
second_level_dispatch_628:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_byte_ea_from_D6
	cmpi.l   #0x10,%d4
	bcs      subx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_byte_D6_to_ea
illegal_135:
	jmp      illegal

|###################################################
|# sub_byte_D6_to_ea                               #
|###################################################
	.align	1
sub_byte_D6_to_ea:
	move.b   reg_d6+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_word_ea_from_D6                            #
|###################################################
	.align	1
subx_word_ea_from_D6:
	bsr      read_operand_word
	move.w   reg_d6+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xffff0000,%d1
	bne.s    _M68k_956_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_956_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d6+2(%a6)
	jmp      exception_handled
second_level_dispatch_629:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_word_ea_from_D6
	cmpi.l   #0x10,%d4
	bcs      subx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_word_D6_to_ea
illegal_136:
	jmp      illegal

|###################################################
|# sub_word_D6_to_ea                               #
|###################################################
	.align	1
sub_word_D6_to_ea:
	move.w   reg_d6+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_long_ea_from_D6                            #
|###################################################
	.align	1
subx_long_ea_from_D6:
	bsr      read_operand_long
	move.l   reg_d6(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d6(%a6)
	jmp      exception_handled
second_level_dispatch_630:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_long_ea_from_D6
	cmpi.l   #0x10,%d4
	bcs      subx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_long_D6_to_ea
illegal_137:
	jmp      illegal

|###################################################
|# sub_long_D6_to_ea                               #
|###################################################
	.align	1
sub_long_D6_to_ea:
	move.l   reg_d6(%a6),%d1
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# suba_long_ea_from_A6                            #
|###################################################
	.align	1
suba_long_ea_from_A6:
	bsr      read_operand_long
	move.l   reg_a6(%a6),%a2
	suba.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# sub_byte_ea_from_D7                             #
|###################################################
	.align	1
sub_byte_ea_from_D7:
	bsr      read_operand_byte
	move.b   reg_d7+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d7+3(%a6)
	jmp      exception_handled

|###################################################
|# sub_word_ea_from_D7                             #
|###################################################
	.align	1
sub_word_ea_from_D7:
	bsr      read_operand_word
	move.w   reg_d7+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d7+2(%a6)
	jmp      exception_handled

|###################################################
|# sub_long_ea_from_D7                             #
|###################################################
	.align	1
sub_long_ea_from_D7:
	bsr      read_operand_long
	move.l   reg_d7(%a6),%d1
	sub.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d7(%a6)
	jmp      exception_handled

|###################################################
|# suba_word_ea_from_A7                            #
|###################################################
	.align	1
suba_word_ea_from_A7:
	bsr      read_operand_word
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	ext.l    %d0
	sub.l    %d0,%a2
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# subx_byte_ea_from_D7                            #
|###################################################
	.align	1
subx_byte_ea_from_D7:
	bsr      read_operand_byte
	move.b   reg_d7+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xff000000,%d1
	bne.s    _M68k_948_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_948_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d7+3(%a6)
	jmp      exception_handled
second_level_dispatch_636:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_byte_ea_from_D7
	cmpi.l   #0x10,%d4
	bcs      subx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_byte_D7_to_ea
illegal_138:
	jmp      illegal

|###################################################
|# sub_byte_D7_to_ea                               #
|###################################################
	.align	1
sub_byte_D7_to_ea:
	move.b   reg_d7+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_word_ea_from_D7                            #
|###################################################
	.align	1
subx_word_ea_from_D7:
	bsr      read_operand_word
	move.w   reg_d7+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d3
	and.l    #0xffff0000,%d1
	bne.s    _M68k_957_
	andi.l   #0x04,%d2
	bclr     #2,%d3
	or.l     %d2,%d3
_M68k_957_:
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d7+2(%a6)
	jmp      exception_handled
second_level_dispatch_637:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_word_ea_from_D7
	cmpi.l   #0x10,%d4
	bcs      subx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_word_D7_to_ea
illegal_139:
	jmp      illegal

|###################################################
|# sub_word_D7_to_ea                               #
|###################################################
	.align	1
sub_word_D7_to_ea:
	move.w   reg_d7+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# subx_long_ea_from_D7                            #
|###################################################
	.align	1
subx_long_ea_from_D7:
	bsr      read_operand_long
	move.l   reg_d7(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d7(%a6)
	jmp      exception_handled
second_level_dispatch_638:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      subx_long_ea_from_D7
	cmpi.l   #0x10,%d4
	bcs      subx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      sub_long_D7_to_ea
illegal_140:
	jmp      illegal

|###################################################
|# sub_long_D7_to_ea                               #
|###################################################
	.align	1
sub_long_D7_to_ea:
	move.l   reg_d7(%a6),%d1
	bsr      read_then_write_operand_long
	sub.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# suba_long_ea_from_A7                            #
|###################################################
	.align	1
suba_long_ea_from_A7:
	bsr      read_operand_long
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	suba.l   %d0,%a2
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# cmp_byte_ea_to_D0                               #
|###################################################
	.align	1
cmp_byte_ea_to_D0:
	bsr      read_operand_byte
	move.b   reg_d0+3(%a6),%d1
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_word_ea_to_D0                               #
|###################################################
	.align	1
cmp_word_ea_to_D0:
	bsr      read_operand_word
	move.w   reg_d0+2(%a6),%d1
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_long_ea_to_D0                               #
|###################################################
	.align	1
cmp_long_ea_to_D0:
	bsr      read_operand_long
	move.l   reg_d0(%a6),%d1
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_word_ea_to_A0                              #
|###################################################
	.align	1
cmpa_word_ea_to_A0:
	bsr      read_operand_word
	move.l   reg_a0(%a6),%a2
	ext.l    %d0
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_byte_D0_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_708:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_byte_D0_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_byte_postincrement_A0
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_byte_D0_to_ea:
	move.b   reg_d0+3(%a6),%d1
	bsr      read_then_write_operand_byte
	eor.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_byte_postincrement_A0                      #
|###################################################
	.align	1
cmpm_byte_postincrement_A0:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_byte
	move.l   reg_a0(%a6),%a2
	move.b   (%a2)+,%d1
	move.l   %a2,reg_a0(%a6)
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_word_D0_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_709:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_word_D0_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_word_postincrement_A0
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_word_D0_to_ea:
	move.w   reg_d0+2(%a6),%d1
	bsr      read_then_write_operand_word
	eor.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_word_postincrement_A0                      #
|###################################################
	.align	1
cmpm_word_postincrement_A0:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_word
	move.l   reg_a0(%a6),%a2
	move.w   (%a2)+,%d1
	move.l   %a2,reg_a0(%a6)
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_long_D0_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_710:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_long_D0_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_long_postincrement_A0
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_long_D0_to_ea:
	move.l   reg_d0(%a6),%d1
	bsr      read_then_write_operand_long
	eor.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_long_postincrement_A0                      #
|###################################################
	.align	1
cmpm_long_postincrement_A0:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_long
	move.l   reg_a0(%a6),%a2
	move.l   (%a2)+,%d1
	move.l   %a2,reg_a0(%a6)
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_long_ea_to_A0                              #
|###################################################
	.align	1
cmpa_long_ea_to_A0:
	bsr      read_operand_long
	move.l   reg_a0(%a6),%a2
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_byte_ea_to_D1                               #
|###################################################
	.align	1
cmp_byte_ea_to_D1:
	bsr      read_operand_byte
	move.b   reg_d1+3(%a6),%d1
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_word_ea_to_D1                               #
|###################################################
	.align	1
cmp_word_ea_to_D1:
	bsr      read_operand_word
	move.w   reg_d1+2(%a6),%d1
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_long_ea_to_D1                               #
|###################################################
	.align	1
cmp_long_ea_to_D1:
	bsr      read_operand_long
	move.l   reg_d1(%a6),%d1
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_word_ea_to_A1                              #
|###################################################
	.align	1
cmpa_word_ea_to_A1:
	bsr      read_operand_word
	move.l   reg_a1(%a6),%a2
	ext.l    %d0
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_byte_D1_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_716:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_byte_D1_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_byte_postincrement_A1
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_byte_D1_to_ea:
	move.b   reg_d1+3(%a6),%d1
	bsr      read_then_write_operand_byte
	eor.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_byte_postincrement_A1                      #
|###################################################
	.align	1
cmpm_byte_postincrement_A1:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_byte
	move.l   reg_a1(%a6),%a2
	move.b   (%a2)+,%d1
	move.l   %a2,reg_a1(%a6)
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_word_D1_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_717:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_word_D1_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_word_postincrement_A1
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_word_D1_to_ea:
	move.w   reg_d1+2(%a6),%d1
	bsr      read_then_write_operand_word
	eor.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_word_postincrement_A1                      #
|###################################################
	.align	1
cmpm_word_postincrement_A1:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_word
	move.l   reg_a1(%a6),%a2
	move.w   (%a2)+,%d1
	move.l   %a2,reg_a1(%a6)
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_long_D1_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_718:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_long_D1_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_long_postincrement_A1
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_long_D1_to_ea:
	move.l   reg_d1(%a6),%d1
	bsr      read_then_write_operand_long
	eor.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_long_postincrement_A1                      #
|###################################################
	.align	1
cmpm_long_postincrement_A1:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_long
	move.l   reg_a1(%a6),%a2
	move.l   (%a2)+,%d1
	move.l   %a2,reg_a1(%a6)
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_long_ea_to_A1                              #
|###################################################
	.align	1
cmpa_long_ea_to_A1:
	bsr      read_operand_long
	move.l   reg_a1(%a6),%a2
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_byte_ea_to_D2                               #
|###################################################
	.align	1
cmp_byte_ea_to_D2:
	bsr      read_operand_byte
	move.b   reg_d2+3(%a6),%d1
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_word_ea_to_D2                               #
|###################################################
	.align	1
cmp_word_ea_to_D2:
	bsr      read_operand_word
	move.w   reg_d2+2(%a6),%d1
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_long_ea_to_D2                               #
|###################################################
	.align	1
cmp_long_ea_to_D2:
	bsr      read_operand_long
	move.l   reg_d2(%a6),%d1
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_word_ea_to_A2                              #
|###################################################
	.align	1
cmpa_word_ea_to_A2:
	bsr      read_operand_word
	move.l   reg_a2(%a6),%a2
	ext.l    %d0
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_byte_D2_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_724:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_byte_D2_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_byte_postincrement_A2
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_byte_D2_to_ea:
	move.b   reg_d2+3(%a6),%d1
	bsr      read_then_write_operand_byte
	eor.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_byte_postincrement_A2                      #
|###################################################
	.align	1
cmpm_byte_postincrement_A2:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_byte
	move.l   reg_a2(%a6),%a2
	move.b   (%a2)+,%d1
	move.l   %a2,reg_a2(%a6)
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_word_D2_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_725:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_word_D2_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_word_postincrement_A2
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_word_D2_to_ea:
	move.w   reg_d2+2(%a6),%d1
	bsr      read_then_write_operand_word
	eor.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_word_postincrement_A2                      #
|###################################################
	.align	1
cmpm_word_postincrement_A2:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_word
	move.l   reg_a2(%a6),%a2
	move.w   (%a2)+,%d1
	move.l   %a2,reg_a2(%a6)
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_long_D2_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_726:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_long_D2_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_long_postincrement_A2
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_long_D2_to_ea:
	move.l   reg_d2(%a6),%d1
	bsr      read_then_write_operand_long
	eor.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_long_postincrement_A2                      #
|###################################################
	.align	1
cmpm_long_postincrement_A2:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_long
	move.l   reg_a2(%a6),%a2
	move.l   (%a2)+,%d1
	move.l   %a2,reg_a2(%a6)
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_long_ea_to_A2                              #
|###################################################
	.align	1
cmpa_long_ea_to_A2:
	bsr      read_operand_long
	move.l   reg_a2(%a6),%a2
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_byte_ea_to_D3                               #
|###################################################
	.align	1
cmp_byte_ea_to_D3:
	bsr      read_operand_byte
	move.b   reg_d3+3(%a6),%d1
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_word_ea_to_D3                               #
|###################################################
	.align	1
cmp_word_ea_to_D3:
	bsr      read_operand_word
	move.w   reg_d3+2(%a6),%d1
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_long_ea_to_D3                               #
|###################################################
	.align	1
cmp_long_ea_to_D3:
	bsr      read_operand_long
	move.l   reg_d3(%a6),%d1
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_word_ea_to_A3                              #
|###################################################
	.align	1
cmpa_word_ea_to_A3:
	bsr      read_operand_word
	move.l   reg_a3(%a6),%a2
	ext.l    %d0
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_byte_D3_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_732:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_byte_D3_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_byte_postincrement_A3
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_byte_D3_to_ea:
	move.b   reg_d3+3(%a6),%d1
	bsr      read_then_write_operand_byte
	eor.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_byte_postincrement_A3                      #
|###################################################
	.align	1
cmpm_byte_postincrement_A3:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_byte
	move.l   reg_a3(%a6),%a2
	move.b   (%a2)+,%d1
	move.l   %a2,reg_a3(%a6)
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_word_D3_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_733:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_word_D3_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_word_postincrement_A3
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_word_D3_to_ea:
	move.w   reg_d3+2(%a6),%d1
	bsr      read_then_write_operand_word
	eor.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_word_postincrement_A3                      #
|###################################################
	.align	1
cmpm_word_postincrement_A3:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_word
	move.l   reg_a3(%a6),%a2
	move.w   (%a2)+,%d1
	move.l   %a2,reg_a3(%a6)
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_long_D3_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_734:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_long_D3_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_long_postincrement_A3
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_long_D3_to_ea:
	move.l   reg_d3(%a6),%d1
	bsr      read_then_write_operand_long
	eor.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_long_postincrement_A3                      #
|###################################################
	.align	1
cmpm_long_postincrement_A3:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_long
	move.l   reg_a3(%a6),%a2
	move.l   (%a2)+,%d1
	move.l   %a2,reg_a3(%a6)
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_long_ea_to_A3                              #
|###################################################
	.align	1
cmpa_long_ea_to_A3:
	bsr      read_operand_long
	move.l   reg_a3(%a6),%a2
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_byte_ea_to_D4                               #
|###################################################
	.align	1
cmp_byte_ea_to_D4:
	bsr      read_operand_byte
	move.b   reg_d4+3(%a6),%d1
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_word_ea_to_D4                               #
|###################################################
	.align	1
cmp_word_ea_to_D4:
	bsr      read_operand_word
	move.w   reg_d4+2(%a6),%d1
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_long_ea_to_D4                               #
|###################################################
	.align	1
cmp_long_ea_to_D4:
	bsr      read_operand_long
	move.l   reg_d4(%a6),%d1
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_word_ea_to_A4                              #
|###################################################
	.align	1
cmpa_word_ea_to_A4:
	bsr      read_operand_word
	move.l   reg_a4(%a6),%a2
	ext.l    %d0
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_byte_D4_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_740:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_byte_D4_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_byte_postincrement_A4
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_byte_D4_to_ea:
	move.b   reg_d4+3(%a6),%d1
	bsr      read_then_write_operand_byte
	eor.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_byte_postincrement_A4                      #
|###################################################
	.align	1
cmpm_byte_postincrement_A4:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_byte
	move.l   reg_a4(%a6),%a2
	move.b   (%a2)+,%d1
	move.l   %a2,reg_a4(%a6)
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_word_D4_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_741:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_word_D4_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_word_postincrement_A4
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_word_D4_to_ea:
	move.w   reg_d4+2(%a6),%d1
	bsr      read_then_write_operand_word
	eor.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_word_postincrement_A4                      #
|###################################################
	.align	1
cmpm_word_postincrement_A4:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_word
	move.l   reg_a4(%a6),%a2
	move.w   (%a2)+,%d1
	move.l   %a2,reg_a4(%a6)
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_long_D4_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_742:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_long_D4_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_long_postincrement_A4
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_long_D4_to_ea:
	move.l   reg_d4(%a6),%d1
	bsr      read_then_write_operand_long
	eor.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_long_postincrement_A4                      #
|###################################################
	.align	1
cmpm_long_postincrement_A4:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_long
	move.l   reg_a4(%a6),%a2
	move.l   (%a2)+,%d1
	move.l   %a2,reg_a4(%a6)
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_long_ea_to_A4                              #
|###################################################
	.align	1
cmpa_long_ea_to_A4:
	bsr      read_operand_long
	move.l   reg_a4(%a6),%a2
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_byte_ea_to_D5                               #
|###################################################
	.align	1
cmp_byte_ea_to_D5:
	bsr      read_operand_byte
	move.b   reg_d5+3(%a6),%d1
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_word_ea_to_D5                               #
|###################################################
	.align	1
cmp_word_ea_to_D5:
	bsr      read_operand_word
	move.w   reg_d5+2(%a6),%d1
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_long_ea_to_D5                               #
|###################################################
	.align	1
cmp_long_ea_to_D5:
	bsr      read_operand_long
	move.l   reg_d5(%a6),%d1
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_word_ea_to_A5                              #
|###################################################
	.align	1
cmpa_word_ea_to_A5:
	bsr      read_operand_word
	move.l   reg_a5(%a6),%a2
	ext.l    %d0
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_byte_D5_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_748:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_byte_D5_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_byte_postincrement_A5
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_byte_D5_to_ea:
	move.b   reg_d5+3(%a6),%d1
	bsr      read_then_write_operand_byte
	eor.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_byte_postincrement_A5                      #
|###################################################
	.align	1
cmpm_byte_postincrement_A5:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_byte
	move.l   reg_a5(%a6),%a2
	move.b   (%a2)+,%d1
	move.l   %a2,reg_a5(%a6)
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_word_D5_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_749:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_word_D5_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_word_postincrement_A5
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_word_D5_to_ea:
	move.w   reg_d5+2(%a6),%d1
	bsr      read_then_write_operand_word
	eor.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_word_postincrement_A5                      #
|###################################################
	.align	1
cmpm_word_postincrement_A5:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_word
	move.l   reg_a5(%a6),%a2
	move.w   (%a2)+,%d1
	move.l   %a2,reg_a5(%a6)
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_long_D5_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_750:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_long_D5_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_long_postincrement_A5
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_long_D5_to_ea:
	move.l   reg_d5(%a6),%d1
	bsr      read_then_write_operand_long
	eor.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_long_postincrement_A5                      #
|###################################################
	.align	1
cmpm_long_postincrement_A5:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_long
	move.l   reg_a5(%a6),%a2
	move.l   (%a2)+,%d1
	move.l   %a2,reg_a5(%a6)
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_long_ea_to_A5                              #
|###################################################
	.align	1
cmpa_long_ea_to_A5:
	bsr      read_operand_long
	move.l   reg_a5(%a6),%a2
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_byte_ea_to_D6                               #
|###################################################
	.align	1
cmp_byte_ea_to_D6:
	bsr      read_operand_byte
	move.b   reg_d6+3(%a6),%d1
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_word_ea_to_D6                               #
|###################################################
	.align	1
cmp_word_ea_to_D6:
	bsr      read_operand_word
	move.w   reg_d6+2(%a6),%d1
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_long_ea_to_D6                               #
|###################################################
	.align	1
cmp_long_ea_to_D6:
	bsr      read_operand_long
	move.l   reg_d6(%a6),%d1
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_word_ea_to_A6                              #
|###################################################
	.align	1
cmpa_word_ea_to_A6:
	bsr      read_operand_word
	move.l   reg_a6(%a6),%a2
	ext.l    %d0
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_byte_D6_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_756:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_byte_D6_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_byte_postincrement_A6
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_byte_D6_to_ea:
	move.b   reg_d6+3(%a6),%d1
	bsr      read_then_write_operand_byte
	eor.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_byte_postincrement_A6                      #
|###################################################
	.align	1
cmpm_byte_postincrement_A6:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_byte
	move.l   reg_a6(%a6),%a2
	move.b   (%a2)+,%d1
	move.l   %a2,reg_a6(%a6)
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_word_D6_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_757:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_word_D6_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_word_postincrement_A6
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_word_D6_to_ea:
	move.w   reg_d6+2(%a6),%d1
	bsr      read_then_write_operand_word
	eor.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_word_postincrement_A6                      #
|###################################################
	.align	1
cmpm_word_postincrement_A6:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_word
	move.l   reg_a6(%a6),%a2
	move.w   (%a2)+,%d1
	move.l   %a2,reg_a6(%a6)
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_long_D6_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_758:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_long_D6_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_long_postincrement_A6
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_long_D6_to_ea:
	move.l   reg_d6(%a6),%d1
	bsr      read_then_write_operand_long
	eor.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_long_postincrement_A6                      #
|###################################################
	.align	1
cmpm_long_postincrement_A6:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_long
	move.l   reg_a6(%a6),%a2
	move.l   (%a2)+,%d1
	move.l   %a2,reg_a6(%a6)
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_long_ea_to_A6                              #
|###################################################
	.align	1
cmpa_long_ea_to_A6:
	bsr      read_operand_long
	move.l   reg_a6(%a6),%a2
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_byte_ea_to_D7                               #
|###################################################
	.align	1
cmp_byte_ea_to_D7:
	bsr      read_operand_byte
	move.b   reg_d7+3(%a6),%d1
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_word_ea_to_D7                               #
|###################################################
	.align	1
cmp_word_ea_to_D7:
	bsr      read_operand_word
	move.w   reg_d7+2(%a6),%d1
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmp_long_ea_to_D7                               #
|###################################################
	.align	1
cmp_long_ea_to_D7:
	bsr      read_operand_long
	move.l   reg_d7(%a6),%d1
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_word_ea_to_A7                              #
|###################################################
	.align	1
cmpa_word_ea_to_A7:
	bsr      read_operand_word
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	ext.l    %d0
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_byte_D7_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_764:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_byte_D7_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_byte_postincrement_A7
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_byte_D7_to_ea:
	move.b   reg_d7+3(%a6),%d1
	bsr      read_then_write_operand_byte
	eor.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_byte_postincrement_A7                      #
|###################################################
	.align	1
cmpm_byte_postincrement_A7:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_byte
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.b   (%a2)+,%d1
	addq.l   #1,%a2
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	cmp.b    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_word_D7_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_765:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_word_D7_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_word_postincrement_A7
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_word_D7_to_ea:
	move.w   reg_d7+2(%a6),%d1
	bsr      read_then_write_operand_word
	eor.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_word_postincrement_A7                      #
|###################################################
	.align	1
cmpm_word_postincrement_A7:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_word
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.w   (%a2)+,%d1
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	cmp.w    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# eor_long_D7_to_ea                               #
|###################################################
	.align	1
second_level_dispatch_766:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      eor_long_D7_to_ea
	cmpi.l   #0x10,%d4
	bcs      cmpm_long_postincrement_A7
	cmpi.l   #0x3a,%d4
	bcc      illegal_141
eor_long_D7_to_ea:
	move.l   reg_d7(%a6),%d1
	bsr      read_then_write_operand_long
	eor.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# cmpm_long_postincrement_A7                      #
|###################################################
	.align	1
cmpm_long_postincrement_A7:
	and.l    #7,%d5
	ori.l    #0x18,%d5
	bsr      read_operand_long
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	move.l   (%a2)+,%d1
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	cmp.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# cmpa_long_ea_to_A7                              #
|###################################################
	.align	1
cmpa_long_ea_to_A7:
	bsr      read_operand_long
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	cmpa.l   %d0,%a2
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      exception_handled

|###################################################
|# and_byte_ea_to_D0                               #
|###################################################
	.align	1
and_byte_ea_to_D0:
	bsr      read_operand_byte
	move.b   reg_d0+3(%a6),%d1
	and.l    %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d0+3(%a6)
	jmp      exception_handled

|###################################################
|# and_word_ea_to_D0                               #
|###################################################
	.align	1
and_word_ea_to_D0:
	bsr      read_operand_word
	move.w   reg_d0+2(%a6),%d1
	and.l    %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d0+2(%a6)
	jmp      exception_handled

|###################################################
|# and_long_ea_to_D0                               #
|###################################################
	.align	1
and_long_ea_to_D0:
	bsr      read_operand_long
	move.l   reg_d0(%a6),%d1
	and.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d0(%a6)
	jmp      exception_handled

|###################################################
|# mulu_word                                       #
|###################################################
	.align	1
mulu_word:
	bsr      read_operand_word
	move.l   %d0,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_long
	mulu.w   %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# and_byte_D0_to_ea                               #
|###################################################
	.align	1
and_byte_D0_to_ea:
	move.b   reg_d0+3(%a6),%d1
	bsr      read_then_write_operand_byte
	and.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# abcd_AyAx                                       #
|###################################################
	.align	1
abcd_AyAx:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_byte
	move.l   %d0,%d2
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_byte
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	and.l    #0x000000ff,%d2
	and.l    #0x000000ff,%d0
	movea.l  #_PA_bcd_tables,%a2
	move.b   (_PA_BCDBIN,%a2,%d2.l),%d2
	move.b   (_PA_BCDBIN,%a2,%d0.l),%d0
	addx.l   %d2,%d0
	move.b   (_PA_BINBCD,%a2,%d0.l*2),%d3
	move.b   (_PA_BINBCD+1,%a2,%d0.l*2),%d0
	ori.l    #0x1b,%d1
	and.l    %d1,%d3
	move     %d3,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)
second_level_dispatch_780:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      abcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      abcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      and_byte_D1_to_ea
illegal_144:
	jmp      illegal

|###################################################
|# abcd_DyDx                                       #
|###################################################
	.align	1
abcd_DyDx:
	bsr      read_operand_byte
	move.l   %d0,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_byte
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	and.l    #0x000000ff,%d1
	and.l    #0x000000ff,%d0
	movea.l  #_PA_bcd_tables,%a2
	move.b   (_PA_BCDBIN,%a2,%d1.l),%d1
	move.b   (_PA_BCDBIN,%a2,%d0.l),%d0
	addx.l   %d1,%d0
	move.b   (_PA_BINBCD,%a2,%d0.l*2),%d3
	move.b   (_PA_BINBCD+1,%a2,%d0.l*2),%d0
	ori.l    #0x1b,%d2
	and.l    %d2,%d3
	move     %d3,%CCR
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)
second_level_dispatch_772:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      abcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      abcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      and_byte_D0_to_ea
illegal_141:
	jmp      illegal

|###################################################
|# exg_A0_Ay                                       #
|###################################################
	.align	1
exg_A0_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_a0(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_a0(%a6)
	jmp      (%a3)

|###################################################
|# exg_D0_Dy                                       #
|###################################################
	.align	1
exg_D0_Dy:
	bsr      read_then_write_operand_long
	move.l   reg_d0(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d0(%a6)
	jmp      (%a3)
second_level_dispatch_773:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      exg_D0_Dy
	cmpi.l   #0x10,%d4
	bcs      exg_A0_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_word_D0_to_ea
illegal_142:
	jmp      illegal

|###################################################
|# and_word_D0_to_ea                               #
|###################################################
	.align	1
and_word_D0_to_ea:
	move.w   reg_d0+2(%a6),%d1
	bsr      read_then_write_operand_word
	and.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# exg_D0_Ay                                       #
|###################################################
	.align	1
exg_D0_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_d0(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d0(%a6)
	jmp      (%a3)
second_level_dispatch_774:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      illegal_143
	cmpi.l   #0x10,%d4
	bcs      exg_D0_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_long_D0_to_ea
illegal_143:
	jmp      illegal

|###################################################
|# and_long_D0_to_ea                               #
|###################################################
	.align	1
and_long_D0_to_ea:
	move.l   reg_d0(%a6),%d1
	bsr      read_then_write_operand_long
	and.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# muls_word                                       #
|###################################################
	.align	1
muls_word:
	bsr      read_operand_word
	move.l   %d0,%d1
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_long
	muls.w   %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# and_byte_ea_to_D1                               #
|###################################################
	.align	1
and_byte_ea_to_D1:
	bsr      read_operand_byte
	move.b   reg_d1+3(%a6),%d1
	and.l    %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d1+3(%a6)
	jmp      exception_handled

|###################################################
|# and_word_ea_to_D1                               #
|###################################################
	.align	1
and_word_ea_to_D1:
	bsr      read_operand_word
	move.w   reg_d1+2(%a6),%d1
	and.l    %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d1+2(%a6)
	jmp      exception_handled

|###################################################
|# and_long_ea_to_D1                               #
|###################################################
	.align	1
and_long_ea_to_D1:
	bsr      read_operand_long
	move.l   reg_d1(%a6),%d1
	and.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d1(%a6)
	jmp      exception_handled

|###################################################
|# and_byte_D1_to_ea                               #
|###################################################
	.align	1
and_byte_D1_to_ea:
	move.b   reg_d1+3(%a6),%d1
	bsr      read_then_write_operand_byte
	and.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# exg_A1_Ay                                       #
|###################################################
	.align	1
exg_A1_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_a1(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_a1(%a6)
	jmp      (%a3)

|###################################################
|# exg_D1_Dy                                       #
|###################################################
	.align	1
exg_D1_Dy:
	bsr      read_then_write_operand_long
	move.l   reg_d1(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d1(%a6)
	jmp      (%a3)
second_level_dispatch_781:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      exg_D1_Dy
	cmpi.l   #0x10,%d4
	bcs      exg_A1_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_word_D1_to_ea
illegal_145:
	jmp      illegal

|###################################################
|# and_word_D1_to_ea                               #
|###################################################
	.align	1
and_word_D1_to_ea:
	move.w   reg_d1+2(%a6),%d1
	bsr      read_then_write_operand_word
	and.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# exg_D1_Ay                                       #
|###################################################
	.align	1
exg_D1_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_d1(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d1(%a6)
	jmp      (%a3)
second_level_dispatch_782:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      illegal_146
	cmpi.l   #0x10,%d4
	bcs      exg_D1_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_long_D1_to_ea
illegal_146:
	jmp      illegal

|###################################################
|# and_long_D1_to_ea                               #
|###################################################
	.align	1
and_long_D1_to_ea:
	move.l   reg_d1(%a6),%d1
	bsr      read_then_write_operand_long
	and.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# and_byte_ea_to_D2                               #
|###################################################
	.align	1
and_byte_ea_to_D2:
	bsr      read_operand_byte
	move.b   reg_d2+3(%a6),%d1
	and.l    %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d2+3(%a6)
	jmp      exception_handled

|###################################################
|# and_word_ea_to_D2                               #
|###################################################
	.align	1
and_word_ea_to_D2:
	bsr      read_operand_word
	move.w   reg_d2+2(%a6),%d1
	and.l    %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d2+2(%a6)
	jmp      exception_handled

|###################################################
|# and_long_ea_to_D2                               #
|###################################################
	.align	1
and_long_ea_to_D2:
	bsr      read_operand_long
	move.l   reg_d2(%a6),%d1
	and.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d2(%a6)
	jmp      exception_handled

|###################################################
|# and_byte_D2_to_ea                               #
|###################################################
	.align	1
and_byte_D2_to_ea:
	move.b   reg_d2+3(%a6),%d1
	bsr      read_then_write_operand_byte
	and.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_788:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      abcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      abcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      and_byte_D2_to_ea
illegal_147:
	jmp      illegal

|###################################################
|# exg_A2_Ay                                       #
|###################################################
	.align	1
exg_A2_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_a2(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_a2(%a6)
	jmp      (%a3)

|###################################################
|# exg_D2_Dy                                       #
|###################################################
	.align	1
exg_D2_Dy:
	bsr      read_then_write_operand_long
	move.l   reg_d2(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d2(%a6)
	jmp      (%a3)
second_level_dispatch_789:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      exg_D2_Dy
	cmpi.l   #0x10,%d4
	bcs      exg_A2_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_word_D2_to_ea
illegal_148:
	jmp      illegal

|###################################################
|# and_word_D2_to_ea                               #
|###################################################
	.align	1
and_word_D2_to_ea:
	move.w   reg_d2+2(%a6),%d1
	bsr      read_then_write_operand_word
	and.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# exg_D2_Ay                                       #
|###################################################
	.align	1
exg_D2_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_d2(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d2(%a6)
	jmp      (%a3)
second_level_dispatch_790:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      illegal_149
	cmpi.l   #0x10,%d4
	bcs      exg_D2_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_long_D2_to_ea
illegal_149:
	jmp      illegal

|###################################################
|# and_long_D2_to_ea                               #
|###################################################
	.align	1
and_long_D2_to_ea:
	move.l   reg_d2(%a6),%d1
	bsr      read_then_write_operand_long
	and.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# and_byte_ea_to_D3                               #
|###################################################
	.align	1
and_byte_ea_to_D3:
	bsr      read_operand_byte
	move.b   reg_d3+3(%a6),%d1
	and.l    %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d3+3(%a6)
	jmp      exception_handled

|###################################################
|# and_word_ea_to_D3                               #
|###################################################
	.align	1
and_word_ea_to_D3:
	bsr      read_operand_word
	move.w   reg_d3+2(%a6),%d1
	and.l    %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d3+2(%a6)
	jmp      exception_handled

|###################################################
|# and_long_ea_to_D3                               #
|###################################################
	.align	1
and_long_ea_to_D3:
	bsr      read_operand_long
	move.l   reg_d3(%a6),%d1
	and.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d3(%a6)
	jmp      exception_handled

|###################################################
|# and_byte_D3_to_ea                               #
|###################################################
	.align	1
and_byte_D3_to_ea:
	move.b   reg_d3+3(%a6),%d1
	bsr      read_then_write_operand_byte
	and.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_796:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      abcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      abcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      and_byte_D3_to_ea
illegal_150:
	jmp      illegal

|###################################################
|# exg_A3_Ay                                       #
|###################################################
	.align	1
exg_A3_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_a3(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_a3(%a6)
	jmp      (%a3)

|###################################################
|# exg_D3_Dy                                       #
|###################################################
	.align	1
exg_D3_Dy:
	bsr      read_then_write_operand_long
	move.l   reg_d3(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d3(%a6)
	jmp      (%a3)
second_level_dispatch_797:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      exg_D3_Dy
	cmpi.l   #0x10,%d4
	bcs      exg_A3_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_word_D3_to_ea
illegal_151:
	jmp      illegal

|###################################################
|# and_word_D3_to_ea                               #
|###################################################
	.align	1
and_word_D3_to_ea:
	move.w   reg_d3+2(%a6),%d1
	bsr      read_then_write_operand_word
	and.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# exg_D3_Ay                                       #
|###################################################
	.align	1
exg_D3_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_d3(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d3(%a6)
	jmp      (%a3)
second_level_dispatch_798:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      illegal_152
	cmpi.l   #0x10,%d4
	bcs      exg_D3_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_long_D3_to_ea
illegal_152:
	jmp      illegal

|###################################################
|# and_long_D3_to_ea                               #
|###################################################
	.align	1
and_long_D3_to_ea:
	move.l   reg_d3(%a6),%d1
	bsr      read_then_write_operand_long
	and.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# and_byte_ea_to_D4                               #
|###################################################
	.align	1
and_byte_ea_to_D4:
	bsr      read_operand_byte
	move.b   reg_d4+3(%a6),%d1
	and.l    %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d4+3(%a6)
	jmp      exception_handled

|###################################################
|# and_word_ea_to_D4                               #
|###################################################
	.align	1
and_word_ea_to_D4:
	bsr      read_operand_word
	move.w   reg_d4+2(%a6),%d1
	and.l    %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d4+2(%a6)
	jmp      exception_handled

|###################################################
|# and_long_ea_to_D4                               #
|###################################################
	.align	1
and_long_ea_to_D4:
	bsr      read_operand_long
	move.l   reg_d4(%a6),%d1
	and.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d4(%a6)
	jmp      exception_handled

|###################################################
|# and_byte_D4_to_ea                               #
|###################################################
	.align	1
and_byte_D4_to_ea:
	move.b   reg_d4+3(%a6),%d1
	bsr      read_then_write_operand_byte
	and.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_804:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      abcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      abcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      and_byte_D4_to_ea
illegal_153:
	jmp      illegal

|###################################################
|# exg_A4_Ay                                       #
|###################################################
	.align	1
exg_A4_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_a4(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_a4(%a6)
	jmp      (%a3)

|###################################################
|# exg_D4_Dy                                       #
|###################################################
	.align	1
exg_D4_Dy:
	bsr      read_then_write_operand_long
	move.l   reg_d4(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d4(%a6)
	jmp      (%a3)
second_level_dispatch_805:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      exg_D4_Dy
	cmpi.l   #0x10,%d4
	bcs      exg_A4_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_word_D4_to_ea
illegal_154:
	jmp      illegal

|###################################################
|# and_word_D4_to_ea                               #
|###################################################
	.align	1
and_word_D4_to_ea:
	move.w   reg_d4+2(%a6),%d1
	bsr      read_then_write_operand_word
	and.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# exg_D4_Ay                                       #
|###################################################
	.align	1
exg_D4_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_d4(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d4(%a6)
	jmp      (%a3)
second_level_dispatch_806:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      illegal_155
	cmpi.l   #0x10,%d4
	bcs      exg_D4_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_long_D4_to_ea
illegal_155:
	jmp      illegal

|###################################################
|# and_long_D4_to_ea                               #
|###################################################
	.align	1
and_long_D4_to_ea:
	move.l   reg_d4(%a6),%d1
	bsr      read_then_write_operand_long
	and.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# and_byte_ea_to_D5                               #
|###################################################
	.align	1
and_byte_ea_to_D5:
	bsr      read_operand_byte
	move.b   reg_d5+3(%a6),%d1
	and.l    %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d5+3(%a6)
	jmp      exception_handled

|###################################################
|# and_word_ea_to_D5                               #
|###################################################
	.align	1
and_word_ea_to_D5:
	bsr      read_operand_word
	move.w   reg_d5+2(%a6),%d1
	and.l    %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d5+2(%a6)
	jmp      exception_handled

|###################################################
|# and_long_ea_to_D5                               #
|###################################################
	.align	1
and_long_ea_to_D5:
	bsr      read_operand_long
	move.l   reg_d5(%a6),%d1
	and.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d5(%a6)
	jmp      exception_handled

|###################################################
|# and_byte_D5_to_ea                               #
|###################################################
	.align	1
and_byte_D5_to_ea:
	move.b   reg_d5+3(%a6),%d1
	bsr      read_then_write_operand_byte
	and.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_812:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      abcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      abcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      and_byte_D5_to_ea
illegal_156:
	jmp      illegal

|###################################################
|# exg_A5_Ay                                       #
|###################################################
	.align	1
exg_A5_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_a5(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_a5(%a6)
	jmp      (%a3)

|###################################################
|# exg_D5_Dy                                       #
|###################################################
	.align	1
exg_D5_Dy:
	bsr      read_then_write_operand_long
	move.l   reg_d5(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d5(%a6)
	jmp      (%a3)
second_level_dispatch_813:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      exg_D5_Dy
	cmpi.l   #0x10,%d4
	bcs      exg_A5_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_word_D5_to_ea
illegal_157:
	jmp      illegal

|###################################################
|# and_word_D5_to_ea                               #
|###################################################
	.align	1
and_word_D5_to_ea:
	move.w   reg_d5+2(%a6),%d1
	bsr      read_then_write_operand_word
	and.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# exg_D5_Ay                                       #
|###################################################
	.align	1
exg_D5_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_d5(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d5(%a6)
	jmp      (%a3)
second_level_dispatch_814:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      illegal_158
	cmpi.l   #0x10,%d4
	bcs      exg_D5_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_long_D5_to_ea
illegal_158:
	jmp      illegal

|###################################################
|# and_long_D5_to_ea                               #
|###################################################
	.align	1
and_long_D5_to_ea:
	move.l   reg_d5(%a6),%d1
	bsr      read_then_write_operand_long
	and.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# and_byte_ea_to_D6                               #
|###################################################
	.align	1
and_byte_ea_to_D6:
	bsr      read_operand_byte
	move.b   reg_d6+3(%a6),%d1
	and.l    %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d6+3(%a6)
	jmp      exception_handled

|###################################################
|# and_word_ea_to_D6                               #
|###################################################
	.align	1
and_word_ea_to_D6:
	bsr      read_operand_word
	move.w   reg_d6+2(%a6),%d1
	and.l    %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d6+2(%a6)
	jmp      exception_handled

|###################################################
|# and_long_ea_to_D6                               #
|###################################################
	.align	1
and_long_ea_to_D6:
	bsr      read_operand_long
	move.l   reg_d6(%a6),%d1
	and.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d6(%a6)
	jmp      exception_handled

|###################################################
|# and_byte_D6_to_ea                               #
|###################################################
	.align	1
and_byte_D6_to_ea:
	move.b   reg_d6+3(%a6),%d1
	bsr      read_then_write_operand_byte
	and.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_820:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      abcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      abcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      and_byte_D6_to_ea
illegal_159:
	jmp      illegal

|###################################################
|# exg_A6_Ay                                       #
|###################################################
	.align	1
exg_A6_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_a6(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_a6(%a6)
	jmp      (%a3)

|###################################################
|# exg_D6_Dy                                       #
|###################################################
	.align	1
exg_D6_Dy:
	bsr      read_then_write_operand_long
	move.l   reg_d6(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d6(%a6)
	jmp      (%a3)
second_level_dispatch_821:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      exg_D6_Dy
	cmpi.l   #0x10,%d4
	bcs      exg_A6_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_word_D6_to_ea
illegal_160:
	jmp      illegal

|###################################################
|# and_word_D6_to_ea                               #
|###################################################
	.align	1
and_word_D6_to_ea:
	move.w   reg_d6+2(%a6),%d1
	bsr      read_then_write_operand_word
	and.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# exg_D6_Ay                                       #
|###################################################
	.align	1
exg_D6_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_d6(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d6(%a6)
	jmp      (%a3)
second_level_dispatch_822:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      illegal_161
	cmpi.l   #0x10,%d4
	bcs      exg_D6_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_long_D6_to_ea
illegal_161:
	jmp      illegal

|###################################################
|# and_long_D6_to_ea                               #
|###################################################
	.align	1
and_long_D6_to_ea:
	move.l   reg_d6(%a6),%d1
	bsr      read_then_write_operand_long
	and.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# and_byte_ea_to_D7                               #
|###################################################
	.align	1
and_byte_ea_to_D7:
	bsr      read_operand_byte
	move.b   reg_d7+3(%a6),%d1
	and.l    %d0,%d1
	tst.b    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.b   %d1,reg_d7+3(%a6)
	jmp      exception_handled

|###################################################
|# and_word_ea_to_D7                               #
|###################################################
	.align	1
and_word_ea_to_D7:
	bsr      read_operand_word
	move.w   reg_d7+2(%a6),%d1
	and.l    %d0,%d1
	tst.w    %d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.w   %d1,reg_d7+2(%a6)
	jmp      exception_handled

|###################################################
|# and_long_ea_to_D7                               #
|###################################################
	.align	1
and_long_ea_to_D7:
	bsr      read_operand_long
	move.l   reg_d7(%a6),%d1
	and.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	move.l   %d1,reg_d7(%a6)
	jmp      exception_handled

|###################################################
|# and_byte_D7_to_ea                               #
|###################################################
	.align	1
and_byte_D7_to_ea:
	move.b   reg_d7+3(%a6),%d1
	bsr      read_then_write_operand_byte
	and.l    %d1,%d0
	tst.b    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)
second_level_dispatch_828:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      abcd_DyDx
	cmpi.l   #0x10,%d4
	bcs      abcd_AyAx
	cmpi.l   #0x3a,%d4
	bcs      and_byte_D7_to_ea
illegal_162:
	jmp      illegal

|###################################################
|# exg_A7_Ay                                       #
|###################################################
	.align	1
exg_A7_Ay:
	bsr      read_then_write_operand_long
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %d1,reg_a7(%a6)
	jmp      (%a3)

|###################################################
|# exg_D7_Dy                                       #
|###################################################
	.align	1
exg_D7_Dy:
	bsr      read_then_write_operand_long
	move.l   reg_d7(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d7(%a6)
	jmp      (%a3)
second_level_dispatch_829:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      exg_D7_Dy
	cmpi.l   #0x10,%d4
	bcs      exg_A7_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_word_D7_to_ea
illegal_163:
	jmp      illegal

|###################################################
|# and_word_D7_to_ea                               #
|###################################################
	.align	1
and_word_D7_to_ea:
	move.w   reg_d7+2(%a6),%d1
	bsr      read_then_write_operand_word
	and.l    %d1,%d0
	tst.w    %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# exg_D7_Ay                                       #
|###################################################
	.align	1
exg_D7_Ay:
	bsr      read_then_write_operand_long
	move.l   reg_d7(%a6),%d1
	move     %ccr,%d3
	move.l   %d0,%d2
	move.l   %d1,%d0
	move.l   %d2,%d1
	move     %d3,%ccr
	moveq.l  #0x0,%d6
	move.l   %d1,reg_d7(%a6)
	jmp      (%a3)
second_level_dispatch_830:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      illegal_164
	cmpi.l   #0x10,%d4
	bcs      exg_D7_Ay
	cmpi.l   #0x3a,%d4
	bcs      and_long_D7_to_ea
illegal_164:
	jmp      illegal

|###################################################
|# and_long_D7_to_ea                               #
|###################################################
	.align	1
and_long_D7_to_ea:
	move.l   reg_d7(%a6),%d1
	bsr      read_then_write_operand_long
	and.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# add_byte_ea_to_D0                               #
|###################################################
	.align	1
add_byte_ea_to_D0:
	bsr      read_operand_byte
	move.b   reg_d0+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d0+3(%a6)
	jmp      exception_handled

|###################################################
|# add_word_ea_to_D0                               #
|###################################################
	.align	1
add_word_ea_to_D0:
	bsr      read_operand_word
	move.w   reg_d0+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d0+2(%a6)
	jmp      exception_handled

|###################################################
|# add_long_ea_to_D0                               #
|###################################################
	.align	1
add_long_ea_to_D0:
	bsr      read_operand_long
	move.l   reg_d0(%a6),%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d0(%a6)
	jmp      exception_handled

|###################################################
|# adda_word_ea_to_A0                              #
|###################################################
	.align	1
adda_word_ea_to_A0:
	bsr      read_operand_word
	move.l   reg_a0(%a6),%a2
	ext.l    %d0
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# addx_byte_predecrement                          #
|###################################################
	.align	1
addx_byte_predecrement:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_byte
	move.l   %d0,%d2
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d4
	lsl.l    %d4,%d2
	lsl.l    %d4,%d0
	move.b   reg_XNZVC(%a6),%d1
	btst     #4,%d1
	sne      %d3
	extb.l   %d3
	lsr.l    #8,%d3
	or.l     %d3,%d0
	move     %d1,%CCR
	addx.l   %d2,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d0
	jmp      (%a3)

|###################################################
|# addx_byte_ea_to_D0                              #
|###################################################
	.align	1
addx_byte_ea_to_D0:
	bsr      read_operand_byte
	move.b   reg_d0+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	lsr.l    #8,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d0+3(%a6)
	jmp      exception_handled
second_level_dispatch_836:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_byte_ea_to_D0
	cmpi.l   #0x10,%d4
	bcs      addx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_byte_D0_to_ea
illegal_165:
	jmp      illegal

|###################################################
|# add_byte_D0_to_ea                               #
|###################################################
	.align	1
add_byte_D0_to_ea:
	move.b   reg_d0+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_word_predecrement                          #
|###################################################
	.align	1
addx_word_predecrement:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_word
	move.l   %d0,%d2
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_word
	moveq.l  #16,%d4
	lsl.l    %d4,%d2
	lsl.l    %d4,%d0
	move.b   reg_XNZVC(%a6),%d1
	btst     #4,%d1
	sne      %d3
	extb.l   %d3
	and.l    #0xffff,%d3
	or.l     %d3,%d0
	move     %d1,%CCR
	addx.l   %d2,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d0
	jmp      (%a3)

|###################################################
|# addx_word_ea_to_D0                              #
|###################################################
	.align	1
addx_word_ea_to_D0:
	bsr      read_operand_word
	move.w   reg_d0+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	and.l    #0xffff,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d0+2(%a6)
	jmp      exception_handled
second_level_dispatch_837:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_word_ea_to_D0
	cmpi.l   #0x10,%d4
	bcs      addx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_word_D0_to_ea
illegal_166:
	jmp      illegal

|###################################################
|# add_word_D0_to_ea                               #
|###################################################
	.align	1
add_word_D0_to_ea:
	move.w   reg_d0+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_long_predecrement                          #
|###################################################
	.align	1
addx_long_predecrement:
	move.l   %d5,%d1
	and.l    #7,%d5
	ori.l    #0x20,%d5
	bsr      read_operand_long
	move.l   %d0,%d2
	move.l   %d1,%d5
	lsr.l    #8,%d5
	lsr.l    #1,%d5
	and.l    #7,%d5
	ori.l    #0x20,%d5
	subq.l   #2,%a0
	bsr      read_then_write_operand_long
	move.b   reg_XNZVC(%a6),%d1
	move     %d1,%ccr
	addx.l   %d2,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# addx_long_ea_to_D0                              #
|###################################################
	.align	1
addx_long_ea_to_D0:
	bsr      read_operand_long
	move.l   reg_d0(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d0(%a6)
	jmp      exception_handled
second_level_dispatch_838:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_long_ea_to_D0
	cmpi.l   #0x10,%d4
	bcs      addx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_long_D0_to_ea
illegal_167:
	jmp      illegal

|###################################################
|# add_long_D0_to_ea                               #
|###################################################
	.align	1
add_long_D0_to_ea:
	move.l   reg_d0(%a6),%d1
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# adda_long_ea_to_A0                              #
|###################################################
	.align	1
adda_long_ea_to_A0:
	bsr      read_operand_long
	move.l   reg_a0(%a6),%a2
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a0(%a6)
	jmp      exception_handled

|###################################################
|# add_byte_ea_to_D1                               #
|###################################################
	.align	1
add_byte_ea_to_D1:
	bsr      read_operand_byte
	move.b   reg_d1+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d1+3(%a6)
	jmp      exception_handled

|###################################################
|# add_word_ea_to_D1                               #
|###################################################
	.align	1
add_word_ea_to_D1:
	bsr      read_operand_word
	move.w   reg_d1+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d1+2(%a6)
	jmp      exception_handled

|###################################################
|# add_long_ea_to_D1                               #
|###################################################
	.align	1
add_long_ea_to_D1:
	bsr      read_operand_long
	move.l   reg_d1(%a6),%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d1(%a6)
	jmp      exception_handled

|###################################################
|# adda_word_ea_to_A1                              #
|###################################################
	.align	1
adda_word_ea_to_A1:
	bsr      read_operand_word
	move.l   reg_a1(%a6),%a2
	ext.l    %d0
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# addx_byte_ea_to_D1                              #
|###################################################
	.align	1
addx_byte_ea_to_D1:
	bsr      read_operand_byte
	move.b   reg_d1+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	lsr.l    #8,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d1+3(%a6)
	jmp      exception_handled
second_level_dispatch_844:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_byte_ea_to_D1
	cmpi.l   #0x10,%d4
	bcs      addx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_byte_D1_to_ea
illegal_168:
	jmp      illegal

|###################################################
|# add_byte_D1_to_ea                               #
|###################################################
	.align	1
add_byte_D1_to_ea:
	move.b   reg_d1+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_word_ea_to_D1                              #
|###################################################
	.align	1
addx_word_ea_to_D1:
	bsr      read_operand_word
	move.w   reg_d1+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	and.l    #0xffff,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d1+2(%a6)
	jmp      exception_handled
second_level_dispatch_845:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_word_ea_to_D1
	cmpi.l   #0x10,%d4
	bcs      addx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_word_D1_to_ea
illegal_169:
	jmp      illegal

|###################################################
|# add_word_D1_to_ea                               #
|###################################################
	.align	1
add_word_D1_to_ea:
	move.w   reg_d1+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_long_ea_to_D1                              #
|###################################################
	.align	1
addx_long_ea_to_D1:
	bsr      read_operand_long
	move.l   reg_d1(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d1(%a6)
	jmp      exception_handled
second_level_dispatch_846:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_long_ea_to_D1
	cmpi.l   #0x10,%d4
	bcs      addx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_long_D1_to_ea
illegal_170:
	jmp      illegal

|###################################################
|# add_long_D1_to_ea                               #
|###################################################
	.align	1
add_long_D1_to_ea:
	move.l   reg_d1(%a6),%d1
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# adda_long_ea_to_A1                              #
|###################################################
	.align	1
adda_long_ea_to_A1:
	bsr      read_operand_long
	move.l   reg_a1(%a6),%a2
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a1(%a6)
	jmp      exception_handled

|###################################################
|# add_byte_ea_to_D2                               #
|###################################################
	.align	1
add_byte_ea_to_D2:
	bsr      read_operand_byte
	move.b   reg_d2+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d2+3(%a6)
	jmp      exception_handled

|###################################################
|# add_word_ea_to_D2                               #
|###################################################
	.align	1
add_word_ea_to_D2:
	bsr      read_operand_word
	move.w   reg_d2+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d2+2(%a6)
	jmp      exception_handled

|###################################################
|# add_long_ea_to_D2                               #
|###################################################
	.align	1
add_long_ea_to_D2:
	bsr      read_operand_long
	move.l   reg_d2(%a6),%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d2(%a6)
	jmp      exception_handled

|###################################################
|# adda_word_ea_to_A2                              #
|###################################################
	.align	1
adda_word_ea_to_A2:
	bsr      read_operand_word
	move.l   reg_a2(%a6),%a2
	ext.l    %d0
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# addx_byte_ea_to_D2                              #
|###################################################
	.align	1
addx_byte_ea_to_D2:
	bsr      read_operand_byte
	move.b   reg_d2+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	lsr.l    #8,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d2+3(%a6)
	jmp      exception_handled
second_level_dispatch_852:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_byte_ea_to_D2
	cmpi.l   #0x10,%d4
	bcs      addx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_byte_D2_to_ea
illegal_171:
	jmp      illegal

|###################################################
|# add_byte_D2_to_ea                               #
|###################################################
	.align	1
add_byte_D2_to_ea:
	move.b   reg_d2+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_word_ea_to_D2                              #
|###################################################
	.align	1
addx_word_ea_to_D2:
	bsr      read_operand_word
	move.w   reg_d2+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	and.l    #0xffff,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d2+2(%a6)
	jmp      exception_handled
second_level_dispatch_853:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_word_ea_to_D2
	cmpi.l   #0x10,%d4
	bcs      addx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_word_D2_to_ea
illegal_172:
	jmp      illegal

|###################################################
|# add_word_D2_to_ea                               #
|###################################################
	.align	1
add_word_D2_to_ea:
	move.w   reg_d2+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_long_ea_to_D2                              #
|###################################################
	.align	1
addx_long_ea_to_D2:
	bsr      read_operand_long
	move.l   reg_d2(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d2(%a6)
	jmp      exception_handled
second_level_dispatch_854:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_long_ea_to_D2
	cmpi.l   #0x10,%d4
	bcs      addx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_long_D2_to_ea
illegal_173:
	jmp      illegal

|###################################################
|# add_long_D2_to_ea                               #
|###################################################
	.align	1
add_long_D2_to_ea:
	move.l   reg_d2(%a6),%d1
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# adda_long_ea_to_A2                              #
|###################################################
	.align	1
adda_long_ea_to_A2:
	bsr      read_operand_long
	move.l   reg_a2(%a6),%a2
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a2(%a6)
	jmp      exception_handled

|###################################################
|# add_byte_ea_to_D3                               #
|###################################################
	.align	1
add_byte_ea_to_D3:
	bsr      read_operand_byte
	move.b   reg_d3+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d3+3(%a6)
	jmp      exception_handled

|###################################################
|# add_word_ea_to_D3                               #
|###################################################
	.align	1
add_word_ea_to_D3:
	bsr      read_operand_word
	move.w   reg_d3+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d3+2(%a6)
	jmp      exception_handled

|###################################################
|# add_long_ea_to_D3                               #
|###################################################
	.align	1
add_long_ea_to_D3:
	bsr      read_operand_long
	move.l   reg_d3(%a6),%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d3(%a6)
	jmp      exception_handled

|###################################################
|# adda_word_ea_to_A3                              #
|###################################################
	.align	1
adda_word_ea_to_A3:
	bsr      read_operand_word
	move.l   reg_a3(%a6),%a2
	ext.l    %d0
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# addx_byte_ea_to_D3                              #
|###################################################
	.align	1
addx_byte_ea_to_D3:
	bsr      read_operand_byte
	move.b   reg_d3+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	lsr.l    #8,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d3+3(%a6)
	jmp      exception_handled
second_level_dispatch_860:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_byte_ea_to_D3
	cmpi.l   #0x10,%d4
	bcs      addx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_byte_D3_to_ea
illegal_174:
	jmp      illegal

|###################################################
|# add_byte_D3_to_ea                               #
|###################################################
	.align	1
add_byte_D3_to_ea:
	move.b   reg_d3+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_word_ea_to_D3                              #
|###################################################
	.align	1
addx_word_ea_to_D3:
	bsr      read_operand_word
	move.w   reg_d3+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	and.l    #0xffff,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d3+2(%a6)
	jmp      exception_handled
second_level_dispatch_861:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_word_ea_to_D3
	cmpi.l   #0x10,%d4
	bcs      addx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_word_D3_to_ea
illegal_175:
	jmp      illegal

|###################################################
|# add_word_D3_to_ea                               #
|###################################################
	.align	1
add_word_D3_to_ea:
	move.w   reg_d3+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_long_ea_to_D3                              #
|###################################################
	.align	1
addx_long_ea_to_D3:
	bsr      read_operand_long
	move.l   reg_d3(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d3(%a6)
	jmp      exception_handled
second_level_dispatch_862:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_long_ea_to_D3
	cmpi.l   #0x10,%d4
	bcs      addx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_long_D3_to_ea
illegal_176:
	jmp      illegal

|###################################################
|# add_long_D3_to_ea                               #
|###################################################
	.align	1
add_long_D3_to_ea:
	move.l   reg_d3(%a6),%d1
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# adda_long_ea_to_A3                              #
|###################################################
	.align	1
adda_long_ea_to_A3:
	bsr      read_operand_long
	move.l   reg_a3(%a6),%a2
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a3(%a6)
	jmp      exception_handled

|###################################################
|# add_byte_ea_to_D4                               #
|###################################################
	.align	1
add_byte_ea_to_D4:
	bsr      read_operand_byte
	move.b   reg_d4+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d4+3(%a6)
	jmp      exception_handled

|###################################################
|# add_word_ea_to_D4                               #
|###################################################
	.align	1
add_word_ea_to_D4:
	bsr      read_operand_word
	move.w   reg_d4+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d4+2(%a6)
	jmp      exception_handled

|###################################################
|# add_long_ea_to_D4                               #
|###################################################
	.align	1
add_long_ea_to_D4:
	bsr      read_operand_long
	move.l   reg_d4(%a6),%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d4(%a6)
	jmp      exception_handled

|###################################################
|# adda_word_ea_to_A4                              #
|###################################################
	.align	1
adda_word_ea_to_A4:
	bsr      read_operand_word
	move.l   reg_a4(%a6),%a2
	ext.l    %d0
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# addx_byte_ea_to_D4                              #
|###################################################
	.align	1
addx_byte_ea_to_D4:
	bsr      read_operand_byte
	move.b   reg_d4+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	lsr.l    #8,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d4+3(%a6)
	jmp      exception_handled
second_level_dispatch_868:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_byte_ea_to_D4
	cmpi.l   #0x10,%d4
	bcs      addx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_byte_D4_to_ea
illegal_177:
	jmp      illegal

|###################################################
|# add_byte_D4_to_ea                               #
|###################################################
	.align	1
add_byte_D4_to_ea:
	move.b   reg_d4+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_word_ea_to_D4                              #
|###################################################
	.align	1
addx_word_ea_to_D4:
	bsr      read_operand_word
	move.w   reg_d4+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	and.l    #0xffff,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d4+2(%a6)
	jmp      exception_handled
second_level_dispatch_869:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_word_ea_to_D4
	cmpi.l   #0x10,%d4
	bcs      addx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_word_D4_to_ea
illegal_178:
	jmp      illegal

|###################################################
|# add_word_D4_to_ea                               #
|###################################################
	.align	1
add_word_D4_to_ea:
	move.w   reg_d4+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_long_ea_to_D4                              #
|###################################################
	.align	1
addx_long_ea_to_D4:
	bsr      read_operand_long
	move.l   reg_d4(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d4(%a6)
	jmp      exception_handled
second_level_dispatch_870:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_long_ea_to_D4
	cmpi.l   #0x10,%d4
	bcs      addx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_long_D4_to_ea
illegal_179:
	jmp      illegal

|###################################################
|# add_long_D4_to_ea                               #
|###################################################
	.align	1
add_long_D4_to_ea:
	move.l   reg_d4(%a6),%d1
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# adda_long_ea_to_A4                              #
|###################################################
	.align	1
adda_long_ea_to_A4:
	bsr      read_operand_long
	move.l   reg_a4(%a6),%a2
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a4(%a6)
	jmp      exception_handled

|###################################################
|# add_byte_ea_to_D5                               #
|###################################################
	.align	1
add_byte_ea_to_D5:
	bsr      read_operand_byte
	move.b   reg_d5+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d5+3(%a6)
	jmp      exception_handled

|###################################################
|# add_word_ea_to_D5                               #
|###################################################
	.align	1
add_word_ea_to_D5:
	bsr      read_operand_word
	move.w   reg_d5+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d5+2(%a6)
	jmp      exception_handled

|###################################################
|# add_long_ea_to_D5                               #
|###################################################
	.align	1
add_long_ea_to_D5:
	bsr      read_operand_long
	move.l   reg_d5(%a6),%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d5(%a6)
	jmp      exception_handled

|###################################################
|# adda_word_ea_to_A5                              #
|###################################################
	.align	1
adda_word_ea_to_A5:
	bsr      read_operand_word
	move.l   reg_a5(%a6),%a2
	ext.l    %d0
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# addx_byte_ea_to_D5                              #
|###################################################
	.align	1
addx_byte_ea_to_D5:
	bsr      read_operand_byte
	move.b   reg_d5+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	lsr.l    #8,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d5+3(%a6)
	jmp      exception_handled
second_level_dispatch_876:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_byte_ea_to_D5
	cmpi.l   #0x10,%d4
	bcs      addx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_byte_D5_to_ea
illegal_180:
	jmp      illegal

|###################################################
|# add_byte_D5_to_ea                               #
|###################################################
	.align	1
add_byte_D5_to_ea:
	move.b   reg_d5+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_word_ea_to_D5                              #
|###################################################
	.align	1
addx_word_ea_to_D5:
	bsr      read_operand_word
	move.w   reg_d5+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	and.l    #0xffff,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d5+2(%a6)
	jmp      exception_handled
second_level_dispatch_877:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_word_ea_to_D5
	cmpi.l   #0x10,%d4
	bcs      addx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_word_D5_to_ea
illegal_181:
	jmp      illegal

|###################################################
|# add_word_D5_to_ea                               #
|###################################################
	.align	1
add_word_D5_to_ea:
	move.w   reg_d5+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_long_ea_to_D5                              #
|###################################################
	.align	1
addx_long_ea_to_D5:
	bsr      read_operand_long
	move.l   reg_d5(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d5(%a6)
	jmp      exception_handled
second_level_dispatch_878:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_long_ea_to_D5
	cmpi.l   #0x10,%d4
	bcs      addx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_long_D5_to_ea
illegal_182:
	jmp      illegal

|###################################################
|# add_long_D5_to_ea                               #
|###################################################
	.align	1
add_long_D5_to_ea:
	move.l   reg_d5(%a6),%d1
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# adda_long_ea_to_A5                              #
|###################################################
	.align	1
adda_long_ea_to_A5:
	bsr      read_operand_long
	move.l   reg_a5(%a6),%a2
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a5(%a6)
	jmp      exception_handled

|###################################################
|# add_byte_ea_to_D6                               #
|###################################################
	.align	1
add_byte_ea_to_D6:
	bsr      read_operand_byte
	move.b   reg_d6+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d6+3(%a6)
	jmp      exception_handled

|###################################################
|# add_word_ea_to_D6                               #
|###################################################
	.align	1
add_word_ea_to_D6:
	bsr      read_operand_word
	move.w   reg_d6+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d6+2(%a6)
	jmp      exception_handled

|###################################################
|# add_long_ea_to_D6                               #
|###################################################
	.align	1
add_long_ea_to_D6:
	bsr      read_operand_long
	move.l   reg_d6(%a6),%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d6(%a6)
	jmp      exception_handled

|###################################################
|# adda_word_ea_to_A6                              #
|###################################################
	.align	1
adda_word_ea_to_A6:
	bsr      read_operand_word
	move.l   reg_a6(%a6),%a2
	ext.l    %d0
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# addx_byte_ea_to_D6                              #
|###################################################
	.align	1
addx_byte_ea_to_D6:
	bsr      read_operand_byte
	move.b   reg_d6+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	lsr.l    #8,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d6+3(%a6)
	jmp      exception_handled
second_level_dispatch_884:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_byte_ea_to_D6
	cmpi.l   #0x10,%d4
	bcs      addx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_byte_D6_to_ea
illegal_183:
	jmp      illegal

|###################################################
|# add_byte_D6_to_ea                               #
|###################################################
	.align	1
add_byte_D6_to_ea:
	move.b   reg_d6+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_word_ea_to_D6                              #
|###################################################
	.align	1
addx_word_ea_to_D6:
	bsr      read_operand_word
	move.w   reg_d6+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	and.l    #0xffff,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d6+2(%a6)
	jmp      exception_handled
second_level_dispatch_885:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_word_ea_to_D6
	cmpi.l   #0x10,%d4
	bcs      addx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_word_D6_to_ea
illegal_184:
	jmp      illegal

|###################################################
|# add_word_D6_to_ea                               #
|###################################################
	.align	1
add_word_D6_to_ea:
	move.w   reg_d6+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_long_ea_to_D6                              #
|###################################################
	.align	1
addx_long_ea_to_D6:
	bsr      read_operand_long
	move.l   reg_d6(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d6(%a6)
	jmp      exception_handled
second_level_dispatch_886:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_long_ea_to_D6
	cmpi.l   #0x10,%d4
	bcs      addx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_long_D6_to_ea
illegal_185:
	jmp      illegal

|###################################################
|# add_long_D6_to_ea                               #
|###################################################
	.align	1
add_long_D6_to_ea:
	move.l   reg_d6(%a6),%d1
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# adda_long_ea_to_A6                              #
|###################################################
	.align	1
adda_long_ea_to_A6:
	bsr      read_operand_long
	move.l   reg_a6(%a6),%a2
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	move.l   %a2,reg_a6(%a6)
	jmp      exception_handled

|###################################################
|# add_byte_ea_to_D7                               #
|###################################################
	.align	1
add_byte_ea_to_D7:
	bsr      read_operand_byte
	move.b   reg_d7+3(%a6),%d1
	moveq.l  #24,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.b   %d1,reg_d7+3(%a6)
	jmp      exception_handled

|###################################################
|# add_word_ea_to_D7                               #
|###################################################
	.align	1
add_word_ea_to_D7:
	bsr      read_operand_word
	move.w   reg_d7+2(%a6),%d1
	moveq.l  #16,%d2
	lsl.l    %d2,%d0
	lsl.l    %d2,%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d1
	move.w   %d1,reg_d7+2(%a6)
	jmp      exception_handled

|###################################################
|# add_long_ea_to_D7                               #
|###################################################
	.align	1
add_long_ea_to_D7:
	bsr      read_operand_long
	move.l   reg_d7(%a6),%d1
	add.l    %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d7(%a6)
	jmp      exception_handled

|###################################################
|# adda_word_ea_to_A7                              #
|###################################################
	.align	1
adda_word_ea_to_A7:
	bsr      read_operand_word
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	ext.l    %d0
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# addx_byte_ea_to_D7                              #
|###################################################
	.align	1
addx_byte_ea_to_D7:
	bsr      read_operand_byte
	move.b   reg_d7+3(%a6),%d1
	moveq.l  #24,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	lsr.l    #8,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.b   %d1,reg_d7+3(%a6)
	jmp      exception_handled
second_level_dispatch_892:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_byte_ea_to_D7
	cmpi.l   #0x10,%d4
	bcs      addx_byte_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_byte_D7_to_ea
illegal_186:
	jmp      illegal

|###################################################
|# add_byte_D7_to_ea                               #
|###################################################
	.align	1
add_byte_D7_to_ea:
	move.b   reg_d7+3(%a6),%d1
	bsr      read_then_write_operand_byte
	moveq.l  #24,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_word_ea_to_D7                              #
|###################################################
	.align	1
addx_word_ea_to_D7:
	bsr      read_operand_word
	move.w   reg_d7+2(%a6),%d1
	moveq.l  #16,%d4
	lsl.l    %d4,%d0
	lsl.l    %d4,%d1
	move.b   reg_XNZVC(%a6),%d2
	btst     #4,%d2
	sne      %d3
	extb.l   %d3
	and.l    #0xffff,%d3
	or.l     %d3,%d1
	move     %d2,%CCR
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d4,%d1
	move.w   %d1,reg_d7+2(%a6)
	jmp      exception_handled
second_level_dispatch_893:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_word_ea_to_D7
	cmpi.l   #0x10,%d4
	bcs      addx_word_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_word_D7_to_ea
illegal_187:
	jmp      illegal

|###################################################
|# add_word_D7_to_ea                               #
|###################################################
	.align	1
add_word_D7_to_ea:
	move.w   reg_d7+2(%a6),%d1
	bsr      read_then_write_operand_word
	moveq.l  #16,%d2
	lsl.l    %d2,%d1
	lsl.l    %d2,%d0
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	lsr.l    %d2,%d0
	jmp      (%a3)

|###################################################
|# addx_long_ea_to_D7                              #
|###################################################
	.align	1
addx_long_ea_to_D7:
	bsr      read_operand_long
	move.l   reg_d7(%a6),%d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	addx.l   %d0,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,reg_d7(%a6)
	jmp      exception_handled
second_level_dispatch_894:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      addx_long_ea_to_D7
	cmpi.l   #0x10,%d4
	bcs      addx_long_predecrement
	cmpi.l   #0x3a,%d4
	bcs      add_long_D7_to_ea
illegal_188:
	jmp      illegal

|###################################################
|# add_long_D7_to_ea                               #
|###################################################
	.align	1
add_long_D7_to_ea:
	move.l   reg_d7(%a6),%d1
	bsr      read_then_write_operand_long
	add.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# adda_long_ea_to_A7                              #
|###################################################
	.align	1
adda_long_ea_to_A7:
	bsr      read_operand_long
	jsr      compute_reg_a7
	move.l   reg_a7(%a6),%a2
	adda.l   %d0,%a2
	moveq.l  #0x0,%d6
	bset     #0,reg_a7_changed(%a6)
	move.l   %a2,reg_a7(%a6)
	jmp      exception_handled

|###################################################
|# shift_and_rotate_right_byte_0                   #
|###################################################
	.align	1
shift_and_rotate_right_byte_0:
	moveq.l  #8,%d1
	move.l   reg_d0(%a6),%d0
shift_and_rotate_right_byte_common:
	btst     #5,%d5
	beq      shift_and_rotate_right_byte_dispatch
	move.l   %d0,%d1
	and.l    #63,%d1
shift_and_rotate_right_byte_dispatch:
	tst.l    %d1
	beq      shift_or_rotate_byte_with_zero_count
	btst     #4,%d5
	bne      rotate_right_byte_dispatch
	btst     #3,%d5
	beq      asr_byte_reg
	bra      lsr_byte_reg
rotate_right_byte_dispatch:
	btst     #3,%d5
	beq      roxr_byte_reg
	bra      ror_byte_reg

|###################################################
|# shift_and_rotate_right_word_0                   #
|###################################################
	.align	1
shift_and_rotate_right_word_0:
	moveq.l  #8,%d1
	move.l   reg_d0(%a6),%d0
shift_and_rotate_right_word_common:
	btst     #5,%d5
	beq      shift_and_rotate_right_word_dispatch
	move.l   %d0,%d1
	and.l    #63,%d1
shift_and_rotate_right_word_dispatch:
	tst.l    %d1
	beq      shift_or_rotate_word_with_zero_count
	btst     #4,%d5
	bne      rotate_right_word_dispatch
	btst     #3,%d5
	beq      asr_word_reg
	bra      lsr_word_reg
rotate_right_word_dispatch:
	btst     #3,%d5
	beq      roxr_word_reg
	bra      ror_word_reg

|###################################################
|# shift_and_rotate_right_long_0                   #
|###################################################
	.align	1
shift_and_rotate_right_long_0:
	moveq.l  #8,%d1
	move.l   reg_d0(%a6),%d0
shift_and_rotate_right_long_common:
	btst     #5,%d5
	beq      shift_and_rotate_right_long_dispatch
	move.l   %d0,%d1
	and.l    #63,%d1
shift_and_rotate_right_long_dispatch:
	tst.l    %d1
	beq      shift_or_rotate_long_with_zero_count
	btst     #4,%d5
	bne      rotate_right_long_dispatch
	btst     #3,%d5
	beq      asr_long_reg
	bra      lsr_long_reg
rotate_right_long_dispatch:
	btst     #3,%d5
	beq      roxr_long_reg
	bra      ror_long_reg

|###################################################
|# asr_memory                                      #
|###################################################
	.align	1
asr_memory:
	bsr      read_then_write_operand_word
	ext.l    %d0
	asr.l    #1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# shift_and_rotate_left_byte_0                    #
|###################################################
	.align	1
shift_and_rotate_left_byte_0:
	moveq.l  #8,%d1
	move.l   reg_d0(%a6),%d0
shift_and_rotate_left_byte_common:
	btst     #5,%d5
	beq      shift_and_rotate_left_byte_dispatch
	move.l   %d0,%d1
	and.l    #63,%d1
shift_and_rotate_left_byte_dispatch:
	tst.l    %d1
	beq      shift_or_rotate_byte_with_zero_count
	btst     #4,%d5
	bne      rotate_left_byte_dispatch
	btst     #3,%d5
	beq      asl_byte_reg
	bra      lsl_byte_reg
rotate_left_byte_dispatch:
	btst     #3,%d5
	beq      roxl_byte_reg
	bra      rol_byte_reg
	
shift_or_rotate_byte_with_zero_count:
	move.l   %d5,%d1
	and.l    #7,%d5
	bsr      read_operand_byte
	tst.b    %d0
shift_or_rotate_with_zero_common:
	move     %ccr,%d7
	moveq.l  #0x0f,%d6
	and.l    #0x18,%d1
	cmpi.l   #0x10,%d1
	bne      shift_or_rotate_exception_handled
	btst     #4,reg_XNZVC(%a6)
	beq      shift_or_rotate_exception_handled
	bset     #0,%d7
shift_or_rotate_exception_handled:
	jmp      exception_handled

|###################################################
|# shift_and_rotate_left_word_0                    #
|###################################################
	.align	1
shift_and_rotate_left_word_0:
	moveq.l  #8,%d1
	move.l   reg_d0(%a6),%d0
shift_and_rotate_left_word_common:
	btst     #5,%d5
	beq      shift_and_rotate_left_word_dispatch
	move.l   %d0,%d1
	and.l    #63,%d1
shift_and_rotate_left_word_dispatch:
	tst.l    %d1
	beq      shift_or_rotate_word_with_zero_count
	btst     #4,%d5
	bne      rotate_left_word_dispatch
	btst     #3,%d5
	beq      asl_word_reg
	bra      lsl_word_reg
rotate_left_word_dispatch:
	btst     #3,%d5
	beq      roxl_word_reg
	bra      rol_word_reg
	
shift_or_rotate_word_with_zero_count:
	move.l   %d5,%d1
	and.l    #7,%d5
	bsr      read_operand_word
	tst.w    %d0
	bra      shift_or_rotate_with_zero_common

|###################################################
|# shift_and_rotate_left_long_0                    #
|###################################################
	.align	1
shift_and_rotate_left_long_0:
	moveq.l  #8,%d1
	move.l   reg_d0(%a6),%d0
shift_and_rotate_left_long_common:
	btst     #5,%d5
	beq      shift_and_rotate_left_long_dispatch
	move.l   %d0,%d1
	and.l    #63,%d1
shift_and_rotate_left_long_dispatch:
	tst.l    %d1
	beq      shift_or_rotate_long_with_zero_count
	btst     #4,%d5
	bne      rotate_left_long_dispatch
	btst     #3,%d5
	beq      asl_long_reg
	bra      lsl_long_reg
rotate_left_long_dispatch:
	btst     #3,%d5
	beq      roxl_long_reg
	bra      rol_long_reg
	
shift_or_rotate_long_with_zero_count:
	move.l   %d5,%d1
	and.l    #7,%d5
	bsr      read_operand_long
	tst.l    %d0
	bra      shift_or_rotate_with_zero_common

|###################################################
|# asl_memory                                      #
|###################################################
	.align	1
asl_memory:
	bsr      read_then_write_operand_word
	move.l   %d0,%d1
	move.l   %d0,%d2
	swap     %d1
	asl.l    #1,%d0
	asl.l    #1,%d1
	move     %ccr,%d3
	eor.l    %d0,%d2
	lsr.l    #8,%d2
	lsr.l    #6,%d2
	and.l    #2,%d2
	or.l     %d2,%d3
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# shift_and_rotate_right_byte_1                   #
|###################################################
	.align	1
shift_and_rotate_right_byte_1:
	moveq.l  #1,%d1
	move.l   reg_d1(%a6),%d0
	bra      shift_and_rotate_right_byte_common

|###################################################
|# shift_and_rotate_right_word_1                   #
|###################################################
	.align	1
shift_and_rotate_right_word_1:
	moveq.l  #1,%d1
	move.l   reg_d1(%a6),%d0
	bra      shift_and_rotate_right_word_common

|###################################################
|# shift_and_rotate_right_long_1                   #
|###################################################
	.align	1
shift_and_rotate_right_long_1:
	moveq.l  #1,%d1
	move.l   reg_d1(%a6),%d0
	bra      shift_and_rotate_right_long_common

|###################################################
|# lsr_memory                                      #
|###################################################
	.align	1
lsr_memory:
	bsr      read_then_write_operand_word
	and.l    #0x0000ffff,%d0
	lsr.l    #1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# shift_and_rotate_left_byte_1                    #
|###################################################
	.align	1
shift_and_rotate_left_byte_1:
	moveq.l  #1,%d1
	move.l   reg_d1(%a6),%d0
	bra      shift_and_rotate_left_byte_common

|###################################################
|# shift_and_rotate_left_word_1                    #
|###################################################
	.align	1
shift_and_rotate_left_word_1:
	moveq.l  #1,%d1
	move.l   reg_d1(%a6),%d0
	bra      shift_and_rotate_left_word_common

|###################################################
|# shift_and_rotate_left_long_1                    #
|###################################################
	.align	1
shift_and_rotate_left_long_1:
	moveq.l  #1,%d1
	move.l   reg_d1(%a6),%d0
	bra      shift_and_rotate_left_long_common

|###################################################
|# lsl_memory                                      #
|###################################################
	.align	1
lsl_memory:
	bsr      read_then_write_operand_word
	move.l   %d0,%d1
	swap     %d1
	lsl.l    #1,%d0
	lsl.l    #1,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# shift_and_rotate_right_byte_2                   #
|###################################################
	.align	1
shift_and_rotate_right_byte_2:
	moveq.l  #2,%d1
	move.l   reg_d2(%a6),%d0
	bra      shift_and_rotate_right_byte_common

|###################################################
|# shift_and_rotate_right_word_2                   #
|###################################################
	.align	1
shift_and_rotate_right_word_2:
	moveq.l  #2,%d1
	move.l   reg_d2(%a6),%d0
	bra      shift_and_rotate_right_word_common

|###################################################
|# shift_and_rotate_right_long_2                   #
|###################################################
	.align	1
shift_and_rotate_right_long_2:
	moveq.l  #2,%d1
	move.l   reg_d2(%a6),%d0
	bra      shift_and_rotate_right_long_common

|###################################################
|# roxr_memory                                     #
|###################################################
	.align	1
roxr_memory:
	bsr      read_then_write_operand_word
	clr.l    %d1
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	subx.l   %d1,%d1
	move.w   %d0,%d1
	move.l   %d1,%d0
	asr.l    #1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# shift_and_rotate_left_byte_2                    #
|###################################################
	.align	1
shift_and_rotate_left_byte_2:
	moveq.l  #2,%d1
	move.l   reg_d2(%a6),%d0
	bra      shift_and_rotate_left_byte_common

|###################################################
|# shift_and_rotate_left_word_2                    #
|###################################################
	.align	1
shift_and_rotate_left_word_2:
	moveq.l  #2,%d1
	move.l   reg_d2(%a6),%d0
	bra      shift_and_rotate_left_word_common

|###################################################
|# shift_and_rotate_left_long_2                    #
|###################################################
	.align	1
shift_and_rotate_left_long_2:
	moveq.l  #2,%d1
	move.l   reg_d2(%a6),%d0
	bra      shift_and_rotate_left_long_common

|###################################################
|# roxl_memory                                     #
|###################################################
	.align	1
roxl_memory:
	bsr      read_then_write_operand_word
	moveq    #16,%d2
	move.b   reg_XNZVC(%a6),%d3
	move     %d3,%ccr
	addx.l   %d0,%d0
	move.l   %d0,%d1
	lsl.l    %d2,%d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# shift_and_rotate_right_byte_3                   #
|###################################################
	.align	1
shift_and_rotate_right_byte_3:
	moveq.l  #3,%d1
	move.l   reg_d3(%a6),%d0
	bra      shift_and_rotate_right_byte_common

|###################################################
|# shift_and_rotate_right_word_3                   #
|###################################################
	.align	1
shift_and_rotate_right_word_3:
	moveq.l  #3,%d1
	move.l   reg_d3(%a6),%d0
	bra      shift_and_rotate_right_word_common

|###################################################
|# shift_and_rotate_right_long_3                   #
|###################################################
	.align	1
shift_and_rotate_right_long_3:
	moveq.l  #3,%d1
	move.l   reg_d3(%a6),%d0
	bra      shift_and_rotate_right_long_common

|###################################################
|# ror_memory                                      #
|###################################################
	.align	1
ror_memory:
	bsr      read_then_write_operand_word
	move.w   %d0,%d1
	move     %ccr,%d2
	swap     %d0
	move.w   %d1,%d0
	lsr.l    #1,%d0
	clr.l    %d1
	addx.l   %d1,%d2
	tst.w    %d0
	move     %ccr,%d1
	andi.l   #0x1001,%d2
	or.l     %d2,%d1
	lsr.l    #8,%d2
	or.l     %d2,%d1
	move     %d1,%ccr
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# shift_and_rotate_left_byte_3                    #
|###################################################
	.align	1
shift_and_rotate_left_byte_3:
	moveq.l  #3,%d1
	move.l   reg_d3(%a6),%d0
	bra      shift_and_rotate_left_byte_common

|###################################################
|# shift_and_rotate_left_word_3                    #
|###################################################
	.align	1
shift_and_rotate_left_word_3:
	moveq.l  #3,%d1
	move.l   reg_d3(%a6),%d0
	bra      shift_and_rotate_left_word_common

|###################################################
|# shift_and_rotate_left_long_3                    #
|###################################################
	.align	1
shift_and_rotate_left_long_3:
	moveq.l  #3,%d1
	move.l   reg_d3(%a6),%d0
	bra      shift_and_rotate_left_long_common

|###################################################
|# rol_memory                                      #
|###################################################
	.align	1
rol_memory:
	bsr      read_then_write_operand_word
	moveq    #24,%d2
	move     %ccr,%d2
	move.w   %d0,%d1
	swap     %d0
	move.w   %d1,%d0
	lsr.l    #8,%d0
	lsr.l    #7,%d0
	move.l   %d0,%d1
	lsl.l    %d2,%d1
	move     %ccr,%d1
	andi.l   #0xF,%d1
	andi.l   #0x1000,%d2
	lsr.l    #8,%d2
	or.l     %d2,%d1
	move     %d1,%ccr
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# shift_and_rotate_right_byte_4                   #
|###################################################
	.align	1
shift_and_rotate_right_byte_4:
	moveq.l  #4,%d1
	move.l   reg_d4(%a6),%d0
	bra      shift_and_rotate_right_byte_common

|###################################################
|# shift_and_rotate_right_word_4                   #
|###################################################
	.align	1
shift_and_rotate_right_word_4:
	moveq.l  #4,%d1
	move.l   reg_d4(%a6),%d0
	bra      shift_and_rotate_right_word_common

|###################################################
|# shift_and_rotate_right_long_4                   #
|###################################################
	.align	1
shift_and_rotate_right_long_4:
	moveq.l  #4,%d1
	move.l   reg_d4(%a6),%d0
	bra      shift_and_rotate_right_long_common

|###################################################
|# bftst_mem                                       #
|###################################################
	.align	1
bftst_mem:
	bsr      setup_bitfield
	bsr      calculate_effective_address
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	lea      -(_PA_BFSTRUCT_SIZE-12)(%a7),%a7
	move     %ccr,%d1
	move.l   %d7,-(%a7)
	move.l   %d6,-(%a7)
	move.l   %a1,-(%a7)
	jsr      _PA_read_bitfield
	move     %d1,%ccr
	tst.l    _PA_BFREAD_VALUE(%a7)
	lea      _PA_BFSTRUCT_SIZE(%a7),%a7
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# bftst_reg                                       #
|###################################################
	.align	1
bftst_reg:
	bsr      setup_bitfield
	bsr      read_operand_long
	move.b   reg_XNZVC(%a6),%d3
	move     %d3,%ccr
	move     %ccr,%d2
	moveq    #32,%d1
	sub.l    %d7,%d1
	sub.l    %d6,%d1
	lsr.l    %d1,%d0
	add.l    %d6,%d1
	lsl.l    %d1,%d0
	move     %d2,%ccr
	tst.l    %d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled
second_level_dispatch_931:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bftst_reg
	cmpi.l   #0x10,%d4
	bcs      illegal_189
	cmpi.l   #0x3a,%d4
	bcs      bftst_mem
illegal_189:
	jmp      illegal

|###################################################
|# shift_and_rotate_left_byte_4                    #
|###################################################
	.align	1
shift_and_rotate_left_byte_4:
	moveq.l  #4,%d1
	move.l   reg_d4(%a6),%d0
	bra      shift_and_rotate_left_byte_common

|###################################################
|# shift_and_rotate_left_word_4                    #
|###################################################
	.align	1
shift_and_rotate_left_word_4:
	moveq.l  #4,%d1
	move.l   reg_d4(%a6),%d0
	bra      shift_and_rotate_left_word_common

|###################################################
|# shift_and_rotate_left_long_4                    #
|###################################################
	.align	1
shift_and_rotate_left_long_4:
	moveq.l  #4,%d1
	move.l   reg_d4(%a6),%d0
	bra      shift_and_rotate_left_long_common

|###################################################
|# bfextu_mem                                      #
|###################################################
	.align	1
bfextu_mem:
	bsr      setup_bitfield
	bsr      calculate_effective_address
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	lea      -(_PA_BFSTRUCT_SIZE-12)(%a7),%a7
	move     %ccr,%d3
	move.l   %d7,-(%a7)
	move.l   %d6,-(%a7)
	move.l   %a1,-(%a7)
	jsr      _PA_read_bitfield
	move.l   _PA_BFRIGHT_PAD(%a7),%d2
	move.l   _PA_BFREAD_VALUE(%a7),%d1
	lsr.l    %d2,%d1
	move     %d3,%ccr
	tst.l    _PA_BFREAD_VALUE(%a7)
	lea      _PA_BFSTRUCT_SIZE(%a7),%a7
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,(%a3)
	jmp      exception_handled

|###################################################
|# bfextu_reg                                      #
|###################################################
	.align	1
bfextu_reg:
	bsr      setup_bitfield
	bsr      read_operand_long
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	move     %ccr,%d3
	moveq    #32,%d2
	move.l   %d0,%d1
	sub.l    %d7,%d2
	sub.l    %d6,%d2
	lsr.l    %d2,%d1
	add.l    %d6,%d2
	lsl.l    %d2,%d1
	move     %d3,%ccr
	tst.l    %d1
	move     %ccr,%d3
	lsr.l    %d2,%d1
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,(%a3)
	jmp      exception_handled
second_level_dispatch_935:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bfextu_reg
	cmpi.l   #0x10,%d4
	bcs      illegal_190
	cmpi.l   #0x3a,%d4
	bcs      bfextu_mem
illegal_190:
	jmp      illegal

|###################################################
|# shift_and_rotate_right_byte_5                   #
|###################################################
	.align	1
shift_and_rotate_right_byte_5:
	moveq.l  #5,%d1
	move.l   reg_d5(%a6),%d0
	bra      shift_and_rotate_right_byte_common

|###################################################
|# shift_and_rotate_right_word_5                   #
|###################################################
	.align	1
shift_and_rotate_right_word_5:
	moveq.l  #5,%d1
	move.l   reg_d5(%a6),%d0
	bra      shift_and_rotate_right_word_common

|###################################################
|# shift_and_rotate_right_long_5                   #
|###################################################
	.align	1
shift_and_rotate_right_long_5:
	moveq.l  #5,%d1
	move.l   reg_d5(%a6),%d0
	bra      shift_and_rotate_right_long_common

|###################################################
|# bfchg_mem                                       #
|###################################################
	.align	1
bfchg_mem:
	bsr      setup_bitfield
	bsr      calculate_effective_address
	move.b   reg_XNZVC(%a6),%d3
	move     %d3,%ccr
	lea      -(_PA_BFSTRUCT_SIZE-12)(%a7),%a7
	move     %ccr,%d2
	move.l   %d7,-(%a7)
	move.l   %d6,-(%a7)
	move.l   %a1,-(%a7)
	jsr      _PA_read_bitfield
	move.l   _PA_BFREAD_VALUE(%a7),%d1
	not.l    %d1
	move.l   %d1,_PA_BFWRITE_VALUE(%a7)
	jsr      _PA_write_bitfield
	move     %d2,%ccr
	tst.l    _PA_BFREAD_VALUE(%a7)
	lea      _PA_BFSTRUCT_SIZE(%a7),%a7
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# bfchg_reg                                       #
|###################################################
	.align	1
bfchg_reg:
	bsr      setup_bitfield
	bsr      read_then_write_operand_long
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	move     %ccr,%d3
	moveq    #32,%d1
	moveq    #-1,%d2
	sub.l    %d7,%d1
	sub.l    %d6,%d1
	lsr.l    %d1,%d2
	add.l    %d6,%d1
	lsl.l    %d1,%d2
	move.l   %d6,%d1
	lsr.l    %d1,%d2
	move.l   %d0,%d1
	not.l    %d1
	and.l    %d2,%d1
	not.l    %d2
	and.l    %d2,%d0
	or.l     %d1,%d0
	not.l    %d1
	not.l    %d2
	and.l    %d2,%d1
	move.l   %d6,%d2
	lsl.l    %d2,%d1
	move     %d3,%ccr
	tst.l    %d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)
second_level_dispatch_939:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bfchg_reg
	cmpi.l   #0x10,%d4
	bcs      illegal_191
	cmpi.l   #0x3a,%d4
	bcs      bfchg_mem
illegal_191:
	jmp      illegal

|###################################################
|# shift_and_rotate_left_byte_5                    #
|###################################################
	.align	1
shift_and_rotate_left_byte_5:
	moveq.l  #5,%d1
	move.l   reg_d5(%a6),%d0
	bra      shift_and_rotate_left_byte_common

|###################################################
|# shift_and_rotate_left_word_5                    #
|###################################################
	.align	1
shift_and_rotate_left_word_5:
	moveq.l  #5,%d1
	move.l   reg_d5(%a6),%d0
	bra      shift_and_rotate_left_word_common

|###################################################
|# shift_and_rotate_left_long_5                    #
|###################################################
	.align	1
shift_and_rotate_left_long_5:
	moveq.l  #5,%d1
	move.l   reg_d5(%a6),%d0
	bra      shift_and_rotate_left_long_common

|###################################################
|# bfexts_mem                                      #
|###################################################
	.align	1
bfexts_mem:
	bsr      setup_bitfield
	bsr      calculate_effective_address
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	lea      -(_PA_BFSTRUCT_SIZE-12)(%a7),%a7
	move     %ccr,%d3
	move.l   %d7,-(%a7)
	move.l   %d6,-(%a7)
	move.l   %a1,-(%a7)
	jsr      _PA_read_bitfield
	move.l   _PA_BFRIGHT_PAD(%a7),%d2
	move.l   _PA_BFREAD_VALUE(%a7),%d1
	asr.l    %d2,%d1
	move     %d3,%ccr
	tst.l    _PA_BFREAD_VALUE(%a7)
	lea      _PA_BFSTRUCT_SIZE(%a7),%a7
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,(%a3)
	jmp      exception_handled

|###################################################
|# bfexts_reg                                      #
|###################################################
	.align	1
bfexts_reg:
	bsr      setup_bitfield
	bsr      read_operand_long
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	move     %ccr,%d3
	moveq    #32,%d2
	move.l   %d0,%d1
	sub.l    %d7,%d2
	sub.l    %d6,%d2
	lsr.l    %d2,%d1
	add.l    %d6,%d2
	lsl.l    %d2,%d1
	asr.l    %d2,%d1
	move     %d3,%ccr
	tst.l    %d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,(%a3)
	jmp      exception_handled
second_level_dispatch_943:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bfexts_reg
	cmpi.l   #0x10,%d4
	bcs      illegal_192
	cmpi.l   #0x3a,%d4
	bcs      bfexts_mem
illegal_192:
	jmp      illegal

|###################################################
|# shift_and_rotate_right_byte_6                   #
|###################################################
	.align	1
shift_and_rotate_right_byte_6:
	moveq.l  #6,%d1
	move.l   reg_d6(%a6),%d0
	bra      shift_and_rotate_right_byte_common

|###################################################
|# shift_and_rotate_right_word_6                   #
|###################################################
	.align	1
shift_and_rotate_right_word_6:
	moveq.l  #6,%d1
	move.l   reg_d6(%a6),%d0
	bra      shift_and_rotate_right_word_common

|###################################################
|# shift_and_rotate_right_long_6                   #
|###################################################
	.align	1
shift_and_rotate_right_long_6:
	moveq.l  #6,%d1
	move.l   reg_d6(%a6),%d0
	bra      shift_and_rotate_right_long_common

|###################################################
|# bfclr_mem                                       #
|###################################################
	.align	1
bfclr_mem:
	bsr      setup_bitfield
	bsr      calculate_effective_address
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	lea      -(_PA_BFSTRUCT_SIZE-12)(%a7),%a7
	move     %ccr,%d1
	move.l   %d7,-(%a7)
	move.l   %d6,-(%a7)
	move.l   %a1,-(%a7)
	jsr      _PA_read_bitfield
	jsr      _PA_write_bitfield
	move     %d1,%ccr
	tst.l    _PA_BFREAD_VALUE(%a7)
	lea      _PA_BFSTRUCT_SIZE(%a7),%a7
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# bfclr_reg                                       #
|###################################################
	.align	1
bfclr_reg:
	bsr      setup_bitfield
	bsr      read_then_write_operand_long
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	move     %ccr,%d3
	moveq    #32,%d1
	moveq    #-1,%d2
	sub.l    %d7,%d1
	sub.l    %d6,%d1
	lsr.l    %d1,%d2
	add.l    %d6,%d1
	lsl.l    %d1,%d2
	move.l   %d6,%d1
	lsr.l    %d1,%d2
	move.l   %d0,%d1
	and.l    %d2,%d1
	not.l    %d2
	and.l    %d2,%d0
	move.l   %d6,%d2
	lsl.l    %d2,%d1
	move     %d3,%ccr
	tst.l    %d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)
second_level_dispatch_947:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bfclr_reg
	cmpi.l   #0x10,%d4
	bcs      illegal_193
	cmpi.l   #0x3a,%d4
	bcs      bfclr_mem
illegal_193:
	jmp      illegal

|###################################################
|# shift_and_rotate_left_byte_6                    #
|###################################################
	.align	1
shift_and_rotate_left_byte_6:
	moveq.l  #6,%d1
	move.l   reg_d6(%a6),%d0
	bra      shift_and_rotate_left_byte_common

|###################################################
|# shift_and_rotate_left_word_6                    #
|###################################################
	.align	1
shift_and_rotate_left_word_6:
	moveq.l  #6,%d1
	move.l   reg_d6(%a6),%d0
	bra      shift_and_rotate_left_word_common

|###################################################
|# shift_and_rotate_left_long_6                    #
|###################################################
	.align	1
shift_and_rotate_left_long_6:
	moveq.l  #6,%d1
	move.l   reg_d6(%a6),%d0
	bra      shift_and_rotate_left_long_common

|###################################################
|# bfffo_mem                                       #
|###################################################
	.align	1
bfffo_mem:
	bsr      setup_bitfield
	bsr      calculate_effective_address
	move.b   reg_XNZVC(%a6),%d3
	move     %d3,%ccr
	lea      -(_PA_BFSTRUCT_SIZE-12)(%a7),%a7
	move     %ccr,%d2
	move.l   %d7,-(%a7)
	move.l   %d6,-(%a7)
	move.l   %a1,-(%a7)
	jsr      _PA_read_bitfield
	jsr      _PA_search_bitfield
	move.l   _PA_BFWRITE_VALUE(%a7),%d1
	move     %d2,%ccr
	tst.l    _PA_BFREAD_VALUE(%a7)
	lea      _PA_BFSTRUCT_SIZE(%a7),%a7
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,(%a3)
	jmp      exception_handled

|###################################################
|# bfffo_reg                                       #
|###################################################
	.align	1
bfffo_reg:
	bsr      setup_bitfield
	bsr      read_operand_long
	move.b   reg_XNZVC(%a6),%d2
	move.l   %d6,%d1
	lsl.l    %d1,%d0
	bmi.s    _M68k_1593_
	move.l   %d7,%d4
	andi.l   #0x1f,%d4
	bne.s    _M68k_1593__loop
	moveq    #32,%d4
_M68k_1593__loop:
	addq.l   #1,%d1
	subq.l   #1,%d4
	beq.s    _M68k_1593_
	lsl.l    #1,%d0
	bpl.s    _M68k_1593__loop
	tst.w    %d4
_M68k_1593_:
	move     %ccr,%d4
	andi.l   #0x10,%d2
	andi.l   #0x0c,%d4
	or.l     %d4,%d2
	move     %d2,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	move.l   %d1,(%a3)
	jmp      exception_handled
second_level_dispatch_951:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bfffo_reg
	cmpi.l   #0x10,%d4
	bcs      illegal_194
	cmpi.l   #0x3a,%d4
	bcs      bfffo_mem
illegal_194:
	jmp      illegal

|###################################################
|# shift_and_rotate_right_byte_7                   #
|###################################################
	.align	1
shift_and_rotate_right_byte_7:
	moveq.l  #7,%d1
	move.l   reg_d7(%a6),%d0
	bra      shift_and_rotate_right_byte_common

|###################################################
|# shift_and_rotate_right_word_7                   #
|###################################################
	.align	1
shift_and_rotate_right_word_7:
	moveq.l  #7,%d1
	move.l   reg_d7(%a6),%d0
	bra      shift_and_rotate_right_word_common

|###################################################
|# shift_and_rotate_right_long_7                   #
|###################################################
	.align	1
shift_and_rotate_right_long_7:
	moveq.l  #7,%d1
	move.l   reg_d7(%a6),%d0
	bra      shift_and_rotate_right_long_common

|###################################################
|# bfset_mem                                       #
|###################################################
	.align	1
bfset_mem:
	bsr      setup_bitfield
	bsr      calculate_effective_address
	move.b   reg_XNZVC(%a6),%d2
	move     %d2,%ccr
	lea      -(_PA_BFSTRUCT_SIZE-12)(%a7),%a7
	move     %ccr,%d1
	move.l   %d7,-(%a7)
	move.l   %d6,-(%a7)
	move.l   %a1,-(%a7)
	jsr      _PA_read_bitfield
	subq.l   #1,_PA_BFWRITE_VALUE(%a7)
	jsr      _PA_write_bitfield
	move     %d1,%ccr
	tst.l    _PA_BFREAD_VALUE(%a7)
	lea      _PA_BFSTRUCT_SIZE(%a7),%a7
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# bfset_reg                                       #
|###################################################
	.align	1
bfset_reg:
	bsr      setup_bitfield
	bsr      read_then_write_operand_long
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	move     %ccr,%d3
	moveq    #32,%d1
	moveq    #-1,%d2
	sub.l    %d7,%d1
	sub.l    %d6,%d1
	lsr.l    %d1,%d2
	add.l    %d6,%d1
	lsl.l    %d1,%d2
	move.l   %d6,%d1
	lsr.l    %d1,%d2
	move.l   %d0,%d1
	or.l     %d2,%d0
	and.l    %d1,%d2
	move.l   %d6,%d1
	lsl.l    %d1,%d2
	move     %d3,%ccr
	tst.l    %d2
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)
second_level_dispatch_955:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bfset_reg
	cmpi.l   #0x10,%d4
	bcs      illegal_195
	cmpi.l   #0x3a,%d4
	bcs      bfset_mem
illegal_195:
	jmp      illegal

|###################################################
|# shift_and_rotate_left_byte_7                    #
|###################################################
	.align	1
shift_and_rotate_left_byte_7:
	moveq.l  #7,%d1
	move.l   reg_d7(%a6),%d0
	bra      shift_and_rotate_left_byte_common

|###################################################
|# shift_and_rotate_left_word_7                    #
|###################################################
	.align	1
shift_and_rotate_left_word_7:
	moveq.l  #7,%d1
	move.l   reg_d7(%a6),%d0
	bra      shift_and_rotate_left_word_common

|###################################################
|# shift_and_rotate_left_long_7                    #
|###################################################
	.align	1
shift_and_rotate_left_long_7:
	moveq.l  #7,%d1
	move.l   reg_d7(%a6),%d0
	bra      shift_and_rotate_left_long_common

|###################################################
|# bfins_mem                                       #
|###################################################
	.align	1
bfins_mem:
	bsr      setup_bitfield
	move.l   (%a3),%d1
	bsr      calculate_effective_address
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	lea      -(_PA_BFSTRUCT_SIZE-12)(%a7),%a7
	move     %ccr,%d3
	move.l   %d7,-(%a7)
	move.l   %d6,-(%a7)
	move.l   %a1,-(%a7)
	jsr      _PA_read_bitfield
	move.l   _PA_BFRIGHT_PAD(%a7),%d2
	lsl.l    %d2,%d1
	move.l   %d1,_PA_BFWRITE_VALUE(%a7)
	jsr      _PA_write_bitfield
	move     %d3,%ccr
	tst.l    %d1
	lea      _PA_BFSTRUCT_SIZE(%a7),%a7
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      exception_handled

|###################################################
|# bfins_reg                                       #
|###################################################
	.align	1
bfins_reg:
	bsr      setup_bitfield
	move.l   (%a3),%d1
	bsr      read_then_write_operand_long
	move.b   reg_XNZVC(%a6),%d2
	moveq    #32,%d4
	moveq    #-1,%d3
	sub.l    %d7,%d4
	lsl.l    %d4,%d1
	lsl.l    %d4,%d3
	move.l   %d6,%d4
	lsr.l    %d4,%d3
	lsr.l    %d4,%d1
	not.l    %d3
	and.l    %d3,%d0
	or.l     %d1,%d0
	lsl.l    %d6,%d1
	move     %d2,%ccr
	tst.l    %d1
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)
second_level_dispatch_959:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      bfins_reg
	cmpi.l   #0x10,%d4
	bcs      illegal_196
	cmpi.l   #0x3a,%d4
	bcs      bfins_mem
illegal_196:
	jmp      illegal

|###################################################
|# move16_abs_indirect                             #
|###################################################
	.align	1
move16_abs_indirect:
	and.l    #0x7,%d5
	move.l   (reg_a0,%a6,%d5.l*4),%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a2
	move.l   2(%a0),%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a4
	addq.l   #6,%a0
	move.l   (%a4)+,(%a2)+
	move.l   (%a4)+,(%a2)+
	move.l   (%a4)+,(%a2)+
	move.l   (%a4)+,(%a2)+
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# move16_indirect_abs                             #
|###################################################
	.align	1
move16_indirect_abs:
	and.l    #0x7,%d5
	move.l   (reg_a0,%a6,%d5.l*4),%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a2
	move.l   2(%a0),%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a4
	addq.l   #6,%a0
	move.l   (%a2)+,(%a4)+
	move.l   (%a2)+,(%a4)+
	move.l   (%a2)+,(%a4)+
	move.l   (%a2)+,(%a4)+
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# move16_abs_inc                                  #
|###################################################
	.align	1
move16_abs_inc:
	and.l    #0x7,%d5
	move.l   (reg_a0,%a6,%d5.l*4),%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a2
	moveq.l  #16,%d1
	add.l    %d1,(reg_a0,%a6,%d5.l*4)
	move.l   2(%a0),%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a4
	addq.l   #6,%a0
	move.l   (%a4)+,(%a2)+
	move.l   (%a4)+,(%a2)+
	move.l   (%a4)+,(%a2)+
	move.l   (%a4)+,(%a2)+
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# move16_inc_abs                                  #
|###################################################
	.align	1
move16_inc_abs:
	and.l    #0x7,%d5
	move.l   (reg_a0,%a6,%d5.l*4),%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a2
	moveq.l  #16,%d1
	add.l    %d1,(reg_a0,%a6,%d5.l*4)
	move.l   2(%a0),%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a4
	addq.l   #6,%a0
	move.l   (%a2)+,(%a4)+
	move.l   (%a2)+,(%a4)+
	move.l   (%a2)+,(%a4)+
	move.l   (%a2)+,(%a4)+
	moveq.l  #0x0,%d6
	jmp      exception_handled
second_level_dispatch_984:
	move.l   %d5,%d4
	and.l    #0x3f,%d4
	cmpi.l   #0x8,%d4
	bcs      move16_inc_abs
	cmpi.l   #0x10,%d4
	bcs      move16_abs_inc
	cmpi.l   #0x18,%d4
	bcs      move16_indirect_abs
	cmpi.l   #0x20,%d4
	bcs      move16_abs_indirect
	cmpi.l   #0x28,%d4
	bcs      move16_inc_inc
illegal_197:
	jmp      illegal

|###################################################
|# move16_inc_inc                                  #
|###################################################
	.align	1
move16_inc_inc:
	and.l    #0x7,%d5
	move.l   (reg_a0,%a6,%d5.l*4),%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a2
	moveq.l  #16,%d1
	add.l    %d1,(reg_a0,%a6,%d5.l*4)
	move.b   2(%a0),%d5
	lsr.l    #4,%d5
	and.l    #0x7,%d5
	move.l   (reg_a0,%a6,%d5.l*4),%a4
	add.l    %d1,(reg_a0,%a6,%d5.l*4)
	addq.l   #4,%a0
	move.l   %a4,%d1
	and.l    #0xfffffff0,%d1
	move.l   %d1,%a4
	move.l   (%a2)+,(%a4)+
	move.l   (%a2)+,(%a4)+
	move.l   (%a2)+,(%a4)+
	move.l   (%a2)+,(%a4)+
	moveq.l  #0x0,%d6
	jmp      exception_handled

|###################################################
|# asl_byte_reg                                    #
|###################################################
	.align	1
asl_byte_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_byte
	moveq    #24,%d3
	move     %ccr,%d4
	move.l   %d0,%d2
	lsl.l    %d3,%d2
	move     %d4,%ccr
	asl.l    %d1,%d0
	move.l   %d2,%d4
	asl.l    %d1,%d2
	move     %ccr,%d3
	asr.l    %d1,%d2
	cmp.l    %d4,%d2
	sne      %d4
	and.l    #2,%d4
	or.l     %d4,%d3
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# asl_word_reg                                    #
|###################################################
	.align	1
asl_word_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_word
	moveq    #16,%d3
	tst.b    %d1
	bne.s    _M68k_1370_1
	tst.w    %d0
	bra.s    _M68k_1370_2
_M68k_1370_1:
	move.l   %d0,%d2
	lsl.l    %d3,%d2
	asl.l    %d1,%d0
	move.l   %d2,%d4
	asl.l    %d1,%d2
	move     %ccr,%d3
	asr.l    %d1,%d2
	cmp.l    %d4,%d2
	sne      %d4
	and.l    #2,%d4
	or.l     %d4,%d3
	move     %d3,%ccr
_M68k_1370_2:
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# asl_long_reg                                    #
|###################################################
	.align	1
asl_long_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_long
	move.l   %d0,%d2
	asl.l    %d1,%d0
	move     %ccr,%d3
	move.l   %d0,%d4
	asr.l    %d1,%d4
	cmp.l    %d2,%d4
	sne      %d2
	and.l    #2,%d2
	or.l     %d2,%d3
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# asr_byte_reg                                    #
|###################################################
	.align	1
asr_byte_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_byte
	extb.l   %d0
	asr.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# asr_word_reg                                    #
|###################################################
	.align	1
asr_word_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_word
	ext.l    %d0
	asr.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# asr_long_reg                                    #
|###################################################
	.align	1
asr_long_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_long
	asr.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# lsl_byte_reg                                    #
|###################################################
	.align	1
lsl_byte_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_byte
	moveq    #24,%d3
	move.l   %d0,%d2
	lsl.l    %d3,%d2
	lsl.l    %d1,%d0
	lsl.l    %d1,%d2
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# lsl_word_reg                                    #
|###################################################
	.align	1
lsl_word_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_word
	move.l   %d0,%d2
	swap     %d2
	clr.w    %d2
	lsl.l    %d1,%d0
	lsl.l    %d1,%d2
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# lsl_long_reg                                    #
|###################################################
	.align	1
lsl_long_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_long
	lsl.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# lsr_byte_reg                                    #
|###################################################
	.align	1
lsr_byte_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_byte
	and.l    #0x000000ff,%d0
	tst.b    %d1
	beq.s    _M68k_1405_1
	lsr.l    %d1,%d0
	bra.s    _M68k_1405_2
_M68k_1405_1:
	tst.b    %d0
_M68k_1405_2:
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# lsr_word_reg                                    #
|###################################################
	.align	1
lsr_word_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_word
	and.l    #0x0000ffff,%d0
	tst.w    %d1
	beq.s    _M68k_1406_1
	lsr.l    %d1,%d0
	bra.s    _M68k_1406_2
_M68k_1406_1:
	tst.w    %d0
_M68k_1406_2:
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# lsr_long_reg                                    #
|###################################################
	.align	1
lsr_long_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_long
	lsr.l    %d1,%d0
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# rol_byte_reg                                    #
|###################################################
	.align	1
rol_byte_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_byte
	move     %ccr,%d4
	tst.b    %d1
	bne.s    _M68k_1409_1
	tst.b    %d0
	bra.s    _M68k_1409_2
_M68k_1409_1:
	and.l    #7,%d1
	move.b   %d0,%d2
	lsl.l    #8,%d2
	move.b   %d0,%d2
	lsl.l    %d1,%d2
	lsr.l    #8,%d2
	move.b   %d2,%d0
	move     %ccr,%d3
	lsr.l    #1,%d2
	move     %ccr,%d2
	and.l    #1,%d2
	and.l    #0x0e,%d3
	and.l    #0x10,%d4
	or.l     %d3,%d2
	or.l     %d4,%d2
	move     %d2,%ccr
_M68k_1409_2:
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# rol_word_reg                                    #
|###################################################
	.align	1
rol_word_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_word
	tst.b    %d1
	bne.s    _M68k_1410_1
	tst.w    %d0
	bra.s    _M68k_1410_2
_M68k_1410_1:
	and.l    #15,%d1
	move.w   %d0,%d2
	swap     %d0
	move.w   %d2,%d0
	move     %ccr,%d3
	lsl.l    %d1,%d0
	swap     %d0
	move.w   %d0,%d2
	move     %ccr,%d4
	andi.l   #0x01,%d2
	or.l     %d2,%d3
	andi.l   #0x11,%d3
	andi.l   #0x0E,%d4
	or.l     %d3,%d4
	move     %d4,%ccr
_M68k_1410_2:
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# rol_long_reg                                    #
|###################################################
	.align	1
rol_long_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_long
	move     %ccr,%d4
	and.l    #31,%d1
	move.l   %d0,%d2
	lsl.l    %d1,%d0
	moveq    #32,%d3
	sub.l    %d1,%d3
	lsr.l    %d3,%d2
	or.l     %d2,%d0
	move     %ccr,%d3
	move.l   %d0,%d2
	andi.l   #0x01,%d2
	andi.l   #0x10,%d4
	andi.l   #0x0E,%d3
	or.l     %d4,%d2
	or.l     %d3,%d2
	move     %d2,%ccr
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# ror_byte_reg                                    #
|###################################################
	.align	1
ror_byte_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_byte
	tst.b    %d1
	bne.s    _M68k_1413_1
	tst.b    %d0
	bra.s    _M68k_1413_2
_M68k_1413_1:
	and.l    #7,%d1
	move     %ccr,%d3
	move.b   %d0,%d2
	lsl.l    #8,%d2
	move.b   %d0,%d2
	lsr.l    %d1,%d2
	move.b   %d2,%d0
	lsr.l    #8,%d2
	move     %ccr,%d2
	and.l    #1,%d2
	or.l     %d2,%d3
	tst.b    %d0
	move     %ccr,%d2
	and.l    #0x11,%d3
	and.l    #0x0E,%d2
	or.l     %d3,%d2
	move     %d2,%ccr
_M68k_1413_2:
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# ror_word_reg                                    #
|###################################################
	.align	1
ror_word_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_word
	tst.b    %d1
	bne.s    _M68k_1414_1
	tst.w    %d0
	bra.s    _M68k_1414_2
_M68k_1414_1:
	and.l    #15,%d1
	move     %ccr,%d3
	move.w   %d0,%d2
	swap     %d2
	move.w   %d0,%d2
	lsr.l    %d1,%d2
	move.w   %d2,%d0
	swap     %d2
	lsl.l    #1,%d2
	move     %ccr,%d2
	and.l    #1,%d2
	and.l    #0x10,%d3
	or.l     %d2,%d3
	tst.w    %d0
	move     %ccr,%d2
	and.l    #0x0E,%d2
	or.l     %d3,%d2
	move     %d2,%ccr
_M68k_1414_2:
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# ror_long_reg                                    #
|###################################################
	.align	1
ror_long_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_long
	tst.b    %d1
	bne.s    _M68k_1415_1
	tst.l    %d0
	bra.s    _M68k_1415_2
_M68k_1415_1:
	and.l    #31,%d1
	move     %ccr,%d4
	move.l   %d0,%d2
	lsr.l    %d1,%d0
	moveq    #32,%d3
	sub.l    %d1,%d3
	lsl.l    %d3,%d2
	or.l     %d2,%d0
	move     %ccr,%d3
	move.l   %d0,%d2
	lsl.l    #1,%d2
	clr.l    %d2
	addx.l   %d2,%d4
	and.l    #0x11,%d4
	and.l    #0x0E,%d3
	or.l     %d3,%d4
	move     %d4,%ccr
_M68k_1415_2:
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# roxl_byte_reg                                   #
|###################################################
	.align	1
roxl_byte_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_byte
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	move.b   %d0,%d2
	addx.l   %d0,%d0
	lsl.l    #8,%d0
	move.b   %d2,%d0
	and.l    #0x0f,%d1
	move.l   #9,%d3
	sub.l    %d1,%d3
	lsr.l    %d3,%d0
	addx.l   %d2,%d2
	lsl.l    #8,%d2
	move.b   %d0,%d2
	moveq.l  #24,%d3
	lsl.l    %d3,%d2
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# roxl_word_reg                                   #
|###################################################
	.align	1
roxl_word_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_word
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	and.l    #0x1f,%d1
	beq.s    _M68k_1418_
	move.w   %d0,%d2
	addx.l   %d0,%d0
	swap     %d0
	move.w   %d2,%d0
	move.w   #17,%d3
	sub.l    %d1,%d3
	lsr.l    %d3,%d0
_M68k_1418_:
	addx.l   %d2,%d2
	swap     %d2
	move.w   %d0,%d2
	moveq.l  #16,%d3
	lsl.l    %d3,%d2
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# roxl_long_reg                                   #
|###################################################
	.align	1
roxl_long_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_long
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	and.l    #0x3f,%d1
	beq.s    _M68k_1419_
	move.l   %d0,%d2
	addx.l   %d0,%d0
	subq.l   #1,%d1
	and.l    #0x1f,%d1
	moveq    #32,%d3
	sub.l    %d1,%d3
	lsr.l    %d3,%d2
	lsl.l    %d1,%d0
	or.l     %d2,%d0
_M68k_1419_:
	tst.l    %d0
	move     %ccr,%d2
	btst     #4,%d2
	beq.s    _M68k_1419__2
	bset     #0,%d2
_M68k_1419__2:
	move     %d2,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# roxr_byte_reg                                   #
|###################################################
	.align	1
roxr_byte_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_byte
	moveq    #24,%d3
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	move.b   %d0,%d2
	addx.l   %d0,%d0
	lsl.l    #8,%d0
	move.b   %d2,%d0
	and.l    #0x0f,%d1
	bne.s    _M68k_1421_
	moveq.l  #9,%d1
_M68k_1421_:
	lsr.l    %d1,%d0
	addx.l   %d2,%d2
	lsl.l    #8,%d2
	move.b   %d0,%d2
	lsl.l    %d3,%d2
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# roxr_word_reg                                   #
|###################################################
	.align	1
roxr_word_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_word
	moveq    #16,%d3
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	and.l    #0x1f,%d1
	beq.s    _M68k_1422_
	move.w   %d0,%d2
	addx.l   %d0,%d0
	swap     %d0
	move.w   %d2,%d0
	lsr.l    %d1,%d0
_M68k_1422_:
	addx.l   %d2,%d2
	swap     %d2
	move.w   %d0,%d2
	lsl.l    %d3,%d2
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# roxr_long_reg                                   #
|###################################################
	.align	1
roxr_long_reg:
	and.l    #7,%d5
	bsr      read_then_write_operand_long
	move.b   reg_XNZVC(%a6),%d4
	move     %d4,%ccr
	and.l    #0x3f,%d1
	bne.s    _M68k_1423_
	move     %ccr,%d3
	btst     #4,%d3
	sne      %d3
	clr.l    %d2
	bra.s    _M68k_1423__2
_M68k_1423_:
	move.l   %d0,%d2
	addx.l   %d2,%d2
	moveq    #32,%d3
	sub.l    %d1,%d3
	lsl.l    %d3,%d2
	lsr.l    %d1,%d0
	move     %ccr,%d3
_M68k_1423__2:
	or.l     %d2,%d0
	move     %ccr,%d2
	andi.l   #0x000e,%d2
	andi.l   #0x0011,%d3
	or.l     %d2,%d3
	move     %d3,%ccr
	move     %ccr,%d7
	moveq.l  #0x1f,%d6
	jmp      (%a3)

|###################################################
|# swap_handler                                    #
|###################################################
	.align	1
swap_handler:
	bsr      read_then_write_operand_long
	swap     %d0
	move     %ccr,%d7
	moveq.l  #0xf,%d6
	jmp      (%a3)

|###################################################
|# bkpt_handler                                    #
|###################################################
	.align	1
bkpt_handler:
	jmp      handle_bkpt

|#########################################################################
|# Instruction Dispatch Table                                            #
|#########################################################################
|# Indexed by top 10 bits of instruction word
	.data
dispatch_table:
	.long 	second_level_dispatch_0                 		| 0x0
	.long 	second_level_dispatch_1                 		| 0x1
	.long 	or_immediate_long                       		| 0x2
	.long 	chk2_and_cmp2                           		| 0x3
	.long 	second_level_dispatch_4                 		| 0x4
	.long 	second_level_dispatch_5                 		| 0x5
	.long 	second_level_dispatch_6                 		| 0x6
	.long 	second_level_dispatch_7                 		| 0x7
	.long 	second_level_dispatch_8                 		| 0x8
	.long 	second_level_dispatch_9                 		| 0x9
	.long 	and_immediate_long                      		| 0xa
	.long 	chk2_and_cmp2                           		| 0xb
	.long 	second_level_dispatch_12                		| 0xc
	.long 	second_level_dispatch_13                		| 0xd
	.long 	second_level_dispatch_14                		| 0xe
	.long 	second_level_dispatch_15                		| 0xf
	.long 	sub_immediate_byte                      		| 0x10
	.long 	sub_immediate_word                      		| 0x11
	.long 	sub_immediate_long                      		| 0x12
	.long 	chk2_and_cmp2                           		| 0x13
	.long 	second_level_dispatch_20                		| 0x14
	.long 	second_level_dispatch_21                		| 0x15
	.long 	second_level_dispatch_22                		| 0x16
	.long 	second_level_dispatch_23                		| 0x17
	.long 	add_immediate_byte                      		| 0x18
	.long 	add_immediate_word                      		| 0x19
	.long 	add_immediate_long                      		| 0x1a
	.long 	second_level_dispatch_27                		| 0x1b
	.long 	second_level_dispatch_28                		| 0x1c
	.long 	second_level_dispatch_29                		| 0x1d
	.long 	second_level_dispatch_30                		| 0x1e
	.long 	second_level_dispatch_31                		| 0x1f
	.long 	second_level_dispatch_32                		| 0x20
	.long 	second_level_dispatch_33                		| 0x21
	.long 	second_level_dispatch_34                		| 0x22
	.long 	second_level_dispatch_35                		| 0x23
	.long 	second_level_dispatch_36                		| 0x24
	.long 	second_level_dispatch_37                		| 0x25
	.long 	second_level_dispatch_38                		| 0x26
	.long 	second_level_dispatch_39                		| 0x27
	.long 	second_level_dispatch_40                		| 0x28
	.long 	second_level_dispatch_41                		| 0x29
	.long 	eor_immediate_long                      		| 0x2a
	.long 	second_level_dispatch_43                		| 0x2b
	.long 	second_level_dispatch_44                		| 0x2c
	.long 	second_level_dispatch_45                		| 0x2d
	.long 	second_level_dispatch_46                		| 0x2e
	.long 	second_level_dispatch_47                		| 0x2f
	.long 	cmp_immediate_byte                      		| 0x30
	.long 	cmp_immediate_word                      		| 0x31
	.long 	cmp_immediate_long                      		| 0x32
	.long 	second_level_dispatch_51                		| 0x33
	.long 	second_level_dispatch_52                		| 0x34
	.long 	second_level_dispatch_53                		| 0x35
	.long 	second_level_dispatch_54                		| 0x36
	.long 	second_level_dispatch_55                		| 0x37
	.long 	moves_byte                              		| 0x38
	.long 	moves_word                              		| 0x39
	.long 	moves_long                              		| 0x3a
	.long 	second_level_dispatch_59                		| 0x3b
	.long 	second_level_dispatch_60                		| 0x3c
	.long 	second_level_dispatch_61                		| 0x3d
	.long 	second_level_dispatch_62                		| 0x3e
	.long 	second_level_dispatch_63                		| 0x3f
	.long 	move_byte_D0                            		| 0x40
	.long 	illegal                                 		| 0x41
	.long 	move_byte_indirect_A0                   		| 0x42
	.long 	move_byte_postincrement_A0              		| 0x43
	.long 	move_byte_predecrement_A0               		| 0x44
	.long 	move_byte_displacement_A0               		| 0x45
	.long 	move_byte_indexed_A0                    		| 0x46
	.long 	move_byte_absolute_word                 		| 0x47
	.long 	move_byte_D1                            		| 0x48
	.long 	illegal                                 		| 0x49
	.long 	move_byte_indirect_A1                   		| 0x4a
	.long 	move_byte_postincrement_A1              		| 0x4b
	.long 	move_byte_predecrement_A1               		| 0x4c
	.long 	move_byte_displacement_A1               		| 0x4d
	.long 	move_byte_indexed_A1                    		| 0x4e
	.long 	move_byte_absolute_long                 		| 0x4f
	.long 	move_byte_D2                            		| 0x50
	.long 	illegal                                 		| 0x51
	.long 	move_byte_indirect_A2                   		| 0x52
	.long 	move_byte_postincrement_A2              		| 0x53
	.long 	move_byte_predecrement_A2               		| 0x54
	.long 	move_byte_displacement_A2               		| 0x55
	.long 	move_byte_indexed_A2                    		| 0x56
	.long 	illegal                                 		| 0x57
	.long 	move_byte_D3                            		| 0x58
	.long 	illegal                                 		| 0x59
	.long 	move_byte_indirect_A3                   		| 0x5a
	.long 	move_byte_postincrement_A3              		| 0x5b
	.long 	move_byte_predecrement_A3               		| 0x5c
	.long 	move_byte_displacement_A3               		| 0x5d
	.long 	move_byte_indexed_A3                    		| 0x5e
	.long 	illegal                                 		| 0x5f
	.long 	move_byte_D4                            		| 0x60
	.long 	illegal                                 		| 0x61
	.long 	move_byte_indirect_A4                   		| 0x62
	.long 	move_byte_postincrement_A4              		| 0x63
	.long 	move_byte_predecrement_A4               		| 0x64
	.long 	move_byte_displacement_A4               		| 0x65
	.long 	move_byte_indexed_A4                    		| 0x66
	.long 	illegal                                 		| 0x67
	.long 	move_byte_D5                            		| 0x68
	.long 	illegal                                 		| 0x69
	.long 	move_byte_indirect_A5                   		| 0x6a
	.long 	move_byte_postincrement_A5              		| 0x6b
	.long 	move_byte_predecrement_A5               		| 0x6c
	.long 	move_byte_displacement_A5               		| 0x6d
	.long 	move_byte_indexed_A5                    		| 0x6e
	.long 	illegal                                 		| 0x6f
	.long 	move_byte_D6                            		| 0x70
	.long 	illegal                                 		| 0x71
	.long 	move_byte_indirect_A6                   		| 0x72
	.long 	move_byte_postincrement_A6              		| 0x73
	.long 	move_byte_predecrement_A6               		| 0x74
	.long 	move_byte_displacement_A6               		| 0x75
	.long 	move_byte_indexed_A6                    		| 0x76
	.long 	illegal                                 		| 0x77
	.long 	move_byte_D7                            		| 0x78
	.long 	illegal                                 		| 0x79
	.long 	move_byte_indirect_A7                   		| 0x7a
	.long 	move_byte_postincrement_A7              		| 0x7b
	.long 	move_byte_predecrement_A7               		| 0x7c
	.long 	move_byte_displacement_A7               		| 0x7d
	.long 	move_byte_indexed_A7                    		| 0x7e
	.long 	illegal                                 		| 0x7f
	.long 	move_long_D0                            		| 0x80
	.long 	movea_long_A0                           		| 0x81
	.long 	move_long_indirect_A0                   		| 0x82
	.long 	move_long_postincrement_A0              		| 0x83
	.long 	move_long_predecrement_A0               		| 0x84
	.long 	move_long_displacement_A0               		| 0x85
	.long 	move_long_indexed_A0                    		| 0x86
	.long 	move_long_absolute_word                 		| 0x87
	.long 	move_long_D1                            		| 0x88
	.long 	movea_long_A1                           		| 0x89
	.long 	move_long_indirect_A1                   		| 0x8a
	.long 	move_long_postincrement_A1              		| 0x8b
	.long 	move_long_predecrement_A1               		| 0x8c
	.long 	move_long_displacement_A1               		| 0x8d
	.long 	move_long_indexed_A1                    		| 0x8e
	.long 	move_long_absolute_long                 		| 0x8f
	.long 	move_long_D2                            		| 0x90
	.long 	movea_long_A2                           		| 0x91
	.long 	move_long_indirect_A2                   		| 0x92
	.long 	move_long_postincrement_A2              		| 0x93
	.long 	move_long_predecrement_A2               		| 0x94
	.long 	move_long_displacement_A2               		| 0x95
	.long 	move_long_indexed_A2                    		| 0x96
	.long 	illegal                                 		| 0x97
	.long 	move_long_D3                            		| 0x98
	.long 	movea_long_A3                           		| 0x99
	.long 	move_long_indirect_A3                   		| 0x9a
	.long 	move_long_postincrement_A3              		| 0x9b
	.long 	move_long_predecrement_A3               		| 0x9c
	.long 	move_long_displacement_A3               		| 0x9d
	.long 	move_long_indexed_A3                    		| 0x9e
	.long 	illegal                                 		| 0x9f
	.long 	move_long_D4                            		| 0xa0
	.long 	movea_long_A4                           		| 0xa1
	.long 	move_long_indirect_A4                   		| 0xa2
	.long 	move_long_postincrement_A4              		| 0xa3
	.long 	move_long_predecrement_A4               		| 0xa4
	.long 	move_long_displacement_A4               		| 0xa5
	.long 	move_long_indexed_A4                    		| 0xa6
	.long 	illegal                                 		| 0xa7
	.long 	move_long_D5                            		| 0xa8
	.long 	movea_long_A5                           		| 0xa9
	.long 	move_long_indirect_A5                   		| 0xaa
	.long 	move_long_postincrement_A5              		| 0xab
	.long 	move_long_predecrement_A5               		| 0xac
	.long 	move_long_displacement_A5               		| 0xad
	.long 	move_long_indexed_A5                    		| 0xae
	.long 	illegal                                 		| 0xaf
	.long 	move_long_D6                            		| 0xb0
	.long 	movea_long_A6                           		| 0xb1
	.long 	move_long_indirect_A6                   		| 0xb2
	.long 	move_long_postincrement_A6              		| 0xb3
	.long 	move_long_predecrement_A6               		| 0xb4
	.long 	move_long_displacement_A6               		| 0xb5
	.long 	move_long_indexed_A6                    		| 0xb6
	.long 	illegal                                 		| 0xb7
	.long 	move_long_D7                            		| 0xb8
	.long 	movea_long_A7                           		| 0xb9
	.long 	move_long_indirect_A7                   		| 0xba
	.long 	move_long_postincrement_A7              		| 0xbb
	.long 	move_long_predecrement_A7               		| 0xbc
	.long 	move_long_displacement_A7               		| 0xbd
	.long 	move_long_indexed_A7                    		| 0xbe
	.long 	illegal                                 		| 0xbf
	.long 	move_word_D0                            		| 0xc0
	.long 	movea_word_A0                           		| 0xc1
	.long 	move_word_indirect_A0                   		| 0xc2
	.long 	move_word_postincrement_A0              		| 0xc3
	.long 	move_word_predecrement_A0               		| 0xc4
	.long 	move_word_displacement_A0               		| 0xc5
	.long 	move_word_indexed_A0                    		| 0xc6
	.long 	move_word_absolute_word                 		| 0xc7
	.long 	move_word_D1                            		| 0xc8
	.long 	movea_word_A1                           		| 0xc9
	.long 	move_word_indirect_A1                   		| 0xca
	.long 	move_word_postincrement_A1              		| 0xcb
	.long 	move_word_predecrement_A1               		| 0xcc
	.long 	move_word_displacement_A1               		| 0xcd
	.long 	move_word_indexed_A1                    		| 0xce
	.long 	move_word_absolute_long                 		| 0xcf
	.long 	move_word_D2                            		| 0xd0
	.long 	movea_word_A2                           		| 0xd1
	.long 	move_word_indirect_A2                   		| 0xd2
	.long 	move_word_postincrement_A2              		| 0xd3
	.long 	move_word_predecrement_A2               		| 0xd4
	.long 	move_word_displacement_A2               		| 0xd5
	.long 	move_word_indexed_A2                    		| 0xd6
	.long 	illegal                                 		| 0xd7
	.long 	move_word_D3                            		| 0xd8
	.long 	movea_word_A3                           		| 0xd9
	.long 	move_word_indirect_A3                   		| 0xda
	.long 	move_word_postincrement_A3              		| 0xdb
	.long 	move_word_predecrement_A3               		| 0xdc
	.long 	move_word_displacement_A3               		| 0xdd
	.long 	move_word_indexed_A3                    		| 0xde
	.long 	illegal                                 		| 0xdf
	.long 	move_word_D4                            		| 0xe0
	.long 	movea_word_A4                           		| 0xe1
	.long 	move_word_indirect_A4                   		| 0xe2
	.long 	move_word_postincrement_A4              		| 0xe3
	.long 	move_word_predecrement_A4               		| 0xe4
	.long 	move_word_displacement_A4               		| 0xe5
	.long 	move_word_indexed_A4                    		| 0xe6
	.long 	illegal                                 		| 0xe7
	.long 	move_word_D5                            		| 0xe8
	.long 	movea_word_A5                           		| 0xe9
	.long 	move_word_indirect_A5                   		| 0xea
	.long 	move_word_postincrement_A5              		| 0xeb
	.long 	move_word_predecrement_A5               		| 0xec
	.long 	move_word_displacement_A5               		| 0xed
	.long 	move_word_indexed_A5                    		| 0xee
	.long 	illegal                                 		| 0xef
	.long 	move_word_D6                            		| 0xf0
	.long 	movea_word_A6                           		| 0xf1
	.long 	move_word_indirect_A6                   		| 0xf2
	.long 	move_word_postincrement_A6              		| 0xf3
	.long 	move_word_predecrement_A6               		| 0xf4
	.long 	move_word_displacement_A6               		| 0xf5
	.long 	move_word_indexed_A6                    		| 0xf6
	.long 	illegal                                 		| 0xf7
	.long 	move_word_D7                            		| 0xf8
	.long 	movea_word_A7                           		| 0xf9
	.long 	move_word_indirect_A7                   		| 0xfa
	.long 	move_word_postincrement_A7              		| 0xfb
	.long 	move_word_predecrement_A7               		| 0xfc
	.long 	move_word_displacement_A7               		| 0xfd
	.long 	move_word_indexed_A7                    		| 0xfe
	.long 	illegal                                 		| 0xff
	.long 	negx_byte                               		| 0x100
	.long 	negx_word                               		| 0x101
	.long 	negx_long                               		| 0x102
	.long 	move_from_SR                            		| 0x103
	.long 	chk_long                                		| 0x104
	.long 	illegal                                 		| 0x105
	.long 	chk_word                                		| 0x106
	.long 	lea_A0                                  		| 0x107
	.long 	clr_byte                                		| 0x108
	.long 	clr_word                                		| 0x109
	.long 	clr_long                                		| 0x10a
	.long 	move_from_CCR                           		| 0x10b
	.long 	chk_long                                		| 0x10c
	.long 	illegal                                 		| 0x10d
	.long 	chk_word                                		| 0x10e
	.long 	lea_A1                                  		| 0x10f
	.long 	neg_byte                                		| 0x110
	.long 	neg_word                                		| 0x111
	.long 	neg_long                                		| 0x112
	.long 	move_to_CCR                             		| 0x113
	.long 	chk_long                                		| 0x114
	.long 	illegal                                 		| 0x115
	.long 	chk_word                                		| 0x116
	.long 	lea_A2                                  		| 0x117
	.long 	not_byte                                		| 0x118
	.long 	not_word                                		| 0x119
	.long 	not_long                                		| 0x11a
	.long 	move_to_SR                              		| 0x11b
	.long 	chk_long                                		| 0x11c
	.long 	illegal                                 		| 0x11d
	.long 	chk_word                                		| 0x11e
	.long 	lea_A3                                  		| 0x11f
	.long 	second_level_dispatch_288               		| 0x120
	.long 	pea                                     		| 0x121
	.long 	second_level_dispatch_290               		| 0x122
	.long 	second_level_dispatch_291               		| 0x123
	.long 	chk_long                                		| 0x124
	.long 	illegal                                 		| 0x125
	.long 	chk_word                                		| 0x126
	.long 	second_level_dispatch_295               		| 0x127
	.long 	tst_byte                                		| 0x128
	.long 	tst_word                                		| 0x129
	.long 	tst_long                                		| 0x12a
	.long 	second_level_dispatch_299               		| 0x12b
	.long 	chk_long                                		| 0x12c
	.long 	illegal                                 		| 0x12d
	.long 	chk_word                                		| 0x12e
	.long 	lea_A5                                  		| 0x12f
	.long 	muls_and_mulu_long                      		| 0x130
	.long 	divs_and_divu_long                      		| 0x131
	.long 	second_level_dispatch_306               		| 0x132
	.long 	second_level_dispatch_307               		| 0x133
	.long 	chk_long                                		| 0x134
	.long 	illegal                                 		| 0x135
	.long 	chk_word                                		| 0x136
	.long 	lea_A6                                  		| 0x137
	.long 	escape                                  		| 0x138
	.long 	second_level_dispatch_313               		| 0x139
	.long 	jsr                                     		| 0x13a
	.long 	jmp                                     		| 0x13b
	.long 	chk_long                                		| 0x13c
	.long 	illegal                                 		| 0x13d
	.long 	chk_word                                		| 0x13e
	.long 	lea_A7                                  		| 0x13f
	.long 	add_quick_byte_8                        		| 0x140
	.long 	second_level_dispatch_321               		| 0x141
	.long 	second_level_dispatch_322               		| 0x142
	.long 	second_level_dispatch_323               		| 0x143
	.long 	sub_quick_byte_8                        		| 0x144
	.long 	second_level_dispatch_325               		| 0x145
	.long 	second_level_dispatch_326               		| 0x146
	.long 	second_level_dispatch_327               		| 0x147
	.long 	add_quick_byte                          		| 0x148
	.long 	second_level_dispatch_329               		| 0x149
	.long 	second_level_dispatch_330               		| 0x14a
	.long 	second_level_dispatch_331               		| 0x14b
	.long 	sub_quick_byte                          		| 0x14c
	.long 	second_level_dispatch_333               		| 0x14d
	.long 	second_level_dispatch_334               		| 0x14e
	.long 	second_level_dispatch_335               		| 0x14f
	.long 	add_quick_byte                          		| 0x150
	.long 	second_level_dispatch_337               		| 0x151
	.long 	second_level_dispatch_338               		| 0x152
	.long 	second_level_dispatch_339               		| 0x153
	.long 	sub_quick_byte                          		| 0x154
	.long 	second_level_dispatch_341               		| 0x155
	.long 	second_level_dispatch_342               		| 0x156
	.long 	second_level_dispatch_343               		| 0x157
	.long 	add_quick_byte                          		| 0x158
	.long 	second_level_dispatch_345               		| 0x159
	.long 	second_level_dispatch_346               		| 0x15a
	.long 	second_level_dispatch_347               		| 0x15b
	.long 	sub_quick_byte                          		| 0x15c
	.long 	second_level_dispatch_349               		| 0x15d
	.long 	second_level_dispatch_350               		| 0x15e
	.long 	second_level_dispatch_351               		| 0x15f
	.long 	add_quick_byte                          		| 0x160
	.long 	second_level_dispatch_353               		| 0x161
	.long 	second_level_dispatch_354               		| 0x162
	.long 	second_level_dispatch_355               		| 0x163
	.long 	sub_quick_byte                          		| 0x164
	.long 	second_level_dispatch_357               		| 0x165
	.long 	second_level_dispatch_358               		| 0x166
	.long 	second_level_dispatch_359               		| 0x167
	.long 	add_quick_byte                          		| 0x168
	.long 	second_level_dispatch_361               		| 0x169
	.long 	second_level_dispatch_362               		| 0x16a
	.long 	second_level_dispatch_363               		| 0x16b
	.long 	sub_quick_byte                          		| 0x16c
	.long 	second_level_dispatch_365               		| 0x16d
	.long 	second_level_dispatch_366               		| 0x16e
	.long 	second_level_dispatch_367               		| 0x16f
	.long 	add_quick_byte                          		| 0x170
	.long 	second_level_dispatch_369               		| 0x171
	.long 	second_level_dispatch_370               		| 0x172
	.long 	second_level_dispatch_371               		| 0x173
	.long 	sub_quick_byte                          		| 0x174
	.long 	second_level_dispatch_373               		| 0x175
	.long 	second_level_dispatch_374               		| 0x176
	.long 	second_level_dispatch_375               		| 0x177
	.long 	add_quick_byte                          		| 0x178
	.long 	second_level_dispatch_377               		| 0x179
	.long 	second_level_dispatch_378               		| 0x17a
	.long 	second_level_dispatch_379               		| 0x17b
	.long 	sub_quick_byte                          		| 0x17c
	.long 	second_level_dispatch_381               		| 0x17d
	.long 	second_level_dispatch_382               		| 0x17e
	.long 	second_level_dispatch_383               		| 0x17f
	.long 	bra                                     		| 0x180
	.long 	bra                                     		| 0x181
	.long 	bra                                     		| 0x182
	.long 	bra                                     		| 0x183
	.long 	bsr                                     		| 0x184
	.long 	bsr                                     		| 0x185
	.long 	bsr                                     		| 0x186
	.long 	bsr                                     		| 0x187
	.long 	bcc_hi                                  		| 0x188
	.long 	bcc_hi                                  		| 0x189
	.long 	bcc_hi                                  		| 0x18a
	.long 	bcc_hi                                  		| 0x18b
	.long 	bcc_ls                                  		| 0x18c
	.long 	bcc_ls                                  		| 0x18d
	.long 	bcc_ls                                  		| 0x18e
	.long 	bcc_ls                                  		| 0x18f
	.long 	bcc_cc                                  		| 0x190
	.long 	bcc_cc                                  		| 0x191
	.long 	bcc_cc                                  		| 0x192
	.long 	bcc_cc                                  		| 0x193
	.long 	bcc_cs                                  		| 0x194
	.long 	bcc_cs                                  		| 0x195
	.long 	bcc_cs                                  		| 0x196
	.long 	bcc_cs                                  		| 0x197
	.long 	bcc_ne                                  		| 0x198
	.long 	bcc_ne                                  		| 0x199
	.long 	bcc_ne                                  		| 0x19a
	.long 	bcc_ne                                  		| 0x19b
	.long 	bcc_eq                                  		| 0x19c
	.long 	bcc_eq                                  		| 0x19d
	.long 	bcc_eq                                  		| 0x19e
	.long 	bcc_eq                                  		| 0x19f
	.long 	bcc_vc                                  		| 0x1a0
	.long 	bcc_vc                                  		| 0x1a1
	.long 	bcc_vc                                  		| 0x1a2
	.long 	bcc_vc                                  		| 0x1a3
	.long 	bcc_vs                                  		| 0x1a4
	.long 	bcc_vs                                  		| 0x1a5
	.long 	bcc_vs                                  		| 0x1a6
	.long 	bcc_vs                                  		| 0x1a7
	.long 	bcc_pl                                  		| 0x1a8
	.long 	bcc_pl                                  		| 0x1a9
	.long 	bcc_pl                                  		| 0x1aa
	.long 	bcc_pl                                  		| 0x1ab
	.long 	bcc_mi                                  		| 0x1ac
	.long 	bcc_mi                                  		| 0x1ad
	.long 	bcc_mi                                  		| 0x1ae
	.long 	bcc_mi                                  		| 0x1af
	.long 	bcc_ge                                  		| 0x1b0
	.long 	bcc_ge                                  		| 0x1b1
	.long 	bcc_ge                                  		| 0x1b2
	.long 	bcc_ge                                  		| 0x1b3
	.long 	bcc_lt                                  		| 0x1b4
	.long 	bcc_lt                                  		| 0x1b5
	.long 	bcc_lt                                  		| 0x1b6
	.long 	bcc_lt                                  		| 0x1b7
	.long 	bcc_gt                                  		| 0x1b8
	.long 	bcc_gt                                  		| 0x1b9
	.long 	bcc_gt                                  		| 0x1ba
	.long 	bcc_gt                                  		| 0x1bb
	.long 	bcc_le                                  		| 0x1bc
	.long 	bcc_le                                  		| 0x1bd
	.long 	bcc_le                                  		| 0x1be
	.long 	bcc_le                                  		| 0x1bf
	.long 	moveq_D0                                		| 0x1c0
	.long 	moveq_D0                                		| 0x1c1
	.long 	moveq_D0                                		| 0x1c2
	.long 	moveq_D0                                		| 0x1c3
	.long 	illegal                                 		| 0x1c4
	.long 	illegal                                 		| 0x1c5
	.long 	illegal                                 		| 0x1c6
	.long 	illegal                                 		| 0x1c7
	.long 	moveq_D1                                		| 0x1c8
	.long 	moveq_D1                                		| 0x1c9
	.long 	moveq_D1                                		| 0x1ca
	.long 	moveq_D1                                		| 0x1cb
	.long 	illegal                                 		| 0x1cc
	.long 	illegal                                 		| 0x1cd
	.long 	illegal                                 		| 0x1ce
	.long 	illegal                                 		| 0x1cf
	.long 	moveq_D2                                		| 0x1d0
	.long 	moveq_D2                                		| 0x1d1
	.long 	moveq_D2                                		| 0x1d2
	.long 	moveq_D2                                		| 0x1d3
	.long 	illegal                                 		| 0x1d4
	.long 	illegal                                 		| 0x1d5
	.long 	illegal                                 		| 0x1d6
	.long 	illegal                                 		| 0x1d7
	.long 	moveq_D3                                		| 0x1d8
	.long 	moveq_D3                                		| 0x1d9
	.long 	moveq_D3                                		| 0x1da
	.long 	moveq_D3                                		| 0x1db
	.long 	illegal                                 		| 0x1dc
	.long 	illegal                                 		| 0x1dd
	.long 	illegal                                 		| 0x1de
	.long 	illegal                                 		| 0x1df
	.long 	moveq_D4                                		| 0x1e0
	.long 	moveq_D4                                		| 0x1e1
	.long 	moveq_D4                                		| 0x1e2
	.long 	moveq_D4                                		| 0x1e3
	.long 	illegal                                 		| 0x1e4
	.long 	illegal                                 		| 0x1e5
	.long 	illegal                                 		| 0x1e6
	.long 	illegal                                 		| 0x1e7
	.long 	moveq_D5                                		| 0x1e8
	.long 	moveq_D5                                		| 0x1e9
	.long 	moveq_D5                                		| 0x1ea
	.long 	moveq_D5                                		| 0x1eb
	.long 	illegal                                 		| 0x1ec
	.long 	illegal                                 		| 0x1ed
	.long 	illegal                                 		| 0x1ee
	.long 	illegal                                 		| 0x1ef
	.long 	moveq_D6                                		| 0x1f0
	.long 	moveq_D6                                		| 0x1f1
	.long 	moveq_D6                                		| 0x1f2
	.long 	moveq_D6                                		| 0x1f3
	.long 	illegal                                 		| 0x1f4
	.long 	illegal                                 		| 0x1f5
	.long 	illegal                                 		| 0x1f6
	.long 	illegal                                 		| 0x1f7
	.long 	moveq_D7                                		| 0x1f8
	.long 	moveq_D7                                		| 0x1f9
	.long 	moveq_D7                                		| 0x1fa
	.long 	moveq_D7                                		| 0x1fb
	.long 	illegal                                 		| 0x1fc
	.long 	illegal                                 		| 0x1fd
	.long 	illegal                                 		| 0x1fe
	.long 	illegal                                 		| 0x1ff
	.long 	or_byte_ea_to_D0                        		| 0x200
	.long 	or_word_ea_to_D0                        		| 0x201
	.long 	or_long_ea_to_D0                        		| 0x202
	.long 	divu_word                               		| 0x203
	.long 	second_level_dispatch_516               		| 0x204
	.long 	second_level_dispatch_517               		| 0x205
	.long 	second_level_dispatch_518               		| 0x206
	.long 	divs_word                               		| 0x207
	.long 	or_byte_ea_to_D1                        		| 0x208
	.long 	or_word_ea_to_D1                        		| 0x209
	.long 	or_long_ea_to_D1                        		| 0x20a
	.long 	divu_word                               		| 0x20b
	.long 	second_level_dispatch_524               		| 0x20c
	.long 	second_level_dispatch_525               		| 0x20d
	.long 	second_level_dispatch_526               		| 0x20e
	.long 	divs_word                               		| 0x20f
	.long 	or_byte_ea_to_D2                        		| 0x210
	.long 	or_word_ea_to_D2                        		| 0x211
	.long 	or_long_ea_to_D2                        		| 0x212
	.long 	divu_word                               		| 0x213
	.long 	second_level_dispatch_532               		| 0x214
	.long 	second_level_dispatch_533               		| 0x215
	.long 	second_level_dispatch_534               		| 0x216
	.long 	divs_word                               		| 0x217
	.long 	or_byte_ea_to_D3                        		| 0x218
	.long 	or_word_ea_to_D3                        		| 0x219
	.long 	or_long_ea_to_D3                        		| 0x21a
	.long 	divu_word                               		| 0x21b
	.long 	second_level_dispatch_540               		| 0x21c
	.long 	second_level_dispatch_541               		| 0x21d
	.long 	second_level_dispatch_542               		| 0x21e
	.long 	divs_word                               		| 0x21f
	.long 	or_byte_ea_to_D4                        		| 0x220
	.long 	or_word_ea_to_D4                        		| 0x221
	.long 	or_long_ea_to_D4                        		| 0x222
	.long 	divu_word                               		| 0x223
	.long 	second_level_dispatch_548               		| 0x224
	.long 	second_level_dispatch_549               		| 0x225
	.long 	second_level_dispatch_550               		| 0x226
	.long 	divs_word                               		| 0x227
	.long 	or_byte_ea_to_D5                        		| 0x228
	.long 	or_word_ea_to_D5                        		| 0x229
	.long 	or_long_ea_to_D5                        		| 0x22a
	.long 	divu_word                               		| 0x22b
	.long 	second_level_dispatch_556               		| 0x22c
	.long 	second_level_dispatch_557               		| 0x22d
	.long 	second_level_dispatch_558               		| 0x22e
	.long 	divs_word                               		| 0x22f
	.long 	or_byte_ea_to_D6                        		| 0x230
	.long 	or_word_ea_to_D6                        		| 0x231
	.long 	or_long_ea_to_D6                        		| 0x232
	.long 	divu_word                               		| 0x233
	.long 	second_level_dispatch_564               		| 0x234
	.long 	second_level_dispatch_565               		| 0x235
	.long 	second_level_dispatch_566               		| 0x236
	.long 	divs_word                               		| 0x237
	.long 	or_byte_ea_to_D7                        		| 0x238
	.long 	or_word_ea_to_D7                        		| 0x239
	.long 	or_long_ea_to_D7                        		| 0x23a
	.long 	divu_word                               		| 0x23b
	.long 	second_level_dispatch_572               		| 0x23c
	.long 	second_level_dispatch_573               		| 0x23d
	.long 	second_level_dispatch_574               		| 0x23e
	.long 	divs_word                               		| 0x23f
	.long 	sub_byte_ea_from_D0                     		| 0x240
	.long 	sub_word_ea_from_D0                     		| 0x241
	.long 	sub_long_ea_from_D0                     		| 0x242
	.long 	suba_word_ea_from_A0                    		| 0x243
	.long 	second_level_dispatch_580               		| 0x244
	.long 	second_level_dispatch_581               		| 0x245
	.long 	second_level_dispatch_582               		| 0x246
	.long 	suba_long_ea_from_A0                    		| 0x247
	.long 	sub_byte_ea_from_D1                     		| 0x248
	.long 	sub_word_ea_from_D1                     		| 0x249
	.long 	sub_long_ea_from_D1                     		| 0x24a
	.long 	suba_word_ea_from_A1                    		| 0x24b
	.long 	second_level_dispatch_588               		| 0x24c
	.long 	second_level_dispatch_589               		| 0x24d
	.long 	second_level_dispatch_590               		| 0x24e
	.long 	suba_long_ea_from_A1                    		| 0x24f
	.long 	sub_byte_ea_from_D2                     		| 0x250
	.long 	sub_word_ea_from_D2                     		| 0x251
	.long 	sub_long_ea_from_D2                     		| 0x252
	.long 	suba_word_ea_from_A2                    		| 0x253
	.long 	second_level_dispatch_596               		| 0x254
	.long 	second_level_dispatch_597               		| 0x255
	.long 	second_level_dispatch_598               		| 0x256
	.long 	suba_long_ea_from_A2                    		| 0x257
	.long 	sub_byte_ea_from_D3                     		| 0x258
	.long 	sub_word_ea_from_D3                     		| 0x259
	.long 	sub_long_ea_from_D3                     		| 0x25a
	.long 	suba_word_ea_from_A3                    		| 0x25b
	.long 	second_level_dispatch_604               		| 0x25c
	.long 	second_level_dispatch_605               		| 0x25d
	.long 	second_level_dispatch_606               		| 0x25e
	.long 	suba_long_ea_from_A3                    		| 0x25f
	.long 	sub_byte_ea_from_D4                     		| 0x260
	.long 	sub_word_ea_from_D4                     		| 0x261
	.long 	sub_long_ea_from_D4                     		| 0x262
	.long 	suba_word_ea_from_A4                    		| 0x263
	.long 	second_level_dispatch_612               		| 0x264
	.long 	second_level_dispatch_613               		| 0x265
	.long 	second_level_dispatch_614               		| 0x266
	.long 	suba_long_ea_from_A4                    		| 0x267
	.long 	sub_byte_ea_from_D5                     		| 0x268
	.long 	sub_word_ea_from_D5                     		| 0x269
	.long 	sub_long_ea_from_D5                     		| 0x26a
	.long 	suba_word_ea_from_A5                    		| 0x26b
	.long 	second_level_dispatch_620               		| 0x26c
	.long 	second_level_dispatch_621               		| 0x26d
	.long 	second_level_dispatch_622               		| 0x26e
	.long 	suba_long_ea_from_A5                    		| 0x26f
	.long 	sub_byte_ea_from_D6                     		| 0x270
	.long 	sub_word_ea_from_D6                     		| 0x271
	.long 	sub_long_ea_from_D6                     		| 0x272
	.long 	suba_word_ea_from_A6                    		| 0x273
	.long 	second_level_dispatch_628               		| 0x274
	.long 	second_level_dispatch_629               		| 0x275
	.long 	second_level_dispatch_630               		| 0x276
	.long 	suba_long_ea_from_A6                    		| 0x277
	.long 	sub_byte_ea_from_D7                     		| 0x278
	.long 	sub_word_ea_from_D7                     		| 0x279
	.long 	sub_long_ea_from_D7                     		| 0x27a
	.long 	suba_word_ea_from_A7                    		| 0x27b
	.long 	second_level_dispatch_636               		| 0x27c
	.long 	second_level_dispatch_637               		| 0x27d
	.long 	second_level_dispatch_638               		| 0x27e
	.long 	suba_long_ea_from_A7                    		| 0x27f
	.long 	illegal_A_line                          		| 0x280
	.long 	illegal_A_line                          		| 0x281
	.long 	illegal_A_line                          		| 0x282
	.long 	illegal_A_line                          		| 0x283
	.long 	illegal_A_line                          		| 0x284
	.long 	illegal_A_line                          		| 0x285
	.long 	illegal_A_line                          		| 0x286
	.long 	illegal_A_line                          		| 0x287
	.long 	illegal_A_line                          		| 0x288
	.long 	illegal_A_line                          		| 0x289
	.long 	illegal_A_line                          		| 0x28a
	.long 	illegal_A_line                          		| 0x28b
	.long 	illegal_A_line                          		| 0x28c
	.long 	illegal_A_line                          		| 0x28d
	.long 	illegal_A_line                          		| 0x28e
	.long 	illegal_A_line                          		| 0x28f
	.long 	illegal_A_line                          		| 0x290
	.long 	illegal_A_line                          		| 0x291
	.long 	illegal_A_line                          		| 0x292
	.long 	illegal_A_line                          		| 0x293
	.long 	illegal_A_line                          		| 0x294
	.long 	illegal_A_line                          		| 0x295
	.long 	illegal_A_line                          		| 0x296
	.long 	illegal_A_line                          		| 0x297
	.long 	illegal_A_line                          		| 0x298
	.long 	illegal_A_line                          		| 0x299
	.long 	illegal_A_line                          		| 0x29a
	.long 	illegal_A_line                          		| 0x29b
	.long 	illegal_A_line                          		| 0x29c
	.long 	illegal_A_line                          		| 0x29d
	.long 	illegal_A_line                          		| 0x29e
	.long 	illegal_A_line                          		| 0x29f
	.long 	illegal_A_line                          		| 0x2a0
	.long 	illegal_A_line                          		| 0x2a1
	.long 	illegal_A_line                          		| 0x2a2
	.long 	illegal_A_line                          		| 0x2a3
	.long 	illegal_A_line                          		| 0x2a4
	.long 	illegal_A_line                          		| 0x2a5
	.long 	illegal_A_line                          		| 0x2a6
	.long 	illegal_A_line                          		| 0x2a7
	.long 	illegal_A_line                          		| 0x2a8
	.long 	illegal_A_line                          		| 0x2a9
	.long 	illegal_A_line                          		| 0x2aa
	.long 	illegal_A_line                          		| 0x2ab
	.long 	illegal_A_line                          		| 0x2ac
	.long 	illegal_A_line                          		| 0x2ad
	.long 	illegal_A_line                          		| 0x2ae
	.long 	illegal_A_line                          		| 0x2af
	.long 	illegal_A_line                          		| 0x2b0
	.long 	illegal_A_line                          		| 0x2b1
	.long 	illegal_A_line                          		| 0x2b2
	.long 	illegal_A_line                          		| 0x2b3
	.long 	illegal_A_line                          		| 0x2b4
	.long 	illegal_A_line                          		| 0x2b5
	.long 	illegal_A_line                          		| 0x2b6
	.long 	illegal_A_line                          		| 0x2b7
	.long 	illegal_A_line                          		| 0x2b8
	.long 	illegal_A_line                          		| 0x2b9
	.long 	illegal_A_line                          		| 0x2ba
	.long 	illegal_A_line                          		| 0x2bb
	.long 	illegal_A_line                          		| 0x2bc
	.long 	illegal_A_line                          		| 0x2bd
	.long 	illegal_A_line                          		| 0x2be
	.long 	illegal_A_line                          		| 0x2bf
	.long 	cmp_byte_ea_to_D0                       		| 0x2c0
	.long 	cmp_word_ea_to_D0                       		| 0x2c1
	.long 	cmp_long_ea_to_D0                       		| 0x2c2
	.long 	cmpa_word_ea_to_A0                      		| 0x2c3
	.long 	second_level_dispatch_708               		| 0x2c4
	.long 	second_level_dispatch_709               		| 0x2c5
	.long 	second_level_dispatch_710               		| 0x2c6
	.long 	cmpa_long_ea_to_A0                      		| 0x2c7
	.long 	cmp_byte_ea_to_D1                       		| 0x2c8
	.long 	cmp_word_ea_to_D1                       		| 0x2c9
	.long 	cmp_long_ea_to_D1                       		| 0x2ca
	.long 	cmpa_word_ea_to_A1                      		| 0x2cb
	.long 	second_level_dispatch_716               		| 0x2cc
	.long 	second_level_dispatch_717               		| 0x2cd
	.long 	second_level_dispatch_718               		| 0x2ce
	.long 	cmpa_long_ea_to_A1                      		| 0x2cf
	.long 	cmp_byte_ea_to_D2                       		| 0x2d0
	.long 	cmp_word_ea_to_D2                       		| 0x2d1
	.long 	cmp_long_ea_to_D2                       		| 0x2d2
	.long 	cmpa_word_ea_to_A2                      		| 0x2d3
	.long 	second_level_dispatch_724               		| 0x2d4
	.long 	second_level_dispatch_725               		| 0x2d5
	.long 	second_level_dispatch_726               		| 0x2d6
	.long 	cmpa_long_ea_to_A2                      		| 0x2d7
	.long 	cmp_byte_ea_to_D3                       		| 0x2d8
	.long 	cmp_word_ea_to_D3                       		| 0x2d9
	.long 	cmp_long_ea_to_D3                       		| 0x2da
	.long 	cmpa_word_ea_to_A3                      		| 0x2db
	.long 	second_level_dispatch_732               		| 0x2dc
	.long 	second_level_dispatch_733               		| 0x2dd
	.long 	second_level_dispatch_734               		| 0x2de
	.long 	cmpa_long_ea_to_A3                      		| 0x2df
	.long 	cmp_byte_ea_to_D4                       		| 0x2e0
	.long 	cmp_word_ea_to_D4                       		| 0x2e1
	.long 	cmp_long_ea_to_D4                       		| 0x2e2
	.long 	cmpa_word_ea_to_A4                      		| 0x2e3
	.long 	second_level_dispatch_740               		| 0x2e4
	.long 	second_level_dispatch_741               		| 0x2e5
	.long 	second_level_dispatch_742               		| 0x2e6
	.long 	cmpa_long_ea_to_A4                      		| 0x2e7
	.long 	cmp_byte_ea_to_D5                       		| 0x2e8
	.long 	cmp_word_ea_to_D5                       		| 0x2e9
	.long 	cmp_long_ea_to_D5                       		| 0x2ea
	.long 	cmpa_word_ea_to_A5                      		| 0x2eb
	.long 	second_level_dispatch_748               		| 0x2ec
	.long 	second_level_dispatch_749               		| 0x2ed
	.long 	second_level_dispatch_750               		| 0x2ee
	.long 	cmpa_long_ea_to_A5                      		| 0x2ef
	.long 	cmp_byte_ea_to_D6                       		| 0x2f0
	.long 	cmp_word_ea_to_D6                       		| 0x2f1
	.long 	cmp_long_ea_to_D6                       		| 0x2f2
	.long 	cmpa_word_ea_to_A6                      		| 0x2f3
	.long 	second_level_dispatch_756               		| 0x2f4
	.long 	second_level_dispatch_757               		| 0x2f5
	.long 	second_level_dispatch_758               		| 0x2f6
	.long 	cmpa_long_ea_to_A6                      		| 0x2f7
	.long 	cmp_byte_ea_to_D7                       		| 0x2f8
	.long 	cmp_word_ea_to_D7                       		| 0x2f9
	.long 	cmp_long_ea_to_D7                       		| 0x2fa
	.long 	cmpa_word_ea_to_A7                      		| 0x2fb
	.long 	second_level_dispatch_764               		| 0x2fc
	.long 	second_level_dispatch_765               		| 0x2fd
	.long 	second_level_dispatch_766               		| 0x2fe
	.long 	cmpa_long_ea_to_A7                      		| 0x2ff
	.long 	and_byte_ea_to_D0                       		| 0x300
	.long 	and_word_ea_to_D0                       		| 0x301
	.long 	and_long_ea_to_D0                       		| 0x302
	.long 	mulu_word                               		| 0x303
	.long 	second_level_dispatch_772               		| 0x304
	.long 	second_level_dispatch_773               		| 0x305
	.long 	second_level_dispatch_774               		| 0x306
	.long 	muls_word                               		| 0x307
	.long 	and_byte_ea_to_D1                       		| 0x308
	.long 	and_word_ea_to_D1                       		| 0x309
	.long 	and_long_ea_to_D1                       		| 0x30a
	.long 	mulu_word                               		| 0x30b
	.long 	second_level_dispatch_780               		| 0x30c
	.long 	second_level_dispatch_781               		| 0x30d
	.long 	second_level_dispatch_782               		| 0x30e
	.long 	muls_word                               		| 0x30f
	.long 	and_byte_ea_to_D2                       		| 0x310
	.long 	and_word_ea_to_D2                       		| 0x311
	.long 	and_long_ea_to_D2                       		| 0x312
	.long 	mulu_word                               		| 0x313
	.long 	second_level_dispatch_788               		| 0x314
	.long 	second_level_dispatch_789               		| 0x315
	.long 	second_level_dispatch_790               		| 0x316
	.long 	muls_word                               		| 0x317
	.long 	and_byte_ea_to_D3                       		| 0x318
	.long 	and_word_ea_to_D3                       		| 0x319
	.long 	and_long_ea_to_D3                       		| 0x31a
	.long 	mulu_word                               		| 0x31b
	.long 	second_level_dispatch_796               		| 0x31c
	.long 	second_level_dispatch_797               		| 0x31d
	.long 	second_level_dispatch_798               		| 0x31e
	.long 	muls_word                               		| 0x31f
	.long 	and_byte_ea_to_D4                       		| 0x320
	.long 	and_word_ea_to_D4                       		| 0x321
	.long 	and_long_ea_to_D4                       		| 0x322
	.long 	mulu_word                               		| 0x323
	.long 	second_level_dispatch_804               		| 0x324
	.long 	second_level_dispatch_805               		| 0x325
	.long 	second_level_dispatch_806               		| 0x326
	.long 	muls_word                               		| 0x327
	.long 	and_byte_ea_to_D5                       		| 0x328
	.long 	and_word_ea_to_D5                       		| 0x329
	.long 	and_long_ea_to_D5                       		| 0x32a
	.long 	mulu_word                               		| 0x32b
	.long 	second_level_dispatch_812               		| 0x32c
	.long 	second_level_dispatch_813               		| 0x32d
	.long 	second_level_dispatch_814               		| 0x32e
	.long 	muls_word                               		| 0x32f
	.long 	and_byte_ea_to_D6                       		| 0x330
	.long 	and_word_ea_to_D6                       		| 0x331
	.long 	and_long_ea_to_D6                       		| 0x332
	.long 	mulu_word                               		| 0x333
	.long 	second_level_dispatch_820               		| 0x334
	.long 	second_level_dispatch_821               		| 0x335
	.long 	second_level_dispatch_822               		| 0x336
	.long 	muls_word                               		| 0x337
	.long 	and_byte_ea_to_D7                       		| 0x338
	.long 	and_word_ea_to_D7                       		| 0x339
	.long 	and_long_ea_to_D7                       		| 0x33a
	.long 	mulu_word                               		| 0x33b
	.long 	second_level_dispatch_828               		| 0x33c
	.long 	second_level_dispatch_829               		| 0x33d
	.long 	second_level_dispatch_830               		| 0x33e
	.long 	muls_word                               		| 0x33f
	.long 	add_byte_ea_to_D0                       		| 0x340
	.long 	add_word_ea_to_D0                       		| 0x341
	.long 	add_long_ea_to_D0                       		| 0x342
	.long 	adda_word_ea_to_A0                      		| 0x343
	.long 	second_level_dispatch_836               		| 0x344
	.long 	second_level_dispatch_837               		| 0x345
	.long 	second_level_dispatch_838               		| 0x346
	.long 	adda_long_ea_to_A0                      		| 0x347
	.long 	add_byte_ea_to_D1                       		| 0x348
	.long 	add_word_ea_to_D1                       		| 0x349
	.long 	add_long_ea_to_D1                       		| 0x34a
	.long 	adda_word_ea_to_A1                      		| 0x34b
	.long 	second_level_dispatch_844               		| 0x34c
	.long 	second_level_dispatch_845               		| 0x34d
	.long 	second_level_dispatch_846               		| 0x34e
	.long 	adda_long_ea_to_A1                      		| 0x34f
	.long 	add_byte_ea_to_D2                       		| 0x350
	.long 	add_word_ea_to_D2                       		| 0x351
	.long 	add_long_ea_to_D2                       		| 0x352
	.long 	adda_word_ea_to_A2                      		| 0x353
	.long 	second_level_dispatch_852               		| 0x354
	.long 	second_level_dispatch_853               		| 0x355
	.long 	second_level_dispatch_854               		| 0x356
	.long 	adda_long_ea_to_A2                      		| 0x357
	.long 	add_byte_ea_to_D3                       		| 0x358
	.long 	add_word_ea_to_D3                       		| 0x359
	.long 	add_long_ea_to_D3                       		| 0x35a
	.long 	adda_word_ea_to_A3                      		| 0x35b
	.long 	second_level_dispatch_860               		| 0x35c
	.long 	second_level_dispatch_861               		| 0x35d
	.long 	second_level_dispatch_862               		| 0x35e
	.long 	adda_long_ea_to_A3                      		| 0x35f
	.long 	add_byte_ea_to_D4                       		| 0x360
	.long 	add_word_ea_to_D4                       		| 0x361
	.long 	add_long_ea_to_D4                       		| 0x362
	.long 	adda_word_ea_to_A4                      		| 0x363
	.long 	second_level_dispatch_868               		| 0x364
	.long 	second_level_dispatch_869               		| 0x365
	.long 	second_level_dispatch_870               		| 0x366
	.long 	adda_long_ea_to_A4                      		| 0x367
	.long 	add_byte_ea_to_D5                       		| 0x368
	.long 	add_word_ea_to_D5                       		| 0x369
	.long 	add_long_ea_to_D5                       		| 0x36a
	.long 	adda_word_ea_to_A5                      		| 0x36b
	.long 	second_level_dispatch_876               		| 0x36c
	.long 	second_level_dispatch_877               		| 0x36d
	.long 	second_level_dispatch_878               		| 0x36e
	.long 	adda_long_ea_to_A5                      		| 0x36f
	.long 	add_byte_ea_to_D6                       		| 0x370
	.long 	add_word_ea_to_D6                       		| 0x371
	.long 	add_long_ea_to_D6                       		| 0x372
	.long 	adda_word_ea_to_A6                      		| 0x373
	.long 	second_level_dispatch_884               		| 0x374
	.long 	second_level_dispatch_885               		| 0x375
	.long 	second_level_dispatch_886               		| 0x376
	.long 	adda_long_ea_to_A6                      		| 0x377
	.long 	add_byte_ea_to_D7                       		| 0x378
	.long 	add_word_ea_to_D7                       		| 0x379
	.long 	add_long_ea_to_D7                       		| 0x37a
	.long 	adda_word_ea_to_A7                      		| 0x37b
	.long 	second_level_dispatch_892               		| 0x37c
	.long 	second_level_dispatch_893               		| 0x37d
	.long 	second_level_dispatch_894               		| 0x37e
	.long 	adda_long_ea_to_A7                      		| 0x37f
	.long 	shift_and_rotate_right_byte_0           		| 0x380
	.long 	shift_and_rotate_right_word_0           		| 0x381
	.long 	shift_and_rotate_right_long_0           		| 0x382
	.long 	asr_memory                              		| 0x383
	.long 	shift_and_rotate_left_byte_0            		| 0x384
	.long 	shift_and_rotate_left_word_0            		| 0x385
	.long 	shift_and_rotate_left_long_0            		| 0x386
	.long 	asl_memory                              		| 0x387
	.long 	shift_and_rotate_right_byte_1           		| 0x388
	.long 	shift_and_rotate_right_word_1           		| 0x389
	.long 	shift_and_rotate_right_long_1           		| 0x38a
	.long 	lsr_memory                              		| 0x38b
	.long 	shift_and_rotate_left_byte_1            		| 0x38c
	.long 	shift_and_rotate_left_word_1            		| 0x38d
	.long 	shift_and_rotate_left_long_1            		| 0x38e
	.long 	lsl_memory                              		| 0x38f
	.long 	shift_and_rotate_right_byte_2           		| 0x390
	.long 	shift_and_rotate_right_word_2           		| 0x391
	.long 	shift_and_rotate_right_long_2           		| 0x392
	.long 	roxr_memory                             		| 0x393
	.long 	shift_and_rotate_left_byte_2            		| 0x394
	.long 	shift_and_rotate_left_word_2            		| 0x395
	.long 	shift_and_rotate_left_long_2            		| 0x396
	.long 	roxl_memory                             		| 0x397
	.long 	shift_and_rotate_right_byte_3           		| 0x398
	.long 	shift_and_rotate_right_word_3           		| 0x399
	.long 	shift_and_rotate_right_long_3           		| 0x39a
	.long 	ror_memory                              		| 0x39b
	.long 	shift_and_rotate_left_byte_3            		| 0x39c
	.long 	shift_and_rotate_left_word_3            		| 0x39d
	.long 	shift_and_rotate_left_long_3            		| 0x39e
	.long 	rol_memory                              		| 0x39f
	.long 	shift_and_rotate_right_byte_4           		| 0x3a0
	.long 	shift_and_rotate_right_word_4           		| 0x3a1
	.long 	shift_and_rotate_right_long_4           		| 0x3a2
	.long 	second_level_dispatch_931               		| 0x3a3
	.long 	shift_and_rotate_left_byte_4            		| 0x3a4
	.long 	shift_and_rotate_left_word_4            		| 0x3a5
	.long 	shift_and_rotate_left_long_4            		| 0x3a6
	.long 	second_level_dispatch_935               		| 0x3a7
	.long 	shift_and_rotate_right_byte_5           		| 0x3a8
	.long 	shift_and_rotate_right_word_5           		| 0x3a9
	.long 	shift_and_rotate_right_long_5           		| 0x3aa
	.long 	second_level_dispatch_939               		| 0x3ab
	.long 	shift_and_rotate_left_byte_5            		| 0x3ac
	.long 	shift_and_rotate_left_word_5            		| 0x3ad
	.long 	shift_and_rotate_left_long_5            		| 0x3ae
	.long 	second_level_dispatch_943               		| 0x3af
	.long 	shift_and_rotate_right_byte_6           		| 0x3b0
	.long 	shift_and_rotate_right_word_6           		| 0x3b1
	.long 	shift_and_rotate_right_long_6           		| 0x3b2
	.long 	second_level_dispatch_947               		| 0x3b3
	.long 	shift_and_rotate_left_byte_6            		| 0x3b4
	.long 	shift_and_rotate_left_word_6            		| 0x3b5
	.long 	shift_and_rotate_left_long_6            		| 0x3b6
	.long 	second_level_dispatch_951               		| 0x3b7
	.long 	shift_and_rotate_right_byte_7           		| 0x3b8
	.long 	shift_and_rotate_right_word_7           		| 0x3b9
	.long 	shift_and_rotate_right_long_7           		| 0x3ba
	.long 	second_level_dispatch_955               		| 0x3bb
	.long 	shift_and_rotate_left_byte_7            		| 0x3bc
	.long 	shift_and_rotate_left_word_7            		| 0x3bd
	.long 	shift_and_rotate_left_long_7            		| 0x3be
	.long 	second_level_dispatch_959               		| 0x3bf
	.long 	illegal_F_line                          		| 0x3c0
	.long 	illegal_F_line                          		| 0x3c1
	.long 	illegal_F_line                          		| 0x3c2
	.long 	illegal_F_line                          		| 0x3c3
	.long 	illegal_F_line                          		| 0x3c4
	.long 	illegal_F_line                          		| 0x3c5
	.long 	illegal_F_line                          		| 0x3c6
	.long 	illegal_F_line                          		| 0x3c7
	.long 	illegal_F_line                          		| 0x3c8
	.long 	illegal_F_line                          		| 0x3c9
	.long 	illegal_F_line                          		| 0x3ca
	.long 	illegal_F_line                          		| 0x3cb
	.long 	illegal_F_line                          		| 0x3cc
	.long 	illegal_F_line                          		| 0x3cd
	.long 	illegal_F_line                          		| 0x3ce
	.long 	illegal_F_line                          		| 0x3cf
	.long 	illegal_F_line                          		| 0x3d0
	.long 	illegal_F_line                          		| 0x3d1
	.long 	illegal_F_line                          		| 0x3d2
	.long 	illegal_F_line                          		| 0x3d3
	.long 	illegal_F_line                          		| 0x3d4
	.long 	illegal_F_line                          		| 0x3d5
	.long 	illegal_F_line                          		| 0x3d6
	.long 	illegal_F_line                          		| 0x3d7
	.long 	second_level_dispatch_984               		| 0x3d8
	.long 	illegal_F_line                          		| 0x3d9
	.long 	illegal_F_line                          		| 0x3da
	.long 	illegal_F_line                          		| 0x3db
	.long 	illegal_F_line                          		| 0x3dc
	.long 	illegal_F_line                          		| 0x3dd
	.long 	illegal_F_line                          		| 0x3de
	.long 	illegal_F_line                          		| 0x3df
	.long 	illegal_F_line                          		| 0x3e0
	.long 	illegal_F_line                          		| 0x3e1
	.long 	illegal_F_line                          		| 0x3e2
	.long 	illegal_F_line                          		| 0x3e3
	.long 	illegal_F_line                          		| 0x3e4
	.long 	illegal_F_line                          		| 0x3e5
	.long 	illegal_F_line                          		| 0x3e6
	.long 	illegal_F_line                          		| 0x3e7
	.long 	illegal_F_line                          		| 0x3e8
	.long 	illegal_F_line                          		| 0x3e9
	.long 	illegal_F_line                          		| 0x3ea
	.long 	illegal_F_line                          		| 0x3eb
	.long 	illegal_F_line                          		| 0x3ec
	.long 	illegal_F_line                          		| 0x3ed
	.long 	illegal_F_line                          		| 0x3ee
	.long 	illegal_F_line                          		| 0x3ef
	.long 	illegal_F_line                          		| 0x3f0
	.long 	illegal_F_line                          		| 0x3f1
	.long 	illegal_F_line                          		| 0x3f2
	.long 	illegal_F_line                          		| 0x3f3
	.long 	illegal_F_line                          		| 0x3f4
	.long 	illegal_F_line                          		| 0x3f5
	.long 	illegal_F_line                          		| 0x3f6
	.long 	illegal_F_line                          		| 0x3f7
	.long 	illegal_F_line                          		| 0x3f8
	.long 	illegal_F_line                          		| 0x3f9
	.long 	illegal_F_line                          		| 0x3fa
	.long 	illegal_F_line                          		| 0x3fb
	.long 	illegal_F_line                          		| 0x3fc
	.long 	illegal_F_line                          		| 0x3fd
	.long 	illegal_F_line                          		| 0x3fe
	.long 	illegal_F_line                          		| 0x3ff
