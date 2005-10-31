/*  PCI BIOS for CT60 with CTPCI
 * 
 * Didier Mequignon August 2005, e-mail: aniplay@wanadoo.fr
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

#define BIG_ENDIAN

#define PCI_BIOS_REV         0x10000

#define PCI_IRQ_BASE_VECTOR      112
/* note: Ethernat use 0x80000000-0x8000003F space and interrupts vectors 0xC4-0xC5 */
#define PCI_LOCAL_CONFIG  0xC0000000   /* CT60 bus slot - no cache - reserved */
#define PCI_MEMORY_OFFSET 0x40000000   /* CT60 bus slot - cache */
#define PCI_MEMORY_SIZE   0x40000000   /* 1024 MB */ 
#define PCI_IO_OFFSET     0xB0000000   /* CT60 bus slot - no cache */
#define PCI_IO_SIZE       0x10000000   /* 256 MB */
#define GRAPHIC_CARD_SIZE 0x10000000

#define PCI_MAX_HANDLE             4   /* 3 slots only on the CTPCI + host bridge PLX9054 */

#define PCI_NOBODYHOME        0xFFFF

/* PLX9054 ID */
#define PLX9054           0x905410B5

/* PLX9054 local configuration registers */
#define LAS0RR                0x80   /* Local Address Space 0 Range
                                        Register for PCI-to-Local Bus       */
#define LAS0BA                0x84   /* Local Address Space 0 Local Base
                                        Address (Remap)                     */
#define MARBRS                0x88   /* Mode/DMA Arbitration                */
#define BIGEND                0x8C   /* Big/Little Endian Descriptor        */
#define LMISC                 0x8D   /* Local Miscellaneous Control         */
#define PROT_AREA             0x8E   /* Serial EEPROM Write-Protect
                                        Address Boundary                    */
#define EROMRR                0x90   /* Expansion ROM Range                 */
#define EROMBA                0x94   /* Expansion ROM Local Base Address
                                        (Remap)                             */
#define LBRD0                 0x98   /* Local Address Space 0/Expansion ROM
                                        Bus Region Descriptor               */
#define DMRR                  0x9C   /* Local Range Register for PCI 
                                        Initiator-to-PCI                    */
#define DMLBAM                0xA0   /* Local Bus Base Address Register for
                                        PCI Initiator-to-PCI Memory         */
#define DMLBAI                0xA4   /* Local Bus Base Address Register for
                                        PCI Initiator-to-PCI I/O Config     */
#define DMPBAM                0xA8   /* PCI Base Address (Remap) Register
                                        for PCI Initiator-to-PCI Memory     */
#define DMCFGA                0xAC   /* PCI Configuration Address Register
                                        for PCI Initiator-to-PCI I/O Config */
#define OPQIS                 0xB0   /* Outbound Post Queue Post Queue 
                                        Interrupt Status                    */
#define OPQIM                 0xB4   /* Outbound Post Queue Post Queue 
                                        Interrupt Mask                      */
#define MBOX0                 0xC0   /* Mailbox Register 0                  */
#define MBOX1                 0xC4   /* Mailbox Register 1                  */
#define MBOX2                 0xC8   /* Mailbox Register 2                  */
#define MBOX3                 0xCC   /* Mailbox Register 3                  */
#define MBOX4                 0xD0   /* Mailbox Register 4                  */
#define MBOX5                 0xD4   /* Mailbox Register 5                  */
#define MBOX6                 0xD8   /* Mailbox Register 6                  */
#define MBOX7                 0xDC   /* Mailbox Register 7                  */
#define P2LDBELL              0xE0   /* PCI-to-Local Doorbell               */
#define L2PDBELL              0xE4   /* Local-to-PCI Doorbell               */
#define INTCSR                0xE8   /* Interrupt Control/Status            */
#define CNTRL                 0xEC   /* Serial EEPROM Control, PCI Command
                                        Codes, User I/O Ctrl, and Init Ctrl */
#define PCIHIDR               0xF0   /* PCI Hardcoded Configuration ID      */
#define PCIHREV               0xF4   /* PCI Hardcoded Revision ID           */
#define DMAMODE0             0x100   /* DMA Channel 0 Mode                  */
#define DMAPADR0             0x104   /* DMA Channel 0 PCI Address           */
#define DMALADR0             0x108   /* DMA Channel 0 Local Address         */
#define DMASIZ0              0x10C   /* DMA Channel 0 Transfer Size (Bytes) */
#define DMADPR0              0x110   /* DMA Channel 0 Descriptor Pointer    */
#define DMAMODE1             0x114   /* DMA Channel 1 Mode                  */
#define DMAPADR1             0x118   /* DMA Channel 1 PCI Address           */
#define DMALADR1             0x11C   /* DMA Channel 1 Local Address         */
#define DMASIZ1              0x120   /* DMA Channel 1 Transfer Size (Bytes) */
#define DMADPR1              0x124   /* DMA Channel 1 Descriptor Pointer    */
#define DMASCR0              0x128   /* DMA Channel 0 Command/Status        */
#define DMASCR1              0x129   /* DMA Channel 1 Command/Status        */
#define DMAARB               0x12C   /* DMA Arbitration                     */
#define DMATHR               0x130   /* DMA Threshold                       */
#define DMADAC0              0x134   /* DMA Channel 0 PCI Dual Address
                                        Cycle Address                       */
#define DMADAC1              0x134   /* DMA Channel 1 PCI Dual Address
                                        Cycle Address                       */
#define MQCR                 0x140   /* Messaging Queue Configuration       */
#define QBAR                 0x144   /* Queue Base Address                  */
#define IFHPR                0x148   /* Inbound Free Head Pointer           */
#define IFTPR                0x14C   /* Inbound Free Tail Pointer           */
#define IPHPR                0x150   /* Inbound Post Head Pointer           */
#define IPTPR                0x154   /* Inbound Post Tail Pointer           */
#define OFHPR                0x158   /* Outbound Free Head Pointer          */
#define OFTPR                0x15C   /* Outbound Free Tail Pointer          */
#define OPHPR                0x160   /* Outbound Post Head Pointer          */
#define OPTPR                0x164   /* Outbound Post Tail Pointer          */
#define QSR                  0x168   /* Queue Status/Control                */
#define LAS1RR               0x170   /* Local Address Space 1 Range Register
                                        for PCI-to-Local Bus                */
#define LAS1BA               0x174   /* Local Address Space 1 Local Base
                                        Address (Remap)                     */
#define LBRD1                0x178   /* Local Address Space 1 Bus Region
                                        Descriptor                          */
#define DMDAC                0x17C   /* PCI Initiator PCI Dual Address Cycle*/

/* PLX9054 configuration registers */
#define PCIIDR                0x00   /* PCI Configuration ID Register       */
#define PCICSR                0x04   /* PCI Command/Status Register         */
#define PCICR                 0x04   /* PCI Command Register                */
#define PCISR                 0x06   /* PCI Status Register                 */
#define PCIREV                0x08   /* PCI Revision ID Register            */
#define PCICCR                0x09   /* PCI Class Code Register             */
#define PCICLSR               0x0C   /* PCI Cache Line Size Register        */
#define PCILTR                0x0D   /* PCI Latency Timer Register          */
#define PCIHTR                0x0E   /* PCI Header Type Register            */
#define PCIBISTR              0x0F   /* PCI Build-In Self Test Register     */
#define PCIBAR0               0x10   /* PCI Base Address Register for Memory
                                        Accesses to Local, Runtime, and DMA */
#define PCIBAR1               0x14   /* PCI Base Address Register for I/O
                                        Accesses to Local, Runtime, and DMA */
#define PCIBAR2               0x18   /* PCI Base Address Register for Memory
                                        Accesses to Local Address Space 0   */
#define PCIBAR3               0x1C   /* PCI Base Address Register for Memory
                                        Accesses to Local Address Space 1   */ 
#define PCIBAR4               0x20   /* PCI Base Address Register, reserved */
#define PCIBAR5               0x24   /* PCI Base Address Register, reserved */
#define PCICIS                0x28   /* PCI Cardbus CIS Pointer, not support*/
#define PCISVID               0x2C   /* PCI Subsystem Vendor ID             */
#define PCISID                0x2E   /* PCI Subsystem ID                    */
#define PCIERBAR              0x30   /* PCI Expansion ROM Base Register     */
#define CAP_PTR               0x34   /* New Capability Pointer              */
#define PCIILR                0x3C   /* PCI Interrupt Line Register         */
#define PCIIPR                0x3D   /* PCI Interrupt Pin Register          */
#define PCIMGR                0x3E   /* PCI Min_Gnt Register                */
#define PCIMLR                0x3F   /* PCI Max_Lat Register                */
#define PMCAPID               0x40   /* Power Management Capability ID      */
#define PMNEXT                0x41   /* Power Management Next Capability
                                        Pointer                             */
#define PMC                   0x42   /* Power Management Capabilities       */
#define PMCSR                 0x44   /* Power Management Control/Status     */
#define PMCSR_BSE             0x46   /* PMCSR Bridge Support Extensions     */
#define PMDATA                0x47   /* Power Management Data               */
#define HS_CNTL               0x48   /* Hot Swap Control                    */
#define HS_NEXT               0x49   /* Hot Swap Next Capability Pointer    */
#define HS_CSR                0x4A   /* Hot Swap Control/Status             */
#define PVPDCNTL              0x4C   /* PCI Vital Product Data Control      */
#define PVPD_NEXT             0x4D   /* PCI Vital Product Data Next
                                        Capability Pointer                  */
#define PVPDAD                0x4E   /* PCI Vital Product Data Address      */
#define PVPDATA               0x50   /* PCI VPD Data                        */

/* Command register bit definitions */
#define PCI_CMDREG_IOSP          1   /* Enable IO space accesses            */
#define PCI_CMDREG_MEMSP         2   /* Enable MEM space accesses           */
#define PCI_CMDREG_MASTR         4   /* Enable PCI Mastership               */
#define PCI_CMDREG_SPCYC         8   /* Monitor special cycles              */
#define PCI_CMDREG_MEMWINV    0x10   /* Enable memory write and invalidate  */
#define PCI_CMDREG_VGASNP     0x20   /* Enable VGA palette snooping         */
#define PCI_CMDREG_PERR       0x40   /* Enable Parity error response        */
#define PCI_CMDREG_STEP       0x80   /* Enable address/data stepping        */
#define PCI_CMDREG_SERR      0x100   /* Enable SERR driver                  */
#define PCI_CMDREG_FSTB2B    0x200   /* Enable back to back transactions    */

/* Status register bit definitions */
#define PCI_STATREG_66M       0x20   /* 66MHz Capable                       */
#define PCI_STATREG_UDF       0x40   /* UDF Supoorted                       */
#define PCI_STATREG_TFBBC     0x80   /* Fast Back to Back capable           */
#define PCI_STATREG_DP_D     0x100   /* data data parity error              */
#define PCI_STATREG_SPEED    0x600   /* device speed mask                   */
#define PCI_STATREG_S_TA     0x800   /* Signalled Target Abort              */
#define PCI_STATREG_R_TA    0x1000   /* Received Target Abort               */
#define PCI_STATREG_R_MA    0x2000   /* Received Master Abort               */
#define PCI_STATREG_S_SERR  0x4000   /* Signalled SERR#                     */
#define PCI_STATREG_D_PE    0x8000   /* Detected Parity Error               */

/* Base register bit definitions */
#define	PCI_BASE_SPACE_M         1   /* memory space indicator              */
#define	PCI_BASE_SPACE_IO        1   /* IO space                            */
#define	PCI_BASE_SPACE_MEM       0   /* memory space                        */
#define	PCI_BASE_TYPE_MEM        0   /* 32-bit memory address               */
#define	PCI_BASE_TYPE_LOW        2   /* less than 1Mb address               */
#define	PCI_BASE_TYPE_ALL        4   /* 64-bit memory address               */
#define	PCI_BASE_TYPE_RES        6   /* reserved                            */
#define	PCI_BASE_TYPE_M		0x00000006  /* type indicator mask              */
#define	PCI_BASE_PREF_M		0x00000008  /* prefetch mask                    */
#define	PCI_BASE_M_ADDR_M	0xFFFFFFF0  /* memory address mask              */
#define	PCI_BASE_IO_ADDR_M	0xFFFFFFFC  /* I/O address mask                 */
#define	PCI_BASE_ROM_ADDR_M	0xFFFFF800  /* ROM address mask                 */
#define	PCI_BASE_ROM_ENABLE	0x00000001  /* ROM decoder enable               */

