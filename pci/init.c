/* TOS 4.04 PCI init for the CT60/CTPCI boards
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
#include "mod_devicetable.h"

#define DEBUG

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

#ifdef TEST_NOPCI
extern struct mode_option resolution;
extern short virtual;
extern short Modecode;
extern void init_var_linea(void);
COOKIE pci;
#endif

extern Virtual *init_var_fvdi(void);
extern void det_xbios(void);
extern void init_det_vdi(Virtual *vwk);
extern void det_vdi(void);
extern long init(Access *access, Driver *driver, Virtual *vwk, char *opts);
extern COOKIE *get_cookie(long id);
extern int add_cookie(COOKIE *cook);
extern int eddi_cookie(int);
extern long initialize_pool(long size, long n);

/* global */
extern struct pci_device_id radeonfb_pci_table[];
Access _access_;            /* fVDI */
extern struct radeonfb_info *rinfo_fvdi;
extern long blocks;
extern long block_size;
Virtual *base_vwk;
long old_vector_xbios,old_vector_vdi;
short video_found,usb_found,ata_found;
COOKIE eddi;

/* some functions */

long length(const char *text)
{
	long length=0;
	while(*text++)
		length++;
	return(length);
}

void copy(const char *src, char *dest)
{
	while(*src)
		*dest++ = *src++;
}

void cat(const char *src, char *dest)
{
	while(*dest++);
	dest--;
	while(*src)
		*dest++ = *src++;
}

void _memset(char *p, char fill, long size)
{
	while(size--)
		*p++ = fill;
}

void _memcpy(void *d, void *s, long n)
{
	char *src, *dest;
	src = (char *)s;
	dest = (char *)d;
	for(n = n - 1; n >= 0; n--)
		*dest++ = *src++;
}

void ltoa(char *buf, long n, unsigned long base)
{
	unsigned long un;
	char *tmp, ch;
	un = n;
	if((base == 10) && (n < 0))
	{
		*buf++ = '-';
		un = -n;
	}
	tmp = buf;
	do
	{
		ch = un % base;
		un = un / base;
		if(ch <= 9)
			ch += '0';
		else
			ch += 'a' - 10;
		*tmp++ = ch;
	}
	while(un);
	*tmp = '\0';
	while(tmp > buf)
	{
		ch = *buf;
		*buf++ = *--tmp;
		*tmp = ch;
	}
}

void display_atari_logo(void)
{
	struct fb_info *info;
	unsigned short *logo_atari, *ptr16;
	long base_adr;
	unsigned char *ptr8;
	int i,j,k;
	unsigned short val,color,r,g,b;
	logo_atari = (unsigned short *)0xE49434; /* logo ATARI inside TOS 4.04 */			
	base_adr = (long)Physbase();
	info = rinfo_fvdi->info;
	base_adr += ((info->var.xres * (info->var.bits_per_pixel / 8))*4);
	g=0;
	for(i=0;i<86;i++)
	{
		ptr8 = (unsigned char *)base_adr;
		ptr16 = (unsigned short *)base_adr;
		if(i<56)
		{
			r = (unsigned short)((63-i)>>1)&0x1F;
			if(i<28)
				g++;
			else
				g--;
			b = (unsigned short)(i>>1)&0x1F;
			color = (r<<11) + (g<<6) + b;
		}
		else
			color = 0;
		for(j=0;j<6;j++)
		{
			switch(info->var.bits_per_pixel)
			{
				case 8:
					val = *logo_atari++;
					for(k=0x8000;k;k>>=1)
					{
						if(val & k)
							*ptr8++ = 0xFF;
						else
							*ptr8++ = 0; 
					}		
					break; 
				case 16:
					val = *logo_atari++;
					for(k=0x8000;k;k>>=1)
					{
						if(val & k)
							*ptr16++ = color;
						else
							*ptr16++ = 0xFFFF;
					}					
					break;
				default:
						break;
		  }
		}
		base_adr += (info->var.xres * (info->var.bits_per_pixel / 8));
	}
}

