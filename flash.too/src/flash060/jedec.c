/* Flashing hard CT60, JEDEC part
*  Didier Mequignon 2003 February, e-mail: didier.mequignon@wanadoo.fr
*  Based on sources Copyright (c) 2000 Stephen Williams (steve@icarus.com)
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

#include "jedec.h"
#include <string.h>
#include <ctype.h>
#include <tos.h>

struct state_mach
{
	jedec_data_t jed;
	void (*state)(char ch, struct state_mach *m);
	char note_keyword[256];
	char *buffer;
	union
	{
		struct
		{
			unsigned long cur_fuse;
		} l;
	} m;
};

static void m_startup(char ch, struct state_mach *m);
static void m_base(char ch, struct state_mach *m);
static void m_getspec(char ch, struct state_mach *m);
static void m_N(char ch, struct state_mach *m);
static void m_Ndevice(char ch, struct state_mach *m);
static void m_L(char ch, struct state_mach *m);
static void m_Lfuse(char ch, struct state_mach *m);
static void m_Q(char ch, struct state_mach *m);
static void m_QF(char ch, struct state_mach *m);
static void m_skip(char ch, struct state_mach *m);

static void m_startup(char ch, struct state_mach *m)
{
	if(ch==2)
		m->state=m_base;
		/* m->state=m_getspec; */
}

static void m_getspec(char ch, struct state_mach *m)
{
	if(ch=='*')
		m->state=m_base;
}

static void m_base(char ch, struct state_mach *m)
{
	if(isspace((int)ch))
		return;
	switch(ch)
	{
		case 'L':
			m->state=m_L;
			m->m.l.cur_fuse=0;
			if(m->jed->fuse_count==0)
				m->state=0;
			break;
		case 'N':
			m->state=m_N;
			m->note_keyword[0]=0;
			break;
		case 'Q':
			m->state=m_Q;
			break;
		default:
			m->state=m_skip;
			break;
	}
}

static void m_N(char ch, struct state_mach *m)
{
	int i;
	switch(ch)
	{
		case '*':
			m->state=m_base;
			break;
		case ' ':
			if(strcmp(m->note_keyword,"DEVICE")==0)
				m->state = m_Ndevice;
		case '\n':
		case '\r':
			break;
		default:
			i=strlen(m->note_keyword);
			m->note_keyword[i]=ch;
			m->note_keyword[i+1]=0;
			if(i>255)
				m->state=0;
			break;
	}
}

static void m_Ndevice(char ch, struct state_mach *m)
{
	int i;
	switch(ch)
	{
		case '*':
			m->state = m_base;
			break;
		case '\n':
		case '\r':
			break;
		default:
			if(m->jed->note_device)
			{
				i=strlen(m->jed->note_device);
				if(i>255)
					break;
				m->jed->note_device[i]=ch;
				m->jed->note_device[i+1]=0;
			}
			else
				m->state = m_skip;
			break;
	}
}

static void m_L(char ch, struct state_mach *m)
{
	if(isdigit((int)ch))
	{
		m->m.l.cur_fuse *= 10;
		m->m.l.cur_fuse += (unsigned long)ch & 15;
		return;
	}
	else if(isspace((int)ch))
	{
		m->state=m_Lfuse;
		if(m->jed->fuse_list==0 || m->jed->sizes_list==0)
			m->state=0;
		return;
	}
	else if(ch=='*')
	{
		m->state=m_base;
		return;
	}
	m->state=0;
}

static void m_Lfuse(char ch, struct state_mach *m)
{
	char *p;
	unsigned char *p2;
	unsigned long cur_fuse,sizes_count;
	p=m->buffer;
	cur_fuse=m->m.l.cur_fuse;
	sizes_count=m->jed->sizes_count;
	p2=&m->jed->sizes_list[sizes_count];
	while(ch!='*')
	{
		if(ch=='0' || ch=='1')
		{
			jedec_set_fuse(m->jed,cur_fuse++,ch);
			(*p2)++;
		}
		else if(ch==' ')
		{
			sizes_count++;
			p2++;	
		}
		else if(ch!='\n' && ch!='\r')
		{
			m->buffer=p;
			m->m.l.cur_fuse=cur_fuse;
			m->jed->sizes_count=sizes_count;
			m->state=0;
			return;
		}	
		p++;
		ch=*p;
	}
	if(*p2)
		sizes_count++;
	m->buffer=p;
	m->m.l.cur_fuse=cur_fuse;
	m->jed->sizes_count=sizes_count;
	m->state=m_base;	
}

static void m_Q(char ch, struct state_mach *m)
{
	if(ch=='F')
	{
		if(m->jed->fuse_count!=0)
		{
			m->state=0;
			return;
		}
		m->state=m_QF;
		m->jed->fuse_count=m->jed->sizes_count=0;
	}
	else
		m->state = m_skip;
}

static void m_QF(char ch, struct state_mach *m)
{
	unsigned long len;
	if(isspace((int)ch))
		return;
	else if(isdigit((int)ch))
	{
		m->jed->fuse_count *= 10;
		m->jed->fuse_count += (unsigned long)ch & 15;
		return;
	}
	else if(ch=='*')
	{
		m->state=m_base;
		m->jed->fuse_list=Malloc(len=(m->jed->fuse_count+7)>>3);
		if(m->jed->fuse_list==0)
			m->state=0;
		else
			memset(m->jed->fuse_list,0,len);
		m->jed->sizes_list=Malloc(len=(m->jed->fuse_count+7)>>2);
		if(m->jed->sizes_list==0)
			m->state=0;
		else
			memset(m->jed->sizes_list,0,len);
		return;
	}
}

static void m_skip(char ch, struct state_mach *m)
{
	if(ch=='*')
		m->state=m_base;
}

jedec_data_t jedec_read(const char *path, const char *device_name)
{
	int handle;
	long bytes_read,size_file;
	char *buffer,*end_buffer;
	struct state_mach m;
	m.jed=Malloc(sizeof(struct jedec_data));
	if(m.jed==0 || (handle=(int)Fopen(path,0))<0)
		return(0);
	if((size_file=Fseek(0,handle,2))<0 || Fseek(0,handle,0)<0
	 || (buffer=Malloc(size_file))<=0
	 || (bytes_read=Fread(handle,size_file,buffer))<=0)
	{
		Fclose(handle);
		return(0);
	}
	Fclose(handle);
	m.jed->fuse_count=0;
	m.jed->fuse_list=m.jed->sizes_list=0;
	if((m.jed->note_device=(char *)device_name) != 0)
		m.jed->note_device[0]=0;
	m.state=m_startup;
	m.buffer=buffer;
	end_buffer=&buffer[bytes_read];
	while(m.buffer<end_buffer)
	{
		m.state(*m.buffer,&m);
		if(m.state==0)	/* Some sort of error happened. */
		{
			Mfree(buffer);
			return(0);
		}
		m.buffer++;
	}
	Mfree(buffer);
	return(m.jed);
}

void jedec_free(jedec_data_t jed)
{
	if(jed->fuse_list)
		Mfree(jed->fuse_list);
	if(jed->sizes_list)
		Mfree(jed->sizes_list);
	Mfree(jed);
}
