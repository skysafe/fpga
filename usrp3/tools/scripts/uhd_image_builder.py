#!/usr/bin/env python
"""
Copyright 2016-2017 Ettus Research

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

from __future__ import print_function
import argparse
import os
import re
import glob
import lxml.objectify
import nocscript_parser

HEADER_TMPL = """/////////////////////////////////////////////////////////
// Auto-generated by uhd_image_builder.py! Any changes
// in this file will be overwritten the next time
// this script is run.
/////////////////////////////////////////////////////////
localparam NUM_CE = {num_ce};
wire [NUM_CE*CHDR_WIDTH-1:0] ce_flat_o_tdata, ce_flat_i_tdata;
wire [NUM_CE-1:0]            ce_o_tlast, ce_o_tvalid, ce_o_tready, ce_i_tlast, ce_i_tvalid, ce_i_tready;
wire [63:0]                  ce_debug[0:NUM_CE-1];

wire ce_clk = radio_clk;
wire ce_rst = radio_rst;
"""

BLOCK_TMPL = """
noc_block_{blockname} {blockparameters}{instname} (
  .bus_clk  (bus_clk),
  .bus_rst  (bus_rst),
  .ce_clk   ({clock}),
  .ce_rst   ({reset}),{buses}{gpio}{ports}
  .debug    (ce_debug[{n}])
);
"""

# Dict of standard bus templates
BUS_TMPL = { \
'chdr': {'cnt' : 0, 'template': \
"""
  .i_tdata  (ce_flat_o_tdata[CHDR_WIDTH*{n}-1:CHDR_WIDTH*{m}]),
  .i_tlast  (ce_o_tlast[{n}-1:{m}]),
  .i_tvalid (ce_o_tvalid[{n}-1:{m}]),
  .i_tready (ce_o_tready[{n}-1:{m}]),
  .o_tdata  (ce_flat_i_tdata[CHDR_WIDTH*{n}-1:CHDR_WIDTH*{m}]),
  .o_tlast  (ce_i_tlast[{n}-1:{m}]),
  .o_tvalid (ce_i_tvalid[{n}-1:{m}]),
  .o_tready (ce_i_tready[{n}-1:{m}]),"""},
'axi master': {'cnt' : 0, 'template': \
"""
  .{portprefix}m_axi_awid     ({netprefix}s_axi_awid_flat[{n}-1:{m}]),
  .{portprefix}m_axi_awaddr   ({netprefix}s_axi_awaddr_flat[32*{n}-1:32*{m}]),
  .{portprefix}m_axi_awlen    ({netprefix}s_axi_awlen_flat[8*{n}-1:8*{m}]),
  .{portprefix}m_axi_awsize   ({netprefix}s_axi_awsize_flat[3*{n}-1:3*{m}]),
  .{portprefix}m_axi_awburst  ({netprefix}s_axi_awburst_flat[2*{n}-1:2*{m}]),
  .{portprefix}m_axi_awlock   ({netprefix}s_axi_awlock_flat[{n}-1:{m}]),
  .{portprefix}m_axi_awcache  ({netprefix}s_axi_awcache_flat[4*{n}-1:4*{m}]),
  .{portprefix}m_axi_awprot   ({netprefix}s_axi_awprot_flat[3*{n}-1:3*{m}]),
  .{portprefix}m_axi_awqos    ({netprefix}s_axi_awqos_flat[4*{n}-1:4*{m}]),
  .{portprefix}m_axi_awregion ({netprefix}s_axi_awregion_flat[4*{n}-1:4*{m}]),
  .{portprefix}m_axi_awuser   ({netprefix}s_axi_awuser_flat[{n}-1:{m}]),
  .{portprefix}m_axi_awvalid  ({netprefix}s_axi_awvalid_flat[{n}-1:{m}]),
  .{portprefix}m_axi_awready  ({netprefix}s_axi_awready_flat[{n}-1:{m}]),
  .{portprefix}m_axi_wdata    ({netprefix}s_axi_wdata_flat[64*{n}-1:64*{m}]),
  .{portprefix}m_axi_wstrb    ({netprefix}s_axi_wstrb_flat[8*{n}-1:8*{m}]),
  .{portprefix}m_axi_wlast    ({netprefix}s_axi_wlast_flat[{n}-1:{m}]),
  .{portprefix}m_axi_wuser    ({netprefix}s_axi_wuser_flat[{n}-1:{m}]),
  .{portprefix}m_axi_wvalid   ({netprefix}s_axi_wvalid_flat[{n}-1:{m}]),
  .{portprefix}m_axi_wready   ({netprefix}s_axi_wready_flat[{n}-1:{m}]),
  .{portprefix}m_axi_bid      ({netprefix}s_axi_bid_flat[{n}-1:{m}]),
  .{portprefix}m_axi_bresp    ({netprefix}s_axi_bresp_flat[2*{n}-1:2*{m}]),
  .{portprefix}m_axi_buser    ({netprefix}s_axi_buser_flat[{n}-1:{m}]),
  .{portprefix}m_axi_bvalid   ({netprefix}s_axi_bvalid_flat[{n}-1:{m}]),
  .{portprefix}m_axi_bready   ({netprefix}s_axi_bready_flat[{n}-1:{m}]),
  .{portprefix}m_axi_arid     ({netprefix}s_axi_arid_flat[{n}-1:{m}]),
  .{portprefix}m_axi_araddr   ({netprefix}s_axi_araddr_flat[32*{n}-1:32*{m}]),
  .{portprefix}m_axi_arlen    ({netprefix}s_axi_arlen_flat[8*{n}-1:8*{m}]),
  .{portprefix}m_axi_arsize   ({netprefix}s_axi_arsize_flat[3*{n}-1:3*{m}]),
  .{portprefix}m_axi_arburst  ({netprefix}s_axi_arburst_flat[2*{n}-1:2*{m}]),
  .{portprefix}m_axi_arlock   ({netprefix}s_axi_arlock_flat[{n}-1:{m}]),
  .{portprefix}m_axi_arcache  ({netprefix}s_axi_arcache_flat[4*{n}-1:4*{m}]),
  .{portprefix}m_axi_arprot   ({netprefix}s_axi_arprot_flat[3*{n}-1:3*{m}]),
  .{portprefix}m_axi_arqos    ({netprefix}s_axi_arqos_flat[4*{n}-1:4*{m}]),
  .{portprefix}m_axi_arregion ({netprefix}s_axi_arregion_flat[4*{n}-1:4*{m}]),
  .{portprefix}m_axi_aruser   ({netprefix}s_axi_aruser_flat[{n}-1:{m}]),
  .{portprefix}m_axi_arvalid  ({netprefix}s_axi_arvalid_flat[{n}-1:{m}]),
  .{portprefix}m_axi_arready  ({netprefix}s_axi_arready_flat[{n}-1:{m}]),
  .{portprefix}m_axi_rid      ({netprefix}s_axi_rid_flat[{n}-1:{m}]),
  .{portprefix}m_axi_rdata    ({netprefix}s_axi_rdata_flat[64*{n}-1:64*{m}]),
  .{portprefix}m_axi_rresp    ({netprefix}s_axi_rresp_flat[2*{n}-1:2*{m}]),
  .{portprefix}m_axi_rlast    ({netprefix}s_axi_rlast_flat[{n}-1:{m}]),
  .{portprefix}m_axi_ruser    ({netprefix}s_axi_ruser_flat[{n}-1:{m}]),
  .{portprefix}m_axi_rvalid   ({netprefix}s_axi_rvalid_flat[{n}-1:{m}]),
  .{portprefix}m_axi_rready   ({netprefix}s_axi_rready_flat[{n}-1:{m}]),"""},
'axi slave': {'cnt' : 0, 'template': \
"""
  .{portprefix}s_axi_awid     ({netprefix}m_axi_awid_flat[{n}-1:{m}]),
  .{portprefix}s_axi_awaddr   ({netprefix}m_axi_awaddr_flat[32*{n}-1:32*{m}]),
  .{portprefix}s_axi_awlen    ({netprefix}m_axi_awlen_flat[8*{n}-1:8*{m}]),
  .{portprefix}s_axi_awsize   ({netprefix}m_axi_awsize_flat[3*{n}-1:3*{m}]),
  .{portprefix}s_axi_awburst  ({netprefix}m_axi_awburst_flat[2*{n}-1:2*{m}]),
  .{portprefix}s_axi_awlock   ({netprefix}m_axi_awlock_flat[{n}-1:{m}]),
  .{portprefix}s_axi_awcache  ({netprefix}m_axi_awcache_flat[4*{n}-1:4*{m}]),
  .{portprefix}s_axi_awprot   ({netprefix}m_axi_awprot_flat[3*{n}-1:3*{m}]),
  .{portprefix}s_axi_awqos    ({netprefix}m_axi_awqos_flat[4*{n}-1:4*{m}]),
  .{portprefix}s_axi_awregion ({netprefix}m_axi_awregion_flat[4*{n}-1:4*{m}]),
  .{portprefix}s_axi_awuser   ({netprefix}m_axi_awuser_flat[{n}-1:{m}]),
  .{portprefix}s_axi_awvalid  ({netprefix}m_axi_awvalid_flat[{n}-1:{m}]),
  .{portprefix}s_axi_awready  ({netprefix}m_axi_awready_flat[{n}-1:{m}]),
  .{portprefix}s_axi_wdata    ({netprefix}m_axi_wdata_flat[64*{n}-1:64*{m}]),
  .{portprefix}s_axi_wstrb    ({netprefix}m_axi_wstrb_flat[8*{n}-1:8*{m}]),
  .{portprefix}s_axi_wlast    ({netprefix}m_axi_wlast_flat[{n}-1:{m}]),
  .{portprefix}s_axi_wuser    ({netprefix}m_axi_wuser_flat[{n}-1:{m}]),
  .{portprefix}s_axi_wvalid   ({netprefix}m_axi_wvalid_flat[{n}-1:{m}]),
  .{portprefix}s_axi_wready   ({netprefix}m_axi_wready_flat[{n}-1:{m}]),
  .{portprefix}s_axi_bid      ({netprefix}m_axi_bid_flat[{n}-1:{m}]),
  .{portprefix}s_axi_bresp    ({netprefix}m_axi_bresp_flat[2*{n}-1:2*{m}]),
  .{portprefix}s_axi_buser    ({netprefix}m_axi_buser_flat[{n}-1:{m}]),
  .{portprefix}s_axi_bvalid   ({netprefix}m_axi_bvalid_flat[{n}-1:{m}]),
  .{portprefix}s_axi_bready   ({netprefix}m_axi_bready_flat[{n}-1:{m}]),
  .{portprefix}s_axi_arid     ({netprefix}m_axi_arid_flat[{n}-1:{m}]),
  .{portprefix}s_axi_araddr   ({netprefix}m_axi_araddr_flat[32*{n}-1:32*{m}]),
  .{portprefix}s_axi_arlen    ({netprefix}m_axi_arlen_flat[8*{n}-1:8*{m}]),
  .{portprefix}s_axi_arsize   ({netprefix}m_axi_arsize_flat[3*{n}-1:3*{m}]),
  .{portprefix}s_axi_arburst  ({netprefix}m_axi_arburst_flat[2*{n}-1:2*{m}]),
  .{portprefix}s_axi_arlock   ({netprefix}m_axi_arlock_flat[{n}-1:{m}]),
  .{portprefix}s_axi_arcache  ({netprefix}m_axi_arcache_flat[4*{n}-1:4*{m}]),
  .{portprefix}s_axi_arprot   ({netprefix}m_axi_arprot_flat[3*{n}-1:3*{m}]),
  .{portprefix}s_axi_arqos    ({netprefix}m_axi_arqos_flat[4*{n}-1:4*{m}]),
  .{portprefix}s_axi_arregion ({netprefix}m_axi_arregion_flat[4*{n}-1:4*{m}]),
  .{portprefix}s_axi_aruser   ({netprefix}m_axi_aruser_flat[{n}-1:{m}]),
  .{portprefix}s_axi_arvalid  ({netprefix}m_axi_arvalid_flat[{n}-1:{m}]),
  .{portprefix}s_axi_arready  ({netprefix}m_axi_arready_flat[{n}-1:{m}]),
  .{portprefix}s_axi_rid      ({netprefix}m_axi_rid_flat[{n}-1:{m}]),
  .{portprefix}s_axi_rdata    ({netprefix}m_axi_rdata_flat[64*{n}-1:64*{m}]),
  .{portprefix}s_axi_rresp    ({netprefix}m_axi_rresp_flat[2*{n}-1:2*{m}]),
  .{portprefix}s_axi_rlast    ({netprefix}m_axi_rlast_flat[{n}-1:{m}]),
  .{portprefix}s_axi_ruser    ({netprefix}m_axi_ruser_flat[{n}-1:{m}]),
  .{portprefix}s_axi_rvalid   ({netprefix}m_axi_rvalid_flat[{n}-1:{m}]),
  .{portprefix}s_axi_rready   ({netprefix}m_axi_rready_flat[{n}-1:{m}]),"""},
}

# List of blocks that are part of our library but that do not take part
# in the process this tool provides
BLACKLIST = {'radio_core'}

OOT_DIR_TMPL = """\nOOT_DIR = {oot_dir}\n"""
OOT_INC_TMPL = """include $(OOT_DIR)/Makefile.inc\n"""
OOT_SRCS_TMPL = """RFNOC_OOT_SRCS += {sources}\n"""
OOT_SRCS_FILE_HDR = """##################################################
# Include OOT makefiles
##################################################\n"""


