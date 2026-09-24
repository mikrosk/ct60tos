/* Lay a GEMDOS program out in memory the way Pexec does: TEXT and DATA copied
 * to A1, BSS cleared behind them, the fixups applied for A1.  A0 points at its
 * program header.  Used for the two programs the flash carries, the SuperVidel
 * driver and the setup.  All registers are preserved.
 */

	.text

	.globl	load_prg

load_prg:

	movem.l D0-D5/A0-A2,-(SP)
	move.l 2(A0),D1          // TEXT
	move.l 6(A0),D2          // DATA
	move.l 10(A0),D3         // BSS
	move.l 14(A0),D4         // symbols, skipped over
	lea 28(A0),A0            // TEXT starts after the program header
	move.l A1,D5             // relocation offset, programs are linked at 0

	move.l D1,D0
	add.l D2,D0              // TEXT + DATA
	move.l A1,A2
	lsr.l #1,D0
	bcc.s .copy_words
	move.b (A0)+,(A2)+       // odd size, can not happen but be safe
.copy_words:
	tst.l D0
	beq.s .copy_done
.loop_copy:
		move.w (A0)+,(A2)+
	subq.l #1,D0
	bne.s .loop_copy
.copy_done:

	move.l D3,D0             // BSS, A2 already points at it
	lsr.l #1,D0
	bcc.s .clear_words
	clr.b (A2)+
.clear_words:
	tst.l D0
	beq.s .clear_done
.loop_clear:
		clr.w (A2)+
	subq.l #1,D0
	bne.s .loop_clear
.clear_done:

	add.l D4,A0              // past the symbols, at the fixup table
	move.l (A0)+,D0          // offset of the first fixup
	beq.s .reloc_done        // nothing to relocate
	move.l A1,A2
	add.l D0,A2
	add.l D5,(A2)
.loop_reloc:
		moveq #0,D0
		move.b (A0)+,D0
		beq.s .reloc_done
		cmp.b #1,D0
		bne.s .reloc_fixup
		lea 254(A2),A2       // skip 254 bytes, no fixup
	bra.s .loop_reloc
.reloc_fixup:
		add.l D0,A2
		add.l D5,(A2)
	bra.s .loop_reloc
.reloc_done:

	nop
	cpusha BC                // it was written through the data cache
	nop
	movem.l (SP)+,D0-D5/A0-A2
	rts
