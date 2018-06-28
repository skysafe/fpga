#!/usr/bin/env python
"""
Creates auto instantiation file for RFNoC
Use add_noc_block() to add noc blocks for instantiation and
to_verilog() for verilog code.
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
        self.resource_dict = {"dram": dram.dram, "fpgpio": fpgpio.fpgpio}
        self.resource_objs = {}

    def add_noc_block(self, block_args):
        """
        Add noc block with provided block arguments, i.e. nocscript dict from
        nocscript parser. If block uses specific device resources, such as dram,
        call the resource object.
        """
        noc_block_inst = noc_block.noc_block(block_args, self.noc_blocks)
        io_args = block_args.get('io', {})
        for key in io_args:
            if key in self.resource_dict:
                # Only make resource object one of the noc blocks use it
                if key not in self.resource_objs:
                    self.make_resource(key)
                self.resource_objs[key].connect(noc_block_inst)
        self.noc_blocks.append(noc_block_inst)

    def make_resource(self, resource):
        """
        Add resource object by name from resource dict.
        TODO: Allow resources from OOT modules.
        """
        self.resource_objs[resource] = self.resource_dict[resource](self.device)

    def to_verilog(self):
        """
        Create verilog code by collecting code dictionaries from noc blocks and
        resources and calling to_verilog() on each.
        """
        vstr = VERILOG_HEADER_TMPL.format(num_ce=len(self.noc_blocks))
        # TODO: Merge code dicts into one so duplicate wires, regs, etc
        #       can be handled.
        # Setup localparams, regs, wires, and assigns.
        # Order is important due to possible dependencies.
        code_order = ['localparams', 'regs', 'wires', 'assigns']
        for item in code_order:
            for (name, resource) in self.resource_objs.items():
                code_dict = resource.get_code_dict()
                if item in code_dict:
                    vstr += code_dict[item].to_verilog()
            for block in self.noc_blocks:
                code_dict = block.get_code_dict()
                if item in code_dict:
                    vstr += code_dict[item].to_verilog()
        # Group verilog code with module for better looking output
        code_order = ['verilog', 'modules']
        for item in code_order:
            for (name, resource) in self.resource_objs.items():
                code_dict = resource.get_code_dict()
                if item in code_dict:
                    vstr += code_dict[item].to_verilog()
        vstr += "\n/////////////////////////////////////\n"
        vstr += "// RFNoC Blocks\n"
        vstr += "/////////////////////////////////////"
        code_order = ['verilog', 'modules']
        for item in code_order:
            for block in self.noc_blocks:
                code_dict = block.get_code_dict()
                if item in code_dict:
                    vstr += code_dict[item].to_verilog()
        return vstr
