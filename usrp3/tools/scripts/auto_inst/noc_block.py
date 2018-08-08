#!/usr/bin/env python
"""
Setup noc block objects from block arguments derived from nocscript.
Applicable noc script tags:
<hdlname>           Required. Module name of block without 'noc_block_' prepended
<io>
    <clock>         Assignment for ce_clk port
    <reset>         Assignment for ce_rst port
    <bus_clock>     Assignment for bus_clk port
    <bus_reset>     Assignment for bus_rst port
    <port>          Extra ports for noc block, one tag per port
        <name>      Name of port
        <assign>    Port assignment value
        <declare>   Create wire for port
        <width>     Width of port, required if declare is true
    <parameter>     Module parameters, one tag per parameter
        <name>      Name of parameter
        <value>     Value
    <bus>
        <name_prefix>    Prefix for ports
        <name_postfix>   Postfix for ports
        <assign_prefix>  Prefix for port assignments
        <assign_postfix> Postfix for port assignments
        <type>           Bus type such as axi, see buses.py
        <width>          Width
        <addr_width>     (AXI only) Address width
        <master>         True or false, if true will setup wires and may signal naming
        <clock>          Assignment for bus clock, if omitted clock port is omitted
        <reset>          Assignment for bus port, if omitted reset port is omitted
        <bus_clock>      (CHDR only) Assignment for bus_clk port
        <bus_reset>      (CHDR only) Assignment for bus_rst port
    <verilog>       Raw verilog to include with module instantiation
NOTE: All tags are optional unless otherwise specified
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

import buses
import basic_types


class noc_block():
    def __init__(self, block_args, noc_blocks_list):
        # Set name based on hdlname and number of instances
        if 'hdlname' in block_args:
            self.name = block_args["hdlname"]
            self.inst_number = len([block for block in noc_blocks_list
                if block.get_block_arg('hdlname') == block_args['hdlname']])
        # This should have already been caught, but just in case...
        else:
            raise AssertionError("Noc block {0} (file: {1}) did not specify a hdlname!".format(
                block_args['block'], block_args['xmlfile']))
        self.block_number = len(noc_blocks_list)
        self.block_args = block_args  # Nocscript dict from nocscript parser
        self.io_args = block_args.get('io', {})  # For convience
        # Noc block module
        self.module = basic_types.module("noc_block_"+self.name, instance_number=self.inst_number)
        # Wires needed for noc block. For majority of noc blocks, this will be empty
        self.wires = basic_types.wire()
        # Add default CHDR bus
        chdr_bus = {
            'type': 'chdr',
            'name_prefix': None,
            'name_postfix': None,
            # Formatting so AXI bus will look like: ce_i_tdata[0], ce_i_tlast[0], etc...
            'assign_prefix': 'ce',
            'assign_postfix': '[{0}]'.format(self.block_number),
            'width': 64,
            # User can include 'clock', 'reset', tags in nocscript io section to set these
            'clock': self.io_args.get('clock', 'ce_clk'),
            'reset': self.io_args.get('reset', 'ce_rst'),
            'bus_clock': self.io_args.get('bus_clock', 'bus_clk'),
            'bus_reset': self.io_args.get('bus_clock', 'bus_rst'),
            'master': False
        }
        self.add_ports(buses.get_ports(chdr_bus))
        # Add debug port
        self.add_port('debug', 'ce_debug[{0}]'.format(self.block_number))
        # Add user defined ports
        if 'port' in self.io_args:
            self.add_ports(self.io_args['port'])
            for port in self.io_args['port']:
                if port.get('declare', False):
                    self.wires.add_item(port['assign'], port['width'])
        # Add user defined parameters
        if 'parameter' in self.io_args:
            self.add_parameters(self.io_args['parameter'])
        # Add user defined buses
        if 'bus' in self.io_args:
            for bus in self.io_args['bus']:
                self.add_ports(buses.get_ports(bus))
                if bus.get('master', False):
                    self.wires.add_items(buses.get_wires(bus))
        # Add verilog
        self.verilog = basic_types.verilog(self.block_args.get('verilog', ''))

    def add_port(self, name, assign):
        self.module.add_port(name, assign)

    def add_ports(self, ports):
        self.module.add_ports(ports)

    def append_port_assign(self, name, assign):
        self.module.append_port_assign(name, assign)

    def append_ports_assign(self, assigns):
        self.module.append_ports_assign(assigns)

    def add_parameter(self, parameter):
        self.module.add_parameter(**parameter)

    def add_parameters(self, parameters):
        self.module.add_parameters(parameters)

    def get_block_arg(self, name):
        """
        Return argument from block args dictionary.
        For nested arguments, use a list or tuple to specify path.
        """
        block_arg = self.block_args
        if isinstance(name, list) or isinstance(name, tuple):
            for _name in name:
                block_arg = block_arg.get(_name, None)
            return block_arg
        else:
            return self.block_args.get(name, None)

    def get_block_args(self):
        return self.block_args

    def get_port(self, name):
        return self.module.get_port(name)

    def get_ports(self):
        return self.module.get_ports()

    def get_parameter(self, name):
        return self.module.get_parameter(name)

    def get_parameters(self):
        return self.module.get_parameters()

    def get_code_dict(self):
        """
        Returns a dictionary containing code objects for wires and noc block module
        """
        d = {}
        d['verilog'] = self.verilog
        d['modules'] = self.module
        d['wires'] = self.wires
        return d
