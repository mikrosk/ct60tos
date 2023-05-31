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
#include "../radeon/radeonfb.h"

#ifdef COLDFIRE
#ifdef LWIP
#include "../../include/ramcf68k.h"
#undef Setexc
#define Setexc(num, vect) \
   *(unsigned long *)(((num) * 4) + coldfire_vector_base) = (unsigned long)vect
#include "../lwip/net.h"
#include "../lwip/cc.h"
#else /* !LWIP */
#include <osbind.h>
#include "../net/net.h"
#endif /* LWIP */
#endif /* COLDFIRE */

#include "dma_utils.h"

extern short use_dma; /* init.c */
extern struct radeonfb_info *rinfo_fvdi; /* fVDI */
extern char *Funcs_allocate_block(long size); /* fVDI */
extern void Funcs_free_block(void *address); /* fVDI */

#ifdef COLDFIRE

#ifdef NETWORK

#ifdef MCF5445X
#include "mcf5445x.h"
#else /* MCF548X */
#include "../mcdapi/MCD_dma.h"
#include "mcf548x.h"
#define V_DMA (64+48)
#define DMA_PRIORITY 6
#endif /* MCF5445X */

#ifndef MCF5445X
#undef USE_COMM_BUS /* works only with 32 bits transfers */
#define CHAINED_DMA /* not works with USE_COMM_BUS */
#endif

#ifdef USE_COMM_BUS
#define STEP_DMA 65532 /* maximum packet size */
#else
#define STEP_DMA 65536
#endif

extern void dma_interrupt(void);

#ifdef CHAINED_DMA
static unsigned long Descriptors;
static int Channel;
#endif

#ifdef MCF5445X
static char used_reqs[16];
#else /* MCF548X */
static char used_reqs[32];
#endif

typedef struct
{
	int req;
	void (*handler)(void);
} DMA_CHANNEL_STRUCT;

static DMA_CHANNEL_STRUCT dma_channel[NCHANNELS];

static void dma_int(int channel);
static void dma00(void) { dma_int(0); }
static void dma01(void) { dma_int(1); }
static void dma02(void) { dma_int(2); }
static void dma03(void) { dma_int(3); }
static void dma04(void) { dma_int(4); }
static void dma05(void) { dma_int(5); }
static void dma06(void) { dma_int(6); }
static void dma07(void) { dma_int(7); }
static void dma08(void) { dma_int(8); }
static void dma09(void) { dma_int(9); }
static void dma10(void) { dma_int(10); }
static void dma11(void) { dma_int(11); }
static void dma12(void) { dma_int(12); }
static void dma13(void) { dma_int(13); }
static void dma14(void) { dma_int(14); }
static void dma15(void) { dma_int(15); }
static void (*dma_handler[])(void) = { dma00,dma01,dma02,dma03,dma04,dma05,dma06,dma07,dma08,dma09,dma10,dma11,dma12,dma13,dma14,dma15 };

struct dma_block
{
	long count;
#ifdef CHAINED_DMA
	MCD_bufDesc *aligned_descriptors;
#else /* !CHAINED_DMA */
#ifdef USE_COMM_BUS
	long dir;
#endif
	char *src;
	char *dest;
	long width;
	long src_incr;
	long dest_incr;
	long step;
	long size_count;
#endif /* CHAINED_DMA */
	volatile long used;
};
struct dma_block dma_block_int[NCHANNELS];

