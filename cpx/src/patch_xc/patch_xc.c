/*
 *	patch_xc.c - patches extended control panel stuff to work with CT60:
 *		XCONTROL.ACC v1.31 (in one of 3 languages)
 *		GENERAL.CPX v1.30 (French) & v1.40 (English)
 *
 *
 *	Version:  1.0
 *	Date:     4 August 2003
 *	Author:   Roger Burrows, Ottawa, Ontario, Canada
 *	Compiler: Lattice C v5.60
 *	Changes:  Original version
 *
 *
 *	Syntax:
 *		patch_xc
 *
 */
#include <stdio.h>
#include <aes.h>
#include <dos.h>
#include <portab.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define VERSION			"Version 1.0"
#define COPYRIGHT		"Copyright ½ Roger Burrows, 2003"

/* standard GEM defines */
#define ERROR			-1
#define OK				0


/* program-specific defines */
#define INTRO_MSG		"[2][CT60 updater for: |XCONTROL v1.31 (FRA/UK/USA) |GENERAL.CPX v1.30 (French) |GENERAL.CPX v1.40 (English) ][Continue|Cancel]"
#define CONTINUE_MSG	"[2][Process more files? ][ Yes | No ]"

#define PRG_NAME		""
#define PRG_MASK		"*.*"

#define PATCH_OK		1	/* patch status ... */
#define ALREADY_PATCHED	2
#define VERIFY_FAILED	3
#define PATCH_SKIPPED	4

#define UPDATE_FILE		1	/* options for patch_file() */
#define RESTORE_FILE	2
#define UPDATE_DONE		1	/* return codes from patch_file() */
#define RESTORE_DONE	2

#define PATHLEN			128

typedef struct {			/* program file data, one per patchable version, terminated by 0 */
	long program_size;
	ULONG *patch_data;
	char *desc;
} PATCHINFO;

/*
 * global variables - general
 */
WORD gl_apid;				/* referenced in system library */
char version[] = VERSION;
char copyright[] = COPYRIGHT;

char name[FMSIZE] = "";
char init_path[PATHLEN] = "";
char path[PATHLEN] = "";

/*	the following is patch data.  each set of 3 longs is
 *		offset, old data, new data
 *	an offset of 1 means the data immediately follows the
 *	previous data; an offset of 0 terminates the patch.
 */
ULONG xc131_fra[] = {
	26190,	0x2f0a2019, 0x2f0a2019,		/* relocation routine */
	1,		0x4a806722, 0x67242450,
	1,		0x2450d5c0, 0x600cb03c,
	1,		0x6012b03c, 0x00016606,
	1,		0x00016606, 0x45ea00fe,
	1,		0x45ea00fe, 0x6006d5c0,
	1,		0x600a4241, 0x2210d392,
	1,		0x1200d4c1, 0x70001019,
	1,		0x2210d392, 0x66e83f3c,
	1,		0x10194a00, 0x0c6d4e4e,
	1,		0x66e4245f, 0x544f245f,
	40604,	0x312e3331, 0x312e3336,		/* version 1.36 */
	0 };

ULONG xc131_uk[] = {
	26218,	0x2f0a2019, 0x2f0a2019,		/* relocation routine */
	1,		0x4a806722, 0x67242450,
	1,		0x2450d5c0, 0x600cb03c,
	1,		0x6012b03c, 0x00016606,
	1,		0x00016606, 0x45ea00fe,
	1,		0x45ea00fe, 0x6006d5c0,
	1,		0x600a4241, 0x2210d392,
	1,		0x1200d4c1, 0x70001019,
	1,		0x2210d392, 0x66e83f3c,
	1,		0x10194a00, 0x0c6d4e4e,
	1,		0x66e4245f, 0x544f245f,
	40608,	0x312e3331, 0x312e3336,		/* version 1.36 */
	0 };

ULONG xc131_usa[] = {
	26214,	0x2f0a2019, 0x2f0a2019,		/* relocation routine */
	1,		0x4a806722, 0x67242450,
	1,		0x2450d5c0, 0x600cb03c,
	1,		0x6012b03c, 0x00016606,
	1,		0x00016606, 0x45ea00fe,
	1,		0x45ea00fe, 0x6006d5c0,
	1,		0x600a4241, 0x2210d392,
	1,		0x1200d4c1, 0x70001019,
	1,		0x2210d392, 0x66e83f3c,
	1,		0x10194a00, 0x0c6d4e4e,
	1,		0x66e4245f, 0x544f245f,
	40604,	0x312e3331, 0x312e3336,		/* version 1.36 */
	0 };

ULONG general_fra[] = {
    4,		0x4647454e, 0x46474536,		/* cpx id 'FGE6' */
	134,	0x6c000000,	0x6c203630,		/* add '60' to title */
	7336,	0x701eb097,	0x703cb097,		/* check for 060 cpu */
	7408,	0x00003111,	0xa0808000,		/* CACR value to check */
	8532,	0x203c0000,	0x2f3cc60c,		/* cache enable */
	1,		0x39194e7b,	0x00014e4e,
	1,		0x00024e75,	0x584f4e75,
	8544,	0x203c0000,	0x2f3cc60c,		/* cache disable */
	1,		0x08084e7b,	0x00004e4e,
	1,		0x00024e75,	0x584f4e75,
	0 };

ULONG general_eng[] = {
    4,		0x47454e00, 0x47454e36,		/* cpx id 'GEN6' */
	134,	0x70000000,	0x70203630,		/* add '60' to title */
	7338,	0x701eb097,	0x703cb097,		/* check for 060 cpu */
	7410,	0x00003111,	0xa0808000,		/* CACR value to check */
	8532,	0x203c0000,	0x2f3cc60c,		/* cache enable */
	1,		0x39194e7b,	0x00014e4e,
	1,		0x00024e75,	0x584f4e75,
	8544,	0x203c0000,	0x2f3cc60c,		/* cache disable */
	1,		0x08084e7b,	0x00004e4e,
	1,		0x00024e75,	0x584f4e75,
	0 };

PATCHINFO patchinfo[] = { { 44990, xc131_fra, "French" },	/* France */
						  { 44685, xc131_uk, "UK" },		/* UK */
						  { 44681, xc131_usa, "USA" },		/* USA */
						  { 14133, general_fra, "French" },	/* French-language */
						  { 14111, general_eng, "English" },/* English-language */
						  { 0, NULL } };

/*
 * private function prototypes
 */
int  init_gem(void);
int  term_gem(void);
WORD get_file(char *prompt,char *buffer,char *wild,char *initial);
void get_cwd(char *buffer);
void get_path_name(char *dname);
void main(int argc,char **argv);
void terminate(char *msg);
void status(char *msg);
int err(char *msg,char *filename,int changes);
int check_file(FILE *fp,PATCHINFO *pi);
int patch_file(char *filename,FILE *fp,PATCHINFO *pi,int option);

/*
 * main program
 */
