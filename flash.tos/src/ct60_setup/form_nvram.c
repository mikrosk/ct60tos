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

#include "config.h"
#include "form_vt.h"
#include "form_nvram.h"
#include "misc.h"
#include "nvram.h"

/*--- Defines ---*/

#define FORM_DATE 1
#define FORM_TIME 2
#define FORM_LANG 3
#define FORM_FMT  4
#define FORM_VIDEOMODE 5
#define FORM_BOOT 6
#define FORM_SCSI 7
#define FORM_LOADSAVE 8
#define FORM_NOTE 10
#define FORM_NOTES 5

#define FORM_SETTING_DATE 0
#define FORM_SETTING_TIME (FORM_SETTING_DATE+3)
#define FORM_SETTING_LANG (FORM_SETTING_TIME+2)
#define FORM_SETTING_KEYB (FORM_SETTING_LANG+1)
#define FORM_SETTING_TFMT (FORM_SETTING_KEYB+1)
#define FORM_SETTING_DFMT (FORM_SETTING_TFMT+1)
#define FORM_SETTING_VIDEOMODE (FORM_SETTING_DFMT+1)
#define FORM_SETTING_DELAY (FORM_SETTING_VIDEOMODE+4)
#define FORM_SETTING_BOOTPREF (FORM_SETTING_DELAY+1)
#define FORM_SETTING_SCSI (FORM_SETTING_BOOTPREF+1)
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

static const char *str_boot_pref[]={
  	"None   ",
	"MagiC  ",
	"Linux  ",
	"NetBSD ",
	"TT SVR4",
	"TOS    ",
	NULL
};

static const char code_boot_pref[]={
  	NVRAM_BOOT_NONE,
	NVRAM_BOOT_MAGIC,
	NVRAM_BOOT_LINUX,
	NVRAM_BOOT_NETBSD,
	NVRAM_BOOT_SVR4,
	NVRAM_BOOT_TOS
};

static const char *str_tfmt[]={
  	"12h",
	"24h",
	NULL
};

static char *str_dfmt[]={
	"MM.DD.YY",
	"DD.MM.YY",
	"YY.MM.DD",
	"YY.DD.MM",
	"MM/DD/YY",
	"DD/MM/YY",
	"YY/MM/DD",
	"YY/DD/MM",
	"MM-DD-YY",
	"DD-MM-YY",
	"YY-MM-DD",
	"YY-DD-MM",
	NULL
};

static const char *vmodes_res[]={
	"VGA 640x480",
	"VGA 640x240",
	"VGA 320x480",
	"VGA 320x240",
	"RGB 640x400",
	"RGB 640x200",
	"RGB 320x400",
	"RGB 320x200",
	"RGB 768x480",
	"RGB 768x240",
	"RGB 384x480",
	"RGB 384x240",
	NULL
};

static const int vmodes_res_c80[]={
   8, 8, 0, 0,
   8, 8, 0, 0,
   8, 8, 0, 0,
};

static const int vmodes_res_vga[]={
  16,16,16,16,
   0, 0, 0, 0,
   0, 0, 0, 0
};

static const int vmodes_res_ovr[]={
   0, 0, 0, 0,
   0, 0, 0, 0,
  64,64,64,64
};

static const int vmodes_res_ldb[]={
     0, 256,   0, 256,
   256,   0, 256,   0,
   256,   0, 256,   0,
};


static const char *vmodes_planes[]={
	"x1","x2","x4","x8","TC",NULL
};

static const char *vmodes_hz[]={
	"PAL ","NTSC",NULL
};

static const char *vmodes_flags[]={
	"ON ","OFF",NULL
};

/*--- Functions prototypes ---*/

static void reloadFromNvram(void);
static void saveToNvram(void);
static void confirmFormNvram(int num_setting, conf_setting_u confSetting);

static void readClock(void);
static void readNvram(void);

/*--- Variables ---*/
#define FPOS_VID_RES 12
#define FPOS_VID_PLANES 24
#define FPOS_VID_HZ 28
#define FPOS_VID_FLAGS 50
#define FPOS_DELAY 12
#define FPOS_BOOTPREF 35
#define FPOS_LANG 13
#define FPOS_KEYB 30
#define FPOS_TFMT 13
#define FPOS_DFMT 30

