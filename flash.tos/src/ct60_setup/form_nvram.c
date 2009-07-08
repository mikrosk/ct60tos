/*
	CT60 Setup
	NVRAM settings

	Copyright (C) 2009	Patrice Mandin

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include <stdlib.h>

#include <mint/osbind.h>
#include <mint/falcon.h>
#include <mint/sysvars.h>

#include "form_vt.h"
#include "form_nvram.h"
#include "misc.h"
#include "nvram.h"

/*--- Defines ---*/

#define FORM_DATE 1
#define FORM_TIME 2
#define FORM_LANG 3
#define FORM_VIDEOMODE 5
#define FORM_DELAY 6
#define FORM_SCSI 7
#define FORM_LOADSAVE 8

#define FORM_SETTING_DATE 0
#define FORM_SETTING_TIME (FORM_SETTING_DATE+3)
#define FORM_SETTING_LANG (FORM_SETTING_TIME+2)
#define FORM_SETTING_VIDEOMODE (FORM_SETTING_LANG+2)
#define FORM_SETTING_DELAY (FORM_SETTING_VIDEOMODE+1)
#define FORM_SETTING_SCSI (FORM_SETTING_DELAY+1)
#define FORM_SETTING_LOADSAVE (FORM_SETTING_SCSI+2)

#define MASK_DATE_DAY ((1<<5)-1)
#define SHIFT_DATE_DAY	0
#define MASK_DATE_MONTH ((1<<4)-1)
#define SHIFT_DATE_MONTH	5
#define MASK_DATE_YEAR ((1<<7)-1)
#define SHIFT_DATE_YEAR	9

#define MASK_TIME_SECOND ((1<<5)-1)
#define SHIFT_TIME_SECOND	0
#define MASK_TIME_MINUTE ((1<<6)-1)
#define SHIFT_TIME_MINUTE	5
#define MASK_TIME_HOUR ((1<<5)-1)
#define SHIFT_TIME_HOUR	11

#define NUM_LANG_TOS 6
#define NUM_LANG_KBD 19

/*--- Types ---*/

typedef struct {
	unsigned short vmode;
	unsigned short width, height;
} videomode_t;

/*--- Const ---*/

static const char *lang_tos[NUM_LANG_TOS+1]={
	"US", "DE", "FR", "UK",
	"ES", "IT",
	NULL
};

static const char *lang_kbd[NUM_LANG_KBD+1]={
	"US", "DE", "FR", "UK",
	"ES", "IT", "SE", "CH",
	"CD", "TR", "FI", "NO",
	"DK", "SA", "NL", "CZ",
	"HU", "SK", "GR",
	NULL
};

static const videomode_t modes_mono[]={
	{COL80|BPS1,640,400},

	{0,0,0}
};

static const videomode_t modes_vga[]={
	{COL80|BPS8,640,480},
	{COL80|BPS4,640,480},
	{COL80|BPS2,640,480},
	{COL80|BPS1,640,480},

	{COL80|BPS8|VERTFLAG,640,240},
	{COL80|BPS4|VERTFLAG,640,240},
	{COL80|BPS2|VERTFLAG,640,240},
	{COL80|BPS1|VERTFLAG,640,240},

	{BPS16,320,480},
	{BPS8,320,480},
	{BPS4,320,480},
	{BPS2,320,480},
	{BPS1,320,480},

	{BPS16|VERTFLAG,320,240},
	{BPS8|VERTFLAG,320,240},
	{BPS4|VERTFLAG,320,240},
	{BPS2|VERTFLAG,320,240},
	{BPS1|VERTFLAG,320,240},

	{0,0,0}
};

