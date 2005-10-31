/****************************************************************************
 *
 * Typen fÅr SCSI-Calls in C
 *
 * $Source: u:\k\usr\src\scsi\cbhd\rcs\scsidefs.h,v $
 *
 * $Revision: 1.8 $
 *
 * $Author: Steffen_Engel $
 *
 * $Date: 1996/02/14 11:33:52 $
 *
 * $State: Exp $
 *
 *****************************************************************************
 * History:
 *
 * $Log: scsidefs.h,v $
 * Revision 1.8  1996/02/14  11:33:52  Steffen_Engel
 * keine globalen Kommandostrukturen mehr
 *
 * Revision 1.7  1996/01/25  17:53:16  Steffen_Engel
 * Tippfehler bei PARITYERROR korrigiert
 *
 * Revision 1.6  1995/11/28  19:14:14  S_Engel
 * *** empty log message ***
 *
 * Revision 1.5  1995/11/14  22:15:58  S_Engel
 * Kleine Korrekturen
 * aktualisiert auf aktuellen Stand
 *
 * Revision 1.4  1995/10/22  15:43:34  S_Engel
 * Kommentare leicht Åberarbeitet
 *
 * Revision 1.3  1995/10/13  22:30:54  S_Engel
 * GetMsg in Struktur eingefÅgt
 *
 * Revision 1.2  1995/10/11  10:21:34  S_Engel
 * Handle als long, Disconnect auf Bit4 verlegt
 *
 * Revision 1.1  1995/10/03  12:49:42  S_Engel
 * Initial revision
 *
 *
 ****************************************************************************/

#ifndef __SCSIDEFS_H
#define __SCSIDEFS_H

#ifdef __PUREC__
#define CDECL cdecl
#else
#define CDECL
#endif

/*****************************************************************************
 * Konstanten
 *****************************************************************************/
#define SCSIRevision 0x0100                     /* Version 1.00 */

#define MAXBUSNO        31       /* maximal mîgliche Busnummer */


/* SCSI-Fehlermeldungen fÅr In und Out */

#define NOSCSIERROR      0L /* Kein Fehler                                   */
#define SELECTERROR     -1L /* Fehler beim Selektieren                       */
#define STATUSERROR     -2L /* Default-Fehler                                */
#define PHASEERROR      -3L /* ungÅltige Phase                               */
#define BSYERROR        -4L /* BSY verloren                                  */
#define BUSERROR        -5L /* Busfehler bei DMA-öbertragung                 */
#define TRANSERROR      -6L /* Fehler beim DMA-Transfer (nichts Åbertragen)  */
#define FREEERROR       -7L /* Bus wird nicht mehr freigegeben               */
#define TIMEOUTERROR    -8L /* Timeout                                       */
#define DATATOOlong     -9L /* Daten fÅr ACSI-Softtransfer zu lang           */
#define LINKERROR      -10L /* Fehler beim Senden des Linked-Command (ACSI)  */
#define TIMEOUTARBIT   -11L /* Timeout bei der Arbitrierung                  */
#define PENDINGERROR   -12L /* auf diesem handle ist ein Fehler vermerkt     */
#define PARITYERROR    -13L /* Transfer verursachte Parity-Fehler            */

typedef struct
{
	unsigned long hi;
	unsigned long lo;
} DLONG;

typedef struct
{
	unsigned long BusIds;
	char  resrvd[28];
}tPrivate;

typedef short *tHandle;               /* Zeiger auf BusFeatures */

typedef struct
{
	tHandle Handle;                     /* Handle fÅr Bus und GerÑt             */
	char *Cmd;                          /* Zeiger auf CmdBlock                  */
	unsigned short CmdLen;              /* LÑnge des Cmd-Block (fÅr ACSI nîtig) */
	void *Buffer;                       /* Datenpuffer                          */
	unsigned long TransferLen;          /* öbertragungslÑnge                    */
	char *SenseBuffer;                  /* Puffer fÅr ReqSense (18 Bytes)       */
	unsigned long Timeout;              /* Timeout in 1/200 sec                 */
	unsigned short Flags;               /* Bitvektor fÅr AblaufwÅnsche          */
#define Disconnect 0x10               /* versuche disconnect                  */
}tSCSICmd;
typedef tSCSICmd *tpSCSICmd;

