/*
 * rwa.s - GEMDOS assembler interface
 *
 * Copyright (c) 1999 by Caldera Inc.
 * Copyright (c) 1985, 2001 by Authors:
 *
 *  EWF  Eric W. Fleischman
 *  JSL  Jason S. Loveman
 *  SCC  Steven C. Cavender
 *  ACH  Anthony C. Hay
 *  MAD  Martin Doering
 *
 * This file is distributed under the GPL, version 2 or at your
 * option any later version.  See doc/license.txt for details.
 *
 */

//============================================================================
//
// Originally written by JSL.
//
// MODIFICATION HISTORY
//
//      11 Mar 85       SCC     Added xgetsup() functionality as a hack in
//                              _entry().
//                              Removed get sup functionality from exit().
//      11 Mar 85       JSL     Changed timer vector number.
//      12 Mar 85       SCC     Modified xgetsup() functionality in _entry().
//      13 Mar 85       SCC     Changed 'xgetsup()' type functionality to
//                              'toggle/inquire processor/stack state' type
//                              functionality.
//      25 Mar 85       SCC     Modified 'tikhnd:'.  It didn't need to save
//                              the registers it was saving.
//       1 Apr 85       SCC     Modified 'tikhnd:'.  It needed to get the
//                              number of milliseconds since last tick into
//                              the right place for the stack frame for call
//                              to tikfrk().
//      10 Apr 85       SCC     Modified longjmp() to use long return value
//                              on stack.
//      12 Apr 85       SCC     Modified exit() to check for function -1
//                              (return address of screen driver.
//      14 Apr 85       SCC     Modified osinit() to disable interrupts while
//                              initializing the tick vector.
//      19 Apr 85       SCC     Modified osinit() to preserve the previous
//                              state of the SR.
//      22 Apr 85       SCC     Modified the saving of SR to store it
//                              temporarily in a static.
//
//      31 May 85       EWF     Added in conditional assembly for 68010-based
//                              systems.
//
//      19 Jun 85       EWF     Added additional conditional assemblies for
//                              68010-based systems.
//
//       9 Aug 85       SCC     Modified osinit() to get tick vector from
//                              clock device handle.
//
//                              NOTE:   STACK LOOKS DIFFERENT THAT ATARI'S ON
//                                      INVOCATION OF TICK HANDLER!
//
//                              Modified tikhnd: to work with new clock format
//                              (tick value in long above long flag value on
//                              stack)
//
//      15 Aug 85       SCC     Modified tikhnd:.  It was picking up the
//                              number of milliseconds from the wrong location
//                              on the stack.
//
//      18 Aug 85       SCC     Added copyright message.
//
//       1 Nov 85       SCC     Converted to runtime determination of
//                              processor type (68000 v. 68010)
//
//                              Added 68010 'MOVE SR,...' to 'MOVE CCR,...'
//                              illegal instruction handler
//
//                              Converted all exception vector handling to
//                              use BIOS calls, rather than direct addresses.
//
//       4 Nov 85       SCC     Cleaned up a stack imbalance problem in
//                              'ii_handler'.  It was not POPing D0/A0 off
//                              the stack before going off to the OEM's
//                              Illegal Instruction handler.
//
//      11 Nov 85       KTB     put trap2 handler back in for the nonce
//
//      14 May 86       KTB     removed dojmp
//
//      02 Jul 86       KTB     M01.01a.0702.01 osinit now returns address of 
//                              date/time stamp for bdos
//
//      23 Jul 86       KTB     M01.01.0723.01 osinit needs to save stack ptr
//                              in some other reg besides d1.
//
//      24 Jul 86       KTB     M01.01.0724.01 osinit no longer returns addr
//                              of date/time stamp.  this is all handled in 
//                              startup.a
//
//      04 Aug 86       KTB     M01.01.0804.02 osinit => _osinit
//
//      28 Aug 86       SCC     M01.01.0828.01 changed TRAP #2 handler back
//                              similar to the way it was in the olden days
//                              for Atari's benefit in bringing up a system
//                              where the VDI and AES are already in memory.
//
//      19 May 87       ACH     The 68070 has an exception stack frame similar
//                              to the 68010 but it does not impliment the
//                              "move ccr,d0" instruction. Hence the 68000 vs.
//                              68010 detection would give the oposite result
//                              to the one desired. Force mc68010 flag to true.
//
//      19 Nov 87       ACH     Moved _lbmove, _bfill, _bmove into this module.
//
//============================================================================

