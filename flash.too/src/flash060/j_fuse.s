;  Didier Mequignon 2003 February, e-mail: didier-mequignon@wanadoo.fr
;                            
;  This program is free software; you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation; either version 2 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program; if not, write to the Free Software
;  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

	.export jedec_get_fuse
	.export jedec_set_fuse

jedec_get_fuse:

	move.l (A0),A0
	bfextu (A0){D0:1},D0
	rts

jedec_set_fuse:

	move.l (A0),A0
	bfins D1,(A0){D0:1}
	rts
	
	end
