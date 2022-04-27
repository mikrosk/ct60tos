/* CT60 TOS link script, raw binary image */
OUTPUT_FORMAT(binary)
INCLUDE ct60_memory.ld
SECTIONS
{
	.text1 :
	{
		/*
		* Each patch contain headers with start addresses and
		* lengths to avoid typing tens of sections and problems
		* with section align. We include 'text' sections but
		* this is only safety check, those files shouldn't
		* contain any 'data' and 'bss' sections.
		* Please note placement into 'flash1' is just cosmetic
		* thing, none of following files depends on it.
		*/
		pmmu.o( .text )
		cookies.o( .text )
		dsp.o( .text )
		periph.o( .text )
		cache.o( .text )
		movep.o( .text )
		boot.o( .text )
		init_par.o( .text )
		blitter.o( .text )
		bios.o( .text )
		xbios.o( .text )
		gemdos.o( .text )
		aes.o( .text )
		vectors.o( .text )
		videl.o( .text )
		debug.o( .text )
		/* Final "patch" header */
		LONG( ADDR( .text2 ) )
		LONG( SIZEOF( .text2 ) )
	} > flash1
	end_of_text1 = .;

	.text2 :
	AT( end_of_text1 )
	{
		version.o( .text )
		pmmu2.o( .text )
		movep2.o( .text )
		blitter2.o( .text )
		bios2.o( .text )
		xbios2.o( .text )
		gemdos2.o( .text )
		aes2.o( .text )
		vectors2.o( .text )
		debug2.o( .text )
		ataboot.o( .text )
		extvidel.o( .text )
		magxboot.o( .text )
		sdram.o( .text )
		videl2.o( .text )
		_etext = .;
		__etext = .;
	} > flash2

	.text3 :
	{
		/* end flag */
		LONG( 0xFFFFFFFF )
	} > flash2
}
