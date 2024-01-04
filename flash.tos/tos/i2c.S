/* CT60 I2C routines
 * Didier Mequignon 2001-2010, e-mail: aniplay@wanadoo.fr
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


#define _gpip_mfp 0xfffffa01
#define _ddr_mfp  0xfffffa05
#define _iera_mfp 0xfffffa07      // MFP registers
#define _ipra_mfp 0xfffffa0b
#define _isra_mfp 0xfffffa0f
#define _imra_mfp 0xfffffa13
#define _tbcr_mfp 0xfffffa1b
#define _tbdr_mfp 0xfffffa21      // timer B
#define _tcdr_mfp 0xfffffa23      // timer C
#define _scl_low  0xf0000000      // write 0 to SCL line (clock)
#define _scl_high 0xf0400000      // write 1 to SCL line (clock)
#define _sda_low  0xf0800000      // write 0 to SDA line (data)
#define _sda_high 0xf0c00000      // write 1 to SDA line (data) 
#define _sda      0xf0000000      // read from SDA line on the D0 CPU data bus

#define CT60_READ_ERROR -1

#define  WAIT_US bsr wait_26us  

	.globl read_seq_device_i2c
	.globl write_seq_device_i2c 
	.globl read_i2c
	.globl write_i2c
	
	.text

read_seq_device_i2c:         // D0.L: address, D0.H: device, D1: len (bytes), A0: 128 bytes buffer, D0 return error

	movem.l D1-D4/A0-A3,-(SP) 
	move.l D0,D4
	swap D4                  // device
	move.w D1,D3             // len (bytes)
	move.l A0,A3
	move SR,-(SP)
	or #0x700,SR             // no interrupts
	lea .ri1(PC),A0
	move.l 8,A1              // bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         // timer C value changed at each 26 uS (clock 19.2 KHz)
	tst.b _tbcr_mfp
	bne.s .ri6               // timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           // clock = 78.125 KHz (value changed at each 6.4 uS)
	move.b #3,_tbcr_mfp      // 2.4576MHz/16
.ri6:
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	move.w D4,D0             // device
	bsr write_device_i2c
	moveq #0,D0              // write address
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne .ri3                 // no acknoledge
	swap D4                  // address
	moveq #0,D0
	add.b D4,D4  
	addx.b D0,D0             // address 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              // 8 bits
.ri4:
		moveq #0,D0
		add.b D4,D4  
		addx.b D0,D0         // address
		bsr write_bit_i2c
	dbf D2,.ri4
	bsr read_bit_i2c         // ack
	bne.s .ri3               // no acknoledge
	bsr start_bit_wait_slave_i2c
	swap D4
	move.w D4,D0             // device
	bsr write_device_i2c
	moveq #1,D0              // read data
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne.s .ri3               // no acknoledge
	subq.w #1,D3             // len (bytes) -1
	bpl.s .ri8
	moveq #0,D3
.ri8:
		moveq #0,D1          // data
		bsr read_bit_wait_slave_i2c  // 1st bit
		lsr.l #1,D0          // data
		addx.w D1,D1
		moveq #6,D2          // 8 bits
.ri5:
			bsr read_bit_i2c
			lsr.l #1,D0      // data
			addx.w D1,D1
		dbf D2,.ri5
		move.b D1,(A3)+
		tst D3
		seq.b D0
		and #1,D0            // ack master = 1 => no other byte
		bsr write_bit_i2c
	dbf D3,.ri8
	bsr stop_bit_i2c
	moveq #0,D0                  //  OK
	bra.s .ri2
.ri3:
	bsr stop_bit_i2c
	moveq #CT60_READ_ERROR,D0    // error
	bra.s .ri2
.ri1:
	moveq #CT60_READ_ERROR,D0    // bus error
	move.l A1,8
	move.l A2,SP
.ri2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s .ri7
	clr.b _tbcr_mfp          // timer B stopped
.ri7:
	move.w (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D4/A0-A3
	rts
	
write_seq_device_i2c:        // D0.L: address, D0.H: device, D1: len (bytes), A0: buffer, D0 return error

	movem.l D1-D4/A0-A3,-(SP) 
	move.l D0,D4
	swap D4                  // device
	move.w D1,D3             // len (bytes)
	move.l A0,A3
	move SR,-(SP)
	or #0x700,SR             // no interrupts
	lea .wi1(PC),A0
	move.l 8,A1              // bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         // timer C value changed at each 26 uS (clock 19.2 KHz)
	tst.b _tbcr_mfp
	bne.s .wi6               // timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           // clock = 78.125 KHz (value changed at each 6.4 uS)
	move.b #3,_tbcr_mfp      // 2.4576MHz/16
.wi6:
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	move.w D4,D0             // device
	bsr write_device_i2c
	moveq #0,D0              // write address
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne .wi3                 // no acknoledge
	swap D4                  // address
	moveq #0,D0
	add.b D4,D4  
	addx.b D0,D0             // address 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              // 8 bits
.wi4:
		moveq #0,D0
		add.b D4,D4  
		addx.b D0,D0         // address
		bsr write_bit_i2c
	dbf D2,.wi4
	bsr read_bit_i2c         // ack
	bne.s .wi3               // no acknoledge
	subq.w #1,D3             // len (bytes) -1
	bmi.s .wi10
.wi8:
		move.b (A3)+,D1          // data
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0             // data 1st bit
		bsr write_bit_wait_slave_i2c
		moveq #6,D2              // 8 bits
.wi5:
			moveq #0,D0
			add.b D1,D1  
			addx.b D0,D0         // data
			bsr write_bit_i2c
		dbf D2,.wi5
		bsr read_bit_i2c         // ack
	dbne D3,.wi8
	bne.s .wi3               // no acknoledge
.wi10:
	bsr stop_bit_i2c
	moveq #0,D0              // OK
	bra.s .wi2
.wi3:
	bsr stop_bit_i2c
.wi9:
	moveq #CT60_READ_ERROR,D0    // error
	bra.s .wi2
.wi1:
	moveq #CT60_READ_ERROR,D0    // bus error
	move.l A1,8
	move.l A2,SP
.wi2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s .wi7
	clr.b _tbcr_mfp          // timer B stopped
.wi7:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D4/A0-A3
	rts

read_i2c:                    // D0.L: address, D0.H: device, D0 return data or error

	movem.l D1-D3/A0-A2,-(SP)
	move.l D0,D3             // device
	swap D3
	move SR,-(SP)
	or #0x700,SR             // no interrupts
	lea .r1(PC),A0
	move.l 8,A1              // bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         // timer C value changed at each 26 uS (clock 19.2 KHz)
	tst.b _tbcr_mfp
	bne.s .r6                // timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           // clock = 78.125 KHz (value changed at each 6.4 uS)
	move.b #3,_tbcr_mfp      // 2.4576MHz/16
.r6:
	move.w D0,D1             // address
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	move.w D3,D0             // device
	bsr write_device_i2c
	moveq #0,D0              // write address
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne .r3                  // no acknoledge
	moveq #0,D0
	add.b D1,D1  
	addx.b D0,D0             // address 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              // 8 bits
.r4:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         // address
		bsr write_bit_i2c
	dbf D2,.r4
	bsr read_bit_i2c         // ack
	bne.s .r3                // no acknoledge
	bsr start_bit_wait_slave_i2c
	move.w D3,D0             // device
	bsr write_device_i2c
	moveq #1,D0              // read data
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne.s .r3                // no acknoledge
	moveq #0,D1              // data
	bsr read_bit_wait_slave_i2c // 1st bit
	lsr.l #1,D0              // data
	addx.w D1,D1
	moveq #6,D2              // 8 bits
.r5:
		bsr read_bit_i2c
		lsr.l #1,D0          // data
		addx.w D1,D1
	dbf D2,.r5
	moveq #1,D0              // ack master = 1 => no other byte
	bsr write_bit_i2c
	bsr stop_bit_i2c
	moveq #0,D0
	move.w D1,D0             // 8 bits data
	bra.s .r2
.r3:
	bsr stop_bit_i2c
	moveq #CT60_READ_ERROR,D0    // error
	bra.s .r2
.r1:
	moveq #CT60_READ_ERROR,D0    // bus error
	move.l A1,8
	move.l A2,SP
.r2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s .r7
	clr.b _tbcr_mfp          // timer B stopped
.r7:
	move.w (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D3/A0-A2
	rts
	
write_i2c:                   // D0.L: address, D0.H: device, D1:data, D0 return error

	movem.l D1-D4/A0-A2,-(SP)
	move.l D0,D3             // device
	swap D3
	move.w D1,D4             // data
	move SR,-(SP)
	or #0x700,SR             // no interrupts
	lea .w1(PC),A0
	move.l 8,A1              // bus error
	move.l A0,8
	move.l SP,A2
	lea _tcdr_mfp,A0         // timer C value changed at each 26 uS (clock 19.2 KHz)
	tst.b _tbcr_mfp
	bne.s .w6                // timer B used
	bclr #0,_imra_mfp
	bclr #0,_iera_mfp
	bclr #0,_ipra_mfp
	bclr #0,_isra_mfp    
	lea _tbdr_mfp,A0 
	move.b #2,(A0)           // clock = 78.125 KHz (value changed at each 6.4 uS)
	move.b #3,_tbcr_mfp      // 2.4576MHz/16
.w6:
	move.w D0,D1             // address
	bsr start_bit_i2c
	move.l A1,8
	move.l A2,SP
	move.w D3,D0             // device
	bsr write_device_i2c
	moveq #0,D0              // write address
	bsr write_bit_i2c        // r/w
	bsr read_bit_i2c         // ack
	btst #0,D0 
	bne .w3                  // no acknoledge
	moveq #0,D0
	add.b D1,D1  
	addx.b D0,D0             // address 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              // 8 bits
.w4:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         // address
		bsr write_bit_i2c
	dbf D2,.w4
	bsr read_bit_i2c         // ack
	bne.s .w3                // no acknoledge
	move.w D4,D1             // data
	moveq #0,D0
	add.b D1,D1  
	addx.b D0,D0             // data 1st bit
	bsr write_bit_wait_slave_i2c
	moveq #6,D2              // 8 bits
.w5:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         // data
		bsr write_bit_i2c
	dbf D2,.w5
	bsr read_bit_i2c         // ack
	bne.s .w3                // no acknoledge
	bsr stop_bit_i2c
	moveq #0,D0
	move.w D1,D0              // 8 bits data
	bra.s .w2
.w3:
	bsr stop_bit_i2c
	moveq #CT60_READ_ERROR,D0    // error
	bra.s .w2
.w1:
	moveq #CT60_READ_ERROR,D0    // bus error
	move.l A1,8
	move.l A2,SP
.w2:
	lea _tbdr_mfp,A1
	cmp.l A0,A1
	bne.s .w7
	clr.b _tbcr_mfp          // timer B stopped
.w7:
	move (SP)+,SR
	tst.l D0
	movem.l (SP)+,D1-D4/A0-A2
	rts

write_device_i2c:            // D0: device

	movem.l D0-D2,-(SP)
	move.w D0,D1
	add.b D1,D1
	moveq #6,D2              // 7 bits 1010xxx (SDRAM)
.wd1:
		moveq #0,D0
		add.b D1,D1  
		addx.b D0,D0         // device
		bsr write_bit_i2c
	dbf D2,.wd1
	movem.l (SP)+,D0-D2
	rts

read_bit_i2c:

	clr.l _sda_high          // data=1 initial state (open drain)
	WAIT_US                  // 100 KHz max !  
	clr.l _scl_high          // clk=1  
	WAIT_US
	move.l _sda,D0           // data on D0  
	clr.l _scl_low           // clk=0
	btst #0,D0
	rts 
 
read_bit_wait_slave_i2c:

	move.l D1,-(SP)
	clr.l _sda_high          // data=1 initial state (open drain)
	WAIT_US
	clr.l _scl_high          // clk=1 
	moveq #31,D1             // time-out slave busy
.rs1:
		WAIT_US              // 100 KHz max !
		move.l _sda,D0       // SCL slave on B1
		btst #1,D0
	dbne D1,.rs1
	move.l _sda,D0           // data on B0  
	clr.l _scl_low           // clk=0  
	move.l (SP)+,D1   
	btst #0,D0
	rts 
 
write_bit_i2c:

	tst.w D0
	bne.s .wb1
	clr.l _sda_low           // data=0  
	bra.s .wb2
.wb1:
	clr.l _sda_high          // data=1  
.wb2:
	WAIT_US                  // 100 KHz max !  
	clr.l _scl_high          // clk=1
	WAIT_US
	clr.l _scl_low           // clk=0  
	rts 
 
write_bit_wait_slave_i2c:

	move.l D1,-(SP)
	tst.w D0
	bne.s .ws1
	clr.l _sda_low           // data=0  
	bra.s .ws2
.ws1:
	clr.l _sda_high          // data=1  
.ws2:
	WAIT_US
	clr.l _scl_high          // clk=1
	moveq #31,D1             // time-out slave busy
.ws3:
		WAIT_US              // 100 KHz max !  
		move.l _sda,D0       // SCL slave on B1
		btst #1,D0
	dbne D1,.ws3 
	clr.l _scl_low           // clk=0
	move.l (SP)+,D1  
	rts 
 
start_bit_i2c:

	clr.l _sda_high          // data=1 initial state
	clr.l _scl_high          // clk=1  
	WAIT_US                  // 100 KHz max !  
	clr.l _sda_low           // data=0 => start condition 
	WAIT_US
	clr.l _scl_low           // clk=0
	rts

start_bit_wait_slave_i2c:

	move.l D1,-(SP)
	clr.l _sda_high          // data=1 initial state
	WAIT_US                  // 100 KHz max !  
	clr.l _scl_high          // clk=1  
	moveq #31,D1             // time-out slave busy
.s1:
		WAIT_US              // 100 KHz max !  
		move.l _sda,D0       // SCL slave on B1
		btst #1,D0
	dbne D1,.s1  
	clr.l _sda_low           // data=0 => start condition 
	WAIT_US
	clr.l _scl_low           // clk=0
	move.l (SP)+,D1
	rts
 
stop_bit_i2c:

	clr.l _sda_low           // data=0 
	WAIT_US                  // 100 KHz max !
	clr.l _scl_high          // clk=1  
	WAIT_US 
	clr.l _sda_high          // data=1 => stop condition
	WAIT_US
	rts

wait_26us:                            // 26uS (timer C) or 6.5uS (timer B)

	move.b (A0),D0
.wu1:
	cmp.b (A0),D0       
	beq.s .wu1
	rts

