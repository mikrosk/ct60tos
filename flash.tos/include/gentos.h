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

#ifndef	_GENTOS_H
#define	_GENTOS_H	1

#define TOS4_SIZE	(512*1024)

void gentos_error(char*, char*);
Bit32u apply_patch(Bit8u*, Bit8u*);
Bit32u modify_tos(Bit8u*);
Bit32u load_file(char*, Bit8u*, Bit32u);
void load_tos(char*, Bit8u*, Bit32u);
void save_tos(char*, Bit8u*, Bit32u);
int main(int, char**);

#endif	/* _GENTOS_H */
