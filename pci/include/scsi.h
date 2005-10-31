/*{{{}}}*/
/*********************************************************************
 *
 * SCSI-Aufrufe fÅr alle GerÑte
 *
 * $Source: u:\k\usr\src\scsi\cbhd\rcs\scsi.h,v $
 *
 * $Revision: 1.2 $
 *
 * $Author: Steffen_Engel $
 *
 * $Date: 1996/02/14 11:33:52 $
 *
 * $State: Exp $
 *
 **********************************************************************
 * History:
 *
 * $Log: scsi.h,v $
 * Revision 1.2  1996/02/14  11:33:52  Steffen_Engel
 * keine globalen Kommandostrukturen mehr
 *
 * Revision 1.1  1995/11/28  19:14:14  S_Engel
 * Initial revision
 *
 *
 *
 *********************************************************************/

#ifndef __SCSI_H
#define __SCSI_H

#include "scsidefs.h"           /* Typen fÅr SCSI-Lib */

/*****************************************************************************
 * Konstanten
 *****************************************************************************/

#define DIRECTACCESSDEV  0       /* GerÑt mit Direktzugriff (Festplatte) */
#define SEQACCESSDEV     1       /*   "    "  seq. Zugriff  (Streamer)   */
#define PRINTERDEV       2       /* Drucker                              */
#define PROCESSORDEV     3       /* Hostadapter                          */
#define WORMDEV          4       /* WORM-Laufwerk                        */
#define ROMDEV           5       /* nur-lese Laufwerk (CD-ROM)           */
#define SCANNERDEF       6       /* Scanner                              */
#define OPTICALMEMDEV    7       /* optical memory device                */
#define MEDIUMCHNGDEV    8       /* medium changer device (zB JukeBox)   */
#define COMMDEV          9       /* Communicationdevice                  */
#define GRAPHDEV1       10
#define GRAPHDEV2       11
#define UNKNOWNDEV      31
/*
        SCSI opcodes
*/
#define TEST_UNIT_READY         0x00
#define REZERO_UNIT             0x01
#define REQUEST_SENSE           0x03
#define FORMAT_UNIT             0x04
#define READ_BLOCK_LIMITS       0x05
#define REASSIGN_BLOCKS         0x07
#define READ_6                  0x08
#define WRITE_6                 0x0a
#define SEEK_6                  0x0b
#define READ_REVERSE            0x0f
#define WRITE_FILEMARKS         0x10
#define SPACE                   0x11
#define INQUIRY                 0x12
#define RECOVER_BUFFERED_DATA   0x14
#define MODE_SELECT             0x15
#define RESERVE                 0x16
#define RELEASE                 0x17
#define COPY                    0x18
#define ERASE                   0x19
#define MODE_SENSE              0x1a
#define START_STOP              0x1b
#define RECEIVE_DIAGNOSTIC      0x1c
#define SEND_DIAGNOSTIC         0x1d
#define ALLOW_MEDIUM_REMOVAL    0x1e

#define SET_WINDOW              0x24
#define READ_CAPACITY           0x25
#define READ_10                 0x28
#define WRITE_10                0x2a
#define SEEK_10                 0x2b
#define WRITE_VERIFY            0x2e
#define VERIFY                  0x2f
#define SEARCH_HIGH             0x30
#define SEARCH_EQUAL            0x31
#define SEARCH_LOW              0x32
#define SET_LIMITS              0x33
#define PRE_FETCH               0x34
#define READ_POSITION           0x34
#define SYNCHRONIZE_CACHE       0x35
#define LOCK_UNLOCK_CACHE       0x36
#define READ_DEFECT_DATA        0x37
#define MEDIUM_SCAN             0x38
#define COMPARE                 0x39
#define COPY_VERIFY             0x3a
#define WRITE_BUFFER            0x3b
#define READ_BUFFER             0x3c
#define UPDATE_BLOCK            0x3d
#define READ_LONG               0x3e
#define WRITE_LONG              0x3f
#define CHANGE_DEFINITION       0x40
#define WRITE_SAME              0x41
#define LOG_SELECT              0x4c
#define LOG_SENSE               0x4d
#define MODE_SELECT_10          0x55
#define MODE_SENSE_10           0x5a
#define WRITE_12                0xaa
#define WRITE_VERIFY_12         0xae
#define SEARCH_HIGH_12          0xb0
#define SEARCH_EQUAL_12         0xb1
#define SEARCH_LOW_12           0xb2
#define SEND_VOLUME_TAG         0xb6

/*****************************************************************************
 * Typen
 *****************************************************************************/

/* Inquiry-Struktur */
typedef struct
{
	unsigned char Device;
	unsigned char Qualifier;
	unsigned char Version;
	unsigned char Format;
	unsigned char AddLen;
	unsigned char Res1;
	unsigned short Res2;
	char Vendor[8];
	char Product[16];
	char Revision[4];
}tInqData;

