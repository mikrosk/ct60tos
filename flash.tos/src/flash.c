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
#include <sys/cookie.h>
#include <mint/osbind.h>

#include "main.h"
#include "flash.h"
#include "write.h"

char *program_name;
 
void
flash_exit(int value)
{
  printf("\n-Press return to quit-");
  getchar();
  exit(value);
}

void
flash_error(char *error, char *solution)
{
  fprintf(stderr, "%s: Error: %s\n", program_name, error);
  Cconout(0xD);
  if(solution != NULL)
  {
    fprintf(stderr, "%s: Solution: %s\n", program_name, solution);
    Cconout(0xD);
  }
  flash_exit(1);
}

void
write_flash(Bit8u *buffer, Bit32u size)
{
  Bit32u device;
  t_sector *sectors = NULL;
  int i;
  char *retry="Retry. You may need to get a new flash if it still fails after some tries.";

  if(detect_flash(&device, (Bit8u *)FLASH_ADR, (Bit8u *)FLASH_UNLOCK1, (Bit8u *)FLASH_UNLOCK2))
    flash_error("No CT60 board detected.", "Check your system.");

  i=0;
  while(supported_devices[i].sectors != NULL)
  {
    if(device == supported_devices[i].device)
      sectors = supported_devices[i].sectors;
    i++;
  }

  if(sectors == NULL)
  {
    char error[MAX_ERROR_LENGTH];
    snprintf(error, MAX_ERROR_LENGTH, "Unsupported flash device: %8X.", (unsigned int)device);
    flash_error(error, "Use latest software from http://www.czuba-tech.com.");
  }

  printf("Erasing flash... ");
  if(erase_flash(sectors))
  {
    printf("\n");
    Cconout(0xD);
    flash_error("Unable to erase flash device.", retry);
  }
  printf("OK\n");
  Cconout(0xD);

  printf("Programing flash...");
  if(program_flash(sectors, buffer, size))
  {
    printf("\n");
    Cconout(0xD);
    flash_error("Unable to program flash device.", retry);
  }
  printf("OK\n");
  Cconout(0xD);
  
  printf("Verify flash...");
  if(verify_flash(buffer, size))
  {
    printf("\n");
    Cconout(0xD);
    flash_error("Verify error.", retry);
  }  
  printf("OK\n");
  Cconout(0xD);
}

void
protect_tos(void)
{
}

void load_file(char *filename, Bit8u *buffer[], Bit32u *size)
{
  Bit16u handle;
  Bit32s return_value;

  if((return_value=Fopen(filename, 0)) < 0)
  {
    char error[MAX_ERROR_LENGTH];
    snprintf(error, MAX_ERROR_LENGTH, "Unable to open file %s.", filename);
    flash_error(error, NULL);
  }
  handle=(Bit16u)return_value;

  *size=Fseek(0, handle, 2);
  Fseek(0, handle, 0);

  if((*buffer=(Bit8u *)Mxalloc(*size, 3)) == NULL)
  {
    char error[MAX_ERROR_LENGTH];
    Fclose(handle);
    snprintf(error, MAX_ERROR_LENGTH, "Not enough memory to load file %s.", filename);
    flash_error(error, NULL);
  }

  Fread(handle, *size, *buffer);

  Fclose(handle);
}

int
main(int argc, char **argv)
{
  Bit32s computer_type;
  Bit8u *buffer;
  Bit32u size;

  program_name=argv[0];
  if(argc != 2)
  {
    fprintf(stderr, "Usage: %s file\n", program_name);
    flash_exit(1);
  }

  if((Getcookie(C__MCH, &computer_type) != C_FOUND) ||
     ((computer_type>>16) != 3))
  {
    flash_error("This program only runs on Falcon + CT60.", "Upgrade your system.");
  }

  load_file(argv[1], &buffer, &size);
  protect_tos();
  write_flash(buffer, size);

  flash_exit(0);
  return 0;
}
