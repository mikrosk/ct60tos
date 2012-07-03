/* TOS 4.04 DOS ISO9660 boot for the CT60/CTPCI & Coldfire boards
 * Didier Mequignon 2011, e-mail: aniplay@wanadoo.fr
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

#include <mint/osbind.h>
#include <string.h>
#include "gemerror.h"
#include "cd_dos.h"
#include "cd_disk.h"
#include "cd_iso.h"

#undef DEBUG

#ifdef COLDFIRE
#define USE_BDOS
#endif

#ifdef USE_BDOS
#define BIOS_H
#define BPB void
#include "../bdos/fs.h"
#else /* GEMDOS */

/* PD - Process Descriptor */

#define NUMSTD          6 /* number of standard files */
#define PDCLSIZE     0x80 /* size of command line in bytes  */
#define NUMCURDIR      16 /* number of entries in curdir array */
#define OPNFILES       32
#define FA_RO        0x01 /* write protected */
#define FA_HIDDEN    0x02
#define FA_SYSTEM    0x04
#define FA_VOL       0x08 /* label */
#define FA_ARCHIVE   0x20
#define FA_SUBDIR    0x10 /* subdirectory */
#endif /* USE_BDOS */

#define MAX_NAME      128 /* max 255 for SUBDTA structure */
#define MAX_PATH      256

#define PE_LOADGO       0
#define PE_LOAD         3
#define PE_GO           4
#define PE_BASEPAGE     5
#define PE_GOTHENFREE   6
#define PE_BASEPAGEFREE 7

typedef struct dtainfo
{
	char dt_name[12];  /*  file name: filename.typ     00-11   */
	long dt_pos;       /*  dir position                12-15   */
	void *dt_dnd;      /*  pointer to DND              16-19   */
	char dt_attr;      /*  attributes of file          20      */
	                   /*  --  below must not change -- [1]    */
	char dt_fattr;     /*  attrib from fcb             21      */
	short dt_time;     /*  time field from fcb         22-23   */
	short dt_date;     /*  date field from fcb         24-25   */
	long dt_fileln;    /*  file length field from fcb  26-29   */
	char dt_fname[14]; /*  file name from fcb          30-43   */
} DTA;

typedef struct subdtainfo
{
	char dt_fattr;
	unsigned char dt_time[2];
	unsigned char dt_date[2];
	unsigned char dt_fileln[4];
	char dt_fname[14];
	unsigned char dt_len_lfname;
	char dt_lfname[1];
} SUBDTA;

typedef struct pgmhdr01 
{
	/*  magic number is already read  */
	long h01_tlen;  /* length of text segment */
	long h01_dlen;  /* length of data segment */
	long h01_blen;  /* length of bss segment */
	long h01_slen;  /* length of symbol table */
	long h01_res1;  /* reserved - always zero */
#define PF_FASTLOAD  0x0001
#define PF_TTRAMLOAD 0x0002
#define PF_TTRAMMEM  0x0004
	long h01_flags; /* flags */
	short h01_abs;   /* not zero if no relocation */
} PGMHDR01;

#ifndef USE_BDOS

typedef struct proc_desc /* this is the basepage format */
{
	/* 0x00 */
	long p_lowtpa;
	long p_hitpa;
	long p_tbase;
	long p_tlen;
	/* 0x10 */
	long p_dbase;
	long p_dlen;
	long p_bbase;
	long p_blen;
	/* 0x20 */
	DTA *p_xdta;
	struct proc_desc *p_parent;  /* parent PD */
	short p_flags;
	short p_0fill[1];
	char *p_env;
	/* 0x30 */
	char p_uft[NUMSTD]; /* index into sys file table for std files */
#ifdef USE_BDOS /* BDOS and MiNT */
	char p_lddrv;
	char p_curdrv;
	short p_1fill[4];
#else /* GEMDOS TOS404 */
	short p_1fill[1];
  /* 0x38 */
	short p_curdrv;
	short max_handle;
	long *p_handle;
#endif
	/* 0x40 */
	char p_curdir[NUMCURDIR]; /* index into sys dir table */
	/* 0x50 */
	long p_2fill[4];
	/* 0x60 */
	long p_3fill[2];
	long p_dreg[1]; /* dreg[0] */
	long p_areg[5]; /* areg[3..7] */
	/* 0x80 */
	char p_cmdlin[PDCLSIZE];
} PD __attribute__ ((__packed__));

#endif /* USE_BDOS */

struct pd_handle
{
	PD *proc;
	long handle;
	struct cd_file file;
	int max_dirs;
	int nb_dirs;
	int dir_count;
	SUBDTA *dirs;
	SUBDTA *end_dirs;
	char *long_filename;
} cd_pd_handle[OPNFILES];

#define malloc(a) Mxalloc(a, 3)
#define free(a) Mfree(a)

