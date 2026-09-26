// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Emil Popovic <mail@emilpopovic.me>

#include "uart16550_model.hpp"

#include <cstdio>

#define REG_RBR_THR_DLL (0)
#define REG_IER_DLM     (1)
#define REG_IIR_FCR     (2)
#define REG_LCR         (3)
#define REG_MCR         (4)
#define REG_LSR         (5)
#define REG_MSR         (6)
#define REG_SCR         (7)

#define IER_ERBFI          (0x01)
#define IER_ETBEI          (0x02)
#define IIR_NO_INT_PENDING (0x01)
#define IIR_THRE           (0x02)
#define IIR_RDA            (0x04)
#define IIR_FIFO_ENABLED   (0xC0)
#define FCR_FIFO_ENABLE    (0x01)
#define LSR_DR             (0x01)
#define LSR_THRE_TEMT      (0x60)

void Uart16550Model::push_rx(const std::string& data) {
    rx_fifo.insert(rx_fifo.end(), data.begin(), data.end());
}

bool Uart16550Model::tx_ends_with(const std::string& s) const {
    return tx_tail.size() >= s.size() &&
           tx_tail.compare(tx_tail.size() - s.size(), s.size(), s) == 0;
}

void Uart16550Model::transmit(uint8_t byte) {
    std::fputc(byte, stdout);
    std::fflush(stdout);

    tx_bytes++;
    tx_tail.push_back(char(byte));
    if (tx_tail.size() > 2 * TX_TAIL_SIZE) tx_tail.erase(0, tx_tail.size() - TX_TAIL_SIZE);
}

uint8_t Uart16550Model::iir() const {
    uint8_t fifo = (fcr & FCR_FIFO_ENABLE) ? IIR_FIFO_ENABLED : 0;
    if ((ier & IER_ERBFI) && !rx_fifo.empty()) return fifo | IIR_RDA;
    if (ier & IER_ETBEI) return fifo | IIR_THRE;
    return fifo | IIR_NO_INT_PENDING;
}

// The interrupt output is not connected, RX is fed from push_rx()
void Uart16550Model::cycle(uint8_t size, uint32_t offset, uint32_t wdata,
                           bool w_en, bool r_en, bool burst_en) {
    (void)size;
    (void)burst_en;

    rdata      = 0;
    wait       = false;
    beat_valid = false;
    err        = false;

    if (!w_en && !r_en) return;

    uint32_t reg  = (offset >> 2) & 0x7;
    uint8_t  byte = wdata & 0xFF;

    if (w_en) {
        switch (reg) {
            case REG_RBR_THR_DLL: if (dlab()) dll = byte; else transmit(byte); break;
            case REG_IER_DLM:     if (dlab()) dlm = byte; else ier = byte; break;
            case REG_IIR_FCR:     fcr = byte; break;
            case REG_LCR:         lcr = byte; break;
            case REG_MCR:         mcr = byte; break;
            case REG_SCR:         scr = byte; break;
            default:              break;
        }
    } else {
        switch (reg) {
            case REG_RBR_THR_DLL:
                if (dlab()) {
                    rdata = dll;
                } else if (!rx_fifo.empty()) {
                    rdata = rx_fifo.front();
                    rx_fifo.pop_front();
                }
                break;
            case REG_IER_DLM: rdata = dlab() ? dlm : ier; break;
            case REG_IIR_FCR: rdata = iir(); break;
            case REG_LCR:     rdata = lcr; break;
            case REG_MCR:     rdata = mcr; break;
            case REG_LSR:     rdata = LSR_THRE_TEMT | (rx_fifo.empty() ? 0 : LSR_DR); break;
            case REG_MSR:     rdata = 0; break;
            case REG_SCR:     rdata = scr; break;
        }
    }
}
