  localparam FP_GPIO_FORCE_FAB_CTRL = 0;
  localparam NUM_CE = 5;  // Must be no more than 11 (5 ports taken by transport and IO connected CEs)

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

  /////////////////////////////////////////////////////////////////////////////////////////////
  //
  // DRAM FIFO
  //
  /////////////////////////////////////////////////////////////////////////////////////////////

  // AXI4 MM buses
  wire        s00_axi_awready, s01_axi_awready;
  wire [0:0]  s00_axi_awid, s01_axi_awid;
  wire [31:0] s00_axi_awaddr, s01_axi_awaddr;
  wire [7:0]  s00_axi_awlen, s01_axi_awlen;
  wire [2:0]  s00_axi_awsize, s01_axi_awsize;
  wire [1:0]  s00_axi_awburst, s01_axi_awburst;
  wire [0:0]  s00_axi_awlock, s01_axi_awlock;
  wire [3:0]  s00_axi_awcache, s01_axi_awcache;
  wire [2:0]  s00_axi_awprot, s01_axi_awprot;
  wire [3:0]  s00_axi_awqos, s01_axi_awqos;
  wire [3:0]  s00_axi_awregion, s01_axi_awregion;
  wire [0:0]  s00_axi_awuser, s01_axi_awuser;
  wire        s00_axi_wready, s01_axi_wready;
  wire [63:0] s00_axi_wdata, s01_axi_wdata;
  wire [7:0]  s00_axi_wstrb, s01_axi_wstrb;
  wire [0:0]  s00_axi_wuser, s01_axi_wuser;
  wire        s00_axi_bvalid, s01_axi_bvalid;
  wire [0:0]  s00_axi_bid, s01_axi_bid;
  wire [1:0]  s00_axi_bresp, s01_axi_bresp;
  wire [0:0]  s00_axi_buser, s01_axi_buser;
  wire        s00_axi_arready, s01_axi_arready;
  wire [0:0]  s00_axi_arid, s01_axi_arid;
  wire [31:0] s00_axi_araddr, s01_axi_araddr;
  wire [7:0]  s00_axi_arlen, s01_axi_arlen;
  wire [2:0]  s00_axi_arsize, s01_axi_arsize;
  wire [1:0]  s00_axi_arburst, s01_axi_arburst;
  wire [0:0]  s00_axi_arlock, s01_axi_arlock;
  wire [3:0]  s00_axi_arcache, s01_axi_arcache;
  wire [2:0]  s00_axi_arprot, s01_axi_arprot;
  wire [3:0]  s00_axi_arqos, s01_axi_arqos;
  wire [3:0]  s00_axi_arregion, s01_axi_arregion;
  wire [0:0]  s00_axi_aruser, s01_axi_aruser;
  wire        s00_axi_rlast, s01_axi_rlast;
  wire        s00_axi_rvalid, s01_axi_rvalid;
  wire        s00_axi_awvalid, s01_axi_awvalid;
  wire        s00_axi_wlast, s01_axi_wlast;
  wire        s00_axi_wvalid, s01_axi_wvalid;
  wire        s00_axi_bready, s01_axi_bready;
  wire        s00_axi_arvalid, s01_axi_arvalid;
  wire        s00_axi_rready, s01_axi_rready;
  wire [0:0]  s00_axi_rid, s01_axi_rid;
  wire [63:0] s00_axi_rdata, s01_axi_rdata;
  wire [1:0]  s00_axi_rresp, s01_axi_rresp;
  wire [0:0]  s00_axi_ruser, s01_axi_ruser;

  axi_intercon_2x64_128_bd_wrapper axi_intercon_2x64_128_bd_i (
    .S00_AXI_ACLK(ddr3_axi_clk_x2), // input S00_AXI_ACLK
    .S00_AXI_ARESETN(~ddr3_axi_rst), // input S00_AXI_ARESETN
    .S00_AXI_AWID(s00_axi_awid), // input [0 : 0] S00_AXI_AWID
    .S00_AXI_AWADDR(s00_axi_awaddr), // input [31 : 0] S00_AXI_AWADDR
    .S00_AXI_AWLEN(s00_axi_awlen), // input [7 : 0] S00_AXI_AWLEN
    .S00_AXI_AWSIZE(s00_axi_awsize), // input [2 : 0] S00_AXI_AWSIZE
    .S00_AXI_AWBURST(s00_axi_awburst), // input [1 : 0] S00_AXI_AWBURST
    .S00_AXI_AWLOCK(s00_axi_awlock), // input S00_AXI_AWLOCK
    .S00_AXI_AWCACHE(s00_axi_awcache), // input [3 : 0] S00_AXI_AWCACHE
    .S00_AXI_AWPROT(s00_axi_awprot), // input [2 : 0] S00_AXI_AWPROT
    .S00_AXI_AWQOS(s00_axi_awqos), // input [3 : 0] S00_AXI_AWQOS
    .S00_AXI_AWVALID(s00_axi_awvalid), // input S00_AXI_AWVALID
    .S00_AXI_AWREADY(s00_axi_awready), // output S00_AXI_AWREADY
    .S00_AXI_WDATA(s00_axi_wdata), // input [63 : 0] S00_AXI_WDATA
    .S00_AXI_WSTRB(s00_axi_wstrb), // input [7 : 0] S00_AXI_WSTRB
    .S00_AXI_WLAST(s00_axi_wlast), // input S00_AXI_WLAST
    .S00_AXI_WVALID(s00_axi_wvalid), // input S00_AXI_WVALID
    .S00_AXI_WREADY(s00_axi_wready), // output S00_AXI_WREADY
    .S00_AXI_BID(s00_axi_bid), // output [0 : 0] S00_AXI_BID
    .S00_AXI_BRESP(s00_axi_bresp), // output [1 : 0] S00_AXI_BRESP
    .S00_AXI_BVALID(s00_axi_bvalid), // output S00_AXI_BVALID
    .S00_AXI_BREADY(s00_axi_bready), // input S00_AXI_BREADY
    .S00_AXI_ARID(s00_axi_arid), // input [0 : 0] S00_AXI_ARID
    .S00_AXI_ARADDR(s00_axi_araddr), // input [31 : 0] S00_AXI_ARADDR
    .S00_AXI_ARLEN(s00_axi_arlen), // input [7 : 0] S00_AXI_ARLEN
    .S00_AXI_ARSIZE(s00_axi_arsize), // input [2 : 0] S00_AXI_ARSIZE
    .S00_AXI_ARBURST(s00_axi_arburst), // input [1 : 0] S00_AXI_ARBURST
    .S00_AXI_ARLOCK(s00_axi_arlock), // input S00_AXI_ARLOCK
    .S00_AXI_ARCACHE(s00_axi_arcache), // input [3 : 0] S00_AXI_ARCACHE
    .S00_AXI_ARPROT(s00_axi_arprot), // input [2 : 0] S00_AXI_ARPROT
    .S00_AXI_ARQOS(s00_axi_arqos), // input [3 : 0] S00_AXI_ARQOS
    .S00_AXI_ARVALID(s00_axi_arvalid), // input S00_AXI_ARVALID
    .S00_AXI_ARREADY(s00_axi_arready), // output S00_AXI_ARREADY
    .S00_AXI_RID(s00_axi_rid), // output [0 : 0] S00_AXI_RID
    .S00_AXI_RDATA(s00_axi_rdata), // output [63 : 0] S00_AXI_RDATA
    .S00_AXI_RRESP(s00_axi_rresp), // output [1 : 0] S00_AXI_RRESP
    .S00_AXI_RLAST(s00_axi_rlast), // output S00_AXI_RLAST
    .S00_AXI_RVALID(s00_axi_rvalid), // output S00_AXI_RVALID
    .S00_AXI_RREADY(s00_axi_rready), // input S00_AXI_RREADY
    //
    .S01_AXI_ACLK(ddr3_axi_clk_x2), // input S01_AXI_ACLK
    .S01_AXI_ARESETN(~ddr3_axi_rst), // input S00_AXI_ARESETN
    .S01_AXI_AWID(s01_axi_awid), // input [0 : 0] S01_AXI_AWID
    .S01_AXI_AWADDR(s01_axi_awaddr), // input [31 : 0] S01_AXI_AWADDR
    .S01_AXI_AWLEN(s01_axi_awlen), // input [7 : 0] S01_AXI_AWLEN
    .S01_AXI_AWSIZE(s01_axi_awsize), // input [2 : 0] S01_AXI_AWSIZE
    .S01_AXI_AWBURST(s01_axi_awburst), // input [1 : 0] S01_AXI_AWBURST
    .S01_AXI_AWLOCK(s01_axi_awlock), // input S01_AXI_AWLOCK
    .S01_AXI_AWCACHE(s01_axi_awcache), // input [3 : 0] S01_AXI_AWCACHE
    .S01_AXI_AWPROT(s01_axi_awprot), // input [2 : 0] S01_AXI_AWPROT
    .S01_AXI_AWQOS(s01_axi_awqos), // input [3 : 0] S01_AXI_AWQOS
    .S01_AXI_AWVALID(s01_axi_awvalid), // input S01_AXI_AWVALID
    .S01_AXI_AWREADY(s01_axi_awready), // output S01_AXI_AWREADY
    .S01_AXI_WDATA(s01_axi_wdata), // input [63 : 0] S01_AXI_WDATA
    .S01_AXI_WSTRB(s01_axi_wstrb), // input [7 : 0] S01_AXI_WSTRB
    .S01_AXI_WLAST(s01_axi_wlast), // input S01_AXI_WLAST
    .S01_AXI_WVALID(s01_axi_wvalid), // input S01_AXI_WVALID
    .S01_AXI_WREADY(s01_axi_wready), // output S01_AXI_WREADY
    .S01_AXI_BID(s01_axi_bid), // output [0 : 0] S01_AXI_BID
    .S01_AXI_BRESP(s01_axi_bresp), // output [1 : 0] S01_AXI_BRESP
    .S01_AXI_BVALID(s01_axi_bvalid), // output S01_AXI_BVALID
    .S01_AXI_BREADY(s01_axi_bready), // input S01_AXI_BREADY
    .S01_AXI_ARID(s01_axi_arid), // input [0 : 0] S01_AXI_ARID
    .S01_AXI_ARADDR(s01_axi_araddr), // input [31 : 0] S01_AXI_ARADDR
    .S01_AXI_ARLEN(s01_axi_arlen), // input [7 : 0] S01_AXI_ARLEN
    .S01_AXI_ARSIZE(s01_axi_arsize), // input [2 : 0] S01_AXI_ARSIZE
    .S01_AXI_ARBURST(s01_axi_arburst), // input [1 : 0] S01_AXI_ARBURST
    .S01_AXI_ARLOCK(s01_axi_arlock), // input S01_AXI_ARLOCK
    .S01_AXI_ARCACHE(s01_axi_arcache), // input [3 : 0] S01_AXI_ARCACHE
    .S01_AXI_ARPROT(s01_axi_arprot), // input [2 : 0] S01_AXI_ARPROT
    .S01_AXI_ARQOS(s01_axi_arqos), // input [3 : 0] S01_AXI_ARQOS
    .S01_AXI_ARVALID(s01_axi_arvalid), // input S01_AXI_ARVALID
    .S01_AXI_ARREADY(s01_axi_arready), // output S01_AXI_ARREADY
    .S01_AXI_RID(s01_axi_rid), // output [0 : 0] S01_AXI_RID
    .S01_AXI_RDATA(s01_axi_rdata), // output [63 : 0] S01_AXI_RDATA
    .S01_AXI_RRESP(s01_axi_rresp), // output [1 : 0] S01_AXI_RRESP
    .S01_AXI_RLAST(s01_axi_rlast), // output S01_AXI_RLAST
    .S01_AXI_RVALID(s01_axi_rvalid), // output S01_AXI_RVALID
    .S01_AXI_RREADY(s01_axi_rready), // input S01_AXI_RREADY
    //
    .M00_AXI_ACLK(ddr3_axi_clk), // input M00_AXI_ACLK
    .M00_AXI_ARESETN(~ddr3_axi_rst), // input S00_AXI_ARESETN
    .M00_AXI_AWID(ddr3_axi_awid), // output [3 : 0] M00_AXI_AWID
    .M00_AXI_AWADDR(ddr3_axi_awaddr), // output [31 : 0] M00_AXI_AWADDR
    .M00_AXI_AWLEN(ddr3_axi_awlen), // output [7 : 0] M00_AXI_AWLEN
    .M00_AXI_AWSIZE(ddr3_axi_awsize), // output [2 : 0] M00_AXI_AWSIZE
    .M00_AXI_AWBURST(ddr3_axi_awburst), // output [1 : 0] M00_AXI_AWBURST
    .M00_AXI_AWLOCK(ddr3_axi_awlock), // output M00_AXI_AWLOCK
    .M00_AXI_AWCACHE(ddr3_axi_awcache), // output [3 : 0] M00_AXI_AWCACHE
    .M00_AXI_AWPROT(ddr3_axi_awprot), // output [2 : 0] M00_AXI_AWPROT
    .M00_AXI_AWQOS(ddr3_axi_awqos), // output [3 : 0] M00_AXI_AWQOS
    .M00_AXI_AWVALID(ddr3_axi_awvalid), // output M00_AXI_AWVALID
    .M00_AXI_AWREADY(ddr3_axi_awready), // input M00_AXI_AWREADY
    .M00_AXI_WDATA(ddr3_axi_wdata), // output [127 : 0] M00_AXI_WDATA
    .M00_AXI_WSTRB(ddr3_axi_wstrb), // output [15 : 0] M00_AXI_WSTRB
    .M00_AXI_WLAST(ddr3_axi_wlast), // output M00_AXI_WLAST
    .M00_AXI_WVALID(ddr3_axi_wvalid), // output M00_AXI_WVALID
    .M00_AXI_WREADY(ddr3_axi_wready), // input M00_AXI_WREADY
    .M00_AXI_BID(ddr3_axi_bid), // input [3 : 0] M00_AXI_BID
    .M00_AXI_BRESP(ddr3_axi_bresp), // input [1 : 0] M00_AXI_BRESP
    .M00_AXI_BVALID(ddr3_axi_bvalid), // input M00_AXI_BVALID
    .M00_AXI_BREADY(ddr3_axi_bready), // output M00_AXI_BREADY
    .M00_AXI_ARID(ddr3_axi_arid), // output [3 : 0] M00_AXI_ARID
    .M00_AXI_ARADDR(ddr3_axi_araddr), // output [31 : 0] M00_AXI_ARADDR
    .M00_AXI_ARLEN(ddr3_axi_arlen), // output [7 : 0] M00_AXI_ARLEN
    .M00_AXI_ARSIZE(ddr3_axi_arsize), // output [2 : 0] M00_AXI_ARSIZE
    .M00_AXI_ARBURST(ddr3_axi_arburst), // output [1 : 0] M00_AXI_ARBURST
    .M00_AXI_ARLOCK(ddr3_axi_arlock), // output M00_AXI_ARLOCK
    .M00_AXI_ARCACHE(ddr3_axi_arcache), // output [3 : 0] M00_AXI_ARCACHE
    .M00_AXI_ARPROT(ddr3_axi_arprot), // output [2 : 0] M00_AXI_ARPROT
    .M00_AXI_ARQOS(ddr3_axi_arqos), // output [3 : 0] M00_AXI_ARQOS
    .M00_AXI_ARVALID(ddr3_axi_arvalid), // output M00_AXI_ARVALID
    .M00_AXI_ARREADY(ddr3_axi_arready), // input M00_AXI_ARREADY
    .M00_AXI_RID(ddr3_axi_rid), // input [3 : 0] M00_AXI_RID
    .M00_AXI_RDATA(ddr3_axi_rdata), // input [127 : 0] M00_AXI_RDATA
    .M00_AXI_RRESP(ddr3_axi_rresp), // input [1 : 0] M00_AXI_RRESP
    .M00_AXI_RLAST(ddr3_axi_rlast), // input M00_AXI_RLAST
    .M00_AXI_RVALID(ddr3_axi_rvalid), // input M00_AXI_RVALID
    .M00_AXI_RREADY(ddr3_axi_rready) // output M00_AXI_RREADY
  );

  /////////////////////////////////////////////////////////////////////////////////////////////
  //
  // RFNoC Blocks
  //
  /////////////////////////////////////////////////////////////////////////////////////////////

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

  noc_block_ddc #( .NUM_CHAINS(2), .NUM_HB(3), .CIC_MAX_DECIM(255)) inst_noc_block_ddc_0 (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[1]), .i_tlast(ce_o_tlast[1]), .i_tvalid(ce_o_tvalid[1]), .i_tready(ce_o_tready[1]),
    .o_tdata(ce_i_tdata[1]), .o_tlast(ce_i_tlast[1]), .o_tvalid(ce_i_tvalid[1]), .o_tready(ce_i_tready[1]),
    .debug(ce_debug[1]));

  noc_block_ddc #( .NUM_CHAINS(2), .NUM_HB(3), .CIC_MAX_DECIM(255)) inst_noc_block_ddc_1 (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[2]), .i_tlast(ce_o_tlast[2]), .i_tvalid(ce_o_tvalid[2]), .i_tready(ce_o_tready[2]),
    .o_tdata(ce_i_tdata[2]), .o_tlast(ce_i_tlast[2]), .o_tvalid(ce_i_tvalid[2]), .o_tready(ce_i_tready[2]),
    .debug(ce_debug[2]));

  noc_block_duc #( .NUM_HB(2), .CIC_MAX_INTERP(128)) inst_noc_block_duc_0 (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[3]), .i_tlast(ce_o_tlast[3]), .i_tvalid(ce_o_tvalid[3]), .i_tready(ce_o_tready[3]),
    .o_tdata(ce_i_tdata[3]), .o_tlast(ce_i_tlast[3]), .o_tvalid(ce_i_tvalid[3]), .o_tready(ce_i_tready[3]),
    .debug(ce_debug[3]));

  noc_block_duc #( .NUM_HB(2), .CIC_MAX_INTERP(128)) inst_noc_block_duc_1 (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(ce_clk), .ce_rst(ce_rst),
    .i_tdata(ce_o_tdata[4]), .i_tlast(ce_o_tlast[4]), .i_tvalid(ce_o_tvalid[4]]), .i_tready(ce_o_tready[4]),
    .o_tdata(ce_i_tdata[4]), .o_tlast(ce_i_tlast[4]), .o_tvalid(ce_i_tvalid[4]]), .o_tready(ce_i_tready[4]),
    .debug(ce_debug[4]));

  // Fill remaining crossbar ports with loopback FIFOs
  genvar n;
  generate
    for (n = 5; n < NUM_CE; n = n + 1) begin
      noc_block_axi_fifo_loopback inst_noc_block_axi_fifo_loopback (
        .bus_clk(bus_clk), .bus_rst(bus_rst),
        .ce_clk(ce_clk), .ce_rst(ce_rst),
        .i_tdata(ce_o_tdata[n]), .i_tlast(ce_o_tlast[n]), .i_tvalid(ce_o_tvalid[n]), .i_tready(ce_o_tready[n]),
        .o_tdata(ce_i_tdata[n]), .o_tlast(ce_i_tlast[n]), .o_tvalid(ce_i_tvalid[n]), .o_tready(ce_i_tready[n]),
        .debug(ce_debug[n]));
    end
  endgenerate
