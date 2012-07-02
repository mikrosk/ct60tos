/* cd_iso.c - iso9660 implementation with extensions: SUSP, Rock Ridge. */
/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 2004,2005,2006,2007,2008,2009,2010  Free Software Foundation, Inc.
 *
 *  GRUB is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  GRUB is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GRUB.  If not, see <http://www.gnu.org/licenses/>.
 */
/* Didier Mequignon - Removed nested functions who crashes with GCC68K (code on stack) */

#include <stdlib.h> /* for malloc */
#include <string.h>
#include "gemerror.h"
#include "cd_dos.h"
#include "cd_disk.h"
#include "cd_iso.h"

#define ISO9660_FSTYPE_DIR     0040000
#define ISO9660_FSTYPE_REG     0100000
#define ISO9660_FSTYPE_SYMLINK 0120000
#define ISO9660_FSTYPE_MASK    0170000

#define ISO9660_LOG2_BLKSZ      2
#define ISO9660_BLKSZ        2048

#define ISO9660_RR_DOT          2
#define ISO9660_RR_DOTDOT       4

#define ISO9660_VOLDESC_BOOT    0
#define ISO9660_VOLDESC_PRIMARY 1
#define ISO9660_VOLDESC_SUPP    2
#define ISO9660_VOLDESC_PART	  3
#define ISO9660_VOLDESC_END   255

#define LONG_MAX       2147483647

/* The head of a volume descriptor.  */
struct iso9660_voldesc
{
	unsigned char type;
	unsigned char magic[5];
	unsigned char version;
} __attribute__ ((packed));

/* A directory entry.  */
struct iso9660_dir
{
	unsigned char len;
	unsigned char ext_sectors;
	unsigned long first_sector;
	unsigned long first_sector_be;
	unsigned long size;
	unsigned long size_be;
	unsigned char year;
	unsigned char month;
	unsigned char day;
	unsigned char hour;
	unsigned char minute;
	unsigned char second;
	unsigned char time_offset;
	unsigned char flags;
	unsigned char unused2[6];
	unsigned char namelen;
} __attribute__ ((packed));

struct iso9660_date
{
	unsigned char year[4];
	unsigned char month[2];
	unsigned char day[2];
	unsigned char hour[2];
	unsigned char minute[2];
	unsigned char second[2];
	unsigned char hundredth[2];
	unsigned char offset;
} __attribute__ ((packed));

/* The primary volume descriptor.  Only little endian is used. */
struct iso9660_primary_voldesc
{
	struct iso9660_voldesc voldesc;
	unsigned char unused1[33];
	unsigned char volname[32];
	unsigned char unused2[8];
	unsigned long total_sectors;
	unsigned long total_sectors_be;
	unsigned char escape[32];	
	unsigned char unused3[12];
	unsigned long path_table_size;
	unsigned char unused4[4];
	unsigned long path_table;
	unsigned char unused5[12];
	struct iso9660_dir rootdir;
	unsigned char unused6[624];
	struct iso9660_date created;
	struct iso9660_date modified;
} __attribute__ ((packed));

/* A single entry in the path table.  */
struct iso9660_path
{
	unsigned char len;
	unsigned char sectors;
	unsigned long first_sector;
	unsigned short parentdir;
	unsigned char name[0];
} __attribute__ ((packed));

/* An entry in the System Usage area of the directory entry. */
struct iso9660_susp_entry
{
	unsigned char sig[2];
	unsigned char len;
	unsigned char version;
	unsigned char data[0];
} __attribute__ ((packed));

/* The CE entry.  This is used to describe the next block where data can be found. */
struct iso9660_susp_ce
{
	struct iso9660_susp_entry entry;
	unsigned long blk;
	unsigned long blk_be;
	unsigned long off;
	unsigned long off_be;
	unsigned long len;
	unsigned long len_be;
} __attribute__ ((packed));

struct iso9660_data
{
	struct iso9660_primary_voldesc voldesc;
	cd_disk_t disk;
	unsigned int first_sector;
	int rockridge;
	int susp_skip;
	int joliet;
};

struct iso9660_node
{
	struct iso9660_data *data;
	unsigned int size;
	unsigned int blk;
	unsigned int dir_blk;
	unsigned int dir_off;
	unsigned int time;
};

typedef struct iso9660_node *iso9660_node_t;

