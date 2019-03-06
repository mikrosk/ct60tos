#include "targa.h"

#define alpha_composite(composite, fg, alpha) {						\
    unsigned short temp = ((unsigned short)( fg) * (unsigned short)( alpha) + ( unsigned short)128);	\
    (composite) = (unsigned char)((temp + (temp >> 8)) >> 8);				\
}

static unsigned char *unpack_line1(tga_pic *tga_struct, unsigned char *src, unsigned char *dst, unsigned short line_width);
static int fill_img_buf(tga_pic *tga_struct, long read);
static int unpack_line(tga_pic *tga_struct, unsigned char *dst);

int read_tga(unsigned char *dest, unsigned char *source, long size_source);

void mem_cpy(unsigned char *dest,unsigned char *source,long size)
{
	while(--size>=0)
		*dest++ = *source++;
}

/*==================================================================================*
 * void tga_write_pixel_to_mem:														*
 *		Write the pixel to the data regarding how the header says the data 			*
 *		is ordered.																	*
 *----------------------------------------------------------------------------------*
 * input:																			*
 *		dst				->	the pixel is wrote here.								*
 *		orientation 	->	the pixel orientation ( from TGA header).				*
 *		pixel_position	->	the pixel position in the x axis.						*
 *		width			->	the image's width.										*
 *		pixel			->	the 24 bits pixel to write.								*
 *----------------------------------------------------------------------------------*
 * return:	 																		*
 *      --																			*
 *==================================================================================*/
static inline void tga_write_pixel_to_mem(unsigned char *dst, unsigned char orientation, unsigned short pixel_position, unsigned short width, unsigned char *rgb) 
{
    register unsigned short x, addy;

    switch(orientation) 
	{
	    case TGA_UPPER_LEFT:
	    case TGA_LOWER_LEFT:
	    default:
	        x = pixel_position % width;
			break;

	    case TGA_LOWER_RIGHT:
	    case TGA_UPPER_RIGHT:
	        x = width - 1 - ( pixel_position % width);
	        break;
    }

    addy = x * 3;

	dst[addy++] = rgb[0];
    dst[addy++] = rgb[1];
    dst[addy] 	= rgb[2];
}


/*==================================================================================*
 * unsigned long tga_convert_color:													*
 *		Write the pixel to the data regarding how the header says the data 			*
 *		is ordered.																	*
 *----------------------------------------------------------------------------------*
 * input:																			*
 *		rgb				->	bgra value.												*
 *		bpp_in			->	original image bitplanes.								*
 *		alphabits		->	Alpha bit... 1 if present else 0.						*
 *----------------------------------------------------------------------------------*
 * return:	 																		*
 *      the converted pixel.														*
 *==================================================================================*/
static inline void tga_convert_color(unsigned char *bgra, unsigned char *rgb, unsigned char bpp_in, unsigned char alphabits)
{
    unsigned char r=0, g=0, b=0, a=0;

    switch(bpp_in) 
	{
	    case 32:
	    case 24:
			if(alphabits)
			{
				/* not premultiplied alpha -- multiply. */
				a =  bgra[3];
				alpha_composite(r, bgra[2], a);
				alpha_composite(g, bgra[1], a);
				alpha_composite(b, bgra[0], a);
		    }
			else
			{
				r = bgra[2];
				g = bgra[1];
				b = bgra[0];
		    }		
	        break;
 
	    case 16:
		case 15:
			{
		        /* 16-bit to 32-bit; (force alpha to full) */
				register unsigned short src16 = (( ( unsigned short)bgra[1] << 8) | bgra[0]);
		        b = ((src16)       & 0x001F) << 3;
		        g = ((src16 >> 5)  & 0x001F) << 3;
		        r = ((src16 >> 10) & 0x001F) << 3; 
		        break;
		    }
	}

	rgb[0] = r;
	rgb[1] = g;
	rgb[2] = b;
}

/*==================================================================================*
 * int  fill_img_buf:																*
 *	    fill the buffer "tga_struct->img_buf" with a line from source buffer.	 	*		*
 *		the buffer can contain 2 lines, this function search also where write the	*
 *		new line from the source buffer.											*			*
 *----------------------------------------------------------------------------------*
 * input:																			*
 *		tga_struct		->	tga_pic struct. with all the wanted information.		*
 *		read		 	->	internal counter.										*
 *----------------------------------------------------------------------------------*
 * return:	 																		*
 *      Always 1 (need to code something more secure)								*
 *==================================================================================*/
