/* TOS 4.04 Xbios calls for the CT60/CTPCI boards
 * Coldfire Xbios AC97 Sound 
 * Didier Mequignon 2005-2009, e-mail: aniplay@wanadoo.fr
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "config.h" 
#include <mint/osbind.h>
#include <mint/falcon.h>
#include <string.h>
#include <sysvars.h>
#include "radeon/fb.h"
#include "radeon/radeonfb.h"
#include "ct60.h"
#ifdef NETWORK
#ifdef COLDFIRE
#ifndef MCF5445X
#include "ac97/mcf548x_ac97.h"
#endif
#endif
#endif

#ifdef TEST_NOPCI
#ifndef Screalloc
#define Screalloc(size) (void *)trap_1_wl((short)(0x15),(long)(size))
#endif
extern void init_var_linea(void);
extern void init_videl_320_240_65K(unsigned short *screen_addr);
extern void init_videl_640_480_65K(unsigned short *screen_addr);
#endif
   
#define Modecode (*((short*)0x184C))

extern const struct fb_videomode modedb[];
extern const struct fb_videomode vesa_modes[];
extern long total_modedb;

unsigned long physbase(void);
long vgetsize(long modecode);

extern void ltoa(char *buf, long n, unsigned long base);                                    
extern void init_var_linea(void);
extern void cursor_home(void);

typedef struct
{
	long ident;
	union
	{
		long l;
		short i[2];
		char c[4];
	} v;
} COOKIE;

extern COOKIE *get_cookie(long id);
extern int add_cookie(COOKIE *cook);

/* global */
extern struct radeonfb_info *rinfo_fvdi;
extern struct mode_option resolution;
extern short virtual;
long fix_modecode, second_screen, second_screen_aligned;

#undef SEMAPHORE

#ifndef TEST_NOPCI

#ifdef COLDFIRE
#ifdef NETWORK
#ifdef LWIP
extern void xSemaphoreTakeRADEON(void);
extern void xSemaphoreGiveRADEON(void);
#undef SEMAPHORE
#endif
#endif
#endif

static long bios_colors[256]; 

/* some XBIOS functions for the radeon driver */

void vsetrgb(long index, long count, long *array)
{
	short i;
	unsigned red,green,blue;
	struct fb_info *info;
#ifdef SEMAPHORE
	xSemaphoreTakeRADEON();
#endif
	info = rinfo_fvdi->info;
	for(i = index; i < (count + index); i++)
	{
		bios_colors[i] = *array;
		if(info->var.bits_per_pixel <= 8)
		{
			red = (*array>>16) & 0xFF;
			green = (*array>>8) & 0xFF;
			blue = *array & 0xFF;
			radeonfb_setcolreg((unsigned)i, red << 8, green << 8, blue << 8, 0, info);
		}
		array++;
	}
#ifdef SEMAPHORE
	xSemaphoreGiveRADEON();
#endif
}

void vgetrgb(long index, long count, long *array)
{
	short i;
	for(i = index; i < (count + index); i++)
		*array++ = bios_colors[i];
}

void display_composite_texture(long op, char *src_tex, long src_x, long src_y, long w_tex, long h_tex, long dst_x, long dst_y, long width, long height)
{
	struct fb_info *info = rinfo_fvdi->info;
	unsigned long dstFormat;
	switch(info->var.bits_per_pixel)
	{
		case 16: dstFormat = PICT_r5g6b5; break;
		case 32: dstFormat = PICT_x8r8g8b8; break;
		default: return;	
	}
	if(RADEONSetupForCPUToScreenTextureMMIO(rinfo_fvdi, (int)op, PICT_a8r8g8b8, dstFormat, src_tex, (int)w_tex << 2 , (int)w_tex, (int)h_tex, 0))
	{
		long x, y, x0 = dst_x;
		for(y = 0; y < height; y += h_tex)
		{
			int h = height - y;
			if(h >= h_tex)
				h = h_tex;
			dst_x = x0;
			for(x = 0; x < width; x += w_tex)
			{
				int w = width - x;
				if(w >= w_tex)
					w = w_tex;
				RADEONSubsequentCPUToScreenTextureMMIO(rinfo_fvdi, (int)dst_x, (int)dst_y, (int)src_x, (int)src_y, (int)w, (int)h);
				dst_x += w_tex;		
			}
			dst_y += h_tex;
		}
	}
}

void display_mono_block(char *src_buf, long dst_x, long dst_y, long w, long h, long foreground, long background, long src_wrap)
{
	int skipleft;
#ifdef SEMAPHORE
	xSemaphoreTakeRADEON();
#endif
	RADEONSetClippingRectangleMMIO(rinfo_fvdi, (int)dst_x, (int)dst_y, (int)w - 1, (int)h -1);
	skipleft = ((int)src_buf & 3) << 3;
	src_buf = (unsigned char*)((int)src_buf & ~3);
	dst_x -= skipleft;
	w += skipleft;
	RADEONSetupForScanlineCPUToScreenColorExpandFillMMIO(rinfo_fvdi, (int)foreground, (int)background, 3, 0xffffffff);
	RADEONSubsequentScanlineCPUToScreenColorExpandFillMMIO(rinfo_fvdi, (int)dst_x, (int)dst_y, (int)w, (int)h, (int)skipleft);
	while(--h >= 0)
	{
		RADEONSubsequentScanlineMMIO(rinfo_fvdi, (unsigned long*)src_buf);
		src_buf += src_wrap;
	}
	RADEONDisableClippingMMIO(rinfo_fvdi);
	radeonfb_sync(rinfo_fvdi->info);	
#ifdef SEMAPHORE
	xSemaphoreGiveRADEON();
#endif
}

long clear_screen(long bg_color, long x, long y, long w, long h)
{
	struct fb_info *info = rinfo_fvdi->info;
#ifdef SEMAPHORE
	xSemaphoreTakeRADEON();
#endif
	if(bg_color == -1)
	{
		x = y = 0;
		w = info->var.xres_virtual;
		h = info->var.yres_virtual;
		if(info->var.bits_per_pixel >= 16)
			RADEONSetupForSolidFillMMIO(rinfo_fvdi, 0, 15, 0xffffffff);  /* set */
		else
			RADEONSetupForSolidFillMMIO(rinfo_fvdi, 0, 0, 0xffffffff);   /* clr */
	}
	else if(bg_color == -2)
	{
		switch(info->var.bits_per_pixel)
		{
			case 8: bg_color = 0xff; break;
			case 16: bg_color = 0xffff; break;
			default: bg_color = 0xffffff; break;
		}
		RADEONSetupForSolidFillMMIO(rinfo_fvdi, (int)bg_color, 6, 0xffffffff);  /* xor */
	}
	else
		RADEONSetupForSolidFillMMIO(rinfo_fvdi, (int)bg_color, 3, 0xffffffff);  /* copy */
	RADEONSubsequentSolidFillRectMMIO(rinfo_fvdi, (int)x, (int)y, (int)w, (int)h);
	radeonfb_sync(rinfo_fvdi->info);
#ifdef SEMAPHORE
	xSemaphoreGiveRADEON();
#endif
	return(1);
}

long move_screen(long src_x, long src_y, long dst_x, long dst_y, long w, long h)
{
	int xdir, ydir;
#ifdef SEMAPHORE
	xSemaphoreTakeRADEON();
#endif
	xdir = (int)(src_x - dst_x);
	ydir = (int)(src_y - dst_y);
	RADEONSetupForScreenToScreenCopyMMIO(rinfo_fvdi, xdir, ydir, 3, 0xffffffff, -1);
	RADEONSubsequentScreenToScreenCopyMMIO(rinfo_fvdi, (int)src_x, (int)src_y, (int)dst_x, (int)dst_y, (int)w, (int)h);
	radeonfb_sync(rinfo_fvdi->info);
#ifdef SEMAPHORE
	xSemaphoreGiveRADEON();
#endif
	return(1);
}

long print_screen(char *character_source, long x, long y, long w, long h, long cell_wrap, long fg_color, long bg_color)
{
	static char buffer[256*16]; /* maximum width 2048 pixels, 256 characters, height 16 */
	static long pos_x, pos_y, length, height, foreground, background, old_timer;
	char *ptr;
	if(character_source == (char *)-1)
	{
		pos_x = -1;
		old_timer = *_hz_200;
	}
	else if(character_source)
	{
		if((pos_x >= 0) && ((pos_y != y) /* if line is different  => flush buffer */
		 || (*_hz_200 != old_timer)))
		{
			ptr = &buffer[pos_x];
			pos_x <<= 3;
			pos_y *= height;
			length <<= 3;
			display_mono_block(ptr, pos_x, pos_y, length, height, foreground, background, 256);
			pos_x = -1;
		}
		w >>= 3;
		if(pos_x < 0)
		{
			pos_x = x;        /* save starting pos */
			pos_y = y;
			length = 0;
			height = h;
			foreground = fg_color;
			background = bg_color;
		}
		if((x < 256) && (h <= 16))
		{
			ptr = &buffer[x]; /* store character inside a line buffer */
			switch(w)
			{
				case 0:
				case 1:
					while(--h >= 0)
					{
						*ptr = *character_source;
						character_source += cell_wrap;
						ptr += 256;
					}
					length++;
					break;
				default:
					while(--h >= 0)
					{
						*(short *)ptr = *(short *)character_source;
						character_source += cell_wrap;
						ptr += 256;
					}
					length += w;
					break;
			}
		}
	}
	else if(pos_x >= 0)   /* if character < ' ' => flush buffer */
	{
		ptr = &buffer[pos_x];
		pos_x <<= 3;
		pos_y *= height;
		length <<= 3;
		display_mono_block(ptr, pos_x, pos_y, length, height, foreground, background, 256);
		pos_x = -1;
	}
	old_timer = *_hz_200;
	return(1);
}

