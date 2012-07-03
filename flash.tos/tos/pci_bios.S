/*  PCI BIOS for CT60 with CTPCI
 *               Coldfire MCF547X/MCF548X & MCF5445X
 * 
 * Didier Mequignon 2005-2012 e-mail: aniplay@wanadoo.fr
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

#include "main.h"
#include "ct60.h"
#include "vars.h"
#include "pci_bios.h"

#define SLOT_TO_DEBUG 1

#undef DISPLAY_SUBCLASS

#ifndef COLDFIRE
#define LOCAL_REGISTERS_BIG
#define SAME_CPU_PCI_MEM_ADDR
#define TARGET_NO_CACHE_PCI_MEM
#endif

	.globl _install_pci_bios
	.globl dummy_function        // errata

_install_pci_bios:

	move.w 2(A0),D0
	ext.l D0
	cmp.l #1,D0                  // init
	blt display_devices
#ifdef COLDFIRE
	lea -56(SP),SP
	movem.l D1-A6,(SP)
#else
	movem.l D1-A6,-(SP)
#endif
	lea 0,A6
	subq.l #1,D0                 // (1) init, (2) init without PCI RESET
	move.l D0,D7 
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
#if 0	// CF PCI moved inside boot2.S before the CF68KLIB is called (init_cf)
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
#ifdef MCF547X
	move.w #0x3F,D0 /* only BREQ0-2 are connected to PCI */
#else
	move.w #0x3FF,D0
#endif
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
	move.l #MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE /* + MCF_PCI_PCIICR_REE*/ + PCI_ RETRIES,D0
	move.l D0,MCF_PCI_PCIICR
	move.l #MCF_PCI_PCIGSCR_SEE,D0
	or.l D0,MCF_PCI_PCIGSCR
#ifdef DEBUG
	lea debug29(PC),A0
	bsr debug_display_string	
#endif
	// Configure Initiator Windows
	move.l #PCI_MEMORY_OFFSET + ((PCI_MEMORY_SIZE - 1) >> 8),D0
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.w #(PCI_MEMORY_OFFSET >> 16),D0
#else
	clr.w D0
#endif
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
	// Target zones
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l #0x40000000,D0
	move.l D0,MCF_PCI_PCIBAR0    // 256 KB window
#ifdef MCF5445X
	move.l #0xFC000000 + MCF_PCI_PCITBATR0_EN,D0 
#else
	move.l #__MBAR + MCF_PCI_PCITBATR0_EN,D0
#endif
	move.l D0,MCF_PCI_PCITBATR0  // Target Base Address Translation Register 0
	clr.l MCF_PCI_PCIBAR1        // 1 GB window ! 
	move.l #MCF_PCI_PCITBATR1_EN,D0 
	move.l D0,MCF_PCI_PCITBATR1  // Target Base Address Translation Register 1
#else /* !SAME_CPU_PCI_MEM_ADDR */
	move.l #0x80000000,D0
	move.l D0,MCF_PCI_PCIBAR0    // 256 KB window
#ifdef MCF5445X
	move.l #0xFC000000 + MCF_PCI_PCITBATR0_EN,D0 
#else
	move.l #__MBAR + MCF_PCI_PCITBATR0_EN,D0
#endif
	move.l D0,MCF_PCI_PCITBATR0  // Target Base Address Translation Register 0
	move.l #0x40000000,D0
	move.l D0,MCF_PCI_PCIBAR1    // 1 GB window ! 
	move.l #MCF_PCI_PCITBATR1_EN,D0 
	move.l D0,MCF_PCI_PCITBATR1  // Target Base Address Translation Register 1
#endif /* SAME_CPU_PCI_MEM_ADDR */
//	move.l #MCF_PCI_PCITCR_P,D0  // prefetch reads for BAR1
//	move.l D0,MCF_PCI_PCITCR     // Target Control Register
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
	move.w #MCF_EPORT_EPPAR_EPPA7(EPORT_EPPAR_EPPAx_FALLING) \
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
#ifdef MCF547X
	/* Falling edge on IRQ1-7 EPORT */
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
	clr.b MCF_EPORT_EPIER
#endif /* MCF5445X */
#ifdef DEBUG
	lea debug31(PC),A0
	bsr debug_display_string	
#endif
	/* Clear PCI Reset and wait for devices to reset */
	move.l #~MCF_PCI_PCIGSCR_PR,D0
	and.l D0,MCF_PCI_PCIGSCR
#ifndef MCF5445X
	move.l MCF_SLT_SCNT1,D2
.delay_reset:
		move.l D2,D1
		sub.l MCF_SLT_SCNT1,D1
	cmp.l #2000000*SYSTEM_CLOCK,D1
	bcs.s .delay_reset
#else /* MCF5445X */
	move.l _hz_200,D2
	add.l #400,D2                // tempo 2 S
.delay_reset:
		move.l _hz_200,D1
	cmp.l D2,D1
	blt.s .delay_reset
#endif
	moveq #0,D7                  // OK, start from reset
#else /* end -- moved inside boot2.S before the CF68KLIB is called (init_cf) */
	move.l #400,D2               // tempo 2 S from reset, maybe it's finished
.delay_reset:
		move.l _hz_200,D1
	cmp.l D2,D1
	blt.s .delay_reset
#endif /* end -- moved inside boot2.S before the CF68KLIB is called (init_cf) */
#else /* ATARI - CTCPI/PLX9054 */
.no_hardware:
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	moveq #-1,D0                 // error
	bra .end_install	
.pci_cookie_not_found:
	tst.l D7
	bne .bypass_reset
             // test and init CTPCI configuration registers
	move.w SR,-(SP)
	or.w #0x700,SR               // no interrupts
	lea .no_hardware(PC),A0
	move.l 8,A5                  // bus error
	move.l A0,8
	move.l SP,A4                 // save ssp
	cmp.l #0x752019F3,memvalid
	bne.s .cold_reset
	cmp.l #0x237698AA,memval2
	bne.s .cold_reset
	cmp.l #0x5555AAAA,memval3
	bne.s .cold_reset
	move.w #PCI_IRQ_BASE_VECTOR,D0
	and.w #0xF0,D0
	move.b D0,PCI_CTPCI_CONFIG_VECTOR
	clr.b PCI_CTPCI_CONFIG_ENABI // mask INTD /INTC / INTB / INTA / LINT
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	bra .bypass_reset
.cold_reset:
	moveq #1,D0
	move.l D0,PCI_CTPCI_CONFIG_RESET // Reset PLX, PCI slots and PCI arbiter
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
	moveq #4,D0
	move.l D0,PCI_CTPCI_CONFIG_RESET // Reset/ + normal CTPCI space
	move.w #PCI_IRQ_BASE_VECTOR,D0
	and.w #0xF0,D0
	move.b D0,PCI_CTPCI_CONFIG_VECTOR
	clr.b PCI_CTPCI_CONFIG_ENABI // mask INTD /INTC / INTB / INTA / LINT
	move.l _hz_200,D2
	add.l #400,D2                // tempo 2 S
.delay_reset:
		move.l _hz_200,D1
	cmp.l D2,D1
	blt.s .delay_reset
	// check CTPCI version
	move.b PCI_CTPCI_CONFIG_PEND,D0
	and.w #0xE0,D0
	bne.s .bypass_reset
	move.l phystop,A0
	moveq #CTPCI_1M,D0
	or.l D0,hardware_type(A0)
	clr.w -(SP)
	pea 1
	bsr dma_lock
	addq.l #4,SP
	move.w D0,(SP)
	clr.l -(SP)
	bsr dma_lock
	addq.l #4,SP
	swap D0
	move.w (SP)+,D0
	cmp.l #0x10000,D0
	bne.s .bypass_reset
	move.l phystop,A0
	moveq #CTPCI_1N,D0
	or.l D0,hardware_type(A0)
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
	move.l #MARBR,D1   	
	bsr read_local_config_longword
//	move.l #0x91200000,D2        // for BIGEND input to WAIT output
	move.l #0x80200000,D2        // for BIGEND input to WAIT output
	cmp.l D0,D2
	seq.b D7
	and.l #1,D7                  // (0) start from reset, (1) start from CTRL-ALT-DEL (no changes)
	move.l #MARBR,D1             // Mode/DMA Arbitration
	bsr write_local_config_longword
	// Target zone
#ifdef TARGET_NO_CACHE_PCI_MEM
	bsr get_no_cache_memory_size
	move.l D0,D2
	subq.l #1,D2
	not.l D2
#else /* !TARGET_NO_CACHE_PCI_MEM */
	move.l #0xC0000000,D2        // 1GB
#endif /* TARGET_NO_CACHE_PCI_MEM */
	move.l #LAS0RR,D1            // Local Address Space 0 Range Register for PCI-to-Local Bus
	bsr write_local_config_longword
#ifdef TARGET_NO_CACHE_PCI_MEM
	bsr get_no_cache_memory
	bset #0,D0                   // enable PCI target window
	move.l D0,D2
#else /* !TARGET_NO_CACHE_PCI_MEM */
	moveq #1,D2                  // enable PCI target window at 0
#endif /* TARGET_NO_CACHE_PCI_MEM */	
	move.l #LAS0BA,D1            // Local Address Space 0 Local Base Address (Remap)
	bsr write_local_config_longword
	moveq #0,D2
	move.l #LAS1RR,D1            // Local Address Space 1 Range Register for PCI-to-Local Bus
	bsr write_local_config_longword
	moveq #0,D2                  // disable PCI target window
	move.l #LAS1BA,D1            // Local Address Space 1 Local Base Address (Remap)
	bsr write_local_config_longword
#if 1        // Optimizations
//	move.l #0x40C300C3,D2
	move.l #0x48C300C3,D2
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
	// Local zones
	moveq #0,D2                  // disable local zones (else it's possible that Ethernat/Supervidel test not works)
	move.l #DMPBAM,D1            // PCI Base Address (Remap) Register for PCI Initiator-to-PCI Memory
	bsr write_local_config_longword
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l #PCI_MEMORY_OFFSET_1,pci_memory_offset(A0)
	move.l #PCI_MEMORY_SIZE_1,pci_memory_size(A0)
	move.l #PCI_IO_OFFSET_1,pci_io_offset(A0)
	move.l #PCI_IO_SIZE_1,pci_io_size(A0)
	move.l A6,D0
	bne .lowest_zones            // 2nd loop (if access fault on I/O zone)
	move.w SR,-(SP)
	or.w #0x700,SR               // no interrupts
	lea .no_ethernat(PC),A1
	move.l 8,A5                  // bus error
	move.l A1,8
	move.l SP,A4                 // save ssp
	moveq #0,D0
	tst.l 0x80000000             // Ethernat
	move.l #ETHERNAT,D0
.no_ethernat:
	lea .no_supervidel(PC),A1
	move.l A1,8
	tst.l 0x80010000             // Supervidel
	or.l #SUPERVIDEL,D0
.no_supervidel:
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	move.l phystop,A0
	or.l D0,hardware_type(A0)
	tst.l D0
	bne.s .lowest_zones
	// biggest zones
	move.l #PCI_MEMORY_OFFSET_2,pci_memory_offset(A0)
	move.l #PCI_MEMORY_SIZE_2,pci_memory_size(A0)
	move.l #PCI_IO_OFFSET_2,pci_io_offset(A0)
	move.l #PCI_IO_SIZE_2,pci_io_size(A0)
	move.l #0x4D616758,D0        // MagX
	bsr get_cookie
	bne.s .lowest_zones          // if found, no change because other bits are set by TOS only (boot2.S)
	clr.l PCI_CTPCI_CONFIG_RESET // enable all space for CTPCI
.lowest_zones:
	move.l pci_io_size(A0),D2
	subq.l #1,D2
	not.l D2
#else /* !PCI_DYNAMIC_MAPPING */
	move.l #~(PCI_IO_SIZE-1),D2
#endif /* PCI_DYNAMIC_MAPPING */
	move.l #DMRR,D1              // Local Range Register for PCI Initiator-to-PCI
	bsr write_local_config_longword
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),D2
#else
	move.l #PCI_MEMORY_OFFSET,D2
#endif
	move.l #DMLBAM,D1            // Local Bus Base Address Register for PCI Initiator-to-PCI Memory
	bsr write_local_config_longword
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),D2
#else
	move.l #PCI_IO_OFFSET,D2
#endif
	move.l #DMLBAI,D1            // Local Bus Base Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #0,D2
	move.l #DMCFGA,D1
	bsr write_local_config_longword
#ifdef SAME_CPU_PCI_MEM_ADDR
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),D2
	add.l #0x2003,D2
#else
	move.l #PCI_MEMORY_OFFSET+0x2003,D2
#endif 
#else /* !SAME_CPU_PCI_MEM_ADDR */
	moveq #3,D2                  // enable PCI base for local bus map-to-PCI
#endif /* SAME_CPU_PCI_MEM_ADDR */
	move.l #DMPBAM,D1            // PCI Base Address (Remap) Register for PCI Initiator-to-PCI Memory
	bsr write_local_config_longword
#ifndef LITTLE_ENDIAN_LANE_SWAPPED        // bits inverses sur le PLX ???
	move.l #0x00300400,D2        // Little Endian + Local Init Status => PLX done
#else	                             // lines are swapped by the bridge
	move.l #0x003004FE,D2        // Big Endian excepted Configuration Registers
#endif                                    // + Local Init Status => PLX done
	move.l #BIGEND,D1            // Big/Little Endian Descriptor /  Local Miscellaneous Control 
	bsr write_local_config_longword
	// Target zones
	moveq #-1,D2
	moveq #PCIBAR0,D1            // PCI Base Address Register for Memory Accesses to Local, Runtime, and DMA
	bsr write_local_config_longword
	moveq #PCIBAR0,D1            // PCI Base Address Register for Memory Accesses to Local, Runtime, and DMA
	bsr read_local_config_longword
#if 0 // #ifdef SAME_CPU_PCI_MEM_ADDR
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),D0
#else
	move.l #PCI_MEMORY_OFFSET,D0
#endif
#else /* !SAME_CPU_PCI_MEM_ADDR */
	move.l #0xFFFFFF00,D2
#endif
	moveq #PCIBAR0,D1            // PCI Base Address Register for Memory Accesses to Local, Runtime, and DMA (256 bytes)
	bsr write_local_config_longword
	moveq #-1,D2
	moveq #PCIBAR2,D1            // PCI Base Address Register for Memory Accesses to Local Address Space 0
	bsr write_local_config_longword
	moveq #PCIBAR2,D1            // PCI Base Address Register for Memory Accesses to Local Address Space 0
	bsr read_local_config_longword
#ifdef TARGET_NO_CACHE_PCI_MEM
	bsr get_no_cache_memory
	move.l D0,D2
#else /* !TARGET_NO_CACHE_PCI_MEM */
#ifdef SAME_CPU_PCI_MEM_ADDR
	moveq #0,D2
#else
	move.l #0x40000000,D2
#endif /* SAME_CPU_PCI_MEM_ADDR */
#endif /* TARGET_NO_CACHE_PCI_MEM */
	moveq #PCIBAR2,D1            // PCI Base Address Register for Memory Accesses to Local Address Space 0
	bsr write_local_config_longword
	// Setup burst parameters
	move.l #PCI_CACHE_LINE + (32<<8),D2 // cache line / latency timer
	moveq #PCICLSR,D1            // PCI Cache Line Size / Latency Timer Register
	bsr write_local_config_longword
	move.l #((PCI_MAXLAT<<24) + (PCI_MINGNT<<16)),D2
	moveq #PCIILR,D1             // PCI Max_Lat / Min_Gnt Register
	bsr write_local_config_longword
	// Master Enable / Memory Space / I/O Space, and clear errors
	move.l #PCI_CMDREG_SERR + PCI_CMDREG_PERR + PCI_CMDREG_MEMWINV + PCI_CMDREG_MASTR + PCI_CMDREG_MEMSP + PCI_CMDREG_IOSP + 0xFA900000,D2
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr write_local_config_longword
	// end of PCI target windows configuration
#if 0 // #ifdef DEBUG
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
	move.l A6,D0
	bne.s .malloc_ok             // 2nd loop (if access fault on I/O zone)
	move.l #0x4D616758,D0        // MagX
	bsr get_cookie
	beq.s .malloc_tos            // not found
	move.l #PCI_COOKIE_TOTALSIZE,D0
	move.l _membot,A0
	add.l D0,_membot
	move.l A0,D0	
	bra.s .malloc_ok
.malloc_tos:
	move.w #3,-(SP)              // TT ram if possible
	move.l #PCI_COOKIE_TOTALSIZE,-(SP)
	move.w #0x44,-(SP)           // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	ble .abort_install
.malloc_ok:
	move.l D0,A6                 // _PCI cookie
	move.l D0,A0
	move.l #(PCI_COOKIE_TOTALSIZE/4)-1,D0
.loop_init_cookie:
		clr.l (A0)+
	subq.l #1,D0
	bpl.s .loop_init_cookie
	move.l A6,D0
	add.l #PCI_COOKIE_SIZE,D0
	move.l D0,A5                 // Ressource-Descriptors
	move.l #PCI_MAX_BUS*PCI_MAX_DEVICE*PCI_MAX_FUNCTION*6,D0
.init_desc:	
#ifdef COLDFIRE
		move.w PCI_RSC_DESC_FLAGS(A5),D1		
		or.l #FLG_LAST,D1
		move.w D1,PCI_RSC_DESC_FLAGS(A5)
#else
		or.w #FLG_LAST,PCI_RSC_DESC_FLAGS(A5)
#endif	
		add.l #PCI_RSC_DESC_SIZE,A5
	subq.l #1,D0
	bgt.s .init_desc
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
	move.l D7,-(SP)
	pea (A6)                      // _PCI cookie
	clr.l -(SP)                   // primary bus
	bsr init_devices
	addq.l #8,SP
#ifdef PCI_DYNAMIC_MAPPING
	tst.l D0
	beq.s .init_ok
	// access fault during PCI access
	move.l (SP)+,D7
	move.l phystop,A0
	moveq #CTPCI_1ABCD,D1
	or.l D1,hardware_type(A0)
	cmp.l #PCI_MEMORY_OFFSET_1,pci_memory_offset(A0)
	bne .bypass_reset            // 2nd loop
	cmp.l #PCI_MEMORY_SIZE_1,pci_memory_size(A0)
	bne .bypass_reset            // 2nd loop
	cmp.l #PCI_IO_OFFSET_1,pci_io_offset(A0)
	bne .bypass_reset            // 2nd loop 
	cmp.l #PCI_IO_SIZE_1,pci_io_size(A0)
	bne .bypass_reset            // 2nd loop with lowest zones (biggest zones not works before CTPCI_1E)
	bra.s .end_install           // abnormal (nothing works)
.init_ok:
#endif /* PCI_DYNAMIC_MAPPING */
#ifdef DEBUG
	lea debug34(PC),A0
	bsr debug_display_string	
#endif
	tst.l D0
	bne.s .error_install
	move.l A6,D1                 // value
	move.l #0x5F504349,D0        // cookie _PCI
	bsr add_cookie
#ifdef COLDFIRE
//#ifndef MCF547X
	moveq #0,D0
	bsr display_devices
//#endif
#endif
.error_install:
	move.l (SP)+,D0
.end_install:
#ifdef COLDFIRE
	movem.l (SP),D1-A6
	lea 56(SP),SP
#else
	movem.l (SP)+,D1-A6
#endif
	rts
	
