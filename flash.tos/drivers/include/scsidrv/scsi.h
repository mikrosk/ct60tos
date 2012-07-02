#ifndef __SCSI_H
#define __SCSI_H

#include "scsidrv/scsidefs.h"

#define DIRECTACCESSDEV  0 
#define SEQACCESSDEV     1
#define PRINTERDEV       2
#define PROCESSORDEV     3
#define WORMDEV          4
#define ROMDEV           5
#define SCANNERDEF       6
#define OPTICALMEMDEV    7
#define MEDIUMCHNGDEV    8
#define COMMDEV          9
#define GRAPHDEV1       10
#define GRAPHDEV2       11
#define UNKNOWNDEV      31

/* SCSI opcodes */
/* Commands (CDB's here are 6-bytes) */
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
/* Group 2 Commands (CDB's here are 10-bytes) */
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
#define READ_SUBCHANNEL         0x42
#define READ_TOC                0x43
#define READ_HEADER             0x44
#define PLAY_AUDIO_10           0x45
#define GET_CONFIGURATION       0x46
#define PLAY_AUDIO_MSF          0x47
#define PLAY_AUDIO_TI           0x48
#define PLAY_TRACK_REL_10       0x49
#define GET_EVENT_STATUS        0x4a
#define PAUSE_RESUME            0x4b
#define LOG_SELECT              0x4c
#define LOG_SENSE               0x4d
#define READ_DISK_INFO          0x51
#define READ_TRACK_INFO         0x52
#define MODE_SELECT_10          0x55
#define MODE_SENSE_10           0x5a
/* Group 5 Commands (CDB's here are 12-bytes) */
#define PLAY_AUDIO_12           0xa5
#define LOAD_UNLOAD             0xa6
#define READ_12	                0xa8
#define TRACK_REL_12            0xa9
#define WRITE_12                0xaa
#define READ_DVD_STRUCTURE      0xad
#define WRITE_VERIFY_12         0xae
#define SEARCH_HIGH_12          0xb0
#define SEARCH_EQUAL_12         0xb1
#define SEARCH_LOW_12           0xb2
#define SEND_VOLUME_TAG         0xb6
#define READ_MSF                0xb9
#define SET_SPEED               0xbb
#define READ_CD                 0xbe

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
} tInqData;

typedef struct
{
	char CDP0DRes2;
	char InactTMul;      /* unteres Nibble */
	unsigned short SperMSF;
	unsigned short FperMSF;
} tCDPage0D;

typedef struct
{
	unsigned char ImmedFlags;
	char CD0ERes3;
	char CD0ERes4;
	unsigned char LBAFlags;
	unsigned short BlocksPerSecond;
	unsigned char Port0Channel;
	unsigned char Port0Volume;
	unsigned char Port1Channel;
	unsigned char Port1Volume;
	unsigned char Port2Channel;
	unsigned char Port2Volume;
	unsigned char Port3Channel;
	unsigned char Port3Volume;
} tCDPage0E;

typedef struct
{
	char ModeLength;
	char MediumType;
	unsigned char DeviceSpecs;
	char BlockDescLen;
} tParmHead;

typedef struct
{
	unsigned long Blocks;                  /* Byte HH = DensityCode */
	unsigned long BlockLen;                /* Byte HH = Reserved    */
} tBlockDesc;

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

typedef union
{
	struct
	{
		char Resrvd;
		char M;
		char S;
		char F;
	} s;
	unsigned long longval;
} tMSF;

#define MAXTOC 100
typedef struct
{
	char Res0;
	unsigned char ADRControl;
  unsigned char TrackNo;
	char Res3;
  tMSF AbsAddress;
} tTOCEntry;

typedef struct
{
	unsigned short TOCLen;
	unsigned char FirstTrack;
	unsigned char LastTrack;
} tTOCHead;

typedef struct
{
	tTOCHead Head;
	tTOCEntry Entry[MAXTOC];
} tTOC;

