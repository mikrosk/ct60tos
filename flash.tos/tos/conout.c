#include <string.h>

#define v_bas_ad  (*(volatile unsigned long *)0x44E)
#define LINEA_VARS 0x3E86 /* TOS404 */
#define LA_OFFSET 910
#define M_CSTATE 2
#define	V_CELL      0 /* VT52 cell output routines */
#define	V_SCRUP     1 /* VT52 screen up routine */
#define	V_SCRDN     2 /* VT52 screen down routine	*/
#define	V_BLANK     3 /* VT52 screen blank routine */
#define	V_BLAST     4 /* blit routines */
#define	V_MONO      5 /* monospace font blit routines */
#define	V_RECT      6 /* rectangle draw routines */
#define	V_VLINE     7 /* vertical line draw routines */
#define	V_HLINE     8 /* horizontal line draw routines */
#define	V_TEXT      9 /* text blit routines */
#define	V_VQCOLOR  10 /* color inquire routines */
#define	V_VSCOLOR  11 /* color set routines */
#define V_INIT     12 /* init routine called upon openwk */
#define V_SHOWCUR  13 /* display cursor */
#define V_HIDECUR	 14 /* replace cursor with old background */
#define V_NEGCELL  15 /* negate alpha cursor */
#define V_MOVEACUR 16 /* move alpha cur to new X,Y (D0, D1) */
#define V_ABLINE   17 /* arbitrary line routine	*/
#define V_HABLINE  18 /* horizontal line routine setup */
#define V_RECTFILL 19 /* routine to do rectangle fill	*/
#define	V_PUTPIX   20 /* output pixel value to the screen	*/
#define V_GETPIX   21 /* get pixel value at (X,Y) of screen */
#define V_ROUTS    22 /* (routine array size) */