enum iso9660_fileype
{
	FSHELP_UNKNOWN,
	FSHELP_REG,
	FSHELP_DIR,
	FSHELP_SYMLINK,
	FSHELP_HIDDEN
};

struct params_iterate_file
{
	enum iso9660_fileype *type;
	char *name;
	iso9660_node_t currnode;
	iso9660_node_t oldnode;
};

#define FSHELP_CASE_INSENSITIVE 0x100
#define FSHELP_TYPE_MASK 0xff
#define FSHELP_FLAGS_MASK 0x100

extern char *strndup(char const *s, int n);
extern unsigned short swap_short(unsigned short val);
extern unsigned long swap_long(unsigned long val);

#define le_to_cpu16(x) swap_short(x)
#define le_to_cpu32(x) swap_long(x)
#define be_to_cpu16(x) (x)
#define be_to_cpu32(x) (x)

inline void *zalloc(int size)
{
	void *ret = malloc(size);
	if(!ret)
		return NULL;
	memset(ret, 0, size);
	return ret;
}

extern int cd_disk_errno;

static int iso9660_iterate_dir(iso9660_node_t dir, int (*hook)(), void *params);
static char *iso9660_read_symlink(iso9660_node_t node);

static int file_iterate(const char *filename, enum iso9660_fileype filetype, iso9660_node_t node, void *params)
{
	struct params_iterate_file *params_iterate = params;
	if(filetype == FSHELP_UNKNOWN || (strcmp(params_iterate->name, filename)
	 && (! (filetype & FSHELP_CASE_INSENSITIVE) || strncasecmp(params_iterate->name, filename, LONG_MAX))))
	{
		free(node);
		return 0;
	}
	/* The node is found, stop iterating over the nodes.  */
	*params_iterate->type = filetype & ~FSHELP_CASE_INSENSITIVE;
	params_iterate->oldnode = params_iterate->currnode;
	params_iterate->currnode = node;
	return 1;
}

static int find_file(const char *currpath, iso9660_node_t currroot, iso9660_node_t *currfound, iso9660_node_t rootnode, enum iso9660_fileype *foundtype, int *symlinknest)
{
	char fpath[strlen(currpath) + 1];
	char *next;
	enum iso9660_fileype type = FSHELP_DIR;
	struct params_iterate_file params_iterate =
	{
		.type = &type,
		.name = fpath,
		.currnode = currroot,
		.oldnode = currroot,
	};
	strncpy(fpath, currpath, strlen(currpath) + 1);
	/* Remove all leading slashes. */
	while(*params_iterate.name == '/')
		params_iterate.name++;
	if(!*params_iterate.name)
	{
		*currfound = params_iterate.currnode;
		return 0;
	}
	while(1)
	{
		int found;
		/* Extract the actual part from the pathname. */
		next = strchr(params_iterate.name, '/');
		if(next)
		{
			/* Remove all leading slashes. */
			while(*next == '/')
				*(next++) = '\0';
		}
		/* At this point it is expected that the current node is a directory, check if this is true. */
		if(type != FSHELP_DIR)
		{
			if(params_iterate.currnode != rootnode && params_iterate.currnode != currroot)
				free(params_iterate.currnode);
			return(cd_disk_errno = EPTHNF); /* not a directory */
		}
		/* Iterate over the directory. */
		found = iso9660_iterate_dir(params_iterate.currnode, file_iterate, &params_iterate);
		if(!found)
		{
			if(cd_disk_errno)
				return cd_disk_errno;
			break;
		}
		/* Read in the symlink and follow it. */
		if(type == FSHELP_SYMLINK)
		{
			char *symlink;
			/* Test if the symlink does not loop.  */
			if(++(*symlinknest) == 8)
			{
				if(params_iterate.currnode != rootnode && params_iterate.currnode != currroot)
					free(params_iterate.currnode);
				if(params_iterate.oldnode != rootnode && params_iterate.oldnode != currroot)
					free(params_iterate.oldnode);
				return(cd_disk_errno = ERANGE); /* too deep nesting of symlinks */
			}
			symlink = iso9660_read_symlink(params_iterate.currnode);
			if(params_iterate.currnode != rootnode && params_iterate.currnode != currroot)
				free(params_iterate.currnode);
			if(!symlink)
			{
				if(params_iterate.oldnode != rootnode && params_iterate.oldnode != currroot)
					free(params_iterate.oldnode);
				return cd_disk_errno;
			}
			/* The symlink is an absolute path, go back to the root inode. */
			if(symlink[0] == '/')
			{
				if(params_iterate.oldnode != rootnode && params_iterate.oldnode != currroot)
					free(params_iterate.oldnode);
				params_iterate.oldnode = rootnode;
			}
			/* Lookup the node the symlink points to. */
			find_file(symlink, params_iterate.oldnode, &params_iterate.currnode, rootnode, foundtype, symlinknest);
			type = *foundtype;
			free(symlink);
			if(cd_disk_errno)
			{
				if(params_iterate.oldnode != rootnode && params_iterate.oldnode != currroot)
					free(params_iterate.oldnode);
				return cd_disk_errno;
			}
		}
		if(params_iterate.oldnode != rootnode && params_iterate.oldnode != currroot)
			free(params_iterate.oldnode);
		/* Found the node! */
		if(!next || *next == '\0')
		{
			*currfound = params_iterate.currnode;
			*foundtype = type;
			return 0;
		}
		params_iterate.name = next;
	}
	return(cd_disk_errno = EFILNF);
}

