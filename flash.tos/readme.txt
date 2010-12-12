This is the first release of TOS drivers.

A great HYP documentation in english is inside doc\CTPCI.HYP, thanks 
to Sascha Uhlig.

Radeon driver works on all tested targets (CTPCI/M5484LITE/M5485EVB/FIREBEE).
DVI output has black screen on some radeon 7000 boards.

Coldfire targets are always in progress, for more information see 
doc\coldfire.readme.


CT60/CTPCI:
===========
For update drivers load drivers\drivers.hex with FLASH060 from the 
TOS060 archive at http://ct60conf.atari.org
If you reload ct60tos.bin, you must reload drivers.hex, else you can 
use only boot.hex and drivers.hex for update each part.
There are a driver for fVDI: drivers\radeon.sys

Hardware CTPCI bugs list:
-------------------------
- PCI 33MHz boards not works, for example USB generic NEC board
  go to "unrecoverable PCI error" and set "Parity error".
  => use only graphics boards who are 33/66 MHz compatible (more 
  signal tolerance).
- Interrupts not works, to confirm (maybe the real cause is the first 
  problem). Local interrupts can't work.
- DMA writing sometimes freeze the system (easy to create with 
  MagiC/NVDI real time moving window.
  => disable DMA with CT650CONF.CPX.
- DMA reading crashes the system (not used actually).
- Bus mastering for works for same reason.
- PCI arbitration not works, for example if you want use Video RAM 
  with USB board (maybe the real cause is the first problem).

So actually the best is to install ONLY the Radeon board.


M5484LITE:
==========
Ethernet works (need dBUG settings).
USB NEC OHCI/EHCI boards drivers:
- Mouse and keyboard works fine.
- Mass Storage return timeout, sometimes works a little bit (worse 
with EHCI), the cause sems the PCI BUS at 50 MHz, the NEC chip is 
for PCI at 33 MHz.


M5485EVB:
=========
Lynx and RTC drivers not works.


FIREBEE:
========
For update drivers load drivers\drivers_firebee.hex with FLASH060 
from the TOS060 at http://ct60conf.atari.org
There are a native Coldfire driver for fVDI (untested with the 
CF68KLIB): drivers\radeon_f.sys
Ethernet works (need dBUG settings).
USB mouse and keyboard works (OHCI NEC driver, EHCI disabled).
Videl ACP extended modes with EDID detection works (not with the 
latest FPGA hardware) else if a Radeon board is found on the PCI the
Radeon driver replace the Videl (who has no hardware acceleration).
AC97 not works (disabled).


Didier MEQUIGNON

aniplay@wanadoo.fr
