/*
  Configure the CT60-SDRAM & I2C interface

  Didier Mequignon 2001-2005, e-mail: aniplay@wanadoo.fr

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/
	/* .import cpu_cookie */

	.globl _ct60_read_info_sdram
	.globl _ct60_read_info_clock
	.globl read_seq_device_i2c
	.globl write_seq_device_i2c
	.globl ct60_configure_sdram
	.globl _ct60_rw_clock
	.globl read_i2c
	.globl write_i2c
	
SLAVE_SDRAM_ADDRESS     = 0x50 | 7 bits 1010xxx
SLAVE_DS_ADDRESS        = 0x58   
SLAVE_CY_EEPROM_ADDRESS = 0x68
SLAVE_CY_SRAM_ADDRESS   = 0x69

| DS1085 serial programmable clock registers
DIVWORD   = 0x01
MUXWORD   = 0x02
DACWORD   = 0x08
ADR       = 0x0D
OFFSET    = 0x0E
RANGEWORD = 0x37
WRITE     = 0x3F

CT60_CLOCK_READ         = 0
CT60_CLOCK_WRITE_RAM    = 1
CT60_CLOCK_WRITE_EEPROM = 2
CT60_CLOCK_RESET        = 3

CT60_READ_ERROR         = -1
CT60_CHIP_DENSITY_ERROR = -2
CT60_NUM_BANK_ERROR     = -3
CT60_MOD_DENSITY_ERROR  = -4
CT60_BURST_LENGTH_ERROR = -5
CT60_DATA_WIDTH_ERROR   = -6
CT60_VOLTAGE_ERROR      = -7
CT60_SDRAM_TYPE_ERROR   = -8
CT60_REFRESH_RATE_ERROR = -9

_gpip_mfp = 0xfffffa01
_ddr_mfp  = 0xfffffa05
_iera_mfp = 0xfffffa07      | MFP registers
_ipra_mfp = 0xfffffa0b
_isra_mfp = 0xfffffa0f
_imra_mfp = 0xfffffa13
_tbcr_mfp = 0xfffffa1b
_tbdr_mfp = 0xfffffa21      | timer B
_tcdr_mfp = 0xfffffa23      | timer C
_scl_low  = 0xf0000000      | write 0 to SCL line (clock)
_scl_high = 0xf0400000      | write 1 to SCL line (clock)
_sda_low  = 0xf0800000      | write 0 to SDA line (data)
_sda_high = 0xf0c00000      | write 1 to SDA line (data) 
_sda      = 0xf0000000      | read from SDA line on the D0 CPU data bus
_sdcnf    = 0xf2000000      | SDRAM configuration $f2xx0000 

.macro WAIT_US
	move.b (A0),D0
0:
	cmp.b (A0),D0            | 26uS (timer C) or 6.5uS (timer B)
	beq.s 0b
	.endm
	
.macro SCL_LOW_SCC

	move.w wr5_scc,D0
	bclr #1,D0               | RTS
	move.b #5,0xFFFF8C85      | WR5
	move.b D0,0xFFFF8C85
	move.w D0,wr5_scc
	.endm
	
.macro SCL_HIGH_SCC

	move.w wr5_scc,D0
	bset #1,D0               | RTS
	move.b #5,0xFFFF8C85      | WR5
	move.b D0,0xFFFF8C85
	move.w D0,wr5_scc
	.endm
	
.macro SDA_LOW_SCC

	move.w wr5_scc,D0
	bclr #7,D0               | DTR
	move.b #5,0xFFFF8C85      | WR5
	move.b D0,0xFFFF8C85
	move.w D0,wr5_scc
	.endm
	
.macro SDA_HIGH_SCC

	move.w wr5_scc,D0
	bset #7,D0               | DTR
	move.b #5,0xFFFF8C85      | WR5
	move.b D0,0xFFFF8C85
	move.w D0,wr5_scc
	.endm

.macro SDA_SCC

	btst #5,0xFFFF8C85       | CTS
	sne.b D0
	.endm

