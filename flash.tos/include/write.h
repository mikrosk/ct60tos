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

#ifndef	_WRITE_H
#define	_WRITE_H	1

#define CMD_UNLOCK1	0xAA
#define CMD_UNLOCK2	0x55
#define CMD_SECTOR_ERASE1	0x80
#define CMD_SECTOR_ERASE2	0x30
#define CMD_PROGRAM	0xA0
#define CMD_AUTOSELECT	0x90
#define CMD_READ	0xF0

int detect_flash(Bit32u*, Bit8u*, Bit8u*, Bit8u*);
int erase_flash(t_sector*);
int program_flash(t_sector*, Bit8u*, Bit32u);
int verify_flash(Bit8u*, Bit32u);

#endif /* _WRITE_H */
