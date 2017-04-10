/* Flashing CT60, HEX part
*  Didier Mequignon 2005-2010, e-mail: aniplay@wanadoo.fr
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
#include <stdio.h>
#include <string.h>
#include "flash.h"

extern void *buffer_flash;
unsigned long start_adr,end_adr,size_srec,offset_srec;
char *buffer_srec;
extern int coldfire;

const unsigned char nibble[256] = {
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0,
  0,10,11,12,13,14,15, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0,10,11,12,13,14,15, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

long stegf(char *buf,long len,int handle)
{
	char *cp;
	long ret,pos;
	if(coldfire)
	{
		if(offset_srec+len>size_srec)
			ret=size_srec-offset_srec;
		else
			ret=len;
		if(ret>0)
			memcpy(buf,&buffer_srec[offset_srec],ret);
		pos=offset_srec;
		while(ret>=0 && (cp=strchr(buf,'\n')) != 0)
		{
			*cp = 0;
			pos++;
		}
		while(ret>=0 && (cp=strchr(buf,'\r')) != 0)
		{
			*cp = 0;
			pos++;
		}
		if(ret<0)
			ret=0;
		else
			offset_srec=pos+strlen(buf);
	}
	else
	{
		pos=Fseek(0L,handle,1);
		ret=Fread(handle,len,buf);
		while(ret>=0 && (cp=strchr(buf,'\n')) != 0)
		{
			*cp = 0;
			pos++;
		}
		while(ret>=0 && (cp=strchr(buf,'\r')) != 0)
		{
			*cp = 0;
			pos++;
		}
		if(ret<0)
			ret=0;
		else
		{
			if(Fseek(pos+strlen(buf),handle,0)<0)
				ret=0;
		}
	}
	return(ret);
}

int strneq(const char *s1,const char *s2)
{
	return(strncmp(s1,s2,strlen(s2))==0);
}

void getbytes(char *line,long addr_bytes)
{
	unsigned long count,offset;
	unsigned char *p; 
	long i,j;
	struct
	{
		char c[4];
		unsigned long v;
	} asciiByte[64];

	memset(asciiByte,0,sizeof(asciiByte));
	for(i=0;*line;i++)
	{
		memcpy(asciiByte[i].c,line,2);
		line+=2;
		asciiByte[i].v = (unsigned long)nibble[(unsigned long)asciiByte[i].c[0]] << 4 | (unsigned long)nibble[(unsigned long)asciiByte[i].c[1]];
	}
	j = 2 + addr_bytes;
	count = asciiByte[1].v - addr_bytes - 1;
	if(addr_bytes==2)
		offset = asciiByte[2].v * 256 + asciiByte[3].v;
	else if(addr_bytes==3)
		offset = asciiByte[2].v * 65536 + asciiByte[3].v * 256 + asciiByte[4].v;
	else if(addr_bytes==4)
		offset = asciiByte[2].v * 16777216 + asciiByte[3].v * 65536 + asciiByte[4].v * 256 + asciiByte[5].v;
	else
		return;
	if(offset < start_adr)
		start_adr=offset;
	if((offset+count) > end_adr)
		end_adr=offset+count; 
	p=(unsigned char *)buffer_flash;
	if(coldfire)
	{
		p+=(offset-FLASH_ADR_CF);
		if((offset >= FLASH_ADR_CF)
		 && ((offset+count) < (FLASH_ADR_CF+FLASH_SIZE_CF)))
		{
			for(i=0;i<count;i++)
				*p++=(unsigned char)asciiByte[i+j].v;
		}
	}
	else
	{
		p+=(offset-(FLASH_ADR & 0xFFFFFF));
		if((offset >= (FLASH_ADR & 0xFFFFFF))
		 && ((offset+count) < ((FLASH_ADR & 0xFFFFFF)+FLASH_SIZE-PARAM_SIZE)))
		{
			for(i=0;i<count;i++)
				*p++=(unsigned char)asciiByte[i+j].v;
		}
	}
}

int srec_read(const char *path)
{
	int handle,rt;
	char line[256];
	long line_count=0,ret;
	start_adr=0xFFFFFFFF;
	end_adr=0;
	buffer_srec=NULL;
	if((handle=(int)Fopen(path,0))<0)
		return(handle);
	if(coldfire)
	{
		size_srec=Fseek(0L,handle,2);
		if(size_srec<0)
			return(size_srec);
		Fseek(0L,handle,0);
		buffer_srec=(char *)Mxalloc(size_srec,2);
		if(buffer_srec==NULL)
			return(-1);
		ret=Fread(handle,size_srec,buffer_srec);
		if(ret<0)
		{
			Mfree(buffer_srec);
			Fclose(handle);		
			return((int)ret);
		}
		offset_srec=0;
	}
	while(stegf(line,100,handle))
	{
		if(strneq(line,"S0")) rt=0;
		else if(strneq(line,"S1")) rt=1;
		else if(strneq(line,"S2")) rt=2;
		else if(strneq(line,"S3")) rt=3;
		else if(strneq(line,"S7")) rt=7;
		else if(strneq(line,"S8")) rt=8;
		else if(strneq(line,"S9")) rt=9;
		else
		{
			if(buffer_srec!=NULL)
				Mfree(buffer_srec);
			Fclose(handle);
			return(-1);
		}
		line_count++;
		switch(rt)
		{
			case 0: break;
			case 1: getbytes(line,2); break;
			case 2: getbytes(line,3); break;
			case 3: getbytes(line,4); break;
			case 7:
			case 8:
			case 9: break;
		}
	}
	if(buffer_srec!=NULL)
		Mfree(buffer_srec);
	Fclose(handle);
	return(0);
}


