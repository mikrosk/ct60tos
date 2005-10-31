#ifndef __RADEONFB_H__
#define __RADEONFB_H__

#include "config.h"
#include <mint/osbind.h>
#include "pcixbios.h"
#include "mod_devicetable.h"
#include "pci_ids.h"
#include "fb.h"
#include "i2c.h"
#include "i2c-algo-bit.h"
#include "radeon_reg.h"

#include "relocate.h" /* fVDI */

#ifndef NULL
#define NULL ((void *)0)
#endif
#ifndef pointer
#define pointer void*
#endif
#ifndef FLASE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE 1
#endif

/* Buffer are aligned on 4096 byte boundaries */
#define RADEON_BUFFER_ALIGN           0x00000fff

#define RADEON_IDLE_RETRY      16 /* Fall out of idle loops after this count */
#define RADEON_TIMEOUT    2000000 /* Fall out of wait loops after this count */
#define RADEON_MMIOSIZE   0x80000

#define RADEON_ALIGN(x,bytes) (((x) + ((bytes) - 1)) & ~((bytes) - 1))
  
#define ATY_RADEON_LCD_ON	0x00000001
#define ATY_RADEON_CRT_ON	0x00000002

#define FBIO_RADEON_GET_MIRROR	0x80044003
#define FBIO_RADEON_SET_MIRROR	0xC0044004

void udelay(long usec);
void mdelay(long msec);


/***************************************************************
 * Most of the definitions here are adapted right from XFree86 *
 ***************************************************************/

/*
 * Chip families. Must fit in the low 16 bits of a long word
 */
enum radeon_family {
	CHIP_FAMILY_UNKNOW,
	CHIP_FAMILY_LEGACY,
	CHIP_FAMILY_RADEON,
	CHIP_FAMILY_RV100,
	CHIP_FAMILY_RS100,    /* U1 (IGP320M) or A3 (IGP320)*/
	CHIP_FAMILY_RV200,
	CHIP_FAMILY_RS200,    /* U2 (IGP330M/340M/350M) or A4 (IGP330/340/345/350), RS250 (IGP 7000) */
	CHIP_FAMILY_R200,
	CHIP_FAMILY_RV250,
	CHIP_FAMILY_RS300,    /* Radeon 9000 IGP */
	CHIP_FAMILY_RV280,
	CHIP_FAMILY_R300,
	CHIP_FAMILY_R350,
	CHIP_FAMILY_RV350,
	CHIP_FAMILY_RV380,    /* RV370/RV380/M22/M24 */
	CHIP_FAMILY_R420,     /* R420/R423/M18 */
	CHIP_FAMILY_LAST,
};

#define IS_RV100_VARIANT(rinfo) (((rinfo)->family == CHIP_FAMILY_RV100)  || \
				 ((rinfo)->family == CHIP_FAMILY_RV200)  || \
				 ((rinfo)->family == CHIP_FAMILY_RS100)  || \
				 ((rinfo)->family == CHIP_FAMILY_RS200)  || \
				 ((rinfo)->family == CHIP_FAMILY_RV250)  || \
				 ((rinfo)->family == CHIP_FAMILY_RV280)  || \
				 ((rinfo)->family == CHIP_FAMILY_RS300))


#define IS_R300_VARIANT(rinfo) (((rinfo)->family == CHIP_FAMILY_R300)  || \
				((rinfo)->family == CHIP_FAMILY_RV350) || \
				((rinfo)->family == CHIP_FAMILY_R350)  || \
				((rinfo)->family == CHIP_FAMILY_RV380) || \
				((rinfo)->family == CHIP_FAMILY_R420))

/*
 * Chip flags
 */
enum radeon_chip_flags {
	CHIP_FAMILY_MASK	= 0x0000ffffUL,
	CHIP_FLAGS_MASK		= 0xffff0000UL,
	CHIP_IS_MOBILITY	= 0x00010000UL,
	CHIP_IS_IGP		= 0x00020000UL,
	CHIP_HAS_CRTC2		= 0x00040000UL,	
};

