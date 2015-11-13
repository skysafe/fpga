#! /usr/bin/python

import sys, os
import collections
import argparse
import re

#------------------------------------------------------------
# Types
#------------------------------------------------------------
# Terminal definiion for each reference designator
terminal_t = collections.namedtuple('terminal_t', 'name pin')
# FPGA pin definiion
fpga_pin_t = collections.namedtuple('fpga_pin_t', 'name loc iotype bank')

# A (ref designator -> terminals) map
class terminal_db_t:
    def __init__(self):
        self.db = dict()
        self.rev_db = dict()

    def add(self, ref_des, net_name, pin_name):
        if self.db.has_key(ref_des):
            self.db[ref_des].append(terminal_t(net_name, pin_name))
        else:
            self.db[ref_des] = [terminal_t(net_name, pin_name)]
        if self.rev_db.has_key(net_name):
            self.rev_db[net_name].append(ref_des)
        else:
            self.rev_db[net_name] = [ref_des]

    def get_terminals(self, ref_des):
        return self.db[ref_des]

    def lookup_endpoints(self, net_name):
        return self.rev_db[net_name]

# A (component -> properties) map
class component_db_t:
    def __init__(self):
        self.db = dict()

    def add_comp(self, ref_des, name):
        self.db[ref_des] = {'Name':name}

    def add_attr(self, ref_des, prop, value):
        self.db[ref_des][prop] = value

    def exists(self, comp_name):
        return self.db.has_key(comp_name)

    def lookup(self, comp_name):
        return self.db[comp_name]

    def attr_exists(self, comp_name, attr_name):
        return self.exists(comp_name) and self.db[comp_name].has_key(attr_name)

    def get_attr(self, comp_name, attr_name):
        return self.db[comp_name][attr_name]

# An FPGA (pin location -> properties) map
class fpga_pin_db_t:
    def __init__(self, pkg_file):
        header = []
        self.db = dict()
        with open(pkg_file, 'r') as pkg_f:
            for line in iter(pkg_f.readlines()):
                tokens = collapse_tokens(line.strip().split('  '))
                if len(tokens) == 8:
                    if tokens[0] == 'Pin':
                        header = tokens
                    else:
                        pin_info = dict()
                        for col in range(1,len(header)):
                            pin_info[header[col].strip()] = tokens[col].strip()
                        self.db[tokens[0].strip()] = pin_info

    def pin_exists(self, pin):
        return self.db.has_key(pin)

    def get_pin_attr(self, pin, attr):
        return self.db[pin][attr]

#------------------------------------------------------------
# Helper functions
#------------------------------------------------------------

# Parse command line options
def get_options():
    parser = argparse.ArgumentParser(description='Generate a template XDC file from an RINF netlist and a Xilinx package file.')
    parser.add_argument('--rinf', type=str, default=None, help='Input RINF netlist file.')
    parser.add_argument('--xil_pkg_file', type=str, default=None, help='Input Xilinx package pinout file.')
    parser.add_argument('--ref_des', type=str, default='U0', help='Reference designator')
    parser.add_argument('--xdc_out', type=str, default='output.xdc', help='Output XDC file.')
    parser.add_argument('--vstub_out', type=str, default=None, help='Output Verilog stub file with the portmap')
    args = parser.parse_args()
    if not args.xil_pkg_file:
        print 'ERROR: Please specify a Xilinx package file using the --xil_pkg_file option\n'
        parser.print_help()
        sys.exit(1)
    if not args.rinf:
        print 'ERROR: Please specify an input RINF file using the --rinf option\n'
        parser.print_help()
        sys.exit(1)
    return args


# Remove empty string from a token array
def collapse_tokens(tokens):
    retval = []
    for tok in tokens:
        if tok.strip():
            retval.append(tok)
    return retval

# Parse user specified RINF file and return a terminal and component database
def parse_rinf(rinf_path):
    terminal_db = terminal_db_t()
    component_db = component_db_t()
    with open(rinf_path, 'r') as rinf_f:
        net_name = '<UNDEF>'
        state = '<UNDEF>'
        line_num = 0
        for line in iter(rinf_f.readlines()):
            tokens = collapse_tokens(line.strip().split('  '))
            line_num = line_num + 1
            if tokens:
                if tokens[0].startswith('.'):
                    # State transition
                    state = tokens[0]
                    if state == '.ADD_COM':
                        component_db.add_comp(tokens[1], tokens[3])
                    elif state == '.ATT_COM':
                        component_db.add_attr(tokens[1], tokens[2].strip('"'), tokens[3].strip('"'))
                    elif state == '.ADD_TER':
                        net_name = tokens[3]
                        terminal_db.add(tokens[1], net_name, tokens[2])
                    elif state == '.TER':
                        terminal_db.add(tokens[1], net_name, tokens[2])
                    elif state == '.END':
                        break
                else:
                    # State continuation
                    if state == '.TER':
                        terminal_db.add(tokens[0], net_name, tokens[1])
                    else:
                        print 'WARNING: Ignoring line continuation for ' + state + ' at line ' + str(line_num)
    return (terminal_db, component_db)

# From all the FPGA pins filter out the ones
# relevant for creating an XDC
def filter_fpga_pins(ref_des, terminal_db, fpga_pin_db):
    terminals = terminal_db.get_terminals(ref_des)
    pins = dict()
    for term in terminals:
        if term.name and (not term.name.startswith('$')):
            if fpga_pin_db.pin_exists(term.pin):
                iotype = fpga_pin_db.get_pin_attr(term.pin, 'I/O Type')
                bank = fpga_pin_db.get_pin_attr(term.pin, 'Bank')
                if iotype != 'CONFIG' and iotype != 'NA':
                    pins[term.name] = fpga_pin_t(term.name, term.pin, iotype, bank)
    return pins