_ct60_rw_clock:
	move.l	d2,-(sp)
	move.l	4+4(sp),d0
	move.l	8+4(sp),d1
	move.l	12+4(sp),d2	
	bsr	ct60_rw_clock_orig
	move.l	(sp)+,d2
	rts

ct60_rw_clock_orig:               | D0.W: mode (0: read, 1:write ram, 2: write eeprom) B15:cypress(0)/dallas(1)
                             | D1.W: address, D2:.W data, D0 return data or error
	tst.w D0                 | mode
	bmi.s 4f                 | dallas
	cmp.w #CT60_CLOCK_READ,D0
	bne.s 2f
	move.w D1,D0             | address
	bra read_i2c_cy_sram
2:
	cmp.w #CT60_CLOCK_WRITE_RAM,D0
	bne.s 3f
	move.w D1,D0             | address
	move.w D2,D1             | data
	bra write_i2c_cy_sram
3:
	cmp.w #CT60_CLOCK_WRITE_EEPROM,D0
	bne.s 12f
	move.w D1,D0             | address
	move.w D2,D1             | data
	bra write_i2c_cy_eeprom
12:
	cmp.w #CT60_CLOCK_RESET,D0
	bne 1f
	moveq #0,D0              | address
	move.w #0x80,D1           | data: reset soft
	bra write_i2c_cy_sram
4:
	bclr #15,D0              | mode
	cmp.w #CT60_CLOCK_READ,D0
	bne.s 5f
	moveq #SLAVE_DS_ADDRESS,D0
	swap D0
	move.w D1,D0             | address
	cmp.w #ADR,D0
	beq.s 8f                 | byte
	cmp.w #OFFSET,D0	
	bne.s 7f                 | word	
8:
	bra read_i2c
7:
	link A6,#-2
	lea -2(A6),A0
	moveq #2,D1              | len
	bsr read_seq_device_i2c
	bmi.s 11f
	move.w (A0),D0           | data
11:
	unlk A6
	rts 
5:
	cmp.w #CT60_CLOCK_WRITE_RAM,D0
	bne.s 6f
	moveq #SLAVE_DS_ADDRESS,D0
	swap D0
	move.w D1,D0             | address
	cmp.w #ADR,D0
	beq.s 10f                | byte
	cmp.w #OFFSET,D0	
	bne.s 9f                 | word	
10:
	move.w D2,D1             | data
	bra write_i2c
9:
	link A6,#-2
	lea -2(A6),A0
	move.w D2,(A0)           | data
	moveq #2,D1              | len
	bsr write_seq_device_i2c
	unlk A6
	rts
6:
	cmp.w #CT60_CLOCK_WRITE_EEPROM,D0
	bne.s 1f
	moveq #SLAVE_DS_ADDRESS,D0
	swap D0
	move.w #WRITE,D0         | address
	moveq #0,D1              | len
	lea 0,A0                 | no data
	bra write_seq_device_i2c
1:
	moveq #CT60_READ_ERROR,D0
	rts
 
_ct60_read_info_sdram:        | A0: 128 bytes buffer, D0 return error
	move.l	4(sp),a0
	moveq #SLAVE_SDRAM_ADDRESS,D0
	swap D0
	move.w #128,D1
	bra.s read_seq_device_i2c

_ct60_read_info_clock:
	move.l	4(sp),a0
	bsr	ct60_read_info_clock_orig
	rts

ct60_read_info_clock_orig:        | A0: 128 bytes buffer, D0 return error

	moveq #SLAVE_CY_SRAM_ADDRESS,D0
	swap D0
	move.w #128,D1
		 
read_seq_device_i2c:         | D0.L: address, D0.H: device, D1: len (bytes), A0: buffer, D0 return error

	movem.l D1-D4/A0-A3,-(SP) 
	move.l D0,D4
	swap D4                  | device
	move.w D1,D3             | len (bytes)
	move.l A0,A3
	move SR,-(SP)
	or #0x700,SR              | no interrupts
	lea 1f(PC),A0
	move.l 8,A1              | bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         | timer C value changed at each 26 uS (clock 19.2 KHz)
	tst.b _tbcr_mfp
	bne.s 6f                 | timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           | clock = 78.125 KHz (value changed at each 6.4 uS)
	move.b #3,_tbcr_mfp      | 2.4576MHz/16
