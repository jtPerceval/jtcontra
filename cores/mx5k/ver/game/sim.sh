#!/bin/bash

if [ ! -e $ROMFILE ]; then
    echo "Missing $ROMFILE"
    exit 1
fi

ln -srf $ROMFILE rom.bin

touch gfx2_cfg.hex gfx1_cfg.hex

jtsim -d JT51_NODEBUG $*
