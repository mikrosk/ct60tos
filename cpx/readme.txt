Note about CT60CONF.CPX:
------------------------
Selection "TOS in RAM" :
This option is removed since the boot 2.00, the TOS is always in RAM,
and the cookie 'PMMU' does not exist.
When this option is set, TOS is copied to SDRAM locations $E00000 to 
$EEFFFF (the last sector of the flash, $EE0000 to $EFFFFF, is used to 
save 16 parameters).
- If only TOS is used you can set this option to increase speed.
- If memory protection is used under MiNT, don't set this option.
The PMMU tree is always created, but the cookie 'PMMU' does not
exist when this option isn't set.

Note about FIRECONF.CPX:
------------------------
Same than CT60CONF.CPX with just another header.

Note about GENERAL6.CPX:
------------------------
This CPX is a version of the Falcon GENERAL.CPX, patched for the 
68060. The cache on/off selection now uses XBIOS calls.  There are no 
problems under TOS because this XBIOS call is inside the FLASH, but
to use this CPX under MagiC you must put CT60XBIO.PRG in the AUTO
folder. This program installs the XBIOS for the CT60 if the cookie 
'CT60' isn't found.

Note sur FSOUND.CPX:
--------------------
The default FSOUND.CPX crashes with big screens (like 1920x1080x32), 
this CPX increase the limits.

Note about XCONTROL, ZCONTROL, COPS, and SDRAM in copyback:
-----------------------------------------------------------
- Only COPS flushes caches after loading the CPX and therefore works
  fine.
- ZCONTROL works under MiNT 1.16/Xaaes.
- XCONTROL crashes.
- The patched XCONTROL.ACC inside this folder (CT60 users must use 
PATCH_XC.PRG before) fixes this problem by using a new XBIOS call; 
if you use this ACC under MagiC, you must put CT60XBIO.PRG in the AUTO folder.

Note about PARX.SYS modules and copyback:
-----------------------------------------
- If a program that uses PARX.SYS crashes at startup, you could try 
  disabling cache with GENERAL6.CPX, loading the program, and enabling
  the cache afterwards. PICCOLO (for example) works with this method.

Note about TSR programs that crash in the AUTO folder:
------------------------------------------------------
- As with CPX loading, programs that do not use the Pexec function to
  load modules crash with SDRAM in copyback mode.  The best way to
  circumvent this is to load the program in STRAM (which uses cache in
  writethrough mode). You can use FILEINFO.CPX in this folder to set
  the program load flags correctly.
  For example, you must remove the TT-RAM flags of METAXBS.PRG (Metados)
  because, when the OVL modules are loaded, there is no cache flush after
  relocation, which is incompatible with SDRAM and the CPU cache in 
  copyback mode.

For more information:
aniplay@wanadoo.fr
