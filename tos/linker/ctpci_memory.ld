/* CTPCI memory configuration */
MEMORY
{
	/* CT60 TOS, part one (TOS 4.04 memory area) */
	flash1 (rx) :	ORIGIN = 0x00E00000, LENGTH = 512K
	/* CT60 TOS, part two */
	flash2 (rx) :	ORIGIN = 0x00E80000, LENGTH = 256K
	/* PCI drivers, part one */
	flash3 (rx) :	ORIGIN = 0x00EC0000, LENGTH = 256K
	/* PCI drivers, part two (<1.06 memory area) */
	flash4 (r)  :	ORIGIN = 0x00FC0000, LENGTH = 192K
	/*
	 * PCI drivers, part three (range also defined in pci_bios.h:
         * PCI_DRIVERS_OFFSET (origin)
	 * PCI_DRIVERS_SIZE (length)
	 */
	ram    (rw) :	ORIGIN = 0x21000000, LENGTH = 64K
}
