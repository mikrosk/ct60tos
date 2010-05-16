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
	} > flash1
	end_of_text1 = .;

	/* End of text1 is aligned on 4-byte boundary. */
	.text2 :
	AT( end_of_text1 )
	{
		/*
		* Final "patch" header, put start address and length here,
		* even when the size is probably bigger than necessary
		* due to 4-byte align...
		*/
		LONG( ADDR( .text3 ) )
		/* omit last 0xFFFFFFFF */
		LONG( SIZEOF( .text3 ) - 4 )
	} > flash1
	end_of_text2 = .;

	/* End of text2 therefore continues without any padding. */
	.text3 :
	AT( end_of_text2 )
	{
		version.o( .text )
		*( .text )
		LONG( 0xFFFFFFFF )
		_etext = .;
		__etext = .;
	} > flash2
}
