/* TOS 4.04 PCI init for the CT60/CTPCI boards
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
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "config.h"
#include <mint/osbind.h>
#include <mint/falcon.h>
#include <mint/sysvars.h>
#include <string.h>
#include "radeon/fb.h"
#include "radeon/radeonfb.h"
#include "mod_devicetable.h"
#include "m68k_disasm.h"
#include "ct60.h"
#ifndef TEST_NOPCI
#include "vidix.h"
#endif

#ifndef Vsetscreen
#ifdef VsetScreen
#define Vsetscreen VsetScreen
#else
#warning Bad falcon.h
#endif
#endif

#ifndef Montype
#ifdef VgetMonitor
#define Montype VgetMonitor
#else
#warning Bad falcon.h
#endif
#endif

#ifdef NETWORK

// #define TEST_NETWORK

#define uint8 unsigned char
#define uint16 unsigned short
#define uint32 unsigned long
#ifdef LWIP
#include "lwip/net.h"
#include "lwip/sockets.h"
#include "lwip/tftp.h"
extern int tftpreceive(unsigned char *server, char *sname, short handle);
extern int tftpsend(unsigned char *server, char *sname, short handle);
extern int usb_load_files(void);
typedef unsigned char IP_ADDR[4];
#else
#include "net/eth.h"
#include "net/nbuf.h"
#include "net/nif.h"
#include "net/ip.h"
#include "net/udp.h"
#include "net/tftp.h"
#endif
#include "get.h"

extern long install_ram_disk(void);
extern void init_dma(void);
extern int init_network(void);
#ifndef LWIP
extern void end_network(void);
#endif
extern int alert_tos(char *string);
extern void init_dma_transfer(void);
extern void minus(char *s);
extern int InitSound(void);

unsigned long write_protect_ram_disk;

#endif /* NETWORK */

extern void init_resolution(long modecode);

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

#ifndef Screalloc
#define Screalloc(size) (void *)trap_1_wl((short)(0x15),(long)(size))
#endif

extern void ltoa(char *buf, long n, unsigned long base);
extern void copy(const char *src, char *dest);
extern void cat(const char *src, char *dest);

extern Virtual *init_var_fvdi(void);
extern void det_xbios(void);
extern void det_linea(void);
extern void init_det_vdi(Virtual *vwk);
extern void det_vdi(void);
extern long init(Access *access, Driver *driver, Virtual *vwk, char *opts);
extern COOKIE *get_cookie(long id);
extern int add_cookie(COOKIE *cook);
extern int eddi_cookie(int);
extern long initialize_pool(long size, long n);
extern void display_atari_logo(void);
#ifndef TEST_NOPCI
extern void display_ati_logo(void);
#endif

/* global */
extern long second_screen;
extern struct mode_option resolution;
#ifdef TEST_NOPCI
COOKIE pci;
#else
COOKIE vidix;
#endif
short use_dma;
extern char monitor_layout[];
extern short default_dynclk;
extern short ignore_edid;
extern short mirror;
extern short virtual;
extern short force_measure_pll;
extern short zoom_mouse;
extern struct pci_device_id radeonfb_pci_table[]; /* radeon_base */
extern Access *access;      /* fVDI */
Access _access_;            /* fVDI */
extern struct radeonfb_info *rinfo_fvdi;
extern long blocks,block_size;
extern long fix_modecode;
Virtual *base_vwk;
long old_vector_xbios,old_vector_linea,old_vector_vdi;
short video_found,usb_found,ata_found;
COOKIE eddi;
m68k_word *old_address;
extern unsigned char _bss_start[];
extern unsigned char _end[];

