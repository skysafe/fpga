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


def make(io_type, **kwargs):
    if io_type == 'ports':
        return ports(**kwargs)
    elif io_type == 'parameters':
        return parameters(**kwargs)
    elif io_type == 'bus':
        return bus(**kwargs)
    elif io_type == 'chdr':
        return chdr(**kwargs)
    elif io_type == 'axi_stream' or io_type == 'axi_stream master' or io_type == 'axi_stream slave':
        return chdr(**kwargs)
    elif io_type == 'axi' or io_type == 'axi master' or io_type == 'axi slave':
        return axi(**kwargs)
    elif io_type is None:
        raise ValueError('Type not specified')
    else:
        raise NotImplementedError('Unknown io or bus type ' + io_type)


def format_port_string(ports_dict):
    """
    Take a single dictionary of ports and format as a verilog string
    """
    ports_string = ''
    port_string_list = []
    if len(ports_dict) > 0:
        for (name, params) in sorted(ports_dict.items()):
            assign = params['assign']
            select = params['select']
            assign_string_list = []
            for i in range(len(assign)):
                if assign[i] is None:
                    assign_string = ""
                else:
                    assign_string = assign[i]
                # Assignments have bit select
                if select[i] is not None:
                    # Bit select [n:m]
                    if isinstance(select[i], tuple):
                        assign_string_list.append(assign_string+"["+select[0]+":"+select[1]+"]")
                    # Single bit or array select [n]
                    else:
                        assign_string_list.append(assign_string+"["+select+"]")
                else:
                    assign_string_list.append(assign_string)
            # Go from list to comma separated signals
            assign_string = ",".join(assign_string_list)
            # Add {...}, but only if concatenating signals
            concat_string = ("{{{0}}}" if len(assign) > 1 else "{0}").format(assign_string)
            # Create port strings in the format .name(assign)
            port_string_list.append(".{0}({1})".format(name, concat_string))
            # Create final port string
        ports_string = "\n  {0}".format(",\n  ".join(port_string_list))
    return ports_string


def format_wire_string(ports_dict):
    """
    Take a single dictionary of ports and create a string
    of verilog wire declarations
    """
    wires_string = ""
    if len(ports_dict) > 0:
        for (name, params) in sorted(ports_dict.items()):
            if params is not None:
                assign = params['assign']
                if assign != '':
                    width = params['width']
                    for i in range(len(assign)):
                        wires_string += "wire "
                        if isinstance(width[i], str):
                            wires_string += "[" + width[i] + "-1:0] "
                        elif width[i] > 1:
                            wires_string += "[{0}:0] ".format(width[i]-1)
                        wires_string += assign[i] + ";\n"
    return wires_string


class ports(object):
    def __init__(self, **kwargs):
        self.ports = {}
        if 'ports' in kwargs:
            self.set_ports(kwargs['ports'])

    def set_port(self, name, assign, width, select=None):
        port = {name: {}}
        port[name]['assign'] = self.to_list(assign)
        port[name]['width'] = self.to_list(width)
        if select is None:
            port[name]['select'] = len(port[name]['assign'])*self.to_list(select)
        else:
            port[name]['select'] = select
        assert len(port[name]['assign']) == len(port[name]['width']), "Invalid port parameters"
        assert len(port[name]['assign']) == len(port[name]['select']), "Invalid port parameters"
        self.ports.update(port)

    def set_ports(self, ports):
        for (key, values) in ports.items():
            self.set_port(key, **values)

    def get_port(self, name):
        """
        Returns the dict for requested port
        """
        return self.ports.get(name, None)

    def get_ports(self):
        """
        Returns a dict of ports
        """
        return self.ports

    def remove_port(self, name):
        del self.ports[name]

    def remove_ports(self, ports):
        for port in ports:
            self.remove_port(port)

    def remove_all_ports(self):
        self.ports = {}

    def append_port(self, name, assign, width, select=None):
        if name in self.ports:
            params = self.get_port(name)
            params['assign'].append(assign)
            params['width'].append(width)
            params['select'].append(select)
            self.set_port(name, **params)
        else:
            self.set_port(name, assign, width, select)

    def append_ports(self, ports):
        for (port, params) in ports:
            self.append_port(port, **params)

    def to_list(self, item):
        if not isinstance(item, list):
            return [item]
        else:
            return item


class parameters(ports):
    def __init__(self, **kwargs):
        super(parameters, self).__init__(**kwargs)
        if 'parameters' in kwargs:
            self.set_parameters(kwargs['parameters'])

    def set_parameter(self, name, assign):
        # Dont care about width for parameters
        self.set_port(name, assign, None)

    def set_parameters(self, parameters):
        params = {}
        for (name, assign) in parameters.items():
            params[name] = {}
            params[name]['assign'] = assign
            params[name]['width'] = None
        self.set_ports(params)

    def get_parameter(self, name):
        return self.get_port(name)

    def get_parameters(self):
        return self.get_ports()

    def remove_parameter(self, name):
        self.remove_port(name)

    def remove_parameters(self, parameters):
        self.remove_ports(parameters)


