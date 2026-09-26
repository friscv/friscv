// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
//
// Emil Popovic <mail@emilpopovic.me>

// Zero-stage bootloader ROM for the FRISC-V reference design.
module friscv_zsbl
    import friscv_mem_pkg::*;
#(
    parameter int unsigned Base      = 32'h0000_1000,
    // Must be a power of 2
    parameter int unsigned SizeBytes = 1024
) (
    input  logic            clk_i,
    input  logic            rst_ni,

    input  friscv_mem_req_t s_req_i,
    output friscv_mem_rsp_t s_rsp_o,

    output friscv_mem_req_t m_req_o,
    input  friscv_mem_rsp_t m_rsp_i
);

localparam int unsigned Words  = SizeBytes / 4;
localparam int unsigned WordAw = $clog2(Words);

logic [31:0] w_offset;
logic        w_hit;
assign w_offset = s_req_i.addr - Base;
assign w_hit    = s_req_i.en && (w_offset < SizeBytes);

logic [31:0] w_rom_rdata;

friscv_zsbl_rom #(
    .Words ( Words )
) i_rom (
    .clk_i,
    .addr_i  ( w_offset[WordAw+1:2] ),
    .rdata_o ( w_rom_rdata          )
);

// A ROM access is accepted in the first cycle and completes the next when the ROM output is valid.
// Like the downstream adapter, the first cycle always stalls, so stall never depends on the address.
logic r_busy;
logic r_err;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        r_busy <= 1'b0;
        r_err  <= 1'b0;
    end else begin
        r_busy <= w_hit && !r_busy;
        r_err  <= s_req_i.wr;
    end
end

always_comb begin
    m_req_o    = s_req_i;
    m_req_o.en = s_req_i.en && !w_hit && !r_busy;

    if (r_busy) begin
        s_rsp_o.rdata = w_rom_rdata;
        s_rsp_o.stall = 1'b0;
        s_rsp_o.beat  = 1'b0;
        s_rsp_o.err   = r_err;
    end else begin
        s_rsp_o = m_rsp_i;
    end
end

endmodule
