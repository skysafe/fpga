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
import nocscript_parser
from auto_inst import auto_inst

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
        "-l", "--list",
        help="List available blocks",
        action="store_true")
    parser.add_argument(
        "--validate",
        help="Validate noc script files",
        action="store_true")
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


def create_vfiles(blocks, device):
    """
    Returns the verilogs
    """
    if len(blocks) == 0:
        print("[ERROR] No blocks specified!")
        exit(1)
    blocks_in_blacklist = [block for block in blocks if block['block'] in BLACKLIST]
    if len(blocks_in_blacklist):
        print("[ERROR] The following blocks require special treatment and"
              " can't be instantiated with this tool:  ")
        for element in blocks_in_blacklist:
            print(" * ", element)
        print("Remove them from the command and run the uhd_image_builder.py again.")
        exit(1)
    print("--Using the following blocks to generate image:")
    auto_inst_gen = auto_inst.auto_inst(device)
    for block in blocks:
        print("    * {}".format(block['block']))
        auto_inst_gen.add_noc_block(block)
    vfile = auto_inst_gen.to_verilog()
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
    path_to_file = fpga_utils_path + '/../../top/' + device_dict(args.device.lower()) +\
        '/rfnoc_ce_auto_inst_' + args.device.lower() + '.v'
    if args.outfile is None:
        open(path_to_file, 'w').write(vfile)
    else:
        open(args.outfile, 'w').write(vfile)


def create_oot_include(device, include_dirs):
    """
    Create the include file for OOT RFNoC sources
    """
    oot_dir_list = []
    target_dir = device_dict(device.lower())
    dest_srcs_file = os.path.join(get_scriptpath(), '..', '..', 'top',
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
            if (oot_path not in oot_dir_list):
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
            dest_srcs_file = os.path.join(get_scriptpath(), '..', '..', 'top',
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
                    print("Pattern {} not found. Could not write {} file".format(linepattern, oldfile))
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
        print("changing temporarily working directory to {0}".format(build_dir))
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
    nfiles = glob.glob(os.path.join(include_dir, '')+'*.v')
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


def print_available_blocks(nocblocks):
    print('Available blocks:')
    for block in sorted(nocblocks):
        print('  '+block)


def create_blocklist(requested_blocks, available_blocks):
    """
    Create a list of blocks for instantiation from list of block names
    (requested_blocks) by checking against available_blocks loaded from noc script.
    """
    blocklist = []
    # Validate each requested block against the 'definition' block in available_blocks
    for blockname in requested_blocks:
        # Block noc script filenames are unique, so requested block should match an available block
        if blockname not in available_blocks.keys():
            print('[ERROR] Requested block '+blockname+' missing corresponding nocscript')
            print_available_blocks(available_blocks)
            exit(1)
        blocklist.append(available_blocks[blockname])
    return blocklist


def main():
    " Go, go, go! "
    args = setup_parser().parse_args()
    device = args.device.lower()
    # Load nocscript
    if args.oot_include_dir is not None:
        oot_nocscript_files = nocscript_parser.find(args.oot_include_dir)
    else:
        oot_nocscript_files = []
    if (args.uhd_include_dir is not None):
        uhd_nocscript_files = nocscript_parser.find(args.uhd_include_dir)
    else:
        uhd_nocscript_files = nocscript_parser.find_default()
    if len(oot_nocscript_files) == 0 and len(uhd_nocscript_files) == 0:
        print("[ERROR] No nocscript xml files found")
        exit(1)
    available_blocks = nocscript_parser.parse(oot_nocscript_files + uhd_nocscript_files)
    # Only validate nocscript
    if args.validate:
        print("No nocscript errors found")
        return
    # Only list available blocks
    if args.list:
        print_available_blocks(available_blocks)
        return
    # Requested blocks from args
    requested_blocks = []
    for blockname in args.blocks:
        requested_blocks.append(blockname)
    if (len(requested_blocks) > args.max_num_blocks):
        print("[ERROR] Requested {0} blocks, but specified max of {1} blocks".format(
            len(requested_blocks), args.max_num_blocks))
    # If space left for extra blocks, fill with FIFOs
    if args.fill_with_fifos:
        for _ in range(len(requested_blocks), args.max_num_blocks):
            requested_blocks.append("fifo")
    blocklist = create_blocklist(requested_blocks, available_blocks)
    vfile = create_vfiles(blocklist, device)
    file_generator(args, vfile)
    create_oot_include(device, args.oot_include_dir)
    if args.outfile is None:
        return build(args)
    else:
        print("Instantiation file generated at {}".format(args.outfile))
        return


if __name__ == "__main__":
    exit(main())
