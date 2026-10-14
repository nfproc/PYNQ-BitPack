// main testbench for BitPack Verilator evaluation
// 2026-10-14 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

#include "bitpack_eval_config.hpp"
#include "bitpack_eval_uut.hpp"
#include "bitpack_lib_io.hpp"
#include "bitpack_lib_rand.hpp"
#include <cstdio>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <vector>

int main(int argc, char* argv[]) {
    const std::string cfgfile = (argc > 1) ? argv[1] : "eval.json";
    try {
        // 1. load the configuration
        EvalConfig cfg(cfgfile);

        // 2. one PRNG instance shared over the whole evaluation
        BitPackRandom rng(cfg.seed());

        // 3. input/output vectors
        EvalInputVector  srcs(cfg.inputs());
        srcs.set_rng(&rng);
        EvalOutputVector dsts(cfg.outputs());

        // 4. UUT
        UserWrapper uut(cfg.cycle());
        uut.reset();

        // 5. open the log files (overwrite)
        std::ofstream fresults("results.txt");
        std::ofstream finput("input.txt");
        std::ofstream foutput("output.txt");
        if (!fresults.is_open() || !finput.is_open() || !foutput.is_open()) {
            throw std::runtime_error("failed to open log files");
        }

        const size_t combos = cfg.combos_per_round();
        const size_t nins = srcs.size();

        // candidate sets: a random input contributes one candidate
        // (USE_RANDOM), a fixed input contributes its "values"
        std::vector<std::vector<InputValue>> cand(nins);
        for (size_t i = 0; i < nins; i++) {
            const EvalInputDesc& d = cfg.inputs()[i];
            if (d.random) {
                cand[i].push_back(InputValue(UseRandom::USE_RANDOM));
            } else {
                for (double v : d.values) {
                    cand[i].push_back(InputValue(v));
                }
            }
        }

        const int rounds = cfg.times();

        // 6. evaluation loop
        // combo index: the last input varies fastest
        // (same order as Python's itertools.product)
        for (int round = 0; round < rounds; round++) {
            std::vector<size_t> idx(nins, 0);
            for (size_t combo = 0; combo < combos; combo++) {
                // a. set the input combination
                for (size_t i = 0; i < nins; i++) {
                    srcs[i].set_value(cand[i][idx[i]]);
                }

                // b. generate the input words and log them
                const std::vector<uint32_t> words = srcs.as_words();
                for (size_t i = 0; i < words.size(); i++) {
                    finput << std::hex << std::setw(8) << std::setfill('0')
                           << words[i] << std::dec << "\n";
                }

                // c. run the circuit
                std::vector<int32_t> counts;
                uut.run(words, counts);

                // d. log the output words (two's complement, unsigned hex)
                for (size_t i = 0; i < counts.size(); i++) {
                    foutput << std::hex << std::setw(8) << std::setfill('0')
                            << (uint32_t)counts[i] << std::dec << "\n";
                }

                // e. convert to real values and log one line
                dsts.set_from_counts(counts, cfg.cycle());
                for (size_t i = 0; i < nins; i++) {
                    fresults << srcs[i].real_value() << " ";
                }
                const std::vector<double> outvals = dsts.real_values();
                for (size_t i = 0; i < outvals.size(); i++) {
                    fresults << outvals[i] << (i + 1 == outvals.size() ? "\n" : " ");
                }

                // f. advance the combo index (odometer style:
                // the last input varies fastest)
                for (int i = (int)nins - 1; i >= 0; i--) {
                    if (++idx[i] < cand[i].size()) {
                        break;
                    }
                    idx[i] = 0;
                }
            }
        }

        // 7. close the files
        fresults.close();
        finput.close();
        foutput.close();

        std::cout << "## Simulator completes " << combos << " x " << rounds 
            << " times of evaluation" << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "!! " << e.what() << std::endl;
        return 1;
    }
    return 0;
}
