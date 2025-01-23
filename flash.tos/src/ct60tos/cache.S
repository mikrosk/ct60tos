/*  TOS 4.04 patch for the CT60 board
 *  Copyright (C) 2001 Xavier Joubert
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
 *
 *
 *  To contact author write to Xavier Joubert, 5 Cour aux Chais, 44 100 Nantes,
 *  FRANCE or by e-mail to xavier.joubert@free.fr.
 *
 */

	.text

	.align	2
	.long	0x638
	.long	end1-begin1
begin1:
// EI, IBE, ED, DBE, WA (cache enable)
// [00e00638] 203c 0000 3111            move.l    #$00003111,d0
// [00e0063e] 4e7b 0002                 movec     d0,cacr
	bsr.l	begin1-0x638+0x250C8
	nop
	nop
end1:

	.align	2
	.long	0x908
	.long	end2-begin2
begin2:
// [00e00908] 6100 ff50                 bsr       flushCaches
	cpusha	bc
	nop
end2:

	.align	2
	.long	0x92A
	.long	end3-begin3
begin3:
// [00e0092a] 6100 ff2e                 bsr       flushCaches
	cpusha	bc
	nop
end3:

	.align	2
	.long	0x94A
	.long	end4-begin4
begin4:
// [00e0094a] 6100 ff0e                 bsr       flushCaches
	cpusha	bc
	nop
end4:

	.align	2
	.long	0xDF6
	.long	end5-begin5
begin5:
// [00e00df6] 6100 fa62                 bsr       flushCaches
	cpusha	bc
	nop
end5:

	.align	2
	.long	0x43B4
	.long	end6-begin6
begin6:
// [00e043b4] 6100 c4a4                 bsr       flushCaches
	cpusha	bc
	nop
end6:

	.align	2
	.long	0x46CC
	.long	end7-begin7
begin7:
// [00e046cc] 6100 c18c                 bsr       flushCaches
	cpusha	bc
	nop
end7:

	.align	2
	.long	0x85A
	.long	end8-begin8
begin8:
// flushCaches: (this has changed its purpose on 060, it's not called to flush but to flush and disable caches, callers are not the same anymore!)
// [00e0085a] 40e7                      move.w    sr,-(a7)
// [00e0085c] 007c 0700                 ori.w     #$0700,sr
// [00e00860] 4e7a 0002                 movec     cacr,d0
// [00e00864] 80bc 0000 0808            or.l      #$00000808,d0
// [00e0086a] 4e7b 0002                 movec     d0,cacr
// [00e0086e] 46df                      move.w    (a7)+,sr
// [00e00870] 4e75                      rts
	move.w	sr,-(sp)
	or.w	#0x700,sr
	cpusha	dc
	clr.l	d0
	movec.l	d0,cacr
	cinva	bc
	move.w	(sp)+,sr
	rts
end8:

	.align	2
	.long	0x18CA
	.long	end9-begin9
begin9:
// DMAread() - IDE
// [00e018ca] 40e7                    > move.w    sr,-(a7)
// [00e018cc] 007c 0700               > ori.w     #$0700,sr
// [00e018d0] 4e7a 1002                 movec     cacr,d1
// [00e018d4] 0041 0808                 ori.w     #$0808,d1
// [00e018d8] 4e7b 1002                 movec     d1,cacr
// [00e018dc] 46df                      move.w    (a7)+,sr
// [00e018de] 4a40                      tst.w     d0
	cpusha	bc
	bra.s	begin9-0x18CA+0x18DE
end9:

	.align	2
	.long	0x1944
	.long	end10-begin10
