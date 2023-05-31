#include <mint/osbind.h>
#include <mint/falcon.h>
#include "ct60.h"
#include "driver.h"
#include "radeonfb.h"
#include "mod_devicetable.h"

extern void setup_scrninfo(Device *device, Mode *graphics_mode);

extern long CDECL c_get_videoramaddress(void);
extern void CDECL c_set_resolution(struct mode_option *resolution);
extern long CDECL c_get_width(void);
extern long CDECL c_get_height(void);
extern long CDECL c_get_width_virtual(void);
extern long CDECL c_get_height_virtual(void);
extern long CDECL c_get_bpp(void);
extern long CDECL c_init_cursor(void);
extern long CDECL c_free_cursor(long buffer);

extern struct pci_device_id radeonfb_pci_table[];

/* color bit organization */
static char none[] = {0};
static char r_8[] = {8};
static char g_8[] = {8};
static char b_8[] = {8};
static char r_16[] = {5, 11, 12, 13, 14, 15};
static char g_16[] = {6, 5, 6, 7, 8, 9, 10};
static char b_16[] = {5, 0, 1, 2, 3, 4};
static char r_32[] = {8, 16, 17, 18, 19, 20, 21, 22, 23};
static char g_32[] = {8,  8,  9, 10, 11, 12, 13, 14, 15};
static char b_32[] = {8,  0,  1,  2,  3,  4,  5,  6,  7};

long buf_cursor;

/**
 * Mode *graphics_mode
 *
 * bpp     The number of bits per pixel
 *
 * flags   Various information (OR together the appropriate ones)
 *           CHECK_PREVIOUS - Ask fVDI to look at the previous graphics mode
 *                            set by the ROM VDI (I suppose.. *standa*)
 *           CHUNKY         - Pixels are chunky
 *           TRUE_COLOUR    - Pixel value is colour value (no palette)
 *
 * bits    Poperly set up MBits structure:
 *           red, green, blue,  - Pointers to arrays containing the number of
 *           alpa, genlock,       of bits and the corresponding bit numbers
 *           unused               (the latter only for true colour modes)
 *
 * code    Driver dependent value
 *
 * format  Type of graphics mode
 *           0 - interleaved
 *           2 - packed pixels
 *
 * clut    Type of colour look up table
 *           1 - hardware
 *           2 - software
 *
 * org     Pixel bit organization (OR together the appropriate ones)
 *           0x01 - usual bit order
 *           0x80 - Intel byte order
 **/
static Mode mode[3] = /* FIXME: big and little endian differences. */
{
	/* ... 0, packed pixels, hardware clut, usual bit order */
	{ 8, CHECK_PREVIOUS, {r_8,   g_8,   b_8,    none, none, none}, 0, 2, 1, 1},
	/* ... 0, packed pixels, software clut (none), usual bit order */
	{16, CHECK_PREVIOUS | CHUNKY | TRUE_COLOUR, {r_16, g_16, b_16, none, none, none}, 0, 2, 2, 1},
	{32, CHECK_PREVIOUS | CHUNKY | TRUE_COLOUR, {r_32,  g_32,  b_32,  none, none, none}, 0, 2, 2, 1}
};

extern Device device;

#ifdef DRIVER_IN_ROM
struct radeonfb_info *rinfo_fvdi;
#else
struct radeonfb_info *rinfo_fvdi = NULL;
#endif

char driver_name[256];

struct mode_option resolution;  /* from fb.h */

extern Driver *me;

extern short *loaded_palette;

extern short colours[][3];
extern void CDECL initialize_palette(Virtual *vwk, long start, long entries, short requested[][3], Colour palette[]);
extern void CDECL c_initialize_palette(Virtual *vwk, long start, long entries, short requested[][3], Colour palette[]);
extern long tokenize(char *value);

long wk_extend = 0;