def setup_parser():
    """
    Create argument parser
    """
    parser = argparse.ArgumentParser(
        description="Generate the NoC block instantiation file",
    )
    parser.add_argument(
        "-I", "--oot-include-dir",
        help="Path directory of the RFNoC Out-of-Tree module",
        nargs='+',
        default=None)
    parser.add_argument(
        "--uhd-include-dir",
        help="Path directory of UHD",
        default=None)
    parser.add_argument(
        "-y", "--yml",
        help="YML file definition of onboard blocks\
              (overrides the 'block' positional arguments)",
        default=None)
    parser.add_argument(
        "-m", "--max-num-blocks", type=int,
        help="Maximum number of blocks (Max. Allowed for x310|x300: 10,\
                for e300: 6)",
        default=10)
    parser.add_argument(
        "--fill-with-fifos",
        help="If the number of blocks provided was smaller than the max\
                number, fill the rest with FIFOs",
        action="store_true")
    parser.add_argument(
        "-o", "--outfile",
        help="Output /path/filename - By running this directive,\
                you won't build your IP",
        default=None)
    parser.add_argument(
        "-d", "--device",
        help="Device to be programmed [x300, x310, e310, n300, n310]",
        default="x310")
    parser.add_argument(
        "-t", "--target",
        help="Build target - image type [X3X0_RFNOC_HG, X3X0_RFNOC_XG,\
                E310_RFNOC_sg3...]",
        default=None)
    parser.add_argument(
        "-g", "--GUI",
        help="Open Vivado GUI during the FPGA building process",
        action="store_true")
    parser.add_argument(
        "-c", "--clean-all",
        help="Cleans the IP before a new build",
        action="store_true")
    parser.add_argument(
        "blocks",
        help="List block names to instantiate.",
        default="",
        nargs='*',
    )
    return parser


