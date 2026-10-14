// eval.json loader for BitPack Verilator evaluation
// 2026-10-14 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

#ifndef BITPACK_EVAL_CONFIG_HPP
#define BITPACK_EVAL_CONFIG_HPP

#include <nlohmann/json.hpp>
#include <fstream>
#include <stdexcept>
#include <stdint.h>
#include <string>
#include <vector>

struct EvalInputDesc {
    std::string name;
    bool        has_negative;
    double      denominator;
    bool        random;
    std::vector<double> values;  // used only when random is false
};

struct EvalOutputDesc {
    std::string name;
    bool        has_negative;
    double      denominator;
};

// Loads and validates eval.json (see doc/eval_json_spec.md).
// Throws std::runtime_error on failure.
class EvalConfig {
public:
    explicit EvalConfig(const std::string& filename) {
        std::ifstream ifs(filename.c_str());
        if (!ifs.is_open()) {
            throw std::runtime_error("failed to open " + filename);
        }
        nlohmann::json j;
        try {
            ifs >> j;
        } catch (const std::exception& e) {
            throw std::runtime_error(std::string("failed to parse ") +
                                     filename + ": " + e.what());
        }

        // "input"
        if (!j.contains("input") || !j["input"].is_array()) {
            throw std::runtime_error("missing or invalid \"input\" in " + filename);
        }
        for (const auto& item : j["input"]) {
            EvalInputDesc d;
            d.name = item.at("name").get<std::string>();
            d.has_negative = item.at("has_negative").get<bool>();
            d.denominator = item.at("denominator").get<double>();
            d.random = item.at("random").get<bool>();
            if (item.at("values").is_array()) {
                for (const auto& v : item["values"]) {
                    d.values.push_back(v.get<double>());
                }
            }
            if (d.denominator <= 0.0) {
                throw std::runtime_error("invalid \"denominator\" for input " +
                                         d.name);
            }
            if (!d.random && d.values.empty()) {
                throw std::runtime_error("input " + d.name +
                                         " has no \"values\" although \"random\" is false");
            }
            m_inputs.push_back(d);
        }

        // "output"
        if (!j.contains("output") || !j["output"].is_array()) {
            throw std::runtime_error("missing or invalid \"output\" in " + filename);
        }
        for (const auto& item : j["output"]) {
            EvalOutputDesc d;
            d.name = item.at("name").get<std::string>();
            d.has_negative = item.at("has_negative").get<bool>();
            d.denominator = item.at("denominator").get<double>();
            if (d.denominator <= 0.0) {
                throw std::runtime_error("invalid \"denominator\" for output " +
                                         d.name);
            }
            m_outputs.push_back(d);
        }

        // "cycle", "times", "seed"
        m_cycle = j.at("cycle").get<int>();
        m_times = j.at("times").get<int>();
        m_seed = j.at("seed").get<uint32_t>();
        if (m_cycle <= 0) {
            throw std::runtime_error("invalid \"cycle\" in " + filename);
        }
        if (m_times <= 0) {
            throw std::runtime_error("invalid \"times\" in " + filename);
        }
    }

    const std::vector<EvalInputDesc>&  inputs()  const { return m_inputs; }
    const std::vector<EvalOutputDesc>& outputs() const { return m_outputs; }
    int        cycle() const { return m_cycle; }
    int        times() const { return m_times; }
    uint32_t   seed()  const { return m_seed; }

    // Number of evaluations per round: the size of the Cartesian product
    // of the candidate sets of all inputs (a random input contributes
    // exactly one candidate, USE_RANDOM).
    size_t combos_per_round() const {
        size_t n = 1;
        for (size_t i = 0; i < m_inputs.size(); i++) {
            n *= (m_inputs[i].random ? 1 : m_inputs[i].values.size());
        }
        return n;
    }

private:
    std::vector<EvalInputDesc>  m_inputs;
    std::vector<EvalOutputDesc> m_outputs;
    int        m_cycle;
    int        m_times;
    uint32_t   m_seed;
};

#endif  // BITPACK_EVAL_CONFIG_HPP
