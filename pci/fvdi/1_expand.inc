/*------------------------------------------------------*
*	Draw in single plane modes			*	
*-------------------------------------------------------*
**********
*
* Actual drawing routines
*
*********/

	.ifeq	shadow
mfdb_left:
	.else
shadow_left:
	.endif
	tst.w		d7		// Colour number
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_l_0
	.else
	beq		shadow_l_0
	.endif
	
	swap		d0
.loop1:
	swap		d0
	move.l		(a0),d7
	lsl.l		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	swap		d7
	and.w		d6,d7
	not.w		d6

	RandorW

	move.w		d0,d6			// Good idea?
	beq		.loop2_end
	subq.w		#1,d6
.loop2:
	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7

	nopW

	dbra		d6,.loop2
.loop2_end:

	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d6
	and.w		d6,d7
	not.w		d6		// Not needed before RandorW

	RandorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc

	add.w		a2,a0


	swap		d0
	dbra		d0,.loop1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_l_0:
	.else
shadow_l_0:
	.endif
	swap		d0
.loop11:
	swap		d0
	move.l		(a0),d7
	lsl.l		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	swap		d7

	not.w		d7		// new

	and.w		d6,d7
	not.w		d6

	RandorW

	move.w		d0,d6			// Good idea?
	beq		.loop22_end
	subq.w		#1,d6
.loop22:
	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7

	not.w		d7		// new

	nopW

	dbra		d6,.loop22
.loop22_end:

	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	moveq		#-1,d6
	lsr.w		d2,d6

	not.w		d7		// new

	not.w		d6
	and.w		d6,d7
	not.w		d6		// Not needed before RandorW

	RandorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc

	add.w		a2,a0

	swap		d0
	dbra		d0,.loop11

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_right:
	.else
shadow_right:
	.endif
	addq.l		#2,a2
	neg.w		d1

	tst.w		d7		// Colour number
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_r_0
	.else
	beq		shadow_r_0
	.endif
	
	swap		d0
.loop111:
	swap		d0
	move.w		(a0),d7
	lsr.w		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	and.w		d6,d7
	not.w		d6

	RandorW

	move.w		d0,d6			// Good idea?
	beq		.loop222_end
	subq.w		#1,d6
.loop222:
	move.l		(a0),d7
	lsr.l		d1,d7

	nopW

	addq.l		#2,a0
	dbra		d6,.loop222
.loop222_end:

	move.l		(a0),d7
	lsr.l		d1,d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d6
	and.w		d6,d7
	not.w		d6		// Not needed before RandorW

	RandorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc

	add.w		a2,a0

	swap		d0
	dbra		d0,.loop111

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_r_0:
	.else
shadow_r_0:
	.endif
	swap		d0
.loop1111:
	swap		d0
	move.w		(a0),d7
	lsr.w		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6

	not.w		d7		// new

	and.w		d6,d7
	not.w		d6

	RandorW

	move.w		d0,d6			// Good idea?
	beq		.loop2222_end
	subq.w		#1,d6
.loop2222:
	move.l		(a0),d7
	lsr.l		d1,d7

	not.w		d7		// new


	nopW

	addq.l		#2,a0
	dbra		d6,.loop2222
.loop2222_end:

	move.l		(a0),d7
	lsr.l		d1,d7

	not.w		d7		// new

	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d6
	and.w		d6,d7
	not.w		d6		// Not needed before RandorW

	RandorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc

	add.w		a2,a0

	swap		d0
	dbra		d0,.loop1111

	moveq		#1,d0
	rts


	.ifeq	shadow
mfdb_single:
	.else
shadow_single:
	.endif

	swap		d0
	moveq		#-1,d6
	lsr.w		d3,d6
	move.w		#-1,d4
	lsr.w		d2,d4
	not.w		d4
	and.w		d4,d6


	sub.w		d3,d1		// d1 - shift length
	.ifeq	shadow
	blt		mfdb_sright
	.else
	blt		shadow_sright
	.endif

	move.w		d6,d3
	not.w		d6

	tst.w		d7		// Colour number
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_s_0
	.else
	beq		shadow_s_0
	.endif

.loops1:
	move.l		(a0),d7
	lsl.l		d1,d7

	swap		d7
	and.w		d3,d7

	RandorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc

	add.w		a2,a0

	dbra		d0,.loops1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_s_0:
	.else
