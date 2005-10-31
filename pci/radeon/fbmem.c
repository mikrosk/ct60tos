/*
 *  fbmem.c
 *
 *  Copyright (C) 1994 Martin Schaller
 *
 *	2001 - Documented with DocBook
 *	- Brad Douglas <brad@neruo.com>
 *
 * This file is subject to the terms and conditions of the GNU General Public
 * License.  See the file COPYING in the main directory of this archive
 * for more details.
 */
 
#include <mint/errno.h>
#include <mint/osbind.h>
#include "fb.h"
#include "radeonfb.h"

extern int radeonfb_set_par(struct fb_info *info);
extern int radeonfb_ioctl(unsigned int cmd, unsigned long arg, struct fb_info *info);
extern int radeonfb_check_var(struct fb_var_screeninfo *var, struct fb_info *info);
extern int radeonfb_pan_display(struct fb_var_screeninfo *var, struct fb_info *info);
extern int radeonfb_blank(int blank, struct fb_info *info);

extern struct radeonfb_info *rinfo_fvdi;

long mem_cmp(char *p1, char *p2, long size)
{
	while(size--)
	{
		if(*p1++ != *p2++)
			return(1);
	}
	return(0);
}

void mem_set(char *p, char fill, long size)
{
	while(size--)
		*p++ = fill;
}

    /*
     *  Frame buffer device initialization and setup routines
     */

#define FBPIXMAPSIZE	(1024 * 8)

int fb_pan_display(struct fb_info *info, struct fb_var_screeninfo *var)
{
	int xoffset = var->xoffset;
	int yoffset = var->yoffset;
	int err;
	if(xoffset < 0 || yoffset < 0
	 || xoffset + info->var.xres > info->var.xres_virtual)
		return -EINVAL;
	if((err = radeonfb_pan_display(var, info)))
		return err;
	info->var.xoffset = var->xoffset;
	info->var.yoffset = var->yoffset;
	if(var->vmode & FB_VMODE_YWRAP)
		info->var.vmode |= FB_VMODE_YWRAP;
	else
		info->var.vmode &= ~FB_VMODE_YWRAP;
	return 0;
}

int fb_set_var(struct fb_info *info, struct fb_var_screeninfo *var)
{
	int err;
	if(var->activate & FB_ACTIVATE_INV_MODE)
		/* return 1 if equal */
		return(!mem_cmp((char *)&info->var, (char *)var, sizeof(struct fb_var_screeninfo)));
	if((var->activate & FB_ACTIVATE_FORCE)
	 || mem_cmp((char *)&info->var, (char *)var, sizeof(struct fb_var_screeninfo)))
	{
		if((err = radeonfb_check_var(var, info)))
			return err;
		if((var->activate & FB_ACTIVATE_MASK) == FB_ACTIVATE_NOW)
		{
			access->funcs.copymem(var, &info->var, sizeof(struct fb_var_screeninfo));
			radeonfb_set_par(info);
			fb_pan_display(info, &info->var);
		}
	}
	return 0;
}

int fb_blank(struct fb_info *info, int blank)
{	
 	if(blank > FB_BLANK_POWERDOWN)
 		blank = FB_BLANK_POWERDOWN;
	return(radeonfb_blank(blank, info));
}

int fb_ioctl(unsigned int cmd, unsigned long arg)
{
	struct fb_info *info;
	struct fb_var_screeninfo var;
	struct fb_fix_screeninfo fix;
	void *argp = (void *)arg;
	int i;
	info=rinfo_fvdi->info;
	switch(cmd)
	{
		case FBIOGET_VSCREENINFO:
			access->funcs.copymem(&info->var, argp, sizeof(var));
			return 0;
		case FBIOPUT_VSCREENINFO:
			access->funcs.copymem(argp, &var, sizeof(var));
			i = fb_set_var(info, &var);
			if(i)
				return i;
			access->funcs.copymem(&var, argp, sizeof(var));
			return 0;
		case FBIOGET_FSCREENINFO:
			access->funcs.copymem(&info->fix, argp, sizeof(fix));
			return 0;
		case FBIOPAN_DISPLAY:
			access->funcs.copymem(argp, &var, sizeof(var));
			i = fb_pan_display(info, &var);
			if(i)
				return i;
			access->funcs.copymem(&var, argp, sizeof(var));
			return 0;
		case FBIOBLANK:
			i = fb_blank(info, arg);
			return i;
		default:
			return(radeonfb_ioctl(cmd, arg, info));
	}
}

/**
 * framebuffer_alloc - creates a new frame buffer info structure
 *
 * @size: size of driver private data, can be zero
 * @dev: pointer to the device for this fb, this can be NULL
 *
 * Creates a new frame buffer info structure. Also reserves @size bytes
 * for driver private data (info->par). info->par (if any) will be
 * aligned to sizeof(long).
 *
 * Returns the new structure, or NULL if an error occured.
 *
 */
struct fb_info *framebuffer_alloc(unsigned long size)
{
#define BYTES_PER_LONG (32/8)
#define PADDING (BYTES_PER_LONG - (sizeof(struct fb_info) % BYTES_PER_LONG))
	int fb_info_size = sizeof(struct fb_info);
	struct fb_info *info;
	char *p;
	if(size)
		fb_info_size += PADDING;
	p = access->funcs.malloc(fb_info_size + size, 3);
	if(!p)
		return NULL;
	mem_set(p, 0, fb_info_size + size);
	info = (struct fb_info *) p;
	if(size)
		info->par = p + fb_info_size;
	return info;
#undef PADDING
#undef BYTES_PER_LONG
}

/**
 * framebuffer_release - marks the structure available for freeing
 *
 * @info: frame buffer info structure
 *
 * Drop the reference count of the class_device embedded in the
 * framebuffer info structure.
 *
 */
void framebuffer_release(struct fb_info *info)
{
	access->funcs.free(info);
}

