/* TOS 4.04 VDI for the CT60/CTPCI boards
 * Didier Mequignon 2005, e-mail: aniplay@wanadoo.fr
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
 * along with ARAnyM; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
	.text

#include "types.inc" /* fVDI structures */

// #define DEBUG

#define _timr_ms  0x442
#define _v_bas_ad 0x44E
#define _sysbase  0x4F2
#define proc_type 0x59E

#define MAX_WORK  128

/* var VDI */
#define CUR_FONT -906
#define M_POS_HX -856
#define M_POS_HY -854
#define M_PLANES -852
#define M_CDB_BG -850
#define M_CDB_FG -848
#define MASKFORM -846
#define INQ_TAB -782
#define DEV_TAB -692
#define G_CURX -602
#define G_CURY -600
#define M_HID_CT -598
#define MOUSE_BT -596
#define REQ_COL48 -594 // 16 colors RVB
#define SIZ_TAB15 -498
#define CUR_WORK -464
#define DEF_FONT -460
#define FONT_RING -456
#define FONT_COUNT -440
#define CUR_MS_STAT -348
#define V_HID_CNT -346
#define CUR_X -344
#define CUR_Y -342
#define CUR_FLAG -340
#define MOUSE_FLAG -339
#define V_SAV_X -334
#define V_SAV_Y -332
#define SAVE_LEN -330
#define SAVE_ADR -328
#define SAVE_STAT -324
#define SAVE_AREA -322
#define USER_TIM -66
#define NEXT_TIM -62
#define USER_BUT -58
#define USER_CUR -54
#define USER_MOT -50
#define V_CEL_HT -46
#define V_CEL_MX -44
#define V_CEL_MY -42
#define V_CEL_WR -40
#define V_COL_BG -38
#define V_COL_FG -36
#define V_CUR_AD -34
#define V_CUR_OFF -30
#define V_CUR_X -28
#define V_CUR_Y -26
#define V_PERIOD -24
#define V_CUR_CT -23
#define V_FNT_AD -22
#define V_FNT_ND -18
#define V_FNT_ST -16
#define V_FNT_WD -14
#define V_REZ_HZ -12
#define V_OFF_AD -10
#define V_REZ_VT -4
#define BYTES_LN -2
#define V_PLANES 0
#define V_LIN_WR 2
#define _WRT_MODE 36
#define _PATPTR 46
#define _PATMSK 50
#define _MULTIFILL 52
#define _CLIP 54
#define _XMN_CLIP 56
#define _DDA_INC 66
#define _T_SCLSTS 68
#define _MONO_STATUS 70
#define _SOURCE_X 72
#define _SOURCE_Y 74
#define _STYLE 90
#define _SCALE 102
#define _CHUP 104
#define REQ_COL48E 174 // 240 colors RVB TOS 4.XX FALCON

/* workstation */
#define CHUP 0
#define CLIP 2
#define ADR_FONT 4
#define MULTIFILL 10
#define PATMSK 12
#define PATPTR 14
#define STYLE 26
#define FILL_COLOR_INDEX 30
#define FILL_STYLE_INDEX 32
#define FILL_PER_VISIB 34
#define FILL_INT_STYLE 36
#define HORIZONTAL_ALIGN 38
#define BEGIN_STYLE 42
#define LINE_COLOR_INDEX 44
#define END_STYLE 46
#define LINE_TYPE 48
#define LINE_WIDTH 50
#define MARK_COLOR_INDEX 56
#define MARK_HEIGHT 58
#define MARK_TYPE 60
#define TEXT_COLOR_INDEX 162
#define USER_DEF_LINE_STYLE_PAT 164
#define USER_DEF_FILL_PAT 166
#define VERTICAL_ALIGN 1190 // special TOS 4.XX FALCON
#define WRT_MODE 1192
#define XMN_CLIP 1196
#define XMX_CLIP 1198
#define YMN_CLIP 1200
#define YMX_CLIP 1202

/* font */
#define FACE_ID 0
#define FIRST_ADE 36
#define LAST_ADE 38
#define TOP_LINE 40
#define ASCENT_LINE 42
#define HALF_LINE 44
#define DESCENT_LINE 46
#define BOTTOM_LINE 48
#define CHARACTER_WIDTH 50
#define CELL_WIDTH 52
#define LEFT_OFFSET 54
#define RIGTH_OFFSET 56
#define THICKENING 58
#define FONTFLAGS 66
#define OFF_TABLE 72
#define FONTDAT 76
#define FORMWIDTH 80
#define FORMHEIGHT 82

	.global _init_det_vdi,_det_vdi,_old_vector_vdi
	.global _opnwk,_clswk,_resolution
	.global _wide_line,_allocate_block,_free_block
	.global _fill_poly,_filled_poly,_fill_spans,_solid,_pattern_ptrs
	.global _ellipsearc,_c_pline,_rounded_box
	.global _vq_chcells,_v_exit_cur,_v_enter_cur,_v_curup
	.global _v_curdown,_v_curright,_v_curleft,_v_curhome
	.global _v_eeos,_v_eeol,_vs_curaddress,_v_curtext
	.global _v_rvon,_v_rvoff,_vq_curaddress,_vq_tabstatus
	.global _fill_area,_get_extent,_draw_text
	.global _init_var_linea,_c_get_width_virtual,_c_get_height_virtual,_c_get_bpp
	.global _cursor_home,_eddi_cookie

_init_det_vdi:

	move.l 4(SP),fvdi_virtual
	movem.l D0-D2/A0-A2,-(SP)
	dc.w 0xA000
	move.l A0,adr_var_vdi
	lea tab_cur_work,A0
	move.w #MAX_WORK-1,D0
.iv1:
		clr.l (A0)+
	dbf D0,.iv1
	movem.l (SP)+,D0-D2/A0-A2
	rts
	
#ifdef DEBUG

display_string:

	movem.l D0/A0,-(SP)
.os2:
		move.b (A0)+,D0
		beq.s .os1
		bsr display_char
	bra.s .os2
.os1:
	movem.l (SP)+,D0/A0
	rts

hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s hex_word
	move.l (SP)+,D0
hex_word:
	move.w D0,-(SP)
	lsr.w #8,D0          
	bsr.s hex_byte     
	move.w (SP)+,D0
hex_byte:
	move.w D0,-(SP)
	lsr.b #4,D0        
	bsr.s hex_char      
	move.w (SP)+,D0      
hex_char:
	and.b #0xF,D0      
	or.b #0x30,D0      
	cmp.b #0x3A,D0     
	bcs.s display_char  
	addq.b #7,D0   

display_char:

	movem.l D0-D2/A0-A2,-(SP)
	move.w D0,-(SP)
	move.w #2,-(SP)
	move.w #3,-(SP)          // Bconout
	trap #13
	addq.w #6,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts
#endif

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0                   // cannot store here because we are in flash

_det_vdi:

	cmp #0x73,D0             // VDI
	bne .v1
	movem.l A0-A3,-(SP)
	move.l D1,A1
	move.l (A1),A3           // CONTRL
	move.w (A3),D0           // opcode function
	subq.w #1,D0
	beq.s .v2                // v_opnwk, no handle
	cmp.w #131,D0            // vqt_fontinfo
	bcc.s .v3
#if 0 // #ifdef DEBUG
	move.w D0,-(SP)
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
	move.w (SP),D0
	bsr hex_word
	move.w (SP)+,D0
#endif
	add.w D0,D0
	move.w tab_vdi(PC,D0.w),D0
	bmi.s .v3                // TOS function
	swap D0
	move.w 12(A3),D0         // VDI handle
	subq.w #1,D0
	cmp.w #MAX_WORK,D0
	bcc.s .v3
	asl.w #2,D0
	lea tab_cur_work,A0
	tst.l (A0,D0.w)
	ble.s .v4                // no init or workstation
	move.l (A0,D0.w),A2
	move.l adr_var_vdi,A0
	move.l A2,CUR_WORK(A0)
	swap D0
	jmp tab_vdi(PC,D0.w)
.v2:
	jmp det_v_opnwk(PC)
.v4:
	bmi.s .v3                // workstation closed
	jmp det_v_opnwk(PC)      // use the tos routine and tab_cur_work init with handle
.v3:
#if 0 // #ifdef DEBUG
	moveq #0x2D,D0
	bsr display_char
#endif
	movem.l (SP)+,A0-A3
	moveq #0x73,D0
.v1:
	move.l _old_vector_vdi,-(SP)
	rts

tab_vdi:                              // functions 1 to 131

	dc.w det_v_opnwk-tab_vdi
	dc.w det_v_clswk-tab_vdi
	dc.w -1                  // v_clrwk
	dc.w -1                  // v_updwk
	dc.w det_escapes-tab_vdi // ESCAPES
	dc.w -1 // det_v_pline-tab_vdi
	dc.w -1                  // v_p_marker
	dc.w -1 // det_v_gtext-tab_vdi
	dc.w det_v_fillarea-tab_vdi
	dc.w -1                  // v_cellarray
	dc.w det_gdps-tab_vdi
	dc.w -1                  // vst_height
	dc.w det_vst_rotation-tab_vdi
	dc.w det_vs_color-tab_vdi
	dc.w det_vsl_type-tab_vdi
	dc.w det_vsl_width-tab_vdi
	dc.w det_vsl_color-tab_vdi
	dc.w det_vsm_type-tab_vdi
	dc.w -1                  // vsm_height
	dc.w det_vsm_color-tab_vdi
	dc.w -1                  // vst_font
	dc.w det_vst_color-tab_vdi
	dc.w det_vsf_interior-tab_vdi
	dc.w det_vsf_style-tab_vdi
	dc.w det_vsf_color-tab_vdi
	dc.w det_vq_color-tab_vdi
	dc.w -1                  // vq_cellarray
	dc.w -1                  // vrq_locator/vsm_locator
	dc.w -1                  // vrq_valuator/vrm_locator
	dc.w -1                  // vrq_choice/vrm_choice
	dc.w -1                  // vrq_string/vrm_string
	dc.w det_vswr_mode-tab_vdi
	dc.w det_vsin_mode-tab_vdi
	dc.w -1
	dc.w det_vql_attributes-tab_vdi
	dc.w det_vqm_attributes-tab_vdi
	dc.w det_vqf_attributes-tab_vdi
	dc.w det_vqt_attributes-tab_vdi
	dc.w det_vst_alignment-tab_vdi
	.rep 60
	dc.w -1                  // opcodes 40-99
	.endr
	dc.w det_v_opnvwk-tab_vdi
	dc.w det_v_clsvwk-tab_vdi
	dc.w det_vq_extend-tab_vdi
	dc.w -1                  // v_contourfill
	dc.w det_vsf_perimeter-tab_vdi
	dc.w det_v_get_pixel-tab_vdi
	dc.w det_vst_effects-tab_vdi
	dc.w -1                  // vst_point
	dc.w det_vsl_ends-tab_vdi
	dc.w -1 // det_vro_cpyfm-tab_vdi
	dc.w -1                  // vr_trnfm
	dc.w -1 // det_vsc_form-tab_vdi
	dc.w det_vsf_updat-tab_vdi
	dc.w det_vsl_udsty-tab_vdi
	dc.w -1 // det_vr_recfl-tab_vdi
	dc.w det_vqin_mode-tab_vdi
	dc.w det_vqt_extent-tab_vdi
	dc.w -1                  // vqt_width
	dc.w det_vex_time-tab_vdi
	dc.w -1                  // vst_load_fonts
	dc.w -1                  // vst_unload_fonts
	dc.w -1 // det_vrt_cpyfm-tab_vdi
	dc.w -1 // det_v_show_c-tab_vdi
	dc.w -1 // det_v_hide_c-tab_vdi
	dc.w det_vq_mouse-tab_vdi
	dc.w det_vex_butv-tab_vdi
	dc.w det_vex_motv-tab_vdi
	dc.w det_vex_curv-tab_vdi
	dc.w det_vq_key_s-tab_vdi
	dc.w det_vs_clip-tab_vdi
	dc.w -1                  // vqt_name
	dc.w det_vqt_fontinfo-tab_vdi

det_v_opnwk:

	move.l A3,save_contrl
	move.l 4(A1),save_intin
	move.l 12(A1),save_intout
	movem.l (SP)+,A0-A3      // fix for RTE
	moveq #0x73,D0
	tst.w proc_type
	beq .owk1
	clr.w -(SP)              // format if > 68000
	bra .owk1
.owk2:
	movem.l D0-D2/A0-A2,-(SP) // return from v_opnwk
	move.l save_contrl,A0
	move.w 12(A0),D0         // handle
	subq.w #1,D0
	cmp.w #MAX_WORK,D0
	bcc .owk3
	asl.w #2,D0
	lea tab_cur_work,A1
	move.l save_intin,A0
	cmp.w #10,(A0)           // ID device
	bgt .owk4                // <> screen
	move.l adr_var_vdi,A0
	move.l CUR_WORK(A0),(A1,D0.w)
	jsr _c_get_width_virtual
	move.l save_intout,A0
	move.w D0,(A0)           // width in pixels
	jsr _c_get_height_virtual
	move.l save_intout,A0
	move.w D0,2(A0)          // height in pixels
	jsr _c_get_bpp
	move.l save_intout,A0
	moveq #0,D1
	bset D0,D1               // nb colors
	cmp.l #256,D1
	bcs.s .owk5
	move.w #256,D1
.owk5:
	move.w D1,26(A0)         // nb colors
	move.w #744,D0
	cmp.w #400,(A0)          // width in pixels
	bcs.s .owk6
	lsr.w #1,D0
.owk6:
	move.w D0,DEV_TAB+6(A0)  // width point in mm/1000
	move.w #744,D0
	cmp.w #350,2(A0)         // height in pixels
	bcs.s .owk7
	lsr.w #1,D0
.owk7:
	move.w D0,DEV_TAB+8(A0)  // heigth point in mm/1000
	clr.w _resolution        // resolution.used
	st.b mouse_semaphore
	move.l fvdi_virtual,-(SP)
	jsr _opnwk
	addq.w #4,SP
	move.w SR,-(SP)
	or.w #0x700,SR
	move.l adr_var_vdi,A0
	lea mov_cur,A1           // mouse
	move.l USER_CUR(A0),old_curv
//	move.l A1,USER_CUR(A0)
	lea vb_draw,A1
	move.l USER_TIM(A0),old_timv
//	move.l A1,USER_TIM(A0)
	clr.b mouse_semaphore
	move.w (SP)+,SR
	bra.s .owk3
.owk4:
	move.l #-1,(A1,D0.w)     // num ID invalid
.owk3:
	movem.l (SP)+,D0-D2/A0-A2
	rte
.owk1:
	pea .owk2(PC)            // return after the TOS routine
	move.w SR,-(SP)
	move.l _old_vector_vdi,-(SP)
	rts

det_v_clswk:

	move.w 12(A3),D0         // handle
	subq.w #1,D0
	cmp.w #MAX_WORK,D0
	bcc.s .cwk1
	asl.w #2,D0
	lea tab_cur_work,A1
	clr.l (A1,D0.w)
	move.w SR,-(SP)
	or.w #0x700,SR
	st.b mouse_semaphore
	move.l old_curv,USER_CUR(A0)
	move.l A1,USER_CUR(A0)
	move.l old_timv,USER_TIM(A0)
	move.w (SP)+,SR
	move.l fvdi_virtual,-(SP)
	jsr _clswk
	addq.w #4,SP