extern PD *run;
extern int cd_disk_errno;
extern struct cd_disk global_disk;
extern void kprint(const char *fmt, ...);

static char cur_path[MAX_PATH + 1];

static long check_drive(const char *path)
{
	long drive = (long)run->p_curdrv;
	if(path[1] == ':')
	{
		if((path[0] >= 'A' && path[0] <= 'Z') || (path[0] >= 'a' && path[0] <= 'z'))
			drive = ((long)path[0] & 0x1F) - 1;
	}
	if(drive != global_disk.dev_id)
		return(EDRIVE); /* for call default GEMDOS routine */
	return(E_OK);
}

static long search_handle(long handle, long *index)
{
	long i;
	if(handle < 0)
		return(EDRIVE); /* for call default GEMDOS routine */
#ifdef USE_BDOS
	if((handle < NUMSTD) || (handle >= OPNFILES))
		return(EIHNDL); /* invalid handle */
	if(!sft[handle - NUMSTD].f_use)
		return(EIHNDL); /* invalid handle */
#else /* GEMDOS */
	if((handle >= (long)run->max_handle))
		return(EIHNDL); /* invalid handle */
	if(!run->p_handle[handle])
		return(EIHNDL); /* invalid handle */
#endif
	for(i = 0; i < OPNFILES; i++)
	{
		if((cd_pd_handle[i].proc == NULL) || (cd_pd_handle[i].handle == '_DTA'))
			continue;
		if((cd_pd_handle[i].proc == run) && (cd_pd_handle[i].handle == handle))
		{
			*index = i;
			return(E_OK);
		}
	}
	return(EDRIVE); /* for call default GEMDOS routine */
}

static void dir2str(const char *src, char *nm)
{
	long i = 8;
	while(i-- && *src != ' ')
		*nm++ = *src++;
	src += i + 1;
	if(*src > ' ')
	{
		*nm++ = '.';
		i = 3;
		while (i-- && *src != ' ')
			*nm++ = *src++;
	}
	*nm = '\0';
}

static void str2dir(const char *src, char *nm)
{
	long i = 8;
	while(i--)
	{
		if(*src && *src != '.')
			*nm++ = *src++;
		else
			*nm++ = ' ';
	}
	if(*src == '.')
		src++;
	i = 3;
	while(i--)
	{
		if(*src)
			*nm++ = *src++;
		else
			*nm++ = ' ';
	}
}

#ifndef USE_BDOS

static char uc(char c)
{
	return((c >= 'a') && (c <= 'z') ? c & 0x5F : c);
}

static void builds(char *src, char *dst)
{
#define isnotdelim(x) ((x) && (x != '*') && (x != '\\') && ( x!= '.') && ( x!= ' '))
	int i;
	char c;
	char *p;
	for(i = 0; (i < 8) && isnotdelim(*src); *dst++ = uc(*src++), i++);
	if(i == 8)
	{
		while(*src && (*src != '.') && (*src != '\\'))
				src++;
	}
	c = (*src == '*') ? '?' : ' ';
	if(*src == '*') /*  skip over wildcard char  */
		src++;
	p = strrchr(src, '.');
	if(p != NULL)
		src = p;
	if(*src == '.') /*  skip over extension delim   */
		src++;
	for(; i < 8; *dst++ = c, i++);
	for(i = 0 ; (i < 3) && isnotdelim(*src); *dst++ = uc(*src++), i++);
	c = (*src == '*') ? '?' : ' ';
	for(; i < 3; *dst++ = c, i++); /* ext */
}

#endif /* USE_BDOS */

static int match(const char *s1, const char *s2)
{
	int i;
	for(i = 0; i < 11; i++, s1++, s2++)
	{
		if((*s1 != '?') && (uc(*s1) != uc(*s2)))
			return(0);
	}
	if((*s1 != FA_VOL) && (*s1 != FA_SUBDIR) && !(*s2))
		return(1);
	return((int)(*s1 & *s2));
}

/*
 * pgfix01 - do the next set of fixups
 *
 *  returns:
 *      addr of last modified longword in code segment (cp)
 *      0 if error or done
 *      stat01:
 *              > 0: all offsets in bss used up, read in more
 *              = 0: offset of 0 encountered, no more fixups
 *              < 0: EPLFMT (load file format error)
 */
static long pgfix01(long nrelbytes, unsigned char *tbase, unsigned char *bbase, unsigned char **lastcp)
{
	unsigned char *cp = *lastcp; /* code pointer */
	unsigned char *rp = bbase ; /* relocation info pointer = start of bss seg */
	long n = nrelbytes; /* nb of relocation bytes */
	while(n-- && *rp)
	{
		if(*rp == 1)
			cp += 0xfe;
		else
		{
			cp += *rp ; /* add the byte at rp to cp, don't sign ext */
			if(cp >= bbase)
				return(EPLFMT);
			*((long *)cp) += (long)tbase;
		}
		rp++;
	}
	*lastcp = cp; /* save code pointer */
	return((++n == 0)  ? 1 : 0);
}
 
