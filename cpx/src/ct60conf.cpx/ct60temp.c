	
/* CT60 TEMPerature - Pure C */
/* Didier MEQUIGNON - v2.00 - June 2010 */

#include <portab.h>
#include <tos.h>
#include <mt_aes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "ct60.h"

#define ID_CF (long)'_CF_'

#define ITIME 1000L	/* mS */
#define MAX_CPULOAD 10000
#define MAX_TEMP 90

#define KER_GETINFO 0x0100

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
#define Sync() gemdos(0x150)
#define Shutdown(mode) gemdos(0x151,(long)(mode))

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

/* prototypes */

void var_name_app(char *env,char *app_name);
int start_app(char *path_app,char *cmd,WORD *global);
void call_app(char *var_env,char *cmd,WORD *global);
void rsc_calc(OBJECT *tree);
OBJECT* adr_tree(int num_tree);
int MT_form_xalert(int fo_xadefbttn,char *fo_xastring,long time_out,void (*call)(),WORD *global);
void (*function)(void);
int test_stop(unsigned long daytime,unsigned int daystop,unsigned int timestop);
int dayofweek(int year,int mon,int mday);
void beep_psg(unsigned int beep);
void SendIkbd(int count, char *buffer);
void stop_60(void);
int read_temp(void);
COOKIE *fcookie(void);
COOKIE *ncookie(COOKIE *p);
COOKIE *get_cookie(long id);
extern long ct60_read_temp(void);
extern long ct60_stop(void);
extern long cf_stop(void);

/* global variables */

int start_lang,flag_xbios,mint,magic,gr_hwchar,gr_hhchar,gr_hwbox,gr_hhbox;
WORD myglobal[15];

/* ressource */

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

BITBLK rs_bitblk[] = {
	(int *)0L,4,32,0,0,1,
	(int *)1L,4,32,0,0,4,
	(int *)2L,4,32,0,0,2 };
	
TEDINFO rs_tedinfo[] = {
	(char *)0L,(char *)1L,(char *)2L,IBM,0,2,0x1480,0,-1,17,1 };

OBJECT rs_object[] = {
	-1,1,12,G_BOX,FL3DBAK,OUTLINED,0x21100L,0,0,42,10,
	2,-1,-1,G_BOXTEXT,FL3DBAK,NORMAL,0L,0,0,42,1,
	3,-1,-1,G_IMAGE,NONE,NORMAL,1L,1,2,4,2,
	4,-1,-1,G_IMAGE,NONE,NORMAL,2L,1,2,4,2,
	5,-1,-1,G_IMAGE,NONE,NORMAL,3L,1,2,4,2,
	6,-1,-1,G_STRING,NONE,NORMAL,3L,1,2,40,1,
	7,-1,-1,G_STRING,NONE,NORMAL,4L,1,3,40,1,
	8,-1,-1,G_STRING,NONE,NORMAL,5L,1,4,40,1,
	9,-1,-1,G_STRING,NONE,NORMAL,6L,1,5,40,1,
	10,-1,-1,G_STRING,NONE,NORMAL,7L,1,6,40,1,
	11,-1,-1,G_BUTTON,SELECTABLE|DEFAULT|EXIT|FL3DIND|FL3DBAK,NORMAL,8L,1,8,10,1,
	12,-1,-1,G_BUTTON,SELECTABLE|EXIT|FL3DIND|FL3DBAK,NORMAL,9L,12,8,10,1,
	0,-1,-1,G_BUTTON,SELECTABLE|EXIT|LASTOB|FL3DIND|FL3DBAK,NORMAL,10L,23,8,10,1 };

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

#define NUM_OBS 12		/* number of objects */
#define NUM_TREE 1		/* number of trees */ 

#define TREE1 0

#define USA 0
#define FRG 1
#define FRA 2
#define UK 3
#define SPA 4
#define ITA 5
#define SWF 7
#define SWG 8

int main(int argc,const char *argv[])

