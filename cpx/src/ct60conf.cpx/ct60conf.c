/* CT60 CONFiguration - Pure C */
/* Didier MEQUIGNON - v0.99d - August 2003 */

#include <portab.h>
#include <tos.h>
#include <vdi.h>
#include <mt_aes.h>
#include <cpx.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "ct60.h"

/* #define LIGHT */					/* without language & video */
/* #define BUBBLEGEM_RIGHTCLIC */	/* not works with COPS :-( */
/* #define ALERT_INSTALL_CT60TEMP */
/* #define DEBUG */
/* #define TEST */
/* #define TEST_MAGICMAC */

#define ID_CPX (long)'CT60'
#define VA_START 0x4711
#define BUBBLEGEM_SHOW 0xbabb
#define BUBBLEGEM_ACK 0xbabc
#define ITIME 1000L	/* mS */
#define MAX_CPULOAD 10000
#define MAX_TEMP 90

#define KER_GETINFO 0x0100

#define SHW_THR_CREATE	20
#define SHW_THR_EXIT	21
#define SHW_THR_KILL	22

#define PAGE_CPULOAD 0
#define PAGE_TEMP 1
#define PAGE_MEMORY 2
#define PAGE_BOOT 3
#define PAGE_STOP 4
#define PAGE_LANG 5
#define PAGE_VIDEO 6

#define NO_STOP 0
#define MONDAY_STOP 1
#define TUESDAY_STOP 2
#define WEDNESDAY_STOP 3
#define THURSDAY_STOP 4
#define FRIDAY_STOP 5
#define SATURDAY_STOP 6
#define SUNDAY_STOP 7
#define WORKDAY_STOP 8
#define WEEKEND_STOP 9
#define EVERYDAY_STOP 10

#define Suptime(uptime,avenrun) gemdos(0x13f,(long)(uptime),(long)(avenrun))

typedef struct
{
	unsigned int bootpref;
	unsigned char language;
	unsigned char keyboard;
	unsigned char datetime;
	char separator;
	unsigned char bootdelay;
	unsigned int vmode;
	unsigned char scsi;
	unsigned char tosram;
	unsigned int trigger_temp;
	unsigned int daystop;
	unsigned int timestop;
	unsigned char blitterspeed;
	unsigned char cachedelay;
	unsigned char bootorder;
} HEAD;

typedef struct
{
	unsigned int bootpref;
	char reserved[4];
	unsigned char language;
	unsigned char keyboard;
	unsigned char datetime;
	char separator;
	unsigned char bootdelay;
	char reserved2[3];
	unsigned int vmode;
	unsigned char scsi;
} NVM;

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

/* prototypes */

int CDECL cpx_call(GRECT *work);
void CDECL cpx_draw(GRECT *clip);
void CDECL cpx_wmove(GRECT *work);
void CDECL cpx_timer(int *event);
void CDECL cpx_key(int kstate,int key,int *event);
void CDECL cpx_button(MRETS *mrets,int nclicks,int *event);
int CDECL cpx_hook(int event,WORD *msg,MRETS *mrets,int *key,int *nclicks);
void CDECL cpx_close(int flag);
int init_rsc(void);
OBJECT* adr_tree(int num_tree);
int cdecl trace_temp(PARMBLK *parmblock);
int cdecl cpu_load(PARMBLK *parmblock);
CPXNODE* get_header(long id);
HEAD *fix_header(void);
void save_header(void);
void display_selection(int selection,int flag_aff);
void change_objc(int objc,int state,GRECT *clip);
void display_objc(int objc,GRECT *clip);
void move_cursor(void);
int hndl_form(OBJECT *tree,int objc);
int MT_form_xalert(int fo_xadefbttn,char *fo_xastring,long time_out,void (*call)(),WORD *global);
void (*function)(void);
void display_erreur(int err);
void bubble_help(void);
void call_st_guide(void);
long cdecl temp_thread(unsigned int *param);
int start_temp(unsigned int *param1,unsigned int *param2,unsigned int *param3);
int start_ct60temp(unsigned int *param1,unsigned int *param2,unsigned int *param3);
int send_ask_temp(void);
int test_stop(unsigned long daytime,unsigned int daystop,unsigned int timestop); 
int dayofweek(int year,int mon,int mday);
void bip(void);
void stop_60(void);
int read_temp(void);
int fill_tab_temp(void);
unsigned long bogomips(void);
void delay_loop(long loops);
int get_MagiC_ver(unsigned long *crdate);
COOKIE *fcookie(void);
COOKIE *ncookie(COOKIE *p);
COOKIE *get_cookie(long id);
int add_cookie(COOKIE *cook);
int test_060(void);
void reboot(void);
void (*reset)(void);
extern long ct60_read_temp(void);
extern long ct60_stop(void);
extern long mes_delay(void);
extern long ct60_rw_param(int mode,long type_param,long value);

/* global variables in the 1st position of DATA segment */

HEAD config={0,2,2,0x11,'/',1,0x1b2,0x87,0,50,0,0};

#include "ct60temp.hex"

/* global variables */

int vdi_handle,work_in[11]={1,1,1,1,1,1,1,1,1,1,2},work_out[57];
int errno;
WORD global[15];
int gr_hwchar,gr_hhchar;
int	ap_id=-1,temp_id=-1,wi_id=-1;
int mint,magic,flag_cpuload,flag_xbios,thread=0,time_out_thread=-1,time_out_bubble=-1;
unsigned long magic_date,st_ram,fast_ram,loops_per_sec=0;
char *eiffel_temp=NULL;
extern unsigned long value_supexec;
XCPB *Xcpb;
GRECT *Work;
CPXNODE *head;
CPXINFO	cpxinfo={cpx_call,cpx_draw,cpx_wmove,cpx_timer,cpx_key,cpx_button,0,0,cpx_hook,cpx_close};
NVM nvram;
USERBLK spec_trace={0,0};
USERBLK spec_cpuload={0,0};
int ed_objc,new_objc,ed_pos,new_pos;
int start_lang,flag_bubble,selection;
int language,keyboard,datetime,vmode,bootpref,bootdelay,scsi,tosram,blitterspeed,cachedelay,bootorder;
unsigned int trigger_temp,daystop,timestop;
char *buffer_bubble=0;
char *buffer_path=0;
unsigned short tab_temp[61],tab_temp_eiffel[61],tab_cpuload[61];

/* ressource */

#define MENUBOX 0
#define MENUBSELECT 3
#define MENUBOXSTATUS 5
#define MENUTEMP 7
#define MENUBARTEMP 8
#define MENUTRIGGER 12
#define MENUTRACE 13
#define MENUSTATUS 18
#define MENUBOXRAM 19
#define MENUSTRAMTOT 21
#define MENUFASTRAMTOT 23
#define MENUSTRAM 25
#define MENUFASTRAM 27
#define MENUMIPS 28
#define MENURAM 29
#define MENUBOXLANG 30
#define MENUBLANG 32
#define MENUBKEY 34
#define MENUBDATE 36
#define MENUBTIME 38
#define MENUSEP 39
#define MENULANG 40
#define MENUBOXVIDEO 41
#define MENUBVIDEO 43
#define MENUBMODE 45
#define MENUBCOUL 47
#define MENUBRES 49
#define MENUSTMODES 50
#define MENUOVERSCAN 51
#define MENUVIDEO 52
#define MENUBOXBOOT 53
#define MENUBBOOTORDER 54
#define MENUBOS 56
#define MENUBARBIT 58
#define MENUBIDSCSI 60
#define MENUDELAY 61
#define MENUBBLITTER 63
#define MENUBTOSRAM 65
#define MENUBCACHE 67
#define MENUBOOT 68
#define MENUBOXSTOP 69
#define MENUBDAY 71
#define MENUTIME 72
#define MENUSTOP 73

#define MENUBSAVE 74
#define MENUBLOAD 75
#define MENUBOK 76
#define MENUBCANCEL 77
#define MENUBINFO 78

#define INFOBOX 0
#define INFOLOGO 1
#define INFOOK 13
#define INFOHELP 14

#define ALERTBOX 0
#define ALERTTITLE 1
#define ALERTNOTE 2
#define ALERTWAIT 3
#define ALERTSTOP 4
#define ALERTLINE1 5
#define ALERTLINE2 6
#define ALERTLINE3 7
#define ALERTLINE4 8
#define ALERTLINE5 9
#define ALERTB1 10
#define ALERTB2 11
#define ALERTB3 12

#define OFFSETTLV 1
#define OFFSETOK 2
#define OFFSETCANCEL 3

char *rs_strings[] = {
	"CT60 Configuration","","",
	"S‚lection:",
	"Temp‚rature","","",
	" Temp‚rature ","","",
	"Tø 60:",
	"xxx øC","","",
	"12","Seuil: __","99",
	"00:00 00:10 00:20 00:30 00:40 00:50 01:00","","",
	"80","","",
	"40","","",
	"0ø","","",
	" M‚moire / æP ","","",
	"Total ST-Ram:",
	"uuuuuuuuu octets",
	"Total Fast-Ram:",
	"vvvvvvvvv octets",
	"ST-Ram libre:",
	"yyyyyyyyy octets","","",
	"Fast-Ram libre:",
	"zzzzzzzzz octets","","",
	"æP:   0.00 Mips     0000 tr/mn","","",
	" Langage ","","",
	"Langage:",
	"Fran‡ais","","",
	"Clavier:",
	"France","","",
	"Format date:",
	"DD/MM/YY","","",
	"Temps:",
	"24","","",
	"/","S‚parateur: _","X",
	" Vid‚o (boot) ","","",
	"Vid‚o:",
	"VGA","","",
	"Mode:",
	"PAL","","",
	"Couleurs:",
	"65536","","",
	"R‚solution:",
	"320x200","","",
	"Mode ST",
	"Overscan",
	" Boot ","","",
	"IDE->SCSI","","",
	"OS:",
	"TOS","","",
	"SCSI arbitration:",
	"Oui","","",
	"ID:",
	"7","","",
	"10","D‚lais: __ S","99",
	"Blitter:",
	"Lent","","",
	"TOS en RAM:",
	"Non","","",
	"TOS:",
	"Normal","","",
	" Arrˆt ","","",
	"Arrˆt programm‚:",
	"Sans","","",
	"2359","…: __:__","9999",
	
	"Sauve",
	"Charge",
	"OK",
	"Annule",
	
	"CT60 Configuration V0.99d Aout 2003","","",
	"Ce CPX et systŠme:","","",
	"Didier MEQUIGNON","","",
	"didier-mequignon@wanadoo.fr","","",
	"SystŠme:","","",
	"Xavier JOUBERT","","",
	"xavier.joubert@free.fr","","",
	"Hardware:","","",
	"Rodolphe CZUBA","","",
	"rczuba@free.fr","","",
	"http://www.czuba-tech.com","","",
	"OK",
	"Aide",
	
	"CT60 Temp‚rature","","",
	"line1",
	"line2",
	"line3",
	"line4",
	"line5",
	"button1",
	"button2",
	"button3",
	
	"-00","Offset TLV 2.8øC/unit: ___ unit","X99",
	"OK",
	"Annule" };

char *rs_strings_en[] = {
	"CT60 Configuration","","",
	"Selection:",
	"Temperature","","",
	" Temperature ","","",
	"Tø 60:",
	"xxx øC","","",
	"34","Thres: __","99",
	"00:00 00:10 00:20 00:30 00:40 00:50 01:00","","",
	"80","","",
	"40","","",
	"0ø","","",
	" Memory / æP ","","",
	"Total ST RAM:",
	"uuuuuuuuu bytes",
	"Total Fast RAM:",
	"vvvvvvvvv bytes",	
	"ST RAM free:",
	"yyyyyyyyy bytes","","",
	"Fast RAM free:",
	"zzzzzzzzz bytes","","",
	"æP:   0.00 Mips     0000 tr/mn","","",
	" Language ","","",
	"Language:",
	"English","","",
	"Keyboard:",
	"England","","",
	"Date format:",
	"DD/MM/YY","","",
	"Time:",
	"24","","",
	"/","Separator: _","X",
	" Video (boot) ","","",
	"Video:",
	"VGA","","",
	"Mode:",
	"PAL","","",
	"Colors:",
	"65536","","",
	"Resolution:",
	"320x200","","",
	"Mode ST",
	"Overscan",
	" Boot ","","",
	"IDE->SCSI","","",
	"OS:",
	"TOS","","",
	"SCSI arbitration:",
	"Yes","","",
	"ID:",
	"7","","",
	"10","Delay: __ S","99",
	"Blitter:",
	"Slow","","",
	"TOS in RAM:",
	"No","","",
	"TOS:",
	"Normal","","",
	" Stop ","","",
	"Stop programmed:",
	"Without","","",
	"2359","at: __:__","9999",
	
	"Save",
	"Load",
	"OK",
	"Cancel",

	"CT60 Configuration V0.99d August 2003","","",
	"This CPX and system:","","",
	"Didier MEQUIGNON","","",
	"didier-mequignon@wanadoo.fr","","",
	"System:","","",
	"Xavier JOUBERT","","",
	"xavier.joubert@free.fr","","",
	"Hardware:","","",
	"Rodolphe CZUBA","","",
	"rczuba@free.fr","","",
	"http://www.czuba-tech.com","","",
	"OK",
	"Help",
	
	"CT60 Temperature","","",
	"line1",
	"line2",
	"line3",
	"line4",
	"line5",
	"button1",
	"button2",
	"button3"
	
	"-00","Offset TLV 2.8øC/unit: ___ unit","X99",
	"OK",
	"Cancel" };

long rs_frstr[] = {0};

BITBLK rs_bitblk[] = {
	(int *)0L,36,72,0,0,2,
	(int *)1L,4,32,0,0,1,
	(int *)2L,4,32,0,0,4,
	(int *)3L,4,32,0,0,2 };

long rs_frimg[] = {0};
ICONBLK rs_iconblk[] = {0};

TEDINFO rs_tedinfo[] = {
	(char *)0L,(char *)1L,(char *)2L,IBM,0,2,0x1180,0,0,32,1,
	(char *)4L,(char *)5L,(char *)6L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)7L,(char *)8L,(char *)9L,IBM,0,2,0x1180,0,0,14,1,
	(char *)11L,(char *)12L,(char *)13L,IBM,0,0,0x1180,0,0,7,1,
	(char *)14L,(char *)15L,(char *)16L,IBM,0,0,0x1180,0,0,3,10,
	(char *)17L,(char *)18L,(char *)19L,SMALL,0,2,0x1180,0,0,42,1,
	(char *)20L,(char *)21L,(char *)22L,SMALL,0,2,0x1180,0,0,3,1,
	(char *)23L,(char *)24L,(char *)25L,SMALL,0,2,0x1180,0,0,3,1,
	(char *)26L,(char *)27L,(char *)28L,SMALL,0,2,0x1180,0,0,3,1,
	(char *)29L,(char *)30L,(char *)31L,IBM,0,2,0x1180,0,0,15,1,
	(char *)37L,(char *)38L,(char *)39L,IBM,0,0,0x1180,0,0,16,1,
	(char *)41L,(char *)42L,(char *)43L,IBM,0,0,0x1180,0,0,16,1,
	(char *)44L,(char *)45L,(char *)46L,IBM,0,0,0x1180,0,0,16,1,
	(char *)47L,(char *)48L,(char *)49L,IBM,0,2,0x1180,0,0,9,1,
	(char *)51L,(char *)52L,(char *)53L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)55L,(char *)56L,(char *)57L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)59L,(char *)60L,(char *)61L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)63L,(char *)64L,(char *)65L,IBM,0,2,0x1180,0,-1,4,1,	
	(char *)66L,(char *)67L,(char *)68L,IBM,0,0,0x1180,0,0,2,14,
	(char *)69L,(char *)70L,(char *)71L,IBM,0,2,0x1180,0,0,9,1,
	(char *)73L,(char *)74L,(char *)75L,IBM,0,2,0x1180,0,-1,8,1,
	(char *)77L,(char *)78L,(char *)79L,IBM,0,2,0x1180,0,-1,8,1,
	(char *)81L,(char *)82L,(char *)83L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)85L,(char *)86L,(char *)87L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)90L,(char *)91L,(char *)92L,IBM,0,2,0x1180,0,0,6,1,
	(char *)93L,(char *)94L,(char *)95L,IBM,0,2,0x1180,0,-1,10,1,
	(char *)97L,(char *)98L,(char *)99L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)101L,(char *)102L,(char *)103L,IBM,0,2,0x1180,0,-1,5,1,
	(char *)105L,(char *)106L,(char *)107L,IBM,0,2,0x1180,0,-1,3,1,		
	(char *)108L,(char *)109L,(char *)110L,IBM,0,0,0x1180,0,0,3,13,
	(char *)112L,(char *)113L,(char *)114L,IBM,0,2,0x1180,0,-1,7,1,
	(char *)116L,(char *)117L,(char *)118L,IBM,0,2,0x1180,0,-1,4,1,
	(char *)120L,(char *)121L,(char *)122L,IBM,0,2,0x1180,0,-1,8,1,
	(char *)123L,(char *)124L,(char *)125L,IBM,0,2,0x1180,0,0,14,1,
	(char *)127L,(char *)128L,(char *)129L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)130L,(char *)131L,(char *)132L,IBM,0,0,0x1180,0,0,5,10,

	(char *)137L,(char *)138L,(char *)139L,IBM,0,2,0x1480,0,0,38,1,
	(char *)140L,(char *)141L,(char *)142L,IBM,0,2,0x1180,0,0,38,1,
	(char *)143L,(char *)144L,(char *)145L,IBM,0,2,0x1180,0,0,38,1,
	(char *)146L,(char *)147L,(char *)148L,IBM,0,2,0x1180,0,0,38,1,
	(char *)149L,(char *)150L,(char *)151L,IBM,0,2,0x1180,0,0,38,1,
	(char *)152L,(char *)153L,(char *)154L,IBM,0,2,0x1180,0,0,38,1,
	(char *)155L,(char *)156L,(char *)157L,IBM,0,2,0x1180,0,0,38,1,
	(char *)158L,(char *)159L,(char *)160L,IBM,0,2,0x1180,0,0,38,1,
	(char *)161L,(char *)162L,(char *)163L,IBM,0,2,0x1180,0,0,38,1,
	(char *)164L,(char *)165L,(char *)166L,IBM,0,2,0x1180,0,0,38,1,
	(char *)167L,(char *)168L,(char *)169L,IBM,0,2,0x1180,0,0,38,1,

	(char *)172L,(char *)173L,(char *)174L,IBM,0,2,0x1480,0,-1,17,1,
	
	(char *)183L,(char *)184L,(char *)185L,IBM,0,0,0x1180,0,0,4,32 };
	
