//
// Copyright 2018 SkySafe Inc.
//
module short_preamble_detector #(
  parameter WIDTH           = 32,
  parameter WINDOW_LEN      = 64,
  // D Metric threshold, (0.25, 1.0)
  // Approximate detection ranges:
  // SNR > 0: 0.5
  // SNR > 3: 0.7
  // SNR > 5: 0.8
  parameter THRESHOLD       = 0.8
)(
  input clk, input reset,
  input [15:0] i_corr_tdata, input i_corr_tvalid, output i_corr_tready,
  input [15:0] i_power_tdata, input i_power_tvalid, output i_power_tready,
  input [WIDTH-1:0] i_samples_tdata, input i_samples_tvalid, output i_samples_tready,
  // o_phase_tlast asserts on phase angle at peak
  output [15:0] o_phase_tdata, output o_phase_tlast, output o_phase_tvalid, input o_phase_tready,
  output [WIDTH-1:0] o_samples_tdata, output o_samples_tlast, output o_samples_tvalid, input o_samples_tready
);

  // Calculate magnitude and phase angle
  wire [31:0] corr_magphase_tdata;
  wire corr_magphase_tvalid, corr_magphase_tready;
  complex_to_magphase inst_complex_to_magphase (
    .aclk(clk), .aresetn(~reset),
    .s_axis_cartesian_tdata({i_corr_tdata[15:0], i_corr_tdata[31:16]}), // Reverse I/Q input to match Xilinx's format
    .s_axis_cartesian_tlast(1'b0), .s_axis_cartesian_tvalid(i_corr_tvalid[0]), .s_axis_cartesian_tready(i_corr_tready[0]),
    .m_axis_dout_tdata(corr_magphase_tdata), // [31:16] phase, [15:0] magnitude
    .m_axis_dout_tlast(), .m_axis_dout_tvalid(corr_magphase_tvalid), .m_axis_dout_tready(corr_magphase_tready));

  // Sync streams
  wire [15:0] corr_phase_tdata, corr_mag_tdata;
  wire [15:0] power_tdata;
  wire [WIDTH-1:0] samples_tdata;
  wire samples_tvalid, samples_tready;
  wire [1:0] dont_care;
  axi_sync #(
    .SIZE(3),
    .WIDTH_VEC({32,16,WIDTH}),
    .FIFO_SIZE_VEC({0,5,5}))
  inst_axi_sync (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata({corr_magphase_tdata, i_power_data, i_samples_tdata}),
    .i_tlast(3'b0),
    .i_tvalid({corr_magphase_tvalid, i_power_tvalid, i_samples_tvalid}),
    .i_tready({corr_magphase_tready, i_power_tready, i_samples_tready}),
    .o_tdata({corr_phase_tdata, corr_mag_tdata}, power_tdata, samples_tdata}),
    .o_tlast(),
    // dont_care because all valids are aligned
    .o_tvalid({dont_care[0], dont_care[1], samples_tvalid}),
    .o_tready({samples_tready, samples_tready, samples_tready}));

  wire [15:0] d_metric_approx, d_metric_approx_reg;
  wire [15:0] phase, phase_reg;
  wire trigger, trigger_reg;

  // Calculate approximate D metric
  // Removes divider and multiplier at cost of less flexible threshold value
  // Derivation:
  //   D < |P(d)|^2/R(d)^2
  //   D^(1/2) < |P(d)|/R(d)
  //   |P(d)| - D^(1/2)*R(d) > 0 --> |P(d)| - (1 - 1/N)*R(d) > 0
  localparam THRESHOLD_POW2 = $clog2(1.0/(1.0-THRESHOLD**(0.5)));
  assign d_metric_approx  = corr_mag_tdata - (power_tdata - (power_tdata >>> THRESHOLD_POW2));
  assign trigger          = (d_metric_approx > 0);
  assign phase            = corr_phase_tdata >>> $clog2(WINDOW_LEN);

  wire [WIDTH-1:0] samples_reg_tdata;
  wire samples_reg_tvalid, samples_reg_tready;
  axi_fifo_flop #(
    .WIDTH(1+16+16+WIDTH)
  axi_fifo_flop (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata({trigger, d_metric_approx, phase, samples_tdata}),
    .i_tvalid(samples_tvalid), .i_tready(samples_tready),
    .o_tdata({trigger_reg, d_metric_approx_reg, phase_reg, samples_reg_tdata}),
    .o_tvalid(samples_reg_tvalid), .o_tready(samples_reg_tready));

  /////////////////////////////////////////////////////////
  // Detect peak via finding the zero crossing
  /////////////////////////////////////////////////////////
  reg [15:0] prev_d_metric_approx;

  wire zero_crossing = trigger_reg & ((d_metric_approx_reg - prev_d_metric_approx) <= 0);

  always @(posedge clk) begin
    if (reset) begin
      prev_d_metric_approx     <= 16'd0;
    end else begin
      if (samples_reg_tvalid & samples_reg_tready) begin
        if (trigger_reg) begin
          prev_d_metric_approx <= d_metric_approx_reg;
        end else begin
          prev_d_metric_approx <= 16'd0;
        end
      end
    end
  end

  wire [WIDTH-1:0] unused_samples;
  wire [15:0] unused_phase;
  split_stream_fifo #(
    .WIDTH(WIDTH+16),
    .FIFO_SIZE(0),
    .ACTIVE_MASK(4'b0011))
  inst_split_stream_fifo (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata({phase_reg, samples_reg_tvalid}), .i_tlast({zero_crossing, zero_crossing}),
    .i_tvalid(samples_reg_tvalid), .i_tready(samples_reg_tready),
    .o0_tdata({unused_phase, o_samples_tdata}), .o0_tlast(o_samples_tlast),
    .o0_tvalid(o_samples_tvalid), .o0_tready(o_samples_tready),
    .o1_tdata({o_phase_tdata, unused_samples}), .o1_tlast(o_phase_tlast),
    .o1_tvalid(o_phase_tvalid), .o1_tready(o_phase_tready),
    .o2_tdata(), .o2_tlast(), .o2_tvalid(), .o2_tready(),
    .o3_tdata(), .o3_tlast(), .o3_tvalid(), .o2_tready());

endmodule