static int fill_img_buf(tga_pic *tga_struct, long read)
{	
	tga_struct->img_buf_used -= read;									
	tga_struct->img_buf_offset += read;								
	
	if(tga_struct->img_buf_offset >= (tga_struct->img_buf_len >> 1))	
	{
		if(tga_struct->img_buf_used > 0)
			mem_cpy(tga_struct->img_buf, tga_struct->img_buf + tga_struct->img_buf_offset, tga_struct->img_buf_used);	
		
		read = tga_struct->img_buf_offset;								

		if(read > tga_struct->rest_length )								
			read = tga_struct->rest_length;

		mem_cpy(tga_struct->img_buf + tga_struct->img_buf_used,tga_struct->ptr_source,read);
		tga_struct->ptr_source += read;

		tga_struct->img_buf_used += read;									
		tga_struct->img_buf_offset = 0;										
		tga_struct->rest_length -= read;
	}

	return(1);
}


/*==================================================================================*
 * unsigned char *unpack_line1:														*		*
 *		depack (for RLE image) and copy data from source to destination. 			*
 *----------------------------------------------------------------------------------*
 * input:																			*
 *		tga_struct	->	tga_pic struct. with all the wanted information.			*
 *		src		 	->	the source buffer.											*
 *		dst		 	->	the destination buffer.										*
 *		line_width	->	the image width.											*
 *----------------------------------------------------------------------------------*
 * return:	 																		*
 *      Howmany source buffer position after that the job is done.					*
 *==================================================================================*/
static unsigned char *unpack_line1(tga_pic *tga_struct, unsigned char *src, unsigned char *dst, unsigned short line_width)
{
	register unsigned short i, j, bytes_per_pix = (short)tga_struct->bytes_per_pix;
	unsigned char	bgra[4], rgb[3], packet_header, repcount;

    if(tga_struct->tga.image_type == TGA_IMG_UNC_TRUECOLOR) 
	{
		for(i=0; i<line_width; i++)
		{
			for(j=0; j<bytes_per_pix; j++)
				bgra[j] = *src++;

 	       	tga_convert_color( &bgra[0], &rgb[0], tga_struct->tga.img_spec_pix_depth, tga_struct->alphabits);
           	tga_write_pixel_to_mem( dst, tga_struct->orientation, i, line_width, &rgb[0]);
		}
	}
	else
	{
		register unsigned short l;

        for(i=0; i<line_width; ) 
		{
			packet_header = *src++;

            if(packet_header & 0x80 ) 
			{

				for(j=0; j<bytes_per_pix; j++)
					bgra[j] = *src++;

				tga_convert_color( &bgra[0], &rgb[0], tga_struct->tga.img_spec_pix_depth, tga_struct->alphabits);

                repcount = (packet_header & 0x7F) + 1;
                
                /* write all the data out */
                for(j=0; j<repcount; j++ ) 
                    tga_write_pixel_to_mem( dst, tga_struct->orientation, i + j, line_width, &rgb[0]);

                i += repcount;
            } 
			else 
			{
                repcount = (packet_header & 0x7F) + 1;
               
                for(l=0; l<repcount; l++) 
				{
					for(j=0; j<bytes_per_pix; j++)
						bgra[j] = *src++;

					tga_convert_color( &bgra[0], &rgb[0], tga_struct->tga.img_spec_pix_depth, tga_struct->alphabits);

					tga_write_pixel_to_mem( dst, tga_struct->orientation, i + l, line_width, &rgb[0]);
                }

                i += repcount;
        	}
		}
	}

	return(src);
}


/*==================================================================================*
 * int  unpack_line:																*
 *		Call the "source's buffer to destination's buffer" and						* 
 *		"image to source's buffer" functions. 										*
 *----------------------------------------------------------------------------------*
 * input:																			*
 *		tga_struct	->	tga_pic struct. with all the wanted information.			*
 *		dst		 	->	the destination buffer.										*
 *----------------------------------------------------------------------------------*
 * return:	 																		*
 *      1 if ok else 0.																*
 *==================================================================================*/
static int unpack_line(tga_pic *tga_struct, unsigned char *dst)
{
	unsigned char		*line_begin;
	long		read;

	line_begin = tga_struct->img_buf + tga_struct->img_buf_offset;
	read = (long)(unpack_line1(tga_struct, line_begin, dst, (unsigned short)tga_struct->tga.img_spec_width) - line_begin);
	return(fill_img_buf(tga_struct, read));
}


