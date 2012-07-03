/* CT60 / Coldfire board(s) IDE/SCSI boot routines
 * IDE driver with XHDI and SCSIDRV protocols
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
 
#include "ct60.h"
#include "vars.h"
#ifdef COLDFIRE
#include "fire.h"
#endif

#undef DEBUG

#define MAX_LOGICAL_DRIVE 16
#define MAX_SECTOR_SIZE 0x4000
#define ATAPI_SECTOR_SIZE 2048

#if defined(COLDFIRE) && defined(MCF547X)
#define FIX_IDE
#define IDE_16BITS
#define HDV_RW_USE_XHDI
#endif

/* SCSIDRV */
#define SCSI_COOKIE_SIZE 74
#define SCSI_EMULATION /* for IDE <> ATAPI */
#if (defined(COLDFIRE) && defined(MCF547X)) || !defined(COLDFIRE)
#define SECOND_IDE_BUS
#endif

#define NOSCSIERROR   0 /* No error */
#define SELECTERROR  -1 /* Error during selection */
#define STATUSERROR  -2 /* Default error */
#define PHASEERROR   -3 /* Invalid phase */
#define BSYERROR     -4 /* BSY lost */
#define BUSERROR     -5 /* Bus error during DMA transfer */
#define TRANSERROR   -6 /* Error during DMA-transfer (nothing transferred) */
#define FREEERROR    -7 /* Bus not freed */
#define TIMEOUTERROR -8 /* Timeout error */
#define DATATOOLONG  -9 /* Data for ACSI Soft-transfer too long */
#define LINKERROR    -10 /* Error while sending the Linked command (ACSI) */
#define TIMEOUTARBIT -11 /* Timeout during arbitration */
#define PENDINGERROR -12 /* Error noted on this handle */
#define PARITIYERROR -13 /* Transfer caused parity errors */

#define cArbit         0x01 /* Arbitration will take place on the bus */
#define cAllCmds       0x02 /* All SCSI-Cmds can be transmitted */
#define cTargCtrl      0x04 /* The target controls the procedure (so it should!) */
#define cTarget        0x08 /* One can install oneself as a target on this bus */
#define cCanDisconnect 0x10 /* Disconnect is possible */
#define cScatterGather 0x20 /* Scatter gather possible with virtual RAM */

/* XHDI */

#define XH_DL_SECSIZ 0 // maximal sector size (BIOS level)
#define XH_DL_MINFAT 1 // minimal number of FATs
#define XH_DL_MAXFAT 2 // maximal number of FATs
#define XH_DL_MINSPC 3 // sectors per cluster minimal
#define XH_DL_MAXSPC 4 // sectors per cluster maximal
#define XH_DL_CLUSTS 5 // maximal number of clusters of a 16 bit FAT
#define XH_DL_MAXSEC 6 // maximal number of sectors
#define XH_DL_DRIVES 7 // maximal number of BIOS drives supported by the DOS

#ifdef COLDFIRE

#ifdef MCF547X
#define FIREBEE_ATA        0xFFF00040
#endif

#else /* !COLDFIRE */

//#define CTPCI_ATA          0xFCF00000 // Rodolphe changed address in 2012 ???
#define CTPCI_ATA          0xFEF00000

#define USE_ATARI_IO       // IDE, SCSI

#endif /* COLDFIRE */

#ifdef USE_ATARI_IO

#define ATA_DATA           0xFFF00000
#define ATA_ERROR_REGISTER 0xFFF00005
#define ATA_SECTOR_COUNT   0xFFF00009
#define ATA_SECTOR_NUM     0xFFF0000D // LBA bits 0-7
#define ATA_CYLINDER_LOW   0xFFF00011 // LBA bits 7-15
#define ATA_CYLINDER_HIGH  0xFFF00015 // LBA bits 16-23
#define ATA_DEVICE_HEAD    0xFFF00019 // LBA bits 24-27
#define ATA_STATUS_COMMAND 0xFFF0001D
#define ATA_CONTROL_DEVICE 0xFFF00039

#define OFFSET_DATA           0x00
#define OFFSET_ERROR_REGISTER 0x05
#define OFFSET_SECTOR_COUNT   0x09
#define OFFSET_SECTOR_NUM     0x0D // LBA bits 0-7
#define OFFSET_CYLINDER_LOW   0x11 // LBA bits 7-15
#define OFFSET_CYLINDER_HIGH  0x15 // LBA bits 16-23
#define OFFSET_DEVICE_HEAD    0x19 // LBA bits 24-27
#define OFFSET_STATUS_COMMAND 0x1D
#define OFFSET_CONTROL_DEVICE 0x39

#endif /* USE_ATARI_IO */

#define TIME_OUT_CMD          200 // 1 second
#define TIME_OUT_4S           800
#define TIME_OUT_10S         2000

	.globl install_scsidrv
#ifdef COLDFIRE
	.globl install_hddriver
	.globl conv_ascii_value_optimized
	.globl error_unknow_device
	.globl error_ok
#if defined(MCF5445X) || defined(MCF547X)
      	.globl ide_reset
#endif
#endif
	.globl read_sectors
	.globl write_sectors
	.globl ide_cmd
	.globl scsi_cmd
	.globl swap_buffer
	.globl delay_hz_200
	.globl get_cookie
	.globl message0b

	.text

	.chip 68060 // some code to fix
	
	// SCSIDRV

install_scsidrv:

#ifdef COLDFIRE
	lea -24(SP),SP
	movem.l D0-D2/A0-A2,(SP)
#else
	movem.l D0-D2/A0-A2,-(SP)
#endif
	move.l #0x53435349,D0    // SCSI
	jsr get_cookie
	bne .error_install       // already installed by an hd driver ?
	move.w #3,-(SP)          // TT ram if possible
	move.l #SCSI_COOKIE_SIZE,-(SP) // size
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	beq .error_install
.malloc_ok:
	move.l D0,A2
	move.l D0,A1
	move.w #0x101,(A1)+      // version
	lea In(PC),A0
	move.l A0,(A1)+
	lea Out(PC),A0
	move.l A0,(A1)+
	lea InquireSCSI(PC),A0
	move.l A0,(A1)+
	lea InquireBus(PC),A0
	move.l A0,(A1)+
	lea CheckDev(PC),A0
	move.l A0,(A1)+
	lea RescanBus(PC),A0
	move.l A0,(A1)+
	lea Open(PC),A0
	move.l A0,(A1)+
	lea Close(PC),A0
	move.l A0,(A1)+
	lea Error(PC),A0
	move.l A0,(A1)+
	lea Install(PC),A0
	move.l A0,(A1)+
	lea Deinstall(PC),A0
	move.l A0,(A1)+
	lea GetCmd(PC),A0
	move.l A0,(A1)+
	lea SendData(PC),A0
	move.l A0,(A1)+
	lea GetData(PC),A0
	move.l A0,(A1)+
	lea SendStatus(PC),A0
	move.l A0,(A1)+
	lea SendMsg(PC),A0
	move.l A0,(A1)+
	lea GetMsg(PC),A0
	move.l A0,(A1)+
	move.l phystop,A0
	move.w #cAllCmds,D0
	move.w D0,Features(A0)   // IDE device 0
	move.w D0,Features+2(A0) // IDE device 1
	move.w D0,Features+4(A0) // IDE2 device 0
	move.w D0,Features+6(A0) // IDE2 device 1
	clr.l ScsiDrvID(A0)
	move.l A0,-(SP)
	move.w #3,-(SP)          // TT ram if possible
	move.l #1024,-(SP)       // size
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	move.l (SP)+,A0
	move.l D0,Buffer1024(A0)
	beq.s .error_install
	move.l #0x53435349,D0    // SCSI
	move.l D0,ScsiDrvID(A0)
	lea ReqData(A0),A0
	move.l A0,(A1)+
	move.l cookie,D0
	beq.s .error_install
	move.l D0,A0
.find_cookiejar:
		tst.l (A0)
		beq.s .cookie_slotfree
		addq.l #8,A0
	bra.s .find_cookiejar
.cookie_slotfree:
	move.l 4(A0),12(A0)      // copy size
	move.l #0x53435349,(A0)+ // SCSI
	move.l A2,(A0)+
	clr.l (A0)
.error_install:
#ifdef COLDFIRE
	movem.l (SP),D0-D2/A0-A2
	lea 24(SP),SP
#else
	movem.l (SP)+,D0-D2/A0-A2
#endif
	rts
	
In:

#ifdef COLDFIRE
	lea -40(SP),SP
	movem.l D1-D5/A0-A4,(SP)
#else /* !COLDFIRE */
	movem.l D1-D5/A0-A4,-(SP)
#endif /* COLDFIRE */
#ifdef DEBUG
	lea debug130(PC),A0
	bsr debug_display_string
	move.l 4+40(SP),A2       // Parms
	move.l (A2),D0           // Handle
	bsr debug_hex_long
	lea debug152(PC),A0
	bsr debug_display_string
	move.l 10(A2),D0         // Buffer
	bsr debug_hex_long
     	lea debug154(PC),A0
	bsr debug_display_string
	move.l 14(A2),D0         // TransferLen
	bsr hex_long
	lea debug153(PC),A0
	bsr debug_display_string
	move.l 22(A2),D0         // Timeout
	bsr hex_long
	lea debug150(PC),A0
	bsr debug_display_string
	moveq #0,D2
	move.w 8(A2),D2          // CmdLen
	move.l 4(A2),A0          // Cmd
.in0:
		move.b (A0)+,D0
		bsr debug_hex_byte
		moveq #0x20,D0
		bsr debug_display_char
	subq.l #1,D2
	bgt.s .in0
	moveq #0x20,D0
	bsr debug_display_char
#endif /* DEBUG */
	move.w SR,D0             // supervisor only
	moveq #TIMEOUTERROR,D5   // error code
	move.l 4+40(SP),A2       // Parms
	move.l 18(A2),D0         // SenseBuffer (18 bytes)
	beq.s .in19
	move.l D0,A0
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.w (A0)
.in19:
	move.l (A2),D4           // Handle
	move.l phystop,A1
	lea Features(A1),A0
	sub.l A0,D4
	asr.l #1,D4
	bmi .in1                 // error
#ifdef SECOND_IDE_BUS
#ifdef COLDFIRE
	cmp.l #4,D4              // FIREBEE
#else /* CT60/CTPCI */
	bsr get_ide2_address
	sne.b D0
	and.l #2,D0
	addq.l #2,D0
	cmp.l D0,D4
#endif /* COLDFIRE */
#else /* !SECOND_IDE_BUS */
	cmp.l #2,D4
#endif /* SECOND_IDE_BUS */
	bcc .in1                 // error
	move.l 4(A2),A3          // Cmd
	moveq #0,D0
	move.w 8(A2),D0          // CmdLen
	cmp.l #6,D0
	bcs .in1                 // error
//	move.w 26(A2),D3         // Flags
	moveq #0,D0
	move.b (A3),D0           // command
	cmp.l #0x12,D0           // inquiry
	beq .in4
#ifdef SCSI_EMULATION
	tst.b PacketDevice(A1,D4.l)
	bne .in2                 // ATAPI devices (packet command)
	// SCSI emulation
	move.l #0x53435349,D0    // SCSI
	cmp.l ScsiDrvID(A1),D0
	bne .in1                 // data destroyed ?
	move.l Buffer1024(A1),D0
	beq .in1
	move.l D0,A0             // buffer IDE
	move.l 10(A2),A4         // Buffer
	move.l 14(A2),D1         // TransferLen
	link A6,#-8
	moveq #0,D0
	move.b (A3),D0           // command : test unit ready
	bne.s .in11
	lea -8(A6),A1            // cmd buffer
	move.b #0xE5,(A1)        // check power mode
	moveq #3,D0
	and.w D4,D0              // drive
	asl.w #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	clr.w 2(A1)              // cyl high & low
	clr.w 4(A1)              // sec num & count
	clr.b 6(A1)              // features
	moveq #0,D0              // bytes
	bsr ide_cmd
	bmi .in16
//	moveq #BSYERROR,D5
//	tst.b ATA_SECTOR_COUNT
//	beq .in16                // not ready
	bra .in17                // OK
.in11:
	cmp.l #0x03,D0           // request sense
	bne.s .in20
	move.l 18(A2),D0         // SenseBuffer (18 bytes)
	beq .in17
	move.l D0,A1
	move.b #0x72,(A1)        // response code
	clr.b 1(A1)              // segment number
	move.b #2,2(A1)          // sense key: no sense
	clr.l 3(A1)              // information
	move.b #10,7(A1)         // additional sense length (n-7)
	move.w #0x0206,8(A1)     // sense specific sense descriptor
	clr.w 10(A1)
	move.b #0x80,12(A1)      // sense-key specific
	clr.l 14(A1)
	bra .in17
.in20:
	cmp.l #0x08,D0           // read
	bne.s .in12
	moveq #0,D2
	move.b 1(A3),D2
	and.l #0x1F,D2
	swap D2
	move.w 2(A3),D2          // LBA 21 bits
	bra.s .in13
.in12:
	cmp.l #0x28,D0           // read
	bne .in14
	move.l 2(A3),D2          // LBA 32 bits
.in13:
	add.l #0x1FF,D1          // TransferLen
	lsr.l #8,D1
	lsr.l #1,D1              // / 512
	beq .in16
	cmp.l #0x100,D1
	bhi .in16                // error
	lea -8(A6),A1            // cmd buffer
	move.l A4,A0             // buffer IDE
	moveq #3,D0
	and.w D4,D0              // physical drive
	asl.w #4,D0
	or.b #0x40,D0            // LBA
	move.b D0,1(A1)          // drive (C/D/H)
	move.l D2,D0             // LBA
	move.b D0,4(A1)          // sec num, LBA low
	lsr.l #8,D0
	move.w D0,2(A1)          // cyl high & low, LBA high & mid
	move.b D1,5(A1)          // sec count 0 <=> 256
	cmp.l #0x1000000,D2
	bcc.s .in22	
	move.b #0x20,(A1)        // read sector(s)
	clr.b 6(A1)              // features
	bra.s .in21
.in22:
	move.b #0x24,(A1)        // read sector(s) ext
	movel D2,D0
	swap D0
	lsr.l #8,D0
	move.b D0,6(A1)          // features, trick for pass LBA B39-B23 as previous data to ide_cmd
.in21:
	moveq #0,D0
	move.w D1,D0             // count
	add.l D0,D0
	asl.l #8,D0              // * 512 = bytes
             bsr ide_cmd
             bmi .in16                // time-out
             beq .in17                // OK
.in18:
             moveq #PARITIYERROR,D5
             bra .in16
.in14:
	cmp.l #0x1A,D0           // mode sense
	bne .in15
	cmp.l #20,D1             // TransferLen
	bcs .in16
	moveq #0x3F,D0
	and.b 2(A3),D0
	cmp.l #0x08,D0           // caching mode page
	bne .in16
	lea -8(A6),A1            // cmd buffer
	move.b #0xEC,(A1)        // identify device
	moveq #3,D0
	and.w D4,D0              // drive
	asl.w #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	clr.w 2(A1)              // cyl high & low
	clr.w 4(A1)              // sec num & count
	clr.b 6(A1)              // features
	move.l #512,D0           // bytes
	bsr ide_cmd
	bmi .in16                // time-out
	bne .in18                // error
	move.b #8,(A4)           // page code
	move.b #12,1(A4)         // page length
	btst #5,171(A0)          // write cache enable
	sne.b D0
	and.l #4,D0              // WCE
	move.b D0,2(A4)
	clr.b 3(A4)
	clr.l 6(A4)
	clr.w 10(A4)
	btst #6,171(A0)          // look ahead enable
	seq.b D0
	and.l #0x20,D0           // DRA
	move.b D0,12(A4)
	clr.b 13(A4)
	clr.w 14(A4)
	clr.l 16(A4)	
	bra .in17
.in15:
	cmp.l #0x25,D0           // read capacity
	bne.s .in16
	cmp.l #4,D1              // TransferLen
	bcs.s .in16
	lea -8(A6),A1            // cmd buffer
	move.b #0xEC,(A1)        // identify device
	moveq #3,D0
	and.w D4,D0              // drive
	asl.w #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	clr.w 2(A1)              // cyl high & low
	clr.w 4(A1)              // sec num & count
	clr.b 6(A1)              // features
	move.l #512,D0           // bytes
	bsr ide_cmd
	bmi .in16                // time-out
	bne .in18                // error
	move.l 120(A0),D0        // total sectors
	swap D0
	move.l D0,(A4)           // logical block address
	move.l #512,4(A4)        // block length
.in17:
	moveq #NOSCSIERROR,D5
.in16:
	unlk A6
	// end of SCSI emulation
	bra .in1
#endif /* SCSI_EMULATION */
.in2:	// packet
	moveq #TIMEOUTERROR,D5   // error code
	link A6,#-20
	lea -20(A6),A1           // cmd buffer
	move.b #0xA0,(A1)        // packet
	moveq #3,D0
	and.l D4,D0              // drive
	asl.l #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	move.w #ATAPI_SECTOR_SIZE,D1
	move.w D1,2(A1)          // cyl high & low, LBA high & mid = maxByteCount
	clr.w 4(A1)              // sec num & count
	moveq #4,D0              // transfer to the host
	move.b D0,6(A1)          // features
	move.l (A3),8(A1)        // ATAPI command
	move.l 4(A3),12(A1)
	move.l 8(A3),16(A1)
	move.l 10(A2),A0         // Buffer for receive data
	move.l 14(A2),D0         // TransferLen
	move.l 22(A2),D1         // Timeout
	bsr ide_cmd
	bmi.s .in10              // timeout
	lsr.l #4,D0              // sense
	bne.s .in3               // error
	moveq #NOSCSIERROR,D5
	bra.s .in10
