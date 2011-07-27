rescuetos.hex is a TOS for replace BAS or dBUG located at 0xE0000000
It's is a firetos.hex with offsets moved from 0xE0400000 to 0xE0000000.
The idea is to have a bacukp stable a the TOS and use it if a new 
TOS (or a beta) create problems.
When the TOS start from this area, the SW5 is tested and there are an  
FPGA init (from 0xE0700000).
Because actually for me it's not tested, flash it only if you have a 
BDM cable.

Boot menu and rescue features:
  SW6 and SW5 are inside the cookie '_SWI':
  * B7: (1) SW6 DOWN, (0) SW6 UP
  * B6: (1) SW5 DOWN, (0) SW5 UP
  * B0: (1) rescue TOS started from 0xE0000000 (replace BAS or dBUG)
 SW6 up is the normal usage
 SW6 down allows to TOS to start FTP (build option), HTTP, TFTP servers and create a Ram-Disk 
     actually in B (this feature is also possible with dBUG at 0xE0000000).
 SW5 up is the normal usage for start the TOS at 0xE0400000 (same usage inside BAS or dBUG at 
     0xE0000000) and a boot menu has 2 choices TOS or EMUTOS (TOS by default).
 SW5 down is the rescue mode, TOS at 0xE0000000 continue to run and a boot menu displays 3 choices:
  * TOS404 (at 0xE0000000 - boot)   => TOS rescue (default choice)
  * EMUTOS (at 0xE0600000)
  * TOS404 (at 0xE0400000 - normal) => TOS to test
 IT'S IMPORTANT TO FLASH ONLY AT 0xE0000000 AN OFFICIAL STABLE RELEASE OF THE TOS (rescuetos.hex)
 OR CONTINUE TO USE DBUG OR BAS AT 0xE0000000.