6:
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	btst #0,D0
	beq 9f                   | SDA always at 0
	move.w D4,D0             | device
	bsr write_device_i2c
	moveq #0,D0              | write address
	bsr write_bit_i2c        | r/w
	bsr read_bit_i2c         | ack
	btst #0,D0 
	bne 3f                   | no acknoledge
	swap D4                  | address
	moveq #0,D0
	add.b D4,D4  
	addx.b D0,D0             | address 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              | 8 bits
4:
		moveq #0,D0
		add.b D4,D4  
		addx.b D0,D0         | address
		bsr write_bit_i2c
	dbf D2,4b
	bsr read_bit_i2c         | ack
	bne.s 3f                 | no acknoledge
	bsr start_bit_wait_slave_i2c
	swap D4
	move.w D4,D0             | device
	bsr write_device_i2c
	moveq #1,D0              | read data
	bsr write_bit_i2c        | r/w
	bsr read_bit_i2c         | ack
	btst #0,D0 
	bne.s 3f                 | no acknoledge
	subq.w #1,D3             | len (bytes) -1
	bpl.s 8f
	moveq #0,D3
8:
		moveq #0,D1          | data
		bsr read_bit_wait_slave_i2c  | 1st bit
		lsr.l #1,D0          | data
		addx.w D1,D1
		moveq #6,D2          | 8 bits
5:
			bsr read_bit_i2c
			lsr.l #1,D0      | data
			addx.w D1,D1
		dbf D2,5b
		move.b D1,(A3)+
		tst D3
		seq.b D0
		and #1,D0            | ack master = 1 => no other byte
		bsr write_bit_i2c
	dbf D3,8b
	bsr stop_bit_i2c
	moveq #0,D0              | OK
	bra.s 2f
3:
	bsr stop_bit_i2c
9:
	moveq #CT60_READ_ERROR,D0    | error
	bra.s 2f
1:
	moveq #CT60_READ_ERROR,D0    | bus error
	move.l A1,8
	move.l A2,SP
2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s 7f
	clr.b _tbcr_mfp          | timer B stopped
7:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D4/A0-A3
	rts

write_seq_device_i2c:        | D0.L: address, D0.H: device, D1: len (bytes), A0: buffer, D0 return error

	movem.l D1-D4/A0-A3,-(SP) 
	move.l D0,D4
	swap D4                  | device
	move.w D1,D3             | len (bytes)
	move.l A0,A3
	move SR,-(SP)
	or #0x700,SR              | no interrupts
	lea 1f(PC),A0
	move.l 8,A1              | bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         | timer C value changed at each 26 uS (clock 19.2 KHz)
	tst.b _tbcr_mfp
	bne.s 6f                 | timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           | clock = 78.125 KHz (value changed at each 6.4 uS)
	move.b #3,_tbcr_mfp      | 2.4576MHz/16
6:
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	btst #0,D0
	beq 9f                   | SDA always at 0
	move.w D4,D0             | device
	bsr write_device_i2c
	moveq #0,D0              | write address
	bsr write_bit_i2c        | r/w
	bsr read_bit_i2c         | ack
	btst #0,D0 
	bne 3f                   | no acknoledge
	swap D4                  | address
	moveq #0,D0
	add.b D4,D4  
	addx.b D0,D0             | address 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              | 8 bits
4:
		moveq #0,D0
		add.b D4,D4  
		addx.b D0,D0         | address
		bsr write_bit_i2c
	dbf D2,4b
	bsr read_bit_i2c         | ack
	bne.s 3f                 | no acknoledge
	subq.w #1,D3             | len (bytes) -1
	bmi.s 10f
8:
		move.b (A3)+,D1          | data
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0             | data 1st bit
		bsr write_bit_wait_slave_i2c
		moveq #6,D2              | 8 bits
5:
			moveq #0,D0
			add.b D1,D1  
			addx.b D0,D0         | data
			bsr write_bit_i2c
		dbf D2,5b
		bsr read_bit_i2c         | ack
	dbne D3,8b
	bne.s 3f                 | no acknoledge