/* PCI Class codes */
#define PCI_CLASS_NONE           0   /* class code for pre-2.0 devices      */
#define PCI_CLASS_MASS           1   /* Mass Storage Controller class       */
#define PCI_CLASS_NET            2   /* Network Controller class            */
#define PCI_CLASS_DISPLAY        3   /* Display Controller class            */
#define PCI_CLASS_MM             4   /* Multimedia Controller class         */
#define PCI_CLASS_MEM            5   /* Memory Controller class             */
#define PCI_CLASS_BRIDGE         6   /* Bridge Controller class             */
#define PCI_CLASS_COMM           7   /* Communications Controller class     */
#define PCI_CLASS_PERIPH         8   /* Peripheral Controller class         */
#define PCI_CLASS_INPUT          9   /* Input Device class                  */
#define PCI_CLASS_DOCK          10   /* Docking Station class               */
#define PCI_CLASS_PROCESSOR     11   /* Processor class                     */
#define PCI_CLASS_SERIALBUS     12   /* Serial Bus class                    */
#define PCI_CLASS_WIRELESS      13   /* Wireless Controller class           */
#define PCI_CLASS_INTIO         14   /* Intelligent IO Controller class     */
#define PCI_CLASS_SATELLITE     15   /* Satellite Communication class       */
#define PCI_CLASS_CRYPT         16   /* Encrytion/Decryption class          */
#define PCI_CLASS_SIGNAL        17   /* Signal Processing class             */

/* PCI Sub-class codes - base class 0 (no new devices should use this code) */
#define PCI_NONE_NOTVGA          0   /* All devices except VGA compatible   */
#define PCI_NONE_VGA             1   /* VGA compatible                      */

/* PCI Sub-class codes - base class 1 (mass storage controllers) */
#define PCI_MASS_SCSI            0   /* SCSI bus Controller                 */
#define PCI_MASS_IDE             1   /* IDE Controller                      */
#define PCI_MASS_FD              2   /* floppy disk Controller              */
#define PCI_MASS_IPI             3   /* IPI bus Controller                  */
#define PCI_MASS_RAID            4   /* RAID Controller                     */
#define PCI_MASS_ATA             5   /* ATA Controller                      */
#define PCI_MASS_SATA            6   /* Serial ATA                          */
#define PCI_MASS_OTHER        0x80   /* Other Mass Storage Controller       */

/* PCI Sub-class codes - base class 2 (Network controllers) */
#define PCI_NET_ENET             0   /* Ethernet Controller                 */
#define PCI_NET_TOKEN            1   /* Token Ring Controller               */
#define PCI_NET_FDDI             2   /* FDDI Controller                     */
#define PCI_NET_ATM              3   /* ATM Controller                      */
#define PCI_NET_ISDN             4   /* ISDN Controller                     */
#define PCI_NET_WFIP             5   /* WorldFip Controller                 */
#define PCI_NET_PICMG            6   /* PICMG 2.14 Multi Computing          */
#define PCI_NET_OTHER         0x80   /* Other Network Controller            */

/* PCI Sub-class codes - base class 3 (display controllers) */
#define PCI_DISPLAY_VGA          0   /* VGA device                          */
#define PCI_DISPLAY_XGA          1   /* XGA device                          */
#define PCI_DISPLAY_3D           2   /* 3D controller                       */
#define PCI_DISPLAY_OTHER     0x80   /* Other Display Device                */

/* PCI Sub-class codes - base class 4 (multi-media devices) */
#define PCI_MM_VIDEO             0   /* Video device                        */
#define PCI_MM_AUDIO             1   /* Audio device                        */
#define PCI_MM_TELEPHONY         2   /* Computer Telephony device           */
#define PCI_MM_OTHER          0x80   /* Other Multimedia Device             */

/* PCI Sub-class codes - base class 5 (memory controllers) */
#define PCI_MEM_RAM              0   /* RAM device                          */
#define PCI_MEM_FLASH            1   /* FLASH device                        */
#define PCI_MEM_OTHER         0x80   /* Other Memory Controller */

/* PCI Sub-class codes - base class 6 (Bridge devices) */
#define PCI_BRIDGE_HOST          0   /* Host/PCI Bridge                     */
#define PCI_BRIDGE_ISA           1   /* PCI/ISA Bridge                      */
#define PCI_BRIDGE_EISA          2   /* PCI/EISA Bridge                     */
#define PCI_BRIDGE_MC            3	 /* PCI/MC Bridge                       */
#define PCI_BRIDGE_PCI           4   /* PCI/PCI Bridge                      */
#define PCI_BRIDGE_PCMCIA        5   /* PCI/PCMCIA Bridge                   */
#define PCI_BRIDGE_NUBUS         6   /* PCI/NUBUS Bridge                    */
#define PCI_BRIDGE_CARDBUS       7   /* PCI/CARDBUS Bridge                  */
#define PCI_BRIDGE_RACE          8   /* RACE-way Bridge                     */
#define PCI_BRIDGE_STPCI         9   /* Semi-transparent PCI/PCI Bridge     */
#define PCI_BRIDGE_IB           10   /* InfiniBand/PCI host Bridge          */
#define PCI_BRIDGE_OTHER      0x80   /* PCI/Other Bridge Device             */

/* PCI Sub-class codes - base class 7 (communication devices) */
#define PCI_COMM_GENERIC_XT      0   /* XT Compatible Serial Controller     */
#define PCI_COMM_PARALLEL        1   /* Parallel Port Controller            */
#define PCI_COMM_MSC             2   /* Multiport Serial Controller         */
#define PCI_COMM_MODEM           3   /* Modem Controller                    */
#define PCI_COMM_GPIB            4   /* GPIB Controller                     */
#define PCI_COMM_SMARTCARD       5   /* Smart Card Controller               */
#define PCI_COMM_OTHER        0x80   /* Other Communications Controller     */

/* PCI Sub-class codes - base class 8 */
#define PCI_PERIPH_PIC           0   /* Generic PIC                         */
#define PCI_PERIPH_DMA           1   /* Generic DMA Controller              */
#define PCI_PERIPH_TIMER         2   /* Generic System Timer Controller     */
#define PCI_PERIPH_RTC           3   /* Generic RTC Controller              */
#define PCI_PERIPH_HPC           4   /* Generic PCI Hot-Plug Controller     */
#define PCI_PERIPH_OTHER      0x80   /* Other System Peripheral             */

/* PCI Sub-class codes - base class 9 */
#define PCI_INPUT_KEYBOARD       0   /* Keyboard Controller                 */
#define PCI_INPUT_DIGITIZ        1   /* Digitizer (Pen)                     */
#define PCI_INPUT_MOUSE          2   /* Mouse Controller                    */
#define PCI_INPUT_SCANNER        3   /* Scanner Controller                  */
#define PCI_INPUT_GAMEPORT       4   /* Gameport Controller                 */
#define PCI_INPUT_OTHER       0x80   /* Other Input Controller              */

/* PCI Sub-class codes - base class 10 */
#define PCI_DOCK_GENERIC         0   /* Generic Docking Station             */
#define PCI_DOCK_OTHER        0x80   /* Other Type of Docking Station       */

/* PCI Sub-class codes - base class 11 */
#define	PCI_PROCESSOR_386        0   /* 386                                 */
#define	PCI_PROCESSOR_486        1   /* 486                                 */
#define	PCI_PROCESSOR_PENT       2   /* Pentium                             */
#define	PCI_PROCESSOR_ALPHA   0x10   /* Alpha                               */
#define	PCI_PROCESSOR_POWERPC 0x20   /* PowerPC                             */
#define	PCI_PROCESSOR_MIPS    0x30   /* MIPS                                */
#define	PCI_PROCESSOR_COPROC  0x40   /* Co-processor                        */

/* PCI Sub-class codes - base class 12 (Serial Controllers) */
#define PCI_SERIAL_FIRE          0   /* FireWire (IEEE 1394)                */
#define PCI_SERIAL_ACCESS        1   /* ACCESS.bus                          */
#define PCI_SERIAL_SSA           2   /* SSA                                 */
#define PCI_SERIAL_USB           3   /* Universal Serial Bus                */
#define PCI_SERIAL_FIBRE         4   /* Fibre Channel                       */
#define PCI_SERIAL_SMBUS         5   /* System Management Bus               */
#define PCI_SERIAL_IB            6   /* InfiniBand                          */
#define PCI_SERIAL_IPMI          7   /* IPMI                                */
#define PCI_SERIAL_SERCOS        8   /* SERCOS Interface Std (IEC 61491)    */
#define PCI_SERIAL_CANBUS        9   /* CANbus                              */

/* PCI Sub-class codes - base class 13 (Wireless controllers) */
#define PCI_WIRELESS_IRDA        0   /* iRDA Compatible Controller          */
#define PCI_WIRELESS_IR          1   /* Consumer IR Controller              */
#define PCI_WIRELESS_RF         16   /* RF Controller                       */
#define PCI_WIRELESS_BLUETOOTH  17   /* Bluetooth Controller                */
#define PCI_WIRELESS_BROADBAND  18   /* Broadband Controller                */
#define PCI_WIRELESS_80211A     32   /* Ethernet 802.11a 5 GHz              */
#define PCI_WIRELESS_80211B     33   /* Ethernet 802.11b 2.4 GHz            */
#define PCI_WIRELESS_OTHER    0x80   /* Other Wireless Controllers          */

/* PCI Sub-class codes - base class 14 (Intelligent I/O controllers) */
#define PCI_INTIO_I20            1   /* I20 Arch Spec 1.0                   */

/* PCI Sub-class codes - base class 15 (Satellite Communication controllers) */
#define PCI_SATELLITE_COMM_TV    1   /* TV                                  */
#define PCI_SATELLITE_COMM_AUDIO 2   /* Audio                               */
#define PCI_SATELLITE_COMM_VOICE 3   /* Voice                               */
#define PCI_SATELLITE_COMM_DATA  4   /* DATA                                */

/* PCI Sub-class codes - base class 16 (Encryption/Decryption controllers) */
#define PCI_CRYPT_NETWORK		 0   /* Network and Computing               */
#define PCI_CRYPT_ENTERTAINMENT 16   /* Entertainment en/decrypt            */
#define PCI_CRYPT_OTHER       0x80   /* Other en/decryption ctrlrs          */

/* PCI Sub-class codes - base class 17 (Signal Processing controllers) */
#define PCI_SIGNAL_DPIO          0   /* DPIO modules                        */
#define PCI_SIGNAL_PERF_COUNTERS 1   /* Performance counters                */
#define PCI_SIGNAL_COMM_SYNC  0x10   /* Comm. synchronization plus          */
                                     /* time and freq test ctrlr            */
#define PCI_SIGNAL_MANAGEMENT 0x20   /* Management card                     */
#define PCI_SIGNAL_OTHER      0x80   /* DSP/DAP controller                  */

/* PCI Resource Descriptor */
#define PCI_RSC_DESC_NEXT        0   /* length of the following structure   */
#define PCI_RSC_DESC_FLAGS       2   /* type of resource and misc. flags    */
#define PCI_RSC_DESC_START       4   /* start-address of resource           */
#define PCI_RSC_DESC_LENGTH      8   /* length of resource                  */
#define PCI_RSC_DESC_OFFSET     12   /* offset PCI to phys. CPU Address     */
#define PCI_RSC_DESC_DMAOFFSET  16   /* offset for DMA-transfers            */
#define PCI_RSC_DESC_ERROR      20   /* internal error code                 */
#define PCI_RSC_DESC_SIZE       24
#define PCI_RSC_DESC_TOTALSIZE  (PCI_RSC_DESC_SIZE*6)