typedef struct
{
	unsigned char Command;
	char LunAdr;
	unsigned short Adr;
	unsigned char Len;
	char Flags;
} tCmd6;

typedef struct
{
	unsigned char Command;
	char Lun;
	unsigned long Adr;
	char Reserved;
	unsigned char LenHigh;
	unsigned char LenLow;
	char Flags;
} tCmd10;

typedef struct
{
	unsigned char Command;
	char Lun;
	unsigned long Adr;
	unsigned long Len;
	char Reserved;
	char Flags;
} tCmd12;

void Wait(unsigned long Ticks);
void SetBlockSize(unsigned long NewLen);
unsigned long GetBlockSize();
void SetScsiUnit(tHandle handle, short Lun, unsigned long MaxLen);
void SetCmd6(tCmd6 *Cmd, unsigned short Opcode, unsigned long BlockAdr, unsigned short TransferLen);
void SetCmd10(tCmd10 *Cmd, unsigned short Opcode, unsigned long BlockAdr, unsigned short TransferLen);
void SetCmd12(tCmd12 *Cmd, unsigned short Opcode, unsigned long BlockAdr, unsigned long TransferLen);
tpSCSICmd SetCmd(char *Cmd, short CmdLen, void *Buffer, unsigned long Len, unsigned long TimeOut);
long TestUnitReady(void);
long Inquiry(void  *data, int Vital, unsigned short VitalPage, short length);
	#define MODESEL_SMP 0x01            /* Save Mode Parameters */
	#define MODESEL_PF  0x10            /* Page Format          */
long ModeSelect(unsigned short SelectFlags, void *Buffer, unsigned short ParmLen);
long ModeSelect6(unsigned short SelectFlags, void *Buffer, unsigned short ParmLen);
long ModeSelect10(unsigned short SelectFlags, void *Buffer, unsigned short ParmLen);
	#define MODESENSE_CURVAL 0          /* current values     */
	#define MODESENSE_CHANGVAL 1        /* changeable values  */
	#define MODESENSE_DEFVAL 2          /* default values     */
	#define MODESENSE_SAVEDVAL 3        /* save values        */
long ModeSense(unsigned short PageCode, unsigned short SubPageCode, unsigned short PageControl, void *Buffer, unsigned short ParmLen);
long ModeSense6(unsigned short PageCode, unsigned short SubPageCode, unsigned short PageControl, void *Buffer, unsigned short ParmLen);
long ModeSense10(unsigned short PageCode, unsigned short SubPageCode, unsigned short PageControl, void *Buffer, unsigned short ParmLen);
long PreventMediaRemoval(int Prevent);
long Read6(unsigned long BlockAdr, unsigned short TransferLen, void *buffer);
long Read10(unsigned long BlockAdr, unsigned short TransferLen, void *buffer);
long Write6(unsigned long BlockAdr, unsigned short TransferLen, void *buffer);
long Write10(unsigned long BlockAdr, unsigned short TransferLen, void *buffer);
long Read(unsigned long BlockAdr, unsigned short TransferLen, void *buffer);
long Write(unsigned long BlockAdr, unsigned short TransferLen, void *buffer);
long StartStop(int LoadEject, int StartFlag);
long ReadCapacity(int PMI, unsigned long *BlockAdr, unsigned long *BlockLen);
long GetConfiguration(int RT, unsigned short StartFeature, void *Buffer, unsigned short Len);
long ReadTOC(int MSF, int Format, unsigned short StartTrack, void *Buffer, unsigned short Len);
long ReadDVDStucture(unsigned long Address, unsigned short LayerNumber, unsigned short Format, int AGID, void *Buffer, unsigned short Len);
long ReadDiskInfo(void *Buffer, unsigned short Len);
long ReadTrackInfo(int AddressNumberType, unsigned long BlockAdr, void *Buffer, unsigned short Len);

#endif

