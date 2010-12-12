/* TOS 4.04 Xbios dispatcher for the CT60/CTPCI boards
 * and USB-disk / Ram-Disk utility
 * Didier Mequignon 2005-2010, e-mail: aniplay@wanadoo.fr
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
#ifdef COLDFIRE
#include "../include/fire.h"
#else
#undef pun_ptr
#define pun_ptr pun_ptr_usb
#endif

// #define RAM_DISK_FAT12
#define RAM_DISK_SEC_FAT    64
#define RAM_DISK_SIZE_KB    8192

#define MAX_LOGICAL_DRIVE 16

#define Modecode    0x184C

#undef DEBUG

	.global _det_xbios,_old_vector_xbios
	.global _physbase,_getrez,_vsetscreen,_vsetmode,_montype,_vgetsize,_vsetrgb,_vgetrgb
	.global _cursconf
#ifdef COLDFIRE
	.global _acp_new_hardware
#ifndef MCF5445X
#ifndef MCF547X
#ifdef NETWORK
#ifdef LWIP
	.global _settime,_gettime
#endif
#endif
#endif
#endif
#endif /* COLDFIRE */
#ifdef SOUND_AC97
#ifdef COLDFIRE
#ifdef NETWORK
#ifndef MCF5445X
	.global _locksnd,_unlocksnd,_soundcmd,_setbuffer,_setmode,_settracks,_setmontracks
	.global _setinterrupt,_buffoper,_gpio,_devconnect,_sndstatus,_buffptr
	.global _flag_snd_init,_count_timer_a,_preload_timer_a,_timer_a_enabled,_io7_enabled;
#endif
#endif
#endif
#endif /* SOUND_AC97 */
	.global _validmode,_vmalloc
	.global _vixGetVersion,_vixProbe,_vixInit,_vixDestroy,_vixGetCapability
	.global _vixQueryFourcc,_vixConfigPlayback,_vixPlaybackOn,_vixPlaybackOff
	.global _vixPlaybackFrameSelect,_vixGetGrKeys,_vixSetGrKeys
	.global _vixPlaybackGetEq,_vixPlaybackSetEq,_vixPlaybackGetDeint,_vixPlaybackSetDeint
	.global _InitVideo
	.global _asm_set_ipl
#if defined(CONFIG_USB_UHCI) || defined(CONFIG_USB_OHCI) || defined(CONFIG_USB_EHCI)
#ifdef CONFIG_USB_STORAGE
	.global _install_usb_stor,_usb_stor_read,_usb_stor_write,_usb_1st_disk_drive
#endif
#endif
#ifdef NETWORK
#ifdef COLDFIRE
#ifdef LWIP
	.global _disable_caches,_enable_caches,_flush_caches,_flush_dc,_flush_ic
#if !defined(MCF547X) && !defined(MCF5445X)
	.global _set_intfrcl,_clr_intfrcl
#endif
#endif /* LWIP */
#endif /* COLDFIRE */
	.global _install_ram_disk,_address_ram_disk,_size_ram_disk,_change_ram_disk,_ext_write_protect_ram_disk
	.global _alert_tos
#endif /* NETWORK */
	.global _call_enumfunc,_call_ikbdvec,_call_mousevec,_direct_conout
	.global _critical_error,_get_sr
#ifdef DEBUG
	.global display_string,hex_long,hex_word,hex_byte,display_char,wait_key,_video_found
#endif

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

#define pinfo_puns     0  // 2 bytes
#define pinfo_pun      2  // 16 bytes
#define pinfo_pstart  18  // 16 x 4 bytes
#define pinfo_cookie  82  // 4 bytes
#define pinfo_cookptr 86  // 4 bytes
#define pinfo_vernum  90  // 2 bytes
#define pinfo_maxsiz  92  // 2 bytes
#define pinfo_ptype   94  // 16 x 4 bytes
#define pinfo_psize  158  // 16 x 4 bytes
#define pinfo_flags  222  // 16 x 2 bytes, internal use: B15:swap, B7:change, B0:bootable
#define pinfo_bpb    256  // 16 x 32 bytes
#define pinfo_size   768

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
debug132:	.asciz "XHDI XHReadWrite 0x"
debug133:	.ascii "XHDI XHInqTarget"
	.byte 13,10,0
debug134:	.ascii "XHDI XHInqDev"
	.byte 13,10,0
debug135:	.ascii "XHDI XHInqDriver"
	.byte 13,10,0
debug136:	.ascii "XHDI XHInqDev2"
	.byte 13,10,0
debug137:	.ascii "XHDI XHDOSLimits"
	.byte 13,10,0
	
	.align 2
#endif

_det_xbios:

#ifdef COLDFIRE
	.chip 68060
	move.l USP,A0            // V4
	.chip 5200
#else
	move.l USP,A0
#endif
	btst #5,(SP)             // call in supervisor state
	beq.s .x2
	lea.l 6(SP),A0
	tst.w proc_type
	beq.s .x2
	tst.w (A0)+              // if > 68000
.x2:
#ifdef DEBUG
	move.l A0,-(SP)
	moveq #0,D0
	move.w (A0),D0           // function
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
#ifndef COLDFIRE
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
		cmp.l #0x5F504349,-8(A1)  // _PCI
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
#endif /* COLDIRE */
#endif /* PATCH_NVDI */
#ifdef COLDFIRE
	moveq #0,D0
#endif
	move.w (A0),D0           // function
#ifdef COLDFIRE
	cmp.l #2,D0              // Physbase
#else
	cmp.w #2,D0              // Physbase
#endif
	bne.s .x9
	jsr _physbase
	rte	
.x9:
#ifdef COLDFIRE
	cmp.l #4,D0              // Getrez
#else
	cmp.w #4,D0              // Getrez
#endif
	bne.s .x26
	jsr _getrez
	rte
.x26:
#ifdef COLDFIRE
	cmp.l #5,D0              // Setscreen
#else
	cmp.w #5,D0              // Setscreen
#endif
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
#ifdef COLDFIRE
#ifdef USE_RTC
#ifndef MCF5445X
#ifndef MCF547X
#ifdef NETWORK
#ifdef LWIP
	move.l MCF_SIU_JTAGID,D1 // check the processor
	and.l #MCF_SIU_JTAGID_PROCESSOR,D1
	cmp.l #MCF_SIU_JTAGID_MCF5485,D1
             bne.s .x24               // <> M5485EVB
	cmp.l #22,D0             // Settime
	bne.s .x23
	move.l 2(A0),-(SP)
	jsr _settime
	addq.l #4,SP
	bra .x1                  // TOS routine
.x23:
	cmp.l #23,D0             // Gettime
	bne.s .x24
	jsr _gettime
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug8(PC),A0
	jsr display_string
	move.l (SP)+,A0
	move.w 2(A0),D0
	jsr hex_long
	moveq #13,D0
	jsr display_char
	moveq #10,D0
	jsr display_char
	move.l (SP)+,D0
#endif
	tst.l D0
	beq .x1                  // TOS routine
	rte
.x24:
#endif /* LWIP */
#endif /* NETWORK */
#endif /* MCF547X */
#endif /* MCF5445X */
#endif /* RTC */
	cmp.l #64,D0             // Blitmode
#else
	cmp.w #64,D0             // Blitmode
#endif
	bne.s .x4
	moveq #0,D0              // no blitter  
	rte
.x4:
#ifdef COLDFIRE
	cmp.l #88,D0             // Vsetmode
#else
	cmp.w #88,D0             // Vsetmode
#endif
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
#ifdef COLDFIRE
	cmp.l #89,D0             // Mon_type
