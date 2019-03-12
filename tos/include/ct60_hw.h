/*  CT60 board
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

#ifndef	CT60_HW_H_
#define	CT60_HW_H_

#define RESERVE_MEM_FONTS  0x8000
#define RESERVE_MEM       0x60000

#define PARAM_SIZE	(64*1024)	/* 64 KB */
#define FLASH_SIZE  (1024*1024)	/* 1MB */

#define TOS4_SIZE	(512*1024)	/* 512 KB */

#define FLASH_ADR	0x00E00000	/* TOS area (2x512 KB) */
#define TESTS_SIZE  (128*1024)	/* 128 KB */

#define FLASH_ADR2  0x00FC0000	/* TOS 1.x area (192 KB) */
#define FLASH_SIZE2 (192*1024)	/* 192 KB */

#endif
