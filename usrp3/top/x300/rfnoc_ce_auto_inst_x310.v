  localparam NUM_CE = 11;  // Must be no more than 11 (5 ports taken by transport and IO connected CEs)

  wire [NUM_CE*64-1:0] ce_flat_o_tdata, ce_flat_i_tdata;
  wire [63:0]          ce_o_tdata[0:NUM_CE-1], ce_i_tdata[0:NUM_CE-1];
  wire [NUM_CE-1:0]    ce_o_tlast, ce_o_tvalid, ce_o_tready, ce_i_tlast, ce_i_tvalid, ce_i_tready;
  wire [63:0]          ce_debug[0:NUM_CE-1];

  // Flatten CE tdata arrays
  genvar k;
  generate
    for (k = 0; k < NUM_CE; k = k + 1) begin
      assign ce_o_tdata[k] = ce_flat_o_tdata[k*64+63:k*64];
      assign ce_flat_i_tdata[k*64+63:k*64] = ce_i_tdata[k];
    end
  endgenerate

  noc_block_axi_dma_fifo #(
    .NUM_FIFOS(2),
    .DEFAULT_FIFO_BASE({30'h02000000, 30'h00000000}),
    .DEFAULT_FIFO_SIZE({30'h01FFFFFF, 30'h01FFFFFF}),
    .STR_SINK_FIFOSIZE(14),
    .DEFAULT_BURST_TIMEOUT({12'd280, 12'd280}),
    .EXTENDED_DRAM_BIST(1),
    .BUS_CLK_RATE(BUS_CLK_RATE))
  inst_noc_block_dram_fifo (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ddr3_axi_clk_x2), .ce_rst(ddr3_axi_rst),
    //AXIS
    .i_tdata(ce_o_tdata[0]), .i_tlast(ce_o_tlast[0]), .i_tvalid(ce_o_tvalid[0]), .i_tready(ce_o_tready[0]),
    .o_tdata(ce_i_tdata[0]), .o_tlast(ce_i_tlast[0]), .o_tvalid(ce_i_tvalid[0]), .o_tready(ce_i_tready[0]),
    //AXI
    .m_axi_awid({s01_axi_awid, s00_axi_awid}),
    .m_axi_awaddr({s01_axi_awaddr, s00_axi_awaddr}),
    .m_axi_awlen({s01_axi_awlen, s00_axi_awlen}),
    .m_axi_awsize({s01_axi_awsize, s00_axi_awsize}),
    .m_axi_awburst({s01_axi_awburst, s00_axi_awburst}),
    .m_axi_awlock({s01_axi_awlock, s00_axi_awlock}),
    .m_axi_awcache({s01_axi_awcache, s00_axi_awcache}),
    .m_axi_awprot({s01_axi_awprot, s00_axi_awprot}),
    .m_axi_awqos({s01_axi_awqos, s00_axi_awqos}),
    .m_axi_awregion({s01_axi_awregion, s00_axi_awregion}),
    .m_axi_awuser({s01_axi_awuser, s00_axi_awuser}),
    .m_axi_awvalid({s01_axi_awvalid, s00_axi_awvalid}),
    .m_axi_awready({s01_axi_awready, s00_axi_awready}),
    .m_axi_wdata({s01_axi_wdata, s00_axi_wdata}),
    .m_axi_wstrb({s01_axi_wstrb, s00_axi_wstrb}),
    .m_axi_wlast({s01_axi_wlast, s00_axi_wlast}),
    .m_axi_wuser({s01_axi_wuser, s00_axi_wuser}),
    .m_axi_wvalid({s01_axi_wvalid, s00_axi_wvalid}),
    .m_axi_wready({s01_axi_wready, s00_axi_wready}),
    .m_axi_bid({s01_axi_bid, s00_axi_bid}),
    .m_axi_bresp({s01_axi_bresp, s00_axi_bresp}),
    .m_axi_buser({s01_axi_buser, s00_axi_buser}),
    .m_axi_bvalid({s01_axi_bvalid, s00_axi_bvalid}),
    .m_axi_bready({s01_axi_bready, s00_axi_bready}),
    .m_axi_arid({s01_axi_arid, s00_axi_arid}),
    .m_axi_araddr({s01_axi_araddr, s00_axi_araddr}),
    .m_axi_arlen({s01_axi_arlen, s00_axi_arlen}),
    .m_axi_arsize({s01_axi_arsize, s00_axi_arsize}),
    .m_axi_arburst({s01_axi_arburst, s00_axi_arburst}),
    .m_axi_arlock({s01_axi_arlock, s00_axi_arlock}),
    .m_axi_arcache({s01_axi_arcache, s00_axi_arcache}),
    .m_axi_arprot({s01_axi_arprot, s00_axi_arprot}),
    .m_axi_arqos({s01_axi_arqos, s00_axi_arqos}),
    .m_axi_arregion({s01_axi_arregion, s00_axi_arregion}),
    .m_axi_aruser({s01_axi_aruser, s00_axi_aruser}),
    .m_axi_arvalid({s01_axi_arvalid, s00_axi_arvalid}),
    .m_axi_arready({s01_axi_arready, s00_axi_arready}),
    .m_axi_rid({s01_axi_rid, s00_axi_rid}),
    .m_axi_rdata({s01_axi_rdata, s00_axi_rdata}),
    .m_axi_rresp({s01_axi_rresp, s00_axi_rresp}),
    .m_axi_rlast({s01_axi_rlast, s00_axi_rlast}),
    .m_axi_ruser({s01_axi_ruser, s00_axi_ruser}),
    .m_axi_rvalid({s01_axi_rvalid, s00_axi_rvalid}),
    .m_axi_rready({s01_axi_rready, s00_axi_rready}),
    .debug());

  noc_block_ddc #(.NOC_ID(64'hDDC0_0000_0000_0001), .NUM_CHAINS(1)) inst_noc_block_ddc (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[1]), .i_tlast(ce_o_tlast[1]), .i_tvalid(ce_o_tvalid[1]), .i_tready(ce_o_tready[1]),
    .o_tdata(ce_i_tdata[1]), .o_tlast(ce_i_tlast[1]), .o_tvalid(ce_i_tvalid[1]), .o_tready(ce_i_tready[1]),
    .debug(ce_debug[1]));

  noc_block_duc inst_noc_block_duc (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[2]), .i_tlast(ce_o_tlast[2]), .i_tvalid(ce_o_tvalid[2]), .i_tready(ce_o_tready[2]),
    .o_tdata(ce_i_tdata[2]), .o_tlast(ce_i_tlast[2]), .o_tvalid(ce_i_tvalid[2]), .o_tready(ce_i_tready[2]),
    .debug(ce_debug[2]));

  noc_block_fft inst_noc_block_fft (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[3]), .i_tlast(ce_o_tlast[3]), .i_tvalid(ce_o_tvalid[3]), .i_tready(ce_o_tready[3]),
    .o_tdata(ce_i_tdata[3]), .o_tlast(ce_i_tlast[3]), .o_tvalid(ce_i_tvalid[3]), .o_tready(ce_i_tready[3]),
    .debug(ce_debug[3]));

  noc_block_window inst_noc_block_window (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[4]), .i_tlast(ce_o_tlast[4]), .i_tvalid(ce_o_tvalid[4]), .i_tready(ce_o_tready[4]),
    .o_tdata(ce_i_tdata[4]), .o_tlast(ce_i_tlast[4]), .o_tvalid(ce_i_tvalid[4]), .o_tready(ce_i_tready[4]),
    .debug(ce_debug[4]));

  noc_block_fir_filter inst_noc_block_fir_filter (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[5]), .i_tlast(ce_o_tlast[5]), .i_tvalid(ce_o_tvalid[5]), .i_tready(ce_o_tready[5]),
    .o_tdata(ce_i_tdata[5]), .o_tlast(ce_i_tlast[5]), .o_tvalid(ce_i_tvalid[5]), .o_tready(ce_i_tready[5]),
    .debug(ce_debug[5]));

  noc_block_siggen inst_noc_block_siggen (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[6]), .i_tlast(ce_o_tlast[6]), .i_tvalid(ce_o_tvalid[6]), .i_tready(ce_o_tready[6]),
    .o_tdata(ce_i_tdata[6]), .o_tlast(ce_i_tlast[6]), .o_tvalid(ce_i_tvalid[6]), .o_tready(ce_i_tready[6]),
    .debug(ce_debug[6]));

  noc_block_keep_one_in_n inst_noc_block_keep_one_in_n (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[7]), .i_tlast(ce_o_tlast[7]), .i_tvalid(ce_o_tvalid[7]), .i_tready(ce_o_tready[7]),
    .o_tdata(ce_i_tdata[7]), .o_tlast(ce_i_tlast[7]), .o_tvalid(ce_i_tvalid[7]), .o_tready(ce_i_tready[7]),
    .debug(ce_debug[7]));

  noc_block_fosphor inst_noc_block_fosphor (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[8]), .i_tlast(ce_o_tlast[8]), .i_tvalid(ce_o_tvalid[8]), .i_tready(ce_o_tready[8]),
    .o_tdata(ce_i_tdata[8]), .o_tlast(ce_i_tlast[8]), .o_tvalid(ce_i_tvalid[8]), .o_tready(ce_i_tready[8]),
    .debug(ce_debug[8]));

  // Fill remaining crossbar ports with loopback FIFOs
  genvar n;
  generate
    for (n = 9; n < NUM_CE; n = n + 1) begin
      noc_block_axi_fifo_loopback inst_noc_block_axi_fifo_loopback (
        .bus_clk(bus_clk), .bus_rst(bus_rst),
        .ce_clk(ce_clk), .ce_rst(ce_rst),
        .i_tdata(ce_o_tdata[n]), .i_tlast(ce_o_tlast[n]), .i_tvalid(ce_o_tvalid[n]), .i_tready(ce_o_tready[n]),
        .o_tdata(ce_i_tdata[n]), .o_tlast(ce_i_tlast[n]), .o_tvalid(ce_i_tvalid[n]), .o_tready(ce_i_tready[n]),
        .debug(ce_debug[n]));
    end
  endgenerate