static int hook_fsfirst(const char *filename, const struct dirhook_info *info)
{
	char name[12];
	DTA *dta = (DTA *)run->p_xdta;
	struct pd_handle *ph = &cd_pd_handle[dta->dt_pos];
	SUBDTA *ps = ph->end_dirs;
	if((dta->dt_pos >= OPNFILES) || (ph->proc != run) || (ph->handle != '_DTA'))
		return(1);
	if(!filename[0] || ((filename[0] == '.') && (!filename[1] || ((filename[1] == '.') && !filename[2]))))
		return(0);
	if((dta->dt_attr == FA_SUBDIR) && !info->dir)
		return(0);
	builds((char *)filename, name);
	if((long)ps + strlen(filename) + sizeof(SUBDTA) > (long)&ph->dirs[ph->max_dirs])
	{
		long size = sizeof(SUBDTA) * ph->max_dirs; /* size with SUBDTA without long filename in the structure */
		long used_size = (long)ps - (long)ph->dirs;
		ps = (SUBDTA *)malloc(size * 2);
		if(ps != NULL)
		{
			memcpy(ps, ph->dirs, size);
			memset(&ps[ph->max_dirs], 0, size);
			ph->max_dirs <<= 1;
			free(ph->dirs);
			ph->dirs = ps;
			ph->end_dirs = (SUBDTA *)((long)ps + used_size);
			ps = ph->end_dirs;
		}
		else
			return(1); /* ouf of memory => stops */
	}
	ph->nb_dirs++;
	ps->dt_fattr = info->dir ? FA_SUBDIR : info->hidden ? FA_HIDDEN : 0;
	dir2str(name, ps->dt_fname);
	if(ph->long_filename != NULL)
	{
		strncpy(ps->dt_lfname, filename, MAX_NAME);
		ps->dt_len_lfname = (unsigned char)strlen(ps->dt_lfname);
	}
	else
	{
		ps->dt_lfname[0] = '\0';
		ps->dt_len_lfname = 0;
	}
	*(unsigned long *)ps->dt_fileln = info->size;
	*(unsigned short *)ps->dt_time = (unsigned short)info->mtime;
	*(unsigned short *)ps->dt_date = (unsigned short)(info->mtime >> 16);
	ph->end_dirs = (SUBDTA *)((unsigned long)ps + sizeof(SUBDTA) + (unsigned long)ps->dt_len_lfname);
	return(0);
}

