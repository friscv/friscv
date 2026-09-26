// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Emil Popovic <mail@emilpopovic.me>

#pragma once

#include <cstdint>

class Uart16550Model;

// Connects the host terminal to the UART
class Console {
  public:
    static constexpr uint8_t ESCAPE_KEY = 0x01;  // Ctrl-A

    Console();
    ~Console();

    bool poll(Uart16550Model& uart);

  private:
    bool escape_pending = false;
    bool stdin_open     = true;
};
