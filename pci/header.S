	.text
	.global	Start,_init_devices,_init_with_sdram
	.long 0x5F504349          // _PCI
Start:
	jmp	_init_devices
	jmp	_init_with_sdram

