/* VDI Videl modes
 * Didier Mequignon 2009-2010, e-mail: aniplay@wanadoo.fr
 * Thanks to MiKRO and his help for HDB / HDE registers !
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
 * along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
 
#include "config.h"
#include <mint/osbind.h>
#include <mint/sysvars.h>
#include <string.h>
#include "fb.h"
#include "edid.h"


#ifndef Screalloc
#define Screalloc(size) (void *)trap_1_wl((short)(0x15),(long)(size))
#endif


#define MT_DFP 1
#define MT_CRT 0

#define TFP_ADDR 0x7A
#define DCC_ADDR 0xA0
#define TEMPO_US 5
#define TIMEOUT (100000 * SYSTEM_CLOCK) /* 100 mS */
#define TIMEOUT_PLL (1000 * SYSTEM_CLOCK) /* 1 mS */

#define SCREEN_POS_ACP (*(volatile unsigned char *)0xFFFF8200)
#define SCREEN_POS_HIGH (*(volatile unsigned char *)0xFFFF8201)
#define SCREEN_POS_MID (*(volatile unsigned char *)0xFFFF8203)
#define VIDEO_SYNC (*(volatile unsigned char *)0xFFFF820A)
#define SCREEN_POS_LOW (*(volatile unsigned char *)0xFFFF820D)
#define OFF_NEXT_LINE (*(volatile unsigned short *)0xFFFF820E)
#define VWRAP (*(volatile unsigned short *)0xFFFF8210)
#define CLUT ((volatile unsigned short *)0xFFFF8240)
#define SHIFT (*(volatile unsigned char *)0xFFFF8260)
#define SPSHIFT (*(volatile unsigned short *)0xFFFF8266)
#define HHC (*(volatile unsigned short *)0xFFFF8280) // Horizontal Hold Counter
#define HHT (*(volatile unsigned short *)0xFFFF8282) // Horizontal Hold Timer
#define HBB (*(volatile unsigned short *)0xFFFF8284) // Horizontal Border Begin
#define HBE (*(volatile unsigned short *)0xFFFF8286) // Horizontal Border End
#define HDB (*(volatile unsigned short *)0xFFFF8288) // Horizontal Display Begin
#define HDE (*(volatile unsigned short *)0xFFFF828A) // Horizontal Display End
#define HSS (*(volatile unsigned short *)0xFFFF828C) // Horizontal Sync Start
#define HFS (*(volatile unsigned short *)0xFFFF828E)
#define HEE (*(volatile unsigned short *)0xFFFF8290)
#define VFC (*(volatile unsigned short *)0xFFFF82A0) // Vertical Frequency Counter
#define VFT (*(volatile unsigned short *)0xFFFF82A2) // Vertical Frequency Timer
#define VBB (*(volatile unsigned short *)0xFFFF82A4) // Vertical Border Begin
#define VBE (*(volatile unsigned short *)0xFFFF82A6) // VBlankOff / Vertical Border End
#define VDB (*(volatile unsigned short *)0xFFFF82A8) // Vertical Display Begin
#define VDE (*(volatile unsigned short *)0xFFFF82AA) // Vertical Display End
#define VSS (*(volatile unsigned short *)0xFFFF82AC) // Vertical Sync Start
#define VCO (*(volatile unsigned short *)0xFFFF82C0) // Video Control
#define VCTRL (*(volatile unsigned short *)0xFFFF82C2) // Video Mode
#define VCLUT ((volatile unsigned long *)0xFFFF9800)

#define TFP410_CTL1_MODE 0x08
#define TFP410_CTL2_MODE 0x09
#define TFP410_CTL3_MODE 0x0A
#define TFP410_CFG       0x0B
#define TFP410_DE_DLY    0x32
#define TFP410_DE_CTL    0x33
#define TFP410_DE_TOP    0x34
#define TFP410_DE_CNTL   0x36
#define TFP410_DE_CNTH   0x37
#define TFP410_DE_LINL   0x38
#define TFP410_DE_LINH   0x39

#define VESA_MODES 34
extern long total_modedb;
extern struct fb_videomode modedb[];
extern int asm_set_ipl(int level);
extern void udelay(long usec);
extern long get_timer(void);

struct videl_table {
#define FLAGS_ST_MODES 1
#define FLAGS_ACP_MODES 2
	short width, height; 
	unsigned char frq, clk, bpp, flags;
//     nb_h  BK  BK  DE  DE  top  nb_v BK  BK  DE  DE  top   
	short hht, hbb, hbe, hdb, hde, hss, vft, vbb, vbe, vdb, vde, vss, vctrl, vco;
};