typedef struct vdiVars
{
  short _angle;
  short begAng;
  void *curFont;    /* pointer to current font       */
  short delAng;
  short deltaY;
  short deltaY1;
  short deltaY2;
  short endAng;
  short filIntersect;
  short fillMaxY;
  short fillMinY;
  short nSteps;
  short oDeltaY;
  short sBegstY;
  short sEndstY;
  short sFilCol;
  short sFillPer;
  short sPatMsk;
  short *sPatPtr;
  short _start;
  short xC;
  short xRad;
  short y;
  short yC;
  short yRad;
  short mPosHx;      /* Mouse hot spot - x coord      */
  short mPosHy;      /* Mouse hot spot - y coord      */
  short mPlanes;     /* Ms planes (reserved, but we used it) */
  short mCdbBg;      /* Mouse background color as pel value  */
  short mCdbFg;      /* Mouse foreground color as pel value  */
  short maskForm[32];    /* Storage for ms cursor mask and form  */
  short inqTab[45];  /* info returned by vq_extnd VDI call   */
  short devTab[45];  /* info returned by v_opnwk VDI call    */
  short gCurX;       /* current mouse cursor X position      */
  short gCurY;       /* current mouse cursor Y position      */
  short hideCnt;     /* depth at which the ms is hidden      */
  short mouseBt;     /* current mouse button status   */
  short reqCol[16][3];   /* internal data for vq_color    */
  short sizTab[15];  /* size in device coordinates    */
  short termCh;      /* 16 bit character info  */
  short chcMode;     /* the mode of the Choice device */
  void *curWork;     /* pointer to current works attributes  */
  void *defFont;     /* pointer to default font head  */
  void *fontRing[4];     /* ptrs to link list of fnt hdrs */
  short iniFontCount;    /* # of fonts in the FONT_RING lists    */
  short lineCW;      /* current line width     */
  short locMode;     /* the mode of the Locator device       */
  short numQCLines;  /* # of line in the quarter circle      */
  long trap14Sav;    /* space to save the return address     */
  long colOrMask;    /* some modes this is ored in VS_COLOR  */
  long colAndMask;   /* some modes this is anded in VS_COLOR */
  long trap14BSav;   /* space to sav ret adr (for reentrency)*/
  short  reserved0[32];  /* reserved            */
  short strMode;     /* the mode of the String device */
  short valMode;     /* the mode of the Valuator device      */
  char curMsStat;    /* Current mouse status   */
  char reserved1;    /* reserved        */
  short disabCnt;    /* hide depth of alpha cursor    */
  short xyDraw[2];   /* x,y communication block.      */
  char drawFlag;     /* Non-zero means draw ms frm on vblank */
  char mouseFlag;    /* Non-zero if mouse ints disabled      */
  long trap1Sav;     /* space to save return address  */
  short savCXY[2];   /* save area for cursor cell coords.    */
  short saveLen;     /* height of saved form   */
  short *saveAddr;   /* screen addr of 1st short of plane 0   */
  short saveStat;    /* cursor save status     */
  long saveArea[64];   /* save up to 4 planes. 16 longs/plane  */
  short (*timAddr)();  /* ptr to user installed routine */
  short (*timChain)(); /* jmps here when done with above       */
  short (*userBut)();  /* user button vector     */
  short (*userCur)();  /* user cursor vector     */
  short (*userMot)();  /* user motion vector     */
  short vCelHt;      /* height of character cell      */
  short vCelMx;      /* maximum horizontal cell index */
  short vCelMy;      /* maximum vertical cell index   */
  short vCelWr;      /* screen width (bytes) * cel_ht */
  short vColBg;      /* character cell text background color */
  short vColFg;      /* character cell text foreground color */
  short *vCurAd;     /* cursor address         */
  short vCurOff;     /* byte offset to cur from screen base  */
  short vCurCx;      /* cursor cell X position        */
  short vCurCy;      /* cursor cell Y position        */
  char vCTInit;      /* vCurTim reload value.  */
  char vCurTim;      /* cursor blink rate (# of vblanks)     */
  short *vFntAd;     /* address of monospaced font data      */
  short vFntNd;      /* last ASCII code in font       */
  short vFntSt;      /* first ASCII code in font      */
  short vFntWr;      /* width of font form in bytes   */
  short vHzRez;      /* horizontal pixel resolution   */
  short *vOffAd;     /* address of font offset table  */
  char vStat0;       /* cursor display mode (look above)     */
  char vDelay;       /* cursor redisplay period       */
  short vVtRez;      /* vertical resolution of the screen    */
  short bytesLin;    /* copy of vLinWr for concat     */
  short vPlanes;     /* number of video planes        */
  short vLinWr;      /* number of bytes/video line    */
  short *contrl;     /* ptr to the CONTRL array       */
  short *intin;      /* ptr to the INTIN array        */
  short *ptsin;      /* ptr to the PTSIN array        */
  short *intout;     /* ptr to the INTOUT array       */
  short *ptsout;     /* ptr to the PTSOUT array       */
  short fgBp1;       /* foreground bit plane #1 value */
  short fgBp2;       /* foreground bit plane #2 value */
  short fgBp3;       /* foreground bit plane #3 value */
  short fgBp4;       /* foreground bit plane #4 value */
  short lstLin;      /* 0 => not last line of polyline       */
  short lnMask;      /* line style mask.       */
  short wrtMode;     /* writing mode.   */
  short x1;          /* X1 coordinate   */
  short y1;          /* Y1 coordinate   */
  short x2;          /* X2 coordinate   */
  short y2;          /* Y2 coordinate   */
  short *patPtr;     /* ptr to pattern.        */
  short patMsk;      /* pattern index. (mask)  */
  short multiFill;   /* multiplane fill flag. (0 => 1 plane) */
  short clip;        /* clipping flag.         */
  short xMnClip;     /* x minimum clipping value.     */
  short yMnClip;     /* y minimum clipping value.     */
  short xMxClip;     /* x maximum clipping value.     */
  short yMxClip;     /* y maximum clipping value.     */
  short xAccDda;     /* accumulator for x DDA  */
  short ddaInc;      /* the fraction to be added to the DDA  */
  short tSclsts;     /* scale up or down flag.        */
  short monoStatus;  /* non-zero - cur font is monospaced    */
  short sourceX;     /* X coord of character in font  */
  short sourceY;     /* Y coord of character in font  */
  short destX;       /* X coord of character on screen       */
  short destY;       /* X coord of character on screen       */
  short delX;        /* width of character     */
  short delY;        /* height of character    */
  short *fBase;      /* pointer to font data   */
  short fWidth;      /* offset,segment and form with of font */
  short style;       /* special effects        */
  short liteMask;    /* special effects        */
  short skewMask;    /* special effects        */
  short weight;      /* special effects        */
  short rOff;        /* Skew offset above baseline    */
  short lOff;        /* Skew offset below baseline    */
  short scale;       /* replicate pixels       */
  short chUp;        /* character rotation vector     */
  short textFg;      /* text foreground color  */
  short *scrtchP;    /* pointer to base of scratch buffer    */
  short scrPt2;      /* large buffer base offset      */
  short textBg;      /* text background color  */
  short copyTran;    /* cp rstr frm type flag (opaque/trans) */
  short (*quitFill)();    /* ptr to routine for quitting seedfill */
  short (*UserDevInit)(); /* ptr to user routine before dev_init  */
  short (*UserEscInit)(); /* ptr to user routine before esc_init  */
  long reserved2[8];      /* reserved            */
  short (**routines)();   /* ptr to primitives vector list      */
  void *curDev;      /* ptr to a surrent device structure    */
  short bltMode;     /* 0: soft BiT BLiT 1: hard BiT BLiT    */
  short reserved3;   /* reserved            */
  short reqXCol[240][3];    /* extended request color array  */
  short *svBlkPtr;   /* points to the proper save block      */
  long  fgBPlanes;   /* fg bit plns flags (bit 0 is plane 0) */
  short fgBP5;       /* foreground bitPlane #5 value. */
  short fgBP6;       /* foreground bitPlane #6 value. */
  short fgBP7;       /* foreground bitPlane #7 value. */
  short fgBP8;       /* foreground bitPlane #8 value. */
  short _saveLen;    /* height of saved form   */
  short *_saveAddr;  /* screen addr of 1st short of plane 0   */
  short _saveStat;   /* cursor save status     */
  long  _saveArea[256];     /* save up to 8 planes. 16 longs/plane  */
  short  qCircle[80];      /* space to build circle coordinates    */
  short  bytPerPix;   /* number of bytes per pixel (0 if < 1) */
  short  formId;      /* scrn form 2 ST, 1 stndrd, 3 pix      */
  long  vlColBg;      /* escape background color (long value) */
  long  vlColFg;      /* escape foreground color (long value) */
  long  palMap[256];      /* either a maping of reg's or true val */
  short  (*primitives[40])();  /* space to copy vectors into      */
} VDIVARS;