static void dma_int(int channel)
{
#ifndef CHAINED_DMA
	long width, step;
#endif
	struct dma_block *p;
	asm("move.w #0x2700,SR");   /* disable interrupts */
	p = &dma_block_int[channel];
#ifndef CHAINED_DMA
	p->src += p->src_incr;
	p->dest += p->dest_incr;
	width = p->width;
	step = p->step;
	p->size_count -= width;
	if(p->size_count > 0)
	{
#ifdef MCF5445X
		struct tcd *dma_tcd = MCF_EDMA_TCD(channel);
		dma_tcd->citer = dma_tcd->biter = 1;
		dma_tcd->nbytes = (unsigned long)((p->size_count > width) ? width	: p->size_count);
		dma_tcd->saddr = (unsigned long)p->src;
		dma_tcd->soff = (unsigned short)step;
		dma_tcd->slast = 0;
		dma_tcd->daddr = (unsigned long)p->dest;
		dma_tcd->doff = (unsigned short)step;
		dma_tcd->dlast_sga = 0;
		switch(step)
		{
			case 1: dma_tcd->attr = 0x0000; break;
			case 2: dma_tcd->attr = 0x0101; break;
			case 4: dma_tcd->attr = 0x0202; break;
			default: 
				dma_channel[channel].req = -1;
				dma_channel[channel].handler = NULL;
				p->used = 0;			
				return;
		}
		dma_tcd->csr = DMA_CSR_INT_MAJOR;
		MCF_EDMA_CERQ = channel;
		MCF_EDMA_SSRT = channel;
		return;
#else /* MCF548X */
		width = (p->size_count > width) ? width	: p->size_count;
#ifdef USE_COMM_BUS
		if(p->dir == 1) /* PCI to Local Bus */
		{
			MCF_PCI_PCIRSAR = (unsigned long)p->src;
			MCF_PCI_PCIRPSR = MCF_PCI_PCIRPSR_PKTSIZE(width);	
			if(MCD_startDma(channel, (char *)&MCF_PCI_PCIRFDR, 0, p->dest, (short)step, (unsigned long)width, (unsigned long)step, DMA_PCI_RX, DMA_PRIORITY,
		   MCD_INTERRUPT | MCD_SINGLE_DMA | MCD_TT_FLAGS_CW | MCD_TT_FLAGS_RL | MCD_TT_FLAGS_SP, MCD_NO_BYTE_SWAP | MCD_NO_CSUM) == MCD_OK)
		 	  return;
		}
		else /* Local Bus to PCI */
		{
			MCF_PCI_PCITSAR = (unsigned long)p->dest;
			MCF_PCI_PCITPSR = MCF_PCI_PCITPSR_PKTSIZE(width);
			if(MCD_startDma(channel, p->src, (short)step, (char *)&MCF_PCI_PCITFDR, 0, (unsigned long)width, (unsigned long)step, DMA_PCI_TX, DMA_PRIORITY,
		   MCD_INTERRUPT | MCD_SINGLE_DMA | MCD_TT_FLAGS_CW | MCD_TT_FLAGS_RL | MCD_TT_FLAGS_SP, MCD_NO_BYTE_SWAP | MCD_NO_CSUM) == MCD_OK)
		 	  return;
		}
#else /* !USE_COMM_BUS */
		if(MCD_startDma(channel, p->src, (short)step, p->dest, (short)step, (unsigned long)width, (unsigned long)step, 0, DMA_PRIORITY, 
		 MCD_INTERRUPT | MCD_SINGLE_DMA | MCD_TT_FLAGS_CW | MCD_TT_FLAGS_RL | MCD_TT_FLAGS_SP, MCD_NO_BYTE_SWAP | MCD_NO_CSUM) == MCD_OK)
			return;
#endif /* USE_COMM_BUS */
#endif /* MCF5445X */
	}
#endif /* CHAINED_DMA */
	dma_channel[channel].req = -1;
	dma_channel[channel].handler = NULL;
#ifndef CHAINED_DMA
#ifdef USE_COMM_BUS
	if(p->dir == 1)
		MCF_PCI_PCIRER = 0;
	else
		MCF_PCI_PCITER = 0;
#endif
#endif
	p->count++;
	p->used = 0;
}

