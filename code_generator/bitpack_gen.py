# code generator for bitstream computation package
# v0.2.2, 2023-10-12 Naoki F., AIT
# New BSD license is applied. See COPYING for more details.

import os
import re
import sys
import json
from pathlib import Path
from functools import reduce

###########################################################################################
# constants definition
template_dir = os.path.dirname(os.path.abspath(__file__)) + '/template/'
modes_file = os.path.dirname(os.path.abspath(__file__)) + '/mode_definition.json'
filenames = ['bitpack_lib.py', 'user_wrapper.sv', 'sn_gen.sv', 'count.sv']

md_pattern =  r'module\s+(\w+)'
md_prog = re.compile(md_pattern)
io_pattern =  r'(?a)(in|out)put\s+(logic|reg|wire)?\s*' # [1] in/out [2] type
io_pattern += r'(\[([\(\)\+\-\*0-9]+):0\])?\s*'         # [3] vector? [4] upper
io_pattern += r'(\w+)(\s*,\s*(\w+))?'                   # [5] name1 [7] name2
io_prog = re.compile(io_pattern)
bp_pattern =  r'(\s+)(#|//)\s*BITPACK_([A-Z_]+)'
bp_prog = re.compile(bp_pattern)

###########################################################################################
# function definitions for code generation
def portlen(ports):
    return reduce(lambda x, y: x + y, map(lambda x: x[1], ports))

# BITPACK_IO_INSTANCES
def putioinst(out, space, inports, outports):
    for vname, cname, ports in [['srcs', 'Input', inports], ['dsts', 'Output', outports]]:
        cname = 'bpio.BitPack' + cname + 'Vector'
        out.append('{0}{1} = {2}({3})\n'.format(space, vname, cname, portlen(ports)))
        start = 0
        for signame, length, moderef, pair in ports:
            newline = '{0}_{1} = {2}[{3}'.format(space, signame, vname, start)
            if length != 1:
                newline += ':{0}+1'.format(start + length - 1)
            newline += ']\n'
            out.append(newline)
            maxv = moderef['maximum']
            minv = moderef['minimum']
            newline = '{0}_{1}.setvaluerange({2}, {3})\n'.format(space, signame, maxv, minv)
            out.append(newline)
            start += length

# BITPACK_IO_DEFINITIONS
def putiodef(out, space, inports, outports, nummodes):
    modelen = len(bin(nummodes)) - 2 # omit "0b" prefix
    bitfmt = '{{0:0{0}b}}'.format(modelen)
    for vname, ports in [['src', inports], ['dst', outports]]:
        out.append('{0}localparam {1}_size = {2};\n'.format(space, vname, portlen(ports)))
        newline = "{0}localparam {1}_mode = {2}'b".format(space, vname, portlen(ports) * modelen)
        modestr = ""
        for signame, length, moderef, pair in ports:
            bits = bitfmt.format(moderef['id'])
            modestr = (bits * length) + modestr
        newline += modestr + ';\n'
        out.append(newline)
    out.append("{0}localparam mode_len = {1};\n".format(space, modelen))

# BITPACK_CIRCUIT_INSTANCE
def putbcinst(out, space, module, clock, reset, inports, outports):
    out.append('{0}{1} user (\n'.format(space, module))
    out.append('{0}    .{1}(CLK),\n'.format(space, clock))
    if reset is not None:
        out.append('{0}    .{1}(proc_en),\n'.format(space, reset))
    for vname, ports in [['src', inports], ['dst', outports]]:
        start = 0
        for signame, length, moderef, pair in ports:
            if length == 1:
                vslice = '[{0}]'.format(start)
            else:
                vslice = '[{0}:{1}]'.format(start + length - 1, start)
            if pair is not None:
                out.append('{0}    .{1}({2}_sn_p{3}),\n'.format(space, pair[0], vname, vslice))
                out.append('{0}    .{1}({2}_sn_n{3}),\n'.format(space, pair[1], vname, vslice))
            else:
                out.append('{0}    .{1}({2}_sn_p{3}),\n'.format(space, signame, vname, vslice))
            start += length
    out[-1] = out[-1][0:-2] + ');\n'

# MODE_PARAMETER
def putmodeparam(out, space, nummodes):
    modelen = len(bin(nummodes)) - 2 # omit "0b" prefix
    out.append("{0}parameter [{1}:0] MODE = {2}'d0;\n".format(space, modelen - 1, modelen))

# GENERATOR_DEFINITIONS, COUNTER_DEFINITIONS
def putgendef(out, space, nummodes, modes, genmode):
    modelen = len(bin(nummodes)) - 2 # omit "0b" prefix
    ifrequired = (modelen != 1)
    ifindent = "    " if ifrequired else ""
    for mode in modes:
        if not mode['used']:
            continue
        ifclause = ''
        if mode['id'] != 0:
            ifclause += 'end else '
        if mode['id'] != nummodes - 1:
            ifclause += "if (MODE == {0}'d{1}) ".format(modelen, mode['id'])
        if ifrequired:
            out.append(space + ifclause + 'begin\n')
        for l in mode[genmode]:
            out.append('{0}{1}{2}\n'.format(space, ifindent, l))
    if ifrequired:
        out.append('{0}end\n'.format(space))