class bus(ports):
    def __init__(self, base_ports, vlen=1, **kwargs):
        super(bus, self).__init__(**kwargs)
        if len(base_ports[0]) == 2:
            self.base_ports = tuple((name, name, width*vlen) for (name, width) in base_ports)
        elif len(base_ports[0]) == 3:
            self.base_ports = tuple((name, assign, width*vlen) for (name, assign, width) in base_ports)
        else:
            raise TypeError("Invalid ports")

    def append_bus(self, name_prefix='axis', assign_prefix='axis', name_postfix='', assign_postfix='', **kwargs):
        name_prefix_list = self.to_list(name_prefix)
        name_postfix_list = self.to_list(name_postfix)
        assign_prefix_list = self.to_list(assign_prefix)
        assign_postfix_list = self.to_list(assign_postfix)
        assert len(name_postfix_list) == len(name_prefix_list), "Invalid bus parameters"
        assert len(assign_prefix_list) == len(name_prefix_list), "Invalid bus parameters"
        assert len(assign_postfix_list) == len(name_prefix_list), "Invalid bus parameters"
        for i in range(len(name_prefix_list)):
            name = name_prefix_list[i] + "{0}" + name_postfix_list[i]
            assign = assign_prefix_list[i] + "{0}" + assign_postfix_list[i]
            for (base_name, base_assign, width) in self.base_ports:
                self.append_port(name.format(base_name), assign.format(base_assign), width)


class chdr(bus):
    def __init__(self, name_prefix='', assign_prefix='', name_postfix='', assign_postfix='',
    width=64, vlen=1, clock=None, reset=None, busclock=None, busreset=None,
    master=False, **kwargs):
        if master is True:
            base_ports = (
                ('i_tdata', 'i_tdata', width),
                ('i_tlast', 'i_tlast', 1),
                ('i_tvalid', 'i_tvalid', 1),
                ('i_tready', 'i_tready', 1),
                ('o_tdata', 'o_tdata', width),
                ('o_tlast', 'o_tlast', 1),
                ('o_tvalid', 'o_tvalid', 1),
                ('o_tready', 'o_tready', 1))
        else:
            base_ports = (
                ('i_tdata', 'o_tdata', width),
                ('i_tlast', 'o_tlast', 1),
                ('i_tvalid', 'o_tvalid', 1),
                ('i_tready', 'o_tready', 1),
                ('o_tdata', 'i_tdata', width),
                ('o_tlast', 'i_tlast', 1),
                ('o_tvalid', 'i_tvalid', 1),
                ('o_tready', 'i_tready', 1))
        super(chdr, self).__init__(base_ports, vlen, **kwargs)
        self.append_bus(name_prefix, assign_prefix, name_postfix, assign_postfix)
        if clock is not None:
            self.set_port('ce_clk', clock, 1)
        else:
            self.set_port('ce_clk', 'ce_clk', 1)
        if reset is not None:
            self.set_port('ce_rst', reset, 1)
        else:
            self.set_port('ce_rst', 'ce_rst', 1)
        if busclock is not None:
            self.set_port('bus_clk', busclock, 1)
        else:
            self.set_port('bus_clk', 'bus_clk', 1)
        if busreset is not None:
            self.set_port('bus_rst', busreset, 1)
        else:
            self.set_port('bus_clk', 'bus_rst', 1)


class axi_stream(bus):
    def __init__(self, name_prefix='axis_', assign_prefix='axis_', name_postfix='', assign_postfix='',
    vlen=1, width=64, addr_width=32, clock=None, reset=None, **kwargs):
        base_ports = (
            ('tdata', width),
            ('tlast', 1),
            ('tvalid', 1),
            ('tready', 1)
        )
        super(axi_stream, self).__init__(base_ports, vlen, **kwargs)
        self.append_bus(name_prefix, assign_prefix, name_postfix, assign_postfix)
        if clock is not None:
            self.set_port(name_prefix+'aclk', clock, 1)
        if reset is not None:
            self.set_port(name_prefix+'aresetn', reset, 1)


class axi(bus):
    def __init__(self, name_prefix='axi_', assign_prefix='axi_', name_postfix='', assign_postfix='',
    vlen=1, width=64, addr_width=32, clock=None, reset=None, **kwargs):
        base_ports = (
            ('awid', 1),
            ('awaddr', addr_width),
            ('awlen', 8),
            ('awsize', 3),
            ('awburst', 2),
            ('awlock', 1),
            ('awcache', 4),
            ('awprot', 3),
            ('awqos', 4),
            ('awregion', 4),
            #('awuser', 1),
            ('awvalid', 1),
            ('awready', 1),
            ('wdata', width),
            ('wstrb', width/8),
            ('wlast', 1),
            #('wuser', 1),
            ('wvalid', 1),
            ('wready', 1),
            ('bid', 1),
            ('bresp', 2),
            #('buser', 1),
            ('bvalid', 1),
            ('bready', 1),
            ('arid', 1),
            ('araddr', addr_width),
            ('arlen', 8),
            ('arsize', 3),
            ('arburst', 2),
            ('arlock', 1),
            ('arcache', 4),
            ('arprot', 3),
            ('arqos', 4),
            ('arregion', 4),
            #('aruser', 1),
            ('arvalid', 1),
            ('arready', 1),
            ('rid', 1),
            ('rdata', width),
            ('rresp', 2),
            ('rlast', 1),
            #('ruser', 1),
            ('rvalid', 1),
            ('rready', 1)
        )
        super(axi, self).__init__(base_ports, vlen, **kwargs)
        self.append_bus(name_prefix, assign_prefix, name_postfix, assign_postfix)
        if clock is not None:
            self.set_port(name_prefix+'aclk', clock, 1)
        if reset is not None:
            self.set_port(name_prefix+'aresetn', reset, 1)
