/* Flashing hard CT60, JTAG part
*  Didier Mequignon 2003 February, e-mail: aniplay@wanadoo.fr
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

#include <stdio.h>
#include <tos.h>
#include "jtag.h"

static long Hir=0,Tir=0,Hdr=0,Tdr=0;

void waitTime(unsigned long microsec)
{
	int i;
	unsigned long time;
	if(microsec>=50000)
	{
		microsec/=5000;
		microsec++;
		time=*(unsigned long *)0x4BA;
		while(*(unsigned long *)0x4BA - time < microsec);
	}
	else
		for(i=0;i<microsec;pulseClock(1),i++);
}

/*****************************************************************************
* Function:     TmsTransition
* Description:  Apply TMS and transition TAP controller by applying one TCK
*               cycle.
* Parameters:   sTms    - new TMS value.
* Returns:      void.
*****************************************************************************/
void TmsTransition(short sTms)
{
	setPort(TMS,(unsigned char)sTms);
	pulseClock(1);
}

/*****************************************************************************
* Function:     ChangeTapState
* Description:  From the current TAP state, go to the named TAP state.
*               A target state of RESET ALWAYS causes TMS reset sequence.
*               All SVF standard stable state paths are supported.
*               All state transitions are supported except for the following
*               which cause an ERROR_ILLEGALSTATE:
*                   - Target==DREXIT2;  Start!=DRPAUSE
*                   - Target==IREXIT2;  Start!=IRPAUSE
* Parameters:   TapState     - Current TAP state; returns final TAP state.
*               TargetState  - New target TAP state.
* Returns:      int          - 0 = success; otherwise error.
*****************************************************************************/
int ChangeTapState(unsigned char * TapState,unsigned char TargetState)
{
	int i;
	int ErrorCode;
	ErrorCode=ERROR_NONE;
	if(TargetState==TAPSTATE_RESET)
	{
		/* If RESET, always perform TMS reset sequence to reset/sync TAPs */
		TmsTransition(1);
		pulseClock(5);
		*TapState=TAPSTATE_RESET;
	}
	else if((TargetState!=*TapState)
	 && (((TargetState==TAPSTATE_EXIT2DR) && (*TapState!=TAPSTATE_PAUSEDR))
	  || ((TargetState==TAPSTATE_EXIT2IR) && (*TapState!=TAPSTATE_PAUSEIR))))
		ErrorCode=ERROR_ILLEGALSTATE;		/* Trap illegal TAP state path specification */
	else
	{
		if(TargetState==*TapState)
		{
			/* Already in target state.  Do nothing except when in DRPAUSE or in IRPAUSE */
			if(TargetState==TAPSTATE_PAUSEDR)
			{
				TmsTransition(1);
				*TapState=TAPSTATE_EXIT2DR;
			}
			else if(TargetState==TAPSTATE_PAUSEIR)
			{
				TmsTransition(1);
				*TapState=TAPSTATE_EXIT2IR;
			}
		}
		/* Perform TAP state transitions to get to the target state */
		while(TargetState!=*TapState)
		{
			switch(*TapState)
			{
				case TAPSTATE_RESET:
					TmsTransition(0);
					*TapState=TAPSTATE_RUNTEST;
					break;
				case TAPSTATE_RUNTEST:
					TmsTransition(1);
					*TapState=TAPSTATE_SELECTDR;
					break;
				case TAPSTATE_SELECTDR:
					if(TargetState>=TAPSTATE_IRSTATES)
					{
						TmsTransition(1);
						*TapState=TAPSTATE_SELECTIR;
					}
					else
					{
						TmsTransition(0);
						*TapState=TAPSTATE_CAPTUREDR;
					}
					break;
				case TAPSTATE_CAPTUREDR:
					if(TargetState==TAPSTATE_SHIFTDR)
					{
						TmsTransition(0);
						*TapState=TAPSTATE_SHIFTDR;
					}
					else
					{
						TmsTransition(1);
						*TapState=TAPSTATE_EXIT1DR;
					}
					break;
				case TAPSTATE_SHIFTDR:
					TmsTransition(1);
					*TapState=TAPSTATE_EXIT1DR;
					break;
				case TAPSTATE_EXIT1DR:
					if(TargetState==TAPSTATE_PAUSEDR)
					{
						TmsTransition(0);
						*TapState=TAPSTATE_PAUSEDR;
					}
					else
					{
						TmsTransition(1);
						*TapState=TAPSTATE_UPDATEDR;
					}
					break;
				case TAPSTATE_PAUSEDR:
					TmsTransition(1);
					*TapState=TAPSTATE_EXIT2DR;
					break;
				case TAPSTATE_EXIT2DR:
					if(TargetState==TAPSTATE_SHIFTDR)
					{
						TmsTransition(0);
						*TapState=TAPSTATE_SHIFTDR;
					}
					else
					{
						TmsTransition(1);
						*TapState=TAPSTATE_UPDATEDR;
					}
					break;
				case TAPSTATE_UPDATEDR:
					if(TargetState==TAPSTATE_RUNTEST)
					{
						TmsTransition(0);
						*TapState=TAPSTATE_RUNTEST;
					}
					else
					{
						TmsTransition(1);
						*TapState=TAPSTATE_SELECTDR;
					}
					break;
				case TAPSTATE_SELECTIR:
					TmsTransition(0);
					*TapState=TAPSTATE_CAPTUREIR;
					break;
				case TAPSTATE_CAPTUREIR:
					if(TargetState==TAPSTATE_SHIFTIR)
					{
						TmsTransition(0);
						*TapState=TAPSTATE_SHIFTIR;
					}
					else
					{
						TmsTransition(1);
						*TapState=TAPSTATE_EXIT1IR;
					}
					break;
				case TAPSTATE_SHIFTIR:
					TmsTransition(1);
					*TapState=TAPSTATE_EXIT1IR;
					break;
				case TAPSTATE_EXIT1IR:
					if(TargetState==TAPSTATE_PAUSEIR)
					{
						TmsTransition(0);
						*TapState=TAPSTATE_PAUSEIR;
					}
					else
					{
						TmsTransition(1);
						*TapState=TAPSTATE_UPDATEIR;
					}
					break;
				case TAPSTATE_PAUSEIR:
					TmsTransition(1);
					*TapState=TAPSTATE_EXIT2IR;
					break;
				case TAPSTATE_EXIT2IR:
					if(TargetState==TAPSTATE_SHIFTIR)
					{
						TmsTransition(0);
						*TapState=TAPSTATE_SHIFTIR;
					}
					else
					{
						TmsTransition(1);
						*TapState=TAPSTATE_UPDATEIR;
					}
					break;
				case TAPSTATE_UPDATEIR:
					if(TargetState==TAPSTATE_RUNTEST)
					{
						TmsTransition(0);
						*TapState=TAPSTATE_RUNTEST;
					}
					else
					{
						TmsTransition( 1 );
						*TapState=TAPSTATE_SELECTDR;
					}
					break;
				default:
					ErrorCode=ERROR_ILLEGALSTATE;
					*TapState=TargetState;    /* Exit while loop */
					break;
			}
		}
	}
	return(ErrorCode);
}

