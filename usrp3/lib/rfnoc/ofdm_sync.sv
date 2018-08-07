//
// Copyright 2018 SkySafe Inc.
//
module ofdm_sync #(
  parameter WINDOW_LEN         = 80,
  parameter SYMBOL_LEN         = 64,
  parameter CYCLIC_PREFIX_LEN  = 16,
  parameter PREAMBLE_LEN       = 160,
  parameter MAX_NUM_SYMBOLS    = 512
)(
  input clk, input reset,
  input [$clog2(MAX_NUM_SYMBOLS+1)-1:0] num_symbols, input num_symbols_valid,
  input [31:0] i_tdata, input i_tlast, input i_tvalid, output i_tready,
  output [31:0] o_tdata, output o_tlast, output o_tvalid, input o_tready,
  output o_sof, output o_eof
);

  // TODO: Implement AGC instead of these fixed gains
  localparam GAIN = 3;
  localparam GAIN2 = 0;

  wire [31:0] samples_in_tdata[0:3];
  wire [3:0] samples_in_tvalid, samples_in_tready;
  split_stream_fifo #(
    .WIDTH(32),
    .ACTIVE_MASK(4'b1111),
    .FIFO_SIZE(0))
  inst_split_stream_fifo_samples (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata(i_tdata), .i_tlast(1'b0), .i_tvalid(i_tvalid), .i_tready(i_tready),
    .o0_tdata(samples_in_tdata[0]), .o0_tlast(), .o0_tvalid(samples_in_tvalid[0]), .o0_tready(samples_in_tready[0]),
    .o1_tdata(samples_in_tdata[1]), .o1_tlast(), .o1_tvalid(samples_in_tvalid[1]), .o1_tready(samples_in_tready[1]),
    .o2_tdata(samples_in_tdata[2]), .o2_tlast(), .o2_tvalid(samples_in_tvalid[2]), .o2_tready(samples_in_tready[2]),
    .o3_tdata(samples_in_tdata[3]), .o3_tlast(), .o3_tvalid(samples_in_tvalid[3]), .o3_tready(samples_in_tready[3]));

  /////////////////////////////////////////////////////////
  // Calculate correlation, P(d)
  /////////////////////////////////////////////////////////
  wire [31:0] samples_dly_tdata;
  wire        samples_dly_tvalid, samples_dly_tready;
  delay_fifo #(
    .MAX_LEN(WINDOW_LEN),
    .WIDTH(32))
  inst_delay_fifo_samples (
    .clk(clk), .reset(reset), .clear(1'b0),
    .len(WINDOW_LEN),
    .i_tdata(samples_in_tdata[0]), .i_tlast(1'b0), .i_tvalid(samples_in_tvalid[0]), .i_tready(samples_in_tready[0]),
    .o_tdata(samples_dly_tdata), .o_tlast(), .o_tvalid(samples_dly_tvalid), .o_tready(samples_dly_tready));

  wire [31:0] samples_conj_tdata;
  wire        samples_conj_tvalid, samples_conj_tready;
  conj #(
    .WIDTH(16))
  inst_conj_samples (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata(samples_dly_tdata), .i_tlast(1'b0), .i_tvalid(samples_dly_tvalid), .i_tready(samples_dly_tready),
    .o_tdata(samples_conj_tdata), .o_tlast(), .o_tvalid(samples_conj_tvalid), .o_tready(samples_conj_tready));

  wire [63:0] corr_tdata;
  wire        corr_tvalid, corr_tready;
  cmul inst_cmul_corr (
    .clk(clk), .reset(reset),
    .a_tdata(samples_in_tdata[1]), .a_tlast(1'b0), .a_tvalid(samples_in_tvalid[1]), .a_tready(samples_in_tready[1]),
    .b_tdata(samples_conj_tdata), .b_tlast(1'b0), .b_tvalid(samples_conj_tvalid), .b_tready(samples_conj_tready),
    .o_tdata(corr_tdata), .o_tlast(), .o_tvalid(corr_tvalid), .o_tready(corr_tready));

  wire [31:0] corr_rnd_tdata;
  wire        corr_rnd_tvalid, corr_rnd_tready;
  axi_round_and_clip_complex #(
    .WIDTH_IN(32),
    .WIDTH_OUT(16),
    .CLIP_BITS(GAIN))
  inst_axi_round_and_clip_complex_corr (
    .clk(clk), .reset(reset),
    .i_tdata(corr_tdata), .i_tlast(1'b0), .i_tvalid(corr_tvalid), .i_tready(corr_tready),
    .o_tdata(corr_rnd_tdata), .o_tlast(), .o_tvalid(corr_rnd_tvalid), .o_tready(corr_rnd_tready));

  localparam CORR_WIDTH = 16+$clog2(WINDOW_LEN+1);
  wire [2*CORR_WIDTH-1:0] corr_ms_tdata;
  wire corr_ms_tvalid, corr_ms_tready;
  moving_sum_complex #(
    .MAX_LEN(WINDOW_LEN),
    .WIDTH(16))
  inst_moving_sum_corr (
    .clk(clk), .reset(reset), .clear(1'b0),
    .len(WINDOW_LEN),
    .i_tdata(corr_rnd_tdata), .i_tlast(1'b0), .i_tvalid(corr_rnd_tvalid), .i_tready(corr_rnd_tready),
    .o_tdata(corr_ms_tdata), .o_tlast(), .o_tvalid(corr_ms_tvalid), .o_tready(corr_ms_tready));

  wire [31:0] corr_ms_rnd_tdata;
  wire        corr_ms_rnd_tvalid, corr_ms_rnd_tready;
  axi_round_and_clip_complex #(
    .WIDTH_IN(CORR_WIDTH),
    .WIDTH_OUT(16),
    .CLIP_BITS(GAIN2))
  inst_axi_round_and_clip_complex_corr_ms (
    .clk(clk), .reset(reset),
    .i_tdata(corr_ms_tdata), .i_tlast(1'b0), .i_tvalid(corr_ms_tvalid), .i_tready(corr_ms_tready),
    .o_tdata(corr_ms_rnd_tdata), .o_tlast(), .o_tvalid(corr_ms_rnd_tvalid), .o_tready(corr_ms_rnd_tready));

  /////////////////////////////////////////////////////////
  // Calculate power, R(d)
  /////////////////////////////////////////////////////////
  wire [31:0] power_tdata;
  wire        power_tvalid, power_tready;
  complex_to_magsq #(
    .WIDTH(16))
  inst_complex_to_magsq_power (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata(samples_in_tdata[2]), .i_tlast(1'b0), .i_tvalid(samples_in_tvalid[2]), .i_tready(samples_in_tready[2]),
    .o_tdata(power_tdata), .o_tlast(), .o_tvalid(power_tvalid), .o_tready(power_tready));

  wire [15:0] power_rnd_tdata;
  wire        power_rnd_tvalid, power_rnd_tready;
  axi_round_and_clip #(
    .WIDTH_IN(32),
    .WIDTH_OUT(16),
    .CLIP_BITS(GAIN-1))
  inst_axi_round_power (
    .clk(clk), .reset(reset),
    .i_tdata(power_tdata), .i_tlast(1'b0), .i_tvalid(power_tvalid), .i_tready(power_tready),
    .o_tdata(power_rnd_tdata), .o_tlast(), .o_tvalid(power_rnd_tvalid), .o_tready(power_rnd_tready));

  // Moving sum over two window lengths to prevent false detections at beginning and end of packets
  // This is a difference from original Schmidl Cox algorithm
  localparam POWER_WIDTH = 16+$clog2(WINDOW_LEN+1);
  wire [POWER_WIDTH-1:0] power_ms_tdata;
  wire power_ms_tvalid, power_ms_tready;
  moving_sum #(
    .MAX_LEN(WINDOW_LEN),
    .WIDTH(16))
  inst_moving_sum_power (
    .clk(clk), .reset(reset), .clear(1'b0),
    .len(WINDOW_LEN),
    .i_tdata(power_rnd_tdata), .i_tlast(1'b0), .i_tvalid(power_rnd_tvalid), .i_tready(power_rnd_tready),
    .o_tdata(power_ms_tdata), .o_tlast(), .o_tvalid(power_ms_tvalid), .o_tready(power_ms_tready));

  wire [15:0] power_ms_rnd_tdata;
  wire        power_ms_rnd_tvalid, power_ms_rnd_tready;
  axi_round_and_clip #(
    .WIDTH_IN(POWER_WIDTH),
    .WIDTH_OUT(16),
    .CLIP_BITS(GAIN2))
  inst_axi_round_and_clip_power_ms (
    .clk(clk), .reset(reset),
    .i_tdata(power_ms_tdata), .i_tlast(1'b0), .i_tvalid(power_ms_tvalid), .i_tready(power_ms_tready),
    .o_tdata(power_ms_rnd_tdata), .o_tlast(), .o_tvalid(power_ms_rnd_tvalid), .o_tready(power_ms_rnd_tready));

  /////////////////////////////////////////////////////////
  // Short Preamble Peak Detection, Course Frequency Correction
  /////////////////////////////////////////////////////////
  wire [31:0] samples_out_tdata;
  wire samples_out_tlast, samples_out_tvalid, samples_out_tready;
  wire [15:0] phase_inc_tdata;
  wire phase_inc_tlast, phase_inc_tvalid, phase_inc_tready;
  short_preamble_detector #(
    .WIDTH(32),
    .WINDOW_LEN(WINDOW_LEN),
    .THRESHOLD(0.7))
  inst_short_preamble_detector (
    .clk(clk), .reset(reset),
    .i_corr_tdata(corr_ms_rnd_tdata),
    .i_corr_tvalid(corr_ms_rnd_tvalid), .i_corr_tready(corr_ms_rnd_tready),
    .i_power_tdata(power_ms_rnd_tdata),
    .i_power_tvalid(power_ms_rnd_tvalid), .i_power_tready(power_ms_rnd_tready),
    .i_samples_tdata(samples_in_tdata[3]),
    .i_samples_tvalid(samples_in_tvalid[3]), .i_samples_tready(samples_in_tready[3]),
    .o_phase_tdata(phase_inc_tdata), .o_phase_tlast(phase_inc_tlast),
    .o_phase_tvalid(phase_inc_tvalid), .o_phase_tready(phase_inc_tready),
    .o_samples_tdata(samples_out_tdata), .o_samples_tlast(samples_out_tlast),
    .o_samples_tvalid(samples_out_tvalid), .o_samples_tready(samples_out_tready));

  wire [15:0] phase_accum_tdata;
  wire phase_accum_tvalid, phase_accum_tready;
  phase_accum #(
    .WIDTH_ACCUM(16),
    .WIDTH_IN(16),
    .WIDTH_OUT(16))
  inst_phase_accum (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata(phase_inc_tdata), .i_tlast(phase_inc_tlast), .i_tvalid(phase_inc_tvalid), .i_tready(phase_inc_tready),
    .o_tdata(phase_accum_tdata), .o_tlast(), .o_tvalid(phase_accum_tvalid), .o_tready(phase_accum_tready));

  wire [31:0] samples_fc_tdata;
  wire samples_fc_tlast, samples_fc_tvalid, samples_fc_tready;
  cordic_rotator inst_cordic_rotator_coarse_freq_correction (
    .aclk(clk), .aresetn(~reset),
    .s_axis_phase_tdata(phase_accum_tdata),
    .s_axis_phase_tvalid(phase_accum_tvalid), .s_axis_phase_tready(phase_accum_tready),
    .s_axis_cartesian_tdata({samples_out_tdata[15:0],samples_out_tdata[31:16]}), .s_axis_cartesian_tlast(samples_out_tlast),
    .s_axis_cartesian_tvalid(samples_out_tvalid), .s_axis_cartesian_tready(samples_out_tready),
    .m_axis_dout_tdata({samples_fc_tdata[15:0],samples_fc_tdata[31:16]}), .m_axis_dout_tlast(samples_fc_tlast),
    .m_axis_dout_tvalid(samples_fc_tvalid), .m_axis_dout_tready(samples_fc_tready));

  /////////////////////////////////////////////////////////
  // Long Preamble Peak Detection, Fine Timing Correction
  /////////////////////////////////////////////////////////
  // Quantized long preamble
  // 16 samples cyclic prefix + 64 samples long preamble symbol
  localparam CORR_LEN = 80;
  localparam [32*2*CORR_LEN-1:0] CORR_COEFFS = {
    {-1,-1},{ 1,-1},{ 1, 1},{ 1, 1},{ 1,-1},{-1,-1},{-1,-1},{ 1,-1},{ 1, 1},{ 1,-1},
    {-1,-1},{ 1,-1},{ 1,-1},{-1, 1},{ 1,-1},{ 1,-1},{ 1, 1},{-1, 1},{-1, 1},{ 1, 1},
    { 1, 1},{-1, 1},{-1,-1},{-1,-1},{-1,-1},{-1,-1},{ 1,-1},{-1, 1},{-1, 1},{ 1, 1},
    { 1, 1},{-1,-1},{ 1,-1},{ 1,-1},{-1,-1},{-1,-1},{ 1, 1},{-1, 1},{-1, 1},{-1, 1},
    {-1, 1},{-1,-1},{ 1,-1},{ 1,-1},{-1,-1},{-1,-1},{ 1,-1},{ 1, 1},{ 1, 1},{-1,-1},
    { 1, 1},{ 1, 1},{-1, 1},{ 1, 1},{ 1,-1},{ 1, 1},{-1, 1},{-1, 1},{ 1, 1},{ 1,-1},
    { 1,-1},{ 1, 1},{-1, 1},{ 1,-1},{-1,-1},{ 1,-1},{ 1, 1},{ 1, 1},{ 1,-1},{-1,-1},
    {-1,-1},{ 1,-1},{ 1, 1},{ 1,-1},{-1,-1},{ 1,-1},{ 1,-1},{-1, 1},{ 1,-1},{ 1,-1}};

  wire [31:0] samples_lp_align_tdata;
  wire samples_lp_align_tlast, samples_lp_align_tvalid, samples_lp_align_tready;
  long_preamble_detector #(
    .WIDTH(32),
    .PEAK_DELTA(SYMBOL_LEN),
    .PREAMBLE_LEN(PREAMBLE_LEN),
    .SEARCH_PAD(32),
    .CORR_LEN(CORR_LEN),
    .CORR_COEFFS(CORR_COEFFS),
    .DELAY_ADJ(0))  // o_tlast marks start of long preamble
  inst_long_preamble_detector (
    .clk(clk), .reset(reset),
    .i_tdata(samples_fc_tdata), .i_tlast(samples_fc_tlast),
    .i_tvalid(samples_fc_tvalid), .i_tready(samples_fc_tready),
    .o_tdata(samples_lp_align_tdata), .o_tlast(samples_lp_align_tlast),
    .o_tvalid(samples_lp_align_tvalid), .o_tready(samples_lp_align_tready));

  ofdm_framer #(
    .WIDTH(32),
    .INITIAL_GAP(24),
    .LONG_PREAMBLE_NUM_SYMBOLS(2),
    .CYCLIC_PREFIX_LEN(CYCLIC_PREFIX_LEN),
    .SYMBOL_LEN(SYMBOL_LEN),
    .MAX_NUM_SYMBOLS(MAX_NUM_SYMBOLS))
  inst_ofdm_framer (
    .clk(clk), .reset(reset),
    .num_symbols(num_symbols), .num_symbols_valid(num_symbols_valid),
    .i_tdata(samples_lp_align_tdata), .i_tlast(samples_lp_align_tlast),
    .i_tvalid(samples_lp_align_tvalid), .i_tready(samples_lp_align_tready),
    .o_tdata(o_tdata), .o_tlast(o_tlast),
    .o_tvalid(o_tvalid), .o_tready(o_tready),
    .o_sof(o_sof), .o_eof(o_eof));

endmodule