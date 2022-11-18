#!/bin/bash

ln -srf $ROM/mx5000.rom rom.bin

touch gfx2_cfg.hex gfx1_cfg.hex

jtsim -d JT51_NODEBUG $*
