//
// Copyright 2018 Ettus Research, a National Instruments Company
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
module noc_block_ofdm_sync #(
  parameter NOC_ID = 64'h0FD3_0001_0000_0000,
  parameter STR_SINK_FIFOSIZE = 11)
(
  input bus_clk, input bus_rst,
  input ce_clk, input ce_rst,
  input  [63:0] i_tdata, input  i_tlast, input  i_tvalid, output i_tready,
  output [63:0] o_tdata, output o_tlast, output o_tvalid, input  o_tready,
  output [63:0] debug
);

  ////////////////////////////////////////////////////////////
  //
  // RFNoC Shell
  //
  ////////////////////////////////////////////////////////////
  wire [31:0] set_data;
  wire [7:0]  set_addr;
  wire        set_stb;

  wire [63:0] str_sink_tdata, str_src_tdata;
  wire        str_sink_tlast, str_sink_tvalid, str_sink_tready, str_src_tlast, str_src_tvalid, str_src_tready;

  wire        clear_tx_seqnum;
  wire [15:0] src_sid, next_dst_sid;

  noc_shell #(
    .NOC_ID(NOC_ID),
    .STR_SINK_FIFOSIZE(STR_SINK_FIFOSIZE))
  noc_shell (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .i_tdata(i_tdata), .i_tlast(i_tlast), .i_tvalid(i_tvalid), .i_tready(i_tready),
    .o_tdata(o_tdata), .o_tlast(o_tlast), .o_tvalid(o_tvalid), .o_tready(o_tready),
    // Computer Engine Clock Domain
    .clk(ce_clk), .reset(ce_rst),
    // Control Sink
    .set_data(set_data), .set_addr(set_addr), .set_stb(set_stb), .set_time(), .set_has_time(),
    .rb_stb(1'b1), .rb_data(64'h0), .rb_addr(),
    // Control Source
    .cmdout_tdata(64'h0), .cmdout_tlast(1'b0), .cmdout_tvalid(1'b0), .cmdout_tready(),
    .ackin_tdata(), .ackin_tlast(), .ackin_tvalid(), .ackin_tready(1'b1),
    // Stream Sink
    .str_sink_tdata(str_sink_tdata), .str_sink_tlast(str_sink_tlast), .str_sink_tvalid(str_sink_tvalid), .str_sink_tready(str_sink_tready),
    // Stream Source
    .str_src_tdata(str_src_tdata), .str_src_tlast(str_src_tlast), .str_src_tvalid(str_src_tvalid), .str_src_tready(str_src_tready),
    // Misc
    .vita_time(64'd0), .clear_tx_seqnum(clear_tx_seqnum),
    .src_sid(src_sid), .next_dst_sid(next_dst_sid), .resp_in_dst_sid(), .resp_out_dst_sid(),
    .debug(debug));

  ////////////////////////////////////////////////////////////
  //
  // AXI Wrapper
  // Convert RFNoC Shell interface into AXI stream interface
  //
  ////////////////////////////////////////////////////////////
  wire [31:0]  m_axis_data_tdata;
  wire         m_axis_data_tlast;
  wire         m_axis_data_tvalid;
  wire         m_axis_data_tready;

  wire [31:0]  s_axis_data_tdata;
  wire         s_axis_data_tlast;
  wire         s_axis_data_tvalid;
  wire         s_axis_data_tready;

  wire sof;

  axi_wrapper #(
    .SIMPLE_MODE(0))
  axi_wrapper (
    .clk(ce_clk), .reset(ce_rst),
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .clear_tx_seqnum(clear_tx_seqnum),
    .next_dst(next_dst_sid),
    .set_stb(set_stb), .set_addr(set_addr), .set_data(set_data),
    .i_tdata(str_sink_tdata), .i_tlast(str_sink_tlast), .i_tvalid(str_sink_tvalid), .i_tready(str_sink_tready),
    .o_tdata(str_src_tdata), .o_tlast(str_src_tlast), .o_tvalid(str_src_tvalid), .o_tready(str_src_tready),
    .m_axis_data_tdata(m_axis_data_tdata),
    .m_axis_data_tlast(m_axis_data_tlast),
    .m_axis_data_tvalid(m_axis_data_tvalid),
    .m_axis_data_tready(m_axis_data_tready),
    .m_axis_data_tuser(),
    .s_axis_data_tdata(s_axis_data_tdata),
    .s_axis_data_tlast(s_axis_data_tlast),
    .s_axis_data_tvalid(s_axis_data_tvalid),
    .s_axis_data_tready(s_axis_data_tready),
    // Packet type, sequence number, and length will be automatically filled
    // Using EOB bit to indicate start of frame
    .s_axis_data_tuser({2'd0,1'd0,sof,12'd0,16'd0,{src_sid,next_dst_sid},64'd0}),
    // Unused
    .m_axis_config_tdata(),
    .m_axis_config_tlast(),
    .m_axis_config_tvalid(),
    .m_axis_config_tready(),
    .m_axis_pkt_len_tdata(),
    .m_axis_pkt_len_tvalid(),
    .m_axis_pkt_len_tready());
  
  ////////////////////////////////////////////////////////////
  //
  // User code
  //
  ////////////////////////////////////////////////////////////
  localparam [31:0] SR_NUM_SYMBOLS        = 129;
  localparam [31:0] SR_FORCE_NUM_SYMBOLS  = 130;
  localparam [31:0] SR_PASSTHRU           = 131;

  localparam [31:0] MAX_NUM_SYMBOLS = 200;

  // Settings Registers
  wire [$clog2(MAX_NUM_SYMBOLS+1)-1:0] num_symbols;
  wire num_symbols_valid;
  setting_reg #(
  .my_addr(SR_NUM_SYMBOLS), .awidth(8), .width($clog2(MAX_NUM_SYMBOLS+1)), .at_reset(MAX_NUM_SYMBOLS))
  sr_num_symbols (
    .clk(ce_clk), .rst(ce_rst),
    .strobe(set_stb), .addr(set_addr), .in(set_data), .out(num_symbols), .changed(num_symbols_valid));

  // Useful when the packet length is known and does not change.
  // Keeps num_symbols_valid always asserted so num_symbols is immediately loaded for every packet.
  wire force_num_symbols_valid;
  setting_reg #(
    .my_addr(SR_FORCE_NUM_SYMBOLS), .awidth(8), .width(1), .at_reset(0))
  sr_force_num_symbols (
    .clk(ce_clk), .rst(ce_rst),
    .strobe(set_stb), .addr(set_addr), .in(set_data), .out(force_num_symbols_valid), .changed());

  wire passthru;
  setting_reg #(
    .my_addr(SR_PASSTHRU), .awidth(8), .width(1), .at_reset(0))
  sr_passthru (
    .clk(ce_clk), .rst(ce_rst),
    .strobe(set_stb), .addr(set_addr), .in(set_data), .out(passthru), .changed());

  ofdm_sync #(
    .WINDOW_LEN(80),
    .SYMBOL_LEN(64),
    .CYCLIC_PREFIX_LEN(16),
    .PREAMBLE_LEN(160),
    .MAX_NUM_SYMBOLS(MAX_NUM_SYMBOLS))
  inst_ofdm_sync (
    .clk(ce_clk), .reset(ce_rst | clear_tx_seqnum),
    .passthru(passthru),
    .num_symbols(num_symbols), .num_symbols_valid(num_symbols_valid | force_num_symbols_valid),
    .i_tdata(m_axis_data_tdata), .i_tlast(m_axis_data_tlast), .i_tvalid(m_axis_data_tvalid), .i_tready(m_axis_data_tready),
    .o_tdata(s_axis_data_tdata), .o_tlast(s_axis_data_tlast), .o_tvalid(s_axis_data_tvalid), .o_tready(s_axis_data_tready),
    .o_sof(sof), .o_eof());

endmodule