shadow_s_0:
	.endif
.loops_1:
	move.l		(a0),d7
	lsl.l		d1,d7

	swap		d7

	not.w		d7		// new

	and.w		d3,d7

	RandorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc

	add.w		a2,a0

	dbra		d0,.loops_1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_sright:
	.else
shadow_sright:
	.endif
	neg.w		d1

	move.w		d6,d3
	not.w		d6

	tst.w		d7		// Colour number
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_sr_0
	.else
	beq		shadow_sr_0
	.endif

.loop_sr1:
	move.w		(a0),d7
	lsr.w		d1,d7

	and.w		d3,d7

	RandorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc

	add.w		a2,a0

	dbra		d0,.loop_sr1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_sr_0:
	.else
shadow_sr_0:
	.endif
.loopsr_01:
	move.w		(a0),d7
	lsr.w		d1,d7

	not.w		d7		// new

	and.w		d3,d7

	RandorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc

	add.w		a2,a0

	dbra		d0,.loopsr_01

	moveq		#1,d0
	rts


	.ifeq	shadow
mfdb_left_transp:
	.else
shadow_left_transp:
	.endif

	tst.w		d7
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_l_transp_0
	.else
	beq		shadow_l_transp_0
	.endif
	
	swap		d0
.loopl_t1:
	swap		d0
	move.l		(a0),d7
	lsl.l		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	swap		d7
	and.w		d6,d7

	RorW

	move.w		d0,d6			// Good idea?
	beq		.loopl_t2_end
	subq.w		#1,d6
.loopl_t2:
	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7

	RorW

	dbra		d6,.loopl_t2
.loopl_t2_end:

	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d6
	and.w		d6,d7

	RorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.loopl_t1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_l_transp_0:
	.else
shadow_l_transp_0:
	.endif
	swap		d0
.loopl_t01:
	swap		d0
	move.l		(a0),d7
	lsl.l		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	swap		d7
	and.w		d6,d7
	not.w		d7			// new

	RandW

	move.w		d0,d6			// Good idea?
	beq		.loopl_t02_end
	subq.w		#1,d6
.loopl_t02:
	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	not.w		d7			// new

	RandW

	dbra		d6,.loopl_t02
.loopl_t02_end:

	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d7
	or.w		d6,d7

	RandWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.loopl_t01

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_right_transp:
	.else
shadow_right_transp:
	.endif

	addq.l		#2,a2
	neg.w		d1

	tst.w		d7
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_r_transp_0
	.else
	beq		shadow_r_transp_0
	.endif

	swap		d0
.loopr_t1:
	swap		d0
	move.w		(a0),d7
	lsr.w		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	and.w		d6,d7

	RorW

	move.w		d0,d6			// Good idea?
	beq		.loopr_t2_end
	subq.w		#1,d6
.loopr_t2:
	move.l		(a0),d7
	lsr.l		d1,d7

	RorW

	addq.l		#2,a0
	dbra		d6,.loopr_t2
.loopr_t2_end:

	move.l		(a0),d7
	lsr.l		d1,d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d6
	and.w		d6,d7

	RorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.loopr_t1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_r_transp_0:
	.else
shadow_r_transp_0:
	.endif
	swap		d0
.looprt1:
	swap		d0
	move.w		(a0),d7
	lsr.w		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	and.w		d6,d7
	not.w		d7

	RandW

	move.w		d0,d6			// Good idea?
	beq		.looprt2_end
	subq.w		#1,d6
.looprt2:
	move.l		(a0),d7
	lsr.l		d1,d7
	not.w		d7

	RandW

	addq.l		#2,a0
	dbra		d6,.looprt2
.looprt2_end:

	move.l		(a0),d7
	lsr.l		d1,d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d7
	or.w		d6,d7

	RandWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.looprt1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_single_transp:
	.else
shadow_single_transp:
	.endif

	swap		d0
	moveq		#-1,d6
	lsr.w		d3,d6
	move.w		#-1,d4
	lsr.w		d2,d4
	not.w		d4
	and.w		d4,d6

	sub.w		d3,d1			// d1 - shift length
	.ifeq	shadow
	blt		mfdb_sright_transp
	.else
	blt		shadow_sright_transp
	.endif

	tst.w		d7
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_s_transp_0
	.else
	beq		shadow_s_transp_0
	.endif