static long i_fsfirst(char *path, long attr, char *long_filename)
{
	char *p;
	struct pd_handle *ph;
	struct info;
	long index, ret;
	DTA *dta = (DTA *)run->p_xdta;
	dta->dt_dnd = NULL;
	dta->dt_attr = (char)attr;
	memset(dta->dt_name, 0, 12);
	p = strrchr(path, '/');
	if(p != NULL)
	{
		strncpy(&dta->dt_name[0], ++p, 12);
		*p = '\0';
	}
	index = 0;
	while((index < OPNFILES) && (cd_pd_handle[index].proc != run))
		index++;
	ph = &cd_pd_handle[index];
	if((ph->proc == run) && (ph->handle == '_DTA') && (ph->dirs == NULL))
		memset(ph, 0, sizeof(struct pd_handle));
	if((ph->proc == run) && (ph->handle == '_DTA')
	 && (ph->dirs != NULL) && ph->max_dirs)
	{
		/* abnormal, directory not read totally before this command with the same PD */
		ph->nb_dirs = ph->dir_count = 0;
		ph->end_dirs = ph->dirs;
	}
	else
	{
		index = 0;
		while((index < OPNFILES) && (cd_pd_handle[index].proc != NULL))
			index++;
		ph = &cd_pd_handle[index];
		if(ph->proc != NULL)
			return(ENMFIL); /* not found */
		ph->handle = '_DTA';
		ph->max_dirs = 64;
		ph->nb_dirs = ph->dir_count = 0;
		ph->end_dirs = ph->dirs = (SUBDTA *)malloc(sizeof(SUBDTA) * ph->max_dirs);
		if(ph->dirs == NULL)
			return(ENMFIL); /* not found */
		memset(ph->dirs, 0, sizeof(SUBDTA) * ph->max_dirs);
		ph->proc = run;
	}
	ph->long_filename = long_filename;
	dta->dt_pos = index;
	cd_disk_errno = 0;
	ret = (long)iso9660_dir(&global_disk, path, hook_fsfirst);
	if(ret == E_OK)
	{
		char name[12], filter[12];
		char *label = NULL;
		SUBDTA *ps1 = ph->dirs;
		ph->end_dirs = ps1; 
		int i = 0;
		while(i < ph->nb_dirs) /* fix DOS with same names 8:3 */
		{
			int j = 0, count = 0;
			SUBDTA *ps2 = ph->dirs;
			p = ps1->dt_fname;
			while(j < ph->nb_dirs)
			{
				if(ps1 != ps2)
				{
					if(!strcmp(p, ps2->dt_fname))
					{
						count++;
						if(count < 10)
						{
							str2dir(ps2->dt_fname, name);
							name[6] = '~';
							name[7] = (char)count + '0';
							dir2str(name, ps2->dt_fname);
						}
						else if(count < 100)
						{
							str2dir(ps2->dt_fname, name);
							name[5] = '~';
							name[6] = (char)(count / 10) + '0';
							name[7] = (char)(count % 10) + '0';
							dir2str(name, ps2->dt_fname);
						}
					}
				}
				ps2 = (SUBDTA *)((unsigned long)ps2 + sizeof(SUBDTA) + (unsigned long)ps2->dt_len_lfname);
				j++;
			}
			if(count)
			{
				str2dir(p, name);
				name[6] = '~';
				name[7] = '0';
				dir2str(name, p);
			}
			ps1 = (SUBDTA *)((unsigned long)ps1 + sizeof(SUBDTA) + (unsigned long)ps1->dt_len_lfname);
			i++;		
		}
		if((attr & FA_VOL) && (path[0] == '/') && !path[1]
		 && (iso9660_label(&global_disk, &label, NULL) == E_OK) && (label != NULL))
		{
			char name[12];
			builds(label, name);
			free(label);
			dta->dt_fattr = FA_VOL;
			dir2str(name, dta->dt_fname);
			if(ph->long_filename != NULL)
				strncpy(ph->long_filename, label, MAX_NAME);
			dta->dt_fileln = 0;
			dta->dt_time = dta->dt_date = 0;
			ret = E_OK;
		}
		else /* file or directory */
		{		
			ret = ENMFIL; /* not found */
			if(ph->nb_dirs)
			{
				SUBDTA *ps = ph->end_dirs;
				builds(dta->dt_name, filter);
				filter[11] = (char)dta->dt_attr;
				while(ph->dir_count < ph->nb_dirs)
				{
					ph->dir_count++;
					str2dir(ps->dt_fname, name);
					name[11] = ps->dt_fattr;
					if(match(filter, name))
					{
						memcpy(&dta->dt_fattr, ps, sizeof(SUBDTA) - 2);
						if(ph->long_filename != NULL)
							strncpy(ph->long_filename, ps->dt_lfname, MAX_NAME);
						ph->end_dirs = (SUBDTA *)((unsigned long)ps + sizeof(SUBDTA) + (unsigned long)ps->dt_len_lfname);
						ret = E_OK;
						break;
					}
					ps = (SUBDTA *)((unsigned long)ps + sizeof(SUBDTA) + (unsigned long)ps->dt_len_lfname);
				}			
			}			
		}
	}
 	if(((ph->dir_count >= ph->nb_dirs) || (ph->long_filename != NULL)) && (ph->dirs != NULL))
 	{
		free(ph->dirs);
		ph->dirs = NULL;
	}
	if(ret != E_OK)
	{
		if(ph->dirs != NULL)
			free(ph->dirs);
		memset(ph, 0, sizeof(struct pd_handle));
	}
	return(ret);
}

static long dos2unix(char *path)
{
	char save_path[MAX_PATH + 1], original_subdir[MAX_NAME + 1];
	char *p, *p2;
	int slash_count = 0;
	long ret;	
	while((p = strrchr(path, '\\')) != NULL)
	{
		*p = '/';
		slash_count++;
	}
	if(!slash_count)
		return(E_OK);
	if((slash_count == 1) && (path[0] == '/')) /* main directory */
		return(E_OK);
	strncpy(save_path, path, MAX_PATH);
	if(path[0] == '/')
	{
		path[1] = '\0';
		slash_count--;
		p = &save_path[1];
	}
	else
	{
		path[0] = '\0';
		p = save_path;
	}
	while(slash_count > 0)
	{
		p2 = strchr(p, '/'); /* extract DOS subdir 8:3 */
		if(p2 == NULL)
			return(EPTHNF); /* abnormal */
	  *p2 = '\0';
		strcat(path, p); /* add 8:3 DOS subdir to unix path */
		if((ret = i_fsfirst(path, FA_SUBDIR, original_subdir)) != E_OK)
			return(EPTHNF); /* not found */	
		p = &p2[1]; /* next subdir or name */
		p2 = strrchr(path, '/');
		if((p2 != NULL) && (original_subdir != NULL))
		{
			p2[1] = '\0';
			strcat(path, original_subdir); /* add unix subdir */
			strcat(path, "/");
		}
		else /* abnormal */
			return(EPTHNF);
		slash_count--;
	}	
	strcat(path, p);
	return(E_OK);
}