static form_t form_nvram[]={
	/* Static info */
	{FORM_TITLE, "NVRAM", FORM_X+((FORM_W-5)>>1), FORM_Y},

	{FORM_TEXT, "Date: -- -- ----", FORM_X+2,FORM_Y+2},
	{FORM_TEXT, "Time: --:--:--", FORM_X+2,FORM_Y+3},

	{FORM_TEXT, "Language   : --  Keyboard   : --", FORM_X+2,FORM_Y+5},
	{FORM_TEXT, "Time-Format: --- Date-Format: -- -- --", FORM_X+2,FORM_Y+6},

	{FORM_TEXT, "Video mode: ----------- --, ----, ST compatiblity ---", FORM_X+2,FORM_Y+8},
	{FORM_TEXT, "Boot delay: ---s, Boot preference: -------", FORM_X+2,FORM_Y+9},
	{FORM_TEXT, "[-] SCSI arbitration, as device -", FORM_X+2,FORM_Y+10},

	{FORM_TEXT, "Reload NVRAM settings", FORM_X+2,FORM_Y+12},
	{FORM_TEXT, "Save NVRAM settings", FORM_X+2,FORM_Y+13},
               //012345678901234567890123456789012345678901234567890123456789012345
#if SETUP_STANDALONE
	{FORM_TEXT, "", FORM_X+2,0},
	{FORM_TEXT, "", FORM_X+2,0},
#endif
	{FORM_TEXT, "NOTE:", FORM_X+2,0},
	{FORM_TEXT, "Illegal Video Modes like VGA 640x480xTC can lead to a black screen", FORM_X+2,0},
	{FORM_TEXT, "unless you have a modified VIDEL clock installed. ", FORM_X+2,0},
#if !SETUP_STANDALONE
	{FORM_TEXT, "Should your monitor fail to sync on boot then pressing the ", FORM_X+2,0},
	{FORM_TEXT, "DELETE key blindly will get you back into the setup program.", FORM_X+2,0},
#endif
	{FORM_END, 0,0,0}
};

