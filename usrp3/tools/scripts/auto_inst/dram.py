#!/usr/bin/env python
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

import auto_inst_io


intercon_params = {
    'x300': {
        'name': 'axi_intercon_2x64_128_bd_wrapper',
        'max_ports': 2,
        'master': {
            'type': 'axi',
            'name_prefix': 'M00_AXI_',
            'assign_prefix': 'ddr3_axi_',
            'width': 128,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk',
            'reset': '~ddr3_axi_rst'
        },
        'slave': {
            'type': 'axi',
            'name_prefix': 'S{0:02d}_AXI_',
            'assign_prefix': 's{0:02d}_axi_',
            'width': 64,
            'addr_width': 32,
            'vlen': 1,
            'clock': 'ddr3_axi_clk_x2',
            'reset': '~ddr3_axi_rst'
        },
        'noc_block': {
            'type': 'axi',
            'name_prefix': 'm_axi_',
            'width': 64,
            'addr_width': 32,
            'vlen': 1
        }
    },
    'x310': {
        'name': 'axi_intercon_2x64_128_bd_wrapper',
        'max_ports': 2,
        'master': {
            'type': 'axi',
            'name_prefix': 'M00_AXI_',
            'assign_prefix': 'ddr3_axi_',
            'width': 128,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk',
            'reset': '~ddr3_axi_rst'
        },
        'slave': {
            'type': 'axi',
            'name_prefix': 'S{0:02d}_AXI_',
            'assign_prefix': 's{0:02d}_axi_',
            'width': 64,
            'addr_width': 32,
            'vlen': 1,
            'clock': 'ddr3_axi_clk_x2',
            'reset': '~ddr3_axi_rst'
        },
        'noc_block': {
            'type': 'axi',
            'name_prefix': 'm_axi_',
            'width': 64,
            'addr_width': 32,
            'vlen': 1
        }
    },
    # TODO: Add E310 support, for now max_ports set to 0
    'e310': {
        'name': 'axi_intercon_2x64_128_bd_wrapper',
        'max_ports': 0,
        'master': {
            'type': 'axi',
            'name_prefix': 'M00_AXI_',
            'assign_prefix': 'ddr3_axi_',
            'width': 128,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk',
            'reset': '~ddr3_axi_rst'
        },
        'slave': {
            'type': 'axi',
            'name_prefix': 'S{0:02d}_AXI_',
            'assign_prefix': 's{0:02d}_axi_',
            'width': 64,
            'addr_width': 32,
            'vlen': 1,
            'clock': 'ddr3_axi_clk_x2',
            'reset': '~ddr3_axi_rst'
        },
        'noc_block': {
            'type': 'axi',
            'name_prefix': 'm_axi_',
            'width': 64,
            'addr_width': 32,
            'vlen': 1
        }
    },
    'n310': {
        'name': 'axi_intercon_4x64_256_bd_wrapper',
        'max_ports': 4,
        'master': {
            'type': 'axi',
            'name_prefix': 'M00_AXI_',
            'assign_prefix': 'ddr3_axi_',
            'width': 256,
            'addr_width': 32,
            'clock': 'ddr3_axi_clk',
            'reset': '~ddr3_axi_rst'
        },
        'slave': {
            'type': 'axi',
            'name_prefix': 'S{0:02d}_AXI_',
            'assign_prefix': 's{0:02d}_axi_',
            'width': 64,
            'addr_width': 32,
            'vlen': 1,
            'clock': 'ddr3_axi_clk_x2',
            'reset': '~ddr3_axi_rst'
        },
        'noc_block': {
            'type': 'axi',
            'name_prefix': 'm_axi_',
            'width': 64,
            'addr_width': 32,
            'vlen': 1
        }
    },
}

DRAM_TMPL = """
{name} inst_{name} ({ports});
"""


