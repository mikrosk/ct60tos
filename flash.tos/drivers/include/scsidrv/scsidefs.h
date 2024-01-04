#ifndef __SCSIDEFS_H
#define __SCSIDEFS_H

#define SCSIRevision 0x0101     /* Version 1.01 */

#define MAXBUSNO        31

#define NOSCSIERROR      0L
#define SELECTERROR     -1L
#define STATUSERROR     -2L
#define PHASEERROR      -3L
#define BSYERROR        -4L
#define BUSERROR        -5L
#define TRANSERROR      -6L
#define FREEERROR       -7L
#define TIMEOUTERROR    -8L
#define DATATOOLONG     -9L
#define LINKERROR      -10L
#define TIMEOUTARBIT   -11L
#define PENDINGERROR   -12L
#define PARITYERROR    -13L

#define w2mot(A) (A)
#define l2mot(A) (A)

typedef struct
{
	unsigned long hi;
	unsigned long lo;
} DLONG;


typedef struct{
	unsigned long BusIds;
	char resrvd[28];
} tPrivate;

typedef short *tHandle;

typedef struct
{
	tHandle Handle;
	char *Cmd;
	unsigned short CmdLen;
	void *Buffer;
	unsigned long TransferLen;
	char *SenseBuffer;
	unsigned long Timeout;  /* Timeout in 1/200 sec */
		#define Disconnect 0x10
	unsigned short Flags;
} tSCSICmd;

typedef tSCSICmd *tpSCSICmd;

typedef struct
{
	tPrivate Private;
	char BusName[20]; /* 'SCSI', 'ACSI', 'PAK-SCSI' */
	unsigned short BusNo;
		#define cArbit     0x01
		#define cAllCmds   0x02
		#define cTargCtrl  0x04
		#define cTarget    0x08
		#define cCanDisconnect 0x10
		#define cScatterGather 0x20
	unsigned short Features;
	unsigned long MaxLen;
}tBusInfo;

typedef struct
{
	char Private[32];
	DLONG SCSIId;
} tDevInfo;

typedef struct ttargethandler
{
	struct  ttargethandler *next;
	int (*TSel)(short bus, unsigned short CSB, unsigned short CSD);
	int (*TCmd)(short bus, char *Cmd);
	unsigned short(*TCmdLen)(short bus, unsigned short Cmd);
	void (*TReset) (unsigned short bus);
	void (*TEOP) (unsigned short bus);
	void (*TPErr)(unsigned short bus);
	void (*TPMism)(unsigned short bus);
	void (*TBLoss)(unsigned short bus);
	void (*TUnknownInt)(unsigned short bus);
} tTargetHandler;

typedef tTargetHandler *tpTargetHandler;

typedef char tReqData[18];

typedef struct
{
	unsigned short Version;                /* Revision in BCD: $0100 = 1.00 */
	long (*In)(tpSCSICmd  Parms);
	long (*Out)(tpSCSICmd  Parms);
		#define cInqFirst  0
		#define cInqNext   1
	long (*InquireSCSI)(short what, tBusInfo  *Info);
	long (*InquireBus)(short what, short BusNo, tDevInfo *Dev);
	long (*CheckDev)(short BusNo, const DLONG *SCSIId, char *Name, unsigned short *Features);
	long (*RescanBus)(short BusNo);
	long (*Open)(short BusNo, const DLONG *SCSIId, unsigned long *MaxLen);
	long (*Close)(tHandle handle);
		#define cErrRead   0
		#define cErrWrite  1
		#define cErrMediach  0
		#define cErrReset    1
	long (*Error)(tHandle handle, short rwflag, short ErrNo);
	long (*Install)(short bus, tpTargetHandler Handler);
	long (*Deinstall)(short bus, tpTargetHandler Handler);
	long (*GetCmd)(short bus, char *Cmd);
 	long (*SendData)(short bus, char *Buffer, unsigned long Len);
	long (*GetData)(short bus, void *Buffer, unsigned long Len);
	long (*SendStatus)(short bus, unsigned short Status);
	long (*SendMsg)(short bus, unsigned short Msg);
	long (*GetMsg)(short bus, unsigned short *Msg);
	tReqData *ReqData;
} tScsiCall;

