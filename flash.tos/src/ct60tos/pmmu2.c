/*  PMMU tree on the CT60.
 *
 *  Didier Mequignon 2002 December, e-mail: aniplay@wanadoo.fr
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

// #define FIRST_PAGE_SDRAM

#define phystop 0x42E
#define cookie  0x5A0
#define ramtop  0x5A4

#define ZONE_EPROM 0x00E00000
#define END_ZONE_EPROM 0x00F00000
#define ZONE_IO 0x00F00000
#define END_ZONE_IO 0x01000000
#define F030_BUS_SLOT 0x00F10000
#define END_F030_BUS_SLOT 0x00FA0000
#define ZONE_CART 0x00FA0000
#define END_ZONE_CART 0x00FC0000
#define F030_UNUSED 0x00FC0000
#define END_F030_UNUSED 0x00FF8000
#define ZONE_SDRAM 0x01000000
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

long init_mmu_tree(void)
{
	unsigned long end_tree,offset,end_stram,end_sdram,srp_reg,tos_in_ram,offset_tos,offset_vectors;
	unsigned long ri,pi,pgi,adr;
	unsigned long *p0,*p1,*p2;
	COOKIE *p;

	tos_in_ram=offset_tos=offset_vectors=0;
	tos_in_ram=(unsigned long)ct60_rw_parameter(CT60_MODE_READ,CT60_PARAM_TOSRAM,tos_in_ram)&1;
	end_sdram=*(unsigned long *)ramtop;
	if(tos_in_ram && end_sdram!=0)              /* copy TOS inside the top of the SDRAM */
	{
		*(unsigned long *)ramtop-=(FLASH_SIZE+PAGESIZE);
		offset_tos=tos_in_ram=end_sdram-FLASH_SIZE;
		p1=(unsigned long *)ZONE_EPROM;           /* source */
		p2=(unsigned long *)tos_in_ram;           /* target */
		adr=(unsigned long)(FLASH_SIZE>>4);       /* size   */
		while(adr>0)
		{ 
			*p2++ = *p1++;
			*p2++ = *p1++;
			*p2++ = *p1++;
			*p2++ = *p1++;
			adr--;	
		} 
		offset_vectors=tos_in_ram=offset_tos-PAGESIZE; 
	}
	else
		tos_in_ram=0;
	if(end_sdram!=0)
		srp_reg = (*(unsigned long *)ramtop)-SIZE_TREE-PAGESIZE;
	else
		srp_reg = (*(unsigned long *)phystop)-SIZE_TREE-PAGESIZE;
	srp_reg += (PAGESIZE-1);
	srp_reg &= ~(PAGESIZE-1);            /* alignment adress on PAGESIZE bytes */
	end_tree=srp_reg+SIZE_TREE;
	p0=(unsigned long *)srp_reg;
	p1=p0+ROOT_TABLE_SIZE;
	p2=p1+(PTR_TABLE_SIZE*NB_32MB);
	end_stram=*(unsigned long *)phystop;
	offset=0;
	if(end_sdram!=0)
		*(unsigned long *)ramtop=srp_reg;
	for(ri=0;ri<ROOT_TABLE_SIZE;ri++)    /* 1st level of the mmu tree => pages 32 MB */
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
					for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)       /* 3rd level of the mmu tree */
					{
						adr = (ri<<25UL) + (pi<<18UL) + (pgi<<13UL);
						if(adr>=srp_reg && adr<end_tree)         /* tree in STRAM */
							*p2++ = offset+(NOCACHE+READONLYBIT+RESIDENT);
						else
#ifdef FIRST_PAGE_SDRAM
					  {						
							if(tos_in_ram && adr==0)               /* vectors in SDRAM */
								*p2++ = offset_vectors+(WRITETHROUGH+RESIDENT);
							else                                   /* STRAM */
								*p2++ = offset+(WRITETHROUGH+RESIDENT);
						}						
#else
							*p2++ = offset+(WRITETHROUGH+RESIDENT);
#endif                                               /* FIRST_PAGE_SDRAM */
						offset+=PAGESIZE;
					}
				}
				else if(adr>=ZONE_EPROM && adr<END_ZONE_EPROM)
				{
					for(pgi=0;pgi<PAGE_TABLE_SIZE;pgi++)       /* 3rd level of the mmu tree */
					{
						adr = (ri<<25UL) + (pi<<18UL) + (pgi<<13UL);
						if(adr<END_ZONE_EPROM-PARAM_SIZE)
						{	
						  if(tos_in_ram)                         /* SDRAM */
						  {	
								*p2++ = offset_tos+(WRITETHROUGH+READONLYBIT+RESIDENT);
								offset_tos+=PAGESIZE;
							}
							else                                   /* flash */
								*p2++ = offset+(WRITETHROUGH+READONLYBIT+RESIDENT);
						}
						else                                     /* flash parameters */
							*p2++ = offset+(NOCACHE+RESIDENT);
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
						else if(adr>=F030_UNUSED && adr<END_F030_UNUSED)
							*p2++ = INVALID;
						else
							*p2++ = offset+(NOCACHE+SUPERBIT+RESIDENT);
						offset+=PAGESIZE;
					}
				}                                            /* SDRAM */
				else if(end_sdram!=0 && adr>=ZONE_SDRAM && adr<end_sdram)
				{
					adr = (ri<<25UL) + (pi<<18UL);
					if(tos_in_ram!=0 && adr>=tos_in_ram)
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
							else                                   /* SDRAM */
								*p2++ = offset+(WRITEBACK+RESIDENT);									
							offset+=PAGESIZE;
						}
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
	if(tos_in_ram!=0)                                  /* copy the vectors inside the top of the SDRAM */
	{ 
		p1=(unsigned long *)0;                           /* source */
		p2=(unsigned long *)offset_vectors;              /* target */
		adr=(unsigned long)(PAGESIZE>>4);                /* size   */
		while(adr>0)
		{ 
			*p2++ = *p1++;
			*p2++ = *p1++;
			*p2++ = *p1++;
			*p2++ = *p1++;
			adr--;	
		}		
	}
	asm(" MOVE.W SR,-(SP)");
	asm(" OR.W #0x700,SR");
	asm(" CPUSHA BC");
	asm(" PFLUSHA");
	asm(" MOVEC.L %0,URP" : : "d" (srp_reg));
	asm(" MOVEC.L %0,SRP" : : "d" (srp_reg));
	asm(" MOVE.L #0x403FE020,D0");    /* zone at 0x40000000 to 0x7FFFFFFF in copyback */
	asm(" MOVEC.L D0,ITT1");
	asm(" MOVEC.L D0,DTT1");
	asm(" MOVE.L #0x807FE040,D0");    /* zone at 0x80000000 to 0xFFFFFFFF in cache inhibed precise */
	asm(" MOVEC.L D0,ITT0");
	asm(" MOVEC.L D0,DTT0");
	asm(" MOVE.L #0xC210,D0");        /* enable, 8Ko, cache inhibed by default */
	asm(" MOVEC.L D0,TC");
	asm(" MOVE.W (SP)+,SR");
	if(tos_in_ram)
	{ 
		p=*(COOKIE **)cookie;
		while(p)
		{
			if(!p->ident)
			{
				*(p+1)=*p;
				p->ident=0x504D4D55;        /* PMMU */
				p->v.l=srp_reg;
				break;
			}
			p++;
		}
	}		
	return(tos_in_ram);
}