/* Flags used in Resource Descriptor */
#define FLG_IO              0x4000   /* Resource in IO range                */
#define FLG_LAST            0x8000   /* last resource                       */
#define FLG_8BIT            0x0100   /* 8 bit accesses allowed              */
#define FLG_16BIT           0x0200   /* 16 bit accesses allowed             */
#define FLG_32BIT           0x0400   /* 32 bit accesses allowed             */
#define FLG_ENDMASK         0x000F   /* mask for byte ordering              */   
#define ORD_MOTOROLA             0   /* Motorola (big endian)               */
#define ORD_INTEL_AS             1   /* Intel (little endian), addr.swapped */
#define ORD_INTEL_LS             2   /* Intel (little endian), lane swapped */
#define ORD_UNKNOWN             15   /* unknown (BIOS-calls allowed only)   */

/* PCI Status Descriptor */
#define PCI_DEV_DES_STATUS       0   /* Status PCI                          */
#define PCI_DEV_DES_CALLBACK     4   /* Address of Callback Routine         */
#define PCI_DEV_DES_HANDLER      8   /* Address of Interrupt Handlers       */
#define PCI_DEV_DES_PARAMETER   12   /* Parameter for Interrupt Handler     */
#define PCI_DEV_DES_START_IRQ   16   /* Routine Start IRQ                   */
#define PCI_DEV_DES_SIZE        20 

/* PCI Address conversion */
#define PCI_CONV_ADDR_ADDR       0   /* calculated address (CPU<->PCI)      */
#define PCI_CONV_ADDR_LEN        4   /* length of memory range              */

/* PCI cookie */
#define PCI_COOKIE_SUBCOOKIE     0   /* Sub-Cookie for PCI_CONF             */
#define PCI_COOKIE_VERSION       4   /* version PCI BIOS                    */
#define PCI_COOKIE_ROUTINE       8   /* offset PCI BIOS routines            */
#define PCI_COOKIE_MAX_ROUTINES 45   /* maximum of routines                 */
#define PCI_COOKIE_SIZE          ((4*PCI_COOKIE_MAX_ROUTINES)+PCI_COOKIE_ROUTINE)
#define PCI_RSC_HANDLESTOTALSIZE (PCI_RSC_DESC_TOTALSIZE*PCI_MAX_HANDLE)
#define PCI_DEV_HANDLESTOTALSIZE (PCI_DEV_DES_SIZE*PCI_MAX_HANDLE)
#define PCI_COOKIE_TOTALSIZE     (PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE+PCI_DEV_HANDLESTOTALSIZE)

/* Error codes */
#define PCI_SUCCESSFUL           0   /* everything's fine         */
#define PCI_FUNC_NOT_SUPPORTED  -2   /* function not supported    */
#define PCI_BAD_VENDOR_ID       -3   /* wrong Vendor ID           */
#define PCI_DEVICE_NOT_FOUND    -4   /* PCI-Device not found      */
#define PCI_BAD_REGISTER_NUMBER -5   /* wrong register number     */
#define PCI_SET_FAILED          -6   /* reserved for later use    */
#define PCI_BUFFER_TOO_SMALL    -7   /* reserved for later use    */
#define PCI_GENERAL_ERROR       -8   /* general BIOS error code   */
#define PCI_BAD_HANDLE          -9   /* wrong/unknown PCI-handle  */
/* Internal error codes */
#define PCI_NO_MORE_IO_SPACE      -100 /* no more IO-space available           */
#define PCI_NO_MORE_MEM_SPACE     -101 /* no more MEM-space                    */
#define PCI_NO_MORE_MEM_BELOW_1MB -102 /* no more memory space below 1 MB      */
#define PCI_NEED_MORE_THAN_4GB    -103 /* device requests more than 4GB memory */
#define PCI_UNKNOW_MEMORY_TYPE    -104 /* device requests unknown memory type  */

_install_pci_bios:

	cmp.w #1,2(A0)               // init
	bne display_devices
	movem.l D1-A6,-(SP)
	lea -24(SP),SP
	clr.l -18(SP)                // offset memory resource
	clr.l -14(SP)                // offset I/O resource
	move.l #0x5F504349,D0        // _PCI
	bsr get_cookie
	beq .pci_cookie_not_found    // not found
.abort_install:
	moveq #-1,D0                 // error
	bra .end_install
.no_hardware:
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	moveq #-1,D0                 // error
	bra .end_install	
.pci_cookie_not_found:
	// test and init PLX9054
	move.w SR,-(SP)
	or.w #0x700,SR               // no interrupts
	lea .no_hardware(PC),A0
	move.l 8,A5                  // bus error
	move.l A0,8
	move.l SP,A4                 // save ssp
	moveq #PCIIDR,D1
	bsr read_local_config_longword
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	cmp.l #PLX9054,D0            // Device ID & Vendor ID
	beq .abort_install
	// Master Enable / Memory Space / I/O Space
	moveq #(PCI_CMDREG_MASTR+PCI_CMDREG_MEMSP+PCI_CMDREG_IOSP),D2
	moveq #PCICR,D1              // PCI Command Register
	bsr write_local_config_word
	moveq #3,D2                  // enable PCI Initiator memory and I/O access
	move.w #DMPBAM,D1 // PCI Base Address (Remap) Register for PCI Initiator-to-PCI Memory
	bsr write_local_config_longword
	moveq #0,D2
	cmp.l #0x1357BD13,ramvalid
	bne .no_sdram
	move.l ramtop,D2             // SDRAM top
	beq.s .no_sdram
	move.l 0x01000001,D2         // enable PCI target window at 0x1000000
.no_sdram:
	move.w #LAS0BA,D1            // Local Address Space 0 Local Base Address (Remap)
	bsr write_local_config_longword
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
	move.w #LAS0RR,D1            // Local Address Space 0 Range Register for PCI-to-Local Bus
	bsr write_local_config_longword
	move.l #PCI_MEMORY_SIZE,D2   // SDRAM mapped on PCI after the zones for devices
	move.w #PCIBAR2,D1           // PCI Base Address Register for Memory Accesses to Local Address Space 0
	bsr write_local_config_longword
	// end of PCI target windows configuration
	move.l #PCI_MEMORY_OFFSET,D2
	move.w #DMLBAM,D1            // Local Bus Base Address Register for PCI Initiator-to-PCI Memory
	bsr write_local_config_longword
	move.l #~(PCI_MEMORY_SIZE-1),D2
	move.w #DMRR,D1              // Local Range Register for PCI Initiator-to-PCI
	bsr write_local_config_longword
	move.l #PCI_IO_OFFSET,D2
	move.w #DMLBAI,D1            // Local Bus Base Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	moveq #3,D2                  // enable PCI base for local bus map-to-PCI
	move.w #DMPBAM,D1            // PCI Base Address (Remap) Register for PCI Initiator-to-PCI Memory
	bsr write_local_config_longword
#ifdef BIG_ENDIAN
	move.w #0xFE,D2              // Big Endian excepted Configuation Registers
#else
	moveq #0,D2                  // Little Endian
#endif
	move.w #BIGEND,D1            // Big/Little Endian Descriptor
	bsr write_local_config_byte	
	move.w #LMISC,D1             // Local Miscellaneous Control  
	bsr read_local_config_byte
	move.w D0,D2
	bset #2,D2                   // Local Init Status => PLX done
	move.w #LMISC,D1             // Local Miscellaneous Control  
	bsr write_local_config_byte
	// init driver
	move.w #3,-(SP)              // TT ram if possible
	move.l #PCI_COOKIE_TOTALSIZE,-(SP)
	move.w #0x44,-(SP)           // Mxalloc
	trap #1 
	addq.w #8,SP
	tst.l D0
	ble .abort_install
	move.l D0,A6                 // _PCI cookie
	add.l #PCI_COOKIE_SIZE,D0
	move.l D0,A5                 // Ressource-Descriptors
	add.l #PCI_RSC_HANDLESTOTALSIZE,D0 // PCI_RSC_DESC_TOTALSIZE*PCI_MAX_HANDLE
	move.l D0,A4                 // Status-Descriptors, size PCI_DEV_DES_SIZE*PCI_MAX_HANDLE
	move.l A6,A0                 // _PCI cookie
	clr.l PCI_COOKIE_SUBCOOKIE(A0) // Sub-Cookie for PCI_CONF, not used obsolete
	move.l #PCI_BIOS_REV,PCI_COOKIE_VERSION(A0)   // version PCI BIOS
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
	// init devices, handle 0 is for local bridge PLX9054
	moveq #0,D4                  // handle => now seach devices
.loop_handle:
		clr.l -24(SP)            // error code
		moveq #PCIIDR,D1
		move.l D4,D0             // handle
		bsr fast_read_config_longword // Device ID & Vendor ID
		move.l D0,6(SP)
		cmp.w #PCI_NOBODYHOME,D0 // Vendor ID
		beq .no_device_found_here
		moveq #PCIREV,D1
		move.l D4,D0             // handle
		bsr fast_read_config_longword // & class code
		swap D0
		lsr.w #8,D0              // base class code
		cmp.w #PCI_CLASS_DISPLAY,D1
		seq.b D0
		ext.w D0
		move.w D0,(SP)           // flag graphic card
		beq.s .card_is_free
		moveq #3,D0              // card in use
.card_is_free:
		move.w D4,D1             // handle
		mulu #PCI_DEV_DES_SIZE,D1
		move.l D0,PCI_DEV_DES_STATUS(A4,D1.w)
		clr.l PCI_DEV_DES_CALLBACK(A4,D1.w)
		clr.l PCI_DEV_DES_HANDLER(A4,D1.w)
		clr.l PCI_DEV_DES_PARAMETER(A4,D1.w)
		clr.l PCI_DEV_DES_START_IRQ(A4,D1.w)
		tst.w D4                 // handle
		bne.s .devices           // <> local bridge PLX9054
		move.w D4,D0             // handle
		mulu #PCI_RSC_DESC_TOTALSIZE,D0
		move.w #PCI_RSC_DESC_SIZE,PCI_RSC_DESC_NEXT(A5,D0.w)
#ifdef BIG_ENDIAN
		move.w #FLG_IO+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_MOTOROLA,PCI_RSC_DESC_FLAGS(A5,D0.w)
#else
		move.w #FLG_IO+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_LS,PCI_RSC_DESC_FLAGS(A5,D0.w)
#endif
		move.l -14(SP),PCI_RSC_DESC_START(A5,D0.w) // offset I/O resource
		move.l #256,PCI_RSC_DESC_LENGTH(A5,D0.w)
		add.l #256,-14(SP)       // offset I/O resource
		move.l #PCI_IO_OFFSET,PCI_RSC_DESC_OFFSET(A5,D0.w)
		move.l #PCI_MEMORY_OFFSET,PCI_RSC_DESC_DMAOFFSET(A5,D0.w)
		move.l PCI_RSC_DESC_START(A5,D0.w),D2      // offset I/O resource now for I/O PLX9054
		clr.l PCI_RSC_DESC_ERROR(A5,D0.w) // internal error code
		move.w #PCIBAR1,D1       // PCI Base Address Register for I/O Accesses to Local, Runtime, and DMA
		move.l D4,D0             // handle
		bsr write_config_longword
		move.w #1,-20(SP)        // offset resource by handle
		bra .end_area
.devices:
		moveq #PCIBAR0,D5        // reg
		clr.w -20(SP)            // index resource by handle
.loop_area:
			move.b D5,D1         // reg
			move.l D4,D0         // handle
			bsr fast_read_config_longword
			move.l D0,D3         // save value and read type bits
			moveq #-1,D2
			move.b D5,D1         // reg
			move.l D4,D0         // handle
			bsr write_config_longword
			move.b D5,D1         // reg
			move.l D4,D0         // handle
			bsr fast_read_config_longword
			move.l D0,2(SP)      // save value for try to found used bits (resolution)
			move.l D3,D2         // handle
			move.b D5,D1         // reg
			move.l D4,D0         // handle
			bsr write_config_longword // restore value
			move.l 2(SP),D0      // value used bits PCIBARx register
			beq .next_area       // register not used
			moveq #PCI_BASE_SPACE_IO,D0
			and.l D3,D0
			beq .not_space_io    // <> IO
			moveq #PCI_BASE_IO_ADDR_M,D7
			and.l 2(SP),D7       // value PCIBARx register
			move.l D7,D0
			moveq #-1,D1
