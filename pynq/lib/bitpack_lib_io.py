# custom driver for I/O ports of bitstream computation circuit
# 2026-10-09 Naoki F., AIT
# New BSD license is applied. See COPYING for more details.

import numpy as np

class BitPackInput():
    RANDOM = object() # special value: request a random value in asarray()
    __value = 0.0
    __random = False
    __seed  = 0
    __has_negative = False
    __denominator  = 1.0
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
            maxv = self.__denominator
            minv = -self.__denominator if self.__has_negative else 0.0
            self.__value = ( maxv if (value > maxv) else
                             minv if (value < minv) else value)

    seed = property()
    @seed.setter
    def seed(self, value):
        self.__seed = value

    def setvaluerange(self, arg1, arg2):
        if isinstance(arg1, bool):
            # new style: (has_negative, denominator)
            self.__has_negative = arg1
            self.__denominator  = arg2
        elif arg1 == 1.0 and arg2 == 0.0:
            # old style compatibility: (max, min) = (1.0, 0.0)
            self.__has_negative = False
            self.__denominator  = 1.0
        elif arg1 == 1.0 and arg2 == -1.0:
            # old style compatibility: (max, min) = (1.0, -1.0)
            self.__has_negative = True
            self.__denominator  = 1.0
        else:
            # neither new style nor old style: throw an exception
            raise ValueError(f"Unknown arguments for setvaluerange: ({arg1}, {arg2})")
        if self.__random:
            return # nothing to truncate for a random value
        self.value = self.__value # call the setter of value to truncate if needed

    def asarray(self):
        if self.__random:
            r = self._getrand()
            if self.__has_negative:
                uvalue = r
            else:
                uvalue = r & 0x7fffffff
        elif self.__value >= 0.0:
            uvalue = self.__value / self.__denominator * 0x7fffffff
        else:
            if self.__has_negative:
                uvalue = 0x100000000 + self.__value / self.__denominator * 0x80000000
            else:
                uvalue = 0

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

    def setvaluerange(self, arg1, arg2):
        for i in range(self.size()):
            self.__ins[i].setvaluerange(arg1, arg2)

    def asarray(self):
        ary = np.empty(self.size() * 2, dtype='u4')
        for i in range(self.size()):
            ary[i*2:i*2+2] = self.__ins[i].asarray()
        return ary

class BitPackOutput():
    __value = 0.0
    __has_negative = False
    __denominator  = 1.0

    @property
    def value(self):
        return self.__value

    def setvaluerange(self, arg1, arg2):
        if isinstance(arg1, bool):
            # new style: (has_negative, denominator)
            self.__has_negative = arg1
            self.__denominator  = arg2
        elif arg1 == 1.0 and arg2 == 0.0:
            # old style compatibility: (max, min) = (1.0, 0.0)
            self.__has_negative = False
            self.__denominator  = 1.0
        elif arg1 == 1.0 and arg2 == -1.0:
            # old style compatibility: (max, min) = (1.0, -1.0)
            self.__has_negative = True
            self.__denominator  = 1.0
        else:
            # neither new style nor old style: throw an exception
            raise ValueError(f"Unknown arguments for setvaluerange: ({arg1}, {arg2})")

    def setfromcount(self, count, size):
        if (count & 0x80000000) == 0:
            self.__value = count / size / self.__denominator
        else:
            self.__value = (count - 0x100000000) / size / self.__denominator

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

    def setvaluerange(self, arg1, arg2):
        for i in range(self.size()):
            self.__outs[i].setvaluerange(arg1, arg2)

    def setfromcount(self, counts, cycle):
        for i in range(self.size()):
            self.__outs[i].setfromcount(counts[i], cycle)
