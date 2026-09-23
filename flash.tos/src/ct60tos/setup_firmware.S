/* CT60 Setup, resident in the flash.
 *
 * The setup is built from src/ct60_setup as an ordinary GEMDOS executable,
 * compressed with UPX (src/ct60_setup/setup.bin) and patched into the free
 * space at the end of the TOS 4.04 area, where setup_loader finds it.  The
 * long in front of the image is its length, which the loader needs to copy
 * it into the basepage it creates for it.
 *
 * Run src/ct60_setup/make-firmware.sh to rebuild the image.
 */

	.text

	.align	2
	.long	0x0007C000
	.long	end_setup-begin_setup
begin_setup:
	.long	end_setup_image-setup_image
setup_image:
	.incbin	"src/ct60_setup/setup.bin"
end_setup_image:
	.space	16               // the loader copies in 16 byte units
	.align	2
end_setup:
