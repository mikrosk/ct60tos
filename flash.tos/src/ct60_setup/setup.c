/*
	CT60 Setup

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
#include <stdint.h>

#include <mint/osbind.h>
#include <mint/falcon.h>
#include <mint/cookie.h>
#include <vt52.h>

#include "config.h"
#include "asm_procs.h"
#include "form_vt.h"
#include "form_nvram.h"
#include "form_ct60.h"
#include "form_cpu.h"
#include "form_sdram.h"
#include "form_boot.h"
#include "form_exit.h"
#include "scancodes.h"
#include "video.h"
#include "misc.h"
#include "ct60.h"

/*--- Defines ---*/

#define CHANGE_VIDEO_MODE 1

#define NUM_MENU_ENTRIES 9

enum {
	STATE_MENU=0,		/* Selecting a form in left menu */
	STATE_FORM_SELECT,	/* Selecting a parameter to edit */
	STATE_FORM_INPUT,	/* Input a string */
	STATE_FORM_LIST,	/* List selection */
	STATE_FORM_UPDOWN	/* Selection using up/down calculation */
};

/*--- Types ---*/

typedef struct {
	const char	*name;
	const form_menu_t	*form;
	const form_setting_t	*settings;
} menu_t;

/*--- Variables ---*/

static const form_menu_t form_menu_empty={
	vt_clearForm,
	NULL
};

static const menu_t menu[NUM_MENU_ENTRIES]={
	{"NVRAM     ",	&form_menu_nvram, &form_setting_nvram[0]},
	{"          ",	&form_menu_empty, NULL},
	{"CT60      ",	&form_menu_ct60, NULL},
	{" CPU      ",	&form_menu_cpu, &form_setting_cpu[0]},
	{" SDRAM    ",	&form_menu_sdram, NULL},
	{"          ",	&form_menu_empty, NULL},
	{"CT60 BOOT ",	&form_menu_boot, &form_setting_boot[0]},
	{"          ",	&form_menu_empty, NULL},
	{"EXIT      ",	&form_menu_exit, &form_setting_exit[0]}
};

static int menu_refresh = 1;
static int form_refresh = 1;
static int setup_state = STATE_MENU;
static int menu_row = 0;
int has_ct60 = 0;
int cpu_cookie=0;

/*--- Functions prototypes ---*/

static void display_banner(void);
static void display_menu(void);
static void display_status(void);

static void setup_menu(unsigned long key_pressed);
static void setup_form_select(unsigned long key_pressed);
static void setup_list_select(unsigned long key_pressed);
static void setup_updown_select(unsigned long key_pressed);

char *basepage;
/*--- Functions ---*/
void forcecachect60()
{
	if (!has_ct60) {
		return;
	}
	ct60_cache(1);
};

//void debout(long val) { char s; for (s = 28; s >= 0; s -= 4) Cconout("0123456789ABCDEF"[(val >> s) & 0xF]); };

void __main(void)
{
	volatile uint32_t * const sysvars = (uint32_t *)0x400;
#if SETUP_STANDALONE
	unsigned long cookie_mch=0;
	getCookie(C__MCH,&cookie_mch);
	if ((cookie_mch>>16)!=3) {
		Cconws("\033ESYSTEM NOT SUPPORTED\r\nPRESS ANY KEY TO QUIT\r\n");
		Cnecin();
		return;
	};
#endif

	unsigned long cookie_ct60;
	has_ct60 = getCookie(C_CT60, &cookie_ct60);


#if CHANGE_VIDEO_MODE
	video_save();
	vt_height=get_text_max()&0xff;
#endif
	forcecachect60();

	display_banner();
	vt_initSettings(NULL);

	while (exit_type == SETUP_CONTINUE) {
		unsigned long key_pressed;

		/* Refresh menu, form, and status line */
		if (menu_refresh) {
			display_menu();
			menu_refresh = 0;
			form_refresh = 1;
			if (menu[menu_row].form->init) {
				menu[menu_row].form->init();
			}
			vt_initSettings(menu[menu_row].settings);
		}
		if (form_refresh) {
			vt_clearForm();
			menu[menu_row].form->display();
			form_refresh = 0;
		}
		display_status();

		/* Wait key press */
		while (Cconis()==0) {
			Vsync();

			if (menu[menu_row].form->update) {
				menu[menu_row].form->update();
			}

			/* Replace cursor on setting */
			if (setup_state == STATE_FORM_SELECT) {
				vt_setting_show();
			}
		}

		key_pressed = Cnecin();

		switch(setup_state) {
			case STATE_MENU:
				setup_menu(key_pressed);
				break;
			case STATE_FORM_SELECT:
				setup_form_select(key_pressed);
				break;
			case STATE_FORM_LIST:
				setup_list_select(key_pressed);
				break;
			case STATE_FORM_UPDOWN:
				setup_updown_select(key_pressed);
				break;
		}
	}

#if CHANGE_VIDEO_MODE
	video_restore();
#else
	vt_setFgColor(COL_BLACK);
	vt_setBgColor(COL_WHITE);
	Cconws("\r\n" C_ON);
#endif

#if !SETUP_STANDALONE
	if (exit_type == SETUP_DIAG) {
		void *old_stack = (void *) Super(0);
		start_diag_asm();
		Super(old_stack);
	};
	Super(0);
	if (exit_type == SETUP_RESET_COLD) {
		sysvars[0x20/4]=0;
		sysvars[0x3a/4]=0;
	}
	__asm__ __volatile__(
		"jmp\t0xe00030"
	);
#endif
}