static const videomode_t modes_tv[]={
	{COL80|BPS16|VERTFLAG|OVERSCAN,768,480},
	{COL80|BPS8|VERTFLAG|OVERSCAN,768,480},
	{COL80|BPS4|VERTFLAG|OVERSCAN,768,480},
	{COL80|BPS2|VERTFLAG|OVERSCAN,768,480},
	{COL80|BPS1|VERTFLAG|OVERSCAN,768,480},

	{COL80|BPS16|VERTFLAG,640,400},
	{COL80|BPS8|VERTFLAG,640,400},
	{COL80|BPS4|VERTFLAG,640,400},
	{COL80|BPS2|VERTFLAG,640,400},
	{COL80|BPS1|VERTFLAG,640,400},

	{COL80|BPS16|OVERSCAN,768,240},
	{COL80|BPS8|OVERSCAN,768,240},
	{COL80|BPS4|OVERSCAN,768,240},
	{COL80|BPS2|OVERSCAN,768,240},
	{COL80|BPS1|OVERSCAN,768,240},

	{COL80|BPS16,640,200},
	{COL80|BPS8,640,200},
	{COL80|BPS4,640,200},
	{COL80|BPS2,640,200},
	{COL80|BPS1,640,200},

	{BPS16|VERTFLAG|OVERSCAN,384,480},
	{BPS8|VERTFLAG|OVERSCAN,384,480},
	{BPS4|VERTFLAG|OVERSCAN,384,480},
	{BPS2|VERTFLAG|OVERSCAN,384,480},

	{BPS16|VERTFLAG,320,400},
	{BPS8|VERTFLAG,320,400},
	{BPS4|VERTFLAG,320,400},
	{BPS2|VERTFLAG,320,400},

	{BPS16|OVERSCAN,384,240},
	{BPS8|OVERSCAN,384,240},
	{BPS4|OVERSCAN,384,240},
	{BPS2|OVERSCAN,384,240},

	{BPS16,320,200},
	{BPS8,320,200},
	{BPS4,320,200},
	{BPS2,320,200},

	{0,0,0}
};

/*--- Functions prototypes ---*/

static void reloadFromNvram(void);
static void saveToNvram(void);
static void confirmFormNvram(int num_setting, conf_setting_u confSetting);

static void readClock(void);
static void readNvram(void);

/*--- Variables ---*/

static form_t form_nvram[]={
	/* Static info */
	{FORM_TITLE, "NVRAM", FORM_X+((FORM_W-5)>>1), FORM_Y},

	{FORM_TEXT, "Date: --/--/----", FORM_X+2,FORM_Y+2},
	{FORM_TEXT, "Time: --:--:--", FORM_X+2,FORM_Y+3},

	{FORM_TEXT, "Language: --", FORM_X+2,FORM_Y+5},
	{FORM_TEXT, "Keyboard: --", FORM_X+2,FORM_Y+6},

	{FORM_TEXT, "Video mode: ---x---x-- bits", FORM_X+2,FORM_Y+8},
	{FORM_TEXT, "Boot delay: ---s", FORM_X+2,FORM_Y+9},
	{FORM_TEXT, "[-] SCSI arbitration, as device -", FORM_X+2,FORM_Y+10},

	{FORM_TEXT, "Reload NVRAM settings", FORM_X+2,FORM_Y+12},
	{FORM_TEXT, "Save NVRAM settings", FORM_X+2,FORM_Y+13},

	{FORM_END, 0,0,0}
};

form_setting_t form_setting_nvram[]={
	{FORM_X+8,FORM_Y+2, NULL, SETTING_INPUT, 2},		/* Date */
	{FORM_X+8+3,FORM_Y+2, NULL, SETTING_INPUT, 2},
	{FORM_X+8+3+3,FORM_Y+2, NULL, SETTING_INPUT, 4},

	{FORM_X+8,FORM_Y+3, NULL, SETTING_INPUT, 2},		/* Time */
	{FORM_X+8+3,FORM_Y+3, NULL, SETTING_INPUT, 2},
	/*{FORM_X+8+3+3,FORM_Y+3, NULL, SETTING_INPUT, 2},*/

	{FORM_X+12,FORM_Y+5, NULL, SETTING_LIST, 2, lang_tos},	/* TOS language */
	{FORM_X+12,FORM_Y+6, NULL, SETTING_LIST, 2, lang_kbd},	/* Keyboard language */

	{FORM_X+14,FORM_Y+8, NULL, SETTING_LIST, 3+1+3+1+2, NULL},	/* Video mode */
	{FORM_X+14,FORM_Y+9, NULL, SETTING_INPUT, 3},	/* Boot delay */

	{FORM_X+3,FORM_Y+10, NULL, SETTING_BOOL},	/* SCSI arbitration enable */
	{FORM_X+34,FORM_Y+10, NULL, SETTING_INPUT, 1}, /* SCSI arbitration device */

	{FORM_X+2,FORM_Y+12, NULL, SETTING_FUNC, 0, reloadFromNvram},	/* Reload settings */
	{FORM_X+2,FORM_Y+13, NULL, SETTING_FUNC, 0, saveToNvram},	/* Save settings */

	{0, 0, NULL, SETTING_END}
};

