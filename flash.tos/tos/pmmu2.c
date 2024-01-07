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

#ifdef COLDFIRE

#ifdef MCF5445X
#define NO_CACHE_MEMORY_BASE 0x40F00000
#else
#define NO_CACHE_MEMORY_BASE 0x00F10000
#define NO_CACHE_MEMORY_SIZE 0x00090000
#endif

#define ZONE_IO_MCF5445X MCF_SCM_MPR
#define END_ZONE_IO_MCF5445X (MCF_PLL_PCR+0x4000)
#define ZONE_IDE_MCF5445X MCF_ATA_TIME_OFF
#define ZONE1_SRAM 0xFFF00000     /* MCF5445X */
#define ZONE2_SRAM 0xFFFFE000     /* MCF5445X */

#define VIDEO_RAM          0x00D00000 /* FIREBEE */
#define END_VIDEO_RAM      0x00E00000 /* FIREBEE */
#define VIDEO_RAM2         0x60000000 /* FIREBEE */
#define END_VIDEO_RAM2     0x80000000 /* FIREBEE */
#define FPGA_VIDEO_RAM     0x60D00000 /* FIREBEE */
#define END_FPGA_VIDEO_RAM 0x60E00000 /* FIREBEE */
#define FPGA_ACP_IO        0xF0000000 /* FIREBEE */
#define END_FPGA_ACP_IO    0xF8000000 /* FIREBEE */
#define FPGA_SRAM          0xF8000000 /* FIREBEE */
#define END_FPGA_SRAM      0xFC000000 /* FIREBEE */
#define FPGA_ZONE_IO       0xFFF00000 /* FIREBEE - ATARI I/O */

#define MMUCR (*(volatile unsigned long *)(MMU_BASE+0x0000))
#define MMUOR (*(volatile unsigned long *)(MMU_BASE+0x0004))
#define MMUSR (*(volatile unsigned long *)(MMU_BASE+0x0008))
#define MMUAR (*(volatile unsigned long *)(MMU_BASE+0x0010))
#define MMUTR (*(volatile unsigned long *)(MMU_BASE+0x0014))
#define MMUDR (*(volatile unsigned long *)(MMU_BASE+0x0018))

#define MMUCR_EN           0x01

#define MMUOR_STLB        0x100
#define MMUOR_CA           0x80
#define MMUOR_CNL          0x40
#define MMUOR_CAS          0x20
#define MMUOR_ITLB         0x10
#define MMUOR_ADR          0x08
#define MMUOR_RW           0x04
#define MMUOR_ACC          0x02
#define MMUOR_UAA          0x01

#define MMUTR_SG           0x02
#define MMUTR_V            0x01

#define MMUDR_SZ1M        0x000
#define MMUDR_SZ4K        0x100
#define MMUDR_SZ8K        0x200
#define MMUDR_SZ1K        0x300
#define MMUDR_WRITETHROUGH 0x00
#define MMUDR_WRITEBACK    0x40
#define MMUDR_NOCACHE      0x80
#define MMUDR_SP           0x20
#define MMUDR_R            0x10
#define MMUDR_W            0x08
#define MMUDR_X            0x04
#define MMUDR_LK           0x02

#define MMUSR_HITN         0x02

#define PAGE_SIZE          1024
#define MMUDR_PAGE         MMUDR_SZ1K
#define PAGE_SIZE_1M       0x100000

#define mmu_map(virt_addr,phys_addr,flag_itlb,flags_mmutr,flags_mmudr) \
do { \
	MMUAR = virt_addr+1; \
	MMUOR = MMUOR_STLB + MMUOR_ADR + flag_itlb; \
	MMUTR = virt_addr + flags_mmutr + MMUTR_V; \
	MMUDR = phys_addr + flags_mmudr; \
	MMUOR = MMUOR_ACC + MMUOR_UAA + flag_itlb; \
} while(0)

#define mmu_remap(virt_addr,phys_addr,flag_itlb,flags_mmutr,flags_mmudr) \
do { \
	MMUTR = virt_addr + flags_mmutr + MMUTR_V; \
	MMUDR = phys_addr + flags_mmudr; \
	MMUOR = MMUOR_ACC + MMUOR_UAA + flag_itlb; \
} while(0)

#define mmu_unmap(virt_addr,flag_itlb) \
do { \
  MMUAR = virt_addr+1; \
  MMUOR = MMUOR_STLB + MMUOR_ADR + flag_itlb; \
  if(MMUSR & MMUSR_HITN) { \
    MMUOR = MMUOR_RW + MMUOR_ACC + flag_itlb; \
    if(MMUSR); \
    MMUTR = 0; \
    MMUDR = 0; \
    MMUOR = MMUOR_ACC + MMUOR_UAA + flag_itlb; \
  } \
} while(0)

#define mmu_flush() (MMUOR = MMUOR_CNL)

#ifdef DEBUG
#define conout(ascii) \
do { \
	while(!(*(volatile unsigned char *)MCF_UART_USR0 & MCF_UART_USR_TXRDY)); \
	*(volatile unsigned char *)MCF_UART_UTB0 = (unsigned char)ascii; \
} while(0)
#endif

#else /* ATARI - 68060 */

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

#endif

#ifdef COLDFIRE

void update_mmu(void) // MMU access fault
{
	unsigned long format, pc, addr;
	asm volatile (
		".global _update_tlb\n\t"
		"_update_tlb:\n\t"
		" MOVE.W #0x2700,SR\n\t"
		" LEA -32(SP),SP\n\t"        /* + reserve space for jump to old vector */
		" MOVEM.L D0-D5/A0,(SP)\n\t" /* normally it's enough !!! */
		" MOVE.L 32(SP),%0" : "=d" (format) : );
	asm volatile (" MOVE.L 36(SP),%0\n\t" : "=d" (pc) : );
	unsigned long MMU_BASE = (unsigned long)__MMU_BASE;
	format >>= 16;
	switch(format & 0x0C03)
  {
		case 0x0402: /* 6: TLB miss on ext word instruction */
			pc += 4;
		case 0x0401: /* 5: TLB miss on opword instruction */
			addr = pc & ~(PAGE_SIZE_1M-1);
			if((addr < END_ZONE_EPROM) /* STRAM & TOS (1st part) */
			 || ((addr >= ZONE_SDRAM) && (addr < SDRAM_SIZE))
#ifdef MCF5445X
			)
				mmu_remap(addr,addr+PHYSICAL_OFFSET_SDRAM,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_X);
#else /* MCF548X */
			 || ((addr >= BOOT_FLASH_BASE) && (addr < BOOT_FLASH_BASE+BOOT_FLASH_SIZE)))
				mmu_remap(addr,addr,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_X);
#endif
			else
			{
				addr = pc & ~(PAGE_SIZE-1);
#ifdef MCF547X
				if((addr >= ZONE_CART) && (addr < END_ZONE_CART))
					mmu_remap(addr,(addr|FPGA_ZONE_IO),MMUOR_ITLB,MMUTR_SG,MMUDR_PAGE+MMUDR_WRITEBACK+MMUDR_X);
				else if((addr >= ZONE_EPROM2) && (addr < END_ZONE_EPROM2))
#else /* MCF548X */
				if((addr >= ZONE_CART) && (addr < END_ZONE_EPROM2))
#endif
					mmu_remap(addr,addr,MMUOR_ITLB,MMUTR_SG,MMUDR_PAGE+MMUDR_WRITEBACK+MMUDR_X);
				else /* invalid */
					mmu_remap(addr,addr,MMUOR_ITLB,MMUTR_SG,MMUDR_PAGE+MMUDR_NOCACHE);
			}
#ifdef DEBUG	
			{
				int i;
				for(i = 12; i >= 0; i-=4)
				{
				  pc = (unsigned long)(format >> i) & 0xF;
				  pc |= '0';
				  if(pc > '9')
				    pc += 7;
					conout(pc);		
				}
				conout('\r');
				conout('\n');
			}
#endif
			break;      
		case 0x0802: /* 10: TLB miss on data write */
		case 0x0C02: /* 14: TLB miss on data read */
#ifdef DEBUG	
			{
				int i;
				for(i = 28; i >= 0; i-=4)
				{
				  pc = (unsigned long)(MMUAR >> i) & 0xF;
				  pc |= '0';
				  if(pc > '9')
				    pc += 7;
					conout(pc);		
				}
				conout('\r');
				conout('\n');
			}
#endif
			addr = MMUAR & ~(PAGE_SIZE_1M-1);
#ifdef MCF5445X
			if(addr < ZONE_EPROM) /* STRAM */
				mmu_remap(addr,addr+PHYSICAL_OFFSET_SDRAM,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_R+MMUDR_W);
			else if((addr >= ZONE_EPROM) && (addr < END_ZONE_EPROM))
        mmu_remap(addr,addr+PHYSICAL_OFFSET_SDRAM,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_R);
			else if((addr >= ZONE_SDRAM) && (addr < SDRAM_SIZE))
				mmu_remap(addr,addr+PHYSICAL_OFFSET_SDRAM,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_R+MMUDR_W);
#else /* MCF548X */
#ifdef MCF547X /* FIREBEE */
			if(addr < VIDEO_RAM) /* STRAM */
				mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_R+MMUDR_W);
			else if((addr >= VIDEO_RAM) && (addr < ZONE_EPROM))
				mmu_remap(addr,addr-VIDEO_RAM+FPGA_VIDEO_RAM,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_R+MMUDR_W);
			else if((addr >= VIDEO_RAM2) && (addr < END_VIDEO_RAM2))
				mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_R+MMUDR_W);