# Write an XDC file with sanity checks and readability enhancements
def write_output_files(xdc_path, vstub_path, fpga_pins):
    # Figure out the max pin name length for human readable text alignment
    max_pin_len = reduce(lambda x,y:max(x,y), map(len, fpga_pins.keys()))

    # Create a bus database. Collapse multi-bit buses into single entries
    bus_db = dict()
    for pin in sorted(fpga_pins.keys()):
        m = re.search('([a-zA-Z0-9_()]+)\(([0-9]+)\)', pin)
        if m:
            bus_name = m.group(1)
            bit_num = int(m.group(2))
            if bus_db.has_key(bus_name):
                bus_db[bus_name].append(bit_num)
            else:
                bus_db[bus_name] = [bit_num]
        else:
                bus_db[pin] = []

    # Walk through the bus database and write the XDC file
    with open(xdc_path, 'w') as xdc_f:
        print 'INFO: Writing template XDC ' + xdc_path + '...'
        for bus in sorted(bus_db.keys()):
            if not re.match("[a-zA-Z].[a-zA-Z0-9_]*$", bus):
                print 'CRITICAL WARNING: Invalid Verilog net name: ' + bus + '. Please review.'
            if bus_db[bus] == []:
                xdc_pin = bus.upper()
                xdc_loc = fpga_pins[bus].loc.upper().ljust(16)
                xdc_iotype = fpga_pins[bus].iotype
                xdc_iostd = ('<IOSTD_BANK' + fpga_pins[bus].bank + '>').ljust(16)
                xdc_f.write('set_property PACKAGE_PIN   ' + xdc_loc + (' [get_ports {' + xdc_pin + '}]').ljust(max_pin_len+16) + '\n')
                xdc_f.write('set_property IOSTANDARD    ' + xdc_iostd + ' [get_ports {' + xdc_pin + '}]\n')
                xdc_f.write('\n')
            else:
                bits = sorted(bus_db[bus])
                coherent = (bits == range(0, bits[-1]+1))
                if not coherent:
                    print 'CRITICAL WARNING: Incoherent bus: ' + bus + '. Some bits may be missing. Please review.'
                for bit in bits:
                    bus_full = bus + '(' + str(bit) + ')'
                    xdc_pin = bus.upper() + '[' + str(bit) + ']'
                    xdc_loc = fpga_pins[bus_full].loc.upper().ljust(16)
                    xdc_iotype = fpga_pins[bus_full].iotype
                    xdc_iostd = ('<IOSTD_BANK' + fpga_pins[bus_full].bank + '>').ljust(16)
                    xdc_f.write('set_property PACKAGE_PIN   ' + xdc_loc + (' [get_ports {' + xdc_pin + '}]').ljust(max_pin_len+16) + '\n')
                xdc_f.write('set_property IOSTANDARD    ' + xdc_iostd + ' [get_ports {' + bus.upper() + '[*]}]\n')
                xdc_f.write('\n')

    # Walk through the bus database and write a stub Verilog file
    if vstub_path:
        with open(vstub_path, 'w') as vstub_f:
            print 'INFO: Writing Verilog stub ' + vstub_path + '...'
            vstub_f.write('module ' + os.path.splitext(os.path.basename(vstub_path))[0] + ' (\n')
            i = 1
            for bus in sorted(bus_db.keys()):
                port_name = bus.upper()
                port_loc = fpga_pins[bus].loc.upper() if (bus_db[bus] == []) else '<Multiple>'
                port_dir_short = raw_input('[' + str(i) + '/' + str(len(bus_db.keys())) +'] Direction for ' + port_name + ' (' + port_loc + ')? {[i]nput,[o]utput,[b]oth}: ').lower()
                if port_dir_short.startswith('i'):
                    port_dir = '  input '
                elif port_dir_short.startswith('o'):
                    port_dir = '  output'
                else:
                    port_dir = '  inout '

                if bus_db[bus] == []:
                    vstub_f.write(port_dir + '          ' + port_name + ',\n')
                else:
                    bus_def = str(sorted(bus_db[bus])[-1]) + ':0'
                    vstub_f.write(port_dir + (' [' + bus_def + '] ').ljust(10) + port_name + ',\n')
                i = i + 1
            vstub_f.write(');\n\nendmodule')

#------------------------------------------------------------
# Main
#------------------------------------------------------------
def main():
    args = get_options();
    print 'INFO: Parsing Xilinx Package File ' + args.xil_pkg_file + '...'
    fpga_pin_db = fpga_pin_db_t(args.xil_pkg_file)
    print 'INFO: Parsing RINF File ' + args.rinf + '...'
    (terminal_db, component_db) = parse_rinf(args.rinf)
    print 'INFO: Resolving reference designator ' + args.ref_des + '...'
    if not component_db.exists(args.ref_des):
        print 'ERROR: Reference designator not found in the netlist'
        sys.exit(1)
    fpga_info = component_db.lookup(args.ref_des)
    print 'INFO: * Name = ' + fpga_info['Name']
    print 'INFO: * Description = ' + fpga_info['Description']
    fpga_pins = filter_fpga_pins(args.ref_des, terminal_db, fpga_pin_db)
    if not fpga_pins:
        print 'ERROR: Could not cross-reference pins for ' + args.ref_des + ' with FPGA device. Are you sure it is an FPGA?'
        sys.exit(1)
    write_output_files(args.xdc_out, args.vstub_out, fpga_pins)
    print 'INFO: Output file(s) generated successfully!'

if __name__ == '__main__':
    main()
