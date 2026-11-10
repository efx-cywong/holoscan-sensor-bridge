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

// Holoscan Sensor Bridge (nv_hsb_ip) file list
// Sources come from the shared tree: fpga/nv_hsb_ip (not a local rtl/lib copy).
// Paths are relative to the staged project copy:
//   fpga/efinix/Ti375N1156/Ti375N1156_HSB/rtl/
// (seed is Ti375N1156/rtl/; full_flow copies it into the project).
// ref_design/ is excluded (board examples only).

+incdir+.
+incdir+../../../../nv_hsb_ip/top

// Packages first
../../../../nv_hsb_ip/lib_apb/apb_pkg.sv
../../../../nv_hsb_ip/lib_axis/axis_pkg.sv
../../../../nv_hsb_ip/ecb/ecb_pkg.sv
../../../../nv_hsb_ip/ptp/ptp_pkg.sv
../../../../nv_hsb_ip/reg_map/regmap_pkg.sv
../../../../nv_hsb_ip/rx_parser/rx_parser_pkg.sv
../../../../nv_hsb_ip/packetizer/packetizer_pkg.sv

// bootp
../../../../nv_hsb_ip/bootp/bootp.sv

// ctrl_bus_evt
../../../../nv_hsb_ip/ctrl_bus_evt/ctrl_bus_evt_fsm.sv
../../../../nv_hsb_ip/ctrl_bus_evt/ctrl_bus_evt_int.sv

// data_gen
../../../../nv_hsb_ip/data_gen/data_gen.sv
../../../../nv_hsb_ip/data_gen/prbs_lfsr_hc.sv
../../../../nv_hsb_ip/data_gen/ram_player.sv

// dp_pkt
../../../../nv_hsb_ip/dp_pkt/dp_pkt.sv
../../../../nv_hsb_ip/dp_pkt/dp_pkt_hdr.sv
../../../../nv_hsb_ip/dp_pkt/dp_pkt_top.sv
../../../../nv_hsb_ip/dp_pkt/dp_pkt_ts.sv

// ecb
../../../../nv_hsb_ip/ecb/ecb_rdwr_ctrl.sv

// eth_pkt
../../../../nv_hsb_ip/eth_pkt/eth_pkt.sv

// glb_ctrl
../../../../nv_hsb_ip/glb_ctrl/glb_ctrl_top.sv

// i2c
../../../../nv_hsb_ip/i2c/i2c.sv
../../../../nv_hsb_ip/i2c/i2c_ctrl_fsm.sv

// lib_apb
../../../../nv_hsb_ip/lib_apb/apb_adapter.sv
../../../../nv_hsb_ip/lib_apb/apb_ff.sv
../../../../nv_hsb_ip/lib_apb/apb_intc_top.sv
../../../../nv_hsb_ip/lib_apb/apb_switch.sv
../../../../nv_hsb_ip/lib_apb/apb_to_axi4l.sv
../../../../nv_hsb_ip/lib_apb/m_apb_reg.sv
../../../../nv_hsb_ip/lib_apb/s_apb_ila.sv
../../../../nv_hsb_ip/lib_apb/s_apb_ram.sv
../../../../nv_hsb_ip/lib_apb/s_apb_ram_dyn.sv
../../../../nv_hsb_ip/lib_apb/s_apb_reg.sv

// lib_axis
../../../../nv_hsb_ip/lib_axis/axis_arb.sv
../../../../nv_hsb_ip/lib_axis/axis_buffer.sv
../../../../nv_hsb_ip/lib_axis/axis_checker.sv
../../../../nv_hsb_ip/lib_axis/axis_demux.sv
../../../../nv_hsb_ip/lib_axis/axis_drop.sv
../../../../nv_hsb_ip/lib_axis/axis_drop_tail.sv
../../../../nv_hsb_ip/lib_axis/axis_ftr.sv
../../../../nv_hsb_ip/lib_axis/axis_gearbox.sv
../../../../nv_hsb_ip/lib_axis/axis_hdr.sv
../../../../nv_hsb_ip/lib_axis/axis_insert.sv
../../../../nv_hsb_ip/lib_axis/axis_mask.sv
../../../../nv_hsb_ip/lib_axis/axis_packer.sv
../../../../nv_hsb_ip/lib_axis/axis_reg.sv
../../../../nv_hsb_ip/lib_axis/axis_remove.sv
../../../../nv_hsb_ip/lib_axis/axis_to_vec.sv
../../../../nv_hsb_ip/lib_axis/vec_to_axis.sv
../../../../nv_hsb_ip/lib_axis/vec_to_axis_dyn_len.sv

