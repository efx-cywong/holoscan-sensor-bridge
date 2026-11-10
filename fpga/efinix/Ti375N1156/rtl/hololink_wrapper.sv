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

`include "HOLOLINK_def.svh"

module hololink_wrapper #(

) (
    input clk_100m,
    input clk_156m,
    input clk_100m_rstn,
    input clk_156m_rstn,
    input mipi_clk,

    output o_hsb_init_done,
    output o_cam_active,
    output o_fb_active,
    output o_eth_rx_active,
    output o_eth_tx_active,

    // -------------------------------------------------------
    // -- APB
    // -------------------------------------------------------
    output          hsb_apb_rst_o,
    output  [7:0]   hsb_apb_psel_o,
    output          hsb_apb_penable_o,
    output  [31:0]  hsb_apb_paddr_o,
    output  [31:0]  hsb_apb_pwdata_o,
    output          hsb_apb_pwrite_o,
    input   [7:0]   hsb_apb_pready_i,
    input   [31:0]  hsb_apb_prdata_i [7:0],
    input   [7:0]   hsb_apb_pserr_i,

    DphyRx4LaneIface.slv    dphy_rx,
    output                  cam_en, 
    // Camera power and register setup are controlled by the host through HSB.
    input  cam_scl_IN,
    input  cam_sda_IN,
    output cam_scl_OUT,
    output cam_scl_OE,
    output cam_sda_OUT,
    output cam_sda_OE,

    // -------------------------------------------------------
    // -- ethernet interface
    // -------------------------------------------------------
    /*
     * Ethernet: SFP+
     */
    input              init_rst_n,
    input              PMA_CMN_READY,
    input              PMA_XCVR_PLLCLK_EN_ACK,
    input  [3:0]       PMA_XCVR_POWER_STATE_ACK,
    input              PMA_RX_SIGNAL_DETECT,
    output             PMA_XCVR_PLLCLK_EN,
    output [3:0]       PMA_XCVR_POWER_STATE_REQ,

    output wire [63:0] sfp0_txd,
    output wire [ 7:0] sfp0_txc,
    input  wire [63:0] sfp0_rxd,
    input  wire [ 7:0] sfp0_rxc

);

// MIPI CSI-2 pixel bus
wire         w_mipi_rx_vs;
wire         w_mipi_rx_hs;
wire         w_mipi_rx_valid;
wire  [63:0] w_mipi_rx_data;
wire  [ 5:0] w_mipi_rx_dt;

// CSI-2 AXI-Lite config port (unused -- tied idle)
wire         reset_mipi_n;
wire  [31:0] rx_axi_awaddr;
wire         rx_axi_awvalid;
wire         rx_axi_awready;
wire  [31:0] rx_axi_wdata;
wire         rx_axi_wvalid;
wire         rx_axi_wready;
wire         rx_axi_bvalid;
wire         rx_axi_bready;
wire  [31:0] rx_axi_araddr;
wire         rx_axi_arvalid;
wire         rx_axi_arready;
wire  [31:0] rx_axi_rdata;
wire         rx_axi_rvalid;
wire         rx_axi_rready;

wire         phy_init_done;

assign reset_mipi_n    = clk_100m_rstn;
assign rx_axi_awaddr   = 32'h0;
assign rx_axi_wdata    = 32'h0;
assign rx_axi_araddr   = 32'h0;
assign rx_axi_awvalid  = 1'b0;
assign rx_axi_wvalid   = 1'b0;
assign rx_axi_bready   = 1'b1;
assign rx_axi_arvalid  = 1'b0;
assign rx_axi_rready   = 1'b1;

logic clk_50m;
always_ff @(posedge clk_100m) begin
    clk_50m <= !clk_50m;
end

logic [47:0] hsb_mac_addr [0:0];
logic [55:0] hsb_board_sn;
logic        hsb_init_done;
localparam logic [47:0] HSB_DEV_MAC  = 48'h02_00_00_00_00_01;
localparam logic [55:0] HSB_BOARD_SN = 56'h0000_0000_C115_ABCD;
assign hsb_mac_addr[0] = HSB_DEV_MAC;
assign hsb_board_sn    = HSB_BOARD_SN;

// mipi_to_HSB_axis <-> HOLOLINK_top sensor AXI-Stream
logic [63:0] sif_axis_tdata [0:0];
logic [ 7:0] sif_axis_tkeep [0:0];
logic [ 1:0] sif_axis_tuser [0:0];
logic        sif_axis_tvalid;
logic        sif_axis_tlast;
logic        sif_axis_tready;
logic        w_sif_rx_rst;

// HOLOLINK APB master <-> external slaves (REG_INST=8); connect slaves to hsb_apb_psel[n]
logic        hsb_apb_rst;
logic [ 7:0] hsb_apb_psel;
logic        hsb_apb_penable;
logic [31:0] hsb_apb_paddr;
logic [31:0] hsb_apb_pwdata;
logic        hsb_apb_pwrite;
logic [ 7:0] hsb_apb_pready;
logic [31:0] hsb_apb_prdata [7:0];
logic [ 7:0] hsb_apb_pserr;
assign hsb_apb_rst_o = hsb_apb_rst;
assign hsb_apb_psel_o = hsb_apb_psel;
assign hsb_apb_penable_o = hsb_apb_penable;
assign hsb_apb_paddr_o = hsb_apb_paddr;
assign hsb_apb_pwdata_o = hsb_apb_pwdata;
assign hsb_apb_pwrite_o = hsb_apb_pwrite;
assign hsb_apb_pready = hsb_apb_pready_i;
assign hsb_apb_prdata = hsb_apb_prdata_i;
assign hsb_apb_pserr  = hsb_apb_pserr_i;


// HOLOLINK <-> pad (instance [0] when I2C_INST=1)
logic hsb_i2c_scl_in;
logic hsb_i2c_sda_in;
logic hsb_i2c_scl_en;
logic hsb_i2c_sda_en;
assign hsb_i2c_scl_in     = cam_scl_IN;
assign hsb_i2c_sda_in     = cam_sda_IN;
assign cam_scl_OUT        = 1'b0;              // always drive 0 when OE on
assign cam_sda_OUT        = 1'b0;
assign cam_scl_OE         = ~hsb_i2c_scl_en; // en=0 → pull low
assign cam_sda_OE         = ~hsb_i2c_sda_en;

// HOLOLINK GPIO
logic [31:0] hsb_sen_rst;
assign cam_en            = hsb_sen_rst[0];
assign dphy_rx.RESET_N   = clk_100m_rstn;
assign dphy_rx.RST0_N    = clk_100m_rstn;
assign o_hsb_init_done   = hsb_init_done;
assign o_cam_active      = w_mipi_rx_vs;
assign o_fb_active       = 1'b0;

localparam NUM_DATA_LANE = 4;
// Mapping to DPHY RX IF
logic RxUlpsClkNot;
logic RxUlpsActiveClkNot;
logic [NUM_DATA_LANE-1:0] RxErrEsc;
logic [NUM_DATA_LANE-1:0] RxErrControl;
logic [NUM_DATA_LANE-1:0] RxErrSotSyncHS;
logic [NUM_DATA_LANE-1:0] RxClkEsc;
logic [NUM_DATA_LANE-1:0] RxUlpsEsc;
logic [NUM_DATA_LANE-1:0] RxUlpsActiveNot;
logic [NUM_DATA_LANE-1:0] RxSkewCalHS;
logic [NUM_DATA_LANE-1:0] RxStopState;
logic [NUM_DATA_LANE-1:0] RxValidHS;
logic [NUM_DATA_LANE-1:0] RxSyncHS;
logic [NUM_DATA_LANE-1:0][15:0] RxDataHS;

assign RxUlpsClkNot = dphy_rx.RX_ULPS_CLK_NOT;
assign RxUlpsActiveClkNot = dphy_rx.RX_ULPS_ACTIVE_CLK_NOT;
assign RxErrEsc[0] = dphy_rx.ERR_ESC_LAN0;
assign RxErrEsc[1] = dphy_rx.ERR_ESC_LAN1;
assign RxErrEsc[2] = dphy_rx.ERR_ESC_LAN2;
assign RxErrEsc[3] = dphy_rx.ERR_ESC_LAN3;
assign RxErrControl[0] = dphy_rx.LINESTATE_LAN0_ERROR;
assign RxErrControl[1] = dphy_rx.LINESTATE_LAN1_ERROR;
assign RxErrControl[2] = dphy_rx.LINESTATE_LAN2_ERROR;
assign RxErrControl[3] = dphy_rx.LINESTATE_LAN3_ERROR;
assign RxErrSotSyncHS[0] = dphy_rx.ERR_SOT_SYNC_HS_LAN0;
assign RxErrSotSyncHS[1] = dphy_rx.ERR_SOT_SYNC_HS_LAN1;
assign RxErrSotSyncHS[2] = dphy_rx.ERR_SOT_SYNC_HS_LAN2;
assign RxErrSotSyncHS[3] = dphy_rx.ERR_SOT_SYNC_HS_LAN3;
assign RxUlpsEsc[0] = dphy_rx.RX_ULPS_ESC_LAN0;
assign RxUlpsEsc[1] = dphy_rx.RX_ULPS_ESC_LAN1;
assign RxUlpsEsc[2] = dphy_rx.RX_ULPS_ESC_LAN2;
assign RxUlpsEsc[3] = dphy_rx.RX_ULPS_ESC_LAN3;
assign RxClkEsc[0] = dphy_rx.ESC_LAN0_CLK;
assign RxClkEsc[1] = dphy_rx.ESC_LAN1_CLK;
assign RxClkEsc[2] = dphy_rx.ESC_LAN2_CLK;
assign RxClkEsc[3] = dphy_rx.ESC_LAN3_CLK;
assign RxUlpsActiveNot[0] = dphy_rx.RX_ULPS_ACTIVE_NOT_LAN0;
assign RxUlpsActiveNot[1] = dphy_rx.RX_ULPS_ACTIVE_NOT_LAN1;
assign RxUlpsActiveNot[2] = dphy_rx.RX_ULPS_ACTIVE_NOT_LAN2;
assign RxUlpsActiveNot[3] = dphy_rx.RX_ULPS_ACTIVE_NOT_LAN3;
assign RxSkewCalHS[0] = dphy_rx.RX_SKEW_CAL_HS_LAN0;
assign RxSkewCalHS[1] = dphy_rx.RX_SKEW_CAL_HS_LAN1;
assign RxSkewCalHS[2] = dphy_rx.RX_SKEW_CAL_HS_LAN2;
assign RxSkewCalHS[3] = dphy_rx.RX_SKEW_CAL_HS_LAN3;
assign RxStopState[0] = dphy_rx.STOPSTATE_LAN0;
assign RxStopState[1] = dphy_rx.STOPSTATE_LAN1;
assign RxStopState[2] = dphy_rx.STOPSTATE_LAN2;
assign RxStopState[3] = dphy_rx.STOPSTATE_LAN3;
assign RxValidHS[0] = dphy_rx.RX_VALID_HS_LAN0;
assign RxValidHS[1] = dphy_rx.RX_VALID_HS_LAN1;
assign RxValidHS[2] = dphy_rx.RX_VALID_HS_LAN2;
assign RxValidHS[3] = dphy_rx.RX_VALID_HS_LAN3;
assign RxSyncHS[0] = dphy_rx.RX_SYNC_HS_LAN0;
assign RxSyncHS[1] = dphy_rx.RX_SYNC_HS_LAN1;
assign RxSyncHS[2] = dphy_rx.RX_SYNC_HS_LAN2;
assign RxSyncHS[3] = dphy_rx.RX_SYNC_HS_LAN3;
assign RxDataHS[0] = dphy_rx.RX_DATA_HS_LAN0;
assign RxDataHS[1] = dphy_rx.RX_DATA_HS_LAN1;
assign RxDataHS[2] = dphy_rx.RX_DATA_HS_LAN2;
assign RxDataHS[3] = dphy_rx.RX_DATA_HS_LAN3;

efx_csi2_rx_top_rx inst_csi2_rx_top (
    .reset_n        (clk_100m_rstn),
    .clk            (clk_100m),
    .reset_byte_HS_n(clk_100m_rstn),
    .clk_byte_HS    (dphy_rx.SLOWCLK),
    .reset_pixel_n  (clk_100m_rstn),
    .clk_pixel      (clk_100m),

    // PPI Interface
    .RxClkEsc          (RxClkEsc),
    .RxUlpsClkNot      (RxUlpsClkNot),
    .RxUlpsActiveClkNot(RxUlpsActiveClkNot),
    .RxErrEsc          (RxErrEsc),
    .RxErrControl      (RxErrControl),
    .RxErrSotSyncHS    (RxErrSotSyncHS),
    .RxUlpsEsc         (RxUlpsEsc),
    .RxUlpsActiveNot   (RxUlpsActiveNot),
    .RxSkewCalHS       (RxSkewCalHS),
    .RxStopState       (RxStopState),
    .RxSyncHS          (RxSyncHS),
    .RxDataHS0         (RxDataHS[0]),
    .RxDataHS1         (RxDataHS[1]),
    .RxDataHS2         (RxDataHS[2]),
    .RxDataHS3         (RxDataHS[3]),
    .RxDataHS4         (),
    .RxDataHS5         (),
    .RxDataHS6         (),
    .RxDataHS7         (),
    .RxValidHS0        ({RxValidHS[0], RxValidHS[0]}),
    .RxValidHS1        ({RxValidHS[1], RxValidHS[1]}),
    .RxValidHS2        ({RxValidHS[2], RxValidHS[2]}),
    .RxValidHS3        ({RxValidHS[3], RxValidHS[3]}),
    .RxValidHS4        (),
    .RxValidHS5        (),
    .RxValidHS6        (),
    .RxValidHS7        (),

    .axi_clk    (clk_100m),
    .axi_reset_n(reset_mipi_n),
    .axi_awaddr (rx_axi_awaddr),
    .axi_awvalid(rx_axi_awvalid),
    .axi_awready(rx_axi_awready),
    .axi_wdata  (rx_axi_wdata),
    .axi_wvalid (rx_axi_wvalid),
    .axi_wready (rx_axi_wready),
    .axi_bvalid (rx_axi_bvalid),
    .axi_bready (rx_axi_bready),
    .axi_araddr (rx_axi_araddr),
    .axi_arvalid(rx_axi_arvalid),
    .axi_arready(rx_axi_arready),
    .axi_rdata  (rx_axi_rdata),
    .axi_rvalid (rx_axi_rvalid),
    .axi_rready (rx_axi_rready),

    .hsync_vc0(w_mipi_rx_hs),
    .vsync_vc0(w_mipi_rx_vs),
    .hsync_vc1 (), .hsync_vc2 (), .hsync_vc3 (), .hsync_vc4 (), .hsync_vc5 (),
    .hsync_vc6 (), .hsync_vc7 (), .hsync_vc8 (), .hsync_vc9 (), .hsync_vc10(),
    .hsync_vc11(), .hsync_vc12(), .hsync_vc13(), .hsync_vc14(), .hsync_vc15(),
    .vsync_vc1 (), .vsync_vc2 (), .vsync_vc3 (), .vsync_vc4 (), .vsync_vc5 (),
    .vsync_vc6 (), .vsync_vc7 (), .vsync_vc8 (), .vsync_vc9 (), .vsync_vc10(),
    .vsync_vc11(), .vsync_vc12(), .vsync_vc13(), .vsync_vc14(), .vsync_vc15(),

    .vc                 (),
    .vcx                (),
    .word_count         (),
    .shortpkt_data_field(),
    .datatype           (w_mipi_rx_dt),         // RAW10
    .pixel_per_clk      (),
    .pixel_data         (w_mipi_rx_data),
    .pixel_data_valid   (w_mipi_rx_valid),
    .irq                ()
);

mipi_to_HSB_axis u_mipi_to_HSB_axis (
    .in_pclk            (clk_100m),
    .in_rstn            (clk_100m_rstn & ~w_sif_rx_rst),

    .i_pixel_data       (w_mipi_rx_data),
    .i_pixel_data_valid (w_mipi_rx_valid),
    .i_hsync            (w_mipi_rx_hs),
    .i_vsync            (w_mipi_rx_vs),
    .i_datatype         (w_mipi_rx_dt),

    .o_axis_tdata       (sif_axis_tdata[0]),
    .o_axis_tkeep       (sif_axis_tkeep[0]),
    .o_axis_tvalid      (sif_axis_tvalid),
    .o_axis_tlast       (sif_axis_tlast),
    .o_axis_tuser       (sif_axis_tuser[0]),
    .i_axis_tready      (sif_axis_tready)
);

logic [63:0] hif_tx_tdata [0:0], hif_rx_tdata [0:0];
logic [ 7:0] hif_tx_tkeep [0:0], hif_rx_tkeep [0:0];
logic [ 0:0] hif_tx_tvalid,       hif_rx_tvalid;
logic [ 0:0] hif_tx_tlast,        hif_rx_tlast;
logic [ 0:0] hif_tx_tuser [0:0], hif_rx_tuser [0:0];
logic [ 0:0] hif_tx_tready,       hif_rx_tready;

// HOLOLINK_top port list matches rtl/HOLOLINK_def.svh (SENSOR_RX, no SENSOR_TX, no UART)
HOLOLINK_top u_hololink_top (
    .i_sys_rst          (~clk_100m_rstn), //active HIGH rstn
    // APB
    .i_apb_clk          (clk_100m),
    .o_apb_rst          (hsb_apb_rst),
    .o_apb_psel         (hsb_apb_psel),
    .o_apb_penable      (hsb_apb_penable),
    .o_apb_paddr        (hsb_apb_paddr),
    .o_apb_pwdata       (hsb_apb_pwdata),
    .o_apb_pwrite       (hsb_apb_pwrite),
    .i_apb_pready       (hsb_apb_pready),
    .i_apb_prdata       (hsb_apb_prdata),
    .i_apb_pserr        (hsb_apb_pserr),
    // Enumeration (ENUM_EEPROM not defined)
    .i_mac_addr         (hsb_mac_addr),
    .i_board_sn         (hsb_board_sn),
    .i_enum_vld         (1'b1),
    .o_init_done        (hsb_init_done),
    // Sensor RX AXI-Stream — connect to sif_axis_* from mipi_to_HSB_axis above
    .i_sif_rx_clk       ({clk_100m}),
    .o_sif_rx_rst       ({w_sif_rx_rst}),
    .i_sif_axis_tvalid  ({sif_axis_tvalid}),
    .i_sif_axis_tlast   ({sif_axis_tlast}),
    .i_sif_axis_tdata   (sif_axis_tdata),
    .i_sif_axis_tkeep   (sif_axis_tkeep),
    .i_sif_axis_tuser   (sif_axis_tuser),
    .o_sif_axis_tready  ({sif_axis_tready}),
    .i_sif_event        (16'h0),
    // Host AXI-Stream (MAC)
    .i_hif_clk          (clk_156m),
    .o_hif_rst          (),
    .i_hif_axis_tvalid  (hif_rx_tvalid),
    .i_hif_axis_tlast   (hif_rx_tlast),
    .i_hif_axis_tdata   (hif_rx_tdata),
    .i_hif_axis_tkeep   (hif_rx_tkeep),
    .i_hif_axis_tuser   (hif_rx_tuser),
    .o_hif_axis_tready  (hif_rx_tready),
    .o_hif_axis_tvalid  (hif_tx_tvalid),
    .o_hif_axis_tlast   (hif_tx_tlast),
    .o_hif_axis_tdata   (hif_tx_tdata),
    .o_hif_axis_tkeep   (hif_tx_tkeep),
    .o_hif_axis_tuser   (hif_tx_tuser),
    .i_hif_axis_tready  (hif_tx_tready),
    // SPI (SPI_INST=1)
    .o_spi_csn          (),
    .o_spi_sck          (),
    .i_spi_sdio         (),
    .o_spi_sdio         (),
    .o_spi_oen          (),
    // I2C (I2C_INST=1)
    .i_i2c_scl          ({hsb_i2c_scl_in}),
    .i_i2c_sda          ({hsb_i2c_sda_in}),
    .o_i2c_scl_en       ({hsb_i2c_scl_en}),
    .o_i2c_sda_en       ({hsb_i2c_sda_en}),
    // GPIO (GPIO_INST=8)
    .i_gpio             (8'h0),
    .o_gpio             (),
    .o_gpio_dir         (),
    // Sensor reset
    .o_sw_sys_rst       (),
    .o_sw_sen_rst       (hsb_sen_rst),
    // PTP (EXT_PTP not defined)
    .i_ptp_clk          (clk_100m),
    .o_ptp_rst          (),
    .o_ptp_sec          (),
    .o_ptp_nanosec      (),
    .o_pps              ()
);

logic [63:0] mac_tx_tdata,  mac_rx_tdata;
logic [7:0]  mac_tx_tkeep,  mac_rx_tkeep;
logic        mac_tx_tvalid, mac_rx_tvalid;
logic        mac_tx_tlast,  mac_rx_tlast;
logic        mac_tx_tuser,  mac_rx_tuser;
logic        mac_tx_tready, mac_rx_tready;

// HSB TX → MAC TX (FPGA → wire)
assign mac_tx_tdata  = hif_tx_tdata[0];
assign mac_tx_tvalid = hif_tx_tvalid[0];
assign mac_tx_tlast  = hif_tx_tlast[0];
assign mac_tx_tkeep  = hif_tx_tkeep[0];
assign mac_tx_tuser  = hif_tx_tuser[0][0];
assign hif_tx_tready[0] = mac_tx_tready;
// MAC RX → HSB RX (wire → FPGA)
assign hif_rx_tdata[0]  = mac_rx_tdata;
assign hif_rx_tvalid[0] = mac_rx_tvalid;
assign hif_rx_tlast[0]  = mac_rx_tlast;
assign hif_rx_tkeep[0]  = mac_rx_tkeep;
assign hif_rx_tuser[0][0] = mac_rx_tuser;
assign mac_rx_tready    = hif_rx_tready[0];

// Stretch brief AXIS beats so LEDs are visible (~100 ms hold).
localparam integer ETH_LED_STRETCH = 156_250_000 / 10; // 100 ms @ 156.25 MHz
localparam integer ETH_LED_W = $clog2(ETH_LED_STRETCH);
logic [ETH_LED_W-1:0] eth_tx_led_cnt;
logic [ETH_LED_W-1:0] eth_rx_led_cnt;

always_ff @(posedge clk_156m or negedge clk_156m_rstn) begin
    if (!clk_156m_rstn) begin
        eth_tx_led_cnt <= '0;
        eth_rx_led_cnt <= '0;
    end else begin
        if (mac_tx_tvalid)
            eth_tx_led_cnt <= ETH_LED_STRETCH[ETH_LED_W-1:0] - 1'b1;
        else if (eth_tx_led_cnt != '0)
            eth_tx_led_cnt <= eth_tx_led_cnt - 1'b1;

        if (mac_rx_tvalid)
            eth_rx_led_cnt <= ETH_LED_STRETCH[ETH_LED_W-1:0] - 1'b1;
        else if (eth_rx_led_cnt != '0)
            eth_rx_led_cnt <= eth_rx_led_cnt - 1'b1;
    end
end

assign o_eth_tx_active = (eth_tx_led_cnt != '0);
assign o_eth_rx_active = (eth_rx_led_cnt != '0);

mac10gbe #() u_mac10gbe (
    .mac_reset_n                       (clk_156m_rstn),
    .mac10gbe_clk                      (clk_156m),
    .init_clk                          (clk_50m),
    .init_rst_n                        (init_rst_n),
    .PMA_CMN_READY                     (PMA_CMN_READY),
    .PMA_XCVR_PLLCLK_EN_ACK            (PMA_XCVR_PLLCLK_EN_ACK),
    .PMA_XCVR_POWER_STATE_ACK          (PMA_XCVR_POWER_STATE_ACK),
    .PMA_RX_SIGNAL_DETECT              (PMA_RX_SIGNAL_DETECT),
    .PMA_XCVR_PLLCLK_EN                (PMA_XCVR_PLLCLK_EN),
    .PMA_XCVR_POWER_STATE_REQ          (PMA_XCVR_POWER_STATE_REQ),
    .phy_init_done                     (phy_init_done),
    .tx_axis_mac_tdata                 (mac_tx_tdata),
    .tx_axis_mac_tvalid                (mac_tx_tvalid),
    .tx_axis_mac_tlast                 (mac_tx_tlast),
    .tx_axis_mac_tkeep                 (mac_tx_tkeep),
    .tx_axis_mac_tuser                 (mac_tx_tuser),
    .tx_axis_mac_tready                (mac_tx_tready),
    
    .rx_axis_mac_tdata                 (mac_rx_tdata),
    .rx_axis_mac_tvalid                (mac_rx_tvalid),
    .rx_axis_mac_tlast                 (mac_rx_tlast),
    .rx_axis_mac_tkeep                 (mac_rx_tkeep),
    .rx_axis_mac_tuser                 (mac_rx_tuser),
    .rx_pause_ignore                   (),
    .tx_pause_gen                      (),
    .tx_pause_busy                     (),
    .tx_pause_quant                    (),
    .rx_address_filtering_mask         (),
    .cnt_rst_n                         (clk_156m_rstn),
    .cnt_tx_frame_transmitted_good     (),
    .cnt_tx_frame_pause_mac_ctrl       (),
    .cnt_tx_frame_error_txfifo_overflow(),
    .cnt_tx_frame_is_fe                (),
    .cnt_rx_frame_received_good        (),
    .cnt_rx_frame_error_fcs            (),
    .cnt_rx_frame_pause_mac_ctrl       (),
    .cnt_rx_frame_errors               (),
    .cnt_rx_frame_received_total       (),
    .cnt_rx_frame_undersized           (),
    .cnt_rx_frame_oversized            (),
    .cnt_rx_frame_mismatched_length    (),
    .cnt_rx_frame_filtered_by_address  (),
    .rpt_rx_frame_length               (),
    .XGMII_TXD                         (sfp0_txd),
    .XGMII_TXC                         (sfp0_txc),
    .XGMII_RXD                         (sfp0_rxd),
    .XGMII_RXC                         (sfp0_rxc)
);

endmodule