.loop_st1:
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7

	and.w		d6,d7

	RorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loop_st1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_s_transp_0:
	.else
shadow_s_transp_0:
	.endif
	not.w		d6
.loop_s_t1:
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7

	not.w		d7
	or.w		d6,d7

	RandWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loop_s_t1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_sright_transp:
	.else
shadow_sright_transp:
	.endif
	neg.w		d1

	tst.w		d7
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_sr_transp_0
	.else
	beq		shadow_sr_transp_0
	.endif
.loop_s_t_1:
	move.w		(a0),d7
	lsr.w		d1,d7

	and.w		d6,d7

	RorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loop_s_t_1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_sr_transp_0:
	.else
shadow_sr_transp_0:
	.endif
	not.w		d6
.loopst01:
	move.w		(a0),d7
	lsr.w		d1,d7

	not.w		d7
	or.w		d6,d7

	RandWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loopst01

	moveq		#1,d0
	rts


	.ifeq	shadow
mfdb_left_xor:
	.else
shadow_left_xor:
	.endif
	swap		d0
.looplx1:
	swap		d0
	move.l		(a0),d7
	lsl.l		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	swap		d7
	and.w		d6,d7
	not.w		d6

	ReorW

	move.w		d0,d6			// Good idea?
	beq		.looplx2_end
	subq.w		#1,d6
.looplx2:
	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7

	ReorW

	dbra		d6,.looplx2
.looplx2_end:

	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d6
	and.w		d6,d7

	ReorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.looplx1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_right_xor:
	.else
shadow_right_xor:
	.endif
	addq.l		#2,a2
	neg.w		d1
	swap		d0
.looprx1:
	swap		d0
	move.w		(a0),d7
	lsr.w		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	and.w		d6,d7
	not.w		d6

	ReorW

	move.w		d0,d6			// Good idea?
	beq		.looprx2_end
	subq.w		#1,d6
.looprx2:
	move.l		(a0),d7
	lsr.l		d1,d7

	ReorW

	addq.l		#2,a0
	dbra		d6,.looprx2
.looprx2_end:

	move.l		(a0),d7
	lsr.l		d1,d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d6
	and.w		d6,d7

	ReorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.looprx1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_single_xor:
	.else
shadow_single_xor:
	.endif
	sub.w		d3,d1			// d1 - shift length
	.ifeq	shadow
	blt		mfdb_sright_xor
	.else
	blt		shadow_l_sright_xor
	.endif

	swap		d0
	moveq		#-1,d6
	lsr.w		d3,d6
	move.w		#-1,d4
	lsr.w		d2,d4
	not.w		d4
	and.w		d4,d6
.loopsx1:
	move.l		(a0),d7
	lsl.l		d1,d7

	swap		d7
	and.w		d6,d7

	ReorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loopsx1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_sright_xor:
	.else
shadow_sright_xor:
	.endif
	neg.w		d1
	swap		d0

	moveq		#-1,d6
	lsr.w		d3,d6
	move.w		#-1,d4
	lsr.w		d2,d4
	not.w		d4
	and.w		d4,d6
.loops_x1:
	move.w		(a0),d7
	lsr.w		d1,d7

	and.w		d6,d7

	ReorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loops_x1

	moveq		#1,d0
	rts


	.ifeq	shadow
mfdb_left_revtransp:
	.else
shadow_left_revtransp:
	.endif

	tst.w		d7
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_l_revtransp_0
	.else
	beq		shadow_l_revtransp_0
	.endif

	swap		d0
.looplr1:
	swap		d0
	move.l		(a0),d7
	lsl.l		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	swap		d7
	not.w		d7
	and.w		d6,d7

	RorW

	move.w		d0,d6			// Good idea?
	beq		.looplr2_end
	subq.w		#1,d6
.looplr2:
	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	not.w		d7

	RorW

	dbra		d6,.looplr2
.looplr2_end:

	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	not.w		d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d6
	and.w		d6,d7

	RorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.looplr1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_l_revtransp_0:
	.else
shadow_l_revtransp_0:
	.endif
	swap		d0
