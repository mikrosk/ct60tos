/* Usage: new_pic input.hex file_compress.tga output.hex
*  Didier Mequignon 2005 April, e-mail: aniplay@wanadoo.fr
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
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "flash.h"

extern int srec_read(const char *path);
extern int bintohex(unsigned char *source, long size_source, long base, int byte_addr, char *name);

void *buffer_flash=0;
extern unsigned long start_adr,end_adr;

int main(int argc, char **argv)
{
	unsigned char *p,*end;
	int handle,tga_found;
	long size,ret;
	int i,j;
	
	
	if(argc!=4)
	{
		fprintf(stderr, "Usage: new_pic input.hex file_compress.tga output.hex\r\n");
		return(-1);
	}
	buffer_flash=Mxalloc(FLASH_SIZE-PARAM_SIZE,3);
	if(buffer_flash<=0)
	{
		fprintf(stderr, "No enough free memory\r\n");
		return(-1);
	}	
	memset(buffer_flash,-1,FLASH_SIZE-PARAM_SIZE);
	if(srec_read(argv[1])<0)
	{
		fprintf(stderr, "Cannot open %s\r\n", argv[1]);
		Mfree(buffer_flash);
		return(-1);
	}
	if((start_adr < (FLASH_ADR & 0xFFFFFF))
	 || (end_adr >= ((FLASH_ADR & 0xFFFFFF)+FLASH_SIZE-PARAM_SIZE)))
	{
		fprintf(stderr, "Source address must be between 0x%08lx and 0x%08lx\r\n",
		(FLASH_ADR & 0xFFFFFF),(FLASH_ADR & 0xFFFFFF)+FLASH_SIZE-PARAM_SIZE-1);
		fprintf(stderr, " begin: 0x%08lx end: 0x%08lx\r\n",start_adr,end_adr);
		Mfree(buffer_flash);
		return(-1);
	}
	end=p=(unsigned char *)buffer_flash;
	p+=(start_adr-(FLASH_ADR & 0xFFFFFF));
	end+=(end_adr-(FLASH_ADR & 0xFFFFFF));
	end-=(18+4);
	tga_found=0;
	while(p<end)
	{
		if(p[2+4]==0xA && p[12+4]==0x40 && p[13+4]==1 && p[14+4]==0xF0 && p[15+4]==0)
		{
			tga_found=1;
			break;
		} 
		p++;
	}
	if(!tga_found)
	{
		fprintf(stderr, "No compressed Targa picture in 320 x 240 found inside %s\r\n",argv[1]);
		fprintf(stderr, " begin: 0x%08lx end: 0x%08lx\r\n",start_adr,end_adr);
		Mfree(buffer_flash);
		return(-1);
	}
	if((handle=(int)Fopen(argv[2],0))<0)
	{
		fprintf(stderr, "Cannot open %s\r\n", argv[2]);
		Mfree(buffer_flash);
		return(-1);
	}
	if((size=Fseek(0L,handle,2))>=0)
	{
		Fseek(0L,handle,0);
		*((unsigned long *)p)=size;
		p+=4;
		end_adr=(unsigned long)(p-(unsigned char*)buffer_flash)+size+(FLASH_ADR & 0xFFFFFF);
		if((start_adr < (FLASH_ADR & 0xFFFFFF))
		 || (end_adr >= ((FLASH_ADR & 0xFFFFFF)+FLASH_SIZE-PARAM_SIZE)))
		{
			fprintf(stderr, "Target address must be between 0x%08lx and 0x%08lx\r\n",
			(FLASH_ADR & 0xFFFFFF),(FLASH_ADR & 0xFFFFFF)+FLASH_SIZE-PARAM_SIZE-1);
			fprintf(stderr, " begin: 0x%08lx end: 0x%08lx\r\n",start_adr,end_adr);
			fprintf(stderr, "Please try again with a lower Targa file\r\n");
			Mfree(buffer_flash);
			return(-1);
		}
		if(size<=0 || (ret=Fread(handle,size,p))<=0 || ret!=size)
		{
			Fclose(handle);
			fprintf(stderr, "Error during reading %s\r\n", argv[2]);
			Mfree(buffer_flash);
			return(-1);
		}
		Fclose(handle);
		if(p[2]!=0xA || p[12]!=0x40 || p[13]!=1 || p[14]!=0xF0 || p[15]!=0)
		{	
			fprintf(stderr, "Targa file %s must be a 320 x 240 compressed picture\r\n",argv[2]);
			Mfree(buffer_flash);
			return(-1);
		}
	}	
	if(bintohex((unsigned char *)buffer_flash+(start_adr-(FLASH_ADR & 0xFFFFFF)),
	 end_adr-start_adr,start_adr,4,argv[3])<0)
	{
		fprintf(stderr, "Cannot create %s\r\n", argv[3]);
		Mfree(buffer_flash);
		return(-1);
	}
	Mfree(buffer_flash);
	return(0);
}

