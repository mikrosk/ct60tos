/* TOS 4.04 Xbios for the CT60 board
*  Didier Mequignon 2002-2010, e-mail: aniplay@wanadoo.fr
*
*  This library is free software; you can redistribute it and/or
*  modify it under the terms of the GNU Lesser General Public
*  License as published by the Free Software Foundation; either
*  version 2.1 of the License, or (at your option) any later version.
*
*  This library is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
*  Lesser General Public License for more details.
*
*  You should have received a copy of the GNU Lesser General Public
*  License along with this library; if not, write to the Free Software
*  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef	_CT60_H
#define	_CT60_H

#define ID_CT60 (long)'CT60'

/* Vsetscreen modecode extended flags */

#define HORFLAG         0x200 /* double width */
#define HORFLAG2        0x400 /* width increased */
#define VESA_600        0x800 /* SVGA 600 lines */
#define VESA_768       0x1000 /* SVGA 768 lines */
#define VERTFLAG2      0x2000 /* double height */
#define DEVID          0x4000 /* bits 11-3 used for devID */
#define VIRTUAL_SCREEN 0x8000 /* width * 2 and height * 2, 2048 x 2048 max */
#define BPS32 5

#define GET_DEVID(x) (((x) & DEVID) ? (((x) & 0x3FF8) >> 3) : -1)
#define SET_DEVID(x) ((((x) << 3) & 0x3FF8) | DEVID)  

/* Vsetscreen New modes */
/* Vsetscreen(void *par1, void *par2, short rez, short command) */
/* with rez always 0x564E 'VN' (Vsetscreen New) */

#define CMD_GETMODE   0
#define CMD_SETMODE   1
#define CMD_GETINFO   2
#define CMD_ALLOCPAGE 3
#define CMD_FREEPAGE  4
#define CMD_FLIPPAGE  5
#define CMD_ALLOCMEM  6
#define CMD_FREEMEM   7
#define CMD_SETADR    8
#define CMD_ENUMMODES 9
#define CMD_TESTMODE  10
#define CMD_COPYPAGE  11

/* scrFlags */
#define SCRINFO_OK 1

/* scrClut */
#define NO_CLUT    0
#define HARD_CLUT  1
#define SOFT_CLUT  2

/* scrFormat */
#define INTERLEAVE_PLANES  0
#define STANDARD_PLANES    1
#define PACKEDPIX_PLANES   2

/* bitFlags */
#define STANDARD_BITS  1
#define FALCON_BITS    2
#define INTEL_BITS     8

typedef struct screeninfo
{
	long size;        /* size of structure          */
	long devID;       /* device id number (modecode)*/
	char name[64];    /* friendly name of screen    */
	long scrFlags;    /* some flags                 */
	long frameadr;    /* address of framebuffer     */
	long scrHeight;   /* visible X res              */
	long scrWidth;    /* visible Y res              */
	long virtHeight;  /* virtual X res              */
	long virtWidth;   /* virtual Y res              */
	long scrPlanes;   /* color planes               */
	long scrColors;   /* # of colors                */
	long lineWrap;    /* # of bytes to next line    */
	long planeWarp;   /* # of bytes to next plane   */
	long scrFormat;   /* screen format              */
	long scrClut;     /* type of clut               */
	long redBits;     /* mask of red Bits           */
	long greenBits;   /* mask of green Bits         */
	long blueBits;    /* mask of blue Bits          */
	long alphaBits;   /* mask of alpha Bits         */
	long genlockBits; /* mask of genlock Bits       */
	long unusedBits;  /* mask of unused Bits        */
	long bitFlags;    /* bits organisation flags    */
	long maxmem;      /* max. memory in this mode   */
	long pagemem;     /* needed memory for one page */
	long max_x;       /* max. possible width        */
	long max_y;       /* max. possible heigth       */
	long refresh;     /* refresh in Hz              */
	long pixclock;    /* pixel clock in pS          */
}SCREENINFO;

#define BLK_ERR      0
#define BLK_OK       1
#define BLK_CLEARED  2

typedef struct _scrblk
{
	long size;        /* size of structure          */
	long blk_status;  /* status bits of blk         */
	long blk_start;   /* Start Address              */
	long blk_len;     /* length of memblk           */
	long blk_x;       /* x pos in total screen      */
	long blk_y;       /* y pos in total screen      */
	long blk_w;       /* width                      */
	long blk_h;       /* height                     */
	long blk_wrap;    /* width in bytes             */
} SCRMEMBLK;
             
#define MSG_CT60_TEMP 0xcc60

/* CT60 parameters  */
#define CT60_CELCIUS 0
#define CT60_FARENHEIT 1
#define CT60_MODE_READ 0
#define CT60_MODE_WRITE 1
#define CT60_PARAM_TOSRAM 0
#define CT60_BLITTER_SPEED 1
#define CT60_CACHE_DELAY 2
#define CT60_BOOT_ORDER 3
#define CT60_CPU_FPU 4
#define CT60_BOOT_LOG 5
#define CT60_VMODE 6
#define CT60_SAVE_NVRAM_1 7
#define CT60_SAVE_NVRAM_2 8
#define CT60_SAVE_NVRAM_3 9
#define CT60_PARAM_OFFSET_TLV 10
#define CT60_ABE_CODE 11
#define CT60_SDR_CODE 12
#define CT60_CLOCK 13
#define CT60_PARAM_CTPCI 14
/* 15 is reserved - do not use */

typedef struct
{
	unsigned short trigger_temp;
	unsigned short daystop;
	unsigned short timestop;
	unsigned short speed_fan;
	unsigned long cpu_frequency; /* in MHz * 10 */
	unsigned short beep;
} CT60_COOKIE;

#define ct60_read_core_temperature(type_deg) (long)trap_14_ww((short)(0xc60a),(short)(type_deg))
#define	ct60_rw_parameter(mode,type_param,value) (long)trap_14_wwll((short)(0xc60b),(short)(mode),(long)(type_param),(long)(value))
#define ct60_cache(cache_mode) (long)trap_14_ww((short)(0xc60c),(short)(cache_mode))
#define ct60_flush_cache() (long)trap_14_w((short)(0xc60d))
#define ct60_vmalloc(mode,value) (long)trap_14_wwl((short)(0xc60e),(short)(mode),(long)(value))
#define CacheCtrl(OpCode,Param) (long)trap_14_www((short)(160),(short)(OpCode),(short)(Param))

#endif