long cd_dfree(long *buf, long driveno)
{
	long drive = (long)run->p_curdrv;
	if(driveno)
		drive = driveno - 1;
	if(drive != global_disk.dev_id)
		return(EDRIVE); /* for call default GEMDOS routine */
	buf[0] = 0;
	buf[1] = global_disk.total_sectors / 2;
	buf[2] = DISK_SECTOR_SIZE;
	buf[3] = 2;	
#ifdef DEBUG
	kprint("cd_dfree(%d) = %d %d %d %d\r\n", driveno, buf[0], buf[1], buf[2], buf[3]);
#endif	
	return(E_OK);
}

long cd_dcreate(const char *path) // xmkdir TOS404 0xE1965A
{
	long ret = check_drive(path);
	if(ret != E_OK)
		return(ret);
#ifdef DEBUG
	kprint("cd_dcreate(%s)\r\n", path);
#endif	
	return(EACCDN); /* access denied */
}

long cd_ddelete(const char *path) // xrmdir TOS404 0xE198FA 
{
	long ret = check_drive(path);
	if(ret != E_OK)
		return(ret);
#ifdef DEBUG
	kprint("cd_dcreate(%s)\r\n", path);
#endif	
	return(EACCDN); /* access denied */
}

long cd_fcreate(const char *fname, long attr) // xcreate TOS404 0xE1AEF6
{
	long ret = check_drive(fname);
	if(attr);
	if(ret != E_OK)
		return(ret);
#ifdef DEBUG
	kprint("cd_fcreate(%s, %d)\r\n", fname, attr);
#endif	
	return(EACCDN); /* access denied */
}

long cd_dsetpath(const char *fname) // xchdir TOS404 0xE19218
{
	DTA *dta = (DTA *)run->p_xdta;
	DTA dta_dsetpath;
	char path[MAX_PATH]; 
	long ret = check_drive(fname);
	if(ret != E_OK)
		return(ret);
	run->p_xdta = (void *)&dta_dsetpath;
	memset(&dta_dsetpath, 0, sizeof(DTA));
	if(fname[1] == ':')
		strcpy(path, fname + 2);
	else
		strcpy(path, fname);
	ret = dos2unix(path);
	run->p_xdta = (void *)dta; /* restore dta */
#ifdef DEBUG
	kprint("cd_dsetpath(%s => %s) = %d\r\n", fname, path, ret);
#endif	
	if(ret == E_OK)
		strncpy(cur_path, fname, MAX_PATH);
	return(ret);
}

long cd_fopen(const char *fname, long mode) // xopen TOS404 0xE1AF84
{
	DTA *dta = (DTA *)run->p_xdta;
	DTA dta_fopen;
	char path[MAX_PATH + 1], original_filename[MAX_NAME + 1];
	char *p;
	long i = 0, index;
#ifdef USE_BDOS
	long max = OPNFILES;
#else /* GEMDOS */
	long max = (long)run->max_handle;
#endif
	cd_file_t file;
	long ret = check_drive(fname);
	if(ret != E_OK)
	  return(ret);
	if(mode == 1) /* write */
		return(EACCDN); /* access denied */
	run->p_xdta = (void *)&dta_fopen;
	memset(&dta_fopen, 0, sizeof(DTA));
	if(fname[1] == ':')
		strcpy(path, fname + 2);
	else
		strcpy(path, fname);
	if((ret = dos2unix(path)) != E_OK)
	{
		run->p_xdta = (void *)dta; /* restore dta */
#ifdef DEBUG
		kprint("cd_fopen(%s => %s, %d) = %d (dos2unix)\r\n", fname, path, mode, ret);
#endif	
		return(EPTHNF);
	}
	if((ret = i_fsfirst(path, FA_SYSTEM + FA_HIDDEN + FA_RO, original_filename)) != E_OK)
	{
		run->p_xdta = (void *)dta; /* restore dta */
#ifdef DEBUG
		kprint("cd_fopen(%s => %s, %d) = %d (i_fsfirst)\r\n", fname, path, mode, ret);
#endif	
		return(EFILNF);
	}
	if((original_filename != NULL) && ((p = strrchr(path, '/')) != NULL))
	{
		p[1] = '\0';
		strcat(path, original_filename);
	}
	run->p_xdta = (void *)dta; /* restore dta */
	ret = ENHNDL; /* too many open files */
	for(i = NUMSTD; i < max; i++)
	{
#ifdef USE_BDOS
		if(!sft[i - NUMSTD].f_use)
#else /* GEMDOS */
		if(!run->p_handle[i])
#endif
		{
			index = 0;
			while((index < OPNFILES) && (cd_pd_handle[index].proc != NULL))
				index++;
			if(cd_pd_handle[index].proc != NULL)
				return(ENHNDL); /* too many open files */
#ifdef USE_BDOS
			sft[i - NUMSTD].f_ofd = NULL;
			sft[i - NUMSTD].f_own = run;
			sft[i - NUMSTD].f_use = 1;
#else /* GEMDOS */
			run->p_handle[i] = i;
#endif
			cd_pd_handle[index].proc = run;
			cd_pd_handle[index].handle = i;
			file = &cd_pd_handle[index].file;
			file->disk = &global_disk;
			cd_disk_errno = 0;
			ret = (long)iso9660_open(file, path);
#ifdef DEBUG
			kprint("cd_fopen(%s => %s, %d) = %d\r\n", fname, path, mode, (ret < 0) ? ret : i);
#endif	
			break;
		}
	}
	return((ret < 0) ? ret : i);
}

