// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Emil Popovic <mail@emilpopovic.me>
// Matej Jurasic <matej.jurasic@cappig.dev>

#include "Vfriscv_cpu_verilator.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

#include "paged_mem.hpp"
#include "mem_model.hpp"
#include "elf_loader.hpp"
#include "bus.hpp"
#include "uart16550_model.hpp"
#include "clint_model.hpp"
#include "console.hpp"

#define DEFAULT_MAX_CYCLES  (10000000u)
#define DEFAULT_WAIT_CYCLES (0)
#define CONSOLE_POLL_CYCLES (4096u)

static uint64_t cycle_count = 0;

static constexpr uint32_t MEM_BASE_ADDR = 0x80000000u;
static constexpr uint32_t MEM_SIZE_MB   = 16;

static constexpr uint32_t UART_BASE_ADDR  = 0x10000000u;
static constexpr uint32_t GPIO_BASE_ADDR  = 0x40000000u;
static constexpr uint32_t HALT_BASE_ADDR  = 0x50000000u;
static constexpr uint32_t CLINT_BASE_ADDR = 0x02000000u;

static constexpr uint32_t PASS_VALUE = 0xAABBCCDDu;

void posedge(Vfriscv_cpu_verilator* top) {
    cycle_count++;
    top->clk_i = 1;
    top->eval();
}

void negedge(Vfriscv_cpu_verilator* top) {
    top->clk_i = 0;
    top->eval();
}

void drive_clint(Vfriscv_cpu_verilator* top, const ClintModel& clint) {
    top->mtime_i = clint.get_mtime();
    top->msip_i  = clint.get_msip();
    top->mtip_i  = clint.get_mtip();
}

void cycle(Vfriscv_cpu_verilator* top, BusRouter& bus) {
    // Posedge for the core
    posedge(top);

    bus.cycle(top->size_o, top->addr_o, top->wdata_o,
              top->w_en_o, top->r_en_o, top->burst_en_o);

    top->rdata_i      = bus.rdata;
    top->stall_i      = bus.wait;
    top->beat_valid_i = bus.beat_valid;
    top->err_i        = bus.err;

    negedge(top);
}

