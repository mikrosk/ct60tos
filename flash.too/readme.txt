FLASH060.PRG
------------
The main task of this program is to put TOS binary (.BIN) files inside 
the flash, but the second task is to update the CT60 hardware with two 
jedec files (.JED) for ABE60 et SDR60 chips (XILINX XC95144XL CPLD).
- You need to make the cable for the JTAG CT60 connector linked to // 
port, look inside CT60.HYP for the schema. 
- Normally the cable must be attached and powered (by the CT60) for 
proper verification. Only SDR60 can be programmed (or verified) when 
the CT60 is connected to the mother board in normal 030 mode (if you 
use the same machine CT60/F030 ;-) ). If you update the ABE60 chip you 
need to remove the CT60 from the bus. 
- If you load the good jedec files, another button appears 'verify'. 
You can use this button for compare the jedec file with the chip. The 
'program' button erase, program, and verify his flash. 

JTAG CT60 connector (pins of tower connector not used):
-------------------------------------------------------
Pin 12 VCC              --> Pin 1 on the JTAG/parallel download cable
Pin 13 GND              --> Pin 2
Pin 14 NC (no pin !)
Pin 15 TCK              --> Pin 3
Pin 16 TDO              --> Pin 4
Pin 17 TDI              --> Pin 5
Pin 18 TMS              --> Pin 6

For more informations:
didier-mequignon@wanadoo.fr