OBJECT rs_object[] = {
	-1,1,78,G_BOX,FL3DBAK,NORMAL,0x1100L,0,0,32,11,
	2,-1,-1,G_TEXT,FL3DBAK,SELECTED,0L,0,0,32,1,
	3,-1,-1,G_STRING,NONE,NORMAL,3L,1,1,14,1,
	4,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,1L,16,1,15,1,								/* popup selection */
	5,-1,-1,G_BOX,FL3DBAK,NORMAL,0x1100L,1,2,14,1,
	18,6,17,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* state box */
	7,-1,-1,G_STRING,NONE,NORMAL,10L,1,1,6,1,
	8,-1,-1,G_TEXT,FL3DBAK,NORMAL,3L,8,1,6,1,										/* temperature */
	12,9,11,G_BOX,NONE,NORMAL,0xff11f1L,15,1,6,1,
	10,-1,-1,G_BOX,NONE,NORMAL,0x11f3L,0,0,2,1,										/* green */
	11,-1,-1,G_BOX,NONE,NORMAL,0x11f6L,2,0,2,1,										/* yellow */
	8,-1,-1,G_BOX,NONE,NORMAL,0x11f2L,4,0,2,1,										/* red */
	13,-1,-1,G_FTEXT,EDITABLE|TOUCHEXIT|FL3DBAK,NORMAL,4L,22,1,9,1,					/* threshold */
	14,-1,-1,G_BOX,NONE,NORMAL,0L,1,2,30,4,											/* trace */
	15,-1,-1,G_TEXT,FL3DBAK,NORMAL,5L,1,6,31,1,
	16,-1,-1,G_TEXT,FL3DBAK,NORMAL,6L,0,2,3,1,
	17,-1,-1,G_TEXT,FL3DBAK,NORMAL,7L,0,4,3,1,
	5,-1,-1,G_TEXT,FL3DBAK,NORMAL,8L,0,5,3,1,
	19,-1,-1,G_TEXT,FL3DBAK,NORMAL,2L,1,2,13,1,
	29,20,28,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* memory box */
	21,-1,-1,G_STRING,NONE,NORMAL,32L,1,1,15,1,
	22,-1,-1,G_STRING,NONE,NORMAL,33L,16,1,16,1,									/* total ST-Ram */
	23,-1,-1,G_STRING,NONE,NORMAL,34L,1,2,15,1,
	24,-1,-1,G_STRING,NONE,NORMAL,35L,16,2,16,1,									/* total Fast-Ram */	
	25,-1,-1,G_STRING,NONE,NORMAL,36L,1,3,15,1,
	26,-1,-1,G_TEXT,FL3DBAK,NORMAL,10L,16,3,16,1,									/* free ST-Ram */
	27,-1,-1,G_STRING,NONE,NORMAL,40L,1,4,15,1,
	28,-1,-1,G_TEXT,FL3DBAK,NORMAL,11L,16,4,16,1,									/* free Fast-Ram */
	19,-1,-1,G_TEXT,/* TOUCHEXIT| */ FL3DBAK,NORMAL,12L,1,5,30,1,					/* Mips & tr/mn */
	30,-1,-1,G_TEXT,FL3DBAK,NORMAL,9L,1,2,14,1,
	40,31,39,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* language box */
	32,-1,-1,G_STRING,NONE,NORMAL,50L,1,1,15,1,
	33,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,14L,16,1,15,1,							/* popup language */
	34,-1,-1,G_STRING,NONE,NORMAL,54L,1,2,15,1,
	35,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,15L,16,2,15,1,							/* popup keyboard */
	36,-1,-1,G_STRING,NONE,NORMAL,58L,1,3,15,1,
	37,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,16L,16,3,15,1,							/* popup date format */
	38,-1,-1,G_STRING,NONE,NORMAL,62L,1,5,7,1,
	39,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,17L,8,5,3,1,								/* popup time format */
	30,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,18L,16,5,14,1,
	41,-1,-1,G_TEXT,FL3DBAK,NORMAL,13L,1,2,10,1,
	52,42,51,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* video box */
	43,-1,-1,G_STRING,NONE,NORMAL,72L,1,1,7,1,
	44,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,20L,8,1,7,1,								/* popup video TV/VGA */
	45,-1,-1,G_STRING,NONE,NORMAL,76L,16,1,7,1,
	46,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,21L,24,1,7,1,								/* popup mode NTSC/PAL */
	47,-1,-1,G_STRING,NONE,NORMAL,80L,1,2,15,1,
	48,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,22L,16,2,15,1,							/* popup colors */
	49,-1,-1,G_STRING,NONE,NORMAL,84L,1,3,15,1,
	50,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,23L,16,3,15,1,							/* popup resolution */
	51,-1,-1,G_BUTTON,SELECTABLE|TOUCHEXIT|FL3DIND,NORMAL,88L,1,5,14,1,
	41,-1,-1,G_BUTTON,SELECTABLE|TOUCHEXIT|FL3DIND,NORMAL,89L,16,5,15,1,
	53,-1,-1,G_TEXT,FL3DBAK,NORMAL,19L,1,2,14,1,
	68,54,67,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* boot box */
	55,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,25L,1,1,9,1,								/* popup boot order */
	56,-1,-1,G_STRING,NONE,NORMAL,96L,12,1,3,1,
	57,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,26L,16,1,15,1,							/* popup favourite OS */
	58,-1,-1,G_STRING,NONE,NORMAL,100L,1,2,17,1,
	59,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,27L,18,2,4,1,								/* popup arbitration */
	60,-1,-1,G_STRING,NONE,NORMAL,104L,24,2,3,1,
	61,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,28L,28,2,2,1,								/* popup ID SCSI */
	62,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,29L,1,3,13,1,
	63,-1,-1,G_STRING,NONE,NORMAL,111L,15,3,8,1,
	64,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,30L,24,3,6,1,								/* popup speed blitter */
	65,-1,-1,G_STRING,NONE,NORMAL,115L,1,5,11,1,
	66,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,31L,12,5,4,1,								/* popup transfer TOS in RAM */
	67,-1,-1,G_STRING,NONE,NORMAL,119L,18,5,4,1,
	53,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,32L,23,5,7,1,								/* popup TOS cache delay */
	69,-1,-1,G_TEXT,FL3DBAK,NORMAL,24L,1,2,6,1,
	73,70,72,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* stop box */
	71,-1,-1,G_STRING,NONE,NORMAL,126L,1,1,15,1,
	72,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,34L,16,1,15,1,							/* popup stop */
	69,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,35L,1,3,13,1,							/* time */
	74,-1,-1,G_TEXT,FL3DBAK,NORMAL,33L,1,2,6,1,

	75,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,133L,1,9,5,1,			/* Save */
	76,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,134L,8,9,6,1,			/* Load */
	77,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,135L,16,9,3,1,			/* OK */
	78,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|FL3DIND|FL3DBAK,NORMAL,136L,21,9,6,1,	/* Cancel */
	0,-1,-1,G_BOXCHAR,SELECTABLE|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,0x69ff1100L,29,9,2,1,	/* i */

	/* info box */
	-1,1,14,G_BOX,FL3DBAK,OUTLINED,0x21100L,0,0,40,24,
	2,-1,-1,G_IMAGE,NONE,NORMAL,0L,2,1,36,5,
	3,-1,-1,G_TEXT,FL3DBAK,NORMAL,36L,1,7,38,1,
	4,-1,-1,G_TEXT,FL3DBAK,NORMAL,37L,1,9,38,1,
	5,-1,-1,G_TEXT,FL3DBAK,NORMAL,38L,1,10,38,1,
	6,-1,-1,G_TEXT,FL3DBAK,NORMAL,39L,1,11,38,1,
	7,-1,-1,G_TEXT,FL3DBAK,NORMAL,40L,1,13,38,1,
	8,-1,-1,G_TEXT,FL3DBAK,NORMAL,41L,1,14,38,1,
	9,-1,-1,G_TEXT,FL3DBAK,NORMAL,42L,1,15,38,1,
	10,-1,-1,G_TEXT,FL3DBAK,NORMAL,43L,1,17,38,1,
	11,-1,-1,G_TEXT,FL3DBAK,NORMAL,44L,1,18,38,1,
	12,-1,-1,G_TEXT,FL3DBAK,NORMAL,45L,1,19,38,1,
	13,-1,-1,G_TEXT,FL3DBAK,NORMAL,46L,1,20,38,1,
	14,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|FL3DIND|FL3DBAK,NORMAL,170L,8,22,8,1,	/* OK */		
	0,-1,-1,G_BUTTON,SELECTABLE|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,171L,24,22,8,1,	/* Help */	

	/* alert box */
	-1,1,12,G_BOX,FL3DBAK,OUTLINED,0x21100L,0,0,42,10,
	2,-1,-1,G_BOXTEXT,FL3DIND,NORMAL,47L,0,0,42,1,
	3,-1,-1,G_IMAGE,NONE,NORMAL,1L,1,2,4,2,
	4,-1,-1,G_IMAGE,NONE,NORMAL,2L,1,2,4,2,
	5,-1,-1,G_IMAGE,NONE,NORMAL,3L,1,2,4,2,
	6,-1,-1,G_STRING,NONE,NORMAL,175L,1,2,40,1,
	7,-1,-1,G_STRING,NONE,NORMAL,176L,1,3,40,1,
	8,-1,-1,G_STRING,NONE,NORMAL,177L,1,4,40,1,
	9,-1,-1,G_STRING,NONE,NORMAL,178L,1,5,40,1,
	10,-1,-1,G_STRING,NONE,NORMAL,179L,1,6,40,1,
	11,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|FL3DIND|FL3DBAK,NORMAL,180L,1,8,10,1,
	12,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,181L,12,8,10,1,
	0,-1,-1,G_BUTTON,SELECTABLE|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,182L,23,8,10,1,

	/* TLV offset */
	-1,1,3,G_BOX,FL3DBAK,OUTLINED,0x21100L,0,0,33,5,
	2,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,48L,1,1,31,1,
	3,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,186L,7,3,6,1,					/* OK */
	0,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,187L,20,3,6,1 };	/* Cancel */

long rs_trindex[] = {0L,79L,94L,107L};
struct foobar {
	int dummy;
	int *image;
	} rs_imdope[] = {0};

UWORD pic_logo[]={
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0001,0xFC27,0xFFFF,0x000E,0x03E0,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x000F,0x07E7,0x8F8F,0x0078,0x0E38,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x001C,0x01E7,0x0F87,0x03E0,0x1E3C,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0038,0x00E6,0x0F83,0x0780, 
	0x1C1C,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0078,0x0064, 
	0x0F81,0x0F00,0x3C1E,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x00F8,0x0064,0x0F81,0x1F00,0x3C1E,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x00F0,0x0020,0x0F80,0x1E00,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x3FF0,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x3C78,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x7C7C,0x7C1F,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x7C3E,0x7C1F,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000,0x0F80,0x7C3E, 
	0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x01F0,0x0000, 
	0x0F80,0x7C3E,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x00F0,0x0000,0x0F80,0x7C3E,0x7C1F,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x00F8,0x0000,0x0F80,0x7C3E,0x3C1E,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0078,0x0020,0x0F80,0x3C3E,0x3C1E,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x003C,0x0060,0x0F80,0x3C3C,0x1C1C,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x001E,0x00C0,0x0F80,0x1E38,0x1E3C,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x000F,0x0300,0x1FC0,0x0E70,0x0E38,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0001,0xFC00,0x7FF0,0x03E0, 
	0x03E0,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x2222,0x2222,0x2222,0x2222,0x2666,0x6666,0x6466,0x6766,0x77FF,0xFDFF, 
	0xFFF7,0x6566,0x6466,0x6462,0x2022,0x2022,0x2000,0x0000,0x8888,0x8888,0x8999,0x9999,0x9BBB,0xBBDB,0xBFDD,0xDDDD, 
	0xDDDD,0xDDDD,0xDDDD,0xDDDD,0xDFDB,0xBBB9,0x9988,0x8880,0x8880,0x0000,0x0000,0x0066,0x6666,0x66EE,0xEAAA,0xB777, 
	0x7777,0x7777,0x7777,0x7777,0x7777,0x7777,0x7776,0xAEAE,0x66E6,0x6660,0x0000,0x0000,0x8888,0x8888,0x8888,0x8991, 
	0x9999,0x9999,0x99D9,0x9DDD,0xDDDD,0xDFDD,0xDDDD,0xDDD9,0x9999,0x9190,0x8988,0x8888,0x8880,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x003F,0xFE00,0x0F00,0x0000,0x0000,0x007C,0x8000, 
	0x0000,0x0000,0x007F,0xF000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x000F,0x0E00,0x0700,0x0000,0x0000, 
	0x00C7,0x8000,0x0000,0x0000,0x001E,0x3800,0x0000,0x0002,0x0000,0x0000,0x0000,0x0000,0x0000,0x000F,0x0200,0x0700, 
	0x0000,0x0000,0x0181,0x8000,0x0000,0x0000,0x001E,0x1C00,0x0000,0x0006,0x0000,0x0000,0x0000,0x0000,0x0000,0x000F, 
	0x1200,0x0700,0x0000,0x0000,0x0180,0x8000,0x0000,0x0000,0x001E,0x1C00,0x0000,0x000E,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x000F,0x103F,0x0703,0xE0F0,0x79E0,0x01C0,0x8F1E,0x7BC0,0x787B,0xC01E,0x1C0F,0x00F0,0x1F9F,0x83C3,0xDE00, 
	0x0000,0x0000,0x0000,0x000F,0x30E1,0x8706,0x739C,0x3BF0,0x01F8,0x070E,0x3CE1,0xCC3F,0xC01E,0x3839,0xC39C,0x618E, 
	0x0E61,0xFE00,0x0000,0x0000,0x0000,0x000F,0xF0E1,0xC70C,0x730C,0x3C70,0x00FF,0x070E,0x3861,0x8639,0xC01F,0xF030, 
	0xC30C,0x608E,0x0C31,0xCE00,0x0000,0x0000,0x0000,0x000F,0x30E1,0xC71C,0x770E,0x3870,0x007F,0x870E,0x3873,0xFE38, 
	0x001E,0x3C70,0xE70E,0x7C0E,0x1FF1,0xC000,0x0000,0x0000,0x0000,0x000F,0x1007,0xC71C,0x070E,0x3870,0x000F,0xC70E, 
	0x3873,0xBE38,0x001E,0x1E70,0xE70E,0x3F0E,0x1DF1,0xC000,0x0000,0x0000,0x0000,0x000F,0x1039,0xC71C,0x070E,0x3870, 
	0x0103,0xC70E,0x3873,0x8038,0x001E,0x1E70,0xE70E,0x0F8E,0x1C01,0xC000,0x0000,0x0000,0x0000,0x000F,0x0061,0xC71C, 
	0x070E,0x3870,0x0181,0xC70E,0x3873,0x8038,0x001E,0x1E70,0xE70E,0x438E,0x1C01,0xC000,0x0000,0x0000,0x0000,0x000F, 
	0x00E1,0xC70E,0x130C,0x3870,0x0181,0xC71E,0x3861,0xC238,0x001E,0x1E30,0xC30C,0x618E,0x4E11,0xC000,0x0000,0x0000, 
	0x0000,0x000F,0x00E3,0xC70F,0x239C,0x3870,0x01C3,0x83EE,0x3CE1,0xFC38,0x001E,0x3C39,0xC39C,0x710F,0x8FE1,0xC000, 
	0x0000,0x0000,0x0000,0x003F,0xC07D,0xCF83,0xC0F0,0x7CF8,0x013E,0x03CF,0x3BC0,0x787E,0x007F,0xF00F,0x00F0,0x5E07, 
	0x03C3,0xF000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x3800,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x3800,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x3800,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x7E00,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000, 
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000 };

UWORD pic_note[]={
	0x0003,0xC000,0x0006,0x6000,0x000D,0xB000,0x001B,0xD800,
	0x0037,0xEC00,0x006F,0xF600,0x00DC,0x3B00,0x01BC,0x3D80,
	0x037C,0x3EC0,0x06FC,0x3F60,0x0DFC,0x3FB0,0x1BFC,0x3FD8,
	0x37FC,0x3FEC,0x6FFC,0x3FF6,0xDFFC,0x3FFB,0xBFFC,0x3FFD,
	0xBFFC,0x3FFD,0xDFFC,0x3FFB,0x6FFC,0x3FF6,0x37FC,0x3FEC,
	0x1BFF,0xFFD8,0x0DFF,0xFFB0,0x06FC,0x3F60,0x037C,0x3EC0,
	0x01BC,0x3D80,0x00DC,0x3B00,0x006F,0xF600,0x0037,0xEC00,
	0x001B,0xD800,0x000D,0xB000,0x0006,0x6000,0x0003,0xC000 };

UWORD pic_wait[]={
	0x3FFF,0xFFFC,0xC000,0x0003,0x9FFF,0xFFF9,0xBFFF,0xFFFD,
	0xDFF8,0x3FFB,0x5FE0,0x0FFA,0x6FC0,0x07F6,0x2F83,0x83F4,
	0x3787,0xC3EC,0x1787,0xC3E8,0x1BFF,0x83D8,0x0BFF,0x07D0,
	0x0DFE,0x0FB0,0x05FC,0x1FA0,0x06FC,0x3F60,0x02FC,0x3F40,
	0x037C,0x3EC0,0x017C,0x3E80,0x01BF,0xFD80,0x00BF,0xFD00,
	0x00DC,0x3B00,0x005C,0x3A00,0x006C,0x3600,0x002F,0xF400,
	0x0037,0xEC00,0x0017,0xE800,0x001B,0xD800,0x000B,0xD000,
	0x000D,0xB000,0x0005,0xA000,0x0006,0x6000,0x0003,0xC000 };

UWORD pic_stop[]={
	0x007F,0xFE00,0x00C0,0x0300,0x01BF,0xFD80,0x037F,0xFEC0,
	0x06FF,0xFF60,0x0DFF,0xFFB0,0x1BFF,0xFFD8,0x37FF,0xFFEC,
	0x6FFF,0xFFF6,0xDFFF,0xFFFB,0xB181,0x860D,0xA081,0x0205,
	0xA4E7,0x3265,0xA7E7,0x3265,0xA3E7,0x3265,0xB1E7,0x3205,
	0xB8E7,0x320D,0xBCE7,0x327D,0xA4E7,0x327D,0xA0E7,0x027D,
	0xB1E7,0x867D,0xBFFF,0xFFFD,0xDFFF,0xFFFB,0x6FFF,0xFFF6,
	0x37FF,0xFFEC,0x1BFF,0xFFD8,0x0DFF,0xFFB0,0x06FF,0xFF60,
	0x037F,0xFEC0,0x01BF,0xFD80,0x00C0,0x0300,0x007F,0xFE00 };

#define NUM_STRINGS 188	/* number of strings */
#define NUM_FRSTR 0		/* strings form_alert */
#define NUM_IMAGES 0
#define NUM_BB 4		/* number of BITBLK */
#define NUM_FRIMG 0
#define NUM_IB 0		/* number of ICONBLK */
#define NUM_TI 49		/* number of TEDINFO */
#define NUM_OBS 111		/* number of objects */
#define NUM_TREE 4		/* number of trees */ 

#define TREE1 0
#define TREE2 1
#define TREE3 2
#define TREE4 3

#ifndef LIGHT
#define MAX_SELECT 7
#define NB_BUB 39
#else
#define MAX_SELECT 5
#define NB_BUB 39-11
#endif

#define USA 0
#define FRG 1
#define FRA 2
#define UK 3
#define SPA 4
#define ITA 5
#define SWE 6
#define SWF 7
#define SWG 8

/* popups */

char *spec_select[2][7]={"Charge moyenne","Temp‚rature","M‚moire / æP","Boot","Arrˆt","Langage","Vid‚o",
                         "Average load","Temperature","Memory / æP","Boot","Stop","Language","Video"};
char *_select[2][7]={"  Charge moyenne ","  Temp‚rature    ","  M‚moire / æP   ","  Boot           ","  Arrˆt          ","  Langage        ","  Vid‚o (boot)   ",
                     "  Average load   ","  Temperature    ","  Memory / æP    ","  Boot           ","  Stop           ","  Language       ","  Video (boot)   "};
#ifndef LIGHT
char *spec_lang[]={"English","Deutsch","Fran‡ais","Espa¥ol","Italiano","Suisse","Schweiz"};
char *lang[]={ "  English     ",
               "  Deutsch     ",
               "  Fran‡ais    ",
               "  Espa¥ol     ",
               "  Italiano    ",
               "  Suisse      ",
               "  Schweiz     " };
char *spec_key[]={"USA","Deutsch","France","England","Espa¥a","Italia","Sweden","Suisse","Schweiž"};
char *key[]={ "  USA            ",
              "  Deutschland    ",
              "  France         ",
              "  England & Eire ",
              "  Espa¥a         ",
              "  Italia         ",
              "  Sweden         ",
              "  Suisse         ",
              "  Schweiž        " };