/* Lookup the node PATH.  The node ROOTNODE describes the root of the
   directory tree.  The node found is returned in FOUNDNODE, which is
   either a ROOTNODE or a new malloc'ed node.  ITERATE_DIR is used to
   iterate over all directory entries in the current node.
   READ_SYMLINK is used to read the symlink if a node is a symlink.
   EXPECTTYPE is the type node that is expected by the called, an
   error is generated if the node is not of the expected type.  Make
   sure you use the NESTED_FUNC_ATTR macro for HOOK, this is required
   because GCC has a nasty bug when using regparm=3.  */
static int iso9660_find_file(const char *path, iso9660_node_t rootnode, iso9660_node_t *foundnode,
 enum iso9660_fileype expecttype)
{
	int err;
	enum iso9660_fileype foundtype = FSHELP_DIR;
	int symlinknest = 0;
	if(!path || path[0] != '/')
		return(cd_disk_errno = EPTHNF);
	err = find_file(path, rootnode, foundnode, rootnode, &foundtype, &symlinknest);
	if(err)
		return err;
	/* Check if the node that was found was of the expected type. */
	if(expecttype == FSHELP_REG && foundtype != expecttype)
		return(cd_disk_errno = EFILNF); /* not a regular file */
	else if(expecttype == FSHELP_DIR && foundtype != expecttype)
		return(cd_disk_errno = EPTHNF); /* not a directory */
	return 0;
}

static unsigned char *iso9660_utf16_to_utf8(unsigned char *dest, unsigned short *src, int size)
{
	unsigned long code_high = 0;
	while (size--)
	{
		unsigned long code = *src++;
		if(code_high)
		{
			if(code >= 0xDC00 && code <= 0xDFFF)
			{
				/* Surrogate pair. */
				code = ((code_high - 0xD800) << 12) + (code - 0xDC00) + 0x10000;
				*dest++ = (code >> 18) | 0xF0;
				*dest++ = ((code >> 12) & 0x3F) | 0x80;
				*dest++ = ((code >> 6) & 0x3F) | 0x80;
				*dest++ = (code & 0x3F) | 0x80;
			}
			else
				*dest++ = '?'; /* error */
			code_high = 0;
		}
		else
		{
			if (code <= 0x007F)
				*dest++ = code;
			else if (code <= 0x07FF)
			{
				*dest++ = (code >> 6) | 0xC0;
				*dest++ = (code & 0x3F) | 0x80;
			}
			else if (code >= 0xD800 && code <= 0xDBFF)
			{
				code_high = code;
				continue;
			}
			else if (code >= 0xDC00 && code <= 0xDFFF)
				*dest++ = '?'; /* error */
			else if (code < 0x10000)
			{
				*dest++ = (code >> 12) | 0xE0;
				*dest++ = ((code >> 6) & 0x3F) | 0x80;
				*dest++ = (code & 0x3F) | 0x80;
			}
			else
			{
				*dest++ = (code >> 18) | 0xF0;
				*dest++ = ((code >> 12) & 0x3F) | 0x80;
				*dest++ = ((code >> 6) & 0x3F) | 0x80;
				*dest++ = (code & 0x3F) | 0x80;
			}
		}
	}
	return dest;
}

