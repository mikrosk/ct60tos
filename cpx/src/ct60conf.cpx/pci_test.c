#include <tos.h>
#include <stdio.h>
#include <string.h>
#include "ct60.h"
#include "pcixbios.h"
#include "radeon.h"

#define PCI_CTPCI_CONFIG   0xE0000000   /* CTPCI PLX registers */
#define PCI_CTPCI_CONFIG_PEND   (PCI_CTPCI_CONFIG+0)
#define PCI_CTPCI_CONFIG_ENABI  (PCI_CTPCI_CONFIG+1)
#define PCI_CTPCI_CONFIG_VECTOR (PCI_CTPCI_CONFIG+3)
#define PCI_CTPCI_CONFIG_RESET  (PCI_CTPCI_CONFIG+0x20)
#define PCI_LOCAL_CONFIG   0xE8000000   /* CT60 bus slot - no cache - reserved */
#define PCI_MEMORY_OFFSET  0x90000000   /* CT60 bus slot - cache */
#define PCI_MEMORY_SIZE    0x10000000   /* 256 MB */ 
#define PCI_IO_OFFSET      0xD0000000   /* CT60 bus slot - no cache */
#define PCI_IO_SIZE        0x10000000   /* 256 MB */

#define PCI_IRQ_BASE_VECTOR      0xC9   /* offset 0x9:LINT - 0xA:INT#A - 0xB:INT#B - 0xC:INT#C - 0xD:INT#D */

#define RADEON_REGSIZE     0x4000

/* PLX9054 ID */
#define PLX9054            0x905410B5
#define PLX9054_SWAPPED    0xB5105490

/* PLX9054 local configuration registers */
#define LAS0RR                0x80   /* Local Address Space 0 Range
                                        Register for PCI-to-Local Bus       */
#define LAS0BA                0x84   /* Local Address Space 0 Local Base
                                        Address (Remap)                     */
#define MARBR                 0x88   /* Mode/DMA Arbitration                */
#define BIGEND                0x8C   /* Big/Little Endian Descriptor        */
#define LMISC                 0x8D   /* Local Miscellaneous Control         */
#define PROT_AREA             0x8E   /* Serial EEPROM Write-Protect
                                        Address Boundary                    */
#define EROMRR                0x90   /* Expansion ROM Range                 */
#define EROMBA                0x94   /* Expansion ROM Local Base Address
                                        (Remap)                             */
#define LBRD0                 0x98   /* Local Address Space 0/Expansion ROM
                                        Bus Region Descriptor               */
#define DMRR                  0x9C   /* Local Range Register for PCI 
                                        Initiator-to-PCI                    */
#define DMLBAM                0xA0   /* Local Bus Base Address Register for
                                        PCI Initiator-to-PCI Memory         */
#define DMLBAI                0xA4   /* Local Bus Base Address Register for
                                        PCI Initiator-to-PCI I/O Config     */
#define DMPBAM                0xA8   /* PCI Base Address (Remap) Register
                                        for PCI Initiator-to-PCI Memory     */
#define DMCFGA                0xAC   /* PCI Configuration Address Register
                                        for PCI Initiator-to-PCI I/O Config */
#define OPQIS                 0xB0   /* Outbound Post Queue Post Queue 
                                        Interrupt Status                    */
#define OPQIM                 0xB4   /* Outbound Post Queue Post Queue 
                                        Interrupt Mask                      */
#define MBOX0                 0xC0   /* Mailbox Register 0                  */
#define MBOX1                 0xC4   /* Mailbox Register 1                  */
#define MBOX2                 0xC8   /* Mailbox Register 2                  */
#define MBOX3                 0xCC   /* Mailbox Register 3                  */
#define MBOX4                 0xD0   /* Mailbox Register 4                  */
#define MBOX5                 0xD4   /* Mailbox Register 5                  */
#define MBOX6                 0xD8   /* Mailbox Register 6                  */
#define MBOX7                 0xDC   /* Mailbox Register 7                  */
#define P2LDBELL              0xE0   /* PCI-to-Local Doorbell               */
#define L2PDBELL              0xE4   /* Local-to-PCI Doorbell               */
#define INTCSR                0xE8   /* Interrupt Control/Status            */
#define CNTRL                 0xEC   /* Serial EEPROM Control, PCI Command
                                        Codes, User I/O Ctrl, and Init Ctrl */
#define PCIHIDR               0xF0   /* PCI Hardcoded Configuration ID      */
#define PCIHREV               0xF4   /* PCI Hardcoded Revision ID           */
#define DMAMODE0             0x100   /* DMA Channel 0 Mode                  */
#define DMAPADR0             0x104   /* DMA Channel 0 PCI Address           */
#define DMALADR0             0x108   /* DMA Channel 0 Local Address         */
#define DMASIZ0              0x10C   /* DMA Channel 0 Transfer Size (Bytes) */
#define DMADPR0              0x110   /* DMA Channel 0 Descriptor Pointer    */
#define DMAMODE1             0x114   /* DMA Channel 1 Mode                  */
#define DMAPADR1             0x118   /* DMA Channel 1 PCI Address           */
#define DMALADR1             0x11C   /* DMA Channel 1 Local Address         */
#define DMASIZ1              0x120   /* DMA Channel 1 Transfer Size (Bytes) */
#define DMADPR1              0x124   /* DMA Channel 1 Descriptor Pointer    */
#define DMASCR0              0x128   /* DMA Channel 0 Command/Status        */
#define DMASCR1              0x129   /* DMA Channel 1 Command/Status        */
#define DMAARB               0x12C   /* DMA Arbitration                     */
#define DMATHR               0x130   /* DMA Threshold                       */
#define DMADAC0              0x134   /* DMA Channel 0 PCI Dual Address
                                        Cycle Address                       */
