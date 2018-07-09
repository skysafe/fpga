#!/usr/bin/env python
"""
Helper functions for handling buses, such as axi, axi stream, and CHDR.
Generally only need to use get_ports(), get_wires(), and get_code_dict().
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


def get_ports(args):
    """
    Return dict of ports for bus
    """
    return get_bus_dict(args)['ports']


def get_wires(args):
    """
    Return dict of wires for bus
    """
    return get_bus_dict(args)['wires']


def get_bus_dict(args):
    """
    Return code dict for bus
    """
    _args = args.copy()
    bus_type = _args.pop('type', None)
    if bus_type == 'chdr':
        return get_chdr_dict(**_args)
    elif bus_type == 'axi stream':
        return get_axi_stream_dict(**_args)
    elif bus_type == 'axi':
        return get_axi_dict(**_args)
    elif bus_type is None:
        raise ValueError('Type not specified')
    else:
        raise NotImplementedError('Unknown io or bus type ' + bus_type)


def get_chdr_dict(width=64, name_prefix=None, name_postfix=None,
        assign_prefix=None, assign_postfix=None, master=False,
        clock=None, reset=None, bus_clock=None, bus_reset=None):
    signals = [('tdata', width), ('tlast', 1), ('tvalid', 1), ('tready', 1)]
    ports = prefix_string((name_prefix, 'i'), postfix_string(name_postfix, signals)) + \
        prefix_string((name_prefix, 'o'), postfix_string(name_postfix, signals))
    if master:
        assigns = prefix_string((assign_prefix, 'i'), postfix_string(assign_postfix, signals)) + \
            prefix_string((assign_prefix, 'o'), postfix_string(assign_postfix, signals))
    else:
        assigns = prefix_string((assign_prefix, 'o'), postfix_string(assign_postfix, signals)) + \
            prefix_string((assign_prefix, 'i'), postfix_string(assign_postfix, signals))
    # Wires are not created for clock / reset ports
    wires = assigns[:]
    # If clock / reset / bus_clock / bus_reset is not set, then the port is left out
    if bus_reset is not None:
        # Inserting at beginning of list makes output look better
        ports.insert(0, ('bus_rst', 1))
        assigns.insert(0, (bus_reset, 1))
    if bus_clock is not None:
        ports.insert(0, ('bus_clk', 1))
        assigns.insert(0, (bus_clock, 1))
    if reset is not None:
        ports.insert(0, ('ce_rst', 1))
        assigns.insert(0, (reset, 1))
    if clock is not None:
        ports.insert(0, ('ce_clk', 1))
        assigns.insert(0, (clock, 1))
    d = {}
    d['ports'] = make_ports(ports, assigns)
    d['wires'] = make_wires(wires)
    return d


def get_axi_stream_dict(width=64, user_width=0, name_prefix=None, name_postfix=None,
        assign_prefix=None, assign_postfix=None, clock=None, reset=None):
    signals = [('tdata', width), ('tlast', 1), ('tvalid', 1), ('tready', 1)]
    if user_width > 0:
        signals += (('tuser', user_width),)
    ports = prefix_string(name_prefix, postfix_string(name_postfix, signals))
    assigns = prefix_string(assign_prefix, postfix_string(assign_postfix, signals))
    # Wires are not created for clock / reset ports
    wires = assigns[:]
    # If clock / reset is not set, then the port is left out
    if reset is not None:
        # Inserting at beginning of list makes output look better
        ports.insert(0, prefix_string(name_prefix, postfix_string(name_postfix, ('aresetn', 1))))
        assigns.insert(0, (reset, 1))
    if clock is not None:
        ports.insert(0, prefix_string(name_prefix, postfix_string(name_postfix, ('aclk', 1))))
        assigns.insert(0, (clock, 1))
    d = {}
    d['ports'] = make_ports(ports, assigns)
    d['wires'] = make_wires(wires)
    return d


def get_axi_dict(width=64, addr_width=32, name_prefix=None, name_postfix=None,
        assign_prefix=None, assign_postfix=None, clock=None, reset=None):
    signals = [
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
        ('awvalid', 1),
        ('awready', 1),
        ('wdata', width),
        ('wstrb', width/8),
        ('wlast', 1),
        ('wvalid', 1),
        ('wready', 1),
        ('bid', 1),
        ('bresp', 2),
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
        ('arvalid', 1),
        ('arready', 1),
        ('rid', 1),
        ('rdata', width),
        ('rresp', 2),
        ('rlast', 1),
        ('rvalid', 1),
        ('rready', 1)
    ]
    ports = prefix_string(name_prefix, postfix_string(name_postfix, signals))
    assigns = prefix_string(assign_prefix, postfix_string(assign_postfix, signals))
    # Wires are not created for clock / reset ports
    wires = assigns[:]
    # If clock / reset is not set, then the port is left out
    if reset is not None:
        # Inserting at beginning of list makes output look better
        ports.insert(0, prefix_string(name_prefix, postfix_string(name_postfix, ('aresetn', 1))))
        assigns.insert(0, (reset, 1))
    if clock is not None:
        ports.insert(0, prefix_string(name_prefix, postfix_string(name_postfix, ('aclk', 1))))
        assigns.insert(0, (clock, 1))
    d = {}
    d['ports'] = make_ports(ports, assigns)
    d['wires'] = make_wires(wires)
    return d


def prefix_string(prefix, signals):
    if prefix is not None:
        if isinstance(prefix, list) or isinstance(prefix, tuple):
            _prefix = [i for i in prefix if i is not None and i != '']
            _prefix = "_".join(_prefix)
        else:
            _prefix = prefix
        if not isinstance(signals, list):
            (name, width) = signals
            return (_prefix+"_"+name, width)
        else:
            return [(_prefix+"_"+name, width) for (name, width) in signals]
    else:
        return signals


def postfix_string(postfix, signals):
    if postfix is not None:
        if isinstance(postfix, list) or isinstance(postfix, tuple):
            _postfix = [i for i in postfix if i is not None and i != '']
            _postfix = "_".join(_postfix)
        else:
            _postfix = postfix
        if not isinstance(signals, list):
            (name, width) = signals
            return (name+_postfix, width)
        else:
            return [(name+_postfix, width) for (name, width) in signals]
    else:
        return signals


def make_ports(ports, assigns):
    """
    Make list of dicts for ports
    """
    port_names = [name for (name, width) in ports]
    port_assigns = [name for (name, width) in assigns]
    return [{'name': name, 'assign': assign} for
        (name, assign) in zip(port_names, port_assigns)]


def make_wires(signals):
    """
    Make list of dicts for wires
    """
    return [{'name': name, 'width': width} for (name, width) in signals]