#ifdef TEST_NOPCI
short accel_s = A_MOUSE;
short accel_c = A_SET_PIX | A_GET_PIX | A_BLIT | A_EXPAND | A_SET_PAL | A_GET_COL;
#else
short accel_s = 0;
short accel_c = A_SET_PIX | A_GET_PIX | A_MOUSE | A_LINE | A_BLIT | A_FILL | A_EXPAND | A_FILLPOLY | A_TEXT | A_SET_PAL | A_GET_COL;
#endif

#ifdef DRIVER_IN_ROM
Mode *graphics_mode;
#else
Mode *graphics_mode = &mode[1];
#endif

short debug;

/* from radeon_base */
extern char monitor_layout[];
extern short default_dynclk;
extern short ignore_edid;
extern short mirror;
extern short virtual;
extern short force_measure_pll;
extern short zoom_mouse;

extern void *c_read_pixel_8, *c_read_pixel_16, *c_read_pixel_32;
extern void *c_write_pixel_8, *c_write_pixel_16, *c_write_pixel_32;
extern void *c_line_draw;
extern void *c_expand_area;
extern void *c_fill_area;
extern void *c_blit_area;
extern void *c_fill_polygon;
extern void *c_text_area;
#ifdef TEST_NOPCI
extern void *mouse_draw;
#else
extern void *c_mouse_draw;
#endif
extern void *c_set_colours_8, *c_set_colours_16, *c_set_colours_32;
extern void *c_get_colours_8, *c_get_colours_16, *c_get_colours_32;
extern void *c_get_colour_8, *c_get_colour_16, *c_get_colour_32;

#ifdef DRIVER_IN_ROM
void *write_pixel_r;
void *read_pixel_r;
void *line_draw_r   = &c_line_draw;
void *expand_area_r = &c_expand_area;
void *fill_area_r   = &c_fill_area;
void *fill_poly_r   = &c_fill_polygon;
void *blit_area_r   = &c_blit_area;
void *text_area_r   = &c_text_area;
#ifdef TEST_NOPCI
void *mouse_draw_r  = &mouse_draw;
#else
void *mouse_draw_r  = &c_mouse_draw;
#endif
void *set_colours_r;
void *get_colours_r;
void *get_colour_r;
#else
void *write_pixel_r = &c_write_pixel_16;
void *read_pixel_r  = &c_read_pixel_16;
void *line_draw_r   = &c_line_draw;
void *expand_area_r = &c_expand_area;
void *fill_area_r   = &c_fill_area;
void *fill_poly_r   = &c_fill_polygon;
void *blit_area_r   = &c_blit_area;
void *text_area_r   = &c_text_area;
#ifdef TEST_NOPCI
void *mouse_draw_r  = &mouse_draw;
#else
void *mouse_draw_r  = &c_mouse_draw;
#endif
void *set_colours_r = &c_set_colours_16;
void *get_colours_r = &c_get_colours_16;
void *get_colour_r  = &c_get_colour_16;
#endif /* DRIVER_IN_ROM */

long monitor(const char **ptr);
long set_mode(const char **ptr);

Option options[] = {
	{"monitor_layout",   monitor,           -1},  /* monitor layout CRT, TMDS, LVDS */
	{"default_dynclk",   &default_dynclk,    1},  /* Power Management: 0/1 off/on */
	{"ignore_edid",      &ignore_edid,       1},  /* 0/1 Ignore EDID data when doing DDC probe */
	{"mirror",           &mirror,            1},  /* 0/1 mirror the display to both monitors */
	{"virtual",          &virtual,           1},  /* 0/1 enable virtual screen  */
	{"force_measure_pll",&force_measure_pll, 1},  /* 0/1 force measure pll */
	{"zoom_mouse",       &zoom_mouse,       -1},  /* 1/2/4 zoom mouse */
	{"mode",             set_mode,          -1},  /* mode WIDTHxHEIGHTxDEPTH@FREQ */
	{"debug",            &debug,             1}   /* debug, turn on debugging aids */
};

