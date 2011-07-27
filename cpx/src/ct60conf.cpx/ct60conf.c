/* CT60 CONFiguration - Pure C */
/* Didier MEQUIGNON - June 2011 */

#define VERSION "2.01"

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
#include "pcixbios.h"
#include "ct60ctcm.h"
#include "radeon.h"

#define Vsetscreen(log,phy,rez,mode) (void)xbios((short)0x05,(long)(log),(long)(phy),(short)(rez),(short)(mode))

/* #define ALERT_INSTALL_CT60TEMP */
#undef DEBUG
/* #define TEST */

#define ID_CF (long)'_CF_'

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
#define PAGE_TEMP    1
#define PAGE_MEMORY  2
#define PAGE_BOOT    3
#define PAGE_STOP    4
#define PAGE_LANG    5
#define PAGE_VIDEO   6

#define NO_STOP        0
#define MONDAY_STOP    1
#define TUESDAY_STOP   2
#define WEDNESDAY_STOP 3
#define THURSDAY_STOP  4
#define FRIDAY_STOP    5
#define SATURDAY_STOP  6
#define SUNDAY_STOP    7
#define WORKDAY_STOP   8
#define WEEKEND_STOP   9
#define EVERYDAY_STOP  10

#define Suptime(uptime,avenrun) gemdos(0x13f,(long)(uptime),(long)(avenrun))
#define Sync() gemdos(0x150)
#define Shutdown(mode) gemdos(0x151,(long)(mode))

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
	unsigned char cpufpu;
	unsigned long frequency;
	unsigned char beep;
	unsigned char bootlog;
	unsigned char idectpci;
	unsigned char div_frequency;
	unsigned char serialspeed;
	unsigned int timeblank;
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
void init_slider(void);
void display_slider(GRECT *work);
int modif_inf(int modecode);
int read_hexa(char *p);
int ascii_hexa(char *p);
void write_hexa(int val,char *p);
void hexa_ascii(int val,char *p);
void infos_sdram(void);
void add_latency(char *buffer_ascii,unsigned char val);
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
void display_error(int err);
void bubble_help(void);
void call_st_guide(void);
long cdecl temp_thread(unsigned int *param);
int start_temp(unsigned int *param1,unsigned int *param2,unsigned int *param3,unsigned int *param4,unsigned int *param5);
int start_ct60temp(unsigned int *param1,unsigned int *param2,unsigned int *param3,unsigned int *param4,unsigned int *param5);
int send_ask_temp(void);
int test_stop(unsigned long daytime,unsigned int daystop,unsigned int timestop); 
int dayofweek(int year,int mon,int mday);
void SendIkbd(int count, char *buffer);
void beep_psg(unsigned int beep);
void stop_060(void);
long version_060(void);
int read_temp(void);
int fill_tab_temp(void);
unsigned long bogomips(void);
void delay_loop(long loops);
int get_MagiC_ver(unsigned long *crdate);
COOKIE *fcookie(void);
COOKIE *ncookie(COOKIE *p);
COOKIE *get_cookie(long id);
int add_cookie(COOKIE *cook);
long cdecl enumfunc(SCREENINFO *inf, long flag);
int find_radeon(void);
int test_060(void);
CT60_COOKIE *get_cookie_ct60(void);
int copy_string(char *p1,char *p2);
int long_deci(char *p,int *lg);
int val_string(char *p);
void reboot(void);
void (*reset)(void);
extern long ct60_read_clock(void);
extern int ct60_configure_clock(unsigned long frequency,int mode,int divider);
extern void tempo_20ms(void);
extern long ct60_read_temp(void);
extern long ct60_stop(void);
extern long cf_stop(void);
extern long ct60_cpu_revision(void);
extern long mes_delay(void);
extern int ct60_read_info_sdram(unsigned char *buffer);
extern int ct60_read_info_clock(unsigned char *buffer);
extern long get_version_flash(void);
extern long ct60_rw_param(int mode,long type_param,long value);
extern long ct60_rw_clock(int mode,int address,int data);
extern int read_i2c(long device_address);

/* global variables in the 1st position of DATA segment */

HEAD config={0,2,2,0x11,'/',1,0x1b2,0x87,0,50,0,0,1,0,1,1,MIN_FREQ,1,1,2,2,0,0};

#include "ct60temp.h"

/* global variables */

int vdi_handle,work_in[11]={1,1,1,1,1,1,1,1,1,1,2},work_out[57];
int errno;
WORD global[15];
int gr_hwchar,gr_hhchar;
int	ap_id=-1,temp_id=-1,wi_id=-1;
int mint,magic,radeon,acp,coldfire,flag_frequency,flag_cpuload,flag_xbios,thread=0,time_out_thread=-1,time_out_bubble=-1,bubblegem_right_click=1,div_frequency=2;
unsigned long magic_date,st_ram,fast_ram,loops_per_sec=0,frequency=MIN_FREQ,min_freq=MIN_FREQ,max_freq=MAX_FREQ_REV6,mac_address=0,ip_address=0,server_ip_address=0;
extern unsigned long step_frequency;
long cpu_cookie=0;
char *eiffel_temp=NULL;
short *eiffel_media_keys=NULL;
extern unsigned long value_supexec;
XCPB *Xcpb;
GRECT *Work;
CPXNODE *head;
CPXINFO	cpxinfo={cpx_call,cpx_draw,cpx_wmove,cpx_timer,cpx_key,cpx_button,0,0,cpx_hook,cpx_close};
NVM nvram;
USERBLK spec_trace={0,0};
USERBLK spec_cpuload={0,0};
int ed_objc,new_objc,ed_pos,new_pos;
int start_lang,flag_bubble,selection,no_jumper;
int language,keyboard,datetime,vmode,vmode_prefered,width_max_mono,height_max_mono,width_prefered,height_prefered,bootpref,bootdelay,scsi,cpufpu;
int tosram,blitterspeed,serialspeed,cachedelay,bootorder,bootlog,idectpci,nv_magic_code;
unsigned int trigger_temp,daystop,timestop,beep,timeblank;
char *buffer_bubble=NULL;
char *buffer_path=NULL;
unsigned short tab_temp[61],tab_temp_eiffel[61],tab_cpuload[61];

/* ressource */

#define MENUBOX 0
#define MENUTITLE 1
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
#define MENUBFPU 30
#define MENUBLEFT 31
#define MENUBOXSLIDER 32
#define MENUSLIDER 33
#define MENUBRIGHT 34
#define MENUBDIV 35
#define MENURAM 36
#define MENUBOXLANG 37
#define MENUBLANG 39
#define MENUBKEY 41
#define MENUBDATE 43
#define MENUBTIME 45
#define MENUSEP 46
#define MENULANG 47
#define MENUBOXVIDEO 48
#define MENUBVIDEO 50
#define MENUBMODE 52
#define MENUBRES 54
#define MENUBCOUL 56
#define MENUBMLAYOUT 57
#define MENUSTMODES 58
#define MENUOVERSCAN 59
#define MENUNVM 60
#define MENUVIDEO 61
#define MENUBOXBOOT 62
#define MENUBBOOTORDER 63
#define MENUBOS 65
#define MENUBARBIT 67
#define MENUBIDSCSI 69
#define MENUDELAY 70
#define MENUBBLITTER 72
#define MENUBTOSRAM 74
#define MENUBCACHE 76
#define MENUBBOOTLOG 78
#define MENUBIDECTPCI 80
#define MENUBOOT 81
#define MENUBOXSTOP 82
#define MENUBDAY 84
#define MENUTIME 85
#define MENUBBEEP 87
#define MENUBLANK 88
#define MENUMAC 89
#define MENUIP 90
#define MENUSERVERIP 91
#define MENUSTOP 92

#define MENUBSAVE 93
#define MENUBLOAD 94
#define MENUBOK 95
#define MENUBCANCEL 96
#define MENUBINFO 97

#define INFOBOX 0
#define INFOLOGO 1
#define INFOOK 13
#define INFOSDRAM 14
#define INFOHELP 15

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
#define ALERTLINE6 10
#define ALERTLINE7 11
#define ALERTLINE8 12
#define ALERTLINE9 13
#define ALERTLINE10 14
#define ALERTLINE11 15
#define ALERTLINE12 16
#define ALERTLINE13 17
#define ALERTLINE14 18
#define ALERTLINE15 19
#define ALERTLINE16 20
#define ALERTLINE17 21
#define ALERTLINE18 22
#define ALERTLINE19 23
#define ALERTLINE20 24
#define ALERTLINE21 25
#define ALERTLINE22 26
#define ALERTLINE23 27
#define ALERTLINE24 28
#define ALERTLINE25 29
#define ALERTB1 30
#define ALERTB2 31
#define ALERTB3 32

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
	"yy","Seuil: __","99",
	"00:00 00:10 00:20 00:30 00:40 00:50 01:xx","","",
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
	"FPU:",
	"Non","","",
	"123.456","","",
	"/2","","",
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
	"R‚solution:",
	"320x200","","",
	"Couleurs:",
	"xxxxx","","",
	"M.Layout","","",
	"Mode ST",
	"Overscan",
	"Remplace NVM",
	" Boot ","","",
	"IDE->SCSI","","",
	"OS:",
	"TOS","","",
	"SCSI arbitration:",
	"Oui","","",
	"ID:",
	"x","","",
	"zz","D‚lais: __ S","99",
	"Blitter:",
	"Lent","","",
	"TOS en RAM:",
	"Non","","",
	"TOS:",
	"Normal","","",
	"boot.log:",
	"Sans","","",
	"IDE:",
	"FALCON","","",
	" Arrˆt/Divers ","","",
	"Arrˆt programm‚:",
	"Sans","","",
	"xxxx","…: __:__","9999",
	"Bip alarme:",
	"Oui","","",
	"ww","D‚lais veille moniteur: __ mn","99",
	"mmmmmm","Adresse MAC: 00:CF:54:__:__:__","NNNNNN",
	"iiiiiiiiiiii","Adresse IP: ___.___.___.___","999999999999",
	"hhhhhhhhhhhh","Serveur IP: ___.___.___.___","999999999999",
	
	"Sauve",
	"Charge",
	"OK",
	"Annule",
	
	"CT60 Configuration V" VERSION " Juin 2011","","",
	"","","",
	"Ce CPX et systŠme:","","",
	"Didier MEQUIGNON","","",
	"aniplay@wanadoo.fr","","",
	"","","",
	"Hardware:","","",
	"Rodolphe CZUBA","","",
	"rczuba@free.fr","","",
	"","","",
	"http://www.powerphenix.com","","",
	"OK",
	"SDRAM",
	"Aide",
	
	"CT60 Temp‚rature","","",
	"line1x",
	"line2x",
	"line3x",
	"line4x",
	"line5x",
	"line6x",
	"line7x",
	"line8x",
	"line9x",	
	"line10x",
	"line11x",
	"line12x",
	"line13x",
	"line14x",
	"line15x",
	"line16x",
	"line17x",
	"line18x",
	"line19x",
	"line20x",
	"line21x",
	"line22x",
	"line23x",
	"line24x",
	"line25x",
	"button1x",
	"button2x",
	"button3x",
	
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
	"yy","Thres: __","99",
	"00:00 00:10 00:20 00:30 00:40 00:50 01:xx","","",
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
	"FPU:",
	"No","","",
	"012.345","","",
	"/3","","",
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
	"Resolution:",
	"320x200","","",
	"Colors:",
	"xxxxx","","",
	"M.Layout","","",
	"Mode ST",
	"Overscan",
	"Replace NVRAM",
	" Boot ","","",
	"IDE->SCSI","","",
	"OS:",
	"TOS","","",
	"SCSI arbitration:",
	"Yes","","",
	"ID:",
	"x","","",
	"zz","Delay: __ S","99",
	"Blitter:",
	"Slow","","",
	"TOS in RAM:",
	"No","","",
	"TOS:",
	"Normal","","",
	"boot.log:",
	"Without","","",
	"IDE:",
	"FALCON","","",
	" Stop/Misc ","","",
	"Stop programmed:",
	"Without","","",
	"xxxx","at: __:__","9999",
	"Beep alarm:",
	"Yes","","",
	"ww","Monitor blank delay: __ mn","99",
	"mmmmmm","MAC address: 00:CF:54:__:__:__","NNNNNN",
	"iiiiiiiiiiii","IP address: ___.___.___.___","999999999999",
	"hhhhhhhhhhhh","Server IP: ___.___.___.___","999999999999",
	
	"Save",
	"Load",
	"OK",
	"Cancel",

	"CT60 Configuration V" VERSION " June 2011","","",
	"","","",
	"This CPX and system:","","",
	"Didier MEQUIGNON","","",
	"aniplay@wanadoo.fr","","",
	"","","",
	"Hardware:","","",
	"Rodolphe CZUBA","","",
	"rczuba@free.fr","","",
	"","","",
	"http://www.powerphenix.com","","",
	"OK",
	"SDRAM",
	"Help",
	
	"CT60 Temperature","","",
	"line1x",
	"line2x",
	"line3x",
	"line4x",
	"line5x",
	"line6x",
	"line7x",
	"line8x",
	"line9x",	
	"line10x",
	"line11x",
	"line12x",
	"line13x",
	"line14x",
	"line15x",
	"line16x",
	"line17x",
	"line18x",
	"line19x",
	"line20x",
	"line21x",
	"line22x",
	"line23x",
	"line24x",
	"line25x",
	"button1x",
	"button2x",
	"button3x",
	
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
	(char *)48L,(char *)49L,(char *)50L,IBM,0,2,0x1180,0,-1,4,1,
	(char *)51L,(char *)52L,(char *)53L,SMALL,0,2,0x1180,0,-1,8,1,
	(char *)54L,(char *)55L,(char *)56L,IBM,0,2,0x1180,0,-1,3,1,
	(char *)57L,(char *)58L,(char *)59L,IBM,0,2,0x1180,0,0,9,1,
	(char *)61L,(char *)62L,(char *)63L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)65L,(char *)66L,(char *)67L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)69L,(char *)70L,(char *)71L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)73L,(char *)74L,(char *)75L,IBM,0,2,0x1180,0,-1,4,1,	
	(char *)76L,(char *)77L,(char *)78L,IBM,0,0,0x1180,0,0,2,14,
	(char *)79L,(char *)80L,(char *)81L,IBM,0,2,0x1180,0,0,9,1,
	(char *)83L,(char *)84L,(char *)85L,IBM,0,2,0x1180,0,-1,8,1,
	(char *)87L,(char *)88L,(char *)89L,IBM,0,2,0x1180,0,-1,8,1,
	(char *)91L,(char *)92L,(char *)93L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)95L,(char *)96L,(char *)97L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)98L,(char *)99L,(char *)100L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)104L,(char *)105L,(char *)106L,IBM,0,2,0x1180,0,0,6,1,
	(char *)107L,(char *)108L,(char *)109L,IBM,0,2,0x1180,0,-1,10,1,
	(char *)111L,(char *)112L,(char *)113L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)115L,(char *)116L,(char *)117L,IBM,0,2,0x1180,0,-1,5,1,
	(char *)119L,(char *)120L,(char *)121L,IBM,0,2,0x1180,0,-1,3,1,		
	(char *)122L,(char *)123L,(char *)124L,IBM,0,0,0x1180,0,0,3,13,
	(char *)126L,(char *)127L,(char *)128L,IBM,0,2,0x1180,0,-1,7,1,
	(char *)130L,(char *)131L,(char *)132L,IBM,0,2,0x1180,0,-1,4,1,
	(char *)134L,(char *)135L,(char *)136L,IBM,0,2,0x1180,0,-1,8,1,
	(char *)138L,(char *)139L,(char *)140L,IBM,0,2,0x1180,0,-1,7,1,
	(char *)142L,(char *)143L,(char *)144L,IBM,0,2,0x1180,0,-1,7,1,
	(char *)145L,(char *)146L,(char *)147L,IBM,0,2,0x1180,0,0,14,1,
	(char *)149L,(char *)150L,(char *)151L,IBM,0,2,0x1180,0,-1,16,1,
	(char *)152L,(char *)153L,(char *)154L,IBM,0,0,0x1180,0,0,5,10,
	(char *)156L,(char *)157L,(char *)158L,IBM,0,2,0x1180,0,-1,5,1,
	
	(char *)159L,(char *)160L,(char *)161L,IBM,0,0,0x1180,0,0,3,31,	
	
	(char *)162L,(char *)163L,(char *)164L,IBM,0,0,0x1180,0,0,7,31,
	(char *)165L,(char *)166L,(char *)167L,IBM,0,0,0x1180,0,0,13,31,
	(char *)168L,(char *)169L,(char *)170L,IBM,0,0,0x1180,0,0,13,31,

	(char *)175L,(char *)176L,(char *)177L,IBM,0,2,0x1480,0,0,38,1,
	(char *)178L,(char *)179L,(char *)180L,IBM,0,2,0x1180,0,0,38,1,
	(char *)181L,(char *)182L,(char *)183L,IBM,0,2,0x1180,0,0,38,1,
	(char *)184L,(char *)185L,(char *)186L,IBM,0,2,0x1180,0,0,38,1,
	(char *)187L,(char *)188L,(char *)189L,IBM,0,2,0x1180,0,0,38,1,
	(char *)190L,(char *)191L,(char *)192L,IBM,0,2,0x1180,0,0,38,1,
	(char *)193L,(char *)194L,(char *)195L,IBM,0,2,0x1180,0,0,38,1,
	(char *)196L,(char *)197L,(char *)198L,IBM,0,2,0x1180,0,0,38,1,
	(char *)199L,(char *)200L,(char *)201L,IBM,0,2,0x1180,0,0,38,1,
	(char *)202L,(char *)203L,(char *)204L,IBM,0,2,0x1180,0,0,38,1,
	(char *)205L,(char *)206L,(char *)207L,IBM,0,2,0x1180,0,0,38,1,

	(char *)211L,(char *)212L,(char *)213L,IBM,0,2,0x1480,0,-1,17,1,
	
	(char *)242L,(char *)243L,(char *)244L,IBM,0,0,0x1180,0,0,4,32 };
	
