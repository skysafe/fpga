//
// Copyright 2014 Ettus Research LLC
// Copyright 2017 Ettus Research, a National Instruments Company
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//

module x300_core #(
   parameter BUS_CLK_RATE = 32'd166666666
)(
   //Clocks and resets
   input radio_clk,
   input radio_rst,
   input bus_clk,
   input bus_rst,
   input ce_clk,
   input ce_rst,
   output [3:0] sw_rst,
   input bus_clk_div2,
   input bus_rst_div2,
   // Radio 0
   input [31:0] rx0, output [31:0] tx0,
   input [31:0] db0_gpio_in, output [31:0] db0_gpio_out, output [31:0] db0_gpio_ddr,
   input [31:0] fp_gpio_in, output [31:0] fp_gpio_out, output [31:0] fp_gpio_ddr,
   output [7:0] sen0, output sclk0, output mosi0, input miso0,
   output [2:0] radio_led0,
   output reg [31:0] radio0_misc_out, input [31:0] radio0_misc_in,
   // Radio 1
   input [31:0] rx1, output [31:0] tx1,
   input [31:0] db1_gpio_in, output [31:0] db1_gpio_out, output [31:0] db1_gpio_ddr,
   output [7:0] sen1, output sclk1, output mosi1, input miso1,
   output [2:0] radio_led1,
   output reg [31:0] radio1_misc_out, input [31:0] radio1_misc_in,
   // Radio shared misc
   inout db_scl,
   inout db_sda,
   // Clock control
   input ext_ref_clk,
   output [1:0] clock_ref_sel,
   output [1:0] clock_misc_opt,
   input [1:0] LMK_Status,
   input LMK_Holdover, input LMK_Lock, output LMK_Sync,
   output LMK_SEN, output LMK_SCLK, output LMK_MOSI,
   input [2:0] misc_clock_status,
   // SFP+ pins
   inout SFPP0_SCL,
   inout SFPP0_SDA,
   inout SFPP0_RS0,
   inout SFPP0_RS1,
   input SFPP0_ModAbs,
   input SFPP0_TxFault,
   input SFPP0_RxLOS,
   output SFPP0_TxDisable,   // Assert low to enable transmitter.

   inout SFPP1_SCL,
   inout SFPP1_SDA,
   inout SFPP1_RS0,
   inout SFPP1_RS1,
   input SFPP1_ModAbs,
   input SFPP1_TxFault,
   input SFPP1_RxLOS,
   output SFPP1_TxDisable,   // Assert low to enable transmitter.

   // SFP+ 0 data stream
   output [63:0] sfp0_tx_tdata,
   output [3:0] sfp0_tx_tuser,
   output sfp0_tx_tlast,
   output sfp0_tx_tvalid,
   input sfp0_tx_tready,

   input [63:0] sfp0_rx_tdata,
   input [3:0] sfp0_rx_tuser,
   input sfp0_rx_tlast,
   input sfp0_rx_tvalid,
   output sfp0_rx_tready,

   input [15:0] sfp0_phy_status,

   // SFP+ 1 data stream
   output [63:0] sfp1_tx_tdata,
   output [3:0] sfp1_tx_tuser,
   output sfp1_tx_tlast,
   output sfp1_tx_tvalid,
   input sfp1_tx_tready,

   input [63:0] sfp1_rx_tdata,
   input [3:0] sfp1_rx_tuser,
   input sfp1_rx_tlast,
   input sfp1_rx_tvalid,
   output sfp1_rx_tready,

   input [15:0] sfp1_phy_status,

   input [31:0] sfp0_wb_dat_i,
   output [31:0] sfp0_wb_dat_o,
   output [15:0] sfp0_wb_adr,
   output [3:0] sfp0_wb_sel,
   input sfp0_wb_ack,
   output sfp0_wb_stb,
   output sfp0_wb_cyc,
   output sfp0_wb_we,
   input sfp0_wb_int,  // IJB. Nothing to connect this too!! No IRQ controller on x300.

   input [31:0] sfp1_wb_dat_i,
   output [31:0] sfp1_wb_dat_o,
   output [15:0] sfp1_wb_adr,
   output [3:0] sfp1_wb_sel,
   input sfp1_wb_ack,
   output sfp1_wb_stb,
   output sfp1_wb_cyc,
   output sfp1_wb_we,
   input sfp1_wb_int,  // IJB. Nothing to connect this too!! No IRQ controller on x300.

   input [31:0] xadc_readback,

   // Time
   input pps,
   output [1:0] pps_select,
   output pps_out_enb,
   output [31:0] ref_freq,
   output ref_freq_changed,
   output gps_txd,
   input gps_rxd,
   // Debug UART
   input debug_rxd,
   output debug_txd,

   //
   // AXI4 (128b@250MHz) interface to DDR3 controller
   //
   input           ddr3_axi_clk,
   input           ddr3_axi_clk_x2,
   input           ddr3_axi_rst,
   input           ddr3_running,
   // Write Address Ports
   output          ddr3_axi_awid,
   output  [31:0]  ddr3_axi_awaddr,
   output  [7:0]   ddr3_axi_awlen,
   output  [2:0]   ddr3_axi_awsize,
   output  [1:0]   ddr3_axi_awburst,
   output  [0:0]   ddr3_axi_awlock,
   output  [3:0]   ddr3_axi_awcache,
   output  [2:0]   ddr3_axi_awprot,
   output  [3:0]   ddr3_axi_awqos,
   output          ddr3_axi_awvalid,
   input           ddr3_axi_awready,
   // Write Data Ports
   output  [255:0] ddr3_axi_wdata,
   output  [31:0]  ddr3_axi_wstrb,
   output          ddr3_axi_wlast,
   output          ddr3_axi_wvalid,
   input           ddr3_axi_wready,
   // Write Response Ports
   output          ddr3_axi_bready,
   input           ddr3_axi_bid,
   input [1:0]     ddr3_axi_bresp,
   input           ddr3_axi_bvalid,
   // Read Address Ports
   output          ddr3_axi_arid,
   output  [31:0]  ddr3_axi_araddr,
   output  [7:0]   ddr3_axi_arlen,
   output  [2:0]   ddr3_axi_arsize,
   output  [1:0]   ddr3_axi_arburst,
   output  [0:0]   ddr3_axi_arlock,
   output  [3:0]   ddr3_axi_arcache,
   output  [2:0]   ddr3_axi_arprot,
   output  [3:0]   ddr3_axi_arqos,
   output          ddr3_axi_arvalid,
   input           ddr3_axi_arready,
   // Read Data Ports
   output          ddr3_axi_rready,
   input           ddr3_axi_rid,
   input [255:0]   ddr3_axi_rdata,
   input [1:0]     ddr3_axi_rresp,
   input           ddr3_axi_rlast,
   input           ddr3_axi_rvalid,

   //iop2 message fifos
   output [63:0] o_iop2_msg_tdata,
   output o_iop2_msg_tvalid,
   output o_iop2_msg_tlast,
   input o_iop2_msg_tready,
   input [63:0] i_iop2_msg_tdata,
   input i_iop2_msg_tvalid,
   input i_iop2_msg_tlast,
   output i_iop2_msg_tready,

   //PCIe
   output [63:0] pcio_tdata,
   output pcio_tlast,
   output pcio_tvalid,
   input pcio_tready,
   input [63:0] pcii_tdata,
   input pcii_tlast,
   input pcii_tvalid,
   output pcii_tready,

   // Debug
   output [1:0] led_misc,
   output [31:0] debug0,
   output [31:0] debug1,
   output [127:0] debug2
);

   localparam DRAM_FIFO_INPUT_BUFF_SIZE = 14;

   // Computation engines that need access to IO
   localparam NUM_IO_CE = 2;

   wire [NUM_IO_CE*64-1:0] ioce_flat_o_tdata, ioce_flat_i_tdata;
   wire [63:0]             ioce_o_tdata[0:NUM_IO_CE-1], ioce_i_tdata[0:NUM_IO_CE-1];
   wire [NUM_IO_CE-1:0]    ioce_o_tlast, ioce_o_tvalid, ioce_o_tready, ioce_i_tlast, ioce_i_tvalid, ioce_i_tready;

   genvar ioce_i;
   generate for (ioce_i = 0; ioce_i < NUM_IO_CE; ioce_i = ioce_i + 1) begin
      assign ioce_o_tdata[ioce_i] = ioce_flat_o_tdata[ioce_i*64+63:ioce_i*64];
      assign ioce_flat_i_tdata[ioce_i*64+63:ioce_i*64] = ioce_i_tdata[ioce_i];
   end endgenerate

   // Number of Radio Cores Instantiated
   localparam NUM_RADIO_CORES = 2;

   //////////////////////////////////////////////////////////////////////////////////////////////
   // RFNoC
   //////////////////////////////////////////////////////////////////////////////////////////////
   localparam CHDR_WIDTH = 64;

   // FPGPIO for use by rfnoc blocks
   wire [31:0] fp_gpio_fab, fp_gpio_rb;

   // Included automatically instantiated CEs sources file created by RFNoC mod tool