// variables on stack used by init_devices:
#define RESERVE_STACK                           52
#define GRAPHICS_CARD_FLAG        -2+RESERVE_STACK // .w flag graphics card
#define SAVE_BITS                 -6+RESERVE_STACK // .l save value for usage bits in PCI ressources
#define DEVICE_VENDOR_ID         -10+RESERVE_STACK // .l device/vendor id
#define OFFSET_IO                -14+RESERVE_STACK // .l offset i/o resource 
#define OFFSET_MEMORY            -18+RESERVE_STACK // .l offset memory resource 
#define OFFSET_MEMORY_PREF       -22+RESERVE_STACK // .l offset memory ressource with prefetch
#define START_OFFSET_MEMORY      -26+RESERVE_STACK // .l start offset memory ressource
#define START_OFFSET_MEMORY_PREF -30+RESERVE_STACK // .l start offset memory ressource with prefetch
#define RESOURCE_INDEX           -32+RESERVE_STACK // .w offset or index resource by handle   
#define ERROR_CODE               -36+RESERVE_STACK // .l error code
#define DMA_OFFSET               -40+RESERVE_STACK // .l offset of base memory mapped of PCI
#define BAR_VALUE                -44+RESERVE_STACK // .l PCIBARX read value
#define BUS_NUMBER               -46+RESERVE_STACK // .w bus number
#define PRIMARY_SLOT_NUMBER      -48+RESERVE_STACK // .w slot offset primary bus where located bridge(s)
#define PCI_COOKIE               -52+RESERVE_STACK // .l pci cookie

init_devices:

	lea -56(SP),SP
	movem.l D1-A6,(SP)
	lea -RESERVE_STACK(SP),A6 
	move.l 56+4(SP),D3           // bus number
	beq.s .is_bus0
	cmp.l #PCI_MAX_BUS,D3
	bcs.s .bus_number_ok
	moveq #-1,D0                 // error
	bra .end_init_pci_bios2
.bus_number_ok:
	move.l 56+8(SP),D0           // get local pointers from bus 0 (main init_device)
	beq.s .is_bus0
	move.l D0,A6
	bra.s .common_bus
.is_bus0:
	move.l 56+8(SP),D0           // _PCI cookie
	move.l D0,PCI_COOKIE(A6)
.common_bus:
	lea -RESERVE_STACK(SP),SP
	move.l PCI_COOKIE(A6),D0
	add.l #PCI_COOKIE_SIZE,D0
	move.l D0,A5                 // Ressource-Descriptors
	add.l #PCI_RSC_HANDLESTOTALSIZE,D0 // PCI_RSC_DESC_TOTALSIZE*PCI_MAX_DEVICE*PCI_MAX_FUNCTION
	move.l D0,A4                 // Status-Descriptors, size PCI_DEV_DES_SIZE*PCI_MAX_DEVICE*PCI_MAX_FUNCTION
	move.l D3,D0                 // bus
	mulu #PCI_MAX_DEVICE*PCI_MAX_FUNCTION*PCI_RSC_DESC_TOTALSIZE,D0
	add.l D0,A5                  // Ressource-Descriptors
	move.l D3,D0                 // bus
	mulu #PCI_MAX_DEVICE*PCI_MAX_FUNCTION*PCI_DEV_DES_SIZE,D0
	add.l D0,A4                  // Status-Descriptors
	mulu #PCI_MAX_FUNCTION,D3
	bne.s .not_bus0
	clr.l DMA_OFFSET(A6)
	clr.w RESOURCE_INDEX(A6)
#ifdef SAME_CPU_PCI_MEM_ADDR
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),D0
#else
	move.l #PCI_MEMORY_OFFSET,D0
#endif
#else /* !SAME_CPU_PCI_MEM_ADDR */
	moveq #0,D0
#endif
	move.l D0,START_OFFSET_MEMORY_PREF(A6)
	move.l D0,OFFSET_MEMORY_PREF(A6)
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_size(A0),D1
	lsr.l #1,D1
	add.l D1,D0
#else
	add.l #PCI_MEMORY_SIZE/2,D0
#endif
	move.l D0,START_OFFSET_MEMORY(A6)
	move.l D0,OFFSET_MEMORY(A6)
	clr.l OFFSET_IO(A6)
	clr.l SAVE_BITS(A6)
	clr.w GRAPHICS_CARD_FLAG(A6)
 	clr.w BUS_NUMBER(A6)
	// init devices, handle 0 is for local bridge
.not_bus0:
	moveq #0,D4              	            // slot
	moveq #0,D6                           // function number
.loop_handle:
		clr.l ERROR_CODE(A6)     // error code
		move.l PCI_COOKIE(A6),A0
		add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE+PCI_DEV_HANDLESTOTALSIZE+PCI_INT_HANDLESTOTALSIZE,A0 // slot offset 0-3 for interrupt
		move.l D4,D0             // slot
		mulu #PCI_MAX_FUNCTION,D0
		add.l D0,A0              // offset slot
		move.l D3,D0             // bus number * PCI_MAX_FUNCTION
		mulu #PCI_MAX_DEVICE,D0
		add.l D0,A0              // offset bus
		add.l D6,A0              // offset function
		tst.l D3
		bne.s .not_primary_bus		
		move.l D4,D0             // slot
#if defined(COLDFIRE) && defined(MCF547X) // FIREBEE
		subq.l #2,D0             // - bridge - internal USB (INTA-B-C)
#else
		subq.l #1,D0             // - bridge
#endif
		bpl.s .init_slot_offset_int
		moveq #0,D0
		bra.s .init_slot_offset_int
.not_primary_bus:
		move.w PRIMARY_SLOT_NUMBER(A6),D0 // use offset from primary bus where located bridge(s)
.init_slot_offset_int:
		move.w D0,PRIMARY_SLOT_NUMBER(A6) // slot offset primary bus where located bridge(s)
		and.l #3,D0
		move.b D0,(A0)           // slot offset 0-3 for interrupt
#ifdef PCI_DYNAMIC_MAPPING                         // test for old CTPCI hardware who not like big PCI local zones
		move.l A4,-(SP)
		move.l A5,-(SP)
		move.w SR,-(SP)
		or.w #0x700,SR           // no interrupts
		lea .hardware_failure(PC),A0
		move.l 8,A5              // bus error
		move.l A0,8
		move.l SP,A4             // save ssp
		moveq #PCIIDR,D1
		move.l D6,D0             // current function number
		add.l D3,D0              // bus number
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_longword // Device ID & Vendor ID
		move.l A5,8              // restore bus error
		move.l A4,SP             // restore ssp
		move.w (SP)+,SR
		move.l (SP)+,A5
		move.l (SP)+,A4
#else /* !PCI_DYNAMIC_MAPPING */
		moveq #PCIIDR,D1
		move.l D6,D0             // current function number
		add.l D3,D0              // bus number
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_longword // Device ID & Vendor ID
#endif /* PCI_DYNAMIC_MAPPING */
		move.l D0,DEVICE_VENDOR_ID(A6)
#ifdef COLDFIRE
#ifdef DEBUG
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
		add.l D3,D0              // bus number
		swap D0
		or.l D4,D0               // slot
		bsr fast_read_config_longword // & class code
#ifdef COLDFIRE
#ifdef DEBUG
		move.l D0,-(SP)
		move.l A0,-(SP)
		lea debug36(PC),A0
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
		clr.w D0
		swap D0
		cmp.l #PCI_CLASS_BRIDGE_PCI,D0
		bne .not_pci_bridge
		tst.l D6                 // do not check for multi-function on bridge
		bne .next_slot
		// PCI to PCI bridge
		move.l D6,D0             // function
		add.l D3,D0              // bus number
		swap D0
		or.l D4,D0               // slot
		move.l OFFSET_IO(A6),D2
		add.l #0x00000FFF,D2     // 4KB alignment
		and.l #0xFFFFF000,D2
		bne.s .offset_io_not_null
		add.l #0x1000,D2
.offset_io_not_null:
		move.l D2,OFFSET_IO(A6)
		lsr.l #8,D2
		moveq #PCI_IO_BASE,D1    // I/O range behind the bridge
		move.l D0,-(SP)          // handle
		bsr write_config_byte
		move.l OFFSET_IO(A6),D2
		swap D2
		moveq #PCI_IO_BASE_UPPER16,D1 // I/O range behind the bridge
		move.l (SP),D0           // handle
		bsr write_config_word
		move.l OFFSET_MEMORY(A6),D2
		add.l #0x000FFFFF,D2     // 1MB alignment
		and.l #0xFFF00000,D2
		bne.s .offset_mem_not_null
		add.l #0x100000,D2
.offset_mem_not_null:
		move.l D2,OFFSET_MEMORY(A6)
		swap D2
		moveq #PCI_MEMORY_BASE,D1 // Memory range behind
		move.l (SP),D0           // handle
		bsr write_config_word
		move.l OFFSET_MEMORY_PREF(A6),D2
		add.l #0x000FFFFF,D2     // 1MB alignment
		and.l #0xFFF00000,D2
		bne.s .offset_mem_pref_not_null
		add.l #0x100000,D2
.offset_mem_pref_not_null:
		move.l D2,OFFSET_MEMORY_PREF(A6)
		swap D2
		moveq #PCI_PREF_MEMORY_BASE,D1 // Prefetchable memory range behind
		move.l (SP),D0           // handle
		bsr write_config_word	
		moveq #0,D2
		moveq #PCI_PREF_BASE_UPPER32,D1 // Upper half of prefetchable memory range
		move.l (SP),D0           // handle
		bsr write_config_longword
		move.l #(PCI_MAXLAT<<24),D2
		moveq #0,D0
		move.w BUS_NUMBER(A6),D0
		or.l D0,D2               // primary bus
		addq.l #1,D0
		move.w D0,BUS_NUMBER(A6)
		asl.l #8,D0              // secondary bus
		or.l D0,D2
		moveq #PCI_PRIMARY_BUS,D1
		or.l #0x00FF0000,D2      // subordinate bus
		move.l (SP),D0           // handle
		move.l D2,-(SP)
		bsr write_config_longword
		pea (A6)
		moveq #0,D0
		move.w BUS_NUMBER(A6),D0
		move.l D0,-(SP)
		jsr init_devices
		addq.l #8,SP
		move.w BUS_NUMBER(A6),D0
		swap D0
		clr.w D0
		move.l (SP)+,D2
		and.l #0xFF00FFFF,D2
		or.l D0,D2               // max subordinate bus
		moveq #PCI_PRIMARY_BUS,D1
		move.l (SP),D0           // handle
		bsr write_config_longword
		move.l OFFSET_IO(A6),D2
		add.l #0x00000FFF,D2     // 4KB alignment
		and.l #0xFFFFF000,D2
		move.l D2,OFFSET_IO(A6)
		subq.l #1,D2
		lsr.l #8,D2
		moveq #PCI_IO_LIMIT,D1
		move.l (SP),D0           // handle
		bsr write_config_byte
		move.l OFFSET_IO(A6),D2
		subq.l #1,D2
		swap D2
		moveq #PCI_IO_LIMIT_UPPER16,D1
		move.l (SP),D0           // handle
		bsr write_config_word
		move.l OFFSET_MEMORY(A6),D2
		add.l #0x000FFFFF,D2     // 1MB alignment
		and.l #0xFFF00000,D2
		move.l D2,OFFSET_MEMORY(A6)
		subq.l #1,D2
		swap D2
		moveq #PCI_MEMORY_LIMIT,D1
		move.l (SP),D0           // handle
		bsr write_config_word
		move.l OFFSET_MEMORY_PREF(A6),D2
		add.l #0x000FFFFF,D2     // 1MB alignment
		and.l #0xFFF00000,D2
		move.l D2,OFFSET_MEMORY_PREF(A6)
		subq.l #1,D2
		swap D2
		moveq #PCI_PREF_MEMORY_LIMIT,D1
		move.l (SP),D0           // handle
		bsr write_config_word
		moveq #0,D2
		moveq #PCI_PREF_LIMIT_UPPER32,D1
		move.l (SP),D0           // handle
		bsr write_config_longword
		move.b #PCI_MAXLAT,D2
		moveq #PCILTR,D1         // Latency Timer
		move.l (SP),D0           // handle
		bsr write_config_byte
		moveq #PCI_CACHE_LINE,D2
		moveq #PCICLSR,D1
		move.l (SP),D0           // handle
		bsr write_config_byte
		moveq #PCISR,D1          // PCI Status Register
		move.l (SP),D0           // handle
		bsr fast_read_config_word
		move.l D0,D2
		moveq #PCISR,D1          // PCI Status Register
		move.l (SP),D0           // handle
		bsr write_config_word    // clear errors
		moveq #0x21,D2           // master abort mode and enable parity error detection on secondary
		moveq #PCI_BRIDGE_CONTROL,D1
		move.l (SP),D0           // handle
		bsr write_config_word
#ifndef COLDFIRE
		move.w #PCI_CMDREG_SERR + PCI_CMDREG_PERR + PCI_CMDREG_MEMWINV + PCI_CMDREG_MASTR + PCI_CMDREG_MEMSP + PCI_CMDREG_IOSP,D2
#else
		move.w #PCI_CMDREG_PERR + PCI_CMDREG_MEMWINV + PCI_CMDREG_MASTR + PCI_CMDREG_MEMSP + PCI_CMDREG_IOSP,D2
#endif
		moveq #PCICR,D1          // PCI Command Register
		move.l (SP)+,D0          // handle
		bsr write_config_word
		moveq #3,D0              // card in use
		move.l D4,D1             // slot
		mulu #PCI_MAX_FUNCTION*PCI_DEV_DES_SIZE,D1
		move.l D0,PCI_DEV_DES_STATUS(A4,D1.l)
		clr.l PCI_DEV_DES_CALLBACK(A4,D1.l)
		clr.l PCI_DEV_DES_HANDLER(A4,D1.l)
		clr.l PCI_DEV_DES_PARAMETER(A4,D1.l)
		clr.l PCI_DEV_DES_START_IRQ(A4,D1.l)
		move.l D4,D0             // slot
		mulu #PCI_MAX_FUNCTION*PCI_RSC_DESC_TOTALSIZE,D0
		move.w #FLG_LAST,D1
		move.w D1,PCI_RSC_DESC_FLAGS(A5,D0.l)
		clr.l PCI_RSC_DESC_START(A5,D0.l) // offset memory resource
		clr.l PCI_RSC_DESC_OFFSET(A5,D0.l)
		clr.l PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
		clr.l PCI_RSC_DESC_LENGTH(A5,D0.l)
		clr.w PCI_RSC_DESC_NEXT(A5,D0.l)
		clr.l PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
		bra .next_slot  
.not_pci_bridge:
		lsr.l #8,D0              // base class code
		and.l #0xFF,D0
		cmp.l #PCI_CLASS_DISPLAY,D0
		seq.b D0
		ext.w D0
		move.w D0,GRAPHICS_CARD_FLAG(A6) // flag graphic card
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
		tst.l D3
		bne.s .devices           // <> bus 0
		tst.l D4                 // slot
		bne.s .devices           // <> local bridge PLX9054
		tst.l D6                 // do not check for multi-function on bridge
		bne .next_slot
		move.w #PCI_RSC_DESC_SIZE,D1
		move.w D1,PCI_RSC_DESC_NEXT(A5)
		// information for bus mastering
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
		move.w D1,PCI_RSC_DESC_FLAGS(A5)
#ifdef COLDFIRE
		move.l #0x40000000,D1 // 1GB
		move.l D1,PCI_RSC_DESC_LENGTH(A5)
		move.l MCF_PCI_PCIBAR1,D1
		and.l #PCI_BASE_M_ADDR_M,D1
#else /* ATARI - CTPCI/PLX9054 */
#ifdef TARGET_NO_CACHE_PCI_MEM
		bsr get_no_cache_memory_size
		move.l D0,PCI_RSC_DESC_LENGTH(A5)
		bsr get_no_cache_memory
		move.l D0,D1
#else /* !TARGET_NO_CACHE_PCI_MEM */
		move.l #0x40000000,PCI_RSC_DESC_LENGTH(A5) // 1GB
#ifdef SAME_CPU_PCI_MEM_ADDR
		moveq #0,D1
#else		// STRAM/SDRAM mapped on PCI after the zones for devices
		move.l #0x40000000,D1
#endif /* SAME_CPU_PCI_MEM_ADDR */
#endif /* TARGET_NO_CACHE_PCI_MEM */ 
#endif /* COLDFIRE */
		move.l D1,PCI_RSC_DESC_START(A5) // offset memory resource
#ifdef SAME_CPU_PCI_MEM_ADDR
		moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
		neg.l D1
#endif /* SAME_CPU_PCI_MEM_ADDR */
		move.l D1,PCI_RSC_DESC_OFFSET(A5)
		move.l D1,PCI_RSC_DESC_DMAOFFSET(A5)
		move.l D1,DMA_OFFSET(A6)
		clr.l PCI_RSC_DESC_ERROR(A5) // internal error code
		// end information for bus mastering
#if 0 // #if !defined(COLDFIRE) && defined(SAME_CPU_PCI_MEM_ADDR)
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
		move.w D1,PCI_RSC_DESC_FLAGS+PCI_RSC_DESC_SIZE(A5)
		move.l #256,D1
		move.l D1,PCI_RSC_DESC_LENGTH+PCI_RSC_DESC_SIZE(A5)
		move.l OFFSET_MEMORY(A6),D0
		move.l D0,PCI_RSC_DESC_START+PCI_RSC_DESC_SIZE(A5) // offset memory resource
		add.l D1,D0
		move.l D0,OFFSET_MEMORY(A6)
#ifdef SAME_CPU_PCI_MEM_ADDR
		moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
		move.l pci_memory_offset(A0),D1
#else
		move.l #PCI_MEMORY_OFFSET,D1
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
		move.l D1,PCI_RSC_DESC_OFFSET+PCI_RSC_DESC_SIZE(A5)
		move.l DMA_OFFSET(A6),D1
		move.l D1,PCI_RSC_DESC_DMAOFFSET+PCI_RSC_DESC_SIZE(A5)
		clr.l PCI_RSC_DESC_ERROR+PCI_RSC_DESC_SIZE(A5) // internal error code
		moveq #2,D0
#else
		moveq #1,D0
#endif /*  !defined(COLDFIRE) && defined(SAME_CPU_PCI_MEM_ADDR) */
		move.w D0,RESOURCE_INDEX(A6) // offset resource by handle
		bra .end_area
.devices:
#ifdef COLDFIRE
#ifdef DEBUG
		lea debug41(PC),A0
		bsr debug_display_string
#endif
#endif
		moveq #PCIBAR0,D5        // reg
		clr.w RESOURCE_INDEX(A6) // index resource by handle
.loop_area:
			move.l D5,D1         // reg
			move.l D6,D0         // current function number
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_longword
			move.l D0,BAR_VALUE(A6) // save value and read type bits
			moveq #-1,D2
			move.l D5,D1         // reg
			move.l D6,D0         // current function number
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
			move.l D5,D1         // reg
			move.l D6,D0         // function number
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_longword
			move.l D0,SAVE_BITS(A6) // save value for try to find used bits (resolution)
			lea OFFSET_MEMORY_PREF(A6),A3
			lea START_OFFSET_MEMORY_PREF(A6),A2
			and.l #PCI_BASE_PREF_M,D0
			bne.s .memory_with_cache
			lea OFFSET_MEMORY(A6),A3
			lea START_OFFSET_MEMORY(A6),A2
.memory_with_cache:
			move.l BAR_VALUE(A6),D2 // saved value
			move.l D5,D1         // reg
			move.l D6,D0         // function number
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword // restore value
			move.l SAVE_BITS(A6),D0 // value used bits PCIBARx register
			beq .next_area       // register not used
			cmp.l #PCIERBAR,D5   // PCI Expansion ROM Base Register 
			beq .expansion_rom
			moveq #PCI_BASE_SPACE_IO,D0
			and.l BAR_VALUE(A6),D0
			beq .not_space_io    // <> IO