const form_menu_t form_menu_nvram={
	displayFormNvram,
	updateFormNvram,

	initFormNvram,
	confirmFormNvram
};

static unsigned long start_tick;
static unsigned long cur_tick;

static unsigned char nvram[17];

static unsigned char vmodes_list[(36+1)*(11+4)];

/*--- Functions ---*/

void initFormNvram(void)
{
	const videomode_t *videomode_list;
	unsigned char *cur_vmode_name;
	unsigned char **cur_vmode_ptr;

	form_setting_nvram[FORM_SETTING_LANG].text = &form_nvram[FORM_LANG].text[10];
	form_setting_nvram[FORM_SETTING_LANG+1].text = &form_nvram[FORM_LANG+1].text[10];

	form_setting_nvram[FORM_SETTING_VIDEOMODE].text = &form_nvram[FORM_VIDEOMODE].text[12];
	form_setting_nvram[FORM_SETTING_DELAY].text = &form_nvram[FORM_DELAY].text[12];
	form_setting_nvram[FORM_SETTING_SCSI].text = &form_nvram[FORM_SCSI].text[1];
	form_setting_nvram[FORM_SETTING_SCSI+1].text = &form_nvram[FORM_SCSI].text[32];

	form_setting_nvram[FORM_SETTING_LOADSAVE].text = &form_nvram[FORM_LOADSAVE].text[0];
	form_setting_nvram[FORM_SETTING_LOADSAVE+1].text = &form_nvram[FORM_LOADSAVE+1].text[0];

	form_setting_nvram[FORM_SETTING_DATE].text = &form_nvram[FORM_DATE].text[6];
	form_setting_nvram[FORM_SETTING_DATE+1].text = &form_nvram[FORM_DATE].text[9];
	form_setting_nvram[FORM_SETTING_DATE+2].text = &form_nvram[FORM_DATE].text[12];

	form_setting_nvram[FORM_SETTING_TIME].text = &form_nvram[FORM_TIME].text[6];
	form_setting_nvram[FORM_SETTING_TIME+1].text = &form_nvram[FORM_TIME].text[9];
	/*form_setting_nvram[FORM_SETTING_TIME+2].text = &form_nvram[FORM_TIME].text[12];*/

	NVMaccess(NVM_READ, 0, 17, nvram);

	switch(VgetMonitor()) {
		case STmono:
			videomode_list = modes_mono;
			break;
		case VGAcolor:
			videomode_list = modes_vga;
			break;
		default:
			videomode_list = modes_tv;
			break;
	}

	cur_vmode_ptr = (unsigned char **) vmodes_list;
	cur_vmode_name = &vmodes_list[40*4];
	while ((videomode_list->width) && (videomode_list->height)) {
		*cur_vmode_ptr++ = cur_vmode_name;

		/* XXXxXXXxXX */
		format_number(&cur_vmode_name[0], videomode_list->width, 3, ' ');
		cur_vmode_name[3]='x';
		format_number(&cur_vmode_name[4], videomode_list->height, 3, ' ');
		cur_vmode_name[7]='x';
		format_number(&cur_vmode_name[8], 1<<(videomode_list->vmode & NUMCOLS), 2, ' ');
		cur_vmode_name[10]=0;

		cur_vmode_name = &cur_vmode_name[11];

		videomode_list++;
	}

	*cur_vmode_ptr = NULL;

	form_setting_nvram[FORM_SETTING_VIDEOMODE].param = vmodes_list;
}

void displayFormNvram(void)
{
	start_tick = getTicks();

	readClock();
	readNvram();

	vt_displayForm(form_nvram);
}

