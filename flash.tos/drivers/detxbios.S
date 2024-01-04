/* TOS 4.04 Xbios dispatcher for the CT60/CTPCI and Coldfire boards
 * and USB-disk / SD-card / Ram-Disk utility
 * Didier Mequignon 2005-2012, e-mail: aniplay@wanadoo.fr
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

#include "config.h"
#include "../include/vars.h"
#define pun_ptr_ahdi 0x516
#undef pun_ptr
#define pun_ptr pun_ptr_usb

#undef DEBUG
#undef DEBUG_XHDI

// #define RAM_DISK_FAT12
#define RAM_DISK_SEC_FAT    64
#define RAM_DISK_SIZE_KB    8192

#define SD_CARD_VERIFY
#define SD_CARD_REPLACE_FLOPPY
#define RAM_DISK_REPLACE_B
#define MINT_IKBD_PATCH

#define MAX_LOGICAL_DRIVE 32

#define Modecode    0x184C

	.global _det_xbios,_old_vector_xbios
	.global _physbase,_logbase,_getrez,_vsetscreen,_wait_vbl,_vsetmode,_montype,_vgetsize,_vsetrgb,_vgetrgb
	.global _cursconf,_info_fvdi,_ltoa,_strcpy,_strcat
	.global _M68k_InstrLen
#ifdef SOUND_AC97
#endif /* SOUND_AC97 */
	.global _validmode,_vmalloc
	.global _vixGetVersion,_vixProbe,_vixInit,_vixDestroy,_vixGetCapability
	.global _vixQueryFourcc,_vixConfigPlayback,_vixPlaybackOn,_vixPlaybackOff
	.global _vixPlaybackFrameSelect,_vixGetGrKeys,_vixSetGrKeys
	.global _vixPlaybackGetEq,_vixPlaybackSetEq,_vixPlaybackGetDeint,_vixPlaybackSetDeint
	.global _InitVideo
	.global _asm_set_ipl
	.global _install_cd_disk,_cd_disk_read_sectors,_cd_disk_drive
	.global _call_enumfunc,_call_ikbdvec,_call_mousevec,_direct_conout
	.global _critical_error,_get_sr
#if defined(DEBUG) || defined(DEBUG_XHDI)
	.global display_string,hex_long,hex_word,hex_byte,display_char,wait_key,_video_found
#endif
	.global _init_before_autofolder,_install_magic_routine
	.global _get_no_cache_memory,_get_no_cache_memory_size,_led_floppy,_code_led

	.data

/* XHDI */

#define XH_DL_SECSIZ 0 // maximal sector size (BIOS level)
#define XH_DL_MINFAT 1 // minimal number of FATs
#define XH_DL_MAXFAT 2 // maximal number of FATs
#define XH_DL_MINSPC 3 // sectors per cluster minimal
#define XH_DL_MAXSPC 4 // sectors per cluster maximal
#define XH_DL_CLUSTS 5 // maximal number of clusters of a 16 bit FAT
#define XH_DL_MAXSEC 6 // maximal number of sectors
#define XH_DL_DRIVES 7 // maximal number of BIOS drives supported by the DOS
	
/* AHDI */

#define PUN_DEV           0x1F /* device number of HD */
#define PUN_UNIT          0x07 /* Unit number */
#define PUN_SCSI          0x08 /* 1=SCSI 0=ACSI */
#define PUN_IDE           0x10 /* Falcon IDE */
#define PUN_USB           0x20 /* USB */
#define PUN_REMOVABLE     0x40 /* Removable media */
#define PUN_VALID         0x80 /* zero if valid */

// if MAX_LOGICAL_DRIVE <> 16 orininal AHDI pun_ptr connot be used
#define _pinfo_puns    0 // 2 bytes
#define _pinfo_pun     2 // MAX_LOGICAL_DRIVE bytes
#define _pinfo_pstart  (_pinfo_pun+MAX_LOGICAL_DRIVE) // MAX_LOGICAL_DRIVE x 4 bytes
#define _pinfo_cookie  (_pinfo_pstart+(MAX_LOGICAL_DRIVE*4)) // 4 bytes
#define _pinfo_cookptr (_pinfo_cookie+4) // 4 bytes
#define _pinfo_vernum  (_pinfo_cookptr+4) // 2 bytes
#define _pinfo_maxsiz  (_pinfo_vernum+2) // 2 bytes
// not inside AHDI
#define _pinfo_ptype   (_pinfo_maxsiz+2) // MAX_LOGICAL_DRIVE x 4 bytes
#define _pinfo_psize   (_pinfo_ptype+(MAX_LOGICAL_DRIVE*4)) // MAX_LOGICAL_DRIVE x 4 bytes
#define _pinfo_flags   (_pinfo_psize+(MAX_LOGICAL_DRIVE*4)) // MAX_LOGICAL_DRIVE x 2 bytes, internal use: B15:swap, B14:stop, B7:change, B0:bootable
#define _pinfo_bpb     (_pinfo_flags+(MAX_LOGICAL_DRIVE*2)) // MAX_LOGICAL_DRIVE x 18 bytes
#define _pinfo_size    (_pinfo_bpb+(MAX_LOGICAL_DRIVE*18))

	.align 2