typedef tScsiCall *tpScsiCall;

#define DefTimeout 4000

#define init_scsiio() \
do { \
	struct { \
		long cktag; \
		long ckvalue; \
	} *jar = (void *)Setexc(0x5A0 /4, (void (*)())-1); \
	scsicall = (tScsiCall *)0; \
	while(jar->cktag) { \
		if(jar->cktag == 0x53435349) { \
			scsicall = (tScsiCall *)jar->ckvalue; \
			break; \
		} \
		jar++; \
	} \
} while(0)	

#define In(Parms)	\
__extension__	\
({	\
	register long retvalue __asm__("d0");	\
	long  _Parms = (long) (Parms);	\
	long  _fct = (long) (scsicall->In);	\
	\
	__asm__ volatile (	\
		"movl	%2,sp@-\n\t"	\
		"movl	%1,a0\n\t"	\
		"jsr a0@\n\t"	\
		"addql #4,sp"	\
		: "=r"(retvalue)	\
		: "r"(_fct), "r"(_Parms)	\
		: __CLOBBER_RETURN("d0") "d1", "d2", "a0", "a1", "a2", "cc" /* clobbered regs */ \
		  AND_MEMORY \
	);	\
	retvalue;	\
})

#define Out(Parms)	\
__extension__	\
({	\
	register long retvalue __asm__("d0");	\
	long  _Parms = (long) (Parms);	\
	long  _fct = (long) (scsicall->Out);	\
	\
	__asm__ volatile (	\
		"movl	%2,sp@-\n\t"	\
		"movl	%1,a0\n\t"	\
		"jsr a0@\n\t"	\
		"addql #4,sp"	\
		: "=r"(retvalue)	\
		: "r"(_fct), "r"(_Parms)	\
		: __CLOBBER_RETURN("d0") "d1", "d2", "a0", "a1", "a2", "cc" /* clobbered regs */ \
		  AND_MEMORY \
	);	\
	retvalue;	\
})

#define InquireSCSI(what, Info)	\
__extension__	\
({	\
	register long retvalue __asm__("d0");	\
	long  _what = (long) (what);	\
	long  _Info = (long) (Info);	\
	long  _fct = (long) (scsicall->InquireSCSI);	\
	\
	__asm__ volatile (	\
		"movl	%3,sp@-\n\t"	\
		"movw	%2,sp@-\n\t"	\
		"movl	%1,a0\n\t"	\
		"jsr a0@\n\t"	\
		"addql #6,sp"	\
		: "=r"(retvalue)	\
		: "r"(_fct), "r"(_what), "r"(_Info)	\
		: __CLOBBER_RETURN("d0") "d1", "d2", "a0", "a1", "a2", "cc" /* clobbered regs */ \
		  AND_MEMORY \
	);	\
	retvalue;	\
})

#define InquireBus(what, BusNo, Dev)	\
__extension__	\
({	\
	register long retvalue __asm__("d0");	\
	long  _what = (long) (what);	\
	long  _BusNo = (long) (BusNo);	\
	long  _Dev = (long) (Dev);	\
	long  _fct = (long) (scsicall->InquireBus);	\
	\
	__asm__ volatile (	\
		"movl	%4,sp@-\n\t"	\
		"movw	%3,sp@-\n\t"	\
		"movw	%2,sp@-\n\t"	\
		"movl	%1,a0\n\t"	\
		"jsr a0@\n\t"	\
		"addql #8,sp"	\
		: "=r"(retvalue)	\
		: "r"(_fct), "r"(_what), "r"(_BusNo), "r"(_Dev)	\
		: __CLOBBER_RETURN("d0") "d1", "d2", "a0", "a1", "a2", "cc" /* clobbered regs */ \
		  AND_MEMORY \
	);	\
	retvalue;	\
})

