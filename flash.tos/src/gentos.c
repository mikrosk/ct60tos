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

Bit32u
load_tests(char *filename, Bit8u *buffer, Bit32u length)
{
  if((length=load_file(filename, buffer, length)) >= TESTS_SIZE)
  {
    char error[MAX_ERROR_LENGTH];
    snprintf(error, MAX_ERROR_LENGTH, "File %s is not a valid tests image.", filename);
    gentos_error(error, NULL);
  }
  return length;
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
	static Bit16u crctab[256] = {
		0x0000,0x1021,0x2042,0x3063,0x4084,0x50a5,0x60c6,0x70e7,
		0x8108,0x9129,0xa14a,0xb16b,0xc18c,0xd1ad,0xe1ce,0xf1ef,
		0x1231,0x0210,0x3273,0x2252,0x52b5,0x4294,0x72f7,0x62d6,
		0x9339,0x8318,0xb37b,0xa35a,0xd3bd,0xc39c,0xf3ff,0xe3de,
		0x2462,0x3443,0x0420,0x1401,0x64e6,0x74c7,0x44a4,0x5485,
		0xa56a,0xb54b,0x8528,0x9509,0xe5ee,0xf5cf,0xc5ac,0xd58d,
		0x3653,0x2672,0x1611,0x0630,0x76d7,0x66f6,0x5695,0x46b4,
		0xb75b,0xa77a,0x9719,0x8738,0xf7df,0xe7fe,0xd79d,0xc7bc,
		0x48c4,0x58e5,0x6886,0x78a7,0x0840,0x1861,0x2802,0x3823,
		0xc9cc,0xd9ed,0xe98e,0xf9af,0x8948,0x9969,0xa90a,0xb92b,
		0x5af5,0x4ad4,0x7ab7,0x6a96,0x1a71,0x0a50,0x3a33,0x2a12,
		0xdbfd,0xcbdc,0xfbbf,0xeb9e,0x9b79,0x8b58,0xbb3b,0xab1a,
		0x6ca6,0x7c87,0x4ce4,0x5cc5,0x2c22,0x3c03,0x0c60,0x1c41,
		0xedae,0xfd8f,0xcdec,0xddcd,0xad2a,0xbd0b,0x8d68,0x9d49,
		0x7e97,0x6eb6,0x5ed5,0x4ef4,0x3e13,0x2e32,0x1e51,0x0e70,
		0xff9f,0xefbe,0xdfdd,0xcffc,0xbf1b,0xaf3a,0x9f59,0x8f78,
		0x9188,0x81a9,0xb1ca,0xa1eb,0xd10c,0xc12d,0xf14e,0xe16f,
		0x1080,0x00a1,0x30c2,0x20e3,0x5004,0x4025,0x7046,0x6067,
		0x83b9,0x9398,0xa3fb,0xb3da,0xc33d,0xd31c,0xe37f,0xf35e,
		0x02b1,0x1290,0x22f3,0x32d2,0x4235,0x5214,0x6277,0x7256,
		0xb5ea,0xa5cb,0x95a8,0x8589,0xf56e,0xe54f,0xd52c,0xc50d,
		0x34e2,0x24c3,0x14a0,0x0481,0x7466,0x6447,0x5424,0x4405,
		0xa7db,0xb7fa,0x8799,0x97b8,0xe75f,0xf77e,0xc71d,0xd73c,
		0x26d3,0x36f2,0x0691,0x16b0,0x6657,0x7676,0x4615,0x5634,
		0xd94c,0xc96d,0xf90e,0xe92f,0x99c8,0x89e9,0xb98a,0xa9ab,
		0x5844,0x4865,0x7806,0x6827,0x18c0,0x08e1,0x3882,0x28a3,
		0xcb7d,0xdb5c,0xeb3f,0xfb1e,0x8bf9,0x9bd8,0xabbb,0xbb9a,
		0x4a75,0x5a54,0x6a37,0x7a16,0x0af1,0x1ad0,0x2ab3,0x3a92,
		0xfd2e,0xed0f,0xdd6c,0xcd4d,0xbdaa,0xad8b,0x9de8,0x8dc9,
		0x7c26,0x6c07,0x5c64,0x4c45,0x3ca2,0x2c83,0x1ce0,0x0cc1,
		0xef1f,0xff3e,0xcf5d,0xdf7c,0xaf9b,0xbfba,0x8fd9,0x9ff8,
		0x6e17,0x7e36,0x4e55,0x5e74,0x2e93,0x3eb2,0x0ed1,0x1ef0 };
  Bit32u length;
  Bit8u *buffer;
  Bit16u crc,crc2;
  Bit32u i;

  program_name=argv[0];
  if(argc != 4)
  {
    fprintf(stderr, "Usage: %s tos404.bin sparrow.out ct60tos.bin\n", program_name);
    exit(1);
  }
  
  if((buffer=(Bit8u *)malloc(FLASH_SIZE-PARAM_SIZE)) == NULL)
    gentos_error("Not enough memory for work buffer.", NULL);
  for(i=0;i<(FLASH_SIZE-PARAM_SIZE);buffer[i++]=0xFF);
    
  load_tos(argv[1], buffer, FLASH_SIZE-PARAM_SIZE-TESTS_SIZE);
  length=modify_tos(buffer);

  if(length>(FLASH_SIZE-PARAM_SIZE-TESTS_SIZE))
    gentos_error("Not enough flash space for load tests.", NULL);
    
  crc=0;
  for(i=0;i < (FLASH_SIZE/2)-2;i++)
  {
			crc2 = crctab[buffer[i] ^ (Bit8u)(crc>>8)];
			crc <<= 8;
			crc ^= crc2;
  }
  buffer[i++] = (Bit8u)(crc>>8);
  buffer[i] = (Bit8u)crc;
  
  length=load_tests(argv[2],buffer+FLASH_SIZE-PARAM_SIZE-TESTS_SIZE,TESTS_SIZE);
  save_tos(argv[3], buffer, FLASH_SIZE-PARAM_SIZE-TESTS_SIZE+length);
  
  return 0;
}
