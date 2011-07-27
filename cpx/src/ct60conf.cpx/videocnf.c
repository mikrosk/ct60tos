/* Video Modes for Radeon / PURE C */
/* Didier MEQUIGNON - v1.01 - 2006-2011 */

#include <portab.h>
#include <string.h>
#include <tos.h>
#include <vdi.h>
#include <mt_aes.h>
#include <cpx.h>
#include <stdio.h>
#include "ct60.h"
#include "pcixbios.h"
#include "radeon.h"

#define Vsetscreen(log,phy,rez,mode) (void)xbios((short)0x05,(long)(log),(long)(phy),(short)(rez),(short)(mode))
#define Vsetmode(mode) (int)xbios((short)0x58,(short)(mode))

/* objects */
#define VIDEOBOX 0
#define VIDEOTEXT 1
#define VIDEOBCOUL 2
#define VIDEOBOXS 3
#define VIDEOCHOIX1 4
#define VIDEOCHOIX2 5
#define VIDEOCHOIX3 6
#define VIDEOCHOIX4 7
#define VIDEOCHOIX5 8
#define VIDEOCHOIX6 9
#define VIDEOBHAUT 10
#define VIDEOBOXSLIDER 11
#define VIDEOSLIDER 12
#define VIDEOBBAS 13
#define VIDEOLOGO 14
#define VIDEOINFO 15
#define VIDEOBCHANGE 16
#define VIDEOBANNULE 17
#define VIDEOBINFO 18
#define VIDEOBTEST 19
#define VIDEOBMODE 20

#define INFOBOX 0
#define INFOLOGO 1
#define INFOOK 10

char *rs_strings[] = {
	" LARGEUR HAUTEUR INFO             COULEURS","","",
	"65536",
	"AAAAAAAAAAAAAAAAAAAAAA","","",
	"BBBBBBBBBBBBBBBBBBBBBB","","",
	"CCCCCCCCCCCCCCCCCCCCCC","","",
	"DDDDDDDDDDDDDDDDDDDDDD","","",
	"EEEEEEEEEEEEEEEEEEEEEE","","",
	"FFFFFFFFFFFFFFFFFFFFFF","","",    
	"00000000 octets 000 Hz 000 MHz",
	"Sauve/reset",
	"Annule",
	"Test",
	"XIOS",

	"Radeon Vid‚o Modes V1.01 Mars 2011","","",
	"Ce CPX et systŠme:","","",
	"Didier MEQUIGNON","","",
	"aniplay@wanadoo.fr","","",
	"CTPCI Hardware:","","",
	"Rodolphe CZUBA","","",
	"rczuba@free.fr","","",
	"http://www.powerphenix.com","","",
	"OK" };
	
char *rs_strings_en[] = {
	" WIDTH   HIGHT   INFO             COLORS","","",
	"65536",
	"AAAAAAAAAAAAAAAAAAAAAA","","",
	"BBBBBBBBBBBBBBBBBBBBBB","","",
	"CCCCCCCCCCCCCCCCCCCCCC","","",
	"DDDDDDDDDDDDDDDDDDDDDD","","",
	"EEEEEEEEEEEEEEEEEEEEEE","","",
	"FFFFFFFFFFFFFFFFFFFFFF","","",    
	"00000000 bytes  000 Hz 000 MHz",
	"Save/reset",
	"Cancel",
	"Test",
	"XBIOS",

	"Radeon Video Modes V1.01 March 2011","","",
	"This CPX and system:","","",
	"Didier MEQUIGNON","","",
	"aniplay@wanadoo.fr","","",
	"CTPCI Hardware:","","",
	"Rodolphe CZUBA","","",
	"rczuba@free.fr","","",
	"http://www.powerphenix.com","","",
	"OK" };

long rs_frstr[] = {0};

BITBLK rs_bitblk[] = {
	(int *)0L,4,24,0,0,4,
	(int *)1L,12,62,0,0,2, };

long rs_frimg[] = {0};
ICONBLK rs_iconblk[] = {0};

TEDINFO rs_tedinfo[] = {
	(char *)0L,(char *)1L,(char *)2L,SMALL,0,2,0x1100,0,0,43,1,
	(char *)4L,(char *)5L,(char *)6L,IBM,0,0,0x1180,0,0,23,1,
	(char *)7L,(char *)8L,(char *)9L,IBM,0,0,0x1180,0,0,23,1,
	(char *)10L,(char *)11L,(char *)12L,IBM,0,0,0x1180,0,0,23,1,
	(char *)13L,(char *)14L,(char *)15L,IBM,0,0,0x1180,0,0,23,1,
	(char *)16L,(char *)17L,(char *)18L,IBM,0,0,0x1180,0,0,23,1,
	(char *)19L,(char *)20L,(char *)21L,IBM,0,0,0x1180,0,0,23,1,

	(char *)27L,(char *)28L,(char *)29L,IBM,0,2,0x1480,0,0,38,1,	
	(char *)30L,(char *)31L,(char *)32L,IBM,0,2,0x1180,0,0,38,1,
	(char *)33L,(char *)34L,(char *)35L,IBM,0,2,0x1180,0,0,38,1,
	(char *)36L,(char *)37L,(char *)38L,IBM,0,2,0x1180,0,0,38,1,
	(char *)39L,(char *)40L,(char *)41L,IBM,0,2,0x1180,0,0,38,1,
	(char *)42L,(char *)43L,(char *)44L,IBM,0,2,0x1180,0,0,38,1,
	(char *)45L,(char *)46L,(char *)47L,IBM,0,2,0x1180,0,0,38,1,
	(char *)48L,(char *)49L,(char *)50L,IBM,0,2,0x1180,0,0,38,1 };

OBJECT rs_object[] = {
	/* video choice Radeon */
	-1,1,20,G_BOX,FL3DBAK,NORMAL,0x1100L,0,0,32,11,
	2,-1,-1,G_TEXT,FL3DBAK,NORMAL,0L,0,0,32,1,
	3,-1,-1,G_BUTTON,TOUCHEXIT,SHADOWED,3L,26,1,5,1,										/* popup colors */
	4,-1,-1,G_BOX,NONE,NORMAL,0xff1100L,1,1,22,6,
	5,-1,-1,G_TEXT,NONE,NORMAL,1L,1,1,22,1,
	6,-1,-1,G_TEXT,NONE,NORMAL,2L,1,2,22,1,
	7,-1,-1,G_TEXT,NONE,NORMAL,3L,1,3,22,1,
	8,-1,-1,G_TEXT,NONE,NORMAL,4L,1,4,22,1,
	9,-1,-1,G_TEXT,NONE,NORMAL,5L,1,5,22,1,
	10,-1,-1,G_TEXT,NONE,NORMAL,6L,1,6,22,1,
	11,-1,-1,G_BOXCHAR,TOUCHEXIT,NORMAL,0x1ff1100L,23,1,2,1,								/*  */
	13,12,12,G_BOX,TOUCHEXIT,NORMAL,0xff1111L,23,2,2,4,
	11,-1,-1,G_BOX,TOUCHEXIT,NORMAL,0xff1100L,0,0,2,1,
	14,-1,-1,G_BOXCHAR,TOUCHEXIT,NORMAL,0x2ff1100L,23,6,2,1,								/*  */
	15,-1,-1,G_IMAGE,TOUCHEXIT,NORMAL,0L,27,3,4,3,											/* logo */
	16,-1,-1,G_STRING,NONE,NORMAL,22L,0,7,31,1,												/* mesures frequency  */
	17,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,23L,1,9,13,1,					/* Save and change */
	18,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|FL3DIND|FL3DBAK,NORMAL,24L,21,9,7,1,			/* Cancel */
	19,-1,-1,G_BOXCHAR,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,0x69ff1100L,29,9,2,1,			/* i */
	20,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,25L,15,9,5,1,					/* Test */
	0,-1,-1,G_BUTTON,LASTOB|TOUCHEXIT,SHADOWED,26L,26,6,5,1,								/* popup modes */

	/* info box */
	-1,1,10,G_BOX,FL3DBAK,OUTLINED,0x21100L,0,0,40,21,
	2,-1,-1,G_IMAGE,NONE,NORMAL,1L,14,1,12,5,
	3,-1,-1,G_TEXT,FL3DBAK,NORMAL,7L,1,7,38,1,
	4,-1,-1,G_TEXT,FL3DBAK,NORMAL,8L,1,9,38,1,
	5,-1,-1,G_TEXT,FL3DBAK,NORMAL,9L,1,10,38,1,
	6,-1,-1,G_TEXT,FL3DBAK,NORMAL,10L,1,11,38,1,
	7,-1,-1,G_TEXT,FL3DBAK,NORMAL,11L,1,13,38,1,
	8,-1,-1,G_TEXT,FL3DBAK,NORMAL,12L,1,14,38,1,
	9,-1,-1,G_TEXT,FL3DBAK,NORMAL,13L,1,15,38,1,
	10,-1,-1,G_TEXT,FL3DBAK,NORMAL,14L,1,17,38,1,
	0,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,51L,16,19,8,1};	/* OK */

long rs_trindex[] = {0L,21L};
struct foobar {
	int dummy;
	int *image;
	} rs_imdope[] = {0};

UWORD image_logo[]={
	0x0000,0x0000,
	0x1fff,0xfff0,
	0x2000,0x0008,
	0x2fff,0xffe8,
	0x2800,0x0028,
	0x2801,0x0028,	
	0x2803,0x8028,
	0x2807,0xc028,
	0x2881,0x0228,
	0x2981,0x0328,
	0x2bff,0xffa8,
	0x2981,0x0328,
	0x2881,0x0228,
	0x2807,0xc028,
	0x2803,0x8028,
	0x2801,0x0028,
	0x2800,0x0028,
	0x2fff,0xffe8,
	0x2000,0x0008,
	0x2000,0x0008,
	0x1ff0,0x1ff0,
	0x001f,0xf000,
	0x03ff,0xff80,
	0x07ff,0xffc0 };

UWORD pic_logo[]={
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF, 
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0x8000,0x0000,0x007F,
	0x01FF,0xFFFF,0xFFFE,0x0000,0x0000,0x003F,
	0x01FF,0xFFFF,0xFFFC,0x0000,0x0000,0x1F1F,
	0x01FF,0xFFFF,0xFFF0,0x0000,0x0000,0x3F8F,
	0x01FF,0xFFFF,0xFFF0,0x0000,0x0000,0x7FC7,
	0x01FF,0xFFFF,0xFFC0,0x0000,0x0000,0x7FE7,
	0x01FF,0xFFFF,0xFF80,0x0000,0x0000,0xFFE7,
	0x01FF,0xFFFF,0xFF00,0x0000,0x0000,0xFFE7,
	0x01FF,0xFFFF,0xFE00,0x0000,0x0000,0xFFE7,
	0x01FF,0xFFFF,0xFC00,0x0000,0x0000,0x7FC7,
	0x01FF,0xFFFF,0xF800,0x0000,0x0000,0x7FC7,
	0x01FF,0xFFFF,0xF000,0x0000,0x0000,0x3F8F,
	0x01FF,0xFFFF,0xE000,0x0000,0x0000,0x0E1F,
	0x01FF,0xFFFF,0xC000,0x0000,0x0000,0x003F,
	0x01FF,0xFFFF,0x8000,0x0000,0x0000,0x00FF,
	0x01FF,0xFFFF,0x0000,0x0700,0x00FF,0xFFFF,
	0x01FF,0xFFFE,0x0000,0x0F00,0x01FF,0xFFFF,
	0x01FF,0xFFFC,0x0000,0x1F00,0x01FF,0xC07F,
	0x01FF,0xFFF8,0x0000,0x3F80,0x01FF,0x003F,
	0x01FF,0xFFF0,0x0000,0x7F80,0x01FF,0x001F,
	0x01FF,0xFFE0,0x0000,0xFF80,0x01FE,0x000F,
	0x01FF,0xFFC0,0x0001,0xFF80,0x01FE,0x000F,
	0x01FF,0xFF80,0x0003,0xFF80,0x01FC,0x000F,
	0x01FF,0xFF00,0x0007,0xFF80,0x01FC,0x000F,
	0x01FF,0xFE00,0x000F,0xFF80,0x01FC,0x000F,
	0x01FF,0xFC00,0x001C,0x3F80,0x01FC,0x000F,
	0x01FF,0xF800,0x0030,0x0F80,0x01FC,0x000F,
	0x01FF,0xF000,0x0070,0x0780,0x01FC,0x000F,
	0x01FF,0xE000,0x00E0,0x0380,0x01FC,0x000F,
	0x01FF,0xC000,0x01E0,0x0380,0x01FC,0x000F,
	0x01FF,0x8000,0x03E0,0x0380,0x01FC,0x000F,
	0x01FF,0x0000,0x07E0,0x0380,0x01FC,0x000F,
	0x01FE,0x0000,0x0FE0,0x0380,0x01FC,0x000F,
	0x01FC,0x0000,0x1FE0,0x0380,0x01FC,0x000F,
	0x01F8,0x0000,0x3FE0,0x0780,0x01FC,0x000F,
	0x01F8,0x0000,0x7FF0,0x0780,0x01FC,0x000F,
	0x01F0,0x0000,0xFFFC,0x1F80,0x01FC,0x000F,
	0x01F0,0x0001,0xFFFF,0xFF80,0x01FC,0x000F,
	0x01F0,0x0003,0xFFFF,0xFF80,0x01FC,0x000F,
	0x01E0,0x0007,0xFFFF,0xFF80,0x01FC,0x000F,
	0x01E0,0x000F,0xFFFF,0xFF80,0x01FC,0x000F,
	0x01F0,0x001F,0xFFFF,0xFF80,0x01FE,0x000F,
	0x01F0,0x003F,0xFFFF,0xFF80,0x03FE,0x000F,
	0x01F8,0x007F,0xFFFF,0xFFC0,0x03FE,0x000F,
	0x01F8,0x00FF,0xFFFF,0xFFC0,0x07FF,0x001F, 
	0x01FC,0x01FF,0xFFFF,0xFFE0,0x0FFF,0x803F,
	0x01FF,0x03FF,0xFFFF,0xFFF8,0x3FFF,0xE0FF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF, 
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,
	0x01FF,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF };

#define NUM_STRINGS 52
#define NUM_FRSTR 0
#define NUM_IMAGES 0
#define NUM_BB 2
#define NUM_FRIMG 0
#define NUM_IB 0
#define NUM_TI 15
#define NUM_OBS 32
#define NUM_TREE 2

#define TREE1 0
#define TREE2 1

#define USA 0
#define FRG 1
#define FRA 2
#define UK 3
#define SPA 4
#define ITA 5
#define SWE 6
#define SWF 7
#define SWG 8

#define MAX_RES 200

#define MODES_XBIOS 0
#define MODES_VESA 1
#define MODES_RADEON 2

typedef struct
{
	long ident;
	union
	{
		long l;
		int i[2];
		char c[4];
	} v;
} COOKIE;

