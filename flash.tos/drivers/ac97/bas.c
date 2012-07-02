void bas_init_ac97(void)
{
// PSC2: AC97 ----------
		int i,zm,va=-1,vb=-1,vc=-1;

		MCF_PSC_TB0_32BIT = 'AC97';
		MCF_GPIO_PAR_PSC2 = MCF_GPIO_PAR_PSC2_PAR_RTS2_RTS	// PSC2=TX,RX BCLK,CTS->AC'97
						 | MCF_GPIO_PAR_PSC2_PAR_CTS2_BCLK
						 | MCF_GPIO_PAR_PSC2_PAR_TXD2
 						 | MCF_GPIO_PAR_PSC2_PAR_RXD2;  
 		MCF_PSC2_MR = 0x0;		 	 
		MCF_PSC2_MR = 0x0;	
		MCF_PSC2_IMR = 0x0300;	 	 
		MCF_PSC2_SICR = 0x03;		//AC97		 
		MCF_PSC2_RFCR = 0x0f000000;
		MCF_PSC2_TFCR = 0x0f000000;
		MCF_PSC2_RFAR = 0x00F0;
		MCF_PSC2_TFAR = 0x00F0;

	for ( zm = 0; zm<100000; zm++)		// wiederholen bis synchron
	{
		MCF_PSC2_CR = 0x20;
		MCF_PSC2_CR = 0x30;
		MCF_PSC2_CR = 0x40;
		MCF_PSC2_CR = 0x05;
// MASTER VOLUME -0dB
		MCF_PSC_TB2_AC97 = 0xE0000000+MCF_PSC_TB_AC97_SOF; //START SLOT1 + SLOT2, FIRST FRAME
		MCF_PSC_TB2_AC97 = 0x02000000; //SLOT1:WR REG MASTER VOLUME adr 0x02
		for ( i = 2; i<13; i++ )
		{
			MCF_PSC_TB2_AC97 = 0x0; //SLOT2-12:WR REG ALLES 0
		}
 //	 read register
 		MCF_PSC_TB2_AC97 = 0xc0000000+MCF_PSC_TB_AC97_SOF; //START SLOT1 + SLOT2, FIRST FRAME
 		MCF_PSC_TB2_AC97 = 0x82000000; //SLOT1:master volume
		for ( i = 2; i<13; i++ )
		{
			MCF_PSC_TB2_AC97 = 0x00000000; //SLOT2-12:RD REG ALLES 0
		}
		udelay(200);
		va = MCF_PSC_TB2_AC97;
		if ((va & (0x80000000+MCF_PSC_TB_AC97_SOF))==(0x80000000+MCF_PSC_TB_AC97_SOF))
		{
			vb = MCF_PSC_TB2_AC97;
 			vc = MCF_PSC_TB2_AC97;
			if (((va & (0xE0000000+MCF_PSC_TB_AC97_SOF))==(0xE0000000+MCF_PSC_TB_AC97_SOF)) /* && (vb==0x02000000) && (vc==0x00000000) */)
			{
				goto livo;
			}
		}
	}
	MCF_PSC_TB0_32BIT = ' not';
livo: 
// AUX VOLUME ->-0dB 
	MCF_PSC_TB2_AC97 = 0xE0000000; //START SLOT1 + SLOT2, FIRST FRAME
	MCF_PSC_TB2_AC97 = 0x16000000; //SLOT1:WR REG AUX VOLUME adr 0x16
	MCF_PSC_TB2_AC97 = 0x06060000; //SLOT1:VOLUME 
	for ( i = 3; i<13; i++ )
	{
		MCF_PSC_TB2_AC97 = 0x0; //SLOT2-12:WR REG ALLES 0
	}
 
// line in VOLUME +12dB
	MCF_PSC_TB2_AC97 = 0xE0000000; //START SLOT1 + SLOT2, FIRST FRAME
	MCF_PSC_TB2_AC97 = 0x10000000; //SLOT1:WR REG MASTER VOLUME adr 0x02
	for ( i = 2; i<13; i++ )
	{
		MCF_PSC_TB2_AC97 = 0x0; //SLOT2-12:WR REG ALLES 0
	}
// cd in VOLUME 0dB
	MCF_PSC_TB2_AC97 = 0xE0000000; //START SLOT1 + SLOT2, FIRST FRAME
	MCF_PSC_TB2_AC97 = 0x12000000; //SLOT1:WR REG MASTER VOLUME adr 0x02
	for ( i = 2; i<13; i++ )
	{
		MCF_PSC_TB2_AC97 = 0x0; //SLOT2-12:WR REG ALLES 0
	}
// mono out VOLUME 0dB
	MCF_PSC_TB2_AC97 = 0xE0000000; //START SLOT1 + SLOT2, FIRST FRAME
	MCF_PSC_TB2_AC97 = 0x06000000; //SLOT1:WR REG MASTER VOLUME adr 0x02
	MCF_PSC_TB2_AC97 = 0x00000000; //SLOT1:WR REG MASTER VOLUME adr 0x02
	for ( i = 3; i<13; i++ )
	{
		MCF_PSC_TB2_AC97 = 0x0; //SLOT2-12:WR REG ALLES 0
	}
	MCF_PSC2_TFCR |= MCF_PSC_RFCR_WRITETAG; //set EOF
	MCF_PSC_TB2_AC97 = 0x00000000; //last data

	MCF_PSC_TB0_32BIT = ' OK!';
	MCF_PSC_TB0_16BIT = 0x0a0d;

	board_printf("va %08X vb %08X vc %08X\r\n", va, vb, vc);

}