begin10:
// DMAread() - ACSI (why flushing data cache only?)
// [00e01944] 40e7                    > move.w    sr,-(a7)
// [00e01946] 007c 0700               > ori.w     #$0700,sr
// [00e0194a] 4e7a 0002                 movec     cacr,d0
// [00e0194e] 0040 0800                 ori.w     #$0800,d0
// [00e01952] 4e7b 0002                 movec     d0,cacr
// [00e01956] 46df                      move.w    (a7)+,sr
// [00e01958] 31c1 8606                 move.w    d1,($FFFF8606).w
	cpusha	dc
	bra.s	begin10-0x1944+0x1958
end10:

	.align	2
	.long	0x3990
	.long	end11-begin11
begin11:
// coldboot (flush & disable caches)
// [00e03990] 203c 0000 0808            move.l    #$00000808,d0
// [00e03996] 4e7b 0002                 movec     d0,cacr
	bsr.w	begin11-0x3990+0x85A
	nop
	nop
	nop
end11:

	.align	2
	.long	0x756
	.long	end12-begin12
begin12:
// (flush & disable caches)
// [00e00756] 203c 0000 0808            move.l    #$00000808,d0
// [00e0075c] 4e7b 0002                 movec     d0,cacr
	bsr.w	begin12-0x756+0x85A
	nop
	nop
	nop
end12:

	.align	2
	.long	0x990C
	.long	end13-begin13
begin13:
	// v_pline, thanks to Roger Burrows
	subq.w	#1,d3
	movem.w	code13(pc),D0/D1/A1
	movea.l	a2,a0
	move.l	0x652(a4),d2
loop13:
	roxr.l	#1,d2
	bcs.s	set13
	move.w	d0,(a0)+
	dbf	d3,loop13
	move.w	a1,(a0)+
	cpusha	bc
	rts
set13:
	move.w	d1,(a0)+
	dbf	d3,loop13
	move.w	a1,(a0)+
	cpusha	bc
	rts
code13:
	and.w	d0,(a5)+
	or.w	d1,(a5)+
	jmp	(a3)
	nop
	nop
	nop
	nop
end13:

	.align	2
	.long	0x11BCE
	.long	end14-begin14
begin14:
// VDI (clear data cache - CD) (do we return because all writes are being done to ST RAM?)
// [00e11bce] 4e7a 0002                 movec     cacr,d0
// [00e11bd2] 08c0 000b                 bset      #11,d0
// [00e11bd6] 4e7b 0002                 movec     d0,cacr
	rts
end14:

	.align	2
	.long	0x11C56
	.long	end15-begin15
begin15:
// [00e11c56] 4e7a 7002                 movec     cacr,d7
// [00e11c5a] 08c7 000b                 bset      #11,d7
// [00e11c5e] 4e7b 7002                 movec     d7,cacr
	rts
end15:

	.align	2
	.long	0x11D52
	.long	end16-begin16
begin16:
// [00e11d52] 4e7a 0002                 movec     cacr,d0
// [00e11d56] 08c0 000b                 bset      #11,d0
// [00e11d5a] 4e7b 0002                 movec     d0,cacr
// [00e11d5e] 7001                      moveq.l   #1,d0
	moveq.l	#1,d0
	rts
end16:

	.align	2
	.long	0x125B8
	.long	end17-begin17
begin17:
// [00e125b8] 4e7a 5002                 movec     cacr,d5
// [00e125bc] 08c5 000b                 bset      #11,d5
// [00e125c0] 4e7b 5002                 movec     d5,cacr
	rts
end17:

	.align	2
	.long	0x1292E
	.long	end18-begin18
begin18:
// [00e1292e] 4e7a 6002                 movec     cacr,d6
// [00e12932] 08c6 000b                 bset      #11,d6
// [00e12936] 4e7b 6002                 movec     d6,cacr
	rts
end18:

	.align	2
	.long	0x1297A
	.long	end19-begin19
begin19:
// [00e1297a] 4e7a 6002                 movec     cacr,d6
// [00e1297e] 08c6 000b                 bset      #11,d6
// [00e12982] 4e7b 6002                 movec     d6,cacr
	rts
