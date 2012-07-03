/* XBIOS CT60 board functions
*  - Read on the CT60, the 68060 temperature on the TLV0831 DC from Texas I.
*    2.8 deg celcius / step 
*  - Parameters in Flash
*  - Backup NVM stored in flash
*  - Cache
*  - PCI BIOS
*  - Eiffel keyboard XBIOS
*
*  XBIOS Coldfire board(s) functions
*  - Parameters in Flash
*  - Backup NVM (SRAM) stored in flash
*  - IKBD from CAN on MCF548X (special version of Eiffel) and UART2 on MCF5445X (serial port, normal)
*  - IKBD from UART2 on MCF5445X
*  - IKBD from PSC1 and FPGA on MCF547X
*  - Serial from PSC0/UART0 or serial mouse
*  - MFP timers replaced by GPT timers on MCF547X-MCF548X and PIT timers on MCF5445X
*  - VBL replaced by SLT0 timer on MCF547X-MCF548X and DTMR0 timer on MCF5445X
*  - Cache
*  - PCI BIOS
*  - Eiffel keyboard XBIOS
*
*  Didier Mequignon 2001-2012, e-mail: aniplay@wanadoo.fr
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
*/

#include "main.h"
#include "ct60.h"
#include "command.h"
#include "vars.h"

#ifdef COLDFIRE
#define USE_MFP /* FIREBEE FPGA emulation */
#undef DEBUG
#endif

// #define DEBUG_GEMDOS
// => move.b #0x01,0x5695 before the Gemdos call

#define CT60_READ_ERROR -1

#ifdef COLDFIRE

#include "fire.h"

#ifndef MCF5445X
/* CAN */
#define NODE_ID  1
#define PDO1TX   (0x180+NODE_ID) // Process Data Object Received
#define PDO1RX   (0x200+NODE_ID) // Process Data Object Send
#endif

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
#define V_STAT_0 -6
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
#define _DESTX 76
#define _DESTY 78
#define _DELX 80
#define _DELY 82
#define _FBASE 84
#define _FWIDTH 88
#define _STYLE 90
#define _SCALE 102
#define _CHUP 104
#define REQ_COL48E 174 // 240 colors RVB TOS 4.XX FALCON

/* font */
#define FACE_ID 0
#define FONT_SIZE 2
#define FONT_NAME 4
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
#define HOR_OFF_TABLE 68
#define CHAR_OFF_TABLE 72
#define FONTDAT 76
#define FORMWIDTH 80
#define FORMHEIGHT 82
#define NEXT_FONT 84

#define MOUSE_ACCEL 4

#endif /* COLDFIRE */

#define read_core_temperature 0xc60a
#define rw_parameter 0xc60b
#define cache 0xc60c
#define flush_cache 0xc60d
#define vmalloc 0xc60e
#define read_core_temperature_bis 0x0c6a
#define rw_parameter_bis 0x0c6b
#define cache_bis 0x0c6c
#define flush_cache_bis 0x0c6d
#define vmalloc_bis 0xc6e

#ifdef COLDFIRE
	.globl flush_caches
	.globl flush_data_cache
	.globl flush_instr_cache
	.globl caches_disable
	.globl caches_enable
	.globl replace_mfp
	.globl disable_interrupts
	.globl install_scsidrv
#ifdef MCF547X
	.globl rtc_init
	.globl flopvbl
	.globl setporta
	.globl waitdma
#endif
	.globl delay_5mS
	.globl delay_80us
	.globl delay_10us
	.globl int_timer_c_mfp
	.globl tempo_reset_ikbd
#ifndef MCF547X
	.globl gettime
	.globl end_settime
#endif
	.globl ikbdwc
	.globl ikbdws
	.globl auxistat
	.globl auxin
	.globl auxostat
	.globl auxout
	.globl _Setscreen
#else /* !COLDFIRE */
	.globl code_led
#endif /* COLDFIRE */
	.globl get_cookie
	.globl det_xbios
	.globl nvm_access
	.globl test_rtc
#if defined(COLDFIRE) && defined(MCF547X)
	.globl end_settime_rtc
#endif
	.globl fix_settime
#if !defined(COLDFIRE) || defined(MCF547X)
	.globl fix_gettime
#endif
	.globl new_ikbdvect
	.globl new_statvec
#ifdef COLDFIRE
	.globl fire_rw_param
#else
	.globl ct60_rw_param
	.globl ct60_read_temp
#endif

	.text
	
#ifdef COLDFIRE
	.chip 5200
	
flush_caches:

	.chip 68060
	cpusha BC
	.chip 5200
	rts

flush_data_cache:

	.chip 68060
	cpusha DC
	.chip 5200
	rts

flush_instr_cache:

	.chip 68060
	cpusha IC
	.chip 5200
	rts

caches_disable:

#ifdef DEBUG
	move.l A0,-(SP)
	lea debug18(PC),A0
	bsr debug_display_string	
	move.l (SP)+,A0
#endif
	move.l D0,-(SP)
	move.l #CACHE_DISABLE_MODE,D0    // invalidate whole cache
	movec D0,CACR
	move.l (SP)+,D0
	rts

caches_enable:

#ifdef DEBUG
	move.l A0,-(SP)
	lea debug17(PC),A0
	bsr debug_display_string	
	move.l (SP)+,A0
#endif
	move.l D0,-(SP)
	move.l #CACHE_ENABLE_MODE,D0 // enable caches
	movec D0,CACR
	move.l (SP)+,D0	
	rts

replace_mfp:
	
#ifdef DEBUG
	lea debug2(PC),A0
	bsr debug_display_string
#endif
	clr.b serial_mouse
	move.w #0x1111,D0
	move.w D0,0x11BA
	moveq #20,D0
	move.w D0,_timer_ms
#ifdef MCF5445X
	moveq #DTIM_DTMR_RST,D1
	move.w #DTIM_DTMR_ORRI + DTIM_DTMR_FRR + DTIM_DTMR_CLK(1),D0
	move.w D0,MCF_DTIM_DTMR0
	moveq #0,D0
	move.l D0,MCF_DTIM_DTCN0
	move.w D0,MCF_DTIM_DTXMR0
	move.l #SYSTEM_CLOCK*1000,D0 // 1mS
	move.l D0,MCF_DTIM_DTRR0
	move.w MCF_DTIM_DTMR0,D0
	or.l D1,D0
	move.w D0,MCF_DTIM_DTMR0 // run
	lea new_vbl(PC),A0
	move.l A0,(64+INT0_HI_DTMR0+OFFSET_INT_CF68KLIB)*4
	moveq #4,D0              // level 4
	move.b D0,MCF_INTC_ICR0+INT0_HI_DTMR0
	move.l #~INTC_IPRH_INT32,D0
	and.l D0,MCF_INTC_IMRH0 
	move.w #((SYSTEM_CLOCK * 256) + 1) + DTIM_DTMR_CLK(1),D0
	move.w D0,MCF_DTIM_DTMR1	
	moveq #0,D0
	move.l D0,MCF_DTIM_DTCN1
	move.w D0,MCF_DTIM_DTXMR1
	move.l D0,MCF_DTIM_DTRR1
	move.w MCF_DTIM_DTMR1,D0
	or.l D1,D0
	move.w D0,MCF_DTIM_DTMR1 // run
	clr.w MCF_PIT_PCSR0      // disable timers
	clr.w MCF_PIT_PCSR1
	clr.w MCF_PIT_PCSR2
	clr.w MCF_PIT_PCSR3
#else /* MCF547X-MCF548X */
#ifdef MCF547X /* FIREBEE */
	lea 0xFFFF8800,A0        // PSG (FPGA emulation)
	lea 2(A0),A1
	move.b #7,(A0)
	move.b #0xC0,(A1)        // ports A / B outputs
	move.b #14,(A0)          // port A
	move.b #7,(A1)           // unselect floppy
	lea 0xFFFFFA01,A0        // MFP (FPGA emulation)
	moveq #0,D0
	moveq #23,D1
.clear_mfp:
		clr.b (A0,D0.l)
		addq.l #2,D0
	subq.l #1,D1
	bpl.s .clear_mfp
	moveq #0x04,D0
	move.b D0,2(A0)          // AER
	move.b #0x48,D0
	move.b D0,22(A0)         // VR
	clr.b stop_mfp_ikbd
	lea int6_mfp(PC),A0
	move.l A0,(64+6+OFFSET_INT_CF68KLIB)*4 // IRQ6 EPORT
	clr.l ACP_INTERRUPT_CLEAR
	move.l #ACP_INT_MFP_IRQ6 + ACP_INT_VSYNC_IRQ4 + ACP_INT_HSYNC_IRQ2,D0
	or.l D0,ACP_INTERRUPT_ENABLE     
	move.b MCF_EPORT_EPIER,D0
	or.l #MCF_EPORT_EPIER_EPIE6,D0
	move.b D0,MCF_EPORT_EPIER
	move.l #~(MCF_INTC_IMRL_INT_MASK6 + MCF_INTC_IMRL_MASKALL),D0
	and.l D0,MCF_INTC_IMRL
#endif /* MCF5474X */
	lea new_vbl(PC),A0       // for rtos
	move.l A0,(64+4+OFFSET_INT_CF68KLIB)*4
	tst.l tid_tos
	bne.s .use_rtos_timer2
	move.l #SYSTEM_CLOCK*1000,D0 // 1mS
	move.l D0,MCF_SLT_SLTCNT0
	move.l #MCF_SLT_SCR_TEN + MCF_SLT_SCR_IEN + MCF_SLT_SCR_RUN,D0
	move.l D0,MCF_SLT_SCR0
	move.l A0,(64+54+OFFSET_INT_CF68KLIB)*4
	moveq #0x20,D0           // level 4, priority 0
	move.b D0,MCF_INTC_ICR54
	move.l #~MCF_INTC_IMRH_INT_MASK54,D0
	and.l D0,MCF_INTC_IMRH
.use_rtos_timer2:
	moveq #-1,D0
	move.l D0,MCF_SLT_SLTCNT1
	move.l #MCF_SLT_SCR_TEN + MCF_SLT_SCR_RUN,D0
	move.l D0,MCF_SLT_SCR1
	clr.l MCF_GPT_GMS0       // disable timers
	clr.l MCF_GPT_GMS1
	clr.l MCF_GPT_GMS2
	clr.l MCF_GPT_GMS3
	move.l #MCF_GPT_GMS_GPIO_OUTHI + MCF_GPT_GMS_TMS_GPIO,D0
	move.l D0,MCF_GPT_GMS0
	move.l D0,MCF_GPT_GMS1
	move.l D0,MCF_GPT_GMS2
	move.l D0,MCF_GPT_GMS3
#endif /* MCF5445X */
	moveq #2,D0              // timer C
	moveq #0x50,D1           // / 64
	move.w #192,D2
	bsr settimer
#ifndef MCF547X /* vector already used for MFP emulation on FIREBEE */
	lea new_timer(PC),A0     // for rtos
	move.l A0,(64+6+OFFSET_INT_CF68KLIB)*4
#endif
	lea 0xE03C50,A0          // timer C interrupt routine 
	move.l A0,TIMER_C_VEC    // for rtos because it's impossible to use initint
	tst.l tid_tos
	bne.s .use_rtos_timer
	moveq #5,D0              // enable timer C
	bsr initint
.use_rtos_timer:
#ifdef MCF547X
	clr.w -(SP)              // SCR
	move.w #1,-(SP)          // TSR, transmitter enable
	move.w #1,-(SP)          // RSR, receiver enable
	move.w #0x98,-(SP)       // UCR, no parity, 2 stops, 8 bits
	clr.w -(SP)              // ctrl, no XON/XOFF, no CTS/RTS
	move.w #1,-(SP)          // 9600 bauds
	jsr 0xE02B06             // Rsconf MFP
	lea 12(SP),SP
	moveq #14,D1             // port A PSG
	bsr Giaccess
	move.l #0xE7,D2          // RTS & DTR
	and.l D2,D0
	bset #7,D1               // write port A
	bsr Giaccess
#else /* MCF548X */
	moveq #3,D0              // timer D
	moveq #1,D1              // 4
	moveq #2,D2              // 9600 bauds
	bsr settimer
#endif /* MCF547X */
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SERIAL_SPEED,D1 // type_param
	moveq #0,D2              // value
             jsr fire_rw_param
	tst.l D0
	bmi.s .default_speed
	cmp.l #16,D0
	bcs.s .speed_ok
.default_speed:
//	moveq #1,D0              // 9600 bauds
	moveq #0,D0              // 19200 bauds
.speed_ok:
	moveq #0,D1              // no XON/XOFF, no CTS/RTS
	moveq #0x18,D2           // no parity, 2 stops, 8 bits
	bsr Rsconf
	lea 0xF72,A0             // iorec RS232
	lea 0xE02776,A1
	moveq #33,D0
	bsr bytes_copy
#ifdef MCF547X
	lea 0x165A,A0            // iorec RS232
	move.l A0,0x11D2
	lea 0xE02776,A1
	moveq #33,D0
	bsr bytes_copy
	lea 0x145A,A0
	move.l A0,0x165A
	lea 0x155A,A0
	move.l A0,0x1668
#endif /* MCF547X */
	lea 0x10A4,A0
	lea 0xE02768,A1
	moveq #13,D0
	bsr bytes_copy
	move.w #0xFFFF,D0
	move.w D0,0x115C
	lea ikbdvect(PC),A0      // 0xE0340A
	move.l A0,0x1132         // IKBD keyboard (code < 0xF6)
#ifdef MCF547X
	lea sysmidi(PC),A0
#else
	lea unimplemented(PC),A0 // 0xE03920
#endif
	move.l A0,0x1136         // midivec (unused because not called)
	lea 0xE032EA,A0          // RTS
	move.l A0,0x113A         // vkbderr, keyboard error (unused because not called)
	move.l A0,0x113E         // vmiderr, MIDI error (unused because not called)
	lea det_statvec(PC),A0   // for Eiffel	
	move.l A0,0x1142         // statvec
	lea 0xE02750,A0          // RTS
	move.l A0,0x1146         // mousevec
	lea jdosgettime(PC),A1   // 0xE0225C
	move.l A1,0x114A         // clockvec
	move.l A0,0x114E         // joyvec
	lea unimplemented(PC),A0 // 0xE032AC
	move.l A0,0x1152         // midisys, MIDI interrupt (unused because not called)
	lea unimplemented(PC),A0 // 0xE032BA
	move.l A0,0x1156         // ikbdsys, keyboard interrupt (unused because not called)
	moveq #7,D0
	move.b D0,conterm        // keyclick, repeat, bell enable
	moveq #0,D0
	move.l D0,0x11BC         // sound pointer
	move.b D0,0x11C0         // delay timer
	move.b D0,0x11C1         // temp value
	move.l D0,0x11B6         // printer timeout
	moveq #15,D0
	move.b D0,0x11B4
	moveq #2,D0
	move.b D0,0x11B5
	lea 0xF96,A0             // iorec keyboard
	lea 0xE0275A,A1
	moveq #13,D0
	bsr bytes_copy
#ifdef MCF547X                        // Bconmap init 6:MFP, 7:PSC0 (default), FIREBEE has no SCC inside FPGA emulation
	lea 0x11D6,A0
	move.l A0,0x11C6
	moveq #2,D0              // 2 tables MFP & PSC0
	move.w D0,0x11CA
	lea 0xE02BEA,A1
	moveq #17,D0
.init_bconmap:
		move.l (A1)+,(A0)+
	subq.l #1,D0
	bpl.s .init_bconmap
	moveq #7,D0              // PSC0 by default
	move.w D0,0x11CC
	lea 0x11EE,A0
	lea auxistat(PC),A1
	move.l A1,(A0)+
	move.l A1,0x522          // bconstat(2)
	lea auxin(PC),A1
	move.l A1,(A0)+
	move.l A1,0x542          // bconin(2)
	lea auxostat(PC),A1
	move.l A1,(A0)+
	move.l A1,0x562          // bcostat(2)
	lea auxout(PC),A1
	move.l A1,(A0)+
	move.l A1,0x582          // bconout(2)
	lea rsconf(PC),A1
	move.l A1,(A0)+
	move.l A1,0x11CE
#endif /* MCF547X */
	link A6,#-4              // bioskeys, init IKBD tables 
	clr.l -4(A6)
	pea -1(A6)               // buffer
	move.w #1,-(SP)          // size
	move.w #7,-(SP)          // start
	clr.w -(SP)              // read
	bsr nvm_access
	lea 10(SP),SP
	tst.w D0
	bne.s .default_value_keyb
	move.l -4(A6),D1
	cmp.l #9,D1
	bcs.s .lang_keyb_ok
.default_value_keyb:
	moveq #0,D1
.lang_keyb_ok:
	unlk A6
	mulu #4*6,D1
	lea 0xE036E2,A0          // tables
	add.l D1,A0
	lea 0x1188,A1
	move.l (A0)+,(A1)+       // tab_unshift
	move.l (A0)+,(A1)+       // tab_shift
	move.l (A0)+,(A1)+       // tab_caps
	move.l (A0)+,(A1)+       // tab_altgr
	move.l (A0)+,(A1)+       // tab_shaltgr
	move.l (A0)+,(A1)+       // tab_alt
	clr.b 0x11B1
#ifdef MCF5445X
	bsr ikbd_init            // uart 2 for IKBD
#else
#ifdef MCF547X 
	moveq #3,D0
	move.b D0,0xFFFFFC04     // reset ACIA MIDI
	move.b #0x95,D0
	move.b D0,0xFFFFFC04     // / 16, 8 bits, 1 stop, no parity
	bsr ikbd_init            // PSC1 / ACIA for IKBD
//	bsr rtc_init             // PSC3 for RTC => moved before_init_cookie
	bsr pseudo_dma_init
	// MFP UART vectors
	lea 0xE028E8,A0
	moveq #12,D0             // MFP vector 12, enable RX full
	bsr initint
	lea 0xE029E4,A0
	moveq #11,D0             // MFP vector 11, enable RX error
	bsr initint
	lea 0xE02982,A0
	moveq #10,D0             // MFP vector 10, enable TX empty
	bsr initint
	lea 0xE02A04,A0
	moveq #9,D0              // MFP vector 9, enable TX error
	bsr initint
	lea 0xE0299E,A0
	moveq #2,D0              // MFP vector 2, enable CTS
	bsr initint
#else /* MCF548X */
	bsr can_init             // used for IKBD
#endif /* MCF547X */
#endif /* MCF5445X */
	lea reset_ikbd(PC),A0    // init data IKBD
	moveq #3,D0
	bsr Ikbdws               // send to IKBD
	lea int_serial(PC),A0
#ifdef MCF5445X
	move.l A0,(64+INT0_LO_UART0+OFFSET_INT_CF68KLIB)*4
	moveq #6,D0              // level 6
	move.b D0,MCF_INTC_ICR0+INT0_LO_UART0
	move.l #~INTC_IMRL_INT_MASK26,D0
	and.l D0,MCF_INTC_IMRL0
#else /* MCF548X */
	move.l A0,(64+35+OFFSET_INT_CF68KLIB)*4 // PSC0
	moveq #0x25,D0           // level 4, priority 5
	move.b D0,MCF_INTC_ICR35
	move.l #~MCF_INTC_IMRH_INT_MASK35,D0
	and.l D0,MCF_INTC_IMRH
	move.l #~MCF_INTC_IMRL_MASKALL,D0
	and.l D0,MCF_INTC_IMRL   // global mask
#endif /* MCF5445X */
#if 0 // automatic 
	move.b #MCF_UART_UACR_IEC,D0
	move.b D0,MCF_UART_UACR0 // CTS enable interrupt
	moveq #MCF_UART_UISR_COS \
	 + MCF_UART_UIMR_RXRDY_FU \
	 + MCF_UART_UIMR_TXRDY,D0
#else
	moveq #MCF_UART_UIMR_RXRDY_FU + MCF_UART_UIMR_TXRDY,D0
#endif
	move.b D0,psc_uimr
	move.b D0,MCF_UART_UIMR0 // enable TX/RX interrupts
	move.w #0x400,D0
	rts

#ifdef MCF547X /* FIREBEE */
	
flopvbl:                              // TOS404 0xE0429A

	moveq #-1,D0
	move.b D0,0x1690         // flag motor on
	tst.w flock
	bne .fv1                 // floppy in action
	move.l _frclock,d0
	move.l D0,D1
	and.l #7,D1
	bne .fv1                 // <> 8th interrupt
	move.w #0x80,D1          // select state register WD1772
	move.w D1,0xFFFF8606     // FDC
	lsr.l #3,D0
	and.l #1,D0              // bit 4 used for drive number
	lea 0x1680,A0            // write protect status table
	add.l D0,A0
	moveq #0,D1
	move.w _nflops,D1
	cmp.l D1,D0
	bne.s .fv3
	moveq #0,D0
.fv3:
	addq.l #1,D0             // select drive A / B (1/2)
	add.l D0,D0              // shift face
	eor.l #7,D0              // invert bits for hardware
	bsr setporta             // drive select
	bsr delay_80us
	move.w 0xFFFF8604,D0     // FDC
	btst #6,D0               // write protect bit
	sne.b D0
	move.b D0,(A0)
	move.b D2,D0             // restore port A
	bsr setporta
	move.w 0x1680,D0         // write protect status table 
	move.w 0x1682,D1         // write protect latch table
	or.l D1,D0
	move.w D0,0x1682         // write protect latch table
	tst.w 0x1692             // unselect flag
	bne.s .fv4               // floppy already unselected
	move.l _hz_200,D0
	cmp.l 0x168C,D0
	bcc.s .fv2
	bsr delay_80us
	move.w 0xFFFF8604,D0     // FDC
	btst #7,D0               // motor on
	bne.s .fv1
.fv2:
	moveq #7,D0              // unselect all
	bsr setporta
	moveq #1,D0
	move.w D0,0x1692         // unselect flag
.fv4:
	clr.w 0x1690             // motor on flag
.fv1:
	rts
	
setporta:

	move.w SR,D1
	move.w D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
	moveq #14,D1             // port A
	move.b D1,0xFFFF8800     // PSG
#if 1
	move.b psg_save_port_a,D1
#else
	move.b 0xFFFF8800,D1     // read outputs (seems not works on FPGA emulation)
#endif
	move.b D1,D2             // save state
	and.l #0xF8,D1
	and.l #7,D0              // new bits
	or.l D1,D0
	moveq #14,D1             // port A
	move.b D1,0xFFFF8800     // PSG
	move.b D0,0xFFFF8802     // write
#if 1
	move.b D0,psg_save_port_a
#endif
	move.w (SP)+,D1
	move.w D1,SR             // restore interrupts
	rts

waitdma:

#if 1
	move.l A0,-(SP)
	lea 0xFFFF860F,A0
.waitdma:
	btst #3,(A0)
	bne.s .waitdma
	move.l (SP)+,A0
#else
	bsr delay_80us
.wait_dma:
	tst.l ACP_DMA_COUNTER
	bgt.s .wait_dma
#endif
	rts

#endif /* MCF547X */

delay_5mS:

	move.l D2,-(SP)
	move.l #5000,D2          // 5 mS
	bra.s delay_us

delay_80us:                           // 0xE045E8 TOS404

	move.l D2,-(SP)
	moveq #80,D2             // 80 uS
	bra.s delay_us

delay_10us:

	move.l D2,-(SP)
	moveq #10,D2             // 10 uS

delay_us:

#ifdef COLDFIRE
	move.l D1,-(SP)
	move.l D0,-(SP)
#ifdef MCF5445X
	move.l MCF_DTIM_DTCN1,D1
.wait_us_loop:
		move.l MCF_DTIM_DTCN1,D0
		sub.l D1,D0
	cmp.l D2,D0
	bcs.s .wait_us_loop
#else /* MCF547X-MCF548X */
	MULU #SYSTEM_CLOCK,D2
	move.l MCF_SLT_SCNT1,D1
.wait_us_loop:
		move.l D1,D0
		sub.l MCF_SLT_SCNT1,D0
	cmp.l D2,D0
	bcs.s .wait_us_loop
#endif /* MCF5445X */
	move.l (SP)+,D0
	move.l (SP)+,D1
#else /* 68060 */
	move.l D1,-(SP)
	divu #26,D2
	subq.w #1,D2
	bmi.s .wait_end
.wait_us_loop:
		move.b 0xFFFFFA23,D1 // MFP TCDR
.wait_timer_c:
		cmp.b 0xFFFFFA23,D1
		beq.s .wait_timer_c
	dbf D2,.wait_us_loop
.wait_end:
	move.l (SP)+,D1
#endif /* COLDFIRE */
	move.l (SP)+,D2
	rts
	
int_timer_c_mfp:

	move.l D0,-(SP)
	addq.l #1,_hz_200
	move.l _hz_200,D0
	and.l #3,D0
	beq.s .int_hz_50
	move.l (SP)+,D0
	rte
.int_hz_50:
	move.l current_tcb,D0
	cmp.l tid_tos,D0
	bne.s .not_timer_c_tos
	lea -56(SP),SP
	movem.l D1-D7/A0-A6,(SP)
#ifdef MCF547X
	bsr sndirq
#endif
	move.b conterm,D0
	btst #1,D0               // key repeat flag
	beq.s .no_repeat_key
	tst.b 0x11B1             // key pressed ?
	beq.s .no_repeat_key
	move.b 0x11B2,D0         // start counter
	beq.s .no_start_counter
	subq.l #1,D0
	move.b D0,0x11B2         // start counter
	bne.s .no_repeat_key
.no_start_counter:
	move.b 0x11B3,D0         // repeat counter
	subq.l #1,D0
	move.b D0,0x11B3
	bne.s .no_repeat_key
	move.b 0x11B5,D0         // reload repeat counter
	move.b D0,0x11B3
	move.b 0x11B1,D0         // repeat current key
	lea 0xF96,A0
	bsr ikbdvect2            // key inside the buffer (0xE03508)
.no_repeat_key:
	move.w _timer_ms,-(SP)
	move.l etv_timer,A0
	jsr (A0)
	addq.l #2,SP
	movem.l (SP),D1-D7/A0-A6
	lea 56(SP),SP
.not_timer_c_tos:
	move.l (SP)+,D0
	rte

#ifdef MCF547X

sndirq:

	lea -12(SP),SP
	movem.l D0-D1/A0,(SP)
	move.l 0x11BC,D0
	beq .sndirq_end          // no active sound
	move.l D0,A0             // data pointer
	moveq #0,D0
	move.b 0x11C0,D0         // timer value
	beq.s .sndirq1           // new sound ?
	subq.l #1,D0
	move.b D0,0x11C0
	bra.s .sndirq_end
