/* TOS 4.04 FIREBEE flash programming
 * Didier Mequignon 2009, e-mail: aniplay@wanadoo.fr
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "mcf548x.h"
#include "net.h"
#include "amd_flash.h"

t_sector amd_29lv640_sectors[] =
{
  {0x00000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x10000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x20000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x30000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x40000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x50000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x60000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x70000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x80000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x90000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0xA0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0xB0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0xC0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0xD0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0xE0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0xF0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x100000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x110000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x120000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x130000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x140000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x150000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x160000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x170000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x180000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x190000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x1A0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x1B0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x1C0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x1D0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x1E0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x1F0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x200000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x210000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x220000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x230000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x240000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x250000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x260000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x270000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x280000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x290000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x2A0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x2B0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x2C0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x2D0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x2E0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x2F0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x300000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x310000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x320000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x330000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x340000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x350000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x360000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x370000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x380000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x390000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x3A0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x3B0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x3C0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x3D0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x3E0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x3F0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x400000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x410000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x420000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x430000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x440000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x450000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x460000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x470000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x480000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x490000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x4A0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x4B0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x4C0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x4D0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x4E0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x4F0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x500000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x510000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x520000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x530000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x540000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x550000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x560000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x570000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x580000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x590000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x5A0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x5B0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x5C0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x5D0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x5E0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x5F0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x600000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x610000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x620000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x630000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x640000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x650000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x660000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x670000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x680000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x690000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x6A0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x6B0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x6C0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x6D0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x6E0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x6F0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x700000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x710000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x720000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x730000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x740000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x750000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x760000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x770000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x780000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x790000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x7A0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x7B0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x7C0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x7D0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x7E0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x7F0000, FLASH_UNLOCK1, FLASH_UNLOCK2},
  {0x800000, 0, 0}
};

struct
{
  vuint32 device;
  t_sector *sectors;
} supported_devices[] = { {0x000122d7, amd_29lv640_sectors}, {0, NULL} };

static vuint32 GetFlashDevice(void)
{
  vuint32 device;
  unsigned long base = MCF_FBCS0_CSAR & 0xFFFF0000;
  vuint16 *unlock1 = (vuint16 *)(base + FLASH_UNLOCK1);
  vuint16 *unlock2 = (vuint16 *)(base + FLASH_UNLOCK2);
  *unlock1 = CMD_UNLOCK1;      // unlock
  *unlock2 = CMD_UNLOCK2;
  *unlock1 = CMD_AUTOSELECT;   // Autoselect command
  device = *(vuint32 *)base;   // Manufacturer code / Device code
  *(vuint16 *)base = CMD_READ; // Read/Reset command
  return(device);
}

unsigned long FlashIdentify(void)
{
  t_sector *sectors = NULL;
  vuint32 device = GetFlashDevice();
  int i = 0;
  while(supported_devices[i].sectors != NULL)
  {
    if(device == supported_devices[i].device)
      sectors = supported_devices[i].sectors;
    i++;
  }
  if(sectors == NULL)
    return(FAIL);
  return(SUCCESS);
}

void UnprotectCSBOOT(void)
{
  MCF_FBCS0_CSMR &= ~MCF_FBCS_CSMR_WP;
} 

void ProtectCSBOOT(void)
{
  MCF_FBCS0_CSMR |= MCF_FBCS_CSMR_WP;
}

unsigned long EraseFlash(unsigned long begin, unsigned long end)
{
  t_sector *sectors = NULL;
  vuint32 address, size;
  vuint32 device = GetFlashDevice();
  unsigned long base = MCF_FBCS0_CSAR & 0xFFFF0000;
  vuint16 status;
  int i = 0;
  while(supported_devices[i].sectors != NULL)
  {
    if(device == supported_devices[i].device)
      sectors = supported_devices[i].sectors;
    i++;
  }
  if(sectors == NULL)
    return(FAIL);
  while(sectors->unlock1 && sectors->unlock2)
  {
    address = base + sectors->offset;  
    size = sectors[1].offset - sectors[0].offset;
    if((address >= (begin & ~(size-1))) && (address < end))
    {
      vuint16 *unlock1 = (vuint16 *)(base + sectors->unlock1);
      vuint16 *unlock2 = (vuint16 *)(base + sectors->unlock1);
      *unlock1 = CMD_UNLOCK1;      // unlock
      *unlock2 = CMD_UNLOCK2;
      *(vuint16 *)address = CMD_SECTOR_ERASE1;
      *unlock1 = CMD_UNLOCK1;      // unlock
      *unlock2 = CMD_UNLOCK2;
      *(vuint16 *)address = CMD_SECTOR_ERASE2; // Erase sector command
      while(!((status = *(vuint16 *)address) & 0x00A0)); // wait
      if((status & 0x0020) && !(*(vuint16 *)address & 0x0080))
      {
        ResetFlash();
        return(FAIL); // erase error
      }
    }    
    address += size;
    sectors++;
  }
  return(ResetFlash());
}

unsigned long ResetFlash(void)
{
  vuint32 base = MCF_FBCS0_CSAR & 0xFFFF0000;
  *(vuint16 *)base = CMD_READ; // Read/Reset command
  return(SUCCESS);
}

unsigned long ProgFlash(unsigned long begin, unsigned long end, void *code)
{
  vuint16 *data = (vuint16 *)code;  
  t_sector *sectors = NULL;
  vuint32 address, size;
  vuint32 device = GetFlashDevice();
  unsigned long base = MCF_FBCS0_CSAR & 0xFFFF0000;
  vuint16 status, flag;
  int i = 0;
  while(supported_devices[i].sectors != NULL)
  {
    if(device == supported_devices[i].device)
      sectors = supported_devices[i].sectors;
    i++;
  }
  if(sectors == NULL)
    return(FAIL);
  while(sectors->unlock1 && sectors->unlock2)
  {
    address = base + sectors->offset;  
    size = sectors[1].offset - sectors[0].offset;
    if((address >= (begin & ~(size-1))) && (address < end))
    { 
      vuint16 *unlock1 = (vuint16 *)(base + sectors->unlock1);
      vuint16 *unlock2 = (vuint16 *)(base + sectors->unlock1);
      address = begin & ~1;
      while(begin < end)
      {
        int j = 15;    
        *unlock1 = CMD_UNLOCK1; // unlock
        *unlock2 = CMD_UNLOCK2;
        *unlock1 = CMD_PROGRAM; // Program command
        do
        {
          flag = *(vuint16 *)address = *data;
          flag &= 0x0080;
          while(((((status = *(vuint16 *)address) ^ flag) & 0x0080) != 0) && !(status & 0x0020)); // wait
          if(!((status & 0x0020) && (((*(vuint16 *)address ^ flag) & 0x0080) != 0)))
            break;
        }
        while(--j > 0); // retry
        if((j < 0) || (*(vuint16 *)address != *data)) // verify
        {
          ResetFlash();
          return(FAIL); // write error
        }
        address += 2;
        data++;
      }
    }
    sectors++;
  }
  return(ResetFlash());
}

