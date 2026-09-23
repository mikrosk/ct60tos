#!/bin/bash
TOS=setup.tos
sed -i '/^#define SETUP_STANDALONE .*/ s//#define SETUP_STANDALONE 0/' config.h
make clean
make
upx --best --nrv2e --small --small $TOS
ID=$(tail -c+281 $TOS | head -c 4)
m68k-atari-mint-flags $TOS -l -r -a
if [ "$ID" != "UPX!" ]; then
  echo UPX compressed file needed!
  exit
fi
make firmware

sed -i '/^#define SETUP_STANDALONE .*/ s//#define SETUP_STANDALONE 1/' config.h
make clean
make
upx --best --nrv2e --small --small $TOS
mv setup.tos ../../../setup
make clean