.space_io:
			moveq #PCI_BASE_IO_ADDR_M,D7
			and.l SAVE_BITS(A6),D7 // value PCIBARx register
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
			move.l OFFSET_IO(A6),D0 // current offset I/O resource
			and.l D7,D0          // alignment with the resolution of PCIBARx
			cmp.l OFFSET_IO(A6),D0 // current offset I/O resource
			bcc.s .ok_with_current_offset_io
			add.l D2,D0          // add the minimum step of the PCI base address
			move.l D0,D7
			bra.s .check_size_io
.ok_with_current_offset_io:
			move.l OFFSET_IO(A6),D7 // current offset I/O resource
.check_size_io:
			move.l D7,D0
			add.l D2,D0          // minimum step of the PCI base address is the size 
#ifdef PCI_DYNAMIC_MAPPING
			move.l phystop,A0
			cmp.l pci_io_size(A0),D0
#else 
			cmp.l #PCI_IO_SIZE,D0
#endif
			bhi .io_space_full   // area overflow
			move.l D7,OFFSET_IO(A6) // new offset I/O resource
			move.w D4,D0         // slot
			mulu #PCI_MAX_FUNCTION,D0
			add.l D6,D0          // function
			mulu #PCI_RSC_DESC_TOTALSIZE,D0
			move.w RESOURCE_INDEX(A6),D1 // index resource by handle
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
			move.l OFFSET_IO(A6),D1
			move.l D1,PCI_RSC_DESC_START(A5,D0.l) // offset I/O resource
			add.l D2,OFFSET_IO(A6)  // offset I/O resource
			move.l D2,PCI_RSC_DESC_LENGTH(A5,D0.l)
#ifdef PCI_DYNAMIC_MAPPING
			move.l pci_io_offset(A0),D1
#else 
			move.l #PCI_IO_OFFSET,D1
#endif
			move.l D1,PCI_RSC_DESC_OFFSET(A5,D0.l)
			move.l DMA_OFFSET(A6),D1
			move.l D1,PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
			clr.l PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
			move.l PCI_RSC_DESC_START(A5,D0.l),D2      // offset I/O resource
			move.l D5,D1         // reg
			move.l D6,D0         // function number
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
#ifdef COLDFIRE
#ifdef DEBUG
			move.l D0,-(SP)
			moveq #0x30,D0
			bsr debug_display_char	
			moveq #0x78,D0
			bsr debug_display_char
			move.l D5,D1         // reg
			move.l D6,D0         // function
			add.l D3,D0          // bus number
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
			move.w RESOURCE_INDEX(A6),D0
			addq.l #1,D0
			move.w D0,RESOURCE_INDEX(A6) // index resource by handle
#else
			addq.w #1,RESOURCE_INDEX(A6) // index resource by handle
#endif
			bra .next_area
.expansion_rom:
			move.l #PCI_BASE_ROM_ADDR_M,D7
			bra.s .not_space_io2
.not_space_io:
			moveq #PCI_BASE_M_ADDR_M,D7
.not_space_io2:
			and.l SAVE_BITS(A6),D7 // value PCIBARx register
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
			move.l BAR_VALUE(A6),D0
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
			move.l D0,ERROR_CODE(A6) // error code
			// device will be shut down now
			moveq #PCICR,D1      // PCI Command Register
			move.l D6,D0         // function
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			move.l D0,-(SP)      // handle
			bsr fast_read_config_word
			// remove Special Cycle / Master Enable / Memory Space / I/O Space
			and.l #~(PCI_CMDREG_SPCYC + PCI_CMDREG_MASTR + PCI_CMDREG_MEMSP + PCI_CMDREG_IOSP),D0
			move.w D0,D2
			moveq #PCICR,D1      // PCI Command Register
			move.l (SP)+,D0      // handle
			bsr write_config_word
			bra .end_area
.memory_32bit:
#if 0 // old feature
			cmp.l #PCIBAR0,D5    // reg
			bne.s .no_fix_graphic_card
			tst.w GRAPHICS_CARD_FLAG(A6)      // flag graphic card
			beq.s .no_fix_graphic_card
			cmp.l #GRAPHIC_CARD_SIZE/4,D2
			bcc.s .no_fix_graphic_card                                             
			move.l #GRAPHIC_CARD_SIZE,D2
.no_fix_graphic_card:
#endif
			move.l D7,D0
			add.l D2,D0          // minimum step of the PCI base address is the size 
			sub.l (A2),D0        // start offset memory ressource
#ifdef PCI_DYNAMIC_MAPPING
			move.l phystop,A0
			move.l pci_memory_size(A0),D1
			lsr.l #1,D1
			cmp.l D1,D0
#else
			cmp.l #PCI_MEMORY_SIZE/2,D0
#endif
			bhi .mem_space_full  // area overflow
			move.l D7,(A3)       // new offset memory resource
			move.l D4,D0         // device
			mulu #PCI_MAX_FUNCTION,D0
			add.l D6,D0
			mulu #PCI_RSC_DESC_TOTALSIZE,D0
			move.w RESOURCE_INDEX(A6),D1 // index resource by handle
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
			cmp.l #PCIERBAR,D5   // PCI Expansion ROM Base Register 
			bne.s .not_expansion_rom2	
			or.l #FLG_ROM,D1                      // Expansion ROM
.not_expansion_rom2:
			move.w D1,PCI_RSC_DESC_FLAGS(A5,D0.l)
			move.l (A3),D1
			move.l D1,PCI_RSC_DESC_START(A5,D0.l) // offset memory resource
			add.l D2,(A3)        // offset memory resource
			move.l D2,PCI_RSC_DESC_LENGTH(A5,D0.l)
#ifdef SAME_CPU_PCI_MEM_ADDR
			moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
			move.l pci_memory_offset(A0),D1
#else
			move.l #PCI_MEMORY_OFFSET,D1
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
			move.l D1,PCI_RSC_DESC_OFFSET(A5,D0.l)
			move.l DMA_OFFSET(A6),D1
			move.l D1,PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
			clr.l PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
			move.l PCI_RSC_DESC_START(A5,D0.l),D2      // offset memory resource
			cmp.l #PCIERBAR,D5   // PCI Expansion ROM Base Register 
			bne.s .not_expansion_rom			
			or.l #PCI_BASE_ROM_ENABLE,D2
.not_expansion_rom:	
			move.l D5,D1         // reg
			move.l D6,D0         // function
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
#ifdef COLDFIRE
#ifdef DEBUG
			move.l D0,-(SP)
			moveq #0x30,D0       // '0'
			bsr debug_display_char	
			moveq #0x78,D0       // 'x'
			bsr debug_display_char
			move.l D5,D1         // reg
			move.l D6,D0         // function
			add.l D3,D0          // bus number
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
			move.w RESOURCE_INDEX(A6),D0
			addq.l #1,D0
			move.w D0,RESOURCE_INDEX(A6) // index resource by handle
#else
			addq.w #1,RESOURCE_INDEX(A6) // index resource by handle
#endif
			bra .next_area
.memory_64bit:
			move.l D2,-(SP)
			moveq #-1,D2
			moveq #4,D1
			add.l D5,D1          // reg + 4 (next PCIBARx)
			move.l D6,D0         // function
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
			moveq #4,D1
			add.l D5,D1          // reg + 4 (next PCIBARx)
			move.l D6,D0         // function
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			bsr fast_read_config_longword
			move.l (SP)+,D2
			moveq #-1,D1
			cmp.l D0,D1
			bne .need_more_4gb
			move.l D7,D0
			add.l D2,D0          // minimum step of the PCI base address is the size
			sub.l (A2),D0        // start offset memory ressource
#ifdef PCI_DYNAMIC_MAPPING
			move.l phystop,A0
			move.l pci_memory_size(A0),D1
			lsr.l #1,D1
			cmp.l D1,D0
#else
			cmp.l #PCI_MEMORY_SIZE/2,D0
#endif
			bhi .mem_space_full  // area overflow
			move.l D7,(A3)       // new offset memory resource
			move.l D4,D0         // device
			mulu #PCI_MAX_FUNCTION,D0
			add.l D6,D0
			mulu #PCI_RSC_DESC_TOTALSIZE,D0
			move.w RESOURCE_INDEX(A6),D1 // index resource by handle
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
#ifdef SAME_CPU_PCI_MEM_ADDR
			moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
			move.l pci_memory_offset(A0),D1
#else
			move.l #PCI_MEMORY_OFFSET,D1
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
			move.l D1,PCI_RSC_DESC_OFFSET(A5,D0.l)
			move.l DMA_OFFSET(A6),D1
			move.l D1,PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
			clr.l PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
			move.l PCI_RSC_DESC_START(A5,D0.l),D2 // offset memory resource
			move.l D5,D1         // reg
			move.l D6,D0         // function
			add.l D3,D0          // bus number
			swap D0
			or.l D4,D0           // slot
			bsr write_config_longword
#ifdef COLDFIRE
#ifdef DEBUG
			move.l D0,-(SP)
			moveq #0x30,D0
			bsr debug_display_char	
			moveq #0x78,D0
			bsr debug_display_char
			move.l D5,D1         // reg
			move.l D6,D0	        // function
			add.l D3,D0          // bus number
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
			move.w RESOURCE_INDEX(A6),D0
			addq.l #1,D0
			move.w D0,RESOURCE_INDEX(A6) // index resource by handle
#else
			addq.w #1,RESOURCE_INDEX(A6) // index resource by handle
#endif
			moveq #0,D2
			moveq #4,D1
			add.l D5,D1          // reg + 4
			move.l D6,D0         // function
			add.l D3,D0          // bus number
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
		moveq #PCI_CACHE_LINE,D2
		moveq #PCICLSR,D1
		move.l D6,D0             // function
		add.l D3,D0              // bus number
		swap D0
		or.l D4,D0               // slot
		move.l D0,-(SP)
		bsr write_config_byte
		moveq #PCISR,D1          // PCI Status Register
		move.l (SP),D0           // handle
		bsr fast_read_config_word
		move.l D0,D2
		moveq #PCISR,D1          // PCI Status Register
		move.l (SP),D0           // handle
		bsr write_config_word    // clear errors
#ifndef COLDFIRE
		move.w #PCI_CMDREG_SERR + PCI_CMDREG_PERR + PCI_CMDREG_MEMWINV + PCI_CMDREG_MASTR + PCI_CMDREG_MEMSP + PCI_CMDREG_IOSP,D2
#else		
		move.w #PCI_CMDREG_PERR + PCI_CMDREG_MEMWINV + PCI_CMDREG_MASTR + PCI_CMDREG_MEMSP + PCI_CMDREG_IOSP,D2
#endif
		moveq #PCICR,D1          // PCI Command Register
		move.l (SP)+,D0
		bsr write_config_word
.end_area:
#ifdef COLDFIRE
#ifdef DEBUG
		move.l D0,-(SP)
		move.l A0,-(SP)
		moveq #13,D0
		bsr debug_display_char
		moveq #10,D0
		bsr debug_display_char
		moveq #PCICR,D1
		move.l D6,D0             // function
		add.l D3,D0              // bus number
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
		move.l D4,D0             // device
		mulu #PCI_MAX_FUNCTION,D0
		add.l D6,D0
		mulu #PCI_RSC_DESC_TOTALSIZE,D0
		move.w RESOURCE_INDEX(A6),D1 // index resource by handle
		bne.s .res_found
		clr.w PCI_RSC_DESC_FLAGS(A5,D0.l)
		clr.l PCI_RSC_DESC_START(A5,D0.l) // offset memory resource
		clr.l PCI_RSC_DESC_OFFSET(A5,D0.l)
		clr.l PCI_RSC_DESC_DMAOFFSET(A5,D0.l)
		clr.l PCI_RSC_DESC_LENGTH(A5,D0.l)
		clr.w PCI_RSC_DESC_NEXT(A5,D0.l)
		clr.l PCI_RSC_DESC_ERROR(A5,D0.l) // internal error code
		addq.l #1,D1                 // if no resource found
.res_found:
		mulu #PCI_RSC_DESC_SIZE,D1
		add.l D1,D0
		move.l ERROR_CODE(A6),D1     // internal error code
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
		move.l D6,D0             // function
		add.l D3,D0              // bus number
		swap D0
		or.l D4,D0               // device
		move.l D0,-(SP)          // handle
		bsr disable_interrupt
		// Interrupt Line Register will be initialised with 0xFF
		// because of different solutions regarding the Hardware
		// (Hades/Milan/...) This register is only for information
		// and won't be used by ATARI-compatibles. PCI adapters
		// don't care about the value set in this register.
		move.b #0xFF,D2
		moveq #PCIILR,D1         // Interrupt Line
		move.l (SP)+,D0          // handle
		bsr write_config_byte
#ifdef COLDFIRE
		tst.l D3                   
		bne.s .set_lat           // <> bus 0
		tst.l D4
		beq .next_slot           // host bridge
.set_lat:
#endif
		// Latency Timer Register is initialised with a useable
		// value. The new revision also cares about the min and
		// max values offered by the adapter in the MIN_GNT and
		// MAX_LAT registers
		moveq #PCIMGR,D1         // Min_Gnt
		move.l D6,D0             // function
		add.l D3,D0              // bus number
		swap D0
		or.l D4,D0               // slot
		move.l D0,-(SP)          // handle
		bsr fast_read_config_byte
		tst.b D0
		bne.s .max_gmt_lat_exist
		moveq #PCIMLR,D1         // Max_Lat
		move.l (SP),D0           // handle
		bsr fast_read_config_byte
		tst.b D0
		bne.s .max_gmt_lat_exist
		move.b #PCI_MAXLAT,D2     // Latency Timer value 1uS for 33 MHz bus
		bra.s .write_latency_timer
.max_gmt_lat_exist:
		moveq #PCIMLR,D1         // Max_Lat
		move.l (SP),D0           // handle
		bsr fast_read_config_byte
		lsl.l #3,D0              // *8
		move.b D0,D2             // Latency Timer value
		cmp.l #PCI_MAXLAT*2,D0   // 2 uS
		bls.s .write_latency_timer
		moveq #PCIMGR,D1         // Min_Gnt
		move.l (SP),D0           // handle
		bsr fast_read_config_byte
		lsl.l #3,D0              // *8
		move.b D0,D2             // Latency Timer value
.write_latency_timer:
		moveq #PCILTR,D1         // Latency Timer
		move.l (SP)+,D0          // handle
		bsr write_config_byte
		tst.l D6                 // function
		bne .next_function
#if 1
		tst.w GRAPHICS_CARD_FLAG(A6)
		bne .next_slot           // do not check for multi-function on graphic card (too big space)
#endif
		// before we go to the next slot, we first check if we have
		// a multi-function device. If so, we need to initialize
		// the remaining functions on the current card first
		move.l D3,D0              // bus number
		swap D0
		or.l D4,D0                // slot
		moveq #PCICLSR,D1
		bsr fast_read_config_longword
		btst #23,D0
		beq .next_slot
		// now that we now we have a multi function card, iterate functions
#ifdef COLDFIRE
#ifdef DEBUG
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
		move.l D4,D0             // device
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
#ifdef DEBUG
		lea debug47(PC),A0
		bsr debug_display_string
#endif
#endif
		addq.l #1,D4             // device
		moveq #PCI_MAX_SLOT,D0
		tst.l D3                 // bus number
		beq.s .primary_bus
		moveq #PCI_MAX_DEVICE,D0
.primary_bus:
	cmp.l D0,D4
	bcs .loop_handle
	moveq #0,D0                  // OK
	tst.l D3                     // bus number
	bne.s .end_init_pci_bios              // secondary bus
	moveq #0,D4                           // INT bridge (0), INT-A-B-C-D (1-4)
.loop_init_int:
#ifdef COLDFIRE
		tst.l D4                 // slot
		beq.s .set_vector_ok     // bridge
#ifdef MCF5445X
		move.w #64+INT0_LO_EPORT3+OFFSET_INT_CF68KLIB,D0 // IRQ5 EPORT
		lea int3_pci(PC),A0
#else /* MCF548X */
		move.w #64+5+OFFSET_INT_CF68KLIB,D0 // IRQ5 EPORT
		lea int5_pci(PC),A0                 // INTC-D (M5484LITE)
#ifndef MCF547X
		cmp.l #2,D4                         // slot
		bls.s .set_vector
		// INT7 call by software INT2 (can be masked)
		move.l A2,-(SP)
		pea int2_pci(PC)                    // INTA-B (M5484LITE)
		move.w #64+2+OFFSET_INT_CF68KLIB,-(SP) // IRQ2 EPORT
		move.w #5,-(SP)          // Setexec
		trap #13
		addq.l #8,SP
		move.l (SP)+,A2
		move.w #64+7+OFFSET_INT_CF68KLIB,D0 // IRQ7 EPORT
		lea int7_pci(PC),A0                 // INTA-B (M5484LITE)
#endif /* MCF547X */
#endif /* MCF5445X */
#else /* ATARI - CTPCI/PLX9054 */
		move.l #PCI_IRQ_BASE_VECTOR,D0
		lea int_ctpci(PC),A0
		tst.l D4                 // slot
		beq.s .set_vector        // bridge (LINT)
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
#ifndef COLDFIRE
		add.l D4,D0
#endif
		move.w D0,-(SP)
		move.w #5,-(SP)          // Setexec
		trap #13
		addq.l #8,SP
		move.l (SP)+,A2
.set_vector_ok:
		addq.l #1,D4
	cmp.l #4,D4
	bls.s .loop_init_int
#ifdef COLDFIRE
	move.l MCF_PCI_PCIISR,D0
	move.l D0,MCF_PCI_PCIISR // clear interrupt
#ifndef MCF5445X
	move.l #~MCF_INTC_IMRH_INT_MASK43,D0 // enable XLB PCI interrupt
	and.l D0,MCF_INTC_IMRH
#endif
#endif /* COLDFIRE */
	moveq #0,D0                  // OK
.end_init_pci_bios:
	lea RESERVE_STACK(SP),SP     // clear local variables
.end_init_pci_bios2:
	movem.l (SP),D1-A6
	lea 56(SP),SP
	rts
#ifdef PCI_DYNAMIC_MAPPING
.hardware_failure:
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	move.l (SP)+,A5
	move.l (SP)+,A4
	moveq #-1,D0                 // error
	lea RESERVE_STACK(SP),SP     // clear local variables
	movem.l (SP),D1-A6
	lea 56(SP),SP
	rts
#endif /* PCI_DYNAMIC_MAPPING */
	
display_devices:

#ifdef COLDFIRE
	lea -32(SP),SP
	movem.l D1-A0,(SP)
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D2
	and.l D2,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
#else /* !COLDFIRE */
	movem.l D1-A0,-(SP)
#endif /* COLDFIRE */
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
	lea begin_table(PC),A0       // Bus | Slot | Fctn | VendorID | DeviceID | Description
	bsr display_string_single
	lea hor_separator(PC),A0
	bsr display_string_single
	moveq #0,D4                  // slot
	moveq #0,D5                  // function
	moveq #0,D7                  // bus
.loop_handle_display:
			move.l D7,D0             // bus number
			mulu #PCI_MAX_FUNCTION,D0
			add.l D5,D0              // function number
			swap D0
			or.l D4,D0               // device
			bsr get_resource
			bmi .next_slot_display
			move.l D0,A1             // resource
			moveq #PCIIDR,D1
			move.l D7,D0             // bus number
			mulu #PCI_MAX_FUNCTION,D0
			add.l D5,D0              // function number
			swap D0
			or.l D4,D0               // device
			bsr fast_read_config_longword // Device ID & Vendor ID
			move.l D0,D3
			tst.l D7                 // bus number
			beq.s .display_all_devices_primary_bus
#ifdef COLDFIRE
			moveq #0,D0
			move.w D3,D0
			cmp.l #PCI_NOBODYHOME,D0 // Vendor ID
#else
			cmp.w #PCI_NOBODYHOME,D3 // Vendor ID