.cwk1:
	movem.l (SP)+,A0-A3
	moveq #0x73,D0
	move.l _old_vector_vdi,-(SP)
	rts

det_escapes:

	move.w 10(A3),D0         // sub-function
	subq.w #1,D0
	bmi.s .de1
	cmp.w #23,D0
	bcc.s .de1
	add.w D0,D0
	tst.w tab_vdi(PC,D0.w)
	bmi.s .de2               // TOS function
	jmp tab_escapes(PC,D0.w)
.de1:
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
.de2:
	movem.l (SP)+,A0-A3
	moveq #0x73,D0
	move.l _old_vector_vdi,-(SP)
	rts

tab_escapes:

	dc.w det_vq_chcells-tab_escapes
	dc.w det_v_exit_cur-tab_escapes
	dc.w det_v_enter_cur-tab_escapes
	dc.w det_v_curup-tab_escapes
	dc.w det_v_curdown-tab_escapes
	dc.w det_v_curright-tab_escapes
	dc.w det_v_curleft-tab_escapes
	dc.w det_v_curhome-tab_escapes
	dc.w det_v_eeos-tab_escapes
	dc.w det_v_eeol-tab_escapes
	dc.w det_vs_curaddress-tab_escapes
	dc.w det_v_curtext-tab_escapes
	dc.w det_v_rvon-tab_escapes
	dc.w det_v_rvoff-tab_escapes
	dc.w det_vq_curaddress-tab_escapes
	dc.w -1 // vq_tabstatus
	dc.w -1 // v_hardcopy
	dc.w -1 // v_dspcur
	dc.w -1 // v_rmcur
	dc.w -1 // v_form_adv
	dc.w -1 // v_output_window
	dc.w -1 // v_clear_disp_list
	dc.w -1 // v_bit_image

det_vq_chcells:

	movem.l D1-D2,-(SP)
	move.w #2,8(A3)          // length tab INTOUT
	move.l 12(A1),A0         // INTOUT
	pea 2(A0)
	pea (A0)
	move.l fvdi_virtual,-(SP)
	jsr _vq_chcells
	lea 12(SP),SP
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_exit_cur:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_exit_cur
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_enter_cur:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_enter_cur
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_v_curup:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,(SP)
	jsr _v_curup
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_curdown:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_curdown
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_v_curright:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_curright
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_curleft:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_curleft
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_curhome:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_curhome
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_eeos:
	
	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_eeos
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_v_eeol:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_eeol
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_vs_curaddress:

	movem.l D1-D2,-(SP)
	move.l 4(A1),A0          // INTIN
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.w (A0),D0
	ext.l D0
	move.l D0,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _vs_curaddress
	lea 12(SP),SP
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_curtext:

	movem.l D1-D2,-(SP)
	move.w 6(A3),D0          // length tab INTIN
	ext.l D0
	move.l D0,-(SP)
	move.l 4(A1),-(SP)       // INTIN
	move.l fvdi_virtual,-(SP)
	jsr _v_curtext
	lea 12(SP),SP
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_rvon:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_rvon
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_v_rvoff:

	movem.l D1-D2,-(SP)
	move.l fvdi_virtual,-(SP)
	jsr _v_rvoff
	addq.w #4,a7
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_vq_curaddress:

	movem.l D1-D2,-(SP)
	move.w #2,8(A3)          // length tab INTOUT
	move.l 12(A1),A0         // INTOUT
	pea 2(A0)
	pea (A0)
	move.l fvdi_virtual,-(SP)
	jsr _vq_curaddress
	lea 12(SP),SP
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_v_pline:

	movem.l D1-D6,-(SP)
	move.l 8(A1),A0          // PTSIN
	move.w 2(A3),D6          // nb points PTSOUT
	cmp.w #1,LINE_WIDTH(A2)
	bhi .pl6                 // wide line
.pl7:
	cmp.w #2,D6
	blt .pl1
	moveq #0,D5
	move.w USER_DEF_LINE_STYLE_PAT(A2),D5
	move.w LINE_TYPE(A2),D0
	cmp.w #6,D0
	bcc.s .pl2
	lea tab_line_type,A0
	add.w D0,D0
	move.w (A0,D0.w),D5
.pl2:
	subq.w #1,d6
	bra.s .pl5
.pl3:
		movem.w (A0),D1-D4 // X1, Y1, X2, Y2
		bsr clip_line
		beq.s .pl4
		move.w D6,-(SP)
		moveq #0,D0
		move.w LINE_COLOR_INDEX(A2),D0
		moveq #0,D6
		move.w WRT_MODE(A2),D6	
/*--------
* Draw a colored line between 2 points
* c_draw_line(Virtual *vwk, long x1, long y1, long x2, long y2, long pattern, long colour, long mode)
* In:	a0	VDI struct (odd address marks table operation)
*	d0	line colour
*	d1	x1 or table address
*	d2	y1 or table length (high) and type (0 - coordinate pairs, 1 - pairs+moves)
*	d3	x2 or move point count
*	d4	y2 or move index address
*	d5	pattern
*	d6	mode
*--------*/
		move.l fvdi_virtual,A0
		move.l vwk_real_address(A0),A3
		move.l wk_r_line(A3),A3
		jsr (A3)
		move.w (SP)+,D6
.pl4:
		addq.w #4,A0
.pl5:
	dbf d6,.pl3
	bra.s .pl1
.pl6:
	movem.l A0-A2,-(SP)
	clr.l -(SP)              // get a memory block of any size (hopefully large)
	jsr _allocate_block
	addq.w #4,SP
	movem.l (SP)+,A0-A2
	tst.l D0
	beq.s .pl7               // error
	move.l D0,-(SP)          // save for later
	moveq #0,D2
	move.w WRT_MODE(A2),d2
	move.l D2,-(SP)          // mode
	move.l D0,-(SP)          // points
	moveq #0,D0
	move.w LINE_COLOR_INDEX(A2),D0
	move.l D0,-(SP)          // color
	moveq #0,D0
	move.w D6,D0             // nb points PTSOUT
	move.l D0,-(SP)          // numpts
	move.l A0,-(SP)          // pts
	move.l fvdi_virtual,A0   // vwk
	move.w LINE_WIDTH(A2),vwk_line_width(A0)
	move.l A0,-(SP)
// wide_line(Virtual *vwk, short *pts, long numpts, long colour, short *points, long mode)
	jsr _wide_line
	lea 24(SP),SP
	jsr _free_block
	addq.w #4,SP
.pl1:
	movem.l (SP)+,D1-D6
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

clip_line:  // D1:X1, D2:Y1, D3:X2, D4:Y2, return flag drawing if D0 <> 0
            // and update D1-D4 for clipping

	tst.w CLIP(A2)           // clipping
	beq .cl19                // clipping off
	movem.l A0-A3/D5-D7,-(SP)
	movem.w XMN_CLIP(A2),A0-A3 // coords X1,X2,Y1,Y2 clipping
.cl14:
	moveq #0,D0              // flags for fix coords clipping
	moveq #0,D5              // flags for fix reverse coords
	cmp.w A0,D1
	bge.s .cl3               // X1 inside left clipping
	addq.w #1,D0             // flag left clipping
	cmp.w A0,D3
	bge.s .cl4               // X2 inside left clipping
	bra.s .cl2
.cl3:
	cmp.w A0,D3
	bge.s .cl4               // X2 inside left clipping
	addq.w #1,D5             // left clipping
.cl4:
	cmp.w A2,D2
	bge.s .cl17              // Y1 inside top clipping
	addq.w #2,D0             // top clipping
	cmp.w A2,D4
	bge.s .cl5               // Y2 inside top clipping
	bra.s .cl2
.cl17:
	cmp.w A2,D4
	bge.s .cl5               // Y2 inside top clipping
	addq.w #2,D5             // top clipping
.cl5:
	cmp.w A1,D1
	ble.s .cl6               // X1 inside right clipping
	addq.w #4,D0             // right clipping
	cmp.w A1,D3
	ble.s .cl7               // X2 inside right clipping
	bra.s .cl2
.cl6:
	cmp.w A1,D3
	ble.s .cl7               // X2 inside right clipping
	addq.w #4,D5             // right clipping
.cl7:
	cmp.w A3,D2              // Y1 inside low clipping
	ble.s .cl8
	addq.w #8,D0             // low clipping
	cmp.w A3,D4              // Y2 inside low clipping
	ble.s .cl10
.cl2:
	moveq #0,D0              // coords unchanged
	bra .cl1
.cl8:
	cmp.w A3,D4
	ble.S .cl10              // Y2 inside low clipping
	addq.w #8,D5             // low clipping
.cl10:
	tst.w D0
	bne.s .cl18
	tst.w D5
	beq .cl9
	exg D1,D3
	exg D2,D4
	move.w D5,D0
.cl18:
	btst #0,D0               // left clipping
	beq.s .cl11
	move.w D4,D6
	sub.w D2,D6
	move.w A0,D7
	sub.w D1,D7
	muls D7,D6
	move.w D3,D7
	sub.w D1,D7
	divs D7,D6
	add.w D6,D2
	move.w A0,D1
	bra.s .cl15
.cl11:
	btst #2,D0               // right clipping
	beq.s .cl12
	move.w D4,D6
	sub.w D2,D6
	move.w A1,D7
	sub.w D1,D7
	muls D7,D6
	move.w D3,D7
	sub.w D1,D7
	divs D7,D6
	add.w D6,D2
	move.w A1,D1
.cl15:
	swap D6
	lsr.w #1,D7
	cmp.w D7,D6
	blt .cl14
	addq.w #1,D2
	bra .cl14
.cl12:
	btst #1,D0               // top clipping
	beq.s .cl13
	move.w D3,D6
	sub.w D1,D6
	move.w A2,D7
	sub.w D2,D7
	muls D7,D6
	move.w D4,D7
	sub.w D2,D7
	divs D7,D6
	add.w D6,D1
	move.w A2,D2
	bra.s .cl16
.cl13:
	move.w D3,D6             // low clipping
	sub.w D1,D6
	move.w A3,D7
	sub.w D2,D7
	muls D7,D6
	move.w D4,D7
	sub.w D2,D7
	divs D7,D6
	add.w D6,D1
	move.w A3,D2
.cl16:
	swap D6
	lsr.w #1,D7
	cmp.w D7,D6
	blt .cl14
	addq.w #1,D1
	bra .cl14
.cl19:
 	moveq #1,D0
 	rts
.cl9:
	moveq #1,D0              // drawing with new coords
.cl1:
	movem.l (SP)+,A0-A3/D5-D7
	rts
	
det_v_gtext:

	moveq #0,D0
	move.w 6(A3),D0          // length tab INTIN
	ble .vg1
	move.l 4(A1),A0          // INTIN
	
gtext:

	movem.l D1-D2,-(SP)
	move.l A0,A3             // INTIN
	move.l 8(A1),A0          // PTSIN
	move.l (A0),D1           // X1,Y1 destination
	tst.w HORIZONTAL_ALIGN(A2)
	beq.s .vg2               // left justified
	move.l D1,-(SP)
	link A6,#-16
	movem.l D0/A0-A1,-(SP)
	move.w 6(A3),D0          // length tab INTIN
	move.l 4(A1),A0          // INTIN
	lea -16(A6),A1           // PTSOUT		
	bsr vqt_extent
	move.w -4(A6),D1         // X4
	movem.l (SP)+,D0/A0-A1
	unlk A6
	cmp.w #2,HORIZONTAL_ALIGN(A2)
	beq.s .vg3               // right justified
	lsr.w #1,d1 
.vg3:
	neg.w d1
	swap d1
	clr.w d1
	add.l (SP)+,D1           // X1,Y1 destination
.vg2:
	move.l A3,A1             // INTIN => string
	sub.l A2,A2              // no special offset table
/*--------
* Draw some text
* c_text_area(Virtual *vwk, short *text, long length, long dst_x, long dst_y, short *offsets)
* In:	a0	VDI struct
*	a1	string address
*	a2	offset table
*	d0	string length
*	d1	x1,y1 destination
*-------*/
	move.l fvdi_virtual,A0
	moveq #0,D7
	move.w TEXT_COLOR_INDEX(A2),D7
	move.l D7,vwk_text_colour(A0)
	move.w CHUP(A2),vwk_text_rotation(A0)
	move.w HORIZONTAL_ALIGN(A2),vwk_text_alignment_horizontal(A0)
	move.w VERTICAL_ALIGN(A2),vwk_text_alignment_vertical(A0)
	move.w STYLE(A2),vwk_text_effects(A0)
	move.w WRT_MODE(A2),vwk_mode(A0)
	move.l ADR_FONT(A2),vwk_text_current_font(A0)
	move.w CLIP(A2),vwk_clip_on(A0)
	move.w XMN_CLIP(A2),vwk_clip_rectangle_x1(A0)
	move.w XMN_CLIP+2(A2),vwk_clip_rectangle_x2(A0)	
	move.w XMN_CLIP+4(A2),vwk_clip_rectangle_y1(A0)
	move.w XMN_CLIP+6(A2),vwk_clip_rectangle_y2(A0)	
	move.l vwk_real_address(A0),A3
	move.l wk_r_text(A3),A3
	jsr (A3)
	movem.l (SP)+,D1-D2
.vg1:
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_fillarea:

	tst.w 6(A3)              // length tab INTIN
	ble .vfa1             
	movem.l D1-D7,-(SP)
	move.l 8(A1),D1          // PTSIN
	moveq #0,D2
	move.w 6(A3),D2          // length tab INTIN
	moveq #0,D3
	moveq #0,D4
	bsr get_pattern
	move.l A0,D5             // pattern
	moveq #0,D6
	move.w WRT_MODE(A2),D6
	move.l D0,D7             // interior/style