.sndirq1:
		moveq #0,D0
		move.b (A0)+,D0
		bmi.s .sndirq2  // command
		move.b d0,0xFFFF8800 // PSG (FPGA emulation)
		cmp.l #7,D0     // register 7
		bne.s .sndirq3
		move.b (A0)+,D1 // data for register 7
		and.l #0x3F,D1
		move.b 0xFFFF8800,D0 // PSG (FPGA emulation)
		and.l #0xC0,D0
		or.l D1,D0
		move.b D0,0xFFFF8802 // PSG (FPGA emulation)
		bra.s .sndirq1
.sndirq3:
		move.b (A0)+,0xFFFF8802 // PSG (FPGA emulation)
		bra.s .sndirq1
.sndirq2:
		cmp.l #0xFF,D0 // command
		beq.s .sndirq4
		cmp.l #0x80,D0 // command
		bne.s .sndirq6
		move.b (A0)+,0x11C1
	bra.s .sndirq1           // next sound
.sndirq6:
	cmp.l #0x81,D0           // command
	bne.s .sndirq4
	move.b (A0)+,0xFFFF8800  // PSG (FPGA emulation)
	moveq #0,D1
	move.b 0x11C1,D1
	move.b (A0)+,D0
	add.l D0,D1
	move.b D1,0x11C1
	move.b (A0)+,D0
	move.b D1,0xFFFF8802     // PSG (FPGA emulation)
	cmp.l D0,D1
	beq.s .sndirq5           // end
	subq.l #4,A0             // previous command
	bra.s .sndirq5
.sndirq4:
	move.b (A0)+,0x11C0      // next value for wait timer
	bne.s .sndirq5
	lea 0,A0
.sndirq5:
	move.l A0,0x11BC         // data pointer
.sndirq_end:
	movem.l (SP),D0-D1/A0
	lea 12(SP),SP
	rts

#endif /* MCF547X*/
	