end19:

	.align	2
	.long	0x129DE
	.long	end20-begin20
begin20:
// [00e129de] 4e7a 6002                 movec     cacr,d6
// [00e129e2] 08c6 000b                 bset      #11,d6
// [00e129e6] 4e7b 6002                 movec     d6,cacr
	rts
end20:

	.align	2
	.long	0x12BF6
	.long	end21-begin21
begin21:
// [00e12bf6] 4e7a 5002                 movec     cacr,d5
// [00e12bfa] 08c5 000b                 bset      #11,d5
// [00e12bfe] 4e7b 5002                 movec     d5,cacr
	rts
end21:

	.align	2
	.long	0x12C76
	.long	end22-begin22
begin22:
// [00e12c76] 4e7a 5002                 movec     cacr,d5
// [00e12c7a] 08c5 000b                 bset      #11,d5
// [00e12c7e] 4e7b 5002                 movec     d5,cacr
	rts
end22:

	.align	2
	.long	0x12CEE
	.long	end23-begin23
begin23:
// [00e12cee] 4e7a 2002                 movec     cacr,d2
// [00e12cf2] 08c2 000b                 bset      #11,d2
// [00e12cf6] 4e7b 2002                 movec     d2,cacr
	rts
end23:

	.align	2
	.long	0x12D6C
	.long	end24-begin24
begin24:
// [00e12d6c] 4e7a 0002               > movec     cacr,d0
// [00e12d70] 08c0 000b                 bset      #11,d0
// [00e12d74] 4e7b 0002                 movec     d0,cacr
// [00e12d78] 4240                      clr.w     d0
	bra.s	begin24-0x12D6C+0x12D78
end24:

	.align	2
	.long	0x12DD4
	.long	end25-begin25
begin25:
// [00e12dd4] 4e7a 0002               > movec     cacr,d0
// [00e12dd8] 08c0 000b                 bset      #11,d0
// [00e12ddc] 4e7b 0002                 movec     d0,cacr
// [00e12de0] 4240                      clr.w     d0
	bra.s	begin25-0x12DD4+0x12DE0
end25:

	.align	2
	.long	0x12E96
	.long	end26-begin26
begin26:
// [00e12e96] 4e7a 0002                 movec     cacr,d0
// [00e12e9a] 08c0 000b                 bset      #11,d0
// [00e12e9e] 4e7b 0002                 movec     d0,cacr
	rts
end26:

	.align	2
	.long	0x17B4C
	.long	end27-begin27
begin27:
// [00e17b4c] 4e7a 0002                 movec     cacr,d0
// [00e17b50] 08c0 000b                 bset      #11,d0
// [00e17b54] 4e7b 0002                 movec     d0,cacr
	rts
end27:

	.align	2
	.long	0x17BE4
	.long	end28-begin28
begin28:
// [00e17be4] 4e7a 0002                 movec     cacr,d0
// [00e17be8] 08c0 000b                 bset      #11,d0
// [00e17bec] 4e7b 0002                 movec     d0,cacr
	rts
end28:

	.align	2
	.long	0x44528
	.long	end29-begin29
begin29:
// ch_cache(WORD set)
// [00e44526] 0c79 001e 0000 b5ee       cmpi.w    #$001E,$0000B5EE
// [00e4452e] 6600 0066                 bne       $00E44596
// [00e44532] 4a6e 0008                 tst.w     8(a6)
// [00e44536] 6700 0024                 beq       $00E4455C
// [00e4453a] 4a79 0000 9c64            tst.w     $00009C64
// [00e44540] 6700 000c                 beq       $00E4454E
	dc.w	60
end29:

	.align	2
	.long	0x44544
	.long	end30-begin30
