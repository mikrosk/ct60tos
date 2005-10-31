#include "fb.h"
#include "radeonfb.h"

static const unsigned char vdi_colours[] = { 0,2,3,6,4,7,5,8,9,10,11,14,12,15,13,255 };
static const unsigned char tos_colours[] = { 0,255,1,2,4,6,3,5,7,8,9,10,12,14,11,13 };
#define toTosColors( color ) \
    ( (color)<(sizeof(tos_colours)/sizeof(*tos_colours)) ? tos_colours[color] : ((color) == 255 ? 15 : (color)) )
#define toVdiColors( color ) \
    ( (color)<(sizeof(vdi_colours)/sizeof(*vdi_colours)) ? vdi_colours[color] : color)

/* from common.c */
extern Driver *me;

/* from clip.S */
extern long CDECL clip_line(Virtual *vwk, long *x1, long *y1, long *x2, long *y2);

/* from spec.c */
extern void CDECL (*get_colours_r)(Virtual *vwk, long colour, long *foreground, long *background);
extern struct radeonfb_info *rinfo_fvdi;

/* from radeon_base.c */
extern short virtual;

static MFDB *simplify(Virtual* vwk, MFDB* mfdb)
{
   vwk = (Virtual *)((long)vwk & ~1);
   if(!mfdb)
      return 0;
   else if(!mfdb->address)
      return 0;
   else if(mfdb->address == vwk->real_address->screen.mfdb.address)
      return 0;
   else
      return mfdb;
}

long CDECL c_read_pixel(Virtual *vwk, MFDB *mfdb, long x, long y)
{
	MFDB *src;
	struct fb_info *info;
	unsigned long color = 0;
	unsigned long row_address;
	src = simplify(vwk, mfdb);
	if(!src)
	{
		info=rinfo_fvdi->info;
#ifndef TEST_NOPCI
		radeonfb_sync(info);
#endif
		row_address = (unsigned long)info->screen_base;
		row_address += (info->var.xres_virtual * 2 * info->var.bits_per_pixel * y);
	}
	else
	{
		row_address = (unsigned long)src->address;
		row_address += ((unsigned long)src->width * 2 * (unsigned long)src->bitplanes * y);
	}
	switch(src->bitplanes)
	{
		case 8:
			color = (unsigned long)*((unsigned char *)(row_address + x));
			break;
		case 16:
			color = (unsigned long)*((unsigned short *)(row_address + x * 2));
			break;
		case 24:
			color = (unsigned long)(*((unsigned long *)(row_address + x * 4))) >> 8;
			break;
		case 32:
			color = (unsigned long)*((unsigned long *)(row_address + x * 4));
			break;
		default:
			color = 0xffffffff;
			break;
	}
	return((long)color);
}

long CDECL c_write_pixel(Virtual *vwk, MFDB *mfdb, long x, long y, long color)
{
#ifndef TEST_NOPCI
	MFDB *src;
	unsigned long row_address;
	struct fb_info *info;
	info=rinfo_fvdi->info;
	src = simplify(vwk, mfdb);
	if(!src)
	{
		RADEONSetupForSolidFillMMIO(rinfo_fvdi,(int)color,0,0xffffffff);
		RADEONSubsequentSolidHorVertLineMMIO(rinfo_fvdi,(int)x,(int)y,1,DEGREES_0);
		return(1);
	}
	row_address = (unsigned long)src->address;
	row_address += ((unsigned long)src->width * 2 * (unsigned long)src->bitplanes * y);
	switch(src->bitplanes)
	{
		case 8:
			*((unsigned char *)(row_address + x))=(unsigned char)color;
			break;
		case 16:
			*((unsigned short *)(row_address + x * 2))=(unsigned short)color;
			break;
		case 24:
			color = (unsigned long)(*((unsigned long *)(row_address + x * 4))) >> 8;
			break;
		case 32:
			*((unsigned long *)(row_address + x * 4))=(unsigned long)color;
			break;
		default:
			break;
	}
#endif
	return(1);
}

