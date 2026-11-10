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

module reset
#(
    parameter   IN_RST_ACTIVE   = "LOW",
    parameter   OUT_RST_ACTIVE  = "HIGH",
    parameter   CYCLE           = 1
)
(
    input   i_arst,
    input   i_clk,

    output  o_srst
);

(* async_reg = "true" *) reg [CYCLE-1:0]r_srst_1P;

genvar i;
generate
    if (IN_RST_ACTIVE == "LOW")
    begin
        if (OUT_RST_ACTIVE == "LOW")
        begin
            always@(negedge i_arst or posedge i_clk)
            begin
                if (~i_arst)
                    r_srst_1P[0]    <= 1'b0;
                else
                    r_srst_1P[0]    <= 1'b1;
            end
            
            for (i=0; i<CYCLE-1; i=i+1)
            begin
                always@(negedge i_arst or posedge i_clk)
                begin
                    if (~i_arst)
                        r_srst_1P[i+1]  <= 1'b0;
                    else
                        r_srst_1P[i+1]  <= r_srst_1P[i];
                end
            end
        end
        else
        begin
            always@(negedge i_arst or posedge i_clk)
            begin
                if (~i_arst)
                    r_srst_1P[0]    <= 1'b1;
                else
                    r_srst_1P[0]    <= 1'b0;
            end
            
            for (i=0; i<CYCLE-1; i=i+1)
            begin
                always@(negedge i_arst or posedge i_clk)
                begin
                    if (~i_arst)
                        r_srst_1P[i+1]  <= 1'b1;
                    else
                        r_srst_1P[i+1]  <= r_srst_1P[i];
                end
            end
        end
    end
    else
    begin
        if (OUT_RST_ACTIVE == "LOW")
        begin
            always@(posedge i_arst or posedge i_clk)
            begin
                if (i_arst)
                    r_srst_1P[0]    <= 1'b0;
                else
                    r_srst_1P[0]    <= 1'b1;
            end
            
            for (i=0; i<CYCLE-1; i=i+1)
            begin
                always@(posedge i_arst or posedge i_clk)
                begin
                    if (i_arst)
                        r_srst_1P[i+1]  <= 1'b0;
                    else
                        r_srst_1P[i+1]  <= r_srst_1P[i];
                end
            end
        end
        else
        begin
            always@(posedge i_arst or posedge i_clk)
            begin
                if (i_arst)
                    r_srst_1P[0]    <= 1'b1;
                else
                    r_srst_1P[0]    <= 1'b0;
            end
            
            for (i=0; i<CYCLE-1; i=i+1)
            begin
                always@(posedge i_arst or posedge i_clk)
                begin
                    if (i_arst)
                        r_srst_1P[i+1]  <= 1'b1;
                    else
                        r_srst_1P[i+1]  <= r_srst_1P[i];
                end
            end
        end
    end
endgenerate

assign  o_srst  = r_srst_1P[CYCLE-1];

endmodule
