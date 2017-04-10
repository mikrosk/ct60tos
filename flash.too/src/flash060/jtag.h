#ifndef __jtag_H
#define __jtag_H
/* Flashing hard CT60, JTAG part
*  Didier Mequignon 2003-2011, e-mail: aniplay@wanadoo.fr
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

/* #define DEBUG */

#define ERROR_NONE          0
#define ERROR_TDOMISMATCH  -1
#define ERROR_MAXRETRIES   -2   /* TDO mismatch after max retries */
#define ERROR_ILLEGALSTATE -3
#define ERROR_ERASE        -4
#define ERROR_BLANK        -5
#define ERROR_PROGRAM      -6
#define ERROR_VERIFY       -7
#define ERROR_CODE         -8

/* TAP states */
#define TAPSTATE_RESET     0x00
#define TAPSTATE_RUNTEST   0x01 /* a.k.a. IDLE */
#define TAPSTATE_SELECTDR  0x02
#define TAPSTATE_CAPTUREDR 0x03
#define TAPSTATE_SHIFTDR   0x04
#define TAPSTATE_EXIT1DR   0x05
#define TAPSTATE_PAUSEDR   0x06
#define TAPSTATE_EXIT2DR   0x07
#define TAPSTATE_UPDATEDR  0x08
#define TAPSTATE_IRSTATES  0x09 /* All IR states begin here */
#define TAPSTATE_SELECTIR  0x09    
#define TAPSTATE_CAPTUREIR 0x0A
#define TAPSTATE_SHIFTIR   0x0B
#define TAPSTATE_EXIT1IR   0x0C
#define TAPSTATE_PAUSEIR   0x0D
#define TAPSTATE_EXIT2IR   0x0E
#define TAPSTATE_UPDATEIR  0x0F

/* XC9500XL instructions */
#define CMD_BIT_LENGTH 8
#define DATA_LENGTH 8  /* for XC95144XL */
#define MAX_SECTOR 108
#define SECTOR_LENGTH 216
#define JTAG_CMD_EXTEST   0x00 /* testing of off-chip circuitry and board level interconnections */
#define JTAG_CMD_SAMPLE   0x01 /* allows a snapshot of the normal operation of a component to be taken and examined */
#define JTAG_CMD_INTEST   0x02 /* allows testing of the on-chip system logic while the compoment is already on the board */
#define JTAG_CMD_FBLANK   0xE5 /* blank check */
#define JTAG_CMD_ISPEN    0xE8 /* activates device for In-System Programming */
#define JTAG_CMD_FPGM     0xEA /* programs bits at specified adresses */
#define JTAG_CMD_FPGMI    0xEB /* programs bits at an internally generated adress */
#define JTAG_CMD_FERASE   0xEC /* erases a sectors of programming cells */
#define JTAG_CMD_FBULK    0xED /* erase several sectors of programming cells */
#define JTAG_CMD_FVFY     0xEE /* verifies the programming at specified adresses */
#define JTAG_CMD_FVFYI    0xEF /* verifies the programming at an internally generated adress */
#define JTAG_CMD_ISPEX    0xF0 /* transfers memory cell contents to internal low power configuration latches */
#define JTAG_CMD_HIGHZ    0xFC /* permits automatic placement of all outputs to high impedance */
#define JTAG_CMD_USERCODE 0xFD /* alows a user-programmable identification code to be shifted out */
#define JTAG_CMD_IDCODE   0xFE /* allows blind interrogation of the components assembled on the board */
#define JTAG_CMD_BYPASS   0xFF /* configures the device to bypass the scan registers */

#define IDCODE_XC9572XL  0x09604093
#define IDCODE_XC95144XL 0x09608093
#define IDCODE_XC95288XL 0x09616093
#define IDMASK           0x0FFFFFFF

#define TCK 0
#define TMS 1
#define TDI 2

#define NO_DEVICE 0
#define ABE 1
#define SDR 2
#define CTPCI 3
#define ETHERNAT 4

typedef struct var_len_byte
{
	short len;               /* number of chars in this value */
	unsigned char val[24] ;  /* bytes of data */
} lenVal;

extern void setPort(short p,unsigned char val);
extern void pulseClock(unsigned short num);
extern unsigned char readTDOBit(void);
extern long test_cable(void);
int JtagShift(unsigned char *TapState,unsigned char StartState,long NumBits,
              lenVal *Tdi,lenVal *TdoCaptured,lenVal *TdoExpected,lenVal *TdoMask,
              unsigned char EndState,long RunTestTime,unsigned char MaxRepeat);
void JtagSelectTarget(int Device);
#endif