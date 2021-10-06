# code generator for bitstream computation package
# 2021-09-10 Naoki F., AIT
# New BSD license is applied. See COPYING for more details.

import os
import re
import sys
from pathlib import Path
from functools import reduce

###########################################################################################
# constants definition
template_dir = os.path.dirname(os.path.abspath(__file__)) + '/template/'
filenames = ['bitpack_lib.py', 'user_wrapper.sv']

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
        for signame, length, bipolar, pair in ports:
            newline = '{0}_{1} = {2}[{3}'.format(space, signame, vname, start)
            if length != 1:
                newline += ':{0}+1'.format(start + length - 1)
            newline += ']\n'
            out.append(newline)
            start += length

# BITPACK_IO_DEFINITIONS
def putiodef(out, space, inports, outports):
    for vname, ports in [['src', inports], ['dst', outports]]:
        out.append('{0}localparam {1}_size = {2};\n'.format(space, vname, portlen(ports)))
        newline = "{0}localparam {1}_mode = {2}'b".format(space, vname, portlen(ports) * 2)
        for signame, length, bipolar, pair in ports:
            bits = '01' if bipolar else '10' if pair is not None else '00'
            newline += bits * length
        newline += ';\n'
        out.append(newline)

# BITPACK_CIRCUIT_INSTANCE
def putbcinst(out, space, module, clock, reset, inports, outports):
    out.append('{0}{1} user (\n'.format(space, module))
    out.append('{0}    .{1}(CLK),\n'.format(space, clock))
    if reset is not None:
        out.append('{0}    .{1}(proc_en),\n'.format(space, reset))
    for vname, ports in [['src', inports], ['dst', outports]]:
        start = 0
        for signame, length, bipolar, pair in ports:
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

###########################################################################################
# main routine starts from here
if len(sys.argv) != 3:
    sys.stderr.write('usage: python3 bitpack_gen.py SOURCE_FILE OUTPUT_DIR\n')
    sys.exit(1)

print('## detecting input/output ports from source file')
module = None
clock = None
reset = None
inports = []
outports = []
with open(sys.argv[1]) as f:
    lines = f.readlines()
for line in lines:
    # find a module, input, or output definition
    # TODO: deal with multi-line comment with /* */
    line = re.sub('//.*','', line) 
    m = md_prog.search(line)
    if m is not None:
        module = m[1]
        continue
    m = io_prog.search(line)
    if m is None:
        continue

    # check the type of signal(s)
    direction = m[1]
    length    = 1 if m[3] is None else eval(m[4]) + 1
    name1     = m[5]
    name2     = m[7]
    signame   = name1
    bipolar   = False
    pair      = None
    print(" - detected {0} bit {1}put: {2}{3}".format(
        length, direction, name1,
        "" if name2 is None else " and " + name2))
    if length == 1 and direction == 'in':
        m_clk = re.search(r'cl(oc)?k', name1.lower())
        if m_clk is not None:
            clock = name1
            print("  - {0} is recognized as clock input".format(clock))
            m_rst = re.search(r're?se?t', name2.lower()) if name2 is not None else None
            if (m_rst is None) and (name2 is not None):
                print("  - {0} is ignored".format(name2))
        else:
            m_rst = re.search(r're?se?t', name1.lower())
        if m_rst is not None:
            reset = name1 if m_clk is None else name2
            print("  - {0} is recognized as reset input".format(reset))
            if (m_clk is None) and (name2 is not None):
                print("  - {0} is ignored".format(name2))
        if (m_clk is not None) or (m_rst is not None):
            continue
    if ((name2 is not None) and (name1[0:-2] == name2[0:-2]) and
        (name1.lower()[-2:] == '_p') and (name2.lower()[-2:] == '_m')):
        signame = name1[0:-2]
        pair = [name1, name2]
        print("  - {0} and {1} are recognized as a pair '{2}'".format(name1, name2, signame))
    elif name2 is not None:
        print("  - {0} is ignored".format(name2))
    if (name1.lower()[-2:] == '_b'):
        bipolar = True
        print("  - {0} is recognized as a bipolar port".format(name1))

    # append to the list of ports
    if direction == 'in':
        inports.append([signame, length, bipolar, pair])
    else:
        outports.append([signame, length, bipolar, pair])

# Check if the circuit is valid
print('')
if module is None:
    print("!! module is not detected. stop.")
    sys.exit(1)
if clock is None:
    print("!! clock input is not detected. stop.")
    sys.exit(1)

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
            putiodef(newlines, m[1], inports, outports)
        elif m[3] == 'CIRCUIT_INSTANCE':
            putbcinst(newlines, m[1], module, clock, reset, inports, outports)
        else:
            newlines.append(line)
            print("  ! unknown keyword BITPACK_{0}. skip.".format(m[3]))
    with open(dstname, 'w') as f:
        f.writelines(newlines)
