This is an example for build a boot demo on the CT60 with gcc, the target 
is in Motorola srecord format (.HEX) and you can load this demo with the 
latest flash060.prg and without destroy the TOS.
The Atari Diagnostics are not available because the same zone is used 
in flash (0xED0000-0xEEFFFF).
This demos replace the boot picture if there are 'XIMG' at 0xED0000, 
in this case the boot call a routine at 0xED0004.
The routine can use XBIOS, the screen is set by the boot at 0x10000 
in 320 x 240 x 65K colors. The SDRAM is not available at this stage.
The maximum size is 128KB (0xED0000-0xEEFFFF).
The Makefile of the example force the code (text and data) at 
0xED0000 and the bss segment at 0x100000.

For more informations, please contact aniplay@wanadoo.fr