def parse_yml(ymlfile):
    """
    Parse an input yaml file with a list of blocks and parameters!
    """
    try:
        import yaml
    except ImportError:
        print('[ERROR] Could not import yaml module')
        exit(1)

    with open(ymlfile, 'r') as f:
        data = yaml.load(f)
    blocks = []
    # Validate
    for val in data:
        block = nocscript_parser.get_default_block_parameters()
        if "block" in val:
            block["block"] = val["block"]
        else:
            print('[ERROR] "block" not specified in yaml block input file')
            exit(1)
        if "clock" in val:
            block["clock"] = val["clock"]
        if "reset" in val:
            block["reset"] = val["reset"]
        if "parameters" in val:
            block["parameters"] = val["parameters"]
        if "ports" in val:
            block["ports"] = val["ports"]
        blocks.append(block)

    return blocks

def format_bus_str(buses):
    """
    Take a single block bus dictionary and format as a verilog string
    """
    busstr = ""
    if buses:
        for bus in buses:
            vlen = int(bus['vlen'])
            n = BUS_TMPL[bus['type']]['cnt']
            BUS_TMPL[bus['type']]['cnt'] += vlen
            portprefix = bus['portprefix']
            netprefix = bus['netprefix']
            busstr += BUS_TMPL[bus['type']]['template'].format(
                portprefix=portprefix, netprefix=netprefix,
                n=vlen*(n+1), m=vlen*n)

    return busstr

def format_param_str(parameters):
    """
    Take a single block parameter dictionary and format as a verilog string
    """
    paramstr = ""
    if parameters:
        paramstrlist = []
        for key in parameters.keys():
            value = ""
            if not (parameters[key] is None):
                value = parameters[key]
            currstr = "  .%s(%s)" % (key, value)
            paramstrlist.append(currstr)
        paramstr = "#(\n%s)\n" % (",\n".join(paramstrlist))
    return paramstr

def format_port_str(ports):
    """
    Take a single dictionary and format as a verilog string representing extra block ports
    """
    portstr = ""
    if ports:
        portstrlist = []
        for key in ports.keys():
            value = ""
            if not (ports[key] is None):
                value = ports[key]
            currstr = ".%s(%s)" % (key, value)
            portstrlist.append(currstr)
        portstr = "\n  %s," % (",\n  ".join(portstrlist))
    return portstr

def create_vfiles(blocks, max_num_blocks):
    """
    Returns the verilogs
    """
    if len(blocks) == 0:
        print("[GEN_RFNOC_INST ERROR] No blocks specified!")
        exit(1)
    if len(blocks) > max_num_blocks:
        print("[GEN_RFNOC_INST ERROR] Trying to connect {} blocks, max is {}".\
                format(len(blocks), max_num_blocks))
        exit(1)
    vfile = HEADER_TMPL.format(num_ce=len(blocks))
    blocks_in_blacklist = [block for block in blocks if block['block'] in BLACKLIST]
    if len(blocks_in_blacklist):
        print("[RFNoC ERROR]: The following blocks require special treatment and"\
                " can't be instantiated with this tool:  ")
        for element in blocks_in_blacklist:
            print(" * ", element)
        print("Remove them from the command and run the uhd_image_builder.py again.")
        exit(1)
    print("--Using the following blocks to generate image:")
    block_count={}
    for block in blocks:
        block_count[block['block']] = 0
    for i, block in enumerate(blocks):
        block_count[block['block']] += 1
        instname = "inst_{}{}".format(block['block'], "" \
                if block_count[block['block']] == 1 else block_count[block['block']])
        print("    * {}".format(block['block']))
        vfile += BLOCK_TMPL.format(blockname=block['hdlname'],
                                   blockparameters=format_param_str(block['parameters']),
                                   instname=instname,
                                   n=i,
                                   clock=block["clock"],
                                   reset=block["reset"],
                                   gpio=format_port_str(block['gpio']),
                                   buses=format_bus_str(block['buses']),
                                   ports=format_port_str(block['ports']))
    return vfile