begin30:
// [00e44544] 203c 0000 3919          > move.l    #$00003919,d0   <-- enable caches path
// [00e4454a] 6000 0008               > bra       $00E44554
// [00e4454e] 203c 0000 0808          > move.l    #$00000808,d0   <-- disable caches path
// [00e44554] 2d40 fffa               > move.l    d0,-6(a6)
// [00e44558] 6000 000a                 bra       $00E44564
// [00e4455c] 2d7c ffff ffff fffa       move.l    #$FFFFFFFF,-6(a6)
// [00e44564] 2eae fffa                 move.l    -6(a6),(a7)
// [00e44568] 4eb9 00e4 44f6            jsr       $00E444F6   <-- inq_cache(data), not used
// [00e4456e] b0bc 0000 3111          > cmp.l     #$00003111,d0   <-- patched below
// [00e44574] 6600 000e                 bne       $00E44584
// [00e44578] 33fc 0001 0000 9c64       move.w    #$0001,$00009C64
// [00e44580] 6000 0008                 bra       $00E4458A
// [00e44584] 4279 0000 9c64            clr.w     $00009C64
	// enable caches path
	bsr.l	begin30-0x44544+0x250C8
	bra.s	begin30-0x44544+0x44578
	nop

// disable caches path
	bsr.l	begin30-0x44544+0x85A
	bra.s	begin30-0x44544+0x44584
end30:

	.align	2
	.long	0x250C8
	.long	end31-begin31
begin31:
#if 0
LONG set_cache(LONG newcacr)
{
	asm( ".dc.w $4e7a,$0002" );	/* movec.l cacr,d0	*/
	asm( ".dc.w $4e7b,$7002" );	/* movec.l d7,cacr	*/
}
#endif
// flush caches and enable them (initially called only when enabling cache while parsing desktop.inf; the 'cacr' parameter is not used anymore)
// [00e250c8] 4e56 0000                 link      a6,#$0000
// [00e250cc] 48e7 0300                 movem.l   d6-d7,-(a7)
// [00e250d0] 2e2e 0008                 move.l    8(a6),d7
// [00e250d4] 4e7a 0002                 movec     cacr,d0
// [00e250d8] 4e7b 7002                 movec     d7,cacr
// [00e250dc] 4a9f                      tst.l     (a7)+
// [00e250de] 4cdf 0080                 movem.l   (a7)+,d7
// [00e250e2] 4e5e                      unlk      a6
// [00e250e4] 4e75                      rts
	move.w	sr,-(sp)
	or.w	#0x700,sr
	cpusha	bc
	move.l	#0xA0808000,d0
	movec.l	d0,cacr
	move.w	(sp)+,sr
	rts
end31:

	.align	2
	.long	0x4456E
	.long	end32-begin32
begin32:
// see above
	cmp.l	#0xA0808000,d0
end32:

#if 0
// not used!
LONG inq_cache(LONG data)
{
	  asm( ".dc.w $4e7a,$0002" ); /* movec.l cacr,d0		*/

	  if ( data != -1 )
	    asm( ".dc.w $4e7b,$7002" ); /* movec.l d7,cacr		*/

	  asm( ".dc.w $4e7a,$0002" ); /* movec.l cacr,d0		*/
}
#endif
// [00e444f6] 4e56 0000                 link      a6,#$0000
// [00e444fa] 48e7 0300                 movem.l   d6-d7,-(a7)
// [00e444fe] 2e2e 0008                 move.l    8(a6),d7
// [00e44502] 4e7a 0002                 movec     cacr,d0
// [00e44506] bebc ffff ffff            cmp.l     #$FFFFFFFF,d7
// [00e4450c] 6700 0006                 beq       $00E44514
// [00e44510] 4e7b 7002                 movec     d7,cacr
// [00e44514] 4e7a 0002                 movec     cacr,d0
// [00e44518] 4a9f                      tst.l     (a7)+
// [00e4451a] 4cdf 0080                 movem.l   (a7)+,d7
// [00e4451e] 4e5e                      unlk      a6
// [00e44520] 4e75                      rts
