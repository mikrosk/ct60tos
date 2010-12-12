/*
 * Driver for the PSC of the Freescale MCF548X configured as AC97 interface
 *
 * Copyright (C) 2009 Didier Mequignon.
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
#include <string.h>
#include <osbind.h>
#include <mint/falcon.h>
#ifdef LWIP
#include "../../include/ramcf68k.h"
#undef Setexc
#define Setexc(num, vect) \
   *(unsigned long *)(((num) * 4) + coldfire_vector_base) = (unsigned long)vect
#include "../lwip/net.h"
#include "../freertos/FreeRTOS.h"
#include "../freertos/task.h"
#else
#include "../net/net.h"
#endif /* LWIP */
#include "mcf548x.h"
#include "core.h"

#undef USE_DMA

#include "ac97_codec.h"
#include "mcf548x_ac97.h"

#ifdef USE_DMA
#include "../mcdapi/MCD_dma.h"
#include "../dma_utils/dma_utils.h"
#endif

#define AC97_BUF_USE_SYSTEM_RAM

#define DEBUG
#define PERIOD

#ifdef SOUND_AC97
#ifdef NETWORK /* for DMA API */

/* ======================================================================== */
/* Structs / Defines                                                        */
/* ======================================================================== */

#define MCF_PSC0_VECTOR                 (64 + 35)
#define MCF_PSC1_VECTOR                 (64 + 34)
#define MCF_PSC2_VECTOR                 (64 + 33)
#define MCF_PSC3_VECTOR                 (64 + 32)

#define AC97_INTC_LVL 7
#define AC97_INTC_PRI 0

#define AC97_TX_NUM_BD 2
#define AC97_RX_NUM_BD 2
#define AC97_SLOTS 13
#define AC97_SAMPLES_BY_BUFFER 48
#define AC97_SAMPLES_BY_FIFO 5 /* 8 MAX */

#define AC97_RETRY_WRITE 10
#define AC97_TIMEOUT 10000000 /* 100 mS */

#ifdef USE_DMA

#define AC97_DMA_SIZE (4 * AC97_SLOTS * AC97_SAMPLES_BY_BUFFER)

#define DMA_PSC_RX(x)   ((x == 0) ? DMA_PSC0_RX : ((x == 1) ? DMA_PSC1_RX : ((x == 2) ? DMA_PSC2_RX : DMA_PSC3_RX)))
#define DMA_PSC_TX(x)   ((x == 0) ? DMA_PSC0_TX : ((x == 1) ? DMA_PSC1_TX : ((x == 2) ? DMA_PSC2_TX : DMA_PSC3_TX)))

#define MCF_PSC_RFDR(x) (*(vuint32*)(&__MBAR[0x008660+((x)*0x100)]))
#define MCF_PSC_TFDR(x) (*(vuint32*)(&__MBAR[0x008680+((x)*0x100)]))
#define MCF_PSC_RFDR_ADDR(x) ((void*)(&__MBAR[0x008660+((x)*0x100)]))
#define MCF_PSC_TFDR_ADDR(x) ((void*)(&__MBAR[0x008680+((x)*0x100)]))

#define PSCRX_DMA_PRI 3
#define PSCTX_DMA_PRI 4

#endif /* USE_DMA */

/* Private structure */
struct mcf548x_ac97_priv {
#ifdef PERIOD
	unsigned long time_get_frame;
	unsigned long time_build_frame;
	unsigned long period_get_frame;
	unsigned long period_build_frame;
	unsigned long previous_get_frame;
	unsigned long previous_build_frame;
#endif
	unsigned long cnt_rx;
	unsigned long cnt_tx;
	unsigned long cnt_error_fifo_rx;
	unsigned long cnt_error_fifo_tx;
	unsigned short last_error_fifo_rx;
	unsigned short last_error_fifo_tx;
	unsigned long cnt_error_sync;
	unsigned long cnt_error_empty_tx;
#ifdef DEBUG
	unsigned short tab_num_frames[AC97_SAMPLES_BY_BUFFER];
	unsigned long err_no_rx;
#endif
	int psc_channel;
	int open_play;
	int open_record;
	volatile int ctrl_mode;
	int ctrl_rw;
	int ctrl_address;
	int ctrl_data;
	int status_data;
#ifndef USE_DMA
	unsigned long cnt_rx_frame;
	unsigned long pos_rx_frame;
	unsigned long cnt_tx_frame;
	unsigned long pos_tx_frame;
	unsigned long tx_frame[AC97_SLOTS * AC97_SAMPLES_BY_BUFFER];
	unsigned long temp_frame[AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 2];
	unsigned long rx_frame[AC97_SLOTS * AC97_SAMPLES_BY_BUFFER];
#endif
	int play_record_mode;
	int play_res;
	int record_res;
	volatile int codec_ready;
	long freq_codec;
	long freq_dac;
	long play_frequency;
	long freq_adc;
	long record_frequency;
	int cnt_slot_rx;
	unsigned char slotreq[AC97_SAMPLES_BY_BUFFER];
	unsigned char incr_offsets_play[AC97_SAMPLES_BY_BUFFER+1];
	unsigned char incr_offsets_record[AC97_SAMPLES_BY_BUFFER+1];
	void *play_samples;
	void *play_start_samples;
	void *play_end_samples;
	void *new_play_start_samples;
	void *new_play_end_samples;
	void *record_samples;
	void *record_start_samples;
	void *record_end_samples;
	void *new_record_start_samples;
	void *new_record_end_samples;
	int cause_inter;
	void (*callback_play)();
	void (*callback_record)();
#ifdef USE_DMA
	MCD_bufDesc *txbd;
	MCD_bufDesc *rxbd;
	void *buffer;
	int tx_bd_idx;
	int rx_bd_idx;
#endif
	struct snd_card *card;
	struct snd_ac97 *ac97;
};

extern unsigned char __MBAR[];
extern unsigned char __MCDAPI_START[];
#ifdef USE_DMA
static MCD_bufDesc *Descriptors = (MCD_bufDesc *)(__MBAR+0x17B00);
#endif
static struct mcf548x_ac97_priv *Devices[4]; 

extern int asm_set_ipl(int level);
extern void udelay(long usec);
extern void call_timer_a(void);
extern void call_io7_mfp(void);
extern void display_string(char *string);
extern void ltoa(char *buf, long n, unsigned long base);
extern void psc0_ac97_interrupt(void);
extern void psc1_ac97_interrupt(void);
extern void psc2_ac97_interrupt(void);
extern void psc3_ac97_interrupt(void);

static int mcf548x_ac97_swap_record_buffers(struct mcf548x_ac97_priv *priv)
{
	int ret = 0;
	if(priv->play_record_mode && SB_REC_RPT)
	{
		if((priv->new_record_start_samples != NULL)
		 && (priv->new_record_end_samples != NULL))
		{
			priv->record_samples = priv->record_start_samples = priv->new_record_start_samples;
			priv->record_end_samples = priv->new_record_end_samples;
			priv->new_record_start_samples = NULL;
			priv->new_record_end_samples = NULL;
		}
		else // loop
			priv->record_samples = priv->record_start_samples;
		ret = 1; // swap => continue record
	}
	else
	{
		priv->record_samples = NULL;
		priv->play_record_mode &= ~SB_REC_ENA;
	}
	switch(priv->cause_inter)
	{
		case 0:
			if(priv->callback_record != NULL)
				priv->callback_record();
			break;
		/* Timer A */
		case SI_RECORD:
		case SI_BOTH:
			call_timer_a(); // XBIOS
			break;
		/* IO7 */
		case SI_RECORD + 0x100:
		case SI_BOTH + 0x100:		
			call_io7_mfp(); // XBIOS
			break;	
	}
	return(ret);
}

//static
int mcf548x_ac97_get_frame(struct mcf548x_ac97_priv *priv, int num_frames)
{
	int i;
	unsigned long tag, addr, data, pcm_left, pcm_right;
#ifdef PERIOD
	unsigned long start_time = MCF_SLT_SCNT(1);
#endif
	int ctrl_mode = priv->ctrl_mode;
	int cnt_slot = priv->cnt_slot_rx;
#ifdef USE_DMA
	MCD_bufDesc *ptdesc = priv->rxbd;
	unsigned long *status = (unsigned long *)ptdesc[priv->rx_bd_idx].destAddr;
#else
	int j;
	unsigned long pos = priv->pos_rx_frame;
	unsigned long *status = &priv->rx_frame[pos];
	if(num_frames <= 0)
		return(-1);
#ifdef PERIOD
	if(priv->previous_get_frame)
	{
		unsigned long period = (priv->previous_get_frame - start_time) / 100;
		if(period > priv->period_get_frame)
			priv->period_get_frame = period;
	}
	priv->previous_get_frame = start_time;
#endif /* PERIOD */
	if(priv->cnt_rx_frame >= pos)
	{
		pos += ((unsigned long)num_frames * AC97_SLOTS);
		pos %= (AC97_SLOTS * AC97_SAMPLES_BY_BUFFER);
	}		
	else
	{
		unsigned long *p1 = priv->rx_frame;
		unsigned long *p2 = priv->temp_frame;
		j = num_frames;
		if(j >= (AC97_SAMPLES_BY_FIFO * 2))
			j = (AC97_SAMPLES_BY_FIFO * 2);
		j *= AC97_SLOTS;
		while(--j >= 0)
		{
			*p2++ = p1[pos++];
			if(pos >= (AC97_SLOTS * AC97_SAMPLES_BY_BUFFER))
				pos = 0;
		}
		status = priv->temp_frame;
	}
	priv->pos_rx_frame = pos;
#endif
	if(!((priv->play_record_mode & SB_REC_ENA)
	 && (priv->record_samples != NULL)))
	{
		for(i = 0; i < num_frames; i++)
		{	
			tag = status[AC97_SLOT_TAG];
			if(!(tag & MCF_PSC_TB_AC97_SOF))
			{
				status += AC97_SLOTS;
				continue;
			}
			addr = status[AC97_SLOT_CMD_ADDR];
			data = status[AC97_SLOT_CMD_DATA];
			pcm_left = status[AC97_SLOT_PCM_LEFT];
			pcm_right = status[AC97_SLOT_PCM_RIGHT];
			priv->slotreq[cnt_slot++] = (unsigned char)(addr >> 16);
			if(cnt_slot >= AC97_SAMPLES_BY_BUFFER)
				cnt_slot = 0;
			if(ctrl_mode && priv->ctrl_rw // read
			 && ((tag >> 29) == 7) // codec ready && Slot #1 && Slot #2
			 && (((addr >> 24) & 0x7f) == priv->ctrl_address))
			{
				priv->status_data = data >> 16;
				ctrl_mode = 0;  // OK
			}	
			status += AC97_SLOTS;
		}	
	}
	else /* record */
	{	
		char *cptr = (char *)priv->record_samples;
		short *sptr = (short *)cptr;
		void *end_ptr = priv->record_end_samples;
		char cl = 0, cr = 0;
		short sl = 0, sr = 0;
		int incr = 0, vra = 1;
		if((priv->record_frequency != priv->freq_adc))
		{
			int coeff = priv->freq_adc / AC97_SAMPLES_BY_BUFFER;
			int new_samples_by_buffer = priv->record_frequency / coeff;
			if((priv->record_frequency % coeff) >= (coeff >> 1))
				new_samples_by_buffer++;
			vra = 0;		
			if(new_samples_by_buffer > AC97_SAMPLES_BY_BUFFER)
				incr = new_samples_by_buffer - AC97_SAMPLES_BY_BUFFER; // required frequency > 48000 Hz => add last sample(s)
		}
		for(i = 0; i < num_frames; i++)
		{	
			tag = status[AC97_SLOT_TAG];
			if(!(tag & MCF_PSC_TB_AC97_SOF))
			{
				status += AC97_SLOTS;
				continue;
			}
			addr = status[AC97_SLOT_CMD_ADDR];
			data = status[AC97_SLOT_CMD_DATA];
			pcm_left = status[AC97_SLOT_PCM_LEFT];
			pcm_right = status[AC97_SLOT_PCM_RIGHT];
			priv->slotreq[cnt_slot++] = (unsigned char)(addr >> 16);
			if(cnt_slot >= AC97_SAMPLES_BY_BUFFER)
				cnt_slot = 0;
			if(ctrl_mode && priv->ctrl_rw // read
			 && ((tag >> 29) == 7) // codec ready && Slot #1 && Slot #2
			 && (((addr >> 24) & 0x7f) == priv->ctrl_address))
			{
				priv->status_data = data >> 16;
				ctrl_mode = 0;  // OK
			}
			if(((tag >> 27) & 3) == 3)
			{
				switch(priv->record_res)
				{
					case RECORD_STEREO8:
						if(vra)
						{
							*cptr++ = (char)(pcm_left >> 24);
							*cptr++ = (char)(pcm_right >> 24);
						}
						else
						{
							cl = cptr[0] = (char)(pcm_left >> 24);
							cr = cptr[1] = (char)(pcm_right >> 24);
					  	cptr += priv->incr_offsets_record[i];
						}
				  	if((void *)cptr >= end_ptr)
				  	{
							mcf548x_ac97_swap_record_buffers(priv);
							cptr = (char *)priv->record_samples;
							end_ptr = priv->record_end_samples;
						}
					  break;
					case RECORD_STEREO16:
						if(vra)
						{
							*sptr++ = (short)(pcm_left >> 16);
							*sptr++ = (short)(pcm_right >> 16);
						}
						else
						{
							sl = sptr[0] = (short)(pcm_left >> 16);
							sr = sptr[1] = (short)(pcm_right >> 16);
					  	sptr += priv->incr_offsets_record[i];
						}
					  if((void *)sptr >= end_ptr)
					  {
							mcf548x_ac97_swap_record_buffers(priv);
							sptr = (short *)priv->record_samples;
							end_ptr = priv->record_end_samples;
						}
						break;
					case RECORD_MONO8:
						if(vra)
							*cptr++ = (char)(pcm_right >> 24);
						else
						{
							cr = *cptr = (char)(pcm_right >> 24);
					  	cptr += priv->incr_offsets_record[i];
						}
						if((void *)cptr >= end_ptr)
					  {
							mcf548x_ac97_swap_record_buffers(priv);
							cptr = (char *)priv->record_samples;
							end_ptr = priv->record_end_samples;
						}
						break;
					case RECORD_MONO16:
						if(vra)
							*sptr++ = (short)(pcm_right >> 16);
						else
						{
							sr = *sptr = (short)(pcm_right >> 16);
					  	sptr += priv->incr_offsets_record[i];
						}
						if((void *)sptr >= end_ptr)
					  {
							mcf548x_ac97_swap_record_buffers(priv);
							sptr = (short *)priv->record_samples;
							end_ptr = priv->record_end_samples;
						}
						break;
				}
			}
			status += AC97_SLOTS;
		}
		if(!vra && (incr > 0)) // required frequency > 48000 Hz => add last sample(s)
		{
			switch(priv->record_res)
			{
				case RECORD_STEREO8:
					while(--incr > 0)
					{
						*cptr++ = cl;
						*cptr++ = cr;
					  if((void *)cptr >= end_ptr)
					  {
							if(!mcf548x_ac97_swap_record_buffers(priv));
							{
								cptr = NULL;
								break;
							}
							cptr = (char *)priv->record_samples;
						}
					}
					break;
				case RECORD_STEREO16:				
					while(--incr > 0)
					{
						*sptr++ = sl;
						*sptr++ = sr;
					  if((void *)sptr >= end_ptr)
					  {
							if(!mcf548x_ac97_swap_record_buffers(priv));
							{
								sptr = NULL;
								break;
							}
							sptr = (short *)priv->record_samples;
						}
					}
					break;
				case RECORD_MONO8:
					while(--incr > 0)
					{
						*cptr++ = cr;
					  if((void *)cptr >= end_ptr)
					  {
							if(!mcf548x_ac97_swap_record_buffers(priv));
							{
								cptr = NULL;
								break;
							}
							cptr = (char *)priv->record_samples;
						}
					}
					break;		
				case RECORD_MONO16:
					while(--incr > 0)
					{
						*sptr++ = sr;
					  if((void *)sptr >= end_ptr)
					  {
							if(!mcf548x_ac97_swap_record_buffers(priv));
							{
								sptr = NULL;
								break;
							}
							sptr = (short *)priv->record_samples;
						}
					}
					break;		
			}
		}
		if((priv->record_res == RECORD_MONO16)
		 || (priv->record_res == RECORD_STEREO16))
			priv->record_samples = (void *)sptr;
		else
			priv->record_samples = (void *)cptr;
	}
	priv->cnt_rx += num_frames;
	priv->cnt_slot_rx = cnt_slot;
	priv->ctrl_mode = ctrl_mode;
#ifdef PERIOD
	start_time = (start_time - MCF_SLT_SCNT(1)) / 100;
	if(start_time > priv->time_get_frame)
		priv->time_get_frame = start_time;
#endif
	return(0);
}

