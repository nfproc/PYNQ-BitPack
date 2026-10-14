// reproducible PRNG for BitPack
// 2026-10-07 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

#include "bitpack_lib_rand.hpp"
#include <stdio.h>

uint32_t BitPackRandom::splitmix32(uint32_t* x) {
    uint32_t z = (*x += 0x9e3779b9u);
    z ^= z >> 16;
    z *= 0x21f0aaadu;
    z ^= z >> 15;
    z *= 0x735a2d97u;
    z ^= z >> 15;
    return z;
}

uint32_t BitPackRandom::rotl(uint32_t x, int k) {
    return (x << k) | (x >> (32 - k));
}

BitPackRandom::BitPackRandom(uint32_t seed) {
    for (int i = 0; i < 4; i++) {
        s_[i] = splitmix32(&seed);
    }
}

uint32_t BitPackRandom::next() {
    const uint32_t result = rotl(s_[1] * 5, 7) * 9;

    const uint32_t t = s_[1] << 9;

    s_[2] ^= s_[0];
    s_[3] ^= s_[1];
    s_[1] ^= s_[2];
    s_[0] ^= s_[3];

    s_[2] ^= t;

    s_[3] = rotl(s_[3], 11);

    return result;
}

int bitpackrandom_test() {
    const uint32_t seed = 12345;
    BitPackRandom rng(seed);
    printf("seed: %u\n", seed);
    for (int i = 0; i < 10; i++) {
        printf("%u\n", rng.next());
    }
    return 0;
}

// int main () { return bitpackrandom_test(); }