long CDECL c_mouse_draw(Workstation *wk, long x, long y, Mouse *mouse)
{
#ifndef TEST_NOPCI
	long foreground,background;
	struct fb_info *info;
	info=rinfo_fvdi->info;
	switch((long)mouse)
	{
		case 0: /* move shown */
			RADEONSetCursorPosition(rinfo_fvdi,(int)x,(int)y);
			RADEONShowCursor(rinfo_fvdi);
			break;
		case 1: /* move hidden */
			RADEONSetCursorPosition(rinfo_fvdi,(int)x,(int)y);
			RADEONHideCursor(rinfo_fvdi);
			break;
		case 2: /* hide */
			RADEONHideCursor(rinfo_fvdi);
			break;
		case 3: /* show */
			RADEONShowCursor(rinfo_fvdi);
			break;
		default:
  		get_colours_r(me->default_vwk, *(long*)&mouse->colour, &foreground, &background);
			RADEONLoadCursorImage(rinfo_fvdi,(unsigned short *)&mouse->mask,(unsigned short *)&mouse->data);
			RADEONSetCursorColors(rinfo_fvdi,(int)background,(int)foreground);
			RADEONSetCursorPosition(rinfo_fvdi,(int)x,(int)y);
			break;
   }
#endif
   return(1);
}

long CDECL c_expand_area(Virtual *vwk, MFDB *src, long src_x, long src_y,
           MFDB *dst, long dst_x, long dst_y, long w, long h, long operation, long colour)
{
#ifndef TEST_NOPCI
	struct fb_info *info;
	info=rinfo_fvdi->info;
	radeonfb_sync(info);
#endif
	return(0);
}

long CDECL c_fill_area(Virtual *vwk, long x, long y, long w, long h, short *pattern,
           long colour, long mode, long interior_style)
{
#ifndef TEST_NOPCI
	int rop;
  long foreground;
  long background;
	struct fb_info *info;
	info=rinfo_fvdi->info;
  get_colours_r((Virtual *)((long)vwk & ~1), colour, &foreground, &background);
	switch(mode)
	{
		case 1:	rop=0; break; /* AND replace */
		case 2: rop=7; break; /* transparent */
		case 3: rop=6; break; /* XOR */
		case 4: rop=11; break; /* reverse transparent */
		default: rop=0; break;
#if 0
    { ROP3_ZERO, ROP3_ZERO }, /* GXclear        */
    { ROP3_DSa,  ROP3_DPa  }, /* Gxand          */
    { ROP3_SDna, ROP3_PDna }, /* GXandReverse   */
    { ROP3_S,    ROP3_P    }, /* GXcopy         */
    { ROP3_DSna, ROP3_DPna }, /* GXandInverted  */
    { ROP3_D,    ROP3_D    }, /* GXnoop         */
    { ROP3_DSx,  ROP3_DPx  }, /* GXxor          */
    { ROP3_DSo,  ROP3_DPo  }, /* GXor           */
    { ROP3_DSon, ROP3_DPon }, /* GXnor          */
    { ROP3_DSxn, ROP3_PDxn }, /* GXequiv        */
    { ROP3_Dn,   ROP3_Dn   }, /* GXinvert       */
    { ROP3_SDno, ROP3_PDno }, /* GXorReverse    */
    { ROP3_Sn,   ROP3_Pn   }, /* GXcopyInverted */
    { ROP3_DSno, ROP3_DPno }, /* GXorInverted   */
    { ROP3_DSan, ROP3_DPan }, /* GXnand         */
    { ROP3_ONE,  ROP3_ONE  }  /* GXset          */
#endif		
	}
	switch(interior_style>>=16)
	{
		case 0:	foreground = background;
		case 1:
			RADEONSetupForSolidFillMMIO(rinfo_fvdi,(int)foreground,rop,0xffffffff);
			RADEONSubsequentSolidFillRectMMIO(rinfo_fvdi,(int)x,(int)y,(int)w,(int)h);
			break;
		default:
			RADEONSetupForMono16x16PatternFillMMIO(rinfo_fvdi,(unsigned short *)pattern,(int)foreground,(int)background,rop,0xffffffff);
			RADEONSubsequentMono16x16PatternFillRectMMIO(rinfo_fvdi,(int)x,(int)y,(int)w,(int)h);
	}
#endif
	return(1);
}