// misc
../../../../nv_hsb_ip/misc/cam.sv
../../../../nv_hsb_ip/misc/cdc_reset_handshake.sv
../../../../nv_hsb_ip/misc/comparator.sv
../../../../nv_hsb_ip/misc/data_sync.sv
../../../../nv_hsb_ip/misc/dc_fifo_generic.sv
../../../../nv_hsb_ip/misc/dc_fifo_stub.sv
../../../../nv_hsb_ip/misc/debouncer.sv
../../../../nv_hsb_ip/misc/dp_ram.sv
../../../../nv_hsb_ip/misc/edge_to_pulse.sv
../../../../nv_hsb_ip/misc/glitch_filter.sv
../../../../nv_hsb_ip/misc/moving_avg.sv
../../../../nv_hsb_ip/misc/priority_arb.sv
../../../../nv_hsb_ip/misc/pulse_sync.sv
../../../../nv_hsb_ip/misc/reg_cdc.sv
../../../../nv_hsb_ip/misc/reg_fifo.sv
../../../../nv_hsb_ip/misc/reset_sync.sv
../../../../nv_hsb_ip/misc/rrarb.sv
../../../../nv_hsb_ip/misc/rst_pb_debounce.sv
../../../../nv_hsb_ip/misc/sc_fifo.sv
../../../../nv_hsb_ip/misc/streaming_cdc.sv
../../../../nv_hsb_ip/misc/str_fwd_fifo.sv

// packetizer
../../../../nv_hsb_ip/packetizer/odd_even_gen.sv
../../../../nv_hsb_ip/packetizer/packetizer.sv
../../../../nv_hsb_ip/packetizer/packetizer_static.sv
../../../../nv_hsb_ip/packetizer/packetizer_top.sv
../../../../nv_hsb_ip/packetizer/virtual_port.sv

// ptp
../../../../nv_hsb_ip/ptp/dpll.sv
../../../../nv_hsb_ip/ptp/ptp_calc.sv
../../../../nv_hsb_ip/ptp/ptp_dly.sv
../../../../nv_hsb_ip/ptp/ptp_egress.sv
../../../../nv_hsb_ip/ptp/ptp_ingress.sv
../../../../nv_hsb_ip/ptp/ptp_parser.sv
../../../../nv_hsb_ip/ptp/ptp_sync.sv
../../../../nv_hsb_ip/ptp/ptp_timer.sv
../../../../nv_hsb_ip/ptp/ptp_top.sv

// reset_gen
../../../../nv_hsb_ip/reset_gen/reset_gen.sv

// roce
../../../../nv_hsb_ip/roce/lfsr_hc.sv
../../../../nv_hsb_ip/roce/roce_ack.sv
../../../../nv_hsb_ip/roce/roce_icrc.sv

// routing_table
../../../../nv_hsb_ip/routing_table/bridge_pkt_proc.sv
../../../../nv_hsb_ip/routing_table/routing_table.sv

// rx_parser
../../../../nv_hsb_ip/rx_parser/arp_ping_pkt_proc.sv
../../../../nv_hsb_ip/rx_parser/rx_ls_parser.sv
../../../../nv_hsb_ip/rx_parser/rx_parser.sv

// sensor_tx
../../../../nv_hsb_ip/sensor_tx/axis_buffer_tx.sv
../../../../nv_hsb_ip/sensor_tx/pause_gen.sv
../../../../nv_hsb_ip/sensor_tx/sensor_tx_pkt_proc.sv
../../../../nv_hsb_ip/sensor_tx/tx_stream_buffer.sv

// spi
../../../../nv_hsb_ip/spi/spi.sv
../../../../nv_hsb_ip/spi/spi_ctrl_fsm.sv

// sys_init
../../../../nv_hsb_ip/sys_init/eeprom_info.sv
../../../../nv_hsb_ip/sys_init/sys_init.sv

// uart
../../../../nv_hsb_ip/uart/uart.sv
../../../../nv_hsb_ip/uart/uart_ctrl_fsm.sv

// top (last)
../../../../nv_hsb_ip/top/HOLOLINK_top.sv