static unsigned long mul32(unsigned long a, unsigned long b) // GCC Colfire bug ???
{
	return(a * b);
}

void display_atari_logo()
{
#define WIDTH_LOGO 96
#define HEIGHT_LOGO 86
	unsigned long base_addr = (unsigned long)Physbase();
	struct fb_info *info = rinfo_fvdi->info;
	unsigned char *buf_tex = NULL;
	unsigned long *ptr32 = NULL;
	unsigned short *ptr16 = NULL;
	unsigned char *ptr8 = NULL;
	int i, j, k, cnt = 1;
	int bpp = info->var.bits_per_pixel;
	unsigned short val, color = 0, r, g, b;
	unsigned long color2 = 0, r2, g2, b2;
	unsigned long incr = mul32(info->var.xres_virtual, bpp >> 3);
//	unsigned long incr = (unsigned long)(info->var.xres_virtual * (bpp >> 3));
#ifndef TEST_NOPCI
	if(bpp >= 16)
	{
		buf_tex = (char *)Malloc(HEIGHT_LOGO * WIDTH_LOGO * 4);
		if(buf_tex != NULL)
		{
			incr = WIDTH_LOGO * 4;
			bpp = 32;
			cnt = 2;
		}
	}
	else
#endif
		base_addr += (incr * 4); // line 4
	while(--cnt >= 0)
	{
		unsigned short *logo_atari = (unsigned short *)0xE49434; /* logo ATARI monochrome inside TOS 4.04 */
#ifndef TEST_NOPCI
		if(buf_tex != NULL)
			base_addr = (unsigned long)buf_tex;
#endif
		g = 3;
		g2 = 3;
		for(i = 0; i < 86; i++) // lines
		{
			switch(bpp)
			{
				case 16:
					if(i < 56)
					{
						r = (unsigned short)((63 - i) >> 1) & 0x1F;
						if(i < 28)
							g++;
						else
							g--;
						b = (unsigned short)((i + 8) >> 1) & 0x1F;
						color = (r << 11) + (g << 6) + b;
					}
					else
						color = 0;
					ptr16 = (unsigned short *)base_addr;
					break;
				case 32:
					if(i < 56)
					{
						r2 = (unsigned long)(63 - i) & 0x3F;
						if(i < 28)
							g2++;
						else
							g2--;
						b2 = (unsigned long)(i + 8) & 0x3F;
						if((buf_tex != NULL) && cnt)
						{
							color2 = ((r2 << 15) & 0xFF0000) + (g2 << 8) + ((b2 >> 1) & 0xFF);
							color2 |= 0xE0E0E0;
						}
						else
							color2 = (r2 << 18) + (g2 << 11) + (b2 << 2);
					}
					else
					{
						if((buf_tex != NULL) && cnt)
							color2 = 0xE0E0E0;
						else
							color2 = 0;
					}
					if(buf_tex != NULL)
						color2 |= 0xFF000000; /* alpha */
					ptr32 = (unsigned long *)base_addr;
					break;
				default:
					ptr8 = (unsigned char *)base_addr;
					break;
			}
			for(j = 0; j < 6; j++)
			{
				switch(bpp)
				{
					case 8:
						val = *logo_atari++;
						for(k = 0x8000; k; k >>= 1)
						{
							if(val & k)
								*ptr8++ = 0xFF;
							else
								*ptr8++ = 0; 
						}		
						break; 
					case 16:
						val = *logo_atari++;
						for(k = 0x8000; k ; k >>= 1)
						{
							if(val & k)
								*ptr16++ = color;
							else
								*ptr16++ = 0xFFFF;
						}					
						break;
					case 32:
						val = *logo_atari++;
						for(k = 0x8000; k; k >>= 1)
						{
							if(val & k)
								*ptr32++ = color2;
							else
								*ptr32++ = 0xFFFFFF;
						}					
						break;
			  }
			}
			base_addr += incr;
		}
#ifndef TEST_NOPCI
		if(buf_tex != NULL)
		{
			if(cnt)
				display_composite_texture(3, buf_tex, 0, 0, WIDTH_LOGO, HEIGHT_LOGO, 0, 0, info->var.xres_virtual, info->var.yres_virtual);
			else
				display_composite_texture(1, buf_tex, 0, 0, WIDTH_LOGO, HEIGHT_LOGO, 0, 0, WIDTH_LOGO, HEIGHT_LOGO);
		}
#endif
	}
#ifndef TEST_NOPCI
	if(buf_tex != NULL)
		Mfree(buf_tex);
#endif
}

void display_ati_logo(void)
{
#ifdef ATI_LOGO
#define WIDTH_ATI_LOGO 96
#define HEIGHT_ATI_LOGO 62
	static unsigned short logo[] =
	{
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF, 
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0x8000,0x0000,0x007F,
		0x01FF,0xFFFF,0xFFFE,0x0000,0x0000,0x003F,
		0x01FF,0xFFFF,0xFFFC,0x0000,0x0000,0x1F1F,
		0x01FF,0xFFFF,0xFFF0,0x0000,0x0000,0x3F8F,
		0x01FF,0xFFFF,0xFFF0,0x0000,0x0000,0x7FC7,
		0x01FF,0xFFFF,0xFFC0,0x0000,0x0000,0x7FE7,
		0x01FF,0xFFFF,0xFF80,0x0000,0x0000,0xFFE7,
		0x01FF,0xFFFF,0xFF00,0x0000,0x0000,0xFFE7,
		0x01FF,0xFFFF,0xFE00,0x0000,0x0000,0xFFE7,
		0x01FF,0xFFFF,0xFC00,0x0000,0x0000,0x7FC7,
		0x01FF,0xFFFF,0xF800,0x0000,0x0000,0x7FC7,
		0x01FF,0xFFFF,0xF000,0x0000,0x0000,0x3F8F,
		0x01FF,0xFFFF,0xE000,0x0000,0x0000,0x0E1F,
		0x01FF,0xFFFF,0xC000,0x0000,0x0000,0x003F,
		0x01FF,0xFFFF,0x8000,0x0000,0x0000,0x00FF,
		0x01FF,0xFFFF,0x0000,0x0700,0x00FF,0xFFFF,
		0x01FF,0xFFFE,0x0000,0x0F00,0x01FF,0xFFFF,
		0x01FF,0xFFFC,0x0000,0x1F00,0x01FF,0xC07F,
		0x01FF,0xFFF8,0x0000,0x3F80,0x01FF,0x003F,
		0x01FF,0xFFF0,0x0000,0x7F80,0x01FF,0x001F,
		0x01FF,0xFFE0,0x0000,0xFF80,0x01FE,0x000F,
		0x01FF,0xFFC0,0x0001,0xFF80,0x01FE,0x000F,
		0x01FF,0xFF80,0x0003,0xFF80,0x01FC,0x000F,
		0x01FF,0xFF00,0x0007,0xFF80,0x01FC,0x000F,
		0x01FF,0xFE00,0x000F,0xFF80,0x01FC,0x000F,
		0x01FF,0xFC00,0x001C,0x3F80,0x01FC,0x000F,
		0x01FF,0xF800,0x0030,0x0F80,0x01FC,0x000F,
		0x01FF,0xF000,0x0070,0x0780,0x01FC,0x000F,
		0x01FF,0xE000,0x00E0,0x0380,0x01FC,0x000F,
		0x01FF,0xC000,0x01E0,0x0380,0x01FC,0x000F,
		0x01FF,0x8000,0x03E0,0x0380,0x01FC,0x000F,
		0x01FF,0x0000,0x07E0,0x0380,0x01FC,0x000F,
		0x01FE,0x0000,0x0FE0,0x0380,0x01FC,0x000F,
		0x01FC,0x0000,0x1FE0,0x0380,0x01FC,0x000F,
		0x01F8,0x0000,0x3FE0,0x0780,0x01FC,0x000F,
		0x01F8,0x0000,0x7FF0,0x0780,0x01FC,0x000F,
		0x01F0,0x0000,0xFFFC,0x1F80,0x01FC,0x000F,
		0x01F0,0x0001,0xFFFF,0xFF80,0x01FC,0x000F,
		0x01F0,0x0003,0xFFFF,0xFF80,0x01FC,0x000F,
		0x01E0,0x0007,0xFFFF,0xFF80,0x01FC,0x000F,
		0x01E0,0x000F,0xFFFF,0xFF80,0x01FC,0x000F,
		0x01F0,0x001F,0xFFFF,0xFF80,0x01FE,0x000F,
		0x01F0,0x003F,0xFFFF,0xFF80,0x03FE,0x000F,
		0x01F8,0x007F,0xFFFF,0xFFC0,0x03FE,0x000F,
		0x01F8,0x00FF,0xFFFF,0xFFC0,0x07FF,0x001F, 
		0x01FC,0x01FF,0xFFFF,0xFFE0,0x0FFF,0x803F,
		0x01FF,0x03FF,0xFFFF,0xFFF8,0x3FFF,0xE0FF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF, 
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
		0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF };
	long dst_y = 0, w = WIDTH_ATI_LOGO - 8, h = HEIGHT_ATI_LOGO, src_wrap = WIDTH_ATI_LOGO / 8;
	struct fb_info *info = rinfo_fvdi->info;
	long foreground, background;
	long dst_x = (long)info->var.xres - w;
	switch(info->var.bits_per_pixel)
	{
		case 8: foreground = 1; background = 7; break; /* red & grey */
		case 16: foreground = 0xF800; background = 0xB596; break;
		default: foreground = 0xFF0000; background = 0xB0B0B0; break;
	}
	display_mono_block(((char *)logo)+1, dst_x, dst_y, w, h, foreground, background, src_wrap);
#endif
}

