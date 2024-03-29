/*
 * Filename:     gs.h
 * Project:      GlueSTiK
 * 
 * Note:         Please send suggestions, patches or bug reports to me
 *               or the MiNT mailing list <mint@fishpool.com>.
 * 
 * Copying:      Copyright 1999 Frank Naumann <fnaumann@cs.uni-magdeburg.de>
 * 
 * Portions copyright 1997, 1998, 1999 Scott Bigham <dsb@cs.duke.edu>
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef _gs_h
#define _gs_h

#include <stdlib.h>
#include <stdio.h>

#include "transprt.h"

#undef GS_DEBUG

#ifndef GS_DEBUG
#define PRINT_DEBUG(x)
#else
#if defined(COLDFIRE) && defined(LWIP)
extern void board_printf(const char *fmt, ...);
#define PRINT_DEBUG(x)	{ board_printf x; board_printf("\r\n"); }
#else
#include <mint/osbind.h>
extern void kprint(const char *fmt, ...);
#define PRINT_DEBUG(x)	{ long stack=0; if(Super(1L) >= 0) stack=Super(0L); kprint x; kprint("\r\n"); if(stack) Super((void *)stack); }
#endif
#endif

typedef unsigned char	uchar;

#endif /* _gs_h */