#else
	cmp.w #89,D0             // Mon_type
#endif
	bne.s .x6
	jsr _montype
	rte
.x6:
#ifdef COLDFIRE
	cmp.l #91,D0             // Vgetsize
#else
	cmp.w #91,D0             // Vgetsize
#endif
	bne.s .x7
	move.w 2(A0),D0          // modecode
	ext.l D0
	move.l D0,-(SP)
	jsr _vgetsize
	addq.l #4,SP
	rte
.x7:
#ifdef COLDFIRE
	cmp.l #93,D0             // Vsetrgb
#else
	cmp.w #93,D0             // Vsetrgb
#endif
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
#ifdef COLDFIRE
	cmp.l #94,D0             // Vgetrgb
#else
	cmp.w #94,D0             // Vgetrgb
#endif
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
#ifdef COLDFIRE
	cmp.l #95,D0             // ValidMode (undocumented, used by AES before v_opnwk or set_video dialog box)
#else
	cmp.w #95,D0             // ValidMode (undocumented, used by AES before v_opnwk or set_video dialog box)
#endif
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
#ifdef COLDFIRE
#ifdef NETWORK
#ifndef MCF5445X
#ifdef SOUND_AC97
	tst.l _flag_snd_init
	beq .x15
	move.w SR,D1
	and.l #0x700,D1
	cmp.l #0x700,D1
	beq .x15                 // called under interrupts ???
	cmp.l #26,D0             // Jdisint
	bne.s .x20
	move.w 2(A0),D0          // num
	bsr jdisint
             bne .x15
             rte
.x20:
	cmp.l #27,D0             // Jenabint
	bne.s .x21
	move.w 2(A0),D0          // num
	bsr jenabint
             bne .x15
             rte
.x21:
	cmp.l #31,D0             // Xbtimer
	bne.s .x22
	move.w 2(A0),D0          // timer
	move.w 4(A0),D1          // control
	move.w 6(A0),D2          // data
	move.l 8(A0),A0          // vector
	bsr xbtimer
	bne .x15
	rte	
.x22:	
	cmp.l #141,D0
	bhi .x15
	cmp.l #128,D0
	bcs .x15
	sub.l #128,D0
	move.w tab_snd_bios(PC,D0.l*2),D0
	bmi .x15                // original TOS XBIOS
	jsr tab_snd_bios(PC,D0.l)
	rte
tab_snd_bios:
	dc.w locksnd-tab_snd_bios // 128
	dc.w unlocksnd-tab_snd_bios // 129
	dc.w soundcmd-tab_snd_bios // 130
	dc.w setbuffer-tab_snd_bios // 131
	dc.w setmode-tab_snd_bios // 132
	dc.w settracks-tab_snd_bios // 133
	dc.w setmontracks-tab_snd_bios // 134
	dc.w setinterrupt-tab_snd_bios // 135
	dc.w buffoper-tab_snd_bios // 136
	dc.w -1 // 137
	dc.w gpio-tab_snd_bios // 138
	dc.w devconnect-tab_snd_bios // 139
	dc.w sndstatus-tab_snd_bios // 140
	dc.w buffptr-tab_snd_bios // 141

jdisint:

	ext.l D0
	cmp.l #13,D0 // timer A
	bne.s .x16
	clr.l _timer_a_enabled
	moveq #0,D0
	rts
.x16:
	cmp.l #15,D0 // IO7
	bne.s .x17
	clr.l _io7_enabled
	moveq #0,D0
	rts
.x17:
	moveq #1,D0
	rts

jenabint:

	ext.l D0
	cmp.l #13,D0 // timer A
	bne.s .x18
	moveq #1,D0
	move.l D0,_timer_a_enabled
	moveq #0,D0
	rts
.x18:
	cmp.l #15,D0 // IO7
	bne.s .x17
	moveq #1,D0
	move.l D0,_io7_enabled
	moveq #0,D0
	rts
 
xbtimer:

	ext.l D0
	bne.s .x17 // <> timer A
	ext.l D1
	bne.s .x19 // <> stop
	clr.l _count_timer_a
	clr.l _preload_timer_a
	clr.l 0x134
	moveq #0,D0
	rts
.x19:
	cmp.l #8,D1
	bne.s .x17 // <> event count mode
	and.l #0xFF,D2
	move.l D2,_count_timer_a
	move.l D2,_preload_timer_a
	move.l A0,0x134 // vector
	moveq #0,D0
	rts

locksnd:

	jmp _locksnd

unlocksnd:

	jmp _unlocksnd

soundcmd:

	moveq #0,D0
	move.w 4(A0),D0
	move.l D0,-(SP) // data
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // mode
	jsr _soundcmd
	addq.l #8,SP
	rts

setbuffer:

	move.l 8(A0),-(SP) // endaddr
	move.l 4(A0),-(SP) // begaddr
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // reg
	jsr _setbuffer
	lea 12(SP),SP
	rts

setmode:

	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // mode
	jsr _setmode
	addq.l #4,SP
	rts

settracks:

	move.w 4(A0),D0
	ext.l D0
	move.l D0,-(SP) // rectracks
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // playtracks
	jsr _settracks
	addq.l #8,SP
	rts

setmontracks:

	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // track
	jsr _setmontracks
	addq.l #4,SP
	rts

setinterrupt:

	move.l 6(A0),D0
	move.l D0,-(SP) // callback
	move.w 4(A0),D0
	ext.l D0
	move.l D0,-(SP) // cause
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // src
	jsr _setinterrupt
	lea 12(SP),SP
	rts

buffoper:

	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // mode
	jsr _buffoper
	addq.l #4,SP
	rts

gpio:

	move.w 4(A0),D0
	ext.l D0
	move.l D0,-(SP) // data
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // mode
	jsr _gpio
	addq.l #8,SP
	rts

devconnect:

	move.w 10(A0),D0
	ext.l D0
	move.l D0,-(SP) // protocol
	move.w 8(A0),D0
	ext.l D0
	move.l D0,-(SP) // prescale
	move.w 6(A0),D0
	ext.l D0
	move.l D0,-(SP) // srcclk
	move.w 4(A0),D0
	ext.l D0
	move.l D0,-(SP) // dest
	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // src
	jsr _devconnect
	lea 20(SP),SP
	rts

sndstatus:

	move.w 2(A0),D0
	ext.l D0
	move.l D0,-(SP) // mode
	jsr _sndstatus
	addq.l #4,SP
	rts

buffptr:
	move.l 2(A0),-(SP) // pointer
	jsr _buffptr
	addq.l #4,SP
	rts
 
.x15:
#endif /* SOUND_AC97 */
#endif /* MCF5445X */
#endif /* NETWORK */
	cmp.l #0xc60e,D0         // ct60_vmalloc
	beq.s .x12
	cmp.l #0xc6e,D0          // bis
#else /* !COLDFIRE */
	cmp.w #0xc60e,D0         // ct60_vmalloc
	beq.s .x12
	cmp.w #0xc6e,D0          // bis
#endif /* COLDFIRE */
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
#ifdef COLDFIRE
#ifdef MCF5445X
#undef VIDIX /* because MCF5445X has no FPU */
#else /* MCF548X has FPU */
#define VIDIX
	cmp.l #420,D0
	bhi .x1
	cmp.l #400,D0            // VIDIX
	bcs .x1
	sub.l #400,D0
	move.w tab_vidix_bios(PC,D0.l*2),D0
	bmi .x1                // original TOS XBIOS
	jsr tab_vidix_bios(PC,D0.l)
	rte
#endif /* MCF5445X */
#else /* ATARI */
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
#endif /* COLDFIRE */
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
#ifndef COLDFIRE
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
#endif /* COLDIRE */
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

