/*  TOS 4.04 patch for the CT60 board
 *  Copyright (C) 2001 Xavier Joubert
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
 *
 *
 *  To contact author write to Xavier Joubert, 5 Cour aux Chais, 44 100 Nantes,
 *  FRANCE or by e-mail to xavier.joubert@free.fr.
 *
 */

	.MACRO	periph	adr
	.align	2
	.long	\adr
	.long	2
	.word	0xFFFF
	.ENDM

	.text

	periph	0x6242
	periph	0x6248
	periph	0x624E
	periph	0x625A
	periph	0x6276
	periph	0x627C
	periph	0x6282
	periph	0x628E
	periph	0x62A8
	periph	0x62AE
	periph	0x62B6
	periph	0x62D2
	periph	0x62D8
	periph	0x62E0
	periph	0x62FC
	periph	0x6302
	periph	0x630A
	periph	0x6326
	periph	0x632C
	periph	0x6334
	periph	0x634C
	periph	0x6352
	periph	0x635A
	periph	0x63A6
	periph	0x63B2
	periph	0x63BE
	periph	0x63C8
	periph	0x63D2
	periph	0x63DC
	periph	0x63E6
	periph	0x63F0
	periph	0x6402
	periph	0x6408
	periph	0x641A
	periph	0x6420
	periph	0x642E
	periph	0x6434
	periph	0x6448
	periph	0x644E
	periph	0x6458
	periph	0x647C
	periph	0x6494
	periph	0x64A0
	periph	0x64B0
	periph	0x64BC
	periph	0x64DE
	periph	0x64E8
	periph	0x64FC
	periph	0x652A
	periph	0x653C
	periph	0x6550
	periph	0x6556
	periph	0x655E
	periph	0x656E
	periph	0x6580
	periph	0x6586
	periph	0x658E
	periph	0x659E
	periph	0x65B0
	periph	0x65B6
	periph	0x65BE
	periph	0x65CE
	periph	0x65E0
	periph	0x65E8
	periph	0x65FE
	periph	0x6606
	periph	0x6616
	periph	0x661C
	periph	0x6622
	periph	0x66C2
	periph	0x66DC
	periph	0x66E4
	periph	0x66EA
	periph	0x66F8
	periph	0x670C
	periph	0x6714
	periph	0x671C
	periph	0x6724
	periph	0x672C
	periph	0x6736
	periph	0x6742
	periph	0x674A
	periph	0x6762
	periph	0x679C
	periph	0x67AA
	periph	0x67BA
	periph	0x67CA
	periph	0x67DA
	periph	0x67FA
	periph	0x6800
	periph	0x6806
	periph	0x680C
	periph	0x6822
	periph	0x6828
	periph	0x682E
	periph	0x6834
	periph	0xD156
	periph	0x11908
	periph	0x11970
	periph	0x11AB0
	periph	0x11AE4
	periph	0x11B00
	periph	0x11BDE
	periph	0x11C7C
	periph	0x11D68
	periph	0x12876
	periph	0x12A10
	periph	0x12C86
	periph	0x12D1E
	periph	0x12D88
	periph	0x12E10
	periph	0x12EB8
	periph	0x12EFC
	periph	0x12F3E
	periph	0x12FCE
	periph	0x13060
	periph	0x1308E
	periph	0x130EE
	periph	0x1313A
	periph	0x131AE
	periph	0x131B6
	periph	0x13498
	periph	0x134D0
	periph	0x1354C
	periph	0x1357A
	periph	0x174CA
	periph	0x1762E
	periph	0x17AC4
