/*
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
 * along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "config.h"
#include <mint/osbind.h>
#include <string.h>
#include "fb.h"
#include "pcixbios.h"

#include "../../include/pci_bios.h"
#include "../../include/vars.h"

#include "dma_utils.h"

extern short use_dma; /* init.c */
extern struct fb_info *info_fvdi; /* fVDI */
extern long *tab_funcs_pci; /* access.S */
extern char *Funcs_allocate_block(long size); /* fVDI */
extern void Funcs_free_block(void *address); /* fVDI */
extern void cpush_dc(void *base, long size);
extern unsigned long swap_long(unsigned long val);
extern void critical_error(int error);


#define DMAMODE0 0x100   /* DMA Channel 0 Mode                  */
#define DMAPADR0 0x104   /* DMA Channel 0 PCI Address           */
#define DMALADR0 0x108   /* DMA Channel 0 Local Address         */
#define DMASIZ0  0x10C   /* DMA Channel 0 Transfer Size (Bytes) */
#define DMADPR0  0x110   /* DMA Channel 0 Descriptor Pointer    */
#define DMASCR0  0x128   /* DMA Channel 0 Command/Status        */

#undef DMA_XBIOS
#define DMA_MALLOC

#ifdef DMA_MALLOC
static unsigned long Descriptors;
#else
static unsigned long Descriptors[2049*4];
#endif

static int dma_run;