{
	register int i,temp;
	unsigned long daytime;
	unsigned int time,trigger_temp,daystop,timestop,beep;
	int temp_id,app_id=-1,app_sid,app_stype,flag_cpuload,event,ret,end=0,count=0,count_mn=0,loops=1,stop,cpu_060,flag_msg=0;
	unsigned long ticks,run_ticks,start_ticks,new_ticks,sum_ticks=0;
	long uptime,load,old_load=0,load_avg=0,load_avg_mn=0,delay=ITIME,avenrun[3]={0,0,0};
	char *eiffel_temp;
	short *eiffel_media_keys;
	char buffer[2];
	static char load_ikbd[4] = {0x20,0x01,0x20,8};
	char message_lcd[10];
	CT60_COOKIE *ct60_arg=NULL;
	static unsigned int old_time=9999;
	static int error_flag=0,old_stop=0;
	static WORD message[8],msg[8];
	unsigned short *tab_temp,*tab_cpuload;
	char mess_alert[256];
	char app_name[9];
	GRECT rect={0,0,0,0};
	EVNTDATA mouse;
	OBJECT *alert_tree;
	TEDINFO *t_edinfo;
	BITBLK *b_itblk;
	COOKIE cookie_temp;
	COOKIE *p;
	MX_KERNEL *mx_kernel;
	trigger_temp=daystop=timestop=0;
	beep=1;
	if(_app)
	{
		if(argc>1)
			trigger_temp=(unsigned int)atoi(argv[1]);
		if(argc>2)
			daystop=(unsigned int)atoi(argv[2]);
		if(argc>3)
			timestop=(unsigned int)atoi(argv[3]);
		if(argc>4)
			beep=(unsigned int)atoi(argv[4])&1;
	}
	else
	{
		if((p=get_cookie(ID_CT60))==0)
			p=get_cookie(ID_CF);
		if(p!=0)
		{
			ct60_arg=(CT60_COOKIE *)p->v.l;
			if(ct60_arg!=NULL)
			{
					trigger_temp=(unsigned int)ct60_arg->trigger_temp;
					daystop=(unsigned int)ct60_arg->daystop;
					timestop=(unsigned int)ct60_arg->timestop;
					beep=(unsigned int)ct60_arg->beep;
			}
		}
	}
	if(trigger_temp==0)
		trigger_temp=(MAX_TEMP*3)/4;
	mint=magic=0;
	if(get_cookie('MiNT'))
		mint=1;
	if(get_cookie('MagX'))
		magic=1;
	if(mint || (magic && (mx_kernel=(MX_KERNEL *)Dcntl(KER_GETINFO,NULL,0L))!=0
	  && *mx_kernel->pe_slice>=0))	/* preemptive */
		flag_cpuload=1;
	else
		flag_cpuload=0;
	start_lang=1;
	if((p=get_cookie('_AKP'))!=0)
	{
		if((p->v.c[2]==FRA) || (p->v.c[2]==SWF))
			start_lang=0;
	}
	eiffel_media_keys=NULL;
	if((p=get_cookie('Eiff'))!=0)
		eiffel_media_keys=(short *)p->v.l;
	eiffel_temp=NULL;
	if((p=get_cookie('Temp'))!=0)
		eiffel_temp=(char *)p->v.l;
	tab_temp=tab_cpuload=NULL;
	if((temp_id=MT_appl_init(myglobal))<=0)
		return(-1);		
	MT_graf_handle(&gr_hwchar,&gr_hhchar,&gr_hwbox,&gr_hhbox,myglobal);
	rsc_calc(rs_object);
	if((alert_tree=adr_tree(TREE1))!=0)
	{
		t_edinfo=rs_object[ALERTTITLE].ob_spec.tedinfo=&rs_tedinfo[0];
		if(!start_lang)
			t_edinfo->te_ptext="CT60 Temp‚rature";
		else
			t_edinfo->te_ptext="CT60 Temperature";		
		t_edinfo->te_ptmplt=t_edinfo->te_pvalid="";	
		b_itblk=alert_tree[ALERTNOTE].ob_spec.bitblk=&rs_bitblk[0];
		b_itblk->bi_pdata=(int *)pic_note;
		b_itblk=alert_tree[ALERTWAIT].ob_spec.bitblk=&rs_bitblk[1];
		b_itblk->bi_pdata=(int *)pic_wait;
		b_itblk=alert_tree[ALERTSTOP].ob_spec.bitblk=&rs_bitblk[2];
		b_itblk->bi_pdata=(int *)pic_stop;
	}
	flag_xbios=1;
	if(((p=get_cookie('_MCH'))==0) || (p->v.l!=0x30000))	/* Falcon */
	{
		if(!start_lang)
			MT_form_alert(1,"[1][Cette machine n'est|pas un FALCON 030][Annuler]",myglobal);
		else
			MT_form_alert(1,"[1][This computer isn't|a FALCON 030][Cancel]",myglobal);
		MT_appl_exit(myglobal);
		return(0);
	}
	if(!get_cookie(ID_CT60) && !get_cookie(ID_CF))
		flag_xbios=0;
	cpu_060=0;
	if(((p=get_cookie('_CPU'))!=0) && (p->v.l==0x3C))
		cpu_060=1;
	if(_app && !flag_xbios && !cpu_060)
	{
		MT_appl_exit(myglobal);
		return(0);
	}
	if(myglobal[0]<0x399)	/* version AES */
	{
		if(!_app)			/* ACC */
		{
			tab_temp=(unsigned short *)Mxalloc(sizeof(unsigned short)*122L,3);
			tab_cpuload=(unsigned short *)Mxalloc(sizeof(unsigned short)*61L,3);
		}
		else
			return(-1);		/* Application */
	}
	else
	{
		tab_temp=(unsigned short *)Mxalloc(sizeof(unsigned short)*122L,0x23);	/* global */
		tab_cpuload=(unsigned short *)Mxalloc(sizeof(unsigned short)*61L,0x23);
	}
	if(tab_temp==NULL || tab_cpuload==NULL)
	{
		MT_appl_exit(myglobal);				
		return(-1);
	}
	MT_menu_register(temp_id,"  CT60 Temperature",myglobal);
	if(!_app && !cpu_060)
	{
		while(1)
		{
			event=MT_evnt_multi(MU_MESAG,0,0,0,0,&rect,0,&rect,message,delay,&mouse,&ret,&ret,myglobal);
			if((event & MU_MESAG) && message[0]==AC_OPEN)
			{
				if(!start_lang)
					MT_form_alert(1,"[1][Pas de CT60 !][Annuler]",myglobal);
				else
					MT_form_alert(1,"[1][CT60 not found!][Cancel]",myglobal);
			}
		}
	}
	for(i=0;i<61;i++)
		tab_temp[i]=tab_temp[i+61]=tab_cpuload[i]=0;
	ticks=start_ticks=run_ticks=clock();
	while(!end)
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
			switch(*eiffel_media_keys)
			{
				case 0x73:										/* POWER */
					*eiffel_media_keys=0;
					stop=1;
					break;
				case 0x3A:										/* WWW HOME */
					*eiffel_media_keys=0;
					call_app("BROWSER",NULL,myglobal);
					break;
				case 0x48:										/* E-MAIL */
					*eiffel_media_keys=0;
					call_app("MAILER",NULL,myglobal);
					break;
				case 0x10:										/* WWW SEARCH */
					*eiffel_media_keys=0;
					call_app("BROWSER","http://www.google.com",myglobal);
					break;
				case 0x40:										/* MY COMPUTER */
					*eiffel_media_keys=0;
					call_app("HELPVIEWER","*:\\CT60.HYP",myglobal);
					break;
				default: stop=test_stop(daytime,daystop,timestop); break;
			}
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
				if(myglobal[0]>=0x399)									/* version AES */
					MT_shel_write(SHW_SHUTDOWN,1,0,"","",myglobal);		/* send AP_TERM to all applications */
				for(i=0;i<10;beep_psg(beep),evnt_timer(ITIME),i++);
				if(!start_lang)
					MT_form_xalert(1,"[1][ATTENTION !|Arrˆt de votre ordinateur...][]",ITIME*5L,stop_60,myglobal);
				else
					MT_form_xalert(1,"[1][WARNING!|Stopping your computer...][]",ITIME*5L,stop_60,myglobal);
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
		if(temp>(MAX_TEMP-5) && ticks-run_ticks>=(5000UL/CLOCKS_PER_SEC))
		{
			beep_psg(beep);
			if(!start_lang)
				sprintf(mess_alert,"[3][ATTENTION !|Votre 060 est trop chaud: %d øC|La destruction est … %d øC|Arrˆt du microprocesseur dans 10 S|aprŠs ce message !][OK]",temp,MAX_TEMP);
			else
				sprintf(mess_alert,"[3][WARNING!|Your 68060 is too hot: %d øC|Destruction begins at %d øC|Your system will be stopped|10 secs after this message!][OK]",temp,MAX_TEMP);
			MT_form_xalert(1,mess_alert,ITIME*5L,0L,myglobal);
			if(myglobal[0]>=0x399)									/* version AES */
				MT_shel_write(SHW_SHUTDOWN,1,0,"","",myglobal);		/* send AP_TERM to all applications */
			if(_app)
				end=1;
			for(i=0;i<10;beep_psg(beep),evnt_timer(ITIME),i++);
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
			tab_cpuload[60]=MAX_CPULOAD/2;
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
			else						/* Suptime() not supported */
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
				buffer[0]=3;			/* get temp */
				SendIkbd(0,buffer);
				for(i=61;i<121;i++)
					tab_temp[i]=tab_temp[i+1];
				tab_temp[121]=((unsigned short)(eiffel_temp[0]&0x3F))
				 | (((unsigned short)(eiffel_temp[2]&1))<<15);
			}
			old_time=time;
			if(trigger_temp && temp > trigger_temp && temp <= MAX_TEMP
			  && ticks-run_ticks>=(5000UL/CLOCKS_PER_SEC))
			{
				beep_psg(beep);
			 	if(!start_lang)
					sprintf(mess_alert,"[3][ATTENTION !|Votre 060 est trop chaud: %d øC|La destruction est … %d øC|Arrˆtez votre ordinateur !][OK]",temp,MAX_TEMP);
				else
					sprintf(mess_alert,"[3][WARNING!|Your 68060 is too hot: %d øC|Destruction begins at %d øC|Shut down your computer NOW!][OK]",temp,MAX_TEMP);
				MT_form_xalert(1,mess_alert,ITIME*10L,0L,myglobal);
			}
		}
		if(loops>1)						/* Suptime() not supported */
			ticks=clock();
		for(i=0;i<loops;i++)
		{
			event=MT_evnt_multi(MU_MESAG|MU_TIMER,0,0,0,0,&rect,0,&rect,message,delay,&mouse,&ret,&ret,myglobal);
			if(event & MU_TIMER)
			{
				if(!flag_msg && !_app && ct60_arg!=NULL)
				{
					trigger_temp=(unsigned int)ct60_arg->trigger_temp;
					daystop=(unsigned int)ct60_arg->daystop;
					timestop=(unsigned int)ct60_arg->timestop;
				}
			}			
			if(loops>1)					/* Suptime() not supported */
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
			if(event & MU_MESAG)
			{
				switch((unsigned int)message[0])
				{
					case AC_OPEN:
						app_name[0]=0;
						if(app_id>=0 && myglobal[0]>=0x399)								/* version AES */
						{
							i=MT_appl_search(0,app_name,&app_stype,&app_sid,myglobal);	/* 1st app */
							while(i && app_sid!=app_id)
								i=MT_appl_search(1,app_name,&app_stype,&app_sid,myglobal);	/* next app */
							if(i==0 || app_sid!=app_id)
								app_name[0]=0;
						}
					 	if(!start_lang)
							sprintf(mess_alert,
							"[0][      CT60 TEMPERATURE       |V2.00 MEQUIGNON Didier 06/2010| |Temp.: %d øC     Seuil: %d øC |Lien avec processus %d %s][OK]",
							temp,trigger_temp,app_id,app_name);
						else
							sprintf(mess_alert,
							"[0][      CT60 TEMPERATURE       |V2.00 MEQUIGNON Didier 06/2010| |Temp.: %d øC Threshold: %d øC |Link with process %d %s][OK]",
							temp,trigger_temp,app_id,app_name);
						MT_form_xalert(1,mess_alert,ITIME*10L,0L,myglobal);
						break;
					case AP_TERM:
						end=1;
						break;				
					case MSG_CT60_TEMP:
						flag_msg=1;
						app_id=message[1];
						trigger_temp=(unsigned int)message[3];
						daystop=(unsigned int)message[4];
						timestop=(unsigned int)message[5];
						beep=(unsigned int)message[6];
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
						break;
				}
			}
		}
	}
	if(tab_temp!=0)
		Mfree(tab_temp);
	MT_appl_exit(myglobal);
	return(0);
}