long cd_fclose(long handle) // xclose TOS404 0xE1A9F4, ixclose TOS404 0xE1AA0A
{
	long index;
	cd_file_t file;
	long ret = search_handle(handle, &index);
	if(ret != E_OK)
		return(ret);
#ifdef DEBUG
	kprint("cd_fclose(%d)\r\n", handle);
#endif	
#ifdef USE_BDOS
	sft[handle - NUMSTD].f_ofd = NULL;
	sft[handle - NUMSTD].f_own = NULL;
	sft[handle - NUMSTD].f_use = 0;
#else /* GEMDOS */
	run->p_handle[handle] = 0;
#endif
	file = &cd_pd_handle[index].file;
	file->disk = &global_disk;
	iso9660_close(file);
	memset(&cd_pd_handle[index], 0, sizeof(struct pd_handle));
	return(E_OK);
}

long cd_fread(long handle, long count, void *buf) // xread TOS404 0xE1AD34
{
	long index;
	cd_file_t file;
	long ret = search_handle(handle, &index);
	if(ret != E_OK)
		return(ret);
	file = &cd_pd_handle[index].file;
	file->disk = &global_disk;
	if(count < 0)
		return(ERANGE);
	if(file->offset + (int)count > file->size)
		count = (long)file->size - (long)file->offset;
	ret = (long)iso9660_read(file, buf, (int)count);
	if(ret >= 0)
		file->offset += (int)count;
#ifdef DEBUG
	kprint("cd_fread(%d, %d, 0x%08X) = %d\r\n", handle, count, buf,  (ret < 0) ? ret : count);
#endif	
	return((ret < 0) ? ret : count);
}

long cd_fwrite(long handle, long count, void *buf) // xwrite TOS404 0xE1ADFA
{
	long index;
	long ret = search_handle(handle, &index);
	if(ret != E_OK)
		return(ret);
#ifdef DEBUG
	kprint("cd_fwrite(%d, %d, 0x%08X)\r\n", handle, count, buf);
#endif	
	return(EACCDN); /* access denied */
}

long cd_fdelete(const char *fname) // xdelete TOS404 0xE1A18C
{
	long ret = check_drive(fname);
#ifdef DEBUG
	kprint("cd_fdelete(%s)\r\n", fname);
#endif	
	if(ret == E_OK)
		return(EACCDN); /* access denied */
  return(ret);
}

long cd_fseek(long offset, long handle, long seekmode) // xlseek TOS404 0xE1B246
{
	long index;
	cd_file_t file;
	long ret = search_handle(handle, &index);
	if(ret != E_OK)
		return(ret);
#ifdef DEBUG
	kprint("cd_fseek(%d, %d, %d)\r\n", offset, handle, seekmode);
#endif	 
	file = &cd_pd_handle[index].file;
	file->disk = &global_disk;
	switch(seekmode)
	{
		case 0: /* from begin */
			if((offset < 0) || (offset > (long)file->size))
				return(ERANGE);
			file->offset = (int)offset;
			break;
		case 1: /* from current */
			if((file->offset + (int)offset < 0) || (file->offset + (int)offset > file->size))
				return(ERANGE);
			file->offset += (int)offset;
			break;
		case 2: /* from end */
			if((file->size - (int)offset < 0) || (file->size - (int)offset > file->size))
				return(ERANGE);
			file->offset = file->size - (int)offset;
			break;
		default:
			return(ERANGE);			
		}
	return((long)file->offset);		
}

long cd_fattrib(const char *filename, long wflag, long attrib) // xchmod TOS404 0xE1A0D4
{
	long ret = check_drive(filename);
	if(ret != E_OK)
		return(ret);
#ifdef DEBUG
	kprint("cd_fattrib(%s, %d, %d)\r\n", filename, wflag, attrib);
#endif	 
	switch(wflag)
	{
		case 0: break;
		case 1: return(EACCDN); /* access denied */
		default: return(ERANGE);
	}
  return(1);
}

