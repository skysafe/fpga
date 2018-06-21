#!/usr/bin/python3
#
# Copyright 2018 Ettus Research, a National Instruments Company
#
# SPDX-License-Identifier: LGPL-3.0-or-later
#

import argparse
import os
import sys
import subprocess
import logging
import re
import io
import time
import datetime
from queue import Queue
from threading import Thread

#-------------------------------------------------------
# Utilities
#-------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
BASE_DIR = os.path.split(os.path.split(SCRIPT_DIR)[0])[0]

_LOG = logging.getLogger(os.path.basename(__file__))
_LOG.setLevel(logging.INFO)
_STDOUT = logging.StreamHandler()
_LOG.addHandler(_STDOUT)
_FORMATTER = logging.Formatter('[%(name)s] - %(levelname)s - %(message)s')
_STDOUT.setFormatter(_FORMATTER)

RETCODE_SUCCESS     = 0
RETCODE_PARSE_ERR   = -1
RETCODE_EXEC_ERR    = -2
RETCODE_COMPILE_ERR = -3
RETCODE_UNKNOWN_ERR = -4

def retcode_to_str(code):
    """ Convert internal status code to string
    """
    code = int(code)
    if code > RETCODE_SUCCESS:
        return 'AppError({code})'.format(code=code)
    else:
        return {RETCODE_SUCCESS:'OK',
            RETCODE_PARSE_ERR:'ParseError', 
            RETCODE_EXEC_ERR:'ExecError', 
            RETCODE_COMPILE_ERR:'CompileError', 
            RETCODE_UNKNOWN_ERR:'UnknownError'
        }[code]

def log_with_header(what, minlen = 0, ch = '#'):
    """ Print with a header around the text
    """
    padlen = max(int((minlen - len(what))/2), 1) 
    toprint = (' '*padlen) + what + (' '*padlen)
    _LOG.info(ch * len(toprint))
    _LOG.info(toprint)
    _LOG.info(ch * len(toprint))

#-------------------------------------------------------
# Simulation Functions
#-------------------------------------------------------

def find_sims_on_fs(basedir):
    """ Find all testbenches in the specific basedir
        Testbenches are defined as directories with a
        Makefile that includes viv_sim_preamble.mak
    """
    sims = {}
    for root, _, files in os.walk(basedir):
        if 'Makefile' in files:
            with open(os.path.join(root, 'Makefile'), 'r') as mfile:
                for l in mfile.readlines():
                    if re.match('.*include.*viv_sim_preamble.mak.*', l) is not None:
                        sims.update({os.path.relpath(root, basedir): root})
                        break
    return sims

def gather_target_sims(basedir, targets):
    """ Parse the specified targets and gather simulations to run
        Remove duplicates and sort alphabetically
    """
    fs_sims = find_sims_on_fs(basedir)
    if not isinstance(targets, list):
        targets = [targets]
    sim_names = set()
    for target in targets:
        for name in sorted(fs_sims):
            if re.match(target, name) is not None:
                sim_names.add(name)
    target_sims = []
    for name in sorted(sim_names):
        target_sims.append((name, fs_sims[name]))
    return target_sims

def parse_output(simout):
    # Gather results (basic metrics)
    results = {'retcode':RETCODE_SUCCESS, 'stdout':simout, 'passed':False}
    # Look for the following in the log:
    # - A start timestamp (indicates that Vivado started)
    # - The testbench infrastructure start header (indicates that the TB started)
    # - A stop timestamp (indicates that the TB stopped)
    tb_started = False
    compile_started = False
    results['start_time'] = '<unknown>'
    results['wall_time'] = '<unknown>'
    for line in simout.split(b'\n'):
        tsm = re.match(rb'TESTBENCH STARTED: (.+)', line)
        if tsm is not None:
            tb_started = True
        csm = re.match(rb'source .*viv_sim_project.tcl', line)
        if csm is not None:
            compile_started = True
        vsm = re.match(rb'# Start of session at: (.+)', line)
        if vsm is not None:
            results['start_time'] = str(vsm.group(1), 'ascii')
        tfm = re.match(rb'launch_simulation:.*; elapsed = (.+) \..*', line)
        if tfm is not None:
            results['wall_time'] = str(tfm.group(1), 'ascii')
    # Parse testbench results
    tb_match_arr = ([
        b'.*TESTBENCH FINISHED: (.+)\n',
        b' - Time elapsed:   (.+) ns.*\n',
        b' - Tests Expected: (.+)\n',
        b' - Tests Run:      (.+)\n',
        b' - Tests Passed:   (.+)\n',
        b'Result: (PASSED|FAILED).*',
    ])
    m = re.match(b''.join(tb_match_arr), simout, re.DOTALL)
    # Figure out the returncode 
    retcode = RETCODE_UNKNOWN_ERR
    if m is not None:
        retcode = RETCODE_SUCCESS
        results['passed'] = (m.group(6) == b'PASSED')
        results['module'] = m.group(1)
        results['sim_time_ns'] = int(m.group(2))
        results['tc_expected'] = int(m.group(3))
        results['tc_run'] = int(m.group(4))
        results['tc_passed'] = int(m.group(5))
    elif tb_started:
        retcode = RETCODE_PARSE_ERR
    elif compile_started:
        retcode = RETCODE_COMPILE_ERR
    else:
        retcode = RETCODE_EXEC_ERR
    results['retcode'] = retcode
    return results