char *spec_date[]={"MM/DD/YY","DD/MM/YY","YY/MM/DD","YY/DD/MM"};
char *date[]={"  MM/DD/YY ","  DD/MM/YY ","  YY/MM/DD ","  YY/DD/MM "};
char *spec_time[]={"12","24"};
char *_time[]={"  12H ","  24H "};
char *spec_video[]={"TV","VGA"};
char *video[]={"  TV  ","  VGA "};
char *spec_mode[]={"NTSC","PAL"};
char *mode[]={"  NTSC ","  PAL  "};
char *spec_coul[]={" 2 "," 4 ","16","256","65536"};
char *coul[]={"  2     ","  4     ","  16    ","  256   ","  65536 "};
char *spec_res[]={"320x200","320x400","640x200","640x400"};
char *res[]={"  320 x 200 ","  320 x 400 ","  640 x 200 ","  640 x 400 "};
#endif
unsigned char code_lang[]= { USA, FRG, FRA, SPA, ITA, SWF, SWG };
unsigned char code_key[]=  { USA, FRG, FRA, UK, SPA, ITA, SWE, SWF, SWG };
unsigned char code_os[]={0,0x80,8,0x40,0x10,0x20};
char *spec_os[]={"-","TOS","MagiC","TT SVR4","Linux","NetBSD"};
char *os[]={"  -       ","  TOS     ","  MagiC   ","  TT SVR4 ","  Linux   ","  NetBSD  "};
char *spec_arbit[2][2]={"Non","Oui","No","Yes"};
char *arbit[2][2]={"  Non ","  Oui ","  No  ","  Yes "};
char *spec_idscsi[]={"0","1","2","3","4","5","6","7"};
char *idscsi[]={"  0 ","  1 ","  2 ","  3 ","  4 ","  5 ","  6 ","  7 "};	
char *spec_blitter_speed[2][2]={"Lent","Rapide","Slow","Fast"};
char *blitter_speed[2][2]={"  Lent   ","  Rapide ","  Slow ","  Fast "};
char *spec_tos_ram[2][2]={"Non","Oui","No","Yes"};
char *tos_ram[2][2]={"  Non ","  Oui ","  No  ","  Yes "};
char *spec_cache_delay[2][4]={"Normal","Cache 5","Alerte","Cache 5","Normal","Cache 5","Alert","Cache 5"};
char *cache_delay[2][4]={"  Cache normal / Pas d'alerte copyback     ",
                         "  Cache delais 5 S / Pas d'alerte copyback ",
                         "  Cache normal / Alerte copyback           ",
                         "  Cache delais 5 S / Alerte copyback       ",
                         "  Normal cache / No copyback alert    ",
                         "  Delay cache 5 S / No copyback alert ",
                         "  Normal cache / Copyback alert       ",
                         "  Delay cache 5 S / Copyback alert    "};
char *spec_boot_order[2][2]={"SCSI->IDE","IDE->SCSI","SCSI->IDE","IDE->SCSI"};
char *boot_order[2][2]={"  SCSI->IDE ","  IDE->SCSI ","  SCSI->IDE ","  IDE->SCSI "};
char *spec_day_stop[2][11]={"Sans","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche","Jours ouvr‚s","Fin de semaine","Chaque jour",
                            "Without","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday","Mon-Fri","Weekend","Every day"};
char *day_stop[2][11]={"  Sans           ","  Lundi          ","  Mardi          ","  Mercredi       ","  Jeudi          ","  Vendredi       ",
                       "  Samedi         ","  Dimanche       ","  Jours ouvr‚s   ","  Fin de semaine ","  Chaque jour    ",
                       "  Without   ","  Monday    ","  Tuesday   ","  Wednesday ","  Thursday  ","  Friday    ",
                       "  Saturday  ","  Sunday    ","  Mon-Fri   ","  Weekend   ","  Every day "};

/* BubbleGEM */

struct bubblegem
{
	int	object;
	char *french[1];
	char *english[1];
};

struct bubblegem bubbletab[NB_BUB] = {
	{MENUBSELECT,
	"S‚lection de la fonction",
	"Select function"},
	{MENUTEMP,
	"Valeur courante de la charge|moyenne du microprocesseur",
	"Current value of|CPU average load"},
	{MENUTEMP,
	"Valeur courante de la|temp‚rature du 68060",
	"Current value of the|68060's temperature"},
	{MENUBARTEMP,
	"Niveau de charge|moyenne du microprocesseur",
	"Level of CPU|average load"},
	{MENUBARTEMP,
	"Niveau de temp‚rature du 68060|Rouge = Danger",
	"Level of the 68060's temperature|Red = Danger"},
	{MENUTRIGGER,
	"Seuil de d‚clenchement de|l'alarme de temp‚rature",
	"Trigger level for|the temperature alarm"},
	{MENUTRACE,
	"Courbe d'‚volution de la|charge moyenne du microprocesseur|durant la derniŠre heure|Sans MiNT 1.11 ou plus, cette|courbe est trŠs approximative",
	"CPU average load curve|during previous hour.|Prior to MiNT v1.11, this|curve is very approximate"},
	{MENUTRACE,
	"Courbe d'‚volution de la|temp‚rature du 68060 durant|la derniŠre heure",
	"68060 temperature curve|during previous hour"},
	{MENUSTRAMTOT,
	"Capacit‚ totale|de la ST-Ram",
	"Total ST RAM capacity"},
	{MENUFASTRAMTOT,
	"Capacit‚ totale|de la Fast-Ram",
	"Total Fast RAM capacity"},
	{MENUSTRAM,
	"Nombre d'octets de|la ST-Ram libres",
	"Number of free bytes|in ST RAM"},
	{MENUFASTRAM,
	"Nombre d'octets de|la Fast-Ram libres",
	"Number of free bytes|in Fast RAM"},
	{MENUMIPS,
	"Nombre de millions d'instructions par|seconde effectu‚s par le microprocesseur",
	"Number of millions of instructions per|second executed by the microprocessor"},
#ifndef LIGHT
	{MENUBLANG,
	"S‚lectionne au d‚marrage|la langue par d‚faut",
	"Select default language|at startup"},
	{MENUBKEY,
	"S‚lectionne au d‚marrage|le type de clavier",
	"Select keyboard type|at startup"},
	{MENUBDATE,
	"S‚lectionne au d‚marrage|le format de la date",
	"Select date format|at startup"},
	{MENUBTIME,
	"S‚lectionne au d‚marrage|le format de l'heure|12 ou 24 heures",
	"Select 12-/24-hour time|format at startup"},
	{MENUSEP,
	"S‚lectionne au d‚marrage|le s‚parateur de date",
	"Select date separator|at startup"},
	{MENUBVIDEO,
	"S‚lectionne au d‚marrage|le type de moniteur",
	"Select monitor type|at startup"},
	{MENUBMODE,
	"S‚lectionne au d‚marrage|le mode d'affichage|NTSC = 60 Hz, PAL = 50 Hz",
	"Select display mode|at startup|NTSC = 60 Hz, PAL = 50 Hz"},
	{MENUBCOUL,
	"S‚lectionne au d‚marrage|le nombre de couleurs",
	"Select number of colours|at startup"},
	{MENUBRES,
	"S‚lectionne au d‚marrage|la r‚solution de l'‚cran",
	"Select screen resolution|at startup"},
	{MENUSTMODES,
	"S‚lectionne au d‚marrage|le mode de compatibilit‚ ST",
	"Select ST compatibility mode|at startup"},
	{MENUOVERSCAN,
	"S‚lectionne au d‚marrage|le mode overscan sur TV",
	"Select TV overscan mode|at startup"},
#endif
	{MENUBBOOTORDER,
	"S‚lectionne l'ordre de boot|sur les disques IDE et SCSI",
	"Select boot order for|IDE and SCSI drives"},
	{MENUBOS,
	"S‚lectionne au d‚marrage le|systŠme d'exploitation par d‚faut",
	"Select default|operating system at startup"},
	{MENUBARBIT,
	"S‚lectionne au d‚marrage|l'arbitration SCSI",
	"Select SCSI arbitration|at startup"},
	{MENUBIDSCSI,
	"S‚lectionne au d‚marrage|l'identificateur SCSI (0 to 7)",
	"Select system SCSI identifier (0 to 7)|at startup"},
	{MENUDELAY,
	"D‚lais de la pause au|d‚marrage en secondes",
	"Boot delay in seconds"},
	{MENUBBLITTER,
	"Change la vitesse|du blitter",
	"Change the speed|of the blitter"},
	{MENUBTOSRAM,
	"Transfert du TOS 4.0x en RAM|avec utilisation de la PMMU",
	"Copy TOS 4.0x to RAM|using the PMMU"},
	{MENUBCACHE,
	"Coupe les caches pendant 5 secondes|lors du lancement d'un programme|sous TOS",
	"Disable the caches for 5 seconds|when a program is started|under TOS"},
	{MENUBDAY,
	"S‚l‚ctionne le mode|d'extinction programm‚e|aprŠs une proc‚dure shutdown",
	"Select the stop mode programmed|after a shutdown procedure"},
	{MENUTIME,
	"Si le mode d'arrˆt est|activ‚, l'heure d'arrˆt|se r‚gle ici",
	"If stop mode is active,|the time must be entered here"},
	
	{MENUBSAVE,
	"Bouton pour sauver les|r‚glages sur le disque",
	"Button to save parameters|to disk"},
	{MENUBLOAD,
	"Bouton pour charger les|r‚glages sauv‚s sur le disque",
	"Button to load saved parameters|from disk"},
	{MENUBOK,
	"Bouton pour valider les changements|dans la m‚moire non volatile",
	"Button to load changed values|into non-volatile RAM"},
	{MENUBCANCEL,
	"Bouton pour ne rien changer|… la configuration",
	"Button to cancel changes|to the configuration"},
	{MENUBINFO,
	"Bouton pour afficher|des informations",
	"Button to display|program information"}
};

CPXINFO* CDECL cpx_init(XCPB *xcpb)

{
	register int i;
	long value,stack;
	COOKIE apk;
	COOKIE idt;
	HEAD *header;
	MX_KERNEL *mx_kernel;
	CT60_COOKIE *ct60_arg=NULL;
	Xcpb=xcpb;
#ifdef DEBUG
	printf("\r\nCPX init\r\nRead NVRAM");
#endif
	NVMaccess(0,0,(int)(sizeof(NVM)),&nvram);	/* read */
	if((*Xcpb->get_cookie)('MiNT',&value))
		mint=1;
	else
		mint=0;
	magic_date=0L;
	magic=get_MagiC_ver(&magic_date);
	if(magic)
		mx_kernel=(MX_KERNEL *)Dcntl(KER_GETINFO,NULL,0L);
	if(mint || (magic && *mx_kernel->pe_slice>=0))	/* preemptive */
		flag_cpuload=1;
	else
		flag_cpuload=0;
	stack=Super(0L);
	st_ram = *(long *)0x42e;					/* phystop, end ST-Ram */
	fast_ram = *(long *)0x5a4;					/* end Fast-Ram */
	if(fast_ram && *(long *)0x5a8==0x1357BD13L	/* ramvalid */
	 && Mxalloc(-1L,1))							/* free Fast-Ram */
		fast_ram-=0x1000000L;
	else
		fast_ram=0L;
	Super((void *)stack);
#ifdef TEST_MAGICMAC
	if(!fast_ram && (*Xcpb->get_cookie)('MgMc',&value))
		fast_ram=0x1000000L;					/* just for a test under MagiCMac */
#endif
	if(init_rsc()==0)
		return(0);
#ifdef DEBUG
	printf("\r\nTest cookies");
#endif
	if(!(*Xcpb->get_cookie)('_AKP',&value))
	{
		apk.ident='_AKP';						/* cookie created if not exists */
		apk.v.l=(((long)nvram.language)<<8) + (long)nvram.keyboard;
		add_cookie(&apk);
	}
	if(!(*Xcpb->get_cookie)('_IDT',&value))
	{
		idt.ident='_IDT';						/* cookie created if not exists */
		idt.v.l=(((long)nvram.datetime)<<8) + (long)nvram.separator;
		add_cookie(&idt);
	}
	eiffel_temp=NULL;
    if((*Xcpb->get_cookie)('Temp',&value))
		eiffel_temp=(char *)value;
	for(i=0;i<61;i++)
		tab_temp[i]=tab_temp_eiffel[i]=tab_cpuload[i]=0;
#ifdef DEBUG
	printf("\r\nRead CPX header");
#endif	
	if((head=get_header(ID_CPX))==0)
		return(0);
	header=fix_header();
	trigger_temp=header->trigger_temp;
	if(trigger_temp==0)
		trigger_temp=(MAX_TEMP*3)/4;
	if(trigger_temp>99)
		trigger_temp=99;
	daystop=header->daystop;
    if(daystop>11)
    	daystop=0;	
	timestop=header->timestop;
	if(!loops_per_sec)
	{
#ifdef DEBUG
		printf("\r\nTest mips");
#endif
		loops_per_sec=bogomips();
	}
	if(mint || magic)
		ap_id=appl_find(NULL);
	else										/* single task system */
	{
		if((ap_id=appl_find("XCONTROL"))<0
		 && (ap_id=appl_find("ZCONTROL"))<0
		 && (ap_id=appl_find("COPS    "))<0
		 && (ap_id=appl_find("FREEDOM2"))<0)
			ap_id=-1;
	}
	if( ((*Xcpb->get_cookie)(ID_CT60,&value))
#ifdef TEST_MAGICMAC
     || (*Xcpb->get_cookie)('MgMc',&value)
#endif
	)
		flag_xbios=1;
	else
		flag_xbios=0;
	if(( (*Xcpb->get_cookie)('_MCH',&value) && (value==0x30000)	/* Falcon */
	 && (flag_xbios || test_060())								/* & CT60 */
#ifdef TEST_MAGICMAC
     || (*Xcpb->get_cookie)('MgMc',&value)
#endif
	) && ap_id>=0 )
	{
#ifdef DEBUG
		printf("\r\nStart temperature task");
#endif
		if((*Xcpb->get_cookie)(ID_CT60,&(long)ct60_arg) && (ct60_arg!=NULL))
		{
			ct60_arg->trigger_temp=(unsigned int)trigger_temp;
			ct60_arg->daystop=(unsigned int)daystop;
			ct60_arg->timestop=(unsigned int)timestop;          /* ACC cannot receive arg */
		}	
		start_temp(&trigger_temp,&daystop,&timestop);			/* start thread or CT60TEMP.APP */
	}
#ifdef DEBUG
	printf("\r\nCPX init finished");
#endif
	return(&cpxinfo);
}

int CDECL cpx_call(GRECT *work)

{
	GRECT menu;
	TEDINFO *t_edinfo;
	long value,stack;
	HEAD *header;
	CT60_COOKIE *ct60_arg=NULL;
	int ret;
	register int i;
#ifdef DEBUG
	printf("\r\nCPX call\r\nOpen virtual workstation");
#endif	
	if((vdi_handle=Xcpb->handle)>0)
	{
		v_opnvwk(work_in,&vdi_handle,work_out);
		if(vdi_handle<=0 || (head=get_header(ID_CPX))==0)
			return(0);
	}
	else
		return(0);
#ifdef DEBUG
	printf("\r\nTest cookies");
#endif
#ifdef TEST_MAGICMAC
    if(!(*Xcpb->get_cookie)('MgMc',&value))
#endif
    {
		if(!(*Xcpb->get_cookie)('_MCH',&value) || (value!=0x30000))	/* Falcon */
		{
			if(!start_lang)
				form_alert(1,"[1][Cette machine n'est|pas un FALCON 030][Annuler]");
			else
				form_alert(1,"[1][This computer isn't|a FALCON 030][Cancel]");
			return(0);
		}
		if(!flag_xbios && !test_060())
		{
			stack=Super(0L);
			tosram=(int)ct60_rw_param(CT60_MODE_READ,CT60_PARAM_TOSRAM,0L);
			Super((void *)stack);
			if(tosram<0)
			{
				if(!start_lang)
					form_alert(1,"[1][Pas de CT60 !][OK]");
				else
					form_alert(1,"[1][CT60 not found!][OK]");
			}
		}
	}
	if((ap_id<0 || temp_id<0) && test_060())
	{
		if(!start_lang)
			form_alert(1,"[1][ATTENTION !|Il n'est pas possible de|surveiller la temp‚rature quand|ce CPX sera ferm‚ !|S.V.P.installez CT60TEMP.ACC/APP][OK]");
		else
			form_alert(1,"[1][WARNING!|It is not possible to monitor|the temperature when this CPX|is closed!  Please install|CT60TEMP.ACC/APP][OK]");
	}
	selection=PAGE_TEMP;
	flag_bubble=0;
	rs_object[MENUBOX].ob_x=work->g_x;
	rs_object[MENUBOX].ob_y=work->g_y;
	rs_object[MENUBOX].ob_width=work->g_w;
	rs_object[MENUBOX].ob_height=work->g_h;
#ifdef DEBUG
	printf("\r\nRead NVRAM");
#endif
	NVMaccess(0,0,(int)(sizeof(NVM)),&nvram);	/* read */
#ifdef DEBUG
	printf("\r\nRead CPX header");
#endif
	header=fix_header();
	trigger_temp=header->trigger_temp;
	if(trigger_temp==0)
		trigger_temp=(MAX_TEMP*3)/4;
	if(trigger_temp>99)
		trigger_temp=99;
	t_edinfo=rs_object[MENUTRIGGER].ob_spec.tedinfo;
	sprintf(t_edinfo->te_ptext,"%d",trigger_temp);
	daystop=header->daystop;
    if(daystop>11)
    	daystop=0;	
	t_edinfo=rs_object[MENUBDAY].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_day_stop[start_lang][daystop];
	t_edinfo=rs_object[MENUTIME].ob_spec.tedinfo;
	timestop=header->timestop;
	i=(((timestop>>11) & 0x1f) * 100) + ((timestop>>5) & 0x3f);
	if(i>2359)
		i=2359;	
	sprintf(t_edinfo->te_ptext,"%04d",i);
	spec_cpuload.ub_code=cpu_load;
	spec_trace.ub_code=trace_temp;
	spec_trace.ub_parm=(long)tab_temp;
	rs_object[MENUTRACE].ob_type=G_USERDEF;
	rs_object[MENUTRACE].ob_spec.userblk=(USERBLK *)&spec_trace;
	sprintf(rs_object[MENUSTRAMTOT].ob_spec.free_string,"%9ld",st_ram);
	rs_object[MENUSTRAMTOT].ob_spec.free_string[9]=' ';
	sprintf(rs_object[MENUFASTRAMTOT].ob_spec.free_string,"%9ld",fast_ram);
	rs_object[MENUFASTRAMTOT].ob_spec.free_string[9]=' ';
	t_edinfo=rs_object[MENUMIPS].ob_spec.tedinfo;
	if((*Xcpb->get_cookie)(ID_CT60,&(long)ct60_arg) && (ct60_arg!=NULL) && ct60_arg->speed_fan)
		sprintf(t_edinfo->te_ptext,"æP: %3lu.%02lu Mips     %04u tr/mn",
		loops_per_sec/500000,(loops_per_sec/5000) % 100,ct60_arg->speed_fan);
	else
		sprintf(t_edinfo->te_ptext,"æP: %3lu.%02lu Mips",loops_per_sec/500000,(loops_per_sec/5000) % 100);
	language=0;
	if(nvram.language<9)
	{
		while(language<7 && nvram.language!=code_lang[language])
			language++;
		if(language>=7)
			language=0;	
	}
	keyboard=0;
	if(nvram.keyboard<9)
	{
		while(keyboard<8 && nvram.keyboard!=code_key[keyboard])
			keyboard++;
		if(keyboard>=8)
			keyboard=0;
	}
	datetime=(int)nvram.datetime & 0x13;
	vmode=(int)nvram.vmode & 0x1ff;
#ifndef LIGHT
	t_edinfo=rs_object[MENUBLANG].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_lang[language];
	t_edinfo=rs_object[MENUBKEY].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_key[keyboard];
	t_edinfo=rs_object[MENUBDATE].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_date[datetime & 3];
	t_edinfo=rs_object[MENUBTIME].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_time[(datetime>>4) & 1];
	t_edinfo=rs_object[MENUSEP].ob_spec.tedinfo;
	t_edinfo->te_ptext[0]=nvram.separator;
	t_edinfo=rs_object[MENUBVIDEO].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_video[((vmode & VGA_FALCON)>>4) & 1];
	t_edinfo=rs_object[MENUBMODE].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_mode[((vmode & PAL)>>5) & 1];
	t_edinfo=rs_object[MENUBCOUL].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_coul[vmode & 7];
	i=0;
	if(vmode & COL80)
		i+=2;
	if(!(vmode & VERTFLAG) && (vmode & VGA_FALCON))
		i++;
	if((vmode & VERTFLAG) && !(vmode & VGA_FALCON))
		i++;
	t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_res[i];
	if((vmode & OVERSCAN) && !(vmode & VGA_FALCON))
		rs_object[MENUOVERSCAN].ob_state |= SELECTED;
	else
		rs_object[MENUOVERSCAN].ob_state &= ~SELECTED;		
	if(vmode & STMODES)
		rs_object[MENUSTMODES].ob_state |= SELECTED;
	else
		rs_object[MENUSTMODES].ob_state &= ~SELECTED;		
#endif
	bootpref=0;
	while(bootpref<6 && nvram.bootpref!=(int)code_os[bootpref])
		bootpref++;
	if(bootpref>=6)
		bootpref=0;	
	t_edinfo=rs_object[MENUBOS].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_os[bootpref];
	scsi=(int)nvram.scsi & 0x87;
	i=0;
	if(scsi & 0x80)
		i++;
	t_edinfo=rs_object[MENUBARBIT].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_arbit[start_lang][i];
	t_edinfo=rs_object[MENUBIDSCSI].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_idscsi[scsi & 7];
	bootdelay=(int)nvram.bootdelay;
	if(bootdelay>99)
		bootdelay=99;
	t_edinfo=rs_object[MENUDELAY].ob_spec.tedinfo;
	sprintf(t_edinfo->te_ptext,"%d",bootdelay);
	if(flag_xbios)
	{
		tosram=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_PARAM_TOSRAM,0L)&1;
		blitterspeed=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_BLITTER_SPEED,0L)&1;
		cachedelay=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_CACHE_DELAY,0L)&3;
		bootorder=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_BOOT_ORDER,0L)&1;
	}
	else
	{
		stack=Super(0L);
		tosram=(int)ct60_rw_param(CT60_MODE_READ,CT60_PARAM_TOSRAM,0L)&1;
		blitterspeed=(int)ct60_rw_param(CT60_MODE_READ,CT60_BLITTER_SPEED,0L)&1;
		cachedelay=(int)ct60_rw_param(CT60_MODE_READ,CT60_CACHE_DELAY,0L)&3;
		bootorder=(int)ct60_rw_param(CT60_MODE_READ,CT60_BOOT_ORDER,0L)&1;
		Super((void *)stack);
	}
	t_edinfo=rs_object[MENUBBLITTER].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_blitter_speed[start_lang][blitterspeed];
	t_edinfo=rs_object[MENUBTOSRAM].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_tos_ram[start_lang][tosram];
	t_edinfo=rs_object[MENUBCACHE].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_cache_delay[start_lang][cachedelay];
	t_edinfo=rs_object[MENUBBOOTORDER].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_boot_order[start_lang][bootorder];
    ed_pos=ed_objc=0;
	Work=work;
	t_edinfo=rs_object[MENUBSELECT].ob_spec.tedinfo;
	if(test_060())
	{
		t_edinfo->te_ptext=spec_select[start_lang][PAGE_TEMP];
		display_selection(PAGE_TEMP,0);
		selection=-1;
		cpx_timer(&ret);
		selection=PAGE_TEMP;
		ed_objc=MENUTRIGGER;
	}
	else						/* read temperature not works in normal mode */
	{
		t_edinfo->te_ptext=spec_select[start_lang][PAGE_MEMORY];
		display_selection(PAGE_MEMORY,0);
		selection=-1;
		cpx_timer(&ret);
		selection=PAGE_MEMORY;
	}
	objc_edit(rs_object,ed_objc,0,&ed_pos,ED_INIT);
	new_objc=ed_objc;
	new_pos=ed_pos;
	cpx_draw(work);
	(*Xcpb->Set_Evnt_Mask)(MU_KEYBD|MU_BUTTON|MU_TIMER,0L,0L,ITIME);
	if(temp_id>=0)
		send_ask_temp();
