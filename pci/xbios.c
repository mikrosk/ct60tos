/* TOS 4.04 Xbios calls for the CT60/CTPCI boards
 * Didier Mequignon 2005, e-mail: aniplay@wanadoo.fr
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
 * along with ARAnyM; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
 
#include <mint/osbind.h>
#include <mint/falcon.h>
#include <sysvars.h>
#include "radeon/fb.h"
#include "radeon/radeonfb.h"

/* modecode extended flags */
#define HORFLAG         0x200 /* double width */
#define HORFLAG2        0x400 /* width increased */
#define VESA_600        0x800 /* SVGA 600 lines */
#define VESA_768       0x1000 /* SVGA 768 lines */
#define VERTFLAG2      0x2000 /* double height */
#define VIRTUAL_SCREEN 0x8000 /* width * 2 and height * 2, 2048 x 2048 max */
                                    
extern void init_var_linea(void);
extern void cursor_home(void);

/* global */
extern struct radeonfb_info *rinfo_fvdi;
extern struct mode_option resolution;
extern short virtual;
short Modecode;
static long bios_colors[256]; 

/* some XBIOS functions for the radeon driver */

void vsetrgb(short index, short count, long *array)
{
	short i;
	unsigned red,green,blue;
	struct fb_info *info;
	info=rinfo_fvdi->info;
	for(i=0;i<count;i++)
	{
		bios_colors[count+i]=*array;
		if(rinfo_fvdi->bpp <= 8)
		{
			red = (*array>>16) & 0xFF;
			green = (*array>>8) & 0xFF;
			blue = *array & 0xFF;
			radeonfb_setcolreg((unsigned)(index+i),red,green,blue,0,info);
		}
		array++;
	}
}

void vgetrgb(short index, short count, long *array)
{
	short i;
	for(i=0;i<count;i++)
		*array++ = bios_colors[count+i];
}

long physbase(void)
{
	struct fb_info *info;
	info=rinfo_fvdi->info;
	return((long)info->screen_base + (long)rinfo_fvdi->fb_offset);
}

void vsetscreen(long logadr, long physadr, short rez, short modecode)
{
	struct fb_info *info;
	struct radeonfb_info *rinfo;
	struct fb_var_screeninfo var;
	info=rinfo_fvdi->info;
	rinfo=rinfo_fvdi;
	if(modecode & VIRTUAL_SCREEN)
	{
		virtual=1;
		modecode &= ~VIRTUAL_SCREEN;
	}
	else
		virtual=0;
	switch(rez)
	{
		case 0:	
			resolution.width=320;
			resolution.height=200;
			resolution.bpp=8;
			resolution.freq=70;
			if(Modecode & VGA)
				modecode = VERTFLAG|STMODES|VGA|BPS4;
			else
				modecode = STMODES|BPS4;
			break;
		case 3:
			if(((modecode & NUMCOLS) != BPS8) && ((modecode & NUMCOLS) != BPS16))
				return;
			if((modecode & NUMCOLS) == BPS8)
				resolution.bpp=8;
			else
				resolution.bpp=16;
			switch(modecode & (VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|STMODES|OVERSCAN|VGA|COL80))
			{
				case (VERTFLAG+VGA):                      /* 320 * 240 */
				case 0:
					resolution.width=320;
					resolution.height=240;
					resolution.freq=60;
					break;
				case (VGA+COL80):                         /* 640 * 480 */
				case (VERTFLAG+COL80):
					resolution.width=640;
					resolution.height=480;
					resolution.freq=60;
					break;
				case (VESA_600+HORFLAG2+VGA+COL80):       /* 800 * 600 */
					resolution.width=800;
					resolution.height=600;
					resolution.freq=60;
					break;
				case (VESA_768+HORFLAG2+VGA+COL80):       /* 1024 * 768 */
					resolution.width=1024;
					resolution.height=768;
					resolution.freq=60;
					break;
				case (VERTFLAG2+HORFLAG+VGA+COL80):       /* 1280 * 960 */
					resolution.width=1280;
					resolution.height=960;
					resolution.freq=60;
					break;
				case (VERTFLAG2+VESA_600+HORFLAG2+HORFLAG+VGA+COL80): /* 1600 * 1200 */
					resolution.width=1600;
					resolution.height=1200;
					resolution.freq=60;
					break;
				default: return;
			}
			Modecode=modecode;
			break;
		default:
			return;
	}
	if(logadr==0 && physadr==0)
	{
		resolution.used=1;
		radeon_check_modes(rinfo_fvdi,&resolution);
		access->funcs.copymem(&info->var,&var,sizeof(struct fb_var_screeninfo));
		if(virtual)
		{
			var.xres_virtual = var.xres*2;
			var.yres_virtual = var.xres*2;
			if(var.xres_virtual > 2048)
				var.xres_virtual = 2048;
			if(var.yres_virtual > 2048)
				var.yres_virtual = 2048;
		}
		if(fb_set_var(info,&var)==0)
		{
			*((char **)_v_bas_ad)=info->screen_base;
			init_var_linea();
			cursor_home();
			vsetrgb(0,256,(long *)0xE1106A); /* default TOS 4.04 palette */
			Modecode=modecode;
		}
	}
	else
	{
		if(logadr)
				*((char **)_v_bas_ad)=(char *)logadr;
		if(physadr)
		{
			physadr -= (long)info->screen_base;
			if(virtual)
			{
				if(physadr < 0
				 || physadr >= (long)info->screen_size - (info->var.xres * info->var.yres * (info->var.bits_per_pixel / 8)))
					return;
				access->funcs.copymem(&info->var,&var,sizeof(struct fb_var_screeninfo));			
				var.xoffset = physadr % (info->var.xres_virtual * info->var.bits_per_pixel);
				var.yoffset = physadr / (info->var.xres_virtual * info->var.bits_per_pixel);
				fb_pan_display(info,&var);
			}
			else
			{
				if(physadr < 0
				 || physadr >= (long)rinfo->mapped_vram - (info->var.xres * info->var.yres * (info->var.bits_per_pixel / 8)))
					return;
				radeon_fifo_wait(2);
				rinfo->fb_offset =  physadr & ~7;
				OUTREG(CRTC_OFFSET, rinfo->fb_offset);
			}
		}
	}
}

short vsetmode(short modecode)
{
	if(modecode==-1)
		return(Modecode);
	vsetscreen(0,0,3,modecode);
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

long vgetsize(short modecode)
{
	long size=0;
	struct fb_info *info;
	info=rinfo_fvdi->info;
	if(modecode==Modecode)
		return(info->var.xres_virtual * info->var.yres_virtual * (info->var.bits_per_pixel / 8));
	if(modecode & STMODES)
	{
		switch(modecode & NUMCOLS)
		{
			case BPS4: return(320*200);
			default: return(640*400);
		}
	}	
	switch(modecode & (VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|OVERSCAN|VGA|COL80))
	{
		case (VERTFLAG+VGA):                      /* 320 * 240 */
		case 0:
			size=320*240;
			break;
		case (VGA+COL80):                         /* 640 * 480 */
		case (VERTFLAG+COL80):
			size=640*480;
			break;
		case (VESA_600+HORFLAG2+VGA+COL80):       /* 800 * 600 */
			size=800*600;
			break;
		case (VESA_768+HORFLAG2+VGA+COL80):       /* 1024 * 768 */
			size=1024*768;
			break;
		case (VERTFLAG2+HORFLAG+VGA+COL80):       /* 1280 x 960 */
			size=1280*960;
			break;
		case (VERTFLAG2+VESA_600+HORFLAG2+HORFLAG+VGA+COL80): /* 1600 * 1200 */
		default:
			size=1600*1200;
			break;
	}
	if((modecode & NUMCOLS) == BPS16)
		size<<=1;
	if(modecode & VIRTUAL_SCREEN)
		size<<=2;
	return(size);
}