def run_sim(path, simulator, basedir, setupenv):
    """ Run the simulation at the specified path
        The simulator can be specified as the target
        A environment script can be run optionally
    """
    try:
        # Optionally run an environment setup script
        if setupenv is None:
            setupenv = ''
            # Check if environment was setup
            if 'VIVADO_PATH' not in os.environ:
                raise RuntimeError('Simulation environment was uninitialized') 
        else:
            setupenv = '. ' + os.path.realpath(setupenv) + ';'
        # Run the simulation
        return parse_output(
            subprocess.check_output(
                'cd {workingdir}; {setupenv} make {simulator} 2>&1'.format(
                    workingdir=os.path.join(basedir, path), setupenv=setupenv, simulator=simulator), shell=True))
    except subprocess.CalledProcessError as e:
        return {'retcode': int(abs(e.returncode)), 'passed':False, 'stdout':e.output}
    except Exception as e:
        _LOG.error('Target ' + path + ' failed to run:\n' + str(e))
        return {'retcode': RETCODE_EXEC_ERR, 'passed':False, 'stdout':bytes(str(e), 'utf-8')}
    except:
        _LOG.error('Target ' + path + ' failed to run')
        return {'retcode': RETCODE_UNKNOWN_ERR, 'passed':False, 'stdout':bytes('Unknown Exception', 'utf-8')}

def run_sim_queue(run_queue, out_queue, simulator, basedir, setupenv):
    """ Thread worker for a simulation runner
        Pull a job from the run queue, run the sim, then place
        output in out_queue
    """
    while not run_queue.empty():
        (name, path) = run_queue.get()
        try:
            _LOG.info('Starting: %s', name)
            result = run_sim(path, simulator, basedir, setupenv)
            out_queue.put((name, result))
            _LOG.info('FINISHED: %s (%s, %s)', name, retcode_to_str(result['retcode']), 'PASS' if result['passed'] else 'FAIL!')
        except KeyboardInterrupt:
            _LOG.warning('Target ' + name + ' received SIGINT. Aborting...')
            out_queue.put((name, {'retcode': RETCODE_EXEC_ERR, 'passed':False, 'stdout':bytes('Aborted by user', 'utf-8')}))
        except Exception as e:
            _LOG.error('Target ' + name + ' failed to run:\n' + str(e))
            out_queue.put((name, {'retcode': RETCODE_UNKNOWN_ERR, 'passed':False, 'stdout':bytes(str(e), 'utf-8')}))
        finally:
            run_queue.task_done()

#-------------------------------------------------------
# Script Actions
#-------------------------------------------------------

def do_list(args):
    """ List all simulations that can be run
    """
    for (name, path) in gather_target_sims(args.basedir, args.target):
        print(name)
    return 0

