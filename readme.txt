This is the second release with the boot 2 (V2.01), the main difference with 
the boot V1.xx versions is:
- BOOT patch the original TOS404 for a 68060.
- BOOT add PCI BIOS to the TOS if PCI hardware is found.
- TOS run always in SDRAM (write protected).
- Multi targets: CT60, M5484LITE, FIREBEE, etc...
- On Coldfire targets (M5484LITE, FIREBEE, etc..), the BOOT start the 
CF68KLIB with a 68060 emulation.
- In the 2nd part of the flash you can replace the Atari Diagnostics 
by drivers for extend or replace TOS features (keyboard, mouse, disks, 
sound, etc...), for exemple add PCI drivers to the CT60 if CTPCI and 
PCI boards are installed.

For the CT60, this update try to fix flash reading before copy in 
SDRAM by using a CRC and use the Supervidel detection for continue
to use the defaut Bconout routines (using Blitter).
FLASH060 is updated for the ETHERNAT.

For the Firebee this update has lot of fixes and more features inside the
CF68KLIB (look history.txt).

For more information http://ct60.atari.org  
                     http://ctpci.atari.org
                     http://acp.atari.org

Thanks to Roger Burrows for the english version and the XCONTROL 
patches.

jpegsnap.acc is a snapshot tool who works in 65K and 16M colors 
compiled for the Coldfire with -m5200 (but works also on a 060 ;-) ), 
there are 3 modes:
 - ALT-PRINT
 - Rubberbox.
 - Top window. 