10:
	bsr stop_bit_i2c
	moveq #0,D0              | OK
	bra.s 2f
3:
	bsr stop_bit_i2c
9:
	moveq #CT60_READ_ERROR,D0    | error
	bra.s 2f
1:
	moveq #CT60_READ_ERROR,D0    | bus error
	move.l A1,8
	move.l A2,SP
2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s 7f
	clr.b _tbcr_mfp          | timer B stopped
7:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D4/A0-A3
	rts

ct60_configure_sdram:

	movem.l D1-D2/A0-A1,-(SP)
	lea _sdcnf,A0
	moveq #2,D0              | memory type
	bsr read_i2c_sdram
	bmi 1f                   | error
	cmp #4,D0                | SDRAM
	beq.s 13f
	moveq #CT60_SDRAM_TYPE_ERROR,D0
	bra 1f 
13:
	moveq #3,D0              | number of row addresses
	bsr read_i2c_sdram
	bmi 1f                   | error
	move D0,D1
	moveq #4,D0              | number of column addresses
	bsr read_i2c_sdram
	bmi 1f                   | error
	lea chip_density(PC),A1
3:
	tst.w (a1)
	ble.s 2f                 | not found => chip density error
	cmp.w (A1),D1            | number of raw addresses
	bne.s 4f
	cmp.w 2(A1),D0           | number of column addresses
	beq.s 5f                 | found
4:
	addq #8,A1
	bra.s 3b
2: 
	moveq #CT60_CHIP_DENSITY_ERROR,D0
	bra 1f
5:
	add.l 4(A1),A0           | chip density on A23-A22
	moveq #12,D0             | refresh rate
	bsr read_i2c_sdram
	bmi 1f                   | error
	and.w #0x7F,D0
	cmp.w #5,D0
	bhi.s 16f                | error
	cmp.w #1,D0
	beq.s 16f                | 3.9 uS => error
	cmp.w #2,D0
	bne.s 17f
	add.l #0x10000,A0         | A16 7.81 uS
	bra.s 17f	
16:
	moveq #CT60_REFRESH_RATE_ERROR,D0
	bra 1f
17:		
	moveq #5,D0              | number of DIMM banks
	bsr read_i2c_sdram
	bmi 1f                   | error
	cmp.w #1,D0
	beq.s 6f
	cmp.w #2,D0
	bne.s 7f                 | num bank error
	add.l #0x100000,A0        | A20
	bra.s 6f
7: 
	moveq #CT60_NUM_BANK_ERROR,D0
	bra 1f
6:
	move d0,d1               | number of DIMM banks
	moveq #6,D0              | module data width
	bsr read_i2c_sdram
	bmi 1f                   | error
	cmp.w #0x40,D0
	bne.s 11f                | data width error
	moveq #7,D0              | module data width
	bsr read_i2c_sdram
	bmi 1f                   | error
	beq.s 14f
11:
	moveq #CT60_DATA_WIDTH_ERROR,D0
	bra 1f
14:
	moveq #8,D0              | voltage interface
	bsr read_i2c_sdram
	bmi 1f                   | error
	cmp.w #1,D0              | LVTTL
	beq.s 12f
	moveq #CT60_VOLTAGE_ERROR,D0
	bra.s 1f
12:
	moveq #17,D0             | number of banks on SDRAM device
	bsr read_i2c_sdram
	bmi.s 1f                 | error
	cmp.w #4,D0
	bne.s 7b                 | num bank error
	moveq #31,D0             | module density
	bsr read_i2c_sdram
	bmi.s 1f                 | error
	cmp.w #8,D0
	beq.s 10f                | 32
	cmp.w #16,D0
	beq.s 10f                | 64
	cmp.w #32,D0
	beq.s 10f                | 128
	cmp.w #64,D0
	beq.s 10f                | 256
	cmp.w #128,D0
	bne.s 8f                 | <> 512 => module density error
10:
	mulu D1,D0               | * number of DIMM banks
	asl.w #2,D0              | MB
	cmp.w #64,D0
	beq.s 9f
	cmp.w #128,D0
	beq.s 9f
	cmp.w #256,D0
	beq.s 9f
	cmp.w #512,D0
	beq.s 9f
