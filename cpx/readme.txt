Note about CT60CONF.CPX:
------------------------
Selection TOS in RAM :
When this option is set, the TOS is copied in SDRAM $E00000 to 
$EEFFFF (the last sector of the flash $EE0000 to $EFFFFF is used for 
save 16 parameters), and the TOS variables are copied to SDRAM $0 to 
$1FFF (the PMMU tree use 8K size page).
- If only the TOS is used you can set this option for increase speed.
- If you're programmer, don't set this option because you can create 
 bugged programs. For exemple writing to 0 not create a bus error.
- If the memory protection is used under MiNT, don't set this option.
 The PMMU tree is always created, but the cookie 'PMMU' not exists 
 when this option is removed.

Note about GENERAL6.CPX:
------------------------
This CPX is a patched version of the Falcon GENERAL.CPX for the 
68060. The cache on/off selection now uses XBIOS calls, there are no 
problems under TOS because this XBIOS is inside the FLASH but under 
MagiC if you use this CPX you need to install CT60XBIO.PRG inside the 
AUTO folder. This program install the XBIOS for the CT60 if the cookie 
'CT60' isn't found.

Note about XCONTROL, ZCONTROL, COPS, and SDRAM in copyback:
-----------------------------------------------------------
- COPS only flush caches after load the CPX and works fine.
- ZCONTROL works under MiNT 1.16/Xaaes.
- XCONTROL crashes.
- The patched XCONTROL.ACC inside this folder fix this problem by a 
new XBIOS call but under MagiC if you use this ACC you need to install 
CT60XBIO.PRG inside the AUTO folder.

Note about PARX.SYS modules and the copyback:
---------------------------------------------
- If a program who use PARX.SYS crashes at start, you can try to 
remove cache with GENERAL6.CPX, load the program and set to on after. 
For example PICCOLO works with this method.

Note about TSR programs who crashes in the AUTO folder:
-------------------------------------------------------
- Like CPX, the programs who not uses the Pexec function for load 
modules crashes with the SDRAM in copyback, so the best way is to load 
the program in STRAM (cache in writethrough). You can use FILEINFO.CPX 
inside this folder.
For example you must remove TT-ram flags of METAXBS.PRG (Metados) 
because when the OVL modules are loaded there are no flush after 
relocation, it's not compatible with the SDRAM and the CPU cache in 
copyback.  

For more informations:
didier-mequignon@wanadoo.fr
