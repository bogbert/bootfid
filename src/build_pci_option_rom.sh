#! /bin/bash

##### Configuration Variables

LOAD_SEGMENT="0xD000"
MULTIPLIER="140"
CONFIRMATION_THRESHOLD="160"
ROM_NAME='BootFID_${VERSION}_${MULT_NAME}_pci.rom'

##### Building of the binary

source version.sh

if [ "$MULTIPLIER" == "'cmos'" ]
then
    MULT_NAME="cmos"
elif [ "$MULTIPLIER" -eq 0 ]
then
    MULT_NAME="disabled"
else
    MULT_NAME="m$MULTIPLIER"
fi

ROM_NAME="$(eval echo ${ROM_NAME})"

nasm -DBF_VERSION="'${VERSION}'" \
     -DLOAD_SEGMENT=$LOAD_SEGMENT \
     -DFID_SET="$MULTIPLIER" \
     -DCONFIRMATION_THRESHOLD=$CONFIRMATION_THRESHOLD \
     -DBUILD_TYPE="'pci'" \
     smpboot.asm
nasm -o "${ROM_NAME}" option_rom.asm
#gcc -o rom_checksum -mno-cygwin rom_checksum.c
rom_checksum "${ROM_NAME}"
