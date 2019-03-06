#include <osbind.h>

void demo(void)
{
	unsigned short *adr;
	int x,y;
	adr=Physbase();
	for(y=0; y<240; y++)
		for(x=0; x<320; *adr++ = ((x/5)<<5)+(y/8), x++);
	for(y=0;y<100;Vsync(),y++);
	adr=Physbase();
	for(y=0; y<240; y++)
	{
		Vsync();
		for(x=0; x<320; *adr++ = ((x/5)<<5)+((y/8)<<11), x++);
	}
}

