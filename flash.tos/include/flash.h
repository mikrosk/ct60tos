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

#ifndef	_FLASH_H
#define	_FLASH_H	1

#define	FLASH_UNLOCK1	(FLASH_ADR+0xAAA)
#define	FLASH_UNLOCK2	(FLASH_ADR+0x554)

typedef struct
{
  Bit32u start_adr;
  Bit32u unlock1;
  Bit32u unlock2;
} t_sector;

t_sector fujitsu_mbm29f400bc_sectors[] =
{
  {FLASH_ADR+0x00000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x04000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x06000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x08000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x10000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x20000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x30000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x40000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x50000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x60000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x70000, FLASH_UNLOCK1, FLASH_UNLOCK2},

  {FLASH_ADR+0x80000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0x84000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0x86000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0x88000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0x90000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0xA0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0xB0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0xC0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0xD0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0xE0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},
  {FLASH_ADR+0xF0000, FLASH_UNLOCK1+0x80000, FLASH_UNLOCK2+0x80000},

  {FLASH_ADR+0x100000, 0, 0}
};

t_sector fujitsu_mbm29f800ba_sectors[] =
{
  {FLASH_ADR+0x00000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x04000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x06000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x08000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x10000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x20000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x30000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x40000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x50000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x60000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x70000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x80000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0x90000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0xA0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0xB0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0xC0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0xD0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0xE0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {FLASH_ADR+0xF0000, FLASH_UNLOCK1, FLASH_UNLOCK2},

  {FLASH_ADR+0x100000, 0, 0}
};

struct
{
  Bit32u device;
  t_sector *sectors;
} supported_devices[] =
{
  {0x000422AB, fujitsu_mbm29f400bc_sectors},
  {0x00042258, fujitsu_mbm29f800ba_sectors},

  {0, NULL}
};

void flash_exit(int);
void flash_error(char*, char*);
void write_flash(Bit8u*, Bit32u);
void protect_tos(void);
void load_file(char*, Bit8u**, Bit32u*);
int main(int, char**);

#endif /* _FLASH_H */