_det_xbios:

	move.l USP,A0
	btst #5,(SP)             // call in supervisor state
	beq.s .x2
	lea 6(SP),A0
	tst.w proc_type
	beq.s .x2
	tst.w (A0)+              // if > 68000
.x2:
#ifdef DEBUG
	move.l A0,-(SP)
	moveq #0,D0
	move.w (A0),D0           // function
	cmp.l #420,D0
	bhi .x0b
	cmp.l #400,D0            // VIDIX
#if 0
	bcc .x0
	cmp.l #2,D0              // Physbase
	beq.s .x0
	cmp.l #3,D0              // Logbase
	beq.s .x0
	cmp.l #4,D0              // Getrez
	beq.s .x0
	cmp.l #5,D0              // Setscreen
	beq.s .x0
	cmp.l #22,D0             // Gettime
	beq.s .x0
	cmp.l #23,D0             // Settime
	beq.s .x0
	cmp.l #64,D0             // Blitmode
	beq.s .x0
	cmp.l #88,D0             // Vsetmode
	beq.s .x0
	cmp.l #89,D0             // Mon_type
	beq.s .x0
	cmp.l #91,D0             // Vgetsize
	beq.s .x0
	cmp.l #93,D0             // Vsetrgb
	beq.s .x0
	cmp.l #94,D0             // Vgetrgb
	beq.s .x0
	cmp.l #95,D0             // ValidMode (undocumented)
	beq.s .x0
	cmp.l #141,D0            // Buffptr
	bhi.s .x0b
	cmp.l #128,D0            // Locksnd
#endif
	bcs.s .x0b	
.x0:
	lea debug1(PC),A0
	jsr display_string
	move.l (SP),A0
	move.w (A0),D0           // opcode function
	jsr hex_word
	moveq #13,D0
	jsr display_char
	moveq #10,D0
	jsr display_char
.x0b:
	move.l (SP)+,A0
#endif
#ifdef PATCH_NVDI
	move.l A2,-(SP)
	move.l 0xB8,A1           // TRAP #14
	move.l A1,A2
	moveq #0,D1
.loop_xbra:
		cmp.l #0x58425241,-12(A1) // XBRA
		bne.s .no_xbra
		cmp.l #0x4E564449,-8(A1)  // NVDI
		bne.s .not_nvdi
		move.l A1,D1
		bra.s .next_xbra
.not_nvdi:
		cmp.l #0x5F504349,-8(A1) // _PCI
		bne.s .next_xbra
		tst.l D1
		beq.s .no_xbra           // NVDI not found before _PCI
		move.l -4(A1),-4(A2)     // remove _PCI XBRA
		move.l 0xB8,-4(A1)       // install _PCI XBRA at the top
		move.l A1,0xB8           // TRAP #14
		bra.s .no_xbra
.next_xbra:
		move.l -4(A1),D0         // next
		beq.s .no_xbra           // no vector
		move.l A1,A2             // previous
		move.l D0,A1
	bra.s .loop_xbra
.no_xbra:
	move.l (SP)+,A2
#endif /* PATCH_NVDI */
	move.w (A0),D0           // function
	tst.l _info_fvdi
	beq .x11
	cmp.w #2,D0              // Physbase
	bne.s .x9
	jsr _physbase
	rte	
.x9:
	cmp.w #3,D0              // Logbase
	bne.s .x31
	jsr _logbase
	rte	
.x31:
	cmp.w #4,D0              // Getrez
	bne.s .x26
	jsr _getrez
	rte
.x26:
	cmp.w #5,D0              // Setscreen
	bne .x3
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug2(PC),A0
	jsr display_string
	move.l (SP)+,A0
	move.l 2(A0),D0
	jsr hex_long
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.l 6(A0),D0
	jsr hex_long
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 10(A0),D0
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 12(A0),D0
	jsr hex_word	
	moveq #13,D0
	jsr display_char
	moveq #10,D0
	jsr display_char
#endif
	moveq #1,D0
	move.l D0,-(SP)          // init var VDI
	move.w 12(A0),D0         // modecode
	ext.l D0
	move.l D0,-(SP)
	move.w 10(A0),D0         // rez
	ext.l D0
	move.l D0,-(SP)
	move.l 6(A0),-(SP)       // logical address
	move.l 2(A0),-(SP)       // physical address
	jsr _vsetscreen
	lea 20(SP),SP
	rte
.x3:
	cmp.l #21,D0             // Cursconf
	bne.s .x25
	move.w 4(A0),-(SP)       // operand
	move.w 2(A0),-(SP)       // function
	jsr _cursconf            // VDI ESC VT52
	addq.l #4,SP
	rte
.x25:
	cmp.w #37,D0             // Vsync
	bne.s .x28
	jsr _wait_vbl
	beq.s .x29               // TOS routine
	rte
.x29:
	move.w SR,-(SP)
	and.w #0xF8FF,SR
	move.l _frclock,D0
