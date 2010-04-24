#include "config.h"

	.text
	.global	Start,_init_devices,_init_with_sdram,_init_before_autofolder
	.global	_clear_screen,_move_screen,_print_screen
	.global	_dbug,_event_aes,_disassemble_pc
	.global	_init_rtos,_set_video

	.long 0x5F504349          // _PCI
Start:
	jmp	_init_devices           // 4
	jmp	_init_with_sdram        // 10
	jmp	_init_before_autofolder // 16
	jmp	_clear_screen           // 22
	jmp	_move_screen            // 28
	jmp          _print_screen           // 34
	jmp	_dbug                   // 40
	jmp	_event_aes              // 46
	jmp	_disassemble_pc         // 52
#ifdef COLDFIRE
#ifdef NETWORK
#ifdef LWIP
	jmp	_init_rtos              // 58
#else
	rts
	nop
	nop
#endif
#else
	rts
	nop
	nop
#endif
#else
	rts
	nop
	nop
#endif
	jmp	_set_video              // 64

