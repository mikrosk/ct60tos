/* TOS 4.04 Xbios vars for the CT60 board
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

#ifndef	_VARS_H
#define	_VARS_H

#define etv_critic 0x404
#define memvalid   0x420
#define memctrl    0x424
#define resvalid   0x426
#define resvector  0x42A
#define phystop    0x42E
#define _memtop    0x436
#define memval2    0x43A
#define flock      0x43E
#define _bootdev   0x446
#define sshiftmd   0x44C
#define _v_bas_ad  0x44E
#define _frclock   0x466	
#define hdv_rw     0x476
#define hdv_boot   0x47A
#define _cmdload   0x482
#define trp14ret   0x486
#define __md       0x49E
#define _hz_200    0x4BA
#define _drvbits   0x4C2
#define _dskbufp   0x4C6
#define _sysbase   0x4F2
#define exec_os    0x4FE
#define memval3    0x51A
#define cookie     0x5A0
#define ramtop     0x5A4
#define ramvalid   0x5A8

// line A offset vars
#define dev_tab -692
#define v_cel_ht -46
#define v_cel_mx -44
#define v_cel_my -42
#define v_cel_wr -40
#define v_rez_hz -12
#define v_cel_vt -4
#define bytes_ln -2
#define v_lin_wr  2

#define power_flag    -68
#define flag_statvec  -64
#define pbuf_statvec  -60
#define count_io3_mfp -54
#define start_hz_200  -52
#define flag_cache    -48
#define save_hz_200   -44
#define save_source   -40
#define save_target   -36
#define save_contrl   -32
#define adr_source    -28
#define adr_target    -24
#define adr_fonts     -20

#endif