#ifdef NETWORK
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
#endif /* NETWORK */

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
#ifdef COLDFIRE
	.chip 68060
	cpusha BC
	.chip 5200
#else
	cpusha BC
#endif
	move.l D3,A1
	move.l (A1),D0
	move.l D0,(A0)+          // old vector
	move.l A0,(A1)           // JMP, new vector
.error_xbra:
	tst.l D0
	movem.l (SP),D1-D3/A0-A3
	lea 28(SP),SP
	rts

#if defined(CONFIG_USB_UHCI) || defined(CONFIG_USB_OHCI) || defined(CONFIG_USB_EHCI)	
#ifdef CONFIG_USB_STORAGE

_install_usb_stor:

	lea -32(SP),SP
	movem.l D1-D4/A0-A3,(SP)
	move.l 36(SP),D0         // dev_num
	cmp.l #PUN_DEV,D0
	bhi .no_pinfo            // error
	move.l 40(SP),D2         // part_type
	move.l D2,D1
	and.l #0xFFFFFF,D1       // ID
	// GEMDOS
	cmp.l #0x47454D,D1       // GEM up to 16M
	beq.s .partition_ok
	cmp.l #0x42474D,D1       // BGM over 16M
	beq.s .partition_ok
	cmp.l #0x524157,D1       // RAW
	beq.s .partition_ok
	// DOS 1:FAT12, 0xB/0xC:FAT32
	cmp.l #0x4,D2            // FAT16 up to 32M
	beq.s .partition_ok
	cmp.l #0x6,D2            // FAT16 over 32M
	beq.s .partition_ok
	cmp.l #0xE,D2            // WIN95 FAT16
	bne .invalid_partition_type
.partition_ok:
	move.l pun_ptr,D0
	bne.s .pinfo_ok
	move.w #3,-(SP)          // TT ram if possible
	move.l #pinfo_size,-(SP)
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	move.l D0,pun_ptr
	beq.s .no_pinfo
	move.l D0,A3
	clr.w pinfo_puns(A3)
	move.w #0x0300,D0
	move.w D0,pinfo_vernum(A3)
	move.w #0x4000,D0
	move.w D0,pinfo_maxsiz(A3)
	lea pinfo_pun(A3),A0
	moveq #-1,D0
	move.w D0,(A0)+          // drives A/B
	move.l D0,(A0)+
	move.l D0,(A0)+
	move.l D0,(A0)+
	move.w D0,(A0)
	lea pinfo_pstart(A3),A0
	lea pinfo_size(A3),A1
.clrpun:
		clr.w -(A1)
	cmp.l A0,A1
	bgt.s .clrpun
	move.l A3,D0             // pun_ptr
.pinfo_ok:
	move.l D0,A3             // pun_ptr
	moveq #2,D4              // drive C
	move.l _drvbits,D0
.search_empty_drive_usb:
		btst D4,D0
		beq.s .drive_not_exist_usb
		addq.l #1,D4
	cmp.l #MAX_LOGICAL_DRIVE,D4
	bcs.s .search_empty_drive_usb
	bra .drive_full_usb      // all drives already used
.no_pinfo:
	moveq #0,D0              // not installed
	bra .end_usb_disk
.drive_not_exist_usb:
	move.w pinfo_puns(A3),D0
	addq.l #1,D0
	move.w D0,pinfo_puns(A3)
	moveq #0,D0
	bset #7,D0               // changed
	lea pinfo_flags(A3),A0
	move.l D0,(A0,D4.l*4)    // B15:swap, B7:change, B0:bootable
	lea pinfo_psize(A3),A0
	move.l 48(SP),D3         // part_size
	move.l 44(SP),D1         // part_offset
	move.l 40(SP),D2         // part_type
	move.l 36(SP),D0         // dev_num
	move.l D2,pinfo_ptype(A3,D4.l*4)
	move.l D0,D2
	or.l #PUN_USB,D2
	move.b D2,pinfo_pun(A3,D4.l)
	move.l D3,(A0,D4.l*4)    // size
	move.l D1,pinfo_pstart(A3,D4.l*4)	
	move.l _dskbufp,A0 
	move.l A0,-(SP)          // buffer
	move.l #1,-(SP)          // blkcnt	
	move.l D1,-(SP)          // blknr
	move.l D0,-(SP)          // devnum
	jsr _usb_stor_read
	lea 16(SP),SP
	tst.l D0
	beq .end_usb_disk        // read error
	tst.l _usb_1st_disk_drive
	bne .usb_1st_drive_ok    // hdv vectors installed
	move.l D4,_usb_1st_disk_drive
	move.w SR,D0
	move.w D0,-(SP)
	or.l #0x700,D0           // mask interrupts
	move.w D0,SR
	move.l #0x5F555342,D1    // _USB
	lea det_hdv_bpb_usb(PC),A0
	move.w #hdv_bpb,D0
	bsr install_xbra
	move.l D0,old_hdv_bpb_usb
	lea det_hdv_rw_usb(PC),A0
	move.w #hdv_rw,D0
	bsr install_xbra
	move.l D0,old_hdv_rw_usb
	lea det_hdv_mediach_usb(PC),A0
	move.w #hdv_mediach,D0
	bsr install_xbra
	move.l D0,old_hdv_mediach_usb
	move.l cookie,D0
	beq.s .no_cookie_jar
	move.l D0,A0
	move.l #0x58484449,D1    // XHDI
.find_cookie_jar:
		tst.l (A0)
		beq.s .cookie_slot_free
		cmp.l (A0),D1
		beq.s .cookie_found
		addq.l #8,A0
	bra.s .find_cookie_jar
.cookie_found:
	move.l 4(A0),D0
	move.l D0,old_xhdi
	lea xhdi(PC),A1
	move.l A1,4(A0)
	clr.l -(SP)              // XHGetVersion
	move.l D0,A0
	jsr (A0)
	addq.l #4,SP
	move.l D0,old_xhdi_version
	bra.s .no_cookie_jar
.cookie_slot_free:
	move.l 4(A0),12(A0)      // copy size
	move.l D1,(A0)+ // XHDI
	lea xhdi(PC),A1
	move.l A1,(A0)+
	clr.l (A0)
	clr.l old_xhdi
	move.l #0x120,D0         //  protocol version
	move.l D0,old_xhdi_version
.no_cookie_jar:
	move.w (SP)+,D0
	move.w D0,SR
.usb_1st_drive_ok:
	move.l _dskbufp,A0       // boot sector
	lea pinfo_bpb(A3),A1
	move.l D4,D2             // logical drive
	asl.l #5,D2              // * 32
	add.l D2,A1
	moveq #0,D2
	move.b 0xC(A0),D2
	asl.l #8,D2
	move.b 0xB(A0),D2        // BPS
	move.w D2,(A1)           // sector size
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
#ifdef COLDFIRE
	.chip 68060
#endif
	divu D2,D0               // / sector size
#ifdef COLDFIRE
	.chip 5200
#endif
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
	bne.s .nsects_ok_usb
	lea pinfo_psize(A3),A2
	move.l (A2,D4.l*4),D2    // partition size in sectors
	sub.l D0,D2              // - 1st data sector
.nsects_ok_usb:
#ifdef COLDFIRE
	.chip 68060
#endif
	divu D1,D2
#ifdef COLDFIRE
	.chip 5200
