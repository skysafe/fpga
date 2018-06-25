#!/usr/bin/env python
"""
Classes for describing Verilog constructs, such as wires, regs, modules, etc.
Every class has a to_verilog() method so it can output a verilog string.
Intended for describing the verilog implementation of resource classes.
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
import collections


def to_list(item):
    if item is not None:
        if isinstance(item, list):
            return item
        else:
            return [item]
    else:
        return None


def string_is_int(string):
    try:
        int(string)
        return True
    except ValueError:
        return False


class generic_hdl_type(object):
    """
    Base class for implementing reg, wire, localparam, and assign.
    """
    def __init__(self, hdl_type, items=None):
        assert hdl_type is not None, "Data type cannot be None"
        self.hdl_type = hdl_type
        self.items = collections.OrderedDict()
        if items is not None:
            self.add_items(items)

    def add_item(self, name, width=None, assign=None, array_width=None):
        assert name is not None, "{0} name cannot be None".format(self.hdl_type)
        assert len(name) > 0, "{0} name cannot be empty".format(self.hdl_type)
        if width is not None and isinstance(width, int):
            assert width > 0, "{0} width must be greater than 0".format(self.hdl_type)
        if array_width is not None and isinstance(array_width, int):
            assert array_width > 0, "{0} array width must be greater than 0".format(self.hdl_type)
        self.items[name] = {}
        self.items[name]['width'] = width
        self.items[name]['assign'] = assign
        self.items[name]['array_width'] = array_width

    def add_items(self, items):
        if isinstance(items, list) or isinstance(items, tuple):
            for item in items:
                self.add_item(**item)
        else:
            self.add_item(**items)

    def get_item(self, name):
        if name in self.items:
            d = {}
            d['name'] = name
            d.update(self.items[name])
            return d
        else:
            return None

    def remove_item(self, name):
        del self.items[name]

    def remove_items(self, names):
        if isinstance(names, list) or isinstance(names, tuple):
            for name in names:
                self.remove_item(name)
        else:
            self.remove_item(names)

    def clear(self):
        self.items = collections.OrderedDict()

    def to_verilog(self):
        """
        Returns verilog string
        """
        vstr = ""
        for name in self.items:
            width = self.items[name]['width']
            assign = self.items[name]['assign']
            array_width = self.items[name]['array_width']
            vstr += "{0}".format(self.hdl_type)
            # e.g. wire **[3:0]** mywire[0:2];
            if width is not None and width > 1:
                if string_is_int(width):
                    vstr += " [{0}:0]".format(width-1)
                else:
                    vstr += " [{0}-1:0]".format(width)
            vstr += " {0}".format(name)
            # e.g. wire [3:0] mynet**[0:2]**;
            if array_width is not None and array_width > 1:
                if not isinstance(array_width, list):
                    array_width_list = list(array_width)
                else:
                    array_width_list = array_width
                for _array_width in array_width_list:
                    if string_is_int(_array_width):
                        vstr += "[0:{0}]".format(_array_width-1)
                    else:
                        vstr += "[0:{0}-1]".format(_array_width)
            # e.g. wire [3:0] mywire[0:2] = **otherwire**;
            if assign is not None:
                if isinstance(assign, tuple) or isinstance(assign, list):
                    vstr += " = {{{0}}}".format(",".join(assign))
                else:
                    vstr += " = {0}".format(assign)
            vstr += ";\n"
        return vstr


class reg(generic_hdl_type):
    def __init__(self, regs=None):
        super(reg, self).__init__('reg', regs)


class wire(generic_hdl_type):
    def __init__(self, wires=None):
        super(wire, self).__init__('wire', wires)


class localparam(generic_hdl_type):
    def __init__(self, localparams=None):
        super(localparam, self).__init__('localparam', localparams)


class assign(generic_hdl_type):
    def __init__(self, assigns=None):
        if isinstance(assigns, dict):
            _assigns = list(assigns)
        for _assign in _assigns:
            assert 'assign' in _assign, "assign must be set"
            assert 'width' not in _assign, "assign cannot have a width"
            assert 'array_width' not in _assign, "assign cannot have an array_width"
        super(assign, self).__init__('assign', assigns)


class verilog():
    """
    Verilog code string
    """
    def __init__(self, string):
        self.vstr = string

    def add(self, string):
        self.vstr += string

    def clear(self, string):
        self.vstr = ''

    def to_verilog(self):
        return self.vstr


class module():
    """
    Verilog module, including parameters and ports.
    Use instance_number to differentiate multiple instances of same module.
    """
    def __init__(self, name, parameters=None, ports=None, instance_number=0):
        assert name is not None, "Module name cannot be None"
        assert len(name) > 0, "Module name cannot be empty"
        self.name = name
        self.instance_number = instance_number
        # Use OrderedDict so ports and parameters are printed in insertion order
        # for better looking output
        self.parameters = collections.OrderedDict()
        self.ports = collections.OrderedDict()
        if parameters is not None:
            if isinstance(parameters, list):
                for parameter in parameters:
                    self.insert_parameter(**parameter)
            else:
                self.insert_parameter(**parameters)
        if ports is not None:
            if isinstance(ports, list):
                for port in ports:
                    self.insert_port(**port)
            else:
                self.insert_port(**ports)

    def get_port(self, name):
        if name in self.ports:
            return {name: self.ports[name]}
        else:
            return None

    def get_ports(self):
        return [{'name': port['name'], 'assign': port['assign'], 'select': port['select']}
                for port in self.ports]

    def get_parameter(self, name):
        if name in self.parameters:
            return {name: self.parameter[name]}
        else:
            return None

    def get_parameters(self):
        return [{'name': param['name'], 'assign': param['assign'], 'select': param['select']}
                for param in self.parameters]

    def add_port(self, name, assign=None, select=None):
        self.ports[name] = {}
        self.ports[name]['assign'] = to_list(assign)
        if select is None:
            self.ports[name]['select'] = len(self.ports[name]['assign'])*[None]
        else:
            self.ports[name]['select'] = to_list(select)

    def add_ports(self, ports):
        if isinstance(ports, list) or isinstance(ports, tuple):
            for port in ports:
                self.add_port(**port)
        else:
            self.add_port(**ports)

    def append_port_assign(self, name, assign, select=None):
        if name in self.ports:
            self.ports[name]['assign'].append(assign)
            self.ports[name]['select'].append(select)
        else:
            self.add_port(name, assign, select)

    def append_ports_assign(self, assigns):
        if isinstance(assigns, list) or isinstance(assigns, tuple):
            for assign in assigns:
                self.append_port_assign(**assign)
        else:
            self.append_port_assign(**assigns)

    def remove_port_assign(self, name):
        if name in self.ports:
            self.ports[name]['assign'].pop()
            self.ports[name]['select'].pop()

    def add_parameter(self, name, value=None, select=None):
        self.parameters[name] = {}
        self.parameters[name]['assign'] = to_list(value)
        if select is None:
            self.parameters[name]['select'] = len(self.parameters[name]['assign'])*[None]
        else:
            self.parameters[name]['select'] = to_list(select)

    def add_parameters(self, parameters):
        if isinstance(parameters, list) or isinstance(parameters, tuple):
            for parameter in parameters:
                self.add_parameter(**parameter)
        else:
            self.add_parameter(**parameters)

    def append_parameter_assignment(self, name, assign, select=None):
        self.parameters[name]['assign'].append(assign)
        self.parameters[name]['select'].append(select)

    def remove_parameter_assignment(self, name):
        self.parameters[name]['assign'].pop()
        self.parameters[name]['select'].pop()

    def remove_port(self, name):
        del self.ports[name]

    def clear_ports(self):
        self.ports = collections.OrderedDict()

    def remove_parameter(self, name):
        del self.parameters[name]

    def clear_parameters(self):
        self.parameters = collections.OrderedDict()

    def dict_to_verilog(self, d):
        """
        Convert dict (either parameters or ports) to verilog strings.
        """
        string_list = []
        for name in d:
            assign = d[name]['assign']
            select = d[name]['select']
            # No assignment
            if len(assign) == 0:
                string_list.append(".{0}()".format(name))
            # One assignment
            elif len(assign) == 1:
                # Bit select
                if select[0] is not None:
                    if isinstance(select, tuple):
                        string_list.append(".{0}({1}[{2}:{3}])".format(name, assign[0], select[0][0], select[0][1]))
                    else:
                        string_list.append(".{0}({1}[{2}])".format(name, assign[0], select[0]))
                else:
                    string_list.append(".{0}({1})".format(name, assign[0]))
            # Concatenate multiple assignments
            else:
                assign_list = []
                for (_assign, _select) in zip(assign, select):
                    if _select is not None:
                        if isinstance(_select, tuple):
                            assign_list.append("{0}[{1}:{2}]".format(_assign, _select[0], _select[1]))
                        else:
                            assign_list.append("{0}[{1}]".format(_assign, _select))
                    else:
                        assign_list.append("{0}".format(_assign))
                # Concatenation getting a bit long, insert new line
                for i in range(len(assign_list)):
                    if i % 4 == 3:
                        assign_list[i] = '\n        ' + assign_list[i]
                string_list.append(".{0}({1})".format(name, "{{{0}}}".format(",".join(assign_list))))
        return string_list

    def to_verilog(self):
        """
        Returns verilog string of module instantiation
        """
        vstr = "\n{0} ".format(self.name)
        if len(self.parameters) > 0:
            vstr += "#(\n  {0})\n".format(",\n  ".join(self.dict_to_verilog(self.parameters)))
        vstr += "{0}_{1}".format(self.name, self.instance_number)
        if len(self.ports) > 0:
            vstr += " (\n  {0})".format(",\n  ".join(self.dict_to_verilog(self.ports)))
        vstr += ";\n"
        return vstr