tempo_reset_ikbd:

	move.l D0,-(SP)
	move.l D1,-(SP)
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug38(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#ifdef MCF5445X
	move.l MCF_DTIM_DTCN1,D1
.loop_tempo_ikbd_reset:
		move.l D1,D0
		sub.l MCF_DTIM_DTCN1,D0
	cmp.l #300000,D0 // 300 mS
	bcs.s .loop_tempo_ikbd_reset
#else /* MCF548X */
	move.l MCF_SLT_SCNT1,D1
.loop_tempo_ikbd_reset:
		move.l D1,D0
		sub.l MCF_SLT_SCNT1,D0
	cmp.l #300000*SYSTEM_CLOCK,D0 // 300 mS
	bcs.s .loop_tempo_ikbd_reset
#endif /* MCF5445X */
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug38b(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	move.l (SP)+,D1
	move.l (SP)+,D0
	rts
	
reset_ikbd:
	dc.l 0x8001121A          // reset, mouse and joystick not connected
	
bytes_copy:

		move.b (A1)+,(A0)+
	subq.l #1,D0
	bpl.s bytes_copy
	rts
	
led:
#ifdef MCF5445X
	move.l D0,-(SP)
	btst #0,D0
	beq.s .led_off
	moveq #LEDS_LED1,D0
	or.l D0,FPGA_LEDS
	move.l (SP)+,D0
	rts
.led_off:	
	moveq #~LEDS_LED1,D0
	and.l D0,FPGA_LEDS
	move.l (SP)+,D0
	rts
#else /* MCF548X */
#ifdef MCF547X
	move.l D0,-(SP)
	btst #0,D0
	beq.s .led_off
	move.b MCF_GPIO_PODR_FEC1L,D0
	and.l #~MCF_GPIO_PODR_FEC1L_PODR_FEC1L4,D0
	move.b D0,MCF_GPIO_PODR_FEC1L
	move.l (SP)+,D0
	rts
.led_off:
	move.b MCF_GPIO_PODR_FEC1L,D0
	or.l #MCF_GPIO_PODR_FEC1L_PODR_FEC1L4,D0
	move.b D0,MCF_GPIO_PODR_FEC1L
	move.l (SP)+,D0
	rts
#else /* MCF548X */
	move.l D0,-(SP)
	btst #0,D0
	beq.s .led_off
	move.l #MCF_GPT_GMS_GPIO_OUTHI,D0
	or.l D0,MCF_GPT_GMS0     // TOUT0 to 1
	move.l (SP)+,D0
	rts
.led_off:		
	move.l #~MCF_GPT_GMS_GPIO_OUTLO,D0
	and.l D0,MCF_GPT_GMS0    // TOUT0 to 0
	move.l (SP)+,D0
	rts
#endif /* MCF547X */
#endif /* M5445X */ 

	dc.l 0x58425241          // XBRA
	dc.l 0x5F43465F          // _CF_
	dc.l 0x00000000

unimplemented:
	
	rts

new_vbl:

//	move.w #0x2700,SR
	move.l D0,-(SP)
#ifdef MCF5445X
	move.l MCF_DTIM_DTCN1,D0
	move.l #1000000/38400,-(SP)
	.chip 68060
	divu.l (SP)+,D0
	divu #192,D0
	.chip 5200
	clr.w D0
	swap D0
	addq.l #1,D0
	move.b D0,0xFFFFFA23     // TCDR MFP emulation
	tst.l tid_tos
	bne.s .use_rtos_vbl
	moveq #DTIM_DTER_REF,D0
	move.b D0,MCF_DTIM_DTER0 // clear interrupt
#else /* MCF548X */
#if 0
	tst.l tid_tos
	beq.s .not_use_rtos_vbl
	move.l MCF_INTC_INTFRCL,D0
	and.l #MCF_INTC_INTFRCL_INTFRC4,D0
	bne.s .not_use_rtos_vbl // forced VBL
 	// true VBL
	move.l #ACP_INT_VSYNC_IRQ4,D0
	move.l D0,ACP_INTERRUPT_CLEAR
	moveq #4,D0
	bset.b D0,MCF_EPORT_EPFR // clear interrupt	
	bra.s .not_vbl_tos
.not_use_rtos_vbl:
#endif
#if !(defined(MCF547X) && defined(USE_MFP)) /* <> FIREBEE FPGA emulation */
	move.l MCF_SLT_SCNT1,D0
	move.l #SYSTEM_CLOCK*1000000/38400,-(SP)
	.chip 68060
	divu.l (SP)+,D0
	divu #192,D0
	.chip 5200
	clr.w D0
	swap D0
	addq.l #1,D0
	move.b D0,0xFFFFFA23     // TCDR MFP emulation
#endif /* !(defined(MCF547X) && defined(USE_MFP)) */
	tst.l tid_tos
	bne.s .use_rtos_vbl
	move.l #MCF_SLT_SSR_ST,D0
	or.l D0,MCF_SLT_SSR0     // clear interrupt
#endif /* MCF5445X */
	move.l counter_1ms,D0
	addq.l #1,D0
	cmp.l #20,D0
	bcc.s .vbl_ok
	move.l D0,counter_1ms
.not_vbl_tos:
	move.l (SP)+,D0
	rte
.use_rtos_vbl:
#ifdef MCF5445X
	move.l #~INTC_INTFRCL_INTFRC4,D0
	and.l D0,MCF_INTC_INTFRCL0
#else /* MCF548X */
	move.l #~MCF_INTC_INTFRCL_INTFRC4,D0
	and.l D0,MCF_INTC_INTFRCL
#endif /* MCF5445X */
.vbl_ok:
	move.l current_tcb,D0
	cmp.l tid_tos,D0
	bne.s .not_vbl_tos
	clr.l counter_1ms
	move.l _frclock,D0
	lsr.l #2,D0
	bsr led
	move.l (SP)+,D0
	move.l VBL_VEC,-(SP)     // TOS404 0xE00CB0
	rts

#ifndef MCF547X
new_timer:

	move.l D0,-(SP)
#ifdef MCF5445X
	move.l #~INTC_INTFRCL_INTFRC6,D0
	and.l D0,MCF_INTC_INTFRCL0
#else /* MCF548X */
	move.l #~MCF_INTC_INTFRCL_INTFRC6,D0
	and.l D0,MCF_INTC_INTFRCL
#endif /* MCF5445X */
	move.l (SP)+,D0
	move.l TIMER_C_VEC,-(SP) // TOS404 0xE03C50
	rts
#endif /* MCF547X */
	
new_timer_a:

	move.l D0,-(SP)
#ifdef MCF5445X
	move.l D1,-(SP)
	moveq #PIT_PCSR_PIF,D1
	move.w MCF_PIT_PCSR0,D0
	or.l D1,D0
	move.w D0,MCF_PIT_PCSR0  // clear interrupt
	move.l (SP)+,D1
#else /* MCF548X */
	move.l #MCF_GPT_GSR_TEXP,D0
	or.l D0,MCF_GPT_GSR0     // clear interrupt
#endif /* MCF5445X */
	move.l (SP)+,D0
	move.l TIMER_A_VEC,-(SP)
	rts

new_timer_b:

	move.l D0,-(SP)
#ifdef MCF5445X
	move.l D1,-(SP)
	moveq #PIT_PCSR_PIF,D1
	move.w MCF_PIT_PCSR1,D0
	or.l D1,D0
	move.w D0,MCF_PIT_PCSR1  // clear interrupt
	move.l (SP)+,D1
#else /* MCF548X */
	move.l #MCF_GPT_GSR_TEXP,D0
	or.l D0,MCF_GPT_GSR1     // clear interrupt
#endif /* MCF5445X */
	move.l (SP)+,D0
	move.l TIMER_B_VEC,-(SP)
	rts

new_timer_c:

	move.l D0,-(SP)
#ifdef MCF5445X
	move.l D1,-(SP)
	moveq #PIT_PCSR_PIF,D1
	move.w MCF_PIT_PCSR2,D0
	or.l D1,D0
	move.w D0,MCF_PIT_PCSR2  // clear interrupt
	move.l (SP)+,D1
#else /* MCF548X */
	move.l #MCF_GPT_GSR_TEXP,D0
	or.l D0,MCF_GPT_GSR2     // clear interrupt
#endif /* MCF5445X */
	move.l (SP)+,D0
	move.l TIMER_C_VEC,-(SP) // TOS404 0xE03C50
	rts

new_timer_d:

	move.l D0,-(SP)
#ifdef MCF5445X
	move.l D1,-(SP)
	moveq #PIT_PCSR_PIF,D1
	move.w MCF_PIT_PCSR3,D0
	or.l D1,D0
	move.w D0,MCF_PIT_PCSR3  // clear interrupt
	move.l (SP)+,D1
#else /* MCF548X */
	move.l #MCF_GPT_GSR_TEXP,D0
	or.l D0,MCF_GPT_GSR3     // clear interrupt
#endif /* MCF5445X */
	move.l (SP)+,D0
	move.l TIMER_D_VEC,-(SP)
	rts
	
settimer:

	lea -16(SP),SP
	movem.l D0-D2/A0,(SP)
#ifdef DEBUG
	lea debug5(PC),A0
	bsr debug_display_string
#endif
#if defined(MCF547X) && defined(USE_MFP) /* FIREBEE FPGA emulation */
	lea 0xFFFFFA01,A0        // MFP (FPGA emulation)
	tst.l D0                 // timer
	beq.s .start_timer_a
	cmp.l #1,D0
	beq.s .start_timer_b    	
	cmp.l #2,D0
	beq.s .start_timer_c
	cmp.l #3,D0
	beq.s .start_timer_d   
 	bra.s .end_timer
.start_timer_a:
	clr.b 24(A0)             // TACR
	move.b D2,30(A0)         // TADR
	move.b D1,24(A0)         // TACR
 	bra.s .end_timer
.start_timer_b:
	clr.b 26(A0)             // TBCR
	move.b D2,32(A0)         // TBDR
	move.b D1,26(A0)         // TBCR
 	bra.s .end_timer
.start_timer_c:
	move.b 28(A0),D0         // TCDCR
	and.l #0xF,D0
	move.b D0,28(A0)         // TCDCR
	and.l #0xF0,D1
	or.l D0,D1               // control
	move.b D2,34(A0)         // TCDR
	move.b D1,28(A0)         // TCDCR
 	bra.s .end_timer
.start_timer_d:
	move.b 28(A0),D0         // TCDCR
	and.l #0xF0,D0
	move.b D0,28(A0)         // TCDCR
	and.l #0xF,D1
	or.l D0,D1               // control
	move.b D2,36(A0)         // TCDR
	move.b D1,28(A0)         // TCDCR
#else /* <> FIREBEE FPGA emulation */
	ext.l D0                 // timer
	ext.l D1                 // control
	ext.l D2                 // data
	cmp.l #2,D0              // timer C
	bne.s .not_timer_c
#if defined(MCF547X) && !defined(USE_MFP) /* FIREBEE FPGA emulation */
	move.l D0,-(SP)          // some programs read timer C for delay loop
	move.l D1,-(SP)
	lea 0xFFFFFA01,A0        // MFP (FPGA emulation)
	moveq #0x50,D1           // / 64
	move.w #192,D2
	move.b 28(A0),D0         // TCDCR
	and.l #0xF,D0
	move.b D0,28(A0)         // TCDCR
	and.l #0xF0,D1
	or.l D0,D1               // control
	move.b D2,34(A0)         // TCDR	
	move.b D1,28(A0)         // TCDCR
	move.l (SP)+,D1
	move.l (SP)+,D0
#endif /*  defined(MCF547X) && !defined(USE_MFP) */
	lsr.l #4,D1
.not_timer_c:
	tst.l D1
	beq .stop_timer
	cmp.l #7,D1              // delay mode
	bhi .end_timer
	asl.l #2,D1
	lea tab_prediv_mfp(PC),A0
	move.l (A0,D1.l),D1
	mulu.l D2,D1             // * data
	move.l #10000,D2
	mulu.l D2,D1
	move.l #24576,D2
	.chip 68060
	divu.l D2,D1             // MFP clock = 2.4576 MHz
	.chip 5200
#ifdef MCF5445X
	mulu #SYSTEM_CLOCK,D1
	move.l D1,D2
	moveq #0,D1
.loop_prediv:	
		btst #0,D2
		bne.s .max_prediv
		lsr.l #1,D2
		addq.l #1,D1
	bra.s .loop_prediv
.max_prediv:
	move.l D1,-(SP)
	move.l #0xFFFF,D1
	cmp.l D1,D2
	bcc.s .max_value
	move.l D2,D1
.max_value:
	move.l (SP)+,D1
	asl.l #8,D1
	move.b #PIT_PCSR_PIE + PIT_PCSR_RLD + PIT_PCSR_EN,D1
#else /* MCF548X */
	and.l #0xFFFF,D1         // => time in uS
	move.l #SYSTEM_CLOCK,D2  // pre
	swap D2
	or.l D1,D2
#endif /* MCF5445X */
	tst.l D0
	beq.s .start_timer_a
	cmp.l #1,D0
	beq.s .start_timer_b    	
	cmp.l #2,D0
	beq.s .start_timer_c
	cmp.l #3,D0
	beq .start_timer_d   
 	bra .end_timer   	
.start_timer_a:
#ifdef MCF5445X
	clr.w MCF_PIT_PCSR0
	move.w D2,MCF_PIT_PMR0
	move.w D1,MCF_PIT_PCSR0
#else /* MCF548X */
	move.l D2,MCF_GPT_GCIR0
#endif /* MCF5445X */
#ifdef DEBUG
	lea debug5a(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
#ifdef MCF5445X
	bra .end_timer
.start_timer_b:
	clr.w MCF_PIT_PCSR1
	move.w D2,MCF_PIT_PMR1
	move.w D1,MCF_PIT_PCSR1
#else /* MCF548X */
	move.l #MCF_GPT_GMS_GPIO_OUTHI + MCF_GPT_GMS_TMS_GPIO + MCF_GPT_GMS_IEN+MCF_GPT_GMS_SC + MCF_GPT_GMS_CE,D0
	move.l D0,MCF_GPT_GMS0
	bra .end_timer
.start_timer_b:
	move.l D2,MCF_GPT_GCIR1
#endif /* MCF5445X */
#ifdef DEBUG
	lea debug5b(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
#ifdef MCF5445X
	bra .end_timer
.start_timer_c:
	clr.w MCF_PIT_PCSR2
	move.w D2,MCF_PIT_PMR2
	move.w D1,MCF_PIT_PCSR2
#else /* MCF548X */
	move.l #MCF_GPT_GMS_GPIO_OUTHI + MCF_GPT_GMS_TMS_GPIO + MCF_GPT_GMS_IEN+MCF_GPT_GMS_SC + MCF_GPT_GMS_CE,D0
	move.l D0,MCF_GPT_GMS1
	bra .end_timer
.start_timer_c:
	move.l D2,MCF_GPT_GCIR2
#endif /* MCF5445X */
#ifdef DEBUG
	lea debug5c(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
#ifdef MCF5445X
	bra .end_timer
.start_timer_d:
	clr.w MCF_PIT_PCSR3
	move.w D2,MCF_PIT_PMR3
	move.w D1,MCF_PIT_PCSR3
#else /* MCF548X */
	move.l #MCF_GPT_GMS_GPIO_OUTHI + MCF_GPT_GMS_TMS_GPIO + MCF_GPT_GMS_IEN+MCF_GPT_GMS_SC + MCF_GPT_GMS_CE,D0
	move.l D0,MCF_GPT_GMS2
	bra .end_timer
.start_timer_d:
	move.l D2,MCF_GPT_GCIR3
#endif /* MCF5445X */
#ifdef DEBUG
	lea debug5d(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
#ifndef MCF5445X
	move.l #MCF_GPT_GMS_GPIO_OUTHI + MCF_GPT_GMS_TMS_GPIO + MCF_GPT_GMS_IEN+MCF_GPT_GMS_SC + MCF_GPT_GMS_CE,D0
	move.l D0,MCF_GPT_GMS3
#endif /* MCF5445X */
	bra .end_timer
.stop_timer:
#ifndef MCF5445X
	move.l #MCF_GPT_GMS_GPIO_OUTHI + MCF_GPT_GMS_TMS_GPIO,D1
#endif /* MCF5445X */
	tst.l D0
	beq.s .stop_timer_a
	cmp.l #1,D0
	beq.s .stop_timer_b
	cmp.l #2,D0
	beq.s .stop_timer_c
	cmp.l #3,D0
	beq.s .stop_timer_d
 	bra.s .end_timer
.stop_timer_a:
#ifdef MCF5445X
	clr.w MCF_PIT_PCSR0
	bra.s .end_timer
.stop_timer_b:
	clr.w MCF_PIT_PCSR1
	bra.s .end_timer
.stop_timer_c:
	clr.w MCF_PIT_PCSR2
	bra.s .end_timer
.stop_timer_d:
	clr.w MCF_PIT_PCSR3
#else /* MCF548X */
	clr.l MCF_GPT_GCIR0
	move.l D1,MCF_GPT_GMS0
	bra.s .end_timer
.stop_timer_b:
	clr.l MCF_GPT_GCIR1
	move.l D1,MCF_GPT_GMS1
	bra.s .end_timer
.stop_timer_c:
	clr.l MCF_GPT_GCIR2
	move.l D1,MCF_GPT_GMS2
	bra.s .end_timer
.stop_timer_d:
	clr.l MCF_GPT_GCIR3
	move.l D1,MCF_GPT_GMS3
#endif /* MCF5445X */
#endif /* defined(MCF547X) && defined(USE_MFP) */
.end_timer:
	movem.l (SP),D0-D2/A0
	lea 16(SP),SP
	rts

initint:

#ifdef DEBUG
	move.l A0,-(SP)
	lea debug6(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	bsr Jdisint
#if defined(MCF547X) && defined(USE_MFP)
	move.l D1,-(SP)
	move.l A1,-(SP)
	move.l D0,D1             // MFP vector number
	asl.l #2,D1              // * 4
	add.l #0x100,D1          // MFP vectors base
	move.l D1,A1
	move.l A0,(A1)           // new vector
	move.l (SP)+,A1
	move.l (SP)+,D1
#else /* !(defined(MCF547X) && defined(USE_MFP)) */
	cmp.l #13,D0
	beq.s .vect_timer_a
	cmp.l #8,D0
	beq.s .vect_timer_b
	cmp.l #5,D0
	beq.s .vect_timer_c
	cmp.l #4,D0
	beq.s .vect_timer_d	
	bra.s .end_new_vector	
.vect_timer_a:
	move.l A0,TIMER_A_VEC
#if !(defined(MCF547X) || defined(USE_MFP)) /* <> FIREBEE FPGA emulation */
	lea new_timer_a(PC),A0
#ifdef MCF5445X
	move.l A0,(128+INT1_HI_PIT0_PIF+OFFSET_INT_CF68KLIB)*4
#else /* MCF548X */
	move.l A0,(64+62+OFFSET_INT_CF68KLIB)*4
#endif
#endif /* defined(MCF547X) && defined(USE_MFP) */
	bra.s .end_new_vector
.vect_timer_b:
	move.l A0,TIMER_B_VEC
#if !(defined(MCF547X) || defined(USE_MFP)) /* <> FIREBEE FPGA emulation */
	lea new_timer_b(PC),A0
#ifdef MCF5445X
	move.l A0,(128+INT1_HI_PIT1_PIF+OFFSET_INT_CF68KLIB)*4
#else /* MCF548X */
	move.l A0,(64+61+OFFSET_INT_CF68KLIB)*4
#endif
#endif /* defined(MCF547X) && defined(USE_MFP) */
	bra.s .end_new_vector
.vect_timer_c:
	move.l A0,TIMER_C_VEC
#if !(defined(MCF547X) || defined(USE_MFP)) /* <> FIREBEE FPGA emulation */
	lea new_timer_c(PC),A0
#ifdef MCF5445X
	move.l A0,(128+INT1_HI_PIT2_PIF+OFFSET_INT_CF68KLIB)*4
#else /* MCF548X */
	move.l A0,(64+60+OFFSET_INT_CF68KLIB)*4
#endif
#endif /* defined(MCF547X) && defined(USE_MFP) */
	bra.s .end_new_vector
.vect_timer_d:
	move.l A0,TIMER_D_VEC
#if !(defined(MCF547X) || defined(USE_MFP)) /* <> FIREBEE FPGA emulation */
	lea new_timer_d(PC),A0
#ifdef MCF5445X
	move.l A0,(128+INT1_HI_PIT3_PIF+OFFSET_INT_CF68KLIB)*4
#else /* MCF548X */
	move.l A0,(64+59+OFFSET_INT_CF68KLIB)*4
#endif
#endif /* defined(MCF547X) && defined(USE_MFP) */
.end_new_vector:
#endif /* defined(MCF547X) && defined(USE_MFP) */
	bsr Jenabint
	rts	
	
tab_prediv_mfp:
	dc.l 0,4,10,16,50,64,100,200

#ifndef MCF547X

gettime:

	link A6,#-2
	clr.l 0x1176
	moveq #-1,D0
	move.b D0,0x11C4
	tst.b serial_mouse
	bne.s .keyboard_error
#ifdef DEBUG
	lea debug24(PC),A0
	bsr debug_display_string
#endif
	lea -2(A6),A0
	move.b #0x1C,(A0)        // gettime
	moveq #0,D0
	bsr Ikbdws
	bmi.s .keyboard_error
	move.l _hz_200,D1
.wait_time:	
		move.l _hz_200,D0
		sub.l D1,D0
		cmp.l #10,D0       // timeout 50 mS
		bge .keyboard_error
	tst.b 0x11C4
	bne.s .wait_time
.keyboard_error:
	move.l 0x1176,D0
	unlk A6
	rts
	
end_settime:

	link A6,#-8
	lea -8(A6),A0
	move.b #0x1B,(A0)+        // settime
	lea 0x117E,A1
	moveq #5,D0
.copy_time:
		move.b (A1)+,(A0)+
	sub.l #1,D0
	bpl.s .copy_time
	lea -8(A6),A0	
	moveq #6,D0
	bsr Ikbdws
	bmi.s .error_time
	lea -2(A6),A0
	move.b #0x1C,(A0)        // gettime
	moveq #0,D0
	bsr Ikbdws
.error_time:
	unlk A6
	rts

#endif /* MCF547X */
	
jdosgettime:                          // IKBD to DOS format
	
	lea 0x116D,A0
	bsr bcdbin
	sub.l #80,D0             // 1980
	bpl.s .year_before_2000_gettime_ikbd
	add.l #100,D0
.year_before_2000_gettime_ikbd:
	move.l D0,D2
	asl.l #4,D2
	bsr bcdbin
	add.l D0,D2
	asl.l #5,D2
	bsr bcdbin
	add.l D0,D2
	asl.l #5,D2
	bsr bcdbin
	add.l D0,D2
	asl.l #6,D2
	bsr bcdbin
	add.l D0,D2
	asl.l #5,D2
	bsr bcdbin
	lsr.l #1,D0
	add.l D0,D2
	move.l D2,0x1176         // store new time
	clr.b 0x11C4             // clear handshake flag
	rts

bcdbin:

	move.b (A0)+,D0
	move.b D0,D1
	and.l #0xF,D0
	and.l #0xF0,D1
	lsr.l #4,D1
	mulu.w #10,D1
	add.l D1,D0
	rts

Initmous:	// D0.W: type, A0: parameters, A1: vector

#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug20(PC),A0
	bsr debug_display_string
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,A0
	move.l (SP)+,D0
#endif
	move.l A3,-(SP)
	move.w D0,type_serial_mouse
	ext.l D0
	beq.s .disconnect_mouse
	move.l A1,0x1146         // mouse vector
	move.l A0,A3             // parameters
	cmp.l #1,D0
	beq.s .relative_mouse
	cmp.l #2,D0
	beq.s .absolute_mouse
	cmp.l #4,D0
	beq .keyboard_mouse
	move.l (SP)+,A3
	moveq #0,D0              // error
	rts
.disconnect_mouse:
	lea 0x11A0,A0            // transfer buffer
	move.b #0x12,(A0)
	moveq #0,D0
	bsr Ikbdws
	lea 0xE03B5E,A0          // RTS
	move.l A0,0x1146
	bra .end_initmouse
.relative_mouse:
	lea 0x11A0,A0            // transfer buffer
	move.b #8,(A0)+          // relative mouse mode
	move.b #0xB,(A0)+        // X, Y 
	bsr setmouse
	lea 0x11A0,A0
	moveq #6,D0
	bsr Ikbdws
	bra.s .end_initmouse
.absolute_mouse:
	lea 0x11A0,A0            // transfer buffer
	move.b #9,(A0)+          // absolute mouse mode
	move.b 4(A3),(A0)+
	move.b 5(A3),(A0)+	
	move.b 6(A3),(A0)+
	move.b 7(A3),(A0)+
	move.b #0xC,(A0)+        // absolute scale
	bsr setmouse
	move.b #0xE,(A0)+        // init position
	clr.b (A0)+
	move.b 8(A3),(A0)+       // X MSB
	move.b 9(A3),(A0)+       // X LSB
	move.b 10(A3),(A0)+      // Y MSB
	move.b 11(A3),(A0)+      // Y LSB
	lea 0x11A0,A0
	moveq #16,D0
	bsr Ikbdws
	bra.s .end_initmouse
.keyboard_mouse:
	lea 0x11A0,A0            // transfer buffer
	move.b #0xA,(A0)+        // mouse keycode mode
	bsr setmouse
	lea 0x11A0,A0
	moveq #5,D0
	bsr Ikbdws	
.end_initmouse:
	clr.b serial_mouse
	tst.w D0
	bpl.s .mouse_ok
#ifdef DEBUG
	lea debug21(PC),A0
	bsr debug_display_string
#endif
	moveq #7,D0              // 1200 bauds
	moveq #0,D1              // no XON/XOFF, no CTS/RTS
	moveq #0x28,D2           // no parity, 1 stop, 7 bits
	bsr Rsconf
	moveq #1,D0
	bsr setrts
	moveq #-1,D0
	move.b D0,serial_mouse   // try a serial mouse
	clr.w id_serial_mouse
	clr.w count_serial_mouse
.mouse_ok:
	move.l (SP)+,A3
	moveq #-1,D0             // OK
	rts
	
setmouse:

	move.b 2(A3),(A0)+       // X treshold, scale, delta
	move.b 3(A3),(A0)+       // Y treshold, scale, delta
	moveq #16,D1             // top/bottom ?
	moveq #0,D0
	move.b (A3),D0
	sub.l D0,D1
	move.b D1,(A0)+
	move.b #7,(A0)+
	move.b 1(A3),(A0)+
	rts

ikbdwc:

	move.w 6(SP),D1
	link a6,#-2
	moveq #0,D0
	move.b D1,-2(A6)
	lea -2(A6),A0
	bsr Ikbdws
	unlk A6
	rts
	

Ikbdws:	// D0.W: len-1, A0: buffer

#ifdef DEBUG
//	move.l A0,-(SP)
//	lea debug10(PC),A0
//	bsr debug_display_string
//	move.l (SP)+,A0
#endif
	moveq #0,D2
	move.w D0,D2             // len -1
#ifdef MCF5445X
.iw1:
		move.b MCF_UART_USR2,D1
		and.l #MCF_UART_USR_TXEMP,D1
		beq.s .iw1               // full
		move.b (A0)+,D0          // data inside the buffer
		move.b D0,MCF_UART_UTB2  // data
	subq.l #1,D2
	bpl.s .iw1
	moveq #0,D0              // OK
	rts
#else
#ifdef MCF547X
#if 0
	move.l D2,-(SP)
	move.l A0,-(SP)
.iw1:
		move.b MCF_UART_USR1,D1
		and.l #MCF_UART_USR_TXEMP,D1
		beq.s .iw1               // full
		move.b (A0)+,D0          // data inside the buffer
		move.b D0,MCF_UART_UTB1  // send data
	subq.l #1,D2
	bpl.s .iw1
	move.l (SP)+,A0
	move.l (SP)+,D2
#endif
.iw2:	// FIREBEE
		move.b 0xFFFFFC00,D1     // ACIA IKBD
		btst #1,D1               // ready
		beq.s .iw2
		move.b (A0)+,D0          // data inside the buffer
		move.b D0,0xFFFFFC02     // send data
	subq.l #1,D2
	bpl.s .iw2
	moveq #0,D0              // OK
	rts
#else /* MCF548X                         CAN1 */
	addq.l #1,D2	
.iw1:
		move.l MCF_CAN_ERRSTAT1,D0
		and.l #MCF_CAN_ERRSTAT_FLTCONF_BUSOFF /* + MCF_CAN_ERRSTAT_FLTCONF_PASSIVE */,D0
		bne.s .iw4
		move.l D2,-(SP)
		cmp.l #8,D2
		bls.s .iw2
		moveq #8,D2 // DLC
.iw2:
		move.l #PDO1RX,D1 // ID
		moveq #0,D0 // num
		bsr can_send_message
		move.l (SP)+,D2
		move.l MCF_SLT_SCNT1,D1
.iw3:
			move.l D1,D0
			sub.l MCF_SLT_SCNT1,D0
			cmp.l #50000*SYSTEM_CLOCK,D0 // 50 mS
			bge.s .iw4
			move.l MCF_CAN_ERRSTAT1,D0
			and.l #MCF_CAN_ERRSTAT_FLTCONF_BUSOFF /* + MCF_CAN_ERRSTAT_FLTCONF_PASSIVE */,D0
			bne.s .iw4
		move.w MCF_CAN_IFLAG1,D0
		and.l #MCF_CAN_IFLAG_BUF0I,D0
		beq.s .iw3  // wait message send
		move.w D0,MCF_CAN_IFLAG1 // clear flag
		addq.l #8,A0
	subq.l #8,D2
	bgt.s .iw1
	moveq #0,D0              // OK
	rts
.iw4:
#ifdef DEBUG
	lea debug11(PC),A0       // Bus-Off
	move.l MCF_CAN_ERRSTAT1,D0
	and.l #MCF_CAN_ERRSTAT_FLTCONF_BUSOFF,D0
	bne.s .iw5
	lea debug11b(PC),A0      // error passive
.iw5:
	bsr debug_display_string
#endif
	moveq #-1,D0             // error
	rts
#endif /* MCF547X */
#endif /* MCF5445X */

Jdisint:

#ifdef DEBUG
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug7(PC),A0
	bsr debug_display_string
	bsr debug_hex_char
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
#endif
	move.l D1,-(SP)
	ext.l D0
#if defined(MCF547X) && defined(USE_MFP) /* FIREBEE FPGA emulation */
	move.l A0,-(SP)
	lea 0xFFFFFA01,A0        // MFP (FPGA emulation)
	cmp.l #8,D0
	bcc.s .clr_imra
	bclr D0,20(A0)           // IMRB
	bclr D0,8(A0)            // IERB
	bclr D0,12(A0)           // IPRB
	bclr D0,16(A0)           // ISRB
	move.l (SP)+,A0
	bra.s .end_clr_imr_timer
.clr_imra:
	cmp.l #16,D0
	bcc.s .end_clr_imr_timer
	move.l D0,-(SP)
	subq.l #8,D0
	bclr D0,18(A0)           // IMRA
	bclr D0,6(A0)            // IERA
	bclr D0,10(A0)           // IPRA
	bclr D0,14(A0)           // ISRA
	move.l (SP)+,D0
	move.l (SP)+,A0
#else /* <> FIREBEE FPGA emulation */
	cmp.l #13,D0
	beq.s .clr_imr_timer_a
	cmp.l #8,D0
	beq.s .clr_imr_timer_b
	cmp.l #5,D0
	beq.s .clr_imr_timer_c
	cmp.l #4,D0
	beq.s .clr_imr_timer_d	
	bra.s .end_clr_imr_timer	
.clr_imr_timer_a:
#ifdef MCF5445X
	move.l #INTC_IMRH_INT_MASK43,D1
	bra.s .clr_imr_timer
.clr_imr_timer_b:
	move.l #INTC_IMRH_INT_MASK44,D1
	bra.s .clr_imr_timer
.clr_imr_timer_c:
	move.l #INTC_IMRH_INT_MASK45,D1
	bra.s .clr_imr_timer
.clr_imr_timer_d:
	move.l #INTC_IMRH_INT_MASK46,D1
.clr_imr_timer:
	or.l D1,MCF_INTC_IMRH1
#else /* MCF548X */
	move.l #MCF_INTC_IMRH_INT_MASK62,D1
	bra.s .clr_imr_timer
.clr_imr_timer_b:
	move.l #MCF_INTC_IMRH_INT_MASK61,D1
	bra.s .clr_imr_timer
.clr_imr_timer_c:
	move.l #MCF_INTC_IMRH_INT_MASK60,D1
	bra.s .clr_imr_timer
.clr_imr_timer_d:
	move.l #MCF_INTC_IMRH_INT_MASK59,D1
.clr_imr_timer:
	or.l D1,MCF_INTC_IMRH
#endif /* MCF5445X */
#endif /* defined(MCF547X) && defined(USE_MFP) */
.end_clr_imr_timer:
	move.l (SP)+,D1
	rts

Jenabint:

#ifdef DEBUG
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug8(PC),A0
	bsr debug_display_string
	bsr debug_hex_char
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
#endif
	move.l D1,-(SP)
	ext.l D0
#if defined(MCF547X) && defined(USE_MFP) /* FIREBEE FPGA emulation */
	lea 0xFFFFFA01,A0        // MFP (FPGA emulation)
	cmp.l #8,D0
	bcc.s .set_imra
	bset D0,8(A0)            // IERB
	bset D0,20(A0)           // IMRB
	bra.s .end_set_imr_timer
.set_imra:
	cmp.l #16,D0
	bcc.s .end_set_imr_timer
	subq.l #8,D0
	bset D0,6(A0)            // IERA
	bset D0,18(A0)           // IMRA
#else /* <> FIREBEE FPGA emulation */
	cmp.l #13,D0
	beq.s .set_imr_timer_a
	cmp.l #8,D0
	beq.s .set_imr_timer_b
	cmp.l #5,D0
	beq.s .set_imr_timer_c
	cmp.l #4,D0
	beq.s .set_imr_timer_d
	bra.s .end_set_imr_timer	
.set_imr_timer_a:
#ifdef MCF5445X
	moveq #6,D1              // level 6
	move.b D1,MCF_INTC_ICR1+INT1_HI_PIT0_PIF
	move.l #~INTC_IMRH_INT_MASK43,D1
	bra.s .set_imr_timer
.set_imr_timer_b:
	moveq #6,D1              // level 6
	move.b D1,MCF_INTC_ICR1+INT1_HI_PIT1_PIF
	move.l #~INTC_IMRH_INT_MASK44,D1
	bra.s .set_imr_timer
.set_imr_timer_c:
	moveq #6,D1              // level 6
	move.b D1,MCF_INTC_ICR1+INT1_HI_PIT2_PIF
	move.l #~INTC_IMRH_INT_MASK45,D1
	bra.s .set_imr_timer
.set_imr_timer_d:
	moveq #6,D1              // level 6
	move.b D1,MCF_INTC_ICR1+INT1_HI_PIT3_PIF
	move.l #~INTC_IMRH_INT_MASK46,D1
.set_imr_timer:
	and.l D1,MCF_INTC_IMRH1
#else /* MCF548X */
	moveq #0x26,D1           // level 4, priority 6
	move.b D1,MCF_INTC_ICR62
	move.l #~MCF_INTC_IMRH_INT_MASK62,D1
	bra.s .set_imr_timer
.set_imr_timer_b:
	moveq #0x23,D1           // level 4, priority 3
	move.b D1,MCF_INTC_ICR61
	move.l #~MCF_INTC_IMRH_INT_MASK61,D1
	bra.s .set_imr_timer
.set_imr_timer_c:
	moveq #0x22,D1           // level 4, priority 2
	move.b D1,MCF_INTC_ICR60
	move.l #~MCF_INTC_IMRH_INT_MASK60,D1
	bra.s .set_imr_timer
.set_imr_timer_d:
	moveq #0x21,D1           // level 4, priority 1
	move.b D1,MCF_INTC_ICR59
	move.l #~MCF_INTC_IMRH_INT_MASK59,D1
.set_imr_timer:
	and.l D1,MCF_INTC_IMRH
#endif /* MCF5445X */
#endif /* defined(MCF547X) && defined(USE_MFP) */
.end_set_imr_timer:
	move.l (SP)+,D1
	rts
	
Xbtimer: // D0.W: timer, D1.W: control, D2.W: data, A0: vector

	bsr settimer
	move.l A0,D0             // vector
	bmi.s .vector_not_used
	lea tab_num_int_timer(PC),A1
	move.b (A1,D0.l),D0
	bsr initint              // new vector
.vector_not_used:
	rts
	
tab_num_int_timer:
	dc.b 13,8,5,4

scale_mouse:

	move.l D1,-(SP)
	ext.w D0
	ext.l D0
	move.l D0,D1
	bpl.s .sm2
	neg.l D0
.sm2:
	cmp.l #4,D0
	bcs.s .sm3
	bne.s .sm4
	addq.l #6,D0
	addq.l #MOUSE_ACCEL/4,D0
	bra.s .sm6
.sm4:
	cmp.l #5,D0
	bne.s .sm5
	addq.l #8,D0
	addq.l #1,D0
	addq.l #MOUSE_ACCEL/2,D0
	bra.s .sm6
.sm5:
	mulu #MOUSE_ACCEL,D0
.sm6:
	cmp.l #127,D0
	bcs.s .sm3
	moveq #127,D0
.sm3:
	tst.l D1
	bpl.s .sm1
	neg.l D0
.sm1:
	move.l (SP)+,D1
	rts

get_serial_mouse:

	link A6,#-10
	lea -56(SP),SP
	movem.l D0-A5,(SP)
	and.l #0x7F,D0
	tst.w id_serial_mouse
	bne.s .gsm2              // ID found
	cmp.l #0x4D,D0           // M
	beq .gsm1
	move.b D0,id_serial_mouse
	bra .gsm1
.gsm2:
	tst.b id_serial_mouse+1
	bne.s .gsm4              // 2nd byte of ID found
	btst #6,D0
	bne.s .gsm6              // M  mouse
	move.w D0,id_serial_mouse+1
	cmp.l #0x33,D0
	beq.s .gsm5              // M3 mouse
	cmp.l #0x5A,D0
	beq.s .gsm5              // MZ mouse
	clr.w id_serial_mouse    // bad ID, retry again
	bra .gsm1
.gsm5:
	clr.w count_serial_mouse
	bra .gsm1
.gsm6:
	moveq #0x20,D1
	move.b D1,id_serial_mouse+1
	clr.w count_serial_mouse
.gsm4:	                         // get frame
	tst.w count_serial_mouse
	bne.s .gsm8
	btst #6,D0
	bne.s .gsm9
	bra .gsm1                // normally 4th byte of M3 mouse if 3rd button pressed
.gsm8:
	btst #6,D0
	beq .gsm9
	clr.w count_serial_mouse // try fo fix a sync problem
.gsm9:
	lea data_serial_mouse,A0
	move.w count_serial_mouse,D1
	and.l #3,D1
	move.b D0,(A0,D1.l)
	addq.l #1,D1
	move.w D1,count_serial_mouse
	moveq #0,D3
	move.w id_serial_mouse,D3
	moveq #3,D2              // 3 bytes
	cmp.l #0x4D5A,D3         // MZ mouse
	bne.s .gsm7
	addq.l #1,D2             // 4 bytes
.gsm7:
	cmp.l D2,D1              // end of frame ?
	bcs .gsm1
	clr.w count_serial_mouse
	lea -8(A6),A1
	move.b (A0),D0
	lsr.l #4,D0              // buttons
	and.l #3,D0
	or.l #0xF8,D0            // relative
	move.b D0,(A1)+          // relative 0xF8-0xFB
	move.b (A0),D0
	asl.l #6,D0
	and.l #0xC0,D0           // X7-X6
	move.b 1(A0),D1          // X5-X0
	or.l D1,D0
	bsr scale_mouse
	move.b D0,(A1)+          // DX
	move.b (A0),D0
	asl.l #4,D0
	and.l #0xC0,D0           // Y7-Y6
	move.b 2(A0),D1          // Y5-Y0
	or.l D1,D0
	bsr scale_mouse
	move.b D0,(A1)+          // DY
	lea 0xF96,A0             // iorec keyboard
	lea -10(A6),A1           // data - 2 for arcvint
	moveq #3,D2              // 3 bytes
.gsm3:
		lea -16(SP),SP
		movem.l D2/A0-A2,(SP)
		bsr arcvint // 0xE032EC
		movem.l (SP),D2/A0-A2
		lea 16(SP),SP
		addq.l #1,A1
	subq.l #1,D2
	bgt.s .gsm3
.gsm1:
	movem.l (SP),D0-A5
	lea 56(SP),SP
	unlk A6
	rts
	
auxistat:

	tst.b serial_mouse
	bne.s .ais2
#ifdef MCF547X
	lea 0x165A,A0            // iorec RS232
#else
	lea 0xF72,A0             // iorec RS232
#endif
	moveq #-1,D0             // OK
	moveq #0,D1
	moveq #0,D2
	move.w 8(A0),D1          // tail index
	move.w 6(A0),D2          // head index
	cmp.l D2,D1              // buffer empty
	bne.s .ais1              // no
.ais2:
	moveq #0,D0
.ais1:
	tst.l D0
	rts
	
auxin:

	moveq #0,D0
	tst.b serial_mouse
	bne.s .aux1
	bsr auxistat
	beq.s auxin
	bsr rs232get
	and.l #0xFF,D0
.aux1:
	rts	

auxostat:

	tst.b serial_mouse
	bne.s .aos3
#ifdef MCF547X
	lea 0x165A,A0            // iorec RS232
#else
	lea 0xF72,A0             // iorec RS232
#endif
	moveq #-1,D0             // OK
	moveq #0,D1
	moveq #0,D2
	move.w 22(A0),D1         // tail index
	addq.l #1,D1
	move.w 18(A0),D2         // size
	cmp.l D2,D1
	bcs.s .aos2
	moveq #0,D1
.aos2:
	move.w 20(A0),D2         // head index
	cmp.l D2,D1              // buffer full
	bne.s .aos1              // no
.aos3:
	moveq #0,D0
.aos1:
	tst.l D0
	rts

auxout:

	tst.b serial_mouse
	bne.s .ao1
	move.w 6(SP),D0
	bsr rs232put
	bcs.s auxout             // not send, try again
.ao1:
	rts

#ifdef MCF547X

rsconf:

	move.w 4(SP),D0          // baud
	move.w 6(SP),D1          // ctrl
	move.w 8(SP),D2          // ucr
	bra Rsconf

#endif
	
rs232put:

#ifdef MCF547X
	lea 0x165A,A0            // iorec RS232
#else
	lea 0xF72,A0             // iorec RS232
#endif
	move.w SR,D2
	move.l D2,-(SP)
	or.l #0x700,D2           // mask interrupts
	move.w D2,SR
	btst #0,32(A0)           // XON/XOFF
	beq.s .rp1               // no
	tst.b 31(A0)             // XON flag ?
	bne.s .rp2               // yes
.rp1:
	move.b MCF_UART_USR0,D1
	and.l #MCF_UART_USR_TXEMP,D1
	beq.s .rp2
	moveq #0,D2
	move.w 20(A0),D2         // head index
	moveq #0,D1
	move.w 22(A0),D1         // tail index
	cmp.l D2,D1
	bne.s .rp2               // data inside the buffer
	move.b D0,MCF_UART_UTB0  // data	
	bra.s .rp3
.rp2:	
	moveq #0,D1
	move.w 22(A0),D1         // tail index
	addq.l #1,D1
	move.w 18(A0),D2         // size
	cmp.l D2,D1
	bcs.s .rp4
	moveq #0,D1
.rp4:
	moveq #0,D2
	move.w 20(A0),D2         // head index
	cmp.l D2,D1
	beq.s .rp5               // buffer full
	move.l 14(A0),A2         // buffer
	move.b D0,(A2,D1.l)      // store data
	move.w D1,22(A0)         // tail index
	move.b psc_uimr,D0
	or.l #MCF_UART_UIMR_TXRDY,D0
	move.b D0,psc_uimr
	move.b D0,MCF_UART_UIMR0 // enable TX interrupt
.rp3:
#if 0
	btst #1,32(A0)           // RTS/CTS mode
	beq.s .rp6               // no
	moveq #MCF_UART_UOP1_RTS,D0
	move.b D0,MCF_UART_UOP10 // RTS on
.rp6:
#endif
	move.l (SP)+,D2
	move.w D2,SR
	moveq #0,D0
	add.l D0,D0              // carry to 0, OK
	rts
.rp5:	
#if 0
	btst #1,32(A0)           // RTS/CTS mode
	beq.s .rp7               // no
	moveq #MCF_UART_UOP1_RTS,D0
	move.b D0,MCF_UART_UOP10 // RTS on
.rp7:
#endif
	move.l (SP)+,D2
	move.w D2,SR		
	moveq #-1,D0
	add.l D0,D0              // carry to 1, no send
	rts
	
rs232get:

#ifdef MCF547X
	lea 0x165A,A0            // iorec RS232
#else
	lea 0xF72,A0             // iorec RS232
#endif
	move.w SR,D2
	move.l D2,-(SP)
	or.l #0x700,D2           // mask interrupts
	move.w D2,SR
	moveq #0,D1
	move.w 6(A0),D1          // head index
	moveq #0,D2
	move.w 8(A0),D2          // tail index
	cmp.l D2,D1
	beq.s .rg1               // bufer empty
	addq.l #1,D1
	moveq #0,D2
	move.w 4(A0),D2          // size
	cmp.l D2,D1
	bcs.s .rg2
	moveq #0,D1
.rg2:
	move.l (A0),A2           // buffer
	moveq #0,D0
	move.b (A2,D1.l),D0      // get data
	move.w D1,6(A0)          // head index
	moveq #0,D1              // OK
	bra.s .rg3
.rg1:
	moveq #-1,D1             // no receive
.rg3:
	move.l (SP)+,D2
	move.w D2,SR
	move.l D1,-(SP)
	btst #0,32(A0)           // XON/XOFF
	beq.s .rg4               // no
	tst.b 30(A0)             // XOFF flag
	beq.s .rg4               // no
	moveq #0,D1
	moveq #0,D2
	move.w 8(A0),D1          // tail index
	move.w 6(A0),D2          // head index
	cmp.l D2,D1              // head > tail ?
	bhi.s .rg5               // no
	moveq #0,D0
	move.w 4(A0),D0          // size
	add.l D0,D1
	sub.l D2,D1              // tail - head
.rg5:
	move.w 10(A0),D2         // low water
	cmp.l D2,D1
	bne.s .rg4
	moveq #17,D0             // XON
	bsr rs232put
.rg4:
	move.l (SP)+,D1
	add.l D1,D1              // carry flag
	rts
	
int_serial:

	lea -28(SP),SP
	movem.l D0-D3/A0-A2,(SP)
#ifdef MCF547X
	lea 0x165A,A0            // iorec RS232
#else
	lea 0xF72,A0             // iorec RS232
#endif
	move.b MCF_UART_UISR0,D3 // isr
	// receive data
	moveq #MCF_UART_UISR_RXRDY_FU,D0
	and.l D3,D0
	beq .is1
	moveq #MCF_UART_USR_RXRDY,D0
	move.b MCF_UART_USR0,D2  // status
	and.l D2,D0
	beq .is1
	move.b D2,28(A0)         // state receiver
	moveq #0,D0
	move.b MCF_UART_URB0,D0  // data
	moveq #0,D1
	move.b #MCF_UART_USR_RB,D1 // receive break
	and.l D2,D1
	bne.s .is9
	moveq #MCF_UART_USR_PE,D1 // parity error		
	and.l D2,D1
	bne.s .is9
	moveq #MCF_UART_USR_OE,D1 // overrun error
	and.l D2,D1
	bne.s .is9
	moveq #MCF_UART_USR_FE,D1 // framing error
	and.l D2,D1
	bne.s .is9
#if 0 // automatic
	btst #1,32(A0)           // RTS/CTS mode
	beq.s .is15              // no
	move.l D0,-(SP)
	moveq #MCF_UART_UOP0_RTS,D0
	move.b D0,MCF_UART_UOP00 // RTS off
	move.l (SP)+,D0
.is15:
#endif
	tst.b serial_mouse
	beq.s .is16
	tst.w type_serial_mouse
	beq .is1
	bsr get_serial_mouse
	bra .is1
.is16:	
	btst #1,32(A0)           // RTS/CTS mode
	bne.s .is5               // yes
	btst #0,32(A0)           // XON/XOFF
	beq.s .is5               // no
	cmp.l #17,D0             // XON
	bne.s .is10              // no
	clr.b 31(A0)             // clear XON flag
	bra .is1
.is10:
	cmp.l #19,D0             // XOFF
	bne.s .is5               // no
	moveq #-1,D0
	move.b D0,31(A0)         // set XON flag
	bra .is1
.is9:
	moveq #MCF_UART_UCR_RESET_ERROR,D0
	move.b D0,MCF_UART_UCR0
	bra .is1
.is5:
	moveq #0,D1
	move.w 8(A0),D1          // tail index
	addq.l #1,D1
	moveq #0,D2
	move.w 4(A0),D2          // size
	cmp.l D2,D1
	bcs.s .is6
	moveq #0,D1
.is6:
	move.w 6(A0),D2          // head index
	cmp.l D2,D1
	beq .is1
	move.l (A0),A2           // buffer
	move.b D0,(A2,D1.l)      // store data
#if 0 //#ifdef DEBUG
	bsr debug_display_char
#endif
	move.w D1,8(A0)          // tail index
	cmp.l D2,D1              // head > tail
	bhi.s .is7               // no
	moveq #0,D0
	move.w 4(A0),D0          // size
	add.l D0,D1
	sub.l D2,D1              // tail - head
.is7:
	move.w 12(A0),D2         // high water
	cmp.l D2,D1
	bne.s .is8
	btst #1,32(A0)           // RTS/CTS mode
	bne.s .is1               // yes
	btst #0,32(A0)           // XON/XOFF
	beq.s .is8               // no
	tst.b 30(A0)             // XOFF already send
	bne.s .is8
	moveq #-1,D0
	move.b D0,30(A0)         // set XOFF flag
	moveq #19,D0             // XOFF
	bsr rs232put
.is8:		                        
#if 0 // automatic
	btst #1,32(A0)           // RTS/CTS mode
	beq.s .is1               // no
	moveq #MCF_UART_UOP1_RTS,D0
	move.b D0,MCF_UART_UOP10 // RTS on
#endif
.is1:	// send data
	moveq #MCF_UART_UISR_TXRDY,D0
	and.l D3,D0
	beq.s .is2
	moveq #MCF_UART_USR_TXRDY,D0
	move.b MCF_UART_USR0,D2  // status
	and.l D2,D0
	beq.s .is2
	btst #1,32(A0)           // RTS/CTS mode
	bne.s .is2               // yes
	btst #0,32(A0)           // XON/XOFF
	beq.s .is3               // no
	tst.b 31(A0)             // XON flag ?
	bne.s .is2               // yes
.is3:		
	move.b D2,29(A0)         // state transmitter
	moveq #0,D2
	move.w 20(A0),D2         // head index
	moveq #0,D1
	move.w 22(A0),D1         // tail index
	cmp.l D2,D1
	beq.s .is11              // buffer empty
	addq.l #1,D1
	move.w 18(A0),D2         // size
	cmp.l D2,D1
	bcs.s .is4
	moveq #0,D1
.is4:
	move.l 14(A0),A2         // buffer
	move.b (A2,D1.l),D0      // get data
	move.b D0,MCF_UART_UTB0  // data
	move.w D1,20(A0)         // head index
	bra.s .is2
.is11:
	move.b psc_uimr,D0
	and.l #~MCF_UART_UIMR_TXRDY,D0
	move.b D0,psc_uimr
	move.b D0,MCF_UART_UIMR0 // disable TX interrupt
.is2:
#if 0 // automatic
	// CTS interrupt
	moveq #0,D0
	move.b #MCF_UART_UISR_COS,D0
	and.l D3,D0
	beq.s .is14
	moveq #MCF_UART_UIPCR_CTS,D1
	move.b MCF_UART_UIPCR0,D0
	and.l D1,D0
	beq.s .is14
	btst #1,32(A0)           // RTS/CTS mode
	beq.s .is14              // yes
.is13:
	move.b MCF_UART_USR0,D2
	moveq #MCF_UART_USR_TXEMP,D0
	and.l D2,D0
	beq.s .is13
	move.b D2,29(A0)         // state transmitter
	moveq #0,D2
	move.w 20(A0),D2         // head index
	moveq #0,D1
	move.w 22(A0),D1         // tail index
	cmp.l D2,D1
	beq.s .is14              // buffer empty
	addq.l #1,D1
	move.w 18(A0),D2         // size
	cmp.l D2,D1
	bcs.s .is12
	moveq #0,D1
.is12:
	move.l 14(A0),A2         // buffer
	move.b (A2,D1.l),D0      // get data
	move.b D0,MCF_UART_UTB0  // data
	move.w D1,20(A0)         // head index
.is14:
#endif
	movem.l (SP),D0-D3/A0-A2
	lea 28(SP),SP
	rte
	
setrts: // d0.w state 0/1

	tst.w D0
	beq.s .clear_rts
	moveq #MCF_UART_UOP1_RTS,D0
	move.b D0,MCF_UART_UOP10
	rts
.clear_rts:	
	moveq #MCF_UART_UOP0_RTS,D0
	move.b D0,MCF_UART_UOP00
	rts

Rsconf: // D0.W: baud, D1.W: ctrl, D2.W: ucr

#ifdef DEBUG
	lea debug4(PC),A0
	bsr debug_display_string	
#endif
	clr.b serial_mouse
	move.l D4,-(SP)
	move.l D3,-(SP)
#ifdef MCF547X
	lea 0x165A,A0            // iorec RS232
#else
	lea 0xF72,A0             // iorec RS232
#endif
	move.w SR,D3
	move.l D3,-(SP)
	or.l #0x700,D3           // mask interrupts
	move.w D3,SR
	tst.w D1
	bmi .set_baud
	tst.w D2
	bmi .set_baud
	move.b D1,32(A0)         // rsmode
	moveq #MCF_UART_UCR_RESET_TX,D3
	move.b D3,MCF_UART_UCR0  // Reset Transmitter
	moveq #MCF_UART_UCR_RESET_RX,D3
	move.b D3,MCF_UART_UCR0  // Reset Receiver
	moveq #MCF_UART_UCR_RESET_MR,D3
	move.b D3,MCF_UART_UCR0  // Reset Mode Register
	moveq #MCF_UART_UMR_PM_NONE,D3	
	btst #2,D2
	beq.s .parity_bits
	moveq #MCF_UART_UMR_PM_ODD,D3
	btst #1,D2
	beq.s .parity_bits
	moveq #MCF_UART_UMR_PM_EVEN,D3
.parity_bits:
	move.l D2,D4
	lsr.l #6,D4
	and.l #3,D4
	beq.s .bits_8
	cmp.l #1,D4
	beq.s .bits_7
	cmp.l #2,D4
	beq.s .bits_6
	or.l #MCF_UART_UMR_BC_5,D3	
	bra.s .set_bits
.bits_6:
	or.l #MCF_UART_UMR_BC_6,D3	
	bra.s .set_bits
.bits_7:
	or.l #MCF_UART_UMR_BC_7,D3	
	bra.s .set_bits	
.bits_8:
	or.l #MCF_UART_UMR_BC_8,D3
.set_bits:
	btst #1,D1               // CTS / RTS
	beq.s .no_cts_rts
	or.l MCF_UART_UMR_RXRTS,D3
.no_cts_rts:
	move.b D3,MCF_UART_UMR0
	lsr.l #3,D2
	and.l #3,D2              // ucr
	moveq #MCF_UART_UMR_SB_STOP_BITS_1,D3
	cmp.l #1,D2
	bls.s .stop_bits
	moveq #MCF_UART_UMR_SB_STOP_BITS_15,D3
	cmp.l #2,D2
	beq.s .stop_bits
	moveq #MCF_UART_UMR_SB_STOP_BITS_2,D3
.stop_bits:
	or.l #MCF_UART_UMR_CM_NORMAL,D3
	btst #1,D1               // CTS / RTS
	beq.s .no_cts_rts2
	or.l #MCF_UART_UMR_TXCTS + MCF_UART_UMR_TXRTS,D3
.no_cts_rts2:		
	move.b D3,MCF_UART_UMR0
.set_baud:
	tst.w D0
	bmi.s .end_rsconf
	/* Set Rx and Tx baud by timer */
	move.b #MCF_UART_UCSR_RCS_SYS_CLK + MCF_UART_UCSR_TCS_SYS_CLK,D2
	move.b D2,MCF_UART_UCSR0
	/* Calculate baud settings */
	lea tab_baudrate(PC),A0
	and.l #0xF,D0
	asl.l #2,D0
	move.l (A0,D0.l),D0
	move.l #SYSTEM_CLOCK*1000000,D2
	asl.l #4,D0              // * 16, baud
	.chip 68060
	divu.l D0,D2             // ubgs
	.chip 5200
	lsr.l #1,D2              // 2
	bcc.s .set_speed
	addq.l #1,D2
.set_speed:	
	move.l D2,D0
	lsr.l #8,D0
	move.b D0,MCF_UART_UBG10
	move.b D2,MCF_UART_UBG20
.end_rsconf:
	/* Enable receiver and transmitter */
	moveq #MCF_UART_UCR_TX_ENABLED + MCF_UART_UCR_RX_ENABLED,D0
	move.b D0,MCF_UART_UCR0
	move.l (SP)+,D3
	move.w D3,SR
	move.l (SP)+,D3
	move.l (SP)+,D4
#ifdef DEBUG
	lea debug4(PC),A0
	bsr debug_display_string	
#endif
	rts

tab_baudrate:
	dc.l 19200,9600,4800,3600,2400,2000,1800,1200,600,300
	//      200,   150,  134,  110,    75,   50
	dc.l 230400,115200,57600,38400,153600,76800

ikbd_codes:	dc.b 1,2,3,3,3,3,4,5,6,7

ikbd_length:	dc.b 7,5,2,2,2,2,6,2,1,1

arcvint:

	moveq #0,D0
	move.b 2(A1),D0
	cmp.l #0xF96,A0        // iorec keyboard
	bne.s .av1             // iorec MIDI
	tst.b 0x115A           // state keyboard
	bne.s .av5
	cmp.l #0xF6,D0         // key pressed ?
	bcc.s .av2             // no
//	move.l 0x1132,-(SP)    // yes (ikbdvect by default)
	pea ikbdvect(PC)
	rts
.av1:
	move.l 0x1136,-(SP)    // MIDI 
	rts                    // (sysmidi by default)
.av2:
	sub.l #0xF6,D0
	and.l #0xFF,D0
	lea ikbd_codes(PC),A3  // IKBD codes table
	move.b (A3,D0.l),D1
	move.b D1,0x115A
	lea ikbd_length(PC),A3 // IKBD length table
	move.b (A3,D0.l),D1
	move.b D1,0x115B
	add.l #0xF6,D0
	cmp.l #0xF8,D0         // mouse position ?
	blt.s .av3             // no
	cmp.l #0xFB,D0
	bgt.s .av3             // no
	move.b D0,0x116A
	rts
.av3:
	cmp.l #0xFD,D0         // joystick ?
	blt.s .av4
	move.b D0,0x1173
.av4:
	rts
.av5:
	moveq #0,D1
	move.b 0x115A,D1       // joystick record ?
	cmp.l #6,D1
	bcc.s .av7             // yes
	lea 0xE033B4,A2        // IKBD parameters
	move.l D1,D2
	subq.l #1,D2
	add.l D2,D2
	add.l D1,D2
	subq.l #1,D2
	asl.l #2,D2
	move.l (A2,D2.l),A0    // IKBD record pointer
	move.l 4(A2,D2.l),A1   // index IKBD
	move.l 8(A2,D2.l),A2   // interrupt routine
	move.l (A2),A2         // interrupt vector
	moveq #0,D2
	move.b 0x115B,D2       // index IKBD
	sub.l D2,A1
	move.b D0,(A1)
	subq.l #1,D2
	move.b D2,0x115B       // index IKBD
	beq.s .av6
	rts
.av7:
	moveq #0,D1
	move.b 0x115A,D1
	add.l #0x1174,D1
	subq.l #6,D1
	move.l D1,A2
	move.b D0,(A2)
	move.l 0x114E,A2       // joystick interrupt routine
	lea 0x1173,A0          // joystick datas
.av6:
	move.l A0,-(SP)
	jsr (A2)               // interrupt routine
	addq.l #4,SP
	clr.b 0x115A
	rts

ikbdvect:	

	bsr new_ikbdvect       // Eiffel keys
	bne.s .iv2             // <> LEFT SHIFT
	bset #1,D1
	bra .iv1
.iv2:
	cmp.l #0xAA,D0
	bne.s .iv3
	bclr #1,D1
	bra .iv1
.iv3:
	cmp.l #0x36,D0         // RIGHT SHIFT
	bne.s .iv4
	bset #0,D1
	bra .iv1
.iv4:
	cmp.l #0xB6,D0
	bne.s .iv5
	bclr #0,d1
	bra .iv1
.iv5:
	cmp.l #0x1D,D0         // CTRL
	bne.s .iv6
	bset #2,D1
	bra .iv1
.iv6:
	cmp.l #0x9D,D0
	bne.s .iv7
	bclr #2,D1
	bra .iv1
.iv7:
	cmp.l #0x38,D0         // ALT
	bne.s .iv8
	bset #3,D1
	bra .iv1
.iv8:
	cmp.l #0xB8,D0
	bne.s .iv9
	bclr #3,D1
	tst.w 0x115C
	bmi.s .iv1
	move.b D1,0x1187
	move.l A0,-(SP)
	moveq #0,D0
	move.b 0x115D,D0
	moveq #-1,D1
	move.w D1,0x115C
	moveq #0,D1
	bra .iv20
.iv9:
	cmp.l #0x3A,D0         // CAPS LOCK
	bne.s .iv10
	move.b conterm,D2
	btst.b #0,D2
	beq.s .iv11
	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
#if 0
	move.l _kcl_hook,A0
	jsr (A0)
#else
	move.l #0xE4A934,D0
	move.l D0,0x11BC       // sound pointer
	clr.b 0x11C0           // delay timer
#endif
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
.iv11:
	bchg #4,D1
.iv1:
	move.b D1,0x1187
	rts
.iv10:
	btst #7,D0
	bne.s .iv12
	move.b D0,0x11B1
	move.b 0x11B4,D0
	move.b D0,0x11B2
	move.b 0x11B5,D0
	move.b D0,0x11B3
	move.b 0x11B1,D0
	bra.s ikbdvect2
.iv12:
	move.l D0,D1
	bclr #0x7,D1
	move.l D0,-(SP)
	move.b 0x11B1,D0
	cmp.l D1,D0
	bne.s .iv13
	moveq #0,D1
	move.b D1,0x11B1
	move.b D1,0x11B2
	move.b D1,0x11B3
.iv13:
	move.l (SP)+,D0
	cmp.l #0xC7,D0         // HOME
	beq.s .iv14
	cmp.l #0xD2,D0         // INSERT
	bne .iv21
.iv14:
	move.b 0x1187,D2
	btst #3,D2             // ALT
	beq .iv21
ikbdvect2:
	move.b conterm,D2
	btst #0,D2
	beq.s .iv15
	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
#if 0
	move.l _kcl_hook,A0
	jsr (A0)
#else
	move.l #0xE4A934,D0
	move.l D0,0x11BC       // sound pounter
	clr.b 0x11C0           // delay timer
#endif
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
.iv15:
	move.l A0,-(SP)
	moveq #0,D1
	move.b D0,D1
	move.l 0x1188,A0       // table unshift
	and.l #0x7F,D0
	move.b 0x1187,D2
	btst #4,D2             // CAPS LOCK
	beq.s .iv16
	move.l 0x1190,A0       // table capslock
.iv16:
	btst #0,D2             // RIGHT SHIFT
	bne.s .iv17
	btst #1,D2             // LEFT SHIFT
	beq.b .iv18
.iv17:
	cmp.l #0x3B,D0         // F1
	bcs.s .iv19
	cmp.l #0x44,D0         // F10
	bhi.s .iv19
	add.l #0x19,D1
	moveq #0,D0
	bra .iv20
.iv19:
	move.l 0x118C,A0       // table shift
.iv18:
	move.b (A0,D0.l),D0
	btst #2,D2             // CTRL
	beq.s .iv22
	cmp.l #0xD,D0
	bne.s .iv23
	moveq #0xA,D0
.iv23:
	cmp.l #0x47,D1         // HOME
	bne.s .iv24
	add.l #0x30,D1
	bra .iv20
.iv24:
	cmp.l #0x4B,D1         // <-
	bne.s .iv25
	moveq #0x73,D1
	moveq #0,D0
	bra .iv20
.iv25:
	cmp.l #0x4D,D1         // ->
	bne.s .iv26
	moveq #0x74,D1
	moveq #0,D0
	bra .iv20
.iv26:
	cmp.l #0x32,D0
	bne.s .iv27
	moveq #0,D0
	bra .iv20
.iv27:
	cmp.l #0x36,D0
	bne.s .iv28
	moveq #0x1E,D0
	bra .iv20
.iv28:
	cmp.l #0x2D,D0
	bne.s .iv22
	moveq #0x1F,D0
	bra .iv20
.iv22:
	btst #3,D2             // ALT pressed ?
	beq .iv29
	cmp.l #0x67,D1
	bcs.s .iv30
	cmp.l #0x70,d1
	bhi.s .iv30
	move.w 0x115C,D0
	bpl.s .iv31
	moveq #0,D0
.iv31:
	mulu.w #10,D0
	move.b (A0,D1.l),D1
	sub.l #0x30,D1
	add.l D1,D0
	move.w d0,0x115C
	move.l (SP)+,A0
	rts
.iv30:
	move.l 0x1194,A0
	move.b 0x1187,D2
	and.l #0x3,D2          // SHIFTs
	beq.s .iv32
	move.l 0x1198,A0
	bra.s .iv33
.iv32:
	move.b 0x1187,D2
	btst #0x4,D2           // CAPS LOCK
	beq.s .iv33
	move.l 0x119C,A0
	moveq #0,D2
.iv33:
		tst.b (A0)
		beq.s .iv34
		move.b (A0),D2
		cmp.l D2,D1
	addq.l #2,A0
	bne.s .iv33
	move.b -(a0),D0
	bra .iv29
.iv34:
	cmp.l #0x62,D1         // ALT HELP
	bne.s .iv35
	move.w _dumpflg,D0     // dump flag for hardcopy
	addq.l #1,D0
	move.w D0,_dumpflg
	move.l (SP)+,A0
	bra .iv21
.iv35:
	cmp.l #0x47,D1
	beq keymaus1
	cmp.l #0xC7,D1
	beq keymaus1
	cmp.l #0x52,D1
	beq keymaus1
	cmp.l #0xD2,D1
	beq keymaus1
	cmp.l #0x48,D1         // ^
	bne.s .iv36
	moveq #0,D1
	moveq #-8,D2
	move.b 0x1187,D0
	and.l #3,D0
	beq keymaus
	moveq #-1,D2
	bra keymaus
.iv36:
	cmp.l #0x4B,D1         // <-
	bne.s .iv37
	moveq #0,D2
	moveq #-8,D1
	move.b 0x1187,D0
	and.l #3,D0
	beq keymaus
	moveq #-1,D1
	bra keymaus
.iv37:
	cmp.l #0x4D,D1         // ->
	bne.s .iv38
	moveq #8,D1
	moveq #0,D2
	move.b 0x1187,d0
	and.l #3,D0
	beq keymaus
	moveq #1,D1
	bra keymaus
.iv38:
	cmp.l #0x50,D1         // v
	bne.s .iv39
	moveq #0,D1
	moveq #8,D2
	move.b 0x1187,D0
	and.l #3,D0
	beq keymaus
	moveq #1,D2
	bra.w keymaus
.iv39:
	move.b 0x1187,D2
	btst #2,D2            // CTRL
	bne.s .iv40
	cmp.l #2,D1
	bcs.s .iv41
	cmp.l #0xD,D1
	bhi.s .iv41
	add.l #0x76,D1
	bra.s .iv42
.iv41:
	cmp.l #0x41,D0        // A
	bcs.s .iv43
	cmp.l #0x5A,D0        // Z
	bhi.s .iv43
.iv42:
	moveq #0,D0
	bra.b .iv20
.iv43:
	cmp.l #0x61,D0         // a
	bcs.s .iv20
	cmp.l #0x7A,D0         // z
	bhi.s .iv20
	bra.s .iv42
.iv29:
	move.b 0x1187,D2
	btst #2,D2             // CTRL
	beq.s .iv20
.iv40:
	and.l #0x1F,D0
.iv20:
	asl.l #8,D1
	add.l D1,D0
	move.l (SP)+,A0        // iorec pointer
	moveq #0,D1
	move.w 8(A0),D1        // tail index
	addq.l #4,D1
	moveq #0,D2
	move.w 4(A0),D2        // buffer size
	cmp.l D2,D1
	bcs.s .iv44
	moveq #0,d1
.iv44:
	move.w 6(A0),D2        // head index
	cmp.l D2,D1
	beq.s .iv21
	move.l (A0),A2         // iorec buffer
	swap D0
	clr.w D0
	move.b 0x1187,D0
	swap D0
	lsl.l #8,D0
	move.l D0,D2
	lsr.l #8,D2
	and.l #0xFF,D2
	move.w D2,D0
	move.l D0,D2
	bclr #28,D2
	clr.w D2
	swap D2
	cmp.l #0xC53,D2        // CTRL ALT DEL
	beq.s .watchdog_reset
//	bne.s .iv45
//	jmp 0xE00030           // reset
//.iv45:
	cmp.l #0xD53,D2        // CTRL ALT LEFT-SHIFT DEL
	bne.s .iv46
	clr.l memvalid
//	jmp 0xE0398C           // cold reset
	bra.s .watchdog_reset
.iv46:
	move.b conterm,D2
	btst #3,D2
	bne.s .iv47
	and.l #0xFFFFFF,D0
.iv47:
	and.l #0xFFFF,D1
	move.l D0,(A2,D1)      // write datas inside buffer
	move.w D1,8(A0)        // update tail index
.iv21:
	rts

.watchdog_reset:

	move.w #0x2700,SR
	jsr disable_interrupts
#ifdef MCF5445X
  	move.w #SCM_CWCR_CWE + SCM_CWCR_CWRI(2) + SCM_CWCR_CWT(8),D0
  	move.w D0,MCF_SCM_CWCR
#else /* MCF548X */
	clr.l MCF_GPT_GMS0 
	move.w #SYSTEM_CLOCK,D0
	swap D0
#ifdef DEBUG
	move.w #-1,D0 // 65535 uS
#else
	move.w #10,D0 // 10 uS
#endif
	move.l D0,MCF_GPT_GCIR0
	move.l #MCF_GPT_GMS_TMS_GPIO + MCF_GPT_GMS_CE + MCF_GPT_GMS_WDEN,D0
	move.l D0,MCF_GPT_GMS0 // reset watchdog
#endif /* MCF5454X */
.wait_reset_board:
	nop
	moveq #0x2E,D0
	move.b D0,MCF_UART_UTB0
	bra.s .wait_reset_board

keymaus1:

	moveq #5,D3
	btst #4,D1
	beq.s .km1
	moveq #6,D3
.km1:
	btst #7,D1
	beq.s .km2
	bclr D3,0x1187
	bra.s .km3
.km2:
	bset D3,0x1187
.km3:
	moveq #0,D1
	moveq #0,D2

keymaus:

	lea 0x1184,A0
	move.l 0x1146,A2
	moveq #0,D0
	move.b 0x1187,D0
	lsr.l #5,D0
	add.l #0xF8,D0
	move.b D0,(A0)
	move.b D1,1(A0)
	move.b D2,2(A0)
	jsr (A2)
	move.l (SP)+,A0
	rts

#ifdef MCF5445X /* use the MCF5445X UART2 for the IKBD at 7812.5 bauds */

int_ikbd:

	link A6,#-4
	lea -56(SP),SP
	movem.l D0-A5,(SP)
	moveq #MCF_UART_USR_RXRDY,D0
	move.b MCF_UART_USR2,D2  // status
	and.l D2,D0
	beq.s .ik1
	moveq #0,D0
	move.b MCF_UART_URB2,D0  // data
	moveq #0,D1
	move.b #MCF_UART_USR_RB,D1 // receive break
	and.l D2,D1
	bne.s .ik2
	moveq #MCF_UART_USR_PE,D1 // parity error		
	and.l D2,D1
	bne.s .ik2
	moveq #MCF_UART_USR_OE,D1 // overrun error
	and.l D2,D1
	bne.s .ik2
	moveq #MCF_UART_USR_FE,D1 // framing error
	and.l D2,D1
	bne.s .ik2
	lea 0xF96,A0             // iorec keyboard
	lea -4(A6),A1            // data - 2 for arcvint
	move.b D0,2(A1)          // data
	bsr arcvint              // 0xE032EC
	bra.s .ik1
.ik2:
	moveq #MCF_UART_UCR_RESET_ERROR,D0
	move.b D0,MCF_UART_UCR2
.ik1:
	movem.l (SP),D0-A5
	lea 56(SP),SP
	unlk A6
	rte

ikbd_init: /* MCF5445X */

#ifdef DEBUG
	lea debug48(PC),A0
	bsr debug_display_string	
#endif
	moveq #MCF_UART_UCR_RESET_TX,D0
	move.b D0,MCF_UART_UCR2  // Reset Transmitter
	moveq #MCF_UART_UCR_RESET_RX,D0
	move.b D0,MCF_UART_UCR2  // Reset Receiver
	moveq #MCF_UART_UCR_RESET_MR,D0
	move.b D0,MCF_UART_UCR2  // Reset Mode Register
	moveq #MCF_UART_UMR_PM_NONE + MCF_UART_UMR_BC_8,D0
	move.b D0,MCF_UART_UMR2
	moveq #MCF_UART_UMR_CM_NORMAL + MCF_UART_UMR_SB_STOP_BITS_1,D0
	move.b D0,MCF_UART_UMR2
	/* Set Rx and Tx baud by timer */
	move.b #MCF_UART_UCSR_RCS_SYS_CLK + MCF_UART_UCSR_TCS_SYS_CLK,D0
	move.b D0,MCF_UART_UCSR2
	move.l #(SYSTEM_CLOCK*1000000)/250000,D1 // 7812.5 bauds * 32
	move.l D1,D0	            // ubgs
	lsr.l #8,D0
	move.b D0,MCF_UART_UBG12
	move.b D1,MCF_UART_UBG22
	/* Enable receiver and transmitter */
	moveq #MCF_UART_UCR_TX_ENABLED + MCF_UART_UCR_RX_ENABLED,D0
	move.b D0,MCF_UART_UCR2
	lea int_ikbd(PC),A0
	move.l A0,(64+INT0_LO_UART2+OFFSET_INT_CF68KLIB)*4
	moveq #6,D0              // level 6
	move.b D0,MCF_INTC_ICR0+INT0_LO_UART2
	move.l #~INTC_IMRL_INT_MASK28,D0
	and.l D0,MCF_INTC_IMRL0
	moveq #MCF_UART_UIMR_RXRDY_FU,D0
	move.b D0,MCF_UART_UIMR2 // enable RX interrupts
	rts

#else
#ifdef MCF547X

#if 0
int_ikbd:	// Eiffel

	link A6,#-4
	lea -56(SP),SP
	movem.l D0-A5,(SP)
	moveq #MCF_UART_USR_RXRDY,D0
	move.b MCF_UART_USR1,D2  // status
	and.l D2,D0
	beq.s .ik1
	moveq #0,D0
	move.b MCF_UART_URB1,D0  // data
	moveq #0,D1
	move.b #MCF_UART_USR_RB,D1 // receive break
	and.l D2,D1
	bne.s .ik2
	moveq #MCF_UART_USR_PE,D1 // parity error		
	and.l D2,D1
	bne.s .ik2
	moveq #MCF_UART_USR_OE,D1 // overrun error
	and.l D2,D1
	bne.s .ik2
	moveq #MCF_UART_USR_FE,D1 // framing error
	and.l D2,D1
	bne.s .ik2
	lea 0xF96,A0             // iorec keyboard
	lea -4(A6),A1            // data - 2 for arcvint
	move.b D0,2(A1)          // data
	bsr arcvint              // 0xE032EC
             bra.s .ik1
.ik2:
	moveq #MCF_UART_UCR_RESET_ERROR,D0
	move.b D0,MCF_UART_UCR1
.ik1:
	movem.l (SP),D0-A5
	lea 56(SP),SP
	unlk A6
	rte
#endif

int6_mfp:

//	move.w #0x2700,SR
	move.l TIMER_C_VEC,-(SP) // TOS404 0xE03C50
	move.l D0,-(SP)
	move.l MCF_INTC_INTFRCL,D0
	and.l #MCF_INTC_INTFRCL_INTFRC6,D0
	bne .int6_forced
	// normal INT6
	moveq #6,D0
	bset.b D0,MCF_EPORT_EPFR // clear interrupt
	move.l D1,-(SP)
	moveq #0,D1
	move.b 0xFFFFFA13,D1     // MFP IMRA (FPGA emulation)
	asl.l #8,D1
	move.b 0xFFFFFA15,D1     // MFP IMRB (FPGA emulation)
	move.b 0xFFFFFA0B,D0     // MFP IPRA (FPGA emulation)
	asl.l #8,D0
	move.b 0xFFFFFA0D,D0     // MFP IPRB (FPGA emulation)
#if 0
	move.l D0,-(SP)
#if 1
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	move.w D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	move.l ACP_INTERRUPT_PENDING,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l ACP_INTERRUPT_ENABLE,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#else	
	moveq #0x4D,D0
	move.b D0,MCF_UART_UTB0
	move.l (SP),D0
	lsr.l #2,D0
	and.l #0xF,D0
	add.l #0x30,D0
	move.b D0,MCF_UART_UTB0
	moveq #0x20,D0
	move.b D0,MCF_UART_UTB0
#endif
	move.l (SP)+,D0
#endif
	and.l D1,D0
	move.l (SP)+,D1
	tst.l D0
	beq.s .is_not_mfp
	move.l ACP_MFP_INTACK_VECTOR,D0 // (MFP vector base register + MFP int channel) * 4
	and.l #0x3FC,D0
	cmp.l #0x100,D0
	bcs.s .is_not_mfp
	cmp.l #PSEUDO_DMA_VEC,D0
	bhi.s .is_not_mfp
	cmp.l #IKBD_VEC,D0
	bne.s .int_mfp_ok
	tst.b stop_mfp_ikbd
	beq.s .int_mfp_ok
	move.l A0,-(SP)          // IKBD not connected, avoid null bytes
	lea 0xFFFFFA01,A0        // MFP (FPGA emulation)
	bclr #6,20(A0)           // IMRB I/O bit 4, stop interrupt
	bclr #6,8(A0)            // IERB
	bclr #6,12(A0)           // IPRB
	bclr #6,16(A0)           // ISRB
	move.l (SP)+,A0
.is_not_mfp:
	move.l (SP)+,D0
	rts
.int_mfp_ok:
	move.l A0,-(SP)
	move.l D0,A0
#if 0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l (A0),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	move.l (A0),8(SP)        // move vector content to return address
	move.l (SP)+,A0
	move.l (SP)+,D0
	rts                      // jump to MFP vector
.int6_forced:                         // forced by rtos
	move.l #~MCF_INTC_INTFRCL_INTFRC6,D0
	and.l D0,MCF_INTC_INTFRCL
	move.l (SP)+,D0
	rts                      // jump to original timer C interrupt

int_pseudo_dma:

	move.l A1,-(SP)
	move.l A0,-(SP)
	move.l D0,-(SP)
.ipd1:
		lea ACP_FIFO_PSEUDO_DMA,A0
		move.l -12(A0),A1 // dma address
   		move.l -8(A0),D0  // byte counter
		ble.s .ipd5       // err
		btst #0,-16(A0)   // write?
		bne.s .ipd4       // write line
		// read line
.ipd3:
			btst #7,-4(A0)
			beq.s .ipd2
			move.l (A0),(A1)+ // read 4 bytes	 
			move.l (A0),(A1)+ // read 4 bytes	 
			move.l (A0),(A1)+ // read 4 bytes	 
			move.l (A0),(A1)+ // read 4 bytes
		sub.l #16,D0
		bgt.s .ipd3
		bra.s .ipd2
		// write line
.ipd4:
			btst #7,-4(A0)
			beq.s .ipd2
			move.l (A1)+,(A0) // write 4 bytes
			move.l (A1)+,(A0) // write 4 bytes
			move.l (A1)+,(A0) // write 4 bytes
			move.l (A1)+,(A0) // write 4 bytes
		sub.l #16,D0
		bgt.s .ipd4
.ipd2:
		move.l A1,-12(A0) // dma address
		move.l D0,-8(A0)  // byte counter
		lea 0xFFFFFA01,A0 // MFP (FPGA emulation)
	btst #7,(A0)                   // GPIP
	beq .ipd1
.ipd5:
	bclr #7,14(A0)                 // ISRA clear interrupt
	move.l (SP)+,D0
	move.l (SP)+,A0
	move.l (SP)+,A1
	rte

pseudo_dma_init: /* MCF547X */

	lea int_pseudo_dma(PC),A0
	move.l A0,PSEUDO_DMA_VEC // MFP I/O bit 7
	lea 0xFFFFFA01,A0        // MFP (FPGA emulation)
	bset #7,6(A0)            // IERA I/O bit 7
	bset #7,18(A0)           // IMRA I/O bit 7 enable interrupt
	rts

int_mfp_ikbd:

	link A6,#-4
	lea -56(SP),SP
	movem.l D0-A5,(SP)
	move.b 0xFFFFFC00,D0     // ACIA IKBD
	move.b D0,D2
	btst #7,D0
	beq.s .imk1              // not interrupt request
	btst #0,D0
	beq.s .imk2              // receiver empty
	move.b 0xFFFFFC02,D0     // read data
	lea 0xF96,A0             // iorec keyboard
	lea -4(A6),A1            // data - 2 for arcvint
	move.b D0,2(A1)          // data
	move.l D2,-(SP)
	bsr arcvint              // 0xE032EC
	move.l (SP)+,D2
.imk2:
	btst #5,D2
	beq.s .imk1              // no error
	move.b 0xFFFFFC02,D0     // read data
.imk1:
	lea 0xFFFFFA01,A0        // MFP (FPGA emulation)		
	bclr #6,16(A0)           // ISRB clear interrupt
	movem.l (SP),D0-A5
	lea 56(SP),SP
	unlk A6
	rte

ikbd_init: /* MCF547X */

#ifdef DEBUG
	lea debug48(PC),A0
	bsr debug_display_string	
#endif
#if 0
	/* PSC1 - Eiffel */
	moveq #MCF_UART_UCR_RESET_TX,D0
	move.b D0,MCF_UART_UCR1  // Reset Transmitter
	moveq #MCF_UART_UCR_RESET_RX,D0
	move.b D0,MCF_UART_UCR1  // Reset Receiver
	moveq #MCF_UART_UCR_RESET_MR,D0
	move.b D0,MCF_UART_UCR1  // Reset Mode Register
	moveq #MCF_UART_UMR_PM_NONE + MCF_UART_UMR_BC_8,D0
	move.b D0,MCF_UART_UMR1
	moveq #MCF_UART_UMR_CM_NORMAL + MCF_UART_UMR_SB_STOP_BITS_1,D0
	move.b D0,MCF_UART_UMR1
	/* Set Rx and Tx baud by timer */
	move.b #MCF_UART_UCSR_RCS_SYS_CLK + MCF_UART_UCSR_TCS_SYS_CLK,D0
	move.b D0,MCF_UART_UCSR1
	move.l #(SYSTEM_CLOCK*1000000)/250000,D1 // 7812.5 bauds * 32
	move.l D1,D0	            // ubgs
	lsr.l #8,D0
	move.b D0,MCF_UART_UBG11
	move.b D1,MCF_UART_UBG21
	/* Enable receiver and transmitter */
	moveq #MCF_UART_UCR_TX_ENABLED + MCF_UART_UCR_RX_ENABLED,D0
	move.b D0,MCF_UART_UCR1
	lea int_ikbd(PC),A0
	move.l A0,(64+34+OFFSET_INT_CF68KLIB)*4 // PSC1
	moveq #0x24,D0           // level 4, priority 4
	move.b D0,MCF_INTC_ICR34
	move.l #~MCF_INTC_IMRH_INT_MASK32,D0
	and.l D0,MCF_INTC_IMRH
	moveq #MCF_UART_UIMR_RXRDY_FU,D0
	move.b D0,MCF_UART_UIMR1 // enable RX interrupts
#endif
	/* INT6 - MFP level 6 */
	moveq #3,D0
	move.b D0,0xFFFFFC00     // reset ACIA IKBD
	move.b #0x96,D0
	move.b D0,0xFFFFFC00     // / 64, 8 bits, 1 stop, no parity
	lea int_mfp_ikbd(PC),A0
	move.l A0,IKBD_VEC       // MFP I/O bit 4
	lea 0xFFFFFA01,A0        // MFP (FPGA emulation)
	bset #6,8(A0)            // IERB I/O bit 4
	bset #6,20(A0)           // IMRB I/O bit 4 enable interrupt
	rts

int_rtc:

	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
	moveq #MCF_UART_USR_RXRDY,D0
	move.b MCF_UART_USR3,D2  // status
	and.l D2,D0
	beq .ir1
	moveq #0,D0
	move.b MCF_UART_URB3,D0  // data
	moveq #0,D1
	move.b #MCF_UART_USR_RB,D1 // receive break
	and.l D2,D1
	bne.s .ir2
	moveq #MCF_UART_USR_PE,D1 // parity error		
	and.l D2,D1
	bne.s .ir2
	moveq #MCF_UART_USR_OE,D1 // overrun error
	and.l D2,D1
	bne.s .ir2
	moveq #MCF_UART_USR_FE,D1 // framing error
	and.l D2,D1
	bne.s .ir2
	cmp.l #2,D0              // need RTC data
	bne.s .ir1
.ir4:
	move.b MCF_UART_USR3,D0
	and.l #MCF_UART_USR_TXEMP,D0
	beq.s .ir4               // full
	move.b #0x82,D0          // header
	move.b D0,MCF_UART_UTB3  // data	
	moveq #0,D1
	lea 0xFFFF8961,A1        // F030 RTC (offset 0) / NVM (offset 14) - FPGA emulation
	lea 0xFFFF8963,A2
.ir3:
		move.b MCF_UART_USR3,D0
		and.l #MCF_UART_USR_TXEMP,D0
		beq.s .ir3     // full
		move.b D1,(A1) // index
		move.b (A2),D0 // data
		move.b D0,MCF_UART_UTB3  // send data
		addq.l #1,D1
	cmp.l #64,D1
	bcs.s .ir3	
	bra.s .ir1
.ir2:
	moveq #MCF_UART_UCR_RESET_ERROR,D0
	move.b D0,MCF_UART_UCR3
.ir1:
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	rte
	
rtc_init: /* MCF547X - FIREBEE */

#ifdef DEBUG
	lea debug49(PC),A0
	bsr debug_display_string	
#endif
	link A6,#-66
	moveq #MCF_UART_UCR_RESET_TX,D0
	move.b D0,MCF_UART_UCR3  // Reset Transmitter
	moveq #MCF_UART_UCR_RESET_RX,D0
	move.b D0,MCF_UART_UCR3  // Reset Receiver
	moveq #MCF_UART_UCR_RESET_MR,D0
	move.b D0,MCF_UART_UCR3  // Reset Mode Register
	moveq #MCF_UART_UMR_PM_NONE + MCF_UART_UMR_BC_8,D0
	move.b D0,MCF_UART_UMR3
	moveq #MCF_UART_UMR_CM_NORMAL + MCF_UART_UMR_SB_STOP_BITS_1,D0
	move.b D0,MCF_UART_UMR3
	/* Set Rx and Tx baud by timer */
	move.b #MCF_UART_UCSR_RCS_SYS_CLK + MCF_UART_UCSR_TCS_SYS_CLK,D0
	move.b D0,MCF_UART_UCSR3
	move.l #(SYSTEM_CLOCK*1000000)/(115200*32),D1 // 115200 bauds * 32
	move.l D1,D0	            // ubgs
	lsr.l #8,D0
	move.b D0,MCF_UART_UBG13
	move.b D1,MCF_UART_UBG23
	/* Enable receiver and transmitter */
	moveq #MCF_UART_UCR_TX_ENABLED + MCF_UART_UCR_RX_ENABLED,D0
	move.b D0,MCF_UART_UCR3
	lea tab_rtc_init(PC),A0  // ACPF
	moveq #3,D0
	bsr rtc_ws
	lea -4(A6),A0
	clr.l (A0)
	moveq #2,D0
	bsr rtc_rd
	bpl.s .ri4               // read OK! ?
	// timeout
#ifdef DEBUG
	lea debug54(PC),A0
	bsr debug_display_string	
#endif
	bra.s .ri5
.ri4:
#ifdef DEBUG
	lea debug53(PC),A0
	bsr debug_display_string
	move.l -4(A6),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	move.l -4(A6),D0
	cmp.l #0x4F4B2100,D0     // OK!
	bne .ri3
#ifdef DEBUG
	lea debug50(PC),A0
	bsr debug_display_string	
#endif
.ri5:
	lea -4(A6),A0
	moveq #1,D0
	move.b D0,(A0)           // cmd
	moveq #0,D0
	bsr rtc_ws
	lea -65(A6),A0           // read buffer
	clr.b (A0)
	moveq #64,D0             // header + len - 1
	bsr rtc_rd
	bmi .ri3                 // timeout
#ifdef DEBUG
	lea debug53(PC),A0
	bsr debug_display_string
	move.b -65(A6),D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	moveq #0,D0
	move.b -65(A6),D0
	cmp.l #0x81,D0           // header
	bne .ri3
#ifdef DEBUG
	lea debug51(PC),A0
	bsr debug_display_string	
#endif
	lea -64+14(A6),A0        // stack read buffer, NVM offset
	moveq #0,D0
	moveq #47,D1
	moveq #0,D2              // checksum loop
.ri6:
		move.b (A0)+,D2
		add.l D2,D0
	subq.l #1,D1
	bpl.s .ri6
	and.l #0xFF,D0
	move.b (A0)+,D1
	not.l D1
#if 1  // 2nd byte seems is bad ???
	move.b D1,(A0)
#endif
	cmp.l D1,D0
	bne.s .ri7               // bad checksum
	move.b (A0)+,D1
	cmp.l D1,D0
	beq.s .ri8               // checksum OK
.ri7:
#ifdef DEBUG
	lea debug55(PC),A0
	bsr debug_display_string	
#endif
	lea -64+14(A6),A0        // stack read buffer, NVM offset
	moveq #0,D0              // clear NVM read buffer
	moveq #47,D1
.ri9:
		clr.b (A0)+
	subq.l #1,D1
	bpl.s .ri9
	move.b D1,(A0)+          // new checksum
	clr.b (A0)+
.ri8:
	moveq #0,D1
	lea -64(A6),A0           // stack read buffer
	lea 0xFFFF8961,A1        // F030 RTC (offset 0) / NVM (offset 14) - FPGA emulation
	lea 0xFFFF8963,A2
.ri2:
		move.b D1,(A1)    // index
		move.b (A0)+,(A2) // data
		addq.l #1,D1
	cmp.l #64,D1
	bcs.s .ri2
	lea int_rtc(PC),A0
	move.l A0,(64+32+OFFSET_INT_CF68KLIB)*4 // PSC3
	moveq #0x9,D0           // level 1, priority 1
	move.b D0,MCF_INTC_ICR32
	move.l #~MCF_INTC_IMRH_INT_MASK32,D0
	and.l D0,MCF_INTC_IMRH
	move.l #~MCF_INTC_IMRL_MASKALL,D0
	and.l D0,MCF_INTC_IMRL   // global mask
	moveq #MCF_UART_UIMR_RXRDY_FU,D0
	move.b D0,MCF_UART_UIMR3 // enable RX interrupts
	moveq #0,D0              // OK
	bra.s .ri1
.ri3:
#ifdef DEBUG
	lea debug52(PC),A0
	bsr debug_display_string	
#endif
	moveq #-1,D0             // timeout
.ri1:
	unlk A6
	rts
	
tab_rtc_init:
	.ascii "ACPF"
	.align 2

rtc_ws:	// D0.W: len-1, A0: buffer

	moveq #0,D2
	move.w D0,D2             // len -1
.rw1:
		move.b MCF_UART_USR3,D1
		and.l #MCF_UART_USR_TXEMP,D1
		beq.s .rw1               // full
		move.b (A0)+,D0          // data inside the buffer
		move.b D0,MCF_UART_UTB3  // data
	subq.l #1,D2
	bpl.s .rw1
	moveq #0,D0              // OK
	rts

rtc_rd:	// D0.W: len-1, A0: buffer

	moveq #0,D3
	move.w D0,D3             // len -1
.rr3:
	move.l MCF_SLT_SCNT1,D1
.rr1:
		moveq #MCF_UART_USR_RXRDY,D0
		move.b MCF_UART_USR3,D2  // status
		and.l D2,D0
		beq.s .rr2               // nothing
		moveq #0,D0
		move.b MCF_UART_URB3,D0  // data
		move.b D0,(A0)+          // store data inside the buffer
                          subq.l #1,D3
                          bpl.s .rr3
                          moveq #0,D0
                          rts         // OK
.rr2:
		move.l D1,D0
		sub.l MCF_SLT_SCNT1,D0
	cmp.l #1000000*SYSTEM_CLOCK,D0 // 1 S
	bcs.s .rr1
	moveq #-1,D0             // timeout
	rts

sysmidi:	/* MCF547X */

	moveq #0,D2
	move.w 4(A0),D2          // buffer size
	moveq #0,D1
	move.w 8(A0),D1          // tail index
	addq.l #1,D1
	cmp.l D2,D1
	bcs.s .smd1
	moveq #0,D1
.smd1:
	move.w 6(A0),D2          // head index
	cmp.l D2,D1
	beq.s .smd2
	move.l (A0),A2           // buffer
	move.b D0,(A2,D1.l)      // store received data
	move.w D1,8(A0)          // tail index
.smd2:
	rts

#else /* MCF548X - use CAN network for the IKBD with a special Eiffel version */

can_set_baudrate:

#ifdef DEBUG
	lea debug12(PC),A0
	bsr debug_display_string	
#endif
	move.l #MCF_CAN_CANMCR_HALT,D1 // stop
	or.l D1,MCF_CAN_CANMCR1
#if 0 // Sample Point at 85.7%
	cmp.l #1000,D0
	bne.s .baud800	
	move.l #MCF_CAN_CANCTRL_PRESDIV(4) \
	 + MCF_CAN_CANCTRL_PROPSEG(7) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(2),D0
	bra.s .setbaud	 
.baud800:
	cmp.l #800,D0
	bne.s .baud500
	move.l #MCF_CAN_CANCTRL_PRESDIV(4) \
	 + MCF_CAN_CANCTRL_PROPSEG(7) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(7),D0
	bra.s .setbaud	 
.baud500:
	cmp.l #500,D0
	bne.s .baud250
	move.l #MCF_CAN_CANCTRL_PRESDIV(9) \
	 + MCF_CAN_CANCTRL_PROPSEG(7) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(2),D0
	bra.s .setbaud	 
.baud250:
	cmp.l #250,D0
	bne.s .baud125
	move.l #MCF_CAN_CANCTRL_PRESDIV(0x18) \
	 + MCF_CAN_CANCTRL_PROPSEG(4) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(1),D0
	bra.s .setbaud	 
.baud125:
	cmp.l #125,D0
	bne.s .baud100
	move.l #MCF_CAN_CANCTRL_PRESDIV(0x31) \
	 + MCF_CAN_CANCTRL_PROPSEG(4) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(1),D0
	bra.s .setbaud	 
.baud100:
	cmp.l #100,D0
	bne.s .baud50
	move.l #MCF_CAN_CANCTRL_PRESDIV(0x31) \
	 + MCF_CAN_CANCTRL_PROPSEG(7) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(2),D0
	bra.s .setbaud	 
.baud50:
	cmp.l #50,D0
	bne.s .baud20
	move.l #MCF_CAN_CANCTRL_PRESDIV(0x7C) \
	 + MCF_CAN_CANCTRL_PROPSEG(4) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(1),D0
	bra.s .setbaud	 
.baud20:
	cmp.l #20,D0
	bne.s .endbaud
	move.l #MCF_CAN_CANCTRL_PRESDIV(0xF9) \
	 + MCF_CAN_CANCTRL_PROPSEG(7) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(2),D0
#else	// Sample Point at 75%
	cmp.l #1000,D0
	bne.s .baud800	
	move.l #MCF_CAN_CANCTRL_PRESDIV(4) \
	 + MCF_CAN_CANCTRL_PROPSEG(5) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(4),D0
	bra.s .setbaud	 
.baud800:
	cmp.l #800,D0
	bne.s .baud500
	move.l #MCF_CAN_CANCTRL_PRESDIV(4) \
	 + MCF_CAN_CANCTRL_PROPSEG(7) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(7),D0
	bra.s .setbaud	 
.baud500:
	cmp.l #500,D0
	bne.s .baud250
	move.l #MCF_CAN_CANCTRL_PRESDIV(9) \
	 + MCF_CAN_CANCTRL_PROPSEG(5) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(4),D0
	bra.s .setbaud	 
.baud250:
	cmp.l #250,D0
	bne.s .baud125
	move.l #MCF_CAN_CANCTRL_PRESDIV(0x18) \
	 + MCF_CAN_CANCTRL_PROPSEG(2) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(3),D0
	bra.s .setbaud	 
.baud125:
	cmp.l #125,D0
	bne.s .baud100
	move.l #MCF_CAN_CANCTRL_PRESDIV(0x31) \
	 + MCF_CAN_CANCTRL_PROPSEG(2) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(3),D0
	bra.s .setbaud	 
.baud100:
	cmp.l #100,D0
	bne.s .baud50
	move.l #MCF_CAN_CANCTRL_PRESDIV(0x31) \
	 + MCF_CAN_CANCTRL_PROPSEG(5) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(4),D0
	bra.s .setbaud	 
.baud50:
	cmp.l #50,D0
	bne.s .baud20
	move.l #MCF_CAN_CANCTRL_PRESDIV(0x7C) \
	 + MCF_CAN_CANCTRL_PROPSEG(2) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(3),D0
	bra.s .setbaud	 
.baud20:
	cmp.l #20,D0
	bne.s .endbaud
	move.l #MCF_CAN_CANCTRL_PRESDIV(0xF9) \
	 + MCF_CAN_CANCTRL_PROPSEG(5) \
	 + MCF_CAN_CANCTRL_PSEG1(7) \
	 + MCF_CAN_CANCTRL_PSEG2(4),D0
#endif
.setbaud:
	or.l #MCF_CAN_CANCTRL_SAMP,D0
	move.l D0,MCF_CAN_CANCTRL1
.endbaud:
	rts
	
can_send_message: // D0:num, D1:ID, D2:DLC, A0:data

	move.l A0,-(SP)
	move.l A1,-(SP)
#if 0 // #ifdef DEBUG
	move.l D0,-(SP)
	moveq #0x53,D0
	bsr debug_display_char
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_byte
	moveq #0x20,D0
	bsr display_char
	move.l (SP)+,D0
#endif
	lea MCF_CAN_MSGBUF1,A1
	asl.l #4,D0              // *16
	add.l D0,A1
	move.l #MBOX_TXCODE_NOT_READY,D0
	move.l D0,(A1)
	moveq #18,D0
	asl.l D0,D1              // ID
	move.l D1,4(A1)
	move.l (A0)+,8(A1)       // data
	move.l (A0)+,12(A1)
	move.l #MBOX_TXCODE_TRANSMIT,D0
	swap D2                  // DLC
	or.l D2,D0
	move.l D0,(A1)
#if 0 // #ifdef DEBUG
	move.l D2,-(SP)
	move.l A1,-(SP)
	swap D2
	lea -8(A0),A1
	bra.s .next_bytes_send
.loop_bytes_send:
		move.b (A1)+,D0
		bsr debug_hex_byte
.next_bytes_send:
	subq.l #1,D2
	bpl.s .loop_bytes_send
	move.l (SP)+,A1
	move.l (SP)+,D2
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
#if 0 // #ifdef DEBUG
	lea debug35(PC),A0
	bsr debug_display_string
	move.l MCF_CAN_CANMCR1,D0
	bsr debug_hex_long
	lea debug35b(PC),A0
	bsr debug_display_string
	move.l MCF_CAN_CANCTRL1,D0
	bsr debug_hex_long
	lea debug35c(PC),A0
	bsr debug_display_string
	move.l MCF_CAN_ERRCNT1,D0
	bsr debug_hex_long
	lea debug35d(PC),A0
	bsr debug_display_string
	move.l MCF_CAN_ERRSTAT1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	move.l (SP)+,A1
	move.l (SP)+,A0
	rts

int_can:

	link A6,#-10
	lea -56(SP),SP
	movem.l D0-A5,(SP)
	lea MCF_CAN_MSGBUF1+(15*16),A1 // message 15
	move.l (A1),D2           // control/status
	move.l 4(A1),D1
	moveq #18,D0
	lsr.l D0,D1              // ID
	and.l #0x7FF,D1          // standard
	swap D2
	and.l #0xF,D2            // DLC
#if 0 // #ifdef DEBUG
	moveq #0x52,D0
	bsr debug_display_char
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr display_char
	move.l D2,D0
	bsr debug_hex_byte
	moveq #0x20,D0
	bsr display_char
#endif
	move.l 8(A1),-8(A6)      // copy data
	move.l 12(A1),-4(A6)
	move.l #MBOX_RXCODE_EMPTY,D0
	move.l D0,(A1)
	tst.l D2                 // DLC
	beq.s .not_ikbd
	cmp.l #PDO1TX,D1
	bne.s .not_ikbd
#if 0 // #ifdef DEBUG
	move.l D2,-(SP)
	move.l A1,-(SP)
	lea -8(A6),A1
	bra.s .next_bytes
.loop_bytes:
		move.b (A1)+,D0
		bsr debug_hex_byte
.next_bytes:
	subq.l #1,D2
	bpl.s .loop_bytes
	move.l (SP)+,A1
	move.l (SP)+,D2
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	lea 0xF96,A0             // iorec keyboard
	lea -10(A6),A1           // data - 2 for arcvint
.get_ikbd_bytes:
		lea -16(SP),SP
		movem.l D2/A0-A2,(SP)
		bsr arcvint // 0xE032EC
		movem.l (SP),D2/A0-A2
		lea 16(SP),SP
		addq.l #1,A1
	subq.l #1,D2
	bgt.s .get_ikbd_bytes
.not_ikbd:
	move.w MCF_CAN_IFLAG1,D0
	and.l #MCF_CAN_IFLAG_BUF15I,D0
	move.w D0,MCF_CAN_IFLAG1 // clear interrupt
	movem.l (SP),D0-A5
	lea 56(SP),SP
	unlk A6
	rte
	
can_init:

#ifdef DEBUG
	lea debug9(PC),A0
	bsr debug_display_string	
#endif
	move.l #250,D0           // 250 Kbits/s
	bsr can_set_baudrate
#ifdef DEBUG
	lea debug13(PC),A0
	bsr debug_display_string	
#endif
	// setup message box acceptance filter
	clr.l MCF_CAN_RXGMASK1
	clr.l MCF_CAN_RX14MASK1
	clr.l MCF_CAN_RX15MASK1  
#ifdef DEBUG
	lea debug14(PC),A0
	bsr debug_display_string	
#endif
	lea MCF_CAN_MSGBUF1,A0
	// active transmit buffer 0
	move.l #PDO1RX<<18,D0	
	move.l D0,4(A0)
	move.l #MBOX_TXCODE_NOT_READY,D0
	move.l D0,(A0)
	lea 16(A0),A0
	// deactivate message buffers 1-14
	moveq #13,D1
	move.l #MBOX_RXCODE_NOT_ACTIVE,D0
.inactive_mbox:
		move.l D0,(A0)
		lea 16(A0),A0
	subq.l #1,D1
	bpl.s .inactive_mbox
	// active message receive buffer 15
	move.l #MBOX_RXCODE_NOT_ACTIVE,D0
	move.l D0,(A0)
	clr.l 4(A0)
	move.l #MBOX_RXCODE_EMPTY,D0
	move.l D0,(A0)
#ifdef DEBUG
	lea debug15(PC),A0
	bsr debug_display_string	
#endif
	// enable interrupt message 15
	lea int_can(PC),A0
	move.l A0,(64+55+OFFSET_INT_CF68KLIB)*4      // ERROR CAN1
	move.l A0,(64+56+OFFSET_INT_CF68KLIB)*4      // BUSOFF CAN1
	move.l A0,(64+57+OFFSET_INT_CF68KLIB)*4      // MBOR CAN1
	moveq #0x24,D0           // level 4, priority 4
	move.b D0,MCF_INTC_ICR55
	move.b D0,MCF_INTC_ICR56
	move.b D0,MCF_INTC_ICR57
	move.l #~(MCF_INTC_IMRH_INT_MASK55 + MCF_INTC_IMRH_INT_MASK56 + MCF_INTC_IMRH_INT_MASK57),D0
	and.l D0,MCF_INTC_IMRH
#ifdef DEBUG
	lea debug16(PC),A0
	bsr debug_display_string
#endif
	// clear interrupts
	tst.w MCF_CAN_IFLAG1
	moveq #-1,D0
	move.w D0,MCF_CAN_IFLAG1
	clr.l MCF_CAN_ERRSTAT1
	// start the chip
	move.l #MCF_CAN_CANMCR_MAXMB(15),D0
	move.l D0,MCF_CAN_CANMCR1
	// enable interrupt message 15
	move.w #MCF_CAN_IMASK_BUF15M,D0
	move.w D0,MCF_CAN_IMASK1
	rts
	
#endif /* MCF547X */
#endif /* MCF5445X */
	
_Setscreen:

	move.w 14(SP),D1         // modecode
	move.w 12(SP),D0         // rez
	move.l 8(SP),A1          // physbase
	move.l 4(SP),A0          // logbase
	
Setscreen:	// D0.W: rez, D1.W: modecode, A0: logbase, A1: physbase

#ifdef DEBUG

	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug26(PC),A0
	bsr debug_display_string
	move.l (SP),D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l A1,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l 4(SP),D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w D1,D0
	bsr debug_hex_word	
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,A0
	move.l (SP)+,D0
#endif
	moveq #0,D2
	move.w D0,D2             // rez
	move.l A0,D0             // logbase
	beq.s .sc1
	move.l D0,_v_bas_ad
	beq .sc2
.sc1:
	move.l A1,D0             // physbase
	bne .sc2
	cmp.l #3,D2              // rez: FALCON
	bne .sc2
	ext.l D1
	cmp.l #-1,D1             // modecode: no change
	beq .sc3
	move.l #640*400,-(SP)
	move.w #0x15,-(SP)       // Srealloc
	trap #1
	addq.l #6,SP
	move.l D0,_v_bas_ad
	move.w #0xA8,D0          // 640 x 400 x 2
	move.w D0,0x184C         // modecode
#ifdef COLDFIRE
	jsr 0xE09512             // TOS404
#else
	dc.w 0xA000
#endif
	moveq #2,D0
	move.w D0,V_PLANES(A0)   // nb planes
	move.l #744/2,D0
	move.w D0,DEV_TAB+6(A0)  // width point in mm/1000
	move.w D0,DEV_TAB+8(A0)  // heigth point in mm/1000
	move.l 8(A1),A2          // 16 * 8 font characters
	move.l A2,CUR_FONT(A0)   // current font
	move.l A2,DEF_FONT(A0)   // default font
	move.w FORMHEIGHT(A2),V_CEL_HT(A0) // cell height
	move.w FORMWIDTH(A2),V_FNT_WD(A0)  // cell width
	move.w FIRST_ADE(A2),V_FNT_ST(A0)  // font start ADE
	move.w LAST_ADE(A2),V_FNT_ND(A0)   // font end ADE
	move.l FONTDAT(A2),V_FNT_AD(A0)    // character definitions
	move.l CHAR_OFF_TABLE(A2),V_OFF_AD(A0) // character offsets
	clr.w V_CUR_X(A0)        // cursor to column 0
	clr.w V_CUR_Y(A0)        // cursor to line 0
	clr.w V_CUR_OFF(A0)      // line offset is 0
	moveq #30,D0
	move.b D0,V_CUR_CT(A0)
	move.b D0,V_PERIOD(A0)   // cursor blink rate
	move.l _v_bas_ad,D2
	move.l D2,V_CUR_AD(A0)   // set cursor to begin of the screen
	moveq #0,D2
	move.w D6,D2
	subq.l #1,D2
	move.w D2,DEV_TAB(A0)    // width workstation info
	move.w D7,D2
	subq.l #1,D2
	move.w D2,DEV_TAB+2(A0)  // height workstation info
	move.w D7,V_REZ_VT(A0)   // height screen VDI ESC
	move.l D7,D1
	.chip 68060
	divu V_CEL_HT(A0),D1     // height character VDI ESC
	.chip 5200
	ext.l D1
	subq.l #1,D1
	move.w D1,V_CEL_MY(A0)   // max line cursor VDI ESC
	move.w D6,V_REZ_HZ(A0)   // width VDI ESC
	move.l D6,D0
	lsr.l #3,D0
	move.l D0,D2
	subq.l #1,D2
	move.w D2,V_CEL_MX(A0)   // max column cursor VDI ESC
	mulu V_PLANES(A0),D0     // planes line A
	move.w D0,V_LIN_WR(A0)   // bytes/line line A
	move.w D0,BYTES_LN(A0)   // bytes/line VDI ESC
	mulu V_CEL_HT(A0),D0     // height character VDI ESC
	move.w D0,V_CEL_WR(A0)   // bytes/line characters VDI ESC	
	lea 0xB12(A0),A1         // Bconout colors
	moveq #0,D0
	moveq #15,D1
.sc4:
		move.l D0,(A1)+
		addq.l #1,D0
	subq.l #1,D1
	bpl.s .sc4
	bra.s .sc3
.sc2:
	cmp.l #2,D2              // rez
	bhi.s .sc3
	moveq #2,D0              // 640 x 400 x 2
	move.w D0,sshiftmd	
.sc3:
	moveq #0,D0
	move.w #0xB8,D0          // 640 x 400 x 2
	rts
	
#ifdef DEBUG

debug1:	.ascii "NVMaccess"
	.byte 13,10,0
debug1r:	.asciz "NVMaccess read 0x"
debug1w:	.asciz "NVMaccess write 0x"
debug1c:	.ascii "NVMaccess clear"
	.byte 13,10,0
#ifdef MCF547X
debug2:	.ascii "Init timers, serial and MFP"
	.byte 13,10,0
#else /* !MCF547X */
debug2:	.ascii "Init timers, serial and CAN"
	.byte 13,10,0
#endif /* MCF547X */

debug3:	.asciz "Flash parameter 0x"
debug3r:	.asciz " read 0x"
debug3w:	.asciz " write 0x"
debug3wb:	.asciz " = 0x"
debug4:      .byte 13,13
	.ascii "Rsconf"
	.byte 13,10,13,13,0
debug5:	.ascii "settimer"
	.byte 13,10,0
debug5a:	.asciz "GPT_GCIR0 (timer A) 0x"
debug5b:	.asciz "GPT_GCIR1 (timer B) 0x"
debug5c:	.asciz "GPT_GCIR2 (timer C) 0x"
debug5d:	.asciz "GPT_GCIR3 (timer D) 0x"
debug6:	.ascii "initint"
	.byte 13,10,0
debug7:	.asciz "Jdisint 0x"
debug8:	.asciz "Jenabint 0x"
#ifndef MCF5445X /* no CAN network on MCF5445X */
#ifndef MCF547X
debug9:	.ascii "CAN init"
	.byte 13,10,0
debug10:	.ascii "Ikbdws"
	.byte 13,10,0
debug11:	.ascii "CAN Bus-Off"
	.byte 13,10,0
debug11b:	.ascii "CAN Error passive"
	.byte 13,10,0
debug12:	.ascii "CAN set baudrate"
	.byte 13,10,0
debug13:	.ascii "CAN setup message box acceptance filter"
	.byte 13,10,0
debug14:	.ascii "CAN init message buffers"
	.byte 13,10,0
debug15:	.ascii "CAN enable interrupt message 15"
	.byte 13,10,0
debug16:	.ascii "CAN start the chip"
	.byte 13,10,0
#endif /* MCF547X */
#endif /* MCF5445X */
debug17:	.ascii "Cache enable"
	.byte 13,10,0
debug18:	.ascii "Cache disable"
	.byte 13,10,0
debug19:	.asciz "Supexec 0x"
debug20:	.asciz "Initmous 0x"
debug21:	.ascii "Init serial mouse at 1200 bauds"
	.byte 13,10,0
debug22:	.asciz "Install vector 0x"
debug22b:	.asciz " at 0x"
debug23:	.ascii "Test RTC"
	.byte 13,10,0
#ifndef MCF547X
debug24:	.ascii "Gettime IKBD"
	.byte 13,10,0
#endif
debug25:	.asciz "XBIOS #0x"
debug26:	.asciz "Setscreen 0x"
debug27:	.ascii "PCI set up the arbiter"
	.byte 13,10,0
debug28:	.ascii "PCI setup burst parameters"
	.byte 13,10,0
debug29:	.ascii "PCI configure initiator windows"
	.byte 13,10,0
debug30:	.ascii "Internal PCI controller interrupts"
	.byte 13,10,0
debug31:	.ascii "Clear PCI Reset and wait for devices to reset"
	.byte 13,10,0
debug32:	.ascii "PCI init driver"
	.byte 13,10,0
debug33:	.ascii "PCI init devices"
	.byte 13,10,0
debug34:	.ascii "Add cookie _PCI"
	.byte 13,10,0
debug35:	.asciz "CANMCR 0x"
debug35b:	.asciz " CANCTRL 0x"
debug35c:	.asciz " ERRCNT 0x"
debug35d:	.asciz " ERRSTAT 0x"
debug36:	.asciz "PCICAR 0x"
debug37:	.asciz "PCIIWxBTAR 0x"
debug39:	.asciz "PCIIDR 0x"
debug38:	.ascii "Delay 300 mS reset IKBD"
	.byte 13,10,0
debug38b:	.ascii "End delay IKBD"
	.byte 13,10,0
debug40:	.asciz "PCIREV 0x"
debug41:	.asciz "PCIBARx "
debug42:	.ascii "PCI Parity error"
	.byte 13,10,0
debug43:	.ascii "PCI Initiator Abort received"
	.byte 13,10,0	
debug44:	.ascii "PCI Target Abort received"
	.byte 13,10,0
debug45:	.asciz "PCICR 0x"
debug46:	.ascii "Multi function device found"
	.byte 13,10,0
debug47:	.ascii "This device is not a multi function device"
	.byte 13,10,0
#if defined(MCF5445X) || defined(MCF547X)
debug48:	.ascii "Init IKBD"
	.byte 13,10,0
#endif
#ifdef MCF547X
debug49:	.ascii "Init PIC RTC"
	.byte 13,10,0
debug50:	.ascii "Get OK! from PIC"
	.byte 13,10,0
debug51:	.ascii "Read PIC RTC frame"
	.byte 13,10,0
debug52:	.ascii "Timeout or bad header received from PIC RTC"
	.byte 13,10,0
debug53:	.asciz "PIC answer 0x"
debug54:	.ascii "Timeout from PIC RTC, OK! not received, continue..."
	.byte 13,10,0
debug55:	.ascii "PIC RTC bad checksum, reset all" 
	.byte 13,10,0
debug56:	.ascii "Write NVM to PIC RTC"
	.byte 13,10,0
#endif
		
	.align 2
	
debug_display_string:

	move.l D0,-(SP)
	move.l A0,-(SP)
.dds2:
		move.b (A0)+,D0
		beq.s .dds1
		bsr debug_display_char
	bra.s .dds2
.dds1:
	move.l (SP)+,A0
	move.l (SP)+,D0
	rts

debug_hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s debug_hex_word
	move.l (SP)+,D0
debug_hex_word:
	move.w D0,-(SP)
	lsr.l #8,D0
	bsr.s debug_hex_byte
	move.w (SP)+,D0
debug_hex_byte:
	move.w D0,-(SP)
	lsr.l #4,D0
	bsr.s debug_hex_char
	move.w (SP)+,D0
debug_hex_char:
	and.l #0xF,D0
	or.l #0x30,D0
	cmp.l #0x3A,D0
	bcs.s debug_display_char  
	addq.l #7,D0

debug_display_char:

	tst.b serial_mouse
	bne.s .no_debug
	move.l D1,-(SP)
.wait_uart:
	move.b MCF_UART_USR0,D1
	and.l #MCF_UART_USR_TXRDY,D1
	beq.s .wait_uart
	move.b D0,MCF_UART_UTB0 // send the character
	move.l (SP)+,D1
.no_debug:
	rts
	
#endif /* DEBUG */

#ifdef COLDFIRE
#undef DEBUG
#endif

#else  /* ATARI */

#ifdef DEBUG

debug1:	.asciz "PCICR 0x"
debug2:	.asciz "LAS0BA 0x"
debug3:	.asciz "LAS0RR 0x"
debug4:	.asciz "PCIBAR2 0x"
debug5:	.asciz "LAS1BA 0x"
debug10:	.asciz "DMLBAM 0x"
debug11:	.asciz "DMRR 0x"
debug12:	.asciz "DMLBAI 0x"
debug13:	.asciz "DMPBAM 0x"
debug20:	.asciz "BIGEND 0x"
debug21:	.asciz "LMISC 0x"
debug27:	.asciz "PCI PLX byte access failure, read: 0x"
debug28:	.asciz "PCI PLX word access failure, read: 0x"
debug29:	.byte 13,10
	.ascii "PCI init PLX registers"
	.byte 13,10,0
debug32:	.ascii "PCI init driver"
	.byte 13,10,0
debug33:	.ascii "PCI init devices"
	.byte 13,10,0
debug34:	.ascii "Add cookie _PCI"
	.byte 13,10,0
debug40:	.ascii "find_pci_device"
	.byte 13,10,0
debug41:	.ascii "find_pci_classcode"
	.byte 13,10,0
debug42:	.asciz "read_config_byte "
debug43:	.asciz "read_config_word "
debug44:	.asciz "read_config_longword "
debug45:	.asciz "fast_read_config_byte "
debug46:	.asciz "fast_read_config_word "
debug47:	.asciz "fast_read_config_longword "
debug48:	.asciz "write_config_byte "
debug49:	.asciz "write_config_word "
debug50:	.asciz "write_config_longword "
debug51:	.asciz "hook_interrupt "
debug52:	.ascii "unhook_interrupt"
	.byte 13,10,0
debug53:	.ascii "special_cycle"
	.byte 13,10,0
debug54:	.ascii "get_routing"
	.byte 13,10,0
debug55:	.ascii "set_interrupt"
	.byte 13,10,0
debug56:	.asciz "get_resource "
debug57:	.ascii "get_card_used"
	.byte 13,10,0
debug58:	.ascii "set_card_used"
	.byte 13,10,0
debug59:	.ascii "read_mem_byte"
	.byte 13,10,0
debug60:	.ascii "read_mem_word"
	.byte 13,10,0
debug61:	.ascii "read_mem_longword"
	.byte 13,10,0
debug62:	.ascii "fast_read_mem_byte"
	.byte 13,10,0
debug63:	.ascii "fast_read_mem_word"
	.byte 13,10,0
debug64:	.ascii "fast_read_mem_longword"
	.byte 13,10,0
debug65:	.asciz "write_mem_byte "
debug66:	.asciz "write_mem_word "
debug67:	.asciz "write_mem_longword "
debug68:	.ascii "read_io_byte"
	.byte 13,10,0
debug69:	.ascii "read_io_word"
	.byte 13,10,0
debug70:	.ascii "read_io_longword"
	.byte 13,10,0
debug71:	.ascii "fast_read_io_byte"
	.byte 13,10,0
debug72:	.ascii "fast_read_io_word"
	.byte 13,10,0
debug73:	.ascii "fast_read_io_longword"
	.byte 13,10,0
debug74:	.asciz "write_io_byte "
debug75:	.asciz "write_io_word "
debug76:	.asciz "write_io_longword "
debug77:	.ascii "get_machine_id"
	.byte 13,10,0
debug78:	.ascii "get_pagesize"
	.byte 13,10,0
debug79:	.ascii "virt_to_bus"
	.byte 13,10,0
debug80:	.ascii "bus_to_virt"
	.byte 13,10,0
debug81:	.ascii "virt_to_phys"
	.byte 13,10,0
debug82:	.ascii "phys_to_virt"
	.byte 13,10,0

	.align 2

debug_display_string:

	movem.l D0/A0,-(SP)
.dds2:
		move.b (A0)+,D0
		beq.s .dds1
		bsr debug_display_char
	bra.s .dds2
.dds1:
	movem.l (SP)+,D0/A0
	rts

debug_hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s debug_hex_word
	move.l (SP)+,D0
debug_hex_word:
	move.w D0,-(SP)
	lsr.w #8,D0          
	bsr.s debug_hex_byte     
	move.w (SP)+,D0
debug_hex_byte:
	move.w D0,-(SP)
	lsr.b #4,D0        
	bsr.s debug_hex_char      
	move.w (SP)+,D0      
debug_hex_char:
	and.b #0xF,D0      
	or.b #0x30,D0      
	cmp.b #0x3A,D0     
	bcs.s debug_display_char  
	addq.b #7,D0   

debug_display_char:

	movem.l D0-D2/A0-A2,-(SP)
	move.w D0,-(SP)
	move.l #0x5F504349,D0 
	lea 0xED0000,A0          // 128 KB
	cmp.l (A0),D0            // _PCI
	beq.s .ddc2
	lea 0xEC0000,A0          // 192 KB
	cmp.l (A0),D0            // _PCI
	beq.s .ddc2
	lea 0xEB0000,A0          // 256 KB
	cmp.l (A0),D0            // _PCI
	beq.s .ddc2
	lea 0xEA0000,A0          // 320 KB
	cmp.l (A0),D0            // _PCI
	bne.s .ddc3
.ddc2:
	move.w (SP),D0           // character
	swap D0
	move.w #0x0076,D0        // 'v'
	move.l D0,-(SP)
	jsr 40(A0)               // drivers PCI in flash, dbug
	addq.l #4,SP
	bne.s .ddc1
.ddc3:
	move.w #2,-(SP)
	move.w #3,-(SP)          // Bconout
	trap #13
	addq.l #4,SP
.ddc1:	
	addq.l #2,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts

#endif /* DEBUG */

	dc.l 0x58425241          // XBRA
	dc.l 0x43543630          // CT60
	dc.l 0x00E00D76

#endif /* COLDFIRE */

det_xbios:

#ifdef COLDFIRE
	.chip 68060
	move.l USP,A0
	.chip 5200
#else
	move.l USP,A0
#endif
	btst #5,(SP)             // call in supervisor state
	beq.s .xb2
	lea 8(SP),A0
.xb2:
#ifdef COLDFIRE
#ifdef DEBUG
	moveq #0,D0
	move.w (A0),D0           // function
	cmp.l #0xB,D0            // unused (DEBUG_GEMDOS)
	beq. .xb0
	cmp.l #356,D0
	bhi .xb00
	cmp.l #299,D0            // BIOS PCI
	bcc .xb0
.xb00:
	move.l A0,-(SP)
	lea debug25(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
	move.w (A0),D0           // function
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
.xb0:
#endif
	moveq #0,D0
#endif
	move.w (A0),D0           // function
#ifdef DEBUG_GEMDOS
	cmp.w #0xB,D0            // unused
	bne.s .xb25
	cmp.w #5,2(A0)
	bne.s .xb25
	cmp.w #0xF100,4(A0)
	bne.s .xb25
	move.l 6(A0),A0          // string
	bsr debug_gemdos
	rte
.xb25:
#endif
#ifdef COLDFIRE
#ifndef MCF547X
	cmp.l #0x2C,D0           // Bconmap
	beq.s .xb27              // just one serial port, no Bconmap
#endif
	cmp.l #0x96,D0           // VsetMask
	bhi .xb10
	move.w tab_xbios(PC,D0.l*2),D0
	bmi .xb1
	jmp tab_xbios(PC,D0.l)
.xb27:
	moveq #0,D0              // no Bconmap
	rte
	
tab_xbios:
	dc.w _Initmous-tab_xbios // 0 Initmous
	dc.w -1                  // 1 Ssbrk
	dc.w _Physbase-tab_xbios // 2 Physase
	dc.w _Logbase-tab_xbios  // 3 Logbase
	dc.w _Getrez-tab_xbios   // 4 GetRez
	dc.w _Vsetscreen-tab_xbios // 5 Setscreen
	dc.w _error-tab_xbios    // 6 Setpalette
	dc.w _error-tab_xbios    // 7 Setcolor
#ifdef MCF547X
	dc.w -1                  // 8 Floprd
	dc.w -1                  // 9 Flopwr
	dc.w -1                  // 0xA Flopfmt
#else
	dc.w _error-tab_xbios    // 8 Floprd
	dc.w _error-tab_xbios    // 9 Flopwr
	dc.w _error-tab_xbios    // 0xA Flopfmt
#endif
	dc.w -1                  // 0xB
#ifdef MCF547X
	dc.w -1                  // 0xC Midiws
#else
	dc.w _error-tab_xbios    // 0xC Midiws
#endif
	dc.w _Mfpint-tab_xbios   // 0xD Mfpint
	dc.w -1                  // 0xE Iorec
#ifdef MCF547X
	dc.w -1                  // 0xF Rsconf
#else
	dc.w _Rsconf-tab_xbios   // 0xF Rsconf
#endif
	dc.w -1                  // 0x10 Keytbl
	dc.w -1                  // 0x11 Random
	dc.w -1                  // 0x12 Protobt
#ifdef MCF547X
	dc.w -1                  // 0x13 Flopver
#else 
	dc.w _error-tab_xbios    // 0x13 Flopver
#endif
	dc.w _error-tab_xbios    // 0x14 Scrdmp
	dc.w -1                  // 0x15 Cursconf
	dc.w -1                  // 0x16 Settime
	dc.w -1                  // 0x17 Gettime
	dc.w -1                  // 0x18 Bioskeys
	dc.w _Ikbdws-tab_xbios   // 0x19 Ikbdws
	dc.w _Jdisint-tab_xbios  // 0x1A Jdisint
	dc.w _Jenabint-tab_xbios // 0x1B Jenabint
#ifdef MCF547X
	dc.w _Giaccess-tab_xbios // 0x1C Giaccess
	dc.w _Offgibit-tab_xbios // 0x1D Offgibit 	
	dc.w _Ongibit-tab_xbios  // 0x1E Ongibit
#else
	dc.w _error-tab_xbios    // 0x1C Giaccess
	dc.w _error-tab_xbios    // 0x1D Offgibit 	
	dc.w _error-tab_xbios    // 0x1E Ongibit
#endif
	dc.w _Xbtimer-tab_xbios  // 0x1F Xbtimer
#ifdef MCF547X
	dc.w -1                  // 0x20 Dosound
#else 
	dc.w _error-tab_xbios    // 0x20 Dosound
#endif
	dc.w -1                  // 0x21 Setprt    
	dc.w -1                  // 0x22 Kbdvbase    
	dc.w -1                  // 0x23 Kbrate   
	dc.w _error-tab_xbios    // 0x24 Prtblk
	dc.w -1                  // 0x25 Vsync
	dc.w _Supexec-tab_xbios  // 0x26 Supexec
	dc.w -1                  // 0x27 Puntaes
	dc.w -1                  // 0x28 
	dc.w -1                  // 0x29
	dc.w -1                  // 0x2A Dmaread
	dc.w -1                  // 0x2B Dmawrite
	dc.w -1                  // 0x2C Bconmap
	dc.w -1                  // 0x2D
	dc.w -1                  // 0x2E NVMaccess
	dc.w -1                  // 0x2F
	dc.w -1                  // 0x30 Metainit
	dc.w -1                  // 0x31
	dc.w -1                  // 0x32
	dc.w -1                  // 0x33
	dc.w -1                  // 0x34
	dc.w -1                  // 0x35
	dc.w -1                  // 0x36
	dc.w -1                  // 0x37
	dc.w -1                  // 0x38
	dc.w -1                  // 0x39
	dc.w -1                  // 0x3A
	dc.w -1                  // 0x3B
	dc.w -1                  // 0x3C
	dc.w -1                  // 0x3D
	dc.w -1                  // 0x3E
	dc.w -1                  // 0x3F
	dc.w _Blitmode-tab_xbios // 0x40 Blitmode
	dc.w -1                  // 0x41 Floprate
	dc.w -1                  // 0x42
	dc.w -1                  // 0x43
	dc.w -1                  // 0x44
	dc.w -1                  // 0x45
	dc.w -1                  // 0x46
	dc.w -1                  // 0x47
	dc.w -1                  // 0x48
	dc.w -1                  // 0x49
	dc.w -1                  // 0x4A
	dc.w -1                  // 0x4B
	dc.w -1                  // 0x4C
	dc.w -1                  // 0x4D
	dc.w -1                  // 0x4E
	dc.w -1                  // 0x4F
	dc.w -1                  // 0x50 EsetShift
	dc.w -1                  // 0x51 EgetShift
	dc.w -1                  // 0x52 EsetBank
	dc.w -1                  // 0x53 EsetColor
	dc.w -1                  // 0x54 EsetPalette
	dc.w -1                  // 0x55 EgetPalette
	dc.w -1                  // 0x56 EsetGray
	dc.w -1                  // 0x57 EsetSmear
	dc.w _Vsetmode-tab_xbios // 0x58 Vsetmode
	dc.w _Mon_type-tab_xbios // 0x59 Mon_type
	dc.w _error-tab_xbios    // 0x5A Vsetsync
	dc.w _Vgetsize-tab_xbios // 0x5B Vgetsize
	dc.w -1                  // 0x5C VsetVars
	dc.w _error-tab_xbios    // 0x5D VsetRGB
	dc.w _error-tab_xbios    // 0x5E VgetRGB
	dc.w _error-tab_xbios    // 0x5F ValidMode (undocumented)
	dc.w _error-tab_xbios    // 0x60 Dsp_DoBlock
	dc.w _error-tab_xbios    // 0x61 Dsp_BlkHandShake
	dc.w _error-tab_xbios    // 0x62 Dsp_BlkUnpacked
	dc.w _error-tab_xbios    // 0x63 Dsp_InStream
	dc.w _error-tab_xbios    // 0x64 Dsp_OutStream
	dc.w _error-tab_xbios    // 0x65 Dsp_IOStream
	dc.w _error-tab_xbios    // 0x66 Dsp_RemoveInterrupts
	dc.w _error-tab_xbios    // 0x67 Dsp_GetWordSize
	dc.w _error-tab_xbios    // 0x68 Dsp_Lock
	dc.w _error-tab_xbios    // 0x69 Dsp_UnLock
	dc.w _error-tab_xbios    // 0x6A Dsp_Available
	dc.w _error-tab_xbios    // 0x6B Dsp_Reserve
	dc.w _error-tab_xbios    // 0x6C Dsp_LoadProg
	dc.w _error-tab_xbios    // 0x6D Dsp_ExecProg
	dc.w _error-tab_xbios    // 0x6E Dsp_ExecBoot
	dc.w _error-tab_xbios    // 0x6F Dsp_LoadToBinary
	dc.w _error-tab_xbios    // 0x70 Dsp_TriggerHC
	dc.w _error-tab_xbios    // 0x71 Dsp_RequestUniqueAbility
	dc.w _error-tab_xbios    // 0x72 Dsp_GetProgAbility
	dc.w _error-tab_xbios    // 0x73 Dsp_FlushSubroutines
	dc.w _error-tab_xbios    // 0x74 Dsp_LoadSubroutines
	dc.w _error-tab_xbios    // 0x75 Dsp_InqSubrAbility
	dc.w _error-tab_xbios    // 0x76 Dsp_RunSubroutine
	dc.w _error-tab_xbios    // 0x77 Dsp_HF0
	dc.w _error-tab_xbios    // 0x78 Dsp_HF1
	dc.w _error-tab_xbios    // 0x79 Dsp_HF2
	dc.w _error-tab_xbios    // 0x7A Dsp_HF3
	dc.w _error-tab_xbios    // 0x7B Dsp_BlkWords
	dc.w _error-tab_xbios    // 0x7C Dsp_BlkBytes
	dc.w _error-tab_xbios    // 0x7D Dsp_HStat
	dc.w _error-tab_xbios    // 0x7E Dsp_SetVectors
	dc.w _error-tab_xbios    // 0x7F Dsp_MultBlocks
	dc.w _error-tab_xbios    // 0x80 Locksnd
	dc.w _error-tab_xbios    // 0x81 Unlocksnd
	dc.w _error-tab_xbios    // 0x82 Soundcmd
	dc.w _error-tab_xbios    // 0x83 Setbuffer
	dc.w _error-tab_xbios    // 0x84 Setmode
	dc.w _error-tab_xbios    // 0x85 Settracks
	dc.w _error-tab_xbios    // 0x86 Setmontracks
	dc.w _error-tab_xbios    // 0x87 Setinterrupt
	dc.w _error-tab_xbios    // 0x88 Buffoper
	dc.w _error-tab_xbios    // 0x89 Dsptristate
	dc.w _error-tab_xbios    // 0x8A Gpio
	dc.w _error-tab_xbios    // 0x8B Devconnect
	dc.w _error-tab_xbios    // 0x8C Sndstatut
	dc.w _error-tab_xbios    // 0x8D Buffptr
	dc.w -1                  // 0x8E
	dc.w -1                  // 0x8F
	dc.w -1                  // 0x90
	dc.w -1                  // 0x91
	dc.w -1                  // 0x92
	dc.w -1                  // 0x93
	dc.w -1                  // 0x94
	dc.w -1                  // 0x95
	dc.w _error-tab_xbios    // 0x96 VsetMask	
_error:

	moveq #-1,D0
	rte

_Initmous:

	move.w 2(A0),D0          // type
	move.l 8(A0),A1          // vector
	move.l 4(A0),A0          // parameters
	bsr Initmous
	rte

_Physbase:
_Logbase:
	move.l _v_bas_ad,D0
	rte

_Getrez:

	moveq #2,D0              // 640 x 400 x 2
	rte

_Vsetscreen:

	move.w 12(A0),D1         // modecode
	move.w 10(A0),D0         // rez	
	move.l 6(A0),A1          // physbase
	move.l 2(A0),A0          // logbase
	bsr Setscreen
	rte	

_Mfpint:

	move.w 2(A0),D0          // num
	move.l 4(A0),A0          // vector
	bsr initint              // Mfpint
	rte

_Rsconf:

	move.w 2(A0),D0          // baud
	move.w 4(A0),D1          // ctrl
	move.w 6(A0),D2          // ucr
	bsr Rsconf
	rte

_Ikbdws:

	move.w 2(A0),D0          // len -1
	move.l 4(A0),A0          // buffer
	bsr Ikbdws
	rte

_Jdisint:
	
	move.w 2(A0),D0          // num
	bsr Jdisint
	rte	

_Jenabint:

	move.w 2(A0),D0          // num
	bsr Jenabint	
	rte

#ifdef MCF547X
	
_Giaccess:

	move.w 2(A0),D0          // data
	move.w 4(A0),D1          // register
	bsr Giaccess
	rte

Giaccess:

	move.l D1,-(SP)
	move.l D2,-(SP)
	move.l A0,-(SP)
	move.w SR,D2
	move.w D2,-(SP)
	or.l #0x700,D2           // mask interrupts
	move.w D2,SR
	lea 0xFFFF8800,A0        // PSG sound
	moveq #15,D2
	btst #7,D1
	bne.s .psg_write
	and.l D2,D1
	move.b D1,(A0)           // register
	bra.s .psg_read
.psg_write:
	and.l D2,D1
	move.b D1,(A0)           // register
	move.b D0,2(A0)          // write data
.psg_read:
	moveq #0,D0
	move.b (A0),D0           // read data	
	move.w (SP)+,D2
	move.w D2,SR             // restore interrupts
	move.l (SP)+,A0
	move.l (SP)+,D2
	move.l (SP)+,D1
	rts

_Offgibit:
	
	move.l D2,-(SP)
	move.w SR,D2
	move.w D2,-(SP)
	or.l #0x700,D2           // mask interrupts
	move.w D2,SR
	moveq #14,D1             // port A
	bsr Giaccess
	moveq #0,D2
	move.w 2(A0),D2          // bit mask
	and.l D2,D0
	bset #7,D1               // write port A
	bsr Giaccess
	move.w (SP)+,D2
	move.w D2,SR             // restore interrupts
	move.l (SP)+,D2
	rte

_Ongibit:

	move.l D2,-(SP)
	move.w SR,D2
	move.w D2,-(SP)
	or.l #0x700,D2           // mask interrupts
	move.w D2,SR
	moveq #14,D1             // port A
	bsr Giaccess
	moveq #0,D2
	move.w 2(A0),D2          // bit mask
	or.l D2,D0
	bset #7,D1               // write port A
	bsr Giaccess
	move.w (SP)+,D2
	move.w D2,SR             // restore interrupts
	move.l (SP)+,D2
	rte

#endif /* MCF547X */

_Xbtimer:

	move.w 2(A0),D0          // timer
	move.w 4(A0),D1          // control
	move.w 6(A0),D2          // data
	move.l 8(A0),A0          // vector
	bsr Xbtimer
	rte

_Supexec:
	lea -36(SP),SP
	movem.l D3-D7/A3-A6,(SP)
	move.l 2(A0),A0          // subroutine
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug19(PC),A0
	bsr debug_display_string
	move.l (SP),D0
	bsr debug_hex_long
	move.l (SP)+,A0
	move.l (SP)+,D0
#endif
	jsr (A0)
#ifdef DEBUG
	move.l D0,-(SP)
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif
	movem.l (SP),D3-D7/A3-A6
	lea 36(SP),SP
	rte

_Blitmode:
	
	moveq #0,D0
	rte

_Vsetmode:

	moveq #0,D0
	move.w #0xB8,D0          // 640 x 400 x 2
	move.w D0,0x184C         // modecode
	rts
	
_Mon_type:

	moveq #0,D0              // ST mono
	rte	

_Vgetsize:

	move.l #640*400,D0
	rte

.xb10:
	cmp.l #160,D0            // CacheCtrl MilanTOS
#else	
	cmp.w #0x40,D0           // Blitmode
	bne.s .xb10
	move.l 2(SP),D0          // PC
	and.l #0xFFF00000,D0
	cmp.l #0x00E00000,D0     // TOS
	beq .xb1
	moveq #0,D0              // no blitter
	rte
.xb10:
	cmp.w #160,D0            // CacheCtrl MilanTOS
#endif
	bne .xb15
	move.w 2(A0),D0          // OpCode
	bne.s .xb16
	moveq #0,D0              // function is implemented
	rte
.xb16:
#ifdef COLDFIRE
	cmp.l #1,D0              // flush data cache
	bne.s .xb17
	bsr flush_data_cache
#else
	cmp.w #1,D0              // flush data cache
	bne.s .xb17	
	cpusha DC
#endif
	moveq #0,D0
	rte	
.xb17:
#ifdef COLDFIRE
	cmp.l #2,D0              // flush instruction cache
	bne.s .xb18
	bsr flush_instr_cache
#else
	cmp.w #2,D0              // flush instruction cache
	bne.s .xb18	
	cpusha IC
#endif
	moveq #0,D0
	rte
.xb18:
#ifdef COLDFIRE
	cmp.l #3,D0              // flush data and instruction caches
	beq .xb14
	cmp.l #4,D0              // inquire data cache mode
	bne.s .xb19
	.chip 68060
	movec.l CACR,D0          // from CF68KLIB
	.chip 5200
	btst #31,D0
	bra.s .xb20
.xb19:
	cmp.l #6,D0              // inquire instruction cache mode
	bne.s .xb21
	.chip 68060
	movec.l CACR,D0          // from CF68KLIB
	.chip 5200
	btst #15,D0
.xb20:
	sne.b D0
	and.l #1,D0
	rte
.xb21:
	cmp.l #5,D0              // set data cache mode
	beq.s .xb22
	cmp.l #7,D0              // set instruction cache mode
#else
	cmp.w #3,D0              // flush data and instruction caches
	beq .xb14
	cmp.w #4,D0              // inquire data cache mode
	bne.s .xb19
	movec.l CACR,D0
	btst #31,D0
	bra.s .xb20
.xb19:
	cmp.w #6,D0              // inquire instruction cache mode
	bne.s .xb21
	movec.l CACR,D0
	btst #15,D0
.xb20:
	sne.b D0
	and.w #1,D0
	ext.l D0
	rte
.xb21:
	cmp.w #5,D0              // set data cache mode
	beq.s .xb22
	cmp.w #7,D0              // set instruction cache mode
#endif
	bne.s .xb23
.xb22:	
	tst.w 4(A0)              // mode
	beq .xb24                // disable
	bra .xb8                 // enable
.xb23:
	moveq #-5,D0             // error
	rte
.xb15:
#ifdef COLDFIRE
	cmp.l #356,D0
	bhi .xb26
	cmp.l #299,D0            // BIOS PCI
	bcs .xb1
	sub.l #299,D0
	move.w tab_pci_bios(PC,D0.l*2),D0
	bmi .xb1                // original TOS XBIOS
	jsr tab_pci_bios(PC,D0.l)
	rte
#else
	cmp.w #356,D0
	bhi .xb26
	cmp.w #299,D0            // BIOS PCI
	bcs .xb1
	sub.w #299,D0
	bne.s .xb27
	lea install_pci_bios_magic(PC),A1
	move.l A1,0x80           // trap #0
.xb27:	
	move.w tab_pci_bios(PC,D0.W*2),D0
	bmi .xb1                 // original TOS XBIOS
	jsr tab_pci_bios(PC,D0.W)
	rte

det_xbios_magic:

	move.l USP,A0
	btst #5,(SP)             // call in supervisor state
	beq.s .xb28
	lea 8(SP),A0
.xb28:
	move.w (A0),D0           // function
	cmp.w #read_core_temperature,D0
	beq.s .xb33
	cmp.w #read_core_temperature_bis,D0
	bne.s .xb34
.xb33:
	move.w 2(A0),-(SP)       // deg_type
	jsr ct60_read_temp
	cmp.w #CT60_CELCIUS,(SP)
	beq.s .xb35
	cmp.w #CT60_FARENHEIT,(SP)
	bne.s .xb36
	mulu #9,D0
	divu #5,D0
	add.w #32,D0
	ext.l D0
	bra.s .xb35
.xb36:
	moveq #CT60_READ_ERROR,D0 // error
.xb35:
	addq.l #2,SP
	rte
.xb34:
	cmp.w #rw_parameter,D0
	beq.s .xb37
	cmp.w #rw_parameter_bis,D0
	bne.s .xb38
.xb37:
	move.w 2(A0),D0          // mode
	move.l 4(A0),D1          // type_param
	move.l 8(A0),D2          // value
	jsr ct60_rw_param 
	rte
.xb38:
	cmp.w #cache,D0
	beq.s .xb39
	cmp.w #cache_bis,D0
	bne.s .xb40
.xb39:
	move.w 2(A0),D0
	bmi.s .xb42
	bne.s .xb41
	jsr 0xE0085A             // caches off
	bra.s .xb42
.xb41:
	jsr 0xE250C8             // caches on
.xb42:
	movec.l CACR,D0
	rte
.xb40:
	cmp.w #flush_cache,D0
	beq.s .xb43
	cmp.w #flush_cache_bis,D0
	bne.s .xb29
.xb43:
	cpusha BC
	moveq #0,D0
	rte
.xb29:
	cmp.w #356,D0
	bhi.s .xb30
	cmp.w #299,D0            // BIOS PCI
	bcs.s .xb30
	sub.w #299,D0
	move.w tab_pci_bios(PC,D0.W*2),D0
	bmi.s .xb30              // original TOS XBIOS
	jsr tab_pci_bios(PC,D0.W)
	rte
.xb30:
	move.l RESERVED_VEC,A0   // where old xbios XBRA vector is saved !
	cmp.l #0x58425241,(A0)   // XBRA
	bne.s .xb31              // invalid
	cmp.l #0x63743630,4(A0)  // ct60
	bne.s .xb31              // invalid
	move.l 8(A0),-(SP)       // jump to MagiC XBIOS vector 
	rts
.xb31:
	bra.s .xb31              // XBRA invalid => infinite loop !
#endif /* COLDFIRE */
tab_pci_bios:
	dc.w _install_pci_bios-tab_pci_bios // 299
	dc.w _find_pci_device-tab_pci_bios // 300
	dc.w _find_pci_classcode-tab_pci_bios // 301
	dc.w _read_config_byte-tab_pci_bios // 302
	dc.w _read_config_word-tab_pci_bios // 303
	dc.w _read_config_longword-tab_pci_bios // 304
	dc.w _fast_read_config_byte-tab_pci_bios // 305
	dc.w _fast_read_config_word-tab_pci_bios // 306
	dc.w _fast_read_config_longword-tab_pci_bios // 307
	dc.w _write_config_byte-tab_pci_bios // 308
	dc.w _write_config_word-tab_pci_bios // 309
	dc.w _write_config_longword-tab_pci_bios // 310
	dc.w _hook_interrupt-tab_pci_bios // 311
	dc.w _unhook_interrupt-tab_pci_bios // 312
	dc.w _special_cycle-tab_pci_bios // 313
	dc.w _get_routing-tab_pci_bios // 314
	dc.w _set_interrupt-tab_pci_bios // 315
	dc.w _get_resource-tab_pci_bios // 316
	dc.w _get_card_used-tab_pci_bios // 317
	dc.w _set_card_used-tab_pci_bios // 318
	dc.w _read_mem_byte-tab_pci_bios // 319
	dc.w _read_mem_word-tab_pci_bios // 320
	dc.w _read_mem_longword-tab_pci_bios // 321
	dc.w _fast_read_mem_byte-tab_pci_bios // 322
	dc.w _fast_read_mem_word-tab_pci_bios // 323
	dc.w _fast_read_mem_longword-tab_pci_bios // 324
	dc.w _write_mem_byte-tab_pci_bios // 325
	dc.w _write_mem_word-tab_pci_bios // 326
	dc.w _write_mem_longword-tab_pci_bios // 327
	dc.w _read_io_byte-tab_pci_bios // 328
	dc.w _read_io_word-tab_pci_bios // 329
	dc.w _read_io_longword-tab_pci_bios // 330
	dc.w _fast_read_io_byte-tab_pci_bios // 331
	dc.w _fast_read_io_word-tab_pci_bios // 332
	dc.w _fast_read_io_longword-tab_pci_bios // 333
	dc.w _write_io_byte-tab_pci_bios // 334
	dc.w _write_io_word-tab_pci_bios // 335
	dc.w _write_io_longword-tab_pci_bios // 336
	dc.w _get_machine_id-tab_pci_bios // 337
	dc.w _get_pagesize-tab_pci_bios // 338
	dc.w _virt_to_bus-tab_pci_bios // 339
	dc.w _bus_to_virt-tab_pci_bios // 340
	dc.w _virt_to_phys-tab_pci_bios // 341
	dc.w _phys_to_virt-tab_pci_bios  // 342
	dc.w -1 // 343
	dc.w -1 // 344
	dc.w -1 // 345
	dc.w -1 // 346
	dc.w -1 // 347
	dc.w -1 // 348
	dc.w -1 // 349
	dc.w _dma_setbuffer-tab_pci_bios // 350
	dc.w _dma_buffoper-tab_pci_bios  // 351
	dc.w _read_mailbox-tab_pci_bios  // 352
	dc.w _write_mailbox-tab_pci_bios // 353
	dc.w _dma_alloc-tab_pci_bios // 354
	dc.w _dma_free-tab_pci_bios // 355
	dc.w _dma_lock-tab_pci_bios // 356
.xb26:	
#ifdef COLDFIRE
	cmp.l #read_core_temperature,D0
	beq.s .xb11
	cmp.l #read_core_temperature_bis,D0
	bne.s .xb5
.xb11:
	moveq #0,D0
#else /* !COLDFIRE */
	cmp.w #read_core_temperature,D0
	beq.s .xb11
	cmp.w #read_core_temperature_bis,D0
	bne.s .xb5
.xb11:
	move.w 2(A0),-(SP)       // deg_type
	jsr ct60_read_temp
	cmp.w #CT60_CELCIUS,(SP)
	beq.s .xb3
	cmp.w #CT60_FARENHEIT,(SP)
	bne.s .xb4
	mulu #9,D0
	divu #5,D0
	add.w #32,D0
	ext.l D0
	bra.s .xb3
.xb4:
	moveq #CT60_READ_ERROR,D0 // error
.xb3:
	addq.l #2,SP
#endif /* COLDFIRE */
	rte
.xb5:
#ifdef COLDFIRE
	cmp.l #rw_parameter,D0
	beq.s .xb12
	cmp.l #rw_parameter_bis,D0
#else
	cmp.w #rw_parameter,D0
	beq.s .xb12
	cmp.w #rw_parameter_bis,D0
#endif
	bne .xb6
.xb12:
	move.w 2(A0),D0          // mode
	move.l 4(A0),D1          // type_param
	move.l 8(A0),D2          // value
#ifdef COLDFIRE
#ifdef DEBUG
	move.l D0,-(SP)
	move.l D0,-(SP)
	lea debug3(PC),A0
	bsr debug_display_string
	move.l D1,D0
	bsr debug_hex_char
	btst #0,3+4(SP)
	beq.s .not_dbg_write
	lea debug3w(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
.not_dbg_write:
	move.l (SP)+,D0
#endif /* DEBUG */
	jsr fire_rw_param
#ifdef DEBUG
	btst #0,3(SP)
	bne.s .not_dbg_read
	move.l D0,-(SP)
	lea debug3r(PC),A0
	bsr debug_display_string
	move.l (SP),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	bra.s .end_dbg_read
.not_dbg_read:
	move.l D0,-(SP)
	lea debug3wb(PC),A0
	bsr debug_display_string
	move.l (SP),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
.end_dbg_read:
	addq.l #4,SP
#endif /* DEBUG */
#else /* !COLDFIRE */
	jsr ct60_rw_param 
#endif /* COLDFIRE */
	rte
.xb6:
#ifdef COLDFIRE
	cmp.l #cache,D0
	beq.s .xb13
	cmp.l #cache_bis,D0
#else
	cmp.w #cache,D0
	beq.s .xb13
	cmp.w #cache_bis,D0
#endif
	bne.s .xb9
.xb13:
	move.w 2(A0),D0
	bmi.s .xb7
	bne.s .xb8
.xb24:
#ifdef COLDFIRE
	bsr caches_disable
#else
	jsr 0xE0085A             // caches off
#endif
	rte
.xb8:
#ifdef COLDFIRE
	bsr caches_enable
	rte
.xb7:
	.chip 68060
	movec.l CACR,D0
	.chip 5200
	rte
.xb9:
	cmp.l #vmalloc,D0
	beq.s .xb32
	cmp.l #vmalloc_bis,D0
	beq.s .xb32
	cmp.l #flush_cache,D0
	beq.s .xb14
	cmp.l #flush_cache_bis,D0
	bne.s .xb1
.xb14:
	bsr flush_caches
#else
	jsr 0xE250C8             // caches on
	rte
.xb7:
	movec.l CACR,D0
	rte
.xb9:
	cmp.w #vmalloc,D0
	beq.s .xb32
	cmp.w #vmalloc_bis,D0
	beq.s .xb32
	cmp.w #flush_cache,D0
	beq.s .xb14
	cmp.w #flush_cache_bis,D0
	bne.s .xb1
.xb14:
	cpusha BC
#endif
.xb32:
	moveq #0,D0
	rte
.xb1:
#ifdef COLDFIRE
	move.l savptr,A1
	move.w (SP)+,D0
	move.w D0,-(A1)          // save SR
	move.l (SP)+,-(A1)       // save PC
	tst.w proc_type
	beq.s .proc_less_68020
	tst.w (SP)+
.proc_less_68020:
	lea -40(A1),A1
	movem.l D3-D7/A3-A7,(A1)
	move.l A1,savptr
	btst #13,D0              // call in supervisor state
	bne.s .call_super
	.chip 68060
	move.l USP,A0            // emulated instruction who as SP
	.chip 5200
	move.l A0,SP             // as target return bad SP !
.call_super:
	moveq #0,D0
	moveq #0,D1
	move.w (SP)+,D0          // function
	lea 0xE0156C,A0          // XBIOS tab
	move.w (A0)+,D1          // max
	cmp.l D1,D0
	bge .call_error
	asl.l #2,D0
	add.l D0,A0
	move.l (A0),D0
	bclr #0,D0
	move.l D0,A0
	beq.s .not_indirect
	move.l (A0),A0
.not_indirect:
	sub.l A5,A5
	jsr (A0)                 // call function
.call_error:
	move.l savptr,A1
	movem.l (A1),D3-D7/A3-A7
	lea 40(A1),A1
	tst.w proc_type
	beq.s .proc_less_68020b
	clr.w -(SP)              // format
.proc_less_68020b:
	move.l (A1)+,-(SP)       // restore PC
	move.w (A1)+,-(SP)       // restore SR
	move.l A1,savptr
	rte
#else /* !COLDFIRE */
	move.l det_xbios-4(PC),-(SP)
	rts
	
test_pci_drivers:

	move.l #0x5F504349,D0    // _PCI
	lea 0xED0000,A0          // 128 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_pci_ok
	lea 0xEC0000,A0          // 192 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_pci_ok
	lea 0xEB0000,A0          // 256 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_pci_ok
	lea 0xEA0000,A0          // 320 KB, 1st part
	cmp.l (A0),D0            // _PCI
.test_pci_ok:                         // (optional 2nd part inside 0xFC0000-0xFEFFFF)
	rts

magic_routine:                        // called before auto folder
	
	jmp install_scsidrv
end_magic_routine:

install_magic_routine:

	lea magic_routine(PC),A0
	pea end_magic_routine(PC)
	move.l phystop,A1
	lea -512(A1),A1
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

install_pci_bios_magic:               // trap #0 handler called when MagiC enable interrupts (trap #1 not exist, seems always TOS)

	movem.l D1-A6,-(SP)
	move.l #0x4D616758,D0    // MagX
	bsr get_cookie
	beq .no_install          // not found
	move.l #0x5F504349,D0    // _PCI cookie
	bsr get_cookie
	bne .no_install          // found
	move.l #((3*4)+(3*2))*2,D0 // size for 2 x XBRA jumper
	move.l _membot,A0        // boot alloc
	add.l D0,_membot
	move.l #0x58425241,D0    // XBRA
	move.l D0,(A0)
	move.l D0,18(A0)
	move.l #0x63743630,D0    // ct60
	move.l D0,4(A0)
	move.l D0,22(A0)
	move.w SR,-(SP)
	or.w #0x700,SR
	move.l A0,RESERVED_VEC   // save address of XBRA jumper
	move.l XBIOS_VEC,8(A0)   // trap #14 vector saved
	move.w #0x4EF9,12(A0)    // JMP
	lea det_xbios_magic(PC),A1
	move.l A1,14(A0)
	lea 12(A0),A0
	move.l A0,XBIOS_VEC      // to jumper
	addq.l #6,A0             // 2nd jumper
	move.l hdv_boot,8(A0)    // hdv_boot vector saved
	move.w #0x4EF9,12(A0)    // JMP
	lea det_hdv_boot_magic(PC),A1
	move.l A1,14(A0)
	lea 12(A0),A6
	cpusha BC                // flush cache for JMP
	move.w (SP)+,SR
	move.w #2,-(SP)
	lea -2(SP),A0            // install PCI BIOS 2nd time (no PCI RESET)
	jsr _install_pci_bios(PC)
	addq.l #2,SP
	bmi .no_install
	lea 0xE00FB6,A0          // exception fault vectors handler
	lea 8,A1
	moveq #2,D0              // access fault, address fault, illegal instruction
.init_vectors:
		move.l A0,(A1)+
	dbf D0,.init_vectors
	bsr test_pci_drivers
	bne.s .no_install        // no PCI drivers
	movec.l CACR,D0
	move.l D0,-(SP)          // save CACR
	cpusha BC
	move.l #0xA0808000,D0    // enable caches
	movec.l D0,CACR
	move.l #2,-(SP)          // no reset (started a 2nd time) for MagiC
	jsr 4(A0)                // drivers PCI in flash, init_devices
	addq.l #4,SP
	cpusha BC
	move.l (SP)+,D0          // restore CACR
	movec.l D0,CACR
	clr.w -(SP)
	lea -2(SP),A0            // display devices
	jsr _install_pci_bios(PC)
	addq.l #2,SP
	move.l A6,hdv_boot       // to jumper
	cpusha BC                // flush cache for JMP
.no_install:
	movem.l (SP)+,D1-A6
	moveq #1,D0
	rte

det_hdv_boot_magic:
	
	movem.l D1-D2/A0-A2,-(SP)
	bsr install_magic_routine
	bsr test_pci_drivers
	bne.s .no_pci_drivers    // no PCI drivers
	jsr 10(A0)               // drivers PCI in flash, call after SDRAM added
.no_pci_drivers:
	move.l hdv_boot,A0
.loop_xbra:
		cmp.l #0x58425241,-12(A0) // XBRA
		bne.s .no_xbra
		cmp.l #0x63743630,-8(A0) // ct60
		bne.s .next_xbra
		move.l -4(A0),D0         // old vector
		movem.l (SP)+,D1-D2/A0-A2
		move.l D0,-(SP)          // old vector
		rts	
.next_xbra:
		move.l -4(A0),D0
		beq.s .no_xbra           // no vector
		move.l D0,A0
	bra.s .loop_xbra
.no_xbra:
	movem.l (SP)+,D1-D2/A0-A2
	moveq #0,D0
	rts

#endif /* COLDFIRE */

#include "pci_bios.S"

	.text
	
	.align 4

get_cookie:

#ifdef COLDFIRE
	move.l D1,-(SP)
	move.l A0,-(SP)
#else
	movem.l D1/A0,-(SP)
#endif
	move.l D0,D1             // cookie
	move.l cookie,D0
	beq.s .cookie_not_found
	move.l D0,A0
.loop_cookie:
		tst.l (A0)
		beq.s .cookie_not_found
		cmp.l (A0),D1
		bne.s .next_cookie
		move.l 4(A0),D0
		bra.s .end_cookie
.next_cookie:
		addq.l #8,A0
	bra.s .loop_cookie
.cookie_not_found:
	moveq #0,D0
.end_cookie:
#ifdef COLDFIRE
	move.l (SP)+,A0
	move.l (SP)+,D1
#else
	movem.l (SP)+,D1/A0
#endif
	tst.l D0
	rts

add_cookie:

#ifdef COLDFIRE
	lea -12(SP),SP
	movem.l D1-D2/A0,(SP)
#else
	movem.l D1-D2/A0,-(SP)
#endif
	move.l cookie,D2
	beq.s .cookie_not_found_add
	move.l D2,A0
	moveq #0,D2
	bra.s .next_cookie_add
.loop_add_cookie:
		addq.l #8,A0
		addq.l #1,D2
.next_cookie_add:
	tst.l (A0)
	bne.s .loop_add_cookie
	cmp.l 4(A0),D2
	bcc.s .cookie_not_found_add
	move.l 4(A0),D2
	move.l D0,(A0)           // cookie
	move.l D1,4(A0)          // value
	addq.l #8,A0
	clr.l (A0)
	move.l D2,4(A0)
	moveq #1,D0              // OK
	bra.s .end_add_cookie
.cookie_not_found_add:
	moveq #0,D0              // error
.end_add_cookie:
#ifdef COLDFIRE
	movem.l (SP),D1-D2/A0
	lea 12(SP),SP
#else
	movem.l (SP)+,D1-D2/A0
#endif
	rts

#ifdef DEBUG_GEMDOS
debug_gemdos:

	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
.dg2:
		move.b (A0)+,D0
		beq .dg1
		cmp.l #0x28777065,-1(A0) // '(wpe'
		bne.s .dg4
		moveq #0,D2
		bra.s .dg3
.dg4:
		cmp.l #0x286C7065,-1(A0) // '(lpe'
		bne.s .dg5
		moveq #1,D2
.dg3:
		cmp.l #0x656B2028,3(A0)  // 'ek ('
		bne.s .dg5
		cmp.l #0x6136202B,8(A0)  // 'a6 +'
		beq.s .dg6
		cmp.l #0x6136202D,8(A0)  // 'a6 -'
		bne.s .dg5
		bset #31,D2
.dg6:
		moveq #0x30,D0
		bsr display_char
		moveq #0x78,D0
		bsr display_char
		add.w #13,A0
		bsr hex_value
		tst.l D2
		bpl.s .dg7
		neg.l D0
.dg7:
		tst.w D2
		bne.s .dg8
		move.w (A6,D0.l),D0
		bsr hex_word
		bra.s .dg9
.dg8:
		move.l (A6,D0.l),D0
		bsr hex_long
.dg9:
			move.b (A0)+,D0
			beq.s .dg1	
			cmp.b #0x29,D0       // )
			bne.s .dg9
		cmp.b #0x29,(A0)
		bne.s .dg9
		addq.w #1,A0
		bra .dg2
.dg5:	
		bsr display_char
	bra .dg2
.dg1:
	rts
	
hex_value:

	movem.l D1/A0,-(SP)
	moveq #0,D0
.hv2:	
		move.b (A0)+,D1
		cmp.b #0x30,D1
		bcs.s .hv1
		cmp.b #0x39,D1
		bhi.s .hv4
		and.b #0xF,D1
		bra.s .hv3
.hv4:
		cmp.b #0x41,D1
		bcs.s .hv1
		cmp.b #0x46,D1
		bls.s .hv5
		cmp.b #0x61,D1
		bcs.s .hv1
		cmp.b #0x66,D1
		bhi.s .hv1		
.hv5:
		and.b #0xF,D1
		add.b #0x9,D1
.hv3:
		asl.l #4,D0
		or.b D1,D0
	bra.s .hv2			
.hv1:
	movem.l (SP)+,D1/A0
	rts
#endif /* DEBUG_GEMDOS */

#ifndef COLDFIRE
get_no_cache_memory:

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

get_no_cache_memory_size:

	move.l D1,-(SP)
	bsr get_no_cache_memory
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
#endif /* COLDFIRE */

nvm_access:

#ifdef COLDFIRE
	.chip 68060              // some instructions not for Coldfire...
#ifdef DEBUG
	lea debug1(PC),A0
	bsr debug_display_string	
#endif
	moveq #-5,D0             // error
	moveq #0,D1
	move.w 6(SP),D1          // start
	cmp.l #48,D1
#else
	moveq #-5,D0             // error
	cmp.w #48,6(SP)          // start
#endif
	bcc .nvram_access 
	move.w 4(SP),D1          // mode
	bne .nvram_access        // <> read
	// fix NVRAM values from flash parameters if NV magic code
	move.w 6(SP),D0          // start
	move.w 8(SP),D1          // size
	move.l 10(SP),A0         // buffer
#ifdef COLDFIRE
	lea -32(SP),SP
	movem.l D1-D4/A0-A3,(SP)
#else
	movem.l D1-D4/A0-A3,-(SP)
#endif
	link A6,#-56
	move.l A0,-56(A6)        // buffer
	move.w D1,-52(A6)        // size
	move.w D0,-50(A6)        // start
	lea -48(A6),A3
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SAVE_NVRAM_1,D1 // type_param
	moveq #0,D2              // value
#if defined(COLDFIRE) && !defined(MCF547X)
	jsr fire_rw_param 
	move.w D0,(A3)           // bootpreff
	clr.w D0
	swap D0
	cmp.l #0x4E56,D0         // NV magic code
	bne .nvm_read
	lea pseudo_nvram_data,A0
	move.w (A3),(A0)
#else /* ATARI - FIREBEE */
#ifdef COLDFIRE
	jsr fire_rw_param
#else
	jsr ct60_rw_param
#endif
	move.w D0,(A3)           // bootpref
	swap D0
	cmp.w #0x4E56,D0         // NV magic code
	bne .nvm_read
	                         // NVM values are stored in Flash
	pea (A3)                 // buffer: bootpref
	move.w #2,-(SP)          // size
	clr.w -(SP)              // start
	moveq #-5,D0
	moveq #1,D1
	move.w D1,-(SP)          // write
	jsr 0xE02172             // NVMaccess
	lea 10(SP),SP
#endif /* defined(COLDFIRE) && !defined(MCF547X) */
	clr.l 2(A3) 
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SAVE_NVRAM_2,D1 // type_param
	moveq #0,D2              // value
#ifdef COLDFIRE
	jsr fire_rw_param
#else
	jsr ct60_rw_param 
#endif
	move.l D0,6(A3)          // language, keyboard, datetime, separator
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SAVE_NVRAM_3,D1 // type_param
	moveq #0,D2              // value
#ifdef COLDFIRE
	jsr fire_rw_param
#else
	jsr ct60_rw_param 
#endif
	rol.l #8,D0
	move.b D0,10(A3)         // bootdelay
	move.l D0,14(A3)         // vmode, scsi, bootdelay
#if defined(COLDFIRE) && !defined(MCF547X)
	lea pseudo_nvram_data+6,A0
	lea 6(A3),A1             // buffer: language, keyboard, datetime, separator, bootdelay
	move.b (A1)+,(A0)+
	move.b (A1)+,(A0)+
	move.b (A1)+,(A0)+
	move.b (A1)+,(A0)+
	move.b (A1)+,(A0)+
#else /* ATARI - FIREBEE */
	pea 6(A3)                // buffer: language, keyboard, datetime, separator, bootdelay
	move.w #5,-(SP)          // size
	move.w #6,-(SP)          // start
	moveq #-5,D0
	moveq #1,D1
	move.w D1,-(SP)          // write
	jsr 0xE02172             // NVMaccess
	lea 10(SP),SP
#endif /* defined(COLDFIRE) && !defined(MCF547X) */
	clr.b 11(A3)
	clr.w 12(A3)
#if defined(COLDFIRE) && !defined(MCF547X)
	lea pseudo_nvram_data+14,A0
	lea 14(A3),A1            // buffer:  vmode, scsi
	move.b (A1)+,(A0)+
	move.b (A1)+,(A0)+
	move.b (A1)+,(A0)+
#else /* ATARI - FIREBEE */
	pea 14(A3)               // buffer: vmode, scsi
	move.w #3,-(SP)          // size
	move.w #14,-(SP)         // start
	moveq #-5,D0
	moveq #1,D1
	move.w D1,-(SP)          // write
	jsr 0xE02172             // NVMaccess
	lea 10(SP),SP
#endif /* defined(COLDFIRE) && !defined(MCF547X) */
	clr.b 17(A3)
	clr.l 18(A3)
	clr.l 24(A3)
	clr.l 28(A3)
	clr.l 32(A3)
	clr.l 36(A3)
	clr.l 40(A3)
	clr.l 44(A3)
	move.l -56(A6),A0        // target buffer
	move.w -52(A6),D1        // size
	move.w -50(A6),D0        // start
	add.w D0,A3
	bra.s .nvm_copy_buf
.loop_nvm_copy_buf:
		cmp.w #48,D0
		bcc.s .end_nvm_copy_buf 
		move.b (A3)+,(A0)+
		addq.w #1,D0	
.nvm_copy_buf:
	dbf D1,.loop_nvm_copy_buf
.end_nvm_copy_buf:
	unlk A6
#ifdef COLDFIRE
	movem.l (SP),D1-D4/A0-A3
	lea 32(SP),SP
#else
	movem.l (SP)+,D1-D4/A0-A3
#endif
	moveq #0,D0
	rts
.nvm_read:
	unlk A6
#ifdef COLDFIRE
	movem.l (SP),D1-D4/A0-A3
	lea 32(SP),SP
#else
	movem.l (SP)+,D1-D4/A0-A3
#endif
	moveq #-5,D0             // error
	move.w 4(SP),D1          // mode
.nvram_access:
#if defined(COLDFIRE) && !defined(MCF547X)
	ext.l D1
	bne .no_nvm_read
#ifdef DEBUG
	lea debug1r(PC),A0
	bsr debug_display_string	
	move.w 6(SP),D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w 8(SP),D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l 10(SP),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	move.w 6(SP),D0          // start
	move.w 8(SP),D1          // size
	move.l 10(SP),A0         // buffer
	ext.l D0
	ext.l D1
	lea pseudo_nvram_data,A1
	add.l D0,A1
	add.l D1,D0
.read_nvm:
		cmp.l #48,D0
		bcc .end_nvm_read_write
		move.b (A1)+,(A0)+
		addq.l #1,D0
	subq.l #1,D1
	bgt.s .read_nvm
	bra .end_nvm_read_write
.no_nvm_read:
	cmp.l #1,D1
	bne .no_write_nvm
#ifdef DEBUG
	lea debug1w(PC),A0
	bsr debug_display_string
	move.w 6(SP),D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w 8(SP),D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l 10(SP),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	move.w 6(SP),D0          // start
	move.w 8(SP),D1          // size
	move.l 10(SP),A0         // buffer
	ext.l D0
	ext.l D1
	lea pseudo_nvram_data,A1
	add.l D0,A1
	add.l D1,D0
.write_nvm:
		cmp.l #48,D0
		bcc.s .end_nvm_read_write
		move.b (A0)+,(A1)+
		addq.l #1,D0
	subq.l #1,D1
	bgt.s .write_nvm
	bra.s .end_nvm_read_write
.no_write_nvm:
	cmp.l #2,D1
	bne.s .end_nvm
#ifdef DEBUG
	lea debug1c(PC),A0
	bsr debug_display_string	
#endif
	lea pseudo_nvram_data,A0
	moveq #47,D0
.clear_nvram:
		clr.b (A0)+
	subq.l #1,D0
	bpl.s .clear_nvram
.end_nvm_read_write:
	moveq #0,D0
.end_nvm:
	rts
#else /* ATARI - FIREBEE */
#if defined(COLDFIRE) && defined(MCF547X) /* FIREBEE */
	cmp.l #1,D1              // write nvm
	bne .no_write_nvm
	lea -20(SP),SP
	movem.l D1-D2/A0-A2,(SP)
	lea 0xFFFF8961,A1        // F030 RTC (offset 0) / NVM (offset 14) - FPGA emulation
	lea 0xFFFF8963,A2
	moveq #0,D0
	moveq #14,D1
	moveq #0,D2
.loop_sum_nvram:
		move.b D1,(A1)
		move.b (A2),D2
		add.l D2,D0
		addq.l #1,D1
	cmp.l #64-2,D1
	bcs.s .loop_sum_nvram
	and.l #0xFF,D0
	move.l D0,D1
	moveq #-12,D0            // error
	move.b #63,(a1)
	move.b (A2),D2
	cmp.l D2,D1
	bne .write_nvm_error
	eor.l #0xFF,D1
	move.b #62,(A1)
	move.b (A2),D2
	cmp.l D2,D1
	bne .write_nvm_error
	moveq #-5,d0             // error
	move.w 6+20(SP),D1       // start
	cmp.l #48,D1
	bcc .write_nvm_error
	move.w 8+20(SP),D2       // size
	bmi .write_nvm_error
	add.l D1,D2
	cmp.l #48,D2
	bhi .write_nvm_error
	move.w 6+20(SP),D1       // start
	add.l #14,D1             // offset
	move.w 8+20(SP),D2       // size
	move.l 10+20(SP),A0      // buffer
	bra.s .next_write_nvm
.loop_write_nvm:
		move.b D1,(A1)
		move.b (A0)+,(A2)
		addq.l #1,D1
.next_write_nvm:
	subq.l #1,D2
	bpl.s .loop_write_nvm
	moveq #0,D0
	moveq #14,D1
	moveq #0,D2
.loop_sum_nvram2:
		move.b D1,(A1)
		move.b (A2),D2
		add.l D2,D0
		addq.l #1,D1
	cmp.l #64-2,D1
	bcs.s .loop_sum_nvram2
	move.b #63,(A1)
	move.b D0,(A2)
	not.l D0
	move.b #62,(A1)          // update sum
	move.b D0,(A2)
#ifdef DEBUG
	lea debug56(PC),A0
	bsr debug_display_string	
#endif
	move.b #0x82,D0          // header
	move.b D0,MCF_UART_UTB3  // data	
	moveq #0,D1
.write_nvm_to_pic:
		move.b MCF_UART_USR3,D0
		and.l #MCF_UART_USR_TXEMP,D0
		beq.s .write_nvm_to_pic // full
		move.b D1,(A1) // index
		move.b (A2),D0 // data
		move.b D0,MCF_UART_UTB3  // send data
		addq.l #1,D1
	cmp.l #64,D1
	bcs.s .write_nvm_to_pic
	moveq #0,D0              // OK
.write_nvm_error:
	movem.l (SP),D1-D2/A0-A2
	lea 20(SP),SP
	rts
.no_write_nvm:
	tst.l D1
#endif /* defined(COLDFIRE) && defined(MCF547X) */
	jmp 0xE02172             // NVMaccess
#endif /* defined(COLDFIRE) && !defined(MCF547X) */
	
test_rtc:

#if defined(COLDFIRE) && !defined(MCF547X)
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug23(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#else /* ATARI - FIREBEE */
	movem.l D0-D2,-(SP)
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SAVE_NVRAM_1,D1 // type_param
	moveq #0,D2              // value
#ifdef COLDFIRE
	jsr fire_rw_param
#else
	jsr ct60_rw_param 
#endif
	swap D0
	cmp.w #0x4E56,D0         // NV magic code
	movem.l (SP)+,D0-D2
	bne .use_rtc
#endif /* defined(COLDFIRE) && !defined(MCF547X) */
	or.b #1,CCR              // use IKBD clock
	rts
#if !defined(COLDFIRE) || defined(MCF547X)
.use_rtc:
	and.b #0xFE,CCR          // use RTC clock
	rts
#endif

#if defined(COLDFIRE) && defined(MCF547X)
end_settime_rtc:

	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
	lea 0xFFFF8961,A1        // F030 RTC (offset 0) / NVM (offset 14) - FPGA emulation
	lea 0xFFFF8963,A2
	move.b #0xE,(A2)
#ifdef DEBUG
	lea debug56(PC),A0
	bsr debug_display_string	
#endif
	move.b #0x82,D0          // header
	move.b D0,MCF_UART_UTB3  // data	
	moveq #0,D1
.write_rtc_to_pic:
		move.b MCF_UART_USR3,D0
		and.l #MCF_UART_USR_TXEMP,D0
		beq.s .write_rtc_to_pic // full
		move.b D1,(A1) // index
		move.b (A2),D0 // data
		move.b D0,MCF_UART_UTB3  // send data to PIC
		addq.l #1,D1
	cmp.l #64,D1
	bcs.s .write_rtc_to_pic
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
	rts
#endif /* defined(COLDFIRE) && defined(MCF57X) */
	
fix_settime:

	move.b D2,D0
	and.w #0x7F,D0           // 1980
	add.w #80,D0
	cmp.w #100,D0
	bcs.s .year_before_2000_settime
	sub.w #100,D0
.year_before_2000_settime:
	rts
	
#ifdef COLDFIRE

#ifdef MCF547X

fix_gettime:

	sub.b #80,D0             // 1980
	bpl.s .year_before_2000_gettime
	add.b #100,D0
.year_before_2000_gettime:
	move.b D0,D2
	rts

#endif /* MCF547X */

#else /* ATARI -CT60 */

fix_gettime:

	sub.b #80,D0             // 1980
	bpl.s .year_before_2000_gettime
	add.b #100,D0
.year_before_2000_gettime:
	move.b D0,D2
	rts

#endif /* COLDFIRE */

power_key:

	move.l D0,-(SP)
	move.l A0,-(SP)
	move.l phystop,A0
	move.l #0xCAFEFADE,D0
	move.l D0,power_flag(A0) // tested inside evnt_multi AES
	move.l (SP)+,A0
	move.l (SP)+,D0
	rts

new_ikbdvect:                // test Eiffel keys

#ifdef COLDFIRE
	.chip 5200
	and.l #0xFF,D0
	move.l D0,D1
	bclr #7,D1
	cmp.l #0x45,D1           // PAGE UP
	bne.s .test_page_down
	btst #7,D0
	bne.s .break_page_up
	move.b 0x1187,D0 
	bset #0,D0               // SHIFT
	move.b D0,0x1187
	move.b #0x48,D0          // ^
	bra .test_shift
.break_page_up:
	move.b 0x1187,D0 
	bclr #0,D0               // SHIFT
	move.b D0,0x1187
	move.b #0xC8,D0          // ^
	bra .test_shift
.test_page_down:
	cmp.l #0x46,D1           // PAGE DOWN
	bne.s .test_print_screen
	btst #7,D0
	bne.s .break_page_down
	move.b 0x1187,D0 
	bset #0,D0               // SHIFT
	move.b D0,0x1187
	move.b #0x50,D0          // v
	bra .test_shift
.break_page_down:
	move.b 0x1187,D0 
	bclr #0,D0               // SHIFT
	move.b D0,0x1187
	move.b #0xD0,D0          // v
	bra .test_shift	
.test_print_screen:
	cmp.l #0x49,D1           // PRINT SCREEN
	bne.s .test_power
	btst #7,D0
	bne.s .break_print_screen
	move.b 0x1187,D0 
	bset #3,D0               // ALT
	move.b D0,0x1187
	move.b #0x62,D0          // HELP
	bra.s .test_shift
.break_print_screen:
	move.b 0x1187,D0 
	bclr #3,D0               // ALT
	move.b D0,0x1187
	move.b #0xE2,D0          // HELP
	bra.s .test_shift
.test_power:
	cmp.l #0x73,D1           // POWER
	bne.s .test_shift
	btst #7,D0
	bne.s .test_shift
	bsr power_key
.test_shift:
	move.b 0x1187,D1         // Shift state
	cmp.l #0x2A,D0	
#else
	move.b D0,D1
	bclr #7,D1
	cmp.b #0x45,D1           // PAGE UP
	bne.s .test_page_down
	btst #7,D0
	bne.s .break_page_up
	bset.b #0,0x1187         // SHIFT
	move.b #0x48,D0          // ^
	bra .test_shift
.break_page_up:
	bclr.b #0,0x1187         // SHIFT
	move.b #0xC8,D0          // ^
	bra .test_shift
.test_page_down:
	cmp.b #0x46,D1           // PAGE DOWN
	bne.s .test_print_screen
	btst #7,D0
	bne.s .break_page_down
	bset.b #0,0x1187         // SHIFT
	move.b #0x50,D0          // v
	bra .test_shift
.break_page_down:
	bclr.b #0,0x1187         // SHIFT
	move.b #0xD0,D0          // v
	bra .test_shift	
.test_print_screen:
	cmp.b #0x49,D1           // PRINT SCREEN
	bne.s .test_power
	btst #7,D0
	bne.s .break_print_screen
	bset.b #3,0x1187         // ALT
	move.b #0x62,D0          // HELP
	bra.s .test_shift
.break_print_screen:
	bclr.b #3,0x1187         // ALT
	move.b #0xE2,D0          // HELP
	bra.s .test_shift
.test_power:
	cmp.b #0x73,D1           // POWER
	bne.s .test_shift
	btst #7,D0
	bne.s .test_shift
	bsr power_key
.test_shift:
	move.b 0x1187,D1         // Shift state
	cmp.b #0x2A,D0
#endif /* COLDFIRE */
	rts

new_statvec:

	move.l A0,-(SP)
	lea det_statvec(PC),A0
	move.l A0,0x1142
	move.l #0xE02750,D0
	move.l (SP)+,A0
	rts

	dc.l 0x58425241          // XBRA
#ifdef COLDFIRE
	dc.l 0x5F43465F          // _CF_
#else
	dc.l 0x43543630          // CT60
#endif
	dc.l 0x00E02750          // RTS
	
det_statvec:

#ifdef COLDFIRE
	move.l D0,-(SP)
             moveq #0,D0
             move.b (A0),D0
#else
	cmp.b #0x05,(A0)
	bne .no_eiffel_key
	movem.l D0/A0,-(SP)
	cmp.b #0x73,6(A0)        // POWER
	bne.s .not_power
	bsr power_key
	bra .not_volume_down
.not_power:
	cmp.b #0x32,6(A0)        // VOLUME UP
	bne.s .not_volume_up
	move.w #-1,-(SP)
	clr.w -(SP)              // LTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	sub.w #0x10,D0
	and.w #0xF0,D0
	cmp.w #0xF0,D0
	bne.s .not_lmax
	moveq #0,D0
.not_lmax:
	move.w D0,-(SP)
	clr.w -(SP)              // LTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	move.w #-1,-(SP)
	move.w #1,-(SP)          // RTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	sub.w #0x10,D0
	and.w #0xF0,D0
	cmp.w #0xF0,D0
	bne.s .not_rmax
	moveq #0,D0
.not_rmax:
	move.w D0,-(SP)
	move.w #1,-(SP)          // RTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	bra.s .not_volume_down
.not_volume_up:
	cmp.b #0x21,6(A0)        // VOLUME DOWN
	bne.s .not_volume_down
	move.w #-1,-(SP)
	clr.w -(SP)              // LTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	add.w #0x10,D0
	and.w #0xF0,D0
	bne.s .not_lmin
	move.w #0xF0,D0
.not_lmin:
	move.w D0,-(SP)
	clr.w -(SP)              // LTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	move.w #-1,-(SP)
	move.w #1,-(SP)          // RTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
	add.w #0x10,D0
	and.w #0xF0,D0
	bne.s .not_rmin
	move.w #0xF0,D0
.not_rmin:
	move.w D0,-(SP)
	move.w #1,-(SP)          // RTATTEN
	jsr 0xE0620C             // soundcmd
	addq.l #4,SP
.not_volume_down:	
	movem.l (SP)+,D0/A0
	bra.s .not_read_memory
.no_eiffel_key:
#endif /* COLDFIRE */
#ifdef COLDFIRE
             cmp.l #0x20,D0
	bne.s .not_read_memory
	lea -12(SP),SP
	movem.l A0-A2,(SP)
	move.l phystop,A2
	move.l flag_statvec(A2),D0
	cmp.l #0xCAFEFADE,D0
#else
	cmp.b #0x20,(A0)
	bne.s .not_read_memory
	movem.l A0-A2,-(SP)
	move.l phystop,A2
	cmp.l #0xCAFEFADE,flag_statvec(A2)
#endif
	bne.s .not_read_memory
	move.l pbuf_statvec(A2),A1
	addq.l #1,A0
	move.b (A0)+,(A1)+
	move.b (A0)+,(A1)+
	move.b (A0)+,(A1)+
	move.b (A0)+,(A1)+
	move.b (A0)+,(A1)+		
	move.b (A0)+,(A1)+
	move.l A1,pbuf_statvec(A2)
#ifdef COLDFIRE
	movem.l (SP),A0-A2
	lea 12(SP),SP
.not_read_memory:	
	move.l (SP)+,D0
#else
	movem.l (SP)+,A0-A2
.not_read_memory:	
#endif
	rts

