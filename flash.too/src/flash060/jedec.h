#ifndef __jedec_H
#define __jedec_H
/* Flashing hard CT60, JEDEC part
*  Didier Mequignon 2003 February, e-mail: didier-mequignon@wanadoo.fr
*  Based on sources Copyright (c) 2000 Stephen Williams (steve@icarus.com)
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

/*
 * The jedec_data_t is an opaque cookie that represents the JEDEC data
 * that can be read, written and otherwise manipulated. It is opaque
 * so that the structure and implementation can be changed without
 * affecting applications.
 */

typedef struct jedec_data *jedec_data_t;

struct jedec_data
{
	unsigned char *fuse_list;
	unsigned char *sizes_list;
	unsigned long fuse_count;
	unsigned long sizes_count;
	char *design_specification;
	char *note_device;
};

/*
 * This method reads a JEDEC file and create a jedec_data_t
 * object. This object has all the data needed.
 */
extern jedec_data_t jedec_read(const char *path,const char *device_name);

/*
 * Release a jedec_data_t object and all the memory it might
 * reference. This must be used instead of the generic free becuase
 * there may be pointers in the depths of the cookie.
 */
extern void jedec_free(jedec_data_t jed);

/*
 * Get/set the state of a specific fuse. If 0, the fuse is "low
 * resistance", and if !0, the fuse is "blown".
 */
extern long jedec_get_fuse(jedec_data_t jed,unsigned long idx);
extern void jedec_set_fuse(jedec_data_t jed,unsigned long idx,unsigned char blow);

#endif
