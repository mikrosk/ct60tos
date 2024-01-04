/* TOS 4.04 PCI init for the CT60/CTPCI & Coldfire boards
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
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "config.h"
#include <mint/osbind.h>
#include <mint/falcon.h>
#include <mint/sysvars.h>
#ifndef hdv_bpb
#define hdv_bpb (((void (**)()) 0x472L))
#define hdv_rw (((void (**)()) 0x476))
#define hdv_mediach (((void (**)()) 0x47E))
#endif
#include <string.h>
#include <stdlib.h> /* for malloc */
#include "driver.h" /* fVDI */
#include "fb.h"
#include "radeon/radeonfb.h"
#include "lynx/smi.h"
#include "mod_devicetable.h"
#include "m68k_disasm.h"
#include "ct60.h"
#include "vidix.h"

#define BETA_VERSION "beta 11"

#undef DEBUG

#define CTPCI_1M 0x00000002

extern void kprint(const char *fmt, ...);
extern int sprintD(char *s, const char *fmt, ...);



extern int drivers_mem_init(void);
extern void init_resolution(long modecode);
extern long find_best_mode(long modecode);
extern const struct fb_videomode *get_db_from_modecode(long modecode);
extern int cd_disk_boot(void);
extern void install_magic_routine(void);
extern long get_no_cache_memory(void);
extern long get_no_cache_memory_size(void);

typedef struct
{
	unsigned short bootpref;
	char reserved[4];
	unsigned char language;
	unsigned char keyboard;
	unsigned char datetime;
	char separator;
	unsigned char bootdelay;
	char reserved2[3];
	unsigned short vmode;
	unsigned char scsi;
} NVM;

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

typedef struct
{
	long xbra;
	long ident;
	long old_address;
	short jump[3];
} XBRA;

extern void ltoa(char *buf, long n, unsigned long base);
extern Virtual *init_var_fvdi(void);
extern void det_xbios(void);
extern void det_linea(void);
extern void init_det_vdi(Virtual *vwk);
extern void det_vdi(void);
extern long init(Access *access, Driver *driver, Virtual *vwk, char *opts);
extern void init_screen(void);
extern COOKIE *get_cookie(long id);
extern int add_cookie(COOKIE *cook);
extern int eddi_cookie(int);
extern long initialize_pool(long size, long n);
extern void display_atari_logo(void);
extern void display_ati_logo(void);
extern void trace_tos(void);
void empty(void) {}

/* global */
extern unsigned short VERSION[];
extern unsigned short DATE[];
extern long second_screen;
extern struct mode_option resolution;
extern short accel_s, accel_c;
COOKIE vidix;
extern char monitor_layout[];
extern short default_dynclk;
extern short ignore_edid;
extern short mirror;
extern short virtual;
extern short force_measure_pll;
extern short zoom_mouse;
extern struct pci_device_id radeonfb_pci_table[]; /* radeon_base.c */
extern struct pci_device_id lynxfb_pci_table[]; /* smi_base.c */
extern struct pci_device_id ohci_usb_pci_table[]; /* ohci-hcd.c */
extern struct pci_device_id ehci_usb_pci_table[]; /* ehci-hcd.c */
extern Access *access;      /* fVDI */
Access _access_;            /* fVDI */
extern struct fb_info *info_fvdi;
extern long blocks,block_size;
extern long fix_modecode;
Virtual *base_vwk;
long old_vector_xbios,old_vector_gemdos,old_vector_linea,old_vector_vdi;
short video_found, usb_found, ethernet_found;
#ifdef USE_RADEON_MEMORY
short lock_video;
#endif
short use_dma, restart, redirect, os_magic, memory_ok, drive_ok, video_log, swi;
NVM nvm;
short key_init_with_sdram;
COOKIE eddi;
void (**mousevec)(void *);
_IOREC *iorec;
void (**ikbdvec)();
unsigned char **keytbl;
long debug_traps[16];
m68k_word *old_address;
unsigned long hardware_flags;
void (*magic_timer_c_routine)();
extern unsigned char _bss_start[];
extern unsigned char _end[];

