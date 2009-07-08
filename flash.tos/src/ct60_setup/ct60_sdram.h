/*
	CT60 Setup
	SDRAM, I2C functions

	Copyright (C) 2009	Patrice Mandin

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef CT60_SDRAM_H
#define CT60_SDRAM_H 1

/*--- Defines ---*/

/* for ct60_read_info_sdram() function */

#define SDRAM_TYPE 2
#define SDRAM_ROWS 3
#define SDRAM_COLUMNS 4
#define SDRAM_DIMMS 5
#define SDRAM_WIDTH 6	/* offsets 6-7 */
#define SDRAM_VOLTAGE 8
#define SDRAM_CYCLE 9
#define SDRAM_ACCESS 10
#define SDRAM_CONFIG 11
#define SDRAM_REFRESH 12
#define SDRAM_BANKS 17
#define SDRAM_ATTRIBS 21
#define SDRAM_PRECHARGE 27
#define SDRAM_ACTIVE 28
#define SDRAM_RASCAS 29
#define SDRAM_DENSITY 31
#define SDRAM_MAN_ID 64 /* offsets 64-71 */
#define SDRAM_MAN_DATE 93	/* offsets 93-94 */

/*--- Functions prototypes ---*/

long ct60_rw_clock(short mode, short address, short data);
long ct60_read_info_clock(char buffer[128]);
long ct60_read_info_sdram(char buffer[128]);

#endif /* CT60_SDRAM_H */
