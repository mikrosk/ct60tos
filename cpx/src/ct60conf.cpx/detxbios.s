
;CT60 XBIOS

	.import ct60_read_temp,ct60_stop,ct60_rw_param
	.export det_xbios,det_xbios_030

TEST equ 0

CT60_CELCIUS equ 0
CT60_FARENHEIT equ 1
CT60_READ_ERROR equ -1

proc_type equ $59e
ct60_read_core_temperature equ $c60a
ct60_rw_parameter equ $c60b
ct60_cache equ $c60c
ct60_flush_cache equ $c60d
ct60_read_core_temperature_bis equ $c6a
ct60_rw_parameter_bis equ $c6b
ct60_cache_bis equ $c6c
ct60_flush_cache_bis equ $c6d

	dc.l "XBRA"
	dc.l "CT60"
	dc.l 0

det_xbios:

	move.l USP,A0
	btst #5,(SP)				; call in supervisor state
	beq.s .2
	lea.l 6(SP),A0
	tst.w proc_type
	beq.s .2
	tst.w (A0)+					; if > 68000
.2:	move.w (A0),D0				; function
	cmp.w #$27,D0				; Puntaes
	bne.s .8
	cmp.l #'AnKr',2(A0)			; MagiC
	bne .1
	cmp.w #-1,6(A0)				; added for the CT60
	bne .1
	jsr ct60_stop
	rte
.8:	cmp.w #$40,D0			 	; Blitmode
	bne.s .17
	moveq #0,D0
	rte
.17:
	cmp.w #160,D0               ; CacheCtrl MilanTOS
	bne.s .6
	move.w 2(A0),D0             ; OpCode
	bne.s .18
	moveq #0,D0                 ; function is implemented
	rte
.18:
	cmp.w #1,D0                 ; flush data cache
	bne.s .19
	cpusha DC
	moveq #0,D0
	rte	
.19:
	cmp.w #2,D0                 ; flush instruction cache
	bne.s .20
	cpusha IC
	moveq #0,D0
	rte
.20:
	cmp.w #3,D0                 ; flush data and instruction caches
	beq .16
	cmp.w #4,D0                 ; inquire data cache mode
	bne.s .21
	movec.l CACR,D0
	btst #31,D0
	bra.s .22
.21:
	cmp.w #6,D0                 ; inquire instruction cache mode
	bne.s .23
	movec.l CACR,D0
	btst #15,D0
.22:
	sne.b D0
	and.w #1,D0
	ext.l D0
	rte
.23:
	cmp.w #5,D0                 ; set data cache mode
	beq.s .24
	cmp.w #7,D0                 ; set instruction cache mode
	bne.s .25
.24:	
	tst.w 4(A0)                 ; mode
	beq .26                     ; disable
	bra .11                     ; enable
.25:
	moveq #-5,D0                ; error
	rts
.6:	cmp.w #ct60_read_core_temperature,D0
	beq.s .13
	cmp.w #ct60_read_core_temperature_bis,D0
	bne.s .5
.13:
	move.w 2(A0),-(SP)			; deg_type
	if TEST
		move.l temp,D0
		subq #1,count
		bpl.s .7
		move #14,count
		move #17,-(SP)			; Random
		trap #14
		addq #2,SP
		and.l #7,D0
		add.l temp,d0
		subq.l #3,D0			; -3 … 4
		bpl.s .7
		moveq #0,d0
.7:		move.l d0,temp
	else
		bsr ct60_read_temp
	endif
	cmp #CT60_CELCIUS,(SP)
	beq.s .3
	cmp #CT60_FARENHEIT,(SP)
	bne.s .4
	mulu #9,D0
	divu #5,D0
	add.w #32,D0
	bra.s .3
.4:	moveq #CT60_READ_ERROR,D0	; error
.3:	addq #2,SP
	rte
.5:	cmp.w #ct60_rw_parameter,D0
	beq.s .14
	cmp.w #ct60_rw_parameter_bis,D0
	bne.s .9
.14:
	move.w 2(A0),D0             ; mode
	move.l 4(A0),D1             ; type_param
	move.l 8(A0),D2             ; value
	bsr ct60_rw_param 
	rte
.9:	cmp.w #ct60_cache,D0
	beq.s .15
	cmp.w #ct60_cache_bis,D0
	bne.s .12
.15:
	move.w 2(A0),D0
	bmi.s .10
	bne.s .11
.26:
	move.w SR,-(SP)             ; caches off
	or.w #$700,SR
	cpusha DC
	moveq #0,D0
	movec.l D0,CACR
	cinva BC	
	move.w (SP)+,SR
	rte	
.11:
	move.w SR,-(SP)             ; caches on
	or.w #$700,SR
	cpusha BC
	move.l #$A0808000,D0
	movec.l D0,CACR
	move.w (SP)+,SR
	rte
.10:
	movec.l CACR,D0
	rte
.12:
	cmp.w #ct60_flush_cache,D0
	beq.s .16
	cmp.w #ct60_flush_cache_bis,D0
	bne.s .1
.16:
	cpusha BC	
	moveq #0,D0
	rte
.1:	move.l det_xbios-4,-(SP)
	rts	
	
	dc.l "XBRA"
	dc.l "CT60"
	dc.l 0

det_xbios_030:

	move.l USP,A0
	btst #5,(SP)				; call in supervisor state
	beq.s .2
	lea.l 6(SP),A0
	tst.w proc_type
	beq.s .2
	tst.w (A0)+					; if > 68000
.2:	move.w (A0),D0				; function
	cmp.w #ct60_read_core_temperature,D0
	bne.s .5
	moveq #CT60_READ_ERROR,D0	; error
	rte
.5:	cmp.w #ct60_rw_parameter,D0
	bne.s .3
	move.w 2(A0),D0             ; mode
	move.l 4(A0),D1             ; type_param
	move.l 8(A0),D2             ; value
	bsr ct60_rw_param 
	rte
.3:	cmp.w #ct60_cache,D0
	bne.s .4
	movec.l CACR,D0
	rte
.4:	cmp.w #ct60_flush_cache,D0
	bne.s .1
	rte
.1:	move.l det_xbios_030-4,-(SP)
	rts	

	if TEST	
temp:	dc.l 25
count:	dc.w 0
	endif

	end