OBJECT rs_object[] = {
	-1,1,97,G_BOX,FL3DBAK,NORMAL,0x1100L,0,0,32,11,
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
	36,20,35,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* memory box */
	21,-1,-1,G_STRING,NONE,NORMAL,32L,1,1,15,1,
	22,-1,-1,G_STRING,NONE,NORMAL,33L,16,1,16,1,									/* total ST-Ram */
	23,-1,-1,G_STRING,NONE,NORMAL,34L,1,2,15,1,
	24,-1,-1,G_STRING,NONE,NORMAL,35L,16,2,16,1,									/* total Fast-Ram */	
	25,-1,-1,G_STRING,NONE,NORMAL,36L,1,3,15,1,
	26,-1,-1,G_TEXT,FL3DBAK,NORMAL,10L,16,3,16,1,									/* free ST-Ram */
	27,-1,-1,G_STRING,NONE,NORMAL,40L,1,4,15,1,
	28,-1,-1,G_TEXT,FL3DBAK,NORMAL,11L,16,4,16,1,									/* free Fast-Ram */
	29,-1,-1,G_TEXT,/* TOUCHEXIT| */ FL3DBAK,NORMAL,12L,1,5,30,1,					/* Mips & tr/mn */
	30,-1,-1,G_STRING,NONE,NORMAL,47L,1,6,4,1,
	31,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,13L,6,6,4,1,								/* popup PFU */
	32,-1,-1,G_BOXCHAR,TOUCHEXIT,NORMAL,0x4ff1100L,12,6,2,1,						/*  */
	34,33,33,G_BOX,TOUCHEXIT,NORMAL,0xff1111L,14,6,11,1,
	32,-1,-1,G_BOXTEXT,TOUCHEXIT,NORMAL,14L,0,0,5,1,
	35,-1,-1,G_BOXCHAR,TOUCHEXIT,NORMAL,0x3ff1100L,25,6,2,1,						/*  */
	19,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,15L,28,6,3,1,								/* popup secondary clock divider */	
	37,-1,-1,G_TEXT,FL3DBAK,NORMAL,9L,1,2,14,1,
	47,38,46,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* language box */
	39,-1,-1,G_STRING,NONE,NORMAL,60L,1,1,15,1,
	40,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,17L,16,1,15,1,							/* popup language */
	41,-1,-1,G_STRING,NONE,NORMAL,64L,1,2,15,1,
	42,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,18L,16,2,15,1,							/* popup keyboard */
	43,-1,-1,G_STRING,NONE,NORMAL,68L,1,3,15,1,
	44,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,19L,16,3,15,1,							/* popup date format */
	45,-1,-1,G_STRING,NONE,NORMAL,72L,1,5,7,1,
	46,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,20L,8,5,3,1,								/* popup time format */
	37,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,21L,16,5,14,1,
	48,-1,-1,G_TEXT,FL3DBAK,NORMAL,16L,1,2,10,1,
	61,49,60,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* video box */
	50,-1,-1,G_STRING,NONE,NORMAL,82L,1,1,7,1,
	51,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,23L,8,1,7,1,								/* popup video TV/VGA */
	52,-1,-1,G_STRING,NONE,NORMAL,86L,16,1,7,1,
	53,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,24L,24,1,7,1,								/* popup mode NTSC/PAL */
	54,-1,-1,G_STRING,NONE,NORMAL,90L,1,2,15,1,
	55,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,26L,16,2,15,1,							/* popup resolution */
	56,-1,-1,G_STRING,NONE,NORMAL,94L,1,3,9,1,
	57,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,25L,10,3,5,1,                             /* popup colors */
	58,-1,-1,G_BOXTEXT,HIDETREE,SHADOWED,27L,16,3,15,1,                             /* popup monitor layout */
	59,-1,-1,G_BUTTON,SELECTABLE|TOUCHEXIT|FL3DIND,NORMAL,101L,16,3,15,1,			/* mode ST */
	60,-1,-1,G_BUTTON,SELECTABLE|TOUCHEXIT|FL3DIND,NORMAL,102L,16,5,15,1,			/* overscan */
	48,-1,-1,G_BUTTON,SELECTABLE|TOUCHEXIT|FL3DIND,NORMAL,103L,1,5,14,1,			/* replace NVRAM */
	62,-1,-1,G_TEXT,FL3DBAK,NORMAL,22L,1,2,14,1,
	81,63,80,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* boot box */
	64,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,29L,1,1,17,1,								/* popup boot order */
	65,-1,-1,G_STRING,NONE,NORMAL,110L,20,1,3,1,
	66,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,30L,24,1,7,1,								/* popup favourite OS */
	67,-1,-1,G_STRING,NONE,NORMAL,114L,1,2,17,1,
	68,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,31L,18,2,4,1,								/* popup arbitration */
	69,-1,-1,G_STRING,NONE,NORMAL,118L,24,2,3,1,
	70,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,32L,28,2,2,1,								/* popup ID SCSI */
	71,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,33L,1,3,13,1,							/* boot delay */
	72,-1,-1,G_STRING,NONE,NORMAL,125L,15,3,8,1,
	73,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,34L,24,3,6,1,								/* popup speed blitter */
	74,-1,-1,G_STRING,NONE,NORMAL,129L,1,4,11,1,
	75,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,35L,12,4,4,1,								/* popup transfer TOS in RAM */
	76,-1,-1,G_STRING,NONE,NORMAL,133L,18,4,4,1,
	77,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,36L,23,4,7,1,								/* popup TOS cache delay */
	78,-1,-1,G_STRING,NONE,NORMAL,137L,1,5,9,1,
	79,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,37L,10,5,7,1,								/* popup boot.log */
	80,-1,-1,G_STRING,NONE,NORMAL,141L,19,5,5,1,
	62,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,38L,23,5,7,1,								/* popup IDE CTPCI */
	82,-1,-1,G_TEXT,FL3DBAK,NORMAL,28L,1,2,6,1,
	92,83,91,G_BOX,FL3DIND,NORMAL,0xff1100L,0,2,32,6,								/* stop box */
	84,-1,-1,G_STRING,NONE,NORMAL,148L,1,1,15,1,
	85,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,40L,16,1,15,1,							/* popup stop */
	86,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,41L,1,2,9,1,							/* time */
	87,-1,-1,G_STRING,NONE,NORMAL,155L,11,2,15,1,
	88,-1,-1,G_BOXTEXT,TOUCHEXIT,SHADOWED,42L,27,2,4,1,								/* popup beep */

	89,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,43L,1,3,30,1,							/* monitor blank delay */

	90,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,44L,1,3,30,1,							/* MAC address */
	91,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,45L,1,4,30,1,							/* IP address */
	82,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,46L,1,5,30,1,							/* server IP */
	93,-1,-1,G_TEXT,FL3DBAK,NORMAL,39L,1,2,14,1,

	94,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,171L,1,9,5,1,			/* Save */
	95,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,172L,8,9,6,1,			/* Load */
	96,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,173L,16,9,3,1,			/* OK */
	97,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|FL3DIND|FL3DBAK,NORMAL,174L,21,9,6,1,	/* Cancel */
	0,-1,-1,G_BOXCHAR,SELECTABLE|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,0x69ff1100L,29,9,2,1,	/* i */

	/* info box */
	-1,1,15,G_BOX,FL3DBAK,OUTLINED,0x21100L,0,0,40,21,
	2,-1,-1,G_IMAGE,NONE,NORMAL,0L,2,1,36,5,
	3,-1,-1,G_TEXT,FL3DBAK,NORMAL,47L,1,7,38,1,
	4,-1,-1,G_TEXT,FL3DBAK,NORMAL,48L,1,8,38,1,
	5,-1,-1,G_TEXT,FL3DBAK,NORMAL,49L,1,9,38,1,
	6,-1,-1,G_TEXT,FL3DBAK,NORMAL,50L,1,10,38,1,
	7,-1,-1,G_TEXT,FL3DBAK,NORMAL,51L,1,11,38,1,
	8,-1,-1,G_TEXT,FL3DBAK,NORMAL,52L,1,12,38,1,
	9,-1,-1,G_TEXT,FL3DBAK,NORMAL,53L,1,13,38,1,
	10,-1,-1,G_TEXT,FL3DBAK,NORMAL,54L,1,14,38,1,
	11,-1,-1,G_TEXT,FL3DBAK,NORMAL,55L,1,15,38,1,
	12,-1,-1,G_TEXT,FL3DBAK,NORMAL,56L,1,16,38,1,
	13,-1,-1,G_TEXT,FL3DBAK,NORMAL,57L,1,17,38,1,
	14,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|FL3DIND|FL3DBAK,NORMAL,208L,4,19,8,1,	/* OK */		
	15,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,209L,16,19,8,1,		/* SDRAM */
	0,-1,-1,G_BUTTON,SELECTABLE|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,210L,28,19,8,1,	/* Help */	

	/* alert box */
	-1,1,32,G_BOX,FL3DBAK,OUTLINED,0x21100L,0,0,42,30,
	2,-1,-1,G_BOXTEXT,FL3DIND,NORMAL,58L,0,0,42,1,
	3,-1,-1,G_IMAGE,NONE,NORMAL,1L,1,2,4,2,
	4,-1,-1,G_IMAGE,NONE,NORMAL,2L,1,2,4,2,
	5,-1,-1,G_IMAGE,NONE,NORMAL,3L,1,2,4,2,
	6,-1,-1,G_STRING,NONE,NORMAL,214L,1,2,40,1,
	7,-1,-1,G_STRING,NONE,NORMAL,215L,1,3,40,1,
	8,-1,-1,G_STRING,NONE,NORMAL,216L,1,4,40,1,
	9,-1,-1,G_STRING,NONE,NORMAL,217L,1,5,40,1,
	10,-1,-1,G_STRING,NONE,NORMAL,218L,1,6,40,1,
	11,-1,-1,G_STRING,NONE,NORMAL,219L,1,7,40,1,
	12,-1,-1,G_STRING,NONE,NORMAL,220L,1,8,40,1,
	13,-1,-1,G_STRING,NONE,NORMAL,221L,1,9,40,1,
	14,-1,-1,G_STRING,NONE,NORMAL,222L,1,10,40,1,
	15,-1,-1,G_STRING,NONE,NORMAL,223L,1,11,40,1,
	16,-1,-1,G_STRING,NONE,NORMAL,224L,1,12,40,1,
	17,-1,-1,G_STRING,NONE,NORMAL,225L,1,13,40,1,
	18,-1,-1,G_STRING,NONE,NORMAL,226L,1,14,40,1,
	19,-1,-1,G_STRING,NONE,NORMAL,227L,1,15,40,1,
	20,-1,-1,G_STRING,NONE,NORMAL,228L,1,16,40,1,
	21,-1,-1,G_STRING,NONE,NORMAL,229L,1,17,40,1,
	22,-1,-1,G_STRING,NONE,NORMAL,230L,1,18,40,1,
	23,-1,-1,G_STRING,NONE,NORMAL,231L,1,19,40,1,
	24,-1,-1,G_STRING,NONE,NORMAL,232L,1,20,40,1,
	25,-1,-1,G_STRING,NONE,NORMAL,233L,1,21,40,1,
	26,-1,-1,G_STRING,NONE,NORMAL,234L,1,22,40,1,
	27,-1,-1,G_STRING,NONE,NORMAL,235L,1,23,40,1,
	28,-1,-1,G_STRING,NONE,NORMAL,236L,1,24,40,1,
	29,-1,-1,G_STRING,NONE,NORMAL,237L,1,25,40,1,
	30,-1,-1,G_STRING,NONE,NORMAL,238L,1,26,40,1,
	31,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|FL3DIND|FL3DBAK,NORMAL,239L,1,28,10,1,
	32,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,240L,12,28,10,1,
	0,-1,-1,G_BUTTON,SELECTABLE|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,241L,23,28,10,1,

	/* TLV offset */
	-1,1,3,G_BOX,FL3DBAK,OUTLINED,0x21100L,0,0,33,5,
	2,-1,-1,G_FTEXT,EDITABLE|FL3DBAK,NORMAL,59L,1,1,31,1,
	3,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,245L,7,3,6,1,					/* OK */
	0,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,246L,20,3,6,1 };	/* Cancel */

long rs_trindex[] = {0L,98L,114L,147L};
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

#define NUM_STRINGS 247	/* number of strings */
#define NUM_FRSTR 0		/* strings form_alert */
#define NUM_IMAGES 0
#define NUM_BB 4		/* number of BITBLK */
#define NUM_FRIMG 0
#define NUM_IB 0		/* number of ICONBLK */
#define NUM_TI 60		/* number of TEDINFO */
#define NUM_OBS 151		/* number of objects */
#define NUM_TREE 4		/* number of trees */ 

#define TREE1 0
#define TREE2 1
#define TREE3 2
#define TREE4 3

#define MAX_SELECT 7
#define NB_BUB 49

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

char *spec_select[2][7]={"Charge moyenne","Temp‚rature","M‚moire / æP","Boot","Arrˆt/Divers","Langage","Vid‚o",
                         "Average load","Temperature","Memory / æP","Boot","Stop/Misc","Language","Video"};
char *_select[2][7]={"  Charge moyenne ","  Temp‚rature    ","  M‚moire / æP   ","  Boot           ","  Arrˆt/Divers   ","  Langage        ","  Vid‚o (boot)   ",
                     "  Average load   ","  Temperature    ","  Memory / æP    ","  Boot           ","  Stop/Misc      ","  Language       ","  Video (boot)   "};
char *spec_fpu[2][2]={"Non","Oui","No","Yes"};
char *fpu[2][2]={"  Non ","  Oui ","  No  ","  Yes "};
char *spec_div_freq[]={"/2","/3","/4","/5","/6"};
char *div_freq[]={"  /2 ","  /3 ","  /4 ","  /5 ","  /6 "};
char *spec_lang[]={"English","Deutsch","Fran‡ais","Espa¥ol","Italiano","Suisse","Schweiz"};
char *lang[]={ "  English     ",
               "  Deutsch     ",
               "  Fran‡ais    ",
               "  Espa¥ol     ",
               "  Italiano    ",
               "  Suisse      ",
               "  Schweiz     " };
char *spec_key[]={"USA","Deutsch","France","England","Espa¥a","Italia","Sweden","Suisse","Schweiz"};
char *key[]={ "  USA            ",
              "  Deutschland    ",
              "  France         ",
              "  England & Eire ",
              "  Espa¥a         ",
              "  Italia         ",
              "  Sweden         ",
              "  Suisse         ",
              "  Schweiz        " };
char *spec_date[]={"MM/DD/YY","DD/MM/YY","YY/MM/DD","YY/DD/MM"};
char *date[]={"  MM/DD/YY ","  DD/MM/YY ","  YY/MM/DD ","  YY/DD/MM "};
char *spec_time[]={"12","24"};
char *_time[]={"  12H ","  24H "};
char *spec_video[]={"TV","VGA"};
char *video[]={"  TV  ","  VGA "};
char *spec_mode[]={"NTSC","PAL"};
char *mode[]={"  NTSC ","  PAL  "};
char *spec_coul[]={" 2 "," 4 ","16","256","65536","16M"};
char *coul[]={"  2     ","  4     ","  16    ","  256   ","  65536 ","  16M   "};
char *spec_res[2][9]={"320x200","320x400","640x200","640x400","800x600","1024x768","1280x960","1600x1200","Pref.Mode",
                      "320x240","320x480","640x240","640x480","800x600","1024x768","1280x960","1600x1200","Pref.Mode"};
char *res[2][9]={"   320 x 200 ","   320 x 400 ","   640 x 200 ","   640 x 400 ",
                 "   800 x 600 ","  1024 x 768 ","  1280 x 960 ","  1600 x1200 ",
                 "  Pref. Mode ",
                 "   320 x 240 ","   320 x 480 ","   640 x 240 ","   640 x 480 ",
                 "   800 x 600 ","  1024 x 768 ","  1280 x 960 ","  1600 x1200 ",
                 "  Pref. Mode "};
char *spec_monitor_layout[6]={"DEFAULT","CRT,NONE","CRT,CRT","CRT,TMDS","TMDS,CRT","TMDS,TMDS"};
char *monitor_layout[6]={"  DEFAULT  ","  CRT,NONE ","  CRT,CRT  ","  CRT,TMDS "," TMDS,CRT  "," TMDS,TMDS "};
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
char *cache_delay[2][4]={"  Cache normal / Sans alerte copyback ",
                         "  Cache delais 5 S / Sans alerte      ",
                         "  Cache normal / Alerte copyback      ",
                         "  Cache delais 5 S / Alerte copyback  ",
                         "  Normal cache / No copyback alert    ",
                         "  Delay cache 5 S / No copyback alert ",
                         "  Normal cache / Copyback alert       ",
                         "  Delay cache 5 S / Copyback alert    "};
char *spec_boot_order[2][8]={"SCSI0-7 -> IDE0-1","IDE0-1 -> SCSI0-7","SCSI7-0 -> IDE1-0","IDE1-0 -> SCSI7-0",
                             "SCSI0-7 -> IDE0-1","IDE0-1 -> SCSI0-7","SCSI7-0 -> IDE1-0","IDE1-0 -> SCSI7-0",
                             "SCSI0-7 -> IDE0-1","IDE0-1 -> SCSI0-7","SCSI7-0 -> IDE1-0","IDE1-0 -> SCSI7-0",
                             "SCSI0-7 -> IDE0-1","IDE0-1 -> SCSI0-7","SCSI7-0 -> IDE1-0","IDE1-0 -> SCSI7-0"};
char *boot_order[2][8]={"  Nouv. boot SCSI0-7 -> IDE0-1 ",
                        "  Nouv. boot IDE0-1 -> SCSI0-7 ",
                        "  Nouv. boot SCSI7-0 -> IDE1-0 ",
                        "  Nouv. boot IDE1-0 -> SCSI7-0 ",
                        "  Vieux boot SCSI0-7 -> IDE0-1 ",
                        "  Vieux boot IDE0-1 -> SCSI0-7 ",
                        "  Vieux boot SCSI7-0 -> IDE1-0 ",
                        "  Vieux boot IDE1-0 -> SCSI7-0 ",
                        "  New boot SCSI0-7 -> IDE0-1 ",
                        "  New boot IDE0-1 -> SCSI0-7 ",
                        "  New boot SCSI7-0 -> IDE1-0 ",
                        "  New boot IDE1-0 -> SCSI7-0 ",
                        "  Old boot SCSI0-7 -> IDE0-1 ",
                        "  Old boot IDE0-1 -> SCSI0-7 ",
                        "  Old boot SCSI7-0 -> IDE1-0 ",
                        "  Old boot IDE1-0 -> SCSI7-0 "};
char *spec_video_log[2][2]={"Oui","Non","Yes","No"};
char *video_log[2][2]={"  Oui ","  Non ","  Yes ","  No  "};
char *spec_boot_log[2][2]={"Avec","Sans","With","Without"};
char *boot_log[2][2]={"  Avec ","  Sans ","  With    ","  Without "};
char *spec_ide_ctpci[2][2]={"FALCON","CTPCI","FALCON","CTPCI"};
char *ide_ctpci[2][2]={"  FALCON ","  CTPCI  ","  FALCON ","  CTPCI  "};
char *spec_ide_cf[2][2]={"IDE","CF","IDE","CF"};
char *ide_cf[2][2]={"  IDE          ","  CompactFlash ","  IDE          ","  CompactFlash "};
char *spec_serial_speed[]={"19200","9600","4800","3600","2400","2000","1800","1200","600","300","230400","115200","57600","38400","153600","76800"};
char *serial_speed[]={"   19200 ","    9600 ","    4800 ","    3600 ","    2400 ","    2000 ","    1800 ","    1200 ","     600 ","     300 ","  230400 ","  115200 ","   57600 ","   38400 ","  153600 ","   76800 "};
char *spec_day_stop[2][11]={"Sans","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche","Jours ouvr‚s","Fin de semaine","Chaque jour",
                            "Without","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday","Mon-Fri","Weekend","Every day"};
char *day_stop[2][11]={"  Sans           ","  Lundi          ","  Mardi          ","  Mercredi       ","  Jeudi          ","  Vendredi       ",
                       "  Samedi         ","  Dimanche       ","  Jours ouvr‚s   ","  Fin de semaine ","  Chaque jour    ",
                       "  Without   ","  Monday    ","  Tuesday   ","  Wednesday ","  Thursday  ","  Friday    ",
                       "  Saturday  ","  Sunday    ","  Mon-Fri   ","  Weekend   ","  Every day "};
