/*  PMMU tree on the CT60 / MMU on Coldfire
 *
 *  Didier Mequignon 2002-2012, e-mail: aniplay@wanadoo.fr
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 * 
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <mint/osbind.h>
#include "main.h"
#include "ct60.h"
#include "pci_bios.h"
#include "vars.h"

#undef DEBUG

#define ZONE_EPROM 0x00E00000
#define END_ZONE_EPROM 0x00F00000
#define ZONE_IO 0x00F00000
#define END_ZONE_IO 0x01000000
#define F030_BUS_SLOT 0x00F10000
#define END_F030_BUS_SLOT 0x00FA0000
#define ZONE_CART 0x00FA0000
#define END_ZONE_CART 0x00FC0000
#define ZONE_EPROM2 0x00FC0000
#define END_ZONE_EPROM2 0x00FF0000
#define F030_UNUSED 0x00FF0000
#define END_F030_UNUSED 0x00FF8000
#define FIREBEE_UNIMPLEMENTED 0x00FF8C00
#define END_FIREBEE_UNIMPLEMENTED 0x00FF9000
#define FIREBEE_UNIMPLEMENTED2 0x00FFA000
#define END_FIREBEE_UNIMPLEMENTED2 0x00FFF800
#define ZONE_SDRAM 0x01000000


#define NO_CACHE_MEMORY_SIZE 0x00080000

#define GLOBALBIT    0x400
#define SUPERBIT      0x80
#define CACHEMODEBITS 0x60
#define WRITETHROUGH  0x00
#define WRITEBACK     0x20
#define NOCACHE       0x40
#define READONLYBIT   0x04
#define PAGETYPEBITS  0x03
#define INVALID       0x00
#define RESIDENT      0x01
#define PROTECTIONBITS  (SUPERBIT | READONLYBIT | PAGETYPEBITS)

/* Translation control register */
#define TC_ENABLE 0x8000
#define TC_PAGE8K 0x4000
#define TC_PAGE4K 0x0000

/* Transparent translation registers */
#define TTR_ENABLE  0x8000    /* enable transparent translation */
#define TTR_ANYMODE 0x4000    /* user and kernel mode access */
#define TTR_KERNELMODE  0x2000    /* only kernel mode access */
#define TTR_USERMODE    0x0000    /* only user mode access */
#define TTR_CI      0x0400    /* inhibit cache */
#define TTR_RW      0x0200    /* read/write mode */
#define TTR_RWM     0x0100    /* read/write mask */
#define TTR_FCB2    0x0040    /* function code base bit 2 */
#define TTR_FCB1    0x0020    /* function code base bit 1 */
#define TTR_FCB0    0x0010    /* function code base bit 0 */
#define TTR_FCM2    0x0004    /* function code mask bit 2 */
#define TTR_FCM1    0x0002    /* function code mask bit 1 */
#define TTR_FCM0    0x0001    /* function code mask bit 0 */

#define NB_32MB 17            /* 512MB/32 + 1 */

#define PAGESIZE 8192
#define ROOT_TABLE_SIZE 128
#define PTR_TABLE_SIZE 128
#define PAGE_TABLE_SIZE 32
#define SIZE_LEVEL1 (ROOT_TABLE_SIZE*4)
#define SIZE_LEVEL2 (PTR_TABLE_SIZE*NB_32MB*4)
#define SIZE_LEVEL3 (PTR_TABLE_SIZE*NB_32MB*PAGE_TABLE_SIZE*4)
#define SIZE_TREE ((SIZE_LEVEL1+SIZE_LEVEL2+SIZE_LEVEL3+PAGESIZE-1) & ~(PAGESIZE-1))
#define SIZE_PROT (65536L+SIZE_TREE+PAGESIZE)

extern void apply_patches(char *src, char *dest);



