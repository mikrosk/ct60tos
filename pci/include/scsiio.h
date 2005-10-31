/****************************************************************************
 *
 * Definitionen und Kommandos fÅr SCSI-Calls in C
 *
 * $Source: u:\k\usr\src\scsi\cbhd\rcs\scsiio.h,v $
 *
 * $Revision: 1.7 $
 *
 * $Author: S_Engel $
 *
 * $Date: 1995/11/28 19:14:14 $
 *
 * $State: Exp $
 *
 *****************************************************************************
 * History:
 *
 * $Log: scsiio.h,v $
 * Revision 1.7  1995/11/28  19:14:14  S_Engel
 * *** empty log message ***
 *
 * Revision 1.6  1995/10/22  15:43:34  S_Engel
 * Kommentare leicht Åberarbeitet
 *
 * Revision 1.5  1995/10/03  12:49:08  S_Engel
 * Typendefinitionen nach scsidefs Åbertragen
 *
 * Revision 1.4  1995/09/29  09:12:16  S_Engel
 * alles nîtige fÅr virtuelles RAM
 *
 * Revision 1.3  1995/06/16  12:06:46  S_Engel
 * *** empty log message ***
 *
 * Revision 1.2  1995/03/09  09:53:16  S_Engel
 * Flags: Disconnect eingefÅhrt
 *
 * Revision 1.1  1995/03/05  18:54:16  S_Engel
 * Initial revision
 *
 *
 *
 ****************************************************************************/


#ifndef __SCSIIO_H
#define __SCSIIO_H

#ifdef __PUREC__
#define CDECL cdecl
#else
#define CDECL
#endif

#include "scsidefs.h"           /* Typen fÅr SCSI-Lib */

/*****************************************************************************
 * Konstanten                                                                *
 *****************************************************************************/
#define DefTimeout 2000

/*****************************************************************************
 * Variablen
 *****************************************************************************/

tpScsiCall scsicall;     /* READ ONLY!! */
int HasVirtual;          /* READ ONLY!! */
tReqData ReqBuff;        /* Request Sense Buffer fÅr alle Kommandos */

/*****************************************************************************
 * Funktionen und zugehîrige Typen
 *****************************************************************************/

/* fÅr In und Out kînnen diese Routinen gerufen werden, sie beachten selbsttÑtig,
 * wenn bei virtuellem RAM die Daten umkopiert werden mÅssen
 */
long cdecl In(tpSCSICmd Parms);
long cdecl Out(tpSCSICmd Parms);
long cdecl InquireSCSI(short what, tBusInfo *Info);
long cdecl InquireBus(short what, short BusNo, tDevInfo *Dev);
long cdecl CheckDev(short BusNo, const DLONG  *DevNo, char *Name, unsigned short *Features);
long cdecl RescanBus(short BusNo);
long cdecl Open(short bus, const DLONG *Id, unsigned long *MaxLen);
long cdecl Close(tHandle handle);
long cdecl Error(tHandle handle, short rwflag, short ErrNo);
int init_scsiio(void);
  /* Initialisierung des Moduls */

#endif