.x30:
	cmp.l _frclock,D0        // enable VBL interrupt
	beq.s .x30
	move.w (SP)+,SR
	rte
.x28:
	cmp.w #64,D0             // Blitmode
	bne.s .x4
	moveq #0,D0              // no blitter  
	rte
.x4:
	cmp.w #88,D0             // Vsetmode
	bne.s .x5
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug6(PC),A0
	jsr display_string
	move.l (SP)+,A0
	move.w 2(A0),D0
	jsr hex_word
	moveq #13,D0
	jsr display_char
	moveq #10,D0
	jsr display_char
#endif
	move.w 2(A0),D0          // modecode
	ext.l D0
	move.l D0,-(SP)
	jsr _vsetmode
	and.l #0xFFFF,D0
	addq.l #4,SP
	rte
.x5:
	cmp.w #89,D0             // Mon_type
	bne.s .x6
	jsr _montype
	rte
.x6:
	cmp.w #91,D0             // Vgetsize
	bne.s .x7
	move.w 2(A0),D0          // modecode
	ext.l D0
	move.l D0,-(SP)
	jsr _vgetsize
	addq.l #4,SP
	rte
.x7:
	cmp.w #93,D0             // Vsetrgb
	bne.s .x8
	move.l 6(A0),-(SP)       // array	
	moveq #0,D0
	move.w 4(A0),D0          // count		
	move.l D0,-(SP)
	move.w 2(A0),D0          // index
	move.l D0,-(SP)
	jsr _vsetrgb
	lea 12(SP),SP
	rte
.x8:
	cmp.w #94,D0             // Vgetrgb
	bne.s .x10
	move.l 6(A0),-(SP)       // array
	moveq #0,D0
	move.w 4(A0),D0          // count		
	move.l D0,-(SP)
	move.w 2(A0),D0          // index
	move.l D0,-(SP)
	jsr _vgetrgb
	lea 12(SP),SP
	rte
.x10:
	cmp.w #95,D0             // ValidMode (undocumented, used by AES before v_opnwk or set_video dialog box)
	bne.s .x11
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug7(PC),A0
	jsr display_string
	move.l (SP)+,A0
	move.w 2(A0),D0
	jsr hex_word
	moveq #13,D0
	jsr display_char
	moveq #10,D0
	jsr display_char
#endif
	move.w 2(A0),D0          // modecode
	ext.l D0
	move.l D0,-(SP)
	jsr _validmode
	addq.l #4,SP
	rte
.x11:
	tst.l _info_fvdi
	beq.s .x1
	cmp.w #0xc60e,D0         // ct60_vmalloc
	beq.s .x12
	cmp.w #0xc6e,D0          // bis
	bne.s .x14
.x12:
	move.l 4(A0),-(SP)
	move.w 2(A0),D0          // value
	ext.l D0
	move.l D0,-(SP)          // mode
	jsr _vmalloc
	addq.l #8,SP
	rte
.x14:
#define VIDIX
	cmp.w #420,D0
	bhi .x1
	cmp.w #400,D0            // VIDIX
	bcs .x1
	sub.w #400,D0
	move.w tab_vidix_bios(PC,D0.w*2),D0
	bmi .x1                // original TOS XBIOS
	jsr tab_vidix_bios(PC,D0.w)
	rte
#ifdef VIDIX
tab_vidix_bios:
	dc.w vixGetVersion-tab_vidix_bios // 400
	dc.w vixProbe-tab_vidix_bios // 401
	dc.w vixInit-tab_vidix_bios // 402
	dc.w vixDestroy-tab_vidix_bios // 403
	dc.w vixGetCapability-tab_vidix_bios // 404
	dc.w vixQueryFourcc-tab_vidix_bios // 405
	dc.w vixConfigPlayback-tab_vidix_bios // 406
	dc.w vixPlaybackOn-tab_vidix_bios // 407
	dc.w vixPlaybackOff-tab_vidix_bios // 408
	dc.w vixPlaybackFrameSelect-tab_vidix_bios // 409
	dc.w vixGetGrKeys-tab_vidix_bios // 410
	dc.w vixSetGrKeys-tab_vidix_bios // 411
	dc.w vixPlaybackGetEq-tab_vidix_bios // 412
	dc.w vixPlaybackSetEq-tab_vidix_bios // 413
	dc.w vixPlaybackGetDeint-tab_vidix_bios // 414
	dc.w vixPlaybackSetDeint-tab_vidix_bios // 415
	dc.w vixPlaybackCopyFrame-tab_vidix_bios // 416
	dc.w vixQueryDMAStatus-tab_vidix_bios // 417
	dc.w -1 // 418
	dc.w -1 // 419
	dc.w InitVideo-tab_vidix_bios // 420
#endif /* VIDIX */
.x1:
#ifdef PATCH_NVDI
	/* if XBRA moved can't use  _old_vector_xbios */
	cmp.l #0x58425241,-12(A1) // XBRA
	bne.s .x27
	cmp.l #0x5F504349,-8(A1)  // _PCI
	bne.s .x27
	move.l -4(A1),D0          // next
	beq.s .x27
	move.l D0,-(SP)
	rts	
