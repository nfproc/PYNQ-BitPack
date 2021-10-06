# template of custom driver for bitstream computation circuit
# 2021-09-10 Naoki F., AIT
# New BSD license is applied. See COPYING for more details.

import bitpack_lib_io as bpio
from pynq import DefaultIP
from pynq import allocate

class BitPackDriver(DefaultIP):
    def __init__(self, description):
        super().__init__(description=description)
    
    bindto = ['AIT:DSLab:bitpack_top:1.0']

    __cycle = 1024

    # instantiate I/O classes
    srcs = bpio.BitPackInputVector(6)
    _A = srcs[0:3+1]
    _SEL = srcs[4:5+1]
    dsts = bpio.BitPackOutputVector(2)
    _PROD = dsts[0]
    _AVG = dsts[1]
    
    cycle = property()
    @cycle.setter
    def cycle(self, value):
        self.__cycle = value
        
    def resetseeds(self):
        for src in self.srcs:
            src.seed = 0

    def start(self):
        # allocate the I/O buffers
        srcbuf = allocate(shape=(self.srcs.size() * 2), dtype='u4')
        dstbuf = allocate(shape=(self.dsts.size()), dtype='u4')

        # write to input buffer
        srcbuf[:] = self.srcs.asarray()

        # invoke the core
        self.write(4, srcbuf.device_address)
        self.write(8, dstbuf.device_address)
        self.write(12, self.__cycle)
        self.write(0, 1)
        while self.read(0) == 1:
            pass
        self.write(0, 0)
        while self.read(0) == 0:
            pass

        # read from output buffer
        self.dsts.setfromcount(dstbuf, self.__cycle)

        # deallocate the buffers
        srcbuf.freebuffer()
        dstbuf.freebuffer()