#include "config.h"
#include "../../include/ct60.h"
#include "../../include/fire.h"
#include "../../include/vars.h"

//==== Global References =====================================================

        .global _termuser
        .global _gouser
        .global _oscall

        .global _enter
        .global _old_trap2
        .global _bdos_trap2
        
        .xdef   _osif
        .xdef   _xterm
        .xdef   _run
        .xdef   fstrt

        .global _xsuper
        
        .global _swp68w
        .global _swp68l
        
        .global _rwabs

        .global _slb_exec
        
        .global _flush_cache_pexec


#undef DEBUG

#ifdef NETWORK
#ifdef LWIP
        .global _xSemaphoreTakeBDOS,_xSemaphoreGiveBDOS
#endif
#endif

#ifdef COLDFIRE
#ifdef DEBUG
        .global display_string,display_char,hex_byte

        .data

debug1: .asciz "BDOS #0x
        .align 2
#endif
#endif

        .data

//==== bdos_trap2 - trap 2 entry point =======================================
//
// This minimal interface connects the entry point for a system where the AES
// and VDI are already in memory.
//

_bdos_trap2:                              
        tst.w   d0
        beq     oterm

        move.l  _old_trap2,-(sp)
        rts

oterm:  move.l  #fstrt,sp
        clr     -(sp)
        jsr     _xterm
        rte

//==== _enter - Front end of TRAP #1 handler =================================

_enter:
        bsr     fix_trap
        btst.b  #5,(sp)         // are we in supervisor mode?
        bne     enter_sup       // yes, go check sup stack
#ifdef COLDFIRE
        .chip 68060
        move.l  usp,a0          // no, check user stack
        .chip 5200
        moveq   #0,d0
        move.w  (a0),d0
#ifdef DEBUG
        move.l  D0,-(SP)
        move.l  A0,-(SP)
        lea     debug1,A0
        jsr     display_string
        move.l  (SP)+,A0
        jsr     hex_byte
        moveq   #13,D0
        jsr     display_char
        moveq   #10,D0
        jsr     display_char
        move.l  (SP)+,D0
#endif
        cmp.l   #0x20,d0
#else
        move.l  usp,a0          // no, check user stack
        cmp.w   #0x20,(a0)      // toggle/inquire state?
#endif
        beq     x20_usr         // yes, go perform function

        bra     enter_2

enter_sup:
                                // next line is 68000 specific
#ifdef COLDFIRE
        moveq   #0,d0
        move.w  6(sp),d0        // toggle/inquire state?
#ifdef DEBUG
        move.l  D0,-(SP)
        move.l  A0,-(SP)
        lea     debug1,A0
        jsr     display_string
        move.l  (SP)+,A0
        jsr     hex_byte
        moveq   #13,D0
        jsr     display_char
        moveq   #10,D0
        jsr     display_char
        move.l  (SP)+,D0
#endif
        cmp.l   #0x20,d0
#else        
        cmp.w   #0x20,6(sp)     // toggle/inquire state?
#endif
        beq     x20_sup         // yes, go perform function

enter_2:
        move.l  a6,-(sp)
        move.l  _run,a6
        movem.l d0/a3-a5,0x68(a6)
        move.l  (sp)+,0x78(a6)  // olda6
        move.w  (sp)+,d0        // status reg
        move.l  (sp)+,a4        // retadd
        btst    #13,d0          // if he is in system state, use his stack
        bne     systk
#ifdef COLDFIRE
       .chip 68060
        move.l  usp,a5
        .chip 5200
        lea     -40(a5),a5
        movem.l d1-d7/a0-a2,(a5)
#else
        move.l  usp,a5
        movem.l d1-d7/a0-a2,-(a5)