.x27:
#endif /* PATCH_NVDI */
	move.l _old_vector_xbios,-(SP)
	rts

#ifdef VIDIX	
vixGetVersion:
	
	jmp _vixGetVersion
	
vixProbe:

	move.l 6(A0),-(SP) // force
	move.l 2(A0),-(SP) // verbose
	jsr _vixProbe
	addq.l #8,SP
	rts
	
vixInit:

	jmp _vixInit
	
vixDestroy:

	jmp _vixDestroy

vixGetCapability:

	move.l 2(A0),-(SP) // to
	jsr _vixGetCapability
	addq.l #4,SP
	rts
	
vixQueryFourcc:

	move.l 2(A0),-(SP) // to
	jsr _vixQueryFourcc
	addq.l #4,SP
	rts

vixConfigPlayback:

	move.l 2(A0),-(SP) // info
	jsr _vixConfigPlayback
	addq.l #4,SP
	rts
	
vixPlaybackOn:

	jmp _vixPlaybackOn
	
vixPlaybackOff:

	jmp _vixPlaybackOff

vixPlaybackFrameSelect:

	move.l 2(A0),-(SP) // frame
	jsr _vixPlaybackFrameSelect
	addq.l #4,SP
	rts
	
vixGetGrKeys:

	move.l 2(A0),-(SP) // grkey
	jsr _vixGetGrKeys
	addq.l #4,SP
	rts
	
vixSetGrKeys:
	
	move.l 2(A0),-(SP) // grkey
	jsr _vixSetGrKeys
	addq.l #4,SP
	rts
	
vixPlaybackGetEq:

	move.l 2(A0),-(SP) // eq
	jsr _vixPlaybackGetEq
	addq.l #4,SP
	rts
	
vixPlaybackSetEq:

	move.l 2(A0),-(SP) // eq
	jsr _vixPlaybackSetEq
	addq.l #4,SP
	rts
	
vixPlaybackGetDeint:

	move.l 2(A0),-(SP) // info
	jsr _vixPlaybackGetDeint
	addq.l #4,SP
	rts
	
vixPlaybackSetDeint:

	move.l 2(A0),-(SP) // info
	jsr _vixPlaybackSetDeint
	addq.l #4,SP
	rts
	
vixPlaybackCopyFrame:

	move.l 2(A0),-(SP) // dmai
	jsr _vixPlaybackCopyFrame
	addq.l #4,SP
	rts

vixQueryDMAStatus:

	jmp _vixQueryDMAStatus
	
InitVideo:
	jmp _InitVideo
#endif /* VIDIX */

#ifdef DEBUG
dump:
	lea -20(SP),SP
	movem.l D0-D2/A0-A1,(SP)
	moveq #31,D1
.loop_dump1:
		moveq #15,D2
.loop_dump2:
			move.b (A1)+,D0
			jsr hex_byte
			moveq #0x20,D0
			jsr display_char
		subq.l #1,D2
		bpl.s .loop_dump2
		lea -16(A1),A1
		moveq #15,D2
.loop_dump3:
			moveq #0,D0
			move.b (A1)+,D0
			cmp.l #0x20,D0
			bcs.s .dump_bad_char
			cmp.l #0x7F,D0
			bcs.s .dump_ok
.dump_bad_char:
			moveq #0x2E,D0
.dump_ok:
			jsr display_char
		subq.l #1,D2
		bpl.s .loop_dump3
		moveq #13,D0
		jsr display_char
		moveq #10,D0
		jsr display_char
	subq.l #1,D1
	bpl.s .loop_dump1
	movem.l (SP),D0-D2/A0-A1
	lea 20(SP),SP
	rts
#endif /* DEBUG */

install_xbra:	// A0: handler, D0: vector, D1: ID 

	lea -28(SP),SP
	movem.l D1-D3/A0-A3,(SP)
	moveq #0,D3
	move.w D0,D3             // vector
	move.l A0,A3             // handler
	move.l D1,-(SP)
	move.w #3,-(SP)          // TT ram if possible
	move.l #18,-(SP)         // size
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	move.l (SP)+,D1
	tst.l D0
	beq.s .error_xbra
	move.l D0,A0
	move.l #0x58425241,(A0)+ // XBRA
	move.l D1,(A0)+
	clr.l (A0)+	
	move.w #0x4EF9,(A0)+     // JMP
	move.l A3,(A0)+          // handler
	lea -10(A0),A0
	cpusha BC
.end_install_xbra:
	move.l D3,A1
	move.l (A1),D0
	move.l D0,(A0)+          // old vector
	move.l A0,(A1)           // JMP, new vector
.error_xbra:
	tst.l D0
	movem.l (SP),D1-D3/A0-A3
	lea 28(SP),SP
	rts





