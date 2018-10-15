#!/usr/bin/env python
"""
DRAM resource class for handling noc blocks that want DRAM access.
Instantiates an AXI interconnect and handles connections its AXI ports.
Applicable noc script tags:
<io>
    <dram>
        <name_prefix>       Prefix for noc block AXI ports
        <vlen>              Number of AXI buses / DRAM ports requested
                            Can also set to a parameter in the <parameter>
                            section, whose value will be used instead.
NOTE: All tags are optional.
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

import basic_types
import buses

# Parameters for axi_interconnect on a per device basis
intercon_params = {
    'x300': {
        'name': 'axi_intercon_{0}x64_256_bd_wrapper',
        'max_ports': 4,
        # Interconnect master AXI bus to MIG
        'master': {
            'type': 'axi',
            'name_prefix': 'M00_AXI',
            'assign_prefix': 'ddr3_axi',
            'width': 256,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk',
            'reset': '~ddr3_axi_rst'
        },
        # Arguments for interconnect slave AXI buses to RFNoC blocks
        'slave': {
            'type': 'axi',
            'name_prefix': 'S{0:02d}_AXI',
            'assign_prefix': 's{0:02d}_axi',
            'width': 64,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk_x2'
            # No slave reset on interface
        },
        # Default arguments for RFNoC block AXI bus. Just a template that will
        # be merged with user provided arguments.
        'noc_block': {
            'type': 'axi',
            'name_prefix': 'm_axi',
            'width': 64,
            'addr_width': 32
            # Note: 'clock' and 'reset' are optional
        }
    },
    'x310': {
        'name': 'axi_intercon_{0}x64_256_bd_wrapper',
        'max_ports': 2,
        'master': {
            'type': 'axi',
            'name_prefix': 'M00_AXI',
            'assign_prefix': 'ddr3_axi',
            'width': 256,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk',
            'reset': '~ddr3_axi_rst'
        },
        'slave': {
            'type': 'axi',
            'name_prefix': 'S{0:02d}_AXI',
            'assign_prefix': 's{0:02d}_axi',
            'width': 64,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk_x2',
        },
        'noc_block': {
            'type': 'axi',
            'name_prefix': 'm_axi',
            'width': 64,
            'addr_width': 32
        }
    },
    # TODO: Add E310 support, for now max_ports set to 0
    'e310': {
        'name': 'axi_intercon_{0}x64_128_bd_wrapper',
        'max_ports': 0,
        'master': {
            'type': 'axi',
            'name_prefix': 'M00_AXI',
            'assign_prefix': 'ddr3_axi',
            'width': 128,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk',
            'reset': '~ddr3_axi_rst'
        },
        'slave': {
            'type': 'axi',
            'name_prefix': 'S{0:02d}_AXI',
            'assign_prefix': 's{0:02d}_axi',
            'width': 64,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk_x2',
        },
        'noc_block': {
            'type': 'axi',
            'name_prefix': 'm_axi',
            'width': 64,
            'addr_width': 32
        }
    },
    'n310': {
        'name': 'axi_intercon_{0}x64_256_bd_wrapper',
        'max_ports': 4,
        'master': {
            'type': 'axi',
            'name_prefix': 'M00_AXI',
            'assign_prefix': 'ddr3_axi',
            'width': 256,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk',
            'reset': '~ddr3_axi_rst'
        },
        'slave': {
            'type': 'axi',
            'name_prefix': 'S{0:02d}_AXI',
            'assign_prefix': 's{0:02d}_axi',
            'width': 64,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk_x2',
        },
        'noc_block': {
            'type': 'axi',
            'name_prefix': 'm_axi',
            'width': 64,
            'addr_width': 32
        }
    },
}


class dram():
    def __init__(self, device):
        self.device = device
        self.ports_in_use = 0
        self.max_ports = intercon_params[self.device]['max_ports']
        # Setup interconnect module
        self.module = basic_types.module(intercon_params[self.device]['name'])
        # Add master bus, but not any wires because those are ports
        self.module.add_ports(self.make_uppercase_ports(buses.get_ports(intercon_params[device]['master'])))
        self.wires = basic_types.wire()

    def connect(self, noc_block_inst):
        """
        Connect a noc block to the interconnect. Adds the bus both to
        the dram object and the noc block.
        """
        dram_args = noc_block_inst.get_block_arg(('io', 'dram')).copy()
        # Grab vlen from nocscript. Resolve string if it is in the parameters section.
        try:
            vlen = int(dram_args.get('vlen', 1))
        except ValueError:
            vlen_param = dram_args['vlen']
            params = noc_block_inst.get_block_arg(('io', 'parameter'))
            for d in params:
                if d['name'] == vlen_param:
                    vlen = int(d['value'])
                    break
            else:
                assert vlen is not None, 'Could not resolve parameter {0} for vlen'.format(vlen_param)
        # Create a separate bus for each DRAM port requested
        for i in range(vlen):
            if self.ports_in_use > self.max_ports:
                error_str = "Too many DRAM connections." + \
                    "Failed on noc block {0} requesting {1} port(s). ".format(
                        noc_block_inst.get_block_arg['block'], vlen) + \
                    "Max allowed is {0}".format(self.max_ports)
                print "[DRAM][ERROR] " + error_str
                raise AssertionError(error_str)
            # Add wires and ports to interconnect module for each bus
            dram_bus_args = intercon_params[self.device]['slave'].copy()
            dram_bus_args['name_prefix'] = dram_bus_args['name_prefix'].format(self.ports_in_use)
            dram_bus_args['assign_prefix'] = dram_bus_args['assign_prefix'].format(self.ports_in_use)
            # NOTE: axi_interconnect generated with uppercase port names, so we need to use
            #       make_uppercase_ports()
            self.module.add_ports(self.make_uppercase_ports(buses.get_ports(dram_bus_args)))
            self.wires.add_items(buses.get_wires(dram_bus_args))
            # Add ports to noc block. If vlen > 1, port assignments will be concatenated.
            # Augment default arguments with user specified arguments from nocscript
            noc_block_bus_args = intercon_params[self.device]['noc_block'].copy()
            noc_block_bus_args['assign_prefix'] = dram_bus_args['assign_prefix']
            # Copy user settings from nocscript
            if dram_args.get('clock', False):
                noc_block_bus_args['clock'] = dram_args['clock']
            if dram_args.get('reset', False):
                noc_block_bus_args['reset'] = "~{0}".format(dram_args['reset'])
            # Add ports to noc block
            if (i == 0):
                noc_block_inst.add_ports(buses.get_ports(noc_block_bus_args))
            else:
                noc_block_inst.append_ports_assign(buses.get_ports(noc_block_bus_args))
            self.ports_in_use += 1

    def make_uppercase_ports(self, ports):
        """
        Make ports uppercase
        """
        for i in range(len(ports)):
            ports[i]['name'] = ports[i]['name'].upper()
        return ports

    def get_code_dict(self):
        """
        Returns a dictionary containing code objects for module, wires, etc
        Every resource class must have this method.
        """
        d = {}
        vstr = "\n/////////////////////////////////////\n"
        vstr += "// DRAM\n"
        vstr += "/////////////////////////////////////"
        d['verilog'] = basic_types.verilog(vstr)
        # Set module name based on number of ports in use
        self.module.set_name(intercon_params[self.device]['name'].format(self.ports_in_use))
        d['modules'] = self.module
        d['wires'] = self.wires
        return d
