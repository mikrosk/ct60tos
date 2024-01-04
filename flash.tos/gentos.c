/* CT60 / Coldfire board(s) binary genarator
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mint/osbind.h>

#include "main.h"
#include "gentos.h"

void *buffer_flash=NULL;
char *program_name;

void gentos_error(char *error, char *solution)
{
	fprintf(stderr, "%s: Error: %s\n", program_name, error);
	if(solution != NULL)
		fprintf(stderr, "%s: Solution: %s\n", program_name, solution);
	exit(1);
}

unsigned long load_file(char *filename, unsigned char *buffer, unsigned long length)
{
	unsigned short handle;
	unsigned long return_value;

	if((return_value=Fopen(filename, 0)) < 0)
	{
		char error[MAX_ERROR_LENGTH];
		snprintf(error, MAX_ERROR_LENGTH, "Unable to open file %s.", filename);
		gentos_error(error, NULL);
	}
	handle=(unsigned short)return_value;
	return_value=Fread(handle, length, buffer);
	Fclose(handle);
	if(return_value < 0)
	{
		char error[MAX_ERROR_LENGTH];
		snprintf(error, MAX_ERROR_LENGTH, "Unable to read file %s.", filename);
		gentos_error(error, NULL);
	}
  return(return_value);
}

unsigned long load_tests(char *filename, unsigned char *buffer, unsigned long length)
{
	if((length=load_file(filename, buffer, length)) >= TESTS_SIZE)
	{
		char error[MAX_ERROR_LENGTH];
		snprintf(error, MAX_ERROR_LENGTH, "File %s is not a valid tests image.", filename);
		gentos_error(error, NULL);
	}
	return(length);
}

void load_tos(char *filename, unsigned char *buffer, unsigned long length)
{
	if((load_file(filename, buffer, length) != TOS4_SIZE) || (buffer[2]!=0x04) || (buffer[3]!=0x04))
	{
		char error[MAX_ERROR_LENGTH];
		snprintf(error, MAX_ERROR_LENGTH, "File %s is not a valid TOS 4.04 image.", filename);
		gentos_error(error, NULL);
	}
}

void save_tos(char *filename, unsigned char *buffer, unsigned long length)
{
	unsigned short handle;
	unsigned long return_value;

	if((return_value=Fcreate(filename, 0)) < 0)
	{
		char error[MAX_ERROR_LENGTH];
		snprintf(error, MAX_ERROR_LENGTH, "Unable to create file %s.", filename);
		gentos_error(error, NULL);
	}
	handle=(unsigned short)return_value;
	if(Fwrite(handle, length, buffer) != length)
	{
		char error[MAX_ERROR_LENGTH];
		 Fclose(handle);
		snprintf(error, MAX_ERROR_LENGTH, "Unable to write file %s.", filename);
		gentos_error(error, NULL);
	}
	Fclose(handle);
}
 
int main(int argc, char **argv)
{
	unsigned long end_previous=0;

	program_name = argv[0];
	if((argc < 4) || (argc > 7))
	{
		fprintf(stderr, "Usage: %s tos404.bin boot.hex [sparrow.out] ct60tos.bin\n", program_name);
		exit(1);
	}
	if((buffer_flash = (unsigned char *)Mxalloc(FLASH_SIZE-PARAM_SIZE,3)) == NULL)
		gentos_error("Not enough memory for work buffer.", NULL);
	memset(buffer_flash,-1,FLASH_SIZE-PARAM_SIZE);
	load_tos(argv[1], buffer_flash, FLASH_SIZE-PARAM_SIZE-TESTS_SIZE); /* load 512KB TOS */
	*((unsigned short *)(buffer_flash+0x30))=0x60FF; /* bra.l to boot (12 bytes version header) */
	*((unsigned long *)(buffer_flash+0x32))=0xE8000C-0xE00030-2;
	if(strstr(argv[2], ".hex") == NULL)
		gentos_error("Need .hex file for boot", NULL);
	printf("read srec file %s...", argv[2]);
	if(srec_read(argv[2])) /* boot.hex */
		gentos_error("Error with HEX boot file.", NULL);
	printf(" (0x%08lX-0x%08lX)\r\n", start_addr, end_addr);
	if((start_addr < FLASH_ADR+TOS4_SIZE) || (start_addr >= FLASH_ADR+FLASH_SIZE-PARAM_SIZE))
		gentos_error("Error with HEX boot file, bad start address.", NULL);
	if((end_addr < FLASH_ADR+TOS4_SIZE) || (end_addr >= FLASH_ADR+FLASH_SIZE-PARAM_SIZE))
		gentos_error("Error with HEX boot file, bad end address.", NULL);
	if(end_addr <= start_addr)
		gentos_error("Error with HEX boot file, end address < start address.", NULL);	
	end_previous = end_addr;
	if(argc == 4)
		save_tos(argv[3], buffer_flash, end_previous-FLASH_ADR); /* normal TOS saved with CT60 boot only */
	else if(argc == 5)
	{
		unsigned long length;
	  if(end_previous > (FLASH_ADR+FLASH_SIZE-PARAM_SIZE-TESTS_SIZE))
		  gentos_error("Not enough flash space for load tests.", NULL);
		length=load_tests(argv[3],buffer_flash+FLASH_SIZE-PARAM_SIZE-TESTS_SIZE,TESTS_SIZE);
		save_tos(argv[4], buffer_flash, FLASH_SIZE-PARAM_SIZE-TESTS_SIZE+length); /* normal TOS saved with CT60 boot and tests */
	}
	else /* argc > 5 */
	{
		int index = 4;
		if(strstr(argv[index], ".hex") == NULL)
			gentos_error("Need .hex file for drivers", NULL);
		printf("read srec file %s...", argv[index]);
		if(srec_read(argv[index++])) /* drivers */
			gentos_error("Error with HEX drivers file.", NULL);
		printf(" (0x%08lX-0x%08lX)\r\n", start_addr, end_addr);
		if((start_addr < end_previous) || (start_addr >= FLASH_ADR+FLASH_SIZE-PARAM_SIZE))
			gentos_error("Error with HEX drivers file, bad start address.", NULL);
		if((end_addr < end_previous) || (end_addr >= FLASH_ADR+FLASH_SIZE-PARAM_SIZE))
			gentos_error("Error with HEX drivers file, bad end address.", NULL);
		if(end_addr <= start_addr)
			gentos_error("Error with HEX drivers file, end address < start address.", NULL);		
		save_tos(argv[index], buffer_flash, end_addr-FLASH_ADR); /* PCI TOS saved with CT60 boot and drivers (and CF68KLIB for CF) */
	}
	return(0);
}