void init_screen_info(SCREENINFO *si, long modecode)
{
	char buf[16];
	long flags = 0;
	struct fb_info *info;
	info = rinfo_fvdi->info;
	switch(modecode & NUMCOLS)
	{
		case BPS32:
			si->scrPlanes = 32;
			si->scrColors = 16777216;
			si->redBits = 0xFF0000;                 /* mask of red bits */
			si->greenBits = 0xFF00;                 /* mask of green bits */
			si->blueBits = 0xFF;                    /* mask of blue bits */
			si->unusedBits = 0xFF000000;            /* mask of unused bits */
			break;
		case BPS16:
			si->scrPlanes = 16;
			si->scrColors = 65536;
			si->redBits = 0xF800;                    /* mask of red bits */
			si->greenBits = 0x3E0;                   /* mask of green bits */
			si->blueBits = 0x1F;                     /* mask of blue bits */
			si->unusedBits = 0;                      /* mask of unused bits */
			break;
		case BPS8:
			si->scrPlanes = 8;
			si->scrColors = 256;
			si->redBits = si->greenBits = si->blueBits = 255;
			si->unusedBits = 0;
			break;
		default:
			si->scrFlags = 0;
			return;
	}
	si->alphaBits = si->genlockBits = 0;
	if(!(modecode & DEVID)) /* modecode normal */
	{
		switch(modecode & (VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|STMODES|VGA|COL80))
		{
			case (VERTFLAG+VGA):                      /* 320 * 240 */
			case 0:
				si->scrWidth = 320;
				si->scrHeight = 240;
				break;
			case (VGA+COL80):                         /* 640 * 480 */
			case (VERTFLAG+COL80):
				si->scrWidth = 640;
				si->scrHeight = 480;
				break;
			case (VESA_600+HORFLAG2+VGA+COL80):       /* 800 * 600 */
				si->scrWidth = 800;
				si->scrHeight = 600;
				break;
			case (VESA_768+HORFLAG2+VGA+COL80):       /* 1024 * 768 */
				si->scrWidth = 1024;
				si->scrHeight = 768;
				break;
			case (VERTFLAG2+HORFLAG+VGA+COL80):       /* 1280 * 960 */
				si->scrWidth = 1280;
				si->scrHeight = 960;
				break;
			case (VERTFLAG2+VESA_600+HORFLAG2+HORFLAG+VGA+COL80): /* 1600 * 1200 */
				si->scrWidth = 1600;
				si->scrHeight = 1200;
				break;
			default:
				si->scrFlags = 0;
				return;
		}
		if(modecode & OVERSCAN)
		{
			if(modecode & PAL)
				si->refresh=85;
			else
				si->refresh=70;
		}
		else
		{
			if(modecode & PAL)
				si->refresh = 60;
			else
				si->refresh = 56;
		}
		si->pixclock = 0;
	}
	else /* bits 11-3 used for devID */
	{
		const struct fb_videomode *db;
		long devID = GET_DEVID(modecode);
		if(devID < 34)
			db = &vesa_modes[devID];		
		else
		{
			devID -= 34;
			if(devID < total_modedb)
				db = &modedb[devID];
			else
			{
      	devID -= total_modedb;
      	if(devID < rinfo_fvdi->mon1_dbsize)
					db = &rinfo_fvdi->mon1_modedb[devID];
      	else
				{
					si->scrFlags=0;
					return;
				}
			}
		}
		si->scrWidth = (long)db->xres;
		si->scrHeight = (long)db->yres;
    si->refresh = (long)db->refresh;
		si->pixclock = (long)db->pixclock;
		flags = (long)db->flag;
	}
	if(modecode & VIRTUAL_SCREEN)
	{
		si->virtWidth = si->scrWidth*2;
		if(si->virtWidth > 2048)
			si->virtWidth = 2048;
		si->virtHeight = si->scrHeight*2;
		if(si->virtHeight > 2048)
			si->virtHeight = 2048;
	}
	else
	{
		si->virtWidth = si->scrWidth;
		si->virtHeight = si->scrHeight;
	}
	ltoa(buf, si->scrWidth, 10); 
	strcpy(si->name, buf);
	strcat(si->name, "x");
	ltoa(buf, si->scrHeight, 10); 
	strcat(si->name, buf);
	strcat(si->name, "-");
	ltoa(buf, si->scrPlanes, 10); 
	strcat(si->name, buf);
	strcat(si->name, "@");
	ltoa(buf, si->refresh, 10); 
	strcat(si->name, buf);
	strcat(si->name, "Hz");
	if(modecode & VIRTUAL_SCREEN)
		strcat(si->name, " x4");
	else
		strcat(si->name, "   ");
	buf[0] = ' ';
	buf[1] = buf[2] ='\0';
	if(flags & FB_MODE_IS_VESA)
		buf[1] = 'V';
	if(flags & FB_MODE_IS_CALCULATED)
		buf[1] = 'C';
	if(flags & FB_MODE_IS_STANDARD)
		buf[1] = 'S';
	if(flags & FB_MODE_IS_DETAILED)
		buf[1] = 'D';
	if(flags & FB_MODE_IS_FIRST)
		buf[1] = '*';
	if(buf[1])
		strcat(si->name, buf);
	si->frameadr = (long)physbase();
	si->lineWrap = si->virtWidth * (si->scrPlanes / 8);
	si->planeWarp = 0;
	si->scrFormat = PACKEDPIX_PLANES;
	if(si->scrPlanes <= 8)
		si->scrClut = HARD_CLUT;
	else
		si->scrClut = SOFT_CLUT;
	si->bitFlags = STANDARD_BITS;					
	si->max_x = si->max_y = 8192; /* max. possible heigth/width ??? */
	si->maxmem = si->max_x * si->max_y * (si->scrPlanes / 8);
	si->pagemem = vgetsize(modecode);
	if(!si->devID)
	{
		si->refresh = info->var.refresh;
		si->pixclock = info->var.pixclock;
		si->devID = modecode;
	}
	si->scrFlags = SCRINFO_OK;
}

#else /* TEST_NOPCI */

long clear_screen(long bg_color, long x, long y, long w, long h)
{
	if(bg_color);
  if(x);
  if(y);
  if(w);
  if(h);
  return(0);
}

long move_screen(long src_x, long src_y, long dst_x, long dst_y, long w, long h)
{
	if(src_x);
	if(src_y);
	if(dst_x);
	if(dst_y);
	if(w);
	if(h);
	return(0);
}

long print_screen(char *car, long x, long y, long w, long h, long fg_color, long bg_color)
{
	if(car);
	if(x);
	if(y);
	if(h);
	if(fg_color);
	if(bg_color);
	return(0);
}

#endif /* TEST_NOPCI */

unsigned long physbase(void)
{
	struct fb_info *info;
	info=rinfo_fvdi->info;
	return((unsigned long)info->screen_base + rinfo_fvdi->fb_offset);
}

void init_screen(void)
{
	Bconout(2,27);
	Bconout(2,'b');
	Bconout(2,0x3F); /* black characters */
	Bconout(2,27);
	Bconout(2,'c');
	Bconout(2,0x30); /* white background */
	Bconout(2,27);
	Bconout(2,'E');  /* clear screen */
	Bconout(2,27);
	Bconout(2,'f');  /* no cursor */
}

void init_resolution(long modecode)
{
	switch(modecode & NUMCOLS)
	{
		case BPS32: resolution.bpp = 32; break;
		case BPS16: resolution.bpp = 16; break;
		default: resolution.bpp = 8; break;
	}
#ifndef TEST_NOPCI
	if(!(modecode & DEVID)) /* modecode normal */
#endif
	{
		if(modecode & OVERSCAN)
		{
			if(modecode & PAL)
				resolution.freq = 85;
			else
				resolution.freq = 70;
		}
		else
		{
			if(modecode & PAL)
				resolution.freq = 60;
			else
				resolution.freq = 56;
		}
		resolution.vesa = 0;
		switch(modecode & (VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|STMODES|VGA|COL80))
		{
			case (VERTFLAG+VGA):                      /* 320 * 240 */
			case 0:
				resolution.width = 320;
				resolution.height = 240;
				break;
			case (VGA+COL80):                         /* 640 * 480 */
			case (VERTFLAG+COL80):
				resolution.width = 640;
				resolution.height = 480;
				break;
#ifndef TEST_NOPCI
			case (VESA_600+HORFLAG2+VGA+COL80):       /* 800 * 600 */
				resolution.width = 800;
				resolution.height = 600;
				break;
			case (VESA_768+HORFLAG2+VGA+COL80):       /* 1024 * 768 */
				resolution.width = 1024;
				resolution.height = 768;
				break;
			case (VERTFLAG2+HORFLAG+VGA+COL80):       /* 1280 * 960 */
				resolution.width = 1280;
				resolution.height = 960;
				resolution.vesa = 1;
				break;
			case (VERTFLAG2+VESA_600+HORFLAG2+HORFLAG+VGA+COL80): /* 1600 * 1200 */
				resolution.width = 1600;
				resolution.height = 1200;
				break;
#endif
			default: 
				init_resolution((long)((unsigned long)Modecode));
			 	break;
		}
	}
#ifndef TEST_NOPCI
	else /* bits 11-3 used for devID */
	{
		const struct fb_videomode *db;
		long devID = GET_DEVID(modecode);
		if(devID < 34)
		{
			db = &vesa_modes[devID];
			resolution.vesa = 1;
		}
		else
		{
			devID -= 34;
			resolution.vesa = 0;
			if(devID < total_modedb)
				db = &modedb[devID];
			else
			{
      	devID -= total_modedb;
      	if(devID < rinfo_fvdi->mon1_dbsize)
					db = &rinfo_fvdi->mon1_modedb[devID];
      	else
				{
					init_resolution((long)((unsigned long)Modecode));
					return;
				}
			}
		}
		resolution.width = (short)db->xres;
		resolution.height = (short)db->yres;
		resolution.freq = (short)db->refresh;
	}
#endif /* TEST_NOPCI */
}

