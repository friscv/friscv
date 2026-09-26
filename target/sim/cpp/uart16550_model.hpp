// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Emil Popovic <mail@emilpopovic.me>

#pragma once

#include <cstdint>
#include <deque>
#include <string>

#include "bus.hpp"

class Uart16550Model : public BusDevice {
  public:
    void cycle(uint8_t size, uint32_t offset, uint32_t wdata,
               bool w_en, bool r_en, bool burst_en) override;

    // Queue bytes for the core to read from RBR
    void push_rx(const std::string& data);

    // Transmitted bytes, for matching console output
    uint64_t tx_count() const { return tx_bytes; }
    bool     tx_ends_with(const std::string& s) const;

  private:
    static constexpr size_t TX_TAIL_SIZE = 256;

    bool    dlab() const { return lcr & 0x80; }
    uint8_t iir() const;
    void    transmit(uint8_t byte);

    uint8_t ier = 0;  // Interrupt Enable Register
    uint8_t fcr = 0;  // FIFO Control Register
    uint8_t lcr = 0;  // Line Control Register
    uint8_t mcr = 0;  // Modem Control Register
    uint8_t scr = 0;  // Scratch Register
    uint8_t dll = 0;  // Divisor Latch LSB
    uint8_t dlm = 0;  // Divisor Latch MSB

    std::deque<uint8_t> rx_fifo;
    std::string         tx_tail;
    uint64_t            tx_bytes = 0;
};
