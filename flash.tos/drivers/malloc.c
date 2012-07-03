/*
 *	malloc.c
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

#include <mint/osbind.h>
#include <mint/errno.h>
#include <string.h>
#include "../include/pci_bios.h"

#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE 1
#endif

#define USE_MXALLOC
#undef DRIVERS_MEM_DEBUG

#ifdef DRIVERS_MEM_DEBUG
extern void kprint(const char *fmt, ...);
extern short drive_ok;
//#define	DRIVERS_MEM_PRINTF(fmt,args...)	if(drive_ok) kprint(fmt ,##args)
#define	DRIVERS_MEM_PRINTF(fmt,args...)	kprint(fmt ,##args)
#else
#define DRIVERS_MEM_PRINTF(fmt,args...)
#endif

#ifdef USE_MXALLOC

int free(void *addr)
{
	DRIVERS_MEM_PRINTF("free(0x%08X)\r\n", addr);
	Mfree(addr);
	return(0);
}

void *malloc(long amount)
{
	void *ret = (void *)Mxalloc(amount, 3);
	DRIVERS_MEM_PRINTF("malloc(%d) = 0x%08X\r\n", amount, ret);
	return(ret);
}

#else /* !USE_MXALLOC */

extern char _bss_start[];
extern char _end[];

static void *drivers_buffer;
extern int asm_set_ipl(int level);

/* MD - Memory Descriptor */

#define MD struct _md_

MD
{
	MD *m_link;
	long m_start;
	long m_length;
  void *m_own;
};

/* MPB - Memory Partition Block */

#define MPB struct _mpb

MPB
{
	MD *mp_mfl;
	MD *mp_mal;
	MD *mp_rover;
};

#define MAXMD 256

static MD tab_md[MAXMD];
static MPB pmd;

static void *xmgetblk(void)
{
	int i;
	for(i = 0; i < MAXMD; i++)
	{
		if(tab_md[i].m_own == NULL)
		{
			tab_md[i].m_own = (void*)1L;
			return(&tab_md[i]);
		}
	}			   
	return(NULL);
}

static void xmfreblk(void *m)
{
	int i = (int)(((long)m - (long)tab_md) / sizeof(MD));
	if((i > 0) && (i < MAXMD))
		tab_md[i].m_own = NULL;
}

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
	maxflg = ((amount == -1) ? TRUE : FALSE) ;
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
				p1 = xmgetblk();
				if(p1 == NULL)
					return(NULL);
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
			xmfreblk(p);
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
			xmfreblk(m);
		}
	}
}

int free(void *addr)
{
	int level;
	MD *p, **q;
	MPB *mpb;
	mpb = &pmd;
	if(drivers_buffer == NULL)
		return(EFAULT);
	level = asm_set_ipl(7);
	for(p = *(q = &mpb->mp_mal); p; p = *(q = &p->m_link))
	{
		if((long)addr == p->m_start)
			break;
	}
	if(!p)
	{
		asm_set_ipl(level);
		return(EFAULT);
	}
	*q = p->m_link;
	freeit(p, mpb);
	asm_set_ipl(level);
	DRIVERS_MEM_PRINTF("free(0x%08X)\r\n", addr);
	return(0);
}

void *malloc(long amount)
{
	void *ret = NULL;
	int level;
	MD *m;
	if(drivers_buffer == NULL)
		return(NULL);
	if(amount == -1L)
		return((void *)ffit(-1L,&pmd));
	if(amount <= 0 )
		return(0);
	if((amount & 1))
		amount++;
	level = asm_set_ipl(7);
	m = ffit(amount, &pmd);
	if(m != NULL)
		ret = (void *)m->m_start;
	asm_set_ipl(level);
	DRIVERS_MEM_PRINTF("malloc(%d) = 0x%08X\r\n", amount, ret);
	return(ret);
}

#endif /* USE_MXALLOC */

void *realloc(void *ptr, int size)
{
	void *ret = malloc(size);
	if(ret != NULL)
	{
		memcpy(ret, ptr, size);
		free(ptr);
		DRIVERS_MEM_PRINTF("realloc(0x%08X, %d) = 0x%08X\r\n", ptr, size, ret);
		return ret;
	}
	free(ptr);
	DRIVERS_MEM_PRINTF("realloc(0x%08X, %d) = 0x00000000\r\n", ptr, size);
	return NULL;
}

int drivers_mem_init(void)
{
#ifndef USE_MXALLOC
	if(drivers_buffer != NULL)
		return(0);
	pmd.mp_mfl = pmd.mp_rover = &tab_md[0];
	tab_md[0].m_link = (MD *)NULL;
	drivers_buffer = (void *)(((long)_end + 15) & 0xFFFFFFF0); /* 16 bytes alignment */
	tab_md[0].m_start = (long)drivers_buffer;
	tab_md[0].m_length = PCI_DRIVERS_SIZE - ((long)drivers_buffer - (long)_bss_start);
	tab_md[0].m_own = (void *)1L;
	pmd.mp_mal = (MD *)NULL;
	memset(drivers_buffer, 0, tab_md[0].m_length);
#endif /* USE_MXALLOC */
	return(0);
}