_install_cd_disk:

	lea -32(SP),SP
	movem.l D1-D4/A0-A3,(SP)
	move.l _dskbufp,-(SP)    // buffer
	moveq #1,D0
	move.l D0,-(SP)          // num_sectors	
	clr.l -(SP)              // sector_start
	jsr _cd_disk_read_sectors
	addq.l #8,SP
	move.l (SP)+,A0          // buffer
	tst.l D0
	bne .error_install_cd_disk
	moveq #0,D2
	move.l #256,D1
.loop_sum_root_cd_disk:
		moveq #0,D0
		move.w (A0)+,D0
		add.l D0,D2
	subq.l #1,D1
	bgt.s .loop_sum_root_cd_disk
	move.l _dskbufp,A0
	move.l (A0),D0
	and.l #0xFFFF,D0
	cmp.l #0x4344,D0         // CD
	bne.s .check_crc_cd_disk
	move.l 4(A0),D0
	cmp.l #0x6261636B,D0     // back
	beq.s .cd_backup_found
.check_crc_cd_disk:	
	and.l #0xFFFF,D2
	cmp.l #0x1234,D2         // checksum
	bne.s .error_install_cd_disk
	lea 0x1C6(A0),A0         // partition table
	moveq #4,D4
.loop_partitions_tos_cd_disk:
		move.l (A0),D1
		and.l #0xFFFFFF,D1 // part_type
		beq.s .next_partition_tos_cd_disk
		cmp.l #0x58474D,D1 // XGM
		beq.s .next_partition_tos_cd_disk
		move.l 4(A0),D2  // part_offset
		move.l 8(A0),D3  // part_size
		bra.s .install_partition_cd_disk
.next_partition_tos_cd_disk:
		lea 12(A0),A0
	subq.l #1,D4
	bgt.s .loop_partitions_tos_cd_disk
.cd_backup_found:
	moveq #0,D2              // no partition table
	moveq #0,D2
	move.l #0x42474D,D1      // BGM
	bra.s .install_partition_cd_disk
.error_install_cd_disk:
	moveq #0,D0              // nothing installed
	bra .end_install_cd_disk
.install_partition_cd_disk:
	move.l D1,part_type_cd
	move.l D2,part_offset_cd
	move.l D3,part_size_cd
	move.l _dskbufp,-(SP)    // buffer
	moveq #1,D0
	move.l D0,-(SP)          // num_sectors	
	move.l D2,-(SP)          // part_offset
	jsr _cd_disk_read_sectors
	lea 12(SP),SP
	tst.l D0
	bne .error_install_cd_disk
	move.l _dskbufp,A0       // boot sector
	lea tab_bpb_cd,A1
	move.l part_type_cd,D1
	and.l #0xFFFFFF,D1       // ID GEMDOS
	cmp.l #0x47454D,D1       // GEM up to 16M
	beq.s .partition_ok_cd
	cmp.l #0x42474D,D1       // BGM over 16M
	bne .error_install_cd_disk
.partition_ok_cd:
	moveq #0,D2
	move.b 0xC(A0),D2
	asl.l #8,D2
	move.b 0xB(A0),D2        // BPS
	move.w D2,(A1)           // sector size in bytes
	beq .error_install_cd_disk
	moveq #0,D1
	move.b 0xD(A0),D1        // SPC
	move.w D1,2(A1)          // cluster size in sectors
	move.w D1,D0
	mulu D2,D0
	move.w D0,4(A1)          // cluster size in bytes
	moveq #0,D0
	move.b 0x12(A0),D0
	asl.l #8,D0
	move.b 0x11(A0),D0       // NDIRS
	asl.l #5,D0              // * 32
	tst.l D2
	beq .error_install_cd_disk
	divu D2,D0               // / sector size
	move.w D0,6(A1)          // size directory in sectors
	moveq #0,D2
	move.b 0x17(A0),D2
	asl.l #8,D2
	move.b 0x16(A0),D2       // SPF
	move.w D2,8(A1)          // FAT size
	moveq #0,D0
	move.b 0xF(A0),D0
	asl.l #8,D0
	move.b 0xE(A0),D0        // RES
	move.l D0,D3
	add.l D2,D3              // + FAT size
	move.w D3,10(A1)         // 1st sector of FAT2 
	moveq #0,D3
	move.b 0x10(A0),D3       // NFATS
	mulu D2,D3               // * FAT size
	add.l D0,D3              // + RES
	moveq #0,D0
	move.w 6(A1),D0          // size directory in sectors
	add.l D3,D0
	move.w D0,12(A1)         // 1st data sector
	moveq #0,D2
	move.b 0x14(A0),D2
	asl.l #8,D2
	move.b 0x13(A0),D2       // NSECTS
	bne.s .nsects_ok_cd
	move.l part_size_cd,D2   // partition size in sectors
	beq .error_install_cd_disk
	sub.l D0,D2              // - 1st data sector