class dram():
    def __init__(self, device):
        self.device = device
        self.ports_in_use = 0
        # Intialize master bus
        master_bus_params = intercon_params[device]['master']
        self.master_bus = auto_inst_io.make(master_bus_params['type'], **master_bus_params)
        self.slave_bus = []

    def connect(self, noc_block_inst):
        """
        Connect a noc block to the interconnect. Adds the bus both to
        the dram object and the noc block.
        """
        if self.ports_in_use > intercon_params[self.device]['max_ports']:
            error_str = "Too many connections to axi interconnect. Max allowed is {0}".format(
                intercon_params[self.device]['max_ports']
            )
            print "[DRAM][ERROR] " + error_str
            raise AssertionError(error_str)
        nocscript_params = noc_block_inst.get_block_parameter('dram').copy()
        vlen = int(nocscript_params.get('vlen', 1))
        nocscript_params['vlen'] = 1
        for i in range(vlen):
            dram_bus_params = nocscript_params.copy()
            dram_bus_params.update(intercon_params[self.device]['slave'])
            dram_bus_params['name_prefix'] = dram_bus_params['name_prefix'].format(self.ports_in_use)
            dram_bus_params['assign_prefix'] = dram_bus_params['assign_prefix'].format(self.ports_in_use)
            noc_block_bus_params = intercon_params[self.device]['noc_block'].copy()
            noc_block_bus_params.update(nocscript_params)
            noc_block_bus_params['assign_prefix'] = dram_bus_params['assign_prefix']
            self.slave_bus.append(auto_inst_io.make(dram_bus_params['type'], **dram_bus_params))
            if (i == 0):
                noc_block_bus = auto_inst_io.make(noc_block_bus_params['type'], **noc_block_bus_params)
            else:
                noc_block_bus.append_bus(**noc_block_bus_params)
            self.ports_in_use += 1
        noc_block_inst.add_bus(noc_block_bus)

    def get_ports(self):
        ports = self.master_bus.get_ports()
        for bus in self.slave_bus:
            ports.update(bus.get_ports())
        return ports

    def get_declaration_string(self):
        ports = {}
        for bus in self.slave_bus:
            ports.update(bus.get_ports())
        # TODO: Need to be able to mark certain ports to not be declared
        for name in ports:
            if intercon_params[self.device]['slave']['clock'] in ports[name]['assign']:
                ports[name] = None
            elif intercon_params[self.device]['slave']['reset'] in ports[name]['assign']:
                ports[name] = None
        unused_bus_params = []
        unused_bus = []
        for i in range(self.ports_in_use, intercon_params[self.device]['max_ports']):
            unused_bus_params.append(intercon_params[self.device]['slave'].copy())
            unused_bus_params[i]['name_prefix'] = unused_bus_params[i]['name_prefix'].format(i)
            unused_bus_params[i]['assign_prefix'] = unused_bus_params[i]['assign_prefix'].format(i)
            # TODO: Have to set these to None to prevent wires for getting set
            unused_bus_params[i]['clock'] = None
            unused_bus_params[i]['reset'] = None
            unused_bus.append(auto_inst_io.make(unused_bus_params[i]['type'], **unused_bus_params[i]))
            ports.update(unused_bus[i].get_ports())
        return auto_inst_io.format_wire_string(ports)

    def get_module_string(self):
        vstr = "\n"
        vstr += "/////////////////////////////////////\n"
        vstr += "// DRAM\n"
        vstr += "/////////////////////////////////////\n"
        # TODO: Fix axi_intercon so port names are not capitialized
        ports = {}
        for (name, value) in self.get_ports().items():
            ports[name.upper()] = value
        # Setup usused ports. Since the ports will not be assigned to anything,
        # the port should be mostly pruned out. Will generate lots of warnings.
        # TODO: Get rid of this code by using correctly sized interconnect
        # depending on number of ports in use.
        unused_bus_params = []
        unused_bus = []
        for i in range(self.ports_in_use, intercon_params[self.device]['max_ports']):
            unused_bus_params.append(intercon_params[self.device]['slave'].copy())
            unused_bus_params[i]['name_prefix'] = unused_bus_params[i]['name_prefix'].format(i)
            unused_bus_params[i]['assign_prefix'] = unused_bus_params[i]['assign_prefix'].format(i)
            unused_bus.append(auto_inst_io.make(unused_bus_params[i]['type'], **unused_bus_params[i]))
            ports.update(unused_bus[i].get_ports())
        vstr = DRAM_TMPL.format(
            name=intercon_params[self.device]['name'],
            ports=auto_inst_io.format_port_string(ports))
        return vstr
