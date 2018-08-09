//
// Copyright 2018 SkySafe Inc.
//
module long_preamble_detector #(
  parameter WIDTH         = 32,
  parameter PEAK_DELTA    = 64,  // Expected number of samples between peaks
  parameter PREAMBLE_LEN  = 160,
  parameter SEARCH_PAD    = 32,  // Extra samples to search due to short preamble location uncertainty & cyclic prefix
  parameter CORR_LEN      = 80,
  parameter [32*2*CORR_LEN-1:0] CORR_COEFFS = 0,
  // Used to adjust when o_tlast is asserted. Examples:
  // - Set to 0, o_tlast marks start of long preamble
  // - Set to PREAMBLE_LEN, o_tlast marks end of long preamble
  // - Set to -PREAMBLE_LEN, o_tlast marks beginning of short preamble
  parameter DELAY_ADJ = 0
)(
  input clk, input reset,
  input [WIDTH-1:0] i_tdata, input i_tlast, input i_tvalid, output i_tready,
  output [WIDTH-1:0] o_tdata, output o_tlast, output o_tvalid, input o_tready
);

  wire signed [31:0] real_coeffs[0:CORR_LEN-1];
  wire signed [31:0] imag_coeffs[0:CORR_LEN-1];

  genvar i;
  generate
    for (i = 0; i < CORR_LEN; i = i + 1) begin
      assign real_coeffs[CORR_LEN-i-1] = CORR_COEFFS[64*i+63:64*i+32];
      assign imag_coeffs[CORR_LEN-i-1] = CORR_COEFFS[64*i+31:64*i];
    end
  endgenerate

  /////////////////////////////////////////////////////////////////////////////
  // Cross correlation
  /////////////////////////////////////////////////////////////////////////////
  localparam NUM_STAGES  = $clog2(CORR_LEN)+1;
  localparam XCORR_DELAY = NUM_STAGES+2;
  localparam XCORR_WIDTH = WIDTH/2+NUM_STAGES+1;
  reg signed [WIDTH-1:0] sample_regs[0:CORR_LEN-1];
  reg signed [XCORR_WIDTH-1:0] xcorr_sum_regs[0:NUM_STAGES-1][0:CORR_LEN-1][0:1]; // Real & imag
  reg [XCORR_WIDTH-1:0] xcorr_abs;

  wire signed [XCORR_WIDTH-1:0] max, min, abs_real, abs_imag;
  assign abs_real = xcorr_sum_regs[NUM_STAGES-1][0][0] > 0 ?  xcorr_sum_regs[NUM_STAGES-1][0][0] :
                                                             -xcorr_sum_regs[NUM_STAGES-1][0][0];
  assign abs_imag = xcorr_sum_regs[NUM_STAGES-1][0][1] > 0 ?  xcorr_sum_regs[NUM_STAGES-1][0][1] :
                                                             -xcorr_sum_regs[NUM_STAGES-1][0][1];
  assign max      = abs_real > abs_imag ? abs_real : abs_imag;
  assign min      = abs_real > abs_imag ? abs_imag : abs_real;

  integer r, x, n, k;

  initial begin
    for (n = 0; n < NUM_STAGES; n = n + 1) begin
      for (k = 0; k < CORR_LEN; k = k + 1) begin
        xcorr_sum_regs[n][k][0] <= 0;
        xcorr_sum_regs[n][k][1] <= 0;
      end
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      for (r = 0; r < CORR_LEN; r = r + 1) begin
        sample_regs[r] <= 0;
      end
    end else begin
    if (i_tvalid & i_tready) begin
      // Register samples
      for (r = 0; r < CORR_LEN; r = r + 1) begin
        if (r == 0) begin
          sample_regs[0] <= i_tdata;
        end else begin
          sample_regs[r] <= sample_regs[r-1];
        end
      end
      // Apply coefficients
      // (a + bj)*(c + dj) = (ac - bd) + j(ad + bc) where a = +/-1 & b = +/-1
      for (x = 0; x < CORR_LEN; x = x + 1) begin
        xcorr_sum_regs[0][x][0] <= (real_coeffs[x] > 0 ? sample_regs[x][WIDTH-1:WIDTH/2] : -sample_regs[x][WIDTH-1:WIDTH/2]) -
                                   (imag_coeffs[x] > 0 ? sample_regs[x][WIDTH/2-1:0]     : -sample_regs[x][WIDTH/2-1:0]);
        xcorr_sum_regs[0][x][1] <= (imag_coeffs[x] > 0 ? sample_regs[x][WIDTH-1:WIDTH/2] : -sample_regs[x][WIDTH-1:WIDTH/2]) +
                                   (real_coeffs[x] > 0 ? sample_regs[x][WIDTH/2-1:0]     : -sample_regs[x][WIDTH/2-1:0]);
      end
      // Adder tree
      for (n = 0; n < NUM_STAGES; n = n + 1) begin
        for (k = 0; k < $rtoi($ceil(CORR_LEN/2.0**(n+1))); k = k + 1) begin
          xcorr_sum_regs[n+1][k][0] <= xcorr_sum_regs[n][2*k][0] + xcorr_sum_regs[n][2*k+1][0];
          xcorr_sum_regs[n+1][k][1] <= xcorr_sum_regs[n][2*k][1] + xcorr_sum_regs[n][2*k+1][1];
        end
      end
      // Magnitude Approx
      // Mag ~= max(|I|, |Q|) + 1/4 * min(|I|, |Q|)
      xcorr_abs <= max + (min >> 2);
      end 
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
      state <= S_IDLE;
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
          if (i_tready & i_tvalid) begin
            cnt <= cnt + 1;
          end
          // Check distance between peaks
          if (peak_index[1] - peak_index[0] == PEAK_DELTA) begin
            // Extra -1 to account for transition to S_SET_TLAST state
            offset <= (DELAY - NEG_DELAY_ADJ) - (PREAMBLE_LEN - peak_index[1]) - XCORR_DELAY + POS_DELAY_ADJ - 1;
            state  <= S_DELAY;
          end else begin
            state <= S_IDLE; // Abort!
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