char *get_num(char *token, short *num)
{
	char buf[10], c;
	int i;
	*num = -1;
	if(!*token)
		return token;
	for(i = 0; i < 10; i ++)
	{
		c = buf[i] = *token++;
		if((c < '0') || (c > '9'))
			break;
	}
	if(i > 5)
		return token;
	buf[i] = '\0';
	*num = Funcs_atol(buf);
	return token;
}

long monitor(const char **ptr)
{
	Funcs_skip_space(*ptr);
	Funcs_copy(*ptr,monitor_layout);
	return(1);
}

int set_bpp(int bpp)
{
#ifndef TEST_NOPCI
  if(rinfo_fvdi!=NULL)
		Funcs_copy(rinfo_fvdi->name,driver_name);
	else
		Funcs_copy("ATI Radeon XX ",driver_name);
#else
		Funcs_copy("Test without PCI ",driver_name);
#endif
	switch(bpp)
	{
		/* indexed color modes */
		case 8:
			graphics_mode = &mode[0];
			read_pixel_r  = &c_read_pixel_8;
			write_pixel_r = &c_write_pixel_8;
			set_colours_r = &c_set_colours_8;
			get_colours_r = &c_get_colours_8;
			get_colour_r  = &c_get_colour_8;
			Funcs_cat("(8 bits)",driver_name);
			break;
		case 32:
			graphics_mode = &mode[2];
			read_pixel_r  = &c_read_pixel_32;
			write_pixel_r = &c_write_pixel_32;
			set_colours_r = &c_set_colours_32;
			get_colours_r = &c_get_colours_32;
			get_colour_r  = &c_get_colour_32;
			Funcs_cat("(32 bits)",driver_name);
			break;
		default:
			bpp = 16;		/* Default as 16 bit */
		case 16:
			graphics_mode = &mode[1];
			read_pixel_r  = &c_read_pixel_16;
			write_pixel_r = &c_write_pixel_16;
			set_colours_r = &c_set_colours_16;
			get_colours_r = &c_get_colours_16;
			get_colour_r  = &c_get_colour_16;
			Funcs_cat("(16 bits)",driver_name);
			break;
	}
	return bpp;
}

long set_mode(const char **ptr)
{
	char token[80], *tokenptr;
	if (!(*ptr = Funcs_skip_space(*ptr)))
		;		/* *********** Error, somehow */
	*ptr = Funcs_get_token(*ptr, token, 80);
	tokenptr = token;
	tokenptr = get_num(tokenptr, &resolution.width);
	tokenptr = get_num(tokenptr, &resolution.height);
	tokenptr = get_num(tokenptr, &resolution.bpp);
	tokenptr = get_num(tokenptr, &resolution.freq);
	resolution.used = 1;
	resolution.bpp = set_bpp(resolution.bpp);
	return 1;
}

/*
 * Handle any driver specific parameters
 */
long check_token(char *token, const char **ptr)
{
	int i;
	int normal;
	char *xtoken;
	xtoken = token;
	switch(token[0])
	{
		case '+':
			xtoken++;
			normal = 1;
			break;
		case '-':
			xtoken++;
			normal = 0;
			break;
		default:
			normal = 1;
			break;
	}
	for(i = 0; i < sizeof(options) / sizeof(Option); i++)
	{
		if(Funcs_equal(xtoken, options[i].name))
		{
			switch(options[i].type)
			{
				case -1:	/* Function call */
					return ((long (*)(const char **))options[i].varfunc)(ptr);
				case 0:	  /* Default 1, set to 0 */
					*(short *)options[i].varfunc = 1 - normal;
					return 1;
				case 1:	 /* Default 0, set to 1 */
					*(short *)options[i].varfunc = normal;
					return 1;
				case 2:	 /* Increase */
					*(short *)options[i].varfunc += -1 + 2 * normal;
					return 1;
				case 3:
					if (!(*ptr = Funcs_skip_space(*ptr)))
						;	 /* *********** Error, somehow */
					*ptr = Funcs_get_token(*ptr, token, 80);
					*(short *)options[i].varfunc = token[0];
					return 1;
			}
		}
	}
	return 0;
}

