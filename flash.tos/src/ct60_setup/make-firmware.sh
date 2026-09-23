#!/bin/bash
#
# Build the setup twice: as setup.bin, the image setup_firmware.S patches into
# the flash, and as the standalone ../../../setup/setup.tos.  Both are UPX
# compressed, the flash one has to be to fit into the free space at the end of
# the TOS 4.04 area.
#
set -e
cd "$(dirname "$0")"

UPX="upx --best --nrv2e --small --small"

make clean
make EXTRA_CFLAGS=-DSETUP_STANDALONE=0
$UPX setup.tos
if [ "$(tail -c+281 setup.tos | head -c 4)" != "UPX!" ]; then
  echo "UPX compressed file needed!"
  exit 1
fi
mv setup.tos setup.bin

make clean
make
$UPX setup.tos
mv setup.tos ../../../setup/setup.tos

make clean
