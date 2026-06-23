#ifndef ENDIANNESS_H_
#define ENDIANNESS_H_

#define SWAP16( x )	__builtin_bswap16( x )
#define SWAP32( x )	__builtin_bswap32( x )

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