void CcenterY(const char *src, int y)
{
  	vt_setCursorPos((WIDTH-strLength(src))>>1,y);
	Cconws(src);
};

static void display_banner(void)
{
  	char msg[256];
	char msg1[]="CT60";
	char msg2[]="Setup";
	int i,l,p,s;
	Cconws(CLEAR_HOME C_OFF);

	vt_setFgColor(COL_BANNER_FG);
	vt_setBgColor(COL_BANNER_BG);

	Cconws(CLEAR_DOWN);

	strCopy("CT60 Setup v1.3.0",msg);
#if !SETUP_STANDALONE
	if ((basepage[0x80]!=0)&&(basepage[0x81]==27)) { // read tos build date from basepage if run from ct60tos
		p=s=0;
		while (msg1[s]) msg[p++]=msg1[s++];
		l=basepage[0x80]-7; // skip escape sequence
		for (i=0;i<l;i++) msg[p++]=basepage[0x83+i];
		strCopy(msg2,&msg[p]);
	}
#endif

	CcenterY(msg,0);
	CcenterY("(C) 2009 Patrice Mandin, 2019-2026 Daniel Illgen",1);
}

static void display_menu(void)
{
	int i;

	vt_setFgColor(COL_MENU_FG);
	for (i=0; i<FORM_H; i++) {
		vt_setCursorPos(FORM_X,FORM_Y+i);
		vt_setBgColor(COL_MENU_BG);
		if (i<NUM_MENU_ENTRIES) {
			if (i==menu_row) vt_setBgColor(COL_MENU_BG_SEL);
			vt_setCursorPos(0,FORM_Y+i);
			Cconws(menu[i].name);
		} else {
			vt_setCursorPos(0,FORM_Y+i);
			Cconws("          ");
		};
	}
}

static void display_status(void)
{
	vt_setFgColor(COL_BANNER_FG);
	vt_setBgColor(COL_BANNER_BG);
	
	vt_setCursorPos(0,HEIGHT);

	switch(setup_state) {
		case STATE_MENU:
			Cconws(CLEAR_DOWN "UP/DOWN: Select menu, ENTER: Enter menu, ESC: Quit");
			break;
		case STATE_FORM_SELECT:
			Cconws(CLEAR_DOWN "ARROWS: Select setting, ENTER: Enter setting, ESC: Back");
			break;
		case STATE_FORM_INPUT:
			Cconws(CLEAR_DOWN "Enter new value: ");
			break;
		case STATE_FORM_LIST:
			Cconws(CLEAR_DOWN "Select new value: ");
			vt_setting_listPrint();
			break;
		case STATE_FORM_UPDOWN:
			Cconws(CLEAR_DOWN "Select new value: ");
			vt_setting_updown(SETTING_DIR_PRINT);
			break;
	}
}