.loop_find_first_lsb_io:
				addq.w #1,D1
				lsr.l #1,D0      // search the first LSB to 1
				bcs.s .found_first_lsb_io
			bne.s .loop_find_first_lsb_io
			moveq #31,D1         // not found ?
.found_first_lsb_io:
			moveq #0,D2
			bset D1,D2           // minimum step of the PCI base address
			move.l -14(SP),D0    // current offset I/O resource
			and.l D7,D0          // alignment with the resolution of PCIBARx
			cmp.l -14(SP),D0     // current offset I/O resource
			bcc.s .ok_with_current_offset_io
			add.l D2,D0          // add the minimum step of the PCI base address
			move.l D0,D7
			bra.s .check_size_io
.ok_with_current_offset_io:
			move.l -14(SP),D7    // current offset I/O resource
.check_size_io:
			move.l D7,D0
			add.l D2,D0          // minimum step of the PCI base address is the size 
			cmp.l #PCI_IO_SIZE,D0
			bcc .io_space_full   // area overflow
			move.l D7,-14(SP)    // new offset I/O resource
			move.w D4,D0         // handle
			mulu #PCI_RSC_DESC_TOTALSIZE,D0
			move.w -20(SP),D1    // index resource by handle
			mulu #PCI_RSC_DESC_SIZE,D1
			add.w D1,D0
			move.w #PCI_RSC_DESC_SIZE,PCI_RSC_DESC_NEXT(A5,D0.w)
#ifdef BIG_ENDIAN
			move.w #FLG_IO+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_MOTOROLA,PCI_RSC_DESC_FLAGS(A5,D0.w)
#else
			move.w #FLG_IO+FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_LS,PCI_RSC_DESC_FLAGS(A5,D0.w)
#endif
			move.l -14(SP),PCI_RSC_DESC_START(A5,D0.w) // offset I/O resource
			add.l D2,-14(SP)     // offset I/O resource
			move.l D2,PCI_RSC_DESC_LENGTH(A5,D0.w)
			move.l #PCI_IO_OFFSET,PCI_RSC_DESC_OFFSET(A5,D0.w)
			move.l #PCI_MEMORY_OFFSET,PCI_RSC_DESC_DMAOFFSET(A5,D0.w)
			clr.l PCI_RSC_DESC_ERROR(A5,D0.w) // internal error code
			move.l PCI_RSC_DESC_START(A5,D0.w),D2      // offset I/O resource
			move.b D5,D1         // reg
			move.l D4,D0         // handle
			bsr write_config_longword
			addq.w #1,-20(SP)    // index resource by handle
			bra .next_area
.not_space_io:
			moveq #PCI_BASE_M_ADDR_M,D7
			and.l 2(SP),D7       // value PCIBARx register
			move.l D7,D0
			moveq #-1,D1
.loop_find_first_lsb_memory:
				addq.w #1,D1
				lsr.l #1,D0      // search the first LSB to 1
				bcs.s .found_first_lsb_memory
			bne.s .loop_find_first_lsb_memory
			moveq #31,D1         // not found ?
.found_first_lsb_memory:
			moveq #0,D2
			bset D1,D2           // minimum step of the PCI base address
			move.l -18(SP),D0    // current offset memory resource
			and.l D7,D0          // alignment with the resolution of PCIBARx
			cmp.l -18(SP),D0     // current offset memory resource
			bcc.s .ok_with_current_offset_memory
			add.l D2,D0          // add the minimum step of the PCI base address
			move.l D0,D7
			bra.s .check_memory_type
.ok_with_current_offset_memory:
			move.l -18(SP),D7    // current offset memory resource
.check_memory_type:
			move.w D3,D0
			and.w #PCI_BASE_TYPE_M,D0
			cmp.w #PCI_BASE_TYPE_MEM,D0 // 32-bit memory address
			beq .memory_32bit
			cmp.w #PCI_BASE_TYPE_LOW,D0 // less than 1Mb address
			beq.s .less_1mb             // error
			cmp.w #PCI_BASE_TYPE_ALL,D0 // 64-bit memory address
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
.shutdown_device:
			move.l D0,-24(SP)    // error code
			lea device_shutdown(PC),A0 // this device will be shut down now
			bsr display_string_single
			moveq #PCICR,D1      // PCI Command Register
			move.l D4,D0         // handle
			bsr fast_read_config_word
			// remove Special Cycle / Master Enable / Memory Space / I/O Space
			and.b #~(PCI_CMDREG_SPCYC+PCI_CMDREG_MASTR+PCI_CMDREG_MEMSP+PCI_CMDREG_IOSP),D0
			move.w D0,D2
			moveq #PCICR,D1      // PCI Command Register
			move.l D4,D0         // handle
			bsr write_config_word
			bra .end_area
.memory_32bit:
			cmp.b #PCIBAR0,D5    // reg
			bne.s .no_fix_graphic_card
			tst.w (SP)           // flag graphic card
			beq.s .no_fix_graphic_card
			cmp.l #GRAPHIC_CARD_SIZE/4,D2
			bcc.s .no_fix_graphic_card                                             
			move.l #GRAPHIC_CARD_SIZE,D2
.no_fix_graphic_card:
			move.l D7,D0
			add.l D2,D0          // minimum step of the PCI base address is the size 
			cmp.l #PCI_MEMORY_SIZE,D0
			bcc .mem_space_full  // area overflow
			move.l D7,-18(SP)    // new offset memory resource
			move.w D4,D0         // handle
			mulu #PCI_RSC_DESC_TOTALSIZE,D0
			move.w -20(SP),D1    // index resource by handle
			mulu #PCI_RSC_DESC_SIZE,D1
			add.w D1,D0
			move.w #PCI_RSC_DESC_SIZE,PCI_RSC_DESC_NEXT(A5,D0.w)
#ifdef BIG_ENDIAN
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_MOTOROLA,PCI_RSC_DESC_FLAGS(A5,D0.w)
#else
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_LS,PCI_RSC_DESC_FLAGS(A5,D0.w)
#endif
			move.l -18(SP),PCI_RSC_DESC_START(A5,D0.w) // offset memory resource
			add.l D2,-18(SP)     // offset memory resource
			move.l D2,PCI_RSC_DESC_LENGTH(A5,D0.w)
			move.l #PCI_MEMORY_OFFSET,PCI_RSC_DESC_OFFSET(A5,D0.w)
			move.l #PCI_MEMORY_OFFSET,PCI_RSC_DESC_DMAOFFSET(A5,D0.w)	
			clr.l PCI_RSC_DESC_ERROR(A5,D0.w) // internal error code
			move.l PCI_RSC_DESC_START(A5,D0.w),D2      // offset memory resource
			move.b D5,D1         // reg
			move.l D4,D0         // handle
			bsr write_config_longword
			addq.w #1,-20(SP)    // index resource by handle
			bra .next_area
.memory_64bit:
			move.l D2,-(SP)
			moveq #-1,D2
			moveq #4,D1
			add.b D5,D1          // reg + 4 (next PCIBARx)
			move.l D4,D0         // handle
			bsr write_config_longword
			moveq #4,D1
			add.b D5,D1          // reg + 4 (next PCIBARx)
			move.l D4,D0         // handle
			bsr fast_read_config_longword
			move.l (SP)+,D2
			moveq #-1,D1
			cmp.l D0,D1
			bne .need_more_4gb
			move.l D7,D0
			add.l D2,D0          // minimum step of the PCI base address is the size
			cmp.l #PCI_MEMORY_SIZE,D0
			bcc .mem_space_full  // area overflow
			move.l D7,-18(SP)    // new offset memory resource
			move.w D4,D0         // handle
			mulu #PCI_RSC_DESC_TOTALSIZE,D0
			move.w -20(SP),D1    // index resource by handle
			mulu #PCI_RSC_DESC_SIZE,D1
			add.w D1,D0
			move.w #PCI_RSC_DESC_SIZE,PCI_RSC_DESC_NEXT(A5,D0.w)
#ifdef BIG_ENDIAN
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_MOTOROLA,PCI_RSC_DESC_FLAGS(A5,D0.w)
#else
			move.w #FLG_8BIT+FLG_16BIT+FLG_32BIT+ORD_INTEL_LS,PCI_RSC_DESC_FLAGS(A5,D0.w)
#endif
			move.l -18(SP),PCI_RSC_DESC_START(A5,D0.w) // offset memory resource
			add.l D2,-18(SP)     // offset memory resource
			move.l D2,PCI_RSC_DESC_LENGTH(A5,D0.w)
			move.l #PCI_MEMORY_OFFSET,PCI_RSC_DESC_OFFSET(A5,D0.w)
			move.l #PCI_MEMORY_OFFSET,PCI_RSC_DESC_DMAOFFSET(A5,D0.w)
			clr.l PCI_RSC_DESC_ERROR(A5,D0.w) // internal error code
			move.l PCI_RSC_DESC_START(A5,D0.w),D2      // offset memory resource
			move.b D5,D1         // reg
			move.l D4,D0         // handle
			bsr write_config_longword
			addq.w #1,-20(SP)    // index resource by handle
			moveq #0,D2
			moveq #4,D1
			add.b D5,D1          // reg + 4
			move.l D4,D0         // handle
			bsr write_config_longword
.next_area:
			addq.b #4,D5
		cmp.b #PCIBAR5,D5
		bls .loop_area
.end_area:
		move.w D4,D0             // handle
		mulu #PCI_RSC_DESC_TOTALSIZE,D0
		move.w -20(SP),D1        // index resource by handle
		mulu #PCI_RSC_DESC_SIZE,D1
		add.w D1,D0
		or.w #FLG_LAST,(PCI_RSC_DESC_FLAGS-PCI_RSC_DESC_SIZE)(A5,D0.w)
		clr.w (PCI_RSC_DESC_NEXT-PCI_RSC_DESC_SIZE)(A5,D0.w)
		move.l -24(SP),PCI_RSC_DESC_ERROR(A5,D0.w) // internal error code
		// Some graphic adapters set the Interrupt Pin Register
		// in that way, that they will use an Interrupt, although
		// they don't. That's nonsens.
		// So the PCI-BIOS ignores the Interrupt Pin Register of
		// that graphic adapters and does NOT install an Interrupt
		// Handler for such an adapter.
		move.w D4,D0             // handle
		bsr disable_interrupt
		move.w (SP),D0           // flag graphic card
		bne.s .graphic_card
		moveq #PCIIPR,D1         // Interrupt Pin
		move.l D4,D0             // handle
		bsr fast_read_config_byte
		tst.b D0
		beq.s .graphic_card
		lea int_ctpci(PC),A0
		tst.w D4                 // handle
		beq.s .set_vector
		lea inta_ctpci(PC),A0
		cmp.w #1,D4
		beq.s .set_vector
		lea intb_ctpci(PC),A0
		cmp.w #2,D4
		beq.s .set_vector
		lea intc_ctpci(PC),A0
.set_vector:
		move.l A2,-(SP)
		pea (A0)
		moveq #PCI_IRQ_BASE_VECTOR,D0
		add.w D4,D0
		move.w D0,-(SP)
		move.w #5,-(SP)          // Setexec
		trap #13
		addq.w #8,SP
		move.l (SP)+,A2