.in3:
	tst.l 18(A2)             // SenseBuffer (18 bytes)
	beq.s .in10              // no sense buffer
	move.b #0xA0,(A1)        // packet
	moveq #3,D0
	and.l D4,D0              // drive
	asl.l #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	move.w #ATAPI_SECTOR_SIZE,D1
	move.w D1,2(A1)          // cyl high & low, LBA high & mid = maxByteCount
	clr.w 4(A1)              // sec num & count
	moveq #4,D0              // transfer to the host
	move.b D0,6(A1)          // features
	move.l #0x03000000,D0
	move.l D0,8(A1)          // request sense
	moveq #18,D0
	move.b D0,12(A1)         // length
	clr.b 13(A1)
	clr.w 14(A1)
	clr.l 16(A1)
	move.l 18(A2),A0         // SenseBuffer (18 bytes)
	move.l 22(A2),D1         // Timeout
	bsr ide_cmd
	bmi.s .in10              // timeout
	moveq #2,D5              // CheckCondition
.in10:
	unlk A6
	bra .in1
.in4:	// inquiry
	move.l phystop,A1
	move.l #0x53435349,D0    // SCSI
	cmp.l ScsiDrvID(A1),D0
	bne .in1                 // data destroyed ?
	move.l Buffer1024(A1),D0
	beq .in1	
	move.l D0,A0             // buffer IDE
	move.l 10(A2),A4         // Buffer for receive data
	move.l 14(A2),D1         // TransferLen
	link A6,#-8
	cmp.l #32,D1             // TransferLen
	bcs .in6
	lea -8(A6),A1            // cmd buffer
	move.b #0xA1,(A1)        // identify packet device
	moveq #3,D0
	and.l D4,D0              // drive
	asl.l #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	clr.w 2(A1)              // cyl high & low
	clr.w 4(A1)              // sec num & count
	clr.b 6(A1)              // features
	move.l #512,D0           // bytes
	move.l D1,-(SP)          // TransferLen
	bsr ide_cmd
#ifdef SCSI_EMULATION
	moveq #-1,D1
	move.l phystop,A1
	move.b D1,PacketDevice(A1,D4.l)
#endif /* SCSI_EMULATION */
	move.l (SP)+,D1          // TransferLen
	tst.l D0
	beq.s .in7               // OK
	lea -8(A6),A1            // cmd buffer
	move.b #0xEC,(A1)        // identify device
	moveq #3,D0
	and.l D4,D0              // drive
	asl.l #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	clr.w 2(A1)              // cyl high & low
	clr.w 4(A1)              // sec num & count
	clr.b 6(A1)              // features
	move.l #512,D0           // bytes
	move.l D1,-(SP)          // TransferLen
	bsr ide_cmd
	move.l (SP)+,D1          // TransferLen
	tst.l D0
	bne .in6                 // time-out
	and.b #0xE0,(A0)         // force to 0 command packet set (identify device packet)
#ifdef SCSI_EMULATION
	move.l phystop,A1
	clr.b PacketDevice(A1,D4.l)
#endif
.in7:
	moveq #0x1F,D0
	and.b (A0),D0            // command packet set
	asl.l #8,D0
	beq.s .in8
	bset #7,D0               // removable	
.in8:
	move.w D0,(A4)           // device type
	move.b #3,2(A4)          // ANSI
	clr.b 3(A4)
	move.b #32,4(A4)         // length - 4
	clr.b 5(A4)
	clr.w 6(A4)
	cmp.l #36,D1             // TransferLen
	bcs.s .in9
	move.l 46(A0),32(A4)     // revision
.in9:
	moveq #15,D0
	lea 54(A0),A0
	lea 8(A4),A1
	moveq #23,D0
.in5:
		move.b (A0)+,(A1)+ // model
	subq.l #1,D0
	bpl.s .in5
	moveq #NOSCSIERROR,D5
#ifdef DEBUG
	lea debug155(PC),A0
	bsr debug_display_string
	move.l D1,D2             // TransferLen
	move.l A4,A0             // Buffer
.in00:
		move.b (A0)+,D0
		bsr debug_hex_byte
		moveq #0x20,D0
		bsr debug_display_char
	subq.l #1,D2
	bgt.s .in00
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
.in6:
	unlk A6
//	tst.w (A4)               // device type
//	bne .in2                 // ATAPI device, try again with the real inquiry command
.in1:
	move.l D5,D0             // error code
#ifdef DEBUG
	lea debug145(PC),A0
	bsr debug_display_string
	move.l D5,D0
	bsr debug_hex_word
	lea debug146(PC),A0
	bsr debug_display_string
	move.l 18(A2),D0         // SenseBuffer (18 bytes)
	beq.s .ind
	move.l D0,A0	
	move.b 2(A0),D0          // key
	and.l #0xF,D0
	bsr debug_hex_byte
	lea debug147(PC),A0
	bsr debug_display_string
	move.l 18(A2),A0         // SenseBuffer (18 bytes)
	move.b 12(A0),D0         // ASC
	bsr debug_hex_byte
	lea debug148(PC),A0
	bsr debug_display_string
	move.l 18(A2),A0         // SenseBuffer (18 bytes)
	move.b 13(A0),D0         // ASCQ
	bsr debug_hex_byte
.ind:
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l D5,D0
#endif
#ifdef COLDFIRE
	movem.l (SP),D1-D5/A0-A4
	lea 40(SP),SP
#else
	movem.l (SP)+,D1-D5/A0-A4
#endif
	rts

Out:

#ifdef COLDFIRE
	lea -40(SP),SP
	movem.l D1-D5/A0-A4,(SP)
#else
	movem.l D1-D5/A0-A4,-(SP)
#endif
#ifdef DEBUG
	lea debug131(PC),A0
	bsr debug_display_string
	move.l 4+40(SP),A2       // Parms
	move.l (A2),D0           // Handle
	bsr debug_hex_long
	lea debug152(PC),A0
	bsr debug_display_string
	move.l 10(A2),D0         // Buffer
	bsr debug_hex_long
     	lea debug154(PC),A0
	bsr debug_display_string
	move.l 14(A2),D0         // TransferLen
	bsr hex_long
	lea debug153(PC),A0
	bsr debug_display_string
	move.l 22(A2),D0         // Timeout
	bsr hex_long
	lea debug150(PC),A0
	bsr debug_display_string
	moveq #0,D2
	move.w 8(A2),D2          // CmdLen
	move.l 4(A2),A0          // Cmd
.out0:
		move.b (A0)+,D0
		bsr debug_hex_byte
		moveq #0x20,D0
		bsr debug_display_char
	subq.l #1,D2
	bgt.s .out0
	moveq #0x20,D0
	bsr debug_display_char
#endif
	move.w SR,D0             // supervisor only
	moveq #TIMEOUTERROR,D5   // error code
	move.l 4+40(SP),A2       // Parms
	move.l 18(A2),D0         // SenseBuffer (18 bytes)
	beq.s .out11
	move.l D0,A0
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.w (A0)
.out11:
	move.l (A2),D4           // Handle
	move.l phystop,A1
	lea Features(A1),A0
	sub.l A0,D4
	asr.l #1,D4
	bmi .out1                // error
#ifdef SECOND_IDE_BUS
#ifdef COLDFIRE
	cmp.l #4,D4              // FIREBEE
#else /* CT60/CTPCI */
	bsr get_ide2_address
	sne.b D0
	and.l #2,D0
	addq.l #2,D0
	cmp.l D0,D4
#endif /* COLDFIRE */
#else /* !SECOND_IDE_BUS */
	cmp.l #2,D4
#endif /* SECOND_IDE_BUS */
	bcc .out1                // error
	move.l 4(A2),A3          // Cmd
	moveq #0,D0
	move.w 8(A2),D0          // CmdLen
	cmp.l #6,D0
	bcs .out1                // error
//	move.w 26(A2),D3         // Flags
	link A6,#-20
#ifdef SCSI_EMULATION
	move.l phystop,A1
	tst.b PacketDevice(A1,D4.l)
	bne .out5                // ATAPI devices (packet command)
	// SCSI emulation
	move.l 10(A2),A4         // Buffer
	move.l 14(A2),D1         // TransferLen
	moveq #0,D0
	move.b (A3),D0           // command
#if 0
	cmp.l #0xA,D0            // write
	bne.s .out4
	moveq #0,D2
	move.b 1(A3),D2
	and.l #0x1F,D2
	swap D2
	move.w 2(A3),D2          // LBA 21 bits
	bra.s .out9
.out4:	
	cmp.l #0x2A,D0           // write
	bne .out6
	move.l 2(A3),D2          // LBA 32 bits
.out9:
	add.l #0x1FF,D1          // TransferLen
	lsr.l #8,D1
	lsr.l #1,D1              // / 512
	beq .out3
	cmp.l #0x100,D1
	bcc .out3                // error
	lea -8(A6),A1            // cmd buffer	
	move.l A4,A0             // buffer IDE
	moveq #3,D0
	and.w D4,D0              // physical drive
	asl.w #4,D0
	or.b #0x40,D0            // LBA
	move.b D0,1(A1)          // drive (C/D/H)
	move.l D2,D0             // LBA
	move.b D0,4(A1)          // sec num, LBA low
	lsr.l #8,D0
	move.w D0,2(A1)          // cyl high & low, LBA high & mid
	move.b D1,5(A1)          // sec count 0 <=> 256
	cmp.l #0x1000000,D2
	bcc.s .out12
	move.b #0x30,(A1)        // write sector(s)
	clr.b 6(A1)              // features
             bra.s .out13
.out12:
	move.b #0x34,(A1)        // write sector(s) ext
	movel D2,D0
	swap D0
	lsr.l #8,D0
	move.b D0,6(A1)          // features, trick for pass LBA B39-B23 as previous data to ide_cmd	
.out13:
	moveq #0,D0
	move.w D1,D0             // count
	add.l D0,D0
	asl.l #8,D0              // * 512 = bytes
             bsr ide_cmd
             bmi .out3                // time-out
             beq .out10               // OK
             moveq #PARITIYERROR,D5
             bra .out3
.out6:
#endif
	cmp.l #0x15,D0           // mode select
	bne .out3
	cmp.l #20,D1             // TransferLen
	bcs .out3
	moveq #0x3F,D0
	and.b 2(A3),D0
	cmp.l #8,D0              // caching mode page
	bne .out3
	moveq #2,D2              // enable write cache
	btst #2,2(A4)            // WCE
	bne.s .out7
	move.w #0x82,D2          // disable write cache 
.out7:
	moveq #0x55,D3           // disable read look ahead 
	btst #5,12(A1)           // DRA
	bne.s .out8
	move.w #0xAA,D3          // enable read look ahead
.out8:
	lea -8(A6),A1            // cmd buffer
	move.b #0xEF,(A1)        // set features
	moveq #7,D0
	and.w D4,D0              // drive
	asl.w #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	clr.w 2(A1)              // cyl high & low
	clr.w 4(A1)              // sec num & count
	move.b D2,6(A1)          // features
	moveq #0,D0              // bytes
	bsr ide_cmd
	bmi .out3                // time-out
	lea -8(A6),A1            // cmd buffer
	move.b #0xEF,(A1)        // set features
	moveq #3,D0
	and.w D4,D0              // drive
	asl.w #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	clr.w 2(A1)              // cyl high & low
	clr.w 4(A1)              // sec num & count
	move.b D3,6(A1)          // features
	moveq #0,D0              // bytes
	bsr ide_cmd
	bmi .out3                // time-out
	bra .out10               // OK
	// end of SCSI emulation
#endif /* SCSI_EMULATION */
.out5:	// packet
	lea -20(A6),A1           // cmd buffer
	move.b #0xA0,(A1)        // packet
	moveq #3,D0
	and.l D4,D0              // drive
	asl.l #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	move.w #ATAPI_SECTOR_SIZE,D1
	move.w D1,2(A1)          // cyl high & low, LBA high & mid = maxByteCount
	clr.w 4(A1)              // sec num & count
	clr.b 6(A1)              // features
	move.l (A3),8(A1)        // ATAPI command
	move.l 4(A3),12(A1)
	move.l 8(A3),16(A1)
	move.l 10(A2),A0         // Buffer for receive data
	move.l 14(A2),D0         // TransferLen
	move.l 22(A2),D1         // Timeout
	bsr ide_cmd
	bmi.s .out3              // timeout
	lsr.l #4,D0              // sense
	bne.s .out2              // error
.out10:
	moveq #NOSCSIERROR,D5
	bra.s .out3
.out2:
	tst.l 18(A2)             // SenseBuffer (18 bytes)
	beq.s .out3              // no sense buffer
	move.b #0xA0,(A1)        // packet
	moveq #3,D0
	and.l D4,D0              // drive
	asl.l #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	move.w #ATAPI_SECTOR_SIZE,D1
	move.w D1,2(A1)          // cyl high & low, LBA high & mid = maxByteCount
	clr.w 4(A1)              // sec num & count
	moveq #4,D0              // transfer to the host
	move.b D0,6(A1)          // features
	move.l #0x03000000,D0
	move.l D0,8(A1)          // request sense
	moveq #18,D0
	move.b D0,12(A1)         // length
	clr.b 13(A1)
	clr.w 14(A1)
	clr.l 16(A1)
	move.l 18(A2),A0         // SenseBuffer (18 bytes)
	move.l 22(A2),D1         // Timeout
	bsr ide_cmd
	bmi.s .out3              // timeout
	moveq #2,D5              // CheckCondition
.out3:
	unlk A6
.out1:
	move.l D5,D0             // error code
#ifdef DEBUG
	lea debug145(PC),A0
	bsr debug_display_string
	move.l D5,D0
	bsr debug_hex_word
	lea debug146(PC),A0
	bsr debug_display_string
	move.l 18(A2),D0         // SenseBuffer (18 bytes)
	beq.s .outd
	move.l D0,A0
	move.b 2(A0),D0          // key
	and.l #0xF,D0
	bsr debug_hex_byte
	lea debug147(PC),A0
	bsr debug_display_string
	move.l 18(A2),A0         // SenseBuffer (18 bytes)
	move.b 12(A0),D0         // ASC
	bsr debug_hex_byte
	lea debug148(PC),A0
	bsr debug_display_string
	move.l 18(A2),A0         // SenseBuffer (18 bytes)
	move.b 13(A0),D0         // ASCQ
	bsr debug_hex_byte
.outd:
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l D5,D0
#endif
#ifdef COLDFIRE
	movem.l (SP),D1-D5/A0-A4
	lea 40(SP),SP
#else
	movem.l (SP)+,D1-D5/A0-A4
#endif
	rts

InquireSCSI:

	move.l A1,-(SP)
	move.l A0,-(SP)
#ifdef DEBUG
	lea debug144(PC),A0
	bsr debug_display_string
#endif
	move.l 6+8(SP),A0        // Info
	move.l phystop,A1
	tst.w 4+8(SP)            // what 
	bne.s .is2               // cInqNext
	clr.l (A0)+              // Private.BusIds
	clr.l (A0)+              // Private.resrvd
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	move.l #0x49444500,(A0)+ // BusName, IDE
	clr.l (A0)+
#ifdef DEBUG
	move.l A0,-(SP)
	lea -8(A0),A0
	bsr debug_display_string
	move.l (SP)+,A0	
#endif	
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	move.w #2,(A0)+          // BusNo, IDE
	clr.w BusNumber(A1)
	move.w Features(A1),(A0)+
.is3:
	move.l #XFRB_SIZE,(A0)+  // MaxLen
	moveq #0,D0
	bra.s .is4
.is2:
#ifdef SECOND_IDE_BUS
#ifndef COLDFIRE
	bsr get_ide2_address
	beq.s .is1               // not found, no 2nd IDE
#endif
	tst.w BusNumber(A1)
	bne.s .is1
	clr.l (A0)+              // Private.BusIds
	clr.l (A0)+              // Private.resrvd
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	move.l #0x49444532,(A0)+ // BusName, IDE2
	clr.l (A0)+
#ifdef DEBUG
	move.l A0,-(SP)
	lea -8(A0),A0
	bsr debug_display_string
	move.l (SP)+,A0	
#endif	
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	move.w #3,(A0)+          // BusNo, IDE not compatible
	moveq #1,D0
	move.w D0,BusNumber(A1)
	move.w Features+2(A1),(A0)+
	bra.s .is3
.is1:
#endif /* SECOND_IDE_BUS */
	moveq #-1,D0
.is4:
#ifdef DEBUG
	move.l D0,-(SP)
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0	
#endif	
	move.l (SP)+,A0
	move.l (SP)+,A1
	rts
	
InquireBus:

	move.l A0,-(SP)
#ifdef DEBUG
	lea debug143(PC),A0
	bsr debug_display_string
	move.w 6+4(SP),D0        // BusNo
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	moveq #0,D0
	move.w 6+4(SP),D0        // BusNo
	cmp.l #2,D0              // IDE
#ifdef SECOND_IDE_BUS
	beq.s .ib4
#ifndef COLDFIRE
	bsr get_ide2_address
	beq.s .ib1               // not found, no 2nd IDE
	moveq #0,D0
	move.w 6+4(SP),D0        // BusNo
#endif
	cmp.l #3,D0              // IDE not compatible
#endif /* SECOND_IDE_BUS */
	bne.s .ib1
.ib4:
	move.l 8+4(SP),A0        // Dev
	clr.l (A0)+              // Private
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+              // SCSIId		
	tst.w 4+4(SP)            // what 
	bne.s .ib2               // cInqNext
	clr.l (A0)+
	bra.s .ib3
.ib2:
	tst.l (A0)
	bne.s .ib1
	moveq #1,D0
	move.l D0,(A0)+
.ib3:
	moveq #0,D0
	move.l (SP)+,A0
	rts
.ib1:
	moveq #-1,D0
	move.l (SP)+,A0
	rts
	
CheckDev:

	move.l A1,-(SP)
	move.l A0,-(SP)