8: 
	moveq #CT60_MOD_DENSITY_ERROR,D0
	bra.s 1f
9:
	lsr.w #7,D0
	cmp.w #3,D0
	bcs.s 15f
	moveq #3,D0
15:
	move.l D0,D1
	swap D1
	asl.l #2,D1
	add.l D1,A0              | size on A19-A18
	clr.l (A0)               | write config
	tst.l D0                 | return size 0-3 for 64MB-512MB
1:
	movem.l (SP)+,D1-D2/A0-A1
	rts
 
read_i2c_sdram:              | D0: address, D0 return data or error

	swap D0
	move.w #SLAVE_SDRAM_ADDRESS,D0
	swap D0
	bra.s read_i2c
	
read_i2c_cy_sram:            | D0: address, D0 return data or error

	swap D0
	move.w #SLAVE_CY_SRAM_ADDRESS,D0
	swap D0

read_i2c:                    | D0.L: address, D0.H: device, D0 return data or error

	movem.l D1-D3/A0-A2,-(SP)
	move.l D0,D3
	swap D3                  | device
	move SR,-(SP)
	or #0x700,SR              | no interrupts
	lea 1f(PC),A0
	move.l 8,A1              | bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         | timer C value changed at each 26 uS (clock 19.2 KHz)
	tst.b _tbcr_mfp
	bne.s 6f                 | timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           | clock = 78.125 KHz (value changed at each 6.4 uS)
	move.b #3,_tbcr_mfp      | 2.4576MHz/16
6:
	move.w D0,D1             | address
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	btst #0,D0
	beq 9f                   | SDA always at 0
	move.w D3,D0             | device
	bsr write_device_i2c
	moveq #0,D0              | write address
	bsr write_bit_i2c        | r/w
	bsr read_bit_i2c         | ack
	btst #0,D0 
	bne 3f                   | no acknoledge
	moveq #0,D0
	add.b D1,D1  
	addx.b D0,D0             | address 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              | 8 bits
4:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         | address
		bsr write_bit_i2c
	dbf D2,4b
	bsr read_bit_i2c         | ack
	bne.s 3f                 | no acknoledge
	bsr start_bit_wait_slave_i2c
	move.w D3,D0             | device
	bsr write_device_i2c
	moveq #1,D0              | read data
	bsr write_bit_i2c        | r/w
	bsr read_bit_i2c         | ack
	btst #0,D0 
	bne.s 3f                 | no acknoledge
	moveq #0,D1              | data
	bsr read_bit_wait_slave_i2c | 1st bit
	lsr.l #1,D0              | data
	addx.w D1,D1
	moveq #6,D2              | 8 bits
5:
		bsr read_bit_i2c
		lsr.l #1,D0          | data
		addx.w D1,D1
	dbf D2,5b
	moveq #1,D0              | ack master = 1 => no other byte
	bsr write_bit_i2c
	bsr stop_bit_i2c
	moveq #0,D0
	move D1,D0               | 8 bits data
	bra.s 2f
3:
	bsr stop_bit_i2c
9:
	moveq #CT60_READ_ERROR,D0    | error
	bra.s 2f
1:
	moveq #CT60_READ_ERROR,D0    | bus error
	move.l A1,8
	move.l A2,SP
2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s 7f
	clr.b _tbcr_mfp          | timer B stopped
7:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D3/A0-A2
	rts

write_i2c_cy_eeprom:         | D0: address, D1:data, D0 return data or error

	swap D0
	move.w #SLAVE_CY_EEPROM_ADDRESS,D0
	swap D0
	bra.s write_i2c
	
write_i2c_cy_sram:           | D0: address, D1:data, D0 return data or error

	swap D0
	move.w #SLAVE_CY_SRAM_ADDRESS,D0
	swap D0
 