typedef struct
{
	tPrivate Private;
	/* fÅr den Treiber */
	char  BusName[20];
	/* zB 'SCSI', 'ACSI', 'PAK-SCSI' */
	unsigned short BusNo;
	/* Nummer, unter der der Bus anzusprechen ist */
	unsigned short Features;
#define cArbit     0x01    /* auf dem Bus wird arbitriert                          */
#define cAllCmds   0x02    /* hier kînnen ale SCSI-Cmds abgesetzt werden           */
#define cTargCtrl  0x04    /* Das Target steuert den Ablauf (so soll's sein!)      */
#define cTarget    0x08    /* auf diesem Bus kann man sich als Target installieren */
#define cCanDisconnect 0x10 /* Disconnect ist mîglich                             */
#define cScatterGather 0x20 /* scatter gather bei virtuellem RAM mîglich */
	/* bis zu 16 Features, die der Bus kann, zB Arbit,
	 * Full-SCSI (alle SCSI-Cmds im Gegensatz zu ACSI)
	 * Target oder Initiator gesteuert
	 * Ein SCSI-Handle ist auch ein Zeiger auf eine Kopie dieser Information!
	 */
	unsigned long MaxLen;
	/* maximale TransferlÑnge auf diesem Bus (in Bytes)
	 * entspricht zB bei ACSI der Grîûe des FRB
	 */
}tBusInfo;

typedef struct
{
	char Private[32];
	DLONG SCSIId;
}tDevInfo;

typedef struct ttargethandler
{
  struct ttargethandler *next;
  int cdecl (*TSel)(short bus, unsigned short CSB, unsigned short CSD);
  int cdecl (*TCmd)(short bus, char *Cmd);
  unsigned short cdecl (*TCmdLen)(short bus, unsigned short Cmd);
  void cdecl (*TReset)(unsigned short bus);
  void cdecl (*TEOP)(unsigned short bus);
  void cdecl (*TPErr)(unsigned short bus);
  void cdecl (*TPMism)(unsigned short bus);
  void cdecl (*TBLoss)(unsigned short bus);
  void cdecl (*TUnknownInt)(unsigned short bus);
}tTargetHandler;

typedef tTargetHandler *tpTargetHandler;

typedef char tReqData[18];

typedef struct
{
	unsigned short Version;  /* Revision in BCD: $0100 = 1.00 */
	/* Routinen als Initiator */
	long cdecl (*In)(tpSCSICmd  Parms);
	long cdecl (*Out)(tpSCSICmd  Parms);
	long cdecl (*InquireSCSI)(short what, tBusInfo *Info);
#define cInqFirst 0
#define cInqNext  1
	long cdecl (*InquireBus)(short what, short BusNo, tDevInfo *Dev);
	long cdecl (*CheckDev)(short BusNo, const DLONG *SCSIId, char *Name, unsigned short *Features);
	long cdecl (*RescanBus)(short BusNo);
	long cdecl (*Open)(short BusNo, const DLONG *SCSIId, unsigned long *MaxLen);
	long cdecl (*Close)(tHandle handle);
	long cdecl (*Error)(tHandle handle, short rwflag, short ErrNo);
#define cErrRead   0
#define cErrWrite  1
#define cErrMediach  0
#define cErrReset    1
  /* Routinen als Target (optional) */
  long cdecl (*Install)(short bus, tpTargetHandler Handler);
  long cdecl (*Deinstall)(short bus, tpTargetHandler Handler);
  long cdecl (*GetCmd)(short bus, char *Cmd);
  long cdecl (*SendData)(short bus, char *Buffer, unsigned long Len);
  long cdecl (*GetData)(short bus, void *Buffer, Unsigned long Len);
  long cdecl (*SendStatus)(short bus, unsigned short Status);
  long cdecl (*SendMsg)(short bus, unsigned short Msg);
  long  cdecl (*GetMsg)(short bus, unsigned short *Msg);
  /* globale Variablen (fÅr Targetroutinen) */
  tReqData *ReqData;
}tScsiCall;
typedef tScsiCall *tpScsiCall;

#endif