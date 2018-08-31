#! /bin/bash

##### Configuration Variables

IMAGE_NAME_PATTERN='BootFID_${VERSION}_${MULT_NAME}_disk.img'

##### Building of the image files

source version.sh
for MULTIPLIER in "'cmos'" 000 030 040 050 055 060 065 070 075 080 085 090 095 \
                   100 105 110 115 120 125 130 135 140 150 160 165 170 180 190 \
                   200 210 220 230 240
do
    if [ "$MULTIPLIER" == "'cmos'" ]
    then
        MULT_NAME="cmos"
    elif [ "$MULTIPLIER" -eq 0 ]
    then
        MULT_NAME="disabled"
    else
        MULT_NAME="m$MULTIPLIER"
    fi
    IMAGE_NAME="$(eval echo $IMAGE_NAME_PATTERN)"

    nasm -DFID_SET="$MULTIPLIER" -DBF_VERSION="'${VERSION}'" smpboot.asm
    nasm -o "$IMAGE_NAME" bootsector.asm
done