/*--------
* Fill a multiple bitplane polygon using a monochrome pattern
* c_fill_polygon(Virtual *vwk, short points[], long n, short index[], long moves, short *pattern, long colour, long mode, long interior_style)
* In:	a0	VDI struct
*	d0	colours
*	d1	points address
*	d2	number of points
*	d3	index address
*	d4	number of indices
*	d5	pattern address
*	d6	mode
*	d7	interior/style
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_r_fillpoly(A3),D0
	beq.s .vfa2              // no accel poly
	move.l D0,A3
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
	jsr (A3)
	movem.l (SP)+,D1-D7
	bra .vfa1
.vfa2:
	movem.l A0-A2,-(SP)
	clr.l -(SP)              // get a memory block of any size (hopefully large)
	jsr _allocate_block
	addq.w #4,SP
	movem.l (SP)+,A0-A2
	tst.l D0
	beq.s .vfa3              // error
	move.l D0,-(SP)          // save for later
	move.l D7,-(SP)          // interior/style
	move.l D6,-(SP)          // mode
	move.l D0,-(SP)          // points
	move.l D5,-(SP)          // pattern
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
	move.l D0,-(SP)          // color
	move.l D2,-(SP)          // nb points PTSOUT
	move.l D1,-(SP)          // pts
	move.l A0,-(SP)          // vwk
// filled_poly(Virtual *vwk, short *pts, long n, long colour, short *pattern, short *points, long mode, long interior_style)
	jsr _filled_poly
	lea 24(SP),SP
	jsr _free_block
.vfa3:
	movem.l (SP)+,D1-D7	
.vfa1:
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
get_pattern:

	move.w D1,-(SP)
	moveq #0,D0
	move.w FILL_INT_STYLE(A2),D0
	move.w D0,D1
	swap D0
	cmp.w #4,D1              // user pattern
	bne.s .gp1
	lea USER_DEF_FILL_PAT(A2),A0
	bra.s .gp5
.gp1:
	cmp.w #3,D1              // pattern
	bne.s .gp2
	lea tab_pattern,A0
	bra.s .gp3
.gp2:
	cmp.w #2,D1              // frames
	bne.s .gp4
	lea tab_frames,A0
.gp3:
	move.w FILL_STYLE_INDEX(A2),D0 // index fill pattern
	asl.w #5,D0              // *32
	add.w D0,A0
	move.w FILL_STYLE_INDEX(A2),D0
	bra.s .gp5
.gp4:
	lea tab_full_pattern,A0
	cmp.w #1,D1              // color
	beq.s .gp5
	lea tab_empty_pattern,A0 // no fill
.gp5:
	move.w (SP)+,D1
	rts

det_gdps:

	move.w 10(A3),D0         // sub-function
	subq.w #1,D0
	bmi.s .gd1
	cmp.w #10,D0
	bcc.s .gd1
	add.w D0,D0
	jmp tab_sub_vdi(PC,D0.w)
.gd1:
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

tab_sub_vdi:

	dc.w det_v_bar-tab_sub_vdi
	dc.w det_v_arc-tab_sub_vdi
	dc.w det_v_pie-tab_sub_vdi
	dc.w det_v_circle-tab_sub_vdi
	dc.w det_v_ellipse-tab_sub_vdi
	dc.w det_v_ellarc-tab_sub_vdi
	dc.w det_v_ellpie-tab_sub_vdi
	dc.w det_v_rbox-tab_sub_vdi
	dc.w det_v_rfbox-tab_sub_vdi
	dc.w det_v_justified-tab_sub_vdi

det_v_bar:

	move.l 8(A1),A0          // PTSIN
	tst.w FILL_INT_STYLE(A2)
	bne.s .vbar9
	tst.w FILL_PER_VISIB(A2)
	bne.s .vbar8
.vbar9:
	bsr rectangle
	tst.w FILL_PER_VISIB(A2)
	beq .vbar1
.vbar8:
	movem.l D1-D7,-(SP)
	lea tab_full_pattern,A3
	move.l A3,D5             // pattern
	moveq #0,D6
	move.w WRT_MODE(A2),D6
	move.l #0x00010000,D7    // solid
	movem.w (A0),D1-D4       // X1, Y1, X2, Y2
	// draw top/bottom perimeter
	move.w D2,D4
	bsr clip_rect
	beq.s .vbar7
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
/*--------
* Fill a multiple bitplane area using a monochrome pattern
* c_fill_area(Virtual *vwk, long x, long y, long w, long h, short *pattern, long colour, long mode, long interior_style)
* In:	a0	VDI struct (odd address marks table operation)
*	d0	colours
*	d1	x1 destination or table address
*	d2	y1    - " -    or table length (high) and type (0 - y/x1/x2 spans)
*	d3-d4	x2,y2 destination
*	d5	pattern address
*	d6	mode
*	d7	interior/style
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_r_fill(A3),A3
	jsr (A3)
.vbar7:
	movem.w (A0),D1-D4       // X1, Y1, X2, Y2
	// draw bottom/top perimeter
	cmp.w D2,D4
	beq .vbar2
	move.w D4,D2
	bsr clip_rect
	beq.s .vbar6
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
/*--------
* Fill a multiple bitplane area using a monochrome pattern
* c_fill_area(Virtual *vwk, long x, long y, long w, long h, short *pattern, long colour, long mode, long interior_style)
* In:	a0	VDI struct (odd address marks table operation)
*	d0	colours
*	d1	x1 destination or table address
*	d2	y1    - " -    or table length (high) and type (0 - y/x1/x2 spans)
*	d3-d4	x2,y2 destination
*	d5	pattern address
*	d6	mode
*	d7	interior/style
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_r_fill(A3),A3
	jsr (A3)
.vbar6:
	movem.w (A0),D1-D4       // X1, Y1, X2, Y2
	// draw left perimeter
	cmp.w D2,D4
	bge .vbar5
	exg D2,D4
.vbar5:
	addq.w #1,D2
	subq.w #1,D4
	move.w D1,D3
	bsr clip_rect
	beq.s .vbar4
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
/*--------
* Fill a multiple bitplane area using a monochrome pattern
* c_fill_area(Virtual *vwk, long x, long y, long w, long h, short *pattern, long colour, long mode, long interior_style)
* In:	a0	VDI struct (odd address marks table operation)
*	d0	colours
*	d1	x1 destination or table address
*	d2	y1    - " -    or table length (high) and type (0 - y/x1/x2 spans)
*	d3-d4	x2,y2 destination
*	d5	pattern address
*	d6	mode
*	d7	interior/style
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_r_fill(A3),A3
	jsr (A3)
.vbar4:
	movem.w (A0),D1-D4       // X1, Y1, X2, Y2
	// draw right perimeter
	cmp.w D2,D4
	bge .vbar3
	exg D2,D4
.vbar3:
	cmp.w D1,D3
	beq .vbar2
	addq.w #1,D2
	subq.w #1,D4
	move.w d3,D1
	bsr clip_rect
	beq.s .vbar2
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
/*--------
* Fill a multiple bitplane area using a monochrome pattern
* c_fill_area(Virtual *vwk, long x, long y, long w, long h, short *pattern, long colour, long mode, long interior_style)
* In:	a0	VDI struct (odd address marks table operation)
*	d0	colours
*	d1	x1 destination or table address
*	d2	y1    - " -    or table length (high) and type (0 - y/x1/x2 spans)
*	d3-d4	x2,y2 destination
*	d5	pattern address
*	d6	mode
*	d7	interior/style
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_r_fill(A3),A3
	jsr (A3)
.vbar2:
	movem.l (SP)+,D1-D7
.vbar1:
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
rectangle:
	movem.l D0-D7/A0-A3,-(SP)
	movem.w (A0),D1-D4       // X1, Y1, X2, Y2
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
	cmp.w D2,D4
	bge.s .rec3
	exg D2,D4
.rec3:
	cmp.w D1,D3
	bge.s .rec2
	exg D1,D3
.rec2:
	bsr clip_rect
	beq .rec1
	bsr get_pattern
	move.l A0,D5             // pattern
	moveq #0,D6
	move.w WRT_MODE(A2),D6
	move.l D0,D7             // interior/style
/*--------
* Fill a multiple bitplane area using a monochrome pattern
* c_fill_area(Virtual *vwk, long x, long y, long w, long h, short *pattern, long colour, long mode, long interior_style)
* In:	a0	VDI struct (odd address marks table operation)
*	d0	colours
*	d1	x1 destination or table address
*	d2	y1    - " -    or table length (high) and type (0 - y/x1/x2 spans)
*	d3-d4	x2,y2 destination
*	d5	pattern address
*	d6	mode
*	d7	interior/style
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_r_fill(A3),A3
	jsr (A3)
.rec1:
	movem.l (SP)+,D0-D7/A0-A3
	rts
	
clip_rect:  // D1:X1, D2:Y1, D3:X2, D4:Y2, return flag drawing if D0 <> 0
            // and update D1-D4 for clipping

	movem.l D5-D7/A0,-(SP)
	cmp.w D1,D3
	bge.s .clr4
	exg D1,D3
.clr4:
	cmp.w D2,D4
	bge.s .clr2
	exg D2,D4
.clr2:
	tst.w CLIP(A2)           // clipping
	beq.s .clr8              // clipping off
	movem.w XMN_CLIP(A2),D0/D5-D7 // coords X1,X2,Y1,Y2 clipping
	cmp.w D0,D1
	bge.s .clr3              // X1 inside clipping
	cmp.w D0,D3
	blt.s .clr5              // X2 out of clipping
	move.w D0,D1             // X1
.clr3:
	cmp.w D6,D2
	bge.s .clr6              // Y1 inside clipping
	cmp.w D6,D4
	blt.s .clr5              // Y2 out of clipping
	move.w D6,D2             // Y1
.clr6:
	cmp.w D5,D3
	ble.s .clr7              // X2 inside clipping
	cmp.w D5,D1
	bgt.s .clr5              // X1 out of clipping
	move.w D5,D3             // X2
.clr7:
	cmp.w D7,D4
	ble.s .clr8              // Y2 inside clipping
	cmp.w D7,D2
	bgt.s .clr5              // Y1 out of clipping
	move.w D7,D4             // Y2
.clr8:
	moveq #1,D0              // drawing with new coords
	bra.s .clr1
.clr5:
	moveq #0,D0
.clr1:
	movem.l (SP)+,D5-D7/A0
	rts

det_v_arc:

	move.l 8(A1),A0          // PTSIN
	move.w 12(A0),4(A0)
	move.w 12(A0),6(A0)

det_v_ellarc:
       
	movem.l D1-D2,-(SP)
	move.l 4(A1),A0          // INTIN
	movem.w (A0),D0-D1       // angles
	move.l D1,-(SP)
	move.l D0,-(SP)
	move.l 8(A1),A0          // PTSIN
	movem.w 4(A0),D0-D1      // radii
	move.l D1,-(SP)
	move.l D0,-(SP)
	movem.w (A0),D0-D1       // center
	move.l D1,-(SP)
	move.l D0,-(SP)
	move.l #6,-(SP)          // ellarc
	move.l fvdi_virtual,A0
	move.w FILL_INT_STYLE(A2),vwk_fill_interior(A0)
	move.w FILL_STYLE_INDEX(A2),vwk_fill_style(A0)
	move.l USER_DEF_FILL_PAT(A2),vwk_fill_user_pattern_in_use(A0)
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
	move.l D0,vwk_fill_colour(A0)
	pea (A0)
	jsr _ellipsearc          // vwk, gdp, xc, yc, xrad, yrad, b_ang, e_ang
	lea 32(SP),SP
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_pie:

	move.l 8(A1),A0          // PTSIN
	move.w 12(A0),4(A0)
	move.w 12(A0),6(A0)

det_v_ellpie:

	movem.l D1-D2,-(SP)
	move.l 4(A1),A0          // INTIN
	movem.w (A0),D0-D1       // angles
	move.l D1,-(SP)
	move.l D0,-(SP)
	move.l 8(A1),A0          // PTSIN	
	movem.w 4(A0),D0-D1      // radii
	move.l D1,-(SP)
	move.l D0,-(SP)
	movem.w (A0),D0-D1       // center
	move.l D1,-(SP)
	move.l D0,-(SP)
	move.l #7,-(SP)          // ellpie
	move.l fvdi_virtual,A0
	move.w FILL_INT_STYLE(A2),vwk_fill_interior(A0)
	move.w FILL_STYLE_INDEX(A2),vwk_fill_style(A0)
	move.l USER_DEF_FILL_PAT(A2),vwk_fill_user_pattern_in_use(A0)
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
	move.l D0,vwk_fill_colour(A0)
	pea (A0)
	jsr _ellipsearc          // vwk, gdp, xc, yc, xrad, yrad, b_ang, e_ang
	lea 32(SP),SP
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_v_circle:

	move.l 8(A1),A0          // PTSIN
	move.w 8(A0),4(A0)
	move.w 8(a2),6(A0)
	
det_v_ellipse:

	movem.l D1-D2,-(SP)
	clr.l -(SP)              // dummy angles
	clr.l -(SP)
	move.l 8(A1),A0          // PTSIN	
	movem.w 4(A0),D0-D1      // radii
	move.l D1,-(SP)
	move.l D0,-(SP)
	movem.w (A0),D0-D1       // center
	move.l D1,-(SP)
	move.l D0,-(SP)
	move.l #5,-(SP)          // ellipse
	move.l fvdi_virtual,A0
	move.w FILL_INT_STYLE(A2),vwk_fill_interior(A0)
	move.w FILL_STYLE_INDEX(A2),vwk_fill_style(A0)
	move.l USER_DEF_FILL_PAT(A2),vwk_fill_user_pattern_in_use(A0)
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
	move.l D0,vwk_fill_colour(A0)
	pea (A0)
	jsr _ellipsearc          // vwk, gdp, xc, yc, xrad, yrad, b_ang, e_ang
	lea 32(SP),SP
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_v_rbox:

	movem.l D1-D2,-(SP)
	move.l 8(A1),-(SP)       // PTSIN, edges
	move.l #8,-(SP)          // rbox
	move.l fvdi_virtual,A0
	move.w FILL_INT_STYLE(A2),vwk_fill_interior(A0)
	move.w FILL_STYLE_INDEX(A2),vwk_fill_style(A0)
	move.l USER_DEF_FILL_PAT(A2),vwk_fill_user_pattern_in_use(A0)
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
	move.l D0,vwk_fill_colour(A0)
	pea (A0)
	jsr _rounded_box         // vwk, gdb_code, points
	lea 12(SP),SP
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_v_rfbox:

	movem.l D1-D2,-(SP)
	move.l 8(A1),-(SP)       // PTSIN, edges
	move.l #9,-(SP)          // rfbox
	move.l fvdi_virtual,A0
	move.w FILL_INT_STYLE(A2),vwk_fill_interior(A0)
	move.w FILL_STYLE_INDEX(A2),vwk_fill_style(A0)
	move.l USER_DEF_FILL_PAT(A2),vwk_fill_user_pattern_in_use(A0)
	moveq #0,D0
	move.w FILL_COLOR_INDEX(A2),D0
	move.l D0,vwk_fill_colour(A0)
	pea (A0)
	jsr _rounded_box         // vwk, gdb_code, points
	lea 12(SP),SP
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_v_justified:

	moveq #0,D0
	move.w 6(A3),D0          // length tab INTIN
	subq.w #2,D0
	ble .vj1
	move.l 4(A1),A0          // INTIN
	tst.l (A0)               // word_space, char_space
	bne.s .vj2	
	addq.w #4,A0             // => string
	jmp gtext
.vj2:
	movem.l A0-A2,-(SP)
	move.l #4*1024,-(SP)
	jsr _allocate_block
	addq.w #4,SP
	movem.l (SP)+,A0-A2
	tst.l D0
	beq .vj1
	movem.l D1-D7/A4-A5,-(SP)
	move.l D0,A5
	move.l A5,-(SP)
	moveq #0,D0
	move.w 6(A3),D0          // length tab INTIN
	subq.w #2,D0             // number of characters
	move.l D0,D7
	move.l 4(A1),A0          // INTIN
	lea 4(A0),A4             // string
	move.l ADR_FONT(A2),A3
	move.w font_code_low(A3),D3
	move.w font_code_high(A3),D4
	move.l font_table_character(A3),A3
	clr.l (A5)+              // first character at 0,0
	moveq #0,D2              // width total
	moveq #0,D5              // spaces
	bra.s .vj5
.vj4:
		move.w (A4)+,D1
		sub.w D3,D1 // negative numbers are higher
		cmp.w D4,D1 // than code_high
		bhi.s .vj5
		cmp.b #0x20,D1 // space
		bne.s .vj3
		addq.w #1,D5
.vj3:
		add.w D1,D1
		move.w 2(A3,D1.w),D6
		sub.w (A3,D1.w),D6
		add.w D6,D2
		move.w D6,(A2)+
		clr.w (A2)+
.vj5:
	dbf D0,.vj4
	move.l 8(A1),A3          // PTSIN
	move.w 4(A3),D6          // x size
	sub.w D2,D6
	beq .vj6
	ext.l D6                 // amount to widen by (could be negative)
	move.w D7,D4             // number of characters
	sub.w D5,D4
	tst.w (A0)               // any word spacing?
	beq.s .vj9
	move.w D5,D4
	tst.w 2(A0)              // any character spacing?
	beq .vj9
	move.w D7,D4             // number of characters
.vj9:
	subq.w #1,D4             // number of positions to vary spacing at
	beq .vj6
	divs D4,D6
	move.l D6,D2
	swap D2
	ext.l D2
	bpl.s .vj10
	neg.w D2
.vj10:
	moveq #0,D3
	move.l (SP),A5
	clr.l (A5)+              // first character at 0,0
	move.w D7,D0             // number of characters
	subq.w #1,D0             // skip first character
	lea 4(A0),A4             // string
	addq.w #2,A4
	bra.s .vj12
.vj11:
		move.w (A5),D5
		move.w (A4)+,D1
		cmp.b #0x20,D1 // space
		bne.s .vj13
		tst.w 2(A0)    // character spacing
		bra.s .vj14
.vj13:
		tst.w (A0)     // word spacing
.vj14:
		beq.s .vj15
		add.w D6,D5
.vj15:
		add.w D2,D3
		cmp.w D4,D3
		blo.s .vj16
		sub.w D4,D3
		addq.w #1,D5
		tst.l D2
		bpl.s .vj16
		subq.w #2,D5
.vj16:
		move.w D5,(A5)
		addq.w #4,A5
.vj12:
	dbf D0,.vj11
.vj6:
	moveq #0,D1
	tst.w HORIZONTAL_ALIGN(A2)
	beq.s .vj7                // left justified
	move.w 4(A3),D1          // x size
	cmp.w #2,HORIZONTAL_ALIGN(A2)
	beq.s .vj8
	lsr.w #1,D1 
.vj8:
	neg.w D1
	swap D1
	clr.w D1
.vj7:
	add.l (A3),D1            // x, y	
	move.l D7,D0             // string length
	lea 4(A0),A1             // string
	move.l (SP),A2           // the character offset table
/*--------
* Draw some text
* c_text_area(Virtual *vwk, short *text, long length, long dst_x, long dst_y, short *offsets)
* In:	a0	VDI struct
*	a1	string address
*	a2	offset table
*	d0	string length
*	d1	x1,y1 destination
*-------*/
	move.l fvdi_virtual,A0
