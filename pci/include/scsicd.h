/*{{{}}}*/
/*********************************************************************
 *
 * Kommandos zum Zugriff auf CD-ROMs
 *
 * $Source: u:\k\usr\src\scsi\cbhd\rcs\scsicd.h,v $
 *
 * $Revision: 1.3 $
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
 * $Log: scsicd.h,v $
 * Revision 1.3  1996/02/14  11:33:52  Steffen_Engel
 * keine globalen Kommandostrukturen mehr
 *
 * Revision 1.2  1995/11/28  19:14:14  S_Engel
 * *** empty log message ***
 *
 * Revision 1.1  1995/11/13  23:46:04  S_Engel
 * Initial revision
 *
 *
 *
 *********************************************************************/

#ifndef __SCSICD
#define __SCSICD

/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- PauseResume entspricht der Pause-Taste des CD-Players.                -*/
/*- SCSI-Opcode $4B                                                       -*/
/*-                                                                       -*/
/*- Pause                                                                 -*/
/*-   TRUE  : CD h�lt an                                                  -*/
/*-   FALSE : CD spielt weiter                                            -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/
LONG PauseResume(int Pause);

/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- PlayAudio spielt von einee CD ab BlockAdr TransLength Bl�cke ab.      -*/
/*- SCSI-Opcode $A5                                                       -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/
LONG PlayAudio(LONG BlockAdr, LONG TransLength);


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
}tMSF;

/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- PlayAudioMSF startet die CD an der absoluten Position Start und l��t  -*/
/*- sie bis Stop laufen.                                                  -*/
/*- SCSI-Opcode $47                                                       -*/
/*-                                                                       -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/
LONG PlayAudioMSF(tMSF Start, tMSF Stop);


/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- Spielt die St�cke StarTrack.StartIndex bis EndTrack.EndIndex          -*/
/*- SCSI-Opcode $48                                                       -*/
/*-                                                                       -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/
LONG PlayAudioTrack(unsigned short StartTrack, unsigned short StartIndex, unsigned short EndTrack, unsigned short EndIndex);

/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- PlayAudioRelative startet den CD-Player bei der Position RelAdr in    -*/
/*- dem Track StartTrack und spielt Len Bl�cke ab.                        -*/
/*- SCSI-Opcode $49                                                       -*/
/*-                                                                       -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/
LONG PlayAudioRelative(unsigned short StartTrack, unsigned long RelAdr, unsigned long Len);

/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- ReadHeader fragt den Header der angegebenen BlockAdr ab.              -*/
/*-                                                                       -*/
/*- SCSI-Opcode $44                                                       -*/
/*-                                                                       -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/
LONG ReadHeader(int MSF, unsigned long BlockAdr, char *Mode, tMSF *AbsoluteAdr);

/* Werte f�r SubFormat */
#define SubQ       0
#define CDPos      1
#define MediaCatNo 2
#define TrackISRC  3
/* Audio-Status-Codes */
#define NotSupp    0
#define Playing    0x11
#define Paused     0x12
#define Complete   0x13
#define ErrStop    0x14
#define NoStatus   0x15
/* Werte f�r Adr (in ADRControl) */
#define NoQInfo   0     /* Sub-channel Q mode information not supplied. */
#define QencPOS   1     /* Sub-channel Q encodes current position data. */
#define QencUPC   2     /* Sub-channel Q encodes media catalog number.  */
#define QencISRC  3     /* Sub-channel Q encodes ISRC.                  */

#define AUDIOEMPHASIS 1
#define COPYPERMIT    2
#define DATATRACK     4
#define FOURCHANNEL   8

typedef struct
{
	char Res0;
	unsigned char AudioStatus;
	unsigned short SubLen;           /* Header 4 Bytes */
	char SubFormat;
	char ADRControl;
	unsigned char TrackNo;
	union
	{
		struct
		{
			unsigned char QIndex;
			tMSF QAbsAdr;         /* auf der CD */
			tMSF QRelAdr;         /* im Track   */
			char QMCVal;          /* Bit 8 */
			char QUPC14;
			char QUPC[14];
			char QTCVal;          /* Bit 8 */
			char QISRC14;
			char QISRC[14];
			/* SubQ : insgesamt 48 Bytes */
		} subq;
		struct
		{
			unsigned char IndexNo;
			tMSF AbsAdr;       /* auf der CD */
			tMSF RelAdr;       /* im Track   */
			/* CDPos : insgesamt 16 Bytes */
		} cdpos;
	} data;
} tSubData;

/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- Sub-Channel Daten abfragen                                            -*/
/*- Datenformat ist tSubData.                                             -*/
/*- SCSI-Opcode $42                                                       -*/
/*-                                                                       -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/
LONG ReadSubChannel(int MSF, int SUBQ, unsigned short SubFormat, unsigned short Track, void *Data, unsigned short Len);

#define MAXTOC 100          /* Maximum laut SCSI-2 */
typedef struct{
	char Res0;
	unsigned char ADRControl;
	unsigned char TrackNo;
	char  Res3;
	tMSF  AbsAddress;
}tTOCEntry;

typedef struct
{
	unsigned short TOCLen;           /* ohne TOCLen-Feld */
	unsigned char FirstTrack;
	unsigned char LastTrack;
}tTOCHead;

typedef struct
{
	tTOCHead Head;
	tTOCEntry Entry[MAXTOC];
}tTOC;

/*-------------------------------------------------------------------------*/
/*-                                                                       -*/
/*- ReadTOC liest das Inhaltsverzeichnis einer CD ein.                    -*/
/*- Wenn StartTrack # 0 ist, so wird das Inhaltsverzeichnis ab dem ange-  -*/
/*- gebenen Track angegeben.                                              -*/
/*- SCSI-Opcode $43                                                       -*/
/*-                                                                       -*/
/*-                                                                       -*/
/*-------------------------------------------------------------------------*/
LONG ReadTOC(int MSF, unsigned short StartTrack, void *Buffer, unsigned short Len);
int init_scsicd(void);

#endif


