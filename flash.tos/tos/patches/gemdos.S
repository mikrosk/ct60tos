/* TOS 4.04 Gemdos Pexec patch for the CT60 board
*  Didier Mequignon 2003 March, e-mail: aniplay@wanadoo.fr
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
	
	.globl	flush_cache_pexec

	.align	2
	.long	0x1F164                /* Pexec */
	.long	end1-begin1
begin1:
	jsr	flush_cache_pexec
end1:

	.globl	det_gemdos

	.align	2
	.long	0x1DF62
	.long	end2-begin2
begin2:
	.short	0x41F9
	.long	det_gemdos
end2:

	.globl	det_vbl

	.align	2
	.long	0x214
	.long	end3-begin3
begin3:
	move.l	#det_vbl,0x70.w
end3:



