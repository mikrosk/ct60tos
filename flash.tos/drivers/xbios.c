/* TOS 4.04 Xbios calls for the CT60/CTPCI & Coldfire boards
 * Coldfire Xbios AC97 Sound 
 * Didier Mequignon 2005-2012, e-mail: aniplay@wanadoo.fr
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
#include <mint/mintbind.h>
#include <mint/falcon.h>
#include <mint/sysvars.h>
#include <string.h>
#include "fb.h"
#include "radeon/radeonfb.h"
#include "lynx/smi.h"
#include "ct60.h"

extern void init_var_linea(long video_found);
extern long call_enumfunc(long (*enumfunc)(SCREENINFO *inf, long flag), SCREENINFO *inf, long flag);
#define board_printf kprint
extern void kprint(const char *fmt, ...);

unsigned long physbase(void);
long vgetsize(long modecode);
long validmode(long modecode);

extern void ltoa(char *buf, long n, unsigned long base);                                    
extern void cursor_home(void);
   
#define XBIOS_SCREEN_VERSION 0x0101

#define Modecode (*((short*)0x184C))

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
extern struct fb_info *info_fvdi;
extern struct mode_option resolution;
extern const struct fb_videomode modedb[];
extern const struct fb_videomode vesa_modes[];
extern long total_modedb;
extern short video_found, video_log, os_magic, memory_ok, drive_ok;
#ifdef USE_RADEON_MEMORY
extern short lock_video;
#endif
long fix_modecode, second_screen, second_screen_aligned, log_addr;

static short modecode_magic;
static long bios_colors[256]; 

/* some XBIOS functions for the video driver */

#ifdef RADEON_RENDER
int display_composite_texture(long op, unsigned char *src_tex, long src_x, long src_y, long w_tex, long h_tex, long dst_x, long dst_y, long width, long height)
{
	struct fb_info *info = info_fvdi;
	unsigned long dstFormat;
	if(info->screen_mono != NULL)
		return(0);
	switch(info->var.bits_per_pixel)
	{
		case 16: dstFormat = PICT_r5g6b5; break;
		case 32: dstFormat = PICT_x8r8g8b8; break;
		default: return(0);	
	}
	if(info->fbops->SetupForCPUToScreenTexture(info, (int)op, PICT_a8r8g8b8, dstFormat, src_tex, (int)w_tex << 2 , (int)w_tex, (int)h_tex, 0))
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
				info->fbops->SubsequentCPUToScreenTexture(info, (int)dst_x, (int)dst_y, (int)src_x, (int)src_y, (int)w, (int)h);
				dst_x += w_tex;		
			}
			dst_y += h_tex;
		}
	}
	return(1);
}
#endif /* RADEON_RENDER */

void display_mono_block(char *src_buf, long dst_x, long dst_y, long w, long h, long foreground, long background, long src_wrap)
{
	int skipleft;
	if(info_fvdi->screen_mono != NULL)
		return;
	info_fvdi->fbops->SetClippingRectangle(info_fvdi, (int)dst_x, (int)dst_y, (int)w - 1, (int)h -1);
	skipleft = ((int)src_buf & 3) << 3;
	src_buf = (char *)((int)src_buf & ~3);
	dst_x -= skipleft;
	w += skipleft;
	info_fvdi->fbops->SetupForScanlineCPUToScreenColorExpandFill(info_fvdi, (int)foreground, (int)background, 3, 0xffffffff);
	info_fvdi->fbops->SubsequentScanlineCPUToScreenColorExpandFill(info_fvdi, (int)dst_x, (int)dst_y, (int)w, (int)h, (int)skipleft);
	while(--h >= 0)
	{
		info_fvdi->fbops->SubsequentScanline(info_fvdi, (unsigned long*)src_buf);
		src_buf += src_wrap;
	}
	info_fvdi->fbops->DisableClipping(info_fvdi);
	info_fvdi->fbops->fb_sync(info_fvdi);	
}

long clear_screen(long bg_color, long x, long y, long w, long h)
{
	struct fb_info *info = info_fvdi;
	if(info->screen_mono != NULL)
		return(0);
	if(bg_color == -1)
	{
		x = y = 0;
		w = info->var.xres_virtual;
		h = info->var.yres_virtual;
		if(info->var.bits_per_pixel >= 16)
			info->fbops->SetupForSolidFill(info, 0, 15, 0xffffffff);  /* set */
		else
			info->fbops->SetupForSolidFill(info, 0, 0, 0xffffffff);   /* clr */
	}
	else if(bg_color == -2)
	{
		switch(info->var.bits_per_pixel)
		{
			case 8: bg_color = 0xff; break;
			case 16: bg_color = 0xffff; break;
			default: bg_color = 0xffffff; break;
		}
		info->fbops->SetupForSolidFill(info, (int)bg_color, 6, 0xffffffff);  /* xor */
	}
	else
		info->fbops->SetupForSolidFill(info, (int)bg_color, 3, 0xffffffff);  /* copy */
	info->fbops->SubsequentSolidFillRect(info, (int)x, (int)y, (int)w, (int)h);
	info->fbops->fb_sync(info);
	return(1);
}

long fill_screen(long op, long bg_color, long x, long y, long w, long h)
{
	struct fb_info *info = info_fvdi;
	if(info->screen_mono != NULL)
		return(0);
	info->fbops->SetupForSolidFill(info, (int)bg_color, (int)op, 0xffffffff);
	info->fbops->SubsequentSolidFillRect(info, (int)x, (int)y, (int)w, (int)h);
	info->fbops->fb_sync(info);
	return(1);
}

long line_screen(long op, long fg_color, long bg_color, long x1, long y1, long x2, long y2, long pattern)
{
	struct fb_info *info = info_fvdi;
	if(info->screen_mono != NULL)
		return(0);
	if(pattern == -1) /* solid line */
	{
		info->fbops->SetupForSolidLine(info, (int)fg_color, (int)op, 0xffffff);
		if(info->fbops->SubsequentSolidTwoPointLine == NULL)
			return(0);
		info->fbops->SubsequentSolidTwoPointLine(info, (int)x1, (int)y1, (int)x2, (int)y2, OMIT_LAST);	
	}
	else
	{
		if(info->fbops->SetupForDashedLine == NULL)
			return(0);
		info->fbops->SetupForDashedLine(info, (int)fg_color, (int)bg_color, (int)op, 0xffffffff, 32, (unsigned char *)&pattern);
		info->fbops->SubsequentDashedTwoPointLine(info, (int)x1, (int)y1, (int)x2, (int)y2, OMIT_LAST,0);
	}
	return(1);
}							

long move_screen(long src_x, long src_y, long dst_x, long dst_y, long w, long h)
{
	int xdir = (int)(src_x - dst_x);
	int ydir = (int)(src_y - dst_y);
	if(info_fvdi->screen_mono != NULL)
		return(0);
	info_fvdi->fbops->SetupForScreenToScreenCopy(info_fvdi, xdir, ydir, 3, 0xffffffff, -1);
	info_fvdi->fbops->SubsequentScreenToScreenCopy(info_fvdi, (int)src_x, (int)src_y, (int)dst_x, (int)dst_y, (int)w, (int)h);
	info_fvdi->fbops->fb_sync(info_fvdi);
	return(1);
}