write_i2c:                   | D0.L: address, D0.H: device, D1:data, D0 return error

	movem.l D1-D4/A0-A2,-(SP)
	move.l D0,D3
	swap D3                  | device
	move.w D1,D4             | data
	move SR,-(SP)
	or #0x700,SR              | no interrupts
	lea 1f(PC),A0
	move.l 8,A1              | bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         | timer C value changed at each 26 uS (clock 19.2 KHz)
	tst.b _tbcr_mfp
	bne.s 6f                 | timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           | clock = 78.125 KHz (value changed at each 6.4 uS)
	move.b #3,_tbcr_mfp      | 2.4576MHz/16
6:
	move D0,D1               | address
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	btst #0,D0
	beq 9f                   | SDA always at 0
	move.w D3,D0             | device
	bsr write_device_i2c
	moveq #0,D0              | write address
	bsr write_bit_i2c        | r/w
	bsr read_bit_i2c         | ack
	btst #0,D0 
	bne 3f                   | no acknoledge
	moveq #0,D0
	add.b D1,D1  
	addx.b D0,D0             | address 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              | 8 bits
4:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         | address
		bsr write_bit_i2c
	dbf D2,4b
	bsr read_bit_i2c         | ack
	bne.s 3f                | no acknoledge
	move.w D4,D1             | data
	moveq #0,D0
	add.b D1,D1  
	addx.b D0,D0             | data 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              | 8 bits
5:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         | data
		bsr write_bit_i2c
	dbf D2,5b
	bsr read_bit_i2c         | ack
	bne.s 3f                 | no acknoledge
	bsr stop_bit_i2c
	moveq #0,D0
	move.w D1,D0             | 8 bits data
	bra.s 2f
3:
	bsr stop_bit_i2c
9:
	moveq #CT60_READ_ERROR,D0    | error
	bra.s 2f
1:
	moveq #CT60_READ_ERROR,D0    | bus error
	move.l A1,8
	move.l A2,SP
2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s 7f
	clr.b _tbcr_mfp          | timer B stopped
7:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D4/A0-A2
	rts
	
write_device_i2c:            | D0: device

	movem.l D0-D2,-(SP)
	move.w D0,D1
	add.b D1,D1
	moveq #6,D2              | 7 bits 1010xxx address (SDRAM)
1:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         | device
		bsr write_bit_i2c
	dbf D2,1b
	movem.l (SP)+,D0-D2
	rts

read_bit_i2c:

	/*cmp.l #60,cpu_cookie
	bne.s read_bit_i2c_scc*/
	clr.l _sda_high          | data=1 initial state (open drain)
	WAIT_US                  | 100 KHz max !  
	clr.l _scl_high          | clk=1  
	WAIT_US
	move.l _sda,D0           | data on D0  
	clr.l _scl_low           | clk=0
	btst #0,D0
	rts
	
read_bit_i2c_scc:

	SDA_HIGH_SCC             | data=1 initial state (open drain)
	WAIT_US                  | 100 KHz max !
	SCL_HIGH_SCC             | clk=1  
	WAIT_US
	SDA_SCC
	move.w D0,-(SP)
	SCL_LOW_SCC              | clk=0
	move.w (SP)+,D0
	btst #0,D0
	rts 
 
read_bit_wait_slave_i2c:

	/*cmp.l #60,cpu_cookie
	bne read_bit_i2c_scc*/
	move.l D1,-(SP)
	clr.l _sda_high          | data=1 initial state (open drain)
	WAIT_US
	clr.l _scl_high          | clk=1 
	moveq #31,D1             | time-out slave busy
r1:
		WAIT_US              | 100 KHz max !
		move.l _sda,D0       | SCL slave on B1
		btst #1,D0
	dbne D1,r1
	move.l _sda,D0           | data on B0  
	clr.l _scl_low           | clk=0  
	move.l (SP)+,D1   
	btst #0,D0
	rts 
 
write_bit_i2c:

	/*cmp.l #60,cpu_cookie
	bne.s write_bit_i2c_scc*/
	tst.w D0
	bne.s 1f
	clr.l _sda_low           | data=0  
	bra.s 2f
1:
	clr.l _sda_high          | data=1  
2:
	WAIT_US                  | 100 KHz max !  
	clr.l _scl_high          | clk=1
	WAIT_US
	clr.l _scl_low           | clk=0  
	rts 
	