extern void sb_blank_internal(short x1, short y1, short x2, short y2);
extern int test_accel(void);


void *cell_addr(short x, short y) /* Atari planes */
{
  VDIVARS *la = (VDIVARS*)(LINEA_VARS - LA_OFFSET);
  return((void*)v_bas_ad + ((unsigned long)la->vLinWr * (unsigned long)la->vCelHt * (unsigned long)y) + ((unsigned long)la->vPlanes * ((unsigned long)x & ~1)) + ((unsigned long)x & 1) + (unsigned long)la->vCurOff);  
}

void *cell_addr2(short x, short y) /* no planes */
{
  VDIVARS *la = (VDIVARS*)(LINEA_VARS - LA_OFFSET);
  return((void*)v_bas_ad + ((unsigned long)la->vLinWr * (unsigned long)la->vCelHt * (unsigned long)y) + ((unsigned long)la->vPlanes * (unsigned long)x) + (unsigned long)la->vCurOff);
}

void sb_cell_c(unsigned char *src, unsigned char *dst, long fg, long bg)
{ 
  VDIVARS *la = (VDIVARS*)(LINEA_VARS - LA_OFFSET);
  short plane;
  short fnt_wr = la->vFntWr;
  short line_wr = la->vLinWr;
  unsigned char *src_sav = src;
  unsigned char *dst_sav = dst;
  if((test_accel() && (la->vPlanes >= 8)) || (la->vPlanes >= 16))
  {
    short y;
    switch(la->vPlanes)
    {
      case 8:
        for(y = la->vCelHt; y--;)
        {
          dst = dst_sav; /* reload dst */
          *dst++ = (*src_sav & 128) ? fg : bg;
          *dst++ = (*src_sav & 64) ? fg : bg;
          *dst++ = (*src_sav & 32) ? fg : bg;
          *dst++ = (*src_sav & 16) ? fg : bg;
          *dst++ = (*src_sav & 8) ? fg : bg;
          *dst++ = (*src_sav & 4) ? fg : bg;
          *dst++ = (*src_sav & 2) ? fg : bg;
          *dst++ = (*src_sav & 1) ? fg : bg;
          dst_sav += line_wr;	/* top of block in next plane */
          src_sav += fnt_wr;
        }
        break;
      case 16:
        for(y = la->vCelHt; y--;)
        {
          short *dst = (short *)dst_sav; /* reload dst */
          *dst++ = (*src_sav & 128) ? fg : bg;
          *dst++ = (*src_sav & 64) ? fg : bg;
          *dst++ = (*src_sav & 32) ? fg : bg;
          *dst++ = (*src_sav & 16) ? fg : bg;
          *dst++ = (*src_sav & 8) ? fg : bg;
          *dst++ = (*src_sav & 4) ? fg : bg;
          *dst++ = (*src_sav & 2) ? fg : bg;
          *dst++ = (*src_sav & 1) ? fg : bg;
          dst_sav += line_wr;	/* top of block in next plane */
          src_sav += fnt_wr;
        }
        break;
      case 32:
        for(y = la->vCelHt; y--;)
        {
          long *dst = (long *)dst_sav; /* reload dst */
          *dst++ = (*src_sav & 128) ? fg : bg;
          *dst++ = (*src_sav & 64) ? fg : bg;
          *dst++ = (*src_sav & 32) ? fg : bg;
          *dst++ = (*src_sav & 16) ? fg : bg;
          *dst++ = (*src_sav & 8) ? fg : bg;
          *dst++ = (*src_sav & 4) ? fg : bg;
          *dst++ = (*src_sav & 2) ? fg : bg;
          *dst++ = (*src_sav & 1) ? fg : bg;
          dst_sav += line_wr;	/* top of block in next plane */
          src_sav += fnt_wr;
        }
        break;
    }
  }
  else /* Atari planes */
  {
    for(plane = la->vPlanes; plane--;)
    {
      short i;
      src = src_sav;    /* reload src */
      dst = dst_sav;    /* reload dst */
      if(bg & 1)
      {
        if(fg & 1)
        {
          /* back:1  fore:1  =>  all ones */
          for (i = la->vCelHt; i--; )
          {
           *dst = 0xff;  /* inject a block */
            dst += line_wr;
          }
        }
        else
        {
          /* back:1  fore:0  =>  invert block */
          for(i = la->vCelHt; i--;)
          {
            /* inject the inverted source block */
            *dst = ~*src;
            dst += line_wr;
            src += fnt_wr;
          }
        }
      }
      else
      {
        if(fg & 1)
        {
          /* back:0  fore:1  =>  direct substitution */
          for(i = la->vCelHt; i--;)
          {
            *dst = *src;
            dst += line_wr;
            src += fnt_wr;
          }
        }
        else
        {
          /* back:0  fore:0  =>  all zeros */
          for(i = la->vCelHt; i--;)
          {
            *dst = 0x00;  /* inject a block */
            dst += line_wr;
          }
        }
      }  
      bg >>= 1;         /* next background color bit */
      fg >>= 1;         /* next foreground color bit */
      dst_sav += 2;     /* top of block in next plane */
    }
  }
}