#endif
	move.w D2,14(A1)         // total clusters
	moveq #1,D0
	move.w D0,16(A1)         // FAT 16
	clr.w 18(A1)
	clr.l 20(A1)
	clr.l 24(A1)
	clr.l 28(A1)
	move.l _drvbits,D0
	bset D4,D0
	move.l D0,_drvbits
	moveq #2,D0              // drive C
	cmp.l D4,D0
	bne.s .no_set_drive_usb
	move.w D0,_bootdev
	move.w D0,-(SP)
	move.w #0xE,-(SP)        // Dsetdrv
	trap #1
	addq.l #4,SP
.no_set_drive_usb:
	move.l 36(SP),D0         // devnum        
	movem.l 52(SP),A1/A2/A3  // vendor / revision / product
	lea product_name,A0      // save product name pointer for XHDI
	move.l A3,(A0,D0.l*4)
	bsr display_drive_usb
	pea message2b(PC)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	moveq #0x41,D0           // A
	add.l D4,D0
	move.w D0,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	pea crlf(PC)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	move.l D4,D0             // OK
	bra.s .end_usb_disk
.invalid_partition_type:
	pea error4(PC)
	bra.s .display_error_usb
.drive_full_usb:
	pea error2(PC)
.display_error_usb:
	move.l 36+4(SP),D0       // devnum      
	movem.l 52+4(SP),A1/A2/A3// vendor / revision / product
	bsr display_drive_usb
	move.w #0x2C,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	move.w #0x20,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	moveq #0,D0              // not installed
.end_usb_disk:
	movem.l (SP),D1-D4/A0-A3
	lea 32(SP),SP
.return:
	rts

display_drive_usb:

	move.l A1,-(SP)
	moveq #0x30,D1
	add.l D1,D0	            // dev_num
	move.w D0,-(SP)         
	lea blue(PC),A0
	bsr text_color
	pea message2(PC)         // USB-disk installed
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	move.w #0x2E,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	move.w #0x30,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	lea black(PC),A0
	bsr text_color
	move.w #0x20,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP    
	move.w #0x20,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	move.l A2,-(SP)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP             
	move.w #0x20,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	move.l A3,-(SP)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	rts

det_hdv_bpb_usb:

	move.l A0,-(SP)
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 4+4(SP),D0        // drive
	cmp.l _usb_1st_disk_drive,D0
	bcs.s .dhbu2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .dhbu2
	tst.b pinfo_pun(A0,D0.l)
	bpl.s .dhbu1
.dhbu2:
	move.l (SP)+,A0
	moveq #0,D0
	move.l old_hdv_bpb_usb,-(SP)
	rts
.dhbu1:
	move.l D1,-(SP)
	move.l pinfo_ptype(A0,D0.l*4),D1
	and.l #0xFFFFFF,D1
	cmp.l #0x524157,D1       // RAW
	bne.s .dhbu3
	move.L (SP)+,D1
	move.l (SP)+,A0
	moveq #0,D0
	rts	
.dhbu3:
	lea pinfo_bpb(A0),A0
	asl.l #5,D0              // * 32
	add.l A0,D0
#ifdef DEBUG
	move.l D0,-(SP)
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.l (SP),D0
	jsr hex_long
	moveq #0x20,D0
	jsr display_char
	lea debug4(PC),A0
	jsr display_string
	move.l (SP)+,D0
#endif
	move.l (SP)+,D1
	move.l (SP)+,A0
	rts

det_hdv_rw_usb:

	lea -28(SP),SP
	movem.l D1-D4/A0-A2,(SP)
#ifdef DEBUG
	lea debug3(PC),A0
	jsr display_string	
	move.w 4+28(SP),D0       // rwflag
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.l 6+28(SP),D0       // buffer
	jsr hex_long
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 10+28(SP),D0      // num sectors
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 12+28(SP),D0      // logical sector
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 14+28(SP),D0      // drive
	jsr hex_word
	moveq #13,D0
	jsr display_char
	moveq #10,D0
	jsr display_char
#endif
	btst #3,5+28(SP)         // rwflag
	bne.s .dhru8             // physical
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 14+28(SP),D0      // drive
	cmp.l _usb_1st_disk_drive,D0
	bcs.s .dhru8
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .dhru8
	moveq #0,D4
	move.b pinfo_pun(A0,D0.l),D4
	bpl.s .dhru1             // valid
.dhru8:
	movem.l (SP),D1-D4/A0-A2
	lea 28(SP),SP
	moveq #0,D0
	move.l old_hdv_rw_usb,-(SP)
	rts
.dhru1:
	move.l D4,D2
	and.l #PUN_USB,D2
	beq.s .dhru8             // not USB
	and.l #PUN_DEV,D4
	moveq #0,D2
	move.w 12+28(SP),D2      // logical sector
	bpl.s .dhru6
	move.l 16+28(SP),D2      // logical sector	
.dhru6:
	tst.l D2
	bmi .dhru2               // negative logical sector
	move.l 6+28(SP),D1       // buffer
	beq .dhru4               // no buffer
	move.l pinfo_pstart(A0,D0.l*4),D3
	lea pinfo_bpb(A0),A0
	asl.l #5,D0              // * 32
	add.l D0,A0
	move.w 14(A0),D0         // total clusters
	mulu.w 2(A0),D0          // cluster size in sectors
	cmp.l D0,D2              // logical sector to hight
	bcc .dhru2
	moveq #0,D0
	move.w (A0),D0           // sector size
	lsr.l #8,D0
	lsr.l #1,D0              // / 512
	move.l D1,A0             // buffer
	move.w 10+28(SP),D1      // num sectors
	beq .dhru4               // no sectors
	mulu D0,D1
	mulu.l D0,D2
	add.l D3,D2              // start sector
	move.l D1,D3             // count
	btst #0,5+28(SP)         // rwflag
	beq.s .dhru7             // read
	// write
	tst.l D2                 // logical sector
	beq.s .dhru2             // root sector
	move.l A0,-(SP)          // buffer
	move.l D3,-(SP)          // blkcnt	
	move.l D2,-(SP)          // blknr
	move.l D4,-(SP)          // devnum
	jsr _usb_stor_write
	bra.s .dhru5
.dhru2:
	moveq #-1,D0             // error
	bra.s .dhru3
.dhru4:
	moveq #0,D0              // OK
	bra.s .dhru3
.dhru7:
	move.l A0,-(SP)          // buffer
	move.l D3,-(SP)          // blkcnt	
	move.l D2,-(SP)          // blknr
	move.l D4,-(SP)          // devnum
	jsr _usb_stor_read
.dhru5:
	lea 16(SP),SP
	tst.l D0
	seq.b D0
	ext.w D0
	ext.l D0
	bclr #0,D0               // OK or device not responding -2
.dhru3:
	movem.l (SP),D1-D4/A0-A2
	lea 28(SP),SP
 	rts

det_hdv_mediach_usb:

	move.l A0,-(SP)
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 4+4(SP),D0        // drive
	cmp.l _usb_1st_disk_drive,D0
	bcs.s .dhmu2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .dhmu2
	tst.b pinfo_pun(A0,D0.l)
	bpl.s .dhmu1
.dhmu2:
	move.l (SP)+,A0
	moveq #0,D0
	move.l old_hdv_mediach_usb,-(SP)
	rts
.dhmu1:
#if 0 // #ifdef DEBUG
	move.l A0,-(SP)
	lea debug5(PC),A0
	jsr display_string
	move.l (SP)+,A0
#endif
	lea pinfo_flags(A0),A0
	add.l D0,A0
	add.l D0,A0
	bclr #7,1(A0)
	sne.b D0
	and.l #2,D0
	move.l (SP)+,A0
	rts

	// XHDI
	
	dc.l 0x27011992
	
xhdi:
	
	link A6,#0
