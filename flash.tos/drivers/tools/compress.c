#include <mint/osbind.h>
#include <string.h>
#include <stdio.h>
#include "lz.h"
#include "LzmaEnc.h"
#include "../../include/main.h"

extern int srec_read(const char *path);
void *buffer_flash=NULL;
extern unsigned long start_addr,end_addr;

static void *SzAlloc(void *p, size_t size) { p = p; return (void *)Mxalloc(size,3); }
static void SzFree(void *p, void *address) { p = p; if(address != NULL) Mfree(address); }
static ISzAlloc g_Alloc = { SzAlloc, SzFree };

int main(int argc, char **argv)
{
	char *sbuf=NULL,*dbuf=NULL;
	unsigned int *work=NULL;
	long length,clength=0;
	short handle=-1;
	int cf=0;
	unsigned long size_pci_drivers;
	char *buffer_pci_drivers=NULL;
	if(argc!=3)
	{
		printf("Usage: compress input output\r\n");
		return(-1);
	}
	if(strstr(argv[1], "_cf") != NULL)
		cf = 1;
	if(strstr(argv[1], ".hex") != NULL)	
	{
		if((buffer_flash = (char *)Mxalloc(0x200000,3)) == NULL)
		{
			printf("Not enough memory\r\n");
			return(-1);
		}
		memset(buffer_flash, -1, 0x200000);
		if(srec_read(argv[1]))
		{
			printf("Error with HEX file pci drivers\r\n");
			return(-1);
		}
		if((start_addr < FLASH_ADR) || (start_addr >= (FLASH_ADR2+FLASH_SIZE2)))
		{
			printf("Error with HEX file, bad start address\r\n");
			return(-1);
		}
		if((end_addr < FLASH_ADR) || (end_addr >= (FLASH_ADR2+FLASH_SIZE2)))
		{
			printf("Error with HEX file, bad end address\r\n");
			return(-1);
		}
		if(end_addr <= start_addr)
		{
			printf("Error with HEX file, end address < start address\r\n", NULL);
			return(-1);
		}
		if(end_addr >= FLASH_ADR2)
		{
			memcpy(buffer_flash+0x100000,buffer_flash+FLASH_ADR2-FLASH_ADR,end_addr-FLASH_ADR2);
			size_pci_drivers = FLASH_ADR+0x100000-start_addr + end_addr-FLASH_ADR2;
		}
		else
			size_pci_drivers = end_addr-start_addr;
		buffer_pci_drivers = buffer_flash+start_addr-FLASH_ADR;
		if((work = (unsigned int *)Mxalloc(sizeof(int)*(size_pci_drivers+65536),3)) == NULL)
		{
			printf("Not enough memory for compress work buffer\r\n");
			return(-1);
		}
		if((dbuf = (char *)Mxalloc(FLASH_SIZE-PARAM_SIZE,3)) == NULL)
		{
			printf("Not enough memory for target buffer\r\n");
			goto error;
		}		
		printf("compress drivers part %d bytes (0x%08lX-0x%08lX)... \r\n", (int)size_pci_drivers, start_addr, end_addr);
		if(!cf)
		{
			clength = (long)LZ_CompressFast((unsigned char *)buffer_pci_drivers, (unsigned char *)&dbuf[8], (unsigned int)size_pci_drivers, work);
			printf("compress %s (%d) to %s (%d)\r\n", argv[1], (int)size_pci_drivers, argv[2], (int)clength);
		}
		if(cf || ((unsigned long)clength > FLASH_ADR+FLASH_SIZE-PARAM_SIZE-start_addr-8))
		{
			int i;
			SizeT destLen;
			CLzmaEncProps props;
			unsigned char out_props[5];
			SizeT out_props_size = 5;
			SRes rc;
			if(!cf)
				printf("Not enough memory for put compressed drivers in flash in LZ format (0x%lX bytes), try again with LZMA\r\n", clength);
		  LzmaEncProps_Init(&props);
		  props.dictSize = 1 << 16;
		  props.lc = 3;
		  props.lp = 0;
		  props.pb = 2;
		  props.numThreads = 1;
			if((rc = LzmaEncode((unsigned char *)&dbuf[8+LZMA_PROPS_SIZE], &destLen, (unsigned char *)buffer_pci_drivers, size_pci_drivers, &props, out_props, &out_props_size, 1, NULL, &g_Alloc, &g_Alloc)) != SZ_OK)
			{
				printf("LzmaEncode error %d.\r\n", rc);
				goto error;
			}
			printf("compress %s (%d) to %s (%d)\r\n", argv[1], (int)size_pci_drivers, argv[2], (int)destLen);
			if((unsigned long)destLen > FLASH_ADR+FLASH_SIZE-PARAM_SIZE-start_addr-8-LZMA_PROPS_SIZE)
			{
				printf("Not enough memory for put compressed drivers in flash (0x%lX bytes).\r\n", destLen);
				goto error;
			}
			dbuf[0] = 'L'; /* add header */
			dbuf[1] = 'Z';
			dbuf[2] = 'M';
			dbuf[3] = 'A';
			*(long *)&dbuf[4] = destLen;
			for(i = 0; i < LZMA_PROPS_SIZE; dbuf[8 + i] = out_props[i], i++); 
			clength = LZMA_PROPS_SIZE + destLen;
		}
		else
		{
			dbuf[0] = dbuf[3]='_'; /* add header */
			dbuf[1] = 'L';
			dbuf[2] = 'Z';
			*(long *)&dbuf[4] = clength;
		}
		clength += 8;
	}
	else /* binary file */
	{
		handle=Fopen(argv[1], 0);
		if(handle<0)
			return(-1);
		length = Fseek(0, handle, 2);
		if(length <= 0)
		{
			Fclose(handle);
			return(-1);
		}
		Fseek(0, handle, 0);
		sbuf = (char *)Mxalloc(length, 3);
		work = (unsigned int *)Mxalloc(sizeof(int)*(length+65536), 3);
		dbuf = (char *)Mxalloc(length*11/10, 3);
		if(sbuf == NULL || work == NULL || dbuf == NULL)
			goto error;
		if(Fread(handle, length, sbuf) != length)
			goto error;
		Fclose(handle);
	  *(long *)dbuf = (long)length;
		clength = (long)LZ_CompressFast((unsigned char *)sbuf, (unsigned char *)&dbuf[4], (unsigned int)length, work) + 4;
		printf("compress %s (%d) to %s (%d)\r\n", argv[1], (int)length, argv[2], (int)clength);
	}
	handle=Fcreate(argv[2], 0);
	if(handle < 0)
	{
error:
		if(buffer_flash!= NULL)
			Mfree(buffer_flash);
		if(sbuf!=NULL)
			Mfree(sbuf);
		if(work!=NULL)
			Mfree(work);
		if(dbuf!=NULL)
			Mfree(dbuf);
		if(handle >= 0)
			Fclose(handle);
		return(-1);
	}
	if(Fwrite(handle, clength, dbuf) != clength)
	{
		printf("Writing error\r\n");
		goto error;
	}
	Fclose(handle);
	if(buffer_flash!= NULL)
		Mfree(buffer_flash);
	if(sbuf!=NULL)
		Mfree(sbuf);
	if(work!=NULL)
		Mfree(work);
	if(dbuf!=NULL)
		Mfree(dbuf);
	return(0);
}