#ifdef DEBUG
	printf("\r\nCPX call finished");
#endif
	return(1);					/* CPX isn't finished */
}

void CDECL cpx_draw(GRECT *clip)

{
	display_objc(0,clip);
}

void CDECL cpx_wmove(GRECT *work)

{
	rs_object[MENUBOX].ob_x=work->g_x;
	rs_object[MENUBOX].ob_y=work->g_y;
	rs_object[MENUBOX].ob_width=work->g_w;
	rs_object[MENUBOX].ob_height=work->g_h;
}

int CDECL cpx_hook(int event,WORD *msg,MRETS *mrets,int *key,int *nclicks)

{
	register int i;
	register long ret;
	register TEDINFO *t_edinfo;
	register unsigned short *p;
	if(mrets && key && nclicks);
	if(event & MU_MESAG)
	{
		switch(msg[0])
		{
		case WF_TOP:
			wi_id=msg[3];
			break;		
		case WM_REDRAW:
			wi_id=msg[3];
			if(temp_id>=0 && selection==PAGE_TEMP)
				send_ask_temp();
			break;
		case THR_EXIT:		/* message received from thread */
	 		ret=*((long *)(&msg[4]));
	 		if(!start_lang)
				form_alert(1,"[1][La tƒche pour surveiller la|temp‚rature est termin‚e !][OK]");
			else
				form_alert(1,"[1][The thread for monitoring the|temperature has terminated!][OK]");
			if(ret);
			break;		
		case BUBBLEGEM_ACK:
			flag_bubble=0;
			time_out_bubble=-1;
			break;
		case MSG_CT60_TEMP:		/* message received from thread or CT60TEMP.ACC/APP */
			if(msg[1]==temp_id)
			{
				time_out_thread=-1;
	 			p=*((unsigned short **)(&msg[3]));
	 			if(p)			
	 			{
	 				for(i=0;i<61;tab_temp[i++]=*p++);
	 				if(eiffel_temp!=NULL)
	 					for(i=0;i<61;tab_temp_eiffel[i++]=*p++);
					if(selection==PAGE_TEMP)
						display_objc(MENUTRACE,Work);
				}
	 			p=*((unsigned short **)(&msg[5]));
	 			if(p)			
	 			{
	 				for(i=0;i<61;tab_cpuload[i++]=*p++);
					if(selection==PAGE_CPULOAD)
						display_objc(MENUTRACE,Work);
				}
				spec_cpuload.ub_parm=(long)msg[7];
				if(selection==PAGE_CPULOAD)
				{
					t_edinfo=rs_object[MENUTEMP].ob_spec.tedinfo;
					sprintf(t_edinfo->te_ptext,"%3ld  ",spec_cpuload.ub_parm);
					t_edinfo->te_ptext[4]='%';
					display_objc(MENUTEMP,Work);
					display_objc(MENUBARTEMP,Work);							
				}
			}
			break;
		}
	}
	return(0);
}

void CDECL cpx_timer(int *event)

{
	register int i,j,ret,mn;
	long value;
	CT60_COOKIE *ct60_arg=NULL;
	unsigned int time,new_trigger,new_timestop;
	static unsigned int old_daystop=0;
	register TEDINFO *t_edinfo;
	char *p;
	static int error_flag=0;
	if(*event);
	if(test_060())													/* read temperature not works in normal mode */
	{
		switch(selection)
		{
		case PAGE_CPULOAD:
			if(temp_id>=0)											/* average load */
				send_ask_temp();		
			break;
		case PAGE_MEMORY:
			if((*Xcpb->get_cookie)(ID_CT60,&(long)ct60_arg) && (ct60_arg!=NULL) && ct60_arg->speed_fan)
			{
				t_edinfo=rs_object[MENUMIPS].ob_spec.tedinfo;	
				sprintf(t_edinfo->te_ptext,"æP: %3lu.%02lu Mips     %04u tr/mn",
				loops_per_sec/500000,(loops_per_sec/5000) % 100,ct60_arg->speed_fan);
				display_objc(MENUMIPS,Work);
			}
			break;
		case PAGE_TEMP:
		case -1:
			ret=read_temp();										/* temperature 68060 */
			if(ret<0)
			{
				ret=0;
				if(!error_flag)
				{
			 		if(!start_lang)
						form_alert(1,"[1][Il n'est pas possible de lire|la temp‚rature car le capteur|donne de mauvaises valeurs][OK]");
					else
						form_alert(1,"[1][Cannot determine temperature|because the monitor has|returned bad values][OK]");
					error_flag=1;
				}
			}
			t_edinfo=rs_object[MENUTEMP].ob_spec.tedinfo;
			sprintf(t_edinfo->te_ptext,"%3d øC",ret);
			if(ret>MAX_TEMP)
				ret=MAX_TEMP;
			i=rs_object[MENUBARTEMP].ob_width;
			ret=(i*ret)/MAX_TEMP;
			i/=3;
			rs_object[MENUBARTEMP+1].ob_flags &= ~HIDETREE;			/* green */
			if(ret<i)
			{
				rs_object[MENUBARTEMP+2].ob_flags |= HIDETREE;		/* no yellow */
				rs_object[MENUBARTEMP+3].ob_flags |= HIDETREE;		/* no red */
				rs_object[MENUBARTEMP+1].ob_width=ret;
				rs_object[MENUBARTEMP+2].ob_width=rs_object[MENUBARTEMP+3].ob_width=0;
			}
			else
			{
				if(ret<(i*2))
				{
					rs_object[MENUBARTEMP+2].ob_flags &= ~HIDETREE;	/* yellow */
					rs_object[MENUBARTEMP+3].ob_flags |= HIDETREE;	/* no red */
					rs_object[MENUBARTEMP+1].ob_width=i;			
					rs_object[MENUBARTEMP+2].ob_width=ret-i;
					rs_object[MENUBARTEMP+3].ob_width=0;
				}
				else
				{
					rs_object[MENUBARTEMP+2].ob_flags &= ~HIDETREE;	/* yellow */
					rs_object[MENUBARTEMP+3].ob_flags &= ~HIDETREE;	/* no red */
					rs_object[MENUBARTEMP+1].ob_width=i;			
					rs_object[MENUBARTEMP+2].ob_width=i;			
					rs_object[MENUBARTEMP+3].ob_width=ret-(i*2);
				}
			}
			if(selection==PAGE_TEMP)
			{
				display_objc(MENUTEMP,Work);
				display_objc(MENUBARTEMP,Work);
			}
			if(temp_id>=0)
				send_ask_temp();
			break;
		}
		if(fill_tab_temp())											/* trace */
		{
			time=(unsigned int)Gettime();
			mn=(int)((((time>>11) & 0x1f) * 60) + ((time>>5) & 0x3f));
			t_edinfo=rs_object[MENUTRACE+1].ob_spec.tedinfo;	
			for(i=-60,j=0;i<=0;i+=10,j+=6)
			{
				ret=mn+i;
				if(ret<0)
					ret+=1440;
				sprintf(&t_edinfo->te_ptext[j],"%02d:%02d",ret/60,ret%60);
				if(i<=0)
					t_edinfo->te_ptext[j+5]=' ';
			}
			if(selection==PAGE_CPULOAD || selection==PAGE_TEMP)
			{
				display_objc(MENUTRACE,Work);
				display_objc(MENUTRACE+1,Work);		
			}
		}
	}
	t_edinfo=rs_object[MENUSTRAM].ob_spec.tedinfo;
	sprintf(t_edinfo->te_ptext,"%9ld",Mxalloc(-1L,0));				/* ST-Ram */
	t_edinfo->te_ptext[9]=' ';
	t_edinfo=rs_object[MENUFASTRAM].ob_spec.tedinfo;
	sprintf(t_edinfo->te_ptext,"%9ld",Mxalloc(-1L,1));				/* Fast-Ram */
	t_edinfo->te_ptext[9]=' ';
	if(selection==PAGE_MEMORY)										/* memory */
	{
		display_objc(MENUSTRAM,Work);
		display_objc(MENUFASTRAM,Work);
	}
	t_edinfo=rs_object[MENUTRIGGER].ob_spec.tedinfo;
	new_trigger=(unsigned int)atoi(t_edinfo->te_ptext);
	t_edinfo=rs_object[MENUTIME].ob_spec.tedinfo;	
	new_timestop=(((unsigned int)atoi(t_edinfo->te_ptext)/100)<<11)
                +(((unsigned int)atoi(t_edinfo->te_ptext)%100)<<5);
	if((new_trigger!=trigger_temp)
	 || (new_timestop!=timestop) || (daystop!=old_daystop))
	{
		trigger_temp=new_trigger;
		timestop=new_timestop;
		if(temp_id>=0)
			send_ask_temp();
		old_daystop=daystop;	
	}
	bubble_help();
	if(time_out_thread>=0)
	{
		time_out_thread++;
		if(time_out_thread>10)
		{
			if(!start_lang)
				form_alert(1,"[1][Pas de r‚ponse de|CT60TEMP.APP/ACC ou Thread !| |Il n'est pas possible|d'afficher la derniŠre heure][Annuler]");
			else
				form_alert(1,"[1][No response from|CT60TEMP.APP/ACC or thread!| |Cannot display previous hour][Cancel]");
			time_out_thread=-1;
		}
	}
}

void CDECL cpx_key(int kstate,int key,int *event)

{
	register int i,j,dial;
	register TEDINFO *t_edinfo;
	if(kstate);
	if(*event);
	dial=form_keybd(rs_object,ed_objc,ed_objc,key,&new_objc,&key);
	if(!key && dial)
	{
		if(new_objc)
		{
			t_edinfo=(TEDINFO *)rs_object[new_objc].ob_spec.tedinfo;
			for(i=0;t_edinfo->te_ptext[i];i++);
			new_pos=i;				/* cursor in end of zone edited */
		}
	}
	else
	{
		if(rs_object[ed_objc].ob_flags & EDITABLE)
		{
			switch(key & 0xff00)
			{
			case 0x7300:			/* ctrl + left */
				new_objc=ed_objc;	/* same zone */
				new_pos=0;			/* cursor at left */
				key=0;
				break;
			case 0x7400:			/* ctrl + right */
				new_objc=ed_objc;	/* same zone */
				key=0;
				t_edinfo=(TEDINFO *)rs_object[new_objc].ob_spec.tedinfo;
				for(i=0;t_edinfo->te_ptext[i];i++);
				new_pos=i;			/* cursor in end of zone */
			}
		}
		if((key & 0xff00)==0x6200)	/* help */
			call_st_guide();
	}
	if(key>0)
	{
		objc_edit(rs_object,ed_objc,key,&ed_pos,ED_CHAR);	/* text edited in usual zone */
		new_objc=ed_objc;
		new_pos=ed_pos;
	}
	if(dial)						/* if 0 => new_objc contains object EXIT */
		move_cursor();
	else
	{
		change_objc(new_objc,NORMAL,Work);
		*event=1;					/* end */
		cpx_close(0);
	}	
}

void CDECL cpx_button(MRETS *mrets,int nclicks,int *event)

