//
// Copyright 2018 Ettus Research, a National Instruments Company
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
module moving_avg_complex #(
  parameter LENGTH = 16,
  parameter WIDTH  = 16
)(
  input clk, input reset, input clear,
  input [2*WIDTH-1:0] i_tdata, input i_tlast, input i_tvalid, output i_tready,
  output [2*WIDTH-1:0] o_tdata, output o_tlast, output o_tvalid, input o_tready
);

  moving_avg #(
    .LENGTH(LENGTH),
    .WIDTH(WIDTH))
  inst_moving_avg_real (
    .clk(clk), .reset(reset), .clear(clear),
    .i_tdata(i_tdata[2*WIDTH-1:WIDTH]), .i_tlast(i_tlast), .i_tvalid(i_tvalid), .i_tready(i_tready),
    .o_tdata(o_tdata[2*WIDTH-1:WIDTH]), .o_tlast(o_tlast), .o_tvalid(o_tvalid), .o_tready(o_tready));

  moving_avg #(
    .LENGTH(LENGTH),
    .WIDTH(WIDTH))
  inst_moving_avg_imag (
    .clk(clk), .reset(reset), .clear(clear),
    .i_tdata(i_tdata[WIDTH-1:0]), .i_tlast(1'b0), .i_tvalid(i_tvalid), .i_tready(),
    .o_tdata(o_tdata[WIDTH-1:0]), .o_tlast(), .o_tvalid(), .o_tready(o_tready));

endmodule