typedef struct {
	WORD version;
	void (*fast_clrmem)( void *von, void *bis );
	char (*toupper)( char c );
	void (*_sprintf)( char *dest, char *source, LONG *p );
	BASPAG **act_pd;
 	void *act_appl;
	void *keyb_app;
	WORD *pe_slice;
	WORD *pe_timer;
	void (*appl_yield)( void );
	void (*appl_suspend)( void );
	void (*appl_begcritic)( void );
	void (*appl_endcritic)( void );
	long (*evnt_IO)( LONG ticks_50hz, void *unsel );
	void (*evnt_mIO)( LONG ticks_50hz, void *unsel, WORD cnt );
	void (*evnt_emIO)( void *ap );
	void (*appl_IOcomplete)( void *ap );
	long (*evnt_sem)( WORD mode, void *sem, LONG timeout );
	void (*Pfree)( void *pd );
	WORD int_msize;
	void *int_malloc( void );
	void int_mfree( void *memblk );
	void resv_intmem( void *mem, LONG bytes );
	LONG diskchange( WORD drv );
	LONG DMD_rdevinit( void *dmd );
	LONG proc_info( WORD code, BASPAG *pd );
	LONG mxalloc( LONG amount, WORD mode, BASPAG *pd );
	LONG mfree( void *block );
	LONG mshrink( LONG newlen, void *block );
} MX_KERNEL;

typedef struct
{
	long magic;
	void *membot;
	void *aes_start;
	long magic2;
	long date;
	void (*chgres)(int res,int txt);
	long (**shel_vector)(void);
	char *aes_bootdrv;
	short *vdi_device;
	void *reservd1;
	void *reservd2;
	void *reservd3;
	short version;
	short release;
} AESVARS;

typedef struct
{
	long config_status;
	void *dosvars;
	AESVARS *aesvars;
	void *res1;
	void *hddrv_functions;
	long status_bits;
} MAGX_COOKIE;

typedef struct
{
	int state;			/* selected or not */
	int modecode;
	int width_screen;
	int height_screen;
	int vert_freq;
	int pixel_clock;
	char name[24];
} LISTE_RES;

/* prototypes */

int CDECL cpx_call(GRECT *work);
void init_rsc(void);
OBJECT* adr_tree(int num_tree);
int hndl_form(OBJECT *tree,int objc);
void init_list_rez(int choice_color);
int current_rez(int modecode,int *vert_freq,int *pixel_clock);
void display_slider(GRECT *work);
void init_slider(void);
void select_normal_rez(GRECT *work);
void display_rez(int flag,GRECT *work);
CPXNODE* get_header(long id);
int modif_sys(LISTE_RES *rez);
int modif_inf(int modecode);
int read_hexa(char *p);
int ascii_hexa(char *p);
void write_hexa(int val,char *p);
void hexa_ascii(int val,char *p);
void display_error(int err);
int get_MagiC_ver(unsigned long *crdate);
COOKIE *fcookie(void);
COOKIE *ncookie(COOKIE *p);
COOKIE *get_cookie(long id);
int find_radeon(void);
int copy_string(char *p1,char *p2);
int long_deci(char *p,int *lg);
int val_string(char *p);
long tempo_5S(void);
void reboot(void);
void (*reset)(void);

/* variables globales */

LISTE_RES liste_rez[MAX_RES];
int offset_select = 0, nb_res = 0, sel_color, type_modes = 0;

/* global variables VDI & AES */

int	vdi_handle, work_in[11] = {1,1,1,1,1,1,1,1,1,1,2}, work_out[57], work_extend[57];
int errno;
XCPB *Xcpb;
CPXNODE *head;
CPXINFO	cpxinfo = {cpx_call,0,0,0,0,0,0,0,0,0};
int start_lang = 0;

CPXINFO* CDECL cpx_init(XCPB *xcpb)
{
	Xcpb=xcpb;
	return(&cpxinfo);
}

