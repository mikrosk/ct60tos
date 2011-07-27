FLASH060.PRG
------------
The main task of this program is to put TOS binary (.BIN) and Srecord 
files (.HEX) files into the CT60 or FIREBEE flash, but the second task 
is to update the CT60 hardware with the JEDEC files (.JED), for the ABE60,
SDR60, and CTPCI chips (XILINX XC95144XL / XC95288XL CPLD).

- In order to load the JEDEC files, you must make the cable for the JTAG
  CT60 connector linked to the parallel port; look in CT60.HYP for the
  diagram. 
- Normally the cable must be attached and powered (by the CT60) for 
  proper verification.  On an unmodified CT60, only the SDR60 can be
  programmed (or verified) when the CT60 is connected to the motherboard
  in normal 030 mode (assuming you use the same machine CT60/F030 ;-) ).
  To update the ABE60 chip you must remove the CT60 from the bus *unless*
  you install a 1K-10K ohm resistor between ground (pin #7) and pin #1 of
  one of the three 74LVC245 chips.  In this case the blitter must not be
  used (NVDI must be installed). 
- After loading valid JEDEC files, the 'verify' button appears.  You can
  use this button to compare the JEDEC file with the chip.  The 'program'
  button erases, programs, and verifies the flash. 

JTAG CT60 connector (unused pins of tower connector):
-----------------------------------------------------
Pin 12 VCC              --> Pin 1 on the JTAG/parallel download cable
Pin 13 GND              --> Pin 2
Pin 14 NC (no pin !)
Pin 15 TCK              --> Pin 3
Pin 16 TDO              --> Pin 4
Pin 17 TDI              --> Pin 5
Pin 18 TMS              --> Pin 6

You can force the programming chip to ABE or SDR, because since the 
CT63 it's impossible to detect the chip from the jedec file 
(SDR60 was a XC95144XL-7-TQ144 and ABE60 a C95144XL-10-TQ144). 
When you load the jedec file, the filename it's also tested and an 
alert box arrives for change the chip. This update allows CTPCI 
device programming (XC95288XL). 

This update allows to program the ETHERNAT (XC9572XL). 

FLASH_CF.PRG
------------
Coldfire native binary for the FIREBEE, if you have problems, use 
FLASH060.PRG under TOS/CF68KLIB.


For more information:
aniplay@wanadoo.fr

