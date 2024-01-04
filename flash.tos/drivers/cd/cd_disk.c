/* 
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
/* Disk cache from GRUB (GRand Unified Bootloader) sources */

#include <mint/osbind.h>
#include <mint/sysvars.h>
#include <string.h>
#include <stdlib.h> /* for malloc */
#include "gemerror.h"
#include "scsidrv/scsi.h"
#include "cd_dos.h"
#include "cd_disk.h"
#include "cd_iso.h"

#define CD_DA        1
#define CD_DATA      2
#define CD_I         3
#define CD_XA        4
#define DVD_ROM      5
#define DVD_RAM      6
#define DVD_R        7
#define DVD_RW       8
#define DVD_PLUS_R   9
#define DVD_PLUS_RW 10

#undef STATIC_TMP_BUF

/* Disk cache  */
struct cd_disk_cache
{
	unsigned long dev_id;
	unsigned long disk_id;
	unsigned long sector;
	char *data;
	int lock;
};

extern void kprint(const char *fmt, ...);
extern tpScsiCall scsicall;
extern tReqData ReqBuff;
extern int boot_menu(int index, int nb_lines, char *title, char *lines[], int delay_sec);
extern int install_cd_disk(void);

static char BuffSector[CD_SECTOR_SIZE];

int cd_disk_errno;
struct cd_disk global_disk;

/* Read sectors with DISK_SECTOR_SIZE for XBIOS */
int cd_disk_read_sectors(unsigned long sector_start, unsigned long num_sectors, void *buffer)
{
	unsigned long sector = sector_start >> (CD_SECTOR_BITS - DISK_SECTOR_BITS);
	unsigned long offset = (sector_start & 3) << DISK_SECTOR_BITS;
	unsigned long count = ((sector_start + num_sectors - 1) >> (CD_SECTOR_BITS - DISK_SECTOR_BITS)) - sector + 1;
	long rc = -1, i;
	if(sector_start < global_disk.total_sectors)
	{
		if(!offset && !(num_sectors & 3) && (count < 65536))
			rc = Read10(sector, count, buffer);
		else
		{
			for(i = 0; i < count; i++)
			{	
				rc = Read10(sector, 1, BuffSector);
				if(rc != 0)
					break;
				while(offset < CD_SECTOR_SIZE)
				{		
					memcpy(buffer, &BuffSector[offset], DISK_SECTOR_SIZE);
					offset += DISK_SECTOR_SIZE;
					buffer += DISK_SECTOR_SIZE;
					num_sectors--;
					if(num_sectors <= 0)
						break;
				}
				offset = 0;
				sector++;
			}
		}
	}
	return((int)rc);
}

/* CD disk cache */
static struct cd_disk_cache cd_disk_cache_table[DISK_CACHE_NUM];

static unsigned cd_disk_cache_get_index(unsigned long dev_id, unsigned long disk_id, unsigned long sector)
{
	return((dev_id * 524287UL + disk_id * 2606459UL + ((unsigned) (sector >> DISK_CACHE_BITS))) % DISK_CACHE_NUM);
}

#if 0
static void cd_disk_cache_invalidate_all(void)
{
	unsigned i;
	for(i = 0; i < DISK_CACHE_NUM; i++)
	{
		struct cd_disk_cache *cache = cd_disk_cache_table + i;
		if((cache->data != NULL) && !cache->lock)
		{
			free(cache->data);
			cache->data = NULL;
		}
	}
}
#endif

static void cd_disk_cache_free_all(void)
{
	unsigned i;
	for(i = 0; i < DISK_CACHE_NUM; i++)
	{
		struct cd_disk_cache *cache = cd_disk_cache_table + i;
		if(cache->data != NULL)
		{
			free(cache->data);
			cache->data = NULL;
		}
	}
}