short vsetscreen(long logaddr, long physaddr, long rez, long modecode, long init_vdi)
{
#ifndef TEST_NOPCI
	static unsigned short tab_16_col_ntc[16] = {
		0xFFDF,0xF800,0x07C0,0xFFC0,0x001F,0xF81F,0x07DF,0xB596,
		0x8410,0xA000,0x0500,0xA500,0x0014,0xA014,0x0514,0x0000 };
	static unsigned long tab_16_col_tc[16] = {
		0xFFFFFF,0xFF0000,0x00FF00,0xFFFF00,0x0000FF,0xFF00FF,0x00FFFF,0xB0B0B0,
		0x808080,0x8F0000,0x008F00,0x8F8F00,0x00008F,0x8F008F,0x008F8F,0x000000 };
	long y, color = 0, test = 0;
#endif /* TEST_NOPCI */
	struct fb_info *info;
	struct radeonfb_info *rinfo;
	struct fb_var_screeninfo var;
	info = rinfo_fvdi->info;
	rinfo = rinfo_fvdi;
	switch((short)rez)
	{
#ifndef TEST_NOPCI
		case 0x564E: /* 'VN' (Vsetscreen New) */
			switch((short)modecode)
			{
				case CMD_GETMODE:
					*((long *)physaddr) = (long)((unsigned long)Modecode);
					return(0);
				case CMD_SETMODE:
					modecode = physaddr;
					rez = 3;
					logaddr = physaddr = 0;
					if(((modecode & NUMCOLS) != BPS8)
					 && ((modecode & NUMCOLS) != BPS16)
					 && ((modecode & NUMCOLS) != BPS32))
						return(0);
					init_resolution(modecode);
					Modecode = (short)modecode;
					break;
				case CMD_GETINFO:
					{
						SCREENINFO *si = (SCREENINFO *)physaddr;
						if(si->devID)
							modecode = si->devID;
						else
							modecode = (long)((unsigned long)Modecode);
						init_screen_info(si, modecode);
					}
          return(0);
				case CMD_ALLOCPAGE:
					{
						long addr, addr_aligned;
						long wrap = info->var.xres_virtual * (info->var.bits_per_pixel >> 3);
						modecode = physaddr;
						if(second_screen)
						{
							if(logaddr != -1)
								*((long *)logaddr) = second_screen_aligned;
							return(0);
						}
						addr_aligned = addr = radeon_offscreen_alloc(rinfo_fvdi,vgetsize(modecode)+wrap);
						if(addr)
						{
							addr_aligned = addr - (long)info->screen_base;
							addr_aligned += (wrap-1);
							addr_aligned /= wrap;
							addr_aligned *= wrap;
							addr_aligned += (long)info->screen_base;
							if(logaddr != -1)
								*((long *)logaddr) = addr_aligned;
							if(!second_screen)
							{
								second_screen = addr;
								second_screen_aligned = addr_aligned;
							}
						}
						else
						{
							if(logaddr != -1)
								*((long *)logaddr) = 0;
						}
					}
					return(0);
				case CMD_FREEPAGE:
					if((logaddr == -1) || (logaddr == second_screen_aligned))
						logaddr = second_screen;
					else
						logaddr = 0;
					if(logaddr)
					{
						radeon_offscreen_free(rinfo_fvdi, logaddr);
						if(logaddr == second_screen_aligned)
						{
							if(second_screen_aligned == (long)physbase())
							{
								logaddr = physaddr = (long)info->screen_base;
								rez = -1; /* switch back to the first if second page active */
								init_vdi = 0;
								second_screen = second_screen_aligned = 0;
								break;
							}								
							else				
								second_screen = second_screen_aligned = 0;							
						}
					}
					return(0);
				case CMD_FLIPPAGE:
					if(!second_screen)
						return(0);
					if(second_screen_aligned == (long)physbase())
						logaddr = physaddr = (long)info->screen_base;
					else
						logaddr = physaddr = second_screen_aligned;
					rez = -1;
					init_vdi = 0;
					break;
				case CMD_ALLOCMEM:
					{
						SCRMEMBLK *blk = (SCRMEMBLK *)physaddr;
						if(blk->blk_y)
							blk->blk_h=blk->blk_y;
						if(blk->blk_h)
						{	
							int bpp = info->var.bits_per_pixel >> 3;
							blk->blk_len = (long)(info->var.xres_virtual * bpp) * blk->blk_h;
							blk->blk_start = radeon_offscreen_alloc(rinfo_fvdi, blk->blk_len);
							if(blk->blk_start)
								blk->blk_status = BLK_OK;
							else
								blk->blk_status = BLK_ERR;
							blk->blk_w = (long)info->var.xres_virtual;
							blk->blk_wrap = blk->blk_w * (long)bpp;
							blk->blk_x = (blk->blk_start % (info->var.xres_virtual * bpp)) / bpp;
							blk->blk_y = blk->blk_start / (info->var.xres_virtual * bpp);
						}
					}
					return(0);
				case CMD_FREEMEM:
					{
						SCRMEMBLK *blk	= (SCRMEMBLK *)physaddr;
						radeon_offscreen_free(rinfo_fvdi,blk->blk_start);
						blk->blk_status = BLK_CLEARED;
					}
					return(0);
				case CMD_SETADR:
					rez = -1;
					break;
				case CMD_ENUMMODES:
					{
						long (*enumfunc)(SCREENINFO *inf, long flag) = (void *)physaddr;
						SCREENINFO si;
						long mode;
						si.size = sizeof(SCREENINFO);
						for(mode = 0; mode < 65536; mode++)
						{
							if(!(mode & DEVID)) /* modecode normal */
							{
								if(mode & STMODES)
									continue;
								mode |= VGA;
								mode &= (VIRTUAL_SCREEN|VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|OVERSCAN|PAL|VGA|COL80|NUMCOLS);
								if(mode == (long)(Modecode & (VIRTUAL_SCREEN|VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|OVERSCAN|PAL|VGA|COL80|NUMCOLS)))
									si.devID = 0;
								else
									si.devID = mode;
							}
							else /* bits 11-3 used for devID */
							{
								if(mode == ((long)Modecode & 0xFFFF))
									si.devID = 0;
								else
									si.devID = mode;
							}							
						  init_screen_info(&si, mode);
						  si.devID = mode;
						  if(si.scrFlags == SCRINFO_OK)
						  {
								if(!(*enumfunc)(&si, 1 /* ??? */))
									break;
							}
						}
					}
					return(0);
				case CMD_TESTMODE:
					debug = 0;
					modecode = physaddr;
					logaddr = physaddr = 0;
					rez = 3;
					init_vdi = 0;
					test = 1;
					if(((modecode & NUMCOLS) != BPS8)
					 && ((modecode & NUMCOLS) != BPS16)
					 && ((modecode & NUMCOLS) != BPS32))
						return(0);
					init_resolution(modecode);
					Modecode = (short)modecode;			
					break;
				case CMD_COPYPAGE:
					if(second_screen)
					{
						long src_x, src_y, dst_x, dst_y;
						int bpp = info->var.bits_per_pixel >> 3;
						long offset = (long)second_screen_aligned - (long)info->screen_base;
						if(physaddr & 1)
						{
					    src_x = (offset % (info->var.xres_virtual * bpp)) / bpp;
							src_y = offset / (info->var.xres_virtual * bpp);
							dst_x = dst_y = 0;
						}
						else
						{
							src_x = src_y = 0;
					    dst_x = (offset % (info->var.xres_virtual * bpp)) / bpp;
							dst_y = offset / (info->var.xres_virtual * bpp);
						}
						move_screen(src_x, src_y, dst_x, dst_y, info->var.xres_virtual, info->var.yres_virtual);
					}
					return(0);
				case -1:
				default: return(0);
			}
			break;
#endif /* TEST_NOPCI */
/*
		case 0:	
			resolution.width = 320;
			resolution.height = 200;
			resolution.bpp = 8;
			resolution.freq = 70;
			if(Modecode & VGA)
				modecode = VERTFLAG|STMODES|VGA|BPS4;
			else
				modecode = STMODES|BPS4;
			break;
*/
		case 3:
			if(((modecode & NUMCOLS) != BPS8)
			 && ((modecode & NUMCOLS) != BPS16)
			 && ((modecode & NUMCOLS) != BPS32))
				return(Modecode);
			init_resolution(modecode);
			Modecode = (short)modecode;
			break;
		default:
			return(Modecode);
	}
	if(modecode & VIRTUAL_SCREEN)
		virtual=1;
	else
		virtual=0;
	if(!logaddr && !physaddr && (rez >= 0))
	{
#ifdef TEST_NOPCI
		if(&var);
		if(Modecode & COL80)
		{
			*((char **)_v_bas_ad) = info->screen_base = (char *)Screalloc(640*480*2);
			init_videl_640_480_65K((unsigned short *)info->screen_base);
		}
		else
		{
			*((char **)_v_bas_ad) = info->screen_base = (char *)Screalloc(320*240*2);
			init_videl_320_240_65K((unsigned short *)info->screen_base);		
		}
		info->var.xres = info->var.xres_virtual = resolution.width;
		info->var.yres = info->var.yres_virtual = resolution.height;
		rinfo_fvdi->bpp = info->var.bits_per_pixel = resolution.bpp;
		if(init_vdi)
		{
			init_var_linea();
			init_screen();
		}
#else /* !TEST_NOPCI */
		resolution.used = 1;
		if(init_vdi)
		{
			DPRINTVALHEX("Setscreen mode ", (long)Modecode & 0xFFFF);
			DPRINTVAL(" ", resolution.width);
			DPRINTVAL("x", resolution.height);
			DPRINTVAL("-", resolution.bpp);
			DPRINTVAL("@", resolution.freq);
			DPRINT("\r\n");
		}
		radeon_check_modes(rinfo_fvdi, &resolution);
		memcpy(&var, &info->var, sizeof(struct fb_var_screeninfo));
		if(virtual)
		{
			var.xres_virtual = var.xres * 2;
			var.yres_virtual = var.yres * 2;
			if(var.xres_virtual > 2048)
				var.xres_virtual = 2048;
			if(var.yres_virtual > 2048)
				var.yres_virtual = 2048;
		}
		var.activate = (FB_ACTIVATE_FORCE|FB_ACTIVATE_NOW);
		rinfo_fvdi->asleep = 0;
		if(!fb_set_var(info, &var))
		{
			int i, red = 0, green = 0, blue = 0;
			*((char **)_v_bas_ad) = info->screen_base;
			switch(rinfo_fvdi->bpp)
			{
				case 16:
					for(i = 0; i < 64; i++)
					{
						if(red > 65535)
							red = 65535;
						if(green > 65535)
							green = 65535;
						if(blue > 65535)
							blue = 65535;
						radeonfb_setcolreg((unsigned)i,red,green,blue,0,info);
						green += 1024;   /* 6 bits */
						red += 2048;     /* 5 bits */
						blue += 2048;    /* 5 bits */
					}
					break;
				case 32:
					for(i = 0; i < 256; i++)
					{
						if(red > 65535)
							red = 65535;
						if(green > 65535)
							green = 65535;
						if(blue > 65535)
							blue = 65535;
						radeonfb_setcolreg((unsigned)i,red,green,blue,0,info);
						green += 256;   /* 8 bits */
						red += 256;     /* 8 bits */
						blue += 256;    /* 8 bits */
					}
					break;
				default:
					vsetrgb(0,256,(long *)0xE1106A); /* default TOS 4.04 palette */
					break;
			}
			if(init_vdi)
			{
				radeon_offscreen_init(rinfo_fvdi);
				init_var_linea();
				init_screen();
			}
			else if(test)
			{
				for(y = 0; y < info->var.yres_virtual; y += 16)
				{
					switch(rinfo_fvdi->bpp)
					{
						case 16: color = (unsigned long)tab_16_col_ntc[(y >> 4) & 15]; break;
						case 32: color = tab_16_col_tc[(y >> 4) & 15]; break;
						default: color = (unsigned long)((y >> 4) & 15); break;
					}
					clear_screen(color, 0, y, info->var.xres_virtual, info->var.yres_virtual-y >= 16 ? 16 : info->var.yres_virtual - y);
				}				
			}
			Modecode = (short)modecode;
		}
#endif /* TEST_NOPCI */
	}
	else
	{
		if(logaddr && (logaddr != -1))
			*((char **)_v_bas_ad) = (char *)logaddr;
		if(physaddr && (physaddr != -1))
		{
#ifndef TEST_NOPCI
			int bpp = info->var.bits_per_pixel >> 3;
			physaddr -= (long)info->screen_base;
			if(physaddr < 0
			 || (physaddr >= (info->var.xres_virtual * 8192 * bpp)))
				return(Modecode);
			memcpy(&var, &info->var, sizeof(struct fb_var_screeninfo));			
			var.xoffset = (physaddr % (info->var.xres_virtual * bpp)) / bpp;
			var.yoffset = physaddr / (info->var.xres_virtual * bpp);
			if(var.yoffset < 8192)
			{
#ifdef SEMAPHORE
				xSemaphoreTakeRADEON();
#endif
				fb_pan_display(info, &var);
#ifdef SEMAPHORE
				xSemaphoreGiveRADEON();
#endif
			}
#endif /* TEST_NOPCI */
		}
	}
	return(Modecode);
}

