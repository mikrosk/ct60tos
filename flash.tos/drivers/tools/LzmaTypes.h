/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (c) 1999-2008 Igor Pavlov
 *  Copyright (C) 2008  Free Software Foundation, Inc.
 *
 *  GRUB is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  GRUB is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GRUB.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * This code was taken from LZMA SDK 4.58 beta, and was slightly modified
 * to adapt it to GRUB's requirement.
 *
 * See <http://www.7-zip.org>, for more information about LZMA.
 */

#ifndef __7Z_TYPES_H
#define __7Z_TYPES_H

#define SZ_OK 0

#define SZ_ERROR_DATA 1
#define SZ_ERROR_MEM 2
#define SZ_ERROR_CRC 3
#define SZ_ERROR_UNSUPPORTED 4
#define SZ_ERROR_PARAM 5
#define SZ_ERROR_INPUT_EOF 6
#define SZ_ERROR_OUTPUT_EOF 7
#define SZ_ERROR_READ 8
#define SZ_ERROR_WRITE 9
#define SZ_ERROR_PROGRESS 10
#define SZ_ERROR_FAIL 11
#define SZ_ERROR_THREAD 12

#define SZ_ERROR_ARCHIVE 16
#define SZ_ERROR_NO_ARCHIVE 17

typedef int SRes;

#ifndef RINOK
#define RINOK(x) { int __result__ = (x); if (__result__ != 0) return __result__; }
#endif

typedef unsigned char Byte;
typedef short Int16;
typedef unsigned short UInt16;

typedef int Int32;
typedef unsigned int UInt32;

typedef long long int Int64;
typedef unsigned long long int UInt64;

typedef UInt32 SizeT;

typedef int Bool;
#define True 1
#define False 0
#define MY_CDECL
#define MY_STD_CALL
#define MY_FAST_CALL

/* The following interfaces use first parameter as pointer to structure */

typedef struct
{
  SRes (*Read)(void *p, void *buf, size_t *size);
    /* if (input(*size) != 0 && output(*size) == 0) means end_of_stream.
       (output(*size) < input(*size)) is allowed */
} ISeqInStream;

typedef struct
{
  size_t (*Write)(void *p, const void *buf, size_t size);
    /* Returns: result - the number of actually written bytes.
      (result < size) means error */
} ISeqOutStream;

typedef struct
{
  SRes (*Progress)(void *p, UInt64 inSize, UInt64 outSize);
    /* Returns: result. (result != SZ_OK) means break.
       Value (UInt64)(Int64)-1 for size means unknown value. */
} ICompressProgress;

typedef struct
{
  void *(*Alloc)(void *p, size_t size);
  void (*Free)(void *p, void *address); /* address can be 0 */
} ISzAlloc;

#define IAlloc_Alloc(p, size) (p)->Alloc((p), size)
#define IAlloc_Free(p, a) (p)->Free((p), a)

#endif