int dma_transfer(char *src, char *dest, int size, int width, int src_incr, int dest_incr, int step)
{
	struct dma_block *p; 
	int	channel;
#ifndef CHAINED_DMA
#ifdef USE_COMM_BUS
	char *screen = (char *)rinfo_fvdi->fb_base;
	if(((long)src & 3) || ((long)dest & 3) || (size & 3) || (width & 3))
		return(-1);
	step = 4; /* 32 bits only */	
#endif
#endif /* CHAINED_DMA */
	if(!use_dma || !size)
		return(-1);
	else
	{
		asm("clr.l -(SP)");		
		asm("move.l D0,-(SP)");
		asm("move.w SR,D0");
		asm("move.l D0,4(SP)");
		asm("or.l #0x700,D0");   /* disable interrupts */
		asm("move.w D0,SR");
		asm("move.l (SP)+,D0");
#ifdef CHAINED_DMA
		channel = dma_set_channel(DMA_ALWAYS, NULL);
#else /* !CHAINED_DMA */
#ifdef USE_COMM_BUS
		if(src >= screen)
			channel = dma_set_channel(DMA_PCI_RX, NULL); /* PCI to Local Bus */
		else if(dest >= screen)
			channel = dma_set_channel(DMA_PCI_TX, NULL); /* Local Bus To PCI */
		else
			channel = -1;
#else
		channel = dma_set_channel(DMA_ALWAYS, NULL);
#endif /* USE_COMM_BUS */
#endif /* CHAINED_DMA */
		if(channel >= 0)
		{
			dma_channel[channel].req = DMA_ALWAYS;
			dma_channel[channel].handler = dma_handler[channel];
		}
		asm("move.l D0,-(SP)");
		asm("move.l 4(SP),D0");
		asm("move.w D0,SR");
		asm("move.l (SP)+,D0");
		asm("addq.l #4,SP");		
	}
	if(channel < 0)
		return(-1);
	p = &dma_block_int[channel];
	if(p->used)
		return(-1);
#ifdef CHAINED_DMA
	p->used = 0;
	Channel = channel;
	Descriptors = (unsigned long)Funcs_allocate_block(((size / width) + 2) * 32);
	if(!Descriptors)
		return(-1);
	else
	{
		MCD_bufDesc *pd = (MCD_bufDesc *)((Descriptors + 31) & ~31); /* 32 bytes alignment */
		p->aligned_descriptors = pd;
		if(!width && !src_incr && !dest_incr)
//			width = src_incr = dest_incr = STEP_DMA;
			width = size;
		while(size > 0)
		{
			pd->flags = MCD_BUF_READY;
			pd->csumResult = 0;
			pd->srcAddr = src;
			pd->destAddr = dest;
			pd->lastDestAddr = dest + width;
			pd->dmaSize = (unsigned long)width;
			pd->next = &pd[1];
 			src += src_incr;
			dest += dest_incr;
			size -= width;
			pd++;
		}
		pd->flags =	pd->csumResult = pd->dmaSize = 0;
		pd->srcAddr = pd->destAddr = pd->lastDestAddr = NULL;
		pd->next = NULL;
		pd--;
		pd->flags |= MCD_INTERRUPT;
  }
#else /* !CHAINED_DMA */
#ifdef USE_COMM_BUS
	if(src >= screen) /* PCI to Local Bus */
	{
  	src -= ((unsigned long)screen - rinfo_fvdi->fb_base_phys); /* PCI mapping local -> offset PCI */
  	p->dir = 1;
	}
	else /* Local Bus To PCI */
	{
  	dest -= ((unsigned long)screen - rinfo_fvdi->fb_base_phys); /* PCI mapping local -> offset PCI */
  	p->dir = 2;
	}
#endif /* USE_COMM_BUS */
	p->src = src;
	p->dest = dest;
	p->step = (long)step;
	p->size_count = (long)size;
	if(width || src_incr || dest_incr)
	{
		p->src_incr = (long)src_incr;
		p->dest_incr = (long)dest_incr;
		p->width = (long)width;
		size = width;
	}
	else
	{
		p->width = p->src_incr = p->dest_incr = STEP_DMA;	
		if(size > STEP_DMA)
			size = STEP_DMA;
	}
#endif /* CHAINED_DMA */
 	/* flush data cache from the cf68klib */
	asm(" .chip 68060\n cpusha DC\n .chip 5200\n");
	p->used = 1;
#ifdef MCF5445X
	{
		struct tcd *dma_tcd = MCF_EDMA_TCD(channel);
		MCF_EDMA_CDNE = channel;
		dma_tcd->citer = dma_tcd->biter = 1;
		dma_tcd->nbytes = (unsigned long)size;
		dma_tcd->saddr = (unsigned long)src;
		dma_tcd->soff = (unsigned short)step;
		dma_tcd->slast = 0;
		dma_tcd->daddr = (unsigned long)dest;
		dma_tcd->doff = (unsigned short)step;
		dma_tcd->dlast_sga = 0;
		switch(step)
		{
			case 1: dma_tcd->attr = 0x0000; break;
			case 2: dma_tcd->attr = 0x0101; break;
			case 4: dma_tcd->attr = 0x0202; break;
			default: p->used = 0; return(-1);
		}
		dma_tcd->csr = DMA_CSR_INT_MAJOR;		
		MCF_EDMA_CERQ = channel;
		MCF_EDMA_SSRT = channel;
		return(0);
	}
#else /* MCF548X */
#ifdef CHAINED_DMA
	if(MCD_startDma(channel, (char *)p->aligned_descriptors, (short)step, dest, (short)step, (unsigned long)size, (unsigned long)step, 0, DMA_PRIORITY,
	 MCD_INTERRUPT | MCD_TT_FLAGS_CW | MCD_TT_FLAGS_RL | MCD_TT_FLAGS_SP, MCD_NO_BYTE_SWAP | MCD_NO_CSUM) == MCD_OK)
	 	return(0);
#else
#ifdef USE_COMM_BUS
	if(p->dir == 1) /* PCI to Local Bus */
	{
		MCF_PCI_PCIRER |= MCF_PCI_PCIRER_RC; /* reset controller */
		MCF_PCI_PCIRSAR = (unsigned long)src;
		if(width || src_incr || dest_incr)
			MCF_PCI_PCIRER &= ~MCF_PCI_PCIRER_CM; /* non-continuous mode */
		else
			MCF_PCI_PCIRER |= MCF_PCI_PCIRER_CM; /* continuous mode */
		MCF_PCI_PCIRER |= MCF_PCI_PCIRER_RF; /* reset fifo */
		MCF_PCI_PCIRER &= ~MCF_PCI_PCIRER_RF;
		MCF_PCI_PCIRFAR = MCF_PCI_PCIRFAR_ALARM(64);
		MCF_PCI_PCIRFCR = MCF_PCI_PCIRFCR_GR(4) | MCF_PCI_PCIRFCR_RXW_MSK | 0x40000; 
		MCF_PCI_PCIRER |= (MCF_PCI_PCIRER_FE | MCF_PCI_PCIRER_ME); /* flush + master enable */
		MCF_PCI_PCIRER &= ~MCF_PCI_PCIRER_RC; /* reset controller bit low */
		MCF_PCI_PCIRPSR = MCF_PCI_PCIRPSR_PKTSIZE(size);	
		if(MCD_startDma(channel, (char *)&MCF_PCI_PCIRFDR, 0, dest, (short)step, (unsigned long)size, (unsigned long)step, DMA_PCI_RX, DMA_PRIORITY,
	   MCD_INTERRUPT | MCD_SINGLE_DMA | MCD_TT_FLAGS_CW | MCD_TT_FLAGS_RL | MCD_TT_FLAGS_SP, MCD_NO_BYTE_SWAP | MCD_NO_CSUM) == MCD_OK)
	 	  return(0);
	}
	else /* Local Bus to PCI */
	{
		MCF_PCI_PCITER |= MCF_PCI_PCITER_RC; /* reset controller */
		MCF_PCI_PCITSAR = (unsigned long)dest;
		if(width || src_incr || dest_incr)
			MCF_PCI_PCITER &= ~MCF_PCI_PCITER_CM; /* non-continuous mode */
		else
			MCF_PCI_PCITER |= MCF_PCI_PCITER_CM; /* continuous mode */
		MCF_PCI_PCITER |= MCF_PCI_PCITER_RF; /* reset fifo */
		MCF_PCI_PCITER &= ~MCF_PCI_PCITER_RF;
		MCF_PCI_PCITFAR = MCF_PCI_PCITFAR_ALARM(64);
		MCF_PCI_PCITFCR = MCF_PCI_PCITFCR_GR(4) | MCF_PCI_PCITFCR_RXW_MSK; 
		MCF_PCI_PCITER |= MCF_PCI_PCITER_ME; /* master enable */
		MCF_PCI_PCITER &= ~MCF_PCI_PCITER_RC; /* reset controller bit low */
		MCF_PCI_PCITPSR = MCF_PCI_PCITPSR_PKTSIZE(size);
		if(MCD_startDma(channel, src, (short)step, (char *)&MCF_PCI_PCITFDR, 0, (unsigned long)size, (unsigned long)step, DMA_PCI_TX, DMA_PRIORITY,
	   MCD_INTERRUPT | MCD_SINGLE_DMA | MCD_TT_FLAGS_CW | MCD_TT_FLAGS_RL | MCD_TT_FLAGS_SP, MCD_NO_BYTE_SWAP | MCD_NO_CSUM) == MCD_OK)
	 	  return(0);
	}
#else /* !USE_COMM_BUS */
	if(MCD_startDma(channel, src, (short)step, dest, (short)step, (unsigned long)size, (unsigned long)step, 0, DMA_PRIORITY,
	 MCD_INTERRUPT | MCD_SINGLE_DMA | MCD_TT_FLAGS_CW | MCD_TT_FLAGS_RL | MCD_TT_FLAGS_SP, MCD_NO_BYTE_SWAP | MCD_NO_CSUM) == MCD_OK)
	 	return(0);
#endif /* USE_COMM_BUS */
#endif /* CHAINED_DMA */
#endif /* MCF5445X */
	p->used = 0;
	return(-1);
}

