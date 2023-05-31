/*
 *	radeon_mem.c
 *
 * based from Emutos / BDOS
 * 
 * Copyright (c) 2001 Lineo, Inc.
 *
 * Authors: Karl T. Braun, Martin Doering, Laurent Vogel
 *
 * This file is distributed under the GPL, version 2 or at your
 * option any later version.
 */

#include <mint/errno.h> 
#include <sysvars.h>
#include "fb.h"
#include "radeonfb.h"

#undef DEBUG

/* MD - Memory Descriptor */

#define MD struct _md_

MD
{
	MD *m_link;
	long m_start;
	long m_length;
};

/* MPB - Memory Partition Block */

#define MPB struct _mpb

MPB
{
	MD *mp_mfl;
	MD *mp_mal;
	MD *mp_rover;
};

#define MAXMD 100

static int count_md;
static MD tab_md[MAXMD];
static MPB pmd;

static MD *ffit(long amount, MPB *mp)
{
	MD *p,*q,*p1;                    /* free list is composed of MD's */
	int maxflg;
	long maxval;
	if(amount != -1)
	{
		amount += 15;                  /* 16 bytes alignment */
		amount &= 0xFFFFFFF0;
	}
	if((q = mp->mp_rover) == 0)      /* get rotating pointer */
		return(0) ;
	maxval = 0;
	maxflg = (amount == -1 ? TRUE : FALSE) ;
	p = q->m_link;                   /* start with next MD */
	do /* search the list for an MD with enough space */
	{
		if(p == 0)
		{
			/*  at end of list, wrap back to start  */
			q = (MD *) &mp->mp_mfl;      /*  q => mfl field  */
			p = q->m_link;               /*  p => 1st MD     */
		}
		if((!maxflg) && (p->m_length >= amount))
		{
			/*  big enough */
			if(p->m_length == amount)
				q->m_link = p->m_link;     /* take the whole thing */
			else
			{
				/* break it up - 1st allocate a new
				   MD to describe the remainder */
				if(count_md >= MAXMD)
					return(0);
				p1 = &tab_md[count_md++];
				/* init new MD */
				p1->m_length = p->m_length - amount;
				p1->m_start = p->m_start + amount;
				p1->m_link = p->m_link;
				p->m_length = amount;      /* adjust allocated block */
				q->m_link = p1;
			}
			/* link allocate block into allocated list,
			    mark owner of block, & adjust rover  */
			p->m_link = mp->mp_mal;
			mp->mp_mal = p;
			mp->mp_rover = (q == (MD *) &mp->mp_mfl ? q->m_link : q);
			return(p);                   /* got some */
		}
		else if(p->m_length > maxval)
			maxval = p->m_length;
		p = ( q=p )->m_link;
	}
	while(q != mp->mp_rover);
	/*  return either the max, or 0 (error)  */
	if(maxflg)
	{
		maxval -= 15; /* 16 bytes alignment */
		if(maxval < 0)
			maxval = 0;
		else
			maxval &= 0xFFFFFFF0;
	}
	return(maxflg ? (MD *) maxval : 0);
}

static void freeit(MD *m, MPB *mp)
{
	MD *p, *q;
	q = 0;
	for(p = mp->mp_mfl; p ; p = (q=p) -> m_link)
	{
		if(m->m_start <= p->m_start)
			break;
	}
	m->m_link = p;
	if(q)
		q->m_link = m;
	else
		mp->mp_mfl = m;
	if(!mp->mp_rover)
		mp->mp_rover = m;
	if(p)
	{
		if(m->m_start + m->m_length == p->m_start)
		{ /* join to higher neighbor */
			m->m_length += p->m_length;
			m->m_link = p->m_link;
			if(p == mp->mp_rover)
				mp->mp_rover = m;
			if(count_md>=0)
				count_md--;
		}
	}
	if(q)
	{
		if(q->m_start + q->m_length == m->m_start)
		{ /* join to lower neighbor */
			q->m_length += m->m_length;
			q->m_link = m->m_link;
			if(m == mp->mp_rover)
				mp->mp_rover = q;
			if(count_md>=0)
				count_md--;
		}
	}
}

long radeon_offscreen_free(struct radeonfb_info *rinfo, long addr)
{
	MD *p,**q;
	MPB *mpb;
#ifdef DEBUG
	char buf[10];
	Funcs_puts("radeon_offscreen_free(0x");
	Funcs_ltoa(buf, addr, 16);
	Funcs_puts(buf);
	Funcs_puts("\r\n");
#endif
	*vblsem = 0;
	mpb = &pmd;
	for(p = *(q = &mpb->mp_mal); p; p = *(q = &p->m_link))
	{
		if(addr == p->m_start)
			break;
	}
	if(!p)
	{
		*vblsem = 1;
		return(EFAULT);
	}
	*q = p->m_link;
	freeit(p,mpb);
	*vblsem = 1;
	return(0);
}

long radeon_offscreen_alloc(struct radeonfb_info *rinfo, long amount)
{
	long ret;
	MD *m;
	struct fb_info *info;
#ifdef DEBUG
	char buf[10];
	Funcs_puts("radeon_offscreen_alloc(0x");
	Funcs_ltoa(buf, amount, 16);
	Funcs_puts(buf);
	Funcs_puts(") = 0x");
#endif
	*vblsem = 0;
	if(amount == -1L)
	{
		ret = (long)ffit(-1L,&pmd);
		*vblsem = 1;
		return(ret);
	}
	if(amount <= 0 )
	{
		*vblsem = 1;
		return(0);
	}
	if((amount & 1))
		amount++;
	m = ffit(amount,&pmd);
	if(m == NULL)
	{
#ifdef DEBUG
		Funcs_puts("0\r\n");
#endif
		*vblsem = 1;
		return(0);
	}
	info = rinfo->info;
	/* test offscreen limits for current screen */
	if((unsigned long)m->m_start - (unsigned long)info->screen_base + (unsigned long)amount
	 > (unsigned long)info->var.xres_virtual * 8192UL * (unsigned long)(info->var.bits_per_pixel / 8))
	{
		radeon_offscreen_free(rinfo,(long)m->m_start);
		*vblsem = 1;
		return(0);
	}	
#ifdef DEBUG
	Funcs_ltoa(buf, m->m_start, 16);
	Funcs_puts(buf);
	Funcs_puts("\r\n");
#endif
	ret = (long)m->m_start;
	*vblsem = 1;
	return(ret);
}

void radeon_offscreen_init(struct radeonfb_info *rinfo)
{
	struct fb_info *info = rinfo->info;
	long size_screen = (long)info->var.xres_virtual*(long)info->var.yres_virtual*(long)(info->var.bits_per_pixel/8);
	if(!size_screen)
		size_screen = (long)info->screen_size;
	pmd.mp_mfl = pmd.mp_rover = &tab_md[0];
	tab_md[0].m_link = (MD *)NULL;
	tab_md[0].m_start = (long)((unsigned long)rinfo->fb_base + (unsigned long)size_screen);
	tab_md[0].m_length = (long)rinfo->mapped_vram-size_screen;	
	pmd.mp_mal = (MD *)NULL;
	count_md=1;
}