static char *iso9660_convert_string(unsigned short *us, int len)
{
	int i;
	char *p = malloc(len * 4 + 1);
	if(!p)
		return p;
	for(i = 0; i < len; us[i] = be_to_cpu16(us[i]), i++);
	*iso9660_utf16_to_utf8((unsigned char *)p, us, len) = '\0';
	return p;
}

/* Iterate over the susp entries, starting with block SUA_BLOCK on the
   offset SUA_POS with a size of SUA_SIZE bytes. Hook is called for every entry. */
static int iso9660_susp_iterate(struct iso9660_data *data, int sua_block, int sua_pos, int sua_size)
{
	char *sua;
	struct iso9660_susp_entry *entry;
	/* Load a part of the System Usage Area.  */
	sua = malloc(sua_size);
	if(!sua)
		return cd_disk_errno;
	if(cd_disk_read(data->disk, sua_block, sua_pos, sua_size, sua))
		return cd_disk_errno;
	entry = (struct iso9660_susp_entry *)sua;
	for(; (char *) entry < (char *)sua + sua_size - 1; entry = (struct iso9660_susp_entry *)((char *)entry + entry->len))
	{
		/* The last entry.  */
		if(strncmp ((char *)entry->sig, "ST", 2) == 0)
			break;
		/* Additional entries are stored elsewhere.  */
		if(strncmp((char *)entry->sig, "CE", 2) == 0)
		{
			struct iso9660_susp_ce *ce = (struct iso9660_susp_ce *)entry;
			sua_size = le_to_cpu32(ce->len);
			sua_pos = le_to_cpu32(ce->off);
			sua_block = le_to_cpu32(ce->blk) << ISO9660_LOG2_BLKSZ;
			free(sua);
			sua = malloc(sua_size);
			if(!sua)
				return cd_disk_errno;
			if(cd_disk_read(data->disk, sua_block, sua_pos, sua_size, sua))
				return cd_disk_errno;
			entry = (struct iso9660_susp_entry *)sua;
		}
		/* The "ER" entry is used to detect extensions.  The `IEEE_P1285' extension means Rock ridge. */
		if(strncmp((char *)entry->sig, "ER", 2) == 0)
		{
			data->rockridge = 1;
			free(sua);
			return 0;
		}
	}
	free(sua);
	return 0;
}

static struct iso9660_data *iso9660_mount(cd_disk_t disk)
{
	struct iso9660_data *data = 0;
	struct iso9660_dir rootdir;
	int sua_pos, sua_size, block;
	char *sua;
	struct iso9660_susp_entry *entry;
	struct iso9660_primary_voldesc *voldesc = NULL;
	voldesc = malloc(sizeof(struct iso9660_primary_voldesc));
	if(voldesc == NULL)
		return 0;
  data = zalloc(sizeof(struct iso9660_data));
	if(data == NULL)
	{
		free(voldesc);
		return 0;
	}
	data->disk = disk;
	block = 16;
	do
	{
		int copy_voldesc = 0;
		/* Read the superblock.  */
		if(cd_disk_read(disk, block << ISO9660_LOG2_BLKSZ, 0, sizeof(struct iso9660_primary_voldesc), (char *)voldesc))
		{
			cd_disk_errno = EMEDIA; /* not a ISO9660 filesystem */
			goto fail;
		}
		if(strncmp((char *)voldesc->voldesc.magic, "CD001", 5) != 0)
		{
			cd_disk_errno = EMEDIA; /* not a ISO9660 filesystem */
			goto fail;
		}
		if(voldesc->voldesc.type == ISO9660_VOLDESC_PRIMARY)
			copy_voldesc = 1;
		else if((voldesc->voldesc.type == ISO9660_VOLDESC_SUPP) && (voldesc->escape[0] == 0x25) && (voldesc->escape[1] == 0x2f)
		 && ((voldesc->escape[2] == 0x40) ||	(voldesc->escape[2] == 0x43) || (voldesc->escape[2] == 0x45))) /* UCS-2 Level 1-2-3 */
		{
			copy_voldesc = 1;
			data->joliet = 1;
		}
		if(copy_voldesc)
			memcpy((char *)&data->voldesc, (char *)voldesc, sizeof(struct iso9660_primary_voldesc));
		block++;
	}
	while(voldesc->voldesc.type != ISO9660_VOLDESC_END);
	free(voldesc);
	voldesc = NULL;
  /* Read the system use area and test it to see if SUSP is supported.  */
	if(cd_disk_read(disk, (le_to_cpu32(data->voldesc.rootdir.first_sector) << ISO9660_LOG2_BLKSZ), 0, sizeof(rootdir), (char *)&rootdir))
	{
		cd_disk_errno = EMEDIA; /* not a ISO9660 filesystem */
		goto fail;
	}
	sua_pos = sizeof(rootdir) + rootdir.namelen + (rootdir.namelen % 2) - 1;
	sua_size = rootdir.len - sua_pos;
	sua = malloc(sua_size + 1);
	if(sua == NULL)
		goto fail;
	if(cd_disk_read(disk, (le_to_cpu32 (data->voldesc.rootdir.first_sector) << ISO9660_LOG2_BLKSZ), sua_pos, sua_size, sua))
	{
		free(sua);
		cd_disk_errno = EMEDIA; /* not a ISO9660 filesystem */
		goto fail;
	}
	entry = (struct iso9660_susp_entry *)sua;
	/* Test if the SUSP protocol is used on this filesystem. */
	if(strncmp((char *)entry->sig, "SP", 2) == 0)
	{
		/* The 2nd data byte stored how many bytes are skipped every time to get to the SUA (System Usage Area). */
		data->susp_skip = entry->data[2];
		entry = (struct iso9660_susp_entry *)((char *)entry + entry->len);
		/* Iterate over the entries in the SUA area to detect extensions. */
		if(iso9660_susp_iterate(data, (le_to_cpu32(data->voldesc.rootdir.first_sector) << ISO9660_LOG2_BLKSZ), sua_pos, sua_size))
		{
			free(sua);
			goto fail;
		}
	}
	free(sua);
	return data;
fail:
	free(data);
	if(voldesc != NULL)
		free(voldesc);
	return 0;
}