.nsects_ok_cd:
	tst.l D1
	beq .error_install_cd_disk
	divu D1,D2
	move.w D2,14(A1)         // total clusters
	moveq #1,D0
	move.w D0,16(A1)         // FAT 16
	move.w SR,D0
	move.w D0,-(SP)
	or.l #0x700,D0           // mask interrupts
	move.w D0,SR
	move.l #0x5F43445F,D1    // _CD_
	lea det_hdv_bpb_cd(PC),A0
	move.w #hdv_bpb,D0
	bsr install_xbra
	move.l D0,old_hdv_bpb_cd
	lea det_hdv_rw_cd(PC),A0
	move.w #hdv_rw,D0
	bsr install_xbra
	move.l D0,old_hdv_rw_cd
	lea det_hdv_mediach_cd(PC),A0
	move.w #hdv_mediach,D0
	bsr install_xbra
	move.l D0,old_hdv_mediach_cd
	move.w (SP)+,D0
	move.w D0,SR
	moveq #1,D1              // drive B
	move.l D1,_cd_disk_drive
	moveq #2,D0
	move.l D0,_change_cd_disk
	move.l _drvbits,D0
	bset D1,D0
	move.l D0,_drvbits
	move.l _cd_disk_drive,D0 // OK
.end_install_cd_disk:
	movem.l (SP),D1-D4/A0-A3
	lea 32(SP),SP
	rts

det_hdv_bpb_cd:

 	moveq #0,D0
	move.w 4(SP),D0          // drive
	cmp.l _cd_disk_drive,D0
	beq.s .dhbc1
	move.l old_hdv_bpb_cd,-(SP)
	rts
.dhbc1:
	move.l A0,-(SP)
#ifdef DEBUG
	lea debug4(PC),A0
	jsr display_string	
#endif
	lea tab_bpb_cd,A0
	move.l A0,D0
	move.l (SP)+,A0
	rts

det_hdv_rw_cd:

 	moveq #0,D0
	move.w 14(SP),D0         // drive
	cmp.l _cd_disk_drive,D0
	beq.s .dhrc1
	move.l old_hdv_rw_cd,-(SP)
	rts
.dhrc1:
	movem.l D1-D3/A0-A1,-(SP)
#ifdef DEBUG
	lea debug3(PC),A0
	jsr display_string	
	move.w 4+20(SP),D0       // rwflag
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.l 6+20(SP),D0       // buffer
	jsr hex_long
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 10+20(SP),D0      // num sectors
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 12+20(SP),D0      // logical sector
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 14+20(SP),D0      // drive
	jsr hex_word
	moveq #13,D0
	jsr display_char
	moveq #10,D0
	jsr display_char
#endif
	moveq #0,D2
	move.w 12+20(SP),D2      // logical sector
	bpl.s .dhrc5
	move.l 16+20(SP),D2      // logical sector	
.dhrc5:
	tst.l D2
	bmi.s .dhrc6             // negative logical sector
	move.l 6+20(SP),D1       // buffer
	beq.s .dhrc4
	move.l part_offset_cd,D3
	lea tab_bpb_cd,A0
	move.w 14(A0),D0         // total clusters
	mulu 2(A0),D0            // cluster size in sectors
	cmp.l D0,D2              // logical sector to hight
	bcc.s .dhrc6
	moveq #0,D0
	move.w (A0),D0           // sector size
	lsr.l #8,D0
	lsr.l #1,D0              // / 512
	move.l D1,A0             // buffer
	move.w 10+20(SP),D1      // num sectors
	beq.s .dhrc4             // no sectors
	mulu D0,D1
	mulu.l D0,D2
	add.l D3,D2              // start sector
	move.l D1,D3             // count
	btst #0,5+20(SP)         // rwflag
	beq.s .dhrc2             // read
	moveq #-13,D0            // write protect
	bra.s .dhrc3
.dhrc6:
	moveq #-1,D0             // error
	bra.s .dhrc3
.dhrc2:
	move.l A0,-(SP)          // buffer
	move.l D3,-(SP)          // num_sectors	
	move.l D2,-(SP)          // sector_start
	jsr _cd_disk_read_sectors
	lea 12(SP),SP
	tst.l D0
	ble.s .dhrc3
	moveq #-11,D0            // read error
.dhrc4:
	moveq #0,D0
.dhrc3:
	movem.l (SP)+,D1-D3/A0-A1
 	rts

det_hdv_mediach_cd:

 	moveq #0,D0
	move.w 4(SP),D0          // drive
	cmp.l _cd_disk_drive,D0
	beq.s .dhmc1
	move.l old_hdv_mediach_cd,-(SP)
	rts
.dhmc1:
#if 0 // #ifdef DEBUG
	move.l A0,-(SP)
	lea debug5(PC),A0
	jsr display_string
	move.l (SP)+,A0
#endif
	move.l _change_cd_disk,D0
	clr.l _change_cd_disk
	rts


	
_asm_set_ipl:

	link A6,#-8
	movem.l D6-D7,(SP)
	move.w SR,D7             // current SR
	move.l D7,D0             // prepare return value
	and.l #0x0700,D0         // mask out IPL
	lsr.l #8,D0              // IPL
	move.l 8(A6),D6          // get argument
	and.l #7,D6              // least significant three bits
	lsl.l #8,D6              // move over to make mask
	and.l #0x0000F8FF,D7     // zero out current IPL
	or.l D6,D7               // place new IPL in SR
	move.w D7,SR
	movem.l (SP),D6-D7
	lea 8(SP),SP
	unlk A6
	rts


