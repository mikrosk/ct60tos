/* TOS 4.04 Gemdos dispatcher for the CT60/CTPCI and Coldfire boards
 *  Didier Mequignon 2011, e-mail: aniplay@wanadoo.fr
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

	.global _det_gemdos,_old_vector_gemdos
	.global _cd_pterm,_cd_dfree,_cd_dcreate,_cd_ddelete,_cd_dsetpath
	.global _cd_fcreate,_cd_fopen,_cd_fclose,_cd_fread,_cd_fwrite,_cd_fdelete,_cd_fseek
	.global _cd_dgetpath,_cd_fattrib,_cd_pexec,_cd_fsfirst,_cd_fsnext,_cd_frename,_cd_fdatime
	
	.data
	
	.align 2
 
_det_gemdos:

	move.l USP,A0
	btst #5,(SP)           // call in supervisor state
	beq.s .gd16
	lea.l 8(SP),A0
.gd16:
	movem.l D1-D2/A1-A2,-(SP)
	move.w (A0),D0         // function
	beq.s .gd21            // Pterm0
	cmp.w #0x31,D0         // Ptermres
	beq.s .gd21   
	cmp.w #0x4C,D0         // Pterm
	bne.s .gd22
.gd21:
	jsr _cd_pterm
	bra .gd1               // call default GEMDOS routine
.gd22:
	cmp.w #0x36,D0         // Dfree
	bne.s .gd15
	move.w 6(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.l 2(A0),-(SP)
	jsr _cd_dfree
	bra .gd19
.gd15:
	cmp.w #0x39,D0         // Dcreate
	bne.s .gd14
	move.l 2(A0),-(SP)
	jsr _cd_dcreate
	bra .gd20
.gd14:
	cmp.w #0x3A,D0         // Ddelete
	bne.s .gd13
	move.l 2(A0),-(SP)
	jsr _cd_ddelete
	bra .gd20
.gd13:
	cmp.w #0x3B,D0         // Dsetpath
	bne.s .gd25
	move.l 2(A0),-(SP)
	jsr _cd_dsetpath
	bra .gd20
.gd25:
	cmp.w #0x3C,D0         // Fcreate
	bne.s .gd12
	move.w 6(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.l 2(A0),-(SP)
	jsr _cd_fcreate
	bra .gd19
.gd12:
	cmp.w #0x3D,D0         // Fopen
	bne.s .gd11
	move.w 6(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.l 2(A0),-(SP)
	jsr _cd_fopen
	bra .gd19
.gd11:
	cmp.w #0x3E,D0         // Fclose
	bne.s .gd10
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP)
	jsr _cd_fclose
	bra.s .gd20
.gd10:
	cmp.w #0x3F,D0         // Fread
	bne.s .gd9
	move.l 8(A0),-(SP)
	move.l 4(A0),-(SP)
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP)
	jsr _cd_fread
	bra .gd18
.gd9:
	cmp.w #0x40,D0         // Fwrite
	bne.s .gd8
	move.l 8(A0),-(SP)
	move.l 4(A0),-(SP)
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP)
	jsr _cd_fwrite
	bra .gd18
.gd8:
	cmp.w #0x41,D0         // Fdelete
	bne.s .gd7
	move.l 2(A0),-(SP)
	jsr _cd_fdelete
.gd20:
	addq.l #4,SP
	bra .gd17
.gd7:
	cmp.w #0x42,D0         // Fseek
	bne.s .gd6
	move.w 8(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.w 6(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.l 2(A0),-(SP)
	jsr _cd_fseek
	bra .gd18
.gd6:
	cmp.w #0x43,D0         // Fattrib
	bne.s .gd5
	move.w 8(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.w 6(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.l 2(A0),-(SP)
	jsr _cd_fattrib
	bra .gd18
.gd5:
	cmp.w #0x47,D0         // Dgetpath
	bne.s .gd24
	move.w 6(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.l 2(A0),-(SP)	
             jsr _cd_dgetpath
             bra .gd19
.gd24:
	cmp.w #0x4B,D0         // Pexec
	bne.s .gd23
	movel A0,-(SP)
	move.l 12(A0),-(SP)
	move.l 8(A0),-(SP)
	move.l 4(A0),-(SP)
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP)
	jsr _cd_pexec
	move.l (SP)+,D1
	lea 12(SP),SP
	move.l (SP)+,A0
	tst.l D0
	bmi .gd17              // error
	cmp.l #3,D1            // PE_LOAD
	beq.s .gd17
	move.l D0,8(A0)        // basepage
	moveq #4,D0
	move.w D0,2(A0)        // PE_GO
	bra.s .gd1
.gd23:
	cmp.w #0x4E,D0         // Fsfirst
	bne.s .gd4
	move.w 6(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.l 2(A0),-(SP)
	jsr _cd_fsfirst
	bra.s .gd19
.gd4:
	cmp.w #0x4F,D0         // Fsnext
	bne.s .gd3
	jsr _cd_fsnext
	bra.s .gd17
.gd3:
	cmp.w #0x56,D0         // Frename
	bne.s .gd2
	move.l 6(A0),-(SP)
	move.l 2(A0),-(SP)
	jsr _cd_frename
.gd19:
	addq.l #8,SP	
	bra.s .gd17
.gd2:
	cmp.w #0x57,D0         // Fdatime
	bne.s .gd1
	move.w 8(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.w 6(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.l 2(A0),-(SP)
	jsr _cd_fdatime
.gd18:
	lea 12(SP),SP
.gd17:
	cmp.l #-46,D0          // EDRIVE
	beq.s .gd1             // call default GEMDOS routine
.gd26:
	movem.l (SP)+,D1-D2/A1-A2
	rte
.gd1:
	movem.l (SP)+,D1-D2/A1-A2
	move.l _old_vector_gemdos,-(SP)
	rts


