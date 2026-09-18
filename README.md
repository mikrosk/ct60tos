This is CT60 TOS 3.00 based on 1.03f. It contains the complete archive with updated both sources and binaries.

The CT60 manual is included in `doc`, readable online as [English](https://tho-otto.m68k.eu/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/ct60tos-1.03x/doc/english/ct60.hyp) or [French](https://tho-otto.m68k.eu/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/ct60tos-1.03x/doc/french/ct60.hyp). It hasn't been updated with latest additions but it is a good guide for answering generic CT60 questions.

This is a new generation of CT60 TOS builds: it boots directly into SuperVidel's extended resolutions and offers SuperVidel configuration via CT60CONF.CPX. In the future it might even support CTPCI the same way.

You still need to boot NVDI 5.0x to get proper (and accelerated) 8bpp / 32bpp chunky support. Pressing LSHIFT skips the SuperVidel XBIOS installation but doesn't if SuperVidel is present, it still doesn't detect the Videl clocks to avoid the infamous lockup.

There are two other branches which you may find interesting:

The [ct60tos-1.03x](https://github.com/mikrosk/ct60tos/tree/ct60tos-1.03x) branch contains latest "plain" CT60 TOS build. CT60 TOS 3.x will be always based on its latest version, i.e. all generic fixes will go to 1.03x as well.

The [ctpcitos](https://github.com/mikrosk/ct60tos/tree/ctpcitos) branch contains Didier's la(te)st work (CT60/CTPCI TOS 2.02 beta), including source code for both the OS and drivers. See its `README.md` for the (convoluted) way how that branch is organised.

Website source files are available in the [gh-pages branch](https://github.com/mikrosk/ct60tos/tree/gh-pages).

You might be interested in [insane/tscc](http://insane.tscc.de)'s work on [CT60TOS 1.05](https://github.com/insane-rabenauge/ct60tos) which merged pieces of CT60TOS 1.03x, Patrice Mandin's [BIOS setup](https://github.com/mikrosk/ct60tos/commit/e583a8aa) and of course many improvements.
