#include <tos.h>
#include <mt_aes.h>
#include <stdio.h>
#include <string.h>
#include "ct60.h"

#define Vsync() (long)xbios(0x25)
#define Vsetscreen(log,phy,rez,mode) (void)xbios((short)0x05,(long)(log),(long)(phy),(short)(rez),(short)(mode))
#define Vsetmode(mode) (int)xbios((short)0x58,(short)(mode))
#define Vgetsize(mode) (long)xbios(0x5B,mode)

#undef USE_VMALLOC
#undef USE_ALLOC_MEM
#define USE_SET_ADR

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

COOKIE *get_cookie(long id);

void test(void)
{
	COOKIE *p;
	long first = 0, second = 0, modecode = 0, version = 0x0100;
	long offset, bpp, x_second, y_second;
	SCREENINFO si;
#ifdef USE_ALLOC_MEM
#ifdef USE_VMALLOC
	long offscreen;
#else
	SCRMEMBLK blk;
#endif /* USE_VMALLOC */
	SCRCOPYMEMBLK copy;
#endif /* USE_ALLOC_MEM */
	SCRFILLMEMBLK fill;
	if(((p = get_cookie('_MCH')) == NULL) || (p->v.l != 0x30000))	/* Falcon */
	{
		printf("This computer isn't a FALCON\r\n");
		Cnecin();
		return;
	}
	if(((p=get_cookie('_CPU')) == NULL) || (p->v.l != 60))
	{
		printf("This computer isn't a CT60\r\n");
		Cnecin();
		return;
	}
	if((p=get_cookie('_PCI'))==0)
	{
		printf("CTPCI / PCI BIOS not found\r\n");
		Cnecin();
		return;
	}	
	if(((unsigned long)Physbase() < 0x01000000UL))
	{
		printf("Graphic card not found\r\n");
		Cnecin();
		return;
	}	
	Vsetscreen(-1,&modecode,'VN',CMD_GETMODE);
	if(modecode != (long)Vsetmode(-1))
	{
		printf("Bad XBIOS\r\n");
		Cnecin();
		return;
	}
	if((modecode & 7) == BPS32)
		Vsetscreen(-1, -1, 3, (short)((modecode & ~7) | (BPS32-1)));
	else
		Vsetscreen(-1, -1, 3, (short)((modecode & ~7) | BPS32));
	Vsetscreen(-1,&version,'VN',CMD_GETVERSION);
	printf("Video XBIOS version %04lX\r\n", version);
	first = (long)Physbase();
	si.size = sizeof(SCREENINFO); /* Structure size has to be set */
	si.devID = 0; /* current  mode */
	si.scrFlags=0; /* status of the operation */
	Vsetscreen(-1,&si,'VN',CMD_GETINFO);
	printf("Screen %ldx%ldx%ld %ld / %ld bytes\r\n", si.virtWidth, si.virtHeight, si.scrPlanes, si.pagemem, si.maxmem);
	printf("Offscreen %ld bytes free\r\n", ct60_vmalloc(0, -1L));
	printf("Modecode 0x%04lX => 0x%04X\r\n", modecode, Vsetmode(-1));
#ifdef USE_ALLOC_MEM
#ifdef USE_VMALLOC
	second = offscreen = ct60_vmalloc(0, Vgetsize(Vsetmode(-1)) + si.lineWrap);
	printf("1st screen at 0x%08lX, VMALLOC 2nd screen at 0x%08lX\r\n", first, second);
#else
	blk.size=sizeof(SCRMEMBLK);
	blk.blk_y=si.virtHeight+1; /* alloc a block like the 1st screen */
	Vsetscreen(-1,&blk,'VN',CMD_ALLOCMEM);
	second = blk.blk_start;
	printf("1st screen at 0x%08lX, ALLOCMEM 2nd screen at 0x%08lX\r\n", first, second);
#endif /* USE_VMALLOC */
	if(second)
	{
		long offset = second - first;
		offset += (si.lineWrap - 1);
		offset /= si.lineWrap;
		offset *= si.lineWrap; /* line alignment (else you need for CMD_SETADR a virtual screeen with virtWidth >= 2*scrWidth) */
		second = offset + first;
	}
#else /* ALLOC_PAGE */
	Vsetscreen(&second,Vsetmode(-1) & 0xFFFF,'VN',CMD_ALLOCPAGE);
	printf("1st screen at 0x%08lX, ALLOCPAGE 2nd screen at 0x%08lX\r\n", first, second);
#endif /* USE_ALLOC_MEM */
	if(!second)
	{
		printf("Cannot allocate second screen\r\n");
		Cnecin();
		Vsetscreen(-1, -1, 3, (short)Vsetmode(-1));
		return;
	}
	printf("Logbase at 0x%08lX, Physbase at 0x%08lX\r\n", Logbase(), Physbase());
    Cnecin();
#ifdef USE_ALLOC_MEM
#ifdef USE_VMALLOC
	offset = second - first;
	bpp = si.scrPlanes / 8;
	x_second = (offset % (si.virtWidth * bpp)) / bpp;
	y_second = offset / (si.virtWidth * bpp);
#else
	x_second = blk.blk_x; /* before version 0x0101 blk_x & blk_y are bad */ 
	y_second = blk.blk_y;
	printf("len: %ld, x: %ld, y: %ld, w: %ld, h: %ld, warp: %ld\r\n", blk.blk_len, blk.blk_x, blk.blk_y, blk.blk_w, blk.blk_h, blk.blk_wrap);
	if(x_second)
		y_second++; /* line alignment before */
#endif /* USE_VMALLOC */
	Vsetscreen(second,second,'VN',CMD_SETADR);
	printf("SETADR second screen at (%ld,%ld)\r\n", x_second, y_second);
#else /* ALLOC_PAGE */
	offset = second - first;
	bpp = si.scrPlanes / 8;
	x_second = (offset % (si.virtWidth * bpp)) / bpp;
	y_second = offset / (si.virtWidth * bpp);
#ifdef USE_SET_ADR
	Vsetscreen(second,second,'VN',CMD_SETADR);
	printf("SETADR second screen at (%ld,%ld)\r\n", x_second, y_second);
#else
	Vsetscreen(-1,-1,'VN',CMD_FLIPPAGE);
	printf("FLIPPAGE second screen at (%ld,%ld)\r\n", x_second, y_second);
#endif /* USE_SET_ADR */
#endif /* USE_ALLOC_MEM */
	printf("Logbase at 0x%08lX, Physbase at 0x%08lX\r\n", Logbase(), Physbase());
	if(version < 0x101)
	{
		memset((void *)second, -1, Vgetsize(Vsetmode(-1))); /* slow with CTPCI bridge */
#ifdef USE_ALLOC_MEM
 		memcpy((void *)second, (void *)first, Vgetsize(Vsetmode(-1)));
#else /* ALLOC_PAGE */
		Vsetscreen(-1,0,'VN',CMD_COPYPAGE);
#endif /* USE_ALLOC_MEM */
		printf("1st screen copied to second screen\r\n");
		memset((void *)second, 0, Vgetsize(Vsetmode(-1)));		
	}
	else /* there are XBIOS accel functions */
	{
		fill.size = sizeof(SCRFILLMEMBLK);
		fill.blk_status = 0;
		fill.blk_op = BLK_SET; /* mode operation */
		fill.blk_color = 0; /* background fill color */
		fill.blk_x = 0; /* x pos in total screen */
		fill.blk_y = y_second; /* y pos in total screen */
		fill.blk_w = si.virtWidth; /* width  */
		fill.blk_h = si.virtHeight; /* height */
		Vsetscreen(-1,&fill,'VN',CMD_FILLMEM);
#ifdef USE_ALLOC_MEM
		copy.size = sizeof(SCRCOPYMEMBLK);
		copy.blk_status = 0;
		copy.blk_op = BLK_COPY; /* mode operation */
		copy.blk_src_x = 0;
		copy.blk_src_y = 0;
		copy.blk_dst_x = 0;
		copy.blk_dst_y = y_second;
		copy.blk_w = si.virtWidth;
		copy.blk_h = si.virtHeight;
		Vsetscreen(-1,&copy,'VN',CMD_COPYMEM);
#else /* ALLOC_PAGE */
		Vsetscreen(-1,0,'VN',CMD_COPYPAGE);
#endif /* USE_ALLOC_MEM */
		fill.size = sizeof(SCRFILLMEMBLK);
		fill.blk_status = 0;
		fill.blk_op = BLK_XOR; /* mode operation */
		fill.blk_color = 0xFFFFFF; /* background fill color */
		fill.blk_x = 20; /* x pos in total screen */
		fill.blk_y = y_second+20; /* y pos in total screen */
		fill.blk_w = si.virtWidth-40; /* width  */
		fill.blk_h = si.virtHeight-40; /* height */
		Vsetscreen(-1,&fill,'VN',CMD_FILLMEM);
		Cnecin(); /* else you can't see nothing */
	}
	printf("Flip to 1st screen\r\n");
#ifdef USE_ALLOC_MEM
	Vsetscreen(first,first,'VN',CMD_SETADR);
#ifdef USE_VMALLOC
	ct60_vmalloc(1,offscreen); /* offscreen free */
#else
	Vsetscreen(-1,&blk,'VN',CMD_FREEMEM);
#endif /* SUE_VMALLOC */
#else /* ALLOC_PAGE */
#ifdef USE_SET_ADR
	Vsetscreen(first,first,'VN',CMD_SETADR);
#else
	Vsetscreen(-1,-1,'VN',CMD_FLIPPAGE); /* before version 0x0101 you need CMD_FLIPPAGE to 1st screen before CMD_FREEPAGE the 2nd screen */
#endif /* USE_SET_ADR */
	Vsetscreen(-1,-1,'VN',CMD_FREEPAGE);
#endif /* USE_ALLOC_MEM */
	Vsetscreen(-1, -1, 3, (short)modecode);
}

int main(void)
{
	GRECT r,rect;
	int gr_hwchar,gr_hhchar,gr_hwbox,gr_hhbox;
	if(appl_init()<=0)
		return(-1);		
	graf_handle(&gr_hwchar,&gr_hhchar,&gr_hwbox,&gr_hhbox);
	wind_update(BEG_UPDATE);
	wind_update(BEG_MCTRL);
	graf_mouse(M_OFF,(MFORM *)0);
	rect.g_x=rect.g_y=0;                /* screen size */
	wind_get(0,WF_WORKXYWH,&r.g_x,&r.g_y,&r.g_w,&r.g_h); /* desktop */
	rect.g_w=r.g_x+r.g_w-1;
	rect.g_h=r.g_y+r.g_h-1;
	form_dial(FMD_START,&rect,&rect);
	test();
	form_dial(FMD_FINISH,&rect,&rect);
	graf_mouse(M_ON,(MFORM *)0);
	graf_mouse(ARROW,(MFORM *)0);
	wind_update(END_MCTRL);
	wind_update(END_UPDATE);
	appl_exit();
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