void updateFormNvram(void)
{
	/* Update time/date after 1 second */

	cur_tick = getTicks();
	if (cur_tick-start_tick<200) {
		return;
	}

	start_tick = cur_tick;

	readClock();
	vt_displayForm_idx(form_nvram, FORM_DATE, 2);
}

static void reloadFromNvram(void)
{
	NVMaccess(NVM_READ, 0, 17, nvram);

	readClock();
	readNvram();

	vt_displayForm(form_nvram);
}

static void saveToNvram(void)
{
	NVMaccess(NVM_WRITE, 0, 17, nvram);
}

static void confirmFormNvram(int num_setting, conf_setting_u confSetting)
{
	int i;
	unsigned short sys_date, sys_time;
	int save_date = 0;
	int save_time = 0;
	int refresh_nvram = 0;

	sys_date = Tgetdate();
	sys_time = Tgettime();

	switch(num_setting) {
		case FORM_SETTING_DATE:
			i = strToInt(confSetting.input);
			if ((i>=1) && (i<=31)) {
				sys_date &= ~(MASK_DATE_DAY<<SHIFT_DATE_DAY);
				sys_date |= i<<SHIFT_DATE_DAY;
				save_date = 1;
			}
			break;
		case FORM_SETTING_DATE+1:
			i = strToInt(confSetting.input);
			if ((i>=1) && (i<=12)) {
				sys_date &= ~(MASK_DATE_MONTH<<SHIFT_DATE_MONTH);
				sys_date |= i<<SHIFT_DATE_MONTH;
				save_date = 1;
			}
			break;
		case FORM_SETTING_DATE+2:
			i = strToInt(confSetting.input);
			if ((i>=1980) && (i<=1980+127)) {
				sys_date &= ~(MASK_DATE_YEAR<<SHIFT_DATE_YEAR);
				sys_date |= (i-1980)<<SHIFT_DATE_YEAR;
				save_date = 1;
			}
			break;
		case FORM_SETTING_TIME:
			i = strToInt(confSetting.input);
			if ((i>=0) && (i<=23)) {
				sys_time &= ~(MASK_TIME_HOUR<<SHIFT_TIME_HOUR);
				sys_time |= i<<SHIFT_TIME_HOUR;
				save_time = 1;
			}
			break;
		case FORM_SETTING_TIME+1:
			i = strToInt(confSetting.input);
			if ((i>=0) && (i<=59)) {
				sys_time &= ~((MASK_TIME_MINUTE<<SHIFT_TIME_MINUTE)|(MASK_TIME_SECOND<<SHIFT_TIME_SECOND));
				sys_time |= i<<SHIFT_TIME_MINUTE;
				save_time = 1;
			}
			break;
		case FORM_SETTING_DELAY:
			i = strToInt(confSetting.input);
			if ((i>=0) && (i<=255)) {
				nvram[NVRAM_DELAY] = i;
			}
			refresh_nvram = 1;
			break;
		case FORM_SETTING_SCSI:
			nvram[NVRAM_SCSI_ARB] ^= NVRAM_SCSI_ARB_ENABLE;
			refresh_nvram = 1;
			break;
		case FORM_SETTING_SCSI+1:
			i = strToInt(confSetting.input);
			if ((i>=0) && (i<=7)) {
				unsigned char scsi_setting = nvram[NVRAM_SCSI_ARB] & ~NVRAM_SCSI_ARB_DEVMASK;
				nvram[NVRAM_SCSI_ARB] = scsi_setting | i;
			}
			refresh_nvram = 1;
			break;
		case FORM_SETTING_LANG:
			nvram[NVRAM_LANGUAGE] = confSetting.num_list;
			refresh_nvram = 1;
			break;
		case FORM_SETTING_LANG+1:
			nvram[NVRAM_KEYBOARD] = confSetting.num_list;
			refresh_nvram = 1;
			break;
		case FORM_SETTING_VIDEOMODE:
			{
				const videomode_t *videomode_list;
				unsigned short vmode_code, vmode_mask;

				switch(VgetMonitor()) {
					case STmono:
						videomode_list = modes_mono;
						break;
					case VGAcolor:
						videomode_list = modes_vga;
						break;
					default:
						videomode_list = modes_tv;
						break;
				}

				vmode_mask = VsetMode(-1) & (VGA|PAL);
				vmode_code = videomode_list[confSetting.num_list].vmode | vmode_mask;
				nvram[NVRAM_VIDEO_HI] = vmode_code>>8;
				nvram[NVRAM_VIDEO_LO] = vmode_code;
				refresh_nvram = 1;
			}
			break;
	}

	if (save_date) {
		Tsetdate(sys_date);
	}
	if (save_time) {
		Tsettime(sys_time);
	}
	if (refresh_nvram) {
		readNvram();
		vt_displayForm(form_nvram);
	}
}