// Load a flat binary into memory at addr
void load_bin(const char* path, uint32_t addr, PagedMem* memory) {
    std::ifstream file(path, std::ios::binary);
    if (!file) throw std::runtime_error("cannot open file");

    std::vector<char> data((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    if (!memory->in_range(addr) || data.size() > memory->base_addr() + memory->size() - addr) {
        throw std::runtime_error("binary outside memory range");
    }

    for (size_t i = 0; i < data.size(); ++i) {
        memory->write_byte(addr + uint32_t(i), uint8_t(data[i]));
    }
}

// Expand \n, \r, \t and \\ in a string
std::string unescape(const char* s) {
    std::string out;
    for (; *s; s++) {
        if (*s != '\\' || !s[1]) { out += *s; continue; }
        switch (*++s) {
            case 'n': out += '\n'; break;
            case 'r': out += '\r'; break;
            case 't': out += '\t'; break;
            default:  out += *s;   break;
        }
    }
    return out;
}

void usage(const char* prog) {
    std::fprintf(stderr,
        "usage: %s (--elf <path> | --bin <path>[@<addr>]) [options]\n"
        "  --max-cycles <n>          stop after n cycles (default %u)\n"
        "  --wait-cycles <n>         DRAM wait cycles, -1/-2 for random (default %d)\n"
        "  --mem-mb <n>              DRAM size in MiB at 0x%08X (default %u)\n"
        "  --check-pass              PASS if the last GPIO write is 0x%08X\n"
        "  --pass-str <s>            PASS when the UART output contains s\n"
        "  --fail-str <s>            FAIL when the UART output contains s (repeatable)\n"
        "  --uart-input <s>          send s to the UART RX, escapes \\n \\r \\t allowed\n"
        "  --uart-input-after <s>    send --uart-input once the UART output contains s\n"
        "  --interactive             connect the terminal to the UART, no pass/fail and no\n"
        "                            cycle limit unless --max-cycles is given, Ctrl-A x quits\n",
        prog, DEFAULT_MAX_CYCLES, DEFAULT_WAIT_CYCLES, MEM_BASE_ADDR, MEM_SIZE_MB, PASS_VALUE);
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);

    const char* elf_path = nullptr;
    const char* bin_arg  = nullptr;
    uint64_t    max_cycles  = DEFAULT_MAX_CYCLES;
    int         wait_cycles = DEFAULT_WAIT_CYCLES;
    uint32_t    mem_size_mb = MEM_SIZE_MB;
    bool        check_pass  = false;
    bool        interactive = false;
    bool        max_cycles_set = false;
    std::string pass_str, uart_input, uart_input_after;
    std::vector<std::string> fail_strs;

    for (int i = 1; i < argc; i++) {
        const char* arg = argv[i];
        const char* val = (i + 1 < argc) ? argv[i + 1] : nullptr;
        char* endptr;

        if (std::strcmp(arg, "--check-pass") == 0) {
            check_pass = true;
            continue;
        }
        if (std::strcmp(arg, "--interactive") == 0) {
            interactive = true;
            continue;
        }
        if (arg[0] == '+') continue;  // Verilator plusargs
        if (!val) {
            usage(argv[0]);
            return 1;
        }
        i++;

        if (std::strcmp(arg, "--elf") == 0) {
            elf_path = val;
        } else if (std::strcmp(arg, "--bin") == 0) {
            bin_arg = val;
        } else if (std::strcmp(arg, "--max-cycles") == 0) {
            max_cycles = std::strtoull(val, &endptr, 10);
            if (*endptr != '\0' || max_cycles == 0) {
                std::fprintf(stderr, "invalid value for --max-cycles: %s\n", val);
                return 1;
            }
            max_cycles_set = true;
        } else if (std::strcmp(arg, "--wait-cycles") == 0) {
            wait_cycles = std::strtol(val, &endptr, 10);
            if (*endptr != '\0') {
                std::fprintf(stderr, "invalid value for --wait-cycles: %s\n", val);
                return 1;
            }
        } else if (std::strcmp(arg, "--mem-mb") == 0) {
            mem_size_mb = std::strtoul(val, &endptr, 10);
            if (*endptr != '\0' || mem_size_mb == 0 || mem_size_mb > 2048) {
                std::fprintf(stderr, "invalid value for --mem-mb: %s\n", val);
                return 1;
            }
        } else if (std::strcmp(arg, "--pass-str") == 0) {
            pass_str = unescape(val);
        } else if (std::strcmp(arg, "--fail-str") == 0) {
            fail_strs.push_back(unescape(val));
        } else if (std::strcmp(arg, "--uart-input") == 0) {
            uart_input = unescape(val);
        } else if (std::strcmp(arg, "--uart-input-after") == 0) {
            uart_input_after = unescape(val);
        } else {
            std::fprintf(stderr, "unknown argument: %s\n", arg);
            usage(argv[0]);
            return 1;
        }
    }

    if (!elf_path == !bin_arg) {
        usage(argv[0]);
        return 1;
    }

    if (interactive && (check_pass || !pass_str.empty() || !fail_strs.empty())) {
        std::fprintf(stderr, "--interactive has no pass/fail, drop --check-pass/--pass-str/--fail-str\n");
        return 1;
    }
    if (interactive && !max_cycles_set) max_cycles = UINT64_MAX;

    const uint32_t mem_size = mem_size_mb << 20;
    PagedMem mem_pool(MEM_BASE_ADDR, mem_size);
    const char* load_path = elf_path ? elf_path : bin_arg;
    try {
        if (elf_path) {
            load_elf(elf_path, &mem_pool);
        } else {
            std::string path = bin_arg;
            uint32_t    addr = MEM_BASE_ADDR;
            size_t      at   = path.rfind('@');
            if (at != std::string::npos) {
                char* endptr;
                addr = std::strtoul(path.c_str() + at + 1, &endptr, 0);
                if (*endptr != '\0') throw std::runtime_error("invalid load address");
                path.resize(at);
            }
            load_bin(path.c_str(), addr, &mem_pool);
        }
    } catch (const std::exception& e) {
        std::fprintf(stderr, "failed to load '%s': %s\n", load_path, e.what());
        return 1;
    }

    // Instantiate top module
    Vfriscv_cpu_verilator* top = new Vfriscv_cpu_verilator;

    // Build the bus and address map
    MemModel       dram(&mem_pool, wait_cycles);
    Uart16550Model uart;
    SinkDevice     gpio, halt_sink;
    ClintModel     clint;
    BusRouter      bus;

    bus.map(MEM_BASE_ADDR,   mem_size, &dram);
    bus.map(UART_BASE_ADDR,  0x20,     &uart);
    bus.map(GPIO_BASE_ADDR,  4,        &gpio);
    bus.map(HALT_BASE_ADDR,  4,        &halt_sink);
    bus.map(CLINT_BASE_ADDR, 0x10000,  &clint);

    // Initialize into reset
    top->rst_ni = 0;
    top->clk_i  = 0;
    drive_clint(top, clint);
    top->meip_i = 0;
    top->eval();

    // Reset for 20 cycles
    for (int i = 0; i < 20 && !Verilated::gotFinish(); i++) {
        cycle(top, bus);
    }

    clint.reset();
    top->rst_ni = 1;  // Release reset

    if (!uart_input.empty() && uart_input_after.empty()) uart.push_rx(uart_input);

    Console* console = nullptr;
    if (interactive) {
        std::fprintf(stderr, "[sim] %s on the UART console, Ctrl-A x to quit\n", load_path);
        console = new Console;
    }
    bool quit = false;

    // Run until halt, timeout, or a UART pass/fail string
    bool     pass_seen = false;
    int      fail_seen = -1;
    uint64_t tx_seen   = 0;
    while (!top->halt_o && cycle_count < max_cycles && !Verilated::gotFinish()) {
        cycle(top, bus);
        drive_clint(top, clint);

        if (console && cycle_count % CONSOLE_POLL_CYCLES == 0 && !console->poll(uart)) {
            quit = true;
            break;
        }

        // At most one byte is transmitted per cycle, so checking the tail on every byte is enough
        if (uart.tx_count() == tx_seen) continue;
        tx_seen = uart.tx_count();

        if (!uart_input_after.empty() && uart.tx_ends_with(uart_input_after)) {
            uart.push_rx(uart_input);
            uart_input_after.clear();
        }
        for (size_t i = 0; i < fail_strs.size() && fail_seen < 0; i++) {
            if (uart.tx_ends_with(fail_strs[i])) fail_seen = int(i);
        }
        if (fail_seen >= 0) break;
        if (!pass_str.empty() && uart.tx_ends_with(pass_str)) {
            pass_seen = true;
            break;
        }
    }

    if (console) {
        delete console;
        std::fflush(stdout);
        std::fprintf(stderr, "\n[sim] %s at cycle %llu\n",
                     quit ? "quit" : top->halt_o ? "halted" : "stopped",
                     (unsigned long long)cycle_count);
    }

    int exit_code = 0;
    if (check_pass) {
        if (gpio.get_last_write() == PASS_VALUE) {
            std::fprintf(stderr, "PASS\n");
            exit_code = 0;
        } else {
            std::fprintf(stderr, "FAIL (gpio=0x%08X)\n", gpio.get_last_write());
            exit_code = 1;
        }
    }
    if (!pass_str.empty() || !fail_strs.empty()) {
        std::fflush(stdout);
        if (fail_seen >= 0) {
            std::fprintf(stderr, "\nFAIL (found \"%s\" at cycle %llu)\n",
                         fail_strs[fail_seen].c_str(), (unsigned long long)cycle_count);
            exit_code = 1;
        } else if (pass_seen) {
            std::fprintf(stderr, "\nPASS (found \"%s\" at cycle %llu)\n",
                         pass_str.c_str(), (unsigned long long)cycle_count);
        } else if (!pass_str.empty()) {
            std::fprintf(stderr, "\nFAIL (%s at cycle %llu)\n",
                         top->halt_o ? "halted" : "timed out", (unsigned long long)cycle_count);
            exit_code = 1;
        }
    }

    top->final();
    delete top;
    return exit_code;
}