void init_mmu_tree(unsigned long base_pci_drivers, unsigned long size_pci_drivers)
{
	unsigned long end_tree,offset,end_stram,end_sdram,srp_reg,tos_in_ram,offset_tos,offset_drivers,no_cache_memory;
	unsigned long ri,pi,pgi,adr,size;
	unsigned long *p0,*p1,*p2;

	tos_in_ram=offset_tos=offset_drivers=no_cache_memory=0;
	end_stram=*(unsigned long *)phystop;        /* save phystop before change if PMMU tree in STRAM */
	end_sdram=*(unsigned long *)ramtop;         /* save ramtop before change if PMMU tree in SDRAM */
	if(end_sdram)                               /* copy TOS inside the top of the SDRAM */
	{
		if(base_pci_drivers)                      /* 2 parts are possible */
		{
			(*(unsigned long *)ramtop)-=(FLASH_SIZE+END_ZONE_EPROM2-ZONE_EPROM2+PCI_DRIVERS_SIZE);
			offset_tos=tos_in_ram=end_sdram-FLASH_SIZE-(END_ZONE_EPROM2-ZONE_EPROM2+PCI_DRIVERS_SIZE);
			offset_drivers=end_sdram-PCI_DRIVERS_SIZE;
		}
		else
		{
			(*(unsigned long *)ramtop)-=(FLASH_SIZE+PAGESIZE);
			offset_tos=tos_in_ram=end_sdram-FLASH_SIZE;
		}
		apply_patches((char *)ZONE_EPROM,(char *)tos_in_ram); /* 512KB original TOS */
		p1=(unsigned long *)(ZONE_EPROM+(FLASH_SIZE>>1)); /* source */
		p2=(unsigned long *)(tos_in_ram+(FLASH_SIZE>>1)); /* target */
		if(base_pci_drivers)
			size=((base_pci_drivers-ZONE_EPROM)-(FLASH_SIZE>>1))>>4;  /* size */
		else		
			size=FLASH_SIZE>>5;                     /* size   */
		while((long)size > 0)
		{ 
			*p2++ = *p1++;                          /* copy boot TOS */
			*p2++ = *p1++;
			*p2++ = *p1++;
			*p2++ = *p1++;
			size--;	
		} 
		if(base_pci_drivers)
		{
			p1 = (unsigned long *)ZONE_SDRAM;       /* source uncompressed */
			if(size_pci_drivers <= (END_ZONE_EPROM - base_pci_drivers))
			{
				size_pci_drivers+=15;
				size_pci_drivers>>=4;
				while((long)size_pci_drivers > 0)
				{
					*p2++ = *p1++;                      /* copy uncompressed PCI drivers */
					*p2++ = *p1++;
					*p2++ = *p1++;
					*p2++ = *p1++;
					size_pci_drivers--;
				}
				size = (FLASH_SIZE + tos_in_ram - (unsigned long)p2) >> 4;
				while((long)size > 0)
				{
					*p2++ = 0xFFFFFFFF;
					*p2++ = 0xFFFFFFFF;
					*p2++ = 0xFFFFFFFF;
					*p2++ = 0xFFFFFFFF;
					size--;
				}
			}
			else /* 2 parts */
			{
				size_pci_drivers -= (END_ZONE_EPROM - base_pci_drivers);
				size = (END_ZONE_EPROM - base_pci_drivers) >> 4; 
				while((long)size > 0)
				{
					*p2++ = *p1++;                      /* copy uncompressed PCI drivers */
					*p2++ = *p1++;
					*p2++ = *p1++;
					*p2++ = *p1++;
					size--;
				}
				size_pci_drivers+=15;
				size_pci_drivers>>=4;
				while((long)size_pci_drivers > 0)
				{
					*p2++ = *p1++;                      /* copy uncompressed PCI drivers */
					*p2++ = *p1++;
					*p2++ = *p1++;
					*p2++ = *p1++;
					size_pci_drivers--;
				}
				size = (END_ZONE_EPROM2 - ZONE_EPROM2 + FLASH_SIZE + tos_in_ram - (unsigned long)p2) >> 4;
				while((long)size > 0)
				{
					*p2++ = 0xFFFFFFFF;
					*p2++ = 0xFFFFFFFF;
					*p2++ = 0xFFFFFFFF;
					*p2++ = 0xFFFFFFFF;
					size--;
				}
			}
		}
		srp_reg = (*(unsigned long *)ramtop)-SIZE_TREE-PAGESIZE;
	}
	else /* STRAM only, copy TOS inside the top of the STRAM */
	{
		(*(unsigned long *)phystop)-=(FLASH_SIZE+PAGESIZE);
		offset_tos=tos_in_ram=end_stram-FLASH_SIZE;
		apply_patches((char *)ZONE_EPROM,(char *)tos_in_ram); /* 512KB original TOS */
		p1=(unsigned long *)(ZONE_EPROM+(FLASH_SIZE>>1)); /* source */
		p2=(unsigned long *)(tos_in_ram+(FLASH_SIZE>>1)); /* target */
		size=FLASH_SIZE>>5;                       /* 2nd part for boot */
		while((long)size > 0)
		{ 
			*p2++ = *p1++;                          /* copy boot TOS */
			*p2++ = *p1++;
			*p2++ = *p1++;
			*p2++ = *p1++;
			size--;	
		} 
		srp_reg = (*(unsigned long *)phystop)-SIZE_TREE-PAGESIZE;
	}
	srp_reg += (PAGESIZE-1);
	srp_reg &= ~(PAGESIZE-1);                   /* alignment adress on PAGESIZE bytes */
	end_tree=srp_reg+SIZE_TREE;
	p0=(unsigned long *)srp_reg;
	p1=p0+ROOT_TABLE_SIZE;
	p2=p1+(PTR_TABLE_SIZE*NB_32MB);
	offset=0;
	if(end_sdram)
	{
		if(base_pci_drivers)
			*(unsigned long *)ramtop=no_cache_memory=(srp_reg&~(NO_CACHE_MEMORY_SIZE-1))-NO_CACHE_MEMORY_SIZE;
		else
			*(unsigned long *)ramtop=srp_reg;
	}
	else
		*(unsigned long *)phystop=srp_reg;
	for(ri=0;ri<ROOT_TABLE_SIZE;ri++)           /* 1st level of the mmu tree => pages 32 MB */
	{
		if(ri<NB_32MB)
		{
			*p0++ = (unsigned long)p1+PAGETYPEBITS;
			for(pi=0;pi<PTR_TABLE_SIZE;pi++)               /* 2nd level of the mmu tree => pages 256 KB */
			{
				*p1++ = (unsigned long)p2+PAGETYPEBITS;
				adr = (ri<<25UL) + (pi<<18UL);
				if(adr<end_stram)
				{
					if(!end_sdram && adr>=tos_in_ram)
					{
						for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)     /* 3rd level of the mmu tree */
						{
							*p2++ = INVALID;
							offset+=PAGESIZE;
						}
					}
					else
					{
						for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)       /* 3rd level of the mmu tree */
						{
							adr = (ri<<25UL) + (pi<<18UL) + (pgi<<13UL);
							if(adr>=srp_reg && adr<end_tree)         /* tree in STRAM */
								*p2++ = offset+(NOCACHE+READONLYBIT+RESIDENT);
							else
								*p2++ = offset+(WRITETHROUGH+RESIDENT);
							offset+=PAGESIZE;
						}
					}
				}
				else if(adr>=end_stram && adr<ZONE_EPROM)
				{
					for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)     /* 3rd level of the mmu tree */
					{
						*p2++ = offset+(NOCACHE+RESIDENT);     /* board with 4MB STRAM ? */
						offset+=PAGESIZE;
					}
				}
				else if(adr>=ZONE_EPROM && adr<END_ZONE_EPROM)
				{
					for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)     /* 3rd level of the mmu tree */
					{
						*p2++ = offset_tos+(WRITETHROUGH+READONLYBIT+RESIDENT);  /* TOS copied in SDRAM or STRAM */
						offset_tos+=PAGESIZE;
						offset+=PAGESIZE;
					}
				}
				else if(adr>=ZONE_IO && adr<END_ZONE_IO)
				{
					for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)       /* 3rd level of the mmu tree */
					{
						adr = (ri<<25UL) + (pi<<18UL) + (pgi<<13UL);
						if(adr>=F030_BUS_SLOT && adr<END_F030_BUS_SLOT)
							*p2++ = offset+(NOCACHE+RESIDENT);
						else if(adr>=ZONE_CART && adr<END_ZONE_CART)
							*p2++ = offset+(NOCACHE+READONLYBIT+RESIDENT);
						else if(adr>=ZONE_EPROM2 && adr<END_ZONE_EPROM2)
						{
							if(end_sdram)                          /* SDRAM => TOS 2nd part */
							{	
								*p2++ = offset_tos+(WRITETHROUGH+READONLYBIT+RESIDENT);
								offset_tos+=PAGESIZE;
							}
							else                                   /* STRAM => no 2nd part */
								*p2++ = INVALID;
						}				
						else if(adr>=F030_UNUSED && adr<END_F030_UNUSED)
							*p2++ = INVALID;
						else
							*p2++ = offset+(NOCACHE+SUPERBIT+RESIDENT);
						offset+=PAGESIZE;
					}
				}                                            /* SDRAM */
				else if(end_sdram && adr>=ZONE_SDRAM && adr<end_sdram)
				{
					if(adr>=tos_in_ram)
					{
						for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)     /* 3rd level of the mmu tree */
						{
							*p2++ = INVALID;
							offset+=PAGESIZE;
						}
					}
					else
					{				
						for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)     /* 3rd level of the mmu tree */
						{
							adr = (ri<<25UL) + (pi<<18UL) + (pgi<<13UL);
							if(adr>=srp_reg && adr<end_tree)       /* tree in SDRAM */
								*p2++ = offset+(NOCACHE+READONLYBIT+RESIDENT);
							else if(base_pci_drivers && adr>=no_cache_memory) 
								*p2++ = offset+(NOCACHE+RESIDENT);	 /* SDRAM without cache */								
//								*p2++ = offset+(WRITETHROUGH+RESIDENT);	/* SDRAM in WT */			
							else                                   /* SDRAM */
								*p2++ = offset+(WRITEBACK+RESIDENT);									
							offset+=PAGESIZE;
						}
					}
				}                                            /* SDRAM */
				else if(end_sdram && adr>=PCI_DRIVERS_OFFSET && adr<PCI_DRIVERS_OFFSET+PCI_DRIVERS_SIZE)
				{
					for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)       /* 3rd level of the mmu tree */
					{
						adr = (ri<<25UL) + (pi<<18UL) + (pgi<<13UL);
						if(adr>=PCI_DRIVERS_OFFSET && adr<PCI_DRIVERS_OFFSET+PCI_DRIVERS_SIZE)
						{
							*p2++ = offset_drivers+(WRITEBACK+RESIDENT); /* SDRAM for PCI drivers */
							offset_drivers+=PAGESIZE;
						}
						else
							*p2++ = INVALID;
						offset+=PAGESIZE;
					}					
				}
				else
				{
					for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)       /* 3rd level of the mmu tree */
					{
						*p2++ = INVALID;
						offset+=PAGESIZE;
					}
				}
			}
		}
		else
			*p0++ = (unsigned long)INVALID;                /* bits of TC by default */
	}
	asm volatile (
		" MOVE.W SR,-(SP)\n\t"
		" OR.W #0x700,SR\n\t"
		" CPUSHA BC\n\t"
		" PFLUSHA\n\t"
		" MOVEC.L %0,URP" : : "d" (srp_reg) );
	asm volatile (" MOVEC.L %0,SRP" : : "d" (srp_reg) );
