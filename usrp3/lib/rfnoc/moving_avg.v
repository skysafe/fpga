//
// Copyright 2018 Ettus Research, a National Instruments Company
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
module moving_avg #(
  parameter LENGTH = 16,
  parameter WIDTH  = 16
)(
  input clk, input reset, input clear,
  input [WIDTH-1:0] i_tdata, input i_tlast, input i_tvalid, output i_tready,
  output [WIDTH-1:0] o_tdata, output o_tlast, output o_tvalid, input o_tready
);

  wire [WIDTH+$clog2(LENGTH+1)-1:0] moving_sum_tdata;
  wire moving_sum_tlast, moving_sum_tvalid, moving_sum_tready;
  moving_sum #(
    .MAX_LEN(LENGTH),
    .WIDTH(WIDTH))
  inst_moving_sum (
    .clk(clk), .reset(reset), .clear(clear),
    .len(LENGTH),
    .i_tdata(i_tdata), .i_tlast(i_tlast), .i_tvalid(i_tvalid), .i_tready(i_tready),
    .o_tdata(moving_sum_tdata), .o_tlast(moving_sum_tlast), .o_tvalid(moving_sum_tvalid), .o_tready(moving_sum_tready));

  axi_round #(
    .WIDTH_IN(WIDTH+$clog2(LENGTH+1)),
    .WIDTH_OUT(WIDTH))
  inst_axi_round (
    .clk(clk), .reset(reset),
    .i_tdata(moving_sum_tdata), .i_tlast(moving_sum_tlast), .i_tvalid(moving_sum_tvalid), .i_tready(moving_sum_tready),
    .o_tdata(o_tdata), .o_tlast(o_tlast), .o_tvalid(o_tvalid), .o_tready(o_tready));

endmodule
