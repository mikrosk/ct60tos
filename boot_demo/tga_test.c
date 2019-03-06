#include <osbind.h>
#include "pic_boot.h"

extern void tga_conv(unsigned char *target, unsigned char *source, long orientation);
extern int read_tga(unsigned char *dest, unsigned char *source, long size_source);

unsigned char buffer[320*240*3];

void demo(void)
{
	unsigned short *adr;
	int x,y,orientation;
	if((orientation=read_tga(buffer,picture,len_picture))!=0)
		tga_conv(Physbase(),buffer,(long)orientation);
	else /* error */
	{
		adr=Physbase();
		for(y=0; y<240; y++)
			for(x=0; x<320; *adr++ = ((x/5)<<5)+((y/8)<<11), x++);
	}
}

