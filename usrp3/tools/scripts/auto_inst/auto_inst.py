#!/usr/bin/env python
"""
Creates auto instantiation file for RFNoC
Use add_noc_block() to add noc blocks for instantiation and
get_verilog_string() for verilog code.
"""
"""
Copyright 2018 SkySafe Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

import noc_block
import dram
import fpgpio

VERILOG_HEADER_TMPL = """
/////////////////////////////////////////////////////////
// Auto-generated instantiation file
// WARNING: Any changes to this file may be overwritten
/////////////////////////////////////////////////////////
localparam NUM_CE = {num_ce};
wire [NUM_CE*64-1:0] ce_flat_o_tdata, ce_flat_i_tdata;
wire [63:0]          ce_o_tdata, ce_i_tdata;
wire [NUM_CE-1:0]    ce_o_tlast, ce_o_tvalid, ce_o_tready, ce_i_tlast, ce_i_tvalid, ce_i_tready;
wire [63:0]          ce_debug[0:NUM_CE-1];

wire ce_clk = radio_clk;
wire ce_rst = radio_rst;

// Flattern CE tdata arrays
genvar k;
generate
for (k = 0; k < NUM_CE; k = k + 1) begin
    assign ce_o_tdata[k] = ce_flat_o_tdata[k*64+63:k*64];
    assign ce_flat_i_tdata[k*64+63:k*64] = ce_i_tdata[k];
end
endgenerate

"""


class auto_inst():
    def __init__(self, device):
        self.device = device
        self.noc_blocks = []
        self.resources = {"dram": dram.dram(device), "fpgpio": fpgpio.fpgpio(device)}

    def add_noc_block(self, block_parameters):
        """
        Add noc block with provided parameters. If block uses specific device
        resources, such as dram, call the resource's handler object.
        """
        noc_block_inst = noc_block.noc_block(block_parameters, self.noc_blocks)
        for key in block_parameters:
            if key in self.resources:
                self.resources[key].connect(noc_block_inst)
        self.noc_blocks.append(noc_block_inst)

    def get_verilog_string(self):
        vstr = VERILOG_HEADER_TMPL.format(num_ce=len(self.noc_blocks))
        # Wire declarations always before modules
        # TODO: This does not catch duplicate ports, which should be an error
        for (name, resource) in self.resources.items():
            vstr += resource.get_declaration_string()
        for block in self.noc_blocks:
            vstr += block.get_declaration_string()
        # Module declarations
        for (name, resource) in self.resources.items():
            vstr += resource.get_module_string()
        for block in self.noc_blocks:
            vstr += block.get_module_string()
        return vstr