write_bit_i2c_scc:

	tst.w D0
	bne.s 1f
	SDA_LOW_SCC              | data=0  
	bra.s 2f
1:
	SDA_HIGH_SCC             | data=1  
2:
	WAIT_US                  | 100 KHz max !  
	SCL_HIGH_SCC             | clk=1
	WAIT_US
	SCL_LOW_SCC              | clk=0  
	rts 
 
write_bit_wait_slave_i2c:

	/*cmp.l #60,cpu_cookie
	bne write_bit_i2c_scc*/
	move.l D1,-(SP)
	tst.w D0
	bne.s w1
	clr.l _sda_low           | data=0  
	bra.s w2
w1:
	clr.l _sda_high          | data=1  
w2:
	WAIT_US
	clr.l _scl_high          | clk=1
	moveq #31,D1             | time-out slave busy
w3:
		WAIT_US              | 100 KHz max !  
		move.l _sda,D0       | SCL slave on B1
		btst #1,D0
	dbne D1,w3 
	clr.l _scl_low           | clk=0
	move.l (SP)+,D1  
	rts 
 
start_bit_i2c:

	/*cmp.l #60,cpu_cookie
	bne.s start_bit_i2c_scc*/
	clr.l _sda_high          | data=1 initial state
	clr.l _scl_high          | clk=1  
	WAIT_US                  | 100 KHz max !  
	clr.l _sda_low           | data=0 => start condition 
	WAIT_US
	clr.l _scl_low           | clk=0
	moveq #-1,D0
	rts
	
start_bit_i2c_scc:

	move.l D1,-(SP)
	move.b #15,0xFFFF8C85     | WR15, external status interrupt enable control
	clr.b 0xFFFF8C85          | $20 by default, CTS IE => latch !
	SDA_HIGH_SCC             | data=1 initial state
	SCL_HIGH_SCC             | clk=1  
	WAIT_US                  | 100 KHz max !
	SDA_SCC
	beq.s ss1				 | SDA always at 0
	SDA_LOW_SCC              | data=0 => start condition 
	WAIT_US
	SCL_LOW_SCC              | clk=0
	moveq #-1,D0
ss1:
	move.l (SP)+,D1
	btst #0,D0
	rts
		
start_bit_wait_slave_i2c:

	/*cmp.l #60,cpu_cookie
	bne start_bit_i2c_scc*/
	move.l D1,-(SP)
	clr.l _sda_high          | data=1 initial state
	WAIT_US                  | 100 KHz max !  
	clr.l _scl_high          | clk=1  
	moveq #31,D1             | time-out slave busy
s1:
		WAIT_US              | 100 KHz max !  
		move.l _sda,D0       | SCL slave on B1
		btst #1,D0
	dbne D1,s1  
	clr.l _sda_low           | data=0 => start condition 
	WAIT_US
	clr.l _scl_low           | clk=0
	move.l (SP)+,D1
	rts
	
stop_bit_i2c:

	/*cmp.l #60,cpu_cookie
	bne.s stop_bit_i2c_scc*/
	clr.l _sda_low           | data=0 
	WAIT_US                  | 100 KHz max !
	clr.l _scl_high          | clk=1  
	WAIT_US 
	clr.l _sda_high          | data=1 => stop condition
	WAIT_US
	rts

stop_bit_i2c_scc:

	SDA_LOW_SCC              | data=0 
	WAIT_US                  | 100 KHz max !
	SCL_HIGH_SCC             | clk=1  
	WAIT_US
	SDA_HIGH_SCC             | data=1 => stop condition
	WAIT_US
	rts

chip_density:                | A23-A22 cdy2-1

	dc.w 0x0C,0x09,0x00,0         | 8Mx8b / 8Mx16b
	dc.w 0x0C,0x0A,0x40,0         | 16Mx8b
	dc.w 0x0D,0x09,0x80,0         | 16Mx16b
	dc.w 0x0D,0x0A,0xC0,0         | 32Mx8b / 32Mx16b
	dc.w 0,0,0,0             | end

wr5_scc:	dc.w 0xEA
