/*  PCI BIOS for CT60 with CTPCI
 *               Coldfire MCF547X/MCF548X & MCF5445X
 * 
 * Didier Mequignon 2005-2009, e-mail: aniplay@wanadoo.fr
 * Markus Froschle       2007
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
	.text

#undef TEST_TARGET
	
#include "ct60_hw.h"
#include "ct60.h"
#include "vars.h"
#include "pci_bios.h"

#ifndef COLDFIRE
#define LOCAL_REGISTERS_BIG
#define write_verify_local_config_longword write_local_config_longword
#endif

_install_pci_bios:

	move.w 2(A0),D0
	ext.l D0
#ifdef COLDFIRE
	cmp.l #1,D0                  // init
	bne display_devices
	lea -56(SP),SP
	movem.l D1-A6,(SP)
#else
	cmp.w #1,D0                  // init
	bne display_devices
	movem.l D1-A6,-(SP)
#endif
	move.l #0x5F504349,D0        // _PCI
	bsr get_cookie
	beq.s .pci_cookie_not_found  // not found
.abort_install:
	moveq #-1,D0                 // error
	bra .end_install
.abort_install2:
#ifndef COLDFIRE
#if 0 // #ifdef DEBUG
	bsr dump_plx
.abort_all:
	bra.s .abort_all
#endif /* DEBUG */
#endif /* COLDFIRE */
	moveq #-1,D0                 // error
	bra .end_install
#ifdef COLDFIRE
.pci_cookie_not_found:

#if 0 // moved inside sdram.S before the CF68KLIB is called (init_cf)
      // excepted interrupts
#ifdef DEBUG
	lea debug27(PC),A0
	bsr debug_display_string	
#endif
	// Setup the arbiter
	move.l #MCF_PCIARB_PACR_INTMPRI \
	 + MCF_PCIARB_PACR_EXTMPRI(0x1F) \
	 + MCF_PCIARB_PACR_INTMINTEN \
	 + MCF_PCIARB_PACR_EXTMINTEN(0x1F),D0
	move.l D0,MCF_PCIARB_PACR
	// GNT and REQ
	move.w #0x3FF,D0
	move.w D0,MCF_GPIO_PAR_PCIBG
	move.w D0,MCF_GPIO_PAR_PCIBR
	// Master Enable / Memory Space / MWI
	move.l #MCF_PCI_PCISCR_M + MCF_PCI_PCISCR_B + MCF_PCI_PCISCR_MW,D0
	move.l D0,MCF_PCI_PCISCR     // PCI Command Register
#ifdef DEBUG
	lea debug28(PC),A0
	bsr debug_display_string	
#endif
	// Setup burst parameters
	move.l #MCF_PCI_PCICR1_CACHELINESIZE(PCI_CACHE_LINE) + MCF_PCI_PCICR1_LATTIMER(32),D0
	move.l D0,MCF_PCI_PCICR1
	move.l #MCF_PCI_PCICR2_MINGNT(PCI_MINGNT) + MCF_PCI_PCICR2_MAXLAT(PCI_MAXLAT),D0
	move.l D0,MCF_PCI_PCICR2
	// Turn on error signaling
	move.l #MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE /* + MCF_PCI_PCIICR_REE*/ + PCI_RETRIES,D0
	move.l D0,MCF_PCI_PCIICR
	move.l #MCF_PCI_PCIGSCR_SEE,D0
	or.l D0,MCF_PCI_PCIGSCR
#ifdef DEBUG
	lea debug29(PC),A0
	bsr debug_display_string	
#endif
	// Configure Initiator Windows
	move.l #PCI_MEMORY_OFFSET + ((PCI_MEMORY_SIZE - 1) >> 8),D0
	clr.w D0
	move.l D0,MCF_PCI_PCIIW0BTAR // Initiator Window 0 Base / Translation Address Register
