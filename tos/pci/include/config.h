#ifndef _CONFIG_H_
#define _CONFIG_H_

/* DEBUG */
#define DEBUG

/* DBUG */
#define DBUG

/* PCI XBIOS */
#undef PCI_XBIOS              /* faster by cookie */

/* NETWORK */
#ifdef COLDFIRE
#define NETWORK
#define ETHERNET_PORT 0       /* FEC channel */
#undef TEST_NETWORK
#undef DEBUG_PRINT
#define LWIP
#define WEB_LIGHT
#define ERRNO
#define MCD_PROGQUERY
#undef MCD_DEBUG

#ifdef MCF5445X               /* target untested */
#ifndef LWIP
#undef NETWORK                /* to do */
#endif
#endif

/* BDOS */
#define NEWCODE
#endif /* COLDFIRE */

/* fVDI */
#ifndef COLDFIRE
#undef TEST_NOPCI
#endif

/* X86 emulator */
#undef DEBUG_X86EMU
#undef DEBUG_X86EMU_PCI
#define __BIG_ENDIAN__
#define NO_LONG_LONG

/* Radeon */
#define DEFAULT_MONITOR_LAYOUT "TMDS,CRT"
#define ATI_LOGO
#define CONFIG_FB_RADEON_I2C
#define CONFIG_FB_MODE_HELPERS
#undef RADEON_TILING /* normally faster but tile 16 x 16 not compatible with accel.c read_pixel, blit/expand_area and writes on screen frame buffer */
#undef RADEON_THEATRE /* unfinished */

/* VIDIX */
#undef VIDIX_FILTER
#undef VIDIX_ENABLE_BM /* unfinished */

/* AC97 */
#define SOUND_AC97

/* USB */
#define USB_DEVICE

#endif /* _CONFIG_H_ */