form_setting_t form_setting_nvram[]={
	{FORM_X+8,FORM_Y+2, NULL, SETTING_INPUT, 2},		/* Date */
	{FORM_X+8+3,FORM_Y+2, NULL, SETTING_INPUT, 2},
	{FORM_X+8+3+3,FORM_Y+2, NULL, SETTING_INPUT, 4},

	{FORM_X+8,FORM_Y+3, NULL, SETTING_INPUT, 2},		/* Time */
	{FORM_X+8+3,FORM_Y+3, NULL, SETTING_INPUT, 2},
	/*{FORM_X+8+3+3,FORM_Y+3, NULL, SETTING_INPUT, 2},*/

	{FORM_X+2+FPOS_LANG,FORM_Y+5, NULL, SETTING_LIST, 2, lang_tos},	/* TOS language */
	{FORM_X+2+FPOS_KEYB,FORM_Y+5, NULL, SETTING_LIST, 2, lang_kbd},	/* Keyboard language */
	{FORM_X+2+FPOS_TFMT,FORM_Y+6, NULL, SETTING_LIST, 3, str_tfmt},
	{FORM_X+2+FPOS_DFMT,FORM_Y+6, NULL, SETTING_LIST, 8, str_dfmt},	/* Keyboard language */

	{FORM_X+2+FPOS_VID_RES   ,FORM_Y+8, NULL, SETTING_LIST, 11, vmodes_res},	/* Video mode */
	{FORM_X+2+FPOS_VID_PLANES,FORM_Y+8, NULL, SETTING_LIST, 2, vmodes_planes},	/* Planes */
	{FORM_X+2+FPOS_VID_HZ    ,FORM_Y+8, NULL, SETTING_LIST, 4, vmodes_hz},	/* 50/60 */
	{FORM_X+2+FPOS_VID_FLAGS ,FORM_Y+8, NULL, SETTING_LIST, 3, vmodes_flags},	/* ST */
	{FORM_X+2+FPOS_DELAY,FORM_Y+9, NULL, SETTING_INPUT, 3},	/* Boot delay */
	{FORM_X+2+FPOS_BOOTPREF  ,FORM_Y+9, NULL, SETTING_LIST, 7, str_boot_pref},	/* Boot preference */

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

static unsigned char bootval=0;
/*--- Functions ---*/

void initFormNvram(void)
{
  	int i;
  	for (i=0;i<FORM_NOTES;i++)
	form_nvram[FORM_NOTE+i].posy=HEIGHT-1-FORM_NOTES+i;
	form_setting_nvram[FORM_SETTING_LANG].text = &form_nvram[FORM_LANG].text[FPOS_LANG];
	form_setting_nvram[FORM_SETTING_KEYB].text = &form_nvram[FORM_LANG].text[FPOS_KEYB];
	form_setting_nvram[FORM_SETTING_TFMT].text = &form_nvram[FORM_FMT ].text[FPOS_TFMT];
	form_setting_nvram[FORM_SETTING_DFMT].text = &form_nvram[FORM_FMT ].text[FPOS_DFMT];

	form_setting_nvram[FORM_SETTING_VIDEOMODE].text = &form_nvram[FORM_VIDEOMODE].text[FPOS_VID_RES];
	form_setting_nvram[FORM_SETTING_VIDEOMODE+1].text = &form_nvram[FORM_VIDEOMODE].text[FPOS_VID_PLANES];
	form_setting_nvram[FORM_SETTING_VIDEOMODE+2].text = &form_nvram[FORM_VIDEOMODE].text[FPOS_VID_HZ];
	form_setting_nvram[FORM_SETTING_VIDEOMODE+3].text = &form_nvram[FORM_VIDEOMODE].text[FPOS_VID_FLAGS];
	form_setting_nvram[FORM_SETTING_DELAY].text = &form_nvram[FORM_BOOT].text[FPOS_DELAY];
	form_setting_nvram[FORM_SETTING_BOOTPREF].text = &form_nvram[FORM_BOOT].text[FPOS_BOOTPREF];
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
	unsigned short vmode = ((nvram[NVRAM_VIDEO_HI]<<8)|nvram[NVRAM_VIDEO_LO]);

	sys_date = Tgetdate();
	sys_time = Tgettime();

	switch(num_setting) {
		case FORM_SETTING_DATE:
			i = strToInt(confSetting.input);
			if (nvram[NVRAM_DATE_FMT]&1) {
				if ((i>=1) && (i<=31)) {
					sys_date &= ~(MASK_DATE_DAY<<SHIFT_DATE_DAY);
					sys_date |= i<<SHIFT_DATE_DAY;
					save_date = 1;
				}
			} else {
				if ((i>=1) && (i<=12)) {
					sys_date &= ~(MASK_DATE_MONTH<<SHIFT_DATE_MONTH);
					sys_date |= i<<SHIFT_DATE_MONTH;
					save_date = 1;
				}
			}
			break;
		case FORM_SETTING_DATE+1:
			i = strToInt(confSetting.input);
			if (nvram[NVRAM_DATE_FMT]&1) {
				if ((i>=1) && (i<=12)) {
					sys_date &= ~(MASK_DATE_MONTH<<SHIFT_DATE_MONTH);
					sys_date |= i<<SHIFT_DATE_MONTH;
					save_date = 1;
				}
			} else {
				if ((i>=1) && (i<=31)) {
					sys_date &= ~(MASK_DATE_DAY<<SHIFT_DATE_DAY);
					sys_date |= i<<SHIFT_DATE_DAY;
					save_date = 1;
				}
			};
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
		case FORM_SETTING_BOOTPREF:
			bootval = confSetting.num_list;
			nvram[NVRAM_BOOT]=code_boot_pref[bootval];
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
		case FORM_SETTING_KEYB:
			nvram[NVRAM_KEYBOARD] = confSetting.num_list;
			refresh_nvram = 1;
			break;
		case FORM_SETTING_TFMT:
			nvram[NVRAM_DATE_FMT] &= NVRAM_DATE_FMT_DATEMASK;
			nvram[NVRAM_DATE_FMT] |= confSetting.num_list?NVRAM_DATE_FMT_24H:NVRAM_DATE_FMT_12H;
			refresh_nvram = 1;
			break;
		case FORM_SETTING_DFMT:
			nvram[NVRAM_DATE_FMT] &= NVRAM_DATE_FMT_TIMEMASK;
			nvram[NVRAM_DATE_FMT] |= confSetting.num_list & NVRAM_DATE_FMT_DATEMASK;
			nvram[NVRAM_DATE_SEP] = str_dfmt[confSetting.num_list][2];
			refresh_nvram = 1;
			break;
		case FORM_SETTING_VIDEOMODE:
			{
				vmode &=0xfea7; 
				vmode|=vmodes_res_c80[confSetting.num_list];
				vmode|=vmodes_res_vga[confSetting.num_list];
				vmode|=vmodes_res_ovr[confSetting.num_list];
				vmode|=vmodes_res_ldb[confSetting.num_list];
				nvram[NVRAM_VIDEO_HI] = vmode>>8;
				nvram[NVRAM_VIDEO_LO] = vmode;
				refresh_nvram = 1;
				
			}
			break;
		case FORM_SETTING_VIDEOMODE+1:
			{
				vmode &=0xfff8; vmode|=confSetting.num_list;
				nvram[NVRAM_VIDEO_HI] = vmode>>8;
				nvram[NVRAM_VIDEO_LO] = vmode;
				refresh_nvram = 1;
				
			}
			break;
		case FORM_SETTING_VIDEOMODE+2: //hz
			{
				vmode &=0xffdf; vmode|=confSetting.num_list?0:32;
				nvram[NVRAM_VIDEO_HI] = vmode>>8;
				nvram[NVRAM_VIDEO_LO] = vmode;
				refresh_nvram = 1;
				
			}
			break;
		case FORM_SETTING_VIDEOMODE+3: //ST
			{
				vmode &=0xff7f; vmode|=confSetting.num_list?0:128;
				nvram[NVRAM_VIDEO_HI] = vmode>>8;
				nvram[NVRAM_VIDEO_LO] = vmode;
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

	if (nvram[NVRAM_DATE_FMT]&1) {
		format_number(&form_setting_nvram[FORM_SETTING_DATE].text[0], sys_date & 31, 2, '0');
		format_number(&form_setting_nvram[FORM_SETTING_DATE].text[3], (sys_date>>5) & 15, 2, '0');
	} else {
		format_number(&form_setting_nvram[FORM_SETTING_DATE].text[3], sys_date & 31, 2, '0');
		format_number(&form_setting_nvram[FORM_SETTING_DATE].text[0], (sys_date>>5) & 15, 2, '0');
	};
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
	unsigned short vmode;
	char c;

	/* Language, keyboard */
	i = nvram[NVRAM_LANGUAGE];
	if (i>NUM_LANG_TOS) {
		i = 0;
	}
	strCopyU(lang_tos[i], &form_nvram[FORM_LANG].text[FPOS_LANG]);

	i = nvram[NVRAM_KEYBOARD];
	if (i>=NUM_LANG_KBD) {
		i = 0;
	}
	strCopyU(lang_kbd[i], &form_nvram[FORM_LANG].text[FPOS_KEYB]);

	i = nvram[NVRAM_DATE_FMT] & NVRAM_DATE_FMT_TIMEMASK?1:0;
	strCopyU(str_tfmt[i], &form_nvram[FORM_FMT ].text[FPOS_TFMT]);

	i = nvram[NVRAM_DATE_FMT] & NVRAM_DATE_FMT_DATEMASK;

	c=nvram[NVRAM_DATE_SEP];
	switch (nvram[NVRAM_DATE_SEP]) {
	  case '.': c='.'; i+=0; break;
	  case '-': c='-'; i+=8; break;
	  default : c='/'; i+=4; break;
	};
	
	form_nvram[FORM_DATE].text[8 ]=c;
	form_nvram[FORM_DATE].text[11]=c;

	strCopyU(str_dfmt[i], &form_nvram[FORM_FMT ].text[FPOS_DFMT]);

	/* Boot delay */
	format_number(form_setting_nvram[FORM_SETTING_DELAY].text, nvram[NVRAM_DELAY], 3, ' ');

	/* Boot Preference */
	bootval=0;
	if (nvram[NVRAM_BOOT]==NVRAM_BOOT_MAGIC ) bootval=1; else
	if (nvram[NVRAM_BOOT]==NVRAM_BOOT_LINUX ) bootval=2; else
	if (nvram[NVRAM_BOOT]==NVRAM_BOOT_NETBSD) bootval=3; else
	if (nvram[NVRAM_BOOT]==NVRAM_BOOT_SVR4  ) bootval=4; else
	if (nvram[NVRAM_BOOT]==NVRAM_BOOT_TOS   ) bootval=5;
	strCopy(str_boot_pref[bootval],form_setting_nvram[FORM_SETTING_BOOTPREF].text);

	/* SCSI arbitration */
	form_nvram[FORM_SCSI].text[1] =
		((nvram[NVRAM_SCSI_ARB] & NVRAM_SCSI_ARB_ENABLE) ? 'X' : ' ');
	form_nvram[FORM_SCSI].text[32] =
		'0'+(nvram[NVRAM_SCSI_ARB] & NVRAM_SCSI_ARB_DEVMASK);

	vmode = ((nvram[NVRAM_VIDEO_HI]<<8)|nvram[NVRAM_VIDEO_LO]);
	i=0;
	i|=vmode&8?0:2;  //c80
	i|=vmode&256?0:1;//ldbl
	if (vmode&16) { //VGA
	  i^=1;
	} else { //RGB
	  i|=4;
	  i+=(vmode&64)?4:0;
	};
	

	strCopyU(vmodes_res[i], form_setting_nvram[FORM_SETTING_VIDEOMODE].text);
	i=vmode&7;if (i>4) i=0;
	strCopyU(vmodes_planes[i], form_setting_nvram[FORM_SETTING_VIDEOMODE+1].text);
	i=vmode&32?0:1;
	strCopyU(vmodes_hz[i], form_setting_nvram[FORM_SETTING_VIDEOMODE+2].text);
	i=vmode&128?0:1;
	strCopyU(vmodes_flags[i], form_setting_nvram[FORM_SETTING_VIDEOMODE+3].text);


	format_number_hex(&form_nvram[FORM_VIDEOMODE].text[6],(vmode),4,0);
	
}