/* Videl native VGA modes */
static struct videl_table table_rez[] = {
#if 0
	{ 320, 200, 60, 25,  4, FLAGS_ST_MODES, 0x017, 0x012, 0x001, 0x20E, 0x00D, 0x011, 0x419, 0x3AF, 0x08F, 0x08F, 0x3AF, 0x415, 5, 0x186 }, // ST-LOW 25 MHz
	{ 640, 200, 60, 25,  2, FLAGS_ST_MODES, 0x017, 0x012, 0x001, 0x20E, 0x00D, 0x011, 0x419, 0x3AF, 0x08F, 0x08F, 0x3AF, 0x415, 9, 0x186 }, // ST-MED 25 MHz
	{ 640, 400, 60, 25,  1, FLAGS_ST_MODES, 0x0C6, 0x08D, 0x015, 0x273, 0x050, 0x096, 0x419, 0x3AF, 0x08F, 0x08F, 0x3AF, 0x415, 8, 0x186 }, // ST-HIG 25 MHz
	{ 320, 240, 60, 25,  2, 0, 0x017, 0x012, 0x001, 0x20A, 0x009, 0x011, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 5, 0x186 }, // 25 MHz
	{ 320, 240, 60, 25,  4, 0, 0x0C6, 0x08D, 0x015, 0x28A, 0x06B, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 5, 0x186 }, // 25 MHz
	{ 320, 240, 60, 25,  8, 0, 0x0C6, 0x08D, 0x015, 0x29A, 0x07B, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 5, 0x186 }, // 25 MHz
	{ 320, 240, 60, 25, 16, 0, 0x0C6, 0x08D, 0x015, 0x2AC, 0x091, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 5, 0x186 }, // 25 MHz
	{ 320, 480, 60, 25,  2, 0, 0x017, 0x012, 0x001, 0x20A, 0x009, 0x011, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 4, 0x186 }, // 25 MHz
	{ 320, 480, 60, 25,  4, 0, 0x0C6, 0x08D, 0x015, 0x28A, 0x06B, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 4, 0x186 }, // 25 MHz
	{ 320, 480, 60, 25,  8, 0, 0x0C6, 0x08D, 0x015, 0x29A, 0x07B, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 4, 0x186 }, // 25 MHz
	{ 320, 480, 60, 25, 16, 0, 0x0C6, 0x08D, 0x015, 0x2AC, 0x091, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 4, 0x186 }, // 25 MHz
	{ 640, 240, 60, 25,  1, 0, 0x0C6, 0x08D, 0x015, 0x273, 0x050, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 9, 0x186 }, // 25 MHz
	{ 640, 240, 60, 25,  2, 0, 0x017, 0x012, 0x001, 0x20E, 0x00D, 0x011, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 9, 0x186 }, // 25 MHz
	{ 640, 240, 60, 25,  4, 0, 0x0C6, 0x08D, 0x015, 0x2A3, 0x07C, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 9, 0x186 }, // 25 MHz
	{ 640, 240, 60, 25,  8, 0, 0x0C6, 0x08D, 0x015, 0x2AB, 0x084, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 9, 0x186 }, // 25 MHz
	{ 640, 240, 60, 25, 16, 0, 0x0C6, 0x08D, 0x015, 0x2AC, 0x091, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 9, 0x186 }, // 25 MHz
	{ 640, 480, 60, 25,  1, 0, 0x0C6, 0x08D, 0x015, 0x273, 0x050, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 8, 0x186 }, // 25 MHz
	{ 640, 480, 60, 25,  2, 0, 0x017, 0x012, 0x001, 0x20E, 0x00D, 0x011, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 8, 0x186 }, // 25 MHz
#endif
	{ 640, 480, 60, 25,  4, 0, 0x0C6, 0x08D, 0x015, 0x2A3, 0x07C, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 8, 0x186 }, // 25 MHz
	{ 640, 480, 60, 25,  8, 0, 0x0C6, 0x08D, 0x015, 0x2AB, 0x084, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 8, 0x186 }, // 25 MHz
	{ 640, 480, 60, 25, 16, 0, 0x0C6, 0x08D, 0x015, 0x2AC, 0x091, 0x096, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 8, 0x186 }, // 25 MHz
//	{ 640, 480, 60, 50, 16, 0, 0x189, 0x126, 0x031, 0x000, 0x160, 0x135, 0x419, 0x3FF, 0x03F, 0x03F, 0x3FF, 0x415, 4, 0x182 }, // 50 MHz
#if 0 // #if defined(COLDFIRE) && defined(MCF547X) /* FIREBEE */
	{ 1280, 1024, 60, 137, 16, FLAGS_ACP_MODES, 1800, 1380, 99, 100, 1379, 1500, 1150, 1074, 49, 50, 1073, 1100, 0, 0 }, // 137 MHz
	{ 1280, 1024, 60, 137, 32, FLAGS_ACP_MODES, 1800, 1380, 99, 100, 1379, 1500, 1150, 1074, 49, 50, 1073, 1100, 0, 0 }  // 137 MHz
#endif
};


