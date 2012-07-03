/* CT60 booting & SDRAM:
 *  - Boot CPU 68060 detection
 *  - Apply TOS404 patches
 *  - Configure the CT60-CTCM (CT60 CLock Module)
 *  - Configure the CT60-SDRAM
 *  - PCI entry points
 *  - Boot disk
 *  - Add SDRAM to TOS
 *  - I2C routines (CTCM and SDRAM)
 *  - Speed FAN on IO3 MFP
 *
 * Coldfire board(s) booting:
 *  - Init board before start the CF68KLIB
 *  - Apply TOS404 patches
 *  - Boot CPU detection MCF547X/MCF548X or MCF5445X
 *  - PCI entry points
 *  - Boot disk from CompactFlash on MCF548X or from ATA on MCF5445X
 *  - IDE driver with XHDI and SCSIDRV protocols
 *  - Add SDRAM to TOS
 *
 * Didier Mequignon 2001-2012, e-mail: aniplay@wanadoo.fr
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "main.h"
#include "ct60.h"
#include "vars.h"
#include "pci_bios.h"

#ifdef COLDFIRE
#undef DEBUG
#endif

// #define INIT_SDRAM_MOVE16
// #define RESET // removed because not works with some motherboards/SDR60 versions
#undef INIT_FPGA_FROM_RAM // FIREBEE

#define ADDR_VERSION     0xE80000
#define ADDR_DATE        0xE80002

#define SPEED_BUFFER_SIZE 0x10000 // mini 512 bytes, maxi 0x20000
#define NB_COOKIES            128
#define CT60_COOKIE_SIZE      256
#define DEFAULT_BOOT_DELAY    800 // 4 seconds

#define rw_parameter 0xc60b
#define cache 0xc60c

#ifdef COLDFIRE
#define AUTO_SUBROUTINE // for BDOS else crash

#include "fire.h"

#define RESET // for IDE

#else /* CT60 - ATARI */

#define USE_ATARI_IO       // IDE, SCSI

/* I2C */

#define SLAVE_SDRAM_ADDRESS           0x50 // 7 bits 1010xxx + r/w
#define SLAVE_DS_ADDRESS              0x58  
#define SLAVE_CY_EEPROM_ADDRESS       0x68
#define SLAVE_CY_SRAM_ADDRESS         0x69

#define CT60_CLOCK_READ         0
#define CT60_CLOCK_WRITE_RAM    1
#define CT60_CLOCK_WRITE_EEPROM 2
#define CT60_CLOCK_RESET        3
#define CT60_CALC_CLOCK_ERROR  -2
#define CYPRESS 0x0000
#define DALLAS  0x8000
#define MIN_FREQ_DALLAS     66000 // KHz
#define MAX_FREQ_DALLAS    133000 // KHz
#define MIN_FREQ            50000 // KHz
#define MAX_FREQ           110000 // KHz

/* DS1085 serial programmable clock registers */
#define DIVWORD   0x01
#define MUXWORD   0x02
#define DACWORD   0x08
#define ADR       0x0D
#define OFFSET    0x0E
#define RANGEWORD 0x37
#define WRITEE2   0x3F
#if 0
// DS1085Z-10
#define BASE_FREQ  61400 // KHz
#define DEF_FREQ   97100 // KHz
#define DAC_STEP      10 // KHz
#define DAC_DEF      500
#define OFFSET_STEP 5120 // KHz
// DS1085Z-25
#define BASE_FREQ  51200 // KHz
#define DEF_FREQ  104600 // KHz
#define DAC_STEP      25 // KHz
#define DAC_DEF      600
#define OFFSET_STEP 6400 // KHz
#endif
// DS1085Z-50
#define BASE_FREQ  38400 // KHz
#define DEF_FREQ  101800 // KHz
#define DAC_STEP      50 // KHz
#define DAC_DEF      500
#define OFFSET_STEP 6400 // KHz 

/* CY27EE16ZE serial programmable clock registers */
#define CTRLMACH  0x00
#define ADRDEV8EE 0x05
#define ADRDEVPLL 0x06
#define DEFPLLCNF 0x07
#define CLKOE     0x09
#define DIV1N     0x0C
#define PINCTRL   0x10
#define WPREG     0x11
#define OSCDRV    0x12
#define INLOAD    0x13
#define ADCREG    0x14
#define CHARGEP   0x40
#define PBCOUNTER 0x41
#define QCOUNTER  0x42
#define MATRIX1   0x44
#define MATRIX2   0x45
#define MATRIX3   0x46
#define DIV2N     0x47
#define REF       10000           // KHz

#define CT60_READ_ERROR         -1
#define CT60_CHIP_DENSITY_ERROR -2
#define CT60_NUM_BANK_ERROR     -3
#define CT60_MOD_DENSITY_ERROR  -4
#define CT60_BURST_LENGTH_ERROR -5
#define CT60_DATA_WIDTH_ERROR   -6
#define CT60_VOLTAGE_ERROR      -7
#define CT60_SDRAM_TYPE_ERROR   -8
#define CT60_REFRESH_RATE_ERROR -9

#define _gpip_mfp 0xfffffa01

#define _sdcnf    0xF2000000      // SDRAM configuration 0xf2xx0000 
#define _nideoff  0xF3000000      // no swap IDE ports, the new IDE on the CTPCI is seconday, F030 IDE is the primary (default)
#define _nideon   0xF3800000      // swap IDE ports, the new IDE on the CTPCI on primary, F030 IDE is secondary
// old Jedecs
//#define _nideoff  0xF3000000      // turn off the new IDE on the CTPCI (default)
//#define _nideon   0xF3800000      // turn on the new IDE on the CTPCI
#define _oideon   0xF8000000      // turn on the old IDE of the motherboard (default)
#define _oideoff  0xF8800000      // turn off the old IDE of the motherboard

#endif /* COLDFIRE */

#define LINEA_VAR 0x3E86
#define _v_cel_ht LINEA_VAR-46  // cell height (width is 8)

#ifdef COLDFIRE 
	.globl init_cf
	.globl dummy_function
	.globl delay_10us
	.globl fire_rw_param
	.globl before_init_cookies // 1rst function called after reset (and before init_cf or init_060)
	.globl disable_interrupts
	.globl check_tos_crc
#ifdef MCF547X
	.globl rtc_init
#endif
#else /* !COLDFIRE */
	.globl init_060
	.globl code_led
#endif /* COLDFIRE */
	.globl _LZ_Uncompress
	.globl _LzmaDecode
	.globl _LzmaDecodeProperties
	.globl _apply_patches
	.globl init_sdram
	.globl add_sdram
#ifdef COLDFIRE
	.globl bootload
#endif
	.globl boot_drive
#ifdef COLDFIRE
	.globl install_scsidrv
	.globl install_hddriver
	.globl conv_ascii_value_optimized
#if defined(MCF5445X) || (defined MCF547X)
	.globl ide_reset
#endif
#endif /* COLDFIRE */
	.globl read_sectors
	.globl write_sectors
	.globl ide_cmd
	.globl scsi_cmd
	.globl swap_buffer
	.globl menu_boot
	.globl init_ram_test
	.globl display_ram_test
	.globl delay_hz_200
#ifndef COLDFIRE
	.globl ct60_read_info_sdram
	.globl ct60_configure_sdram
	.globl read_seq_device_i2c
	.globl write_seq_device_i2c 
	.globl read_i2c
	.globl write_i2c
	.globl init_speed_fan
#endif
	.globl message0b

	.text

#ifdef COLDFIRE

init_cf:                             // entry point

	move.w #0x2700,SR       // mask Interrupts
	.chip 5200
	lea .start_ok(PC),A0
	cmp.l #FLASH_ADR,A0
	bcs.s .start_ok
	cmp.l #FLASH_ADR+0x100000,A0
	bcc.s .start_ok
	// started from TOS space (copy by another boot) normally incompatible with boot 2.0 and patches apply to the same place
	jmp FLASH_TOS_FIRE_ENGINE
	nop
	nop
	nop
//	.align 16
dummy_function: // 32 bytes length, 16 bytes alignment, for chip errata, used by PCI config writes
	clr.l D0
	move.l D0,MCF_EPORT_EPFR
	rts
	dc.w 0x51FB,0,0 // tpf.l #0
	dc.w 0x51FB,0,0 // tpf.l #0	
	dc.w 0x51FB,0,0 // tpf.l #0
	dc.w 0x51FA,0   // tpf.w #0
.start_ok:
#ifdef MCF5445X
	/* Initialize RAMBAR - locate it on the data bus */
	move.l #SRAM_BASE+0x35,D0
	movec.l D0,RAMBAR1
	move.l #8191,D0 // 32KB
.init_sram:                           // clear SRAM
		clr.l (A0)+
	subq.l #1,D0
	bpl.s .init_sram
	/* Point Stack Pointer into Core SRAM temporarily */
	lea SRAM_BASE+0x8000,A0
#else /* MCF547X - MCF548X */
	/* Initialize MBAR */
	move.l #__MBAR,D0
	movec.l D0,MBAR
	/* Initialize RAMBAR0 - locate it on the data bus */
	move.l #0x20000035,D0
	movec.l D0,RAMBAR0
	/* Initialize RAMBAR1 - locate it on the data bus */
	move.l #0x20001035,D0
	movec.l D0,RAMBAR1
	lea 0x20000000,A0
	move.l #2047,D0 // 2 x 4KB
.init_sram:                           // clear 2 x SRAM
		clr.l (A0)+
	subq.l #1,D0
	bpl.s .init_sram
	/* Point Stack Pointer into Core SRAM temporarily */
	lea 0x20002000,A0
#endif /* MCF5445X */
	move.l A0,SP
#if 1
	/* Invalidate the data, instruction, and branch caches */
	/* Turn on the branch cache and instruction cache */
	move.l #CF_CACR_DCINVA + CF_CACR_BEC + CF_CACR_BCINVA + CF_CACR_IEC + CF_CACR_ICINVA + CF_CACR_EUSP,D0
#else
	/* Invalidate the data, instruction, and branch caches */
	move.l #CACHE_DISABLE_MODE,D0 
#endif
	movec.l D0,CACR
	nop                      // default copyback set later with CACR at X2XXXXXX
	move.l #0x0000E000,D0    // zone at $00000000 to $00FFFFFF in writethrough
	movec.l D0,ACR0
	movec.l D0,ACR2
#if defined(MCF547X) && !defined(DEBUG)
	move.l #0xF00FE040,D0    // and the zone $F0000000-$FFFFFFFF in cache inhibit precise
#else
	move.l #0x807FE040,D0    // and the zone $80000000-$FFFFFFFF in cache inhibit precise
#endif
	movec.l D0,ACR1
	movec.l D0,ACR3
#define MMUCR           __MMU_BASE
	move.l #__MMU_BASE+1,D0
	dc.l 0x4E7B0008          // movec.l D0,MMUBAR
	nop
	clr.l MMUCR              // disable MMU 		
	nop	
	/* Disable all interrupts */
	bsr disable_interrupts
#ifdef MCF5445X /* M54455EVB */
	/* Falling edge on IRQ1-7 EPORT */
	move.w #EPORT_EPPAR_EPPA7(EPORT_EPPAR_FALLING) \
	 + EPORT_EPPAR_EPPA6(EPORT_EPPAR_FALLING) \
	 + EPORT_EPPAR_EPPA5(EPORT_EPPAR_FALLING) \
	 + EPORT_EPPAR_EPPA4(EPORT_EPPAR_FALLING) \
	 + EPORT_EPPAR_EPPA3(EPORT_EPPAR_FALLING) \
	 + EPORT_EPPAR_EPPA2(EPORT_EPPAR_FALLING) \
	 + EPORT_EPPAR_EPPA1(EPORT_EPPAR_FALLING),D0
	move.w D0,MCF_EPORT_EPPAR
	clr.b MCF_EPORT_EPDDR
	clr.b MCF_EPORT_EPIER
	/* Disable watchdog timer */
	clr.w MCF_SCM_CWCR
	/* System Control */
	move.l #0x77777777,D0
	move.L D0,MCF_SCM_MPR
	moveq #0,D0
	move.l D0,MCF_SCM_PACRA
	move.l D0,MCF_SCM_PACRB
	move.l D0,MCF_SCM_PACRC
	move.l D0,MCF_SCM_PACRD
	move.l D0,MCF_SCM_PACRE
	move.l D0,MCF_SCM_PACRF
	move.l D0,MCF_SCM_PACRG
	/* Setup RTC Clock */
	move.l #(CFG_RTC_OSCILLATOR/65536),D0
	move.l D0,MCF_RTC_GOCU
	move.l #(CFG_RTC_OSCILLATOR%65536),D0
	move.l D0,MCF_RTC_GOCL    
	/* Setup FEC Pins */
	move.b #GPIO_PAR_FEC_FEC1_RMII_ATA + GPIO_PAR_FEC_FEC0_RMII_ULPI,D0
	move.b D0,MCF_GPIO_PAR_FEC
	/* Setup FlexBus Pins */
	move.b #GPIO_PAR_BE_BE3_BE3 + GPIO_PAR_BE_BE2_BE2 \
	 + GPIO_PAR_BE_BE1_BE1 + GPIO_PAR_BE_BE0_BE0,D0
	MOVE.B D0,MCF_GPIO_PAR_BE
	MOVE.B #GPIO_PAR_CS_CS1_CS1 + GPIO_PAR_CS_CS2_CS2 + GPIO_PAR_CS_CS3_CS3,D0
	MOVE.B D0,MCF_GPIO_PAR_CS
	move.b #GPIO_PAR_FBCTL_OE + GPIO_PAR_FBCTL_TA_TA \
	 + GPIO_PAR_FBCTL_RW_RW + GPIO_PAR_FBCTL_TS_TS,D0
	move.b D0,MCF_GPIO_PAR_FBCTL
	/* Setup DSPI Serial Flash / Audio Pins */
	move.b #GPIO_PAR_DSPI_PCS5_PCS5 + GPIO_PAR_DSPI_PCS2_PCS2 \
	 + GPIO_PAR_DSPI_PCS1_PCS1 + GPIO_PAR_DSPI_PCS0_PCS0 \
	 + GPIO_PAR_DSPI_SIN_SIN + GPIO_PAR_DSPI_SOUT_SOUT + GPIO_PAR_DSPI_SCK_SCK,D0
	move.b D0,MCF_GPIO_PAR_DSPI
	/* Setup SSI Audio Pins */
	move.w #GPIO_PAR_SSI_BCLK_BCLK + GPIO_PAR_SSI_FS_FS \
	 + GPIO_PAR_SSI_SRXD_SRXD + GPIO_PAR_SSI_STXD_STXD + GPIO_PAR_SSI_MCLK_MCLK,D0
	move.w D0,MCF_GPIO_PAR_SSI
	/* Setup USB Pins */
	move.b #GPIO_PAR_USB_VBUSEN_VBUSEN + GPIO_PAR_USB_VBUSOC_VBUSOC,D0
	move.b D0,MCF_GPIO_PAR_USB
	move.b #GPIO_PAR_DMA_DACK1_ULPI_DIR + GPIO_PAR_DMA_DREQ1_USB_CLKIN \
	+ GPIO_PAR_DMA_DACK0_DACK0 + GPIO_PAR_DMA_DREQ0_DREQ0,D0
	move.b D0,MCF_GPIO_PAR_DMA
	/* Setup I2C/FEC/ATA Pins */
	move.w #GPIO_PAR_FECI2C_MDC1_ATA_DIOR + GPIO_PAR_FECI2C_MDIO1_ATA_DIOW \
	 + GPIO_PAR_FECI2C_MDC0_MDC0 + GPIO_PAR_FECI2C_MDIO0_MDIO0 \
	 + GPIO_PAR_FECI2C_SCL_SCL + GPIO_PAR_FECI2C_SDA_SDA,D0
	move.w D0,MCF_GPIO_PAR_FECI2C	
	/* ATA */
	move.w #GPIO_PAR_ATA_BUFEN_BUFEN + GPIO_PAR_ATA_CS1_CS1 + GPIO_PAR_ATA_CS0_CS0 \
	 + GPIO_PAR_ATA_DA2_DA2 + GPIO_PAR_ATA_DA1_DA1 + GPIO_PAR_ATA_DA0_DA0 \
	 + GPIO_PAR_ATA_RESET_RESET + GPIO_PAR_ATA_DMARQ_DMARQ + GPIO_PAR_ATA_IORDY_IORDY,D0
	move.w D0,MCF_GPIO_PAR_ATA
	/* Setup Pins Serial Ports */
	move.b #GPIO_PAR_UART_U1CTS_U1CTS + GPIO_PAR_UART_U1RTS_U1RTS \
	 + GPIO_PAR_UART_U1RXD_U1RXD + GPIO_PAR_UART_U1TXD_U1TXD \
	 + GPIO_PAR_UART_U0CTS_U0CTS + GPIO_PAR_UART_U0RTS_U0RTS \
	 + GPIO_PAR_UART_U0RXD_U0RXD + GPIO_PAR_UART_U0TXD_U0TXD,D0
	move.b D0,MCF_GPIO_PAR_UART
	move.b #GPIO_PAR_TIMER_T3IN_U2RXD + GPIO_PAR_TIMER_T2IN_U2TXD,D0
	move.b D0,MCF_GPIO_PAR_TIMER
	/* Set PCIGNT1, PCIREQ1, PCIREQ0/PCIGNTIN, PCIGNT0/PCIREQOUT, PCIREQ2, PCIGNT2 */
	move.w #GPIO_PAR_PCI_GNT3_ATA_DMACK + GPIO_PAR_PCI_GNT2 \
	 + GPIO_PAR_PCI_GNT1 + GPIO_PAR_PCI_GNT0 \
	 + GPIO_PAR_PCI_REQ3_ATA_INTRQ + GPIO_PAR_PCI_REQ2 \
	 + GPIO_PAR_PCI_REQ1 + GPIO_PAR_PCI_REQ0,D0
	move.w D0,MCF_GPIO_PAR_PCI
	/* Reset UART Transmitter */
	move.b #MCF_UART_UCR_RESET_TX,D0
    	move.b D0,MCF_UART_UCR0
	/* Reset UART Receiver */
	move.b #MCF_UART_UCR_RESET_RX,D0
	move.b D0,MCF_UART_UCR0
	/* Reset UART Mode Register */
	move.b #MCF_UART_UCR_RESET_MR,D0
	move.b D0,MCF_UART_UCR0
	/* No parity, 8-bits per character */
	move.b #MCF_UART_UMR_PM_NONE+MCF_UART_UMR_BC_8,D0
	move.b D0,MCF_UART_UMR0
	/* No echo or loopback, 1 stop bit */
	move.b #MCF_UART_UMR_CM_NORMAL+MCF_UART_UMR_SB_STOP_BITS_1,D0
	move.b D0,MCF_UART_UMR0
	/* Set Rx and Tx baud by timer */
	move.b #MCF_UART_UCSR_RCS_SYS_CLK+MCF_UART_UCSR_TCS_SYS_CLK,D0
	move.b D0,MCF_UART_UCSR0
	/* Mask all UART interrupts */
	clr.b MCF_UART_UIMR0  
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_MAC_ADDRESS,D1 // type_param
	moveq #0,D2              // value
	.chip 68060
	bsr.l fire_rw_param
	.chip 5200
	move.l D0,mac_address
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_IP_ADDRESS,D1 // type_param
	moveq #0,D2              // value
	.chip 68060
	bsr.l fire_rw_param
	.chip 5200
	move.l D0,ip_address
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SERVER_IP_ADDRESS,D1 // type_param
	moveq #0,D2              // value
	.chip 68060
	bsr.l fire_rw_param
	.chip 5200
	move.l D0,server_ip_address
	/* Calculate baud settings */
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SERIAL_SPEED,D1 // type_param
	moveq #0,D2              // value
	.chip 68060
	bsr.l fire_rw_param
	.chip 5200
	tst.l D0
	bmi.s .default_speed
	cmp.l #16,D0
	bcs.s .speed_ok
.default_speed:
//	moveq #1,D0              // 9600 bauds
	moveq #0,D0              // 19200 bauds
.speed_ok:
	lea tab_baudrate(PC),A0
	and.l #0xF,D0
	asl.l #2,D0
	move.l (A0,D0.l),D1
	asl.l #4,D1              // * 16
	move.l #(SYSTEM_CLOCK*1000000),D0
	.chip 68060
	divu.l D1,D0             // ubgs
	.chip 5200
	lsr.l #1,D0              // / 2
	bcc.s .set_speed
	addq.l #1,D0
.set_speed:	
	move.b D0,D1
	lsr.l #8,D0
	move.b D0,MCF_UART_UBG10
	move.b D1,MCF_UART_UBG20
	/* Enable receiver and transmitter */
	move.b #MCF_UART_UCR_TX_ENABLED+MCF_UART_UCR_RX_ENABLED,D0
	move.b D0,MCF_UART_UCR0
#if 1 /* PCI Config */ /*to finish...*/
	/* Master Enable / Memory Space / MWI */
	move.l #0x16,D0
	move.l D0,MCF_PCI_PCISCR     // PCI Command Register
	/* Turn on error signaling */
//	move.l #MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE /* + MCF_PCI_PCIICR_REE*/ + PCI_RETRIES,D0
//	move.l D0,MCF_PCI_PCIICR
//	move.l #MCF_PCI_PCIGSCR_SEE,D0
//	or.l D0,MCF_PCI_PCIGSCR
	/* Configure Initiator Windows */
	move.l #PCI_MEMORY_OFFSET + ((PCI_MEMORY_SIZE - 1) >> 8),D0
	clr.w D0
	move.l D0,MCF_PCI_PCIIW0BTAR // Initiator Window 0 Base / Translation Address Register
	move.l #PCI_IO_OFFSET + ((PCI_IO_SIZE - 1) >> 8),D0
	clr.w D0
	move.l D0,MCF_PCI_PCIIW1BTAR // Initiator Window 1 Base / Translation Address Register
	clr.l MCF_PCI_PCIIW2BTAR     // not used
//	move.l #MCF_PCI_PCIIWCR_WINCTRL0_MEMRDLINE + MCF_PCI_PCIIWCR_WINCTRL1_IO,D0
//	move.l D0,MCF_PCI_PCIIWCR	   // Initiator Window Configuration Register
	// Target zones
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l #0x40000000,D0
	move.l D0,MCF_PCI_PCIBAR0    // 256 KB window
	move.l #0xFC000001,D0 
	move.l D0,MCF_PCI_PCITBATR0  // Target Base Address Translation Register 0
	clr.l MCF_PCI_PCIBAR1        // 1 GB window ! 
	moveq #1,D0 
	move.l D0,MCF_PCI_PCITBATR1  // Target Base Address Translation Register 1
#else /* !SAME_CPU_PCI_MEM_ADDR */
	move.l #0x80000000,D0
	move.l D0,MCF_PCI_PCIBAR0    // 256 KB window
	move.l #0xFC000001,D0 
	move.l D0,MCF_PCI_PCITBATR0  // Target Base Address Translation Register 0
	move.l #0x40000000,D0
	move.l D0,MCF_PCI_PCIBAR1    // 1 GB window ! 
	moveq #1,D0 
	move.l D0,MCF_PCI_PCITBATR1  // Target Base Address Translation Register 1
#endif /* SAME_CPU_PCI_MEM_ADDR */
	/* Clear PCI Reset and wait for devices to reset */
	move.l #0xFFFFFFFE,D0
	and.l D0,MCF_PCI_PCIGSCR
#endif /* PCI config */
#ifdef DEBUG
	clr.b serial_mouse
	lea debug102(PC),A0
	bsr debug_display_string
	lea init_cf(PC),A0
	move.l A0,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug101(PC),A0
	bsr debug_display_string	
#endif
	/* Intel Flash */
	move.l #FBCS_CSAR_BA(BOOT_FLASH_BASE),D0
	move.l D0,MCF_FBCS0_CSAR
	move.l #CFG_CS0_MASK,D0
	move.l D0,MCF_FBCS0_CSMR
	move.l #CFG_CS0_CTRL,D0
	move.l D0,MCF_FBCS0_CSCR
#if 0
	/* Atmel Flash */
	move.l #CFG_CS1_BASE,D0
	move.l D0,MCF_FBCS1_CSAR
	move.l #CFG_CS1_MASK,D0
	move.l D0,MCF_FBCS1_CSMR
	move.l #CFG_CS1_CTRL,D0
	move.l D0,MCF_FBCS1_CSCR
#endif
#ifdef DEBUG
	lea debug108(PC),A0
	bsr debug_display_string
#endif
	/* FPGA */
	move.l #FBCS_CSAR_BA(CPLD_BASE),D0
	move.l D0,MCF_FBCS2_CSAR
	move.l #CFG_CS2_MASK,D0
	move.l D0,MCF_FBCS2_CSMR
	move.l #CFG_CS2_CTRL,D0
	move.l D0,MCF_FBCS2_CSCR	
	/* FPGA */
	move.l #FBCS_CSAR_BA(FPGA_BASE),D0
	move.l D0,MCF_FBCS3_CSAR
	move.l #CFG_CS3_MASK,D0
	move.l D0,MCF_FBCS3_CSMR
	move.l #CFG_CS3_CTRL,D0
	move.l D0,MCF_FBCS3_CSCR
#ifdef DEBUG
	lea debug109(PC),A0
	bsr debug_display_string
	move.l FPGA_VERSION,D0
	lsr.l #8,D0
	bsr debug_hex_byte
	moveq #0x2E,D0
	bsr debug_display_char
	move.l FPGA_VERSION,D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif	
	/*
	 * Check to see if the SDRAM has already been initialized
	 * by a run control tool
	 */
	lea .copy_boot(PC),A0
	move.l A0,D0
	moveq #24,D1
	lsr.l D1,D0
	beq .sdram_controller_ok // started from RAM
//	move.l MCF_SDRAMC_SDCR,D0
//	and.l #SDRAMC_SDCR_REF,D0
//	bne .sdram_controller_ok
#ifdef DEBUG
	lea debug103(PC),A0
	bsr debug_display_string	
#endif
	move.b #GPIO_MSCR_SDRAM_SDDATA_DDR2 + GPIO_MSCR_SDRAM_SDDQS_DDR2 \
	 + GPIO_MSCR_SDRAM_SDCLK_DDR2 + GPIO_MSCR_SDRAM_SDCTL_DDR2, D0
	move.b D0,MCF_GPIO_MSCR_SDRAM
	move.l #SDRAMC_SDCS_BA(SDRAM_BASE) \
	+ SDRAMC_SDCS_CSSZ(SDRAMC_SDCS_CSSZ_64MBYTE),D0
	move.l D0,MCF_SDRAMC_SDCS0
	move.l #SDRAMC_SDCS_BA(SDRAM_BASE+(SDRAM_SIZE/2)) \
	+ SDRAMC_SDCS_CSSZ(SDRAMC_SDCS_CSSZ_64MBYTE),D0
	move.l D0,MCF_SDRAMC_SDCS1
	move.l #CFG_SDRAM_CFG1,D0
	move.l D0,MCF_SDRAMC_SDCFG1
	move.l #CFG_SDRAM_CFG2,D0
	move.l D0,MCF_SDRAMC_SDCFG2
	/* Issue PALL */
	move.l #CFG_SDRAM_CTRL + SDRAMC_SDCR_IPALL,D0
	move.l D0,MCF_SDRAMC_SDCR
	/* Issue LEMR */
	move.l #CFG_SDRAM_EMOD + 0x408,D0
	move.l D0,MCF_SDRAMC_SDMR
	move.l #CFG_SDRAM_MODE + 0x300,D0
	move.l D0,MCF_SDRAMC_SDMR
	/* Issue PALL */
	move.l #CFG_SDRAM_CTRL + SDRAMC_SDCR_IPALL,D0
	move.l D0,MCF_SDRAMC_SDCR
	/* Perform two refresh cycles */
	move.l #CFG_SDRAM_CTRL + SDRAMC_SDCR_IREF,D0
	move.l D0,MCF_SDRAMC_SDCR
	move.l #CFG_SDRAM_CTRL + SDRAMC_SDCR_IREF,D0
	move.l D0,MCF_SDRAMC_SDCR
	move.l #CFG_SDRAM_MODE + SDRAMC_SDMR_DDR2_AD(0x200),D0
	move.l D0,MCF_SDRAMC_SDMR
	move.l #~SDRAMC_SDCR_MODE_EN,D0
	and.l D0,MCF_SDRAMC_SDCR
	move.l #SDRAMC_SDCR_REF_EN+SDRAMC_SDCR_DQS_OE(0x3),D0
	or.l D0,MCF_SDRAMC_SDCR
.sdram_controller_ok:
	clr.b boot_tos
#else /* MCF547X-MCF548X */
#ifdef MCF547X
	move.w #MCF_EPORT_EPPAR_EPPA7(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA6(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA5(MCF_EPORT_EPPAR_EPPAx_LEVEL) \
	 + MCF_EPORT_EPPAR_EPPA4(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA3(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA2(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA1(MCF_EPORT_EPPAR_EPPAx_FALLING),D0
#else
	/* Falling edge on IRQ1-7 EPORT */
	move.w #MCF_EPORT_EPPAR_EPPA7(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA6(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA5(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA4(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA3(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA2(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA1(MCF_EPORT_EPPAR_EPPAx_FALLING),D0
#endif
	move.w D0,MCF_EPORT_EPPAR
	clr.b MCF_EPORT_EPDDR
	moveq #-1,D0
	move.b D0,MCF_EPORT_EPFR
	clr.b MCF_EPORT_EPIER
	/* Disable watchdog timer */
	clr.l MCF_GPT_GMS0
	/* Setup XL Bus Arbiter */
	moveq #24,D0
	move.l MCF_PCI_PCIGSCR,D2
	lsr.l D0,D2
	and.l #7,D2
	move.l #MCF_XARB_CFG_BA + MCF_XARB_CFG_DT + MCF_XARB_CFG_AT,D0
	cmp.l #4,D2                  // clock ratio 4:1
	bne.s .not_ratio_4_1
	or.l #MCF_XARB_CFG_PLDIS,D0  // Device Errata 26 - Flexbus hang up in 4:1 clock ratio
.not_ratio_4_1:
	move.l D0,MCF_XARB_CFG
#if 0
	move.l #0x1FFFFF,D0
	move.l D0,MCF_XARB_ADRTO
	move.l D0,MCF_XARB_DATTO
	move.l #0xFFFFFF,D0
	move.l D0,MCF_XARB_BUSTO     // better timeouts
#endif
	/* Reset PCI devices */
	move.l #MCF_PCI_PCIGSCR_PR,D0
	or.l D0,MCF_PCI_PCIGSCR
#if 1 /* PCI Config */
	/* Setup the PCI arbiter */
	move.l #MCF_PCIARB_PACR_INTMPRI \
	 + MCF_PCIARB_PACR_EXTMPRI(0x1F) \
	 + MCF_PCIARB_PACR_INTMINTEN \
	 + MCF_PCIARB_PACR_EXTMINTEN(0x1F),D0
#ifdef MCF547X
	move.b MCF_GPIO_PPDSDR_PCIBR,D1
	and.l #MCF_GPIO_PPDSDR_PCIBR_PPDSDR_PCIBR3,D1
	beq.s .pci_is_master2
	or.l #MCF_PCIARB_PACR_DS,D0 // disable on-chip arbiter and use GNT0/ for PCI request output and REQ0/ for grant input
.pci_is_master2:
#endif
	move.l D0,MCF_PCIARB_PACR
	/* GNT and REQ */
#ifdef MCF547X
	move.w #0x3F,D0 /* only BREQ0-2 are connected to PCI */
#else
	move.w #0x3FF,D0
#endif
	move.w D0,MCF_GPIO_PAR_PCIBG
	move.w D0,MCF_GPIO_PAR_PCIBR
	/* Master Enable / Memory Space / MWI */
	move.l #MCF_PCI_PCISCR_M + MCF_PCI_PCISCR_B + MCF_PCI_PCISCR_MW,D0
	move.l D0,MCF_PCI_PCISCR     // PCI Command Register
	/* Setup burst parameters */
	move.l #MCF_PCI_PCICR1_CACHELINESIZE(PCI_CACHE_LINE) + MCF_PCI_PCICR1_LATTIMER(32),D0
	move.l D0,MCF_PCI_PCICR1
	move.l #MCF_PCI_PCICR2_MINGNT(PCI_MINGNT) + MCF_PCI_PCICR2_MAXLAT(PCI_MAXLAT),D0
	move.l D0,MCF_PCI_PCICR2
	/* Turn on error signaling */
	move.l #MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE /* + MCF_PCI_PCIICR_REE */ + PCI_RETRIES,D0
	move.l D0,MCF_PCI_PCIICR
	move.l #MCF_PCI_PCIGSCR_SEE,D0
	or.l D0,MCF_PCI_PCIGSCR
	/* Configure Initiator Windows */
	move.l #PCI_MEMORY_OFFSET + ((PCI_MEMORY_SIZE - 1) >> 8),D0
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.w #(PCI_MEMORY_OFFSET >> 16),D0
#else
	clr.w D0
#endif
	move.l D0,MCF_PCI_PCIIW0BTAR // Initiator Window 0 Base / Translation Address Register
	move.l #PCI_IO_OFFSET + ((PCI_IO_SIZE - 1) >> 8),D0
	clr.w D0
	move.l D0,MCF_PCI_PCIIW1BTAR // Initiator Window 1 Base / Translation Address Register
	clr.l MCF_PCI_PCIIW2BTAR     // not used
	move.l #MCF_PCI_PCIIWCR_WINCTRL0_MEMRDLINE + MCF_PCI_PCIIWCR_WINCTRL1_IO,D0
	move.l D0,MCF_PCI_PCIIWCR	   // Initiator Window Configuration Register
	// Target zones
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l #0x40000000,D0
	move.l D0,MCF_PCI_PCIBAR0    // 256 KB window
	move.l #__MBAR + MCF_PCI_PCITBATR0_EN,D0
	move.l D0,MCF_PCI_PCITBATR0  // Target Base Address Translation Register 0
	clr.l MCF_PCI_PCIBAR1        // 1 GB window ! 
	move.l #MCF_PCI_PCITBATR1_EN,D0 
	move.l D0,MCF_PCI_PCITBATR1  // Target Base Address Translation Register 1
#else /* !SAME_CPU_PCI_MEM_ADDR */
	move.l #0x80000000,D0
	move.l D0,MCF_PCI_PCIBAR0    // 256 KB window
	move.l #__MBAR + MCF_PCI_PCITBATR0_EN,D0
	move.l D0,MCF_PCI_PCITBATR0  // Target Base Address Translation Register 0
	move.l #0x40000000,D0
	move.l D0,MCF_PCI_PCIBAR1    // 1 GB window ! 
	move.l #MCF_PCI_PCITBATR1_EN,D0 
	move.l D0,MCF_PCI_PCITBATR1  // Target Base Address Translation Register 1
#endif /* SAME_CPU_PCI_MEM_ADDR */
//	move.l #MCF_PCI_PCITCR_P,D0  // prefetch reads for BAR1
//	move.l D0,MCF_PCI_PCITCR     // Target Control Register
	/* Clear PCI Reset and wait for devices to reset */
	move.l #~MCF_PCI_PCIGSCR_PR,D0
	and.l D0,MCF_PCI_PCIGSCR
#endif /* PCI config */
	/* PSC init for debug */
	move.b #MCF_GPIO_PAR_PSC0_PAR_TXD0 \
	 + MCF_GPIO_PAR_PSC0_PAR_RXD0 \
	 + MCF_GPIO_PAR_PSC0_PAR_CTS0_CTS \
	 + MCF_GPIO_PAR_PSC0_PAR_RTS0_RTS,D0
	move.b D0,MCF_GPIO_PAR_PSC0
	/* Put PSC in UART mode */
	move.b #MCF_PSC_SICR_SIM_UART,D0
	move.b D0,MCF_PSC_SICR0
	/* Reset Transmitter */
	move.b #MCF_UART_UCR_RESET_TX,D0
    	move.b D0,MCF_UART_UCR0
	/* Reset Receiver */
	move.b #MCF_UART_UCR_RESET_RX,D0
	move.b D0,MCF_UART_UCR0
	/* Reset Mode Register */
	move.b #MCF_UART_UCR_RESET_MR,D0
	move.b D0,MCF_UART_UCR0
	/* No parity, 8-bits per character */
	move.b #MCF_UART_UMR_PM_NONE+MCF_UART_UMR_BC_8,D0
	move.b D0,MCF_UART_UMR0
	/* No echo or loopback, 1 stop bit */
	move.b #MCF_UART_UMR_CM_NORMAL+MCF_UART_UMR_SB_STOP_BITS_1,D0
	move.b D0,MCF_UART_UMR0
	/* Set Rx and Tx baud by timer */
	move.b #MCF_UART_UCSR_RCS_SYS_CLK+MCF_UART_UCSR_TCS_SYS_CLK,D0
	move.b D0,MCF_UART_UCSR0
	/* Mask all UART interrupts */
	clr.b MCF_UART_UIMR0  
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_MAC_ADDRESS,D1 // type_param
	moveq #0,D2              // value
	.chip 68060
	bsr.l fire_rw_param
	.chip 5200
	move.l D0,mac_address
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_IP_ADDRESS,D1 // type_param
	moveq #0,D2              // value
	.chip 68060
	bsr.l fire_rw_param
	.chip 5200
	move.l D0,ip_address
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SERVER_IP_ADDRESS,D1 // type_param
	moveq #0,D2              // value
	.chip 68060
	bsr.l fire_rw_param
	.chip 5200
	move.l D0,server_ip_address
	/* Calculate baud settings */
	moveq #CT60_MODE_READ,D0 // mode
	moveq #CT60_SERIAL_SPEED,D1 // type_param
	moveq #0,D2              // value
	.chip 68060
             bsr.l fire_rw_param
             .chip 5200
	tst.l D0
	bmi.s .default_speed
	cmp.l #16,D0
	bcs.s .speed_ok
.default_speed:
//	moveq #1,D0              // 9600 bauds
	moveq #0,D0              // 19200 bauds
.speed_ok:
	lea tab_baudrate(PC),A0
	and.l #0xF,D0
	asl.l #2,D0
	move.l (A0,D0.l),D1
	asl.l #4,D1              // * 16
	move.l #(SYSTEM_CLOCK*1000000),D0
	.chip 68060
	divu.l D1,D0             // ubgs
	.chip 5200
	lsr.l #1,D0              // / 2
	bcc.s .set_speed
	addq.l #1,D0
.set_speed:	
	move.b D0,D1
	lsr.l #8,D0
	move.b D0,MCF_UART_UBG10
	move.b D1,MCF_UART_UBG20
	/* Enable receiver and transmitter */
	move.b #MCF_UART_UCR_TX_ENABLED+MCF_UART_UCR_RX_ENABLED,D0
	move.b D0,MCF_UART_UCR0
	/*
	 * Enable Ethernet signals so that, if a cable is plugged into
	 * the ports, the lines won't be floating and potentially cause
	 * erroneous transmissions
	 */
#ifdef MCF547X /* MCF547X - FIREBEE */
	/* reduce power by disable clock of unused parts */
	move.l #~(MCF_PLL_SPCR_CRYENB+MCF_PLL_SPCR_CRYENA+MCF_PLL_SPCR_CN1EN+MCF_PLL_SPCR_USBEN+MCF_PLL_SPCR_FEC1EN+MCF_PLL_SPCR_CN0EN),D0
	and.l D0,MCF_PLL_SPCR
	/* Just FEC0, FEC1 PINS are GPIO excecpted MDC and MDIO */
	move.w #MCF_GPIO_PAR_FECI2CIRQ_PAR_E1MDC_EMDC \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E1MDIO_EMDIO \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E0MDC \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E0MDIO \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E0MII \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E07 \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_SDA \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_SCL \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_IRQ6 \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_IRQ5,D0
	move.w D0,MCF_GPIO_PAR_FECI2CIRQ
	move.b #MCF_GPIO_PAR_DMA_PAR_DREQ0(MCF_GPIO_PAR_DMA_PAR_DREQx_DREQ) \
	 + MCF_GPIO_PAR_DMA_PAR_DREQ1(MCF_GPIO_PAR_DMA_PAR_DREQx_DREQ) \
	 + MCF_GPIO_PAR_DMA_PAR_DACK0(MCF_GPIO_PAR_DMA_PAR_DACKx_DACK) \
	 + MCF_GPIO_PAR_DMA_PAR_DACK1(MCF_GPIO_PAR_DMA_PAR_DACKx_DACK),D0
	move.b D0,MCF_GPIO_PAR_DMA
	move.b #MCF_GPIO_PAR_PSC0_PAR_CTS0_CTS \
	 + MCF_GPIO_PAR_PSC0_PAR_RTS0_RTS \
	 + MCF_GPIO_PAR_PSC0_PAR_RXD0 \
	 + MCF_GPIO_PAR_PSC0_PAR_TXD0,D0 // Serial (debug)
	move.b D0,MCF_GPIO_PAR_PSC0
	move.b #MCF_GPIO_PAR_PSC1_PAR_CTS1_CTS \
	 + MCF_GPIO_PAR_PSC1_PAR_RTS1_RTS \
	 + MCF_GPIO_PAR_PSC1_PAR_RXD1 \
	 + MCF_GPIO_PAR_PSC1_PAR_TXD1,D0 // Serial (external)
	move.b D0,MCF_GPIO_PAR_PSC1
	move.b #MCF_GPIO_PAR_PSC2_PAR_CTS2_BCLK \
	 + MCF_GPIO_PAR_PSC2_PAR_RTS2_FSYNC \
	 + MCF_GPIO_PAR_PSC2_PAR_RXD2 \
	 + MCF_GPIO_PAR_PSC2_PAR_TXD2,D0 // AC97 audio codec
	move.b D0,MCF_GPIO_PAR_PSC2
	move.b #MCF_GPIO_PAR_PSC3_PAR_CTS3_GPIO \
	 + MCF_GPIO_PAR_PSC3_PAR_RTS3_GPIO \
	 + MCF_GPIO_PAR_PSC3_PAR_RXD3 \
	 + MCF_GPIO_PAR_PSC3_PAR_TXD3,D0 // IKBD (Eiffel)
	move.b D0,MCF_GPIO_PAR_PSC3
	move.w #MCF_GPIO_PAR_DSPI_PAR_CS5 \
	 + MCF_GPIO_PAR_DSPI_PAR_CS3_DSPICS \
	 + MCF_GPIO_PAR_DSPI_PAR_CS2_DSPICS \
	 + MCF_GPIO_PAR_DSPI_PAR_CS0_DSPICS \
	 + MCF_GPIO_PAR_DSPI_PAR_SCK_SCK \
	 + MCF_GPIO_PAR_DSPI_PAR_SIN_SIN \
	 + MCF_GPIO_PAR_DSPI_PAR_SOUT_SOUT,D0 
	move.w D0,MCF_GPIO_PAR_DSPI
	move.b #MCF_GPIO_PAR_TIMER_PAR_TIN3_IRQ \
	 + MCF_GPIO_PAR_TIMER_PAR_TOUT3 \
	 + MCF_GPIO_PAR_TIMER_PAR_TIN2_IRQ \
	 + MCF_GPIO_PAR_TIMER_PAR_TOUT2,D0
	move.b D0,MCF_GPIO_PAR_TIMER
	move.b #MCF_GPIO_PDDR_FEC1L_PDDR_FEC1L4 \
	 + MCF_GPIO_PDDR_FEC1L_PDDR_FEC1L3 \
	 + MCF_GPIO_PDDR_FEC1L_PDDR_FEC1L2  \
	 + MCF_GPIO_PDDR_FEC1L_PDDR_FEC1L1,D0
	move.b D0,MCF_GPIO_PDDR_FEC1L // OUT: 4=LED,3=PRG_DQ0,2=#FPGA_CONFIG,1=PRG_CLK(FPGA)
	/* Flexbus pins are enabled by default */
#ifdef DEBUG
	clr.b serial_mouse
#ifdef MCF547X
	move.b MCF_GPIO_PPDSDR_PCIBR,D0
	and.l #MCF_GPIO_PPDSDR_PCIBR_PPDSDR_PCIBR3,D0
	beq.s .pci_is_master
	lea debug141(PC),A0
	bra.s .pci_end_slave
.pci_is_master:	
	lea debug142(PC),A0
.pci_end_slave:
	bsr debug_display_string	 
#endif
	lea debug102(PC),A0
	bsr debug_display_string
	lea init_cf(PC),A0
	move.l A0,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	/* The FIREBEE has one 8MB flash */
	move.l #MCF_FBCS_CSAR_BA(BOOT_FLASH_BASE),D0
	move.l D0,MCF_FBCS_CSAR0
	move.l #MCF_FBCS_CSCR_SWS(0) \
	 + MCF_FBCS_CSCR_ASET(1) \
	 + MCF_FBCS_CSCR_RDAH(1) \
	 + MCF_FBCS_CSCR_WRAH(1) \
	 + MCF_FBCS_CSCR_AA \
	 + MCF_FBCS_CSCR_PS_16,D1 // cscr
	/* 
	 * Determine the necessary wait states based on the defined system
	 * period (XLB clock period) and the CLKIN to XLB ratio.
	 * The flash has a max access time of 120ns - AM29LV640D.
	 */
	moveq #24,D0
	move.l MCF_PCI_PCIGSCR,D2
	lsr.l D0,D2
	and.l #7,D2
	mulu #SYSTEM_PERIOD_X10,D2
	move.l #1200,D0
	.chip 68060
	divu D2,D0
	.chip 5200
	ext.l D0                 // ws
	moveq #10,D2
	asl.l D2,D0
	or.l D0,D1               // cscr
	move.l D1,MCF_FBCS_CSCR0
	move.l #MCF_FBCS_CSMR_BAM_8M+MCF_FBCS_CSMR_WP+MCF_FBCS_CSMR_V,D0
	move.l D0,MCF_FBCS_CSMR0
#ifdef DEBUG
	lea debug101(PC),A0
	bsr debug_display_string	
#endif
	/* FALCON I/O 1MB */
	move.l #MCF_FBCS_CSAR_BA(FPGA_CS1_BASE),D0
	cmp.l MCF_FBCS_CSAR1,D0
	beq.s .fbcs1_ok
	move.l D0,MCF_FBCS_CSAR1
	move.l #FPGA_CS1_ACCESS,D0
	move.l D0,MCF_FBCS_CSCR1
	move.l #MCF_FBCS_CSMR_BAM_1M+MCF_FBCS_CSMR_V,D0
	move.l D0,MCF_FBCS_CSMR1
#ifdef DEBUG
	lea debug146(PC),A0
	bsr debug_display_string
	move.l #MCF_FBCS_CSAR_BA(FPGA_CS1_BASE),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
.fbcs1_ok:
	/* ACP I/O 128MB */ 
	move.l #MCF_FBCS_CSAR_BA(FPGA_CS2_BASE),D0
	cmp.l MCF_FBCS_CSAR2,D0
	beq.s .fbcs2_ok
	move.l D0,MCF_FBCS_CSAR2
	move.l #FPGA_CS2_ACCESS,D0
	move.l D0,MCF_FBCS_CSCR2
	move.l #MCF_FBCS_CSMR_BAM_128M+MCF_FBCS_CSMR_V,D0
	move.l D0,MCF_FBCS_CSMR2
#ifdef DEBUG
	lea debug147(PC),A0
	bsr debug_display_string
	move.l #MCF_FBCS_CSAR_BA(FPGA_CS2_BASE),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
.fbcs2_ok:
	/* SRAM 256Kx16 */
	move.l #MCF_FBCS_CSAR_BA(FPGA_CS3_BASE),D0
	cmp.l MCF_FBCS_CSAR3,D0
	beq.s .fbcs3_ok
	move.l D0,MCF_FBCS_CSAR3
	move.l #FPGA_CS3_ACCESS,D0
	move.l D0,MCF_FBCS_CSCR3
	move.l #MCF_FBCS_CSMR_BAM_64M+MCF_FBCS_CSMR_V,D0
	move.l D0,MCF_FBCS_CSMR3
#ifdef DEBUG
	lea debug148(PC),A0
	bsr debug_display_string
	move.l #MCF_FBCS_CSAR_BA(FPGA_CS3_BASE),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
.fbcs3_ok:
	/* VIDEO RAM 128MB */ 
	move.l #MCF_FBCS_CSAR_BA(FPGA_CS4_BASE),D0
	cmp.l MCF_FBCS_CSAR4,D0
	beq.s .fbcs4_ok
	move.l D0,MCF_FBCS_CSAR4
	move.l #FPGA_CS4_ACCESS,D0
	move.l D0,MCF_FBCS_CSCR4
	move.l #MCF_FBCS_CSMR_BAM_1G+MCF_FBCS_CSMR_V,D0
	move.l D0,MCF_FBCS_CSMR4
#ifdef DEBUG
	lea debug149(PC),A0
	bsr debug_display_string
	move.l #MCF_FBCS_CSAR_BA(FPGA_CS4_BASE),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
.fbcs4_ok:
	/*
	 * Check to see if the SDRAM has already been initialized
	 * by a run control tool
	 */
	lea .copy_boot(PC),A0
	move.l A0,D0
	moveq #24,D1
	lsr.l D1,D0
	beq .sdram_controller_ok // started from RAM (test)
	move.l MCF_SDRAMC_SDCR,D0
	and.l #MCF_SDRAMC_SDCR_REF,D0
	bne .sdram_controller_ok
#ifdef DEBUG
	lea debug103(PC),A0
	bsr debug_display_string	
#endif
	/* Basic configuration and initialization - 8 x K4H510438 - DDR266 CL2 (512Mbits - 32M * 16) */
#if 1 // Fredi
	move.l #0x000002AA,D0   // SDRAMDS configuration
	move.l D0,MCF_SDRAMC_SDRAMDS
 	move.l #0x0000001A,D0   // SDRAM CS0 configuration (128Mbytes 0000_0000 - 07FF_FFFF)
	move.l D0,MCF_SDRAMC_CS0CFG
	move.l #0x0800001A,D0   // SDRAM CS1 configuration (128Mbytes 0800_0000 - 0FFF_FFFF)
	move.l D0,MCF_SDRAMC_CS1CFG 	
	move.l #0x1000001A,D0   // SDRAM CS2 configuration (128Mbytes 1000_0000 - 07FF_FFFF)
	move.l D0,MCF_SDRAMC_CS2CFG 	
	move.l #0x1800001A,D0   // SDRAM CS3 configuration (128Mbytes 1800_0000 - 1FFF_FFFF)
	move.l D0,MCF_SDRAMC_CS3CFG 	
	move.l #0x73622830,D0   // SDCFG1
	move.l D0,MCF_SDRAMC_SDCFG1 
	move.l #0x46770000,D0   // SDCFG2
	move.l D0,MCF_SDRAMC_SDCFG2 	
	move.l #0xE10D0002,D0   // SDCR + IPALL
	move.l D0,MCF_SDRAMC_SDCR 
	move.l #0x40010000,D0   // SDMR (write to LEMR)
	move.l D0,MCF_SDRAMC_SDMR 
	move.l #0x048D0000,D0   // SDRM (write to LMR)
	move.l D0,MCF_SDRAMC_SDMR 	
	move.l #0xE10D0002,D0   // SDCR + IPALL
	move.l D0,MCF_SDRAMC_SDCR 
	move.l #0xE10D0004,D0   // SDCR + IREF (first refresh)
	move.l D0,MCF_SDRAMC_SDCR 
	move.l #0xE10D0004,D0   // SDCR + IREF (second refresh)
	move.l D0,MCF_SDRAMC_SDCR 
	move.l #0x008D0000,D0   // SDMR (write to LMR)
	move.l D0,MCF_SDRAMC_SDMR 
	move.l #0x710D0F00,D0   // SDCR (lock SDMR and enable refresh)
	move.l D0,MCF_SDRAMC_SDCR 
#else // !Fredi
	move.l #MCF_SDRAMC_SDRAMDS_SB_E(MCF_SDRAMC_SDRAMDS_DRIVE_16MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_C(MCF_SDRAMC_SDRAMDS_DRIVE_16MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_A(MCF_SDRAMC_SDRAMDS_DRIVE_16MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_S(MCF_SDRAMC_SDRAMDS_DRIVE_16MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_D(MCF_SDRAMC_SDRAMDS_DRIVE_16MA),D0
	move.l D0,MCF_SDRAMC_SDRAMDS
	move.l #MCF_SDRAMC_CSnCFG_CSBA(SDRAM_BASE) \
	+ MCF_SDRAMC_CSnCFG_CSSZ(MCF_SDRAMC_CSnCFG_CSSZ_512MBYTE),D0
	move.l D0,MCF_SDRAMC_CS0CFG
	move.l #MCF_SDRAMC_SDCFG1_SRD2RW(7) \
	 + MCF_SDRAMC_SDCFG1_SWT2RD(3) \
	 + MCF_SDRAMC_SDCFG1_RDLAT(6) \
	 + MCF_SDRAMC_SDCFG1_ACT2RW(2) \
	 + MCF_SDRAMC_SDCFG1_PRE2ACT(1) \
	 + MCF_SDRAMC_SDCFG1_REF2ACT(9) \
	 + MCF_SDRAMC_SDCFG1_WTLAT(3),D0
	move.l D0,MCF_SDRAMC_SDCFG1
	move.l #MCF_SDRAMC_SDCFG2_BRD2PRE(4) \
	 + MCF_SDRAMC_SDCFG2_BWT2RW(6) \
	 + MCF_SDRAMC_SDCFG2_BRD2WT(3) \
	 + MCF_SDRAMC_SDCFG2_BL(7),D0
	move.l D0,MCF_SDRAMC_SDCFG2
	/* Precharge and enable write to SDMR */
	move.l #MCF_SDRAMC_SDCR_MODE_EN \
	 + MCF_SDRAMC_SDCR_CKE \
	 + MCF_SDRAMC_SDCR_DDR \
	 + MCF_SDRAMC_SDCR_MUX(1) \
	 + MCF_SDRAMC_SDCR_RCNT(15) \
	 + MCF_SDRAMC_SDCR_IPALL,D0
	move.l D0,MCF_SDRAMC_SDCR        
	/* Write extended mode register */
	lea MCF_SDRAMC_SDMR,A0
	move.l #MCF_SDRAMC_SDMR_BNKAD_LEMR \
	 + MCF_SDRAMC_SDMR_AD(0x0) \
	 + MCF_SDRAMC_SDMR_CMD,(A0)
	/* Write mode register and reset DLL */
	move.l #MCF_SDRAMC_SDMR_BNKAD_LMR \
	 + MCF_SDRAMC_SDMR_AD(0x123) \
	 + MCF_SDRAMC_SDMR_CMD,(A0)
	/* Execute a PALL command */
	lea MCF_SDRAMC_SDCR,A0
	move.l #MCF_SDRAMC_SDCR_IPALL,D0
	or.l D0,(A0)
	/* Perform two REF cycles */
	move.l #MCF_SDRAMC_SDCR_IREF,D0
	or.l D0,(A0)
	move.l #MCF_SDRAMC_SDCR_IREF,D0
	or.l D0,(A0)
	/* Write mode register and clear reset DLL */
	move.l #MCF_SDRAMC_SDMR_BNKAD_LMR \
	 + MCF_SDRAMC_SDMR_AD(0x023) \
	 + MCF_SDRAMC_SDMR_CMD,D0
	move.l D0,MCF_SDRAMC_SDMR
	/* Enable auto refresh and lock SDMR */
	move.l #~MCF_SDRAMC_SDCR_MODE_EN,D0
	and.l D0,(A0)
	move.l #MCF_SDRAMC_SDCR_REF+MCF_SDRAMC_SDCR_DQS_OE(0xF),D0
	or.l D0,(A0)
#endif // Fredi
#ifdef DEBUG	
	lea debug119(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDRAMDS,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug120(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_CS0CFG,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug121(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDMR,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug122(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDCR,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug123(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDCFG1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug124(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDCFG2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
.sdram_controller_ok:
	moveq #-1,D0
	move.l D0,MCF_SLT_SLTCNT1
	move.l #MCF_SLT_SCR_TEN + MCF_SLT_SCR_RUN,D0
	move.l D0,MCF_SLT_SCR1       // for delay_10us and rtc_init
	clr.b boot_tos
	/* Init FPGA */
	lea .copy_boot(PC),A0
	move.l A0,D0
	moveq #24,D1
	lsr.l D1,D0
#ifdef INIT_FPGA_FROM_RAM
	bne fpga_end                 // started from FLASH
	move.l A0,D0
	and.l #0xFF000000,D0
	lea (DATA_FPGA & 0xFFFFFF),A0 // start address fpga data
	add.l D0,A0
#else /* !INIT_FPGA_FROM_RAM */
	beq fpga_end                 // started from SDRAM
	move.l A0,D0
	and.l #0xFFF00000,D0
	lea BOOT_FLASH_BASE,A0
	cmp.l D0,A0                  // TOS replace dBUG or other
	bne fpga_end
	moveq #-1,D0
	move.b D0,boot_tos
	lea DATA_FPGA,A0             // start address fpga data
#endif /* INIT_FPGA_FROM_RAM */
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug143(PC),A0
	bsr debug_display_string
	move.l (SP),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,A0
#endif
	/* Invalidate the data, instruction, and branch caches */
	/* Turn on the branch cache and instruction cache */
	move.l #CF_CACR_DCINVA + CF_CACR_BEC + CF_CACR_BCINVA + CF_CACR_IEC + CF_CACR_ICINVA + CF_CACR_EUSP,D0
	movec D0,CACR
	lea MCF_GPIO_PODR_FEC1L,A1   // register address:write
	lea MCF_GPIO_PPDSDR_FEC1L,A2 // reads
	bclr #1,(A1)                 // clk low
	bclr #2,(A1)                 // #config=low 
test_nSTATUS:
		btst #0,(A2)	   // nSTATUS==0
		bne.s test_nSTATUS
	btst #5,(A2)                 // conf done==0
	bne.s test_nSTATUS
	bsr delay_10us
	bset #2,(A1)                 // #config=high
	bsr delay_10us
test_STATUS:
	btst #0,(A2)	                // status high?
	beq.s test_STATUS
	bsr delay_10us
	move.l A0,A3
	add.l #SIZE_FPGA,A3	
byte_send_loop:
		cmp.l A3,A0
		bhi.s fpga_error
		move.b (A0)+,D0
		moveq #7,D1
bit_send_loop:
			lsr.l #1,D0	   // bit loop
			bcs.s bit_is_1							
			bclr #3,(A1)
			bra.s bit_send
bit_is_1:
			bset #3,(A1)
bit_send:
			bset #1,(A1)    // clock=high
			bclr #1,(A1)    // clock=low
		subq.l #1,D1
		bpl.s bit_send_loop
	btst #5,(A2)                 // conf_done=high?
	beq.s byte_send_loop
	move.l #4000,D1
overclk:
		bset #1,(A1)   // clock=high
		nop
		bclr #1,(A1)   // clock=low
	subq.l #1,D1
	bgt.s overclk
#ifdef DEBUG	
	lea debug145(PC),A0
	bsr debug_display_string
	bra.s fpga_end
#endif
fpga_error:
#ifdef DEBUG	
	lea debug144(PC),A0
	bsr debug_display_string
#endif
fpga_end:
	moveq #0,D1
	moveq.l #0x55,D0
	move.w D0,ACP_VIDEO_PLL_CLK
	move.w ACP_VIDEO_PLL_CLK,D1 // 1st read not works
	move.w ACP_VIDEO_PLL_CLK,D1 // 2nd access works
	cmp.l D0,D1
	bne .has_no_pll // old hardware - list of clocks
#ifdef DEBUG	
	lea debug139(PC),A0
	bsr debug_display_string
#endif
	lea ACP_VIDEO_PLL_CONFIG,A0
	bsr wait_pll
	moveq #27,D0
	move.w D0,0x48(A0)  // loopfilter r
	bsr wait_pll
	moveq #1,D0
	move.w D0,0x08(A0)  // charge pump I
	bsr wait_pll
	moveq #12,D1
	move.w D1,0x00(A0)  // N counter high = 12
	bsr wait_pll
	move.w D1,0x40(A0)  // N counter low = 12
	bsr wait_pll
	move.w D0,0x114(A0) // ck1 bypass
	bsr wait_pll
	move.w D0,0x118(A0) // ck2 bypass
	bsr wait_pll
	move.w D0,0x11C(A0) // ck3 bypass
	bsr wait_pll
	move.w D0,0x10(A0)  // ck0 high = 1
	bsr wait_pll
	move.w D0,0x50(A0)  // ck0 low = 1
	bsr wait_pll
	move.w D0,0x144(A0) // M odd division
	bsr wait_pll
	move.w D0,0x44(A0)  // M low = 1
	bsr wait_pll
	move.w #150-1,D0
	move.w D0,0x04(A0)  // M high = 150MHz
	bsr wait_pll
	clr.b ACP_VIDEO_PLL_RECONFIG // set
.has_no_pll:
	/* Init video ram */
	move.l #ACP_CONFIG_ON + ACP_VCS + ACP_VCKE,D0
	swap D0
	move.w D0,ACP_VIDEO_CONTROL
	nop
	lea ACP_VIDEO_CFG,A0
	nop
	move.l #0x00050400,(A0) // IPALL
	nop
	move.l #0x00072000,(A0) // load EMR pll on
	nop
	move.l #0x00070122,(A0) // load MR: reset pll, cl=2 BURST=4lw
	nop
	move.l #0x00050400,(A0) // IPALL
	nop
	move.l #0x00060000,(A0) // auto refresh
	nop
	move.l #0x00060000,(A0) // auto refresh
	nop
	move.l #0x00070022,(A0) // load MR dll on
	nop
	move.l #ACP_FIFO_ON + ACP_REFRESH_ON + ACP_VCS + ACP_VCKE + ACP_VIDEO_DAC_ON,D0
	move.l D0,ACP_VIDEO_CONTROL
	tst.b boot_tos
	beq.s .normal_tos // TOS not started from 0xE0000000
	move.b MCF_GPIO_PPDSDR_PSC3PSC2,D0
	and.l #MCF_GPIO_PPDSDR_PSC3PSC2_PPDSDR_PSC3PSC27,D0
             bne.s .normal_tos // SW6 DDWN
	// check TOS if SW6 UP
	lea 0xE0400000,A0
	move.w (A0),D0
	move.l #0x602E,D1
	cmp.l D0,D1
	bne.s .normal_tos
	jmp (A0) // jump to TOS
.normal_tos:	
#else /* MCF548X - M5484LITE */
  	clr.b MCF_GPIO_PDDR_FECI2C;
	move.w #MCF_GPIO_PAR_FECI2CIRQ_PAR_E1MDC_EMDC \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E1MDIO_EMDIO \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E1MII \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E17 \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E0MDC \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E0MDIO \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E0MII \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_E07 \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_SDA \
              + MCF_GPIO_PAR_FECI2CIRQ_PAR_SCL \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_IRQ6 \
	 + MCF_GPIO_PAR_FECI2CIRQ_PAR_IRQ5,D0
	move.w D0,MCF_GPIO_PAR_FECI2CIRQ
	move.b #MCF_GPIO_PAR_PSC3_PAR_CTS3_BCLK \
	 + MCF_GPIO_PAR_PSC3_PAR_RTS3_FSYNC \
	 + MCF_GPIO_PAR_PSC3_PAR_RXD3 \
	 + MCF_GPIO_PAR_PSC3_PAR_TXD3,D0
	move.b D0,MCF_GPIO_PAR_PSC3 // AC97 audio codec
	/* TOUT0 as LED output */
	move.b #MCF_GPIO_PAR_DMA_PAR_DREQ0(MCF_GPIO_PAR_DMA_PAR_DREQx_TIN) \
	 + MCF_GPIO_PAR_DMA_PAR_DREQ1(MCF_GPIO_PAR_DMA_PAR_DREQx_TIN) \
	 + MCF_GPIO_PAR_DMA_PAR_DACK0(MCF_GPIO_PAR_DMA_PAR_DACKx_TOUT) \
	 + MCF_GPIO_PAR_DMA_PAR_DACK1(MCF_GPIO_PAR_DMA_PAR_DACKx_TOUT),D0
	move.b D0,MCF_GPIO_PAR_DMA
#ifdef DEBUG
	clr.b serial_mouse
	lea debug102(PC),A0
	bsr debug_display_string
	lea init_cf(PC),A0
	move.l A0,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug101(PC),A0
	bsr debug_display_string	
#endif
	/* The M5474LITE/M5484LITE has one 4MB boot flash */
	/* The M5485EVB has a 2MB boot flash */
	move.l #MCF_FBCS_CSAR_BA(BOOT_FLASH_BASE),D0
	move.l D0,MCF_FBCS_CSAR0
	move.l #MCF_FBCS_CSCR_SWS(0) \
	 + MCF_FBCS_CSCR_ASET(1) \
	 + MCF_FBCS_CSCR_RDAH(0) \
	 + MCF_FBCS_CSCR_WRAH(0) \
	 + MCF_FBCS_CSCR_WS(5) \
	 + MCF_FBCS_CSCR_AA \
	 + MCF_FBCS_CSCR_PS_16,D1 // cscr
	/* 
	 * Determine the necessary wait states based on the defined system
	 * period (XLB clock period) and the CLKIN to XLB ratio.
	 * The boot flash has a max access time of 110ns.
	 */
	moveq #24,D0
	move.l MCF_PCI_PCIGSCR,D2
	lsr.l D0,D2
	and.l #7,D2              // clk_ratio (2)
	mulu #SYSTEM_PERIOD,D2   // fb_period (100)
	move.l #110,D0
	.chip 68060
	divu D2,D0
	.chip 5200
	ext.l D0                 // ws
	moveq #10,D2
	asl.l D2,D0
	or.l D0,D1               // cscr
	move.l D1,MCF_FBCS_CSCR0
	/* MCF5485EVB - 2MB flash */
	move.l #MCF_FBCS_CSMR_BAM_2M+MCF_FBCS_CSMR_V,D0
	move.l MCF_SIU_JTAGID,D1 // check the processor
	and.l #MCF_SIU_JTAGID_PROCESSOR,D1
	cmp.l #MCF_SIU_JTAGID_MCF5485,D1
             beq.s .m5485evb          // M5485EVB
	/* the M5484LITE - 4MB flash */
	move.l #MCF_FBCS_CSMR_BAM_4M+MCF_FBCS_CSMR_V,D0
.m5485evb:
	move.l D0,MCF_FBCS_CSMR0
#ifdef DEBUG
	lea debug108(PC),A0
	bsr debug_display_string
#endif
             /* CPLD on FBCS4/5 */
	move.l #MCF_FBCS_CSAR_BA(FIRE_ENGINE_CS4_BASE),D0
	move.l D0,MCF_FBCS_CSAR4
	move.l #FIRE_ENGINE_CS4_ACCESS,D0
	move.l D0,MCF_FBCS_CSCR4
	move.l #MCF_FBCS_CSMR_BAM_256M+MCF_FBCS_CSMR_V,D0
	move.l D0,MCF_FBCS_CSMR4
	move.l #MCF_FBCS_CSAR_BA(FIRE_ENGINE_CS5_BASE),D0
	move.l D0,MCF_FBCS_CSAR5
	move.l #FIRE_ENGINE_CS5_ACCESS,D0
	move.l D0,MCF_FBCS_CSCR5
	move.l #MCF_FBCS_CSMR_BAM_256M+MCF_FBCS_CSMR_V,D0
	move.l D0,MCF_FBCS_CSMR5
	move.l MCF_PCI_PCIGSCR,D2
	moveq #24,D0
	lsr.l D0,D2
	moveq #7,D1
	and.l D1,D2
	move.b FIRE_ENGINE_CPLD_HW_REVISION,D0
	and.l #0xF0,D0
	cmp.l #0xA0,D0
	bne.s .bad_cpld
	move.w FIRE_ENGINE_CS5_BASE+0x1000000,D1
	moveq #2,D0
	cmp.l D2,D0
	bne.s .not_548x
	or.l #0xFFFF8000,D1
	bra.s .cpld_cpu
.not_548x:
	and.l #0x00007FFF,D1
.cpld_cpu:
	move.w D1,FIRE_ENGINE_CS5_BASE+0x1000000
.bad_cpld:
#ifdef DEBUG
	lea debug109(PC),A0
	bsr debug_display_string
	move.b FIRE_ENGINE_CPLD_HW_REVISION,D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug110(PC),A0
	bsr debug_display_string
	move.b FIRE_ENGINE_CPLD_SW_REVISION,D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	/*
	 * Check to see if the SDRAM has already been initialized
	 * by a run control tool
	 */
	lea .copy_boot(PC),A0
	move.l A0,D0
	moveq #24,D1
	lsr.l D1,D0
	beq .sdram_controller_ok // started from RAM (test)
//	move.l MCF_SDRAMC_SDCR,D0
//	and.l #MCF_SDRAMC_SDCR_REF,D0
//	bne .sdram_controller_ok
#ifdef DEBUG
	lea debug103(PC),A0
	bsr debug_display_string	
#endif
#if 1
	/* Basic configuration and initialization */
	move.l #MCF_SDRAMC_SDRAMDS_SB_E(MCF_SDRAMC_SDRAMDS_DRIVE_8MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_C(MCF_SDRAMC_SDRAMDS_DRIVE_8MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_A(MCF_SDRAMC_SDRAMDS_DRIVE_8MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_S(MCF_SDRAMC_SDRAMDS_DRIVE_8MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_D(MCF_SDRAMC_SDRAMDS_DRIVE_8MA),D0
	move.l D0,MCF_SDRAMC_SDRAMDS
	move.l #MCF_SDRAMC_CSnCFG_CSBA(SDRAM_BASE) \
	+ MCF_SDRAMC_CSnCFG_CSSZ(MCF_SDRAMC_CSnCFG_CSSZ_64MBYTE),D0
	move.l D0,MCF_SDRAMC_CS0CFG
	move.l #MCF_SDRAMC_SDCFG1_SRD2RW(5) \
	 + MCF_SDRAMC_SDCFG1_SWT2RD(3) \
	 + MCF_SDRAMC_SDCFG1_RDLAT(6) \
	 + MCF_SDRAMC_SDCFG1_ACT2RW(1) \
	 + MCF_SDRAMC_SDCFG1_PRE2ACT(2) \
	 + MCF_SDRAMC_SDCFG1_REF2ACT(7) \
	 + MCF_SDRAMC_SDCFG1_WTLAT(3),D0
	move.l D0,MCF_SDRAMC_SDCFG1
	move.l #MCF_SDRAMC_SDCFG2_BRD2PRE(4) \
	 + MCF_SDRAMC_SDCFG2_BWT2RW(6) \
	 + MCF_SDRAMC_SDCFG2_BRD2WT(3) \
	 + MCF_SDRAMC_SDCFG2_BL(7),D0
	move.l D0,MCF_SDRAMC_SDCFG2
	/* Precharge and enable write to SDMR */
	move.l #MCF_SDRAMC_SDCR_MODE_EN \
	 + MCF_SDRAMC_SDCR_CKE \
	 + MCF_SDRAMC_SDCR_DDR \
	 + MCF_SDRAMC_SDCR_MUX(1) \
	 + MCF_SDRAMC_SDCR_RCNT(15) \
	 + MCF_SDRAMC_SDCR_IPALL,D0
	move.l D0,MCF_SDRAMC_SDCR        
	/* Write extended mode register */
	lea MCF_SDRAMC_SDMR,A0
	move.l #MCF_SDRAMC_SDMR_BNKAD_LEMR \
	 + MCF_SDRAMC_SDMR_AD(0x0) \
	 + MCF_SDRAMC_SDMR_CMD,(A0)
	/* Write mode register and reset DLL */
	move.l #MCF_SDRAMC_SDMR_BNKAD_LMR \
	 + MCF_SDRAMC_SDMR_AD(0x123) \
	 + MCF_SDRAMC_SDMR_CMD,(A0)
	/* Execute a PALL command */
	lea MCF_SDRAMC_SDCR,A0
	move.l #MCF_SDRAMC_SDCR_IPALL,D0
	or.l D0,(A0)
	/* Perform two REF cycles */
	move.l #MCF_SDRAMC_SDCR_IREF,D0
	or.l D0,(A0)
	move.l #MCF_SDRAMC_SDCR_IREF,D0
	or.l D0,(A0)
	/* Write mode register and clear reset DLL */
	move.l #MCF_SDRAMC_SDMR_BNKAD_LMR \
	 + MCF_SDRAMC_SDMR_AD(0x023) \
	 + MCF_SDRAMC_SDMR_CMD,D0
	move.l D0,MCF_SDRAMC_SDMR
	/* Enable auto refresh and lock SDMR */
	move.l #~MCF_SDRAMC_SDCR_MODE_EN,D0
	and.l D0,(A0)
	move.l #MCF_SDRAMC_SDCR_REF+MCF_SDRAMC_SDCR_DQS_OE(0xF),D0
	or.l D0,(A0)
#else	// original dBUG config
	/* Basic configuration and initialization */
	move.l #MCF_SDRAMC_SDRAMDS_SB_E(MCF_SDRAMC_SDRAMDS_DRIVE_8MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_C(MCF_SDRAMC_SDRAMDS_DRIVE_8MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_A(MCF_SDRAMC_SDRAMDS_DRIVE_8MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_S(MCF_SDRAMC_SDRAMDS_DRIVE_8MA) \
	 + MCF_SDRAMC_SDRAMDS_SB_D(MCF_SDRAMC_SDRAMDS_DRIVE_8MA),D0
	move.l D0,MCF_SDRAMC_SDRAMDS
	move.l #MCF_SDRAMC_CSnCFG_CSBA(SDRAM_BASE) \
	+ MCF_SDRAMC_CSnCFG_CSSZ(MCF_SDRAMC_CSnCFG_CSSZ_64MBYTE),D0
	move.l D0,MCF_SDRAMC_CS0CFG
	move.l #MCF_SDRAMC_SDCFG1_SRD2RW(7) \
	 + MCF_SDRAMC_SDCFG1_SWT2RD(SDRAM_TWR+1) \
	 + MCF_SDRAMC_SDCFG1_RDLAT(SDRAM_CASL+2) \
	 + MCF_SDRAMC_SDCFG1_ACT2RW((SDRAM_TRCD/SYSTEM_PERIOD) - 1) \
	 + MCF_SDRAMC_SDCFG1_PRE2ACT((SDRAM_TRP/SYSTEM_PERIOD) - 1) \
	 + MCF_SDRAMC_SDCFG1_REF2ACT((SDRAM_TRFC/SYSTEM_PERIOD) - 1) \
	 + MCF_SDRAMC_SDCFG1_WTLAT(3),D0
	move.l D0,MCF_SDRAMC_SDCFG1
	move.l #MCF_SDRAMC_SDCFG2_BRD2PRE(4) \
	 + MCF_SDRAMC_SDCFG2_BWT2RW(6) \
	 + MCF_SDRAMC_SDCFG2_BRD2WT(3) \
	 + MCF_SDRAMC_SDCFG2_BL(7),D0
	move.l D0,MCF_SDRAMC_SDCFG2
	/* Precharge and enable write to SDMR */
	move.l #MCF_SDRAMC_SDCR_MODE_EN \
	 + MCF_SDRAMC_SDCR_CKE \
	 + MCF_SDRAMC_SDCR_DDR \
	 + MCF_SDRAMC_SDCR_MUX(1) \
	 + MCF_SDRAMC_SDCR_RCNT((SDRAM_TREFI/(SYSTEM_PERIOD*64))-1) \
	 + MCF_SDRAMC_SDCR_IPALL,D0
	move.l D0,MCF_SDRAMC_SDCR        
	/* Write extended mode register */
	lea MCF_SDRAMC_SDMR,A0
	move.l #MCF_SDRAMC_SDMR_BNKAD_LEMR \
	 + MCF_SDRAMC_SDMR_AD(0x0) \
	 + MCF_SDRAMC_SDMR_CMD,(A0)
	/* Write mode register and reset DLL */
	move.l #MCF_SDRAMC_SDMR_BNKAD_LMR \
	 + MCF_SDRAMC_SDMR_AD(0x163) \
	 + MCF_SDRAMC_SDMR_CMD,(A0)
	/* Execute a PALL command */
	lea MCF_SDRAMC_SDCR,A0
	move.l #MCF_SDRAMC_SDCR_IPALL,D0
	or.l D0,(A0)
	/* Perform two REF cycles */
	move.l #MCF_SDRAMC_SDCR_IREF,D0
	or.l D0,(A0)
	move.l #MCF_SDRAMC_SDCR_IREF,D0
	or.l D0,(A0)
	/* Write mode register and clear reset DLL  */
	move.l #MCF_SDRAMC_SDMR_BNKAD_LMR \
	 + MCF_SDRAMC_SDMR_AD(0x063) \
	 + MCF_SDRAMC_SDMR_CMD,D0
	move.l D0,MCF_SDRAMC_SDMR
	/* Enable auto refresh and lock SDMR */
	move.l #~MCF_SDRAMC_SDCR_MODE_EN,D0
	and.l D0,(A0)
	move.l #MCF_SDRAMC_SDCR_REF+MCF_SDRAMC_SDCR_DQS_OE(0xF),D0
	or.l D0,(A0)
#endif
#ifdef DEBUG	
	lea debug119(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDRAMDS,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug120(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_CS0CFG,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug121(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDMR,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug122(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDCR,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug123(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDCFG1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug124(PC),A0
	bsr debug_display_string
	move.l MCF_SDRAMC_SDCFG2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
.sdram_controller_ok:
	clr.b boot_tos
#ifdef DEBUG
	lea debug100(PC),A0
	bsr debug_display_string	
#endif
	/* FlexCAN config */
	/* TOUT2 pin for CANTX1, TIN2 pin for CANRX1 */ 
	move.b #MCF_GPIO_PAR_TIMER_PAR_TIN3_TIN \
	 + MCF_GPIO_PAR_TIMER_PAR_TOUT3 \
	 + MCF_GPIO_PAR_TIMER_PAR_TIN2_CANRX,D0
	move.b D0,MCF_GPIO_PAR_TIMER
	clr.w MCF_GPIO_PAR_DSPI
	/* FlexCAN 0 disabled, FlexCAN 1 reset */
	clr.w MCF_CAN_IMASK0
	move.l #0x1FFFFFFF,D0
	move.l D0,MCF_CAN_RXGMASK0
	move.l D0,MCF_CAN_RX14MASK0
	move.l D0,MCF_CAN_RX15MASK0  
	clr.l MCF_CAN_CANCTRL0
	move.l #MCF_CAN_CANMCR_MDIS \
	 + MCF_CAN_CANMCR_FRZ \
	 + MCF_CAN_CANMCR_HALT \
	 + MCF_CAN_CANMCR_MAXMB(15),D0
	move.l D0,MCF_CAN_CANMCR0
	clr.w MCF_CAN_IMASK1
	move.l #0x1FFFFFFF,D0
	move.l D0,MCF_CAN_RXGMASK1
	move.l D0,MCF_CAN_RX14MASK1
	move.l D0,MCF_CAN_RX15MASK1
	clr.l MCF_CAN_CANCTRL1
	move.l #MCF_CAN_CANMCR_FRZ \
	 + MCF_CAN_CANMCR_HALT \
	 + MCF_CAN_CANMCR_MAXMB(15),D0
	move.l D0,MCF_CAN_CANMCR1
/*	
	move.l #~MCF_CAN_CANMCR_FRZ,D0
	and.l D0,MCF_CAN_CANMCR1
	move.l #MCF_CAN_CANMCR_SOFTRST,D0
	or.l D0,MCF_CAN_CANMCR1
.test_reset_can:
	move.l MCF_CAN_CANMCR1,D1
	and.l D1,D0
	bne.s .test_reset_can
*/
#endif /* MCF547X */
#endif /* MCF5445X */
.begin_copy_tos:
#ifdef DEBUG
	lea debug104(PC),A0
	bsr debug_display_string	
	lea .copy_boot(PC),A0
	move.l A0,D0
	and.l #0xFF000000,D0
	lea (FLASH_TOS_FIRE_ENGINE & 0xFFFFFF),A0
	add.l A0,D0
	bsr debug_hex_long
	lea debug104b(PC),A0
	bsr debug_display_string	
	move.l #FLASH_ADR,D0     // TOS404
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char	
	moveq #10,D0
	bsr debug_display_char	
#endif
	/* copy FLASH in SDRAM */	
	lea .copy_boot(PC),A0
	move.l A0,D0
	and.l #0xFF000000,D0
	lea (FLASH_TOS_FIRE_ENGINE & 0xFFFFFF),A0
	add.l D0,A0
	lea FLASH_ADR,A1         // TOS404
	move.l A1,-(SP)          // dest patched in RAM
	move.l A0,-(SP)          // source
	move.l #0x80000,D1       // original TOS404 size (512KB)
	add.l D1,A0
	add.l D1,A1
	move.l #(FLASH_SIZE-0x80000)/16,D0
.copy_boot:
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
	subq.l #1,D0
	bgt.s .copy_boot
	move.l #CACHE_DISABLE_MODE,D0 // invalidate whole cache
	movec.l D0,CACR
	nop
	move.l #CACHE_ENABLE_MODE,D0 // enable caches
	movec.l D0,CACR
	bsr _apply_patches       // source/dest are on stack
	addq.l #8,SP
	lea 0,A1
.loop_cpushl_dc:
		dc.w 0xF469 // cpushl DC,(A1)
		addq.l #1,A1
		dc.w 0xF469 // cpushl DC,(A1)
		addq.l #1,A1
		dc.w 0xF469 // cpushl DC,(A1)
		addq.l #1,A1
		dc.w 0xF469 // cpushl DC,(A1)
		add.l #0x10-3,A1
	cmp.l #LAST_DCACHE_ADDR,A1
	ble.s .loop_cpushl_dc
	/* Init pseudo STRAM */
#if 0 // #ifdef MCF547X /* FIREBEE - FPGA mulation */
	lea 0xFFFF8007,A0
	move.b (A0),D0
	or.l #0x21,D0            // like the FALCON
	move.b D0,(A0)
	beq #6,D0                // F030 Start (0 - Cold, 1 - Warn)
	beq.s .init_stram_cf     // Cold
#endif /* MCF547X */
#ifdef MCF547X
	lea 0xFFFF8800,A0        // PSG sound
	moveq #7,D0
	move.b D0,(A0)           // ports A & B
	move.b #0xC0,D0          // are outputs
	move.b D0,2(A0)
	moveq #14,D0             // port A
	move.b D0,(A0)
	moveq #7,D0              // disable floppy
	move.b D0,2(A0)	
#endif /* MCF547X */
	move.l memvalid,D0
	cmp.l #0x752019F3,D0
	bne.s .init_stram_cf
	move.l memval2,D0
	cmp.l #0x237698AA,D0
	bne.s .init_stram_cf
	move.l memval3,D0
	cmp.l #0x5555AAAA,D0
	beq.s .no_init_stram_cf
.init_stram_cf:
#ifdef DEBUG
	lea debug105(PC),A0
	bsr debug_display_string
#endif
	bsr init_stram
.no_init_stram_cf:
	clr.l _hz_200
	clr.l con_state
	lea reset_board,A1
	lea 8,A0
	moveq #125,D0
.loop_init_vectors:
		move.l A1,(A0)+
		move.l A1,(A0)+
	subq.l #1,D0
	bpl.s .loop_init_vectors
	lea SDRAM_SIZE-SDRAM_RESERVED,A0
	move.l A0,ramtop
#ifdef DEBUG
	lea debug107(PC),A0
	bsr debug_display_string	
#endif
	lea _init_mmu,A0
	lea _update_tlb,A1
	lea _LZ_Uncompress,A2
	lea _LzmaDecodeProperties,A3
	lea _LzmaDecode,A4
	/* Start cf68klib in RAM */
	jmp CF68KLIB

#ifdef MCF547X
wait_pll:

	move.l D1,-(SP)
	move.l D0,-(SP)
	move.l MCF_SLT_SCNT1,D1
.wait_pll_loop:
		tst.w ACP_VIDEO_PLL_RECONFIG
		bpl.s .not_busy
		move.l D1,D0
		sub.l MCF_SLT_SCNT1,D0
	cmp.l #1000*SYSTEM_CLOCK,D0 // 1 mS
	bcs.s .wait_pll_loop
.not_busy:
	move.l (SP)+,D0
	move.l (SP)+,D1
	rts

#endif /* MCF547X */

tab_baudrate:
	dc.l 19200,9600,4800,3600,2400,2000,1800,1200,600,300
	//      200,   150,  134,  110,    75,   50
	dc.l 230400,115200,57600,38400,153600,76800
	
restart_emulation:

#ifdef DEBUG
	lea debug112(PC),A0
	bsr debug_display_string
	move.l (SP),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
.loop_null:
	bra.s .loop_null
#endif
reset_board:
#ifdef DEBUG
	lea debug151(PC),A0
	bsr debug_display_string
	move.w 6(SP),D0
	and.l #0xFFF,D0
	lsr.l #2,D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	lea library_data_area,A0 // 1024 bytes
	move.w 68(A0),D0         // reg_sr
	and.l #0x2000,D0
	beq.s .user_mode
	move.w #0x2700,SR        // mask Interrupts
.user_mode:
	lea access_fault_stack,SP
	bsr disable_interrupts
#ifdef MCF5445X
  	move.w #SCM_CWCR_CWE + SCM_CWCR_CWRI(2) + SCM_CWCR_CWT(8),D0
  	move.w D0,MCF_SCM_CWCR
#else /* MCF548X */
	clr.l MCF_GPT_GMS0 
	move.w #SYSTEM_CLOCK,D0
	swap D0
#ifdef DEBUG
	move.w #-1,D0 // 65535 uS
#else
	move.w #10,D0 // 10 uS
#endif
	move.l D0,MCF_GPT_GCIR0
	move.l #MCF_GPT_GMS_TMS_GPIO + MCF_GPT_GMS_CE + MCF_GPT_GMS_WDEN,D0
	move.l D0,MCF_GPT_GMS0 // reset watchdog
#endif /* MCF5454X */
.wait_reset_board:
	nop
	moveq #0x2E,D0
	move.b D0,MCF_UART_UTB0
	bra.s .wait_reset_board
#if 0
.super_ok:
#ifdef DEBUG
	lea debug111(PC),A0
	bsr debug_display_string
#endif
	move.w #0x2700,SR
	moveq #0,D0
	movec.l D0,VBR
	bsr disable_interrupts
#if 1
	/* Invalidate the data, instruction, and branch caches */
	/* Turn on the branch cache and instruction cache */
	move.l #CF_CACR_DCINVA + CF_CACR_BEC + CF_CACR_BCINVA + CF_CACR_IEC + CF_CACR_ICINVA + CF_CACR_EUSP,D0
#else
	/* Invalidate the data, instruction, and branch caches */
	move.l #CACHE_DISABLE_MODE,D0 
#endif
	movec.l D0,CACR
	move.l memvalid,D0
	cmp.l #0x752019F3,D0
	bne.s .init_stram
	move.l memval2,D0
	cmp.l #0x237698AA,D0
	bne.s .init_stram
	move.l memval3,D0
	cmp.l #0x5555AAAA,D0
	beq.s .no_init_stram
.init_stram:
#ifdef DEBUG
	lea debug105(PC),A0
	bsr debug_display_string
#endif
	bsr init_stram
.no_init_stram:
#ifdef DEBUG
	lea debug106(PC),A0
	bsr debug_display_string	
#endif
	jmp 0xE001DA
#endif /* if 0 */

disable_interrupts:

#ifdef MCF5445X
	lea MCF_INTC_ICR0+8,A0
	moveq #8,D0
.clear_int_loop:
		clr.b (A0)+
		addq.l #1,D0
	cmp.l #64,D0
	bcs.s .clear_int_loop
	lea MCF_INTC_ICR1+33,A0
	moveq #33,D0
.clear_int_loop2:
		clr.b (A0)+
		addq.l #1,D0
	cmp.l #57,D0
	bcs.s .clear_int_loop2
	moveq #-1,D0
	move.l D0,MCF_INTC_IMRL0
	move.l D0,MCF_INTC_IMRH0
	move.l D0,MCF_INTC_IMRL1
	move.l D0,MCF_INTC_IMRH1
#else /* MCF548X */
	lea MCF_INTC_ICR15,A0
	moveq #15,D0
.clear_int_loop:
		clr.b (A0)+
		addq.l #1,D0
	cmp.l #64,D0
	bcs.s .clear_int_loop
	moveq #-1,D0
	move.l D0,MCF_INTC_IMRL
	move.l D0,MCF_INTC_IMRH
#endif /* MCF5445X */
	rts

init_stram:

	lea FLASH_ADR,A4         // TOS404
	lea .started_from_flash(PC),A0
	move.l A0,D0
	moveq #24,D1
	lsr.l D1,D0
	bne.s .started_from_flash
	move.l A0,D0
	and.l #0xF00000,D0
	move.l D0,A4
.started_from_flash:
	move.l A4,D7             // end pseudo STRAM
	sub.l #0x400,D7
	moveq #0,D0
	move.l D0,D1
	move.l D0,D2
	move.l D0,D3
	move.l D0,A0
	move.l D1,A1
	move.l D2,A2
	move.l D3,A3
	lsr.l #6,D7              // / 64
.loop_init_stram:
		lea -32(A4),A4
		movem.l D0-D3/A0-A3,(A4)
		lea -32(A4),A4
		movem.l D0-D3/A0-A3,(A4)
	subq.l #1,D7
	bgt.s .loop_init_stram
	lea FLASH_ADR,A0         // TOS404
	move.l A0,phystop
	move.l #0x1357BD13,D0
	move.l D0,ramvalid
	rts
	
before_init_cookies:

#ifdef DEBUG
	lea debug113(PC),A0
	bsr debug_display_string
#endif
#if defined(COLDFIRE) && defined(MCF547X)
	jsr rtc_init             // PSC3 for RTC
#endif
	lea FLASH_ADR,A0
	lea 0x940,A1
	moveq #0x2F,D0
.copy_header_tos:
		move.b (A0)+,(A1)+
	subq.l #1,D0
	bpl.s .copy_header_tos
	lea .code_940(PC),A0
	lea 0x940,A1
	move.w (A0)+,D0
	move.w D0,-6(A1)
	move.l 4(A1),-4(A1)
	addq.l #4,A0
	move.w (A0)+,(A1)
	move.w 0x1E(A1),D0
	move.w D0,0x1C(A1)
	move.l A1,_sysbase
	lea 0x980,A0             // buffer cookies
	rts
.code_940:
	jmp 0x12345678
	bra.s .code_940
	
#ifdef DEBUG

debug100:	.ascii "FlexCAN config init"
	.byte 13,10,0
#ifdef MF5445X /* M54455EVB */
debug101:    .ascii "16MB boot flash base address init"
#else
#ifdef MCF547X /* MCF548X - FIREBEE */
debug101:    .ascii "8MB boot flash base address init"
#else /* MCF548X - M5484LITE */
debug101:    .ascii "4MB boot flash base address init"
#endif /* MCF547X */
#endif /* MCF5445X */
	.byte 13,10,0
debug102:	.asciz "TOS started from 0x"
debug103:	.ascii "SDRAM controller init"
	.byte 13,10,0
debug104:	.asciz "Copy FLASH in SDRAM, 0x"
debug104b:	.asciz " to 0x"
debug105:	.ascii "Init pseudo STRAM"
	.byte 13,10,0
debug106:	.ascii "Re-"
debug107:	.ascii "Start cf68klib"
	.byte 13,10,0
debug108:	.ascii "CPLD base address init"
	.byte 13,10,0
debug109:	.asciz "CPLD HW revision "
debug110:	.asciz "CPLD SW revision "
debug111:	.ascii "Reset"
	.byte 13,10,0
debug112:	.asciz "Null pointer ? return address 0x"
debug113:	.ascii "Init cookies"
	.byte 13,10,13,13,0
debug114:	.ascii "Install PCI BIOS"
	.byte 13,10,0
debug115:	.asciz "Add SDRAM ramtop: 0x"
debug116:	.ascii "Init SDRAM"
	.byte 13,10,0
debug117:	.ascii "Menu boot"
	.byte 13,10,0
debug119:	.asciz "SDRAMC_SDRAMDS 0x"
debug120:	.asciz "SDRAMC_CS0CFG 0x"
debug121:	.asciz "SDRAMC_SDMR 0x"
debug122:	.asciz "SDRAMC_SDCR 0x"
debug123:	.asciz "SDRAMC_SDCFG1 0x"
debug124:	.asciz "SDRAMC_SDCFG2 0x"
debug131:	.ascii "bootload floprd"
	.byte 13,10,0
debug132:	.ascii "Bad clock, fix clock from build date"
	.byte 13,10,0    
#if defined(MCF5445X) || defined(MCF547X)
debug133:	.ascii "IDE reset"
	.byte 13,10,0
#endif
debug134:	.ascii "bootload hdv_init"
	.byte 13,10,0
debug135:	.ascii "=> boot sector invalid"
	.byte 13,10,0
debug136:	.ascii "=> not loadable"
	.byte 13,10,0
debug137: 	.ascii "=> no drive"
	.byte 13,10,0
debug138:	.ascii "=> boot OK"
	.byte 13,10,0
#ifdef MCF547X
debug139:	.ascii "Init video PLL"
	.byte 13,10,0
debug140:	.ascii "IDE / CF ports swapped"
	.byte 13,10,0
debug141:	.ascii "PCI is slave"
	.byte 13,10,0
debug142:	.ascii "PCI is master"
	.byte 13,10,0
debug143:	.asciz "Init FPGA from 0x"
debug144:	.ascii "PPGA error"
	.byte 13,10,0
debug145:	.ascii "PPGA OK"
	.byte 13,10,0
debug146:	.asciz "Set FBCS FALCON I/O at 0x"
debug147:	.asciz "Set FBCS ACP I/O at 0x"
debug148:	.asciz "Set FBCS SRAM at 0x"
debug149:	.asciz "Set FBCS VIDEO RAM at 0x"
#endif /* MCF547X */
debug151:	.asciz "Reset from vector 0x"
debug152:	.asciz " Apply patch in 0x"
debug153:	.ascii "Check TOS CRC"
	.byte 13,10,0

	.align 2

debug_display_string:

	move.l D0,-(SP)
	move.l A0,-(SP)
.dds2:
		move.b (A0)+,D0
		beq.s .dds1
		bsr debug_display_char
	bra.s .dds2
.dds1:
	move.l (SP)+,A0
	move.l (SP)+,D0
	rts

debug_hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s debug_hex_word
	move.l (SP)+,D0
debug_hex_word:
	move.w D0,-(SP)
	lsr.l #8,D0          
	bsr.s debug_hex_byte     
	move.w (SP)+,D0
debug_hex_byte:
	move.w D0,-(SP)
	lsr.l #4,D0        
	bsr.s debug_hex_char      
	move.w (SP)+,D0      
debug_hex_char:
	and.l #0xF,D0      
	or.l #0x30,D0      
	cmp.l #0x3A,D0     
	bcs.s debug_display_char  
	addq.l #7,D0   

debug_display_char:

	tst.b serial_mouse
	bne.s .no_debug
	move.l D1,-(SP)
.wait_uart:
	move.b MCF_UART_USR0,D1
	and.l  #MCF_UART_USR_TXRDY,D1
	beq.s .wait_uart
	move.b D0,MCF_UART_UTB0 // send the character
	move.l (SP)+,D1
.no_debug:
	rts
	
#undef DEBUG
	
#endif /* DEBUG */

	.chip 68060
	
#else /* ATARI - 68060 */

init_060:                             // entry point

	move.w #0x2700,SR
#ifdef RESET
	move.w 0xFFFF8006,D0
	reset
#endif
	move.w 0xFFFF8006,D0
	move.w #7,0xFFFF8940	
	movec.l PCR,D0
	bclr #1,D0               // enable PFU
	bset #0,D0               // superscalar
	movec.l D0,PCR
	moveq #0,D0
	movec.l D0,VBR
	movec.l D0,CACR
	cinva BC
	pflusha
	move.l #0x00000108,D0    // default zone in copyback for 68060 EC
	movec.l D0,TCR
	move.l #0x0000E000,D0    // zone at $00000000 to $00FFFFFF in writethrough for 68060 EC
	movec.l D0,DTT1
	movec.l D0,ITT1
	move.l #0x807FE040,D0    // excepted external CI signal =>  cache inhibit imprecise
	                         // and the zone $80000000-$FFFFFFFF in cache inhibit precise
	movec.l D0,DTT0
	movec.l D0,ITT0
	cmp.l #0xFA52235F,0x00FA0000
	bne.s .no_cartrige
	lea .no_cartrige(PC),A6
	jmp 0x00FA0004
.no_cartrige:
	move.w #0x20,0xFFFF828C
	move.w #0x10,0xFFFF8282
	or.b #0x21,0xFFFF8007
	lea 0xFFFF8800,A0        // PSG
	move.b #7,(A0)           // ports A & B
	move.b #0xC0,2(A0)       // A & B are outputs
	move.b #14,(A0)          // port A
	move.b #7,2(A0)          // unselect floppy drives
#ifndef RESET
	clr.b 0xFFFF8901         // stops DMA sound
#endif
	lea _gpip_mfp,A0         // MFP
	moveq #23,D0
.clear_mfp:
		clr.b (A0)
		addq.l #2,A0
	subq.l #1,D0
	bpl.s .clear_mfp
#if 1	// this sequence crashes after mmu_init and cache enabled without SDRAM (see above)
	lea 0x00E00C3A(PC),A0
	lea 0xFFFF8240,A1        // VIDEL
	moveq #15,D0
.init_st_palette:
		move.w (A0)+,(A1)+
	dbf D0,.init_st_palette
	clr.b 0xFFFF8266
	lea 0xFFFF9800,A1
	moveq #15,D0
.init_f030_palette:
		move.l (A0)+,(A1)+
	dbf D0,.init_f030_palette
	clr.b 0xFFFF8260
	move.b #1,0xFFFF8201
	clr.b 0xFFFF8203
#endif
	lea 0x8870,SP            // stack
	lea reset_f030,A1        // clear lower memory and reset
	lea 8,A0                 // bus error / acces fault
	moveq #63,D0
.init_vectors_to_reset:
		move.l A1,(A0)+
	dbf D0,.init_vectors_to_reset
	lea _rte(PC),A1
	move.l A1,0x14           // TRAPV
	lea 0x60,A0              // INT0-7 auto vectors
	moveq #7,D0
.init_int_vectors_to_rte:
		move.l A1,(A0)+
	dbf D0,.init_int_vectors_to_rte
	move.w 0xFFFF8006,D0     // config
	lsr.w #8,D0
	lsr.b #1,D0
	move.b D0,D1
	and.b #1,D1
	lsr.b #2,D0
	and.b #6,D0
	or.b D0,D1
	move.l #0x80000,D0
	asl.l D1,D0
	cmp.b #5,D1
	bne.s .not_14mb
	move.l #0xE00000,D0      // max 14MB
.not_14mb:	
	move.l D0,phystop        // STRAM
	cpusha BC
	move.l #0xA0808000,D0    // caches on
	movec.l D0,CACR          // enable caches (else it's too slow for uncompress / copy / patch TOS)
	bsr ct60_configure_sdram
	move.l D0,ramtop         // negative values are errors (used by init_sdram)
	bpl.s .sdram_ok_init_mmu
	moveq #1,D0
	bsr code_led
	bra .normal_mmu_init     // error SDRAM => with STRAM
.sdram_ok_init_mmu:
	add.w #26,D0             // size 0-3 for 64MB-512MB
	moveq #0,D1
	bset D0,D1
	add.l #0x01000000,D1
	move.l D1,ramtop
	lea .no_ctpci_hardware(PC),A0
	move.l 8,A5              // bus error
	move.l A0,8
	move.l SP,A4             // save ssp
	clr.b PCI_CTPCI_CONFIG_ENABI // mask INTD /INTC / INTB / INTA / LINT
	move.l A5,8              // restore bus error
	move.l A4,SP             // restore ssp
	move.l #0x5F4C5A5F,D0    // _LZ_
	move.l #0x4C5A4D41,D1    // LZMA
	moveq #3,D2
	lea 0xED0000,A0          // 128KB / 192KB / 256KB / 320KB 
.test_lz_loop:
		cmp.l (A0),D0            // _LZ_
		beq.s .pci_drivers_found
		cmp.l (A0),D1            // LZMA
		beq.s .pci_drivers_found2
		sub.l #0x10000,A0
	dbf D2,.test_lz_loop
	bra .normal_mmu_init     // with SDRAM
.pci_drivers_found:
	bsr fast_test_sdram
	bpl.s .test_sdram_ok_init_mmu
	moveq #3,D0              // SDRAM read/write error
	bsr code_led
	bra .normal_mmu_init     // SDRAM failure
.test_sdram_ok_init_mmu:
	move.l 4(A0),-(SP)       // insize
	pea 0x1000000            // out: SDRAM temp
	pea 8(A0)                // in
	jsr _LZ_Uncompress
	move.l (SP)+,A0
	subq.l #8,A0
	addq.l #8,SP
	move.l D0,-(SP)          // size PCI drivers in a protected area
	move.l A0,-(SP)          // base PCI drivers
	bra.s .go_init_mmu
.pci_drivers_found2:
	bsr fast_test_sdram
	bmi.s .normal_mmu_init   // SDRAM failure
	link A6,#-24
	move.l A0,-(SP)          // base PCI drivers
             pea 8(A0)                // propsData
	pea -16(A6)              // Properties
	jsr _LzmaDecodeProperties
	addq.l #8,SP
	tst.l D0
	bne.s .error_header_lzma // error
	move.l #0x1100000,-4(A6) // Probs buffer, size = (LZMA_BASE_SIZE + (LZMA_LIT_SIZE << (lc + lp))) * sizeof(CProb)
	move.l (SP),A0           // base PCI drivers
	pea -24(A6)              // outSizeProcessed
	move.l #0x100000,-(SP)   // outSize
	pea 0x1000000            // outStream: SDRAM temp
	pea -20(A6)              // inSizeProcessed
	move.l 4(A0),-(SP)       // inSize
             pea 8+5(A0)              // inStream
	pea -16(A6)              // CLzmaDecoderState structure
	jsr _LzmaDecode
	lea 28(SP),SP
	move.l -24(A6),D1        // outSizeProcessed
.error_header_lzma:
	move.l (SP)+,A0
	unlk a6
	tst.l D0
	bne.s  .normal_mmu_init  // error
	move.l D1,-(SP)          // size PCI drivers in a protected area
	move.l A0,-(SP)          // base PCI drivers
	bra.s .go_init_mmu
.no_ctpci_hardware:
	move.l A5,8              // restore bus error
	move.l A4,SP             // restore ssp
.normal_mmu_init:
	clr.l -(SP)              // size PCI drivers
	clr.l -(SP)              // base PCI drivers
.go_init_mmu:
	jsr _init_mmu_tree
	addq.l #8,SP
	move.l phystop,D0
	sub.l #RESERVE_MEM_FONTS,D0 // for blitter2.S and more...
	move.l D0,phystop
	btst #6,0xFFFF8007       // F030 Start (0 - Cold, 1 - Warn)
	beq .no_reset_vector     // Cold
	cmp.l #0x752019F3,memvalid
	bne .no_reset_vector
	cmp.l #0x237698AA,memval2
	bne .no_reset_vector
	cmp.l #0x5555AAAA,memval3
	bne .no_reset_vector
	move.b memctrl,0xFFFF8001 // config STRAM
	cmp.l #0x31415926,resvalid
	bne .no_reset_vector
	move.l resvector,D0
	btst #0,D0
	bne .no_reset_vector    // bad address
#if 0
	cmp.l #0x58425241,-12(A0) // XBRA
	bne.s .check_ramvalid
	cmp.l #0x55534844,-8(A0) // USHD
	bne.s .check_ramvalid
	clr.l resvalid
	clr.l resvector
	bra.s .no_reset_vector
.check_ramvalid:
#endif
	cmp.l #0x1357BD13,ramvalid
	bne .not_sdram_found
	cmp.l #0x01000000,A0     // base SDRAM
	beq.s .no_reset_vector
	bra.s .jump_to_reset
.not_sdram_found:
	cmp.l #0x31415926,resvalid
	bne .no_reset_vector
	move.l resvector,D0
	btst #0,D0
	bne .no_reset_vector
.jump_to_reset:
	move.l D0,A0
	lea .not_sdram_found(PC),A6
	jmp (A0)                 // resvector
.no_reset_vector:
	lea 0xFFFF8800,A0        // PSG
	move.b #7,(A0)           // ports A & B
	move.b #0xC0,2(A0)       // A & B are outputs
	move.b #14,(A0)          // port A
	move.b #7,2(A0)          // unselect floppy drives
#if 0	// this sequence crashes after mmu_init and cache enabled without SDRAM (see before)
	lea 0x00E00C3A(PC),A0
	lea 0xFFFF8240,A1        // VIDEL
	moveq #15,D0
.init_st_palette:
		move.w (A0)+,(A1)+
	dbf D0,.init_st_palette2
	clr.b 0xFFFF8266
	lea 0xFFFF9800,A1
	moveq #15,D0
.init_f030_palette:
		move.l (A0)+,(A1)+
	dbf D0,.init_f030_palette2
	clr.b 0xFFFF8260
	move.b #1,0xFFFF8201
	clr.b 0xFFFF8203
#endif
	bset #6,0xFFFF8007       // F030 Start (0 - Cold, 1 - Warn)	
	beq.s .init_stram        // Cold
	cmp.l #0x752019F3,memvalid
	bne.s .init_stram
	cmp.l #0x237698AA,memval2
	bne.s .init_stram
	cmp.l #0x5555AAAA,memval3
	beq.s .no_init_stram
.init_stram:
	move.l phystop,D5        // save phystop
	move.l ramtop,D6         // save ramtop
	lea 0x400,A4             // start adress
	move.l D5,D4             // phystop
	add.l #RESERVE_MEM_FONTS,D4
	sub.l A4,D4              // - start address
	lsr.l #8,D4              // / 256 (block transfer)
	subq.l #1,D4             // for dbf
	moveq #0,D0
	moveq #0,D1
	moveq #0,D2
	moveq #0,D3
	move.l D0,A0
	move.l D1,A1
	move.l D2,A2
	move.l D3,A3
	lea 256(A4),A4
	lea 512,A5
.loop_init_stram:                     // init STRAM
		movem.l D0-D3/A0-A3,-(A4)
		movem.l D0-D3/A0-A3,-(A4)	
		movem.l D0-D3/A0-A3,-(A4)	
 		movem.l D0-D3/A0-A3,-(A4)
		movem.l D0-D3/A0-A3,-(A4)
		movem.l D0-D3/A0-A3,-(A4)	
		movem.l D0-D3/A0-A3,-(A4)	
 		movem.l D0-D3/A0-A3,-(A4)
 		add.l A5,A4 // next 256 bytes block
 	dbf D4,.loop_init_stram
	move.l D5,phystop        // restore phystop
	move.l D6,ramtop         // restore ramtop
	move.l D5,A0
	clr.l hardware_type(A0)
.no_init_stram:
	jmp 0x00E001DA

#endif /* COLDFIRE */

_rte:
	rte

#ifndef COLDFIRE

reset_f030:

	moveq #7,D0              // exception error
	bsr code_led
	jmp 0x00E0398C           // clear lower memory and reset

led_floppy:

	move.l A0,-(SP)
	move.l D0,-(SP)
	lea 0xFFFF8800,A0        // PSG sound
	moveq #7,D0
	move.b D0,(A0)           // ports A & B
	move.b #0xC0,D0          // are outputs
	move.b D0,2(A0)
	moveq #14,D0             // port A
	move.b D0,(A0)
	tst.l (SP)
	seq.b D0
	and.b #7,D0              // disable floppy: 7
	move.b D0,2(A0)
	move.l (SP)+,D0
	move.l (SP)+,A0
	rts

tempo_mfp:

	movem.l D0/A0,-(SP)
	lea _gpip_mfp,A0         // MFP 68901
	clr.b 24(A0)             // TACR stop timer A
	bclr #5,18(A0)           // IMRA interrupt mask timer A
	bclr #5,6(A0)            // IERA
	bclr #5,10(A0)           // IPRA no pending
	bclr #5,14(A0)           // ISRA
	moveq #49,D0             // 0.5 S 
.tm1:
		move.b #124,30(A0)       // TADR init timer A MFP for 10091 uS
		move.b #7,24(A0)         // TACR (prediv /200)
		bset #5,6(A0)            // IERA enable
		bclr #5,10(A0)           // IPRA clear timer A
.tm2:
		btst #5,10(A0)           // IPRA wait timer A
		beq.s .tm2
		clr.b 24(A0)             // TACR stop timer A
	dbf D0,.tm1
	movem.l (SP)+,D0/A0
	rts

code_led:
	// 1: SDRAM refresh error
	// 3: SDRAM read/write error
	// 6: Keyboard error
	// 7: Exception error
	// 9: BIOS checksum error
	// 11: Memory test error
	subq.l #1,D0
	bmi.s .cl1
.cl2:
		move.l D0,-(SP)
		moveq #1,D0
		bsr led_floppy	
		bsr tempo_mfp
		moveq #0,D0
		bsr led_floppy
		bsr tempo_mfp
		move.l (SP)+,D0
	dbf D0,.cl2
.cl1:
	bsr tempo_mfp
	bsr tempo_mfp
	bsr tempo_mfp
	bsr tempo_mfp
	rts	

#endif /* COLDFIRE */

_apply_patches:

#ifdef COLDFIRE
	lea -48(SP),SP
	movem.l D0-A3,(SP)
#else
	movem.l D0-A3,-(SP)
	moveq #15,D5      // retry counter
.retry_loop:
#endif /* COLDFIRE */
	move.l 52(SP),A0 // TOS source
	move.l 56(SP),A1 // target in RAM
	move.l #0x80000/16,D0 // 512K / 16, TOS size
.copy_original_tos:
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
		move.l (A0)+,(A1)+
	subq.l #1,D0
	bgt.s .copy_original_tos
	move.l 56(SP),A1         // target in RAM
	move.l #0x46FC2700,D0    // move.w #0x2700,SR  
	move.l #0x30388006,D1    // move.w 0xFFFF8006,D0
	move.l D0,0x30(A1)       // restore begin of TOS, jump used for boot outside the original TOS
	move.l D1,0x34(A1) 
	lea crctab(PC),A0
	moveq #0,D0
	moveq #0,D1              // crc
	moveq #0,D3
	move.l #0x80000-2,D7
.calc_crc_source:
		move.b (A1)+,D0
		move.w D1,D2          // crc
		lsr.l #8,D2
		eor.l D0,D2
		move.w (A0,D2.l*2),D3 // crc2		
		asl.l #8,D1           // crc
		eor.l D3,D1
	subq.l #1,D7
	bgt.s .calc_crc_source
	moveq #0,D0
	move.w (A1),D0   // crc at the end of the TOS
	and.l #0xFFFF,D1
	cmp.l D1,D0      // crc
	seq.b D6         // set if CRC is correct
#ifndef COLDFIRE
	dbeq D5,.retry_loop // cmp result BAD => try again (CT60 flash bad access ???)
	beq.s .crc_ok
	moveq #9,D0      // bad checksum
	bsr code_led
.crc_ok:
#endif
	move.l 56(SP),A0 // target in RAM
	lea _ct60tos_patch,A1
	lea _ct60tos_end_patch,A2
	move.l #0xFFFFFFFC,D1         // long mask alignment 
.loop_patch:
		move.l (A1)+,D0  // offset
		lea (A0,D0.l),A3 // TOS address
		move.l (A1)+,D0  // len
		ble.s .next_patch
#ifdef COLDFIRE
#if 0 // #ifdef DEBUG
		move.l D0,-(SP)
		move.l A0,-(SP)
		lea debug152(PC),A0
		bsr debug_display_string	
		move.l A1,D0
		subq.l #8,D0
		bsr debug_hex_long
		lea debug104b(PC),A0
		bsr debug_display_string	
		move.l A3,D0
		bsr debug_hex_long
		moveq #13,D0
		bsr debug_display_char	
		moveq #10,D0
		bsr debug_display_char
		move.l (SP)+,A0
		move.l (SP)+,D0
#endif
#endif
		btst #0,D0
		bne.s .copy_bytes_patch
		btst #1,D0
		bne.s .copy_word_patch
.copy_long_patch:
			move.l (A1)+,(A3)+ // copy patch
		subq.l #4,D0
		bgt.s .copy_long_patch
		bra.s .next_patch		
.copy_word_patch:
			move.w (A1)+,(A3)+ // copy patch
		subq.l #2,D0
		bgt.s .copy_word_patch
		bra.s .next_patch
.copy_bytes_patch:
			move.b (A1)+,(A3)+ // copy patch
		subq.l #1,D0
		bgt.s .copy_bytes_patch
.next_patch:
		move.l A1,D0
		addq.l #3,D0
		and.l D1,D0
		move.l D0,A1 // long alignment
	cmp.l A2,A1
	bcs.s .loop_patch
	move.l 56(SP),A1         // target in RAM
#ifdef COLDFIRE
	lea restart_emulation,A0
	move.l A0,D0
	and.l #0x000FFFFF,D0
	or.l #0x00E00000,D0
	move.l D0,4(A1)          // reset vector
	move.l D0,0x10(A1)       // header TOS404
	move.l D0,0x32(A1)       // JMP
	move.w #0x4EF9,D0
	move.w D0,0x30(A1)
	move.l A1,A0
	add.l #0x0008000C,A0     // init_cf
	move.w #0x60FE,(A0)      // bra.s
#endif
	lea ADDR_DATE,A0
	moveq #0,D0
	move.w 2(A0),D0          // month
	divu #10,D0
	moveq #0,D1
	move.w D0,D1
	asl.l #4,D1
	swap D0
	or.l D1,D0
	move.b D0,24(A1)         // month header
	moveq #0,D0
	move.w (A0),D0           // day
	divu #10,D0
	moveq #0,D1
	move.w D0,D1
	asl.l #4,D1
	swap D0
	or.l D1,D0
	move.b D0,25(A1)         // day header
	moveq #0,D0
	move.w 4(A0),D0          // year
	divu #100,D0
	move.l D0,D2
	and.l #0xFFFF,D0
	divu #10,D0
	moveq #0,D1
	move.w D0,D1
	asl.l #4,D1
	swap D0
	or.l D1,D0
	move.b D0,26(A1)         // year/100 header
	clr.w D2
	swap D2
	move.l D2,D0
	divu #10,D0
	moveq #0,D1
	move.w D0,D1
	asl.l #4,D1
	swap D0
	or.l D1,D0
	move.b D0,27(A1)         // year%100 header
	tst.b D6
	beq.s .source_crc_bad    // source is bad => don't update target (for TOS error message)
	/* update TOS404 checksum */
	lea crctab(PC),A0
	moveq #0,D0
	moveq #0,D1              // crc
	moveq #0,D3
	move.l #0x80000-2,D7
.calc_crc_dest:
		move.b (A1)+,D0
		move.w D1,D2          // crc
		lsr.l #8,D2
		eor.l D0,D2
		move.w (A0,D2.l*2),D3 // crc2		
		asl.l #8,D1           // crc
		eor.l D3,D1
	subq.l #1,D7
	bgt.s .calc_crc_dest
	move.w D1,(A1)           // update crc at the end of the TOS
.source_crc_bad:
#ifdef COLDFIRE
	movem.l (SP),D0-A3
	lea 48(SP),SP
#else
	movem.l (SP)+,D0-A3
#endif
	rts

#ifdef COLDFIRE

check_tos_crc:

#ifdef DEBUG
	lea debug153(PC),A0
	bsr debug_display_string	
#endif
	move.l 4(SP),A0          // TOS address
	move.l 8(SP),D2          // size
	move.w 12(SP),A1         // incr
	moveq #0,D0
	moveq #0,D1
	moveq #0,D3
	moveq #0,D4
	lea crctab(PC),A2
.loop_tos_crc:
	             move.w D0,D1
		lsl.l #8,D0
		lsr.l #8,D1
		move.b (A0),D3
		add.l A1,A0
		eor.l D3,D1
		move.w (A2,D1.l*2),D4
		eor.l D4,D0
	subq.l #1,D2
	bgt.s .loop_tos_crc
	rts

#endif /* COLDFIRE */

crctab:
	dc.w 0x0000,0x1021,0x2042,0x3063,0x4084,0x50a5,0x60c6,0x70e7
	dc.w 0x8108,0x9129,0xa14a,0xb16b,0xc18c,0xd1ad,0xe1ce,0xf1ef
	dc.w 0x1231,0x0210,0x3273,0x2252,0x52b5,0x4294,0x72f7,0x62d6
	dc.w 0x9339,0x8318,0xb37b,0xa35a,0xd3bd,0xc39c,0xf3ff,0xe3de
	dc.w 0x2462,0x3443,0x0420,0x1401,0x64e6,0x74c7,0x44a4,0x5485
	dc.w 0xa56a,0xb54b,0x8528,0x9509,0xe5ee,0xf5cf,0xc5ac,0xd58d
	dc.w 0x3653,0x2672,0x1611,0x0630,0x76d7,0x66f6,0x5695,0x46b4
	dc.w 0xb75b,0xa77a,0x9719,0x8738,0xf7df,0xe7fe,0xd79d,0xc7bc
	dc.w 0x48c4,0x58e5,0x6886,0x78a7,0x0840,0x1861,0x2802,0x3823
	dc.w 0xc9cc,0xd9ed,0xe98e,0xf9af,0x8948,0x9969,0xa90a,0xb92b
	dc.w 0x5af5,0x4ad4,0x7ab7,0x6a96,0x1a71,0x0a50,0x3a33,0x2a12
	dc.w 0xdbfd,0xcbdc,0xfbbf,0xeb9e,0x9b79,0x8b58,0xbb3b,0xab1a
	dc.w 0x6ca6,0x7c87,0x4ce4,0x5cc5,0x2c22,0x3c03,0x0c60,0x1c41
	dc.w 0xedae,0xfd8f,0xcdec,0xddcd,0xad2a,0xbd0b,0x8d68,0x9d49
	dc.w 0x7e97,0x6eb6,0x5ed5,0x4ef4,0x3e13,0x2e32,0x1e51,0x0e70
	dc.w 0xff9f,0xefbe,0xdfdd,0xcffc,0xbf1b,0xaf3a,0x9f59,0x8f78
	dc.w 0x9188,0x81a9,0xb1ca,0xa1eb,0xd10c,0xc12d,0xf14e,0xe16f
	dc.w 0x1080,0x00a1,0x30c2,0x20e3,0x5004,0x4025,0x7046,0x6067
	dc.w 0x83b9,0x9398,0xa3fb,0xb3da,0xc33d,0xd31c,0xe37f,0xf35e
	dc.w 0x02b1,0x1290,0x22f3,0x32d2,0x4235,0x5214,0x6277,0x7256
	dc.w 0xb5ea,0xa5cb,0x95a8,0x8589,0xf56e,0xe54f,0xd52c,0xc50d
	dc.w 0x34e2,0x24c3,0x14a0,0x0481,0x7466,0x6447,0x5424,0x4405
	dc.w 0xa7db,0xb7fa,0x8799,0x97b8,0xe75f,0xf77e,0xc71d,0xd73c
	dc.w 0x26d3,0x36f2,0x0691,0x16b0,0x6657,0x7676,0x4615,0x5634
	dc.w 0xd94c,0xc96d,0xf90e,0xe92f,0x99c8,0x89e9,0xb98a,0xa9ab
	dc.w 0x5844,0x4865,0x7806,0x6827,0x18c0,0x08e1,0x3882,0x28a3
	dc.w 0xcb7d,0xdb5c,0xeb3f,0xfb1e,0x8bf9,0x9bd8,0xabbb,0xbb9a
	dc.w 0x4a75,0x5a54,0x6a37,0x7a16,0x0af1,0x1ad0,0x2ab3,0x3a92
	dc.w 0xfd2e,0xed0f,0xdd6c,0xcd4d,0xbdaa,0xad8b,0x9de8,0x8dc9
	dc.w 0x7c26,0x6c07,0x5c64,0x4c45,0x3ca2,0x2c83,0x1ce0,0x0cc1
	dc.w 0xef1f,0xff3e,0xcf5d,0xdf7c,0xaf9b,0xbfba,0x8fd9,0x9ff8
	dc.w 0x6e17,0x7e36,0x4e55,0x5e74,0x2e93,0x3eb2,0x0ed1,0x1ef0

init_sdram:

#ifdef COLDFIRE
	lea -56(SP),SP
	movem.l D1-A6,(SP)
	move.w SR,D0
	move.w D0,-(SP)
	or.l #0x700,D0           // mask interrupts
	move.w D0,SR
	move.l #CACHE_DISABLE_MODE,D0 // invalidate whole cache
	movec.l D0,CACR
	nop
	move.l #CACHE_ENABLE_MODE,D0 // enable caches
	movec.l D0,CACR
	move.w (SP)+,D0
	move.w D0,SR
	pea linea000(PC)
	move.w #47,-(SP)         // TRAP #15
	move.w #5,-(SP)          // Setexec
	trap #13
	addq.l #8,SP             // MAC instruction on Coldfire use opcodes 0xAxxx
#ifdef MCF547X
	move.l #0x5F535749,D0    // _SWI
	bsr get_cookie
	move.l A0,D0
	beq.s .no_swi_cookie    // no _SWI cookie
	moveq #1,D1
	move.b boot_tos,D0
	and.l D0,D1
	move.l 4(A0),D0         // value
	and.l #0xC0,D0
	or.l D1,D0
	move.l D0,4(A0)
.no_swi_cookie:
#endif /* MCF547X */
#ifdef MCF5445X /* M54455EVB */
	moveq #2,D0              // SDRAM 256MB
#else
#ifdef MCF547X /* MCF547X - FIREBEE */
	moveq #3,D0              // SDRAM 512MB
#else /* MCF548X - M5484LITE */
	moveq #0,D0              // SDRAM 64MB
#endif /* MCF547X */
#endif /* MCF5445X */
	clr.l ramtop
#else /* ATARI */
	movem.l D1-A6,-(SP)
	bclr #5,0xFFFFFA07       // mask timer A
	move.w SR,-(SP)
	or #0x700,SR             // no interrupts
	cpusha BC
	move.l #0xA0808000,D0    // caches on
	movec.l D0,CACR
	move.w (SP)+,SR
	move.l #0x00E00FB6,8     // set access fault vector
	move.b 0xFFFF8006,D0
	lsr.b #6,D0              // 0:ST mono, 1:ST col, 2:VGA, 3:TV
	cmp.b #2,D0              // VGA
	beq.s .ok_screen
	move.l #0x5F465251,D0    // _FRQ cookie, internal clock
	bsr get_cookie
	cmp.l #32,D0
	bls.s .ok_screen
	move.l #0x5F465245,D0    // _FRE cookie, external clock
	bsr get_cookie
	cmp.l #32,D0
	bne.s .ok_screen
	bset #0,0xFFFF820A       // external clock
.ok_screen:	
	clr.l -(SP)
	move.l #CT60_BLITTER_SPEED,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	btst #0,D0
	beq.s .blitter_slow
	bset #2,0xFFFF8007       // blitter 16 MHz
.blitter_slow:
	move.l ramtop,D0         // negative value is error code of ct60_configure_sdram from init_060
	bpl.s .no_error_cfg_sdram
	clr.l ramtop             // if error clear ramtop
.no_error_cfg_sdram:	
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D1
	and.b #0xF,D1
	cmp.b #0x3,D1            // LSHIFT-RSHIFT
	beq .test_ok             // boot without SDRAM
#endif /* COLDFIRE */
	clr.l ramvalid
	move.l D0,D5             // save return value of ct60_configure_sdram
	bmi .error_pci           // error SDRAM => no PCI
#ifdef COLDFIRE
	move.l #SDRAM_SIZE-SDRAM_RESERVED,D1
	move.l D1,ramtop
#else
	moveq #26,D1
	lsr.l D1,D5
	subq.l #1,D5             // for boot info, size 0-3 for 64MB-512MB
	lea size_info(PC),A0
	move.b (A0,D5),D5
#endif
	move.l #0x1357BD13,ramvalid
#ifndef COLDFIRE
	/* Clock generator */
	moveq #0,D4              // error code programmable clock generator
	clr.l -(SP)
	move.l #CT60_CLOCK,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
//	cmp.l #MIN_FREQ_DALLAS/2,D0
	cmp.l #MIN_FREQ,D0
	bcs.s .bad_clock
	cmp.l #MAX_FREQ,D0
	bhi.s .bad_clock
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D1
	and.b #0xF,D1
	cmp.b #4,D1              // CTRL
	beq.s .reset_clock
	cmp.b #8,D1              // ALT
	beq.s .reset_clock
	move.l D0,-(SP)          // frequency
	clr.l -(SP)
	move.l #CT60_USER_DIV_CLOCK,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	move.l D0,D2             // divider
	move.l (SP)+,D0          // frequency
	cmp.l #2,D2
	blt.s .default_div_freq
	cmp.l #6,D2
	ble.s .div_freq_ok
.default_div_freq:
	move.l D0,D1             // frequency
	divu #33000,D1           // PCI clock
	moveq #0,D2
	move.w D1,D2
	swap D1
	tst.w D1
	beq.s .div_freq_ok 
	addq.l #1,D2             // divider
.div_freq_ok:
	moveq #CT60_CLOCK_WRITE_RAM,D1
	bsr ct60_configure_clock
	bra.s .delay_stable_clock
.reset_clock:
 	moveq #0,D2
	moveq #0,D1
	move.w #CT60_CLOCK_RESET+CYPRESS,D0
	bsr ct60_rw_clock
.delay_stable_clock:
	move.l D0,D4             // error code programmable clock generator
	bsr tempo_20ms
.bad_clock:
#endif /* !COLDFIRE */
	/* PCI */
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D1
	and.b #0xF,D1
	cmp.b #4,D1              // CTRL
	beq .error_pci
	cmp.b #8,D1              // ALT
	beq .error_pci
#ifdef COLDFIRE
#ifdef DEBUG
	lea debug114(PC),A0
	bsr debug_display_string
#endif
#endif
	move.w #1,-(SP)
	move.w #299,-(SP)        // install PCI BIOS
	trap #14
	addq.l #4,SP
	tst.w D0
	sgt.b D7
	and.l #1,D7              // (0) from reset, (1) from CTRL-ALT-DEL
#ifdef COLDFIRE
	tst.w D0
	bmi .error_pci           // no PCI ???
#ifdef MCF547X
	move.l #~ACP_CF_IDE,D0
	and.l D0,ACP_CONFIG      // no swap IDE address
//	move.l #ACP_DD_HD+ACP_IDE_INT_ENABLE+ACP_SCSI_INT_ENABLE,D0
	move.l #ACP_IDE_INT_ENABLE+ACP_SCSI_INT_ENABLE,D0
	or.l D0,ACP_CONFIG       // floppy DD/HD selected by 0xFFFF860F
	clr.l -(SP)
	move.l #CT60_PARAM_CTPCI,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	btst #0,D0
	bne.s .no_swap_ide_cf
	move.l #ACP_CF_IDE,D0
	or.l D0,ACP_CONFIG       // swap IDE address
#ifdef DEBUG
	lea debug140(PC),A0
	bsr debug_display_string
#endif
.no_swap_ide_cf:	
#endif /* MCF547X */
#else /* !COLDFIRE - 68060 */
	tst.w D0
	bmi.s .no_change_swap_ide_ctpci // no CTPCI
	clr.l -(SP)
	move.l #CT60_PARAM_CTPCI,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	tst.l D0
	bmi.s .no_change_swap_ide_ctpci
	btst #0,D0
	beq.s .no_swap_ide_ctpci
	clr.l _nideon // swap IDE ports, the new IDE on the CTPCI on primary, F030 IDE is secondary
	clr.l _oideoff
	bra.s .no_change_swap_ide_ctpci
.no_swap_ide_ctpci:	
	clr.l _nideoff // no swap IDE ports, the new IDE on the CTPCI is seconday, F030 IDE is the primary (default)
	clr.l _oideon
.no_change_swap_ide_ctpci:
#endif /* COLDFIRE */
	bsr test_pci_drivers
	bne.s .error_pci
	move.l phystop,A1
	move.l hardware_type(A1),-(SP) // hardware flags
	move.l D7,-(SP)          // (0) from reset, (1) from CTRL-ALT-DEL
	jsr 4(A0)                // drivers PCI in flash, init_devices
	addq.l #8,SP
	tst.l D0
	bne.s .graphic_card
	move.l _v_bas_ad,D0
	cmp.l #0x1000000,D0
	bcc.s .graphic_card
.error_pci:
	/* display boot infos */
	moveq #0x1B,D0           // clear screen
	bsr display_char
	moveq #0x45,D0
	bsr display_char
.graphic_card:
	bsr spaces
	lea message0(PC),A0
	cmp.w #2,0x3E86          // number of planes
	bhi.s .title_colors
	lea message0b(PC),A0
.title_colors:
	bsr display_string_single
	bsr spaces
#ifdef COLDFIRE
#ifdef MCF5445X
	move.w MCF_CCM_CIR,D0
	and.l #CCM_CIR_PIN_MASK,D0
	lea message8(PC),A0
	cmp.l #CCM_CIR_PIN_MCF54454,D0
	beq.s .v4m
	lea message8a(PC),A0
	cmp.l #CCM_CIR_PIN_MCF54453,D0
	beq.s .v4m
	lea message8b(PC),A0
	cmp.l #CCM_CIR_PIN_MCF54452,D0
	beq.s .v4m
	lea message8c(PC),A0
	cmp.l #CCM_CIR_PIN_MCF54451,D0
	beq.s .v4m
	lea message8d(PC),A0
	cmp.l #CCM_CIR_PIN_MCF54450,D0	
	lea message10(PC),A0
.v4m:
#else /* MCF548X */
	move.l MCF_SIU_JTAGID,D0
	and.l #MCF_SIU_JTAGID_PROCESSOR,D0
	lea message8(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5485,D0
	beq .v4e
	lea message8a(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5484,D0
	beq.s .v4e
	lea message8b(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5483,D0
	beq.s .v4e
	lea message8c(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5482,D0
	beq.s .v4e
	lea message8d(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5481,D0
	beq.s .v4e
	lea message8e(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5480,D0
	beq.s .v4e
	lea message9(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5475,D0
	beq.s .v4e
	lea message9a(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5474,D0
	beq.s .v4e
	lea message9b(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5473,D0
	beq.s .v4e
	lea message9c(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5472,D0
	beq.s .v4e
	lea message9d(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5471,D0
	beq.s .v4e
	lea message9e(PC),A0
	cmp.l #MCF_SIU_JTAGID_MCF5470,D0
	beq.s .v4e
	lea message10(PC),A0
.v4e:
#endif /* MCF5445X */
#else /* ATARI */
	movec.l PCR,D0
	swap D0
	lea message8(PC),A0      // 68060
	cmp.w #0x0430,D0
	beq.s .full_060
	lea message9(PC),A0      // 68EC060 / 68LC060
	cmp.w #0x0431,D0
	beq.s .ec_lc_060
	lea message10(PC),A0
.full_060:
.ec_lc_060:
#endif /* COLDFIRE */
	bsr display_string
#ifdef COLDFIRE
#ifdef MCF5445X
	move.w MCF_CCM_CIR,D0	
	and.l #CCM_CIR_PRN_MASK,D0 // revision
#else /* MCF548X */
	move.l MCF_SIU_JTAGID,D0
	and.l #MCF_SIU_JTAGID_REV,D0
	moveq #28,D1
	lsr.l D1,D0              // revision
#endif /* MCF548X */
#else /* ATARI */
	clr.w D0
	swap D0
	lsr.w #8,D0              // revision
#endif /* COLDFIRE */
	divu #10,D0
	and.w #7,D0
	beq.s .rev_less_10
	or.w #0x30,D0
	bsr display_char
.rev_less_10:
	swap D0
	or.w #0x30,D0
	bsr display_char
#ifndef COLDFIRE
	movec.l PCR,D0
	move.l D0,D1
	lsr.l #8,D1
	lea message11(PC),A0
	and.w #0x1FF,D1
	beq.s .display_mask      // revision 0, mask D00W/D11W
	lea message13(PC),A0
	cmp.w #2,D1              // revision 2, mask F84W
	beq.s .display_mask
	lea message14(PC),A0	
	cmp.w #6,D1              // revision 1,5 mask F43G/G65V 
	bcc.s .display_mask      // revision 6 and more mask E41J ?
	bset #5,D0               // disable store/load bypass (masks 1,3,4,5)
	movec.l D0,PCR
	lea message12(PC),A0
.display_mask:
	btst #8,D1
	bne.s .mask_060_ok       // mask info only for 060 full
	bsr display_string
.mask_060_ok:
#endif /* !COLDFIRE */
	link A6,#-6
	bsr measure_cpu_frequency
	move.l phystop,A0
	move.l D0,measure_clock(A0)
	move.l D0,-4(A6)         // CPU frequency in MHz * 10
#ifdef COLDFIRE
	move.l #0x5F43465F,D0    // _CF_		
#else /* 68060 */
#if 1
	cmp.l #750,D0
	bcs.s .lower_75mhz
	move.l #0x5F504349,D0    // cookie _PCI
	bsr get_cookie
	move.l A0,D0
	beq.s .lower_75mhz       // no CTPCI registers
	moveq #ITF+4,D0          // IDE Fast Timmings + normal space for CTPCI
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	cmp.l #PCI_MEMORY_OFFSET_2,pci_memory_offset(A0)
	bne.s .normal_space
	cmp.l #PCI_MEMORY_SIZE_2,pci_memory_size(A0)
	bne.s .normal_space
	cmp.l #PCI_IO_OFFSET_2,pci_io_offset(A0)
	bne.s .normal_space
	cmp.l #PCI_IO_SIZE_2,pci_io_size(A0)
	bne.s .normal_space
	bclr #2,D0               // enable all space for CTPCI
.normal_space:
#endif
	move.l D0,PCI_CTPCI_CONFIG_RESET
.lower_75mhz:
#endif
	move.l #0x43543630,D0    // CT60
#endif /* COLDFIRE */
	bsr get_cookie
	move.l A0,D0
	beq.s .no_cookie_ct60
	move.l -4(A6),4(A0)      // value
.no_cookie_ct60:
	move.l -4(A6),D0
	clr.w -2(A6)
	cmp.w #1000,D0
	bcs.s .low_100
	move.l D0,-(SP)
	moveq #0x20,D0
	bsr display_char
	move.l (SP)+,D0
.low_100:     
	lea -6(A6),A0
	moveq #4,D1
	bsr conv_ascii_value
	move.b -3(A6),-2(A6)
	move.b #0x2E,-3(A6)
	bsr display_string_single
	unlk A6
	lea message18(PC),A0     // MHz
	bsr display_string_single
#ifndef COLDFIRE
	moveq #0,D6              // flag display hardware
	move.l phystop,A0
	move.l hardware_type(A0),D2
	move.l #ABE_SDR_7,D1
	and.l D2,D1
	beq.s .no_abe_sdr_7
	bsr display_1st_hardware_info
	lea message39(PC),A0
	bsr display_string_single
.no_abe_sdr_7:
	move.l #0x5F504349,D0    // cookie _PCI
	bsr get_cookie
	move.l A0,D0
	beq.s .no_pci_cookie
	moveq #CTPCI_1ABCD,D1
	and.l D2,D1
	bne.s .no_ctpci_1e
	bsr display_1st_hardware_info
	lea message39a(PC),A0
	moveq #CTPCI_1M,D1
	and.l D2,D1
	beq.s .no_ctpci_1x
	lea message39b(PC),A0
	moveq #CTPCI_1N,D1
	and.l D2,D1
	beq.s .no_ctpci_1x
	lea message39c(PC),A0
.no_ctpci_1x:
	bsr display_string_single	
.no_ctpci_1e:
	move.l #ETHERNAT,D1
	and.l D2,D1
	beq.s .no_ethernat
	bsr display_1st_hardware_info
	lea message40(PC),A0
	bsr display_string_single	
.no_ethernat:
	move.l #SUPERVIDEL,D1
	and.l D2,D1
	beq.s .no_pci_cookie
	bsr display_1st_hardware_info
	lea message40a(PC),A0
	bsr display_string_single	
.no_pci_cookie:
	clr.l -(SP)
	move.l #CT60_CLOCK,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
//	cmp.l #MIN_FREQ_DALLAS/2,D0
	cmp.l #MIN_FREQ,D0
	bcs .no_pclock_display
	cmp.l #MAX_FREQ,D0
	bhi .no_pclock_display
	bsr display_1st_hardware_info
	tst.l D4                 // error code programmable clock generator
	bpl.s .pclock_ok
	moveq #0x20,D0
	bsr display_char
	lea error12(PC),A0
	cmp.w #CT60_CALC_CLOCK_ERROR,D4
	beq.s .pclock_error
	lea error11(PC),A0
.pclock_error:
	bsr display_string
	bra.s .no_pclock_display
.pclock_ok:
	lea message99(PC),A0
	bsr display_string_single
	cmp.l #100000,D0         // KHz
	bcs.s .low_100000
	move.l D0,-(SP)
	moveq #0x20,D0
	bsr display_char
	move.l (SP)+,D0
.low_100000:	
	link A6,#-8
	clr.w -2(A6)
	lea -8(A6),A0
	moveq #6,D1
	bsr conv_ascii_value
	move.b -4(A6),-3(A6)
	move.b -5(A6),-4(A6)
	move.b #0x2E,-5(A6)
	bsr display_string_single
	unlk A6
	lea message18(PC),A0     // MHz
	bsr display_string_single
.no_pclock_display:
#endif /* !COLDFIRE */
	lea crlf(PC),A0
	bsr display_string_single
#ifdef COLDFIRE
	move.l D5,D0             // return value from ct60_configure_sdram
#else
	move.l D5,D0             // return value from ct60_configure_sdram
	bpl .ok_sdram
	move.w D0,D1
	lea error9(PC),A0
	cmp.w #CT60_REFRESH_RATE_ERROR,D1
	beq.s .error_sdram
	lea error8(PC),A0
	cmp.w #CT60_SDRAM_TYPE_ERROR,D1
	beq.s .error_sdram
	lea error7(PC),A0	
	cmp.w #CT60_VOLTAGE_ERROR,D1
	beq.s .error_sdram
	lea error6(PC),A0	
	cmp.w #CT60_DATA_WIDTH_ERROR,D1
	beq.s .error_sdram
	lea error5(PC),A0	
	cmp.w #CT60_BURST_LENGTH_ERROR,D1
	beq.s .error_sdram
	lea error4(PC),A0	
	cmp.w #CT60_MOD_DENSITY_ERROR,D1
	beq.s .error_sdram
	lea error3(PC),A0	
	cmp.w #CT60_NUM_BANK_ERROR,D1
	beq.s .error_sdram
	lea error2(PC),A0	
	cmp.w #CT60_CHIP_DENSITY_ERROR,D1
	beq.s .error_sdram
	lea error1(PC),A0	
.error_sdram:
	bsr crlf_spaces
	bsr display_string
.error_sdram2:
	clr.l ramtop
	clr.l ramvalid
	bsr wait_key
.display_values_sdram:
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
	bsr display_char
	bsr display_infos_sdram
	bsr wait_key
	cmp.b #0x77,D0           // w
	bne.s .halt_no_sdram
.write_eeprom_sdram:
	lea message97(PC),A0     // write register
	bsr display_string	
	bsr get_value
	move.w D0,D4             // address
	lea message98(PC),A0     // value
	bsr display_string
	bsr get_value
	move.w D0,D1             // data
	move.w D4,D0             // address
	bsr write_i2c_sdram
	bra.s .display_values_sdram
.halt_no_sdram:
	bra.s .halt_no_sdram
#endif /* COLDFIRE */
.ok_sdram:
	move.l D0,D4
	bsr crlf_spaces
	lea message1(PC),A0
	bsr display_string_single
	lea message5(PC),A0
	cmp.w #3,D4
	beq.s .ok_sdram2
	lea message4(PC),A0
	cmp.w #2,D4
	beq.s .ok_sdram2
	lea message3(PC),A0
	cmp.w #1,D4
	beq.s .ok_sdram2
	lea message2(PC),A0
.ok_sdram2:
	bsr display_string_single
	lea message6(PC),A0
	bsr display_string
#ifndef COLDFIRE
	bsr fast_test_sdram
	bmi.s .error_test
	moveq #18,D0             // CAS laytency
	bsr read_i2c_sdram
	bmi.s .test_ok           // error
	btst #1,D0               // CAS latency = 2
	bne.s .test_ok
	moveq #9,D0              // cycle time
	bsr read_i2c_sdram
	bmi .test_ok             // error
	cmp.b #0x70,D0
	bls.s .test_ok           // PC150
	lea message54(PC),A0     // warning CAS latency
	bsr display_string
 	bra.s .test_ok
.error_test:
	move.l A0,-(SP)
	bsr crlf_spaces
	lea error10(PC),A0
	bsr display_string
	move.l (SP)+,D0
	bsr hex_long
	moveq #6,D0              // module data width
	bsr read_i2c_sdram
	bmi .error_sdram2        // error
	cmp.w #0x40,D0           // 64
	beq.s .data_width_ok
	lea message55(PC),A0
	bsr display_string
	bra .error_sdram2
.data_width_ok:
	moveq #18,D0             // CAS laytency
	bsr read_i2c_sdram
	bmi .error_sdram2        // error
	btst #1,D0               // CAS latency = 2
	bne .error_sdram2
	lea message54(PC),A0
	bsr display_string
	bra .error_sdram2
.test_ok:
#endif /* COLDFIRE */
	bsr crlf_spaces
	clr.l -(SP)
	move.l #CT60_SAVE_NVRAM_1,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	swap D0
	cmp.w #0x4E56,D0             // NV magic code
	bne .no_nvm_read_saved
	lea message51(PC),A0         // NVRAM restored
	bsr display_string
.no_nvm_read_saved:
	lea crlf(PC),A0
	bsr display_string_single
#if defined(COLDFIRE) && (defined(MCF5445X) || (defined MCF547X))
#ifdef DEBUG
	lea debug133(PC),A0
	bsr debug_display_string
#endif
	jsr ide_reset
#endif
	movem.l (SP)+,D1-A6
	rts

#ifndef COLDFIRE /* ATARI - CT60 */

size_info:
	dc.b 0,1,1,2,2,2,2,3

display_1st_hardware_info:

	tst.w D6
	bne.s .no_1st_hardware_info
	moveq #-1,D6                 // flag display hardware
	bsr crlf_spaces
	lea message38(PC),A0
	bsr display_string_single
.no_1st_hardware_info:
	rts

fast_test_sdram:

	movem.l D0-D3/A0-A1,-(SP)
	cmp.l #0x1357BD13,ramvalid
	bne .bypass_test
	cmp.l #0x752019F3,memvalid
	bne.s .make_test
	cmp.l #0x237698AA,memval2
	bne.s .make_test
	cmp.l #0x5555AAAA,memval3
	beq .bypass_test
.make_test:
	lea 0x1000000,A0
	move.l #0x01234567,D0
	move.l #0x89ABCDEF,D1
	move.l ramtop,A1         // end SDRAM
.loop_sdram_write:
		movem.l D0-D1,(A0)       // long
		movem.w D0-D1,8(A0)      // word
		move.b D0,12(A0)         // byte
		rol.l #3,D0
		rol.l #3,D1
		add.l #0x2000,A0         // 8K step
	cmp.l A1,A0
	bcs.s .loop_sdram_write
	lea 0x1000000,A0
	move.l #0x01234567,D0
	move.l #0x89ABCDEF,D1
	cpusha BC                // flush
.loop_sdram_test:
		movem.l (A0),D2-D3
		cmp.l D0,D2
		bne.s .error_test_sdram
		cmp.l D1,D3
		bne.s .error_test_sdram
		movem.w 8(A0),D2-D3
		cmp.w D0,D2
		bne.s .error_test_sdram
		cmp.w D1,D3
		bne.s .error_test_sdram
		cmp.b 12(A0),D0
		bne.s .error_test_sdram
		rol.l #3,D0
		rol.l #3,D1
		add.l #0x2000,A0         // 8K step
	cmp.l A1,A0
	bcs.s .loop_sdram_test
.bypass_test:
	moveq #0,D0
	movem.l (SP)+,D0-D3/A0-A1
	rts
.error_test_sdram:
	moveq #-1,D0
	movem.l (SP)+,D0-D3/A0-A1
	rts

display_infos_sdram:

	movem.l D0-D2/A0-A1,-(SP)
	link A6,#-134
	clr.w -130(A6)
	lea -128(A6),A0
	bsr ct60_read_info_sdram
	bmi .error_eeprom_sdram
	lea -128(A6),A1
	lea message20(PC),A0     // type
	bsr display_string
	moveq #0,D0
	move.b 2(A1),D0
	lea -133(A6),A0
	moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	cmp.b #4,2(A1)
	bne.s .no_sdram
	lea message20b(PC),A0
	bsr display_string_single
.no_sdram:	
	lea message21(PC),A0     // row
	bsr display_string
	moveq #0,D0
	move.b 3(A1),D0
	lea -133(A6),A0
	moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message22(PC),A0     // column
	bsr display_string
	moveq #0,D0
	move.b 4(A1),D0
	lea -133(A6),A0
	moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message23(PC),A0     // banks
	bsr display_string
	moveq #0,D0
	move.b 5(A1),D0
	lea -133(A6),A0
	moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message24(PC),A0     // data width
	bsr display_string
	moveq #0,D0
	move.w 6(A1),D0
	ror.w #8,D0
	lea -134(A6),A0
	moveq #4,D1
	bsr conv_ascii_value_optimized
	lea -134(A6),A0
	bsr display_string_single
	lea message24b(PC),A0
	bsr display_string_single
	lea message25(PC),A0     // voltage
	bsr display_string
	moveq #0,D0
	move.b 8(A1),D0
	lea -133(A6),A0
	moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	cmp.b #1,8(A1)
	bne.s .not_lvttl
	lea message25b(PC),A0
	bsr display_string_single
.not_lvttl:	
	lea message26(PC),A0     // cycle time
	bsr display_string
	move.b 9(A1),D0
	bsr display_value_ns_10
	lea message73(PC),A0
	cmp.b #0xA0,9(A1)
	bcc.s .pc100
	lea message74(PC),A0
.pc100:
	bsr display_string_single
	lea message27(PC),A0     // access from clock
	bsr display_string
	move.b 10(A1),D0
	bsr display_value_ns_10
	lea message28(PC),A0     // configuration type
	bsr display_string
	moveq #0,D0
	move.b 11(A1),D0
	lea -133(A6),A0
	moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message60(PC),A0
	move.b 11(A1),D0
	beq.s .parity
	lea message61(PC),A0
	cmp.b #1,D0
	beq.s .parity
	lea message62(PC),A0
	cmp.b #2,D0
	bne.s .no_ecc	
.parity:
	bsr display_string
.no_ecc:	
	lea message29(PC),A0     // refresh
	bsr display_string
	lea message63(PC),A0
	move.b 12(A1),D0
	and.b #0x7F,D0
	beq.s .refresh_rate
	lea message64(PC),A0
	cmp.b #1,D0
	beq.s .refresh_rate
	lea message65(PC),A0
	cmp.b #2,D0
	beq.s .refresh_rate
	lea message66(PC),A0
	cmp.b #3,D0
	beq.s .refresh_rate
	lea message67(PC),A0
	cmp.b #4,D0
	beq.s .refresh_rate
	lea message68(PC),A0
	cmp.b #5,D0
	bne.s .no_refresh_rate	
.refresh_rate:
	bsr display_string_single
	tst.b 12(A1)
	bpl.s .no_refresh_rate
	lea message71(PC),A0
	bsr display_string_single
	bra.s .end_refresh_rate
.no_refresh_rate:
	moveq #0x24,D0
	bsr display_char
	move.b 12(A1),D0
	bsr hex_byte		
.end_refresh_rate:
	lea message30(PC),A0     // banks device
	bsr display_string
	moveq #0,D0
	move.b 17(A1),D0
	lea -133(A6),A0
	moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -133(A6),A0
	bsr display_string_single
	lea message53(PC),A0     // CAS latency
	bsr display_string
	move.b 18(A1),D0
	add.b D0,D0
	bsr display_latency
	lea message56(PC),A0     // CS latency
	bsr display_string
	move.b 19(A1),D0
	bsr display_latency
	lea message57(PC),A0     // WE latency
	bsr display_string
	move.b 20(A1),D0
	bsr display_latency	
	lea message37(PC),A0     // module attributes
	bsr display_string
	move.b 21(A1),D0
	bsr hex_byte
	tst.b 21(A1)
	bne.s .not_unbuffered
	lea message72(PC),A0
	bsr display_string
.not_unbuffered:	
	lea message31(PC),A0     // precharge time
	bsr display_string
	move.b 27(A1),D0
	bsr display_value_ns
	lea message32(PC),A0     // minimum row active
	bsr display_string
	move.b 28(A1),D0
	bsr display_value_ns
	lea message33(PC),A0     // minimum RAS to CAS delay
	bsr display_string
	move.b 29(A1),D0
	bsr display_value_ns
	lea message70(PC),A0     // minimum RAS pulse width
	bsr display_string
	move.b 30(A1),D0
	bsr display_value_ns
	lea message34(PC),A0     // bank density
	bsr display_string
	moveq #0,D0
	move.b 31(A1),D0
	asl.w #2,D0
	lea -134(A6),A0
	moveq #4,D1
	bsr conv_ascii_value_optimized
	lea -134(A6),A0
	bsr display_string_single
	lea message69(PC),A0
	bsr display_string
	lea message35(PC),A0     // ID
	bsr display_string
	move.b 64(A1),D0
	bsr hex_byte
	moveq #0x20,D0
	bsr display_char
	lea list_manufacturers(PC),A0
.manufacturer_loop1:
		move.b (A0)+,D0
		beq.s .manufacturer_not_found
		cmp.b 64(A1),D0
		bne.s .next_manufacturer
		moveq #31,D1
		bra.s .manufacturer_loop2
.next_manufacturer:
		tst.b (A0)+
		bne.s .next_manufacturer
	bra.s .manufacturer_loop1
.manufacturer_not_found:
	lea 65(A1),A0            // manufacturer
	moveq #6,D1
.manufacturer_loop2:
		move.b (A0)+,D0
		beq.s .end_manufacturer
		cmp.b #0x20,D0
		bcs.s .end_manufacturer
		cmp.b #0x7F,D0
		bcc.s .end_manufacturer
		bsr display_char
	dbf D1,.manufacturer_loop2
.end_manufacturer:	
	lea message58(PC),A0     // part number
	bsr display_string
	lea 73(A1),A0
	moveq #17,D1
.part_number:
		move.b (A0)+,D0
		bsr display_char
	dbf D1,.part_number	
	lea message36(PC),A0     // date
	bsr display_string
	moveq #0,D0
	move.b 93(A1),D0         // week
	move.b D0,D1
	and.b 94(A1),D1
	cmp.b #0xFF,D1
	beq .no_date
	cmp.b #0x52,94(A1)       // week 52
	bls.s .date_jedec_format
	lea -132(A6),A0          // IBM format
	moveq #2,D1
	bsr conv_ascii_value_optimized
	lea -132(A6),A0          // date
	bsr display_string_single
	moveq #0x2F,D0
	bsr display_char
	moveq #2,D1
	bsr conv_ascii_value_optimized
	bsr display_string_single
	moveq #0,D0
	move.b 94(A1),D0         // year
	add.w #1900,D0
	lea -134(A6),A0
	moveq #4,D1
	bsr conv_ascii_value_optimized
	lea -134(A6),A0	
	bsr display_string_single
	bra.s .no_date
.date_jedec_format:
	move.b 94(A1),D0         // week
	bsr hex_byte
	moveq #0x2F,D0
	bsr display_char
	cmp.b #0x90,93(A1)       // year
	bcs.s .year_20xx
	moveq #0x31,D0
	bsr display_char
	moveq #0x39,D0
	bsr display_char         // 19xx
	bra.s .year
.year_20xx:
	moveq #0x32,D0
	bsr display_char
	moveq #0x30,D0
	bsr display_char         // 20xx	
.year:		
	move.b 93(A1),D0         // year	
	bsr hex_byte
.no_date:	
//	lea -128(A6),A1
//	moveq #7,D1
//	bsr dump
.error_eeprom_sdram:
	unlk A6
	movem.l (SP)+,D0-D2/A0-A1
	rts

#endif

#ifdef DEBUG
dump:
	movem.l D0-D2/A0-A1,-(SP)
.loop_dump1:
		lea crlf(PC),A0
		bsr display_string_single
#ifdef COLDFIRE
		bsr debug_display_string
#endif		
		moveq #15,D2
.loop_dump2:
			move.b (A1)+,D0
			bsr hex_byte
#ifdef COLDFIRE
			move.b -1(A1),D0
			bsr debug_hex_byte
#endif
			moveq #0x20,D0
			bsr display_char
#ifdef COLDFIRE
			bsr debug_display_char
#endif		
		dbf D2,.loop_dump2
		lea -16(A1),A1
		moveq #15,D2
.loop_dump3:
			move.b (A1)+,D0
			cmp.b #0x20,D0
			bcs.s .dump_bad_char
			cmp.b #0x7F,D0
			bcs.s .dump_ok
.dump_bad_char:
			moveq #0x2E,D0
.dump_ok:
			bsr display_char
#ifdef COLDFIRE
			bsr debug_display_char
#endif	
		dbf D2,.loop_dump3
	dbf D1,.loop_dump1
	movem.l (SP)+,D0-D2/A0-A1
	rts
#endif

measure_cpu_frequency:                 // return CPU frequency in MHz * 10

#ifdef COLDFIRE
	lea -12(SP),SP
	movem.l D1-D3,(SP)
	move.w SR,D2
	move.w D2,-(SP)
#else
	movem.l D1-D3,-(SP)
	move.w SR,-(SP)
#endif /* COLDFIRE */
	move.w #0x2500,SR
	moveq #0,D0
	moveq #9,D2
	move.l _hz_200,D1
.sync_timer:
	cmp.l _hz_200,D1
	beq.s .sync_timer
.next_mes:
		moveq #0,D3
		move.l _hz_200,D1
.loop_mes:
		addq.l #1,D3
		cmp.l _hz_200,D1
		beq.s .loop_mes
		cmp.l D0,D3
		bcs.s .not_maxi
		move.l D3,D0
.not_maxi:
#ifdef COLDFIRE
	subq.l #1,D2
	bpl.s .next_mes
	move.w (SP)+,D2
	move.w D2,SR
	divu #125,D0             // MHz * 10
#else
	dbf D2,.next_mes
	move.w (SP)+,SR
	divu #250,D0             // MHz * 10
#endif /* COLDFIRE */
	swap D0
	tst.w D0
	beq.s .end_mes
	add.l #0x10000,D0
.end_mes:
	clr.w D0
	swap D0
	tst.l D0
#ifdef COLDFIRE
	movem.l (SP),D1-D3
	lea 12(SP),SP
#else
	movem.l (SP)+,D1-D3
#endif /* COLDFIRE */
	rts

get_cookie:

	move.l D1,-(SP)
	move.l D0,D1
	move.l cookie,D0
	beq.s .cookie_not_found
	move.l D0,A0
.loop_cookie:
		tst.l (A0)
		beq.s .cookie_not_found
		cmp.l (A0),D1
		bne.s .next_cookie
		move.l 4(A0),D0
		bra.s .end_cookie
.next_cookie:
		addq.l #8,A0
	bra.s .loop_cookie
.cookie_not_found:
	moveq #0,D0
	move.l D0,A0
.end_cookie:
	move.l (SP)+,D1
	tst.l D0
	rts

#ifdef USE_ATARI_IO
tab_boot_order:
	.word message100-tab_boot_order
	.word message101-tab_boot_order
	.word message102-tab_boot_order
	.word message103-tab_boot_order
#ifndef COLDFIRE
	.word message104-tab_boot_order
	.word message105-tab_boot_order
	.word message106-tab_boot_order
	.word message107-tab_boot_order
tab_boot_order_ctpci:
	.word message100b-tab_boot_order_ctpci
	.word message101b-tab_boot_order_ctpci
	.word message102b-tab_boot_order_ctpci
	.word message103b-tab_boot_order_ctpci
	.word message104b-tab_boot_order_ctpci
	.word message105b-tab_boot_order_ctpci
	.word message106b-tab_boot_order_ctpci
	.word message107b-tab_boot_order_ctpci
#endif /* COLDFIRE */
#endif /* USE_ATARI_IO */
tab_partition:
	.word message109-tab_partition
	.word message110-tab_partition
	.word message111-tab_partition
	.word message112-tab_partition
	.word message113-tab_partition
	.word message114-tab_partition
	.word message115-tab_partition
	.word message116-tab_partition
	.word message117-tab_partition
	.word message118-tab_partition
	.word message119-tab_partition
	.word message120-tab_partition
	.word message121-tab_partition
	.word message122-tab_partition
	.word message123-tab_partition
	.word message124-tab_partition
	.word message125-tab_partition

#if 0
tab_vdo_cookie:
	.word message128-tab_vdo_cookie
	.word message129-tab_vdo_cookie
	.word message130-tab_vdo_cookie
	.word message131-tab_vdo_cookie
	.word message132-tab_vdo_cookie
	.word message133-tab_vdo_cookie
#endif

#ifdef COLDFIRE
env:	.asciz "PATH="
	.asciz "#:\\"
	.asciz "SDL_AUDIODRIVER="
	.asciz "mint_gsxb"
	.asciz "SDL_VIDEODRIVER="
	.asciz "gem"
	.asciz "SDL_ATARI_EVENTSDRIVER="
	.asciz "gemdos"
	.byte 0
#else
error1:	.asciz "SDRAM not found"
	.asciz "SDRAM non trouv‚e"
error2:	.asciz "SDRAM chip density error"
	.asciz "SDRAM erreur densit‚ puces"
error3:	.asciz "SDRAM number of banks error" 
	.asciz "SDRAM erreur nombre de banques" 
error4:	.asciz "SDRAM density error" 
	.asciz "SDRAM erreur densit‚" 
error5:	.asciz "SDRAM burst length error" 
	.asciz "SDRAM erreur longueur burst" 
error6:	.asciz "SDRAM data width error"
	.asciz "SDRAM erreur largeur donn‚es"
error7:	.asciz "SDRAM voltage error"
	.asciz "SDRAM erreur tension"
error8:	.asciz "SDRAM type error"
	.asciz "SDRAM erreur type"
error9:	.asciz "SDRAM refresh rate error"
	.asciz "SDRAM refresh rate error"
error10:	.asciz "SDRAM read failure at $"
	.asciz "SDRAM erreur v‚rification en $"
error11:	.asciz "CTCM not found"
	.asciz "CTCM non trouv‚e"
error12:	.asciz "CTCM frequency error"
	.asciz "CTCM erreur fr‚quence"
#endif /* COLDFIRE */
error13:	.byte 13,10
	.ascii "CTPCI not found"
	.byte 13,10,0
	.byte 13,10
	.ascii "CTPCI non trouv‚e"
	.byte 13,10,0
name1:	.asciz "Eiffel"
name2:	.asciz "boot.log"
message0:	.byte 0x1B,0x62,0x34,0x41
	.byte 0x1B,0x62,0x32,0x54
	.byte 0x1B,0x62,0x33,0x41
	.byte 0x1B,0x62,0x31,0x52
	.byte 0x1B,0x62,0x35,0x49,0x20
	.byte 0x1B,0x62,0x3F
#ifdef COLDFIRE
#ifdef MCF5445X /* M54455EVB */
	.ascii "M54455EVB"
#else
#ifdef MCF547X /* MCF547X - FIREBEE */
	.ascii "FIREBEE"
#else /* MCF548X - M5484LITE */
	.ascii "M5484LITE/M5485EVB"
#endif /* MCF547X */
#endif /* MCF5445X */
#else /* ATARI - CT60 */
	.ascii "FALCON/"
	.byte 0x1B,0x62,0x31
	.ascii "CT60"
	.byte 0x1B,0x62,0x3F
#endif /* COLDFIRE */
	.ascii " TOS4.04"
	.byte 13,10,0
message0b:
#ifdef COLDFIRE
#ifdef MCF5445X /* M54455EVB */
	.ascii "ATARI M54455EVB TOS4.04"
#else
#ifdef MCF547X /* MCF547X - FIREBEE */
	.ascii "FIREBEE TOS4.04"
#else /* MCF548X - M5484LITE */
	.ascii "ATARI M5484LITE/M5485EVB TOS4.04"
#endif /* MCF547X */
#endif /* MCF5445X */
#else /* ATARI - CT60 */
	.ascii "ATARI FALCON/CT60 TOS4.04"
#endif /* COLDFIRE */
crlf:	.byte 13,10,0
xlf:	.byte 10,10,10,10,10,0
separator:	.asciz ", "
message1:	.asciz "SDRAM "
message2:	.asciz "64"
message3:	.asciz "128"
message4:	.asciz "256"
message5:	.asciz "512"
message6:	.asciz "MB detected"
	.asciz "Mo d‚tect‚e" 
message7:	.asciz "TOS drivers v"
#ifdef COLDFIRE
#ifdef MCF5445X
message8:	.asciz "MCF54455 Rev."
	.asciz "MCF54455 R‚v."
message8a:	.asciz "MCF54454 Rev."
	.asciz "MCF54454 R‚v."	
message8b:	.asciz "MCF54453 Rev."
	.asciz "MCF54453 R‚v."		
message8c:	.asciz "MCF54452 Rev."
	.asciz "MCF54452 R‚v."	
message8d:	.asciz "MCF54451 Rev."
	.asciz "MCF54451 R‚v."
message8e:	.asciz "MCF54450 Rev."
	.asciz "MCF54450 R‚v."
#else /* MCF548X */
message8:	.asciz "MCF5485 Rev."
	.asciz "MCF5485 R‚v."
message8a:	.asciz "MCF5484 Rev."
	.asciz "MCF5484 R‚v."	
message8b:	.asciz "MCF5483 Rev."
	.asciz "MCF5483 R‚v."		
message8c:	.asciz "MCF5482 Rev."
	.asciz "MCF5482 R‚v."	
message8d:	.asciz "MCF5481 Rev."
	.asciz "MCF5481 R‚v."
message8e:	.asciz "MCF5480 Rev."
	.asciz "MCF5480 R‚v."
message9:	.asciz "MCF5475 Rev."
	.asciz "MCF5475 R‚v."
message9a:	.asciz "MCF5474 Rev."
	.asciz "MCF5474 R‚v."
message9b:	.asciz "MCF5473 Rev."
	.asciz "MCF5473 R‚v."
message9c:	.asciz "MCF5472 Rev."
	.asciz "MCF5472 R‚v."
message9d:	.asciz "MCF5471 Rev."
	.asciz "MCF5471 R‚v."
message9e:	.asciz "MCF5470 Rev."
#endif /* MCF5445X */
#else /* ATARI */
message8:	.asciz "68060 Rev."
	.asciz "68060 R‚v."
message9:	.asciz "68EC060 / 68LC060 Rev."
	.asciz "68EC060 / 68LC060 R‚v."
#endif /* COLDFIRE */
message10:	.asciz "unknown CPU "
	.asciz "CPU inconnu"
#ifndef COLDFIRE
message11:	.asciz " Mask D00W/D11W" // revision 0
	.asciz " Masque D00W/D11W"
message12:	.asciz " Mask F43G/G65V" // revision 1 & 5
	.asciz " Masque F43G/G65V"
message13:	.asciz " Mask F84W"      // revision 2
	.asciz " Masque F84W"
message14:	.asciz " Mask E41J"      // revision 6
	.asciz " Masque E41J" 
#endif
message15:	.byte 27 
	.asciz "p Boot v"
message15a:	.asciz " beta 11 " // additionnal information about version (alpha, beta...)
message15b:	.ascii " "
	.byte 27
	.ascii "q"
	.byte 13,10,0
message16:	.byte 13,10
	.asciz "Initialization SDRAM"
	.byte 13,10 
	.asciz "Initialisation SDRAM" 
message17:   .ascii "MB/S"
	.byte 13,10,0
	.ascii "Mo/S"
	.byte 13,10,0
message18:	.asciz "MHz"
#ifndef COLDFIRE
message19:	.byte 13,10,27 
	.ascii "p SDRAM EEPROM DATA "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p SDRAM DONNEES EEPROM "
	.byte 27
	.ascii "q"
	.byte 13,10,0
message20:	.byte 13,10
	.asciz "Byte 2, Memory Type : "
	.byte 13,10
	.asciz "Octet 2, Type de m‚moire : "
message20b:	.asciz " SDRAM"
message21:	.byte 13,10
	.asciz "Byte 3, Number of Row Addresses : "
	.byte 13,10
	.asciz "Octet 3, Nombre de lignes d'adresses : "
message22:	.byte 13,10
	.asciz "Byte 4, Number of Column Addresses : "
	.byte 13,10
	.asciz "Octet 4, Nombre de colonnes d'adresses : "
message23:	.byte 13,10
	.asciz "Byte 5, Number of DIMM Banks : "
	.byte 13,10
	.asciz "Octet 5, Nombre de banques DIMM : "
message24:	.byte 13,10
	.asciz "Bytes 6-7, Module Data Width : "
	.byte 13,10
	.asciz "Octets 6-7, Largeur donn‚es module : "
message24b:	.asciz " bits"
message25:	.byte 13,10
	.asciz "Byte 8, Voltage Interface Level : "
	.byte 13,10
	.asciz "Octet 8, Niveau de tension interface : "
message25b:	.asciz " LVTTL"
message26:	.byte 13,10
	.asciz "Byte 9, SDRAM Cycle Time : "
	.byte 13,10
	.asciz "Octet 9, SDRAM Temps cycle : "
message27:	.byte 13,10
	.asciz "Byte 10, SDRAM Access from Clock : "
	.byte 13,10
	.asciz "Octet 10, SDRAM AccŠs de l'horloge : "
message28:	.byte 13,10
	.asciz "Byte 11, SDRAM Configuration Type : "
	.byte 13,10
	.asciz "Octet 11, SDRAM Type : "
message29:	.byte 13,10
	.asciz "Byte 12, Refresh Rate : "
	.byte 13,10
	.asciz "Octet 12, Fr‚quence rafraichissement : "
message30:	.byte 13,10
	.asciz "Byte 17, Number of Banks : "
	.byte 13,10
	.asciz "Octet 17, Nombre de banques : "
message31:	.byte 13,10
	.asciz "Byte 27, Minimum Row Precharge Time : "
	.byte 13,10
	.asciz "Octet 27, Temps de pr‚chage mini lignes : "
message32:	.byte 13,10
	.asciz "Byte 28, Minimum Row Active to Active Delay : "
	.byte 13,10
	.asciz "Octet 28, D‚lais mini entre activations de lignes : "
message33:	.byte 13,10
	.asciz "Byte 29, Minimum RAS to CAS Delay : "
	.byte 13,10
	.asciz "Octet 29, D‚lais mini entre RAS et CAS : "
message34:	.byte 13,10
	.asciz "Byte 31, Module Bank Density : "
	.byte 13,10
	.asciz "Octet 31, Densit‚ banque du module : "
message35:	.byte 13,10
	.asciz "Bytes 64-71, Module Manufacturers ID : $"
	.byte 13,10
	.asciz "Octets 64-71, ID fabriquant du module : $"
message36:	.byte 13,10
	.asciz "Bytes 93-94, Module Manufacturing Date : "
	.byte 13,10
	.asciz "Octets 93-94, Date de fabrication du module : "
message37:	.byte 13,10
	.asciz "Byte 21, SDRAM Module Attributes : $" 
	.byte 13,10
	.asciz "Octet 21, Attributs du module : $" 
message38:	.asciz "CT60 hardware"
message39:	.asciz " ABE/SDR7+"
message39a:	.asciz " CTPCI_1E-1L"
message39b:	.asciz " CTPCI_1M"
message39c:	.asciz " CTPCI_1N"
message40:	.asciz " ETHERNAT"
message40a:	.asciz " SUPERVIDEL"
#endif /* COLDFIRE */
#ifdef USE_ATARI_IO
message41:	.byte 13,10
	.asciz "SCSI "
#endif
message42:	.byte 13,10
	.asciz "IDE  "
message43:	.asciz " ... "
message44:	.asciz "no answer "
	.asciz "pas de r‚ponse "
message45:	.asciz "error "
	.asciz "erreur "
message46:	.asciz "read error "
	.asciz "erreur lecture "
message47:	.asciz "no boot found "
	.asciz "boot non trouv‚ "
message48:	.asciz "boot in progress "
	.asciz "boot en cours "
message49:	.asciz " -> "
message50:	.asciz "no XBRA"
	.asciz "pas de XBRA"
message51:	.asciz "NVRAM unused"
	.asciz "NVRAM non utilis‚e"
message52:	.byte 13,10
	.asciz "Reset"
#ifndef COLDFIRE
message53:	.byte 13,10
	.asciz "Byte 18, CAS Latency : " 
	.byte 13,10
	.asciz "Octet 18, CAS Latence : "
message54:	.asciz ", CAS Latency unsupported"
	.asciz ", CAS Latence non support‚e"
message55:	.asciz ", Data Width unsupported"
	.asciz ", Largeur donn‚es non support‚e"
message56:	.byte 13,10
	.asciz "Byte 19, CS Latency : " 
	.byte 13,10
	.asciz "Octet 19, CS Latence : "
message57:	.byte 13,10
	.asciz "Byte 20, WE Latency : " 
	.byte 13,10
	.asciz "Octet 20, WE Latence : "
message58:	.byte 13,10
	.asciz "Bytes 73-90, Module Part Number : " 
	.byte 13,10
	.asciz "Octets 73-90, R‚f‚rence du module : "
message59:	.asciz " nS"
message60:	.asciz " no parity"
	.asciz " pas de parit‚"
message61:	.asciz " parity"
	.asciz " parit‚"
message62:	.asciz " ECC"
	.asciz " ECC"
message63:	.asciz "15.625 uS"
message64:	.asciz "3.9 uS"
message65:	.asciz "7.8 uS"
message66:	.asciz "31.3 uS"
message67:	.asciz "62.5 uS"
message68:	.asciz "125 uS"
message69:	.asciz " MB"
	.asciz " Mo"
message70:	.byte 13,10
	.asciz "Byte 30, Minimum RAS Pulse Width : "
	.byte 13,10
	.asciz "Octet 30, Largeur mini impulsion RAS : "
message71:	.asciz ", self refresh"
message72:	.asciz " unbuffered"
	.asciz " sans buffers" 
message73:	.asciz " PC100"
message74:	.asciz " PC133"
#endif
message75:	.byte 13,10
	.asciz "Keyboard OK  "
	.byte 13,10 
	.asciz "Clavier OK  " 
#ifndef MCF547X
message76b:	
#endif
message76:	.byte 13,10
#ifdef MCF547X
	.asciz "Atari keyboard failure, interrupt disabled"
#else
	.asciz "Keyboard failure"
#endif
	.byte 13,10 
#ifdef MCF547X
	.asciz "Pas de r‚ponse du clavier Atari, interruption inhib‚e" 
#else
	.asciz "Pas de r‚ponse du clavier" 
#endif
#ifdef MCF547X
message76b:	.byte 13,10
	.asciz "Keyboard failure for Eiffel test"
	.byte 13,10 
	.asciz "Pas de r‚ponse du clavier pour le test Eiffel" 
#endif
message77:	.byte 13,10,27
	.ascii "p Choice of the system : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p Choix du systŠme : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
message78:	.byte 13
	.asciz "Starting in "
	.byte 13
	.asciz "D‚marrage dans "
message79:	.asciz " seconds  "
	.asciz " secondes  "
message80:	.asciz " TOS   "
message81:	.asciz " MagiC "
#ifndef COLDFIRE
message82:	.asciz " Linux "
#endif
message83:	.asciz " removable"
	.asciz " amovible"
message84:	.asciz "no logical unit"
	.asciz "pas d'unit‚ logique"
#ifdef USE_ATARI_IO
message85:	.asciz "not ready"
	.asciz "pas prˆt"
#endif
message86:	.asciz "media not present"
	.asciz "support non pr‚sent"
message87:	.asciz "boot impossible"
	.asciz "boot impossible"
#ifdef USE_ATARI_IO
message88:	.byte 13,10
	.asciz " Abnormal asnwer => Reset SCSI..."
	.byte 13,10
	.asciz " R‚ponse anormale => Reset SCSI..."
#endif
message89:	.asciz "MB/S "
	.asciz "Mo/S "
message90:	.asciz "boot MSDOS"
	.asciz "boot MSDOS"
message91:	.byte 13,10
	.asciz " Found "
	.byte 13,10
	.asciz " Trouv‚ "
message92:	.byte 13,10
	.ascii "Boot drive has a BPB invalid!"
	.byte 13,10,0
	.byte 13,10
	.ascii "Le lecteur de boot a un BPB invalide !"
	.byte 13,10,0
message93:	.asciz " ... is not a TOS binary!"
	.asciz " ... n'est pas un ex‚cutable TOS !"
message94:	.byte 13,10
	.asciz "Error TOS : "
	.byte 13,10
	.asciz "Erreur TOS : "
message95:	.byte 13,10,27 
	.ascii "p START AUTO FOLDER "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p LANCEMENT DOSSIER AUTO "
	.byte 27
	.ascii "q"
	.byte 13,10,0
message96:	.byte 13,10,27 
	.ascii "p START GEM "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p LANCEMENT DU GEM "
	.byte 27
	.ascii "q"
	.byte 13,10,0
#ifndef COLDFIRE
message97:	.byte 13,10	
	.asciz "Write byte EEPROM (dec) ? "
	.byte 13,10	
	.asciz "Ecriture octet EEPROM (dec) ? "
message98:	.byte 13,10	
	.asciz "Value (dec) ? "
	.byte 13,10	
	.asciz "Valeur (dec) ? "
message99:	.asciz " CTCM"
#endif
#ifdef USE_ATARI_IO
#ifdef COLDFIRE
message100:	.asciz " New boot SCSI0-7 -> IDE0-3 "
	.asciz " Nouveau boot SCSI0-7 -> IDE0-3 "
message101:	.asciz " New boot IDE0-3 -> SCSI0-7 "
	.asciz " Nouveau boot IDE0-3 -> SCSI0-7 "
message102:	.asciz " New boot SCSI7-0 -> IDE3-0 "
	.asciz " Nouveau boot SCSI7-0 -> IDE3-0 "
message103:	.asciz " New boot IDE3-0 -> SCSI7-0 "
	.asciz " Nouveau boot IDE3-0 -> SCSI7-0 "
#else
message100:	.asciz " New boot SCSI0-7 -> IDE0-1 "
	.asciz " Nouveau boot SCSI0-7 -> IDE0-1 "
message101:	.asciz " New boot IDE0-1 -> SCSI0-7 "
	.asciz " Nouveau boot IDE0-1 -> SCSI0-7 "
message102:	.asciz " New boot SCSI7-0 -> IDE1-0 "
	.asciz " Nouveau boot SCSI7-0 -> IDE1-0 "
message103:	.asciz " New boot IDE1-0 -> SCSI7-0 "
	.asciz " Nouveau boot IDE1-0 -> SCSI7-0 "
message104:	.asciz " Old boot SCSI0-7 -> IDE0-1 "
	.asciz " Vieux boot SCSI0-7 -> IDE0-1 "
message105:	.asciz " Old boot IDE0-1 -> SCSI0-7 "
	.asciz " Vieux boot IDE0-1 -> SCSI0-7 "
message106:	.asciz " Old boot SCSI7-0 -> IDE1-0 "
	.asciz " Vieux boot SCSI7-0 -> IDE1-0 "
message107:	.asciz " Old boot IDE1-0 -> SCSI7-0 "
	.asciz " Vieux boot IDE0-1 -> SCSI7-0 "
message100b:	.asciz " New boot SCSI0-7 -> IDE0-3 "
	.asciz " Nouveau boot SCSI0-7 -> IDE0-3 "
message101b:	.asciz " New boot IDE0-3 -> SCSI0-7 "
	.asciz " Nouveau boot IDE0-3 -> SCSI0-7 "
message102b:	.asciz " New boot SCSI7-0 -> IDE3-0 "
	.asciz " Nouveau boot SCSI7-0 -> IDE3-0 "
message103b:	.asciz " New boot IDE3-0 -> SCSI7-0 "
	.asciz " Nouveau boot IDE3-0 -> SCSI7-0 "
message104b:	.asciz " Old boot SCSI0-7 -> IDE0 "
	.asciz " Vieux boot SCSI0-7 -> IDE0 "
message105b:	.asciz " Old boot IDE0--> SCSI0-7 "
	.asciz " Vieux boot IDE0 -> SCSI0-7 "
message106b:	.asciz " Old boot SCSI7-0 -> IDE0 "
	.asciz " Vieux boot SCSI7-0 -> IDE0 "
message107b:	.asciz " Old boot IDE0 -> SCSI7-0 "
	.asciz " Vieux boot IDE0 -> SCSI7-0 "
#endif
message108:	.byte 13,10,27 
	.ascii "p Boot order selection for IDE and SCSI drives : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p S‚lection ordre de boot des disques IDE et SCSI : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
#endif /* USE_ATARI_IO */
message109:	.asciz " Ignore this disk "
	.asciz " Ignorer ce disque "
message110:	.asciz " Partition 1 "
	.asciz " Partition 1 "
message111:	.asciz " Partition 2 "
	.asciz " Partition 2 "
message112:	.asciz " Partition 3 "
	.asciz " Partition 3 "
message113:	.asciz " Partition 4 "
	.asciz " Partition 4 "
message114:	.asciz " Partition 5 "
	.asciz " Partition 5 "
message115:	.asciz " Partition 6 "
	.asciz " Partition 6 "
message116:	.asciz " Partition 7 "
	.asciz " Partition 7 "
message117:	.asciz " Partition 8 "
	.asciz " Partition 8 "
message118:	.asciz " Partition 9 "
	.asciz " Partition 9 "
message119:	.asciz " Partition 10 "
	.asciz " Partition 10 "
message120:	.asciz " Partition 11 "
	.asciz " Partition 11 "
message121:	.asciz " Partition 12 "
	.asciz " Partition 12 "
message122:	.asciz " Partition 13 "
	.asciz " Partition 13 "
message123:	.asciz " Partition 14 "
	.asciz " Partition 14 "
message124:	.asciz " Partition 15 "
	.asciz " Partition 15 "
message125:	.asciz " Partition 16 "
	.asciz " Partition 16 "
message126:	.byte 13,10,27 
	.ascii "p No boot partition found, selection for this disk : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p Pas de partition de boot, s‚lection pour ce disque : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
#if 0
message127:	.byte 13,10,27 
	.ascii "p _VDO cookie for NVDI : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
	.byte 13,10,27 
	.ascii "p Cookie _VDO pour NVDI : "
	.byte 27
	.ascii "q"
	.byte 13,10,0
message128:	.asciz " ST "
	.asciz " ST "
message129:	.asciz " STE "
	.asciz " STE "
message130:	.asciz " TT "
	.asciz " TT "
message131:	.asciz " FALCON "
	.asciz " FALCON "
message132:	.asciz " MILAN "
	.asciz " MILAN "
message133:	.asciz " ARANYM "
	.asciz " ARANYM "
#endif
	
blue:	.byte 0x1B,0x62,0x34,0
black:	.byte 0x1B,0x62,0x3F,0
	
#ifdef DEBUG
debug1:	.byte 13,10
	.asciz "Set Features: "
debug2:	.byte 13,10
	.asciz "Get Media Status: "	
debug3:	.byte 13,10
	.asciz "Test Unit Ready: "
debug4:	.byte 13,10
	.asciz "Request Sense: "	
debug5:	.byte 13,10
	.asciz "Read IDE LBA: "	
debug6:	.byte 13,10
	.asciz "Identify Device Packet: "
debug7:	.byte 13,10
	.asciz "Identify Device: "
debug8:	.byte 13,10
	.asciz "Inquiry: "
debug9:	.byte 13,10
	.asciz "Read TOS: "
debug10:	.byte 13,10
	.asciz "Packet: "
debug11:	.byte 13,10
	.asciz "Read SCSI: "
debug12:	.byte 13,10
	.asciz "TOS partition found: 0x"
debug13:	.byte 13,10
	.asciz "Boot TOS partition: 0x"
debug14:	.byte 13,10
	.asciz "Read directory: 0x"
debug15:	.byte 13,10
	.asciz "MSDOS partition found: 0x"
debug16:	.byte 13,10
	.asciz "Error code: 0x"
debug17:	.byte 13,10	
	.asciz "Initialize Device Parameters: "
#endif

#ifdef USE_ATARI_IO
#if defined(COLDFIRE) && defined(MCF547X) /* FIREBEE */
boot_scsi:	.byte 8,9,10,11,12,13,14,15,16,17,18,19,255
boot_ide:	.byte 16,17,18,19,8,9,10,11,12,13,14,15,255
boot_scsi_2:	.byte 15,14,13,12,11,10,9,8,19,18,17,16,255
boot_ide_2:	.byte 19,18,17,16,15,14,13,12,11,10,9,8,255
#else /* <> FIREBEE */
boot_scsi:	.byte 8,9,10,11,12,13,14,15,16,17,255
boot_ide:	.byte 16,17,8,9,10,11,12,13,14,15,255
boot_scsi_2:	.byte 15,14,13,12,11,10,9,8,17,16,255
boot_ide_2:	.byte 17,16,15,14,13,12,11,10,9,8,255
boot_scsi_ctpci:	.byte 8,9,10,11,12,13,14,15,16,17,18,19,255
boot_ide_ctpci:	.byte 16,17,18,19,8,9,10,11,12,13,14,15,255
boot_scsi_2_ctpci:	.byte 15,14,13,12,11,10,9,8,19,18,17,16,255
boot_ide_2_ctpci:	.byte 19,18,17,16,15,14,13,12,11,10,9,8,255
#endif /* defined(COLDFIRE) && defined(MCF547X) */
#else /* !USE_ATARI_IO */
boot_ide:	.byte 16, /* 17, */ 255
#endif /* USE_ATARI_IO  */

tab_os:	.byte 0x80,8,0x10

#ifndef COLDFIRE
list_manufacturers:
	.byte 0x1C
	.asciz "MITSUBISHI"
	.byte 0x25
	.asciz "KINGMAX"
	.byte 0x2C
	.asciz "MICRON"
	.byte 0x4A
	.asciz "COMPAQ"
	.byte 0x54
	.asciz "HP"
	.byte 0x98
	.asciz "KINGSTON"
	.byte 0x9E
	.asciz "CORSAIR"
	.byte 0xA4
	.asciz "IBM"
	.byte 0xC1
	.asciz "INFINEON"
	.byte 0xCE
	.asciz "SAMSUNG"
	.byte 0xDA
	.asciz "DANE-ELEC"
	.byte 0xAD     // jedec source
	.asciz "HYUNDAI" 
	.byte 0xE0     // module source ?
	.asciz "HYUNDAI"
#endif
null:	.byte 0,0

list_device_type:

	.asciz "magnetic disk"  // Direct-access Device
	.asciz "magnetic tape"  // Sequential Access Device
	.asciz "printer"        // Printer Device
	.asciz "processor"      // Processor Device
	.asciz "optical disk"   // Write Once Block Device
	.asciz "CD/DVD"         // CD/DVD Device
	.asciz "scanner"        // Scanner Device
	.asciz "optical memory" // Optical Memory Block Device
	.asciz "juke-box"       // Media Changer Device
	.asciz "communication"  // Communication Device
	.asciz "CompactFlash"
	
	.asciz "disque magn‚tique"
	.asciz "bande magn‚tique"
	.asciz "imprimante"
	.asciz "processeur"
	.asciz "disque optique"
	.asciz "CD/DVD"
	.asciz "scanner"
	.asciz "m‚moire optique"
	.asciz "juke-box"
	.asciz "communication"
	.asciz "CompactFlash"

	.align 2

boot_drive:

	movem.l D0-A5,-(SP)
	link A6,#-24
#ifdef COLDFIRE
	bset #5,0xFFFFFA01       // for IDE emulation (SRAM)
//	clr.l save_ide_registers
//	clr.l save_ide_registers+4
//	lea coldfire_vector_base,A1
//	move.l 2*4(A1),D0
//	move.l D0,old_access_error
//	lea access_error_ide(PC),A0
//	move.l A0,2*4(A1)        // to fix with MMU update_tlb access fault !!!
#endif
	jsr install_scsidrv
	move.l hdv_rw,-22(A6)
	move.w #3,-(SP)          // TT ram if possible
	move.l #pinfo_size,-(SP)
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	move.l D0,pun_ptr
	beq.s .no_pinfo
	move.l D0,A3
	clr.w pinfo_puns(A3)
	lea pinfo_pun(A3),A0
	moveq #-1,D0
	move.w D0,(A0)+          // drives A/B
	move.l D0,(A0)+
	move.l D0,(A0)+
	move.l D0,(A0)+
	move.w D0,(A0)
	lea pinfo_pstart(A3),A0
	lea pinfo_size(A3),A1
.clrpun:
		clr.w -(A1)
	cmp.l A0,A1
	bgt.s .clrpun
	lea pinfo_cookie(A3),A0
	move.l #0x41484449,(A0)  // AHDI
	move.l A0,4(A0)
	move.w #0x0300,D0
	move.w D0,pinfo_vernum(A3)
	move.w #0x4000,D0
	move.w D0,pinfo_maxsiz(A3)
.no_pinfo:
	clr.l -(SP)
	move.l #CT60_BOOT_ORDER,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	cmp.l #-1,D0
	bne.s .param_boot_ok
	moveq #1,D0             // force new boot IDE0-1/SCSI0-7
.param_boot_ok:
	// 0: New boot SCSI0-7 -> IDE0-1
	// 1: New boot IDE0-1 -> SCSI0-7
	// 2: New boot SCSI7-0 -> IDE1-0
	// 3: New boot IDE1-0 -> SCSI7-0
	// 4: Old boot SCSI0-7 -> IDE0-1
	// 5: Old boot IDE0-1 -> SCSI0-7
	// 6; Old boot SCSI7-0 -> IDE1-0
	// 7: Old boot IDE1-0 -> SCSI7-0
#ifdef COLDFIRE
	and.l #0xFFFF0003,D0
#endif
	move.b D0,-18(A6)       // boot order 0-7 (0-3 on Coldfire)
	swap D0
	move.w D0,-24(A6)       // device mask (B11-B8: IDE3-0, B7-B0: SCSI7-0)
#ifdef USE_ATARI_IO
	bsr test_key
	beq.s .no_key_pressed
	bsr wait_key
	cmp.w #0x43,D0    // C
	beq.s .c_key_pressed
	cmp.w #0x63,D0    // c
	bne.s .no_key_pressed
.c_key_pressed:
	lea tab_boot_order(PC),A1
#ifndef COLDFIRE
	move.l #0x5F504349,D0    // cookie _PCI
	bsr get_cookie
	beq.s .no_pci_cookie_for_menu
	lea tab_boot_order_ctpci(PC),A1
.no_pci_cookie_for_menu:
#endif /* COLDFIRE */
	moveq #0,D0
	move.b -18(A6),D0	
#ifdef COLDFIRE
	moveq #4,D1       // nb lines
#else
	moveq #8,D1       // nb lines
#endif
	lea message108(PC),A0
	bsr common_menu
	move.b D0,-18(A6)
.no_key_pressed:	
#ifndef COLDFIRE
	move.l #0x5F504349,D0    // cookie _PCI
	bsr get_cookie
	beq.s .no_pci_cookie_for_ide
	move.b -18(A6),D0	
	lea boot_scsi_ctpci(PC),A5
	and.w #3,D0
	beq.s .loop_drive
	lea boot_ide_ctpci(PC),A5
	cmp.w #1,D0
	beq.s .loop_drive
	lea boot_scsi_2_ctpci(PC),A5
	cmp.w #2,D0
	beq.s .loop_drive
	lea boot_ide_2_ctpci(PC),A5
	bra.s .loop_drive
.no_pci_cookie_for_ide:
#endif /* COLDFIRE */
	move.b -18(A6),D0	
	lea boot_scsi(PC),A5
	and.w #3,D0
	beq.s .loop_drive
	lea boot_ide(PC),A5
	cmp.w #1,D0
	beq.s .loop_drive
	lea boot_scsi_2(PC),A5
	cmp.w #2,D0
	beq.s .loop_drive
	lea boot_ide_2(PC),A5
#else
	lea boot_ide(PC),A5
#endif /* USE_ATARI_IO */
.loop_drive:
		clr.w -(SP)                       // STRAM
		move.l #SPEED_BUFFER_SIZE,-(SP)   // size
		move.w #0x44,-(SP)                // Mxalloc
		trap #1 
		addq.l #8,SP
		move.l D0,-12(A6)                 // SCSI buffer
		move.w #3,-(SP)                   // TT ram if possible
		move.l #SPEED_BUFFER_SIZE,-(SP)   // size
		move.w #0x44,-(SP)                // Mxalloc
		trap #1 
		addq.l #8,SP
		move.l D0,-16(A6)                 // IDE buffer normally in SDRAM    
		move.w 0x840,D4
		move.b (A5,D4.w),D4
		moveq #1,D1                       // counter logical unit
#if defined(COLDFIRE) && defined(MCF547X) /* FIREBEE */
		move.l _sysbase,A0                // header ROM
		move.l 0x24(A0),A0                // kbshift
		move.b (A0),D0
		btst #2,D0                        // CTRL
		bne.s .loop2_drive
 		moveq #0,D0
		bset D4,D0
		lsr.l #8,D0
		and.w -24(A6),D0                  // device mask
		bne .next_drive                   // disabled
#endif /* defined(COLDFIRE) && defined(MCF547X) */
.loop2_drive:
			move.w D1,-(SP)      // logical unit
			move.l _dskbufp,A0
			move.l #(1024/16),D0
.loop_clear_dskbufp:
				clr.l (A0)+
				clr.l (A0)+
				clr.l (A0)+
				clr.l (A0)+
			subq.l #1,D0
			bgt.s .loop_clear_dskbufp
			cmp.w #2,0x3E86      // number of planes
			bls.s .black_and_white
			lea blue(PC),A0
			bsr display_string_single
.black_and_white:
#ifdef USE_ATARI_IO
			lea message41(PC),A0
			btst #4,D4
			beq.s .scsi_drive
#endif /* USE_ATARI_IO */
			moveq #0,D1          // no logical unit on IDE drives
			clr.w (SP)
			lea message42(PC),A0
.scsi_drive:
			bsr display_string_single
			move.w D4,D0
			and.w #7,D0
			or.w #0x30,D0
			bsr display_char
			moveq #0x2E,D0
			bsr display_char
			moveq #0x30,D0
			or.w (SP),D0         // logical unit
			bsr display_char
			cmp.w #2,0x3E86      // number of planes
			bls.s .black_and_white_2
			lea black(PC),A0
			bsr display_string_single
.black_and_white_2:
			moveq #0,D7          // flags
#ifdef USE_ATARI_IO
			btst #2,-18(A6)      // old boot
			beq.s .new_boot
			lea message43(PC),A0 // ...
			bsr display_string_single
			bra .default_tos_routine
.new_boot:
			btst #4,D4
			bne .ide_drive
#ifdef DEBUG
			lea debug8(PC),A0
			bsr display_string_single
#endif	
			move.w D4,D0         // drive
			move.l _dskbufp,A0   // DMA buffer
			lea -6(A6),A1        // cmd buffer
			move.b #0x12,(A1)    // inquiry
			asl.w #5,D1
			move.b D1,1(A1)      // logical unit
			clr.w 2(A1)
			moveq #96,D1         // DMA bytes length
			move.b D1,4(A1)      // length
			clr.b 5(A1)
			moveq #6,D2          // cmd bytes length
			jsr scsi_cmd
			bmi .no_answer       // time-out
#ifdef DEBUG
			move.l _dskbufp,A1
			moveq #5,D1
			bsr dump
#ifndef COLDFIRE
			bsr wait_key
#endif
			moveq #13,D0
			bsr display_char
			moveq #10,D0
			bsr display_char
#endif			
			move.l _dskbufp,A0
			cmp.b #0x7F,(A0)     // qualifier = 3 & no device type
			beq .no_logical_unit
			addq.l #8,A0
			lea 24(A0),A1
			moveq #23,D1
.last_space_infos_device_scsi:
				cmp.b #0x20,-(A1)
			dbne D1,.last_space_infos_device_scsi
			addq.w #1,A1
			clr.b (a1)
			moveq #0x20,D0
			bsr display_char
			moveq #23,D1         // vendor & product identification
.infos_device_scsi:
				move.b (A0)+,D0
				beq.s .end_infos_device_scsi
				bsr display_char			
			dbf D1,.infos_device_scsi
.end_infos_device_scsi:
			move.l _dskbufp,A0   // DMA buffer
			moveq #0x1F,D0
			and.b (A0),D0        // device type
			cmp.w #10,D0
			bcc .read_root
			bra .infos_device_type
.ide_drive:
#endif /* USE_ATARI_IO */
#ifdef RESET
			move.l _dskbufp,A0   // IDE buffer
			lea -8(A6),A1        // cmd buffer
			move.b #0x08,(A1)    // device reset
			moveq #3,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			moveq #0,D0          // bytes
			jsr ide_cmd
#endif
#ifdef DEBUG
			lea debug6(PC),A0
			bsr display_string_single
#endif	
			bset #16,D7          // flag PACKET
			move.l _dskbufp,A0   // IDE buffer
			lea -8(A6),A1        // cmd buffer
			move.b #0xA1,(A1)    // identify packet device
			moveq #3,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			move.l #512,D0       // bytes
			jsr ide_cmd
			beq.s .found_ide_drive
#ifdef DEBUG
			lea debug7(PC),A0
			bsr display_string_single
#endif	
			bclr #16,D7          // flag PACKET
			move.l _dskbufp,A0   // IDE buffer
			clr.w (A0)
			lea -8(A6),A1        // cmd buffer
			move.b #0xEC,(A1)    // identify device
			moveq #3,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			move.l #512,D0       // bytes
			jsr ide_cmd
			move.l _dskbufp,A0   // IDE buffer
			cmp.w #0x848A,(A0)   // CompactFlash
			beq.s .compactflash_found
			and.b #0xE0,(A0)     // force to 0 command packet set (identify device packet)
.compactflash_found:                                        // this word =  0x848A for Compact flash
			tst.w D0
			beq.s .found_ide_drive
.no_answer:
			move.w (SP)+,D1
			lea message43(PC),A0 // ...
			bsr display_string_single
			lea message44(PC),A0 // time-out
			moveq #-1,D0
			bra .no_read_error
.no_logical_unit:
			move.w (SP)+,D1
			lea message43(PC),A0 // ...
			bsr display_string_single
			lea message84(PC),A0 // no logical unit
			moveq #0,D0
			bra .no_read_error
.found_ide_drive:	
#ifdef DEBUG
			move.l _dskbufp,A1
			moveq #15,D1
			bsr dump
#ifndef COLDFIRE
			bsr wait_key
#endif
			moveq #13,D0
			bsr display_char
			moveq #10,D0
			bsr display_char			
//			move.l _dskbufp,A0   // IDE buffer
//			move.w (A0),D0
//			bsr hex_word	
#endif
			move.l _dskbufp,A0
			lea 54(A0),A0
			lea 24(A0),A1
			moveq #23,D1
.last_space_infos_device_ide:
				cmp.b #0x20,-(A1)
			dbne D1,.last_space_infos_device_ide
			addq.w #1,A1
			clr.b (a1)
			moveq #0x20,D0
			bsr display_char
			moveq #23,D1         // model number
.infos_device_ide:
				move.b (A0)+,D0
				beq.s .end_infos_device_ide
				bsr display_char
			dbf D1,.infos_device_ide
.end_infos_device_ide:
			move.l _dskbufp,A0   // IDE buffer
			btst #1,98(A0)       // capabilities, LBA supported
			sne.b D7
			ext.w D7             // LBA flag
			moveq #10,D0
			cmp.w #0x848A,(A0)   // CompactFlash
			beq.s .infos_device_type
			moveq #0x1F,D0
			and.b (A0),D0        // command packet set
			cmp.w #10,D0 
			bcc .read_root
.infos_device_type:
			move.w D0,-(SP)
			moveq #0x2C,D0
			bsr display_char
			moveq #0x20,D0
			bsr display_char
			move.w (SP)+,D0
			bsr display_device_type
			tst.b 1(A0)
			bpl.s .check_total_sectors // RMB
			bset #31,D7          // removable media flags
			lea message83(PC),A0 // removable
			bsr display_string
.check_total_sectors:
			btst #4,D4
			beq .read_root       // SCSI
			move.l _dskbufp,A0   // IDE buffer
			cmp.w #0x848A,(A0)   // CompactFlash
			beq .read_root
			move.l 120(A0),D1    // total number of user addressable sectors
			swap D1
			cmp.l #16515072,D1   // 8 GB
			bhi .read_root
			move.w D0,-(SP)
			move.w 2(A0),D0      // cyl
			beq.s .bad_params_chs
			move.w 6(A0),D2      // heads
			beq.s .bad_params_chs
			cmp.w #16,D2
			bhi.s .bad_params_chs
			move.w 12(A0),D1     // logical sectors / track
			beq.s .bad_params_chs
			cmp.w #63,D1
			bls.s .init_chs
.bad_params_chs:
			moveq #16,D2
			move.l 120(A0),D1    // total number of user addressable sectors
			swap D1
			cmp.l #1032192,D1    // 528 MB
			bcc.s .chs_extended
			moveq #63,D1         // logical sectors / track
			bra.s .init_chs
.chs_extended:
			lsr.l #4,D1          // / 16 heads
			divu #16383,D1       // cyl max for 16 heads
			swap D1			
			tst.w D1
			beq.s .chs_sectors
			add.l #0x10000,D1
.chs_sectors:
			swap D1              // logical sectors / track
.init_chs:
			subq.w #1,D2
#ifdef DEBUG
			lea debug17(PC),A0
			bsr display_string_single
			move.w D2,D0         // heads
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
			move.w D1,D0         // sector count
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
#endif	
			lea -8(A6),A1        // cmd buffer
			move.b #0x91,(A1)    // initialize device parameters
			moveq #3,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			or.b D2,D0           // max head
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.b 4(A1)          // sec num
			move.b D1,5(A1)      // sector count, logical sectors / track
			clr.b 6(A1)          // features
			moveq #0,D0          // bytes
			jsr ide_cmd
#if 0 // #ifdef DEBUG
			btst #0,D0           // state, ERR
			beq .no_error_init_dev
			moveq #0,D0
			move.b ATA_ERROR_REGISTER,D0 // error register
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
.no_error_init_dev:
#endif		
			move.w (SP)+,D0			
.read_root:
			lea message43(PC),A0 // ...
			bsr display_string_single
			cmp.w #10,D0         // device type
			beq.s .direct_access 
			tst.w D0             // device type <> Direct-access
			bne .boot_impossible
.direct_access:
			tst.l D7             // removable media flag
			bpl .no_removable_media
#ifndef USE_ATARI_IO
			bra.s .ide_drive_2
#else
			btst #4,D4
			bne .ide_drive_2
.test_media_scsi:
#ifdef DEBUG
			move.l #200,D0
			jsr delay_hz_200
			lea debug3(PC),A0
			bsr display_string_single
#endif	
			move.w D4,D0         // drive
			move.l _dskbufp,A0   // DMA buffer
			lea -6(A6),A1        // cmd buffer
			clr.b (A1)           // test unit ready
			move.w (SP),D1       // logical unit
			asl.w #5,D1
			move.b D1,1(A1)      // logical unit
			clr.w 2(A1)
			clr.w 4(A1)          // length
			moveq #6,D2          // cmd bytes length
			jsr scsi_cmd
			bmi .no_answer_2     // time-out
			beq .no_removable_media // good
#ifdef DEBUG
			bsr hex_byte
			lea debug4(PC),A0
			bsr display_string_single
#endif	
			move.w D4,D0         // drive
			move.l _dskbufp,A0   // DMA buffer
			lea -6(A6),A1        // cmd buffer
			move.b #0x03,(A1)    // request sense
			move.w (SP),D1       // logical unit
			asl.w #5,D1
			move.b D1,1(A1)      // logical unit
			clr.w 2(A1)
			clr.w 2(A1)
			move.l #252,D1       // DMA bytes length
			move.b D1,4(A1)      // length
			clr.b 5(A1)
			moveq #6,D2          // cmd bytes length
			jsr scsi_cmd
			bmi .no_answer_2     // time-out
			move.l _dskbufp,A0   // DMA buffer
#ifdef DEBUG
			move.b 2(A0),D0
			bsr hex_byte
			move.b 12(A0),D0
			bsr hex_byte
			move.b 13(A0),D0
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
#endif	
			moveq #0xF,D0
			and.b 2(A0),D0       // sense key
			beq .no_removable_media
			cmp.w #2,D0          // not ready
			beq.s .sense_not_ready_scsi
			cmp.w #6,D0          // unit attention
			bne .no_removable_media
.sense_not_ready_scsi:
			cmp.b #0x28,12(A0)   // ASC, medium changed
			bne.s .test_not_changed_scsi
			tst.b 13(A0)
			beq .test_media_scsi
.test_not_changed_scsi:
			cmp.b #0x29,12(A0)   // ASC, reset bus occured
			bne.s .test_not_ready_scsi
			tst.b 13(A0)
			beq .test_media_scsi 
.test_not_ready_scsi:
			cmp.b #4,12(A0)      // ASC, in progress
			bne.s .test_media_present_scsi
			cmp.b #1,13(A0)      // ASCQ
			beq .test_media_scsi	
.test_media_present_scsi:
			cmp.b #0x3A,12(A0)   // ASC, medium not present
			bne.s .not_ready_scsi
			tst.b 13(A0)         // ASCQ
			beq.s .no_media_scsi
			cmp.b #1,13(A0)      // ASCQ, try closed
			bne.s .not_ready_scsi
.no_media_scsi:
			move.w (SP)+,D1
			lea message86(PC),A0 // no media
			moveq #0,D0
			bra .no_read_error	
.not_ready_scsi:		
			cmp.w #2,D0          // not ready
			bne .no_removable_media
			move.w (SP)+,D1
			lea message85(PC),A0 // not ready
			moveq #0,D0
			bra .no_read_error
.no_answer_2:		                     // abnormal time-out on test unit ready or request sense command
			lea message44(PC),A0 // time-out
			bsr display_string
			jsr 0xE01C8C         // reset the bus a 2nd time for other drives
			move.w (SP)+,D1
			lea message88(PC),A0 // reset SCSI
			moveq #-1,D0
			bra .no_read_error
#endif /* USE_ATARI_IO */
.boot_impossible:
			move.w (SP)+,D1
			lea message87(PC),A0 // boot impossible
			moveq #0,D0
			bra .no_read_error
.ide_drive_2:
			move.l _dskbufp,A0   // IDE buffer
			moveq #3,D0
			and.w 254(A0),D0
			cmp.w #1,D0          // removable media status supported
			bne .no_removable_media
#ifdef DEBUG
			lea debug1(PC),A0
			bsr display_string_single
#endif	
			move.l _dskbufp,A0   // IDE buffer
			clr.w (A0)
			lea -8(A6),A1        // cmd buffer
			move.b #0xEF,(A1)    // set features
			moveq #3,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			move.b #0x95,6(A1)   // features, enable media status notification
			moveq #0,D0          // bytes
			jsr ide_cmd
#ifdef DEBUG
			bsr hex_byte
#endif			
.test_media_ide:
#ifdef DEBUG
			move.l #200,D0
			jsr delay_hz_200
			lea debug2(PC),A0
			bsr display_string_single
#endif			
			move.l _dskbufp,A0   // IDE buffer
			lea -8(A6),A1        // cmd buffer
			move.b #0xDA,(A1)    // get media status
			moveq #3,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			move.b D0,1(A1)      // drive (C/D/H)
			clr.w 2(A1)          // cyl high & low
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			moveq #0,D0          // bytes
			jsr ide_cmd
			bmi.s .no_answer_3
#ifdef DEBUG
			move.w D0,-(SP)
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
			move.w (SP)+,D0
#endif	
			btst #5,D0           // media change MC
			bne.s .test_media_ide
			btst #1,D0           // no media NM
			beq.s .no_removable_media
			move.w (SP)+,D1
			lea message86(PC),A0 // no media
			moveq #0,D0
			bra .no_read_error
.no_answer_3:
			move.w (SP)+,D1
			lea message44(PC),A0 // time-out
			moveq #-1,D0
			bra .no_read_error
.no_removable_media:
#ifdef USE_ATARI_IO
			btst #4,D4
			beq .scsi_drive_2    // SCSI
			tst.w D7
			bpl .default_tos_routine // LBA not supported			
#endif
			btst #16,D7
			beq.s .no_packet
#ifdef DEBUG
			lea debug10(PC),A0
			bsr display_string_single
#endif	
			move.l _dskbufp,A0   // IDE buffer
			lea -8(A6),A1        // cmd buffer
			move.b #0xA0,(A1)    // packet
			moveq #3,D0
			and.w D4,D0          // drive
			asl.w #4,D0
			move.b D0,1(A1)      // drive (C/D/H)
			move.w #0x200,2(A1)  // cyl high & low, byte count limit
			clr.w 4(A1)          // sec num & count
			clr.b 6(A1)          // features
			moveq #0,D0          // bytes
			jsr ide_cmd
.no_packet:
#ifdef USE_ATARI_IO
			tst.l -16(A6)        // IDE buffer
			beq .default_tos_routine 
#endif
#ifdef DEBUG
			lea debug5(PC),A0
			bsr display_string_single
#endif	
			moveq #1,D3
.loop_speed_ide:
				move.l -16(A6),A0    // IDE buffer normally in SDRAM
				lea -8(A6),A1        // cmd buffer
				move.b #0x20,(A1)    // read sector(s)
				moveq #3,D0
				and.w D4,D0          // drive
				asl.w #4,D0
				or.b #0x40,D0        // LBA
				move.b D0,1(A1)      // drive (C/D/H)
				clr.w 2(A1)          // cyl high & low
				clr.b 4(A1)          // sec num
				move.b #SPEED_BUFFER_SIZE/512,5(A1) // sec count
				clr.b 6(A1)          // features
				move.l #SPEED_BUFFER_SIZE,D0 // bytes
				jsr ide_cmd
				bne.s .drive_not_ok_ide
			dbf D3,.loop_speed_ide 	
			move.l D1,D0
			bsr display_mb_by_sec_disk
			moveq #0,D0          // no error
			move.l -16(A6),A0    // IDE buffer
			move.l _dskbufp,A1
			moveq #127,D1        // 512 bytes
.copy_buffer_ide:
				move.l (A0)+,(A1)+
			dbf D1,.copy_buffer_ide
.drive_not_ok_ide:
			move.w (SP)+,D1
			tst.l D0
			beq .drive_ok
			bgt.s .read_ide_error
			lea message44(PC),A0 // time-out
			bra .no_read_error
.read_ide_error:
			lea message46(PC),A0 // read error
#if 0 // #ifdef DEBUG
			btst #16,D7          // flag PACKET
			beq .no_read_error
			btst #0,D0           // state, ERR
			beq .no_read_error
			moveq #0,D0
			move.b ATA_ERROR_REGISTER,D0 // error register
			bsr hex_byte
			moveq #0x20,D0
			bsr display_char
			moveq #0,D0
#endif
			bra .no_read_error
#ifdef USE_ATARI_IO
.scsi_drive_2:
			tst.l -12(A6)        // SCSI buffer
			beq .default_tos_routine 
#ifdef DEBUG
			lea debug11(PC),A0
			bsr display_string_single
			move.l -12(A6),A0
			moveq #127,D0
.loop_raz_buffer:
				clr.l (A0)+
			dbf D0,.loop_raz_buffer			
#endif
			moveq #1,D3
.loop_speed_scsi:
				move.w D4,D0         // drive
				move.l -12(A6),A0    // DMA buffer
				lea -6(A6),A1        // cmd buffer
				move.b #0x08,(A1)    // read
				move.w (SP),D1       // logical unit
				asl.w #5,D1
				move.b D1,1(A1)      // logical unit
				clr.w 2(A1)          // logical block address
				move.b #SPEED_BUFFER_SIZE/512,4(A1) // num blocks
				clr.b 5(A1)          // control
				move.l #SPEED_BUFFER_SIZE,D1 // DMA bytes length
				moveq #6,D2          // cmd bytes length
				jsr scsi_cmd
				bne .drive_not_ok_scsi // error
			dbf D3,.loop_speed_scsi
			move.l D1,D0
			bsr display_mb_by_sec_disk
			moveq #0,D0          // no error
			move.l -12(A6),A0    // SCSI buffer
			move.l _dskbufp,A1
			moveq #127,D1        // 512 bytes
.copy_buffer_scsi:
				move.l (A0)+,(A1)+
			dbf D1,.copy_buffer_scsi
.drive_not_ok_scsi:
#ifdef DEBUG
			move.l D0,-(SP)
			move.l -12(A6),A1
			moveq #15,D1
			bsr dump
#ifndef COLDFIRE
			bsr wait_key
#endif
			lea debug16(PC),A0
			bsr display_string_single
			move.l (SP),D0
			bsr hex_long	
			moveq #13,D0
			bsr display_char
			moveq #10,D0
			bsr display_char
			move.l (SP)+,D0
#endif
			move.w (SP)+,D1
			tst.l D0
			beq .drive_ok
			lea message44(PC),A0 // time-out
			tst.l D0
			bmi.s .no_read_error
			lea message46(PC),A0 // read error
			bra.s .no_read_error
.default_tos_routine:
#ifdef DEBUG
			lea debug9(PC),A0
			bsr display_string_single
#endif
			movem.l D3/A5/A6,-(SP)
			move.w D4,-(SP)
			move.l _dskbufp,-(SP)
			move.w #1,-(SP)
			clr.l -(SP)
			jsr 0xE017CE         // read root sector
			lea 12(SP),SP
			movem.l (SP)+,D3/A5/A6
			move.w (SP)+,D1
			tst.l D0
			beq .drive_ok
			lea message44(PC),A0 // time-out
			cmp.l #-1,D0
			beq.s .no_read_error
			lea message45(PC),A0 // error
			cmp.l #-11,D0
			bne.s .no_read_error
			lea message46(PC),A0 // read error
#endif /* USE_ATARI_IO */
.no_read_error:
			bsr display_string
			addq.l #1,D0
		dbeq D1,.loop2_drive
		move.l -16(A6),D0        // IDE buffer
		beq.s .no_ide_buffer_2
		move.l D0,-(SP)
		move.w #0x49,-(SP)       // Mfree
		trap #1 
		addq.l #6,SP
.no_ide_buffer_2:
		move.l -12(A6),D0        // SCSI buffer
		beq .next_drive
		move.l D0,-(SP)
		move.w #0x49,-(SP)       // Mfree
		trap #1 
		addq.l #6,SP
		bra .next_drive
.drive_ok:
		move.l -16(A6),D0        // IDE buffer
		beq.s .no_ide_buffer
		move.l D0,-(SP)
		move.w #0x49,-(SP)       // Mfree
		trap #1 
		addq.l #6,SP
.no_ide_buffer:
		move.l -12(A6),D0        // SCSI buffer
		beq.s .no_scsi_buffer
		move.l D0,-(SP)
		move.w #0x49,-(SP)       // Mfree
		trap #1 
		addq.l #6,SP
.no_scsi_buffer:
		move.l _dskbufp,A0
		bsr check_root
		bne.s .root_bad
		bsr atari_root           // root OK
		bne.s .end_boot_drive
		bra.s .next_drive		
.root_bad:
#if !defined(USE_ATARI_IO) || defined(COLDFIRE)
		bsr atari_root2           // install hard disk driver
		bne.s .end_boot_drive
#endif
#ifdef USE_ATARI_IO
		btst #2,-18(A6)          // old boot
		bne .no_boot_found
#endif /* USE_ATARI_IO */
		move.l _dskbufp,A0
		cmp.w #0xAA55,510(A0)
		bne.s .no_boot_found
		// last bytes of root sector are 0xAA55
		bsr msdos_root
		bne.s .end_boot_drive
		bra.s .next_drive
.no_boot_found:
#if 0 // #ifdef DEBUG
		move.l D1,-(SP)
		move.l _dskbufp,A0
		moveq #31,D1
		bsr dump
		move.l (SP)+,D1
		moveq #13,D0
		bsr display_char
		moveq #10,D0
		bsr display_char
#endif		
		lea message47(PC),A0     // no boot found
		bsr display_string
.next_drive:
#ifdef DEBUG
#ifndef COLDFIRE
		bsr wait_key
#endif
#endif
		move.w 0x840,D4
		addq.w #1,D4
		move.w D4,0x840
	tst.b (A5,D4)
	bpl .loop_drive
.end_boot_drive:
#if !defined(USE_ATARI_IO) || defined(COLDFIRE)
	move.l hdv_rw,D0
	cmp.l -22(A6),D0
	bne.s .external_driver
	jsr install_hddriver     // if no external driver
.external_driver:
#endif /* USE_ATARI_IO */
//	cmp.l #0x31415926,resvalid
//	bne.s .no_resvector
//	tst.l resvector
//	beq.s .no_resvector
//	lea message52(PC),A0
//	bsr display_string_single
//	move.l resvector,A0
//	bsr display_xbra
//	lea crlf(PC),A0
//	bsr display_string_single
//.no_resvector:
	move.l #0x5F504349,D0    // cookie _PCI
	bsr get_cookie
	move.l A0,D0
	beq.s .no_pci_drivers
	bsr test_pci_drivers
	bne.s .no_pci_drivers
	jsr 16(A0)               // drivers PCI in flash, init before auto folder
.no_pci_drivers:
	unlk A6
	movem.l (SP)+,D0-A5
	rts
	
search_tos_partition:                 // D0: drive, D0.H: flag swap bytes
                                      // D1: logical drive, D2: bootpref
	movem.l D1-A5,-(SP)
	move.l D0,D3             // D0: drive, D0.H: flag swap bytes
	moveq #0,D6
	move.w D1,D6             // logical drive
	move.w D2,D5             // bootpref
	moveq #0,D7              // start of 1st bootable partition
	move.l pun_ptr,A3
	move.l _dskbufp,A2
	lea 0x1C6(A2),A2         // infos partitions TOS
	lea 0,A4                 // partition count
	move.l D6,A5             // logical drive start
	moveq #0,D2              // ext sector for XGM
	moveq #3,D4              // 4 partitions
.loop_partition_tos:
		move.l (A2),D1
		and.l #0xFFFFFF,D1 // ID
		beq.s .next_partition_tos
#if 1
		cmp.l #0x4C4E58,D1 // LNX
		beq.s .partition_ok_tos
		cmp.l #0x524157,D1 // RAW
		beq.s .partition_ok_tos
		cmp.l #0x463332,D1 // F32
		beq.s .partition_ok_tos
#endif
		cmp.l #0x47454D,D1 // GEM
		beq.s .partition_ok_tos
		cmp.l #0x42474D,D1 // BGM
		beq.s .partition_ok_tos
		cmp.l #0x58474D,D1 // XGM
		bne.s .next_partition_tos
		move.l 4(A2),D2    // start of partition = ext sector for XGM
		subq.l #1,D4
		bpl.s .loop_partition_tos
		bra.s .test_extended_partition_tos
.next_partition_tos:
		moveq #0,D2
		lea 12(A2),A2
	subq.l #1,D4
	bpl.s .loop_partition_tos
.test_extended_partition_tos:
	tst.l D2
	beq .end_partitions_tos  // no ext sector for XGM
	moveq #1,D1              // 1 sector
	move.l D3,D0             // drive
	move.l _dskbufp,A0       // read ext sector for XGM
	jsr read_sectors
	bmi .error_next_drive_tos
	move.l A0,A2
	lea 0x1C6(A2),A2         // infos partitions
	moveq #0,D2              // ext sector for XGM
	moveq #1,D4              // 1 entry by ext sector
	bra .loop_partition_tos
.partition_ok_tos:                    // know this partition type
	move.l (A2),D1
	and.l #0xFFFFFF,D1       // ID
	move.l 4(A2),D2          // start sect
	move.l A3,D0             // pun_ptr
	beq .test_1st_bootable_tos
	cmp.l #16,D6
	bcc .test_1st_bootable_tos
             addq.l #1,A4             // partition count
	lea pinfo_ptype(A3),A1
	move.l D1,(A1,D6.l*4)
	move.l D2,pinfo_pstart(A3,D6.l*4)
	lea pinfo_psize(A3),A1
	move.l 8(A2),D0
	cmp.l #0x47454D,D1       // GEM
	beq.s .check_partition_size_tos
	cmp.l #0x42474D,D1       // BGM
	bne.s .no_limit_size_tos
.check_partition_size_tos:
	cmp.l #0x400000,D0
	bcs.s .no_limit_size_tos
	move.l #0x400000,D0      // 2GB limit
.no_limit_size_tos:
	move.l D0,(A1,D6.l*4)
	move.b D3,pinfo_pun(A3,D6.l) // drive
	move.w pinfo_puns(A3),D0
	addq.l #1,D0
	move.w D0,pinfo_puns(A3)
#ifdef DEBUG
	lea debug12(PC),A0
	bsr display_string_single
	move.l D1,D0
	bsr hex_long
	moveq #0x20,D0
	bsr display_char
	moveq #0x30,D0
	bsr display_char
	moveq #0x78,D0
	bsr display_char
	move.l 4(A2),D0
	bsr hex_long
	moveq #0x20,D0
	bsr display_char
	moveq #0x30,D0
	bsr display_char
	moveq #0x78,D0
	bsr display_char
	move.l 8(A2),D0
	bsr hex_long
	moveq #0x20,D0
	bsr display_char
	moveq #0x41,D0
	add.l D6,D0
	bsr display_char
#endif
  	lea pinfo_flags(A3),A1
  	tst.l D3
	smi.b D0
	ext.w D0
	and.l #0x8000,D0         // flag swap
	bset #7,D0               // disk change
  	move.w D0,(A1,D6.l*2)
	addq.l #1,D6             // next logical drive       
.test_1st_bootable_tos:
	btst #0,(A2)             // active partition
	beq .next_partition_tos
	tst.l D7                 // start of 1st bootable partition
	bne .next_partition_tos
	cmp.l #0x47454D,D1       // GEM
	beq.s .partition_gem
	cmp.l #0x42474D,D1       // BGM
	bne .next_partition_tos
.partition_gem:
	move.b (A2),D1
	tst.b D5                 // bootpref
	beq.s .all_types
	and.b #0xF8,D1           // remove unused bits
	cmp.b D5,D1              // partition type
	beq.s .partition_bootable
	bra .next_partition_tos
.all_types:  
	and.b #0xF8,D1           // remove unused bits
	beq .next_partition_tos
.partition_bootable:
	move.l 4(A2),D7          // start of partition
	move.l D3,D0             // D0: drive, D0.H: flag swap bytes
	move.l D7,D2             // start of partition
	moveq #1,D1              // 1 sector
	move.l _dskbufp,A0       // read boot sector
	lea 512(A0),A0
	jsr read_sectors
	bmi .error_next_drive_tos
	move.l _dskbufp,A0       // buffer
	bsr check_root
	bne .not_bootable_tos
	move.l A3,D0             // pun_ptr
	beq .next_partition_tos
  	lea pinfo_flags(A3),A1
  	bset #0,-1(A1,D6.l*2)    // bootable
	bra .next_partition_tos
.not_bootable_tos:
	moveq #0,D7              // try another partition
	bra .next_partition_tos
.end_partitions_tos:
	move.l D7,D0             // start of 1st bootable partition
	bne.s .boot_partition_found_tos
	// no bootable partition found => menu for select
	bsr search_bootable_pun
	bpl .error_next_drive_tos // another disk bootable found
	moveq #0,D0
	move.l A4,D1             // nb lines
	beq .error_next_drive_tos // not found
	addq.l #1,D1
	lea message126(PC),A0
	lea tab_partition(PC),A1
	bsr common_menu
	ext.l D0
	beq.s .error_next_drive_tos // ignore => not found
	subq.l #1,D0
	add.l A5,D0              // logical drive start
	move.l D0,D6
	move.l pinfo_pstart(A3,D6.l*4),D2 // start of partition
	move.l D3,D0             // D0: drive, D0.H: flag swap bytes
	moveq #1,D1              // 1 sector
	move.l _dskbufp,A0       // read boot sector
	lea 512(A0),A0
	jsr read_sectors
	bmi.s .error_next_drive_tos
//	move.l _dskbufp,A0       // buffer
//	bsr check_root
//	bne.s .error_next_drive_tos
	move.l D2,D0             // start of partition
	move.l A3,D1             // pun_ptr
	beq.s .boot_partition_found_tos
  	lea pinfo_flags(A3),A1
  	bset #0,1(A1,D6.l*2)     // bootable
.boot_partition_found_tos:	
	move.l _dskbufp,A0       // buffer
	lea 512(A0),A1
	moveq #127,D1
.copy_boot_sector_tos:
		move.l (A1)+,(A0)+
	subq.l #1,D1
	bpl.s .copy_boot_sector_tos
	tst.l D0
	bra.s .end_search_tos_partition
.error_next_drive_tos:
	moveq #-1,D0             // error	
.end_search_tos_partition:
	movem.l (SP)+,D1-A5
	rts

atari_root:

	lea message48(PC),A0
	bsr display_string
#ifdef DEBUG
	move.l _dskbufp,A1
	moveq #31,D1
	bsr dump
#ifndef COLDFIRE
	bsr wait_key
#endif
#endif /* DEBUG */
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D0
	move.l _dskbufp,A0
	move.l #0x444D4172,D3    // DMAr
	move.w D4,D7
	asl.w #5,D7
	move.w 0xA80,D5          // bootpref NVM
	btst #2,D0               // CTRL
	bne .normal_bootpref
	and.w #0x67,D5           // remove TOS, Linux, MagiC flags for menu_boot
.normal_bootpref:
	movem.l A5/A6,-(SP)
	move.l pun_ptr,-(sp)
	clr.l pun_ptr
	move.l hdv_rw,-(SP)
	jsr (A0)                 // exec boot sector
	move.l (SP)+,D0
	move.l (SP)+,D1
	movem.l (SP)+,A5/A6
	cmp.l hdv_rw,D0
	bne .end_boot_drive_atari // driver installed by boot sector
	move.l D1,pun_ptr
#if !defined(USE_ATARI_IO) || defined(COLDFIRE)

atari_root2:

	moveq #PUN_IDE,D0
	and.w D4,D0
	beq .next_drive_atari
	move.l _dskbufp,A0
	moveq #0,D2              // root sector
	moveq #1,D1              // 1 sector
	moveq #0,D0              // no swap bytes
	move.w D4,D0             // drive
	jsr read_sectors         // reload (buffer maybe destroyed)
	bmi.s .next_drive_atari
	bsr search_empty_pun
	bmi.s .next_drive_atari
	move.l D0,D1             // logical drive
	moveq #0,D0              // no swap bytes
	move.w D4,D0             // drive
	move.w D5,D2             // bootpref
	bsr search_tos_partition // D0: drive, D0.H: flag swap bytes, D1: logical drive, D2: bootpref
#endif /* USE_ATARI_IO */
.next_drive_atari:
	moveq #0,D0
	rts
.end_boot_drive_atari:
	moveq #1,D0
	rts

search_dos_partition:                 // D0: drive, D0.H: flag swap bytes
                                      // D1: logical drive
	movem.l D1-A5,-(SP)
	move.w D0,D3             // drive
	moveq #0,D6
	move.w D1,D6             // logical drive
	moveq #0,D7              // start of 1st bootable partition
	move.l pun_ptr,A3
	move.l _dskbufp,A2
	lea 0x1BE(A2),A2         // infos partitions MSDOS
	lea 0,A4                 // partition count
	move.l D6,A5             // logical drive start
	moveq #3,D4              // 4 partitions
.loop_partition_msdos:
		tst.l 12(A2)       // nr sect
		beq .next_partition_msdos
		moveq #0,D1
		move.b 4(A2),D1    // partition type
		cmp.l #0x5,D1      // extended partition
		beq .extended_partition_msdos
		cmp.l #0xF,D1      // WIN95 extended partition
		beq .extended_partition_msdos
#if 1
		tst.l D1
		bne.s .partition_ok_msdos
#else
		cmp.l #0x1,D1      // FAT12 up to 15M
		beq.s .partition_ok_msdos
		cmp.l #0x4,D1      // FAT16 up to 32M
		beq.s .partition_ok_msdos
		cmp.l #0x6,D1      // FAT16 over 32M
		beq.s .partition_ok_msdos
		cmp.l #0xE,D1      // WIN95 FAT16
		beq.s .partition_ok_msdos
#endif
		bra.s .next_partition_msdos
.extended_partition_msdos:
		move.l 8(A2),D2    // start sect = extended partition
		ror.w #8,D2
		swap D2
 		ror.w #8,D2
		lea 16(A2),A2
		subq.l #1,D4
		bpl.s .loop_partition_msdos
		bra.s .test_extended_partition_msdos
.next_partition_msdos:
		moveq #0,D2
		lea 16(A2),A2
	subq.l #1,D4
	bpl.s .loop_partition_msdos
.test_extended_partition_msdos:
	tst.l D2
	beq .end_partitions_msdos // no extended partition
	moveq #1,D1              // 1 sector
	moveq #-1,D0             // swap bytes
	move.w D3,D0             // drive
	move.l _dskbufp,A0       // read extended partition
	jsr read_sectors
	bmi .error_next_drive_msdos
	move.l A0,A2
	cmp.w #0x55AA,510(A2)    // magic
	bne .error_next_drive_msdos  
	lea 0x1BE(A2),A2         // infos partitions
	moveq #0,D2
	moveq #1,D4              // 1 entry by ext sector
	bra .loop_partition_msdos
.partition_ok_msdos:                  // know this partition type
	move.l 8(A2),D2          // start sect
	ror.w #8,D2
	swap D2
 	ror.w #8,D2
	move.l A3,D0             // pun_ptr
	beq .test_1st_bootable_msdos
	cmp.l #16,D6             // logical drive
	bcc .test_1st_bootable_msdos
             addq.l #1,A4             // partition count
	lea pinfo_ptype(A3),A1
	move.l D1,(A1,D6.l*4)
	move.l D2,pinfo_pstart(A3,D6.l*4)
	move.l 12(A2),D0         // nr sect
	ror.w #8,D0
	swap D0
 	ror.w #8,D0
  	lea pinfo_psize(A3),A1
	cmp.l #0x1,D1            // FAT12 up to 15M
	beq.s .check_partition_size_msdos
	cmp.l #0x4,D1            // FAT16 up to 32M
	beq.s .check_partition_size_msdos
	cmp.l #0x6,D1            // FAT16 over 32M
	beq.s .check_partition_size_msdos
	cmp.l #0xE,D1            // WIN95 FAT16
	bne.s .no_limit_size_msdos
.check_partition_size_msdos:
	cmp.l #0x400000,D0
	bcs.s .no_limit_size_msdos
	move.l #0x400000,D0      // 2GB limit
.no_limit_size_msdos:
	move.l D0,(A1,D6.l*4)
	move.b D3,pinfo_pun(A3,D6.l) // drive
	move.w pinfo_puns(A3),D0
	addq.l #1,D0
	move.w D0,pinfo_puns(A3)
#ifdef DEBUG
	move.l D0,-(SP)
	lea debug15(PC),A0
	bsr display_string_single
	move.l D1,D0
	bsr hex_long
	moveq #0x20,D0
	bsr display_char
	moveq #0x30,D0
	bsr display_char
	moveq #0x78,D0
	bsr display_char
	move.l D2,D0
	bsr hex_long
	moveq #0x20,D0
	bsr display_char
	moveq #0x30,D0
	bsr display_char
	moveq #0x78,D0
	bsr display_char
	move.l (SP)+,D0
	bsr hex_long
	moveq #0x20,D0
	bsr display_char
	moveq #0x41,D0
	add.l D6,D0
	bsr display_char
#endif
  	lea pinfo_flags(A3),A1
  	move.w #0x8080,(A1,D6.l*2) // flag swap & disk change
	addq.l #1,D6             // next logical drive
.test_1st_bootable_msdos:
	cmp.b #0x80,(A2)         // active partition bootable
	bne .next_partition_msdos
	tst.l D7                 // start of 1st bootable partition
	bne .next_partition_msdos
	cmp.l #0x1,D1            // FAT12 up to 15M
	beq.s .read_boot_sector_msdos
	cmp.l #0x4,D1            // FAT16 up to 32M
	beq.s .read_boot_sector_msdos
	cmp.l #0x6,D1            // FAT16 over 32M
	beq.s .read_boot_sector_msdos
	cmp.l #0xE,D1            // WIN95 FAT16
	bne .next_partition_msdos
.read_boot_sector_msdos:
	move.l D2,D7             // start of partition
	moveq #1,D1              // 1 sector
	moveq #-1,D0             // swap bytes
	move.w D3,D0             // drive
	move.l _dskbufp,A0       // read boot sector
	lea 512(A0),A0
	jsr read_sectors
	bmi .error_next_drive_msdos
	cmp.w #0x55AA,510(A0)    // magic
	bne .not_bootable_msdos
	move.l A3,D0             // pun_ptr
	beq .next_partition_msdos
  	lea pinfo_flags(A3),A1
  	bset #0,-1(A1,D6.l*2)    // bootable
	bra .next_partition_msdos
.not_bootable_msdos:
	moveq #0,D7              // try another partition
	bra .next_partition_msdos
.end_partitions_msdos:
	move.l D7,D0             // start of 1st bootable partition
	bne.s .boot_partition_found_msdos
	// no bootable partition found => menu for select
	bsr search_bootable_pun
	bpl .error_next_drive_msdos // another disk bootable found
	moveq #0,D0
	move.l A4,D1             // nb lines
	beq.s .error_next_drive_msdos // not found
	addq.l #1,D1
	lea message126(PC),A0
	lea tab_partition(PC),A1
	bsr common_menu
	ext.l D0
	beq.s .error_next_drive_msdos // ignore => not found
	subq.l #1,D0
	add.l A5,D0              // logical drive start
	move.l D0,D6
	move.l pinfo_pstart(A3,D6.l*4),D2 // start of partition
	moveq #1,D1              // 1 sector
	moveq #-1,D0             // swap bytes
	move.w D3,D0             // drive
	move.l _dskbufp,A0       // read boot sector
	lea 512(A0),A0
	jsr read_sectors
	bmi.s .error_next_drive_msdos
//	cmp.w #0x55AA,510(A0)    // magic
//	bne.s .error_next_drive_msdos
	move.l D2,D0             // start of partition
	move.l A3,D1             // pun_ptr
	beq.s .boot_partition_found_msdos
  	lea pinfo_flags(A3),A1
  	bset #0,1(A1,D6.l*2)     // bootable
.boot_partition_found_msdos:
	move.l _dskbufp,A0       // buffer
	lea 512(A0),A1           // boot sector already read
	moveq #127,D1
.copy_boot_sector_msdos:
		move.l (A1)+,(A0)+
	subq.l #1,D1
	bpl.s .copy_boot_sector_msdos
	tst.l D0
	bra.s .end_search_dos_partition
.error_next_drive_msdos:
	moveq #-1,D0
.end_search_dos_partition:
	movem.l (SP)+,D1-A5
	rts

msdos_root:                           // last bytes of root sector are 0xAA55

	btst #4,D4
	beq .not_ide_drive       // SCSI
	tst.w D7
	bpl .next_drive_msdos    // LBA not supported (needed by read_sectors)
.not_ide_drive:
	move.l _dskbufp,A0
	moveq #1,D0
	jsr swap_buffer
	lea message90(PC),A0     // boot MSDOS combined
	bsr display_string
#ifdef DEBUG
	move.l _dskbufp,A1
	moveq #31,D1
	bsr dump
#ifndef COLDFIRE
	bsr wait_key
#endif
#endif /* DEBUG */
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D0
	move.l #0x444D4172,D3    // DMAr
	move.w D4,D7
	asl.w #5,D7
	move.w 0xA80,D5          // bootpref NVM
	btst #3,D0               // ALT 
	bne .next_drive_msdos
	btst #2,D0               // CTRL
	bne .normal_bootpref_2
	and.w #0x67,D5           // remove TOS, Linux, MagiC flags for menu_boot
.normal_bootpref_2:
	bsr search_empty_pun
	bmi .next_drive_msdos
	move.l D0,D1             // logical drive
	move.l _dskbufp,A0
	bsr check_root
	beq .root_combined_valid
	// DOS only
	move.w D4,D0             // drive
	bsr search_dos_partition // D0: drive, D0.H: flag swap bytes, D1: logical drive
	bmi .next_drive_msdos
	move.l D0,D2
 	bra.s .boot_tos_partition
.root_combined_valid:
	moveq #-1,D0             // swap bytes
	move.w D4,D0             // drive
	move.w D5,D2             // bootpref
	bsr search_tos_partition // D0: drive, D0.H: flag swap bytes, D1: logical drive, D2: bootpref
	bmi .next_drive_msdos
	move.l D0,D2             // start of partition
.boot_tos_partition:
#ifdef DEBUG
	lea debug13(PC),A0
	bsr display_string_single
	move.l D2,D0
	bsr hex_long
#endif
	move.l pun_ptr,-(sp)
	clr.l pun_ptr
	move.l hdv_rw,-(SP)
	move.l D2,D1             // start of partition
	moveq #-1,D0             // swap bytes
	move.w D4,D0             // drive
	bsr exec_sys             // try to load xxxxdriver.sys without boot sector
	move.l (SP)+,D0
	move.l (SP)+,D1
	cmp.l hdv_rw,D0
	bne .end_boot_drive_dos  // driver installed
	move.l D1,pun_ptr
.next_drive_msdos:
	moveq #0,D0
	rts
.end_boot_drive_dos:                  // driver installed
	move.w _bootdev,-(SP)
	move.w #7,-(SP)          // Getbpb
	trap #13
	addq.l #4,SP
	tst.l D0
	bne .end_boot_drive_msdos
	lea message92(PC),A0     //  BPB invalid
	bsr display_string
	bsr wait_key
	clr.w _bootdev
.end_boot_drive_msdos:
	moveq #1,D0
	rts

search_empty_pun:

	move.l pun_ptr,D0
	beq.s .no_pun_ptr
	move.l D0,A0
	moveq #2,D0              //  drive C
.find_empty_pun:
		tst.b pinfo_pun(A0,D0.l)
		bmi.s .pun_free
		addq.l #1,D0
	cmp.l #16,D0
	bcs.s .find_empty_pun
.no_pun_ptr:
	moveq #-1,D0             // full
.pun_free:
	tst.l D0
	rts

search_bootable_pun:

	move.l A1,-(SP)
	move.l pun_ptr,D0
	beq.s .no_pun_ptr2
	move.l D0,A0
	moveq #2,D0              //  drive C
	lea pinfo_flags(A0),A1
.find_bootable_pun:
		tst.b pinfo_pun(A0,D0.l)
		bmi.s .next_pun
		btst #0,1(A1,D0.l*2)     // bootable
		bne.s .pun_found
.next_pun:
		addq.l #1,D0
	cmp.l #16,D0
	bcs.s .find_bootable_pun
.no_pun_ptr2:
	moveq #-1,D0             // error
.pun_found:
	move.l (SP)+,A1
	tst.l D0
	rts
	
check_root:

#ifdef COLDFIRE
	lea -16(SP),SP
	movem.l D0-D2/A0,(SP)
	move.l #255,D0
	moveq #0,D1
.loop_checksum:
		moveq #0,D2
		move.w (A0)+,D2
		add.l D2,D1
	subq.l #1,D0
	bpl.s .loop_checksum
	and.l #0xFFFF,D1
#ifdef DEBUG
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.w D1,D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	cmp.l #0x1234,D1
	movem.l (SP),D0-D2/A0
	lea 16(SP),SP
#else
	movem.l D0-D1/A0,-(SP)
	move.w #255,D0
	moveq #0,D1
.loop_checksum:
		add.w (A0)+,D1
	dbf D0,.loop_checksum
	cmp.w #0x1234,D1
	movem.l (SP)+,D0-D1/A0
#endif /* COLDFIRE */
	rts
	
exec_sys:  		// D0 drive, D0.H: flag swap bytes, D1.L: start of partition

#if defined(USE_ATARI_IO) && !defined(COLDFIRE)
//#ifdef USE_ATARI_IO
	movem.l D1-D7/A4,-(SP)
	link A6,#-32
	move.l D0,D4             // drive & flag swap bytes
	move.l D1,D6             // start of partition
	move.w #3,-(SP)          // TT ram if possible
	move.l #-1,-(SP)         // size
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	move.l D0,D5             // greater block
	move.l D0,-4(A6)
	move.w #3,-(SP)          // TT ram if possible
	move.l D5,-(SP)          // size
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	beq .boot_error
	move.l D0,A4             // buffer
	move.l D0,-16(A6)
	move.l _dskbufp,A0       // boot sector
	moveq #0,D1
	move.b 0xC(A0),D1        // BPS * 256
	lsr.w #1,D1              // / 512
	move.l D1,-12(A6)        // BPS / 512
	moveq #0,D2
	move.b 0x12(A0),D2
	asl.w #8,D2
	move.b 0x11(A0),D2       // NDIRS
	move.w 0xE(A0),D3        // RES
	ror.w #8,D3
	mulu D1,D3               // * (BPS / 512)
	add.l D6,D3
	move.l D3,-8(A6)
	move.w 0x16(A0),D6       // SPF
	ror.w #8,D6
	mulu D1,D6               // * (BPS / 512)
	moveq #0,D1
	move.b 0x10(A0),D1       // NFATS
	mulu D1,D6
	add.l D3,D6              // + RES + start sector of partition
	lsr.l #4,D2              // NDIRS / 32
	add.l D6,D2
#ifdef DEBUG
	lea debug14(PC),A0
	bsr display_string_single
	move.l D6,D0
	bsr hex_long
#endif
	move.l D2,-20(A6)        // end directory
	move.l D6,D2             // 1st sector directory
.loop_read_dir:	
		move.l -16(A6),A0               // buffer Mxalloc
		moveq #1,D1                     // 1 sector
		move.l D4,D0                    // drive & flag swap bytes
		jsr read_sectors                // read directory
		bmi .mfree_boot
		move.l -16(A6),A0               // buffer Mxalloc
		moveq #15,D1
.next_entry_dir:
			cmp.b #0x53,8(A0)  // S
			bne.s .bad_ext
			cmp.b #0x59,9(A0)  // Y
			bne.s .bad_ext
			cmp.b #0x53,10(A0) // S
			beq.s .ext_ok
.bad_ext:
			lea 32(A0),A0
		dbf D1,.next_entry_dir
		addq.l #1,D2
	cmp.l -20(A6),D2
	bcs.s .loop_read_dir
	bra .mfree_boot
.bad_file:
	lea message93(PC),A0     // not a TOS binary
	bsr display_string       
	move.l -16(A6),A0        // buffer Mxalloc
	moveml -28(A6),D2        // restore loop_read_dir context
	moveq #1,D1              // 1 sector
	move.l D4,D0             // drive & flag swap bytes
	jsr read_sectors         // reload directory
	bmi .mfree_boot
	movem.l -32(A6),D1/D2/A0 // restore loop_read_dir context
	bra.s .bad_ext 
.ext_ok:
	movem.l D1/D2/A0,-32(A6) // save loop_read_dir context
	move.l A0,-(SP)
	lea message91(PC),A0     // boot found
	bsr display_string       // display driver name
	move.l (SP)+,A0
	moveq #10,D1
	moveq #0,D2
.loop_name_driver:	
		cmp.w #8,D2
		bne.s .not_point
		moveq #0x2E,D0
		bsr display_char
.not_point:
		move.b (A0,D2),D0
		bsr display_char
		addq.w #1,D2
	dbf D1,.loop_name_driver
	move.l 28(A0),D5         // size file
	ror.w #8,D5
	swap D5
	ror.w #8,D5
	add.l #0x1800,D5         // stack size
	cmp.l -4(A6),D5          // size block Mxalloc
	bhi .mfree_boot
	move.l -16(A6),A4        // buffer Mxalloc
	add.l -4(A6),A4          // size block Mxalloc
	lea -0x8000(A4),A4       // top of the block
	move.l -16(A6),A2        // buffer Mxalloc
	move.w 26(A0),D6         // 1st cluster
	ror.w #8,D6
	moveq #-1,D3
.loop_read_file:
		move.l _dskbufp,A0       // boot sector
		moveq #0,D1
		move.b 0xD(A0),D1        // SPC
		mulu -10(A6),D1          // BPS / 512 = sec count
		move.w D6,D2             // cluster
		subq.w #2,D2
		mulu D1,D2               // * sec count * SPC
		add.l -20(A6),D2         // + end directory = start sector
		move.l A2,A0             // buffer file
		move.l D4,D0             // drive & flag swap bytes
		jsr read_sectors
		bmi .mfree_boot
		asl.l #8,D1              // * 512
		add.l D1,D1              // bytes
		add.l D1,A2              // + file offset
		move.w D6,D2
		ext.l D2
		lsr.l #8,D2
		add.l -8(A6),D2          // + RES + start sector of partition
		cmp.l D3,D2              // start sector
		beq.s .not_reload_fat
		move.l D2,D3
		move.l A4,A0             // buffer FAT
		moveq #1,D1              // sec count
		move.l D4,D0             // drive & flag swap bytes
		jsr read_sectors
		bmi .mfree_boot
.not_reload_fat:
		and.w #255,D6
		add.w D6,D6
		move.w (A4,D6),D6        // cluster from FAT entry
	ror.w #8,D6
	bpl.s .loop_read_file
	move.l -16(A6),A2        // buffer Mxalloc
	move.l A2,A0             // buffer file
	cmp.w #0x601A,(A0)+      // binary test
	bne .bad_file
	lea 0x1C(A2),A1          // + header size
	add.l (A0)+,A1           // + text segment
	add.l (A0)+,A1           // + data segment
	add.l 4(A0),A1           // + bss segment
	tst.l (A1)
	beq.s .end_reloc
	lea 0x1C(A2),A0          // + header size
	move.l A0,D1
	moveq #0,D0
	add.l (A1)+,A0
.loop_reloc:
		add.l D1,(A0)
.loop_reloc_2:
			move.b (A1)+,D0
			beq.s .end_reloc
			cmp.b #1,D0
			bne.s .next_reloc
			lea 254(A0),A0
		bra.s .loop_reloc_2
.next_reloc:
		add.w D0,A0
	bra.s .loop_reloc
.end_reloc:
	cpusha BC                // flush
	move.l -4(A6),D0         // size block Mxalloc
	unlk A6
	movem.l (SP)+,D1-D7/A4
	jmp 0x20(A2)	            // start file after the 1st BRA
.mfree_boot:
	move.l -16(A6),-(SP)     // buffer Mxalloc
	move.w #0x49,-(SP)       // Mfree
	trap #1
	addq.l #6,SP
.boot_error:
	unlk A6
	movem.l (SP)+,D1-D7/A4
#endif /* USE_ATARI_IO */
	rts

common_menu:

	movem.l D1-A5,-(SP)
	move.w D0,D4             // index
	move.w D0,D5             // index
	move.w D1,D6             // maxi
	move.l A1,A5             // lines menu
	bsr display_string       // title
.display_common_menu_again:
		move.w D6,D1
		subq.w #1,D1
		moveq #0,D2
		moveq #0,D3
.display_common_menu_loop:	
			moveq #0x20,D0
			bsr display_char
			moveq #0x20,D0
			bsr display_char			
			cmp.w D4,D2       // index
			bne.s .menu_no_display_inv
			moveq #27,D0
			bsr display_char
			moveq #0x70,D0
			bsr display_char
.menu_no_display_inv:
			move.w D2,D0
			add.w D0,D0
			move.w (A5,D0.w),D0
			lea (A5,D0.w),A0
			bsr display_string
			cmp.w D4,D2       // index
			bne.s .menu_no_display_inv2
			moveq #27,D0
			bsr display_char
			moveq #0x71,D0
			bsr display_char
			move.w D2,D3
.menu_no_display_inv2:
			lea crlf(PC),A0
			bsr display_string_single
			addq.w #1,D2
		dbf D1,.display_common_menu_loop
.wait_common_menu:
			bsr wait_key
			cmp.w #0x20,D0    // SPACE
			beq .end_common_menu
			cmp.w #13,D0      // ENTER
			beq .end_common_menu
			swap D0           // scan-code
			cmp.w #0x48,D0    // UP
			beq.s .menu_key_up
			cmp.w #0x50,D0    // DOWN
			beq.s .menu_key_down
		bra.s .wait_common_menu
.menu_key_up:
		move.w D6,D1
		subq.w #1,D1
		subq.w #1,D3
		bpl.s .menu_cursor_up_loop
		move.w D6,D3
		subq.w #1,D3
		bra.s .menu_cursor_up_loop
.menu_key_down:	
		move.w D6,D1
		subq.w #1,D1
		addq.w #1,D3
		cmp.w D6,D3
		bcs.s .menu_cursor_up_loop
		moveq #0,D3
.menu_cursor_up_loop:
			moveq #27,D0
			bsr display_char
			moveq #0x41,D0
			bsr display_char
		dbf D1,.menu_cursor_up_loop
		moveq #13,D0
		bsr display_char
		move.w D3,D4 // index
	bra .display_common_menu_again
.end_common_menu:
	moveq #-1,D0
	cmp.w D4,D5              // index changed ?
	beq.s .menu_no_change
	moveq #0,D0
.menu_no_change:
	move.w D4,D0             // new selected index
	tst.l D0
	movem.l (SP)+,D1-A5
	rts

menu_boot:

#if defined(COLDFIRE) && !defined(MCF547X)
	bsr wait_key
#endif
#ifndef COLDFIRE
	link A6,#-12
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	moveq #0xC,D0            // ALT or CTRL
	and.b (A0),D0
	bne .normal_boot
#ifdef COLDFIRE
#ifdef DEBUG
	lea debug117(PC),A0
	bsr debug_display_string
#endif
#endif
	pea -12(A6)              // buffer
	move.w #12,-(SP)         // size
	clr.w -(SP)              // start
	clr.w -(SP)              // read
	move.w #46,-(SP)         // NVMaccess
	trap #14
	lea 12(SP),SP
	move.w -12(A6),D5        // bootpref
	beq .normal_boot
	moveq #0,D4
	move.b -2(A6),D4         // bootdelay in seconds
	cmp.w #99,D4
	bcs.s .delay_ok
	moveq #99,D4             // bootdelay maxi
.delay_ok:
	mulu #200,D4             // timer 200 Hz
	bne.s .display_menu
	move.w #DEFAULT_BOOT_DELAY,D4
.display_menu:
	lea message77(PC),A0     // boot menu
	bsr display_string
.display_menu_again:
		lea tab_os(PC),A1
#ifdef COLDFIRE
		moveq #1,D1
#else
		moveq #2,D1
#endif
		moveq #0,D2
		moveq #0,D3
.display_menu_loop:	
			moveq #0x20,D0
			bsr display_char
			moveq #0x20,D0
			bsr display_char			
			move.b (A1),D0
			cmp.b -11(A6),D0     // bootpref
			bne.s .no_display_inv
			moveq #27,D0
			bsr display_char
			moveq #0x70,D0
			bsr display_char
.no_display_inv:
#ifdef COLDFIRE
			lea message80(PC),A0 // TOS
			cmp.l #1,D1
			beq.s .display_line_os
			lea message81(PC),A0 // MagiC
#else
			lea message80(PC),A0 // TOS
			cmp.w #2,D1
			beq.s .display_line_os
			lea message81(PC),A0 // MagiC
			cmp.w #1,D1
			beq.s .display_line_os
			lea message82(PC),A0 // Linux
#endif
.display_line_os:
			bsr display_string_single
			move.b (A1)+,D0
			cmp.b -11(A6),D0     // bootpref
			bne.s .no_display_inv2
			moveq #27,D0
			bsr display_char
			moveq #0x71,D0
			bsr display_char
			move.w D2,D3
.no_display_inv2:
			lea crlf(PC),A0
			bsr display_string_single
			addq.w #1,D2
		dbf D1,.display_menu_loop
		move.l _hz_200,D7
		moveq #-1,D6
.wait_menu:
			move.l _hz_200,D0
			sub.l D7,D0
			cmp.l D4,D0
			bcc .end_boot_delay
			neg.l D0
			add.l D4,D0
			divu #200,D0
			cmp.w D0,D6
			beq.s .no_display_second
			move.w D0,D6
			lea message78(PC),A0
			bsr display_string
			moveq #0,D0
			move.w D6,D0
			divu #10,D0
			tst.w D0
			beq.s .delay_less_10
			or.w #0x30,D0
			bsr display_char
.delay_less_10:
			swap D0
			or.w #0x30,D0
			bsr display_char
			lea message79(PC),A0
			bsr display_string
.no_display_second:
			bsr test_key
			beq.s .wait_menu
			bsr wait_key
			cmp.w #0x20,D0    // SPACE
			beq .end_boot_delay
			cmp.w #13,D0      // ENTER
			beq .end_boot_delay
			swap D0           // scan-code
			cmp.w #0x48,D0    // UP
			beq.s .key_up
			cmp.w #0x50,D0    // DOWN
			beq.s .key_down
		bra.s .wait_menu
.key_up:
#ifdef COLDFIRE
		moveq #1,D1
		subq.l #1,D3
#else
		moveq #2,D1
		subq.w #1,D3
#endif
		bpl.s .cursor_up_loop
#ifdef COLDFIRE
		moveq #1,D3
#else
		moveq #2,D3
#endif
		bra.s .cursor_up_loop
.key_down:	
#ifdef COLDFIRE
		moveq #1,D1
		addq.l #1,D3
		cmp.l #2,D3
#else
		moveq #2,D1
		addq.w #1,D3
		cmp.w #3,D3
#endif
		bcs.s .cursor_up_loop
		moveq #0,D3
.cursor_up_loop:
			moveq #27,D0
			bsr display_char
			moveq #0x41,D0
			bsr display_char
		dbf D1,.cursor_up_loop
		moveq #13,D0
		bsr display_char
		lea tab_os(PC),A0
		move.b (A0,D3),-11(A6) // bootpref
	bra .display_menu_again
.end_boot_delay:
	cmp.w -12(A6),D5         // bootpref
	beq.s .unchanged
	pea -12(A6)              // buffer
	move.w #2,-(SP)          // size
	clr.w -(SP)              // start
	move.w #1,-(SP)          // write
	move.w #46,-(SP)         // NVMaccess
	trap #14
	lea 12(SP),SP
.unchanged:
#ifdef COLDFIRE
	moveq #0,D0
	move.w -12(A6),D0        // bootpref
	cmp.l #0x80,D0           // TOS
	beq.s .normal_boot
	cmp.l #8,D0              // MagiC
	bne.s .normal_boot
	lea magxboot,A1	
#else
	move.w -12(A6),D0        // bootpref
	cmp.w #0x80,D0           // TOS
	beq .normal_boot
	lea magxboot,A1	
	cmp.w #8,D0              // MagiC
	beq.s .call_boot
	cmp.w #0x10,D0           // Linux
	bne.s .normal_boot
	lea ataboot,A1
#endif
.call_boot:
	moveq #0,D4              // boot on IDE master
	move.l A1,-(SP)
	clr.l -(SP)
	move.l #CT60_BOOT_ORDER,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	move.l (SP)+,A1
	tst.l D0
	bmi.s .err_boot_order 
	// 0: New boot SCSI0-7 -> IDE0-1
	// 1: New boot IDE0-1 -> SCSI0-7
	// 2: New boot SCSI7-0 -> IDE1-0
	// 3: New boot IDE1-0 -> SCSI7-0
	// 4: Old boot SCSI0-7 -> IDE0-1
	// 5: Old boot IDE0-1 -> SCSI0-7
	// 6; Old boot SCSI7-0 -> IDE1-0
	// 7: Old boot IDE1-0 -> SCSI7-0
	btst #1,D0
	sne.b D4
	ext.w D4
	ext.l D4                 // boot on IDE slave
.err_boot_order:
	move.l #0x5F504349,D0    // _PCI cookie
	bsr get_cookie
	move.l D0,D3
	move.l #0x5F465245,D0    // _FRE cookie, external clock
	bsr get_cookie
	move.l D0,D2
	move.l #0x5F465251,D0    // _FRQ cookie, internal clock
	bsr get_cookie
	move.l D0,D1
	move.l #0x5F465055,D0    // _FPU cookie
	bsr get_cookie
	jsr (A1)
.normal_boot:
	unlk A6
#endif /* COLDFIRE */
	tst.w _cmdload
	beq.s .no_command
	lea message95(PC),A0     // start AUTO folder
	bsr display_string
	bsr auto_exec
	move.l #0xE00000,_sysbase
	pea null(PC)             // env
	pea null(PC)             // command
	pea 0xE00842             // file COMMAND.PRG
	clr.w -(SP)              // load'n go
	bra .go_pexec
.no_command:
	lea message95(PC),A0     // start AUTO folder
	bsr display_string
	bsr auto_exec
	move.l #0x5F504349,D0    // cookie _PCI
	bsr get_cookie
	move.l A0,D0
	beq.s .no_pci_drv
	bsr test_pci_drivers
	bne.s .no_pci_drv
	jsr 70(A0)               // drivers PCI in flash, init after auto folder
.no_pci_drv:
	move.l #0xE00000,_sysbase
#ifdef COLDFIRE
	lea env,A0
#else
	lea 0xE00836,A0          // PATH= ...
#endif
	lea 0x840,A1
	move.l A1,A2
.loop_copy_env:
		cmp.b #0x23,(A0) // #
		bne.s .no_drive_letter
		move.l A1,A2
.no_drive_letter:
		move.b (A0)+,(A1)+
	bpl.s .loop_copy_env
	move.w _bootdev,D0
	add.b #0x41,D0
	move.b D0,(A2)
	lea message96(PC),A0     // start GEM
	bsr display_string
	pea 0x840                // env
	pea null(PC)             // command
	pea null(PC)             // file
	move.w #5,-(SP)          // create basepage
	move.w #0x4B,-(SP)       // Pexec
	trap #1
	lea 16(SP),SP
	tst.l D0
	bpl.s .basepage_ok
	bsr error_tos
	jmp 0xE00030             // reset
.basepage_ok:
	move.l D0,A0             // basepage
	move.l exec_os,8(A0)
	pea 0x840                // env
	pea (A0)                 // command
	pea null(PC)             // file
	move.w #4,-(SP)          // run GEM
.go_pexec:
	move.w #0x4B,-(SP)       // Pexec
	trap #1
	lea 16(SP),SP
	jmp 0xE00030             // reset

error_tos:

	move.l D0,-(SP)
	pea message94(PC)        // error TOS
	move.w #9,-(SP)          // Cconws
	trap #1
	addq.l #6,SP
	move.l (SP)+,D0
	neg.l D0
	link A6,#-4
	clr -2(A6)
	lea -4(A6),A0
	moveq #3,D1
	bsr conv_ascii_value_optimized
	pea -4(A6)
	move.w #9,-(SP)          // Cconws
	trap #1
	addq.l #6,SP
	unlk a6

wait_key:

#if 0 // #ifdef COLDFIRE
	lea -16(SP),SP
	movem.l D1-D2/A1-A2,(SP)
#ifdef DEBUG
	move.w #1,-(SP)          // AUX
#else
	move.w #2,-(SP)          // CON
#endif
	move.w #2,-(SP)          // Bconin
	trap #13
	addq.l #4,SP
	movem.l (SP),D1-D2/A1-A2
	lea 16(SP),SP
#else
	move.w #7,-(SP)          // Crawcin
	trap #1
	addq.l #2,SP
#endif
	rts

test_key:

#ifdef COLDFIRE
	lea -16(SP),SP
	movem.l D1-D2/A1-A2,(SP)
#ifdef DEBUG
	move.w #1,-(SP)          // AUX
#else
	move.w #2,-(SP)          // CON
#endif
	move.w #1,-(SP)          // Bconstat
	trap #13
	addq.l #4,SP
	movem.l (SP),D1-D2/A1-A2
	lea 16(SP),SP
#else
	move.w #0xB,-(SP)        // Cconis
	trap #1
	addq.l #2,SP
#endif
	tst.w D0
	rts

auto_exec:

	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D0
	btst #2,D0               // CTRL
	bne.s .end_auto_exec
	move.l _drvbits,D0
	move.w _bootdev,D1
	btst D1,D0
	beq.s .end_auto_exec     // no boot drive
	lea 0xE010EE,A0          // \AUTO\*.PRG
	lea 0xE010F4,A1          // *.PRG
#ifndef AUTO_SUBROUTINE
	move.l (SP)+,0xAE4       // PC
#endif
	move.l A0,0xAE8          // path
	move.l A1,0xAEC          // file
#ifdef AUTO_SUBROUTINE
	bsr auto_exec_prg 
#else
	lea null(PC),A0
	pea (A0)
	pea (A0)
	pea (A0)	
	move.w #5,-(SP)          // create basepage
	move.w #0x4B,-(SP)       // Pexec
	trap #1
	lea 16(SP),SP
	tst.l D0
	bpl.s .basepage_ok_2
	bsr error_tos
	bra.s .end_auto_exec_2
.basepage_ok_2:
	move.l D0,A0             // basepage
	lea auto_exec_prg(PC),A1
	move.l A1,8(A0)
	pea null(PC)             // env
	pea (A0)                 // command
	pea null(PC)             // file
	move.w #4,-(SP)          // run prg
	move.w #0x4B,-(SP)       // Pexec
	trap #1
	lea 16(SP),SP
	tst.l D0
	bpl.s .end_auto_exec_2
	bsr error_tos
.end_auto_exec_2:
	move.l 0xAE4,-(SP)       // return address
#endif
.end_auto_exec:
	rts
	
auto_exec_prg:
	
#ifdef AUTO_SUBROUTINE
	movem.l D0-A6,-(SP)
#else
#define AUTO_STACK 4096 // was 256
	clr.l -(SP)
	move.w #0x20,-(SP)       // Super
	trap #1
	addq.l #6,SP
	move.l 4(SP),A6          // basepage
	lea AUTO_STACK(A6),SP
	move.l #AUTO_STACK,-(SP) // size
	pea (A6)                 // old stack
	clr.w -(SP)              // dummy
	move.w #0x4A,-(SP)       // Mshrink
	trap #1
	lea 12(SP),SP
	tst.w D0
	bne .end_auto_prg        // error
#endif
	move.l #-1,-(SP)         // handles
	clr.l -(SP)
	move.l #CT60_BOOT_LOG,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP 
	btst #0,D0
	bne.s .no_boot_log
	move.w #1,-(SP)          // stdout
	move.w #0x45,-(SP)       // Fdup
	trap #1
	addq.l #4,SP
	move.w D0,2(SP)          // dup handle
	bmi.s .no_boot_log
	clr.w -(SP)
	pea name2(PC)
	move #0x3C,-(SP)         // Fcreate
	trap #1
	addq.l #8,SP
	move.w D0,(SP)           // handle
	bmi.s .no_boot_log
	move.w D0,-(SP)
	move.w #1,-(SP)          // stdout
	move.w #0x46,-(SP)       // Fforce
	trap #1
	addq.l #6,SP
.no_boot_log:
	move.w #7,-(SP)          // all files
	move.l 0xAE8,-(SP)       // path
	move.w #0x4E,-(SP)       // Fsfirst
	moveq #8,D7              // for fix stack
.loop_auto_folder:
		pea 0xAF0            // buffer
		move.w #0x1A,-(SP)   // Fsetdta
		trap #1
		addq.l #6,SP
		trap #1              // Fsfirst or Fsnext
		add.l D7,SP
		tst.w D0
		bne .end_loop_auto   // error
		move.l 0xAE8,A0      // path
		move.l 0xAEC,A2      // file
		lea 0xB1C,A1         // auto name
.loop_copy_path:
			move.b (A0)+,(A1)+
		cmp.l A2,A0
		bcs.s .loop_copy_path
		lea 0xB0E,A0         // name from dta buffer
.loop_copy_name:
		move.b (A0)+,(A1)+
		bne.s .loop_copy_name
		move.w #13,-(SP)
		move.w #2,-(SP)      // Cconout
		trap #1
		move.w #10,-(SP)
		move.w #2,-(SP)      // Cconout
		trap #1
		addq.l #8,SP
		cmp.w #2,0x3E86      // number of planes
		bls.s .black_and_white_3
		pea blue(PC)
		move.w #9,-(SP)      // Cconws
		trap #1
		addq.l #6,SP
.black_and_white_3:
		pea 0xB1C            // auto name
		move.w #9,-(SP)      // Cconws
		trap #1
		addq.l #6,SP
		cmp.w #2,0x3E86      // number of planes
		bls.s .black_and_white_4
		pea black(PC)
		move.w #9,-(SP)      // Cconws
		trap #1
		addq.l #6,SP
.black_and_white_4:
		move.w #13,-(SP)
		move.w #2,-(SP)      // Cconout
		trap #1
		move.w #10,-(SP)
		move.w #2,-(SP)      // Cconout
		trap #1
		addq.l #8,SP
		lea 0,A2             // cookie pointer
		lea 0xB0E,A0         // name from dta buffer
		cmp.l #0x53504447,(A0) // SPDG
		bne.s .not_speedo
		cmp.l #0x444F532E,4(A0) // DOS.
		bne.s .not_speedo
		cmp.l #0x50524700,8(A0) // PRG
		bne.s .not_speedo
		clr.w -(SP)          // caches off
		move.w #cache,-(SP)
		trap #14
		addq.l #4,SP
.not_speedo:
#if 0 // #ifdef COLDFIRE
		cmp.l #0x4E564449,(A0) // NVDI
		bne.s .not_nvdi
		cmp.l #0x2E505247,4(A0) // .PRG
		bne.s .not_nvdi
		move.l #0x5F435055,D0 // _CPU cookie
		bsr get_cookie
		move.l A0,D2
		beq.s .not_nvdi
#if 1
		moveq #0,D0          // 68000 for mulu/s.l dx,dy:dz && divu/s.l dx,dy:dz
#else
		clr.w D0
		swap D0
		moveq #6,D1
		lea message127(PC),A0
		lea tab_vdo_cookie(PC),A1
		bsr common_menu
		swap D0
		clr.w D0
#endif
		move.l D2,A2
		move.l 4(A2),D2     // old value
		move.l D0,4(A2)     // value
		clr.w -(SP)         // caches off
		move.w #cache,-(SP)
		trap #14
		addq.l #4,SP
.not_nvdi:
#endif
		pea null(PC)         // env
		pea null(PC)         // command
		pea 0xB1C            // auto name
		clr.w -(SP)          // load'n go
		move.w #0x4B,-(SP)   // Pexec
		trap #1
		lea 16(SP),SP
		lea 0xB0E,A0         // name from dta buffer
		cmp.l #0x53504447,(A0) // SPDG
		bne.s .not_speedo2
		cmp.l #0x444F532E,4(A0) // DOS.
		bne.s .not_speedo2
		cmp.l #0x50524700,8(A0) // PRG
		bne.s .not_speedo2
		move.l D0,-(SP)
		move.w #1,-(SP)      // caches on
		move.w #cache,-(SP)
		trap #14
		addq.l #4,SP
		move.l (SP)+,D0
.not_speedo2:
#if 0 // #ifdef COLDFIRE
		move.l A2,D1
		beq.s .no_cookie_restore
		move.l D2,4(A2)
		move.l D0,-(SP)
		move.w #1,-(SP)      // caches on
		move.w #cache,-(SP)
		trap #14
		addq.l #4,SP
		move.l (SP)+,D0
.no_cookie_restore:
#endif
		tst.l D0
		bpl.s .pexec_ok
		cmp.l #-66,D0
		beq.s .pexec_ok
		bsr error_tos
		bra.s .end_loop_auto
.pexec_ok:
		moveq #2,D7          // for fix stack
		move.w #0x4F,-(SP)   // Fsnext
	bra .loop_auto_folder
.end_loop_auto:
	move.w (SP)+,D0          // handle
	bmi.s .end_dup
	move.w D0,-(SP)
	move.w #0x3E,-(SP)
	trap #1                  // Fclose
	addq.l #4,SP
.end_dup:
	move.w (SP)+,D0          // dup handle
	bmi.s .end_auto_prg
	move.w D0,-(SP)
	move.w #1,-(SP)          // stdout
	move.w #0x46,-(SP)       // Fforce
	trap #1
	addq.l #6,SP
.end_auto_prg:
#ifdef AUTO_SUBROUTINE
	movem.l (SP)+,D0-A6
#else
	lea 0x8870,SP            // stack
	move.l 0xAE4,-(SP)       // return address
#endif
	rts

display_device_type:	// type inside D0
		
	movem.l D0-D3/A0,-(SP)
	move.w D0,D3	
	moveq #10,D1
	move.l #0x5F414B50,D0    // _AKP cookie
	bsr get_cookie
	lsr.w #8,D0
	cmp.w #2,D0              // FRA
	beq.s .display_french
	cmp.w #7,D0              // SWF
	bne.s .display_english
.display_french:
	add.w #11,D3
	add.w #11,D1
.display_english:
	lea list_device_type(PC),A0
	moveq #0,D2
.device_type_loop:
		cmp.b D2,D3
		beq.s .device_type_found
.next_device_type:        
		tst.b (A0)+
		bne.s .next_device_type
		addq.w #1,D2
	dbf D1,.device_type_loop
	bra .read_root
.device_type_found:
		move.b (A0),D0
		bsr display_char
	tst.b (A0)+
	bne.s .device_type_found
	movem.l (SP)+,D0-D3/A0
	rts

init_ram_test:

	move.l phystop,D0
	and.l #0xFFFE0000,D0
	move.l D0,0x183E
	rts
	
display_ram_test:

	movem.l D0/D1/A0,-(SP)
	link A6,#-8
	clr -2(A6)
	lea -8(A6),A0
	moveq #6,D1
	bsr conv_ascii_value
	lea -8(A6),A0
	bsr display_string_single
	unlk A6
	movem.l (SP)+,D0/D1/A0
	rts

conv_ascii_value_optimized:           // A0:target ascii, D0.L:value, D1:len

	move.l A1,-(SP)
	link A6,#-16
	move.l A0,-(SP)
	lea -16(A6),A0
	move.w D1,-(SP)
	bsr conv_ascii_value
	move.w (SP)+,D1
	move.l (SP)+,A0
	lea -16(A6),A1
	subq.w #1,D1
	bmi.s .co3
.co1:
		move.b (A1)+,D0
		cmp.b #0x20,D0
		beq.s .co2
		move.b D0,(A0)+
.co2:
	dbf D1,.co1
	clr.b (A0)
.co3:
	unlk A6
	move.l (SP)+,A1
	rts
	
conv_ascii_value:                     // A0:target ascii, D0.L:value, D1:len

	move.w D1,-(SP)
	subq.w #1,D1
	move.l D0,-(SP)
.dv1:
		moveq #0,D0
		move.w (SP),D0
		divu #10,D0
		move.w D0,(SP)
		move.w 2(SP),D0
		divu #10,D0
		move.w D0,2(SP)
		swap D0
		or.w #0x30,D0
		move.b D0,(A0,D1.w)
	dbf D1,.dv1
	addq.w #4,SP
	move.w (SP)+,D1
	subq.w #1,D1
	beq.s .dv2
	swap D0
	tst.w D0
	bne.s .dv3
	moveq #0,D0
.dv4:
		cmp.b #0x30,(A0,D0.w)
		bne.s .dv2
		move.b #0x20,(A0,D0.w)
		addq.w #1,D0
	cmp.w D1,D0
	bne.s .dv4
	bra.s .dv2
.dv3:
	move.b #0x3F,(A0,D1.w)
	dbf D1,.dv3
.dv2:
	rts

#if 0
display_xbra:

	movem.l D0/A0/A1,-(SP)
	link A6,#-6
	clr.w -2(A6)
	move.l A0,A1
.loop_xbra:
		lea message49(PC),A0
		bsr display_string_single
		cmp.l #0x58425241,-12(A1) // XBRA
		bne.s .no_xbra
		move.l -8(A1),-6(A6)
		lea -6(A6),A0
		bsr display_string_single // ID
		move.l -4(A1),D0          // next
		beq.s .end_xbra
		move.l D0,A1
	bra.s .loop_xbra
.no_xbra:
	lea message50(PC),A0
	bsr display_string
.end_xbra:
	unlk A6
	movem.l (SP)+,D0/A0/A1
	rts
#endif

#ifdef COLDFIRE

display_mb_by_sec_disk:                // D0: total time
	
	lea -12(SP),SP
	movem.l D0-D1/A0,(SP)
	move.l #SPEED_BUFFER_SIZE*10,D1 // buffer test size
	divu.l D0,D1
	link A6,#-6
	clr.w -2(A6)
	lea -4(A6),A0
	moveq #0,D0
	move.w D1,D0
	moveq #3,D1
	bsr conv_ascii_value
	move.b -2(A6),-1(A6)
	move.b #0x2E,-2(A6)
	bsr display_string_single
	unlk A6
	lea message89(PC),A0     // MB/S
	bsr display_string
	movem.l (SP),D0-D1/A0
	lea 12(SP),SP
	rts
	
#else /* ATARI */

display_mb_by_sec_disk:                // D0: total time
	
	movem.l D0-D1/A0,-(SP)
	move.l #(SPEED_BUFFER_SIZE*256)/500,D1 // buffer test size * 256
	divu D0,D1
	link A6,#-6
	clr.w -2(A6)
	lea -4(A6),A0
	moveq #0,D0
	move.w D1,D0
	moveq #2,D1
	bsr conv_ascii_value
	move.b -3(A6),-2(A6)
	move.b #0x2E,-3(A6)
	bsr display_string_single
	unlk A6
	lea message89(PC),A0     // MB/S
	bsr display_string
	movem.l (SP)+,D0-D1/A0
	rts
	
display_value_ns_10:

	movem.l D0/A0,-(SP)
	link A6,#-4
	clr -2(A6)
	move.w D0,-(SP)
	and.l #0xFF,D0
	lsr.w #4,D0
	lea -4(A6),A0
	moveq #2,D1
	bsr conv_ascii_value_optimized
	lea -4(A6),A0
	bsr display_string_single
	moveq #0x2E,D0
	bsr display_char
	moveq #0x0F,D0
	and.w (SP)+,D0
	lea -3(A6),A0
	moveq #1,D1
	bsr conv_ascii_value_optimized
	lea -3(A6),A0
	bsr display_string_single
	lea message59(PC),A0
	bsr display_string_single
	unlk A6
	movem.l (SP)+,D0/A0
	rts
	
display_value_ns:

	movem.l D0/A0,-(SP)
	link A6,#-4
	clr -2(A6)
	and.l #0xFF,D0
	lea -4(A6),A0
	moveq #3,D1
	bsr conv_ascii_value_optimized
	lea -4(A6),A0
	bsr display_string_single
	lea message59(PC),A0
	bsr display_string_single
	unlk A6
	movem.l (SP)+,D0/A0
	rts	
	
display_latency:

	movem.l D0-D4/A0,-(SP)
	move.l D0,D4	
	moveq #0,D1
	moveq #0,D2
	moveq #6,D3
.loop_latency:
		btst D1,D4
		beq.s .next_latency
		tst.w D2
		beq.s .first_latency
		moveq #0x2F,D0
		bsr display_char
.first_latency:
		moveq #-1,D2
		moveq #0x30,D0
		add.w D1,D0
		bsr display_char
.next_latency:
		addq.w #1,D1
	dbf D3,.loop_latency	
	movem.l (SP)+,D0-D4/A0
	rts
	
#endif /* COLDFIRE */

display_version:

	move.b (A0)+,D0
	and.l #0xF,D0
	or.l #0x30,D0
	bsr display_char
	moveq #0x2E,D0           // .
	bsr display_char
	move.b (A0),D0
	and.l #0xF0,D0
	lsr.l #4,D0
	or.l #0x30,D0
	bsr display_char
	move.b (A0),D0
	and.l #0xF,D0
	or.l #0x30,D0
	bsr display_char
	rts
	
display_date:

	move.l D1,-(SP)
	move.l A1,-(SP)
	link A6,#-18
	move.l A0,A1
	clr -2(A6)
	lea -18(A6),A0
	moveq #0,D0
	move.w (A1),D0           // day
	moveq #2,D1
	bsr conv_ascii_value
	lea -15(A6),A0
	moveq #0,D0
	move.w 2(A1),D0          // month
	moveq #2,D1
	bsr conv_ascii_value
	lea -12(A6),A0
	moveq #0,D0
	move.w 4(A1),D0          // year
	moveq #4,D1
	bsr conv_ascii_value	
	lea -7(A6),A0
	moveq #0,D0
	move.w 6(A1),D0          // hour
	moveq #2,D1
	bsr conv_ascii_value
	lea -4(A6),A0
	moveq #0,D0
	move.w 8(A1),D0          // mn
	moveq #2,D1
	bsr conv_ascii_value
	bset #4,-18(A6)
	bset #4,-15(A6)
	bset #4,-7(A6)
	bset #4,-4(A6)
	moveq #0x2F,D0           // /
	move.b D0,-16(A6)
	move.b D0,-13(A6)
	moveq #0x20,D0
	move.b D0,-8(A6)
	moveq #0x3A,D0           // :
	move.b D0,-5(A6)
	lea -18(A6),A0
	bsr display_string_single		
	unlk A6
	move.l (SP)+,A1
	move.l (SP)+,D1
	rts

display_string:

	movem.l D0/A0,-(SP)	
	move.l A0,-(SP)
	move.l #0x5F414B50,D0    // _AKP cookie
	bsr get_cookie
	move.l (SP)+,A0
	lsr.w #8,D0
	cmp.w #2,D0              // FRA
	beq.s .french
	cmp.w #7,D0              // SWF
	bne.s .english
.french:
	tst.b (A0)+
	bne.s .french
.english:
	bsr display_string_single	
	movem.l (SP)+,D0/A0
	rts

display_string_single:

	movem.l D0/A0,-(SP)
.os2:
		move.b (A0)+,D0
		beq.s .os1
		bsr display_char
	bra.s .os2
.os1:
	movem.l (SP)+,D0/A0
	rts

crlf_spaces:
	move.l D0,-(SP)
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
	move.l (SP)+,D0
	
spaces:
	movem.l D0/D1,-(SP)
	moveq #11,D1
.loop_spaces:
		moveq #0x1B,D0
		bsr display_char
		moveq #0x43,D0 // ESC C
		bsr display_char
	dbf D1,.loop_spaces
	movem.l (SP)+,D0/D1
	rts

hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s hex_word
	move.l (SP)+,D0
hex_word:
	move.w D0,-(SP)
	lsr.w #8,D0          
	bsr.s hex_byte     
	move.w (SP)+,D0
hex_byte:
	move.w D0,-(SP)
	lsr.b #4,D0        
	bsr.s hex_char      
	move.w (SP)+,D0      
hex_char:
	and.b #0xF,D0      
	or.b #0x30,D0      
	cmp.b #0x3A,D0     
	bcs.s display_char  
	addq.b #7,D0   

display_char:

	movem.l D0-D2/A0-A2,-(SP)
	move.w D0,-(SP)
	move.w #2,-(SP)
	move.w #3,-(SP)          // Bconout
	trap #13
	addq.l #6,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts
	
get_value:

	movem.l D1-A5,-(SP)
	link A6,#-4
	moveq #0,D7
.loop_get_value:
		bsr wait_key
		cmp.b #13,D0
		beq.s .conv_get_value
		cmp.b #0x30,D0
		bcs.s .loop_get_value
		cmp.b #0x39,D0
		bhi.s .loop_get_value
		bsr display_char
		and.b #0x0F,D0
		move.b D0,-4(A6,D7)
		addq.w #1,D7
	cmp.w #3,D7
	bcs.s .loop_get_value
.conv_get_value:
	moveq #0,D0
	tst.w D7
	beq.s .end_get_value
	move.b -4(a6),D0
	cmp.w #1,D7
	beq.s .end_get_value
	mulu #10,D0
	add.b -3(A6),D0
	cmp.w #2,D7
	beq.s .end_get_value		
	mulu #10,D0
	add.b -2(A6),D0
.end_get_value:	
	tst.l D0
	unlk A6
	movem.l (SP)+,D1-A5
	rts
	
test_keyboard:
	
	movem.l D0-A5,-(SP)
	link A6,#-8
	move.w #0x17,-(SP)       // Gettime
	trap #14
	addq.l #2,SP
	move.l D0,D7
#if defined(COLDFIRE) && !defined(MCF547X)
	beq.s .invalid_clock
	and.l #0x01FFFFE0,D0
	cmp.l #0x00210000,D0
	bne.s .not_january_1st_00h00
.invalid_clock:
#ifdef COLDFIRE
#ifdef DEBUG
	lea debug132(PC),A0
	bsr debug_display_string
#endif
#endif
	lea ADDR_DATE,A0
	moveq #0,D0
	move.w 4(A0),D0          // year
	sub.l #1980,D0
	move.l D0,D1
	asl.l #4,D1
	moveq #0,D0
	move.w 2(A0),D0          // month
	or.l D0,D1
	asl.l #5,D1
	move.w (A0),D0           // day
	or.l D0,D1
	asl.l #5,D1
	move.w 6(A0),D0          // hour
	or.l D0,D1
	asl.l #6,D1
	move.w 8(A0),D0          // mn
	or.l D0,D1
	asl.l #5,D1
	move.l D1,-(SP)
	move.w #0x16,-(SP)       // Settime
	trap #14
	addq.l #2,SP
	move.l (SP),D1
	move.w D1,-(SP)
	move.w #0x2D,-(SP)       // Tsettime
	trap #1
	addq.l #4,SP
	move.l (SP)+,D1
	swap D1
	move.w D1,-(SP)
	move.w #0x2B,-(SP)       // Tsetdate
	trap #1
	addq.l #4,SP
.not_january_1st_00h00:	
#else /* ATARI - FIREBEE */
	clr.l -(SP)
	move.l #CT60_SAVE_NVRAM_1,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
	swap D0
	cmp.w #0x4E56,D0         // NV magic code
	beq .rtc_bypass
	move.l D7,-(SP)          // => Gettime
	jsr 0xE022CA             // Settime IKBD
	addq.l #4,SP
	moveq #5,D4              // retry counter
.rtc_bypass:
	jsr 0xE022A0             // Gettime IKBD
	tst.b 0x11C4
	bpl.s .keyboard_answer
.keyboard_error_2:
	subq.l #1,D4             // retry counter
	bgt.s .rtc_bypass
	lea message76(PC),A0     // keyboard failure
	bsr display_string
#if defined(COLDFIRE) && defined(MCF547X) /* FIREBEE disabled interrupt else infinite 0x00 bytes received */
	moveq #-1,D0
	move.b D0,stop_mfp_ikbd
#endif
	bra .no_buffer           // => rts
.keyboard_answer:
	sub.l D7,D0
	bmi.s .keyboard_error_2
	cmp.l #1,D0
	bhi.s .keyboard_error_2
#endif /* COLDFIRE */
	clr.w -(SP)              // STRAM
	move.l #0x2000,-(SP)     // 8K
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	ble .no_buffer
	move.l D0,A5             // buffer
	move.l phystop,A4        // use internal statvec
	moveq #5,D4              // retry counter
.retry_eiffel_test:
	move.l A5,pbuf_statvec(A4)
	move.l #0xCAFEFADE,flag_statvec(A4)
	move.b #0x12,-4(A6)      // IKBD mouse off
	move.b #0x21,-3(A6)      // IKBD read memory
	move.b #0x8F,-2(A6)      // Eiffel 16F 0x0FFF flash memory
	move.b #0xFF,-1(A6)
	pea -4(A6)
	move.w #3,-(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.l #8,SP
	move.l _hz_200,D1
.wait_answer_16f:
		move.l _hz_200,D0
		sub.l D1,D0
		cmp.l #20,D0          // time-out 100 mS
		bge.s .keyboard_error_3
	cmp.l pbuf_statvec(A4),A5
	beq.s .wait_answer_16f
	bra.s .keyboard_ok
.keyboard_error_3:
	subq.l #1,D4             // retry counter
	bgt.s .retry_eiffel_test
	bra .keyboard_error
.keyboard_ok:
	lea message75(PC),A0     // keyboard OK
	bsr display_string
	moveq #5,D4              // retry counter
.retry_eiffel_test_2:
	move.l A5,pbuf_statvec(A4)
	moveq #0,D6              // flag 16F
	move.b #0x21,-4(A6)      // IKBD read memory
	move.b #0x90,-3(A6)      // Eiffel 0x1000 16F flash memory
	clr.b -2(A6)
	tst.w (A5)
	beq.s .eiffel_2nd_bank_ok // firmware loaded valid
	cmp.w #0x3FFF,(A5)
	beq.s .eiffel_1st_bank_ok
	move.b #0x9F,-3(A6)      // Eiffel 18F 0x1FFE flash memory
	move.b #0xFE,-2(A6)
	pea -4(A6)
	move.w #2,-(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.l #8,SP	
	move.l _hz_200,D1
.wait_answer_18f:
		move.l _hz_200,D0
		sub.l D1,D0
		cmp.l #20,D0          // time-out 100 mS
		bge .keyboard_error_4
	cmp.l pbuf_statvec(A4),A5
	beq.s .wait_answer_18f
	move.l A5,pbuf_statvec(A4)
	moveq #-1,D6             // flag 18F
	move.b #0xA0,-3(A6)      // Eiffel 0x2000 18F flash memory
	clr.b -2(A6)
	tst.w (A5)
	beq.s .eiffel_2nd_bank_ok // firmware loaded valid
	cmp.w #0xFFFF,(A5)
	bne .end_test_keyboard   // Eiffel 16F or 18F
.eiffel_1st_bank_ok:
	move.b #0x80,-3(A6)      // Eiffel 0x0000 flash memory
.eiffel_2nd_bank_ok:
	move.l A5,A3
	move.w #(256/6),D7
.loop_read_eiffel:
		pea -4(A6)
		move.w #2,-(SP)
		move.w #0x19,-(SP)    // Ikbdws
		trap #14 
		addq.l #8,SP
		move.l _hz_200,D1
.wait_answer_keyb:
			move.l _hz_200,D0
			sub.l D1,D0
			cmp.l #20,D0 // time-out 100 mS
			bge .keyboard_error_4
		cmp.l pbuf_statvec(A4),A3
		beq.s .wait_answer_keyb
		move.l pbuf_statvec(A4),A3
		tst.w D6
		beq.s .pic16f
		add.w #3,-3(A6)
.pic16f:
		add.w #3,-3(A6)       // next word
	dbf D7,.loop_read_eiffel
	move.l A5,A0             // buffer
	move.w #(256/2)-7,D1
.loop_find_name:
		move.l A0,A2
		lea name1(PC),A1
		moveq #5,D0
.compare_name:
			addq.l #1,A2
			cmpm.b (A1)+,(A2)+
		dbne D0,.compare_name
		beq.s .eiffel_found			
		addq.l #2,A0
	dbf D1,.loop_find_name
	bra .end_test_keyboard
.keyboard_error_4:
	subq.l #1,D4             // retry counter
	bgt .retry_eiffel_test_2
	bra .keyboard_error
.eiffel_found:                        // display eiffel version
		addq.l #1,A0
		move.b (A0)+,D0
		beq.s .end_eiffel_found
		bsr display_char
	bra.s .eiffel_found
.end_eiffel_found:
	move.b #0x20,-4(A6)      // IKBD load memory
	move.b #0x01,-3(A6)      // Eiffel 0x120 ram memory
	move.b #0x20,-2(A6)
	move.b #8,-1(A6)         // 8 bytes
	pea -4(A6)
	move.w #3,-(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.l #8,SP
#ifdef COLDFIRE
	move.l #0x5F43465F,D0    // _CF_
#else
	move.l #0x43543630,D0    // CT60
#endif
	bsr get_cookie
	lea -8(A6),A0
	moveq #4,D1              // CPU speed * 10 saved inside init_sdram
	bsr conv_ascii_value
	move.b -5(A6),-4(A6)
	move.b #0x2E,-5(A6)
	move.b #0x4D,-3(A6)      // MHz
	move.b #0x48,-2(A6)
	move.b #0x7A,-1(A6)
	pea -8(A6)
	move.w #7,-(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.l #8,SP
	bra.s .end_test_keyboard
.keyboard_error:
	lea message76b(PC),A0     // keyboard failure
	bsr display_string
.end_test_keyboard:
	move.b #0x08,-4(A6)      // IKBD mouse on
	pea -4(A6)
	clr.w -(SP)
	move.w #0x19,-(SP)       // Ikbdws
	trap #14 
	addq.l #8,SP
	clr.l flag_statvec(A4)   //  not use internal statvec
	move.l A5,D0
	beq.s .no_buffer
	move.l D0,-(SP)
	move.w #0x49,-(SP)       // Mfree
	trap #1 
	addq.l #6,SP
.no_buffer:
	unlk A6
	movem.l (SP)+,D0-A5
	rts

add_sdram:

	movem.l D1-D7/A1-A5,-(SP)
	move.l _v_bas_ad,D0
	cmp.l #0x01000000,D0
#ifdef COLDFIRE
	bcs.s .font_16x8
#else
	bcs.s .check_font        // <> graphic card
	// why cursor isn't at the good place ???
	moveq #0x1B,D0
	bsr display_char
	moveq #0x48,D0           // ESC H cursor home
	bsr display_char
	lea xlf(PC),A0
	bsr display_string_single
	bsr display_string_single
.check_font:
#endif
	cmp.w #8,_v_cel_ht       // font 8 x 8
	bhi.s .font_16x8
	lea xlf(PC),A0
	bsr display_string_single
.font_16x8:
	lea message15(PC),A0     // boot version
	bsr display_string_single
	lea ADDR_VERSION,A0
	bsr display_version
	lea message15a(PC),A0    // additionnal information about version (alpha, beta...)
	bsr display_string_single
	lea ADDR_DATE,A0
	bsr display_date
	lea message15b(PC),A0
	bsr display_string_single	
	bsr test_pci_drivers
	bne.s .no_drivers
	lea 100(A0),A1
	lea message7(PC),A0      // drivers version
	bsr display_string_single
	move.l A1,A0
	bsr display_version
	moveq #0x20,D0
	bsr display_char
	lea 2(A1),A0
	bsr display_date
	lea crlf(PC),A0
	bsr display_string_single
.no_drivers:
	clr.l -(SP)
	move.l #CT60_BOOT_ORDER,-(SP)
	move.w #CT60_MODE_READ,-(SP)
	move.w #rw_parameter,-(SP)
	trap #14
	lea 12(SP),SP
#ifndef COLDFIRE
	btst #2,D0               // old boot
	bne.s .old_boot
#endif
	bsr test_keyboard
.old_boot:
	cmp.l #0x1357BD13,ramvalid
	bne .not_sdram
#ifdef COLDFIRE
#ifdef DEBUG
	lea debug115(PC),A0
	bsr debug_display_string
	move.l ramtop,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
#else
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D0
	and.b #0xF,D0
	cmp.b #0x1,D0            // RSHIFT
	bne.s .not_infos
	lea message19(PC),A0
	bsr display_string
	bsr display_infos_sdram
	bsr wait_key
	cmp.b #0x77,D0           // w
	beq .write_eeprom_sdram
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
.not_infos:
#endif
	move.l #0x01000000,D1
	move.l ramtop,D0
	sub.l D1,D0
	ble .not_sdram
	move.l D0,-(SP)          // size
	move.l D1,-(SP)          // start
	cmp.l #0x752019F3,memvalid
	bne.s .not_valid
	cmp.l #0x237698AA,memval2
	bne.s .not_valid
	cmp.l #0x5555AAAA,memval3
	beq .ram_valid
.not_valid:
	move.l D1,A4
#ifdef COLDFIRE
	add.l D0,A4              // end
#else /* ATARI - CT60 */
#ifndef INIT_SDRAM_MOVE16
	add.l D0,A4              // end
#endif
#endif /* COLDFIRE */
	move.l D0,D7
	lsr.l #8,D7              // / 256
	lea message16(PC),A0
	bsr display_string       // init SDRAM
#ifdef COLDFIRE
#ifdef DEBUG
	lea debug116(PC),A0
	bsr debug_display_string
#endif
#endif
	move.l _hz_200,A5
	moveq #0,D0
	moveq #0,D1
	moveq #0,D2
	moveq #0,D3
	move.l D0,A0
	move.l D1,A1
	move.l D2,A2
	move.l D3,A3
#ifdef COLDFIRE
	subq.l #1,D7
	moveq #0,D6
	move.w D7,D6
	clr.w D7
	swap D7
.init_sdram:
			lea -256(A4),A4
			movem.l D0-D3/A0-A3,(A4)
			movem.l D0-D3/A0-A3,32(A4)
			movem.l D0-D3/A0-A3,64(A4)
			movem.l D0-D3/A0-A3,96(A4)
			movem.l D0-D3/A0-A3,128(A4)
			movem.l D0-D3/A0-A3,160(A4)
			movem.l D0-D3/A0-A3,192(A4)
			movem.l D0-D3/A0-A3,224(A4)
		subq.l #1,D6
		bpl.s .init_sdram
		and.l #0xFFFF,D6
		moveq #0x2E,D0	
		bsr display_char
		moveq #0,D0
	subq.l #1,D7
	bpl.s .init_sdram
#else /* !COLDFIRE */
	subq.l #1,D7
	move.w D7,D6
	swap D7
#ifdef INIT_SDRAM_MOVE16
	move.l D0,D4
	lea 256(A4),A4
	move.l A4,A0
	movem.l D0-D4/A1-A3,-(A0)
	movem.l D0-D4/A1-A3,-(A0)
	movem.l D0-D4/A1-A3,-(A0)
	movem.l D0-D4/A1-A3,-(A0)
	movem.l D0-D4/A1-A3,-(A0)
	movem.l D0-D4/A1-A3,-(A0)
	movem.l D0-D4/A1-A3,-(A0)
	movem.l D0-D4/A1-A3,-(A0)
	bra.s .next_loop_sdram
#endif /* INIT_SDRAM_MOVE16 */
.init_sdram:
#ifdef INIT_SDRAM_MOVE16
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			move16 (A0)+,(A4)+
			lea -256(A0),A0
.next_loop_sdram:
#else /* !INIT_SDRAM_MOVE16 */
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
			movem.l D0-D3/A0-A3,-(A4)
#endif /* INIT_SDRAM_MOVE16 */
		dbf D6,.init_sdram
		moveq #0x2E,D0	
		bsr display_char
		moveq #0,D0
	dbf D7,.init_sdram
#endif /* COLDFIRE */
	move.l _hz_200,D1
	sub.l A5,D1
	move.l 4(SP),D0          // size
#ifdef COLDFIRE
#if 0 /* test MB/S */
	move.l _hz_200,-(SP)
	moveq #9,D7
.yy:
	move.l #0x1000000,A4      // src
	move.l _v_bas_ad,A5       // dst
	move.l #1280*1024*4,D5
	move.l #256,D4
.xx:
		movem.l (A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,(A5)
		movem.l 32(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,32(A5)
		movem.l 64(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,64(A5)
		movem.l 96(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,96(A5)
		movem.l 128(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,128(A5)
		movem.l 160(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,160(A5)
		movem.l 192(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,192(A5)
		movem.l 224(A4),D0-D3/A0-A3
		movem.l D0-D3/A0-A3,224(A5)
		add.l D4,A4
		add.l D4,A5
	sub.l D4,D5
	bgt.s .xx
	subq.l #1,D7
	bpl.s .yy
	move.l _hz_200,D1
	sub.l (SP)+,D1
	move.l #1280*1024*40,D0
#endif
#endif
	divu.l D1,D0
	divu.l #500,D0
#ifndef COLDFIRE
	move.l phystop,A0
	cmp.l measure_clock(A0),D0
	bhi.s .fast_abe_sdr
	movec.l CACR,D1
	cmp.l #0xA0808000,D1
	bne.s .fast_abe_sdr // no cache
	move.l #ABE_SDR_7,D1
	or.l D1,hardware_type(A0)
.fast_abe_sdr:
#endif
	link A6,#-6
	clr.w -2(A6)
	lea -6(A6),A0
	moveq #4,D1
	bsr conv_ascii_value
	move.b -3(A6),-2(A6)
	move.b #0x2E,-3(A6)
	bsr display_string_single
	unlk A6
	lea message17(PC),A0     // MB/S
	bsr display_string
.ram_valid:
	move.w #0x14,-(SP)       // Maddalt
	trap #1 
	lea 10(SP),SP	
	tst.l D0
	bmi .not_sdram
	clr.w -(SP)              // STRAM
	move.l #0x10000+16,-(SP) // 64K
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	ble.s .not_sdram
	addq.l #8,D0
	addq.l #7,D0
	and.b #0xF0,D0           // 16 bytes alignment
	move.l D0,A1             // fastram buffer
	clr.w -(SP)              // STRAM
	move.l #XFRB_SIZE+16+20,-(SP) // 64K
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	ble.s .not_sdram
	move.l D0,A2             // XFRB struct
	lea 18(A2),A0
	move.w #0x101,(A2)       // version
	move.l A0,2(A2)          // xflock
	clr.w (A0)+
	move.l A0,D0
	addq.l #8,D0
	addq.l #7,D0
	and.b #0xF0,D0           // 16 bytes alignment
	move.l D0,6(A2)          // buffer
	move.l #XFRB_SIZE,10(A2) // size buffer
	clr.l 14(A2)             // next XFRB struct
	move.l cookie,D0
	beq.s .not_sdram
	move.l D0,A0
.find_cookie:
		tst.l (A0)
		beq.s .cookie_free
		addq.l #8,A0
	bra.s .find_cookie
.cookie_free:
	move.l 4(A0),12(A0)      // copy size
	move.l #0x5F465242,(A0)+ // _FRB
	move.l A1,(A0)+
	move.l 4(A0),12(A0)      // copy size
	move.l #0x58465242,(A0)+ // XFRB
	move.l A2,(A0)+
	clr.l (A0)
.not_sdram:
	move.l _sysbase,A0       // header ROM
	move.l 0x24(A0),A0       // kbshift
	move.b (A0),D0
	and.b #0xF,D0
	cmp.b #0x1,D0            // RSHIFT
	seq.b D0
	ext.w D0
	move.w D0,-(SP)          // 0 or -1 (more infos)
	move.w #299,-(SP)        // display devices PCI BIOS
	trap #14
	addq.l #2,SP
	tst.w (SP)+
	beq.s .no_wait_key
	move.w D0,-(SP)
	bsr wait_key	
	move.w (SP)+,D0
.no_wait_key:
	tst.w D0
	bpl.s .no_error_pci_bios
	lea error13(PC),A0
	bsr display_string
#ifdef COLDFIRE
	bra.s .no_pci_bios	
#endif
.no_error_pci_bios:
	move.l #0x5F504349,D0    // cookie _PCI
	bsr get_cookie
	move.l A0,D0
	beq.s .no_pci_bios
	clr.b 0xA82              // no memory test (boot delay null), not works (Mxalloc)
	bsr test_pci_drivers
	bne.s .no_pci_bios
	jsr 10(A0)               // drivers PCI in flash, call after SDRAM added
.no_pci_bios:
	move.l #0x752019F3,memvalid
	move.l #0x237698AA,memval2
	move.l #0x5555AAAA,memval3
#ifdef COLDFIRE
	bsr init_cookie_cf
#else
	bsr init_cookie_ct60
	moveq #3,D0
	jsr 0xE00BD2             // cartridge
#endif
	move.l hdv_boot,A0
	jsr (A0)                 // in a 1st time call hdv_init and test _nflops
	tst.w D0
	bne.s .no_boot
	move.l _dskbufp,A0
	jsr (A0)
.no_boot:
	movem.l (SP)+,D1-D7/A1-A5
	rts

#ifdef COLDFIRE
	
bootload:	                         // hdv_boot TOS404 0xE04F54

#ifdef DEBUG
	move.l A0,-(SP)
	lea debug134(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	move.l hdv_init,A0
	jsr (A0)                 // flopini => set _drvbits and _nflops

#if 1
	move.l #1,D0
	move.l D0,_drvbits
	moveq #1,D0
	move.w D0,_nflops
#endif

	tst.w _nflops
	beq.s .bl1
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug131(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	move.w #1,-(SP)          // count
	clr.w -(SP)              // face A
	clr.w -(SP)              // track 0
	move.w #1,-(SP)          // sector 1
	clr.w -(SP)              // drive A
	clr.l -(SP)              // filler
	move.l _dskbufp,-(SP)
	move.w #8,-(SP)          // Floprd TOS404 0xE03DB4
	trap #15
	lea 20(SP),SP
	ext.l D0
	bne.s .bl2               // error
	move.l _dskbufp,A0
	bsr check_root
	bne.s .bl3               // bad checksum
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug138(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	moveq #0,D0              // OK
	bra.s .bl4
.bl2:
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug137(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	moveq #2,D0              // no drive
	bra.s .bl4
.bl1:
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug136(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	moveq #1,D0              // not loadable
	bra.s .bl4
.bl3:
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug135(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	moveq #4,D0              // bootsector invalid
.bl4:
	rts

#endif /* COLDFIRE */
	
test_pci_drivers:

	move.l #0x5F504349,D0    // _PCI
	lea 0xED0000,A0          // 128 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_pci_ok
	lea 0xEC0000,A0          // 192 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_pci_ok
	lea 0xEB0000,A0          // 256 KB, 1st part
	cmp.l (A0),D0            // _PCI
	beq.s .test_pci_ok
	lea 0xEA0000,A0          // 320 KB, 1st part
	cmp.l (A0),D0            // _PCI
.test_pci_ok:                         // (optional 2nd part inside 0xFC0000-0xFEFFFF)
	rts

	
#ifndef COLDFIRE /* ATARI - CT60 - CTCM */

ct60_configure_clock:	// D0.L: frequency, D1.W: mode, D2.W: divider (user frequency)

	movem.l D1-A1,-(SP)
	move.l D0,D6 // frequency
	move.w D1,D7 // mode
	cmp.w #2,D2  // divider
	bgt.s .ccc21
	moveq #2,D2	
.ccc21:
	cmp.w #6,D2  // divider
	blt.s .ccc20
	moveq #6,D2
.ccc20:
	move.w D2,A1 // divider
	moveq #ADR,D1
	move.w #CT60_CLOCK_READ+DALLAS,D0  // Dallas DS1085
	bsr ct60_rw_clock 
	bmi .ccc11
	move.w D0,D3 // adr
	// frequency = (DEF_FREQ + (OFFSET_STEP * (offset-offset_def)))
	//           - ((DAC_DEF-dac) * DAC_STEP))
	moveq #RANGEWORD,D1
	move.w #CT60_CLOCK_READ+DALLAS,D0
	bsr ct60_rw_clock 
	bmi .ccc10
	move.w D0,D2
	moveq #11,D0
	lsr.w D0,D2  // offset_def
//	cmp.l #MIN_FREQ_DALLAS+333,D6
//	bge.s .ccc14 // strap on CLK
//	add.l D6,D6  // strap on CLK/2
//.ccc14:
	cmp.l #MIN_FREQ_DALLAS,D6
	blt .ccc1    // error	
	cmp.l #MAX_FREQ_DALLAS,D6
	bgt .ccc1    // error	
	move.w D2,D4 // offset = offset_def
	move.l D6,D5 // frequency
	sub.l #DEF_FREQ,D5
	divs.l #DAC_STEP,D5
	add.l #DAC_DEF,D5
	bmi.s .ccc15
	cmp.l #1023,D5 // dac
	ble.s .ccc16
.ccc15:
	move.l D6,D4 // frequency
	sub.l #DEF_FREQ,D4
	divs.l #OFFSET_STEP,D4
	cmp.l #-6,D4 // offset
	blt .ccc1    // error
	cmp.l #6,D4
	bgt .ccc1    // error
	add.w D2,D4  // + offset_def
	bmi .ccc1    // error
	cmp.l #31,D4
	bgt .ccc1    // error
	move.w D4,D0 // offset
	sub.w D2,D0  // - offset def
	muls #OFFSET_STEP,D0
	add.l #DEF_FREQ,D0 // fos
	move.l D6,D5 // frequency
	sub.l D0,D5  // fos
	divs.l #DAC_STEP,D5
	add.l #DAC_DEF,D5
	bmi .ccc1    // error
	cmp.l #1023,D5 // dac
	bgt .ccc1    // error
.ccc16:
	moveq #8,D0  // WC = 0
	and.w D3,D0  // adr
	bne.s .ccc13
	moveq #8,D2  // WC = 1 => use WRITEE2 command for the EEPROM
	moveq #ADR,D1
	move.w #CT60_CLOCK_WRITE_RAM+DALLAS,D0
	bsr ct60_rw_clock
	bmi .ccc10   // error
	bsr tempo_20ms
.ccc13:
	// MUX : PDN0/1 = 0, SEL0 = 1, EN0 = 0, 0M = 1, 1M = 0, DIV1 = 0 
	move.w #0x1200,D2 // mux
	moveq #MUXWORD,D1
	move.w #CT60_CLOCK_WRITE_RAM+DALLAS,D0
	bsr ct60_rw_clock
	bmi .ccc10   // error
	move.w D5,D2 // dac
	asl.w #6,D2	
	moveq #DACWORD,D1
	move.w #CT60_CLOCK_WRITE_RAM+DALLAS,D0
	bsr ct60_rw_clock
	bmi .ccc10   // error
	move.w D4,D2 // offset
	moveq #OFFSET,D1
	move.w #CT60_CLOCK_WRITE_RAM+DALLAS,D0
	bsr ct60_rw_clock
	bmi .ccc10   // error
             move.w A1,D2 // divider
	cmp.l #66000,D6 // frequency
	bhi.s .ccc19
	moveq #2,D2  // divider
.ccc19:
             subq.w #2,D2
             asl.w #6,D2
	moveq #DIVWORD,D1
	move.w #CT60_CLOCK_WRITE_RAM+DALLAS,D0
	bsr ct60_rw_clock
	bmi .ccc10   // error
	cmp.w #CT60_CLOCK_WRITE_EEPROM,D7 // mode
	bne.s .ccc12
	moveq #0,D2
	moveq #WRITEE2,D1
	move.w #CT60_CLOCK_WRITE_EEPROM+DALLAS,D0
	bsr ct60_rw_clock
.ccc12:
	tst.l D0
	bra .ccc10
.ccc11:
	moveq #CLKOE,D1
	move.w #CT60_CLOCK_READ+CYPRESS,D0 // Cypress CY27EE16
	bsr ct60_rw_clock 
	bmi .ccc10
	// frequency (KHz) = (REF (KHz) * p) / q) / post divider
	// => p/q = (frequency * post divider) / REF (KHz)
	// p = (2 * (PB  + 4)) + P0   q = Q + 2
	// 8 <= p <= 2055             2 <= q <= 129
	or.w #CYPRESS,D7
	move.l #REF,D2
	move.l D6,D3 // frequency
	mulu.l #2000,D3
	divu.l D2,D3 // p
	move.l #(REF/250),D4 // q
.ccc2:		// 250 KHz mini => max value for q
		move.l D3,D5
		mulu.l D4,D5 // p * q
		cmp.l #2055000,D5
		bls.s .ccc3
		cmp.l #2,D4
		bcs.s .ccc3
		subq.l #1,D4
	bra.s .ccc2
.ccc3:
	cmp.l #2,D4  // q
	bcs .ccc1    // error
	cmp.l #129,D4
	bhi .ccc1    // error
	move.l D3,D5 // p
	divu.l #1000,D5
	mulu.l D2,D5 // * REF => pll
	cmp.l #100000,D5
	bcs .ccc1    // error
	cmp.l #400000,D5
	bhi .ccc1	// error
	mulu.l D4,D3 // p = (p * q) / 1000
	divu.l #1000,D3
	cmp.l #8,D3
	bcs .ccc1    // error
	cmp.l #2055,D3
	bhi .ccc1    // error
	cmp.w #CT60_CLOCK_WRITE_EEPROM+CYPRESS,D7 // mode
	bne.s .ccc18	
	moveq #0x0C,D2 // enable EEPROM writing
	moveq #WPREG,D1
	move.w #CT60_CLOCK_WRITE_RAM+CYPRESS,D0
	bsr ct60_rw_clock 
	bsr tempo_20ms
	moveq #0x0C,D2 // enable EEPROM writing
	moveq #WPREG,D1
	move.w #CT60_CLOCK_WRITE_RAM+CYPRESS,D0
	bsr ct60_rw_clock 
	bmi .ccc10
.ccc18:
	// CLKSRC2-0
	// 0: Reference input
	// 1: DIV1CLK/DIV1N
	// 2: DIV1CLK/2
	// 3: DIV1CLK/3
	// 4: DIV2CLK/DIV2N (/8)
	// 5: DIV2CLK/2
	// 6: DIV2CLK/4
	move.w #0xDE,D2
	move.w #0x4F,D1 // clocks 5 & 6 DIV1CLK/DIV1N
	cmp.l #66000,D6 // frequency
	bhi.s .ccc9
	move.w #3,A1    // /6
	move.w #0xDF,D2
	move.w #0xB7,D1 // clocks 5 & 6 DIV2CLK/4
.ccc9:
	move.w D1,D6  // MATRIX3
	swap D6
	move.w D2,D6  // MATRIX2
	move.w A1,D2  // DIV1N
	add.w D2,D2
	moveq #DIV1N,D1
	move.w D7,D0
	bsr ct60_rw_clock
	bmi .ccc10 
	move.w D6,D2
	moveq #MATRIX2,D1
	move.w D7,D0
	bsr ct60_rw_clock
	bmi .ccc10
	swap D6 
	move.w D6,D2
	moveq #MATRIX3,D1
	move.w D7,D0
	bsr ct60_rw_clock 
	bmi .ccc10
	move.l D3,D2  // p
	lsr.l #1,D2
	subq.l #4,D2
	lsr.w #8,D2
	or.w #0xC0,D2 // chargep
	cmp.l #45,D3  // p
	bcs.s .ccc6
	cmp.l #480,D3
	bcc.s .ccc5
	or.w #0x04,D2
	bra.s .ccc6
.ccc5:
	cmp.l #640,D3
	bcc.s .ccc7
	or.w #0x08,D2
	bra.s .ccc6
.ccc7:
	cmp.l #800,D3
	bcc.s .ccc8
	or.w #0x0C,D2
	bra.s .ccc6
.ccc8:
	or.w #0x10,D2 // chargep
.ccc6:
	moveq #CHARGEP,D1
	move.w D7,D0
	bsr ct60_rw_clock
	bmi .ccc10    // error
	move.l D3,D2  // p
	lsr.l #1,D2
	subq.l #4,D2
	and.w #0xFF,D2	
	moveq #PBCOUNTER,D1
	move.w D7,D0
	bsr ct60_rw_clock
	bmi .ccc10  // error
	moveq #1,D2
	and.l D3,D2 // p
	asl.l #7,D2
	add.l D4,D2 // q
	subq.l #2,D2
	moveq #QCOUNTER,D1
	move.w D7,D0
	bsr ct60_rw_clock
	bmi.s .ccc10 // error
	lea clock_registers(PC),A0
.ccc4:
		moveq #0,D0
		tst.w (A0)
		beq.s .ccc10
 		moveq #0,D1
 		move.b (A0)+,D1 // address
 		moveq #0,D2
		move.b (A0)+,D2 // data 		
		move.w D7,D0    // mode
		bsr ct60_rw_clock
		bmi.s .ccc10    // error
	bra.s .ccc4
.ccc1:
	moveq #CT60_CALC_CLOCK_ERROR,D0
.ccc10:
	movem.l (SP)+,D1-A1
	rts
 
ct60_rw_clock:               // D0.W: mode (0: read, 1:write ram, 2: write eeprom, 3: reset)
                             //       B15:Cypress(0)/Dallas(1)
                             // D1.W: address, D2:.W data, D0 return data or error
	tst.w D0                 // mode
	bmi.s .rwc4              // Dallas DS1085
	cmp.w #CT60_CLOCK_READ,D0
	bne.s .rwc2
	move.w D1,D0             // address
	bra read_i2c_cy_sram
.rwc2:
	cmp.w #CT60_CLOCK_WRITE_RAM,D0
	bne.s .rwc3
	move.w D1,D0             // address
	move.w D2,D1             // data
	bra write_i2c_cy_sram
.rwc3:
	cmp.w #CT60_CLOCK_WRITE_EEPROM,D0
	bne.s .rwc12
	move.w D1,D0             // address
	move.w D2,D1             // data
	bra write_i2c_cy_eeprom
.rwc12:
	cmp.w #CT60_CLOCK_RESET,D0
	bne .rwc1
	moveq #CTRLMACH,D0       // address
	move.w #0x80,D1          // data: reset soft
	bra write_i2c_cy_sram
.rwc4:                                // Dallas DS1085
	bclr #15,D0              // mode
	cmp.w #CT60_CLOCK_READ,D0
	bne.s .rwc5
	moveq #SLAVE_DS_ADDRESS,D0
	swap D0
	move.w D1,D0             // address
	cmp.w #ADR,D0
	beq.s .rwc8              // byte
	cmp.w #OFFSET,D0	
	bne.s .rwc7              // word	
.rwc8:
	jmp read_i2c
.rwc7:
	link A6,#-2
	lea -2(A6),A0
	moveq #2,D1              // len
	jsr read_seq_device_i2c
	bmi.s .rwc11
	move.w (A0),D0           // data
.rwc11:
	unlk A6
	rts 
.rwc5:
	cmp.w #CT60_CLOCK_WRITE_RAM,D0
	bne.s .rwc6
	moveq #SLAVE_DS_ADDRESS,D0
	swap D0
	move.w D1,D0             // address
	cmp.w #ADR,D0
	beq.s .rwc10             // byte
	cmp.w #OFFSET,D0	
	bne.s .rwc9              // word	
.rwc10:
	move.w D2,D1             // data
	jmp write_i2c
.rwc9:
	link A6,#-2
	lea -2(A6),A0
	move.w D2,(A0)           // data
	moveq #2,D1              // len
	jsr write_seq_device_i2c
	unlk A6
	rts
.rwc6:
	cmp.w #CT60_CLOCK_WRITE_EEPROM,D0
	bne.s .rwc1
	moveq #SLAVE_DS_ADDRESS,D0
	swap D0
	move.w #WRITEE2,D0       // address
	moveq #0,D1              // len
	lea 0,A0                 // no data
	jmp write_seq_device_i2c
.rwc1:
	moveq #CT60_READ_ERROR,D0
	rts
 
ct60_read_info_sdram:        // A0: 128 bytes buffer, D0 return error

	moveq #SLAVE_SDRAM_ADDRESS,D0
	swap D0
	move.w #128,D1
	jmp read_seq_device_i2c

ct60_read_info_clock:        // A0: 128 bytes buffer, D0 return error

	moveq #SLAVE_CY_SRAM_ADDRESS,D0
	swap D0
	move.w #128,D1
	jmp read_seq_device_i2c
		 
ct60_configure_sdram:

	movem.l D1-D2/A0-A1,-(SP)
	lea _sdcnf,A0
	moveq #2,D0              // memory type
	bsr read_i2c_sdram
	bmi .c1                  // error
	cmp #4,D0                // SDRAM
	beq.s .c13
	moveq #CT60_SDRAM_TYPE_ERROR,D0
	bra .c1 
.c13:
	moveq #3,D0              // number of row addresses
	bsr read_i2c_sdram
	bmi .c1                  // error
	move.w D0,D1
	moveq #4,D0              // number of column addresses
	bsr read_i2c_sdram
	bmi .c1                  // error
	lea chip_density(PC),A1
.c3:
		tst.w (a1)
		ble.s .c2                // not found => chip density error
		cmp.w (A1),D1            // number of raw addresses
		bne.s .c4
		cmp.w 2(A1),D0           // number of column addresses
		beq.s .c5                // found
.c4:
		addq.w #8,A1
	bra.s .c3
.c2: 
	moveq #CT60_CHIP_DENSITY_ERROR,D0
	bra .c1
.c5:
	add.l 4(A1),A0           // chip density on A23-A22 cdy2-1
	moveq #12,D0             // refresh rate
	bsr read_i2c_sdram
	bmi .c1                  // error
	and.w #0x7F,D0
	cmp.w #5,D0
	bhi.s .c16               // error
	cmp.w #1,D0
	beq.s .c16               // 3.9 uS => error
	cmp.w #2,D0
	bne.s .c17
	add.l #0x10000,A0        // A16 7.81 uS
	bra.s .c17	
.c16:
	moveq #CT60_REFRESH_RATE_ERROR,D0
	bra .c1
.c17:		
	moveq #5,D0              // number of DIMM banks
	bsr read_i2c_sdram
	bmi .c1                  // error
	cmp.w #1,D0
	beq.s .c6
	cmp.w #2,D0
	bne.s .c7                // num bank error
	add.l #0x100000,A0       // A20
	bra.s .c6
.c7: 
	moveq #CT60_NUM_BANK_ERROR,D0
	bra .c1
.c6:
	move.w D0,D1             // number of DIMM banks
	moveq #6,D0              // module data width
	bsr read_i2c_sdram
	bmi .c1                  // error
	cmp.w #0x40,D0
	beq.s .c18               // 64
	cmp.w #0x48,D0           // 72
	bne.s .c11               // data width error
.c18:
	moveq #7,D0              // module data width
	bsr read_i2c_sdram
	bmi .c1                  // error
	beq.s .c14
.c11:
	moveq #CT60_DATA_WIDTH_ERROR,D0
	bra .c1
.c14:
	moveq #8,D0              // voltage interface
	bsr read_i2c_sdram
	bmi .c1                  // error
	cmp.w #1,D0              // LVTTL
	beq.s .c12
	moveq #CT60_VOLTAGE_ERROR,D0
	bra .c1
.c12:
	moveq #17,D0             // number of banks on SDRAM device
	bsr read_i2c_sdram
	bmi.s .c1                // error
	cmp.w #4,D0
	bne.s .c7                // num bank error
	moveq #31,D0             // module density
	bsr read_i2c_sdram
	bmi.s .c1                // error
	cmp.w #8,D0
	beq.s .c10               // 32
	cmp.w #16,D0
	beq.s .c10               // 64
	cmp.w #32,D0
	beq.s .c10               // 128
	cmp.w #64,D0
	beq.s .c10               // 256
	cmp.w #128,D0	
	bne.s .c8                // <> 512 => module density error
.c10:
	mulu D1,D0               // * number of DIMM banks
	asl.w #2,D0              // MB
	cmp.w #64,D0
	beq.s .c9
	cmp.w #128,D0
	beq.s .c9
	cmp.w #256,D0
	beq.s .c9
	cmp.w #512,D0
	beq.s .c9
.c8: 
	moveq #CT60_MOD_DENSITY_ERROR,D0
	bra.s .c1
.c9:
	lsr.w #7,D0
	cmp.w #3,D0
	bcs.s .c15
	moveq #3,D0
.c15:
	move.l D0,D1
	swap D1
	asl.l #2,D1
	add.l D1,A0              // size on A19-A18 mdy2-1
	clr.l (A0)               // write config
	tst.l D0                 // return size 0-3 for 64MB-512MB
.c1:
	movem.l (SP)+,D1-D2/A0-A1
	rts
 
read_i2c_sdram:              // D0: address, D0 return data or error

	swap D0
	move.w #SLAVE_SDRAM_ADDRESS,D0
	swap D0
	jmp read_i2c
	
read_i2c_cy_sram:            // D0: address, D0 return data or error

	swap D0
	move.w #SLAVE_CY_SRAM_ADDRESS,D0
	swap D0
	jmp read_i2c

write_i2c_sdram:             // D0: address, D1:data, D0 return data or error

	swap D0
	move.w #SLAVE_SDRAM_ADDRESS,D0
	swap D0
	jmp write_i2c

write_i2c_cy_eeprom:         // D0: address, D1:data, D0 return data or error

	swap D0
	move.w #SLAVE_CY_EEPROM_ADDRESS,D0
	swap D0
	jmp write_i2c
	
write_i2c_cy_sram:           // D0: address, D1:data, D0 return data or error

	swap D0
	move.w #SLAVE_CY_SRAM_ADDRESS,D0
	swap D0
	jmp write_i2c
	
tempo_20ms:	

	move.l D0,-(SP)
	move.l D1,-(SP)
	move.l _hz_200,D1	
.t20:
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #4,D0               // 20 mS
	ble.s .t20
	move.l (SP)+,D1
	move.l (SP)+,D0
	rts
	
clock_registers:

	dc.b CLKOE,  0x69        // clocks 1, 4, 5, 6
	dc.b PINCTRL,0x50        // output enable pin
	dc.b OSCDRV, 0x28        // clock REF
	dc.b INLOAD, 0x6B        // capacity load
	dc.b ADCREG, 0x00
	dc.b MATRIX1,0xB6        // clocks 1 to 3 DIV2CLK/2
	dc.b DIV2N,  0x08        // post divider /8
	dc.b WPREG,  0x1C        // write protect soft on, in last position
	dc.b 0,0

chip_density:                         // A23-A22 cdy2-1

	dc.w 0xC,0x9,0x00,0      // 8Mx8b / 8Mx16b
	dc.w 0xC,0xA,0x40,0      // 16Mx8b
	dc.w 0xD,0x9,0x80,0      // 16Mx16b
	dc.w 0xD,0xA,0xC0,0      // 32Mx8b / 32Mx16b
	dc.w 0,0,0,0             // end
	
#endif /* !COLDFIRE - ATARI - CT60 - CTCM */

#ifdef COLDFIRE
init_cookie_cf:
#else
init_cookie_ct60:
#endif
	movem.l D0-D2/A0-A2,-(SP)
	move.w #3,-(SP)          // TT ram if possible
	move.l #NB_COOKIES*8,-(SP)
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	ble .error_cookie_ct60
	move.l D0,A1
	move.l cookie,D0
	beq .error_cookie_ct60
	move.l A1,cookie
	move.l D0,A0
	moveq #NB_COOKIES-1,D1   // move cookies to TT ram
.loop_move_cookies:
		move.l (A0)+,D0
		beq.s .end_cookies
		move.l D0,(A1)+
		move.l (A0)+,(A1)+
	dbf D1,.loop_move_cookies
	bra.s .init_cookie_ct60
.end_cookies:
	clr.l (A1)+
	move.l #NB_COOKIES,(A1)+
	subq.w #1,D1
	bmi.s .init_cookie_ct60
.loop_end_cookies:
		clr.l (A1)+
		clr.l (A1)+
	dbf D1,.loop_end_cookies
.init_cookie_ct60:
	move.w #3,-(SP)          // TT ram if possible
	move.l #CT60_COOKIE_SIZE,-(SP)
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	ble.s .error_cookie_ct60
	move.l D0,A1
#ifdef COLDFIRE
	move.l #0x5F43465F,D0    // _CF_
#else
	move.l #0x43543630,D0    // CT60
#endif
	bsr get_cookie
	move.l A0,D0
	beq.s .error_cookie_ct60
	move.l 4(A0),D2          // CPU frequency in MHz * 10 saved inside init_sdram
	move.l A1,4(A0)          // buffer
	moveq #(CT60_COOKIE_SIZE/4)-1,D0
.clear_data_ct60_cookie:
		clr.l (A1)+
	dbf D0,.clear_data_ct60_cookie
	move.l 4(A0),A0          // buffer
	move.l D2,8(A0)          // CPU frequency in MHz * 10
#ifndef COLDFIRE
	jsr init_speed_fan
#endif
.error_cookie_ct60:	
	movem.l (SP)+,D0-D2/A0-A2
	RTS

#ifdef COLDFIRE

	dc.l 0x58425241          // XBRA
	dc.l 0x5F43465F          // _CF_
	dc.l 0

linea000:

	jsr 0xE09512             // address function Linea 0xA000
	rte
	
#endif
	
