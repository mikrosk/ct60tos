CT60 patches for 1.04a firmware
-------------------------------

CTPCI is heavy on the bus, and cause problems when running at high speed with
a Rev5 cpu. So I added the possibility to downclock the cpu below 66MHz.

2010-04-09:

Added downclocking support to 50MHz (for revisions 1 to 5 of 060 CPU).
Supported clock ranges:
 50-75MHz (for rev1 to 5)
 66-110MHz (for rev6)

Patches to apply against ct60-1.04a 20090928 flash.tos directory
001-version.diff: Modified version
002-downclock.diff: Allow downclocking to 50MHz
003-*-setup.diff: Add setup
004-mintlib.diff: Patches for latest mintlib
005-duplicate.diff: Remove some duplicate definitions
006-oformat.diff: Fix in Makefile for ld oformat parameter
007-string.diff: Mising " in a string
008-forward-decl.diff: Fixes for gcc 2.95

2009-07-08:

Added setup application.

BEWARE: Keep your current ct60tos.bin file somewhere, so you can reflash it if
it does not work for you, and must reflash it from 030 mode.


2009-06-27:

Added patch (also present in 1.04) in VT52 emulation, where setting a new
background color was not working.


2009-04-21:

Added patch (also present in 1.04) to support STMicro flash chip.

-- 
Patrice Mandin <patmandin@gmail.com>
http://pmandin.atari.org
