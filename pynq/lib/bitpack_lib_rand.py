# reproducible PRNG for BitPack
# 2026-10-07 Naoki F., AIT
# New BSD license is applied. See COPYING for more details.

"""bitpack_lib_rand.py

A reproducible 32-bit pseudo-random number generator combining
splitmix32 (used as a seed expander) and xoshiro128** (the core generator).

Produces the same sequence as the C++ implementation in
bitpack_lib_rand.hpp / bitpack_lib_rand.cpp for the same seed.
"""

MASK32 = 0xFFFFFFFF


class BitPackRandom:
    """32-bit PRNG: splitmix32-seeded xoshiro128**."""

    def __init__(self, seed: int) -> None:
        """Initialize the internal xoshiro128** state.

        The 32-bit unsigned integer ``seed`` is fed through splitmix32
        four times; the four outputs become the initial state s[0..3].
        """
        seed &= MASK32
        state = []
        for _ in range(4):
            seed = (seed + 0x9E3779B9) & MASK32
            z = seed
            z ^= z >> 16
            z = (z * 0x21F0AAAD) & MASK32
            z ^= z >> 15
            z = (z * 0x735A2D97) & MASK32
            z ^= z >> 15
            state.append(z & MASK32)
        self._s = state

    @staticmethod
    def _rotl(x: int, k: int) -> int:
        return ((x << k) | (x >> (32 - k))) & MASK32

    def next(self) -> int:
        """Advance the state and return the next 32-bit unsigned integer
        (xoshiro128** next function)."""
        s = self._s
        # In C, the multiplications and shifts wrap modulo 2^32; mask
        # explicitly to reproduce the uint32_t semantics.
        result = (self._rotl((s[1] * 5) & MASK32, 7) * 9) & MASK32

        t = (s[1] << 9) & MASK32

        s[2] ^= s[0]
        s[3] ^= s[1]
        s[1] ^= s[2]
        s[0] ^= s[3]

        s[2] ^= t

        s[3] = self._rotl(s[3], 11)

        return result


if __name__ == "__main__":
    seed = 12345
    rng = BitPackRandom(seed)
    print(f"seed: {seed}")
    for _ in range(10):
        print(rng.next())
