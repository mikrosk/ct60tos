/*
 * fVDI console functions
 *
 * $Id: escape.c,v 1.3 2004/10/24 13:01:11 johan Exp $
 *
 * Copyright 2002-2003, Johan Klockars 
 * This software is licensed under the GNU General Public License.
 * Please, see LICENSE.TXT for further information.
 */

/*
 * Currently only works as it should when text alignment for the
 * virtual workstation is set to left/top and no rotation is set.
 *
 * The drivers should not be responsible for any alignment adjustments.
 * The colour should be passed in directly to the driver text function.
 */

#include "fvdi.h"
#include "function.h"


static long
get_colour(Virtual *vwk, long reversed)
{
   long colour = vwk->text.colour.foreground & 0xffffL;
   if (vwk->console.reversed)
      colour = (colour << 16) | (vwk->text.colour.background & 0xffffL);
   else
      colour = colour | ((long)vwk->text.colour.background << 16);
   if (reversed)
      colour = (colour << 16) | ((colour >> 16) & 0xffffL);

   return colour;
}


void
vq_chcells(Virtual *vwk, short *rows, short *columns)
{
   Workstation *wk = vwk->real_address;
   *rows    = (wk->screen.coordinates.max_x - wk->screen.coordinates.min_x + 1) /
              vwk->text.cell.width;
   *columns = (wk->screen.coordinates.max_y - wk->screen.coordinates.min_y + 1) /
              vwk->text.cell.height;
}


void
v_curup(Virtual *vwk)
{
   Workstation *wk = vwk->real_address;
   if (vwk->console.pos.y > wk->screen.coordinates.min_y + vwk->text.cell.height)
      vwk->console.pos.y -= vwk->text.cell.height;
   else
      vwk->console.pos.y = wk->screen.coordinates.min_y;
}


void
v_curdown(Virtual *vwk)
{
   Workstation *wk = vwk->real_address;
   if (vwk->console.pos.y <= wk->screen.coordinates.max_y - vwk->text.cell.height)
      vwk->console.pos.y += vwk->text.cell.height;
   else
      vwk->console.pos.y = wk->screen.coordinates.max_y + 1 - vwk->text.cell.height;
}


void
v_curright(Virtual *vwk)
{
   Workstation *wk = vwk->real_address;
   if (vwk->console.pos.x <= wk->screen.coordinates.max_x - vwk->text.cell.width)
      vwk->console.pos.x += vwk->text.cell.width;
   else
      vwk->console.pos.x = wk->screen.coordinates.max_x + 1 - vwk->text.cell.width;
}


void
v_curleft(Virtual *vwk)
{
   Workstation *wk = vwk->real_address;
   if (vwk->console.pos.x > wk->screen.coordinates.min_x + vwk->text.cell.width)
      vwk->console.pos.x += vwk->text.cell.width;
   else
      vwk->console.pos.x = wk->screen.coordinates.min_x;
}


void
v_eeol(Virtual *vwk)
{
   Workstation *wk = vwk->real_address;
   long colour = get_colour(vwk, !vwk->console.reversed);
   fill_area(vwk, vwk->console.pos.x, vwk->console.pos.y, wk->screen.coordinates.max_x,
             vwk->console.pos.y + vwk->text.cell.height - 1, colour);
}


void
v_eeos(Virtual *vwk)
{
   Workstation *wk = vwk->real_address;
   long colour = get_colour(vwk, !vwk->console.reversed);
   if (vwk->console.pos.x) {
      v_eeol(vwk);
      if (vwk->console.pos.y <= wk->screen.coordinates.max_y - vwk->text.cell.height)
         fill_area(vwk, 0, vwk->console.pos.y + vwk->text.cell.height,
                   wk->screen.coordinates.max_x,
                   wk->screen.coordinates.max_y, colour);
   } else
      fill_area(vwk, 0, vwk->console.pos.y, wk->screen.coordinates.max_x,
                wk->screen.coordinates.max_y, colour);
}


void
v_curhome(Virtual *vwk)
{
   vwk->console.pos.x = 0;
   vwk->console.pos.y = 0;
}


void
v_exit_cur(Virtual *vwk)
{
   v_curhome(vwk);
   v_eeos(vwk);
   vwk->console.cursor = 0;
}


void
v_enter_cur(Virtual *vwk)
{
   v_curhome(vwk);
   v_eeos(vwk);
   vwk->console.cursor = 1;
}


void
vs_curaddress(Virtual *vwk, long row, long column)
{
   Workstation *wk = vwk->real_address;
   short max_row, max_column;
   vq_chcells(vwk, &max_row, &max_column);
   if (row < 0)
      vwk->console.pos.y = wk->screen.coordinates.min_y;
   else if (row > max_row)
      vwk->console.pos.y = wk->screen.coordinates.max_y + 1 - vwk->text.cell.height;
   else
      vwk->console.pos.y = row * vwk->text.cell.height;
   if (column < 0)
      vwk->console.pos.x = wk->screen.coordinates.min_x;
   else if (column > max_column)
      vwk->console.pos.x = wk->screen.coordinates.max_x + 1 - vwk->text.cell.width;
   else
      vwk->console.pos.x = column * vwk->text.cell.width;
}


void
v_curtext(Virtual *vwk, short* text, long length)
{
   Workstation *wk = vwk->real_address;
   long colour = get_colour(vwk, vwk->console.reversed);
   short points[8];
   get_extent(vwk, length, text, points);
   draw_text(vwk, vwk->console.pos.x, vwk->console.pos.y, text, length, colour);
   if (vwk->console.pos.x + points[4] >= wk->screen.coordinates.max_x - vwk->text.cell.width)
      vwk->console.pos.x = wk->screen.coordinates.max_x + 1 - vwk->text.cell.width;
   else
      vwk->console.pos.x += points[4];
}


void
v_rvon(Virtual *vwk)
{
   vwk->console.reversed = 1;
}


void
v_rvoff(Virtual *vwk)
{
   vwk->console.reversed = 0;
}


void
vq_curaddress(Virtual* vwk, short *row, short *column)
{
   Workstation *wk = vwk->real_address;
   *row = (vwk->console.pos.y - wk->screen.coordinates.min_y) / vwk->text.cell.height;
   *column = (vwk->console.pos.x - wk->screen.coordinates.min_x) / vwk->text.cell.width;
}


#if 0
void
vq_tabstatus(Virtual *vwk, short *tablet)
{
   *tablet = 0;
}


void
v_hardcopy(Virtual *vwk)
{
}


void
v_dspcur(Virtual *vwk, long x, long y)
{
}


void
v_rmcur(Virtual *vwk)
{
}


void
v_form_adv(Virtual *vwk)
{
}


void
v_output_window(Virtual *vwk, long x1, long y1, long x2, long y2)
{
}


void
v_clear_display_list(Virtual *vwk)
{
}


void
v_bit_image(Virtual *vwk, char* filename, long aspect,
            long scaling, long num_pts, short points[])
{
}
#endif

