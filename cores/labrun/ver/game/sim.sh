#!/bin/bash

ROMFILE=$ROM/tricktrp.rom

if [ ! -e $ROMFILE ]; then
    echo "Missing $ROMFILE"
    exit 1
fi

ln -srf $ROMFILE rom.bin

touch gfx_cfg.hex
# Generic simulation script from JTFRAME
jtsim -d JTFRAME_DWNLD_PROM_ONLY $*