/*
 * scroll_up - Scroll upwards
 *
 *
 * Scroll copies a source region as wide as the screen to an overlapping
 * destination region on a one cell-height offset basis.  Two entry points
 * are provided:  Partial-lower scroll-up, partial-lower scroll-down.
 * Partial-lower screen operations require the cell y # indicating the
 * top line where scrolling will take place.
 *
 * After the copy is performed, any non-overlapping area of the previous
 * source region is "erased" by calling blank_out which fills the area
 * with the background color.
 *
 * in:
 *   top_line - cell y of cell line to be used as top line in scroll
 */
void sb_scrup_c(short top_line)
{
  VDIVARS *la = (VDIVARS*)(LINEA_VARS - LA_OFFSET);
  /* screen base addr + cell y nbr * cell wrap */
  unsigned char *dst = (unsigned char*)v_bas_ad + ((unsigned long)top_line * (unsigned long)la->vLinWr * (unsigned long)la->vCelHt);
  /* form source address from cell wrap + base address */
  unsigned char *src = dst + ((unsigned long)la->vLinWr * (unsigned long)la->vCelHt);
  /* form # of bytes to move */
  unsigned long count = ((unsigned long)la->vLinWr * (unsigned long)la->vCelHt) * ((unsigned long)la->vCelMy - (unsigned long)top_line);
  /* move BYTEs of memory*/
  memmove(dst, src, count);
  /* exit thru blank out, bottom line cell address y to top/left cell */
  sb_blank_internal(0, la->vCelMy, la->vCelMx, la->vCelMy);
}

