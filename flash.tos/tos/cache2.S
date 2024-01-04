/*
*  Didier Mequignon 2001-2010, e-mail: aniplay@wanadoo.fr
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

#include "vars.h"

	.globl fix_bug_nvdi

fix_bug_nvdi:

	move.l _v_bas_ad,D0
	cmp.l #0x01000000,D0
	bcc.s .normal_v_opnwk
	movec.l CACR,D0
	move.l D0,-(SP)
	jsr 0xE0085A             // caches off
	moveq #3,D0
	jsr 0xE34348             // v_opnwk
	cmp.l #0xA0808000,(SP)+
	bne.s .no_caches	
	jsr 0xE250C8             // caches on
.no_caches:
	rts
.normal_v_opnwk:
	moveq #3,D0
	jmp 0xE34348             // v_opnwk