static int mcf548x_ac97_swap_play_buffers(struct mcf548x_ac97_priv *priv)
{
	int ret = 0;
	if(priv->play_record_mode && SB_PLA_RPT)
	{
		if((priv->new_play_start_samples != NULL)
		 && (priv->new_play_end_samples != NULL))
		{
			priv->play_samples = priv->play_start_samples = priv->new_play_start_samples;
			priv->play_end_samples = priv->new_play_end_samples;
			priv->new_play_start_samples = NULL;
			priv->new_play_end_samples = NULL;
		}
		else // loop
			priv->play_samples = priv->play_start_samples;
		ret = 1; // swap => continue play
	}
	else
	{
		priv->play_samples = NULL;
		priv->play_record_mode &= ~SB_PLA_ENA;
	}
	switch(priv->cause_inter)
	{
		case 0:
			if(priv->callback_play != NULL)
				priv->callback_play();
			break;
		/* Timer A */
		case SI_PLAY:
		case SI_BOTH:
			call_timer_a(); // XBIOS
			break;
		/* IO7 */
		case SI_PLAY + 0x100:
		case SI_BOTH + 0x100:		
			call_io7_mfp(); // XBIOS
			break;	
	}
	return(ret);
}

/*
 * Sound data memory layout - samples are all signed values
 *
 * 				(each char = 1 byte, 2 chars = 1 word)
 * 1 16 bit stereo track:	LLRRLLRRLLRRLLRR
 * 1 8 bit stereo track:	LRLRLRLR  
 * 2 16 bit stereo tracks:	L0R0L1R1L0R0L1R1
 *  etc...
 */
	
//static
int mcf548x_ac97_build_frame(struct mcf548x_ac97_priv *priv, int num_frames)
{
	int i;
	unsigned long tag;
#ifdef PERIOD
	unsigned long start_time = MCF_SLT_SCNT(1);
#endif
	int ctrl_mode = priv->ctrl_mode;
#ifdef USE_DMA
	MCD_bufDesc *ptdesc = priv->txbd;
	unsigned long *cmd = (unsigned long *)ptdesc[priv->tx_bd_idx].srcAddr;
#else
	unsigned long pos = priv->pos_tx_frame;
	unsigned long *cmd = &priv->tx_frame[pos];
#endif /* USE_DMA */
	if(num_frames <= 0)
		return(-1);
#ifdef PERIOD
	if(priv->previous_build_frame)
	{
		unsigned long period = (priv->previous_build_frame - start_time) / 100;
		if(period > priv->period_build_frame)
			priv->period_build_frame = period;
	}
	priv->previous_build_frame = start_time;
#endif /* PERIOD */
	if(!((priv->play_record_mode & SB_PLA_ENA)
	 && (priv->play_samples != NULL)))
	{
		for(i = 0; i < num_frames; i++)
		{
			tag = MCF_PSC_TB_AC97_TB(1<<19) | MCF_PSC_TB_AC97_SOF; /* 1st slot is 16 bits length */
			priv->cnt_tx++;
			if(ctrl_mode)
			{
				if(priv->ctrl_rw) /* read */
				{
					/* Tag - Slot #0 */
					cmd[AC97_SLOT_TAG] = MCF_PSC_TB_AC97_TB(1<<18) | tag;
					/* Control Address - Slot #1 */
					cmd[AC97_SLOT_CMD_ADDR] = MCF_PSC_TB_AC97_TB((1<<19) | ((priv->ctrl_address & 0x7f) << 12));
					/* Control data - Slot #2 */
					cmd[AC97_SLOT_CMD_DATA] = MCF_PSC_TB_AC97_TB(0);
				}
				else /* write */
				{
					/* Tag - Slot #0 */
					cmd[AC97_SLOT_TAG] = MCF_PSC_TB_AC97_TB(3<<17) | tag;
					/* Control Address - Slot #1 */
					cmd[AC97_SLOT_CMD_ADDR] = MCF_PSC_TB_AC97_TB((priv->ctrl_address & 0x7f) << 12);
					/* Control data - Slot #2 */
					cmd[AC97_SLOT_CMD_DATA] = MCF_PSC_TB_AC97_TB(priv->ctrl_data << 4);
					priv->ctrl_rw = 1; /* read after write for get an ack */
				}
			}
			else
			{
				/* Tag - Slot #0 */
				cmd[AC97_SLOT_TAG] = tag;
				/* Control Address - Slot #1 */
				cmd[AC97_SLOT_CMD_ADDR] = 0;
				/* Control data - Slot #2 */
				cmd[AC97_SLOT_CMD_DATA] = 0;
			}
			cmd[AC97_SLOT_PCM_RIGHT] = 0;
			cmd[AC97_SLOT_PCM_LEFT] = 0;
/*
			cmd[AC97_SLOT_MODEM_LINE1] = 0;
			cmd[AC97_SLOT_PCM_CENTER] = 0;
			cmd[AC97_SLOT_PCM_SLEFT] = 0;
			cmd[AC97_SLOT_PCM_SRIGHT] = 0;
			cmd[AC97_SLOT_LFE] = 0;
			cmd[AC97_SLOT_MODEM_LINE2] = 0;
			cmd[AC97_SLOT_HANDSET] = 0;
			cmd[AC97_SLOT_MODEM_GPIO] =	0;
*/
#ifndef USE_DMA
		  pos += AC97_SLOTS;
		  cmd += AC97_SLOTS;
		  if(pos >= (AC97_SLOTS * AC97_SAMPLES_BY_BUFFER))
		  {
				pos = 0;
				cmd = priv->tx_frame;
			}
#else /* USE_DMA */
			cmd += AC97_SLOTS;	
#endif /* USE_DMA */
		}
	}
	else /* play */
	{
		char *cptr = (char *)priv->play_samples;
		short *sptr = (short *)cptr;
		void *end_ptr = priv->play_end_samples;
		int vra = 1, incr = 0;
		if(priv->play_frequency != priv->freq_dac)
		{
			int coeff = priv->freq_dac / AC97_SAMPLES_BY_BUFFER;
			int new_samples_by_buffer = priv->play_frequency / coeff;
			if((priv->play_frequency % coeff) >= (coeff >> 1))
				new_samples_by_buffer++;
			vra = 0;		
			if(new_samples_by_buffer > AC97_SAMPLES_BY_BUFFER)
				incr = new_samples_by_buffer - AC97_SAMPLES_BY_BUFFER; // required frequency > 48000 Hz => jump last sample(s)
		}
		for(i = 0; i < num_frames; i++)
		{
			int valid = 0;
			tag = MCF_PSC_TB_AC97_TB(1<<19) | MCF_PSC_TB_AC97_SOF; /* 1st slot is 16 bits length */
			if(vra)
			{
				if(!(priv->slotreq[priv->cnt_tx % AC97_SAMPLES_BY_BUFFER] & 0xc0)) /* PCM left/right channel */
				{
					tag |=  MCF_PSC_TB_AC97_TB(3<<15);
					valid = 1;
				}
			}
			else /* variable rate impossible */
			{
				tag |= MCF_PSC_TB_AC97_TB(3<<15);
				valid = 1;
			}
			priv->cnt_tx++;
			if(ctrl_mode)
			{
				if(priv->ctrl_rw) /* read */
				{
					/* Tag - Slot #0 */
					cmd[AC97_SLOT_TAG] = MCF_PSC_TB_AC97_TB(1<<18) | tag;
					/* Control Address - Slot #1 */
					cmd[AC97_SLOT_CMD_ADDR] = MCF_PSC_TB_AC97_TB((1<<19) | ((priv->ctrl_address & 0x7f) << 12));
					/* Control data - Slot #2 */
					cmd[AC97_SLOT_CMD_DATA] = MCF_PSC_TB_AC97_TB(0);
				}
				else /* write */
				{
					/* Tag - Slot #0 */
					cmd[AC97_SLOT_TAG] = MCF_PSC_TB_AC97_TB(3<<17) | tag;
					/* Control Address - Slot #1 */
					cmd[AC97_SLOT_CMD_ADDR] = MCF_PSC_TB_AC97_TB((priv->ctrl_address & 0x7f) << 12);
					/* Control data - Slot #2 */
					cmd[AC97_SLOT_CMD_DATA] = MCF_PSC_TB_AC97_TB(priv->ctrl_data << 4);
					priv->ctrl_rw = 1; /* read after write for get an ack */
				}
			}
			else
			{
				/* Tag - Slot #0 */
				cmd[AC97_SLOT_TAG] = tag;
				/* Control Address - Slot #1 */
				cmd[AC97_SLOT_CMD_ADDR] = MCF_PSC_TB_AC97_TB((1<<19) | (AC97_VENDOR_ID2 << 12));
				/* Control data - Slot #2 */
				cmd[AC97_SLOT_CMD_DATA] = 0;
			}
			if(vra) /* variable rate */
			{
				if(valid)
				{
					unsigned long val;
					switch(priv->play_res)
					{
						case STEREO8:
						  cmd[AC97_SLOT_PCM_LEFT] = MCF_PSC_TB_AC97_TB((long)*cptr++ << 12);
						  cmd[AC97_SLOT_PCM_RIGHT] = MCF_PSC_TB_AC97_TB((long)*cptr++ << 12);
							if((void *)cptr >= end_ptr)
							{
								mcf548x_ac97_swap_play_buffers(priv);
								cptr = (char *)priv->play_samples;
								end_ptr = priv->play_end_samples;
							}
					 		break;
						case STEREO16:
					  	cmd[AC97_SLOT_PCM_LEFT] = MCF_PSC_TB_AC97_TB((long)*sptr++ << 4);
					  	cmd[AC97_SLOT_PCM_RIGHT] = MCF_PSC_TB_AC97_TB((long)*sptr++ << 4);
							if((void *)sptr >= end_ptr)
							{
								mcf548x_ac97_swap_play_buffers(priv);
								sptr = (short *)priv->play_samples;
								end_ptr = priv->play_end_samples;
							}
							break;
						case MONO8:
							val = MCF_PSC_TB_AC97_TB((long)*cptr++ << 12);
						  cmd[AC97_SLOT_PCM_LEFT] = val;
						  cmd[AC97_SLOT_PCM_RIGHT] = val;
							if((void *)cptr >= end_ptr)
							{
								mcf548x_ac97_swap_play_buffers(priv);
								cptr = (char *)priv->play_samples;
								end_ptr = priv->play_end_samples;
							}
							break;
						case MONO16:
							val = MCF_PSC_TB_AC97_TB((long)*sptr++ << 4);
						  cmd[AC97_SLOT_PCM_LEFT] = val;
						  cmd[AC97_SLOT_PCM_RIGHT] = val;
							if((void *)sptr >= end_ptr)
							{
								mcf548x_ac97_swap_play_buffers(priv);
								sptr = (short *)priv->play_samples;
								end_ptr = priv->play_end_samples;
							}
							break;
						default:
							cmd[AC97_SLOT_PCM_RIGHT] = 0;
							cmd[AC97_SLOT_PCM_LEFT] = 0;
							break;
					}
				}
				else /* !valid */
				{
					cmd[AC97_SLOT_PCM_RIGHT] = 0;
					cmd[AC97_SLOT_PCM_LEFT] = 0;
				}
			}
			else /* variable rate impossible */
			{
				if(valid)
				{
					unsigned long val;
					switch(priv->play_res)
					{
						case STEREO8:
						  cmd[AC97_SLOT_PCM_LEFT] = MCF_PSC_TB_AC97_TB((long)cptr[0] << 12);
						  cmd[AC97_SLOT_PCM_RIGHT] = MCF_PSC_TB_AC97_TB((long)cptr[1] << 12);
							cptr += priv->incr_offsets_play[0];
						  if((void *)cptr >= end_ptr)
						  {
								mcf548x_ac97_swap_play_buffers(priv);
								cptr = (char *)priv->play_samples;
								end_ptr = priv->play_end_samples;
							}
							if((priv->cnt_tx % AC97_SAMPLES_BY_BUFFER) == 0)
							{
						   	priv->play_samples = &cptr[incr<<1];
								if(incr && ((void *)cptr >= end_ptr))
									mcf548x_ac97_swap_play_buffers(priv);
		 	 				}
					 		break;
						case STEREO16:
							cmd[AC97_SLOT_PCM_LEFT] = MCF_PSC_TB_AC97_TB((long)sptr[0] << 4);
						 	cmd[AC97_SLOT_PCM_RIGHT] = MCF_PSC_TB_AC97_TB((long)sptr[1] << 4);
							sptr += priv->incr_offsets_play[0];
							if((void *)sptr >= end_ptr)
							{
								mcf548x_ac97_swap_play_buffers(priv);
								sptr = (short *)priv->play_samples;
								end_ptr = priv->play_end_samples;			
							}
							if((priv->cnt_tx % AC97_SAMPLES_BY_BUFFER) == 0)
							{
						    priv->play_samples = &sptr[incr<<1];
								if(incr && ((void *)sptr >= end_ptr))
									mcf548x_ac97_swap_play_buffers(priv);					
							}
							break;
						case MONO8:
							val = MCF_PSC_TB_AC97_TB((long)cptr[0] << 12);
							cmd[AC97_SLOT_PCM_LEFT] = val;
 							cmd[AC97_SLOT_PCM_RIGHT] = val;
							cptr += priv->incr_offsets_play[0];
						  if((void *)cptr >= end_ptr)
						  {
								mcf548x_ac97_swap_play_buffers(priv);
								cptr = (char *)priv->play_samples;
								end_ptr = priv->play_end_samples;
							}
							if((priv->cnt_tx % AC97_SAMPLES_BY_BUFFER) == 0)
							{
						    priv->play_samples = &cptr[incr];
								if(incr && ((void *)cptr >= end_ptr))
									mcf548x_ac97_swap_play_buffers(priv);
							}
							break;
						case MONO16:
							val = MCF_PSC_TB_AC97_TB((long)sptr[0] << 4);
							cmd[AC97_SLOT_PCM_LEFT] = val;
 							cmd[AC97_SLOT_PCM_RIGHT] = val;
							sptr += priv->incr_offsets_play[0];
						  if((void *)sptr >= end_ptr)
						  {
								mcf548x_ac97_swap_play_buffers(priv);
								sptr = (short *)priv->play_samples;
								end_ptr = priv->play_end_samples;
							}
							if((priv->cnt_tx % AC97_SAMPLES_BY_BUFFER) == 0)
							{
						    priv->play_samples = &sptr[incr];
								if(incr && ((void *)sptr >= end_ptr))
									mcf548x_ac97_swap_play_buffers(priv);
							}
							break;
						default:
							cmd[AC97_SLOT_PCM_RIGHT] = 0;
							cmd[AC97_SLOT_PCM_LEFT] = 0;
							break;
					}
				}
				else /* !valid */
				{
					cmd[AC97_SLOT_PCM_RIGHT] = 0;
					cmd[AC97_SLOT_PCM_LEFT] = 0;
				}
			}
#ifndef USE_DMA
/*
			cmd[AC97_SLOT_MODEM_LINE1] = 0;
			cmd[AC97_SLOT_PCM_CENTER] = 0;
			cmd[AC97_SLOT_PCM_SLEFT] = 0;
			cmd[AC97_SLOT_PCM_SRIGHT] = 0;
			cmd[AC97_SLOT_LFE] = 0;
			cmd[AC97_SLOT_MODEM_LINE2] = 0;
			cmd[AC97_SLOT_HANDSET] = 0;
			cmd[AC97_SLOT_MODEM_GPIO] =	0;
*/
		  pos += AC97_SLOTS;
		  cmd += AC97_SLOTS;
		  if(pos >= (AC97_SLOTS * AC97_SAMPLES_BY_BUFFER))
		  {
				pos = 0;
				cmd = priv->tx_frame;
			}
#else /* USE_DMA */
			cmd += AC97_SLOTS;	
#endif /* USE_DMA */
		}
		if(priv->play_res == STEREO16)
			priv->play_samples = (void *)sptr;
		else
			priv->play_samples = (void *)cptr;
	}
	priv->pos_tx_frame = pos;
#ifdef PERIOD
	start_time = (start_time - MCF_SLT_SCNT(1)) / 100;
	if(start_time > priv->time_build_frame)
		priv->time_build_frame = start_time;
#endif
	return(0);
}
 
