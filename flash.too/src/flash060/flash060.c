/* Flashing CT60 soft & hard
*  Didier Mequignon 2003 March, e-mail: didier-mequignon@wanadoo.fr
*
*  This program is free software; you can redistribute it and/or modify
*  it under the terms of the GNU General Public License as published by
*  the Free Software Foundation; either version 2 of the License, or
*  (at your option) any later version.
*
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU General Public License for more details.
*
*  You should have received a copy of the GNU General Public License
*  along with this program; if not, write to the Free Software
*  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include <tos.h>
#include <aes.h>
#include <vdi.h>
#include <string.h>
#include <stdio.h>
#include "flash060.h"
#include "jedec.h"
#include "jtag.h"

#define SOFT 0
#define HARD 1

#define	NORESOURCE	form_alert(1,"[1][File FLASH060.RSC not found][Cancel]")
#define	NOWINDOW	form_alert(1,"[1][No window free !][Cancel]")
#define	NOALERT		form_alert(1,"[1][Error message not found |inside the file FLASH060.RSC][OK]")
#define	NOMEMORY	form_alert(1,"[1][No enough memory ! |This program need 1MB][Cancel]")

#define FLASH_SIZE 0x100000
#define PARAM_SIZE 0x10000

#define ERR_DEVICE  -1
#define ERR_ERASE   -2
#define ERR_PROGRAM -3
#define ERR_VERIFY  -4
#define ERR_CT60    -5

#define MAX_PATH 1024
#define MAX_NAME 256

#define	DESK 0                             /* desktop window */
#define	WINDOW (NAME|CLOSER|MOVER|SMALLER) /* window options */

#define DD_OK  0
#define DD_NAK 1
#define DD_EXT 2
#define DD_LEN 3
#define DD_NUMEXTS 8
#define DD_EXTSIZE 32
#define DD_NAMEMAX 128
#define DD_TIMEOUT 4000

#define CT60_MODE_READ 0
#define CT60_PARAM_TOSRAM 0L

/* macros */

#define	Grect(p)	(p)->g_x,(p)->g_y,(p)->g_w,(p)->g_h
#define	aGrect(p)	&(p)->g_x,&(p)->g_y,&(p)->g_w,&(p)->g_h

#define ct60_rw_parameter(mode,type_param,value) (long)xbios(0xc60b,(short)mode,(long)type_param,(long)value)

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

typedef void (*__Sigfunc) (int signum);
__Sigfunc signal(int sig, __Sigfunc func);

int Alert(int name);
int Load(void);
int Keyboard(int key);
int Button(int code);
void aff_leds(int count);
int jtag_test_device(unsigned char *tap_state,unsigned long *usercode);
int jtag_isp_enable(unsigned char *tap_state);
int jtag_isp_exit(unsigned char *tap_state);
int jtag_erase(unsigned char *tap_state);
int jtag_blank(unsigned char *tap_state);
int jtag_program(unsigned char *tap_state);
int jtag_verify(unsigned char *tap_state);
unsigned long jtag_device_adr(unsigned long jedec_line);
unsigned long get_user_code_jed(void);
int test_file(char *path);
void load_file(char *path_argv);
int init(int argc,int *vp,int *wp);
void term(int code,int vh,int wh);
int rc_intersect(GRECT *r1,GRECT *r2);
int min(int a,int b),max(int a,int b);
void get_date_file(unsigned short date_file,char *date_format);
void get_date_os(unsigned char *date_os,char *date_format);
void get_version_boot(unsigned char *version_boot,char *version_format);
COOKIE *fcookie(void);
COOKIE *ncookie(COOKIE *p);
COOKIE *get_cookie(long id);
void hndl_dd(short pipe_num);
long dd_open_pipe(short pnum);
long dd_open(short pipe_num,unsigned char *extlist);
void dd_close(long fd);
int dd_getheader(long fd,unsigned char *obname,unsigned char *fname,unsigned char *datatype,long *size);
int dd_reply(long fd,unsigned char ack);
extern long get_date_flash(void);
extern long get_version_flash(void);
extern long program_flash(long offset,long size,void *source,int lock_interrupts);

/* global variables */

int contrl[12],intin[128],intout[128],ptsin[128],ptsout[128];
int ap_id,wh,w_icon,file_loaded=0;
void *buffer_flash=0;
long size_tos=0;
int jedec_only=0;
int soft_hard=SOFT;
int device=NO_DEVICE;
unsigned long usercode_jed=0;
OBJECT *Resource;
OBJECT *Icone;
GRECT shrink;
jedec_data_t jed=0;
__Sigfunc oldsig;

void main(int argc, char **argv)
{	
	int vh;					/* handle VDI */
	int code,event,done,i,bid,ok,clic,x,y,key;
	int message[8];
	long value=0;
	unsigned short version;
	char *path;
	OBJECT *op;
	TEDINFO *tp;
	GRECT rect1,rect2;
	clic=1;
	value=Supexec(get_date_flash);
	jedec_only=0;
	if(value==0)
		jedec_only=1;
	if((code=init(argc,&vh,&wh))==0)
	{
		rsrc_gaddr(R_OBJECT,DATE_FLASH,&op);
		tp=op->ob_spec.tedinfo;
		get_date_os((unsigned char *)&value,tp->te_ptext);  /* TOS in flash date */
		rsrc_gaddr(R_OBJECT,VERSION_FLASH,&op);
		tp=op->ob_spec.tedinfo;
		version=(unsigned short)Supexec(get_version_flash);
		get_version_boot((unsigned char *)&version,tp->te_ptext);
		if(argc>1)
		{
			wind_update(BEG_UPDATE);
			load_file(argv[1]);
			Button(PROG);
			wind_update(END_UPDATE);
		}
		do
		{
			event=evnt_multi(MU_KEYBD|MU_BUTTON|MU_MESAG,1,1,clic,0,0,0,0,0,0,0,0,0,0,
				message,0,0,&x,&y,&i,&i,&key,&i);
			done=0;
			if((event & MU_KEYBD) && !w_icon)
			{
				wind_update(BEG_UPDATE);
				done|=Keyboard(key);
				wind_update(END_UPDATE);
			}
			if(event & MU_BUTTON && !w_icon)
			{
				if((!(clic^=1)) && ((i=objc_find(Resource,ROOT,MAX_DEPTH,x,y)) >= 0))
				{
					wind_get(wh,WF_TOP,&ok,&bid,&bid,&bid);
					if(ok==wh)
					{
						wind_update(BEG_UPDATE);
						done|=Button(i);
						wind_update(END_UPDATE);
					}
				}
			}
			if(event & MU_MESAG)
			{
				wind_update(BEG_UPDATE);
				switch(message[0])
				{
				case WM_REDRAW:		/* retrace */
					wind_get(message[3],WF_WORKXYWH,aGrect(&rect1));
					if(w_icon)		/* window iconified */
					{
						Icone[ROOT].ob_x=rect1.g_x;
						Icone[ROOT].ob_y=rect1.g_y;
						Icone[ROOT].ob_width=rect1.g_w;
						Icone[ROOT].ob_height=rect1.g_h;
						Icone[ICONE].ob_x=(rect1.g_w-Icone[ICONE].ob_width)/2;
						Icone[ICONE].ob_y=(rect1.g_h-Icone[ICONE].ob_height)/2;
					}
					else
					{
						Resource[ROOT].ob_x=rect1.g_x;
						Resource[ROOT].ob_y=rect1.g_y;
					}
					rect2.g_x=message[4];
					rect2.g_y=message[5];
					rect2.g_w=message[6];
					rect2.g_h=message[7];
					wind_get(message[3],WF_FIRSTXYWH,aGrect(&rect1));
					while(rect1.g_w && rect1.g_h)
					{
						if(rc_intersect(&rect2,&rect1))
						{
							if(!w_icon)	/* window not iconified */
								objc_draw(Resource,ROOT,MAX_DEPTH,Grect(&rect1));
							else
								objc_draw(Icone,ROOT,MAX_DEPTH,Grect(&rect1));
						}
						wind_get(message[3],WF_NEXTXYWH,aGrect(&rect1));
					}
					break;
				case WM_TOPPED:
				case WM_NEWTOP:		/* window selected */
					wind_set(message[3],WF_TOP,0,0,0,0);
					break;
				case AP_TERM:
				case WM_CLOSED:		/* window or program closed (end) */
					done=1;
					break;
				case AP_DRAGDROP :  /* drag & drop */ 
					wind_set(message[3],WF_TOP,0,0,0,0);
					hndl_dd((short)message[7]);
					break;
				case WM_MOVED:		/* window moved */
					wind_set(message[3],WF_CURRXYWH,message[4],message[5],message[6],message[7]);
					wind_get(message[3],WF_WORKXYWH,&message[4],&message[5],&message[6],&message[7]);
					Resource->ob_x=message[4];
					Resource->ob_y=message[5];
					break;
				case WM_BOTTOMED:
					wind_set(message[3],WF_BOTTOM,message[4],message[5],message[6],message[7]);
					break;
				case WM_ICONIFY:	/* window inconified */
				case WM_ALLICONIFY:
					wind_get(message[3],WF_CURRXYWH,aGrect(&rect1));
					graf_shrinkbox(message[4],message[5],message[6],message[7],Grect(&rect1));
					wind_set(message[3],WF_ICONIFY,message[4],message[5],message[6],message[7]);
					w_icon=1;
					break;
				case WM_UNICONIFY:	/* window recall */
					wind_get(message[3],WF_CURRXYWH,aGrect(&rect1));
					graf_growbox(Grect(&rect1),message[4],message[5],message[6],message[7]);
					wind_set(message[3],WF_UNICONIFY,message[4],message[5],message[6],message[7]);
					w_icon=0;
					break;
				}
				wind_update(END_UPDATE);
			}
		}
		while(!done);
	}
	if(jed)
		jedec_free(jed);
	term(code,vh,wh);
}

