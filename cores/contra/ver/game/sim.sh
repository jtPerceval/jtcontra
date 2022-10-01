#!/bin/bash

if [ ! -e sdram.hex ]; then
    ln -sf $ROM/contra.rom rom.bin
    bin2hex <rom.bin >sdram_bank0.hex
fi

export MEM_CHECK_TIME=210_000_000
export CONVERT_OPTIONS="-resize 300%x300%"

# Generic simulation script from JTFRAME
jtsim -mist -sysname contra  \
    -d JTFRAME_DWNLD_PROM_ONLY \
    -d JT51_NODEBUG  \
    $*
