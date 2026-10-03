Reconstruction status
=====================

Every commit from the TOS060 2.02 Beta 11 source release on was built from a clean
checkout with the toolchain it carries and compared with the image released for it:

- TOS part (CTPCI 0x00000-0xBFFFF, FireBee 0x00000-0x9FFFF): byte compare, date
  stamps included
- drivers: unpacked and compared section by section; addresses that are relocated
  are compared by what they point to

Commits
-------

| commit | date | subject | images in the commit | built from the commit vs released image |
|---|---|---|---|---|
| 4588110 | 2012-07-03 | CT60/CTPCI TOS 2.02 beta 11: source release, build for wongck | CT60: our build, CTPCI: released, FireBee: our build | CTPCI TOS part identical; drivers identical |
| c9fd061 | 2026-10-02 | Pinned cross toolchain for the TOS and drivers images |  |  |
| 6c0512c | 2012-11-11 | CT60/CTPCI TOS 2.02 beta 11: optional XHDI/SCSI, DMA lock | CT60: our build, CTPCI: released, FireBee: our build | CTPCI TOS part identical; drivers 140/141 sections identical |
| 6d3992a | 2012-11-28 | CT60/CTPCI TOS 2.02 beta 12: IDE reset, PCI BIOS test builds | CT60: our build, CTPCI: released, FireBee: our build | CTPCI TOS part identical; drivers 140/141 sections identical |
| 690ede0 | 2012-12-01 | FireTOS 2.02 beta 12: USB keyboard debug output | CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 168/175 sections identical |
| 73ae840 | 2012-12-02 | FireTOS 2.02 beta 12: USB keyboard country code | CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 170/175 sections identical |
| 28545ef | 2012-12-17 | FireTOS 2.02 beta 12: USB keyboard Shift fix | CT60: our build, CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 170/175 sections identical |
| 16e8c6e | 2012-12-18 | FireTOS 2.02 beta 12: IDE LBA48, ST-RAM in FPGA RAM | CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 170/175 sections identical |
| 5984cbe | 2013-01-01 | FireTOS 2.02 beta 12: fix logbase and VNC server | FireBee: released | FireBee TOS part identical; drivers 170/175 sections identical |
| 0fde017 | 2013-01-12 | FireTOS 2.02 beta 13: monochrome support | CT60: our build, CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| 58d489c | 2013-01-20 | FireTOS 2.02 beta 13: ST-RAM in FPGA RAM removed | FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| 68d4966 | 2013-02-03 | FireTOS 2.02 beta 13: EmuTOS fixes | CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| 58b2a6a | 2014-01-08 | FireTOS 2.02 beta 14: USB hub and 200 Hz timer fixes | CT60: our build, CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| 9cea64e | 2014-01-09 | FireTOS 2.02 beta 14: rebuild | FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| 6d178f8 | 2014-01-09 | FireTOS 2.02 beta 14: IDE LBA48 only above 128 GB | CT60: our build, CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| f6882c5 | 2014-01-15 | FireTOS 2.02 beta 15: SD card plug and play | CT60: our build, CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| baaca6d | 2014-01-21 | FireTOS 2.02 beta 15: SD card partitions, USB fix | CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| 34a14d1 | 2014-03-11 | FireTOS 2.02 beta 15: IKBD clock boot hang fix | CT60: our build, CTPCI: our build, FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| 918e8d4 | 2014-03-16 | FireTOS 2.02 beta 15: EmuTOS exception display | FireBee: released | FireBee TOS part identical; drivers 177/179 sections identical |
| 465af62 | 2018-07-18 | FireTOS 2.02 beta 15, MCS binary patch ver.9 | FireBee: released | FireBee TOS part: layout shifted (MCS patches as source); drivers 176/179 sections identical |
| f756dc3 | 2019-10-09 | FireTOS 2.02 beta 15, MCS binary patch ver10 | FireBee: released | FireBee TOS part: layout shifted (MCS patches as source); drivers 176/179 sections identical |
| c96493a | 2026-10-02 | gcc-4.6.4: Drivers: no d0 in the fallback clobber list of the trap bindings |  |  |
| dbb4cd8 | 2026-10-02 | gcc-4.6.4: Drivers: old XBIOS names in work.c |  |  |
| d9dd5f0 | 2026-10-02 | gcc-4.6.4: CD: include <mint/sysvars.h> |  |  |
| ece2835 | 2026-10-02 | gcc-4.6.4: lwIP: keep the fd_set and select() of <sys/select.h> out |  |  |
| 015da4c | 2026-10-02 | gcc-4.6.4: Build with the MiNT gcc 4.6.4 toolchain | CT60: our build, CTPCI: our build, FireBee: our build |  |
| a45a3bb | 2026-10-02 | gcc-4.6.4: BUGFIX: build with -fno-delete-null-pointer-checks | CT60: our build, CTPCI: our build, FireBee: our build |  |
| 08a3bbb | 2026-10-02 | BUGFIX: FireBee MMU: save all registers in the TLB miss handler | FireBee: our build |  |
| 90a3934 | 2026-10-02 | UNTESTED: USB EHCI: 32-bit register accesses |  |  |
| 23b0f5f | 2026-10-02 | BUGFIX: CT60/CTPCI TOS 2.02 beta 11: source release, build for wongck | CTPCI: our build |  |
| 296334a | 2026-10-02 | BUGFIX: CT60/CTPCI TOS 2.02 beta 11: source release, build for wongck | FireBee: our build |  |
| e22a88f | 2026-10-02 | BUGFIX: CT60/CTPCI TOS 2.02 beta 11: optional XHDI/SCSI, DMA lock | CT60: our build, CTPCI: our build |  |
| 8c897b5 | 2026-10-02 | BUGFIX: CT60/CTPCI TOS 2.02 beta 11: optional XHDI/SCSI, DMA lock | CT60: our build, CTPCI: our build |  |
| 2ce5220 | 2026-10-02 | BUGFIX: CT60/CTPCI TOS 2.02 beta 12: IDE reset, PCI BIOS test builds | CT60: our build, CTPCI: our build |  |
| 47c0828 | 2026-10-02 | BUGFIX: FireTOS 2.02 beta 14: IDE LBA48 only above 128 GB | CT60: our build, CTPCI: our build, FireBee: our build |  |
| 1489ba0 | 2026-10-02 | BUGFIX: FireTOS 2.02 beta 15: SD card partitions, USB fix | CTPCI: our build, FireBee: our build |  |
| 7675ab4 | 2026-10-02 | BUGFIX: FireTOS 2.02 beta 15, MCS binary patch ver.9 | FireBee: our build |  |
| 5115b2e | 2026-10-02 | BUGFIX: FireTOS 2.02 beta 15, MCS binary patch ver.9 | FireBee: our build |  |
| 2bbf27b | 2026-10-03 | BUGFIX: CT60/CTPCI TOS 2.02 beta 11: source release, build for wongck | CT60: our build, CTPCI: our build |  |
| 9cc3c6b | 2026-10-03 | BUGFIX: CT60/CTPCI TOS 2.02 beta 12: IDE reset, PCI BIOS test builds | CT60: our build, CTPCI: our build |  |
| 0385483 | 2026-10-03 | BUGFIX: CT60/CTPCI TOS 2.02 beta 11: source release, build for wongck | CT60: our build, CTPCI: our build, FireBee: our build |  |
| 1371850 | 2026-10-03 | BUGFIX: CT60/CTPCI TOS 2.02 beta 11: source release, build for wongck | CT60: our build, CTPCI: our build, FireBee: our build |  |
| 2b21b63 | 2026-10-03 | BUGFIX: CT60/CTPCI TOS 2.02 beta 11: source release, build for wongck | CT60: our build, CTPCI: our build, FireBee: our build |  |

