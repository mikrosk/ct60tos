
#define ID_CT60 (long)'CT60'
#define MSG_CT60_TEMP 0xcc60
#define CT60_CELCIUS 0
#define CT60_FARENHEIT 1
#define CT60_MODE_READ 0
#define CT60_MODE_WRITE 1
#define CT60_PARAM_TOSRAM 0L
#define CT60_BLITTER_SPEED 1L
#define CT60_CACHE_DELAY 2L
#define CT60_BOOT_ORDER 3L
#define CT60_CPU_FPU 4L
#define CT60_SAVE_NVRAM_1 7L
#define CT60_SAVE_NVRAM_2 8L
#define CT60_SAVE_NVRAM_3 9L
#define CT60_PARAM_OFFSET_TLV 10L
#define CT60_ABE_CODE 11L
#define CT60_SDR_CODE 12L
#define CT60_CLOCK 13L

typedef struct
{
	unsigned short trigger_temp;
	unsigned short daystop;
	unsigned short timestop;
	unsigned short speed_fan;
} CT60_COOKIE;

#define ct60_read_core_temperature(type_deg) (long)xbios(0xc60a,(short)type_deg)
#define ct60_rw_parameter(mode,type_param,value) (long)xbios(0xc60b,(short)mode,(long)type_param,(long)value)
#define ct60_cache(cache_mode) (long)xbios(0xc60c,(short)cache_mode)
#define ct60_flush_cache() (long)xbios(0xc60d)