//	asm volatile (" MOVE.L #0x401FE020,D0");    /* zone at 0x40000000 to 0x5FFFFFFF in copyback */
//	asm volatile (" MOVE.L #0x401FE000,D0");    /* zone at 0x40000000 to 0x5FFFFFFF in writethrough */
//	asm volatile (" MOVE.L #0x401FE040,D0");    /* zone at 0x40000000 to 0x5FFFFFFF in cache inhibed precise */
#if 1
	asm volatile (
		" MOVE.L #0x403FE040,D0\n\t"    /* zone at 0x40000000 to 0x7FFFFFFF in cache inhibed precise */
		" MOVEC.L D0,ITT1\n\t"
		" MOVEC.L D0,DTT1\n\t"
		" MOVE.L #0x807FE040,D0" );    /* zone at 0x80000000 to 0xFFFFFFFF in cache inhibed precise */
#else
	asm volatile (
		" MOVE.L #0xE00FE044,D0\n\t"    /* zone at 0xE0000000 to 0xEFFFFFFF in cache inhibed precise + write protect */
		" MOVEC.L D0,ITT1\n\t"
		" MOVEC.L D0,DTT1\n\t"
		" MOVE.L #0xF00FE040,D0" );    /* zone at 0xF0000000 to 0xFFFFFFFF in cache inhibed precise */
#endif
	asm volatile (
		" MOVEC.L D0,ITT0\n\t"
		" MOVEC.L D0,DTT0\n\t"
		" MOVE.L #0xC210,D0\n\t"        /* enable, 8Ko, cache inhibed by default */
		" MOVEC.L D0,TC\n\t"
		" MOVE.W (SP)+,SR" );
}