#if 0
	move.w ,vwk_text_font(A0)
#endif
	moveq #0,D7
	move.w TEXT_COLOR_INDEX(A2),D7
	move.l D7,vwk_text_colour(A0)
	move.w CHUP(A2),vwk_text_rotation(A0)
	move.w HORIZONTAL_ALIGN(A2),vwk_text_alignment_horizontal(A0)
	move.w VERTICAL_ALIGN(A2),vwk_text_alignment_vertical(A0)
#if 0
	move.w ,vwk_text_character_width(A0)
	move.w ,vwk_text_character_height(A0)
	move.w ,vwk_text_cell_width(A0)
	move.w ,vwk_text_cell_height(A0)
#endif
	move.w STYLE(A2),vwk_text_effects(A0)
	move.w WRT_MODE(A2),vwk_mode(A0)
	move.l ADR_FONT(A2),vwk_text_current_font(A0)
	move.l vwk_real_address(A0),A3
	move.l wk_r_text(A3),A3
	jsr (A3)
	jsr _free_block          // address still on stack
	addq.l #4,SP
	movem.l (SP)+,D1-D7/A4-A5
.vj1:
	movem.l (SP)+,A0-A3
	move #0,D0
	rte
	
det_vs_color:

	move.l 4(A1),A3          // INTIN
	move.w (A3)+,D0          // index couleur
	blt.s .vco1
	cmp.w DEV_TAB+26(A0),D0  // nb colors
	bge.s .vco1
	lea REQ_COL48(A0),A2
	cmp.w #16,DEV_TAB+26(A0) // nb colors
	bne.s .vco2
	cmp.w #16,D0
	blt.s .vco2
	sub.w #16,D0
	lea REQ_COL48E(A0),A2
.vco2:
	mulu #6,D0
	add.w D0,A2
	move.l (A3)+,(A2)+       // red & green level
	move.w (A3),(A2)         // blue level
	move.l 4(A1),A0          // INTIN
	moveq #1,D0              // number of entries
	swap D0
	move.w (A0)+,D0          // index
	move.l A0,A1             // rgb_in[3] 0-1000
