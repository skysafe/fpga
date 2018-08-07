module moving_sum_complex #(
  parameter MAX_LEN = 1023,
  parameter WIDTH   = 16
)(
  input clk, input reset, input clear,
  input [$clog2(MAX_LEN+1)-1:0] len,
  input [2*WIDTH-1:0] i_tdata, input i_tlast, input i_tvalid, output i_tready,
  output [2*(WIDTH+$clog2(MAX_LEN+1))-1:0] o_tdata, output o_tlast, output o_tvalid, input o_tready
);

  moving_sum #(
    .MAX_LEN(MAX_LEN),
    .WIDTH(WIDTH))
  inst_moving_sum_real (
    .clk(clk), .reset(reset), .clear(clear),
    .len(len),
    .i_tdata(i_tdata[2*WIDTH-1:WIDTH]), .i_tlast(i_tlast), .i_tvalid(i_tvalid), .i_tready(i_tready),
    .o_tdata(o_tdata[2*(WIDTH+$clog2(MAX_LEN+1))-1:WIDTH+$clog2(MAX_LEN+1)]), .o_tlast(o_tlast), .o_tvalid(o_tvalid), .o_tready(o_tready));

  moving_sum #(
    .MAX_LEN(MAX_LEN),
    .WIDTH(WIDTH))
  inst_moving_sum_imag (
    .clk(clk), .reset(reset), .clear(clear),
    .len(len),
    .i_tdata(i_tdata[WIDTH-1:0]), .i_tlast(1'b0), .i_tvalid(i_tvalid), .i_tready(),
    .o_tdata(o_tdata[WIDTH+$clog2(MAX_LEN+1)-1:0]), .o_tlast(), .o_tvalid(), .o_tready(o_tready));

endmodule