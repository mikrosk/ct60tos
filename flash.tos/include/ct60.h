/* TOS 4.04 Xbios for the CT60 board
*  Didier Mequignon 2002 December, e-mail: aniplay@wanadoo.fr
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
#define CT60_CACHE_DELAY 2
#define CT60_BOOT_ORDER 3
#define CT60_CPU_FPU 4
#define CT60_SAVE_NVRAM_1 7
#define CT60_SAVE_NVRAM_2 8
#define CT60_SAVE_NVRAM_3 9
#define CT60_PARAM_OFFSET_TLV 10
#define CT60_ABE_CODE 11
#define CT60_SDR_CODE 12

#define ct60_read_core_temperature(type_deg) (long)trap_14_ww((short)(0xc60a),(short)(type_deg))
#define	ct60_rw_parameter(mode,type_param,value) (long)trap_14_wwll((short)(0xc60b),(short)(mode),(long)(type_param),(long)(value))
#define ct60_cache(cache_mode) (long)trap_14_ww((short)(0xc60c),(short)(cache_mode))
#define ct60_flush_cache() (long)trap_14_ww((short)(0xc60d))

#endif	_CT60_H
