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

#define TOS4_SIZE	(512*1024)	// 512 KB

#define FLASH_ADR	0x00E00000	// TOS area (2x512 KB)
#define FLASH_SIZE  (1024*1024)	// 1MB
#define TESTS_SIZE  (128*1024)	// 128 KB
#define PARAM_SIZE	(64*1024)	// 64 KB

#define FLASH_ADR2  0x00FC0000	// TOS 1.x area (192 KB)
#define FLASH_SIZE2 (192*1024)	// 192 KB

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <time.h>

#include "endianness.h"
#include "tos_addr.h"

static void showHelp( const char* sProgramName )
{
	fprintf( stderr, "%s [--help] --tos <path> --tospatch <path> [--tests <path>] [--pci <path>] --out <path>\n", sProgramName );
	fprintf( stderr, "--help:     this help\n" );
	fprintf( stderr, "--tos:      path to unmodified TOS 4.04 image\n" );
	fprintf( stderr, "--tospatch: path to binary with TOS patches\n" );
	fprintf( stderr, "--tests:    path to binary with tests  (optional)\n" );
	fprintf( stderr, "--pci:      path to PCI hex file (optional)\n" );
	fprintf( stderr, "--out:      path to final TOS image\n" );
}

static void waitAndExit( void )
{
	fprintf( stderr, "Press Enter to exit.\n" );
	getchar();
	exit( 1 );
}

static void showError( const char* fmt, ... )
{
	va_list argptr;

	va_start( argptr, fmt );
	fprintf( stderr, "Error: " );
	vfprintf( stderr, fmt, argptr );
	fprintf( stderr, "\n" );
	va_end( argptr );

	waitAndExit();
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

static void loadFile( const char* sPath, void* pBuffer, size_t bufferSize, size_t expectedSize )
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
}

static size_t patchTos( unsigned char* pTos, const unsigned char* pPatches )
{
	int year;

	unsigned char* p;
	unsigned long  len;

	time_t timeSec;
	time( &timeSec );
	struct tm* pTime = localtime( &timeSec );

	// write new TOS date ...
	pTos[24] = (unsigned char)( ( ( pTime->tm_mon / 10 ) << 4 ) + ( pTime->tm_mon % 10 ) );
	pTos[25] = (unsigned char)( ( ( pTime->tm_mday / 10 ) << 4 ) + ( pTime->tm_mday % 10 ) );

	year = ( pTime->tm_year + 1900 ) / 100;
	pTos[26] = (unsigned char)( ( ( year / 10 ) << 4 ) + ( year % 10 ) );
	year = ( pTime->tm_year + 1900 ) % 100;
	pTos[27] = (unsigned char)( ( ( year / 10 ) << 4 ) + ( year % 10 ) );

	// patch TOS ... input buffer consists of 4-byte aligned blocks with header:
	// .long target_address
	// .long length
	// if bit 31 of length is set, then first instruction is jmp/jsr <2nd flash area address>
	// if bit 31 and 30 of length is set, then first long is a vector to 2nd flash area
	do
	{
		// beware, not x64 friendly!
		p = &pTos[BE32( *(unsigned long*)pPatches )];
		pPatches += sizeof( unsigned long* );

		len = BE32( *(unsigned long*)pPatches );
		pPatches += sizeof( len );

		if( len & 0x80000000 )
		{
			unsigned long* pl;
			unsigned long  l;

			len &= 0x7FFFFFFF;

			if( len & 0x40000000 )
			{
				len &= 0x3FFFFFFF;

				pl = (unsigned long*)pPatches;
			}
			else
			{
				pl = (unsigned long*)( pPatches + 2 );	// skip jmp/jsr instruction
			}
			// new address = <address of 2nd flash area> + function offset
			// 0xe4 is an offset introduced by m68k-atari-mint-ld
			l = BE32( *pl );
			l = 0xE80000 + ( l - (unsigned long)ct60tos_half_flash ) +  ct60tos_patch;
			*pl = BE32( l );
		}
		memcpy( p, pPatches, len );
		p += len;
		pPatches += len;

		if( (unsigned long)pPatches & 3 )
		{
			pPatches = (unsigned char*)( ( (unsigned long)pPatches & 0xFFFFFFFC ) + 4 );
		}
	}
	while( *(unsigned long*)pPatches != 0xffffffff );
}

int main( int argc, char* argv[] )
{
	int i;

	char*          sPathTos = NULL;
	char*	sPathTosPatches = NULL;
	char*        sPathTests = NULL;
	char*          sPathPci = NULL;
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
		else if( strcmp( "--pci", argv[i] ) == 0 )
		{
			if( ++i < argc )
			{
				sPathPci = argv[i];
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
			waitAndExit();
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

	pBufferPatches = allocMemory( FLASH_SIZE - PARAM_SIZE );
	loadFile( sPathTosPatches, pBufferPatches, FLASH_SIZE - PARAM_SIZE, -1 );

	patchTos( pBufferFlash, pBufferPatches );

	return 0;
}