char *spec_beepp[2][2]={"Non","Oui","No","Yes"};
char *beepp[2][2]={"  Non ","  Oui ","  No  ","  Yes "};

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
	{MENUBFPU,
	"Inhibe le FPU",
	"Disable the FPU"},
	{MENUBOXSLIDER,
	"Change la fr‚quence de|l'horloge de la CT60",
	"Change the frequency of|the clock of the CT60"},
	{MENUSLIDER,
	"Change la fr‚quence de|l'horloge de la CT60",
	"Change the frequency of|the clock of the CT60"},
	{MENUBDIV,
	"Change le diviseur de l'horloge|utilisateur de la CT60",
	"Change the divider of|the user clock on the CT60"},
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
	{MENUBRES,
	"S‚lectionne au d‚marrage|la r‚solution de l'‚cran",
	"Select screen resolution|at startup"},
	{MENUBCOUL,
	"S‚lectionne au d‚marrage|le nombre de couleurs",
	"Select number of colours|at startup"},	
	{MENUBMLAYOUT,
	"S‚lectionne au d‚marrage|le mapping des moniteurs",
	"Select monitor layout|at startup"},		
	{MENUSTMODES,
	"S‚lectionne au d‚marrage|le mode de compatibilit‚ ST",
	"Select ST compatibility mode|at startup"},
	{MENUOVERSCAN,
	"S‚lectionne au d‚marrage|le mode overscan sur TV",
	"Select TV overscan mode|at startup"},
	{MENUNVM,
	"Remplace la lecture NVRAM|par les valeurs TOS sauv‚s|en Flash. Utilise l'horloge|IKBD au lieu du RTC.",
	"Replace the NVRAM reading|by TOS values saved in the|Flash. Use the IKBD clock|instead of the RTC."},
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
	{MENUBBOOTLOG,
	"Redirige l'affichage des programmes|du dossier AUTO vers un fichier boot.log",
	"Redirect displays of the AUTO folder's|programs to a file boot.log"},
	{MENUBIDECTPCI,
	"Redirige le port principal IDE du|FALCON vers le port IDE de la CTPCI,|l'ancien restant disponible comme port no2",
	"Redirect the FALCON IDE port to|the CTPCI IDE port, the old port|is always available as a 2nd port"},
	{MENUBDAY,
	"S‚l‚ctionne le mode|d'extinction programm‚e|aprŠs une proc‚dure shutdown",
	"Select the stop mode programmed|after a shutdown procedure"},
	{MENUTIME,
	"Si le mode d'arrˆt est|activ‚, l'heure d'arrˆt|se r‚gle ici",
	"If stop mode is active,|the time must be entered here"},
	{MENUBBEEP,
	"Active le bip d'alame|de la phase d'arrˆt",
	"Enable the alarm beep|for the stop procedure"},
	{MENUBLANK,
	"Permet de couper le moniteur|aprŠs un certain temps|(si <> 0)",
	"Monitor blank after|a delay (0: disabled)"},
	
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
	COOKIE *p;
	HEAD *header;
	MX_KERNEL *mx_kernel;
	CT60_COOKIE *ct60_arg=NULL;
	Xcpb=xcpb;
#ifdef DEBUG
	printf("CPX init\r\nRead NVRAM\r\n");
#endif
	if(NVMaccess(0,0,(int)(sizeof(NVM)),&nvram)<0)	/* read */
	{
		form_alert(1,"[1][NVRAM read error !][Init]");
		NVMaccess(2,0,0,&nvram);					/* init */
		NVMaccess(0,0,(int)(sizeof(NVM)),&nvram);	/* read */
	}
	if(get_cookie('MiNT') != NULL)
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
	radeon=find_radeon();
	if(get_cookie(ID_CF) != NULL)
		coldfire=1;
	else
		coldfire=0;
	if(coldfire && ((unsigned long)Physbase() == 0x60000000UL))
		acp=1;
	else
		acp=0;
	if(!init_rsc())
		return(0);
#ifdef DEBUG
	printf("Test cookies\r\n");
#endif
	if(get_cookie('_AKP') == NULL)
	{
		apk.ident = '_AKP';						/* cookie created if not exists */
		apk.v.l = (((long)nvram.language)<<8) + (long)nvram.keyboard;
		add_cookie(&apk);
	}
	if(get_cookie('_IDT') == NULL)
	{
		idt.ident = '_IDT';						/* cookie created if not exists */
		idt.v.l = (((long)nvram.datetime)<<8) + (long)nvram.separator;
		add_cookie(&idt);
	}
	eiffel_media_keys = NULL;
	if((p = get_cookie('Eiff')) != NULL)
		eiffel_media_keys = (short *)p->v.l;
	eiffel_temp=NULL;
	if((p = get_cookie('Temp')) != NULL)
		eiffel_temp = (char *)p->v.l;
	for(i=0;i<61;i++)
		tab_temp[i]=tab_temp_eiffel[i]=tab_cpuload[i]=0;
#ifdef DEBUG
	printf("Read CPX header\r\n");
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
	beep=(int)header->beep&1;
	timeblank=header->timeblank;
	if(!loops_per_sec)
	{
#ifdef DEBUG
		printf("Test mips\r\n");
#endif
		loops_per_sec=bogomips();
#ifdef DEBUG
		printf("%ld loops/sec\r\n",loops_per_sec);
#endif
	}
	if(mint || magic)
	{
#ifdef DEBUG
		printf("MiNT/MagiC appl_find(NULL)\r\n");
#endif
		ap_id=appl_find(NULL);
	}
	else										/* single task system */
	{
		if((ap_id=appl_find("XCONTROL"))<0
		 && (ap_id=appl_find("ZCONTROL"))<0
		 && (ap_id=appl_find("COPS    "))<0
		 && (ap_id=appl_find("FREEDOM2"))<0)
			ap_id=-1;
	}
#ifdef DEBUG
	printf("ap_id acc %d\r\n",ap_id);
#endif
	if((get_cookie(ID_CT60) != NULL) || coldfire)
		flag_xbios=1;
	else
		flag_xbios=0;
	if((((p = get_cookie('_MCH')) != NULL) && (p->v.l == 0x30000)	/* Falcon */
	 && (flag_xbios || test_060()))								/* & CT60 */
	 && (ap_id >= 0))
	{
#ifdef DEBUG
		printf("Start temperature task\r\n");
#endif
		if((ct60_arg = get_cookie_ct60()) != NULL)
		{
			ct60_arg->trigger_temp=(unsigned short)trigger_temp;
			ct60_arg->daystop=(unsigned short)daystop;
			ct60_arg->timestop=(unsigned short)timestop;
			ct60_arg->beep=(unsigned short)beep;
			ct60_arg->timeblank=(unsigned short)timeblank;  	/* ACC cannot receive arg */
		}	
		start_temp(&trigger_temp,&daystop,&timestop,&beep,&timeblank);	/* start thread or CT60TEMP.APP */
	}
#ifdef DEBUG
	printf("CPX init finished\r\n");
#endif
	return(&cpxinfo);
}

int CDECL cpx_call(GRECT *work)
{
	GRECT menu;
	TEDINFO *t_edinfo;
	long value,stack;
	static char mess_alert[256];
	HEAD *header;
	COOKIE *p;
	CT60_COOKIE *ct60_arg=NULL;
	int ret;
	int mlayout;
	register int i;
#ifdef DEBUG
	printf("CPX call\r\nOpen virtual workstation\r\n");
#endif	
	if((vdi_handle = Xcpb->handle) > 0)
	{
		v_opnvwk(work_in,&vdi_handle,work_out);
		if((vdi_handle <= 0) || ((head = get_header(ID_CPX)) == NULL))
			return(0);
	}
	else
		return(0);
#ifdef DEBUG
	printf("Test cookies\r\n");
#endif
	if(((p = get_cookie('_MCH')) == NULL) || (p->v.l != 0x30000))	/* Falcon */
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
		if(tosram < 0)
		{
			if(!start_lang)
				form_alert(1,"[1][Pas de CT60 !][OK]");
			else
				form_alert(1,"[1][CT60 not found!][OK]");
		}
	}
	if(!coldfire && ((ap_id < 0) || (temp_id < 0)) && test_060())
	{
		if(!start_lang)
			form_alert(1,"[1][ATTENTION !|Il n'est pas possible de|surveiller la temp‚rature quand|ce CPX sera ferm‚ !|S.V.P.installez CT60TEMP.ACC/APP][OK]");
		else
			form_alert(1,"[1][WARNING!|It is not possible to monitor|the temperature when this CPX|is closed!  Please install|CT60TEMP.ACC/APP][OK]");
	}
	if(!radeon)
		radeon=find_radeon();
	if(coldfire)
		selection=PAGE_BOOT;
	else
		selection=PAGE_TEMP;
	flag_bubble=0;
	rs_object[MENUBOX].ob_x=work->g_x;
	rs_object[MENUBOX].ob_y=work->g_y;
	rs_object[MENUBOX].ob_width=work->g_w;
	rs_object[MENUBOX].ob_height=work->g_h;
#ifdef DEBUG
	printf("Read NVRAM\r\n");
#endif
	NVMaccess(0,0,(int)(sizeof(NVM)),&nvram);	/* read */
#ifdef DEBUG
	printf("Read CPX header\r\n");
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
	beep=(int)header->beep&1;
	t_edinfo=rs_object[MENUBBEEP].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_beepp[start_lang][beep];
	timeblank=header->timeblank;
	if(timeblank>99)
		timeblank=99;
	t_edinfo=rs_object[MENUBLANK].ob_spec.tedinfo;
	sprintf(t_edinfo->te_ptext,"%d",timeblank);
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
	if(((ct60_arg = get_cookie_ct60()) != NULL) && ct60_arg->speed_fan)
		sprintf(t_edinfo->te_ptext,"æP: %3lu.%02lu Mips     %04u tr/mn",
		loops_per_sec/500000,(loops_per_sec/5000) % 100,ct60_arg->speed_fan);
	else
		sprintf(t_edinfo->te_ptext,"æP: %3lu.%02lu Mips",loops_per_sec/500000,(loops_per_sec/5000) % 100);
	language=0;
	while(language<7 && nvram.language!=code_lang[language])
		language++;
	if(language>=7)
		language=0;	
	keyboard=0;
	while(keyboard<9 && nvram.keyboard!=code_key[keyboard])
		keyboard++;
	if(keyboard>=9)
		keyboard=0;
	datetime=(int)nvram.datetime & 0x13;
	vmode=(int)nvram.vmode & (VERTFLAG|STMODES|OVERSCAN|PAL|VGA_FALCON|COL80|NUMCOLS);
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
	if(radeon || acp)
	{
		if(flag_xbios)
			value=ct60_rw_parameter(CT60_MODE_READ,CT60_VMODE,0L);
		else
		{
			stack=Super(0L);
			value=ct60_rw_param(CT60_MODE_READ,CT60_VMODE,0L);
			Super((void *)stack);
		}
		vmode_prefered=width_max_mono=height_max_mono=width_prefered=height_prefered=0;
		Vsetscreen(-1,&enumfunc,'VN',CMD_ENUMMODES);
		if((width_prefered>=0) && (width_prefered<=9999) && (height_prefered>=0) && (height_prefered<=9999))
		{
			sprintf(spec_res[1][8],"%dx%d",width_prefered,height_prefered);
			if(height_prefered<=999)
				sprintf(res[1][8],"  %04d x %03d ",width_prefered,height_prefered);
			else
				sprintf(res[1][8],"  %04d x%04d ",width_prefered,height_prefered);
		}
		if((value<0) || ((value & DEVID) && !vmode_prefered))
			vmode = PAL|VGA_FALCON|COL80|BPS16;
		else if(value & DEVID) /* bits 11-3 used for devID */
		{
			vmode=(int)value & ~VIRTUAL_SCREEN;
			if( ((vmode & NUMCOLS) != BPS1) && (((vmode & NUMCOLS) < BPS8) || ((vmode & NUMCOLS) > BPS32)))
			{
				vmode &= ~NUMCOLS;
				vmode |= BPS8;
			}
		}
		else /* normal modecode */
		{
			vmode = (int)value & (VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|PAL|VGA_FALCON|COL80|NUMCOLS);
			vmode &= ~(VIRTUAL_SCREEN|OVERSCAN);
			vmode |= (PAL|VGA_FALCON);
			if(((vmode & NUMCOLS) == BPS1) && width_max_mono && height_max_mono) /* VGA monochrome emulation */
			{
				switch(vmode & (VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|STMODES|VGA_FALCON|COL80))
				{
					case (VERTFLAG+VGA_FALCON):                      /* 320 * 240 */
					case (VGA_FALCON+COL80):                         /* 640 * 480 */
					case (VESA_600+HORFLAG2+VGA_FALCON+COL80):       /* 800 * 600 */
					case (VESA_768+HORFLAG2+VGA_FALCON+COL80):       /* 1024 * 768 */
						break;
					default:
						vmode = PAL|VGA_FALCON|COL80|BPS1;           /* 640 * 480 * 1 */
						break;
				}
			}
			else if(((vmode & NUMCOLS) < BPS8) || ((vmode & NUMCOLS) > BPS32))
			{
				vmode &= (PAL|VGA_FALCON|COL80);
				vmode |= BPS8;
			}
			if(vmode & COL80)
				vmode &= ~VERTFLAG;
			else
				vmode |= VERTFLAG;
		}
		if((vmode & DEVID) && vmode_prefered)
		{
			if((vmode & NUMCOLS) == BPS1) /* VBL monochrome emulation */
			{
				if((width_max_mono >= width_prefered) && (height_max_mono >= width_prefered))
					i=8; /* prefered mode */
				else
					i=3;			
			}
			else
				i=8; /* prefered mode */
		}
		else
		{
			i=3;
			ret=VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG;
			if(!(vmode & ret))
			{
				i=0;      /* 320 * 240 */
				if(vmode & COL80)
					i=3;  /* 640 * 480 */
			}
			else
			{
				if((vmode & NUMCOLS) == BPS1)
				{
					if(((vmode & ret) == (VESA_600|HORFLAG2)) && (width_max_mono >= 800) && (height_max_mono >= 600))
						i=4;  /* 800 * 600 */
					else if(((vmode & ret) == (VESA_768|HORFLAG2)) && (width_max_mono >= 1024) && (height_max_mono >= 768))
						i=5;  /* 1024 * 768 */
					else if(((vmode & ret) == (VERTFLAG2|HORFLAG)) && (width_max_mono >= 1280) && (height_max_mono >= 960))
						i=6;  /* 1280 * 960 */
					else if(((vmode & ret) == (VERTFLAG2|VESA_600|HORFLAG2|HORFLAG)) && (width_max_mono >= 1600) && (height_max_mono >= 1200))
						i=7;  /* 1600 * 1200 */
				}
				else
				{
					if((vmode & ret) == (VESA_600|HORFLAG2))
						i=4;  /* 800 * 600 */
					else if((vmode & ret) == (VESA_768|HORFLAG2))
						i=5;  /* 1024 * 768 */
					else if((vmode & ret) == (VERTFLAG2|HORFLAG))
						i=6;  /* 1280 * 960 */
					else if((vmode & ret) == (VERTFLAG2|VESA_600|HORFLAG2|HORFLAG))
						i=7;  /* 1600 * 1200 */
				}
			}
		}
		rs_object[MENUOVERSCAN].ob_state &= ~SELECTED;
		rs_object[MENUSTMODES].ob_state &= ~SELECTED;
		rs_object[MENUSTMODES].ob_flags &= ~TOUCHEXIT;
		rs_object[MENUSTMODES].ob_flags |= HIDETREE;
		rs_object[MENUBMLAYOUT].ob_flags |= TOUCHEXIT;
		rs_object[MENUBMLAYOUT].ob_flags &= ~HIDETREE;
		t_edinfo=rs_object[MENUBVIDEO].ob_spec.tedinfo;
		t_edinfo->te_ptext=spec_video[1];
		t_edinfo=rs_object[MENUBMODE].ob_spec.tedinfo;
		t_edinfo->te_ptext=spec_mode[1];
	}
	else /* VIDEL */
	{
		i=0;
		if(vmode & COL80)
			i+=2;
		if(!(vmode & VERTFLAG) && (vmode & VGA_FALCON))
			i++;
		if((vmode & VERTFLAG) && !(vmode & VGA_FALCON))
			i++;
		if((vmode & OVERSCAN) && !(vmode & VGA_FALCON))
			rs_object[MENUOVERSCAN].ob_state |= SELECTED;
		else
			rs_object[MENUOVERSCAN].ob_state &= ~SELECTED;		
		if((vmode & STMODES) && (vmode & NUMCOLS)<BPS8)
		{
			rs_object[MENUSTMODES].ob_state |= SELECTED;
			switch(vmode & NUMCOLS)
			{
			case 0:				/* 640 x 400 */	
				i=3;
				vmode |= COL80;
				if(vmode & VGA_FALCON)
					vmode &= ~VERTFLAG;
				else
					vmode |= VERTFLAG;
				break;
			case 1:				/* 640 x 200 */
				i=2;
				vmode |= COL80;
				if(vmode & VGA_FALCON)
					vmode |= VERTFLAG;
				else
					vmode &= ~VERTFLAG;
				break;
			case 2:				/* 320 x 200 */
				i=0;
				vmode &= ~COL80;
				if(vmode & VGA_FALCON)
					vmode |= VERTFLAG;
				else
					vmode &= ~VERTFLAG;
				break;
			}
		}
		else
		{
			rs_object[MENUSTMODES].ob_state &= ~SELECTED;
			if((vmode & NUMCOLS)>=BPS8)
				vmode &= ~STMODES;	
		}
		rs_object[MENUSTMODES].ob_flags |= TOUCHEXIT;
		rs_object[MENUSTMODES].ob_flags &= ~HIDETREE;
		rs_object[MENUBMLAYOUT].ob_flags &= ~TOUCHEXIT;
		rs_object[MENUBMLAYOUT].ob_flags |= HIDETREE;		
		t_edinfo=rs_object[MENUBVIDEO].ob_spec.tedinfo;
		t_edinfo->te_ptext=spec_video[((vmode & VGA_FALCON)>>4) & 1];
		t_edinfo=rs_object[MENUBMODE].ob_spec.tedinfo;
		t_edinfo->te_ptext=spec_mode[((vmode & PAL)>>5) & 1];
	}
	t_edinfo=rs_object[MENUBCOUL].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_coul[vmode & NUMCOLS];
	t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_res[(vmode & VGA_FALCON) ? 1 : 0][i];
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
		serialspeed=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_SERIAL_SPEED,0L);
		cachedelay=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_CACHE_DELAY,0L)&3;
		bootorder=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_BOOT_ORDER,0L)&7;
		bootlog=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_BOOT_LOG,0L)&3;
		cpufpu=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_CPU_FPU,0L)&1;
		nv_magic_code=(int)((ct60_rw_parameter(CT60_MODE_READ,CT60_SAVE_NVRAM_1,0L)>>16) & 0xffff);
		if(coldfire)
		{
			mac_address=(unsigned long)ct60_rw_parameter(CT60_MODE_READ,CT60_MAC_ADDRESS,0L);
			ip_address=(unsigned long)ct60_rw_parameter(CT60_MODE_READ,CT60_IP_ADDRESS,0L);
			server_ip_address=(unsigned long)ct60_rw_parameter(CT60_MODE_READ,CT60_SERVER_IP_ADDRESS,0L);		
		}
		else
		{
			frequency=(unsigned long)ct60_rw_parameter(CT60_MODE_READ,CT60_CLOCK,0L);
			div_frequency=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_USER_DIV_CLOCK,0L);		
		}
		idectpci=(int)ct60_rw_parameter(CT60_MODE_READ,CT60_PARAM_CTPCI,0L);
	}
	else
	{
		stack=Super(0L);
		tosram=(int)ct60_rw_param(CT60_MODE_READ,CT60_PARAM_TOSRAM,0L)&1;
		blitterspeed=(int)ct60_rw_param(CT60_MODE_READ,CT60_BLITTER_SPEED,0L)&1;
		serialspeed=(int)ct60_rw_param(CT60_MODE_READ,CT60_SERIAL_SPEED,0L);
		cachedelay=(int)ct60_rw_param(CT60_MODE_READ,CT60_CACHE_DELAY,0L)&3;
		bootorder=(int)ct60_rw_param(CT60_MODE_READ,CT60_BOOT_ORDER,0L)&7;
		bootlog=(int)ct60_rw_param(CT60_MODE_READ,CT60_BOOT_LOG,0L)&3;
		cpufpu=(int)ct60_rw_param(CT60_MODE_READ,CT60_CPU_FPU,0L)&1;
		nv_magic_code=(int)((ct60_rw_param(CT60_MODE_READ,CT60_SAVE_NVRAM_1,0L)>>16) & 0xffff);
		if(coldfire)
		{
			mac_address=(unsigned long)ct60_rw_param(CT60_MODE_READ,CT60_MAC_ADDRESS,0L);
			ip_address=(unsigned long)ct60_rw_param(CT60_MODE_READ,CT60_IP_ADDRESS,0L);
			server_ip_address=(unsigned long)ct60_rw_param(CT60_MODE_READ,CT60_SERVER_IP_ADDRESS,0L);		
		}
		else
		{
			frequency=(unsigned long)ct60_rw_param(CT60_MODE_READ,CT60_CLOCK,0L);
			div_frequency=(int)ct60_rw_param(CT60_MODE_READ,CT60_USER_DIV_CLOCK,0L);
		}
		idectpci=(int)ct60_rw_param(CT60_MODE_READ,CT60_PARAM_CTPCI,0L);
		Super((void *)stack);
	}
	t_edinfo=rs_object[MENUBMLAYOUT].ob_spec.tedinfo;
	mlayout=idectpci>>2;
	idectpci&=3;
	if((mlayout<0) || (mlayout>5))
		mlayout=0;
	t_edinfo->te_ptext=spec_monitor_layout[mlayout];
	flag_frequency=0; /* modif */
	step_frequency=125;
	min_freq=MIN_FREQ;
	if(version_060()<6)
		max_freq=MAX_FREQ_REV1;
	else
		max_freq=MAX_FREQ_REV6;
	if(frequency<min_freq || frequency>max_freq)
		frequency=min_freq;
	if(div_frequency<2)
		div_frequency=2;
	if(div_frequency>6)
		div_frequency=6;
	if((serialspeed<0) || (serialspeed>15))
		serialspeed=0;
	t_edinfo=rs_object[MENUBTOSRAM].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_tos_ram[start_lang][tosram];
	if(radeon || acp)
	{
		if(coldfire || ((long)Supexec(get_version_flash) >= 0x200))
		{
			t_edinfo->te_ptext=spec_video_log[start_lang][(bootlog>>1)&1];
			rs_object[MENUBTOSRAM-1].ob_spec.free_string = "video.log:";
		}
		if(!start_lang)
			rs_object[MENUOVERSCAN].ob_spec.free_string = "Utilise DMA";
		else
			rs_object[MENUOVERSCAN].ob_spec.free_string = "Use DMA";
		if(idectpci & 2) /* DMA */
			rs_object[MENUOVERSCAN].ob_state |= SELECTED;
		else
			rs_object[MENUOVERSCAN].ob_state &= ~SELECTED;	
	}
	if(nv_magic_code=='NV')
		rs_object[MENUNVM].ob_state |= SELECTED;
	else
		rs_object[MENUNVM].ob_state &= ~SELECTED;
	t_edinfo=rs_object[MENUBBLITTER].ob_spec.tedinfo;
	if(coldfire)
		t_edinfo->te_ptext=spec_serial_speed[serialspeed];	
	else
		t_edinfo->te_ptext=spec_blitter_speed[start_lang][blitterspeed];
	t_edinfo=rs_object[MENUBCACHE].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_cache_delay[start_lang][cachedelay];
	t_edinfo=rs_object[MENUBBOOTORDER].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_boot_order[start_lang][bootorder];
	t_edinfo=rs_object[MENUBBOOTLOG].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_boot_log[start_lang][bootlog&1];
	t_edinfo=rs_object[MENUBIDECTPCI].ob_spec.tedinfo;
	if(coldfire)
		t_edinfo->te_ptext=spec_ide_cf[start_lang][idectpci&1];
	else
		t_edinfo->te_ptext=spec_ide_ctpci[start_lang][idectpci&1];
	t_edinfo=rs_object[MENUBFPU].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_fpu[start_lang][cpufpu];
	t_edinfo=rs_object[MENUBDIV].ob_spec.tedinfo;
	t_edinfo->te_ptext=spec_div_freq[div_frequency-2];
	t_edinfo=rs_object[MENUMAC].ob_spec.tedinfo;
	sprintf(t_edinfo->te_ptext,"%02X%02X%02X",(int)((mac_address>>16)&255),(int)((mac_address>>8)&255),(int)(mac_address&255));
	t_edinfo=rs_object[MENUIP].ob_spec.tedinfo;
	sprintf(t_edinfo->te_ptext,"%03d%03d%03d%03d",(int)((ip_address>>24)&255),(int)((ip_address>>16)&255),(int)((ip_address>>8)&255),(int)(ip_address&255));
	t_edinfo=rs_object[MENUSERVERIP].ob_spec.tedinfo;
	sprintf(t_edinfo->te_ptext,"%03d%03d%03d%03d",(int)((server_ip_address>>24)&255),(int)((server_ip_address>>16)&255),(int)((server_ip_address>>8)&255),(int)(server_ip_address&255));
	ed_pos=ed_objc=0;
	Work=work;
	t_edinfo=rs_object[MENUBSELECT].ob_spec.tedinfo;
	if(test_060())
	{
		if(coldfire)
		{
			t_edinfo->te_ptext=spec_select[start_lang][PAGE_BOOT];
			display_selection(PAGE_BOOT,0);
			selection=-1;
			cpx_timer(&ret);
			selection=PAGE_BOOT;
		}
		else
		{
			t_edinfo->te_ptext=spec_select[start_lang][PAGE_TEMP];
			display_selection(PAGE_TEMP,0);
			selection=-1;
			cpx_timer(&ret);
			selection=PAGE_TEMP;
		}
		ed_objc=MENUTRIGGER;
		no_jumper=0;
		if(coldfire || (value=ct60_read_clock())<0)
			frequency=0;                 /* no programmable clock */
		else
		{
			if(step_frequency==DAC_STEP) /* Dallas DS1085 programmable clock */
			{
				min_freq=MIN_FREQ_DALLAS+600UL;
				if((ct60_arg = get_cookie_ct60()) != NULL)
				{
#ifdef DEBUG
					printf("CPU frequency: %3lu.%01lu MHz\r\n",ct60_arg->cpu_frequency/10,ct60_arg->cpu_frequency%10);
#endif
					if(ct60_arg->cpu_frequency==0)
					{
						ct60_arg->cpu_frequency=loops_per_sec/100000; /* for MagiC */
#ifdef DEBUG
						printf("CPU frequency from bogomips: %3lu.%01lu MHz\r\n",ct60_arg->cpu_frequency/10,ct60_arg->cpu_frequency%10);
#endif						
					}
#if 0
					if(((ct60_arg->cpu_frequency*100UL) < (MIN_FREQ_DALLAS+300UL))
					 && ((loops_per_sec/1000) < (MIN_FREQ_DALLAS+300UL)))
					{                        /* strap on CLK/2 */
						min_freq=(MIN_FREQ_DALLAS+600UL)/2;
						max_freq=MIN_FREQ_DALLAS;
						value>>=1;           /* /2 */
						no_jumper=1;
					}	                     /* strap on CLK */
#endif
				}
			}
			if(value<min_freq || value>max_freq)
			{
		 		if(!start_lang)
					sprintf(mess_alert,"[1][ATTENTION !|La fr‚quence actuelle dans|le g‚n‚rateur d'horloge|est anormale: %ld MHz !][Continuer]",value/1000);
				else
					sprintf(mess_alert,"[1][WARNING!|The actual frequency inside|the clock generator|is abnormal: %ld MHz!][Continue]",value/1000);
				form_alert(1,mess_alert);
			}
			else
				frequency=(unsigned long)value;
		}
	}
	else						/* read temperature not works in normal mode */
	{
		t_edinfo->te_ptext=spec_select[start_lang][PAGE_MEMORY];
		display_selection(PAGE_MEMORY,0);
		selection=-1;
		cpx_timer(&ret);
		selection=PAGE_MEMORY;
	}
	init_slider();
	objc_edit(rs_object,ed_objc,0,&ed_pos,ED_INIT);
	new_objc=ed_objc;
	new_pos=ed_pos;
	cpx_draw(work);
	(*Xcpb->Set_Evnt_Mask)(MU_KEYBD|MU_BUTTON|MU_TIMER,0L,0L,ITIME);
	if(temp_id>=0)
		send_ask_temp();