#else /* MCF548X */
			if(addr < ZONE_EPROM) /* STRAM */
				mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_R+MMUDR_W);
#endif /* MCF547X */
			else if((addr >= ZONE_EPROM) && (addr < END_ZONE_EPROM))
        mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_R);
			else if((addr >= ZONE_SDRAM) && (addr < SDRAM_SIZE))
				mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_R+MMUDR_W);
#endif /* MCF5445X */
#if 0 // 1st half size of PCI memory used with prefetch inside the PCI BIOS
			else if((addr >= PCI_MEMORY_OFFSET) && (addr < PCI_MEMORY_OFFSET+(PCI_MEMORY_SIZE/2)))
				mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_R+MMUDR_W);
			else if(((addr >= PCI_MEMORY_OFFSET+(PCI_MEMORY_SIZE/2)) && (addr < PCI_MEMORY_OFFSET+PCI_MEMORY_SIZE))
#else
			else if(((addr >= PCI_MEMORY_OFFSET) && (addr < PCI_MEMORY_OFFSET+PCI_MEMORY_SIZE))
#endif
#ifdef MCF547X /* FIREBEE */
			 || ((addr >= FPGA_ACP_IO) && (addr < END_FPGA_ACP_IO))
			 || ((addr >= FPGA_SRAM) && (addr < END_FPGA_SRAM))			
#endif
			 || ((addr >= PCI_IO_OFFSET) && (addr < PCI_IO_OFFSET+PCI_IO_SIZE))
			 || ((addr >= BOOT_FLASH_BASE) && (addr < BOOT_FLASH_BASE+BOOT_FLASH_SIZE)))
				mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_NOCACHE+MMUDR_R+MMUDR_W);
			else
			{
				addr = MMUAR & ~(PAGE_SIZE-1);			
//				if((addr >= F030_BUS_SLOT) && (addr < END_F030_BUS_SLOT))
//					mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_PAGE+MMUDR_WRITEBACK+MMUDR_R+MMUDR_W);
//				else 
#ifdef MCF5445X
				if((addr >= ZONE_CART) && (addr < END_ZONE_EPROM2))
					mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_PAGE+MMUDR_WRITEBACK+MMUDR_R);
				else if((addr == SRAM_BASE) && (addr < SRAM_BASE+SRAM_SIZE))
					mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_PAGE+MMUDR_NOCACHE+MMUDR_R+MMUDR_W);
				else if(addr == ZONE1_SRAM)
					mmu_remap(ZONE1_SRAM,SRAM_BASE+SRAM_SIZE,0,MMUTR_SG,MMUDR_PAGE+MMUDR_NOCACHE+MMUDR_R+MMUDR_W);
				else if(addr == ZONE2_SRAM)
					mmu_remap(ZONE2_SRAM,SRAM_BASE+SRAM_SIZE+PAGE_SIZE,0,MMUTR_SG,MMUDR_PAGE+MMUDR_NOCACHE+MMUDR_R+MMUDR_W);	
				else if((addr == ZONE_IDE_MCF5445X)
				 || ((addr >= ZONE_IO_MCF5445X) && (addr < END_ZONE_IO_MCF5445X))
				 || (addr == CPLD_BASE) || (addr == FPGA_BASE)
#else /* MCF547X - MCF548X */
#ifdef MCF547X /* FIREBEE */
        if((addr == ZONE_IO) // IDE
				 || ((addr >= ZONE_CART) && (addr < END_ZONE_CART))
				 || ((addr >= END_F030_UNUSED) && (addr < FIREBEE_UNIMPLEMENTED))
				 || ((addr >= END_FIREBEE_UNIMPLEMENTED) && (addr < FIREBEE_UNIMPLEMENTED2))
				 || ((addr >= END_FIREBEE_UNIMPLEMENTED2) && (addr < END_ZONE_IO)))
					mmu_remap(addr,(addr|FPGA_ZONE_IO),0,MMUTR_SG,MMUDR_PAGE+MMUDR_NOCACHE+MMUDR_R+MMUDR_W);		
				else if((addr >= ZONE_EPROM2) && (addr < END_ZONE_EPROM2))
					mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_PAGE+MMUDR_WRITEBACK+MMUDR_R);
				else if((addr == FPGA_ZONE_IO) // IDE
				 || ((addr >= FPGA_ZONE_IO+END_F030_UNUSED-ZONE_IO) && (addr < FPGA_ZONE_IO+FIREBEE_UNIMPLEMENTED-ZONE_IO))
				 || ((addr >= FPGA_ZONE_IO+END_FIREBEE_UNIMPLEMENTED-ZONE_IO) && (addr < FPGA_ZONE_IO+FIREBEE_UNIMPLEMENTED2-ZONE_IO))
				 || (addr >= FPGA_ZONE_IO+END_FIREBEE_UNIMPLEMENTED2-ZONE_IO)
				 || ((addr >= __MBAR) && (addr < __MBAR+0x20000))
#else /* MCF548X */				 
				if((addr >= ZONE_CART) && (addr < END_ZONE_EPROM2))
					mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_PAGE+MMUDR_WRITEBACK+MMUDR_R);
				else if((addr == COMPACTFLASH_BASE)
				 || ((addr >= __MBAR) && (addr < __MBAR+0x20000))
#endif /* MCF547X */
				 || ((addr >= NO_CACHE_MEMORY_BASE) && (addr < NO_CACHE_MEMORY_BASE+NO_CACHE_MEMORY_SIZE))
#endif /* MCF5445X */
				 || ((addr >= __MMU_BASE) && (addr < __MMU_BASE+0x10000)))
					mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_PAGE+MMUDR_NOCACHE+MMUDR_R+MMUDR_W);
				else /* invalid */
				{
					if((pc >= CF68KLIB) && (pc < CF68KLIB+0x10000))
					{
						/* try to fix access fault with emulated instructions */
						*(unsigned long *)(save_mmuar) = addr;
//						while(1);
					}			
					mmu_remap(addr,addr,0,MMUTR_SG,MMUDR_PAGE+MMUDR_NOCACHE);
				}
			}
			break;
		default:
