#!/bin/sh
# usage: get_version.sh <version in hex> <output file>

echo "#ifndef CT60TOS_VERSION_H_" > $2
echo "#define CT60TOS_VERSION_H_" >> $2
echo -e "\r" >> $2

echo -e "#define VERSION\t$1" >> $2

d=$(date +"%-e,%-m,%-Y,%-k,%-M")
echo -e "#define DATE\t$d" >> $2

echo -e "\r" >> $2
echo "#endif" >> $2