#ifdef COLDFIRE
	lea -52(SP),SP
	movem.l D1-A5,(SP)
#else
	movem.l D1-A5,-(SP)
#endif
	moveq #0,D1
	move.w 8(A6),D1
	moveq #-32,D0            // invalid function
	cmp.l #18,d1
	bcc.s .bad_xhdi
	move.w SR,D0             // supervisor only
	moveq #-1,d0             // error
	move.w tab_xhdi(PC,D1.l*2),D1
	jsr tab_xhdi(PC,D1.W)
.bad_xhdi:
#ifdef COLDFIRE
	movem.l (SP),D1-A5
	lea 52(SP),SP
#else
	movem.l (SP)+,D1-A5
#endif
	unlk A6
	rts
tab_xhdi:
	dc.w XHGetVersion-tab_xhdi    // 0
	dc.w XHInqTarget-tab_xhdi     // 1
	dc.w XHReserve-tab_xhdi       // 2
	dc.w XHLock-tab_xhdi          // 3
	dc.w XHStop-tab_xhdi          // 4
	dc.w XHEject-tab_xhdi         // 5
	dc.w XHDrvMap-tab_xhdi        // 6
	dc.w XHInqDev-tab_xhdi        // 7
	dc.w XHInqDriver-tab_xhdi     // 8
	dc.w XHNewCookie-tab_xhdi     // 9
	dc.w XHReadWrite-tab_xhdi     // 10
	dc.w XHInqTarget2-tab_xhdi    // 11
	dc.w XHInqDev2-tab_xhdi       // 12
	dc.w XHDriverSpecial-tab_xhdi // 13
	dc.w XHGetCapacity-tab_xhdi   // 14
	dc.w XHMediumChanged-tab_xhdi // 15
	dc.w XHMiNTInfo-tab_xhdi      // 16
	dc.w XHDOSLimits-tab_xhdi     // 17
	
XHGetVersion:

	move.l #0x120,D0         //  protocol version
	move.l old_xhdi_version,D1
	cmp.l D1,D0
	bcs.s .xv1
	move.l D1,D0             // minimum version
.xv1:	
	rts
	
XHInqTarget:

	moveq #32,D2             // stringlen
	bra.s .xi1
	
XHInqTarget2:

#ifdef DEBUG
	lea debug133(PC),A0
	jsr display_string
#endif
	move.l 26(A6),D2         // stringlen
.xi1:
	tst.w 12(A6)             // minor
	bne.s .xi2
	moveq #0,D0
	move.w 10(A6),D0         // major
	cmp.l #PUN_USB,D0
	bcs.s .xi2
	cmp.l #PUN_USB+PUN_DEV,D0
	bls.s .xi3
.xi2:
	tst.l old_xhdi
	beq.s .xi7
	moveq #-15,D0            // unknown device
	rts
.xi7:
	move.l old_xhdi,-(SP)
	rts
.xi3:
	lea 14(A6),A0            // blocksize
	move.l #512,(A0)
	lea 18(A6),A0            // device_flags
	clr.l (A0)
	move.l 22(A6),D1         // product_name
	beq.s .xi3
	move.l D1,A0
	clr.b (A0)
	lea product_name,A1
	move.l (A1,D0.l*4),D0
	beq.s .xi6               // no pointer
	move.l D0,A1
.xi5:
		move.b (A1)+,(A0)+
		beq.s .xi4
	subq.l #1,D2
	ble.s .xi4
.xi4:
	clr.b -1(A0)
.xi6:
	moveq #0,D0
	rts

XHReserve:
XHLock:
XHStop:
XHEject:

	tst.l old_xhdi
	beq.s .xnu1
	moveq #0,D0
	rts
.xnu1:
	move.l old_xhdi,-(SP)
	rts
	
XHDrvMap:

	move.l _drvbits,D0
	rts

XHInqDev:

#ifdef DEBUG
	lea debug134(PC),A0
	jsr display_string
#endif
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 10(A6),D0         // bios_device
	cmp.l _usb_1st_disk_drive,D0
	bcs.s .xd2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .xd2
	moveq #0,D1
	move.b pinfo_pun(A0,D0.l),D1
	bpl.s .xd1
.xd2:	
	tst.l old_xhdi
	beq.s .xd3
	moveq #-46,D0            // invalid drive number
	rts
.xd3:
	move.l old_xhdi,-(SP)
	rts
.xd1:	
	move.l D1,D2
	and.l #PUN_USB,D2
	beq.s .xd2
	tst.l 12(A6)
	beq.s .xd4
	move.l 12(A6),A1         // major
	move.w D1,(A1)
.xd4:
	tst.l 16(A6)
	beq.s .xd5
	move.l 16(A6),A1         // minor
	clr.w (A1)
.xd5:
	tst.l 20(A6)
	beq.s .xd6
	move.l pinfo_pstart(A0,D0.l*4),D1
	move.l 20(A6),A1         // start_sector
	move.l D1,(A1)
.xd6:
	lea pinfo_bpb(A0),A0
	asl.l #5,D0              // * 32
	add.l A0,D0
	tst.l 24(A6)
	beq.s .xd7
	move.l 24(A6),A1         // bpb
	move.l D0,(A1)
.xd7:
	moveq #0,D0
	rts

XHInqDriver:

#ifdef DEBUG
	lea debug135(PC),A0
	jsr display_string
#endif
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 10(A6),D0         // bios_device
	cmp.l _usb_1st_disk_drive,D0
	bcs.s .xdr2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .xdr2
	moveq #0,D1
	move.b pinfo_pun(A0,D0.l),D1
	bpl.s .xdr1
.xdr2:	
	tst.l old_xhdi
	beq.s .xdr8
	moveq #-46,D0            // invalid drive number
	rts
.xdr8:
	move.l old_xhdi,-(SP)
	rts
.xdr1:
	move.l D1,D0
	and.l #PUN_USB,D0
	beq.s .xdr2
	move.l 12(A6),D0         // name, 17 characters
	beq.s .xdr3
	move.l D0,A1
	lea message1(PC),A0
	moveq #17,D1
.xdr6:
		move.b (A0)+,D0
		beq.s .xdr7
		move.b D0,(A1)+
	subq.l #1,D1
	bpl.s .xdr6
.xdr7:
	clr.b (A1)
.xdr3:
	move.l 16(A6),D0         // version, 7 characters
	beq.s .xdr4
	move.l D0,A1
	move.b #0x34,(A1)+       // ??? TOS 4.04
	move.b #0x2E,(A1)+
	move.b #0x30,(A1)+
	move.b #0x34,(A1)+
	clr.b (A1)
.xdr4:
	move.l 20(A6),D0         // company, 17 characters
	beq.s .xdr5
	move.l D0,A1
	clr.b (A1)
.xdr5:
	move.l 24(A6),A1         // ahdi_version
	move.w pinfo_vernum(A0),(A1)
	move.l 28(A6),A1         // maxIPL
	moveq #5,D0
	move.w D0,(A1)	
	moveq #0,D0
	rts

XHReadWrite:                          // read / write physical sectors

	tst.w 12(A6)             // minor
	bne.s .xr4
	moveq #0,D4
	move.w 10(A6),D4         // major
	cmp.l #PUN_USB,D4
	bcs.s .xr4
	cmp.l #PUN_USB+PUN_DEV,D4
	bls.s .xr1
.xr4:
	tst.l old_xhdi
	beq.s .xr6
	moveq #-15,D0            // unknown device
	rts
.xr6:
	move.l old_xhdi,-(SP)
	rts
