/*
 * File:    mcf548x_dspi.h
 * Purpose: Register and bit definitions
 */

#ifndef __MCF548X_DSPI_H__
#define __MCF548X_DSPI_H__

/*********************************************************************
*
* DMA Serial Peripheral Interface (DSPI)
*
*********************************************************************/

/* Register read/write macros */
#define MCF_DSPI_DMCR               (*(vuint32*)(&__MBAR[0x008A00]))
#define MCF_DSPI_DTCR               (*(vuint32*)(&__MBAR[0x008A08]))
#define MCF_DSPI_DCTAR0             (*(vuint32*)(&__MBAR[0x008A0C]))
#define MCF_DSPI_DCTAR1             (*(vuint32*)(&__MBAR[0x008A10]))
#define MCF_DSPI_DCTAR2             (*(vuint32*)(&__MBAR[0x008A14]))
#define MCF_DSPI_DCTAR3             (*(vuint32*)(&__MBAR[0x008A18]))
#define MCF_DSPI_DCTAR4             (*(vuint32*)(&__MBAR[0x008A1C]))
#define MCF_DSPI_DCTAR5             (*(vuint32*)(&__MBAR[0x008A20]))
#define MCF_DSPI_DCTAR6             (*(vuint32*)(&__MBAR[0x008A24]))
#define MCF_DSPI_DCTAR7             (*(vuint32*)(&__MBAR[0x008A28]))
#define MCF_DSPI_DCTAR(x)           (*(vuint32*)(&__MBAR[0x008A0C+((x)*0x004)]))
#define MCF_DSPI_DSR                (*(vuint32*)(&__MBAR[0x008A2C]))
#define MCF_DSPI_DIRSR              (*(vuint32*)(&__MBAR[0x008A30]))
#define MCF_DSPI_DTFR               (*(vuint32*)(&__MBAR[0x008A34]))
#define MCF_DSPI_DRFR               (*(vuint32*)(&__MBAR[0x008A38]))
#define MCF_DSPI_DTFDR0             (*(vuint32*)(&__MBAR[0x008A3C]))
#define MCF_DSPI_DTFDR1             (*(vuint32*)(&__MBAR[0x008A40]))
#define MCF_DSPI_DTFDR2             (*(vuint32*)(&__MBAR[0x008A44]))
#define MCF_DSPI_DTFDR3             (*(vuint32*)(&__MBAR[0x008A48]))
#define MCF_DSPI_DTFDR(x)           (*(vuint32*)(&__MBAR[0x008A3C+((x)*0x004)]))
#define MCF_DSPI_DRFDR0             (*(vuint32*)(&__MBAR[0x008A7C]))
#define MCF_DSPI_DRFDR1             (*(vuint32*)(&__MBAR[0x008A80]))
#define MCF_DSPI_DRFDR2             (*(vuint32*)(&__MBAR[0x008A84]))
#define MCF_DSPI_DRFDR3             (*(vuint32*)(&__MBAR[0x008A88]))
#define MCF_DSPI_DRFDR(x)           (*(vuint32*)(&__MBAR[0x008A7C+((x)*0x004)]))

/* Bit definitions and macros for MCF_DSPI_DMCR */
#define MCF_DSPI_DMCR_HALT          (0x00000001)
#define MCF_DSPI_DMCR_SMPL_PT(x)    (((x)&0x00000003)<<8)
#define MCF_DSPI_DMCR_CRXF          (0x00000400)
#define MCF_DSPI_DMCR_CTXF          (0x00000800)
#define MCF_DSPI_DMCR_DRXF          (0x00001000)
#define MCF_DSPI_DMCR_DTXF          (0x00002000)
#define MCF_DSPI_DMCR_CSIS0         (0x00010000)
#define MCF_DSPI_DMCR_CSIS2         (0x00040000)
#define MCF_DSPI_DMCR_CSIS3         (0x00080000)
#define MCF_DSPI_DMCR_CSIS5         (0x00200000)
#define MCF_DSPI_DMCR_ROOE          (0x01000000)
#define MCF_DSPI_DMCR_PCSSE         (0x02000000)
#define MCF_DSPI_DMCR_MTFE          (0x04000000)
#define MCF_DSPI_DMCR_FRZ           (0x08000000)
#define MCF_DSPI_DMCR_DCONF(x)      (((x)&0x00000003)<<28)
#define MCF_DSPI_DMCR_CSCK          (0x40000000)
#define MCF_DSPI_DMCR_MSTR          (0x80000000)

/* Bit definitions and macros for MCF_DSPI_DTCR */
#define MCF_DSPI_DTCR_SPI_TCNT(x)   (((x)&0x0000FFFF)<<16)