/*
 * Errata workarounds
 */
enum radeon_errata {
	CHIP_ERRATA_R300_CG		= 0x00000001,
	CHIP_ERRATA_PLL_DUMMYREADS	= 0x00000002,
	CHIP_ERRATA_PLL_DELAY		= 0x00000004,
};


/*
 * Monitor types
 */
enum radeon_montype {
	MT_NONE = 0,
	MT_CRT,		/* CRT */
	MT_LCD,		/* LCD */
	MT_DFP,		/* DVI */
	MT_CTV,		/* composite TV */
	MT_STV		/* S-Video out */
};

/*
 * DDC i2c ports
 */
enum ddc_type {
	ddc_none,
	ddc_monid,
	ddc_dvi,
	ddc_vga,
	ddc_crt2,
};

/*
 * Connector types
 */
enum conn_type {
	conn_none,
	conn_proprietary,
	conn_crt,
	conn_DVI_I,
	conn_DVI_D,
};


/*
 * PLL infos
 */
struct pll_info {
	int ppll_max;
	int ppll_min;
	int sclk, mclk;
	int ref_div;
	int ref_clk;
};


/*
 * This structure contains the various registers manipulated by this
 * driver for setting or restoring a mode. It's mostly copied from
 * XFree's RADEONSaveRec structure. A few chip settings might still be
 * tweaked without beeing reflected or saved in these registers though
 */
struct radeon_regs {
	/* Common registers */
	unsigned long		ovr_clr;
	unsigned long		ovr_wid_left_right;
	unsigned long		ovr_wid_top_bottom;
	unsigned long		ov0_scale_cntl;
	unsigned long		mpp_tb_config;
	unsigned long		mpp_gp_config;
	unsigned long		subpic_cntl;
	unsigned long		viph_control;
	unsigned long		i2c_cntl_1;
	unsigned long		gen_int_cntl;
	unsigned long		cap0_trig_cntl;
	unsigned long		cap1_trig_cntl;
	unsigned long		bus_cntl;
	unsigned long		surface_cntl;
	unsigned long		bios_5_scratch;

	/* Other registers to save for VT switches or driver load/unload */
	unsigned long		dp_datatype;
	unsigned long		rbbm_soft_reset;
	unsigned long		clock_cntl_index;
	unsigned long		amcgpio_en_reg;
	unsigned long		amcgpio_mask;

	/* Surface/tiling registers */
	unsigned long		surf_lower_bound[8];
	unsigned long		surf_upper_bound[8];
	unsigned long		surf_info[8];

	/* CRTC registers */
	unsigned long		crtc_gen_cntl;
	unsigned long		crtc_ext_cntl;
	unsigned long		dac_cntl;
	unsigned long		crtc_h_total_disp;
	unsigned long		crtc_h_sync_strt_wid;
	unsigned long		crtc_v_total_disp;
	unsigned long		crtc_v_sync_strt_wid;
	unsigned long		crtc_offset;
	unsigned long		crtc_offset_cntl;
	unsigned long		crtc_pitch;
	unsigned long		disp_merge_cntl;
	unsigned long		grph_buffer_cntl;
	unsigned long		crtc_more_cntl;

	/* CRTC2 registers */
	unsigned long		crtc2_gen_cntl;
	unsigned long		dac2_cntl;
	unsigned long		disp_output_cntl;
	unsigned long		disp_hw_debug;
	unsigned long		disp2_merge_cntl;
	unsigned long		grph2_buffer_cntl;
	unsigned long		crtc2_h_total_disp;
	unsigned long		crtc2_h_sync_strt_wid;
	unsigned long		crtc2_v_total_disp;
	unsigned long		crtc2_v_sync_strt_wid;
	unsigned long		crtc2_offset;
	unsigned long		crtc2_offset_cntl;
	unsigned long		crtc2_pitch;

