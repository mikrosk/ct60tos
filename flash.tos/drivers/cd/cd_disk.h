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

#ifndef _CD_DISK_H
#define _CD_DISK_H
 
#define DISK_SECTOR_SIZE  512
#define DISK_SECTOR_BITS	  9
#define CD_SECTOR_SIZE   2048
#define CD_SECTOR_BITS     11

/* The size of a disk cache in sector units. */
#define DISK_CACHE_SIZE     8
#define DISK_CACHE_BITS     3

/* The maximum number of disk caches.  */
#define DISK_CACHE_NUM	 125 // was 1021

struct dirhook_info
{
	unsigned dir:1;
	unsigned hidden:1;
	unsigned mtimeset:1;
	unsigned case_insensitive:1;
	unsigned long mtime;
	unsigned long size;
};

struct cd_disk
{
  unsigned long total_sectors;
  unsigned long dev_id;
  unsigned long id; /* The id used by the disk cache manager  */
  void *data;
};

typedef struct cd_disk *cd_disk_t;

int cd_disk_read_sectors(unsigned long sector_start, unsigned long num_sectors, void *buffer);
int cd_disk_read(cd_disk_t disk, unsigned long sector, unsigned long offset, int size, void *buf);
int cd_disk_boot(void);

#endif /* _CD_DISK_H */
