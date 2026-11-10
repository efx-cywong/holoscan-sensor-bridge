// SPDX-FileCopyrightText: Copyright (c) 2013-2026 Efinix Inc. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


module fpga (
    input        clk_100m,
    input        sfp0_iface_clk,
    input        pll_locked,

    input        user_sw0,  // active-low soft reset
    output [5:0] led,

    DphyRx4LaneIface.slv dphy_rx1,
    output               cam_en,
    input                cam_sda_IN,
    output               cam_sda_OUT,
    output               cam_sda_OE,
    input                cam_scl_IN,
    output               cam_scl_OUT,
    output               cam_scl_OE,


    input         cmn_inst1_USER_APB_PREADY,
    input  [31:0] cmn_inst1_USER_APB_PRDATA,
    input         cmn_inst1_USER_APB_PSLVERR,
    output [23:0] cmn_inst1_USER_APB_PADDR,
    output        cmn_inst1_USER_APB_PENABLE,
    output        cmn_inst1_USER_APB_PWRITE,
    output        cmn_inst1_USER_APB_PSEL,
    output [31:0] cmn_inst1_USER_APB_PWDATA,

    input         cmn_inst1_PMA_CMN_READY,

    input         sfp0_IRQ,
    input         sfp0_BLOCK_LOCK,
    input  [63:0] sfp0_RXD,
    input  [ 7:0] sfp0_RXC,
    input         sfp0_HI_BER,
    input  [ 3:0] sfp0_PMA_XCVR_POWER_STATE_ACK,
    input         sfp0_PHY_INTERRUPT,
    input         sfp0_PCS_STATUS,
    input         sfp0_PMA_RX_SIGNAL_DETECT,
    input         sfp0_PMA_XCVR_PLLCLK_EN_ACK,
    output [63:0] sfp0_TXD,
    output [ 3:0] sfp0_PMA_XCVR_POWER_STATE_REQ,
    output [ 7:0] sfp0_TXC,
    output        sfp0_PMA_TX_ELEC_IDLE,
    output        sfp0_PHY_RESET_N,
    output        sfp0_PCS_RST_N_RX,
    output        sfp0_ETH_EEE_ALERT_EN,
    output        sfp0_PCS_RST_N_TX,
    output        sfp0_PMA_XCVR_PLLCLK_EN,
    // Unused KR status and training ports.
    // input         sfp0_KR_FRAME_LOCK,
    // input         sfp0_KR_TRAINING_FAILURE,
    // input         sfp0_KR_TRAINING,
    // input         sfp0_KR_SIGNAL_DETECT,
    // input         sfp0_KR_LOCAL_RX_TRAINED,
    // output        sfp0_KR_RESTART_TRAINING,
    // output        sfp0_KR_TRAINING_ENABLE
);

wire rstn_100mhz_int;
wire clk_156m;
wire rst_156mhz_int;
wire i_arstn;
wire startup_release_reset;

assign sfp0_PCS_RST_N_RX = rstn_100mhz_int;
assign sfp0_PCS_RST_N_TX = rstn_100mhz_int;
assign sfp0_PHY_RESET_N = rstn_100mhz_int;
assign i_arstn = user_sw0;

localparam [31:0] HSB_SERDES_ADDR_BASE = 32'h00000000;

wire        sfp0_tx_clk_int;
wire        sfp0_tx_rst_int;
wire        sfp0_rx_clk_int;
wire        sfp0_rx_rst_int;

wire        apb_rom_end_o;
wire        apb_done_o;
wire [15:0] HW_APB_PADDR;
wire        HW_USER_APB_PSEL;
wire        HW_USER_APB_PENABLE;
wire        HW_USER_APB_PREADY;
wire        HW_USER_APB_PWRITE;
wire [31:0] HW_USER_APB_PWDATA;
wire [31:0] HW_USER_APB_PRDATA;
wire        HW_USER_APB_PSLVERROR;


wire        sfp0_reset_done;
wire        sfp1_reset_done;

assign clk_156m = sfp0_iface_clk;
assign sfp0_tx_clk_int = sfp0_iface_clk;
assign sfp0_rx_clk_int = sfp0_iface_clk;

reset #(
    .IN_RST_ACTIVE("LOW"),
    .OUT_RST_ACTIVE("LOW"),
    .CYCLE(2)
) u_reset (
    .i_arst(pll_locked && i_arstn),
    .i_clk (clk_100m),
    .o_srst(rstn_100mhz_int)
);