#ifdef USE_DMA

//static
void mcf548x_ac97_rx_frame(int channel)
{
	struct mcf548x_ac97_priv *priv = Devices[channel];
	if(priv == NULL)
	{
#ifdef DEBUG
//		display_string("mcf548x_ac97_rx_frame priv null\r\n");
#endif
		return;
	}
	else
	{
#ifdef USE_DMA
		MCD_bufDesc *ptdesc = priv->rxbd;
#endif
#ifdef DEBUG
		char buf[10];
		MCD_XferProg progRep;
		long bytes = 0;
		int dma_channel = dma_get_channel(DMA_PSC_RX(channel));
		display_string("mcf548x_ac97_rx_frame bytes: ");
		if((dma_channel != -1)
	   && (MCD_XferProgrQuery(dma_channel, &progRep) == MCD_OK))
			bytes = (long)progRep.dmaSize;   
		ltoa(buf, bytes, 10);
		display_string(buf);
		display_string("\r\n");
#endif /* DEBUG */
 	 /* Check to see if the ring of BDs is full */
		if(ptdesc->flags & MCD_BUF_READY)
		{
#ifdef DEBUG
			display_string("mcf548x_ac97_rx_frame buffer not ready\r\n");
#endif
			return;
		}
		mcf548x_ac97_get_frame(priv, AC97_SAMPLES_BY_BUFFER);
		priv->codec_ready = 1;
		/* increment the circular index */
		priv->rx_bd_idx = (priv->rx_bd_idx + 1) % AC97_RX_NUM_BD;
		/* Re-initialize the buffer descriptor */
		ptdesc->flags = MCD_INTERRUPT | MCD_BUF_READY;
	}
}

static void mcf548x_psc0_rx_frame(void)
{
  mcf548x_ac97_rx_frame(0);
}

static void mcf548x_psc1_rx_frame(void)
{
  mcf548x_ac97_rx_frame(1);
}

static void mcf548x_psc2_rx_frame(void)
{
  mcf548x_ac97_rx_frame(2);
}

static void mcf548x_psc3_rx_frame(void)
{
  mcf548x_ac97_rx_frame(3);
}

static int mcf548x_ac97_rx_start(struct mcf548x_ac97_priv *priv)
{
	unsigned long initiator;
	int dma_channel;
	int psc_channel = priv->psc_channel;
#ifdef DEBUG
	char buf[10];
	display_string("mcf548x_ac97_rx_start channel: ");
	ltoa(buf, (long)psc_channel, 10);
	display_string(buf);
	display_string("\r\n");
#endif
	/* Make the initiator assignment */
	dma_set_initiator(DMA_PSC_RX(psc_channel));
	/* Grab the initiator number */
	initiator = dma_get_initiator(DMA_PSC_RX(psc_channel));
	/* Determine the DMA channel running the task for the selected PSC */
	dma_channel = dma_set_channel(DMA_PSC_RX(psc_channel), (psc_channel == 0) ? mcf548x_psc0_rx_frame : ((psc_channel == 1) ? mcf548x_psc1_rx_frame : ((psc_channel == 2) ? mcf548x_psc2_rx_frame : mcf548x_psc3_rx_frame)));
	/* Start the Rx DMA task */
	return((MCD_startDma(dma_channel, (char *)&MCF_PSC_TB_AC97(psc_channel), 0, (char *)priv->rxbd, 4, AC97_DMA_SIZE, 4, initiator, PSCRX_DMA_PRI,
	 MCD_INTERRUPT | MCD_TT_FLAGS_CW | MCD_TT_FLAGS_RL | MCD_TT_FLAGS_SP, MCD_NO_CSUM | MCD_NO_BYTE_SWAP) == MCD_OK) ? 0 : -1);
}

static void mcf548x_ac97_rx_stop(struct mcf548x_ac97_priv *priv)
{
	int psc_channel = priv->psc_channel;
  int dma_channel = dma_get_channel(DMA_PSC_RX(psc_channel));
  if(dma_channel != -1)
    MCD_killDma(dma_channel);
  dma_free_initiator(DMA_PSC_RX(psc_channel));
  /* Free up the DMA channel */
  dma_free_channel(DMA_PSC_RX(psc_channel));
}

//static
void mcf548x_ac97_tx_frame(int channel)
{
	struct mcf548x_ac97_priv *priv = Devices[channel];
	if(priv == NULL)
	{
#ifdef DEBUG
//		display_string("mcf548x_ac97_tx_frame priv null\r\n");
#endif
		return;
	}
	else
	{
		MCD_bufDesc *ptdesc = priv->txbd;
#ifdef DEBUG
#ifdef USE_DMA
		MCD_XferProg progRep;
		char buf[10];
		long bytes = 0;
		int dma_channel = dma_get_channel(DMA_PSC_TX(channel));
		display_string("mcf548x_ac97_tx_frame bytes: ");
		if((dma_channel != -1)
	   && (MCD_XferProgrQuery(dma_channel, &progRep) == MCD_OK))
			bytes = (long)progRep.dmaSize;   
		ltoa(buf, bytes, 10);
		display_string(buf);
		display_string("\r\n");
#else
		display_string("mcf548x_ac97_tx_frame\r\n");
#endif /* USE_DMA */
#endif /* DEBUG */
#ifdef USE_DMA
		/* Check to see if the ring of BDs is empty */
		if(ptdesc->flags & MCD_BUF_READY)
		{
#ifdef DEBUG
			display_string("mcf548x_ac97_tx_frame buffer not ready\r\n");
#endif
			return;
		}
#endif /* USE_DMA */
		mcf548x_ac97_build_frame(priv, AC97_SAMPLES_BY_BUFFER);
		/* increment the circular index */
		priv->tx_bd_idx = (priv->tx_bd_idx + 1) % AC97_RX_NUM_BD;
		/* Re-initialize the buffer descriptor */
		ptdesc->flags = MCD_INTERRUPT | MCD_BUF_READY;
	}
}

static void mcf548x_psc0_tx_frame(void)
{
  mcf548x_ac97_tx_frame(0);
}

static void mcf548x_psc1_tx_frame(void)
{
  mcf548x_ac97_tx_frame(1);
}

static void mcf548x_psc2_tx_frame(void)
{
  mcf548x_ac97_tx_frame(2);
}

static void mcf548x_psc3_tx_frame(void)
{
  mcf548x_ac97_tx_frame(3);
}

