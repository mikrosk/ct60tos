/* CT60 TOS + CTPCI link script, raw binary image */
OUTPUT_FORMAT(binary)
INCLUDE ctpci_memory.ld
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
		*( .text )	/* remaining files */
		_etext = .;
		__etext = .;
	} > flash2

	.text3 :
	{
		/* end flag */
		LONG( 0xFFFFFFFF )
	} > flash2
}
