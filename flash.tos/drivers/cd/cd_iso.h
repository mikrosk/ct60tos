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

#ifndef _CD_ISO_H
#define _CD_ISO_H

int iso9660_label(cd_disk_t disk, char **label, long *total_sectors);
int iso9660_dir(cd_disk_t disk, const char *path, int (*hook)());
int iso9660_open(cd_file_t file, const char *name);
int iso9660_read(cd_file_t file, char *buf, int len);
int iso9660_close(cd_file_t file);

#endif /* _CD_ISO_H */
