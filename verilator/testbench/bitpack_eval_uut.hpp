// UUT driver for BitPack Verilator evaluation
// 2026-10-14 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

#ifndef BITPACK_EVAL_UUT_HPP
#define BITPACK_EVAL_UUT_HPP

#include "Vuser_wrapper.h"
#include "verilated.h"
#include <stdint.h>
#include <stdexcept>
#include <vector>

// Wraps Vuser_wrapper. The testbench acts as the slave side of the
// AXI_FIFO interface:
//  - it drives READ_DATA/READ_VALID and WRITE_READY/WRITE_BUSY,
//  - it observes READ_REQ/READ_READY/WRITE_REQ/WRITE_VALID/WRITE_DATA.
//
// Handshake (see doc/verilator_eval_spec.md):
//  - READ_REQ is high only in the cycle GO is raised (READ_REQ = DONE & GO);
//    with READ_BUSY = 0 the address transfer is accepted at that cycle.
//  - In STATE_READ, READ_READY is high, so the testbench can send
//    all input words back to back, one per cycle.
//  - WRITE_REQ is high for one cycle at the end of the processing;
//    with WRITE_BUSY = 0 the address transfer is accepted.
//  - In STATE_WRITE, WRITE_VALID is high, so the testbench receives
//    all counter values back to back by keeping WRITE_READY = 1.
class UserWrapper {
public:
    explicit UserWrapper(int cycle)
        : m_dut(new Vuser_wrapper), m_cycle(cycle) {
        // inputs driven by the testbench
        m_dut->CLK = 0;
        m_dut->RST_X = 0;
        m_dut->GO = 0;
        m_dut->SRC = 0;
        m_dut->DST = 0;
        m_dut->SIZE = (uint32_t)cycle;
        m_dut->READ_BUSY = 0;
        m_dut->READ_DATA = 0;
        m_dut->READ_VALID = 0;
        m_dut->WRITE_BUSY = 0;
        m_dut->WRITE_READY = 1;  // always accept write data
        m_dut->eval();
    }

    ~UserWrapper() {
        delete m_dut;
        m_dut = nullptr;
    }

    // Apply reset and wait until the circuit is idle (DONE = 1)
    void reset() {
        m_dut->RST_X = 0;
        for (int i = 0; i < 10; i++) {
            tick();
        }
        m_dut->RST_X = 1;
        tick();
        wait_idle();
    }

    // Run the circuit once.
    //  - words: the 2*src_size input words (from EvalInputVector::as_words())
    //  - counts: output, dst_size counter values
    void run(const std::vector<uint32_t>& words,
             std::vector<int32_t>& counts) {
        if (!m_dut->DONE) {
            throw std::runtime_error("circuit is not idle before run()");
        }
        m_write_counts.clear();

        // 1. raise GO while DONE is 1; the read address transfer
        //    (READ_REQ = 1, READ_BUSY = 0) happens at this cycle
        m_dut->GO = 1;
        tick();

        // 2. send all input words back to back (READ_READY = 1 in STATE_READ)
        for (size_t i = 0; i < words.size(); i++) {
            m_dut->READ_DATA = words[i];
            m_dut->READ_VALID = 1;
            tick();
        }
        m_dut->READ_VALID = 0;
        m_dut->READ_DATA = 0;

        // 3. clear GO and wait until the circuit is idle again;
        //    capture the counter values while WRITE_VALID is high
        m_dut->GO = 0;
        const int guard = 10 * m_cycle + 1000;
        for (int i = 0; i < guard; i++) {
            tick();
            if (m_dut->WRITE_VALID) {
                m_write_counts.push_back((int32_t)m_dut->WRITE_DATA);
            }
            if (m_dut->DONE) {
                break;
            }
        }
        if (!m_dut->DONE) {
            throw std::runtime_error("timeout while waiting for DONE");
        }

        counts = m_write_counts;
    }

    // Advance one full clock cycle (the clock is generated internally).
    // Without --timing, Verilator compiles always_ff @(posedge CLK) so that
    // the flip-flops are updated whenever eval() is called with CLK = 1,
    // so a full cycle needs one eval() at CLK = 1 and one at CLK = 0.
    void tick() {
        m_dut->CLK = 1;
        m_dut->eval();
        m_dut->CLK = 0;
        m_dut->eval();
    }

private:
    // Wait (with a timeout) until DONE is 1
    void wait_idle() {
        const int guard = 10 * m_cycle + 1000;
        for (int i = 0; i < guard; i++) {
            if (m_dut->DONE) {
                return;
            }
            tick();
        }
        throw std::runtime_error("timeout while waiting for DONE");
    }

    Vuser_wrapper* m_dut;
    int m_cycle;
    std::vector<int32_t> m_write_counts;  // received counter values
};

#endif  // BITPACK_EVAL_UUT_HPP
