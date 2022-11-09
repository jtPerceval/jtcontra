    // From this line down, do not modify ports manually:
    input   [21:0]  prog_addr,
    input   [ 7:0]  prog_data,
    input           prog_we,
    input   [ 1:0]  prog_ba,
    input   [24:0]  ioctl_addr,
`ifdef JTFRAME_PROM_START
    input           prom_we,
`endif
`ifdef JTFRAME_HEADER
    input           header,
`endif
`ifdef JTFRAME_IOCTL_RD
    input           ioctl_ram,
    output   [ 7:0] ioctl_din,
`endif


    output   [14:0] snd_addr,
    input    [ 7:0] snd_data,
    output          snd_cs,
    input           snd_ok,

    output   [18:1] gfx1_addr,
    input    [15:0] gfx1_data,
    output          gfx1_cs,
    input           gfx1_ok,

    output   [17:0] pcma_addr,
    input    [ 7:0] pcma_data,
    output          pcma_cs,
    input           pcma_ok,

    output   [17:0] pcmb_addr,
    input    [ 7:0] pcmb_data,
    output          pcmb_cs,
    input           pcmb_ok,

    output   [17:0] main_addr,
    input    [ 7:0] main_data,
    output          main_cs,
    input           main_ok