#define DMADAC1              0x134   /* DMA Channel 1 PCI Dual Address
                                        Cycle Address                       */
#define MQCR                 0x140   /* Messaging Queue Configuration       */
#define QBAR                 0x144   /* Queue Base Address                  */
#define IFHPR                0x148   /* Inbound Free Head Pointer           */
#define IFTPR                0x14C   /* Inbound Free Tail Pointer           */
#define IPHPR                0x150   /* Inbound Post Head Pointer           */
#define IPTPR                0x154   /* Inbound Post Tail Pointer           */
#define OFHPR                0x158   /* Outbound Free Head Pointer          */
#define OFTPR                0x15C   /* Outbound Free Tail Pointer          */
#define OPHPR                0x160   /* Outbound Post Head Pointer          */
#define OPTPR                0x164   /* Outbound Post Tail Pointer          */
#define QSR                  0x168   /* Queue Status/Control                */
#define LAS1RR               0x170   /* Local Address Space 1 Range Register
                                        for PCI-to-Local Bus                */
#define LAS1BA               0x174   /* Local Address Space 1 Local Base
                                        Address (Remap)                     */
#define LBRD1                0x178   /* Local Address Space 1 Bus Region
                                        Descriptor                          */
#define DMDAC                0x17C   /* PCI Initiator PCI Dual Address Cycle*/

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

struct rom_header
{
	unsigned short signature;
	unsigned char size;
	unsigned char init[3];
	unsigned char reserved[0x12];
	unsigned short data;
};

struct pci_data
{
	unsigned long signature;
	unsigned short vendor;
	unsigned short device;
	unsigned short reserved_1;
	unsigned short dlen;
	unsigned char drevision;
	unsigned char class_lo;
	unsigned short class_hi;
	unsigned short ilen;
	unsigned short irevision;
	unsigned char type;
	unsigned char indicator;
	unsigned short reserved_2;
};

/* prototypes */

COOKIE *fcookie(void);
COOKIE *ncookie(COOKIE *p);
COOKIE *get_cookie(long id);
int add_cookie(COOKIE *cook);
extern void move_16(unsigned long *src, unsigned long *dst);
extern void move_4_longs(unsigned long *src, unsigned long *dst);
extern void	cpush_dc(void *base, long size);
extern volatile long count_inta;
extern void inta(void);

#define BUFFER_SIZE 0x100000 
unsigned char buffer[BUFFER_SIZE+256];

long enable_inta(void)
{
	*(volatile unsigned char *)PCI_CTPCI_CONFIG_ENABI |= 0x02;
	return(0);
}

long disable_inta(void)
{
	*(volatile unsigned char *)PCI_CTPCI_CONFIG_ENABI &= 0xFD;
	return(0);
}

void write_local_config_longword(unsigned long reg, unsigned long data)
{
	if(*((unsigned long *)PCI_LOCAL_CONFIG) == PLX9054_SWAPPED)
		data = ((data >> 24) & 0xff)
		    | ((data >> 8)  & 0xff00)
		    | ((data << 8)  & 0xff0000)
		    | ((data << 24) & 0xff000000);
	*((unsigned long *)(PCI_LOCAL_CONFIG + reg)) = data;
}

long get_hz_200(void)
{
	return(*(long *)0x4BA);
}

void wait_dma(void)
{
	unsigned long start_hz_200 = (unsigned long)Supexec(get_hz_200);
	while(dma_buffoper(-1) > 0)
	{
		if(Supexec(get_hz_200) - start_hz_200 > 200)
		{
			printf("DMA Timeout\r\n");
			break;							
		}
	}
}

long find_radeon(void)
{
	unsigned long temp;
	short index;
	long handle,err;
	struct pci_device_id *radeon;
	index=0;
	do
	{
		handle=find_pci_device(0x0000FFFFL,index++);
		if(handle>=0)
		{
			err=read_config_longword(handle,PCIIDR,&temp);
			/* test Radeon ATI devices */
			if(err>=0)
			{
				radeon=radeonfb_pci_table; /* compare table */
				while(radeon->vendor)
				{
					if((radeon->vendor==(temp & 0xFFFF))
					 && (radeon->device==(temp>>16)))
						return(handle);
					radeon++;
				}
			}
		}
	}
	while(handle>=0);
	return(0);
}	

