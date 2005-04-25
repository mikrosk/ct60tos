
#define WIDTH  320
#define HEIGHT 240

	.global	_tga_conv

_tga_conv:

	movem.l D0-D3/A0-A3,-(SP)
	move.l 36(SP),A3        // target 65K
	move.l 40(SP),A1        // source 24M TGA uncompressed
	move.w #HEIGHT-1,D1
	move.w #WIDTH*2,D3 
	tst.l 44(SP)            // orientation
	bpl.s pb1
	move.w d1,D0
	mulu D3,D0
	neg.w D3
	add.l D0,A3
pb1:
		move.l A3,A2
		move.w #WIDTH-1,D2
pb2:
			moveq #0,D0
			move.b (A1)+,D0 // R
			asl.l #8,D0
			move.b (A1)+,D0 // G
			asl.l #8,D0
			move.b (A1)+,D0 // B
			lsr.l #3,D0     // 000RRRRR 321GGGGG 321BBBBB
			asl.b #2,D0     // 000RRRRR 321GGGGG 1BBBBB00
			asl.w #3,D0     // 000RRRRR GGGGG1BB BBB00000
			lsr.l #5,D0     // 00000000 RRRRRGGG GG1BBBBB
			bclr #5,D0
			move.w D0,(A2)+ // target NTC 65K colors
		dbf D2,pb2
		add.w D3,A3
	dbf D1,pb1
	movem.l (SP)+,D0-D3/A0-A3
	rts
	

	