	/* Flat panel regs */
	unsigned long 	fp_crtc_h_total_disp;
	unsigned long		fp_crtc_v_total_disp;
	unsigned long		fp_gen_cntl;
	unsigned long		fp2_gen_cntl;
	unsigned long		fp_h_sync_strt_wid;
	unsigned long		fp2_h_sync_strt_wid;
	unsigned long		fp_horz_stretch;
	unsigned long		fp_panel_cntl;
	unsigned long		fp_v_sync_strt_wid;
	unsigned long		fp2_v_sync_strt_wid;
	unsigned long		fp_vert_stretch;
	unsigned long		lvds_gen_cntl;
	unsigned long		lvds_pll_cntl;
	unsigned long		tmds_crc;
	unsigned long		tmds_transmitter_cntl;

	/* Computed values for PLL */
	unsigned long		dot_clock_freq;
	unsigned long		pll_output_freq;
	int		feedback_div;
	int		post_div;	

	/* PLL registers */
	unsigned long		ppll_div_3;
	unsigned long		ppll_ref_div;
	unsigned long		vclk_ecp_cntl;
	unsigned long		clk_cntl_index;
	unsigned long		htotal_cntl;

	/* Computed values for PLL2 */
	unsigned long		dot_clock_freq_2;
	unsigned long		pll_output_freq_2;
	int		feedback_div_2;
	int		post_div_2;

	/* PLL2 registers */
	unsigned long		p2pll_ref_div;
	unsigned long		p2pll_div_0;
	unsigned long		htotal_cntl2;
};

struct panel_info {
	int xres, yres;
	int valid;
	int clock;
	int hOver_plus, hSync_width, hblank;
	int vOver_plus, vSync_width, vblank;
	int hAct_high, vAct_high, interlaced;
	int pwr_delay;
	int use_bios_dividers;
	int ref_divider;
	int post_divider;
	int fbk_divider;
};

struct radeonfb_info;

#ifdef CONFIG_FB_RADEON_I2C
struct radeon_i2c_chan {
	struct radeonfb_info		*rinfo;
	unsigned long		 		ddc_reg;
	struct i2c_adapter		adapter;
	struct i2c_algo_bit_data	algo;
};
#endif

enum radeon_pm_mode {
	radeon_pm_none	= 0,		/* Nothing supported */
	radeon_pm_d2	= 0x00000001,	/* Can do D2 state */
	radeon_pm_off	= 0x00000002,	/* Can resume from D3 cold */
};

typedef struct {
    int               bitsPerPixel;
    int               depth;
    int               displayWidth;
    int               pixel_code;
    int               pixel_bytes;
} RADEONFBLayout;

struct radeonfb_info {
	long handle;     /* PCI BIOS */
	long big_endian; /* PCI BIOS */

	unsigned long     cursor_start;
	unsigned long     cursor_end;
	int               cursor_fg;
	int               cursor_bg;

	int fifo_slots;       /* Free slots in the FIFO (64 max)   */

				/* Computed values for Radeon */
	unsigned long     dp_gui_master_cntl_clip;
	unsigned long     trans_color;

				/* Saved values for ScreenToScreenCopy */
	int               xdir;
	int               ydir;

				/* ScanlineScreenToScreenColorExpand support */
	int               scanline_h;
	int               scanline_words;
	int               scanline_bpp;     /* Only used for ImageWrite */

				/* Saved values for DashedTwoPointLine */
	int               dashLen;
	unsigned long     dashPattern;
	int               dash_fg;
	int               dash_bg;

	struct fb_info		*info;

	struct radeon_regs 	state;
	struct radeon_regs	init_state;

	char			name[50];

	unsigned long		mmio_base_phys;
	unsigned long		fb_base_phys;

	void 		*mmio_base;
	void 		*fb_base;