static char *add_part(char *symlink, const char *part, int len) /* Extend the symlink. */
{
	int size = strlen(symlink);
	char *new_symlink = realloc(symlink, size + len + 1);
	if(!new_symlink)
		return NULL;
	strncat(new_symlink, part, len);
	return new_symlink;
}

/* Iterate over the susp entries, starting with block SUA_BLOCK on the
   offset SUA_POS with a size of SUA_SIZE bytes. Hook is called for every entry. */
static int iso9660_susp_iterate_sl(struct iso9660_data *data, int sua_block, int sua_pos, int sua_size, char *symlink, int *addslash)
{
	char *sua;
	struct iso9660_susp_entry *entry;
	/* Load a part of the System Usage Area.  */
	sua = malloc(sua_size);
	if(!sua)
		return cd_disk_errno;
	if(cd_disk_read(data->disk, sua_block, sua_pos, sua_size, sua))
		return cd_disk_errno;
	entry = (struct iso9660_susp_entry *)sua;
	for(; (char *) entry < (char *)sua + sua_size - 1; entry = (struct iso9660_susp_entry *)((char *)entry + entry->len))
	{
		/* The last entry.  */
		if(strncmp ((char *)entry->sig, "ST", 2) == 0)
			break;
		/* Additional entries are stored elsewhere.  */
		if(strncmp((char *)entry->sig, "CE", 2) == 0)
		{
			struct iso9660_susp_ce *ce = (struct iso9660_susp_ce *)entry;
			sua_size = le_to_cpu32(ce->len);
			sua_pos = le_to_cpu32(ce->off);
			sua_block = le_to_cpu32(ce->blk) << ISO9660_LOG2_BLKSZ;
			free(sua);
			sua = malloc(sua_size);
			if(!sua)
				return cd_disk_errno;
			if(cd_disk_read(data->disk, sua_block, sua_pos, sua_size, sua))
				return cd_disk_errno;
			entry = (struct iso9660_susp_entry *)sua;
		}
		if(strncmp("SL", (char *)entry->sig, 2) == 0)
		{
			unsigned int pos = 1;
			/* The symlink is not stored as a POSIX symlink, translate it. */
			while(pos < le_to_cpu32(entry->len))
			{
				if(*addslash)
				{
					symlink = add_part(symlink, "/", 1);
					*addslash = 0;
				}
				/* The current position is the `Component Flag'. */
				switch(entry->data[pos] & 30)
				{
					case 0:
					{
						/* The data on pos + 2 is the actual data, pos + 1 is the length.  Both are part of the `Component Record'. */
						symlink = add_part(symlink, (char *)&entry->data[pos + 2], entry->data[pos + 1]);
						if((entry->data[pos] & 1))
							*addslash = 1;
						break;
					}
					case 2: symlink = add_part(symlink, "./", 2); break;
					case 4: symlink = add_part(symlink, "../", 3); break;
					case 8: symlink = add_part(symlink, "/", 1); break;
				}
				/* In pos + 1 the length of the `Component Record' is stored. */
				pos += entry->data[pos + 1] + 2;
			}
			/* Check if `realloc' failed. */
			if(cd_disk_errno)
			{
				free(sua);
				return 0;
			}
		}
	}
	free(sua);
	return 0;
}

