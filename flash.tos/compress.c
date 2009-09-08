#include <osbind.h>
#include <string.h>
#include <stdio.h>
#include "lz.h"

int main(int argc, char **argv)
{
	char *sbuf,*dbuf;
	int *work;
	long length, clength;
	short handle;
	if(argc!=3)
	{
		printf("Usage: compress input output\r\n");
		return(-1);
	}
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
	sbuf = (char *)Mxalloc(length, 2);
	work = (int *)Mxalloc(sizeof(int)*(length+65536), 2);
	dbuf = (char *)Mxalloc(length*11/10, 2);
	if(sbuf == NULL || work == NULL || dbuf == NULL)
		goto error;
	if(Fread(handle, length, sbuf) != length)
		goto error;
	Fclose(handle);
	handle=Fcreate(argv[2], 0);
	if(handle < 0)
	{
error:
		if(sbuf)
			Mfree(sbuf);
		if(work)
			Mfree(work);
		if(dbuf)
			Mfree(dbuf);
		if(handle >= 0)
			Fclose(handle);
		return(-1);
	}
  *(long *)dbuf = (long)length;
	clength = (long)LZ_CompressFast(sbuf, dbuf+4, (int)length, work) + 4;
	printf("compress %s (%d) to %s (%d)\r\n", argv[1], (int)length, argv[2], (int)clength);
	if(Fwrite(handle, clength, dbuf) != clength)
		goto error;
	Fclose(handle);
	Mfree(sbuf);
	Mfree(work);
	Mfree(dbuf);
	return(0);
}
