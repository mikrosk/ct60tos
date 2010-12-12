firebee_fpga_29_11_10.rbf converted in fpga.hex
It's not the latest fpga hardware release, but floppy read works fine 
(not write / format), like video.
You can use FLASH060 for update the flash, the FPGA code is loaded to 
the FPGA by Coldfire from the BAS or dBUG before start the TOS.

dbug.hex is one of the preliminary release of dBUG monitor for the Firebee.
NOTE: In the current state because the network part of the TOS use 
      dBUG settings, ethernet not works if the BAS start the TOS.
WARNING: The ethernet part of dBUG need a clock on the PHY (ethernet 
         tranceiver), so if the FLASH above 0xE7000000 is destroyed 
         (FPGA code) ethernet can't work!
          
For load firetos.hex (the TOS) with an host TFTP server with dBUG cmds:
 The 1st time, set TFTP vars (for example):
 * set server 192.168.1.1 (host IP server)
 * set client 192.168.1.2 (FIREBEE IP)
 * set filename /home/firetos_firebee.hex
 * set filetype S-Record
 And also: 
 * set baud 19200
 After just use:
 * dn -o 20000000
 * fl w E0400000 400000 f0000
 * go E0400000 (or go)
 or if jou want preserve flash:
 * dn -o 20000000
 * go 4000000 (or go)
 
You can change the TOS serial debug speed with fireconf.cpx 
 (default is 19200).