int CDECL cpx_call(GRECT *work)
{
	static char *colors[] = {"  2   ","  4   ","  16  ","  256 ","  65K ","  16M  " };
	char *modes[] = { "  XBIOS ","  VESA  ","  DRIV  " };
	char *spec_modes[] = { "XBIOS","VESA","DRIV" };
	static char *spec_sauve_change[2] = {"Sauve/change","Save/change"};
	static char *spec_sauve_reboot[2] = {"Sauve/reset","Save/reset"};
	MX_KERNEL *mx_kernel;
	COOKIE *p;
	int xy[8];
	MFDB source,target;
	GRECT menu,rect,r;
	OBJECT *info_tree;
	TEDINFO *t_edinfo;	
	EVNTDATA mouse;
	long temp;
	unsigned long magic_date=0L;
	int mesag[8];
	char cmde[32];
	int ret,fvdi,mint,magic,double_clic,fin,redraw,modecode,new_mode,cur_mode,test_mode,choice_color,choice_rez,vert_freq,pixel_clock,l,h;
	register int i,j;
	init_rsc();
	if(get_cookie('fVDI') != NULL)
		fvdi=1;
	else
		fvdi=0;
	if(get_cookie('MiNT') != NULL)
		mint=1;
	else
		mint=0;
	magic_date=0L;
	magic=get_MagiC_ver(&magic_date);
	if((head=get_header('ATIC')) == NULL)
		return(0);
	if(((p = get_cookie('_MCH')) == NULL) || (p->v.l != 0x30000L))
	{
		if(!start_lang)
			form_alert(1,"[1][Cette machine|n'est pas un FALCON][Annuler]");
		else
			form_alert(1,"[1][This computer isn't|a FALCON][Cancel]");
		return(0);
	}
	if(!find_radeon())
	{
		if(!start_lang)
			form_alert(1,"[1][Pas de Radeon|PCI install‚e][Annuler]");
		else
			form_alert(1,"[1][No Radeon PCI|installed][Cancel]");
		return(0);
	}
	if((vdi_handle=Xcpb->handle) <= 0)
		return(0);
	v_opnvwk(work_in,&vdi_handle,work_out);
	if(vdi_handle <= 0)
		return(0);
	vq_extnd(vdi_handle,1,work_extend);
	modecode=Vsetmode(-1);
	if(!(modecode & DEVID))
		type_modes = MODES_XBIOS;
	else
	{
		if(GET_DEVID(modecode) < 34)
			type_modes = MODES_VESA;
		else if(GET_DEVID(modecode))
			type_modes = MODES_RADEON;
	}
	rs_object[VIDEOBCOUL].ob_flags |= TOUCHEXIT;
	rs_object[VIDEOBCOUL].ob_state &= ~DISABLED;
	rs_object[VIDEOBOX].ob_x=work->g_x;
	rs_object[VIDEOBOX].ob_y=work->g_y;
	rs_object[VIDEOBOX].ob_width=work->g_w;
	rs_object[VIDEOBOX].ob_height=work->g_h;
	choice_color=modecode & NUMCOLS;
	init_list_rez(choice_color);
	offset_select=0;
	choice_rez=current_rez(modecode,&vert_freq,&pixel_clock);	/* search curent rez inside the list */
	for(i=VIDEOCHOIX1;i<=VIDEOCHOIX6;i++)
	{
		if(choice_rez+VIDEOCHOIX1==i)
			rs_object[i].ob_state |= SELECTED;
		else
			rs_object[i].ob_state &= ~SELECTED;
	}
	display_rez(0,work);
	if(choice_color >= 5)
		copy_string("16M",rs_object[VIDEOBCOUL].ob_spec.free_string);
	else
		sprintf(rs_object[VIDEOBCOUL].ob_spec.free_string,"%ld",1L<<(long)(1<<choice_color));
	rs_object[VIDEOBMODE].ob_spec.free_string = spec_modes[type_modes];
	if(!start_lang)
		sprintf(rs_object[VIDEOINFO].ob_spec.free_string,"%8ld octets %3d Hz %3d MHz",
		 VgetSize(modecode),vert_freq,pixel_clock);
	else
		sprintf(rs_object[VIDEOINFO].ob_spec.free_string,"%8ld bytes  %3d Hz %3d MHz",
		 VgetSize(modecode),vert_freq,pixel_clock);
	if(mint || magic)
		rs_object[VIDEOBCHANGE].ob_spec.free_string=spec_sauve_change[start_lang];
	else
		rs_object[VIDEOBCHANGE].ob_spec.free_string=spec_sauve_reboot[start_lang];
	if(choice_rez>=0)
	{
		rs_object[VIDEOBCHANGE].ob_flags |= (SELECTABLE|EXIT);
		rs_object[VIDEOBCHANGE].ob_state &= ~DISABLED;
	}
	else
	{
		rs_object[VIDEOBCHANGE].ob_flags &= ~(SELECTABLE|EXIT);
		rs_object[VIDEOBCHANGE].ob_state |= DISABLED;
	}
	fin=0,redraw=1;
	do
	{
		if(redraw)
		{
			objc_draw(rs_object,VIDEOBOX,2,work);
			redraw=0;
		}
		double_clic=0;
		ret=(*Xcpb->Xform_do)(rs_object,0,mesag);
		if(ret!=-1 && (ret & 0x8000))
		{
			ret &= 0x7fff;
			double_clic=1;
		}
		switch(ret)
		{
		case VIDEOBCOUL:
			objc_offset(rs_object,VIDEOBCOUL,&menu.g_x,&menu.g_y);
			menu.g_w=rs_object[VIDEOBCOUL].ob_width;
			menu.g_h=rs_object[VIDEOBCOUL].ob_height;
			if((ret=(*Xcpb->Popup)(colors,6,choice_color,IBM,&menu,work))>=0
			 && (ret!=choice_color))
			{
				offset_select=0;
				choice_color=ret;
				if(choice_color>=5)
					copy_string("16M",rs_object[VIDEOBCOUL].ob_spec.free_string);
				else
					sprintf(rs_object[VIDEOBCOUL].ob_spec.free_string,"%ld",1L<<(long)(1<<choice_color));
				objc_draw(rs_object,VIDEOBCOUL,2,work);
				if(choice_rez>=0)
				{
					cur_mode=liste_rez[choice_rez].modecode & ~NUMCOLS;
					init_list_rez(choice_color);
					choice_rez=-1;
					for(i=0;i<nb_res;i++)	/* search rez with previous selected colors choice */
					{
						if((liste_rez[i].modecode & ~NUMCOLS) == cur_mode)
						{
							choice_rez=i;
							liste_rez[i].state=SELECTED;
							break;
						}
					}
				}
				else
				{
					init_list_rez(choice_color);
					if((ret=current_rez(modecode,&vert_freq,&pixel_clock))>=0)
						choice_rez=ret;
				}
				goto display_res;
			}
			break;
		case VIDEOCHOIX1:
		case VIDEOCHOIX2:
		case VIDEOCHOIX3:
		case VIDEOCHOIX4:
		case VIDEOCHOIX5:
		case VIDEOCHOIX6:
			if(nb_res>=0)
			{
				if(choice_rez>=0)
						liste_rez[choice_rez].state=NORMAL;
				select_normal_rez(work);
				objc_change(rs_object,ret,0,work,SELECTED,1);
				do
					graf_mkstate(&mouse);
				while(mouse.bstate);
				ret-=VIDEOCHOIX1;
				choice_rez=ret+offset_select;
				liste_rez[choice_rez].state=SELECTED;
				rs_object[VIDEOBCHANGE].ob_flags |= (SELECTABLE|EXIT);
				if(double_clic)
				{
					static char mess_alert[256];
					LISTE_RES *r = &liste_rez[choice_rez];
					objc_change(rs_object,VIDEOBCHANGE,0,work,SELECTED,1);
					if(!start_lang)
					{
						static char alert[] = "[2][Changer la r‚solution en";
						static char end_alert[] = "][Annuler|Changer]";
						sprintf(mess_alert,"%s|%dx%dx%d@%d ?|modecode: 0x%04X (%u)%s",
						 alert,r->width_screen,r->height_screen,1<<(r->modecode & NUMCOLS),r->vert_freq,(unsigned int)r->modecode,(unsigned int)r->modecode,end_alert);
					}
					else
					{
						static char alert[] = "[2][Change the screen in";
						static char end_alert[] = "][Cancel|Change]";
						sprintf(mess_alert,"%s|%dx%dx%d@%d ?|modecode: 0x%04X (%u)%s",
						 alert,r->width_screen,r->height_screen,1<<(r->modecode & NUMCOLS),r->vert_freq,(unsigned int)r->modecode,(unsigned int)r->modecode,end_alert);
					}	
					if(form_alert(1,mess_alert)!=1)
						goto change;
				}
				objc_change(rs_object,VIDEOBCHANGE,0,work,NORMAL,1);
			}
			break;
		case VIDEOBHAUT:
			if(offset_select)
			{
				objc_change(rs_object,VIDEOBHAUT,0,work,SELECTED,1);
				offset_select--;
				if(offset_select<0)
					offset_select=0;
				display_rez(1,work);
				objc_change(rs_object,VIDEOBHAUT,0,work,NORMAL,1);
 			}
			break;
		case VIDEOBOXSLIDER:
			graf_mkstate(&mouse);
			objc_offset(rs_object,VIDEOSLIDER,&mouse.x,&ret);
			if(mouse.y>ret)
				offset_select+=6;
 			else
				offset_select-=6;
			if(offset_select<0)
				offset_select=0;
			if((i=nb_res-6)<0)
				i=0;
			if(offset_select>i)
				offset_select=i;
			display_rez(1,work);
			break;
		case VIDEOSLIDER:
			wind_update(BEG_MCTRL);
			ret=graf_slidebox(rs_object,VIDEOBOXSLIDER,VIDEOSLIDER,1);
			wind_update(END_MCTRL);
			if((i=nb_res-6)<0)
				i=0;
			temp=(long)i*(long)ret;
			temp/=1001L;
			if(temp%1001L)
				temp++;
			offset_select=(int)temp;
			display_rez(1,work);
			break;
		case VIDEOBBAS:
			if((i=nb_res-6)<0)
				i=0;
			if(offset_select!=i)
			{
				objc_change(rs_object,VIDEOBBAS,0,work,SELECTED,1);
				offset_select++;
				if(offset_select>i)
					offset_select=i;
				display_rez(1,work);
				objc_change(rs_object,VIDEOBBAS,0,work,NORMAL,1);
			}
			break;
		case VIDEOLOGO:
			do
				graf_mkstate(&mouse);
			while(mouse.bstate);	
			choice_color=modecode & NUMCOLS;
			if(choice_color>=5)
				copy_string("16M",rs_object[VIDEOBCOUL].ob_spec.free_string);
			else
				sprintf(rs_object[VIDEOBCOUL].ob_spec.free_string,"%ld",1L<<(long)(1<<choice_color));
			objc_draw(rs_object,VIDEOBCOUL,2,work);
			init_list_rez(choice_color);
			choice_rez=current_rez(modecode,&vert_freq,&pixel_clock);	/* search current rez inside the list */
display_res:
			if(choice_rez>=0)
			{
				for(i=VIDEOCHOIX1;i<=VIDEOCHOIX6;i++)
				{
					if(choice_rez+VIDEOCHOIX1-offset_select==i)
						rs_object[i].ob_state |= SELECTED;
					else
						rs_object[i].ob_state &= ~SELECTED;
				}
				rs_object[VIDEOBCHANGE].ob_flags |= (SELECTABLE|EXIT);
			}
			else
				rs_object[VIDEOBCHANGE].ob_flags &= ~(SELECTABLE|EXIT);
			display_rez(1,work);
			objc_change(rs_object,VIDEOBCHANGE,0,work,choice_rez>=0 ? NORMAL : DISABLED,1);
			break;
		case VIDEOBCHANGE:
change:		
			rs_object[VIDEOBCHANGE].ob_state &= ~SELECTED;
			if(choice_rez>=0)
			{
				new_mode=liste_rez[choice_rez].modecode;
				if(fvdi)
				{
					if(!start_lang)
					{
						if(form_alert(1,"[2][Voulez-vous sauver|la r‚solution|dans FVDI.SYS ?][Annuler|Sauver]")!=1)
							modif_sys(&liste_rez[choice_rez]);
							
					}
					else
					{
						if(form_alert(1,"[2][Do you want save the|screen selected|inside FVDI.SYS ?][Cancel|Save]")!=1)
							modif_sys(&liste_rez[choice_rez]);
					}	
				}
				if(mint || magic)
				{
					modif_inf(new_mode);			/* modification modecode NEWDESK.INF */
					if(new_mode != modecode)
					{
						if(shel_write(5,new_mode,1,"",""))		/* change rez */
						{
							if(mint)
							{										/* MultiTOS */
								MT_wind_new(0L);
								appl_exit();
								Pterm0();
							}							
						}
						else
						{
							if(!start_lang)
							{
								if(form_alert(1,"[1][Vous devez fermer toutes les |applications actuellement |ouvertes avant de changer de |r‚solution][Annuler|Rebooter]")!=1)
									reboot();
							}
							else
							{
								if(form_alert(1,"[1][You must close all|applications opened before|change the screen][Cancel|Reboot]")!=1)
									reboot();
							}	
						}
					}
				}
				else								/* without MiNT / MAGIC */
				{
					modif_inf(new_mode);			/* modification modecode NEWDESK.INF */
					if(new_mode != modecode)
						reboot();					/* change rez by reset system */
				}
			}
			fin=1;
			break;
		case VIDEOBANNULE:
			rs_object[VIDEOBANNULE].ob_state &= ~SELECTED;
			fin=1;
			break;
		case VIDEOBINFO:
			objc_change(rs_object,VIDEOBINFO,0,work,NORMAL,1);
			if((info_tree=adr_tree(TREE2))!=0)
				hndl_form(info_tree,0);
			break;
		case VIDEOBTEST:
			rect.g_x=rect.g_y=0;                /* screen size */
			rect.g_w=work_out[0];
			rect.g_h=work_out[1];
			wind_update(BEG_UPDATE);
			graf_mouse(M_OFF,(MFORM *)0);
			form_dial(FMD_START,&rect,&rect);
			wind_get(0,WF_WORKXYWH,&r.g_x,&r.g_y,&r.g_w,&r.g_h); /* desktop */
			wind_get(0,WF_SCREEN,&xy[0],&xy[1],&xy[2],&xy[3]);
			target.fd_addr=0;                   /* screen */
			source.fd_addr=(void *)(((long)xy[0]<<16)+(long)((unsigned)xy[1]));	/* AES buffer */
			source.fd_w=work_out[0]+1;          /* width screen */
			source.fd_h=work_out[1]+1;          /* height screen */
			source.fd_wdwidth=source.fd_w>>4;
			if(source.fd_w%16)
				source.fd_wdwidth++;
			source.fd_stand=0;
			source.fd_nplanes=work_extend[4];   /* nb planes */
			xy[0]=xy[1]=xy[4]=xy[5]=0;          /* x1,y1 */
			xy[2]=xy[6]=r.g_w-1;                /* x2 */
			xy[3]=xy[7]=r.g_y-1;                /* y2 */
			vro_cpyfm(vdi_handle,S_ONLY,xy,&target,&source); /* save menu */
			cur_mode=Vsetmode(-1);              /* save curent video mode */
			if(choice_rez>=0) 
				test_mode = liste_rez[choice_rez].modecode & ~VIRTUAL_SCREEN;
			else
				test_mode = modecode & ~VIRTUAL_SCREEN;
			Vsetscreen(-1,test_mode,'VN',CMD_TESTMODE);
			ret=Vsetmode(-1);
			Supexec(tempo_5S);                  /* delay */
			if(Vsetmode(cur_mode));             /* restore video mode */
			xy[0]=xy[1]=xy[4]=xy[5]=0;          /* x1,y1 */
			xy[2]=xy[6]=r.g_w-1;                /* x2 */
			xy[3]=xy[7]=r.g_y-1;                /* y2 */
			vro_cpyfm(vdi_handle,S_ONLY,xy,&source,&target);	/* redraw menu */
			rect.g_x=rect.g_y=0;                /* redraw screen */
			rect.g_w=work_out[0];
			rect.g_h=work_out[1];
			form_dial(FMD_FINISH,&rect,&rect);
			graf_mouse(M_ON,(MFORM *)0);
			graf_mouse(ARROW,(MFORM *)0);
			wind_update(END_UPDATE);
			objc_change(rs_object,VIDEOBTEST,0,work,NORMAL,1);
			if(ret != test_mode)
			{
				static char mess_alert[256];
				register int i;
				for(i=0;i<nb_res;i++)	/* search modecode really used (nearest ?) inside the list */
				{
					if(liste_rez[i].modecode==ret)
					{
						if(!start_lang)
						{
							static char alert[] = "[1][La plus proche r‚solution est";
							static char end_alert[] = "][OK]";
							sprintf(mess_alert,"%s|%dx%dx%d@%d|modecode: 0x%04X (%u)%s",
							 alert,liste_rez[i].width_screen,liste_rez[i].height_screen,1<<(ret & NUMCOLS),liste_rez[i].vert_freq,(unsigned int)ret,(unsigned int)ret,end_alert);
						}
						else
						{
							static char alert[] = "[1][Nearest screen possible is";
							static char end_alert[] = "][OK]";
							sprintf(mess_alert,"%s|%dx%dx%d@%d|modecode: 0x%04X (%u)%s",
							 alert,liste_rez[i].width_screen,liste_rez[i].height_screen,1<<(ret & NUMCOLS),liste_rez[i].vert_freq,(unsigned int)ret,(unsigned int)ret,end_alert);
						}	
						form_alert(1,mess_alert);
						break;
					}
				}
			}
			break;
		case VIDEOBMODE:
			objc_offset(rs_object,VIDEOBMODE,&menu.g_x,&menu.g_y);
			menu.g_w=rs_object[VIDEOBMODE].ob_width;
			menu.g_h=rs_object[VIDEOBMODE].ob_height;
			if((ret=(*Xcpb->Popup)(modes,3,type_modes,IBM,&menu,work))>=0
			 && (ret!=type_modes))
			{
				offset_select=0;
				type_modes=ret;
				rs_object[VIDEOBMODE].ob_spec.free_string = spec_modes[type_modes];
				objc_draw(rs_object,VIDEOBMODE,2,work);
				if(choice_rez>=0)
				{
					cur_mode=liste_rez[choice_rez].modecode & ~NUMCOLS;
					init_list_rez(choice_color);
					choice_rez=-1;
					for(i=0;i<nb_res;i++)	/* search rez with previous selected colors choice */
					{
						if((liste_rez[i].modecode & ~NUMCOLS) == cur_mode)
						{
							choice_rez=i;
							liste_rez[i].state=SELECTED;
							break;
						}
					}
				}
				else
				{
					init_list_rez(choice_color);
					if((ret=current_rez(modecode,&vert_freq,&pixel_clock))>=0)
						choice_rez=ret;
				}
				goto display_res;
			}
			break;
		case -1:
			switch(mesag[0])
			{
			case WM_REDRAW:
				break;
			case WM_CLOSED:
			case AC_CLOSE:
			case AP_TERM:
				fin=1;
			}
		}
	}
	while(!fin); 
	v_clsvwk(vdi_handle);
	return(0);
}