static char *cd_disk_cache_fetch(unsigned long dev_id, unsigned long disk_id, unsigned long sector)
{
	unsigned index = cd_disk_cache_get_index(dev_id, disk_id, sector);
	struct cd_disk_cache *cache = cd_disk_cache_table + index;
	if(cache->dev_id == dev_id && cache->disk_id == disk_id && cache->sector == sector)
	{
		cache->lock = 1;
		return(cache->data);
	}
	return(0);
}

static void cd_disk_cache_unlock(unsigned long dev_id, unsigned long disk_id, unsigned long sector)
{
	unsigned index = cd_disk_cache_get_index(dev_id, disk_id, sector);
	struct cd_disk_cache *cache = cd_disk_cache_table + index;
	if(cache->dev_id == dev_id && cache->disk_id == disk_id && cache->sector == sector)
		cache->lock = 0;
}

static int cd_disk_cache_store(unsigned long dev_id, unsigned long disk_id, unsigned long sector, const char *data)
{
	unsigned index = cd_disk_cache_get_index(dev_id, disk_id, sector);
	struct cd_disk_cache *cache = cd_disk_cache_table + index;
	cache->lock = 1;
	if(cache->data != NULL)
		free(cache->data);
	cache->data = NULL;
	cache->lock = 0;
	cache->data = (char *)malloc(DISK_SECTOR_SIZE << DISK_CACHE_BITS);
	if(cache->data == NULL)
		return(cd_disk_errno = ENSMEM);
	memcpy(cache->data, data, DISK_SECTOR_SIZE << DISK_CACHE_BITS);
	cache->dev_id = dev_id;
	cache->disk_id = disk_id;
	cache->sector = sector;
	return(E_OK);
}

/* This function:
   - Make sectors disk relative from partition relative.
   - Normalize offset to be less than the sector size.  */
static int cd_disk_adjust_range(cd_disk_t disk, unsigned long *sector, unsigned long *offset, int size)
{
	*sector += *offset >> DISK_SECTOR_BITS;
	*offset &= DISK_SECTOR_SIZE - 1;
  if((disk->total_sectors <= *sector) || (((*offset + size + DISK_SECTOR_SIZE - 1) >> DISK_SECTOR_BITS) > (disk->total_sectors - *sector)))
		return(cd_disk_errno = ERANGE); /* out of disk */
	return(E_OK);
}

/* Read data from the disk */
int cd_disk_read(cd_disk_t disk, unsigned long sector, unsigned long offset, int size, void *buf)
{
#ifdef STATIC_TMP_BUF
	static char tmp_buf[DISK_SECTOR_SIZE << DISK_CACHE_BITS];
#else
	char *tmp_buf;
#endif
	unsigned real_offset, size_tmp = DISK_SECTOR_SIZE << DISK_CACHE_BITS;
	/* First of all, check if the region is within the disk */
	if(cd_disk_adjust_range(disk, &sector, &offset, size) != E_OK)
		return(cd_disk_errno);
	real_offset = offset;
#ifndef STATIC_TMP_BUF
	/* Allocate a temporary buffer */
	tmp_buf = (char *)malloc(size_tmp);
  if(tmp_buf == NULL)
    return(cd_disk_errno = ENSMEM);
#endif
	/* Until SIZE is zero... */
	while(size)
	{
		/* For reading bulk data.  */
		unsigned long start_sector = sector & ~(DISK_CACHE_SIZE - 1);
		int pos = (sector - start_sector) << DISK_SECTOR_BITS;
		int len = ((DISK_SECTOR_SIZE << DISK_CACHE_BITS) - pos - real_offset);
		/* Fetch the cache */
		char *data = cd_disk_cache_fetch(disk->dev_id, disk->id, start_sector);
		if(len > size)
			len = size;
		if(data != NULL)
		{
			/* Just copy it! */
			memcpy(buf, data + pos + real_offset, len);
			cd_disk_cache_unlock(disk->dev_id, disk->id, start_sector);
		}
		else
		{
			/* Otherwise read data from the disk actually */
			if((start_sector + DISK_CACHE_SIZE > disk->total_sectors)
			 || cd_disk_read_sectors(start_sector, DISK_CACHE_SIZE, tmp_buf))
	    {
				/* Failed. Instead, just read necessary data */
				unsigned num = ((size + real_offset + DISK_SECTOR_SIZE - 1) >> DISK_SECTOR_BITS);
				char *p = (char *)malloc(num << DISK_SECTOR_BITS);
				if(p == NULL)
				{
					cd_disk_errno = ENSMEM;
					goto finish;
				}
	      cd_disk_errno = E_OK;
				memcpy(p, tmp_buf, size_tmp);
#ifndef STATIC_TMP_BUF
				free(tmp_buf);
				tmp_buf = NULL;
#endif
				if(!cd_disk_read_sectors(sector, num, p))
					memcpy(buf, p + real_offset, size);
				/* This must be the end */
				goto finish;
			}
			/* Copy it and store it in the disk cache */
			memcpy(buf, tmp_buf + pos + real_offset, len);
			cd_disk_cache_store(disk->dev_id, disk->id, start_sector, tmp_buf);
		}
		sector = start_sector + DISK_CACHE_SIZE;
		buf = (char *)buf + len;
		size -= len;
		real_offset = 0;
	}
finish:
#ifndef STATIC_TMP_BUF
	if(tmp_buf != NULL)
		free(tmp_buf);
#endif
	return(cd_disk_errno);
}