static void readClock(void)
{
	unsigned short sys_date, sys_time;

	/* Update date string */
	sys_date = Tgetdate();

	format_number(&form_setting_nvram[FORM_SETTING_DATE].text[0], sys_date & 31, 2, '0');
	format_number(&form_setting_nvram[FORM_SETTING_DATE].text[0+3], (sys_date>>5) & 15, 2, '0');
	format_number(&form_setting_nvram[FORM_SETTING_DATE].text[0+3+3], 1980 + ((sys_date>>9) & 127), 4, '0');

	/* Update time string */
	sys_time = Tgettime();

	format_number(&form_setting_nvram[FORM_SETTING_TIME].text[0], (sys_time>>11) & 31, 2, '0');
	format_number(&form_setting_nvram[FORM_SETTING_TIME].text[0+3], (sys_time>>5) & 63, 2, '0');
	format_number(&form_setting_nvram[FORM_SETTING_TIME].text[0+3+3], (sys_time & 31)<<1, 2, '0');
}

static void readNvram(void)
{
	int i;
	unsigned short vmode, vmode_mask = VERTFLAG|OVERSCAN|COL80|NUMCOLS;
	const videomode_t *vmode_list;

	/* Language, keyboard */
	i = nvram[NVRAM_LANGUAGE];
	if (i>NUM_LANG_TOS) {
		i = 0;
	}
	strCopy(lang_tos[i], &form_nvram[FORM_LANG].text[10]);

	i = nvram[NVRAM_KEYBOARD];
	if (i>=NUM_LANG_KBD) {
		i = 0;
	}
	strCopy(lang_kbd[i], &form_nvram[FORM_LANG+1].text[10]);

	/* Boot delay */
	format_number(&form_nvram[FORM_DELAY].text[12], nvram[NVRAM_DELAY], 3, ' ');

	/* SCSI arbitration */
	form_nvram[FORM_SCSI].text[1] =
		((nvram[NVRAM_SCSI_ARB] & NVRAM_SCSI_ARB_ENABLE) ? 'X' : ' ');
	form_nvram[FORM_SCSI].text[32] =
		'0'+(nvram[NVRAM_SCSI_ARB] & NVRAM_SCSI_ARB_DEVMASK);

	/* Video mode, only keep VERTFLAG,OVERSCAN,COL80,BPSn bits */
	/* Remove overscan flag for non tv,rgb */
	switch(VgetMonitor()) {
		case STmono:
			vmode_mask = VERTFLAG|COL80|NUMCOLS;
			vmode_list = modes_mono;
			break;
		case VGAcolor:
			vmode_mask = VERTFLAG|COL80|NUMCOLS;
			vmode_list = modes_vga;
			break;
		default:
			vmode_list = modes_tv;
			break;
	}

	vmode = ((nvram[NVRAM_VIDEO_HI]<<8)|nvram[NVRAM_VIDEO_LO]) & vmode_mask;

	/* Search video mode */
	while ((vmode_list->width) && (vmode_list->height)) {
		if (vmode_list->vmode == vmode) {
			break;
		}

		vmode_list++;
	}

	format_number(&form_setting_nvram[FORM_SETTING_VIDEOMODE].text[0], vmode_list->width, 3, ' ');
	format_number(&form_setting_nvram[FORM_SETTING_VIDEOMODE].text[4], vmode_list->height, 3, ' ');
	format_number(&form_setting_nvram[FORM_SETTING_VIDEOMODE].text[8], 1<<(vmode_list->vmode & NUMCOLS), 2, ' ');
}