void init_rsc(void)
{
	OBJECT *info_tree;
	BITBLK *b_itblk;
	COOKIE *p;
	register int i;
	char **rs_str;
	if(((p = get_cookie('_AKP')) != NULL)
	 && ((p->v.l >> 8) == FRA) || ((p->v.l >> 8) == SWF))
	{
		start_lang=0;
		rs_str=rs_strings;
	}
	else
	{
		start_lang=1;
		rs_str=rs_strings_en;
	}
	if(!(Xcpb->SkipRshFix))
	{
		(*Xcpb->rsh_fix)(NUM_OBS,NUM_FRSTR,NUM_FRIMG,NUM_TREE,rs_object,rs_tedinfo,rs_str,rs_iconblk,rs_bitblk,rs_frstr,rs_frimg,rs_trindex,rs_imdope);
		rs_object[VIDEOTEXT].ob_y+=2;
		rs_object[VIDEOBHAUT].ob_x++;
		rs_object[VIDEOBOXSLIDER].ob_x++;
		rs_object[VIDEOBOXSLIDER].ob_y++;
		rs_object[VIDEOBOXSLIDER].ob_height-=2;
		rs_object[VIDEOBBAS].ob_x++;
		rs_object[VIDEOLOGO].ob_y-=4;
		b_itblk=rs_object[VIDEOLOGO].ob_spec.bitblk;
		b_itblk->bi_pdata=(int *)image_logo;
		rs_object[VIDEOINFO].ob_y+=4;
		rs_object[VIDEOBMODE].ob_y-=4;
		if((info_tree=adr_tree(TREE2))!=0)
		{
			info_tree[INFOLOGO].ob_x-=4;
			b_itblk=info_tree[INFOLOGO].ob_spec.bitblk;
			b_itblk->bi_pdata=(int *)pic_logo;
		}
	}
}

