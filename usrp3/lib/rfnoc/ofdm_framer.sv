//
// Copyright 2014-2016 Ettus Research
// Copyright 2018 Ettus Research, a National Instruments Company
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
module ofdm_framer #(
  parameter WIDTH                     = 32,
  parameter INITIAL_GAP               = 24,
  parameter LONG_PREAMBLE_NUM_SYMBOLS = 2,
  parameter CYCLIC_PREFIX_LEN         = 16,
  parameter SYMBOL_LEN                = 64,
  parameter MAX_NUM_SYMBOLS           = 256
)(
  input clk, input reset,
  input passthru,  // Output all samples
  input [$clog2(MAX_NUM_SYMBOLS+1)-1:0] num_symbols, input num_symbols_valid,
  input [WIDTH-1:0] i_tdata, input i_tlast, input i_tvalid, output i_tready,
  output [WIDTH-1:0] o_tdata, output o_tlast, output o_tvalid, input o_tready,
  output reg o_sof, output o_eof
);

  reg [2:0] state;
  localparam S_IDLE               = 3'd0;
  localparam S_INITIAL_GAP        = 3'd1;
  localparam S_LONG_PREAMBLE      = 3'd2;
  localparam S_CYCLIC_PREFIX      = 3'd3;
  localparam S_SYMBOL             = 3'd4;
  localparam S_PASSTHRU           = 3'd5;

  reg num_symbols_set;
  reg [$clog2(MAX_NUM_SYMBOLS+1)-1:0] symbol_cnt;
  reg [15:0] cnt;

  reg [31:0] false_detect = 0;

  always @(posedge clk) begin
    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: begin
          o_sof           <= 1'b0;
          cnt             <= 0;
          symbol_cnt      <= 1;
          num_symbols_set <= 1'b0;
          if (passthru) begin
            state <= S_PASSTHRU;
          end else if (i_tvalid & i_tready & i_tlast) begin
            if (INITIAL_GAP > 0) begin
              state <= S_INITIAL_GAP;
            end else if (LONG_PREAMBLE_NUM_SYMBOLS > 0) begin
              o_sof <= 1'b1;
              state <= S_LONG_PREAMBLE;
            end else if (CYCLIC_PREFIX_LEN > 0) begin
              state <= S_CYCLIC_PREFIX;
            end else begin
              state <= S_SYMBOL;
            end
          end
        end
        S_INITIAL_GAP: begin
          if (i_tvalid & i_tready) begin
            if (cnt < INITIAL_GAP-1) begin
              cnt   <= cnt + 1;
            end else begin
              cnt   <= 0;
              if (LONG_PREAMBLE_NUM_SYMBOLS > 0) begin
                o_sof <= 1'b1;
                state <= S_LONG_PREAMBLE;
              end else if (CYCLIC_PREFIX_LEN > 0) begin
                state <= S_CYCLIC_PREFIX;
              end else begin
                state <= S_SYMBOL;
              end
            end
          end
        end
        S_LONG_PREAMBLE: begin
          if (i_tvalid & i_tready) begin
            if (cnt < SYMBOL_LEN-1) begin
              cnt   <= cnt + 1;
            end else begin
              o_sof <= 1'b0;
              cnt   <= 0;
              if (symbol_cnt < LONG_PREAMBLE_NUM_SYMBOLS) begin
                symbol_cnt <= symbol_cnt + 1;
              end else begin
                symbol_cnt <= 1;
                if (CYCLIC_PREFIX_LEN > 0) begin
                  state     <= S_CYCLIC_PREFIX;
                end else begin
                  state     <= S_SYMBOL;
                end
              end
            end
          end
        end
        S_CYCLIC_PREFIX: begin
          if (i_tvalid & i_tready) begin
            if (cnt < CYCLIC_PREFIX_LEN-1) begin
              cnt   <= cnt + 1;
            end else begin
              cnt   <= 0;
              state <= S_SYMBOL;
            end
          end
        end
        S_SYMBOL: begin
          if (num_symbols_valid) begin
            num_symbols_set <= 1'b1;
          end
          if (i_tvalid & i_tready) begin
            if (cnt < SYMBOL_LEN-1) begin
              cnt <= cnt + 1;
            end else begin
              cnt <= 0;
              if (num_symbols_set & (symbol_cnt >= num_symbols)) begin
                state        <= S_IDLE;
              end else if (symbol_cnt >= MAX_NUM_SYMBOLS) begin
                state        <= S_IDLE;
              end else begin
                symbol_cnt   <= symbol_cnt + 1;
                if (CYCLIC_PREFIX_LEN > 0) begin
                  symbol_cnt <= symbol_cnt + 1;
                  state      <= S_CYCLIC_PREFIX;
                end
              end
            end
          end
        end
        S_PASSTHRU: begin
          if (i_tvalid & i_tready) begin
            if (i_tlast) begin
              o_sof   <= 1'b1;
            end
            if (cnt < SYMBOL_LEN-1) begin
              cnt     <= cnt + 1;
            end else begin
              cnt     <= 0;
              o_sof   <= 1'b0;
              if (~passthru) begin
                state <= S_IDLE;
              end
            end
          end
        end
      endcase
    end
  end

  assign o_eof = (state == S_SYMBOL) && (num_symbols_set ? (symbol_cnt >= num_symbols) : (symbol_cnt >= MAX_NUM_SYMBOLS));

  assign o_tdata  = i_tdata;
  assign o_tvalid = i_tvalid && (state == S_LONG_PREAMBLE || state == S_SYMBOL || state == S_PASSTHRU);
  assign o_tlast  = (cnt == SYMBOL_LEN-1);
  assign i_tready = o_tready;

endmodule
