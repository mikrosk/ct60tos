/************************************************************************/
/*																		*/
/*	Helper functions for assembler programming and debugging			*/
/*	Copyright 2002 Dr. Thomas Redelberger								*/
/*	Use it under the terms of the GNU General Public License			*/
/*	(See file COPYING.TXT)												*/
/*																		*/
/* Software interface file												*/
/*																		*/
/* Tabsize 4, developed with Turbo-C ST 2.0								*/
/*																		*/
/************************************************************************/
/*
$Id: uti.h 1.1 2002/03/24 13:46:52 Thomas Exp Thomas $
 */

#define myPling()	prntStr("\7")


/**** entry points in UTI.S ****/

/* printing functions via the BIOS concole */

extern void cdecl prntStr(char* string);
extern void cdecl prntLong(uint32);
extern void cdecl prntWord(uint16);
extern void cdecl prntByte(uint8);
extern void cdecl prntSR(void);
extern void cdecl led_floppy(short state);
extern void cdecl code_led(short code);

/* asm util functions */

extern unsigned short cdecl swap_short(unsigned short val);
extern unsigned long cdecl swap_long(unsigned long val);
extern void cdecl udelay(short us);
extern short cdecl splx(short level);
extern long cdecl semaphore_take(long *sem);
#define semaphore_give(a) *a=0