unsigned long get_hex_value(void)
{
	unsigned long val;
	int i=0,j=0;
	char c;
	char buf[8];
	while(1)
	{
		c=(char)Crawcin();
		if(c=='\r')
			break;
		if(c==8 && i>0)
		{
			Cconout(c);
			i--;
		}
		else if(c>='0' && c<='9')
		{
			Cconout(c);
			buf[i++] = c & 0xF;
		}
		else if((c>='a' && c<='F') || (c>='A' && c<='f'))
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

long install_xbra(short vector, void *handler)
{
	XBRA *xbra;
	xbra = (XBRA *)Mxalloc(sizeof(XBRA), 3);
	if(xbra != NULL)
	{
		xbra->xbra = 'XBRA';
		xbra->ident = '_PCI';
		xbra->jump[0] = 0x4EF9; /* JMP */
		*(long *)&xbra->jump[1] = (long)handler;
#ifdef COLDFIRE
		asm("	.chip 68060");
#endif
		asm(" cpusha BC");
#ifdef COLDFIRE
		asm("	.chip 5200");
#endif
		xbra->old_address = (long)Setexc(vector,(void(*)())&xbra->jump[0]);
		return(xbra->old_address);
	}
	return(0);
}

#ifdef NETWORK

int tftp_load_file(int drive, char *name, char *path_server, IP_ADDR server)
{
	int ch, i, ret;
	long handle, err;
	static char sname[80], fname[80], data[1024];
	char *p;
	copy(path_server, sname);
	cat(name, sname);
	minus(sname);
	fname[0] = (char)drive+'A'; fname[1] = ':'; fname[2] = '\\';
	if(name[0] == '/' || name[0] == '\\')
		copy(name, &fname[2]);
	else
		copy(name, &fname[3]);
#ifdef LWIP
	if(ch);
	if(data);
	i=3;
	while(fname[i])
	{
		if(fname[i] == '/' || fname[i] == '\\')
		{
			fname[i]=0;
			Dcreate(fname);
			fname[i]='\\';
		}
		i++;	
	}
	err = handle = (long)Fcreate(fname, 0);
	ret = TRUE;
	if(err >= 0)
	{
		if((ret = tftpreceive((unsigned char *)server, sname, (short)handle)) == TRUE)
			Fclose((short)handle);
		else
		{
			Fclose((short)handle);
			Fdelete(fname);
		}
#else
	if((ret = tftp_read(&nif[ETHERNET_PORT], sname, server)) == TRUE)
	{
		i=3;
		while(fname[i])
		{
			if(fname[i] == '/' || fname[i] == '\\')
			{
				fname[i]=0;
				Dcreate(fname);
				fname[i]='\\';
			}
			i++;	
		}
		err = handle = (long)Fcreate(fname, 0);
		i = 0;
		while(((ch = tftp_in_char()) != -1) && (err >= 0))
		{
			data[i++] = (char)ch;
			if(i >= 1024)
			{
				err = Fwrite((short)handle, i, data);
				i = 0;
			}
		}
		if((err >= 0) && i)
				err = Fwrite((short)handle, i, data);
		if(handle >= 0) 
			Fclose((short)handle);
		tftp_end(1);
#endif
		p = tftp_get_error();
		if(*p)
			ret = FALSE;
	}
	return(ret);
}

int tftp_write_file(int drive, char *name, char *path_server, IP_ADDR server)
{
	long handle, len;
	int ret = TRUE;
	char *buf;
	static char sname[80], fname[80];
	copy(path_server, sname);
	cat(name, sname);
	minus(sname);
	fname[0] = (char)drive+'A'; fname[1] = ':'; fname[2] = '\\';
	copy(name, &fname[3]);
	handle = (long)Fopen(fname, 2);
	if(handle >=  0)
	{
#ifndef LWIP
		len = Fseek(0, (short)handle, 2);
		if(len > 0)
		{
			Fseek(0, (short)handle, 0);
			buf = (char *)Mxalloc(len, 3);
			if(buf)
			{
				if(Fread((short)handle, len, buf) >= 0)
					ret = tftp_write(&nif[ETHERNET_PORT], sname, server, (unsigned long)buf, (unsigned long)&buf[len]);			
				Mfree(buf);
			}
		}
#else
		if(len);
		if(buf);
		ret = tftpsend((unsigned char *)server, sname, (short)handle);
#endif
		Fclose((short)handle);
	}
	return(ret);
}

#endif

/* Init TOS call is here ... */

void init_devices(void) /* after the original setscreen with the modecode from NVRAM */
{
#ifdef COLDFIRE
#ifdef LWIP
	extern void *run;
	extern void *start_run;
#endif
	extern void osinit(void);
	memset(_bss_start, 0, (int)(_end - _bss_start));
 	*_membot = (long)_end;
	osinit();        /* BDOS */
#ifdef LWIP
  start_run = run; /* PD for BDOS malloc */
#endif
#else /* 68060 - use GEMDOS */
	memset(_bss_start, 0, (int)(_end-_bss_start));
#endif /* COLDFIRE */
	do
	{
		unsigned long temp;
		short index, vmode = 0;
		long handle, err;
		struct pci_device_id *radeon;
		old_address = (m68k_word *)0xFFFFFFFF; /* dbug */
		access = &_access_;
		base_vwk = init_var_fvdi();
#ifdef DEBUG
		debug = 1;
#else
		debug = 0;
#endif
		video_found = usb_found = ata_found = 0;
		/* init options Radeon */
		use_dma = 0;
		copy(DEFAULT_MONITOR_LAYOUT, monitor_layout); /* CRT, TMDS, LVDS */
		default_dynclk = -2;
		ignore_edid = 0;
		mirror = 1;
		virtual = 0;
		zoom_mouse = 1;
		force_measure_pll = 0;
    /* XBIOS */
		fix_modecode = 0;  /* XBIOS 95 used by AES */
		second_screen = 0;
#ifdef TEST_NOPCI
		if(Montype() != 2) /* VGA */
			continue;
		Cconws("\rTest fVDI (y/n)");
		if((Cconin()&0xFF) != 'y')
		{
			Cconout(27);
			Cconout('E');
			continue;
		}
		video_found = 1;
		if(temp || index || handle || radeon || err);
#else
		temp = ct60_rw_parameter(CT60_MODE_READ, CT60_VMODE, (unsigned long)vmode);
		if(temp == 0xFFFFFFFF) /* default mode */
//			vmode = PAL | VGA | COL80 | BPS16;
			vmode = VESA_768 | HORFLAG2 | PAL | VGA | COL80 | BPS16;
		else
			vmode = (short)temp;
		if((vmode & NUMCOLS) < BPS8 || (vmode & NUMCOLS) > BPS32)
		{
			vmode &= (VERTFLAG | PAL | VGA | COL80);
			vmode |= BPS8;
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
		/* PCI devices detection */ 
		index = 0;
		do
		{
			handle = find_pci_device(0x0000FFFFL, index++);
			if(handle >= 0)
			{
				temp = 0;
				err = read_config_longword(handle, PCIIDR, &temp);
				/* test Radeon ATI devices */
				if((err >= 0) && !video_found)
				{
					radeon = radeonfb_pci_table; /* compare table */
					while(radeon->vendor)
					{
						if((radeon->vendor == (temp & 0xFFFF))
						 && (radeon->device == (temp >> 16)))
						{
							resolution.used = 1;
							init_resolution((long)vmode & 0xFFFF); /* for monitor */
							if(radeonfb_pci_register(handle, radeon) >= 0)
 								video_found = 1;
							resolution.used = 0;
							break;
						}
						radeon++;
					}
				}
				/* test USB device */
				if((err >= 0) && !usb_found)
				{
					if(read_config_longword(handle,PCIREV,&temp) >= 0
					 && ((temp >> 16) == PCI_CLASS_SERIAL_USB))
					{
						Cconws("USB PCI card found\r\n");
						if((temp >> 8) == PCI_CLASS_SERIAL_USB_UHCI)
							Cconws("UHCI USB controller found\r\n");
						else if((temp >> 8) == PCI_CLASS_SERIAL_USB_OHCI)
							Cconws("OHCI USB controller found\r\n");
						else if((temp >> 8) == PCI_CLASS_SERIAL_USB_EHCI)
						{
							Cconws("EHCI USB controller found\r\n");
							usb_found = 1;
						}
					}
				}
				/* test ATA device */
				if((err >= 0) && !ata_found)
				{
					if(temp == 0x12345678)  /* device / vendor */
						ata_found = 1;	
				}
			}    
		}
		while(handle >= 0);
#endif
		old_vector_xbios = 0;
		if(video_found)
		{
#ifdef TEST_NOPCI
			COOKIE *p;
			struct fb_info *info;
			p = get_cookie('_FRQ');
			if(p != NULL) && (p->v.l == 50)) /* MHz */
			{
				resolution.width = 640;
				resolution.height = 480;
				vmode = VGA | COL80 | BPS16;
			}
			else
			{
				resolution.width = 320;
				resolution.height = 240;
				vmode = VERTFLAG | VGA | BPS16;
			}
			resolution.bpp = 16;
			resolution.freq = 60;
			resolution.used = 1;
			info =framebuffer_alloc(sizeof(struct radeonfb_info));
			if(!info)
				continue;
			rinfo_fvdi = info->par;
			rinfo_fvdi->info = info;
			rinfo_fvdi->mon1_type = MT_CRT;
			info->var.xres = info->var.xres_virtual = resolution.width;
			info->var.yres = info->var.yres_virtual = resolution.height;
			info->var.bits_per_pixel = rinfo_fvdi->bpp = resolution.bpp;
			copy("Test without PCI ",rinfo_fvdi->name);
			pci.ident = '_PCI';
			pci.v.l = 0;
			add_cookie(&pci); /* for TOS call init_with_sdram() */
			old_vector_xbios = install_xbra(46, det_xbios); /* TRAP #14 */
#else
//			COOKIE *p;
//			p = get_cookie('_VDO');
//			if(p != NULL)
//				p->v.l = 0xFFFF0000;  /* not FALCON graphics modes */
//			Vsetscreen(0, 0, 2, 0);  /* for reduce F030 Videl bus load */
			old_vector_xbios = install_xbra(46, det_xbios); /* TRAP #14 */
			vidix.ident = 'VIDX';
			vidix.v.l = VIDIX_VERSION;
			add_cookie(&vidix);
#endif
			use_dma = (short)ct60_rw_parameter(CT60_MODE_READ,CT60_PARAM_CTPCI,0);
			if(use_dma >= 0)
				use_dma = (use_dma >> 1) & 1;
			else
				use_dma = 0;
#ifndef COLDFIRE
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
			Vsetscreen(0, 0, 3, vmode);
			display_atari_logo();
#ifndef TEST_NOPCI
			if(vmode & (VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG))
				display_ati_logo();
#endif		
			old_vector_linea = install_xbra(10,det_linea);
		}
	}
	while(0);
}

void init_with_sdram(void) /* before booting, after the SDRAM init and the PCI devices list */
{
	if(video_found && initialize_pool(block_size,blocks)
	 && init(access, base_vwk->real_address->driver, base_vwk, ""))
	{
		init_det_vdi(base_vwk->real_address->driver->default_vwk);
		old_vector_vdi = install_xbra(34, det_vdi); /* TRAP #2 */
		eddi.ident = 'EdDI';
		eddi.v.l = (long)&eddi_cookie;
		add_cookie(&eddi); /* infos about screen with vq_scrninfo() */		
	}
	if(ata_found)
	{
		if(!old_vector_xbios)
			old_vector_xbios = install_xbra(46,det_xbios); /* TRAP #14 */

	}
#ifdef NETWORK
#ifndef LWIP
	init_dma();
#endif
#ifndef MCF5445X
#ifdef SOUND_AC97
//	InitSound(); // AC97
#endif
#endif
#endif
}

void init_before_autofolder(void) /* after booting, before start auto-folder */
{
#ifdef NETWORK
	IP_ADDR server;
	char path_server[80],name[80],speed[10];
	char *buf;
	long handle, len;
	int i, j, drive;
	if((drive = install_ram_disk()) != 0)
	{
		board_get_filename(path_server);
		i = j = 0;
		while(path_server[i])
		{
			if(path_server[i] == '/' || path_server[i] == '\\')
				j = i+1;
			i++;	
		}
		path_server[j] = 0;
		board_get_server((unsigned char *)server);
		if(init_network() == TRUE)
		{
			write_protect_ram_disk = TRUE;
			Cconws("TFTP load tftp.inf\r\n");
			name[0]=(char)drive+'A';
			name[1]=':';
			name[2]='\\';
			copy("tftp.inf",&name[3]);
			if(tftp_load_file(drive, &name[3], path_server, server) == TRUE)
			{			
				handle = Fopen(name, 2);
				if(handle >=  0)
				{
					len = Fseek(0, handle, 2);
					if(len > 0)
					{
						Fseek(0, handle, 0);
						buf = (char *)Mxalloc(len, 3);
						if(buf)
						{
							if(Fread(handle, len, buf) >= 0)
							{
								i=0;
#ifdef LWIP
								if((len >= 3) && (buf[0] == 'U') && (buf[1] == 'S') && (buf[2] == 'B'))
								{
									write_protect_ram_disk = FALSE;
									Cconws("Waiting USB link...\r\n");
									if(usb_load_files() == TRUE)
									{
										len  = 0;
										Cconws("Ram-disk loaded from USB\r\n");
									}
									else
									{
										write_protect_ram_disk = TRUE;
										i += 3;
										len -= 3;
									}
								}
#endif
								while(len > 0)
								{
									j=0;
									while(buf[i]!=0 && buf[i]!='\r' && buf[i]!='\n')
									{
										name[j++]=buf[i++];
										len--;
									}
									name[j]=0;
									if(j)
									{
										unsigned long start_hz_200 = *_hz_200;
				  					Cconws("TFTP load ");
								  	Cconws(name);
								  	Cconws(" ... ");	
										if(tftp_load_file(drive, name, path_server, server) != TRUE)
										{
											Cconws("\r\n");
											Cconws(tftp_get_error());
											Cconws("\r\n");
										}
										else
										{
											int i;
											long handle, len = 0;
											char fname[80];
											unsigned long tps = *_hz_200 - start_hz_200;
											fname[0] = (char)drive+'A'; fname[1] = ':'; fname[2] = '\\';
											if(name[0] == '/' || name[0] == '\\')
												copy(name, &fname[2]);
											else
												copy(name, &fname[3]);
											i=3;
											while(fname[i])
											{
												if(fname[i] == '/')
													fname[i]='\\';
												i++;	
											}
											handle = (long)Fopen(fname, 0);
											if(handle >=  0)
											{
												len = Fseek(0, (short)handle, 2);
												if(len > 0)
													Fseek(0, (short)handle, 0);
												Fclose((short)handle);
											}
											if(len < 0)
												len = 0;
                      len /= tps;
                      len /= 5;
											ltoa(speed, len, 10);
											Cconws(speed);
									  	Cconws("KB/S\r\n");																			
										}
									}		
									if(buf[i]==0)
										break;
									if(buf[i]=='\r')
									{
										i++;
										len--;
									}
									if(buf[i]=='\n')
									{
										i++;
										len--;
									}
								}
							}
							Mfree(buf);
						}
					}
					Fclose(handle);
				}
			}
			else
			{
				Cconws(tftp_get_error());
				Cconws("\r\n");
			}
			if(Fsfirst("C:\\tftpsend",0x10) != 0)
				Dcreate("C:\\tftpsend");      /* for later */
#ifndef LWIP
#ifdef TEST_NETWORK
			{
				static char sname[80],data[1024],buf[10];
				int i=0,j,ch;
				char *p;
				Cconws("Network test...\r\n");
				copy(path_server, sname);
				cat("tftpsend\\test.bin", sname);
				minus(sname);
				for(j = 0; j < 10; j++)
				{
					Cconws("Send TOS...\r\n");
					if(tftp_write(&nif[ETHERNET_PORT], sname, server, 0xE00000, 0xEF0000) == TRUE)
					{
						Cconws("Get TOS...\r\n");
					  if(tftp_read(&nif[ETHERNET_PORT], sname, server) == TRUE)
						i = 0;
						p = (char *)0xE00000;
						while((ch = tftp_in_char()) != -1)
						{
							data[i++] = (char)ch;
							if(i >= 1024)
							{
								for(i = 0; i < 1024; i++)
								{
									if(*p++ != data[i])
									{
										Cconws("Error at offset 0x");
										ltoa(buf,(long)p & 0xFFFFF,16);
										Cconws(buf);
										Cconws("\r\n");
									}
								}
								i = 0;
							}
						}
						p = tftp_get_error();
						if(*p)
						{
							Cconws(tftp_get_error());
							Cconws("\r\n");
						}
					}
					else
					{
						Cconws(tftp_get_error());
						Cconws("\r\n");				
					}
				}
				Cconws("Press a key...\r\n");
				Cnecin();
			}
#endif /* TEST_NETWORK */
			end_network();
#endif /* LWIP */
			write_protect_ram_disk = FALSE;
		}
	}
	else
	{
		Cconws("Press a key...\r\n");
 		Cnecin();	
 	}
#endif
}

#ifdef DBUG
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
#endif

long dbug(long key)
{
#ifdef DBUG
	static struct DisasmPara_68k dp;
	static char buffer[16];
	m68k_word *p,*ip;
	static char opcode[16];
	static char operands[128];
	static char iwordbuf[32];
	int n,i;
	char *s;
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
				Cconout('\r');
				Cconout('\n');
				Cconws(buffer);
				Cconout(':');
				Cconout(' ');
				Cconws(iwordbuf);
				copy("       ",buffer);
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
	}
#endif
	return(key);
}

void event_aes(void)
{
#ifdef NETWORK
	static int lock = 0;
	static long mem_size = 0;
	static unsigned long old_hz_200 = 0;
	IP_ADDR server;
	_DTA *save_dta;
	_DTA tp_dta;
	static char subdir[] = "C:\\tftpsend\\";
	static char path[80], path_server[80], name[80], buf[48], buf_alert[256];
	char *p, *p2;
	char c;
	int i, j, ok, nb_files;
	long total_size;
	if((*_hz_200 - old_hz_200) < 200) /* 1 second */
		return;
	if(lock)
		return;
	lock = 1;
	old_hz_200 = *_hz_200;
	nb_files = 0;
	total_size = 0;
	save_dta=Fgetdta();
	Fsetdta(&tp_dta);
	copy(subdir, path);
	cat("*.*", path);
	if(Fsfirst(path,1) == 0)
	{
		do
		{
			if((tp_dta.dta_name[0] != '.') && tp_dta.dta_size)
			{
				total_size += tp_dta.dta_size;
				nb_files++;
			}
		}
		while(Fsnext() == 0);
	}
	if(nb_files && (total_size == mem_size))
	{
		NVMaccess(0, 0, 48, buf);
		if(buf[6] == 2)	/* language */
			i = alert_tos("[1][Envoi des fichiers|au serveur TFTP ?][Oui|Non]");
		else	
			i = alert_tos("[1][Send files to|the TFTP server?][Yes|No]");
		if(i == 1)
		{
			board_get_filename(path_server);
			i = j = 0;
			while(path_server[i])
			{
				if(path_server[i] == '/' || path_server[i] == '\\')
					j = i+1;
				i++;	
			}
			path_server[j] = 0;
			board_get_server((unsigned char *)server);
#ifndef LWIP
			if(init_network())
			{
#endif
				if(Fsfirst(path, 1) == 0)
				{
					ok = TRUE;
					do
					{
						if((tp_dta.dta_name[0] != '.') && tp_dta.dta_size)
						{
							copy(subdir, name);
							cat(tp_dta.dta_name, name);
							if(ok == TRUE)
							{
								ok = tftp_write_file((int)(name[0]-'A'), name+3, path_server, server);
								if(ok != TRUE)
								{
									i = j = 0;
									p = tftp_get_error();
									copy("[3][",buf_alert);
									p2 = &buf_alert[4];
									while(*p && j < 5) /* build alert */
									{
										c = *p2++ = *p++;
										i++;
										if(i >= 20 && c == ' ')
										{
											if(j < 4)
											{
												p2[-1] = '|'; /* separator */
												i = 0;
											}
											j++;            /* next line */
										}
									}
									*p2 = 0;
									if(buf[6] == 2)     /* language */
										cat("][Suivant|Abandon]", buf_alert);
									else
										cat("][Next|Cancel]", buf_alert);
									if(alert_tos(buf_alert) == 1)
										ok = TRUE;
								}
							}
						}
					}
					while(Fsnext() == 0);
				}
#ifndef LWIP
				end_network();
			}
			else
			{
				if(buf[6] == 2)	/* language */
					alert_tos("[3][Ethernet en d‚faut!][Abandon]");
				else	
					alert_tos("[3][Ethernet failure!][Cancel]");			
			}
#endif
		}
		/* if cancel or finished transfer, delete files in the tftp directory */
		if(Fsfirst(path, 1) == 0)
		{
			do
			{
				if((tp_dta.dta_name[0] != '.') && tp_dta.dta_size)
				{
					copy(subdir, name);
					cat(tp_dta.dta_name, name);
					Fattrib(name, 1, 0);
					Fdelete(name);
				}
			}
			while(Fsnext() == 0);
		}
	}
	else if(!nb_files)
		mem_size = 0;
	else
		mem_size = total_size;
	Fsetdta(save_dta);
	lock = 0;
#endif
}

char *disassemble_pc(unsigned long pc)
{
	static char line[80];
#ifdef DBUG
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
	copy(buffer,line);
	cat(": ",line);
	cat(iwordbuf,line);
	copy("       ",buffer);
	n = 0;
	while(opcode[n])
	{
		buffer[n] = opcode[n];
		n++;
	}
	buffer[n++] = ' ';
	buffer[n] = '\0';
	cat(buffer,line);
	cat(operands,line);
#else
	line[0] ='\0';
#endif
	return(line);
}