	unsigned long		fb_local_base;
	unsigned long   fb_offset;

	struct { unsigned char red, green, blue, pad; }
				palette[256];

	int			chipset;
	unsigned char			family;
	unsigned char			rev;
	unsigned int		errata;
	unsigned long		video_ram;
	unsigned long		mapped_vram;
	int			vram_width;
	int			vram_ddr;

	int			pitch, bpp, depth;

	int			has_CRTC2;
	int			is_mobility;
	int			is_IGP;
	int			reversed_DAC;
	int			reversed_TMDS;
	struct panel_info	panel_info;
	int			mon1_type;
	unsigned char			*mon1_EDID;
	struct fb_videomode	*mon1_modedb;
	int			mon1_dbsize;
	int			mon2_type;
	unsigned char		        *mon2_EDID;

	unsigned long			dp_gui_master_cntl;

	struct pll_info		pll;

	unsigned long			save_regs[100];
	int			asleep;
	int			lock_blank;
	int			dynclk;
	int			no_schedule;
	enum radeon_pm_mode	pm_mode;

	/* Timer used for delayed LVDS operations */
  long lvds_timer;
	unsigned long			pending_lvds_gen_cntl;

#ifdef CONFIG_FB_RADEON_I2C
	struct radeon_i2c_chan 	i2c[4];
#endif
};


#define PRIMARY_MONITOR(rinfo)	(rinfo->mon1_type)

/*
 * Debugging stuffs
 */
extern Access *access;       /* fVDI */
extern short debug;
extern void debug_print(const char *string);
extern void debug_print_value(const char *string, long val);
#define DPRINT debug_print
#define DPRINTVAL debug_print_value

/*
 * IO macros
 */

/* Note about this function: we have some rare cases where we must not schedule,
 * this typically happen with our special "wake up early" hook which allows us to
 * wake up the graphic chip (and thus get the console back) before everything else
 * on some machines that support that mecanism. At this point, interrupts are off
 * and scheduling is not permitted
 */
static inline void _radeon_msleep(struct radeonfb_info *rinfo, unsigned long ms)
{
		mdelay(ms);
}

#define radeon_msleep(ms)		_radeon_msleep(rinfo,ms)

extern void _OUTREGP(struct radeonfb_info *rinfo, unsigned long addr, unsigned long val, unsigned long mask);
extern void radeon_pll_errata_after_index(struct radeonfb_info *rinfo);
extern void radeon_pll_errata_after_data(struct radeonfb_info *rinfo);
extern unsigned long __INPLL(struct radeonfb_info *rinfo, unsigned long addr);
extern void __OUTPLL(struct radeonfb_info *rinfo, unsigned int index, unsigned long val);
extern void __OUTPLLP(struct radeonfb_info *rinfo, unsigned int index, unsigned long val, unsigned long mask);

#define INREG8(addr)		fast_read_io_byte((rinfo->handle),(rinfo->mmio_base_phys)+addr)
#define INREG16(addr)		fast_read_io_word((rinfo->handle),(info->mmio_base_phys)+addr)
#define INREG(addr)		fast_read_io_longword((rinfo->handle),(rinfo->mmio_base_phys)+addr)
#define OUTREG8(addr,val)	write_io_byte((rinfo->handle),(rinfo->mmio_base_phys)+addr,val)
#define OUTREG16(addr,val)	write_io_word((info->handle),(rinfo->mmio_base_phys)+addr,val)
#define OUTREG(addr,val)	write_io_longword((rinfo->handle),(rinfo->mmio_base_phys)+addr,val)

#define ADDRREG(addr)		((volatile unsigned long *)(rinfo->mmio_base_phys + (addr)))
#define OUTREGP(addr,val,mask)	_OUTREGP(rinfo, addr, val,mask)
#define INPLL(addr)			__INPLL(rinfo, addr)
#define OUTPLL(index, val)		__OUTPLL(rinfo, index, val)
#define OUTPLLP(index, val, mask)	__OUTPLLP(rinfo, index, val, mask)

