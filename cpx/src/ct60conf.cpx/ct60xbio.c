	
/* CT60 XBIOS - Pure C */
/* Didier MEQUIGNON - July 2003 */

#include <tos.h>
#include <stdio.h>
#include "ct60.h"

/* #define TEST */
/* #define TEST_MAGICMAC */

#define USA 0
#define FRG 1
#define FRA 2
#define UK 3
#define SPA 4
#define ITA 5
#define SWF 7
#define SWG 8

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

/* prototypes */

COOKIE *fcookie(void);
COOKIE *ncookie(COOKIE *p);
COOKIE *get_cookie(long id);
int add_cookie(COOKIE *cook);
extern void det_xbios(void);
extern void det_xbios_030(void);
extern void det_vdi(void);

int main(void)

{
	int start_lang;
	COOKIE cookie_ct60;
	COOKIE *p;
	if((p=get_cookie('_AKP'))!=0)
	{
		if((p->v.c[2]==FRA) || (p->v.c[2]==SWF))
			start_lang=0;
	}
	Cconws("\r\n\n");
	Cconout(27);
	Cconws("p XBIOS CT60 v0.99 ");
	Cconout(27);
	Cconws("q July 2003\r\n");
#ifdef TEST_MAGICMAC
    if(!get_cookie('MgMc'))
#endif
    {
		if(((p=get_cookie('_MCH'))==0) || (p->v.l!=0x30000)		/* Falcon */
#ifndef TEST
		 || ((p=get_cookie('_CPU'))==0) || (p->v.l!=0x3C)       /* 68060 */
#endif
		)
		{
			if(!start_lang)
				Cconws("Cette machine n'est pas un FALCON 030/CT60\r\n");
			else
				Cconws("This computer isn't a FALCON 030/CT60\r\n");
			*(((long *)(&det_xbios_030))-1L)=(long)Setexc(46,(void(*)())det_xbios_030);	/* TRAP #14 */
			Ptermres(32000,0);
		}
	}	
	if((p=get_cookie(ID_CT60))!=0)
	{
		if(!start_lang)
			Cconws("Le driver est d‚ja install‚\r\n");
		else
			Cconws("The driver is already installed\r\n");
	}	
	else
	{
		p=&cookie_ct60;
		p->ident=ID_CT60;
		p->v.l=0L;
		add_cookie(p);
		if(get_cookie('MagX')==0)
			*(((long *)(&det_vdi))-1L)=(long)Setexc(34,(void(*)())det_vdi);	/* TRAP #2 */
		*(((long *)(&det_xbios))-1L)=(long)Setexc(46,(void(*)())det_xbios);	/* TRAP #14 */
		Ptermres(32000,0);
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
