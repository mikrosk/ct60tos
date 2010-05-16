/* PCI link script, raw binary image */
OUTPUT_FORMAT(binary)
INCLUDE ctpci_memory.ld
SECTIONS
{
	/* instruct linker where to place this symbol */
	_d_rezword = 0xA4EA;

	/* VMA of .text2 must == ORIGIN( flash3 ) */
	.text1 ORIGIN( flash3 ) - 8 :
	{
		LONG( ADDR( .text2 ) )
		LONG( SIZEOF( .text2 ) )
	} > flash3

	.text2 :
	{
		*(.text)
		_etext = .;
		__etext = .;
	} > flash3

	.text3 :
	{
		LONG( ADDR( .data1 ) )
		LONG( SIZEOF( .data1 ) )
	} > flash3
	end_of_text = .;

	.data1 :
	AT( end_of_text )
	{
		*(.data)
		_edata  =  .;
		__edata  =  .;
	} > flash4

	.data2 :
	{
		/* end flag */
		LONG( 0xFFFFFFFF )
	} > flash4

	/* bss section isn't part of image */
	.bss :
	{
		__bss_start = .;
		*(.bss)
		*(COMMON)
		_end = .;
		__end = .;
	} > ram
}
