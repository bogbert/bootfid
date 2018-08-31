#! /bin/bash

##### Configuration Variables

LOAD_SEGMENT="0xEC00"
MULTIPLIER="'cmos'"
CONFIRMATION_THRESHOLD="160"
ORIG_ROM_NAME="cav_shdw.bin"

# PATCHED_ROM_NAME is a pattern, variables are substituted later
PATCHED_ROM_NAME='cav_shdw_bf_${VERSION}-${MULT_NAME}.bin'

# NB: INJECTION_OFFSET=3 would have been a natural choice, but it would have
# overridden the byte at offset 5 (I don't know what this byte is used for, as
# it doesn't seem to be used for checksum in this ROM), so I chose to leave
# the ROM header alone and use INJECTION_OFFSET=12 which is the target of the
# short jump at offset 3.
INJECTION_OFFSET="12"   # = 0x0C
BOOTFID_OFFSET=$(stat -c%s "$ORIG_ROM_NAME")

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

PATCHED_ROM_NAME="$(eval echo ${PATCHED_ROM_NAME})"

nasm -o "$PATCHED_ROM_NAME" \
     -DBF_VERSION="'${VERSION}'" \
     -DCREDITS \
     -DLOAD_SEGMENT=$LOAD_SEGMENT \
     -DFID_SET="$MULTIPLIER" \
     -DSMBIOS \
     -DCONFIRMATION_THRESHOLD=$CONFIRMATION_THRESHOLD \
     -DBUILD_TYPE="'injection'" \
     -DORIG_ROM_PATH="'$ORIG_ROM_NAME'" \
     -DINJECTION_OFFSET=$INJECTION_OFFSET \
     smpboot.asm
#gcc -o patch_for_injection -mno-cygwin patch_for_injection.c
patch_for_injection "${PATCHED_ROM_NAME}" $INJECTION_OFFSET $BOOTFID_OFFSET

# Comments:
# . it seems that size of 'cav_shdw.bin' doesn't have to be a multiple of 512
# . it seems that the checksum of 'cav_shdw.bin' doesn't have to be zero, but
#   patch_for_injection sets it to zero anyway, it's not needed but that doesn't
#   seem to hurt neither
# . it seems that the value of the byte at offset 2 doesn't describe the size of
#   the 'cav_shdw.bin' ROM itself, but the memory size (in units of 512 bytes)
#   reserved for the module by the BIOS. I guess this size has to be larger than
#   the size of patched 'cav_shdw.bin' file. The original size in the version of
#   'cav_shdw.bin' I worked with, is 0x20, which is more than enough, so I did
#   not take the pain to care about this setting