int main(void)
{
	COOKIE *p;
	unsigned long ad, val, read = 0x12345678;
	char c;
	if(((p=get_cookie('_CPU'))==0) || (p->v.l!=0x3C))
	{
		printf("This computer isn't a FALCON 030/CT60\r\n");
		Cconin();
	}
	else
	{
		if(read);
		if(get_cookie('_PCI')==0)
		{
#if 1
			printf("CTPCI / PCI BIOS not found\r\n");
			Cconin();
#else
			write_local_config_longword(BIGEND, 0x00300100);
			write_local_config_longword(DMRR, 0xfff00000);
			write_local_config_longword(DMLBAM, PCI_MEMORY_OFFSET);
			write_local_config_longword(DMLBAI, PCI_IO_OFFSET);
			write_local_config_longword(DMPBAM, 0);
			write_local_config_longword(DMCFGA, 0);
			write_local_config_longword(BIGEND, 0x00300500);
			write_local_config_longword(PCICSR, 0x02900007);
			write_local_config_longword(DMPBAM, 3);
			while(1)
			{
				for(ad = 21; ad <= 24; ad++)
				{
					val = (ad  - 11) << 11;
					val |= 0x80000000;
					write_local_config_longword(DMCFGA, val);
					read = *((unsigned long *)PCI_IO_OFFSET);
/*					val &= 0x7fffffff;
					write_local_config_longword(DMCFGA, val);		
*/					printf("AD[%d] selected, read: 0x%08lx\r\n", (int)ad, read);
					c = (char)Crawcin();
					if((c == 27) || (c =='q') || (c=='Q'))
						return(0);
				}
			}
#endif
		}
		else		
		{
#if 0
			while(1)
			{
				for(ad = 11; ad < 31; ad++)
				{
					val = (ad  - 11) << 11;
					val |= 0x80000000;
					write_config_longword(0, DMCFGA, val);
					read = *((unsigned long *)PCI_IO_OFFSET);
/*					val &= 0x7fffffff;
					write_config_longword(0, DMCFGA, val);		
*/					printf("AD[%d] selected, read: 0x%08lx\r\n", (int)ad, read);
					c = (char)Cconin();
					if((c == 27) || (c =='q') || (c=='Q'))
						return(0);
				}
			}
#else
			Cconws("\r\n(1-a-A) Random write/read (B/W/L) on PLX regs MBOX0-7\r\n");
			Cconws("(2-b-B) Random write/read (B/W/L) on Radeon MEM\r\n");
			Cconws("(3-c-C) Linear write/read (L) on Radeon MEM\r\n");
			Cconws("(4-d-D) Random read (B/W/L) on Radeon MEM\r\n");
			Cconws("(5-e-E) Linear read (L) on Radeon MEM\r\n");
			Cconws("(6-f-F) Save Radeon VGA ROM\r\n");
			Cconws("(7-g-G) Dump Radeon config registers\r\n");
			Cconws("(8-h-H) Linear write/read (L) with 0/0xFFFFFFFF on Radeon MEM\r\n");
			Cconws("(9-i-I) Random write/read (B/W/L) on PLX regs MBOX0-7 with 0/0xFFFFFFFF\r\n");
			Cconws("(0-j-J) Write/multiple read (B) on PLX reg MBOX0 with 0\r\n");
			Cconws("(  k-K) Linear Move16 on Radeon MEM\r\n");
			Cconws("(  l-L) DMA write - Local to PCI\r\n");
			Cconws("(  m-M) DMA read - PCI to Local\r\n");
			Cconws("(  n-N) DMA write - Local to PCI, random size\r\n");
			Cconws("(  o-O) DMA read - PCI to Local, random size\r\n");
			Cconws("(  p-P) INTA test\r\n");
			Cconws("Choice ? ");
			c = (char)(Cconin()&0xFF);
			printf("\r\n");
			if((c == '1') || (c == 'a') || (c == 'A'))
			{
				while(1)
				{
					unsigned long rnd = Random();
					unsigned long offset, val3 = 0;
					switch(rnd & 7)
					{
						case 0: offset = MBOX0; break;
						case 1: offset = MBOX1; break;
						case 2: offset = MBOX2; break;
						case 3: offset = MBOX3; break;	
						case 4: offset = MBOX4; break;
						case 5: offset = MBOX5; break;
						case 6: offset = MBOX6; break;
						case 7: offset = MBOX7; break;
					}
					rnd >>= 3;
					if(rnd & 1)
					{
						unsigned char val1 = (unsigned char)Random(), val2;
						write_config_byte(0, offset, val1);
						val2 = fast_read_config_byte(0, offset);
						if(val1 != val2)
						{
							val3 = *(unsigned long *)0xA0000000;
							printf("Write 0x%02x read 0x%02x at PLX reg 0x%04lx\r\n", (int)val1 & 0xff, (int)val2 & 0xff, offset);
						}
					}
					else if(rnd & 2)
					{
						unsigned short val1 = (unsigned short)Random(), val2;
						write_config_word(0, offset, val1);
						val2 = fast_read_config_word(0, offset);
						if(val1 != val2)
						{
							val3 = *(unsigned long *)0xA0000000;
							printf("Write 0x%04x read 0x%04x at PLX reg 0x%04lx\r\n", val1, val2, offset);
						}
					}
					else
					{
						unsigned long val1 = (unsigned long)Random() + (offset << 16), val2;
						write_config_longword(0, offset, val1);
						val2 = fast_read_config_longword(0, offset);
						if(val1 != val2)
						{
							val3 = *(unsigned long *)0xA0000000;
							printf("Write 0x%08lx read 0x%08lx at PLX reg 0x%04lx\r\n", val1, val2, offset);
						}
					}
					val3 += rnd;
					c = (char)Crawio(255);
					if((c == 27) || (c =='q') || (c=='Q'))
						return(0);
				}
			}
			else if((c == '9') || (c == 'i') || (c == 'I'))
			{
				unsigned long val = 0, val3 = 0;
				while(1)
				{
					unsigned char val1 = (unsigned char)val, val2;
					write_config_byte(0, MBOX0, val1);
					val2 = fast_read_config_byte(0, MBOX0);
					if(val1 != val2)
					{
						val3 = *(unsigned long *)0xA0000000;
						printf("Write 0x%02x read 0x%02x at PLX reg 0x%04lx\r\n", (int)val1 & 0xff, (int)val2 & 0xff, MBOX0);
					}
					val ^= 0xFFFFFFFF;
					val3 += val;
					c = (char)Crawio(255);
					if((c == 27) || (c =='q') || (c=='Q'))
						return(0);
				}
			}
			else if((c == '0') || (c == 'j') || (c == 'J'))
			{
				unsigned long val3 = 0;
				write_config_byte(0, MBOX0, 0);
				while(1)
				{
					unsigned char val2;
					if((val2 = fast_read_config_byte(0, MBOX0)) != 0)
					{
						val3 = *(unsigned long *)0xA0000000;
						printf("Write 0x00 read 0x%02x at PLX reg 0x%04lx\r\n",(int)val2 & 0xff, MBOX0);
					}
					val3 += (unsigned long)val2;
					c = (char)Crawio(255);
					if((c == 27) || (c =='q') || (c=='Q'))
						return(0);
				}
			}
			else
			{
				long handle = find_radeon();
				void *io_base = NULL;
				void *mmio_base = NULL;
				void *fb_base = NULL;
				void *bios_seg = NULL;
				unsigned long bios_seg_phys = 0;
				unsigned long fb_base_phys = 0xFFFFFFFF;
				unsigned long mmio_base_phys = 0xFFFFFFFF;
				unsigned long io_base_phys = 0xFFFFFFFF;
				unsigned long mapped_vram = 0;
				unsigned long cnt_err = 0;
				unsigned long cnt_rw = 0;
				unsigned long cnt_err_cmp = 0;
				unsigned long err;
				PCI_CONV_ADR pci_conv_adr;
				if(handle == 0)
				{
					printf("Radeon board not found\r\n");
					Cconin();
				}
				else
				{
					PCI_RSC_DESC *pci_rsc_desc = (PCI_RSC_DESC *)get_resource(handle);
					if((long)pci_rsc_desc>=0)
					{
						unsigned short flags;
						do
						{
							if(!(pci_rsc_desc->flags & FLG_IO))
							{
								if((fb_base_phys == 0xFFFFFFFF) && (pci_rsc_desc->length >= 0x100000))
								{
									fb_base_phys = pci_rsc_desc->start;
									mapped_vram = pci_rsc_desc->length;
									if((pci_rsc_desc->flags & FLG_ENDMASK) == ORD_MOTOROLA)
										printf("host bridge is big endian\r\n");
									else
										printf("host bridge is little endian\r\n");
								}
								else if((pci_rsc_desc->length >= RADEON_REGSIZE)
								 && (pci_rsc_desc->length < 0x100000))
								{
									if(bios_seg == NULL)
									{
										unsigned short signature;
										bios_seg_phys = pci_rsc_desc->start;
										signature = ((unsigned short)fast_read_mem_byte(handle, bios_seg_phys)
										          | ((unsigned short)fast_read_mem_byte(handle, bios_seg_phys + 1) << 8));
										if(signature == 0xaa55)
											bios_seg  = (void *)(pci_rsc_desc->offset + pci_rsc_desc->start);
										else
											bios_seg_phys = 0;
									}
									if(mmio_base_phys == 0xFFFFFFFF)
									{		
										mmio_base = (void *)(pci_rsc_desc->offset + pci_rsc_desc->start);
										mmio_base_phys = pci_rsc_desc->start;
									}
								}
							}
							else
							{
								if(io_base_phys == 0xFFFFFFFF)
								{		
									io_base = (void *)(pci_rsc_desc->offset + pci_rsc_desc->start);
									io_base_phys = pci_rsc_desc->start;
								}
							}
							flags = pci_rsc_desc->flags;
							(unsigned long)pci_rsc_desc += (unsigned long)pci_rsc_desc->next;
						}
						while(!(flags & FLG_LAST));
					}
					else
						printf("PCI BIOS get_resource error\r\n");
					printf("mmio_base_phys 0x%08lx mmio_base 0x%08lx\r\n", mmio_base_phys, (unsigned long)mmio_base);
					printf("io_base_phys 0x%08lx io_base 0x%08lx\r\n", io_base_phys, (unsigned long)io_base);
					fb_base = NULL;
					if(bus_to_virt(handle,fb_base_phys,&pci_conv_adr) >= 0)
						fb_base=(void *)pci_conv_adr.adr;
					else
						printf("PCI BIOS bus_to_virt error");
					printf("fb_base_phys 0x%08lx fb_base 0x%08lx\r\n", fb_base_phys, (unsigned long)fb_base);
					printf("bios_seg_phys 0x%08lx bios_seg 0x%08lx\r\n", bios_seg_phys, (unsigned long)bios_seg);
					switch(c)
					{
					case 'p':
					case 'P': /* INTA test */
						{
							long cc = count_inta;
							long old_inta = (long)Setexc(PCI_IRQ_BASE_VECTOR+1,(void (*)())inta);
							Supexec(enable_inta);
							do
							{
								c = (char)Crawio(255);
								if(cc != count_inta)
								{
									printf("INTA no %ld\r\n", count_inta);
									cc = count_inta;
								}
							}
							while((c != 27) && (c !='q') && (c!='Q'));
							Supexec(disable_inta);
							Setexc(PCI_IRQ_BASE_VECTOR+1,(void (*)())old_inta);
							return(0);
						}
					case 'o':
					case 'O': /* DMA read - random size */
						while(1)
						{
							unsigned long *src = (unsigned long *)(((unsigned long)buffer + 3) & 0xfffffffc);
							unsigned long offset, val3 = 0;
							unsigned long size =  Random() & (BUFFER_SIZE-1) & 0xfffffffc;
							src[size >> 2] = 0;
							memset(src, 0, size);
							val = 0;
							for(offset = 0; offset < size; offset += 4)
							{
								if(val == 0xffffffff)
									val = 0;
								else
									val += 0x01010101;
								*((unsigned long *)((unsigned long)fb_base + (mapped_vram >> 1) + offset)) = val;
							}
/*							printf("pci:%08lx local:%08lx size:%08lx\r\n",fb_base_phys + (mapped_vram >> 1),src,size); */
							/* PCI, local, size */
							dma_setbuffer(fb_base_phys + (mapped_vram >> 1),src,size);
							dma_buffoper(1); /* PCI to local bus */
							wait_dma();
							val = 0;					
							for(offset = 0; offset < (size >> 2); offset++)
							{
								cnt_rw++;
								if(val == 0xFFFFFFFF)
									val = 0;
								else
									val += 0x01010101;
								if(src[offset] != val)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[%ld]:%08lx [local:%08lx] -> move longs -> [MEM:%08lx], [PCI:%08lx] -> DMA read -> [local:%08lx], read:%08lx\r\n", 
									 offset, val, &src[offset], (unsigned long)fb_base + (offset << 2), fb_base_phys + (offset << 2), &src[offset], src[offset]);
									c = (char)Crawio(255);
									if((c == 27) || (c =='q') || (c=='Q'))
									{
										printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
										Crawcin();
										return(0);
									}	
								}
							}
							if(src[size >> 2] != 0)
							{
								val3 = *(unsigned long *)0xA0000000;
								printf("Buffer overlow Data[%ld]:%08lx\r\n", size >> 2, src[size >> 2]);
							}
							val3 ^= 0xFFFFFFFF;
							c = (char)Crawio(255);
							if((c == 27) || (c =='q') || (c=='Q'))
							{
								printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
								Crawcin();
								return(0);
							}	
						}							
					case 'n':
					case 'N': /* DMA write - random size */
						while(1)
						{
							unsigned long *src = (unsigned long *)(((unsigned long)buffer + 3) & 0xfffffffc);
							unsigned long offset, val3 = 0;
							unsigned long size =  Random() & (BUFFER_SIZE-1) & 0xfffffffc;
							unsigned long ssp;
							val = 0;
							for(offset = 0; offset < (size >> 2); offset++)
							{
								if(val == 0xffffffff)
									val = 0;
								else
									val += 0x01010101;
								src[offset] = val;
							}
							ssp = Super(0);
							cpush_dc(src, size);
							Super((void *)ssp);
							/* PCI, local, size */
							dma_setbuffer(fb_base_phys + (mapped_vram >> 1),src,size);
							dma_buffoper(2); /* local bus to PCI */
							wait_dma();
							val = 0;					
							for(offset = 0; offset < size; offset += 4)
							{
								unsigned long val2;
								cnt_rw++;
								if(val == 0xFFFFFFFF)
									val = 0;
								else
									val += 0x01010101;
								val2  = *((unsigned long *)((unsigned long)fb_base + (mapped_vram >> 1) + offset));
								if(val2 != val)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[%ld]:%08lx [local:%08lx] -> DMA write -> [PCI:%08lx], [MEM:%08lx] -> move longs -> read:%08lx\r\n", 
									 offset >> 2, val, &src[0], fb_base_phys + offset, (unsigned long)fb_base + offset, val2);
									c = (char)Crawio(255);
									if((c == 27) || (c =='q') || (c=='Q'))
									{
										printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
										Crawcin();
										return(0);
									}
								}
							}
							val3 ^= 0xFFFFFFFF;
							c = (char)Crawio(255);
							if((c == 27) || (c =='q') || (c=='Q'))
							{
								printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
								Crawcin();
								return(0);
							}	
						}	
					case 'm':
					case 'M': /* DMA read */
						{
							unsigned long *src = (unsigned long *)(((unsigned long)buffer + 15) & 0xfffffff0);
							unsigned long offset, val3 = 0;
							src[0] = src[2] = 0x76543210;
							src[1] = src[3] = 0x89ABCDEF;
							for(offset = 0; offset < (mapped_vram >> 1); offset += 16)
							{
								cnt_rw+=4;
								move_4_longs(src, (unsigned long *)((unsigned long)fb_base + offset));
								src[0] = src[1] = src[2] = src[3] = 0;
/*								printf("pci:%08lx local:%08lx size:%ld\r\n",fb_base_phys + offset,src,16); */
								/* PCI, local, size */
								dma_setbuffer(fb_base_phys + offset,src,16);
								dma_buffoper(1); /* PCI to local bus */
								wait_dma();			
								if(src[0] != 0x76543210)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[0]:76543210 [local:%08lx] -> move4long -> [MEM:%08lx], [PCI:%08lx] -> DMA read -> [local:%08lx], read:%08lx\r\n", 
									 &src[0], (unsigned long)fb_base + offset, fb_base_phys + offset, &src[0], src[0]);
									src[0] = 0x76543210;
								}
								if(src[1] != 0x89ABCDEF)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[1]:89ABCDEF [local:%08lx] -> move4long -> [MEM:%08lx], [PCI:%08lx] -> DMA read -> [local:%08lx], read:%08lx\r\n", 
									 &src[1], (unsigned long)fb_base + offset + 4, fb_base_phys + offset + 4, &src[1], src[1]);
									src[1] =0x89ABCDEF;
								}
								if(src[2] != 0x76543210)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[2]:76543210 [local:%08lx] -> move4long -> [MEM:%08lx], [PCI:%08lx] -> DMA read -> [local:%08lx], read:%08lx\r\n", 
									 &src[2], (unsigned long)fb_base + offset + 8, fb_base_phys + offset + 8, &src[2], src[2]);
									src[2] = 0x76543210;
								}
								if(src[3] != 0x89ABCDEF)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[3]:89ABCDEF [local:%08lx] -> move4long -> [MEM:%08lx], [PCI:%08lx] -> DMA read -> [local:%08lx], read:%08lx\r\n", 
									 &src[3], (unsigned long)fb_base + offset + 12, fb_base_phys + offset + 12, &src[3], src[3]);
									src[3] = 0x89ABCDEF;
								}
								write_config_longword(0, MBOX0, cnt_rw);
								val3 ^= 0xFFFFFFFF;
								c = (char)Crawio(255);
								if((c == 27) || (c =='q') || (c=='Q'))
								{
									printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
									Crawcin();
									return(0);
								}							
							}
						}							
						printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
						Crawcin();
						return(0);
					case 'l':
					case 'L': /* DMA write */
						{
							unsigned long *src = (unsigned long *)(((unsigned long)buffer + 15) & 0xfffffff0);
							unsigned long offset, val3 = 0;
							src[0] = src[2] = 0x76543210;
							src[1] = src[3] = 0x89ABCDEF;
							for(offset = 0; offset < (mapped_vram >> 1); offset += 16)
							{
								unsigned long ssp = Super(0);
								cpush_dc(src, 16);
								Super((void *)ssp);
								cnt_rw += 4;
								/* PCI, local, size */
								dma_setbuffer(fb_base_phys + offset,src,16);
								dma_buffoper(2); /* local bus to PCI */
								wait_dma();
								move_4_longs((unsigned long *)((unsigned long)fb_base + offset), src);
								if(src[0] != 0x76543210)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[0]:76543210 [local:%08lx] -> DMA write -> [PCI:%08lx], [MEM:%08lx] -> move4long -> [local:%08lx], read:%08lx\r\n", 
									 &src[0], fb_base_phys + offset, (unsigned long)fb_base + offset, &src[0], src[0]);
									src[0] = 0x76543210;
								}
								if(src[1] != 0x89ABCDEF)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[1]:89ABCDEF [local:%08lx] -> DMA write -> [PCI:%08lx], [MEM:%08lx] -> move4long -> [local:%08lx], read:%08lx\r\n", 
									 &src[1], fb_base_phys + offset + 4, (unsigned long)fb_base + offset + 4, &src[1], src[1]);
									src[1] = 0x89ABCDEF;
								}
								if(src[2] != 0x76543210)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[2]:76543210 [local:%08lx] -> DMA write -> [PCI:%08lx], [MEM:%08lx] -> move4long -> [local:%08lx], read:%08lx\r\n", 
									 &src[2], fb_base_phys + offset + 8, (unsigned long)fb_base + offset + 8, &src[2], src[2]);
									src[2] = 0x76543210;
								}
								if(src[3] != 0x89ABCDEF)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Data[3]:89ABCDEF [local:%08lx] -> DMA write -> [PCI:%08lx], [MEM:%08lx] -> move4long -> [local:%08lx], read:%08lx\r\n", 
									 &src[3], fb_base_phys + offset + 12, (unsigned long)fb_base + offset + 12, &src[3], src[3]);
									src[3] = 0x89ABCDEF;
								}