long cd_dgetpath(char *path, long driveno) // xgetdir TOS404 0xE1930E
{
	long drive = (long)run->p_curdrv;
	if(driveno)
		drive = driveno - 1;
	if(drive != global_disk.dev_id)
		return(EDRIVE); /* for call default GEMDOS routine */
	strncpy(path, cur_path, MAX_PATH);	
#ifdef DEBUG
	kprint("cd_dgetpath(%s, %d)\r\n", path, driveno);
#endif
	return(E_OK);
}

long cd_pexec(long mode, const char *prg, const char *cmdl, const char *envp)
{
	PD *pd;
	PGMHDR01 header;
	short magic;
	unsigned char *lastcp, *cp;
	long ret, handle, needed, max, relst, len;
	if((mode != PE_LOADGO) && (mode != PE_LOAD))
		return(EDRIVE); /* for call default GEMDOS routine */		
	ret = check_drive(prg);
	if(ret != E_OK)
	  return(ret);
#ifdef DEBUG
	kprint("cd_pexec(%d, %s, %s, %s)\r\n", mode, (prg != NULL) ? prg : "NULL", (cmdl != NULL) ? cmdl : "NULL", (envp != NULL) ? envp : "NULL");
#endif
	handle = cd_fopen(prg, 0);
	if(handle < 0)
		return(handle);
	ret = cd_fread(handle, 2, &magic);
	if(ret >= 0)
	{
		/* check and read program header */
		if(magic == 0x601A)
			ret = cd_fread(handle, sizeof(PGMHDR01), &header);
		else
			ret = EPLFMT;
	}
	if(ret < sizeof(PGMHDR01))
		ret = EPLFMT;
	if(ret < 0)
	{
		cd_fclose(handle);
#ifdef DEBUG
		kprint("cd_pexec() = %d\r\n", ret);
#endif
		return(ret);
	}
	pd = (PD *)Pexec(PE_BASEPAGE, prg, cmdl, envp); /* create basepage */
	if((long)pd < 0)
	{
		cd_fclose(handle);
#ifdef DEBUG
		kprint("cd_pexec() = %d\r\n", (long)pd);
#endif
		return((long)pd);
	}
	max = pd->p_hitpa - pd->p_lowtpa;
	needed = header.h01_tlen + header.h01_dlen + header.h01_blen + sizeof(PD);
	if(needed > max)
	{
		ret = ENSMEM;
		goto fail;
	}
	pd->p_flags = header.h01_flags;
	pd->p_tlen = header.h01_tlen;
	pd->p_dlen = header.h01_dlen;
	pd->p_blen = header.h01_blen;
	pd->p_tbase = (long)&pd[1]; /* 1st byte after PD */
	pd->p_dbase = pd->p_tbase + pd->p_tlen;
	pd->p_bbase = pd->p_dbase + pd->p_dlen;
#ifdef DEBUG
	kprint("cd_pexec pd 0x%08X, p_tbase 0x%08X, p_dbase 0x%08X, p_bbase 0x%08X, p_hitpa 0x%08X\r\n", pd, pd->p_tbase, pd->p_dbase, pd->p_bbase, pd->p_hitpa);
#endif
	ret = cd_fread(handle, pd->p_tlen + pd->p_dlen, (void *)pd->p_tbase); /* read in the program file (text and data) */
	if(ret < 0)
	{
fail:
#ifdef DEBUG
		kprint("cd_pexec() = %d\r\n", ret);
#endif
		Mfree(pd->p_env);
		Mfree(pd->p_lowtpa);
		cd_fclose(handle);
		return(ret);
	}
	if(!header.h01_abs)
	{
		ret = cd_fseek(header.h01_slen, handle, 1); /* seek symbols */
		if(ret < 0)
			goto fail;
		ret = cd_fread(handle, (long)sizeof(relst), &relst);
		if(ret < 0)
			goto fail;
		if(relst)
		{
			cp = (unsigned char *)pd->p_tbase + relst;
			if((cp < (unsigned char *)pd->p_tbase) || (cp >= (unsigned char *)pd->p_bbase)) /* make sure we didn't wrap memory or overrun the bss */
			{
				ret = EPLFMT;
				goto fail;
			}
			*((long *)cp) += pd->p_tbase; /* 1st fixup */
			lastcp = cp;
			len = pd->p_hitpa - pd->p_bbase;
			do
			{
				ret = cd_fread(handle, len, (void *)pd->p_bbase); /* read in more relocation info  */
				if(ret < 0)
					goto fail;
        ret = pgfix01(ret, (unsigned char *)pd->p_tbase, (unsigned char *)pd->p_bbase, &lastcp);
			}
			while(ret > 0);
			if(ret < 0)
				goto fail;
    }
    /* clear the bss or the whole heap */
    if(header.h01_flags & PF_FASTLOAD) /* clear only the bss */
    	memset((void *)pd->p_bbase, 0, pd->p_blen);
		else
    	memset((void *)pd->p_bbase, 0, (long)pd->p_hitpa - (long)pd->p_bbase); /* clear the whole heap */
	}
	cd_fclose(handle);
#ifdef COLDFIRE
#if (__GNUC__ > 3)
	asm volatile (" .chip 68060\n\t cpusha BC\n\t .chip 5485\n\t"); /* flush from CF68KLIB */
#else
	asm volatile (" .chip 68060\n\t cpusha BC\n\t .chip 5200\n\t"); /* flush from CF68KLIB */
#endif
#else /* 68060 */
	asm volatile (" cpusha BC\n\t");
#endif /* COLDFIRE */
#ifdef DEBUG
	kprint("cd_pexec pd 0x%08X\r\n", pd);
#endif
	return((long)pd);
}