short vsetmode(long modecode)
{
	if(modecode == -1)
		return(Modecode);
	vsetscreen(0, 0 , 3, modecode & 0xFFFF, 0);
	return(Modecode);
}

short montype(void)
{
	switch(rinfo_fvdi->mon1_type)
	{
		case MT_STV: return(1); /* S-Video out */
		case MT_CRT: return(2); /* VGA */
		case MT_CTV: return(3); /* TV / composite */
		case MT_LCD: return(4);	/* LCD */
		case MT_DFP: return(5); /* DVI */
		default: return(2);     /* VGA */
	}
}

long vgetsize(long modecode)
{
	long size = 0;
	struct fb_info *info;
	info = rinfo_fvdi->info;
	if((short)modecode == Modecode)
		return(info->var.xres_virtual * info->var.yres_virtual * (info->var.bits_per_pixel >> 3));
#ifndef TEST_NOPCI
	if(!(modecode & DEVID)) /* modecode normal */
#endif
	{
		if(modecode & STMODES)
		{
			switch(modecode & NUMCOLS)
			{
				case BPS4: return(320 * 200);
				default: return(640 * 400);
			}
		}	
		switch(modecode & (VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|OVERSCAN|VGA|COL80))
		{
			case (VERTFLAG+VGA):                      /* 320 * 240 */
			case 0:
				size = 320 * 240;
				break;
			case (VGA+COL80):                         /* 640 * 480 */
			case (VERTFLAG+COL80):
				size = 640 * 480;
				break;
#ifndef TEST_NOPCI
			case (VESA_600+HORFLAG2+VGA+COL80):       /* 800 * 600 */
				size = 800 * 600;
				break;
			case (VESA_768+HORFLAG2+VGA+COL80):       /* 1024 * 768 */
				size=1024 * 768;
				break;
			case (VERTFLAG2+HORFLAG+VGA+COL80):       /* 1280 x 960 */
				size = 1280 * 960;
				break;
			case (VERTFLAG2+VESA_600+HORFLAG2+HORFLAG+VGA+COL80): /* 1600 * 1200 */
			default:
				size = 1600 * 1200;
				break;
#else
			default:
				size = 640 * 480;
				break;
#endif
		}
	}
#ifndef TEST_NOPCI
	else /* bits 11-3 used for devID */
	{
		const struct fb_videomode *db;
		long devID = GET_DEVID(modecode);
		if(devID < 34)
			db = &vesa_modes[devID];		
		else
		{
			devID -= 34;
			if(devID < total_modedb)
				db = &modedb[devID];
			else
			{
      	devID -= total_modedb;
      	if(devID < rinfo_fvdi->mon1_dbsize)
					db = &rinfo_fvdi->mon1_modedb[devID];
      	else
					return(0);
			}
		}
		size = db->xres * db->yres;
	}
#endif /* TEST_NOPCI */
	switch(modecode & NUMCOLS)
	{
		case BPS32: size <<= 2; break;
		case BPS16: size <<= 1; break;
		default: break;
	}
	if(modecode & VIRTUAL_SCREEN)
		size <<= 2;
	return(size);
}

short validmode(long modecode)
{
#ifndef TEST_NOPCI
	if((unsigned short)modecode != 0xFFFF)
	{
		if(((modecode & NUMCOLS) < BPS8) || ((modecode & NUMCOLS) > BPS32))
		{
			modecode &= ~NUMCOLS;
			modecode |= BPS16;
		}
		if(!(modecode & DEVID)) /* modecode normal */
		{
			modecode |= VGA;
			if(modecode & STMODES)
			{
				modecode &= (VERTFLAG|VGA|COL80);
				modecode |= BPS16;
			}
			else if(fix_modecode < 0)
			{
				modecode &= (VERTFLAG|VGA|COL80|NUMCOLS);
				modecode |= ((long)Modecode & (VIRTUAL_SCREEN|VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG));
			}
		}
		else /* bits 11-3 used for devID */
		{
			if(fix_modecode < 0)
			{
			 	modecode &= NUMCOLS;
			 	modecode |= ((long)Modecode & ~NUMCOLS);
			}
			if(GET_DEVID(modecode) >= (34 + total_modedb + rinfo_fvdi->mon1_dbsize))
			{
				modecode &= NUMCOLS;
				modecode |= (VGA|COL80);
			}
		}
	}
	if(fix_modecode != 1)
		fix_modecode = -1;
#endif /* TEST_NOPCI */
	return((short)modecode);
}

long vmalloc(long mode, long value)
{
#ifndef TEST_NOPCI
	switch(mode)
	{
		case 0:
			if(value)
				return(radeon_offscreen_alloc(rinfo_fvdi,value));
			break;
		case 1:
			return(radeon_offscreen_free(rinfo_fvdi,value));
		case 2:
			if(value > 0)
				rinfo_fvdi = (struct radeonfb_info *)value; 
			radeon_offscreen_init(rinfo_fvdi);
			return(0);
			break;
	}
#endif
	return(-1);
}

long InitVideo(void)
{
#if 0 // #ifndef TEST_NOPCI
	RADEONInitVideo(rinfo_fvdi);
	Cconin();	
	RADEONPutVideo(rinfo_fvdi, 0, 0, 720, 576, 0, 0, 640, 512);
	Cconin();
	RADEONStopVideo(rinfo_fvdi, 1);	
	Cconin();
	RADEONShutdownVideo(rinfo_fvdi);
	Cconin();	
#endif
	return(0);
}

#ifdef NETWORK
#ifdef COLDFIRE
#ifndef MCF5445X

#ifdef SOUND_AC97

#define DEBUG

#ifdef MCF547X
#define AC97_DEVICE 2 /* COLDARI */
#else /* MCF548X */
#define AC97_DEVICE 3 /* M5484LITE */
#endif /* MCF547X */
#define SETSMPFREQ 7
#define SETFMT8BITS 8
#define SETFMT16BITS 9
#define SETFMT24BITS 10
#define SETFMT32BITS 11
#define LTGAINMASTER 12
#define RTGAINMASTER 13
#define LTGAINMIC 14
#define RTGAINMIC 15
#define LTGAINFM 16
#define RTGAINFM 17
#define LTGAINLINE 18
#define RTGAINLINE 19
#define LTGAINCD 20
#define RTGAINCD 21
#define LTGAINVIDEO 22
#define RTGAINVIDEO 23
#define LTGAINAUX 24
#define RTGAINAUX 25

