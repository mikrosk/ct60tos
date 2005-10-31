/*
 *	radeon_mem.c
 *
 * based from Emutos / bdos
 * 
 * Copyright (c) 2001 Lineo, Inc.
 *
 * Authors: Karl T. Braun, Martin Doering, Laurent Vogel
 *
 * This file is distributed under the GPL, version 2 or at your
 * option any later version.
 */

#include <mint/errno.h> 
#include "fb.h"
#include "radeonfb.h"

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
	mpb = &pmd;
	for(p = *(q = &mpb->mp_mal); p; p = *(q = &p->m_link))
	{
		if(addr == p->m_start)
			break;
	}
	if(!p)
		return(EFAULT);
	*q = p->m_link;
	freeit(p,mpb);
	return(0);
}

long radeon_offscreen_alloc(struct radeonfb_info *rinfo, long amount)
{
	MD *m;
	if(amount == -1L)
		return((long)ffit(-1L,&pmd));
	if(amount <= 0 )
		return(0);
	if((amount & 1))
		amount++;
	m = ffit(amount,&pmd);
	if(m == NULL)
		return(0);
	return((long) m->m_start);
}

void radeon_offscreen_init(struct radeonfb_info *rinfo)
{
	struct fb_info *info = rinfo->info;
	pmd.mp_mfl = pmd.mp_rover = &tab_md[0];
	tab_md[0].m_link = (MD *)NULL;
	tab_md[0].m_start = (long)rinfo->fb_base + (long)info->screen_size;
	tab_md[0].m_length = (long)info->screen_size;	
	pmd.mp_mal = (MD *)NULL;
	count_md=1;
}