/*****************************************************************************
* Function:     EqualLenVal
* Description:  Compare two lenval arrays with an optional mask.
* Parameters:   TdoExpected  - ptr to lenval #1.
*               TdoCaptured  - ptr to lenval #2.
*               TdoMask      - optional ptr to mask (=0 if no mask).
* Returns:      short   - 0 = mismatch; 1 = equal.
*****************************************************************************/
short EqualLenVal(lenVal *TdoExpected,lenVal *TdoCaptured,lenVal *TdoMask)
{
	short Equal,Index;
	unsigned char ByteVal1,ByteVal2,ByteMask;
	unsigned char *PtrExpected,*PtrCaptured,*PtrMask;
	Equal=1;
	Index=TdoExpected->len;
	PtrExpected=&TdoExpected->val[Index];
	PtrCaptured=&TdoCaptured->val[Index];
	PtrMask=&TdoMask->val[Index];
	while(Index--)
	{
		ByteVal1=*(--PtrExpected);
		ByteVal2=*(--PtrCaptured);
		if(TdoMask)
		{
			ByteMask=*(--PtrMask);
			ByteVal1&=ByteMask;
			ByteVal2&=ByteMask;
		}
		if(ByteVal1!=ByteVal2)
		{
			Equal=0;
			break;
		}
	}
	return(Equal);
}