reset #(
    .IN_RST_ACTIVE("LOW"),
    .OUT_RST_ACTIVE("HIGH"),
    .CYCLE(4)
) tx_reset_sync_inst (
    .i_arst(apb_done_o),
    .i_clk (sfp0_tx_clk_int),
    .o_srst(sfp0_tx_rst_int)
);

reset #(
    .IN_RST_ACTIVE("LOW"),
    .OUT_RST_ACTIVE("HIGH"),
    .CYCLE(4)
) rx_reset_sync_inst (
    .i_arst(apb_done_o),
    .i_clk (sfp0_rx_clk_int),
    .o_srst(sfp0_rx_rst_int)
);

reset #(
    .IN_RST_ACTIVE("LOW"),
    .OUT_RST_ACTIVE("HIGH"),
    .CYCLE(4)
) rst_156mhz_reset_sync_inst (
    .i_arst(apb_done_o && startup_release_reset),
    .i_clk (clk_156m),
    .o_srst(rst_156mhz_int)
);

// HSB APB
logic        hsb_apb_rst;
logic [ 7:0] hsb_apb_psel;
logic        hsb_apb_penable;
logic [31:0] hsb_apb_paddr;
logic [31:0] hsb_apb_pwdata;
logic        hsb_apb_pwrite;
logic [ 7:0] hsb_apb_pready;
logic [31:0] hsb_apb_prdata [7:0];
logic [ 7:0] hsb_apb_pserr;

// SERDES PHY APB MUX
wire hsb_serdes_sel = apb_done_o && hsb_apb_psel[0];
// Return path
assign HW_USER_APB_PREADY = cmn_inst1_USER_APB_PREADY;
assign HW_USER_APB_PRDATA = cmn_inst1_USER_APB_PRDATA;
assign hsb_apb_pready[0] = hsb_serdes_sel ? cmn_inst1_USER_APB_PREADY : 1'b1;
assign hsb_apb_prdata[0] = hsb_serdes_sel ? cmn_inst1_USER_APB_PRDATA : 32'h0;
// Output path
assign cmn_inst1_USER_APB_PSEL    = (apb_done_o == 1'b0) ? HW_USER_APB_PSEL 
                                : hsb_apb_psel[0];
assign cmn_inst1_USER_APB_PWRITE  = (apb_done_o == 1'b0) ? HW_USER_APB_PWRITE
                                : hsb_apb_pwrite;
assign cmn_inst1_USER_APB_PENABLE = (apb_done_o == 1'b0) ? HW_USER_APB_PENABLE
                                : hsb_apb_penable;
assign cmn_inst1_USER_APB_PWDATA  = (apb_done_o == 1'b0) ? HW_USER_APB_PWDATA 
                                : hsb_apb_pwdata;
assign cmn_inst1_USER_APB_PADDR   = (apb_done_o == 1'b0) ? {3'b110, 10'b0, HW_APB_PADDR[10:0]}
                                : {{HSB_SERDES_ADDR_BASE[0 +: 6], hsb_apb_paddr[2 +: 18]}};


localparam RAM_ADDR_W = 5;
localparam ROM_DEPTH = 20;
localparam PADDR_WIDTH = 19;
localparam PDATA_WIDTH = 32;
apb_master #(
    .ROM_MIF    ("efx_rom_mif.mem"),
    .ROM_DEPTH  (ROM_DEPTH),
    .RAM_ADDR_W (RAM_ADDR_W),
    .PADDR_WIDTH(PADDR_WIDTH),
    .PDATA_WIDTH(PDATA_WIDTH)
) q1_apb_master (
    .apb_halt_i   (0),
    .apb_rom_end_o(apb_rom_end_o),
    .apb_done_o   (apb_done_o),

    .ram_usr_wren_i(),
    .ram_usr_addr_i(),
    .ram_dout_d_o  (),
    .ram_dout_a_o  (),

    .usr_apb_start_i (),
    .usr_apb_write_i (),
    .usr_apb_addr_i  (),
    .usr_apb_pwdata_i(),

    .PCLK   (clk_100m),
    .PRESETn(rstn_100mhz_int),
    .PSEL   (HW_USER_APB_PSEL),
    .PWRITE (HW_USER_APB_PWRITE),
    .PENABLE(HW_USER_APB_PENABLE),
    .PADDR  (HW_APB_PADDR),
    .PWDATA (HW_USER_APB_PWDATA),
    .PRDATA (HW_USER_APB_PRDATA),
    .PREADY (HW_USER_APB_PREADY),
    .PSLVERR(0)
);


// HSB external APB slaves [1:7] are idle until wired.
// [0] is the SERDES mux above.
assign hsb_apb_pready[7:1] = 7'h7F;
assign hsb_apb_pserr[7:1]  = 7'h00;
assign hsb_apb_pserr[0]    = 1'b0;
assign hsb_apb_prdata[1] = 32'h0;
assign hsb_apb_prdata[2] = 32'h0;
assign hsb_apb_prdata[3] = 32'h0;
assign hsb_apb_prdata[4] = 32'h0;
assign hsb_apb_prdata[5] = 32'h0;
assign hsb_apb_prdata[6] = 32'h0;
assign hsb_apb_prdata[7] = 32'h0;

// The old Sapphire app.bin held the legacy path in reset for one second,
// then wrote its sw_rstn APB register.  The HSB camera is now configured by
// the host, so replace that fixed boot delay in RTL.
startup_config_fsm #(
    .CLK_HZ    (100_000_000),
    .SETTLE_MS (1000)
) inst_startup_config_fsm (
    .clk          (clk_100m),
    .rstn         (rstn_100mhz_int),
    .release_reset(startup_release_reset)
);

wire w_hsb_init_done;
wire w_cam_active;
wire w_fb_active;
wire w_eth_tx_active;
wire w_eth_rx_active;
assign led[0] = w_hsb_init_done;
assign led[1] = w_cam_active;
assign led[2] = w_eth_tx_active;  // SFP eth TX
assign led[3] = w_eth_rx_active;  // SFP eth RX
assign led[4] = '0;
assign led[5] = '0;

hololink_wrapper inst_hololink_wrapper (
    .clk_100m(clk_100m),
    .clk_156m(clk_156m),
    .clk_100m_rstn(rstn_100mhz_int),
    .clk_156m_rstn(!rst_156mhz_int),
    .mipi_clk(clk_100m),

    .o_hsb_init_done(w_hsb_init_done),
    .o_cam_active(w_cam_active),
    .o_fb_active(w_fb_active),
    .o_eth_rx_active(w_eth_rx_active),
    .o_eth_tx_active(w_eth_tx_active),

    .hsb_apb_rst_o(hsb_apb_rst),
    .hsb_apb_psel_o(hsb_apb_psel),
    .hsb_apb_penable_o(hsb_apb_penable),
    .hsb_apb_paddr_o(hsb_apb_paddr),
    .hsb_apb_pwdata_o(hsb_apb_pwdata),
    .hsb_apb_pwrite_o(hsb_apb_pwrite),
    .hsb_apb_pready_i(hsb_apb_pready),
    .hsb_apb_prdata_i(hsb_apb_prdata),
    .hsb_apb_pserr_i(hsb_apb_pserr),


    .dphy_rx(dphy_rx1),
    .cam_en (cam_en),
    .cam_scl_IN (cam_scl_IN),
    .cam_sda_IN (cam_sda_IN),
    .cam_scl_OUT(cam_scl_OUT),
    .cam_scl_OE (cam_scl_OE),
    .cam_sda_OUT(cam_sda_OUT),
    .cam_sda_OE (cam_sda_OE),

    .init_rst_n(apb_done_o),
    .PMA_CMN_READY(cmn_inst1_PMA_CMN_READY),
    .PMA_XCVR_PLLCLK_EN_ACK(sfp0_PMA_XCVR_PLLCLK_EN_ACK),
    .PMA_XCVR_POWER_STATE_ACK(sfp0_PMA_XCVR_POWER_STATE_ACK),
    .PMA_RX_SIGNAL_DETECT(sfp0_PMA_RX_SIGNAL_DETECT),
    .PMA_XCVR_PLLCLK_EN(sfp0_PMA_XCVR_PLLCLK_EN),
    .PMA_XCVR_POWER_STATE_REQ(sfp0_PMA_XCVR_POWER_STATE_REQ),

    .sfp0_txd(sfp0_TXD),
    .sfp0_txc(sfp0_TXC),
    .sfp0_rxd(sfp0_RXD),
    .sfp0_rxc(sfp0_RXC)
);

endmodule