static int mcf548x_ac97_tx_start(struct mcf548x_ac97_priv *priv)
{
	unsigned long initiator;
	int dma_channel;
	int psc_channel = priv->psc_channel;
#ifdef DEBUG
	char buf[10];
	display_string("mcf548x_ac97_tx_start channel: ");
	ltoa(buf, (long)psc_channel, 10);
	display_string(buf);
	display_string("\r\n");
#endif
	/* Make the initiator assignment */
	dma_set_initiator(DMA_PSC_TX(psc_channel));
	/* Grab the initiator number */
	initiator = dma_get_initiator(DMA_PSC_TX(psc_channel));
	/* Determine the DMA channel running the task for the selected PSC */
	dma_channel = dma_set_channel(DMA_PSC_TX(psc_channel), (psc_channel == 0) ? mcf548x_psc0_tx_frame : ((psc_channel == 1) ? mcf548x_psc1_tx_frame : ((psc_channel == 2) ? mcf548x_psc2_tx_frame : mcf548x_psc3_tx_frame)));
	/* Start the Tx DMA task */
	return((MCD_startDma(dma_channel, (char *)priv->txbd, 4, (char *)(MCF_PSC_TFDR_ADDR(psc_channel)), 0, AC97_DMA_SIZE, 4, initiator, PSCTX_DMA_PRI,
	 MCD_INTERRUPT | MCD_TT_FLAGS_CW | MCD_TT_FLAGS_RL | MCD_TT_FLAGS_SP, MCD_NO_CSUM | MCD_NO_BYTE_SWAP) == MCD_OK) ? 0 : -1);
}

static void mcf548x_ac97_tx_stop(struct mcf548x_ac97_priv *priv)
{
	int psc_channel = priv->psc_channel;
  int dma_channel = dma_get_channel(DMA_PSC_TX(psc_channel));
  if(dma_channel != -1)
    MCD_killDma(dma_channel);
  dma_free_initiator(DMA_PSC_TX(psc_channel));
  /* Free up the DMA channel */
  dma_free_channel(DMA_PSC_TX(psc_channel));
}

static int mcf548x_ac97_bdinit(struct mcf548x_ac97_priv *priv)
{ 
#ifdef DEBUG
	display_string("mcf548x_ac97_bdinit\r\n");
#endif
#ifdef AC97_BUF_USE_SYSTEM_RAM
	priv->buffer = (void *)&Descriptors[AC97_TX_NUM_BD + AC97_RX_NUM_BD]; 
#else
	priv->buffer = (void *)Mxalloc((AC97_DMA_SIZE + 16) * (AC97_TX_NUM_BD + AC97_RX_NUM_BD), 0);
	if(priv->buffer != NULL)
#endif
	{
		int i;
		unsigned long aligned_buffer = ((unsigned long)priv->buffer + 15) & ~15;
		priv->txbd = &Descriptors[0]; 
		priv->tx_bd_idx = 0;
		for(i = 0; i < AC97_TX_NUM_BD; i++)
		{
		  Descriptors[i].flags = MCD_INTERRUPT | MCD_BUF_READY;
		  Descriptors[i].csumResult = 0;
		  Descriptors[i].srcAddr = (char *)aligned_buffer;
		  Descriptors[i].destAddr = (char *)(MCF_PSC_TFDR_ADDR(priv->psc_channel));
		  Descriptors[i].lastDestAddr = Descriptors[i].destAddr;
		  Descriptors[i].dmaSize = AC97_DMA_SIZE;
		  if(i == AC97_TX_NUM_BD - 1)
			  Descriptors[i].next = &Descriptors[0];
			else
		  	Descriptors[i].next = &Descriptors[i+1];
		  Descriptors[i].info = 0;
		  memset((void *)aligned_buffer, AC97_DMA_SIZE, 0);
			aligned_buffer += ((AC97_DMA_SIZE + 15) & ~15);
		}
		priv->rxbd = &Descriptors[AC97_TX_NUM_BD]; 
		priv->rx_bd_idx = 0;
		for(i = AC97_TX_NUM_BD; i < AC97_TX_NUM_BD + AC97_RX_NUM_BD; i++)
		{
		  Descriptors[i].flags = MCD_INTERRUPT | MCD_BUF_READY;
		  Descriptors[i].csumResult = 0;
		  Descriptors[i].srcAddr = (char *)&MCF_PSC_TB_AC97(priv->psc_channel);
		  Descriptors[i].destAddr = (char *)aligned_buffer;
		  Descriptors[i].lastDestAddr = (char *)(aligned_buffer+AC97_DMA_SIZE);
		  Descriptors[i].dmaSize = AC97_DMA_SIZE;
		  if(i == AC97_TX_NUM_BD + AC97_RX_NUM_BD - 1)
			  Descriptors[i].next = &Descriptors[AC97_TX_NUM_BD];
		  else
			  Descriptors[i].next = &Descriptors[i+1];
		  Descriptors[i].info = 0;
		  memset((void *)aligned_buffer, AC97_DMA_SIZE, 0);
			aligned_buffer += ((AC97_DMA_SIZE + 15) & ~15);
		}
		return(0);
	}
	return(-1);
}

static void mcf548x_ac97_fill_fifo(struct mcf548x_ac97_priv *priv)
{
}

#else /* !USE_DMA */

static void mcf548x_ac97_fill_fifo(struct mcf548x_ac97_priv *priv)
{
	int channel = priv->psc_channel;
	unsigned long cnt = priv->cnt_tx_frame;
	unsigned long pos = priv->pos_tx_frame;
	long empty_bytes = (long)MCF_PSC_TFAR_ALARM(0xFFFF) - (long)MCF_PSC_TFCNT(channel);
	long count;
#ifdef DEBUG
	priv->tab_num_frames[priv->err_no_rx % AC97_SAMPLES_BY_BUFFER] = (short)empty_bytes;
	priv->err_no_rx++;
#endif
	if(pos >= cnt)
		empty_bytes -= (long)(pos - cnt);
	else
		empty_bytes -= (long)((AC97_SLOTS * AC97_SAMPLES_BY_BUFFER) - cnt + pos);
	if(empty_bytes < 0)
		empty_bytes = 0;
	mcf548x_ac97_build_frame(priv, ((empty_bytes >> 2) / AC97_SLOTS) + 1);
	count = ((long)MCF_PSC_TFAR_ALARM(0xFFFF) - (long)MCF_PSC_TFCNT(channel)) >> 2;
	while(--count)
	{
		MCF_PSC_TB_AC97(channel) = priv->tx_frame[cnt++];
		if(cnt >= (AC97_SLOTS * AC97_SAMPLES_BY_BUFFER))
			cnt = 0;				
	}
	priv->cnt_tx_frame = cnt;
#ifdef DEBUG
//	priv->tab_num_frames[priv->err_no_rx % AC97_SAMPLES_BY_BUFFER] = MCF_PSC_TFCNT(channel);
//	priv->err_no_rx++;
#endif      
}

#endif /* USE_DMA */

static void mcf548x_ac97_psc0_interrupt(void)
{
  asm("_psc0_ac97_interrupt:\n move.w #0x2700,SR\n lea -24(SP),SP\n movem.l D0-D2/A0-A2,(SP)\n pea.l 0\n");
  asm(" jsr _mcf548x_ac97_interrupt_handler\n");
  asm(" addq.l #4,SP\n movem.l (SP),D0-D2/A0-A2\n lea 24(SP),SP\n rte\n");
}

static void mcf548x_ac97_psc1_interrupt(void)
{
  asm("_psc1_ac97_interrupt:\n move.w #0x2700,SR\n lea -24(SP),SP\n movem.l D0-D2/A0-A2,(SP)\n pea.l 1\n");
  asm(" jsr _mcf548x_ac97_interrupt_handler\n"); 
  asm(" addq.l #4,SP\n movem.l (SP),D0-D2/A0-A2\n lea 24(SP),SP\n rte\n");
}

static void mcf548x_ac97_psc2_interrupt(void)
{
  asm("_psc2_ac97_interrupt:\n move.w #0x2700,SR\n lea -24(SP),SP\n movem.l D0-D2/A0-A2,(SP)\n pea.l 2\n");
  asm(" jsr _mcf548x_ac97_interrupt_handler\n");
  asm(" addq.l #4,SP\n movem.l (SP),D0-D2/A0-A2\n lea 24(SP),SP\n rte\n");
}

static void mcf548x_ac97_psc3_interrupt(void)
{
  asm("_psc3_ac97_interrupt:\n move.w #0x2700,SR\n lea -24(SP),SP\n movem.l D0-D2/A0-A2,(SP)\n pea.l 3\n");
  asm(" jsr _mcf548x_ac97_interrupt_handler\n"); 
  asm(" addq.l #4,SP\n movem.l (SP),D0-D2/A0-A2\n lea 24(SP),SP\n rte\n");
}

void mcf548x_ac97_interrupt_handler(int channel)
{
	struct mcf548x_ac97_priv *priv = Devices[channel];
	short int_status = MCF_PSC_ISR(channel);
	short status = MCF_PSC_SR(channel);
#if AC97_INTC_LVL == 7
	MCF_PSC_IMR(channel) = 0;
#endif
#ifndef USE_DMA
	if(priv != NULL)
	{
		if(int_status & MCF_PSC_ISR_RXRDY_FU) /* RxFIFO full (RxFIFO threshold) */
		{
			unsigned long cnt = priv->cnt_rx_frame;
			unsigned long pos = priv->pos_rx_frame;
			long count;
#ifdef DEBUG
//			priv->tab_num_frames[priv->err_no_rx % AC97_SAMPLES_BY_BUFFER] = MCF_PSC_RFCNT(channel);
//			priv->err_no_rx++;
#endif
			while(status & MCF_PSC_SR_RXRDY)
			{
				priv->rx_frame[cnt++] = MCF_PSC_TB_AC97(channel);
				if(cnt >= (AC97_SLOTS * AC97_SAMPLES_BY_BUFFER))
					cnt = 0;				
				status = MCF_PSC_SR(channel);
			}
			priv->cnt_rx_frame = cnt;
			if(cnt >= pos)
				count = (long)(cnt - pos);
			else
				count = (long)((AC97_SLOTS * AC97_SAMPLES_BY_BUFFER) - pos + cnt);
#ifdef DEBUG
//			priv->tab_num_frames[priv->err_no_rx % AC97_SAMPLES_BY_BUFFER] = (short)bytes;
//			priv->err_no_rx++;
#endif
 			if(count >= AC97_SLOTS)
 			{
				unsigned long *p = priv->rx_frame;
 			  unsigned long tag = p[pos];
				if(!(tag & MCF_PSC_TB_AC97_SOF))
				{
					int i = AC97_SLOTS - 1;
					do
					{
						pos++;
						if(pos >= (AC97_SLOTS * AC97_SAMPLES_BY_BUFFER))
							pos = 0;				
						tag = p[pos];
						count--;
					}
					while(!(tag & MCF_PSC_TB_AC97_SOF) && (--i > 0));
					priv->cnt_error_sync++;
				}
				priv->pos_rx_frame = pos;
				if(tag & MCF_PSC_TB_AC97_SOF)
				{
					if(!mcf548x_ac97_get_frame(priv, count / AC97_SLOTS))
						priv->codec_ready = 1;
					status = MCF_PSC_SR(channel);
					while(status & MCF_PSC_SR_RXRDY)
					{
						priv->rx_frame[cnt++] = MCF_PSC_TB_AC97(channel);
						if(cnt >= (AC97_SLOTS * AC97_SAMPLES_BY_BUFFER))
							cnt = 0;				
						status = MCF_PSC_SR(channel);
					}
					priv->cnt_rx_frame = cnt;
				} 			  
			}
		}
		if(int_status & MCF_PSC_ISR_TXRDY) /* TxFIFO empty (TxFIFO threshold) */
			mcf548x_ac97_fill_fifo(priv);
	}
#endif /* USE_DMA */
	if(int_status & MCF_PSC_ISR_ERR)
	{
		if(status & MCF_PSC_SR_TXEMP_URERR)
		{
//			MCF_PSC_CR(channel) = MCF_PSC_CR_RESET_RX;
//			MCF_PSC_CR(channel) = MCF_PSC_CR_RESET_TX;	
			MCF_PSC_CR(channel) = MCF_PSC_CR_RESET_ERROR;
			if(priv != NULL)
			{
				priv->codec_ready = 0;
				priv->cnt_error_empty_tx++;
//				priv->cnt_tx_frame = priv->pos_tx_frame = 0;
//				mcf548x_ac97_fill_fifo(priv);
			}
//			MCF_PSC_CR(channel) = MCF_PSC_CR_TX_ENABLED | MCF_PSC_CR_RX_ENABLED;
		}
		if(status & MCF_PSC_SR_ERR)
		{
			if(priv != NULL)
			{
				if(MCF_PSC_TFSR(channel) & 0xC0F0)
				{
					priv->last_error_fifo_tx = (short)MCF_PSC_TFSR(channel);
					priv->cnt_error_fifo_tx++;
				}
				if(MCF_PSC_RFSR(channel) & 0xC0F0)
				{
					priv->last_error_fifo_rx = (short)MCF_PSC_RFSR(channel);
					priv->cnt_error_fifo_rx++;
				}
			}		
			MCF_PSC_TFSR(channel) &= 0xC0F0;
			MCF_PSC_RFSR(channel) &= 0xC0F0;
			MCF_PSC_CR(channel) = MCF_PSC_CR_RESET_ERROR;
		}
	}
#if AC97_INTC_LVL == 7
#ifdef USE_DMA
	MCF_PSC_IMR(channel) = MCF_PSC_IMR_ERR;
#else
	MCF_PSC_IMR(channel) = MCF_PSC_IMR_TXRDY | MCF_PSC_IMR_RXRDY_FU | MCF_PSC_IMR_ERR; 
#endif
#endif
}