static void setup_menu(unsigned long key_pressed)
{
	unsigned char asciicode, scancode;

	asciicode = key_pressed & 0xff;
	scancode = (key_pressed >> 16) & 0xff;

	switch(scancode) {
		case SCANCODE_ESCAPE:
//			exit_type = SETUP_EXIT;
			menu_row=NUM_MENU_ENTRIES-1;
			menu_refresh = 1;
			if (menu[menu_row].settings) {
				setup_state = STATE_FORM_SELECT;
			}
			break;
		case SCANCODE_UP:
			if (menu_row>0) {
				do { --menu_row; } while ((menu_row>0)&&(menu[menu_row].form==&form_menu_empty));
			} else menu_row=NUM_MENU_ENTRIES-1;
			menu_refresh = 1;
			break;
		case SCANCODE_DOWN:
			if (menu_row<NUM_MENU_ENTRIES-1) {
				do { ++menu_row; } while ((menu_row<NUM_MENU_ENTRIES-1)&&(menu[menu_row].form==&form_menu_empty));
			} else menu_row = 0;
			menu_refresh = 1;
			break;
		case SCANCODE_ENTER:
		case SCANCODE_SPACE:
		case SCANCODE_RIGHT:	/* First parameter on first row */
			if (menu[menu_row].settings) {
				setup_state = STATE_FORM_SELECT;
			}
			break;
	}
}

static void setup_form_select(unsigned long key_pressed)
{
	unsigned char asciicode, scancode;

	asciicode = key_pressed & 0xff;
	scancode = (key_pressed >> 16) & 0xff;

	switch(scancode) {
		case SCANCODE_ESCAPE:
			setup_state = STATE_MENU;
			menu_refresh = 1;
			break;
		case SCANCODE_UP:	/* First parameter on previous row */
			vt_setting_prevRow();
			break;
		case SCANCODE_DOWN:	/* First parameter on next row */
			vt_setting_nextRow();
			break;
		case SCANCODE_LEFT:	/* Previous parameter on same row */
			if (vt_setting_prev()) {
				setup_state = STATE_MENU;
				menu_refresh = 1;
			};
			break;
		case SCANCODE_RIGHT:	/* Next parameter on same row */
			vt_setting_next();
			break;
		case SCANCODE_SPACE:
		case SCANCODE_ENTER:
		case SCANCODE_KP_ENTER:
			switch(vt_setting_getType()) {
				case SETTING_INPUT:
					{
						const char *strInput;

						setup_state = STATE_FORM_INPUT;
						display_status();


						Cconws(C_ON);
						strInput = vt_readString();
						Cconws(C_OFF);

						vt_setting_newValue(menu[menu_row].form, strInput);
						setup_state = STATE_FORM_SELECT;
					}
					break;
				case SETTING_FUNC:
					vt_setting_execFunc();
					break;
				case SETTING_BOOL:
					vt_setting_newValue(menu[menu_row].form, NULL);
					break;
				case SETTING_LIST:
					setup_state = STATE_FORM_LIST;
					vt_setting_listInit();
					break;
				case SETTING_UPDOWN:
					setup_state = STATE_FORM_UPDOWN;
					break;
			}
			break;
	}
}

static void setup_list_select(unsigned long key_pressed)
{
	unsigned char asciicode, scancode;

	asciicode = key_pressed & 0xff;
	scancode = (key_pressed >> 16) & 0xff;

	switch(scancode) {
		case SCANCODE_ESCAPE:
			setup_state = STATE_FORM_SELECT;
			break;
		case SCANCODE_UP:
		case SCANCODE_LEFT:
			vt_setting_listPrev();
			break;
		case SCANCODE_DOWN:
		case SCANCODE_RIGHT:
			vt_setting_listNext();
			break;
		case SCANCODE_SPACE:
		case SCANCODE_ENTER:
		case SCANCODE_KP_ENTER:
			vt_setting_newValue(menu[menu_row].form, NULL);
			setup_state = STATE_FORM_SELECT;
			break;
	}
}

static void setup_updown_select(unsigned long key_pressed)
{
	unsigned char asciicode, scancode;

	asciicode = key_pressed & 0xff;
	scancode = (key_pressed >> 16) & 0xff;

	switch(scancode) {
		case SCANCODE_ESCAPE:
			setup_state = STATE_FORM_SELECT;
			break;
		case SCANCODE_UP:
			vt_setting_updown(SETTING_DIR_UP);
			break;
		case SCANCODE_LEFT:
			vt_setting_updown(SETTING_DIR_LEFT);
			break;
		case SCANCODE_DOWN:
			vt_setting_updown(SETTING_DIR_DOWN);
			break;
		case SCANCODE_RIGHT:
			vt_setting_updown(SETTING_DIR_RIGHT);
			break;
		case SCANCODE_SPACE:
		case SCANCODE_ENTER:
		case SCANCODE_KP_ENTER:
			vt_setting_newValue(menu[menu_row].form, NULL);
			setup_state = STATE_FORM_SELECT;
			break;
	}
}