/*
 * scroll_down - Scroll (partitially) downwards
 */
void sb_scrdn_c(short start_line)
{
  VDIVARS *la = (VDIVARS*)(LINEA_VARS - LA_OFFSET);
  /* screen base addr + offset for bottom of second to last cell row */
  unsigned char *src = (unsigned char*)v_bas_ad + ((unsigned long)start_line * (unsigned long)la->vLinWr * (unsigned long)la->vCelHt);
  /* form destination from source + cell wrap */
  unsigned char *dst = src + ((unsigned long)la->vLinWr * (unsigned long)la->vCelHt);
  /* form # of bytes to move */
  unsigned long count = (unsigned long)la->vLinWr * (unsigned long)la->vCelHt * ((unsigned long)la->vCelMy - (unsigned long)start_line);
  /* move BYTEs of memory*/
  memmove(dst, src, count);
  /* exit thru blank out */
  sb_blank_internal(0, start_line, la->vCelMx, start_line);
}

/*
 * blank_out - Fills region with the background color.
 *
 * Fills a cell-word aligned region with the background color.
 *
 * The rectangular region is specified by a top/left cell x,y and a
 * bottom/right cell x,y, inclusive.  Routine assumes top/left x is
 * even and bottom/right x is odd for cell-word alignment. This is,
 * because this routine is heavily optimized for speed, by always
 * blanking as much space as possible in one rush.
 *
 * in:
 *   topx - top/left cell x position (must be even)
 *   topy - top/left cell y position
 *   botx - bottom/right cell x position (must be odd)
 *   boty - bottom/right cell y position
 */

