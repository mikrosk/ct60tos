/* TOS 4.04 patch for the Fire Engine Coldfire board
*  Didier Mequignon 2006, e-mail: aniplay@wanadoo.fr
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

#include "fire.h"

	.text
	
	.globl	replace_mfp

	.align	2
	.long	0x526
	.long	end1-begin1
begin1:
	jsr	replace_mfp
	nop
 	// tempo 5 mS MFP
	nop
	nop
end1:

	.globl	int_timer_c_mfp

	.align	2
	.long	0x3C50 
	.long	end2-begin2
begin2:	jmp	int_timer_c_mfp
end2:

	.globl	tempo_reset_ikbd

	.align	2
	.long	0x544
	.long	end3-begin3
begin3: 	// tempo 20mS *15 MFP after IKBD reset
	jsr	tempo_reset_ikbd
	nop
	nop
	nop
	nop
	nop
end3:

	.align	2
	.long	0x62E
	.long	end4-begin4
begin4:
	nop
	nop
end4:

