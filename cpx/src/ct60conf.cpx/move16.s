
        .EXPORT _move_16,move_16,_move_4_longs,move_4_longs,_cpush_dc,cpush_dc,_inta,inta,_count_inta,count_inta


_move_16:
move_16:
		move16 (a0)+,(a1)+
		rts
		
_move_4_longs:
move_4_longs:
		move.l (a0)+,(a1)+
		move.l (a0)+,(a1)+
		move.l (a0)+,(a1)+
		move.l (a0)+,(a1)+
		rts
		
_cpush_dc:
cpush_dc:
		move.l 8(SP),D0          ; size
		beq.s .csh1
		move.l 4(SP),A0          ; base
		move.l A0,D1
		and.l #0xf,D1
		subq.l #1,D1
		add.l D1,D0
		lsr.l #4,D0
		cmp.l #256,D0            ; cache lines
		bcc.s .csh3
		move.l A0,D1             ; line alignment
		and.b #0xF0,D1
		move.l D1,A0 
.csh2:                           ; flush lines loop
			cpushl dc,(A0)
			lea 16(A0),A0
		dbf D0,.csh2
		rts
.csh3:
		cpusha dc                ; flush all
.csh1:
		rts


_inta:
inta:
		addq.l #1,count_inta
		rte

_count_inta:
count_inta:
		dc.l 0