.graphic_card:
		// Interrupt Line Register will be initialised with 0xFF
		// because of different solutions regarding the Hardware
		// (Hades/Milan/...) This register is only for information
		// and won't be used by ATARI-compatibles. PCI adapters
		// don't care about the value set in this register.
		move.b #0xFF,D2
		moveq #PCIILR,D1         // Interrupt Line
		move.l D4,D0             // handle
		bsr write_config_byte
		// Latency Timer Register is initialised with a useable
		// value. The new revision also cares about the min and
		// max values offered by the adapter in the MIN_GNT and
		// MAX_LAT registers
		moveq #PCIMGR,D1         // Min_Gnt
		move.l D4,D0             // handle
		bsr fast_read_config_byte
		tst.b D0
		bne.s .max_gmt_lat_exist
		moveq #PCIMLR,D1         // Max_Lat
		move.l D4,D0             // handle
		bsr fast_read_config_byte
		tst.b D0
		bne.s .max_gmt_lat_exist
		moveq #32,D2             // Latency Timer value 1uS for 33 MHz bus
		bra.s .write_latency_timer
.max_gmt_lat_exist:
		moveq #PCIMLR,D1         // Max_Lat
		move.l D4,D0             // handle
		bsr fast_read_config_byte
		lsl.b #3,D0              // *8
		move.b D0,D2             // Latency Timer value
		cmp.b #64,D0             // 2 uS
		bls.s .write_latency_timer
		moveq #PCIMGR,D1         // Min_Gnt
		move.l D4,D0             // handle
		bsr fast_read_config_byte
		lsl.b #3,D0              // *8
		move.b D0,D2             // Latency Timer value
.write_latency_timer:
		moveq #PCILTR,D1         // Latency Timer
		move.l D4,D0             // handle
		bsr write_config_byte
		bra .next_handle
.no_device_found_here:
		move.w D4,D0             // handle
		mulu #PCI_DEV_DES_SIZE,D0
		move.l #PCI_DEVICE_NOT_FOUND,PCI_DEV_DES_STATUS(A4,D0.w)
		clr.l PCI_DEV_DES_CALLBACK(A4,D0.w)
		clr.l PCI_DEV_DES_HANDLER(A4,D0.w)
		clr.l PCI_DEV_DES_PARAMETER(A4,D0.w)
		clr.l PCI_DEV_DES_START_IRQ(A4,D0.w)
.next_handle:
	addq.l #1,D4                 // handle
	cmp.l #PCI_MAX_HANDLE,D4
	bcs .loop_handle
	move.l A6,D1                 // value
	move.l #0x5F504349,D0        // cookie _PCI
	bsr add_cookie
	moveq #0,D0                  // OK
.end_install:
	lea 24(SP),SP
	movem.l (SP)+,D1-A6
	rts
	
display_devices:

	movem.l D1-D4/A0,-(SP)
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
	lea begin_table(PC),A0       // Slot | VendorID | DeviceID | Description
	bsr display_string_single
	lea hor_separator(PC),A0
	bsr display_string_single
	moveq #0,D4                  // handle => now search devices
.loop_handle_2:
		move.l D4,D0             // handle
		bsr get_resource
		bmi .no_device_found_here_2
		move.l D0,A1             // resource
		moveq #PCIIDR,D1
		move.l D4,D0             // handle
		bsr fast_read_config_longword // Device ID & Vendor ID
		move.l D0,D3
		moveq #0x5B,D0           // [
		bsr display_char
		moveq #0x30,D0
		add.l D4,D0              // slot <=> handle
		bsr display_char
		moveq #0x5D,D0           // ]
		bsr display_char
		lea separator(PC),A0
		bsr display_string_single
		cmp.w #PCI_NOBODYHOME,D3 // Vendor ID
		beq .no_device_found_here_2
		moveq #0x20,D0
		bsr display_char
		moveq #0x30,D0           // 0
		bsr display_char
		moveq #0x78,D0           // x
		bsr display_char
		move.w D3,D0             // Vendor ID
		bsr hex_word
		moveq #0x20,D0
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
		move.l D4,D0             // handle
		bsr fast_read_config_longword // & class code
		bsr display_infos_class
		moveq #5,D1
.loop_resource:
			move.l PCI_RSC_DESC_ERROR(A1),D0
			bmi.s .error_device
			move.w PCI_RSC_DESC_FLAGS(A1),D0
			and.w #FLG_LAST,D0
			bne.s .next_handle_2
			add.w PCI_RSC_DESC_NEXT(A1),A1
		dbra D1,.loop_resource
		bra.s .next_handle_2
.error_device:
		lea no_more_io_space(PC),A0  // no more IO-space available
		cmp.l #PCI_NO_MORE_IO_SPACE,D0
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
		bne.s .next_handle_2
.display_error_device:
		bsr display_string_single
.no_device_found_here_2:
		lea no_device(PC),A0     // no device
		bsr display_string_single		
.next_handle_2:
	addq.l #1,D4                 // handle
	cmp.l #PCI_MAX_HANDLE,D4
	bcs .loop_handle_2
	moveq #0,D0                  // OK
.end_display_devices:
	movem.l (SP)+,D1-D4/A0
	rts

display_infos_class:

	movem.l D0-D1/D4/A0,-(SP)
	move.l D0,D4                 // class code
	move.l D4,D1
	swap D1
	lsr.w #8,D1                  // base class code
	cmp.w #PCI_CLASS_NONE,D1
	beq .old_device
	cmp.w #PCI_CLASS_MASS,D1
	beq .mass_storage
	cmp.w #PCI_CLASS_NET,D1
	beq .network_controller
	cmp.w #PCI_CLASS_DISPLAY,D1
	beq .display_controller
	cmp.w #PCI_CLASS_MM,D1
	beq .multimedia_controller
	cmp.w #PCI_CLASS_MEM,D1
	beq .memory_controller
	cmp.w #PCI_CLASS_BRIDGE,D1
	beq .bridge_device
	cmp.w #PCI_CLASS_COMM,D1
	beq .communications_controller
	cmp.w #PCI_CLASS_PERIPH,D1
	beq .peripheral_controller
	cmp.w #PCI_CLASS_INPUT,D1
	beq .input_device
	cmp.w #PCI_CLASS_DOCK,D1
	beq .docking_station
	cmp.w #PCI_CLASS_PROCESSOR,D1
	beq .processor
	cmp.w #PCI_CLASS_SERIALBUS,D1
	beq .serial_bus
	cmp.w #PCI_CLASS_WIRELESS,D1
	beq .wireless_controller
	cmp.w #PCI_CLASS_INTIO,D1
	beq .intelligent_io_controller
	cmp.w #PCI_CLASS_SATELLITE,D1
	beq .satellite_communication
	cmp.w #PCI_CLASS_CRYPT,D1
	beq .encrytion_decryption
	cmp.w #PCI_CLASS_SIGNAL,D1
	beq .signal_processing
	bra .unknow_class_device
.old_device:
	lea pciinfo0(PC),A0          // Device built before Class Code definitions
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_NONE_NOTVGA,D1
	beq.s .all_except_vga
	cmp.w #PCI_NONE_VGA,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_MASS_SCSI,D1
	beq.s .scsi_bus_controller
	cmp.w #PCI_MASS_IDE,D1
	beq.s .ide_controller
	cmp.w #PCI_MASS_FD,D1
	beq.s .floppy_disk_controller
	cmp.w #PCI_MASS_IPI,D1
	beq.s .ipi_bus_controller
	cmp.w #PCI_MASS_RAID,D1
	beq.s .raid_controller
	cmp.w #PCI_MASS_ATA,D1
	beq.s .ata_controller
	cmp.w #PCI_MASS_SATA,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_NET_ENET,D1
	beq.s .ethernet_controller
	cmp.w #PCI_NET_TOKEN,D1
	beq.s .token_ring_controller
	cmp.w #PCI_NET_FDDI,D1
	beq.s .fddi_controller
	cmp.w #PCI_NET_ATM,D1
	beq.s .atm_controller
	cmp.w #PCI_NET_ISDN,D1
	beq.s .idsn_controller
	cmp.w #PCI_NET_WFIP,D1
	beq.s .worldfip_controller
	cmp.w #PCI_NET_PICMG,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_DISPLAY_VGA,D1
	beq.s .vga_device
	cmp.w #PCI_DISPLAY_XGA,D1
	beq.s .xvga_device
	cmp.w #PCI_DISPLAY_3D,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_MM_VIDEO,D1
	beq.s .video_device
	cmp.w #PCI_MM_AUDIO,D1
	beq.s .audio_device	
	cmp.w #PCI_MM_TELEPHONY,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_MEM_RAM,D1
	beq.s .ram_device
	cmp.w #PCI_MEM_FLASH,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_BRIDGE_HOST,D1
	beq.s .host_bridge
	cmp.w #PCI_BRIDGE_ISA,D1
	beq.s .isa_bridge
	cmp.w #PCI_BRIDGE_EISA,D1
	beq.s .eisa_bridge
	cmp.w #PCI_BRIDGE_MC,D1
	beq.s .mc_bridge
	cmp.w #PCI_BRIDGE_PCI,D1
	beq.s .pci_to_pci_bridge
	cmp.w #PCI_BRIDGE_PCMCIA,D1
	beq.s .pcmcia_bridge
	cmp.w #PCI_BRIDGE_NUBUS,D1
	bra.s .nubus_bridge
	cmp.w #PCI_BRIDGE_CARDBUS,D1
	beq.s .cardbus_bridge
	cmp.w #PCI_BRIDGE_RACE,D1
	beq.s .race_bridge
	cmp.w #PCI_BRIDGE_STPCI,D1
	beq.s .stpci_bridge
	cmp.w #PCI_BRIDGE_IB,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_COMM_GENERIC_XT,D1
	beq.s .xt_serial_controller
	cmp.w #PCI_COMM_PARALLEL,D1
	beq.s .parallel_port_controller
	cmp.w #PCI_COMM_MSC,D1
	beq.s .multiport_serial_controller
	cmp.w #PCI_COMM_MODEM,D1
	beq.s .modem_controller
	cmp.w #PCI_COMM_GPIB,D1
	beq.s .gpib_controller
	cmp.w #PCI_COMM_SMARTCARD,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_PERIPH_PIC,D1
	beq.s .generic_pic
	cmp.w #PCI_PERIPH_DMA,D1
	beq.s .dma_controller
	cmp.w #PCI_PERIPH_TIMER,D1
	beq.s .system_timer_controller
	cmp.w #PCI_PERIPH_RTC,D1
	beq.s .rtc_controller
	cmp.w #PCI_PERIPH_HPC,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_INPUT_KEYBOARD,D1
	beq.s .keyboard_controller
	cmp.w #PCI_INPUT_DIGITIZ,D1
	beq.s .digitizer
	cmp.w #PCI_INPUT_MOUSE,D1
	beq.s .mouse_controller
	cmp.w #PCI_INPUT_SCANNER,D1
	beq.s .scanner_controller
	cmp.w #PCI_INPUT_GAMEPORT,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_DOCK_GENERIC,D1
	bne .unknow_subclass_device
	lea pciinfo101(PC),A0        // (Docking Station)
	bra .add_subclass
.processor:
	lea pciinfo110(PC),A0        // Processor
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_PROCESSOR_386,D1
	beq.s .i386
	cmp.w #PCI_PROCESSOR_486,D1
	beq.s .i486
	cmp.w #PCI_PROCESSOR_PENT,D1
	beq.s .pentium
	cmp.w #PCI_PROCESSOR_ALPHA,D1
	beq.s .alpha
	cmp.w #PCI_PROCESSOR_POWERPC,D1
	beq.s .powerpc
	cmp.w #PCI_PROCESSOR_MIPS,D1
	beq.s .mips
	cmp.w #PCI_PROCESSOR_COPROC,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_SERIAL_FIRE,D1
	beq.s .firewire
	cmp.w #PCI_SERIAL_ACCESS,D1
	beq.s .access
	cmp.w #PCI_SERIAL_SSA,D1
	beq.s .ssa
	cmp.w #PCI_SERIAL_USB,D1
	beq.s .usb
	cmp.w #PCI_SERIAL_FIBRE,D1
	beq.s .fibre_channel
	cmp.w #PCI_SERIAL_SMBUS,D1
	beq.s .system_management_bus
	cmp.w #PCI_SERIAL_IB,D1
	beq.s .infiniband
	cmp.w #PCI_SERIAL_IPMI,D1
	beq.s .ipmi
	cmp.w #PCI_SERIAL_SERCOS,D1
	beq.s .sercos
	cmp.w #PCI_SERIAL_CANBUS,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_WIRELESS_IRDA,D1
	beq.s .irda_controller
	cmp.w #PCI_WIRELESS_IR,D1
	beq.s .consumer_ir_controller
	cmp.w #PCI_WIRELESS_RF,D1
	beq.s .rf_controller
	cmp.w #PCI_WIRELESS_BLUETOOTH,D1
	beq.s .bluetooth_controller
	cmp.w #PCI_WIRELESS_BROADBAND,D1
	beq.s .broadband_controller
	cmp.w #PCI_WIRELESS_80211A,D1
	beq.s .ethernet_802_11a
	cmp.w #PCI_WIRELESS_80211B,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_INTIO_I20,D1
	bne .unknow_subclass_device
	lea pciinfo141(PC),A0        // (I20 Arch)
	bra .add_subclass