#if 0 // #ifdef DEBUG
	lea debug37(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char		
#endif
	move.l #PCI_IO_OFFSET + ((PCI_IO_SIZE - 1) >> 8),D0
	clr.w D0
	move.l D0,MCF_PCI_PCIIW1BTAR // Initiator Window 1 Base / Translation Address Register
	clr.l MCF_PCI_PCIIW2BTAR     // not used
#if 0 // #ifdef DEBUG
	lea debug37(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
#endif
	move.l #MCF_PCI_PCIIWCR_WINCTRL0_MEMRDLINE + MCF_PCI_PCIIWCR_WINCTRL1_IO,D0
	move.l D0,MCF_PCI_PCIIWCR	   // Initiator Window Configuration Register
#if 0 // one target zone 	
	clr.l MCF_PCI_PCIBAR0 
	clr.l MCF_PCI_PCITBATR0      // Target Base Address Translation Register 0
//	move.l #PCI_MEMORY_SIZE,D0   // STRAM/SDRAM mapped on PCI after the zones for devices
	move.l #0x40000000,D0
	move.l D0,MCF_PCI_PCIBAR1    // 1 GB window ! 
	move.l #MCF_PCI_PCITBATR1_EN,D0 
	move.l D0,MCF_PCI_PCITBATR1  // Target Base Address Translation Register 1
#else // two target zones
	moveq #0,D2
	move.l ramvalid,D0
	cmp.l #0x1357BD13,D0
	bne.s .no_sdram
	move.l ramtop,D2             // SDRAM top
	beq.s .no_sdram
//	move.l #PCI_MEMORY_SIZE,D0   // SDRAM mapped on PCI after the zones for devices
//	add.l 0x01000000,D0
	move.l #0x80000000,D0
	move.l D0,MCF_PCI_PCIBAR0 
	move.l #0x01000000 + MCF_PCI_PCITBATR0_EN,D2
.no_sdram:
	move.l D2,MCF_PCI_PCITBATR0  // Target Base Address Translation Register 0
//	move.l #PCI_MEMORY_SIZE,D0   // STRAM mapped on PCI after the zones for devices
	move.l #0x40000000,D0
	move.l D0,MCF_PCI_PCIBAR1    // 1 GB window ! 
	move.l #MCF_PCI_PCITBATR1_EN,D0 
	move.l D0,MCF_PCI_PCITBATR1  // Target Base Address Translation Register 1
#endif
#ifdef DEBUG
	lea debug30(PC),A0
	bsr debug_display_string	
#endif
	// Internal PCI controller interrupts
#ifdef MCF5445X
	pea int_pciarb(PC)
	move.w #64+INT1_HI_PCI_ASR+64+OFFSET_INT_CF68KLIB,-(SP)
	move.w #5,-(SP)              // Setexec
	trap #13
	addq.l #8,SP
	moveq #5,D0                  // level 5
	move.b D0,MCF_INTC_ICR1+INT1_HI_PCI_ASR
	move.l #~INTC_IMRH_INT_MASK56,D0
	and.l D0,MCF_INTC_IMRH1
	/* Falling edge on IRQ1-7 EPORT */
	move.w MCF_EPORT_EPPAR_EPPA7(EPORT_EPPAR_EPPAx_FALLING) \
	 + EPORT_EPPAR_EPPA6(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + EPORT_EPPAR_EPPA5(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + EPORT_EPPAR_EPPA4(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + EPORT_EPPAR_EPPA3(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + EPORT_EPPAR_EPPA2(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + EPORT_EPPAR_EPPA1(MCF_EPORT_EPPAR_EPPAx_FALLING),D0
	move.w D0,MCF_EPORT_EPPAR
	clr.b MCF_EPORT_EPDDR
	clr.b MCF_EPORT_EPIER
#else /* MCF548X */
	pea int_pciarb(PC)
	move.w #64+41+OFFSET_INT_CF68KLIB,-(SP)
	move.w #5,-(SP)              // Setexec
	trap #13
	addq.l #8,SP
	moveq #0x34,D0               // level 5, priority 4
	move.b D0,MCF_INTC_ICR41     // PCIARB
	move.l #~MCF_INTC_IMRH_INT_MASK41,D0
	and.l D0,MCF_INTC_IMRH
	pea int_xlbpci(PC)
	move.w #64+43+OFFSET_INT_CF68KLIB,-(SP)
	move.w #5,-(SP)              // Setexec
	trap #13
	addq.l #8,SP
	moveq #0x34,D0               // level 5, priority 4
	move.b D0,MCF_INTC_ICR43     // XLBPCI
	move.l #~MCF_INTC_IMRH_INT_MASK43,D0
	and.l D0,MCF_INTC_IMRH
	/* Falling edge on IRQ1-7 EPORT */
	move.w MCF_EPORT_EPPAR_EPPA7(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA6(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA5(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA4(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA3(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA2(MCF_EPORT_EPPAR_EPPAx_FALLING) \
	 + MCF_EPORT_EPPAR_EPPA1(MCF_EPORT_EPPAR_EPPAx_FALLING),D0
	move.w D0,MCF_EPORT_EPPAR
	clr.b MCF_EPORT_EPDDR
	clr.b MCF_EPORT_EPIER
#endif /* MCF5445X */
#ifdef DEBUG
	lea debug31(PC),A0
	bsr debug_display_string	
#endif
	/* Clear PCI Reset and wait for devices to reset */
	move.l #~MCF_PCI_PCIGSCR_PR,D0
	and.l D0,MCF_PCI_PCIGSCR
#if 1
	move.l MCF_SLT_SCNT1,D2
.delay_reset:
		move.l D2,D1
		sub.l MCF_SLT_SCNT1,D1
	cmp.l #200000000,D1
	bcs.s .delay_reset
#else
	move.l _hz_200,D2
	add.l #400,D2                // tempo 2 S
.delay_reset:
		move.l _hz_200,D1
	cmp.l D2,D1
	blt.s .delay_reset
#endif
#endif /* end #if 0 -- moved inside sdram.S before the CF68KLIB is called (init_cf) */

#else /* ATARI - CTCPI/PLX9054 */
.no_hardware:
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	moveq #-1,D0                 // error
	bra .end_install	
.pci_cookie_not_found:
             // test and init CTPCI configuration registers
	move.w SR,-(SP)
	or.w #0x700,SR               // no interrupts
	lea .no_hardware(PC),A0
	move.l 8,A5                  // bus error
	move.l A0,8
	move.l SP,A4                 // save ssp
	move.l memvalid,D0
	cmp.l #0x752019F3,D0
	bne.s .cold_reset
	move.l memval2,D0
	cmp.l #0x237698AA,D0
	bne.s .cold_reset
	move.l memval3,D0
	cmp.l #0x5555AAAA,D0
	bne.s .cold_reset
	move.l #PCI_IRQ_BASE_VECTOR,D0
	and.l #0xF0,D0
	move.l D0,PCI_CTPCI_CONFIG
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	bra.s .bypass_reset
.cold_reset:
	moveq #1,D0
	move.l D0,PCI_CTPCI_CONFIG+0x20 // Reset PLX, PCI slots and PCI arbiter
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
#ifdef DEBUG
	lea debug29(PC),A0
	bsr debug_display_string	
#endif
	move.l _hz_200,D2
	add.l #200,D2                // tempo 1 S
.tempo_reset:
	move.l _hz_200,D1
	cmp.l D2,D1
	blt.s .tempo_reset
	move.l #PCI_IRQ_BASE_VECTOR,D0
	and.l #0xF0,D0
	move.l D0,PCI_CTPCI_CONFIG
	moveq #0,D0
	move.l D0,PCI_CTPCI_CONFIG+0x20 // Reset/
	move.l _hz_200,D2
	add.l #400,D2                // tempo 2 S
.delay_reset:
		move.l _hz_200,D1
	cmp.l D2,D1
	blt.s .delay_reset
.bypass_reset:
	// test and init PLX9054
	move.w SR,-(SP)
	or.w #0x700,SR               // no interrupts
	lea .no_hardware(PC),A0
	move.l 8,A5                  // bus error
	move.l A0,8
	move.l SP,A4                 // save ssp
	moveq #PCIIDR,D1
	bsr read_local_config_longword // 1st acces returns bad value ???
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	moveq #PCIIDR,D1
	bsr read_local_config_longword
	cmp.l #PLX9054,D0            // Device ID & Vendor ID
	bne .abort_install2
#ifdef DEBUG
	bsr test_endian_local_config
	bne.s .plx_in_little
	lea debug30(PC),A0
	bsr debug_display_string
.plx_in_little:
#endif
#if 0
	move.l #0x00300100,D2        // Little Endian
	move.l #BIGEND,D1            // Big/Little Endian Descriptor /  Local Miscellaneous Control 
	bsr write_local_config_longword
#endif
	// pin BIGEND is active => try to use little endian
	move.l #0x80200000,D2        // for BIGEND input to WAIT output
	move.l #MARBR,D1             // Mode/DMA Arbitration
	bsr write_local_config_longword
#if 0
#if 1 // one target zone 
	move.l phystop,D2            // end STRAM
	cmp.l #0x1357BD13,ramvalid
	bne.s .no_sdram
	move.l ramtop,D2             // end SDRAM
.no_sdram:
	moveq #24,D0
	lsr.l D0,D2
	addq.l #1,D2
	lsl.l D0,D2                  // size
	subq.l #1,D2
	not.l D2
	move.l #LAS0RR,D1            // Local Address Space 0 Range Register for PCI-to-Local Bus
	bsr write_verify_local_config_longword
	moveq #1,D2                  // enable PCI target window at 0
	move.l #LAS0BA,D1            // Local Address Space 0 Local Base Address (Remap)
	bsr write_verify_local_config_longword
#else // two target zones
	cmp.l #0x1357BD13,ramvalid
	bne .no_sdram_2
	move.l ramtop,D2
	sub.l #0x01000000,D2
	bpl.s .sdram_ok
.no_sdram_2:
	moveq #0,D2
.sdram_ok:
	moveq #24,D0
	lsr.l D0,D2
	addq.l #1,D2
	lsl.l D0,D2                  // size
	subq.l #1,D2
	not.l D2
	move.l #LAS0RR,D1            // Local Address Space 0 Range Register for PCI-to-Local Bus
	bsr write_verify_local_config_longword
	moveq #0,D2
	cmp.l #0x1357BD13,ramvalid
	bne.s .no_sdram
	move.l ramtop,D2             // end SDRAM
	beq.s .no_sdram
	move.l #0x01000001,D2        // enable PCI target window at 0x1000000
.no_sdram:
	move.l #LAS0BA,D1            // Local Address Space 0 Local Base Address (Remap)
	bsr write_verify_local_config_longword
#endif
#endif
	move.l #~(PCI_IO_SIZE-1),D2
	move.l #DMRR,D1              // Local Range Register for PCI Initiator-to-PCI
	bsr write_verify_local_config_longword
	move.l #PCI_MEMORY_OFFSET,D2
	move.l #DMLBAM,D1            // Local Bus Base Address Register for PCI Initiator-to-PCI Memory
	bsr write_verify_local_config_longword
	move.l #PCI_IO_OFFSET,D2
	move.l #DMLBAI,D1            // Local Bus Base Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_verify_local_config_longword
	moveq #0,D2
	move.l #DMPBAM,D1            // PCI Base Address (Remap) Register for PCI Initiator-to-PCI Memory
	bsr write_verify_local_config_longword
	moveq #0,D2
	move.l #DMCFGA,D1
	bsr write_local_config_longword

#if 1
	move.l #0x40C300C3,D2
	move.l #LBRD0,D1
	bsr write_local_config_longword
	move.l #0x000000C3,D2
	move.l #LBRD1,D1
	bsr write_local_config_longword
	move.l #0x000001C3,D2
	move.l #DMAMODE0,D1
	bsr write_local_config_longword
	move.l #0x000001C3,D2
	move.l #DMAMODE1,D1
	bsr write_local_config_longword
#endif

#if 0
#if 1 // one target zone 	
	moveq #0,D2
	move.l #LAS1RR,D1            // Local Address Space 1 Range Register for PCI-to-Local Bus
	bsr write_verify_local_config_longword
	moveq #0,D2                  // disable PCI target window
	move.l #LAS1BA,D1            // Local Address Space 1 Local Base Address (Remap)
	bsr write_verify_local_config_longword
#else // two target zones
	move.l phystop,D2            // end STRAM
	moveq #24,D0
	lsr.l D0,D2
	addq.l #1,D2
	lsl.l D0,D2                  // size
	subq.l #1,D2
	not.l D2
	move.l #LAS1RR,D1            // Local Address Space 1 Range Register for PCI-to-Local Bus
	bsr write_verify_local_config_longword
	moveq #1,D2                  // enable PCI target window at 0 (STRAM)
	move.l #LAS1BA,D1            // Local Address Space 1 Local Base Address (Remap)
	bsr write_verify_local_config_longword
#endif
#endif
#ifndef LITTLE_ENDIAN_LANE_SWAPPED        // bits inverses sur le PLX ???
	move.l #0x00300500,D2        // Little Endian + Local Init Status => PLX done
#else	                             // lines are swapped by the bridge
	move.l #0x003005FE,D2        // Big Endian excepted Configuration Registers
#endif                                    // + Local Init Status => PLX done
	move.l #BIGEND,D1            // Big/Little Endian Descriptor /  Local Miscellaneous Control 
	bsr write_local_config_longword
#if 0
	// PCI target windows configuration
#if 1 // one target zone 
	move.l #PCI_MEMORY_SIZE,D2   // STRAM/SDRAM mapped on PCI after the zones for devices
	move.l #PCIBAR2,D1           // PCI Base Address Register for Memory Accesses to Local Address Space 0
	bsr write_local_config_longword
#else // two target zones
	move.l #PCI_MEMORY_SIZE,D2   // SDRAM mapped on PCI after the zones for devices
	add.l #0x01000000,D2
	move.l #PCIBAR2,D1           // PCI Base Address Register for Memory Accesses to Local Address Space 0
	bsr write_local_config_longword
	move.l #PCI_MEMORY_SIZE,D2   // STRAM mapped on PCI after the zones for devices
	move.l #PCIBAR3,D1           // PCI Base Address Register for Memory Accesses to Local Address Space 1
	bsr write_local_config_longword
#endif
#endif
	// Master Enable / Memory Space / I/O Space
	move.l #PCI_CMDREG_MASTR + PCI_CMDREG_MEMSP + PCI_CMDREG_IOSP + 0x02900000,D2
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr write_local_config_longword
	// end of PCI target windows configuration
	moveq #3,D2                  // enable PCI base for local bus map-to-PCI
	move.l #DMPBAM,D1            // PCI Base Address (Remap) Register for PCI Initiator-to-PCI Memory
	bsr write_local_config_longword
#ifdef DEBUG
	lea debug1(PC),A0
	bsr debug_display_string
	moveq #PCICSR,D1
	bsr read_local_config_longword
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug2(PC),A0
	bsr debug_display_string
	move.l #LAS0BA,D1
	bsr read_local_config_longword	
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug3(PC),A0
	bsr debug_display_string
	move.l #LAS0RR,D1
	bsr read_local_config_longword	
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug4(PC),A0
	bsr debug_display_string
	move.l #PCIBAR2,D1
	bsr read_local_config_longword	
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug5(PC),A0
	bsr debug_display_string
	move.l #LAS1BA,D1
	bsr read_local_config_longword	
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug10(PC),A0
	bsr debug_display_string
	move.l #DMLBAM,D1
	bsr read_local_config_longword	
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug11(PC),A0
	bsr debug_display_string
	move.l #DMRR,D1
	bsr read_local_config_longword	
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug12(PC),A0
	bsr debug_display_string
	move.l #DMLBAI,D1
	bsr read_local_config_longword	
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug13(PC),A0
	bsr debug_display_string
	move.l #DMPBAM,D1
	bsr read_local_config_longword	
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug20(PC),A0
	bsr debug_display_string
	move.l #BIGEND,D1
	bsr read_local_config_byte	
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	lea debug21(PC),A0
	bsr debug_display_string
	move.l #LMISC,D1
	bsr read_local_config_byte	
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	bsr test_endian_local_config
	lea debug31l(PC),A0	
	tst.l D0
	bne.s .plx_in_little2
	lea debug31b(PC),A0
.plx_in_little2:
	bsr debug_display_string
	move.l #PCIIDR,D1
	bsr read_local_config_word
	move.l #PLX9054,D1
	cmp.w D1,D0
	beq.s .plx_word_ok
	move.l D0,-(SP)
	lea debug28(PC),A0
	bsr debug_display_string
	move.l (SP)+,D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
.plx_word_ok:
	move.l #PCIIDR,D1
	bsr read_local_config_byte
	move.l #PLX9054,D1
	cmp.b D1,D0
	beq.s .plx_byte_ok
	move.l D0,-(SP)
	lea debug27(PC),A0
	bsr debug_display_string
	move.l (SP)+,D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
.plx_byte_ok:
	move.l _hz_200,D2
	add.l #200,D2                // tempo 1 S
.tempo2:
	move.l _hz_200,D1
	cmp.l D2,D1
	blt.s .tempo2
#endif /* DEBUG */
#endif /* COLDFIRE */
#ifdef DEBUG
	lea debug32(PC),A0
	bsr debug_display_string	
#endif
	// init driver
	move.w #3,-(SP)              // TT ram if possible
	move.l #PCI_COOKIE_TOTALSIZE,-(SP)
	move.w #0x44,-(SP)           // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	ble .abort_install
	move.l D0,A6                 // _PCI cookie
	add.l #PCI_COOKIE_SIZE,D0
	move.l D0,A5                 // Ressource-Descriptors
	add.l #PCI_RSC_HANDLESTOTALSIZE,D0 // PCI_RSC_DESC_TOTALSIZE*PCI_MAX_HANDLE*PCI_MAX_FUNCTION
	move.l D0,A4                 // Status-Descriptors, size PCI_DEV_DES_SIZE*PCI_MAX_HANDLE*PCI_MAX_FUNCTION
	move.l A6,A0                 // _PCI cookie
	clr.l PCI_COOKIE_SUBCOOKIE(A0) // Sub-Cookie for PCI_CONF, not used obsolete
	move.l #PCI_BIOS_REV,D0
	move.l D0,PCI_COOKIE_VERSION(A0) // version PCI BIOS
	lea find_pci_device(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE(A0)
	lea find_pci_classcode(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+4(A0)
	lea read_config_byte(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+8(A0)
	lea read_config_word(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+12(A0)
	lea read_config_longword(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+16(A0)
	lea fast_read_config_byte(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+20(A0)
	lea fast_read_config_word(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+24(A0)
	lea fast_read_config_longword(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+28(A0)
	lea write_config_byte(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+32(A0)
	lea write_config_word(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+36(A0)
	lea write_config_longword(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+40(A0)
	lea hook_interrupt(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+44(A0)
	lea unhook_interrupt(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+48(A0)
	lea special_cycle(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+52(A0)
	lea get_routing(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+56(A0)
	lea set_interrupt(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+60(A0)
	lea get_resource(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+64(A0)
	lea get_card_used(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+68(A0)
	lea set_card_used(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+72(A0)
	lea read_mem_byte(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+76(A0)
	lea read_mem_word(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+80(A0)
	lea read_mem_longword(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+84(A0)
	lea fast_read_mem_byte(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+88(A0)
	lea fast_read_mem_word(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+92(A0)
	lea fast_read_mem_longword(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+96(A0)
	lea write_mem_byte(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+100(A0)
	lea write_mem_word(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+104(A0)
	lea write_mem_longword(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+108(A0)
	lea read_io_byte(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+112(A0)
	lea read_io_word(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+116(A0)
	lea read_io_longword(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+120(A0)
	lea fast_read_io_byte(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+124(A0)
	lea fast_read_io_word(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+128(A0)
	lea fast_read_io_longword(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+132(A0)
	lea write_io_byte(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+136(A0)
	lea write_io_word(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+140(A0)
	lea write_io_longword(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+144(A0)
	lea get_machine_id(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+148(A0)
	lea get_pagesize(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+152(A0)
	lea virt_to_bus(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+156(A0)
	lea bus_to_virt(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+160(A0)
	lea virt_to_phys(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+164(A0)
	lea phys_to_virt(PC),A1
	move.l A1,PCI_COOKIE_ROUTINE+168(A0)
#ifdef DEBUG
	lea debug33(PC),A0
	bsr debug_display_string	
#endif
	bsr init_devices
.end_install:
#ifdef COLDFIRE
	movem.l (SP),D1-A6
	lea 56(SP),SP
#else
	movem.l (SP)+,D1-A6
#endif
	rts
	
// variables on stack used by init_devices:
#define RESERVE_STACK                     28 
#define GRAPHICS_CARD_FLAG  -2+RESERVE_STACK // .w flag graphics card
#define SAVE_BITS           -6+RESERVE_STACK // .l save value for usage bits in PCI ressources
#define DEVICE_VENDOR_ID   -10+RESERVE_STACK // .l device/vendor id
#define OFFSET_IO          -14+RESERVE_STACK // .l offset i/o resource 
#define OFFSET_MEMORY      -18+RESERVE_STACK // .l offset memory resource 
#define OFFSET_MEMORY_PREF -22+RESERVE_STACK // .l offset memory ressource with prefetch
#define RESOURCE_INDEX     -24+RESERVE_STACK // .w offset or index resource by handle   
#define ERROR_CODE         -28+RESERVE_STACK // .l error code

init_devices:

	lea -RESERVE_STACK(SP),SP
	clr.w RESOURCE_INDEX(SP)
	clr.l OFFSET_MEMORY_PREF(SP)
	move.l #PCI_MEMORY_SIZE/2,D0
	move.l D0,OFFSET_MEMORY(SP)
	clr.l OFFSET_IO(SP)
	clr.l SAVE_BITS(SP)
	clr.w GRAPHICS_CARD_FLAG(SP)
	// init devices, handle 0 is for local bridge PLX9054
	moveq #0,D4              	            // slot
	moveq #0,D6                           // function number
.loop_handle:
		clr.l ERROR_CODE(SP)     // error code
		moveq #PCIIDR,D1
		move.l D6,D0             // current function number
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_longword // Device ID & Vendor ID
		move.l D0,DEVICE_VENDOR_ID(SP)
#ifdef COLDFIRE
#if 0 // #ifdef DEBUG
		move.l D0,-(SP)
		move.l A0,-(SP)
		lea debug39(PC),A0
		bsr debug_display_string
		bsr debug_hex_long
		moveq #13,D0
		bsr debug_display_char
		moveq #10,D0
		bsr debug_display_char
		move.l (SP)+,A0
		move.l (SP)+,D0
#endif
#endif
#ifdef COLDFIRE
		moveq #0,D1
		move.w D0,D1
		cmp.l #PCI_NOBODYHOME,D1 // Vendor ID
#else
		cmp.w #PCI_NOBODYHOME,D0 // Vendor ID
#endif
		beq .no_device_found_here
		moveq #PCIREV,D1
		move.l D6,D0             // current function number
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_longword // & class code
#ifdef COLDFIRE
#if 0 // #ifdef DEBUG
		move.l D0,-(SP)
		move.l A0,-(SP)
		lea debug40(PC),A0
		bsr debug_display_string
		bsr debug_hex_long
		moveq #13,D0
		bsr debug_display_char
		moveq #10,D0
		bsr debug_display_char
		move.l (SP)+,A0
		move.l (SP)+,D0
#endif
#endif
		swap D0
		lsr.l #8,D0              // base class code
		and.l #0xFF,D0
		cmp.l #PCI_CLASS_DISPLAY,D0
		seq.b D0
		ext.w D0
		move.w D0,GRAPHICS_CARD_FLAG(SP) // flag graphic card
		beq.s .card_is_free
		moveq #3,D0              // card in use
.card_is_free:
		move.l D4,D1             // slot
		mulu #PCI_MAX_FUNCTION,D1
		add.l D6,D1              // function
		mulu #PCI_DEV_DES_SIZE,D1
		move.l D0,PCI_DEV_DES_STATUS(A4,D1.l)
		clr.l PCI_DEV_DES_CALLBACK(A4,D1.l)
		clr.l PCI_DEV_DES_HANDLER(A4,D1.l)
		clr.l PCI_DEV_DES_PARAMETER(A4,D1.l)
		clr.l PCI_DEV_DES_START_IRQ(A4,D1.l)
		tst.l D4                 // slot
		bne.s .devices           // <> local bridge PLX9054
		tst.l D6                 // do not check for multi-function on bridge
		bne .next_slot
		move.l D4,D0             // slot
		mulu #PCI_MAX_FUNCTION,D0
		add.l D6,D0              // function
		mulu #PCI_RSC_DESC_TOTALSIZE,D0
		move.w #PCI_RSC_DESC_SIZE,D1
		move.w D1,PCI_RSC_DESC_NEXT(A5,D0.l)
#if 1		// information for bus mastering
#ifdef BIG_ENDIAN
		move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_MOTOROLA,D1
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
		move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_AS,D1
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
		move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_LS,D1
#else
		move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_UNKNOWN,D1
#endif /* LITTLE_ENDIAN_LANE_SWAPPED */
#endif /* LITTLE_ENDIAN_ADDRESSES_SWAPPED */
#endif /* BIG_ENDIAN */
		move.w D1,PCI_RSC_DESC_FLAGS(A5,D0.l)
#ifdef COLDFIRE
		move.l #0x40000000,D1
		move.l D1,PCI_RSC_DESC_START(A5,D0.l) // offset memory resource
		move.l #-0x40000000,D1
		move.l D1,PCI_RSC_DESC_OFFSET(A5,D0.l)
		move.l D1,PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
#else /* ATARI - CTPCI/PLX9054 */
		// STRAM/SDRAM mapped on PCI after the zones for devices
		move.l #PCI_MEMORY_SIZE,PCI_RSC_DESC_START(A5,D0.l) // offset memory resource
		move.l #-PCI_MEMORY_SIZE,D1
		move.l D1,PCI_RSC_DESC_OFFSET(A5,D0.l)
		move.l D1,PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
#endif /* COLDFIRE */
		clr.l PCI_RSC_DESC_LENGTH(A5,D0.l)
#else		// information for bridge I/O
#ifdef BIG_ENDIAN
		move.w #FLG_IO+FLG_LAST+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_MOTOROLA,D1
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
		move.w #FLG_IO+FLG_LAST+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_AS,D1
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
		move.w #FLG_IO+FLG_LAST+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_LS,D1
#else
		move.w #FLG_IO+FLG_LAST+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_UNKNOWN,D1
#endif /* LITTLE_ENDIAN_LANE_SWAPPED */
#endif /* LITTLE_ENDIAN_ADDRESSES_SWAPPED */
#endif /* BIG_ENDIAN */
		move.w D1,PCI_RSC_DESC_FLAGS(A5,D0.l)
		move.l OFFSET_IO(SP),D1
		move.l D1,PCI_RSC_DESC_START(A5,D0.l) // offset I/O resource
		move.l #256,D1
		move.l D1,PCI_RSC_DESC_LENGTH(A5,D0.l)
#ifdef COLDFIRE
		move.l #PCI_LOCAL_CONFIG,D1
		move.l D1,PCI_RSC_DESC_OFFSET(A5,D0.l)
#else
		add.l #256,OFFSET_IO(SP) // offset I/O resource
		move.l #PCI_IO_OFFSET,PCI_RSC_DESC_OFFSET(A5,D0.l)
#endif /* COLDFIRE */
		move.l #PCI_MEMORY_OFFSET,D1
		move.l D1,PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
		clr.l PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
#ifndef COLDFIRE
		move.l PCI_RSC_DESC_START(A5,D0.l),D2 // offset I/O resource now for I/O PLX9054
		moveq #PCIBAR1,D1        // PCI Base Address Register for I/O Accesses to Local, Runtime, and DMA
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr write_config_longword
#endif /* COLDFIRE */
#endif
		moveq #1,D0
		move.w D0,RESOURCE_INDEX(SP) // offset resource by handle
		bra .end_area
.devices:
#ifdef COLDFIRE
#if 0 // #ifdef DEBUG
		lea debug41(PC),A0
		bsr debug_display_string
#endif
#endif
		moveq #PCIBAR0,D5        // reg
		clr.w RESOURCE_INDEX(SP) // index resource by handle
.loop_area:
			move.l D5,D1         // reg
			move.l D6,D0         // current function number
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_longword
			move.l D0,D3         // save value and read type bits
			moveq #-1,D2
			move.l D5,D1         // reg
			move.l D6,D0         // current function number
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
			move.l D5,D1         // reg
			move.l D6,D0         // function number
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_longword
			move.l D0,SAVE_BITS(SP) // save value for try to find used bits (resolution)
			lea OFFSET_MEMORY_PREF(SP),A3
			and.l #PCI_BASE_PREF_M,D0
			bne.s .memory_with_cache
			lea OFFSET_MEMORY(SP),A3
.memory_with_cache:
			move.l D3,D2         // saved value
			move.l D5,D1         // reg
			move.l D6,D0         // function number
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword // restore value
			move.l SAVE_BITS(SP),D0 // value used bits PCIBARx register
			beq .next_area       // register not used
			cmp.l #PCIERBAR,D5   // PCI Expansion ROM Base Register 
			beq .expansion_rom
			moveq #PCI_BASE_SPACE_IO,D0
			and.l D3,D0
			beq .not_space_io    // <> IO
.space_io:
			moveq #PCI_BASE_IO_ADDR_M,D7
			and.l SAVE_BITS(SP),D7 // value PCIBARx register
			move.l D7,D0
			moveq #-1,D1
.loop_find_first_lsb_io:
				addq.l #1,D1
				lsr.l #1,D0 // search the first LSB to 1
				bcs.s .found_first_lsb_io
			bne.s .loop_find_first_lsb_io
			moveq #31,D1         // not found ?
.found_first_lsb_io:
			moveq #0,D2
			bset D1,D2           // minimum step of the PCI base address
			move.l OFFSET_IO(SP),D0 // current offset I/O resource
			and.l D7,D0          // alignment with the resolution of PCIBARx
			cmp.l OFFSET_IO(SP),D0 // current offset I/O resource
			bcc.s .ok_with_current_offset_io
			add.l D2,D0          // add the minimum step of the PCI base address
			move.l D0,D7
			bra.s .check_size_io
.ok_with_current_offset_io:
			move.l OFFSET_IO(SP),D7 // current offset I/O resource
.check_size_io:
			move.l D7,D0
			add.l D2,D0          // minimum step of the PCI base address is the size 
			cmp.l #PCI_IO_SIZE,D0
			bcc .io_space_full   // area overflow
			move.l D7,OFFSET_IO(SP) // new offset I/O resource
			move.w D4,D0         // slot
			mulu #PCI_MAX_FUNCTION,D0
			add.l D6,D0          // function
			mulu #PCI_RSC_DESC_TOTALSIZE,D0
			move.w RESOURCE_INDEX(SP),D1 // index resource by handle
			mulu #PCI_RSC_DESC_SIZE,D1
			add.l D1,D0
			move.w #PCI_RSC_DESC_SIZE,D1
			move.w D1,PCI_RSC_DESC_NEXT(A5,D0.l)
#ifdef BIG_ENDIAN
			move.w #FLG_IO+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_MOTOROLA,D1
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
			move.w #FLG_IO+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_AS,D1
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
			move.w #FLG_IO+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_LS,D1
#else
			move.w #FLG_IO+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_UNKNOWN,D1
#endif /* LITTLE_ENDIAN_LANE_SWAPPED */
#endif /* LITTLE_ENDIAN_ADDRESSES_SWAPPED */
#endif /* BIG_ENDIAN */
			move.w D1,PCI_RSC_DESC_FLAGS(A5,D0.l)
			move.l OFFSET_IO(SP),D1
			move.l D1,PCI_RSC_DESC_START(A5,D0.l) // offset I/O resource
			add.l D2,OFFSET_IO(SP)  // offset I/O resource
			move.l D2,PCI_RSC_DESC_LENGTH(A5,D0.l)
			move.l #PCI_IO_OFFSET,D1
			move.l D1,PCI_RSC_DESC_OFFSET(A5,D0.l)
			move.l #PCI_MEMORY_OFFSET,D1
			move.l D1,PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
			clr.l PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
			move.l PCI_RSC_DESC_START(A5,D0.l),D2      // offset I/O resource
			move.l D5,D1         // reg
			move.l D6,D0         // function number
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
#ifdef COLDFIRE
#if 0 // #ifdef DEBUG
			move.l D0,-(SP)
			moveq #0x30,D0
			bsr debug_display_char	
			moveq #0x78,D0
			bsr debug_display_char
			move.l D5,D1         // reg
			move.l D6,D0         // function
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_longword
			bsr debug_hex_long
			moveq #0x20,D0
			bsr debug_display_char
			move.l (SP)+,D0
#endif
#endif
#ifdef COLDFIRE
			move.w RESOURCE_INDEX(SP),D0
			addq.l #1,D0
			move.w D0,RESOURCE_INDEX(SP) // index resource by handle
#else
			addq.w #1,RESOURCE_INDEX(SP) // index resource by handle
#endif
			bra .next_area
.expansion_rom:
			move.l #PCI_BASE_ROM_ADDR_M,D7
			bra.s .not_space_io2
.not_space_io:
			moveq #PCI_BASE_M_ADDR_M,D7
.not_space_io2:
			and.l SAVE_BITS(SP),D7 // value PCIBARx register
			move.l D7,D0
			moveq #-1,D1
.loop_find_first_lsb_memory:
				addq.l #1,D1
				lsr.l #1,D0 // search the first LSB to 1
				bcs.s .found_first_lsb_memory
			bne.s .loop_find_first_lsb_memory
			moveq #31,D1         // not found ?
.found_first_lsb_memory:
			moveq #0,D2
			bset D1,D2           // minimum step of the PCI base address
			move.l (A3),D0       // current offset memory resource
			and.l D7,D0          // alignment with the resolution of PCIBARx
			cmp.l (A3),D0        // current offset memory resource
			bcc.s .ok_with_current_offset_memory
			add.l D2,D0          // add the minimum step of the PCI base address
			move.l D0,D7
			bra.s .check_memory_type
.ok_with_current_offset_memory:
			move.l (A3),D7       // current offset memory resource
.check_memory_type:
#ifdef CHECK_PARITY
			bsr check_parity
			bmi.s .parity_error_detected
#endif
			cmp.l #PCIERBAR,D5   // PCI Expansion ROM Base Register 
			beq .memory_32bit
			move.w D3,D0
			and.l #PCI_BASE_TYPE_M,D0
			cmp.l #PCI_BASE_TYPE_MEM,D0 // 32-bit memory address
			beq .memory_32bit
			cmp.l #PCI_BASE_TYPE_LOW,D0 // less than 1Mb address
			beq.s .less_1mb             // error
			cmp.l #PCI_BASE_TYPE_ALL,D0 // 64-bit memory address
			beq .memory_64bit
			bra .memory_type_unknow
.io_space_full:
			moveq #PCI_NO_MORE_IO_SPACE,D0
			bra.s .shutdown_device
.mem_space_full:
			moveq #PCI_NO_MORE_MEM_SPACE,D0
			bra.s .shutdown_device
.less_1mb:
			moveq #PCI_NO_MORE_MEM_BELOW_1MB,D0
			bra.s .shutdown_device	
.need_more_4gb:
			moveq #PCI_NEED_MORE_THAN_4GB,D0
			bra.s .shutdown_device
.memory_type_unknow:
			moveq #PCI_UNKNOW_MEMORY_TYPE,D0
#ifdef CHECK_PARITY
			bra.s .shutdown_device
.parity_error_detected:
			moveq #PCI_PARITY_ERROR,D0
#endif
.shutdown_device:
			move.l D0,ERROR_CODE(SP) // error code
			// device will be shut down now
			moveq #PCICR,D1      // PCI Command Register
			move.l D6,D0         // function
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_word
			// remove Special Cycle / Master Enable / Memory Space / I/O Space
			and.l #~(PCI_CMDREG_SPCYC + PCI_CMDREG_MASTR + PCI_CMDREG_MEMSP + PCI_CMDREG_IOSP),D0
			move.w D0,D2
			moveq #PCICR,D1      // PCI Command Register
			move.l D6,D0         // function
			swap D0
			or.l D4,D0           // slot
			bsr write_config_word
			bra .end_area
.memory_32bit:
			cmp.l #PCIBAR0,D5    // reg
			bne.s .no_fix_graphic_card
			tst.w GRAPHICS_CARD_FLAG(SP)      // flag graphic card
			beq.s .no_fix_graphic_card
			cmp.l #GRAPHIC_CARD_SIZE/4,D2
			bcc.s .no_fix_graphic_card                                             
			move.l #GRAPHIC_CARD_SIZE,D2
.no_fix_graphic_card:
			move.l D7,D0
			add.l D2,D0          // minimum step of the PCI base address is the size 
			cmp.l #PCI_MEMORY_SIZE,D0
			bcc .mem_space_full  // area overflow
			move.l D7,(A3)       // new offset memory resource
			move.l D4,D0         // handle
			mulu #PCI_MAX_FUNCTION,D0
			add.l D6,D0
			mulu #PCI_RSC_DESC_TOTALSIZE,D0
			move.w RESOURCE_INDEX(SP),D1 // index resource by handle
			mulu #PCI_RSC_DESC_SIZE,D1
			add.l D1,D0
			move.w #PCI_RSC_DESC_SIZE,D1
			move.w D1,PCI_RSC_DESC_NEXT(A5,D0.l)
#ifdef BIG_ENDIAN
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_MOTOROLA,D1
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_AS,D1
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_LS,D1
#else
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_UNKNOWN,D1
#endif /* LITTLE_ENDIAN_LANE_SWAPPED */
#endif /* LITTLE_ENDIAN_ADDRESSES_SWAPPED */
#endif /* BIG_ENDIAN */
			move.w D1,PCI_RSC_DESC_FLAGS(A5,D0.l)
			move.l (A3),D1
			move.l D1,PCI_RSC_DESC_START(A5,D0.l) // offset memory resource
			add.l D2,(A3)        // offset memory resource
			move.l D2,PCI_RSC_DESC_LENGTH(A5,D0.l)
			move.l #PCI_MEMORY_OFFSET,D1
			move.l D1,PCI_RSC_DESC_OFFSET(A5,D0.l)
			move.l D1,PCI_RSC_DESC_DMAOFFSET(A5,D0.l)	
			clr.l PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
			move.l PCI_RSC_DESC_START(A5,D0.l),D2      // offset memory resource
			cmp.l #PCIERBAR,D5   // PCI Expansion ROM Base Register 
			bne.s .not_expansion_rom			
			or.l #PCI_BASE_ROM_ENABLE,D2		
.not_expansion_rom:	
			move.l D5,D1         // reg
			move.l D6,D0         // function
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
#ifdef COLDFIRE
#if 0 // #ifdef DEBUG
			move.l D0,-(SP)
			moveq #0x30,D0       // '0'
			bsr debug_display_char	
			moveq #0x78,D0       // 'x'
			bsr debug_display_char
			move.l D5,D1         // reg
			move.l D6,D0         // function
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_longword
			bsr debug_hex_long
			moveq #0x20,D0
			bsr debug_display_char
			move.l (SP)+,D0
#endif
#endif
#ifdef COLDFIRE
			move.w RESOURCE_INDEX(SP),D0
			addq.l #1,D0
			move.w D0,RESOURCE_INDEX(SP) // index resource by handle
#else
			addq.w #1,RESOURCE_INDEX(SP) // index resource by handle
#endif
			bra .next_area
.memory_64bit:
			move.l D2,-(SP)
			moveq #-1,D2
			moveq #4,D1
			add.l D5,D1          // reg + 4 (next PCIBARx)
			move.l D6,D0         // function
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
			moveq #4,D1
			add.l D5,D1          // reg + 4 (next PCIBARx)
			move.l D6,D0         // function
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_longword
			move.l (SP)+,D2
			moveq #-1,D1
			cmp.l D0,D1
			bne .need_more_4gb
			move.l D7,D0
			add.l D2,D0          // minimum step of the PCI base address is the size
			cmp.l #PCI_MEMORY_SIZE,D0
			bcc .mem_space_full  // area overflow
			move.l D7,(A3)       // new offset memory resource
			move.l D4,D0         // handle
			mulu #PCI_MAX_FUNCTION,D0
			add.l D6,D0
			mulu #PCI_RSC_DESC_TOTALSIZE,D0
			move.w RESOURCE_INDEX(SP),D1 // index resource by handle
			mulu #PCI_RSC_DESC_SIZE,D1
			add.l D1,D0
			move.w #PCI_RSC_DESC_SIZE,D1
			move.w D1,PCI_RSC_DESC_NEXT(A5,D0.l)
#ifdef BIG_ENDIAN
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_MOTOROLA,D1
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_AS,D1
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_LS,D1
#else
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_UNKNOWN,D1
#endif /* LITTLE_ENDIAN_LANE_SWAPPED */
#endif /* LITTLE_ENDIAN_ADDRESSES_SWAPPED */
#endif /* BIG_ENDIAN */
			move.w D1,PCI_RSC_DESC_FLAGS(A5,D0.l)
			move.l (A3),D1
			move.l D1,PCI_RSC_DESC_START(A5,D0.l) // offset memory resource
			add.l D2,(A3)          // offset memory resource
			move.l D2,PCI_RSC_DESC_LENGTH(A5,D0.l)
			move.l #PCI_MEMORY_OFFSET,D1
			move.l D1,PCI_RSC_DESC_OFFSET(A5,D0.l)
			move.l D1,PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
			clr.l PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
			move.l PCI_RSC_DESC_START(A5,D0.l),D2 // offset memory resource
			move.l D5,D1         // reg
			move.l D6,D0         // function
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
#ifdef COLDFIRE
#if 0 // #ifdef DEBUG
			move.l D0,-(SP)
			moveq #0x30,D0
			bsr debug_display_char	
			moveq #0x78,D0
			bsr debug_display_char
			move.l D5,D1         // reg
			move.l D6,D0	        // function
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_longword
			bsr debug_hex_long
			moveq #0x20,D0
			bsr debug_display_char
			move.l (SP)+,D0
#endif
#endif
#ifdef COLDFIRE
			move.w RESOURCE_INDEX(SP),D0
			addq.l #1,D0
			move.w D0,RESOURCE_INDEX(SP) // index resource by handle
#else
			addq.w #1,RESOURCE_INDEX(SP) // index resource by handle
#endif
			moveq #0,D2
			moveq #4,D1
			add.l D5,D1          // reg + 4
			move.l D6,D0         // function
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
.next_area:
			addq.l #4,D5
			cmp.l #PCIBAR5,D5
			bls .loop_area
			cmp.l #PCIERBAR,D5
			bhi.s .end_loop_area 
			moveq #PCIERBAR,D5   // PCI Expansion ROM Base Register 
		bra .loop_area
.end_loop_area:
#ifdef COLDFIRE
		moveq #PCI_CACHE_LINE,D2
		moveq #PCICLSR,D1
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr write_config_byte
#endif
		move.w #PCI_CMDREG_PERR + PCI_CMDREG_MASTR + PCI_CMDREG_MEMSP + PCI_CMDREG_IOSP,D2
		moveq #PCICR,D1          // PCI Command Register
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr write_config_word
.end_area:
#ifdef COLDFIRE
#if 0 // #ifdef DEBUG
		move.l D0,-(SP)
		move.l A0,-(SP)
		moveq #13,D0
		bsr debug_display_char
		moveq #10,D0
		bsr debug_display_char
		moveq #PCICR,D1
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_word
		lea debug45(PC),A0
		bsr debug_display_string
		bsr debug_hex_word
		moveq #13,D0
		bsr debug_display_char
		moveq #10,D0
		bsr debug_display_char
		move.l (SP)+,A0
		move.l (SP)+,D0
#endif
#endif
		move.l D4,D0             // handle
		mulu #PCI_MAX_FUNCTION,D0
		add.l D6,D0
		mulu #PCI_RSC_DESC_TOTALSIZE,D0
		move.w RESOURCE_INDEX(SP),D1 // index resource by handle
		mulu #PCI_RSC_DESC_SIZE,D1
		add.l D1,D0
		move.l ERROR_CODE(SP),D1     // internal error code
		bne.s .end_area_with_error
#ifdef COLDFIRE
		move.w (PCI_RSC_DESC_FLAGS-PCI_RSC_DESC_SIZE)(A5,D0.l),D1		
		or.l #FLG_LAST,D1
		move.w D1,(PCI_RSC_DESC_FLAGS-PCI_RSC_DESC_SIZE)(A5,D0.l)
#else
		or.w #FLG_LAST,(PCI_RSC_DESC_FLAGS-PCI_RSC_DESC_SIZE)(A5,D0.l)
#endif
		clr.w (PCI_RSC_DESC_NEXT-PCI_RSC_DESC_SIZE)(A5,D0.l)
		bra.s .end_area_set_int
.end_area_with_error:
		move.l D1,PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
#ifdef COLDFIRE
		move.w #FLG_LAST,D1
		move.w D1,PCI_RSC_DESC_FLAGS(A5,D0.l)
#else
		move.w #FLG_LAST,PCI_RSC_DESC_FLAGS(A5,D0.l)
#endif
		clr.w PCI_RSC_DESC_NEXT(A5,D0.l)
.end_area_set_int:
		// Some graphic adapters set the Interrupt Pin Register
		// in that way, that they will use an Interrupt, although
		// they don't. That's nonsens.
		// So the PCI-BIOS ignores the Interrupt Pin Register of
		// that graphic adapters and does NOT install an Interrupt
		// Handler for such an adapter.
		move.l D6,D0
		swap D0
		or.l D4,D0               // handle
		bsr disable_interrupt
		tst.w GRAPHICS_CARD_FLAG(SP) // flag graphic card
		bne.s .graphic_card
		moveq #PCIIPR,D1         // Interrupt Pin
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_byte
		tst.b D0
		beq.s .graphic_card
		move.l #PCI_IRQ_BASE_VECTOR,D0
#ifdef COLDFIRE
		lea int_cfpci(PC),A0
		tst.l D4                 // slot
		beq.s .set_vector        // bridge
#ifdef MCF5445X
		move.w #64+INT0_LO_EPORT3+OFFSET_INT_CF68KLIB,D0 // IRQ5 EPORT
		lea int3_pci(PC),A0
#else /* MCF548X */
		move.w #64+5+OFFSET_INT_CF68KLIB,D0 // IRQ5 EPORT
		lea int5_pci(PC),A0
		cmp.l #2,D4
		bls.s .graphic_card
		move.w #64+7+OFFSET_INT_CF68KLIB,D0 // IRQ7 EPORT
		lea int7_pci(PC),A0
#endif /* MCF5445X */
#else /* ATARI - CTPCI/PLX9054 */
		lea int_ctpci(PC),A0
		tst.l D4                 // slot
		beq.s .set_vector        // bridge
		addq.l #1,D0             // jump LSERR
		lea inta_ctpci(PC),A0
		cmp.l #1,D4
		beq.s .set_vector
		lea intb_ctpci(PC),A0
		cmp.l #2,D4
		beq.s .set_vector
		lea intc_ctpci(PC),A0
		cmp.l #3,D4
		beq.s .set_vector
		lea intd_ctpci(PC),A0
#endif /* COLDFIRE */
.set_vector:
		move.l A2,-(SP)
		pea (A0)
		add.l D4,D0
		move.w D0,-(SP)
		move.w #5,-(SP)          // Setexec
		trap #13
		addq.l #8,SP
		move.l (SP)+,A2
.graphic_card:
		// Interrupt Line Register will be initialised with 0xFF
		// because of different solutions regarding the Hardware
		// (Hades/Milan/...) This register is only for information
		// and won't be used by ATARI-compatibles. PCI adapters
		// don't care about the value set in this register.
		move.b #0xFF,D2
		moveq #PCIILR,D1         // Interrupt Line
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr write_config_byte
#ifdef COLDFIRE
		tst.l D4
		beq .next_handle         // host bridge
#endif
		// Latency Timer Register is initialised with a useable
		// value. The new revision also cares about the min and
		// max values offered by the adapter in the MIN_GNT and
		// MAX_LAT registers
		moveq #PCIMGR,D1         // Min_Gnt
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_byte
		tst.b D0
		bne.s .max_gmt_lat_exist
		moveq #PCIMLR,D1         // Max_Lat
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_byte
		tst.b D0
		bne.s .max_gmt_lat_exist
		moveq #PCI_MAXLAT,D2     // Latency Timer value 1uS for 33 MHz bus
		bra.s .write_latency_timer
.max_gmt_lat_exist:
		moveq #PCIMLR,D1         // Max_Lat
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_byte
		lsl.l #3,D0              // *8
		move.b D0,D2             // Latency Timer value
		cmp.l #PCI_MAXLAT*2,D0   // 2 uS
		bls.s .write_latency_timer
		moveq #PCIMGR,D1         // Min_Gnt
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_byte
		lsl.l #3,D0              // *8
		move.b D0,D2             // Latency Timer value
.write_latency_timer:
		moveq #PCILTR,D1         // Latency Timer
		move.l D6,D0             // function
		swap D0
		or.l D4,D0               // slot
		bsr write_config_byte
		tst.l D6                 // function
		bne .next_function
#if 0
		tst.w GRAPHICS_CARD_FLAG(SP)
		bne .next_slot           // do not check for multi-function on graphic card (too big space)
#endif
		// before we go to the next slot, we first check if we have
		// a multi-function device. If so, we need to initialize
		// the remaining functions on the current card first
		move.l D4,D0             // handle (slot)
		moveq #PCICLSR,D1
		bsr fast_read_config_longword
		btst #23,D0
		beq .next_slot
		// now that we now we have a multi function card, iterate functions
#ifdef COLDFIRE
#if 0 // #ifdef DEBUG
		lea debug46(PC),A0
		bsr debug_display_string
#endif
#endif
.next_function:
		add.l #1,D6              // function
		cmp.l #PCI_MAX_FUNCTION,D6
		bcc .next_slot
		bra .loop_handle
.no_device_found_here:
		move.l D4,D0             // handle
		mulu #PCI_MAX_FUNCTION,D0
		add.l D6,D0              // function
		mulu #PCI_DEV_DES_SIZE,D0
		move.l #PCI_DEVICE_NOT_FOUND,D1
		move.l D1,PCI_DEV_DES_STATUS(A4,D0.l)
		clr.l PCI_DEV_DES_CALLBACK(A4,D0.l)
		clr.l PCI_DEV_DES_HANDLER(A4,D0.l)
		clr.l PCI_DEV_DES_PARAMETER(A4,D0.l)
		clr.l PCI_DEV_DES_START_IRQ(A4,D0.l)
.next_slot:
		moveq #0,D6              // function number
#ifdef COLDFIRE
#if  0 // #ifdef DEBUG
		lea debug47(PC),A0
		bsr debug_display_string
#endif
#endif
.next_handle:
		addq.l #1,D4             // handle
	cmp.l #PCI_MAX_HANDLE,D4
	bcs .loop_handle
#ifdef DEBUG
	lea debug34(PC),A0
	bsr debug_display_string	
#endif
	move.l A6,D1                 // value
	move.l #0x5F504349,D0        // cookie _PCI
	bsr add_cookie
#ifdef COLDFIRE
#ifdef DEBUG
	moveq #0,D0
	bsr display_devices
#endif
#endif
	moveq #0,D0                  // OK
	lea RESERVE_STACK(SP),SP     // clear local variables
	rts
	
display_devices:

#ifdef COLDFIRE
	lea -32(SP),SP
	movem.l D1-A0,(SP)
#else
	movem.l D1-A0,-(SP)
#endif
	move.l D0,D6                 // flag more infos
	move.l #0x5F504349,D0        // _PCI
	bsr get_cookie
	move.l D0,D1
	moveq #-1,D0                 // error
	tst.l D1
	beq .end_display_devices     // not found
	lea scanning_devices(PC),A0  // CTPCI found, scanning devices...
	bsr display_string
	lea hor_separator(PC),A0
	bsr display_string_single
	lea begin_table(PC),A0       // Slot | Fctn | VendorID | DeviceID | Description
	bsr display_string_single
	lea hor_separator(PC),A0
	bsr display_string_single
	moveq #0,D4                  // slot
	moveq #0,D5                  // function
.loop_handle_display:
		move.l D5,D0
		swap D0
		or.l D4,D0               // handle
		bsr get_resource
		bmi .next_slot_display
		move.l D0,A1             // resource
		moveq #PCIIDR,D1
		move.l D5,D0
		swap D0
		or.l D4,D0               // handle
		bsr fast_read_config_longword // Device ID & Vendor ID
		move.l D0,D3
		// display slot
		moveq #0x20,D0           // " "
		bsr display_char
		moveq #0x5B,D0           // [
		bsr display_char
		moveq #0x30,D0
		add.l D4,D0              // slot
		bsr display_char
		moveq #0x5D,D0           // ]
		bsr display_char
		lea separator(PC),A0
		bsr display_string_single
		// display function
		moveq #0x20,D0           // " "
		bsr display_char
		moveq #0x5B,D0           // [
		bsr display_char
		moveq #0x30,D0
		add.l D5,D0              // function
		bsr display_char
		moveq #0x5D,D0           // ]
		bsr display_char
		lea separator(PC),A0
		bsr display_string_single
#ifdef COLDFIRE
		moveq #0,D0
		move.w D3,D0
		cmp.l #PCI_NOBODYHOME,D0 // Vendor ID
#else
		cmp.w #PCI_NOBODYHOME,D3 // Vendor ID
#endif
		beq .no_device_found_here_2
    		moveq #0x20,D0           // " "
		bsr display_char
		moveq #0x30,D0           // 0
		bsr display_char
		moveq #0x78,D0           // x
		bsr display_char
		move.w D3,D0             // Vendor ID
		bsr hex_word
    		moveq #0x20,D0           // " "
		bsr display_char
		lea separator(PC),A0
		bsr display_string_single		
		moveq #0x20,D0
		bsr display_char
		moveq #0x30,D0           // 0
		bsr display_char
		moveq #0x78,D0           // x
		bsr display_char
		move.l D3,D0
		swap D0                  // Device ID
		bsr hex_word
		moveq #0x20,D0
		bsr display_char
		lea separator(PC),A0
		bsr display_string_single
		moveq #PCIREV,D1
		move.l D5,D0
		swap D0
		or.l D4,D0               // handle
		bsr fast_read_config_longword // & class code
		move.l D0,D7
		bsr display_infos_class
#if 0
		tst.l D6
		beq.s .no_66mhz
		moveq #PCICSR,D1
		move.l D5,D0
		swap D0
		or.l D4,D0               // handle
		bsr fast_read_config_longword
		btst #21,D0
		beq.s .no_66mhz
		lea _66mhz(PC),A0
		bsr display_string_single	
.no_66mhz:
#endif
		moveq #5,D1
.loop_resource:
			move.l PCI_RSC_DESC_ERROR(A1),D0
			bmi .error_device
			move.w PCI_RSC_DESC_FLAGS(A1),D0
#if 0
			tst.l D6
			beq.s .no_infos_desc
			move.l D0,-(SP)
			lea desc_io(PC),A0
#ifdef COLDFIRE
			and.l #FLG_IO,D0
#else
			and.w #FLG_IO,D0
#endif
			bne.s .is_desc_io
			lea desc_mem(PC),A0		
.is_desc_io:
			bsr display_string_single
			move.l PCI_RSC_DESC_START(A1),D0
			add.l PCI_RSC_DESC_OFFSET(A1),D0
			bsr hex_long
			lea desc_size(PC),A0
			bsr display_string_single
			move.l PCI_RSC_DESC_LENGTH(A1),D0
			bsr hex_long
			move.l (SP)+,D0
.no_infos_desc:
#endif
#ifdef COLDFIRE
			and.l #FLG_LAST,D0
			bne.s .next_handle_3
			move.w PCI_RSC_DESC_NEXT(A1),D0
			ext.l D0
			add.l D0,A1
		subq.l #1,D1
		bpl.s .loop_resource
#else
			and.w #FLG_LAST,D0
			bne.s .next_handle_3
			add.w PCI_RSC_DESC_NEXT(A1),A1
		dbra D1,.loop_resource
#endif
.next_handle_3:
		moveq #13,D0
		bsr display_char
		moveq #10,D0
		bsr display_char
		bra.s .next_handle_2
.error_device:
		lea no_more_io_space(PC),A0  // no more IO-space available
		cmp.l #PCI_NO_MORE_IO_SPACE,D0
		beq.s .display_error_device
 		lea no_more_mem_space(PC),A0 // no more MEM-space
		cmp.l #PCI_NO_MORE_MEM_SPACE,D0
		beq.s .display_error_device
 		lea no_more_memory_below_1mb(PC),A0 // no more memory space below 1 MB
		cmp.l #PCI_NO_MORE_MEM_BELOW_1MB,D0
		beq.s .display_error_device
		lea need_more_than_4gb(PC),A0 // device requests more than 4GB memory
		cmp.l #PCI_NEED_MORE_THAN_4GB,D0
		beq.s .display_error_device
		lea unknow_memory_type(PC),A0 // device requests unknown memory type
		cmp.l #PCI_UNKNOW_MEMORY_TYPE,D0
#ifdef CHECK_PARITY
		beq.s .display_error_device
		lea parity_error(PC),A0 // detected parity error
		cmp.l #PCI_PARITY_ERROR,D0
#endif		
		bne.s .next_handle_2
.display_error_device:
		bsr display_string_single
		bra.s .next_slot_display
.no_device_found_here_2:
		lea no_device(PC),A0     // no device
		bsr display_string_single
		bra.s .next_slot_display		
.next_handle_2:
		tst.l D4
		beq.s .next_slot_display // do not search for multiple devices on bridge
#if 0
		move.l D7,D0             // PCIREV
		swap D0
		lsr.l #8,D0              // base class code
		and.l #0xFF,D0
		cmp.l #PCI_CLASS_DISPLAY,D0
		beq.s .next_slot_display // do not check for multi-function on graphic card (too big space)
#endif
		// do we have a multi-function device?
		move.l D4,D0             // handle (slot)
		moveq #PCICLSR,D1
		bsr fast_read_config_longword
		btst #23,D0
		beq.s .next_slot_display
		addq.l #1,D5             // function
		cmp.l #PCI_MAX_FUNCTION,D5
		bcs .loop_handle_display
.next_slot_display:
		moveq #0,D5
		addq.l #1,D4             // handle
	cmp.l #PCI_MAX_HANDLE,D4
	bcs .loop_handle_display
	moveq #0,D0                  // OK
.end_display_devices:
#ifdef COLDFIRE
	movem.l (SP),D1-A0
	lea 32(SP),SP
#else
	movem.l (SP)+,D1-A0
#endif
	rts

display_infos_class:

#ifdef COLDFIRE
	lea -16(SP),SP
	movem.l D0-D1/D4/A0,(SP)
#else
	movem.l D0-D1/D4/A0,-(SP)
#endif
	move.l D0,D4                 // class code
	move.l D4,D1
	swap D1
	ext.l D1
	lsr.l #8,D1                  // base class code
	cmp.l #PCI_CLASS_NONE,D1
	beq .old_device
	cmp.l #PCI_CLASS_MASS,D1
	beq .mass_storage
	cmp.l #PCI_CLASS_NET,D1
	beq .network_controller
	cmp.l #PCI_CLASS_DISPLAY,D1
	beq .display_controller
	cmp.l #PCI_CLASS_MM,D1
	beq .multimedia_controller
	cmp.l #PCI_CLASS_MEM,D1
	beq .memory_controller
	cmp.l #PCI_CLASS_BRIDGE,D1
	beq .bridge_device
	cmp.l #PCI_CLASS_COMM,D1
	beq .communications_controller
	cmp.l #PCI_CLASS_PERIPH,D1
	beq .peripheral_controller
	cmp.l #PCI_CLASS_INPUT,D1
	beq .input_device
	cmp.l #PCI_CLASS_DOCK,D1
	beq .docking_station
	cmp.l #PCI_CLASS_PROCESSOR,D1
	beq .processor
	cmp.l #PCI_CLASS_SERIALBUS,D1
	beq .serial_bus
	cmp.l #PCI_CLASS_WIRELESS,D1
	beq .wireless_controller
	cmp.l #PCI_CLASS_INTIO,D1
	beq .intelligent_io_controller
	cmp.l #PCI_CLASS_SATELLITE,D1
	beq .satellite_communication
	cmp.l #PCI_CLASS_CRYPT,D1
	beq .encrytion_decryption
	cmp.l #PCI_CLASS_SIGNAL,D1
	beq .signal_processing
	bra .unknow_class_device
.old_device:
	lea pciinfo0(PC),A0          // Device built before Class Code definitions
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_NONE_NOTVGA,D1
	beq.s .all_except_vga
	cmp.l #PCI_NONE_VGA,D1
	beq.s .vga_compatible
	bra .unknow_subclass_device
.all_except_vga:
	lea pciinfo1(PC),A0          // (All except VGA)
	bra .add_subclass
.vga_compatible:
	lea pciinfo2(PC),A0          // (VGA compatible)
	bra .add_subclass
.mass_storage:
	lea pciinfo10(PC),A0         // Mass Storage Controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_MASS_SCSI,D1
	beq.s .scsi_bus_controller
	cmp.l #PCI_MASS_IDE,D1
	beq.s .ide_controller
	cmp.l #PCI_MASS_FD,D1
	beq.s .floppy_disk_controller
	cmp.l #PCI_MASS_IPI,D1
	beq.s .ipi_bus_controller
	cmp.l #PCI_MASS_RAID,D1
	beq.s .raid_controller
	cmp.l #PCI_MASS_ATA,D1
	beq.s .ata_controller
	cmp.l #PCI_MASS_SATA,D1
	beq.s .serial_ata
	bra .unknow_subclass_device
.scsi_bus_controller:
	lea pciinfo11(PC),A0         // (SCSI bus)
	bra .add_subclass
.ide_controller:
	lea pciinfo12(PC),A0         // (IDE)
	bra .add_subclass
.floppy_disk_controller:
	lea pciinfo13(PC),A0         // (Floppy Disk)
	bra .add_subclass
.ipi_bus_controller:
	lea pciinfo14(PC),A0         // (IPI bus)
	bra .add_subclass
.raid_controller:
	lea pciinfo15(PC),A0         // (RAID)
	bra .add_subclass
.ata_controller:
	lea pciinfo16(PC),A0         // (ATA)
	bra .add_subclass
.serial_ata:
	lea pciinfo17(PC),A0         // (SATA)
	bra .add_subclass
.network_controller:
	lea pciinfo20(PC),A0         // Network controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_NET_ENET,D1
	beq.s .ethernet_controller
	cmp.l #PCI_NET_TOKEN,D1
	beq.s .token_ring_controller
	cmp.l #PCI_NET_FDDI,D1
	beq.s .fddi_controller
	cmp.l #PCI_NET_ATM,D1
	beq.s .atm_controller
	cmp.l #PCI_NET_ISDN,D1
	beq.s .idsn_controller
	cmp.l #PCI_NET_WFIP,D1
	beq.s .worldfip_controller
	cmp.l #PCI_NET_PICMG,D1
	beq.s .picmg_controller
	bra .unknow_subclass_device
.ethernet_controller:
	lea pciinfo21(PC),A0         // (Ethernet)
	bra .add_subclass
.token_ring_controller:
	lea pciinfo22(PC),A0         // (Token Ring)
	bra .add_subclass
.fddi_controller:
	lea pciinfo23(PC),A0         // (FDDI)
	bra .add_subclass
.atm_controller:
	lea pciinfo24(PC),A0         // (ATM)
	bra .add_subclass
.idsn_controller:
	lea pciinfo25(PC),A0         // (ISDM)
	bra .add_subclass
.worldfip_controller:
	lea pciinfo26(PC),A0         // (WorldFip)
	bra .add_subclass
.picmg_controller:
	lea pciinfo27(PC),A0         // (PICMG)
	bra .add_subclass
.display_controller:
	lea pciinfo30(PC),A0         // Display Controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_DISPLAY_VGA,D1
	beq.s .vga_device
	cmp.l #PCI_DISPLAY_XGA,D1
	beq.s .xvga_device
	cmp.l #PCI_DISPLAY_3D,D1
	beq.s .controller_3d
	bra .unknow_subclass_device
.vga_device:
	lea pciinfo31(PC),A0         // (VGA)
	bra .add_subclass
.xvga_device:
	lea pciinfo32(PC),A0         // (XGA)
	bra .add_subclass
.controller_3d:
	lea pciinfo33(PC),A0         // (3D)
	bra .add_subclass
.multimedia_controller:
	lea pciinfo40(PC),A0         // Multimedia Controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_MM_VIDEO,D1
	beq.s .video_device
	cmp.l #PCI_MM_AUDIO,D1
	beq.s .audio_device	
	cmp.l #PCI_MM_TELEPHONY,D1
	beq.s .computer_telephony
	bra .unknow_subclass_device
.video_device:
	lea pciinfo41(PC),A0         // (Video)
	bra .add_subclass
.audio_device:
	lea pciinfo42(PC),A0         // (Audio)
	bra .add_subclass
.computer_telephony:
	lea pciinfo43(PC),A0         // (Computer Telephony)
	bra .add_subclass
.memory_controller:
	lea pciinfo50(PC),A0         // Memory controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_MEM_RAM,D1
	beq.s .ram_device
	cmp.l #PCI_MEM_FLASH,D1
	beq.s .flash_device
	bra .unknow_subclass_device
.ram_device:
	lea pciinfo51(PC),A0         // (RAM)
	bra .add_subclass
.flash_device:
	lea pciinfo52(PC),A0         // (FLASH)
	bra .add_subclass
.bridge_device:
	lea pciinfo60(PC),A0         // Bridge Controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_BRIDGE_HOST,D1
	beq.s .host_bridge
	cmp.l #PCI_BRIDGE_ISA,D1
	beq.s .isa_bridge
	cmp.l #PCI_BRIDGE_EISA,D1
	beq.s .eisa_bridge
	cmp.l #PCI_BRIDGE_MC,D1
	beq.s .mc_bridge
	cmp.l #PCI_BRIDGE_PCI,D1
	beq.s .pci_to_pci_bridge
	cmp.l #PCI_BRIDGE_PCMCIA,D1
	beq.s .pcmcia_bridge
	cmp.l #PCI_BRIDGE_NUBUS,D1
	bra.s .nubus_bridge
	cmp.l #PCI_BRIDGE_CARDBUS,D1
	beq.s .cardbus_bridge
	cmp.l #PCI_BRIDGE_RACE,D1
	beq.s .race_bridge
	cmp.l #PCI_BRIDGE_STPCI,D1
	beq.s .stpci_bridge
	cmp.l #PCI_BRIDGE_IB,D1
	beq.s .infiniband_bridge
	bra .unknow_subclass_device
.host_bridge:
	lea pciinfo61(PC),A0         // (Host Bridge)
	bra .add_subclass
.isa_bridge:
	lea pciinfo62(PC),A0         // (ISA Bridge)
	bra .add_subclass
.eisa_bridge:
	lea pciinfo63(PC),A0         // (EISA Bridge)
	bra .add_subclass
.mc_bridge:
	lea pciinfo64(PC),A0         // (MC Bridge)
	bra .add_subclass
.pci_to_pci_bridge:
	lea pciinfo65(PC),A0        // (PCI/PCI Bridge)
	bra .add_subclass
.pcmcia_bridge:
	lea pciinfo66(PC),A0         // (PCMCIA Bridge)
	bra .add_subclass
.nubus_bridge:
	lea pciinfo67(PC),A0         // (NUBUS Bridge)
	bra .add_subclass
.cardbus_bridge:
	lea pciinfo68(PC),A0         // (CARDBUS Bridge)
	bra .add_subclass
.race_bridge:
	lea pciinfo68(PC),A0         // (RACE Bridge)
	bra .add_subclass
.stpci_bridge:
	lea pciinfo610(PC),A0        // (STPCI Bridge)
	bra .add_subclass
.infiniband_bridge:
	lea pciinfo611(PC),A0        // (InfiniBand Bridge)
	bra .add_subclass
.communications_controller:
	lea pciinfo70(PC),A0         // Communications Controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_COMM_GENERIC_XT,D1
	beq.s .xt_serial_controller
	cmp.l #PCI_COMM_PARALLEL,D1
	beq.s .parallel_port_controller
	cmp.l #PCI_COMM_MSC,D1
	beq.s .multiport_serial_controller
	cmp.l #PCI_COMM_MODEM,D1
	beq.s .modem_controller
	cmp.l #PCI_COMM_GPIB,D1
	beq.s .gpib_controller
	cmp.l #PCI_COMM_SMARTCARD,D1
	beq.s .smart_card_controller
	bra .unknow_subclass_device
.xt_serial_controller:
	lea pciinfo71(PC),A0         // (XT Compatible Serial)
	bra .add_subclass
.parallel_port_controller:
	lea pciinfo72(PC),A0         // (Parallel Port)
	bra .add_subclass
.multiport_serial_controller:
	lea pciinfo73(PC),A0         // (Multiport Serial)
	bra .add_subclass
.modem_controller:
	lea pciinfo74(PC),A0         // (Modem Controller)
	bra .add_subclass
.gpib_controller:
	lea pciinfo75(PC),A0         // (GPIB Controller)
	bra .add_subclass
.smart_card_controller:
	lea pciinfo76(PC),A0         // (Smart Card)
	bra .add_subclass	
.peripheral_controller:
	lea pciinfo80(PC),A0         // Peripheral Controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_PERIPH_PIC,D1
	beq.s .generic_pic
	cmp.l #PCI_PERIPH_DMA,D1
	beq.s .dma_controller
	cmp.l #PCI_PERIPH_TIMER,D1
	beq.s .system_timer_controller
	cmp.l #PCI_PERIPH_RTC,D1
	beq.s .rtc_controller
	cmp.l #PCI_PERIPH_HPC,D1
	beq.s .pci_hot_plug_controller
	bra .unknow_subclass_device
.generic_pic:
	lea pciinfo81(PC),A0         // (PIC)
	bra .add_subclass
.dma_controller:
	lea pciinfo82(PC),A0         // (DMA)
	bra .add_subclass
.system_timer_controller:
	lea pciinfo83(PC),A0         // (System Timer)
	bra .add_subclass
.rtc_controller:
	lea pciinfo84(PC),A0         // (RTC)
	bra .add_subclass
.pci_hot_plug_controller:
	lea pciinfo85(PC),A0         // (PCI Hot-Plug)
	bra .add_subclass
.input_device:
	lea pciinfo90(PC),A0         // Input Device
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_INPUT_KEYBOARD,D1
	beq.s .keyboard_controller
	cmp.l #PCI_INPUT_DIGITIZ,D1
	beq.s .digitizer
	cmp.l #PCI_INPUT_MOUSE,D1
	beq.s .mouse_controller
	cmp.l #PCI_INPUT_SCANNER,D1
	beq.s .scanner_controller
	cmp.l #PCI_INPUT_GAMEPORT,D1
	beq.s .gameport_controller
	bra .unknow_subclass_device
.keyboard_controller:
	lea pciinfo91(PC),A0         // (Keyboard)
	bra .add_subclass
.digitizer:
	lea pciinfo92(PC),A0         // (Digitizer)
	bra .add_subclass
.mouse_controller:
	lea pciinfo93(PC),A0         // (Mouse)
	bra .add_subclass
.scanner_controller:
	lea pciinfo94(PC),A0         // (Scanner)
	bra .add_subclass
.gameport_controller:
	lea pciinfo95(PC),A0         // (Gameport)
	bra .add_subclass
.docking_station:
	lea pciinfo100(PC),A0        // Docking Station
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_DOCK_GENERIC,D1
	bne .unknow_subclass_device
	lea pciinfo101(PC),A0        // (Docking Station)
	bra .add_subclass
.processor:
	lea pciinfo110(PC),A0        // Processor
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_PROCESSOR_386,D1
	beq.s .i386
	cmp.l #PCI_PROCESSOR_486,D1
	beq.s .i486
	cmp.l #PCI_PROCESSOR_PENT,D1
	beq.s .pentium
	cmp.l #PCI_PROCESSOR_ALPHA,D1
	beq.s .alpha
	cmp.l #PCI_PROCESSOR_POWERPC,D1
	beq.s .powerpc
	cmp.l #PCI_PROCESSOR_MIPS,D1
	beq.s .mips
	cmp.l #PCI_PROCESSOR_COPROC,D1
	beq.s .coprocessor
	bra .unknow_subclass_device
.i386:
	lea pciinfo111(PC),A0        // (386)
	bra .add_subclass
.i486:
	lea pciinfo112(PC),A0        // (486)
	bra .add_subclass
.pentium:
	lea pciinfo113(PC),A0        // (Pentium)
	bra .add_subclass
.alpha:
	lea pciinfo114(PC),A0        // (Alpha)
	bra .add_subclass
.powerpc:
	lea pciinfo115(PC),A0        // (PowerPC)
	bra .add_subclass
.mips:
	lea pciinfo116(PC),A0        // (MIPS)
	bra .add_subclass
.coprocessor:
	lea pciinfo117(PC),A0        // (Coprocessor)
	bra .add_subclass
.serial_bus:
	lea pciinfo120(PC),A0        // Serial Bus
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_SERIAL_FIRE,D1
	beq.s .firewire
	cmp.l #PCI_SERIAL_ACCESS,D1
	beq.s .access
	cmp.l #PCI_SERIAL_SSA,D1
	beq.s .ssa
	cmp.l #PCI_SERIAL_USB,D1
	beq.s .usb
	cmp.l #PCI_SERIAL_FIBRE,D1
	beq.s .fibre_channel
	cmp.l #PCI_SERIAL_SMBUS,D1
	beq.s .system_management_bus
	cmp.l #PCI_SERIAL_IB,D1
	beq.s .infiniband
	cmp.l #PCI_SERIAL_IPMI,D1
	beq.s .ipmi
	cmp.l #PCI_SERIAL_SERCOS,D1
	beq.s .sercos
	cmp.l #PCI_SERIAL_CANBUS,D1
	beq.s .canbus
	bra .unknow_subclass_device
.firewire:
	lea pciinfo121(PC),A0        // (FireWire)
	bra .add_subclass
.access:
	lea pciinfo122(PC),A0        // (ACCESS)
	bra .add_subclass
.ssa:
	lea pciinfo123(PC),A0        // (SSA)
	bra .add_subclass
.usb:
	lea pciinfo124(PC),A0        // (USB)
	bra .add_subclass
.fibre_channel:
	lea pciinfo125(PC),A0        // (Fibre Channel)
	bra .add_subclass
.system_management_bus:
	lea pciinfo126(PC),A0        // (System Management Bus)
	bra .add_subclass
.infiniband:
	lea pciinfo127(PC),A0        // (InfiniBand)
	bra .add_subclass
.ipmi:
	lea pciinfo128(PC),A0        // (IPMI)
	bra .add_subclass
.sercos:
	lea pciinfo129(PC),A0        // (SERCOS)
	bra .add_subclass
.canbus:
	lea pciinfo1210(PC),A0       // (CANbus)	
	bra .add_subclass
.wireless_controller:
	lea pciinfo130(PC),A0        // Wireless Controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_WIRELESS_IRDA,D1
	beq.s .irda_controller
	cmp.l #PCI_WIRELESS_IR,D1
	beq.s .consumer_ir_controller
	cmp.l #PCI_WIRELESS_RF,D1
	beq.s .rf_controller
	cmp.l #PCI_WIRELESS_BLUETOOTH,D1
	beq.s .bluetooth_controller
	cmp.l #PCI_WIRELESS_BROADBAND,D1
	beq.s .broadband_controller
	cmp.l #PCI_WIRELESS_80211A,D1
	beq.s .ethernet_802_11a
	cmp.l #PCI_WIRELESS_80211B,D1
	beq.s .ethernet_802_11b
	bra .unknow_subclass_device
.irda_controller:
	lea pciinfo131(PC),A0        // (iRDA Compatible)
	bra .add_subclass
.consumer_ir_controller:
	lea pciinfo132(PC),A0        // (Consumer IR)
	bra .add_subclass
.rf_controller:
	lea pciinfo133(PC),A0        // (RF)
	bra .add_subclass
.bluetooth_controller:
	lea pciinfo134(PC),A0        // (Bluetooth)
	bra .add_subclass
.broadband_controller:
	lea pciinfo135(PC),A0        // (Broadband)
	bra .add_subclass
.ethernet_802_11a:
	lea pciinfo136(PC),A0        // (Ethernet 802.11a)
	bra .add_subclass
.ethernet_802_11b:
	lea pciinfo137(PC),A0        // (Ethernet 802.11b)
	bra .add_subclass
.intelligent_io_controller:
	lea pciinfo140(PC),A0        // Intelligent IO Controller
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_INTIO_I20,D1
	bne .unknow_subclass_device
	lea pciinfo141(PC),A0        // (I20 Arch)
	bra .add_subclass
.satellite_communication:
	lea pciinfo150(PC),A0        // Satellite Communication
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_SATELLITE_COMM_TV,D1
	beq.s .satellite_tv
	cmp.l #PCI_SATELLITE_COMM_AUDIO,D1
	beq.s .satellite_audio
	cmp.l #PCI_SATELLITE_COMM_VOICE,D1
	beq.s .satellite_voice
	cmp.l #PCI_SATELLITE_COMM_DATA,D1
	beq.s .satellite_data
	bra .unknow_subclass_device
.satellite_tv:
	lea pciinfo151(PC),A0        // (TV)
	bra .add_subclass
.satellite_audio:
	lea pciinfo152(PC),A0        // (Audio)
	bra .add_subclass
.satellite_voice:
	lea pciinfo153(PC),A0        // (Voice)
	bra .add_subclass
.satellite_data:
	lea pciinfo154(PC),A0        // (DATA)
	bra .add_subclass
.encrytion_decryption:
	lea pciinfo160(PC),A0        // Encrytion/Decryption
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_CRYPT_NETWORK,D1
	beq.s .crypt_network
	cmp.l #PCI_CRYPT_ENTERTAINMENT,D1
	beq.s .crypt_entertainment
	bra.s .unknow_subclass_device
.crypt_network:
	lea pciinfo161(PC),A0        // (Network and Computing)
	bra .add_subclass
.crypt_entertainment:
	lea pciinfo162(PC),A0        // (Entertainment en/decrypt)
	bra .add_subclass	
.signal_processing:
	lea pciinfo170(PC),A0        // Signal Processing
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_SIGNAL_DPIO,D1
	beq.s .signal_dpio
	cmp.l #PCI_SIGNAL_PERF_COUNTERS,D1
	beq.s .signal_performance_counters
	cmp.l #PCI_SIGNAL_COMM_SYNC,D1
	beq.s .signal_comm_synchronization
	cmp.l #PCI_SIGNAL_MANAGEMENT,D1
	beq.s .signal_management
.signal_dpio:
	lea pciinfo171(PC),A0        // (DPIO modules)
	bra .add_subclass
.signal_performance_counters:
	lea pciinfo172(PC),A0        // (Performance counters)
	bra .add_subclass
.signal_comm_synchronization:
	lea pciinfo173(PC),A0        // (Comm. synchronization)
	bra .add_subclass
.signal_management:
	lea pciinfo174(PC),A0        // (Management)	
	bra .add_subclass	
.unknow_subclass_device:
	lea pciinfo9(PC),A0          // (unknown)
.add_subclass:
	bsr display_string_single
	bra.s .end_info_class
.unknow_class_device:
	lea pciinfo999(PC),A0        // Device does not fit in any defined classes
	bsr display_string_single
.end_info_class:
#ifdef COLDFIRE
	movem.l (SP),D0-D1/D4/A0
	lea 16(SP),SP
#else
	movem.l (SP)+,D0-D1/D4/A0
#endif
	rts

_find_pci_device:

	move.l 2(A0),D0           // ID
	move.w 6(A0),D1           // index

find_pci_device:
#ifdef COLDFIRE
	lea -24(SP),SP
	movem.l D3-D6/A4-A5,(SP)
#else
	movem.l D3-D6/A4-A5,-(SP)
#endif
	move.l D0,D3              // ID
	move.w D1,D5              // index
	ext.l D5
#ifdef COLDFIRE
	ext.l D0
	cmp.l #-1,D0
#else
	move.w SR,-(SP)
	or.w #0x700,SR            // no interrupts
	lea .no_pci_devices(PC),A0
	move.l 8,A5               // bus error
	move.l A0,8
	move.l SP,A4              // save ssp
	cmp.w #-1,D3
#endif
	beq.s .query_all_cards
	moveq #0,D4               // slot
	moveq #0,D6               // function
.loop_find_pci_device:
		moveq #PCIIDR,D1     	// Device ID & Vendor ID
		move.l D6,D0		// function
		swap D0
		or.l D4,D0         	// slot
		bsr fast_read_config_longword
		cmp.l D0,D3          	// ID
		bne.s .next_find_pci_device
		tst.l D5             	// index
		beq .end_index_pci_device
		subq.l #1,D5
		tst.l D4
		beq .next_slot_find_pci_device // do not look for multi-function devices at bridge
.next_find_pci_device:
		addq.l #1,D6		// function
		cmp.l #PCI_MAX_FUNCTION,D6
		bcs .loop_find_pci_device
.next_slot_find_pci_device:
		moveq #0,D6
		addq.l #1,D4              // handle
	cmp.l #PCI_MAX_HANDLE,D4
	bcs .loop_find_pci_device
	bra.s .no_pci_devices
.query_all_cards:
	moveq #0,D4          	// slot
	moveq #0,D6	     	// function
.loop_query_all_cards:
		moveq #PCIIDR,D1
		move.l D6,D0             // current function number
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_longword // Device ID & Vendor ID
#ifdef COLDFIRE
		moveq #0,D1
		move.w D0,D1
		cmp.l #PCI_NOBODYHOME,D1 // Vendor ID
#else
		cmp.w #PCI_NOBODYHOME,D0 // Vendor ID
#endif
		beq.s .next_slot_query_all_cards
		tst.l D5             	// index
		beq.s .end_index_pci_device
		subq.l #1,D5
		tst.l D4
		beq .next_slot_query_all_cards // don't look for multi-function-devices at bridge
		move.l D4,D0              // handle (slot)
		moveq #PCICLSR,D1	// check for multi-function device
		bsr fast_read_config_longword
		btst #23,D0
		beq.s .next_slot_query_all_cards
		addq.l #1,D6
		cmp.l #PCI_MAX_FUNCTION,D6
		bcs.s .loop_query_all_cards
.next_slot_query_all_cards:
		moveq.l #0,D6
		addq.l #1,D4             // handle
	cmp.l #PCI_MAX_HANDLE,D4
	bcs.s .loop_query_all_cards
.no_pci_devices:
#ifndef COLDFIRE
	move.l A5,8              // restore bus error
	move.l A4,SP             // restore ssp
	move.w (SP)+,SR
#endif
	moveq #PCI_DEVICE_NOT_FOUND,D0
	bra.s .end_find_pci_device
.end_index_pci_device:
#ifndef COLDFIRE
    	move.l A5,8              // restore bus error
	move.l A4,SP             // restore ssp
	move.w (SP)+,SR
#endif
	move.l D6,D0
	swap D0
	or.l D4,D0               // handle 
.end_find_pci_device:
#ifdef COLDFIRE
	movem.l (SP),D3-D6/A4-A5
	lea 24(SP),SP
#else
	movem.l (SP)+,D3-D6/A4-A5
#endif
	rts
	
_find_pci_classcode:

	move.l 2(A0),D0          // class
	move.w 6(A0),D1          // index

find_pci_classcode:

#ifdef COLDFIRE
	lea -16(SP),SP
	movem.l D3-D6,(SP)
#else
	movem.l D3-D6,-(SP)
#endif /* COLDFIRE */
	move.l D0,D4             // class
	moveq #0,D5
	move.w D1,D5             // index
	moveq #0,D3              // slot
	moveq #0,D6              // function
.loop_pci_classcode:
		moveq #PCIIDR,D1
		move.l D6,D0             // current function number
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_longword // Device ID & Vendor ID
#ifdef COLDFIRE
		moveq #0,D1
		move.w D0,D1
		cmp.l #PCI_NOBODYHOME,D1 // Vendor ID
#else
		cmp.w #PCI_NOBODYHOME,D0 // Vendor ID
#endif
		beq.s .next_pci_classcode
		move.l D4,D0
		and.l #0x4000000,D0      // if 0 compare base class
		bne.s .ignore_base_class
		moveq #PCICCR+2,D1       // PCI Class Code Register
		move.l D6,D0
		swap D0
		or.l D3,D0               // handle
		bsr fast_read_config_byte
		move.l D4,D1             // class
		swap D1
#ifdef COLDFIRE
		extb.l D0
		extb.l D1
		cmp.l D1,D0              // base class code
#else
		cmp.b D1,D0              // base class code
#endif
		bne.s .next_pci_classcode
.ignore_base_class:
		move.l D4,D0             // class
		and.l #0x2000000,D0      // if 0 compare subclass
		bne.s .ignore_subclass
		moveq #PCICCR+1,D1       // PCI Class Code Register
		move.l D6,D0
		swap D0
		or.l D3,D0               // handle
		bsr fast_read_config_byte
		move.l D4,D1             // class
		lsr.l #8,D1
#ifdef COLDFIRE
		extb.l D0
		extb.l D1
		cmp.l D1,D0              // subclass code
#else
		cmp.b D1,D0              // subclass code
#endif
		bne.s .next_pci_classcode
.ignore_subclass:
		move.l D4,D0
		and.l #0x1000000,D0      // if 0 compare prog. if
		bne.s .ignore_prog_if
		moveq #PCICCR,D1         // PCI Class Code Register
		move.l D6,D0
		swap D0
		or.l D3,D0               // handle
		bsr fast_read_config_byte
#ifdef COLDFIRE
		moveq #0,D1
		move.b D4,D1
		cmp.l D1,D0              // prog. if
#else
		cmp.b D4,D0              // prog. if
#endif
		bne.s .next_pci_classcode
.ignore_prog_if:
		tst.l D5                 // index
		beq.s .end_index_classcode
		subq.l #1,D5
.next_pci_classcode:
		addq.l #1,D6
	cmp.l #PCI_MAX_FUNCTION,D6
	bcs .loop_pci_classcode
	clr.l D6
	addq.l #1,D3             // handle
	cmp.l #PCI_MAX_HANDLE,D3
	bcs .loop_pci_classcode
	moveq #PCI_DEVICE_NOT_FOUND,D0
	bra.s .end_pci_classcode
.end_index_classcode:
	move.l D3,D0
.end_pci_classcode:
#ifdef COLDFIRE
	movem.l (SP),D3-D5
	lea 16(SP),SP
#else
	movem.l (SP)+,D3-D5
#endif /* COLDFIRE */
	rts
	
_read_config_byte:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // PCI register
	move.l 8(A0),A0          // pointer to space for read data

read_config_byte:

	move.l A0,A1             // address
	move.l D0,D2
	ext.l D0                 // handle
	bmi .bad_handle_read_config_byte
	beq .read_local_config_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_read_config_byte
	swap D2
	ext.l D2
	bmi .bad_handle_read_config_byte
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc .bad_handle_read_config_byte
	move.l D3,-(SP)
	moveq #2,D3
	and.l D1,D3
	move.l D3,-(SP)
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	lsl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif
	lea PCI_IO_OFFSET,A0
	move.l 4(SP),D2
	move.b (A0,D2.l),(A1)    // address
	move.l (SP)+,D2
	addq.l #4,SP
	move.l (SP)+,D3
#ifdef COLDFIRE
	move.l D2,MCF_PCI_PCICAR
#else
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_byte
	moveq #-1,D0
	move.b D0,(A1)
.no_master_abort_byte:
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.read_local_config_byte:
	ext.l D1
	cmp.l #LAST_LOCAL_REGISTER,D1
	bcc.s .bad_register_read_config_byte
	bsr read_local_config_byte
	move.b D0,(A1)
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_register_read_config_byte:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts
.bad_handle_read_config_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_config_word:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // PCI register
	move.l 8(A0),A0          // pointer to space for read data

read_config_word:

	move.l A0,A1             // address
	btst #0,D1               // PCI register
	bne .bad_register_read_config_word
	move.l D0,D2
	ext.l D0                 // handle
	bmi .bad_handle_read_config_word
	beq .read_local_config_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_read_config_word
	swap D2
	ext.l D2
	bmi .bad_handle_read_config_word
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc .bad_handle_read_config_word
	move.l D3,-(SP)
	moveq #2,D3
	and.l D1,D3
	move.l D3,-(SP)
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	lsl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif
	lea PCI_IO_OFFSET,A0
	move.l 4(SP),D2
//#ifdef BIG_ENDIAN
//	move.w (A0,D2.l),(A1)
//#else
	move.w (A0,D2.l),D0
#ifdef COLDFIRE
	moveq #0,D1
	move.w D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	or.l D1,D0
#else
	ror.w #8,D0
#endif /* COLDFIRE */
	move.w D0,(A1)           // address
//#endif
	move.l (SP)+,D2
	addq.l #4,SP
	move.l (SP)+,D3
#ifdef COLDFIRE
	move.l D2,MCF_PCI_PCICAR
#else
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_word
	moveq #-1,D0
	move.w D0,(A1)
.no_master_abort_word:
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.read_local_config_word:
	ext.l D1
	cmp.l #LAST_LOCAL_REGISTER,D1
	bcc.s .bad_register_read_config_word
	bsr read_local_config_word
	move.w D0,(A1)
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_register_read_config_word:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts
.bad_handle_read_config_word:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_config_longword:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // PCI register
	move.l 8(A0),A0          // pointer to space for read data

read_config_longword:

	move.l A0,A1             // address
	moveq #3,D2
	and.l D1,D2              // PCI register
	bne .bad_register_read_config_longword
	move.l D0,D2
	ext.l D0                 // handle
	bmi .bad_handle_read_config_longword
	beq .read_local_config_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_read_config_longword
	swap D2
	ext.l D2
	bmi .bad_handle_read_config_longword
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc .bad_handle_read_config_longword
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#if 0 // #ifdef DEBUG
	lea debug36(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
#endif
#else
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif
	lea PCI_IO_OFFSET,A0
//#ifdef BIG_ENDIAN
//	move.l (A0),(A1)
//#else
	move.l (A0),D0
#ifdef COLDFIRE
	move.l D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	and.l #0x00FF00FF,D1
	and.l #0xFF00FF00,D0
	or.l D1,D0
	swap D0
#else
	ror.w #8,D0
	swap D0
	ror.w #8,D0
#endif /* COLDFIRE */
	move.l D0,(A1)           // address
//#endif
	move.l (SP)+,D2
#ifdef COLDFIRE
	move.l D2,MCF_PCI_PCICAR
#if 0 // #ifdef DEBUG
	move.l D0,-(SP)
	move.l (A1),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif
#else
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_longword
	moveq #-1,D0
	move.l D0,(A1)
.no_master_abort_longword:
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.read_local_config_longword:
	ext.l D1
	cmp.l #LAST_LOCAL_REGISTER,D1
	bcc.s .bad_register_read_config_longword
	bsr read_local_config_longword
	move.l D0,(A1)
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_register_read_config_longword:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts
.bad_handle_read_config_longword:
	moveq #PCI_BAD_HANDLE,D0
	rts

_fast_read_config_byte:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // PCI register
	
fast_read_config_byte:

	tst.w D0                 // check slot number
	beq read_local_config_byte
	moveq #3,D2
	and.l D1,D2
	move.l D2,-(SP)
	move.l D0,D2             // function(H)/handle(L)
	ext.l D0
	swap D2
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif
	lea PCI_IO_OFFSET,A0
	moveq #0,D0
	move.l 4(SP),D2
	move.b (A0,D2.l),D0
	move.l (SP)+,D2
	addq.l #4,SP
#ifdef COLDFIRE
	move.l D2,MCF_PCI_PCICAR
#else
	move.l D0,-(SP)
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .fast_no_master_abort_byte
	moveq #-1,D0
	move.l D0,(SP)
.fast_no_master_abort_byte:
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.l (SP)+,D0
#endif
	rts

_fast_read_config_word:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // PCI register

fast_read_config_word:

	tst.w D0                 // check slot number
	beq read_local_config_word
	moveq #2,D2
	and.l D1,D2
	move.l D2,-(SP)
	move.l D0,D2             // function(H)/handle(L)
	ext.l D0
	swap D2
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif
	lea PCI_IO_OFFSET,A0
	moveq #0,D0
	move.l 4(SP),D2
	move.w (A0,D2.l),D0
//#ifndef BIG_ENDIAN
#ifdef COLDFIRE
	moveq #0,D1
	move.w D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	or.l D1,D0
#else
	ror.w #8,D0
#endif /* COLDFIRE */
//#endif
	move.l (SP)+,D2
	addq.l #4,SP
#ifdef COLDFIRE
	move.l D2,MCF_PCI_PCICAR
#else
	move.l D0,-(SP)
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .fast_no_master_abort_word
	moveq #-1,D0
	move.l D0,(SP)
.fast_no_master_abort_word:
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.l (SP)+,D0
#endif
	rts
	
_fast_read_config_longword:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // PCI register

fast_read_config_longword:

	move.l D0,D2
	ext.l D0                 // check slot number
	beq read_local_config_longword
	swap D2
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#if 0 // #ifdef DEBUG
	lea debug36(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bset #31,D0
	bsr debug_hex_long
	moveq #0x20,D0           // " "
	bsr debug_display_char	 
	moveq #0x30,D0           // "0"
	bsr debug_display_char
	moveq #0x78,D0           // "x"
	bsr debug_display_char
#endif
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2	// enable config space access
	move.l D2,MCF_PCI_PCICAR
#else
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
	lea PCI_IO_OFFSET,A0
	move.l (A0),D0
//#ifndef BIG_ENDIAN
#ifdef COLDFIRE
	move.l D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	and.l #0x00FF00FF,D1
	and.l #0xFF00FF00,D0
	or.l D1,D0
	swap D0
#else
	ror.w #8,D0
	swap D0
	ror.w #8,D0
#endif /* COLDFIRE */
//#endif
	move.l (SP)+,D2
#ifdef COLDFIRE
	move.l D2,MCF_PCI_PCICAR
#else
	move.l D0,-(SP)
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .fast_no_master_abort_longword
	moveq #-1,D0
	move.l D0,(SP)
.fast_no_master_abort_longword:
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.l (SP)+,D0
#endif /* COLDFIRE */
#if 0 // #ifdef DEBUG
	move.l D0,-(SP)
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif
	rts
	
_write_config_byte:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // PCI register
	move.w 8(A0),D2          // data to write

write_config_byte:

	move.l D3,-(SP)
	move.l D4,-(SP)
	move.l D0,D3             // handle
	ext.l D0
	bmi .bad_handle_write_config_byte
	beq .write_local_config_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_write_config_byte
	swap D3
	ext.l D3                 // function
	bmi .bad_handle_write_config_byte
	cmp.l #PCI_MAX_FUNCTION,D3
	bcc.s .bad_handle_write_config_byte
	moveq #3,D4
	and.l D1,D4
	move.l D4,-(SP)
	asl.l #8,D3              // shift function number into place
	or.l D3,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D3
	move.b (A0,D0.l),D3
	moveq #11,D0
	asl.l D0,D3              // Device Number
	or.l D3,D1
	move.l D1,-(SP)
	move.l D2,-(SP)
	move.l D1,D2
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif
	move.l (SP)+,D2
	lea PCI_IO_OFFSET,A0
	move.l 4(SP),D1
	move.b D2,(A0,D1.l)
	move.l (SP)+,D2
	addq.l #4,SP
#ifdef COLDFIRE
	move.l D2,MCF_PCI_PCICAR
#else
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
#endif
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_write_config_byte
.write_local_config_byte:
	ext.l D1
	cmp.l #LAST_LOCAL_REGISTER,D1
	bcc.s .bad_register_write_config_byte
	bsr write_local_config_byte
	bra.s .end_write_config_byte	
.bad_register_write_config_byte:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	bra.s .end_write_config_byte
.bad_handle_write_config_byte:
	moveq #PCI_BAD_HANDLE,D0
.end_write_config_byte:
	move.l (SP)+,D4
	move.l (SP)+,D3
	rts

_write_config_word:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // PCI register
	move.w 8(A0),D2          // data to write

write_config_word:
	move.l D3,-(SP)
	move.l D4,-(SP)
	btst #0,D1               // PCI register       
	bne .bad_register_write_config_word
	move.l D0,D3
	ext.l D0                 // handle
	bmi .bad_handle_write_config_word
	beq .write_local_config_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_write_config_word
	swap D3
	ext.l D3                 // function
	bmi .bad_handle_write_config_word
	cmp.l #PCI_MAX_FUNCTION,D3
	bcc.s .bad_handle_write_config_word
	moveq #2,D4
	and.l D1,D4
	move.l D4,-(SP)
	asl.l #8,D3              // shift function number into place
	or.l D3,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D3
	move.b (A0,D0.l),D3
	moveq #11,D0
	asl.l D0,D3              // Device Number
	or.l D3,D1
	move.l D1,-(SP)
	move.l D2,-(SP)
	move.l D1,D2
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif
	move.l (SP)+,D2
	lea PCI_IO_OFFSET,A0
//#ifndef BIG_ENDIAN
#ifdef COLDFIRE
	moveq #0,D1
	move.w D2,D1
	lsr.l #8,D1
	asl.l #8,D2
	or.l D1,D2               // data to write
#else
	ror.w #8,D2              // data to write
#endif /* COLDFIRE */
//#endif
	move.l 4(SP),D1
	move.w D2,(A0,D1.l)
	move.l (SP)+,D2
	addq.l #4,SP
#ifdef COLDFIRE
	move.l D2,MCF_PCI_PCICAR
#else
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
#endif
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_write_config_word
.write_local_config_word:
	ext.l D1
	cmp.l #LAST_LOCAL_REGISTER,D1
	bcc.s .bad_register_write_config_word
	bsr write_local_config_word
	bra.s .end_write_config_word	
.bad_register_write_config_word:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	bra.s .end_write_config_word
.bad_handle_write_config_word:
	moveq #PCI_BAD_HANDLE,D0
.end_write_config_word:
	move.l (SP)+,D4
	move.l (SP)+,D3
	rts
	
_write_config_longword:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // PCI register
	move.l 8(A0),D2          // data to write
	
write_config_longword:
	move.l D3,-(SP)
	moveq #3,D3
	and.l D1,D3              // PCI register
	bne .bad_register_write_config_longword
	move.l D0,D3
	ext.l D0                 // handle
	bmi .bad_handle_write_config_longword
	beq .write_local_config_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_write_config_longword
	swap D3
	ext.l D3                 // function
	bmi .bad_handle_write_config_longword
	cmp.l #PCI_MAX_FUNCTION,D3
	bcc.s .bad_handle_write_config_longword
	asl.l #8,D3              // shift function number in place
	or.l D3,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D3
	move.b (A0,D0.l),D3
	moveq #11,D0
	asl.l D0,D3              // Device Number
	or.l D3,D1
	move.l D1,-(SP)
	move.l D2,-(SP)
	move.l D1,D2
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif
	move.l (SP)+,D2
	lea PCI_IO_OFFSET,A0
//#ifndef BIG_ENDIAN
#ifdef COLDFIRE
	move.l D2,D0
	lsr.l #8,D0
	asl.l #8,D2
	and.l #0x00FF00FF,D0
	and.l #0xFF00FF00,D2
	or.l D0,D2
	swap D2
#else
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
#endif /* COLDFIRE */
//#endif
	move.l D2,(A0)
	move.l (SP)+,D2
#ifdef COLDFIRE
	move.l D2,MCF_PCI_PCICAR
#else
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
#endif
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_write_config_longword
.write_local_config_longword:
	ext.l D1
	cmp.l #LAST_LOCAL_REGISTER,D1
	bcc.s .bad_register_write_config_longword
	bsr write_local_config_longword
	bra.s .end_write_config_longword	
.bad_register_write_config_longword:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	bra.s .end_write_config_longword
.bad_handle_write_config_longword:
	moveq #PCI_BAD_HANDLE,D0
.end_write_config_longword:
	move.l (SP)+,D3
	rts

_hook_interrupt:
	
	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 10(A0),A1         // parameter for interrupt handler
	move.l 6(A0),A0          // pointer to interrupt handler

hook_interrupt:
	move.l A2,-(SP)
	move.l D0,D1             // handle
	move.l D0,D2
	swap D2                  // function
	ext.l D0
	bmi.s .bad_handle_hook_interrupt
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_hook_interrupt
	ext.l D2                 // function
	bmi.s .bad_handle_hook_interrupt
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc.s .bad_handle_hook_interrupt
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_hook_interrupt // not found
	add.l #PCI_COOKIE_SIZE + PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A2             // Status-Descriptors
	move.w D1,D0             // handle
	ext.l D0
	mulu #PCI_MAX_FUNCTION,D1
	add.l D2,D1
	mulu #PCI_DEV_DES_SIZE,D1
	tst.l PCI_DEV_DES_HANDLER(A2,D1.l)
	bne.s .general_error_hook_interrupt
	tst.l PCI_DEV_DES_PARAMETER(A2,D1.l)
	bne.s .general_error_hook_interrupt
	move.l A0,PCI_DEV_DES_HANDLER(A2,D1.l)   // routine
	move.l A1,PCI_DEV_DES_PARAMETER(A2,D1.l) // parameter
	move.l PCI_DEV_DES_START_IRQ(A2,D1.l),D1
	beq.s .enable_hook_interrupt
	move.l D1,A2
	jsr (A2)
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_hook_interrupt
.enable_hook_interrupt:
	bsr enable_interrupt     // handle
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_hook_interrupt
.general_error_hook_interrupt:
	moveq #PCI_GENERAL_ERROR,D0
	bra.s .end_hook_interrupt
.bad_handle_hook_interrupt:
	moveq #PCI_BAD_HANDLE,D0
.end_hook_interrupt:
	move.l (SP)+,A2
	rts
	
_unhook_interrupt:
	
	move.l 2(A0),D0          // function(H)/handle(L)
	
unhook_interrupt:

	move.w D0,D1             // handle
	move.l D0,D2
	swap D2                  // function
	ext.l D0
	bmi.s .bad_handle_unhook_interrupt
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_unhook_interrupt
	ext.l D2                 // function
	bmi.s .bad_handle_unhook_interrupt
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc.s .bad_handle_unhook_interrupt
	bsr disable_interrupt
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_unhook_interrupt // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A1             // Status-Descriptors
	mulu #PCI_MAX_FUNCTION,D1
	add.l D2,D1
	mulu #PCI_DEV_DES_SIZE,D1
	clr.l PCI_DEV_DES_HANDLER(A1,D1.l)
	clr.l PCI_DEV_DES_PARAMETER(A1,D1.l)
	moveq #PCI_SUCCESSFUL,D0
	rts
.general_error_unhook_interrupt:
	moveq #PCI_GENERAL_ERROR,D0
	bra.s .end_hook_interrupt
.bad_handle_unhook_interrupt:
	moveq #PCI_BAD_HANDLE,D0
	rts

_special_cycle:

	move.w 2(A0),D0          // bus number
	move.l 4(A0),D1          // special cycle data
	
special_cycle:

	moveq #PCI_FUNC_NOT_SUPPORTED,D0
	rts
	
_get_routing:
	
	move.l 2(A0),D0          // function(H)/handle(L)

get_routing:

	ext.l D0                 // handle
	bmi.s .bad_handle_set_routing
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_set_routing
	moveq #PCI_FUNC_NOT_SUPPORTED,D0
	rts
.bad_handle_set_routing:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_set_interrupt:
	
	move.l 2(A0),D0          // function(H)/handle(L)
	move.w 6(A0),D1          // mode

set_interrupt:
	ext.l D0                 // handle
	bmi.s .bad_handle_set_interrupt
#ifndef COLDFIRE
	beq.s .local_set_interrupt
#endif
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_set_interrupt
	moveq #PCI_FUNC_NOT_SUPPORTED,D0
	rts
#ifndef COLDFIRE
.local_set_interrupt:
	moveq #0,D2
	btst #0,D1               // DMA Interrupt
	beq.s .no_dma_set_interrupt
	bset #18,D2              // Local DMA Channel 0 Interrut Enable
	bset #16,D2              // Local Interrupt Output Enable
.no_dma_set_interrupt:
	btst #1,D1               // Mailbox
	beq.s .no_mailbox_set_interrupt
	bset #3,D2               // Mailbox Interrupt Enable
	bset #16,D2              // Local Interrupt Output Enable
.no_mailbox_set_interrupt:
	bset #8,D2               // PCI Interrupt enable
	move.l #INTCSR,D1        // Interrupt Control/Status
	bsr write_local_config_longword
	rts
#endif
.bad_handle_set_interrupt:
	moveq #PCI_BAD_HANDLE,D0
	rts

_get_resource:

	move.l 2(A0),D0          // function(H)/handle(L)

get_resource:

	move.l D0,D1             // slot
	swap D1                  // function
	ext.l D0
	bmi.s .bad_handle_get_resource
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_get_resource
	ext.l D1                 // function
	bmi.s .bad_handle_get_resource
	cmp.l #PCI_MAX_FUNCTION,D1
	bcc.s .bad_handle_get_resource	
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,D1
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_get_resource // not found
	mulu #PCI_RSC_DESC_TOTALSIZE,D1
	add.l #PCI_COOKIE_SIZE,D0 // Ressource-Descriptors
	add.l D1,D0	
	rts
.general_error_get_resource:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_get_resource:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_get_card_used:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),A0          // address
	
get_card_used:

	move.l D0,D1             // handle
	swap D1                  // function
	ext.l D0
	bmi.s .bad_handle_get_card_used
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_get_card_used
	ext.l D1
	bmi.s .bad_handle_get_card_used
	cmp.l #PCI_MAX_FUNCTION,D1
	bcc.s .bad_handle_get_card_used
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,D1
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_get_card_used // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A1             // Status-Descriptors
	mulu #PCI_DEV_DES_SIZE,D1
	move.l PCI_DEV_DES_CALLBACK(A1,D1.l),(A0) // address
	move.l PCI_DEV_DES_STATUS(A1,D1.l),D0     // status
	rts
.general_error_get_card_used:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_get_card_used:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_set_card_used:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),A0          // callback
	
set_card_used:

	move.l D0,D1             // handle
	swap D1                  // function
	ext.l D0
	bmi.s .bad_handle_set_card_used
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_set_card_used
	ext.l D1
	bmi.s .bad_handle_set_card_used
	cmp.l #PCI_MAX_FUNCTION,D1
	bcc.s .bad_handle_set_card_used
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,D1
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_set_card_used // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A1             // Status-Descriptors
	mulu #PCI_RSC_DESC_SIZE,D1
	move.l A0,D0             // callback, 0: card is free
	beq.s .set_status_set_card_used
	cmp.l #1,D0              // callback, 2: card in use
	beq.s .set_status_set_card_used
	cmp.l #3,D0              // callback, 3: card in use
	beq.s .set_status_set_card_used
.callback_entry_set_card_used:
	move.l A0,PCI_DEV_DES_CALLBACK(A1,D1.l)
	move.l #2,D0
	move.l D0,PCI_DEV_DES_STATUS(A1,D1.l)
	moveq #PCI_SUCCESSFUL,D0
	rts
.set_status_set_card_used:
	clr.l PCI_DEV_DES_CALLBACK(A1,D1.l)
	move.l A0,PCI_DEV_DES_STATUS(A1,D1.l) // status
	moveq #PCI_SUCCESSFUL,D0
	rts
.general_error_set_card_used:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_set_card_used:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_mem_byte:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory
	
read_mem_byte:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A2,-(SP)
	move.l D0,A2
#endif
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_mem_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_read_mem_byte
	ext.l D2
	bmi .bad_handle_read_mem_byte
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc .bad_handle_read_mem_byte
	lea PCI_MEMORY_OFFSET,A1
#ifdef BIG_ENDIAN
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D2
	eor.l D2,D1              // offset
#endif
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.read_mem_byte_retry:
	move.b (A0),D0
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .read_mem_byte_ok2
	lea debug35(PC),A0
	bra.s .read_mem_byte_display	
.read_mem_byte_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_read_mem_byte
	lea debug39(PC),A0
	bra.s .read_mem_byte_display2
.no_master_abort_read_mem_byte:
	move.l A2,D0
	bsr check_parity_target
	bpl.s .read_mem_byte_ok
	lea debug37(PC),A0
.read_mem_byte_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_byte
	lea debug35b(PC),A0
.read_mem_byte_display2:
	bsr debug_display_string
	move.l A1,D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	bsr wait_key
	bne.s .read_mem_byte_bad
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.b (A1,D1.l),(A0) 
	bra.s .read_mem_byte_retry
.read_mem_byte_bad:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
	moveq #PCI_PARITY_ERROR,D0
	rts
.read_mem_byte_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_read_mem_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_mem_word:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory

read_mem_word:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A2,-(SP)
	move.l D0,A2
#endif
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_mem_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_read_mem_word
	ext.l D2
	bmi .bad_handle_read_mem_word
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc .bad_handle_read_mem_word
	btst #0,D1
	bne .bad_alignment_read_mem_word
	lea PCI_MEMORY_OFFSET,A1
#ifdef BIG_ENDIAN
	move.w (A1,D1.l),(A0)    // pointer to data in memory
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D2
	eor.l D2,D1              // address to access (in PCI memory address space)
#endif
.read_mem_word_retry:
	move.w (A1,D1.l),D0
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	moveq #0,D1
	move.w D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	or.l D1,D0
#else
	ror.w #8,D0
#endif /* COLDFIRE */
#endif
	move.w D0,(A0)           // pointer to data in memory
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.w (A0),D0
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .read_mem_word_ok2
	lea debug35(PC),A0
	bra.s .read_mem_word_display	
.read_mem_word_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_read_mem_word
	lea debug39(PC),A0
	bra.s .read_mem_word_display2
.no_master_abort_read_mem_word:
	move.l A2,D0
	bsr check_parity_target
	bpl.s .read_mem_word_ok
	lea debug37(PC),A0
.read_mem_word_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_word
	lea debug35b(PC),A0
.read_mem_word_display2:
	bsr debug_display_string
	move.l A1,D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .read_mem_word_bad
	move.l (SP)+,A0
	move.l (SP)+,D0
	bra.s .read_mem_word_retry
.read_mem_word_bad:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
	moveq #PCI_PARITY_ERROR,D0
	rts
.read_mem_word_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_read_mem_word:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_read_mem_word:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_mem_longword:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory
	
read_mem_longword:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A2,-(SP)
	move.l D0,A2
#endif
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_mem_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_read_mem_longword
	ext.l D2
	bmi .bad_handle_read_mem_longword
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc .bad_handle_read_mem_longword
	moveq #3,D0
	and.l D1,D0
	bne .bad_alignment_read_mem_longword
	lea PCI_MEMORY_OFFSET,A1
.read_mem_longword_retry:
#ifdef BIG_ENDIAN
	move.l (A1,D1.l),(A0)    // pointer to data in memory
#else
	move.l (A1,D1.l),D0      // + address to access (in PCI memory address space)
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	move.l D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	and.l #0x00FF00FF,D1
	and.l #0xFF00FF00,D0
	or.l D1,D0
	swap D0
#else
	ror.w #8,D0
	swap D0
	ror.w #8,D0
#endif /* COLDFIRE */
#endif
	move.l D0,(A0)           // pointer to data in memory
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l (A0),D0
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .read_mem_longword_ok2
	lea debug35(PC),A0
	bra.s .read_mem_longword_display	
.read_mem_longword_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_read_mem_longword
	lea debug39(PC),A0
	bra.s .read_mem_longword_display2
.no_master_abort_read_mem_longword:
	move.l A2,D0
	bsr check_parity_target
	bpl.s .read_mem_longword_ok
	lea debug37(PC),A0
.read_mem_longword_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_long
	lea debug35b(PC),A0
.read_mem_longword_display2:
	bsr debug_display_string
	move.l A1,D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .read_mem_longword_bad
	move.l (SP)+,A0
	move.l (SP)+,D0
	bra.s .read_mem_longword_retry
.read_mem_longword_bad:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
	moveq #PCI_PARITY_ERROR,D0
	rts
.read_mem_longword_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_read_mem_longword:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_read_mem_longword:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_fast_read_mem_byte:

	move.l 6(A0),D1          // address to access (in PCI memory address space)

fast_read_mem_byte:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.b (A0,D1.l),D0
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
#endif
	move.b (A0,D1.l),D0      // read data
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.fast_read_mem_byte_retry:
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .fast_read_mem_byte_ok2
	lea debug35(PC),A0
	bra.s .fast_read_mem_byte_display	
.fast_read_mem_byte_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_fast_read_mem_byte
	lea debug39(PC),A0
	bra.s .fast_read_mem_byte_display2
.no_master_abort_fast_read_mem_byte:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .fast_read_mem_byte_ok
	lea debug37(PC),A0
.fast_read_mem_byte_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_byte
	lea debug35b(PC),A0
.fast_read_mem_byte_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .fast_read_mem_byte_ok
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.b (A0,D1.l),D0 
	bra.s .fast_read_mem_byte_retry
.fast_read_mem_byte_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A1
#endif
#endif
#endif
	rts
	
_fast_read_mem_word:

	move.l 6(A0),D1          // address to access (in PCI memory address space)

fast_read_mem_word:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.w (A0,D1.l),D0
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
#endif
.fast_read_mem_word_retry:
	move.w (A0,D1.l),D0
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	moveq #0,D1
	move.w D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	or.l D1,D0
#else
	ror.w #8,D0              // read data
#endif
#endif
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .fast_read_mem_word_ok2
	lea debug35(PC),A0
	bra.s .fast_read_mem_word_display	
.fast_read_mem_word_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_fast_read_mem_word
	lea debug39(PC),A0
	bra.s .fast_read_mem_word_display2
.no_master_abort_fast_read_mem_word:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .fast_read_mem_word_ok
	lea debug37(PC),A0
.fast_read_mem_word_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_word
	lea debug35b(PC),A0
.fast_read_mem_word_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .fast_read_mem_word_ok
	move.l (SP)+,A0
	move.l (SP)+,D0
	bra.s .fast_read_mem_word_retry
.fast_read_mem_word_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A1
#endif
#endif
#endif
	rts
	
_fast_read_mem_longword:

	move.l 6(A0),D1          // address to access (in PCI memory address space)

fast_read_mem_longword:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_MEMORY_OFFSET,A0
.fast_read_mem_longword_retry:
#ifdef BIG_ENDIAN
	move.l (A0,D1.l),D0
#else
	move.l (A0,D1.l),D0      // + address to access (in PCI memory address space)
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	move.l D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	and.l #0x00FF00FF,D1
	and.l #0xFF00FF00,D0
	or.l D1,D0
	swap D0                  // read data
#else
	ror.w #8,D0
	swap D0
	ror.w #8,D0              // read data
#endif /* COLDFIRE */
#endif
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .fast_read_mem_longword_ok2
	lea debug35(PC),A0
	bra.s .fast_read_mem_longword_display	
.fast_read_mem_longword_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_fast_read_mem_longword
	lea debug39(PC),A0
	bra.s .fast_read_mem_longword_display2
.no_master_abort_fast_read_mem_longword:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .fast_read_mem_longword_ok
	lea debug37(PC),A0
.fast_read_mem_longword_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_long
	lea debug35b(PC),A0
.fast_read_mem_longword_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .fast_read_mem_longword_ok
	move.l (SP)+,A0
	move.l (SP)+,D0
	bra.s .fast_read_mem_longword_retry
.fast_read_mem_longword_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A1
#endif
#endif
#endif
	rts

_write_mem_byte:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.w 10(A0),D2         // data to write
	
// write_mem_byte:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_mem_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_mem_byte
	move.l A1,D0
	swap D0                  // function
	ext.l D0
	bmi.s .bad_handle_write_mem_byte
	cmp.l #PCI_MAX_FUNCTION,D0
	bcc.s .bad_handle_write_mem_byte
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
#endif
	move.b D2,(A0,D1.l)      // data to write
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_mem_byte_retry2:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_mem_byte2
	lea debug39(PC),A0
	bra.s .write_mem_byte_display2
.no_master_abort_write_mem_byte2:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_mem_byte_ok2
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_byte
	lea debug35b(PC),A0
.write_mem_byte_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_mem_byte_bad2
	move.l (SP)+,A0
	move.b D2,(A0,D1.l)
	bra.s .write_mem_byte_retry2
.write_mem_byte_bad2:
	move.l (SP)+,A0
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_mem_byte_ok2:
	move.l (SP)+,A0
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_write_mem_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
write_mem_byte: // faster for X86EMU

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
#endif
	move.b D2,(A0,D1.l)      // data to write
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_mem_byte_retry:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_mem_byte
	lea debug39(PC),A0
	bra.s .write_mem_byte_display
.no_master_abort_write_mem_byte:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_mem_byte_ok
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_byte
	lea debug35b(PC),A0
.write_mem_byte_display:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_mem_byte_bad
	move.l (SP)+,A0
	move.b D2,(A0,D1.l)
	bra.s .write_mem_byte_retry 
.write_mem_byte_bad:
	move.l (SP)+,A0
	move.l (SP)+,A1
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_mem_byte_ok:
	move.l (SP)+,A0
	move.l (SP)+,A1
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

_write_mem_word:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.w 10(A0),D2         // data to write
	
// write_mem_word:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_mem_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_write_mem_word
	move.l A1,D0
	swap D0                  // function
	ext.l D0
	bmi.s .bad_handle_write_mem_word
	cmp.l #PCI_MAX_FUNCTION,D0
	bcc.s .bad_handle_write_mem_word
	btst #0,D1
	bne.s .bad_alignment_write_mem_word
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.w D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	moveq #0,D0
	move.w D2,D0
	lsr.l #8,D0
	asl.l #8,D2
	or.l D0,D2               // data to write
#else
	ror.w #8,D2              // data to write
#endif /* COLDFIRE */
#endif
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
#endif
	move.w D2,(A0,D1.l)
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_mem_word_retry2:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_mem_word2
	lea debug39(PC),A0
	bra.s .write_mem_word_display2
.no_master_abort_write_mem_word2:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_mem_word_ok2
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_word
	lea debug35b(PC),A0
.write_mem_word_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_mem_word_bad2
	move.l (SP)+,A0
	move.w D2,(A0,D1.l)	
	bra.s .write_mem_word_retry2
.write_mem_word_bad2:
	move.l (SP)+,A0
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_mem_word_ok2:
	move.l (SP)+,A0
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_write_mem_word:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_write_mem_word:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
write_mem_word: // faster for X86EMU

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.w D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	moveq #0,D0
	move.w D2,D0
	lsr.l #8,D0
	asl.l #8,D2
	or.l D0,D2               // data to write
#else
	ror.w #8,D2              // data to write
#endif /* COLDFIRE */
#endif
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
#endif
	move.w D2,(A0,D1.l)
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_mem_word_retry:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_mem_word
	lea debug39(PC),A0
	bra.s .write_mem_word_display
.no_master_abort_write_mem_word:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_mem_word_ok
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_word
	lea debug35b(PC),A0
.write_mem_word_display:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_mem_word_bad
	move.l (SP)+,A0
	move.w D2,(A0,D1.l)	
	bra.s .write_mem_word_retry
.write_mem_word_bad:
	move.l (SP)+,A0
	move.l (SP)+,A1
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_mem_word_ok:
	move.l (SP)+,A0
	move.l (SP)+,A1
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
	
_write_mem_longword:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),D2         // data to write

// write_mem_longword:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_mem_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_write_mem_longword
	move.l A1,D0
	swap D0                  // function
	ext.l D0
	bmi .bad_handle_write_mem_longword
	cmp.l #PCI_MAX_FUNCTION,D0
	bcc.s .bad_handle_write_mem_longword
	moveq #3,D0
	and.l D1,D0
	bne.s .bad_alignment_write_mem_longword
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.l D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	move.l D2,D0
	lsr.l #8,D0
	asl.l #8,D2
	and.l #0x00FF00FF,D0
	and.l #0xFF00FF00,D2
	or.l D0,D2
	swap D2
#else
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
#endif /* COLDFIRE */
#endif
	move.l D2,(A0,D1.l)      // + address to access (in PCI memory address space)
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_mem_longword_retry2:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_mem_longword2
	lea debug39(PC),A0
	bra.s .write_mem_longword_display2
.no_master_abort_write_mem_longword2:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_mem_longword_ok2
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
	lea debug35b(PC),A0
.write_mem_longword_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_mem_longword_bad2
	move.l (SP)+,A0
	move.l D2,(A0,D1.l)	
	bra.s .write_mem_longword_retry2
.write_mem_longword_bad2:
	move.l (SP)+,A0
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_mem_longword_ok2:
	move.l (SP)+,A0
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_write_mem_longword:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_write_mem_longword:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
write_mem_longword: // faster for X86EMU

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.l D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	move.l D2,D0
	lsr.l #8,D0
	asl.l #8,D2
	and.l #0x00FF00FF,D0
	and.l #0xFF00FF00,D2
	or.l D0,D2
	swap D2
#else
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
#endif /* COLDFIRE */
#endif
	move.l D2,(A0,D1.l)      // + address to access (in PCI memory address space)
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_mem_longword_retry:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_mem_longword
	lea debug39(PC),A0
	bra.s .write_mem_longword_display
.no_master_abort_write_mem_longword:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_mem_longword_ok
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
	lea debug35b(PC),A0
.write_mem_longword_display:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_mem_longword_bad
	move.l (SP)+,A0
	move.l D2,(A0,D1.l)	
	bra.s .write_mem_longword_retry
.write_mem_longword_bad:
	move.l (SP)+,A0
	move.l (SP)+,A1
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_mem_longword_ok:
	move.l (SP)+,A0
	move.l (SP)+,A1
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

_read_io_byte:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.l 10(A0),A0         // pointer to data in memory

read_io_byte:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A2,-(SP)
	move.l D0,A2
#endif
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_io_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_read_io_byte
	ext.l D2
	bmi .bad_handle_read_io_byte
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc .bad_handle_read_io_byte
	lea PCI_IO_OFFSET,A1
#ifdef BIG_ENDIAN
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.read_io_byte_retry:
	move.b (A0),D0
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .read_io_byte_ok2
	lea debug35(PC),A0
	bra.s .read_io_byte_display	
.read_io_byte_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_read_io_byte
	lea debug39(PC),A0
	bra.s .read_io_byte_display2
.no_master_abort_read_io_byte:
	move.l A2,D0
	bsr check_parity_target
	bpl.s .read_io_byte_ok
	lea debug37(PC),A0
.read_io_byte_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_byte
	lea debug35b(PC),A0
.read_io_byte_display2:
	bsr debug_display_string
	move.l A1,D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .read_io_byte_bad
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.b (A1,D1.l),(A0)	
	bra.s .read_io_byte_retry
.read_io_byte_bad:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
	moveq #PCI_PARITY_ERROR,D0
	rts
.read_io_byte_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_read_io_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_io_word:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.l 10(A0),A0         // pointer to data in memory
	
read_io_word:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A2,-(SP)
	move.l D0,A2
#endif
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_io_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_read_io_word
	ext.l D2
	bmi .bad_handle_read_io_word
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc .bad_handle_read_io_word
	btst #0,D1
	bne .bad_alignment_read_io_word
	lea PCI_IO_OFFSET,A1
#ifdef BIG_ENDIAN
	move.w (A1,D1.l),(A0)    // pointer to data in memory
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
.read_io_word_retry:
	move.w (A1,D1.l),D0
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	moveq #0,D1
	move.w D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	or.l D1,D0
#else
	ror.w #8,D0
#endif /* COLDFIRE */
#endif
	move.w D0,(A0)           // pointer to data in memory
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.w (A0),D0
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .read_io_word_ok2
	lea debug35(PC),A0
	bra.s .read_io_word_display	
.read_io_word_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_read_io_word
	lea debug39(PC),A0
	bra.s .read_io_word_display2
.no_master_abort_read_io_word:
	move.l A2,D0
	bsr check_parity_target
	bpl.s .read_io_word_ok
	lea debug37(PC),A0
.read_io_word_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_word
	lea debug35b(PC),A0
.read_io_word_display2:
	bsr debug_display_string
	move.l A1,D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .read_io_word_bad
	move.l (SP)+,A0
	move.l (SP)+,D0
	bra.s .read_io_word_retry
.read_io_word_bad:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
	moveq #PCI_PARITY_ERROR,D0
	rts
.read_io_word_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_read_io_word:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_read_io_word:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_io_longword:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory

read_io_longword:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A2,-(SP)
	move.l D0,A2
#endif
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_io_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_read_io_longword
	ext.l D2
	bmi .bad_handle_read_io_longword
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc .bad_handle_read_io_longword
	moveq #3,D0
	and.l D1,D0
	bne .bad_alignment_read_io_longword
	lea PCI_IO_OFFSET,A1
.read_io_longword_retry:
#ifdef BIG_ENDIAN
	move.l (A1,D1.l),(A0)    // pointer to data in memory
#else
	move.l (A1,D1.l),D0      // + address to access (in PCI I/O address space)
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	move.l D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	and.l #0x00FF00FF,D1
	and.l #0xFF00FF00,D0
	or.l D1,D0
	swap D0
#else
	ror.w #8,D0
	swap D0
	ror.w #8,D0
#endif /* COLDFIRE */
#endif
	move.l D0,(A0)           // pointer to data in memory
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l (A0),D0
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .read_io_longword_ok2
	lea debug35(PC),A0
	bra.s .read_io_longword_display	
.read_io_longword_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_read_io_longword
	lea debug39(PC),A0
	bra.s .read_io_longword_display2
.no_master_abort_read_io_longword:
	move.l A2,D0
	bsr check_parity_target
	bpl.s .read_io_longword_ok
	lea debug37(PC),A0
.read_io_longword_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_long
	lea debug35b(PC),A0
.read_io_longword_display2:
	bsr debug_display_string
	move.l A1,D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .read_io_longword_bad
	move.l (SP)+,A0
	move.l (SP)+,D0
	bra.s .read_io_longword_retry
.read_io_longword_bad:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
	moveq #PCI_PARITY_ERROR,D0
	rts
.read_io_longword_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A2
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_read_io_longword:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_read_io_longword:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_fast_read_io_byte:

	move.l 6(A0),D1          // address to access (in PCI I/O address space)

fast_read_io_byte:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.b (A0,D1.l),D0
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
	move.b (A0,D1.l),D0      // read data
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.fast_read_io_byte_retry:
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .fast_read_io_byte_ok2
	lea debug35(PC),A0
	bra.s .fast_read_io_byte_display	
.fast_read_io_byte_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_fast_read_io_byte
	lea debug39(PC),A0
	bra.s .fast_read_io_byte_display2
.no_master_abort_fast_read_io_byte:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .fast_read_io_byte_ok
	lea debug37(PC),A0
.fast_read_io_byte_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_byte
	lea debug35b(PC),A0
.fast_read_io_byte_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .fast_read_io_byte_ok
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.b (A0,D1.l),D0 
	bra.s .fast_read_io_byte_retry 
.fast_read_io_byte_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A1
#endif
#endif
#endif
	rts

_fast_read_io_word:

	move.l 6(A0),D1          // address to access (in PCI I/O address space)

fast_read_io_word:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.w (A0,D1.l),D0
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
.fast_read_io_word_retry:
	move.w (A0,D1.l),D0
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	moveq #0,D1
	move.w D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	or.l D1,D0               // read data
#else
	ror.w #8,D0              // read data
#endif /* COLDFIRE */
#endif
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .fast_read_io_word_ok2
	lea debug35(PC),A0
	bra.s .fast_read_io_word_display	
.fast_read_io_word_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_fast_read_io_word
	lea debug39(PC),A0
	bra.s .fast_read_io_word_display2
.no_master_abort_fast_read_io_word:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .fast_read_io_word_ok
	lea debug37(PC),A0
.fast_read_io_word_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_word
	lea debug35b(PC),A0
.fast_read_io_word_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .fast_read_io_word_ok
	move.l (SP)+,A0
	move.l (SP)+,D0
	bra.s .fast_read_io_word_retry
.fast_read_io_word_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A1
#endif
#endif
#endif
	rts
	
_fast_read_io_longword:

	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	
fast_read_io_longword:

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_IO_OFFSET,A0
.fast_read_io_longword_retry:
#ifdef BIG_ENDIAN
	move.l (A0,D1.l),D0
#else
	move.l (A0,D1.l),D0      // + address to access (in PCI I/O address space)
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	move.l D0,D1
	lsr.l #8,D1
	asl.l #8,D0
	and.l #0x00FF00FF,D1
	and.l #0xFF00FF00,D0
	or.l D1,D0
	swap D0                  // read data
#else
	ror.w #8,D0
	swap D0
	ror.w #8,D0              // read data
#endif /* COLDFIRE */
#endif
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	bsr check_parity
	bpl.s .fast_read_io_longword_ok2
	lea debug35(PC),A0
	bra.s .fast_read_io_longword_display	
.fast_read_io_longword_ok2:
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_fast_read_io_longword
	lea debug39(PC),A0
	bra.s .fast_read_io_longword_display2
.no_master_abort_fast_read_io_longword:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .fast_read_io_longword_ok
	lea debug37(PC),A0
.fast_read_io_longword_display:
	bsr debug_display_string
	move.l 4(SP),D0
	bsr debug_hex_long
	lea debug35b(PC),A0
.fast_read_io_longword_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .fast_read_io_longword_ok
	move.l (SP)+,A0
	move.l (SP)+,D0
	bra.s .fast_read_io_longword_retry
.fast_read_io_longword_ok:
	move.l (SP)+,A0
	move.l (SP)+,D0
	move.l (SP)+,A1
#endif
#endif
#endif
	rts
	
_write_io_byte:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.w 10(A0),D2         // data to write
	
// write_io_byte:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_io_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_write_io_byte
	move.l A1,D0
	swap D0                 // function
	ext.l D0
	bmi.s .bad_handle_write_io_byte
	cmp.l #PCI_MAX_FUNCTION,D0
	bcc.s .bad_handle_write_io_byte
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
	move.b D2,(A0,D1.l)      // data to write
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_io_byte_retry2:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_io_byte2
	lea debug39(PC),A0
	bra.s .write_io_byte_display2
.no_master_abort_write_io_byte2:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_io_byte_ok2
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_byte
	lea debug35b(PC),A0
.write_io_byte_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_io_byte_bad2
	move.l (SP)+,A0
	move.b D2,(A0,D1.l)
	bra.s .write_io_byte_retry2
.write_io_byte_bad2:
	move.l (SP)+,A0
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_io_byte_ok2:
	move.l (SP)+,A0
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_write_io_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts

write_io_byte: // faster for X86EMU

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
	move.b D2,(A0,D1.l)      // data to write
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_io_byte_retry:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_io_byte
	lea debug39(PC),A0
	bra.s .write_io_byte_display
.no_master_abort_write_io_byte:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_io_byte_ok
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_byte
	lea debug35b(PC),A0
.write_io_byte_display:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_io_byte_bad
	move.l (SP)+,A0
	move.b D2,(A0,D1.l)
	bra.s .write_io_byte_retry
.write_io_byte_bad:
	move.l (SP)+,A0
	move.l (SP)+,A1
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_io_byte_ok:
	move.l (SP)+,A0
	move.l (SP)+,A1
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

_write_io_word:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.w 10(A0),D2         // data to write

// write_io_word:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_io_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_write_io_word
	move.l A1,D0
	swap D0                 // function
	ext.l D0
	bmi.s .bad_handle_write_io_word
	cmp.l #PCI_MAX_FUNCTION,D0
	bcc.s .bad_handle_write_io_word
	btst #0,D1
	bne.s .bad_alignment_write_io_word
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.w D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	moveq #0,D0
	move.w D2,D0
	lsr.l #8,D0
	asl.l #8,D2
	or.l D0,D2               // data to write
#else
	ror.w #8,D2              // data to write
#endif /* COLDFIRE */
#endif
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
	move.w D2,(A0,D1.l)
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_io_word_retry2:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_io_word2
	lea debug39(PC),A0
	bra.s .write_io_word_display2
.no_master_abort_write_io_word2:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_io_word_ok2
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_word
	lea debug35b(PC),A0
.write_io_word_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_io_word_bad2
	move.l (SP)+,A0
	move.w D2,(A0,D1.l)
	bra.s .write_io_word_retry2
.write_io_word_bad2:
	move.l (SP)+,A0
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_io_word_ok2:
	move.l (SP)+,A0
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_write_io_word:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_write_io_word:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
write_io_word: // faster for X86EMU

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.w D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	moveq #0,D0
	move.w D2,D0
	lsr.l #8,D0
	asl.l #8,D2
	or.l D0,D2               // data to write
#else
	ror.w #8,D2              // data to write
#endif /* COLDFIRE */
#endif
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
	move.w D2,(A0,D1.l)
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_io_word_retry:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_io_word
	lea debug39(PC),A0
	bra.s .write_io_word_display
.no_master_abort_write_io_word:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_io_word_ok
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_word
	lea debug35b(PC),A0
.write_io_word_display:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_io_word_bad
	move.l (SP)+,A0
	move.w D2,(A0,D1.l)
	bra.s .write_io_word_retry
.write_io_word_bad:
	move.l (SP)+,A0
	move.l (SP)+,A1
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_io_word_ok:
	move.l (SP)+,A0
	move.l (SP)+,A1
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

_write_io_longword:

	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.l 10(A0),D2         // data to write

// write_io_longword:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_io_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc .bad_handle_write_io_longword
	move.l A1,D0
	swap D0                 // function
	ext.l D0
	bmi .bad_handle_write_io_longword
	cmp.l #PCI_MAX_FUNCTION,D0
	bcc.s .bad_handle_write_io_longword
	moveq #3,D0
	and.l D1,D0
	bne.s .bad_alignment_write_io_longword
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.l D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	move.l D2,D0
	lsr.l #8,D0
	asl.l #8,D2
	and.l #0x00FF00FF,D0
	and.l #0xFF00FF00,D2
	or.l D0,D2
	swap D2
#else
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
#endif /* COLDFIRE */
#endif
	move.l D2,(A0,D1.l)      // + address to access (in PCI I/O address space)
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_io_longword_retry2:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_io_longword2
	lea debug39(PC),A0
	bra.s .write_io_longword_display2
.no_master_abort_write_io_longword2:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_io_longword_ok2
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
	lea debug35b(PC),A0
.write_io_longword_display2:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_io_longword_bad2
	move.l (SP)+,A0
	move.l D2,(A0,D1.l)  		
	bra.s .write_io_longword_retry2
.write_io_longword_bad2:
	move.l (SP)+,A0
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_io_longword_ok2:
	move.l (SP)+,A0
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_write_io_longword:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_write_io_longword:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
write_io_longword: // faster for X86EMU

#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
	move.l A1,-(SP)
	move.l D0,A1
#endif
#endif
#endif
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.l D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_LANE_SWAPPED
#ifdef COLDFIRE
	move.l D2,D0
	lsr.l #8,D0
	asl.l #8,D2
	and.l #0x00FF00FF,D0
	and.l #0xFF00FF00,D2
	or.l D0,D2
	swap D2
#else
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
#endif /* COLDFIRE */
#endif
	move.l D2,(A0,D1.l)      // + address to access (in PCI I/O address space)
#endif
#ifndef COLDFIRE
#ifdef CHECK_PARITY
#ifdef DEBUG
.write_io_longword_retry:
	move.l A0,-(SP)
	bsr check_parity
	and.l #0x28000000,D0     // Master Target Abort
	beq.s .no_master_abort_write_io_longword
	lea debug39(PC),A0
	bra.s .write_io_longword_display
.no_master_abort_write_io_longword:
	move.l A1,D0
	bsr check_parity_target
	bpl.s .write_io_longword_ok
	lea debug38(PC),A0
	bsr debug_display_string
	move.l D2,D0
	bsr debug_hex_long
	lea debug35b(PC),A0
.write_io_longword_display:
	bsr debug_display_string
	move.l (SP),D0
	add.l D1,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	bsr wait_key
	bne.s .write_io_longword_bad
	move.l (SP)+,A0
	move.l D2,(A0,D1.l)  		
	bra.s .write_io_longword_retry
.write_io_longword_bad:
	move.l (SP)+,A0
	move.l (SP)+,A1
	moveq #PCI_PARITY_ERROR,D0
	rts
.write_io_longword_ok:
	move.l (SP)+,A0
	move.l (SP)+,A1
#endif
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

_get_machine_id:
get_machine_id:

	// 0: Medusa/Hades
	// 1: Milan
	// 2: PAK/Panther
	// 3: Aranym
	moveq #0,D0              // no ID available
	rts

_get_pagesize:
get_pagesize:

	moveq #0,D0              // paging not active
	rts
	
_virt_to_bus:
	
	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // address in virtual CPU space 
	move.l 10(A0),A0         // ptr
	
virt_to_bus:

	move.l D0,D2
	swap D2                 // function
	ext.l D0                 // handle
	bmi.s .bad_handle_virt_to_bus
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_virt_to_bus
	ext.l D2
	bmi.s .bad_handle_virt_to_bus
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc.s .bad_handle_virt_to_bus
	move.l D1,D0             // address in virtual CPU space
	sub.l #PCI_MEMORY_OFFSET,D0
	move.l D0,PCI_CONV_ADDR_ADDR(A0) // PCI bus address
	move.l #PCI_MEMORY_SIZE,D0
	move.l D0,PCI_CONV_ADDR_LEN(A0) // length of contiguous mapped area
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_virt_to_bus:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_bus_to_virt:
	
	move.l 2(A0),D0          // function(H)/handle(L)
	move.l 6(A0),D1          // PCI bus address 
	move.l 10(A0),A0         // ptr

bus_to_virt:

	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi.s .bad_handle_bus_to_virt
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_bus_to_virt
	ext.l D2
	bmi.s .bad_handle_bus_to_virt
	cmp.l #PCI_MAX_FUNCTION,D2
	bcc.s .bad_handle_bus_to_virt
	move.l D1,D0             // PCI bus address 
	add.l #PCI_MEMORY_OFFSET,D0
	move.l D0,PCI_CONV_ADDR_ADDR(A0) // CPU virtual address
	move.l #PCI_MEMORY_SIZE,D0
	move.l D0,PCI_CONV_ADDR_LEN(A0) // length of contiguous mapped area
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_bus_to_virt:
	moveq #PCI_BAD_HANDLE,D0
	rts

_virt_to_phys:

	move.l 2(A0),D0          // address in virtual CPU space  
	move.l 6(A0),A0          // ptr

virt_to_phys:

	move.l D0,PCI_CONV_ADDR_ADDR(A0) // physical CPU virtual address
	clr.l PCI_CONV_ADDR_LEN(A0) // length of contiguous mapped area
	moveq #PCI_SUCCESSFUL,D0
	rts

_phys_to_virt:

	move.l 2(A0),D0          // physical CPU address 
	move.l 6(A0),A0          // ptr

phys_to_virt:

	move.l D0,PCI_CONV_ADDR_ADDR(A0) // CPU virtual address
	clr.l PCI_CONV_ADDR_LEN(A0) // length of contiguous mapped area
	moveq #PCI_SUCCESSFUL,D0
	rts
	
_dma_setbuffer:

#ifndef COLDFIRE
	move.l 10(A0),-(SP)      // Transfer Size (Bytes)
	move.l 6(A0),-(SP)       // Local Address
	move.l 2(A0),D2          // PCI Address
	move.l #DMAPADR0,D1      // DMA Channel 0 PCI Address
	bsr write_local_config_longword	
	move.l (SP)+,D2          // Local Address
	move.l #DMALADR0,D1      // DMA Channel 0 Local Address
	bsr write_local_config_longword
	move.l (SP)+,D2          // Transfer Size (Bytes)
	move.l #DMASIZ0,D1       // DMA Channel 0 Transfer Size (Bytes
	bsr write_local_config_longword
#endif
	rts
	
_dma_buffoper:

#ifndef COLDFIRE
	move.w 2(A0),D0          // mode
	bmi.s .status_dma_buffoper
	moveq #4,D2              // abort
	ext.l D0                 // stop
	beq.s .cmd_dma_buffoper
	moveq #0,D2
	cmp.l #1,D0              // PCI to Local Bus
	beq.s .direction_dma_buffoper
	cmp.l #2,D0              // Local Bus To PCI
	bne.s .bad_mode_dma_buffoper	
	moveq #8,D2              // Local Bus To PCI
.direction_dma_buffoper:
	move.l #DMADPR0,D1       // DMA Channel 0 Descriptor Pointer
 	bsr write_local_config_longword
	move.l #DMAMODE0,D1      // DMA Channel 0 Mode
 	bsr read_local_config_longword
 	bclr #9,D0               // Block mode
 	move.l D0,D2 	
	move.l #DMAMODE0,D1      // DMA Channel 0 Mode
 	bsr write_local_config_longword
	moveq #3,D2              // start & enable
.cmd_dma_buffoper:
	move.l #DMASCR0,D1       // DMA Channel 0 Command/Status
	bsr write_local_config_byte
.status_dma_buffoper:
	move.l #DMASCR0,D1       // DMA Channel 0 Command/Status
	bsr read_local_config_byte
	moveq #0,D1
	btst #0,D0               // enable
	beq.s .end_dma_buffoper  // no
	btst #4,D0               // done
	bne.s .end_dma_buffoper  // transfer complete
	moveq #1,D1              // busy
.end_dma_buffoper:
	move.l D1,D0             // state	
	rts
.bad_mode_dma_buffoper:
#endif
	moveq #PCI_GENERAL_ERROR,D0
	rts
	
_read_mailbox:

#ifndef COLDFIRE
	move.w 2(A0),D0          // mailbox 0-7
	move.l 4(A0),A0          // pointer to data in memory
	ext.l D0
	cmp.l #8,D0
	bcc.s .bad_register_read_mailbox 
	move.l D0,D1             // mailbox 0-7
	lsl.l #2,D1
	move.l A0,A1
	add.l #MBOX0,D1          // Mailbox Register 0
 	bsr read_local_config_longword
	move.l D0,(A1)           // pointer to data in memory
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_register_read_mailbox:
#endif
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts
	
_write_mailbox:

#ifndef COLDFIRE
	move.w 2(A0),D0          // mailbox 0-7
	move.l 4(A0),D1          // data to write
	ext.l D0
	cmp.l #8,D0
	bcc.s .bad_register_write_mailbox 
	move.l D1,D2             // data to write             
	move.l D0,D1             // mailbox 0-7              
	lsl.l #2,D1
	add.l #MBOX0,D1          // Mailbox Register 0
 	bsr write_local_config_longword
	rts 	
.bad_register_write_mailbox:
#endif
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts

#if 1 // #ifdef COLDFIRE
	
read_local_config_byte:

#ifdef LOCAL_REGISTERS_BIG
	moveq #3,D0
	eor.l D0,D1              // offset
#endif
	lea PCI_LOCAL_CONFIG,A0
	move.b (A0,D1.l),D0      // read data
	rts

read_local_config_word:

#ifdef LOCAL_REGISTERS_BIG
	moveq #2,D0
	eor.l D0,D1              // offset
#endif
	lea PCI_LOCAL_CONFIG,A0
	move.w (A0,D1.l),D0
#ifndef LOCAL_REGISTERS_BIG
	ror.w #8,D0              // read data
#endif
	rts

read_local_config_longword:

	lea PCI_LOCAL_CONFIG,A0
	move.l (A0,D1.l),D0
#ifndef LOCAL_REGISTERS_BIG
	ror.w #8,D0
	swap D0
	ror.w #8,D0              // read data
#endif
	rts

write_local_config_byte:

#ifdef LOCAL_REGISTERS_BIG
	moveq #3,D0
	eor.l D0,D1              // offset
#endif
	lea PCI_LOCAL_CONFIG,A0
	move.b D2,(A0,D1.l)      // data to write
	moveq #PCI_SUCCESSFUL,D0
	rts
	
write_local_config_word:

#ifdef LOCAL_REGISTERS_BIG
	moveq #2,D0
	eor.l D0,D1              // offset
#else
	ror.w #8,D2              // data to write
#endif
	lea PCI_LOCAL_CONFIG,A0
	move.w D2,(A0,D1.l)
	moveq #PCI_SUCCESSFUL,D0
	rts
	
write_local_config_longword:

#ifndef LOCAL_REGISTERS_BIG
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
#endif
	lea PCI_LOCAL_CONFIG,A0
	move.l D2,(A0,D1.l)
	moveq #PCI_SUCCESSFUL,D0
	rts

#else /* ATARI - CTCPI/PLX9054 */

read_local_config_byte:

	lea PCI_LOCAL_CONFIG,A0
	cmp.l #PLX9054_SWAPPED,(A0)
	beq.s .read_local_config_byte_little
	moveq #3,D0
	eor.l D0,D1              // offset
.read_local_config_byte_little:
	move.b (A0,D1.l),D0      // read data
#if 0 // #ifdef DEBUG
	move.l D0,-(SP)
	moveq #0x52,D0
	bsr debug_display_char
	move.l (SP),D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif
	rts

read_local_config_word:

	lea PCI_LOCAL_CONFIG,A0
	cmp.l #PLX9054_SWAPPED,(A0)
	beq.s .read_local_config_word_little
	moveq #2,D0
	eor.l D0,D1              // offset
.read_local_config_word_little:
	move.w (A0,D1.l),D0
#if 0 // #ifdef DEBUG
	move.l D0,-(SP)
	moveq #0x52,D0
	bsr debug_display_char
	move.l (SP),D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif
	cmp.l #PLX9054_SWAPPED,(A0)
	bne.s .read_local_config_word_big
	ror.w #8,D0              // read data
.read_local_config_word_big:
	rts

read_local_config_longword:

	lea PCI_LOCAL_CONFIG,A0
	move.l (A0,D1.l),D0
#if 0 // #ifdef DEBUG
	move.l D0,-(SP)
	moveq #0x52,D0
	bsr debug_display_char
	move.l (SP),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif
	cmp.l #PLX9054_SWAPPED,(A0)
	bne.s .read_local_config_longword_big
	ror.w #8,D0
	swap D0
	ror.w #8,D0              // read data
.read_local_config_longword_big:
	rts
	
write_local_config_byte:

	lea PCI_LOCAL_CONFIG,A0
	cmp.l #PLX9054_SWAPPED,(A0)
	beq.s .write_local_config_byte_little
	moveq #3,D0
	eor.l D0,D1              // offset
.write_local_config_byte_little:
	move.b D2,(A0,D1.l)      // data to write
#if 0 // #ifdef DEBUG
	moveq #0x57,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
	
write_local_config_word:

	lea PCI_LOCAL_CONFIG,A0
	cmp.l #PLX9054_SWAPPED,(A0)
	beq.s .write_local_config_word_little
	moveq #2,D0
	eor.l D0,D1              // offset
	move.w D2,(A0,D1.l)
#if 0 // #ifdef DEBUG
	moveq #0x57,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.write_local_config_word_little:
	ror.w #8,D2              // data to write
	move.w D2,(A0,D1.l)
#if 0 // #ifdef DEBUG
	moveq #0x57,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
	
write_local_config_longword:

	lea PCI_LOCAL_CONFIG,A0
	cmp.l #PLX9054_SWAPPED,(A0)
	bne.s .write_local_config_longword_big
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
.write_local_config_longword_big:
	move.l D2,(A0,D1.l)
#if 0 // #ifdef DEBUG
	moveq #0x57,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

write_verify_local_config_byte:

	move.l D1,-(SP)
	bsr write_local_config_byte
	move.b (A0,D1.l),D0
	cmp.b D0,D2
	beq.s .wvb_ok
	move.l D0,-(SP)
	lea plx_error_register(PC),A0
	bsr display_string
	move.l 4(SP),D0
	bsr hex_word
	lea plx_error_write_value(PC),A0
	bsr display_string
	move.l D2,D0
	bsr hex_byte
	lea plx_error_read_value(PC),A0
	bsr display_string
	move.l (SP)+,D0
	bsr hex_byte
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
#if 0 // #ifdef DEBUG
	bsr dump_plx
#endif
.wvb_error:
	bra.s .wvb_error
.wvb_ok:
	addq.l #4,SP
	moveq #PCI_SUCCESSFUL,D0
	rts

write_verify_local_config_word:

	move.l D1,-(SP)
	bsr write_local_config_word
	move.w (A0,D1.l),D0
	cmp.w D0,D2
	beq.s .wvw_ok
	move.l D0,-(SP)
	lea plx_error_register(PC),A0
	bsr display_string
	move.l 4(SP),D0
	bsr hex_word
	lea plx_error_write_value(PC),A0
	bsr display_string
	move.l D2,D0
	bsr hex_word
	lea plx_error_read_value(PC),A0
	bsr display_string
	move.l (SP)+,D0
	bsr hex_word
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
#if 0 // #ifdef DEBUG
	bsr dump_plx
#endif
.wvw_error:
	bra.s .wvw_error
.wvw_ok:
	addq.l #4,SP
	moveq #PCI_SUCCESSFUL,D0
	rts

write_verify_local_config_longword:

	move.l D1,-(SP)
	bsr write_local_config_longword
	move.l (A0,D1.l),D0
	cmp.l D0,D2
	beq.s .wvl_ok
	move.l D0,-(SP)
	lea plx_error_register(PC),A0
	bsr display_string
	move.l 4(SP),D0
	bsr hex_word
	lea plx_error_write_value(PC),A0
	bsr display_string
	move.l D2,D0
	bsr hex_long
	lea plx_error_read_value(PC),A0
	bsr display_string
	move.l (SP)+,D0
	bsr hex_long
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
#if 0 // #ifdef DEBUG
	bsr dump_plx
#endif
.wvl_error:
	bra.s .wvl_error
.wvl_ok:
	addq.l #4,SP
	moveq #PCI_SUCCESSFUL,D0
	rts

#ifdef DEBUG

test_endian_local_config:

	lea PCI_LOCAL_CONFIG,A0
	cmp.l #PLX9054_SWAPPED,(A0)
	seq.b D0
	ext.w D0
	ext.l D0                 // -1: little, 0: big
	rts

wait_key:

	lea debug40(PC),A0
	bsr debug_display_string
	move.w #1,-(SP)
	trap #1                  // Cconin
	addq.l #2,SP
	cmp.b #0x79,D0           // y
	rts

#if 0
dump_plx:

	movem.l D0-D5,-(SP)
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	moveq #15,D4
	moveq #0,D3
.loop_dump2:
		move.l D3,D0
		bsr debug_hex_word
		moveq #0x20,D0
		bsr debug_display_char
		moveq #0x20,D0
		bsr debug_display_char
		moveq #7,D5
.loop_dump1:
			move.l D3,D1
			bsr read_local_config_longword
			bsr debug_hex_long
			moveq #0x20,D0
			bsr debug_display_char
			addq.l #4,D3
		dbf D5,.loop_dump1
		moveq #13,D0
		bsr debug_display_char
		moveq #10,D0
		bsr debug_display_char
	dbf D4,.loop_dump2
	movem.l (SP)+,D0-D5
	rts
#endif

#endif /* DEBUG */

#endif /* COLDFIRE */

#ifdef CHECK_PARITY

check_parity:

	move.l A0,-(SP)
	move.l D1,-(SP)
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	move.l D0,-(SP)          // value
	move.l D2,-(SP)
	move.l D0,D2
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.l (SP)+,D2
	move.l (SP)+,D0          // value
	move.l (SP)+,D1
	move.l (SP)+,A0
	tst.l D0                 // value, bit 31: parity
	rts

check_parity_target:                  // D0.l handle

#ifdef TEST_TARGET
	move.l A0,-(SP)
	move.l D1,-(SP)
	move.l D0,-(SP)          // handle
	moveq #PCICSR,D1
	bsr fast_read_config_longword
	move.l D0,-(SP)          // value
	move.l D2,-(SP)
	move.l D0,D2
	move.l 8(SP),D0          // handle
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_config_longword
	move.l (SP)+,D2
	move.l (SP)+,D0          // value
	addq.l #4,SP             // handle
	move.l (SP)+,D1
	move.l (SP)+,A0
	tst.l D0                 // value, bit 31: parity
#else
	moveq #0,D0
#endif
	rts
	
#endif /* CHECK_PARITY */
	
pci_interrupt:

	move.w D0,D4             // Bridge/IntA/IntB/IntC/IntD <=> handle <=> card
	lea 0,A2
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq.s .loop_interrupt    // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A2             // Status-Descriptors
.loop_interrupt:
		move.l A2,D0
		beq.s .end_interrupt
		move.w D4,D1             // handle
		mulu #PCI_DEV_DES_SIZE,D1
		move.l PCI_DEV_DES_HANDLER(A2,D1.l),D0
		beq.s .end_interrupt
		move.l D0,A3
		move.l PCI_DEV_DES_PARAMETER(A2,D1.l),A0
		moveq #0,D0
		jsr (A3)
		and.l #1,D0
		bne.s .interrupt_ok      // interrupt was from this card
.end_interrupt:
		move.w D4,D0             // handle
		bsr disable_interrupt
		rts
.interrupt_ok:
		move.w D4,D0             // handle
		bsr clear_interrupt
		move.w D4,D0             // handle
	bsr test_interrupt
	beq .loop_interrupt
	rts

#ifdef COLDFIRE

#ifdef MCF5445X

enable_interrupt:

	moveq #0,D1
	bset D0,D1
	move.l FPGA_IRQEN,D0
	or.l D1,D0
	move.l D0,FPGA_IRQEN
	rts
	
disable_interrupt:

	moveq #-1,D1
	bclr D0,D1
	move.l FPGA_IRQEN,D0
	and.l D1,D0
	move.l D0,FPGA_IRQEN
	rts
	
clear_interrupt:

	moveq #INT0_LO_EPORT3,D0
	bset.b D0,MCF_EPORT_EPFR
	rts
	
test_interrupt:

	move.l FPGA_IRQEN,D1
	and.l FPGA_IRQSTATUS,D1
	btst D0,D1
	rts

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int_cfpci:

	lea -60(SP),SP
	movem.l D0-A6,(SP)
	moveq #0,D0              // bridge
	bsr pci_interrupt
	move.l MCF_PCI_PCIGSCR,D0
	move.l D0,MCF_PCI_PCIGSCR
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int_pciarb:

	move.l D0,-(SP)
	move.l MCF_PCIARB_PASR,D0
	move.l D0,MCF_PCIARB_PASR
	move.l (SP)+,D0
	rte

int3_pci:                             // same interrupt for 4 sources IntA-D
	lea -60(SP),SP
	movem.l D0-A6,(SP)
	move.l FPGA_IRQEN,D1
	and.l FPGA_IRQSTATUS,D1
	and.l #IRQEN_PCI,D1
	moveq #0,D0
.loop_find_first_lsb:
		addq.l #1,D0
		lsr.l #1,D1 // search the first LSB to 1
		bcs.s .found_first_lsb
	bne.s .loop_find_first_lsb
.found_first_lsb:
	bsr pci_interrupt        // IntA-D
	moveq #INT0_LO_EPORT3,D0
	bset.b D0,MCF_EPORT_EPFR
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rte

#else /* MCF548X */

enable_interrupt:

	move.l D1,-(SP)
	move.w SR,D1
	move.l D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
	ext.l D0
	beq.s .end_enable
	cmp.l #2,D0
	bhi.s .slot_enable
	move.b MCF_EPORT_EPIER,D0
	or.l #MCF_EPORT_EPIER_EPIE5,D0
	move.b D0,MCF_EPORT_EPIER
    	move.l #~(MCF_INTC_IMRL_INT_MASK5 + MCF_INTC_IMRL_MASKALL),D0
	and.l D0,MCF_INTC_IMRL
	bra.s .end_enable
.slot_enable:
	move.l MCF_INTC_IMRL,D0
	and.l #MCF_INTC_IMRL_INT_MASK7,D0
	beq.s .end_enable
	move.b MCF_EPORT_EPIER,D0
	or.l #MCF_EPORT_EPIER_EPIE7,D0
	move.b D0,MCF_EPORT_EPIER
    	move.l #~(MCF_INTC_IMRL_INT_MASK7 + MCF_INTC_IMRL_MASKALL),D0
	and.l D0,MCF_INTC_IMRL
.end_enable:
	move.l (SP)+,D1
	move.w D1,SR
	move.l (SP)+,D1
	rts

disable_interrupt:

	move.l D1,-(SP)
	move.w SR,D1
	move.l D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
	ext.l D0
	beq.s .end_disable
	cmp.l #2,D0
	bhi.s .slot_disable
    	move.l #MCF_INTC_IMRL_INT_MASK5,D0
	or.l D0,MCF_INTC_IMRL
	move.b MCF_EPORT_EPIER,D0
	and.l #~MCF_EPORT_EPIER_EPIE5,D0
	move.b D0,MCF_EPORT_EPIER
	bra.s .end_disable
.slot_disable:
	move.l MCF_INTC_IMRL,D0
	and.l #MCF_INTC_IMRL_INT_MASK7,D0
	bne.s .end_disable
    	move.l #MCF_INTC_IMRL_INT_MASK7,D0
	or.l D0,MCF_INTC_IMRL
	move.b MCF_EPORT_EPIER,D0
	and.l #~MCF_EPORT_EPIER_EPIE7,D0
	move.b D0,MCF_EPORT_EPIER
.end_disable:
	move.l (SP)+,D1
	move.w D1,SR
	move.l (SP)+,D1
	rts

clear_interrupt:

	ext.l D0
	bne.s .usb_clear
	rts
.usb_clear:
	cmp.l #2,D0
	bhi.s .slot_clear
	moveq #5,D0
	bset.b D0,MCF_EPORT_EPFR
	rts
.slot_clear:
	moveq #7,D0
	bset.b D0,MCF_EPORT_EPFR
	rts

test_interrupt:

	ext.l D0
	bne.s .usb_test_interrupt
	move.l MCF_INTC_IPRH,D0
	btst #41-32,D0
	rts
.usb_test_interrupt:
	cmp.l #2,D0
	bhi.s .slot_test_interrupt
	move.l MCF_INTC_IPRL,D0
	btst #5,D0
	rts
.slot_test_interrupt:
	move.l MCF_INTC_IPRL,D0
	btst #7,D0
	rts

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int_cfpci:

	lea -60(SP),SP
	movem.l D0-A6,(SP)
	moveq #0,D0              // bridge
	bsr pci_interrupt
	move.l MCF_PCI_PCIGSCR,D0
	move.l D0,MCF_PCI_PCIGSCR
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int_pciarb:

	move.l D0,-(SP)
	move.l MCF_PCIARB_PASR,D0
	move.l D0,MCF_PCIARB_PASR
	move.l (SP)+,D0
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int_xlbpci:

	move.l D0,-(SP)
	move.l D1,-(SP)
	move.l MCF_PCI_PCIISR,D0
	move.l D0,MCF_PCI_PCIISR
	move.l #MCF_PCI_PCIICR_REE,D1
	and.l D0,D1
	beq.s .no_retry_abort		
#if 0 // #ifdef DEBUG
	move.l A0,-(SP)
	lea debug42(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#else
	nop
#endif	
.no_retry_abort:
	move.l #MCF_PCI_PCIICR_IAE,D1
	and.l D0,D1
	beq.s .no_initiator_abort
#if 0 // #ifdef DEBUG
	move.l A0,-(SP)
	lea debug43(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#else
	nop	
#endif
.no_initiator_abort:
	move.l #MCF_PCI_PCIICR_TAE,D1
	and.l D0,D1
	beq.s .no_target_abort
#if 0 // #ifdef DEBUG	
	move.l A0,-(SP)
	lea debug44(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#else
	nop
#endif
.no_target_abort:
	move.l (SP)+,D1
	move.l (SP)+,D0
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0
	
int5_pci:
	lea -60(SP),SP
	movem.l D0-A6,(SP)
	moveq #1,D0
	bsr pci_interrupt
	moveq #5,D0
	bset.b D0,MCF_EPORT_EPFR
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int7_pci:

	lea -60(SP),SP
	movem.l D0-A6,(SP)
	moveq #2,D0
	bsr pci_interrupt
	moveq #7,D0
	bset.b D0,MCF_EPORT_EPFR
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rte
	
#endif /* MCF5445X */
	
#else  /* ATARI - CTPCI/PLX9054 */

enable_interrupt: // there are just a global enable bit on the CTPCI

	move.l #PCI_IRQ_BASE_VECTOR,D0
	and.l #0xF0,D0          // base vector bits 4-7
	bset #0,D0              // enable
	move.l D0,PCI_CTPCI_CONFIG
	rts
	
disable_interrupt:

	rts
	
clear_interrupt:

	rts

test_interrupt:

             tst.w D0                 // LINT
             bne.s .slots_test_interrupt
           	move.l #INTCSR,D1        // Interrupt Control/Status
	bsr read_local_config_longword
	and.l #0x00F0E000,D0
	seq.b D0
	and.l #1,D0
             rts
.slots_test_interrupt:
	moveq #1,D0              // interrupt is finished
	rts
	
	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int_ctpci:
	
	movem.l D0-A6,-(SP)
	moveq #0,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0
	
inta_ctpci:

	movem.l D0-A6,-(SP)
	moveq #1,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0
	
intb_ctpci:

	movem.l D0-A6,-(SP)
	moveq #2,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

intc_ctpci:
	
	movem.l D0-A6,-(SP)
	moveq #3,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

intd_ctpci:
	
	movem.l D0-A6,-(SP)
	moveq #4,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
	rte
	
#endif /* COLDFIRE */
	
get_cookie:

#ifdef COLDFIRE
	move.l D1,-(SP)
	move.l A0,-(SP)
#else
	movem.l D1/A0,-(SP)
#endif
	move.l D0,D1             // cookie
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
.end_cookie:
#ifdef COLDFIRE
	move.l (SP)+,A0
	move.l (SP)+,D1
#else
	movem.l (SP)+,D1/A0
#endif
	tst.l D0
	rts

add_cookie:

#ifdef COLDFIRE
	lea -12(SP),SP
	movem.l D1-D2/A0,(SP)
#else
	movem.l D1-D2/A0,-(SP)
#endif
	move.l cookie,D2
	beq.s .cookie_not_found_add
	move.l D2,A0
	moveq #0,D2
	bra.s .next_cookie_add
.loop_add_cookie:
		addq.l #8,A0
		addq.l #1,D2
.next_cookie_add:
	tst.l (A0)
	bne.s .loop_add_cookie
	cmp.l 4(A0),D2
	bcc.s .cookie_not_found_add
	move.l 4(A0),D2
	move.l D0,(A0)           // cookie
	move.l D1,4(A0)          // value
	addq.l #8,A0
	clr.l (A0)
	move.l D2,4(A0)
	moveq #1,D0              // OK
	bra.s .end_add_cookie
.cookie_not_found_add:
	moveq #0,D0              // error
.end_add_cookie:
#ifdef COLDFIRE
	movem.l (SP),D1-D2/A0
	lea 12(SP),SP
#else
	movem.l (SP)+,D1-D2/A0
#endif
	rts
	
display_string:

	move.l D0,-(SP)
	move.l A0,-(SP)	
	move.l #0x5F414B50,D0    // _AKP cookie
	bsr get_cookie
	lsr.l #8,D0
	and.l #0xFF,D0
	cmp.l #2,D0              // FRA
	beq.s .french
	cmp.l #7,D0              // SWF
	bne.s .english
.french:
	tst.b (A0)+
	bne.s .french
.english:
	bsr display_string_single	
	move.l (SP)+,A0
	move.l (SP)+,D0
	rts
	
display_string_single:

	move.l D0,-(SP)
	move.l A0,-(SP)
.os2:
		move.b (A0)+,D0
		beq.s .os1
		bsr display_char
	bra.s .os2
.os1:
	move.l (SP)+,A0
	move.l (SP)+,D0
	rts

hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s hex_word
	move.l (SP)+,D0
hex_word:
	move.w D0,-(SP)
	lsr.l #8,D0          
	bsr.s hex_byte     
	move.w (SP)+,D0
hex_byte:
	move.w D0,-(SP)
	lsr.l #4,D0        
	bsr.s hex_char      
	move.w (SP)+,D0      
hex_char:
	and.l #0xF,D0      
	or.l #0x30,D0      
	cmp.l #0x3A,D0     
	bcs display_char  
	addq.l #7,D0

display_char:

#ifdef COLDFIRE
	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
#else
	movem.l D0-D2/A0-A2,-(SP)
#endif
	move.w D0,-(SP)
	move.w #2,-(SP)
	move.w #3,-(SP)          // Bconout
	trap #13
	addq.l #6,SP
#ifdef COLDFIRE
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
#else
	movem.l (SP)+,D0-D2/A0-A2
#endif
	rts   

tab_pci_device:
#ifdef COLDFIRE
#ifdef MCF5445X
	.byte 16                 // host bridge MCF5445X
	.byte 17,18,19,20        // device number n where AD[n] select IDSEL
#else /* MCF548X */
#ifdef MCF547X /* COLDARI */
	.byte 16                 // host bridge MCF547X
	// AD17 is the USB Controller ISP1563
	// AD18 and more are slots ?
	.byte 17,18,19,20        // device number n where AD[n] select IDSEL
#else /* MCF548X - M5484LITE/M5485EVB */
	.byte 16                 // host bridge MCF548X
	// on the Fire Engine AD17 is the USB Controller
	//                    AD18 is the Graphic Controller (not on M5484LITE)
	//                    AD20 is the 1st PCI slot
	//                    AD21 is the 2nd PCI slot (not on M5484LITE)
	.byte 17,18,20,21        // device number n where AD[n] select IDSEL
#endif /* MCF547X */
#endif /* MCF5445X */
#else /* ATARI - CTPCI/PLX9054 */
	.byte 20-11                 // host bridge PLX9054
	.byte 21-11,22-11,23-11,24-11 // device number n-11 where AD[n] select IDSEL
#endif /* COLDFIRE */

pciinfo0:	.asciz "Device built before Class Code definitions"
pciinfo1:	.asciz "(All except VGA)"
pciinfo2:	.asciz "(VGA compatible)"
pciinfo9:	.asciz "(unknown)"

pciinfo10:	.asciz "Mass Storage Controller "
pciinfo11:	.asciz "(SCSI bus)"
pciinfo12:	.asciz "(IDE)"
pciinfo13:	.asciz "(Floppy disk)"
pciinfo14:	.asciz "(IPI bus)"
pciinfo15:	.asciz "(RAID)"
pciinfo16:	.asciz "(ATA)"
pciinfo17:	.asciz "(SATA)"
	
pciinfo20:	.asciz "Network Controller "
pciinfo21:	.asciz "(Ethernet)"
pciinfo22:	.asciz "(Token Ring)"
pciinfo23:	.asciz "(FDDI)"
pciinfo24:	.asciz "(ATM)"
pciinfo25:	.asciz "(ISDM)"
pciinfo26:	.asciz "(WorldFip)"
pciinfo27:	.asciz "(PICMG)"

pciinfo30:	.asciz "Display Controller "
pciinfo31:	.asciz "(VGA)"
pciinfo32:	.asciz "(XGA)"
pciinfo33:	.asciz "(3D)"
	
pciinfo40:	.asciz "Multimedia Controller "
pciinfo41:	.asciz "(Video)"
pciinfo42:	.asciz "(Audio)"
pciinfo43:	.asciz "(Computer Telephony)"
	
pciinfo50:	.asciz "Memory controller "
pciinfo51:	.asciz "(RAM)"
pciinfo52:	.asciz "(FLASH)"

pciinfo60:	.asciz "Bridge Controller "
pciinfo61:	.asciz "(Host Bridge)"
pciinfo62:	.asciz "(ISA Bridge)"
pciinfo63:	.asciz "(EISA Bridge)"
pciinfo64:	.asciz "(MC Bridge)"
pciinfo65:	.asciz "(PCI/PCI Bridge)"
pciinfo66:	.asciz "(PCMCIA Bridge)"
pciinfo67:	.asciz "(NUBUS Bridge)"
pciinfo68:	.asciz "(CARDBUS Bridge)"
pciinfo69:	.asciz "(RACE Bridge)"
pciinfo610:	.asciz "(STPCI Bridge)"
pciinfo611:	.asciz "(InfiniBand Bridge)"

pciinfo70:	.asciz "Communications Controller "
pciinfo71:	.asciz "(XT Compatible Serial)"
pciinfo72:	.asciz "(Parallel Port)"
pciinfo73:	.asciz "(Multiport Serial)"
pciinfo74:	.asciz "(Modem Controller)"
pciinfo75:	.asciz "(GPIB Controller)"
pciinfo76:	.asciz "(Smart Card)"

pciinfo80:	.asciz "Peripheral Controller "
pciinfo81:	.asciz "(PIC)"
pciinfo82:	.asciz "(DMA)"
pciinfo83:	.asciz "(System Timer)"
pciinfo84:	.asciz "(RTC)"
pciinfo85:	.asciz "(PCI Hot-Plug)"

pciinfo90:	.asciz "Input Device "
pciinfo91:	.asciz "(Keyboard)"
pciinfo92:	.asciz "(Digitizer)"
pciinfo93:	.asciz "(Mouse)"
pciinfo94:	.asciz "(Scanner)"
pciinfo95:	.asciz "(Gameport)"

pciinfo100:	.asciz "Docking Station "
pciinfo101:	.asciz "(Docking Station)"

pciinfo110:	.asciz "Processor "
pciinfo111:	.asciz "(386)"
pciinfo112:	.asciz "(486)"
pciinfo113:	.asciz "(Pentium)"
pciinfo114:	.asciz "(Alpha)"
pciinfo115:	.asciz "(PowerPC)"
pciinfo116:	.asciz "(MIPS)"
pciinfo117:	.asciz "(Coprocessor)"

pciinfo120:	.asciz "Serial Bus "
pciinfo121:	.asciz "(FireWire)"
pciinfo122:	.asciz "(ACCESS)"
pciinfo123:	.asciz "(SSA)"
pciinfo124:	.asciz "(USB)"
pciinfo125:	.asciz "(Fibre Channel)"
pciinfo126:	.asciz "(System Management Bus)"
pciinfo127:	.asciz "(InfiniBand)"
pciinfo128:	.asciz "(IPMI)"
pciinfo129:	.asciz "(SERCOS)"
pciinfo1210:	.asciz "(CANbus)"

pciinfo130:	.asciz "Wireless Controller "
pciinfo131:	.asciz "(iRDA Compatible)"
pciinfo132:	.asciz "(Consumer IR)"
pciinfo133:	.asciz "(RF)"
pciinfo134:	.asciz "(Bluetooth)"
pciinfo135:	.asciz "(Broadband)"
pciinfo136:	.asciz "(Ethernet 802.11a)"
pciinfo137:	.asciz "(Ethernet 802.11b)"

pciinfo140:	.asciz "Intelligent IO Controller "
pciinfo141:	.asciz "(I20 Arch)"

pciinfo150:	.asciz "Satellite Communication "
pciinfo151:	.asciz "(TV)"
pciinfo152:	.asciz "(Audio)"
pciinfo153:	.asciz "(Voice)"
pciinfo154:	.asciz "(DATA)"

pciinfo160:	.asciz "Encrytion/Decryption "
pciinfo161:	.asciz "(Network and Computing)"
pciinfo162:	.asciz "(Entertainment en/decrypt)"

pciinfo170:	.asciz "Signal Processing "
pciinfo171:	.asciz "(DPIO modules)"
pciinfo172:	.asciz "(Performance counters)"
pciinfo173:	.asciz "(Comm. synchronization)"
pciinfo174:	.asciz "(Management)"

pciinfo999:	.asciz "Device does not fit in any defined classes"

scanning_devices:
#ifdef COLDFIRE
	.byte 13,10
	.ascii "Scanning PCI devices..."
	.byte 13,10,0
	.byte 13,10
	.ascii "Recherche cartes PCI..."
	.byte 13,10,0
#else /* ATARI - CTPCI/PLX9054 */
	.byte 13,10
	.ascii "CTPCI found, scanning PCI devices..."
	.byte 13,10,0
	.byte 13,10
	.ascii "CTPCI trouve, recherche cartes PCI..."
	.byte 13,10,0
plx_error_register:
	.byte 13,10
	.asciz "PLX write error, register: 0x"
	.byte 13,10
	.asciz "PLX erreur ‚criture, registre: 0x"
plx_error_write_value:
	.asciz ", write: 0x"
	.asciz ", ‚criture: 0x"
plx_error_read_value:
	.asciz ", read: 0x"
	.asciz ", lecture: 0x"
#endif
separator:
	.asciz " | "
hor_separator:
	.ascii "-----------------------------------------------------------------------"
	.byte 13,10,0
begin_table:
	.ascii "Slot | Fctn | VendorID | DeviceID | Description"
	.byte 13,10,0
no_device:
	.ascii " 0xFFFF  |          | no device"
	.byte 13,10,0
no_more_io_space:
	.byte 13,10
	.ascii "     |      | no more IO-space available !!!"
	.byte 13,10,0
no_more_mem_space:
	.byte 13,10
	.ascii "     |      | no more MEM-space !!!"
	.byte 13,10,0
no_more_memory_below_1mb:
	.byte 13,10
	.ascii "     |      | no more memory space below 1 MB !!!"
	.byte 13,10,0
need_more_than_4gb:
	.byte 13,10
	.ascii "     |      | device requests more than 4GB memory !!!"
	.byte 13,10,0
unknow_memory_type:
	.byte 13,10
	.ascii "     |      | device requests unknown memory type !!!"
	.byte 13,10,0
#ifdef CHECK_PARITY
parity_error:
	.byte 13,10
	.ascii "     |      | detected parity error"
	.byte 13,10,0
#endif
#if 0
desc_io:
	.byte 13,10
	.asciz "     |      | I/O Address "
desc_mem:
	.byte 13,10
	.asciz "     |      | MEM Address "
desc_size:
	.asciz " Size "
_66mhz:
	.asciz " 66 MHz"
#endif