static char mess_ignore[] = 
	"Press 'CTRL' or 'ALT' before this screen for ignore CTCM/CTPCI\r\n"
	"Press 'V' before this screen for use VIDEL\r\n"
	"   or 'D' for use the default mode / monitor layout\r\n"
	"          and turn on debug information\r\n";

unsigned long get_hex_value(void)
{
	unsigned long val;
	int i=0,j=0;
	char c;
	char buf[8];
	while(1)
	{
		c = (char)Crawcin();
		if(c == '\r')
			break;
		if((c == 8) && ( i > 0))
		{
			Cconout(c);
			i--;
		}
		else if((c >= '0') && (c <= '9'))
		{
			Cconout(c);
			buf[i++] = c & 0xF;
		}
		else if(((c >= 'a') && (c <= 'F')) || ((c >= 'A') && (c <= 'f')))
		{
			Cconout(c);
			buf[i++] = (c & 0xF) + 9;
		}
	}
	val = 0;
	while(--i >= 0)
	{
		val <<= 4;
		val |= (unsigned long)buf[j++];
	}
	return(val);
}

long boot_alloc(long size) /* without free */
{
	if(os_magic && !memory_ok)
	{
		long ret = *_membot;
#define BOOT_MEM_SIZE 0x10000
		static char boot_mem[BOOT_MEM_SIZE];
		static char *pt_boot_mem;
		if(pt_boot_mem == NULL)
			pt_boot_mem = boot_mem;
		if(&pt_boot_mem[size] <= &boot_mem[BOOT_MEM_SIZE]) /* try to use driver's memory */
		{
			ret = (long)pt_boot_mem;
			pt_boot_mem += size;
			return(ret);
		}
		*_membot += size;
		return(ret);
	}
	return((long)Mxalloc(size, 3));
}

long install_xbra(short vector, void *handler)
{
	XBRA *xbra = (XBRA *)boot_alloc(sizeof(XBRA));
	if(xbra != NULL)
	{
		xbra->xbra = 'XBRA';
		xbra->ident = '_PCI';
		xbra->jump[0] = 0x4EF9; /* JMP */
		*(long *)&xbra->jump[1] = (long)handler;
		asm volatile (" cpusha BC\n\t");
		xbra->old_address = (long)Setexc(vector, (void(*)())&xbra->jump[0]);
		return(xbra->old_address);
	}
	return(0);
}

#if 0
void uninstall_xbra(void **vector, long ident)
{
	XBRA *previous_xbra = NULL;
	XBRA *xbra = (XBRA *)((long)*vector - 12);
	while((xbra != NULL) && (xbra->xbra == 'XBRA'))
	{
	
		board_printf("XBRA %c%c%c%c %08X %08X\r\n", (xbra->ident >> 24) & 255, (xbra->ident >> 16) & 255, (xbra->ident >> 8) & 255, (xbra->ident >> 0) & 255,
		 (long)xbra + 12, xbra->old_address);
	
		if(xbra->ident == ident)
		{
			if(previous_xbra == NULL)
				*vector = (void *)xbra->old_address;
			else
				previous_xbra->old_address = xbra->old_address;
			break;
		}
		previous_xbra = xbra;
		if(xbra->old_address)
			xbra = (XBRA *)(xbra->old_address - 12);
		else
			xbra = NULL;
	}
}
#endif