#endif
        move.l  a4,-(a5)        // retadd
        move.w  d0,-(a5)        // sr
        move.l  sp,a0
        move.l  a0,-(a5)
        move.l  a5,0x7c(a6)
// now switch to fs stack
        move.l  #fstrt,sp
        lea     50(a5),a0
        bra     callos
// he was using his own ssp
systk:
#ifdef COLDFIRE
        lea     -40(sp),sp
        movem.l d1-d7/a0-a2,(sp)
        move.l  a4,-(sp)
        move.w  d0,-(sp)
        .chip   68060
        move.l  usp,a0
        .chip   5200
#else
        movem.l d1-d7/a0-a2,-(sp)
        move.l  a4,-(sp)
        move.w  d0,-(sp)
        move.l  usp,a0
#endif
        move.l  a0,-(sp)
        move.l  sp,0x7c(a6)
        lea     50(sp),a0
        move.l  #fstrt,sp
callos: move.l  a0,-(sp)        // push parm pointer

        jsr     _osif
        add.l   #4,sp

//...fall into gouser....



//==== _gouser ===============================================================

_gouser:
        move.l  _run,a5
        move.l  d0,0x68(a5)
ggusr:  move.l  0x7c(a5),a6     // stack pointer (maybe usp, maybe ssp)
        move.l  (a6)+,a4        // other stack pointer
        move.w  (a6)+,d0
        move.l  (a6)+,a3        // retadd
#ifdef COLDFIRE
        movem.l (a6),d1-d7/a0-a2
        lea     40(a6),a6
#else
        movem.l (a6)+,d1-d7/a0-a2
#endif
        btst    #13,d0
        bne     retsys          // a6 is (user-supplied) system stack
        move.l  a4,sp
#ifdef COLDFIRE
        .chip   68060
        move.l  a6,usp
        .chip   5200
#else
        move.l  a6,usp
#endif
gousr:  move.l  a3,-(sp)
        move    d0,-(sp)
        movem.l 0x68(a5),d0/a3-a6

        bra     fix_rte

retsys: move.l  a6,sp
#ifdef COLDFIRE
        .chip   68060
        move.l  a4,usp
        .chip   5200
#else
        move.l  a4,usp
#endif
        bra     gousr
        
        // attempting to fix a problem where return codes provided by
        // xterm [ 0x4C ] aren't correctly passed back to the parent.
        // this is entered from C code as termuser()
        // aug 2005, RCL
_termuser:
        move.l  _run,a5
        bra     ggusr

//==== function 0x20 handler - toggle/inquire processor/stack state ==========

_xsuper:
x20_usr:                        // user mode entry point
        move.l  2(a0),d1        // get parameter
        beq     xu_0            // already have new SSP from
                                // old USP, go handle 0L entry

        subq.l  #1,d1           // check for +1L entry
        beq     x20_inq         // go handle inquiry

        move.l  2(a0),a0        // get new SSP from parameter
xu_0:
        move.w  (sp)+,d0        // pop SR
        move.l  (sp)+,-(a0)     // transport the return address
        ori.l   #0x2000,d0      // set supervisor mode
        move.w  d0,-(a0)        // push SR
        move.l  sp,d0           // set return value (old SSP)
        move.l  a0,sp           // set new SSP

        bra     fix_rte





// supervisor mode gemdos(20) entry point

x20_sup:
        move.l  8(sp),d1        // get parameter
        beq     xs_0            // go handle 0L entry

        subq.l  #1,d1           // check for +1L entry
        beq     x20_inq         // go handle inquiry

        move.l  8(sp),a1        // point to new SSP
        move.w  (sp)+,d0        // pop SR
        move.l  (sp)+,-(a1)     // transport the return address
        move.w  d0,-(a1)        // push SR
#ifdef COLDFIRE
        .chip   68060
        move.l  usp,a0          // get USP
        .chip   5200
#else
        move.l  usp,a0          // get USP
#endif
        cmpa.l  a0,sp           // already at old USP?
        beq     xs_usp          // don't play with stack

        move.l  (sp)+,-(a0)     // transport func # and parm
        move.l  a1,sp           // update SSP
        bra     xs_exit