#define SI_CALLBACK 2

struct McSnCookie
{
	short vers; // version in BCD
	short size; // size the structure
	short play;
	short record;
	short dsp;  // Is the DSP there?
	short pint; // Playing: Interrupt possible with frame-end?
 	short rint; // Recording: Interrupt possible with frame-end?
	long res1;
	long res2;
	long res3;
	long res4;
};

long flag_snd_init, count_timer_a, preload_timer_a, timer_a_enabled, io7_enabled; 
static long flag_snd_lock, status_dma, mode_res;
static long volume_play, volume_record, volume_master, volume_mic, volume_fm, volume_line, volume_cd, volume_video, volume_aux;
static long adder_inputs, record_source;
static long nb_tracks_play, nb_tracks_record, mon_track;
static long flag_clock_44_48, prescale_ste, frequency, cause_inter;
static long play_addr, record_addr, end_play_addr, end_record_addr;
static void (*callback_play)(), (*callback_record)();
extern void display_string(char *string);
extern void ltoa(char *buf, long n, unsigned long base);

static unsigned short tab_freq_falcon[] = {
	// internal
	49170,33800,24585,20770,16940,16940,12292,12292,9834,9834,8195, // 25.175 MHz
	// external
	44100,29400,22050,17640,14700,14700,11025,11025,8820,8820,7350, // 22.5792 MHz
	48000,32000,24000,19200,16000,16000,12000,12000,9600,9600,8000 }; // 24.576 MHz
static unsigned short tab_freq_ste[] = { 6250,12500,25000,50000 };
struct McSnCookie cookie_mac_sound = { 0x0100, 30, 2, 2, 0, 1, 1, 0, 0, 0, 0 }; 

void call_timer_a(void)
{
	void *vect_timer_a = *(void **)0x134;
	if((vect_timer_a == NULL) || (!timer_a_enabled))
		return;
	count_timer_a--;
	if(count_timer_a > 0)
		return;
	count_timer_a = preload_timer_a;
	asm(" clr.w -(SP)");         // 68K format
	asm("	pea.l .next_timer_a(PC)"); // return address
	asm(" clr.w -(SP)");				 // space for SR
	asm(" move.l D0,-(SP)");
	asm(" move.w SR,D0");
	asm(" move.w D0,4(SP)");
	asm(" move.l (SP)+,D0");
	asm(" move.l 0x134,-(SP)");  // timer A vector
	asm("	rts");
	asm(".next_timer_a:");
}

void call_io7_mfp(void)
{
	void *vect_io7 = *(void **)0x13C;
	if((vect_io7 == NULL) || (!io7_enabled))
		return;
	asm(" clr.w -(SP)");         // 68K format
	asm("	pea.l .next_io7(PC)"); // return address
	asm(" clr.w -(SP)");				 // space for SR
	asm(" move.l D0,-(SP)");
	asm(" move.w SR,D0");
	asm(" move.w D0,4(SP)");
	asm(" move.l (SP)+,D0");
	asm(" move.l 0x13C,-(SP)");
	asm("	rts");
	asm(".next_io7:");           // IO7 MFP vector
}

void stop_dma_play(void)
{
	if(status_dma & SI_PLAY)
	{
		mcf548x_ac97_playback_trigger(AC97_DEVICE, 0);
		mcf548x_ac97_playback_close(AC97_DEVICE);
		status_dma &= ~SI_PLAY;
	}
}

void stop_dma_record(void)
{
	if(status_dma & SI_RECORD)
	{
		mcf548x_ac97_capture_trigger(AC97_DEVICE, 0);
		mcf548x_ac97_capture_close(AC97_DEVICE);
		status_dma &= ~SI_RECORD;
	}
}

long locksnd(void)
{
#ifdef DEBUG
	display_string("locksnd\r\n");
#endif
	if(flag_snd_lock)
		return(-128);
	flag_snd_lock = 1;
#ifdef DEBUG
	display_string("locksnd ok\r\n");
#endif
	return(1);
}

long unlocksnd(void)
{
#ifdef DEBUG
	display_string("unlocksnd\r\n");
#endif
	if(!flag_snd_lock)
		return(-127);
	flag_snd_lock = 0;
#ifdef DEBUG
	display_string("unlocksnd ok\r\n");
#endif
	return(0);
}