int dma_transfer(char *src, char *dest, int size, int width, int src_incr, int dest_incr, int step)
{
	short dir;
	long handle;
	unsigned long direction, mode;
#ifndef DMA_XBIOS
	unsigned char status;
#endif
	PCI_CONV_ADR pci_conv_adr;
	unsigned long offset = (unsigned long)info_fvdi->ram_base;
	if(step);
	if(!use_dma || !size)
		return(-1);
	if(((long)src & 3) || ((long)dest & 3) || (size & 3) || (width & 3))
		return(-1); /* 32 bits only */	
#ifdef DMA_XBIOS
	if(dma_buffoper(-1) != 0)
		return(-1); /* busy */
#else /* direct PCI BIOS (by cookie) */
	if(tab_funcs_pci == NULL) /* table of functions */
		return(-1);
	status = Fast_read_config_byte(0, DMASCR0);
	if((status & 1) && !(status & 0x10)) /* enable & tranfert not complete */
		return(-1); /* busy */
#endif
	if(src >= (char *)info_fvdi->ram_base)
		dir = 1; /* PCI to Local Bus */
	else if(dest >= (char *)info_fvdi->ram_base)
		dir = 2; /* Local Bus To PCI */
	else
		return(-1);
#if 1
	if(dir == 1)
		return(-1); /* memory violation actually */
#endif
	handle = *(long *)info_fvdi->par;
#ifdef PCI_XBIOS
	if(virt_to_bus(handle, (unsigned long)info_fvdi->ram_base, &pci_conv_adr) >= 0)
#else
	if(Virt_to_bus(handle, (unsigned long)info_fvdi->ram_base, &pci_conv_adr) >= 0)
#endif
		offset -= pci_conv_adr.adr;
	else
		return(-1);
#if 0
	{
		extern void display_string(char *s);
		extern void hex_word(short v);
		extern void hex_long(long v);
		extern display_char(char c);
		display_string("dma_transfer ");
		hex_long((long)src);
		display_char(' ');
		hex_long((long)dest);
		display_char(' ');
		hex_long((long)size);
		display_char(' ');
		hex_word((short)width);
		display_char(' ');
		hex_word((short)src_incr);
		display_char(' ');
		hex_word((short)dest_incr);
		display_char(' ');
		hex_word((short)step);
		display_string("\r\n");
	}
#endif
	if(dir == 1)
  	src -= offset; /* PCI mapping local -> offset PCI */
	else
	{
		char *temp = src;
		int temp_incr = src_incr;
  	dest -= offset; /* PCI mapping local -> offset PCI */
  	src = dest;     /* swap src / dest */
  	dest = temp;
  	src_incr = dest_incr;  /* swap src_incr / dest_incr */
  	dest_incr = temp_incr;
  }
	direction = (dir == 1) ? 0 : 8;
	if((width || src_incr || dest_incr) && (size > width)) /* line by line */
	{
#ifdef DMA_XBIOS
		if(tab_funcs_pci == NULL) /* table of functions */
			return(-1);
#endif
#ifdef DMA_MALLOC
		Descriptors = (unsigned long)Funcs_allocate_block(((size / width) + 2) * 16); /* descriptor / line */
		if(Descriptors)
#endif
		{
#ifdef DMA_MALLOC
			unsigned long *aligned_descriptors = (unsigned long *)((Descriptors + 15) & ~15); /* 16 bytes alignment */
#else
			unsigned long *aligned_descriptors = (unsigned long *)(((unsigned long)&Descriptors[0] + 15) & ~15); /* 16 bytes alignment */
			unsigned long phys_ramtop = (*(unsigned long *)ramtop & 0xFF000000) + 0x1000000;
			unsigned long mmu_offset = PCI_DRIVERS_OFFSET - (phys_ramtop - PCI_DRIVERS_SIZE);
#endif
			unsigned long *p = aligned_descriptors;
			while(size > 0)
			{
#if 1 /* to fix: test bridge endian */
				*p++ = swap_long((unsigned long)src);   /* PCI address */
				*p++ = swap_long((unsigned long)dest);  /* local address */
				*p++ = swap_long((unsigned long)width); /* transfer size */
				size -= width;
				if(size > 0)
				{
#ifdef DMA_MALLOC
					*p = swap_long((unsigned long)&p[1] + direction); /* next descriptor pointer */
#else
					*p = swap_long((unsigned long)&p[1] + direction - mmu_offset); /* next descriptor pointer */
#endif
					p++;
				}
				else
					*p++ = swap_long(direction + 2); /* next descriptor pointer = end of chain */
#else /* no swap */
				*p++ = (unsigned long)src;   /* PCI address */
				*p++ = (unsigned long)dest;  /* local address */
				*p++ = (unsigned long)width; /* transfer size */
				size -= width;
				if(size > 0)
				{
#ifdef DMA_MALLOC
					*p = (unsigned long)&p[1] + direction; /* next descriptor pointer */
#else
					*p = (unsigned long)&p[1] + direction - mmu_offset; /* next descriptor pointer */
#endif
					p++;
				}
				else
					*p++ = direction + 2; /* next descriptor pointer = end of chain */
#endif
				src += src_incr;
				dest += dest_incr;
			}
			if(dir == 2) /* Local Bus To PCI */
				asm volatile (" cpusha DC\n\t"); /* descriptors and blocks to flush => flush all data cache */
			else /* just descriptors to flush */
#ifdef DMA_MALLOC
				cpush_dc(aligned_descriptors, (long)p - (long)aligned_descriptors); /* flush data cache */
#else
				cpush_dc((void *)(unsigned long)aligned_descriptors - mmu_offset, (long)p - (long)aligned_descriptors); /* flush data cache (physical address) */
#endif
			mode = Fast_read_config_longword(0, DMAMODE0); 
//			mode |= 0x10200;                 /* scatter/gather mode */
			mode |= 0x200;                   /* scatter/gather mode */
			Write_config_longword(0, DMAMODE0, mode);
			/* load the 1st descriptor in the PLX registers */
#ifdef DMA_MALLOC
			Write_config_longword(0, DMADPR0, (unsigned long)aligned_descriptors); /* initial descriptor block */
#else
			Write_config_longword(0, DMADPR0, (unsigned long)aligned_descriptors - mmu_offset); /* initial descriptor block */
#endif
			Write_config_byte(0, DMASCR0, 3); /* start & enable */
			dma_run = 1;
//			while(*(volatile unsigned long *)&p[-2]); /* wait last transfert size cleared by DMA clear count mode */
//			if(dir == 2) /* else black screen and crash, why ??? */
//				wait_dma();	
//			if(dir == 1) /* PCI to Local Bus */
				wait_dma(); /* need wait if there are an Mfree before DMA finished */
		}
#ifdef DMA_MALLOC
		else /* no memory block for descriptors */
			return(-1);
#endif
	}
	else /* full block */
	{
		if(dir == 2) /* Local Bus To PCI */
			cpush_dc(dest, size); /* flush data cache */
#ifdef DMA_XBIOS
		dma_setbuffer(src, dest, size);
		dma_buffoper(dir);
#else /* direct PCI BIOS (by cookie) */
		mode = Fast_read_config_longword(0, DMAMODE0); 
		mode &= ~0x200;                  /* block mode */
		Write_config_longword(0, DMAMODE0, mode);
		Write_config_longword(0, DMAPADR0, (unsigned long)src);  /* PCI Address */
		Write_config_longword(0, DMALADR0, (unsigned long)dest); /* Local Address */
		Write_config_longword(0, DMASIZ0, (unsigned long)size);  /* Transfer Size (Bytes) */
		Write_config_longword(0, DMADPR0, (unsigned long)direction); /* Descriptor Pointer */
		Write_config_byte(0, DMASCR0, 3); /* start & enable */
#endif
		dma_run = 1;
		if(dir == 1) /* PCI to Local Bus */
			wait_dma(); /* need wait if there are an Mfree before DMA finished */
	}
	return(0);
}

int dma_status(void)
{
	if(!use_dma)
		return(-1);
#ifdef DMA_XBIOS
	return(dma_buffoper(-1));
#else /* direct PCI BIOS (by cookie) */
	else
	{
		unsigned char status = Fast_read_config_byte(0, DMASCR0);
		if((status & 1) && !(status & 0x10)) /* enable & tranfert not complete */
			return(1); /* buzy */
	}
	return(0);
#endif
}

void wait_dma(void)
{
	if(!dma_run)
		return; /* faster */
	if(use_dma)
	{
		unsigned long start_timer = *(volatile unsigned long *)_hz_200;
		while(dma_status() > 0)
		{
			if((*(volatile unsigned long *)_hz_200 - start_timer) >= 200) /* 1S timeout */
			{
#ifdef DMA_XBIOS
				dma_buffoper(0);
#else
				Write_config_byte(0, DMASCR0, 4); /* abort */
#endif
//				critical_error(-1);
				use_dma = 0;
				break;			
			}
		}
	}
#ifdef DMA_MALLOC
	if(Descriptors)
	{
		Funcs_free_block((void *)Descriptors);
		Descriptors = 0;
	}
#endif /* DMA_MALLOC */
	dma_run = 0;
}