static int mcf548x_ac97_sync_period(struct mcf548x_ac97_priv *priv)
{
	int period = 0;
	int level = asm_set_ipl(7);
	unsigned char sync = MCF_PSC_IP(priv->psc_channel) & MCF_PSC_IP_TGL;
	unsigned long start_timer = MCF_SLT_SCNT(1);
	while((MCF_PSC_IP(priv->psc_channel) & MCF_PSC_IP_TGL) == sync)
	{
	  if((start_timer - MCF_SLT_SCNT(1)) > 10000)
	  {
	  	asm_set_ipl(level);
	  	return(0);
	  }
	}
	sync = MCF_PSC_IP(priv->psc_channel) & MCF_PSC_IP_TGL;
	start_timer = MCF_SLT_SCNT(1);
	while((MCF_PSC_IP(priv->psc_channel) & MCF_PSC_IP_TGL) == sync)
	{
	  if((start_timer - MCF_SLT_SCNT(1)) > 10000)
	  {
	  	asm_set_ipl(level);
	  	return(0);
	  }
	}
	period = (int)(start_timer - MCF_SLT_SCNT(1));
	asm_set_ipl(level);
	return(period);	
}	

static int mcf548x_ac97_hwinit(struct mcf548x_ac97_priv *priv)
{
#ifdef LWIP
	extern unsigned long save_imrh;
#endif
	int level = asm_set_ipl(7);
#ifdef DEBUG
	char buf[10];
	display_string("mcf548x_ac97_hwinit priv: 0x");
	ltoa(buf, (long)priv, 16);
	display_string(buf);
	display_string("\r\n");	
	if(!(MCF_PSC_IP(priv->psc_channel) & MCF_PSC_IP_LWPR_B))
		display_string("CODEC is in low power mode\r\n");
#endif
	/* Configure AC97 enhanced mode */
	MCF_PSC_SICR(priv->psc_channel) = MCF_PSC_SICR_ACRB | MCF_PSC_SICR_SIM_AC97;
	/* Reset everything first by safety */
	MCF_PSC_CR(priv->psc_channel) = MCF_PSC_CR_RESET_RX;
	MCF_PSC_CR(priv->psc_channel) = MCF_PSC_CR_RESET_TX;	
	MCF_PSC_CR(priv->psc_channel) = MCF_PSC_CR_RESET_ERROR;
	MCF_PSC_CR(priv->psc_channel) = MCF_PSC_CR_RESET_MR; /* acces to MR1 */
	/* Do a warm reset of codec - 1uS */
	MCF_PSC_SICR(priv->psc_channel) |= MCF_PSC_SICR_AWR;
	udelay(1);
	MCF_PSC_SICR(priv->psc_channel) &= ~MCF_PSC_SICR_AWR;
#ifdef DEBUG
	if(!(MCF_PSC_IP(priv->psc_channel) & MCF_PSC_IP_LWPR_B))
		display_string("CODEC is in low power mode\r\n");
#endif
 	if((priv->freq_codec = (long)mcf548x_ac97_sync_period(priv)) == 0)
	{
		asm_set_ipl(level);
#ifdef DEBUG
		display_string("No SYNC\r\n");
#endif
		return(-1); /* no clock */
	} 	
	priv->freq_codec = 100000000 / priv->freq_codec;
#ifdef DEBUG
  {
		char buf[10];
		display_string("SYNC frequency: ");
		ltoa(buf, priv->freq_codec, 10);
		display_string(buf);
		display_string(" Hz\r\n");
	}
#endif
	/* IRQ */
	MCF_PSC_MR(priv->psc_channel) = MCF_PSC_MR_RXIRQ;
	MCF_PSC_CR(priv->psc_channel) = MCF_PSC_CR_RESET_MR; /* acces to MR1 */
#ifdef USE_DMA
	MCF_PSC_IMR(priv->psc_channel) = MCF_PSC_IMR_ERR;
#else
	MCF_PSC_IMR(priv->psc_channel) = MCF_PSC_IMR_TXRDY | MCF_PSC_IMR_RXRDY_FU | MCF_PSC_IMR_ERR; 
#endif
	MCF_PSC_IRCR1(priv->psc_channel) = MCF_PSC_IRCR1_FD;
	MCF_PSC_IRCR2(priv->psc_channel) = 0;	
	/* FIFO levels */
	MCF_PSC_RFCR(priv->psc_channel) = MCF_PSC_RFCR_FRMEN | MCF_PSC_RFCR_GR(4);
	MCF_PSC_TFCR(priv->psc_channel) = MCF_PSC_TFCR_FRMEN | MCF_PSC_TFCR_GR(7);
	switch(priv->psc_channel)
	{
		case 0: /* => used by serial 0 !!! */
			MCF_PSC0_RFAR = MCF_PSC_RFAR_ALARM(0xFFFF) - MCF_PSC_RFAR_ALARM(AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 4);
			MCF_PSC0_TFAR = MCF_PSC_TFAR_ALARM(0xFFFF) - MCF_PSC_TFAR_ALARM(AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 4);
			MCF_GPIO_PAR_PSC0 = MCF_GPIO_PAR_PSC0_PAR_CTS0_BCLK | MCF_GPIO_PAR_PSC0_PAR_RTS0_RTS | MCF_GPIO_PAR_PSC0_PAR_RXD0 | MCF_GPIO_PAR_PSC0_PAR_TXD0;
			Setexc(MCF_PSC0_VECTOR, psc0_ac97_interrupt);
			MCF_INTC_ICR35 = MCF_INTC_ICRn_IL(AC97_INTC_LVL) | MCF_INTC_ICRn_IP(AC97_INTC_PRI);
			MCF_INTC_IMRH &= ~MCF_INTC_IMRH_INT_MASK35;
#ifdef LWIP
			save_imrh &= ~MCF_INTC_IMRH_INT_MASK35; // for all tasks
#endif
			break;
		case 1: /* used by IKBD (Eiffel) */
			MCF_PSC1_RFAR = MCF_PSC_RFAR_ALARM(0xFFFF) - MCF_PSC_RFAR_ALARM(AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 4);
			MCF_PSC1_TFAR = MCF_PSC_TFAR_ALARM(0xFFFF) - MCF_PSC_TFAR_ALARM(AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 4);
			MCF_GPIO_PAR_PSC1 = MCF_GPIO_PAR_PSC1_PAR_CTS1_BCLK | MCF_GPIO_PAR_PSC1_PAR_RTS1_RTS | MCF_GPIO_PAR_PSC1_PAR_RXD1 | MCF_GPIO_PAR_PSC1_PAR_TXD1;
			Setexc(MCF_PSC1_VECTOR, psc1_ac97_interrupt);
			MCF_INTC_ICR34 = MCF_INTC_ICRn_IL(AC97_INTC_LVL) | MCF_INTC_ICRn_IP(AC97_INTC_PRI);
			MCF_INTC_IMRH &= ~MCF_INTC_IMRH_INT_MASK34;
#ifdef LWIP
			save_imrh &= ~MCF_INTC_IMRH_INT_MASK34; // for all tasks 
#endif
			break;
		case 2: /* AC97 codec */
			MCF_PSC2_RFAR = MCF_PSC_RFAR_ALARM(0xFFFF) - MCF_PSC_RFAR_ALARM(AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 4);
			MCF_PSC2_TFAR = MCF_PSC_TFAR_ALARM(0xFFFF) - MCF_PSC_TFAR_ALARM(AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 4);
			MCF_GPIO_PAR_PSC2 = MCF_GPIO_PAR_PSC2_PAR_CTS2_BCLK | MCF_GPIO_PAR_PSC2_PAR_RTS2_RTS | MCF_GPIO_PAR_PSC2_PAR_RXD2 | MCF_GPIO_PAR_PSC2_PAR_TXD2;
			Setexc(MCF_PSC2_VECTOR, psc2_ac97_interrupt);
			MCF_INTC_ICR33 = MCF_INTC_ICRn_IL(AC97_INTC_LVL) | MCF_INTC_ICRn_IP(AC97_INTC_PRI);
			MCF_INTC_IMRH &= ~MCF_INTC_IMRH_INT_MASK33;
#ifdef LWIP
			save_imrh &= ~MCF_INTC_IMRH_INT_MASK33; // for all tasks 
#endif
			break;
		case 3:
			MCF_PSC3_RFAR = MCF_PSC_RFAR_ALARM(0xFFFF) - MCF_PSC_TFAR_ALARM(AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 4);
			MCF_PSC3_TFAR = MCF_PSC_TFAR_ALARM(AC97_SLOTS * 4);
//			MCF_PSC3_RFAR = MCF_PSC_RFAR_ALARM(0xFFFF) - MCF_PSC_RFAR_ALARM(AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 4);
//			MCF_PSC3_TFAR = MCF_PSC_TFAR_ALARM(0xFFFF) - MCF_PSC_TFAR_ALARM(AC97_SLOTS * AC97_SAMPLES_BY_FIFO * 4);
			MCF_GPIO_PAR_PSC3 = MCF_GPIO_PAR_PSC3_PAR_CTS3_BCLK | MCF_GPIO_PAR_PSC3_PAR_RTS3_RTS | MCF_GPIO_PAR_PSC3_PAR_RXD3 | MCF_GPIO_PAR_PSC3_PAR_TXD3;
			Setexc(MCF_PSC3_VECTOR, psc3_ac97_interrupt);
			MCF_INTC_ICR32 = MCF_INTC_ICRn_IL(AC97_INTC_LVL) | MCF_INTC_ICRn_IP(AC97_INTC_PRI);
			MCF_INTC_IMRH &= ~MCF_INTC_IMRH_INT_MASK32;
#ifdef LWIP
			save_imrh &= ~MCF_INTC_IMRH_INT_MASK32; // for all tasks 
#endif
			break;
	}
#ifndef USE_DMA
	mcf548x_ac97_fill_fifo(priv);
#endif
	/* Go */
	MCF_PSC_CR(priv->psc_channel) = MCF_PSC_CR_TX_ENABLED | MCF_PSC_CR_RX_ENABLED;
	asm_set_ipl(level);
	return(0);
}

/* ======================================================================== */
/* AC97 Bus interface                                                       */
/* ======================================================================== */

static unsigned short mcf548x_ac97_bus_read(struct snd_ac97 *ac97, unsigned short reg)
{
	struct mcf548x_ac97_priv *priv = ac97->private_data;
	unsigned long start_timer = MCF_SLT_SCNT(1);
#ifdef DEBUG
	int old_cnt_error_fifo_rx = priv->cnt_error_fifo_rx;
	int old_cnt_error_fifo_tx = priv->cnt_error_fifo_tx;
	int old_cnt_error_sync = priv->cnt_error_sync;
	unsigned long measure_timer = start_timer;
#endif
	int level;
	/* Wait for it to be ready */
	while(!priv->codec_ready || priv->ctrl_mode)
	{
#ifdef DEBUG
		if(old_cnt_error_fifo_rx != priv->cnt_error_fifo_rx)
		{
			char buf[10];
			display_string("mcf548x_ac97_bus_read cnt_error_fifo_rx: ");
			ltoa(buf, (long)priv->cnt_error_fifo_rx, 10);
			display_string(buf);
			display_string(", last_error_fifo_rx: 0x");
			ltoa(buf, (long)priv->last_error_fifo_rx & 0xffff, 16);
			display_string(buf);
			display_string("\r\n");
			old_cnt_error_fifo_rx = priv->cnt_error_fifo_rx;
		}
		if(old_cnt_error_fifo_tx != priv->cnt_error_fifo_tx)
		{
			char buf[10];
			display_string("mcf548x_ac97_bus_read cnt_error_fifo_tx: ");
			ltoa(buf, (long)priv->cnt_error_fifo_tx, 10);
			display_string(buf);
			display_string(", last_error_fifo_tx: 0x");
			ltoa(buf, (long)priv->last_error_fifo_tx & 0xffff, 16);
			display_string(buf);
			display_string("no answer\r\n");
			old_cnt_error_fifo_tx = priv->cnt_error_fifo_tx;
		}
		if(old_cnt_error_sync != priv->cnt_error_sync)
		{
			char buf[10];
			display_string("mcf548x_ac97_bus_read cnt_error_sync: ");
			ltoa(buf, (long)priv->cnt_error_sync, 10);
			display_string(buf);
			display_string("\r\n");
			old_cnt_error_sync = priv->cnt_error_sync;
		}
#endif
	  if((start_timer - MCF_SLT_SCNT(1)) >= AC97_TIMEOUT)
		{
#ifdef DEBUG
			char buf[10];
			display_string("mcf548x_ac97_bus_read reg: 0x");
			ltoa(buf, (long)reg & 0xffff, 16);
			display_string(buf);
			display_string(", ");
			if(priv->ctrl_mode)
				display_string("no answer\r\n");
			else
				display_string("codec not ready\r\n");
#endif
			priv->ctrl_mode = 0;
			return(0xffff); /* timeout */
		}
	}
	/* Do the read - Control Address - Slot #1 */
	level = asm_set_ipl(7);
	priv->ctrl_address = (int)reg;
	priv->ctrl_rw = 1; /* read */
	priv->ctrl_mode = 1;
	start_timer = MCF_SLT_SCNT(1);
	asm_set_ipl(level);
	/* Wait for the answer */
	while(priv->ctrl_mode)
	{
#ifdef DEBUG
		if(old_cnt_error_fifo_rx != priv->cnt_error_fifo_rx)
		{
			char buf[10];
			display_string("mcf548x_ac97_bus_read cnt_error_fifo_rx: ");
			ltoa(buf, (long)priv->cnt_error_fifo_rx, 10);
			display_string(buf);
			display_string(", last_error_fifo_rx: 0x");
			ltoa(buf, (long)priv->last_error_fifo_rx & 0xffff, 16);
			display_string(buf);
			display_string("\r\n");
			old_cnt_error_fifo_rx = priv->cnt_error_fifo_rx;
		}
		if(old_cnt_error_fifo_tx != priv->cnt_error_fifo_tx)
		{
			char buf[10];
			display_string("mcf548x_ac97_bus_read cnt_error_fifo_tx: ");
			ltoa(buf, (long)priv->cnt_error_fifo_tx, 10);
			display_string(buf);
			display_string(", last_error_fifo_tx: 0x");
			ltoa(buf, (long)priv->last_error_fifo_tx & 0xffff, 16);
			display_string(buf);
			display_string("no answer\r\n");
			old_cnt_error_fifo_tx = priv->cnt_error_fifo_tx;
		}
		if(old_cnt_error_sync != priv->cnt_error_sync)
		{
			char buf[10];
			display_string("mcf548x_ac97_bus_read cnt_error_sync: ");
			ltoa(buf, (long)priv->cnt_error_sync, 10);
			display_string(buf);
			display_string("\r\n");
			old_cnt_error_sync = priv->cnt_error_sync;
		}
#endif
	  if((start_timer - MCF_SLT_SCNT(1)) >= AC97_TIMEOUT)
		{
#ifdef DEBUG
			char buf[10];
			display_string("mcf548x_ac97_bus_read reg: 0x");
			ltoa(buf, (long)reg & 0xffff, 16);
			display_string(buf);
			display_string(", timeout\r\n");
#endif
			priv->ctrl_mode = 0;
			return(0xffff); /* timeout */
		}
	}
#ifdef DEBUG
	{
		char buf[10];
		measure_timer -= MCF_SLT_SCNT(1);
		measure_timer /= 100;
		display_string("mcf548x_ac97_bus_read reg: 0x");
		ltoa(buf, (long)reg & 0xffff, 16);
		display_string(buf);
		display_string(", value: 0x");
		ltoa(buf, (long)priv->status_data & 0xffff, 16);
		display_string(buf);
		display_string(" (");
		ltoa(buf, measure_timer, 10);
		display_string(buf);
		display_string(" uS)\r\n");
	}
#endif
	return((unsigned short)priv->status_data);
}