xs_usp:
        move.l  a1,sp           // update SSP
        bra     xs_scram

xs_0:
        move.l  sp,a0           // create USP
        addq.l  #6,a0           // this is 68000 specific
xs_exit:
#ifdef COLDFIRE
        .chip   68060
        move.l  a0,usp          // update USP
        .chip   5200
xs_scram:
        move.l  d0,-(sp)
        move.w  4(sp),d0
        andi.l  #0xDFFF,d0      // set user mode
        move.w  d0,4(sp)
        move.l  (sp)+,d0
#else
        move.l  a0,usp          // update USP
xs_scram:
        andi.w  #0xDFFF,(sp)    // set user mode
#endif
        bra     fix_rte

// gemdos(20) inquiry mode entry point

x20_inq:
        moveq.l #0,d0           // return 0L for user mode
        btst.b  #5,(sp)         // supervisor mode?
        beq     xi_exit         // no, user mode
        subq.l  #1,d0           // return -1L for sup mode
xi_exit:
        bra     fix_rte

//==== call dosjr from within itself (or from linked-in shell) ===============

_oscall:
        link    a6,#0
        move.l  a0,-(sp)
        lea     8(a6),a0
        move.l  a0,-(sp)
        jsr     _osif
        addq.l  #4,sp
        move.l  (sp)+,a0
        unlk    a6
        rts

//==== fix_trap - make 68010 exception stack frame look like a 68000 frame ===

fix_trap:
#ifdef NETWORK
#ifdef LWIP
        lea     -24(sp),sp
        movem.l d0-d2/a0-a2,(sp)
        jsr     _xSemaphoreTakeBDOS
        movem.l (sp),d0-d2/a0-a2
        lea     24(sp),sp
#endif
#endif
        tst.w   proc_type       // check processor type
        beq     ft_exit

        move.w  8(sp),10(sp)    // lsw of return address of TRAP
        move.w  6(sp),8(sp)     // msw of return address of TRAP
        move.w  4(sp),6(sp)     // sr
        move.w  2(sp),4(sp)     // lsw of return address of BSR
        move.w  (sp),2(sp)      // msw of return address of BSR
        addq.l   #2,sp          // discard the missing word
ft_exit:
        rts


//==== fix_rte - restore a 68010 exception stack frame =======================

fix_rte:
        tst.w   proc_type       // check processor type
        beq     fr_exit

        subq.l  #2,sp           // reserve a hole on top of the stack
        move.w  2(sp),(sp)      // move SR
        move.w  4(sp),2(sp)     // msw of return address of TRAP
        move.w  6(sp),4(sp)     // lsw of return address of TRAP
        clr.w   6(sp)           // store a bogus exception frame type
fr_exit:
#ifdef NETWORK
#ifdef LWIP
        lea     -24(sp),sp
        movem.l d0-d2/a0-a2,(sp)
        jsr     _xSemaphoreGiveBDOS
        movem.l (sp),d0-d2/a0-a2
        lea     24(sp),sp
#endif
#endif
        rte

//==== miscasm - swap ========================================================

_swp68w:
        move.l  4(sp),a0
        move.w  (a0),d0
#ifdef COLDFIRE
        move.l  d1,-(sp)
        move.w  d0,d1
        asl.l   #8,d0
        lsr.l   #8,d1
        and.l   #0xff00,d0
        and.l   #0x00ff,d1
        or.l    d1,d0
        move.l  (sp)+,d1
#else
        ror.w   #8,d0
#endif
        move.w  d0,(a0)
        rts
        
_swp68l:
        move.l  4(sp),a0
        move.l  (a0),d0
#ifdef COLDFIRE
        move.l  d1,-(sp)
        move.l  d0,d1
        asl.l   #8,d0
        lsr.l   #8,d1
        and.l   #0xff00ff00,d0
        and.l   #0x00ff00ff,d1
        or.l    d1,d0
        swap    d0
        move.l  (sp)+,d1
#else
        ror.w   #8,d0
        swap    d0
        ror.w   #8,d0
#endif
        move.l  d0,(a0)
        rts
        