/*--------
* Set palette colours
* c_set_colours(Virtual *vwk, long start, long entries, short requested[3][], Colour palette[])
* In:	a0	VDI struct
*	d0	number of entries (H), start entry (L)
*	a1	requested colour values (3 word/entry)
*	a2	colour palette
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_screen_palette_colours(A3),A2
	move.l wk_r_set_palette(A3),A3
	jsr (A3)
.vco1:
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_vst_rotation:

	move.w #1,8(A3)          // length tab INTOUT
	move.l ADR_FONT(A2),CUR_FONT(A0)
	move.l 4(A1),A0          // INTIN
	move.w (A0),D0           // rotation 1/10 degree
	add.w #450,D0
	ext.l D0
	divs #900,D0
	muls #900,D0
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)           // rotation selectedÇ
	move.w D0,CHUP(A2)
	movem.l (SP)+,A0-A3
	move #0,D0
	rte

det_vsl_type:

	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A0          // INTIN
	move.w (A0),D0           // line type
	subq.w #1,D0
	blt.s .vt1
	cmp.w #6,D0
	ble.s .vt2
.vt1:
	moveq #0,D0
.vt2:
	move.w D0,LINE_TYPE(A2)
	addq.w #1,D0
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)           // line type selected
	movem.l (SP)+,A0-A3
	movq #0,D0
	rte

det_vsl_width:

	move.w #1,4(A3)          // nb points PTSOUT
	move.l 8(A1),A3          // PTSIN
	move.w (A3),D0           // line width
	ble.s .vlw1
	cmp.w SIZ_TAB15+12(A0),D0  // max width
	blt.s .vlw3
	move.w SIZ_TAB15+12(A0),D0 // max width
.vlw3:
	btst #0,D0
	bne.s .vlw2              // odd
	subq.w #1,D0
	bra.s .vlw2
.vlw1:
	moveq #1,D0              // min width
.vlw2:
	move.l 16(A1),A0         // PTSOUT
	move.w D0,(A0)           // line width selected
	move.w D0,LINE_WIDTH(A2)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vsl_color:

	move.w D1,-(SP)
	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A3          // INTIN
	move.w DEV_TAB+26(A0),D1 // nb colors
	move.w (A3),D0           // color index
	blt.s .vlc1
	cmp.w D1,D0
	blt.s .vlc2
.vlc1:
	moveq #1,D0              // default color index
.vlc2:
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)           // color index selected
	lea tab_index_col_pal,A0
	move.b (A0,D0.w),D0
	subq.w #1,D1
	and.w D1,D0
	move.w D0,LINE_COLOR_INDEX(A2)
	move.w  (SP)+,D1
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vsm_type:

	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A0          // INTIN
	move.w (A0),D0           // mark type
	subq.w #1,D0
	blt.s .vmt1
	cmp.w #5,D0
	ble.s .vmt2
.vmt1:
	moveq #2,D0
.vmt2:
	move.w D0,MARK_TYPE(A2)
	addq.w #1,D0
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)           // mark type selected
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vsm_color:

	move.w D1,-(SP)
	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A3          // INTIN
	move.w DEV_TAB+26(A0),D1 // nb colors
	move.w (A3),D0           // color index
	blt.s .dvmc1
	cmp.w D1,D0
	blt.s .dvmc2
.dvmc1:
	moveq #1,D0              // default color index
.dvmc2:
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)           // color index selected
	lea tab_index_col_pal,A0
	move.b (A0,D0.w),D0
	subq.w #1,D1
	and.w D1,D0
	move.w D0,MARK_COLOR_INDEX(A2)
	move.w (SP)+,D1
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vst_color:

	move.w D1,-(SP)
	move.w #1,8(A3)          // length tab INTOUT
	move.l ADR_FONT(A2),CUR_FONT(A0)
	move.l 4(A1),A3          // INTIN
	move.w DEV_TAB+26(A0),D1 // nb colors
	move.w (A3),D0           // color index
	blt.s .vtc1
	cmp.w D1,D0
	blt.s .vtc2
.vtc1:
	moveq #1,D0              // default color index
.vtc2:
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)           // color index selected
	lea tab_index_col_pal,A0
	move.b (A0,D0.w),D0
	subq.w #1,D1
	and.w D1,D0
	move.w D0,TEXT_COLOR_INDEX(A2)
	move.w (SP)+,D1
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vsf_interior:

	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A3          // INTIN
	move.w (A3),D0           // fill type
	blt.s .vfi2
	cmp.w #4,D0              // user pattern
	ble.s .vfi1
.vfi2:
	moveq #0,D0
.vfi1:
	move.w D0,FILL_INT_STYLE(A2)
	move.l 12(A1),A3         // INTOUT
	move.w D0,(A3)           // fill type selected
	bra choice_fill
	
det_vsf_style:

	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A3          // INTIN
	move.w (A3),D0           // fill pattern
	move.l 12(A1),A3         // INTOUT
	cmp.w #1,D0
	blt.s .vsf2
	cmp.w #2,FILL_INT_STYLE(A2) // fill type: frames
	bne.s .vsf1
	cmp.w #24,D0
	ble.s .vsf3
	bra.s .vsf2
.vsf1:
	cmp.w #12,D0
	ble.s .vsf3
.vsf2:
	moveq #1,D0
.vsf3:
	move.w D0,(A3)           // fill pattern selected
	subq.w #1,D0
	move.w D0,FILL_STYLE_INDEX(A2) // index fill pattern
	move.w FILL_INT_STYLE(A2),D0 // pattern type

choice_fill:
	cmp.w #4,D0              // user pattern
	bne.s .vsf8
	lea USER_DEF_FILL_PAT(A2),A1
	bra.s .vsf9
.vsf8:
	cmp.w #3,D0              // pattern
	bne.s .vsf4
	lea tab_pattern,A1
	bra.s .vsf7
.vsf4:
	cmp.w #2,D0              // frames
	bne.s .vsf5
	lea tab_frames,A1
.vsf7:
	move.w FILL_STYLE_INDEX(A2),D0 // index fill pattern
	asl.w #5,D0              // *32
	add.w D0,A1
	bra.s .vsf9
.vsf5:
	lea tab_full_pattern,A1
	cmp.w #1,D0              // color
	beq.s .vsf9
	lea tab_empty_pattern,A1 // no fill
.vsf9:
	move.l A1,PATPTR(A2)
	move.l A1,_PATPTR(A0)
	moveq #15,D0
	move.w D0,PATMSK(A2)     // mask
	move.w D0,_PATMSK(A0)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vsf_color:

	move.w D1,-(SP)
	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A3          // INTIN
	move.w DEV_TAB+26(A0),D1 // nb colors
	move.w (A3),D0           // color index
	blt.s .vfc1
	cmp.w D1,D0
	blt.s .vfc2
.vfc1:
	moveq #1,D0              // default color index
.vfc2:
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)           // color index selected
	lea tab_index_col_pal,A0
	move.b (A0,D0.w),D0
	subq.w #1,D1
	and.w D1,D0
	move.w D0,FILL_COLOR_INDEX(A2)
	move.w (SP)+,D1
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vq_color:

	move.w #4,8(A3)          // length tab INTOUT
	move.l 4(A1),A3          // INTIN
	move.w (A3)+,D0          // index couleur
	blt.s .vqc1
	cmp.w DEV_TAB+26(A0),D0  // nb colors
	bge.s .vqc1
	tst.w (A3)               // flag index color used
	bne.s .vqc3              // current index (real colors)
	move.l 12(A1),A2         // INTOUT
	move.w D0,(A2)+
	lea REQ_COL48(A0),A1
	cmp.w #16,DEV_TAB+26(A0) // nb colors
	bne.s .vqc2
	cmp.w #16,D0
	blt.s .vqc2
	sub.w #16,D0
	lea REQ_COL48E(A0),A1
.vqc2:
	mulu #6,D0
	bra.s .vqc4
.vqc3:
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_screen_palette_colours(A3),A1
	mulu #(3*2*2)+4,D0        // sizeof struct Colour !!!
	add.w #3*2,A1             // hw !!!
.vqc4:
	add.w D0,A1
	move.l (A1)+,(A2)+        // red & green level
	move.w (A1),(A2)          // blue level
.vqc1:
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte
	
det_vswr_mode:

	move.w #1,8(A3)           // length tab INTOUT
	move.l 4(A1),A3           // INTIN
	move.w (A3),D0            // graphic mode
	subq.w #1,D0
	blt.s .vrm1
	cmp.w #3,D0
	ble.s .vrm2
.vrm1:
	moveq #0,D0
.vrm2:
	move.w D0,WRT_MODE(A2)
	move.w D0,_WRT_MODE(A0)
	addq.w #1,D0
	move.l 12(A1),A0          // INTOUT
	move.w D0,(A0)            // graphic mode selected
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vsin_mode:

	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A2          // INTIN
	move.w (A2)+,D0
	beq.s .vnm1
	cmp.w #4,D0
	bhi.s .vnm1
	move.w (A2)+,D1
	move.l 12(A1),A2         // INTOUT
	move.w D1,(A2)
	subq.w #1,D1
	add.w D0,D0
	lea tab_vin,A1
	move.w (A1,D0.w),D0
	move.w D1,(A0,D0.w)
.vnm1:
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vql_attributes:

	move.w #1,4(A3)          // nb points PTSOUT
	move.w #5,8(A3)          // length tab INTOUT
	move.l 16(A1),A3         // PTSOUT
	move.w LINE_WIDTH(A2),(A3)+ // width line
	clr.w (A3)
	move.l 12(A1),A1         // INTOUT
	move.w LINE_TYPE(A2),D0
	addq.w #1,D0
	move.w D0,(A1)+          // type line
	move.w DEV_TAB+26(A0),D0 // nb colors
	subq.w #1,D0
	and.w #255,D0
	move.w D0,A0
	move.w LINE_COLOR_INDEX(A2),D0
	cmp.w A0,D0
	bne.s .vla1
	move.w #255,D0
.vla1:
	lea tab_index_col_vdi,A0
	move.b (A0,D0.w),D0      // => VDI color index
	move.w D0,(A1)+          // color line
	move.w WRT_MODE(A2),D0
	addq.w #1,D0
	move.w D0,(A1)+          // graphic mode
	move.w BEGIN_STYLE(A2),(A1)+ // begin line style
	move.w END_STYLE(A2),(A1) // end line style
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vqm_attributes:

	move.w #1,4(A3)          // nb points PTSOUT
	move.w #3,8(A3)          // length tab INTOUT
	move.l 16(A1),A3         // PTSOUT
	clr.w (A3)+              // width marker
	move.w MARK_HEIGHT(A2),(A3) // height marker
	move.l 12(A1),A1         // INTOUT
	move.w MARK_TYPE(A2),(A1)+ // type marker
	move.w DEV_TAB+26(A0),D0 // nb colors
	subq.w #1,D0
	and.w #255,D0
	move.w D0,A0
	move.w MARK_COLOR_INDEX(A2),D0
	cmp.w A0,D0
	bne.s .vma1
	move.w #255,D0
.vma1:
	lea tab_index_col_vdi,A0
	move.b (A0,D0.w),D0      // => VDI color index
	move.w D0,(A1)+          // color marker
	move.w WRT_MODE(A2),D0
	addq.w #1,D0
	move.w D0,(A1)           // graphic mode
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vqf_attributes:

	move.w #5,8(A3)          // length tab INTOUT
	move.l 12(A1),A1         // INTOUT
	move.w FILL_INT_STYLE(A2),(A1)+ // fill type
	move.w DEV_TAB+26(A0),D0 // nb colors
	subq.w #1,D0
	and.w #255,D0
	move.w D0,A0
	move.w FILL_COLOR_INDEX(A2),D0
	cmp.w A0,D0
	bne.s .vqfa1
	move.w #255,D0
.vqfa1:
	lea tab_index_col_vdi,A0
	move.b (A0,D0.w),D0      // => VDI color index
	move.w D0,(A1)+          // fill color
	move.w FILL_STYLE_INDEX(A2),D0
	addq.w #1,D0
	move.w D0,(A1)+          // fill pattern
	move.w WRT_MODE(A2),D0
	addq.w #1,D0
	move.w D0,(A1)+          // graphic mode
	move.w FILL_PER_VISIB(A2),(A1) // state border
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vqt_attributes:

	move.w #2,4(A3)          // nb points PTSOUT
	move.w #6,8(A3)          // length tab INTOUT
	move.l ADR_FONT(A2),A0
	move.l 16(A1),A3         // PTSOUT
	move.w CHARACTER_WIDTH(A0),(A3)+ // character width, greatest char
	move.w TOP_LINE(A0),D0   // top line distance
	move.w D0,(A3)+          // height char
	move.w CELL_WIDTH(A0),(A3)+ // cell width
	add.w BOTTOM_LINE(A0),D0 // bottom line distance
	addq.w #1,D0
	move.w D0,(A3)           // cell height
	move.l 12(A1),A3         // INTOUT
	move.w FACE_ID(A0),(A3)+ // font identifier
	move.l adr_var_vdi,A0
	move.w DEV_TAB+26(A0),D0 // nb colors
	subq.w #1,D0
	and.w #255,D0
	move.w D0,A0
	move.w TEXT_COLOR_INDEX(A2),D0
	cmp.w A0,D0
	bne.s .dvqta1
	move.w #255,D0
.dvqta1:
	lea tab_index_col_vdi,A0
	move.b (A0,D0.w),D0      // => VDI color index
	move.w D0,(A3)+          // text color
	move.w CHUP(A2),(A3)+    // rotation
	move.w HORIZONTAL_ALIGN(A2),(A3)+ // horizontal center
	move.w VERTICAL_ALIGN(A2),(A3)+   // vertical center
	move.w WRT_MODE(A2),D0
	addq.w #1,D0
	move.w D0,(A3)           // graphic mode
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vst_alignment:

	move.w #2,8(A3)          // length tab INTOUT
	move.l ADR_FONT(A2),CUR_FONT(A0) // address current font
	move.l 4(A1),A0          // INTIN
	move.l 12(A1),A1         // INTOUT
	move.w (A0)+,D0          // horizontal text alignment
	blt.s .vsta1
	cmp.w #2,D0              // right
	ble.s .vsta2
.vsta1:
	moveq #0,D0              // left
.vsta2:
	move.w D0,(A1)+          // horizontal alignment selected
	move.w D0,HORIZONTAL_ALIGN(A2)
	move.w (A0)+,D0          // vertical text alignment
	blt.s .vsta3
	cmp.w #5,D0              // top line
	ble.s .vsta4
.vsta3:
	moveq #0,D0              // middle inf
.vsta4:
	move.w D0,(A1)           // vertical alignment selected
	move.w D0,VERTICAL_ALIGN(A2)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_v_opnvwk:

	move.l A3,save_contrl2
 	movem.l (SP)+,A0-A3      // fix for RTE
	moveq #0x73,D0
	tst.w proc_type
	beq.s .vo1
	clr.w -(SP)              // format if > 68000
	bra.s .vo1
.vo2:
	movem.l D0/A0-A1,-(SP)   // return from v_opnvwk call
	move.l save_contrl2,A0
	move.w 12(A0),D0         // handle
	subq.w #1,D0
	cmp.w #MAX_WORK,D0
	bcc.s .vo3
	asl.w #2,D0
	move.l adr_var_vdi,A0
	move.l CUR_WORK(A0),A1
	move.l ADR_FONT(A1),CUR_FONT(A0) // address current font
	lea tab_cur_work,A0
	move.l A1,(A0,D0.w)
.vo3:
	movem.l (SP)+,D0/A0-A1
	rte
.vo1:
	pea .vo2(PC)             // return address from TOS
	move.w SR,-(SP)
	move.l _old_vector_vdi,-(SP)
	rts

det_v_clsvwk:

	move.w 12(A3),D0         // handle
	subq.w #1,D0
	cmp.w #MAX_WORK,D0
	bcc.s .cvwk1
	asl.w #2,D0
	lea tab_cur_work,A1
	clr.l (A1,D0.w)
.cvwk1:
	movem.l (SP)+,A0-A3
	moveq #0x73,D0
	move.l _old_vector_vdi,-(SP)
	rts

det_vq_extend:

	move.w #6,4(A3)          // nb points PTSOUT
	move.w #45,8(A3)         // length tab INTOUT
	move.l 4(A1),A2          // INTIN
	tst.w (A2)
	move.l 16(A1),A2         // PTSOUT
	bne.s .ve1
	lea SIZ_TAB15(A0),A3     // datas for texts, lines, & markers outputs
	move.l (A3)+,(A2)+       // 2*6 parameters of PTSOUT
	move.l (A3)+,(A2)+
	move.l (A3)+,(A2)+
	move.l (A3)+,(A2)+
	move.l (A3)+,(A2)+
	move.l (A3),(A2)
	lea DEV_TAB(A0),A0       // 45 parameters of v_opnwk
	move.l 12(A1),A2         // INTOUT
	moveq #21,D0             // 45 parameters in INTOUT
.ve4:
		move.l (A0)+,(A2)+
	dbf D0,.ve4
	move.w (A0)+,(A2)+
	bra.s .ve2
.ve1:
	cmp.w #2,(A2)            // vq_scrninfo ?
	bne.s .ve5
	cmp.w #1,10(A3)          // sub-function
	bne.s .ve5
	move.l 12(A1),A2         // INTOUT
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A0
	move.l wk_driver(A0),A3
	move.l driver_device(A3),A3
	move.l wk_screen_mfdb_address(A0),dev_address(A3)
	move.w wk_screen_wrap(A0),dev_byte_width(A3)
	move #(dev_struct_size/2)-1,D0
.ve6:
		move.w (A3)+,(A2)+
	dbf D0,.ve6
	bra.s .ve2
.ve5:
	lea _XMN_CLIP(A0),A3
	move.l (A3)+,(A2)+       // clipping coords in 2*6 parameters of PTSOUT
	move.l (A3),(A2)+
	clr.l (A2)+
	clr.l (A2)+
	clr.l (A2)+
	clr.l (A2)
	lea INQ_TAB(A0),A0       // 45 paramätres de VQ_EXTEND
	move.l 12(A1),A2         // INTOUT
	moveq #21,D0             // 45 parameters in INTOUT
.ve3:
		move.l (A0)+,(A2)+
	dbf D0,.ve3
	move.w (A0)+,(A2)+
	lea 863(A0),A0           // offset var VDI +171
	lea -78(A2),A2           // INTOUT[6] nb op/S for resolution 16 * 16
	move.w #1000,(A2)
	btst #0,(A0)
	beq.s .ve2
	move.w #5000,(A2)
.ve2:
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vsf_perimeter:

	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A0          // INTIN
	move.w (A0),D0           // border
	beq.s .vp1
	moveq #1,D0              // drawing
.vp1:
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)
	move D0,FILL_PER_VISIB(A2)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte
 
det_v_get_pixel:

	movem.l D1-D2,-(SP)
	move.w #2,8(A3)          // length tab INTOUT
	move.l 8(A1),A3          // PTSIN
	movem.w (A3),D1-D2       // X, Y
	movem.l A0-A1,-(SP) 
/*--------
* Get a coloured pixel
* c_read_pixel(Virtual *vwk, MFDB *mfdb, long x, long y)
* In:	a0	VDI struct, source MFDB
*	d1	x
*	d2	y
* Out:	d0	pixel colour
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_r_get_pixel(A3),A3
	clr.l -(SP)
	pea (A0)
	move.l SP,A0
	jsr (A3)
	addq.w #8,SP
	movem.l (SP)+,A0-A1
	move.l 12(A1),A3         // INTOUT
	cmp.w #16,V_PLANES(A0)
	bhi.s .vgp2
	beq.s .vgp3
	move.w D0,(A3)           // pixel color
	move.w DEV_TAB+26(A0),D1 // nb colors
	subq.w #1,D1
	and.w #255,D1
	cmp.w D1,D0
	bne.s .vgp4
	move.w #255,D0
.vgp4:
	lea tab_index_col_vdi,A0
	move.b (A0,D0.w),D0
	move.w D0,2(A3)          // index	
.vgp3:
	move.w D0,(A3)           // 16 bits color
	move.w #-1,2(A3)         // index not used
	bra.s .vgp1
.vgp2:
	swap D0
	move.l D0,(A3)           // 32 bits color
.vgp1:
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vst_effects:

	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A3          // INTIN
	move.W (A3),D0           // effect
	move.l ADR_FONT(A2),CUR_FONT(A0)
	and.w INQ_TAB+4(A0),D0   // text effects
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)           // effect selected
	move.w D0,STYLE(A2)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vsl_ends:

	move.w #2,8(A3)          // length tab INTOUT
	movem.l 4(A1),A0         // INTIN
	move.l 12(A1),A1         // INTOUT
	move.w (A0)+,D0          // begin line
	blt.s .vse1
	cmp.w #2,D0
	ble.s .vse2
.vse1:
	moveq #0,D0
.vse2:
	move.w D0,BEGIN_STYLE(A2)
	mov.w D0,(A1)+           // begin line selected
	move.w (A0),D0           // end line
	blt.s .vse3
	cmp.w #2,D0
	ble.s .vse4
.vse3:
	moveq #0,D0
.vse4:
	move.w D0,END_STYLE(A2)
	move.w D0,(A1)           // end line selected
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vro_cpyfm:

	movem.l D1-D7/A4-A5,-(SP)
	bsr coords_raster
	bmi .vrc1                // nothing to do
	move.w D1,D2             // Y1 source
	move.w D0,D1             // X1 source
	move.w D4,D3             // X1 target
	move.w D5,D4             // Y1 target
	move.w D6,D5             // X2 target
	move.w D7,D6             // Y2 target
	ext.l D1
	ext.l D2
	ext.l D3
	ext.l D4
	ext.l D5
	ext.l D6
	move.l 4(A1),A0          // INTIN
	moveq #0,D0
	move.w (A0),D0           // logic operation
	ext.l D0               
/*--------
* Blit an area
* c_blit_area(Virtual *vwk, MFDB *src, long src_x, long src_y, MFDB *dst, long dst_x, long dst_y, long w, long h, long operation)
* In:	a0	VDI struct, destination MFDB, VDI struct, source MFDB
*	d0	logic operation
*	d1-d2	x1,y1 source
*	d3-d6	x1,y1 x2,y2 destination
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_r_blit(A3),A3
	lea -16(SP),SP
	move.l A0,(SP)
	move.l 18(A3),4(SP)      // target MFDB
	move.l A0,8(SP)
 	move.l 14(A3),12(SP)     // source MFDB
 	move.l SP,A0
	jsr (A3)
	lea 16(SP),SP
.vrc1:
	movem.l (SP)+,D0-D7/A4-A5
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

coords_raster:
// input: A1: PB VDI, A2: CUR_WORK, A3: CONTRL
// return source coords inside D0-D3 & target inside D4-D7
// if D0.L < 0 => nothing to do
// if 2 rasters are differents, source is used

	movem.l A0-A5,-(SP)
	moveq #0,D5              // flag clipping
	move.l 18(A3),A0         // target MFDB
	move.l (A0),D0           // target address
	move.l 8(A1),A0          // PTSIN
	beq.s .cr15              // target = screen
	cmp.l _v_bas_ad,D0
	bne.s .cr17              // target <> screen
.cr15:
	moveq #-1,D5
	move.w CLIP(A2),D5       // clipping
.cr17:
	move.l D5,A5
	movem.w 8(A0),D4-D7      // target coords
	cmp.w D4,D6
	bge.s .cr14              // X2 target >= X1 target
	exg D4,D6                // X1,X2 target
.cr14:
	cmp.w D5,D7
	bge.s .cr9               // Y2 target >= Y1 target
	exg D5,D7                // Y1,Y2 target
.cr9:
	move.w 4(A0),D0          // X2 source (fix target coords if error)
	sub.w (A0),D0            // X1 source
	bge.s .cr21
	neg D0
.cr21:
	move.w D4,D6             // X1 target
	add.w D0,D6              // X2 target = width source + X1 target
	move.w 6(A0),D0          // Y2 source
	sub.w 2(A0),D0           // Y1 source
	bge.s .cr18
	neg.w D0
.cr18:
	move.w D5,D7             // Y1 target
	add.w D0,D7              // Y2 target = heigth source + Y1 target
	cmp.w #0,A5
	beq.s .cr5               // no clipping
	movem.w XMN_CLIP(A2),D0-D3 // X1,X2,Y1,Y2 clipping coords
	move.w D4,A1             // save X1 target
	move.w D5,A2             // save Y1 target
	move.w D6,A3             // save X2 target
	move.w D7,A4             // save Y2 target
	cmp.w D0,D4
	bge.s .cr8               // X1 inside clipping
	cmp.w D0,D6
	blt .cr4                 // X2 outside clipping
	move.w D0,D4             // X1 target
.cr8:
	cmp.w D2,D5
	bge.s .cr7               // Y1 inside clipping
	cmp.w D2,D7
	blt .cr4                 // Y2 outside clipping
	move.w D2,D5             // Y1 target
.cr7:
	cmp.w D1,D6
	ble.s .cr6               // X2 inside clipping
	cmp.w D1,D4
	bgt .cr4                 // X1 outside clipping
	move.w D1,D6             // Y1 cible
.cr6:
	cmp.w D3,D7
	ble.s .cr5               // Y2 inside clipping
	cmp.w D3,D5
	bgt.s .cr4               // Y1 outside clipping
	move.w D3,D7             // Y2 target
.cr5:
	movem.w (A0),D0-D3       // source coords
	cmp.w D0,D2
	bge.s .cr2               // X2 source >= X1 source
	exg D0,D2                // X1,X2 source
.cr2:
	cmp.w D1,D3
	bge.s .cr3               // Y2 source >= Y1 source
	exg D1,D3                // Y1,Y2 source
.cr3:
	cmp.w #0,A5
	beq.s .cr19              // no clipping
	sub.w D4,A1
	sub.w A1,D0              // X1 source fixed after target clipping
	sub.w D5,A2
	sub.w A2,D1              // Y1 source
	sub.w D6,A3
	sub.w A3,D2              // X2 source
	sub.w D7,A4
	sub.w A4,D3              // Y2 source
.cr19:
	cmp.l #0,A5
	bpl.s .cr16              // target <> screen
	move.l adr_var_vdi,A0
	cmp.w DEV_TAB(A0),D6     // width screen
	bcs.s .cr20
	move.w DEV_TAB(A0),D6    // X2 target
.cr20:
	cmp.w DEV_TAB+2(A0),D7   // height screen
	bcs.s .cr16
	move.w DEV_TAB+2(A0),D7  // Y2 target
.cr16:
	tst.w D0                 // X1 source
	bpl.s .cr12
	clr.w D0                 // X1 source
.cr12:
	tst.w D1                 // Y1 source
	bpl.s .cr13
	clr.w D1                 // Y1 source
.cr13:
	tst.w D4                 // X1 target
	bpl.s .cr10
	clr.w D4                 // X1 target
.cr10:
	tst.w D5                 // Y1 source
	bpl.s .cr11
	clr.w D5                 // Y1 target
.cr11:
	and.w #0xFFFF,D0
	bra.s .cr1
.cr4:
	moveq #-1,D0             // nothing to do
.cr1:
	movem.l (SP)+,A0-A5
	rts

det_vsc_form:

	movem.l D1-D2,-(SP)
	move.l 4(A1),A2          // INTIN
	addq.b #1,MOUSE_FLAG(A0) // mask mouse interrupt routine
	moveq #0xF,D0
	move.w (A2)+,D1          // X action point
	and.w D0,D1
	move.w D1,M_POS_HX(A0)
	move.w (A2)+,D1          // Y action point
	and.w D0,D1
	move.w D1,M_POS_HY(A0)
	move.w (A2)+,D1
	move. D1,M_PLANES(A0)
	move.w DEV_TAB+26(A0),D0 // nb colors
	move.w (A2)+,D1          // index VDI color, mask
	cmp.w D0,D1
	blt.s .vf1
	moveq #1,D1
.vf1:
	lea tab_index_col_pal,A3
	move.b (A3,D1.w),D1
	move.w D1,M_CDB_BG(A0)
	move.w (A2)+,D1          // index VDI color, form
	cmp.w D0,D1
	blt.s .vf2
	moveq #1,D1
.vf2:
	move.b (A3,D1.w),D1
	subq.w #1,D0             // nb colors -1
	and.w D0,M_CDB_BG(A0)
	and.w D0,D1
	move.w D1,M_CDB_FG(A0)
	lea MASKFORM(A0),A1	
	lea 32(A2),A3            // 16 words form
	moveq #15,D0
.vf3:
		move.w (A2)+,(A1)+ // word mask
		move.w (A3)+,(A1)+ // word form
	dbf D0,.vf3
/*--------
* Draw the mouse
* c_mouse_draw(Workstation *wk, long x, long y, Mouse *mouse)
* In:	a1	Pointer to Workstation struct
*	d0	x (low), old op bits (high)
*	d1	y
*	d2	0 (move), 1 (hide), 2 (show), Mouse* (change)
* Call:	a1	Pointer to Workstation struct
*	d0	x (low), old op bits (high)
*	d1	y
*	d2	0 (move shown), 1 (move hidden), 2 (hide), 3 (show), Mouse* (change)
* Out:	d0	mouse op to try again (low), pointer delay (high)
*-------*/
	move.l fvdi_virtual,A1
	move.l vwk_real_address(A1),A1