.xr1:
#ifdef DEBUG
	lea debug132(PC),A0
	jsr display_string
	move.w 14(A6),D0         // rwflag
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.l 24(A6),D0         // buffer
	jsr hex_long
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 20(A6),D0         // num sectors
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.l 16(A6),D0         // logical sector
	jsr hex_long
	moveq #13,D0
	jsr display_char
	moveq #10,D0
	jsr display_char	
#endif
	move.l 24(A6),A0         // buffer
	moveq #0,D3
	move.w 20(A6),D3         // count
	beq .xr2                 // no sectors
             move.l 16(A6),D2         // start sector
	btst #0,15(A6)           // rwflag
	beq.s .xr7               // read
	// write
	move.l A0,-(SP)          // buffer
	move.l D3,-(SP)          // blkcnt	
	move.l D2,-(SP)          // blknr
	move.l D4,D0             // major
	and.l #PUN_DEV,D0
	move.l D0,-(SP)          // devnum
	jsr _usb_stor_write
	bra.s .xr5
.xr2:
	moveq #-1,D0             // error
	bra.s .xr3
.xr7:
	move.l A0,-(SP)          // buffer
	move.l D3,-(SP)          // blkcnt	
	move.l D2,-(SP)          // blknr
	move.l D4,D0             // major
	and.l #PUN_DEV,D0
	move.l D0,-(SP)          // devnum
	jsr _usb_stor_read
.xr5:
	lea 16(SP),SP
	tst.l D0
	seq.b D0
	ext.w D0
	ext.l D0
	bclr #0,D0               // OK or device not responding -2
.xr3:
 	rts

XHInqDev2:

#ifdef DEBUG
	lea debug136(PC),A0
	bsr display_string
#endif
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 10(A6),D0         // bios_device
	cmp.l _usb_1st_disk_drive,D0
	bcs.s .xdd2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .xdd2
	moveq #0,D1
	move.b pinfo_pun(A0,D0.l),D1
	bpl.s .xdd1
.xdd2:	
	tst.l old_xhdi
	beq.s .xdd4
	moveq #-46,D0            // invalid drive number
	rts
.xdd4:
	move.l old_xhdi,-(SP)
	rts
.xdd1:	
	move.l D1,D2
	and.l #PUN_USB,D2
	beq.s .xdd2
	tst.l 12(A6)
	beq.s .xdd5
	move.l 12(A6),A1         // major
	move.w D1,(A1)
.xdd5:
	tst.l 16(A6)
	beq.s .xdd6
	move.l 16(A6),A1         // minor
	clr.w (A1)
.xdd6:
	tst.l 20(A6)
	beq.s .xdd7
	move.l pinfo_pstart(A0,D0.l*4),D1
	move.l 20(A6),A1         // start_sector
	move.l D1,(A1)
.xdd7:
	tst.l 24(A6)
	beq.s .xdd8
	lea pinfo_bpb(A0),A2
	move.l D0,D1
	asl.l #5,D1              // * 32
	add.l A2,D1
	move.l 24(A6),A1         // bpb
	move.l D1,(A1)
.xdd8:
	tst.l 28(A6)
	beq.s .xdd9
	move.l 28(A6),A1         // blocks
	lea pinfo_psize(A0),A2
	move.l (A2,D0.l*4),(A1)
.xdd9:
	tst.l 32(A6)
	beq.s .xdd10
	move.l 32(A6),A1         // partid
	move.b pinfo_ptype+1(A2,D0.l*4),(A1)
	move.b pinfo_ptype+2(A2,D0.l*4),D1
	bne.s .xdd3
	moveq #0x44,D1           // D
.xdd3:
	move.b D1,1(A1)
	move.b pinfo_ptype+3(A2,D0.l*4),(A1)
.xdd10:
	moveq #0,D0
	rts
 
XHDriverSpecial:
XHGetCapacity:
XHMediumChanged:
XHMiNTInfo:
XHNewCookie:

	tst.l old_xhdi
	beq.s .xn1
	moveq #-32,D0            //  invalid function number 
	rts
.xn1:
	move.l old_xhdi,-(SP)
	rts

XHDOSLimits:

	tst.l old_xhdi
	bne.s .xn1
#ifdef DEBUG
	lea debug137(PC),A0
	jsr display_string
#endif
	moveq #0,D0
	move.w 10(A6),D0         // which
	cmp.l #XH_DL_SECSIZ,D0   // maximal sector size (BIOS level)
	bne.s .xl1
	move.l #0x4000,D0
	rts	
.xl1:
	cmp.l #XH_DL_MINFAT,D0   // minimal number of FATs
	bne.s .xl2
	moveq #1,D0
	rts
.xl2:
	cmp.l #XH_DL_MAXFAT,D0   // maximal number of FATs
	bne.s .xl3
	moveq #2,D0
	rts
.xl3:
	cmp.l #XH_DL_MINSPC,D0   // sectors per cluster minimal
	bne.s .xl4
	moveq #2,D0
	rts
.xl4:
	cmp.l #XH_DL_MAXSPC,D0   // sectors per cluster maximal
	bne.s .xl5
#ifdef COLDFIRE
	moveq #64,D0             // for this Coldfire version of BDOS, else 2
#else
	moveq #2,D0
#endif
	rts
.xl5:
	cmp.l #XH_DL_CLUSTS,D0   // maximal number of clusters of a 16 bit FAT
	bne.s .xl6
	move.l #0x8000,D0
	rts	
.xl6:
	cmp.l #XH_DL_MAXSEC,D0   // maximal number of sectors
	bne.S .xl7
#ifdef COLDFIRE
	move.l #0x200000,D0      // for this Coldfire version of BDOS, else 0x10000
#else
	move.l #0x10000,D0
#endif
	rts
.xl7:
	cmp.l #XH_DL_DRIVES,D0   // maximal number of BIOS drives supported by the DOS
	bne.s .xl8
	moveq #16,D0
	rts
.xl8:
	moveq #-32,D0            // invalid function number 
	rts

#endif /* CONFIG_USB_STORAGE */
#endif /* CONFIG_USB_UHCI || CONFIG_USB_OHCI || CONFIG_USB_EHCI */

#ifdef NETWORK

_install_ram_disk:

	lea -20(SP),SP
	movem.l D1-D2/A0-A2,(SP)
	link A6,#-16
	moveq #2,D1              // drive C
	move.l _drvbits,D0
.search_empty_drive:
		btst D1,D0
		beq.s .drive_not_exist
		addq.l #1,D1
	cmp.l #MAX_LOGICAL_DRIVE,D1
	bcs.s .search_empty_drive
	bra .drive_full          // all drives already used
.drive_not_exist:
	move.l D1,ram_disk_drive
	moveq #2,D0
	move.l D0,_change_ram_disk
	clr.l _ext_write_protect_ram_disk
	moveq #0,D0
	move.w tab_bpb+12(PC),D0 // sectors offset
	addq.l #1,D0
	lsr.l #1,D0
	add.l #RAM_DISK_SIZE_KB,D0
	asl.l #8,D0              // * 1024
	asl.l #2,D0
	move.l D0,_size_ram_disk
	addq.l #4,D0
	move.w #3,-(SP)          // TT ram if possible
	move.l D0,-(SP)
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
.test_malloc_ok:
	tst.l D0
	beq .no_ram_disk
	addq.l #3,D0
	and.l #0xFFFFFFFC,D0     // 4 bytes alignment
	move.l D0,_address_ram_disk
	move.w SR,D0
	move.w D0,-(SP)
	or.l #0x700,D0           // mask interrupts
	move.w D0,SR
	move.l #0x5F43465F,D1    // _CF_
	lea det_hdv_bpb(PC),A0
	move.w #hdv_bpb,D0
	bsr install_xbra
	move.l D0,old_hdv_bpb
	lea det_hdv_rw(PC),A0
	move.w #hdv_rw,D0
	bsr install_xbra
	move.l D0,old_hdv_rw
	lea det_hdv_mediach(PC),A0
	move.w #hdv_mediach,D0
	bsr install_xbra
	move.l D0,old_hdv_mediach
	move.w (SP)+,D0
	move.w D0,SR