static short fix_boot_modecode(short vmode)
{
	vmode &= ~VIRTUAL_SCREEN; /* fix boot modecode */
	if(!(vmode & DEVID)) /* modecode normal */
	{
		vmode &= ~(STMODES|OVERSCAN);
		vmode |= PAL;
		if((video_found == 1) && ((vmode & NUMCOLS) == BPS1) && !os_magic) /* VBL monochrome emulation */
		{
			switch(vmode & (VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|VGA|COL80))
			{
				case (VERTFLAG+VGA):                      /* 320 * 240 */
				case 0:                                                                      
				case (VGA+COL80):                         /* 640 * 480 */
				case (VERTFLAG+COL80):
				case (VESA_600+HORFLAG2+VGA+COL80):       /* 800 * 600 */
				case (VESA_768+HORFLAG2+VGA+COL80):       /* 1024 * 768 */
					break;
				default:
					vmode = PAL | VGA | COL80 | BPS1;       /* 640 * 480 * 1 */
					break;
			}
		}
		else if((vmode & NUMCOLS) < BPS8 || ((vmode & NUMCOLS) > BPS32))
		{
			if(!video_found)
				vmode = PAL | VGA | COL80 | BPS16; /* 640 x 480 * 16 */
			else
				vmode = VERTFLAG | PAL | VGA | BPS8; /* 320 * 240 * 8 */
		}
		if(vmode & VGA)
		{
			if(vmode & COL80)
				vmode &= ~VERTFLAG;
			else
				vmode |= VERTFLAG;
		}
		else
		{
			if(vmode & COL80)
				vmode |= VERTFLAG;
			else
				vmode &= ~VERTFLAG;
		}
	}
	else /* bits 11-3 used for DevID */
	{
		const struct fb_videomode *db = get_db_from_modecode(vmode);
		if(db == NULL)
			vmode = VERTFLAG | PAL | VGA | BPS8; /* 320 * 240 * 8 */
		else if((video_found == 1) && ((vmode & NUMCOLS) == BPS1) /* Radeon - VBL monochrome emulation */
		 && ((db->xres > MAX_WIDTH_EMU_MONO) || (db->yres > MAX_HEIGHT_EMU_MONO)))
			vmode = PAL | VGA | COL80 | BPS1; /* 640 * 480 * 1 */
	}
	return(vmode);
}

static void wait_key(void)
{
	Cconws("Press a key...\r\n");
	Crawcin();
}

int boot_menu(int index, int nb_lines, char *title, char *lines[], int delay_sec)
{
#define DELAY_MENU 400 /* 2 seconds */
	int i, j, end = 0;
	char key;
	long ret;
	unsigned long start_hz_200 = *_hz_200;
	unsigned long delay_menu;
	if(delay_sec > 0)
		delay_menu = (unsigned long)delay_sec * 200;
	else
		delay_menu= (unsigned long)nvm.bootdelay * 200;
	if(delay_menu < DELAY_MENU)
		delay_menu = DELAY_MENU;
	Cconws(title);
	while(1)
	{
		i = 0;
		j = 0;
		for(i = 0; i < nb_lines; i++)
		{
			Cconout(' ');
			Cconout(' ');	
			if(i == index)
			{
				Cconout(27); /* invert display */
				Cconout('p');
			}
			Cconout(' ');
			Cconout('1' + (char)i);
			Cconout(':');			
			Cconws(lines[i]);
			if(i == index)
			{
				Cconout(27);
				Cconout('q');
				j = i;
			}
			Cconout('\r');
			Cconout('\n');
		}
		while(1)
		{
			if((( *_hz_200 - start_hz_200) >= delay_menu) || end)
			  return(index);
			if(Cconis())
			{
				start_hz_200 = *_hz_200;
				ret = Crawcin();
				key = (char)ret;
				if((key == ' ') || (key == '\r'))
				  return(index);
				if((key >= '1') && (key <= ((char)nb_lines + '1')))
				{
					j = (int)(key - '1');
					end = 1;
					break;
				}
				ret >>= 16; /* scancode */
				if(ret ==  0x48) /* UP */
				{
					j--;
					if(j < 0)
						j = nb_lines - 1;
					break;
				}
				if(ret == 0x50) /* DOWN */
				{
					j++;
					if(j >= nb_lines)
						j = 0;
					break;
				}
				if((ret == 0x61) && ((Getshift() & 0xC) == 0xC)) /* CTRL-ALT-UNDO */
				{
					(void)NVMaccess(2, 0, sizeof(NVM), (void *)&nvm); /* init */
				  return(index);
				}
			}
		}
		for(i = 0; i < nb_lines; i++)
		{
			Cconout(27);
			Cconout('A');
		}
		Cconout('\r');
		index = j;
	}
}