/* called from init.c */
int cd_disk_boot(void)
{
	static char inqdata[36], vendor[9], product[17], revision[5];
	static unsigned char tocdata[14], dvddata[84];
	unsigned long MaxLen, BlockSize, BlockLen;
	long rc;
	tBusInfo Bus;
	tDevInfo Dev;
	tHandle handle;
	int ret = 0, found = 0, type = 0;
	SetBlockSize(CD_SECTOR_SIZE);
	init_scsiio();
	if(scsicall != NULL)
	{
		rc = InquireSCSI(cInqFirst, &Bus);
		while(rc == 0)
		{
			rc = InquireBus(cInqFirst, Bus.BusNo, &Dev);
			while(rc == 0)
			{
				rc = Open(Bus.BusNo, &Dev.SCSIId, &MaxLen);
				if(rc < 0L)
					continue;
				handle = (tHandle)rc;
        SetScsiUnit(handle, 0, MaxLen);       
				memset(inqdata, 0, sizeof(inqdata));
				rc = Inquiry(inqdata, 0, 0, sizeof(inqdata));
				if(rc == 0)
				{
					if((*inqdata&0x1f) == ROMDEV) /* CD-ROM / DVD drive */
					{
						int medium = 0, in_progress = 0;
						unsigned long timeout = *(volatile unsigned long *)_hz_200 + (5 * 200);
						strncpy(vendor,inqdata+8,8);
						vendor[8] = '\0';
						strncpy(product,inqdata+16,16);
						product[16] = '\0';
						strncpy(revision,inqdata+32,4);
						revision[4] = '\0';
						while(!medium)
						{
							rc = ReadCapacity(0, &BlockSize, &BlockLen);
							if(rc == 0)
								medium = 1;
							else if(rc == 2)
							{
								unsigned char asc = ReqBuff[12];
								unsigned char ascq = ReqBuff[13]; 
								if(asc == 0x3A) /* MEDIUM NOT PRESENT */
									medium = -1;
								else if((asc == 0x04) && (ascq == 0x01) && !in_progress) /* IN PROGRESS OF BECOMING READY */
								{
									timeout = *(volatile unsigned long *)_hz_200 + (30 * 200);
									in_progress = 1;
								}
								Wait(20);
								if(*(volatile unsigned long *)_hz_200 >= timeout)
									medium = -1;
							}
							else
								medium = -1;
						}
						switch(BlockLen)
						{
							case 0:
							case 2340:
							case 2352:
								BlockLen = CD_SECTOR_SIZE;
								break;
						}
						if((medium > 0) && (BlockLen == CD_SECTOR_SIZE))
						{
							rc = ReadDVDStucture(0, 0, 0, 0, dvddata, sizeof(dvddata));  /* DVD Struct Physical */
							if(rc == 0)
							{
								switch(dvddata[4] >> 4) /* Book Type */
								{
									case 0: type = DVD_ROM; break;
									case 1: type = DVD_RAM; break;
									case 2: type = DVD_R; break;
									case 3: type = DVD_RW; break;
									case 8: type = DVD_PLUS_R; break;
									case 9: type = DVD_PLUS_RW; break;
									default: rc = -1; break;
								}
							}
							if(rc != 0)
							{
								rc = ReadTOC(1, 2, 0, tocdata, sizeof(tocdata)); /* Full TOC */
								if((rc == 0) && (tocdata[7] == 0xA0))
								{
									if(tocdata[13] == 0x00)
									{
										if(tocdata[5] & 0x04)
											type = CD_DATA;
										else 
											type = CD_DA; 
									}
									else if(tocdata[13] == 0x10)
										type = CD_I;
									else if(tocdata[13] == 0x20) 
										type = CD_XA;
								}
							}
							if((rc == 0) && ((type == CD_DATA) || (type == CD_XA) || (type >= DVD_ROM)) && !found)
							{
								char *label = NULL;
								long total_sectors = 0;
								cd_disk_errno = 0;
								memset(&global_disk, 0, sizeof(struct cd_disk));
								global_disk.dev_id = 1;
								global_disk.id = 1;
								global_disk.total_sectors = BlockSize << (CD_SECTOR_BITS - DISK_SECTOR_BITS);
								rc = (long)iso9660_label(&global_disk, &label, &total_sectors);
								if((rc == E_OK) || (rc == EMEDIA))
								{
									static char *menu[] = {" Ignore      ", " Boot CD/DVD "};
									kprint("\33\142\64\0");
									kprint("%s  %d.%d", Bus.BusName, Dev.SCSIId.hi, Dev.SCSIId.lo);
									kprint("\33\142\77\0 ");
									kprint(" %s %s %s ... %s\r\n", vendor, product, revision, (label != NULL) ? label : "");
									if(boot_menu(0, 2, "", menu, 2))
									{
										if(rc == EMEDIA)
										{
											if((global_disk.dev_id = (unsigned long)install_cd_disk()) != 0) /* CD-backup: TOS FAT16 partition */
												found = 1;
											else
											{
												kprint("CD-disk not installed (not TOS FAT16 or ISO9660)\r\n");
												Crawcin();
											}
										}
										else /* ISO */
										{
											extern long install_xbra(short vector, void *handler);
											extern void det_gemdos(void);
											extern long old_vector_gemdos;
											total_sectors <<= (CD_SECTOR_BITS - DISK_SECTOR_BITS);
											if(total_sectors && (total_sectors < global_disk.total_sectors))
												global_disk.total_sectors = total_sectors;
											old_vector_gemdos = install_xbra(33, det_gemdos); /* TRAP #1 */
											found = 1;
										}
									}
									if(found)
									{
//										*_bootdev = (short)global_disk.dev_id;
//										Dsetdrv((short)global_disk.dev_id);
										kprint("\33\142\64\0");
										kprint("CD-disk installed in %c", (char)global_disk.dev_id + 'A');
										kprint("\33\142\77\0\r\n");
									}
								}
								if(label != NULL)
									free(label);								
							}
						}
					}
					Close(handle);					
				}
				rc = InquireBus(cInqNext, Bus.BusNo, &Dev);
			}			
			rc = InquireSCSI(cInqNext, &Bus);
		}
	}
	if(!found)
		cd_disk_cache_free_all();
	return(ret);
}
