	.export NVMaccess

NVMaccess:
	pea (A2)
	move.l A0,-(SP)
	move.w D2,-(SP)
	move.w D1,-(SP)
	move.w D0,-(SP)
	move.w #0x2e,-(SP)
	trap #14
	lea 12(SP),SP
	move.l (SP)+,A2
	rts

	end
