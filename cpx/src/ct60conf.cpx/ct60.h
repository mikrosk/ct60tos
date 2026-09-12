
#define ID_CT60 (long)'CT60'
#define MSG_CT60_TEMP 0xcc60
#define CT60_CELCIUS 0
#define CT60_FARENHEIT 1
#define CT60_MODE_READ 0
#define CT60_MODE_WRITE 1
#define CT60_PARAM_TOSRAM 0L
#define CT60_BLITTER_SPEED 1L
#define CT60_BOOT_ORDER 3L
#define CT60_CPU_FPU 4L
#define CT60_BOOT_LOG 5L
#define CT60_SAVE_NVRAM_1 7L
#define CT60_SAVE_NVRAM_2 8L
#define CT60_SAVE_NVRAM_3 9L
#define CT60_PARAM_OFFSET_TLV 10L
#define CT60_ABE_CODE 11L
#define CT60_SDR_CODE 12L
#define CT60_CLOCK 13L

/* SuperVidel settings, written by the CT60 CPX and read by the SuperVidel
   driver. They mirror the keys of the driver's SV.INF. */

#define CT60_SV_AES_MODES 2L    /* default mode code << 16 | forced mode code */
#define CT60_SV_CONFIG 6L       /* boot mode code << 16 | the flags below */
#define CT60_SV_RESTRICT 14L    /* VDI width << 16 | VDI height, 0 for no limit */

#define CT60_SV_BPS8C 0x0001         /* 8 bit chunky in the TOS VDI */
#define CT60_SV_BPS32 0x0002         /* 32 bit true colour in the TOS VDI */
#define CT60_SV_CLONE 0x0004         /* screen sent to both outputs at once */
#define CT60_SV_REZDIALOG 0x0008     /* extended desktop video dialog */
#define CT60_SV_FAST_VIDEL 0x0010    /* Videl resolutions accelerated in GEM */
#define CT60_SV_KILL_VIDEL 0x0020    /* Videl off in SuperVidel resolutions */
#define CT60_SV_PMMU_BOOST 0x0040    /* higher CPU to VRAM bandwidth */
#define CT60_SV_DVI 0x0080           /* primary output, 0: VGA, 1: DVI */
#define CT60_SV_DUAL 0x0300          /* dual screen, 0: off, 1: vertical, 2: horizontal */
#define CT60_SV_DUAL_SHIFT 8
#define CT60_SV_VERSION 0x1000       /* layout version, 0: never written, 0xf: erased */
#define CT60_SV_VERSION_MASK 0xf000

typedef struct
{
	unsigned short trigger_temp;
	unsigned short daystop;
	unsigned short timestop;
	unsigned short speed_fan;
	unsigned long cpu_frequency; /* in MHz * 10 */
	unsigned short beep;
} CT60_COOKIE;

#define ct60_read_core_temperature(type_deg) (long)xbios(0xc60a,(short)type_deg)
#define ct60_rw_parameter(mode,type_param,value) (long)xbios(0xc60b,(short)mode,(long)type_param,(long)value)
#define ct60_cache(cache_mode) (long)xbios(0xc60c,(short)cache_mode)
#define ct60_flush_cache() (long)xbios(0xc60d)