void var_name_app(char *env,char *app_name)
{
	register int i;
	char *p;
	for(i=0;i<8;app_name[i++]=' ');
	i=0;
	p=env;
	while(env[i])
	{
		if(env[i]=='\\')
			p=&env[i+1];
		i++;		
	}
	for(i=0;i<8 && p[i] && p[i]!='.';i++)
	{
		if(p[i]>='a' && p[i]<'z')
			app_name[i]=p[i]|0x20;
		else
			app_name[i]=p[i];	
	}
}

int start_app(char *path_app,char *cmd,WORD *global)

{
	register int i,ret;
	char *p;
	char path[1024],cmd_line[256];
	if(*cmd)
	{
		strcpy(&cmd_line[1],cmd);
		cmd_line[0]=(char)strlen(cmd);
	}
	else
		cmd_line[0]=cmd_line[1]=0;
	if(path_app[1]==':' && path_app[2]=='\\'
	 && ((path_app[0]>='a' && path_app[0]<='z')
	  || (path_app[0]>='A' && path_app[0]<='Z')))
	{ 
		Dsetdrv((int)(path_app[0]&0x1F)-1);
		strcpy(path,&path_app[2]);
		i=0;
		p=path;
		while(path[i])
		{
			if(path[i]=='\\')
				p=&path[i+1];
			i++;		
		}
		*p=0;
    	Dsetpath(path);
	}
	if(magic)
		ret=MT_shel_write(1,1,SHW_PARALLEL,path_app,cmd_line,global);
	else
		ret=MT_shel_write(0,1,SHW_CHAIN,path_app,cmd_line,global);
	evnt_timer(100L);
	return(ret);
}