/*
 * Inline utilities
 */

static inline unsigned long radeon_get_dstbpp(unsigned short depth)
{
	switch (depth)
	{
		case 8: return DST_8BPP;
		case 15: return DST_15BPP;
   	case 16: return DST_16BPP;
   	case 32: return DST_32BPP;
   	default: return 0;
	}
}

/* I2C Functions */
extern void radeon_create_i2c_busses(struct radeonfb_info *rinfo);
extern void radeon_delete_i2c_busses(struct radeonfb_info *rinfo);
extern int radeon_probe_i2c_connector(struct radeonfb_info *rinfo, int conn, unsigned char **out_edid);

/* PM Functions */
/* extern int radeonfb_pci_suspend(struct pci_dev *pdev, unsigned long state);
extern int radeonfb_pci_resume(struct pci_dev *pdev);  */
extern void radeonfb_pm_init(struct radeonfb_info *rinfo, int dynclk);
extern void radeonfb_pm_exit(struct radeonfb_info *rinfo);

/* Monitor probe functions */
extern void radeon_probe_screens(struct radeonfb_info *rinfo,
				 const char *monitor_layout, int ignore_edid);
extern void radeon_check_modes(struct radeonfb_info *rinfo, struct mode_option *resolution);
extern int radeon_match_mode(struct radeonfb_info *rinfo,
			     struct fb_var_screeninfo *dest,
			     const struct fb_var_screeninfo *src);

/* Accel functions */

extern void RADEONWaitForFifoFunction(struct radeonfb_info *rinfo, int entries);
extern void RADEONEngineFlush(struct radeonfb_info *rinfo);
extern void RADEONEngineReset(struct radeonfb_info *rinfo);
extern void RADEONEngineRestore(struct radeonfb_info *rinfo);
extern void RADEONEngineInit(struct radeonfb_info *rinfo);
extern void RADEONWaitForIdleMMIO(struct radeonfb_info *rinfo);

#define DEGREES_0	0
#define DEGREES_90	1
#define DEGREES_180	2
#define DEGREES_270	3
#define OMIT_LAST	1
#define RADEONWaitForFifo(rinfo, entries)				\
do {									\
	if(rinfo->fifo_slots < entries)					\
		RADEONWaitForFifoFunction(rinfo, entries);			\
	rinfo->fifo_slots -= entries;					\
} while(0)
#define radeon_fifo_wait(entries) RADEONWaitForFifo(rinfo, entries)
#define radeon_engine_flush (rinfo) RADEONEngineFlush(rinfo)
#define radeonfb_engine_reset(rinfo) RADEONEngineReset(rinfo)
#define radeonfb_engine_init(rinfo) RADEONEngineInit(rinfo)
#define radeon_engine_idle() RADEONWaitForIdleMMIO(rinfo)

static inline int radeonfb_sync(struct fb_info *info)
{
	struct radeonfb_info *rinfo = info->par;
	radeon_engine_idle();
	return 0;
}

extern void RADEONRestoreAccelStateMMIO(struct radeonfb_info *rinfo);
extern void RADEONSetupForSolidFillMMIO(struct radeonfb_info *rinfo,
            int color, int rop, unsigned int planemask);
extern void RADEONSubsequentSolidFillRectMMIO(struct radeonfb_info *rinfo,
            int x, int y, int w, int h);
extern void RADEONSetupForSolidLineMMIO(struct radeonfb_info *rinfo,
            int color, int rop, unsigned int planemask);
extern void RADEONSubsequentSolidHorVertLineMMIO(struct radeonfb_info *rinfo,
            int x, int y, int len, int dir);   
extern void RADEONSubsequentSolidTwoPointLineMMIO(struct radeonfb_info *rinfo,
            int xa, int ya, int xb, int yb, int flags);  