static char *iso9660_read_symlink(iso9660_node_t node)
{
	struct iso9660_dir dirent;
	int sua_off, sua_size, addslash = 0;
	char *symlink = NULL;
	if(cd_disk_read(node->data->disk, node->dir_blk, node->dir_off, sizeof(dirent), (char *)&dirent))
		return NULL;
	sua_off = (sizeof (dirent) + dirent.namelen + 1 - (dirent.namelen % 2) + node->data->susp_skip);
	sua_size = dirent.len - sua_off;
	symlink = malloc(1);
	if(!symlink)
		return NULL;
	*symlink = '\0';
	if(iso9660_susp_iterate_sl(node->data, node->dir_blk, node->dir_off + sua_off, sua_size, symlink, &addslash))
	{
		free(symlink);
		return NULL;
	}
	return symlink;
}

/* Iterate over the susp entries, starting with block SUA_BLOCK on the
   offset SUA_POS with a size of SUA_SIZE bytes. Hook is called for every entry. */
static int iso9660_susp_iterate_dir(struct iso9660_data *data, int sua_block, int sua_pos, int sua_size, 
 char *filename, enum iso9660_fileype *type, unsigned int *filename_alloc)
{
	char *sua;
	struct iso9660_susp_entry *entry;
	/* Load a part of the System Usage Area.  */
	sua = malloc(sua_size);
	if(!sua)
		return cd_disk_errno;
	if(cd_disk_read(data->disk, sua_block, sua_pos, sua_size, sua))
		return cd_disk_errno;
	entry = (struct iso9660_susp_entry *)sua;
	for(; (char *) entry < (char *)sua + sua_size - 1; entry = (struct iso9660_susp_entry *)((char *)entry + entry->len))
	{
		/* The last entry.  */
		if(strncmp ((char *)entry->sig, "ST", 2) == 0)
			break;
		/* Additional entries are stored elsewhere.  */
		if(strncmp((char *)entry->sig, "CE", 2) == 0)
		{
			struct iso9660_susp_ce *ce = (struct iso9660_susp_ce *)entry;
			sua_size = le_to_cpu32(ce->len);
			sua_pos = le_to_cpu32(ce->off);
			sua_block = le_to_cpu32(ce->blk) << ISO9660_LOG2_BLKSZ;
			free(sua);
			sua = malloc(sua_size);
			if(!sua)
				return cd_disk_errno;
			if(cd_disk_read(data->disk, sua_block, sua_pos, sua_size, sua))
				return cd_disk_errno;
			entry = (struct iso9660_susp_entry *)sua;
		}
		/* The filename in the rock ridge entry. */
		if(strncmp("NM", (char *)entry->sig, 2) == 0)
		{
			/* The flags are stored at the data position 0, here the filename type is stored. */
			if(entry->data[0] & ISO9660_RR_DOT)
				filename = ".";
			else if(entry->data[0] & ISO9660_RR_DOTDOT)
				filename = "..";
			else
			{
				int size = 1;
				if(filename)
				{
					size += strlen(filename);
					realloc(filename, strlen(filename) + entry->len);
				}
				else
				{
					size = entry->len - 5;
					filename = zalloc(size + 1);
				}
				*filename_alloc = 1;
				strncpy(filename, (char *)&entry->data[1], size);
				filename[size] = '\0';
			}
		}
		/* The mode information (st_mode). */
		else if(strncmp((char *)entry->sig, "PX", 2) == 0)
		{
			/* At position 0 of the PX record the st_mode information is stored (little-endian). */
			unsigned long mode = ((entry->data[0] + (entry->data[1] << 8)) & ISO9660_FSTYPE_MASK);
			switch(mode)
			{
				case ISO9660_FSTYPE_DIR: *type = FSHELP_DIR; break;
				case ISO9660_FSTYPE_REG: *type = FSHELP_REG; break;
				case ISO9660_FSTYPE_SYMLINK: *type = FSHELP_SYMLINK; break;
				default: *type = FSHELP_UNKNOWN; break;
			}
		}
	}
	free(sua);
	return 0;
}