{
	register int i,j,k,ret,objc_clic,pos_clic;
	register TEDINFO *t_edinfo;
	int xoff,yoff,attrib[10];
	long value,stack,offset;
	GRECT menu;
	HEAD *header;
	CT60_COOKIE *ct60_arg=NULL;
	OBJECT *info_tree, *offset_tree;
	header=(HEAD *)head->cpxhead.buffer;
	if((objc_clic=objc_find(rs_object,0,MAX_DEPTH,mrets->x,mrets->y))>=0)
	{
		if(form_button(rs_object,objc_clic,nclicks,&new_objc))
		{
			if(new_objc>0)
			{
				objc_offset(rs_object,objc_clic,&xoff,&yoff);
				t_edinfo=(TEDINFO *)rs_object[objc_clic].ob_spec.tedinfo;
				vqt_attributes(vdi_handle,attrib);
				/* attrib[8] = largeur du cadre des caractŠres */
				for(i=0;t_edinfo->te_ptmplt[i];i++);	/* size of mask string */
				if((pos_clic=rs_object[objc_clic].ob_width-i*attrib[8])>=0)
				{
					switch(t_edinfo->te_just)
					{
					case TE_RIGHT: 			/* justified to right */
						pos_clic=mrets->x-xoff-pos_clic;
						break;
					case TE_CNTR:			/* centred */
						pos_clic=mrets->x-xoff-pos_clic/2;
						break;
					case TE_LEFT:			/* justified to left */
					default:
						pos_clic=mrets->x-xoff;
					}
				}
				else
					pos_clic=mrets->x-xoff;
				new_pos=-1;
				pos_clic/=attrib[8];		/* position character checked */
				j=-1;
				do
				{
					if(t_edinfo->te_ptmplt[++j]=='_')
						new_pos++;
				}
				while(j<i && j<pos_clic);	/* end if cursor on end of string or position character checked */
				if(j>=i)
					new_pos=-1;						/* cursor at end of string */
				else
				{
					j--;
					while(t_edinfo->te_ptmplt[++j]!='_' && j<i);
					if(j>=i)
						new_pos=-1;					/* cursor at end of string */
				}
				for(i=0;t_edinfo->te_ptext[i];i++);	/* size of string text */
				if(new_pos<0 || i<new_pos)
					new_pos=i;
			}
			move_cursor();
		}
		else
		{
			switch(objc_clic)
			{
			case MENUBSELECT:
				objc_offset(rs_object,MENUBSELECT,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBSELECT].ob_width;
				menu.g_h=rs_object[MENUBSELECT].ob_height;
				i=MAX_SELECT;
				j=selection;
				k=0;
				if(!test_060())
				{
					i-=2;
					j-=2;
					k=2;
				}
				else
				{
					if(!flag_cpuload || ((ap_id<0 || temp_id<0) && test_060()))
					{
						i--;
						j--;
						k++;
					}
				}
				ret=(*Xcpb->Popup)(&_select[start_lang][k],i,j,IBM,&menu,Work);
				if(ret>=0 && k!=0)
					ret+=k; 
				if(ret>=0 && ret!=selection)
				{
					t_edinfo=rs_object[MENUBSELECT].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_select[start_lang][ret];
					display_objc(MENUBSELECT,Work);
					selection=ret;
					display_selection(selection,1);
				}
				break;
			case MENUTRIGGER:
				if(nclicks>1 && (offset_tree=adr_tree(TREE4))!=0)
				{
					if(flag_xbios)
						offset=ct60_rw_parameter(CT60_MODE_READ,CT60_PARAM_OFFSET_TLV,0L);
					else
					{
						stack=Super(0L);
						offset=ct60_rw_param(CT60_MODE_READ,CT60_PARAM_OFFSET_TLV,0L);
						Super((void *)stack);
					}
					if(offset>99)
						offset=99;
					if(offset<-99)
						offset=-99;
					t_edinfo=offset_tree[OFFSETTLV].ob_spec.tedinfo;
					sprintf(t_edinfo->te_ptext,"%ld",offset);
					if(hndl_form(offset_tree,OFFSETTLV)==OFFSETOK)
					{
						offset=atoi(t_edinfo->te_ptext);
						if(flag_xbios)
							ct60_rw_parameter(CT60_MODE_WRITE,CT60_PARAM_OFFSET_TLV,offset);
						else
						{
							stack=Super(0L);
							ct60_rw_param(CT60_MODE_WRITE,CT60_PARAM_OFFSET_TLV,offset);
							Super((void *)stack);
						}
					}
				}
				break;				
			case MENUMIPS:
				loops_per_sec=bogomips();
				t_edinfo=rs_object[MENUMIPS].ob_spec.tedinfo;
				if((*Xcpb->get_cookie)(ID_CT60,&(long)ct60_arg) && (ct60_arg!=NULL) && ct60_arg->speed_fan)
					sprintf(t_edinfo->te_ptext,"æP: %3lu.%02lu Mips     %04u tr/mn",
					loops_per_sec/500000,(loops_per_sec/5000) % 100,ct60_arg->speed_fan);
				else
					sprintf(t_edinfo->te_ptext,"æP: %3lu.%02lu Mips",loops_per_sec/500000,(loops_per_sec/5000) % 100);
				display_objc(MENUMIPS,Work);	
				break;
#ifndef LIGHT
			case MENUBLANG:
				objc_offset(rs_object,MENUBLANG,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBLANG].ob_width;
				menu.g_h=rs_object[MENUBLANG].ob_height;
				ret=(*Xcpb->Popup)(lang,7,language,IBM,&menu,Work);
				if(ret>=0 && ret!=language)
				{
					t_edinfo=rs_object[MENUBLANG].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_lang[ret];
					display_objc(MENUBLANG,Work);
					language=ret;
				}		
				break;
			case MENUBKEY:
				objc_offset(rs_object,MENUBKEY,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBKEY].ob_width;
				menu.g_h=rs_object[MENUBKEY].ob_height;
				ret=(*Xcpb->Popup)(key,9,keyboard,IBM,&menu,Work);
				if(ret>=0 && ret!=keyboard)
				{
					t_edinfo=rs_object[MENUBKEY].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_key[ret];
					display_objc(MENUBKEY,Work);
					keyboard=ret;
				}		
				break;
			case MENUBDATE:
				objc_offset(rs_object,MENUBDATE,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBDATE].ob_width;
				menu.g_h=rs_object[MENUBDATE].ob_height;
				ret=(*Xcpb->Popup)(date,4,datetime & 3,IBM,&menu,Work);
				if(ret>=0 && ret!=(datetime & 3))
				{
					t_edinfo=rs_object[MENUBDATE].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_date[ret];
					display_objc(MENUBDATE,Work);
					datetime &= ~3;
					datetime |= ret;
				}
				break;
			case MENUBTIME:
				objc_offset(rs_object,MENUBTIME,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBTIME].ob_width;
				menu.g_h=rs_object[MENUBTIME].ob_height;
				ret=(*Xcpb->Popup)(_time,2,(datetime>>4) & 1,IBM,&menu,Work);
				if(ret>=0 && ret!=((datetime>>4) & 1))
				{
					t_edinfo=rs_object[MENUBTIME].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_time[ret];
					display_objc(MENUBTIME,Work);
					datetime &= 3;
					datetime |= (ret<<4);
				}
				break;
			case MENUBVIDEO:
				objc_offset(rs_object,MENUBVIDEO,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBVIDEO].ob_width;
				menu.g_h=rs_object[MENUBVIDEO].ob_height;
				i=0;
				if(vmode & VGA_FALCON)
					i++;
				ret=(*Xcpb->Popup)(video,2,i,IBM,&menu,Work);
				if(ret>=0 && ret!=(((vmode & VGA_FALCON)>>4) & 1))
				{
					if(ret && (vmode & COL80) && (vmode & 7)==4)
						ret=0;
					t_edinfo=rs_object[MENUBVIDEO].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_video[ret];
					display_objc(MENUBVIDEO,Work);
					if(ret)
					{
						vmode |= VGA_FALCON;
						vmode &= ~OVERSCAN;	
						change_objc(MENUOVERSCAN,NORMAL,Work);
					}
					else
						vmode &= ~VGA_FALCON;
				}		
				break;
			case MENUBMODE:
				objc_offset(rs_object,MENUBMODE,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBMODE].ob_width;
				menu.g_h=rs_object[MENUBMODE].ob_height;
				i=0;
				if(vmode & PAL)
					i++;
				ret=(*Xcpb->Popup)(mode,2,i,IBM,&menu,Work);
				if(ret>=0 && ret!=(((vmode & PAL)>>5) & 1))
				{
					t_edinfo=rs_object[MENUBMODE].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_mode[ret];
					display_objc(MENUBMODE,Work);
					if(ret)
						vmode |= PAL;
					else
						vmode &= ~PAL;
				}		
				break;		
			case MENUBCOUL:
				objc_offset(rs_object,MENUBCOUL,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBCOUL].ob_width;
				menu.g_h=rs_object[MENUBCOUL].ob_height;
				ret=(*Xcpb->Popup)(coul,5,vmode & 7,IBM,&menu,Work);
				if(ret>=0 && ret!=(vmode & 7))
				{
					if(!(vmode & COL80) && ret==0)
						ret++;
					if((vmode & COL80) && (vmode & VGA_FALCON) && ret==4)
						ret--;
					t_edinfo=rs_object[MENUBCOUL].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_coul[ret];
					display_objc(MENUBCOUL,Work);
					vmode &= ~7;
					vmode |= ret;
				}		
				break;
			case MENUBRES:
				objc_offset(rs_object,MENUBRES,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBRES].ob_width;
				menu.g_h=rs_object[MENUBRES].ob_height;
				i=0;
				if(vmode & COL80)
					i+=2;
				if(!(vmode & VERTFLAG) && (vmode & VGA_FALCON))
					i++;
				if((vmode & VERTFLAG) && !(vmode & VGA_FALCON))
					i++;
				ret=(*Xcpb->Popup)(res,4,i,IBM,&menu,Work);					
				if(ret>=0 && ret!=i)
				{
					if(ret<2)
					{
						if((vmode & 7)==0)
							ret+=2;					
					}
					else
					{
						if((vmode & VGA_FALCON) && (vmode & 7)==4)
							ret-=2;
					}
					t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_res[ret];
					display_objc(MENUBRES,Work);
					switch(ret)
					{
					case 0:
						vmode &= ~COL80;
						if(vmode & VGA_FALCON)
							vmode |= VERTFLAG;
						else
							vmode &= ~VERTFLAG;
						break;
					case 1:
						vmode &= ~COL80;
						if(vmode & VGA_FALCON)
							vmode &= ~VERTFLAG;
						else
							vmode |= VERTFLAG;
						break;	
					case 2:
						vmode |= COL80;
						if(vmode & VGA_FALCON)
							vmode |= VERTFLAG;
						else
							vmode &= ~VERTFLAG;
						break;		
					case 3:
						vmode |= COL80;				
						if(vmode & VGA_FALCON)
							vmode &= ~VERTFLAG;
						else
							vmode |= VERTFLAG;
						break;
					}
				}		
				break;		
			case MENUSTMODES:
				if(rs_object[MENUSTMODES].ob_state & SELECTED)		
					vmode |= STMODES;
				else
					vmode &= ~STMODES;
				break;
			case MENUOVERSCAN:
				if(rs_object[MENUOVERSCAN].ob_state & SELECTED)		
				{
					if(!(vmode & VGA_FALCON))
						vmode |= OVERSCAN;
					else
						change_objc(MENUOVERSCAN,NORMAL,Work);
				}
				else
					vmode &= ~OVERSCAN;
				break;
#endif
			case MENUBBOOTORDER:
				objc_offset(rs_object,MENUBBOOTORDER,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBBOOTORDER].ob_width;
				menu.g_h=rs_object[MENUBBOOTORDER].ob_height;
				ret=(*Xcpb->Popup)(boot_order[start_lang],2,bootorder,IBM,&menu,Work);
				if(ret>=0 && ret!=bootorder)
				{
					t_edinfo=rs_object[MENUBBOOTORDER].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_boot_order[start_lang][ret];
					display_objc(MENUBBOOTORDER,Work);				
					bootorder=ret;
				}
				break;
			case MENUBOS:
				objc_offset(rs_object,MENUBOS,&menu.g_x,&menu.g_y);
					menu.g_w=rs_object[MENUBOS].ob_width;
				menu.g_h=rs_object[MENUBOS].ob_height;
				ret=(*Xcpb->Popup)(os,6,bootpref,IBM,&menu,Work);
				if(ret>=0 && ret!=bootpref)
				{
					t_edinfo=rs_object[MENUBOS].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_os[ret];
					display_objc(MENUBOS,Work);
					bootpref=ret;
				}
				break;
			case MENUBARBIT:
				objc_offset(rs_object,MENUBARBIT,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBARBIT].ob_width;
				menu.g_h=rs_object[MENUBARBIT].ob_height;
				ret=(*Xcpb->Popup)(arbit[start_lang],2,(scsi>>7) & 1,IBM,&menu,Work);
				if(ret>=0 && ret!=((scsi>>7) & 1))
				{
					t_edinfo=rs_object[MENUBARBIT].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_arbit[start_lang][ret];
					display_objc(MENUBARBIT,Work);
					scsi &= 0x7f;
					if(ret)
						scsi |= 0x80;
				}
				break;
			case MENUBIDSCSI:
				objc_offset(rs_object,MENUBIDSCSI,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBIDSCSI].ob_width;
				menu.g_h=rs_object[MENUBIDSCSI].ob_height;
				ret=(*Xcpb->Popup)(idscsi,8,scsi & 7,IBM,&menu,Work);
				if(ret>=0 && ret!=(scsi & 7))
				{
					t_edinfo=rs_object[MENUBIDSCSI].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_idscsi[ret];
					display_objc(MENUBIDSCSI,Work);
					scsi &= ~7;
					scsi |= ret;
				}
				break;
			case MENUBBLITTER:
				objc_offset(rs_object,MENUBBLITTER,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBBLITTER].ob_width;
				menu.g_h=rs_object[MENUBBLITTER].ob_height;
				ret=(*Xcpb->Popup)(blitter_speed[start_lang],2,blitterspeed,IBM,&menu,Work);
				if(ret>=0 && ret!=blitterspeed)
				{
					t_edinfo=rs_object[MENUBBLITTER].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_blitter_speed[start_lang][ret];
					display_objc(MENUBBLITTER,Work);				
					blitterspeed=ret;
				}
				break;
			case MENUBTOSRAM:
				objc_offset(rs_object,MENUBTOSRAM,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBTOSRAM].ob_width;
				menu.g_h=rs_object[MENUBTOSRAM].ob_height;
				ret=(*Xcpb->Popup)(tos_ram[start_lang],2,tosram,IBM,&menu,Work);
				if(ret>=0 && ret!=tosram)
				{
					t_edinfo=rs_object[MENUBTOSRAM].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_tos_ram[start_lang][ret];
					display_objc(MENUBTOSRAM,Work);				
					tosram=ret;
				}
				break;
			case MENUBCACHE:
				objc_offset(rs_object,MENUBCACHE,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBCACHE].ob_width;
				menu.g_h=rs_object[MENUBCACHE].ob_height;
				ret=(*Xcpb->Popup)(cache_delay[start_lang],4,cachedelay,IBM,&menu,Work);
				if(ret>=0 && ret!=cachedelay)
				{
					t_edinfo=rs_object[MENUBCACHE].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_cache_delay[start_lang][ret];
					display_objc(MENUBCACHE,Work);				
					cachedelay=ret;
				}
				break;
			case MENUBDAY:
				objc_offset(rs_object,MENUBDAY,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBDAY].ob_width;
				menu.g_h=rs_object[MENUBDAY].ob_height;
				ret=(*Xcpb->Popup)(day_stop[start_lang],11,daystop,IBM,&menu,Work);
				if(ret>=0 && ret!=daystop)
				{
					t_edinfo=rs_object[MENUBDAY].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_day_stop[start_lang][ret];
					display_objc(MENUBDAY,Work);
					daystop=ret;
				}
				break;			
			case MENUBSAVE:
				head->cpxhead.flags.resident=head->cpxhead.flags.bootinit=1;
				header->language=code_lang[language];
				header->keyboard=code_key[keyboard];
				header->datetime=(unsigned char)datetime;
				t_edinfo=rs_object[MENUSEP].ob_spec.tedinfo;
				header->separator=t_edinfo->te_ptext[0];
				header->vmode=(unsigned int)vmode;
				header->bootpref=(unsigned int)code_os[bootpref];
				header->scsi=(unsigned char)scsi;
				t_edinfo=rs_object[MENUDELAY].ob_spec.tedinfo;
				header->bootdelay=(unsigned char)atoi(t_edinfo->te_ptext);
				header->blitterspeed=(unsigned char)blitterspeed;
				header->tosram=(unsigned char)tosram;
				header->cachedelay=(unsigned char)cachedelay;
				header->bootorder=(unsigned char)bootorder;
				t_edinfo=rs_object[MENUTRIGGER].ob_spec.tedinfo;
				header->trigger_temp=(unsigned int)atoi(t_edinfo->te_ptext);
				header->daystop=daystop;
				t_edinfo=rs_object[MENUTIME].ob_spec.tedinfo;				
				header->timestop=(((unsigned int)atoi(t_edinfo->te_ptext)/100)<<11)
				                +(((unsigned int)atoi(t_edinfo->te_ptext)%100)<<5);
				save_header();
				change_objc(MENUBSAVE,NORMAL,Work);
				break;
 			case MENUBLOAD:
		 		if(!start_lang)
					ret=form_alert(1,"[2][Charger les|r‚glages sauv‚s ?][Charger|Annuler]");
				else
					ret=form_alert(1,"[2][Load saved parameters?][Load|Cancel]");
				if(ret==1)
				{
					if(test_060())
						selection=PAGE_TEMP;
					else				/* read temperature not works in normal mode */
						selection=PAGE_MEMORY;
					t_edinfo=rs_object[MENUBSELECT].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_select[start_lang][selection];
					language=0;
					if(header->language<9)
					{
						while(language<7 && header->language!=code_lang[language])
						language++;
						if(language>=7)
							language=0;	
					}
					keyboard=0;
					if(header->keyboard<9)
					{
						while(keyboard<8 && header->keyboard!=code_key[keyboard])
							keyboard++;
						if(keyboard>=8)
							keyboard=0;
					}
					datetime=(int)header->datetime;
					vmode=(int)header->vmode;
#ifndef LIGHT
					t_edinfo=rs_object[MENUBLANG].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_lang[language];
					t_edinfo=rs_object[MENUBKEY].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_key[keyboard];
					t_edinfo=rs_object[MENUBDATE].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_date[datetime & 3];
					t_edinfo=rs_object[MENUBTIME].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_time[(datetime>>4) & 1];
					t_edinfo=rs_object[MENUSEP].ob_spec.tedinfo;
					t_edinfo->te_ptext[0]=header->separator;
					t_edinfo=rs_object[MENUBVIDEO].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_video[((vmode & VGA_FALCON)>>4) & 1];
					t_edinfo=rs_object[MENUBMODE].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_mode[((vmode & PAL)>>5) & 1];
					t_edinfo=rs_object[MENUBCOUL].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_coul[vmode & 7];
					i=0;
					if(vmode & COL80)
						i+=2;
					if(!(vmode & VERTFLAG) && (vmode & VGA_FALCON))
						i++;
					if((vmode & VERTFLAG) && !(vmode & VGA_FALCON))
						i++;
					t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_res[i];
					if((vmode & OVERSCAN) && !(vmode & VGA_FALCON))
						rs_object[MENUOVERSCAN].ob_state |= SELECTED;
					else
						rs_object[MENUOVERSCAN].ob_state &= ~SELECTED;		
					if(vmode & STMODES)
						rs_object[MENUSTMODES].ob_state |= SELECTED;
					else
						rs_object[MENUSTMODES].ob_state &= ~SELECTED;		
#endif
					bootpref=0;
					while(bootpref<6 && header->bootpref!=(int)code_os[bootpref])
						bootpref++;
					if(bootpref>=6)
						bootpref=0;	
					t_edinfo=rs_object[MENUBOS].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_os[bootpref];
					scsi=(int)header->scsi;
					i=0;
					if(scsi & 0x80)
						i++;
					t_edinfo=rs_object[MENUBARBIT].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_arbit[start_lang][i];
					t_edinfo=rs_object[MENUBIDSCSI].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_idscsi[scsi & 7];
					bootdelay=(int)header->bootdelay;
					if(bootdelay>99)
						bootdelay=99;
					t_edinfo=rs_object[MENUDELAY].ob_spec.tedinfo;
					sprintf(t_edinfo->te_ptext,"%d",bootdelay);
					blitterspeed=(int)header->blitterspeed;
					t_edinfo=rs_object[MENUBBLITTER].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_blitter_speed[start_lang][blitterspeed];
					tosram=(int)header->tosram;
					t_edinfo=rs_object[MENUBTOSRAM].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_tos_ram[start_lang][tosram];
					cachedelay=(int)header->cachedelay;
					t_edinfo=rs_object[MENUBCACHE].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_cache_delay[start_lang][cachedelay];
					bootorder=(int)header->bootorder;					
					t_edinfo=rs_object[MENUBBOOTORDER].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_boot_order[start_lang][bootorder];
					trigger_temp=header->trigger_temp;
					if(trigger_temp==0)
						trigger_temp=(MAX_TEMP*3)/4;
					if(trigger_temp>99)
						trigger_temp=99;
					t_edinfo=rs_object[MENUTRIGGER].ob_spec.tedinfo;
					sprintf(t_edinfo->te_ptext,"%d",trigger_temp);			
					daystop=header->daystop;
					if(daystop>11)
						daystop=0;	
					t_edinfo=rs_object[MENUBDAY].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_day_stop[start_lang][daystop];
					t_edinfo=rs_object[MENUTIME].ob_spec.tedinfo;
					timestop=header->timestop;					
					i=(((timestop>>11) & 0x1f) * 100) + ((timestop>>5) & 0x3f);
					if(i>2359)
						i=2359;	
					sprintf(t_edinfo->te_ptext,"%04d",i);
					display_objc(MENUBSELECT,Work);
					display_selection(selection,1);
				}
				change_objc(MENUBLOAD,NORMAL,Work);
				break;
			case MENUBOK:
#ifndef LIGHT
				nvram.language=code_lang[language];
				nvram.keyboard=code_key[keyboard];
				nvram.datetime=(unsigned char)datetime;
				t_edinfo=rs_object[MENUSEP].ob_spec.tedinfo;
				nvram.separator=t_edinfo->te_ptext[0];
				nvram.vmode=(unsigned int)vmode;
#endif
				nvram.bootpref=(unsigned int)code_os[bootpref];
				nvram.scsi=(unsigned char)scsi;
				t_edinfo=rs_object[MENUDELAY].ob_spec.tedinfo;
				nvram.bootdelay=(unsigned char)atoi(t_edinfo->te_ptext);
				NVMaccess(1,0,(int)(sizeof(NVM)),&nvram);		/* write */			
				if(flag_xbios)
				{
					tosram=ct60_rw_parameter(CT60_MODE_WRITE,CT60_PARAM_TOSRAM,(long)tosram);
					blitterspeed=ct60_rw_parameter(CT60_MODE_WRITE,CT60_BLITTER_SPEED,(long)blitterspeed);
					cachedelay=ct60_rw_parameter(CT60_MODE_WRITE,CT60_CACHE_DELAY,(long)cachedelay);
					bootorder=ct60_rw_parameter(CT60_MODE_WRITE,CT60_BOOT_ORDER,(long)bootorder);
				}
				else
				{
					stack=Super(0L);
					tosram=ct60_rw_param(CT60_MODE_WRITE,CT60_PARAM_TOSRAM,(long)tosram);
					blitterspeed=ct60_rw_param(CT60_MODE_WRITE,CT60_BLITTER_SPEED,(long)blitterspeed);
					cachedelay=ct60_rw_param(CT60_MODE_WRITE,CT60_CACHE_DELAY,(long)cachedelay);
					bootorder=ct60_rw_param(CT60_MODE_WRITE,CT60_BOOT_ORDER,(long)bootorder);
					Super((void *)stack);
				}
				if(tosram<0 || blitterspeed<0 || cachedelay<0 || bootorder<0)
				{
					if(tosram==-15 || blitterspeed==-15 || cachedelay==-15 || bootorder==-15)   /* error device */
					{
						if(!start_lang)
							form_alert(1,"[1][Type de flash|inconnu !][OK]");
						else
							form_alert(1,"[1][Unknow flash|device!][OK]");
					}
					else
					{
						if(!start_lang)
							form_alert(1,"[1][Erreur ‚criture|paramŠtre en flash !][OK]");
						else
							form_alert(1,"[1][Error writing parameters|to flash!][OK]");
					}
				}
				rs_object[MENUBOK].ob_state &= ~SELECTED;
				*event=1;	/* end */
				cpx_close(0);
				break;
			case MENUBCANCEL:
				rs_object[MENUBCANCEL].ob_state &= ~SELECTED;
				*event=1;	/* end */
				cpx_close(0);
				break;
			case MENUBINFO:
				change_objc(MENUBINFO,NORMAL,Work);
				if((info_tree=adr_tree(TREE2))!=0)
				{
					if(hndl_form(info_tree,0)==INFOHELP)
						call_st_guide();
				}
				break;
			}
		}
	}
}

void CDECL cpx_close(int flag)

{
	int x,y,m,k;
	if(flag);
	objc_edit(rs_object,ed_objc,0,&ed_pos,ED_END);
	v_clsvwk(vdi_handle);
}

int init_rsc(void)