/* Init TOS call is here ... */

void init_devices(void) /* after the original setscreen with the modecode from NVRAM */
{
	unsigned long temp;
	short index,modecode;
	long handle,err;
	struct pci_device_id *radeon;
	access=&_access_;
	base_vwk=init_var_fvdi();
#ifdef DEBUG
	debug=1;
#else
	debug=0;
#endif	
	video_found=usb_found=ata_found=0;
#ifdef TEST_NOPCI
	Cconws("\rTest fVDI (y/n)");
	if((Cconin()&0xFF) != 'y')
	{
		Cconout(27);
		Cconout('E');
		return;
	}
	video_found=1;
	virtual=0;
	if(temp || index || handle || radeon || err);
#else
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
			/* test USB device */
			if(err>=0 && !usb_found)
			{
				if(read_config_longword(handle,PCIREV,&temp)>=0
				 && ((temp>>16) == PCI_CLASS_SERIAL_USB))
				{
      		
      		
      		usb_found=1;
      	}
			}

			/* test ATA device */
			if(err>=0 && !ata_found)
			{
      	if(temp==0x12345678)  /* device / vendor */
      		ata_found=1;	
			}
		}    
	}
	while(handle>=0);
#endif
	old_vector_xbios=0;
	if(video_found)
	{
		modecode=Vsetmode(-1);
		Vsetscreen(0,0,2,0);  /* for reduce F030 bus load */
#ifdef TEST_NOPCI
		struct fb_info *info;
		Modecode=modecode=VERTFLAG|VGA|BPS16;
		resolution.width=320;
		resolution.height=240;
		resolution.bpp=16;
		resolution.freq=60;
		resolution.used=1;
		info=framebuffer_alloc(sizeof(struct radeonfb_info));
		if(!info)
			return;
		rinfo_fvdi=info->par;
		rinfo_fvdi->info=info;
		info->var.xres=info->var.xres_virtual=resolution.width;
		info->var.yres=info->var.yres_virtual=resolution.height;
		info->var.bits_per_pixel=rinfo_fvdi->bpp=resolution.bpp;
		copy("Test without PCI ",rinfo_fvdi->name);
		pci.ident='_PCI';
		pci.v.l=0;
		add_cookie(&pci); /* for TOS call init_with_sdram() */		
#else
		old_vector_xbios=(long)Setexc(46,(void(*)())det_xbios); /* TRAP #14 */
#endif
		if((modecode & NUMCOLS) < BPS8 || (modecode & NUMCOLS) > BPS16)
		{
			modecode &= (VERTFLAG|PAL|VGA|COL80);
      modecode |= BPS8;
		}				
		if(modecode & VGA)
		{
			if(modecode & COL80)
				modecode &= ~VERTFLAG;
			else
				modecode |= VERTFLAG;
		}
		else
		{
			if(modecode & COL80)
				modecode |= VERTFLAG;
			else
				modecode &= ~VERTFLAG;
		} 
		Vsetscreen(0,0,3,modecode);
		display_atari_logo();
	}
}

void init_with_sdram(void) /* before booting, after the SDRAM init and the PCI devices list */
{
	if(video_found && initialize_pool(block_size,blocks)
	 && init(access,base_vwk->real_address->driver,base_vwk,""))
	{
		init_det_vdi(base_vwk->real_address->driver->default_vwk);
		old_vector_vdi=0;
		old_vector_vdi=(long)Setexc(34,(void(*)())det_vdi); /* TRAP #2 */
		eddi.ident='EdDI';
		eddi.v.l=(long)&eddi_cookie;
		add_cookie(&eddi); /* infos about screen with vq_scrninfo() */		
	}
	if(ata_found)
	{
		if(!old_vector_xbios)
			old_vector_xbios=(long)Setexc(46,(void(*)())det_xbios); /* TRAP #14 */

	}
}