#ifdef DEBUG
	lea debug142(PC),A0
	bsr debug_display_string
	move.w 4+8(SP),D0        // BusNo
	bsr debug_hex_byte
	lea debug149(PC),A0
	bsr debug_display_string
	move.l 6+8(SP),A0        // SCSIId
	move.l 4(A0),D0          // SCSIId.lo
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	move.l phystop,A1
	move.l 6+8(SP),A0        // SCSIId
	move.l 4(A0),D0          // SCSIId.lo
	cmp.l #2,D0
	bcc.s .cd1               // error (2 devices max on IDE)
	moveq #0,D0
	move.w 4+8(SP),D0        // BusNo
	cmp.l #2,D0              // IDE
	bne.s .cd2
	move.l 10+8(SP),A0       // Name
	move.l #0x49444500,(A0)+ // BusName, IDE
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	move.l 14+8(SP),A0       // Features
	move.w Features(A1),(A0)+
	moveq #0,D0
	bra.s .cd3
.cd2:
#ifdef SECOND_IDE_BUS
#ifndef COLDFIRE
	bsr get_ide2_address
	beq.s .cd1               // not found, no 2nd IDE
	moveq #0,D0
	move.w 4+8(SP),D0        // BusNo
#endif
	cmp.l #3,D0              // IDE not compatible
	bne.s .cd1               // error
	move.l 10+8(SP),A0       // Name
	move.l #0x49444532,(A0)+ // BusName, IDE2
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	clr.l (A0)+
	move.l 14+8(SP),A0       // Features
	move.w Features+2(A1),(A0)+
	moveq #0,D0
	bra.s .cd3
#endif /* SECOND_IDE_BUS */
.cd1:
	moveq #-15,D0            // unknown device
.cd3:
	move.l (SP)+,A0
	move.l (SP)+,A1
	rts

RescanBus:

#ifdef DEBUG
	move.l A0,-(SP)
	lea debug141(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
	move.w 4(SP),D0          // BusNo
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	moveq #0,D0
	move.w 4(SP),D0          // BusNo
	cmp.l #2,D0              // IDE
#ifdef SECOND_IDE_BUS
	beq.s .rb2
#ifndef COLDFIRE
	bsr get_ide2_address
	beq.s .rb1               // not found, no 2nd IDE
	moveq #0,D0
	move.w 4(SP),D0          // BusNo
#endif
	cmp.l #3,D0              // IDE not compatible
#endif /* SECOND_IDE_BUS */
	bne.s .rb1               // error
.rb2:
	moveq #0,D0
	rts
.rb1:
	moveq #-15,D0            // unknown device
	rts

Open:

#ifdef COLDFIRE
	lea -12(SP),SP
	movem.l D1/A0-A1,(SP)
#else
	movem.l D1/A0-A1,-(SP)
#endif
#ifdef DEBUG
	lea debug138(PC),A0
	bsr debug_display_string
	move.w 4+12(SP),D0       // BusNo
	bsr debug_hex_byte
	lea debug149(PC),A0
	bsr debug_display_string
	move.l 6+12(SP),A0       // SCSIId
	move.l 4(A0),D0          // SCSIId.lo
	bsr debug_hex_byte
#endif
	move.l phystop,A1
	move.l 6+12(SP),A0       // SCSIId
	move.l 4(A0),D0          // SCSIId.lo
	cmp.l #2,D0
	bcc.s .op1               // error (2 devices max on IDE)
	moveq #0,D1
	move.w 4+12(SP),D1       // BusNo
	cmp.l #2,D1              // IDE
	bne.s .op3
.op5:
	move.l 10+12(SP),A0      // MaxLen
	move.l #XFRB_SIZE,(A0)
#ifdef SCSI_EMULATION
	clr.b PacketDevice(A1,D0.l)
#endif
	add.l D0,D0              // * 2 Features size
	lea Features(A1),A0
	add.l A0,D0              // Handle
	bra.s .op4
.op3:
#ifdef SECOND_IDE_BUS
#ifndef COLDFIRE
	bsr get_ide2_address
	beq.s .op2               // not found, no 2nd IDE
	move.l 4(A0),D0          // SCSIId.lo
#endif
	cmp.l #3,D1              // IDE not compatible
	bne.s .op2
	addq.l #2,D0
	bra.s .op5
#endif /* SECOND_IDE_BUS */
.op2:
	moveq #-35,D0            // no more handles
	bra.s .op4
.op1:
	moveq #-15,D0            // unknown device
.op4:
#ifdef DEBUG
	move.l D0,-(SP)
	lea debug151(PC),A0
	bsr debug_display_string
	move.l (SP),D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
	move.l (SP)+,D0
#endif
#ifdef COLDFIRE
	movem.l (SP),D1/A0-A1
	lea 12(SP),SP
#else
	movem.l (SP)+,D1/A0-A1
#endif
	rts

Close:

#ifdef DEBUG
	move.l A0,-(SP)
	lea debug139(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	moveq #NOSCSIERROR,D0
	rts

Error:

#ifdef DEBUG
	move.l A0,-(SP)
	lea debug140(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	move.l 4(SP),D0          // handle
	move.w 8(SP),D0          // rwflag
	move.w 10(SP),D0         // ErrNo
	moveq #NOSCSIERROR,D0
	rts
	
Install:
Deinstall:
GetCmd:
SendData:
GetData:
SendStatus:
SendMsg:
GetMsg:

#ifdef DEBUG
	move.l A0,-(SP)
	lea debug156(PC),A0
	bsr debug_display_string
	move.l (SP)+,A0
#endif
	moveq #-1,D0             // error
	rts

#ifdef COLDFIRE

	// XHDI
	
	dc.l 0x27011992
	
xhdi:
	
	link A6,#0
#ifdef COLDFIRE
	lea -52(SP),SP
	movem.l D1-A5,(SP)
#else
	movem.l D1-A5,-(SP)
#endif
	moveq #0,D1
	move.w 8(A6),D1
	moveq #-32,D0            // invalid function
	cmp.l #18,D1
	bcc.s .bad_xhdi
	move.w SR,D0             // supervisor only
	moveq #-1,D0             // error
	move.w tab_xhdi(PC,D1.l*2),D1
	jsr tab_xhdi(PC,D1.l)
.bad_xhdi:
#ifdef COLDFIRE
	movem.l (SP),D1-A5
	lea 52(SP),SP
#else
	movem.l (SP)+,D1-A5
#endif
	unlk A6
	rts
tab_xhdi:
	dc.w XHGetVersion-tab_xhdi    // 0
	dc.w XHInqTarget-tab_xhdi     // 1
	dc.w XHReserve-tab_xhdi       // 2
	dc.w XHLock-tab_xhdi          // 3
	dc.w XHStop-tab_xhdi          // 4
	dc.w XHEject-tab_xhdi         // 5
	dc.w XHDrvMap-tab_xhdi        // 6
	dc.w XHInqDev-tab_xhdi        // 7
	dc.w XHInqDriver-tab_xhdi     // 8
	dc.w XHNewCookie-tab_xhdi     // 9
	dc.w XHReadWrite-tab_xhdi     // 10
	dc.w XHInqTarget2-tab_xhdi    // 11
	dc.w XHInqDev2-tab_xhdi       // 12
	dc.w XHDriverSpecial-tab_xhdi // 13
	dc.w XHGetCapacity-tab_xhdi   // 14
	dc.w XHMediumChanged-tab_xhdi // 15
	dc.w XHMiNTInfo-tab_xhdi      // 16
	dc.w XHDOSLimits-tab_xhdi     // 17
	
XHGetVersion:

	move.l #0x120,D0         //  protocol version
	rts
	
XHInqTarget:

	moveq #32,D3             // stringlen
	bra.s .xi1
	
XHInqTarget2:

#ifdef COLDFIRE
#ifdef DEBUG
	lea debug133(PC),A0
	bsr debug_display_string
#endif
#endif
	move.l 26(A6),D3         // stringlen
.xi1:
	tst.w 12(A6)             // minor
	bne.s .xi2
	moveq #0,D4
	move.w 10(A6),D4         // major
	and.l #PUN_IDE,D4
	bne.s .xi3
.xi2:
	moveq #-15,D0            // unknown device
	rts
.xi3:
	move.w 10(A6),D4         // major
	move.l 14(A6),D1
	beq.s .xi10
	move.l D1,A0             // blocksize
	move.l #512,(A0)
.xi10:
	move.l 18(A6),D1
	beq.s .xi9
	move.l D1,A0             // device_flags
	clr.l (A0)
.xi9:
	move.l 22(A6),D1         // product_name, 32 characters
	beq.s .xi4
	move.l D1,A2
	clr.b (A2)
	link A6,#-8
	move.l _dskbufp,A0       // IDE buffer
	clr.w (A0)
	lea -8(A6),A1            // cmd buffer
	move.b #0xEC,(A1)        // identify device
	moveq #3,D0
	and.l D4,D0              // drive
	asl.l #4,D0
	move.b D0,1(A1)          // drive (C/D/H)
	clr.w 2(A1)              // cyl high & low
	clr.w 4(A1)              // sec num & count
	clr.b 6(A1)              // features
	move.l #512,D0           // bytes
	bsr ide_cmd
	unlk A6
	bne.s .xi4
	move.l _dskbufp,A0
	lea 54(A0),A0
	lea 24(A0),A1
	moveq #23,D1             // jump end spaces
.xi5:
		cmp.b #0x20,-(A1)
		bne.s .xi6
	subq.l #1,D1
	bpl.s .xi5
.xi6:
	addq.l #1,A1
	clr.b (A1)
	moveq #23,D1             // model
.xi7:
		move.b (A0)+,D0
		beq.s .xi8
		move.b D0,(A2)+
		subq.l #1,D3
		ble.s .xi8
	subq.l #1,D1
	bpl.s .xi7
.xi8:
	clr.b (A2)
.xi4:
	moveq #0,D0
	rts

XHReserve:
XHLock:
XHStop:
XHEject:

	moveq #0,D0
	rts
	
XHDrvMap:

	move.l _drvbits,D0
	moveq #0,D1
	move.l pun_ptr,A0
.xdm1:
		tst.b pinfo_pun(A0,D1.L)
		bpl.s .xdm2
		bclr D1,D0  // remove drive not in pun table
.xdm2:
		addq.l #1,D1
	cmp.l #MAX_LOGICAL_DRIVE,D1
	bcs.s .xdm1
	rts

XHInqDev:

#ifdef COLDFIRE
#ifdef DEBUG
	lea debug134(PC),A0
	bsr debug_display_string
#endif
#endif
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 10(A6),D0         // bios_device
	cmp.l #2,D0              // C
	bcs.s .xd2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .xd2
	moveq #0,D1
	move.b pinfo_pun(A0,D0.l),D1
	bpl.s .xd1
.xd2:	
	moveq #-46,D0            // invalid drive number
	rts
.xd1:	
	tst.l 12(A6)
	beq.s .xd4
	move.l 12(A6),A1         // major
	move.w D1,(A1)
.xd4:
	tst.l 16(A6)
	beq.s .xd5
	move.l 16(A6),A1         // minor
	clr.w (A1)
.xd5:
	tst.l 20(A6)
	beq.s .xd6
	move.l pinfo_pstart(A0,D0.l*4),D1
	move.l 20(A6),A1         // start_sector
	move.l D1,(A1)
.xd6:
	lea pinfo_bpb(A0),A0
	mulu #18,D0              // * 18
	add.l D0,A0
	tst.l 24(A6)
	beq.s .xd7
	move.l 24(A6),A1         // bpb
	move.l (A0)+,(A1)+
	move.l (A0)+,(A1)+
	move.l (A0)+,(A1)+
	move.l (A0)+,(A1)+
	move.w (A0)+,(A1)+
.xd7:
	moveq #0,D0
	rts

XHInqDriver:

#ifdef COLDFIRE
#ifdef DEBUG
	lea debug135(PC),A0
	bsr debug_display_string
#endif
#endif
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 10(A6),D0         // bios_device
	cmp.l #2,D0              // C
	bcs.s .xdr2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .xdr2
	moveq #0,D1
	move.b pinfo_pun(A0,D0.l),D1
	bpl.s .xd1
.xdr2:	
	moveq #-46,D0            // invalid drive number
	rts
.xdr1:
	move.l 12(A6),D0         // name, 17 characters
	beq.s .xdr3
	move.l D0,A1
	lea message0b(PC),A0
	moveq #17,D1
.xdr6:
		move.b (A0)+,D0
		beq.s .xdr7
		move.b D0,(A1)+
	subq.l #1,D1
	bpl.s .xdr6
.xdr7:
	clr.b (A1)
.xdr3:
	move.l 16(A6),D0         // version, 7 characters
	beq.s .xdr4
	move.l D0,A1
	move.b #0x34,(A1)+       // ??? TOS 4.04
	move.b #0x2E,(A1)+
	move.b #0x30,(A1)+
	move.b #0x34,(A1)+
	clr.b (A1)
.xdr4:
	move.l 20(A6),D0         // company, 17 characters
	beq.s .xdr5
	move.l D0,A1
	clr.b (A1)
.xdr5:
	move.l 24(A6),A1         // ahdi_version
	move.w pinfo_vernum(A0),(A1)
	move.l 28(A6),A1         // maxIPL
	moveq #5,D0
	move.w D0,(A1)	
	moveq #0,D0
	rts

XHNewCookie:

	moveq #-32,D0            //  invalid function number 
	rts

XHReadWrite:                          // read / write physical sectors

#ifdef COLDFIRE
#ifdef DEBUG
	lea debug132(PC),A0
	bsr debug_display_string
	move.w 10(A6),D0         // major
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w 12(A6),D0         // minor
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w 14(A6),D0         // rwflag
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l 16(A6),D0         // logical sector
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w 20(A6),D0         // num sectors
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l 22(A6),D0         // buffer
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char	
#endif
#endif
	tst.w 12(A6)             // minor
	bne.s .xr4
	moveq #0,D4
	move.w 10(A6),D4         // major
	and.l #PUN_IDE,D4
	bne.s .xr1
.xr4:
	moveq #-15,D0            // unknown device
	rts	
.xr1:
	move.w 10(A6),D4         // major
	moveq #0,D0              // need to swap bytes ?
	moveq #0,D1
	move.l pun_ptr,A0
.xr9:
		move.b pinfo_pun(A0,D1.L),D0
		bmi.s .xr10 // invalid
		cmp.l D4,D0 // major
		beq.s .xr12
.xr10:
		addq.l #1,D1
	cmp.l #MAX_LOGICAL_DRIVE,D1
	bcs.s .xr9
	bra.s .xr11
.xr2:
	moveq #-1,D0             // error
	rts
.xr12:
	swap D4
	lea pinfo_flags(A0),A0
	tst.w (A0,D1.l*2)
	smi.b D4                 // flag swap
	ext.w D4	
	swap D4                  // swap/drive
.xr11:
	move.l 22(A6),A0         // buffer
	moveq #0,D3
	move.w 20(A6),D3         // count
	beq.s .xr2               // no sectors
             move.l 16(A6),D2         // start sector
#ifndef FIX_IDE
	btst #0,15(A6)           // rwflag
	beq.s .xr7               // read
.xr5:
		move.l D3,D1     // count
		cmp.l #0x100,D1
		bcs.s .xr6
		move.l #0xFF,D1  // count
.xr6:
		move.l D4,D0
		bsr write_sectors
		bmi.s .xr3
		move.l D1,D0
		add.l D0,D0
		asl.l #8,D0 // * 512
		add.l D0,A0 // buffer
		add.l D1,D2 // start sector
	sub.l D1,D3
	bgt.s .xr5
	moveq #0,D0              // OK
	rts
.xr7:
		move.l D3,D1     // count
		cmp.l #0x100,D1
		bcs.s .xr8
		move.l #0xFF,D1  // count
.xr8:
		move.l D4,D0
		bsr read_sectors
		bmi.s .xr3
		move.l D1,D0
		add.l D0,D0
		asl.l #8,D0 // * 512
		add.l D0,A0 // buffer
		add.l D1,D2 // start sector
	sub.l D1,D3
	bgt.s .xr7
	moveq #0,D0              // OK
.xr3:
	rts
#else /* FIX_IDE */
.xr13:
	moveq #1,D5
	move.l _dskbufp,A2
	move.l #0x5F465242,D0    // _FRB
	jsr get_cookie
	beq.s .xr19
	move.l D0,A2             // buffer
	move.l #128,D5           // max 65KB - 128
.xr19:
	btst #0,15(A6)           // rwflag
	beq.s .xr14              // read
.xr17:
		move.l D3,D1 // count
		cmp.l D5,D1
		bcs.s .xr22
		move.l D5,D1 // count
.xr22:
		move.l A2,A1 // temp buffer
		move.l D1,D0
		asl.l #5,D0 // * 32
.xr18:
			move.l (A0)+,(A1)+ 
			move.l (A0)+,(A1)+ 		
			move.l (A0)+,(A1)+ 
			move.l (A0)+,(A1)+ 
		subq.l #1,D0
		bgt.s .xr18
		move.l A0,-(SP) // source buffer
		move.l D4,D0
		move.l A2,A0
		bsr write_sectors
		move.l (SP)+,A0 // source buffer
		bmi.s .xr15
		add.l D1,D2 // start sector
	sub.l D1,D3
	bgt.s .xr17
	moveq #0,D0              // OK
.xr15:
	rts
.xr14:
		move.l A0,A3
		move.l D2,A4
		move.l D3,A5
		moveq #4,D7              // retry counter
.xr28:
		moveq #1,D6              // verify
.xr27:
			move.l A0,-(SP) // target buffer
			move.l D3,D1 // count
			cmp.l D5,D1
			bcs.s .xr23
			move.l D5,D1 // count
.xr23:
			move.l D4,D0
			move.l A2,A0 // temp buffer
			bsr read_sectors // A0: buffer, D0: drive, D0.H: flag swap bytes, D1: count, D2.L: start sector
			move.l (SP)+,A0
			bmi.s .xr15
			move.l A2,A1 // temp buffer
			move.l D1,D0
			asl.l #5,D0 // * 32
			tst.l D6
			bne.s .xr16 // 1st read
			move.l D1,-(SP)
.xr26:
				move.l (A1)+,D1
				cmp.l (A0)+,D1
				bne.s .xr25
				move.l (A1)+,D1
				cmp.l (A0)+,D1
				bne.s .xr25
				move.l (A1)+,D1
				cmp.l (A0)+,D1
				bne.s .xr25
				move.l (A1)+,D1
				cmp.l (A0)+,D1
				bne.s .xr25
			subq.l #1,D0
			bgt.s .xr26
			move.l (SP)+,D1
			bra.s .xr24
.xr25:
			move.l (SP)+,D1
			move.l A3,A0 // read buffer
			move.l A4,D2 // start sector
			move.l A5,D3 // count
			subq.l #1,D7 // retry counter
			bpl.s .xr28		
			moveq #-11,D0 // read error
			rts
.xr16:
				move.l (A1)+,(A0)+ 
				move.l (A1)+,(A0)+ 		
				move.l (A1)+,(A0)+ 
				move.l (A1)+,(A0)+ 
			subq.l #1,D0
			bgt.s .xr16
			move.l A3,A0 // read buffer
			move.l A4,D2 // start sector
			move.l A5,D3 // count
		subq.l #1,D6
		bpl.s .xr27
.xr24:
		add.l D1,D2 // start sector
	sub.l D1,D3
	bgt.s .xr14
	moveq #0,D0              // OK
 	rts	
#endif /* FIX_IDE */

XHInqDev2:

#ifdef COLDFIRE
#ifdef DEBUG
	lea debug136(PC),A0
	bsr debug_display_string
#endif
#endif
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 10(A6),D0         // bios_device
	cmp.l #2,D0              // C
	bcs.s .xdd2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .xdd2
	moveq #0,D1
	move.b pinfo_pun(A0,D0.l),D1
	bpl.s .xdd1
.xdd2:	
	moveq #-46,D0            // invalid drive number
	rts
.xdd1:	
	tst.l 12(A6)
	beq.s .xdd5
	move.l 12(A6),A1         // major
	move.w D1,(A1)
.xdd5:
	tst.l 16(A6)
	beq.s .xdd6
	move.l 16(A6),A1         // minor
	clr.w (A1)
.xdd6:
	tst.l 20(A6)
	beq.s .xdd7
	move.l pinfo_pstart(A0,D0.l*4),D1
	move.l 20(A6),A1         // start_sector
	move.l D1,(A1)
.xdd7:
	tst.l 24(A6)
	beq.s .xdd8
	lea pinfo_bpb(A0),A2
	move.l D0,D1
	mulu #18,D1              // * 18
	add.l D1,A2
	move.l 24(A6),A1         // bpb
	move.l (A2)+,(A1)+
	move.l (A2)+,(A1)+
	move.l (A2)+,(A1)+
	move.l (A2)+,(A1)+
	move.w (A2)+,(A1)+
.xdd8:
	tst.l 28(A6)
	beq.s .xdd9
	move.l 28(A6),A1         // blocks
	lea pinfo_psize(A0),A2
	move.l (A2,D0.l*4),(A1)
.xdd9:
	tst.l 32(A6)
	beq.s .xdd10
	move.l 32(A6),A1         // partid
	move.b pinfo_ptype+1(A0,D0.l*4),(A1)+
	move.b pinfo_ptype+2(A0,D0.l*4),D1
	bne.s .xdd3              // Atari partition
	moveq #0x44,D1           // D for MSDOS
.xdd3:
	move.b D1,(A1)+
	move.b pinfo_ptype+3(A0,D0.l*4),(A1)
.xdd10:
	moveq #0,D0
	rts
 
XHDriverSpecial:
XHGetCapacity:
XHMediumChanged:
XHMiNTInfo:

	moveq #-32,D0            // invalid function number 
	rts

XHDOSLimits:

#ifdef COLDFIRE
#ifdef DEBUG
	lea debug137(PC),A0
	bsr debug_display_string
#endif
#endif
	moveq #0,D0
	move.w 10(A6),D0         // which
	cmp.l #XH_DL_SECSIZ,D0   // maximal sector size (BIOS level)
	bne.s .xl1
	move.l #MAX_SECTOR_SIZE,D0
	rts	
.xl1:
	cmp.l #XH_DL_MINFAT,D0   // minimal number of FATs
	bne.s .xl2
	moveq #1,D0
	rts
.xl2:
	cmp.l #XH_DL_MAXFAT,D0   // maximal number of FATs
	bne.s .xl3
	moveq #2,D0
	rts
.xl3:
	cmp.l #XH_DL_MINSPC,D0   // sectors per cluster minimal
	bne.s .xl4
	moveq #2,D0
	rts
.xl4:
	cmp.l #XH_DL_MAXSPC,D0   // sectors per cluster maximal
	bne.s .xl5
#ifdef COLDFIRE
	moveq #64,D0             // for this Coldfire version of BDOS, else 2
#else
	moveq #2,D0
#endif
	rts
.xl5:
	cmp.l #XH_DL_CLUSTS,D0   // maximal number of clusters of a 16 bit FAT
	bne.s .xl6
	move.l #0x8000,D0
	rts	
.xl6:
	cmp.l #XH_DL_MAXSEC,D0   // maximal number of sectors
	bne.s .xl7
#ifdef COLDFIRE
	move.l #0x200000,D0      // for this Coldfire version of BDOS, else 0x10000
#else
	move.l #0x10000,D0
#endif
	rts
.xl7:
	cmp.l #XH_DL_DRIVES,D0   // maximal number of BIOS drives supported by the DOS
	bne.s .xl8
	moveq #MAX_LOGICAL_DRIVE,D0
	rts
.xl8:
	moveq #-32,D0            // invalid function number 
	rts

	// IDE emulation
	.chip 5200
	
#if 0        // unfinished, to fix with MMU update_tlb access fault !!!
access_error_ide:                     // called out of cf68klib

	move.w #0x2700,SR        // mask interrupts
	move.l SP,save_sp
	move.l D0,save_registers
	move.l D1,save_registers+4
	move.l A0,save_registers+32
	move.l save_sp,A0
	move.w (A0),D0           // format
	move.w D0,D1
	lsr.l #8,D0
	and.l #0xC,D0
	and.l #3,D1
	or.l D0,D1               // FS
	cmp.l #0xA,D1            // TLB miss on data write
	beq.s .error_on_data
	cmp.l #0xC,D1            // TLB miss on data read
	bne .not_ide_access
.error_on_data:
	move.l __MMU_BASE+0x10,D0 // MMUAR
	move.l D0,save_mmuar
	cmp.l #FALCON_ATA_DATA,D0
	bcs .not_ide_access
	cmp.l #FALCON_ATA_DATA+0x3F,D0
	bhi .not_ide_access
	lea access_fault_stack,SP
	move.w 2(A0),D0          // SR
	move.w D0,save_sr
	lea save_registers,A0
	movem.l D2-D7,8(A0)
	movem.l A1-A6,36(A0)
	move.l save_sp,A0
	move.l 4(A0),A0          // PC
	moveq #0,D0
	move.w (A0)+,D0          // opcode
	move.l D0,D1
	and.l #0xF000,D0
	cmp.l #0x1000,D0         // move.b
	bne .not_move_b
	move.l D1,D0             // opcode
	and.l #0xFFF8,D0
	cmp.l #0x13C0,D0         // move.b Dx,FALCON_ATA
	beq.s .move_b_dx_ata
	move.l D1,D0             // opcode
	and.l #0xF1F8,D0
	cmp.l #0x1080,D0         // move.b Dx,(Ax)
	beq.s .write_register_b
	cmp.l #0x1100,D0         // move.b Dx,-(Ax)
	beq.s .write_register_b
	cmp.l #0x10C0,D0         // move.b Dx,(Ax)+
	bne.s .not_move_b_dx_ax
	move.l D1,D0             // opcode
	swap D0
	lsr.l #1,D0
	and.l #7,D0              // address register index
	move.l A0,-(SP)
	lea save_registers,A0
	lea 32(A0,D0.w*4),A0
	addq.l #1,(A0)           // (Ax)+
	move.l (SP)+,A0          // PC
	bra.s .move_b_dx_ata	
.not_move_b_dx_ax:
	cmp.l #0x1140,D0         // move.b Dx,d16(Ax)
	beq.s .move_b_dx_dax
	cmp.l #0x1180,D0         // move.b Dx,d8(Ax,Xi)
	bne .not_move_b_dx_dax
.move_b_dx_dax:
	addq.l #2,A0             // fix PC
	bra.s .write_register_b
.move_b_dx_ata:
	addq.l #4,A0             // fix PC
.write_register_b:
	move.l A0,save_pc

#ifdef DEBUG
	move.l save_sp,A0
	move.l 4(A0),A0          // PC
	move.w (A0),D0           // opcode
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	move.l save_pc,D0        // PC updated
	bsr debug_hex_long

	moveq #0x20,D0
	bsr debug_display_char	
	move.l save_sp,A0
	move.l 4(A0),A0          // PC
	move.w (A0),D0           // opcode
	bsr debug_hex_word

	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif


	lea save_registers,A0
	moveq #7,D0
	and.l D1,D0              // opcode => register index
	move.l (A0,D0.w*4),D1    // value


#ifdef DEBUG
	move.l save_sp,A0
	move.l 4(A0),A0          // PC
	move.w (A0),D0           // opcode
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	move.l save_pc,D0        // PC updated
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif


	move.l save_mmuar,D0
	lsr.l #2,D0              // / 4
	not.l D0
	and.l #0xF,D0
	bclr #3,D0
	beq .end_opcode
	lea save_ide_registers,A0
	move.b D1,(A0,D0.w)
	tst.l D0
	bne .end_opcode          // <> cmd
	bra .send_ide_cmd
.not_move_b_dx_dax:
	move.l D1,D0             // opcode
	and.l #0xF1FF,D0
	cmp.l #0x1039,D0         // move.b FALCON_ATA,Dx
	beq.s .move_b_ata_dx
	move.l D1,D0             // opcode
	and.l #0xF1F8,D0
	cmp.l #0x1010,D0         // move.b (Ax),Dx
	beq.s .read_register_b
	cmp.l #0x1020,D0         // move.b -(Ax),Dx
	beq.s .read_register_b
	cmp.l #0x1018,D0         // move.b (Ax)+,Dx
	bne.s .not_move_b_ax_dx
	moveq #7,D0
	and.l D1,D0              // opcode => address register index
	move.l A0,-(SP)
	lea save_registers,A0
	lea 32(A0,D0.w*4),A0
	addq.l #1,(A0)           // (Ax)+
	move.l (SP)+,A0          // PC
	bra.s .move_b_ata_dx
.not_move_b_ax_dx:
	cmp.l #0x1028,D0         // move.b d16(Ax),Dx
	beq.s .move_b_dax_dx
	cmp.l #0x1030,D0         // move.b d8(Ax,Xi),Dx
	bne.s .not_move_b_dax_dx
.move_b_dax_dx:
	addq.l #2,A0             // fix PC
	bra.s .read_register_b
.move_b_ata_dx:
	addq.l #4,A0             // fix PC
.read_register_b:
	move.l A0,save_pc
	lsr.l #8,D1
	lsr.l #1,D1
	and.l #7,D1              // register index
	bra.s .read_register_dx
.not_move_b_dax_dx:
.not_move_b:
	bra .unknow_opcode
.read_register_dx:
	move.l save_mmuar,D0
	lea ATA_ERROR_REGISTER,A0
	cmp.l #FALCON_ATA_ERROR_REGISTER,D0
	beq.s .update_register
	lea ATA_SECTOR_COUNT,A0
	cmp.l #FALCON_ATA_SECTOR_COUNT,D0
	beq.s .update_register
	lea ATA_SECTOR_NUM,A0
	cmp.l #FALCON_ATA_SECTOR_NUM,D0
	beq.s .update_register
	lea ATA_CYLINDER_LOW,A0
	cmp.l #FALCON_ATA_CYLINDER_LOW,D0
	beq.s .update_register
	lea ATA_CYLINDER_HIGH,A0
	cmp.l #FALCON_ATA_CYLINDER_HIGH,D0
	beq.s .update_register
	lea ATA_DEVICE_HEAD,A0
	cmp.l #FALCON_ATA_DEVICE_HEAD,D0
	beq.s .update_register
	lea ATA_CONTROL_DEVICE,A0
	cmp.l #FALCON_ATA_CONTROL_DEVICE,D0
	bne .end_opcode
.update_register:
	move.b (A0),D0
	lea save_registers,A0
	move.b D0,3(A0,D1.w*4)
	move.l save_sp,A0
	move.b (A0),D0           // format
	lsr.l #4,D0
	and.l #3,D0              // stack alignment
	sub.l D0,A0
	subq.l #8,A0             // original stack before access fault
	move.l A0,save_sp
	lea save_registers,A0
	movem.l 4(A0),D1-A6
	clr.l save_mmuar
	move.l save_sp,SP
	move.w save_sr,D0
	move.w D0,SR	
	move.l save_registers,D0
	move.l save_pc,-(SP)
	rts
.send_ide_cmd:
	move.w 2(A0),D0          // sector high / sector low
	move.w D0,ATA_CYLINDER_HIGH
	move.w 4(A0),D0          // sector num / sector count
	move.w D0,ATA_SECTOR_NUM
	move.b 6(A0),D0          // features (error when read)
	move.w D0,ATA_ERROR_REGISTER
	moveq #2,D0              // control device, disable interrupt
	move.b D0,ATA_CONTROL_DEVICE	
 	move.w (A0),D0           // command, C/D/H
 	move.w D0,ATA_STATUS_COMMAND
.end_opcode:
#ifdef DEBUG
	move.l save_sp,A0
	move.l 4(A0),A0          // PC
	move.w (A0),D0           // opcode
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	move.l save_pc,D0        // PC updated
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l save_sp,A0
	move.w (A0),D0
	bsr debug_hex_word       // format
	moveq #0x20,D0
	bsr debug_display_char
	move.w 2(A0),D0
	bsr debug_hex_word       // SR
	moveq #0x20,D0
	bsr debug_display_char
	move.l A0,D0
	bsr debug_hex_long	
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
	move.l save_sp,A0
	move.b (A0),D0           // format
	lsr.l #4,D0
	and.l #3,D0              // stack alignment
	sub.l D0,A0
	subq.l #8,A0             // original stack before access fault
	move.l A0,save_sp
	clr.l save_mmuar
	lea save_registers,A0
	move.l 4(A0),D1
	movem.l 32(A0),A0-A6
	move.l save_sp,SP
	move.w save_sr,D0
	move.w D0,SR	
	move.l save_registers,D0
	move.l save_pc,-(SP)
	rts
.unknow_opcode:
	move.l save_sp,SP
.not_ide_access:
	move.l save_registers+32,A0	
	move.l save_registers+4,D1
	move.l save_registers,D0
	move.l old_access_error,-(SP)
	rts
#endif /* #if 0 */

	// IDE driver
	.chip 68060

install_xbra:	// A0: handler, D0: vector 

#ifdef COLDFIRE
	lea -28(SP),SP
	movem.l D1-D3/A0-A3,(SP)
#else
	movem.l D1-D3/A0-A3,-(SP)
#endif
	moveq #0,D3
	move.w D0,D3             // vector
	move.l A0,A3             // handler
	move.w #3,-(SP)          // TT ram if possible
	move.l #18,-(SP)         // size
	move.w #0x44,-(SP)       // Mxalloc
	trap #1 
	addq.l #8,SP
	tst.l D0
	beq.s .error_xbra
             move.l D0,A0
             move.l #0x58425241,(A0)+ // XBRA
	move.l #0x5F445256,(A0)+ // _DRV
	clr.l (A0)+	
	move.w #0x4EF9,(A0)+     // JMP
	move.l A3,(A0)+          // handler
	lea -10(A0),A0
	cpusha BC
	move.l D3,A1
	move.l (A1),D0
	move.l D0,(A0)+          // old vector
	move.l A0,(A1)           // JMP, new vector
.error_xbra:
	tst.l D0
#ifdef COLDFIRE
	movem.l (SP),D1-D3/A0-A3
	lea 28(SP),SP
#else
	movem.l (SP)+,D1-D3/A0-A3
#endif
	rts

install_hddriver:

#ifdef COLDFIRE
	lea -32(SP),SP
	movem.l D1-D4/A0-A3,(SP)
#ifdef DEBUG
	lea debug128(PC),A0
	bsr debug_display_string	
	move.l pun_ptr,D0
	bsr debug_hex_long
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
#endif
#else
	movem.l D1-D4/A0-A3,-(SP)
#endif
	pea crlf(PC)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP	
	move.l pun_ptr,D0
	beq .no_drive
	move.l D0,A3
	lea pinfo_bpb(A3),A1
	move.l #((16*18)/4),D0
.clr_tab_bpb:
		clr.l (A1)+
	subq.l #1,D0
	bpl.s .clr_tab_bpb
	moveq #2,D4              // logical drive
.loop_partition:
		moveq #0,D0
		move.b pinfo_pun(A3,D4.l),D0
		bmi .next_partition
		swap D0
		lea pinfo_flags(A3),A0
		tst.w (A0,D4.l*2)
		smi.b D0                 // flag swap
		ext.w D0
		swap D0                  // swap/drive
		move.l pinfo_pstart(A3,D4.l*4),D2
		moveq #1,D1              // 1 sector
		move.l _dskbufp,A0       // read boot sector
		bsr read_sectors
		bmi .next_partition
		move.b pinfo_pun(A3,D4.l),D0
		move.l D4,D1             // logical drive
		move.l pinfo_ptype(A3,D4.l*4),D2 // part_type
		lea pinfo_psize(A3),A0
		move.l (A0,D4.l*4),D3    // partition size in sectors
		bsr display_drive
		move.l _dskbufp,A0       // boot sector
		lea pinfo_bpb(A3),A1
		move.l D4,D1             // logical drive
		mulu #18,D1              // * 18
		add.l D1,A1
		move.l D2,D1             // part_type
		and.l #0xFFFFFF,D1       // ID
		// GEMDOS
		cmp.l #0x47454D,D1       // GEM up to 16M
		beq.s .partition_ok
		cmp.l #0x42474D,D1       // BGM over 16M
		beq.s .partition_ok
		cmp.l #0x524157,D1       // RAW
		beq.s .partition_ok
		// DOS 1:FAT12, 0xB/0xC:FAT32
		cmp.l #0x1,D2            // FAT12 up to 15M
		beq.s .partition_ok
		cmp.l #0x4,D2            // FAT16 up to 32M
		beq.s .partition_ok
		cmp.l #0x6,D2            // FAT16 over 32M
		beq.s .partition_ok
		cmp.l #0xE,D2            // WIN95 FAT16
		bne .no_bpb
.partition_ok:
		move.l D2,-(SP)          // part_type
		moveq #0,D2
		move.b 0xC(A0),D2
		asl.l #8,D2
		move.b 0xB(A0),D2        // BPS
		move.w D2,(A1)           // sector size
		beq .no_bpb2
		cmp.l #MAX_SECTOR_SIZE,D2
		bhi .no_bpb2
		moveq #0,D1
		move.b 0xD(A0),D1        // SPC
		move.w D1,2(A1)          // cluster size in sectors
		move.w D1,D0
		mulu D2,D0
		move.w D0,4(A1)          // cluster size in bytes
		moveq #0,D0
		move.b 0x12(A0),D0
		asl.l #8,D0
		move.b 0x11(A0),D0       // NDIRS
		asl.l #5,D0              // * 32
		divu D2,D0               // / sector size
		move.w D0,6(A1)          // size directory in sectors
		moveq #0,D2
		move.b 0x17(A0),D2
		asl.l #8,D2
		move.b 0x16(A0),D2       // SPF
		move.w D2,8(A1)          // FAT size
		moveq #0,D0
		move.b 0xF(A0),D0
		asl.l #8,D0
		move.b 0xE(A0),D0        // RES
		move.l D0,D3
		add.l D2,D3              // + FAT size
		move.w D3,10(A1)         // 1st sector of FAT2 
		moveq #0,D3
		move.b 0x10(A0),D3       // NFATS
		mulu D2,D3               // * FAT size
		add.l D0,D3              // + RES
		moveq #0,D0
		move.w 6(A1),D0          // size directory in sectors
		add.l D3,D0
		move.w D0,12(A1)         // 1st data sector
		moveq #0,D2
		move.b 0x14(A0),D2
		asl.l #8,D2
		move.b 0x13(A0),D2       // NSECTS
		bne.s .nsects_ok
		lea pinfo_psize(A3),A2
		move.l (A2,D4.l*4),D2    // partition size in sectors
		sub.l D0,D2              // - 1st data sector
.nsects_ok:
		divu D1,D2
		move.w D2,14(A1)         // total clusters
		move.l (SP)+,D2          // part_type
		moveq #0,D0              // FAT 12
		cmp.l #0x1,D2            // FAT 12 up to 15M
		beq.s .fat12
		moveq #1,D0              // FAT 16
.fat12:
		moveq #0,D3
		move.b 0x10(A0),D3       // NFATS
		cmp.l #1,D3
		bne.s .two_fats
		bset #1,D0               // one FAT
.two_fats:
		move.w D0,16(A1)         // FAT 16
		bra.s .end_bpb
.no_bpb2:
		move.l (SP)+,D2
.no_bpb:
		clr.w (A1)
		clr.l 2(A1)
		clr.l 6(A1)
		clr.l 10(A1)
		clr.l 14(A1)
.end_bpb:
		move.l _drvbits,D0
		bset D4,D0               // logical drive
		move.l D0,_drvbits
#ifdef DEBUG
		lea debug125(PC),A0
		bsr debug_display_string
		moveq #8,D1
.loop_bpb:
			move.w (A1)+,D0
			bsr debug_hex_word
			moveq #0x20,D0
			bsr debug_display_char
		subq.l #1,D1
		bpl.s .loop_bpb
		moveq #13,D0
		bsr debug_display_char
		moveq #10,D0
		bsr debug_display_char
		lea debug129(PC),A0
		bsr debug_display_string
		move.l _drvbits,D0
		bsr debug_hex_long
		moveq #13,D0
		bsr debug_display_char
		moveq #10,D0
		bsr debug_display_char
#endif
.next_partition:
		addq.l #1,D4
	cmp.l #MAX_LOGICAL_DRIVE,D4
	bcs .loop_partition
	move.w SR,D0
	move.w D0,-(SP)
	or.l #0x700,D0           // mask interrupts
	move.w D0,SR
	lea det_hdv_bpb(PC),A0
	move.w #hdv_bpb,D0
	bsr install_xbra
	move.l D0,old_hdv_bpb_hd
	lea det_hdv_rw(PC),A0
	move.w #hdv_rw,D0
	bsr install_xbra	
	move.l D0,old_hdv_rw_hd
	lea det_hdv_mediach(PC),A0
	move.w #hdv_mediach,D0
	bsr install_xbra
	move.l D0,old_hdv_mediach_hd
	move.l cookie,D0
	beq.s .no_cookie_jar
	move.l D0,A0
.find_cookie_jar:
		tst.l (A0)
		beq.s .cookie_slot_free
		addq.l #8,A0
	bra.s .find_cookie_jar
.cookie_slot_free:
	move.l 4(A0),12(A0)      // copy size
	move.l #0x58484449,(A0)+ // XHDI
	lea xhdi(PC),A2
	move.l A2,(A0)+
	clr.l (A0)
.no_cookie_jar:
	move.w (SP)+,D0
	move.w D0,SR
	lea pinfo_flags(A3),A0
	moveq #0,D4              // logical drive
.search_partition_boot:
		move.w (A0)+,D0
		btst #0,D0
		bne.s .found_partition_boot
		addq.l #1,D4
	cmp.l #MAX_LOGICAL_DRIVE,D4
	bcs.s .search_partition_boot
	bra.s .no_drive
.found_partition_boot:
	move.w D4,_bootdev
	move.w D4,-(SP)          // logical boot drive
	move.w #0xE,-(SP)        // Dsetdrv
	trap #1
	addq.l #4,SP
.no_drive:
#ifdef COLDFIRE
	movem.l (SP),D1-D4/A0-A3
	lea 32(SP),SP
#else
	movem.l (SP)+,D1-D4/A0-A3
#endif
	rts
	
det_hdv_bpb:

	move.l A0,-(SP)
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 4+4(SP),D0        // drive
	cmp.l #2,D0              // C
	bcs.s .dhb2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .dhb2
	tst.b pinfo_pun(A0,D0.l)
	bpl.s .dhb1
.dhb2:
	move.l (SP)+,A0
	moveq #0,D0
	move.l old_hdv_bpb_hd,-(SP)
	rts
.dhb1:
	move.l D1,-(SP)
	move.l pinfo_ptype(A0,D0.l*4),D1
	// from ROOT sector
	cmp.l #0x47454D,D1       // GEM
	beq.s .dhb3
	cmp.l #0x42474D,D1       // BGM
	beq.s .dhb3
	// from MBR
	cmp.l #0x1,D1            // FAT12 up to 15M
	beq.s .dhb3
	cmp.l #0x4,D1            // FAT16 up to 32M
	beq.s .dhb3
	cmp.l #0x6,D1            // FAT16 over 32M
	beq.s .dhb3
	cmp.l #0xE,D1            // WIN95 FAT16
	beq.s .dhb3
.dhb4:
	move.l (SP)+,D1
	move.l (SP)+,A0
	moveq #0,D0              // not for TOS
	rts
.dhb3:
	lea pinfo_bpb(A0),A0
	mulu #18,D0              // * 18
	add.l A0,D0
	move.l D0,A0
#ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,-(SP)
	lea debug125(PC),A0
	bsr debug_display_string
	move.l D1,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	move.l (SP),A0
	moveq #8,D1
.loop_getbpb:
		move.w (A0)+,D0
		bsr debug_hex_word
		moveq #0x20,D0
		bsr debug_display_char
	subq.l #1,D1
	bpl.s .loop_getbpb
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,A0
	move.l (SP)+,D0
#endif
	tst.w (A0)               // sector size
	beq.s .dhb4
	move.l (SP)+,D1
	move.l (SP)+,A0
	rts
	
det_hdv_rw:

	lea -24(SP),SP
	movem.l D1-D4/A0-A1,(SP)
	btst #3,5+24(SP)         // rwflag
	bne.s .dhr10             // physical
	move.l pun_ptr,A1
 	moveq #0,D0
	move.w 14+24(SP),D0      // drive
	cmp.l #2,D0              // C
	bcs.s .dhr10
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .dhr10
	moveq #0,D4
	move.b pinfo_pun(A1,D0.l),D4
	bpl.s .dhr1
.dhr10:
	movem.l (SP),D1-D4/A0-A1
	lea 24(SP),SP
	moveq #0,D0
	move.l old_hdv_rw_hd,-(SP)
	rts
.dhr2:
	moveq #-1,D0             // error
	bra .dhr3
.dhr1:	
	moveq #0,D2
	move.w 12+24(SP),D2      // logical sector
	bpl.s .dhr9
	move.l 16+24(SP),D2      // logical sector	
.dhr9:	
	tst.l D2
	bmi.s .dhr2              // negative logical sector
	move.l 6+24(SP),D1       // buffer
	beq .dhr4                // no buffer
	move.l pinfo_pstart(A1,D0.l*4),D3
	swap D4
	lea pinfo_flags(A1),A0
	tst.w (A0,D0.l*2)
	smi.b D4                 // flag swap
	ext.w D4	
	swap D4                  // swap/drive
	lea pinfo_bpb(A1),A0
	mulu #18,D0              // * 18
	add.l D0,A0
	move.w 14(A0),D0         // total clusters
	mulu.w 2(A0),D0          // cluster size in sectors
	cmp.l D0,D2              // logical sector to hight
	bcc.s .dhr2
#ifdef DEBUG
	move.l A0,-(SP)
	lea debug127(PC),A0
	bsr debug_display_string	
	move.w 4+28(SP),D0       // rwflag
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l D1,D0             // buffer
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w 10+28(SP),D0      // num sectors
	bsr debug_hex_word
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.l D2,D0             // logical sector
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0x30,D0
	bsr debug_display_char
	moveq #0x78,D0
	bsr debug_display_char
	move.w 14+28(SP),D0      // drive
	bsr debug_hex_word
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,A0
#endif
	moveq #0,D0
	move.w (A0),D0           // sector size
	lsr.l #8,D0
	lsr.l #1,D0              // / 512
	move.l D1,A0             // buffer
	move.w 10+24(SP),D1      // num sectors
	beq .dhr4                // no sectors
	mulu D0,D1
	mulu.l D0,D2
	add.l D3,D2              // start sector
	move.l D1,D3             // count
#ifndef HDV_RW_USE_XHDI
	btst #0,5+24(SP)         // rwflag
	beq.s .dhr7              // read
	tst.l D2                 // logical sector
	beq.s .dhr2              // root sector
.dhr5:
		move.l D3,D1     // count
		cmp.l #0x100,D1
		bcs.s .dhr6
		move.l #0xFF,D1  // count
.dhr6:
		move.l D4,D0
		bsr write_sectors
		bmi.s .dhr3
		move.l D1,D0
		add.l D0,D0
		asl.l #8,D0 // * 512
		add.l D0,A0 // buffer
		add.l D1,D2 // start sector
	sub.l D1,D3
	bgt.s .dhr5
	bra.s .dhr4
.dhr7:
		move.l D3,D1     // count
		cmp.l #0x100,D1
		bcs.s .dhr8
		move.l #0xFF,D1  // count
.dhr8:
		move.l D4,D0
		bsr read_sectors
		bmi.s .dhr3
		move.l D1,D0
		add.l D0,D0
		asl.l #8,D0 // * 512
		add.l D0,A0 // buffer
		add.l D1,D2 // start sector
	sub.l D1,D3
	bgt.s .dhr7
#else /* HDV_RW_USE_XHDI */
	move.w 4+24(SP),D1       // rwflag
 	moveq #0,D0
	move.w 14+24(SP),D0      // logical drive
	move.l A6,-(SP)
	lea -26(SP),A6
	lea -46(SP),SP
	movem.l D5-D7/A2-A5,(SP)
	move.b pinfo_pun(A1,D0.L),D0 // physical drive
	move.w D0,10(A6)         // major
	clr.w 12(A6)             // minor
	move.w D1,14(A6)         // rwflag
	move.l D2,16(A6)         // logical sector
	move.w D3,20(A6)         // num sectors
	move.l A0,22(A6)         // buffer
	bsr XHReadWrite
	movem.l (SP),D5-D7/A2-A5
	lea 46(SP),SP
	move.l (SP)+,A6
	tst.l D0
	bmi.s .dhr3
#endif /* HDV_RW_USE_XHDI */
.dhr4:
	moveq #0,D0              // OK
.dhr3:
	movem.l (SP),D1-D4/A0-A1
	lea 24(SP),SP
 	rts
 	
det_hdv_mediach:

	move.l A0,-(SP)
	move.l pun_ptr,A0
 	moveq #0,D0
	move.w 4+4(SP),D0        // drive
	cmp.l #2,D0              // C
	bcs.s .dhm2
	cmp.l #MAX_LOGICAL_DRIVE,D0
	bcc.s .dhm2
	tst.b pinfo_pun(A0,D0.l)
	bpl.s .dhm1
.dhm2:
	move.l (SP)+,A0
	moveq #0,D0
	move.l old_hdv_mediach_hd,-(SP)
	rts
.dhm1:
	lea pinfo_flags(A0),A0
	add.l D0,A0
	add.l D0,A0
	bclr #7,1(A0)
	sne.b D0
#ifdef COLDFIRE                        // for BDOS
	and.l #1,D0
#else
	and.l #2,D0
#endif
	move.l (SP)+,A0
	rts
	
#endif /* COLDFIRE */

swap_buffer:		// A0: buffer, D0: count

#ifdef COLDFIRE
	lea -16(SP),SP
	movem.l D0-D2/A0,(SP)
	and.l #0xFFFF,D0
	bra.s .end_loop_swap
.loop_swap:
	move.l #255,D2
.loop_swap_2:
			move.b 1(A0),D1
			asl.l #8,D1
			move.b (A0),D1
			move.w D1,(A0)+
		subq.l #1,D2
		bpl.s .loop_swap_2
.end_loop_swap:
	subq.l #1,D0
	bpl.s .loop_swap
	movem.l (SP),D0-D2/A0
	lea 16(SP),SP
#else
	movem.l D0-D2/A0,-(SP)
	bra.s .end_loop_swap
.loop_swap:
	move.w #255,D2
.loop_swap_2:
			move.w (A0),D1
			ror.w #8,D1
			move.w D1,(A0)+	
		dbf D2,.loop_swap_2
.end_loop_swap:
	dbf D0,.loop_swap
	movem.l (SP)+,D0-D2/A0
#endif
	rts

read_sectors: 	// A0: buffer, D0: drive, D0.H: flag swap bytes, D1: count, D2.L: start sector
		// return error code inside D0
#ifdef COLDFIRE
	lea -36(SP),SP
	movem.l D1-D4/A0-A4,(SP)
#else
	movem.l D1-D4/A0-A4,-(SP)
#endif
	move.l A0,A4             // buffer
	move.l D0,D4             // physical drive & flag swap bytes
	move.w D1,D3             // count
	btst #4,D4
	beq .use_DMAread         // SCSI
	link A6,#-8
	move.l A4,A0             // IDE buffer
	lea -8(A6),A1            // cmd buffer
	moveq #3,D0
	and.l D4,D0              // physical drive
	asl.l #4,D0
	or.l #0x40,D0            // LBA mode
	move.l D0,-(SP)
	move.l D2,D0             // LBA
	swap D0
	lsr.l #8,D0
	and.l #0xF,D0            // LBA bits 24-27
	or.l (SP)+,D0
	move.b D0,1(A1)          // drive (C/D/H)
	move.l D2,D0             // LBA
	move.b D0,4(A1)          // sec num, LBA low
	lsr.l #8,D0
	move.w D0,2(A1)          // cyl high & low, LBA high & mid
	move.b D1,5(A1)          // sec count 0 <=> 256
	cmp.l #0x1000000,D2
	bcc.s .read_lba48	
	move.b #0x20,(A1)        // read sector(s)
	clr.b 6(A1)              // features
	bra.s .read_lba
.read_lba48:
	move.b #0x24,(A1)        // read sector(s) ext
	movel D2,D0
	swap D0
	lsr.l #8,D0
	move.b D0,6(A1)          // features, trick for pass LBA B39-B23 as previous data to ide_cmd
.read_lba:
	moveq #0,D0
	move.w D1,D0             // count
	add.l D0,D0
	asl.l #8,D0              // * 512 = bytes
	bsr ide_cmd
	unlk A6
	ble.s .end_read_sectors  // OK or time-out
	moveq #-11,D0            // read error
	bra.s .end_read_sectors		
.use_DMAread:
	move.w D4,-(SP)          // physical drive
	move.l A4,-(SP)          // buffer
	move.w D1,-(SP)          // count
	move.l D2,-(SP)          // sector
	move.w #0x2A,-(SP)       // DMAread
	trap #14
	lea 14(SP),SP
	ext.l D0
.end_read_sectors:
	tst.l D0
	bmi.s .end_read_sectors_swap
	tst.l D4                 // flag swap bytes
	bpl.s .end_read_sectors_swap
	move.l D0,-(SP)
	move.l A4,A0             // buffer
	move.w D3,D0             // count
	bsr swap_buffer
	move.l (SP)+,D0
.end_read_sectors_swap:
#if 0 // #ifdef DEBUG
	tst.l D0
	bmi.s .error_sectors_read
	move.l D0,-(SP)
	ext.l D3
	bra.s .end_dump_sectors_read
.loop_dump_sectors_read:
		move.l A4,A1
		moveq #31,D1
		bsr dump
//		bsr wait_key
		lea 512(A4),A4
.end_dump_sectors_read:
	subq.l #1,D3
	bpl.s .loop_dump_sectors_read
.error_sectors_read:
	move.l (SP)+,D0
#endif	
	tst.l D0
#ifdef COLDFIRE
	movem.l (SP),D1-D4/A0-A4
	lea 36(SP),SP
#else
	movem.l (SP)+,D1-D4/A0-A4
#endif
	rts
	
write_sectors: 	// A0: buffer, D0: drive, D0.H: flag swap bytes, D1: count, D2.L: start sector
		// return error code inside D0
#ifdef COLDFIRE
	lea -36(SP),SP
	movem.l D1-D4/A0-A4,(SP)
#else
	movem.l D1-D4/A0-A4,-(SP)
#endif
	move.l A0,A4             // buffer
	move.w D1,D3             // count
	move.l D0,D4             // physical drive & flag swap bytes
	bpl.s .begin_write_sectors_swap
	move.l A4,A0             // buffer
	move.w D3,D0             // count
	bsr swap_buffer
.begin_write_sectors_swap:
	btst #4,D4
	beq .use_DMAwrite        // SCSI
	link A6,#-8
	move.l A4,A0             // IDE buffer
	lea -8(A6),A1            // cmd buffer
	moveq #3,D0
	and.l D4,D0              // physical drive
	asl.l #4,D0
	or.l #0x40,D0            // LBA mode
	move.l D0,-(SP)
	move.l D2,D0             // LBA
	swap D0
	lsr.l #8,D0
	and.l #0xF,D0            // LBA bits 24-27
	or.l (SP)+,D0
	move.b D0,1(A1)          // drive (C/D/H)
	move.l D2,D0             // LBA
	move.b D0,4(A1)          // sec num, LBA low
	lsr.l #8,D0
	move.w D0,2(A1)          // cyl high & low, LBA high & mid
	move.b D1,5(A1)          // sec count 0 <=> 256
	cmp.l #0x1000000,D2
	bcc.s .write_lba48
	move.b #0x30,(A1)        // write sector(s)
	clr.b 6(A1)              // features
             bra.s .write_lba
.write_lba48:
	move.b #0x34,(A1)        // write sector(s) ext
	movel D2,D0
	swap D0
	lsr.l #8,D0
	move.b D0,6(A1)          // features, trick for pass LBA B39-B23 as previous data to ide_cmd	
.write_lba:
	moveq #0,D0
	move.w D1,D0             // count
	add.l D0,D0
	asl.l #8,D0              // * 512 = bytes
	bsr ide_cmd
	unlk A6
	ble.s .end_write_sectors // OK or time-out
	moveq #-10,D0            // write error
	bra.s .end_write_sectors		
.use_DMAwrite:
	move.w D4,-(SP)          // physical drive
	move.l A4,-(SP)          // buffer
	move.w D1,-(SP)          // count
	move.l D2,-(SP)          // sector
	move.w #0x2B,-(SP)       // DMAwrite
	trap #14
	lea 14(SP),SP
	ext.l D0
.end_write_sectors:
	tst.l D4                 // flag swap bytes
	bpl.s .end_write_sectors_swap
	move.l D0,-(SP)
	move.l A4,A0             // buffer
	move.w D3,D0             // count
	bsr swap_buffer
	move.l (SP)+,D0
.end_write_sectors_swap:
#if 0 // #ifdef DEBUG
	tst.l D0
	bmi.s .error_sectors_write
	move.l D0,-(SP)
	ext.l D3
	bra.s .end_dump_sectors_write
.loop_dump_sectors_write:
		move.l A4,A1
		moveq #31,D1
		bsr dump
//		bsr wait_key
		lea 512(A4),A4
.end_dump_sectors_write:
	subq.l #1,D3
	bpl.s .loop_dump_sectors_write
.error_sectors_write:
	move.l (SP)+,D0
#endif	
	tst.l D0
#ifdef COLDFIRE
	movem.l (SP),D1-D4/A0-A4
	lea 36(SP),SP
#else
	movem.l (SP)+,D1-D4/A0-A4
#endif
	rts
	
#ifdef COLDFIRE

error_unknow_device:

	moveq #-15,D0
	rts

error_ok:

	moveq #0,D0
	rts

#endif /* COLDFIRE */
	
#ifdef USE_ATARI_IO
	
scsi_cmd:	// D0: drive, D1.L: DMA bytes, D2: bytes cmd, A0: DMA buffer, A1: buffer bytes cmd
	// return error code inside D0, and time speed test inside D1.L

	bset #7,flock
	beq.s .sr5
	moveq #0,D1
	moveq #-1,D0             // error
	rts
.sr5:
	movem.l D2-D3/A0,-(SP)
	moveq #0,D3
	bsr send_cmd_scsi
	bmi .sr4                // time-out
	move.w #0x89,0xFFFF8606 // Init-Command Register NCR5380
	move.w #0,0xFFFF8604
	move.w #0x8B,0xFFFF8606 // Target-Command Register
	move.w #1,0xFFFF8604
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w 0xFFFF8604,D0
	move.w #0x8A,0xFFFF8606 // Mode Register
	move.w #2,0xFFFF8604    // enable DMA
	move.l A0,-(SP)
	move.b 3(SP),0xFFFF860D
	move.b 2(SP),0xFFFF860B
	move.b 1(SP),0xFFFF8609
	addq.l #4,SP
	move.w #0x190,0xFFFF8606
	bsr mfp_delay
	move.w #0x90,0xFFFF8606 // DMA reading
	bsr mfp_delay
	move.l D1,D0            // num bytes DMA
	and.w #0x1FF,D1
	lsr.l #8,D0
	lsr.l #1,D0             // / 512
	tst.w D1
	beq.s .sr3
	addq #1,D0
.sr3:
	move.w D0,0xFFFF8604    // sectors
.sr1:
	btst #3,0xFFFF860F
	bne.s .sr1
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w #0,0xFFFF8604
	move.w #0,0xFFFF8606    // read transfer
#ifdef COLDFIRE
	move.l MCF_SLT_SCNT1,D0 // uS * SYSTEM_CLOCK
#else
	bsr get_timer_c
#endif
	move.l D0,D3            // speed test	
	bsr wait_end_cmd_scsi
	bmi.s .sr4              // time-out
	and #0xF,D1
	beq.s .sr2
	move.w #0x20,0xFFFF8606
.sr2:
#ifdef COLDFIRE
	move.l MCF_SLT_SCNT1,D0 // uS * SYSTEM_CLOCK
#else
	bsr get_timer_c
#endif
	sub.l D3,D0
	move.l D0,D3            // time speed test
	bsr get_status_scsi
	cpusha DC
	and.l #0xFF,D0          // error code
.sr4:
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w 0xFFFF8604,D1
	move.w #0x180,0xFFFF8606
	bsr mfp_delay
	move.w #0x80,0xFFFF8606 // Data register
	clr.w flock
	move.l D3,D1            // time speed test
	tst.l D0
	movem.l (SP)+,D2-D3/A0
	rts

get_status_scsi:

	move.l D1,-(SP)
	move.w #0x8B,0xFFFF8606 // Target-Command Register
	move.w #3,0xFFFF8604
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w 0xFFFF8604,D0
	move.w #0x8C,0xFFFF8606 // ID Select/SCSI Control Register
	move.l _hz_200,D1
.gs5:
		move.w 0xFFFF8604,D0 // DMA state
		btst #5,D0
		bne.s .gs2
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #TIME_OUT_CMD,D0
	blt.s .gs5
	bra.s .gs6
.gs2:
	move.w #0x88,0xFFFF8606           // Data register
	move.w 0xFFFF8604,D0
	and.l #0xFF,D0
	move.l D0,-(SP)
	bsr attention_scsi
	move.w #0x8C,0xFFFF8606           // ID Select/SCSI Control Register
	move.l _hz_200,D1
.gs3:
		move.w 0xFFFF8604,D0 // DMA state
		btst #5,D0
		bne.s .gs4
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #TIME_OUT_CMD,D0            // time-out 500 mS
	blt.s .gs3
	addq.l #4,SP
.gs6:
	moveq #-1,D0
	bra.s .gs1
.gs4:
	move.w #0x88,0xFFFF8606           // Data register
	move.w 0xFFFF8604,D0
	bsr attention_scsi
	move.l (SP)+,D0
.gs1:
	move.l (SP)+,D1
	tst.l D0
	rts
	
send_cmd_scsi: // D0: drive, D2: bytes cmd, A1: buffer bytes cmd
// return D0 < 0 => time-out

	movem.l D1-D3/A1,-(SP)
	move.w #0x8C,0xFFFF8606           // ID Select/SCSI Control Register
	move.l _hz_200,D1
.cs1:
		move.w 0xFFFF8604,D3 // DMA state
		btst #6,D3
		beq.s .cs2
		move.l _hz_200,D3
		sub.l D1,D3
		cmp.l #TIME_OUT_CMD,D3
	blt.s .cs1
	bra .cs7
.cs2:
	move.w #0x8B,0xFFFF8606 // Target-Command Register
	move.w #0,0xFFFF8604
	move.w #0x8C,0xFFFF8606 // ID Select/SCSI Control Register
	move.w #0,0xFFFF8604
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #0x0C,0xFFFF8604 
	moveq #0,D1
	and.w #7,D0 // SCSI drive
	bset D0,D1
	move.w #0x88,0xFFFF8606 // Data register
	move.w D1,0xFFFF8604
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #5,0xFFFF8604
	move.w #0x8A,0xFFFF8606 // Mode Register
	move.w 0xFFFF8604,D0
	and.b #0xFE,D0          // disable arbitration
	move.w D0,0xFFFF8604
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w 0xFFFF8604,D0
	and.w #0xF7,D0
	move.w D0,0xFFFF8604
	bsr mfp_delay
	move.w #0x8C,0xFFFF8606 // ID Select/SCSI Control Register
	move.l _hz_200,D1
.cs6:
		move.w 0xFFFF8604,D0 // DMA state
		btst #6,D0
		bne.s .cs3
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #TIME_OUT_CMD,D0
	blt.s .cs6
.cs7:
	move.w #0x89,0xFFFF8606      // Init-Command Register
	move.w #0,0xFFFF8604
	moveq #-1,D0                 // time-out
 	bra .cs5
.cs3:
	move.w #0x89,0xFFFF8606      // Init-Command Register
	move.w #0,0xFFFF8604
	move.w #0x8B,0xFFFF8606      // Target-Command Register
	move.w #2,0xFFFF8604
	move.w #0x89,0xFFFF8606      // Init-Command Register
	move.w #1,0xFFFF8604
	subq.w #1,D2                 // bytes cmd counter
	bmi.s .cs8
.cs4:                        
		move.l #TIME_OUT_CMD,D0
		bsr wait_hdc
		bmi.s .cs5      // time-out
		moveq #0,D0
		move.b (A1)+,D0 // byte cmd
		move.w #0x88,0xFFFF8606 // Data register
		move.w D0,0xFFFF8604
		bsr attention_scsi
	dbf D2,.cs4
.cs8:
	moveq #0,D0
.cs5:
	movem.l (SP)+,D1-D3/A1
	rts

attention_scsi:

	move.w D0,-(SP)
	move.w #0x89,0xFFFF8606      // Init-Command Register
	move.w 0xFFFF8604,D0
	or.b #0x11,D0
	move.w D0,0xFFFF8604
	and.b #0xEF,D0
	move.w D0,0xFFFF8604
	move.w (SP)+,D0
	rts

mfp_delay:

	tst.b 0xFFFFFA01
	tst.b 0xFFFFFA01
	tst.b 0xFFFFFA01
	tst.b 0xFFFFFA01
	rts
	
#endif /* USE_ATARI_IO */

delay_hz_200: // inside D0.L

	movem.l D1/D2,-(SP)
	move.l _hz_200,D1
.dh1:	move.l _hz_200,D2
		sub.l D1,D2
	cmp.l D0,D2
	blt.s .dh1
	movem.l (SP)+,D1/D2
	rts

#ifdef USE_ATARI_IO
	
wait_hdc: // time-out inside D0.L, return D0 < 0 => time-out

	movem.l D1/D2,-(SP)
	move.l D0,D2 // time-out
	move.w #0x8C,0xFFFF8606 // ID Select/SCSI Control Register
	move.l _hz_200,D1
.wh1:
		move.w 0xFFFF8604,D0
		btst #5,D0
		bne.s .wh2
		move.l _hz_200,D0
		sub.l D1,D0
		cmp.l D2,D0
	blt.s .wh1
	moveq #-1,D0 // time-out
	bra.s .wh3
.wh2:
	moveq #0,D0
.wh3:
	movem.l (SP)+,D1/D2
	rts

wait_end_cmd_scsi: // return D0 < 0 => time-out

	move.l #TIME_OUT_4S,D0
	cmp #6,D2 // bytes cmd
	beq.s .wec3
	move.l #TIME_OUT_10S,D0
.wec3:
	move.l _hz_200,D1
.wec5:
		btst #5,0xFFFFFA01 // GPIP MFP 68901
		beq .wec2
		move.l _hz_200,D2
		sub.l D1,D2
	cmp.l D0,D2
	blt.s .wec5
.wec4:
	btst #3,0xFFFF860F
	bne.s .wec4
	move.w #0x190,0xFFFF8606
	bsr mfp_delay
	move.w #0x90,0xFFFF8606 // DMA reading
	bsr mfp_delay
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #0x80,0xFFFF8604
	move.l #TIME_OUT_CMD,D0
	bsr delay_hz_200        // reset
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #0,0xFFFF8604
	move.l #200,D0          // 1 S
	bsr delay_hz_200
	moveq #-1,D0            // error
	bra.s .wec1
.wec2:
	move.w #0x8F,0xFFFF8606 // Initiate Receive/Reset
	move.w 0xFFFF8604,D0
	move.w #0x8A,0xFFFF8606 // Mode Register
	move.w #0,0xFFFF8604    // disable DMA
	move.w #0x89,0xFFFF8606 // Init-Command Register
	move.w #0,0xFFFF8604
	moveq #0,D0             // OK
.wec1:
	rts

#endif /* USE_ATARI_IO */

ide_cmd: 	// D0.L: bytes, D1.L: timeout ATAPI, A0: IDE buffer, A1: cmd buffer
	// return error code inside D0, and time speed test inside D1.L
#ifndef USE_ATARI_IO
	lea -24(SP),SP
	movem.l D2-D4/A0-A2,(SP)
#if 0 // #ifdef DEBUG
#ifndef MCF5445X
//	bsr debug_ide
#endif
	move.l D0,-(SP)
	move.l A0,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0,D2
.ir00:
		move.b (A1,D2),D0
		bsr debug_hex_byte
		moveq #0x20,D0
		bsr debug_display_char
	add.l #1,D2
	cmp.l #7,D2
	bcs.s .ir00
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif /* DEBUG */
	move.l D0,D2             // 0: non-data
	move.l D1,D4             // timeout ATAPI in _hz_200 units
	lea flock,A2
	bset #7,(A2)
	beq.s .ir13
	moveq #0,D1
	moveq #-1,D0             // error
	bra .ir0
.ir13:
#ifdef MCF5445X
	move.b 1(A1),D3          // C/D/H
	or.l #0xA0,D3
	move.b D3,ATA_DEVICE_HEAD
	moveq #0,D0
	move.b (A1),D0
	move.l #0x24,D3          // read sector(s) ext
	cmp.l D0,D3
	beq.s .ir29
	move.l #0x34,D3          // write sector(s) ext
	cmp.l D0,D3
	bne.s .ir30
.ir29:
	// previous data
	clr.b ATA_CYLINDER_HIGH
	clr.b ATA_CYLINDER_LOW	
	move.b 6(A1),D3          // feature special usage (trick for LBA48 B31-B24)
	move.b D3,ATA_SECTOR_NUM 
	move.l D2,D3
	swap D3
	lsr.l #1,D3              // / 512 / 256
	move.b D3,ATA_SECTOR_COUNT
	clr.b 6(A1)              // feature
	// current data
.ir30:
	move.b 2(A1),D3          // cyl high
	move.b D3,ATA_CYLINDER_HIGH
	move.b 3(A1),D3          // cyl low
	move.b D3,ATA_CYLINDER_LOW
	move.b 4(A1),D3          // sector num
	move.b D3,ATA_SECTOR_NUM 
	move.b 5(A1),D3          // sector count
	move.b D3,ATA_SECTOR_COUNT
#else /* MCF548X */
	move.b fire_engine_hw_rev,D3
	and.l #0xF0,D3
	cmp.l #0xA0,D3
	beq.s .ide_cpld_ok
	clr.w flock
	moveq #0,D1	
.ir29:
	moveq #-1,D0             // error
	bra .ir0
.ide_cpld_ok:
	moveq #0,D0
	move.b (A1),D0
	move.l #0x24,D3          // read sector(s) ext
	cmp.l D0,D3
	beq.s .ir29              // unimplemented
	move.l #0x34,D3          // write sector(s) ext
	cmp.l D0,D3
	beq.s .ir29              // unimplemented
	// word access are used for writing register
	// else byte writing on odd address register not works
	//       byte writing on even address write also on odd address register
	// reading works in byte or word access
	// => CPLD bug ?
	move.w 2(A1),D3          // sector high / sector low
	move.w D3,ATA_CYLINDER_HIGH
	move.w 4(A1),D3          // sector num / sector count
	move.w D3,ATA_SECTOR_NUM
#endif /* MCF5445X */
#else /* USE_ATARI_IO */
#ifdef COLDFIRE
	lea -24(SP),SP
	movem.l D2-D4/A0-A2,(SP)
#else
	movem.l D2-D4/A0-A2,-(SP)
#endif
#if 0 // #ifdef DEBUG
	move.l D0,-(SP)
	move.l A0,D0
	bsr debug_hex_long
	moveq #0x20,D0
	bsr debug_display_char
	moveq #0,D2
.ir00:
		move.b (A1,D2),D0
		bsr debug_hex_byte
		moveq #0x20,D0
		bsr debug_display_char
		add.l #1,D2
	cmp.l #7,D2
	bcs.s .ir00
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif /* DEBUG */
	move.l D0,D2             // 0: non-data
	move.l D1,D4             // timeout ATAPI in _hz_200 units
	lea flock,A2
	bset #7,(A2)
	beq.s .ir13
	moveq #0,D1
	moveq #-1,D0             // error
	bra .ir0
.ir13:
	lea ATA_DATA,A2
#ifdef COLDFIRE
#ifdef MCF547X
	move.b 1(A1),D3          // C/D/H
	btst #5,D3               // trick for 2nd IDE port
	beq.s .first_port
	lea FIREBEE_ATA,A2
.first_port:	
#endif /* MCF547X */
	move.b 1(A1),D3          // C/D/H
	or.l #0xA0,D3
	move.b D3,OFFSET_DEVICE_HEAD(A2)
	moveq #0,D0
	move.b (A1),D0
	move.l #0x24,D3          // read sector(s) ext
	cmp.l D0,D3
	beq.s .ir29
	move.l #0x34,D3          // write sector(s) ext
	cmp.l D0,D3
	bne.s .ir30
.ir29:
	// previous data
	clr.b OFFSET_CYLINDER_HIGH(A2)
	clr.b OFFSET_CYLINDER_LOW(A2)
	move.b 6(A1),D3          // feature special usage (trick for LBA48 B31-B24)
	move.b D3,OFFSET_SECTOR_NUM(A2)
	move.l D2,D3
	swap D3
	lsr.l #1,D3              // / 512 / 256
	move.b D3,OFFSET_SECTOR_COUNT(A2)
	clr.b 6(A1)              // feature
	// current data
.ir30:
	move.b 2(A1),D3          // cyl high
	move.b D3,OFFSET_CYLINDER_HIGH(A2)
	move.b 3(A1),D3          // cyl low
	move.b D3,OFFSET_CYLINDER_LOW(A2)
	move.b 4(A1),D3          // sector num
	move.b D3,OFFSET_SECTOR_NUM(A2)
	move.b 5(A1),D3          // sector count
	move.b D3,OFFSET_SECTOR_COUNT(A2)
#else /* ATARI */
	move.b 1(A1),D3          // C/D/H
	btst #5,D3               // trick for 2nd IDE port
	beq.s .first_port
	lea CTPCI_ATA,A2
.first_port:	
	move.b 1(A1),D3          // C/D/H
	or.b #0xA0,D3
	move.b D3,OFFSET_DEVICE_HEAD(A2)
	moveq #0x24,D3
	cmp.b (A1),D3            // read sector(s) ext
	beq.s .ir29
	moveq #0x34,D3
	cmp.b (A1),D3            // write sector(s) ext
	bne.s .ir30
.ir29:
	// previous data
	clr.b OFFSET_CYLINDER_HIGH(A2)
	clr.b OFFSET_CYLINDER_LOW(A2)	
	move.b 6(A1),OFFSET_SECTOR_NUM(A2) // feature special usage (trick for LBA48 B31-B24) 
	move.l D2,D3
	swap D3
	lsr.l #1,D3              // / 512 / 256
	move.b D3,OFFSET_SECTOR_COUNT(A2)
	clr.b 6(A1)              // feature
	// current data
.ir30:
	move.b 2(A1),OFFSET_CYLINDER_HIGH(A2) // cyl high
	move.b 3(A1),OFFSET_CYLINDER_LOW(A2)  // cyl low
	move.b 4(A1),OFFSET_SECTOR_NUM(A2)    // sector num
	move.b 5(A1),OFFSET_SECTOR_COUNT(A2)  // sector count
#endif /* COLDFIRE */
#endif /* USE_ATARI_IO */
	moveq #0,D1              // sector counter
#ifdef COLDFIRE
	moveq #0,D0
	move.b (A1),D0
	move.l #0xA1,D3          // identify packet device
	cmp.l D0,D3
	beq.s .ir7
	move.l #0xEC,D3          // identify device
	cmp.l D0,D3
#else
	move.b #0xA1,D3          // identify packet device
	cmp.b (A1),D3
	beq.s .ir7
	move.b #0xEC,D3          // identify device
	cmp.b (A1),D3
#endif /* COLDFIRE */
	beq.s .ir7
	move.l D2,D0
	beq.s .ir7               // non-data
	move.w D0,D1
	and.l #0x1FF,D1
	lsr.l #8,D0              // bytes
	lsr.l #1,D0              // / 512
	tst.l D1
	beq.s .ir6
	addq.l #1,D0
.ir6:
	moveq #0,D1
	move.b D0,D1
	beq .ir5
	subq.l #1,D1             // sector counter
.ir7:
#ifndef USE_ATARI_IO
#ifdef MCF5445X
	move.b 6(A1),D0                   // features (error when read)
	move.b D0,ATA_ERROR_REGISTER
	moveq #2,D0
	move.b D0,ATA_CONTROL_DEVICE      // control device, disable interrupt
 	move.w (A1),D0           // command, C/D/H
 	move.w D0,ATA_STATUS_COMMAND
	move.l MCF_DTIM_DTCN1,D0 // uS
#else /* MCF548X */
	// word access are used for writing register
	// else byte writing on odd address register not works
	//       byte writing on even address write also on odd address register
	// reading works in byte or word access
	// => CPLD bug ?
	move.b 6(A1),D0
	asl.l #8,D0
	move.w D0,ATA_ERROR_REGISTER      // features (error when read)
	moveq #2,D0
	move.w D0,ATA_CONTROL_DEVICE-1    // control device, disable interrupt
 	move.w (A1),D0           // command, C/D/H
 	move.w D0,ATA_STATUS_COMMAND
	move.l MCF_SLT_SCNT1,D0  // uS * SYSTEM_CLOCK
#endif /* MCF5445X */
#else /* USE_ATARI_IO */
#ifdef COLDFIRE
	move.b 6(A1),D0
	move.b D0,OFFSET_ERROR_REGISTER(A2)    // features (error when read)
	clr.b OFFSET_CONTROL_DEVICE(A2)        // control device, INTRQ on MFP IO5
 	move.b (A1),D0
 	move.b D0,OFFSET_STATUS_COMMAND(A2)    // command
	move.l MCF_SLT_SCNT1,D0  // uS * SYSTEM_CLOCK
#else /* ATARI */
	move.b 6(A1),OFFSET_ERROR_REGISTER(A2) // features (error when read)
	clr.b OFFSET_CONTROL_DEVICE(A2)        // control device, INTRQ on MFP IO5
 	move.b (A1),OFFSET_STATUS_COMMAND(A2)  // command
	bsr get_timer_c
#endif /* COLDFIRE */
#endif /* USE_ATARI_IO */
	move.l D0,D3             // speed test
	moveq #0,D0
	move.b (A1),D0
	cmp.l #0xA0,D0           // packet
	beq .ir14
	cmp.l #0x30,D0           // write sector(s)
	bne .ir10                // read
.ir4:
#ifndef USE_ATARI_IO
	move.b ATA_STATUS_COMMAND,D0           // state
#else
	move.b OFFSET_STATUS_COMMAND(A2),D0    // state
#endif
	btst #3,D0               // DRQ
	beq.s .ir4
#ifndef USE_ATARI_IO
.ir8:		// write
		lea ATA_DATA,A1   // IDE buffer
		moveq #31,D0      // 512 bytes
.ir11:
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
		subq.l #1,D0
		bpl.s .ir11
		move.l #TIME_OUT_CMD,D0
		bsr wait_end_cmd_ide
		bmi .ir1          // time-out
		move.b ATA_STATUS_COMMAND,D0   // state
		and.l #9,D0       // DRQ & ERR
		btst #3,D0        // DRQ
		beq .ir1          // error		
	subq.l #1,D1
	bpl.s .ir8
	bra.s .ir12
.ir10:		// read
		move.l #TIME_OUT_CMD,D0
		bsr wait_end_cmd_ide
		bmi .ir1          // time-out
 		tst.l D2
		beq .ir9          // no data
		move.b ATA_STATUS_COMMAND,D0   // state
		and.l #9,D0       // DRQ & ERR
		btst #3,D0        // DRQ
		beq .ir1          // error
		lea ATA_DATA,A1   // IDE buffer
		moveq #31,D0      // 512 bytes
.ir3:
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
		subq.l #1,D0
		bpl.s .ir3
	subq.l #1,D1
	bpl.s .ir10
.ir12:	// end without error
#ifdef MCF5445X
	move.l MCF_DTIM_DTCN1,D0 // uS
	sub.l D0,D3
	neg.l D3	           // time speed test
#else /* MCF548X */
	move.l MCF_SLT_SCNT1,D0 // uS * SYSTEM_CLOCK
	sub.l D0,D3             // time speed test
	move.l #SYSTEM_CLOCK,D0
	divu.l D0,D3            // uS
#endif /* MCF5445X */
#else /* USE_ATARI_IO */
.ir8:		// write
		lea OFFSET_DATA(A2),A1   // IDE buffer
#if defined(COLDFIRE) && defined(MCF547X) // FIREBEE
#ifdef IDE_16BITS
		moveq #31,D0      // 512 bytes
.ir11:
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
			move.w (A0)+,(A1)
#else
		moveq #15,D0      // 512 bytes
.ir11:
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
#endif /* IDE_16BITS */
		subq.l #1,D0
		bpl.s .ir11
#else /* !(defined(COLDFIRE) && defined(MCF547X)) */
		moveq #15,D0      // 512 bytes
.ir11:
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
			move.l (A0)+,(A1)
		dbf D0,.ir11
#endif /* defined(COLDFIRE) && defined(MCF547X) */
		move.l #TIME_OUT_CMD,D0
		bsr wait_end_cmd_ide
		bmi .ir1          // time-out
		move.b OFFSET_STATUS_COMMAND(A2),D0   // state
		and.l #9,D0       // DRQ & ERR
		btst #3,D0        // DRQ
		beq .ir1          // error
#if defined(COLDFIRE) && defined(MCF547X)
	subq.l #1,D1
	bpl.s .ir8
#else
	dbf D1,.ir8
#endif
	bra .ir12
.ir10:		// read
		move.l #TIME_OUT_CMD,D0
		bsr wait_end_cmd_ide
		bmi .ir1          // time-out
 		tst.l D2
		beq .ir9 	     // no data
		move.b OFFSET_STATUS_COMMAND(A2),D0 // state
		and.l #9,D0       // DRQ & ERR
		btst #3,D0        // DRQ
		beq .ir1          // error
		lea OFFSET_DATA(A2),A1 // IDE buffer
#if defined(COLDFIRE) && defined(MCF547X) // FIREBEE
#ifdef IDE_16BITS
		moveq #31,D0      // 512 bytes
.ir3:
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
			move.w (A1),(A0)+
#else
		moveq #15,D0      // 512 bytes
.ir3:
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
#endif /* IDE_16BITS */
		subq.l #1,D0
		bpl.s .ir3
	subq.l #1,D1
	bpl.s .ir10
#else /* !(defined(COLDFIRE) && defined(MCF547X)) */
		moveq #15,D0      // 512 bytes
.ir3:
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
			move.l (A1),(A0)+
		dbf D0,.ir3
	dbf D1,.ir10
#endif /* defined(COLDFIRE) && defined(MCF547X) */
.ir12:	// end without error
#ifdef COLDFIRE
	move.l MCF_SLT_SCNT1,D0 // uS * SYSTEM_CLOCK
	sub.l D0,D3             // time speed test
	move.l #SYSTEM_CLOCK,D0
	divu.l D0,D3            // uS
#else
	bsr get_timer_c
	sub.l D3,D0
	move.l D0,D3	           // time speed test
#endif
#endif /* USE_ATARI_IO */
.ir5:
	moveq #0,D0
	bra .ir1
.ir14:	                        // *** ATAPI ***
	move.l _hz_200,D1
.ir21:
#ifndef USE_ATARI_IO
		tst.b ATA_STATUS_COMMAND // BSY bit
#else
		tst.b OFFSET_STATUS_COMMAND(A2) // BSY bit	
#endif
		bpl.s .ir22
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l D4,D0
	blt.s .ir21
	moveq #-1,D0 // time-out
	bra .ir1
.ir22:
#ifndef USE_ATARI_IO
		move.b ATA_STATUS_COMMAND,D0
#else
		move.b OFFSET_STATUS_COMMAND(A2),D0
#endif
		and.l #9,D0
		btst #0,D0 // ERROR
		bne .ir24  // error
		btst #3,D0 // DRQ
		bne.s .ir23
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l D4,D0
	blt.s .ir22
	moveq #-1,D0 // time-out
	bra .ir1
.ir23:
	moveq #0,D1
.ir17:
		move.w 8(A1,D1.l),D0 // ATAPI command
#ifdef COLDFIRE
		moveq #0,D2
		move.w D0,D2
		lsr.l #8,D2
		asl.l #8,D0
		or.l D2,D0
#else
		ror.w #8,D0
#endif /* COLDFIRE */
#ifndef USE_ATARI_IO
		move.w D0,ATA_DATA
#else
		move.w D0,OFFSET_DATA(A2)
#endif
		addq.l #2,D1
	cmp.l #12,D1
	bcs.s .ir17
	move.b 6(A1),D0         // features
#ifndef USE_ATARI_IO
	lea ATA_DATA,A1         // IDE buffer
#else
	lea OFFSET_DATA(A2),A1  // IDE buffer
#endif
	btst #2,D0
	bne.s .ir19             // transfer to the host (read)
.ir18:	// write
		move.l D4,D0
		bsr wait_end_cmd_ide
		bmi .ir1          // time-out
#ifndef USE_ATARI_IO
		move.b ATA_STATUS_COMMAND,D0 // state
#else
		move.b OFFSET_STATUS_COMMAND(A2),D0 // state
#endif
		and.l #9,D0       // DRQ & ERR
		btst #3,D0        // DRQ
		beq .ir24         // error or command finished
		moveq #0,D1
#ifndef USE_ATARI_IO
		move.b ATA_CYLINDER_HIGH,D1
		asl.l #8,D1
		move.b ATA_CYLINDER_LOW,D1 // packet byte count
		lsr.l #1,D1
#else
		move.b OFFSET_CYLINDER_HIGH(A2),D1
		asl.l #8,D1
		move.b OFFSET_CYLINDER_LOW(A2),D1 // packet byte count
		lsr.l #1,D1
		btst #0,D1
		beq.s .ir25
#endif /* ATARI_USE_IO */
		subq.l #1,D1
		bmi.s .ir18
.ir16:		// 16 bits write

			move.w (A0)+,D0
#ifdef COLDFIRE
			moveq #0,D2
			move.w D0,D2
			lsr.l #8,D2
			asl.l #8,D0
			or.l D2,D0
#else
			ror.w #8,D0
#endif /* COLDFIRE */
			move.w D0,(A1)
#ifdef COLDFIRE
		subq.l #1,D1
		bpl.s .ir16
#else
		dbf D1,.ir16
#endif /* COLDFIRE */
	bra.s .ir18
#ifdef USE_ATARI_IO
.ir25:
		lsr.l #1,D1
		subq.l #1,D1
		bmi.s .ir18
.ir26:		// 32 bits write
			move.l (A0)+,D0
#ifdef COLDFIRE
			move.l D0,D2
			lsr.l #8,D2
			asl.l #8,D0
			and.l #0x00FF00FF,D2
			and.l #0xFF00FF00,D0
			or.l D2,D0
#else
			ror.w #8,D0
			swap D0
			ror.w #8,D0
			swap D0
#endif /* COLDFIRE */
			move.l D0,(A1)
#ifdef COLDFIRE
		subq.l #1,D1
		bpl.s .ir26
#else
		dbf D1,.ir26
#endif
	bra.s .ir18
#endif /* USE_ATARI_IO */
.ir19:	// read
		move.l D4,D0
		bsr wait_end_cmd_ide
		bmi .ir1          // time-out
#ifndef USE_ATARI_IO
		move.b ATA_STATUS_COMMAND,D0 // state
#else
		move.b OFFSET_STATUS_COMMAND(A2),D0 // state
#endif
		and.l #9,D0       // DRQ & ERR
		btst #3,D0        // DRQ
		beq .ir24         // error or command finished
		moveq #0,D1
#ifndef USE_ATARI_IO
		move.b ATA_CYLINDER_HIGH,D1
		asl.l #8,D1
		move.b ATA_CYLINDER_LOW,D1 // packet byte count
		lsr.l #1,D1
#else
		move.b OFFSET_CYLINDER_HIGH(A2),D1
		asl.l #8,D1
		move.b OFFSET_CYLINDER_LOW(A2),D1 // packet byte count
		lsr.l #1,D1
		btst #0,D1
		beq.s .ir27
#endif /* USE_ATARI_IO */
		subq.l #1,D1
		bmi.s .ir19
.ir15:		// 16 bits read
			move.w (A1),D0
#ifdef COLDFIRE
			moveq #0,D2
			move.w D0,D2
			lsr.l #8,D2
			asl.l #8,D0
			or.l D2,D0
#else
			ror.w #8,D0
#endif /* COLDFIRE */
			move.w D0,(A0)+
#ifdef COLDFIRE
		subq.l #1,D1
		bpl.s .ir15
#else
		dbf D1,.ir15
#endif /* CODFIRE */
	bra.s .ir19
#ifdef USE_ATARI_IO
.ir27:
		lsr.l #1,D1
		subq.l #1,D1
		bmi.s .ir19
.ir28:		// 32 bits read
			move.l (A1),D0
#ifdef COLDFIRE
			move.l D0,D2
			lsr.l #8,D2
			asl.l #8,D0
			and.l #0x00FF00FF,D2
			and.l #0xFF00FF00,D0
			or.l D2,D0
#else
			ror.w #8,D0
			swap D0
			ror.w #8,D0
			swap D0
#endif /* COLDFIRE */
			move.l D0,(A0)+
#ifdef COLDFIRE
		subq.l #1,D1
		bpl.s .ir28
#else
		dbf D1,.ir28
#endif /* COLDFIRE */
	bra.s .ir19
#endif /* USE_ATARI_IO */
.ir24:	// ATAPI
#ifndef USE_ATARI_IO
	btst #0,ATA_STATUS_COMMAND        // state, ERR
	beq .ir12                         // end without error
	move.b ATA_ERROR_REGISTER,D0      // error register
#else /* USE_ATARI_IO */
	btst #0,OFFSET_STATUS_COMMAND(A2) // state, ERR
	beq .ir12                         // end without error
	move.b OFFSET_ERROR_REGISTER(A2),D0 // error register
#endif /* USE_ATARI_IO */
	bra.s .ir1	
.ir9:	// IDE
#ifndef USE_ATARI_IO
	btst #0,ATA_STATUS_COMMAND        // state, ERR
	beq .ir12                         // end without error
	move.b ATA_ERROR_REGISTER,D0      // error register
#else /* USE_ATARI_IO */
	btst #0,OFFSET_STATUS_COMMAND(A2) // state, ERR
	beq .ir12                         // end without error
	move.b OFFSET_ERROR_REGISTER(A2),D0 // error register
#endif /* USE_ATARI_IO */
	and.l #0x6E,D0            // WP, MC, MCR, ABRT, NM
	bra.s .ir1	
.ir2:
	moveq #-1,D0              // error, time-out
.ir1:
#ifndef USE_ATARI_IO
#ifdef MCF5445X
	moveq #2,D1
	move.b D1,ATA_CONTROL_DEVICE      // control device, disable interrupt
#else /* MCF548X */
	// word access are used for writing register
	// else byte writing on odd address register not works
	//       byte writing on even address write also on odd address register
	// reading works in byte or word access
	// => CPLD bug ?
	moveq #2,D1
	move.w D1,ATA_CONTROL_DEVICE-1    // control device, disable interrupt
#endif /* MCF5445X */
#else /* USE_ATARI_IO */
#ifdef COLDFIRE
	moveq #2,D1
	move.b D1,OFFSET_CONTROL_DEVICE(A2) // control device, disable interrupt
#else /* ATARI */
	move.b #2,OFFSET_CONTROL_DEVICE(A2) // control device, no INTRQ on MFP IO5
#endif /* COLDFIRE */
#endif /* USE_ATARI_IO */
	clr.w flock
	move.l D3,D1              // time speed test
#ifndef USE_ATARI_IO
#if 0 // #ifdef DEBUG
//	bsr debug_ide
#if 1
	tst.l D0
	beq.s .ir0
	move.l D0,-(SP)
	lea debug126(PC),A0
	bsr debug_display_string
	move.l (SP),D0
	bsr debug_hex_byte
	moveq #0x20,D0
	bsr debug_display_char
	move.b ATA_STATUS_COMMAND,D0
	bsr debug_hex_byte
	moveq #0x20,D0
	bsr debug_display_char
	move.b ATA_ERROR_REGISTER,D0      // error register
	bsr debug_hex_byte
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D0
#endif
#endif
#endif
.ir0:
#ifdef COLDFIRE
	movem.l (SP),D2-D4/A0-A2
	lea 24(SP),SP
#else
	movem.l (SP)+,D2-D4/A0-A2
#endif
	tst.l D0
	rts

#ifdef COLDFIRE
ide_reset:

#ifdef MCF547X
	lea 0xFFFF8800,A0        // PSG (FPGA emulation)
	lea 2(A0),A1
	move.w SR,D1
	move.w D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
	move.b #14,(A0)          // port A
	move.b (A0),D0           // read port A
	bset #7,D0               // reset IDE
	move.b D0,(A1)           // write port A
	move.w (SP)+,D1
	move.w D1,SR             // restore interrupts
	move.l _hz_200,D1	
.delay_reset_ide:
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #2,D0                  // 10 mS
	ble.s .delay_reset_ide
	move.w SR,D1
	move.w D1,-(SP)
	or.l #0x700,D1           // mask interrupts
	move.w D1,SR
	move.b #14,(A0)          // port A
	move.b (A0),D0           // read port A
	bclr #7,D0               // reset IDE
	move.b D0,(A1)           // write port A
	move.w (SP)+,D1
	move.w D1,SR             // restore interrupts
#endif /* MCF547X */
#ifdef MCF5445X
	clr.b MCF_ATA_CR             // control reset
	move.l _hz_200,D1	
.delay_reset_ide:
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #2,D0                  // 10 mS
	ble.s .delay_reset_ide
	/* IDE set */
	lea piotms+(2*9*2)(PC),A0    // PIO 2
	move.l #1000/SYSTEM_CLOCK,D1 // period in ns
	moveq #0,D0
	move.w (A0)+,D0              // t1
	add.l D1,D0                  // + period
	sub.l #1,D0
	divu D1,D0                   // / period
	move.b D0,MCF_ATA_TIME_1
	moveq #0,D0
	move.w (A0)+,D0              // t2
	add.l D1,D0                  // + period
	sub.l #1,D0
	divu D1,D0                   // / period
	move.b D0,MCF_ATA_TIME_2W
	move.b D0,MCF_ATA_TIME_2R
	addq.l #2,A0                 // t3
	moveq #0,D0
	move.w (A0)+,D0              // t4
	add.l D1,D0                  // + period
	sub.l #1,D0
	divu D1,D0                   // / period
	move.b D0,MCF_ATA_TIME_4
	addq.l #4,A0                 // t5, t6
	moveq #0,D0
	move.w (A0)+,D0              // t9
	add.l D1,D0                  // + period
	sub.l #1,D0
	divu D1,D0                   // / period
	move.b D0,MCF_ATA_TIME_9
	moveq #0,D0
	move.w (A0)+,D0              // tRD
	add.l D1,D0                  // + period
	sub.l #1,D0
	divu D1,D0                   // / period
	move.b D0,MCF_ATA_TIME_PIORDX
	moveq #0,D0
	move.w (A0)+,D0              // tA
	add.l D1,D0                  // + period
	sub.l #1,D0
	divu D1,D0                   // / period
	move.b D0,MCF_ATA_TIME_AX
	moveq #0x40,D0               // IORDY enable
	move.b D0,MCF_ATA_CR
	move.l _hz_200,D1	
.delay_end_reset_ide:
		move.l _hz_200,D0
		sub.l D1,D0
	cmp.l #40,D0                 // 200 mS
	ble.s .delay_end_reset_ide
	bset #0,MCF_ATA_CR           // IORDY enable
#endif /* MCF5445X */
	rts
	
#ifdef MCF5445X
	/*   t1,  t2, t3, t4, t5,t6, t9,tRD, tA */
piotms:
	dc.w 70, 165, 60, 30, 50, 5, 20,  0, 35 /* PIO 0 */
	dc.w 50, 125, 45, 20, 35, 5, 15,  0, 35 /* PIO 1 */
	dc.w 30, 100, 30, 15, 20, 5, 10,  0, 35 /* PIO 2 */
	dc.w 30,  80, 30, 10, 20, 5, 10,  0, 35 /* PIO 3 */
	dc.w 25,  70, 20, 10, 20, 5, 10,  0, 35 /* PIO 4 */
#endif

#endif /* COLDFIRE*/

#ifndef COLDFIRE
#define EBUG
#endif

#ifndef USE_ATARI_IO
#ifndef MCF5445X
#ifdef DEBUG
	
debug_ide:

	move.l A0,-(SP)
	move.l A1,-(SP)
	move.l D0,-(SP)
	move.l D1,-(SP)
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	moveq #15,D1
	lea COMPACTFLASH_BASE+0x1800,A1
.loop:
	move.b (A1)+,D0
	bsr debug_hex_byte
	moveq #0x20,D0
	bsr debug_display_char
	subq.l #1,D1
	bpl.s .loop
	moveq #13,D0
	bsr debug_display_char
	moveq #10,D0
	bsr debug_display_char
	move.l (SP)+,D1
	move.l (SP)+,D0	
	move.l (SP)+,A1
	move.l (SP)+,A0
	rts
#endif /* DEBUG */
#endif /* MCF5445X */
#endif /* COLDFIRE */
	
wait_end_cmd_ide:	// time-out inside D0.L, return D0 < 0 => time-out

	move.l D1,-(SP)
	move.l D2,-(SP)
	move.l _hz_200,D1
.weci1:
#ifndef USE_ATARI_IO
		tst.b ATA_STATUS_COMMAND // busy bit	
		bpl.s .weci2
#else /* USE_ATARI_IO */
#ifdef COLDFIRE
		tst.b OFFSET_STATUS_COMMAND(A2) // busy bit	
		bpl.s .weci2
#else
		btst #5,0xFFFFFA01     // GPIP MFP 68901
		beq.s .weci2
#endif /* COLDFIRE */
#endif /* USE_ATARI_IO */
		move.l _hz_200,D2
		sub.l D1,D2
	cmp.l D0,D2
	blt.s .weci1
	moveq #-1,D0 // time-out
	bra.s .weci3
.weci2:
	moveq #0,D0
.weci3:
	move.l (SP)+,D2
	move.l (SP)+,D1
	rts

#ifdef COLDFIRE

display_drive:

	link A6,#-8
	add.l #0x41,D1
	move.w D1,-(SP)          // logical drive
	moveq #0x30,D1
	or.l D0,D1	            // device number
	move.w D1,-(SP)         
	lea blue(PC),A0
	moveq #PUN_IDE,D1
	and.l D0,D1
	bne.s .display_ide
	pea message2(PC)         // SCSI-disk installed
	bra.s .display_color
.display_ide:
	pea message1(PC)         // IDE-disk installed
.display_color:
	bsr text_color
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	move.w #0x2E,-(SP)       // .
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	move.w #0x30,-(SP)       // 0
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	lea black(PC),A0
	bsr text_color
	pea message3(PC)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	pea message4(PC)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	cmp.l #0xFF,D2           // part_type
	bhi.s .gem_part
	move.l D2,D0
	bsr hex_byte
	bra.s .size_part
.gem_part:
	move.l D2,D0
	asl.l #8,D0
	move.l D0,-4(A6)
	pea -4(A6)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP	
.size_part:
	pea message5(PC)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
	add.l #1024,D3	
	moveq #11,D0
	lsr.l D0,D3              // sector size / 1024*2 => MB
	move.l D3,D0             
	clr.w -2(A6)
	lea -8(A6),A0
	moveq #6,D1
	jsr conv_ascii_value_optimized
	pea -8(A6)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP	
	pea message6(PC)         // MB
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP	
	unlk A6
	rts

text_color:

	moveq #0,D0
	move.w 0x3E86,D0         // number of planes
	cmp.l #2,D0
	bls.s .black_and_white
	pea (A0)
	move.w #9,-(SP)
	trap #1                  // Cconws
	addq.l #6,SP
.black_and_white:
	rts

hex_byte:
	move.w D0,-(SP)
	lsr.l #4,D0        
	bsr.s hex_char      
	move.w (SP)+,D0      
hex_char:
	and.l #0xF,D0      
	or.l #0x30,D0      
	cmp.l #0x3A,D0     
	bcs.s .display_char  
	addq.l #7,D0
.display_char:
	move.w D0,-(SP)
	move.w #2,-(SP)
	trap #1                  // Cconout
	addq.l #4,SP
	rts

message1:	.asciz "IDE  "
message2:	.asciz "SCSI "
message3:	.asciz " partition installed in "
message4:	.asciz ", type "
message5:	.asciz ", "
message6:	.ascii " MB"
crlf:	.byte 13,10,0
blue:	.byte 0x1B,0x62,0x34,0
black:	.byte 0x1B,0x62,0x3F,0

	.align 2
	
#ifdef DEBUG

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
	
#endif /* DEBUG */

#else /* ATARI */

get_timer_c:

	move.l D1,-(SP)
	move.w SR,-(SP)
	or.w #0x700,SR           // no interrupts
	move.l _hz_200,D0
	asl.l #8,D0
	moveq #0,D1
	move.b 0xFFFFFA23,D1     // TCDR timer C MFP
	subq.b #1,D1             // 0-191
	asl.l #8,D1              // * 256
	divu #192,D1             // 0-255
	not.b D1
	move.b D1,D0
	move.w (SP)+,SR
	move.l (SP)+,D1
	rts

get_ide2_address:

	movem.l A0-A5,-(SP)
	move.w SR,-(SP)
	or.w #0x700,SR               // no interrupts
	lea .no_ctpci(PC),A1
	move.l 8,A5                  // bus error
	move.l A1,8
	move.l SP,A4                 // save ssp
	moveq #0,D0
	lea CTPCI_ATA,A0
	tst.w (A0)
	move.l A0,D0                 // address
.no_ctpci:
	move.l A5,8                  // restore bus error
	move.l A4,SP                 // restore ssp
	move.w (SP)+,SR
	movem.l (SP)+,A0-A5
	tst.l D0
	rts

#endif /* COLDFIRE */

#ifndef COLDFIRE
#ifdef DEBUG

dump:
	movem.l D0-D2/A0-A1,-(SP)
.loop_dump1:
		moveq #13,D0
		bsr display_char
		moveq #10,D0
		bsr display_char
#if 0 // #ifdef COLDFIRE
		moveq #13,D0
		bsr debug_display_char
		moveq #10,D0
		bsr debug_display_char
#endif		
		moveq #15,D2
.loop_dump2:
			move.b (A1)+,D0
			bsr hex_byte
#if 0 // #ifdef COLDFIRE
			move.b -1(A1),D0
			bsr debug_hex_byte
#endif
			moveq #0x20,D0
			bsr display_char
#if 0 // #ifdef COLDFIRE
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
#if 0 // #ifdef COLDFIRE
			bsr debug_display_char
#endif	
		dbf D2,.loop_dump3
	dbf D1,.loop_dump1
	movem.l (SP)+,D0-D2/A0-A1
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

debug_hex_long:
	move.l D0,-(SP)
	swap D0
	bsr.s hex_word
	move.l (SP)+,D0
debug_hex_word:
	move.w D0,-(SP)
	lsr.w #8,D0          
	bsr.s hex_byte     
	move.w (SP)+,D0
debug_hex_byte:
	move.w D0,-(SP)
	lsr.b #4,D0        
	bsr.s hex_char      
	move.w (SP)+,D0      
debug_hex_char:
	and.b #0xF,D0      
	or.b #0x30,D0      
	cmp.b #0x3A,D0     
	bcs.s display_char  
	addq.b #7,D0   

debug_display_char:

	movem.l D0-D2/A0-A2,-(SP)
	move.w D0,-(SP)
	move.l #0x5F504349,D0 
	lea 0xED0000,A0          // 128 KB
	cmp.l (A0),D0            // _PCI
	beq.s .ddc2
	lea 0xEC0000,A0          // 192 KB
	cmp.l (A0),D0            // _PCI
	beq.s .ddc2
	lea 0xEB0000,A0          // 256 KB
	cmp.l (A0),D0            // _PCI
	beq.s .ddc2
	lea 0xEA0000,A0          // 320 KB
	cmp.l (A0),D0            // _PCI
	bne.s .ddc3
.ddc2:
	move.w (SP),D0           // character
	swap D0
	move.w #0x0076,D0        // 'v'
	move.l D0,-(SP)
	jsr 40(A0)               // drivers PCI in flash, dbug
	addq.l #4,SP
	bne.s .ddc1
.ddc3:
	move.w #2,-(SP)
	move.w #3,-(SP)          // Bconout
	trap #13
	addq.l #4,SP
.ddc1:	
	addq.l #2,SP
	movem.l (SP)+,D0-D2/A0-A2
	rts

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
#endif
#endif

#ifdef DEBUG

debug125:	.asciz "BPB: "
debug126:	.asciz "IDE error (code - STATUS - ERROR) "
debug127:	.asciz "hdv_rw 0x"
debug128:	.asciz "pun_ptr 0x"
debug129:	.asciz "drvbits 0x"
debug130:	.asciz "SCSCDRV In Handle 0x"
debug131:	.asciz "SCSIDRV Out Handle 0x"
debug132:	.asciz "XHDI XHReadWrite 0x"
debug133:	.ascii "XHDI XHInqTarget"
	.byte 13,10,0
debug134:	.ascii "XHDI XHInqDev"
	.byte 13,10,0
debug135:	.ascii "XHDI XHInqDriver"
	.byte 13,10,0
debug136:	.ascii "XHDI XHInqDev2"
	.byte 13,10,0
debug137:	.ascii "XHDI XHDOSLimits"
	.byte 13,10,0
debug138:	.asciz "SCSCDRV Open BusNo 0x"
debug139:	.ascii "SCSIDRV Close"
	.byte 13,10,0
debug140:	.ascii "SCSIDRV Error"
	.byte 13,10,0
debug141:	.asciz "SCSIDRV RescanBus BusNo 0x"
debug142:	.asciz "SCSIDRV CheckDev BusNo 0x"
debug143:	.asciz "SCSIDRV InquireBus BusNo 0x"
debug144:	.asciz "SCSIDRV InquireSCSI "
debug145:	.asciz " Ret "
debug146:	.asciz " Sense key "
debug147:	.asciz " ASC "
debug148:	.asciz " ASCQ "
debug149:	.asciz " SCSIId.lo 0x"
debug150:	.byte 13,10
	.asciz " Cmd "
debug151:	.asciz " => Handle 0x"
debug152:	.asciz " Buffer 0x"
debug153:	.asciz " Timeout 0x"
debug154:	.asciz " TransferLen 0x"
debug155:	.asciz " => "
debug156:	.ascii "SCCSIDRV Unimplemented"
	.byte 13,10,0
#endif