def file_generator(args, vfile):
    """
    Takes the target device as an argument and, if no '-o' directive is given,
    replaces the auto_ce file in the corresponding top folder. With the
    presence of -o, it just generates a version of the verilog file which
    is  not intended to be build
    """
    fpga_utils_path = get_scriptpath()
    print("Adding CE instantiation file for '%s'" % args.target)
    path_to_file = fpga_utils_path +'/../../top/' + device_dict(args.device.lower()) +\
            '/rfnoc_ce_auto_inst_' + args.device.lower() + '.v'
    if args.outfile is None:
        open(path_to_file, 'w').write(vfile)
    else:
        open(args.outfile, 'w').write(vfile)

def append_re_line_sequence(filename, linepattern, newline):
    """ Detects the re 'linepattern' in the file. After its last occurrence,
    paste 'newline'. If the pattern does not exist, append the new line
    to the file. Then, write. If the newline already exists, leaves the file
    unchanged"""
    oldfile = open(filename, 'r').read()
    lines = re.findall(newline, oldfile, flags=re.MULTILINE)
    if len(lines) != 0:
        pass
    else:
        pattern_lines = re.findall(linepattern, oldfile, flags=re.MULTILINE)
        if len(pattern_lines) == 0:
            open(filename, 'a').write(newline)
            return
        last_line = pattern_lines[-1]
        newfile = oldfile.replace(last_line, last_line + newline + '\n')
        open(filename, 'w').write(newfile)

