#! /bin/bash

##### Configuration Variables

MULTIPLIER="140"
CONFIRMATION_THRESHOLD="160"
SPLASH_SCREEN_WAIT_TIME="500"
EXIT_WAIT_TIME="-1"
IMAGE_NAME='BootFID_${VERSION}_${MULT_NAME}_disk.img'

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

IMAGE_NAME="$(eval echo $IMAGE_NAME)"

nasm -DBF_VERSION="'${VERSION}'" \
     -DCREDITS \
     -DFID_SET="$MULTIPLIER" \
     -DCONFIRMATION_THRESHOLD=$CONFIRMATION_THRESHOLD \
     -DSPLASH_SCREEN_WAIT_TIME=$SPLASH_SCREEN_WAIT_TIME \
     -DEXIT_WAIT_TIME=$EXIT_WAIT_TIME \
     -DSMBIOS \
     smpboot.asm
nasm -o "$IMAGE_NAME" \
     -DSMALL_IMG \
     bootsector.asm
