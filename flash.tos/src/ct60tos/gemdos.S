/* TOS 4.04 Gemdos Pexec patch for the CT60 board
*  Didier Mequignon 2003 March, e-mail: didier-mequignon@wanadoo.fr
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
	.long	end1-begin1+0x80000000
begin1:
	jsr	flush_cache_pexec
end1:
