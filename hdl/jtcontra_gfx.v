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

// Main features of Konami's 007121 hardware
// Some elements have been factored out one level up (H/S timing...)

module jtcontra_gfx(
    input                rst,
    input                clk,
    input                clk24,
    input                pxl2_cen,
    input                pxl_cen,
    input                LHBL,
    input                LVBL,
    input                HS,
    input                VS,
    input   [8:0]        hdump,
    input   [8:0]        vdump,
    input   [8:0]        vrender,
    input   [8:0]        vrender1,
    output               flip,
    // PROMs
    input      [ 8:0]    prog_addr,
    input      [ 3:0]    prog_data,
    input                prom_we,
    // CPU      interface
    input                vram_cs,
    input                cfg_cs,
    input                cpu_rnw,
    input                cpu_cen,
    input      [12:0]    cpu_addr,
    input      [ 7:0]    cpu_dout,
    output     [ 7:0]    gfx_dout,
    output reg           cpu_irqn,
    // SDRAM interface
    output reg [17:0]    rom_addr,
    input      [15:0]    rom_data,
    input                rom_ok,
    output reg           rom_cs,
    // colour output
    output reg [ 6:0]    pxl_out,
    // test
    input      [ 1:0]    gfx_en
);

parameter H0 = 9'h75; // initial value of hdump after H blanking

reg         last_LVBL;
wire        gfx_we = cpu_cen & ~cpu_rnw & vram_cs;

wire        line;
wire [9:0]  line_addr;
wire [7:0]  chr_pxl, scr_pxl, line_din;

////////// Memory Mapped Registers
reg  [7:0]  mmr[0:7];
wire [8:0]  hpos = { mmr[1][0], mmr[0] };
wire [7:0]  vpos = mmr[2];
wire [4:0]  tile_extra = { mmr[3][0], mmr[4][3:0] };
wire        obj_page   = mmr[3][3]; // select from which page to draw sprites
wire        layout     = mmr[3][4]; // 1 for wide layout
wire [3:0]  extra_mask = mmr[4][7:4];
wire [1:0]  code9_sel, code10_sel, code11_sel, code12_sel;
wire        nmi_en     = mmr[7][0];
wire        irq_en     = mmr[7][1];
wire        firq_en    = mmr[7][2];
assign      flip       = mmr[7][3];
wire        pal_msb    = mmr[6][0];
wire        hflip_en   = mmr[6][1];
wire        vflip_en   = mmr[6][2];
wire        prio_en    = mmr[6][3];
wire [1:0]  pal_bank   = mmr[6][5:4];
wire        char_en    = 1;
// wire        char_en    =~mmr[7][4];     // undocumented by MAME

assign      { code12_sel, code11_sel, code10_sel, code9_sel } = mmr[5];

// Other configuration
reg  [8:0]  chr_dump_start;
reg  [8:0]  chr_dump_end;
reg  [8:0]  scr_dump_start;
reg  [8:0]  scr_dump_end;

// Scan
wire [10:0] scan_addr;
wire [10:0] ram_addr = { cpu_addr[11], cpu_addr[9:0] };
wire        attr_we  = gfx_we & ~cpu_addr[10] & ~cpu_addr[12];
wire        code_we  = gfx_we &  cpu_addr[10] & ~cpu_addr[12];
wire        obj_we   = gfx_we &  cpu_addr[12];
wire [7:0]  code_dout, attr_dout, obj_dout, obj_pxl;
assign      gfx_dout = cpu_addr[12] ? obj_dout : 
                      (cpu_addr[10] ? code_dout : attr_dout);
wire [ 7:0] code_scan, attr_scan, obj_scan;

reg  [ 7:0] vprom_addr;
wire [ 3:0] vprom_data, oprom_data;

wire [9:0]  line_dump;

wire        rom_obj_cs, rom_scr_cs;
wire [17:0] rom_scr_addr, rom_obj_addr;

assign      line_dump = { ~line, hdump };