long soundcmd(long mode, unsigned long data)
{
	int val1, val2, val3;
#ifdef DEBUG
	{
		char buf[10];
		display_string("soundcmd, mode: ");
		ltoa(buf, mode, 10);
		display_string(buf);
		display_string(", data: ");
		ltoa(buf, data, 10);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	switch(mode)
	{
		case LTATTEN:
			if(data >= 0x8000)
				return(255 - (volume_play & 0xff));
			volume_play &= 0xff00;
			volume_play |= ((255 - data) & 0xff);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_PCM, (void *)&volume_play);
			return(data);
		case RTATTEN:
			if(data >= 0x8000)
				return(255 - ((volume_play >> 8) & 0xff));
			volume_play &= 0xff;
			volume_play |= ((255 - data) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_PCM, (void *)&volume_play);
			return(data);
		case LTGAIN:
			if(data >= 0x8000)
				return(volume_record & 0xff);
			volume_record &= 0xff00;
			volume_record |= (data & 0xff);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_RECLEV, (void *)&volume_record);
			return(data);
		case RTGAIN:
			if(data >= 0x8000)
				return((volume_record >> 8) & 0xff);
			volume_record &= 0xff;
			volume_record |= ((data & 0xff) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_RECLEV, (void *)&volume_record);
			return(data);
		case ADDERIN: /* Select inputs to adder 0=off, 1=on */
			if(data >= 0x8000)
				return(adder_inputs);
			adder_inputs = data & 0x1ff;
			if(data & ADCIN) /* Input from ADC */
				val1 = 0x1ff0000;
			else
				val1 = 0x1000000;
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_MIC, (void *)&val1);
			if(data & MATIN) /* Input from connection matrix */
				val1 = 0x1ff0000;
			else
				val1 = 0x1000000;
			if(data & 0x4000) /* Bit 14 */
			{
				/* extended values valid by bit 5 of cookie '_SND'
				   Bit 2: Mic
				   Bit 3: FM-Generator, PC Beep on AC97
				   Bit 4: Line
				   Bit 5: CD
					 Bit 6: Video
				   Bit 7: Aux1
				   bit 8: PCM
				*/
				if(data & 4) /* Mic */
					val1 = 0x1ff0000;
				else
					val1 = 0x1000000;
				mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_MIC, (void *)&val1); // Mic
				if(data & 8) /* FM-Generator, PC Beep on AC97 */
					val1 = 0x1ff0000;
				else
					val1 = 0x1000000;
				mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_SYNTH, (void *)&val1);
				if(data & 0x10) /* Line */
					val1 = 0x1ff0000;
				else
					val1 = 0x1000000;
				mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_LINE, (void *)&val1);
				if(data & 0x20) /* CD */
					val1 = 0x1ff0000;
				else
					val1 = 0x1000000;
				mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_CD, (void *)&val1);
				if(data & 0x40) /* Video */
					val1 = 0x1ff0000;
				else
					val1 = 0x1000000;
				mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_LINE2, (void *)&val1);
				if(data & 0x80) /* Aux */
					val1 = 0x1ff0000;
				else
					val1 = 0x1000000;
				mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_LINE1, (void *)&val1); // Aux
				if(data & 0x100) /* PCM */
					val1 = 0x1ff0000;
				else
					val1 = 0x1000000;
				mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_PCM, (void *)&val1);
			}
			return(adder_inputs);
			break;
		case ADCINPUT: /* Select input to ADC, 0=mic, 1=PSG */
			if(data >= 0x8000)
				return(record_source);			
			record_source = data & (ADCRT | ADCLT | 0x3ffc);
			if(data & ADCRT) /* Right channel input */
				val2 = RECORD_SOURCE_AUX; /* (Coldari PSG) */
			else
				val2 = RECORD_SOURCE_MIC;
			if(data & ADCLT) /* Left channel input */
				val1 = RECORD_SOURCE_AUX;
			else
				val1 = RECORD_SOURCE_MIC;
			if(data & 0x4000) /* Bit 14 */
			{
				/* extended values valid by bit 5 of cookie '_SND'
				   Bit 2: right FM-Generator, 3D enable on AC97
				   Bit 3: left FM-Generator, not used on AC97
				   Bit 4: right Line input
				   Bit 5: left Line input
				   Bit 6: right CD
				   Bit 7: left CD                   
				   Bit 8: right Video
				   Bit 9: left Video
				   Bit 10: right Aux
				   Bit 11: left Aux
				   Bit 12: right Mix out
				   Bit 13: left Mix out
				*/
				if(!(data & 4)) /* right FM-Generator, 3D enable on AC97 */
				{
					val3 = 0x1ff0000;
					record_source &=  ~4;
				}
				else
					val3 = 0x1000000;
				mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_ENHANCE, (void *)&val3);
				if(!(data & 0x10)) /* Line right input */
					val2 = RECORD_SOURCE_LINE; 
				if(!(data & 0x20)) /* Line left input */
					val1 = RECORD_SOURCE_LINE; 
				if(!(data & 0x40)) /* CD right input */
					val2 = RECORD_SOURCE_CD;
				if(!(data & 0x80)) /* CD left input*/
					val1 = RECORD_SOURCE_CD;
				if(!(data & 0x100)) /* Video right */
					val2 = RECORD_SOURCE_VIDEO;
				if(!(data & 0x200)) /* Video left */
					val1 = RECORD_SOURCE_VIDEO;
				if(!(data & 0x400)) /* Aux right (Coldari PSG)  */
					val2 = RECORD_SOURCE_AUX;
				if(!(data & 0x800)) /* Aux left */
					val1 = RECORD_SOURCE_AUX;
				if(!(data & 0x1000)) /* Mix right out */
					val2 = RECORD_SOURCE_STEREO_MIX;
				if(!(data & 0x2000)) /* Mix left out */
					val1 = RECORD_SOURCE_STEREO_MIX;
			}
			switch(val1) // left
			{
				case RECORD_SOURCE_MIC: record_source &= ~ADCLT; break;
				case RECORD_SOURCE_CD: record_source &= ~0x80; break;
				case RECORD_SOURCE_VIDEO: record_source &= ~0x200; break;
				case RECORD_SOURCE_AUX: record_source &= ~0x800; break;
				case RECORD_SOURCE_LINE: record_source &= ~0x20; break;
				case RECORD_SOURCE_STEREO_MIX: record_source &= ~0x2000; break;
			}
			switch(val2) // right
			{
				case RECORD_SOURCE_MIC: record_source &= ~ADCRT; break;
				case RECORD_SOURCE_CD: record_source &= ~0x40; break;
				case RECORD_SOURCE_VIDEO: record_source &= ~0x100; break;
				case RECORD_SOURCE_AUX: record_source &= ~0x400; break;
				case RECORD_SOURCE_LINE: record_source &= ~0x10; break;
				case RECORD_SOURCE_STEREO_MIX: record_source &= ~0x1000; break;
			}
			val2 <<= 8;
			val2 |= val1;
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_RECSRC, (void *)&val2);
			return(record_source);
		case SETPRESCALE:
			if(data >= 0x8000)
				return prescale_ste;
			switch(data)
			{
				case PREMUTE:
				case PRE640:
				case PRE320:
				case PRE160:
					prescale_ste = data;
					break;
			}
			return(prescale_ste);
		case SETSMPFREQ: /* valid by bit 5 of cookie '_SND' */
			if(data != 0xFFFF)
			{
				int i = 0, index = 0;
				long d, mini = 999999;
				data &= 0xffff;
				while(i < sizeof(tab_freq_falcon)/sizeof(tab_freq_falcon[0]))
				{
					d = tab_freq_falcon[i++] - data;
					if(d < 0)
						d = -d;
					if(d < mini)
					{
						mini = d;
						index = i - 1;
					}
				}
				frequency = tab_freq_falcon[index];
			}
			return(frequency);
		case SETFMT8BITS: /* valid by bit 5 of cookie '_SND' */
			return(1); /* signed */
			break;
		case SETFMT16BITS: /* valid by bit 5 of cookie '_SND' */
			return(5); /* signed motorola big endian */
		case LTGAINMASTER: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return(volume_master & 0xff);
			volume_master &= 0xff00;
			volume_master |= (data & 0xff);
			val1 = 0x1ff0000;
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_VOLUME, (void *)&val1);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_VOLUME, (void *)&volume_master);
			return(data);
		case RTGAINMASTER: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return((volume_master >> 8) & 0xff);
			volume_master &= 0xff;
			volume_master |= (data << 8);
			val1 = 0x1ff0000;
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_VOLUME, (void *)&val1);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_VOLUME, (void *)&volume_master);
			return(data);
		case LTGAINMIC: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return(volume_mic & 0xff);
			volume_mic &= 0xff00;
			volume_mic |= (data & 0xff);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_MIC, (void *)&volume_mic);
			return(data);
		case RTGAINMIC: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return((volume_mic >> 8) & 0xff);
			volume_mic &= 0xff;
			volume_mic |= ((data & 0xff) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_MIC, (void *)&volume_mic);
			return(data);
		case LTGAINFM: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return(volume_fm & 0xff);
			volume_fm &= 0xff00;
			volume_fm |= (data & 0xff);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_SYNTH, (void *)&volume_fm); // PC Beep
			return(data);
		case RTGAINFM: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return((volume_fm >> 8) & 0xff);
			volume_fm &= 0xff;
			volume_fm |= ((data & 0xff) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_ENHANCE, (void *)&volume_fm); // 3D Control
			return(data);
		case LTGAINLINE: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return(volume_line & 0xff);
			volume_line &= 0xff00;
			volume_line |= (data & 0xff);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_LINE, (void *)&volume_line);
			return(data);
		case RTGAINLINE: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return((volume_line >> 8) & 0xff);
			volume_line &= 0xff;
			volume_line |= ((data & 0xff) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_LINE, (void *)&volume_line);
			return(data);
		case LTGAINCD: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return(volume_cd & 0xff);
			volume_cd &= 0xff00;
			volume_cd |= (data & 0xff);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_CD, (void *)&volume_cd);
			return(data);
		case RTGAINCD: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return((volume_cd >> 8) & 0xff);
			volume_cd &= 0xff;
			volume_cd |= ((data & 0xff) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_CD, (void *)&volume_cd);
			return(data);
		case LTGAINVIDEO: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return((volume_video >> 8) & 0xff);
			volume_video &= 0xff;
			volume_video |= ((data & 0xff) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_LINE2, (void *)&volume_video);
			return(data);
		case RTGAINVIDEO: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return((volume_video >> 8) & 0xff);
			volume_video &= 0xff;
			volume_video |= ((data & 0xff) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_LINE2, (void *)&volume_video);
			return(data);
		case LTGAINAUX: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return((volume_aux >> 8) & 0xff);
			volume_aux &= 0xff;
			volume_aux |= ((data & 0xff) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_LINE1, (void *)&volume_aux);
			return(data);
		case RTGAINAUX: /* valid by bit 5 of cookie '_SND' */
			if(data >= 0x8000)
				return((volume_aux >> 8) & 0xff);
			volume_aux &= 0xff;
			volume_aux |= ((data & 0xff) << 8);
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_LINE1, (void *)&volume_aux);
			return(data);
	}
	return(0);
}