.satellite_communication:
	lea pciinfo150(PC),A0        // Satellite Communication
	bsr display_string_single
	move.l D4,D1
	swap D1
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_SATELLITE_COMM_TV,D1
	beq.s .satellite_tv
	cmp.w #PCI_SATELLITE_COMM_AUDIO,D1
	beq.s .satellite_audio
	cmp.w #PCI_SATELLITE_COMM_VOICE,D1
	beq.s .satellite_voice
	cmp.w #PCI_SATELLITE_COMM_DATA,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_CRYPT_NETWORK,D1
	beq.s .crypt_network
	cmp.w #PCI_CRYPT_ENTERTAINMENT,D1
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
	and.w #0xFF,D1               // subclass code
	cmp.w #PCI_SIGNAL_DPIO,D1
	beq.s .signal_dpio
	cmp.w #PCI_SIGNAL_PERF_COUNTERS,D1
	beq.s .signal_performance_counters
	cmp.w #PCI_SIGNAL_COMM_SYNC,D1
	beq.s .signal_comm_synchronization
	cmp.w #PCI_SIGNAL_MANAGEMENT,D1
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
	moveq #13,D0
	bsr display_char
	moveq #10,D0
	bsr display_char
	movem.l (SP)+,D0-D1/D4/A0
	rts
	
_find_pci_device:

	move.l 2(A0),D0          // ID
	move.w 6(A0),D1          // index

find_pci_device:

	movem.l D3-D5,-(SP)
	move.l D0,D3             // ID
	move.w D1,D5             // index
	cmp.w #-1,D3
	beq.s .query_all_cards
	moveq #0,D4              // handle
.loop_find_pci_device:
		moveq #PCIIDR,D1     // Device ID & Vendor ID
		move.l D4,D0         // handle
		bsr fast_read_config_longword
		cmp.l D0,D3          // ID
		bne.s .next_find_pci_device
		tst.w D5             // index
		beq.s .end_index_pci_device
		subq.w #1,D5
.next_find_pci_device:
	addq.l #1,D4             // handle
	cmp.l #PCI_MAX_HANDLE,D4
	bcs.s .loop_find_pci_device
	moveq #PCI_DEVICE_NOT_FOUND,D0
	bra.s .end_find_pci_device
.query_all_cards:
	moveq #0,D4              // handle
.loop_query_all_cards:
		moveq #PCIIDR,D1     // Device ID & Vendor ID
		move.l D4,D0         // handle
		bsr fast_read_config_word
		cmp.w #0xFFFF,D0
		beq.s .next_query_all_cards
		tst.w D5             // index
		beq.s .end_index_pci_device
		subq.w #1,D5
.next_query_all_cards:
	addq.l #1,D4             // handle
	cmp.l #PCI_MAX_HANDLE,D4
	bcs.s .loop_query_all_cards
	moveq #PCI_DEVICE_NOT_FOUND,D0
	bra.s .end_find_pci_device
.end_index_pci_device:
	move.l D4,D0             // handle 
.end_find_pci_device:
	movem.l (SP)+,D3-D5
	rts
	
_find_pci_classcode:

	move.l 2(A0),D0          // class
	move.w 6(A0),D1          // index

find_pci_classcode:

	movem.l D3-D5,-(SP)
	move.l D0,D4             // class
	move.w D1,D5             // index
	moveq #0,D3              // handle
.loop_pci_classcode:
		moveq #PCIIDR,D1     // Device ID & Vendor ID
		move.l D3,D0         // handle
		bsr fast_read_config_word
		cmp.w #0xFFFF,D0
		beq.s .next_pci_classcode
		move.l D4,D0
		and.l #0x4000000,D0  // if 0 compare base class
		bne.s .ignore_base_class
		moveq #PCICCR+2,D1   // PCI Class Code Register
		move.l D3,D0         // handle
		bsr fast_read_config_byte
		move.l D4,D1         // class
		swap D1
		cmp.b D1,D0          // base class code
		bne.s .next_pci_classcode
.ignore_base_class:
		move.l D4,D0         // class
		and.l #0x2000000,D0  // if 0 compare subclass
		bne.s .ignore_subclass
		moveq #PCICCR+1,D1   // PCI Class Code Register
		move.l D3,D0         // handle
		bsr fast_read_config_byte
		move.l D4,D1         // class
		lsr.l #8,D1
		cmp.b D1,D0          // subclass code
		bne.s .next_pci_classcode
.ignore_subclass:
		move.l D4,D0
		and.l #0x1000000,D0  // if 0 compare prog. if
		bne.s .ignore_prog_if
		moveq #PCICCR,D1     // PCI Class Code Register
		move.l D3,D0         // handle
		bsr fast_read_config_byte
		cmp.b D0,D4          // prog. if
		bne.s .next_pci_classcode
.ignore_prog_if:
		tst.w D5             // index
		beq.s .end_index_classcode
		subq.w #1,D5
.next_pci_classcode:
	addq.l #1,D3             // handle
	cmp.l #PCI_MAX_HANDLE,D3
	bcs.s .loop_pci_classcode
	moveq #PCI_DEVICE_NOT_FOUND,D0
	bra.s .end_pci_classcode
.end_index_classcode:
	move.l D3,D0
.end_pci_classcode:
	movem.l (SP)+,D3-D5
	rts
	
_read_config_byte:

	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // PCI register
	move.l 10(A0),A0         // pointer to space for read data

read_config_byte:

	move.l A0,A1             // address
	tst.l D0                 // handle
	bmi.s .bad_handle_read_config_byte
	beq.s .read_local_config_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_read_config_byte
	lsl.w #2,D1              // PCI register
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	lsl.l D0,D2              // Device Number
	or.l D2,D1
	bset #31,D1              // Configuration Enable
	move.w #DMCFGA,D0        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	lea PCI_IO_OFFSET,A0
	move.b (A0),(A1)         // address
	moveq #PCI_SUCCESSFUL,D0
	rts
.read_local_config_byte:
	cmp.w #0x40,D1
	bcc.s .bad_register_read_config_byte
	bsr read_local_config_byte
	move.b D0,(A1)
.bad_register_read_config_byte:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts
.bad_handle_read_config_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_config_word:

	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // PCI register
	move.l 10(A0),A0         // pointer to space for read data

read_config_word:

	move.l A0,A1             // address
	btst #0,D1               // PCI register
	bne.s .bad_register_read_config_word
	tst.l D0                 // handle
	bmi.s .bad_handle_read_config_word
	beq.s .read_local_config_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_read_config_word
	lsl.w #2,D1              // PCI register
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	lsl.l D0,D2              // Device Number
	or.l D2,D1
	bset #31,D1              // Configuration Enable
	move.w #DMCFGA,D0        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.w (A0),(A1)
#else
	move.w (A0),D0
	ror.w #8,D0
	move.w D0,(A1)           // address
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.read_local_config_word:
	cmp.w #0x40,D1
	bcc.s .bad_register_read_config_word
	bsr read_local_config_word
	move.w D0,(A1)
.bad_register_read_config_word:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts
.bad_handle_read_config_word:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_config_longword:

	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // PCI register
	move.l 10(A0),A0         // pointer to space for read data

read_config_longword:

	move.l A0,A1             // address
	moveq #3,D2
	and.b D1,D2              // PCI register
	bne.s .bad_register_read_config_longword
	tst.l D0                 // handle
	bmi.s .bad_handle_read_config_longword
	beq.s .read_local_config_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_read_config_longword
	lsl.w #2,D1              // PCI register
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D2,D1
	bset #31,D1              // Configuration Enable
	move.w #DMCFGA,D0        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.l (A0),(A1)
#else
	move.l (A0),D0
	ror #8,D0
	swap D0
	ror #8,D0
	move.l D0,(A1)           // address
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.read_local_config_longword:
	cmp.w #0x40,D1
	bcc.s .bad_register_read_config_longword
	bsr read_local_config_longword
	move.l D0,(A1)
.bad_register_read_config_longword:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts
.bad_handle_read_config_longword:
	moveq #PCI_BAD_HANDLE,D0
	rts

_fast_read_config_byte:

	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // PCI register
	
fast_read_config_byte:

	tst.l D0
	beq read_local_config_byte
	lsl.w #2,D1              // PCI register
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D2,D1
	bset #31,D1              // Configuration Enable
	move.w #DMCFGA,D0        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	lea PCI_IO_OFFSET,A0
	moveq #0,D0
	move.b (A0),D0
	rts

_fast_read_config_word:

	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // PCI register

fast_read_config_word:

	tst.l D0
	beq read_local_config_word
	lsl.w #2,D1              // PCI register
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D2,D1
	bset #31,D1              // Configuration Enable
	move.w #DMCFGA,D0        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	lea PCI_IO_OFFSET,A0
	moveq #0,D0
	move.w (A0),D0
#ifndef BIG_ENDIAN
	ror.w #8,D0
#endif
	rts
	
_fast_read_config_longword:

	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // PCI register

fast_read_config_longword:

	tst.l D0
	beq read_local_config_longword
	lsl.w #2,D1              // PCI register
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D2
	move.b (A0,D0.l),D2
	moveq #11,D0
	asl.l D0,D2              // Device Number
	or.l D2,D1
	bset #31,D1              // Configuration Enable
	move.w #DMCFGA,D0        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	lea PCI_IO_OFFSET,A0
	move.l (A0),D0
#ifndef BIG_ENDIAN
	ror.w #8,D0
	swap D0
	ror.w #8,D0
#endif
	rts
	
_write_config_byte:

	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // PCI register
	move.w 8(A0),D2          // data to write

write_config_byte:

	move.l D3,-(SP)
	move.l D0,D3             // handle
	bmi.s .bad_handle_write_config_byte
	beq.s .write_local_config_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_config_byte
	lsl.w #2,D1              // PCI register
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D3
	move.b (A0,D0.l),D3
	moveq #11,D0
	asl.l D0,D3              // Device Number
	or.l D3,D1
	bset #31,D1              // Configuration Enable
	move.w #DMCFGA,D0        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	lea PCI_IO_OFFSET,A0
	move.b D2,(A0)
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_write_config_byte
.write_local_config_byte:
	cmp.w #0x40,D1
	bcc.s .bad_register_write_config_byte
	bsr write_local_config_byte
	bra.s .end_write_config_byte	
.bad_register_write_config_byte:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	bra.s .end_write_config_byte
.bad_handle_write_config_byte:
	moveq #PCI_BAD_HANDLE,D0
.end_write_config_byte:
	move.l (SP)+,D3
	rts

_write_config_word:

	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // PCI register
	move.w 8(A0),D2          // data to write

write_config_word:

	move.l D3,-(SP)
	btst #0,D1               // PCI register       
	bne.s .bad_register_write_config_word
	tst.l D0                 // handle
	bmi.s .bad_handle_write_config_word
	beq.s .write_local_config_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_config_word
	lsl.w #2,D1              // PCI register
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D3
	move.b (A0,D0.l),D3
	moveq #11,D0
	asl.l D0,D3              // Device Number
	or.l D3,D1
	bset #31,D1              // Configuration Enable
	move.w #DMCFGA,D0        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	lea PCI_IO_OFFSET,A0
