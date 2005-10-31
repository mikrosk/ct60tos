/* $XFree86: xc/programs/Xserver/hw/xfree86/drivers/ati/radeon_cursor.c,v 1.26 2003/11/10 18:41:22 tsi Exp $ */
/*
 * Copyright 2000 ATI Technologies Inc., Markham, Ontario, and
 *                VA Linux Systems Inc., Fremont, California.
 *
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation on the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the
 * next paragraph) shall be included in all copies or substantial
 * portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NON-INFRINGEMENT.  IN NO EVENT SHALL ATI, VA LINUX SYSTEMS AND/OR
 * THEIR SUPPLIERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/*
 * Authors:
 *   Kevin E. Martin <martin@xfree86.org>
 *   Rickard E. Faith <faith@valinux.com>
 *
 * References:
 *
 * !!!! FIXME !!!!
 *   RAGE 128 VR/ RAGE 128 GL Register Reference Manual (Technical
 *   Reference Manual P/N RRG-G04100-C Rev. 0.04), ATI Technologies: April
 *   1999.
 *
 *   RAGE 128 Software Development Manual (Technical Reference Manual P/N
 *   SDK-G04000 Rev. 0.01), ATI Technologies: June 1999.
 *
 */

#include "radeonfb.h"

#define CURSOR_WIDTH	64
#define CURSOR_HEIGHT	64

/*
 * The cursor bits are always 32bpp.  On MSBFirst buses,
 * configure byte swapping to swap 32 bit units when writing
 * the cursor image.  Byte swapping must always be returned
 * to its previous value before returning.
 */
#define CURSOR_SWAPPING_DECL_MMIO
#define CURSOR_SWAPPING_DECL	    unsigned long  __surface_cntl=0;
#define CURSOR_SWAPPING_START() \
	if(rinfo->big_endian) \
    OUTREG(SURFACE_CNTL, \
	   ((__surface_cntl = INREG(SURFACE_CNTL)) | \
	    NONSURF_AP0_SWP_32BPP) & \
	   ~NONSURF_AP0_SWP_16BPP);
#define CURSOR_SWAPPING_END() \
	if(rinfo->big_endian) \
	(OUTREG(SURFACE_CNTL, __surface_cntl));

/* Set cursor foreground and background colors */
void RADEONSetCursorColors(struct radeonfb_info *rinfo, int bg, int fg)
{
	unsigned long *pixels = (unsigned long *)(pointer)(rinfo->fb_local_base + rinfo->cursor_start);
	int pixel, i;
	CURSOR_SWAPPING_DECL_MMIO
	CURSOR_SWAPPING_DECL
	fg |= 0xff000000;
	bg |= 0xff000000;
	/* Don't recolour the image if we don't have to. */
	if(fg == rinfo->cursor_fg && bg == rinfo->cursor_bg)
		return;
	CURSOR_SWAPPING_START();
	/* Note: We assume that the pixels are either fully opaque or fully
	 * transparent, so we won't premultiply them, and we can just
	 * check for non-zero pixel values; those are either fg or bg
	 */
	for(i = 0; i < CURSOR_WIDTH * CURSOR_HEIGHT; i++, pixels++)
		if((pixel = *pixels))
			*pixels = (pixel == rinfo->cursor_fg) ? fg : bg;
	CURSOR_SWAPPING_END();
	rinfo->cursor_fg = fg;
	rinfo->cursor_bg = bg;
}

void RADEONSetCursorPosition(struct radeonfb_info *rinfo, int x, int y)
{
	OUTREG(CUR_HORZ_VERT_OFF, (CUR_LOCK  | (x << 16) | y));
	OUTREG(CUR_HORZ_VERT_POSN, (CUR_LOCK | ((x ? 0 : x) << 16) | (y ? 0 : y)));
	OUTREG(CUR_OFFSET, rinfo->cursor_start + y * 256);
}

/* Copy cursor image from `image' to video memory.  RADEONSetCursorPosition
 * will be called after this, so we can ignore xorigin and yorigin.
 */
void RADEONLoadCursorImage(struct radeonfb_info *rinfo, unsigned short *mask, unsigned short *data)
{
	unsigned long *d = (unsigned long *)(pointer)(rinfo->fb_base + rinfo->cursor_start);
	unsigned long save = 0;
	unsigned short chunk,mchunk;
	unsigned long i, j, k;
	CURSOR_SWAPPING_DECL
	save = INREG(CRTC_GEN_CNTL) & ~(unsigned long) (3 << 20);
	save |= (unsigned long) (2 << 20);
	OUTREG(CRTC_GEN_CNTL, save & (unsigned long)~CRTC_CUR_EN);
	/*
	 * Convert the bitmap to ARGB32.
	 */
	CURSOR_SWAPPING_START();
#define ARGB_PER_CHUNK	(8 * sizeof (chunk))
	for(i = 0; i < CURSOR_HEIGHT; i++)
	{
		mchunk = *mask++;
		chunk = *data++;
		for(j = 0; j < CURSOR_WIDTH/ ARGB_PER_CHUNK; j++)
		{
			for(k = 0; k < ARGB_PER_CHUNK; k++, chunk <<= 1, mchunk <<= 1)
			{
				if(mchunk & 0x8000)
				{
					if(chunk & 0x8000)
						*d++ = 0xff000000; /* Black, fully opaque. */				
					else
						*d++ = 0xffffffff; /* White, fully opaque. */
				}			
				else
						*d++ = 0x00000000; /* White/Black, fully transparent. */			
			}
		}
	}
	CURSOR_SWAPPING_END();
	rinfo->cursor_bg = 0xffffffff; /* White, fully opaque. */
	rinfo->cursor_fg = 0xff000000; /* Black, fully opaque. */		
	OUTREG(CRTC_GEN_CNTL, save);
}

/* Hide hardware cursor. */
void RADEONHideCursor(struct radeonfb_info *rinfo)
{
	OUTREGP(CRTC_GEN_CNTL, 0, ~CRTC_CUR_EN);
}

/* Show hardware cursor. */
void RADEONShowCursor(struct radeonfb_info *rinfo)
{
	OUTREGP(CRTC_GEN_CNTL, CRTC_CUR_EN, ~CRTC_CUR_EN);
}

/* Initialize hardware cursor support. */
long RADEONCursorInit(struct radeonfb_info *rinfo)
{
	long fbarea;
	int size_bytes;
	size_bytes = CURSOR_WIDTH * 4 * CURSOR_HEIGHT;
	fbarea = radeon_offscreen_alloc(rinfo,size_bytes+256);
	if(!fbarea)
		rinfo->cursor_start    = 0;
	else
	{
		rinfo->cursor_start = RADEON_ALIGN(fbarea, 256);
		rinfo->cursor_end = rinfo->cursor_start + size_bytes;
	}
	return(rinfo->cursor_start ? fbarea : 0);
}