/*==================================================================================*
 * int  read_tga:																    *
 *		Decompress the "source's buffer to destination's buffer"                    *
 *----------------------------------------------------------------------------------*
 * input:																			*
 *		source	->	tga picture.		                                            *
 *		dest	->	the destination buffer.										    *
 *----------------------------------------------------------------------------------*
 * return:	 																		*
 *      1/-1 if ok (orientation) else 0.																*
 *==================================================================================*/
int read_tga(unsigned char *dest, unsigned char *source, long size_source)
{
	tga_pic		tga_struct;
	unsigned char buffer_line[4096];
	unsigned short y;
	
	/* byte order is important here. */
	tga_struct.tga.idlen				= source[0];
	tga_struct.tga.cmap_type			= source[1];
	tga_struct.tga.image_type			= source[2];
	tga_struct.tga.cmap_first			= (unsigned short)source[3]  + ((unsigned short)source[4] << 8);
	tga_struct.tga.cmap_length			= (unsigned short)source[5]  + ((unsigned short)source[6] << 8);
	tga_struct.tga.cmap_entry_size		= source[7];
	tga_struct.tga.img_spec_xorig		= (unsigned short)source[8]  + ((unsigned short)source[9]  << 8);
	tga_struct.tga.img_spec_yorig		= (unsigned short)source[10] + ((unsigned short)source[11] << 8);
	tga_struct.tga.img_spec_width		= (unsigned short)source[12] + ((unsigned short)source[13] << 8);
	tga_struct.tga.img_spec_height		= (unsigned short)source[14] + ((unsigned short)source[15] << 8);
	tga_struct.tga.img_spec_pix_depth	= source[16];
	tga_struct.tga.img_spec_img_desc	= source[17];
	
	source += (HDR_LENGTH + tga_struct.tga.idlen);

	if(tga_struct.tga.img_spec_width == 0
	 || tga_struct.tga.img_spec_height == 0)
		return(0);	
	
	tga_struct.alphabits   = tga_struct.tga.img_spec_img_desc & 0x0F;
	tga_struct.ptr_source  = source;
    
	/* if the image type is not supported, just jump out. */
	if(tga_struct.tga.image_type != TGA_IMG_UNC_TRUECOLOR
	 && tga_struct.tga.image_type != TGA_IMG_RLE_TRUECOLOR)
		return(0);	

	/* compute number of bytes in an image data unit (either index or BGR triple) */
	if(tga_struct.tga.img_spec_pix_depth & 0x07)
		tga_struct.bytes_per_pix = (((8 - (tga_struct.tga.img_spec_pix_depth & 0x07)) + tga_struct.tga.img_spec_pix_depth) >> 3);
	else
		tga_struct.bytes_per_pix = (tga_struct.tga.img_spec_pix_depth >> 3);

	/* assume that there's one byte per pixel */
	if(tga_struct.bytes_per_pix == 0 )
		tga_struct.bytes_per_pix = 1;

	tga_struct.line_size = tga_struct.tga.img_spec_width * tga_struct.bytes_per_pix;
	tga_struct.img_buf_len = tga_struct.line_size << 1;

	tga_struct.img_buf = buffer_line; /* size = tga_struct.img_buf_len + 256L */

	tga_struct.orientation = (tga_struct.tga.img_spec_img_desc & 0x30) >> 4;
	tga_struct.rest_length = size_source - (HDR_LENGTH + tga_struct.tga.idlen);

	if(tga_struct.img_buf_len > tga_struct.rest_length)						
		tga_struct.img_buf_len = tga_struct.rest_length;	

	tga_struct.img_buf_offset = 0;	
	tga_struct.img_buf_used	= tga_struct.img_buf_len;
	mem_cpy(tga_struct.img_buf, tga_struct.ptr_source, tga_struct.img_buf_len);	
	tga_struct.ptr_source  += tga_struct.img_buf_len;
	tga_struct.rest_length -= tga_struct.img_buf_used;

	y=0;
	while(y < tga_struct.tga.img_spec_height)
	{
		if(unpack_line(&tga_struct, dest))
		{
			dest += (tga_struct.bytes_per_pix * tga_struct.tga.img_spec_width);
			y++;
		}
		else
			break;
	}

	if(tga_struct.orientation == TGA_UPPER_LEFT
	 || tga_struct.orientation == TGA_UPPER_RIGHT)
		return(1);  /* up to down */
	else
		return(-1); /* down to up */
}
