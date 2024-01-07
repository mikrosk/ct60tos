/* 
  LzmaDecode.h
  LZMA Decoder interface

  LZMA SDK 4.21 Copyright (c) 1999-2005 Igor Pavlov (2005-06-08)
  http://www.7-zip.org/

  LZMA SDK is licensed under two licenses:
  1) GNU Lesser General Public License (GNU LGPL)
  2) Common Public License (CPL)
  It means that you can select one of these two licenses and 
  follow rules of that license.

  SPECIAL EXCEPTION:
  Igor Pavlov, as the author of this code, expressly permits you to 
  statically or dynamically link your code (or bind by name) to the 
  interfaces of this file without subjecting your linked code to the 
  terms of the CPL or GNU LGPL. Any modifications or additions 
  to this file, however, are subject to the LGPL or CPL terms.
*/

#ifndef __LZMADECODE_H
#define __LZMADECODE_H

/* #define _LZMA_PROB32 */
/* It can increase speed on some 32-bit CPUs, 
   but memory usage will be doubled in that case */

#ifndef UInt32
#ifdef _LZMA_UINT32_IS_ULONG
#define UInt32 unsigned long
#else
#define UInt32 unsigned int
#endif
#endif

#ifndef SizeT
#define SizeT UInt32
#endif

#ifdef _LZMA_PROB32
#define CProb UInt32
#else
#define CProb unsigned short
#endif

#define LZMA_RESULT_OK 0
#define LZMA_RESULT_DATA_ERROR 1

#define LZMA_BASE_SIZE 1846
#define LZMA_LIT_SIZE 768

#define LZMA_PROPERTIES_SIZE 5

typedef struct _CLzmaProperties
{
  int lc;
  int lp;
  int pb;
} CLzmaProperties;

int LzmaDecodeProperties(CLzmaProperties *propsRes, const unsigned char *propsData);

#define LzmaGetNumProbs(Properties) (LZMA_BASE_SIZE + (LZMA_LIT_SIZE << ((Properties)->lc + (Properties)->lp)))

#define kLzmaNeedInitId (-2)

typedef struct _CLzmaDecoderState
{
  CLzmaProperties Properties;
  CProb *Probs;
} CLzmaDecoderState;

int LzmaDecode(CLzmaDecoderState *vs,
    const unsigned char *inStream, SizeT inSize, SizeT *inSizeProcessed,
    unsigned char *outStream, SizeT outSize, SizeT *outSizeProcessed);

#endif
