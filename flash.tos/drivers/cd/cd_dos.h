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

#ifndef _CD_DOS_H
#define _CD_DOS_H
 
struct cd_file
{
  struct cd_disk *disk;
	int offset;
	int size;
	unsigned int time;
  void *data;
  /* This is called when a sector is read. Used only for a disk device. */
  void (*read_hook)(unsigned sector, unsigned offset, unsigned length);
};

typedef struct cd_file *cd_file_t;

long cd_dfree(long *buf, long driveno);
long cd_dcreate(const char *path);
long cd_ddelete(const char *path);
long cd_dsetpath(const char *fname);
long cd_fcreate(const char *fname, long attr);
long cd_fopen(const char *fname, long mode);
long cd_fclose(long handle);
long cd_fread(long handle, long count, void *buf);
long cd_fwrite(long handle, long count, void *buf);
long cd_fdelete(const char *fname);
long cd_fseek(long offset, long handle, long seekmode);
long cd_fattrib(const char *filename, long wflag, long attrib);
long cd_pexec(long mode, const char *prg, const char *cmdl, const char *envp);
void cd_pterm(void);
long cd_fsfirst(const char *filename, long attr);
long cd_fsnext(void);
long cd_frename(const char *oldname, const char *newname);
long cd_fdatime(short *timeptr, long handle, long wflag);

#endif /* _CD_DOS_H */