OBJECT* adr_tree(int num_tree)
{
	register int i,tree;
	if(!num_tree)
		return(rs_object);
	for(i=tree=0;i<NUM_OBS;i++)
	{
		if(rs_object[i].ob_flags & LASTOB)
		{
			tree++;
			if(tree==num_tree)
				return(&rs_object[i+1]);
		}
	}
	return(0L);
}

int hndl_form(OBJECT *tree,int objc)
{
	register int i,flag_exit,answer;
	long value;
	GRECT rect,kl_rect;
	void *flyinf;
	void *scantab=0;
	int	lastcrsr;
	wind_update(BEG_UPDATE);
	form_center(tree,&rect);
	answer=flag_exit=i=0;
	do
	{
		if(tree[i].ob_flags & EXIT)
			flag_exit=1;
	}
	while(!(tree[i++].ob_flags & LASTOB));
	if((get_cookie('MagX') != NULL) && flag_exit)
	{									/* MagiC dialog */ 
		form_xdial(FMD_START,&kl_rect,&rect,&flyinf);
		objc_draw(tree,0,MAX_DEPTH,&rect);
		answer = 0x7f & form_xdo(tree,objc,&lastcrsr,scantab,flyinf);
		form_xdial(FMD_FINISH,&kl_rect,&rect,&flyinf);
	}
	else								/* TOS dialog */
	{
		form_dial(FMD_START,&kl_rect,&rect);
		objc_draw(tree,0,MAX_DEPTH,&rect);
		if(flag_exit)
			answer = 0x7f & form_do(tree,objc);
		else
			evnt_timer((long)objc);		/* dialog without EXIT button */
		form_dial(FMD_FINISH,&kl_rect,&rect);
	}
	wind_update(END_UPDATE);
	tree[answer].ob_state &= ~SELECTED;
	return(answer);
}	

long cdecl enumfunc(SCREENINFO *inf,long flag)
{
	int i;
	if(flag);
	if((nb_res < MAX_RES)
	 && ((inf->devID & NUMCOLS) == (long)sel_color)
	 && ( ((type_modes == MODES_XBIOS) && !(inf->devID & DEVID))
	  || ((type_modes == MODES_VESA) && (inf->devID & DEVID) && (GET_DEVID(inf->devID) < 34))
	  || ((type_modes == MODES_RADEON) && (inf->devID & DEVID) && (GET_DEVID(inf->devID) >= 34)) ))
	{
		liste_rez[nb_res].state=NORMAL;
		liste_rez[nb_res].modecode=(int)inf->devID;
		liste_rez[nb_res].width_screen=(int)inf->scrWidth;
		liste_rez[nb_res].height_screen=(int)inf->scrHeight;
		liste_rez[nb_res].vert_freq=(int)inf->refresh;
		if(inf->pixclock)
			liste_rez[nb_res].pixel_clock=(int)(1000000L/inf->pixclock);
		else
			liste_rez[nb_res].pixel_clock=0;
		for(i=0;i<22 && inf->name[i];liste_rez[nb_res].name[i]=inf->name[i],i++);
		for(;i<22;liste_rez[nb_res].name[i++]=' ');
		liste_rez[nb_res].name[i]=0;
		nb_res++;
	}
	if(nb_res < MAX_RES)
		return(1);
	return(0);
}

void init_list_rez(int choice_color)
{
	register int liste,i,j,temp;
	char buf_temp[24];
	nb_res=0;
	sel_color=(long)choice_color;
	Vsetscreen(-1,&enumfunc,'VN',CMD_ENUMMODES);
	for(i=0;i<nb_res;i++)		/* sort */
	{
		for(j=0;j<nb_res;j++)
		{
			if((unsigned long)liste_rez[i].height_screen*(unsigned long)liste_rez[i].width_screen+((unsigned long)liste_rez[i].modecode&0xFFFF)
			 < (unsigned long)liste_rez[j].height_screen*(unsigned long)liste_rez[j].width_screen+((unsigned long)liste_rez[j].modecode&0xFFFF))
			{
				temp=liste_rez[i].modecode;
				liste_rez[i].modecode=liste_rez[j].modecode;
				liste_rez[j].modecode=temp;		
				temp=liste_rez[i].width_screen;
				liste_rez[i].width_screen=liste_rez[j].width_screen;
				liste_rez[j].width_screen=temp;
				temp=liste_rez[i].height_screen;
				liste_rez[i].height_screen=liste_rez[j].height_screen;
				liste_rez[j].height_screen=temp;
				temp=liste_rez[i].vert_freq;
				liste_rez[i].vert_freq=liste_rez[j].vert_freq;
				liste_rez[j].vert_freq=temp;
				temp=liste_rez[i].pixel_clock;
				liste_rez[i].pixel_clock=liste_rez[j].pixel_clock;
				liste_rez[j].pixel_clock=temp;
				copy_string(liste_rez[i].name,buf_temp);
				copy_string(liste_rez[j].name,liste_rez[i].name);
				copy_string(buf_temp,liste_rez[j].name);
			}
		}
	}
}
						
int current_rez(int modecode,int *vert_freq,int *pixel_clock)
{
	register int i,choice_rez=-1;
	for(i=0;i<nb_res;i++)	/* search current rez inside the list */
	{
		if(liste_rez[i].modecode==modecode)
		{
			choice_rez=i;
			liste_rez[i].state=SELECTED;
			*vert_freq=liste_rez[i].vert_freq;
			*pixel_clock=liste_rez[i].pixel_clock;
		}
	}					
	return(choice_rez);
}

void display_slider(GRECT *work)
{
	register int i;
	if((i=nb_res-6)<=0)		
		i=1;
	/* vectical position of the slider */
	rs_object[VIDEOSLIDER].ob_y =
	 (offset_select * (rs_object[VIDEOBOXSLIDER].ob_height - rs_object[VIDEOSLIDER].ob_height))/i;
	objc_draw(rs_object,VIDEOBOXSLIDER,2,work);
}