static void mcf548x_ac97_bus_write(struct snd_ac97 *ac97, unsigned short reg, unsigned short val)
{
	struct mcf548x_ac97_priv *priv = ac97->private_data;
	unsigned long start_timer;
#ifdef DEBUG
	int old_cnt_error_fifo_rx = priv->cnt_error_fifo_rx;
	int old_cnt_error_fifo_tx = priv->cnt_error_fifo_tx;
	int old_cnt_error_sync = priv->cnt_error_sync;
	unsigned long measure_timer = MCF_SLT_SCNT(1);
#endif
	int level;
	int count = 0;
	do
	{
		start_timer = MCF_SLT_SCNT(1);
		/* Wait for it to be ready */
		while(!priv->codec_ready || priv->ctrl_mode)
		{
#ifdef DEBUG
			if(old_cnt_error_fifo_rx != priv->cnt_error_fifo_rx)
			{
				char buf[10];
				display_string("mcf548x_ac97_bus_write cnt_error_fifo_rx: ");
				ltoa(buf, (long)priv->cnt_error_fifo_rx, 10);
				display_string(buf);
				display_string(", last_error_fifo_rx: 0x");
				ltoa(buf, (long)priv->last_error_fifo_rx & 0xffff, 16);
				display_string(buf);
				display_string("\r\n");
				old_cnt_error_fifo_rx = priv->cnt_error_fifo_rx;
			}
			if(old_cnt_error_fifo_tx != priv->cnt_error_fifo_tx)
			{
				char buf[10];
				display_string("mcf548x_ac97_bus_write cnt_error_fifo_tx: ");
				ltoa(buf, (long)priv->cnt_error_fifo_tx, 10);
				display_string(buf);
				display_string(", last_error_fifo_tx: 0x");
				ltoa(buf, (long)priv->last_error_fifo_tx & 0xffff, 16);
				display_string(buf);
				display_string("no answer\r\n");
				old_cnt_error_fifo_tx = priv->cnt_error_fifo_tx;
			}
			if(old_cnt_error_sync != priv->cnt_error_sync)
			{
				char buf[10];
				display_string("mcf548x_ac97_bus_write cnt_error_sync: ");
				ltoa(buf, (long)priv->cnt_error_sync, 10);
				display_string(buf);
				display_string("\r\n");
				old_cnt_error_sync = priv->cnt_error_sync;
			}
#endif
		  if((start_timer - MCF_SLT_SCNT(1)) >= AC97_TIMEOUT)
			{
#ifdef DEBUG
				char buf[10];
				display_string("mcf548x_ac97_bus_write reg: 0x");
				ltoa(buf, (long)reg & 0xffff, 16);
				display_string(buf);
				display_string(", timeout\r\n");
#endif
				priv->ctrl_mode = 0;
				return; /* timeout */
			}
		}
		/* Write data */
		level = asm_set_ipl(7);
		priv->ctrl_address = (int)reg;
		priv->ctrl_data = (int)val;
		priv->status_data = (int)~val;
		priv->ctrl_rw = 0; /* write */
		priv->ctrl_mode = 1;
		asm_set_ipl(level);
		/* Wait for the answer */
		while(priv->ctrl_mode)
		{
#ifdef DEBUG
			if(old_cnt_error_fifo_rx != priv->cnt_error_fifo_rx)
			{
				char buf[10];
				display_string("mcf548x_ac97_bus_write cnt_error_fifo_rx: ");
				ltoa(buf, (long)priv->cnt_error_fifo_rx, 10);
				display_string(buf);
				display_string(", last_error_fifo_rx: 0x");
				ltoa(buf, (long)priv->last_error_fifo_rx & 0xffff, 16);
				display_string(buf);
				display_string("\r\n");
				old_cnt_error_fifo_rx = priv->cnt_error_fifo_rx;
			}
			if(old_cnt_error_fifo_tx != priv->cnt_error_fifo_tx)
			{
				char buf[10];
				display_string("mcf548x_ac97_bus_write cnt_error_fifo_tx: ");
				ltoa(buf, (long)priv->cnt_error_fifo_tx, 10);
				display_string(buf);
				display_string(", last_error_fifo_tx: 0x");
				ltoa(buf, (long)priv->last_error_fifo_tx & 0xffff, 16);
				display_string(buf);
				display_string("no answer\r\n");
				old_cnt_error_fifo_tx = priv->cnt_error_fifo_tx;
			}
			if(old_cnt_error_sync != priv->cnt_error_sync)
			{
				char buf[10];
				display_string("mcf548x_ac97_bus_write cnt_error_sync: ");
				ltoa(buf, (long)priv->cnt_error_sync, 10);
				display_string(buf);
				display_string("\r\n");
				old_cnt_error_sync = priv->cnt_error_sync;
			}
#endif
		  if((start_timer - MCF_SLT_SCNT(1)) >= AC97_TIMEOUT)
			{
#ifdef DEBUG
				char buf[10];
				display_string("mcf548x_ac97_bus_write reg: 0x");
				ltoa(buf, (long)reg & 0xffff, 16);
				display_string(buf);
				display_string(", timeout\r\n");
#endif
				priv->ctrl_mode = 0;
				return; /* timeout */
			}
		}
		count++;
	}
	while((priv->ctrl_data != priv->status_data) && (count < AC97_RETRY_WRITE));
#ifdef DEBUG
	{
		char buf[10];
		measure_timer -= MCF_SLT_SCNT(1);
		measure_timer /= 100;
		display_string("mcf548x_ac97_bus_write reg: 0x");
		ltoa(buf, (long)reg & 0xffff, 16);
		display_string(buf);
		display_string(", value: 0x");
		ltoa(buf, (long)priv->ctrl_data & 0xffff, 16);
		display_string(buf);
		display_string(" => count: ");
		ltoa(buf, (long)count, 10);
		display_string(buf);
		display_string(" (");
		ltoa(buf, measure_timer, 10);
		display_string(buf);
		display_string(" uS)\r\n");
	}
#endif
}

static void mcf548x_ac97_bus_reset(struct snd_ac97 *ac97)
{
	struct mcf548x_ac97_priv *priv = ac97->private_data;
	/* Do a warm reset of codec - 1uS */
	MCF_PSC_SICR(priv->psc_channel) |= MCF_PSC_SICR_AWR;
	udelay(1);
	MCF_PSC_SICR(priv->psc_channel) &= ~MCF_PSC_SICR_AWR;
	priv->codec_ready = 0,
	priv->cnt_error_fifo_rx = 0;
	priv->cnt_error_fifo_tx = 0;
	priv->last_error_fifo_rx = 0;
	priv->last_error_fifo_tx = 0;
	priv->cnt_error_sync = 0;
	priv->cnt_error_empty_tx = 0;
#ifdef PERIOD
	priv->time_get_frame = 0;
	priv->time_build_frame = 0;
	priv->period_get_frame = 0;
	priv->period_build_frame = 0;
#endif
//	mcf548x_ac97_bus_write(ac97, AC97_RESET, 0);	/* reset audio codec */
}

static struct snd_ac97_bus_ops mcf548x_ac97_bus_ops = {
	.read = mcf548x_ac97_bus_read,
	.write = mcf548x_ac97_bus_write,
	.reset = mcf548x_ac97_bus_reset,
};

/* ======================================================================== */
/* PCM interface                                                            */
/* ======================================================================== */

static void mcf548x_ac97_create_offsets(long frequency, long nearest_freq, int mode, unsigned char *tab_incr_offsets)
{
	if(frequency != nearest_freq)
	{ // VRA not works => create soft offsets
		long tab_offsets[AC97_SAMPLES_BY_BUFFER+1];
    int i;
    long incr, offset = 0;
		int coeff = nearest_freq / AC97_SAMPLES_BY_BUFFER;
		int new_samples_by_buffer = frequency / coeff;
		if((frequency % coeff) >= (coeff >> 1))
			new_samples_by_buffer++;
		if(new_samples_by_buffer > AC97_SAMPLES_BY_BUFFER)
			new_samples_by_buffer = AC97_SAMPLES_BY_BUFFER;
		incr = (long)((new_samples_by_buffer << 16) / AC97_SAMPLES_BY_BUFFER);
		switch(mode)
		{
			case STEREO8:
			case STEREO16:
				for(i = 0; i <= AC97_SAMPLES_BY_BUFFER; i++)
				{
					tab_offsets[i] = (offset >> 16) << 1;
					offset += incr;
				}
				break;
			default:
				for(i = 0; i <= AC97_SAMPLES_BY_BUFFER; i++)
				{
					tab_offsets[i] = offset >> 16;
					offset += incr;
				}
				break;
		}
		for(i = 0; i < AC97_SAMPLES_BY_BUFFER; i++)
			tab_incr_offsets[i] = (unsigned char)(tab_offsets[i+1] - tab_offsets[i]);
	}
}

static void mcf548x_ac97_clear_playback(struct mcf548x_ac97_priv *priv)
{
	int level = asm_set_ipl(7);
	priv->play_record_mode &= ~(SB_PLA_RPT|SB_PLA_ENA); 
	priv->play_samples = NULL;
	priv->play_start_samples = NULL;
	priv->play_end_samples = NULL;
	priv->new_play_start_samples = NULL;
	priv->new_play_end_samples = NULL;
	priv->cause_inter &= ~SI_PLAY;
	priv->callback_play = NULL;
	asm_set_ipl(level);
}

int mcf548x_ac97_playback_open(long psc_channel)
{
	struct mcf548x_ac97_priv *priv;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(priv->open_play)
		return(-1); // error
#ifdef DEBUG
	display_string("mcf548x_ac97_playback_open\r\n");
#endif
	priv->open_play = 1;
	mcf548x_ac97_clear_playback(priv);
	return(0); // OK
}

int mcf548x_ac97_playback_close(long psc_channel)
{
	struct mcf548x_ac97_priv *priv;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_play)
		return(-1); // error
#ifdef DEBUG
	display_string("mcf548x_ac97_playback_close\r\n");
#endif
	priv->open_play = 0;
	mcf548x_ac97_clear_playback(priv);
	return(0); // OK
}

