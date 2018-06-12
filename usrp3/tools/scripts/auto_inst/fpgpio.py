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

fgpio_settings = {
    'x300': {
        'width': 32,
        'default': {
            'nameprefix': '',
            'in_bits': '0',
            'out_bits': '0',
            'own_bits': '0'
        }
    },
    'x310': {
        'width': 32,
        'default': {
            'nameprefix': '',
            'in_bits': '0',
            'out_bits': '0',
            'own_bits': '0'
        }
    },
    'e310': {
        'width': 6,
        'default': {
            'nameprefix': '',
            'in_bits': '0',
            'out_bits': '0',
            'own_bits': '0'
        }
    },
    'n310': {
        'width': 0,
        'default': {
            'nameprefix': '',
            'in_bits': '0',
            'out_bits': '0',
            'own_bits': '0'
        }
    }
}


class fpgpio():
    def __init__(self, device):
        self.device = device
        self.fpgpio_in_use = 0
        self.own_bits = 0
        self.assigns_in = []
        self.assigns_out = []

    def connect(self, noc_block_inst):
        width = int(fgpio_settings[self.device]['width'])
        if width == 0:
            raise AssertionError('{0} does not have any FPGPIO to connect'.format(self.device))
        fgpio_params = fgpio_settings[self.device]['default'].copy()
        fgpio_params.update(noc_block_inst.get_block_parameter('fpgpio'))
        in_bits = int(fgpio_params['in_bits'], 16)
        out_bits = int(fgpio_params['out_bits'], 16)
        own_bits = int(fgpio_params['own_bits'], 16)
        # Check if output bits are already acquired
        overlap = out_bits & self.fpgpio_in_use
        if overlap == 0:
            self.fpgpio_in_use |= out_bits
        else:
            overlap_list = [2**i for i in range(width) if overlap >> i & 1]
            raise AssertionError('FPGPIO bits: {0} have multiple drivers'.format(overlap_list))
        # Check if attempting to own FPGPIOs that are not in out_bits
        greedy = ~out_bits & own_bits
        if greedy:
            greedy_list = [2**i for i in range(width) if greedy >> i & 1]
            raise AssertionError('Attempting to own FPGPIO bits: {0} without driving them'.format(greedy_list))
        else:
            self.own_bits |= own_bits
        # Create fp_gpio_in port on noc block
        if in_bits > 0:
            in_bits_list = [i for i in range(width) if in_bits >> i & 1]
            fp_gpio_in_assign = 'fp_gpio_rb_{0}'.format(len(self.assigns_in))
            noc_block_inst.set_port(fgpio_params['nameprefix']+'fp_gpio_in',
                fp_gpio_in_assign, len(in_bits_list))
            self.assigns_in.append((fp_gpio_in_assign, in_bits_list))
        # Create fp_gpio_out port on noc block
        if out_bits > 0:
            out_bits_list = [i for i in range(width) if out_bits >> i & 1]
            fp_gpio_out_assign = 'fp_gpio_fab_{0}'.format(len(self.assigns_out))
            noc_block_inst.set_port(fgpio_params['nameprefix']+'fp_gpio_out',
                fp_gpio_out_assign, len(out_bits_list))
            self.assigns_out.append((fp_gpio_out_assign, out_bits_list))

    def get_declaration_string(self):
        vstr = "localparam FP_GPIO_FORCE_FAB_CTRL = {0};\n".format(self.own_bits)
        return vstr

    def get_module_string(self):
        vstr = "\n"
        vstr += "/////////////////////////////////////\n"
        vstr += "// FPGPIO assignments\n"
        vstr += "/////////////////////////////////////\n"
        for (assign, bits_list) in self.assigns_in:
            fp_gpio_rb_list = []
            for bit in bits_list:
                fp_gpio_rb_list.append("fp_gpio_rb[{0}]".format(bit))
            vstr += "assign {0} = {{{1}}};\n".format(assign, ",".join(fp_gpio_rb_list))
        for (assign, bits_list) in self.assigns_out:
            i = 0
            for bit in bits_list:
                vstr += "assign fp_gpio_fab[{0}] = {1}[{2}];\n".format(bit, assign, i)
                i += 1
        return vstr