#ifndef BIG_ENDIAN
	ror.w #8,D2              // data to write
#endif
	move.w D2,(A0)
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_write_config_word
.write_local_config_word:
	cmp.w #0x40,D1
	bcc.s .bad_register_write_config_word
	bsr write_local_config_word
	bra.s .end_write_config_word	
.bad_register_write_config_word:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	bra.s .end_write_config_word
.bad_handle_write_config_word:
	moveq #PCI_BAD_HANDLE,D0
.end_write_config_word:
	move.l (SP)+,D3
	rts
	
_write_config_longword:

	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // PCI register
	move.l 8(A0),D2          // data to write
	
write_config_longword:

	move.l D3,-(SP)
	moveq #3,D3
	and.b D1,D3              // PCI register
	bne.s .bad_register_write_config_longword
	tst.l D0                 // handle
	bmi.s .bad_handle_write_config_longword
	beq.s .write_local_config_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_config_longword
	lsl.w #2,D1              // PCI register
	and.l #0x7FC,D1          // function/reg
	lea tab_pci_device(PC),A0
	moveq #0,D3
	move.b (A0,D0.l),D3
	moveq #11,D0
	asl.l D0,D3              // Device Number
	or.l D3,D1
	bset #31,D1              // Configuration Enable
	move.w #DMCFGA,D0        // PCI Configuration Address Register for PCI Initiator-to-PCI I/O Config
	bsr write_local_config_longword
	lea PCI_IO_OFFSET,A0
#ifndef BIG_ENDIAN
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
#endif
	move.l D2,(A0)
	moveq #PCI_SUCCESSFUL,D0
	bra.s .end_write_config_longword
.write_local_config_longword:
	cmp.w #0x40,D1
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
	
	move.l 2(A0),D0          // handle
	move.l 10(A0),A1         // parameter for interrupt handler
	move.l 6(A0),A0          // pointer to interrupt handler

hook_interrupt:

	move.l A2,-(SP)
	move.l D0,D1             // handle
	bmi.s .bad_handle_hook_interrupt
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_hook_interrupt
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_hook_interrupt // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A2             // Status-Descriptors
	move.l D1,D0             // handle
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
	
	move.l 2(A0),D0          // handle
	
unhook_interrupt:

	move.l D0,D1             // handle
	bmi.s .bad_handle_unhook_interrupt
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_unhook_interrupt
	bsr disable_interrupt
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_unhook_interrupt // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A1             // Status-Descriptors
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
	
	move.l 2(A0),D0          // handle

get_routing:

	tst.l D0                 // handle
	bmi.s .bad_handle_set_routing
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_set_routing
	moveq #PCI_FUNC_NOT_SUPPORTED,D0
	rts
.bad_handle_set_routing:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_set_interrupt:
	
	move.l 2(A0),D0          // handle
	move.w 6(A0),D1          // mode

set_interrupt:

	tst.l D0                 // handle
	bmi.s .bad_handle_set_interrupt
	beq.s .local_set_interrupt
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_set_interrupt
	moveq #PCI_FUNC_NOT_SUPPORTED,D0
	rts
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
	move.w #INTCSR,D1        // Interrupt Control/Status
	bsr write_local_config_longword
	rts
.bad_handle_set_interrupt:
	moveq #PCI_BAD_HANDLE,D0
	rts

_get_resource:

	move.l 2(A0),D0          // handle

get_resource:

	move.l D0,D1             // handle
	bmi.s .bad_handle_get_resource
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_get_resource
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

	move.l 2(A0),D0          // handle
	move.l 6(A0),A0          // address
	
get_card_used:

	move.l D0,D1             // handle
	bmi.s .bad_handle_get_card_used
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_get_card_used
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

	move.l 2(A0),D0          // handle
	move.l 6(A0),A0          // callback
	
set_card_used:

	move.l D0,D1             // handle
	bmi.s .bad_handle_set_card_used
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_set_card_used
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq .general_error_set_card_used // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A1             // Status-Descriptors
	mulu #PCI_RSC_DESC_SIZE,D1
	move.w A0,D0             // callback, 0: card is free
	beq.s .set_status_set_card_used
	cmp.w #1,D0              // callback, 2: card in use
	beq.s .set_status_set_card_used
	cmp.w #3,D0              // callback, 3: card in use
	beq.s .set_status_set_card_used
.callback_entry_set_card_used:
	move.l A0,PCI_DEV_DES_CALLBACK(A1,D1.l)
	move.l #2,PCI_DEV_DES_STATUS(A1,D1.l)
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

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory
	
read_mem_byte:

	tst.l D0                 // handle
	bmi.s .bad_handle_read_mem_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_read_mem_byte
	lea PCI_MEMORY_OFFSET,A1
#ifdef BIG_ENDIAN
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#else
	moveq #3,D2
	eor.l D2,D1              // offset
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_read_mem_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_mem_word:

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory

read_mem_word:

	tst.l D0                 // handle
	bmi.s .bad_handle_read_mem_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_read_mem_word
	btst #0,D1
	bne.s .bad_alignment_read_mem_word
	lea PCI_MEMORY_OFFSET,A1
#ifdef BIG_ENDIAN
	move.w (A1,D1.l),(A0)    // pointer to data in memory
#else
	moveq #2,D2
	eor.l D2,D1              // address to access (in PCI memory address space)
	move.w (A1,D1.l),D0
	ror.w #8,D0
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

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory
	
read_mem_longword:

	tst.l D0                 // handle
	bmi.s .bad_handle_read_mem_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_read_mem_longword
	moveq #3,D0
	and.l D1,D0
	bne.s .bad_alignment_read_mem_longword
	lea PCI_MEMORY_OFFSET,A1
#ifdef BIG_ENDIAN
	move.l (A1,D1.l),(A0)    // pointer to data in memory
#else
	move.l (A1,D1.l),D0      // + address to access (in PCI memory address space)
	ror.w #8,D0
	swap D0
	ror.w #8,D0
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

	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.b (A0,D1.l),D0
#else
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
	move.b (A0,D1.l),D0      // read data
#endif
	rts
	
_fast_read_mem_word:

	move.l 6(A0),D1          // address to access (in PCI memory address space)

fast_read_mem_word:

	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.w (A0,D1.l),D0
#else
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
	move.w (A0,D1.l),D0
	ror.w #8,D0              // read data
#endif
	rts
	
_fast_read_mem_longword:

	move.l 6(A0),D1          // address to access (in PCI memory address space)

fast_read_mem_longword:

	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.l (A0,D1.l),D0
#else
	move.l (A0,D1.l),D0      // + address to access (in PCI memory address space)
	ror.w #8,D0
	swap D0
	ror.w #8,D0              // read data
#endif
	rts

_write_mem_byte:

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.w 10(A0),D2         // data to write
	
write_mem_byte:

	tst.l D0                 // handle
	bmi.s .bad_handle_write_mem_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_mem_byte
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
	move.b D2,(A0,D1.l)      // data to write
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_write_mem_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts

_write_mem_word:

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.w 10(A0),D2         // data to write
	
write_mem_word:

	tst.l D0                 // handle
	bmi.s .bad_handle_write_mem_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_mem_word
	btst #0,D1
	bne.s .bad_alignment_write_mem_word
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.w D2,(A0,D1.l)
#else
	ror.w #8,D2              // data to write
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI memory address space)
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
	
_write_mem_longword:

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),D2         // data to write

write_mem_longword:

	tst.l D0                 // handle
	bmi.s .bad_handle_write_mem_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_mem_longword
	moveq #3,D0
	and.l D1,D0
	bne.s .bad_alignment_write_mem_longword
	lea PCI_MEMORY_OFFSET,A0
#ifdef BIG_ENDIAN
	move.l D2,(A0,D1.l)
#else
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
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

_read_io_byte:

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.l 10(A0),A0         // pointer to data in memory

read_io_byte:

	tst.l D0                 // handle
	bmi.s .bad_handle_read_io_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_read_io_byte
	lea PCI_IO_OFFSET,A1
#ifdef BIG_ENDIAN
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#else
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
	move.b (A1,D1.l),(A0)    // pointer to data in memory
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_read_io_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_read_io_word:

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.l 10(A0),A0         // pointer to data in memory
	
read_io_word:

	tst.l D0                 // handle
	bmi.s .bad_handle_read_io_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_read_io_word
	btst #0,D1
	bne.s .bad_alignment_read_io_word
	lea PCI_IO_OFFSET,A1
#ifdef BIG_ENDIAN
	move.w (A1,D1.l),(A0)    // pointer to data in memory
#else
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
	move.w (A1,D1.l),D0
	ror.w #8,D0
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

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI memory address space)
	move.l 10(A0),A0         // pointer to data in memory

read_io_longword:

	tst.l D0                 // handle
	bmi.s .bad_handle_read_io_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_read_io_longword
	moveq #3,D0
	and.l D1,D0
	bne.s .bad_alignment_read_io_longword
	lea PCI_IO_OFFSET,A1
#ifdef BIG_ENDIAN
	move.l (A1,D1.l),(A0)    // pointer to data in memory
#else
	move.l (A1,D1.l),D0      // + address to access (in PCI I/O address space)
	ror.w #8,D0
	swap D0
	ror.w #8,D0
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

	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.b (A0,D1.l),D0
#else
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
	move.b (A0,D1.l),D0      // read data
#endif
	rts

_fast_read_io_word:

	move.l 6(A0),D1          // address to access (in PCI I/O address space)

fast_read_io_word:

	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	moveq #0,D0
	move.w (A0,D1.l),D0
#else
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
	move.w (A0,D1.l),D0
	ror.w #8,D0              // read data
#endif
	rts
	
_fast_read_io_longword:

	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	
fast_read_io_longword:

	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.l (A0,D1.l),D0
#else
	move.l (A0,D1.l),D0      // + address to access (in PCI I/O address space)
	ror.w #8,D0
	swap D0
	ror.w #8,D0              // read data
#endif
	rts
	
_write_io_byte:

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.w 10(A0),D2         // data to write
	
write_io_byte:

	tst.l D0                 // handle
	bmi.s .bad_handle_write_io_byte
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_io_byte
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.b D2,(A0,D1.l)
#else
	moveq #3,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
	move.b D2,(A0,D1.l)      // data to write
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_write_io_byte:
	moveq #PCI_BAD_HANDLE,D0
	rts

_write_io_word:

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.w 10(A0),D2         // data to write

write_io_word:

	move.l D3,-(SP)
	tst.l D0                 // handle
	bmi.s .bad_handle_write_io_word
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_io_word
	btst #0,D1
	bne.s .bad_alignment_write_io_word
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.w D2,(A0,D1.l)
#else
	ror.w #8,D2              // data to write
	moveq #2,D0
	eor.l D0,D1              // address to access (in PCI I/O address space)
	move.w D2,(A0,D1.l)
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_write_io_word:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_write_io_word:
	moveq #PCI_BAD_HANDLE,D0
	rts

_write_io_longword:

	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address to access (in PCI I/O address space)
	move.l 10(A0),D2         // data to write

write_io_longword:

	tst.l D0                 // handle
	bmi.s .bad_handle_write_io_longword
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_write_io_longword
	moveq #3,D0
	and.l D1,D0
	bne.s .bad_alignment_write_io_longword
	lea PCI_IO_OFFSET,A0
#ifdef BIG_ENDIAN
	move.l D2,(A0,D1.l)
#else
	ror.w #8,D2              // data to write
	swap D2
	ror.w #8,D2
	move.l D2,(A0,D1.l)      // + address to access (in PCI I/O address space)
#endif
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_alignment_write_io_longword:
	moveq #PCI_GENERAL_ERROR,D0
	rts
.bad_handle_write_io_longword:
	moveq #PCI_BAD_HANDLE,D0
	rts

_get_machine_id:
get_machine_id:

	moveq #0,D0              // no ID available
	rts

_get_pagesize:
get_pagesize:

	moveq #0,D0              // paging not active
	rts
	
_virt_to_bus:
	
	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // address in virtual CPU space 
	move.l 10(A0),A0         // ptr
	