int dma_status(void)
{
	struct dma_block *p = dma_block_int; 
	int channel;
	if(!use_dma)
		return(-1);
	for(channel = NCHANNELS-1; channel >= 0; channel--)
	{
		if(p->used)
			return(1);
		p++;
	}
	return(0);
}

void wait_dma(void)
{
#ifdef CHAINED_DMA
	if(use_dma && Descriptors)
	{
		while(dma_status() > 0);
		Funcs_free_block((void *)Descriptors);
		Descriptors = 0;
	}
#else
	struct dma_block *p = dma_block_int; 
	int channel;
	if(use_dma)
	{
		for(channel = NCHANNELS-1; channel >= 0; channel--)
		{
			while(p->used);
			p++;
		}
	}
#endif
}

void dma_init_tables(void)
{
  int i;
#ifdef MCF5445X
  used_reqs[0] = DMA_DREQ0;
  used_reqs[1] = DMA_DREQ1;
  used_reqs[2] = DMA_UART0_RX;
  used_reqs[3] = DMA_UART0_TX;
  used_reqs[4] = DMA_UART1_RX;
  used_reqs[5] = DMA_UART1_TX;
  used_reqs[6] = DMA_UART2_RX;
  used_reqs[7] = DMA_UART2_TX;
  used_reqs[8] = DMA_TIM0_SSI0RX;
  used_reqs[9] = DMA_TIM1_SSI1RX;
  used_reqs[10] = DMA_TIM2_SSI0TX;
  used_reqs[11] = DMA_TIM3_SSI1TX;
  used_reqs[12] = DMA_DSPI_RX;
  used_reqs[13] = DMA_DSPI_TX;
  used_reqs[14] = DMA_ATA_RX;
  used_reqs[15] = DMA_ATA_TX;    
#else /* MCF548X */
  used_reqs[0] = DMA_ALWAYS;
  used_reqs[1] = DMA_DSPI_RX;
  used_reqs[2] = DMA_DSPI_TX;
  used_reqs[3] = DMA_DREQ0;
  used_reqs[4] = DMA_PSC0_RX;
  used_reqs[5] = DMA_PSC0_TX;
  used_reqs[6] = DMA_USBEP0;
  used_reqs[7] = DMA_USBEP1;
  used_reqs[8] = DMA_USBEP2;
  used_reqs[9] = DMA_USBEP3;
  used_reqs[10] = DMA_PCI_TX;
  used_reqs[11] = DMA_PCI_RX;
  used_reqs[12] = DMA_PSC1_RX;
  used_reqs[13] = DMA_PSC1_TX;
  used_reqs[14] = DMA_I2C_RX;
  used_reqs[15] = DMA_I2C_TX;
  for(i=16; i<32; used_reqs[i++] = 0);
#endif
  for(i=0; i<NCHANNELS; i++)
  {
    dma_channel[i].req = -1;
    dma_channel[i].handler = NULL;
  }
}