text_color:

	moveq #0,D0
	move.w 0x3E86,D0         // number of planes
	cmp.l #2,D0
	bls.s .black_and_white
	pea (A0)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
.black_and_white:
	rts
	
_call_enumfunc:

	lea -20(SP),SP
	movem.l D1-D2/A0-A2,(SP)
	move.l 24(SP),A2         // enumfunc
	move.l 28(SP),A0         // si
	move.l 32(SP),D0         // flags
	move.l D0,-(SP)
	move.l A0,-(SP)
	jsr (A2)
	addq.l #8,SP
	movem.l (SP),D1-D2/A0-A2
	lea 20(SP),SP
	rts

_call_ikbdvec:

	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
	move.l 28(SP),D0         // ikbd code
	and.l #0xFF,D0
	move.l 32(SP),A0         // iorec
	move.l 36(SP),A2         // &kbdvecs[-1]
	move.l (A2),A2           // ikbdvec
	jsr (A2)
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	rts

	dc.l 0x58425241          // XBRA
	dc.l 0x4D694E54          // MiNT
	dc.l 0

_call_mousevec:

	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
	move.l 28(SP),A0         // data
	move.l 32(SP),A2
	move.l (A2),A2           // mousevec
	jsr (A2)
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	rts

	
_direct_conout:

	lea -60(SP),SP
	movem.l D0-A6,(SP)
	move.l 64(SP),D1
	and.l #0xFF,D1
#if defined(DEBUG) && !defined(COLDFIRE)
	tst.w _video_found
	beq.s .normal_conout 
	move.l D1,D0
	bsr display_char             // display_char can use always the Videl
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rts
.normal_conout:		
#endif
	move.l con_state,A0
	tst.w _os_magic
	bne.s .os_magic	
	lea 0x3E86,A4                // TOS404 LINEA vars !!!
.os_magic:
	jsr (A0)	
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rts

_critical_error:

	move.l (SP),D0
	move.l etv_critic,-(SP)
	rts

_get_sr:
	moveq #0,D0
	move SR,D0
	rts
	
magic_routine:
	
	movem.l D0-D1/A0-A1,-(SP)
	jsr _init_before_autofolder
	movem.l (SP)+,D0-D1/A0-A1
	rts
end_magic_routine:

_install_magic_routine:

	lea magic_routine(PC),A0
	pea end_magic_routine(PC)
	move.l phystop,A1
	lea -1024(A1),A1             // let the space for a boot routine (512 bytes)
	move.l #0x12123456,(A1)      // magic key
	move.l A1,4(A1)
	move.w #((512-8)/2)-2,D1
	move.w (A1)+,D0
	add.w (A1)+,D0
	add.w (A1)+,D0
	add.w (A1)+,D0
.copy_magic_routine:
		cmp.l (SP),A0
		bcc.s .fill_end_magic_routine
		add.w (A0),D0
		move.w (A0)+,(A1)+
	dbf D1,.copy_magic_routine
	bra.s .end_copy_magic_routine
.fill_end_magic_routine:
		clr.w (A1)+
	dbf D1,.fill_end_magic_routine
.end_copy_magic_routine:
	move.w #0x5678,D1            // checksum
	sub.w D0,D1
	move.w D1,(A1)+
	addq.l #4,SP
	rts

_get_no_cache_memory:

	movem.l A0-A5,-(SP)
	move.w SR,-(SP)
	or.w #0x700,SR               // no interrupts
	lea .no_memory(PC),A1
	move.l 8,A5                  // bus error
	move.l A1,8
	move.l SP,A4                 // save ssp
	moveq #0,D0
	move.l ramtop,A0
	clr.l (A0)                   // if access fault it's PMMU tree
	move.l A0,D0                 // buffer
.no_memory:
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	movem.l (SP)+,A0-A5
	rts

_get_no_cache_memory_size:

	move.l D1,-(SP)
	bsr _get_no_cache_memory
	tst.l D0
	beq.s .no_memory_size
	move.l D0,D1
	movec.l SRP,D0               // PMMU tree
	sub.l D1,D0
	moveq #32,D1
.loop_find_first_msb:
		subq.l #1,D1
		add.l D0,D0 // search the first MSB to 1
		bcs.s .found_first_msb
	tst.l D1
	bne.s .loop_find_first_msb
	moveq #0,D0                  // not found ?
	bra.s .no_memory_size
.found_first_msb:
	moveq #0,D0
	bset D1,D0                   // size alignment
.no_memory_size:
	move.l (SP)+,D1
	rts
	
led_floppy:

	move.l A0,-(SP)	
	move.l D0,-(SP)
	bsr _led_floppy
	move.l (SP)+,D0
	move.l (SP)+,A0
	rts