{
	OBJECT *info_tree,*alert_tree;
	BITBLK *b_itblk;
	char **rs_str;
	register int h;
	if(rs_object[MENUBINFO].ob_height==1)
	/* flag SkipRshFix is bugged with XCONTROL and ZCONTROL when it's used in cpx_init */
	{
#ifdef DEBUG
		printf("\r\nInit RSC");
#endif		
		if((nvram.language==FRA) || (nvram.language==SWF))
		{
			start_lang=0;

			rs_str=rs_strings;
		}
		else
		{
			start_lang=1;
			rs_str=rs_strings_en;
		}
		(*Xcpb->rsh_fix)(NUM_OBS,NUM_FRSTR,NUM_FRIMG,NUM_TREE,rs_object,rs_tedinfo,rs_str,rs_iconblk,rs_bitblk,rs_frstr,rs_frimg,rs_trindex,rs_imdope);
		if(rs_object[MENUBINFO].ob_height==1)
			return(0);	/* error */
		else
		{
			gr_hwchar=rs_object[MENUBINFO].ob_width>>1;
			gr_hhchar=rs_object[MENUBINFO].ob_height;
			h=gr_hhchar>>1;
			rs_object[MENUBSELECT].ob_y+=2;
			rs_object[MENUBOXSTATUS].ob_y+=(h+1);
			rs_object[MENUBOXSTATUS].ob_height+=h;
			rs_object[MENUTEMP-1].ob_y-=h;
			rs_object[MENUTEMP].ob_y-=h;		
			rs_object[MENUBARTEMP+1].ob_height=rs_object[MENUBARTEMP+2].ob_height=rs_object[MENUBARTEMP+3].ob_height=h;
			rs_object[MENUTRIGGER].ob_y-=h;
			rs_object[MENUTRACE].ob_x+=6;
			rs_object[MENUTRACE].ob_y=(7*gr_hhchar)>>2;
			rs_object[MENUTRACE].ob_height=gr_hhchar<<2;
			rs_object[MENUTRACE+1].ob_height=rs_object[MENUTRACE+2].ob_height=rs_object[MENUTRACE+3].ob_height=rs_object[MENUTRACE+4].ob_height=6;
			rs_object[MENUTRACE+2].ob_width=rs_object[MENUTRACE+3].ob_width=rs_object[MENUTRACE+4].ob_width=12;	
			rs_object[MENUTRACE+2].ob_x++;
			rs_object[MENUTRACE+3].ob_x++;
			rs_object[MENUTRACE+4].ob_x++;
			rs_object[MENUTRACE+4].ob_y+=h;
			rs_object[MENUBOXRAM].ob_y+=(h+1);
			rs_object[MENUBOXRAM].ob_height+=h;
			rs_object[MENUBOXLANG].ob_y+=(h+1);
			rs_object[MENUBOXLANG].ob_height+=h;
			rs_object[MENUBLANG-1].ob_y-=h;
			rs_object[MENUBLANG].ob_y-=h;
			rs_object[MENUBDATE-1].ob_y+=h;
			rs_object[MENUBDATE].ob_y+=h;
			rs_object[MENUBOXVIDEO].ob_y+=(h+1);
			rs_object[MENUBOXVIDEO].ob_height+=h;
			rs_object[MENUBVIDEO-1].ob_y-=h;
			rs_object[MENUBVIDEO].ob_y-=h;
			rs_object[MENUBMODE-1].ob_y-=h;
			rs_object[MENUBMODE].ob_y-=h;		
			rs_object[MENUBRES-1].ob_y+=h;
			rs_object[MENUBRES].ob_y+=h;
			rs_object[MENUBOXBOOT].ob_y+=(h+1);
			rs_object[MENUBOXBOOT].ob_height+=h;
			rs_object[MENUBBOOTORDER].ob_y-=h;
			rs_object[MENUBOS-1].ob_y-=h;
			rs_object[MENUBOS].ob_y-=h;
			rs_object[MENUDELAY].ob_y+=h;
			rs_object[MENUBBLITTER-1].ob_y+=h;
			rs_object[MENUBBLITTER].ob_y+=h;
			rs_object[MENUBOXSTOP].ob_y+=(h+1);
			rs_object[MENUBOXSTOP].ob_height+=h;
			
			rs_object[MENUBSAVE].ob_y+=h;
			rs_object[MENUBLOAD].ob_y+=h;
			rs_object[MENUBOK].ob_y+=h;
			rs_object[MENUBCANCEL].ob_y+=h;
			rs_object[MENUBINFO].ob_y+=h;
			if((info_tree=adr_tree(TREE2))!=0)
			{
				b_itblk=info_tree[INFOLOGO].ob_spec.bitblk;
				b_itblk->bi_pdata=(int *)pic_logo;
			}
			if((alert_tree=adr_tree(TREE3))!=0)
			{
				b_itblk=alert_tree[ALERTNOTE].ob_spec.bitblk;
				b_itblk->bi_pdata=(int *)pic_note;
				b_itblk=alert_tree[ALERTWAIT].ob_spec.bitblk;
				b_itblk->bi_pdata=(int *)pic_wait;
				b_itblk=alert_tree[ALERTSTOP].ob_spec.bitblk;
				b_itblk->bi_pdata=(int *)pic_stop;
			}
			if(!mint && !magic)
			{
				buffer_bubble=(char *)Mxalloc(256L,3);		/* normal memory */
				buffer_path=(char *)Mxalloc(256L,3);
			}
			else
			{
				buffer_bubble=(char *)Mxalloc(256L,0x23);	/* global memory */
				buffer_path=(char *)Mxalloc(256L,0x23);
			}
		}
	}
	return(1);	/* OK */
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

int cdecl trace_temp(PARMBLK *parmblock)

{
	register int i,color,temp,temp2,x,y,w,h;
	int tab_clip[4],tab_l[10],tab_f[4],attrib_l[6],attrib_f[5],xy[6];
	unsigned short *p;
	if(	parmblock->pb_prevstate==parmblock->pb_currstate)
	{
		tab_clip[0]=parmblock->pb_xc;
		tab_clip[1]=parmblock->pb_yc;
		tab_clip[2]=parmblock->pb_wc+tab_clip[0]-1;
		tab_clip[3]=parmblock->pb_hc+tab_clip[1]-1;
		vs_clip(vdi_handle,1,tab_clip);			/* clipping */
		tab_f[0]=x=parmblock->pb_x;
		tab_f[1]=y=parmblock->pb_y;
		w=parmblock->pb_w;
		h=parmblock->pb_h;
		tab_f[2]=w+tab_f[0]-1;
		tab_f[3]=h+tab_f[1]-1;
		tab_l[0]=tab_l[2]=tab_l[8]=tab_f[0]-1;
		tab_l[1]=tab_l[7]=tab_l[9]=tab_f[1]-1;
		tab_l[3]=tab_l[5]=tab_f[3]+1;
		tab_l[4]=tab_l[6]=tab_f[2]+1;
		vql_attributes(vdi_handle,attrib_l);	/* save lines attributes */
		vqf_attributes(vdi_handle,attrib_f);	/* save filling attributes */
		vsl_type(vdi_handle,1);
		vsl_color(vdi_handle,WHITE);			/* color line */
		vswr_mode(vdi_handle,MD_REPLACE);
		vsl_ends(vdi_handle,0,0);
		vsl_width(vdi_handle,1);
		vsf_interior(vdi_handle,1);				/* color */
		vsf_color(vdi_handle,BLACK);
		vsf_perimeter(vdi_handle,1);
		vr_recfl(vdi_handle,tab_f);
		v_pline(vdi_handle,5,tab_l);			/* border */
		vswr_mode(vdi_handle,MD_TRANS);
		vsl_type(vdi_handle,3);					/* type line: dotted line */
		for(i=10;i<60;i+=10)					/* vertical square */
		{
			xy[0]=xy[2]=x+((i * w) / 60);
			xy[1]=y;
			xy[3]=y+h-1;
			v_pline(vdi_handle,2,xy);
 		}
		p=(unsigned short *)parmblock->pb_parm;	/* trace */
		if(p==tab_cpuload)						/* cpu_load */
		{
			for(i=20;i<100;i+=20)				/* horizontal square */
			{
				xy[0]=x;
				xy[1]=xy[3]=y+h-((i * h) / 100);
				xy[2]=x+w-1;
				v_pline(vdi_handle,2,xy);
			}
			vsl_type(vdi_handle,1);				/* type line: full line */
			for(i=0;i<60;i++)					/* trace */
			{
				temp = (int)*p++;
				temp2 =(int)*p;
				vsl_color(vdi_handle,CYAN);
				xy[0]=x+((i * w) / 60);
				xy[1]=y+h-(int)(((long)temp * (long)h) / (long)MAX_CPULOAD);
				xy[2]=x+(((i+1) * w) / 60);
				xy[3]=y+h-(int)(((long)temp2 * (long)h) / (long)MAX_CPULOAD);
				v_pline(vdi_handle,2,xy);
			}
		}
		else									/* temperature */            
		{
			for(i=20;i<MAX_TEMP;i+=20)				/* horizontal square */
			{
				xy[0]=x;
				xy[1]=xy[3]=y+h-((i * h) / MAX_TEMP);
				xy[2]=x+w-1;
				v_pline(vdi_handle,2,xy);
			}
			vsl_type(vdi_handle,1);					/* type line: full line */
			if(p==tab_temp && eiffel_temp!=NULL)
			{
				p=tab_temp_eiffel;
				for(i=0;i<60;i++)					/* trace */
				{
					temp = (int)(*p++ & 0x3F);
					temp2 = (int)(*p & 0x3F);
					if(*p & 0x8000)					/* motor on */
						vsl_color(vdi_handle,MAGENTA);
					else
						vsl_color(vdi_handle,BLUE);
					xy[0]=x+((i * w) / 60);
					xy[1]=y+h-(int)(((long)temp * (long)h) / MAX_TEMP);
					xy[2]=x+(((i+1) * w) / 60);
					xy[3]=y+h-(int)(((long)temp2 * (long)h) / MAX_TEMP);
					v_pline(vdi_handle,2,xy);
				}
				p=tab_temp;
			}
			for(i=0;i<60;i++)						/* trace */
			{
				temp = (int)*p++;
				temp2 = (int)*p;
				if(temp < MAX_TEMP/3)
					color=GREEN;
				else
				{
					if(temp < (MAX_TEMP*2)/3)
						color=YELLOW;
					else
						color=RED;
				}
				vsl_color(vdi_handle,color);	/* beginning with the 1st color */
				xy[0]=x+((i * w) / 60);
				xy[1]=y+h-((temp * h) / MAX_TEMP);
				xy[4]=x+(((i+1) * w) / 60);
				xy[5]=y+h-((temp2 * h) / MAX_TEMP);
				xy[2]=(xy[0]+xy[4])>>1;
				xy[3]=(xy[1]+xy[5])>>1;
				v_pline(vdi_handle,2,xy);		/* 1st segment */
				if(temp2 < MAX_TEMP/3)
					color=GREEN;
				else
				{
					if(temp2 < (MAX_TEMP*2)/3)
						color=YELLOW;
					else
						color=RED;
				}
				vsl_color(vdi_handle,color);	/* end maybe with 2nd color */
				v_pline(vdi_handle,2,&xy[2]);	/* 2nd segment */
			}
		}		
		vs_clip(vdi_handle,0,tab_clip);
		vsl_type(vdi_handle,attrib_l[0]);		/* restore: type line */
		vsl_color(vdi_handle,attrib_l[1]);				/* color line */
		vswr_mode(vdi_handle,attrib_l[2]);				/* graphic modec */
		vsl_ends(vdi_handle,attrib_l[3],attrib_l[4]);	/* line aspect */
		vsl_width(vdi_handle,attrib_l[5]);				/* width line */
		vsf_interior(vdi_handle,attrib_f[0]);			/* type filling */
		vsf_color(vdi_handle,attrib_f[1]);				/* color fillinge */
		vsf_style(vdi_handle,attrib_f[2]);				/* motif filling */
		vsf_perimeter(vdi_handle,attrib_f[4]);			/* state border */
	}
	return(0);
}

int cdecl cpu_load(PARMBLK *parmblock)

{
	register int i,scale,x,y,w,h;
	int tab_clip[4],tab_f[4],attrib_l[6],attrib_f[5],xy[4];
	unsigned int *p;
	if(	parmblock->pb_prevstate==parmblock->pb_currstate)
	{
		tab_clip[0]=parmblock->pb_xc;
		tab_clip[1]=parmblock->pb_yc;
		tab_clip[2]=parmblock->pb_wc+tab_clip[0]-1;
		tab_clip[3]=parmblock->pb_hc+tab_clip[1]-1;
		vs_clip(vdi_handle,1,tab_clip);			/* clipping */
		tab_f[0]=x=parmblock->pb_x;
		tab_f[1]=y=parmblock->pb_y;
		w=parmblock->pb_w;
		h=parmblock->pb_h;
		tab_f[2]=w+tab_f[0]-1;
		tab_f[3]=h+tab_f[1]-1;
		vql_attributes(vdi_handle,attrib_l);	/* save lines attributes */
		vqf_attributes(vdi_handle,attrib_f);	/* save filling attributes */
		vsl_type(vdi_handle,1);
		vsl_color(vdi_handle,CYAN);				/* color line */
		vswr_mode(vdi_handle,MD_REPLACE);
		vsl_ends(vdi_handle,0,0);
		vsl_width(vdi_handle,1);
		vsf_interior(vdi_handle,1);				/* color */
		vsf_color(vdi_handle,BLACK);
		vsf_perimeter(vdi_handle,1);
		vr_recfl(vdi_handle,tab_f);
		scale=(int)((parmblock->pb_parm*((long)w-3L))/100L);
		if(scale > w-3)
			scale=w-3;
		xy[1]=y+3;
		xy[3]=y+h-4;
		for(i=3;i<scale;i+=4)
		{
			xy[0]=xy[2]=x+i;	
			v_pline(vdi_handle,2,xy);
			xy[0]++;
			xy[2]++;
			v_pline(vdi_handle,2,xy);
		}
		vs_clip(vdi_handle,0,tab_clip);
		vsl_type(vdi_handle,attrib_l[0]);		/* restore: type line */
		vsl_color(vdi_handle,attrib_l[1]);				/* color line */
		vswr_mode(vdi_handle,attrib_l[2]);				/* graphic modec */
		vsl_ends(vdi_handle,attrib_l[3],attrib_l[4]);	/* line aspect */
		vsl_width(vdi_handle,attrib_l[5]);				/* width line */
		vsf_interior(vdi_handle,attrib_f[0]);			/* type filling */
		vsf_color(vdi_handle,attrib_f[1]);				/* color fillinge */
		vsf_style(vdi_handle,attrib_f[2]);				/* motif filling */
		vsf_perimeter(vdi_handle,attrib_f[4]);			/* state border */
	}
	return(0);
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

HEAD *fix_header(void)
{
	HEAD *header;
	header=(HEAD *)head->cpxhead.buffer;
	if(header->bootpref==0 && header->language==0 && header->keyboard==0
	 && header->datetime==0 && header->separator==0 && header->bootdelay==0
	 && header->vmode==0 && header->scsi==0 && header->tosram==0
	 && header->trigger_temp==0 && header->daystop==0 && header->timestop==0
	 && header->blitterspeed==0 && header->cachedelay==0 && header->bootorder==0)
		*header=config;	/* buffer of header is always to 0 with ZCONTROL */
	return(header);
}

void save_header(void)

{
	HEAD *header;
	if((*Xcpb->XGen_Alert)(SAVE_DEFAULTS))
	{
		header=(HEAD *)head->cpxhead.buffer;
		if(((*Xcpb->Save_Header)(head))==0) /* not works with ZCONTROL */
			(*Xcpb->XGen_Alert)(FILE_ERR);
		config=*header;
		if(((*Xcpb->CPX_Save)((void *)&config,sizeof(HEAD)))==0)
			(*Xcpb->XGen_Alert)(FILE_ERR);	
	}
}

void display_selection(int selection,int flag_aff)

{
	static char *status[2][2]={" Charge CPU "," Temp‚rature ",
	                           " CPU load "," Temperature "};
	TEDINFO *t_edinfo;
	if(flag_aff)
		display_objc(MENUBSELECT+1,Work);
	switch(selection)
	{
	case PAGE_CPULOAD:			/* average load */
		rs_object[MENUBOXSTATUS].ob_flags &= ~HIDETREE;
		rs_object[MENUSTATUS].ob_flags &= ~HIDETREE;
		t_edinfo=rs_object[MENUSTATUS].ob_spec.tedinfo;
		t_edinfo->te_ptext=status[start_lang][0];
		rs_object[MENUTEMP-1].ob_flags |= HIDETREE;
		t_edinfo=rs_object[MENUTEMP].ob_spec.tedinfo;
		sprintf(t_edinfo->te_ptext,"%3ld  ",spec_cpuload.ub_parm);
		t_edinfo->te_ptext[4]='%';
		rs_object[MENUTEMP].ob_x=gr_hwchar;
		rs_object[MENUBARTEMP].ob_type=G_USERDEF;
		rs_object[MENUBARTEMP].ob_spec.userblk=(USERBLK *)&spec_cpuload;
		rs_object[MENUBARTEMP].ob_x=gr_hwchar<<3;
		rs_object[MENUBARTEMP].ob_y=gr_hhchar>>1;
		rs_object[MENUBARTEMP].ob_width=gr_hwchar*23;
		rs_object[MENUBARTEMP].ob_height=gr_hhchar;
		rs_object[MENUBARTEMP+1].ob_flags |= HIDETREE;
		rs_object[MENUBARTEMP+2].ob_flags |= HIDETREE;
		rs_object[MENUBARTEMP+3].ob_flags |= HIDETREE;
		rs_object[MENUTRIGGER].ob_flags &= ~EDITABLE;
		rs_object[MENUTRIGGER].ob_flags |= HIDETREE;
		rs_object[MENUTRACE+2].ob_y=rs_object[MENUTRACE].ob_y+rs_object[MENUTRACE].ob_height
		                           -((80*rs_object[MENUTRACE].ob_height)/(MAX_CPULOAD/100))-2;
		rs_object[MENUTRACE+3].ob_y=rs_object[MENUTRACE].ob_y+rs_object[MENUTRACE].ob_height
		                           -((40*rs_object[MENUTRACE].ob_height)/(MAX_CPULOAD/100))-2;
		t_edinfo=rs_object[MENUTRACE+4].ob_spec.tedinfo;
		t_edinfo->te_ptext="0%";
		rs_object[MENUBOXRAM].ob_flags |= HIDETREE;
		rs_object[MENURAM].ob_flags |= HIDETREE;
		rs_object[MENUBOXLANG].ob_flags |= HIDETREE;
		rs_object[MENULANG].ob_flags |= HIDETREE;
		rs_object[MENUSEP].ob_flags &= ~EDITABLE;	
		rs_object[MENUBOXVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUBOXBOOT].ob_flags |= HIDETREE;
		rs_object[MENUBOOT].ob_flags |= HIDETREE;
		rs_object[MENUDELAY].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXSTOP].ob_flags |= HIDETREE;
		rs_object[MENUSTOP].ob_flags |= HIDETREE;
		rs_object[MENUTIME].ob_flags &= ~EDITABLE;
		spec_trace.ub_parm=(long)tab_cpuload;
		if(flag_aff)
		{	
			display_objc(MENUBOXSTATUS,Work);
			display_objc(MENUSTATUS,Work);
			new_objc=ed_objc=new_pos=ed_pos=0;
		}	
		break;
	case PAGE_TEMP:				/* temperature */
		rs_object[MENUBOXSTATUS].ob_flags &= ~HIDETREE;
		rs_object[MENUSTATUS].ob_flags &= ~HIDETREE;
		t_edinfo=rs_object[MENUSTATUS].ob_spec.tedinfo;
		t_edinfo->te_ptext=status[start_lang][1];
		rs_object[MENUTEMP-1].ob_flags &= ~HIDETREE;
		t_edinfo=rs_object[MENUTEMP].ob_spec.tedinfo;
		sprintf(t_edinfo->te_ptext,"%3d øC",read_temp());		
		rs_object[MENUTEMP].ob_x=gr_hwchar<<3;
		rs_object[MENUBARTEMP].ob_type=G_BOX;
		rs_object[MENUBARTEMP].ob_spec.index=(long)0xff11f1L;
		rs_object[MENUBARTEMP].ob_x=gr_hwchar*15;
		rs_object[MENUBARTEMP].ob_y=(gr_hhchar*3)>>2;
		rs_object[MENUBARTEMP].ob_width=gr_hwchar*6;
		rs_object[MENUBARTEMP].ob_height=gr_hhchar>>1;
		rs_object[MENUBARTEMP+1].ob_flags &= ~HIDETREE;
		if(rs_object[MENUBARTEMP+2].ob_width)
		{
			rs_object[MENUBARTEMP+2].ob_flags &= ~HIDETREE;
			if(rs_object[MENUBARTEMP+3].ob_width)
				rs_object[MENUBARTEMP+3].ob_flags &= ~HIDETREE;
			else
				rs_object[MENUBARTEMP+3].ob_flags |= HIDETREE;
		}
		else
		{
			rs_object[MENUBARTEMP+2].ob_flags |= HIDETREE;
			rs_object[MENUBARTEMP+3].ob_flags |= HIDETREE;
		}
		rs_object[MENUTRIGGER].ob_flags |= EDITABLE;
		rs_object[MENUTRIGGER].ob_flags &= ~HIDETREE;
		rs_object[MENUTRACE+2].ob_y=rs_object[MENUTRACE].ob_y+rs_object[MENUTRACE].ob_height
		                           -((80*rs_object[MENUTRACE].ob_height)/MAX_TEMP)-2;
		rs_object[MENUTRACE+3].ob_y=rs_object[MENUTRACE].ob_y+rs_object[MENUTRACE].ob_height
		                           -((40*rs_object[MENUTRACE].ob_height)/MAX_TEMP)-2;
		t_edinfo=rs_object[MENUTRACE+4].ob_spec.tedinfo;
		t_edinfo->te_ptext="0ø";
		rs_object[MENUBOXRAM].ob_flags |= HIDETREE;
		rs_object[MENURAM].ob_flags |= HIDETREE;
		rs_object[MENUBOXLANG].ob_flags |= HIDETREE;
		rs_object[MENULANG].ob_flags |= HIDETREE;
		rs_object[MENUSEP].ob_flags &= ~EDITABLE;	
		rs_object[MENUBOXVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUBOXBOOT].ob_flags |= HIDETREE;
		rs_object[MENUBOOT].ob_flags |= HIDETREE;
		rs_object[MENUDELAY].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXSTOP].ob_flags |= HIDETREE;
		rs_object[MENUSTOP].ob_flags |= HIDETREE;
		rs_object[MENUTIME].ob_flags &= ~EDITABLE;
		spec_trace.ub_parm=(long)tab_temp;
		if(flag_aff)
		{	
			display_objc(MENUBOXSTATUS,Work);
			display_objc(MENUSTATUS,Work);
			ed_objc=MENUTRIGGER;
			objc_edit(rs_object,ed_objc,0,&ed_pos,ED_INIT);
			new_objc=ed_objc;
			new_pos=ed_pos;
		}
		break;
	case PAGE_MEMORY:			/* memory */
		rs_object[MENUBOXSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUTRIGGER].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXRAM].ob_flags &= ~HIDETREE;
		rs_object[MENURAM].ob_flags &= ~HIDETREE;
		rs_object[MENUBOXLANG].ob_flags |= HIDETREE;
		rs_object[MENULANG].ob_flags |= HIDETREE;
		rs_object[MENUSEP].ob_flags &= ~EDITABLE;	
		rs_object[MENUBOXVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUBOXBOOT].ob_flags |= HIDETREE;
		rs_object[MENUBOOT].ob_flags |= HIDETREE;
		rs_object[MENUDELAY].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXSTOP].ob_flags |= HIDETREE;
		rs_object[MENUSTOP].ob_flags |= HIDETREE;
		rs_object[MENUTIME].ob_flags &= ~EDITABLE;
		if(flag_aff)
		{	
			display_objc(MENUBOXRAM,Work);
			display_objc(MENURAM,Work);
			new_objc=ed_objc=new_pos=ed_pos=0;
		}
		break;
	case PAGE_BOOT:				/* boot */
		rs_object[MENUBOXSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUTRIGGER].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXRAM].ob_flags |= HIDETREE;
		rs_object[MENURAM].ob_flags |= HIDETREE;
		rs_object[MENUBOXLANG].ob_flags |= HIDETREE;
		rs_object[MENULANG].ob_flags |= HIDETREE;
		rs_object[MENUSEP].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUBOXBOOT].ob_flags &= ~HIDETREE;
		rs_object[MENUBOOT].ob_flags &= ~HIDETREE;
		rs_object[MENUDELAY].ob_flags |= EDITABLE;
		rs_object[MENUBOXSTOP].ob_flags |= HIDETREE;
		rs_object[MENUSTOP].ob_flags |= HIDETREE;
		rs_object[MENUTIME].ob_flags &= ~EDITABLE;
		if(flag_aff)
		{
			display_objc(MENUBOXBOOT,Work);
			display_objc(MENUBOOT,Work);
			ed_objc=MENUDELAY;
			objc_edit(rs_object,ed_objc,0,&ed_pos,ED_INIT);
			new_objc=ed_objc;
			new_pos=ed_pos;
		}
		break;		
	case PAGE_STOP:				/* stop */
		rs_object[MENUBOXSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUTRIGGER].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXRAM].ob_flags |= HIDETREE;
		rs_object[MENURAM].ob_flags |= HIDETREE;
		rs_object[MENUBOXLANG].ob_flags |= HIDETREE;
		rs_object[MENULANG].ob_flags |= HIDETREE;
		rs_object[MENUSEP].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUBOXBOOT].ob_flags |= HIDETREE;
		rs_object[MENUBOOT].ob_flags |= HIDETREE;
		rs_object[MENUDELAY].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXSTOP].ob_flags &= ~HIDETREE;
		rs_object[MENUSTOP].ob_flags &= ~HIDETREE;
		rs_object[MENUTIME].ob_flags |= EDITABLE;
		if(flag_aff)
		{
			display_objc(MENUBOXSTOP,Work);
			display_objc(MENUSTOP,Work);
			ed_objc=MENUTIME;
			objc_edit(rs_object,ed_objc,0,&ed_pos,ED_INIT);
			new_objc=ed_objc;
			new_pos=ed_pos;
		}
		break;		
