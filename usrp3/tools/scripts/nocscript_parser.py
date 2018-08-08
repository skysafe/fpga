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


def find(include_dir):
    """
    Returns a list of noc block xml files
    """
    files = []
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

    if include_dir is None or len(include_dir) == 0:
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
    Returns a list of noc block xml files by looking at predefined paths
    """
    files = []
    search_paths = filter(None, (
        # Installed via PYBOMBS
        os.path.join(os.environ.get('PYBOMBS_PREFIX'), 'share', 'uhd', 'rfnoc', 'blocks', '*.xml')
        if os.environ.get('PYBOMBS_PREFIX') else None,
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


def etree_to_dict(tree):
    """
    Walk element tree converting to dictionary. Depending on structure of each
    element, element will be stored in dictionary as either a string, a list of strings,
    a dict, or a list of dicts.

    Note: In some cases, item should be tested if it is a list or not before accessing
    """
    """
    String case:
      <id>...</id>
      -> {'id': '...'}
    List of strings case:
      <id>...</id>
      <id>...</id>
      -> {'id': ['...', '...']}
    Dict case:
      <arg>
        <name>...</name>
        <value>...</value>
      </arg>
      -> {'arg': {'name': '...', 'value': '...'}}
    List of dicts case:
      <arg>
        <name>...</name>
        <value>...</value>
      </arg>
      <arg>
        <name>...</name>
        <value>...</value>
      </arg>
      -> {'arg': [{'name': '...', 'value': '...'}, {'name': '...', 'value': '...'}]}
    """
    d = {}
    tags_set = set([elem.tag for elem in tree.findall('*')])
    # For each unique element tag
    for tag in tags_set:
        elems = tree.findall(tag)
        # If element has sub-elements, recursively process sub-tree, i.e.:
        # <args>
        #   <arg>
        #   ...
        #   </arg>
        # </args>
        if len([elem for elem in elems if len(elem.findall('*'))]) > 0:
            # Use list to group multiple elements with same tag, i.e.:
            # <arg>
            # ...
            # </arg>
            # <arg>
            # ...
            # </arg>
            if len(elems) > 1:
                l = []
                for elem in elems:
                    l.append(etree_to_dict(elem))
                d[tag] = l
            else:
                d[tag] = etree_to_dict(elems[0])
        # i.e. <name>...</name>
        else:
            # Multiple elements with same tag, use a list
            if len(elems) > 1:
                l = []
                for elem in elems:
                    l.append(elem.text)
                d[tag] = l
            else:
                d[tag] = elems[0].text
    return d


def parse(xmlfiles):
    """
    Returns noc block dicts (organized by filename) by parsing
    nocscript xml files.
    Nocscript files are validated for the required elements using RelaxNG and
    that no duplicate nocscript files exist.
    """
    with open(NOCSCRIPT_RELAXNG_SCHEMA, 'r') as f:
        relaxng = lxml.etree.RelaxNG(file=f)

    noc_block_dicts = {}
    for xmlfile in xmlfiles:
        with open(xmlfile, 'r') as f:
            nocscript = lxml.objectify.fromstring(f.read())
            # Validate with relax ng
            try:
                relaxng.assert_(nocscript)
            except BaseException:
                print('[ERROR] Failed to parse '+xmlfile)
                print('Parser errors:')
                error_log = re.split('\n', str(relaxng.error_log))
                for line in error_log:
                    line_split = re.split(':', line)
                    print('  line {0}: {1}'.format(line_split[1], line_split[6]))
                raise AssertionError("Invalid nocscript")
            nocscript_name = os.path.splitext(os.path.basename(xmlfile))[0]
            noc_block_dict = etree_to_dict(nocscript)
            noc_block_dict['xmlfile'] = xmlfile
            noc_block_dict['block'] = nocscript_name
            # Error on duplicate nocscript files with different contents
            if nocscript_name in noc_block_dicts:
                for key in noc_block_dicts[nocscript_name]:
                    if key != 'xmlfile' and noc_block_dict[key] != noc_block_dicts[nocscript_name][key]:
                        print('[ERROR] Nocscript files cannot have the same name and different content:')
                        print('  Tag: {0}'.format(key))
                        print('  '+xmlfile)
                        print('  '+noc_block_dicts[nocscript_name]['xmlfile'])
                        raise AssertionError('Cannot have multiple nocscript files with ' +
                            'same name and different content')
            else:
                noc_block_dicts[nocscript_name] = noc_block_dict
    return noc_block_dicts
