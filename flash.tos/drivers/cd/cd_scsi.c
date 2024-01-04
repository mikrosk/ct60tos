#include <mint/sysvars.h>
#include <string.h>
#include "scsidrv/scsi.h"

static tHandle Handle;
static tSCSICmd SCmd;
static long ScsiFlags;

/* global */
unsigned long BlockLen;
unsigned long MaxDmaLen;
unsigned short LogicalUnit;
tReqData ReqBuff;      /* Request Sense Buffer for all commands */
tpScsiCall scsicall;

void Wait(unsigned long Ticks)
{
	long endtime = *(volatile unsigned long *)_hz_200 + Ticks;
	while(*(volatile unsigned long *)_hz_200 < endtime);
}

void SetBlockSize(unsigned long NewLen)
{
	BlockLen = NewLen;
}

unsigned long GetBlockSize()
{
	return(BlockLen);
}

void SetScsiUnit(tHandle handle, short Lun, unsigned long MaxLen)
{
	Handle = handle;
	LogicalUnit = Lun*32;
	MaxDmaLen = MaxLen;
}

void SetCmd6(tCmd6 *Cmd, unsigned short Opcode, unsigned long BlockAdr, unsigned short TransferLen)
{
	Cmd->Command = (unsigned char)Opcode;
	Cmd->LunAdr  = (unsigned char)LogicalUnit + (unsigned char)((BlockAdr >> 16) & 0x1F);
	Cmd->Adr     = w2mot((unsigned short)(BlockAdr & 0xFFFF));
	Cmd->Len     = (unsigned char)TransferLen;
	Cmd->Flags   = 0;
}

void SetCmd10(tCmd10 *Cmd, unsigned short Opcode, unsigned long BlockAdr, unsigned short TransferLen)
{
	Cmd->Command   = (unsigned char)Opcode;
	Cmd->Lun       = (unsigned char)LogicalUnit;
	Cmd->Adr       = l2mot(BlockAdr);
	Cmd->Reserved  = 0;
	Cmd->LenHigh   = (unsigned char)(TransferLen >> 8);
	Cmd->LenLow    = (unsigned char)(TransferLen & 0xFF);
	Cmd->Flags     = 0;
}

void SetCmd12(tCmd12 *Cmd, unsigned short Opcode, unsigned long BlockAdr, unsigned long TransferLen)
{
	Cmd->Command = (unsigned char)Opcode;
	Cmd->Lun     = (unsigned char)LogicalUnit;
	Cmd->Adr     = l2mot(BlockAdr);
	Cmd->Len     = l2mot(TransferLen);
	Cmd->Reserved= 0;
	Cmd->Flags   = 0;
}

tpSCSICmd SetCmd(char *Cmd, short CmdLen, void *Buffer, unsigned long Len, unsigned long TimeOut)
{
	SCmd.Handle = Handle;
	SCmd.Cmd    = Cmd;
	SCmd.CmdLen = CmdLen;
	SCmd.Buffer = Buffer;
	SCmd.TransferLen = Len;
	SCmd.SenseBuffer = ReqBuff;
	SCmd.Timeout  = TimeOut;
	SCmd.Flags    = (char)ScsiFlags;
	return(&SCmd);
}

long TestUnitReady(void)
{
	tCmd6 Cmd;
	SetCmd6(&Cmd, TEST_UNIT_READY, 0, 0);
	return(In(SetCmd((char *)&Cmd, 6, NULL, 0, DefTimeout)));
}

long Inquiry(void  *data, int Vital, unsigned short VitalPage, short length)
{
	tCmd6 Cmd;
	SetCmd6(&Cmd, INQUIRY, 0, length);
  if(Vital)
	{
		Cmd.LunAdr |= 1;
		Cmd.Adr = VitalPage << 8;
	}
	return(In(SetCmd((char *)&Cmd, 6, data, length, 1000)));
}

long ModeSelect6(unsigned short SelectFlags, void *Buffer, unsigned short ParmLen)
{
	tCmd6 Cmd;
	SetCmd6(&Cmd, MODE_SELECT, 0, ParmLen);
	Cmd.LunAdr |= (SelectFlags & 0x1F);
	return(Out(SetCmd((char *)&Cmd, 6, Buffer, ParmLen, DefTimeout)));
}

long ModeSelect10(unsigned short SelectFlags, void *Buffer, unsigned short ParmLen)
{
	tCmd10 Cmd;
	SetCmd10(&Cmd, MODE_SELECT_10, 0, ParmLen);
	Cmd.Lun = (char)SelectFlags;
	return(Out(SetCmd((char *)&Cmd, 10, Buffer, ParmLen, DefTimeout)));
}

