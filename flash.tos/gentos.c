/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <time.h>
#include <stdint.h>

#include "ct60_hw.h"
#include "endianness.h"

static void showHelp( const char* sProgramName )
{
	fprintf( stderr, "%s [--help] --tos <path> --tospatch <path> [--tests <path>] --out <path>\n", sProgramName );
	fprintf( stderr, "--help:     this help\n" );
	fprintf( stderr, "--tos:      path to unmodified TOS 4.04 image\n" );
	fprintf( stderr, "--tospatch: path to binary with TOS patches\n" );
	fprintf( stderr, "--tests:    path to binary with tests (optional)\n" );
	fprintf( stderr, "--out:      path to final TOS image\n" );
}

static void showError( const char* fmt, ... )
{
	va_list argptr;

	va_start( argptr, fmt );
	fprintf( stderr, "Error: " );
	vfprintf( stderr, fmt, argptr );
	fprintf( stderr, "\n" );
	va_end( argptr );

	exit( 1 );
}

static void* allocMemory( size_t size )
{
	void* p = malloc( size );
	if( p == NULL )
	{
		showError( "Not enough memory for allocating %d bytes!", size );
	}

	return p;
}

static size_t fileSize( const char* sPath )
{
	size_t	size = 0;
	FILE*	pFs;

	pFs = fopen( sPath, "rb" );
	if( pFs != NULL )
	{
		fseek( pFs, 0, SEEK_END );
		size = ftell( pFs );

		fclose( pFs );
	}

	return size;
}

static size_t loadFile( const char* sPath, void* pBuffer, size_t bufferSize, size_t expectedSize )
{
	size_t readBytes;

	FILE* pFs = fopen( sPath, "rb" );
	if( pFs == NULL )
	{
		showError( "Unable to open file %s!", sPath );
	}

	readBytes = fread( pBuffer, 1, bufferSize, pFs );
	if( expectedSize != -1 && readBytes != expectedSize )
	{
		showError( "File size for '%s' is %d instead of %d!",
			   sPath, readBytes, expectedSize );
	}

	fclose( pFs );

	return readBytes;
}

static size_t saveFile( const char* sPath, const void* pBuffer, size_t bufferSize )
{
	size_t writeBytes;

	FILE* pFs = fopen( sPath, "wb" );
	if( pFs == NULL )
	{
		showError( "Unable to open file %s!", sPath );
	}

	writeBytes = fwrite( pBuffer, 1, bufferSize, pFs );
	if( writeBytes != bufferSize )
	{
		showError( "Failed to write %d bytes, disk full?", bufferSize );
	}

	fclose( pFs );

	return writeBytes;
}

static void patchTosDate( unsigned char* pTos )
{
	int year;
	time_t timeSec;
	struct tm* pTime;
	
	time( &timeSec );
	pTime = localtime( &timeSec );

	// write new TOS date ...
	pTos[24] = (unsigned char)1+( ( ( pTime->tm_mon / 10 ) << 4 ) + ( pTime->tm_mon % 10 ) );
	pTos[25] = (unsigned char)( ( ( pTime->tm_mday / 10 ) << 4 ) + ( pTime->tm_mday % 10 ) );

	year = ( pTime->tm_year + 1900 ) / 100;
	pTos[26] = (unsigned char)( ( ( year / 10 ) << 4 ) + ( year % 10 ) );
	year = ( pTime->tm_year + 1900 ) % 100;
	pTos[27] = (unsigned char)( ( ( year / 10 ) << 4 ) + ( year % 10 ) );
}

// not very nice but comfortable ;)
static uint32_t startAddress;
static uint32_t endAddress;

static void patchImage( unsigned char* pImage, const unsigned char* pPatches )
{
	startAddress	= 0xFFFFFFFF;
	endAddress		= 0;

	// patch image ... input buffer consists of 4-byte aligned blocks with header:
	// .long target_address
	// .long length
	do
	{
		unsigned char* p;
		uint32_t len;
		uint32_t addr;

		addr = BE32( *(uint32_t*)pPatches );
		pPatches += sizeof( addr );

		len = BE32( *(uint32_t*)pPatches );
		pPatches += sizeof( len );

//		printf("addr=%08x, len=%08x\n",addr,len);
		
		// check / set VMA ranges ...
		startAddress = addr < startAddress ? addr : startAddress;
		endAddress = ( addr + len ) > endAddress ? ( addr + len ) : endAddress;

		if( addr >= FLASH_ADR2 )
		{
			fprintf( stderr, "Forcing compression of PCI image ...\n" );
		}
		if( addr >= FLASH_ADR )
		{
			// our index 0 begins at FLASH_ADR ...
			addr -= FLASH_ADR;
		}

		p = &pImage[addr];

		memcpy( p, pPatches, len );
		p += len;
		pPatches += len;

		if( (uintptr_t)pPatches & 3 )
		{
			pPatches = (unsigned char*)( ( (uintptr_t)pPatches & ~3 ) + 4 );
		}
	}
	while( *(uint32_t*)pPatches != 0xffffffff );
}