int mcf548x_ac97_playback_prepare(long psc_channel, long frequency, long res, long mode)
{
	long tab_freq[] = { 8000,11025,16000,22050,32000,44100,48000 };
	long nearest_freq;
	struct mcf548x_ac97_priv *priv;
	long d, mini = 999999;
	int i = 0, index = 0;
	int level;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_play)
		return(-1); // error
	while(i < sizeof(tab_freq)/sizeof(tab_freq[0]))
	{
		d = tab_freq[i++] - frequency;
		if(d < 0)
			d = -d;
		if(d < mini)
		{
			mini = d;
			index = i - 1;
		}
	}
	nearest_freq = tab_freq[index];
	switch(nearest_freq)
	{
		case 8000:
			if(priv->ac97->rates[AC97_RATES_FRONT_DAC] & SNDRV_PCM_RATE_8000)
				break;
			nearest_freq = 48000;
			break;
		case 11025:
			if(priv->ac97->rates[AC97_RATES_FRONT_DAC] & SNDRV_PCM_RATE_11025)
				break;
			nearest_freq = 48000;
			break;
		case 16000:
			if(priv->ac97->rates[AC97_RATES_FRONT_DAC] & SNDRV_PCM_RATE_16000)
				break;
			nearest_freq = 48000;
			break;
		case 22050:
			if(priv->ac97->rates[AC97_RATES_FRONT_DAC] & SNDRV_PCM_RATE_22050)
				break;
			nearest_freq = 48000;
			break;
		case 32000:
			if(priv->ac97->rates[AC97_RATES_FRONT_DAC] & SNDRV_PCM_RATE_32000)
				break;
			nearest_freq = 48000;
			break;
		case 44100:
			if(priv->ac97->rates[AC97_RATES_FRONT_DAC] & SNDRV_PCM_RATE_44100)
				break;
			nearest_freq = 48000;
			break;
		case 48000:
			if(priv->ac97->rates[AC97_RATES_FRONT_DAC] & SNDRV_PCM_RATE_48000)
				break;
			return(-1); // error
	}
	mcf548x_ac97_create_offsets(frequency, nearest_freq, res, priv->incr_offsets_play);
#if 1
	// Vendor Specific - Mic Crystal Control CS4299
//	mcf548x_ac97_bus_write(priv->ac97, 0x60, 0x22); // remove LOSM
	// Vendor Specific - AC Mode Control Register CS4299
	mcf548x_ac97_bus_write(priv->ac97, 0x5e, 0x100); // set DDM, DAC Direct Mode
#endif
	mcf548x_ac97_bus_write(priv->ac97, AC97_PCM_FRONT_DAC_RATE, nearest_freq);
	level = asm_set_ipl(7);
	priv->play_frequency = frequency;
	priv->freq_dac = nearest_freq;
	priv->play_record_mode = priv->play_record_mode | ((int)mode & SB_PLA_RPT);
	priv->play_res = res & 0xff;
	asm_set_ipl(level);
#ifdef DEBUG
	{
		char buf[10];
		display_string("mcf548x_ac97_playback_prepare, frequency: ");
		ltoa(buf, frequency, 10);
		display_string(buf);
		display_string(", res: ");
		ltoa(buf, res, 10);
		display_string(buf);
		display_string(", mode: ");
		ltoa(buf, mode, 10);
		display_string(buf);
		display_string(" => play_frequency: ");
		ltoa(buf, priv->play_frequency, 10);
		display_string(buf);
		display_string(", freq_dac: ");
		ltoa(buf, priv->freq_dac, 10);
		display_string(buf);
		display_string(", rates: 0x");
		ltoa(buf, priv->ac97->rates[AC97_RATES_FRONT_DAC], 16);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	return(0); // OK
}

int mcf548x_ac97_playback_callback(long psc_channel, void (*callback)())
{
	struct mcf548x_ac97_priv *priv;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_play)
		return(-1); // error
	priv->callback_play = callback;
#ifdef DEBUG
	{
		char buf[10];
		display_string("mcf548x_ac97_playback_callback, callback: 0x");
		ltoa(buf, (long)callback, 16);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	return(0); // OK
}

int mcf548x_ac97_playback_trigger(long psc_channel, long cmd)
{
	struct mcf548x_ac97_priv *priv;
	int level;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_play)
		return(-1); // error
	level = asm_set_ipl(7);
	if(cmd && (priv->play_samples != NULL))
		priv->play_record_mode |= SB_PLA_ENA; /* play enable */
	else
		priv->play_record_mode &= ~SB_PLA_ENA;
	asm_set_ipl(level);
#ifdef DEBUG
	{
		char buf[10];
		display_string("mcf548x_ac97_playback_trigger, cmd: ");
		ltoa(buf, cmd, 10);
		display_string(buf);
		display_string(" => play_record_mode: ");
		ltoa(buf, priv->play_record_mode, 10);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	return(0); // OK
}

int mcf548x_ac97_playback_pointer(long psc_channel, void **ptr, long set)
{
	struct mcf548x_ac97_priv *priv;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	if(ptr == NULL)
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_play)
		return(-1); // error
	if(set)
	{
		if(priv->play_record_mode & SB_PLA_ENA)
		{	
			priv->new_play_start_samples = ptr[0];
			priv->new_play_end_samples = ptr[1];
		}
		else
		{
			priv->play_samples = priv->play_start_samples = ptr[0];
			priv->play_end_samples = ptr[1];
		}
#ifdef DEBUG
		{
			char buf[10];
			display_string("mcf548x_ac97_playback_pointer, ptrs: 0x");
			ltoa(buf, (long)ptr[0], 16);
			display_string(buf);
			display_string(", 0x");
			ltoa(buf, (long)ptr[1], 16);
			display_string(buf);
			display_string("\r\n");
		}
#endif
	}
	else
	{
		if(priv->play_record_mode & SB_PLA_ENA)
			*ptr = priv->play_samples;
		else
			*ptr = NULL;
#if 0 // #ifdef DEBUG
		{
		  int i;
			char buf[10];
			display_string("mcf548x_ac97_playback_pointer, ptr: 0x");
			ltoa(buf, (long)*ptr, 16);
			display_string(buf);
			display_string("\r\n");
			for(i = 0; i < AC97_SAMPLES_BY_BUFFER; i++)
			{
				ltoa(buf, (long)priv->slotreq[i], 16);
				display_string(buf);
				display_string(" ");
				if((i & 17) == 15)
					display_string("\r\n");
			}
		}
#endif
	}
	return(0); // OK
}

static void mcf548x_ac97_clear_capture(struct mcf548x_ac97_priv *priv)
{
	int level = asm_set_ipl(7);
	priv->play_record_mode &= ~(SB_REC_RPT|SB_REC_ENA);
	priv->record_samples = NULL;
	priv->record_start_samples = NULL;
	priv->record_end_samples = NULL;
	priv->new_record_start_samples = NULL;
	priv->new_record_end_samples = NULL;
	priv->cause_inter &= ~SI_RECORD;
	priv->callback_record = NULL;
	asm_set_ipl(level);
}

int mcf548x_ac97_capture_open(long psc_channel)
{
	struct mcf548x_ac97_priv *priv;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(priv->open_record)
		return(-1); // error
#ifdef DEBUG
	display_string("mcf548x_ac97_capture_open\r\n");
#endif
	priv->open_record = 1;
	mcf548x_ac97_clear_capture(priv);
	return(0); // OK
}

int mcf548x_ac97_capture_close(long psc_channel)
{
	struct mcf548x_ac97_priv *priv;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_record)
		return(-1); // error
#ifdef DEBUG
	display_string("mcf548x_ac97_capture_close\r\n");
#endif
	priv->open_record = 0;
	mcf548x_ac97_clear_capture(priv);
	return(0); // OK
}

int mcf548x_ac97_capture_prepare(long psc_channel, long frequency, long res, long mode)
{
	long tab_freq[] = { 8000,11025,16000,22050,32000,44100,48000 };
	long nearest_freq;
	struct mcf548x_ac97_priv *priv;
	long d, mini = 999999;
	int i = 0, index = 0;
	int level;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_record)
		return(-1); // error
	while(i < sizeof(tab_freq)/sizeof(tab_freq[0]))
	{
		d = tab_freq[i++] - frequency;
		if(d < 0)
			d = -d;
		if(d < mini)
		{
			mini = d;
			index = i - 1;
		}
	}
	nearest_freq = tab_freq[index];
	switch(nearest_freq)
	{
		case 8000:
			if(priv->ac97->rates[AC97_RATES_ADC] & SNDRV_PCM_RATE_8000)
				break;
			nearest_freq = 48000;
			break;
		case 11025:
			if(priv->ac97->rates[AC97_RATES_ADC] & SNDRV_PCM_RATE_11025)
				break;
			nearest_freq = 48000;
			break;
		case 16000:
			if(priv->ac97->rates[AC97_RATES_ADC] & SNDRV_PCM_RATE_16000)
				break;
			nearest_freq = 48000;
			break;
		case 22050:
			if(priv->ac97->rates[AC97_RATES_ADC] & SNDRV_PCM_RATE_22050)
				break;
			nearest_freq = 48000;
			break;
		case 32000:
			if(priv->ac97->rates[AC97_RATES_ADC] & SNDRV_PCM_RATE_32000)
				break;
			nearest_freq = 48000;
			break;
		case 44100:
			if(priv->ac97->rates[AC97_RATES_ADC] & SNDRV_PCM_RATE_44100)
					break;
			nearest_freq = 48000;
			break;
		case 48000:
			if(priv->ac97->rates[AC97_RATES_ADC] & SNDRV_PCM_RATE_48000)
				break;
			return(-1); // error
	}
	mcf548x_ac97_create_offsets(frequency, nearest_freq, res, priv->incr_offsets_record);
	mcf548x_ac97_bus_write(priv->ac97, AC97_PCM_LR_ADC_RATE, nearest_freq);
	level = asm_set_ipl(7);
	priv->record_frequency = frequency;
	priv->freq_adc = nearest_freq;
	priv->play_record_mode = priv->play_record_mode | ((int)mode & SB_REC_RPT);
	priv->record_res = res & 0xff00;
	mcf548x_ac97_bus_write(priv->ac97, AC97_PCM_LR_ADC_RATE, nearest_freq);
	asm_set_ipl(level);
#ifdef DEBUG
	{
		char buf[10];
		display_string("mcf548x_ac97_capture_prepare, frequency: ");
		ltoa(buf, frequency, 10);
		display_string(buf);
		display_string(", res: ");
		ltoa(buf, res, 10);
		display_string(buf);
		display_string(", mode: ");
		ltoa(buf, mode, 10);
		display_string(buf);
		display_string(" => record_frequency: ");
		ltoa(buf, priv->record_frequency, 10);
		display_string(buf);
		display_string(", freq_adc: ");
		ltoa(buf, priv->freq_adc, 10);
		display_string(buf);
		display_string(", rates: 0x");
		ltoa(buf, priv->ac97->rates[AC97_RATES_ADC], 16);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	return(0); // OK
}

int mcf548x_ac97_capture_callback(long psc_channel, void (*callback)())
{
	struct mcf548x_ac97_priv *priv;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_play)
		return(-1); // error
	priv->callback_play = callback;
#ifdef DEBUG
	{
		char buf[10];
		display_string("mcf548x_ac97_capture_callback, callback: 0x");
		ltoa(buf, (long)callback, 16);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	return(0); // OK
}

int mcf548x_ac97_capture_trigger(long psc_channel, long cmd)
{
	struct mcf548x_ac97_priv *priv;
	int level;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_record)
		return(-1); // error
	level = asm_set_ipl(7);
	if(cmd && (priv->record_samples != NULL))
		priv->play_record_mode |= SB_REC_ENA; /* record enable */
	else
		priv->play_record_mode &= ~SB_REC_ENA; 
	asm_set_ipl(level);
#ifdef DEBUG
	{
		char buf[10];
		display_string("mcf548x_ac97_capture_trigger, cmd: ");
		ltoa(buf, cmd, 10);
		display_string(buf);
		display_string(" => play_record_mode: ");
		ltoa(buf, priv->play_record_mode, 10);
		display_string(buf);
		display_string("\r\n");
	}
#endif
	return(0); // OK
}

int mcf548x_ac97_capture_pointer(long psc_channel, void **ptr, long set)
{
	struct mcf548x_ac97_priv *priv;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	if(ptr == NULL)
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if(!priv->open_record)
		return(-1); // error
	if(set)
	{
		if(priv->play_record_mode & SB_REC_ENA)
		{	
			priv->new_record_start_samples = ptr[0];
			priv->new_record_end_samples = ptr[1];
		}
		else
		{
			priv->record_samples = priv->record_start_samples = ptr[0];
			priv->record_end_samples = ptr[1];
		}
#ifdef DEBUG
		{
			char buf[10];
			display_string("mcf548x_ac97_capture_pointer, ptr: 0x");
			ltoa(buf, (long)ptr[0], 16);
			display_string(buf);
			display_string(", 0x");
			ltoa(buf, (long)ptr[1], 16);
			display_string(buf);
			display_string("\r\n");
		}
#endif
	}
	else
	{
		if(priv->play_record_mode & SB_REC_ENA)
			*ptr = priv->record_samples;
		else
			*ptr = NULL;
#ifdef DEBUG
		{
			char buf[10];
			display_string("mcf548x_ac97_capture_pointer, ptr: 0x");
			ltoa(buf, (long)*ptr, 16);
			display_string(buf);
			display_string("\r\n");
		}
#endif
	}
	return(0); // OK
}

