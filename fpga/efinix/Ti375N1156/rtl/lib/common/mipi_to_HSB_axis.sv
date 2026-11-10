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

module mipi_to_HSB_axis #(
    parameter integer H_ACTIVE   = 1920,
    parameter integer V_ACTIVE   = 1080,
    parameter integer FIFO_DEPTH = 512
) (
    input  wire         in_pclk,
    input  wire         in_rstn,

    input  wire [63:0]  i_pixel_data,
    input  wire         i_pixel_data_valid,
    input  wire         i_hsync,
    input  wire         i_vsync,
    input  wire [ 5:0]  i_datatype,        // expect 6'h2B (RAW10)

    output wire [63:0]  o_axis_tdata,
    output wire [ 7:0]  o_axis_tkeep,
    output wire         o_axis_tvalid,
    output wire         o_axis_tlast,
    output wire [ 1:0]  o_axis_tuser,
    input  wire         i_axis_tready
);

    localparam integer PIXELS_PER_INPUT = 4;
    localparam integer GROUPS_PER_LINE  = H_ACTIVE / PIXELS_PER_INPUT;
    localparam integer GROUP_COUNT_W    = $clog2(GROUPS_PER_LINE);
    localparam integer LINE_COUNT_W     = $clog2(V_ACTIVE);
    localparam integer FIFO_PTR_W       = $clog2(FIFO_DEPTH);
    localparam integer FIFO_COUNT_W     = $clog2(FIFO_DEPTH + 1);

    // The Efinix CSI receiver presents four unpacked 10-bit pixels in the
    // low 40 bits of pixel_data. Hololink CsiToBayerOp expects MIPI CSI-2
    // RAW10 packing: four pixels in five consecutive bytes.
    wire [9:0] pixel_0 = i_pixel_data[ 9: 0];
    wire [9:0] pixel_1 = i_pixel_data[19:10];
    wire [9:0] pixel_2 = i_pixel_data[29:20];
    wire [9:0] pixel_3 = i_pixel_data[39:30];

    wire [39:0] raw10_group = {
        pixel_3[1:0], pixel_2[1:0], pixel_1[1:0], pixel_0[1:0],
        pixel_3[9:2], pixel_2[9:2], pixel_1[9:2], pixel_0[9:2]
    };
    wire raw10_valid = i_pixel_data_valid && (i_datatype == 6'h2B);

    // 40-to-64-bit byte-stream accumulator. Data is kept LSB-first because
    // Hololink transmits tdata[7:0] as the first payload byte.
    logic [127:0] bit_buffer;
    logic [7:0]   bit_count;

    logic [GROUP_COUNT_W-1:0] group_count;
    logic [LINE_COUNT_W-1:0]  line_count;

    // Output FIFO absorbs normal Hololink backpressure. The CSI receiver
    // cannot be stalled, so an exceptionally long stall can still overflow;
    // FIFO_DEPTH=512 holds more than one complete 1080p RAW10 line (300 beats).
    logic [63:0] fifo_tdata [0:FIFO_DEPTH-1];
    logic [ 1:0] fifo_tuser [0:FIFO_DEPTH-1];
    logic        fifo_tlast [0:FIFO_DEPTH-1];
    logic [FIFO_PTR_W-1:0]   fifo_wr_ptr;
    logic [FIFO_PTR_W-1:0]   fifo_rd_ptr;
    logic [FIFO_COUNT_W-1:0] fifo_count;
    logic                    fifo_overflow;

    wire fifo_pop = (fifo_count != 0) && i_axis_tready;

    assign o_axis_tdata  = fifo_tdata[fifo_rd_ptr];
    assign o_axis_tkeep  = 8'hFF;
    assign o_axis_tvalid = (fifo_count != 0);
    assign o_axis_tuser  = fifo_tuser[fifo_rd_ptr];
    assign o_axis_tlast  = fifo_tlast[fifo_rd_ptr];

    always_ff @(posedge in_pclk or negedge in_rstn) begin : pack_raw10
        logic [127:0] buffer_next;
        logic [7:0]   count_next;
        logic         produce_beat;
        logic         store_beat;
        logic         line_end;
        logic         frame_end;

        if (~in_rstn) begin
            bit_buffer    <= '0;
            bit_count     <= '0;
            group_count   <= '0;
            line_count    <= '0;
            fifo_wr_ptr   <= '0;
            fifo_rd_ptr   <= '0;
            fifo_count    <= '0;
            fifo_overflow <= 1'b0;
        end else begin
            buffer_next = bit_buffer;
            count_next  = bit_count;
            line_end    = 1'b0;
            frame_end   = 1'b0;

            if (raw10_valid) begin
                buffer_next = buffer_next | ({88'b0, raw10_group} << count_next);
                count_next  = count_next + 8'd40;

                line_end  = (group_count == GROUPS_PER_LINE - 1);
                frame_end = line_end && (line_count == V_ACTIVE - 1);

                if (line_end) begin
                    group_count <= '0;
                    if (frame_end) begin
                        line_count <= '0;
                    end else begin
                        line_count <= line_count + 1'b1;
                    end
                end else begin
                    group_count <= group_count + 1'b1;
                end
            end

            produce_beat = (count_next >= 8'd64);
            store_beat   = produce_beat
                         && ((fifo_count < FIFO_DEPTH) || fifo_pop);

            if (produce_beat) begin
                if (store_beat) begin
                    fifo_tdata[fifo_wr_ptr] <= buffer_next[63:0];
                    fifo_tuser[fifo_wr_ptr] <= {line_end, 1'b0};
                    fifo_tlast[fifo_wr_ptr] <= frame_end;
                    fifo_wr_ptr             <= (fifo_wr_ptr == FIFO_DEPTH - 1)
                                             ? '0 : fifo_wr_ptr + 1'b1;
                end else begin
                    // Keep byte-stream alignment after a drop so the next
                    // frame can recover at its normal byte boundary.
                    fifo_overflow <= 1'b1;
                end
                buffer_next = buffer_next >> 64;
                count_next  = count_next - 8'd64;
            end

            bit_buffer <= buffer_next;
            bit_count  <= count_next;

            if (fifo_pop) begin
                fifo_rd_ptr <= (fifo_rd_ptr == FIFO_DEPTH - 1)
                             ? '0 : fifo_rd_ptr + 1'b1;
            end

            case ({store_beat, fifo_pop})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end

endmodule