/*****************************************************************************
* Function:     JtagShiftOnly
* Description:  Assumes that starting TAP state is SHIFT-DR or SHIFT-IR.
*               Shift the given TDI data into the JTAG scan chain.
*               Optionally, save the TDO data shifted out of the scan chain.
*               Last shift cycle is special:  capture last TDO, set last TDI,
*               but does not pulse TCK.  Caller must pulse TCK and optionally
*               set TMS=1 to exit shift state.
* Parameters:   TapState      - current TAP state.
*               NumBits       - number of bits to shift.
*               Tdi           - ptr to lenval for TDI data.
*               TdoCaptured   - ptr to lenval for storing captured TDO data.
*               ExitShift     - 1=exit at end of shift; 0=stay in Shift-DR.
* Returns:      void.
*****************************************************************************/
void JtagShiftOnly(unsigned char TapState,long NumBits,lenVal *Tdi,lenVal *TdoCaptured,int ExitShift)
{
	unsigned char *TdiPtr,*TdoPtr;
	unsigned char TdiByte,TdoByte,Hr;
	long NumBitsTot;
	int i;
	/* Initialize TDO storage len == TDI len */
	TdoPtr=0;
	if(TdoCaptured)
	{
		TdoCaptured->len=Tdi->len;
		TdoPtr=TdoCaptured->val+Tdi->len;
	}
	/* Shift LSB first.  val[N-1] == LSB.  val[0] == MSB. */
	TdiPtr=Tdi->val+Tdi->len;
	NumBitsTot=NumBits;
	switch(TapState)
	{
		case TAPSTATE_SHIFTIR:
			setPort(TDI,1);                      /* Bit to shift before the target */
			pulseClock(Hir);
			NumBitsTot+=Tir;
			break;
		case TAPSTATE_SHIFTDR:
			setPort(TDI,0);                      /* Bit to shift before the target */
			pulseClock(Hdr);
			NumBitsTot+=Tdr;
			break;
	}
	while(NumBits)
	{
		/* Process on a byte-basis */
		TdiByte=(*(--TdiPtr));
		if(TdoPtr)
		{
			TdoByte=0;
			for(i=8;NumBits && i;i--)
			{
				NumBits--;
				NumBitsTot--;
				if(ExitShift && !NumBitsTot)
					setPort(TMS,1);              /* Exit Shift-DR state */
				setPort(TDI,TdiByte);            /* Set the new TDI value */
				TdiByte>>=1;
				setPort(TCK,0);                  /* Set TCK low */
				TdoByte>>=1;
				TdoByte|=readTDOBit();           /* Save the TDO value */
				setPort(TCK,1);                  /* Set TCK high */
			}
			(*(--TdoPtr))=TdoByte;               /* Save the TDO byte value */
		}
		else
		{
			for(i=8;NumBits && i;i--)
			{
				NumBits--;
				NumBitsTot--;
				if(ExitShift && !NumBitsTot)
					setPort(TMS,1);              /* Exit Shift-DR state */
				setPort(TDI,TdiByte);            /* Set the new TDI value */
				TdiByte>>=1;
				pulseClock(1);                   /* Toggle TCK LH */
			}
		}
	}
	switch(TapState)
	{
		case TAPSTATE_SHIFTIR:
			setPort(TDI,1);                      /* Bits to shift after the target */
			for(i=Tir;i;i--)
			{
				NumBitsTot--;
				if(ExitShift && !NumBitsTot)
					setPort(TMS,1);              /* Exit Shift-DR state */
				pulseClock(1);
			}
			break;
		case TAPSTATE_SHIFTDR:
			setPort(TDI,1);                      /* Bits to shift after the target */
			for(i=Tdr;i;i--)
			{
				NumBitsTot--;
				if(ExitShift && !NumBitsTot)
					setPort(TMS,1);              /* Exit Shift-DR state */
				pulseClock(1);
			}
			break;
	}
}