_rwabs:

        lea -20(sp),sp
        movem.l d1-d5,(sp)
        movem.l 24(sp),d0-d5
        move.l  d5,-(sp) // lrecno
        move.w  d4,-(sp) // dev
        move.w  d3,-(sp) // recno
        move.w  d2,-(sp) // count
        move.l  d1,-(sp) // buf
        move.w  d0,-(sp) // mode
#ifdef NETWORK
#ifdef LWIP
        move.l  _pxCurrentTCB,d0
        cmp.l   _tid_TOS,d0
        beq.s   use_trap
        move.l  hdv_rw,a0
        jsr     (a0)
        lea     16(sp),sp
        movem.l (sp),d1-d5
        lea     20(sp),sp
        rts 
use_trap:
#endif
#endif
        move.w  #4,-(sp) // Rwabs
        trap    #13
        lea     18(sp),sp
        movem.l (sp),d1-d5
        lea     20(sp),sp
        rts     
        
#define SL_HEAD 4
#define SH_NO_FUNCS 68
#define SH_FUNCTIONS 72

// slb_exec
//
// Helper function to call an SLB's function from within an application.
//
// Input:
// 4(sp): Pointer to shared library structure
// 8(sp): Function number (long)
// 12(sp): Number of arguments (short)
// 14(sp): arguments (if any)
//
// Returns:
// d0: EINVFN: Function not implemented (or function number out of range)
//     Otherwise: Return code of function
//

_slb_exec:
	move.l	8(sp),d0
	bmi.s	einvfn
	move.l	4(sp),a0
	move.l	SL_HEAD(a0),a0
	cmp.l	SH_NO_FUNCS(a0),d0
	bcc.s	einvfn
	lsl.l	#2,d0
	move.l	SH_FUNCTIONS(a0,d0.l),d0
	beq.s	einvfn
	move.l	_run,a0
	move.l	a0,4(sp)	// replace the SLB handle with basepage pointer
	move.l	d0,a0
	jmp	(a0)

einvfn:	moveq	#-32,d0
	rts


#define DELAY_CACHE 1000   /* 5 Sec */

#define rw_parameter 0xc60b

_flush_cache_pexec:

#ifdef COLDFIRE
	lea -28(SP),SP
	movem.l D0-D2/A0-A2/A5,(SP)
	move.l 32(SP),A5                                    // PD
	move.l 0xC(A5),D1                                   // p_tlen
	lsr.l #1,D1
	lea 256(A5),A0                                      // text
	lea memset_purec,A1
.loop_search_memset:
		move.l (A0),D0
		cmp.l (A1),D0
		bne.s .next_search_memset
		addq.l #4,A1
		lea 4(A0),A2
		moveq #(12*4)-1,D2
.loop_search_memset_2:
			move.l (A2)+,D0
			cmp.l (A1)+,D0
			bne.s .bad_cmp_memset
		subq.l #1,D2
		bgt.s .loop_search_memset_2
		// patch for incompatible instructions
		lea 0x14(A0),A0                        // move.b D0,-(SP) move.w (SP)+,D2
		move.l #0x1400E18A,(A0)                // => move.b D0,D2 lsl.l #8,D2 
		bra.s .test_cacr
.bad_cmp_memset:
		lea memset_purec,A1	
.next_search_memset:
		addq.l #2,A0
	subq.l #1,D1
	bgt.s .loop_search_memset
.test_cacr:
	.chip 68060
	movec.l CACR,D0
	.chip 5200
	cmp.l #CACHE_ENABLE_MODE,D0
#else
	movem.l D0-D2/A0-A2/A5,-(SP)
	move.l _run,A5
	movec.l CACR,D0
	cmp.l #0xA0808000,D0
#endif
	bne.s .normal
	clr.l -(SP)
	move.l #CT60_CACHE_DELAY,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	cmp.l #-1,D0
	beq.s .normal
	btst #0,D0
	beq.s .normal
	jsr 0xE0085A                                        // caches off
	move.l phystop,A0
	clr.l save_hz_200(A0)
	move.l #0x12345678,D0
	move.l D0,flag_cache(A0)                            // flag delay	
	bra .end_pexec
.normal:
	lea 256(A5),A0                                      // begin of the program