long copy_screen(long op, long src_x, long src_y, long dst_x, long dst_y, long w, long h)
{
	int xdir = (int)(src_x - dst_x);
	int ydir = (int)(src_y - dst_y);
	if(info_fvdi->screen_mono != NULL)
		return(0);
	info_fvdi->fbops->SetupForScreenToScreenCopy(info_fvdi, xdir, ydir, op, 0xffffffff, -1);
	info_fvdi->fbops->SubsequentScreenToScreenCopy(info_fvdi, (int)src_x, (int)src_y, (int)dst_x, (int)dst_y, (int)w, (int)h);
	info_fvdi->fbops->fb_sync(info_fvdi);
	return(1);
}

long clip_screen(long clip_on, long dst_x, long dst_y, long w, long h)
{
	struct fb_info *info = info_fvdi;
	if(info->screen_mono != NULL)
		return(0);
	if(clip_on)
		info->fbops->SetClippingRectangle(info, (int)dst_x, (int)dst_y, (int)(dst_x + w - 1), (int)(dst_y + h - 1));
	else
		info->fbops->DisableClipping(info);
	return(1);
}

long print_screen(char *character_source, long x, long y, long w, long h, long cell_wrap, long fg_color, long bg_color)
{
	static char buffer[256*16]; /* maximum width 2048 pixels, 256 characters, height 16 */
	static long pos_x, pos_y, length, height, foreground, background, old_timer;
	char *ptr;
	if(info_fvdi->screen_mono != NULL)
		return(0);
	if(character_source == (char *)-1) /* init */
	{
		pos_x = -1;
		old_timer = *_hz_200;
	}
	else if(character_source != NULL)
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
	else if(pos_x >= 0)   /* flush buffer */
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

void display_atari_logo(void)
{
#define WIDTH_LOGO 96
#define HEIGHT_LOGO 86
#ifndef TOS_ATARI_LOGO
	static unsigned short logo[] = 
	{
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0x79FF,0x3C00,0x0000,0x0000,
		0x0000,0x0000,0xF9FF,0x3E00,0x0000,0x0000,
		0x0000,0x0000,0xF9FF,0x3E00,0x0000,0x0000,
		0x0000,0x0000,0xF9FF,0x3E00,0x0000,0x0000,
		0x0000,0x0000,0xF9FF,0x3E00,0x0000,0x0000,
		0x0000,0x0000,0xF9FF,0x3E00,0x0000,0x0000,
		0x0000,0x0000,0xF9FF,0x3E00,0x0000,0x0000,
		0x0000,0x0001,0xF9FF,0x3F00,0x0000,0x0000,
		0x0000,0x0001,0xF9FF,0x3F00,0x0000,0x0000,
		0x0000,0x0001,0xF9FF,0x3F00,0x0000,0x0000,
		0x0000,0x0001,0xF9FF,0x3F00,0x0000,0x0000,
		0x0000,0x0003,0xF9FF,0x3F80,0x0000,0x0000,
		0x0000,0x0003,0xF9FF,0x3F80,0x0000,0x0000,
		0x0000,0x0003,0xF9FF,0x3F80,0x0000,0x0000,
		0x0000,0x0007,0xF1FF,0x1FC0,0x0000,0x0000,
		0x0000,0x0007,0xF1FF,0x1FC0,0x0000,0x0000,
		0x0000,0x000F,0xF1FF,0x1FE0,0x0000,0x0000,
		0x0000,0x000F,0xF1FF,0x1FE0,0x0000,0x0000,
		0x0000,0x001F,0xE1FF,0x0FF0,0x0000,0x0000,
		0x0000,0x003F,0xE1FF,0x0FF8,0x0000,0x0000,
		0x0000,0x003F,0xE1FF,0x0FF8,0x0000,0x0000,
		0x0000,0x007F,0xC1FF,0x07FC,0x0000,0x0000,
		0x0000,0x00FF,0xC1FF,0x07FE,0x0000,0x0000,
		0x0000,0x01FF,0x81FF,0x03FF,0x0000,0x0000,
		0x0000,0x03FF,0x81FF,0x03FF,0x8000,0x0000,
		0x0000,0x07FF,0x01FF,0x01FF,0xC000,0x0000,
		0x0000,0x0FFE,0x01FF,0x00FF,0xE000,0x0000,
		0x0000,0x1FFE,0x01FF,0x00FF,0xF000,0x0000,
		0x0000,0x7FFC,0x01FF,0x007F,0xFC00,0x0000,
		0x0000,0xFFF8,0x01FF,0x003F,0xFE00,0x0000,
		0x0003,0xFFF0,0x01FF,0x001F,0xFF80,0x0000,
		0x001F,0xFFE0,0x01FF,0x000F,0xFFF0,0x0000,
		0x00FF,0xFFC0,0x01FF,0x0007,0xFFFE,0x0000,
		0x00FF,0xFF80,0x01FF,0x0003,0xFFFE,0x0000,
		0x00FF,0xFF00,0x01FF,0x0001,0xFFFE,0x0000,
		0x00FF,0xFC00,0x01FF,0x0000,0x7FFE,0x0000,
		0x00FF,0xF800,0x01FF,0x0000,0x3FFE,0x0000,
		0x00FF,0xE000,0x01FF,0x0000,0x0FFE,0x0000,
		0x00FF,0x8000,0x01FF,0x0000,0x03FE,0x0000,
		0x00FC,0x0000,0x01FF,0x0000,0x007E,0x0000,
		0x00E0,0x0000,0x01FF,0x0000,0x000E,0x0000,
		0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
		0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
		0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
		0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
		0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
		0x0000,0xC07F,0xFE03,0x0007,0xC01E,0x0700,
		0x0001,0xE07F,0xFE07,0x801F,0xF81E,0x18C0,
		0x0003,0xE07F,0xFE0F,0x803F,0xFC1E,0x1740,
		0x0003,0xF07F,0xFE0F,0xC03F,0xFE1E,0x2520,
		0x0003,0xF07F,0xFE0F,0xC03F,0xFE1E,0x2620,
		0x0007,0xF803,0xC01F,0xE03C,0x1F1E,0x2520,
		0x0007,0xF803,0xC01F,0xE03C,0x0F1E,0x1540,
		0x0007,0xF803,0xC01F,0xE03C,0x0F1E,0x18C0,
		0x000F,0x7C03,0xC03D,0xF03C,0x0F1E,0x0700,
		0x000F,0x3C03,0xC03C,0xF03C,0x0F1E,0x0000,
		0x000F,0x3C03,0xC03C,0xF03C,0x1E1E,0x0000,
		0x001E,0x3E03,0xC078,0xF83C,0x7E1E,0x0000,
		0x001E,0x1E03,0xC078,0x783D,0xFC1E,0x0000,
		0x001E,0x1E03,0xC078,0x783D,0xF81E,0x0000,
		0x003E,0x1F03,0xC0F8,0x7C3D,0xE01E,0x0000,
		0x003F,0xFF03,0xC0FF,0xFC3D,0xE01E,0x0000,
		0x003F,0xFF03,0xC0FF,0xFC3D,0xE01E,0x0000,
		0x007F,0xFF83,0xC1FF,0xFE3C,0xF01E,0x0000,
		0x007F,0xFF83,0xC1FF,0xFE3C,0xF81E,0x0000,
		0x0078,0x0783,0xC1E0,0x1E3C,0x781E,0x0000,
		0x00F8,0x07C3,0xC3E0,0x1F3C,0x3C1E,0x0000,
		0x00F0,0x07C3,0xC3C0,0x1F3C,0x3E1E,0x0000,
		0x00F0,0x03C3,0xC3C0,0x0F3C,0x1E1E,0x0000,
		0x01F0,0x03E3,0xC7C0,0x0FBC,0x1F1E,0x0000,
		0x01E0,0x01E3,0xC780,0x07B8,0x0F1E,0x0000
};
#endif /* TOS_ATARI_LOGO */
	unsigned long base_addr = (unsigned long)physbase();
	struct fb_info *info = info_fvdi;
	unsigned char *buf_tex = NULL;
	unsigned long *ptr32 = NULL;
	unsigned short *ptr16 = NULL;
	unsigned char *ptr8 = NULL;
	int i, j, k, cnt = 1;
	int bpp = info->var.bits_per_pixel;
	unsigned short val, color = 0;
	unsigned long color2 = 0, r, g, b;
	unsigned long incr = mul32(info->var.xres_virtual, bpp >> 3); // line above not works on CF ?!?!
//	unsigned long incr = (unsigned long)(info->var.xres_virtual * (bpp >> 3));
	if(info->screen_mono != NULL) /* VBL monochrome emulation */
	{
		bpp = 1;
		incr = (unsigned long)(info->var.xres_virtual >> 3);
	}
#ifdef RADEON_RENDER
	if(video_found && (info->screen_mono == NULL) && (bpp >= 16) && (info->fbops->SetupForCPUToScreenTexture != NULL))
	{
		buf_tex = (unsigned char *)Malloc(HEIGHT_LOGO * WIDTH_LOGO * 4);
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
#ifdef TOS_ATARI_LOGO
		unsigned short *logo_atari = (unsigned short *)0xE49434; /* logo ATARI monochrome inside TOS 4.04 */
#else
		unsigned short *logo_atari = logo;
#endif
#ifdef RADEON_RENDER
		if(buf_tex != NULL)
			base_addr = (unsigned long)buf_tex;
#endif
		g = 3;
		for(i = 0; i < 86; i++) // lines
		{
			switch(bpp)
			{
				case 1:
					ptr16 = (unsigned short *)base_addr;
					break;
				case 16:
					if(i < 56)
					{
						r = (unsigned long)((63 - i) >> 1) & 0x1F;
						if(i < 28)
							g++;
						else
							g--;
						b = (unsigned long)((i + 8) >> 1) & 0x1F;
						color = (unsigned short)((r << 11) + (g << 6) + b);
					}
					else
						color = 0;
					ptr16 = (unsigned short *)base_addr;
					break;
				case 32:
					if(i < 56)
					{
						r = (unsigned long)(63 - i) & 0x3F;
						if(i < 28)
							g++;
						else
							g--;
						b = (unsigned long)(i + 8) & 0x3F;
						if((buf_tex != NULL) && cnt)
						{
							color2 = ((r << 15) & 0xFF0000) + (g << 8) + ((b >> 1) & 0xFF);
							color2 |= 0xE0E0E0;
						}
						else
							color2 = (r << 18) + (g << 11) + (b << 2);
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
					case 1:
						*ptr16++ = *logo_atari++;
						break;
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
#ifdef RADEON_RENDER
		if(buf_tex != NULL)
		{
			if(cnt)
				display_composite_texture(3, buf_tex, 0, 0, WIDTH_LOGO, HEIGHT_LOGO, 0, 0, info->var.xres_virtual, info->var.yres_virtual);
			else
				display_composite_texture(1, buf_tex, 0, 0, WIDTH_LOGO, HEIGHT_LOGO, 0, 0, WIDTH_LOGO, HEIGHT_LOGO);
		}
#endif
	}
	if(info->screen_mono != NULL) /* VBL monochrome emulation */
		info->update_mono = 1;
#ifdef RADEON_RENDER
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
	struct fb_info *info = info_fvdi;
	long foreground, background;
	long dst_x = (long)info->var.xres - w;
	if(info->screen_mono != NULL)
		return;
	switch(info->var.bits_per_pixel)
	{
		case 8: foreground = 1; background = 7; break; /* red & grey */
		case 16: foreground = 0xF800; background = 0xB596; break;
		default: foreground = 0xFF0000; background = 0xB0B0B0; break;
	}
	display_mono_block(((char *)logo)+1, dst_x, dst_y, w, h, foreground, background, src_wrap);
#endif
}

const struct fb_videomode *get_db_from_modecode(long modecode)
{
	const struct fb_videomode *db;
	long devID = GET_DEVID(modecode);
	if(devID < VESA_MODEDB_SIZE)
		db = &vesa_modes[devID];		
	else
	{
		devID -= VESA_MODEDB_SIZE;
		if(devID < total_modedb)
			db = &modedb[devID];
		else if(video_found == 1) /* Radeon */
		{
			struct radeonfb_info *rinfo = info_fvdi->par;
			devID -= total_modedb;
			if(devID < rinfo->mon1_dbsize)
				db = &rinfo->mon1_modedb[devID];
			else
				return(NULL);
		}
		else if(video_found == 2) /* Lynx */
		{
			struct radeonfb_info *smiinfo = info_fvdi->par;
			devID -= total_modedb;
			if(devID < smiinfo->mon1_dbsize)
				db = &smiinfo->mon1_modedb[devID];
			else
				return(NULL);
		}	
		else
			return(NULL);
	}
	return(db);
}

long get_modecode_from_screeninfo(struct fb_var_screeninfo *var)
{
	const struct fb_videomode *db = NULL;
	long modecode, i, nb = 0;
	if(info_fvdi->screen_mono)
		modecode = BPS1; /* VBL mono emulation */
	else
	{
		switch(var->bits_per_pixel)
		{
			case 16: modecode = BPS16; break;
			case 32: modecode = BPS32; break;
			default: modecode = BPS8; break;
		}
	}
	if(video_found == 1) /* Radeon */
	{
		struct radeonfb_info *rinfo = info_fvdi->par;
		if((nb = rinfo->mon1_dbsize) != 0)
			db = rinfo->mon1_modedb;
	}
	else if(video_found == 2) /* Lynx */
	{
		struct radeonfb_info *smiinfo = info_fvdi->par;
		if((nb = smiinfo->mon1_dbsize) != 0)
			db = smiinfo->mon1_modedb;
	}
	if(db != NULL)
	{
		for(i = 0; i < nb; i++)
		{
			if(((unsigned long)db->xres == var->xres) && ((unsigned long)db->yres == var->yres) && ((unsigned long)db->refresh == var->refresh))
				return(SET_DEVID(i + VESA_MODEDB_SIZE + total_modedb) + modecode);
			db++;
		}
	}
	db = modedb;
	for(i = 0; i < total_modedb; i++)
	{
		if(((unsigned long)db->xres == var->xres) && ((unsigned long)db->yres == var->yres) && ((unsigned long)db->refresh == var->refresh))
			return(SET_DEVID(i + VESA_MODEDB_SIZE) + modecode);
		db++;
	}
	db = vesa_modes;
	for(i = 0; i < VESA_MODEDB_SIZE; i++)
	{
		if(((unsigned long)db->xres == var->xres) && ((unsigned long)db->yres == var->yres) && ((unsigned long)db->refresh == var->refresh))
			return(SET_DEVID(i) + modecode);
		db++;
	}
	return(-1);
}

void init_screen_info(SCREENINFO *si, long modecode)
{
	char buf[16];
	long flags = 0;
	struct fb_info *info = info_fvdi;
	if(si->size < sizeof(SCREENINFO) - 8)
		return;
	switch(modecode & NUMCOLS)
	{
		case BPS1: /* VBL mono emulation */
			si->scrPlanes = 1;
			si->scrColors = 2;
			si->redBits = si->greenBits = si->blueBits = 255;
			si->unusedBits = 0;
			break;
		case BPS8:
			si->scrPlanes = 8;
			si->scrColors = 256;
			si->redBits = si->greenBits = si->blueBits = 255;
			si->unusedBits = 0;
			break;
		case BPS16:
			si->scrPlanes = 16;
			si->scrColors = 65536;
			si->redBits = 0xF800;                    /* mask of red bits */
			si->greenBits = 0x3E0;                   /* mask of green bits */
			si->blueBits = 0x1F;                     /* mask of blue bits */
			si->unusedBits = 0;                      /* mask of unused bits */
			break;
		case BPS32:
			si->scrPlanes = 32;
			si->scrColors = 16777216;
			si->redBits = 0xFF0000;                 /* mask of red bits */
			si->greenBits = 0xFF00;                 /* mask of green bits */
			si->blueBits = 0xFF;                    /* mask of blue bits */
			si->unusedBits = 0xFF000000;            /* mask of unused bits */
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
		const struct fb_videomode *db = get_db_from_modecode(modecode);
		if(db == NULL)
		{
			si->scrFlags = 0;
			return;
		}
		si->scrWidth = (long)db->xres;
		si->scrHeight = (long)db->yres;
		si->refresh = (long)db->refresh;
		si->pixclock = (long)db->pixclock;
		flags = (long)db->flag;
	}
	if((si->scrPlanes == 1)
	 && ((os_magic == 1) || (si->scrWidth > MAX_WIDTH_EMU_MONO) || (si->scrHeight > MAX_HEIGHT_EMU_MONO)
	  || (modecode & VIRTUAL_SCREEN))) /* limit size for the VBL mono emulation */
	{
		si->scrFlags = 0;
		return;
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
	si->max_x = si->virtWidth;
	si->max_y = 8192; /* max. possible heigth/width ??? */
	si->maxmem = si->max_x * si->max_y * (si->scrPlanes / 8);
	si->pagemem = vgetsize(modecode);
	if(!si->devID && si->size && (si->size >= sizeof(SCREENINFO)))
	{
		if(info->var.refresh)
			si->refresh = info->var.refresh;
		if(info->var.pixclock)
			si->pixclock = info->var.pixclock;
		si->devID = modecode;
	}
	si->scrFlags = SCRINFO_OK;
}

static long update_modecode(long modecode)
{
	if(os_magic == 1)
		modecode_magic = (short)modecode;
	else
		Modecode = (short)modecode;
	return(modecode);
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
	long Mode;
	if(os_magic == 1)
		Mode = (long)modecode_magic & 0xFFFF;
	else
		Mode = (long)Modecode & 0xFFFF;
//	board_printf("init_resolution modecode %04X (%04X)\r\n", modecode, Mode);
	switch(modecode & NUMCOLS)
	{
		case BPS1: 
			if(os_magic == 1)
				break;
			resolution.flags = MODE_EMUL_MONO_FLAG; resolution.bpp = 1; break;
		case BPS16: resolution.flags = 0; resolution.bpp = 16; break;
		case BPS32: resolution.flags = 0; resolution.bpp = 32; break;
		default: resolution.flags = 0; resolution.bpp = 8; break;
	}
	if(!(modecode & DEVID)) /* modecode normal */
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
				resolution.flags |= MODE_VESA_FLAG;
				break;
			case (VERTFLAG2+VESA_600+HORFLAG2+HORFLAG+VGA+COL80): /* 1600 * 1200 */
				resolution.width = 1600;
				resolution.height = 1200;
				break;
			default:
				init_resolution(validmode(Mode));
			 	break;
		}
	}
	else /* bits 11-3 used for devID */
	{
		const struct fb_videomode *db;
		long devID = GET_DEVID(modecode);
		if(devID < VESA_MODEDB_SIZE)
		{
			db = &vesa_modes[devID];
			resolution.flags |= MODE_VESA_FLAG;
		}
		else
		{
			devID -= VESA_MODEDB_SIZE;
			if(devID < total_modedb)
				db = &modedb[devID];
			else if(video_found == 1) /* Radeon */
			{
				struct radeonfb_info *rinfo = info_fvdi->par;
				devID -= total_modedb;
				if(devID < rinfo->mon1_dbsize)
					db = &rinfo->mon1_modedb[devID];
				else
				{
					init_resolution(Mode);
					return;
				}
			}
			else if(video_found == 2) /* Lynx */
			{
				struct smifb_info *smiinfo = info_fvdi->par;
				devID -= total_modedb;
				if(devID < smiinfo->mon1_dbsize)
					db = &smiinfo->mon1_modedb[devID];
				else
				{
					init_resolution(Mode);
					return;
				}
			}
			else
			{
				init_resolution(Mode);
				return;
			}
		}
		resolution.width = (short)db->xres;
		resolution.height = (short)db->yres;
		resolution.freq = (short)db->refresh;
	}
}

void vsetrgb(long index, long count, long *array)
{
	static int init_ok;
	unsigned red,green,blue;
	struct fb_info *info = info_fvdi;
	int i;
	for(i = index; i < (count + index); i++, array++)
	{
		if(video_found && (info->var.bits_per_pixel <= 8))
		{
			if(init_ok && (bios_colors[i] == *array))
				continue;
			bios_colors[i] = *array;
			red = (*array>>16) & 0xFF;
			green = (*array>>8) & 0xFF;
			blue = *array & 0xFF;
			info->fbops->fb_setcolreg((unsigned)i, red << 8, green << 8, blue << 8, 0, info);
		}
		else
			bios_colors[i] = *array;
	}
	if(!index && (count == 256) && video_found && (info->var.bits_per_pixel <= 8))
		init_ok = 1;
}

void vgetrgb(long index, long count, long *array)
{
	short i;
	for(i = index; i < (count + index); i++)
		*array++ = bios_colors[i];
}

unsigned long physbase(void)
{
	struct fb_info *info = info_fvdi;
	long physaddr;
	if(video_found == 1) /* Radeon */
	{
		struct radeonfb_info *rinfo = info->par;
		if(info->screen_mono != NULL)
			physaddr = (unsigned long)info->screen_mono;
		else
			physaddr = (unsigned long)info->screen_base + rinfo->fb_offset;
	}
	else if(video_found == 2) /* Lynx */
	{
		struct smifb_info *smiinfo = info->par;
		if(info->screen_mono != NULL)
			physaddr = (unsigned long)info->screen_mono;
		else
			physaddr = (unsigned long)info->screen_base + smiinfo->fb_offset;
	}
	else
		physaddr = (unsigned long)info->screen_base;
//	board_printf("physbase => %08X\r\n", physaddr);
	return(physaddr);
}

unsigned long logbase(void)
{
	struct fb_info *info = info_fvdi;
	if(video_found && (info->screen_mono == NULL))
		return(log_addr);
	return((long)*((char **)_v_bas_ad));
}

long getrez(void)
{

	long Mode;
	if(os_magic == 1)
		Mode = (long)modecode_magic & 0xFFFF;
	else
		Mode = (long)Modecode & 0xFFFF;
	if(!(Mode & DEVID)) /* modecode normal */
	{
		switch(Mode & (VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|VGA|COL80))
		{
			case (VERTFLAG+VGA):                      /* 320 * 240 */
			case 0:
				return(0);
			case (VGA+COL80):                         /* 640 * 480 */
			case (VERTFLAG+COL80):
				return(4);
			default:
				return(6);
		}
	}
	else /* bits 11-3 used for devID */
	{
		const struct fb_videomode *db = get_db_from_modecode(Mode);
		if(db == NULL)
			return(0);
		if((db->xres <= 320) && (db->yres <= 240))
			return(0);
		if((db->xres <= 640) && (db->yres <= 480))
			return(4);
		return(6);
	}
}

long vsetscreen(long logaddr, long physaddr, long rez, long modecode, long init_vdi)
{
	static unsigned short tab_16_col_ntc[16] = {
		0xFFDF,0xF800,0x07C0,0xFFC0,0x001F,0xF81F,0x07DF,0xB596,
		0x8410,0xA000,0x0500,0xA500,0x0014,0xA014,0x0514,0x0000 };
	static unsigned long tab_16_col_tc[16] = {
		0xFFFFFF,0xFF0000,0x00FF00,0xFFFF00,0x0000FF,0xFF00FF,0x00FFFF,0xB0B0B0,
		0x808080,0x8F0000,0x008F00,0x8F8F00,0x00008F,0x8F008F,0x008F8F,0x000000 };
	long y, color = 0, test = 0;
	struct fb_info *info = info_fvdi;
	struct fb_var_screeninfo var;
	int milan_mode = 0;
	short dup_handle = -1, log_handle = -1, save_debug = debug;
	long Mode;
	if(os_magic == 1)
		Mode = (long)modecode_magic & 0xFFFF;
	else
		Mode = (long)Modecode & 0xFFFF;
//	board_printf("vsetscreen logaddr %08X phyaddr %08X rez %04X modecode %04X (%04X)\r\n", logaddr, physaddr, rez, modecode, Mode);
	switch((short)rez)
	{
		case 0x4D49: /* 'MI' (Milan Vsetscreen) */
			milan_mode = 1;
		case 0x564E: /* 'VN' (Vsetscreen New) */
			switch((short)modecode)
			{
				case CMD_GETMODE:
					*((long *)physaddr) = Mode;
					return(0);
				case CMD_SETMODE:
					modecode = physaddr;
					rez = 3;
					logaddr = physaddr = 0;
#ifdef USE_RADEON_MEMORY
					if(lock_video)
						return(0);
#endif
					switch(modecode & NUMCOLS)
					{
						case BPS1:
							if(os_magic == 1)
								return(0);
							init_resolution(modecode);
							if((resolution.width > MAX_WIDTH_EMU_MONO) || (resolution.height > MAX_HEIGHT_EMU_MONO))
								return(0);
							break;
						case BPS8:
						case BPS16:
						case BPS32:
							init_resolution(modecode);
							break;
						default:
							return(0);
					}
					Mode = update_modecode(modecode);
					break;
				case CMD_GETINFO:
					{
						SCREENINFO *si = (SCREENINFO *)physaddr;
						if(si->devID)
							modecode = si->devID;
						else
							modecode = Mode;
						init_screen_info(si, modecode);
					}
					return(0);
				case CMD_ALLOCPAGE:
					if(video_found && (info->screen_mono == NULL))
					{
						long addr, addr_aligned, size;
						long wrap = info->var.xres_virtual * (info->var.bits_per_pixel >> 3);
						modecode = physaddr;
						if(second_screen)
						{
							if(logaddr != -1)
								*((long *)logaddr) = second_screen_aligned;
							return(0);
						}
						if(modecode == -1)
							size = info->var.yres_virtual * wrap;
						else
						{
							size = vgetsize(modecode & 0xFFFF);
							if(size <  (info->var.yres_virtual * wrap))
								size = info->var.yres_virtual * wrap;
						}
						addr_aligned = addr = offscreen_alloc(info, size + wrap);
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
					if(video_found && (info->screen_mono == NULL))
					{
						if((logaddr == -1) || (logaddr == second_screen_aligned))
							logaddr = second_screen;
						else
							logaddr = 0;
						if(logaddr)
						{
							offscreen_free(info, logaddr);
							if(logaddr == second_screen)
							{
								if(second_screen_aligned == (long)physbase())
								{
									log_addr = logaddr = physaddr = (long)info->screen_base;
									rez = -1; /* switch back to the first if second page active */
									init_vdi = 0;
									second_screen = second_screen_aligned = 0;
									break;
								}								
								else				
									second_screen = second_screen_aligned = 0;							
							}
						}
					}
					return(0);
				case CMD_FLIPPAGE:
					if(!video_found || !second_screen || (info->screen_mono != NULL))
						return(0);
					if(second_screen_aligned == (long)physbase())
						physaddr = (long)info->screen_base;
					else
						physaddr = second_screen_aligned;
					if(second_screen_aligned == log_addr)
						log_addr = logaddr = (long)info->screen_base;
					else
						log_addr = logaddr = second_screen_aligned;
					rez = -1;
					break;
				case CMD_ALLOCMEM:
					if(video_found && (info->screen_mono == NULL))
					{
						SCRMEMBLK *blk = (SCRMEMBLK *)physaddr;
						if(blk->blk_y)
							blk->blk_h=blk->blk_y;
						if(blk->blk_h)
						{	
							int bpp = info->var.bits_per_pixel >> 3;
							blk->blk_len = (long)(info->var.xres_virtual * bpp) * blk->blk_h;
							blk->blk_start = offscreen_alloc(info, blk->blk_len);
							if(blk->blk_start)
								blk->blk_status = BLK_OK;
							else
								blk->blk_status = BLK_ERR;
							blk->blk_w = (long)info->var.xres_virtual;
							blk->blk_wrap = blk->blk_w * (long)bpp;
							blk->blk_x = ((blk->blk_start - (long)info->screen_base) % (info->var.xres_virtual * bpp)) / bpp;
							blk->blk_y = (blk->blk_start - (long)info->screen_base) / (info->var.xres_virtual * bpp);
						}
					}
					else
					{
						SCRMEMBLK *blk = (SCRMEMBLK *)physaddr;
						blk->blk_status = BLK_ERR;
					}
					return(0);
				case CMD_FREEMEM:
					if(video_found && (info->screen_mono == NULL))
					{
						SCRMEMBLK *blk	= (SCRMEMBLK *)physaddr;
						offscreen_free(info, blk->blk_start);
						blk->blk_status = BLK_CLEARED;
					}
					return(0);
				case CMD_SETADR:
					if(video_found && (info->screen_mono == NULL))
					{
						if((logaddr >= (long)info->screen_base)
						 || ((logaddr - (long)info->screen_base) >= (info->var.xres_virtual * 8192 * (info->var.bits_per_pixel >> 3))))
							log_addr = logaddr;
						rez = -1;
						break;
					}
					return(0);
				case CMD_ENUMMODES:
					{
						long (*enumfunc)(SCREENINFO *inf, long flag) = (void *)physaddr;
						SCREENINFO si;
						long index, mode;
						si.size = sizeof(SCREENINFO);
						for(index = 0; index < 65536; index++)
						{
							mode = index;
							if(!video_found && (mode & VIRTUAL_SCREEN))
								continue;
							if(!(mode & DEVID)) /* modecode normal */
							{
								if(mode & STMODES)
									continue;
								if(!(mode & VGA))
									continue;
								mode &= (VIRTUAL_SCREEN|VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|OVERSCAN|PAL|VGA|COL80|NUMCOLS);
								if(mode == (Mode & (VIRTUAL_SCREEN|VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|OVERSCAN|PAL|VGA|COL80|NUMCOLS)))
									si.devID = 0;
								else
									si.devID = mode;
							}
							else /* bits 11-3 used for devID */
							{
								if(mode == Mode)
									si.devID = 0;
								else
									si.devID = mode;
							}							
						  init_screen_info(&si, mode);
						  si.devID = mode;
						  if(si.scrFlags == SCRINFO_OK)
						  {
								if(!call_enumfunc(enumfunc, &si, 1 /* ??? */)) /* for Pure C user */
									break;
							}
						}
					}
					if(milan_mode)
						return(0);
					return((long)info); /* trick for get sructure */
				case CMD_TESTMODE:
					if(milan_mode)
						return(0);
#ifdef USE_RADEON_MEMORY
					if(lock_video)
						return(0);
#endif
					modecode = physaddr;
					logaddr = physaddr = 0;
					rez = 3;
					init_vdi = 0;
					test = 1;
					switch(modecode & NUMCOLS)
					{
						case BPS1:
							if(os_magic == 1)
								return(0);
							init_resolution(modecode);
							if((resolution.width > MAX_WIDTH_EMU_MONO) || (resolution.height > MAX_HEIGHT_EMU_MONO))
								return(0);
							break;
						case BPS8:
						case BPS16:
						case BPS32:
							init_resolution(modecode);
							break;
						default:
							return(0);
					}
					Mode = update_modecode(modecode);
					break;
				case CMD_COPYPAGE:
					if(milan_mode)
						return(0);					
					if(video_found && second_screen	&& (info->screen_mono == NULL))
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
				case CMD_FILLMEM:
					if(milan_mode)
						return(0);
					if(video_found)
					{
						SCRFILLMEMBLK *blk = (SCRFILLMEMBLK *)physaddr;
						if(fill_screen(blk->blk_op, blk->blk_color, blk->blk_x, blk->blk_y, blk->blk_w, blk->blk_h))
							blk->blk_status = BLK_OK;
						else
							blk->blk_status = BLK_ERR;			
					}
					else
					{
						SCRFILLMEMBLK *blk = (SCRFILLMEMBLK *)physaddr;
						blk->blk_status = BLK_ERR;			
					}
					return(0);
				case CMD_COPYMEM:
					if(milan_mode)
						return(0);
					if(video_found)
					{
						SCRCOPYMEMBLK *blk = (SCRCOPYMEMBLK *)physaddr;
						if(copy_screen(blk->blk_op, blk->blk_src_x, blk->blk_src_y, blk->blk_dst_x, blk->blk_dst_y, blk->blk_w, blk->blk_h))
							blk->blk_status = BLK_OK;
						else
							blk->blk_status = BLK_ERR;				
					}
					else
					{
						SCRCOPYMEMBLK *blk = (SCRCOPYMEMBLK *)physaddr;
						blk->blk_status = BLK_ERR;			
					}
					return(0);
				case CMD_TEXTUREMEM:
					if(milan_mode)
						return(0);
					if(video_found && (info->screen_mono == NULL))
					{
						SCRTEXTUREMEMBLK *blk = (SCRTEXTUREMEMBLK *)physaddr;
#ifdef RADEON_RENDER
						if(display_composite_texture(blk->blk_op, (unsigned char *)blk->blk_src_tex, blk->blk_src_x, blk->blk_src_y, blk->blk_w_tex, blk->blk_h_tex, blk->blk_dst_x, blk->blk_dst_y, blk->blk_w, blk->blk_h))
							blk->blk_status = BLK_OK;
						else
#endif
							blk->blk_status = BLK_ERR;				
					}
					else
					{
						SCRTEXTUREMEMBLK *blk = (SCRTEXTUREMEMBLK *)physaddr;
						blk->blk_status = BLK_ERR;			
					}
					return(0);
				case CMD_GETVERSION:
					if(milan_mode)
						return(0);
					if(physaddr != -1)
						*((long *)physaddr) = XBIOS_SCREEN_VERSION;
					return(0);			
				case CMD_LINEMEM:
					if(milan_mode)
						return(0);
					if(video_found && (info->screen_mono == NULL))
					{
						SCRLINEMEMBLK *blk = (SCRLINEMEMBLK *)physaddr;
						if(line_screen(blk->blk_op, blk->blk_fgcolor, blk->blk_bgcolor, blk->blk_x1, blk->blk_y1, blk->blk_x2, blk->blk_y2, blk->blk_pattern))
							blk->blk_status = BLK_OK;
						else
							blk->blk_status = BLK_ERR;			
					}
					else
					{
						SCRLINEMEMBLK *blk = (SCRLINEMEMBLK *)physaddr;
						blk->blk_status = BLK_ERR;			
					}
					return(0);
				case CMD_CLIPMEM:
					if(milan_mode)
						return(0);
					if(video_found)
					{
						SCRCLIPMEMBLK *blk = (SCRCLIPMEMBLK *)physaddr;
						if(clip_screen(blk->blk_clip_on, blk->blk_x, blk->blk_y, blk->blk_w, blk->blk_h))
							blk->blk_status = BLK_OK;
						else
							blk->blk_status = BLK_ERR;			
					}
					else
					{
						SCRCLIPMEMBLK *blk = (SCRCLIPMEMBLK *)physaddr;
						blk->blk_status = BLK_ERR;			
					}
					return(0);
				case CMD_SYNCMEM:
					if(!milan_mode && video_found)
						info_fvdi->fbops->fb_sync(info_fvdi);
					return(0);
				case CMD_BLANK:
					if(!milan_mode)
					{
						if(video_found)
							info_fvdi->fbops->fb_blank(physaddr, info_fvdi);
					}
					return(0);
				case -1:
				default:
					return(0);
			}
			break;
#if 0 // actually the fVDI driver works only with packed pixels in 256 / 65K / 16M colors and VBL mono emulation
		case 0:	/* ST-LOW */
			if(!video_found)
			{
				resolution.width = 320;
				resolution.height = 200;
				resolution.bpp = 4;
				resolution.freq = 60;
				resolution.flags = 0;
				modecode = VERTFLAG|STMODES|PAL|VGA|BPS4;
				Mode = update_modecode(modecode);
				break;
			}
			return(Mode);
		case 1: /* ST-MED */
			if(!video_found)
			{
				resolution.width = 640;
				resolution.height = 200;
				resolution.bpp = 2;
				resolution.freq = 60;
				resolution.flags = 0;
				modecode = VERTFLAG|STMODES|PAL|VGA|COL80|BPS2;
				Mode = update_modecode(modecode);
				break;
			}
			return(Mode);
#endif
		case 2: /* ST-HIG */
			if(os_magic == 1)
				return(Mode);
#ifdef USE_RADEON_MEMORY
			if(lock_video)
				return(Mode);
#endif
			resolution.width = 640;
			resolution.height = 400;
			resolution.bpp = 1;
			resolution.freq = 60;
			resolution.flags = MODE_EMUL_MONO_FLAG;
			modecode = STMODES|PAL|VGA|COL80|BPS1;
			Mode = update_modecode(modecode);
			break;
		case 3:
#ifdef USE_RADEON_MEMORY
			if(lock_video)
			{
				if(init_vdi)
				{
					init_var_linea((long)video_found);
					init_screen();
				}
				return(0);
			}
#endif
			switch(modecode & NUMCOLS)
			{
				case BPS1:
					init_resolution(modecode);
					if((resolution.width > MAX_WIDTH_EMU_MONO) || (resolution.height > MAX_HEIGHT_EMU_MONO))
						return(Mode);
					break;
				case BPS8:
				case BPS16:
				case BPS32:
					init_resolution(modecode);
					break;
				default:
#if 0
					modecode = Mode;  /* previous modecode */
					init_resolution(modecode);
					break;
#else
					return(Mode);
#endif
			}
			Mode = update_modecode(modecode);
			break;
		default:
#if 0
			modecode = Mode; /* previous modecode */
			init_resolution(modecode);
			break;
#else
			return(Mode);
#endif
	}
	if(modecode & VIRTUAL_SCREEN)
		virtual=1;
	else
		virtual=0;
	if(((!logaddr && !physaddr) || ((logaddr == -1) && (physaddr == -1))) && (rez >= 0))
	{
		resolution.used = 1;
		if(test)
			debug = 0;
		if(!test && drive_ok && video_log)
		{
			dup_handle = Fdup(1); /* stdout */
			if(dup_handle >= 0)
			{
				log_handle = Fcreate("C:\\screen.log", 0);
				if(log_handle >= 0)
				{
					Fforce(1, log_handle); /* stdout */
					debug = 1;  /* force debug to file */
				}
			}
		}
		info->update_mono = 0; /* stop VBL redraw if monochrome emulation */
		info->fbops->fb_check_modes(info, &resolution);
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
//		rinfo->asleep = 0;
		print_screen(NULL, 0, 0, 0, 0, 0, 0, 0); /* flush characters */
    if(!fb_set_var(info, &var))
		{
			int i, red = 0, green = 0, blue = 0;
			switch(info->var.bits_per_pixel)
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
						info->fbops->fb_setcolreg((unsigned)i,red,green,blue,0,info);
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
						info->fbops->fb_setcolreg((unsigned)i,red,green,blue,0,info);
						green += 256;   /* 8 bits */
						red += 256;     /* 8 bits */
						blue += 256;    /* 8 bits */
					}
					break;
				default:
					vsetrgb(0, 256, (long *)0xE1106A); /* default TOS 4.04 palette */
					break;
			}
			if((info->var.xres != (unsigned long)resolution.width) || (info->var.yres != (unsigned long)resolution.height))
			{ /* fix modecode if the driver choice another screen */
				modecode = get_modecode_from_screeninfo(&info->var);
				init_resolution(modecode);
				Mode = update_modecode(modecode);
			}
			if(resolution.flags & MODE_EMUL_MONO_FLAG)
			{
				extern Driver *me;
				extern void *default_text;
//				extern void *default_line, *default_fill;
				extern void *line, *fill;
				Virtual *vwk = me->default_vwk;
				Workstation *wk = vwk->real_address;
//				wk->r.line = &default_line;
//				wk->r.fill = &default_fill;
				wk->r.line = &line;
				wk->r.fill = &fill;
				wk->r.fillpoly = NULL; 
				wk->r.text = &default_text;				
				info->screen_mono = (char *)Srealloc((info->var.xres_virtual * info->var.yres_virtual) >> 3);
				if(info->screen_mono != NULL)
					memset(info->screen_mono, 0, (info->var.xres_virtual * info->var.yres_virtual) >> 3);
			}
			else if(info->screen_mono != NULL)  /* VBL nono emulation to normal => update fVDI accel functions */
			{
					extern Driver *me;
					extern void *c_line, *c_text, *c_fill, *c_fillpoly;
					Virtual *vwk = me->default_vwk;
					Workstation *wk = vwk->real_address;
					info->update_mono = 0; /* stop VBL redraw */
					info->screen_mono = NULL;
					wk->r.line = &c_line;
					wk->r.fill = &c_fill;
					wk->r.fillpoly = &c_fillpoly; 
					wk->r.text = &c_text;
			}
			if(info->screen_mono != NULL)
				*((char **)_v_bas_ad) = info->screen_mono;
			else
			{
				*((char **)_v_bas_ad) = info->screen_base;
				log_addr = (long)info->screen_base;
			}
			if(init_vdi) /* Vsetscreen, Vsetmode not change linea variables */
			{
				offscreen_init(info);
				second_screen = second_screen_aligned = 0;
				init_var_linea((long)video_found);
				switch(info->var.bits_per_pixel)
				{
					case 16: color = (unsigned long)tab_16_col_ntc[15]; break;
					case 32: color = tab_16_col_tc[15]; break;
					default: color = 15; break;
				}
				clear_screen(color, 0, 0, info->var.xres_virtual, info->var.yres_virtual); /* black screen */
				init_screen(); /* it's possible than fVDI not clear latest lines (modulo 16) */				
			}
			else if(test)
			{
				if(info->screen_mono == NULL)
				{
					for(y = 0; y < info->var.yres_virtual; y += 16)
					{
						switch(info->var.bits_per_pixel)
						{
							case 16: color = (unsigned long)tab_16_col_ntc[(y >> 4) & 15]; break;
							case 32: color = tab_16_col_tc[(y >> 4) & 15]; break;
							default: color = (unsigned long)((y >> 4) & 15); break;
						}
						clear_screen(color, 0, y, info->var.xres_virtual, info->var.yres_virtual-y >= 16 ? 16 : info->var.yres_virtual - y);
					}
				}
				else /* VBL mono emulation */
				{
					unsigned char *buffer = (unsigned char *)info->screen_mono;
					int size  = (info->var.xres_virtual >> 3) << 4;
					for(y = 0; y < info->var.yres_virtual; y += 16)
					{
						memset(buffer, (y >> 4) & 1 ? -1 : 0, size);
						buffer += size;
					}
					info->update_mono = 1;
				}
			}
			Mode = update_modecode(modecode);		
		}
		if(log_handle >= 0)
			Fclose(log_handle);
		if(dup_handle >= 0)
			Fforce(1, dup_handle); /* stdout */
		debug = save_debug;
	}
	else
	{
		if(logaddr && (logaddr != -1) && (info->screen_mono != NULL))
			*((char **)_v_bas_ad) = (char *)logaddr;
		if(physaddr && (physaddr != -1))
		{
			if((video_found) && (info->screen_mono == NULL))
			{
				int bpp = info->var.bits_per_pixel >> 3;
				physaddr -= (long)info->screen_base;
				if((physaddr < 0)
				 || (physaddr >= (info->var.xres_virtual * 8192 * bpp)))
					return(Mode);
				memcpy(&var, &info->var, sizeof(struct fb_var_screeninfo));			
				var.xoffset = (physaddr % (info->var.xres_virtual * bpp)) / bpp;
				var.yoffset = physaddr / (info->var.xres_virtual * bpp);
				if(var.yoffset < 8192)
					fb_pan_display(info, &var);
			}
			else if((info->screen_mono != NULL) && (physaddr < *phystop)) /* VBL mono emulation */
				info->screen_mono = (char *)physaddr;
		}
	}
	return(Mode);
}

long vsetmode(long modecode)
{
	long Mode;
	if(os_magic == 1)
		Mode = (long)modecode_magic & 0xFFFF;
	else
		Mode = (long)Modecode & 0xFFFF;
//	board_printf("vsetmode modecode %04X (%04X)\r\n", modecode, Mode);
	if(modecode == -1)
		return(Mode);
	vsetscreen(0, 0 , 3, modecode & 0xFFFF, 0);
	return(Mode);
}

long montype(void)
{
	if(video_found == 1) /* Radeon */
	{
		struct radeonfb_info *rinfo = info_fvdi->par;
		switch(rinfo->mon1_type)
		{
			case MT_STV: return(1); /* S-Video out */
			case MT_CRT: return(2); /* VGA */
			case MT_CTV: return(3); /* TV / composite */
//			case MT_LCD: return(4);	/* LCD */
//			case MT_DFP: return(5); /* DVI */
			default: return(2);     /* VGA */
		}
	}
	else if(video_found == 2) /* Lynx */
	{
		struct smifb_info *smiinfo = info_fvdi->par;
		/* 0:none 1:LCD 2:CRT 3:CRT/LCD 4:TV 5:TV/LCD */
		switch(smiinfo->videoout)
		{
			case 2: return(2); /* VGA */
			case 4: return(3); /* TV / composite */
			case 1:
			case 3:
			case 5:
				return(4);	/* LCD */
			default: return(2);     /* VGA */
		}	
	}
	return(2);
}

long vgetsize(long modecode)
{
	long size = 0, Mode;
	struct fb_info *info = info_fvdi;
	if(os_magic == 1)
		Mode = (long)modecode_magic & 0xFFFF;
	else
		Mode = (long)Modecode & 0xFFFF;
	if((short)modecode == Mode)
	{
		if(info->screen_mono != NULL)
			return((info->var.xres_virtual * info->var.yres_virtual) >> 3);
		return(info->var.xres_virtual * info->var.yres_virtual * (info->var.bits_per_pixel >> 3));
	}
	if(!(modecode & DEVID)) /* modecode normal */
	{
		if(modecode & STMODES)
			return(32000);
		switch(modecode & (VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|OVERSCAN|VGA|COL80))
		{		
			case (VERTFLAG|VGA):                      /* 320 * 240 */
			case 0:
				size = 320 * 240;
				break;
			case (VGA+COL80):                         /* 640 * 480 */
			case (VERTFLAG|COL80):
				size = 640 * 480;
				break;
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
		}
	}
	else /* bits 11-3 used for devID */
	{
		const struct fb_videomode *db = get_db_from_modecode(modecode);
		if(db == NULL)
			return(0);
		size = db->xres * db->yres;
	}
	switch(modecode & NUMCOLS)
	{
		case BPS1: size >>= 3; break;
		case BPS8: break;
		case BPS16: size <<= 1; break;
		case BPS32: size <<= 2; break;
		default: break;
	}
	if(modecode & VIRTUAL_SCREEN)
		size <<= 2;
	return(size);
}

long find_best_mode(long modecode)
{
	long i = 0, index = -1;
	switch(video_found)
	{
		case 1: /* Radeon */
			{
				struct radeonfb_info *rinfo = info_fvdi->par;
				const struct fb_videomode *db;
				while(i < rinfo->mon1_dbsize)
				{
					db = &rinfo->mon1_modedb[i];
					if(db->flag & FB_MODE_IS_FIRST)
					{
						modecode = SET_DEVID(i + VESA_MODEDB_SIZE + total_modedb);
						return(modecode);
					}
					i++;
				}
				i = 0;
				while(i < rinfo->mon1_dbsize)
				{
					db = &rinfo->mon1_modedb[i];
					if(db->flag & FB_MODE_IS_STANDARD)
						index = i;
					i++;
				}
			}
			break;
		case 2: /* Lynx */
			{
				struct radeonfb_info *smiinfo = info_fvdi->par;
				const struct fb_videomode *db;
				while(i < smiinfo->mon1_dbsize)
				{
					db = &smiinfo->mon1_modedb[i];
					if(db->flag & FB_MODE_IS_FIRST)
					{
						modecode = SET_DEVID(i + VESA_MODEDB_SIZE + total_modedb);
						return(modecode);
					}
					i++;
				}
				i = 0;
				while(i < smiinfo->mon1_dbsize)
				{
					db = &smiinfo->mon1_modedb[i];
					if(db->flag & FB_MODE_IS_STANDARD)
						index = i;
					i++;
				}
			}
			break;
	}
	if(index >= 0)
		modecode = SET_DEVID(index + VESA_MODEDB_SIZE + total_modedb); /* last standard mode */
	return(modecode);
}

long validmode(long modecode)
{
	long Mode;
	if(os_magic == 1)
		Mode = (long)modecode_magic & 0xFFFF;
	else
		Mode = (long)Modecode & 0xFFFF;
//	board_printf("validmode modecode %04X fix %d\r\n", modecode, fix_modecode);
	if((unsigned short)modecode != 0xFFFF)
	{
		if((os_magic != 1) && ((modecode & NUMCOLS) == BPS1)) /* VBL mono emulation */
			modecode &= ~VIRTUAL_SCREEN; /* limit size */
		else
		if(((modecode & NUMCOLS) < BPS8) || ((modecode & NUMCOLS) > BPS32))
		{
			modecode &= ~NUMCOLS;
			modecode = find_best_mode(modecode) | BPS16;
		}
		if(!(modecode & DEVID)) /* modecode normal */
		{
			modecode |= (PAL|VGA);
			if(modecode & STMODES)
			{
				modecode &= (VERTFLAG|STMODES|OVERSCAN|COL80);
				modecode |= BPS16;
			}
			else if(fix_modecode < 0)
			{
				modecode &= (VERTFLAG|PAL|VGA|COL80|NUMCOLS);
				modecode |= (Mode & (VIRTUAL_SCREEN|VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG));
			}
			if((modecode & VGA) && !(modecode & COL80))
				modecode |= VERTFLAG;
		}
		else /* bits 11-3 used for devID */
		{
			if(fix_modecode < 0)
			{
			 	modecode &= NUMCOLS;
			 	modecode |= (Mode & ~NUMCOLS);
			}
			if(video_found == 1) /* Radeon */
			{
				struct radeonfb_info *rinfo = info_fvdi->par;
				if(GET_DEVID(modecode) >= (VESA_MODEDB_SIZE + total_modedb + rinfo->mon1_dbsize))
				{
					modecode &= NUMCOLS;
					modecode |= (PAL|VGA|COL80);
				}
			}
			else if(video_found == 2) /* Lynx */
			{
				struct smifb_info *smiinfo = info_fvdi->par;
				if(GET_DEVID(modecode) >= (VESA_MODEDB_SIZE + total_modedb + smiinfo->mon1_dbsize))
				{
					modecode &= NUMCOLS;
					modecode |= (PAL|VGA|COL80);
				}
			}
			else
			{
				if(GET_DEVID(modecode) >= (VESA_MODEDB_SIZE + total_modedb))
				{
					modecode &= NUMCOLS;
					modecode |= (PAL|VGA|COL80);
				}		
			}
		}
	}
	if(fix_modecode != 1)
		fix_modecode = -1;
//	board_printf(" => modecode %04X\r\n", modecode);
	return(modecode);
}

long wait_vbl(void)
{
	if(video_found && (info_fvdi->fbops->WaitVbl != NULL))
	{
		info_fvdi->fbops->WaitVbl(info_fvdi);
		return(1);
	}
	return(0);
}

long vmalloc(long mode, long value)
{
	if(video_found)
	{
		switch(mode)
		{
			case 0:
				if(value)
					return(offscreen_alloc(info_fvdi, value));
				break;
			case 1:
				return(offscreen_free(info_fvdi, value));
			case 2:
				if(value > 0)
					info_fvdi = (struct fb_info *)value;
				offscreen_init(info_fvdi);
				return(0);
				break;
		}
	}
	return(-1);
}

long InitVideo(void) /* test for Video input */
{
#if 0 /* todo */
	if(video_found == 1) /* Radeon */
	{
		struct radeonfb_info *rinfo = info_vdi->par;
		RADEONInitVideo(rinfo);
		Cconin();	
		RADEONPutVideo(rinfo, 0, 0, 720, 576, 0, 0, 640, 512);
		Cconin();
		RADEONStopVideo(rinfo, 1);	
		Cconin();
		RADEONShutdownVideo(rinfo);
		Cconin();	
	}
#endif
	return(0);
}


