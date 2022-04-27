/* CT60 memory configuration */
MEMORY
{
	/* CT60 TOS, part one (TOS 4.04 memory area) */
	flash1 (rx) :	ORIGIN = 0x00E00000, LENGTH = 512K
	/* CT60 TOS, part two */
	flash2 (rx) :	ORIGIN = 0x00E80000, LENGTH = 512K
}