#ifdef RAM_DISK_FAT12
	moveq #0,D0
	move.w tab_bpb+12(PC),D0 // sectors offset
	asl.l #6,D0              // * 512 / 8
	subq.l #1,D0
#else
	move.l #((512*((RAM_DISK_SEC_FAT*2)+1+7))/8)-1,D0
#endif
	move.l _address_ram_disk,A0
.raz_fat:
		clr.l (A0)+
		clr.l (A0)+
	subq.l #1,D0
	bpl.s .raz_fat
	move.l _address_ram_disk,A0
	lea 8(A0),A0
	lea tab_boot(PC),A1
	moveq #5,D0
.init_boot_sector:
		move.l (A1)+,(A0)+
	subq.l #1,D0
	bpl.s .init_boot_sector
	moveq #0,D0
	move.w tab_bpb+12(PC),D0 // sectors offset
	add.l #RAM_DISK_SIZE_KB*2,D0 // number of sectors
	move.l _address_ram_disk,A0 // boot sector bytes 19-20
	moveq #0,D2
	move.b D0,D2
	move.l 16(A0),D1
	and.l #0xFFFFFF00,D1
	or.l D2,D1
	move.l D1,16(A0)
	move.w D0,D2
	swap D2
	and.l #0xFF000000,D2
	move.l 20(A0),D1
	and.l #0x00FFFFFF,D1
	or.l D2,D1
	move.l D1,20(A0)
	move.l _drvbits,D0
	move.l ram_disk_drive,D1
	bset D1,D0
	move.l D0,_drvbits
	lea -16(A6),A0           // name
	add.l #0x41,D1
	move.b D1,(A0)+
	move.b #0x3A,(A0)+       // :
	move.l #0x5C52414D,(A0)+ // \RAM
	move.l #0x2D444953,(A0)+ // -DIS
	move.w #0x4B00,(A0)      // K
	move.w #8,-(SP)
	pea -16(A6)              // name
	move.w #0x3C,-(SP)       // Fcreate
	trap #1
	addq.l #8,SP
	tst.w D0
	bmi .error_fcreate
	move.w D0,-(SP)	
	move.w #0x3E,-(SP)       // Fclose
	trap #1
	addq.l #4,SP	
	moveq #2,D0              // drive C
	cmp.l ram_disk_drive,D0
	bne.s .no_set_drive
	move.w D0,_bootdev
	move.w D0,-(SP)
	move.w #0xE,-(SP)        // Dsetdrv
	trap #1
	addq.l #4,SP
.no_set_drive:
	lea blue(PC),A0
	bsr text_color
	pea message(PC)          // Ram-disk installed
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	moveq #0x41,D0           // A
	add.l ram_disk_drive,D0
	move.w D0,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	pea crlf(PC)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	lea black(PC),A0
	bsr text_color
	move.l ram_disk_drive,D0 // OK
	bra.s .end_ram_disk
.error_fcreate:
	pea error3(PC)
	bra.s .display_error
.drive_full:
	pea error2(PC)
	bra.s .display_error
.no_ram_disk:
	pea error1(PC)
.display_error:
	pea error(PC)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	moveq #0,D0              // not installed
.end_ram_disk:
	unlk A6
	movem.l (SP),D1-D2/A0-A2
	lea 20(SP),SP
	rts

det_hdv_bpb:

 	moveq #0,D0
	move.w 4(SP),D0          // drive
	cmp.l ram_disk_drive,D0
	beq.s .dhb1
	move.l old_hdv_bpb,-(SP)
	rts
.dhb1:
	move.l A0,-(SP)
#ifdef DEBUG
	lea debug4(PC),A0
	jsr display_string	
#endif
	lea tab_bpb(PC),A0
	move.l A0,D0
	move.l (SP)+,A0
	rts
	
#ifdef RAM_DISK_FAT12

tab_bpb:
	dc.w 0x200               // sector size
	dc.w 2                   // cluster size in sectors
	dc.w 0x400               // cluster size in bytes
	dc.w 7                   // size directory in sectors
	dc.w RAM_DISK_SEC_FAT    // FAT size
	dc.w RAM_DISK_SEC_FAT+1  // 1st sector of FAT2
	dc.w (RAM_DISK_SEC_FAT*2)+7+1 // 1st data sector
	dc.w RAM_DISK_SIZE_KB    // total clusters
	dc.w 0                   // FAT 12
	dc.w 0
	dc.l 0,0,0
	
tab_boot:
	dc.b 0x16,0x10,0x64      // serial number
	dc.b 0,2                 // bytes/sector
	dc.b 2                   // sectors/cluster
	dc.b 1,0                 // reserved sectors
	dc.b 2                   // number of FATs
	dc.b 112,0               // number of directory entry
	dc.b 0,0                 // number of sectors
	dc.b 0
	dc.b RAM_DISK_SEC_FAT,0  // number of sectors/FAT
	dc.b 9,0                 // number of sectors/track
	dc.b 1,0                 // number of sides
	dc.b 0,0                 // number of hidden sectors
	dc.b 0,0                 // exec flag

#else

tab_bpb:
	dc.w 0x200               // sector size
	dc.w 2                   // cluster size in sectors
	dc.w 0x400               // cluster size in bytes
	dc.w 7                   // size directory in sectors
	dc.w RAM_DISK_SEC_FAT    // FAT size
	dc.w RAM_DISK_SEC_FAT+1  // 1st sector of FAT2
	dc.w (RAM_DISK_SEC_FAT*2)+7+1 // 1st data sector
	dc.w RAM_DISK_SIZE_KB    // total clusters
	dc.w 1                   // FAT 16
	dc.w 0
	dc.l 0,0,0
	
tab_boot:
	dc.b 0x16,0x10,0x64      // serial number
	dc.b 0,2                 // bytes/sector
	dc.b 2                   // sectors/cluster
	dc.b 1,0                 // reserved sectors
	dc.b 2                   // number of FATs
	dc.b 112,0               // number of directory entry
	dc.b 0,0                 // number of sectors
	dc.b 0
	dc.b RAM_DISK_SEC_FAT,0  // number of sectors/FAT
	dc.b 9,0                 // number of sectors/track
	dc.b 1,0                 // number of sides
	dc.b 0,0                 // number of hidden sectors
	dc.b 0,0                 // exec flag

#endif
	.align 2

det_hdv_rw:

 	moveq #0,D0
	move.w 14(SP),D0         // drive
	cmp.l ram_disk_drive,D0
	beq.s .dhr1
	move.l old_hdv_rw,-(SP)
	rts
.dhr1:
	lea -16(SP),SP
	movem.l D1-D2/A0-A1,(SP)
#ifdef DEBUG
	lea debug3(PC),A0
	jsr display_string	
	move.w 4+16(SP),D0       // rwflag
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.l 6+16(SP),D0       // buffer
	jsr hex_long
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 10+16(SP),D0      // num sectors
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 12+16(SP),D0      // logical sector
	jsr hex_word
	moveq #0x20,D0
	jsr display_char
	moveq #0x30,D0
	jsr display_char
	moveq #0x78,D0
	jsr display_char
	move.w 14+16(SP),D0      // drive
	jsr hex_word
	moveq #13,D0
	jsr display_char
	moveq #10,D0
	jsr display_char
