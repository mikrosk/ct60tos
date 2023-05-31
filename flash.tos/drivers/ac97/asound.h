/*
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
 *
 */

#ifndef __SOUND_ASOUND_H
#define __SOUND_ASOUND_H

/****************************************************************************
 *                                                                          *
 *        Digital audio interface					    *
 *                                                                          *
 ****************************************************************************/

struct snd_aes_iec958 {
	unsigned char status[24];	/* AES/IEC958 channel status bits */
	unsigned char subcode[147];	/* AES/IEC958 subcode bits */
	unsigned char pad;		/* nothing */
	unsigned char dig_subframe[4];	/* AES/IEC958 subframe bits */
};

/****************************************************************************
 *                                                                          *
 *        Section for driver control interface                              *
 *                                                                          *
 ****************************************************************************/

struct snd_ctl_card_info {
	int card;			/* card number */
	int pad;			/* reserved for future (was type) */
	unsigned char id[16];		/* ID of card (user selectable) */
	unsigned char driver[16];	/* Driver name */
	unsigned char name[32];		/* Short name of soundcard */
	unsigned char longname[80];	/* name + info text about soundcard */
	unsigned char reserved_[16];	/* reserved for future (was ID of mixer) */
	unsigned char mixername[80];	/* visual mixer identification */
	unsigned char components[80];	/* card components / fine identification, delimited with one space (AC97 etc..) */
	unsigned char reserved[48];	/* reserved for future */
};

typedef int snd_ctl_elem_type_t;
#define	SNDRV_CTL_ELEM_TYPE_NONE	((snd_ctl_elem_type_t) 0) /* invalid */
#define	SNDRV_CTL_ELEM_TYPE_BOOLEAN	((snd_ctl_elem_type_t) 1) /* boolean type */
#define	SNDRV_CTL_ELEM_TYPE_INTEGER	((snd_ctl_elem_type_t) 2) /* integer type */
#define	SNDRV_CTL_ELEM_TYPE_ENUMERATED	((snd_ctl_elem_type_t) 3) /* enumerated type */
#define	SNDRV_CTL_ELEM_TYPE_BYTES	((snd_ctl_elem_type_t) 4) /* byte array */
#define	SNDRV_CTL_ELEM_TYPE_IEC958	((snd_ctl_elem_type_t) 5) /* IEC958 (S/PDIF) setup */
#define	SNDRV_CTL_ELEM_TYPE_INTEGER64	((snd_ctl_elem_type_t) 6) /* 64-bit integer type */
#define	SNDRV_CTL_ELEM_TYPE_LAST	SNDRV_CTL_ELEM_TYPE_INTEGER64

typedef int snd_ctl_elem_iface_t;
#define	SNDRV_CTL_ELEM_IFACE_CARD	((snd_ctl_elem_iface_t) 0) /* global control */
#define	SNDRV_CTL_ELEM_IFACE_HWDEP	((snd_ctl_elem_iface_t) 1) /* hardware dependent device */
#define	SNDRV_CTL_ELEM_IFACE_MIXER	((snd_ctl_elem_iface_t) 2) /* virtual mixer device */
#define	SNDRV_CTL_ELEM_IFACE_PCM	((snd_ctl_elem_iface_t) 3) /* PCM device */
#define	SNDRV_CTL_ELEM_IFACE_RAWMIDI	((snd_ctl_elem_iface_t) 4) /* RawMidi device */
#define	SNDRV_CTL_ELEM_IFACE_TIMER	((snd_ctl_elem_iface_t) 5) /* timer device */
#define	SNDRV_CTL_ELEM_IFACE_SEQUENCER	((snd_ctl_elem_iface_t) 6) /* sequencer client */
#define	SNDRV_CTL_ELEM_IFACE_LAST	SNDRV_CTL_ELEM_IFACE_SEQUENCER

