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

import re
import os
import glob
import lxml.objectify

NOCSCRIPT_RELAXNG_SCHEMA = os.path.join(os.path.dirname(os.path.realpath(__file__)), "nocscript.rng")

def get_default_block_parameters():
    default = {
        "xmlfile"    : '',       # Full path to noc script XML
        "name"       : '',       # Block full name
        "blockname"  : '',       # Block name
        "key"        : '',       # Unique key for block
        "hdlname"    : '',       # Name of block's HDL module/entity
        "doc"        : '',       # Documentation
        "ids"        : [],       # NOC IDs
        "setregs"    : {},       # Settings bus setting registers
        "readbacks"  : {},       # Settings bus readback regs
        "args"       : {},       # Noc script args
        "sinks"      : {},       # Sink block ports
        "sources"    : {},       # Source block ports
        "clock"      : 'ce_clk', # Net to assign to ce_clk input
        "reset"      : 'ce_rst', # Net to assign to ce_rst input
        "ports"      : {},       # Dict of extra ports to instantiate on block IO
        "gpio"       : {},       # Dict of blocks's general purpose IO
        "buses"      : [get_default_bus_parameters()],  # List of dicts of block's buses
        "parameters" : {}}       # Dict of block's HDL parameters/generics
    return default


def get_default_arg_parameters():
    default = {
        'type'          : '',
        'value'         : '',
        'check'         : '',
        'check_message' : ''
    }
    return default


def get_default_blockport_parameters():
    default = {
        'type'     : '',
        'port'     : '',
        'vlen'     : '',
        'pkt_size' : ''
    }
    return default


def get_default_bus_parameters():
    default = {
        'portprefix' : '',
        'netprefix'  : '',
        'type'       : 'chdr',
        'vlen'       : 1
    }
    return default


def find(include_dir):
    """
    Returns a list of nocblock xml files
    """
    files=[]
    postfix_search_paths = (
        '*.xml',
        # Install location
        os.path.join('share', 'uhd', 'rfnoc', 'blocks', '*.xml'),
        # OOT src
        os.path.join('blocks', '*.xml'),
        os.path.join('rfnoc', 'blocks', '*.xml'),
        # UHD src
        os.path.join('include', 'uhd', 'rfnoc', 'blocks', '*.xml'),
        os.path.join('host', 'include', 'uhd', 'rfnoc', 'blocks', '*.xml'))

    if include_dir is None:
        return files

    # Search user provided paths
    if isinstance(include_dir, str):
        for postfix_search_path in postfix_search_paths:
            if glob.glob(os.path.join(include_dir, postfix_search_path)):
                files.extend(glob.glob(os.path.join(include_dir, postfix_search_path)))
                break
    else:
        for path in include_dir:
            for postfix_search_path in postfix_search_paths:
                if glob.glob(os.path.join(path, postfix_search_path)):
                    files.extend(glob.glob(os.path.join(path, postfix_search_path)))
                    break
    # Nothing found, doh!
    if len(files) == 0:
        print("[WARNING] Did not find any noc script xml files in the following dirs:")
        if isinstance(include_dir, str):
            print(include_dir)
        else:
            for dir in include_dir:
                print(dir)

    return files


def find_default():
    """
    Returns a list of nocblock xml files by looking at predefined paths
    """
    files=[]
    search_paths = filter(None,(
    # Installed via PYBOMBS
    os.environ.get('PYBOMBS_PREFIX') if os.environ.get('PYBOMBS_PREFIX') else None,
    # fpga-src path in UHD src
    os.path.join('..', '..', '..', '..', 'uhd', 'host', 'include', 'uhd', 'rfnoc', 'blocks', '*.xml'),
    # usr local install
    os.path.join('/usr', 'local', 'share', 'uhd', 'rfnoc', 'blocks', '*.xml')))

    # default paths
    for search_path in search_paths:
        if glob.glob(search_path):
            files.extend(glob.glob(search_path))
            break
    return files


def copy_parameters(elem, d):
    for key in d.keys():
        if elem.find(key) is not None:
            d[key] = elem.find(key).text
    return d


def create_block(nocscript, file):
    """
    Convert nocscript element tree into an easier to use dict
    Note: It is assumed the element tree has been validated
    """
    block = get_default_block_parameters()
    block['xmlfile'] = file
    block['name'] = nocscript.find('name').text
    block['blockname'] = nocscript.find('blockname').text
    block['hdlname'] = nocscript.find('hdlname').text
    if nocscript.find('key') is not None:
        block['key'] = nocscript.find('key').text
    if nocscript.find('doc') is not None:
        block['doc'] = nocscript.find('doc').text
    block['ids'] = [nocid.text for nocid in nocscript.findall('ids/id')]
    for reg in nocscript.findall('registers/setreg'):
        block['setregs'][reg.find('name').text] = reg.find('address').text
    for reg in nocscript.findall('registers/readback'):
        block['readbacks'][reg.find('name').text] = reg.find('address').text
    for arg in nocscript.findall('args/arg'):
        block['args'][arg.find('name').text] = copy_parameters(arg, get_default_arg_parameters())
    for sink in nocscript.findall('ports/sink'):
        block['sinks'][sink.find('name').text] = copy_parameters(sink, get_default_blockport_parameters())
    for src in nocscript.findall('ports/source'):
        block['sources'][src.find('name').text] = copy_parameters(src, get_default_blockport_parameters())
    if nocscript.find('io/clock') is not None:
        block['clock'] = nocscript.find('io/clock').text
    if nocscript.find('io/reset') is not None:
        block['reset'] = nocscript.find('io/reset').text
    for port in nocscript.findall('io/port'):
        block['ports'][port.find('portname').text] = port.find('netname').text
    for gpio in nocscript.findall('io/gpio'):
        block['gpio'][gpio.find('portname').text] = gpio.find('netname').text
    if nocscript.find('io/bus') is not None:
        block['buses'] = [copy_parameters(bus, get_default_bus_parameters()) for bus in nocscript.findall('io/bus')]
    for param in nocscript.findall('parameters/parameter'):
        block['parameters'][param.find('name').text] = param.find('value').text
    return block


def parse(files):
    """
    Return a list of nocblocks by parsing nocscript xml files.
    Noc script files are linted for the required subset of fields and
    that no duplicate noc script files exist.
    """

    with open(NOCSCRIPT_RELAXNG_SCHEMA, 'r') as f:
        relaxng = lxml.etree.RelaxNG(file=f)

    nocblocks={}
    for file in files:
        with open(file, 'r') as f:
            nocscript = lxml.objectify.fromstring(f.read())
            # Validate with relax ng
            try:
                relaxng.assert_(nocscript)
            except BaseException:
                print('[ERROR] Failed to parse '+file)
                print('Parser errors:')
                error_log = re.split('\n',str(relaxng.error_log))
                for line in error_log:
                    line_split = re.split(':',line)
                    print('  line {0}: {1}'.format(line_split[1],line_split[6]))
                raise AssertionError("Invalid noc script")
            nocscript_name = os.path.splitext(os.path.basename(file))[0]
            if nocscript_name in nocblocks:
                print('[ERROR] Noc script files cannot have the same name:')
                print('  '+file)
                print('  '+nocblocks[nocscript_name]['xmlfile'])
                raise AssertionError('Cannot have two noc script files with same name:')
            nocblocks[nocscript_name] = create_block(nocscript, file)

    return nocblocks