void get_mouseikbdvec(void) /* for USB drivers and HTTP server (screen view) */
{
	_KBDVECS *kbdvecs = (_KBDVECS *)Kbdvbase();
	void **kbdvecs2 = (void **)kbdvecs;
	mousevec = &kbdvecs->mousevec; 
	ikbdvec = (void (**)())&kbdvecs2[-1]; /* undocumented */
	iorec = (_IOREC *)Iorec(1);
	keytbl = (unsigned char **)Keytbl(-1,-1,-1);
}

static short init_video(short vmode) /* called by init_devices */
{
	extern void *write_pixel_r, *read_pixel_r, *set_colours_r, *get_colours_r, *get_colour_r;
	/* fVDI spec */
	accel_s = 0;  
	accel_c = A_SET_PIX | A_GET_PIX | A_MOUSE | A_LINE | A_BLIT | A_FILL | A_EXPAND | A_FILLPOLY | A_TEXT | A_SET_PAL | A_GET_COL;
	read_pixel_r = write_pixel_r = set_colours_r = get_colours_r = get_colour_r = empty;
	if(!os_magic)
	{
		long screen_addr = Mxalloc(32000 + 256, 0) + 255; /* STRAM - use Mxalloc because Srealloc can be used by monochome emulation later */
		screen_addr &= ~0xFF;
		if((debug && !redirect) /* || usb_found */)
			wait_key();
		VsetScreen(screen_addr, screen_addr, 2, 0);  /* for reduce F030 Videl bus load */
		Cconws(mess_ignore);
	}
	old_vector_xbios = install_xbra(46, det_xbios); /* TRAP #14 */
	vidix.ident = 'VIDX';
	vidix.v.l = VIDIX_VERSION;
	add_cookie(&vidix);
#if 0 // #ifndef COLDFIRE
	if(use_dma)
	{
		Cconws("\rDMA (y/n)");
		if((Cconin() & 0xFF) != 'y')
		{
			use_dma = 0;
			Cconout(27);
			Cconout('E');
		}			
	}
#endif
	if(!vmode)
	{
		vmode = (short)find_best_mode((long)vmode);
		if(!vmode)
			vmode = PAL | VGA | COL80 | BPS16;
		else
			vmode |= BPS16;
	}
	vmode = fix_boot_modecode(vmode);

	VsetScreen(0, 0, 3, vmode); /* new Vsetscreen with internal driver installed */

	return(vmode);
}

/* Init TOS call is here ... */

