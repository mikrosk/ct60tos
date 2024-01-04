/* time / delay functions for the CT60/CTPCI & Coldfire boards
 * Didier Mequignon 2005-2012, e-mail: aniplay@wanadoo.fr
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
#include "../include/fire.h"

typedef struct
{
	long xbra;
	long ident;
	long old_address;
	short caller[13];
} XBRA;

static long time_out;


long get_timer(void) /* try to get a precise timer on F030 */
{
	register long retvalue __asm__("d0");
	asm volatile (
		"move.w SR,-(SP)\n\t"
		"or.w #0x700,SR\n\t"       /* no interrupts	*/
		"move.l 0x4BA,D0\n\t"      /* _hz_200 */
		"asl.l #8,D0\n\t"
		"moveq #0,D1\n\t"
		"move.b 0xFFFFFA23,D1\n\t" /* TCDR timer C MFP */
		"subq.b #1,D1\n\t"         /* 0-191 */
		"asl.l #8,D1\n\t"	         /* *256  */
		"divu #192,D1\n\t"         /* 0-255 */
		"not.b D1\n\t"
		"move.b D1,D0\n\t"
		"move.w (SP)+,SR\n\t"	: "=r"(retvalue) : : "d1", "cc" );
	return(retvalue);	
}

void start_timeout(void)
{
	time_out = get_timer();
}

int end_timeout(long msec)
{
	msec <<= 8;
	msec /= 5;
	return(((get_timer() - time_out) < msec) ? 0 : 1);
}

void udelay(long usec)
{
	unsigned char tcdr;
	while(usec > 0)
	{
		tcdr = *((volatile unsigned char *)0xFFFFFA23);
		while(*((volatile unsigned char *)0xFFFFFA23) == tcdr); /* 26 uS timer C MFP */
		usec -= 26;
	}
}

void mdelay(long msec)
{
	long val = get_timer();
	msec <<= 8;
	msec /= 5;
	while((get_timer() - val) < msec);
}


static long vbl_stack[512];
static long save_stack;

void install_vbl_timer(void *func, int remove)
{
	XBRA *xbra;
	int i = (int)*nvbls;
	void (**func_vbl)(void);
	func_vbl = *_vblqueue;
	func_vbl += 2; /* 2 first vectors are used by the VDI cursors mouse and text */
	i-=2;
	while(--i >= 0)
	{
		if(remove && (*func_vbl != NULL))
		{
			xbra = (XBRA *)((long)*func_vbl - 12);
			if((xbra->xbra == 'XBRA') && (xbra->ident == '_PCI')
			 && (xbra->caller[0] == 0x23CF) && (*(long *)&xbra->caller[7] == (long)func))
			{
				Funcs_free(xbra);
			*func_vbl = NULL;		/* remove old vector */
			}
		}
		if(*func_vbl == NULL)
		{
				xbra = (XBRA *)Funcs_malloc(sizeof(XBRA),3);
			if(xbra != NULL)
			{
				xbra->xbra = 'XBRA';
				xbra->ident = '_PCI';
				xbra->caller[0] = 0x23CF; /* move.l SP,xxxx */
				*(long *)&xbra->caller[1] = (long)&save_stack;
				xbra->caller[3] = 0x4FF9; /* lea xxxx,SP */
				*(long *)&xbra->caller[4] = (long)&vbl_stack[512];
				xbra->caller[6] = 0x4EB9; /* jsr xxxx */
				*(long *)&xbra->caller[7] = (long)func;
				xbra->caller[9] = 0x2E79; /* move.l xxxx,SP */
				*(long *)&xbra->caller[10] = (long)&save_stack;
				xbra->caller[12] = 0x4E75; /* rts */
				asm volatile (" cpusha BC\n\t");
				*func_vbl = (void(*)())&xbra->caller[0];
				xbra->old_address = 0;
			}
			break;
		}
		func_vbl++;
	}	
}

void uninstall_vbl_timer(void *func)
{
	XBRA *xbra;
	int i = (int)*nvbls;
	void (**func_vbl)(void);
	func_vbl = *_vblqueue;
	while(--i > 0)
	{
		if(*func_vbl != NULL)
		{
			xbra = (XBRA *)((long)*func_vbl - 12);
			if((xbra->xbra == 'XBRA') && (xbra->ident == '_PCI')
			 && (xbra->caller[0] == 0x23CF) && (*(long *)&xbra->caller[7] == (long)func))
			{
				Funcs_free(xbra);
				*func_vbl = NULL;		/* remove old vector */	
				break;
			}
		}
		func_vbl++;
	}
}