#ifndef LWIP
static void dmainterrupt(void)
{
  asm("_dma_interrupt:\n lea -24(SP),SP\n movem.l D0-D2/A0-A2,(SP)\n");
  asm(" jsr _dma_interrupt_handler\n");
  asm(" movem.l (SP),D0-D2/A0-A2\n lea 24(SP),SP\n rte\n");
}
#endif

void dma_interrupt_handler(void)
{
#ifdef MCF5445X
  unsigned short i, interrupts;
  /* Determine which interrupt(s) triggered */
  interrupts = MCF_EDMA_CINT;
  /* Clear the interrupt in the pending register */
  MCF_EDMA_CINT = interrupts;
#else /* MCF548X */
  unsigned long i, interrupts;
  /* Determine which interrupt(s) triggered by AND'ing the
     pending interrupts with those that aren't masked. */
  interrupts = MCF_DMA_DIPR & ~MCF_DMA_DIMR;
  /* Clear the interrupt in the pending register */
  MCF_DMA_DIPR = interrupts;
#endif
  for(i=0; i<16; ++i, interrupts>>=1)
  {
    if(interrupts & 1)
    {
      /* If there is a handler, call it */
      if(dma_channel[i].handler != NULL)
        dma_channel[i].handler();
    }
  }
}

void init_dma(void)
{
#ifdef MCF5445X
  int i;
#endif
#ifndef LWIP
  if(dmainterrupt);
#endif
#ifdef CHAINED_DMA
	Descriptors = 0;
  Channel = -1;
#endif
  dma_init_tables();
	memset(dma_block_int, 0, sizeof(dma_block_int));
#ifdef MCF5445X
  /* Configure Interrupt vectors */
  for(i=0; i<NCHANNELS; i++)
    Setexc(64+INT0_LO_EDMA_00, dma_interrupt);
#else /* MCF548X */
  /* Initialize the Multi-channel DMA */
  MCD_initDma((dmaRegs*)(__MBAR+0x8000), (void *)__MCDAPI_START, MCD_COMM_PREFETCH_EN | MCD_RELOC_TASKS);
  /* Configure Interrupt vector */
   Setexc(V_DMA, dma_interrupt);
#endif
  /* Enable interrupts in DMA and INTC */
  dma_irq_enable(DMA_INTC_LVL, DMA_INTC_PRI);
}

void dma_irq_enable(uint8 lvl, uint8 pri)
{
#ifdef MCF5445X
  /* Setup the DMA ICR */
  MCF_INTC_ICR0n(INT0_LO_EDMA_00) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_01) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_02) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_03) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_04) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_05) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_06) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_07) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_08) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_09) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_10) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_11) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_12) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_13) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_14) = INTC_ICR_IL(lvl);
  MCF_INTC_ICR0n(INT0_LO_EDMA_15) = INTC_ICR_IL(lvl);
  /* Unmask all task interrupts */

  /* Clear the interrupt pending register */
  MCF_EDMA_INT = 0;
  /* Unmask the DMA interrupt in the interrupt controller */
  MCF_INTC_IMRL0 &= ~(INTC_IMRL_INT_MASK8
   | INTC_IMRL_INT_MASK9
   | INTC_IMRL_INT_MASK10
   | INTC_IMRL_INT_MASK11
   | INTC_IMRL_INT_MASK12
   | INTC_IMRL_INT_MASK13
   | INTC_IMRL_INT_MASK14
   | INTC_IMRL_INT_MASK15
   | INTC_IMRL_INT_MASK16
   | INTC_IMRL_INT_MASK17
   | INTC_IMRL_INT_MASK18
   | INTC_IMRL_INT_MASK19
   | INTC_IMRL_INT_MASK20
   | INTC_IMRL_INT_MASK21
   | INTC_IMRL_INT_MASK22
   | INTC_IMRL_INT_MASK23);
