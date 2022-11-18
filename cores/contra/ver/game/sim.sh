#!/bin/bash

touch gfx2_cfg.hex gfx1_cfg.hex

if [ ! -e rom.bin ]; then
    ln -rs $ROM/contra.rom rom.bin
    # Quickly convert from rom.bin to the SDRAM dump
    # bin2hex <rom.bin >sdram_bank0.hex
fi

# Generic simulation script from JTFRAME
jtsim -d JTFRAME_DWNLD_PROM_ONLY -d JT51_NODEBUG $*
