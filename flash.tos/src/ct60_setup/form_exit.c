/*
	CT60 Setup
	Exit

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

#include "config.h"
#include "form_vt.h"
#include "form_exit.h"

/*--- Defines ---*/

#if SETUP_STANDALONE
#define FORM_CONTINUE 1
#define FORM_RESET (FORM_CONTINUE+1)
#define FORM_RCOLD (FORM_RESET+1)
#define FORM_DIAG  (FORM_RCOLD+1)

#define FORM_SETTING_CONTINUE 0
#define FORM_SETTING_RESET (FORM_SETTING_CONTINUE+1)
#define FORM_SETTING_RCOLD (FORM_SETTING_RESET+1)
#define FORM_SETTING_DIAG  (FORM_SETTING_RCOLD+1)

#define YPOS_CONT  FORM_Y+2
#define YPOS_RESET FORM_Y+3
#define YPOS_RCOLD FORM_Y+4
#define YPOS_DIAG  FORM_Y+6
#else
#define FORM_RESET 1
#define FORM_RCOLD (FORM_RESET+1)
#define FORM_DIAG  (FORM_RCOLD+1)

#define FORM_SETTING_RESET 0
#define FORM_SETTING_RCOLD (FORM_SETTING_RESET+1)
#define FORM_SETTING_DIAG  (FORM_SETTING_RCOLD+1)

#define YPOS_RESET FORM_Y+2
#define YPOS_RCOLD FORM_Y+3
#define YPOS_DIAG  FORM_Y+5
#endif
/*--- Global variables ---*/

unsigned char exit_type;

/*--- Const ---*/

static void exitContinue(void);
static void exitReset(void);
static void exitResetCold(void);
static void exitDiag(void);

static form_t form_exit[]={
	{FORM_TITLE, "Exit", FORM_X+((FORM_W-4)>>1), FORM_Y},
#if SETUP_STANDALONE
	{FORM_TEXT, "Exit to TOS", FORM_X+2,YPOS_CONT},
#else
	{FORM_TEXT, "Exit and warm reboot", FORM_X+2,YPOS_RESET},
	{FORM_TEXT, "Exit and cold reboot", FORM_X+2,YPOS_RCOLD},
	{FORM_TEXT, "Exit to diagnostics", FORM_X+2,YPOS_DIAG},
#endif
	{FORM_END, 0,0,0}
};

form_setting_t form_setting_exit[]={
#if SETUP_STANDALONE
	{FORM_X+2,YPOS_CONT , NULL, SETTING_FUNC, 0, exitContinue},
#else
	{FORM_X+2,YPOS_RESET, NULL, SETTING_FUNC, 0, exitReset},
	{FORM_X+2,YPOS_RCOLD, NULL, SETTING_FUNC, 0, exitResetCold},
	{FORM_X+2,YPOS_DIAG , NULL, SETTING_FUNC, 0, exitDiag},
#endif
	{0, 0, NULL, SETTING_END}
};

/*--- Variables ---*/

static void initFormExit(void);

const form_menu_t form_menu_exit={
	displayFormExit,
	NULL,
	initFormExit,
	NULL
};

/*--- Functions ---*/
static int diag_installed()
{
	void *old_stack = (void *) Super(0);

	unsigned long value = *((volatile long *)0x00ed0000);

	Super(old_stack);

	return value==0xFA52235F;
}


static void initFormExit(void)
{

#if SETUP_STANDALONE
	form_setting_exit[FORM_SETTING_CONTINUE].text = &form_exit[FORM_CONTINUE].text[0];
#else
	form_setting_exit[FORM_SETTING_RESET].text = &form_exit[FORM_RESET].text[0];
	form_setting_exit[FORM_SETTING_RCOLD].text = &form_exit[FORM_RCOLD].text[0];
	form_setting_exit[FORM_SETTING_DIAG].text = &form_exit[FORM_DIAG].text[0];

	if (!diag_installed()) {
	   form_setting_exit[FORM_SETTING_DIAG].text[0]=0;
	   form_setting_exit[FORM_SETTING_DIAG].input=SETTING_END;
	};
#endif
}

void displayFormExit(void)
{
	vt_displayForm(form_exit);
}

void exitContinue(void)
{
	exit_type = SETUP_EXIT;
}

void exitReset(void)
{
	exit_type = SETUP_RESET;
}

void exitResetCold(void)
{
	exit_type = SETUP_RESET_COLD;
}

void exitDiag(void)
{
	exit_type = SETUP_DIAG;
}