#else /* MCF548X */
  /* Setup the DMA ICR (#48) */
  MCF_INTC_ICR48 = MCF_INTC_ICRn_IP(pri) | MCF_INTC_ICRn_IL(lvl);
  /* Unmask all task interrupts */
  MCF_DMA_DIMR = 0;
  /* Clear the interrupt pending register */
  MCF_DMA_DIPR = 0;
  /* Unmask the DMA interrupt in the interrupt controller */
  MCF_INTC_IMRH &= ~MCF_INTC_IMRH_INT_MASK48;
#endif
}

void dma_irq_disable(void)
{
#ifdef MCF5445X
  /* Mask all task interrupts */

  /* Clear any pending task interrupts */
  MCF_EDMA_INT = (uint16)~0;
  /* Mask the DMA interrupt in the interrupt controller */
  MCF_INTC_IMRL0 &= (INTC_IMRL_INT_MASK8
   | INTC_IMRL_INT_MASK9
   | INTC_IMRL_INT_MASK10
   | INTC_IMRL_INT_MASK11
   | INTC_IMRL_INT_MASK12
   | INTC_IMRL_INT_MASK13
   | INTC_IMRL_INT_MASK14
   | INTC_IMRL_INT_MASK15
   | INTC_IMRL_INT_MASK16
   | INTC_IMRL_INT_MASK17
   | INTC_IMRL_INT_MASK18
   | INTC_IMRL_INT_MASK19
   | INTC_IMRL_INT_MASK20
   | INTC_IMRL_INT_MASK21
   | INTC_IMRL_INT_MASK22
   | INTC_IMRL_INT_MASK23);
#else /* MCF548X */
  /* Mask all task interrupts */
  MCF_DMA_DIMR = (unsigned long)~0;
  /* Clear any pending task interrupts */
  MCF_DMA_DIPR = (unsigned long)~0;
  /* Mask the DMA interrupt in the interrupt controller */
  MCF_INTC_IMRH |= MCF_INTC_IMRH_INT_MASK48;
#endif
}