#ifndef LIGHT
	case PAGE_LANG:				/* language */
		rs_object[MENUBOXSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUTRIGGER].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXRAM].ob_flags |= HIDETREE;
		rs_object[MENURAM].ob_flags |= HIDETREE;
		rs_object[MENUBOXLANG].ob_flags &= ~HIDETREE;
		rs_object[MENULANG].ob_flags &= ~HIDETREE;
		rs_object[MENUSEP].ob_flags |= EDITABLE;
		rs_object[MENUBOXVIDEO].ob_flags |= HIDETREE;
		rs_object[MENUVIDEO].ob_flags |= HIDETREE;				
		rs_object[MENUBOXBOOT].ob_flags |= HIDETREE;
		rs_object[MENUBOOT].ob_flags |= HIDETREE;
		rs_object[MENUDELAY].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXSTOP].ob_flags |= HIDETREE;
		rs_object[MENUSTOP].ob_flags |= HIDETREE;
		rs_object[MENUTIME].ob_flags &= ~EDITABLE;		
		if(flag_aff)
		{
			display_objc(MENUBOXLANG,Work);
			display_objc(MENULANG,Work);
			ed_objc=MENUSEP;
			objc_edit(rs_object,ed_objc,0,&ed_pos,ED_INIT);
			new_objc=ed_objc;
			new_pos=ed_pos;
		}
		break;
	case PAGE_VIDEO:			/* video */
		rs_object[MENUBOXSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUSTATUS].ob_flags |= HIDETREE;
		rs_object[MENUTRIGGER].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXRAM].ob_flags |= HIDETREE;
		rs_object[MENURAM].ob_flags |= HIDETREE;
		rs_object[MENUBOXLANG].ob_flags |= HIDETREE;
		rs_object[MENULANG].ob_flags |= HIDETREE;
		rs_object[MENUSEP].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXVIDEO].ob_flags &= ~HIDETREE;
		rs_object[MENUVIDEO].ob_flags &= ~HIDETREE;
		rs_object[MENUBOXBOOT].ob_flags |= HIDETREE;
		rs_object[MENUBOOT].ob_flags |= HIDETREE;
		rs_object[MENUDELAY].ob_flags &= ~EDITABLE;
		rs_object[MENUBOXSTOP].ob_flags |= HIDETREE;
		rs_object[MENUSTOP].ob_flags |= HIDETREE;
		rs_object[MENUTIME].ob_flags &= ~EDITABLE;			
		if(flag_aff)
		{
			display_objc(MENUBOXVIDEO,Work);
			display_objc(MENUVIDEO,Work);
			new_objc=ed_objc=new_pos=ed_pos=0;
		}
		break;
#endif
	}
}

void change_objc(int objc,int state,GRECT *clip)

{
	switch(state)
	{
	case NORMAL:
		rs_object[objc].ob_state &= ~SELECTED;
		break;	
	case SELECTED:
		rs_object[objc].ob_state |= SELECTED;
		break;	
	default:
		rs_object[objc].ob_state=state;
		break;
	}
	display_objc(objc,clip);
}

void display_objc(int objc,GRECT *clip)

{
	register GRECT *rect;
	register int cursor=0;
	wind_update(BEG_UPDATE);
	if(objc==MENUBOX)
	{
		objc_edit(rs_object,ed_objc,0,&ed_pos,ED_END);		/* hide cursor */
		cursor=1;
	}
	rect=(GRECT *)(*Xcpb->GetFirstRect)(clip);
	while(rect)
	{
		objc_draw(rs_object,objc,MAX_DEPTH,rect);
		rect=(GRECT *)(*Xcpb->GetNextRect)();
	}
	if(cursor)
		objc_edit(rs_object,ed_objc,0,&ed_pos,ED_END);		/* showm cursor */
	wind_update(END_UPDATE);
}

void move_cursor(void)