long CDECL c_blit_area(Virtual *vwk, MFDB *src, long src_x, long src_y, MFDB *dst,
           long dst_x, long dst_y, long w, long h, long operation)
{
#ifndef TEST_NOPCI
	struct fb_info *info;
	int xdir, ydir;
	info=rinfo_fvdi->info;
	src = simplify(vwk, src);
	dst = simplify(vwk, dst);
	if(!src && !dst)
	{
		xdir = (int)(src_x - dst_x);
		ydir = (int)(src_y - dst_y);
		RADEONSetupForScreenToScreenCopyMMIO(rinfo_fvdi,xdir,ydir,(int)operation,0xffffffff,-1);
		RADEONSubsequentScreenToScreenCopyMMIO(rinfo_fvdi,(int)src_x,(int)src_y,(int)dst_x,(int)dst_y,(int)w,(int)h);   
		return(1);
	}
	else if(src && !dst)
	{
		unsigned char *src_buf = (unsigned char *)src->address;
		int srcwidth = src->wdwidth<<1;	/* bytes */
    int skipleft, Bpp = src->bitplanes >> 3; 
		src_buf += (Bpp * ((srcwidth * src_y) + src_x));
    if((skipleft = (long)src_buf & 0x03L))
    {
			if(Bpp == 3)
				skipleft = 4 - skipleft;
			else
				skipleft /= Bpp;
			src_x -= skipleft;	     
			w += skipleft;
			if(Bpp == 3)
				src_buf -= 3 * skipleft;  
			else
				src_buf = (unsigned char*)((long)src_buf & ~0x03L);     
		}
		RADEONSetupForScanlineImageWriteMMIO(rinfo_fvdi,(int)operation,0xffffffff,-1,(int)src->bitplanes);
		RADEONSubsequentScanlineImageWriteRectMMIO(rinfo_fvdi,(int)dst_x,(int)dst_y,(int)w,(int)h,skipleft);
		while(h--)
		{
			RADEONSubsequentScanlineMMIO(rinfo_fvdi, (unsigned long*)src_buf);
			src_buf += srcwidth;
		}
		return(1);
	}
	radeonfb_sync(info);
#endif
	return(0);
}

long CDECL c_line_draw(Virtual *vwk, long x1, long y1, long x2, long y2,
           long pattern, long colour, long mode)
{
#ifndef TEST_NOPCI
	int rop;
	long foreground;
	long background;
	struct fb_info *info;
	info=rinfo_fvdi->info;
	if(!clip_line(vwk, &x1, &y1, &x2, &y2))
		return(1);
	get_colours_r((Virtual *)((long)vwk & ~1), colour, &foreground, &background);
	switch(mode)
	{
		case 1:	rop=0; break; /* AND replace */
		case 2: rop=7; break; /* transparent */
		case 3: rop=6; break; /* XOR */
		case 4: rop=11; break; /* reverse transparent */
		default: rop=0; break;
#if 0
    { ROP3_ZERO, ROP3_ZERO }, /* GXclear        */
    { ROP3_DSa,  ROP3_DPa  }, /* Gxand          */
    { ROP3_SDna, ROP3_PDna }, /* GXandReverse   */
    { ROP3_S,    ROP3_P    }, /* GXcopy         */
    { ROP3_DSna, ROP3_DPna }, /* GXandInverted  */
    { ROP3_D,    ROP3_D    }, /* GXnoop         */
    { ROP3_DSx,  ROP3_DPx  }, /* GXxor          */
    { ROP3_DSo,  ROP3_DPo  }, /* GXor           */
    { ROP3_DSon, ROP3_DPon }, /* GXnor          */
    { ROP3_DSxn, ROP3_PDxn }, /* GXequiv        */
    { ROP3_Dn,   ROP3_Dn   }, /* GXinvert       */
    { ROP3_SDno, ROP3_PDno }, /* GXorReverse    */
    { ROP3_Sn,   ROP3_Pn   }, /* GXcopyInverted */
    { ROP3_DSno, ROP3_DPno }, /* GXorInverted   */
    { ROP3_DSan, ROP3_DPan }, /* GXnand         */
    { ROP3_ONE,  ROP3_ONE  }  /* GXset          */
#endif		
	}
	if((pattern & 0xffff) == 0xffff)
	{
		RADEONSetupForSolidLineMMIO(rinfo_fvdi,(int)foreground,rop,0xffffff);
		RADEONSubsequentSolidTwoPointLineMMIO(rinfo_fvdi,(int)x1,(int)y1,(int)x2,(int)y2,OMIT_LAST);  
	}
	else
	{
		pattern<<=16;
		RADEONSetupForDashedLineMMIO(rinfo_fvdi,(int)foreground,(int)background,rop,0xffffffff,16,(unsigned char *)&pattern);
		RADEONSubsequentDashedTwoPointLineMMIO(rinfo_fvdi,(int)x1,(int)y1,(int)x2,(int)y2,OMIT_LAST,0);  
	}
#endif
	return(1);
}

