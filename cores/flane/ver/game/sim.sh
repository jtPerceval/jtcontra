#!/bin/bash

eval `jtcfgstr -target=mist -output=bash -parse ../../hdl/jtflane.def |grep _START`

jtsim_sdram

# Generic simulation script from JTFRAME
jtsim -mist -sysname flane  \
    -d JT51_NODEBUG  -d JTFRAME_SIM_ROMRQ_NOCHECK \
    $*