{
	if(new_objc>0 && (ed_objc!=new_objc || ed_pos!=new_pos))
	{
		objc_edit(rs_object,ed_objc,0,&ed_pos,ED_END);		/* hide cursor */
		ed_pos=new_pos;
		objc_edit(rs_object,new_objc,0,&ed_pos,ED_CHAR);	/* new position of cursor */
		objc_edit(rs_object,new_objc,0,&ed_pos,ED_END);		/* showm cursor */
		ed_objc=new_objc;									/* new zone edited */
		ed_pos=new_pos;										/* new position cursor */
	}
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
	if(magic && flag_exit)				/* MagiC dialog */ 
	{
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

int MT_form_xalert(int fo_xadefbttn,char *fo_xastring,long time_out,void (*call)(),WORD *global)

{
	register int i,j,w,max_length_lines,max_length_buttons;
	register char *p;
	int flag_img,nb_lines,nb_buttons;
	int answer,event,ret,objc_clic,key,nclicks,new_objc;
	GRECT rect,kl_rect;
	OBJECT *alert_tree;
	TEDINFO *t_edinfo;
	EVNTDATA mouse;
	WORD msg[8];
	char line[5][61];
	char button[3][21];
	if((alert_tree=adr_tree(TREE3))==0)
		return(0);
	alert_tree[ALERTB1].ob_state &= ~SELECTED;
	alert_tree[ALERTB2].ob_state &= ~SELECTED;
	alert_tree[ALERTB3].ob_state &= ~SELECTED;
	switch(fo_xadefbttn)
	{
		case 2:
			alert_tree[ALERTB1].ob_flags &= ~DEFAULT;
			alert_tree[ALERTB2].ob_flags |= DEFAULT;
			alert_tree[ALERTB3].ob_flags &= ~DEFAULT;
			break;
		case 3:
			alert_tree[ALERTB1].ob_flags &= ~DEFAULT;
			alert_tree[ALERTB2].ob_flags &= ~DEFAULT;
			alert_tree[ALERTB3].ob_flags |= DEFAULT;
			break;
		default:
			alert_tree[ALERTB1].ob_flags |= DEFAULT;
			alert_tree[ALERTB2].ob_state &= ~DEFAULT;
			alert_tree[ALERTB3].ob_state &= ~DEFAULT;			
			break;
	}
	if(fo_xastring[0]!='[' || fo_xastring[2]!=']' || fo_xastring[3]!='[')
		return(0);				/* error */
	switch(fo_xastring[1])
	{
	case '1':
		alert_tree[ALERTNOTE].ob_flags &= ~HIDETREE;
		alert_tree[ALERTWAIT].ob_flags |= HIDETREE;
		alert_tree[ALERTSTOP].ob_flags |= HIDETREE;
		flag_img=1;
		break;
	case '2':
		alert_tree[ALERTNOTE].ob_flags |= HIDETREE;
		alert_tree[ALERTWAIT].ob_flags &= ~HIDETREE;
		alert_tree[ALERTSTOP].ob_flags |= HIDETREE;
		flag_img=1;
		break;
	case '3':
		alert_tree[ALERTNOTE].ob_flags |= HIDETREE;
		alert_tree[ALERTWAIT].ob_flags |= HIDETREE;
		alert_tree[ALERTSTOP].ob_flags &= ~HIDETREE;		
		flag_img=1;
		break;			
	default:
		alert_tree[ALERTNOTE].ob_flags |= HIDETREE;
		alert_tree[ALERTWAIT].ob_flags |= HIDETREE;
		alert_tree[ALERTSTOP].ob_flags |= HIDETREE;		
		flag_img=0;
		break;
	}
	for(i=0;i<5;alert_tree[ALERTLINE1+i].ob_spec.free_string=&line[i][0],line[i++][0]=0);
	for(i=0;i<3;alert_tree[ALERTB1+i].ob_spec.free_string=&button[i][0],button[i++][0]=0);
	fo_xastring+=4;
	p=fo_xastring;				/* search the size of the box */
	max_length_buttons=nb_lines=nb_buttons=0;
	t_edinfo=alert_tree[ALERTTITLE].ob_spec.tedinfo;
	max_length_lines=t_edinfo->te_txtlen-1;
	for(i=0;*p!=']' && i<5;i++)
	{ 
		for(j=0;*p!=']' && *p!='|' && j<60;j++)
		{
			if(*p++ == 0)
				return(0);		/* error */
		}
		if(p[0]=='|')
			p++;
		else
		{
			if(j>=60)
				return(0);		/* error */
		}
		if(j>max_length_lines)
			max_length_lines=j;
		nb_lines++;
	}
	if(p[0]!=']' || p[1]!='[')
		return(0);				/* error */
	p+=2;
	for(i=0;*p!=']' && i<3;i++)
	{
		for(j=0;*p!=']' && *p!='|' && j<20;j++)
		{
			if(*p++ == 0)
				return(0);		/* error */
		}
		if(*p=='|')
			p++;
		else
		{
			if(j>=20)
				return(0);		/* error */
		}
		if(j>max_length_buttons)
			max_length_buttons=j;
		nb_buttons++;
	}
	if(p[0]!=']' || p[1]!=0)
		return(0);				/* error */
	if(!max_length_buttons)
		nb_buttons=0;
	else
		max_length_buttons++;
	i=max_length_buttons*nb_buttons;
	if(max_length_lines>i)
		i=max_length_lines;
	i+=3;
	if(flag_img)							/* NOTE, WAIT or STOP */
		i+=5;
	i*=gr_hwchar;							/* width of box */
	alert_tree[ALERTBOX].ob_width=i;
	alert_tree[ALERTTITLE].ob_x=gr_hwchar>>1;
	alert_tree[ALERTTITLE].ob_y=4;
	alert_tree[ALERTTITLE].ob_width=i-gr_hwchar;
	j=max_length_buttons*gr_hwchar;			/* width of button */
	w=(i-(j*nb_buttons))/(nb_buttons+1);	/* width between buttons */
	alert_tree[ALERTB1].ob_x=w;
	alert_tree[ALERTB1].ob_width=alert_tree[ALERTB2].ob_width=alert_tree[ALERTB3].ob_width=j;
	alert_tree[ALERTB2].ob_x=j+(w<<1);
	alert_tree[ALERTB3].ob_x=(j<<1)+(w*3);
	i=nb_lines+1;
	if(flag_img)							/* NOTE, WAIT or STOP */
	{
		j=(alert_tree[ALERTNOTE].ob_height/gr_hhchar)+2;
		if(j>i)
			i=j;
	}
	if(nb_buttons)
		j=(i+4)*gr_hhchar;	
	else
		j=(i+2)*gr_hhchar;
	alert_tree[ALERTBOX].ob_height=j;		/* height of box */
	alert_tree[ALERTB1].ob_y=alert_tree[ALERTB2].ob_y=alert_tree[ALERTB3].ob_y=j-(gr_hhchar<<1);
	for(i=0;i<5;i++)						/* copy texts of lines */
	{
		if(i<nb_lines)
		{
			alert_tree[ALERTLINE1+i].ob_flags &= ~HIDETREE;
			alert_tree[ALERTLINE1+i].ob_x=gr_hwchar<<1;
			if(flag_img)
				alert_tree[ALERTLINE1+i].ob_x+=alert_tree[ALERTNOTE].ob_width;
			alert_tree[ALERTLINE1+i].ob_width=max_length_lines*gr_hwchar;
			for(j=0;*fo_xastring!='|' && *fo_xastring!=']' && j<60;line[i][j++]=*fo_xastring++);
			line[i][j]=0;
			fo_xastring++;
		}
		else
		{
			alert_tree[ALERTLINE1+i].ob_flags |= HIDETREE;
			line[i][0]=0;
		}			
	}
	fo_xastring++;
	for(i=0;i<3;i++)						/* copy texts of buttons */
	{
		if(i<nb_buttons)
		{
			alert_tree[ALERTB1+i].ob_flags &= ~HIDETREE;
			for(j=0;*fo_xastring!='|' && *fo_xastring!=']' && j<20;button[i][j++]=*fo_xastring++);
			button[i][j]=0;
			fo_xastring++;
		}
		else
		{
			alert_tree[ALERTB1+i].ob_flags |= HIDETREE;
			button[i][0]=0;
		}
	}
	MT_wind_update(BEG_UPDATE,global);
	MT_form_center(alert_tree,&rect,global);
	MT_form_dial(FMD_START,&kl_rect,&rect,global);
	MT_objc_draw(alert_tree,0,MAX_DEPTH,&rect,global);
	MT_wind_update(BEG_MCTRL,global);
	answer=0;
	do
	{	event=(MU_KEYBD|MU_BUTTON);
		if(time_out!=0)
			event|=MU_TIMER;	
		event=MT_evnt_multi(event,2,1,1,0,&rect,0,&rect,msg,time_out,&mouse,&key,&nclicks,global);
		if(event & MU_TIMER)
			answer=fo_xadefbttn;
		if(event & MU_BUTTON)
		{
			if((objc_clic=MT_objc_find(alert_tree,0,MAX_DEPTH,mouse.x,mouse.y,global))>=0)
			{
				if(!MT_form_button(alert_tree,objc_clic,nclicks,&new_objc,global))
				{
					switch(objc_clic)		/* buttons */
					{
					case ALERTB1:
						answer=1;
						break;
					case ALERTB2:
						answer=2;
						break;	
					case ALERTB3:
						answer=3;
						break;
					}
				}
				else
				{
					if(time_out)
						answer=fo_xadefbttn;		
				}
			}
		}
		if(event & MU_KEYBD)
		{
			if(!MT_form_keybd(alert_tree,0,0,key,&new_objc,&key,global))
				answer=fo_xadefbttn;				
		}		
	}
	while(!answer);
	if(call)
	{
		function=call;
		(*function)();
	}
	MT_wind_update(END_MCTRL,global);
	MT_form_dial(FMD_FINISH,&kl_rect,&rect,global);
	MT_wind_update(END_UPDATE,global);
	return(answer);
}

void display_erreur(int error)

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

void bubble_help(void)

{
	register int i,j;
	int bubble_id,objc;
    EVNTDATA mouse;
#ifndef BUBBLEGEM_RIGHTCLIC
	static int old_objc=-1;
#endif
	static WORD msg[8];
	if(ap_id>=0 && !flag_bubble && buffer_bubble && time_out_bubble<0)
	{
		if((bubble_id=appl_find("BUBBLE  "))>=0)
		{
			graf_mkstate(&mouse);
			if((wi_id==-1 || wi_id==wind_find(mouse.x,mouse.y)))
			{
#ifdef BUBBLEGEM_RIGHTCLIC
				if((mouse.bstate & 2)!=0						/* right button */
				 && (objc=objc_find(rs_object,0,2,mouse.x,mouse.y))>=0)
				{
#else
				if((objc=objc_find(rs_object,0,2,mouse.x,mouse.y))>=0)
				{
					if(old_objc!=objc)
						old_objc=objc;
					else
#endif
					{
						i=0;
						while(i<NB_BUB && bubbletab[i].object != objc)
							i++;
						if(i<NB_BUB)
						{
							if((objc==MENUTEMP || objc==MENUBARTEMP || objc==MENUTRACE)
							 && selection==PAGE_TEMP)
								i++;
							if(!start_lang)
								strcpy(buffer_bubble,*bubbletab[i].french);
							else
								strcpy(buffer_bubble,*bubbletab[i].english);				
							msg[0]=BUBBLEGEM_SHOW;
							msg[1]=ap_id;
							msg[3]=mouse.x;
							msg[4]=mouse.y;
							*((char **)(&msg[5]))=buffer_bubble;
							msg[2]=msg[7]=0;
							if(appl_write(bubble_id,16,msg))	/* send BUBBLEGEM_SHOW to BUBBLE */
							{
								flag_bubble=1;
								time_out_bubble=0;
							}
						}
					}
				}
			}
		}
	}
	if(time_out_bubble>=0)
	{
		time_out_bubble++;
		if(time_out_bubble>10)
		{
			if(!start_lang)
				form_alert(1,"[1][Pas de r‚ponse de|BubbleGEM !][Annuler]");
			else
				form_alert(1,"[1][No response from|BubbleGEM!][Cancel]");
			time_out_bubble=-1;
		}
	}
}

void call_st_guide(void)

{
	register int st_guide_id;
	static WORD msg[8];
	if(ap_id>=0 && buffer_path
	 && (st_guide_id=appl_find("ST-GUIDE"))>=0)
	{
		strcpy(buffer_path,"*:\\CT60.HYP");
		msg[0]=VA_START;
		msg[1]=ap_id;
		*((char **)(&msg[3]))=buffer_path;
		msg[2]=msg[5]=msg[6]=msg[7]=0;
		appl_write(st_guide_id,16,msg);					/* send VA_START to ST-GUIDE */
	}
}

long cdecl temp_thread(unsigned int *param)				/* used with MagiC > 4.5 */

{
	register int i,temp;
	unsigned long daytime;
	unsigned int time,trigger_temp,daystop,timestop;
	int temp_id,event,ret,count=0,count_mn=0,loops=1,stop;
	unsigned long ticks,start_ticks,new_ticks,sum_ticks=0;
	long uptime,load,old_load=0,load_avg=0,load_avg_mn=0,delay=ITIME,avenrun[3]={0,0,0};
	char buffer[2];
	static unsigned int old_time=9999;
	static int error_flag=0,old_stop=0;
	static WORD message[8],msg[8];
	static char mess_alert[256];
	GRECT rect={0,0,0,0};
	OBJECT *alarm_tree;
	EVNTDATA mouse;
	WORD myglobal[15];
	unsigned short *tab_temp,*tab_cpuload;
	temp_id=MT_appl_init(myglobal);
	tab_temp=(unsigned short *)Mxalloc(sizeof(unsigned short)*122L,0x4023);		/* global memory, don't free */	
	tab_cpuload=(unsigned short *)Mxalloc(sizeof(unsigned short)*61L,0x4023);
	if(!tab_temp || !tab_cpuload)
		return(-1);
	for(i=0;i<61;i++)
		tab_temp[i]=tab_temp[i+61]=tab_cpuload[i]=0;
	start_ticks=clock();
	trigger_temp=param[0];
	daystop=param[1];
	timestop=param[2];
	while(1)
	{
		avenrun[0]=-1L;
		Suptime(&uptime,avenrun);
		/* The load average value is calculated using the following formula:
		   sum += (new_load - old_load) * LOAD_SCALE;
			   load_avg = sum / MAX_SIZE;
		   where LOAD_SCALE is 2048, MAX_SIZE is 12 for 1 mn, 
 		       new_load is the number of currently running processes,
    		   old_load is the number of processes running previous time. */
		daytime=Gettime();
		time=(unsigned int)(daytime & 0xffe0L);					/* mn */
		stop=test_stop(daytime,daystop,timestop);
		if(stop && !old_stop)
		{
			bip();
			if(!start_lang)
				ret=MT_form_xalert(1,"[2][ATTENTION !|Arrˆt programm‚ de votre|ordinateur dans 30 secondes ?][OK|Annuler]",ITIME*30L,0L,myglobal);
			else
				ret=MT_form_xalert(1,"[2][WARNING!|Stop programmed for your|computer in 30 seconds?][OK|Cancel]",ITIME*30L,0L,myglobal);
			if(ret==1)
			{
				for(i=0;i<10;bip(),evnt_timer(ITIME),i++);
				if(!start_lang)
					MT_form_xalert(1,"[1][Arrˆt de votre ordinateur...][]",ITIME*5L,stop_60,myglobal);
				else
					MT_form_xalert(1,"[1][Stopping your computer...][]",ITIME*5L,stop_60,myglobal);
			}
		}
		old_stop=stop;
		temp=read_temp();
		if(temp<0)
		{
			temp=0;
			if(!error_flag)
			{
		 		if(!start_lang)
					MT_form_xalert(1,"[1][Il n'est pas possible de lire|la temp‚rature car le capteur|donne de mauvaises valeurs][OK]",0L,0L,myglobal);
				else
					MT_form_xalert(1,"[1][Cannot determine temperature|because the monitor has|returned bad values][OK]",0L,0L,myglobal);
				error_flag=1;
			}
		}
		if(temp > MAX_TEMP-5)
		{
			bip();
			if(!start_lang)
				sprintf(mess_alert,"[3][ATTENTION !|Votre 060 est trop chaud: %d øC|La destruction est … %d øC|Arrˆt du microprocesseur dans 10 S|aprŠs ce message !][OK]",temp,MAX_TEMP);
			else
				sprintf(mess_alert,"[3][WARNING!|Your 68060 is too hot: %d øC|Destruction begins at %d øC|Your system will be stopped|10 secs after this message!][OK]",temp,MAX_TEMP);
			MT_form_xalert(1,mess_alert,ITIME*5L,0L,myglobal);
			for(i=0;i<10;bip(),evnt_timer(ITIME),i++);
			if(!start_lang)
				sprintf(mess_alert,"[3][ATTENTION !|Votre 060 est trop chaud: %d øC|La destruction est … %d øC| |SystŠme Arrˆt‚ ! ][]",temp,MAX_TEMP);
			else
				sprintf(mess_alert,"[3][WARNING!|Your 68060 is too hot: %d øC|Destruction begins at %d øC| |System halted!][]",temp,MAX_TEMP);
			MT_form_xalert(1,mess_alert,ITIME*2L,stop_60,myglobal);
		}
		if(time!=old_time)
		{
			for(i=0;i<60;i++)
				tab_cpuload[i]=tab_cpuload[i+1];
			if(avenrun[0]>=0 || !flag_cpuload)
			{
				if(flag_cpuload)
				{
					if(avenrun[0]>MAX_CPULOAD)
						avenrun[0]=MAX_CPULOAD;
					tab_cpuload[60]=(unsigned short)avenrun[0];
				}
				else
				{
					tab_cpuload[60]=0;
					load_avg=0;
				}
				delay=ITIME;
				loops=1;
			}
			else
			{
				if(count_mn)
					load=load_avg_mn/(long)count_mn;
				else
					load=load_avg;
				count_mn=load_avg_mn=0;
				if(load<0)
					load=0;
				if(load>MAX_CPULOAD)
					load=MAX_CPULOAD;
				tab_cpuload[60]=(unsigned short)load;
				delay=ITIME/CLOCKS_PER_SEC;
				loops=CLOCKS_PER_SEC;
			}
			for(i=0;i<60;i++)
				tab_temp[i]=tab_temp[i+1];
			tab_temp[60]=temp;
			if(tab_temp[60]>MAX_TEMP)
				tab_temp[60]=MAX_TEMP;
			if(eiffel_temp!=NULL)
			{
				buffer[0]=3;				/* get temp */
				Ikbdws(0,buffer);
				for(i=61;i<121;i++)
					tab_temp[i]=tab_temp[i+1];
				tab_temp[121]=((unsigned short)(eiffel_temp[0]&0x3F))
				 | (((unsigned short)(eiffel_temp[2]&1))<<15);
			}
			old_time=time;
			if(temp > trigger_temp && temp <= MAX_TEMP)
			{
				bip();
			 	if(!start_lang)
					sprintf(mess_alert,"[3][ATTENTION !|Votre 060 est trop chaud: %d øC|La destruction est … %d øC|Arrˆtez votre ordinateur !][OK]",temp,MAX_TEMP);
				else
					sprintf(mess_alert,"[3][WARNING!|Your 68060 is too hot: %d øC|Destruction begins at %d øC|Shut down your computer NOW!][OK]",temp,MAX_TEMP);
				MT_form_xalert(1,mess_alert,ITIME*10L,0L,myglobal);
			}
		}
		if(loops>1)
			ticks=clock();
		for(i=0;i<loops;i++)
		{
			event=MT_evnt_multi(MU_MESAG|MU_TIMER,0,0,0,0,&rect,0,&rect,message,delay,&mouse,&ret,&ret,myglobal);
			if((event & MU_TIMER) && loops>1)
			{
				new_ticks=clock();
				if(new_ticks-ticks > (1000UL/CLOCKS_PER_SEC))
					sum_ticks+=((long)new_ticks-(long)ticks-(long)(1000UL/CLOCKS_PER_SEC));
				ticks=new_ticks;
				count++;
				if(new_ticks-start_ticks >= (2L*CLOCKS_PER_SEC))			/* 2 seconds */	
				{
					start_ticks=new_ticks;
					load=((long)sum_ticks * 4000L) / (long)count;
					load_avg=(load+old_load)>>1;
					load_avg_mn+=load_avg;
					old_load=load;
					sum_ticks=count=0;
					count_mn++;
				}
			}
			if((event & MU_MESAG)
			 && ((unsigned int)message[0]==MSG_CT60_TEMP))
			{
				trigger_temp=(unsigned int)message[3];
				daystop=(unsigned int)message[4];
				timestop=(unsigned int)message[5];
				if(avenrun[0]>=0)
					load=avenrun[0];
				else
					load=load_avg;
				if(load<0)
					load=0;
				if(load>MAX_CPULOAD)
					load=MAX_CPULOAD;
				msg[0]=MSG_CT60_TEMP;
				msg[1]=temp_id;
				*((UWORD **)(&msg[3]))=tab_temp;	
				*((UWORD **)(&msg[5]))=tab_cpuload;
				msg[7]=(WORD)((load*100L)/MAX_CPULOAD);
				msg[2]=0;
				MT_appl_write(message[1],16,msg,myglobal);
			}
		}
	}
}

int start_temp(unsigned int *param1,unsigned int *param2,unsigned int *param3)

{
	register int ret,err,i,j;
	unsigned int param[3];
	THREADINFO thi;
	char path_app[256],path_acc[256];
	char name[9];
	int type,sid;
	if(temp_id>=0)
		return(temp_id);
	temp_id=appl_find("CT60TEMP");
	if(temp_id>=0)
		return(temp_id);
	else
    {
		if(mint || magic)
		{
			if(start_ct60temp(param1,param2,param3))
				return(appl_find("CT60TEMP"));
		}
    }
	if(appl_find("FREEDOM2")<0 && magic >=0x405
	 && magic_date >= 0x19960401L && temp_id<0)
	{						/* threads exists since MagiC 4.5 */ 
		param[0]=*param1;
		param[1]=*param2;
		param[2]=*param3;
		thi.proc=(void *)temp_thread;
		thi.user_stack=NULL;
		thi.stacksize=4096L;
		thi.mode=0;
		thi.res1=0L;
		temp_id=shel_write(SHW_THR_CREATE,1,0,(char *)&thi,(void *)param);
		if(temp_id>=0)
			thread=1;
		return(temp_id);
	}
	else
	{
		strcpy(path_app,"*.ACC");
		if(!shel_find(path_app))
			strcpy(path_app,"C:\\");
		if((mint  || magic) && ap_id>=0)
		{	/* try to find the ACC path */
			if(appl_search(0,name,&type,&sid))
			{
				do
				{
					if(sid==ap_id)
					{
						strcpy(path_acc,name);
						for(i=0;path_acc[i]!=' ' && i<8;i++);
						path_acc[i]=0;
						strcat(path_acc,".ACC");
						if(shel_find(path_acc))
							strcpy(path_app,path_acc);
						break;
					}
				}
				while(appl_search(1,name,&type,&sid));
			}
		}
		for(i=j=0;path_app[i] && i<250;i++)
		{
			if(path_app[i]=='\\')
				j=i+1;
		}
		path_app[j]=0;
		if(mint || magic)
			strcat(path_app,"CT60TEMP.APP");		
		else
			strcat(path_app,"CT60TEMP.ACC");
#ifdef ALERT_INSTALL_CT60TEMP
		if(!start_lang)
			ret=form_alert(1,"[2][Il faut installer CT60TEMP|pour surveiller la temp‚rature][Installer|Annuler]");
		else
			ret=form_alert(1,"[2][You must install CT60TEMP|to monitor the temperature][Install|Cancel]");
		if(ret==1)
#endif
		{
			graf_mouse(HOURGLASS,(MFORM*)0);
			ret=Fcreate(path_app,0);
			if(ret<0)
			{
				graf_mouse(ARROW,(MFORM*)0);
				if(!start_lang)
					ret=form_alert(1,"[1][Erreur durant la cr‚ation|du fichier CT60TEMP.ACC][Annuler]");
				else
					ret=form_alert(1,"[1][Error occurred while|creating CT60TEMP.ACC][Cancel]");	
			}		
			else
			{
				err=Fwrite(ret,LENCT60TEMP,CT60TEMP);
				Fclose(ret);
				graf_mouse(ARROW,(MFORM*)0);
				if(err<0)
				{
					if(!start_lang)
						ret=form_alert(1,"[1][Erreur durant l'‚criture|du fichier CT60TEMP.ACC][Annuler]");
					else
						ret=form_alert(1,"[1][Error occurred while|writing CT60TEMP.ACC][Cancel]");	
				}
				else
				{
					if(mint || magic)
					{
						if(start_ct60temp(param1,param2,param3))
							return(appl_find("CT60TEMP"));
					}
					else
					{
						if(!start_lang)
							ret=form_alert(1,"[2][Vous devez red‚marrer|votre ordinateur pour que la|surveillance de temp‚rature|fonctionne][Reboot|Annuler]");
						else
							ret=form_alert(1,"[2][You must reboot your|computer in order to start|the temperature monitor][Reboot|Cancel]");	
						if(ret==1)
							reboot();
					}
				}
			}
		}
	}
	return(-1);
}

int start_ct60temp(unsigned int *param1,unsigned int *param2,unsigned int *param3)

{
	register int ret=0;
	char path_app[256],cmd_line[256];
	strcpy(path_app,"CT60TEMP.APP");
	if(shel_find(path_app))
	{
		sprintf(&cmd_line[1],"%d %d %d",*param1,*param2,*param3);
		ret=strlen(&cmd_line[1]);
		cmd_line[0]=(char)ret;
		if(magic)
			ret=shel_write(1,1,SHW_PARALLEL,path_app,cmd_line);
		else
			ret=shel_write(0,1,SHW_CHAIN,path_app,cmd_line);
#ifdef DEBUG
		printf("\r\nCT60TEMP.APP started");
#endif
		evnt_timer(100L);
	}
	return(ret);
}

int send_ask_temp(void)

{	
	register int ret;
	static WORD msg[8];
	if(time_out_thread>=0)
		return(0);		/* no answer from the latest message */ 
	if(!thread)
		temp_id=appl_find("CT60TEMP");
	if(temp_id<0)
		return(0);		/* error */
	msg[0]=MSG_CT60_TEMP;
	msg[1]=ap_id;
	msg[3]=(int)trigger_temp;
	msg[4]=(int)daystop;
	msg[5]=(int)timestop;
	msg[2]=msg[6]=msg[7]=0;
	if((ret=appl_write(temp_id,16,msg))!=0)
		time_out_thread=0;
	return(ret);
}

int test_stop(unsigned long daytime,unsigned int daystop,unsigned int timestop)

{
	unsigned int day;
	int year,mon,mday;
	if(((unsigned int)(daytime & 0xffe0L))==timestop)	/* mn */
	{	
		year=(int)((daytime>>25)+1980UL);				/* year */
		mon=(int)((daytime>>21) & 0xf);					/* month */
		mday=(int)((daytime>>16) & 0x1f);				/* day of month */
		day=dayofweek(year,mon,mday)+1;					/* day of week */
		switch(daystop)
		{
		case MONDAY_STOP:
		case TUESDAY_STOP:
		case WEDNESDAY_STOP:
		case THURSDAY_STOP:
		case FRIDAY_STOP:
		case SATURDAY_STOP:
		case SUNDAY_STOP:
			if(day==daystop)
				return(1);								/* stop */
			break;
		case WORKDAY_STOP:
			if(day!=SATURDAY_STOP && day!=SUNDAY_STOP)
				return(1);								/* stop */
			break;
		case WEEKEND_STOP:
			if(day==SATURDAY_STOP || day==SUNDAY_STOP)
				return(1);								/* stop */
			break;
		case EVERYDAY_STOP:
			return(1);									/* stop */
		case NO_STOP:
		default:
			break;
		}
	}
	return(0);											/* continue */
}

int dayofweek(int year,int mon,int mday)

{
	static int doylookup[2][13] = {
	 { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365 },
	 { 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366 }};
	int doe,isleapyear;
	int era,cent,quad,rest;
	/* break down the year into 400, 100, 4, and 1 year multiples */
	rest = year-1;
	quad = rest/4;
	rest %= 4;
	cent = quad/25;
	quad %= 25;
	era = cent/4;
	cent %= 4;
	/* leap year every 4th year, except every 100th year,
	   not including every 400th year. */
	isleapyear = !(year % 4) && ((year % 100) || !(year % 400));
	/* set up doe */
	doe = mday + doylookup[isleapyear][mon - 1];
	doe += era * (400 * 365 + 97);
	doe += cent * (100 * 365 + 24);
	doe += quad * (4 * 365 + 1);
	doe += rest * 365;
	return(doe %7);
}

void bip(void)

{
	static unsigned char tab_bip[] = {
	0,0xA0,1,0,2,0,3,0,4,0,5,0,6,0,7,0xFE,8,13,9,0,10,0,0xFF,10,
	0,0,1,0,2,0,3,0,4,0,5,0,6,0,7,0xFF,8,0,9,0,10,0,0xFF,0 };
	Dosound(tab_bip);
}

void stop_60(void)

{
	long value;
	if(((*Xcpb->get_cookie)('_CPU',&value)) && (value==60L))
		Supexec(ct60_stop);		
	while(1);
}

int read_temp(void)

{
	register int temp,temperature,i;
	static int old_temp[8]={0,0,0,0,0,0,0,0};
	if(flag_xbios)
		temp=(int)ct60_read_core_temperature(CT60_CELCIUS);
	else
		temp=(int)Supexec(ct60_read_temp);
	if(temp>=0)
	{
		if(old_temp[0]==0)
			for(i=0;i<8;old_temp[i++]=temp);
		temperature=0;		/* filter on the last 8 values */
		for(i=0;i<7;old_temp[i]=old_temp[i+1],temperature+=old_temp[i],i++);	
		old_temp[7]=temp;
		temperature+=temp;
		temperature>>=3;
		return(temperature);
	}
	return(temp);
}

int fill_tab_temp(void)

{
	register int i,temp;
	register unsigned int time;
	char buffer[2];
	static unsigned int old_time=9999;
	time=(unsigned int)(Gettime() & 0xffe0L);		/* mn */
	if(time!=old_time)
	{
		for(i=0;i<60;i++)
			tab_temp[i]=tab_temp[i+1];
		temp=read_temp();
		if(temp<0)
			temp=0;
		if(temp>MAX_TEMP)
			temp=MAX_TEMP;
		tab_temp[60]=temp;
		old_time=time;
		if(eiffel_temp!=NULL)
		{
			buffer[0]=3;							/* get temp */
			Ikbdws(0,buffer);
			for(i=0;i<60;i++)
				tab_temp_eiffel[i]=tab_temp_eiffel[i+1];
			tab_temp[60]=((unsigned short)(eiffel_temp[0]&0x3F))
			 | (((unsigned short)(eiffel_temp[2]&1))<<15);
		}
		return(1);
	}
	return(0);
}

unsigned long bogomips(void)

{
	long value;
	unsigned long loops_per_sec=1;
	unsigned long ticks;
	while((loops_per_sec<<=1))
	{
		if(!(*Xcpb->get_cookie)('MgMc',&value))
   		{	/* normal case ST, TT, FALCON, HADES, MILAN, CT60 */
   			value_supexec=loops_per_sec;
			ticks=(unsigned long)Supexec(mes_delay);
		}
		else
		{	/* _hz_200 seems not works in supervisor state under MagiCMac */
			ticks=clock();
			delay_loop(loops_per_sec);
			ticks=clock()-ticks;
		}
		if(ticks>=CLOCKS_PER_SEC)
		{
			loops_per_sec=(loops_per_sec/ticks) * CLOCKS_PER_SEC;
			break;
		}
	}
	return(loops_per_sec);
}

void delay_loop(long loops)

{
	while((--loops)>=0);
}

int get_MagiC_ver(unsigned long *crdate)

{
	long value;
	AESVARS *av;
	if(!(*Xcpb->get_cookie)('MagX',&value))
		return(0);
	av=((MAGX_COOKIE *)value)->aesvars;
	if(!av)
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

int test_060(void)
{
#ifndef TEST
	static long value=0;
	if(value==0)
		(*Xcpb->get_cookie)('_CPU',&value);
	return(value==0x3C ? 1 : 0);
#else
	return(1);
#endif
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