static void setup_wk(Virtual *vwk)
{
	Workstation *wk = vwk->real_address;
	/* update the settings */
	wk->screen.mfdb.width = resolution.width;
	wk->screen.mfdb.height = resolution.height;
	/*
	 * Some things need to be changed from the
	 * default workstation settings.
	 */
	wk->screen.mfdb.address = (void *)c_get_videoramaddress();
	wk->screen.mfdb.wdwidth = (c_get_width_virtual() * resolution.bpp) / 16;
	wk->screen.mfdb.bitplanes = resolution.bpp;
	wk->screen.wrap = c_get_width_virtual() * (resolution.bpp / 8);
	wk->screen.coordinates.max_x = wk->screen.mfdb.width - 1;
	wk->screen.coordinates.max_y = (wk->screen.mfdb.height & 0xfff0) - 1;	/* Desktop can't deal with non-16N heights */
	wk->screen.look_up_table = 0;			/* Was 1 (???)	Shouldn't be needed (graphics_mode) */
	wk->screen.mfdb.standard = 0;
	if (wk->screen.pixel.width > 0)			/* Starts out as screen width */
		wk->screen.pixel.width = (wk->screen.pixel.width * 1000L) / wk->screen.mfdb.width;
	else								   /*	or fixed DPI (negative) */
		wk->screen.pixel.width = 25400 / -wk->screen.pixel.width;
	if (wk->screen.pixel.height > 0)		/* Starts out as screen height */
		wk->screen.pixel.height = (wk->screen.pixel.height * 1000L) / wk->screen.mfdb.height;
	else									/*	 or fixed DPI (negative) */
		wk->screen.pixel.height = 25400 / -wk->screen.pixel.height;
	device.address		= wk->screen.mfdb.address;
	device.byte_width	= wk->screen.wrap;
	/* => c_set_colours_xx */
	if(wk->screen.palette.colours)
		c_initialize_palette(vwk, 0, wk->screen.palette.size, colours, wk->screen.palette.colours);
}

static void initialize_wk_palette(Virtual *vwk)
{
	Workstation *wk = vwk->real_address;
	if(loaded_palette)
		Funcs_copymem(loaded_palette, colours, 256 * 3 * sizeof(short));
	/*
	 * This code needs more work.
	 * Especially if there was no VDI started since before.
	 */
	if (wk->screen.palette.size != 256)
	{	/* Started from different graphics mode? */
		Colour *old_palette_colours = wk->screen.palette.colours;
		wk->screen.palette.colours = (Colour *)Funcs_malloc(256L * sizeof(Colour), 3);	/* Assume malloc won't fail. */
		if(wk->screen.palette.colours)
		{
			wk->screen.palette.size = 256;
			if (old_palette_colours)
				Funcs_free(old_palette_colours);	/* Release old (small) palette (a workaround) */
		}
		else
			wk->screen.palette.colours = old_palette_colours;
	}
}

/*
 * Do whatever setup work might be necessary on boot up
 * and which couldn't be done directly while loading.
 * Supplied is the default fVDI virtual workstation.
 */
