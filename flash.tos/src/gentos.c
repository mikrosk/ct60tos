/*  Flashing tool for the CT60 board
 *  Copyright (C) 2000 Xavier Joubert
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
 *
 *
 *  To contact author write to Xavier Joubert, 5 Cour aux Chais, 44 100 Nantes,
 *  FRANCE or by e-mail to xavier.joubert@free.fr.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <mint/osbind.h>

#include "main.h"
#include "gentos.h"
#include "ct60tos.h"

char *program_name;

void
gentos_error(char *error, char *solution)
{
  fprintf(stderr, "%s: Error: %s\n", program_name, error);
  if(solution != NULL)
    fprintf(stderr, "%s: Solution: %s\n", program_name, solution);
  exit(1);
}

Bit32u
apply_patch(Bit8u *buffer, Bit8u *patch)
{
  Bit8u *p=patch;
  Bit8u *adr;
  Bit32u len;
  Bit8u *top=buffer;

  adr=buffer+(*((Bit32u *)p)++);
  while(adr != (buffer-1))
  {
    len=*((Bit32u *)p)++;
    if(len&0x80000000)
    {
      len&=0x7FFFFFFF;
			if(len&0x40000000)
	    {
      	len&=0x3FFFFFFF;
      	*((Bit32u *)p)+=(0xE80000-(Bit32u)ct60tos_half_flash);
			}
			else
      	*((Bit32u *)(p+2))+=(0xE80000-(Bit32u)ct60tos_half_flash);
    }
    while(len--)
      *adr++=*p++;
    top=(adr > top ? adr : top);
    if((Bit32u)p & 3)
      p=(Bit8u *)(((Bit32u)p & 0xFFFFFFFC)+4);
    adr=&buffer[*((Bit32u *)p)++];
  }

  return (top-buffer);
}

Bit32u
modify_tos(Bit8u *buffer)
{
  Bit32u size=TOS4_SIZE;
  Bit32u sizepatch;
  Bit32u time;
  Bit32u day,month,year,year1,year2;

  time=Gettime();
  day=(time>>16)&0x1F;
  month=(time>>21)&0xF;
  year=(time>>25)+1980;
  buffer[24]=(Bit8u)(((month/10)<<4)+(month%10)); 
  buffer[25]=(Bit8u)(((day/10)<<4)+(day%10)); 
  year1=year/100;
  year2=year%100;
  buffer[26]=(Bit8u)(((year1/10)<<4)+(year1%10)); 
  buffer[27]=(Bit8u)(((year2/10)<<4)+(year2%10));

  sizepatch=apply_patch(buffer, (Bit8u *)ct60tos_patch);

  size=(sizepatch > size ? sizepatch : size);

  return size;
}

Bit32u
load_file(char *filename, Bit8u *buffer, Bit32u length)
{
  Bit16u handle;
  Bit32u return_value;

  if((return_value=Fopen(filename, 0)) < 0)
  {
    char error[MAX_ERROR_LENGTH];
    snprintf(error, MAX_ERROR_LENGTH, "Unable to open file %s.", filename);
    gentos_error(error, NULL);
  }
  handle=(Bit16u)return_value;

  return_value=Fread(handle, length, buffer);

  Fclose(handle);

  if(return_value < 0)
  {
    char error[MAX_ERROR_LENGTH];
    snprintf(error, MAX_ERROR_LENGTH, "Unable to read file %s.", filename);
    gentos_error(error, NULL);
  }

  return return_value;
}

void
load_tos(char *filename, Bit8u *buffer, Bit32u length)
{
  if((load_file(filename, buffer, length) != TOS4_SIZE) ||
     (buffer[2]!=0x04) ||
     (buffer[3]!=0x04))
  {
    char error[MAX_ERROR_LENGTH];
    snprintf(error, MAX_ERROR_LENGTH, "File %s is not a valid TOS 4.04 image.", filename);
    gentos_error(error, NULL);
  }
}

void
save_tos(char *filename, Bit8u *buffer, Bit32u length)
{
  Bit16u handle;
  Bit32u return_value;

  if((return_value=Fcreate(filename, 0)) < 0)
  {
    char error[MAX_ERROR_LENGTH];
    snprintf(error, MAX_ERROR_LENGTH, "Unable to create file %s.", filename);
    gentos_error(error, NULL);
  }
  handle=(Bit16u)return_value;

  if(Fwrite(handle, length, buffer) != length)
  {
    char error[MAX_ERROR_LENGTH];
    Fclose(handle);
    snprintf(error, MAX_ERROR_LENGTH, "Unable to write file %s.", filename);
    gentos_error(error, NULL);
  }

  Fclose(handle);
}
 
int
main(int argc, char **argv)
{
  Bit32u length;
  Bit8u *buffer;

  program_name=argv[0];
  if(argc != 3)
  {
    fprintf(stderr, "Usage: %s tos404.bin ct60tos.bin\n", program_name);
    exit(1);
  }

  if((buffer=(Bit8u *)malloc(FLASH_SIZE-PARAM_SIZE)) == NULL)
  {
    gentos_error("Not enough memory for work buffer.", NULL);
  }

  load_tos(argv[1], buffer, FLASH_SIZE-PARAM_SIZE);
  length=modify_tos(buffer);
  save_tos(argv[2], buffer, length);
 
  return 0;
}