//	move.w ,wk_mouse_type(A1)
	move.w V_HID_CNT(A0),wk_mouse_hide(A1)
//	move.w ,wk_mouse_buttons(A1)
//	move.w ,wk_mouse_forced(A1)
	move.l G_CURX(A0),wk_mouse_position(A1)
	move.l M_POS_HX(A0),wk_mouse_hotspot(A1)
	move.l M_CDB_BG(A0),wk_mouse_colour(A1)
	lea MASKFORM(A0),A0
	moveq #7,D2
	moveq #0,D1
.vf4:
		move.w (A0)+,wk_mouse_mask(A1,D1.w)
		move.w (A0)+,wk_mouse_data(A1,D1.w)
		addq.w #2,D1
	dbf D2,.vf4
//	move.l ,wk_mouse_extra_info(A1)
	lea wk_mouse(A1),A2
	move.l wk_r_mouse(A1),A3
	move.l A2,D2
	movem.w G_CURX(A0),D0-D1
	swap D0
	move.w mouse_op,D0
	swap D0
	jsr (A3)
	move.w D0,mouse_op       // what to try again
	move.l adr_var_vdi,A0	
	move.w SR,-(SP)
	or.w #0x700,SR           // mask interrupts
	move.l G_CURX(A0),CUR_X(A0) // actual position for the next drawing
	bset #0,CUR_FLAG(A0)     // VBL redraw actived
	move.w (SP)+,SR
	subq.b #1,MOUSE_FLAG(A0) // remove mask mouse interrupt routine
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vsf_updat:

	move.w 6(A3),D0          // length tab INTIN
	lsr.w #1,D0
	move.l 4(A1),A3          // INTIN
	lea USER_DEF_FILL_PAT(A2),A1
	cmp.w #8,D0
	bne.s .vfu3
	clr.w MULTIFILL(A2)
	move.l (A3)+,(A1)+       // fill pattern 16 * 16 for 1 plane => monochrome
	move.l (A3)+,(A1)+
	move.l (A3)+,(A1)+
	move.l (A3)+,(A1)+
	move.l (A3)+,(A1)+
	move.l (A3)+,(A1)+
	move.l (A3)+,(A1)+
	move.l (A3)+,(A1)+
	clr.w _MULTIFILL(A0)     // pattern fo 1 plane
	bra.s .vfu1
.vfu3:
	subq.w #1,D0
	bmi.s .vfu1
	move.w #1,MULTIFILL(A2)
.vfu2:
		move.l (A3)+,(A1)+
	dbf D0,.vfu2
	move.w #1,_MULTIFILL(A0) // pattern for X planes
.vfu1:
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte
	
det_vsl_udsty:

	move.l 4(A1),A0          // INTIN
	move.w (A0),USER_DEF_LINE_STYLE_PAT(A2) // user line type
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vr_recfl:

	move.l 8(A1),A0          // PTSIN
	bsr rectangle
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vqin_mode:

	move.w #1,8(A3)          // length tab INTOUT
	move.l 4(A1),A2          // INTIN
	move.w (A2),D0
	beq.s .vqm1
	cmp.w #4,D0
	bhi.s .vqm1
	move.l 12(A1),A2         // INTOUT
	add.w D0,D0
	move.w tab_vin(PC,D0.w),D0
	move.w (A0,D0.w),(A2)
.vqm1:
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

tab_vin:
	dc.w 0                   // offset var VDI
	dc.w -436                // reserved
	dc.w -350                // reserved
	dc.w -466                // reserved
	dc.w -352                // reserved
 
det_vqt_extent:

	move.w #4,4(A3)          // length tab PTSOUT
	move.w 6(A3),D0          // length tab INTIN
	move.l 4(A1),A0          // INTIN	
	move.l 16(A1),A1         // PTSOUT
	bsr vqt_extent
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

vqt_extent:

	movem.l D1-D3/A2-A3,-(SP)
	move.w D0,D3             // length tab INTIN
	swap D3
	move.w D0,D3             // length tab INTIN
	move.l A0,A2             // INTIN
	move.l adr_var_vdi,A3
	move.l CUR_WORK(A3),A3
	move.l ADR_FONT(A3),A3
	move.l OFF_TABLE(A3),A0  // offset table of characters
	moveq #0,D2              // border text
	move.w FIRST_ADE(A3),D1  // lower ASCII code
	bra.s .vte1
.vte2:
		move.w (A2)+,D0 // char
		sub.w D1,D0     // - ASCII base code
		add.w D0,D0
		add.w 2(A0,D0.w),D2
		sub.w (A0,D0.w),D2
.vte1:
	dbf D3,.vte2             // next char
	move.l adr_var_vdi,A0
	tst.w _SCALE(A0)
	beq.s .vte3              // no scale change
	cmp.w #-1,_DDA_INC(A0)
	bne.s .vte4
	add.w D2,D2              // increase
	bra.s .vte3
.vte4:
	move.w D2,D1
	move.w #0x7FFF,D3
	move.w _DDA_INC(A0),D0
	moveq #0,D2
	btst #0,_T_SCLSTS+1(A0)
	beq.s .vte8              // not increased
	bra.s .vte6
.vte9:
		addq.w #1,D2
		add.w D0,D3
		bcc.s .vte6
		addq.w #1,D2
.vte6:
	dbf D1,.vte9
	bra.s .vte3
.vte7:
		add.w D0,D3
		bcc.s .vte8
		addq.w #1,D2
.vte8:
	dbf D1,.vte7
	tst.w D2
	bne.s .vte3
	addq.w #1,D2
.vte3:
	swap D3
	move.w _STYLE(A0),D0     // style
	btst #0,D0               // bold char
	beq.s .vte10
	btst #3,FONTFLAGS+1(A3)
	bne.s .vte10             // no proportionnal fonte (characters with same width)
	move.w THICKENING(A3),D1
	mulu D3,D1               // * size tab INTIN = nb characters
	add.w D1,D2
.vte10:
	btst #2,D0               // italic
	beq.s .vte11
	add.w LEFT_OFFSET(A3),D2 // + left offset
	add.w RIGTH_OFFSET(A3),D2 // + right offset
.vte11:
	move.w TOP_LINE(A3),D1   // top line distance
 	add.w BOTTOM_LINE(A3),D1 // bottom line distance
	addq.w #1,D1             // height border text
	btst #4,D0               // outlined
	beq.s .vte12
	add.w D3,D3              // size tab INTIN = nb characters
	add.w D3,D2
	addq.w #2,D1
.vte12:
	move.w _CHUP(A0),D0      // rotation
	bne.s .vte13
	clr.l (A1)+
	move.w D2,(A1)+
	clr.w (A1)+
	move.w D2,(A1)+
	move.w D1,(A1)+
	clr.w (A1)+
	move.w D1,(A1)
	bra.s .vte5
.vte13:
	cmp.w #900,D0
	bne.s .vte14
	move.w D1,(A1)+
	clr.w (A1)+
	move.w D1,(A1)+
	move.w D2,(A1)+
	clr.w (A1)+
	move.w D2,(A1)+
	clr.l (A1)
	bra.s .vte5
.vte14:
	cmp.w #1800,D0
	bne.s .vte15
	move.w D2,(A1)+
	move.w D1,(A1)+
	clr.w (A1)+
	move.w D1,(A1)+
	clr.l (A1)+
	move.w D2,(A1)+
	clr.w (A1)
	bra.s .vte5
.vte15:
	cmp.w #2700,D0
	bne.s .vte5
	clr.w (A1)+
	move.w D2,(A1)+
	clr.l (A1)+
	move.w D1,(A1)+
	clr.w (A1)+
	move.w D1,(A1)+
	move.w D2,(A1)
.vte5:
	movem.l (SP)+,D1-D3/A2-A3
	rts

det_vex_time:

	move.w SR,-(SP)
	or.w #0x700,SR
	move.l USER_TIM(A0),18(A3)
	move.l 14(A3),USER_TIM(A0)
	move.w (SP)+,SR
	move.l 12(A1),A0         // INTOUT
	move.w _timr_ms,(A0)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte
	
det_vrt_cpyfm:

	movem.l D1-D7/A4-A5,-(SP)
	bsr coords_raster_vrt
	bmi .vrtc1               // nothing to do
	move.w D1,D2             // Y1 source
	move.w D0,D1             // X1 source
	move.w D4,D3             // X1 target
	move.w D5,D4             // Y1 target
	move.w D6,D5             // X2 target
	move.w D7,D6             // Y2 target
	ext.l D1
	ext.l D2
	ext.l D3
	ext.l D4
	ext.l D5
	ext.l D6
	move.l 4(A1),A0          // INTIN
	moveq #0,D7
	move.w (A0)+,D7          // logic operation
	ext.l D7       
	move.l (A0),D0
	swap D0                  // colors        
/*--------
* Expand a monochrome area to multiple bitplanes
* c_expand_area(Virtual *vwk, MFDB *src, long src_x, long src_y, MFDB *dst, long dst_x, long dst_y, long w, long h, long operation, long colour)
* In:	a0	VDI struct, destination MFDB, VDI struct, source MFDB
*	d0	colours
*	d1-d2	x1,y1 source
*	d3-d6	x1,y1 x2,y2 destination
*	d7	logic operation
*-------*/
	move.l fvdi_virtual,A0
	move.l vwk_real_address(A0),A3
	move.l wk_r_expand(A3),A3
	lea -16(SP),SP
	move.l A0,(SP)
	move.l 18(A3),4(SP)      // target MFDB
	move.l A0,8(SP)
 	move.l 14(A3),12(SP)     // source MFDB
 	move.l SP,A0
	jsr (A3)
	lea 16(SP),SP
.vrtc1:
	movem.l (SP)+,D0-D7/A4-A5
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

coords_raster_vrt:
// input: A1: PB VDI, A2: CUR_WORK, A3: CONTRL
// return source coords inside D0-D3 & target inside D4-D7
// if D0.L < 0 => nothing to do
// if 2 rasters are differents, use adjusted target

	movem.l A0-A5,-(SP)
	moveq #0,D5              // flag clipping
	move.l 18(A3),A0         // target MFDB
	move.l (A0),D0           // target address
	move.l 8(A1),A0          // PTSIN
	beq.s .tcr15             // target = screen
	cmp.l _v_bas_ad,D0
	bne.s .tcr17             // target <> screen
.tcr15:
	moveq #-1,D5
	move.w CLIP(A2),D5       // clipping
.tcr17:
	move.l D5,A5
	movem.w 8(A0),D4-D7      // target coords
	cmp.w D4,D6
	bge.s .tcr14             // X2 target >= X1 target
	exg D4,D6                // X1,X2 target
.tcr14:
	cmp.w D5,D7
	bge.s .tcr9              // Y2 target >= Y1 target
	exg D5,D7                // Y1,Y2 target