`ifdef RFNOC
 `ifdef X300
   `include "rfnoc_ce_auto_inst_x300.v"
 `endif
 `ifdef X310
   `include "rfnoc_ce_auto_inst_x310.v"
 `endif
`else
 `ifdef X300
   `include "rfnoc_ce_default_inst_x300.v"
 `endif
 `ifdef X310
   `include "rfnoc_ce_default_inst_x310.v"
 `endif
`endif

   /////////////////////////////////////////////////////////////////////////////////
   // Internal time synchronization
   /////////////////////////////////////////////////////////////////////////////////
   wire time_sync, time_sync_r;
    synchronizer time_sync_synchronizer
     (.clk(radio_clk), .rst(radio_rst), .in(time_sync), .out(time_sync_r));

   /////////////////////////////////////////////////////////////////////////////////
   // PPS synchronization logic
   /////////////////////////////////////////////////////////////////////////////////
   wire pps_rclk, pps_detect;
   pps_synchronizer pps_sync_inst (
      .ref_clk(ext_ref_clk), .timebase_clk(radio_clk),
      .pps_in(pps), .pps_out(pps_rclk), .pps_count(pps_detect)
   );

   /////////////////////////////////////////////////////////////////////////////////
   // Bus Int containing soft CPU control, routing fabric
   /////////////////////////////////////////////////////////////////////////////////
   bus_int #(.NUM_CE(NUM_CE + NUM_IO_CE)) bus_int_i (
      .clk(bus_clk), .clk_div2(bus_clk_div2), .reset(bus_rst), .reset_div2(bus_rst_div2),
      .sen(LMK_SEN), .sclk(LMK_SCLK), .mosi(LMK_MOSI), .miso(1'b0),
      .scl0(SFPP0_SCL), .sda0(SFPP0_SDA),
      .scl1(db_scl), .sda1(db_sda),
      .scl2(SFPP1_SCL), .sda2(SFPP1_SDA),
      .gps_txd(gps_txd), .gps_rxd(gps_rxd),
      .debug_txd(debug_txd), .debug_rxd(debug_rxd),
      .leds(led_misc), .sw_rst(sw_rst),
      // SFP 0
      .SFPP0_ModAbs(SFPP0_ModAbs),.SFPP0_TxFault(SFPP0_TxFault),.SFPP0_RxLOS(SFPP0_RxLOS),
      .SFPP0_RS0(SFPP0_RS0), .SFPP0_RS1(SFPP0_RS1),
      // SFP 1
      .SFPP1_ModAbs(SFPP1_ModAbs),.SFPP1_TxFault(SFPP1_TxFault),.SFPP1_RxLOS(SFPP1_RxLOS),
      .SFPP1_RS0(SFPP1_RS0), .SFPP1_RS1(SFPP1_RS1),
      //clocky locky misc
      .clock_status({misc_clock_status, pps_detect, LMK_Holdover, LMK_Lock, LMK_Status}),
      .clock_control({time_sync, clock_misc_opt[1:0], pps_out_enb, pps_select[1:0], clock_ref_sel[1:0]}),
      .ref_freq(ref_freq), .ref_freq_changed(ref_freq_changed),
      // Eth0
      .sfp0_tx_tdata(sfp0_tx_tdata), .sfp0_tx_tuser(sfp0_tx_tuser), .sfp0_tx_tlast(sfp0_tx_tlast),
      .sfp0_tx_tvalid(sfp0_tx_tvalid), .sfp0_tx_tready(sfp0_tx_tready),
      .sfp0_rx_tdata(sfp0_rx_tdata), .sfp0_rx_tuser(sfp0_rx_tuser), .sfp0_rx_tlast(sfp0_rx_tlast),
      .sfp0_rx_tvalid(sfp0_rx_tvalid), .sfp0_rx_tready(sfp0_rx_tready),
      // Eth1
      .sfp1_tx_tdata(sfp1_tx_tdata), .sfp1_tx_tuser(sfp1_tx_tuser), .sfp1_tx_tlast(sfp1_tx_tlast),
      .sfp1_tx_tvalid(sfp1_tx_tvalid), .sfp1_tx_tready(sfp1_tx_tready),
      .sfp1_rx_tdata(sfp1_rx_tdata), .sfp1_rx_tuser(sfp1_rx_tuser), .sfp1_rx_tlast(sfp1_rx_tlast),
      .sfp1_rx_tvalid(sfp1_rx_tvalid), .sfp1_rx_tready(sfp1_rx_tready),
      // Computation Engines
      .ce_o_tdata({ce_flat_o_tdata, ioce_flat_o_tdata}), .ce_o_tlast({ce_o_tlast, ioce_o_tlast}),
      .ce_o_tvalid({ce_o_tvalid, ioce_o_tvalid}), .ce_o_tready({ce_o_tready, ioce_o_tready}),
      .ce_i_tdata({ce_flat_i_tdata, ioce_flat_i_tdata}), .ce_i_tlast({ce_i_tlast, ioce_i_tlast}),
      .ce_i_tvalid({ce_i_tvalid, ioce_i_tvalid}), .ce_i_tready({ce_i_tready, ioce_i_tready}),
      // IoP2 Msgs
      .o_iop2_msg_tdata(o_iop2_msg_tdata), .o_iop2_msg_tvalid(o_iop2_msg_tvalid), .o_iop2_msg_tlast(o_iop2_msg_tlast), .o_iop2_msg_tready(o_iop2_msg_tready),
      .i_iop2_msg_tdata(i_iop2_msg_tdata), .i_iop2_msg_tvalid(i_iop2_msg_tvalid), .i_iop2_msg_tlast(i_iop2_msg_tlast), .i_iop2_msg_tready(i_iop2_msg_tready),
      // PCIe
      .pcio_tdata(pcio_tdata), .pcio_tlast(pcio_tlast), .pcio_tvalid(pcio_tvalid), .pcio_tready(pcio_tready),
      .pcii_tdata(pcii_tdata), .pcii_tlast(pcii_tlast), .pcii_tvalid(pcii_tvalid), .pcii_tready(pcii_tready),
      // Wishbone Slave Interface(s)
      .sfp0_wb_dat_i(sfp0_wb_dat_i), .sfp0_wb_dat_o(sfp0_wb_dat_o), .sfp0_wb_adr(sfp0_wb_adr),
      .sfp0_wb_sel(sfp0_wb_sel), .sfp0_wb_ack(sfp0_wb_ack), .sfp0_wb_stb(sfp0_wb_stb),
      .sfp0_wb_cyc(sfp0_wb_cyc), .sfp0_wb_we(sfp0_wb_we), .sfp0_wb_int(sfp0_wb_int),
      .sfp1_wb_dat_i(sfp1_wb_dat_i), .sfp1_wb_dat_o(sfp1_wb_dat_o), .sfp1_wb_adr(sfp1_wb_adr),
      .sfp1_wb_sel(sfp1_wb_sel), .sfp1_wb_ack(sfp1_wb_ack), .sfp1_wb_stb(sfp1_wb_stb),
      .sfp1_wb_cyc(sfp1_wb_cyc), .sfp1_wb_we(sfp1_wb_we), .sfp1_wb_int(sfp1_wb_int),
      //Status signals
      .sfp0_phy_status(sfp0_phy_status),
      .sfp1_phy_status(sfp1_phy_status),
      .xadc_readback(xadc_readback),

      // Debug
      .debug0(debug0), .debug1(debug1), .debug2(debug2)
   );

   /////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Radios
   //
   /////////////////////////////////////////////////////////////////////////////////////////////

   // We need enough input buffering for 4 MTU sized packets.
   // Regardless of the sample rate the radio consumes data at 200MS/s so we need a 
   // decent amount of buffering at the input. With 4k samples we have 20us.
   localparam RADIO_INPUT_BUFF_SIZE  = 8'd12;
   // The radio needs a larger output buffer compared to other blocks because it is a finite
   // rate producer i.e. the input is not backpressured. 
   // Here, we allocate enough room from 2 MTU sized packets. This buffer serves as a 
   // packet gate so we need room for an additional packet if the first one is held due to
   // contention on the crossbar. Any additional buffering will be largely a waste.
   localparam RADIO_OUTPUT_BUFF_SIZE = 8'd11;

   // Daughter board I/O
   wire [31:0] leds[0:3];
   wire [31:0] fp_gpio_r_in[0:3], fp_gpio_r_out[0:3], fp_gpio_r_ddr[0:3], fp_gpio_fab_arr[0:3], fp_gpio_rb_arr[0:3];
   wire [31:0] db_gpio_in[0:3], db_gpio_out[0:3], db_gpio_ddr[0:3];
   wire [31:0] misc_outs[0:3];
   reg  [31:0] misc_ins[0:3];
   wire [7:0]  sen[0:3];
   wire        sclk[0:3], mosi[0:3], miso[0:3];
   wire        rx_running[0:3], tx_running[0:3];

   // Data
   wire [31:0] rx_data_in[0:3], rx_data[0:3], tx_data[0:3], tx_data_out[0:3];
   wire        rx_stb[0:3], tx_stb[0:3];
   wire        db_fe_set_stb[0:3];
   wire [7:0]  db_fe_set_addr[0:3];
   wire [31:0] db_fe_set_data[0:3];
   wire        db_fe_rb_stb[0:3];
   wire [7:0]  db_fe_rb_addr[0:3];
   wire [64:0] db_fe_rb_data[0:3];

   wire [NUM_RADIO_CORES-1:0] sync_out;

   //------------------------------------
   // Radio 0,1 (XB Radio Port 0)
   //------------------------------------
   noc_block_radio_core #(
      .NOC_ID(64'h12AD_1000_0000_0001),
      .NUM_CHANNELS(2),
      .STR_SINK_FIFOSIZE({8'd0, RADIO_INPUT_BUFF_SIZE}),
      .MTU(RADIO_OUTPUT_BUFF_SIZE)
   ) noc_block_radio_core_i0 (
      //Clocks
      .bus_clk(bus_clk), .bus_rst(bus_rst),
      .ce_clk(radio_clk), .ce_rst(radio_rst),
      //AXIS data to/from crossbar
      .i_tdata(ioce_o_tdata[0]), .i_tlast(ioce_o_tlast[0]), .i_tvalid(ioce_o_tvalid[0]), .i_tready(ioce_o_tready[0]),
      .o_tdata(ioce_i_tdata[0]), .o_tlast(ioce_i_tlast[0]), .o_tvalid(ioce_i_tvalid[0]), .o_tready(ioce_i_tready[0]),
      // Data ports connected to radio front end
      .rx({rx_data[1],rx_data[0]}), .rx_stb({rx_stb[1],rx_stb[0]}),
      .tx({tx_data[1],tx_data[0]}), .tx_stb({tx_stb[1],tx_stb[0]}),
      // Timing and sync
      .pps(pps_rclk), .sync_in(time_sync_r), .sync_out(sync_out[0]),
      .rx_running({rx_running[1], rx_running[0]}), .tx_running({tx_running[1], tx_running[0]}), 
      // Ctrl ports connected to radio dboard and front end core
      .db_fe_set_stb({db_fe_set_stb[1],db_fe_set_stb[0]}),
      .db_fe_set_addr({db_fe_set_addr[1],db_fe_set_addr[0]}),
      .db_fe_set_data({db_fe_set_data[1],db_fe_set_data[0]}),
      .db_fe_rb_stb({db_fe_rb_stb[1],db_fe_rb_stb[0]}),
      .db_fe_rb_addr({db_fe_rb_addr[1],db_fe_rb_addr[0]}),
      .db_fe_rb_data({db_fe_rb_data[1],db_fe_rb_data[0]}),
      //Debug
      .debug()
   );

   //------------------------------------
   // Radio 2,3 (XB Radio Port 1)
   //------------------------------------
   noc_block_radio_core #(
      .NOC_ID(64'h12AD_1000_0000_0001),
      .NUM_CHANNELS(2),
      .STR_SINK_FIFOSIZE({8'd0, RADIO_INPUT_BUFF_SIZE}),
      .MTU(RADIO_OUTPUT_BUFF_SIZE)
   ) noc_block_radio_core_i1 (
      //Clocks
      .bus_clk(bus_clk), .bus_rst(bus_rst),
      .ce_clk(radio_clk), .ce_rst(radio_rst),
      //AXIS data to/from crossbar
      .i_tdata(ioce_o_tdata[1]), .i_tlast(ioce_o_tlast[1]), .i_tvalid(ioce_o_tvalid[1]), .i_tready(ioce_o_tready[1]),
      .o_tdata(ioce_i_tdata[1]), .o_tlast(ioce_i_tlast[1]), .o_tvalid(ioce_i_tvalid[1]), .o_tready(ioce_i_tready[1]),
      // Ports connected to radio front end
      .rx({rx_data[3],rx_data[2]}), .rx_stb({rx_stb[3],rx_stb[2]}),
      .tx({tx_data[3],tx_data[2]}), .tx_stb({tx_stb[3],tx_stb[2]}),
      // Timing and sync
      .pps(pps_rclk), .sync_in(time_sync_r), .sync_out(sync_out[1]),
      .rx_running({rx_running[3], rx_running[2]}), .tx_running({tx_running[3], tx_running[2]}), 
      // Ctrl ports connected to radio dboard and front end core
      .db_fe_set_stb({db_fe_set_stb[3],db_fe_set_stb[2]}),
      .db_fe_set_addr({db_fe_set_addr[3],db_fe_set_addr[2]}),
      .db_fe_set_data({db_fe_set_data[3],db_fe_set_data[2]}),
      .db_fe_rb_stb({db_fe_rb_stb[3],db_fe_rb_stb[2]}),
      .db_fe_rb_addr({db_fe_rb_addr[3],db_fe_rb_addr[2]}),
      .db_fe_rb_data({db_fe_rb_data[3],db_fe_rb_data[2]}),
      //Debug
      .debug()
   );

   //------------------------------------
   // Frontend Correction
   //------------------------------------

   genvar i;
   generate for (i=0; i<4; i=i+1) begin
      x300_db_fe_core #(
        .USE_SPI_CLK(0),
        .FP_GPIO_FORCE_FAB_CTRL(FP_GPIO_FORCE_FAB_CTRL))
      db_fe_core_i (
         .clk(radio_clk), .reset(radio_rst),
         .set_stb(db_fe_set_stb[i]), .set_addr(db_fe_set_addr[i]), .set_data(db_fe_set_data[i]),
         .rb_stb(db_fe_rb_stb[i]),  .rb_addr(db_fe_rb_addr[i]), .rb_data(db_fe_rb_data[i]),
         .time_sync(sync_out[i < 2 ? 0 : 1]),
         .tx_stb(tx_stb[i]), .tx_data_in(tx_data[i]), .tx_data_out(tx_data_out[i]), .tx_running(tx_running[i]), 
         .rx_stb(rx_stb[i]), .rx_data_in(rx_data_in[i]), .rx_data_out(rx_data[i]), .rx_running(rx_running[i]),
         .misc_ins(misc_ins[i]), .misc_outs(misc_outs[i]),
         .fp_gpio_in(fp_gpio_r_in[i]), .fp_gpio_out(fp_gpio_r_out[i]), .fp_gpio_ddr(fp_gpio_r_ddr[i]),
         .fp_gpio_fab(fp_gpio_fab_arr[i]), .fp_gpio_rb(fp_gpio_rb_arr[i]),
         .db_gpio_in(db_gpio_in[i]), .db_gpio_out(db_gpio_out[i]), .db_gpio_ddr(db_gpio_ddr[i]),
         .db_gpio_fab(), .db_gpio_rb(),
         .leds(leds[i]),
         .spi_clk(radio_clk), .spi_rst(radio_rst),
         .sen(sen[i]), .sclk(sclk[i]), .mosi(mosi[i]), .miso(miso[i])
      );
   end endgenerate

   //------------------------------------
   // Radio to ADC,DAC and IO Mapping
   //------------------------------------

   // Data
   assign {rx_data_in[1], rx_data_in[0]} = {rx0, rx0};
   assign {rx_data_in[3], rx_data_in[2]} = {rx1, rx1};

   assign tx0 = tx_data_out[0];   //tx_data_out[1] unused
   assign tx1 = tx_data_out[2];   //tx_data_out[3] unused
   assign tx_stb[0] = 1'b1;
   assign tx_stb[1] = 1'b0;
   assign tx_stb[2] = 1'b1;
   assign tx_stb[3] = 1'b0;

   //Daughter board GPIO
   assign {db_gpio_in[1], db_gpio_in[0]} = {32'b0, db0_gpio_in};
   assign {db_gpio_in[3], db_gpio_in[2]} = {32'b0, db1_gpio_in};
   assign db0_gpio_out = db_gpio_out[0];  //db_gpio_out[1] unused
   assign db1_gpio_out = db_gpio_out[2];  //db_gpio_out[3] unused
   assign db0_gpio_ddr = db_gpio_ddr[0];  //db_gpio_ddr[1] unused
   assign db1_gpio_ddr = db_gpio_ddr[2];  //db_gpio_out[3] unused

   //Front-panel board GPIO
   assign {fp_gpio_r_in[1], fp_gpio_r_in[0]} = {32'b0, fp_gpio_in};
   assign {fp_gpio_r_in[3], fp_gpio_r_in[2]} = {32'b0, 32'b0};
   assign fp_gpio_out = fp_gpio_r_out[0];  //fp_gpio_r_out[1,2,3] unused
   assign fp_gpio_ddr = fp_gpio_r_ddr[0];  //fp_gpio_ddr[1,2,3] unused
   assign {fp_gpio_fab_arr[1], fp_gpio_fab_arr[0]} = {32'd0, fp_gpio_fab};
   assign {fp_gpio_fab_arr[3], fp_gpio_fab_arr[2]} = {32'd0, 32'd0};
   assign fp_gpio_rb = fp_gpio_rb_arr[0];

   //SPI
   assign {sen0, sclk0, mosi0} = {sen[0], sclk[0], mosi[0]};   //*[1] unused
   assign {miso[1], miso[0]}   = {1'b0, miso0};
   assign {sen1, sclk1, mosi1} = {sen[2], sclk[2], mosi[2]};   //*[3] unused
   assign {miso[3], miso[2]}   = {1'b0, miso1};

   //LEDs
   // When we RX on both channels, we don't light up both LEDs. Rather, we
   // treat both channels equally and print the overlay (OR) of both channels.
   assign radio_led0 = leds[0][2:0] | leds[1][2:0];
   assign radio_led1 = leds[2][2:0] | leds[3][2:0];
   // If we wanted to treat channel 2 special, and map the RX chans
   // to individual LEDs, we'd want to do something like this:
   //assign radio_led0 = leds[0][2:0] | {2'b0,leds[1][0]};
   //assign radio_led1 = leds[2][2:0] | {2'b0,leds[3][0]};
   // Reminder: radio_ledX = {RX, TXRX_TX, TXRX_RX}

   //Misc ins and outs
   always @(posedge radio_clk) begin
      radio0_misc_out   <= misc_outs[0];
      radio1_misc_out   <= misc_outs[2];
      misc_ins[0]       <= radio0_misc_in;
      misc_ins[2]       <= radio1_misc_in;
   end

endmodule // x300_core
