/*
	CT60 Setup
	VT52 functions

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

#ifndef FORM_VT_H
#define FORM_VT_H 1

/*--- Defines ---*/

#define WIDTH 80
#define HEIGHT 24

#define FORM_X	10
#define FORM_Y	2
#define FORM_W (WIDTH-FORM_X)
#define FORM_H (HEIGHT-FORM_Y)

enum vt_colors_e {
	COL_WHITE='0', COL_RED, COL_GREEN, COL_YELLOW,
	COL_BLUE, COL_PINK, COL_LIGHTBLUE, COL_LIGHTGRAY,
	COL_DARKGRAY, COL_DARKRED, COL_DARKGREEN, COL_DARKYELLOW,
	COL_DARKBLUE, COL_DARKPINK, COL_DARKLIGHTBLUE, COL_BLACK
};

#if 1
#define COL_BANNER_FG COL_WHITE
#define COL_BANNER_BG COL_BLACK
#define COL_MENU_FG	COL_WHITE
#define COL_MENU_BG COL_DARKGRAY
#define COL_MENU_BG_SEL COL_LIGHTGRAY
#define COL_FORM_TITLE COL_LIGHTGRAY
#define COL_FORM_FG COL_YELLOW
#define COL_FORM_BG COL_DARKBLUE
#endif

#if 0
#define COL_BANNER_FG COL_BLACK
#define COL_BANNER_BG COL_DARKGRAY
#define COL_MENU_FG	COL_BLACK
#define COL_MENU_BG COL_DARKLIGHTBLUE
#define COL_MENU_BG_SEL COL_DARKGREEN
#define COL_FORM_TITLE COL_LIGHTGRAY
#define COL_FORM_FG COL_BLACK
#define COL_FORM_BG COL_DARKGREEN
#endif

/* Form flag */
enum {
	FORM_END=0,
	FORM_TITLE,
	FORM_TEXT
};

/* Form input type */
enum {
	SETTING_END=0,
	SETTING_BOOL,
	SETTING_INPUT,
	SETTING_LIST,
	SETTING_FUNC,
	SETTING_UPDOWN
};

enum {
	SETTING_DIR_UP=0,	/* select previous value */
	SETTING_DIR_DOWN,	/* select next value */
	SETTING_DIR_PRINT	/* print current value */
};

/*--- Types ---*/

typedef struct {
	unsigned char flag;
	char *text;
	unsigned char posx, posy;
} form_t;

typedef struct {
	unsigned char posx, posy;
	char *text;
	unsigned char input;
	unsigned char length;	/* length in chars, if input=SETTING_INPUT */
	void *param;	/* text items, if input=SETTING_LIST */
			/* void (*func)(void) if input=SETTING_FUNC */
} form_setting_t;

typedef union {
	const char *input;	/* Value entered */
	int num_list;	/* Selected list item */
} conf_setting_u;

typedef struct {
	void (*display)(void);	/* Function to display form */
	void (*update)(void);	/* Update form with time */

	void (*init)(void);	/* Function to init setting pointer */
	void (*confirm)(int numSetting, conf_setting_u confSetting);
} form_menu_t;

/* for SETTING_FUNC, param is this type */
typedef void (*setting_func_t)(void);

/* for SETTING_UPDOWN, param is this type */
typedef void (*setting_updown_t)(int dir);

/*--- Function prototypes ---*/

void vt_setCursorPos(int x,int y);
void vt_setBgColor(int col);
void vt_setFgColor(int col);

/* Read string max 16 chars */
const char *vt_readString(void);

void vt_clearForm(void);
void vt_displayForm(form_t *form);
void vt_displayForm_idx(form_t *form, int start, int count);

/* Setting functions */
void vt_initSettings(const form_setting_t *settings);
void vt_setting_prev(void);
void vt_setting_next(void);
void vt_setting_prevRow(void);
void vt_setting_nextRow(void);
int vt_setting_getType(void);
void vt_setting_show(void);
void vt_setting_newValue(const form_menu_t *form_menu, const char *str);
void vt_setting_execFunc(void);

/* List selection for setting */
void vt_setting_listInit(void);
void vt_setting_listPrint(void);
void vt_setting_listPrev(void);
void vt_setting_listNext(void);

/* Up/down calculation for setting */
void vt_setting_updownPrint(void);
void vt_setting_updown(int dir);

#endif /* FORM_VT_H */