#define CheckDev(BusNo, SCSIId, Name, Features)	\
__extension__	\
({	\
	register long retvalue __asm__("d0");	\
	long  _BusNo = (long) (BusNo);	\
	long  _SCSIId = (long) (SCSIId);	\
	long  _Name = (long) (Name);	\
	long  _Features = (long) (Name);	\
	long  _fct = (long) (scsicall->CheckDev);	\
	\
	__asm__ volatile (	\
		"movl	%5,sp@-\n\t"	\
		"movl	%4,sp@-\n\t"	\
		"movl	%3,sp@-\n\t"	\
		"movw	%2,sp@-\n\t"	\
		"movl	%1,a0\n\t"	\
		"jsr a0@\n\t"	\
		"lea sp@(14),sp"	\
		: "=r"(retvalue)	\
		: "r"(_fct), "r"(_BusNo), "r"(_SCSIId), "r"(_Name), "r"(_Features)	\
		: __CLOBBER_RETURN("d0") "d1", "d2", "a0", "a1", "a2", "cc" /* clobbered regs */ \
		  AND_MEMORY \
	);	\
	retvalue;	\
})

#define RescanBus(BusNo)	\
__extension__	\
({	\
	register long retvalue __asm__("d0");	\
	long  _BusNo = (long) (BusNo);	\
	long  _fct = (long) (scsicall->RescanBus);	\
	\
	__asm__ volatile (	\
		"movw	%2,sp@-\n\t"	\
		"movl	%1,a0\n\t"	\
		"jsr a0@\n\t"	\
		"addql #2,sp"	\
		: "=r"(retvalue)	\
		: "r"(_fct), "r"(_BusNo)	\
		: __CLOBBER_RETURN("d0") "d1", "d2", "a0", "a1", "a2", "cc" /* clobbered regs */ \
		  AND_MEMORY \
	);	\
	retvalue;	\
})

#define Open(bus, SCSIId, MaxLen)	\
__extension__	\
({	\
	register long retvalue __asm__("d0");	\
	long  _bus = (long) (bus);	\
	long  _SCSIId = (long) (SCSIId);	\
	long  _MaxLen = (long) (MaxLen);	\
	long  _fct = (long) (scsicall->Open);	\
	\
	__asm__ volatile (	\
		"movl	%4,sp@-\n\t"	\
		"movl	%3,sp@-\n\t"	\
		"movw	%2,sp@-\n\t"	\
		"movl	%1,a0\n\t"	\
		"jsr a0@\n\t"	\
		"lea sp@(10),sp"	\
		: "=r"(retvalue)	\
		: "r"(_fct), "r"(_bus), "r"(_SCSIId), "r"(_MaxLen)	\
		: __CLOBBER_RETURN("d0") "d1", "d2", "a0", "a1", "a2", "cc" /* clobbered regs */ \
		  AND_MEMORY \
	);	\
	retvalue;	\
})

#define Close(handle)	\
__extension__	\
({	\
	register long retvalue __asm__("d0");	\
	long  _handle = (long) (handle);	\
	long  _fct = (long) (scsicall->Close);	\
	\
	__asm__ volatile (	\
		"movl	%2,sp@-\n\t"	\
		"movl	%1,a0\n\t"	\
		"jsr a0@\n\t"	\
		"addql #4,sp"	\
		: "=r"(retvalue)	\
		: "r"(_fct), "r"(_handle)	\
		: __CLOBBER_RETURN("d0") "d1", "d2", "a0", "a1", "a2", "cc" /* clobbered regs */ \
		  AND_MEMORY \
	);	\
	retvalue;	\
})

#define Error(handle, rwflag, ErrNo)	\
__extension__	\
({	\
	register long retvalue __asm__("d0");	\
	long  _handle = (long) (handle);	\
	long  _rwflag = (long) (rwflag);	\
	long  _ErrNo = (long) (ErrNo);	\
	long  _fct = (long) (scsicall->Error);	\
	\
	__asm__ volatile (	\
		"movw	%4,sp@-\n\t"	\
		"movw	%3,sp@-\n\t"	\
		"movl	%2,sp@-\n\t"	\
		"movl	%1,a0\n\t"	\
		"jsr a0@\n\t"	\
		"addql #8,sp"	\
		: "=r"(retvalue)	\
		: "r"(_fct), "r"(_handle), "r"(_rwflag), "r"(_ErrNo)	\
		: __CLOBBER_RETURN("d0") "d1", "d2", "a0", "a1", "a2", "cc" /* clobbered regs */ \
		  AND_MEMORY \
	);	\
	retvalue;	\
})

#endif