/*								write_config_longword(0, MBOX0, cnt_rw); */
								val3 ^= 0xFFFFFFFF;
								c = (char)Crawio(255);
								if((c == 27) || (c =='q') || (c=='Q'))
								{
									printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
									Crawcin();
									return(0);
								}							
							}
						}							
						printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
						Crawcin();
						return(0);					
					case 'k':
					case 'K':
						{
							unsigned long *src = (unsigned long *)(((unsigned long)buffer + 15) & 0xfffffff0);
							unsigned long offset, dst = (unsigned long)fb_base, val3 = 0;
							src[0] = src[2] = 0x76543210;
							src[1] = src[3] = 0x89ABCDEF;
							for(offset = 0; offset < (mapped_vram >> 1); offset += 16)
							{
								cnt_rw+=4;
								move_16(src, (unsigned long *)(dst + offset));
								src[0] = src[1] = src[2] = src[3] = 0;
								move_16((unsigned long *)(dst + offset), src);
								if(src[0] != 0x76543210)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Write 0x%08lx read 0x%08lx at 0x%08lx\r\n", 0x76543210, src[0], dst + offset);
									src[0] = 0x76543210;
								}
								if(src[1] != 0x89ABCDEF)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Write 0x%08lx read 0x%08lx at 0x%08lx\r\n", 0x89ABCDEF, src[1], dst + offset + 4);
									src[1] = 0x89ABCDEF;
								}
								if(src[2] != 0x76543210)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Write 0x%08lx read 0x%08lx at 0x%08lx\r\n", 0x76543210, src[2], dst + offset + 8);
									src[2] = 0x76543210;
								}
								if(src[3] != 0x89ABCDEF)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Write 0x%08lx read 0x%08lx at 0x%08lx\r\n", 0x89ABCDEF, src[3], dst + offset + 12);
									src[3] = 0x89ABCDEF;
								}