long setbuffer(long reg, long begaddr, long endaddr)
{
	if(endaddr <= begaddr)
		return(1); // error
#ifdef DEBUG
	{
		char buf[10];
		display_string("setbuffer, reg: ");
		ltoa(buf, reg, 10);
		display_string(buf);
		display_string(", begaddr: 0x");
		ltoa(buf, (long)begaddr, 16);
		display_string(buf);
		display_string(", endaddr: 0x");
		ltoa(buf, (long)endaddr, 16);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	switch(reg)
	{
		case SR_PLAY:
			play_addr = begaddr;
			end_play_addr = endaddr;
			return(0); // OK
		case SR_RECORD:
			record_addr = begaddr;
			end_record_addr = endaddr;
			return(0); // OK
	}
	return(1); // error
}

long setmode(long mode)
{
	switch(mode & 0xff)
	{
		case STEREO8:
		case STEREO16:
		case MONO8:
		/* valid by bit 5 of cookie '_SND' */
		case MONO16:
			break;
		return(1); // error
	}
	switch(mode & 0xff00)
	{
		case RECORD_STEREO16:
		/* valid by bit 5 of cookie '_SND' */
		case RECORD_STEREO8:
		case RECORD_MONO8:
		case RECORD_MONO16:
    	break;
 		default:
 			return(1); // error
 	}
	mode_res = mode;
	return(0); // OK
}

long settracks(long playtracks, long rectracks)
{
	nb_tracks_play = playtracks & 3;
	nb_tracks_record = rectracks & 3; // not used actually
	return(0); // OK
}

long setmontracks(long track)
{
	mon_track = track & 3; // not used actually
	return(0); // OK
}

long setinterrupt(long src, long cause, void (*callback)())
{
#ifdef DEBUG
	{
		char buf[10];
		display_string("setinterrupt, src: ");
		ltoa(buf, src, 10);
		display_string(buf);
		display_string(", cause: ");
		ltoa(buf, cause, 10);
		display_string(buf);
		if(src == SI_CALLBACK)
		{
			display_string(", callback: 0x");
			ltoa(buf, (long)callback, 16);
			display_string(buf);
		}
		display_string("\r\n");
	}
#endif
	switch(src)
	{
		case SI_TIMERA:
			switch(cause)
			{
				case SI_NONE:
				case SI_PLAY:
				case SI_RECORD:
				case SI_BOTH:
					cause_inter = cause;
					return(0); // OK
			}
			break;
		case SI_MFPI7:
			switch(cause)
			{
				case SI_NONE:
				case SI_PLAY:
				case SI_RECORD:
				case SI_BOTH:
					cause_inter = cause | 0x100;
					return(0); // OK
			}
			break;
		case SI_CALLBACK: // valid by bit 5 of cookie '_SND'
			switch(cause)
			{
				case SI_NONE: callback_play = callback_record = NULL; break; // disable interrupt
				case SI_PLAY: callback_play = callback; break;	// int_addr called on eof DAC interrupts
				case SI_RECORD: callback_record = callback;	break; // int_addr called on eof ADC interrupts
				case SI_BOTH: callback_play = callback_record = callback; break; // int_addr called on eof DAC/ADC interrupts
					mcf548x_ac97_playback_callback(AC97_DEVICE, callback_play);
					mcf548x_ac97_capture_callback(AC97_DEVICE, callback_record);
          cause_inter = 0;
					return(0); // OK
			}
			break;
	}
	return(1); // error
}

long buffoper(long mode)
{
	void *ptr[2];
	void *ptr_play, *ptr_record;
#ifdef DEBUG
	if(mode >= 0)
	{
		char buf[10];
		display_string("buffoper, mode: ");
		ltoa(buf, mode, 10);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	mcf548x_ac97_playback_pointer(AC97_DEVICE, &ptr_play, 0);
	mcf548x_ac97_capture_pointer(AC97_DEVICE, &ptr_record, 0);
	if(ptr_play == NULL)
		stop_dma_play(); /* => status_dma update */
	if(ptr_record == NULL)
		stop_dma_record(); /* => status_dma update */
	if(mode < 0)
	  return(status_dma);
	if((mode & SB_PLA_ENA) /* Play enable */
	 && !(status_dma & SI_PLAY))
	{
		if(!mcf548x_ac97_playback_open(AC97_DEVICE))
		{
			if(!mcf548x_ac97_playback_prepare(AC97_DEVICE, frequency, mode_res, mode))
			{
				ptr[0] = (void *)play_addr;
				ptr[1] = (void *)end_play_addr;
				if(!mcf548x_ac97_playback_pointer(AC97_DEVICE, (void **)&ptr, 1)
				 && !mcf548x_ac97_playback_callback(AC97_DEVICE, callback_play)
				 && !mcf548x_ac97_playback_trigger(AC97_DEVICE, 1))
			 		status_dma |= SI_PLAY;
		 	}
		 	else
				mcf548x_ac97_playback_close(AC97_DEVICE);
		}
	}
	if(!(mode & SB_PLA_ENA) && (status_dma & SI_PLAY))
	{
		mcf548x_ac97_playback_trigger(AC97_DEVICE, 0);
		mcf548x_ac97_playback_close(AC97_DEVICE);
		return(0);	
	}
	if((mode & SB_REC_ENA) /* Record enable */
	 && !(status_dma & SI_RECORD))
	{
		if(!mcf548x_ac97_capture_open(AC97_DEVICE))
		{
			if(!mcf548x_ac97_capture_prepare(AC97_DEVICE, frequency, mode_res, mode))
			{
				ptr[0] = (void *)record_addr;
				ptr[1] = (void *)end_record_addr;
				if(!mcf548x_ac97_capture_pointer(AC97_DEVICE, (void **)&ptr, 1)
				 && !mcf548x_ac97_capture_callback(AC97_DEVICE, callback_record)
				 && !mcf548x_ac97_capture_trigger(AC97_DEVICE, 1))
					status_dma |= SI_RECORD;
			}
			else
				mcf548x_ac97_capture_close(AC97_DEVICE);
		}
	}
	if(!(mode & SB_REC_ENA) && (status_dma & SI_RECORD))
	{
		mcf548x_ac97_capture_trigger(AC97_DEVICE, 0);
		mcf548x_ac97_capture_close(AC97_DEVICE);
		return(0);	
	}
	return(0); // OK
}

long gpio(long mode, long data)
{
// bit0: 0: external clock 22.5792 Mhz for 44.1KHz, 1: clock 24.576 MHz for 48KHZ
// bit1: 1 for quartz
#ifdef DEBUG
	char buf[10];
	display_string("gpio, mode: ");
	ltoa(buf, mode, 10);
	display_string(buf);
	display_string(", data: ");
	ltoa(buf, data, 10);
	display_string(buf);
	display_string("\r\n");
#endif
	switch(mode)
	{
		case GPIO_READ:
			return(flag_clock_44_48 ? 3 : 2);
		case GPIO_WRITE:
			flag_clock_44_48 = data & 1;
   		break;
	}
	return(0); // OK
}

long devconnect(long src, long dest, long srcclk, long prescale, long protocol)
{
#ifdef DEBUG
	char buf[10];
	display_string("devconnect, src: ");
	ltoa(buf, src, 10);
	display_string(buf);
	display_string(", dest: ");
	ltoa(buf, dest, 10);
	display_string(buf);
	display_string(", srcclk: ");
	ltoa(buf, srcclk, 10);
	display_string(buf);
	display_string(", prescale: ");
	ltoa(buf, prescale, 10);
	display_string(buf);
	display_string("\r\n");
#endif
	switch(prescale)
	{
		case CLKOLD:
		case CLK50K:
		case CLK33K:
		case CLK25K:
		case CLK20K:
		case CLK16K:
		case CLK12K:
		case CLK10K:
		case CLK8K:
			break;
    default:
    	return(1); // error
	}
	switch(srcclk)
	{
		case CLK25M:
		  if(prescale == CLKOLD)
		  	frequency = tab_freq_ste[prescale_ste & 3];
		  else
		  	frequency = tab_freq_falcon[prescale - 1];
			break;		
		case CLKEXT:
		  if(prescale == CLKOLD)
		  	frequency = (long)tab_freq_ste[prescale_ste & 3] & 0xFFFF;
		  else
		  {
		  	if(!flag_clock_44_48)
		  		frequency = (long)tab_freq_falcon[prescale + 11 - 1] & 0xFFFF;
				else
		  		frequency = (long)tab_freq_falcon[prescale + (11*2) - 1] & 0xFFFF;
		 	}
			break;
		default:
			return(1); // error
	}
	switch(src)
	{
		case DMAPLAY:
		case ADC:
			return(0); // OK
		case DSPXMIT:
		case EXTINP:
		default:
			return(1); // error
	}
/* dest: DMAREC 1, DSPRECV 2, EXTOUT 4, DAC 8 */
}

long sndstatus(long reset)
{
	long data = 0;
	switch(reset)
	{
		case SND_CHECK:
			return(SS_OK);
		case SND_RESET:
			stop_dma_play();
			stop_dma_record();
			soundcmd(LTATTEN, 0);
			soundcmd(RTATTEN, 0);
			soundcmd(LTGAIN, 0);
			soundcmd(RTGAIN, 0); 
			soundcmd(ADDERIN, ADCIN + 0x41B4); /* + PCM / Aux / CD / Mic */
			soundcmd(ADCINPUT, 0);
			soundcmd(LTGAINMASTER, 255);
			soundcmd(RTGAINMASTER, 255); 
			soundcmd(LTGAINMIC, 0);
			soundcmd(RTGAINMIC, 0);
			soundcmd(LTGAINLINE, 0);
			soundcmd(RTGAINLINE, 0);
			soundcmd(LTGAINCD, 0);
			soundcmd(RTGAINCD, 0);
			soundcmd(LTGAINVIDEO, 0);
			soundcmd(RTGAINVIDEO, 0);
			soundcmd(LTGAINAUX, 255);
			soundcmd(RTGAINAUX, 255);
			data = 0x1ff0000; /* enable */
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_SPEAKER, (void *)&data);
			data = 0xffff;
			mcf548x_ac97_ioctl(AC97_DEVICE, SOUND_MIXER_WRITE_SPEAKER, (void *)&data);
			status_dma = 0;
			nb_tracks_play = nb_tracks_record = mon_track = 0;
			flag_clock_44_48 = prescale_ste = 0;
			play_addr = record_addr = 0;
			cause_inter = 0;
			callback_play = callback_record = NULL;
			return(SS_OK);
		/* extended values valid by bit 5 of cookie '_SND' */
		case 2: // resolutions
			return(3); // 8 & 16 bits
		case 3: // MasterMix
		  /* Bit 0: A/D (ADC-InMix bypass)   X
		     Bit 1: D/A (DAC/Multiplexer)    X
		     Bit 2: Mic                      X
		     Bit 3: FM-Generator             X (PC Beep)
		     Bit 4: Line                     X
		     Bit 5: CD                       X
		     Bit 6: Video                    X
		     Bit 7: Aux1                     X
		   */
			return(0xff);
		case 4: // record sources
			/* Bit 0: Mic right                X
			   Bit 1: Mic left                 X
			   Bit 2: FM-Generator right       X (3D Control)
			   Bit 3: FM-Generator left        X (PC Beep)
			   Bit 4: Line right               X
			   Bit 5: Line left                X
			   Bit 6: CD right                 X
			   Bit 7: CD left                  X
			   Bit 8: Video right              X
			   Bit 9: Video left               X
			   Bit 10: Aux1 right              X
			   Bit 11: Aux1 left               X
			   Bit 12: Mixer right (MasterMix) X
			   Bit 13: Mixer left (MasterMix)  X
			*/
			return(0x3fff);
		case 5: // duplex
			return(0);
		case 8: // format8bits
			return(1); // signed
		case 9: // format16bits
			return(5); // signed motorola big endian
		default:
			return(SS_OK);
	}
}

long buffptr(SndBufPtr *ptr)
{
	mcf548x_ac97_playback_pointer(AC97_DEVICE, (void **)&ptr->play, 0);
	mcf548x_ac97_capture_pointer(AC97_DEVICE, (void **)&ptr->record, 0);
#ifdef DEBUG
	{
		char buf[10];
		display_string("buffptr, play: 0x");
		ltoa(buf, (long)ptr->play, 16);
		display_string(buf);
		display_string(", record: 0x");
		ltoa(buf, (long)ptr->record, 16);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	if(ptr->play == NULL)
	{
		ptr->play = (char *)play_addr;
		stop_dma_play();
	}
	if(ptr->record == NULL)
	{
		ptr->record = (char *)record_addr;
		stop_dma_record();
	}
	ptr->reserve1 = ptr->reserve2 = 0;
	return(0); // OK
}

long InitSound(void)
{
	if(!mcf548x_ac97_install(AC97_DEVICE))
	{
		COOKIE mcsn;
		COOKIE gsxb;
		COOKIE *p = get_cookie('_SND');
		if(p != 0)
		{
			p->v.l &= 0x9;  /* preserve PSG & DSP bits */
			p->v.l |= 0x26; /* bit 5: extended mode, bit 2: 16 bits DMA, bit 1: 8 bits DMA */
		}
		mcsn.ident = 'McSn';
		mcsn.v.l = (long)&cookie_mac_sound;
		add_cookie(&mcsn);
		gsxb.ident = 'GSXB';
		gsxb.v.l = 0;
		add_cookie(&gsxb);
		flag_snd_init = 1;
		sndstatus(SND_RESET);
		return(0); // OK
	}
	flag_snd_init = 0;
	return(-1); // error
}

#else

long InitSound(void)
{
	return(-1); // error
}

#endif /* SOUND_AC97 */

#endif /* MCF5445X */
#endif /* COLDFIRE */
#endif /* NETWORK */

