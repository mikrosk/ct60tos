
;CT60 PATCH VDI

	.export det_vdi

proc_type equ $59e

	dc.l "XBRA"
	dc.l "CT60"
	dc.l 0

det_vdi:

	cmp #$73,D0;VDI
	bne .1
	movem.l A0-A3,-(SP)
	move.l D1,A1
	move.l (A1),A3;CONTRL
	cmp #109,(A3);vro_cpyfm
	beq.s .11
	cmp.w #110,(A3);vr_trnfm
	beq.s .11
	cmp.w #121,(A3);vrt_cpyfm
	bne .3
.11:	move.l D2,-(SP)
	move.l A3,save_contrl
	clr.l adr_source
	clr.l adr_target
	move.l 14(A3),A0;MFDB source
	tst.l (A0)
	beq.S .4;source = screen
	cmp.l #$E00000,(A0)
	bcs.s .4;<> fast-ram
	move.l (A0),adr_source
	move 8(A0),D2;width in words
	mulu 12(A0),D2;number of planes
	mulu 6(A0),D2;height
	add.l D2,D2;size in bytes
	move.l D2,D0;size
	bsr malloc_stram
	blt .7;error
	move.l D0,(A0);new source
	move.l D0,A1
	move.l adr_source,A0;source in fast-ram
	move.l D2,D0;size
	bsr copy_bloc             	
.4:	move.l 18(A3),A0;MFDB target
	tst.l (A0)
	beq.S .9;target = screen
	cmp.l #$E00000,(A0)
	bcs.s .9;<> fast-ram
	move.l (A0),adr_target
	move 8(A0),D0;width in words
	mulu 12(A0),D0;number of planes
	mulu 6(A0),D0;height
	add.l D0,D0;in bytes
	bsr malloc_stram
	blt .8
	move.l D0,(A0);new target
.9:	move.l (SP)+,D2
	movem.l (SP)+,A0-A3
	moveq #$73,D0
	tst proc_type
	beq.s .10
	clr -(SP);format if > 68000
.10:	pea .2(PC)
	move SR,-(SP)
	move.l det_vdi-4,-(SP)
	rts
.2:	movem.l D0-D2/A0-A3,-(SP);return after vro_cpyfm
	move.l save_contrl,A3
	tst.l adr_source
	beq.s .5
	move.l 14(A3),A1;MFDB source
	move.l (A1),A0;source
	bsr free_stram
	move.l adr_source,(A1)	
.5:	move.l adr_target,D0
	beq.s .6
	move.l 18(A3),A0;MFDB target
	move.l D0,A1;target in fast-ram
	move 8(A0),D0;width in words
	mulu 12(A0),D0;number of planes
	mulu 6(A0),D0;height
	add.l D0,D0;size in bytes
	move.l (A0),A0;target	
	bsr copy_bloc
	move.l 18(A3),A0;MFDB target
	move.l (A1),A0;target
	bsr free_stram
	move.l adr_target,(A1)
	clr.l adr_target
.6:	movem.l (SP)+,D0-D2/A0-A3
	rte	 
.8:	tst.l adr_source
	beq.s .7
	move.l 14(A3),A1;MFDB source
	move.l (A1),A0;source
	bsr free_stram
	move.l adr_source,(A1)	
	clr.l adr_source
.7:	move.l (SP)+,D2
	movem.l (SP)+,A0-A3
	rte
.3:	movem.l (SP)+,A0-A3
	moveq #$73,D0
.1:	move.l det_vdi-4,-(SP)
	rts
	
copy_bloc:	;A0: source, A0:target, D0.L:size in bytes

	movem.l D0-A5,-(SP)
	moveq #32,D7
	move.l D0,D2
	ble.s .1
	move A0,D1;source
	btst #0,D1
	beq.s .5;adresse paire
	move.b (A0)+,(A1)+
	subq.l #1,D0
	ble.s .1
	move.l D0,D2
.5:
	lsr.l #5,D0;/32
	subq.l #1,D0
	bmi.s .4
	move D0,D1
	swap D0
.3:			movem.l (A0)+,D3-D6/A2-A5
			movem.l D3-D6/A2-A5,(A1)
			add D7,A1
		dbra D1,.3
	dbra D0,.3
.4:	move D2,D0
	and #$1E,D0
	lea .2(PC),A5
	sub D0,A5
	jmp (A5)
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
	move (A0)+,(A1)+
.2:	btst #0,D2
	beq.s .1
	move.b (A0)+,(A1)+
.1:	movem.l (SP)+,D0-A5
	rts

malloc_stram:

	move.l A0,-(SP)
	clr -(SP)
	move.l D0,-(SP)
	move #$44,-(SP)
	trap #1
	addq #8,SP
	move.l (SP)+,A0
	tst.l D0
	rts

free_stram:

	pea (A0)
	move #$49,-(SP)
	trap #1
	addq #6,SP
	rts

save_contrl:	dc.l 0
adr_source:	dc.l 0
adr_target:	dc.l 0

	end