extern void RADEONSetupForDashedLineMMIO(struct radeonfb_info *rinfo,
            int fg, int bg, int rop, unsigned int planemask, int length, unsigned char *pattern);
extern void RADEONSubsequentDashedTwoPointLineMMIO(struct radeonfb_info *rinfo,
            int xa, int ya, int xb, int yb, int flags, int phase);  
extern void RADEONSetupForScreenToScreenCopyMMIO(struct radeonfb_info *rinfo,
            int xdir, int ydir, int rop, unsigned int planemask, int trans_color);
extern void RADEONSubsequentScreenToScreenCopyMMIO(struct radeonfb_info *rinfo,
            int xa, int ya, int xb, int yb, int w, int h);   
extern void RADEONSetupForMono8x8PatternFillMMIO(struct radeonfb_info *rinfo,
            int patternx, int patterny, int fg, int bg, int rop, unsigned int planemask);
extern void RADEONSetupForMono16x16PatternFillMMIO(struct radeonfb_info *rinfo,
            unsigned short *pattern, int fg, int bg, int rop, unsigned int planemask);
extern void RADEONSubsequentMono8x8PatternFillRectMMIO(struct radeonfb_info *rinfo,
            int patternx, int patterny, int x, int y, int w, int h);
#define RADEONSubsequentMono16x16PatternFillRectMMIO(rinfo, x, y, w, h) \
        RADEONSubsequentMono8x8PatternFillRectMMIO(rinfo, 0, 0, x, y, w, h)
extern void RADEONSetupForScanlineCPUToScreenColorExpandFillMMIO(struct radeonfb_info *rinfo, 
            int fg, int bg, int rop, unsigned int planemask);
extern void RADEONSubsequentScanlineCPUToScreenColorExpandFillMMIO(struct radeonfb_info *rinfo,
            int x, int y, int w, int h, int skipleft);
extern void RADEONSubsequentScanlineMMIO(struct radeonfb_info *rinfo, unsigned long *buf);
extern void RADEONSetupForScanlineImageWriteMMIO(struct radeonfb_info *rinfo,
            int rop, unsigned int planemask, int trans_color, int bpp);
extern void RADEONSubsequentScanlineImageWriteRectMMIO(struct radeonfb_info *rinfo,
            int x, int y, int w, int h, int skipleft);  
extern void RADEONSetClippingRectangleMMIO(struct radeonfb_info *rinfo,
            int xa, int ya, int xb, int yb);
extern void RADEONDisableClippingMMIO(struct radeonfb_info *rinfo);

/* Cursor functions */
extern void RADEONSetCursorColors(struct radeonfb_info *rinfo, int bg, int fg);
extern void RADEONSetCursorPosition(struct radeonfb_info *rinfo, int x, int y);
extern void RADEONLoadCursorImage(struct radeonfb_info *rinfo, unsigned short *mask, unsigned short *data);
extern void RADEONHideCursor(struct radeonfb_info *rinfo);
extern void RADEONShowCursor(struct radeonfb_info *rinfo);
extern long RADEONCursorInit(struct radeonfb_info *rinfo);

/* Memory functions */
extern long radeon_offscreen_free(struct radeonfb_info *rinfo, long addr);
extern long radeon_offscreen_alloc(struct radeonfb_info *rinfo, long amount);
extern void radeon_offscreen_init(struct radeonfb_info *rinfo);

/* Other functions */
extern int radeon_screen_blank(struct radeonfb_info *rinfo, int blank, int mode_switch);
extern void radeon_write_mode (struct radeonfb_info *rinfo, struct radeon_regs *mode, int reg_only);
int radeonfb_setcolreg(unsigned regno, unsigned red, unsigned green,
			       unsigned blue, unsigned transp, struct fb_info *info);
extern int radeonfb_pci_register(long handle, const struct pci_device_id *ent);
extern void radeonfb_pci_unregister(void);

#endif /* __RADEONFB_H__ */