static void createTosChecksum( unsigned char* pBuffer )
{
	unsigned short crc;
	unsigned short crc2;
	int i;

	static unsigned short crctab[256] =
	{
		0x0000,0x1021,0x2042,0x3063,0x4084,0x50a5,0x60c6,0x70e7,
		0x8108,0x9129,0xa14a,0xb16b,0xc18c,0xd1ad,0xe1ce,0xf1ef,
		0x1231,0x0210,0x3273,0x2252,0x52b5,0x4294,0x72f7,0x62d6,
		0x9339,0x8318,0xb37b,0xa35a,0xd3bd,0xc39c,0xf3ff,0xe3de,
		0x2462,0x3443,0x0420,0x1401,0x64e6,0x74c7,0x44a4,0x5485,
		0xa56a,0xb54b,0x8528,0x9509,0xe5ee,0xf5cf,0xc5ac,0xd58d,
		0x3653,0x2672,0x1611,0x0630,0x76d7,0x66f6,0x5695,0x46b4,
		0xb75b,0xa77a,0x9719,0x8738,0xf7df,0xe7fe,0xd79d,0xc7bc,
		0x48c4,0x58e5,0x6886,0x78a7,0x0840,0x1861,0x2802,0x3823,
		0xc9cc,0xd9ed,0xe98e,0xf9af,0x8948,0x9969,0xa90a,0xb92b,
		0x5af5,0x4ad4,0x7ab7,0x6a96,0x1a71,0x0a50,0x3a33,0x2a12,
		0xdbfd,0xcbdc,0xfbbf,0xeb9e,0x9b79,0x8b58,0xbb3b,0xab1a,
		0x6ca6,0x7c87,0x4ce4,0x5cc5,0x2c22,0x3c03,0x0c60,0x1c41,
		0xedae,0xfd8f,0xcdec,0xddcd,0xad2a,0xbd0b,0x8d68,0x9d49,
		0x7e97,0x6eb6,0x5ed5,0x4ef4,0x3e13,0x2e32,0x1e51,0x0e70,
		0xff9f,0xefbe,0xdfdd,0xcffc,0xbf1b,0xaf3a,0x9f59,0x8f78,
		0x9188,0x81a9,0xb1ca,0xa1eb,0xd10c,0xc12d,0xf14e,0xe16f,
		0x1080,0x00a1,0x30c2,0x20e3,0x5004,0x4025,0x7046,0x6067,
		0x83b9,0x9398,0xa3fb,0xb3da,0xc33d,0xd31c,0xe37f,0xf35e,
		0x02b1,0x1290,0x22f3,0x32d2,0x4235,0x5214,0x6277,0x7256,
		0xb5ea,0xa5cb,0x95a8,0x8589,0xf56e,0xe54f,0xd52c,0xc50d,
		0x34e2,0x24c3,0x14a0,0x0481,0x7466,0x6447,0x5424,0x4405,
		0xa7db,0xb7fa,0x8799,0x97b8,0xe75f,0xf77e,0xc71d,0xd73c,
		0x26d3,0x36f2,0x0691,0x16b0,0x6657,0x7676,0x4615,0x5634,
		0xd94c,0xc96d,0xf90e,0xe92f,0x99c8,0x89e9,0xb98a,0xa9ab,
		0x5844,0x4865,0x7806,0x6827,0x18c0,0x08e1,0x3882,0x28a3,
		0xcb7d,0xdb5c,0xeb3f,0xfb1e,0x8bf9,0x9bd8,0xabbb,0xbb9a,
		0x4a75,0x5a54,0x6a37,0x7a16,0x0af1,0x1ad0,0x2ab3,0x3a92,
		0xfd2e,0xed0f,0xdd6c,0xcd4d,0xbdaa,0xad8b,0x9de8,0x8dc9,
		0x7c26,0x6c07,0x5c64,0x4c45,0x3ca2,0x2c83,0x1ce0,0x0cc1,
		0xef1f,0xff3e,0xcf5d,0xdf7c,0xaf9b,0xbfba,0x8fd9,0x9ff8,
		0x6e17,0x7e36,0x4e55,0x5e74,0x2e93,0x3eb2,0x0ed1,0x1ef0
	};

	for( i = 0, crc = 0; i < FLASH_SIZE/2 - 2; i++ )
	{
		crc2 = crctab[pBuffer[i] ^ (unsigned char)( crc >> 8 )];
		crc <<= 8;
		crc ^= crc2;
	}
	pBuffer[i++] = (unsigned char)( crc >> 8 );
	pBuffer[i]   = (unsigned char)( crc      );
}

int main( int argc, char* argv[] )
{
	int i;

	size_t flashSize;

	char*          sPathTos = NULL;
	char*	sPathTosPatches = NULL;
	char*        sPathTests = NULL;
	char*          sPathOut = NULL;

	unsigned char* pBufferFlash;
	unsigned char* pBufferPatches;

	for( i = 1; i < argc; ++i )
	{
		if( strcmp( "--tos", argv[i] ) == 0 )
		{
			if( ++i < argc )
			{
				sPathTos = argv[i];
				continue;
			}
		}
		else if( strcmp( "--tospatch", argv[i] ) == 0 )
		{
			if( ++i < argc )
			{
				sPathTosPatches = argv[i];
				continue;
			}
		}
		else if( strcmp( "--tests", argv[i] ) == 0 )
		{
			if( ++i < argc )
			{
				sPathTests = argv[i];
				continue;
			}
		}
		else if( strcmp( "--out", argv[i] ) == 0 )
		{
			if( ++i < argc )
			{
				sPathOut = argv[i];
				continue;
			}
		}
		else
		{
			showHelp( argv[0] );
			getchar();
			exit( 1 );
		}
	}

	if( sPathTos == NULL )
	{
		showHelp( argv[0] );
		showError( "Path to TOS image is missing!" );
	}
	else if( sPathTosPatches == NULL )
	{
		showHelp( argv[0] );
		showError( "Path to TOS patches is missing!" );
	}
	else if( sPathOut == NULL )
	{
		showHelp( argv[0] );
		showError( "Output path is missing!" );
	}

	pBufferFlash = allocMemory( FLASH_SIZE - PARAM_SIZE );
	memset( pBufferFlash, 0xff, FLASH_SIZE - PARAM_SIZE );
	loadFile( sPathTos, pBufferFlash, FLASH_SIZE - PARAM_SIZE, TOS4_SIZE );
	if( pBufferFlash[2] != 0x04 || pBufferFlash[3] != 0x04 )
	{
		showError( "File '%s' is not a valid TOS 4.04 image!", sPathTos );
	}

	if( fileSize( sPathTosPatches ) > FLASH_SIZE - PARAM_SIZE )
	{
		showError( "File '%s' is too big.", sPathTosPatches );
	}
	pBufferPatches = allocMemory( FLASH_SIZE - PARAM_SIZE );
	loadFile( sPathTosPatches, pBufferPatches, FLASH_SIZE - PARAM_SIZE, -1 );

	patchTosDate( pBufferFlash );
	patchImage( pBufferFlash, pBufferPatches );

	flashSize = endAddress - FLASH_ADR;	// file size = 0 ... end address-1
	flashSize = TOS4_SIZE > flashSize ? TOS4_SIZE : flashSize;	// in case we patch only some small portions of original TOS
	if( flashSize >= FLASH_SIZE - PARAM_SIZE )
	{
		showError( "CT60 TOS loads too high in flash memory." );
	}

	createTosChecksum( pBufferFlash );

	if( sPathTests != NULL )
	{
		if( flashSize >= FLASH_SIZE - PARAM_SIZE - TESTS_SIZE )
		{
			showError( "TOS with patches takes 0x%x bytes, no space for tests, missing %d bytes",
					   flashSize, flashSize -( FLASH_SIZE - PARAM_SIZE - TESTS_SIZE ) );
		}
		else
		{
			// patched TOS image             + FLASH_ADR
			// new code                      | [+TOS4_SIZE]
			// (possible empty space)        | [+flashSize - TOS4_SIZE]
			// tests (max TESTS_SIZE bytes)  |
			// params                        | [+TESTS_SIZE]
			// end of flash                  + [+PARAM_SIZE]

			size_t testsSize;

			if( fileSize( sPathTests ) > TESTS_SIZE )
			{
				showError( "File '%s' is too big.", sPathTosPatches );
			}
			testsSize = loadFile( sPathTests, &pBufferFlash[FLASH_SIZE-PARAM_SIZE-TESTS_SIZE], TESTS_SIZE, -1 );
			// use testsSize instead of TESTS_SIZE because testsSize <= TESTS_SIZE
			flashSize = FLASH_SIZE - PARAM_SIZE - TESTS_SIZE + testsSize;
		}
	}


	saveFile( sPathOut, pBufferFlash, flashSize );

	return 0;
}