def do_run(args):
    """ Build a simulation queue based on the specified
        args and process it
    """
    run_queue = Queue(maxsize=0)
    out_queue = Queue(maxsize=0)
    _LOG.info('Queueing the following targets to simulate:')
    for (name, path) in gather_target_sims(args.basedir, args.target):
        run_queue.put((name, path))
        _LOG.info('* ' + name)
    # Spawn tasks to run builds
    num_sims = run_queue.qsize()
    num_jobs = min(num_sims, int(args.jobs))
    _LOG.info('Started ' + str(num_jobs) + ' job(s) to process queue...')
    results = {}
    for i in range(num_jobs):
        worker = Thread(target=run_sim_queue, args=(run_queue, out_queue, args.simulator, args.basedir, args.setupenv))
        worker.setDaemon(False)
        worker.start()
    # Wait for build queue to become empty
    start = datetime.datetime.now()
    try:
        while out_queue.qsize() < num_sims:
            tdiff = str(datetime.datetime.now() - start).split('.', 2)[0]
            print("\r>>> [%s] (%d/%d simulations completed) <<<" % (tdiff, out_queue.qsize(), num_sims), end='\r', flush=True)
            time.sleep(1.0)
        sys.stdout.write("\n")
    except (KeyboardInterrupt):
        _LOG.info('Received SIGINT. Aborting...')
        raise SystemExit(1)

    results = {}
    result_all = 0
    while not out_queue.empty():
        (name, result) = out_queue.get()
        results[name] = result
        log_with_header(name)
        sys.stdout.buffer.write(result['stdout'])
        if not result['passed']:
            result_all += 1

    summary_line = 'SUMMARY: %d/%d tests failed. Time elapsed was %s'%(
        result_all, num_sims, str(datetime.datetime.now() - start).split('.', 2)[0])
    log_with_header('RESULTS', len(summary_line))
    for name in results:
        r = results[name]
        if 'module' in r:
            _LOG.info('* %s : %s (Expected=%d, Run=%d, Passed=%d, Elapsed=%s)',
                ('PASS' if r['passed'] else 'FAIL'), name, r['tc_expected'], r['tc_run'], r['tc_passed'], r['wall_time'])
        else:
            _LOG.info('* %s : %s (Status=%s)', ('PASS' if r['passed'] else 'FAIL'), 
                name, retcode_to_str(r['retcode']))
    _LOG.info('#'*len(summary_line))
    _LOG.info(summary_line)   
    return result_all


def do_cleanup(args):
    """ Run make cleanall for all simulations
    """
    setupenv = args.setupenv
    if setupenv is None:
        setupenv = ''
        # Check if environment was setup
        if 'VIVADO_PATH' not in os.environ:
            raise RuntimeError('Simulation environment was uninitialized') 
    else:
        setupenv = '. ' + os.path.realpath(setupenv) + ';'
    for (name, path) in gather_target_sims(args.basedir, args.target):
        _LOG.info('Cleaning up %s', name)
        os.chdir(os.path.join(args.basedir, path))
        subprocess.Popen('{setupenv} make cleanall'.format(setupenv=setupenv), shell=True).wait()
    return 0

def do_report(args):
    """ List all simulations that can be run
    """
    keys = ['module', 'status', 'retcode', 'start_time', 'wall_time',
            'sim_time_ns', 'tc_expected', 'tc_run', 'tc_passed']
    with open(args.repfile, 'w') as repfile:
        repfile.write((','.join([x.upper() for x in keys])) + '\n')
        for (name, path) in gather_target_sims(args.basedir, args.target):
            results = {'module': str(name), 'status':'NOT_RUN', 'retcode':'<unknown>', 
                       'start_time':'<unknown>', 'wall_time':'<unknown>', 'sim_time_ns':0,
                       'tc_expected':0, 'tc_run':0, 'tc_passed':0}
            logpath = os.path.join(path, args.simulator + '.log')
            if os.path.isfile(logpath):
                with open(logpath, 'rb') as logfile:
                    r = parse_output(logfile.read())
                    if r['retcode'] != RETCODE_SUCCESS:
                        results['retcode'] = retcode_to_str(r['retcode'])
                        results['status'] = 'ERROR'
                        results['start_time'] = r['start_time']
                    else:
                        results = r
                        results['module'] = name
                        results['status'] = 'PASSED' if r['passed'] else 'FAILED'
                        results['retcode'] = retcode_to_str(r['retcode'])
            repfile.write((','.join([str(results[x]) for x in keys])) + '\n')
    _LOG.info('Testbench report written to ' + args.repfile)
    return 0

# Parse command line options
def get_options():
    parser = argparse.ArgumentParser(description='Batch testbench execution script')
    parser.add_argument('--basedir', default=BASE_DIR, help='Base directory for the usrp3 codebase')
    parser.add_argument('--simulator', choices=['xsim', 'vsim'], default='xsim', help='Simulator name')
    parser.add_argument('--setupenv', default=None, help='Optional environment setup script to run for each TB')
    parser.add_argument('-j', '--jobs', default=1, help='Number of parallel simulation jobs to run')
    parser.add_argument('--repfile', default='testbench_report.csv', help='Name of the output report file')
    parser.add_argument('action', choices=['run', 'cleanup', 'list', 'report'], default='list', help='What to do?')
    parser.add_argument('target', nargs='*', default='.*', help='Space separated simulation target regexes')
    return parser.parse_args()

def main():
    args = get_options()
    actions = {'list': do_list, 'run': do_run, 'cleanup': do_cleanup, 'report': do_report}
    return actions[args.action](args)

if __name__ == '__main__':
    exit(main())