long CDECL initialize(Virtual *vwk)
{
	unsigned long temp;
	short index;
	long handle,err;
	struct pci_device_id *radeon;
	int video_found=0;
	if(Funcs_get_cookie("_PCI",0))
	{
		if(debug)
			Funcs_puts("  Search pci devices...\r\n");
		index=0;
		do
		{
			handle=find_pci_device(0x0000FFFFL,index++);
			if(handle>=0)
			{
				err = read_config_longword(handle,PCIIDR,&temp);
				/* test Radeon ATI devices */
				if(err>=0 && !video_found)
				{
					radeon=radeonfb_pci_table; /* compare table */
					while(radeon->vendor)
					{
						if((radeon->vendor==(temp & 0xFFFF))
						 && (radeon->device==(temp>>16)))
						{
							if(radeonfb_pci_register(handle,radeon)>=0)
 								video_found=1;
							break;
						}
			    	radeon++;
					}
				}
			}
		}
		while(handle>=0);
	}
	if(!video_found)
	{
#ifdef TEST_NOPCI
		struct fb_info *info;
		long value;
		value=Funcs_get_cookie("_FRQ",0);
		if(value==50) /* MHz */
		{
			resolution.width=640;
			resolution.height=480;
		}
		else
		{
			resolution.width=320;
			resolution.height=240;
		}
		info=framebuffer_alloc(sizeof(struct radeonfb_info));
		if(!info)
			return 0;
		rinfo_fvdi=info->par;
		rinfo_fvdi->info=info;
		rinfo_fvdi->mon1_type=MT_CRT;
		info->var.xres=info->var.xres_virtual=resolution.width;
		info->var.yres=info->var.yres_virtual=resolution.height;
		info->var.bits_per_pixel=rinfo_fvdi->bpp=resolution.bpp;
		Funcs_copy("Test without PCI ",rinfo_fvdi->name);
#else
		Funcs_puts("  No Radeon PCI card found\r\n");
		return 0;
#endif
	}
	else if(Funcs_get_cookie("CT60",0) || Funcs_get_cookie("_CF_",0))
		ct60_vmalloc(2,(long)rinfo_fvdi); /* init radeon malloc, overwrite TOS */
	if(debug)
	{
		Funcs_puts("  Found ");
		Funcs_puts(rinfo_fvdi->name);
		Funcs_puts("\r\n");
	}		
	vwk = me->default_vwk;  /* This is what we're interested in */
	initialize_wk_palette(vwk);
	setup_wk(vwk);
	buf_cursor=0;
	return 1;
}

long CDECL setup(long type, long value)
{
	long ret;
	ret = -1;
	switch((int)type)
	{
		case Q_NAME:
			ret = (long)driver_name;
			break;
		case S_DRVOPTION:
			ret = tokenize((char *)value);
			break;
	}
	return ret;
}

/*
 * Initialize according to parameters (boot and sent).
 * Create new (or use old) Workstation and default Virtual.
 * Supplied is the default fVDI virtual workstation.
 */
Virtual* CDECL opnwk(Virtual *vwk)
{
	vwk = me->default_vwk;  /* This is what we're interested in */
	if(resolution.used)
	{
		if(debug)
		{
			char buf[10];
			Funcs_puts("  resolution ");
			Funcs_ltoa(buf, resolution.width, 10);
			Funcs_puts(buf);
			Funcs_puts("x");
			Funcs_ltoa(buf, resolution.height, 10);
			Funcs_puts(buf);
			Funcs_puts("x");
			Funcs_ltoa(buf, 1<<resolution.bpp, 10);
			Funcs_puts(buf);
			Funcs_puts("@");
			Funcs_ltoa(buf, resolution.freq, 10);
			Funcs_puts(buf);
			Funcs_puts("\r\n");
		}	
		c_set_resolution(&resolution);
	}
	/* update the width/height if restricted by the native part */
	resolution.width = c_get_width_virtual();
	resolution.height = c_get_height_virtual();
	resolution.bpp = set_bpp(c_get_bpp());
	setup_scrninfo(vwk->real_address->driver->device, graphics_mode);
	setup_wk(vwk);
 	if(!buf_cursor)
		buf_cursor = c_init_cursor();
	return 0;
}

/*
 * 'Deinitialize'
 */
void CDECL clswk(Virtual *vwk)
{
	if(buf_cursor)
	{
		c_free_cursor(buf_cursor);
		buf_cursor = 0;
	}
}