###########################################################################################
# function definition for parse a line of SystemVerilog file of SC circuit
# TODO: deal with multi-line comment with /* */
def parseline(line):
    line = re.sub('//.*','', line) 
    m = md_prog.search(line)

    # check if the line is module definition
    if m is not None:
        return 'module', m[1]
    
    # check if the line is NOT port definition
    m = io_prog.search(line)
    if m is None:
        return 'none', None

    # rename the results of regex search
    direction = m[1]
    length    = 1 if m[3] is None else eval(m[4]) + 1
    name1     = m[5]
    name2     = m[7]
    signame   = name1
    moderef   = None
    print(" - detected {0} bit {1}put: {2}{3}".format(
        length, direction, name1, "" if name2 is None else " and " + name2))
    
    # check if the detected signal is clock or reset
    if length == 1 and direction == 'in':
        m_clk = re.search(r'cl(oc)?k', name1.lower())
        if m_clk is not None:
            print("  - {0} is recognized as clock input".format(name1))
            m_rst = re.search(r're?se?t', name2.lower()) if name2 is not None else None
            if m_rst is None:
                if name2 is not None:
                    print("  - {0} is ignored".format(name2))
                return 'clock', [name1, None]
            else:
                print("  - {0} is recognized as reset input".format(name2))
                return 'clock', [name1, name2]
        m_rst = re.search(r're?se?t', name1.lower())
        if m_rst is not None:
            print("  - {0} is recognized as reset input".format(name1))
            if (m_clk is None) and (name2 is not None):
                print("  - {0} is ignored".format(name2))
            return 'reset', name1
        
    # determine the mode of signal(s)
    for mode in modes:
        pf = mode['postfix']
        if mode['default']:
            moderef = mode
        elif name1.lower().endswith(pf[0]):
            if len(pf) == 1:
                moderef = mode
            elif (name1[0:-len(pf[0])] == name2[0:-len(pf[1])] and
                  name2.lower().endswith(pf[1])):
                moderef = mode
    if moderef is None:
        print("  - {0} is ignored because the signal type is unknown".format(signame))
        return 'none', None

    # pack the information required for code generation
    moderef['used'] = True
    if len(moderef['postfix']) == 2:
        signame = name1[0:-len(moderef['postfix'][0])]
        print("  - {0} and {1} are recognized as a pair of {2} signals '{3}'".format(
            name1, name2, moderef['name'], signame))
        return direction, [signame, length, moderef, [name1, name2]]
    else:
        print("  - {0} is recognized as {1} signal".format(signame, moderef['name']))
        if name2 is not None:
            print("  - {0} is ignored".format(name2))
        return direction, [signame, length, moderef, None]

###########################################################################################
# main routine starts from here
if len(sys.argv) != 3:
    sys.stderr.write('usage: python3 bitpack_gen.py SOURCE_FILE OUTPUT_DIR\n')
    sys.exit(1)

with open(modes_file) as f:
    modes = json.load(f)
for mode in modes:
    mode["used"] = False

# Parse a source SystemVerilog file
print('## detecting input/output ports from source file')
module = None
clock = None
reset = None
inports = []
outports = []
with open(sys.argv[1]) as f:
    lines = f.readlines()
for line in lines:
    direction, port = parseline(line)
    if direction == 'module':
        module = port
    elif direction == 'clock':
        clock = port[0]
        if port[1] is not None:
            reset = port[1]
    elif direction == 'reset':
        reset = port
    elif direction == 'in':
        inports.append(port)
    elif direction == 'out':
        outports.append(port)

# Check if the circuit is valid
print('')
if module is None:
    print("!! module is not detected. stop.")
    sys.exit(1)
if clock is None:
    print("!! clock input is not detected. stop.")
    sys.exit(1)

# Assign mode ID for each of used modes
nummodes = 0
for mode in modes:
    if mode['used']:
        mode['id'] = nummodes
        nummodes += 1

# Generate codes
Path(sys.argv[2]).mkdir(exist_ok=True)
for filename in filenames:
    srcname = template_dir + filename
    dstname = sys.argv[2] + '/' + filename
    print("## generating " + dstname)
    with open(srcname) as f:
        lines = f.readlines()
    newlines = []
    for line in lines:
        m = bp_prog.match(line)
        if m is None:
            newlines.append(line)
            continue
        if m[3] == 'IO_INSTANCES':
            putioinst(newlines, m[1], inports, outports)
        elif m[3] == 'IO_DEFINITIONS':
            putiodef(newlines, m[1], inports, outports, nummodes)
        elif m[3] == 'CIRCUIT_INSTANCE':
            putbcinst(newlines, m[1], module, clock, reset, inports, outports)
        elif m[3] == 'MODE_PARAMETER':
            putmodeparam(newlines, m[1], nummodes)
        elif m[3] == 'GENERATOR_DEFINITIONS':
            putgendef(newlines, m[1], nummodes, modes, 'generator')
        elif m[3] == 'COUNTER_DEFINITIONS':
            putgendef(newlines, m[1], nummodes, modes, 'counter')
        else:
            newlines.append(line)
            print("  ! unknown keyword BITPACK_{0}. skip.".format(m[3]))
    with open(dstname, 'w') as f:
        f.writelines(newlines)