/*****************************************************************************
* Function:     JtagShift
* Description:  Goes to the given starting TAP state.
*               Calls ShiftOnly to shift in the given TDI data and
*               optionally capture the TDO data.
*               Compares the TDO captured data against the TDO expected
*               data.
*               If a data mismatch occurs, then executes the exception
*               handling loop upto ucMaxRepeat times.
* Parameters:   TapState      - Ptr to current TAP state.
*               StartState    - Starting shift state: Shift-DR or Shift-IR.
*               NumBits       - number of bits to shift.
*               Tdi           - ptr to lenval for TDI data.
*               TdoCaptured   - ptr to lenval for storing TDO data.
*               TdoExpected   - ptr to expected TDO data.
*               TdoMask       - ptr to TDO mask.
*               EndState      - state in which to end the shift.
*               RunTestTime   - amount of time to wait after the shift.
*               MaxRepeat     - Maximum number of retries on TDO mismatch.
* Returns:      int           - 0 = success; otherwise TDO mismatch.
* Notes:        XC9500XL-only Optimization:
*               Skip the waitTime() if TdoMask->val[0:TdoMask->len-1]
*               is NOT all zeros and sMatch==1.
*****************************************************************************/
int JtagShift(unsigned char *TapState,unsigned char StartState,long NumBits,
              lenVal *Tdi,lenVal *TdoCaptured,lenVal *TdoExpected,lenVal *TdoMask,
              unsigned char EndState,long RunTestTime,unsigned char MaxRepeat)
{
	int ErrorCode,Mismatch,ExitShift;
	long stack;
	unsigned char Repeat;
	ErrorCode=ERROR_NONE;
	Mismatch=Repeat=0;
	ExitShift=(StartState!=EndState);
	stack=Super(0L);
	if(!NumBits)
	{
		/* SDR 0 = no shift, but wait in RTI */
		if(RunTestTime)
		{
			ChangeTapState(TapState,TAPSTATE_RUNTEST);            /* Wait for prespecified RUNTEST time */
			waitTime(RunTestTime);
		}
	}
	else
	{
		do
		{
			ChangeTapState(TapState,StartState);                  /* Goto Shift-DR or Shift-IR */
			JtagShiftOnly(StartState,NumBits,Tdi,TdoCaptured,ExitShift);  /* Shift TDI and capture TDO */
			if(TdoExpected)                                       /* Compare TDO data to expected TDO data */
				Mismatch=!EqualLenVal(TdoExpected,TdoCaptured,TdoMask);               
			if(ExitShift)
			{
				++(*TapState);                                    /* Update TAP state:  Shift->Exit */
				if(Mismatch && RunTestTime && (Repeat < MaxRepeat))
				{
					ChangeTapState(TapState,TAPSTATE_PAUSEDR);    /* Do exception handling retry - ShiftDR only */
					ChangeTapState(TapState,TAPSTATE_SHIFTDR);    /* Shift 1 extra bit */
					RunTestTime += (RunTestTime>>2);              /* Increment RUNTEST time by an additional 25% */
				}
				else
					ChangeTapState(TapState,EndState);            /* Do normal exit from Shift-XR */
				if(RunTestTime)
				{
					ChangeTapState(TapState,TAPSTATE_RUNTEST);    /* Wait for prespecified RUNTEST time */
					waitTime(RunTestTime);
				}
			}
		}
		while(Mismatch && (Repeat++ < MaxRepeat));
	}
	if(Mismatch)
	{
		if(MaxRepeat && (Repeat > MaxRepeat))
			ErrorCode=ERROR_MAXRETRIES;
		else
			ErrorCode=ERROR_TDOMISMATCH;
	}
	Super((void *)stack);
	return(ErrorCode);
}

/*****************************************************************************
* Function:     JtagSelectTarget
* Description:  Select device target for set:
*               - The number of one bits to shift before the target set of 
*                 instruction bits. These bits put the non-target devices
*                 after the target device into BYPASS mode (Hir).
*               - The number of one bits to shift after the target set of 
*                 instruction bits. These bits put the non-target devices
*                 before the target device into BYPASS mode (Tir).
*               - The number of zero bits to shift before the target set of 
*                 instruction bits. These bits are placeholders that fill 
*                 the BYPASS data registers in the non-target devices after
*                 the target device (Hdr).
*               - The number of zero bits to shift after the target set of 
*                 instruction bits. These bits are placeholders that fill 
*                 the BYPASS data registers in the non-target devices before
*                 the target device (Tdr).
* Global Parameters:
*               Hir - Header Instruction Register.
*               Tir - Trailer Instruction Register.
*               Hdr - Header Data Register.
*               Tdr - Trailer Data Register.
* Global:       Device (1,2,etc...).
* Returns:      void.
*****************************************************************************/
void JtagSelectTarget(int Device)
{
	switch(Device)
	{
		case ABE:  /* first device on the chain */
			Hir=CMD_BIT_LENGTH;
			Tir=0;
			Hdr=1;
			Tdr=0;
		  break;
		case SDR:  /* last device on the chain */
			Hir=0;
			Tir=CMD_BIT_LENGTH;
			Hdr=0;
			Tdr=1;		
			break;
		default:   /* device alone */
			Hir=Tir=Hdr=Tdr=0;
			break;
	}
#ifdef DEBUG
	printf("\r\nDevice:%d, Hir:%ld, Tir:%ld, Hdr:%ld, Tdr:%ld ",Device,Hir,Tir,Hdr,Tdr);
#endif
}
