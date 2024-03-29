/*
 * File:    mcf548x_gpt.h
 * Purpose: Register and bit definitions
 */

#ifndef __MCF548X_GPT_H__
#define __MCF548X_GPT_H__

/*********************************************************************
*
* General Purpose Timers (GPT)
*
*********************************************************************/

/* Register read/write macros */
#define MCF_GPT0_GMS             (*(vuint32*)(&__MBAR[0x000800]))
#define MCF_GPT0_GCIR            (*(vuint32*)(&__MBAR[0x000804]))
#define MCF_GPT0_GPWM            (*(vuint32*)(&__MBAR[0x000808]))
#define MCF_GPT0_GSR             (*(vuint32*)(&__MBAR[0x00080C]))
#define MCF_GPT1_GMS             (*(vuint32*)(&__MBAR[0x000810]))
#define MCF_GPT1_GCIR            (*(vuint32*)(&__MBAR[0x000814]))
#define MCF_GPT1_GPWM            (*(vuint32*)(&__MBAR[0x000818]))
#define MCF_GPT1_GSR             (*(vuint32*)(&__MBAR[0x00081C]))
#define MCF_GPT2_GMS             (*(vuint32*)(&__MBAR[0x000820]))
#define MCF_GPT2_GCIR            (*(vuint32*)(&__MBAR[0x000824]))
#define MCF_GPT2_GPWM            (*(vuint32*)(&__MBAR[0x000828]))
#define MCF_GPT2_GSR             (*(vuint32*)(&__MBAR[0x00082C]))
#define MCF_GPT3_GMS             (*(vuint32*)(&__MBAR[0x000830]))
#define MCF_GPT3_GCIR            (*(vuint32*)(&__MBAR[0x000834]))
#define MCF_GPT3_GPWM            (*(vuint32*)(&__MBAR[0x000838]))
#define MCF_GPT3_GSR             (*(vuint32*)(&__MBAR[0x00083C]))
#define MCF_GPT_GMS(x)           (*(vuint32*)(&__MBAR[0x000800+((x)*0x010)]))
#define MCF_GPT_GCIR(x)          (*(vuint32*)(&__MBAR[0x000804+((x)*0x010)]))
#define MCF_GPT_GPWM(x)          (*(vuint32*)(&__MBAR[0x000808+((x)*0x010)]))
#define MCF_GPT_GSR(x)           (*(vuint32*)(&__MBAR[0x00080C+((x)*0x010)]))

/* Bit definitions and macros for MCF_GPT_GMS */
#define MCF_GPT_GMS_TMS(x)       (((x)&0x00000007)<<0)
#define MCF_GPT_GMS_GPIO(x)      (((x)&0x00000003)<<4)
#define MCF_GPT_GMS_IEN          (0x00000100)
#define MCF_GPT_GMS_OD           (0x00000200)
#define MCF_GPT_GMS_SC           (0x00000400)
#define MCF_GPT_GMS_CE           (0x00001000)
#define MCF_GPT_GMS_WDEN         (0x00008000)
#define MCF_GPT_GMS_ICT(x)       (((x)&0x00000003)<<16)
#define MCF_GPT_GMS_OCT(x)       (((x)&0x00000003)<<20)
#define MCF_GPT_GMS_OCPW(x)      (((x)&0x000000FF)<<24)
#define MCF_GPT_GMS_OCT_FRCLOW   (0x00000000)
#define MCF_GPT_GMS_OCT_PULSEHI  (0x00100000)
#define MCF_GPT_GMS_OCT_PULSELO  (0x00200000)
#define MCF_GPT_GMS_OCT_TOGGLE   (0x00300000)
#define MCF_GPT_GMS_ICT_ANY      (0x00000000)
#define MCF_GPT_GMS_ICT_RISE     (0x00010000)
#define MCF_GPT_GMS_ICT_FALL     (0x00020000)
#define MCF_GPT_GMS_ICT_PULSE    (0x00030000)
#define MCF_GPT_GMS_GPIO_INPUT   (0x00000000)
#define MCF_GPT_GMS_GPIO_OUTLO   (0x00000020)
#define MCF_GPT_GMS_GPIO_OUTHI   (0x00000030)
#define MCF_GPT_GMS_TMS_DISABLE  (0x00000000)
#define MCF_GPT_GMS_TMS_INCAPT   (0x00000001)
#define MCF_GPT_GMS_TMS_OUTCAPT  (0x00000002)
#define MCF_GPT_GMS_TMS_PWM      (0x00000003)
#define MCF_GPT_GMS_TMS_GPIO     (0x00000004)

/* Bit definitions and macros for MCF_GPT_GCIR */
#define MCF_GPT_GCIR_CNT(x)      (((x)&0x0000FFFF)<<0)
#define MCF_GPT_GCIR_PRE(x)      (((x)&0x0000FFFF)<<16)

/* Bit definitions and macros for MCF_GPT_GPWM */
#define MCF_GPT_GPWM_LOAD        (0x00000001)
#define MCF_GPT_GPWM_PWMOP       (0x00000100)
#define MCF_GPT_GPWM_WIDTH(x)    (((x)&0x0000FFFF)<<16)

/* Bit definitions and macros for MCF_GPT_GSR */
#define MCF_GPT_GSR_CAPT         (0x00000001)
#define MCF_GPT_GSR_COMP         (0x00000002)
#define MCF_GPT_GSR_PWMP         (0x00000004)
#define MCF_GPT_GSR_TEXP         (0x00000008)
#define MCF_GPT_GSR_PIN          (0x00000100)
#define MCF_GPT_GSR_OVF(x)       (((x)&0x00000007)<<12)
#define MCF_GPT_GSR_CAPTURE(x)   (((x)&0x0000FFFF)<<16)

/********************************************************************/

#endif /* __MCF548X_GPT_H__ */