long ModeSelect(unsigned short SelectFlags, void *Buffer, unsigned short ParmLen)
{
	long rc = ModeSelect6(SelectFlags, Buffer, ParmLen);
	if(rc)
		rc = ModeSelect10(SelectFlags, Buffer, ParmLen);
	return(rc);
}

long ModeSense6(unsigned short PageCode, unsigned short SubPageCode, unsigned short PageControl, void *Buffer, unsigned short ParmLen)
{
	tCmd6 Cmd;
	SetCmd6(&Cmd, MODE_SENSE, 0, ParmLen);
	Cmd.Adr = ((((PageControl << 6) + PageCode) & 0xFF) << 8) + (SubPageCode & 0xFF);
	return(In(SetCmd((char *)&Cmd, 6, Buffer, ParmLen, DefTimeout)));
}

long ModeSense10(unsigned short PageCode, unsigned short SubPageCode, unsigned short PageControl, void *Buffer, unsigned short ParmLen)
{
	tCmd10 Cmd;
	SetCmd10(&Cmd, MODE_SENSE_10, 0, ParmLen);
	Cmd.Adr = ((((PageControl << 6) + PageCode) & 0xFF) << 24) + ((SubPageCode & 0xFF) << 16);
	return(In(SetCmd((char *)&Cmd, 10, Buffer, ParmLen, DefTimeout)));
}

long ModeSense(unsigned short PageCode, unsigned short SubPageCode, unsigned short PageControl, void *Buffer, unsigned short ParmLen)
{
	long rc = ModeSense6(PageCode, SubPageCode, PageControl, Buffer, ParmLen);
	if(rc)
		rc = ModeSense10(PageCode, SubPageCode, PageControl, Buffer, ParmLen);
	return(rc);
}

long PreventMediaRemoval(int Prevent)
{
	tCmd6 Cmd;
	SetCmd6(&Cmd, ALLOW_MEDIUM_REMOVAL, 0, Prevent ? 1 : 0);
  return(In(SetCmd((char *)&Cmd, 6, NULL, 0, DefTimeout)));
}

long Read6(unsigned long BlockAdr, unsigned short TransferLen, void *buffer)
{
	long ret;
	tCmd6 Cmd;
	while(TransferLen > MaxDmaLen / BlockLen)
	{
		SetCmd6(&Cmd, READ_6, BlockAdr, (unsigned short)(MaxDmaLen / BlockLen));
		if((ret = In(SetCmd((char *)&Cmd, 6, buffer, MaxDmaLen / BlockLen * BlockLen, DefTimeout))) != 0)
			return(ret);
		BlockAdr += MaxDmaLen / BlockLen;
		TransferLen -= (unsigned short)(MaxDmaLen / BlockLen);
		buffer = (void *)((long)buffer + MaxDmaLen / BlockLen * BlockLen);
	}
	SetCmd6(&Cmd, READ_6, BlockAdr, TransferLen);
	return(In(SetCmd((char *)&Cmd, 6, buffer, BlockLen * (unsigned long)TransferLen, DefTimeout)));
}

long Read10(unsigned long BlockAdr, unsigned short TransferLen, void *buffer)
{
	long ret;
	tCmd10 Cmd;
	while(TransferLen > MaxDmaLen / BlockLen)
	{
		SetCmd10(&Cmd, READ_10, BlockAdr, (unsigned short)(MaxDmaLen / BlockLen));
		if((ret = In(SetCmd((char *)&Cmd, 10, buffer, MaxDmaLen / BlockLen * BlockLen, 20*200))) != 0)
			return(ret);
		BlockAdr += MaxDmaLen / BlockLen;
		TransferLen -= (unsigned short)(MaxDmaLen / BlockLen);
		buffer = (void *)((long)buffer + MaxDmaLen / BlockLen * BlockLen);
	}
	SetCmd10(&Cmd, READ_10, BlockAdr, TransferLen);
	return(In(SetCmd((char *)&Cmd, 10, buffer, BlockLen * (unsigned long)TransferLen, 20*200)));
}

long Write6(unsigned long BlockAdr, unsigned short TransferLen, void *buffer)
{
	long ret;
	tCmd6 Cmd;
	while(TransferLen > MaxDmaLen / BlockLen)
	{
		SetCmd6(&Cmd, WRITE_6, BlockAdr, (unsigned short)(MaxDmaLen / BlockLen));
		if((ret = Out(SetCmd((char *)&Cmd, 6, buffer, MaxDmaLen / BlockLen * BlockLen, 20*200))) != 0)
			return(ret);
		BlockAdr += MaxDmaLen / BlockLen;
		TransferLen -= (unsigned short)(MaxDmaLen / BlockLen);
		buffer = (void *)((long)buffer + MaxDmaLen / BlockLen * BlockLen);
	}
	SetCmd6(&Cmd, WRITE_6, BlockAdr, TransferLen);
	return(Out(SetCmd((char *)&Cmd, 6, buffer, BlockLen * (unsigned long)TransferLen, 20*200)));
}

