/* CT60 programmable clock module */
/* Didier MEQUIGNON - March 2005 / July 2010 */

#include <tos.h>
#include <mt_aes.h>
#include <stdio.h>
#include <stdlib.h>
#include "ct60ctcm.h"

#ifndef NO_GEM
unsigned long step_frequency=125;
#endif

extern int ct60_read_info_clock(unsigned char *buffer);
extern long ct60_rw_clock(int mode,int address,int data);

long ct60_read_clock(void);
int ct60_configure_clock(unsigned long frequency,int mode,int divider);
void tempo_20ms(void);

long ct60_read_clock(void)

{
	int dac,offset;
	long val,offset_def;
	long stack,fos;
	unsigned long p,q,pb,frequency;
	static unsigned char buffer[128];
	stack=Super(0L);
	if((val=ct60_rw_clock(CT60_CLOCK_READ|DALLAS,OFFSET,0))>=0) /* Dallas DS1085 */
	{
		/* frequency = (DEF_FREQ + (OFFSET_STEP * (offset-offset_def)))   */
		/*           - ((DAC_DEF-dac) * DAC_STEP)                         */
#ifndef NO_GEM
		step_frequency=DAC_STEP; /* global for slider */
#endif
		offset=(int)(val&0x1F);
		if((val=ct60_rw_clock(CT60_CLOCK_READ|DALLAS,DACWORD,0))>=0)
		{
			dac=(int)(val>>6);
			if((val=ct60_rw_clock(CT60_CLOCK_READ|DALLAS,RANGEWORD,0))>=0)
			{	
				offset_def=(long)(val>>11);		
				fos=DEF_FREQ+(OFFSET_STEP*((long)offset-offset_def));
				frequency=(unsigned long)(fos-((DAC_DEF-(long)dac)*DAC_STEP));
			}
		}
	}
	else if((val=ct60_rw_clock(CT60_CLOCK_READ|CYPRESS,CLKOE,0))>=0)   /* Cypress CY27EE16 */
	{	
		/* frequency (KHz) = (REF (KHz) * p) / q) / post divider */
		val=ct60_read_info_clock(buffer);
		if(val>=0)
		{
			q=(unsigned long)(buffer[QCOUNTER] & 127)+2;
			p=(unsigned long)buffer[QCOUNTER]>>7;  /* P0 */
			pb=((unsigned long)(buffer[CHARGEP]&3)<<8);
			pb|=(unsigned long)buffer[PBCOUNTER];
			p+=((pb+4)<<1);
			frequency=(REF*p)/q;
			if(p==8 && q==2
			 && buffer[CLKOE]==0 && buffer[DIV1N]==0
			 && buffer[PINCTRL]==0 && buffer[WPREG]==0 && buffer[OSCDRV]==0
			 && buffer[INLOAD]==0 && buffer[ADCREG]==0 && buffer[MATRIX1]==0
			 && buffer[MATRIX2]==0 && buffer[MATRIX3]==0 && buffer[DIV2N]==0)
				val=CT60_NULL_CLOCK_ERROR;
			if((buffer[DIV1N]&0x7F)<4)
				buffer[DIV1N]+=4;
			if((buffer[DIV2N]&0x7F)<4)
				buffer[DIV2N]+=4;
			switch((buffer[MATRIX2]&0x70)>>4) /* clock 4 */
			{
				case 0:
					frequency=REF;
					break;
				case 1:
					if(buffer[DIV1N]&0x80)
						frequency=REF/(buffer[DIV1N]&0x7F);
					else
						frequency/=(buffer[DIV1N]&0x7F);
					break;
				case 2:
					if(buffer[DIV1N]&0x80)
						frequency=REF>>1;
					else
						frequency>>=1;
					break;
				case 3:
					if(buffer[DIV1N]&0x80)
						frequency=REF/3;
					else
						frequency/=3;
					break;
				case 4:
					if(buffer[DIV2N]&0x80)
						frequency=REF/(buffer[DIV2N]&0x7F);
					else
						frequency/=(buffer[DIV2N]&0x7F);
					break;
				case 5:
					if(buffer[DIV2N]&0x80)
						frequency=REF>>1;
					else
						frequency>>=1;
					break;
				case 6:
					if(buffer[DIV2N]&0x80)
						frequency=REF>>2;
					else
						frequency>>=2;
					break;
			}
#ifdef DEBUG
			for(val=0;val<0x48;val++)
			{
				if((val&7)==0)
					printf("\r\n");
				printf("%02x ",buffer[val]);
			}
#endif
		}
	}
	Super((void *)stack);
	if(val<0)
		return(val);
	return((long)frequency);
}

