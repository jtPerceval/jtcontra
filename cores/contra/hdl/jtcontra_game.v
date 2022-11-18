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
    Date: 02-05-2020 */

module jtcontra_game(
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
    input           service,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd_left,
    output  signed [15:0] snd_right,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [ 3:0]  gfx_en,
    // Ports
    `include "mem_ports.inc"
);

// Defines which game to render
`ifndef JTCONTRA_PCB
`define  JTCONTRA_PCB 0
`endif

localparam GAME=`JTCONTRA_PCB;
localparam CONTRA=0;

localparam PROM_START  =  GAME==CONTRA ? 25'h128_000 : 25'h2C_0000;

wire        snd_irq;

wire [ 7:0] snd_latch;
wire        cen12, cen3, cen1p5;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;

wire [15:0] cpu_addr;
wire        gfx1_ramcs, gfx2_ramcs, gfx1_cfg_cs, gfx2_cfg_cs, pal_cs;
wire        gfx1_vram_cs, gfx2_vram_cs;
wire        cpu_cen, cpu_rnw, cpu_irqn, cpu_nmin;
wire [ 7:0] gfx1_dout, gfx2_dout, pal_dout, cpu_dout;
wire [ 7:0] video_bank;
wire        prio_latch;
 
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

`ifdef GFX_ONLY
jtcontra_simloader u_simloader(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    // GFX
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( cpu_rnw       ),
    .gfx1_cs    ( gfx1_ramcs    ),
    .gfx2_cs    ( gfx2_ramcs    ),
    .pal_cs     ( pal_cs        ),
    .video_bank ( video_bank    ),
    .prio_latch ( prio_latch    )
);
`else
`ifndef NOMAIN
jtcontra_main #(.GAME(GAME)) u_main(
    .clk            ( clk24         ),        // 24 MHz
    .rst            ( rst24         ),
    .cen12          ( cen12         ),
    .cpu_cen        ( cpu_cen       ),
    // communication with main CPU
    .snd_irq        ( snd_irq       ),
    .snd_latch      ( snd_latch     ),
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
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),
    .gfx_irqn       ( cpu_irqn      ),
    .gfx_nmin       ( cpu_nmin      ),
    .gfx1_cs        ( gfx1_ramcs    ),
    .gfx2_cs        ( gfx2_ramcs    ),
    .pal_cs         ( pal_cs        ),

    .gfx1_dout      ( gfx1_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),

    .video_bank     ( video_bank    ),
    .prio_latch     ( prio_latch    ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       )
);
`else
// load a sound code for simulation
assign snd_latch = 8'h22;
reg pre_irq=0;
initial begin
    #100_000_000 pre_irq=1;
end

assign snd_irq = pre_irq;
`endif
`endif

`ifndef NOVIDEO
jtcontra_video #(.GAME(GAME)) u_video (
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
    .prog_addr      ( prog_addr[9:0]),
    .prog_data      ( prog_data[3:0]),
    // GFX - CPU interface
    .cpu_irqn       ( cpu_irqn      ),
    .cpu_nmin       ( cpu_nmin      ),
    .gfx1_cs        ( gfx1_ramcs    ),
    .gfx2_cs        ( gfx2_ramcs    ),
    .pal_cs         ( pal_cs        ),
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_cen        ( cpu_cen       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .gfx1_dout      ( gfx1_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),
    .video_bank     ( video_bank    ),
    .prio_latch     ( prio_latch    ),
    // SDRAM
    .gfx1_addr      ( gfx1_addr     ),
    .gfx1_data      ( gfx1_data     ),
    .gfx1_ok        ( gfx1_ok       ),
    .gfx1_romcs     ( gfx1_cs       ),
    .gfx2_addr      ( gfx2_addr     ),
    .gfx2_data      ( gfx2_data     ),
    .gfx2_ok        ( gfx2_ok       ),
    .gfx2_romcs     ( gfx2_cs       ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .gfx_en         ( gfx_en        )
);
`endif

`ifndef NOSOUND
jtcontra_sound u_sound(
    .clk        ( clk24         ), // 24 MHz
    .rst        ( rst24         ),
    .cen12      ( cen12         ),
    .cen3       ( cen3          ),
    .cen1p5     ( cen1p5        ),
    // communication with main CPU
    .snd_irq    ( snd_irq       ),
    .snd_latch  ( snd_latch     ),
    // ROM
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),
    // ADPCM ROM
    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),
    // Sound output
    .snd_left   ( snd_right     ), // channels reversed in
    .snd_right  ( snd_left      ), // the real PCB too
    .sample     ( sample        ),
    .peak       ( game_led      )
);
`else
assign snd_cs   = 0;
assign pcm_cs   = 0;
assign snd_addr = 15'd0;
assign snd_left = 16'd0;
assign snd_right= 16'd0;
assign sample   = 0;
`endif

endmodule