void cd_pterm(void)
{
	long index;
	for(index = 0; index < OPNFILES; index++)
	{
		struct pd_handle *ph = &cd_pd_handle[index];
		if(ph->proc == run)
		{
#ifdef DEBUG
			kprint("cd_pterm()\r\n");
#endif
			if(ph->handle == '_DTA')
			{
				if(ph->dirs != NULL)
					free(ph->dirs);
			}
			else
			{
				cd_file_t file = &ph->file;
				file->disk = &global_disk;
				iso9660_close(file);				
			}
			memset(ph, 0, sizeof(struct pd_handle));
		}
	}
}

long cd_fsfirst(const char *filename, long attr) // xsfirst TOS404 0xE19ABE
{
	char path[MAX_PATH];
	long ret = check_drive(filename);
	if(ret != E_OK)
	  return(ret);
	if(filename[1] == ':')
		strcpy(path, filename + 2);
	else
		strcpy(path, filename);
	if(dos2unix(path) != E_OK)
		return(EPTHNF);
#ifdef DEBUG
	kprint("cd_fsfirst(%s => %s, 0x%02X) = ", filename, path, attr);
#endif	 	
	ret = i_fsfirst(path, attr, NULL);
#ifdef DEBUG
	kprint("%d\r\n", ret);
#endif	 	
	return(ret);
}

long cd_fsnext(void) // xsnext TOS404 0xE19C54
{
	DTA *dta = (DTA *)run->p_xdta;
	long index;
	for(index = 0; index < OPNFILES; index++)
	{
		if((cd_pd_handle[index].proc == run) && (cd_pd_handle[index].handle == '_DTA'))
		{
			struct pd_handle *ph = &cd_pd_handle[index];
			SUBDTA *ps = ph->end_dirs;
			char name[12], filter[12];
			long ret = ENMFIL; /* not found */
			if(ph->dirs == NULL)
			{
				memset(ph, 0, sizeof(struct pd_handle));
#ifdef DEBUG
//				kprint("cd_fsnext() = %d\r\n", ret);
#endif	 
				return(ret); /* not found */
			}
			builds(dta->dt_name, filter);
			filter[11] = (char)dta->dt_attr;
			while(ph->dir_count < ph->nb_dirs)
			{
				ph->dir_count++;
				str2dir(ps->dt_fname, name);
				name[11] = ps->dt_fattr;
				if(match(filter, name))
				{
					memcpy(&dta->dt_fattr, ps, sizeof(SUBDTA) - 2);
					ph->end_dirs = (SUBDTA *)((unsigned long)ps + sizeof(SUBDTA) + (unsigned long)ps->dt_len_lfname);
					ret = E_OK;
					break;
				}
				ps = (SUBDTA *)((unsigned long)ps + sizeof(SUBDTA) + (unsigned long)ps->dt_len_lfname);
			}
			if(ret != E_OK)
			{
				free(ph->dirs);
				memset(ph, 0, sizeof(struct pd_handle));
#ifdef DEBUG
//				kprint("cd_fsnext() = %d\r\n", ret);
#endif	 
			}
			return(ret);
		}
	}
	return(EDRIVE); /* for call default GEMDOS routine */
}

long cd_frename(const char *oldname, const char *newname) // xrename TOS404 0xE1A356
{
	long ret = check_drive(oldname);
	if(ret == E_OK)
		return(EACCDN); /* access denied */
  return(ret);
}

long cd_fdatime(short *timeptr, long handle, long wflag) // xdatime TOS404 0xE1B498
{
	long index;
	cd_file_t file;
	long ret = search_handle(handle, &index);
	if(ret != E_OK)
		return(ret);
	switch(wflag)
	{
		case 0: break;
		case 1: return(EACCDN); /* access denied */
		default: return(ERANGE);
	}
	file = &cd_pd_handle[index].file;
	timeptr[0] = (unsigned short)file->time; /* time */
	timeptr[1] = (unsigned short)(file->time >> 16); /* date */
	return(E_OK);
}

// xgetdta TOS404 0xE1B57C
// xsetdta TOS404 0xE1B5B4
// xsetdrv TOS404 0xE1B5F0
// xgetdrv TOS404 0xE1B644
