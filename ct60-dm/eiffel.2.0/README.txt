There are backward compatibility between hardware Eiffel 1,2,3 and the 
latest Firmware, _excepted_ after the firmware 2.0 because the clock 
is at 8 MHz (4 MHz before). 
 
An update v1.x to v2.0 with EIFFELCF.APP seems possible _only_ for eiffel.hex 
but you need to change the quartz after (the timer and the serial link to the 
host are programmed for 8 MHz). If you cannot reprogram the PIC, the 
best is to use a socket for the quartz. 
 
So if you want use a version 2.0 and you have a 1.x the best is to reprogram 
the pic with a programmer ! 


Since Eiffel 1.10, there are two HEX files for update the Firmware: - 
 The normal version eiffel.hex need a minimum a PIC programmed with 
   Eiffel 1.0.4 (backward compatibility).
 - The clock interrupt version eiffel_i.hex (who not lost seconds)  
   need a PIC programmed with Eiffel 1.10.
The Flash boot loader since Eiffel 1.10 displays the programming 
address, and 'OK' if the checksum is good on the LCD 2x16.


lcd.slb is a library for use all the LCD sreen from the Atari.
This library is for example used by Aniplayer 2.23.
You need to install E_TEMP.PRG inside the AUTO folder for get the 
temperature and install a serial buffer for send data to the IKBD.
The serial buffer reduce CPU load, because all characters are send
by interrupts.