static int iso9660_iterate_dir(iso9660_node_t dir, int (*hook)(), void *params)
{
	struct iso9660_dir dirent;
	unsigned int offset = 0, filename_alloc = 0;
	char *filename;
	enum iso9660_fileype type;
	while(offset < dir->size)
	{
		if(cd_disk_read(dir->data->disk, (dir->blk << ISO9660_LOG2_BLKSZ) + offset / DISK_SECTOR_SIZE, offset % DISK_SECTOR_SIZE, sizeof(dirent), (char *)&dirent))
			return 0;
		/* The end of the block, skip to the next one. */
		if(!dirent.len)
		{
			offset = (offset / ISO9660_BLKSZ + 1) * ISO9660_BLKSZ;
			continue;
		}
		{
			int dot = 0;
			char name[dirent.namelen + 1];
			int nameoffset = offset + sizeof(dirent);
			struct iso9660_node *node;
			int sua_off = (sizeof(dirent) + dirent.namelen + 1 - (dirent.namelen % 2));
			int sua_size = dirent.len - sua_off;
			sua_off += offset + dir->data->susp_skip;
			filename = 0;
			filename_alloc = 0;
			type = FSHELP_UNKNOWN;
			if(dir->data->rockridge 
				&& iso9660_susp_iterate_dir(dir->data, (dir->blk << ISO9660_LOG2_BLKSZ) + (sua_off / DISK_SECTOR_SIZE), sua_off % DISK_SECTOR_SIZE, sua_size, filename, &type, &filename_alloc))
				return 0;
			/* Read the name. */
			if(cd_disk_read(dir->data->disk, (dir->blk << ISO9660_LOG2_BLKSZ) + nameoffset / DISK_SECTOR_SIZE, nameoffset % DISK_SECTOR_SIZE, dirent.namelen, (char *)name))
				return 0;
			node = malloc(sizeof(struct iso9660_node));
			if(!node)
				return 0;
			/* Setup a new node.  */
			node->data = dir->data;
			node->size = le_to_cpu32(dirent.size);
			node->blk = le_to_cpu32(dirent.first_sector);
			node->dir_blk = ((dir->blk << ISO9660_LOG2_BLKSZ) + offset / DISK_SECTOR_SIZE);
			node->dir_off = offset % DISK_SECTOR_SIZE;
			node->time = ((((unsigned)dirent.year - 80) & 0x7F) << 25) | (((unsigned)dirent.month & 0xF) << 21) | (((unsigned)dirent.day & 0x1F) << 16)
			           | (((unsigned)dirent.hour & 0x1F) << 11) | (((unsigned)dirent.minute & 0x3F) << 5) | (((unsigned)dirent.second & 0x3F) >> 1);
			/* If the filetype was not stored using rockridge, use whatever is stored in the iso9660 filesystem. */
			if(type == FSHELP_UNKNOWN)
			{
				if((dirent.flags & 3) == 2)
					type = FSHELP_DIR;
				else if(dirent.flags & 1)
					type = FSHELP_HIDDEN;
				else
					type = FSHELP_REG;
			}
			/* The filename was not stored in a rock ridge entry. Read it from the iso9660 filesystem. */
			if(!filename)
			{
				name[dirent.namelen] = '\0';
				filename = strrchr(name, ';');
				if(filename)
					*filename = '\0';
				if(dirent.namelen == 1 && name[0] == 0)
				{
					filename = ".";
					dot = 1;
				}
				else if(dirent.namelen == 1 && name[0] == 1)
				{
					filename = "..";
					dot = 1;
				}
				else
					filename = name;
			}
			if((dir->data->joliet) && !dot)
			{
				char *oldname, *semicolon;
				oldname = filename;
				filename = iso9660_convert_string((unsigned short *)oldname, dirent.namelen >> 1);
				semicolon = strrchr(filename, ';');
				if(semicolon)
					*semicolon = '\0';
				if(filename_alloc)
					free(oldname);
				filename_alloc = 1;
			}
			if(hook(filename, type, node, params))
			{
				if(filename_alloc)
					free(filename);
				return 1;
			}
			if(filename_alloc)
				free(filename);
		}
		offset += dirent.len;
	}
	return 0;
}

