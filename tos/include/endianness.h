#ifndef ENDIANNESS_H_
#define ENDIANNESS_H_

#define SWAP16( x ) \
	((((x)>>8)&0x00ff) | ((x)<<8))
#define SWAP32( x ) \
	((((x)>>24)&0x000000ff) | (((x)<<8)&0x00ff0000) | \
	(((x)>> 8)&0x0000ff00) | ((x)<<24))

#ifdef ATARI
#define BE16( x )	( x )
#define BE32( x )	( x )
#define LE16		SWAP16
#define LE32		SWAP32
#else
#define BE16		SWAP16
#define BE32		SWAP32
#define LE16( x )	( x )
#define LE32( x )	( x )
#endif

#endif