int init_devices(int no_reset, unsigned long flags) /* after the original setscreen with the modecode from NVRAM */
{
	/* check boot version, 0x202 for Timer D vector overwrited by the boot after init_devices and used by FreeRTOS */
	if(*((unsigned short *)0xE80000) < 0x202)
		return(0);
	restart = (short)no_reset;
	if(restart == 2)
	{
    flags = hardware_flags; /* save for bss memset to 0 */
	  memset(_bss_start, 0, (int)(_end-_bss_start));
//	drivers_mem_init();
    hardware_flags = flags;
		memory_ok = 0; /* not use M(x)alloc */
		os_magic = 1;
	}
	else
	{
	  memset(_bss_start, 0, (int)(_end-_bss_start));
//	drivers_mem_init();
    hardware_flags = flags;
		memory_ok = 1; /* use M(x)alloc */
		os_magic = 0;
	}
	get_mouseikbdvec();
	swi = 0;
	(void)NVMaccess(0, 0, sizeof(NVM), (void *)&nvm);
	drive_ok = 0;
	redirect = 0; /* for debug to memory during boot (redirection impossible to file by GEMDOS) */
#ifdef USE_RADEON_MEMORY
	lock_video = 0;
#endif
	old_vector_xbios = old_vector_gemdos = old_vector_linea = old_vector_vdi = 0;
	do
	{
		static char *spec_monitor_layout[] = {"CRT,NONE","CRT,CRT","CRT,TMDS","TMDS,CRT","TMDS,TMDS"};
		int loop_counter = 0;
		unsigned long temp;
		short index, vmode = 0, key = 0;
		long handle, err;
		int usb_ok = 1;
		struct pci_device_id *board;
		old_address = (m68k_word *)0xFFFFFFFF; /* dbug */
		access = &_access_;
		base_vwk = init_var_fvdi();
#ifdef DEBUG
		debug = 1;
#else
		debug = 0;
#endif
		video_found = usb_found = ethernet_found = video_log = 0;
		/* init options Radeon */
		use_dma = (short)ct60_rw_parameter(CT60_MODE_READ, CT60_PARAM_CTPCI, 0);
		strcpy(monitor_layout, DEFAULT_MONITOR_LAYOUT); /* CRT, TMDS, LVDS */
		if(use_dma >= 0)
		{
			int mlayout = (int)((use_dma >> 2) & 0x1F) - 1;
			if((mlayout >= 0) && (mlayout < 5))
				strcpy(monitor_layout, spec_monitor_layout[mlayout]);
			use_dma = (use_dma >> 1) & 1;
		}
		else
			use_dma = 0;
		default_dynclk = -2;
		ignore_edid = 0;
		mirror = 1;
		virtual = 0;
		zoom_mouse = 1;
		force_measure_pll = 0;
    /* XBIOS */
		fix_modecode = 0;  /* XBIOS 95 used by AES */
		second_screen = 0;
		if(!os_magic && Cconis())
		{
			key = Crawcin() & 0xFF;
			while(Cconis())
				Crawcin();
		}
		temp = ct60_rw_parameter(CT60_MODE_READ, CT60_VMODE, (unsigned long)vmode);
		if((temp == 0xFFFFFFFF) || (key == 'D') || (key == 'd')) /* default mode */
		{
//			vmode = PAL | VGA | COL80 | BPS16;
			vmode = VESA_768 | HORFLAG2 | PAL | VGA | COL80 | BPS16;
			strcpy(monitor_layout, DEFAULT_MONITOR_LAYOUT); /* CRT, TMDS, LVDS */
			debug = 1;
 		}
		else
		{
			vmode = (short)temp;
			if(!debug && !(ct60_rw_parameter(CT60_MODE_READ, CT60_BOOT_LOG, 0) & 2))
				debug = redirect = video_log = 1;
		}
		/* PCI devices detection */ 
		do
		{
			index = 0;
			do
			{
				handle = find_pci_device(0x0000FFFFL, index++);
				if(handle >= 0)
				{
					unsigned long id = 0;
					err = read_config_longword(handle, PCIIDR, &id);
					/* test Radeon ATI devices */
					if((err >= 0) && !video_found && (key != 'V') && (key != 'v')) /* V => Videl use */
					{
						if(!loop_counter)
						{
							board = radeonfb_pci_table; /* compare table */
							while(board->vendor)
							{
								if((board->vendor == (id & 0xFFFF))
								 && (board->device == (id >> 16)))
								{
									if(!os_magic)
										Cconws(mess_ignore);
									resolution.used = 1;									
									init_resolution(PAL|VGA|COL80|BPS8); /* for monitor */
									if(radeonfb_pci_register(handle, board) >= 0)
 										video_found = 1;
									resolution.used = 0;
									break;
								}
								board++;
							}
						}
#ifdef CONFIG_VIDEO_SMI_LYNXEM
						else if(loop_counter == 1) /* motherboard PCI video */
						{
							board = lynxfb_pci_table; /* compare table */
							while(board->vendor)
							{
								if((board->vendor == (id & 0xFFFF))
								 && (board->device == (id >> 16)))
								{
									resolution.used = 1;
									init_resolution(PAL|VGA|COL80|BPS16); /* for monitor */
									board_printf("Mark, now you have 60 seconds before the Lynx driver start\r\nFor see Lynx mmio register use: dm.l 0xA0700300\r\n(fb_base + 0x400000 + 0x300000 + 0x300 - VGA registers)\r\n");
									wait_ms(60000);
									if(lynxfb_pci_register(handle, board) >= 0)
 										video_found = 2;
									resolution.used = 0;
									break;
								}
								board++;
							}
						}
#endif /* CONFIG_VIDEO_SMI_LYNXEM */
					}
					/* test USB devices */
					if((err >= 0) 
#if 0 // #ifdef MCF547X
					 && ((swi & 0x80) || (boot_os == 2)) /* SW6 (DOWN) */
#endif
					 && (hardware_flags & CTPCI_1M)
#define USB_MAX_BUS           3
					 && usb_ok && (usb_found < USB_MAX_BUS))
					{
						unsigned long class;
						if((read_config_longword(handle, PCIREV, &class) >= 0)
						 && ((class >> 16) == PCI_CLASS_SERIAL_USB))
						{
							switch(loop_counter)
							{
								case 0:
#if 0 // #ifndef COLDFIRE
									if((usb_ok == 1) && video_found)
									{
										Cconws("\rUSB (y/n)");
										if((Cconin() & 0xFF) != 'y')
											usb_ok = 0;
										else
										{
											usb_ok = 2;
#ifdef USE_RADEON_MEMORY /* CTPCI bug  fix */
											if(video_found)
											{
												vmode &= ~NUMCOLS;
												vmode |= BPS8; /* no endian convert */
								      	vmode = init_video(vmode);
							      		lock_video = 1;
							      	}
#endif /* USE_RADEON_MEMORY */
										}
									}
#endif /* !COLDFIRE */
									break;
							case 1:
									if((class >> 8) == PCI_CLASS_SERIAL_USB_EHCI)
									{
									}
									break;
								case 2: /* install EHCI before */
									if((class >> 8) == PCI_CLASS_SERIAL_USB_OHCI)
									{
									}
									break;
							}
						}
					}
					if((err >= 0) && !os_magic && !ethernet_found
					 && (hardware_flags & CTPCI_1M)
					 && (loop_counter == 1))
					{
					}
				}    
			}
			while(handle >= 0);
			loop_counter++;
		}
		while(loop_counter <= 2);
		if(usb_found)
		{
		}
		if(video_found)
		{
#ifdef USE_RADEON_MEMORY
      if(!lock_video)
#endif
      	vmode = init_video(vmode);
			if(!os_magic)
			{
				display_atari_logo();
				if(vmode & (DEVID|VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG)) 
					display_ati_logo();
			}
			old_vector_linea = install_xbra(10,det_linea);
		}
		if(redirect)
	  	debug = redirect = 0;
	}
	while(0);
	return((int)video_found);
}