#ifdef DEBUG
	printf("CPX call finished\r\n");
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
	unsigned int time,new_trigger,new_timestop,new_timeblank;
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
			if(((ct60_arg = get_cookie_ct60()) != NULL) && ct60_arg->speed_fan)
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
	t_edinfo=rs_object[MENUBLANK].ob_spec.tedinfo;	
	new_timeblank=(unsigned int)atoi(t_edinfo->te_ptext);
	if((new_trigger!=trigger_temp) || (new_timestop!=timestop) || (daystop!=old_daystop) || (timeblank!=new_timeblank))
	{
		trigger_temp=new_trigger;
		timestop=new_timestop;
		timeblank=new_timeblank;
		if(temp_id>=0)
			send_ask_temp();
		old_daystop=daystop;	
	}
	bubble_help();
	if(time_out_thread>=0)
	{
		time_out_thread++;
		if(!coldfire && (time_out_thread>10))
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
	register int i,j,k,objc_clic,pos_clic;
	register TEDINFO *t_edinfo;
	int ret,xoff,yoff,attrib[10];
	int mlayout=0;
	static char mess_alert[256];
	long value,stack,offset;
	GRECT menu;
	HEAD *header;
	CT60_COOKIE *ct60_arg=NULL;
	OBJECT *info_tree, *offset_tree;
	static MRETS old_mouse;
	EVNTDATA mouse;
	if((mrets->buttons & 2)!=0					/* right button */
	 || ((mrets->buttons & 2)==0 && (old_mouse.buttons & 2)!=0))
	{
		bubble_help();							/* for COPS */
		old_mouse.buttons=mrets->buttons;
		return;
	}
	old_mouse.buttons=mrets->buttons;
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
					if(coldfire)
						offset=0;
					else if(flag_xbios)
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
						if(!coldfire)
						{
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
				}
				break;				
			case MENUMIPS:
				loops_per_sec=bogomips();
				t_edinfo=rs_object[MENUMIPS].ob_spec.tedinfo;
				if(((ct60_arg = get_cookie_ct60()) != NULL) && ct60_arg->speed_fan)
					sprintf(t_edinfo->te_ptext,"æP: %3lu.%02lu Mips     %04u tr/mn",
					loops_per_sec/500000,(loops_per_sec/5000) % 100,ct60_arg->speed_fan);
				else
					sprintf(t_edinfo->te_ptext,"æP: %3lu.%02lu Mips",loops_per_sec/500000,(loops_per_sec/5000) % 100);
				display_objc(MENUMIPS,Work);	
				break;
			case MENUBFPU:
				objc_offset(rs_object,MENUBFPU,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBFPU].ob_width;
				menu.g_h=rs_object[MENUBFPU].ob_height;
				ret=(*Xcpb->Popup)(fpu[start_lang],2,cpufpu,IBM,&menu,Work);
				if(ret>=0 && ret!=cpufpu)
				{
					t_edinfo=rs_object[MENUBFPU].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_fpu[start_lang][ret];
					display_objc(MENUBFPU,Work);				
					cpufpu=ret;
				}
				break;
			case MENUBLEFT:
				if(frequency>min_freq)
				{
					change_objc(MENUBLEFT,SELECTED,Work);
					frequency-=step_frequency;
					if(frequency<min_freq)
						frequency=min_freq;
					flag_frequency=1;
					display_slider(Work);						
					change_objc(MENUBLEFT,NORMAL,Work);
					do
						graf_mkstate(&mouse);	/* wait end of clic */
					while(mouse.bstate);
 				}
				break;
			case MENUBOXSLIDER:
				graf_mkstate(&mouse);
				objc_offset(rs_object,MENUSLIDER,&ret,&mouse.y);
				if(mouse.x>ret)
					frequency+=1000;
 				else
					frequency-=1000;
				if(frequency<min_freq)
					frequency=min_freq;
				if(frequency>max_freq)
					frequency=max_freq;
				flag_frequency=1;
				display_slider(Work);
				do
					graf_mkstate(&mouse);	/* wait end of clic */
				while(mouse.bstate);
				break;
			case MENUSLIDER:
				wind_update(BEG_MCTRL);
				ret=graf_slidebox(rs_object,MENUBOXSLIDER,MENUSLIDER,0);
				wind_update(END_MCTRL);
				frequency=((unsigned long)ret*(max_freq-min_freq))/1000UL;
				frequency/=step_frequency;
				frequency*=step_frequency;
				frequency+=min_freq;
				flag_frequency=1;
				display_slider(Work);
				break;
			case MENUBRIGHT:
				if(frequency<max_freq)
				{
					change_objc(MENUBRIGHT,SELECTED,Work);
					frequency+=step_frequency;
					if(frequency>max_freq)
						frequency=max_freq;
					flag_frequency=1;
					display_slider(Work);
					change_objc(MENUBRIGHT,NORMAL,Work);
					do
						graf_mkstate(&mouse);	/* wait end of clic */
					while(mouse.bstate);
				}
				break;
			case MENUBDIV:
				objc_offset(rs_object,MENUBDIV,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBDIV].ob_width;
				menu.g_h=rs_object[MENUBDIV].ob_height;
				ret=(*Xcpb->Popup)(div_freq,5,div_frequency-2,IBM,&menu,Work);
				if(ret>=0 && ret!=(div_frequency-2))
				{
					t_edinfo=rs_object[MENUBDIV].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_div_freq[ret];
					display_objc(MENUBDIV,Work);				
					div_frequency=ret+2;
				}
				break;
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
					if(radeon || acp)
						ret=1;
					else if(ret && (vmode & COL80) && (vmode & NUMCOLS)==BPS16)
						ret=0;
					t_edinfo=rs_object[MENUBVIDEO].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_video[ret];
					display_objc(MENUBVIDEO,Work);
					if(ret)
					{
						vmode |= VGA_FALCON;
						if(!radeon && !acp)
						{
							vmode &= ~OVERSCAN;	
							change_objc(MENUOVERSCAN,NORMAL,Work);
						}
					}
					else
						vmode &= ~VGA_FALCON;
					if(!radeon && !acp)
					{
						i=0;
						if(vmode & COL80)
							i+=2;
						if(!(vmode & VERTFLAG) && (vmode & VGA_FALCON))
							i++;
						if((vmode & VERTFLAG) && !(vmode & VGA_FALCON))
							i++;
						t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
						t_edinfo->te_ptext=spec_res[(vmode & VGA_FALCON) ? 1 : 0][i];
						display_objc(MENUBRES,Work);
					}
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
					if(radeon || acp)
						ret=1;
					t_edinfo=rs_object[MENUBMODE].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_mode[ret];
					display_objc(MENUBMODE,Work);
					if(ret)
						vmode |= PAL;
					else
						vmode &= ~PAL;
				}		
				break;		
			case MENUBRES:
				objc_offset(rs_object,MENUBRES,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBRES].ob_width;
				menu.g_h=rs_object[MENUBRES].ob_height;
				if(radeon || acp)
				{
					if((vmode & DEVID) && vmode_prefered)
					{
						if((vmode & NUMCOLS) == BPS1) /* VBL monochrome emulation */
						{
							if((width_max_mono >= width_prefered) && (height_max_mono >= width_prefered))
								i=8; /* prefered mode */
							else
								i=3;			
						}
						else
							i=8; /* prefered mode */
					}
					else
					{
						i=3;
						ret=VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG;
						if(!(vmode & ret))
						{
							i=0;    /* 320 * 240 */
							if(vmode & COL80)
								i=3;  /* 640 * 480 */
						}
						else
						{	
							if((vmode & NUMCOLS) == BPS1)
							{
								if(((vmode & ret) == (VESA_600|HORFLAG2)) && (width_max_mono >= 800) && (height_max_mono >= 600))
									i=4;  /* 800 * 600 */
								else if(((vmode & ret) == (VESA_768|HORFLAG2)) && (width_max_mono >= 1024) && (height_max_mono >= 768))
									i=5;  /* 1024 * 768 */
								else if(((vmode & ret) == (VERTFLAG2|HORFLAG)) && (width_max_mono >= 1280) && (height_max_mono >= 960))
									i=6;  /* 1280 * 960 */
								else if(((vmode & ret) == (VERTFLAG2|VESA_600|HORFLAG2|HORFLAG)) && (width_max_mono >= 1600) && (height_max_mono >= 1200))
									i=7;  /* 1600 * 1200 */
							}
							else
							{
								if((vmode & ret) == (VESA_600|HORFLAG2))
									i=4;  /* 800 * 600 */
								else if((vmode & ret) == (VESA_768|HORFLAG2))
									i=5;  /* 1024 * 768 */
								else if((vmode & ret) == (VERTFLAG2|HORFLAG))
									i=6;  /* 1280 * 960 */
								else if((vmode & ret) == (VERTFLAG2|VESA_600|HORFLAG2|HORFLAG))
									i=7;  /* 1600 * 1200 */							
							}
						}
					}
					if((vmode & NUMCOLS) == BPS1) /* VBL monochorme emulation */
					{			
						ret = 4;
						if((width_max_mono >= 800) && (height_max_mono >= 600))
							ret = 5;
						if((width_max_mono >= 1024) && (height_max_mono >= 768))
							ret = 6;
						if((width_max_mono >= 1280) && (height_max_mono >= 960))
							ret = 7;
						if((width_max_mono >= 1600) && (height_max_mono >= 1200))
							ret = 8;
					}
					else
						ret = 8;
				}
				else
				{
					i=0;
					if(vmode & COL80)
						i+=2;
					if(!(vmode & VERTFLAG) && (vmode & VGA_FALCON))
						i++;
					if((vmode & VERTFLAG) && !(vmode & VGA_FALCON))
						i++;
				}
				ret=(*Xcpb->Popup)(res[(vmode & VGA_FALCON) ? 1 : 0],(radeon || acp) ? (vmode_prefered && ((vmode & NUMCOLS) != BPS1)) ? 9 : ret : 4,i,IBM,&menu,Work);
				if(ret>=0 && ret!=i)
				{
					if(radeon || acp)
					{
						if(ret==1)
							ret--;
						else if(ret==2)
							ret++;
					}
					else
					{
						if(ret<2)
						{
							if((vmode & NUMCOLS) == BPS1)
								ret+=2;					
						}
						else
						{
							if((vmode & VGA_FALCON) && (vmode & NUMCOLS) == BPS16)
								ret-=2;
						}
						if(vmode & STMODES)
						{
							switch(vmode & NUMCOLS)
							{
							case 0: ret=3; break;		/* 640 x 400 */
							case 1: ret=2; break;		/* 640 x 200 */
							default: ret=0; break;		/* 320 x 200 */
							}
						}
					}
					t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_res[(vmode & VGA_FALCON) ? 1 : 0][ret];
					display_objc(MENUBRES,Work);
					if(radeon || acp)
					{
						switch(ret)
						{
							case 0:
							case 1:        /* 320 * 240 */
								vmode = (VERTFLAG|PAL|VGA_FALCON) | (vmode & NUMCOLS); break;
							case 2:
							case 3:        /* 640 * 480 */
								vmode = (PAL|VGA_FALCON|COL80) | (vmode & NUMCOLS); break;
							case 4:        /* 800 * 600 */
								vmode = (VESA_600|HORFLAG2|PAL|VGA_FALCON|COL80) | (vmode & NUMCOLS); break;
							case 5:        /* 1024 * 768 */
								vmode = (VESA_768|HORFLAG2|PAL|VGA_FALCON|COL80) | (vmode & NUMCOLS); break;
							case 6:        /* 1280 * 960 */
								vmode = (VERTFLAG2|HORFLAG|PAL|VGA_FALCON|COL80) | (vmode & NUMCOLS); break;
							case 7:        /* 1600 * 1200 */
								vmode = (VERTFLAG2|VESA_600|HORFLAG2|HORFLAG|PAL|VGA_FALCON|COL80) | (vmode & NUMCOLS); break;
							case 8:
								if(vmode_prefered)						
									vmode = (vmode_prefered & ~NUMCOLS) | (vmode & NUMCOLS);
								break;
						}
					}
					else
					{
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
				}		
				break;		
			case MENUBCOUL:
				objc_offset(rs_object,MENUBCOUL,&menu.g_x,&menu.g_y);
				menu.g_w = rs_object[MENUBCOUL].ob_width;
				menu.g_h = rs_object[MENUBCOUL].ob_height;
				ret = (*Xcpb->Popup)(coul,(radeon || acp) ? 6 : 5,vmode & NUMCOLS,IBM,&menu,Work);
				if((ret >= 0) && (ret != (vmode & NUMCOLS)))
				{
					if(radeon || acp)
					{			
						if(!((ret == BPS1) && width_max_mono && height_max_mono) && (ret < BPS8))
						{
							vmode &=~ NUMCOLS;
							vmode |= BPS8;
							ret = BPS8;
						}
						else if((ret == BPS1) && width_max_mono && height_max_mono)
						{
							if((vmode & DEVID) && vmode_prefered)
							{
								if((width_max_mono < width_prefered) || (height_max_mono < height_prefered))
								{
									vmode = PAL|VGA_FALCON|COL80; /* 640 * 480 */
									t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
									t_edinfo->te_ptext=spec_res[1][3];
									display_objc(MENUBRES,Work);
								}
							}
							else
							{
								int mask=VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG;
								i=3;
								if(!(vmode & mask))
								{
									i=0;      /* 320 * 240 */
										if(vmode & COL80)
											i=3;  /* 640 * 480 */
								}
								else if(((vmode & mask) == (VESA_600|HORFLAG2)) && (width_max_mono >= 800) && (height_max_mono >= 600))
									i=4;  /* 800 * 600 */
								else if(((vmode & mask) == (VESA_768|HORFLAG2)) && (width_max_mono >= 1024) && (height_max_mono >= 768))
									i=5;  /* 1024 * 768 */
								else if(((vmode & mask) == (VERTFLAG2|HORFLAG)) && (width_max_mono >= 1280) && (height_max_mono >= 960))
									i=6;  /* 1280 * 960 */
								else if(((vmode & mask) == (VERTFLAG2|VESA_600|HORFLAG2|HORFLAG)) && (width_max_mono >= 1600) && (height_max_mono >= 1200))
									i=7;  /* 1600 * 1200 */
								switch(i)
								{
									case 0:
									case 1:        /* 320 * 240 */
										vmode = VERTFLAG|PAL|VGA_FALCON; break;
									case 2:
									case 3:        /* 640 * 480 */
										vmode = PAL|VGA_FALCON|COL80; break;
									case 4:        /* 800 * 600 */
										vmode = VESA_600|HORFLAG2|PAL|VGA_FALCON|COL80; break;
									case 5:        /* 1024 * 768 */
										vmode = VESA_768|HORFLAG2|PAL|VGA_FALCON|COL80; break;
									case 6:        /* 1280 * 960 */
										vmode = VERTFLAG2|HORFLAG|PAL|VGA_FALCON|COL80; break;
									case 7:        /* 1600 * 1200 */
										vmode = VERTFLAG2|VESA_600|HORFLAG2|HORFLAG|PAL|VGA_FALCON|COL80; break;
								}
								t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
								t_edinfo->te_ptext=spec_res[1][i];
								display_objc(MENUBRES,Work);								
							}
						}
					}
					else
					{
						if(vmode & STMODES)
						{
							switch(ret)
							{
							case 0:				/* 640 x 400 */	
								vmode |= COL80;
								if(vmode & VGA_FALCON)
									vmode &= ~VERTFLAG;
								else
									vmode |= VERTFLAG;
								t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
								t_edinfo->te_ptext=spec_res[(vmode & VGA_FALCON) ? 1 : 0][3];
								display_objc(MENUBRES,Work);
								break;
							case 1:				/* 640 x 200 */
								vmode |= COL80;
								if(vmode & VGA_FALCON)
									vmode |= VERTFLAG;
								else
									vmode &= ~VERTFLAG;
								t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
								t_edinfo->te_ptext=spec_res[(vmode & VGA_FALCON) ? 1 : 0][2];
								display_objc(MENUBRES,Work);
								break;
							case 2:				/* 320 x 200 */
								vmode &= ~COL80;
								if(vmode & VGA_FALCON)
									vmode |= VERTFLAG;
								else
									vmode &= ~VERTFLAG;
								t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
								t_edinfo->te_ptext=spec_res[(vmode & VGA_FALCON) ? 1 : 0][0];
								display_objc(MENUBRES,Work);
								break;
							default:
								vmode &= ~STMODES;
								change_objc(MENUSTMODES,NORMAL,Work);
								break;
							}
						}
						if(!(vmode & COL80) && (ret == BPS1))
							ret++;
						if((vmode & COL80) && (vmode & VGA_FALCON) && (ret == BPS16))
							ret--;
					}
					t_edinfo=rs_object[MENUBCOUL].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_coul[ret];
					display_objc(MENUBCOUL,Work);
					vmode &= ~NUMCOLS;
					vmode |= ret;
				}		
				break;
			case MENUBMLAYOUT:
				objc_offset(rs_object,MENUBMLAYOUT,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBMLAYOUT].ob_width;
				menu.g_h=rs_object[MENUBMLAYOUT].ob_height;
				mlayout=idectpci>>2;
				if((mlayout<0) || (mlayout>5))
					mlayout=0;
				ret=(*Xcpb->Popup)(monitor_layout,6,mlayout,IBM,&menu,Work);
				if(ret>=0 && ret!=mlayout)
				{
					t_edinfo=rs_object[MENUBMLAYOUT].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_monitor_layout[ret];
					display_objc(MENUBMLAYOUT,Work);
					idectpci &= 3;
					idectpci |= (ret << 2);	
				}
				break;
			case MENUSTMODES:
				if(!radeon && !acp && (rs_object[MENUSTMODES].ob_state & SELECTED) && (vmode & NUMCOLS)<BPS8)
				{
					vmode |= STMODES;
					switch(vmode & NUMCOLS)
					{
					case 0:				/* 640 x 400 */	
						i=3;
						vmode |= COL80;
						if(vmode & VGA_FALCON)
							vmode &= ~VERTFLAG;
						else
							vmode |= VERTFLAG;
						break;
					case 1:				/* 640 x 200 */
						i=2;
						vmode |= COL80;
						if(vmode & VGA_FALCON)
							vmode |= VERTFLAG;
						else
							vmode &= ~VERTFLAG;
						break;
					case 2:				/* 320 x 200 */
						i=0;
						vmode &= ~COL80;
						if(vmode & VGA_FALCON)
							vmode |= VERTFLAG;
						else
							vmode &= ~VERTFLAG;
						break;
					}
					t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_res[(vmode & VGA_FALCON) ? 1 : 0][i];
					display_objc(MENUBRES,Work);
				}
				else
				{
					vmode &= ~STMODES;
					if(radeon || acp || (vmode & NUMCOLS)>=BPS8)
						change_objc(MENUSTMODES,NORMAL,Work);
				}
				break;
			case MENUOVERSCAN:
				if(radeon || acp)
				{
					if(rs_object[MENUOVERSCAN].ob_state & SELECTED)
						idectpci |= 2;
					else
						idectpci &= ~2;
				}
				else /* Videl */
				{
					if(rs_object[MENUOVERSCAN].ob_state & SELECTED)
					{
						if(!(vmode & VGA_FALCON))
							vmode |= OVERSCAN;
						else
							change_objc(MENUOVERSCAN,NORMAL,Work); /* no OVERSCAN in VGA */
					}
					else
						vmode &= ~OVERSCAN;
				}
				break;
			case MENUNVM:
				if(rs_object[MENUNVM].ob_state & SELECTED)		
					nv_magic_code='NV';
				else
					nv_magic_code=0;
				break;	
			case MENUBBOOTORDER:
				objc_offset(rs_object,MENUBBOOTORDER,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBBOOTORDER].ob_width;
				menu.g_h=rs_object[MENUBBOOTORDER].ob_height;
				ret=(*Xcpb->Popup)(boot_order[start_lang],8,bootorder,IBM,&menu,Work);
				if((ret >= 0) && (ret != bootorder))
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
				if((ret >= 0) && (ret != bootpref))
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
				if((ret >= 0) && (ret != ((scsi>>7) & 1)))
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
				if((ret >= 0) && (ret != (scsi & 7)))
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
				if(coldfire)
				{
					ret=(*Xcpb->Popup)(serial_speed,16,serialspeed,IBM,&menu,Work);
					if((ret >= 0) && (ret != serialspeed))
					{
						t_edinfo=rs_object[MENUBBLITTER].ob_spec.tedinfo;
						t_edinfo->te_ptext=spec_serial_speed[ret];
						display_objc(MENUBBLITTER,Work);				
						serialspeed=ret;
					}
				}
				else
				{
					ret=(*Xcpb->Popup)(blitter_speed[start_lang],2,blitterspeed,IBM,&menu,Work);
					if((ret >= 0) && (ret != blitterspeed))
					{
						t_edinfo=rs_object[MENUBBLITTER].ob_spec.tedinfo;
						t_edinfo->te_ptext=spec_blitter_speed[start_lang][ret];
						display_objc(MENUBBLITTER,Work);				
						blitterspeed=ret;
					}
				}
				break;
			case MENUBTOSRAM:
				objc_offset(rs_object,MENUBTOSRAM,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBTOSRAM].ob_width;
				menu.g_h=rs_object[MENUBTOSRAM].ob_height;
				if((coldfire || ((long)Supexec(get_version_flash) >= 0x200)) && (radeon || acp))
				{
					ret=(*Xcpb->Popup)(video_log[start_lang],2,(bootlog>>1)&1,IBM,&menu,Work);
					if((ret >= 0) && (ret != ((bootlog>>1) & 1)))
					{
						t_edinfo=rs_object[MENUBTOSRAM].ob_spec.tedinfo;
						t_edinfo->te_ptext=spec_video_log[start_lang][ret];
						display_objc(MENUBTOSRAM,Work);
						bootlog &= ~2;
						bootlog |= (ret << 1);
					}
				}
				else
				{
					ret=(*Xcpb->Popup)(tos_ram[start_lang],2,tosram,IBM,&menu,Work);
					if((ret >= 0) && (ret!=tosram))
					{
						t_edinfo=rs_object[MENUBTOSRAM].ob_spec.tedinfo;
						t_edinfo->te_ptext=spec_tos_ram[start_lang][ret];
						display_objc(MENUBTOSRAM,Work);				
						tosram=ret;
					}
				}
				break;
			case MENUBCACHE:
				objc_offset(rs_object,MENUBCACHE,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBCACHE].ob_width;
				menu.g_h=rs_object[MENUBCACHE].ob_height;
				ret=(*Xcpb->Popup)(cache_delay[start_lang],4,cachedelay,IBM,&menu,Work);
				if((ret >= 0) && (ret != cachedelay))
				{
					t_edinfo=rs_object[MENUBCACHE].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_cache_delay[start_lang][ret];
					display_objc(MENUBCACHE,Work);				
					cachedelay=ret;
				}
				break;
			case MENUBBOOTLOG:
				objc_offset(rs_object,MENUBBOOTLOG,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBBOOTLOG].ob_width;
				menu.g_h=rs_object[MENUBBOOTLOG].ob_height;
				ret=(*Xcpb->Popup)(boot_log[start_lang],2,bootlog&1,IBM,&menu,Work);
				if((ret >= 0) && (ret != (bootlog & 1)))
				{
					t_edinfo=rs_object[MENUBBOOTLOG].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_boot_log[start_lang][ret];
					display_objc(MENUBBOOTLOG,Work);
					bootlog &= ~1;
					bootlog |= ret;
				}
				break;
			case MENUBIDECTPCI:
				objc_offset(rs_object,MENUBIDECTPCI,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBIDECTPCI].ob_width;
				menu.g_h=rs_object[MENUBIDECTPCI].ob_height;
				ret=(*Xcpb->Popup)(coldfire ? ide_cf[start_lang] : ide_ctpci[start_lang],2,idectpci&1,IBM,&menu,Work);
				if(ret>=0 && ret!=(idectpci&1))
				{
					t_edinfo=rs_object[MENUBIDECTPCI].ob_spec.tedinfo;
					if(coldfire)
						t_edinfo->te_ptext=spec_ide_cf[start_lang][ret];
					else
						t_edinfo->te_ptext=spec_ide_ctpci[start_lang][ret];
					display_objc(MENUBIDECTPCI,Work);
					idectpci &= ~1;
					idectpci |= ret;
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
			case MENUBBEEP:
				objc_offset(rs_object,MENUBBEEP,&menu.g_x,&menu.g_y);
				menu.g_w=rs_object[MENUBBEEP].ob_width;
				menu.g_h=rs_object[MENUBBEEP].ob_height;
				ret=(*Xcpb->Popup)(beepp[start_lang],2,beep,IBM,&menu,Work);
				if(ret>=0 && ret!=beep)
				{
					t_edinfo=rs_object[MENUBBEEP].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_beepp[start_lang][ret];
					display_objc(MENUBBEEP,Work);
					beep=ret;
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
				header->serialspeed=(unsigned char)serialspeed;
				header->tosram=(unsigned char)tosram;
				header->cachedelay=(unsigned char)cachedelay;
				header->bootorder=(unsigned char)bootorder;
				header->bootlog=(unsigned char)bootlog;
				header->cpufpu=(unsigned char)cpufpu;
				header->idectpci=(unsigned char)idectpci;
				t_edinfo=rs_object[MENUTRIGGER].ob_spec.tedinfo;
				header->trigger_temp=(unsigned int)atoi(t_edinfo->te_ptext);
				header->daystop=daystop;
				t_edinfo=rs_object[MENUTIME].ob_spec.tedinfo;				
				header->timestop=(((unsigned int)atoi(t_edinfo->te_ptext)/100)<<11)
				                +(((unsigned int)atoi(t_edinfo->te_ptext)%100)<<5);
				header->frequency=frequency;
				header->div_frequency=(unsigned char)div_frequency;
				header->beep=(unsigned char)beep;
				t_edinfo=rs_object[MENUBLANK].ob_spec.tedinfo;	
				header->timeblank=(unsigned int)atoi(t_edinfo->te_ptext);
				if(nclicks<=1)
				{
					save_header();
		 			if(!start_lang)
						ret=form_alert(1,"[2][Voulez vous aussi sauver|le mode vid‚o dans le .INF ?][Sauver|Annuler]");
					else
						ret=form_alert(1,"[2][Do you want also save|video mode inside .INF?][Save|Cancel]");
					if(ret==1)
						modif_inf(vmode); /* modification modecode NEWDESK.INF */
				}
				if(((nclicks>1 && test_060()) || (flag_frequency && !test_060())) && frequency!=0 && !coldfire)
				{
					value=-1;
					if(!coldfire)
						value=ct60_read_clock();
					if(value>0)
					{
						if(step_frequency==DAC_STEP) /* Dallas DS1085 programmable clock */
						{
							if(no_jumper)
							{
								min_freq=(MIN_FREQ_DALLAS+600UL)/2;
								max_freq=MIN_FREQ_DALLAS;
								value>>=1;           /* /2 */
							}
							else
								min_freq=MIN_FREQ_DALLAS+600UL;
						}
 						else
							min_freq=MIN_FREQ;
						if(frequency<min_freq)
							frequency=min_freq;
						init_slider();
						display_objc(MENUBSELECT,Work);
						display_selection(selection,1);
						if(!test_060() && (value<min_freq || value>max_freq))
						{					
		 					if(!start_lang)
								sprintf(mess_alert,"[1][ATTENTION !|La fr‚quence actuelle dans|le g‚n‚rateur d'horloge|est anormale: %ld MHz !][Continuer]",value/1000);
							else
								sprintf(mess_alert,"[1][WARNING!|The actual frequency inside|the clock generator|is abnormal: %ld MHz!][Continue]",value/1000);
							form_alert(1,mess_alert);
						}
						if(value!=frequency && test_060())
						{
							if(!start_lang)
								ret=form_alert(2,"[1][Vous devez essayer|cette fr‚quence avant son|‚criture en EEPROM du|g‚n‚rateur d'horloge !][Essayer|Annuler]");
							else
								ret=form_alert(2,"[1][You must test the|frequency before writing to|the EEPROM of the|clock generator!][Try|Cancel]");
							if(ret==1)
							{
								change_objc(MENUBSAVE,NORMAL,Work);
								goto _ok_;
							}
						}
						else if(test_060()
						 && ((frequency>MAX_FREQ_REV1_BOOT && version_060()<6)
						  || (frequency>MAX_FREQ_REV6_BOOT && version_060()>=6)))
						{
							if(!start_lang)
								form_alert(1,"[1][Impossible d'‚crire cette|fr‚quence dans la EEPROM du|g‚n‚rateur d'horloge !|Le CPU peut ne pas red‚marrer][Annuler]");
							else
								form_alert(1,"[1][Impossible to write this|frequency to the EEPROM of|the clock generator!|The CPU can fail when restart][Cancel]");
						}						
						else
						{
					 		if(!start_lang)
								ret=form_alert(2,"[2][Sauver l'horloge|dans le g‚n‚rateur ?|ATTENTION ! L'ordinateur va d‚marrer|avec la nouvelle fr‚quence lors de la|prochaine mise sous tension !][Sauver|Annuler]");
							else
								ret=form_alert(2,"[2][Save the clock|inside the generator?|WARNING! The computer will start|with this new frequency|during the next power-on!][Save|Cancel]");
							if(ret==1)
							{
								value=ct60_configure_clock(frequency,CT60_CLOCK_WRITE_EEPROM,div_frequency);
								if(value<0)
								{
									if(value==CT60_CALC_CLOCK_ERROR)
									{
										if(!start_lang)
											form_alert(1,"[1][Erreur de calcul|du g‚n‚rateur d'horloge !][Annuler]");
										else
											form_alert(1,"[1][Calcul error for|the clock generator!][Cancel]");
									}
									else
									{
										if(!start_lang)
											form_alert(1,"[1][Erreur ‚criture|dans la EEPROM du|g‚n‚rateur d'horloge !][Annuler]");
										else
											form_alert(1,"[1][Error writing to|the EEPROM of the|clock generator!][Cancel]");
									}
								}
								else
									flag_frequency=0;
							}
						}				
					}
					else if(!test_060())
					{
						if(value==CT60_NULL_CLOCK_ERROR)
						{
							if(!start_lang)
								form_alert(1,"[1][Tous les paramŠtres du|g‚n‚rateur d'horloge sont nuls !| |V‚rifier la liaison MODEM2][Annuler]");
							else
								form_alert(1,"[1][All parameters of the clock|generator are null!| |Please check the MODEM2 link][Cancel]");
						}
						else
						{
							if(!start_lang)
								form_alert(1,"[1][Pour programmer le|g‚n‚rateur d'horloge|sans la CT60, vous|devez connecter le|module sur MODEM2 !][OK]");
							else
								form_alert(1,"[1][For program the clock|generator without the|CT60, you must connect|the module on MODEM2!][OK]");
						}
					}
				}
				change_objc(MENUBSAVE,NORMAL,Work);
				break;
 			case MENUBLOAD:
		 		if(!start_lang)
					ret=form_alert(1,"[2][Charger les|r‚glages sauv‚s ?][Charger|Annuler]");
				else
					ret=form_alert(1,"[2][Load saved|parameters?][Load|Cancel]");
				if(ret==1)
				{
					if(test_060())
						selection=PAGE_TEMP;
					else				/* read temperature not works in normal mode */
						selection=PAGE_MEMORY;
					t_edinfo=rs_object[MENUBSELECT].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_select[start_lang][selection];
					language=0;
					while(language<7 && header->language!=code_lang[language])
					language++;
					if(language>=7)
						language=0;	
					keyboard=0;
					while(keyboard<9 && header->keyboard!=code_key[keyboard])
						keyboard++;
					if(keyboard>=9)
						keyboard=0;
					datetime=(int)header->datetime;
					vmode=(int)header->vmode;
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
					if(radeon || acp)
					{
						t_edinfo=rs_object[MENUBVIDEO].ob_spec.tedinfo;
						t_edinfo->te_ptext=spec_video[1];
						t_edinfo=rs_object[MENUBMODE].ob_spec.tedinfo;
						t_edinfo->te_ptext=spec_mode[1];
					}
					else
					{
						t_edinfo=rs_object[MENUBVIDEO].ob_spec.tedinfo;
						t_edinfo->te_ptext=spec_video[((vmode & VGA_FALCON)>>4) & 1];
						t_edinfo=rs_object[MENUBMODE].ob_spec.tedinfo;
						t_edinfo->te_ptext=spec_mode[((vmode & PAL)>>5) & 1];
					}
					t_edinfo=rs_object[MENUBCOUL].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_coul[vmode & NUMCOLS];
					if(radeon || acp)
					{
						if((vmode & DEVID) && vmode_prefered)
						{
							if((vmode & NUMCOLS) == BPS1) /* VBL monochrome emulation */
							{
								if((width_max_mono >= width_prefered) && (height_max_mono >= width_prefered))
									i=8; /* prefered mode */
								else
									i=3;			
							}
							else
								i=8; /* prefered mode */
						}
						else
						{
							vmode &= (VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG|VERTFLAG|VGA_FALCON|COL80|NUMCOLS);
							vmode &= ~(VIRTUAL_SCREEN|OVERSCAN);
							vmode |= (PAL|VGA_FALCON);
							if(!(((vmode & NUMCOLS) == BPS1) && width_max_mono && height_max_mono)						
							 && (((vmode & NUMCOLS) < BPS8) || ((vmode & NUMCOLS) > BPS32)))
							{
								vmode &=(PAL|VGA_FALCON|COL80);
								vmode |= BPS8;
							}
							if(vmode & COL80)
								vmode &= ~VERTFLAG;
							else
								vmode |= VERTFLAG;
							i=3;
							ret=VERTFLAG2|VESA_768|VESA_600|HORFLAG2|HORFLAG;
							if(!(vmode & ret))
							{
								i=0;      /* 320 * 240 */
								if(vmode & COL80)
									i=3;  /* 640 * 480 */
							}
							else
							{	
								if((vmode & ret) == (VESA_600|HORFLAG2))
									i=4;  /* 800 * 600 */
								else if ((vmode & ret) == (VESA_768|HORFLAG2)) 
									i=5;  /* 1024 * 768 */
								else if ((vmode & ret) == (VERTFLAG2|HORFLAG)) 
									i=6;  /* 1280 * 960 */
								else if ((vmode & ret) == (VERTFLAG2|VESA_600|HORFLAG2|HORFLAG)) 
									i=7;  /* 1600 * 1200 */
							}
						}
						if(idectpci & 2)
							rs_object[MENUOVERSCAN].ob_state |= SELECTED;
						else
							rs_object[MENUOVERSCAN].ob_state &= ~SELECTED;	
						rs_object[MENUSTMODES].ob_state &= ~SELECTED;
					}
					else /* Videl */
					{
						i=0;
						if(vmode & COL80)
							i+=2;
						if(!(vmode & VERTFLAG) && (vmode & VGA_FALCON))
							i++;
						if((vmode & VERTFLAG) && !(vmode & VGA_FALCON))
							i++;
						if((vmode & OVERSCAN) && !(vmode & VGA_FALCON))
							rs_object[MENUOVERSCAN].ob_state |= SELECTED;
						else
							rs_object[MENUOVERSCAN].ob_state &= ~SELECTED;		
						if((vmode & STMODES) && (vmode & NUMCOLS)<BPS8)
						{
							rs_object[MENUSTMODES].ob_state |= SELECTED;
							switch(vmode & NUMCOLS)
							{
							case 0:				/* 640 x 400 */	
								i=3;
								vmode |= COL80;
								if(vmode & VGA_FALCON)
									vmode &= ~VERTFLAG;
								else
									vmode |= VERTFLAG;
								break;
							case 1:				/* 640 x 200 */
								i=2;
								vmode |= COL80;
								if(vmode & VGA_FALCON)
									vmode |= VERTFLAG;
								else
									vmode &= ~VERTFLAG;
								break;
							case 2:				/* 320 x 200 */
								i=0;
								vmode &= ~COL80;
								if(vmode & VGA_FALCON)
									vmode |= VERTFLAG;
								else
									vmode &= ~VERTFLAG;
								break;
							}
						}
						else
						{
							rs_object[MENUSTMODES].ob_state &= ~SELECTED;		
							if((vmode & NUMCOLS)>=3)
								vmode &= ~STMODES;	
						}
					}
					t_edinfo=rs_object[MENUBRES].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_res[(vmode & VGA_FALCON) ? 1 : 0][i];
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
					blitterspeed=(int)header->blitterspeed&1;
					serialspeed=(int)header->serialspeed&15;
					t_edinfo=rs_object[MENUBBLITTER].ob_spec.tedinfo;
					if(coldfire)
						t_edinfo->te_ptext=spec_serial_speed[serialspeed];
					else
						t_edinfo->te_ptext=spec_blitter_speed[start_lang][blitterspeed];
					bootlog=(int)header->bootlog;		
					tosram=(int)header->tosram;
					t_edinfo=rs_object[MENUBTOSRAM].ob_spec.tedinfo;
					if((coldfire || ((long)Supexec(get_version_flash) >= 0x200)) && (radeon || acp))
						t_edinfo->te_ptext=spec_video_log[start_lang][(bootlog>>1)&1];
					else
						t_edinfo->te_ptext=spec_tos_ram[start_lang][tosram];
					cachedelay=(int)header->cachedelay;
					t_edinfo=rs_object[MENUBCACHE].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_cache_delay[start_lang][cachedelay];
					bootorder=(int)header->bootorder;					
					t_edinfo=rs_object[MENUBBOOTORDER].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_boot_order[start_lang][bootorder];
					t_edinfo=rs_object[MENUBBOOTLOG].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_boot_log[start_lang][bootlog&1];
					idectpci=(int)header->idectpci;					
					t_edinfo=rs_object[MENUBIDECTPCI].ob_spec.tedinfo;
					if(coldfire)
						t_edinfo->te_ptext=spec_ide_cf[start_lang][idectpci&1];					
					else
						t_edinfo->te_ptext=spec_ide_ctpci[start_lang][idectpci&1];
					cpufpu=(int)header->cpufpu;
					t_edinfo=rs_object[MENUBFPU].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_fpu[start_lang][cpufpu];
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
					timeblank=header->timeblank;
					if(timeblank>99)
						timeblank=99;
					t_edinfo=rs_object[MENUBLANK].ob_spec.tedinfo;
					sprintf(t_edinfo->te_ptext,"%d",timeblank);
					frequency=header->frequency;
					if(frequency<min_freq || frequency>max_freq)
						frequency=min_freq;
					if(test_060() && (coldfire || ct60_read_clock()<0))
						frequency=0;
					div_frequency=(int)header->div_frequency;
					if(div_frequency<2)
						div_frequency=2;
					if(div_frequency>6)
						div_frequency=6;
					t_edinfo=rs_object[MENUBDIV].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_div_freq[div_frequency-2];
					init_slider();
					beep=(int)header->beep&1;
					t_edinfo=rs_object[MENUBBEEP].ob_spec.tedinfo;
					t_edinfo->te_ptext=spec_beepp[start_lang][beep];
					display_objc(MENUBSELECT,Work);
					display_selection(selection,1);
				}
				change_objc(MENUBLOAD,NORMAL,Work);
				break;
			case MENUBOK:
_ok_:
				nvram.language=code_lang[language];
				nvram.keyboard=code_key[keyboard];
				nvram.datetime=(unsigned char)datetime;
				t_edinfo=rs_object[MENUSEP].ob_spec.tedinfo;
				nvram.separator=t_edinfo->te_ptext[0];
				if(!radeon && !acp)
					nvram.vmode=(unsigned int)vmode;
				nvram.bootpref=(unsigned int)code_os[bootpref];
				nvram.scsi=(unsigned char)scsi;
				t_edinfo=rs_object[MENUDELAY].ob_spec.tedinfo;
				nvram.bootdelay=(unsigned char)atoi(t_edinfo->te_ptext);
				NVMaccess(1,0,(int)(sizeof(NVM)),&nvram);		/* write */
				{
					char buf[4];
					int i;
					unsigned long val;
					mac_address=ip_address=server_ip_address=0;
					buf[3]='\0';
					t_edinfo=rs_object[MENUMAC].ob_spec.tedinfo;
					for(i=0;i<3;i++)
					{
						val=(unsigned long)read_hexa(&t_edinfo->te_ptext[i<<1]);
						if(val>255)
							val=255;
						mac_address|=(val<<((2-i)<<3));
					}
					t_edinfo=rs_object[MENUIP].ob_spec.tedinfo;
					for(i=0;i<4;i++)
					{
						memcpy(buf,&t_edinfo->te_ptext[i*3],3);
						val=(unsigned long)val_string(buf);
						if(val>255)
							val=255;
						ip_address|=(val<<((3-i)<<3));
					}
					t_edinfo=rs_object[MENUSERVERIP].ob_spec.tedinfo;
					for(i=0;i<4;i++)
					{
						memcpy(buf,&t_edinfo->te_ptext[i*3],3);
						val=(unsigned long)val_string(buf);
						if(val>255)
							val=255;
						server_ip_address|=(val<<((3-i)<<3));
					}
				}
				if(flag_xbios)
				{
					tosram=(int)ct60_rw_parameter(CT60_MODE_WRITE,CT60_PARAM_TOSRAM,(long)tosram);
					blitterspeed=(int)ct60_rw_parameter(CT60_MODE_WRITE,CT60_BLITTER_SPEED,(long)blitterspeed);
					serialspeed=(int)ct60_rw_parameter(CT60_MODE_WRITE,CT60_SERIAL_SPEED,(long)serialspeed);
					cachedelay=(int)ct60_rw_parameter(CT60_MODE_WRITE,CT60_CACHE_DELAY,(long)cachedelay);
					bootorder=(int)ct60_rw_parameter(CT60_MODE_WRITE,CT60_BOOT_ORDER,(long)bootorder);
					bootlog=(int)ct60_rw_parameter(CT60_MODE_WRITE,CT60_BOOT_LOG,(long)bootlog);
					cpufpu=(int)ct60_rw_parameter(CT60_MODE_WRITE,CT60_CPU_FPU,(long)cpufpu);
					if(coldfire)
					{
						ct60_rw_parameter(CT60_MODE_WRITE,CT60_MAC_ADDRESS,(long)mac_address);
						ct60_rw_parameter(CT60_MODE_WRITE,CT60_IP_ADDRESS,(long)ip_address);
						ct60_rw_parameter(CT60_MODE_WRITE,CT60_SERVER_IP_ADDRESS,(long)server_ip_address);					
					}
					else
					{
						ct60_rw_parameter(CT60_MODE_WRITE,CT60_CLOCK,(long)frequency);
						ct60_rw_parameter(CT60_MODE_WRITE,CT60_USER_DIV_CLOCK,(long)div_frequency);
					}
					ct60_rw_parameter(CT60_MODE_WRITE,CT60_SAVE_NVRAM_1,
					 (long)((((unsigned long)nv_magic_code)<<16)+(unsigned long)nvram.bootpref));
					ct60_rw_parameter(CT60_MODE_WRITE,CT60_SAVE_NVRAM_2,
					 (long)((((unsigned long)nvram.language)<<24)
					 + (((unsigned long)nvram.keyboard)<<16) 
					 + (((unsigned long)nvram.datetime)<<8)
					 + (unsigned long)nvram.separator));
					ct60_rw_parameter(CT60_MODE_WRITE,CT60_SAVE_NVRAM_3,
					 (long)((((unsigned long)nvram.bootdelay)<<24)
					 + (((unsigned long)nvram.vmode)<<8)
					 + (unsigned long)nvram.scsi));
					if(radeon || acp)
						ct60_rw_parameter(CT60_MODE_WRITE,CT60_VMODE,(long)vmode);
					ct60_rw_parameter(CT60_MODE_WRITE,CT60_PARAM_CTPCI,(long)idectpci);
				}
				else
				{
					stack=Super(0L);
					tosram=(int)ct60_rw_param(CT60_MODE_WRITE,CT60_PARAM_TOSRAM,(long)tosram);
					blitterspeed=(int)ct60_rw_param(CT60_MODE_WRITE,CT60_BLITTER_SPEED,(long)blitterspeed);
					serialspeed=(int)ct60_rw_param(CT60_MODE_WRITE,CT60_SERIAL_SPEED,(long)serialspeed);
					cachedelay=(int)ct60_rw_param(CT60_MODE_WRITE,CT60_CACHE_DELAY,(long)cachedelay);
					bootorder=(int)ct60_rw_param(CT60_MODE_WRITE,CT60_BOOT_ORDER,(long)bootorder);
					bootlog=(int)ct60_rw_param(CT60_MODE_WRITE,CT60_BOOT_LOG,(long)bootlog);
					cpufpu=(int)ct60_rw_param(CT60_MODE_WRITE,CT60_CPU_FPU,(long)cpufpu);
					if(coldfire)
					{
						ct60_rw_param(CT60_MODE_WRITE,CT60_MAC_ADDRESS,(long)mac_address);
						ct60_rw_param(CT60_MODE_WRITE,CT60_IP_ADDRESS,(long)ip_address);
						ct60_rw_param(CT60_MODE_WRITE,CT60_SERVER_IP_ADDRESS,(long)server_ip_address);					
					}
					else
					{
						ct60_rw_param(CT60_MODE_WRITE,CT60_CLOCK,(long)frequency);
						ct60_rw_param(CT60_MODE_WRITE,CT60_USER_DIV_CLOCK,(long)div_frequency);
					}
					ct60_rw_param(CT60_MODE_WRITE,CT60_SAVE_NVRAM_1,
					 (long)((((unsigned long)nv_magic_code)<<16)+(unsigned long)nvram.bootpref));
					ct60_rw_param(CT60_MODE_WRITE,CT60_SAVE_NVRAM_2,
					 (long)((((unsigned long)nvram.language)<<24)
					 + (((unsigned long)nvram.keyboard)<<16) 
					 + (((unsigned long)nvram.datetime)<<8)
					 + (unsigned long)nvram.separator));
					ct60_rw_param(CT60_MODE_WRITE,CT60_SAVE_NVRAM_3,
					 (long)((((unsigned long)nvram.bootdelay)<<24)
					 + (((unsigned long)nvram.vmode)<<8)
					 + (unsigned long)nvram.scsi));
					if(radeon || acp)
						ct60_rw_param(CT60_MODE_WRITE,CT60_VMODE,(long)vmode);
					ct60_rw_param(CT60_MODE_WRITE,CT60_PARAM_CTPCI,(long)idectpci);
					Super((void *)stack);
				}
				if(tosram<0 || blitterspeed<0 || cachedelay<0 || bootorder<0 || bootlog<0 || cpufpu<0)
				{
					if(tosram==-15 || blitterspeed==-15 || cachedelay==-15
					 || bootorder==-15 || bootlog==-15 || cpufpu==-15)   /* error device */
					{
						if(!start_lang)
							form_alert(1,"[1][Type de flash|inconnu !][Annuler]");
						else
							form_alert(1,"[1][Unknow flash|device!][Cancel]");
					}
					else
					{
						if(!start_lang)
							form_alert(1,"[1][Erreur ‚criture|paramŠtre en flash !][Annuler]");
						else
							form_alert(1,"[1][Error writing|parameters to flash!][Cancel]");
					}
				}
				if(test_060() && frequency!=0)
				{
					value=-1;
					if(!coldfire)
						value=ct60_read_clock();
					if(value>0)
					{
						if(value!=frequency)
						{
							value=ct60_configure_clock(frequency,CT60_CLOCK_WRITE_RAM,div_frequency);
							if(value<0)
							{
								if(value==CT60_CALC_CLOCK_ERROR)
								{
									if(!start_lang)
										form_alert(1,"[1][Erreur calcul|g‚n‚rateur d'horloge !][Annuler]");
									else
										form_alert(1,"[1][Error calcul|clock generator!][Cancel]");
								}
								else
								{
									if(!start_lang)
										form_alert(1,"[1][Erreur ‚criture|vers le g‚n‚rateur|d'horloge !][Annuler]");
									else
										form_alert(1,"[1][Error writing to|clock generator!][Cancel]");

								}
							}
						}
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
				if(!coldfire && ((info_tree=adr_tree(TREE2))!=0))
				{
					if(test_060())
					{
						info_tree[INFOSDRAM].ob_flags |= (SELECTABLE|EXIT);
						info_tree[INFOSDRAM].ob_state &= ~DISABLED;
					}
					else
					{
						info_tree[INFOSDRAM].ob_flags &= ~(SELECTABLE|EXIT);
						info_tree[INFOSDRAM].ob_state |= DISABLED;
					}
					switch(hndl_form(info_tree,0))
					{
					case INFOSDRAM :
						infos_sdram();
						break;
					case INFOHELP:
						call_st_guide();
						break;
					}
				}
				else if(coldfire)
					form_alert(1,"[0][FireTOS configuration  V" VERSION "  | |      Didier MEQUIGNON|      aniplay@wanadoo.fr][ OK ]");
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
	TEDINFO *t_edinfo;
	BITBLK *b_itblk;
	char **rs_str;
	register int h;
	long value;
	if(rs_object[MENUBINFO].ob_height==1)
	/* flag SkipRshFix is bugged with XCONTROL and ZCONTROL when it's used in cpx_init */
	{
#ifdef DEBUG
		printf("Init RSC\r\n");
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
			rs_object[MENUSTRAMTOT-1].ob_y-=(h+1);
			rs_object[MENUSTRAMTOT].ob_y-=(h+1);
			rs_object[MENUFASTRAMTOT-1].ob_y-=(h+2);
			rs_object[MENUFASTRAMTOT].ob_y-=(h+2);			
			rs_object[MENUSTRAM-1].ob_y-=(h+3);
			rs_object[MENUSTRAM].ob_y-=(h+3);
			rs_object[MENUFASTRAM-1].ob_y-=(h+4);
			rs_object[MENUFASTRAM].ob_y-=(h+4);				
			rs_object[MENUMIPS].ob_y-=(h+5);
			rs_object[MENUBFPU-1].ob_y-=(h+3);
			rs_object[MENUBFPU].ob_y-=(h+3);
			rs_object[MENUBLEFT].ob_x--;
			rs_object[MENUBLEFT].ob_y-=(h+2);
			rs_object[MENUBOXSLIDER].ob_y-=(h+2);
			rs_object[MENUBRIGHT].ob_x++;
			rs_object[MENUBRIGHT].ob_y-=(h+2);
			rs_object[MENUBDIV].ob_y-=(h+3);
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
			rs_object[MENUBCOUL-1].ob_y+=h;
			rs_object[MENUBCOUL].ob_y+=h;
			rs_object[MENUBMLAYOUT].ob_y+=h;
			rs_object[MENUSTMODES].ob_y+=h;
			rs_object[MENUBOXBOOT].ob_y+=(h+1);
			rs_object[MENUBOXBOOT].ob_height+=h;
			rs_object[MENUBBOOTORDER].ob_y-=h;
			rs_object[MENUBOS-1].ob_y-=h;
			rs_object[MENUBOS].ob_y-=h;
			rs_object[MENUBARBIT-1].ob_y-=(h-3);
			rs_object[MENUBARBIT].ob_y-=(h-3);
			rs_object[MENUBIDSCSI-1].ob_y-=(h-3);
			rs_object[MENUBIDSCSI].ob_y-=(h-3);
			rs_object[MENUDELAY].ob_y-=(h-6);
			if(coldfire)
			{
				t_edinfo=rs_object[MENUTITLE].ob_spec.tedinfo;
				t_edinfo->te_ptext="FireTOS Configuration";
				rs_object[MENUBBLITTER-1].ob_spec.free_string="  Debug:";
			}
			rs_object[MENUBBLITTER-1].ob_y-=(h-6);
			rs_object[MENUBBLITTER].ob_y-=(h-6);
			rs_object[MENUBTOSRAM-1].ob_y+=(h-7);
			rs_object[MENUBTOSRAM].ob_y+=(h-7);
			if((coldfire || ((long)Supexec(get_version_flash) >= 0x200)) && !radeon && !acp)
			{
				rs_object[MENUBTOSRAM-1].ob_flags |= HIDETREE;
				rs_object[MENUBTOSRAM].ob_flags |= HIDETREE;
			}
			rs_object[MENUBCACHE-1].ob_y+=(h-7);
			rs_object[MENUBCACHE].ob_y+=(h-7);
			rs_object[MENUBBOOTLOG-1].ob_y+=(h-4);
			rs_object[MENUBBOOTLOG].ob_y+=(h-4);
			rs_object[MENUBIDECTPCI-1].ob_y+=(h-4);
			rs_object[MENUBIDECTPCI].ob_y+=(h-4);
			if((get_cookie('_PCI') != NULL) || coldfire)
			{
				rs_object[MENUBIDECTPCI-1].ob_flags &= ~HIDETREE;
				rs_object[MENUBIDECTPCI].ob_flags &= ~HIDETREE;
			}
			else
			{
				rs_object[MENUBIDECTPCI-1].ob_flags |= HIDETREE;	
				rs_object[MENUBIDECTPCI].ob_flags |= HIDETREE;
			}		
			rs_object[MENUBOXSTOP].ob_y+=(h+1);
			rs_object[MENUBOXSTOP].ob_height+=h;
			rs_object[MENUBDAY-1].ob_y-=h;
			rs_object[MENUBDAY].ob_y-=h;
			rs_object[MENUTIME].ob_y-=(h-3);
			rs_object[MENUBBEEP-1].ob_y-=(h-3);
			rs_object[MENUBBEEP].ob_y-=(h-3);
			if(coldfire)
				rs_object[MENUBLANK].ob_y-=(h*2);
			else
				rs_object[MENUBLANK].ob_y+=2;
			rs_object[MENUMAC].ob_y+=2;
			rs_object[MENUIP].ob_y+=2;
			rs_object[MENUSERVERIP].ob_y+=2;
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

void init_slider(void)
{
	TEDINFO *t_edinfo;
	if(frequency)
	{
		rs_object[MENUBLEFT].ob_flags &= ~HIDETREE;	
		rs_object[MENUBOXSLIDER].ob_flags &= ~HIDETREE;
		rs_object[MENUSLIDER].ob_flags &= ~HIDETREE;
		rs_object[MENUBRIGHT].ob_flags &= ~HIDETREE;
		rs_object[MENUSLIDER].ob_x = (int)
		 (((frequency-min_freq) * (unsigned long)(rs_object[MENUBOXSLIDER].ob_width - rs_object[MENUSLIDER].ob_width))/(max_freq-min_freq));
		t_edinfo=rs_object[MENUSLIDER].ob_spec.tedinfo;
		sprintf(t_edinfo->te_ptext,"%ld.%03ld",frequency/1000,frequency%1000);
		rs_object[MENUBDIV].ob_flags &= ~HIDETREE;
	}
	else
	{
		rs_object[MENUBLEFT].ob_flags |= HIDETREE;	
		rs_object[MENUBOXSLIDER].ob_flags |= HIDETREE;
		rs_object[MENUSLIDER].ob_flags |= HIDETREE;
		rs_object[MENUBRIGHT].ob_flags |= HIDETREE;
		rs_object[MENUBDIV].ob_flags |= HIDETREE;
	}
}

void display_slider(GRECT *work)
{
	init_slider();
	display_objc(MENUBOXSLIDER,work);
}

int modif_inf(int modecode)
{
	static char path_desk[]="C:\\newdesk.inf";
	static char path_magic[]="C:\\magx.inf";
	static char path_inf[16];
	static char chaine[8];
	void *sauve_ssp,*buffer;
	char *p;
	register int handle,i;
	register long err,size;
	int ok,old_modecode,magic,lg=0;
	ok=0;
	graf_mouse(HOURGLASS,(MFORM*)0);
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
					if(magic)
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
								if(Vsetmode(-1)==0x88)	/* ST monochrome */
									modecode=(old_modecode & ~(HORFLAG2|VERTFLAG|OVERSCAN))
							         | (modecode & (HORFLAG2|VERTFLAG|OVERSCAN));
								if(modecode!=old_modecode)
								{
									long_deci(p,&lg);	/* modecode */
									p+=lg;
									if((err=Fwrite(handle,3," 5 "))>=0)
									{
										sprintf(chaine,"%d",modecode);
										if((err=Fwrite(handle,long_deci(chaine,&lg),chaine))>=0)
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
								if(Vsetmode(-1)==0x88)	/* ST monochrome */
									modecode=(old_modecode & ~(HORFLAG2|VERTFLAG|OVERSCAN))
									        | (modecode & (HORFLAG2|VERTFLAG|OVERSCAN));
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

void display_error(int err)
{
	if(err<0)
	{
		switch(err)
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

void infos_sdram(void)
{
	static char mess_alert[26*61];
	static unsigned char buffer[128];
	static char buf[256];
	char *save_title_alert;
	OBJECT *alert_tree;
	TEDINFO *t_edinfo;
	int i;
	long stack;
	if(!test_060() || coldfire)
		return;
	stack=Super(0L);
#ifdef DEBUG
	for(i=0;i<128;i++)
	{
		if(read_i2c(((long)i)<<16)>=0)
			printf("Found I2C device %02x\r\n",i); 		
	}
#endif
	i=ct60_read_info_sdram(buffer);
	Super((void *)stack);
	if(i<0)
	{
 		if(!start_lang)
			form_alert(1,"[1][Il n'est pas possible|de lire les informations|de la SDRAM][Annuler]");
		else
			form_alert(1,"[1][Cannot read the|informations about|the SDRAM][Cancel]");
		return;	
	}
	if(start_lang)
		strcpy(mess_alert,"[0][Memory Type : ");
	else
		strcpy(mess_alert,"[0][Type de m‚moire : ");
	sprintf(buf,"%d",buffer[2]);
	strcat(mess_alert,buf);
	if(buffer[2]==4)
		strcat(mess_alert," SDRAM");
	if(start_lang)
		strcat(mess_alert,"|Number of Row Addresses : ");
	else
		strcat(mess_alert,"|Nombre de lignes d'adresses : ");
	sprintf(buf,"%d",buffer[3]);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Number of Column Addresses : ");
	else
		strcat(mess_alert,"|Nombre de colonnes d'adresses : ");
	sprintf(buf,"%d",buffer[4]);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Number of DIMM Banks : ");
	else
		strcat(mess_alert,"|Nombre de banques DIMM : ");
	sprintf(buf,"%d",buffer[5]);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Module Data Width : ");
	else
		strcat(mess_alert,"|Largeur donn‚es module : ");
	sprintf(buf,"%d bits",(unsigned int)buffer[6]+(((unsigned int)buffer[7])<<8));
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Voltage Interface Level : ");
	else
		strcat(mess_alert,"|Niveau de tension interface : ");
	sprintf(buf,"%d",buffer[8]);
	strcat(mess_alert,buf);
	if(buffer[8]==1)
		strcat(mess_alert," LVTTL");
	if(start_lang)
		strcat(mess_alert,"|SDRAM Cycle Time : ");
	else
		strcat(mess_alert,"|SDRAM Temps cycle : ");
	sprintf(buf,"%d.%d nS ",buffer[9]>>4,buffer[9]&0xf);
	strcat(mess_alert,buf);
	if(buffer[9]>=0xA0)
		strcat(mess_alert,"PC100");
	else
		strcat(mess_alert,"PC133");
	if(start_lang)
		strcat(mess_alert,"|SDRAM Access from Clock : ");
	else
		strcat(mess_alert,"|SDRAM AccŠs de l'horloge : ");
	sprintf(buf,"%d.%d nS",buffer[10]>>4,buffer[10]&0xf);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|SDRAM Configuration Type : ");
	else
		strcat(mess_alert,"|SDRAM Type : ");
	sprintf(buf,"%d ",buffer[11]);
	strcat(mess_alert,buf);
	switch(buffer[11])
	{
	case 0:
		if(start_lang)
			strcat(mess_alert,"no parity");
		else
			strcat(mess_alert,"pas de parit‚");
		break;
	case 1:
		if(start_lang)
			strcat(mess_alert,"parity");
		else
			strcat(mess_alert,"parit‚");
		break;
	case 2:
		strcat(mess_alert,"ECC");
		break;
	}
	if(start_lang)
		strcat(mess_alert,"|Refresh Rate : ");
	else
		strcat(mess_alert,"|Fr‚quence rafraichissement : ");
	switch(buffer[12]&0x7f)
	{
	case 0: strcat(mess_alert,"15.625 uS"); break;
	case 1: strcat(mess_alert,"3.9 uS"); break;
	case 2: strcat(mess_alert,"7.8 uS"); break;
	case 3: strcat(mess_alert,"31.3 uS"); break;
	case 4: strcat(mess_alert,"62.5 uS"); break;
	case 5: strcat(mess_alert,"125 uS"); break;
	}
	if(buffer[12]&0x80)
		strcat(mess_alert,", self refresh");
	if(start_lang)
		strcat(mess_alert,"|Number of Banks : ");
	else
		strcat(mess_alert,"|Nombre de banques : ");
	sprintf(buf,"%d ",buffer[17]);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|CAS Latency : ");
	else
		strcat(mess_alert,"|CAS Latence : ");
	add_latency(mess_alert,buffer[18]<<1);
	if(start_lang)
		strcat(mess_alert,"|CS Latency : ");
	else
		strcat(mess_alert,"|CS Latence : ");
	add_latency(mess_alert,buffer[19]);
	if(start_lang)
		strcat(mess_alert,"|WE Latency : ");
	else
		strcat(mess_alert,"|WE Latence : ");
	add_latency(mess_alert,buffer[20]);
	if(start_lang)
		strcat(mess_alert,"|SDRAM Module Attributes : $");
	else
		strcat(mess_alert,"|Attributs du module : $");
	sprintf(buf,"%02x ",buffer[21]);
	strcat(mess_alert,buf);
	if(buffer[21]==0)
	{
		if(start_lang)
			strcat(mess_alert," unbuffered");
		else
			strcat(mess_alert," sans buffers");	
	}
	if(start_lang)
		strcat(mess_alert,"|Minimum Row Precharge Time : ");
	else
		strcat(mess_alert,"|Temps de pr‚chage mini lignes : ");
	sprintf(buf,"%d nS",buffer[27]);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Minimum Row Active to Active Delay : ");
	else
		strcat(mess_alert,"|D‚lais mini entre activations lignes : ");
	sprintf(buf,"%d nS",buffer[28]);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Minimum RAS to CAS Delay : ");
	else
		strcat(mess_alert,"|D‚lais mini entre RAS et CAS : ");
	sprintf(buf,"%d nS",buffer[29]);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Minimum RAS Pulse Width : ");
	else
		strcat(mess_alert,"|Largeur mini impulsion RAS : ");
	sprintf(buf,"%d nS",buffer[30]);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Module Bank Density : ");
	else
		strcat(mess_alert,"|Densit‚ banque du module : ");
	if(start_lang)
		sprintf(buf,"%d MB",((unsigned int)buffer[31])<<2);
	else
		sprintf(buf,"%d Mo",((unsigned int)buffer[31])<<2);
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Module Manufacturers ID : $");
	else
		strcat(mess_alert,"|ID fabriquant du module : $");
	sprintf(buf,"%02x ",buffer[64]);
	strcat(mess_alert,buf);
	switch(buffer[64])
	{
	case 0x1C: strcat(mess_alert,"MITSUBISHI"); break;
	case 0x25: strcat(mess_alert,"KINGMAX"); break;		/* 0x7F7F7F bytes 65-67 */
	case 0x2C: strcat(mess_alert,"MICRON"); break;
	case 0x4A: strcat(mess_alert,"COMPAQ"); break;
	case 0x54: strcat(mess_alert,"HP"); break;
	case 0x98: strcat(mess_alert,"KINGSTON"); break;	/* 0x7F byte 65 */
	case 0x9E: strcat(mess_alert,"CORSAIR"); break;		/* 0x7F7F bytes 65-66 */
	case 0xA4: strcat(mess_alert,"IBM"); break;
	case 0xE0: /* ??? */
	case 0xAD: strcat(mess_alert,"HYUNDAI"); break;
	case 0xC1: strcat(mess_alert,"INFINEON"); break;
	case 0xCE: strcat(mess_alert,"SAMSUNG"); break;
	case 0xDA: strcat(mess_alert,"DANE-ELEC"); break;
	default:
		for(i=0;i<7;i++)
		{
			if(buffer[65+i]<' ' || buffer[65+i]>=127)
				break;
			buf[i]=buffer[65+i];
		}
		buf[i]=0;
		strcat(mess_alert,buf);
		break;
	}
	if(start_lang)
		strcat(mess_alert,"|Module Part Number : ");
	else
		strcat(mess_alert,"|R‚f‚rence du module : ");
	for(i=0;i<18;i++)
		buf[i]=buffer[73+i];
	buf[i]=0;
	strcat(mess_alert,buf);
	if(start_lang)
		strcat(mess_alert,"|Module Manufacturing Date : ");
	else
		strcat(mess_alert,"|Date de fabrication du module : ");
	if(buffer[93]!=0xFF || buffer[94]!=0xFF)
	{
		if(buffer[94]>0x52)	/* IBM format */
			sprintf(buf,"%d/%d",buffer[93],((unsigned int)buffer[94]+1900));
		else
		{					/* JEDEC format */
			if(buffer[93]>=0x90)
				sprintf(buf,"%x/19%02x",buffer[94],buffer[93]);
			else
				sprintf(buf,"%x/20%02x",buffer[94],buffer[93]);
		}
		strcat(mess_alert,buf);
	}
	strcat(mess_alert,"][OK]");
	if((alert_tree=adr_tree(TREE3))==0)
		return;
	t_edinfo=alert_tree[ALERTTITLE].ob_spec.tedinfo;
	if(start_lang)
		strcpy(buf,"SDRAM EEPROM DATA");
	else
		strcpy(buf,"SDRAM DONNEES EEPROM");
	save_title_alert=t_edinfo->te_ptext;
	t_edinfo->te_ptext=buf;
	MT_form_xalert(1,mess_alert,0L,0L,0L);
	t_edinfo->te_ptext=save_title_alert;
}

void add_latency(char *buffer_ascii,unsigned char val)
{
	int i,first;
	char buf[]={"/0"};
	first=1;
	i=6;
	while(i>0)
	{
		if(val&1)
		{
			if(first)
			{
				strcat(buffer_ascii,&buf[1]);
				first=0;
			}
			else
				strcat(buffer_ascii,buf);
		}
		val>>=1;
		buf[1]++;
		i--;
	}
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
		else										/* temperature */            
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
	 && header->blitterspeed==0 && header->serialspeed==0 && header->cachedelay==0
	 && header->bootorder==0 && header->bootlog==0 && header->cpufpu==0 && header->beep==0)
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
		rs_object[MENUBLANK].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags |= HIDETREE;
		rs_object[MENUIP].ob_flags &= ~EDITABLE;
		rs_object[MENUIP].ob_flags |= HIDETREE;
		rs_object[MENUSERVERIP].ob_flags &= ~EDITABLE;
		rs_object[MENUSERVERIP].ob_flags |= HIDETREE;
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
		rs_object[MENUBLANK].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags |= HIDETREE;
		rs_object[MENUIP].ob_flags &= ~EDITABLE;
		rs_object[MENUIP].ob_flags |= HIDETREE;
		rs_object[MENUSERVERIP].ob_flags &= ~EDITABLE;
		rs_object[MENUSERVERIP].ob_flags |= HIDETREE;
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
		rs_object[MENUBLANK].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags |= HIDETREE;
		rs_object[MENUIP].ob_flags &= ~EDITABLE;
		rs_object[MENUIP].ob_flags |= HIDETREE;
		rs_object[MENUSERVERIP].ob_flags &= ~EDITABLE;
		rs_object[MENUSERVERIP].ob_flags |= HIDETREE;
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
		rs_object[MENUBLANK].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags |= HIDETREE;
		rs_object[MENUIP].ob_flags &= ~EDITABLE;
		rs_object[MENUIP].ob_flags |= HIDETREE;
		rs_object[MENUSERVERIP].ob_flags &= ~EDITABLE;
		rs_object[MENUSERVERIP].ob_flags |= HIDETREE;
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
	case PAGE_STOP:				/* stop/misc */
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
		if(radeon || acp)
		{
			rs_object[MENUBLANK].ob_flags &= ~HIDETREE;
			rs_object[MENUBLANK].ob_flags |= EDITABLE;
		}
		else
		{
			rs_object[MENUBLANK].ob_flags |= HIDETREE;
			rs_object[MENUBLANK].ob_flags &= ~EDITABLE;
		}
		if(coldfire)
		{
			rs_object[MENUBDAY-1].ob_flags |= HIDETREE;
			rs_object[MENUBDAY].ob_flags |= HIDETREE;
			rs_object[MENUTIME].ob_flags |= HIDETREE;
			rs_object[MENUTIME].ob_flags &= ~EDITABLE;
			rs_object[MENUBBEEP-1].ob_flags |= HIDETREE;
			rs_object[MENUBBEEP].ob_flags |= HIDETREE;
			rs_object[MENUMAC].ob_flags |= EDITABLE;
			rs_object[MENUMAC].ob_flags &= ~HIDETREE;
			rs_object[MENUIP].ob_flags |= EDITABLE;
			rs_object[MENUIP].ob_flags &= ~HIDETREE;
			rs_object[MENUSERVERIP].ob_flags |= EDITABLE;
			rs_object[MENUSERVERIP].ob_flags &= ~HIDETREE;
		}
		else
		{
			rs_object[MENUBDAY-1].ob_flags &= ~HIDETREE;
			rs_object[MENUBDAY].ob_flags &= ~HIDETREE;
			rs_object[MENUTIME].ob_flags &= ~HIDETREE;
			rs_object[MENUTIME].ob_flags |= EDITABLE;
			rs_object[MENUBBEEP-1].ob_flags &= ~HIDETREE;
			rs_object[MENUBBEEP].ob_flags &= ~HIDETREE;
			rs_object[MENUMAC].ob_flags &= ~EDITABLE;
			rs_object[MENUMAC].ob_flags |= HIDETREE;
			rs_object[MENUIP].ob_flags &= ~EDITABLE;
			rs_object[MENUIP].ob_flags |= HIDETREE;
			rs_object[MENUSERVERIP].ob_flags &= ~EDITABLE;
			rs_object[MENUSERVERIP].ob_flags |= HIDETREE;
		}
		if(flag_aff)
		{
			display_objc(MENUBOXSTOP,Work);
			display_objc(MENUSTOP,Work);
			if(coldfire)
			{
				if(radeon || acp)
					ed_objc=MENUBLANK;
				else
					ed_objc=MENUMAC;			
			}
			else
				ed_objc=MENUTIME;
			objc_edit(rs_object,ed_objc,0,&ed_pos,ED_INIT);
			new_objc=ed_objc;
			new_pos=ed_pos;
		}
		break;		
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
		rs_object[MENUBLANK].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags |= HIDETREE;
		rs_object[MENUIP].ob_flags &= ~EDITABLE;
		rs_object[MENUIP].ob_flags |= HIDETREE;
		rs_object[MENUSERVERIP].ob_flags &= ~EDITABLE;
		rs_object[MENUSERVERIP].ob_flags |= HIDETREE;
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
		rs_object[MENUBLANK].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags &= ~EDITABLE;
		rs_object[MENUMAC].ob_flags |= HIDETREE;
		rs_object[MENUIP].ob_flags &= ~EDITABLE;
		rs_object[MENUIP].ob_flags |= HIDETREE;
		rs_object[MENUSERVERIP].ob_flags &= ~EDITABLE;
		rs_object[MENUSERVERIP].ob_flags |= HIDETREE;
		if(flag_aff)
		{
			display_objc(MENUBOXVIDEO,Work);
			display_objc(MENUVIDEO,Work);
			new_objc=ed_objc=new_pos=ed_pos=0;
		}
		break;
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
	char line[25][61];
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
	for(i=0;i<25;alert_tree[ALERTLINE1+i].ob_spec.free_string=&line[i][0],line[i++][0]=0);
	for(i=0;i<3;alert_tree[ALERTB1+i].ob_spec.free_string=&button[i][0],button[i++][0]=0);
	fo_xastring+=4;
	p=fo_xastring;				/* search the size of the box */
	max_length_buttons=nb_lines=nb_buttons=0;
	t_edinfo=alert_tree[ALERTTITLE].ob_spec.tedinfo;
	max_length_lines=t_edinfo->te_txtlen-1;
	for(i=0;*p!=']' && i<25;i++)
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
	for(i=0;i<25;i++)						/* copy texts of lines */
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
					if(time_out && nb_buttons==0) /* no buttons and clic inside the box */
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

void bubble_help(void)
{
	register int i,j,ok;
	int bubble_id,objc;
    EVNTDATA mouse;
	static int old_objc=-1;
	static WORD msg[8];
	if(ap_id>=0 && !flag_bubble && buffer_bubble && time_out_bubble<0)
	{
		if((bubble_id=appl_find("BUBBLE  "))>=0)
		{
			graf_mkstate(&mouse);
			if((wi_id==-1 || wi_id==wind_find(mouse.x,mouse.y)))
			{
				ok=0;
				if(bubblegem_right_click)
				{
					if((mouse.bstate & 2)!=0						/* right button */
					 && (objc=objc_find(rs_object,0,2,mouse.x,mouse.y))>=0)
						ok=1;
				}
				else
				{
					if((objc=objc_find(rs_object,0,2,mouse.x,mouse.y))>=0)
					{
						if(old_objc!=objc)
							old_objc=objc;
						else
							ok=1;
					}
				}
				if(ok)
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
	 && ((st_guide_id=appl_find("ST-GUIDE"))>=0
	  || (st_guide_id=appl_find("HYP_VIEW"))>=0))
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
	unsigned int time,trigger_temp,daystop,timestop,beep,timeblank,timeoutblank=0;
	int temp_id,event,ret,count=0,count_mn=0,loops=1,stop,blank=0;
	unsigned long ticks,start_ticks,new_ticks,sum_ticks=0;
	long uptime,load,old_load=0,load_avg=0,load_avg_mn=0,delay=ITIME,avenrun[3]={0,0,0};
	char buffer[2];
	static char load_ikbd[4] = {0x20,0x01,0x20,8};
	char message_lcd[10];
	static unsigned int old_time=9999;
	static int error_flag=0,old_stop=0;
	static WORD message[8],msg[8];
	static char mess_alert[256];
	GRECT rect={0,0,0,0};
	OBJECT *alarm_tree;
	EVNTDATA mouse,old_mouse;
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
	beep=param[3];
	timeblank=param[4];
	MT_graf_mkstate(&old_mouse,myglobal);
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
		if(eiffel_media_keys!=NULL)
		{
			if(*eiffel_media_keys==0x73)						/* POWER */
			{
				*eiffel_media_keys=0;
				stop=1;
			}
			else
				stop=test_stop(daytime,daystop,timestop);
		}
		else
			stop=test_stop(daytime,daystop,timestop);
		if(stop && !old_stop)
		{
			beep_psg(beep);
			if(!start_lang)
				ret=MT_form_xalert(1,"[2][ATTENTION !|Arrˆt programm‚ de votre|ordinateur dans 30 secondes ?][OK|Annuler]",ITIME*30L,0L,myglobal);
			else
				ret=MT_form_xalert(1,"[2][WARNING!|Stop programmed for your|computer in 30 seconds?][OK|Cancel]",ITIME*30L,0L,myglobal);
			if(ret==1)
			{
				for(i=0;i<10;beep_psg(beep),evnt_timer(ITIME),i++);
				if(!start_lang)
					MT_form_xalert(1,"[1][Arrˆt de votre ordinateur...][]",ITIME*5L,stop_060,myglobal);
				else
					MT_form_xalert(1,"[1][Stopping your computer...][]",ITIME*5L,stop_060,myglobal);
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
			beep_psg(beep);
			if(!start_lang)
				sprintf(mess_alert,"[3][ATTENTION !|Votre 060 est trop chaud: %d øC|La destruction est … %d øC|Arrˆt du microprocesseur dans 10 S|aprŠs ce message !][OK]",temp,MAX_TEMP);
			else
				sprintf(mess_alert,"[3][WARNING!|Your 68060 is too hot: %d øC|Destruction begins at %d øC|Your system will be stopped|10 secs after this message!][OK]",temp,MAX_TEMP);
			MT_form_xalert(1,mess_alert,ITIME*5L,0L,myglobal);
			for(i=0;i<10;beep_psg(beep),evnt_timer(ITIME),i++);
			if(!start_lang)
				sprintf(mess_alert,"[3][ATTENTION !|Votre 060 est trop chaud: %d øC|La destruction est … %d øC| |SystŠme Arrˆt‚ ! ][]",temp,MAX_TEMP);
			else
				sprintf(mess_alert,"[3][WARNING!|Your 68060 is too hot: %d øC|Destruction begins at %d øC| |System halted!][]",temp,MAX_TEMP);
			MT_form_xalert(1,mess_alert,ITIME*2L,stop_060,myglobal);
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
			else							/* Suptime() not supported */
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
				delay=ITIME/(CLOCKS_PER_SEC>>2);
				loops=CLOCKS_PER_SEC>>2;
			}
			for(i=0;i<60;i++)
				tab_temp[i]=tab_temp[i+1];
			tab_temp[60]=temp;
			if(tab_temp[60]>MAX_TEMP)
				tab_temp[60]=MAX_TEMP;
			if(eiffel_temp!=NULL)
			{
				SendIkbd(3,load_ikbd);
				sprintf(message_lcd," 60 %02d\337C",temp);
				SendIkbd(7,message_lcd);
				buffer[0]=3;				/* get temp */
				SendIkbd(0,buffer);
				for(i=61;i<121;i++)
					tab_temp[i]=tab_temp[i+1];
				tab_temp[121]=((unsigned short)(eiffel_temp[0]&0x3F))
				 | (((unsigned short)(eiffel_temp[2]&1))<<15);
			}
			old_time=time;
			if(temp > trigger_temp && temp <= MAX_TEMP)
			{
				beep_psg(beep);
			 	if(!start_lang)
					sprintf(mess_alert,"[3][ATTENTION !|Votre 060 est trop chaud: %d øC|La destruction est … %d øC|Arrˆtez votre ordinateur !][OK]",temp,MAX_TEMP);
				else
					sprintf(mess_alert,"[3][WARNING!|Your 68060 is too hot: %d øC|Destruction begins at %d øC|Shut down your computer NOW!][OK]",temp,MAX_TEMP);
				MT_form_xalert(1,mess_alert,ITIME*10L,0L,myglobal);
			}
		}
		if(loops>1)							/* Suptime() not supported */
			ticks=clock();
		for(i=0;i<loops;i++)
		{
			event=MT_evnt_multi(MU_MESAG|MU_TIMER,0,0,0,0,&rect,0,&rect,message,delay,&mouse,&ret,&ret,myglobal);
			if(event & MU_TIMER)
			{
				if(loops>1) 								/*  Suptime() not supported */
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
				if(radeon || acp)
				{
					MT_graf_mkstate(&mouse,myglobal);
					if((mouse.x!=old_mouse.x) || (mouse.y!=old_mouse.y) || (mouse.bstate!=old_mouse.bstate))
					{
						if(blank)
							Vsetscreen(-1,0,'VN',CMD_BLANK);
						blank=0;
						timeoutblank=0;
					}
					old_mouse=mouse;					
					if(!blank && timeblank)
					{
						if(timeoutblank >= (timeblank*60))
						{
							Vsetscreen(-1,1,'VN',CMD_BLANK);
							blank=1;				
						}
						if(!i)
							timeoutblank++;
					}
				}
			}
			if((event & MU_MESAG)
			 && ((unsigned int)message[0]==MSG_CT60_TEMP))
			{
				trigger_temp=(unsigned int)message[3];
				daystop=(unsigned int)message[4];
				timestop=(unsigned int)message[5];
				beep=(unsigned int)message[6];
				timeblank=(unsigned int)message[7];
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

int start_temp(unsigned int *param1,unsigned int *param2,unsigned int *param3,unsigned int *param4,unsigned int *param5)
{
	register int ret,err,i,j;
	static unsigned int param[5];
	THREADINFO thi;
	static char path_app[256],path_acc[256];
	static char name[9];
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
#ifdef DEBUG
			printf("Send params to temperature ACC/APP\r\n");
#endif
			if(start_ct60temp(param1,param2,param3,param4,param5))
				return(appl_find("CT60TEMP"));
		}
    }
	if(appl_find("FREEDOM2")<0 && magic >=0x405
	 && magic_date >= 0x19960401L && temp_id<0)
	{						/* threads exists since MagiC 4.5 */ 
#ifdef DEBUG
		printf("Start temperature thread\r\n");
#endif
		param[0]=*param1;
		param[1]=*param2;
		param[2]=*param3;
		param[3]=*param4;
		param[5]=*param5;
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
#ifdef DEBUG
			printf("Search temperature ACC/APP\r\n");
#endif
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
			ret=form_alert(1,"[2][Il faut installer|CT60TEMP pour surveiller|la temp‚rature][Installer|Annuler]");
		else
			ret=form_alert(1,"[2][You must install|CT60TEMP to monitor|the temperature][Install|Cancel]");
		if(ret==1)
#endif
		{
			graf_mouse(BUSYBEE,(MFORM*)0);
			ret=Fcreate(path_app,0);
			if(ret<0)
			{
				graf_mouse(ARROW,(MFORM*)0);
				if(!start_lang)
					ret=form_alert(1,"[1][Erreur durant la|cr‚ation du fichier|CT60TEMP.ACC][Annuler]");
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
						ret=form_alert(1,"[1][Erreur durant|l'‚criture du|fichier CT60TEMP.ACC][Annuler]");
					else
						ret=form_alert(1,"[1][Error occurred while|writing CT60TEMP.ACC][Cancel]");	
				}
				else
				{
					if(mint || magic)
					{
#ifdef DEBUG
						printf("Send params to temperature ACC/APP\r\n");
#endif
						if(start_ct60temp(param1,param2,param3,param4,param5))
							return(appl_find("CT60TEMP"));
					}
					else if(!coldfire)
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

int start_ct60temp(unsigned int *param1,unsigned int *param2,unsigned int *param3,unsigned int *param4,unsigned int *param5)
{
	register int ret=0;
	char path_app[256],cmd_line[256];
	strcpy(path_app,"CT60TEMP.APP");
	if(shel_find(path_app))
	{
#ifdef DEBUG
		printf("params: %d %d %d %d %d\r\n",*param1,*param2,*param3,*param4,*param5);
#endif
		sprintf(&cmd_line[1],"%d %d %d %d %d",*param1,*param2,*param3,*param4,*param5);
		ret=strlen(&cmd_line[1]);
		cmd_line[0]=(char)ret;
		if(magic)
			ret=shel_write(1,1,SHW_PARALLEL,path_app,cmd_line);
		else
			ret=shel_write(0,1,SHW_CHAIN,path_app,cmd_line);
#ifdef DEBUG
		printf("CT60TEMP.APP started\r\n");
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
	msg[6]=(int)beep;
	msg[7]=(int)timeblank;
	msg[2]=0;
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

void beep_psg(unsigned int beep)
{
	static unsigned char tab_beep[] = {
	0,0xA0,1,0,2,0,3,0,4,0,5,0,6,0,7,0xFE,8,13,9,0,10,0,0xFF,10,
	0,0,1,0,2,0,3,0,4,0,5,0,6,0,7,0xFF,8,0,9,0,10,0,0xFF,0 };
	if(beep)
		Dosound(tab_beep);
}

void SendIkbd(int count, char *buffer)
{
	while(count>=0)
	{
		/* IKBD interrupt buffered by a TSR program inside the AUTO folder */
		Bconout(4,*buffer++);
		count--;
	}
}

void stop_060(void)
{
	COOKIE *p;
	Sync();
	Shutdown(0L);
	if(((p = get_cookie('_CPU')) != NULL) && (p->v.l == 60L))
	{
		if(coldfire)
			Supexec(cf_stop);
		else
			Supexec(ct60_stop);	
	}
	while(1);
}

long version_060(void)
{
	if(!test_060())
		return(6);
#ifndef TEST
	if(coldfire)
		return(6);
	return(Supexec(ct60_cpu_revision));	
#else
	return(1);
#endif
}

int read_temp(void)
{
	register int temp,temperature,i;
	static int old_temp[8]={0,0,0,0,0,0,0,0};
	static int ct63=0;
	if(ct63)
		return(0);
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
	else if(temp==0)
		ct63=1;
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
	unsigned long loops_per_sec=1;
	unsigned long ticks;
	while((loops_per_sec<<=1))
	{
		if(get_cookie('MgMc') == NULL)
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

long cdecl enumfunc(SCREENINFO *inf, long flag)
{
	if(flag);
	if(!vmode_prefered && !width_prefered && !height_prefered
	 && (inf->devID & DEVID) && !(inf->devID & VIRTUAL_SCREEN)
	 && (strchr(inf->name,'*') != NULL)) /* symbol used for prefered mode */
	{
		vmode_prefered = (int)inf->devID;
		width_prefered = (int)inf->scrWidth;
		height_prefered = (int)inf->scrHeight;
	}
	if((inf->devID & NUMCOLS) == BPS1) /* VBL monochome emulation */
	{
		if((int)inf->scrWidth > width_max_mono)
			width_max_mono = (int)inf->scrWidth;
		if((int)inf->scrHeight > height_max_mono)
			height_max_mono = (int)inf->scrHeight;
	}
	return(1);
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
	if((get_cookie('_PCI') == NULL) || !test_060())
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

int test_060(void)
{
#ifndef TEST
	COOKIE *p;
	if(cpu_cookie==0)
	{
		if((p = get_cookie('_CPU')) != NULL)
			cpu_cookie = p->v.l;
	}
	return((cpu_cookie == 60) ? 1 : 0);
#else
	return(1);
#endif
}

CT60_COOKIE *get_cookie_ct60(void)
{
	COOKIE *p;
	if((p = get_cookie(ID_CT60)) != NULL)
		return((CT60_COOKIE *)p->v.l);
	if((p = get_cookie(ID_CF)) != NULL)
		return((CT60_COOKIE *)p->v.l);
	return(NULL);
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