void call_app(char *var_env,char *cmd,WORD *global)

{
	static char app_name[]="        ";
	static char mess_alert[256];
	char *env;
	if(_app)
	{
		if(cmd!=NULL)
			sprintf(mess_alert,"[0][%s|%s][]",var_env,cmd);
		else
			sprintf(mess_alert,"[0][%s][]",var_env);
		MT_form_xalert(1,mess_alert,ITIME,0L,global);
		env=getenv(var_env);
		if(env!=NULL && env[0])
		{
			var_name_app(env,app_name);
			if(MT_appl_find(app_name,global)<0)
			{
				if(cmd!=NULL)
					start_app(env,cmd,global);
				else
					start_app(env,"",global);
			}
		}
	}
}

void rsc_calc(OBJECT *tree)

{
	register int i;
	i=0;
	do
	{
		tree[i].ob_x*=gr_hwchar;
		tree[i].ob_y*=gr_hhchar;	
		tree[i].ob_width*=gr_hwchar;		
		tree[i].ob_height*=gr_hhchar;			
	}
	while(!(tree[i++].ob_flags & LASTOB));
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
	if((alert_tree=adr_tree(TREE1))==0)
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
			alert_tree[ALERTB2].ob_flags &= ~DEFAULT;
			alert_tree[ALERTB3].ob_flags &= ~DEFAULT;			
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
			j=0;
			while(*fo_xastring!='|' && *fo_xastring!=']' && j<60)
			{
				line[i][j++] = *fo_xastring;
				fo_xastring++;
			}
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
			j=0;
			while(*fo_xastring!='|' && *fo_xastring!=']' && j<20)
			{
				button[i][j++] = *fo_xastring;
				fo_xastring++;
			}
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
					switch(objc_clic)
					{
						case ALERTB1:			/* buttons */
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

void stop_60(void)

{
	COOKIE *p;
	Sync();
	Shutdown(0L);
	if(((p=get_cookie('_CPU'))!=0) && (p->v.l==60L))
	{
		if(get_cookie(ID_CF))
			Supexec(cf_stop);
		else
			Supexec(ct60_stop);
	}
	while(1);
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
