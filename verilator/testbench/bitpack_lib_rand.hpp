// reproducible PRNG for BitPack
// 2026-10-07 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

#ifndef BITPACK_LIB_RAND_HPP
#define BITPACK_LIB_RAND_HPP

#include <stdint.h>

// A reproducible 32-bit pseudo-random number generator combining
// splitmix32 (used as a seed expander) and xoshiro128** (the core generator).
//
// Produces the same sequence as the Python implementation in
// bitpack_lib_rand.py for the same seed.
class BitPackRandom {
public:
    // Initialize the internal xoshiro128** state: the 32-bit unsigned
    // integer seed is fed through splitmix32 four times, and the four
    // outputs become the initial state s[0..3].
    explicit BitPackRandom(uint32_t seed);

    // Advance the state and return the next 32-bit unsigned integer
    // (xoshiro128** next function).
    uint32_t next();

private:
    uint32_t s_[4];

    static uint32_t splitmix32(uint32_t* x);
    static uint32_t rotl(uint32_t x, int k);
};

#endif  // BITPACK_LIB_RAND_HPP