_led_floppy:

	lea 0xFFFF8800,A0        // PSG sound
	moveq #7,D0
	move.b D0,(A0)           // ports A & B
	move.b #0xC0,D0          // are outputs
	move.b D0,2(A0)
	moveq #14,D0             // port A
	move.b D0,(A0)
	tst.l 4(SP)
	seq.b D0
	and.b #7,D0              // disable floppy: 7
	move.b D0,2(A0)
	rts

tempo_mfp:

	movem.l D0/A0,-(SP)
	lea 0xfffffa01,A0        // MFP 68901
	clr.b 24(A0)             // TACR stop timer A
	bclr #5,18(A0)           // IMRA interrupt mask timer A
	bclr #5,6(A0)            // IERA
	bclr #5,10(A0)           // IPRA no pending
	bclr #5,14(A0)           // ISRA
	moveq #49,D0             // 0.5 S 
.tm1:
		move.b #124,30(A0)       // TADR init timer A MFP for 10091 uS
		move.b #7,24(A0)         // TACR (prediv /200)
		bset #5,6(A0)            // IERA enable
		bclr #5,10(A0)           // IPRA clear timer A
.tm2:
		btst #5,10(A0)           // IPRA wait timer A
		beq.s .tm2
		clr.b 24(A0)             // TACR stop timer A
	dbf D0,.tm1
	movem.l (SP)+,D0/A0
	rts

_code_led:
	move.l 4(SP),D0
	// 1: SDRAM refresh error
	// 3: SDRAM read/write error
	// 6: Keyboard error
	// 7: Exception error
	// 9: BIOS checksum error
	// 11: Memory test error
	subq.l #1,D0
	bmi.s .cl1
.cl2:
		move.l D0,-(SP)
		moveq #1,D0
		bsr led_floppy	
		bsr tempo_mfp
		moveq #0,D0
		bsr led_floppy
		bsr tempo_mfp
		move.l (SP)+,D0
	dbf D0,.cl2
.cl1:
	bsr tempo_mfp
	bsr tempo_mfp
	bsr tempo_mfp
	bsr tempo_mfp
	rts		
	

message:	.asciz "Ram-disk installed in "
crlf:	.byte 13,10,0
space:	.asciz " "
error:	.asciz "No ram-disk installed, "
error1:	.ascii "no enough memory"
	.byte 13,10,0
error2:	.ascii "all drives already used"
	.byte 13,10,0
error3:	.ascii "error disk name"
	.byte 13,10,0
error4:	.ascii "partition type not supported"
	.byte 13,10,0
blue:	.byte 0x1B,0x62,0x34,0
black:	.byte 0x1B,0x62,0x3F,0

#ifdef DEBUG
debug1:	.asciz "XBIOS #0x"
debug2:	.asciz "Setscreen 0x"
debug3:	.asciz "hdv_rw 0x"
debug4:	.ascii "hdv_bpb"
	.byte 13,10,0
debug5:	.ascii "hdv_mediach"
	.byte 13,10,0
debug6:	.asciz "Vsetmode 0x"
debug7:	.asciz "ValidMode 0x"
debug8:	.asciz "Gettime 0x"
#endif
#ifdef DEBUG_XHDI
debug130:	.asciz "XHDI return 0x"
debug131:	.asciz "XHDI XHDrvMap 0x"
debug132:	.asciz "XHDI XHReadWrite major 0x"
debug133:	.asciz "XHDI XHInqTarget major 0x"
debug133a:	.asciz "XHDI XHInqTarget2 major 0x"
debug134:	.asciz "XHDI XHInqDev device 0x"
debug135:	.asciz "XHDI XHInqDriver device 0x"
debug136:	.asciz "XHDI XHInqDev2 device 0x"
debug137:	.asciz "XHDI XHDOSLimits which 0x"
debug138:	.ascii "XHDI XHGetVersion"
	.byte 13,10,0
debug139:	.asciz "XHDI XHEject major 0x"
debug140:	.asciz ", minor 0x"
debug141:	.asciz ", rwflag 0x"
debug142:	.asciz ", sector 0x"
debug143:	.asciz ", count 0x"
debug144:	.asciz ", buffer 0x"
debug145:	.asciz "XHDI XHLock major 0x"
debug146:	.asciz "XHDI call default routine 0x"
debug147:	.asciz " function 0x"
debug148:	.asciz "XHDI XHGetCapacity major 0x"
#endif

	.align 2

	.lcomm _address_ram_disk,4
	.lcomm _size_ram_disk,4
	.lcomm _change_ram_disk,4
	.lcomm _ext_write_protect_ram_disk,4
	.lcomm _ram_disk_drive,4
	.lcomm old_hdv_bpb,4
	.lcomm old_hdv_rw,4
	.lcomm old_hdv_mediach,4
	.lcomm _change_cd_disk,4
	.lcomm _cd_disk_drive,4
	.lcomm old_hdv_bpb_cd,4
	.lcomm old_hdv_rw_cd,4
	.lcomm old_hdv_mediach_cd,4
	.lcomm part_type_cd,4
	.lcomm part_offset_cd,4
	.lcomm part_size_cd,4
	.lcomm tab_bpb_cd,32
	
