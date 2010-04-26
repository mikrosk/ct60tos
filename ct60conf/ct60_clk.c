	
/* CT60 CLK MODEM2 programming  - Pure C */
/* Didier MEQUIGNON - February 2005 */

#include <tos.h>
#include <stdio.h>
#include "ct60ctcm.h"

/* #define DEBUG */

typedef struct
{
	long ident;
	union
	{
		long l;
		short i[2];
		char c[4];
	} v;
} COOKIE;

#if 0
unsigned char CY27EE16[256*2]= {
0x00,0x00,0x00,0x00,0x00,0x08,0x34,0x08,0x5a,0x6f,0x00,0x14,0x04,0x00,0x08,0x88,
0x50,0x0C,0x2a,0x6b,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
0xd0,0x24,0x00,0x00,0xff,0xfe,0x7f,0x04,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,
0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,
0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,
0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,
0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,
0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,
0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,
0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,0x10,0x32,
};
#endif

/* prototypes */

void scan_i2c(void);
void test_i2c(void);
COOKIE *fcookie(void);
COOKIE *ncookie(COOKIE *p);
COOKIE *get_cookie(long id);
extern long ct60_read_clock(void);
extern int ct60_configure_clock(unsigned long frequency,int mode);
extern void tempo_20ms(void);
extern int ct60_read_info_clock(unsigned char *buffer);
extern int read_seq_device_i2c(long device_address,int len,unsigned char *buffer);
extern int write_seq_device_i2c(long device_address,int len,unsigned char *buffer);
extern long ct60_rw_clock(int mode,int address,int data);
extern int read_i2c(long device_address);
extern int write_i2c(long device_address,int data);

unsigned long cpu_cookie=0;

int main(void)

{
	long frequency;
	int i,err;
	COOKIE *p;
	char *ptr;
	Cconws("\r\n\n");
	Cconout(27);
	Cconws("p CT60 CLK programming v1.03a ");
	Cconout(27);
	Cconws("q March 2005\r\n");
    {
		if(((p=get_cookie('_MCH'))==0) || (p->v.l!=0x30000))		/* Falcon */
		{
			Cconws("This computer isn't a FALCON 030\r\n");
			return(0);
		}
	}
	if(cpu_cookie==0 && (p=get_cookie('_CPU'))!=0)
		cpu_cookie=p->v.l;
	cpu_cookie=0;
	if(cpu_cookie==60)
		printf("\r\nScan I2C...");
	else
		printf("\r\nScan I2C from MODEM2...");
	scan_i2c();
	printf("\r\n\nCT60 clock frequency: ");
	frequency=ct60_read_clock();
	if(frequency<0)
		printf("no answer");
	else
	{
		printf("%ld KHz",frequency);
		frequency=66600;
		printf("\r\nProgramming in EEPROM %ld KHz",frequency);
		err=ct60_configure_clock(frequency,CT60_CLOCK_WRITE_EEPROM);
#if 0
		for(frequency=105500;frequency>=65900;frequency-=100)
		{
		printf("\r\nProgramming in RAM %ld KHz",frequency);
		err=ct60_configure_clock(frequency,CT60_CLOCK_WRITE_RAM);
#endif
		switch(err)
		{
			case -1: printf("\r\nNo answer"); break;
			case CT60_CALC_CLOCK_ERROR: printf("\r\nFrequency error"); break;
			default: printf("\r\nOK");break;
		}
#if 0
			{
			long stack;
			stack=Super(0L);
			tempo_20ms();
			Super((void *)stack);
			}
		}
#endif
	}	
	Cconin();	
	return(0);
}

void scan_i2c(void)

{
	int i,val,dev;
	long stack;
	stack=Super(0L);
	for(dev=i=0;dev<128;dev++)
	{
		if((val=read_i2c(0xEL+(((long)dev)<<16)))>=0)
		{
			printf("\r\nFound I2C device $%02x (byte $0E: $%02x)",dev,val); 		
			i++;
		}
	}
	if(i==0)
		printf("\r\nNo I2C devices found");
	Super((void *)stack);
}

void test_i2c()

{
	int i,val,dev;
	long stack;
	stack=Super(0L);
#if 0
	for(dev=0x40;dev<=0x47;dev++)
	{
		printf("\r\nDevice %02x",dev);
		for(i=0;i<256;i++)
		{
			if((val=read_i2c((long)i+(((long)dev)<<16)))<0)
			{
				printf("\r\nError reading device %02x address %02x",dev,i);
				break;
			}
			else
			{
				if((i&15)==0)
					printf("\r\n");
				printf("%02x ",val);	
			}
		}
	}
#endif
	for(dev=0x68;dev<=0x69;dev++)
	{
		printf("\r\nDevice %02x",dev);
#if 0
		for(i=0;i<256;i++)
		{
			if(write_i2c((long)i+(((long)dev)<<16),CY27EE16[i])<0)
			{
				printf("\r\nError writing device %02x address %02x",dev,i);
				break;
			}
			tempo_20ms();
		}
#endif
		for(i=0;i<256;i++)
		{
			if((val=read_i2c((long)i+(((long)dev)<<16)))<0)
			{
				printf("\r\nError reading device %02x address %02x",dev,i);
				break;
			}
			else
			{
				if((i&15)==0)
					printf("\r\n");
				printf("%02x ",val);	
			}
		}
	}
#if 0
	if(write_i2c(0x690000,0x80)<0) /* reset */
		printf("\r\nError writing device");
	tempo_20ms();
#endif
	Super((void *)stack);
}

COOKIE *fcookie(void)

{
	COOKIE *p;
	long stack;
	stack=Super(0L);
	p=*(COOKIE **)0x5a0;
	Super((void *)stack);
	if(!p)
		return((COOKIE *)0);
	return(p);
}

COOKIE *ncookie(COOKIE *p)

{
	if(!p->ident)
		return(0);
	return(++p);
}

COOKIE *get_cookie(long id)

{
	COOKIE *p;
	p=fcookie();
	while(p)
	{
		if(p->ident==id)
			return p;
		p=ncookie(p);
	}
	return((COOKIE *)0);
}

