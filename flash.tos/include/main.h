/*  Flashing tool for the CT60 board
 *  Copyright (C) 2000 Xavier Joubert
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *
 *  To contact author write to Xavier Joubert, 5 Cour aux Chais, 44 100 Nantes,
 *  FRANCE or by e-mail to xavier.joubert@free.fr.
 *
 */

#ifndef	_MAIN_H
#define	_MAIN_H	1

#define VERSION 0x0099

#define Bit32u unsigned long
#define Bit32s signed long
#define Bit16u unsigned short
#define Bit16s signed short
#define Bit8u unsigned char
#define Bit8s signed char

#define RESERVE_MEM_FONTS 0x8000
#define RESERVE_MEM 0x60000

#define FLASH_ADR  0x00E00000
#define FLASH_SIZE 0x00100000
#define PARAM_SIZE (64*1024)

#define	MAX_ERROR_LENGTH	256

#endif /* _MAIN_H */