int dma_set_initiator(int initiator)
{
#ifndef MCF5445X
  switch(initiator)
  {
    case DMA_ALWAYS:
    case DMA_DSPI_RX:
    case DMA_DSPI_TX:
    case DMA_DREQ0:
    case DMA_PSC0_RX:
    case DMA_PSC0_TX:
    case DMA_USBEP0:
    case DMA_USBEP1:
    case DMA_USBEP2:
    case DMA_USBEP3:
    case DMA_PCI_TX:
    case DMA_PCI_RX:
    case DMA_PSC1_RX:
    case DMA_PSC1_TX:
    case DMA_I2C_RX:
    case DMA_I2C_TX:
      /* These initiators are always active */
      break;
    case DMA_FEC0_RX:
      MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC16(3)) | MCF_DMA_IMCR_SRC16_FEC0RX;
      used_reqs[16] = DMA_FEC0_RX;
      break;
    case DMA_FEC0_TX:
      MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC17(3)) | MCF_DMA_IMCR_SRC17_FEC0TX;
      used_reqs[17] = DMA_FEC0_TX;
      break;
    case DMA_FEC1_RX:
      MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC20(3)) | MCF_DMA_IMCR_SRC20_FEC1RX;
      used_reqs[20] = DMA_FEC1_RX;
      break;
    case DMA_FEC1_TX:
      if(used_reqs[21] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC21(3)) | MCF_DMA_IMCR_SRC21_FEC1TX;
        used_reqs[21] = DMA_FEC1_TX;
      }
      else if(used_reqs[25] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC25(3)) | MCF_DMA_IMCR_SRC25_FEC1TX;
        used_reqs[25] = DMA_FEC1_TX;
      }
      else if(used_reqs[31] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC31(3)) | MCF_DMA_IMCR_SRC31_FEC1TX;
        used_reqs[31] = DMA_FEC1_TX;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_DREQ1:
      if(used_reqs[29] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC29(3)) | MCF_DMA_IMCR_SRC29_DREQ1;
        used_reqs[29] = DMA_DREQ1;
      }
      else if(used_reqs[21] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC21(3)) | MCF_DMA_IMCR_SRC21_DREQ1;
        used_reqs[21] = DMA_DREQ1;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_CTM0:
      if(used_reqs[24] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC24(3)) | MCF_DMA_IMCR_SRC24_CTM0;
        used_reqs[24] = DMA_CTM0;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_CTM1:
      if(used_reqs[25] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC25(3)) | MCF_DMA_IMCR_SRC25_CTM1;
        used_reqs[25] = DMA_CTM1;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_CTM2:
      if(used_reqs[26] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC26(3)) | MCF_DMA_IMCR_SRC26_CTM2;
        used_reqs[26] = DMA_CTM2;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_CTM3:
      if(used_reqs[27] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC27(3)) | MCF_DMA_IMCR_SRC27_CTM3;
        used_reqs[27] = DMA_CTM3;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_CTM4:
      if(used_reqs[28] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC28(3)) | MCF_DMA_IMCR_SRC28_CTM4;
        used_reqs[28] = DMA_CTM4;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_CTM5:
      if(used_reqs[29] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC29(3)) | MCF_DMA_IMCR_SRC29_CTM5;
        used_reqs[29] = DMA_CTM5;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_CTM6:
      if(used_reqs[30] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC30(3)) | MCF_DMA_IMCR_SRC30_CTM6;
        used_reqs[30] = DMA_CTM6;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_CTM7:
      if(used_reqs[31] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC31(3)) | MCF_DMA_IMCR_SRC31_CTM7;
        used_reqs[31] = DMA_CTM7;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_USBEP4:
      if(used_reqs[26] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC26(3)) | MCF_DMA_IMCR_SRC26_USBEP4;
        used_reqs[26] = DMA_USBEP4;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_USBEP5:
      if(used_reqs[27] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC27(3)) | MCF_DMA_IMCR_SRC27_USBEP5;
        used_reqs[27] = DMA_USBEP5;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_USBEP6:
      if(used_reqs[28] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC28(3)) | MCF_DMA_IMCR_SRC28_USBEP6;
        used_reqs[28] = DMA_USBEP6;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_PSC2_RX:
      if(used_reqs[28] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC28(3)) | MCF_DMA_IMCR_SRC28_PSC2RX;
        used_reqs[28] = DMA_PSC2_RX;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_PSC2_TX:
      if(used_reqs[29] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC29(3)) | MCF_DMA_IMCR_SRC29_PSC2TX;
        used_reqs[29] = DMA_PSC2_TX;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_PSC3_RX:
      if(used_reqs[30] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC30(3)) | MCF_DMA_IMCR_SRC30_PSC3RX;
        used_reqs[30] = DMA_PSC3_RX;
      }
      else /* No empty slots */
        return 1;
      break;
    case DMA_PSC3_TX:
      if(used_reqs[31] == 0)
      {
        MCF_DMA_IMCR = (MCF_DMA_IMCR & ~MCF_DMA_IMCR_SRC31(3)) | MCF_DMA_IMCR_SRC31_PSC3TX;
        used_reqs[31] = DMA_PSC3_TX;
      }
      else /* No empty slots */
        return 1;
      break;
    default: return 1;
  }
#endif
  return 0;
}

unsigned long dma_get_initiator(int requestor)
{
  unsigned long i;
  for(i=0; i<sizeof(used_reqs); ++i)
  {
    if(used_reqs[i] == requestor)
      return i;
  }
  return 0;
}

void dma_free_initiator(int requestor)
{
  unsigned long i;
  for(i=16; i<sizeof(used_reqs); ++i)
  {
    if(used_reqs[i] == requestor)
    {
      used_reqs[i] = 0; break;
    }
  }
}

int dma_set_channel(int requestor, void (*handler)(void))
{
  int i;
  /* Check to see if this requestor is already assigned to a channel */
  if(requestor && (i = dma_get_channel(requestor)) != -1)
    return i;
  for(i=0; i<NCHANNELS; ++i)
  {
    if(dma_channel[i].req == -1)
    {
      dma_channel[i].req = requestor;
      dma_channel[i].handler = handler;
      return i;
    }
  }
  /* All channels taken */
  return -1;
}

int dma_get_channel(int requestor)
{
  unsigned long i;
  for(i=0; i<NCHANNELS; ++i)
  {
    if(dma_channel[i].req == requestor)
      return i;
  }
  return -1;
}

void dma_free_channel(int requestor)
{
  unsigned long i;
  for(i=0; i<NCHANNELS; ++i)
  {
    if(dma_channel[i].req == requestor)
    {
      dma_channel[i].req = -1;
      dma_channel[i].handler = NULL;
      break;
    }
  }
}

void dma_clear_channel(int channel)
{
  if(channel >= 0 && channel < NCHANNELS)
  {
    dma_channel[channel].req = -1;
    dma_channel[channel].handler = NULL;
  }
}

#endif /* NETWORK */

