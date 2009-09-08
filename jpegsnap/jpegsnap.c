	
/* JPEG SNAPSHOT */
/* Didier MEQUIGNON - v1.01 - September 2009 */

#include <mint/osbind.h>
#include <mint/falcon.h>
#include <stdio.h>
#include "jinclude.h"
#include "jpeglib.h"
#include <gem.h>
#include "ct60.h"
#include "pcixbios.h"
#include "radeon.h"

#ifndef Vsetscreen
#ifdef VsetScreen
#define Vsetscreen VsetScreen
#else
#warning Bad falcon.h
#endif
#endif

#ifndef Vsetmode
#ifdef VsetMode
#define Vsetmode VsetMode
#else
#warning Bad falcon.h
#endif
#endif

#define _dumpflg (((short *) 0x4EEL)) 
#define dump_vec (((void (**)()) 0x502L))

#define ITIME 1000L	/* mS */

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

void rsc_calc(OBJECT *tree);
OBJECT* adr_tree(int num_tree);
int form_xalert(int fo_xadefbttn,char *fo_xastring,long time_out,void (*call)());
void (*function)(void);
int save_jpeg(char *filename,char *src,int incr_src,int image_width,int image_height,int quality);
void init_alt_help(void);
int find_radeon(void);
COOKIE *fcookie(void);
COOKIE *ncookie(COOKIE *p);
COOKIE *get_cookie(long id);

/* global variables */

short start_lang,gr_hwchar,gr_hhchar,gr_hwbox,gr_hhbox;
short	vdi_handle,work_in[11]={1,1,1,1,1,1,1,1,1,1,2},work_out[57],work_extend[57];
short aes_global[15];
int start_snap, radeon;
long second_screen;

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
	{ (short *)0L,4,32,0,0,1 },
	{ (short *)1L,4,32,0,0,4 }, 
	{ (short *)2L,4,32,0,0,2 } };
	
TEDINFO rs_tedinfo[] = {
	{ (char *)0L,(char *)1L,(char *)2L,IBM,0,2,0x1480,0,-1,17,1 } };

OBJECT rs_object[] = {
	{ -1,1,12,G_BOX,OF_FL3DBAK,OS_OUTLINED,{0x21100L},0,0,42,10 },
	{ 2,-1,-1,G_BOXTEXT,OF_FL3DBAK,OS_NORMAL,{0L},0,0,42,1 },
	{ 3,-1,-1,G_IMAGE,OF_NONE,OS_NORMAL,{1L},1,2,4,2 },
	{ 4,-1,-1,G_IMAGE,OF_NONE,OS_NORMAL,{2L},1,2,4,2 },
	{ 5,-1,-1,G_IMAGE,OF_NONE,OS_NORMAL,{3L},1,2,4,2 },
	{ 6,-1,-1,G_STRING,OF_NONE,OS_NORMAL,{3L},1,2,40,1 },
	{ 7,-1,-1,G_STRING,OF_NONE,OS_NORMAL,{4L},1,3,40,1 },
	{ 8,-1,-1,G_STRING,OF_NONE,OS_NORMAL,{5L},1,4,40,1 },
	{ 9,-1,-1,G_STRING,OF_NONE,OS_NORMAL,{6L},1,5,40,1 },
	{ 10,-1,-1,G_STRING,OF_NONE,OS_NORMAL,{7L},1,6,40,1 },
	{ 11,-1,-1,G_BUTTON,OF_SELECTABLE|OF_DEFAULT|OF_EXIT|OF_FL3DIND|OF_FL3DBAK,OS_NORMAL,{8L},1,8,10,1 },
	{ 12,-1,-1,G_BUTTON,OF_SELECTABLE|OF_EXIT|OF_FL3DIND|OF_FL3DBAK,OS_NORMAL,{9L},12,8,10,1 },
	{ 0,-1,-1,G_BUTTON,OF_SELECTABLE|OF_EXIT|OF_LASTOB|OF_FL3DIND|OF_FL3DBAK,OS_NORMAL,{10L},23,8,10,1 } };