def create_oot_include(device, include_dirs):
    """
    Create the include file for OOT RFNoC sources
    """
    oot_dir_list = []
    target_dir = device_dict(device.lower())
    dest_srcs_file = os.path.join(get_scriptpath(), '..', '..', 'top',\
            target_dir, 'Makefile.OOT.inc')
    incfile = open(dest_srcs_file, 'w')
    incfile.write(OOT_SRCS_FILE_HDR)
    if include_dirs is not None:
        for dirs in include_dirs:
            currpath = os.path.abspath(str(dirs))
            if os.path.isdir(currpath) & (os.path.basename(currpath) == "rfnoc"):
                # Case 1: Pointed directly to rfnoc directory
                oot_path = os.path.dirname(currpath)
            elif os.path.isdir(os.path.join(currpath, 'rfnoc')):
                # Case 2: Pointed to top level rfnoc module directory
                oot_path = currpath
            else:
                print('No RFNoC module found at ' + os.path.abspath(currpath))
                continue
            if (not oot_path in oot_dir_list):
                oot_dir_list.append(oot_path)
                named_path = os.path.join('$(BASE_DIR)', get_relative_path(get_basedir(), oot_path), 'rfnoc')
                incfile.write(OOT_DIR_TMPL.format(oot_dir=named_path))
                if os.path.isfile(os.path.join(oot_path, 'rfnoc', 'Makefile.inc')):
                    # Check for Makefile.inc
                    incfile.write(OOT_INC_TMPL)
                elif os.path.isfile(os.path.join(oot_path, 'rfnoc', 'fpga-src', 'Makefile.srcs')):
                    # Legacy: Check for fpga-src/Makefile.srcs
                    # Read, then append to file
                    curr_srcs = open(os.path.join(oot_path, 'rfnoc', 'fpga-src', 'Makefile.srcs'), 'r').read()
                    curr_srcs = curr_srcs.replace('SOURCES_PATH', os.path.join(oot_path, 'rfnoc', 'fpga-src', ''))
                    incfile.write(OOT_SRCS_TMPL.format(sources=curr_srcs))
                else:
                    print('No valid makefile found at ' + os.path.abspath(currpath))
                    continue
    incfile.close()

