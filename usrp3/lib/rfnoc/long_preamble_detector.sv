//
// Copyright 2018 SkySafe Inc.
//
module long_preamble_detector #(
  parameter WIDTH         = 32,
  parameter PEAK_DELTA    = 64,  // Expected number of samples between peaks
  parameter PREAMBLE_LEN  = 160,
  parameter SEARCH_PAD    = 32,  // Extra samples to search due to short preamble location uncertainty & cyclic prefix
  parameter CORR_LEN      = 80,
  parameter [2*2*CORR_LEN-1:0] CORR_COEFFS = 0,
  // Used to adjust when o_tlast is asserted. Examples:
  // - Set to 0, o_tlast marks start of long preamble
  // - Set to PREAMBLE_LEN, o_tlast marks end of long preamble
  // - Set to -PREAMBLE_LEN, o_tlast marks beginning of short preamble
  parameter DELAY_ADJ = 0
)(
  input clk, input reset,
  input [WIDTH-1:0] i_tdata, input i_tlast, input i_tvalid, output i_tready,
  output [WIDTH-1:0] o_tdata, output o_tlast, output o_tvalid, input o_tready,
  output reg [47:0] total_detect, output reg [47:0] false_detect
);

  /////////////////////////////////////////////////////////////////////////////
  // Calculate absolute value of cross correlation
  /////////////////////////////////////////////////////////////////////////////
  localparam NUM_STAGES  = $clog2(CORR_LEN)+1;
  localparam XCORR_DELAY = NUM_STAGES+2;
  localparam XCORR_WIDTH = NUM_STAGES+2;

  wire real_coeffs[0:CORR_LEN-1];
  wire imag_coeffs[0:CORR_LEN-1];
  reg samples_real[0:CORR_LEN-1];
  reg samples_imag[0:CORR_LEN-1];
  wire signed [2:0] ac[0:CORR_LEN-1], bd[0:CORR_LEN-1], ad[0:CORR_LEN-1], bc[0:CORR_LEN-1];
  wire signed [2:0] ac_minus_bd[0:CORR_LEN-1], ad_plus_bc[0:CORR_LEN-1];
  reg signed [XCORR_WIDTH-1:0] xcorr_sum_real[0:NUM_STAGES-1][0:CORR_LEN-1];
  reg signed [XCORR_WIDTH-1:0] xcorr_sum_imag[0:NUM_STAGES-1][0:CORR_LEN-1];
  wire unsigned [XCORR_WIDTH-1:0] max, min, abs_real, abs_imag;
  reg unsigned [XCORR_WIDTH-1:0] xcorr_abs;

  genvar i, n;
  generate
    for (i = 0; i < CORR_LEN; i = i + 1) begin
      // 1-bit coefficients
      assign real_coeffs[i] = CORR_COEFFS[2*i+1];
      assign imag_coeffs[i] = CORR_COEFFS[2*i];
      // 1-bit samples
      always @(posedge clk) begin
        if (reset) begin
          samples_real[i] <= 0;
          samples_imag[i] <= 0;
        end else if (i_tvalid & i_tready) begin
          if (i == 0) begin
            samples_real[0] <= i_tdata[WIDTH-1];
            samples_imag[0] <= i_tdata[WIDTH/2-1];
          end else begin
            samples_real[i] <= samples_real[i-1];
            samples_imag[i] <= samples_imag[i-1];
          end
        end
      end
      // 1-bit complex mult
      // (a + bj)*(c + dj) = (ac - bd) + j(ad + bc)
      assign ac[i] = (real_coeffs[i] ^ samples_real[i]) ? -2'sd1 : 2'sd1;
      assign bd[i] = (imag_coeffs[i] ^ samples_imag[i]) ? -2'sd1 : 2'sd1;
      assign ad[i] = (real_coeffs[i] ^ samples_imag[i]) ? -2'sd1 : 2'sd1;
      assign bc[i] = (imag_coeffs[i] ^ samples_real[i]) ? -2'sd1 : 2'sd1;
      assign ac_minus_bd[i] = ac[i] - bd[i];
      assign ad_plus_bc[i]  = ad[i] + bc[i];
      always @(posedge clk) begin
        if (i_tvalid & i_tready) begin
          xcorr_sum_real[0][i][2:0] <= ac_minus_bd[i];
          xcorr_sum_imag[0][i][2:0] <= ad_plus_bc[i];
        end
      end
    end
  endgenerate
  generate
    // Sum with an adder tree
    for (n = 0; n < NUM_STAGES; n = n + 1) begin
      for (i = 0; i < CORR_LEN; i = i + 1) begin
        initial begin
          xcorr_sum_real[n][i] <= 0;
          xcorr_sum_imag[n][i] <= 0;
        end
        // Vivado synth needs some help with optimization, only add necessary terms and bits.
        always @(posedge clk) begin
          if (i_tready & i_tvalid) begin
            if (i < (CORR_LEN/2**(n+1) + (CORR_LEN % 2**(n+1) != 0))) begin
              xcorr_sum_real[n+1][i][n+3:0] <= $signed(xcorr_sum_real[n][2*i][n+2:0]) + $signed(xcorr_sum_real[n][2*i+1][n+2:0]);
              xcorr_sum_imag[n+1][i][n+3:0] <= $signed(xcorr_sum_imag[n][2*i][n+2:0]) + $signed(xcorr_sum_imag[n][2*i+1][n+2:0]);
            end
          end
        end
      end
    end
  endgenerate

  // Magnitude Approx
  // Mag ~= max(|I|, |Q|) + 1/4 * min(|I|, |Q|)
  assign abs_real = xcorr_sum_real[NUM_STAGES-1][0] > 0 ? $unsigned( xcorr_sum_real[NUM_STAGES-1][0]) :
                                                          $unsigned(-xcorr_sum_real[NUM_STAGES-1][0]);
  assign abs_imag = xcorr_sum_imag[NUM_STAGES-1][0] > 0 ? $unsigned( xcorr_sum_imag[NUM_STAGES-1][0]) :
                                                          $unsigned(-xcorr_sum_imag[NUM_STAGES-1][0]);
  assign max      = abs_real > abs_imag ? abs_real : abs_imag;
  assign min      = abs_real > abs_imag ? abs_imag : abs_real;
  always @(posedge clk) begin
    if (i_tready & i_tvalid) begin
      xcorr_abs <= max + (min >> 2);
    end
  end

  /////////////////////////////////////////////////////////////////////////////
  // Peak Finding State Machine
  /////////////////////////////////////////////////////////////////////////////
  reg [2:0] state;
  localparam S_IDLE        = 3'd0;
  localparam S_FIRST_PEAK  = 3'd1;
  localparam S_SECOND_PEAK = 3'd2;
  localparam S_CHECK       = 3'd3;
  localparam S_SET_TLAST   = 3'd4;
  localparam S_DELAY       = 3'd5;

  // See DELAY_ADJ param
  localparam POS_DELAY_ADJ = DELAY_ADJ > 0 ? DELAY_ADJ : 0;
  localparam NEG_DELAY_ADJ = DELAY_ADJ < 0 ? DELAY_ADJ : 0;

  localparam DELAY = 2**$clog2(PREAMBLE_LEN+SEARCH_PAD)-1 + NEG_DELAY_ADJ;

  reg [XCORR_WIDTH-1:0] peak_xcorr[0:1];
  // +1 ensures long enough counter for extra cycles in state machine
  reg [$clog2(PREAMBLE_LEN+SEARCH_PAD+POS_DELAY_ADJ):0] peak_index[0:1], cnt, offset;

  always @(posedge clk) begin
    if (reset) begin
      total_detect <= 0;
      false_detect <= 0;
      state        <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: begin
          peak_xcorr[0] <= 0;
          peak_xcorr[1] <= 0;
          if (i_tready & i_tvalid & i_tlast) begin
            cnt   <= 1; // Account for delay through cross correlation calc
            state <= S_FIRST_PEAK;
          end
        end
        S_FIRST_PEAK: begin
          if (i_tready & i_tvalid) begin
            if (xcorr_abs >= peak_xcorr[0]) begin
              peak_xcorr[0]   <= xcorr_abs;
              peak_index[0]   <= cnt;
            end
            cnt <= cnt + 1;
            if (cnt == CORR_LEN+SEARCH_PAD+XCORR_DELAY-1) begin
              state <= S_SECOND_PEAK;
            end
          end
        end
        S_SECOND_PEAK: begin
          if (i_tready & i_tvalid) begin
            if (xcorr_abs >= peak_xcorr[1]) begin
              peak_xcorr[1]   <= xcorr_abs;
              peak_index[1]   <= cnt;
            end
            cnt <= cnt + 1;
            if (cnt == PREAMBLE_LEN+SEARCH_PAD+XCORR_DELAY-1) begin
              state <= S_CHECK;
            end
          end
        end
        S_CHECK: begin
          total_detect   <= total_detect + 1;
          if (i_tready & i_tvalid) begin
            cnt <= cnt + 1;
          end
          // Check distance between peaks
          if (peak_index[1] - peak_index[0] == PEAK_DELTA) begin
            // Extra -1 to account for transition to S_SET_TLAST state
            offset       <= (DELAY - NEG_DELAY_ADJ) - (PREAMBLE_LEN - peak_index[1]) - XCORR_DELAY + POS_DELAY_ADJ - 1;
            state        <= S_DELAY;
          end else begin
            false_detect <= false_detect + 1;
            state        <= S_IDLE; // Abort!
          end
        end
        S_DELAY: begin
          if (i_tready & i_tvalid) begin
            cnt <= cnt + 1;
            if (cnt == offset) begin
              state <= S_SET_TLAST;
            end
          end
        end
        S_SET_TLAST: begin
          if (i_tready & i_tvalid) begin
            state <= S_IDLE;
          end
        end
        default: state <= S_IDLE;
      endcase
    end
  end

  delay_fifo #(.MAX_LEN(DELAY), .WIDTH(32)) inst_delay_fifo (
    .clk(clk), .reset(reset), .clear(1'b0),
    .len(DELAY[$clog2(DELAY+1)-1:0]),
    .i_tdata(i_tdata), .i_tlast(1'b0), .i_tvalid(i_tvalid), .i_tready(i_tready),
    .o_tdata(o_tdata), .o_tlast(), .o_tvalid(o_tvalid), .o_tready(o_tready));

  assign o_tlast  = (state == S_SET_TLAST);

endmodule
