This is archived content of all publicly known/released CT60 TOS, CTPCI TOS and
FireTOS releases after TOS060 2.01, in both source and binary form.

Up to version 1.04a, CT60 TOS and CTPCI TOS source code was fully available.
Later it was split into TOS060 2.0x and Drivers 1.0x packages where only the latter
had source code available. CTPCI TOS had gradually become FireTOS. With TOS060 2.02
Beta 11 (July 2012) Didier Méquignon published the complete source once more.

This branch has one commit per released image, in release order and dated with the
release (mostly the date of the forum post announcing it):

- before the Beta 11 source release: the released images only (FireTOS 2.02 betas
  1 to 3 of 2011, CTPCI TOS betas 6 to 11 of 2012)
- from the Beta 11 source release on: the released image(s) together with the source
  that builds them. The source of the later releases (CTPCI TOS Beta 11 of 11.11.2012
  and Beta 12, FireTOS betas 12 to 15) and of the MCS binary patches of FireTOS
  (ver.9 and ver10) was reconstructed from the released images
- after the last release: the switch to a current compiler (gcc 4.6.4), fixes
  ("BUGFIX: <the release that introduced the bug>") and changes not tried on
  hardware ("UNTESTED: ...")

Where a release exists, the committed image is the released file. From the source
release on, every commit also carries our build of each other image (CT60
`ct60tos.bin`, CTPCI `ctpcitos.bin`, FireBee `firetos.hex`) whenever its source change
alters that image by more than the build date; their commits say so. A release
commit's message holds the release author's own text (forum post, changelog,
verbatim) and its link; everything written by us follows a `===` line under
"Decompilation notes:".

How exactly each release is reproduced is listed in [STATUS.md](STATUS.md).

Building
--------

The Makefiles use the MiNT gcc 4.6.4 cross toolchain named by `CROSS` (default
`$HOME/gnu-tools-464/m68000/bin/m68k-atari-mint-`):

    make -C flash.tos              (ct60 and firebee)
    make -C flash.tos ct60         (flash.tos/ct60tos.bin, flash.tos/ctpcitos.bin)
    make -C flash.tos firebee      (flash.tos/firetos_firebee.hex)

The `m5484lite` and `m54455evb` targets (ColdFire evaluation boards) do not link:
the FireTOS beta 12 and 13 sources were reconstructed from FireBee images only, and
no image exists for these boards to reconstruct their side from.

Commits from "Pinned cross toolchain for the TOS and drivers images" up to MCS ver10
build with the toolchain of the original releases instead, built by `gnu/` (needs
docker, see `gnu/README`):

    make -C gnu
    make -C flash.tos firebee
    make -C flash.tos ct60

Documentation
-------------

The official documentation by Didier Méquignon available online (released packages can be found in the [releases](https://github.com/mikrosk/ct60tos/releases)):

- [CT60TOS 1.03c](http://www.tho-otto.de/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/1eb9075d63fb3ed776070a097542a191ccff058d/doc/english/ct60.hyp) ([source tree](https://github.com/mikrosk/ct60tos/tree/1eb9075d63fb3ed776070a097542a191ccff058d))
- [CT60TOS 2.01](http://www.tho-otto.de/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/2.01/doc/ct60/english/ct60.hyp) ([source tree](https://github.com/mikrosk/ct60tos/tree/2.01))
- [FireTOS 2.01](http://www.tho-otto.de/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/2.01/doc/firebee/english/firebee.hyp) ([source tree](https://github.com/mikrosk/ct60tos/tree/2.01))
- [CTPCI Drivers 1.01](http://www.tho-otto.de/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/db5de81f0b8bd130dfb04869d67204ec005861d3/doc/CTPCI.hyp) ([source tree](https://github.com/mikrosk/ct60tos/tree/db5de81f0b8bd130dfb04869d67204ec005861d3))

Website source files are available in the [gh-pages branch](https://github.com/mikrosk/ct60tos/tree/gh-pages).