static int mcf5485_ac97_cmd(struct mcf548x_ac97_priv *priv, char *name, int channels, int value)
{
	struct snd_ctl_elem_info info;
	struct snd_ctl_elem_value ctl;
	if(channels)
	{
		info.id.iface = SNDRV_CTL_ELEM_IFACE_MIXER;
		strcpy((void *)&info.id.name, name);
		snd_ctl_elem_info(priv->card, &info);
		ctl.value.integer.value[0] = (LEFT_CHANNEL_VOLUME(value) * (info.value.integer.max + 1)) >> 8;
#if 0 // #ifdef DEBUG
	{
		char buf[10];
		display_string("mcf5485_ac97_cmd name: ");
		display_string(name);
		display_string(", channels: ");
		ltoa(buf, (long)channels, 10);
		display_string(buf);
		display_string(", value: 0x");
		ltoa(buf, (long)value, 16);
		display_string(buf);
		display_string(" => max: 0x");
		ltoa(buf, (long)info.value.integer.max, 16);
		display_string(buf);
		display_string(", value: 0x");
		ltoa(buf, (long)ctl.value.integer.value[0], 16);
		display_string(buf);
		display_string("\r\n");	
	}
#endif
		if(channels > 1)
			ctl.value.integer.value[1] = (RIGHT_CHANNEL_VOLUME(value) * (info.value.integer.max + 1)) >> 8;
	}
	else
	{
		ctl.value.enumerated.item[0] = LEFT_CHANNEL_VOLUME(value);
		ctl.value.enumerated.item[1] = RIGHT_CHANNEL_VOLUME(value);
	}
	ctl.id.iface = SNDRV_CTL_ELEM_IFACE_MIXER;	
	strcpy((void *)&ctl.id.name, name);
	return(snd_ctl_elem_write(priv->card, &ctl));
}

int mcf548x_ac97_ioctl(long psc_channel, unsigned int cmd, void *arg)
{
	struct mcf548x_ac97_priv *priv;
	int value = *(int *)arg; 
	int err;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
#if 0 // #ifdef DEBUG
	{
		char buf[10];
		display_string("mcf548x_ac97_ioctl cmd: 0x");
		ltoa(buf, (long)cmd, 16);
		display_string(buf);
		display_string(", value: 0x");
		ltoa(buf, (long)value, 16);
		display_string(buf);
		display_string("\r\n");	
	}
#endif
	switch(cmd)
	{
		// outputs
		case SOUND_MIXER_WRITE_VOLUME:
			if(value & 0xff000000)
			{
				err = mcf5485_ac97_cmd(priv, "Master Playback Switch", 1, (value >> 16) & 0xff);
				err |= mcf5485_ac97_cmd(priv, "Headphone Playback Switch", 1, (value >> 16) & 0xff);
				return(err | mcf5485_ac97_cmd(priv, "Master Mono Playback Switch", 1, (value >> 16) & 0xff));
			}
		  else
		  {
		  	int mono = (LEFT_CHANNEL_VOLUME(value) + RIGHT_CHANNEL_VOLUME(value)) >> 1;
				err = mcf5485_ac97_cmd(priv, "Master Playback Volume", 2, value);
				err |= mcf5485_ac97_cmd(priv, "Headphone Playback Volume", 2, value);
				return(err | mcf5485_ac97_cmd(priv, "Master Mono Playback Volume", 1, mono));
			}
		case SOUND_MIXER_WRITE_BASS:
			return(mcf5485_ac97_cmd(priv, "Tone Control - Bass", 1, value));
		case SOUND_MIXER_WRITE_TREBLE:
			return(mcf5485_ac97_cmd(priv, "Tone Control - Treble", 1, value));		
		case SOUND_MIXER_WRITE_SYNTH:
			if(value & 0xff000000)
				return(mcf5485_ac97_cmd(priv, "PC Speaker Capture Switch", 1, (value >> 16) & 0xff));
			else
				return(mcf5485_ac97_cmd(priv, "PC Speaker Capture Volume", 1, value));
		case SOUND_MIXER_WRITE_PCM:
			if(value & 0xff000000)
				return(mcf5485_ac97_cmd(priv, "PCM Playback Switch", 1, (value >> 16) & 0xff));
			else
				return(mcf5485_ac97_cmd(priv, "PCM Playback Volume", 2, value));
		case SOUND_MIXER_WRITE_SPEAKER:
			if(value & 0xff000000)
				return(mcf5485_ac97_cmd(priv, "PC Speaker Playback Switch", 1, (value >> 16) & 0xff));
			else
				return(mcf5485_ac97_cmd(priv, "PC Speaker Playback Volume", 1, value));
		// inputs
		case SOUND_MIXER_WRITE_LINE:
			if(value & 0xff000000)
				return(mcf5485_ac97_cmd(priv, "Line Playback Switch", 1, (value >> 16) & 0xff));
			else
				return(mcf5485_ac97_cmd(priv, "Line Playback Volume", 2, value));
		case SOUND_MIXER_WRITE_CD:
			if(value & 0xff000000)
				return(mcf5485_ac97_cmd(priv, "CD Playback Switch", 1, (value >> 16) & 0xff));
			else
				return(mcf5485_ac97_cmd(priv, "CD Playback Volume", 2 , value));
		case SOUND_MIXER_WRITE_LINE1:
			if(value & 0xff000000)
				return(mcf5485_ac97_cmd(priv, "Aux Playback Switch", 1, (value >> 16) & 0xff));
			else
				return(mcf5485_ac97_cmd(priv, "Aux Playback Volume", 2 , value));
		case SOUND_MIXER_WRITE_LINE2:
			if(value & 0xff000000)
				return(mcf5485_ac97_cmd(priv, "Video Playback Switch", 1, (value >> 16) & 0xff));
			else
				return(mcf5485_ac97_cmd(priv, "Video Playback Volume", 2 , value));
		case SOUND_MIXER_WRITE_MIC:
			if(value & 0xff000000)
			{
			  /* 0:Mic1, 1:Mic2 */
				err = mcf5485_ac97_cmd(priv, "Mic Select", 0, value);
				return(err | mcf5485_ac97_cmd(priv, "Mic Playback Switch", 1, (value >> 16) & 0xff));
			}
			else
			{
		  	int mono = LEFT_CHANNEL_VOLUME(value) + RIGHT_CHANNEL_VOLUME(value);
				err = mcf5485_ac97_cmd(priv, "Mic Boost (+20dB)", 1, (mono & 0x100) ? 0xff : 0);
				return(mcf5485_ac97_cmd(priv, "Mic Playback Volume", 2 , value));
			}
		case SOUND_MIXER_WRITE_RECLEV:
			return(mcf5485_ac97_cmd(priv, "Capture Volume", 2, value));
		case SOUND_MIXER_WRITE_ENHANCE:
			if(value & 0xff000000)
				return(mcf5485_ac97_cmd(priv, "3D Control - Switch", 1, (value >> 16) & 0xff));
			else
				return(mcf5485_ac97_cmd(priv, "3D Control - Depth", 1, value));
		case SOUND_MIXER_WRITE_LOUD:
			return(mcf5485_ac97_cmd(priv, "Loudness (bass boost)", 1, value));
		case SOUND_MIXER_WRITE_RECSRC:
			/* 0:Mic, 1:CD, 2:Video, 3:Aux, 4:Line, 5:Mix Stereo, 6:Mix Mono, 7:Phone */
			return(mcf5485_ac97_cmd(priv, "Capture Source", 0, value));
	}
	return(-1); // error
}

/* ======================================================================== */
/* AC97 Interface Debug                                                     */
/* ======================================================================== */

#ifdef LWIP

int mcf548x_ac97_debug_read(long psc_channel, long reg)
{
	struct mcf548x_ac97_priv *priv;
	unsigned long start_timer = MCF_SLT_SCNT(1);
	int level;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if((reg < 0) || (reg >= 0x80))
		return(-1);
	/* Wait for it to be ready */
	while(!priv->codec_ready || priv->ctrl_mode)
	{
		vTaskDelay(1);
	  if((start_timer - MCF_SLT_SCNT(1)) >= AC97_TIMEOUT)
		{
			priv->ctrl_mode = 0;
			return(-1); /* timeout */
		}
	}
	/* Do the read - Control Address - Slot #1 */
	level = asm_set_ipl(7);
	priv->ctrl_address = (int)reg;
	priv->ctrl_rw = 1; /* read */
	priv->ctrl_mode = 1;
	start_timer = MCF_SLT_SCNT(1);
	asm_set_ipl(level);
	/* Wait for the answer */
	while(priv->ctrl_mode)
	{
		vTaskDelay(1);
	  if((start_timer - MCF_SLT_SCNT(1)) >= AC97_TIMEOUT)
		{
			priv->ctrl_mode = 0;
			return(-1); /* timeout */
		}
	}
	return(priv->status_data);
}

int mcf548x_ac97_debug_write(long psc_channel, long reg, long val)
{
	struct mcf548x_ac97_priv *priv;
	unsigned long start_timer;
	int level, count = 0;
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	priv = Devices[psc_channel];
	if(priv == NULL)
		return(-1); // error
	if((reg < 0) || (reg >= 0x80))
		return(-1);
	do
	{
		start_timer = MCF_SLT_SCNT(1);
		/* Wait for it to be ready */
		while(!priv->codec_ready || priv->ctrl_mode)
		{
			vTaskDelay(1);
		  if((start_timer - MCF_SLT_SCNT(1)) >= AC97_TIMEOUT)
			{
				priv->ctrl_mode = 0;
				return(-1); /* timeout */
			}
		}
		/* Write data */
		level = asm_set_ipl(7);
		priv->ctrl_address = (int)reg;
		priv->ctrl_data = (int)val;
		priv->status_data = (int)~val;
		priv->ctrl_rw = 0; /* write */
		priv->ctrl_mode = 1;
		asm_set_ipl(level);
		/* Wait for the answer */
		while(priv->ctrl_mode)
		{
			vTaskDelay(1);
		  if((start_timer - MCF_SLT_SCNT(1)) >= AC97_TIMEOUT)
			{
				priv->ctrl_mode = 0;
				return(-1); /* timeout */
			}
		}
		count++;
	}
	while((priv->ctrl_data != priv->status_data) && (count < AC97_RETRY_WRITE));
	return(0);
}

#endif /* LWIP */

/* ======================================================================== */
/* Sound driver setup                                                       */
/* ======================================================================== */

static int mcf548x_ac97_setup_mixer(struct mcf548x_ac97_priv *priv)
{
	struct snd_ac97_bus *ac97_bus;
	struct snd_ac97_template ac97_template;
#ifdef DEBUG
	display_string("mcf548x_ac97_setup_mixer\r\n");
#endif
	int rv = snd_ac97_bus(priv->card, 0, &mcf548x_ac97_bus_ops, NULL, &ac97_bus);
	if(rv)
		return(rv);
	memset(&ac97_template, 0, sizeof(struct snd_ac97_template));
	ac97_template.private_data = priv;
	return(snd_ac97_mixer(ac97_bus, &ac97_template, &priv->ac97));
}

int mcf548x_ac97_install(long psc_channel)
{
	if(mcf548x_ac97_psc0_interrupt);
	if(mcf548x_ac97_psc1_interrupt);
	if(mcf548x_ac97_psc2_interrupt);
	if(mcf548x_ac97_psc3_interrupt);
	if((psc_channel < 0) || (psc_channel > 4))
		return(-1); // error
	else
	{
		struct snd_card *card = (struct snd_card *)Mxalloc(sizeof(struct snd_card),2);
		struct mcf548x_ac97_priv *priv = (struct mcf548x_ac97_priv *)Mxalloc(sizeof(struct mcf548x_ac97_priv),2);
		if((card != NULL) && (priv != NULL))
		{
			card->private_data = (void *)priv;
			/* Init our private structure */
			memset(priv, sizeof(struct mcf548x_ac97_priv), 0);
			Devices[psc_channel] = priv;
			priv->card = card;
			priv->psc_channel = psc_channel;
#ifdef USE_DMA
			if(!mcf548x_ac97_bdinit(priv))
#endif
			{
#ifdef USE_DMA
				if(!mcf548x_ac97_rx_start(priv))
				{
//					if(!mcf548x_ac97_tx_start(priv))
					{
#endif
						/* Low level HW Init */
						if(!mcf548x_ac97_hwinit(priv))
						{
							/* Prepare sound stuff */
							if(!mcf548x_ac97_setup_mixer(priv))
							{
#ifdef DEBUG
								char buf[10];
								display_string("mcf548x_ac97_install cnt_error_sync: ");
								ltoa(buf, (long)priv->cnt_error_sync, 10);
								display_string(buf);
								display_string("\r\n");
#endif
								return(0); // OK
							}
#ifdef DEBUG
							{
								char buf[10];
								display_string("mcf548x_ac97_install cnt_error_sync: ");
								ltoa(buf, (long)priv->cnt_error_sync, 10);
								display_string(buf);
								display_string("\r\n");
							}

							display_string("mcf548x_ac97_setup_mixer error\r\n");
#endif
						}
#ifdef USE_DMA
						else
						{
							mcf548x_ac97_rx_stop(priv);
							mcf548x_ac97_tx_stop(priv);						
						}
					}
//					else
//						mcf548x_ac97_rx_stop(priv);
				}
#endif
			}
		}
		if(priv != NULL)
		  Mfree(priv);
		if(card != NULL)
			Mfree(card);
		return(-1); // error
	}
}

#endif /* NETWORK */
#endif /* SOUND_AC97 */