def append_item_into_file(device, include_dir):
    """
    Basically the same as append_re_line_sequence function, but it does not
    append anything when the input is not found
    ---
    Detects the re 'linepattern' in the file. After its last occurrence,
    pastes the input string. If pattern doesn't exist
    notifies and leaves the file unchanged
    """

    target_dir = device_dict(device.lower())
    if include_dir is not None:
        for directory in include_dir:
            dirs = os.path.join(directory, '')
            checkdir_v(dirs)
            oot_srcs_file = os.path.join(dirs, 'Makefile.srcs')
            dest_srcs_file = os.path.join(get_scriptpath(), '..', '..', 'top',\
                    target_dir, 'Makefile.srcs')
            oot_srcs_list = readfile(oot_srcs_file)
            oot_srcs_list = [w.replace('SOURCES_PATH', dirs) for w in oot_srcs_list]
            dest_srcs_list = readfile(dest_srcs_file)
            prefixpattern = re.escape('$(addprefix ' + dirs + ', \\\n')
            linepattern = re.escape('RFNOC_OOT_SRCS = \\\n')
            oldfile = open(dest_srcs_file, 'r').read()
            prefixlines = re.findall(prefixpattern, oldfile, flags=re.MULTILINE)
            if len(prefixlines) == 0:
                lines = re.findall(linepattern, oldfile, flags=re.MULTILINE)
                if len(lines) == 0:
                    print("Pattern {} not found. Could not write {} file".\
                            format(linepattern, oldfile))
                    return
                else:
                    last_line = lines[-1]
                    srcs = "".join(oot_srcs_list)
            else:
                last_line = prefixlines[-1]
                notin = []
                notin = [item for item in oot_srcs_list if item not in dest_srcs_list]
                srcs = "".join(notin)
            newfile = oldfile.replace(last_line, last_line + srcs)
            open(dest_srcs_file, 'w').write(newfile)

def compare(file1, file2):
    """
    compares two files line by line, and returns the lines of first file that
    were not found on the second. The returned is a tuple item that can be
    accessed in the form of a list as tuple[0], where each line takes a
    position on the list or in a string as tuple [1].
    """
    notinside = []
    with open(file1, 'r') as arg1:
        with open(file2, 'r') as arg2:
            text1 = arg1.readlines()
            text2 = arg2.readlines()
            for item in text1:
                if item not in text2:
                    notinside.append(item)
    return notinside

def readfile(files):
    """
    compares two files line by line, and returns the lines of first file that
    were not found on the second. The returned is a tuple item that can be
    accessed in the form of a list as tuple[0], where each line takes a
    position on the list or in a string as tuple [1].
    """
    contents = []
    with open(files, 'r') as arg:
        text = arg.readlines()
        for item in text:
            contents.append(item)
    return contents

def build(args):
    " build "
    cwd = get_scriptpath()
    target_dir = device_dict(args.device.lower())
    build_dir = os.path.join(cwd, '..', '..', 'top', target_dir)
    if os.path.isdir(build_dir):
        print("changing temporarily working directory to {0}".\
                format(build_dir))
        os.chdir(build_dir)
        make_cmd = ". ./setupenv.sh "
        if args.clean_all:
            make_cmd = make_cmd + "&& make cleanall "
        make_cmd = make_cmd + "&& make " + dtarget(args)
        if args.GUI:
            make_cmd = make_cmd + " GUI=1"
        # Wrap it into a bash call:
        make_cmd = '/bin/bash -c "{0}"'.format(make_cmd)
        ret_val = os.system(make_cmd)
        os.chdir(cwd)
    return ret_val

def device_dict(args):
    """
    helps selecting the device building folder based on the targeted device
    """
    build_dir = {
        'x300':'x300',
        'x310':'x300',
        'e300':'e300',
        'e310':'e300',
        'n300':'n3xx',
        'n310':'n3xx'
    }
    return build_dir[args]

def dtarget(args):
    """
    If no target specified,  selecs the default building target based on the
    targeted device
    """
    if args.target is None:
        default_trgt = {
            'x300':'X300_RFNOC_HG',
            'x310':'X310_RFNOC_HG',
            'e310':'E310_RFNOC_HLS',
            'n300':'N300_RFNOC_HG',
            'n310':'N310_RFNOC_HG'
        }
        return default_trgt[args.device.lower()]
    else:
        return args.target

def checkdir_v(include_dir):
    """
    Checks the existance of verilog files in the given include dir
    """
    nfiles = glob.glob(os.path.join(include_dir,'')+'*.v')
    if len(nfiles) == 0:
        print('[ERROR] No verilog files found in the given directory')
        exit(1)
    else:
        print('Verilog sources found!')
    return

