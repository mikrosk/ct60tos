#ifndef __flash_H
#define __flash_H
/* Flashing CT60 / CTPCI and Firebee
*  Didier Mequignon 2005-2010, e-mail: aniplay@wanadoo.fr
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
*/

#define FLASH_ADR  0xFFE00000
#define FLASH_SIZE 0x100000
#define PARAM_SIZE 0x10000

#define FLASH_ADR_CF     0xE0000000
#define FLASH_ADR_TOS_CF 0xE0400000
#define FLASH_SIZE_CF    0x00800000

#endif