.tcr9:
	cmp.w #0,A5
	beq.s .tcr5              // no clipping
	movem.w XMN_CLIP(A2),D0-D3 // X1,X2,Y1,Y2 clipping coords
	move.w D4,A1             // save X1 target
	move.w D5,A2             // save Y1 target
	move.w D6,A3             // save X2 target
	move.w D7,A4             // save Y2 target
	cmp.w D0,D4
	bge.s .tcr8              // X1 inside clipping
	cmp.w D0,D6
	blt .tcr4                // X2 outside clipping
	move.w D0,D4             // X1 target
.tcr8:
	cmp.w D2,D5
	bge.s .tcr7              // Y1 inside clipping
	cmp.w D2,D7
	blt .tcr4                // Y2 outside clipping
	move.w D2,D5             // Y1 target
.tcr7:
	cmp.w D1,D6
	ble.s .tcr6              // X2 inside clipping
	cmp.w D1,D4
	bgt .tcr4                // X1 outside clipping
	move.w D1,D6             // Y1 cible
.tcr6:
	cmp.w D3,D7
	ble.s .tcr5              // Y2 inside clipping
	cmp.w D3,D5
	bgt .tcr4                // Y1 outside clipping
	move.w D3,D7             // Y2 target
.tcr5:
	movem.w (A0),D0-D3       // source coords
	cmp.w D0,D2
	bge.s .tcr2              // X2 source >= X1 source
	exg D0,D2                // X1,X2 source
.tcr2:
	cmp.w D1,D3
	bge.s .tcr3              // Y2 source >= Y1 source
	exg D1,D3                // Y1,Y2 source
.tcr3:
	move.w D4,-(SP)
	move.w 12(A0),D4         // X2 target (fix source coords if error)
	sub.w 8(A0),D4           // X1 target with target coors without clipping
	bge .tcr21
	neg.w D4
.tcr21:
	move.w D0,D2             // X1 source
	add.w D4,D2              // X2 source
	move.w 14(A0),D4         // Y2 cible
	sub.w 10(A0),D4          // Y1 cible
	bge.s .tcr19
	neg.w D4
.tcr19:
	move.w D1,D3             // Y1 source
	add.w D4,D3              // Y2 source
	move.w (SP)+,D4
	cmp.w #0,A5
	beq.s .tcr18             // no clipping
	sub.w D4,A1
	sub.w A1,D0              // X1 source fixed after target clipping
	sub.w D5,A2
	sub.w A2,D1              // Y1 source
	sub.w D6,A3
	sub.w A3,D2              // X2 source
	sub.w D7,A4
	sub.w A4,D3              // Y2 source
.tcr18:
	cmp.l #0,A5
	bpl.s .tcr16             // target <> screen
	move.l adr_var_vdi,A0
	cmp.w DEV_TAB(A0),D6     // width screen
	bcs.s .tcr20
	move.w DEV_TAB(A0),D6    // X2 target
.tcr20:
	cmp.w DEV_TAB+2(A0),D7   // height screen
	bcs.s .tcr16
	move.w DEV_TAB+2(A0),D7  // Y2 target
.tcr16:
	tst.w D0                 // X1 source
	bpl.s .tcr12
	clr.w D0                 // X1 source
.tcr12:
	tst.w D1                 // Y1 source
	bpl.s .tcr13
	clr.w D1                 // Y1 source
.tcr13:
	tst.w D4                 // X1 target
	bpl.s .tcr10
	clr.w D4                 // X1 target
.tcr10:
	tst.w D5                 // Y1 source
	bpl.s .tcr11
	clr.w D5                 // Y1 target
.tcr11:
	and.w #0xFFFF,D0
	bra.s .tcr1
.tcr4:
	moveq #-1,D0             // nothing to do
.tcr1:
	movem.l (SP)+,A0-A5
	rts

det_v_show_c:

	movem.l D1-D2,-(SP)
	move.l 4(A1),A3          // INTIN
	tst.w (A3)               // reset
	bne.s .shc1
	tst.w V_HID_CNT(A0)
	beq.s .shc1
	move.w #1,V_HID_CNT(A0)  // reset cursor to on
.shc1:
	addq.b #1,MOUSE_FLAG(A0) // mask mouse interrupt routine
	subq.w #1,V_HID_CNT(A0)
	bgt.s .shc2
	clr.w V_HID_CNT(A0)
	move.l G_CURX(A0),CUR_X(A0) // actual position for the next drawing
	// display the cursor
/*--------
* Draw the mouse
* c_mouse_draw(Workstation *wk, long x, long y, Mouse *mouse)
* In:	a1	Pointer to Workstation struct
*	d0	x (low), old op bits (high)
*	d1	y
*	d2	0 (move), 1 (hide), 2 (show), Mouse* (change)
* Call:	a1	Pointer to Workstation struct
*	d0	x (low), old op bits (high)
*	d1	y
*	d2	0 (move shown), 1 (move hidden), 2 (hide), 3 (show), Mouse* (change)
* Out:	d0	mouse op to try again (low), pointer delay (high)
*-------*/
	move.l fvdi_virtual,A1
	move.l vwk_real_address(A1),A1
	move.l G_CURX(A0),wk_mouse_position(A1)
	clr.w wk_mouse_hide(A1)
	move.l wk_r_mouse(A1),A3
	moveq #3,D2
	movem.w G_CURX(A0),D0-D1
	swap D0
	move.w mouse_op,D0
	swap D0
	jsr (A3)
	move.w D0,mouse_op       // what to try again
	move.l adr_var_vdi,A0	
	bclr #0,CUR_FLAG(A0)     // VBL redraw disabled
.shc2:	
	subq.b #1,MOUSE_FLAG(A0) // remove mask mouse interrupt routine
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_v_hide_c:

	movem.l D1-D2,-(SP)
	addq.b #1,MOUSE_FLAG(A0) // mask mouse interrupt routine
	addq.w #1,V_HID_CNT(A0)
	cmp.w #1,V_HID_CNT(A0)
	bne.s .hic1              // cursor was hidden
	// remove the cursor from screen
/*--------
* Draw the mouse
* c_mouse_draw(Workstation *wk, long x, long y, Mouse *mouse)
* In:	a1	Pointer to Workstation struct
*	d0	x (low), old op bits (high)
*	d1	y
*	d2	0 (move), 1 (hide), 2 (show), Mouse* (change)
* Call:	a1	Pointer to Workstation struct
*	d0	x (low), old op bits (high)
*	d1	y
*	d2	0 (move shown), 1 (move hidden), 2 (hide), 3 (show), Mouse* (change)
* Out:	d0	mouse op to try again (low), pointer delay (high)
*-------*/
	move.l fvdi_virtual,A1
	move.l vwk_real_address(A1),A1
	move.l G_CURX(A0),wk_mouse_position(A1)
	move.w #1,wk_mouse_hide(A1)
	move.l wk_r_mouse(A1),A3
	moveq #2,D2
	movem.w G_CURX(A0),D0-D1
	swap D0
	move.w mouse_op,D0
	swap D0
	jsr (A3)
	move.w D0,mouse_op       // what to try again
	move.l adr_var_vdi,A0
	bclr #0,CUR_FLAG(A0)     // VBL redraw disabled
.hic1:
	subq.b #1,MOUSE_FLAG(A0) // remove mask mouse interrupt routine
	movem.l (SP)+,D1-D2
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vq_mouse:

	moveq #1,D0
	move.w D0,4(A3)          // nb points PTSOUT
	move.w D0,8(A3)          // length tab INTOUT
	move.l 12(A1),A2         // INTOUT
	move.w SR,D0
	or.w #0x700,SR
	move.w MOUSE_BT(A0),(A2)
	move.l 16(A1),A2         // PTSOUT
	move.l G_CURX(A0),(A2)
	move.w D0,SR
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

mov_cur:

	move.l A0,-(SP)
	move.l adr_var_vdi,A0
	tst.w V_HID_CNT(A0)
	bne.s .mc1
	swap D0
	move.w D1,D0
	move.l D0,mouse_first
.mc1:
	move.l (SP)+,A0
	rts
	
vb_draw:
	                         // VBL routine	
	tas.b mouse_semaphore
	bne .vd1
	movem.l D0-D2/A0-A2,-(SP)
	move.l mouse_first,D0
	move.w D0,D1
	move.w mouse_op,D0
	swap D0
	move.l adr_var_vdi,A0
	move.l fvdi_virtual,A1
	move.l vwk_real_address(A1),A1
	move.w D0,G_CURX(A0)
	move.w D1,G_CURY(A0)
	move.l G_CURX(A0),wk_mouse_position(A1)
	moveq #1,D2              // assume move hidden
	move.w V_HID_CNT(A0),wk_mouse_hide(A1)
	bne.s .vd2
	moveq #0,D2              // shown if zero
.vd2:
/*--------
* Draw the mouse
* c_mouse_draw(Workstation *wk, long x, long y, Mouse *mouse)
* In:	a1	Pointer to Workstation struct
*	d0	x (low), old op bits (high)
*	d1	y
*	d2	0 (move), 1 (hide), 2 (show), Mouse* (change)
* Call:	a1	Pointer to Workstation struct
*	d0	x (low), old op bits (high)
*	d1	y
*	d2	0 (move shown), 1 (move hidden), 2 (hide), 3 (show), Mouse* (change)
* Out:	d0	mouse op to try again (low), pointer delay (high)
*-------*/
	move.l wk_r_mouse(A1),A2
	jsr (A2)
	move.w D0,mouse_op
	clr.b mouse_semaphore
	movem.l (SP)+,D0-D2/A0-A2
.vd1:
	move.l old_timv,-(SP)
	rts
 
det_vex_butv:

	move.l USER_BUT(A0),18(A3)
	move.l 14(A3),USER_BUT(A0)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte
 
det_vex_motv:

	move.l USER_MOT(A0),18(A3)
	move.l 14(A3),USER_MOT(A0)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vex_curv:

	move.l USER_CUR(A0),18(A3)
	move.l 14(A3),USER_CUR(A0)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte
 
det_vq_key_s:

	move.w #1,8(A3)          // length tab INTOUT
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D0
	and.w #0xF,D0
	move.l 12(A1),A0         // INTOUT
	move.w D0,(A0)
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte
 
det_vs_clip:

	move.l 4(A1),A3          // INTIN
	move.w (A3),D0           // flag clip
	move.w D0,_CLIP(A0)
	move.w D0,CLIP(A2)       // clipping
	beq.s .vsc3              // not activedÇ
	movem.l D1-D3,-(SP)
	move.l 8(A1),A1          // PTSIN
	movem.w (A1),D0-D3
	cmp.w D0,D2
	bge.s .vsc1              // X2 >= X1
	exg D0,D2
.vsc1:
	cmp.w D1,D3
	bge.s .vsc2              // Y2 >= Y1
	exg D1,D3
.vsc2:
	tst.w D0                 // X1
	bpl.s .vsc5
	moveq #0,D0
.vsc5:
	tst.w D1                 // Y1
	bpl.s .vsc6
	moveq #0,D1
.vsc6:
	tst.w D2                 // X2
	bpl.s .vsc9
	moveq #0,D2
.vsc9:
	tst.w D3                 // Y2
	bpl.s .vsc10
	moveq #0,D3
.vsc10:
	cmp.w DEV_TAB(A0),D2     // width screen -1
	ble.s .vsc7              // X2 < width screen
	move.w DEV_TAB(A0),D2    // width screen -1
.vsc7:
	cmp.w DEV_TAB+2(A0),D3   // height screen -1
	ble.s .vsc8              // Y2 < height screen
	move.w DEV_TAB+2(A0),D3  // height screen -1
.vsc8:
	movem.w D0-D3,_XMN_CLIP(A0)
	swap D0                  // X1
	move.w D2,D0             // X2
	swap D1                  // Y1
	move.w D3,D1             // Y2
	movem.l D0-D1,XMN_CLIP(A2) // clipping X1,X2,Y1,Y2
	movem.l (SP)+,D1-D3
	bra.s .vsc4
.vsc3:
	lea _XMN_CLIP(A0),A1
	clr.l (A1)+
	move.l DEV_TAB(A0),(A1)  // width and height screen -1
	lea XMN_CLIP(A2),A1      // clipping coords X1,X2,Y1,Y2
	moveq #0,D0              // = screen coords
	move.w DEV_TAB(A0),D0    // width screen -1
	move.l D0,(A1)+
	move.w DEV_TAB+2(A0),D0  // height screen -1
	move.l D0,(A1)
.vsc4:
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

det_vqt_fontinfo:

	move.w #5,4(A3)          // nb points PTSOUT
	move.w #2,8(A3)          // length tab INTOUT
	move.l ADR_FONT(A2),A3
	move.w _STYLE(A0),D0
	move.l 12(A1),A0         // INTOUT
	move.l FIRST_ADE(A3),(A0) // ASCII code mini and maxi
	move.l 16(A1),A0         // PTSOUT
	move.w CELL_WIDTH(A3),(A0)+  // cell width
	move.w BOTTOM_LINE(A3),(A0)+ // bottom line distance
	clr.w (A0)+
	btst #0,D0               // bold char
	beq.s .vtf2
	move.w THICKENING(A3),-2(A0)
.vtf2:
	move.w TOP_LINE(A3),(A0)+ // descent line distance
	btst #8,D0               // italic char
	beq.s .vtf3
	move.w LEFT_OFFSET(A3),(A0)+ // left offset
	move.w HALF_LINE(A3),(A0)+   // half line distance
	move.w RIGTH_OFFSET(A3),(A0)+ // right offset
	bra.s .vtf1
.vtf3:
	clr.w (A0)+              // left offset
	move.w HALF_LINE(A3),(A0)+ // half line distance
	clr.w (A0)+              // right offset
.vtf1:
	move.w ASCENT_LINE(A3),(A0)+ // ascent line distance
	clr.w (A0)+
	move.w TOP_LINE(A3),(A0)+    // top line distance
	movem.l (SP)+,A0-A3
	moveq #0,D0
	rte

_init_var_linea:

	movem.l D0-A2,-(SP)
	dc.w 0xA000
	move.l A0,adr_var_vdi
	jsr _c_get_width_virtual
	move.l D0,D6
	jsr _c_get_height_virtual
	move.l D0,D7
	jsr _c_get_bpp
	move.l adr_var_vdi,A0
	move.w D0,V_PLANES(A0)   // nb planes
	move.w D6,DEV_TAB(A0)
	subq.w #1,DEV_TAB(A0)    // width workstation info
	move.w D7,DEV_TAB+2(A0)
	subq.w #1,DEV_TAB+2(A0)  // height workstation info
	move.w D7,V_REZ_VT(A0)   // height screen VDI ESC
	move.l D7,D1
	divu V_CEL_HT(A0),D1     // height character VDI ESC
	subq.w #1,D1
	move.w D1,V_CEL_MY(A0)   // max line cursor VDI ESC
	move.w D6,V_REZ_HZ(A0)   // width VDI ESC
	move.w D6,D0
	lsr.w #3,D0
	move.w D0,V_CEL_MX(A0)
	subq.w #1,V_CEL_MX(A0)   // max column cursor VDI ESC
	mulu V_PLANES(A0),D0     // planes line A
	move.w D0,V_LIN_WR(A0)   // bytes/line line A
	move.w D0,BYTES_LN(A0)   // bytes/line VDI ESC
	mulu V_CEL_HT(A0),D0     // height character VDI ESC
	move.w D0,V_CEL_WR(A0)   // bytes/line characters VDI ESC
	move.w #744,D0
	cmp.w #400,D6
	bcs.s .ivl1
	lsr.w #1,D0
