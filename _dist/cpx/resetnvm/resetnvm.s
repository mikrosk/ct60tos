; Nvmaccess()
	clr.l	-(sp)
	clr.w	-(sp)
	clr.w	-(sp)
	move.w	#2,-(sp)
	move.w	#46,-(sp)
	trap	#14
	lea.l	12(sp),sp

; Pterm0
	clr.w	-(sp)
	trap	#1
