#!/bin/bash

eval `jtcfgstr -target=mist -output=bash -parse ../../hdl/jtmx5k.def |grep _START`

jtsim_sdram
# Generic simulation script from JTFRAME
jtsim -mist -sysname mx5k  \
    -d JT51_NODEBUG  \
    $*