.loopl_r1:
	swap		d0
	move.l		(a0),d7
	lsl.l		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	swap		d7
	not.w		d7
	and.w		d6,d7
	not.w		d7			// new

	RandW

	move.w		d0,d6			// Good idea?
	beq		.loopl_r2_end
	subq.w		#1,d6
.loopl_r2:
	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7

	RandW

	dbra		d6,.loopl_r2
.loopl_r2_end:

	addq.l		#2,a0
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7
	moveq		#-1,d6
	lsr.w		d2,d6
	or.w		d6,d7

	RandWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.loopl_r1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_right_revtransp:
	.else
shadow_right_revtransp:
	.endif
	addq.l		#2,a2
	neg.w		d1

	tst.w		d7
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_r_revtransp_0
	.else
	beq		shadow_r_revtransp_0
	.endif

	swap		d0
.looprr1:
	swap		d0
	move.w		(a0),d7
	lsr.w		d1,d7
	not.w		d7
	moveq		#-1,d6
	lsr.w		d3,d6
	and.w		d6,d7

	RorW

	move.w		d0,d6			// Good idea?
	beq		.looprr2_end
	subq.w		#1,d6
.looprr2:
	move.l		(a0),d7
	lsr.l		d1,d7
	not.w		d7

	RorW

	addq.l		#2,a0
	dbra		d6,.looprr2
.looprr2_end:

	move.l		(a0),d7
	lsr.l		d1,d7
	not.w		d7
	moveq		#-1,d6
	lsr.w		d2,d6
	not.w		d6
	and.w		d6,d7

	RorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.looprr1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_r_revtransp_0:
	.else
shadow_r_revtransp_0:
	.endif
	swap		d0
.loopr_r1:
	swap		d0
	move.w		(a0),d7
	lsr.w		d1,d7
	moveq		#-1,d6
	lsr.w		d3,d6
	not.w		d7
	and.w		d6,d7
	not.w		d7

	RandW

	move.w		d0,d6			// Good idea?
	beq		.loopr_r2_end
	subq.w		#1,d6
.loopr_r2:
	move.l		(a0),d7
	lsr.l		d1,d7

	RandW

	addq.l		#2,a0
	dbra		d6,.loopr_r2
.loopr_r2_end:

	move.l		(a0),d7
	lsr.l		d1,d7
	moveq		#-1,d6
	lsr.w		d2,d6
	or.w		d6,d7

	RandWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	swap		d0
	dbra		d0,.loopr_r1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_single_revtransp:
	.else
shadow_single_revtransp:
	.endif
	swap		d0
	moveq		#-1,d6
	lsr.w		d3,d6
	move.w		#-1,d4
	lsr.w		d2,d4
	not.w		d4
	and.w		d4,d6

	sub.w		d3,d1			// d1 - shift length
	.ifeq	shadow
	blt		mfdb_sright_revtransp
	.else
	blt		shadow_sright_revtransp
	.endif

	tst.w		d7
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_s_revtransp_0
	.else
	beq		shadow_s_revtransp_0
	.endif
	
.loop_sr_1:
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7

	not.w		d7
	and.w		d6,d7

	RorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loop_sr_1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_s_revtransp_0:
	.else
shadow_s_revtransp_0:
	.endif
	not.w		d6
.loops_r1:
	move.l		(a0),d7
	lsl.l		d1,d7
	swap		d7

	or.w		d6,d7

	RandWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loops_r1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_sright_revtransp:
	.else
shadow_sright_revtransp:
	.endif
	neg.w		d1

	tst.w		d7
	// Go away if not 1s
	.ifeq	shadow
	beq		mfdb_sr_revtransp_0
	.else
	beq		shadow_sr_revtransp_0
	.endif
.loopsr1:
	move.w		(a0),d7
	lsr.w		d1,d7

	not.w		d7
	and.w		d6,d7

	RorWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loopsr1

	moveq		#1,d0
	rts

	.ifeq	shadow
mfdb_sr_revtransp_0:
	.else
shadow_sr_revtransp_0:
	.endif
	not.w		d6
.loop_s_r1:
	move.w		(a0),d7
	lsr.w		d1,d7

	or.w		d6,d7

	RandWl

	add.w		a3,a1
	.ifne	both
	add.w		a3,a4
	.endc
	add.w		a2,a0

	dbra		d0,.loop_s_r1

	moveq		#1,d0
	rts