#ifdef DEBUG	
			{
				int i;
				for(i = 12; i >= 0; i-=4)
				{
				  pc = (unsigned long)(format >> i) & 0xF;
				  pc |= '0';
				  if(pc > '9')
				    pc += 7;
					conout(pc);		
				}
				conout('\r');
				conout('\n');
			}
#endif
			*(unsigned long *)(address_fault) = MMUAR;
			addr = *(unsigned long *)(save_coldfire_vector);
			asm volatile (
				" MOVE.L %0,28(SP)\n\t"
				" MOVEM.L (SP),D0-D5/A0\n\t"
				" LEA 28(SP),SP\n\t"
				" RTS" : : "d" (addr) ); /* CF68KLIB */
	}
	asm volatile (
		" MOVEM.L (SP),D0-D5/A0\n\t"
		" LEA 32(SP),SP\n\t"
		" RTE" );
}

void init_mmu(unsigned long base_pci_drivers, unsigned long size_pci_drivers)
{
	unsigned long addr,size;
	unsigned long *p1,*p2;
	unsigned long MMU_BASE = (unsigned long)__MMU_BASE;
	if(base_pci_drivers)
	{
		p1 = (unsigned long *)ZONE_SDRAM;         /* source uncompressed */
		p2 = (unsigned long *)base_pci_drivers;
		if(size_pci_drivers <= (END_ZONE_EPROM - base_pci_drivers))
		{
			size_pci_drivers+=15;
			size_pci_drivers>>=4;
			while((long)size_pci_drivers > 0)
			{
				*p2++ = *p1++;                        /* copy uncompressed PCI drivers */
				*p2++ = *p1++;
				*p2++ = *p1++;
				*p2++ = *p1++;
				size_pci_drivers--;
			}
			size = (END_ZONE_EPROM - (unsigned long)p2) >> 4;
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
				*p2++ = *p1++;                        /* copy uncompressed PCI drivers */
				*p2++ = *p1++;
				*p2++ = *p1++;
				*p2++ = *p1++;
				size--;
			}
			p2 = (unsigned long *)ZONE_EPROM2;
			size_pci_drivers+=15;
			size_pci_drivers>>=4;
			while((long)size_pci_drivers > 0)
			{
				*p2++ = *p1++;                        /* copy uncompressed PCI drivers */
				*p2++ = *p1++;
				*p2++ = *p1++;
				*p2++ = *p1++;
				size_pci_drivers--;
			}
			size = (END_ZONE_EPROM2 - (unsigned long)p2) >> 4;
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
	size = (END_ZONE_CART - ZONE_CART) >> 4;
	p2 = (unsigned long *)ZONE_CART;
	while((long)size > 0)
	{
		*p2++ = 0xFFFFFFFF;
		*p2++ = 0xFFFFFFFF;
		*p2++ = 0xFFFFFFFF;
		*p2++ = 0xFFFFFFFF;
		size--;
	}
	asm volatile (
		" MOVE.L D0,-(SP)\n\t"
		" MOVE.L %0,D0\n\t"
		" DC.L 0x4E7B0008\n\t"                   /* MOVEC.L D0,MMUBAR */
		" MOVE.L (SP)+,D0" : : "d" (MMU_BASE+1) );
	MMUOR =	MMUOR_CA;
	MMUOR = MMUOR_CA+MMUOR_ITLB;
#ifdef MCF5445X
	for(addr=0;addr<ZONE_EPROM;addr+=PAGE_SIZE_1M)
	{
		mmu_map(addr,addr+PHYSICAL_OFFSET_SDRAM,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_X+MMUDR_LK);
		mmu_map(addr,addr+PHYSICAL_OFFSET_SDRAM,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_R+MMUDR_W+MMUDR_LK);
	}	
	mmu_map(ZONE_EPROM,ZONE_EPROM+PHYSICAL_OFFSET_SDRAM,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_X+MMUDR_LK);
	mmu_map(ZONE_EPROM,ZONE_EPROM+PHYSICAL_OFFSET_SDRAM,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_R+MMUDR_LK);
	mmu_map(NO_CACHE_MEMORY_BASE,NO_CACHE_MEMORY_BASE,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_NOCACHE+MMUDR_X+MMUDR_LK);
	mmu_map(NO_CACHE_MEMORY_BASE,NO_CACHE_MEMORY_BASE,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_NOCACHE+MMUDR_R+MMUDR_W+MMUDR_LK);
	mmu_map(RAM_BASE_CF68KLIB,RAM_BASE_CF68KLIB,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_X+MMUDR_LK);
	mmu_map(RAM_BASE_CF68KLIB,RAM_BASE_CF68KLIB,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_R+MMUDR_W+MMUDR_LK);
#else /* MCF548X */
	for(addr=0;addr<ZONE_EPROM;addr+=PAGE_SIZE_1M)
	{
#ifdef MCF547X /* FIREBEE */
		if((addr>=VIDEO_RAM) && (addr<END_VIDEO_RAM))
		{
			mmu_map(addr,addr-VIDEO_RAM+FPGA_VIDEO_RAM,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_X+MMUDR_LK);
			mmu_remap(addr,addr-VIDEO_RAM+FPGA_VIDEO_RAM,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_R+MMUDR_W);
		}
		else
#endif /* MCF547X */
		{
			mmu_map(addr,addr,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_X+MMUDR_LK);
			mmu_map(addr,addr,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITETHROUGH+MMUDR_R+MMUDR_W+MMUDR_LK);
		}
	}
	mmu_map(ZONE_EPROM,ZONE_EPROM,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_X+MMUDR_LK);
	mmu_map(ZONE_EPROM,ZONE_EPROM,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_R+MMUDR_LK);
	mmu_map(RAM_BASE_CF68KLIB,RAM_BASE_CF68KLIB,MMUOR_ITLB,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_X+MMUDR_LK);
	mmu_map(RAM_BASE_CF68KLIB,RAM_BASE_CF68KLIB,0,MMUTR_SG,MMUDR_SZ1M+MMUDR_WRITEBACK+MMUDR_R+MMUDR_W+MMUDR_LK);
#ifdef MCF547X /* FIREBEE */
	mmu_map(FPGA_ZONE_IO,FPGA_ZONE_IO,0,MMUTR_SG,MMUDR_PAGE+MMUDR_NOCACHE+MMUDR_R+MMUDR_W+MMUDR_LK); // IDE
#endif
#endif /* MCF5445X */
#ifdef DEBUG
	addr = MCF_UART_UTB0 & ~(PAGE_SIZE-1);
	mmu_map(addr,addr,0,MMUTR_SG,MMUDR_PAGE+MMUDR_NOCACHE+MMUDR_R+MMUDR_W+MMUDR_LK);
#endif
	asm volatile (
		" MOVE.W SR,D0\n\t"
		" MOVE.L D0,-(SP)\n\t"
		" OR.L #0x700,D0\n\t"
		" MOVE.W D0,SR" : : : "d0");
#ifdef MCF5445X /* because SDRAM is remapped on MCF5445X, it's impossible to use ACRs for this zone */
  /* zone PCI memory in cache inhibit precise */
	{
		unsigned long ACR_PCI = (PCI_MEMORY_OFFSET & 0xFF000000) + (((PCI_MEMORY_SIZE-1) >> 8) & 0xFF0000) + 0xE040;
		asm volatile (
			" MOVE.L %0,D0\n\t"
			" MOVEC.L D0,ACR0" : : "d" (ACR_PCI) : "d0" ); /* data	*/
	}
  /* zone FLASH in cache inhibit precise */
	{
		unsigned long ACR_FLASH = (BOOT_FLASH_BASE & 0xFFF00000) + (((BOOT_FLASH_SIZE-1) >> 4) & 0xF0000) + 0xE440;
		asm volatile (
			" MOVE.L %0,D0\n\t"
			" MOVEC.L D0,ACR1\n\t"                           /* data */
			" MOVEC.L D0,ACR3" : : "d" (ACR_FLASH) : "d0" ); /* instruction */
	}
	asm volatile (
		" MOVEQ #0,D0\n\t"
		" MOVEC.L D0,ACR2" : : : "d0" );    /* instruction */
#else /* MCF547X - MCF548X */
	/* zone TT-RAM 48MB in copyback */
	asm volatile (
		" MOVE.L #0x0201E020,D0\n\t"
		" MOVEC.L D0,ACR0\n\t"              /* data */
		" MOVE.L #0x0100E020,D0\n\t"
		" MOVEC.L D0,ACR1" : : : "d0" );    /* data */
  /* SDRAM is cacheable */
	{
		unsigned long ACR_SDRAM = (SDRAM_BASE & 0xFF000000) + (((SDRAM_SIZE-1) >> 8) & 0xFF0000) + 0xE000;
		asm volatile (
			" MOVE.L %0,D0\n\t"
			" MOVEC.L D0,ACR2" : : "d" (ACR_SDRAM) : "d0" ); /* instruction */
	}	
	asm volatile (
		" MOVEQ #0,D0\n\t"
		" MOVEC.L D0,ACR3" : : : "d0");     /* instruction */
#endif
	asm volatile (" NOP");
	MMUCR = MMUCR_EN;                     /* enable */
	asm volatile (
		" NOP\n\t"
		" MOVE.L (SP)+,D0\n\t"
		" MOVE.W D0,SR\n\t" : : : "d0" );
}

#else /* ATARI - 68060 */

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

#endif
