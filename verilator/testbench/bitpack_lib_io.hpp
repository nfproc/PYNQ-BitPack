// input/output abstraction for BitPack Verilator evaluation
// 2026-10-14 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

#ifndef BITPACK_EVAL_IO_HPP
#define BITPACK_EVAL_IO_HPP

#include "bitpack_eval_config.hpp"
#include "bitpack_lib_rand.hpp"
#include <stdexcept>
#include <variant>
#include <vector>

// Special value meaning "request a random value"
enum class UseRandom { USE_RANDOM };
using InputValue = std::variant<double, UseRandom>;

class EvalInput {
public:
    EvalInput(bool has_negative, double denominator)
        : m_has_negative(has_negative), m_denominator(denominator),
          m_random(false), m_value(0.0),
          m_binary(0), m_seed(0), m_rng(nullptr) {}

    // Set the value. UseRandom requests a random value.
    void set_value(InputValue v) {
        if (std::holds_alternative<UseRandom>(v)) {
            m_random = true;
            return;
        }
        m_random = false;
        const double dv = std::get<double>(v);
        const double maxv = m_denominator;
        const double minv = m_has_negative ? -m_denominator : 0.0;
        m_value = (dv > maxv) ? maxv : (dv < minv) ? minv : dv;
    }

    // Set the PRNG source (used for the random value and the seed)
    void set_rng(BitPackRandom* rng) { m_rng = rng; }

    // Compute binary_value (see doc/verilator_eval_spec.md).
    // For a random value, a pseudo-random number is drawn here.
    uint32_t binary_value() const {
        if (m_rng == nullptr) {
            throw std::runtime_error("no BitPackRandom instance is set");
        }
        double uvalue;
        if (m_random) {
            const uint32_t r = m_rng->next();
            uvalue = m_has_negative ? (double)r : (double)(r & 0x7fffffffu);
        } else if (m_value >= 0.0) {
            uvalue = m_value / m_denominator * 0x7fffffff;
        } else if (m_has_negative) {
            uvalue = 4294967296.0 + m_value / m_denominator * 2147483648.0;
        } else {
            uvalue = 0.0;
        }
        m_binary = (uint32_t)(uvalue + 0.5);
        return m_binary;
    }

    // Compute the seed (a non-zero pseudo-random number)
    uint32_t seed() const {
        if (m_rng == nullptr) {
            throw std::runtime_error("no BitPackRandom instance is set");
        }
        uint32_t r;
        do {
            r = m_rng->next();
        } while (r == 0);
        m_seed = r;
        return m_seed;
    }

    // Real value for results.txt:
    // for a random value, the inverse transform of binary_value();
    // for a fixed value, the (clamped) set value.
    double real_value() const {
        if (m_random) {
            // binary_value() should already have been called
            const int32_t b = (int32_t)m_binary;
            return m_has_negative
                 ? (double)b / 2147483648.0 * m_denominator
                 : (double)m_binary / 0x7fffffff * m_denominator;
        }
        return m_value;
    }

private:
    bool   m_has_negative;
    double m_denominator;
    bool   m_random;
    double m_value;      // fixed value (clamped)
    mutable uint32_t m_binary;  // cache of binary_value()
    mutable uint32_t m_seed;    // cache of seed()
    BitPackRandom* m_rng;
};

class EvalInputVector {
public:
    explicit EvalInputVector(const std::vector<EvalInputDesc>& descs) {
        for (size_t i = 0; i < descs.size(); i++) {
            m_ins.push_back(EvalInput(descs[i].has_negative,
                                      descs[i].denominator));
        }
    }

    void set_rng(BitPackRandom* rng) {
        for (size_t i = 0; i < m_ins.size(); i++) {
            m_ins[i].set_rng(rng);
        }
    }

    EvalInput& operator[](size_t i) { return m_ins[i]; }
    size_t size() const { return m_ins.size(); }

    // Generate the 2*size() words read by user_wrapper for one run.
    // Word order: the inputs are laid out as an array of input_port_t
    // (binary_value, seed), so word 2*i is the binary_value of input i
    // and word 2*i+1 is its seed.
    // PRNG consumption order (per spec): binary_value() of all inputs
    // first (USE_RANDOM inputs draw their value here), then seed() of
    // all inputs.
    std::vector<uint32_t> as_words() const {
        const size_t n = m_ins.size();
        std::vector<uint32_t> words(n * 2);
        for (size_t i = 0; i < n; i++) {
            words[2 * i] = m_ins[i].binary_value();
        }
        for (size_t i = 0; i < n; i++) {
            words[2 * i + 1] = m_ins[i].seed();
        }
        return words;
    }

private:
    std::vector<EvalInput> m_ins;
};

class EvalOutput {
public:
    EvalOutput(bool has_negative, double denominator)
        : m_has_negative(has_negative), m_denominator(denominator),
          m_value(0.0) {}

    // Convert a 32-bit signed counter value to a real value:
    // value = count / (cycle * denominator)
    void set_from_count(int32_t count, int cycle) {
        m_value = (double)count / (double)cycle / m_denominator;
    }

    double real_value() const { return m_value; }

private:
    bool   m_has_negative;  // kept for reference (does not affect the formula)
    double m_denominator;
    double m_value;
};

class EvalOutputVector {
public:
    explicit EvalOutputVector(const std::vector<EvalOutputDesc>& descs) {
        for (size_t i = 0; i < descs.size(); i++) {
            m_outs.push_back(EvalOutput(descs[i].has_negative,
                                        descs[i].denominator));
        }
    }

    EvalOutput& operator[](size_t i) { return m_outs[i]; }
    size_t size() const { return m_outs.size(); }

    void set_from_counts(const std::vector<int32_t>& counts, int cycle) {
        for (size_t i = 0; i < m_outs.size(); i++) {
            m_outs[i].set_from_count(counts[i], cycle);
        }
    }

    std::vector<double> real_values() const {
        std::vector<double> res;
        for (size_t i = 0; i < m_outs.size(); i++) {
            res.push_back(m_outs[i].real_value());
        }
        return res;
    }

private:
    std::vector<EvalOutput> m_outs;
};

#endif  // BITPACK_EVAL_IO_HPP