void main(int argc,char **argv)
{
PATCHINFO *pi;
FILE *fp;
char msg[200], *p;
int rc;

	/*
	 * tell GEM hello.
	 * we're glad to see him too.
	 */
	if (init_gem() == ERROR)
		exit(1);

	graf_mouse(ARROW,0);

	if (form_alert(1,INTRO_MSG) != 1)
		terminate("Program cancelled");

	do {
		strcpy(path,init_path);
		strcpy(name,PRG_NAME);
		if (get_file("Select program file",path,PRG_MASK,name) <= 0)
			continue;

		strcpy(init_path,path);		/* re-initialise */
		p = strrchr(init_path,'\\');
		if (p)
			*p = '\0';

		if ((fp=fopen(path,"rb+")) == NULL) {
			err("can't open file",path,0);
			continue;
		}

		for (pi = patchinfo; pi->program_size; pi++)
			if (filelength(fileno(fp)) == pi->program_size)
				break;

		rc = PATCH_SKIPPED;
		switch(check_file(fp,pi)) {
		case PATCH_OK:
			sprintf(msg,"[2][You have selected the |original %s version. ][Update|Skip]",pi->desc);
			if (form_alert(1,msg) == 1)
				rc = patch_file(path,fp,pi,UPDATE_FILE);
			break;
		case ALREADY_PATCHED:
			sprintf(msg,"[2][You have selected the |updated %s version. ][Restore|Skip]",pi->desc);
			if (form_alert(2,msg) == 1)
				rc = patch_file(path,fp,pi,RESTORE_FILE);
			break;
		case VERIFY_FAILED:
			form_alert(1,"[1][Selected file does not |match update data. ][Skip]");
			break;
		default:
			form_alert(1,"[1][Error reading program file. ][Skip]");
			break;
		}

		if (rc == PATCH_SKIPPED)
			continue;

		switch(rc) {
		case UPDATE_DONE:
			sprintf(msg,"[1][Program has been updated |for CT60. ][Continue]");
			break;
		case RESTORE_DONE:
			sprintf(msg,"[1][Original version has been |restored. ][Continue]");
			break;
		case 0:
			sprintf(msg,"[1][Program modification failed. |No changes have been made. ][Continue]");
			break;
		default:
			sprintf(msg,"[1][Program changes incomplete. |Restore from a backup! ][Continue]");
			break;
		}
		form_alert(1,msg);
	} while (form_alert(2,CONTINUE_MSG) == 1);

	terminate("");
}

/*
 ********** ye olde GEM interface routines
 */
int init_gem()
{
	appl_init();						/* register application */
	if (gl_apid < 0) {
		form_alert(1,"[3][Fatal error !|Cannot initialise application][ Quit ]");
		return ERROR;
	}

	return OK;
}


int term_gem()
{
	if (appl_exit() == 0) {
		form_alert(1,"[3][Fatal error !|Cannot exit properly][ Quit ]");
		return ERROR;
	}
	return OK;
}

/*
 ********** file-handling routines
 */

/*
 *	get the current working directory into buffer
 *
 *	Input:
 *		buffer -	large enough to hold a valid path name
 *	Output:
 *		(void)		buffer contains the cwd
 *
 */
void get_cwd(char *buffer)
{
register int drive;

	drive = Dgetdrv();					/* get default drive */
	buffer[0] = drive + 'A';			/*  & move to buffer */
	buffer[1] = ':';
	buffer[2] = '\0';
	Dgetpath(&buffer[2],0);				/* get current directory   */
	strcat(buffer,"\\");				/*  & terminate it with \. */
}

/*
 *	get a file name using fsel_exinput() dialog
 *
 *	Input:
 *		buffer - buffer large enough to hold the longest valid pathname.
 *				 If buffer[0] == '\0' on entry, the current working
 *				 directory is used.  If buffer[0] != '\0' it is assumed
 *				 to contain the directory path to be initially shown
 *				 in the dialog.
 *		wild   - the wild card spec to use to match file names.
 *		initial- the initial file selection if any.  It must be
 *				 large enough to hold a valid file name (13 characters).
 *	Output:
 *		-1	-	if an error occurred in the dialog
 *		 0	-	if the user hit CANCEL
 *		>0	-	if no error and user hit OK.  Buffer will contain the
 *				complete path name of the file selected.  Initial will
 *				contain only the file name selected.
 */
WORD get_file(char *prompt,char *buffer,char *wild,char *initial)
{
WORD button;
int l;
		
	if (*buffer == '\0')		/* get current pathname into buffer */
		get_cwd(buffer);
	else {						/* path specified - check it ends in '\' */
		l = strlen(buffer);
		if (buffer[l-1] != '\\') {	/* doesn't, so put it in */
			buffer[l]   = '\\';
			buffer[l+1] = '\0';
		}
	}
	strcat(buffer,wild);		/* add on wildcard spec */
		
	if (fsel_exinput(buffer,initial,&button,prompt) == FALSE)
		return ERROR;			/* error occurred */

	if (button) {				/* user clicked on OK */
		get_path_name(buffer);
		strcat(buffer,initial);
	}

	return button;
}

/*
 *	get pointer to the name at the end of a file spec
 *
 *	Input:
 *		name - the full path name
 *
 *	Output:
 *		pointer to the last component of the full path name
 */