void init_with_sdram(void) /* before booting, after the SDRAM init and the PCI devices list */
{
#ifdef BETA_VERSION
	int i;
	char buf[8];
	ltoa(buf, (long)VERSION[0], 16);
	Cconout(27);
	Cconws("p TOS drivers v");
	Cconout(buf[0]);
	Cconout('.');
	Cconws(&buf[1]);
	Cconws(" " BETA_VERSION " ");
	for(i = 0; i < 5; i++) /* day, month, date, hour, min */
	{
		ltoa(buf, (long)DATE[i] + 10000, 10);
		if(i < 2)
		{
			Cconws(&buf[3]);
			Cconout('/');
		}
		else if(i == 2)
		{
			Cconws(&buf[1]);
			Cconout(' ');
		}
		else
		{
			Cconws(&buf[3]);
			if(i == 3)
				Cconout(':');
		}
	}
	Cconout(' ');
	Cconout(27);
	Cconout('q');
	Cconws(" (build with GCC ");
	ltoa(buf, (long)__GNUC__, 10);
	Cconws(buf);
//	Cconout('.');
//	ltoa(buf, (long)__GCC_MINOR__, 10);
//	Cconws(buf);
	Cconws(")\r\n");
#endif /* BETA_VERSION */
	if(!os_magic &&	!(hardware_flags & CTPCI_1M))
		Cconws("Update the CTPCI hardware to 1M or more, if USB or Ethernet PCI boards used.\r\n");
	memory_ok = 1; /* use M(x)alloc */
	if(os_magic)
		drive_ok = 1;
	key_init_with_sdram = 0;
	if(!os_magic && Cconis())
	{
		key_init_with_sdram = Crawcin() & 0xFF;
		while(Cconis())
			Crawcin();
	}
	/* check boot version, 0x202 for Timer D vector overwrited by the boot after init_devices and used by FreeRTOS */
	if(*((unsigned short *)0xE80000) < 0x202)
		return;
	if(video_found /* Radeon driver */
	 && initialize_pool(block_size, blocks)
	 && init(access, base_vwk->real_address->driver, base_vwk, ""))
	{
		init_det_vdi(base_vwk->real_address->driver->default_vwk);
		old_vector_vdi = install_xbra(34, det_vdi); /* TRAP #2 */
		eddi.ident = 'EdDI';
		eddi.v.l = (long)&eddi_cookie;
		add_cookie(&eddi); /* infos about screen with vq_scrninfo() */		
	}
	else if(video_found) /* Radeon driver */
	{
		Cconws("VDI init error\r\n");
		Crawcin();
	}
	if(os_magic) 
		install_magic_routine(); /* init_before_autofolder call */
#ifdef DEBUG
	if(os_magic)
	{
		Cconws("Debug Magic\r\n");
		/* debug on videl output */
//		debug_traps[1] = install_xbra(33, trace_tos);  /* TRAP #1 */
//		debug_traps[2] = install_xbra(34, trace_tos);  /* TRAP #2 */
//		debug_traps[13] = install_xbra(45, trace_tos); /* TRAP #13 */
//		debug_traps[14] = install_xbra(46, trace_tos); /* TRAP #14 */
	}
#endif
}

