# custom driver for I/O ports of bitstream computation circuit
# 2021-09-09 Naoki F., AIT
# New BSD license is applied. See COPYING for more details.

import numpy as np
import random

class BitPackInput():
    __value = 0.0
    __seed  = 0

    value = property()
    @value.setter
    def value(self, value):
        self.__value = ( 1.0 if (value >  1.0) else
                        -1.0 if (value < -1.0) else value)

    seed = property()
    @seed.setter
    def seed(self, value):
        self.__seed = value
    
    def asarray(self):
        uvalue = 0x100000000 if (self.__value < 0.0) else 0
        uvalue += self.__value * 0x7fffffff
        while(self.__seed == 0):
            self.__seed = random.getrandbits(32)
        return np.array([uvalue, self.__seed], dtype='u4')

class BitPackInputVector():
    def __init__(self, arg):
        if isinstance(arg, list):
            self.__ins = arg
        else:
            self.__ins = []
            for i in range(arg):
                self.__ins.append(BitPackInput())
    
    def __getitem__(self, key):
        if isinstance(key, slice):
            return BitPackInputVector(self.__ins[key])
        else:
            return self.__ins[key]

    values = property()
    @values.setter
    def values(self, values):
        for i in range(self.size()):
            self.__ins[i].value = values[i]

    def size(self):
        return len(self.__ins)
    
    def asarray(self):
        ary = np.empty(self.size() * 2, dtype='u4')
        for i in range(self.size()):
            ary[i*2:i*2+2] = self.__ins[i].asarray()
        return ary

class BitPackOutput():
    __value = 0.0

    @property
    def value(self):
        return self.__value
    
    def setfromcount(self, count, size):
        scount = count - 0x100000000 if ((count & 0x80000000) != 0) else count
        self.__value = scount / size

class BitPackOutputVector():
    def __init__(self, arg):
        if isinstance(arg, list):
            self.__outs = arg
        else:
            self.__outs = []
            for i in range(arg):
                self.__outs.append(BitPackOutput())
    
    def __getitem__(self, key):
        if isinstance(key, slice):
            return BitPackOutputVector(self.__outs[key])
        else:
            return self.__outs[key]

    @property
    def values(self):
        res = []
        for i in range(self.size()):
            res.append(self.__outs[i].value)
        return res

    def size(self):
        return len(self.__outs)

    def setfromcount(self, counts, cycle):
        for i in range(self.size()):
            self.__outs[i].setfromcount(counts[i], cycle)