char *get_name(char *name)
{
register char c;
register int i;

	i = strlen(name);
	while ((i > 0) && (((c = name[i-1]) != '\\') && (c != ':')))
		i--;
	return name+i;
}

/*
 *	remove the name at the end of a file spec
 *
 *	Input:
 *		dname - the directory name, with possibly wild card characters at
 *				the end
 *	Output:
 *		(void)	dname contains the full pathname, excluding the filename
 */
void get_path_name(char *dname)
{
register char *p;

	p = get_name(dname);		/* get ptr to last component of name */

	if (*(p-1) == ':')			/* if back at drive spec, */
		*p++ = '\\';			/*   insert the \.        */

	*p = '\0';					/* terminate dir name */
}

/*
 *	replace the extension at the end of a file spec
 *
 *	Input:
 *		path -	the full pathname, including filename and extension
 *		ext -	the new extension
 *	Output:
 *		(void)	path contains the full pathname, with new extension
 */
void make_path_name(char *path,char *ext)
{
register char *p;

	p = get_name(path);			/* get ptr to last component of name */

	while (*p && (*p != '.'))	/* look for start of extension */
		p++;
	strcpy(p,".");				/* tag on the new extension */
	strcat(p,ext);
}


/*
 ********** other routines
 */

/*
 * check patch file
 *	returns:	PATCH_OK		patch verifies olddata OK
 *				ALREADY_PATCHED	file is already patched
 *				VERIFY_FAILED	patch doesn't fit
 *				ERROR			error accessing file
 */
int check_file(FILE *fp,PATCHINFO *pi)
{
ULONG *pd, olddata;
int old = 0, new = 0, tot = 0;
int match;

	if (!pi->patch_data)
		return VERIFY_FAILED;

	for (pd = pi->patch_data; *pd; tot++, pd += 3) {	/* terminate on word of zeros */
		if (*pd != 1)
			if (fseek(fp,*pd,SEEK_SET) < 0)
				return ERROR;
		olddata = fgetl(fp);
		if (feof(fp))
			return ERROR;
		match = 0;
		if (olddata == *(pd+1))
			old++, match++;
		if (olddata == *(pd+2))
			new++, match++;
		if (!match)				//debug only
			olddata = 999;		//debug only
	}

	if (old == tot)
		return PATCH_OK;

	if (new == tot)
		return ALREADY_PATCHED;

	return VERIFY_FAILED;
}

/*
 * do patch
 *	returns:	PATCH_DONE		patch completed OK
 *				RESTORE_DONE	restore completed OK
 *				0				failed, but no changes made
 *				-N				failed, N changes made
 */
int patch_file(char *filename,FILE *fp,PATCHINFO *pi,int option)
{
int changes = 0;
ULONG *pd;

	for (pd = pi->patch_data; *pd; changes++, pd += 3) {	/* terminate on word of zeros */
		if (*pd != 1)
			if (fseek(fp,*pd,SEEK_SET) < 0)
				return err("can't seek in file",filename,changes);
		if (option == RESTORE_FILE)	/* if restoring */
			fputl(*(pd+1),fp);		/* use col 2 */
		else fputl(*(pd+2),fp);		/* else col 3 */
		if (feof(fp))
			return err("can't write file",filename,changes);
	}

	if (fclose(fp))
		return err("can't close file",filename,changes);

	if (option == RESTORE_FILE)
		return RESTORE_DONE;

	return UPDATE_DONE;
}

/*
 * terminate with an optional message
 */
void terminate(char *msg)
{
char s[200];

	if (*msg) {
		sprintf(s,"[1][|%s][ Done ]",msg);
		form_alert(1,s);
	}

	/* tell GEM bye, bye */
	if (term_gem() == ERROR)
		exit(1);

	exit(0);
}

void status(char *msg)
{
char s[200];

	sprintf(s,"[1][%s ][Continue]",msg);
	form_alert(1,s);
}

int err(char *msg,char *filename,int changes)
{
char s[200];

	sprintf(s,"[1][Error:    | %s | %s ][Continue]",msg,filename);
	form_alert(1,s);
	return -changes;
}
