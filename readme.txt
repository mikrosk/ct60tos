Thanks to Roger Burrows for the english version and the XCONTROL 
patches.

New feature of the boot 1.01 :
------------------------------
Inside ct60tos.bin, there are a boot menu if the entry of the 
favourite OS inside CT60CONF.CPX is <> '-'.
You can select TOS, MagiC or Linux, value is stored inside the NVM.
- With MagiC the ct60tos try to found magic.ram inside the main 
directory of the boot folder.
- With Linux the ct60tos try to found bootargs inside the main 
directory of the boot folder. Tested with the kernel 2.4.25.
Sure you can always use magxboot.prg or ataboot.prg inside the AUTO 
folder (this programs are in this archive).