virt_to_bus:

	tst.l D0                 // handle
	bmi.s .bad_handle_virt_to_bus
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_virt_to_bus
	move.l D1,D0             // address in virtual CPU space
	sub.l #PCI_MEMORY_OFFSET,D0
	move.l D0,PCI_CONV_ADDR_ADDR(A0) // PCI bus address
	move.l #PCI_MEMORY_SIZE,PCI_CONV_ADDR_LEN(A0) // length of contiguous mapped area
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_handle_virt_to_bus:
	moveq #PCI_BAD_HANDLE,D0
	rts
	
_bus_to_virt:
	
	move.l 2(A0),D0          // handle
	move.l 6(A0),D1          // PCI bus address 
	move.l 10(A0),A0         // ptr

bus_to_virt:

	tst.l D0                 // handle
	bmi.s .bad_handle_bus_to_virt
	cmp.l #PCI_MAX_HANDLE,D0
	bcc.s .bad_handle_bus_to_virt
	move.l D1,D0             // PCI bus address 
	add.l #PCI_MEMORY_OFFSET,D0
	move.l D0,PCI_CONV_ADDR_ADDR(A0) // CPU virtual address
	move.l #PCI_MEMORY_SIZE,PCI_CONV_ADDR_LEN(A0) // length of contiguous mapped area
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

	move.l 10(A0),D0         // Transfer Size (Bytes)
	move.l 6(A0),A1          // Local Address
	move.l 2(A0),A0          // PCI Address
	move.l D0,-(SP)          // Transfer Size (Bytes)
	move.l A0,D2             // PCI Address
	move.w #DMAPADR0,D1      // DMA Channel 0 PCI Address
	bsr write_local_config_longword	
	move.l A1,D2             // Local Address
	move.w #DMALADR0,D1      // DMA Channel 0 Local Address
	bsr write_local_config_longword
	move.l (SP)+,D2          // Transfer Size (Bytes)
	move.w #DMASIZ0,D1       // DMA Channel 0 Transfer Size (Bytes
	bsr write_local_config_longword
	rts
	
_dma_buffoper:

	move.w 2(A0),D0          // mode
	bmi.s .status_dma_buffoper
	moveq #4,D2              // abort
	tst.w D0                 // stop
	beq.s .cmd_dma_buffoper
	moveq #0,D2
	cmp.w #1,D0              // PCI to Local Bus
	beq.s .direction_dma_buffoper
	cmp.w #2,D0              // Local Bus To PCI
	bne.s .bad_mode_dma_buffoper	
	moveq #8,D2              // Local Bus To PCI
.direction_dma_buffoper:
	move.w #DMADPR0,D1       // DMA Channel 0 Descriptor Pointer
 	bsr write_local_config_longword
	move.w #DMAMODE0,D1      // DMA Channel 0 Mode
 	bsr read_local_config_longword
 	bclr #9,D0               // Block mode
 	move.l D0,D2 	
	move.w #DMAMODE0,D1      // DMA Channel 0 Mode
 	bsr write_local_config_longword
	moveq #3,D2              // start & enable
.cmd_dma_buffoper:
	move.w #DMASCR0,D1       // DMA Channel 0 Command/Status
	bsr write_local_config_byte
.status_dma_buffoper:
	move.w #DMASCR0,D1       // DMA Channel 0 Command/Status
	bsr read_local_config_byte
	moveq #0,D1
	btst #0,D0               // enable
	beq.s .end_dma_buffoper
	btst #4,D0               // done
	bne.s .end_dma_buffoper
	moveq #1,D1
.end_dma_buffoper:
	move.l D1,D0             // state	
	rts
.bad_mode_dma_buffoper:
	moveq #PCI_GENERAL_ERROR,D0
	rts
	
_read_mailbox:

	move.w 2(A0),D0          // mailbox 0-7
	move.l 4(A0),A0          // pointer to data in memory
	cmp.w #8,D0
	bcc.s .bad_register_read_mailbox 
	move.w D0,D1             // mailbox 0-7
	lsl.w #2,D1
	move.l A0,A1
	add.w #MBOX0,D1          // Mailbox Register 0
 	bsr read_local_config_longword
	move.l D0,(A1)           // pointer to data in memory
	moveq #PCI_SUCCESSFUL,D0
	rts
.bad_register_read_mailbox:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts
	
_write_mailbox:

	move.w 2(A0),D0          // mailbox 0-7
	move.l 4(A0),D1          // data to write
	cmp.w #8,D0
	bcc.s .bad_register_write_mailbox 
	move.l D1,D2             // data to write             
	move.w D0,D1             // mailbox 0-7              
	lsl.w #2,D1
	add.w #MBOX0,D1          // Mailbox Register 0
 	bsr write_local_config_longword
	rts 	
.bad_register_write_mailbox:
	moveq #PCI_BAD_REGISTER_NUMBER,D0
	rts
	
read_local_config_byte:

	lea PCI_LOCAL_CONFIG,A0
	move.b (A0,D1.w),D0      // read data
	rts

read_local_config_word:

	lea PCI_LOCAL_CONFIG,A0
	move.w (A0,D1.w),D0
	ror.w #8,D0             // read data
	rts

read_local_config_longword:

	lea PCI_LOCAL_CONFIG,A0
	move.l (A0,D1.w),D0
	ror.w #8,D0
	swap D0
	ror.w #8,D0              // read data
	rts

write_local_config_byte:

	lea PCI_LOCAL_CONFIG,A0
	move.b D2,(A0,D1.w)      // data to write
	moveq #PCI_SUCCESSFUL,D0
	rts
	
write_local_config_word:

	ror.w #8,D2              // data to write
	lea PCI_LOCAL_CONFIG,A0
	move.w D2,(A0,D1.w)
	moveq #PCI_SUCCESSFUL,D0
	rts
	
write_local_config_longword:

	ror.w #8,D1              // data to write
	swap D1
	ror.w #8,D1
	lea PCI_LOCAL_CONFIG,A0
	move.l D2,(A0,D1.w)
	moveq #PCI_SUCCESSFUL,D0
	rts

pci_interrupt:

	move.w D0,D4             //  INTA/B/C/D <=> handle <=> card
	lea 0,A2
	move.l #0x5F504349,D0    // _PCI
	bsr get_cookie
	beq.s .loop_interrupt    // not found
	add.l #PCI_COOKIE_SIZE+PCI_RSC_HANDLESTOTALSIZE,D0
	move.l D0,A2             // Status-Descriptors
.loop_interrupt:
		move.l A2,D0
		beq.s .end_interrupt
		move.w D4,D1         // handle
		mulu #PCI_DEV_DES_SIZE,D1
		move.l PCI_DEV_DES_HANDLER(A2,D1.l),D0
		beq.s .end_interrupt
		move.l D0,A3
		move.l PCI_DEV_DES_PARAMETER(A2,D1.l),A0
		moveq #0,D0
		jsr (A3)
		and.l #1,D0
		bne.s .interrupt_ok  // interrupt was from this card
.end_interrupt:
		move.w D4,D0         // handle
		bsr disable_interrupt
		rts
.interrupt_ok:
		move.w D4,D0         // handle
		bsr clear_interrupt
		move.w D4,D0         // handle
	bsr test_interrupt
	beq .loop_interrupt
	rts

enable_interrupt:

//	lea tab_inter(PC),A0
//	move.b (A0,D0.w),D0
//	bset D0,0xFFFFFA89.w     // IERB MFP TT
//	bset D0,0xFFFFFA95.w     // IMRB
	rts
	
disable_interrupt:

//	lea tab_inter(PC),A0
//	move.b (A0,D0.w),D0
//	bclr D0,0xFFFFFA95.w     // IMRB MFP TT
//	bclr D0,0xFFFFFA89.w     // IERB
//	bclr D0,0xFFFFFA8D.w     // IPRB
//	bclr D0,0xFFFFFA91.w     // ISRB
	rts
	
clear_interrupt:

//	lea tab_inter(PC),A0
//	move.b (A0,D0.w),D0
//	bclr D0,0xFFFFFA8D.w     // IPRB MFP TT
	rts

test_interrupt:

//	lea tab_inter(PC),A0
//	move.b (A0,D0.w),D0
//	btst D0,0xFFFFFA81.w     // GPIP MFP TT
	rts
	
	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

int_ctpci:
	
	movem.l D0-A6,-(SP)
	moveq #0,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
//	bclr #0,0xFFFFFA91.w     // ISRB MFP TT
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0
	
inta_ctpci:

	movem.l D0-A6,-(SP)
	moveq #1,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
//	bclr #1,0xFFFFFA91.w     // ISRB MFP TT
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0
	
intb_ctpci:

	movem.l D0-A6,-(SP)
	moveq #2,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
//	bclr #2,0xFFFFFA91.w     // ISRB MFP TT
	rte

	dc.l 0x58425241          // XBRA
	dc.l 0x5F504349          // _PCI
	dc.l 0

intc_ctpci:
	
	movem.l D0-A6,-(SP)
	moveq #3,D0
	bsr pci_interrupt
	movem.l (SP)+,D0-A6
//	bclr #7,0xFFFFFA91.w     // ISRB MFP TT
	rte
	
get_cookie:

	movem.l D1/A0,-(SP)
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
	movem.l (SP)+,D1/A0
	tst.l D0
	rts

add_cookie:

	movem.l D1-D2/A0,-(SP)
	move.l cookie,D2
	beq.s .cookie_not_found_add
	move.l D2,A0
	moveq #0,D2
	bra.s .next_cookie_add
.loop_add_cookie:
		addq.w #8,A0
		addq.l #1,D2
.next_cookie_add:
	tst.l (A0)
	bne.s .loop_add_cookie
	cmp.l 4(A0),D2
	bcc.s .cookie_not_found_add
	move.l 4(A0),D2
	move.l D0,(A0)           // cookie
	move.l D1,4(A0)          // value
	addq.w #8,A0
	clr.l (A0)
	move.l D2,4(A0)
	moveq #1,D0              // OK
	bra.s .end_add_cookie
.cookie_not_found_add:
	moveq #0,D0              // error
.end_add_cookie:
	movem.l (SP)+,D1-D2/A0
	rts
	
display_string:

	movem.l D0/A0,-(SP)	
	move.l #0x5F414B50,D0    // _AKP cookie
	bsr get_cookie
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
	addq.w #6,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts

tab_pci_device:
	.byte 0                  // host bridge
	.byte 10,11,12           // device number n-11 where AD[n] select IDSEL

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
pciinfo126:	.asciz "(System Management Bus)
pciinfo127:	.asciz "(InfiniBand)"
pciinfo128:	.asciz "(IPMI)"
pciinfo129:	.asciz "(SERCOS)"
pciinfo1210:	.asciz "(CANbus)"

pciinfo130:	.asciz "Wireless Controller "
pciinfo131:	.asciz "(iRDA Compatible)
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
	.byte 13,10
	.ascii "CTPCI found, scanning PCI devices..."
	.byte 13,10,0
	.byte 13,10
	.ascii "CTPCI trouv‚e, recherche cartes PCI..."
	.byte 13,10,0
separator:
	.asciz " | "
hor_separator:
	.ascii "----------------------------------------------------------------"
	.byte 13,10,0
begin_table:
	.ascii "Slot | VendorID | DeviceID | Description"
	.byte 13,10,0
no_device:
	.ascii " 0xFFFF  |          | no device"
	.byte 13,10,0
no_more_io_space:
	.ascii "     | no more IO-space available !!!"
	.byte 13,10,0
no_more_mem_space:
	.ascii "     | no more MEM-space !!!"
	.byte 13,10,0
no_more_memory_below_1mb:
	.ascii "     | no more memory space below 1 MB !!!"
	.byte 13,10,0
need_more_than_4gb:
	.ascii "     | device requests more than 4GB memory !!!"
	.byte 13,10,0
unknow_memory_type:
	.ascii "     | device requests unknown memory type !!!"
	.byte 13,10,0
device_shutdown:
	.ascii "     | this device will be shut down now..."
	.byte 13,10,0