#ifdef COLDFIRE
	moveq #0,D0
	move.w (A0)+,D0
	cmp.l #0x6008,D0                                    // fix problems with Ice Packer
	bne .no_ice
	move.l (A0)+,D0
	cmp.l #0x5061636B,D0                                // Pack
	bne.s .no_ice
	move.l (A0)+,D0
	cmp.l #0x2D496365,D0                                // _Ice
	bne.s .no_ice
	moveq #0,D0
	move.w 0x86(A0),D0
	cmp.l #0x4ED2,D0                                    // jmp (A2)
	bne.s .no_ice
	move.w 0xA4(A0),D0
	cmp.l #0x4ED6,D0                                    // jmp (A6)
	bne.s .no_ice
	move.w #0x4AFC,D0                                   // illegal
	move.w D0,0x86(A0)
	move.w D0,0xA4(A0)                                  // illegal
	lea.l .new_illegal(PC),A0
	move.l 0x10,D0
	move.l D0,0x380                                     // save illegal vector
#else
	cmp.w #0x6008,(A0)+                                 // fix problems with Ice Packer
	bne.s .no_ice
	cmp.l #0x5061636B,(A0)+                             // Pack
	bne.s .no_ice
	cmp.l #0x2D496365,(A0)+                             // _Ice
	bne.s .no_ice
	cmp.w #0x4ED2,0x86(A0)                              // jmp (A2)
	bne.s .no_ice
	cmp.w #0x4ED6,0xA4(A0)                              // jmp (A6)
	bne.s .no_ice
	move.w #0x4AFC,0x86(A0)                             // illegal
	move.w #0x4AFC,0xA4(A0)                             // illegal
	lea.l .new_illegal(PC),A0
	move.l 0x10,0x380 
#endif
	clr.l 0x384                                         // illegal counter
	move.l A0,0x10
	bra.s .no_ice
.new_illegal:
#ifdef COLDFIRE
	.chip 68060
	cpusha BC                                           // flush
	.chip 5200
	addq.l #1,0x384                                     // illegal counter
	move.l 0x384,D0
	cmp.l #2,D0
	bcs.s .jmp_a2
	move.l 0x380,D0
	move.l D0,0x10                                      // restore illegal vector
#else
	cpusha BC                                           // flush
	addq.l #1,0x384                                     // illegal counter
	cmp.l #2,0x384
	bcs.s .jmp_a2
	move.l 0x380,0x10                                   // restore illegal vector
#endif
	addq.l #8,SP
	moveq #0,D0
	move D0,SR
	jmp (A6)
.jmp_a2:
	addq.l #8,SP
	moveq #0,D0
	move D0,SR
	jmp (A2)
.no_ice:	
#ifdef COLDFIRE
	.chip 68060
	cpusha BC                                           // flush
	.chip 5200
.end_pexec:
	movem.l (SP),D0-D2/A0-A2/A5
	lea 28(SP),SP
#else
	cpusha BC                                           // flush
.end_pexec:
	movem.l (SP)+,D0-D2/A0-A2/A5
#endif
	rts
	
#ifdef COLDFIRE

	.data

memset_purec:
	dc.l 0x2F08D1C1,0x24080802,0x00006708,0x53816500
	dc.l 0x00AC1100,0x1F00341F,0x14003002,0x48423400
	dc.l 0x2001E088,0xE4886778,0x48E75F3E,0x22022602
	dc.l 0x28022A02,0x2C022E02,0x22422442,0x26422842
	dc.l 0x2A422C42,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F7E,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F7E,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F7E,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F7E,0x48E07F7E,0x48E07F7E,0x48E07F7E
	dc.l 0x48E07F60,0x538066AC,0x4CDF7CFA,0xC27C03FF
	dc.l 0x3001E448,0x67085340,0x210251C8,0xFFFCC27C
	dc.l 0x00036708,0x53411102,0x51C9FFFC,0x205F4E75
#endif

	.bss
	.even

_old_trap2:
	.ds.l   1                       // old TRAP #2 handler

	.ds.w   4096 // was 1000
fstrt:
	.ds.l   1

	.end