def get_scriptpath():
    """
    returns the absolute path where a script is located
    """
    return os.path.dirname(os.path.realpath(__file__))

def get_basedir():
    """
    returns the base directory (BASE_DIR) used in rfnoc build process
    """
    return os.path.abspath(os.path.join(get_scriptpath(), '..', '..', 'top'))

def get_relative_path(base, target):
    """
    Find the relative path (including going "up" directories) from base to target
    """
    basedir = os.path.abspath(base)
    prefix = os.path.commonprefix([basedir, os.path.abspath(target)])
    path_tail = os.path.relpath(os.path.abspath(target), prefix)
    total_path = path_tail
    if prefix != "":
        while basedir != os.path.abspath(prefix):
            basedir = os.path.dirname(basedir)
            total_path = os.path.join('..', total_path)
        return total_path
    else:
        print ("Could not determine relative path")
        return path_tail


def create_blocklist(requested_blocks, available_blocks):
    """
    Create a list of block for instantiation from requested_blocks
    by checking against available_blocks loaded from noc script.
    The purpose is to use available_blocks to validate and fill
    in any missing parameters and io defined by blocks in
    requested_blocks. Block parameters in requested_blocks override
    the matching parameters in available_blocks.
    """
    blocklist=[]
    # Validate each requested block against the 'definition' block in available_blocks
    for req_block in requested_blocks:
        # Block noc script filenames are unique, so requested block should match an available block
        block_matches = [_block for _block in available_blocks if _block['block'] == req_block['block']]
        if len(block_matches) == 0:
            print('[ERROR] Requested block '+req_block["block"]+' missing corresponding noc script')
            print('Available blocks:')
            for block in available_blocks:
                print(block['block'])
            exit(1)
        elif len(block_matches) > 1:
            print('[ERROR] Requested block '+req_block["block"]+' has duplicate noc script')
            print('Duplicate files:')
            for block in available_blocks:
                print(block['xmlfile'])
            exit(1)
        else:
            avail_block = block_matches[0]

        # Merge req_block and avail_block params, give req_block precedence
        for param in req_block['parameters']:
            avail_block[param.key()] = req_block[param.key()]
        for port in req_block['ports']:
            avail_block[port.key()] = req_block['ports']
        blocklist.append(avail_block)

    return blocklist

def main():
    " Go, go, go! "
    args = setup_parser().parse_args()
    if args.yml:
        print("Using yml file. Ignoring command line blocks arguments")
        requested_blocks = parse_yml(args.yml)
    else:
        requested_blocks=[]
        for blockname in args.blocks:
            block = nocscript_parser.get_default_block_parameters()
            block["block"] = blockname
            requested_blocks.append(block)
    if args.fill_with_fifos:
        for i in range(len(requested_blocks), args.max_num_blocks):
            block = nocscript_parser.get_default_block_parameters()
            block["block"] = "fifo"
            requested_blocks.append(block)
    oot_nocscript = nocscript_parser.find(args.oot_include_dir)
    if (args.uhd_include_dir is not None):
        uhd_nocscript = nocscript_parser.find(args.uhd_include_dir)
    if len(uhd_nocscript) == 0:
        uhd_nocscript = nocscript_parser.find_default()
    if len(oot_nocscript) == 0 and len(uhd_nocscript) == 0:
        print("[ERROR] No nocscript xml files found!")
    nocscript_files = oot_nocscript + uhd_nocscript
    available_blocks = nocscript_parser.parse(nocscript_files)
    blocklist = create_blocklist(requested_blocks, available_blocks)
    vfile = create_vfiles(blocklist, args.max_num_blocks)
    file_generator(args, vfile)
    create_oot_include(args.device, args.oot_include_dir)
    if args.outfile is  None:
        return build(args)
    else:
        print("Instantiation file generated at {}".\
                format(args.outfile))
        return 0

if __name__ == "__main__":
    exit(main())