#endif      	
			beq .next_slot_display   // on secondary bus display only devices found
.display_all_devices_primary_bus:
			// display bus
			moveq #0x20,D0           // " "
			bsr display_char
			moveq #0x5B,D0           // [
			bsr display_char
			moveq #0x30,D0
			add.l D7,D0              // bus
			bsr display_char
			moveq #0x5D,D0           // ]
			bsr display_char
			lea separator(PC),A0
			bsr display_string_single
			// display slot
			move.l D4,D0             // slot
#ifdef COLDFIRE
			.chip 68060
#endif
			divu #10,D0
#ifdef COLDFIRE
			.chip 5200
#endif
			move.l D0,D1
			clr.w D1
			swap D1
			ext.l D0
			beq.s .slot_less_10
			move.l D0,-(SP)
			moveq #0x5B,D0           // [
			bsr display_char
			moveq #0x30,D0
			add.l (SP)+,D0           // slot / 10
			bsr display_char
			bra.s .slot_display
.slot_less_10:
			moveq #0x20,D0           // " "
			bsr display_char
			moveq #0x5B,D0           // [
			bsr display_char
.slot_display:
			moveq #0x30,D0
			add.l D1,D0
			bsr display_char         // slot
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
			beq .no_device_found_here_display
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
			move.l D7,D0             // bus number
			mulu #PCI_MAX_FUNCTION,D0
			add.l D5,D0              // function number
			swap D0
			or.l D4,D0               // device
			bsr fast_read_config_longword // & class code
			bsr display_infos_class
			tst.l D6
			beq.s .no_66mhz
			moveq #PCICSR,D1
			move.l D7,D0             // bus number
			mulu #PCI_MAX_FUNCTION,D0
			add.l D5,D0              // function number
			swap D0
			or.l D4,D0               // device
			bsr fast_read_config_longword
			btst #21,D0
			beq.s .no_66mhz
			lea _66mhz(PC),A0
			bsr display_string_single	
.no_66mhz:
			moveq #5,D1
.loop_resource:
				move.l PCI_RSC_DESC_ERROR(A1),D0
				bmi .error_device
				move.w PCI_RSC_DESC_FLAGS(A1),D0
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
				move.l A0,-(SP)
				lea separators(PC),A0
				bsr display_string_single
				move.l (SP)+,A0
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
#ifdef COLDFIRE
				and.l #FLG_LAST,D0
				bne.s .next_handle_3
				move.w PCI_RSC_DESC_NEXT(A1),D0
				ext.l D0
				add.l D0,A1
			subq.l #1,D1
			bpl.s .loop_resource
#else /* COLDFIRE */
				and.w #FLG_LAST,D0
				bne.s .next_handle_3
				add.w PCI_RSC_DESC_NEXT(A1),A1
			dbra D1,.loop_resource
#endif /* COLDFIRE */
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
			bne.s .next_handle_3     // unknow error
.display_error_device:
			move.l A0,-(SP)
			lea separators(PC),A0
			bsr display_string_single
			move.l (SP)+,A0
			bsr display_string_single
			bra.s .next_slot_display
.no_device_found_here_display:
			lea no_device(PC),A0     // no device
			bsr display_string_single
			bra.s .next_slot_display		
.next_handle_2:
			tst.l D7                 // bus number
			bne.s .secondary_bus_display
			tst.l D4
			beq.s .next_slot_display // do not search for multiple devices on bridge
.secondary_bus_display:
			// do we have a multi-function device?
			moveq #PCICLSR,D1
			move.l D7,D0             // bus number
			mulu #PCI_MAX_FUNCTION,D0
			swap D0
			or.l D4,D0              // device (slot)
			bsr fast_read_config_longword
			btst #23,D0
			beq.s .next_slot_display
			addq.l #1,D5             // function
			cmp.l #PCI_MAX_FUNCTION,D5
			bcs .loop_handle_display
.next_slot_display:
			moveq #0,D5              // function
			moveq #PCI_MAX_SLOT,D0
			tst.l D7                 // bus number
			beq.s .primary_bus_display
			moveq #PCI_MAX_DEVICE,D0
.primary_bus_display:			
			addq.l #1,D4             // device
		cmp.l D0,D4
		bcs .loop_handle_display
		moveq #0,D4                           // device
		addq.l #1,D7                          // bus
	cmp.l #PCI_MAX_BUS,D7
	bcs .loop_handle_display
	moveq #0,D0                  // OK
.end_display_devices:
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D1
	move.l D1,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
	movem.l (SP),D1-A0
	lea 32(SP),SP
#else /* !COLDFIRE */
	movem.l (SP)+,D1-A0
#endif /* COLDFIRE */
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
#ifdef DISPLAY_SUBCLASS
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
#else
	bra .end_info_class
#endif /* DISPLAY_SUBCLASS */
.mass_storage:
	lea pciinfo10(PC),A0         // Mass Storage Controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra .end_info_class
#endif /* DISPLAY_SUBCLASS */
.network_controller:
	lea pciinfo20(PC),A0         // Network controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra .end_info_class
#endif /* DISPLAY_SUBCLASS */
.display_controller:
	lea pciinfo30(PC),A0         // Display Controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra .end_info_class
#endif /* DISPLAY_SUBCLASS */
.multimedia_controller:
	lea pciinfo40(PC),A0         // Multimedia Controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra .end_info_class
#endif /* DISPLAY_SUBCLASS */
.memory_controller:
	lea pciinfo50(PC),A0         // Memory controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra .end_info_class
#endif /* DISPLAY_SUBCLASS */
.bridge_device:
	lea pciinfo60(PC),A0         // Bridge Controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.communications_controller:
	lea pciinfo70(PC),A0         // Communications Controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.peripheral_controller:
	lea pciinfo80(PC),A0         // Peripheral Controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.input_device:
	lea pciinfo90(PC),A0         // Input Device
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.docking_station:
	lea pciinfo100(PC),A0        // Docking Station
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_DOCK_GENERIC,D1
	bne .unknow_subclass_device
	lea pciinfo101(PC),A0        // (Docking Station)
	bra .add_subclass
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.processor:
	lea pciinfo110(PC),A0        // Processor
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.serial_bus:
	lea pciinfo120(PC),A0        // Serial Bus
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.wireless_controller:
	lea pciinfo130(PC),A0        // Wireless Controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.intelligent_io_controller:
	lea pciinfo140(PC),A0        // Intelligent IO Controller
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
	move.l D4,D1
	swap D1
	and.l #0xFF,D1               // subclass code
	cmp.l #PCI_INTIO_I20,D1
	bne .unknow_subclass_device
	lea pciinfo141(PC),A0        // (I20 Arch)
	bra .add_subclass
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.satellite_communication:
	lea pciinfo150(PC),A0        // Satellite Communication
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.encrytion_decryption:
	lea pciinfo160(PC),A0        // Encrytion/Decryption
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
.signal_processing:
	lea pciinfo170(PC),A0        // Signal Processing
	bsr display_string_single
#ifdef DISPLAY_SUBCLASS
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
#else
	bra.s .end_info_class
#endif /* DISPLAY_SUBCLASS */
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

	move.l 2(A0),D0          // ID
	move.w 6(A0),D1          // index

find_pci_device:

#ifndef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug40(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
#ifdef COLDFIRE
	lea -28(SP),SP
	movem.l D3-D7/A4-A5,(SP)
#else /* !COLDFIRE */
	movem.l D3-D7/A4-A5,-(SP)
#endif /* COLDFIRE */
	move.l D0,D3             // ID
	move.w D1,D5             // index
	ext.l D5
	moveq #0,D4              // slot
	moveq #0,D6              // function
	moveq #0,D7              // bus
#ifdef COLDFIRE
	move.l #PCI_MAX_SLOT,-(SP)
	ext.l D0
	cmp.l #-1,D0
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
	lea .no_pci_devices(PC),A0
	move.l 8,A5              // bus error
	move.l A0,8
	move.l SP,A4             // save ssp
	move.l #PCI_MAX_SLOT,-(SP)
	cmp.w #-1,D3
#endif
	beq.s .loop_query_all_cards
.loop_find_pci_device:                                           
			moveq #PCIIDR,D1          // Device ID & Vendor ID
			move.l D7,D0              // bus number
			mulu #PCI_MAX_FUNCTION,D0
			add.l D6,D0               // function number
			swap D0
			or.l D4,D0                // slot
			bsr fast_read_config_longword
			cmp.l D0,D3               // ID
			bne.s .next_find_pci_device
			tst.l D5             	// index
			beq .end_index_pci_device
			subq.l #1,D5
			move.l D7,D0              // bus number
			bne.s .not_bus0_find_pci_device // <> bus 0
			tst.l D4                  // slot
			beq .next_slot_find_pci_device // do not look for multi-function devices at bridge
.not_bus0_find_pci_device:
			mulu #PCI_MAX_FUNCTION,D0
			swap D0
			add.l D4,D0               // device (slot)
			moveq #PCICLSR,D1	// check for multi-function device
			bsr fast_read_config_longword
			btst #23,D0
			beq.s .next_slot_find_pci_device
.next_find_pci_device:
			addq.l #1,D6		// function
			cmp.l #PCI_MAX_FUNCTION,D6
			bcs .loop_find_pci_device
.next_slot_find_pci_device:
			moveq #0,D6
			addq.l #1,D4              // device
		cmp.l (SP),D4
		bcs .loop_find_pci_device
		move.l #PCI_MAX_DEVICE,(SP)
		moveq #0,D4               // device
		addq.l #1,D7              // bus
	cmp.l #PCI_MAX_BUS,D7
	bcs .loop_find_pci_device
	bra.s .no_pci_devices
.loop_query_all_cards:
			moveq #PCIIDR,D1
			move.l D7,D0             // bus number
			mulu #PCI_MAX_FUNCTION,D0
			add.l D6,D0              // function number
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
			move.l D7,D0             // bus number
			bne.s .not_bus0_query_all_cards // <> bus 0
			tst.l D4
			beq .next_slot_query_all_cards // don't look for multi-function-devices at bridge
.not_bus0_query_all_cards:
			mulu #PCI_MAX_FUNCTION,D0
			swap D0
			add.l D4,D0               // device (slot)
			moveq #PCICLSR,D1	// check for multi-function device
			bsr fast_read_config_longword
			btst #23,D0
			beq.s .next_slot_query_all_cards
			addq.l #1,D6
			cmp.l #PCI_MAX_FUNCTION,D6
			bcs.s .loop_query_all_cards
.next_slot_query_all_cards:
			moveq #0,D6
			addq.l #1,D4             // device
		cmp.l (SP),D4
		bcs.s .loop_query_all_cards
		move.l #PCI_MAX_DEVICE,(SP)
		moveq #0,D4               // device
		addq.l #1,D7              // bus
	cmp.l #PCI_MAX_BUS,D7
	bcs .loop_query_all_cards
.no_pci_devices:
#ifdef COLDFIRE
	addq.l #4,SP
#else
	move.l A5,8              // restore bus error
	move.l A4,SP             // restore ssp
	move.w (SP)+,SR
#endif
	moveq #PCI_DEVICE_NOT_FOUND,D0
	bra.s .end_find_pci_device
.end_index_pci_device:
#ifdef COLDFIRE
	addq.l #4,SP
#else
    	move.l A5,8              // restore bus error
	move.l A4,SP             // restore ssp
	move.w (SP)+,SR
#endif
	move.w D7,D0              // bus number
	mulu #PCI_MAX_FUNCTION,D0
	add.l D6,D0               // current function number
	swap D0
	or.l D4,D0                // slot => handle
.end_find_pci_device:
#ifdef COLDFIRE
	movem.l (SP),D3-D7/A4-A5
	lea 28(SP),SP
#else /* !COLDFIRE */
	movem.l (SP)+,D3-D7/A4-A5
#endif /* COLDFIRE */
	rts
	
_find_pci_classcode:

	move.l 2(A0),D0          // class
	move.w 6(A0),D1          // index

find_pci_classcode:

#ifndef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug41(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
#ifdef COLDFIRE
	lea -20(SP),SP
	movem.l D3-D7,(SP)
#else /* !COLDFIRE */
	movem.l D3-D7,-(SP)
#endif /* COLDFIRE */
	move.l D0,D4             // class
	moveq #0,D5
	move.w D1,D5             // index
	moveq #0,D3              // slot
	moveq #0,D6              // function
	moveq #0,D7              // bus
	move.l #PCI_MAX_SLOT,-(SP)
.loop_pci_classcode:
				moveq #PCIIDR,D1
				move.l D7,D0             // bus number
				mulu #PCI_MAX_FUNCTION,D0
				add.l D6,D0              // function number
				swap D0
				or.l D3,D0               // slot
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
				move.l D7,D0             // bus number
				mulu #PCI_MAX_FUNCTION,D0
				add.l D6,D0              // function number
				swap D0
				or.l D3,D0               // device
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
				move.l D7,D0             // bus number
				mulu #PCI_MAX_FUNCTION,D0
				add.l D6,D0              // function number
				swap D0
				or.l D3,D0               // device
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
				move.l D7,D0             // bus number
				mulu #PCI_MAX_FUNCTION,D0
				add.l D6,D0              // function number
				swap D0
				or.l D3,D0               // device
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
				move.l D7,D0             // bus number
				bne.s .not_bus0_find_pci_classcode
				tst.l D3
				beq.s .next_slot_pci_classcode // don't look for multi-function-devices at bridge
.not_bus0_find_pci_classcode:
				mulu #PCI_MAX_FUNCTION,D0
				swap D0
				add.l D3,D0               // device (slot)
				moveq #PCICLSR,D1	// check for multi-function device
				bsr fast_read_config_longword
				btst #23,D0
				beq.s .next_slot_pci_classcode
				addq.l #1,D6
			cmp.l #PCI_MAX_FUNCTION,D6
			bcs .loop_pci_classcode
.next_slot_pci_classcode:
			moveq #0,D6
			addq.l #1,D3             // device
		cmp.l (SP),D3
		bcs .loop_pci_classcode
		moveq #0,D3
		move.l #PCI_MAX_DEVICE,(SP)
		addq.l #1,D7
	cmp.l #PCI_MAX_BUS,D7
	bcs .loop_pci_classcode
	moveq #PCI_DEVICE_NOT_FOUND,D0
	bra.s .end_pci_classcode
.end_index_classcode:
	move.w D7,D0              // bus number
	mulu #PCI_MAX_FUNCTION,D0
	add.l D6,D0               // current function number
	swap D0
	or.l D3,D0                // slot => handle
.end_pci_classcode:
	addq.l #4,SP
#ifdef COLDFIRE
	movem.l (SP),D3-D7
	lea 20(SP),SP
#else /* !COLDFIRE */
	movem.l (SP)+,D3-D7
#endif /* COLDFIRE */
	rts
	
_read_config_byte:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // PCI register
	move.l 8(A0),A0          // pointer to space for read data

read_config_byte:

#ifndef COLDFIRE
#ifdef DEBUG
	move.l D3,-(SP)
	move.l D0,D3
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .ccc
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug42(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x3D,D0
	bsr debug_display_char	
	moveq #0x20,D0
	bsr debug_display_char	
	move.l (SP)+,A0
	move.l (SP)+,D0
.ccc:
#endif
#endif
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D2
	and.l D2,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
#endif
	move.l A0,A1             // address
	move.l D0,D2
	tst.l D0                 // handle
	bmi .bad_handle_read_config_byte
	beq .read_local_config_byte
	ext.l D0
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_read_config_byte
	swap D2
	ext.l D2
	bmi .bad_handle_read_config_byte
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc .bad_handle_read_config_byte
	move.l D3,-(SP)
#ifdef COLDFIRE
	move.w SR,D3
	move.l D3,-(SP)
	or.l #0x700,D3           // mask interrupts
	move.w D3,SR
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
#endif
	moveq #3,D3
	and.l D1,D3
	move.l D3,-(SP)
	move.l D2,D3
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D3
#ifdef COLDFIRE
	.chip 5200
#endif
	swap D3
	move.w D3,D2
	ext.l D2                 // function
	clr.w D3                 // bus number (B23-B16)
	tst.l D3 
	beq.s .read_config_byte_type0
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function (B10-B8) / reg (B7-B2)
	bset #0,D1               // type 1 (B0)
	or.l D3,D1               // bus number
	lea tab_pci_device2(PC),A0
	bra.s .read_config_byte_type
.read_config_byte_type0:
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
.read_config_byte_type:
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	lsl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else /* !COLDFIRE */
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
	move.l 4(SP),D2
	move.b (A0,D2.l),(A1)    // address
	move.l (SP)+,D2
	addq.l #4,SP
#ifdef COLDFIRE
	nop
	move.l D2,MCF_PCI_PCICAR
	move.l (SP)+,D1
	move.w D1,SR
#else /* !COLDFIRE */
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x38000000,D0     // Master Target Abort
	beq.s .no_master_abort_byte
	moveq #-1,D0
	move.b D0,(A1)
.no_master_abort_byte:
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.w (SP)+,SR
#endif /* COLDFIRE */
	move.l (SP)+,D3
#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D3
	bne.s .cccC
	move.l D0,-(SP)
	move.b (A1),D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
.cccC:
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_read_config_byte
.read_local_config_byte:
	ext.l D1
	cmp.l #LAST_LOCAL_REGISTER,D1
	bcc.s .bad_register_read_config_byte
	bsr read_local_config_byte
	move.b D0,(A1)
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_read_config_byte
.bad_register_read_config_byte:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	bra.s .end_read_config_byte
.bad_handle_read_config_byte:
	moveq #PCI_BAD_HANDLE,D0
.end_read_config_byte:
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D2
	move.l D2,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
#endif
#ifndef COLDFIRE
#ifdef DEBUG
	move.l (SP)+,D3
#endif
#endif
	rts
	
_read_config_word:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // PCI register
	move.l 8(A0),A0          // pointer to space for read data

read_config_word:

#ifndef COLDFIRE
#ifdef DEBUG
	move.l D3,-(SP)
	move.l D0,D3
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .ddd
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug43(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x3D,D0
	bsr debug_display_char	
	moveq #0x20,D0
	bsr debug_display_char	
	move.l (SP)+,A0
	move.l (SP)+,D0	
.ddd:
#endif
#endif
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D2
	and.l D2,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
#endif
	move.l A0,A1             // address
	btst #0,D1               // PCI register
	bne .bad_register_read_config_word
	move.l D0,D2
	tst.l D0                 // handle
	bmi .bad_handle_read_config_word
	beq .read_local_config_word
	ext.l D0
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_read_config_word
	swap D2
	ext.l D2
	bmi .bad_handle_read_config_word
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc .bad_handle_read_config_word
	move.l D3,-(SP)
#ifdef COLDFIRE
	move.w SR,D3
	move.l D3,-(SP)
	or.l #0x700,D3           // mask interrupts
	move.w D3,SR
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
#endif
	moveq #2,D3
	and.l D1,D3
	move.l D3,-(SP)
	move.l D2,D3
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D3
#ifdef COLDFIRE
	.chip 5200
#endif
	swap D3
	move.w D3,D2
	ext.l D2                 // function
	clr.w D3                 // bus number (B23-B16)
	tst.l D3 
	beq.s .read_config_word_type0
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function (B10-B8) / reg (B7-B2)
	bset #0,D1               // type 1 (B0)
	or.l D3,D1               // bus number
	lea tab_pci_device2(PC),A0
	bra.s .read_config_word_type
.read_config_word_type0:
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
.read_config_word_type:
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	lsl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else /* !COLDFIRE */
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
#ifdef COLDFIRE
	nop
	move.l D2,MCF_PCI_PCICAR
	move.l (SP)+,D1
	move.w D1,SR
#else /* !COLDFIRE */
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x38000000,D0     // Master Target Abort
	beq.s .no_master_abort_word
	moveq #-1,D0
	move.w D0,(A1)
.no_master_abort_word:
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.w (SP)+,SR
#endif /* COLDFIRE */
	move.l (SP)+,D3
#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D3
	bne.s .dddD
	move.l D0,-(SP)
	move.w (A1),D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
.dddD:
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_read_config_word
.read_local_config_word:
	ext.l D1
	cmp.l #LAST_LOCAL_REGISTER,D1
	bcc.s .bad_register_read_config_word
	bsr read_local_config_word
	move.w D0,(A1)
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_read_config_word
.bad_register_read_config_word:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	bra.s .end_read_config_word
.bad_handle_read_config_word:
	moveq #PCI_BAD_HANDLE,D0
.end_read_config_word:
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D2
	move.l D2,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
#endif
#ifndef COLDFIRE
#ifdef DEBUG
	move.l (SP)+,D3
#endif
#endif
	rts
	
_read_config_longword:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // PCI register
	move.l 8(A0),A0          // pointer to space for read data

read_config_longword:

#ifndef COLDFIRE
#ifdef DEBUG
	move.l D3,-(SP)
	move.l D0,D3
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .eee
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug44(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x3D,D0
	bsr debug_display_char	
	moveq #0x20,D0
	bsr debug_display_char	
	move.l (SP)+,A0
	move.l (SP)+,D0
.eee:
#endif
#endif
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D2
	and.l D2,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
#endif
	move.l A0,A1             // address
	moveq #3,D2
	and.l D1,D2              // PCI register
	bne .bad_register_read_config_longword
	move.l D0,D2
	tst.l D0                 // handle
	bmi .bad_handle_read_config_longword
	beq .read_local_config_longword
	ext.l D0
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_read_config_longword
	swap D2
	ext.l D2
	bmi .bad_handle_read_config_longword
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc .bad_handle_read_config_longword
#ifdef COLDFIRE /* device errata 4 */
	swap D0                  // handle
	move.w D2,D0             // function
	swap D0
	move.l A1,-(SP)          // pointer
	move.l D0,-(SP)
	move.l D1,-(SP)
	bsr fast_read_config_word// lower 16 bits
	move.w D0,D2
	move.l (SP)+,D1
	addq.l #2,D1
	move.l (SP)+,D0
	move.l (SP),A1
	move.l D2,-(SP)
	bsr fast_read_config_word// upper 16 bits
	move.l (SP)+,D2
	swap D0
	move.w D2,D0
	move.l (SP)+,A1          // pointe
	move.l D0,(A1)
#else /* !COLDFIRE errata */
	move.l D3,-(SP)
	move.l D2,D3
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D3
#ifdef COLDFIRE
	.chip 5200
#endif
	swap D3
	move.w D3,D2
	ext.l D2                 // function
	clr.w D3                 // bus number (B23-B16)
	tst.l D3 
	beq.s .read_config_longword_type0
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function (B10-B8) / reg (B7-B2)
	bset #0,D1               // type 1 (B0)
	or.l D3,D1               // bus number
	lea tab_pci_device2(PC),A0
	bra.s .read_config_longword_type
.read_config_longword_type0:
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
.read_config_longword_type:
	move.l (SP)+,D3
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D1,D2
#ifdef COLDFIRE
	move.w SR,D1
	move.l D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
#endif
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else /* !COLDFIRE */
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
	nop
	move.l D2,MCF_PCI_PCICAR
#if 0 /* another solution for device errata 4 */	
	or.l #MCF_PCI_PCICAR_E+0x00FF0000,D2 // enable config space acces with bad bus number
	move.l D2,MCF_PCI_PCICAR
	tst.l (A0)
	and.l #~MCF_PCI_PCICAR_E,D2 // disable config space access with bad bus number
	nop
	move.l D2,MCF_PCI_PCICAR
#endif	
	move.l (SP)+,D1
	move.w D1,SR
#else /* !COLDFIRE */
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x38000000,D0     // Master Target Abort
	beq.s .no_master_abort_longword
	moveq #-1,D0
	move.l D0,(A1)
.no_master_abort_longword:
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.w (SP)+,SR
#endif /* COLDFIRE */
#endif /* COLDFIRE errata */
#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D3
	bne.s .eeeE
	move.l D0,-(SP)
	move.l (A1),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
.eeeE:
#endif
#endif
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_read_config_longword
.read_local_config_longword:
	ext.l D1
	cmp.l #LAST_LOCAL_REGISTER,D1
	bcc.s .bad_register_read_config_longword
	bsr read_local_config_longword
	move.l D0,(A1)
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_read_config_longword
.bad_register_read_config_longword:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	bra.s .end_read_config_longword
.bad_handle_read_config_longword:
	moveq #PCI_BAD_HANDLE,D0
.end_read_config_longword:
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D2
	move.l D2,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
#endif
#ifndef COLDFIRE
#ifdef DEBUG
	move.l (SP)+,D3
#endif
#endif
	rts

_fast_read_config_byte:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // PCI register
	
fast_read_config_byte:

	tst.l D0                 // handle
	beq read_local_config_byte
#ifndef COLDFIRE
#ifdef DEBUG
	move.l D0,-(SP)
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .fff
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug45(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x3D,D0
	bsr debug_display_char	
	moveq #0x20,D0
	bsr debug_display_char	
	move.l (SP)+,A0
	move.l (SP)+,D0
.fff:
#endif
#endif
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D2
	and.l D2,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
	move.w SR,D2
	move.l D2,-(SP)
	or.l #0x700,D2           // mask interrupts
	move.w D2,SR
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
#endif /* COLDFIRE */
	moveq #3,D2
	and.l D1,D2
	move.l D2,-(SP)
	move.l D0,D2             // bus/function(H)/slot(L)
	ext.l D0
	swap D2
	move.l D3,-(SP)
	ext.l D2
	move.l D2,D3
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D3
#ifdef COLDFIRE
	.chip 5200
#endif
	swap D3
	move.w D3,D2
	ext.l D2                 // function
	clr.w D3                 // bus number (B23-B16)
	tst.l D3 
	beq.s .fast_read_config_byte_type0
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function (B10-B8) / reg (B7-B2)
	bset #0,D1               // type 1 (B0)
	or.l D3,D1               // bus number
	lea tab_pci_device2(PC),A0
	bra.s .fast_read_config_byte_type
.fast_read_config_byte_type0:  
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
.fast_read_config_byte_type:
	move.l (SP)+,D3
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else /* !COLDFIRE */
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
	moveq #0,D0
	move.l 4(SP),D2
	move.b (A0,D2.l),D0
	move.l (SP)+,D2
	addq.l #4,SP
#ifdef COLDFIRE
	nop
	move.l D2,MCF_PCI_PCICAR
	move.l (SP)+,D1
	move.w D1,SR
#else /* !COLDFIRE */
	move.l D0,-(SP)
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x38000000,D0     // Master Target Abort
	beq.s .fast_no_master_abort_byte
	moveq #-1,D0
	move.l D0,(SP)
.fast_no_master_abort_byte:
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.l (SP)+,D0
	move.w (SP)+,SR
#endif /* COLDFIRE */
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D2
	move.l D2,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
#endif
#ifndef COLDFIRE
#ifdef DEBUG
	move.l (SP)+,D2
	cmp.l #SLOT_TO_DEBUG,D2
	bne.s .fffF
	move.l D0,-(SP)
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
.fffF:
#endif
#endif
	rts

_fast_read_config_word:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // PCI register

fast_read_config_word:

	tst.l D0                 // handle
	beq read_local_config_word
#ifndef COLDFIRE
#ifdef DEBUG
	move.l D0,-(SP)
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .ggg
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug46(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x3D,D0
	bsr debug_display_char	
	moveq #0x20,D0
	bsr debug_display_char	
	move.l (SP)+,A0
	move.l (SP)+,D0	
.ggg:
#endif
#endif
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D2
	and.l D2,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
	move.w SR,D2
	move.l D2,-(SP)
	or.l #0x700,D2           // mask interrupts
	move.w D2,SR
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
#endif /* COLDFIRE */
	moveq #2,D2
	and.l D1,D2
	move.l D2,-(SP)
	move.l D0,D2             // bus/function(H)/slot(L)
	ext.l D0
	swap D2
	move.l D3,-(SP)
	ext.l D2
	move.l D2,D3
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D3
#ifdef COLDFIRE
	.chip 5200
#endif
	swap D3
	move.w D3,D2
	ext.l D2                 // function
	clr.w D3                 // bus number (B23-B16)
	tst.l D3 
	beq.s .fast_read_config_word_type0
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function (B10-B8) / reg (B7-B2)
	bset #0,D1               // type 1 (B0)
	or.l D3,D1               // bus number
	lea tab_pci_device2(PC),A0
	bra.s .fast_read_config_word_type
.fast_read_config_word_type0:    
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
.fast_read_config_word_type:
	move.l (SP)+,D3
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D1,D2
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else /* !COLDFIRE */
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
	nop
	move.l D2,MCF_PCI_PCICAR
	move.l (SP)+,D1
	move.w D1,SR
#else /* !COLDFIRE */
	move.l D0,-(SP)
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x38000000,D0     // Master Target Abort
	beq.s .fast_no_master_abort_word
	moveq #-1,D0
	move.l D0,(SP)
.fast_no_master_abort_word:
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.l (SP)+,D0
	move.w (SP)+,SR
#endif /* COLDFIRE */
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D2
	move.l D2,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
#endif
#ifndef COLDFIRE
#ifdef DEBUG
	move.l (SP)+,D2
	cmp.l #SLOT_TO_DEBUG,D2
	bne.s .gggG
	move.l D0,-(SP)
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
.gggG:
#endif
#endif
	rts
	
_fast_read_config_longword:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // PCI register

fast_read_config_longword:

	tst.l D0                 // handle
	beq read_local_config_longword
#ifndef COLDFIRE
#ifdef DEBUG
	move.l D0,-(SP)
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .hhh
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug47(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x3D,D0
	bsr debug_display_char	
	moveq #0x20,D0
	bsr debug_display_char	
	move.l (SP)+,A0
	move.l (SP)+,D0
.hhh:
#endif
#endif
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D2
	and.l D2,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
#endif
#ifdef COLDFIRE /* device errata 4 */
	move.l D0,-(SP)          // bus/function(H)/slot(L)
	move.l D1,-(SP)
	bsr fast_read_config_word// lower 16 bits
	move.w D0,D2
	move.l (SP)+,D1
	addq.l #2,D1
	move.l (SP)+,D0          // bus/function(H)/slot(L)
	move.l D2,-(SP)
	bsr fast_read_config_word// upper 16 bits
	move.l (SP)+,D2
	swap D0
	move.w D2,D0
#else /* !COLDFIRE errata */
	move.l D0,D2             // bus/function(H)/slot(L)
	ext.l D0
	swap D2
	move.l D3,-(SP)
	ext.l D2
	move.l D2,D3
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D3
#ifdef COLDFIRE
	.chip 5200
#endif
	swap D3
	move.w D3,D2
	ext.l D2                 // function
	clr.w D3                 // bus number (B23-B16)
	tst.l D3 
	beq.s .fast_read_config_longword_type0
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function (B10-B8) / reg (B7-B2)
	bset #0,D1               // type 1 (B0)
	or.l D3,D1               // bus number
	lea tab_pci_device2(PC),A0
	bra.s .fast_read_config_longword_type
.fast_read_config_longword_type0:    
	asl.l #8,D2              // shift function number into place
	or.l D2,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
.fast_read_config_longword_type:
	move.l (SP)+,D3
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D1,D2
#ifdef COLDFIRE
	move.w SR,D1
	move.l D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
#endif
	move.l D2,-(SP)
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2	// enable config space access
	move.l D2,MCF_PCI_PCICAR
#else /* !COLDFIRE */
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
	nop
	move.l D2,MCF_PCI_PCICAR
#if 0 /* another solution for device errata 4 */	
	or.l #MCF_PCI_PCICAR_E+0x00FF0000,D2 // enable config space acces with bad bus number
	move.l D2,MCF_PCI_PCICAR
	tst.l (A0)
	and.l #~MCF_PCI_PCICAR_E,D2 // disable config space access with bad bus number
	nop
	move.l D2,MCF_PCI_PCICAR
#endif	
	move.l (SP)+,D1
	move.w D1,SR
#else /* !COLDFIRE */
	move.l D0,-(SP)
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	and.l #0x38000000,D0     // Master Target Abort
	beq.s .fast_no_master_abort_longword
	moveq #-1,D0
	move.l D0,(SP)
.fast_no_master_abort_longword:
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.l (SP)+,D0
	move.w (SP)+,SR
#endif /* COLDFIRE */
#endif /* COLDFIRE errata */
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D2
	move.l D2,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
#endif
#ifndef COLDFIRE
#ifdef DEBUG
	move.l (SP)+,D2
	cmp.l #SLOT_TO_DEBUG,D2
	bne.s .hhhH
	move.l D0,-(SP)
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
.hhhH:
#endif
#endif
	rts
	
_write_config_byte:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // PCI register
	move.w 8(A0),D2          // data to write

write_config_byte:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .zzz
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug48(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.zzz:
#endif
#endif
	move.l D3,-(SP)
	move.l D4,-(SP)
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D3
	and.l D3,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
#endif
	move.l D0,D3             // handle
	tst.l D0
	bmi .bad_handle_write_config_byte
#ifdef COLDFIRE
	bne.s .write_config_byte_not_bridge
	cmp.l #0x60,D1           // MCF need a PCI config cycle for reset bit in SR
	bcc .write_local_config_byte
.write_config_byte_not_bridge:
#else
	beq .write_local_config_byte
#endif
	ext.l D0
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_write_config_byte
	swap D3
	ext.l D3                 // function
	bmi .bad_handle_write_config_byte
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D3
	bcc .bad_handle_write_config_byte
#ifdef COLDFIRE
	move.w SR,D4
	move.l D4,-(SP)
	or.l #0x700,D4           // mask interrupts
	move.w D4,SR
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
#endif
	moveq #3,D4
	and.l D1,D4
	move.l D4,-(SP)
	move.l D3,D4
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D4
#ifdef COLDFIRE
	.chip 5200
#endif
	swap D4
	move.w D4,D3
	ext.l D3                 // function
	clr.w D4                 // bus number (B23-B16)
	tst.l D4 
	beq.s .write_config_byte_type0
	asl.l #8,D3              // shift function number into place
	or.l D3,D1
	and.l #0x7FC,D1          // function (B10-B8) / reg (B7-B2)
	bset #0,D1               // type 1 (B0)
	or.l D4,D1               // bus number
	lea tab_pci_device2(PC),A0
	bra.s .write_config_byte_type
.write_config_byte_type0:   
	asl.l #8,D3              // shift function number into place
	or.l D3,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
.write_config_byte_type:
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
#else /* !COLDFIRE */
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
	move.l (SP)+,D2
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
	move.l 4(SP),D1
	move.b D2,(A0,D1.l)
#ifdef COLDFIRE
	jsr dummy_function       // errata, use D0
#endif
	move.l (SP)+,D2
	addq.l #4,SP
#ifdef COLDFIRE
	nop
	move.l D2,MCF_PCI_PCICAR
	move.l (SP)+,D1
	move.w D1,SR
#else /* !COLDFIRE */
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.w (SP)+,SR
#endif /* COLDFIRE */
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
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D3
	move.l D3,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
#endif
	move.l (SP)+,D4
	move.l (SP)+,D3
	rts

_write_config_word:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // PCI register
	move.w 8(A0),D2          // data to write

write_config_word:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .zzzz
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug49(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.zzzz:
#endif
#endif
	move.l D3,-(SP)
	move.l D4,-(SP)
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D3
	and.l D3,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
#endif
	btst #0,D1               // PCI register       
	bne .bad_register_write_config_word
	move.l D0,D3
	tst.l D0                 // handle
	bmi .bad_handle_write_config_word
#ifdef COLDFIRE
	bne.s .write_config_word_not_bridge
	cmp.l #0x60,D1           // MCF need a PCI config cycle for reset bit in SR
	bcc .write_local_config_word
.write_config_word_not_bridge:
#else
	beq .write_local_config_word
#endif
	ext.l D0
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_write_config_word
	swap D3
	ext.l D3                 // function
	bmi .bad_handle_write_config_word
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D3
	bcc .bad_handle_write_config_word
#ifdef COLDFIRE
	move.w SR,D4
	move.l D4,-(SP)
	or.l #0x700,D4           // mask interrupts
	move.w D4,SR
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
#endif
	moveq #2,D4
	and.l D1,D4
	move.l D4,-(SP)
	move.l D3,D4
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D4
#ifdef COLDFIRE
	.chip 5200
#endif
	swap D4
	move.w D4,D3
	ext.l D3                 // function
	clr.w D4                 // bus number (B23-B16)
	tst.l D4 
	beq.s .write_config_word_type0
	asl.l #8,D3              // shift function number into place
	or.l D3,D1
	and.l #0x7FC,D1          // function (B10-B8) / reg (B7-B2)
	bset #0,D1               // type 1 (B0)
	or.l D4,D1               // bus number
	lea tab_pci_device2(PC),A0
	bra.s .write_config_word_type
.write_config_word_type0:    
	asl.l #8,D3              // shift function number into place
	or.l D3,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
.write_config_word_type:
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
#else /* !COLDFIRE */
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
	move.l (SP)+,D2
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
#ifdef COLDFIRE
	jsr dummy_function       // errata, use D0
#endif
	move.l (SP)+,D2
	addq.l #4,SP
#ifdef COLDFIRE
	nop
	move.l D2,MCF_PCI_PCICAR
	move.l (SP)+,D1
	move.w D1,SR
#else /* !COLDFIRE */
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.w (SP)+,SR
#endif /* COLDFIRE */
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
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D3
	move.l D3,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
#endif
	move.l (SP)+,D4
	move.l (SP)+,D3
	rts
	
_write_config_longword:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // PCI register
	move.l 8(A0),D2          // data to write
	
write_config_longword:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .zzzzz
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug50(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.zzzzz:
#endif
#endif
	move.l D3,-(SP)
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIICR,-(SP)
	move.l #~(MCF_PCI_PCIICR_TAE + MCF_PCI_PCIICR_IAE + MCF_PCI_PCIICR_REE),D3
	and.l D3,MCF_PCI_PCIICR  // disable PCI XLB interrupts
#endif
#endif
	moveq #3,D3
	and.l D1,D3              // PCI register
	bne .bad_register_write_config_longword
	move.l D0,D3
	tst.l D0                 // handle
	bmi .bad_handle_write_config_longword
#ifdef COLDFIRE
	bne.s .write_config_longword_not_bridge
	cmp.l #0x60,D1           // MCF need a PCI config cycle for reset bit in SR
	bcc .write_local_config_longword
.write_config_longword_not_bridge:
#else
	beq .write_local_config_longword
#endif
	ext.l D0
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_write_config_longword
	swap D3
	ext.l D3                 // function
	bmi .bad_handle_write_config_longword
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D3
	bcc .bad_handle_write_config_longword
	move.l D4,-(SP)
	move.l D3,D4
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D4
#ifdef COLDFIRE
	.chip 5200
#endif
	swap D4
	move.w D4,D3
	ext.l D3                 // function
	clr.w D4                 // bus number (B23-B16)
	tst.l D4 
	beq.s .write_config_longword_type0
	asl.l #8,D3              // shift function number into place
	or.l D3,D1
	and.l #0x7FC,D1          // function (B10-B8) / reg (B7-B2)
	bset #0,D1               // type 1 (B0)
	or.l D4,D1               // bus number
	lea tab_pci_device2(PC),A0
	bra.s .write_config_longword_type
.write_config_longword_type0:
	asl.l #8,D3              // shift function number in place
	or.l D3,D1
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
.write_config_longword_type:
	move.l (SP)+,D4
	moveq #0,D3
	move.b (A0,D0.l),D3
	moveq #11,D0
	asl.l D0,D3              // Device Number
	or.l D3,D1
#ifdef COLDFIRE
	move.w SR,D3
	move.l D3,-(SP)
	or.l #0x700,D3           // mask interrupts
	move.w D3,SR
#else
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
#endif
	move.l D1,-(SP)
	move.l D2,-(SP)
	move.l D1,D2
#ifdef COLDFIRE
	or.l #MCF_PCI_PCICAR_E,D2
	move.l D2,MCF_PCI_PCICAR
#else /* !COLDFIRE */
	bset #31,D2              // Configuration Enable
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
#endif /* COLDFIRE */
	move.l (SP)+,D2
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
#ifdef COLDFIRE
	jsr dummy_function       // errata, use D0
#endif
	move.l (SP)+,D2
#ifdef COLDFIRE
	nop
	move.l D2,MCF_PCI_PCICAR
	move.l (SP)+,D1
	move.w D1,SR
#else /* !COLDFIRE */
	move.l #DMCFGA,D1        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr read_local_config_longword
	bclr #31,D0
	move.l D0,D2
	moveq #PCICSR,D1             // PCI Command / Status Register
	bsr write_local_config_longword // clear errors
	move.w (SP)+,SR
#endif /* COLDFIRE */
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
#ifdef COLDFIRE
#ifndef MCF5445X
	move.l MCF_PCI_PCIISR,D3
	move.l D3,MCF_PCI_PCIISR // clear interrupt
	move.l (SP)+,MCF_PCI_PCIICR
#endif
#endif
	move.l (SP)+,D3
	rts

_hook_interrupt:
	
	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 10(A0),A1         // parameter for interrupt handler
	move.l 6(A0),A0          // pointer to interrupt handler

hook_interrupt:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .iii
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug51(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.iii:
#endif
#endif
	move.l A2,-(SP)
	move.l D0,-(SP)          // handle
	move.l D0,D1
	swap D1                  // bus/function
	ext.l D0
	bmi.s .bad_handle_hook_interrupt
	cmp.l #PCI_MAX_DEVICE,D0
	bcc.s .bad_handle_hook_interrupt
	ext.l D1                 // function
	bmi.s .bad_handle_hook_interrupt
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D1
	bcc.s .bad_handle_hook_interrupt
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_hook_interrupt // not found
	add.l #PCI_COOKIE_SIZE + PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A2             // Status-Descriptors
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D1
#ifdef COLDFIRE
	.chip 5200
#endif
	move.l D1,D2
	swap D1
	ext.l D1                 // function
	ext.l D2                 // bus number
	move.l (SP),D0           // handle
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,D1
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D2
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
	move.l (SP),D0           // handle
	bsr enable_interrupt
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_hook_interrupt
.general_error_hook_interrupt:
	moveq #PCI_GENERAL_ERROR,D0
	bra.s .end_hook_interrupt
.bad_handle_hook_interrupt:
	moveq #PCI_BAD_HANDLE,D0
.end_hook_interrupt:
	addq.l #4,SP
	move.l (SP)+,A2
	rts
	
_unhook_interrupt:
	
	move.l 2(A0),D0          // bus/function(H)/slot(L)
	
unhook_interrupt:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .jjj
	move.l A0,-(SP)
	lea debug52(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.jjj:
#endif
#endif
	move.l D0,-(SP)          // handle
	move.l D0,D1
	swap D1                  // function
	ext.l D0
	bmi.s .bad_handle_unhook_interrupt
	cmp.l #PCI_MAX_DEVICE,D0
	bcc.s .bad_handle_unhook_interrupt
	ext.l D1                 // function
	bmi.s .bad_handle_unhook_interrupt
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D1
	bcc.s .bad_handle_unhook_interrupt
	move.l (SP),D0           // handle
	bsr disable_interrupt
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_unhook_interrupt // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A1             // Status-Descriptors
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D1
#ifdef COLDFIRE
	.chip 5200
#endif
	move.l D1,D2
	swap D1
	ext.l D1                 // function
	ext.l D2                 // bus number
	move.l (SP),D0           // handle
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,D1
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D2
	add.l D2,D1  	
	mulu #PCI_DEV_DES_SIZE,D1
	clr.l PCI_DEV_DES_HANDLER(A1,D1.l)
	clr.l PCI_DEV_DES_PARAMETER(A1,D1.l)
	addq.l #4,SP
	moveq #PCI_SUCCESSFUL,D0
	rts
.general_error_unhook_interrupt:
	addq.l #4,SP
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_unhook_interrupt:
	addq.l #4,SP
	moveq #PCI_BAD_HANDLE,D0
	rts

_special_cycle:

	move.w 2(A0),D0          // bus number
	move.l 4(A0),D1          // special cycle data
	
special_cycle:

#ifndef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug53(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
	moveq #PCI_FUNC_NOT_SUPPORTED,D0
	rts
	
_get_routing:
	
	move.l 2(A0),D0          // bus/function(H)/slot(L)

get_routing:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .lll
	move.l A0,-(SP)
	lea debug54(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.lll:
#endif
#endif
	ext.l D0                 // handle
	bmi.s .bad_handle_set_routing
	cmp.l #PCI_MAX_DEVICE,D0
	bcc.s .bad_handle_set_routing
	moveq #PCI_FUNC_NOT_SUPPORTED,D0
	rts
.bad_handle_set_routing:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_set_interrupt:
	
	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.w 6(A0),D1          // mode

set_interrupt:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .mmm
	move.l A0,-(SP)
	lea debug55(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.mmm:
#endif
#endif
	ext.l D0                 // handle
	bmi.s .bad_handle_set_interrupt
#ifndef COLDFIRE
	beq.s .local_set_interrupt
#endif
	cmp.l #PCI_MAX_DEVICE,D0
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

	move.l 2(A0),D0          // bus/function(H)/slot(L)

get_resource:

#ifndef COLDFIRE
#ifdef DEBUG
	move.l D0,D2
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .nnn
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug56(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x3D,D0
	bsr debug_display_char
	moveq #0x20,D0
	bsr debug_display_char
	move.l (SP)+,A0
	move.l (SP)+,D0
.nnn:
#endif
#endif
	move.l D0,D1             // slot
	swap D1                  // function
	ext.l D0
	bmi .bad_handle_get_resource
	cmp.l #PCI_MAX_DEVICE,D0
	bcc.s .bad_handle_get_resource
	ext.l D1                 // function
	bmi.s .bad_handle_get_resource
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D1
	bcc.s .bad_handle_get_resource	
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D1
#ifdef COLDFIRE
	.chip 5200
#endif
	move.l D1,D2
	swap D1
	ext.l D1                 // function
	ext.l D2                 // bus number
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,D1
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D2
	add.l D2,D1
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_get_resource // not found
	mulu #PCI_RSC_DESC_TOTALSIZE,D1
	add.l #PCI_COOKIE_SIZE,D0 // Ressource-Descriptors
	add.l D1,D0	
#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D2
	bne.s .nn
	move.l D0,-(SP)
	move.l D0,A0
	move.l (A0)+,D0
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #3,D2
.nnnn:
		move.l (A0)+,D0
		bsr debug_hex_long
		moveq #0x20,D0
		bsr debug_display_char
	dbf D2,.nnnn
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
.nn:
#endif
#endif
	rts
.general_error_get_resource:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_get_resource:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_get_card_used:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),A0          // address
	
get_card_used:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .ooo
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug57(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l (SP)+,A0
	move.l (SP)+,D0
.ooo:
#endif
#endif
	move.l D0,D1             // handle
	swap D1                  // function
	ext.l D0
	bmi.s .bad_handle_get_card_used
	cmp.l #PCI_MAX_DEVICE,D0
	bcc.s .bad_handle_get_card_used
	ext.l D1
	bmi.s .bad_handle_get_card_used
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D1
	bcc.s .bad_handle_get_card_used
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D1
#ifdef COLDFIRE
	.chip 5200
#endif
	move.l D1,D2
	swap D1
	ext.l D1                 // function
	ext.l D2                 // bus number
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,D1
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D2
	add.l D2,D1  
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

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),A0          // callback
	
set_card_used:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .ppp
	move.l A0,-(SP)
	lea debug58(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.ppp:
#endif
#endif
	move.l D0,D1             // handle
	swap D1                  // function
	ext.l D0
	bmi.s .bad_handle_set_card_used
	cmp.l #PCI_MAX_DEVICE,D0
	bcc.s .bad_handle_set_card_used
	ext.l D1
	bmi.s .bad_handle_set_card_used
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D1
	bcc.s .bad_handle_set_card_used
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D1
#ifdef COLDFIRE
	.chip 5200
#endif
	move.l D1,D2
	swap D1
	ext.l D1                 // function
	ext.l D2                 // bus number
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,D1
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D2
	add.l D2,D1    
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

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory
	
read_mem_byte:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .qqq
	move.l A0,-(SP)
	lea debug59(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.qqq:
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_mem_byte
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_read_mem_byte
	ext.l D2
	bmi .bad_handle_read_mem_byte
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc .bad_handle_read_mem_byte
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A1
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	move.l pci_memory_offset(A1),A1
#else
	lea PCI_MEMORY_OFFSET,A1
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
#ifdef BIG_ENDIAN
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D2
	eor.l D2,D1              // offset
#endif
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_read_mem_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_mem_word:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory

read_mem_word:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .rrr
	move.l A0,-(SP)
	lea debug60(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.rrr:
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_mem_word
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_read_mem_word
	ext.l D2
	bmi .bad_handle_read_mem_word
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc .bad_handle_read_mem_word
	btst #0,D1
	bne .bad_alignment_read_mem_word
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A1
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	move.l pci_memory_offset(A1),A1
#else
	lea PCI_MEMORY_OFFSET,A1
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
#ifdef BIG_ENDIAN
	move.w (A1,D1.l),(A0)    // pointer to data in memory
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D2
	eor.l D2,D1              // address to access (in PCI memory address space)
#endif
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
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_read_mem_word:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_read_mem_word:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_mem_longword:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory
	
read_mem_longword:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .sss
	move.l A0,-(SP)
	lea debug61(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.sss:
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_mem_longword
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_read_mem_longword
	ext.l D2
	bmi .bad_handle_read_mem_longword
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc .bad_handle_read_mem_longword
	moveq #3,D0
	and.l D1,D0
	bne .bad_alignment_read_mem_longword
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A1
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	move.l pci_memory_offset(A1),A1
#else
	lea PCI_MEMORY_OFFSET,A1
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
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
#if 0 // #ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .ttt
	move.l A0,-(SP)
	lea debug62(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.ttt:
#endif
#endif
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A0
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),A0
#else
	lea PCI_MEMORY_OFFSET,A0
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
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
	rts
	
_fast_read_mem_word:

	move.l 6(A0),D1          // address to access (in PCI memory address space)

fast_read_mem_word:

#ifndef COLDFIRE
#if 0 // #ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .uuu
	move.l A0,-(SP)
	lea debug63(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.uuu:
#endif
#endif
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A0
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),A0
#else
	lea PCI_MEMORY_OFFSET,A0
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.w (A0,D1.l),D0
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
#endif
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
	rts
	
_fast_read_mem_longword:

	move.l 6(A0),D1          // address to access (in PCI memory address space)

fast_read_mem_longword:

#ifndef COLDFIRE
#if 0 // #ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .vvv
	move.l A0,-(SP)
	lea debug64(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.vvv:
#endif
#endif
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A0
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),A0
#else
	lea PCI_MEMORY_OFFSET,A0
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
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
	rts

_write_mem_byte:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.w 10(A0),D2         // data to write
	
// write_mem_byte:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_mem_byte
	cmp.l #PCI_MAX_DEVICE,D0
	bcc.s .bad_handle_write_mem_byte
	move.l A1,D0
	swap D0                  // function
	ext.l D0
	bmi.s .bad_handle_write_mem_byte
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D0
	bcc.s .bad_handle_write_mem_byte
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A0
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),A0
#else
	lea PCI_MEMORY_OFFSET,A0
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
#endif
	move.b D2,(A0,D1.l)      // data to write
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_write_mem_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
write_mem_byte: // faster for X86EMU

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .xxxx
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug65(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.xxxx:
#endif
#endif
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A0
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),A0
#else
	lea PCI_MEMORY_OFFSET,A0
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
#endif
	move.b D2,(A0,D1.l)      // data to write
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

_write_mem_word:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.w 10(A0),D2         // data to write
	
// write_mem_word:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_mem_word
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_write_mem_word
	move.l A1,D0
	swap D0                  // function
	ext.l D0
	bmi.s .bad_handle_write_mem_word
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D0
	bcc.s .bad_handle_write_mem_word
	btst #0,D1
	bne.s .bad_alignment_write_mem_word
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A0
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),A0
#else
	lea PCI_MEMORY_OFFSET,A0
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
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
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .xxxxx
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug66(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.xxxxx:
#endif
#endif
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A0
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),A0
#else
	lea PCI_MEMORY_OFFSET,A0
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
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
	moveq #PCI_SUCCESSFUL,D0
	rts
	
_write_mem_longword:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),D2         // data to write

// write_mem_longword:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_mem_longword
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_write_mem_longword
	move.l A1,D0
	swap D0                  // function
	ext.l D0
	bmi .bad_handle_write_mem_longword
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D0
	bcc.s .bad_handle_write_mem_longword
	moveq #3,D0
	and.l D1,D0
	bne.s .bad_alignment_write_mem_longword
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A0
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),A0
#else
	lea PCI_MEMORY_OFFSET,A0
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
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
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .xxxxxx
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug67(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.xxxxxx:
#endif
#endif
#ifdef SAME_CPU_PCI_MEM_ADDR
	move.l D1,A0
	moveq #0,D1
#else /* !SAME_CPU_PCI_MEM_ADDR */
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_memory_offset(A0),A0
#else
	lea PCI_MEMORY_OFFSET,A0
#endif
#endif /* SAME_CPU_PCI_MEM_ADDR */
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
	moveq #PCI_SUCCESSFUL,D0
	rts

_read_io_byte:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.l 10(A0),A0         // pointer to data in memory

read_io_byte:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .aaaa
	move.l A0,-(SP)
	lea debug68(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.aaaa:
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_io_byte
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_read_io_byte
	ext.l D2
	bmi .bad_handle_read_io_byte
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc .bad_handle_read_io_byte
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	move.l pci_io_offset(A1),A1
#else 
	lea PCI_IO_OFFSET,A1
#endif
#ifdef BIG_ENDIAN
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_read_io_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_io_word:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.l 10(A0),A0         // pointer to data in memory
	
read_io_word:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .bbbb
	move.l A0,-(SP)
	lea debug69(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.bbbb:
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_io_word
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_read_io_word
	ext.l D2
	bmi .bad_handle_read_io_word
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc .bad_handle_read_io_word
	btst #0,D1
	bne .bad_alignment_read_io_word
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	move.l pci_io_offset(A1),A1
#else 
	lea PCI_IO_OFFSET,A1
#endif
#ifdef BIG_ENDIAN
	move.w (A1,D1.l),(A0)    // pointer to data in memory
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
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
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_read_io_word:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_read_io_word:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_io_longword:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory

read_io_longword:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .cccc
	move.l A0,-(SP)
	lea debug70(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.cccc:
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi .bad_handle_read_io_longword
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_read_io_longword
	ext.l D2
	bmi .bad_handle_read_io_longword
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc .bad_handle_read_io_longword
	moveq #3,D0
	and.l D1,D0
	bne .bad_alignment_read_io_longword
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	move.l pci_io_offset(A1),A1
#else 
	lea PCI_IO_OFFSET,A1
#endif
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
#if 0 // #ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .dddd
	move.l A0,-(SP)
	lea debug71(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.dddd:
#endif
#endif
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
	rts

_fast_read_io_word:

	move.l 6(A0),D1          // address to access (in PCI I/O address space)

fast_read_io_word:

#ifndef COLDFIRE
#if 0 // #ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .eeee
	move.l A0,-(SP)
	lea debug72(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.eeee:
#endif
#endif
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.w (A0,D1.l),D0
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
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
	rts
	
_fast_read_io_longword:

	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	
fast_read_io_longword:

#ifndef COLDFIRE
#if 0 // #ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .ffff
	move.l A0,-(SP)
	lea debug73(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.ffff:
#endif
#endif
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
	rts
	
_write_io_byte:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.w 10(A0),D2         // data to write
	
// write_io_byte:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_io_byte
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_write_io_byte
	move.l A1,D0
	swap D0                 // function
	ext.l D0
	bmi.s .bad_handle_write_io_byte
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D0
	bcc.s .bad_handle_write_io_byte
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
	move.b D2,(A0,D1.l)      // data to write
#endif
#ifdef COLDFIRE
	jsr dummy_function       // errata, use D0
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_write_io_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts

write_io_byte: // faster for X86EMU

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .yyyy
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug74(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.yyyy:
#endif
#endif
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
#ifdef LITTLE_ENDIAN_ADDRESSES_SWAPPED
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
#endif
	move.b D2,(A0,D1.l)      // data to write
#endif
#ifdef COLDFIRE
	jsr dummy_function       // errata, use D0
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

_write_io_word:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.w 10(A0),D2         // data to write

// write_io_word:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_io_word
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_write_io_word
	move.l A1,D0
	swap D0                 // function
	ext.l D0
	bmi.s .bad_handle_write_io_word
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D0
	bcc.s .bad_handle_write_io_word
	btst #0,D1
	bne.s .bad_alignment_write_io_word
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
#endif /* BIG_ENDIAN */
#ifdef COLDFIRE
	jsr dummy_function       // errata, use D0
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
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .yyyyy
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug75(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.yyyyy:
#endif
#endif
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
#endif /* BIG_ENDIAN */
#ifdef COLDFIRE
	jsr dummy_function       // errata, use D0
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

_write_io_longword:

	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.l 10(A0),D2         // data to write

// write_io_longword:

	move.l D0,A1
	ext.l D0                 // handle
	bmi .bad_handle_write_io_longword
	cmp.l #PCI_MAX_DEVICE,D0
	bcc .bad_handle_write_io_longword
	move.l A1,D0
	swap D0                 // function
	ext.l D0
	bmi .bad_handle_write_io_longword
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D0
	bcc.s .bad_handle_write_io_longword
	moveq #3,D0
	and.l D1,D0
	bne.s .bad_alignment_write_io_longword
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
#endif /* BIG_ENDIAN */
#ifdef COLDFIRE
	jsr dummy_function       // errata, use D0
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
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .yyyyyy
	move.l A0,-(SP)
	move.l D0,-(SP)
	lea debug76(PC),A0
	bsr debug_display_string
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D1,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l D2,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
	move.l (SP)+,A0
.yyyyyy:
#endif
#endif
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A0
	move.l pci_io_offset(A0),A0
#else 
	lea PCI_IO_OFFSET,A0
#endif
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
#endif /* BIG_ENDIAN */
#ifdef COLDFIRE
	jsr dummy_function       // errata, use D0
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts

_get_machine_id:
get_machine_id:

	// 0: Medusa/Hades
	// 1: Milan
	// 2: PAK/Panther
	// 3: Aranym
#ifndef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug77(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
	moveq #0,D0              // no ID available
	rts

_get_pagesize:
get_pagesize:

#ifndef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug78(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
	moveq #0,D0              // paging not active
	rts
	
_virt_to_bus:
	
	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // address in virtual CPU space 
	move.l 10(A0),A0         // ptr
	
virt_to_bus:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .iiii
	move.l A0,-(SP)
	lea debug79(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.iiii:
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi.s .bad_handle_virt_to_bus
	cmp.l #PCI_MAX_DEVICE,D0
	bcc.s .bad_handle_virt_to_bus
	ext.l D2
	bmi.s .bad_handle_virt_to_bus
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc.s .bad_handle_virt_to_bus
	move.l D1,D0             // address in virtual CPU space
#ifndef SAME_CPU_PCI_MEM_ADDR
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	sub.l pci_memory_offset(A1),D0
#else
	sub.l #PCI_MEMORY_OFFSET,D0 // cannot work for I/O space 
#endif
#endif
	move.l D0,PCI_CONV_ADDR_ADDR(A0) // PCI bus address
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	move.l pci_memory_size(A1),D0
#else
	move.l #PCI_MEMORY_SIZE,D0
#endif
	move.l D0,PCI_CONV_ADDR_LEN(A0) // length of contiguous mapped area
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_virt_to_bus:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_bus_to_virt:
	
	move.l 2(A0),D0          // bus/function(H)/slot(L)
	move.l 6(A0),D1          // PCI bus address 
	move.l 10(A0),A0         // ptr

bus_to_virt:

#ifndef COLDFIRE
#ifdef DEBUG
	cmp.l #SLOT_TO_DEBUG,D0
	bne.s .jjjj
	move.l A0,-(SP)
	lea debug80(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
.jjjj:
#endif
#endif
	move.l D0,D2
	swap D2                  // function
	ext.l D0                 // handle
	bmi.s .bad_handle_bus_to_virt
	cmp.l #PCI_MAX_DEVICE,D0
	bcc.s .bad_handle_bus_to_virt
	ext.l D2
	bmi.s .bad_handle_bus_to_virt
	cmp.l #PCI_MAX_FUNCTION*PCI_MAX_BUS,D2
	bcc.s .bad_handle_bus_to_virt
	move.l D1,D0             // PCI bus address 
#ifndef SAME_CPU_PCI_MEM_ADDR
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	add.l pci_memory_offset(A1),D0
#else
	add.l #PCI_MEMORY_OFFSET,D0 // cannot work for I/O space
#endif
#endif
	move.l D0,PCI_CONV_ADDR_ADDR(A0) // CPU virtual address
#ifdef PCI_DYNAMIC_MAPPING
	move.l phystop,A1
	move.l pci_memory_size(A1),D0
#else
	move.l #PCI_MEMORY_SIZE,D0
#endif
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

#ifndef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug81(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
	move.l D0,PCI_CONV_ADDR_ADDR(A0) // physical CPU virtual address
	clr.l PCI_CONV_ADDR_LEN(A0) // length of contiguous mapped area
	moveq #PCI_SUCCESSFUL,D0
	rts

_phys_to_virt:

	move.l 2(A0),D0          // physical CPU address 
	move.l 6(A0),A0          // ptr

phys_to_virt:

#ifndef COLDFIRE
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug82(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
#endif
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
	bra.s .status_dma_buffoper2
.status_dma_buffoper:
	move.l #DMASCR0,D1       // DMA Channel 0 Command/Status
	bsr read_local_config_byte
.status_dma_buffoper2:
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

#ifdef COLDFIRE
_dma_lock:
#endif
_dma_alloc:
_dma_free:

	moveq #0,D0
	rts

#ifndef COLDFIRE

dma_lock:

	move.l 4(SP),D0          // mode
	bra.s .dl1
	
_dma_lock:  /* CTPCI DMA freeze workaround */

	move.w 2(A0),D0          // mode
.dl1:
	cmp.w #-2,D0
	bne.s .dl2
	lea dma_lock(PC),A0
	move.l A0,D0
	rts
.dl2:
	bmi.s .dl3
	nop	
.dl3:
	moveq #-1,D0
	rts

#endif /* COLDFIRE */

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
	rts

read_local_config_word:

	lea PCI_LOCAL_CONFIG,A0
	cmp.l #PLX9054_SWAPPED,(A0)
	beq.s .read_local_config_word_little
	moveq #2,D0
	eor.l D0,D1              // offset
.read_local_config_word_little:
	move.w (A0,D1.l),D0
	cmp.l #PLX9054_SWAPPED,(A0)
	bne.s .read_local_config_word_big
	ror.w #8,D0              // read data
.read_local_config_word_big:
	rts

read_local_config_longword:

	lea PCI_LOCAL_CONFIG,A0
	move.l (A0,D1.l),D0
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
	moveq #PCI_SUCCESSFUL,D0
	rts
	
write_local_config_word:

	lea PCI_LOCAL_CONFIG,A0
	cmp.l #PLX9054_SWAPPED,(A0)
	beq.s .write_local_config_word_little
	moveq #2,D0
	eor.l D0,D1              // offset
	move.w D2,(A0,D1.l)
	moveq #PCI_SUCCESSFUL,D0
	rts
.write_local_config_word_little:
	ror.w #8,D2              // data to write
	move.w D2,(A0,D1.l)
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
	moveq #PCI_SUCCESSFUL,D0
	rts

#ifdef DEBUG

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

#endif /* CHECK_PARITY */
	
pci_interrupt:

	move.l D0,D5             // 0: bridge, 1+:num int host for get INTA-D 
	moveq #0,D2              // interrupt handled
	moveq #PCI_MAX_SLOT,D3   // primary bus
	moveq #0,D4              // slot
	moveq #0,D6              // function
	moveq #0,D7              // bus
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .interrupt_cookie_not_found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A2             // Status-Descriptors
	add.l #PCI_DEV_HANDLESTOTALSIZE,D0
	move.l D0,A4             // used interrupt table
	move.l D0,A5
.loop_interrupt:
				moveq #0,D0
				move.b (A4),D0
				beq.s .interrupt_next_handle // not used for this handle
				cmp.l D5,D0              // num int
				bne.s .interrupt_next_handle // not for this interrupt
				move.l PCI_DEV_DES_HANDLER(A2),D0
				beq.s .end_interrupt     // abnormal
				move.l D0,A3
				moveq #0,D0              // return value
				move.l D0,-(SP)          // BIOS internal data
				move.l PCI_DEV_DES_PARAMETER(A2),-(SP) // parameter for interrupt handler
				jsr (A3)
				addq.l #8,SP
				and.l #1,D0
				or.l D0,D2
				tst.l D0
				bne.s .interrupt_ok      // interrupt was from this card
				bra.s .interrupt_next_handle
.end_interrupt:
				move.l D7,D0             // bus number
				mulu #PCI_MAX_FUNCTION,D0
				add.l D6,D0              // function number
				swap D0
				or.l D4,D0               // slot
				bsr disable_interrupt
				bra.s .interrupt_next_handle
.interrupt_ok:
				move.l D5,D0             // num int
				bsr clear_interrupt
#ifdef COLDFIRE /* problems with CTPCI */
				move.l D5,D0             // num int
				bsr test_interrupt
#if 1
				bne.s .interrupt_next_handle
				rts                      // interrupt not active and finished
#else /* was */
				beq .loop_interrupt      // interrupt always active
#endif
#endif /* COLDFIRE */
.interrupt_next_handle:
				add.l #PCI_DEV_DES_SIZE,A2
				addq.l #1,A4
				add.l #1,D6              // function
			cmp.l #PCI_MAX_FUNCTION,D6
			bcs .loop_interrupt
			moveq #0,D6              // function
			addq.l #1,D4             // slot
		cmp.l D3,D4
		bcs .loop_interrupt
#if (PCI_MAX_DEVICE != PCI_MAX_SLOT)
		mulu #PCI_MAX_FUNCTION,D3
		sub.l D3,A4
		mulu #PCI_DEV_DES_SIZE,D3
		sub.l D3,A2                  // Status-Descriptors
		moveq #PCI_MAX_DEVICE,D3
		move.l D3,D4
		mulu #PCI_MAX_FUNCTION,D4
		add.l D4,A4
		mulu #PCI_DEV_DES_SIZE,D4
		add.l D4,A2                  // Status-Descriptors
#endif
		moveq #0,D4                  // handle
		addq.l #1,D7
	cmp.l #PCI_MAX_BUS,D7
	bcs .loop_interrupt
	tst.l D2
	bne.s .end_of_interrupt                   // interrupt handled
.interrupt_cookie_not_found:
	// problem => disable this interrupt on all devices
	moveq #PCI_MAX_SLOT,D3   // primary bus
	moveq #0,D4              // slot
	moveq #0,D6              // function
	moveq #0,D7              // bus
.loop_disable:
				moveq #0,D0
				move.b (A5),D0
				beq.s .disable_next_handle // not used for this handle
				cmp.l D5,D0              // num int
				bne.s .disable_next_handle // not for this interrupt
				move.l D7,D0             // bus number
				mulu #PCI_MAX_FUNCTION,D0
				add.l D6,D0              // function number
				swap D0
				or.l D4,D0               
				bsr disable_interrupt
.disable_next_handle:
				addq.l #1,A5
				add.l #1,D6              // function
			cmp.l #PCI_MAX_FUNCTION,D6
			bcs.s .loop_disable
			moveq #0,D6              // function
			addq.l #1,D4             // slot
		cmp.l D3,D4
		bcs.s .loop_disable
#if (PCI_MAX_DEVICE != PCI_MAX_SLOT)
		mulu #PCI_MAX_FUNCTION,D3
		sub.l D3,A5
		moveq #PCI_MAX_DEVICE,D3
		move.l D3,D4
		mulu #PCI_MAX_FUNCTION,D4
		add.l D4,A5
#endif
		moveq #0,D4                  // handle
		addq.l #1,D7
	cmp.l #PCI_MAX_BUS,D7
	bcs.s .loop_disable
.end_of_interrupt:
	rts

test_int_not_used:

	move.l A0,-(SP)
	move.l D1,-(SP)
	move.l #PCI_INT_HANDLESTOTALSIZE-1,D1
	moveq #0,D0              // search how many times the interrupt is used
.loop_int_not_used:
		tst.b (A0)+ // 0:no INT, 1+:num int host for get INTA-D
		beq.s .int_not_used
		addq.l #1,D0
.int_not_used:
	subq.l #1,D1
	bpl.s .loop_int_not_used
	move.l (SP)+,D1
	move.l (SP)+,A0
	tst.l D0
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

#else /* MCF548X-7X */

#ifdef MCF547X /* FIREBEE */

enable_interrupt:                     // D0.L: handle

	move.l A0,-(SP)
	move.l D1,-(SP)
	move.w SR,D1
	move.l D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
	move.l D0,D1             // handle
	beq .end_enable          // bridge
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .end_enable          // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE+PCI_DEV_HANDLESTOTALSIZE,D0
	move.l D0,A0             // used int table
	move.l D1,D0             // bus/function(H)/slot(L)
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,A0              // offset slot
	move.l D1,D0
	swap D0
	ext.l D0                 // bus/function
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D0
#ifdef COLDFIRE
	.chip 5200
#endif
	move.l D0,-(SP)
	ext.l D0                 // bus
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D0
	add.l D0,A0              // offset bus
	move.l (SP)+,D0
	clr.w D0
	swap D0                  // function
	add.l D0,A0              // offset function
	move.l A0,-(SP)
	move.l D1,D0             // handle
	moveq #PCIIPR,D1         // Interrupt Pin
	bsr fast_read_config_byte// 0:no INT, 1:INTA, 2:INTB, 3:INTC, 4:INTD
	moveq #0,D1
	move.b D0,D1
	move.l (SP)+,A0
	tst.l D1
	beq.s .end_enable
	subq.l #1,D1
	moveq #0,D0
	move.b PCI_INT_HANDLESTOTALSIZE(A0),D0 // slot offset 0-3
	add.l D0,D1
	and.l #3,D1              // INTA-D
	moveq #ACP_INT_PCI_INTA,D0
	asl.l D1,D0
	move.b D0,(A0)           // use INTx for this handle
	or.l #ACP_INT_ACP_IRQ5,D0
	or.l D0,ACP_INTERRUPT_ENABLE          
	move.b MCF_EPORT_EPIER,D0
	or.l #MCF_EPORT_EPIER_EPIE5,D0
	move.b D0,MCF_EPORT_EPIER
	moveq #5,D0
	bset.b D0,MCF_EPORT_EPFR // clear interrupt
	move.l #~(MCF_INTC_IMRL_INT_MASK5 + MCF_INTC_IMRL_MASKALL),D0
	and.l D0,MCF_INTC_IMRL
.end_enable:
	move.l (SP)+,D1
	move.w D1,SR
	move.l (SP)+,D1
	move.l (SP)+,A0
	rts

disable_interrupt:                    // D0.L: handle

	move.l A1,-(SP)
	move.l A0,-(SP)
	move.l D1,-(SP)
	move.w SR,D1
	move.l D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
	move.l D0,D1             // handle
	beq .end_disable         // bridge
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .end_disable         // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE+PCI_DEV_HANDLESTOTALSIZE,D0
	move.l D0,A0
	move.l D0,A1
	move.l D1,D0             // bus/function(H)/slot(L)
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,A1              // offset slot
	move.l D1,D0
	swap D0
	ext.l D0                 // bus/function
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D0
#ifdef COLDFIRE
	.chip 5200
#endif
	move.l D0,-(SP)
	ext.l D0                 // bus
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D0
	add.l D0,A1              // offset bus
	move.l (SP)+,D0
	clr.w D0
	swap D0                  // function
	add.l D0,A1              // offset function
	move.l A1,-(SP)
	move.l A0,-(SP)
	move.l D1,D0             // handle
	moveq #PCIIPR,D1         // Interrupt Pin
	bsr fast_read_config_byte// 0:no INT, 1:INTA, 2:INTB, 3:INTC, 4:INTD
	moveq #0,D1
	move.b D0,D1
	move.l (SP)+,A0
	move.l (SP)+,A1
	tst.l D1
	beq.s .end_disable
	subq.l #1,D1
	moveq #0,D0
	move.b PCI_INT_HANDLESTOTALSIZE(A1),D0 // slot offset 0-3
	add.l D0,D1
	and.l #3,D1              // INTA-D
	clr.b (A1)               // not use INTx for this handle
	bsr test_int_not_used
	bne.s .end_disable       // used on another handle
	moveq #~ACP_INT_PCI_INTA,D0
	asl.l D1,D0
	and.l D0,ACP_INTERRUPT_ENABLE    
.end_disable:
	move.l (SP)+,D1
	move.w D1,SR
	move.l (SP)+,D1
	move.l (SP)+,A0
	move.l (SP)+,A1
	rts

clear_interrupt:

	ext.l D0
	bne.s .int_clear
	rts
.int_clear:
	or.l D0,ACP_INTERRUPT_CLEAR // clear interrupt
	rts

test_interrupt:

	ext.l D0
	bne.s .test_int
	move.l MCF_INTC_IPRH,D0
	btst #41-32,D0
	seq.b D0
	and.l #1,D0              // 1: interrupt is finished
	rts
.test_int:
	and.l ACP_INTERRUPT_CLEAR,D0
	seq.b D0
	and.l #1,D0              // 1: interrupt is finished
	rts

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int5_pci:	                         // INTA-D

	move.w #0x2700,SR        // for FreeRTOS native interrupts
	lea -60(SP),SP
	movem.l D0-A6,(SP)
	moveq #3,D7
	moveq #ACP_INT_PCI_INTA,D6
.int_abcd_loop:
		move.l ACP_INTERRUPT_CLEAR,D0 // state
		and.l ACP_INTERRUPT_ENABLE,D0
		and.l D6,D0
		beq.s .next_int_abcd
		move.l D7,-(SP)
		move.l D6,-(SP)
		bsr pci_interrupt
		move.l (SP)+,D6
		move.l (SP)+,D7
.next_int_abcd:
		add.l D6,D6
	subq.l #1,D7
	bpl .int_abcd_loop
	moveq #ACP_INT_PCI_INTD+ACP_INT_PCI_INTC+ACP_INT_PCI_INTB+ACP_INT_PCI_INTA,D0
	move.l D0,ACP_INTERRUPT_CLEAR
	moveq #5,D0
	bset.b D0,MCF_EPORT_EPFR // clear interrupt
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rte

#else /* MCF548X - M5484LITE-M5485EVB */

enable_interrupt:                     // D0.L: handle

	move.l A0,-(SP)
	move.l D1,-(SP)
	move.w SR,D1
	move.l D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
	move.l D0,D1             // handle
	beq .end_enable          // bridge
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .end_enable          // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE+PCI_DEV_HANDLESTOTALSIZE,D0
	move.l D0,A0             // used int table
	move.l D1,D0             // bus/function(H)/slot(L)
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,A0              // offset slot
	move.l D1,D0
	swap D0
	ext.l D0                 // bus/function
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D0
#ifdef COLDFIRE
	.chip 5200
#endif
	move.l D0,-(SP)
	ext.l D0                 // bus
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D0
	add.l D0,A0              // offset bus
	move.l (SP)+,D0
	clr.w D0
	swap D0                  // function
	add.l D0,A0              // offset function
	move.l D1,D0
	ext.l D0                 // handle => slot
	cmp.l #3,D0              // TODO: FIX for bus
	bcc.s .slot_enable
	// on board M5485EVB devices
.enable_int5:
	moveq #5,D0
	move.b D0,(A0)           // use INT5 for this handle
	move.b MCF_EPORT_EPIER,D0
	or.l #MCF_EPORT_EPIER_EPIE5,D0
	move.b D0,MCF_EPORT_EPIER
	move.l #~(MCF_INTC_IMRL_INT_MASK5 + MCF_INTC_IMRL_MASKALL),D0
	and.l D0,MCF_INTC_IMRL
	bra.s .end_enable
.slot_enable:                         // M5484LITE: INT7: INTA-B, INT5 INTC-D
	move.l A0,-(SP)
	move.l D0,-(SP)          // slot
	move.l D1,D0             // handle
	moveq #PCIIPR,D1         // Interrupt Pin
	bsr fast_read_config_byte// 0:no INT, 1:INTA, 2:INTB, 3:INTC, 4:INTD
	moveq #0,D1
	move.b D0,D1
	move.l (SP)+,D0          // slot
	move.l (SP)+,A0
	tst.l D1
	beq.s .end_enable
	// slot 3: INT7: INTA-B, INT5 INTC-D, slot4 (riser): INT7: INTB-A, INT5 INTD-C
	subq.l #1,D1
	cmpl #4,D0
	bne.s .not_a_riser
	bchg #0,D1
.not_a_riser:
	cmp.l #2,D1
	bcc.s .enable_int5
	moveq #7,D0
	move.b D0,(A0)           // use INT7 for this handle
	move.b MCF_EPORT_EPIER,D0
	or.l #MCF_EPORT_EPIER_EPIE7,D0
	move.b D0,MCF_EPORT_EPIER
	move.l #~(MCF_INTC_IMRL_INT_MASK7 + MCF_INTC_IMRL_MASKALL),D0
	and.l D0,MCF_INTC_IMRL
.end_enable:
	move.l (SP)+,D1
	move.w D1,SR
	move.l (SP)+,D1
	move.l (SP)+,A0
	rts

disable_interrupt:                    // D0.L: handle

	move.l A1,-(SP)
	move.l A0,-(SP)
	move.l D1,-(SP)
	move.w SR,D1
	move.l D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
	move.l D0,D1             // handle
	beq .end_disable         // bridge
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .end_disable         // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE+PCI_DEV_HANDLESTOTALSIZE,D0
	move.l D0,A0
	move.l D0,A1
	move.l D1,D0             // bus/function(H)/slot(L)
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,A1              // offset slot
	move.l D1,D0
	swap D0
	ext.l D0                 // bus/function
#ifdef COLDFIRE
	.chip 68060
#endif
	divu #PCI_MAX_FUNCTION,D0
#ifdef COLDFIRE
	.chip 5200
#endif
	move.l D0,-(SP)
	ext.l D0                 // bus
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D0
	add.l D0,A1              // offset bus
	move.l (SP)+,D0
	clr.w D0
	swap D0                  // function
	add.l D0,A1              // offset function
	move.l D1,D0
	ext.l D0                 // handle => slot
	cmp.l #3,D0              // TODO: FIX for bus
	bcc.s .slot_disable
	// on board M5485EVB devices
.disable_int5:
	clr.b (A1)               // not use INT5 for this handle
	bsr test_int_not_used
	bne .end_disable         // used on another handle
	move.l #MCF_INTC_IMRL_INT_MASK5,D0
	or.l D0,MCF_INTC_IMRL
	move.b MCF_EPORT_EPIER,D0
	and.l #~MCF_EPORT_EPIER_EPIE5,D0
	move.b D0,MCF_EPORT_EPIER
	bra.s .end_disable
.slot_disable:
	move.l A1,-(SP)
	move.l A0,-(SP)
	move.l D0,-(SP)          // slot
	move.l D1,D0             // handle
	moveq #PCIIPR,D1         // Interrupt Pin
	bsr fast_read_config_byte// 0:no INT, 1:INTA, 2:INTB, 3:INTC, 4:INTD
	moveq #0,D1
	move.b D0,D1
	move.l (SP)+,D0          // slot
	move.l (SP)+,A0
	move.l (SP)+,A1
	tst.l D1
	beq.s .end_disable
	// slot 3: INT7: INTA-B, INT5 INTC-D, slot4 (riser): INT7: INTB-A, INT5 INTD-C
	subq.l #1,D1
	cmpl #4,D0
	bne.s .not_a_riser2
             bchg #0,D1
.not_a_riser2:
	cmp.l #2,D1
	bcc.s .disable_int5
	clr.b (A1)               // not use INT7 for this handle
	bsr test_int_not_used
	bne.s .end_disable       // used on another handle
	move.l #MCF_INTC_IMRL_INT_MASK7,D0
	or.l D0,MCF_INTC_IMRL
	move.b MCF_EPORT_EPIER,D0
	and.l #~MCF_EPORT_EPIER_EPIE7,D0
	move.b D0,MCF_EPORT_EPIER
.end_disable:
	move.l (SP)+,D1
	move.w D1,SR
	move.l (SP)+,D1
	move.l (SP)+,A0
	move.l (SP)+,A1
	rts

clear_interrupt:

	ext.l D0
	bne.s .usb_clear
	rts
.usb_clear:
	cmp.l #7,D0
	beq.s .slot_clear
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
	seq.b D0
	and.l #1,D0              // 1: interrupt is finished
	rts
.usb_test_interrupt:
	cmp.l #7,D0
	beq.s .slot_test_interrupt
	move.l MCF_INTC_IPRL,D0
	btst #5,D0
	seq.b D0
	and.l #1,D0              // 1: interrupt is finished
	rts
.slot_test_interrupt:
	move.l MCF_INTC_IPRL,D0
	btst #7,D0
	seq.b D0
	and.l #1,D0              // 1: interrupt is finished
	rts

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

	// INT7 call by software INT2 (can be masked)	
int2_pci:	                         // INTA-B

	move.w #0x2700,SR        // for FreeRTOS native interrupts
	move.l D0,-(SP)
	lea -56(SP),SP
	movem.l D1-A6,(SP)
	move.l #~MCF_INTC_INTFRCL_INTFRC2,D0
	and.l D0,MCF_INTC_INTFRCL
	moveq #7,D0
	bsr pci_interrupt
	movem.l (SP),D1-A6
	lea 56(SP),SP
    	move.l #MCF_INTC_IMRL_INT_MASK7,D0
	and.l MCF_INTC_IMRL,D0
	bne.s .not_int7          // INT7 disabled by the handler
	move.b MCF_EPORT_EPIER,D0
	or.l #MCF_EPORT_EPIER_EPIE7,D0 // enable
	move.b D0,MCF_EPORT_EPIER
.not_int7:
	move.l (SP)+,D0
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0
	
int5_pci:	                         // INTC-D

	move.w #0x2700,SR        // for FreeRTOS native interrupts
	lea -60(SP),SP
	movem.l D0-A6,(SP)
	moveq #5,D0
	bsr pci_interrupt
	moveq #5,D0
	bset.b D0,MCF_EPORT_EPFR // clear interrupt
	movem.l (SP),D0-A6
	lea 60(SP),SP
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int7_pci:	                         // INTA-B

	move.l D0,-(SP)
	move.b MCF_EPORT_EPIER,D0
	and.l #~MCF_EPORT_EPIER_EPIE7,D0 // disable
	move.b D0,MCF_EPORT_EPIER
	moveq #7,D0
	bset.b D0,MCF_EPORT_EPFR // clear interrupt
	move.l #MCF_INTC_INTFRCL_INTFRC2,D0
	or.l D0,MCF_INTC_INTFRCL // force INT 2
	move.l (SP)+,D0
	rte
	
#endif /* MCF547X */

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
	move.l D2,-(SP)
	move.l MCF_PCI_PCIGSCR,D0 // PERR and SERR seems on this interrupt
	move.l D0,MCF_PCI_PCIGSCR
	move.l MCF_PCI_PCIISR,D0
	move.l D0,MCF_PCI_PCIISR
	moveq #0,D0              // bridge
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr fast_read_config_longword
	move.l D0,-(SP)          // value
	move.l D0,D2
	moveq #0,D0              // bridge
	moveq #PCICSR,D1         // PCI Command / Status Register
	bsr write_config_longword // clear errors
	move.l (SP)+,D0
	move.l #MCF_PCI_PCISCR_PE,D1
	and.l D0,D1
	beq.s .no_parity_error
#if 0 // #ifdef DEBUG
	move.l A0,-(SP)
	lea debug42(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#else
	nop	
#endif
.no_parity_error:
	move.l #MCF_PCI_PCISCR_MA,D1
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
	move.l #MCF_PCI_PCISCR_TR,D1
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
	move.l (SP)+,D2
	move.l (SP)+,D1
	move.l (SP)+,D0
	rte
	
#endif /* MCF5445X */
	
#else  /* ATARI - CTPCI/PLX9054 */

enable_interrupt:                     // D0.L: handle

	move.l A0,-(SP)
	move.l D1,-(SP)
	move.w SR,-(SP)
	or.w #0x700,SR           // mask interrupts
	move.l D0,D1             // handle
	beq .end_enable          // bridge
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .local_enable        // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE+PCI_DEV_HANDLESTOTALSIZE,D0
	move.l D0,A0             // used int table
	move.l D1,D0             // bus/function(H)/slot(L)
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,A0              // offset slot
	move.l D1,D0
	swap D0
	ext.l D0                 // bus/function
	divu #PCI_MAX_FUNCTION,D0
	move.l D0,-(SP)
	ext.l D0                 // bus
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D0
	add.l D0,A0              // offset bus
	move.l (SP)+,D0
	clr.w D0
	swap D0                  // function
	add.l D0,A0              // offset function
	move.l A0,-(SP)
	move.l D1,D0             // handle
	moveq #PCIIPR,D1         // Interrupt Pin
	bsr fast_read_config_byte// 0:no INT, 1:INTA, 2:INTB, 3:INTC, 4:INTD
	moveq #0,D1
	move.b D0,D1
	move.l (SP)+,A0
	tst.l D1
	beq.s .end_enable
	subq.l #1,D1
	moveq #0,D0
	move.b PCI_INT_HANDLESTOTALSIZE(A0),D0 // slot offset 0-3
	add.l D0,D1
	and.l #3,D1              // INTA-D
	addq.l #1,D1
	bset.b D1,PCI_CTPCI_CONFIG_ENABI // mask INTD /INTC / INTB / INTA / LINT
	move.b D1,(A0)           // use INTx for this handle
	bra.s .end_enable
.local_enable: // hardware not works ???
//	bset.b #0,PCI_CTPCI_CONFIG_ENABI // mask INTD /INTC / INTB / INTA / LINT
	nop                      // else GAS produce bug with the previous bra.s .end_enable
.end_enable:
	move.w (SP)+,SR
	move.l (SP)+,D1
	move.l (SP)+,A0
	rts

disable_interrupt:                    // D0.L: handle

	movem.l D1/A0-A1,-(SP)
	move.w SR,-(SP)
	or.w #0x700,SR           // mask interrupts
	move.l D0,D1             // handle
	beq .local_disable       // bridge
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .end_disable         // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE+PCI_DEV_HANDLESTOTALSIZE,D0
	move.l D0,A0
	move.l D0,A1
	move.l D1,D0             // bus/function(H)/slot(L)
	mulu #PCI_MAX_FUNCTION,D0
	add.l D0,A1              // offset slot
	move.l D1,D0
	swap D0
	ext.l D0                 // bus/function
	divu #PCI_MAX_FUNCTION,D0
	move.l D0,-(SP)
	ext.l D0                 // bus
	mulu #PCI_MAX_FUNCTION*PCI_MAX_DEVICE,D0
	add.l D0,A1              // offset bus
	move.l (SP)+,D0
	clr.w D0
	swap D0                  // function
	add.l D0,A1              // offset function
	move.l A1,-(SP)
	move.l A0,-(SP)
	move.l D1,D0             // handle
	moveq #PCIIPR,D1         // Interrupt Pin
	bsr fast_read_config_byte// 0:no INT, 1:INTA, 2:INTB, 3:INTC, 4:INTD
	moveq #0,D1
	move.b D0,D1
	move.l (SP)+,A0
	move.l (SP)+,A1
	tst.l D1
	beq.s .end_disable
	subq.l #1,D1
	moveq #0,D0
	move.b PCI_INT_HANDLESTOTALSIZE(A1),D0 // slot offset 0-3
	add.l D0,D1
	and.l #3,D1              // INTA-D
	clr.b (A1)               // not use INTx for this handle
	bsr test_int_not_used
	bne.s .end_disable       // used on another handle
	addq.l #1,D1
	bclr.b D1,PCI_CTPCI_CONFIG_ENABI // mask INTD / INTC / INTB / INTA / LINT
	bra.s .end_disable
.local_disable:
	bclr.b #0,PCI_CTPCI_CONFIG_ENABI // mask INTD / INTC / INTB / INTA / LINT
.end_disable:
	move.w (SP)+,SR
	movem.l (SP)+,D1/A0-A1
	rts

clear_interrupt:

	rts

test_interrupt:

#if 0
	tst.w D0                 // LINT
	bne.s .slots_test_interrupt
	move.l #INTCSR,D1        // Interrupt Control/Status
	bsr read_local_config_longword
	and.l #0x00F0E000,D0
	seq.b D0
	and.l #1,D0              // 1: interrupt is finished
	rts
.slots_test_interrupt:
#endif
	btst.b D0,PCI_CTPCI_CONFIG_ENABI
	beq.s .test_int_disabled
	btst.b D0,PCI_CTPCI_CONFIG_PEND // INTD / INTC / INTB / INTA / LINT
	seq.b D0
	and.l #1,D0              // 1: interrupt is finished
	rts
.test_int_disabled:
	moveq #1,D0              // 1: interrupt is finished
	rts

pci_interrupt_rtos:

	move.l 4(SP),D0
	movem.l D2-D7/A2-A6,-(SP)
	bsr pci_interrupt
	movem.l (SP)+,D2-D7/A2-A6
	rts

	dc.l 0x5F504349          // _PCI
	dc.l pci_interrupt_rtos
	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int_ctpci:
	
	movem.l D0-A6,-(SP)
	moveq #0,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
	rte

	dc.l 0x5F504349          // _PCI
	dc.l pci_interrupt_rtos
	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0
	
inta_ctpci:

	movem.l D0-A6,-(SP)
	moveq #1,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
	rte

	dc.l 0x5F504349          // _PCI
	dc.l pci_interrupt_rtos
	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0
	
intb_ctpci:

	movem.l D0-A6,-(SP)
	moveq #2,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
	rte

	dc.l 0x5F504349          // _PCI
	dc.l pci_interrupt_rtos
	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

intc_ctpci:

	movem.l D0-A6,-(SP)
	moveq #3,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
	rte

	dc.l 0x5F504349          // _PCI
	dc.l pci_interrupt_rtos
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
#ifdef MCF547X /* FIREBEE */
	.byte 16                 // host bridge MCF547X
	// AD17 is the USB Controller
	// AD18 and more are slots ?
	.byte 17,18,19,20,21,22,23,24,25,26,27,28,29,30 // device number n where AD[n] select IDSEL
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
	.byte 20-11              // host bridge PLX9054
	.byte 21-11,22-11,23-11,24-11 // device number n-11 where AD[n] select IDSEL
#endif /* COLDFIRE */
tab_pci_device2:
	.byte  0, 1, 2, 3, 4, 5, 6, 7
	.byte  8, 9,10,11,12,13,14,15
	.byte 16,17,18,19,20,21,22,23
	.byte 24,25,26,27,28,29,30,31

pciinfo0:	.asciz "Device built before Class Code definitions"
#ifdef DISPLAY_SUBCLASS
pciinfo1:	.asciz "(All except VGA)"
pciinfo2:	.asciz "(VGA compatible)"
pciinfo9:	.asciz "(unknown)"
#endif

pciinfo10:	.asciz "Mass Storage Controller "
#ifdef DISPLAY_SUBCLASS
pciinfo11:	.asciz "(SCSI bus)"
pciinfo12:	.asciz "(IDE)"
pciinfo13:	.asciz "(Floppy disk)"
pciinfo14:	.asciz "(IPI bus)"
pciinfo15:	.asciz "(RAID)"
pciinfo16:	.asciz "(ATA)"
pciinfo17:	.asciz "(SATA)"
#endif
	
pciinfo20:	.asciz "Network Controller "
#ifdef DISPLAY_SUBCLASS
pciinfo21:	.asciz "(Ethernet)"
pciinfo22:	.asciz "(Token Ring)"
pciinfo23:	.asciz "(FDDI)"
pciinfo24:	.asciz "(ATM)"
pciinfo25:	.asciz "(ISDM)"
pciinfo26:	.asciz "(WorldFip)"
pciinfo27:	.asciz "(PICMG)"
#endif

pciinfo30:	.asciz "Display Controller "
#ifdef DISPLAY_SUBCLASS
pciinfo31:	.asciz "(VGA)"
pciinfo32:	.asciz "(XGA)"
pciinfo33:	.asciz "(3D)"
#endif
	
pciinfo40:	.asciz "Multimedia Controller "
#ifdef DISPLAY_SUBCLASS
pciinfo41:	.asciz "(Video)"
pciinfo42:	.asciz "(Audio)"
pciinfo43:	.asciz "(Computer Telephony)"
#endif
	
pciinfo50:	.asciz "Memory controller "
#ifdef DISPLAY_SUBCLASS
pciinfo51:	.asciz "(RAM)"
pciinfo52:	.asciz "(FLASH)"
#endif

pciinfo60:	.asciz "Bridge Controller "
#ifdef DISPLAY_SUBCLASS
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
#endif

pciinfo70:	.asciz "Communications Controller "
#ifdef DISPLAY_SUBCLASS
pciinfo71:	.asciz "(XT Compatible Serial)"
pciinfo72:	.asciz "(Parallel Port)"
pciinfo73:	.asciz "(Multiport Serial)"
pciinfo74:	.asciz "(Modem Controller)"
pciinfo75:	.asciz "(GPIB Controller)"
pciinfo76:	.asciz "(Smart Card)"
#endif

pciinfo80:	.asciz "Peripheral Controller "
#ifdef DISPLAY_SUBCLASS
pciinfo81:	.asciz "(PIC)"
pciinfo82:	.asciz "(DMA)"
pciinfo83:	.asciz "(System Timer)"
pciinfo84:	.asciz "(RTC)"
pciinfo85:	.asciz "(PCI Hot-Plug)"
#endif

pciinfo90:	.asciz "Input Device "
#ifdef DISPLAY_SUBCLASS
pciinfo91:	.asciz "(Keyboard)"
pciinfo92:	.asciz "(Digitizer)"
pciinfo93:	.asciz "(Mouse)"
pciinfo94:	.asciz "(Scanner)"
pciinfo95:	.asciz "(Gameport)"
#endif

pciinfo100:	.asciz "Docking Station "
#ifdef DISPLAY_SUBCLASS
pciinfo101:	.asciz "(Docking Station)"
#endif

pciinfo110:	.asciz "Processor "
#ifdef DISPLAY_SUBCLASS
pciinfo111:	.asciz "(386)"
pciinfo112:	.asciz "(486)"
pciinfo113:	.asciz "(Pentium)"
pciinfo114:	.asciz "(Alpha)"
pciinfo115:	.asciz "(PowerPC)"
pciinfo116:	.asciz "(MIPS)"
pciinfo117:	.asciz "(Coprocessor)"
#endif

pciinfo120:	.asciz "Serial Bus "
#ifdef DISPLAY_SUBCLASS
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
#endif

pciinfo130:	.asciz "Wireless Controller "
#ifdef DISPLAY_SUBCLASS
pciinfo131:	.asciz "(iRDA Compatible)"
pciinfo132:	.asciz "(Consumer IR)"
pciinfo133:	.asciz "(RF)"
pciinfo134:	.asciz "(Bluetooth)"
pciinfo135:	.asciz "(Broadband)"
pciinfo136:	.asciz "(Ethernet 802.11a)"
pciinfo137:	.asciz "(Ethernet 802.11b)"
#endif

pciinfo140:	.asciz "Intelligent IO Controller "
#ifdef DISPLAY_SUBCLASS
pciinfo141:	.asciz "(I20 Arch)"
#endif

pciinfo150:	.asciz "Satellite Communication "
#ifdef DISPLAY_SUBCLASS
pciinfo151:	.asciz "(TV)"
pciinfo152:	.asciz "(Audio)"
pciinfo153:	.asciz "(Voice)"
pciinfo154:	.asciz "(DATA)"
#endif

pciinfo160:	.asciz "Encrytion/Decryption "
#ifdef DISPLAY_SUBCLASS
pciinfo161:	.asciz "(Network and Computing)"
pciinfo162:	.asciz "(Entertainment en/decrypt)"
#endif

pciinfo170:	.asciz "Signal Processing "
#ifdef DISPLAY_SUBCLASS
pciinfo171:	.asciz "(DPIO modules)"
pciinfo172:	.asciz "(Perf. counters)"
pciinfo173:	.asciz "(Comm. synchro)"
pciinfo174:	.asciz "(Management)"
#endif

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
	.ascii "CTPCI trouv‚e, recherche cartes PCI..."
	.byte 13,10,0
#endif
separator:
	.asciz " | "
hor_separator:
	.ascii "-----------------------------------------------------------------------"
	.byte 13,10,0
begin_table:
	.ascii " Bus | Slot | Fctn | VendorID | DeviceID | Description"
	.byte 13,10,0
separators:
	.byte 13,10
	.asciz "     |      |      | "
no_device:
	.ascii " 0xFFFF  |          | no device"
	.byte 13,10,0
no_more_io_space:
	.ascii "no more IO-space available !!!"
	.byte 13,10,0
no_more_mem_space:
	.ascii "no more MEM-space !!!"
	.byte 13,10,0
no_more_memory_below_1mb:
	.ascii "no more memory space below 1 MB !!!"
	.byte 13,10,0
need_more_than_4gb:
	.ascii "device requests more than 4GB memory !!!"
	.byte 13,10,0
unknow_memory_type:
	.ascii "device requests unknown memory type !!!"
	.byte 13,10,0
#ifdef CHECK_PARITY
parity_error:
	.ascii "detected parity error"
	.byte 13,10,0
#endif
desc_io:
	.asciz "I/O Address "
desc_mem:
	.asciz "MEM Address "
desc_size:
	.asciz " Size "
_66mhz:
	.asciz " 66 MHz"
