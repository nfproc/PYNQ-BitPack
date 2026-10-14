# custom driver for I/O ports of bitstream computation circuit
# 2026-10-14 Naoki F., AIT
# New BSD license is applied. See COPYING for more details.

"""bitpack_lib_io.py

Provides interfaces for input and output ports of the target stochastic computing circuit.
The library consists of four classes:
- BitPackInput:        single-bit input
- BitPackInputVector:  multiple-bit input
- BitPackOutput:       single-bit output
- BitPackOutputVector: multple-bit output
"""

import numpy as np

class BitPackInput():
    """Interface for an input port of single bit of the target circuit."""

    RANDOM = object() # special value: request a random value in asarray()
    __value = 0.0
    __uvalue = None
    __random = False
    __seed  = 0
    __has_negative = False
    __denominator  = 1.0
    __rng   = None

    def __init__(self, rng=None):
        self.rng = rng

    def _getrand(self):
        if self.__rng is None:
            raise RuntimeError("no BitPackRandom instance is set; "
                               "pass it to the constructor or set the 'rng' property")
        return self.__rng.next()

    rng = property()
    @rng.setter
    def rng(self, value):
        self.__rng = value

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
        self.__uvalue = None

    seed = property()
    @seed.setter
    def seed(self, value):
        self.__seed = value

    def setvaluerange(self, arg1, arg2):
        """Set the range of values for this port.

        This has two styles of arguments for compatibility:
        - new style: (has_negative (bool), denominator (float))
        - old style: (max (float), min (float))
        See doc/eval_json_spec.md for details of the new-style arguments.
        """
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

    def getvalueword(self):
        """Translate a real value into a 32-bit binary value.

        Note that calling this method might have a side effect:
        if a random value has been requested, its actual value is generated here.
        The generated value will remain unchanged until the 'value' is set again.
        """
        if self.__uvalue is not None:
            return self.__uvalue
        if self.__random:
            r = self._getrand()
            if self.__has_negative:
                self.__uvalue = r
            else:
                self.__uvalue = r & 0x7fffffff
        elif self.__value >= 0.0:
            self.__uvalue = self.__value / self.__denominator * 0x7fffffff
        else:
            if self.__has_negative:
                self.__uvalue = 0x100000000 + self.__value / self.__denominator * 0x80000000
            else:
                self.__uvalue = 0
        return self.__uvalue

    def getvaluereal(self):
        """Translate a 32-bit binary value into a real value.

        This is equivalent to real_value() of the C++ version,
        which performs the inverse transform of getvalueword() for a random value.
        """
        if self.__random:
            if self.__has_negative and ((self.__uvalue & 0x80000000) != 0):
                return ((self.__uvalue & 0x80000000) / 0x80000000 - 1) * self.__denominator
            else:
                return (self.__uvalue / 0x7fffffff) * self.__denominator
        else:
            return self.__value

    def getseedword(self):
        """Returns a 32-bit seed for an internal LFSR in the circuit.

        Note that calling this method might also have a side effect:
        if the seed has not been set, a random number is generated and set as the seed
        until a non-zero number is generated.
        The LFSR will not work correctly for a seed of zero.
        """
        while(self.__seed == 0):
            self.__seed = self._getrand()
        return self.__seed

    def asarray(self):
        """Returns a pair of value and seed as 32-bit words."""
        return np.array([self.getvalueword(), self.getseedword()], dtype='u4')

class BitPackInputVector():
    """Interface for an input port of multiple bits of the target circuit."""

    def __init__(self, arg, rng=None):
        if isinstance(arg, list):
            self.__ins = arg
        else:
            self.__ins = []
            for i in range(arg):
                self.__ins.append(BitPackInput(rng))

    def __getitem__(self, key):
        if isinstance(key, slice):
            return BitPackInputVector(self.__ins[key])
        else:
            return self.__ins[key]

    def __len__(self):
        return len(self.__ins)

    rng = property()
    @rng.setter
    def rng(self, value):
        for i in range(self.size()):
            self.__ins[i].rng = value

    values = property()
    @values.setter
    def values(self, values):
        for i in range(self.size()):
            self.__ins[i].value = values[i]

    def size(self):
        return len(self.__ins) # for compatibility

    def setvaluerange(self, arg1, arg2):
        for i in range(self.size()):
            self.__ins[i].setvaluerange(arg1, arg2)

    def asarray(self):
        ary = np.empty(self.size() * 2, dtype='u4')
        for i in range(self.size()):
            ary[i * 2] = self.__ins[i].getvalueword() # consume random numbers for values at first
        for i in range(self.size()):
            ary[i * 2 + 1] = self.__ins[i].getseedword()
        return ary

class BitPackOutput():
    """Interface for an output port of single bit of the target circuit."""

    __value = 0.0
    __has_negative = False
    __denominator  = 1.0

    @property
    def value(self):
        return self.__value

    def setvaluerange(self, arg1, arg2):
        """Set the range of values for this port.

        This has two styles of arguments for compatibility:
        - new style: (has_negative (bool), denominator (float))
        - old style: (max (float), min (float))
        See doc/eval_json_spec.md for details of the new-style arguments.
        """
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
        """Calculate and set the real value of this port from the counter value."""
        if (count & 0x80000000) == 0:
            self.__value = count / size / self.__denominator
        else:
            self.__value = (count - 0x100000000) / size / self.__denominator

class BitPackOutputVector():
    """Interface for an output port of multiple bits of the target circuit."""

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
            
    def __len__(self):
        return len(self.__outs)

    @property
    def values(self):
        res = []
        for i in range(self.size()):
            res.append(self.__outs[i].value)
        return res

    def size(self): 
        return len(self.__outs) # for compatibility

    def setvaluerange(self, arg1, arg2):
        for i in range(self.size()):
            self.__outs[i].setvaluerange(arg1, arg2)

    def setfromcount(self, counts, cycle):
        for i in range(self.size()):
            self.__outs[i].setfromcount(counts[i], cycle)