/*								write_config_longword(0, MBOX0, cnt_rw); */
								val3 ^= 0xFFFFFFFF;
								c = (char)Crawio(255);
								if((c == 27) || (c =='q') || (c=='Q'))
								{
									printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
									Crawcin();
									return(0);
								}							
							}
						}							
						printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
						Crawcin();
						return(0);
					case '8':
					case 'h':
					case 'H':
						{
							unsigned long offset, val1 = 0, val3 = 0;
							for(offset = 0; offset < (mapped_vram >> 1); offset += 4)
							{
								unsigned long val2 = 0;
								cnt_rw++;
								if((err = write_mem_longword(handle, offset, val1)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								cnt_rw++;
								if((err = read_mem_longword(handle, offset, &val2)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								if(val1 != val2)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Write 0x%08lx read 0x%08lx at 0x%08lx\r\n", val1, val2, (unsigned long)fb_base + offset);
								}
/*								write_config_longword(0, MBOX0, cnt_rw); */
								val1 ^= 0xFFFFFFFF;
								val3 += val1;
								c = (char)Crawio(255);
								if((c == 27) || (c =='q') || (c=='Q'))
								{
									printf("Total errors %ld / %ld (%ld%%)\r\n", cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
									printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
									Crawcin();
									return(0);
								}							
							}
						}							
						printf("Total errors %ld / %ld (%ld%%)\r\n", cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
						Crawcin();
						return(0);
					case '7':
					case 'g':
					case 'G':
						{
							unsigned long i, j;
							for(i = 0, j = 0; i < 0x80; i+= 4, j++)
							{
								if((j & 7) == 0)
									printf("\r\n%04lx ", i);
								printf("%08lx ", fast_read_config_longword(handle, i));
							}
							printf("\r\n");
						}
						Crawcin();
						break;
					case '6':
					case 'f':
					case 'F':
						{
							short handle_dos;
							unsigned long i, j;
							struct rom_header *rom_header = (struct rom_header *)NULL;
							struct pci_data *rom_data;
							unsigned long rom_size = 0;
							unsigned long image_size = 0;
							do
							{
								unsigned long v;
								rom_header = (struct rom_header *)((unsigned long)rom_header + image_size); /* get next image */
								v = (unsigned long)&rom_header->data;
								rom_data = (struct pci_data *)((unsigned long)rom_header
								         + (unsigned long)((unsigned long)fast_read_mem_byte(handle,bios_seg_phys + v) | (unsigned long)fast_read_mem_byte(handle, bios_seg_phys + v + 1) << 8));
								v = (unsigned long)&rom_data->ilen;
								image_size = ((unsigned long)fast_read_mem_byte(handle, bios_seg_phys + v) | ((unsigned long)fast_read_mem_byte(handle, bios_seg_phys + v + 1) << 8)) << 9;
							}
							while((fast_read_mem_byte(handle, bios_seg_phys + (unsigned long)&rom_data->type) != 0) && (fast_read_mem_byte(handle,bios_seg_phys + (unsigned long)&rom_data->indicator) != 0));  /* make sure we got x86 version */
							if(fast_read_mem_byte(handle,bios_seg_phys + (unsigned long)&rom_data->type) != 0)
							{
								printf("No X86 VGA ROM found!");
								Crawcin();
								return(0);
							}
							rom_size = (unsigned long)fast_read_mem_byte(handle, bios_seg_phys + (unsigned long)&rom_header->size) << 9;
							printf("\r\nVGA ROM word access, start:\r\n");
							for(i = 0; i < 16; printf("%04x ", fast_read_mem_word(handle, bios_seg_phys + i)), i += 2);
							printf("\r\nVGA ROM longword access, start:\r\n");
							for(i = 0; i < 16; printf("%08lx ", fast_read_mem_longword(handle, bios_seg_phys + i)), i += 4);
							printf("\r\nSave all VGA ROM with byte access, start:");  
							for(i = 0, j = 0; i < ((unsigned long)rom_header + rom_size); i++, j++)
							{
								buffer[j] = fast_read_mem_byte(handle, bios_seg_phys + i);
								if(j < 256)
								{
									if((j & 15) == 0)
								  		printf("\r\n%08lx ", bios_seg_phys + i);
								  	printf("%02x ", buffer[j]);
									if((j & 15) == 15)
									{
										unsigned long k;
										for(k = j - 15; k <= j; k++)
										{
											if((buffer[k] >= ' ') && (buffer[k] < 127))
												printf("%c", buffer[k]);
											else
												printf(".");
										} 
										c = (char)Crawio(255);
										if(c == ' ')
											Crawcin();
									}
								}
							}
							printf("\r\n");
							handle_dos = Fcreate("C:\\VGA_ROM.BIN", 0);
							if(handle_dos >= 0)
							{
								if(Fwrite(handle_dos, (unsigned long)rom_header + rom_size, buffer) <= 0)
								{
									printf("Error during writing file C:\\VGA_ROM.BIN\r\n");
									Fclose(handle_dos);
								}
								else
								{
									Fclose(handle_dos);
									printf("File C:\\VGA_ROM.BIN writed with success (%ld bytes)\r\n", (unsigned long)rom_header + rom_size);
								}
							}
							else
								printf("Error for create file C:\\VGA_ROM.BIN (error:%d)!", handle_dos);
							Crawcin();
						}
						return(0);
					case '5':
					case 'e':
					case 'E':
						{
							unsigned long offset;
							for(offset = 0; offset < (mapped_vram >>1); offset += 4)
							{
								unsigned long val2 = 0;
								cnt_rw++;
								if((err = read_mem_longword(handle, offset, &val2)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
/*								write_config_longword(0, MBOX0, cnt_rw); */
								c = (char)Crawio(255);
								if((c == 27) || (c =='q') || (c=='Q'))
								{
									printf("Total errors %ld / %ld (%ld%%)\r\n", cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
									Crawcin();
									return(0);
								}							
							}
						}							
						printf("Total errors %ld / %ld (%ld%%)\r\n", cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
						Crawcin();
						return(0);
					case '4':
					case 'd':
					case 'D':
						while(1)
						{
							unsigned long rnd = Random();
							unsigned long offset = (((mapped_vram >> 1) - 1) & rnd);
							if(rnd & 1)
							{
								unsigned char val2 = 0;
								cnt_rw++;
								if((err = read_mem_byte(handle, offset, &val2)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
							}
							else if(rnd & 2)
							{
								unsigned short val2 = 0;
								cnt_rw++;
								if((err = read_mem_word(handle, offset, &val2)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
							}
							else
							{
								unsigned long val2 = 0;
								cnt_rw++;
								if((err = read_mem_longword(handle, offset, &val2)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
							}
/*							write_config_longword(0, MBOX0, cnt_rw); */
							c = (char)Crawio(255);
							if((c == 27) || (c =='q') || (c=='Q'))
							{
								printf("Total errors %ld / %ld (%ld%%)\r\n", cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								Crawcin();
								return(0);
							}
						}
					case '3':
					case 'c':
					case 'C':
						{
							unsigned long offset, val3 = 0;
							for(offset = 0; offset < (mapped_vram >> 1); offset += 4)
							{
								unsigned long val1 = (unsigned long)Random() + (offset << 16), val2 = 0;
								cnt_rw++;
								if((err = write_mem_longword(handle, offset, val1)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								cnt_rw++;
								if((err = read_mem_longword(handle, offset, &val2)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								if(val1 != val2)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Write 0x%08lx read 0x%08lx at 0x%08lx\r\n", val1, val2, (unsigned long)fb_base + offset);
								}
/*								write_config_longword(0, MBOX0, cnt_rw); */
								val1 += val3;
								c = (char)Crawio(255);
								if((c == 27) || (c =='q') || (c=='Q'))
								{
									printf("Total errors %ld / %ld (%ld%%)\r\n", cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
									printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
									Crawcin();
									return(0);
								}							
							}
						}							
						printf("Total errors %ld / %ld (%ld%%)\r\n", cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
						Crawcin();
						return(0);
					case '2':
					case 'b':
					case 'B':
						while(1)
						{
							unsigned long rnd = Random(), val3 = 0;
							unsigned long offset = (((mapped_vram >> 1) - 1) & rnd);
							if(rnd & 1)
							{
								unsigned char val1 = (unsigned char)Random(), val2 = 0;
								cnt_rw++;
								if((err = write_mem_byte(handle, offset, val1)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								cnt_rw++;
								if((err = read_mem_byte(handle, offset, &val2)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								if(val1 != val2)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Write 0x%02x read 0x%02x at 0x%08lx\r\n", (int)val1 & 0xff, (int)val2 & 0xff, (unsigned long)fb_base + offset);
								}
							}
							else if(rnd & 2)
							{
								unsigned short val1 = (unsigned short)Random(), val2 = 0;
								cnt_rw++;
								if((err = write_mem_word(handle, offset, val1)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								cnt_rw++;
								if((err = read_mem_word(handle, offset, &val2)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								if(val1 != val2)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Write 0x%04x read 0x%04x at 0x%08lx\r\n", val1, val2, (unsigned long)fb_base + offset);
								}
							}
							else
							{
								unsigned long val1 = (unsigned long)Random() + (offset << 16), val2 = 0;
								cnt_rw++;
								if((err = write_mem_longword(handle, offset, val1)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								cnt_rw++;
								if((err = read_mem_longword(handle, offset, &val2)) != 0)
								{
									cnt_err++;
									printf("Error %ld, Total errors %ld / %ld (%ld%%)\r\n", err, cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								}
								if(val1 != val2)
								{
									val3 = *(unsigned long *)0xA0000000;
									cnt_err_cmp++;
/*									write_config_longword(0, MBOX1, cnt_err_cmp); */
									printf("Write 0x%08lx read 0x%08lx at 0x%08lx\r\n", val1, val2, (unsigned long)fb_base + offset);
								}
							}
/*							write_config_longword(0, MBOX0, cnt_rw); */
							rnd += val3;
							c = (char)Crawio(255);
							if((c == 27) || (c =='q') || (c=='Q'))
							{
								printf("Total errors %ld / %ld (%ld%%)\r\n", cnt_err, cnt_rw, (cnt_err * 100UL) / cnt_rw);
								printf("Compare errors %ld / %ld (%ld%%)\r\n", cnt_err_cmp, cnt_rw, (cnt_err_cmp * 100UL) / cnt_rw);
								Crawcin();
								return(0);
							}
						}
					default:
						return(0);
					}
				}
			}
#endif
		}
	}
	return(0);
}

COOKIE *fcookie(void)
{
	COOKIE *p;
	long stack;
	stack=Super(0L);
	p=*(COOKIE **)0x5a0;
	Super((void *)stack);
	if(!p)
		return((COOKIE *)0);
	return(p);
}

COOKIE *ncookie(COOKIE *p)
{
	if(!p->ident)
		return(0);
	return(++p);
}

COOKIE *get_cookie(long id)
{
	COOKIE *p;
	p=fcookie();
	while(p)
	{
		if(p->ident==id)
			return p;
		p=ncookie(p);
	}
	return((COOKIE *)0);
}

int add_cookie(COOKIE *cook)
{
	COOKIE *p;
	int i=0;
	p=fcookie();
	while(p)
	{
		if(p->ident==cook->ident)
			return(-1);
		if(!p->ident)
		{
			if(i+1 < p->v.l)
			{
				*(p+1)=*p;
				*p=*cook;
				return(0);
			}
			else
				return(-2);			/* problem */
		}
		i++;
		p=ncookie(p);
	}
	return(-1);						/* no cookie-jar */
}