int Alert(int name)
{	
	char *addr;
	if(rsrc_gaddr(R_STRING,name,&addr))
		return form_alert(1,addr);
	return NOALERT;
}

int Load(void)
{
	return(rsrc_load("flash060.rsc")
		&& rsrc_gaddr(R_TREE,FORM1,&Resource)
		&& rsrc_gaddr(R_TREE,FORM2,&Icone));
}

int Keyboard(int key)
{
	key&=0x7F;
	switch(key)
	{
		case 12:            /* CTRL-L */
			Button(LOAD);
			break;
		case 13:            /* ENTER */
			Button(PROG);
			break;
		case 17:            /* CTRL-Q */
		case 27:            /* ESC */
			return(1);
	}
	return(0);
}

int Button(int code)
{
	long stack,offset,value,tosram;
	unsigned long usercode;
	unsigned short version;
	int i,b,error,verify,repeat,lock_interrupts;
	unsigned char tap_state;
	char c;
	COOKIE *p;
	OBJECT *op;
	TEDINFO *tp;
	char buffer[2];
	if(!rsrc_gaddr(R_OBJECT,code,&op)
	 || !((op->ob_flags & SELECTABLE) && !(op->ob_state & DISABLED)))
		return(0);
	verify=0;
	switch(code)
	{
	case LOAD:
	case FILE:
		load_file(0);
		break;	
	case VERIFY:
		verify=1;
	case PROG:
		objc_change(Resource,code,MAX_DEPTH,Resource->ob_x,Resource->ob_y,
			Resource->ob_width,Resource->ob_height,SELECTED,1);
		if(!file_loaded)
			load_file(0);
		b=1;
		tosram=lock_interrupts=0;
		if(file_loaded && ((p=get_cookie('_CPU'))!=0) && (p->v.l==0x3C))	/* 68060 */
		{
			if(get_cookie('CT60'))
				tosram=ct60_rw_parameter(CT60_MODE_READ,CT60_PARAM_TOSRAM,0L)&1;
			if(!tosram && soft_hard!=HARD)
			{
				b=Alert(ALERT_060);
				if(b && get_cookie('MagX')==0)
					lock_interrupts=1;
			}
			else if(soft_hard==HARD)
			{
				Alert(ALERT_HARD_060);
				b=0;			
			}
		}
		if(file_loaded && b==1)
		{
			graf_mouse(BUSYBEE,0L);
			aff_leds(-1);  /* init */
			if(soft_hard==HARD && jed)
			{
				if(Supexec(test_cable)==0)
					Alert(ALERT_CABLE);
				else
				{
					stack=Super(0L);
					/* Initialize the I/O.  SetPort initializes I/O on first call */
					setPort(TMS,1);
					setPort(TCK,1);
					b=(int)readTDOBit(); 
					Super((void *)stack);
					if(!b)
						Alert(ALERT_POWER);
					else
					{
						JtagSelectTarget(device);
						stack=Super(0L);
						setPort(TMS,1); /* JTAG reset */
						pulseClock(5);
						setPort(TMS,0);
						pulseClock(1);
						Super((void *)stack);
						tap_state=TAPSTATE_RUNTEST;
						error=jtag_test_device(&tap_state,&usercode);
						b=1;
						for(i=0;i<32;i+=8)
						{
							c=(char)(usercode>>i);
							if(!((c>='0' && c<='9') || (c>='A' && c<='Z') || (c>='a' && c<='z')))
							{
								b=0;
								break;
							}
						}
						if(b)
						{
							rsrc_gaddr(R_OBJECT,USERCODE,&op);
							tp=op->ob_spec.tedinfo;
							for(i=3;i>=0;tp->te_ptext[3-i]=(char)(usercode>>(i<<3)),i--);
							tp->te_ptext[4]=0;
							objc_draw(Resource,USERCODE,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
						}
						if(error==ERROR_NONE)
						{
							if(verify)
							{
								if(usercode!=usercode_jed)
									error=ERROR_CODE;
							}
							else
							{
								repeat=5;
								do
								{
									error=jtag_isp_enable(&tap_state);
									if(error==ERROR_NONE)
									{
										error=jtag_erase(&tap_state);
										i=jtag_isp_exit(&tap_state);
										if(error==ERROR_NONE && i!=ERROR_NONE)
											error=i;
									}
									if(error==NONE || error==ERROR_ERASE)
									{
										error=jtag_isp_enable(&tap_state);
										if(error==ERROR_NONE)
										{
											error=jtag_blank(&tap_state);
											i=jtag_isp_exit(&tap_state);
											if(error==ERROR_NONE && i!=ERROR_NONE)
												error=i;
										}
									}
									repeat--;
								}
								while(repeat>=0 && (error==ERROR_ERASE || error==ERROR_BLANK));
								if(error==NONE)
								{
									error=jtag_isp_enable(&tap_state);
									if(error==ERROR_NONE)
									{
										error=jtag_program(&tap_state);
										i=jtag_isp_exit(&tap_state);
										if(error==ERROR_NONE && i!=ERROR_NONE)
											error=i;
									}
								}		
							}
							if(error==NONE)
							{
								error=jtag_isp_enable(&tap_state);
								if(error==ERROR_NONE)
								{
									error=jtag_verify(&tap_state);
									i=jtag_isp_exit(&tap_state);
									if(error==ERROR_NONE && i!=ERROR_NONE)
										error=i;
								}
							}
						}
						switch(error)
						{
							case ERROR_TDOMISMATCH: i=ALERT_JTAG_DEV; break;
							case ERROR_MAXRETRIES: i=ALERT_JTAG_RETRY; break;
							case ERROR_ILLEGALSTATE: i=ALERT_JTAG_STATE; break;
							case ERROR_ERASE:
							case ERROR_BLANK: i=ALERT_JTAG_ERASE; break;
							case ERROR_PROGRAM: i=ALERT_JTAG_PROG; break;
							case ERROR_VERIFY: i=ALERT_JTAG_VERIF; break;
							case ERROR_CODE: i=ALERT_JTAG_CODE; break;
							default: i=-1; break;
						}
						if(i>=0)
							Alert(i);
					}
				}
			}
			else
			{
				if(!jedec_only && buffer_flash!=0)
				{
					offset=0;
					while(offset<(FLASH_SIZE-PARAM_SIZE))
					{
						if(lock_interrupts)
						{
							buffer[0]=0x13;
							Ikbdws(0,buffer); /* pause output */
							evnt_timer(10,0);
						}
						stack=Super(0L);
						offset=program_flash(offset,size_tos,buffer_flash,lock_interrupts);
						Super((void *)stack);
						if(lock_interrupts)
						{
							buffer[0]=0x11;
							Ikbdws(0,buffer); /* resume */
							evnt_timer(10,0);
						}											
						if(offset<0)
						{
							switch(offset)
							{
								case ERR_DEVICE: i=ALERT_DEVICE; break;
								case ERR_ERASE: i=ALERT_ERASE; break;
								case ERR_PROGRAM: i=ALERT_PROGRAM; break;
								case ERR_VERIFY: i=ALERT_VERIFY; break;
								case ERR_CT60: i=ALERT_CT60; break;
								default: i=-1; break;
							}
							if(i>=0)
								Alert(i);
							break;
						}
						aff_leds((int)((offset*16L)/(long)(FLASH_SIZE-PARAM_SIZE)));
					}
				}
			}
			graf_mouse(ARROW,0L);
		}
		rsrc_gaddr(R_OBJECT,DATE_FLASH,&op);
		tp=op->ob_spec.tedinfo;
		value=Supexec(get_date_flash);
		get_date_os((unsigned char *)&value,tp->te_ptext);
		rsrc_gaddr(R_OBJECT,VERSION_FLASH,&op);
		tp=op->ob_spec.tedinfo;
		version=(unsigned short)Supexec(get_version_flash);
		get_version_boot((unsigned char *)&version,tp->te_ptext);
		objc_draw(Resource,DATE_FLASH,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
		objc_draw(Resource,VERSION_FLASH,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
		objc_change(Resource,code,MAX_DEPTH,Resource->ob_x,Resource->ob_y,
			Resource->ob_width,Resource->ob_height,NORMAL,1);
		break;
	}
	return(0);
}

void aff_leds(int count)
{
	static int led[]={ L1,L2,L3,L4,L5,L6,L7,L8,L9,L10,L11,L12,L13,L14,L15,L16,0 };
	int i;
	if(count<0)
	{
		for(i=0;led[i];i++)
		{
			if(Resource[led[i]].ob_state & SELECTED)
			{
				Resource[led[i]].ob_state &= ~SELECTED;
				objc_draw(Resource,led[i],MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
			}
		}
	}
	else
	{
		for(i=0;led[i];i++)
		{
			if(i<count)
			{
				if(!(Resource[led[i]].ob_state & SELECTED))
				{
					Resource[led[i]].ob_state |= SELECTED;
					objc_draw(Resource,led[i],MAX_DEPTH,
						Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
				}					
			}
			else
			{
				if(Resource[led[i]].ob_state & SELECTED)
				{
					Resource[led[i]].ob_state &= ~SELECTED;
					objc_draw(Resource,led[i],MAX_DEPTH,
						Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
				}
			}
		}	
	}
}

int jtag_test_device(unsigned char *tap_state,unsigned long *usercode)
{
	int error;
	static lenVal tdi,tdo,tdo_cmp,tdo_mask;
	*tap_state=TAPSTATE_RESET;
	tdi.len=0;               /* idle */
	error=JtagShift(tap_state,TAPSTATE_RUNTEST,0,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(error)
		return(error);       /* bypass */
	tdi.len=tdo.len=tdo_cmp.len=tdo_mask.len=1;
	tdi.val[0]=JTAG_CMD_BYPASS;
	tdo_cmp.val[0]=0x01;
	tdo_mask.val[0]=0xE3;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,&tdo,&tdo_cmp,&tdo_mask,TAPSTATE_RUNTEST,0,0);
#ifdef DEBUG
	printf("\r\nBYPASS tdi:$%02x, tdo:$%02x, cmp:$%02x ",tdi.val[0],tdo.val[0],tdo_cmp.val[0]);
#endif
	if(error)
		return(error);       /* idcode */
#ifdef DEBUG
	printf("\r\nIDCODE ");
#endif
	tdi.val[0]=JTAG_CMD_IDCODE;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(error)
		return(error);
	tdi.len=tdo.len=tdo_cmp.len=tdo_mask.len=4;
	*(unsigned long *)&tdi.val[0]=0xFFFFFFFF;
	*(unsigned long *)&tdo_cmp.val[0]=IDCODE_XC95144XL;
	*(unsigned long *)&tdo_mask.val[0]=IDMASK;
	error=JtagShift(tap_state,TAPSTATE_SHIFTDR,32,&tdi,&tdo,&tdo_cmp,&tdo_mask,TAPSTATE_RUNTEST,0,0);
#ifdef DEBUG
	printf("tdi:$%08lx, tdo:$%08lx, cmp:$%08lx, mask:$%08lx ",
	 (unsigned long)(*(unsigned long *)&tdi.val[0]),
	 (unsigned long)(*(unsigned long *)&tdo.val[0]),
	 (unsigned long)(*(unsigned long *)&tdo_cmp.val[0]),
	 (unsigned long)(*(unsigned long *)&tdo_mask.val[0]));
#endif
	if(error)
		return(error);
	tdi.len=1;               /* bypass */
	tdi.val[0]=JTAG_CMD_BYPASS;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(usercode!=NULL)
	{
		if(error)
			return(error);
#ifdef DEBUG
		printf("\r\nUSERCODE ");
#endif
		tdi.len=1;           /* usercode */
		tdi.val[0]=JTAG_CMD_USERCODE;
		error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
		if(error)
			return(error);
		tdi.len=tdo.len=tdo_cmp.len=tdo_mask.len=4;
		*(unsigned long *)&tdi.val[0]=*(unsigned long *)&tdo_mask.val[0]=0xFFFFFFFF;
		error=JtagShift(tap_state,TAPSTATE_SHIFTDR,32,&tdi,&tdo,0,&tdo_mask,TAPSTATE_RUNTEST,0,0);
		*usercode=*(unsigned long *)&tdo.val[0];
#ifdef DEBUG
		printf("tdi:$%08lx, tdo:$%08lx, cmp:$%08lx, mask:$%08lx ",
		 (unsigned long)(*(unsigned long *)&tdi.val[0]),
		 (unsigned long)(*(unsigned long *)&tdo.val[0]),
		 (unsigned long)(*(unsigned long *)&tdo_cmp.val[0]),
		 (unsigned long)(*(unsigned long *)&tdo_mask.val[0]));
#endif
		if(error)
			return(error);
		tdi.len=1;           /* bypass */
		tdi.val[0]=JTAG_CMD_BYPASS;
		error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	}
	return(error);
}

int jtag_isp_enable(unsigned char *tap_state)
{
	int error;
	static lenVal tdi;
#ifdef DEBUG
	printf("\r\nISPEN ");
#endif
	tdi.len=1;               /* isp enable */
	tdi.val[0]=JTAG_CMD_ISPEN;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(error)
		return(error);
	tdi.val[0]=0x05;
	error=JtagShift(tap_state,TAPSTATE_SHIFTDR,6,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	return(error);
}

int jtag_isp_exit(unsigned char *tap_state)
{
	int error;
	static lenVal tdi;
#ifdef DEBUG
	printf("\r\nISPEX ");
#endif	
	tdi.len=1;               /* isp exit */
	tdi.val[0]=JTAG_CMD_ISPEX;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(error)
		return(error);
	tdi.len=0;               /* idle 100 TCK */
	error=JtagShift(tap_state,TAPSTATE_RUNTEST,0,&tdi,0,0,0,TAPSTATE_RUNTEST,100,0);
	if(error)
		return(error);
	tdi.len=1;               /* bypass */
	tdi.val[0]=JTAG_CMD_BYPASS;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	return(error);
}

int jtag_erase(unsigned char *tap_state)
{
	int error;				
	static lenVal tdi,tdo,tdo_cmp,tdo_mask;
#ifdef DEBUG
	printf("\r\nFERASE ");
#endif
	tdi.len=1;               /* erase => overrinding write protection */
	tdi.val[0]=JTAG_CMD_FERASE;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(error)
		return(error);
	tdi.len=3;
	*(unsigned long *)&tdi.val[0]=((0xAA55L<<2)|3L)<<8;
	error=JtagShift(tap_state,TAPSTATE_SHIFTDR,18,&tdi,0,0,0,TAPSTATE_RUNTEST,400000,0);
#ifdef DEBUG
	printf("tdi:$%08lx",(unsigned long)(*(unsigned long *)&tdi.val[0]));
#endif
	if(error)
		return(error);
#ifdef DEBUG
	printf("\r\nFBULK ");
#endif
	tdi.len=1;               /* bulk erase */
	tdi.val[0]=JTAG_CMD_FBULK;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(error)
		return(error);
	tdi.len=3;
	*(unsigned long *)&tdi.val[0]=0x03FFFF00;
	error=JtagShift(tap_state,TAPSTATE_SHIFTDR,18,&tdi,0,0,0,TAPSTATE_RUNTEST,400000,0);
	if(error)
		return(error);
	tdo.len=tdo_cmp.len=tdo_mask.len=3;
	*(unsigned long *)&tdi.val[0]=0x00000100;
	*(unsigned long *)&tdo_cmp.val[0]=0x00000100;
	*(unsigned long *)&tdo_mask.val[0]=0x00000300;
	error=JtagShift(tap_state,TAPSTATE_SHIFTDR,18,&tdi,&tdo,&tdo_cmp,&tdo_mask,TAPSTATE_RUNTEST,0,0);
#ifdef DEBUG
	printf("tdi:$%08lx, tdo:$%08lx, cmp:$%08lx, mask:$%08lx ",
	 (unsigned long)(*(unsigned long *)&tdi.val[0]),
	 (unsigned long)(*(unsigned long *)&tdo.val[0]),
	 (unsigned long)(*(unsigned long *)&tdo_cmp.val[0]),
	 (unsigned long)(*(unsigned long *)&tdo_mask.val[0]));
#endif
	if(error==ERROR_TDOMISMATCH)
		error=ERROR_ERASE;
	return(error);
}

int jtag_blank(unsigned char *tap_state)
{	
	int error;				
	static lenVal tdi,tdo,tdo_cmp,tdo_mask;
#ifdef DEBUG
	printf("\r\nFBLANK ");
#endif	
	tdi.len=1;               /* blank check */
	tdi.val[0]=JTAG_CMD_FBLANK;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(error)
		return(error);
	tdi.len=3;
	*(unsigned long *)&tdi.val[0]=0x00000300;
	error=JtagShift(tap_state,TAPSTATE_SHIFTDR,18,&tdi,0,0,0,TAPSTATE_RUNTEST,500,0);
#ifdef DEBUG
	printf("tdi:$%08lx",(unsigned long)(*(unsigned long *)&tdi.val[0]));
#endif
	if(error)
		return(error);
	tdo.len=tdo_cmp.len=tdo_mask.len=3;
	*(unsigned long *)&tdi.val[0]=0x00000100;
	*(unsigned long *)&tdo_cmp.val[0]=0x00000100;
	*(unsigned long *)&tdo_mask.val[0]=0x00000300;
	error=JtagShift(tap_state,TAPSTATE_SHIFTDR,18,&tdi,&tdo,&tdo_cmp,&tdo_mask,TAPSTATE_RUNTEST,0,0);
#ifdef DEBUG
	printf("\r\n tdi:$%08lx, tdo:$%08lx, cmp:$%08lx, mask:$%08lx ",
	 (unsigned long)(*(unsigned long *)&tdi.val[0]),
	 (unsigned long)(*(unsigned long *)&tdo.val[0]),
	 (unsigned long)(*(unsigned long *)&tdo_cmp.val[0]),
	 (unsigned long)(*(unsigned long *)&tdo_mask.val[0]));
#endif
	if(error==ERROR_TDOMISMATCH)
		error=ERROR_BLANK;
	return(error);
}

int jtag_program(unsigned char *tap_state)
{
	unsigned long count_fuse,count_size,adr_fuse,adr,old_adr;
	int i,byte,bit,first,error;				
	unsigned char value;
	static lenVal tdi,tdo,tdo_cmp,tdo_mask;
#ifdef DEBUG
	printf("\r\nFPGM ");
#endif
	tdi.len=1;               /* program */
	tdi.val[0]=JTAG_CMD_FPGM;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(error)
		return(error);
	count_size=0;
	bit=(int)jed->sizes_list[count_size];
	value=0;
	byte=8;
	first=1;
	adr_fuse=old_adr=0;
	*(unsigned long *)&tdo_cmp.val[0]=*(unsigned long *)&tdo_mask.val[0]=0;
	*(unsigned long *)&tdo_cmp.val[4]=*(unsigned long *)&tdo_mask.val[4]=0;
	*(unsigned long *)&tdo_cmp.val[8]=*(unsigned long *)&tdo_mask.val[8]=0x00000300;
	for(count_fuse=0;count_fuse<jed->fuse_count;count_fuse++)
	{
		bit--;
			value>>=1;
		if(jedec_get_fuse(jed,count_fuse))
			value |= 0x80;
		else
			value &= ~0x80;
		if(bit<=0)
		{
			tdi.val[byte+2]=value>>(8-jed->sizes_list[count_size++]);
			byte--;
			if(byte<=0)
			{
				adr=jtag_device_adr(adr_fuse);
				if(old_adr != (adr & 0xFFFFF000))
					old_adr = adr & 0xFFFFF000;
				tdi.len=tdo.len=tdo_cmp.len=tdo_mask.len=11;
				tdi.val[0]=0;
				*(unsigned short *)&tdi.val[1]=(unsigned short)adr;
				if((adr & 0x1F)== 0x14)
					tdi.val[11]=0xC0;
				else
					tdi.val[11]=0x40;
				*(unsigned long *)&tdi.val[0]<<=2;
				*(unsigned long *)&tdi.val[0]|=(*(unsigned long *)&tdi.val[4]>>30);
				*(unsigned long *)&tdi.val[4]<<=2;
				*(unsigned long *)&tdi.val[4]|=(*(unsigned long *)&tdi.val[8]>>30);
				*(unsigned long *)&tdi.val[8]<<=2;
				if((adr & 0x1F)== 0x00)
				{
					tdo_cmp.val[10]=0x01;
					tdo_mask.val[10]=0x03;
				}
				if((adr & 0x1F)== 0x01)
				{
					tdo_cmp.val[10]=0x02;
					tdo_mask.val[10]=0x00;
				}				
				if(first)
					error=JtagShift(tap_state,TAPSTATE_SHIFTDR,16+8*8+2,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
				else
					error=JtagShift(tap_state,TAPSTATE_SHIFTDR,16+8*8+2,&tdi,&tdo,&tdo_cmp,&tdo_mask,TAPSTATE_RUNTEST,0,0);
#ifdef DEBUG
				if(error)
				{
					printf("\r\nL%05ld tdi:",adr_fuse);
					for(i=0;i<tdi.len;printf("%02x",tdi.val[i++]));
					if(!first)
					{
						printf(", tdo:");
						for(i=0;i<tdo.len;printf("%02x",tdo.val[i++]));
						printf(", cmp:");
						for(i=0;i<tdo_cmp.len;printf("%02x",tdo_cmp.val[i++]));
					}
				}
#endif
				first=0;
				if(error)
				{
					if(error==ERROR_TDOMISMATCH)
						error=ERROR_PROGRAM;
					break;
				}
				if((adr & 0x1F)== 0x14)
				{
					tdi.len=0;              /* idle */
					error=JtagShift(tap_state,TAPSTATE_RUNTEST,0,&tdi,0,0,0,TAPSTATE_RUNTEST,50000,0);
					aff_leds((int)((((count_fuse+1)*16L)/jed->fuse_count)));
					if(error)
						break;
				}
				adr_fuse=count_fuse+1;
				byte=8;
			}
			bit=(int)jed->sizes_list[count_size];
			value=0;
		}
	}
	if(!error)
	{
		tdi.len=tdo.len=tdo_cmp.len=tdo_mask.len=11;
		*(unsigned long *)&tdi.val[0]=*(unsigned long *)&tdi.val[4]=0;
		*(unsigned long *)&tdi.val[8]=0x00000100;
		tdo_cmp.val[10]=0x01;
		tdo_mask.val[10]=0x03;		
		error=JtagShift(tap_state,TAPSTATE_SHIFTDR,16+8*8+2,&tdi,&tdo,&tdo_cmp,&tdo_mask,TAPSTATE_RUNTEST,0,0);
#ifdef DEBUG
		if(error)
		{
			printf("\r\nL%05ld tdi:",adr_fuse);
			for(i=0;i<tdi.len;printf("%02x",tdi.val[i++]));
			printf(", tdo:");
			for(i=0;i<tdo.len;printf("%02x",tdo.val[i++]));
			printf(", cmp:");
			for(i=0;i<tdo_cmp.len;printf("%02x",tdo_cmp.val[i++]));
		}
#endif
		if(error==ERROR_TDOMISMATCH)
			error=ERROR_PROGRAM;
	}
	return(error);
}

int jtag_verify(unsigned char *tap_state)
{
	unsigned long count_fuse,count_size,adr_fuse,adr,mem_adr;
	int i,byte,bit,first,error;				
	unsigned char value;
	static lenVal tdi,tdo,tdo_cmp,tdo_mask,old_tdo;
#ifdef DEBUG
	printf("\r\nFVFY ");
#endif
	tdi.len=1;               /* verify */
	tdi.val[0]=JTAG_CMD_FVFY;
	error=JtagShift(tap_state,TAPSTATE_SHIFTIR,8,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
	if(error)
		return(error);
	count_size=0;
	bit=(int)jed->sizes_list[count_size];
	value=0;
	byte=8;
	first=1;
	adr_fuse=0;
	tdi.len=tdo.len=tdo_cmp.len=tdo_mask.len=11;
	*(unsigned long *)&tdi.val[4]=0;
	*(unsigned long *)&tdi.val[8]=0x00000300;
	*(unsigned long *)&tdo_mask.val[0]=0x03FFFFFF;
	*(unsigned long *)&tdo_mask.val[4]=0xFFFFFFFF;
	*(unsigned long *)&tdo_mask.val[8]=0xFFFFFF00;
	for(count_fuse=0;count_fuse<jed->fuse_count;count_fuse++)
	{
		bit--;
			value>>=1;
		if(jedec_get_fuse(jed,(count_fuse)))
			value |= 0x80;
		else
			value &= ~0x80;
		if(bit<=0)
		{
			tdo_cmp.val[byte+2]=value>>(8-jed->sizes_list[count_size++]);
			byte--;
			if(byte<=0)
			{
				adr=jtag_device_adr(adr_fuse);
				*(unsigned long *)&tdi.val[0]=adr<<10;
				tdo_cmp.val[0]=0;
				*(unsigned short *)&tdo_cmp.val[1]=(unsigned short)adr;
				tdo_cmp.val[11]=0x40;
				*(unsigned long *)&tdo_cmp.val[0]<<=2;
				*(unsigned long *)&tdo_cmp.val[0]|=(*(unsigned long *)&tdo_cmp.val[4]>>30);
				*(unsigned long *)&tdo_cmp.val[4]<<=2;
				*(unsigned long *)&tdo_cmp.val[4]|=(*(unsigned long *)&tdo_cmp.val[8]>>30);
				*(unsigned long *)&tdo_cmp.val[8]<<=2;
				if(first)
					error=JtagShift(tap_state,TAPSTATE_SHIFTDR,16+8*8+2,&tdi,0,0,0,TAPSTATE_RUNTEST,0,0);
				else
					error=JtagShift(tap_state,TAPSTATE_SHIFTDR,16+8*8+2,&tdi,&tdo,&old_tdo,&tdo_mask,TAPSTATE_RUNTEST,0,0);
#ifdef DEBUG
				if(error)
				{
					printf("\r\nL%05ld tdi:",adr_fuse);
					for(i=0;i<tdi.len;printf("%02x",tdi.val[i++]));
					if(!first)
					{
						printf(", tdo:");
						for(i=0;i<tdo.len;printf("%02x",tdo.val[i++]));
						printf(", cmp:");
						for(i=0;i<old_tdo.len;printf("%02x",old_tdo.val[i++]));
					}
				}
#endif
				first=0;
				if(error)
				{
					if(error==ERROR_TDOMISMATCH)
						error=ERROR_VERIFY;
					break;
				}
				old_tdo=tdo_cmp;
				adr_fuse=count_fuse+1;
				byte=8;
			}
			bit=(int)jed->sizes_list[count_size];
			value=0;
		}
		if((count_fuse & 2047)==0)
			aff_leds((int)((((count_fuse+2048)*16L)/jed->fuse_count)));
	}
	if(!error)
	{
		tdi.val[10]=0x01;
		error=JtagShift(tap_state,TAPSTATE_SHIFTDR,16+8*8+2,&tdi,&tdo,&tdo_cmp,&tdo_mask,TAPSTATE_RUNTEST,0,0);
		if(error==ERROR_TDOMISMATCH)
			error=ERROR_VERIFY;
	}
	return(error);
}

unsigned long jtag_device_adr(unsigned long jedec_line)
{
	unsigned long saddr,taddr,laddr;
	saddr=jedec_line/(DATA_LENGTH/2)/SECTOR_LENGTH;
	taddr=(jedec_line/DATA_LENGTH)%MAX_SECTOR;
	if(taddr<72)
		laddr=taddr/8;
	else
		laddr=((taddr-72) / 6) + 9;
	return(((laddr/5) * 0x08) + (laddr%5) + (saddr*0x20));
}

unsigned long get_user_code_jed(void)
{
	unsigned long count_fuse,usercode=0;
	long fuse,j,m;
	for(count_fuse=0;count_fuse<jed->fuse_count;count_fuse++)
	{
		fuse=jedec_get_fuse(jed,count_fuse);					
		if((count_fuse >= 648*DATA_LENGTH) && (count_fuse < 712*DATA_LENGTH))
		{
			j = count_fuse - (648*DATA_LENGTH);
			m = j / (DATA_LENGTH*8);
			if((j & (DATA_LENGTH*8-1)) == 6 || (j & (DATA_LENGTH*8-1)) == 7)
			{
				if(fuse)
					usercode |= 0x80000000L >> (m*2+1-(count_fuse&1));
			}
		}
		if((count_fuse >= 756*DATA_LENGTH) && (count_fuse < 820*DATA_LENGTH))
		{
			j = (count_fuse - 756*DATA_LENGTH);
			m = j / (DATA_LENGTH*8);
			if((j & (DATA_LENGTH*8-1)) == 6 || (j & (DATA_LENGTH*8-1)) == 7)
			{
				if(fuse)
					usercode |= 0x00008000L >> (m*2+1-(count_fuse&1));
			}
		}
	}
	return(usercode);
}

int test_file(char *path)
{
	int i;
	i=strlen(path);
	if(i>3 && path[i-4]=='.'
	 && ((path[i-3]=='J' && path[i-2]=='E' && path[i-1]=='D')
	 || (path[i-3]=='j' && path[i-2]=='e' && path[i-1]=='d')))
		return(HARD);
	return(SOFT);
}

void load_file(char *path_argv)
{
	char path[MAX_PATH],nom[MAX_NAME],device_name[MAX_NAME],code[10];
	DTA *save_dta;
	DTA tp_dta;
	char c;
	int i,handle,b,title;
	unsigned short date;
	OBJECT *op;
	TEDINFO *tp;
	unsigned char *p;
	char *addr;
	nom[0]=0;
	if(path_argv==0)
	{
		path[0]=Dgetdrv()+'A'; path[1]=':';
		Dgetpath(path+2,Dgetdrv()+1);
		strcat(path,"\\");
		addr=NULL;
		if(jedec_only)
		{
			strcat(path,"*.JED");
			title=TITLE_JED;		
		}	
		else
		{
			if(get_cookie('MagX') || get_cookie('MiNT'))
				strcat(path,"*.BIN");
			else
				strcat(path,"*.*");
			title=TITLE_BIN_JED;
		}
		if(rsrc_gaddr(R_STRING,title,&addr))
			fsel_exinput(path,nom,&b,addr);
		else
			fsel_input(path,nom,&b);
		objc_draw(Resource,ROOT,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
		if(path[0]>='A' && path[0]<='Z')
		{
			c=strlen(path)-1;	
			while(path[c]!='\\')
				path[c--]=0;
			Dsetdrv(path[0]-'A');Dsetpath(path+2);
			strcat(path,nom);
		}
	}
	else
	{
		strcpy(path,path_argv);
		b=1;
		objc_draw(Resource,ROOT,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
	}
	if(b)
	{
		if(jed)
		{
			jedec_free(jed);
			jed=NULL;
			if(!jedec_only)
			{
				rsrc_gaddr(R_OBJECT,VERIFY,&op);
				op->ob_flags |= HIDETREE;
				rsrc_gaddr(R_OBJECT,CODE_VERSION_FI,&op);
				op->ob_flags |= HIDETREE;
				rsrc_gaddr(R_OBJECT,VERSION_FI,&op);
				op->ob_flags &= ~HIDETREE;
				rsrc_gaddr(R_OBJECT,DATE_F,&op);
				op->ob_flags &= ~HIDETREE;
				rsrc_gaddr(R_OBJECT,VERSION_F,&op);
				op->ob_flags &= ~HIDETREE;
				rsrc_gaddr(R_OBJECT,DATE_FLASH,&op);
				op->ob_flags &= ~HIDETREE;
				rsrc_gaddr(R_OBJECT,VERSION_FLASH,&op);
				op->ob_flags &= ~HIDETREE;
				rsrc_gaddr(R_OBJECT,USERCODE,&op);
				op->ob_flags |= HIDETREE;
				objc_draw(Resource,ROOT,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
			}
		}
		file_loaded=0;
		size_tos=0;
	    graf_mouse(BUSYBEE,0L);
		if((soft_hard=test_file(path))==HARD)
		{
			if((jed=jedec_read(path,device_name))==NULL)
			{
				graf_mouse(ARROW,0L);
				Alert(ALERT_JEDEC);
			}
			else
			{
				save_dta=Fgetdta();
				Fsetdta(&tp_dta);
				date=0;				
				if(Fsfirst(path,1)==0)
					date=(unsigned short)tp_dta.d_date;
				Fsetdta(save_dta);
				rsrc_gaddr(R_OBJECT,DATE_FILE,&op);
				tp=op->ob_spec.tedinfo;
				get_date_file(date,tp->te_ptext);
				graf_mouse(ARROW,0L);
				usercode_jed=get_user_code_jed();
				if(strcmp(device_name,"XC95144XL-5-TQ144")==0
				 || strcmp(device_name,"XC95144XL-10-TQ144")==0)
				{
					device=ABE;
					strcat(device_name," ABE60 ");
				}
				else if(strcmp(device_name,"XC95144XL-7-TQ144")==0)
				{
					device=SDR;
					strcat(device_name," SDR60 ");
				}
				else
					device=NO_DEVICE;
				if(device==NO_DEVICE)
					Alert(ALERT_JED_DEVICE);
				else
				{
					b=1;
					for(i=0;i<32;i+=8)
					{
						c=(char)(usercode_jed>>i);
						if(!((c>='0' && c<='9') || (c>='A' && c<='Z') || (c>='a' && c<='z')))
						{
							b=0;
							break;
						}
					}
					rsrc_gaddr(R_OBJECT,VERSION_FILE,&op);
					tp=op->ob_spec.tedinfo;
					if(b)
					{
						for(i=3;i>=0;tp->te_ptext[3-i]=code[3-i]=(char)(usercode_jed>>(i<<3)),i--);
						code[4]=0;
					}
					else
					{
						for(i=7;i>=0;i--)
						{
							c=(char)(usercode_jed>>(i<<2));
							if(c<10)
								c+='0';
							else
								c+=('A'-10);
							code[7-i]=c;
						}
						code[8]=0;
						tp->te_ptext[0]=tp->te_ptext[1]=tp->te_ptext[2]=tp->te_ptext[3]='X';
					}
					tp->te_ptext[4]=0;
					strcat(device_name,code);
					rsrc_gaddr(R_OBJECT,FILE,&op);
					tp=op->ob_spec.tedinfo;
					tp->te_ptext=device_name;
					rsrc_gaddr(R_OBJECT,VERIFY,&op);
					op->ob_flags &= ~HIDETREE;
					rsrc_gaddr(R_OBJECT,CODE_VERSION_FI,&op);
					op->ob_flags &= ~HIDETREE;
					rsrc_gaddr(R_OBJECT,VERSION_FI,&op);
					op->ob_flags |= HIDETREE;
					rsrc_gaddr(R_OBJECT,DATE_F,&op);
					op->ob_flags |= HIDETREE;
					rsrc_gaddr(R_OBJECT,VERSION_F,&op);
					op->ob_flags |= HIDETREE;
					rsrc_gaddr(R_OBJECT,DATE_FLASH,&op);
					op->ob_flags |= HIDETREE;
					rsrc_gaddr(R_OBJECT,VERSION_FLASH,&op);
					op->ob_flags |= HIDETREE;
					rsrc_gaddr(R_OBJECT,USERCODE,&op);
					op->ob_flags &= ~HIDETREE;
					objc_draw(Resource,ROOT,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);		
					file_loaded=1;
				}
			}			
			return;
		}
		if(jedec_only || buffer_flash==0)
			Alert(ALERT_JEDEC);
		else
		{		
			memset(buffer_flash,-1,FLASH_SIZE-PARAM_SIZE);
			if((handle=(int)Fopen(path,0))>=0)
			{
				if((size_tos=Fread(handle,FLASH_SIZE-PARAM_SIZE,buffer_flash))>=0)
				{
					p=(unsigned char *)buffer_flash;
					if(size_tos<8 || p[4]!=0 || p[5]!=0xE0 || p[6]!=0 || p[7]!=0x30)
					{ 
						Alert(ALERT_TOS);
						size_tos=0;
					}
					else
						file_loaded=1;
				}
				else
				{
					Alert(ALERT_LOAD);
					size_tos=0;	
				}
				Fclose(handle);
			}
			else
				Alert(ALERT_OPEN);
		}
		graf_mouse(ARROW,0L);
		rsrc_gaddr(R_OBJECT,FILE,&op);
		tp=op->ob_spec.tedinfo;
		if(file_loaded & jed==NULL)
		{
			tp->te_ptext=path;
			rsrc_gaddr(R_OBJECT,DATE_FILE,&op);
			tp=op->ob_spec.tedinfo;
			get_date_os((unsigned char *)buffer_flash+0x18,tp->te_ptext);
			rsrc_gaddr(R_OBJECT,VERSION_FILE,&op);
			tp=op->ob_spec.tedinfo;
			get_version_boot((unsigned char *)buffer_flash+0x80000,tp->te_ptext);
		}
		else
		{
			tp->te_ptext[0]=0;
			rsrc_gaddr(R_OBJECT,DATE_FILE,&op);
			tp=op->ob_spec.tedinfo;
			get_date_os((unsigned char *)0xE00018,tp->te_ptext);
			rsrc_gaddr(R_OBJECT,VERSION_FILE,&op);
			tp=op->ob_spec.tedinfo;
			strcpy(tp->te_ptext,"X.XX");
		}
		objc_draw(Resource,FILE,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
		objc_draw(Resource,DATE_FILE,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
		objc_draw(Resource,VERSION_FILE,MAX_DEPTH,Resource->ob_x,Resource->ob_y,Resource->ob_width,Resource->ob_height);
	}
}

int init(int argc,int *vp,int *wp)
{	
	int work_in[11],work_out[57];
	OBJECT *op;
	TEDINFO *tp;
	GRECT curr,work;
	COOKIE *p;
	long value;
	int i;
	static int led[]={ L1,L2,L3,L4,L5,L6,L7,L8,L9,L10,L11,L12,L13,L14,L15,L16,0 };
	if((ap_id=appl_init())==-1)
		return(4);
	if(jedec_only)
		buffer_flash=0;
	else
	{
		buffer_flash=Mxalloc(FLASH_SIZE-PARAM_SIZE,3);
		if(buffer_flash<=0)
		{
			NOMEMORY;
			return(4);	
		}
	}
	for(i=0;i<10;work_in[i++]=1);
	work_in[i]=2;
	*vp=graf_handle(&i,&i,&i,&i);
	v_opnvwk(work_in,vp,work_out);
	if(!*vp)
		return(1);		/* no workstation */		
	/* load rsc */
	graf_mouse(HOURGLASS,0L);
	wind_update(BEG_UPDATE);
	if(!Load())
	{
		graf_mouse(ARROW,0L);
		wind_update(END_UPDATE);
		NORESOURCE;
		return(1);		/* no rsc */
	}
	if(((p=get_cookie('_MCH'))==0) || (p->v.l!=0x30000))	/* Falcon */
	{
		Alert(ALERT_FALCON);
		return(2);		/* no Falcon */
	}
	wind_get(DESK,WF_WORKXYWH,aGrect(&curr));
	shrink.g_x=curr.g_w/2;
	shrink.g_y=curr.g_h/2;
	shrink.g_w=1;
	shrink.g_h=1;
	form_center(Resource,aGrect(&work));
	for(i=0;led[i];Resource[led[i++]].ob_state &= ~SELECTED);	
	rsrc_gaddr(R_OBJECT,VERIFY,&op);
	if(jedec_only)
	{
		op->ob_flags &= ~HIDETREE;
		rsrc_gaddr(R_OBJECT,CODE_VERSION_FI,&op);
		op->ob_flags &= ~HIDETREE;
		rsrc_gaddr(R_OBJECT,VERSION_FI,&op);
		op->ob_flags |= HIDETREE;
		rsrc_gaddr(R_OBJECT,DATE_F,&op);
		op->ob_flags |= HIDETREE;
		rsrc_gaddr(R_OBJECT,VERSION_F,&op);
		op->ob_flags |= HIDETREE;
		rsrc_gaddr(R_OBJECT,DATE_FLASH,&op);
		op->ob_flags |= HIDETREE;
		rsrc_gaddr(R_OBJECT,VERSION_FLASH,&op);
		op->ob_flags |= HIDETREE;
		rsrc_gaddr(R_OBJECT,USERCODE,&op);
		op->ob_flags &= ~HIDETREE;				
		if(argc<=1)
			Alert(ALERT_CT60);
	}
	else
	{
		op->ob_flags |= HIDETREE;
		rsrc_gaddr(R_OBJECT,CODE_VERSION_FI,&op);
		op->ob_flags |= HIDETREE;
		rsrc_gaddr(R_OBJECT,VERSION_FI,&op);
		op->ob_flags &= ~HIDETREE;
		rsrc_gaddr(R_OBJECT,DATE_F,&op);
		op->ob_flags &= ~HIDETREE;
		rsrc_gaddr(R_OBJECT,VERSION_F,&op);
		op->ob_flags &= ~HIDETREE;
		rsrc_gaddr(R_OBJECT,DATE_FLASH,&op);
		op->ob_flags &= ~HIDETREE;
		rsrc_gaddr(R_OBJECT,VERSION_FLASH,&op);
		op->ob_flags &= ~HIDETREE;
		rsrc_gaddr(R_OBJECT,USERCODE,&op);
		op->ob_flags |= HIDETREE;
	}
	rsrc_gaddr(R_OBJECT,FILE,&op);
	tp=op->ob_spec.tedinfo;
	tp->te_ptext[0]=0;
	rsrc_gaddr(R_OBJECT,DATE_FILE,&op);
	tp=op->ob_spec.tedinfo;
	get_date_os((unsigned char *)0xE00018,tp->te_ptext); /* TOS in ROM date */
	rsrc_gaddr(R_OBJECT,VERSION_FILE,&op);
	tp=op->ob_spec.tedinfo;
	strcpy(tp->te_ptext,"X.XX");
	rsrc_gaddr(R_OBJECT,USERCODE,&op);
	tp=op->ob_spec.tedinfo;
	strcpy(tp->te_ptext,"XXXX");
	wind_calc(WC_BORDER,WINDOW,Grect(&work),aGrect(&curr));
	if((*wp=wind_create(WINDOW,Grect(&curr)))==-1)
	{	
		graf_mouse(ARROW,0L);
		wind_update(END_UPDATE);
		NOWINDOW;
		return(3);		/* no window available */
	}
	wind_set(*wp,WF_NAME," FLASH TOOL CT60 ",0,0);
	graf_growbox(Grect(&shrink),Grect(&curr));
	wind_open(*wp,Grect(&curr));
	graf_mouse(ARROW,0L);
	wind_update(END_UPDATE);
	w_icon=0;
	Pdomain(1);         /* long names */
	return(0);
}

void term(int code,int vh,int wh)
{	
	GRECT curr;
	switch(code)
	{
	case 0:				/* normal end */
		wind_get(wh,WF_CURRXYWH,aGrect(&curr));
		wind_close(wh);
		graf_shrinkbox(Grect(&shrink),Grect(&curr));
		wind_delete(wh);
	case 3:				/* no window */
	case 2:				/* no Falcon */
		v_clsvwk(vh);
	case 1:				/* no workstation */
		if(code)
			wind_update(END_UPDATE);
		appl_exit();
	case 4:				/* other */
		if(buffer_flash>0)
			Mfree(buffer_flash);
		break;
	}
}

int rc_intersect(GRECT *r1,GRECT *r2)
{
	int x,y,w,h;
	x=max(r2->g_x,r1->g_x);
	y=max(r2->g_y,r1->g_y);
	w=min(r2->g_x+r2->g_w,r1->g_x+r1->g_w);
	h=min(r2->g_y+r2->g_h,r1->g_y+r1->g_h);
	r2->g_x=x;
	r2->g_y=y;
	r2->g_w=w-x;
	r2->g_h=h-y;
	return((w>x) && (h>y));
}

int max(int a,int b)
{
	return((a>b) ? a : b);
}

int min(int a,int b)	
{
	return((a<b) ? a : b);
}

void get_date_file(unsigned short date_file,char *date_format)
{
	COOKIE *p;
	unsigned char day,month,year1,year2;
	long value;
	value=0x112E;
	if((p=get_cookie('_IDT'))!=0)
		value=p->v.l;
	day=(unsigned char)(date_file&31);                         
	month=(unsigned char)((date_file>>5)&15);
	year1=(unsigned char)(((date_file>>9)+1980)/100);
	year2=(unsigned char)(((date_file>>9)+1980)%100);
	if(day>31 || month>12 || year1>99 || year2>99)
		day=month=year1=year2=0;
	switch((value>>8)&3) /* Date Format */
	{
		case 0:          /* MMDDYY */
			date_format[0]=(month/10)+'0';
			date_format[1]=(month%10)+'0';
			date_format[2]=date_format[5]='//';
			date_format[3]=(day/10)+'0';
			date_format[4]=(day%10)+'0';
			date_format[6]=(year1/10)+'0';
			date_format[7]=(year1%10)+'0';
			date_format[8]=(year2/10)+'0';
			date_format[9]=(year2%10)+'0';
			break;
		case 1:          /* DDMMYY */
			date_format[0]=(day/10)+'0';
			date_format[1]=(day%10)+'0';
			date_format[2]=date_format[5]='//';
			date_format[3]=(month/10)+'0';
			date_format[4]=(month%10)+'0';
			date_format[6]=(year1/10)+'0';
			date_format[7]=(year1%10)+'0';
			date_format[8]=(year2/10)+'0';
			date_format[9]=(year2%10)+'0';
			break;
		case 2:          /* YYMMDD */
			date_format[0]=(year1/10)+'0';
			date_format[1]=(year1%10)+'0';
			date_format[2]=(year2/10)+'0';
			date_format[3]=(year2%10)+'0';
			date_format[4]=date_format[7]='//';
			date_format[5]=(month/10)+'0';
			date_format[6]=(month%10)+'0';
			date_format[8]=(day/10)+'0';
			date_format[9]=(day%10)+'0';
			break;
		case 3:          /* YYDDMM */
			date_format[0]=(year1/10)+'0';
			date_format[1]=(year1%10)+'0';
			date_format[2]=(year2/10)+'0';
			date_format[3]=(year2%10)+'0';
			date_format[4]=date_format[7]='//';
			date_format[5]=(day/10)+'0';
			date_format[6]=(day%10)+'0';
			date_format[8]=(month/10)+'0';
			date_format[9]=(month%10)+'0';
			break;	
	}
	date_format[10]=0;
}

void get_date_os(unsigned char *date_os,char *date_format)
{
	COOKIE *p;
	unsigned char day,month,year1,year2;
	long value;
	value=0x112E;
	if((p=get_cookie('_IDT'))!=0)
		value=p->v.l;
	month=((date_os[0]>>4)*10)+(date_os[0]&0xF);
	day=((date_os[1]>>4)*10)+(date_os[1]&0xF);
	year1=((date_os[2]>>4)*10)+(date_os[2]&0xF);
	year2=((date_os[3]>>4)*10)+(date_os[3]&0xF);
	if(day>31 || month>12 || year1>99 || year2>99)
		day=month=year1=year2=0;
	switch((value>>8)&3) /* Date Format */
	{
		case 0:          /* MMDDYY */
			date_format[0]=(month/10)+'0';
			date_format[1]=(month%10)+'0';
			date_format[2]=date_format[5]='//';
			date_format[3]=(day/10)+'0';
			date_format[4]=(day%10)+'0';
			date_format[6]=(year1/10)+'0';
			date_format[7]=(year1%10)+'0';
			date_format[8]=(year2/10)+'0';
			date_format[9]=(year2%10)+'0';
			break;
		case 1:          /* DDMMYY */
			date_format[0]=(day/10)+'0';
			date_format[1]=(day%10)+'0';
			date_format[2]=date_format[5]='//';
			date_format[3]=(month/10)+'0';
			date_format[4]=(month%10)+'0';
			date_format[6]=(year1/10)+'0';
			date_format[7]=(year1%10)+'0';
			date_format[8]=(year2/10)+'0';
			date_format[9]=(year2%10)+'0';
			break;
		case 2:          /* YYMMDD */
			date_format[0]=(year1/10)+'0';
			date_format[1]=(year1%10)+'0';
			date_format[2]=(year2/10)+'0';
			date_format[3]=(year2%10)+'0';
			date_format[4]=date_format[7]='//';
			date_format[5]=(month/10)+'0';
			date_format[6]=(month%10)+'0';
			date_format[8]=(day/10)+'0';
			date_format[9]=(day%10)+'0';
			break;
		case 3:          /* YYDDMM */
			date_format[0]=(year1/10)+'0';
			date_format[1]=(year1%10)+'0';
			date_format[2]=(year2/10)+'0';
			date_format[3]=(year2%10)+'0';
			date_format[4]=date_format[7]='//';
			date_format[5]=(day/10)+'0';
			date_format[6]=(day%10)+'0';
			date_format[8]=(month/10)+'0';
			date_format[9]=(month%10)+'0';
			break;	
	}
	date_format[10]=0;
}

void get_version_boot(unsigned char *version_boot,char *version_format)
{
	version_format[0]=(version_boot[0] & 0xF)+'0';
	version_format[1]='.';
	version_format[2]=((version_boot[1]>>4) & 0x0F)+'0';
	version_format[3]=(version_boot[1] & 0xF)+'0';
	version_format[4]=0;
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

void hndl_dd(short pipe_num)
{
	long fd,size;
	char obname[DD_NAMEMAX],ext[5],fname[PATH_MAX];
	static char ourexts[DD_EXTSIZE]="ARGS.TXT";
	char *cmdline;
	fd=dd_open(pipe_num,ourexts);
	if(fd<0)
		return;
	do
	{
		if(!dd_getheader(fd,obname,fname,ext,&size))
		{
			dd_close(fd);
			return;
		}
		if(!strncmp(ext,"ARGS",4))
		{
			cmdline=Mxalloc(size+1,0x23);
			if(!cmdline)
			{
				dd_reply(fd,DD_LEN);
				continue;
			}
			dd_reply(fd,DD_OK);
			Fread((short)fd,size,cmdline);
			dd_close(fd);
			cmdline[size]=0;
			wind_update(BEG_UPDATE);
			load_file(cmdline);
			Button(PROG);
			wind_update(END_UPDATE);
			Mfree(cmdline);
			return;
		}
	}
	while(dd_reply(fd,DD_EXT));
}

long dd_open_pipe(short pnum)
{
	char pipename[20];
	char ext[3];
	long fd;
	ext[0]=(char)((pnum & 0xff00)>>8);
	ext[1]=(char)(pnum & 0xff);
	ext[2]=0;
	strcpy(pipename,"U:\\PIPE\\DRAGDROP.");
	strcat(pipename,ext);
	if((fd=Fopen(pipename,2))>0)
		oldsig=signal(SIGPIPE,(__Sigfunc)SIG_IGN);
	return(fd);
}

long dd_open(short pipe_num,unsigned char *extlist)
{
	long fd;
	unsigned char outbuf[DD_EXTSIZE+2];
	fd=dd_open_pipe(pipe_num);
	if(fd<0)
		return(fd);
	memset(outbuf,0,DD_EXTSIZE+2);
	outbuf[0]=DD_OK;
	strncpy(outbuf+1,extlist,DD_EXTSIZE);
	if(Fwrite((short)fd,DD_EXTSIZE+1,outbuf) != DD_EXTSIZE+1)
	{
		dd_close(fd);
		return(-1);
	}
	return(fd);
}

void dd_close(long fd)
{
	signal(SIGPIPE,oldsig);
	Fclose((short)fd);
}

int dd_getheader(long fd,unsigned char *obname,unsigned char *fname,unsigned char *datatype,long *size)
{
	short hdrlen,cnt,slen;
	unsigned char buf[MAX_PATH+DD_NAMEMAX+1];
	unsigned char *fp;
	if(Fread((short)fd,2,&hdrlen)!=2)
		return(0);
	if(hdrlen<8)
		return(0);
	if(Fread((short)fd,4,datatype) != 4)
		return(0);
	datatype[4]=0;
	if(Fread((short)fd,4,size)!=4)
		return(0);
	hdrlen-=8;
	cnt=hdrlen;
	if(cnt>MAX_PATH+DD_NAMEMAX)
		cnt=MAX_PATH+DD_NAMEMAX;
	if(Fread((short)fd,cnt,buf)!=cnt)
		return(0);
	buf[MAX_PATH+DD_NAMEMAX]=0;
	hdrlen-=cnt;
	slen=(short)strlen(buf);
	if(slen<DD_NAMEMAX)
		strcpy(obname, buf);
	if(slen<MAX_PATH+DD_NAMEMAX)
	{
		fp=buf+slen+1;
		slen=(short)strlen(fp);
		if(slen<MAX_PATH)
			strcpy(fname,fp);
	}
	while(hdrlen)
	{
		cnt=hdrlen;
		if(cnt>sizeof(buf))
			hdrlen=(short)sizeof(buf);
		Fread((short)fd,cnt,buf);
		hdrlen-=cnt;
	}
	return(1);
}

int dd_reply(long fd,unsigned char ack)
{
	if(Fwrite((short)fd,1,&ack)!=1)
	{
		dd_close(fd);
		return(0);
	}
	return(1);
}

