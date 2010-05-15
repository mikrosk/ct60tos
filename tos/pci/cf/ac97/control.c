/*
 *   Control interface
 *
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

#include "config.h"
#include <string.h>
#include <osbind.h>
#include <errno.h>
#include "core.h"
#include "pcm.h"
#include "control.h"

#ifdef SOUND_AC97
#ifdef NETWORK /* for DMA API */

int snd_ctl_add(struct snd_card *card, struct snd_kcontrol *kcontrol)
{
	struct snd_ctl_elem_id id;
	id = kcontrol->id;
	if(snd_ctl_find_id(card, &id) != NULL)
	{
		Mfree(kcontrol);
		return -EBUSY;	
	}	
	if(card->controls == NULL)
		card->controls = (void *)kcontrol;
	else
	{
		struct snd_kcontrol *k = (struct snd_kcontrol *)card->controls;
		while(k->next != NULL)
			k = k->next;
		k->next = kcontrol;
	}
	return 0;
}

struct snd_kcontrol *snd_ctl_new1(const struct snd_kcontrol_new *kcontrolnew, void *private_data)
{
	struct snd_kcontrol * kcontrol = (struct snd_kcontrol *)Mxalloc(sizeof(struct snd_kcontrol), 2);
	if(kcontrol != NULL)
	{
		kcontrol->id.iface = kcontrolnew->iface;
		if(kcontrolnew->name)
			strcpy(kcontrol->id.name, kcontrolnew->name);
		kcontrol->info = kcontrolnew->info;
		kcontrol->get = kcontrolnew->get;
		kcontrol->put = kcontrolnew->put;
    kcontrol->tlv.p = kcontrolnew->tlv.p;
    kcontrol->private_value = kcontrolnew->private_value;
		kcontrol->private_data = private_data;
		kcontrol->next = NULL;
	}
	return kcontrol;
}

int snd_ctl_remove(struct snd_card * card, struct snd_kcontrol * kcontrol)
{
	if(kcontrol == NULL)
		return -ENOENT;
	Mfree(kcontrol);
	return 0;
}

int snd_ctl_remove_id(struct snd_card * card, struct snd_ctl_elem_id *id)
{
	return snd_ctl_remove(card, snd_ctl_find_id(card, id));
}

struct snd_kcontrol *snd_ctl_find_id(struct snd_card * card, struct snd_ctl_elem_id *id)
{
	if(card->controls == NULL)
		return NULL;
	else
	{
		struct snd_kcontrol *k = (struct snd_kcontrol *)card->controls;
		while(k->next != NULL)
		{
			if((k->id.iface == id->iface)
			 && !strcmp(k->id.name, id->name))
				return k;
			k = k->next;
		}
	}
	return NULL;
}

int snd_ctl_elem_info(struct snd_card *card, struct snd_ctl_elem_info *info)
{
	struct snd_kcontrol *k = snd_ctl_find_id(card, &info->id);
	if(k == NULL)
		return -ENOENT;
	if(k->get != NULL)
		return k->info(k, info);
	return -EPERM;
}

int snd_ctl_elem_read(struct snd_card *card, struct snd_ctl_elem_value *control)
{
	struct snd_kcontrol *k = snd_ctl_find_id(card, &control->id);
	if(k == NULL)
		return -ENOENT;
	if(k->get != NULL)
		return k->get(k, control);
	return -EPERM;
}

int snd_ctl_elem_write(struct snd_card *card, struct snd_ctl_elem_value *control)
{
	struct snd_kcontrol *k = snd_ctl_find_id(card, &control->id);
	if(k == NULL)
		return -ENOENT;
	if(k->put != NULL)
		return k->put(k, control);
	return -EPERM;
}

#endif /* NETWORK */
#endif /* SOUND_AC97 */