unsigned short pic_note[]={
 0x0003,0xC000,0x0006,0x6000,0x000D,0xB000,0x001B,0xD800,
 0x0037,0xEC00,0x006F,0xF600,0x00DC,0x3B00,0x01BC,0x3D80,
 0x037C,0x3EC0,0x06FC,0x3F60,0x0DFC,0x3FB0,0x1BFC,0x3FD8,
 0x37FC,0x3FEC,0x6FFC,0x3FF6,0xDFFC,0x3FFB,0xBFFC,0x3FFD,
 0xBFFC,0x3FFD,0xDFFC,0x3FFB,0x6FFC,0x3FF6,0x37FC,0x3FEC,
 0x1BFF,0xFFD8,0x0DFF,0xFFB0,0x06FC,0x3F60,0x037C,0x3EC0,
 0x01BC,0x3D80,0x00DC,0x3B00,0x006F,0xF600,0x0037,0xEC00,
 0x001B,0xD800,0x000D,0xB000,0x0006,0x6000,0x0003,0xC000 };

unsigned short pic_wait[]={
 0x3FFF,0xFFFC,0xC000,0x0003,0x9FFF,0xFFF9,0xBFFF,0xFFFD,
 0xDFF8,0x3FFB,0x5FE0,0x0FFA,0x6FC0,0x07F6,0x2F83,0x83F4,
 0x3787,0xC3EC,0x1787,0xC3E8,0x1BFF,0x83D8,0x0BFF,0x07D0,
 0x0DFE,0x0FB0,0x05FC,0x1FA0,0x06FC,0x3F60,0x02FC,0x3F40,
 0x037C,0x3EC0,0x017C,0x3E80,0x01BF,0xFD80,0x00BF,0xFD00,
 0x00DC,0x3B00,0x005C,0x3A00,0x006C,0x3600,0x002F,0xF400,
 0x0037,0xEC00,0x0017,0xE800,0x001B,0xD800,0x000B,0xD000,
 0x000D,0xB000,0x0005,0xA000,0x0006,0x6000,0x0003,0xC000 };

