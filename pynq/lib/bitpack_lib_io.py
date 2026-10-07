# custom driver for I/O ports of bitstream computation circuit
# 2022-12-12 Naoki F., AIT
# New BSD license is applied. See COPYING for more details.

import numpy as np

class BitPackInput():
    RANDOM = object() # special value: request a random value in asarray()
    __value = 0.0
    __random = False
    __seed  = 0
    __max   = 1.0
    __min   = 0.0
    __rng   = None

    def __init__(self, rng=None):
        self.__rng = rng

    def setrng(self, rng):
        self.__rng = rng

    def _getrand(self):
        if self.__rng is None:
            raise RuntimeError("no BitPackRandom instance is set; "
                               "pass it to the constructor or call setrng()")
        return self.__rng.next()

    value = property()
    @value.setter
    def value(self, value):
        if value is self.RANDOM:
            self.__random = True
        else:
            self.__random = False
            self.__value = ( self.__max if (value > self.__max) else
                             self.__min if (value < self.__min) else value)

    seed = property()
    @seed.setter
    def seed(self, value):
        self.__seed = value
    
    def setvaluerange(self, newmax, newmin):
        self.__max = newmax
        self.__min = newmin
        if self.__random:
            return # nothing to truncate for a random value
        self.value = self.__value # call the setter of value to truncate if needed
    
    def asarray(self):
        if self.__random:
            r = self._getrand()
            if self.__max > 0.0 and self.__min < 0.0:
                uvalue = r
            elif self.__max > 0.0 and self.__min == 0.0:
                uvalue = r & 0x7fffffff
            elif self.__max == 0.0 and self.__min < 0.0:
                uvalue = 0x80000000 | (r & 0x7fffffff)
            else:
                uvalue = 0
        elif self.__value >= 0.0:
            if self.__max == 0.0:
                uvalue = 0
            else:
                uvalue = self.__value / self.__max * 0x7fffffff
        else:
            if self.__min == 0.0:
                uvalue = 0
            else:
                uvalue = 0x100000000 + self.__value / (-self.__min) * 0x7fffffff
                 
        while(self.__seed == 0):
            self.__seed = self._getrand()
        return np.array([uvalue, self.__seed], dtype='u4')

class BitPackInputVector():
    def __init__(self, arg, rng=None):
        if isinstance(arg, list):
            self.__ins = arg
        else:
            self.__ins = []
            for i in range(arg):
                self.__ins.append(BitPackInput(rng))

    def setrng(self, rng):
        for i in range(self.size()):
            self.__ins[i].setrng(rng)
    
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
    
    def setvaluerange(self, newmax, newmin):
        for i in range(self.size()):
            self.__ins[i].setvaluerange(newmax, newmin)
    
    def asarray(self):
        ary = np.empty(self.size() * 2, dtype='u4')
        for i in range(self.size()):
            ary[i*2:i*2+2] = self.__ins[i].asarray()
        return ary

class BitPackOutput():
    __value = 0.0
    __max   = 1.0
    __min   = 0.0

    @property
    def value(self):
        return self.__value

    def setvaluerange(self, newmax, newmin):
        self.__max = newmax
        self.__min = newmin
    
    def setfromcount(self, count, size):
        if (count & 0x80000000) == 0:
            if self.__max == 0.0:
                self.__value = 0.0
            else:
                self.__value = count / size / self.__max
        else:
            self.__value = (count - 0x100000000) / size / (-self.__min)

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
    
    def setvaluerange(self, newmax, newmin):
        for i in range(self.size()):
            self.__outs[i].setvaluerange(newmax, newmin)

    def setfromcount(self, counts, cycle):
        for i in range(self.size()):
            self.__outs[i].setfromcount(counts[i], cycle)
