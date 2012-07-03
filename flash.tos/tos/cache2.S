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

#ifdef COLDFIRE
#include "fire.h"

	.globl caches_disable
	.globl caches_enable
#endif
	.globl fix_bug_nvdi

fix_bug_nvdi:

	move.l _v_bas_ad,D0
	cmp.l #0x01000000,D0
	bcc.s .normal_v_opnwk
#ifdef COLDFIRE
	.chip 68060
	movec.l CACR,D0
	.chip 5200
#else
	movec.l CACR,D0
#endif
	move.l D0,-(SP)
#ifdef COLDFIRE
	jsr caches_disable
#else
	jsr 0xE0085A             // caches off
#endif
	moveq #3,D0
	jsr 0xE34348             // v_opnwk
#ifdef COLDFIRE
	move.l #CACHE_ENABLE_MODE,D0
	cmp.l (SP)+,D0
#else
	cmp.l #0xA0808000,(SP)+
#endif
	bne.s .no_caches	
#ifdef COLDFIRE
	jsr caches_enable
#else
	jsr 0xE250C8             // caches on
#endif
.no_caches:
	rts
.normal_v_opnwk:
	moveq #3,D0
	jmp 0xE34348             // v_opnwk
