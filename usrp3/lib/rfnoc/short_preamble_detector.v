//
// Copyright 2018 SkySafe Inc.
//
module short_preamble_detector #(
  parameter WIDTH           = 32,
  parameter WINDOW_LEN      = 80,
  // D Metric threshold, (0.25, 1.0)
  // Approximate detection ranges:
  // SNR > 0: 0.5
  // SNR > 3: 0.7
  // SNR > 5: 0.8
  parameter THRESHOLD       = 0.7,
  // Divide by 80 approximation constants
  parameter DIV_A           = 6,
  parameter DIV_B           = 8,
  parameter DELAY_ADJ       = 0
)(
  input clk, input reset,
  input [31:0] i_corr_tdata, input i_corr_tvalid, output i_corr_tready,
  input [15:0] i_power_tdata, input i_power_tvalid, output i_power_tready,
  input [WIDTH-1:0] i_samples_tdata, input i_samples_tvalid, output i_samples_tready,
  // o_phase_tlast asserts on phase angle at peak
  output [15:0] o_phase_tdata, output o_phase_tlast, output o_phase_tvalid, input o_phase_tready,
  output [WIDTH-1:0] o_samples_tdata, output o_samples_tlast, output o_samples_tvalid, input o_samples_tready
);

  /////////////////////////////////////////////////////////
  // Calculate magnitude and phase angle
  /////////////////////////////////////////////////////////
  wire [31:0] corr_magphase_tdata;
  wire corr_magphase_tvalid, corr_magphase_tready;
  complex_to_magphase inst_complex_to_magphase (
    .aclk(clk), .aresetn(~reset),
    .s_axis_cartesian_tdata({i_corr_tdata[15:0], i_corr_tdata[31:16]}), // Reverse I/Q input to match Xilinx's format
    .s_axis_cartesian_tlast(1'b0), .s_axis_cartesian_tvalid(i_corr_tvalid), .s_axis_cartesian_tready(i_corr_tready),
    .m_axis_dout_tdata(corr_magphase_tdata), // [31:16] phase, [15:0] magnitude
    .m_axis_dout_tlast(), .m_axis_dout_tvalid(corr_magphase_tvalid), .m_axis_dout_tready(corr_magphase_tready));

  // Sync streams
  wire signed [15:0] corr_phase_tdata, corr_mag_tdata;
  wire signed [15:0] power_tdata;
  wire [WIDTH-1:0] samples_tdata;
  wire samples_tvalid, samples_tready;
  wire [1:0] dont_care;
  axi_sync #(
    .SIZE(3),
    .WIDTH_VEC({32,16,WIDTH}),
    .FIFO_SIZE_VEC({0,5,5}))
  inst_axi_sync (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata({corr_magphase_tdata, i_power_tdata, i_samples_tdata}),
    .i_tlast(3'b0),
    .i_tvalid({corr_magphase_tvalid, i_power_tvalid, i_samples_tvalid}),
    .i_tready({corr_magphase_tready, i_power_tready, i_samples_tready}),
    .o_tdata({{corr_phase_tdata, corr_mag_tdata}, power_tdata, samples_tdata}),
    .o_tlast(),
    // dont_care because all valids are aligned
    .o_tvalid({dont_care[0], dont_care[1], samples_tvalid}),
    .o_tready({samples_tready, samples_tready, samples_tready}));

  /////////////////////////////////////////////////////////
  // Calculate approximate D metric
  /////////////////////////////////////////////////////////
  // Removes divider and multiplier at cost of less flexible threshold value
  // Derivation:
  //   D < |P(d)|^2/R(d)^2
  //   D^(1/2) < |P(d)|/R(d)
  //   |P(d)| - D^(1/2)*R(d) > 0 --> |P(d)| - (1 - 1/N)*R(d) > 0
  localparam THRESHOLD_POW2 = $clog2($rtoi(1.0/(1.0-THRESHOLD**(0.5))));

  wire signed [15:0] d_metric_approx, d_metric_approx_reg;
  wire signed [15:0] phase, phase_reg;

  assign d_metric_approx  = corr_mag_tdata - (power_tdata - (power_tdata >>> THRESHOLD_POW2));
  generate
    if (2**$clog2(WINDOW_LEN) == WINDOW_LEN) begin
      assign phase        = corr_phase_tdata >>> $clog2(WINDOW_LEN);
    // Approximate division
    end else begin
      assign phase        = (corr_phase_tdata >>> DIV_A) - (corr_phase_tdata >>> DIV_B);
    end
  endgenerate

  wire [WIDTH-1:0] samples_reg_tdata;
  wire samples_reg_tvalid, samples_reg_tready;
  axi_fifo_flop #(
    .WIDTH(16+16+WIDTH))
  axi_fifo_flop (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata({d_metric_approx, phase, samples_tdata}),
    .i_tvalid(samples_tvalid), .i_tready(samples_tready),
    .o_tdata({d_metric_approx_reg, phase_reg, samples_reg_tdata}),
    .o_tvalid(samples_reg_tvalid), .o_tready(samples_reg_tready));

  /////////////////////////////////////////////////////////
  // Peak detection
  /////////////////////////////////////////////////////////
  localparam POS_DELAY_ADJ = DELAY_ADJ > 0 ? DELAY_ADJ : 0;
  localparam NEG_DELAY_ADJ = DELAY_ADJ < 0 ? DELAY_ADJ : 0;

  localparam DELAY = 2**$clog2(WINDOW_LEN)-1 + NEG_DELAY_ADJ;

  wire [15:0] phase_dly;
  wire [WIDTH-1:0] samples_dly_tdata;
  wire samples_dly_tvalid, samples_dly_tready;
  delay_fifo #(
    .MAX_LEN(DELAY),
    .WIDTH(16+WIDTH))
  inst_delay_fifo (
    .clk(clk), .reset(reset), .clear(1'b0),
    .len(DELAY),
    .i_tdata({phase_reg, samples_reg_tdata}), .i_tlast(1'b0), .i_tvalid(samples_reg_tvalid), .i_tready(samples_reg_tready),
    .o_tdata({phase_dly, samples_dly_tdata}), .o_tlast(), .o_tvalid(samples_dly_tvalid), .o_tready(samples_dly_tvalid));

  reg [2:0] state;
  localparam S_IDLE        = 3'd0;
  localparam S_FIND_PEAK   = 3'd1;
  localparam S_CALC_OFFSET = 3'd2;
  localparam S_DELAY       = 3'd3;
  localparam S_SET_TLAST   = 3'd4;

  reg signed [15:0] peak_phase;
  reg signed [15:0] peak_d_metric_approx;
  reg [$clog2(DELAY):0] cnt, peak_index, offset;

  always @(posedge clk) begin
    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: begin
          if (samples_reg_tvalid & samples_reg_tready) begin
            if (d_metric_approx_reg > 0) begin
              cnt                  <= 1;
              peak_index           <= 1;
              peak_phase           <= phase_reg;
              peak_d_metric_approx <= d_metric_approx_reg;
              state                <= S_FIND_PEAK;
            end
          end
        end
        S_FIND_PEAK: begin
          if (samples_reg_tvalid & samples_reg_tready) begin
            cnt <= cnt + 1;
            if (d_metric_approx_reg > peak_d_metric_approx) begin
              peak_index           <= cnt;
              peak_phase           <= phase_reg;
              peak_d_metric_approx <= d_metric_approx_reg;
            end
            if (cnt == DELAY-1) begin
              state                <= S_CALC_OFFSET;
            end
          end
        end
        S_CALC_OFFSET: begin
          if (samples_dly_tvalid & samples_dly_tready) begin
            cnt  <= cnt + 1;
          end
          offset <= (DELAY - NEG_DELAY_ADJ) + peak_index + POS_DELAY_ADJ;
          state  <= S_DELAY;
        end
        S_DELAY: begin
          if (samples_dly_tvalid & samples_dly_tready) begin
            cnt     <= cnt + 1;
            if (cnt == offset) begin
              state <= S_SET_TLAST;
            end
          end
        end
        S_SET_TLAST: begin
          if (samples_dly_tvalid & samples_dly_tready) begin
            state   <= S_IDLE;
          end
        end
        default: state <= S_IDLE;
      endcase
    end
  end

  wire trigger = (state == S_SET_TLAST);

  /////////////////////////////////////////////////////////
  // Split into independent streams
  /////////////////////////////////////////////////////////
  wire [WIDTH-1:0] unused_samples;
  wire [15:0] unused_phase;
  split_stream_fifo #(
    .WIDTH(WIDTH+16),
    .FIFO_SIZE(0),
    .ACTIVE_MASK(4'b0011))
  inst_split_stream_fifo (
    .clk(clk), .reset(reset), .clear(1'b0),
    .i_tdata({peak_phase, samples_dly_tdata}), .i_tlast(trigger),
    .i_tvalid(samples_dly_tvalid), .i_tready(samples_dly_tready),
    .o0_tdata({unused_phase, o_samples_tdata}), .o0_tlast(o_samples_tlast),
    .o0_tvalid(o_samples_tvalid), .o0_tready(o_samples_tready),
    .o1_tdata({o_phase_tdata, unused_samples}), .o1_tlast(o_phase_tlast),
    .o1_tvalid(o_phase_tvalid), .o1_tready(o_phase_tready),
    .o2_tdata(), .o2_tlast(), .o2_tvalid(), .o2_tready(),
    .o3_tdata(), .o3_tlast(), .o3_tvalid(), .o3_tready());

endmodule