/* Bit definitions and macros for MCF_DSPI_DCTAR */
#define MCF_DSPI_DCTAR_BR(x)        (((x)&0x0000000F)<<0)
#define MCF_DSPI_DCTAR_DT(x)        (((x)&0x0000000F)<<4)
#define MCF_DSPI_DCTAR_ASC(x)       (((x)&0x0000000F)<<8)
#define MCF_DSPI_DCTAR_CSSCK(x)     (((x)&0x0000000F)<<12)
#define MCF_DSPI_DCTAR_PBR(x)       (((x)&0x00000003)<<16)
#define MCF_DSPI_DCTAR_PDT(x)       (((x)&0x00000003)<<18)
#define MCF_DSPI_DCTAR_PASC(x)      (((x)&0x00000003)<<20)
#define MCF_DSPI_DCTAR_PCSSCK(x)    (((x)&0x00000003)<<22)
#define MCF_DSPI_DCTAR_LSBFE        (0x01000000)
#define MCF_DSPI_DCTAR_CPHA         (0x02000000)
#define MCF_DSPI_DCTAR_CPOL         (0x04000000)
#define MCF_DSPI_DCTAR_TRSZ(x)      (((x)&0x0000000F)<<27)
#define MCF_DSPI_DCTAR_PCSSCK_1CLK  (0x00000000)
#define MCF_DSPI_DCTAR_PCSSCK_3CLK  (0x00400000)
#define MCF_DSPI_DCTAR_PCSSCK_5CLK  (0x00800000)
#define MCF_DSPI_DCTAR_PCSSCK_7CLK  (0x00A00000)
#define MCF_DSPI_DCTAR_PASC_1CLK    (0x00000000)
#define MCF_DSPI_DCTAR_PASC_3CLK    (0x00100000)
#define MCF_DSPI_DCTAR_PASC_5CLK    (0x00200000)
#define MCF_DSPI_DCTAR_PASC_7CLK    (0x00300000)
#define MCF_DSPI_DCTAR_PDT_1CLK     (0x00000000)
#define MCF_DSPI_DCTAR_PDT_3CLK     (0x00040000)
#define MCF_DSPI_DCTAR_PDT_5CLK     (0x00080000)
#define MCF_DSPI_DCTAR_PDT_7CLK     (0x000A0000)
#define MCF_DSPI_DCTAR_PBR_1CLK     (0x00000000)
#define MCF_DSPI_DCTAR_PBR_3CLK     (0x00010000)
#define MCF_DSPI_DCTAR_PBR_5CLK     (0x00020000)
#define MCF_DSPI_DCTAR_PBR_7CLK     (0x00030000)

/* Bit definitions and macros for MCF_DSPI_DSR */
#define MCF_DSPI_DSR_RXPTR(x)       (((x)&0x0000000F)<<0)
#define MCF_DSPI_DSR_RXCTR(x)       (((x)&0x0000000F)<<4)
#define MCF_DSPI_DSR_TXPTR(x)       (((x)&0x0000000F)<<8)
#define MCF_DSPI_DSR_TXCTR(x)       (((x)&0x0000000F)<<12)
#define MCF_DSPI_DSR_RFDF           (0x00020000)
#define MCF_DSPI_DSR_RFOF           (0x00080000)
#define MCF_DSPI_DSR_TFFF           (0x02000000)
#define MCF_DSPI_DSR_TFUF           (0x08000000)
#define MCF_DSPI_DSR_EOQF           (0x10000000)
#define MCF_DSPI_DSR_TXRXS          (0x40000000)
#define MCF_DSPI_DSR_TCF            (0x80000000)

/* Bit definitions and macros for MCF_DSPI_DIRSR */
#define MCF_DSPI_DIRSR_RFDFS        (0x00010000)
#define MCF_DSPI_DIRSR_RFDFE        (0x00020000)
#define MCF_DSPI_DIRSR_RFOFE        (0x00080000)
#define MCF_DSPI_DIRSR_TFFFS        (0x01000000)
#define MCF_DSPI_DIRSR_TFFFE        (0x02000000)
#define MCF_DSPI_DIRSR_TFUFE        (0x08000000)
#define MCF_DSPI_DIRSR_EOQFE        (0x10000000)
#define MCF_DSPI_DIRSR_TCFE         (0x80000000)

/* Bit definitions and macros for MCF_DSPI_DTFR */
#define MCF_DSPI_DTFR_TXDATA(x)     (((x)&0x0000FFFF)<<0)
#define MCF_DSPI_DTFR_CS0           (0x00010000)
#define MCF_DSPI_DTFR_CS2           (0x00040000)
#define MCF_DSPI_DTFR_CS3           (0x00080000)
#define MCF_DSPI_DTFR_CS5           (0x00200000)
#define MCF_DSPI_DTFR_CTCNT         (0x04000000)
#define MCF_DSPI_DTFR_EOQ           (0x08000000)
#define MCF_DSPI_DTFR_CTAS(x)       (((x)&0x00000007)<<28)
#define MCF_DSPI_DTFR_CONT          (0x80000000)

/* Bit definitions and macros for MCF_DSPI_DRFR */
#define MCF_DSPI_DRFR_RXDATA(x)     (((x)&0x0000FFFF)<<0)

/* Bit definitions and macros for MCF_DSPI_DTFDR */
#define MCF_DSPI_DTFDR_TXDATA(x)    (((x)&0x0000FFFF)<<0)
#define MCF_DSPI_DTFDR_TXCMD(x)     (((x)&0x0000FFFF)<<16)

/* Bit definitions and macros for MCF_DSPI_DRFDR */
#define MCF_DSPI_DRFDR_RXDATA(x)    (((x)&0x0000FFFF)<<0)

/********************************************************************/

#endif /* __MCF548X_DSPI_H__ */