void init_slider(void)
{
	register int i;
	if((i=nb_res)<6)		
		i=6;
	i=(rs_object[VIDEOBOXSLIDER].ob_height)*6/i;
	if(i<8)
		i=8;
	rs_object[VIDEOSLIDER].ob_height=i;
	if((i=nb_res-6)<=0)		
		i=1;
	/* vertical position of the slider */
	rs_object[VIDEOSLIDER].ob_y =
	 (offset_select * (rs_object[VIDEOBOXSLIDER].ob_height - rs_object[VIDEOSLIDER].ob_height))/i;
}

void select_normal_rez(GRECT *work)
{
	register int i;
	for(i=VIDEOCHOIX1;i<=VIDEOCHOIX6;i++)
	{
		if(rs_object[i].ob_state & SELECTED)
			objc_change(rs_object,i,0,work,NORMAL,1);
	}
}

void display_rez(int flag,GRECT *work)
{
	TEDINFO *t_edinfo;
	register int i,j;
	long value;
	if(flag)
	{
		display_slider(work);
		select_normal_rez(work);
	}
	for(i=VIDEOCHOIX1,j=offset_select;i<=VIDEOCHOIX6;i++,j++)
	{
		t_edinfo=rs_object[i].ob_spec.tedinfo;
		if(j<nb_res)
		{
			copy_string(liste_rez[j].name,t_edinfo->te_ptext);
			rs_object[i].ob_flags |= TOUCHEXIT;
			rs_object[i].ob_state=liste_rez[j].state;
		}
		else
		{ 
			t_edinfo->te_ptext="                      ";
			rs_object[i].ob_flags &= ~TOUCHEXIT;
			rs_object[i].ob_state=NORMAL;
		}
		if(flag)
			objc_draw(rs_object,i,2,work);		
	}
}

CPXNODE* get_header(long id)
{
	register CPXNODE *p;
	p=(CPXNODE *)(*Xcpb->Get_Head_Node)();	/* header 1st CPX */
	do
	{
		if(p->cpxhead.cpx_id==id)
			return(p);
	}
	while(p->vacant && (p=p->next)!=0);		/* no more headers */
	return(0L);
}

int modif_sys(LISTE_RES *r)
{
	static char path_fvdi[]="C:\\fvdi.sys";
	static char choice[64];
	static char line[256];
	void *sauve_ssp;
	char *buffer,*p,*p2;
	register int handle;
	register long err;
	long size,offset,i;
	int ok=0;
	sprintf(choice,"%dx%dx%d@%d",r->width_screen,r->height_screen,1<<(r->modecode & NUMCOLS),r->vert_freq);
	graf_mouse(HOURGLASS,(MFORM*)0);
	sauve_ssp=(void *)Super(0L);
	path_fvdi[0]=(char)*(int *)0x446+'A';		/* boot drive */
	Super(sauve_ssp);
	if((err=(long)(handle=Fopen(path_fvdi,FO_RW)))>=0)
	{
		if((err=size=Fseek(0L,handle,2))>=0
		 && (err=Fseek(0L,handle,0))>=0)
		{
			if((err=(long)(buffer=Malloc(size+1)))>=0)
			{
				buffer[size]='\0';
				if((err=Fread(handle,size,buffer))>=0)
				{
					p=strstr(buffer," radeon.sys");
					if(p!=NULL)
					{
						p+=11;
						p2=strchr(p,'\n');
						if(p2==NULL)
							p2=strchr(p,'\r');
						if((p2!=NULL) && ((long)(p2-p) < 256L))
						{
							long length=(long)(p2-p);
							memcpy(line,p,length); /* radeon.sys parameters */
							line[length]='\0';
							p2=strstr(line," mode ");
							if(p2!=NULL)
							{
								p2+=6;
								while(*p2==' ');
									p2++;
								p2--;
								offset=(long)(p2-line);
								if((err=Fseek((long)(p-buffer)+offset,handle,0))>=0)
								{
									long len=0;
									long new_len=strlen(choice);
									while((*p2!=' ') && (*p2!='\r') && (*p2!='\n'))
									{
										p2++;
										offset++;
										len++;
									}
									for(i=new_len;i<len;choice[i++]=' ');
									choice[i]='\0';
									p+=offset;
									if((err=Fwrite(handle,strlen(choice),choice))>=0)
									{
										if((err=Fwrite(handle,size-(long)(p-buffer),p))>=0)
											ok=1;
									}
								}
							}
						}
					}
				}
				Mfree(buffer);
			}
		}
		if(err<0)
			Fclose(handle);
		else
			err=(long)Fclose(handle);
	}
	if(err<0)
		display_error((int)err);
	graf_mouse(ARROW,(MFORM*)0);
	return(ok);
}