#endif
	moveq #0,D0
	move.w 12+16(SP),D0      // logical sector
	bpl.s .dhr5
	move.l 16+16(SP),D0      // logical sector	
.dhr5:
	asl.l #8,D0
	add.l D0,D0              // * 512
	move.l 6+16(SP),D1       // buffer
	beq.s .dhr4
	move.l D1,A0
	moveq #0,D1
	move.w 10+16(SP),D1      // num sectors
	subq.l #1,D1
	bmi.s .dhr4
	move.l _address_ram_disk,A1
	add.l D0,A1
	btst #0,5+16(SP)         // rwflag
	beq.s .dhr2              // read
	move.l A0,D0
	move.l A1,A0
	move.l D0,A1
	tst.l _ext_write_protect_ram_disk
	beq.s .dhr2
	moveq #-13,D0            // write protect
	bra.s .dhr6
.dhr2:
#ifdef DEBUG
//		bsr dump
//		jsr wait_key
#endif
		moveq #15,D0 // 512 bytes transfer
.dhr3:
			move.l (A1)+,(A0)+
			move.l (A1)+,(A0)+
			move.l (A1)+,(A0)+
			move.l (A1)+,(A0)+
			move.l (A1)+,(A0)+
			move.l (A1)+,(A0)+
			move.l (A1)+,(A0)+
			move.l (A1)+,(A0)+  
		subq.l #1,D0
		bpl.s .dhr3
	subq.l #1,D1
	bpl.s .dhr2
.dhr4:
	moveq #0,D0
.dhr6:
	movem.l (SP),D1-D2/A0-A1
	lea 16(SP),SP
 	rts

det_hdv_mediach:

 	moveq #0,D0
	move.w 4(SP),D0          // drive
	cmp.l ram_disk_drive,D0
	beq.s .dhm1
	move.l old_hdv_mediach,-(SP)
	rts
.dhm1:
#if 0 // #ifdef DEBUG
	move.l A0,-(SP)
	lea debug5(PC),A0
	jsr display_string
	move.l (SP)+,A0
#endif
	move.l _change_ram_disk,D0
	clr.l _change_ram_disk
	rts
	
_alert_tos:
	
	lea -52(SP),SP
	movem.l D1-A5,(SP)
	move.l 56(SP),A0         // string
	pea.l (A0)
	move.w #1,-(SP)
	jsr 0xE22A68             // form_alert
	addq.l #6,SP
	movem.l (SP),D1-A5
	lea 52(SP),SP
	ext.l D0
	rts
	
#endif /* NETWORK */
	
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

#ifdef COLDFIRE
#ifdef NETWORK
#ifdef LWIP

#include "../include/fire.h"

	.chip 68060
	
_flush_dc:

 	move.w SR,D0
	or.l #0x700,D0           // mask interrupts
	move.w D0,SR
	lea 0,A1                 // cpushl pointer
.fdc1:
		cpushl DC,(A1)
		addq.l #1,A1
		cpushl DC,(A1)
		addq.l #1,A1
		cpushl DC,(A1)
		addq.l #1,A1
		cpushl DC,(A1)
		add.l #0x10-3,A1
	cmp.l #LAST_DCACHE_ADDR,A1
	bls.s .fdc1
	move.w D0,SR
	rts

_flush_caches:

	bsr _flush_dc

_flush_ic:

 	move.w SR,D0
	or.l #0x700,D0           // mask interrupts
	move.w D0,SR
	lea 0,A1                 // cpushl pointer
.fic1:
		cpushl IC,(A1)
		addq.l #1,A1
		cpushl IC,(A1)
		addq.l #1,A1
		cpushl IC,(A1)
		addq.l #1,A1
		cpushl IC,(A1)
		add.l #0x10-3,A1
	cmp.l #LAST_ICACHE_ADDR,A1
	bls.s .fic1
	move.w D0,SR
	rts

_disable_caches:

	move.l D0,-(SP)
	move.w SR,D0
	move.l D0,-(SP)
	or.l #0x700,D0           // mask interrupts
	move.w D0,SR
	bsr _flush_caches
	nop
	move.l #0x01000120,D0    // Invalidate and disable cache
	movec D0,CACR
	move.l (SP)+,D0
	move.w D0,SR
	move.l (SP)+,D0
	rts

_enable_caches:

	move.w SR,D0
	move.l D0,-(SP)
	or.l #0x700,D0           // mask interrupts
	move.w D0,SR
	bsr _flush_caches
	nop
	move.l #0x01040120,D0    // invalidate whole cache
	movec D0,CACR
	nop
	move.l #0xA2088020,D0    // enable caches
	movec D0,CACR
	move.l (SP)+,D0
	move.w D0,SR
	rts

#if !defined(MCF547X) && !defined(MCF5445X)

_set_intfrcl:                         // force interrupt

	move.l 4(SP),D0
	or.l D0,MCF_INTC_INTFRCL
	rts

_clr_intfrcl:                         // unforce interrupt

	move.l 4(SP),D0
	and.l D0,MCF_INTC_INTFRCL
	rts

#endif /* !defined(MCF547X) && !defined(MCF5445X) */
#endif /* LWIP */
#endif /* NETWORK */

#ifdef MCF547X

_acp_new_hardware:                    // need asm timming

	moveq #0,D1
	moveq.l #0x55,D0
	move.w D0,ACP_VIDEO_PLL_CLK
	move.w ACP_VIDEO_PLL_CLK,D1 // 1st read not works
	move.w ACP_VIDEO_PLL_CLK,D1 // 2nd access works
	cmp.l D0,D1
	seq.b D0
	and.l #1,D0
	rts

#endif /* MCF547X */

#endif /* COLDFIRE */

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
	and.l #0xff,D1
#if defined(DEBUG) && !defined(COLDFIRE)
	tst.w _video_found
	beq.s .normal_conout 
	move.l D1,D0
	bsr display_char
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rts
.normal_conout:		
#endif
	move.l con_state,A0
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
	
message:	.asciz "Ram-disk installed in "
#if defined(CONFIG_USB_UHCI) || defined(CONFIG_USB_OHCI) || defined(CONFIG_USB_EHCI)
#ifdef CONFIG_USB_STORAGE
message1:	.ascii "TOS4.04 "
message2:	.asciz "USB  "
message2b:	.asciz ", disk installed in "
#endif
#endif
crlf:	.byte 13,10,0
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

	.align 2

	.lcomm _address_ram_disk,4
	.lcomm _size_ram_disk,4
	.lcomm _change_ram_disk,4
	.lcomm _ext_write_protect_ram_disk,4
	.lcomm ram_disk_drive,4
	.lcomm old_hdv_bpb,4
	.lcomm old_hdv_rw,4
	.lcomm old_hdv_mediach,4
#if defined(CONFIG_USB_UHCI) || defined(CONFIG_USB_OHCI) || defined(CONFIG_USB_EHCI)
#ifdef CONFIG_USB_STORAGE
#ifndef COLDFIRE
	.lcomm pun_ptr_usb,4
#endif
	.lcomm _usb_1st_disk_drive,4
	.lcomm old_hdv_bpb_usb,4
	.lcomm old_hdv_rw_usb,4
	.lcomm old_hdv_mediach_usb,4
	.lcomm old_xhdi,4
	.lcomm old_xhdi_version,4
	.lcomm product_name,4*(PUN_DEV+1)
#endif /* CONFIG_USB_STORAGE */
#endif /* CONFIG_USB_UHCI || CONFIG_USB_OHCI || CONFIG_USB_EHCI */