// local SDRAM mux
reg  [ 1:0] data_sel;
reg         rom_scr_ok, rom_obj_ok;
reg  [15:0] rom_scr_data, rom_obj_data;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs   <= 0;
        rom_addr <= 18'd0;
        data_sel <= 2'b00;
    end else begin
        if( data_sel==2'b00 ) begin
            if( rom_scr_cs ) begin
                rom_cs     <= 1;
                rom_addr   <= rom_scr_addr;
                rom_scr_ok <= 0;
                data_sel   <= 2'b01;
            end else if( rom_obj_cs ) begin
                rom_cs     <= 1;
                rom_addr   <= rom_obj_addr;
                rom_obj_ok <= 0;
                data_sel   <= 2'b10;
            end
            else rom_cs <= 0;
        end else if( rom_ok ) begin
            if( data_sel[0] ) begin
                rom_scr_data <= rom_data;
                rom_scr_ok   <= 1;
            end
            if( data_sel[1] ) begin
                rom_obj_data <= rom_data;
                rom_obj_ok   <= 1;
            end
            data_sel <= 2'b00;
            rom_cs   <= 0;
        end
    end
end

always @(posedge clk24) begin
    if( rst ) begin
        { mmr[7], mmr[6], mmr[5], mmr[4] } <= 32'd0;
        { mmr[3], mmr[2], mmr[1], mmr[0] } <= 32'd0;
    end else if(cpu_cen) begin
        if(!cpu_rnw && cfg_cs)
            mmr[ cpu_addr[2:0] ] <= cpu_dout;
        // Apply layout
        if( layout ) begin
            // total 35*8 = 280 visible pixels
            chr_dump_start <= 9'h74;
            chr_dump_end   <= chr_dump_start+(9'd5<<3);
            scr_dump_start <= chr_dump_end;
            scr_dump_end   <= scr_dump_start+(9'd30<<3);
        end else begin
            // total 32*8 = 256 visible pixels
            chr_dump_start <= 9'h74+(9'd2<<3);
            chr_dump_end   <= chr_dump_start+(9'd32<<3);
            scr_dump_start <= chr_dump_start;
            scr_dump_end   <= chr_dump_end;
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        cpu_irqn <= 1;
    end else if(pxl_cen) begin
        last_LVBL <= LVBL;
        if( !LVBL && last_LVBL ) begin
            if( irq_en ) cpu_irqn <= 0;
        end
        else if( LHBL ) cpu_irqn <= 1;
    end
end

// Local colour mixer
wire [ 7:0] scr_pxl_gated = {8{gfx_en[1]}} & scr_pxl;
wire [ 7:0] chr_pxl_gated = {8{gfx_en[0] & char_en}} & chr_pxl;
wire        chr_blank     = chr_pxl_gated[3:0] == 4'h0;
wire        obj_blank     = oprom_data[3:0] == 4'h0;
wire        chr_area      = hdump>=chr_dump_start && hdump<chr_dump_end;
wire        scr_area      = hdump>=scr_dump_start && hdump<scr_dump_end;
reg         draw_scr;
wire [11:0] obj_scan_addr;

always @(*) begin
    draw_scr <= ( chr_area && !scr_area) ? 0 : (
                (!chr_area &&  scr_area) ? 1 : (
                 chr_blank ? 1 : 0 ));
end

always @(posedge clk) begin
    if( rst ) begin
        pxl_out    <= ~7'd0;
        vprom_addr <= 8'd0;
    end else begin
        vprom_addr <= draw_scr ? scr_pxl_gated : chr_pxl_gated;
        if(pxl_cen) begin
            pxl_out[6:5] <= pal_bank;
            if( obj_blank )
                pxl_out <= { 1'b1, vprom_data };
            else
                pxl_out <= { 1'b0, oprom_data };
        end
    end
end

jtcontra_gfx_tilemap u_tilemap(
    .rst                ( rst               ),
    .clk                ( clk               ),
    // screen
    .LHBL               ( LHBL              ),
    .LVBL               ( LVBL              ),
    .hpos               ( hpos              ),
    .vpos               ( vpos              ),
    .vrender            ( vrender           ),
    .lyr                ( lyr               ),
    .line               ( line              ),
    .line_addr          ( line_addr         ),
    .done               ( done              ),
    .chr_we             ( chr_we            ),
    .scr_we             ( scr_we            ),
    .line_din           ( line_din          ),
    .scan_addr          ( scan_addr         ),
    // SDRAM
    .rom_cs             ( rom_scr_cs        ),
    .rom_addr           ( rom_scr_addr      ),
    .rom_ok             ( rom_scr_ok        ),
    .rom_data           ( rom_scr_data      ),
    .attr_scan          ( attr_scan         ),
    .code_scan          ( code_scan         ),
    // Configuration
    .chr_dump_start     ( chr_dump_start    ),
    .scr_dump_start     ( scr_dump_start    ),
    .pal_msb            ( pal_msb           ),
    .code9_sel          ( code9_sel         ),
    .code10_sel         ( code10_sel        ),
    .code11_sel         ( code11_sel        ),
    .code12_sel         ( code12_sel        )
);

jtcontra_gfx_obj u_obj(
    .rst                ( rst               ),
    .clk                ( clk               ),
    .start              ( LHBL              ),
    .LVBL               ( LVBL              ),
    .vrender            ( vrender           ),
    .done               (                   ),
    .scan_addr          ( obj_scan_addr[9:0]),
    .line_dump          ( line_dump         ),
    .pxl                ( obj_pxl           ),
    // SDRAM
    .rom_cs             ( rom_obj_cs        ),
    .rom_addr           ( rom_obj_addr      ),
    .rom_ok             ( rom_obj_ok        ),
    .rom_data           ( rom_obj_data      ),
    .obj_scan           ( obj_scan          )
);

assign obj_scan_addr[11] = obj_page;
assign obj_scan_addr[10] = 1'b0;

// Colour PROMs

jtframe_prom #(.dw(4),.aw(8) ) u_vprom(
    .clk        ( clk                       ),
    .cen        ( 1'b1                      ),
    .data       ( prog_data                 ),
    .rd_addr    ( vprom_addr                ),
    .wr_addr    ( prog_addr[7:0]            ),
    .we         ( prom_we & prog_addr[8]    ),
    .q          ( vprom_data                )
);

jtframe_prom #(.dw(4),.aw(8) ) u_oprom(
    .clk        ( clk                       ),
    .cen        ( 1'b1                      ),
    .data       ( prog_data                 ),
    .rd_addr    ( obj_pxl                   ),
    .wr_addr    ( prog_addr[7:0]            ),
    .we         ( prom_we & ~prog_addr[8]   ),
    .q          ( oprom_data                )
);

// Line buffers could work with only AW=9 but it would
// make logic a bit more complex without any benefit in
// the FPGA, as the minimum size BRAM available is normally AW=10
jtframe_dual_ram #(.aw(10)) u_line_char(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( line_din  ),
    .addr0  ( line_addr ),
    .we0    ( chr_we    ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( line_dump ),
    .we1    ( 1'b0      ),
    .q1     ( chr_pxl   )
);

jtframe_dual_ram #(.aw(10)) u_line_scr(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( line_din  ),
    .addr0  ( line_addr ),
    .we0    ( scr_we    ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( line_dump ),
    .we1    ( 1'b0      ),
    .q1     ( scr_pxl   )
);

jtframe_dual_ram #(.aw(11)) u_attr_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( ram_addr  ),
    .we0    ( attr_we   ),
    .q0     ( attr_dout ),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( attr_scan )
);

jtframe_dual_ram #(.aw(11)) u_code_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( ram_addr  ),
    .we0    ( code_we   ),
    .q0     ( code_dout ),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( code_scan )
);

jtframe_dual_ram #(.aw(12)) u_obj_ram(
    .clk0   ( clk24         ),
    .clk1   ( clk           ),
    // Port 0
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr[11:0]),
    .we0    ( obj_we        ),
    .q0     ( obj_dout      ),
    // Port 1
    .data1  (               ),
    .addr1  ( obj_scan_addr ),
    .we1    ( 1'b0          ),
    .q1     ( obj_scan      )
);

endmodule