int modif_inf(int modecode)
{
	static char path_desk[]="C:\\newdesk.inf";
	static char path_magic[]="C:\\magx.inf";
	static char path_myaes[]="C:\\gemsys\\myaes\\myaes.cnf";
	static char path_xaaes[]="C:\\video.cnf";
	static char path_inf[16];
	static char string[32];
	void *sauve_ssp,*buffer;
	char *p;
	register int handle,i;
	register long err,size;
	long value;
	int ok,old_modecode,magic,myaes,lg=0;
	ok=0;
	graf_mouse(HOURGLASS,(MFORM*)0);
	if(get_cookie('nAES') != NULL)
	{
		copy_string(path_xaaes,path_inf);
		sauve_ssp=(void *)Super(0L);
		path_inf[0]=(char)*(int *)0x446+'A';		/* boot drive */
		Super(sauve_ssp);
		if((err=(long)(handle=Fcreate(path_inf,0)))>=0)
		{
			sprintf(string,"video = %d\r\n",modecode);
			err=Fwrite(handle,strlen(string),string);
			Fclose(handle);
		}
		if(err<0)
		{
			if(!start_lang)
				form_alert(1,"[1][Erreur pour ‚crire|le fichier VIDEO.CNF][Annuler]");
			else
				form_alert(1,"[1][Error for write|the file VIDEO.CNF][Cancel]");
		}
	}
	if(get_cookie('MAS2') != NULL)
	{
		myaes=1;
		magic=0;
		copy_string(path_myaes,path_inf);
	}
	else
	{
		myaes=0;
		if(get_cookie('MagX') != NULL)
		{
			magic=1;
			copy_string(path_magic,path_inf);
		}
		else
		{
			magic=0;
			copy_string(path_desk,path_inf);
		}
	}
	sauve_ssp=(void *)Super(0L);
	path_inf[0]=(char)*(int *)0x446+'A';		/* boot drive */
	Super(sauve_ssp);
	if((err=(long)(handle=Fopen(path_inf,FO_RW)))>=0)
	{
		if((err=size=Fseek(0L,handle,2))>=0
		 && (err=Fseek(0L,handle,0))>=0)
		{
			if((err=(long)(buffer=Malloc(size)))>=0)
			{
				if((err=Fread(handle,size,buffer))>=0)
				{
					p=(char *)buffer;
					if(myaes)
					{
						while(p<(char *)((long)buffer+size)
						 && !(p[0]=='M' && p[1]=='Y' && p[2]=='A' && p[3]=='E' && p[4]=='S' && p[5]=='_' && p[6]=='V'
						  && p[7]=='s' && p[8]=='e' && p[9]=='t' && p[10]=='M' && p[11]=='o' && p[12]=='d' && p[13]=='e' && p[14]=='='))
							p++;					/* search screen descriptor */
						if(p<(char *)((long)buffer+size))
						{
							p+=15;
							if((err=Fseek((long)(p-buffer),handle,0))>=0)
							{
								old_modecode=val_string(p);
								sprintf(string,"%d",modecode);
								if(modecode!=old_modecode)
								{
									int new_len = strlen(string);
									int len = long_deci(p,&lg);	/* modecode */
									for(i=new_len;i<len;string[i++]=' ');
									string[i]='\0';
									p+=len;
									if((err=Fwrite(handle,strlen(string),string))>=0)
									{
										if((err=Fwrite(handle,size-(long)(p-buffer),p))>=0)
											ok=1;
									}
								}
							}
						}
						else
						{
							if(!start_lang)
								form_alert(1,"[1][Erreur dans le|fichier MYAES.CNF][Annuler]");
							else
								form_alert(1,"[1][Error inside the|file MYAES.CNF][Cancel]");
						}		
					}
					else if(magic)
					{
						while(p<(char *)((long)buffer+size)
						 && !(p[0]=='_' && p[1]=='D' && p[2]=='E' && p[3]=='V'))
							p++;					/* search screen descriptor */
						if(p<(char *)((long)buffer+size))
						{
							p+=4;
							if((err=Fseek((long)(p-buffer),handle,0))>=0)
							{
								long_deci(p,&lg);	/* video mode 5 for FALCON */
								p+=lg;
								old_modecode=val_string(p);
								if(modecode!=old_modecode)
								{
									long_deci(p,&lg);	/* modecode */
									p+=lg;
									if((err=Fwrite(handle,3," 5 "))>=0)
									{
										sprintf(string,"%d",modecode);
										if((err=Fwrite(handle,long_deci(string,&lg),string))>=0)
										{
											if((err=Fwrite(handle,size-(long)(p-buffer),p))>=0)
												ok=1;
										}
									}
								}
							}
						}
						else
						{
							if(!start_lang)
								form_alert(1,"[1][Erreur dans le|fichier MAGX.INF][Annuler]");
							else
								form_alert(1,"[1][Error inside the|file MAGX.INF][Cancel]");
						}
					}
					else
					{
						while(p<(char *)((long)buffer+size)
						 && !(p[0]=='#' && p[1]=='E'))
							p++;					/* search screen descriptor */
						if(p<(char *)((long)buffer+size))
						{
							p+=3;					/* 1st data hexa */
							for(i=0;i<4 && p[-1]==' ' && read_hexa(p)!=-1;i++,p+=3);
							if(i==4 && p[-1]==' ' && p[2]==' '
							 && (old_modecode=(read_hexa(p)<<8) | read_hexa(p+3))!=-1)
							{
								if(modecode!=old_modecode)
								{
									write_hexa(modecode>>8,p);
									p+=3;
									write_hexa(modecode,p);
									if((err=Fseek(0L,handle,0))>=0)
									{
										if((err=Fwrite(handle,size,buffer))>=0)
											ok=1;
									}
								}
							}
						}
						else
						{
							if(!start_lang)
								form_alert(1,"[1][Erreur dans le|fichier NEWDESK.INF][Annuler]");
							else
								form_alert(1,"[1][Error inside the|file NEWDESK.INF][Cancel]");
						}
					}
				}
				Mfree(buffer);
			}
		}
		if(err<0)
			Fclose(handle);
		else
			err=(long)Fclose(handle);
	}
	if(err<0)
		display_error((int)err);
	graf_mouse(ARROW,(MFORM*)0);
	return(ok);
}

int read_hexa(char *p)
{
	return((ascii_hexa(p)<<4) | ascii_hexa(p+1));
}

int ascii_hexa(char *p)
{
	register int val;
	if((val=p[0]-'0')<0)
		return(-1);
	if(val>9)
	{
		val-=7;
		if(val<10 || val>15)
			return(-1);
	}
	return(val);
}	

void write_hexa(int val,char *p)
{
	val&=0xff;
	hexa_ascii(val>>4,p++);
	hexa_ascii(val & 0xf,p);
}

void hexa_ascii(int val,char *p)
{
	val&=0xf;
	val+='0';
	if(val>'9')
		val+=7;
	*p=(char)val;
}

void display_error(int error)
{
	if(error<0)
	{
		switch(error)
		{
		case -33:
			(*Xcpb->XGen_Alert)(FILE_NOT_FOUND);
			break;
		case -39:
		case -35:
		case -40:
		case -67:
			(*Xcpb->XGen_Alert)(MEM_ERR);
			break;
		default:
			(*Xcpb->XGen_Alert)(FILE_ERR);
		}
	}
}

int get_MagiC_ver(unsigned long *crdate)
{
	long value;
	AESVARS *av;
	COOKIE *p;
	if((p = get_cookie('MagX')) == NULL)
		return(0);
	av = ((MAGX_COOKIE *)p->v.l)->aesvars;
	if(av == NULL)
		return(0);
	if(crdate)
	{
		*crdate = av->date << 16L;
		*crdate |= av->date >> 24L;
		*crdate |= (av->date >> 8L) & 0xff00L;		/* yyyymmdd */
	}
	return(av->version);
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

long physbase_videl(void)
{
	unsigned long physaddr = (unsigned long)(*(unsigned char *)0xFFFF8201); /* video screen memory position, high byte */
	physaddr <<= 8;
	physaddr |= (unsigned long)(*(unsigned char *)0xFFFF8203); /* mid byte */
	physaddr <<= 8;
	physaddr |= (unsigned long)(*(unsigned char *)0xFFFF820D); /* low byte */
	return((long)physaddr);
}

int find_radeon(void)
{
	unsigned long temp;
	short index;
	long handle,err;
	unsigned long physaddr;
	struct pci_device_id *radeon;
	if(get_cookie('_PCI') == NULL)
		return(0);
	physaddr = (unsigned long)Physbase();
	if((physaddr < 0x1000000UL) && (physaddr == (unsigned long)Supexec(physbase_videl)))
		return(0);
	index=0;
	do
	{
		handle = find_pci_device(0x0000FFFFL,index++);
		if(handle >= 0)
		{
			err = read_config_longword(handle,PCIIDR,&temp);
			/* test Radeon ATI devices */
			if(err >= 0)
			{
				radeon = radeonfb_pci_table; /* compare table */
				while(radeon->vendor)
				{
					if((radeon->vendor == (temp & 0xFFFF))
					 && (radeon->device == (temp >> 16)))
						return(1);
					radeon++;
				}
			}
		}
	}
	while(handle>=0);
	return(0);
}	

int copy_string(char *p1,char *p2)
{
	register int i=0;
	while((*p2++ = *p1++)!=0)
		i++;
	return(i);
}

int long_deci(char *p,int *lg)
{
	register int i=0;
	*lg=0;
	while((*p>='0' && *p<='9') || (!i && *p==' '))
	{
		if(*p!=' ')
			i++;
		p++;
		(*lg)++;	/* number of characters */
	}
	return(i);		/* number of digits */
}

int val_string(char *p)
{
	static int tab_mul_10[5]={10000,1000,100,10,1};
	register int lg=0,i,j;
	register int *range;
	while(p[lg]>='0' && p[lg]<='9')
		lg++;
	if(!lg)
		return(0);
	range = &tab_mul_10[5-lg];
	for(i=j=0;j<lg;i+=(((int)p[j] & 0xf) * range[j]),j++);
	return(i);
}

long tempo_5S(void)
{
	unsigned long 	start_time;
	start_time	=*(unsigned long *)0x4BA;
	while(((*(unsigned long *)0x4BA) - start_time) <= 1000);
	return(0);
}

void reboot(void)
{
	EVNTDATA mouse;
	do
		graf_mkstate(&mouse);				/* wait end of clic */
	while(mouse.bstate);
	Super(0L);								/* supervisor state */
	reset=(void (*)())*(void **)0x4;		/* reset vector */
	(*reset)();								/* reset system */
}
