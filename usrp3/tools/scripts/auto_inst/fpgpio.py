#!/usr/bin/env python
"""
FPGPIO resource class for handling noc blocks that want front panel
general purpose IO access. Uses fabric access port on gpio_atr.
Applicable noc script tags:
<io>
    <fpgpio>
            <name_prefix>       Prefix for port name
            <in_bits>           Hexadecimal bit mask of input fpgpio to map to noc block
            <out_bits>          Hexadecimal bit mask of output fpgpio to map to noc block
            <exclusive_bits>    Hexadecimal bit mask of output fpgpio CE will exclusively
                                control (versus sharing with radio core)
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


# Parameters for FPGPIO on a per device basis
fgpio_params = {
    'x300': {
        # Number of FPGPIO
        'width': 32,
        # Default arguments that can be overriden by user
        'default': {
            'name_prefix': '',
            'in_bits': '0',
            'out_bits': '0',
            'exclusive_bits': '0'
        }
    },
    'x310': {
        'width': 32,
        'default': {
            'name_prefix': '',
            'in_bits': '0',
            'out_bits': '0',
            'exclusive_bits': '0'
        }
    },
    'e310': {
        'width': 6,
        'default': {
            'name_prefix': '',
            'in_bits': '0',
            'out_bits': '0',
            'exclusive_bits': '0'
        }
    },
    'n310': {
        'width': 32,
        'default': {
            'name_prefix': '',
            'in_bits': '0',
            'out_bits': '0',
            'exclusive_bits': '0'
        }
    }
}


class fpgpio():
    def __init__(self, device):
        self.device = device
        self.fpgpio_in_use = 0
        self.exclusive_bits = 0

    def connect(self, noc_block_inst):
        """
        Connect a noc block to FPGPIO. Adds the fpgpio ports to the noc block.
        """
        width = int(fgpio_params[self.device]['width'])
        noc_block_name = noc_block_inst.get_block_arg('block')
        # Tried to use FPGPIO with a device that does not have any
        if width == 0:
            self.print_error('{0} does not have any FPGPIO to connect'.format(self.device))
        # Merge default arguments and user arguments
        fgpio_args = fgpio_params[self.device]['default'].copy()
        fgpio_args.update(noc_block_inst.get_block_arg(('io', 'fpgpio')))
        # Expect hexadecimal bit masks
        in_bits = int(fgpio_args['in_bits'], 16)
        out_bits = int(fgpio_args['out_bits'], 16)
        exclusive_bits = int(fgpio_args['exclusive_bits'], 16)
        # Cannot use more FPGPIO than device supports
        if 2**width <= in_bits:
            self.print_error('noc block {0} requested more input FPGPIOs than USRP {1} supports'.format(
                noc_block_name, self.device))
        if 2**width <= out_bits:
            self.print_error('noc block {0} requested more output FPGPIOs than USRP {1} supports'.format(
                noc_block_name, self.device))
        # Check if output bits are already acquired
        overlap = out_bits & self.fpgpio_in_use
        if overlap == 0:
            self.fpgpio_in_use |= out_bits
        else:
            overlap_list = [2**i for i in range(width) if overlap >> i & 1]
            self.print_error('FPGPIO bits: {0} have multiple drivers'.format(overlap_list))
        # Check if attempting to own FPGPIOs that are not in out_bits
        greedy = ~out_bits & exclusive_bits
        if greedy:
            greedy_list = [2**i for i in range(width) if greedy >> i & 1]
            self.print_error('noc block {0} attempted to exclusively own FPGPIO bits: {1} without driving them'.format(
                noc_block_name, greedy_list))
        else:
            self.exclusive_bits |= exclusive_bits
        # Create FPGPIO input / output ports on noc block and assign FPGPIO bits
        # e.g. .fp_gpio_in(fp_gpio_rb[0], fp_gpio_rb[1], ...),
        # NOTE: It is assumed the fp_gpio_rb and fp_gpio_fab wires are already declared.
        if in_bits > 0:
            in_bits_list = [i for i in range(width) if in_bits >> i & 1]
            in_assign_list = []
            for bit in in_bits_list:
                in_assign_list.append('fp_gpio_rb[{0}]'.format(bit))
            noc_block_inst.append_port_assign(fgpio_args['name_prefix']+'fp_gpio_in', in_assign_list)
        if out_bits > 0:
            out_bits_list = [i for i in range(width) if out_bits >> i & 1]
            out_assign_list = []
            for bit in out_bits_list:
                out_assign_list.append('fp_gpio_fab[{0}]'.format(bit))
            noc_block_inst.append_port_assign(fgpio_args['name_prefix']+'fp_gpio_out', out_assign_list)

    def print_error(self, string):
        print '[FPGPIO][ERROR] ' + string
        raise AssertionError(string)

    def get_code_dict(self):
        """
        Returns a dictionary containing code objects for module, wires, etc
        Every resource class must have this method.
        """
        d = {}
        d['localparams'] = basic_types.localparam(
            {'name': 'FP_GPIO_FORCE_FAB_CTRL', 'assign': "{0}".format(self.exclusive_bits)})
        return d