static int dir_iterate(const char *filename, enum iso9660_fileype filetype, iso9660_node_t node, void *params)
{
	int ret;
	struct dirhook_info info;
	int (*dir_hook)(const char *filename, const struct dirhook_info *info) = params;
	memset(&info, 0, sizeof(info));
	info.dir = ((filetype & FSHELP_TYPE_MASK) == FSHELP_DIR);
	info.hidden = ((filetype & FSHELP_TYPE_MASK) == FSHELP_HIDDEN); 
	if(info.dir)
		info.size = 0;
	else
		info.size = (unsigned long)node->size;
	info.mtime = (unsigned long)node->time;
	info.mtimeset = 1;
	ret = dir_hook(filename, &info);
	free(node);
	return ret;
}

int iso9660_dir(cd_disk_t disk, const char *path, int (*hook)())
{
	struct iso9660_data *data = 0;
	struct iso9660_node rootnode;
	struct iso9660_node *foundnode;
	data = iso9660_mount(disk);
	if(data == NULL)
		goto fail;
	rootnode.data = data;
	rootnode.blk = le_to_cpu32(data->voldesc.rootdir.first_sector);
	rootnode.size = le_to_cpu32(data->voldesc.rootdir.size);
	/* Use this function to traverse the path. */
	if(iso9660_find_file(path, &rootnode, &foundnode, FSHELP_DIR))
		goto fail;
	/* List the files in the directory. */
	iso9660_iterate_dir(foundnode, dir_iterate, hook);
	if(foundnode != &rootnode)
		free(foundnode);
fail:
	free(data);
	return cd_disk_errno;
}

/* Open a file named NAME and initialize FILE. */
int iso9660_open(cd_file_t file, const char *name)
{
	struct iso9660_data *data;
	struct iso9660_node rootnode;
	struct iso9660_node *foundnode;
	data = iso9660_mount(file->disk);
	if(data == NULL)
		goto fail;
	rootnode.data = data;
	rootnode.blk = le_to_cpu32(data->voldesc.rootdir.first_sector);
	rootnode.size = le_to_cpu32(data->voldesc.rootdir.size);
	/* Use this function to traverse the path. */
	if(iso9660_find_file(name, &rootnode, &foundnode, FSHELP_REG))
		goto fail;
	data->first_sector = foundnode->blk;
	file->data = data;
	file->size = foundnode->size;
	file->offset = 0;
	file->time = foundnode->time;
	return 0;
fail:
	free(data);
	return cd_disk_errno;
}

int iso9660_read(cd_file_t file, char *buf, int len)
{
	struct iso9660_data *data = (struct iso9660_data *)file->data;
	/* XXX: The file is stored in as a single extent.  */
	cd_disk_read(data->disk, data->first_sector << ISO9660_LOG2_BLKSZ, file->offset, len, buf);
	if(cd_disk_errno)
		return cd_disk_errno /* -1 */;
	return len;
}

int iso9660_close(cd_file_t file)
{
	free(file->data);
	file->data = NULL;
	return E_OK;
}

int iso9660_label(cd_disk_t disk, char **label, long *total_sectors)
{
	struct iso9660_data *data = iso9660_mount(disk);
	if(data != NULL)
	{
		if(label != NULL)
		{
			if(data->joliet)
				*label = iso9660_convert_string((unsigned short *)&data->voldesc.volname, 16);
			else
				*label = strndup((char *)data->voldesc.volname, 32);
			if(*label != NULL)
			{
				char *ptr;
				for(ptr = *label; *ptr;ptr++);
					ptr--;
				while(ptr >= *label && *ptr == ' ')
					*ptr-- = 0;
			}
		}
		if(total_sectors != NULL)
			*total_sectors = le_to_cpu32(data->voldesc.total_sectors);
		free(data);
	}
	else
	{
		if(label != NULL)
			*label = NULL;
		if(total_sectors != NULL)
			*total_sectors = 0;
	}
	return cd_disk_errno;
}

