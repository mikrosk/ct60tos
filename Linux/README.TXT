This ataboot is only for the F030/CT60 and the Videl.

If the Radeon/CTPCI are used, it is possible to avoid that the kernel use 
the Videl, for example with bootargs :

-V 0x4303 -k vmlinuz root=/dev/hda9 video=atafb:external:1920;1080;8;p;0x40000000 

0x4303 is the modecode for the Radeon driver (Vsetscreen) used inside Ataboot.
external is here for the send infos to the kernel (0x40000000 isthe 
screen address, 'p' for packed pixels, 't' for true color).

In this case you must also select Linux boot with CT60CONF.CPX for use 
the internal ataboot (else Videl is used).
For capture the hex value of a modecode you can uuse VIDEOCNF.CPX with 
a double-click inside the list of screens.