int ct60_configure_clock(unsigned long frequency,int mode,int divider)

{
	int i,adr,mux,dac,offset;
	unsigned char matrix2,matrix3,chargep;
	long error,stack,fos,offset_def;
	unsigned long p,q,pll;
	static unsigned char tab_cy_reg[] = { /* Cypress CY27EE16     */
		CLKOE,0x69,    /* clocks 1, 4, 5, 6                       */
		PINCTRL,0x50,  /* output enable pin                       */
		OSCDRV,0x28,   /* clock REF                               */
		INLOAD,0x6B,   /* capacity load                           */
		ADCREG,0x00,
		MATRIX1,0xB6,  /* clocks 1 to 3 DIV2CLK/2                 */
		DIV2N,0x08,    /* post divider /8                         */
		WPREG,0x1C,    /* write protect soft on, in last position */
		0,0 };
	stack=Super(0L);   /* supervisor mode */
	if((error=ct60_rw_clock(CT60_CLOCK_READ|DALLAS,ADR,0))>=0) /* Dallas DS1085 */
	{
		/* frequency = (DEF_FREQ + (OFFSET_STEP * (offset-offset_def)))   */
		/*           - ((DAC_DEF-dac) * DAC_STEP)                         */
		adr=(int)error;
		if((error=ct60_rw_clock(CT60_CLOCK_READ|DALLAS,RANGEWORD,0))>=0)
		{
			offset_def=(long)(error>>11);
			Super((void *)stack);     /* user mode */
			if(frequency<(MIN_FREQ_DALLAS+300UL)) /* strap on CLK/2 */
				frequency<<=1;
			if(frequency<MIN_FREQ_DALLAS || frequency>MAX_FREQ_DALLAS)
				return(CT60_CALC_CLOCK_ERROR);
			/* MUX : PDN0/1 = 0, SEL0 = 1, EN0 = 0, 0M = 1, 1M = 0, DIV1 = 0  */
			mux=0x1200;
			if((frequency<=66000)||(divider<2))
				divider=2;
			dac=(int)((((long)frequency-DEF_FREQ)/DAC_STEP)+DAC_DEF);
			if(dac<0 || dac>1023)
			{
				offset=(int)(((long)frequency-DEF_FREQ)/OFFSET_STEP);
				if(offset<-6 || offset>6)
					return(CT60_CALC_CLOCK_ERROR);
				offset+=offset_def;
				if(offset<0 || offset>31)
					return(CT60_CALC_CLOCK_ERROR);
				fos=DEF_FREQ+(OFFSET_STEP*((long)offset-offset_def));
				dac=(int)((((long)frequency-fos)/DAC_STEP)+DAC_DEF);
				if(dac<0 || dac>1023)
					return(CT60_CALC_CLOCK_ERROR);
			}
			else
				offset=(int)offset_def;
#ifndef NO_GEM
			graf_mouse(BUSYBEE,(MFORM*)0);
#endif
			stack=Super(0L);              /* supervisor mode */
			if((adr&0x08)==0)             /* WC = 0 */
			{
				adr=0x08; /* WC = 1 => use WRITEE2 command for the EEPROM */
				error=ct60_rw_clock(CT60_CLOCK_WRITE_RAM|DALLAS,ADR,adr);
				tempo_20ms();
			}
			if(error>=0)
			{
				if((error=ct60_rw_clock(CT60_CLOCK_WRITE_RAM|DALLAS,MUXWORD,mux))>=0)
				{
					if((error=ct60_rw_clock(CT60_CLOCK_WRITE_RAM|DALLAS,DACWORD,dac<<6))>=0)
					{
						if((error=ct60_rw_clock(CT60_CLOCK_WRITE_RAM|DALLAS,OFFSET,offset))>=0)
							error=ct60_rw_clock(CT60_CLOCK_WRITE_RAM|DALLAS,DIVWORD,(divider-2)<<6);
					}
				}
			}
			if(error>=0 && mode==CT60_CLOCK_WRITE_EEPROM)
			{
				error=ct60_rw_clock(CT60_CLOCK_WRITE_EEPROM|DALLAS,WRITEE2,0); /* transfer in EEPROM */
				tempo_20ms();
			}
		}
	}
	else if((error=ct60_rw_clock(CT60_CLOCK_READ|CYPRESS,CLKOE,0))>=0)   /* Cypress CY27EE16 */
	{	
		Super((void *)stack);         /* user mode */
		if(frequency<MIN_FREQ || frequency>MAX_FREQ_REV6)
			return(CT60_CALC_CLOCK_ERROR);
		/* frequency (KHz) = (REF (KHz) * p) / q) / post divider */
		/* => p/q = (frequency * post divider) / REF (KHz)       */
		/* p = (2 * (PB  + 4)) + P0   q = Q + 2                  */
		/* 8 <= p <= 2055             2 <= q <= 129              */
		p=(frequency*2000)/REF;
		q=REF/250;         /* 250 KHz mini => max value for q    */
		while((p*q)>2055000 && q>=2)
			q--;
		if(q<2 || q>129)
			return(CT60_CALC_CLOCK_ERROR);
		pll=(p/1000)*REF;
		if(pll<100000 || pll>400000)  /* PLL between 100 and 400 MHz */
			return(CT60_CALC_CLOCK_ERROR);
		p*=q;
		p/=1000;
		if(p<8 || p>2055)
			return(CT60_CALC_CLOCK_ERROR);
		chargep=(unsigned char)((((p>>1)-4)>>8) & 0xFF);
		chargep|=0xC0;
		if(p>=45 && p<=479)
			chargep|=0x04;
		else if(p>=480 && p<=639)
			chargep|=0x08;
		else if(p>=640 && p<=799)
			chargep|=0x0C;
		else if(p>=800)
			chargep|=0x10;
		if(frequency<=66000)
		{
			matrix2=0xDF;
			matrix3=0xB7;   /* clocks 5 & 6 DIV2CLK/4 */
			divider=6;      /* post divider */
		}		
		else
		{
			matrix2=0xDE;
			matrix3=0x4F;   /* clocks 5 & 6 DIV1CLK/DIV1N */
			divider<<=1;    /* post divider */
			if(divider<4)
				divider=4;
			if(divider>127)
				divider=127;
		}
#ifndef NO_GEM
		graf_mouse(BUSYBEE,(MFORM*)0);
#endif
		stack=Super(0L);    /* supervisor mode */
		if(mode==CT60_CLOCK_WRITE_EEPROM)
		{
			ct60_rw_clock(CT60_CLOCK_WRITE_RAM|CYPRESS,WPREG,0x0C); /* enable EEPROM writing */
			tempo_20ms();
			error=ct60_rw_clock(CT60_CLOCK_WRITE_RAM|CYPRESS,WPREG,0x0C); /* enable EEPROM writing */
		}
		if(error>=0)
		{
			error=ct60_rw_clock(mode|CYPRESS,DIV1N,(int)divider);
			if(error>=0)
			{
				if(mode==CT60_CLOCK_WRITE_EEPROM)
						tempo_20ms();
				error=ct60_rw_clock(mode|CYPRESS,MATRIX2,(int)matrix2);
				if(error>=0)
				{
					if(mode==CT60_CLOCK_WRITE_EEPROM)
						tempo_20ms();
					error=ct60_rw_clock(mode|CYPRESS,MATRIX3,(int)matrix3);
					if(error>=0)
					{
						if(mode==CT60_CLOCK_WRITE_EEPROM)
							tempo_20ms();
						error=ct60_rw_clock(mode|CYPRESS,CHARGEP,(int)chargep);
						if(error>=0)
						{
							if(mode==CT60_CLOCK_WRITE_EEPROM)
								tempo_20ms();
							error=ct60_rw_clock(mode|CYPRESS,PBCOUNTER,(int)(((p>>1)-4) & 0xFF));
							if(error>=0)
							{
								if(mode==CT60_CLOCK_WRITE_EEPROM)
									tempo_20ms();
								error=ct60_rw_clock(mode|CYPRESS,QCOUNTER,(int)((((p & 1)<<7)+q-2) & 0xFF));
								if(error>=0)
								{
									if(mode==CT60_CLOCK_WRITE_EEPROM)
										tempo_20ms();
									i=error=0;
									while((tab_cy_reg[i] || tab_cy_reg[i+1]) && error>=0)
									{
									 	error=ct60_rw_clock(mode|CYPRESS,tab_cy_reg[i],tab_cy_reg[i+1]);
										if(mode==CT60_CLOCK_WRITE_EEPROM)
											tempo_20ms();
										i+=2;
									}
								}
							}
						}
					}
				}
			}
		}
	}
	Super((void *)stack); /* user mode */
#ifndef NO_GEM
	graf_mouse(ARROW,(MFORM*)0);
#endif
	return((int)error);
}

void tempo_20ms(void)

{
	unsigned long 	start_time;
	start_time	=*(unsigned long *)0x4BA;
	while( ((*(unsigned long *)0x4BA) - start_time) <= 4); /* 20 mS */
}