unsigned short pic_stop[]={
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

#define MAX_PATH 1024
#define MAX_NAME 256

int main(void)
{
	static char path[MAX_PATH],name_sel[MAX_NAME];
	int end=0;
	short app_id,event,ret,whandle;
	short message[8];
	GRECT rect={0,0,0,0};
	GRECT work;
	char name[]="C:\\snap_00.jpg";
	int i,j,count=0;
	short mouse[4];
	OBJECT *alert_tree;
	TEDINFO *t_edinfo;
	BITBLK *b_itblk;
	COOKIE *p;
	static MFDB mfdb_src,mfdb_dest;
	char *buffer;
	long incr,size;
	short pxy[8];
	start_lang=1;
	if((p=get_cookie('_AKP'))!=0)
	{
		if((p->v.c[2]==FRA) || (p->v.c[2]==SWF))
			start_lang=0;
	}
	if((app_id=appl_init())<=0)
		return(-1);		
	vdi_handle=graf_handle(&gr_hwchar,&gr_hhchar,&gr_hwbox,&gr_hhbox);
	v_opnvwk(work_in,&vdi_handle,work_out);
	if(vdi_handle>0)
		vq_extnd(vdi_handle,1,work_extend);
	rsc_calc(rs_object);
	if((alert_tree=adr_tree(TREE1))!=0)
	{
		t_edinfo=rs_object[ALERTTITLE].ob_spec.tedinfo=&rs_tedinfo[0];
		if(!start_lang)
			t_edinfo->te_ptext="JPEG SNAPSHOT";
		else
			t_edinfo->te_ptext="JPEG SNAPSHOT";		
		t_edinfo->te_ptmplt=t_edinfo->te_pvalid="";	
		b_itblk=alert_tree[ALERTNOTE].ob_spec.bitblk=&rs_bitblk[0];
		b_itblk->bi_pdata=(short *)pic_note;
		b_itblk=alert_tree[ALERTWAIT].ob_spec.bitblk=&rs_bitblk[1];
		b_itblk->bi_pdata=(short *)pic_wait;
		b_itblk=alert_tree[ALERTSTOP].ob_spec.bitblk=&rs_bitblk[2];
		b_itblk->bi_pdata=(short *)pic_stop;
	}
	name_sel[0]=0;
	path[0]=Dgetdrv()+'A'; path[1]=':'; path[2]='\\'; path[3]=0;
	start_snap=radeon=0;
	second_screen=0;
	if((get_cookie('CT60') || get_cookie('_CF_'))
	 && get_cookie('_PCI') && find_radeon())
	{
		Vsetscreen(&second_screen, Vsetmode(-1) & 0xFFFF, 0x564E, CMD_ALLOCPAGE);
    if(second_screen)
			radeon=1;
	}
	Supexec(init_alt_help);
	menu_register(app_id,"  JPEG Snapshot");
	wind_get(0,WF_WORKXYWH,&work.g_x,&work.g_y,&work.g_w,&work.g_h);
	while(!end)
	{
		event=evnt_multi(MU_MESAG|MU_TIMER,0,0,0,0,rect.g_x,rect.g_y,rect.g_w,rect.g_h,
		 0,rect.g_x,rect.g_y,rect.g_w,rect.g_h,message,ITIME,
		 &mouse[0],&mouse[1],&mouse[2],&mouse[3],&ret,&ret);
		if(event & MU_TIMER)
		{
			if(start_snap && work_extend[4]>=16) /* (near) true color */
			{
				count++;
				if(count>99)
					count=0;
				name[8]=(char)(count/10)|'0';
				name[9]=(char)(count%10)|'0';
				if(radeon)
					mfdb_src.fd_addr=(void *)second_screen;
				else
					mfdb_src.fd_addr=(void *)0; /* screen */
				mfdb_src.fd_w=mfdb_dest.fd_w=work_out[0]+1;
				mfdb_src.fd_h=mfdb_dest.fd_h=work_out[1]+1;
				mfdb_src.fd_wdwidth=mfdb_dest.fd_wdwidth=(mfdb_src.fd_w+15)>>4;
				mfdb_src.fd_stand=mfdb_dest.fd_stand=0;
				mfdb_src.fd_nplanes=mfdb_dest.fd_nplanes=work_extend[4];
				mfdb_src.fd_r1=mfdb_dest.fd_r1=0;
				mfdb_src.fd_r2=mfdb_dest.fd_r2=0;
				mfdb_src.fd_r3=mfdb_dest.fd_r3=0;
				incr=(unsigned long)mfdb_dest.fd_wdwidth*2*(unsigned long)mfdb_dest.fd_nplanes;
				size=incr*(unsigned long)mfdb_dest.fd_h;
				buffer=(char *)Mxalloc(size,3);
				mfdb_dest.fd_addr=(void *)buffer;
				if(buffer && vdi_handle>0)
				{
					if(radeon)
						wind_update(BEG_UPDATE);	
					graf_mouse(256,(const MFORM *)0);
					pxy[0]=pxy[1]=pxy[4]=pxy[5]=0;
					pxy[2]=pxy[6]=work_out[0];
					pxy[3]=pxy[7]=work_out[1];
					vro_cpyfm(vdi_handle,S_ONLY,pxy,&mfdb_src,&mfdb_dest);
					graf_mouse(257,(const MFORM *)0);
					if(!radeon)
						wind_update(BEG_UPDATE);	
					graf_mouse(2,(const MFORM *)0);
					save_jpeg(name,buffer,(int)incr,(int)work_out[0]+1,(int)work_out[1]+1,80);
					graf_mouse(0,(const MFORM *)0);
					wind_update(END_UPDATE);
    			Mfree(buffer);
    		}
				start_snap=0;
			}
		}
		if(event & MU_MESAG)
		{
			switch((unsigned int)message[0])
			{
				case AC_OPEN:
					if(start_lang)
						ret=form_xalert(1,"[2][          JPEG SNAPSHOT           |  V1.01 MEQUIGNON Didier 09/2009  |This software is based on the work|of the Independent JPEG Group|Select you choice...][Cancel|Select|Window]",ITIME*10L,0L);
					else
						ret=form_xalert(1,"[2][          JPEG SNAPSHOT           |  V1.01 MEQUIGNON Didier 09/2009  |Ce programme est bas‚ sur le|travail du Independent JPEG Group|S‚lectionnez votre choix...][Abandon|S‚lection|Fenˆtre]",ITIME*10L,0L);
					if(ret==1)
						break;
					if(work_extend[4]<16)
					{
						if(start_lang)
							form_xalert(1,"[1][This program works|only in (near) true color!][Cancel]",ITIME*10L,0L);
						else
							form_xalert(1,"[1][Ce programme fonctionne seulement|en 65K ou 16M de couleurs !][Abandon]",ITIME*10L,0L);
						break;
					}
					wind_update(BEG_UPDATE);
					if(ret==2)
					{
						wind_update(BEG_MCTRL);
						graf_mouse(3,(const MFORM *)0);
						do
							graf_mkstate(&mouse[0],&mouse[1],&mouse[2],&mouse[3]);
						while(!mouse[2]);
						rect.g_x=mouse[0];
						rect.g_y=mouse[1];
						graf_rubberbox(mouse[0],mouse[1],-work_out[0],-work_out[1],&rect.g_w,&rect.g_h);
						if(rect.g_w<0)
						{
							rect.g_x+=rect.g_w;
							rect.g_w=-rect.g_w;
						}
						if(rect.g_h<0)
						{
							rect.g_y+=rect.g_h;
							rect.g_h=-rect.g_h;
						}
						graf_mouse(0,(const MFORM *)0);
						wind_update(END_MCTRL);
					}
					else
					{
						wind_get(0,WF_TOP,&whandle,&rect.g_y,&rect.g_w,&rect.g_h);
						if(whandle<=0)
						{
							wind_update(END_UPDATE);
							break;
						}
						wind_get(whandle,WF_WORKXYWH,&rect.g_x,&rect.g_y,&rect.g_w,&rect.g_h);
					}
					mfdb_src.fd_addr=(void *)0; /* screen */
					mfdb_src.fd_w=work_out[0]+1;
					mfdb_src.fd_h=work_out[1]+1;
					mfdb_src.fd_wdwidth=(mfdb_src.fd_w+15)>>4;
					mfdb_src.fd_stand=mfdb_dest.fd_stand=0;
					mfdb_src.fd_nplanes=mfdb_dest.fd_nplanes=work_extend[4];
					mfdb_dest.fd_w=rect.g_w;
					mfdb_dest.fd_h=rect.g_h;
					mfdb_dest.fd_wdwidth=(mfdb_dest.fd_w+15)>>4;
					mfdb_src.fd_r1=mfdb_dest.fd_r1=0;
					mfdb_src.fd_r2=mfdb_dest.fd_r2=0;
					mfdb_src.fd_r3=mfdb_dest.fd_r3=0;
					incr=(unsigned long)mfdb_dest.fd_wdwidth*2*(unsigned long)mfdb_dest.fd_nplanes;
					size=incr*(unsigned long)mfdb_dest.fd_h;
					buffer=(char *)Mxalloc(size,3);
					mfdb_dest.fd_addr=(void *)buffer;
					if(!buffer)
					{
						wind_update(END_UPDATE);
						break;
					}
					graf_mouse(256,(const MFORM *)0);
					pxy[0]=rect.g_x;
					pxy[1]=rect.g_y;
					pxy[2]=rect.g_x+rect.g_w-1;
					pxy[3]=rect.g_y+rect.g_h-1;
					pxy[4]=pxy[5]=0;
					pxy[6]=rect.g_w-1;
					pxy[7]=rect.g_h-1;
					if(vdi_handle>0)
						vro_cpyfm(vdi_handle,S_ONLY,pxy,&mfdb_src,&mfdb_dest);
					graf_mouse(257,(const MFORM *)0);			
					wind_update(END_UPDATE);
					i=j=0;
    			while(path[i])
    			{
    				if(path[i]=='\\')
    					j=i+1;
    				i++;
    			}
					path[j++]='*'; path[j++]='.'; path[j++]='J'; path[j++]='P'; path[j++]='G'; path[j]=0;
					fsel_input(path,name_sel,&ret);
					if(ret==1)
					{
						i=j=0;
	    			while(path[i])
	    			{
	    				if(path[i]=='\\')
	    					j=i+1;
	    				i++;
	    			}
	    			path[j]=0;
	    			strcat(path,name_sel);		
						graf_mouse(2,(const MFORM *)0);
						save_jpeg(path,buffer,(int)incr,(int)rect.g_w,(int)rect.g_h,80);
						graf_mouse(0,(const MFORM *)0);
    			}
    			Mfree(buffer);
					break;
				case AP_TERM:
					end=1;
					break;				
			}
		}
	}
	if(vdi_handle>0)
		v_clsvwk(vdi_handle);
	appl_exit();
	return(0);
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
	while(!(tree[i++].ob_flags & OF_LASTOB));
}

OBJECT* adr_tree(int num_tree)
{
	register int i,tree;
	if(!num_tree)
		return(rs_object);
	for(i=tree=0;i<NUM_OBS;i++)
	{
		if(rs_object[i].ob_flags & OF_LASTOB)
		{
			tree++;
			if(tree==num_tree)
				return(&rs_object[i+1]);
		}
	}
	return(0L);
}

int form_xalert(int fo_xadefbttn,char *fo_xastring,long time_out,void (*call)())
{
	register int i,j,w,max_length_lines,max_length_buttons;
	register char *p;
	int flag_img,nb_lines,nb_buttons;
	short answer,event,objc_clic,key,nclicks,new_objc;
	GRECT rect,kl_rect;
	OBJECT *alert_tree;
	TEDINFO *t_edinfo;
	static MFDB mfdb_src,mfdb_dest;
	char *buffer;
	long size;
	short pxy[8];
	short mouse[4];
	short msg[8];
	char line[5][61];
	char button[3][21];
	if((alert_tree=adr_tree(TREE1))==0)
		return(0);
	alert_tree[ALERTB1].ob_state &= ~OS_SELECTED;
	alert_tree[ALERTB2].ob_state &= ~OS_SELECTED;
	alert_tree[ALERTB3].ob_state &= ~OS_SELECTED;
	switch(fo_xadefbttn)
	{
		case 2:
			alert_tree[ALERTB1].ob_flags &= ~OF_DEFAULT;
			alert_tree[ALERTB2].ob_flags |= OF_DEFAULT;
			alert_tree[ALERTB3].ob_flags &= ~OF_DEFAULT;
			break;
		case 3:
			alert_tree[ALERTB1].ob_flags &= ~OF_DEFAULT;
			alert_tree[ALERTB2].ob_flags &= ~OF_DEFAULT;
			alert_tree[ALERTB3].ob_flags |= OF_DEFAULT;
			break;
		default:
			alert_tree[ALERTB1].ob_flags |= OF_DEFAULT;
			alert_tree[ALERTB2].ob_flags &= ~OF_DEFAULT;
			alert_tree[ALERTB3].ob_flags &= ~OF_DEFAULT;			
			break;
	}
	if(fo_xastring[0]!='[' || fo_xastring[2]!=']' || fo_xastring[3]!='[')
		return(0);				/* error */
	switch(fo_xastring[1])
	{
		case '1':
			alert_tree[ALERTNOTE].ob_flags &= ~OF_HIDETREE;
			alert_tree[ALERTWAIT].ob_flags |= OF_HIDETREE;
			alert_tree[ALERTSTOP].ob_flags |= OF_HIDETREE;
			flag_img=1;
			break;
		case '2':
			alert_tree[ALERTNOTE].ob_flags |= OF_HIDETREE;
			alert_tree[ALERTWAIT].ob_flags &= ~OF_HIDETREE;
			alert_tree[ALERTSTOP].ob_flags |= OF_HIDETREE;
			flag_img=1;
			break;
		case '3':
			alert_tree[ALERTNOTE].ob_flags |= OF_HIDETREE;
			alert_tree[ALERTWAIT].ob_flags |= OF_HIDETREE;
			alert_tree[ALERTSTOP].ob_flags &= ~OF_HIDETREE;		
			flag_img=1;
			break;			
		default:
			alert_tree[ALERTNOTE].ob_flags |= OF_HIDETREE;
			alert_tree[ALERTWAIT].ob_flags |= OF_HIDETREE;
			alert_tree[ALERTSTOP].ob_flags |= OF_HIDETREE;		
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
			alert_tree[ALERTLINE1+i].ob_flags &= ~OF_HIDETREE;
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
			alert_tree[ALERTLINE1+i].ob_flags |= OF_HIDETREE;
			line[i][0]=0;
		}			
	}
	fo_xastring++;
	for(i=0;i<3;i++)						/* copy texts of buttons */
	{
		if(i<nb_buttons)
		{
			alert_tree[ALERTB1+i].ob_flags &= ~OF_HIDETREE;
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
			alert_tree[ALERTB1+i].ob_flags |= OF_HIDETREE;
			button[i][0]=0;
		}
	}
	wind_update(BEG_UPDATE);
	form_center(alert_tree,&rect.g_x,&rect.g_y,&rect.g_w,&rect.g_h);
	mfdb_src.fd_addr=(void *)0; /* screen */
	mfdb_src.fd_w=work_out[0]+1;
	mfdb_src.fd_h=work_out[1]+1;
	mfdb_src.fd_wdwidth=(mfdb_src.fd_w+15)>>4;
	mfdb_src.fd_stand=mfdb_dest.fd_stand=0;
	mfdb_src.fd_nplanes=mfdb_dest.fd_nplanes=work_extend[4];
	mfdb_dest.fd_w=rect.g_w;
	mfdb_dest.fd_h=rect.g_h;
	mfdb_dest.fd_wdwidth=(mfdb_dest.fd_w+15)>>4;
	mfdb_src.fd_r1=mfdb_dest.fd_r1=0;
	mfdb_src.fd_r2=mfdb_dest.fd_r2=0;
	mfdb_src.fd_r3=mfdb_dest.fd_r3=0;
	size=(unsigned long)mfdb_dest.fd_wdwidth*2*(unsigned long)mfdb_dest.fd_nplanes;
	size*=(unsigned long)mfdb_dest.fd_h;
	buffer=(char *)Mxalloc(size,3);
	mfdb_dest.fd_addr=(void *)buffer;
	if(buffer && vdi_handle>0)
	{
		graf_mouse(256,(const MFORM *)0);
		pxy[0]=rect.g_x;
		pxy[1]=rect.g_y;
		pxy[2]=rect.g_x+rect.g_w-1;
		pxy[3]=rect.g_y+rect.g_h-1;
		pxy[4]=pxy[5]=0;
		pxy[6]=rect.g_w-1;
		pxy[7]=rect.g_h-1;
		vro_cpyfm(vdi_handle,S_ONLY,pxy,&mfdb_src,&mfdb_dest);
		graf_mouse(257,(const MFORM *)0);		
	}
	else
		form_dial(FMD_START,kl_rect.g_x,kl_rect.g_y,kl_rect.g_w,kl_rect.g_h,
		 rect.g_x,rect.g_y,rect.g_w,rect.g_h);
	objc_draw(alert_tree,0,MAX_DEPTH,rect.g_x,rect.g_y,rect.g_w,rect.g_h);
	wind_update(BEG_MCTRL);
	answer=0;
	do
	{	event=(MU_KEYBD|MU_BUTTON);
		if(time_out!=0)
			event|=MU_TIMER;	
		event=evnt_multi(event,2,1,1,0,rect.g_x,rect.g_y,rect.g_w,rect.g_h,
		 0,rect.g_x,rect.g_y,rect.g_w,rect.g_h,msg,time_out,&mouse[0],&mouse[1],&mouse[2],&mouse[3],&key,&nclicks);
		if(event & MU_TIMER)
			answer=fo_xadefbttn;
		if(event & MU_BUTTON)
		{
			if((objc_clic=objc_find(alert_tree,0,MAX_DEPTH,mouse[0],mouse[1]))>=0)
			{
				if(!form_button(alert_tree,objc_clic,nclicks,&new_objc))
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
			if(!form_keybd(alert_tree,0,0,key,&new_objc,&key))
				answer=fo_xadefbttn;				
		}		
	}
	while(!answer);
	if(call)
	{
		function=call;
		(*function)();
	}
	wind_update(END_MCTRL);
	if(buffer && vdi_handle>0)
	{
		graf_mouse(256,(const MFORM *)0);
		pxy[0]=pxy[1]=0;
		pxy[2]=rect.g_w-1;
		pxy[3]=rect.g_h-1;
		pxy[4]=rect.g_x;
		pxy[5]=rect.g_y;
		pxy[6]=rect.g_x+rect.g_w-1;
		pxy[7]=rect.g_y+rect.g_h-1;
		vro_cpyfm(vdi_handle,S_ONLY,pxy,&mfdb_dest,&mfdb_src);
		graf_mouse(257,(const MFORM *)0);		
	}
  else
		form_dial(FMD_FINISH,kl_rect.g_x,kl_rect.g_y,kl_rect.g_w,kl_rect.g_h,
	 	 rect.g_x,rect.g_y,rect.g_w,rect.g_h);
	if(buffer)
		Mfree(buffer);
	wind_update(END_UPDATE);
	return(answer);
}

int save_jpeg(char *filename,char *src,int incr_src,int image_width,int image_height,int quality)
{
  static struct jpeg_compress_struct cinfo;
  static struct jpeg_error_mgr jerr;
  JSAMPROW row_pointer[1];	          /* pointer to JSAMPLE row[s] */
	short handle;
	char *rgb,*p,*p2;
	unsigned short *p16;
	unsigned short val;
	int i;
	rgb=(char *)Mxalloc(image_width*3,3);
	if(!rgb)
		return(-1);
	handle=Fcreate(filename,0);
	if(handle<0)
	{
		Mfree(rgb);
		return((int)handle);	
	}	
	cinfo.err = jpeg_std_error(&jerr);
	jpeg_create_compress(&cinfo);
	jpeg_stdio_dest(&cinfo,(FILE *)((unsigned long)handle));
	cinfo.image_width = image_width;   	/* image width and height, in pixels */
	cinfo.image_height = image_height;
	cinfo.input_components = 3;		      /* # of color components per pixel */
	cinfo.in_color_space = JCS_RGB; 	  /* colorspace of input image */
	jpeg_set_defaults(&cinfo);
	jpeg_set_quality(&cinfo,quality,1); /* quality in % */
	cinfo.dct_method = JDCT_IFAST;
	jpeg_start_compress(&cinfo,1);
  while(cinfo.next_scanline < cinfo.image_height)
  {
		p2=rgb;
  	i=image_width;
		switch(work_extend[4])
		{
			case 16:
				p16=(unsigned short*)src;
		  	while(--i > 0)
		  	{
		  		val = *p16++;
		  		*p2++ = (char)((val>>8)&0xF8); /* red */
		  		*p2++ = (char)((val>>3)&0xF8); /* green */
		  		*p2++ = (char)((val<<3)&0xF8); /* blue */
		  	}
				break;
			case 32:
				p=src;  	
		  	while(--i > 0)
		  	{
					p++;
					*p2++ = *p++; /* red */
					*p2++ = *p++; /* green */
					*p2++ = *p++; /* blue */
		  	}
		  	break;
		}
    row_pointer[0] = (JSAMPROW)rgb;
		jpeg_write_scanlines(&cinfo,row_pointer,1);
		src=&src[incr_src];
	}
	jpeg_finish_compress(&cinfo);
	jpeg_destroy_compress(&cinfo);
	Fclose(handle);
	Mfree(rgb);
	return(0);
}

void new_dump_vec(void)
{
	start_snap=1;
	if(radeon)
		Vsetscreen(-1, 0, 0x564E, CMD_COPYPAGE);
	*_dumpflg=-1;
}

void init_alt_help(void)
{
	*dump_vec=new_dump_vec;
}

int find_radeon(void)
{
	unsigned long temp;
	short index;
	long handle, err;
	struct pci_device_id *radeon;
	if(get_cookie('_PCI') == NULL)
		return(0);
	index = 0;
	do
	{
		handle = find_pci_device(0x0000FFFFL, index++);
		if(handle >= 0)
		{
			err = read_config_longword(handle, PCIIDR, &temp);
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
	while(handle >= 0);
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