#else /* !COLDFIRE => CT60 / CTPCI / PLX via XBIOS or PCI BIOS */

#define DMAMODE0 0x100   /* DMA Channel 0 Mode                  */
#define DMAPADR0 0x104   /* DMA Channel 0 PCI Address           */
#define DMALADR0 0x108   /* DMA Channel 0 Local Address         */
#define DMASIZ0  0x10C   /* DMA Channel 0 Transfer Size (Bytes) */
#define DMADPR0  0x110   /* DMA Channel 0 Descriptor Pointer    */
#define DMASCR0  0x128   /* DMA Channel 0 Command/Status        */

#undef DMA_XBIOS

static unsigned long Descriptors;

int dma_transfer(char *src, char *dest, int size, int width, int src_incr, int dest_incr, int step)
{
	extern void	cpush_dc(void *base, long size);
	short dir;
	unsigned long direction;
	unsigned char mode;
#ifndef DMA_XBIOS
	unsigned char status;
#endif
	if(step);
	if(!use_dma || !size)
		return(-1);
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
	if(src >= (char *)rinfo_fvdi->fb_base)
		dir = 1; /* PCI to Local Bus */
	else if(dest >= (char *)rinfo_fvdi->fb_base)
		dir = 2; /* Local Bus To PCI */
	else
		return(-1);
  if(dir == 1)
  	src -= ((unsigned long)rinfo_fvdi->fb_base - rinfo_fvdi->fb_base_phys); /* PCI mapping local -> offset PCI */
	else
	{
		char *temp = src;
  	dest -= ((unsigned long)rinfo_fvdi->fb_base - rinfo_fvdi->fb_base_phys); /* PCI mapping local -> offset PCI */
  	src = dest;
  	dest = temp;
  }
	direction = (dir == 1) ? 0 : 8;
	if((width || src_incr || dest_incr) && (size > width)) /* line by line */
	{
#ifdef DMA_XBIOS
		if(tab_funcs_pci == NULL) /* table of functions */
			return(-1);
#endif
		Descriptors = (unsigned long)Funcs_allocate_block(((size / width) + 1) * 16); /* descriptor / line */
		if(Descriptors)
		{
			unsigned long *aligned_descriptors = (unsigned long *)((Descriptors + 15) & ~15); /* 16 bytes alignment */
			unsigned long *p = aligned_descriptors;
			if(dir == 2) /* Local Bus To PCI */
				cpush_dc(dest,size); /* flush data cache */
			/* load the 1st descriptor in the PLX registers */
			Write_config_longword(0, DMAPADR0, (unsigned long)src);
			Write_config_longword(0, DMALADR0, (unsigned long)dest);
			Write_config_longword(0, DMASIZ0, (unsigned long)width);
			Write_config_longword(0, DMADPR0, (unsigned long)p + direction);
			while(size > 0)
			{
				unsigned long next = (unsigned long)p + direction;
				*p++ = (unsigned long)src;   /* PCI address */
				*p++ = (unsigned long)dest;  /* local address */
				*p++ = (unsigned long)width; /* transfer size */
				*p++ = next;                 /* next descriptor pointer */
				src += src_incr;
				dest += dest_incr;
				size -= width;
			}		
			p[-1] |= 2; /* end of chain */ 
			cpush_dc(aligned_descriptors,(long)(p-aligned_descriptors)); /* flush data cache */
			mode = Fast_read_config_byte(0, DMAMODE0); 
			mode |= 0x200;                 /* scatter/gather mode */
			Write_config_longword(0, DMAMODE0, mode);
			Write_config_longword(0, DMASCR0, 3); /* start & enable */
		}
		else /* no memory block for descriptors */
			return(-1);
	}
	else /* full block */
	{
		if(dir == 2) /* Local Bus To PCI */
			cpush_dc(dest,size); /* flush data cache */
#ifdef DMA_XBIOS
		dma_setbuffer(src,dest,size);
		dma_buffoper(dir);
#else /* direct PCI BIOS (by cookie) */
		Write_config_longword(0, DMAPADR0, (unsigned long)src);  /* PCI Address */
		Write_config_longword(0, DMALADR0, (unsigned long)dest); /* Local Address */
		Write_config_longword(0, DMASIZ0, (unsigned long)width); /* Transfer Size (Bytes) */
		Write_config_longword(0, DMADPR0, (unsigned long)direction); /* Descriptor Pointer */
		mode = Fast_read_config_byte(0, DMAMODE0); 
		mode &= ~0x200;                       /* block mode */
		Write_config_longword(0, DMAMODE0, mode);
		Write_config_longword(0, DMASCR0, 3); /* start & enable */
#endif
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
	if(use_dma)
		while(dma_status() > 0);
	if(Descriptors)
		Funcs_free_block((void *)Descriptors);
	Descriptors = 0;
}

#endif /* COLDFIRE */