long Write10(unsigned long BlockAdr, unsigned short TransferLen, void *buffer)
{
	long ret;
	tCmd10 Cmd;
	while(TransferLen > MaxDmaLen / BlockLen)
	{
		SetCmd10(&Cmd, WRITE_10, BlockAdr, (unsigned short)(MaxDmaLen / BlockLen));
		if((ret = Out(SetCmd((char *)&Cmd, 10, buffer, MaxDmaLen / BlockLen * BlockLen, 20*200))) != 0)
			return(ret);
		BlockAdr += MaxDmaLen / BlockLen;
		TransferLen -= (unsigned short)(MaxDmaLen / BlockLen);
		buffer = (void *)((long)buffer + MaxDmaLen / BlockLen * BlockLen);
	}
	SetCmd10(&Cmd, WRITE_10, BlockAdr, TransferLen);
	return(Out(SetCmd((char *)&Cmd, 10, buffer, BlockLen * (unsigned long)TransferLen, 20*200)));
}

#define cMaxBlockAdr  0x001FFFFFL /* Max. Blocknummer for Read6/Write6  */

long Read(unsigned long BlockAdr, unsigned short TransferLen, void *buffer)
{
	if(BlockAdr > cMaxBlockAdr)
		return(Read10(BlockAdr, TransferLen, buffer));
	else
		return(Read6(BlockAdr, TransferLen, buffer));
}

long Write(unsigned long BlockAdr, unsigned short TransferLen, void *buffer)
{
  if(BlockAdr > cMaxBlockAdr)
		return(Write10(BlockAdr, TransferLen, buffer));
	else
		return(Write6(BlockAdr, TransferLen, buffer));
}

long StartStop(int LoadEject, int StartFlag)
{
	tCmd6 Cmd;
		SetCmd6(&Cmd, START_STOP, 0, StartFlag ? 1 : 0);
	if(LoadEject)
		Cmd.Len |= 2;
	return(In(SetCmd((char *)&Cmd, 6, NULL, 0, 60*200)));
}

long ReadCapacity(int PMI, unsigned long *BlockAdr, unsigned long *BlockLen)
{
	unsigned long Data[2];
	long ret;
	tCmd10 Cmd;
	SetCmd10(&Cmd, READ_CAPACITY, *BlockAdr, 0);
	if(PMI)
		Cmd.LenLow = 1;
	if((ret = In(SetCmd((char *)&Cmd, 10, Data, sizeof(Data), DefTimeout))) == 0)
	{
		*BlockAdr = Data[0];
		*BlockLen = Data[1];
	}
	return(ret);
}

long GetConfiguration(int RT, unsigned short StartFeature, void *Buffer, unsigned short Len)
{
	tCmd10 Cmd;
	SetCmd10(&Cmd, GET_CONFIGURATION, (unsigned long)StartFeature << 16, Len);
	Cmd.Lun |= (RT & 3);
	return(In(SetCmd((char *)&Cmd, 10, Buffer, Len, DefTimeout)));
}

long ReadTOC(int MSF, int Format, unsigned short StartTrack, void *Buffer, unsigned short Len)
{
	tCmd10 Cmd;
	SetCmd10(&Cmd, READ_TOC, (unsigned long)Format << 24, Len);
	if(MSF)
		Cmd.Lun |= 2;
	Cmd.Reserved = (char)StartTrack;
	return(In(SetCmd((char *)&Cmd, 10, Buffer, Len, DefTimeout)));
}

long ReadDVDStucture(unsigned long Address, unsigned short LayerNumber, unsigned short Format, int AGID, void *Buffer, unsigned short Len)
{
	tCmd12 Cmd;
	SetCmd12(&Cmd, READ_DVD_STRUCTURE, Address, (Len & 0xFFFF) + (((unsigned long)LayerNumber & 0xFF) << 24) + (((unsigned long)Format & 0xFF) << 16));
	Cmd.Reserved = (AGID & 3) << 6;
	return(In(SetCmd((char *)&Cmd, 12, Buffer, Len, DefTimeout)));
}

long ReadDiskInfo(void *Buffer, unsigned short Len)
{
	tCmd10 Cmd;
	SetCmd10(&Cmd, READ_DISK_INFO, 0, Len);
	return(In(SetCmd((char *)&Cmd, 10, Buffer, Len, DefTimeout)));
}

long ReadTrackInfo(int AddressNumberType, unsigned long BlockAdr, void *Buffer, unsigned short Len)
{
	tCmd10 Cmd;
	SetCmd10(&Cmd, READ_TRACK_INFO, BlockAdr, Len);
	Cmd.Lun |= (AddressNumberType & 3);
	return(In(SetCmd((char *)&Cmd, 10, Buffer, Len, DefTimeout)));
}

