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

NOC_BLOCK_TMPL = """
noc_block_{blockname} #({params})
noc_block_{blockname}_{inst_number} ({ports},
  .debug(ce_debug[{block_number}])
);
"""


class noc_block():
    def __init__(self, block_parameters, noc_blocks_list):
        # Set name based on hdlname and number of instances
        if 'hdlname' in block_parameters:
            self.name = block_parameters["hdlname"]
            self.inst_number = len([block for block in noc_blocks_list
                if block.get_block_parameter('hdlname') == block_parameters['hdlname']])
        else:
            raise AssertionError("Noc block {0} (file: {1}) did not specify a hdlname!".format(
                block_parameters['blockname'], block_parameters['xmlfile']))
        self.block_number = len(noc_blocks_list)
        self.block_parameters = block_parameters
        # Add default CHDR bus and any ports / buses / parameters specified in block parameters
        # Note: CHDR bus is handled separately (instead of being in self.buses) due to special naming
        chdr_bus = {
            'type': 'chdr',
            'name_prefix': '',
            'name_postfix': '',
            'assign_prefix': 'ce_',
            'assign_postfix': '[{0}]'.format(self.block_number),
            'width': 64,
            'clock': block_parameters.get('clock', 'ce_clk'),
            'reset': block_parameters.get('reset', 'ce_rst'),
            'busclock': block_parameters.get('busclock', 'bus_clk'),
            'busreset': block_parameters.get('busclock', 'bus_rst'),
            'master': False
        }
        self.chdr = auto_inst_io.make(chdr_bus['type'], **chdr_bus)
        self.extra_ports = auto_inst_io.make('ports')
        if 'ports' in block_parameters:
            self.set_ports(block_parameters['ports'])
        self.parameters = auto_inst_io.make('parameters')
        if 'parameters' in block_parameters:
            self.set_parameters(block_parameters['parameters'])
        self.buses = []
        if 'buses' in block_parameters:
            for bus in block_parameters['buses']:
                self.add_bus(bus)

    def set_port(self, name, assign, width):
        self.extra_ports.set_port(name, assign, width)

    def set_ports(self, ports):
        self.extra_ports.set_ports(ports)

    def set_parameter(self, name, assign):
        self.parameters.set_parameter(name, assign)

    def set_parameters(self, parameters):
        self.parameters.set_parameters(parameters)

    def add_bus(self, bus):
        self.buses.append(bus)

    def get_block_parameter(self, name):
        return self.block_parameters[name]

    def get_parameters(self):
        return self.parameters.get_parameters()

    def get_ports(self):
        ports = self.extra_ports.get_ports()
        ports.update(self.chdr.get_ports())
        for bus in self.buses:
            ports.update(bus.get_ports())
        return ports

    def get_declaration_string(self):
        """
        """
        # TODO: chdr ports are skipped because they are declared outside this block,
        #       but should really be declared here
        ports = self.extra_ports.get_ports()
        for bus in self.buses:
            ports.update(bus.get_ports())
        return auto_inst_io.format_wire_string(ports)

    def get_module_string(self):
        vstr = self.block_parameters.get('verilog', '')
        vstr += NOC_BLOCK_TMPL.format(
            blockname=self.name,
            inst_number=self.inst_number,
            block_number=self.block_number,
            params=auto_inst_io.format_port_string(self.get_parameters()),
            ports=auto_inst_io.format_port_string(self.get_ports()))
        return vstr
