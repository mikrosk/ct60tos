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

#define GET_DEVID(x) (((x) & DEVID) ? ((x & 0x3FF8) >> 3) : -1)
#define SET_DEVID(x) ((((x) << 3) & 0x3FF8) | DEVID)  

/* Vsetscreen New modes */
/* Vsetscreen(void *par1, void *par2, short rez, short command) */
/* with rez always 0x564E 'VN' (Vsetscreen New) */

#define CMD_GETMODE    0
#define CMD_SETMODE    1
#define CMD_GETINFO    2
#define CMD_ALLOCPAGE  3
#define CMD_FREEPAGE   4
#define CMD_FLIPPAGE   5
#define CMD_ALLOCMEM   6
#define CMD_FREEMEM    7
#define CMD_SETADR     8
#define CMD_ENUMMODES  9
#define CMD_TESTMODE   10
#define CMD_COPYPAGE   11
#define CMD_FILLMEM    12
#define CMD_COPYMEM    13
#define CMD_TEXTUREMEM 14
#define CMD_GETVERSION 15
#define CMD_LINEMEM    16
#define CMD_CLIPMEM    17
#define CMD_SYNCMEM    18
#define CMD_BLANK      19

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

/* operations */
#define BLK_CLEAR        0
#define BLK_AND          1
#define BLK_ANDREVERSE   2
#define BLK_COPY         3
#define BLK_ANDINVERTED  4
#define BLK_NOOP         5
#define BLK_XOR          6
#define BLK_OR           7
#define BLK_XNOR         8
#define BLK_EQUIV        9
#define BLK_INVERT       10
#define BLK_ORREVERSE    11
#define BLK_COPYINVERTED 12
#define BLK_ORINVERTED   13
#define BLK_NAND         14
#define BLK_SET          15

typedef struct _scrfillblk
{
	long size;        /* size of structure          */
	long blk_status;  /* status bits of blk         */
  long blk_op;      /* mode operation             */
	long blk_color;   /* background fill color      */
	long blk_x;       /* x pos in total screen      */
	long blk_y;       /* y pos in total screen      */
	long blk_w;       /* width                      */
	long blk_h;       /* height                     */
	long blk_unused;
} SCRFILLMEMBLK;
           
typedef struct _scrcopyblk
{
	long size;        /* size of structure            */
	long blk_status;  /* status bits of blk           */
	long blk_src_x;   /* x pos source in total screen */
	long blk_src_y;   /* y pos source in total screen */
	long blk_dst_x;   /* x pos dest in total screen   */
	long blk_dst_y;   /* y pos dest in total screen   */
	long blk_w;       /* width                        */
	long blk_h;       /* height                       */
  long blk_op;      /* mode operation               */
} SCRCOPYMEMBLK;

typedef struct _scrtextureblk
{
	long size;        /* size of structure            */
	long blk_status;  /* status bits of blk           */
	long blk_src_x;   /* x pos source                 */
	long blk_src_y;   /* y pos source                 */
	long blk_dst_x;   /* x pos dest in total screen   */
	long blk_dst_y;   /* y pos dest in total screen   */
	long blk_w;       /* width                        */
	long blk_h;       /* height                       */
	long blk_op;      /* mode operation               */
	long blk_src_tex; /* source texture address       */
	long blk_w_tex;   /* width texture                */
	long blk_h_tex;   /* height texture               */
}SCRTEXTUREMEMBLK;

typedef struct _scrlineblk
{
	long size;        /* size of structure            */
	long blk_status;  /* status bits of blk           */
	long blk_fgcolor; /* foreground fill color        */
	long blk_bgcolor; /* background fill color        */
	long blk_x1;      /* x1 pos dest in total screen  */
	long blk_y1;      /* y1 pos dest in total screen  */
	long blk_x2;      /* x2 pos dest in total screen  */
	long blk_y2;      /* y2 pos dest in total screen  */
	long blk_op;      /* mode operation               */
	long blk_pattern; /* pattern (-1: solid line)     */
} SCRLINEMEMBLK;

typedef struct _scrclipblk
{
	long size;        /* size of structure            */
	long blk_status;  /* status bits of blk           */
	long blk_clip_on; /* clipping flag 1:on, 0:off    */
	long blk_x;       /* x pos in total screen        */
	long blk_y;       /* y pos in in total screen     */
	long blk_w;       /* width                        */
	long blk_h;       /* height                       */
} SCRCLIPMEMBLK;
             
#define MSG_CT60_TEMP 0xcc60

/* CT60 parameters  */
#define CT60_CELCIUS 0
#define CT60_FARENHEIT 1
#define CT60_MODE_READ 0
#define CT60_MODE_WRITE 1
#define CT60_PARAM_TOSRAM 0L /* obsolete for boot >= 2.00, but the CPX is backward compatible */
#define CT60_BLITTER_SPEED 1L
#define CT60_CACHE_DELAY 2L
#define CT60_BOOT_ORDER 3L
#define CT60_CPU_FPU 4L
#define CT60_BOOT_LOG 5L
#define CT60_VMODE 6L
#define CT60_SAVE_NVRAM_1 7L
#define CT60_SAVE_NVRAM_2 8L
#define CT60_SAVE_NVRAM_3 9L
#define CT60_PARAM_OFFSET_TLV 10L
#define CT60_MAC_ADDRESS 10L
#define CT60_SERIAL_SPEED 11L
#define CT60_USER_DIV_CLOCK 12L
#define CT60_IP_ADDRESS 12L
#define CT60_CLOCK 13L
#define CT60_SERVER_IP_ADDRESS 13L
#define CT60_PARAM_CTPCI 14L
/* 15 is reserved - do not use */

typedef struct
{
	unsigned short trigger_temp;
	unsigned short daystop;
	unsigned short timestop;
	unsigned short speed_fan;
	unsigned long cpu_frequency; /* in MHz * 10 */
	unsigned short beep;
	unsigned short timeblank;
} CT60_COOKIE;

#define ct60_read_core_temperature(type_deg) (long)xbios((short)0xc60a,(short)(type_deg))
#define ct60_rw_parameter(mode,type_param,value) (long)xbios((short)0xc60b,(short)(mode),(long)(type_param),(long)(value))
#define ct60_cache(cache_mode) (long)xbios((short)0xc60c,(short)(cache_mode))
#define ct60_flush_cache() (long)xbios((short)0xc60d)
#define ct60_vmalloc(mode,value) (long)xbios((short)0xc60e,(short)(mode),(long)(value))
#define CacheCtrl(OpCode,Param) (long)xbios((short)160,(short)(OpCode),(short)(Param))

#endif

