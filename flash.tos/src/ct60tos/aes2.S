/* TOS 4.04 AES patch for Eiffel POWER OFF alert for the CT60 board
*  Didier Mequignon 2004 February, e-mail: aniplay@wanadoo.fr
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

	.globl det_evnt_multi
	
#include "vars.h"

alert_power_en:
	.asciz "[2][ |Do you want cut the|power of your computer?][Yes|No]" 

alert_power_fr:
	.asciz "[2][ |Voulez vous ‚teindre|votre ordinateur ?][Oui|Non]" 
	
	.align 2	

det_evnt_multi:

	move.l phystop,A1
	cmp.l #0xCAFEFADE,power_flag(A1)
	bne.s .no_power_off
	clr.l power_flag(A1)
	movem.l D0-A5,-(SP)
	link A6,#-48
	pea.l -48(A6)                                       // buffer
	move.w #48,-(SP)                                    // size
	clr.w -(SP)                                         // start
	clr.w -(SP)                                         // read
	move.w #46,-(SP)                                    // NVMaccess
	trap #14
	lea.l 12(SP),SP
	lea.l -48(A6),A0                                    // buffer
	move.b 6(A0),D0                                     // language
	unlk A6
	lea.l alert_power_en(PC),A0
	cmp.b #2,D0                                         // french
	bne.s .no_french
	lea.l alert_power_fr(PC),A0	
.no_french:                                      
	pea.l (A0)
	move.w #1,-(SP)
	jsr 0xE22A68                                        // form_alert
	addq.l #6,SP
	cmp.w #1,D0                                         // delay
	bne.s .cancel
	clr.b 0xFA800000                                    // power off
	dc.w 0xF800,0x01C0,0x2700		
.cancel:
	movem.l (SP)+,D0-A5
.no_power_off:
	swap D0
	clr.w D0
	swap D0
	rts