Remaining differences
---------------------

All of them are compiler output, not source: gcc 4.4.2 chooses registers and
instruction order depending on how many declarations it has seen before a function,
so a few declarations more in the original source files (which are lost) give
byte-different but equivalent code. In every case the code does the same; the
commits concerned say so.

- CTPCI Beta 11 of 11.11.2012 and Beta 12: `rtl8139_interrupt`, 2 instructions in
  another order
- FireTOS, all images: `EraseFlash` (amd_flash.c), 2 instructions in another order;
  flash commands and memory accesses are identical
- FireTOS Beta 12 (01.12.2012 to 01.01.2013): parts of `init`, `vsetscreen`,
  `c_blit_area`/`c_line_draw` and the lwIP monitor commands; the first build also
  `usb_kbd_translate`
- FireTOS from 03.02.2013 on: lwIP monitor commands `ping` (2 instructions) and,
  in the last beta 15, `md` (5 instructions)
- FireTOS from 12.01.2013 on: `xbios.c` matches with one declaration order chosen to
  stand in for an unknown extra declaration
- MCS ver.9 and ver10: the MCS changes are source here instead of binary patches at
  fixed addresses, so the code after them sits at other addresses, and the blitter
  copy is part of the drivers' memcpy instead of a jump patched into it at runtime

Images that were never released (our builds) are not verified against anything.