long CDECL c_fill_polygon(Virtual *vwk, short points[], long n,
           short index[], long moves, short *pattern,
           long colour, long mode, long interior_style)
{
#ifndef TEST_NOPCI
	struct fb_info *info;
	info=rinfo_fvdi->info;
	radeonfb_sync(info);
#endif
	return(0);		
}

long CDECL c_text_area(Virtual *vwk, short *text, long length, long dst_x, long dst_y, short *offsets)
{
#ifndef TEST_NOPCI
	struct fb_info *info;
	info=rinfo_fvdi->info;
	radeonfb_sync(info);
#endif
	return(0);	
}

long CDECL c_set_colour(Virtual *vwk, long index, long red, long green, long blue)
{
#ifdef TEST_NOPCI
	return(0);
#else
	int ret;
	struct fb_info *info;
	info=rinfo_fvdi->info;
	index = toTosColors(index);
	red <<= 16;
	green <<= 16;
	blue <<= 16; 
	red /= 1000;
	green /= 1000;
	blue /= 1000;
	ret=radeonfb_setcolreg((unsigned)index,(unsigned)red,(unsigned)green,(unsigned)blue,0,info);
	return(!ret ? 1 : 0);
#endif
}

long CDECL c_set_resolution(struct mode_option *resolution)
{
#ifdef TEST_NOPCI
	if(resolution);
	return(0);
#else
	struct fb_info *info;
	struct fb_var_screeninfo var;
	info=rinfo_fvdi->info;
	radeon_check_modes(rinfo_fvdi,resolution);
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
	return(fb_set_var(info,&var) ? 0 : 1);
#endif
}

long CDECL c_get_videoramaddress()
{
#ifdef TEST_NOPCI
	return(Physbase());
#else
	struct fb_info *info;
	info=rinfo_fvdi->info;
	return((long)info->screen_base);
#endif
}

long CDECL c_get_width(void)
{
	struct fb_info *info;
	info=rinfo_fvdi->info;
	return((long)info->var.xres);
}

long CDECL c_get_height(void)
{
	struct fb_info *info;
	info=rinfo_fvdi->info;
	return((long)info->var.yres);
}

long CDECL c_get_width_virtual(void)
{
	struct fb_info *info;
	info=rinfo_fvdi->info;
	return((long)info->var.xres_virtual);
}

long CDECL c_get_height_virtual(void)
{
	struct fb_info *info;
	info=rinfo_fvdi->info;
	return((long)info->var.yres_virtual);
}

long CDECL c_get_bpp(void)
{
   return(rinfo_fvdi->bpp);
}

long CDECL c_init_cursor(void)
{
#ifdef TEST_NOPCI
	return(0);
#else
	return(RADEONCursorInit(rinfo_fvdi));
#endif
}

long CDECL c_free_cursor(long buf)
{
#ifdef TEST_NOPCI
	return(0);
#else
	return(radeon_offscreen_free(rinfo_fvdi,buf));
#endif
}
