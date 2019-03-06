#define TGA_IMG_NODATA             (0)
#define TGA_IMG_UNC_PALETTED       (1)
#define TGA_IMG_UNC_TRUECOLOR      (2)
#define TGA_IMG_UNC_GRAYSCALE      (3)
#define TGA_IMG_RLE_PALETTED       (9)
#define TGA_IMG_RLE_TRUECOLOR      (10)
#define TGA_IMG_RLE_GRAYSCALE      (11)


#define TGA_LOWER_LEFT             (0)
#define TGA_LOWER_RIGHT            (1)
#define TGA_UPPER_LEFT             (2)
#define TGA_UPPER_RIGHT            (3)


#define HDR_LENGTH               (18)
#define HDR_IDLEN                (0)
#define HDR_CMAP_TYPE            (1)
#define HDR_IMAGE_TYPE           (2)
#define HDR_CMAP_FIRST           (3)
#define HDR_CMAP_LENGTH          (5)
#define HDR_CMAP_ENTRY_SIZE      (7)
#define HDR_IMG_SPEC_XORIGIN     (8)
#define HDR_IMG_SPEC_YORIGIN     (10)
#define HDR_IMG_SPEC_WIDTH       (12)
#define HDR_IMG_SPEC_HEIGHT      (14)
#define HDR_IMG_SPEC_PIX_DEPTH   (16)
#define HDR_IMG_SPEC_IMG_DESC    (17)

typedef struct
{
    unsigned char	idlen;               /* length of the image_id string below.		*/
    unsigned char	cmap_type;           /* paletted image <=> cmap_type				*/
    unsigned char	image_type;          /* can be any of the IMG_TYPE constants above.	*/
    unsigned short	cmap_first;          
    unsigned short	cmap_length;         /* how long the colormap is					*/
    unsigned char	cmap_entry_size;     /* how big a palette entry is.					*/
    unsigned short	img_spec_xorig;      /* the x origin of the image in the image data.*/
    unsigned short	img_spec_yorig;      /* the y origin of the image in the image data.*/
    unsigned short	img_spec_width;      /* the width of the image.						*/
    unsigned short	img_spec_height;     /* the height of the image.					*/
    unsigned char	img_spec_pix_depth;  /* the depth of a pixel in the image.			*/
    unsigned char	img_spec_img_desc;   /* the image descriptor.						*/
} targa_hdr;

#define TGA_TRUECOLOR_32 (4)
#define TGA_TRUECOLOR_24 (3)

typedef struct
{
	unsigned char		*ptr_source;
	unsigned char 		*img_buf;			/* buffer for 1 line of packet TGA Data */
	unsigned char		alphabits;
	unsigned char		bytes_per_pix;
	unsigned char		orientation;
	long		line_size;			
	long		img_buf_len;		/* L„nge des IMG-Buffers */
	long		img_buf_offset;		/* Abstand zum Anfang des IMG-Buffers */
	long		img_buf_used;		/* Anzahl der benutzten Bytes des IMG-Buffers */
	long		rest_length;		/* noch einzulesende Dateil„nge */
	targa_hdr	tga;
} tga_pic;