void init_before_autofolder(void) /* after booting, before start AUTO folder */
{
	/* check boot version, 0x202 for Timer D vector overwrited by the boot after init_devices and used by FreeRTOS */
	if(*((unsigned short *)0xE80000) < 0x202)
		return;
	Cconws("\r\n");
	if(!os_magic)
	{
//		if((key_init_with_sdram == 'c') || (key_init_with_sdram == 'C'))
		cd_disk_boot();
	}
	drive_ok = 1;
}

void init_after_autofolder(void) /* after booting, after start AUTO folder */
{
	
}

static void init_disassembler(struct DisasmPara_68k *dp, char *opcode, char *operands)
{
	dp->instr = NULL;              /* pointer to instruction to disassemble */
	dp->iaddr = NULL;              /* instr.addr., usually the same as instr */
	dp->opcode = opcode;           /* buffer for opcode, min. 16 chars. */
	dp->operands = operands;       /* operand buffer, min. 128 chars. */
	dp->radix = 16;                /* base 2, 8, 10, 16 ... */
/* call-back functions for symbolic debugger support */
	dp->get_areg = NULL;           /* returns current value of reg. An */
	dp->find_symbol = NULL;        /* finds closest symbol to addr and */
	                               /*  returns (positive) difference and name */
/* changed by disassembler: */
	dp->type = 0;                  /* type of instruction, see below */
	dp->flags = 0;                 /* additional flags */
	dp->reserved = 0;
	dp->areg = 0;                  /* address reg. for displacement (PC=-1) */
	dp->displacement = 0;          /* branch- or d16-displacement */
}

long dbug(long key)
{
	static struct DisasmPara_68k dp;
	static char buffer[16];
	m68k_word *p,*ip;
	static char opcode[16];
	static char operands[128];
	static char iwordbuf[32];
	int n,i;
	char *s;
	if((key >= 'A') && (key <= 'Z'))
		key |= 0x20;
	if((char)key == 'v')
	{
#ifdef DEBUG
		extern void display_char(char c);
		if(video_found)
		{
			display_char((key >> 16) & 0xFF);
			return(1);
		}
#endif /* DEBUG */
		return(0);
	}
	switch((char)key)
	{
		case '\r':
			if(old_address != (m68k_word *)0xFFFFFFFF)
			{
				p = old_address;
				goto disassemble;
			}
			break;
		case 'd':
			Cconws("\r\nDisassemble memory (hex) ? ");
			p=(m68k_word *)(get_hex_value() & ~1);
disassemble:
			db_radix = 16;
			init_disassembler(&dp, opcode, operands);
			for(i = 0;i < 8; i++)
			{					
				for(n = 0; n < sizeof(opcode)-1; opcode[n++] = ' ');
				opcode[n] = 0;
				for(n = 0; n < sizeof(operands); operands[n++] = 0);
				dp.instr = dp.iaddr = p;
				p = M68k_Disassemble(&dp);
				/* print up to 5 instruction words */
				for(n = 0; n < 26; iwordbuf[n++] = ' ');
			  iwordbuf[26] = 0;
				if((n = (int)(p - dp.instr)) > 5)
					n = 5;
				ip = dp.instr;
				s = iwordbuf;
				while(n--)
				{
					ltoa(buffer,(((unsigned long)*(unsigned char *)ip)<<8) | ((unsigned long)*((unsigned char *)ip+1)) | 0x10000UL,16);
					*s++ = buffer[1];
					*s++ = buffer[2];
					*s++ = buffer[3];
					*s++ = buffer[4];
					s++;
					ip++;
				}
				ltoa(buffer,(unsigned long)dp.iaddr,16);
				Cconws("\r\n");
				Cconws(buffer);
				Cconws(": ");
				Cconws(iwordbuf);
				strcpy(buffer, "       ");
				n = 0;
				while(opcode[n])
				{
					buffer[n] = opcode[n];
					n++;
				}
				buffer[n] = 0;
				Cconws(buffer);
				Cconout(' ');
				Cconws(operands);
			}
			old_address = p;
			key = 0;
			break;
		case 'h':
		case '?':
			Cconws("\r\nList of commands:");
			Cconws("\r\n (D)isassemble memory");
			Cconws("\r\n (M)emory dump");
			Cconws("\r\n (P)atch memory");
			key = 0;
			break;
		case 'm':
		case 'p':
			old_address = (m68k_word *)0xFFFFFFFF;
			break;
		default:
			if(key > ' ')
				key = 0;
			break;		
	}
	return(key);
}


void event_aes(void)
{
}

char *disassemble_pc(unsigned long pc)
{
	static char line[80];
	static struct DisasmPara_68k dp;
	static char buffer[16];
	m68k_word *ip, *p = (m68k_word *)pc;
	static char opcode[16];
	static char operands[128];
	static char iwordbuf[32];
	int n;
	char *s;
	db_radix = 16;
	init_disassembler(&dp, opcode, operands);
	for(n = 0; n < sizeof(opcode)-1; opcode[n++]=' ');
	opcode[n] = 0;
	for(n = 0; n < sizeof(operands); operands[n++]=0);
	dp.instr = dp.iaddr = p;
	p = M68k_Disassemble(&dp);
	/* print up to 5 instruction words */
	for(n = 0; n<26; iwordbuf[n++]=' ');
	iwordbuf[26] = 0;
	if((n = (int)(p-dp.instr)) > 5)
		n = 5;
	ip = dp.instr;
	s = iwordbuf;
	while(n--)
	{
		ltoa(buffer, (((unsigned long)*(unsigned char *)ip) << 8) | ((unsigned long)*((unsigned char *)ip+1)) | 0x10000UL, 16);
		*s++ = buffer[1];
		*s++ = buffer[2];
		*s++ = buffer[3];
		*s++ = buffer[4];
		s++;
		ip++;
	}
	ltoa(buffer,(unsigned long)dp.iaddr,16);
	strcpy(line, buffer);
	strcat(line, ": ");
	strcat(line, iwordbuf);
	strcpy(buffer, "       ");
	n = 0;
	while(opcode[n])
	{
		buffer[n] = opcode[n];
		n++;
	}
	buffer[n++] = ' ';
	buffer[n] = '\0';
	strcat(line, buffer);
	strcat(line, operands);
	return(line);
}

