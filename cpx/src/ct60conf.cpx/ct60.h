
#define ID_CT60 (long)'CT60'
#define MSG_CT60_TEMP 0xcc60
#define CT60_CELCIUS 0
#define CT60_FARENHEIT 1
#define CT60_MODE_READ 0
#define CT60_MODE_WRITE 1
#define CT60_PARAM_TOSRAM 0L
#define CT60_PARAM_OFFSET_TLV 10L

#define ct60_read_core_temperature(type_deg) (long)xbios(0xc60a,(WORD)type_deg)
#define ct60_rw_parameter(mode,type_param,value) (long)xbios(0xc60b,(WORD)mode,(long)type_param,(long)value)
#define ct60_cache(cache_mode) (long)xbios(0xc60c,(WORD)cache_mode)
#define ct60_flush_cache() (long)xbios(0xc60d)
