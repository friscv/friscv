// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Emil Popovic <mail@emilpopovic.me>

#include "console.hpp"

#include <csignal>
#include <cstdlib>
#include <poll.h>
#include <string>
#include <termios.h>
#include <unistd.h>

#include "uart16550_model.hpp"

namespace {

termios saved_termios;
bool    termios_saved = false;

void restore_terminal() {
    if (termios_saved) tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios);
    termios_saved = false;
}

void restore_and_exit(int sig) {
    restore_terminal();
    std::signal(sig, SIG_DFL);
    std::raise(sig);
}

}  // namespace

Console::Console() {
    if (isatty(STDIN_FILENO) && tcgetattr(STDIN_FILENO, &saved_termios) == 0) {
        termios_saved = true;

        termios raw = saved_termios;
        raw.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
        raw.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
        raw.c_cc[VMIN]  = 0;
        raw.c_cc[VTIME] = 0;
        tcsetattr(STDIN_FILENO, TCSANOW, &raw);
    }

    std::atexit(restore_terminal);
    std::signal(SIGTERM, restore_and_exit);
    std::signal(SIGHUP, restore_and_exit);
}

Console::~Console() {
    restore_terminal();
}

bool Console::poll(Uart16550Model& uart) {
    if (!stdin_open) return true;

    pollfd pfd = { STDIN_FILENO, POLLIN, 0 };
    if (::poll(&pfd, 1, 0) <= 0) return true;

    char buf[256];
    ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
    if (n == 0) {
        stdin_open = false;  // EOF, keep running without input
        return true;
    }
    if (n < 0) return true;  // Nothing to read

    std::string rx;
    for (ssize_t i = 0; i < n; i++) {
        uint8_t ch = uint8_t(buf[i]);
        if (escape_pending) {
            escape_pending = false;
            if (ch == 'x' || ch == 'X') {
                uart.push_rx(rx);
                return false;
            }
            if (ch != ESCAPE_KEY) rx += char(ESCAPE_KEY);
            rx += char(ch);
        } else if (ch == ESCAPE_KEY) {
            escape_pending = true;
        } else {
            rx += char(ch);
        }
    }
    uart.push_rx(rx);
    return true;
}