.ivl1:
	move.w D0,DEV_TAB+6(A0)  // width point in mm/1000
	move.w #744,D0
	cmp.w #350,D7
	bcs.s .ivl2
	lsr.w #1,D0
.ivl2:
	move.w D0,DEV_TAB+8(A0)  // heigth point in mm/1000
	movem.l (SP)+,D0-A2
	rts

_cursor_home:

	move.l adr_var_vdi,A0
	clr.w V_CUR_X(A0)
	clr.w V_CUR_Y(A0)
	rts
	
_eddi_cookie:
	tst.w D0
	bne.s .ec1
	move.w #0x110,D0         // version 1.10
	rts
.ec1:
	moveq #-1,D0
	rts
	
/* fVDI subroutines, from Johan Klockars */

// fill_poly(Virtual *vwk, short *pts, int n, int colour, short *pattern, short *points, long mode, long interior_style);
_fill_poly:
	move.l 12(SP),D1
	ble .end_fill_poly
	move.l 4(SP),A0
	move.l vwk_real_address(A0),A1
	move.l wk_r_fillpoly(A1),D0
	beq .do_c_poly
	movem.l D2-D7,-(SP)
	move.l D1,D2
	move.l 6*4+8(SP),D1
	move.l D0,A1
	moveq #0,D3
	moveq #0,D4
	move.l 6*4+16(a7),D0
	move.l 6*4+20(a7),D5
	move.l 6*4+28(a7),D6
	move.l 6*4+32(a7),D7
	jsr (A1)
	movem.l (SP)+,D2-D7
.end_fill_poly:
	rts
.do_c_poly:
	jmp _filled_poly

// fill_spans(Virtual *vwk, short *spans, long n, long colour, short *pattern, long mode, long interior_style)
_fill_spans:
	movem.l D2-D7/A2-A6,-(SP)
	move.l 11*4+4+0(SP),A0
	move.l 11*4+4+12(a7),D0
	move.l 11*4+4+4(SP),D1
	move.l 11*4+4+8(SP),D2
	swap D2
	clr.w D2
	moveq #0,D3
	moveq #0,D4
	move.l vwk_real_address(A0),A2
	addq.l #1,A0
	move.l wk_r_fill(A2),A1
	move.l 11*4+4+16(SP),D5
	move.l 11*4+4+20(SP),D6
	move.l 11*4+4+24(SP),D7
	jsr (A1)
	movem.l (SP)+,D2-D7/A2-A6
	rts

// c_pline(Virtual *vwk, long numpts, long colour, short *pts)
_c_pline:
	movem.l D2-D3/A2,-(SP)
	clr.l -(SP)              // get a memory block of any size (hopefully large)
	jsr _allocate_block
	addq.w #4,SP
	tst.l D0
	beq.s .cpl1              // error
	move.l D0,-(SP)          // save for later
	move.l 12+4+4(SP),A0     // vwk
	move.l 12+4+8(SP),D1     // numpts	
	move.l 12+4+12(SP),D2    // colour	
	move.l 12+4+16(a7),A1    // pts
	moveq #0,D3
	move.w vwk_mode(A0),D3
	move.l D3,-(SP)          // mode
	move.l D0,-(SP)          // points
	move.l D2,-(SP)          // color
	move.l D1,-(SP)          // numpts
	move.l A1,-(SP)          // pts
	move.l A0,-(SP)          // vwk
// wide_line(Virtual *vwk, short *pts, long numpts, long colour, short *points, long mode)
	jsr _wide_line
	lea 24(SP),SP
	jsr _free_block
	addq.w #4,SP
.cpl1:
	movem.l (SP)+,D2-D3/A2
	rts
	
// fill_area(Virtual *vwk, long x1, long y1, long x2, long y2, long colour);
_fill_area:
	movem.l D2-D7/A2,-(SP)
	lea 4+4*4(SP),A1
	move.l (A1),A0
	movem.l 4(A1),D1-D4
	move.l 20(a1),D0
	bsr clip_rect
	beq.s .fa1
	move.l vwk_real_address(A0),A2
	move.l wk_r_fill(A2),A1
	move.l _pattern_ptrs,D5
	moveq #1,D6              // replace mode
	move.l #0x00010000,D7    // solid
	jsr (A1)
.fa1:
	movem.l	(SP)+,D2-D7/A2
	rts	

// void get_extent(Virtual *vwk, long length, short *text, short points[]);
_get_extent:

 	move.w 8(SP),D0          // length tab INTIN			; Number of characters
	move.l 10(SP),A0         // text INTIN
	move.l 14(SP),A1         // points PTSOUT	
	bsr vqt_extent
	rts
	
// void draw_text(Virtual *vwk, long x, long y, short *text, long length, long colour);
_draw_text:
	movem.l A2-A3,-(A7)
	lea 4+2*4(SP),A1
	move.l (A1),A0
	move.w 2+4(a1),D1
	swap D1
	move.w 2+8(A1),D1
	move.l 16(A1),D0
	move.l 12(A1),A1
	sub.l A2,A2               // no special offset table
	move.l vwk_real_address(A0),A3
	move.l wk_r_text(A3),A3
	jsr (A3)
	movem.l (SP)+,A2-A3
	rts
	
	.data
	
tab_index_col_pal: // index VDI color => index palette
	dc.b   0,255,  1,  2,  4,  6,  3,  5,  7,  8,  9, 10, 12, 14, 11, 13
	dc.b  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
	dc.b  32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47
	dc.b  48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63
	dc.b  64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79
	dc.b  80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95
	dc.b  96, 97, 98, 99,100,101,102,103,104,105,106,107,108,109,110,111
	dc.b 112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127
	dc.b 128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
	dc.b 144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
	dc.b 160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175
	dc.b 176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191
	dc.b 192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207
	dc.b 208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223
	dc.b 224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
	dc.B 240,241,242,243,244,245,246,247,248,249,250,251,252,253,254, 15

tab_index_col_vdi: // color index palette => index VDI
	dc.b   0,  2,  3,  6,  4,  7,  5,  8,  9, 10, 11, 14, 12, 15, 13,255
	dc.b  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
	dc.b  32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47
	dc.b  48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63
	dc.b  64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79
	dc.b  80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95
	dc.b  96, 97, 98, 99,100,101,102,103,104,105,106,107,108,109,110,111
	dc.b 112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127
	dc.b 128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
	dc.b 144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
	dc.b 160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175
	dc.b 176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191
	dc.b 192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207
	dc.b 208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223
	dc.b 224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
	dc.b 240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,  1

tab_empty_pattern:
	.rep 16
	dc.w 0
	.endr

tab_full_pattern:
_solid:
	.rep 16
	dc.w 0xFFFF
	.endr

tab_frames:
	dc.w 0x0000,0x4444,0x0000,0x1111,0x0000,0x4444,0x0000,0x1111
	dc.w 0x0000,0x4444,0x0000,0x1111,0x0000,0x4444,0x0000,0x1111
	dc.w 0x0000,0x5555,0x0000,0x5555,0x0000,0x5555,0x0000,0x5555
	dc.w 0x0000,0x5555,0x0000,0x5555,0x0000,0x5555,0x0000,0x5555
	dc.w 0x8888,0x5555,0x2222,0x5555,0x8888,0x5555,0x2222,0x5555
	dc.w 0x8888,0x5555,0x2222,0x5555,0x8888,0x5555,0x2222,0x5555
	dc.w 0xAAAA,0x5555,0xAAAA,0x5555,0xAAAA,0x5555,0xAAAA,0x5555
	dc.w 0xAAAA,0x5555,0xAAAA,0x5555,0xAAAA,0x5555,0xAAAA,0x5555
	dc.w 0xAAAA,0xDDDD,0xAAAA,0x7777,0xAAAA,0xDDDD,0xAAAA,0x7777
	dc.w 0xAAAA,0xDDDD,0xAAAA,0x7777,0xAAAA,0xDDDD,0xAAAA,0x7777
	dc.w 0xAAAA,0xFFFF,0xAAAA,0xFFFF,0xAAAA,0xFFFF,0xAAAA,0xFFFF
	dc.w 0xAAAA,0xFFFF,0xAAAA,0xFFFF,0xAAAA,0xFFFF,0xAAAA,0xFFFF
	dc.w 0xEEEE,0xFFFF,0xBBBB,0xFFFF,0xEEEE,0xFFFF,0xBBBB,0xFFFF
	dc.w 0xEEEE,0xFFFF,0xBBBB,0xFFFF,0xEEEE,0xFFFF,0xBBBB,0xFFFF
	dc.w 0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF
	dc.w 0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF
	dc.w 0xFFFF,0x8080,0x8080,0x8080,0xFFFF,0x0808,0x0808,0x0808
	dc.w 0xFFFF,0x8080,0x8080,0x8080,0xFFFF,0x0808,0x0808,0x0808
	dc.w 0x2020,0x4040,0x8080,0x4141,0x2222,0x1414,0x0808,0x1010
	dc.w 0x2020,0x4040,0x8080,0x4141,0x2222,0x1414,0x0808,0x1010
	dc.w 0x0000,0x0000,0x1010,0x2828,0x0000,0x0000,0x0101,0x8282
	dc.w 0x0000,0x0000,0x1010,0x2828,0x0000,0x0000,0x0101,0x8282
	dc.w 0x0202,0x0202,0xAAAA,0x5050,0x2020,0x2020,0xAAAA,0x0505
	dc.w 0x0202,0x0202,0xAAAA,0x5050,0x2020,0x2020,0xAAAA,0x0505
	dc.w 0x4040,0x8080,0x0000,0x0808,0x0404,0x0202,0x0000,0x2020
	dc.w 0x4040,0x8080,0x0000,0x0808,0x0404,0x0202,0x0000,0x2020
	dc.w 0x6606,0xC6C6,0xD8D8,0x1818,0x8181,0x8DB1,0x0C33,0x6000
	dc.w 0x6606,0xC6C6,0xD8D8,0x1818,0x8181,0x8DB1,0x0C33,0x6000
	dc.w 0x0000,0x0000,0x0400,0x0000,0x0010,0x0000,0x8000,0x0000
	dc.w 0x0000,0x0000,0x0400,0x0000,0x0010,0x0000,0x8000,0x0000
	dc.w 0xF8F8,0x6C6C,0xC6C6,0x8F8F,0x1F1F,0x3636,0x6363,0xF1F1
	dc.w 0xF8F8,0x6C6C,0xC6C6,0x8F8F,0x1F1F,0x3636,0x6363,0xF1F1
	dc.w 0xAAAA,0x0000,0x8888,0x1414,0x2222,0x4141,0x8888,0x0000
	dc.w 0xAAAA,0x0000,0x8888,0x1414,0x2222,0x4141,0x8888,0x0000
	dc.w 0x0808,0x0000,0xAAAA,0x0000,0x0808,0x0000,0x8888,0x0000
	dc.w 0x0808,0x0000,0xAAAA,0x0000,0x0808,0x0000,0x8888,0x0000
	dc.w 0x7777,0x9898,0xF8F8,0xF8F8,0x7777,0x8989,0x8F8F,0x8F8F
	dc.w 0x7777,0x9898,0xF8F8,0xF8F8,0x7777,0x8989,0x8F8F,0x8F8F
	dc.w 0x8080,0x8080,0x4141,0x3E3E,0x0808,0x0808,0x1414,0xE3E3
	dc.w 0x8080,0x8080,0x4141,0x3E3E,0x0808,0x0808,0x1414,0xE3E3
	dc.w 0x8181,0x4242,0x2424,0x1818,0x0606,0x0101,0x8080,0x8080
	dc.w 0x8181,0x4242,0x2424,0x1818,0x0606,0x0101,0x8080,0x8080
	dc.w 0xF0F0,0xF0F0,0xF0F0,0xF0F0,0x0F0F,0x0F0F,0x0F0F,0x0F0F
	dc.w 0xF0F0,0xF0F0,0xF0F0,0xF0F0,0x0F0F,0x0F0F,0x0F0F,0x0F0F
	dc.w 0x0808,0x1C1C,0x3E3E,0x7F7F,0xFFFF,0x7F7F,0x3E3E,0x1C1C
	dc.w 0x0808,0x1C1C,0x3E3E,0x7F7F,0xFFFF,0x7F7F,0x3E3E,0x1C1C
	dc.w 0x1111,0x2222,0x4444,0xFFFF,0x8888,0x4444,0x2222,0xFFFF
	dc.w 0x1111,0x2222,0x4444,0xFFFF,0x8888,0x4444,0x2222,0xFFFF

tab_pattern:
	dc.w 0x0101,0x0202,0x0404,0x0808,0x1010,0x2020,0x4040,0x8080
	dc.w 0x0101,0x0202,0x0404,0x0808,0x1010,0x2020,0x4040,0x8080
	dc.w 0x6060,0xC0C0,0x8181,0x0303,0x0606,0x0C0C,0x1818,0x3030
	dc.w 0x6060,0xC0C0,0x8181,0x0303,0x0606,0x0C0C,0x1818,0x3030
	dc.w 0x4242,0x8181,0x8181,0x4242,0x2424,0x1818,0x1818,0x2424
	dc.w 0x4242,0x8181,0x8181,0x4242,0x2424,0x1818,0x1818,0x2424
	dc.w 0x8080,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080
	dc.w 0x8080,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080
	dc.w 0xFFFF,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	dc.w 0xFFFF,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	dc.w 0xFFFF,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080
	dc.w 0xFFFF,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080
	dc.w 0x0001,0x0002,0x0004,0x0008,0x0010,0x0020,0x0040,0x0080
	dc.w 0x0100,0x0200,0x0400,0x0800,0x1000,0x2000,0x4000,0x8000
	dc.w 0x8003,0x0007,0x000E,0x001C,0x0038,0x0070,0x00E0,0x01C0
	dc.w 0x0380,0x0700,0x0E00,0x1C00,0x3800,0x7000,0xE000,0xC001
	dc.w 0x8001,0x4002,0x2004,0x1008,0x0810,0x0420,0x0240,0x0180
	dc.w 0x0180,0x0240,0x0420,0x0810,0x1008,0x2004,0x4002,0x8001
	dc.w 0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000
	dc.w 0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000,0x8000
	dc.w 0xFFFF,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	dc.w 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	dc.w 0xFFFF,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080
	dc.w 0xFFFF,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080,0x8080
	
tab_line_type:
	dc.w 0xFFFF,0xFFF0,0xE0E0,0xFE38,0xFF00,0xF198

_pattern_ptrs:
	dc.l tab_full_pattern, tab_full_pattern, tab_frames, tab_pattern

	.lcomm tab_cur_work,MAX_WORK*4
	.lcomm fvdi_virtual,4
	.lcomm adr_var_vdi,4
	.lcomm save_contrl,4
	.lcomm save_contrl2,4
	.lcomm save_intin,4
	.lcomm save_intout,4
	.lcomm mouse_op,2
	.lcomm mouse_semaphore,2
	.lcomm mouse_first,4
	.lcomm old_curv,4
	.lcomm old_timv,4
