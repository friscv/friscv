// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
//
// Emil Popovic <mail@emilpopovic.me>

// This module implements address remapping specific for the FRISC-V reference design.
// It handles remapping of the CLINT and UART peripherals to their "real" addresses on the PYNQ-Z2 AXI bus.
module friscv_remap
    import friscv_pkg::*;
# (
    // Address space remapping
    parameter bit ENABLE_REMAP       = 1,
    // Remaps standard CLINT address to a free address in the AXI map: 0x0200_0000 -> 0x4010_0000
    parameter bit ENABLE_REMAP_CLINT = 1,
    // Remaps UART: 0x1000_0000 -> 0x4060_0000
    parameter bit ENABLE_REMAP_UART  = 1,

    // Platform address map
    parameter addr_t DRAM_BASE       = 32'h80000000,
    parameter addr_t DRAM_START_AT   = 32'h00100000,
    parameter addr_t CLINT_REAL_BASE = 32'h40100000,
    parameter addr_t CLINT_PHY_BASE  = 32'h02000000,
    parameter addr_t UART_REAL_BASE  = 32'h40600000,
    parameter addr_t UART_PHY_BASE   = 32'h10000000
) (
    input  addr_t i_addr,
    output addr_t o_addr
);

always_comb begin
    if (!ENABLE_REMAP)
        o_addr = i_addr;
    else if (ENABLE_REMAP_CLINT && i_addr[31:16] == CLINT_PHY_BASE[31:16] && i_addr[15:0] <= 16'hBFFF)
        o_addr = {CLINT_REAL_BASE[31:16], i_addr[15:0]};
    else if (ENABLE_REMAP_UART && i_addr[31:16] == UART_PHY_BASE[31:16] && i_addr[15:0] <= 16'hBFFF)
        o_addr = {UART_REAL_BASE[31:16], i_addr[15:0]};
    else if (DRAM_BASE == 32'h8000_0000)
        o_addr = i_addr[31] ? {1'b0, i_addr[30:0]} + DRAM_START_AT : i_addr;
    else if (DRAM_BASE == 32'h0)
        o_addr = i_addr + DRAM_START_AT;
    else
        o_addr = (i_addr < DRAM_BASE) ? i_addr : (i_addr - DRAM_BASE) + DRAM_START_AT;
end

endmodule
