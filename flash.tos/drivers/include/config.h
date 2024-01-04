#ifndef _CONFIG_H_
#define _CONFIG_H_

/* DEBUG */
#define DEBUG

/* DBUG */
#define DBUG

/* PCI XBIOS */
#undef PCI_XBIOS              /* faster by cookie */


//#define LWIP
//#define FREERTOS


/* XBIOS */
#define TOS_ATARI_LOGO        /* defined for use TOS4.04 logo */

/* fVDI */
#define FVDI_STRUCT_2006

/* NVDI */
#define PATCH_NVDI

/* VDI */
#define TOS_TABLES            /* defined for use TOS4.04 index tables */
    
/* X86 emulator */
#undef DEBUG_X86EMU
#undef DEBUG_X86EMU_PCI
#define __BIG_ENDIAN__
#define NO_LONG_LONG

/* Radeon */
#define DEFAULT_MONITOR_LAYOUT ""
#define ATI_LOGO
#define CONFIG_FB_RADEON_I2C
#define CONFIG_FB_MODE_HELPERS
#undef RADEON_TILING /* normally faster but tile 16 x 16 is not compatible with accel.c read_pixel, blit/expand_area and writes on screen frame buffer */
#define RADEON_RENDER
#undef RADEON_THEATRE /* unfinished */
#define RADEON_DIRECT_ACCESS /* MMIO access faster but don't check endian - little -> big conversion !!! */

/* Radeon VIDIX */
#undef VIDIX_FILTER
#undef VIDIX_ENABLE_BM /* unfinished */

/* RTC M5485EVB */
#undef USE_RTC

/* LynxEM M5485EVB */

/* XBIOS Setscreen */
#define MAX_WIDTH_EMU_MONO 1024
#define MAX_HEIGHT_EMU_MONO 768

/* AC97 */
#define SOUND_AC97

/* USB */
#undef USB_DEVICE /* Coldfire USB device */
#define USB_BUFFER_SIZE 0x80000
#undef USE_RADEON_MEMORY
//#define CONFIG_USB_OHCI /* PCI USB 1.1 */
//#define CONFIG_USB_EHCI /* PCI USB 2.0 */
#undef CONFIG_EHCI_DCACHE
#define CONFIG_SYS_OHCI_SWAP_REG_ACCESS
#define CONFIG_SYS_USB_OHCI_MAX_ROOT_PORTS 5
#define CONFIG_SYS_USB_EHCI_MAX_ROOT_PORTS 5
#undef CONFIG_USB_INTERRUPT_POLLING /* CT60 */
#undef CONFIG_LEGACY_USB_INIT_SEQ
#define CONFIG_USB_KEYBOARD
#define CONFIG_USB_MOUSE
#define CONFIG_USB_STORAGE

#endif /* _CONFIG_H_ */