void sb_blank_c(short topx, short topy, short botx, short boty)
{
  VDIVARS *la = (VDIVARS*)(LINEA_VARS - LA_OFFSET);
  short row, rows, offs;
  /* d2 = # of lines in region - 1 */
  rows = (boty - topy + 1) * la->vCelHt;
  if((test_accel() && (la->vPlanes >= 8)) || (la->vPlanes >= 16))
  {
    unsigned long *addr; /* running pointer to screen */
    unsigned long c;
    short cell;
    /* # of cell per row in region -1 */
    short cells = (botx - topx);      /* # of characters */
    /* calculate the BYTE offset from the end of one row to next start */
    offs = la->vLinWr - cells * la->vPlanes;
    switch(la->vPlanes)
    {
      case 8:
        c = ((unsigned long)la->vColBg & 0xFF) + (((unsigned long)la->vColBg & 0xFF) << 8);
        c |= (c << 16);
        offs >>= 2;     /* from BYTE to LONG offset */
        addr = (unsigned long *)cell_addr2(topx, topy);       /* start address */
        /* do all rows in region */
        for(row = rows; row--;)
        {
          for(cell = cells; cell--;)
          {
            *addr++ = c;
            *addr++ = c;
          }
          addr += offs;         /* skip non-region area with stride advance */
        }
        break;
      case 16:
        c = ((unsigned long)la->vlColBg & 0xFFFF) + ((unsigned long)la->vlColBg << 16);
        offs >>= 2;     /* from BYTE to LONG offset */
        addr = (unsigned long *)cell_addr2(topx, topy);       /* start address */
        /* do all rows in region */
        for(row = rows; row--;)
        {
          for(cell = cells; cell--;)
          {
            *addr++ = c;
            *addr++ = c;
            *addr++ = c;
            *addr++ = c;
          }
          addr += offs;         /* skip non-region area with stride advance */
        }
        break;
      case 32:
        c = (unsigned long)la->vlColBg;
        offs >>= 2;     /* from BYTE to LONG offset */
        addr = (unsigned long *)cell_addr2(topx, topy);       /* start address */
        /* do all rows in region */
        for(row = rows; row--;)
        {
          for(cell = cells; cell--;)
          {
            *addr++ = c;
            *addr++ = c;
            *addr++ = c;
            *addr++ = c;
            *addr++ = c;
            *addr++ = c;
            *addr++ = c;
            *addr++ = c;
          }
          addr += offs;         /* skip non-region area with stride advance */
        }
        break;
    }
  }
  else /* Atari planes */
  {
    short pair;
    long pl01 = 0x00000000;      /* bits on screen for planes 0 + 1 */
    long pl23 = 0x00000000;      /* bits on screen for planes 2 + 3 */
    long pl45 = 0x00000000;      /* bits on screen for planes 4 + 5 */
    long pl67 = 0x00000000;      /* bits on screen for planes 6 + 7 */
    unsigned short color = la->vColBg;    /* background color to d5 */
    /* # of cell-pairs per row in region -1 */
    short pairs = (botx - topx) / 2 + 1;      /* pairs of characters */
    /* calculate the BYTE offset from the end of one row to next start */
    offs = la->vLinWr - pairs * 2 * la->vPlanes;
    /* test for 1, 2 or 4 planes */
    switch(la->vPlanes)
    {
      case 8:
        {
          /* 8 planes */
          unsigned long *addr; /* running pointer to screen */
          /* set the high WORD of our LONG for plane 0 + 1 */
          if(color & 1)
            pl01 = 0xffff0000;
          /* set the low WORD of our LONG for plane 0 + 1 */
          color = color >> 1;  /* get next bit */
          if(color & 1)
            pl01 |= 0x0000ffff;
          /* set the high WORD of our LONG for plane 2 + 3 */
          color = color >> 1;  /* get next bit */
          if(color & 1)
            pl23 = 0xffff0000;
          /* set the low WORD of our LONG for plane 2 + 3 */
          color = color >> 1;  /* get next bit */
          if(color & 1)
            pl23 |= 0x0000ffff;
          /* set the high WORD of our LONG for plane 4 + 5 */
          color = color >> 1;  /* get next bit */
          if(color & 1)
            pl45 = 0xffff0000;
          /* set the low WORD of our LONG for plane 4 + 5 */
          color = color >> 1;  /* get next bit */
          if(color & 1)
            pl45 |= 0x0000ffff;
          /* set the high WORD of our LONG for plane 6 + 7 */
          color = color >> 1;  /* get next bit */
          if(color & 1)
          pl67 = 0xffff0000;
          /* set the low WORD of our LONG for plane 6 + 7 */
          color = color >> 1;  /* get next bit */
          if(color & 1)
            pl67 |= 0x0000ffff;
          offs >>= 2;     /* from BYTE to LONG offset */
          addr = (unsigned long *)cell_addr(topx, topy); /* start address */  
          /* do all rows in region */
          for(row = rows; row--;)
          {
            /* loop through all cell pairs (LONG) */
            for(pair = pairs; pair--;)
            {
              *addr++ = pl01;     /* fill background to planes 0 & 1 */
              *addr++ = pl23;     /* fill background to planes 2 & 3 */
              *addr++ = pl45;     /* fill background to planes 4 & 5 */
              *addr++ = pl67;     /* fill background to planes 6 & 7 */
            }
            addr += offs;         /* skip non-region area with stride advance */
          }
        }
        break;
      case 4:
        {
          /* 4 planes */
          unsigned long *addr;     /* running pointer to screen */
          /* set the high WORD of our LONG for plane 0 + 1 */
          if(color & 0x1)
            pl01 = 0xffff0000;
          /* set the low WORD of our LONG for plane 0 + 1 */
          color = color >> 1;       /* get next bit */
          if(color & 1)
            pl01 |= 0x0000ffff;
          /* set the high WORD of our LONG for plane 2 + 3 */
          color = color >> 1;       /* get next bit */
          if(color & 1)
            pl23 = 0xffff0000;
          /* set the low WORD of our LONG for plane 2 + 3 */
          color = color >> 1;       /* get next bit */
          if(color & 1)
            pl23 |= 0x0000ffff;
          offs >>= 2;     /* from BYTE to LONG offset */
          addr = (unsigned long *)cell_addr(topx, topy);       /* start address */
          /* do all rows in region */
          for(row = rows; row--;)
          {
            /* loop through all cell pairs (LONG) */
            for(pair = pairs; pair--;)
            {
              *addr++ = pl01;       /* fill background to planes 0 & 1 */
              *addr++ = pl23;       /* fill background to planes 2 & 3 */
            }
            addr += offs;           /* skip non-region area with stride advance */
          }
        }
        break;
      case 2:
        {
          /* 2 planes */
          unsigned long *addr;     /* running pointer to screen */
          /* set the high WORD of our LONG for plane 0 + 1 */
          if(color & 0x1)
            pl01 = 0xffff0000;
          /* set the low WORD of our LONG for plane 0 + 1 */
          color = color >> 1;       /* get next bit */
          if(color & 0x1)
            pl01 |= 0x0000ffff;
          offs >>= 2;     /* from BYTE to LONG offset */
          addr = (unsigned long *)cell_addr(topx, topy);       /* start address */
          /* do all rows in region */
          for(row = rows; row--;)
          {
            /* loop through all cell pairs (LONG) */
            for(pair = pairs; pair--;)
              *addr++ = pl01;       /* fill background to planes 0 & 1 */
            addr += offs;           /* skip non-region area with stride advance */
          }
        }
        break;
      default:
        {
          /* if monochrome */
          unsigned short *addr;    /* running pointer to screen */
          /* set the WORD for plane 0 */
          if(color & 0x0001)
            pl01 = 0xffff;
          offs >>= 1;     /* from BYTE to WORD offset */
          addr = (unsigned short *)cell_addr(topx, topy);       /* start address */
          /* do all rows in region */
          for(row = rows; row--;)
          {
            for(pair = pairs; pair--;)
              *addr++ = pl01;       /* fill background to planes 0 & 1 */
            addr += offs;           /* skip non-region area with stride advance */
          }
        }
        break;
    }
  }
}

