/*  This file is part of JTCONTRA.
    JTCONTRA program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCONTRA program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCONTRA.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 25-8-2021 */

module jtflane_game(
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [4:0]  red,
    output   [4:0]  green,
    output   [4:0]  blue,
    output          LHBL,
    output          LVBL,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input   [31:0]  dipsw,
    input           dip_pause,
    input           service,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [ 3:0]  gfx_en,
    `include "mem_ports.inc"
);

wire        cen12, cen3, cen1p5;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;

wire [13:0] cpu_addr;
wire        gfx_irqn, pal_cs, gfx_ramcs;
wire        cpu_cen, cpu_rnw, cpu_irqn, cpu_nmin;
wire [ 7:0] pal_dout, cpu_dout, gfx_dout;

assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[19:0];


jtframe_cen24 u_cen(
    .clk        ( clk24         ),    // 24 MHz
    .cen12      ( cen12         ),
    .cen8       (               ),
    .cen6       (               ),
    .cen4       (               ),
    .cen3       ( cen3          ),
    .cen3q      (               ), // 1/4 advanced with respect to cen3
    .cen1p5     ( cen1p5        ),
    // 180 shifted signals
    .cen12b     (               ),
    .cen6b      (               ),
    .cen3b      (               ),
    .cen3qb     (               ),
    .cen1p5b    (               )
);

`ifndef NOMAIN
jtflane_main u_main(
    .clk            ( clk24         ),        // 24 MHz
    .rst            ( rst24         ),
    .cen12          ( cen12         ),
    .cen3           ( cen3          ),
    .cpu_cen        ( cpu_cen       ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // cabinet I/O
    .start_button   ( start_button  ),
    .coin_input     ( coin_input    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    // GFX
    .gfx_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),
    .gfx_irqn       ( cpu_irqn      ),
    .gfx_nmin       ( cpu_nmin      ),
    .gfx_cs         ( gfx_ramcs     ),
    .pal_cs         ( pal_cs        ),

    .gfx_dout       ( gfx_dout      ),
    .pal_dout       ( pal_dout      ),

    // PCM sound
    .pcma_addr      ( pcma_addr     ),
    .pcma_dout      ( pcma_data     ),
    .pcma_cs        ( pcma_cs       ),
    .pcma_ok        ( pcma_ok       ),

    .pcmb_addr      ( pcmb_addr     ),
    .pcmb_dout      ( pcmb_data     ),
    .pcmb_cs        ( pcmb_cs       ),
    .pcmb_ok        ( pcmb_ok       ),

    .pcmc_addr      ( pcmc_addr     ),
    .pcmc_dout      ( pcmc_data     ),
    .pcmc_cs        ( pcmc_cs       ),
    .pcmc_ok        ( pcmc_ok       ),

    .pcmd_addr      ( pcmd_addr     ),
    .pcmd_dout      ( pcmd_data     ),
    .pcmd_cs        ( pcmd_cs       ),
    .pcmd_ok        ( pcmd_ok       ),

    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       ),
    // Sound
    .snd            ( snd           ),
    .sample         ( sample        ),
    .peak           ( game_led      )
);
`else
assign main_cs = 0;
`endif

`ifndef NOVIDEO
jtlabrun_video #(.GAME(1))
u_video (
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk24          ( clk24         ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( dip_flip      ),
    .dip_pause      ( dip_pause     ),
    .start_button   ( &start_button ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      ( prog_addr[8:0]),
    .prog_data      ( prog_data[3:0]),
    // GFX - CPU interface
    .cpu_irqn       ( cpu_irqn      ),
    .cpu_nmin       ( cpu_nmin      ),
    .gfx_cs         ( gfx_ramcs     ),
    .pal_cs         ( pal_cs        ),
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_cen        ( cpu_cen       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .gfx_dout       ( gfx_dout      ),
    .pal_dout       ( pal_dout      ),
    // SDRAM
    .gfx_addr       (  gfx_addr     ),
    .gfx_data       (  gfx_data     ),
    .gfx_ok         (  gfx_ok       ),
    .gfx_romcs      (  gfx_cs       ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .gfx_en         ( gfx_en        )
);
`endif

endmodule