void setrgb_videl(long index, long rgb, long type)
{
	index &= 255;
	if(type);
	if(rgb);
}


long get_videl_base(void) /* return 0 for an ACP mode */
{
	long ret = 0;
	ret |= (unsigned long)SCREEN_POS_HIGH;
	ret <<= 8;
	ret |= (unsigned long)SCREEN_POS_MID;
	ret <<= 8;
	ret |= (unsigned long)SCREEN_POS_LOW;
  if(ret >= 0xE00000)
  	ret = 0;
	return(ret);
}

long get_videl_bpp(void)
{
	unsigned long bpp = 1;
	unsigned short spshift = SPSHIFT;
	if(spshift & 0x400)
		bpp = 1;
	else if(spshift & 0x10)
		bpp = 8;
	else if(spshift & 0x100)
		bpp = 16;
	else
	{
		switch(SHIFT)
		{
			case 0: bpp = 4; break;
			case 1: bpp = 2; break;
			default: bpp = 1; break;
		}
	}
	return(bpp);
}

long get_videl_width()
{
  return(((long)VWRAP * 16)/ get_videl_bpp());
}

long get_videl_height(void)
{
	return((long)(VDE - VDB) / 2);
}

long get_videl_size(void)
{
	return(get_videl_height() * (long)VWRAP * 2);
}

void *get_videl_palette(void)
{
	long bpp = get_videl_bpp();
	switch(bpp)
	{
		case 1:
		case 2:
		case 4: return((void *)CLUT);
		case 8: return((void *)VCLUT); /* to fix acp palette */
		default: return(NULL);
	}
}

void videl_blank(long blank)
{
	if(blank);
}

void init_videl_i2c(void)
{
}

long init_videl(long width, long height, long bpp, long refresh, long extended)
{
	long addr = 0;
	int x, st_mode = 0, falcon_mode = 0, acp_mode =0;
	unsigned short vwrap;
	struct videl_table *videl_rez = NULL;
	if(!width || !height || !bpp || !refresh)
		return(0);		
	if((width > 640) || (height > 480) || (bpp > 16))
		return(0);
	for(x = 0; x < (sizeof(table_rez) / sizeof(struct videl_table)); x++)
	{
		if(((long)table_rez[x].width == width) && ((long)table_rez[x].height == height) && ((long)table_rez[x].bpp == bpp))
		{
			st_mode = (int)table_rez[x].flags & FLAGS_ST_MODES;
			acp_mode = (int)table_rez[x].flags & FLAGS_ACP_MODES;
			videl_rez = &table_rez[x];
			falcon_mode = 1;
			break;		
		}		
	}
	if(videl_rez == NULL)
	{
		return(0);
	}
	if(bpp <= 8)
	{
		/*
		                             8 Words * 16 Pixels
		Horizontal pixel multiple =  -------------------
		                                No. of planes	
		*/
		if((width % ((8 * 16) / bpp)) != 0)
			return(0);
	}
	switch(bpp)
	{
		case 1: vwrap = width >> 4; break;
		case 2: vwrap = width >> 3; break;
		case 4: vwrap = width >> 2; break;
		case 8: vwrap = width >> 1; break;
		case 16: vwrap = width; break; // words/line
		case 32: vwrap = width << 1; break;
		default : return(0);
	}
	if(!addr && !acp_mode)
	{
#define MIN_VIDEO_RAM 0xD00000
#define BLOCK_STEP_RAM 0x10000
#define NUM_BLOCKS_RAM (MIN_VIDEO_RAM/BLOCK_STEP_RAM)
		long *tab = (long *)Mxalloc(NUM_BLOCKS_RAM * sizeof(long), 2);
		int i = -1, j;
		(void)Screalloc(BLOCK_STEP_RAM/2);
		/* try to get a screen above MIN_VIDEO_RAM */
		if(tab != NULL)
		{
			for(i = 0; i < NUM_BLOCKS_RAM; i++)
			{
				tab[i] = Mxalloc(BLOCK_STEP_RAM, 0); /* ST-RAM */
				if(!tab[i])
					break;
				if(tab[i] >= MIN_VIDEO_RAM)
					break;
			}
			if(!tab[i])
			{
				for(j = 0; j < i; j++)
				{
					if(tab[j])
						Mfree(tab[j]);
				}
				i = -1;
			}
		}
		addr = (long)Screalloc(width * height * (bpp >> 3));
		for(j = 0; j <= i; j++)
		{
			if(tab[j])
				Mfree(tab[j]);
		}
		if(!addr)
			addr = (long)Screalloc(width * height * (bpp >> 3));
		if(tab != NULL)
			Mfree(tab);
		if(!addr)
			return(0);
	}
	*((char **)_v_bas_ad) = (char *)addr;
	return(addr);
}