#define SNDRV_CTL_ELEM_ACCESS_READ		(1<<0)
#define SNDRV_CTL_ELEM_ACCESS_WRITE		(1<<1)
#define SNDRV_CTL_ELEM_ACCESS_READWRITE		(SNDRV_CTL_ELEM_ACCESS_READ|SNDRV_CTL_ELEM_ACCESS_WRITE)
#define SNDRV_CTL_ELEM_ACCESS_VOLATILE		(1<<2)	/* control value may be changed without a notification */
#define SNDRV_CTL_ELEM_ACCESS_TIMESTAMP		(1<<3)	/* when was control changed */
#define SNDRV_CTL_ELEM_ACCESS_TLV_READ		(1<<4)	/* TLV read is possible */
#define SNDRV_CTL_ELEM_ACCESS_TLV_WRITE		(1<<5)	/* TLV write is possible */
#define SNDRV_CTL_ELEM_ACCESS_TLV_READWRITE	(SNDRV_CTL_ELEM_ACCESS_TLV_READ|SNDRV_CTL_ELEM_ACCESS_TLV_WRITE)
#define SNDRV_CTL_ELEM_ACCESS_TLV_COMMAND	(1<<6)	/* TLV command is possible */
#define SNDRV_CTL_ELEM_ACCESS_INACTIVE		(1<<8)	/* control does actually nothing, but may be updated */
#define SNDRV_CTL_ELEM_ACCESS_LOCK		(1<<9)	/* write lock */
#define SNDRV_CTL_ELEM_ACCESS_OWNER		(1<<10)	/* write lock owner */
#define SNDRV_CTL_ELEM_ACCESS_TLV_CALLBACK	(1<<28)	/* kernel use a TLV callback */ 
#define SNDRV_CTL_ELEM_ACCESS_USER		(1<<29) /* user space element */
/* bits 30 and 31 are obsoleted (for indirect access) */

/* for further details see the ACPI and PCI power management specification */
#define SNDRV_CTL_POWER_D0		0x0000	/* full On */
#define SNDRV_CTL_POWER_D1		0x0100	/* partial On */
#define SNDRV_CTL_POWER_D2		0x0200	/* partial On */
#define SNDRV_CTL_POWER_D3		0x0300	/* Off */
#define SNDRV_CTL_POWER_D3hot		(SNDRV_CTL_POWER_D3|0x0000)	/* Off, with power */
#define SNDRV_CTL_POWER_D3cold		(SNDRV_CTL_POWER_D3|0x0001)	/* Off, without power */

struct snd_ctl_elem_id {
	snd_ctl_elem_iface_t iface;	/* interface identifier */
	unsigned char name[44];		/* ASCII name of item */
};

struct snd_ctl_elem_list {
	unsigned int offset;		/* W: first element ID to get */
	unsigned int space;		/* W: count of element IDs to get */
	unsigned int used;		/* R: count of element IDs set */
	unsigned int count;		/* R: count of all elements */
	struct snd_ctl_elem_id *pids; /* R: IDs */
//	unsigned char reserved[50];
};

struct snd_ctl_elem_info {
	struct snd_ctl_elem_id id;	/* W: element ID */
	snd_ctl_elem_type_t type;	/* R: value type - SNDRV_CTL_ELEM_TYPE_* */
	unsigned int count;		/* count of values */
	union {
		struct {
			long min;		/* R: minimum value */
			long max;		/* R: maximum value */
			long step;		/* R: step (0 variable) */
		} integer;
		struct {
			long long min;		/* R: minimum value */
			long long max;		/* R: maximum value */
			long long step;		/* R: step (0 variable) */
		} integer64;
		struct {
			unsigned int items;	/* R: number of items */
			unsigned int item;	/* W: item number */
			char name[64];		/* R: value name */
		} enumerated;
		unsigned char reserved[128];
	} value;
	union {
		unsigned short d[4];		/* dimensions */
		unsigned short *d_ptr;		/* indirect - obsoleted */
	} dimen;
//	unsigned char reserved[64-4*sizeof(unsigned short)];
};

struct snd_ctl_elem_value {
	struct snd_ctl_elem_id id;	/* W: element ID */
	unsigned int indirect: 1;	/* W: indirect access - obsoleted */
      union {
union {
	long value[128];
			long *value_ptr;	/* obsoleted */
} integer;
		union {
			long long value[64];
			long long *value_ptr;	/* obsoleted */
		} integer64;
union {
	unsigned int item[128];
	unsigned int *item_ptr;	/* obsoleted */
} enumerated;
		union {
			unsigned char data[512];
			unsigned char *data_ptr;	/* obsoleted */
		} bytes;
		struct snd_aes_iec958 iec958;
        } value;                /* RO */
//	unsigned char reserved[128-sizeof(struct timespec)];
};

struct snd_ctl_tlv {
	unsigned int numid;	/* control element numeric identification */
	unsigned int length;	/* in bytes aligned to 4 */
	unsigned int tlv[0];	/* first TLV */
};

#endif /* __SOUND_ASOUND_H */
