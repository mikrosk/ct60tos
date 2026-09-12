/* TOS 4.04 Xbios for the CT60 board
*  Didier Mequignon 2002-2005, e-mail: aniplay@wanadoo.fr
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

#ifndef	_CT60_H
#define	_CT60_H

#define ID_CT60 (long)'CT60'
#define MSG_CT60_TEMP 0xcc60
#define CT60_CELCIUS 0
#define CT60_FARENHEIT 1
#define CT60_MODE_READ 0
#define CT60_MODE_WRITE 1
#define CT60_PARAM_TOSRAM 0
#define CT60_BLITTER_SPEED 1
#define CT60_BOOT_ORDER 3
#define CT60_CPU_FPU 4
#define CT60_BOOT_LOG 5
#define CT60_SAVE_NVRAM_1 7
#define CT60_SAVE_NVRAM_2 8
#define CT60_SAVE_NVRAM_3 9
#define CT60_PARAM_OFFSET_TLV 10
#define CT60_ABE_CODE 11
#define CT60_SDR_CODE 12
#define CT60_CLOCK 13

/* SuperVidel settings, written by the CT60 CPX and read by the SuperVidel
   driver. They mirror the keys of the driver's SV.INF. */

#define CT60_SV_AES_MODES 2    /* default mode code << 16 | forced mode code */
#define CT60_SV_CONFIG 6       /* boot mode code << 16 | the flags below */
#define CT60_SV_RESTRICT 14    /* VDI width << 16 | VDI height, 0 for no limit */

#define CT60_SV_BPS8C 0x0001         /* 8 bit chunky in the TOS VDI */
#define CT60_SV_BPS32 0x0002         /* 32 bit true colour in the TOS VDI */
#define CT60_SV_CLONE 0x0004         /* screen sent to both outputs at once */
#define CT60_SV_REZDIALOG 0x0008     /* extended desktop video dialog */
#define CT60_SV_FAST_VIDEL 0x0010    /* Videl resolutions accelerated in GEM */
#define CT60_SV_KILL_VIDEL 0x0020    /* Videl off in SuperVidel resolutions */
#define CT60_SV_PMMU_BOOST 0x0040    /* higher CPU to VRAM bandwidth */
#define CT60_SV_DVI 0x0080           /* primary output, 0: VGA, 1: DVI */
#define CT60_SV_DUAL 0x0300          /* dual screen, 0: off, 1: vertical, 2: horizontal */
#define CT60_SV_DUAL_SHIFT 8
#define CT60_SV_VERSION 0x1000       /* layout version, 0: never written, 0xf: erased */
#define CT60_SV_VERSION_MASK 0xf000

#define ct60_read_core_temperature(type_deg) (long)trap_14_ww((short)(0xc60a),(short)(type_deg))
#define	ct60_rw_parameter(mode,type_param,value) (long)trap_14_wwll((short)(0xc60b),(short)(mode),(long)(type_param),(long)(value))
#define ct60_cache(cache_mode) (long)trap_14_ww((short)(0xc60c),(short)(cache_mode))
#define ct60_flush_cache() (long)trap_14_ww((short)(0xc60d))

#endif	/* _CT60_H */