/* Modesense/select-Typen */

/* Pages fÅr CD-ROMS */
/* {{{ */
typedef struct
{
	char CDP0DRes2;
	char InactTMul;      /* unteres Nibble */
	unsigned short SperMSF;
	unsigned short FperMSF;
}tCDPage0D;

typedef struct
{
	unsigned char ImmedFlags;
	char CD0ERes3;
	char CD0ERes4;
	unsigned char LBAFlags;
	unsigned short BlocksPerSecond;
	/* Genau:
	 *   LBAFlags MOD 10H = 0 -> BlocksPerSecond
	 *   LBAFlags MOD 10H = 8 -> 256 * BlocksPerSecond
	 */
	unsigned char Port0Channel;
	unsigned char Port0Volume;
	unsigned char Port1Channel;
	unsigned char Port1Volume;
	unsigned char Port2Channel;
	unsigned char Port2Volume;
	unsigned char Port3Channel;
	unsigned char Port3Volume;
}tCDPage0E;
/* }}} */

/* allgmeine Struktur fÅr ModeSense/Select */
typedef struct
{
	char ModeLength;
	char MediumType;
	unsigned char DeviceSpecs;  /* GerÑteabhÑngig */
	char BlockDescLen;
} tParmHead;

typedef struct
{
	unsigned long Blocks;                  /* Byte HH = DensityCode */
	unsigned long BlockLen;                /* Byte HH = Reserved    */
} tBlockDesc;

/* die Varianten fÅr die Pages */
typedef union
{
	tCDPage0D CDP0D;
	tCDPage0E CDP0E;
} tPage;

typedef struct
{
	tParmHead ParmHead;
	tBlockDesc BlockDesc;
	tPage Page;
} tModePage;


/*****************************************************************************
 * Variablen
 *****************************************************************************/
long ScsiFlags;   /* Wert fÅr tScsiCmd.Flags */

/*****************************************************************************
 * Funktionen
 *****************************************************************************/
LONG TestUnitReady(void);
LONG Inquiry(void  *data, int Vital, unsigned short VitalPage, short length);
  /* Inquiry von einem GerÑt abholen */
#define MODESEL_SMP 0x01            /* Save Mode Parameters */
#define MODESEL_PF  0x10            /* Page Format          */
long ModeSelect(unsigned short SelectFlags, void *Buffer, unsigned short ParmLen);
#define MODESENSE_CURVAL 0          /* current values     */
#define MODESENSE_CHANGVAL 1        /* changeable values  */
#define MODESENSE_DEFVAL 2          /* default values     */
#define MODESENSE_SAVEDVAL 3        /* save values        */
long ModeSense(unsigned short PageCode, unsigned short PageControl, void *Buffer, unsigned short ParmLen);
long PreventMediaRemoval(int Prevent);
int init_scsi (void);
  /* Initialisierung des Moduls */
/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- Allgemeine Tools                                                      -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/
void SuperOn(void);
void SuperOff(void);
void Wait(unsigned long Ticks);
void SetBlockSize(unsigned long NewLen);
  /*
   * SetBlockLen legt die BlocklÑnge fÅr das SCSI-GerÑt fest
   * (normalerweise 512 Bytes).
   */
unsigned long GetBlockSize();
  /*
   * GetBlockLen gibt die aktuell eingestellte BlocklÑnge zurÅck.
   */
void SetScsiUnit(tHandle handle, short Lun, unsigned long MaxLen);
  /*
   * SetScsiUnit legt das GerÑt fest an das die nachfolgenden Kommandos
   * gesendet werden und wie lang die Transfers maximal sein dÅrfen.
   */

/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- Zugriff fÅr Submodule (ScsiStreamer, ScsiCD, ScsiDisk...)             -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/

typedef struct
{
	unsigned char Command;
	char LunAdr;
	unsigned short Adr;
	unsigned char Len;
	char Flags;
}tCmd6;

typedef struct
{
	unsigned char Command;
	char Lun;
	unsigned long Adr;
	char Reserved;
	unsigned char LenHigh;
	unsigned char LenLow;
	char Flags;
}tCmd10;

typedef struct
{
	unsigned char Command;
	char Lun;
	unsigned long Adr;
	unsigned long Len;
	char Reserved;
	char Flags;
}tCmd12;

unsigned long BlockLen;
unsigned long MaxDmaLen;
unsigned short LogicalUnit;

void SetCmd6(tCmd6 *Cmd, unsigned short Opcode, unsigned long BlockAdr, unsigned short TransferLen);
void SetCmd10(tCmd10 *Cmd, unsigned short Opcode, unsigned long BlockAdr, unsigned short TransferLen);     
void SetCmd12(tCmd12 *Cmd, unsigned short Opcode, unsigned long BlockAdr, unsigned long TransferLen);
tpSCSICmd SetCmd(char *Cmd, short CmdLen, void *Buffer, unsigned long Len, unsigned long TimeOut);

#endif