void sb_neg_cell_c(short *cell)
{
  VDIVARS *la = (VDIVARS*)(LINEA_VARS - LA_OFFSET);
  short i, j;
  la->disabCnt++; /* begin critical section */
  if((test_accel() && (la->vPlanes >= 8)) || (la->vPlanes >= 16))
  {
    switch(la->vPlanes)
    {
      case 8:
#if 0
        if(la->vOffAd[1] == 16)
        {
          long *p = (long *)cell;  		
          for(j = la->vCelHt; j--; p = (unsigned long *)((unsigned char *)p + la->vLinWr))
          {
            p[0] = ~p[0];
            p[1] = ~p[1];
            p[2] = ~p[2];
            p[3] = ~p[3];
          }
          cell++;
        }
        else
#endif
  	    {
          long *p = (long *)cell;  			
          for(j = la->vCelHt; j--; p = (unsigned long *)((unsigned char *)p + la->vLinWr))
          {
            p[0] = ~p[0];
            p[1] = ~p[1];
          }
          cell++;
        }
        break;
      case 16:
#if 0
        if(la->vOffAd[1] == 16)
        {
          long *p = (long *)cell;  		
          for(j = la->vCelHt; j--; p = (unsigned long *)((unsigned char *)p + la->vLinWr))
            for(i =0; i < 8; p[i] = ~p[i], i++);
          cell++;
        }
        else
#endif
  	    {
          long *p = (long *)cell;  			
          for(j = la->vCelHt; j--; p = (unsigned long *)((unsigned char *)p + la->vLinWr))
          {
            p[0] = ~p[0];
            p[1] = ~p[1];
            p[2] = ~p[2];
            p[3] = ~p[3];
          }
          cell++;
        }
        break;
      case 32:
#if 0
        if(la->vOffAd[1] == 16)
        {
          long *p = (long *)cell;  		
          for(j = la->vCelHt; j--; p = (unsigned long *)((unsigned char *)p + la->vLinWr))
            for(i =0; i < 16; p[i] = ~p[i], i++);
          cell++;
        }
        else
#endif
  	    {
          long *p = (long *)cell;  			
          for(j = la->vCelHt; j--; p = (unsigned long *)((unsigned char *)p + la->vLinWr))
          {
            p[0] = ~p[0];
            p[1] = ~p[1];
            p[2] = ~p[2];
            p[3] = ~p[3];
            p[4] = ~p[4];
            p[5] = ~p[5];
            p[6] = ~p[6];
            p[7] = ~p[7];
          }
          cell++;
        }
        break;
    }
  }
  else /* Atari planes */
  {
    for(i = la->vPlanes; i--;)
 	  {
#if 0
      if(la->vOffAd[1] == 16)
      {
        short *p = cell;  		
        for(j = la->vCelHt; j--; p = (unsigned short *)((unsigned char *)p + la->vLinWr))
          *p = ~*p;
        cell++;
      }
      else
#endif
  	  {
    	  char *p = (char *)cell;  		
        for(j = la->vCelHt; j--; p += la->vLinWr)
          *p = ~*p;
        cell++;
      }
    }
  }
  la->disabCnt--; /* end critical section */
}

void sb_move_cursor_c(short x, short y)
{
  VDIVARS *la = (VDIVARS*)(LINEA_VARS - LA_OFFSET);
  la->disabCnt++; /* begin critical section */
  if(la->vStat0 & M_CSTATE) /* cursor flash state */
  {
    /* cursor is currently visible, remove it */
    la->vStat0 &= ~M_CSTATE;
    sb_neg_cell_c(la->vCurAd);
  }
  /* clip cursor coordinates */
  if(x > la->vCelMx)
    x = la->vCelMx; 
  if(y > la->vCelMy)
    y = la->vCelMy;
  /* set cursor position */
  la->vCurCx = x;
  la->vCurCy = y;
  if((test_accel() && (la->vPlanes >= 8)) || (la->vPlanes >= 16))
    la->vCurAd = cell_addr2(x, y);
  else /* Atari planes */
    la->vCurAd = cell_addr(x, y);    
  /* redisplay cursor if applicable */
  if(!la->vDelay)
  {
    if(la->disabCnt == 1)
    {
      sb_neg_cell_c(la->vCurAd);
      la->vStat0 |= M_CSTATE;
      la->vCurTim = la->vCTInit;
    }
  }
  else  
    la->vCurTim = la->vDelay;
  la->disabCnt--; /* end critical section */  
}

