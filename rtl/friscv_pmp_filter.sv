// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
//
// Emil Popovic <mail@emilpopovic.me>

// This module enforces PMP on the physical memory bus.
module friscv_pmp_filter
    import friscv_pkg::*;
#(
    parameter bit          EnforcePmp = 0,
    parameter int unsigned PmpEntries = 8
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  pmp_entry_t [PmpEntries-1:0] pmp_table_i,

    // Request side
    input  addr_t       req_addr_i,
    input  mem_width_e  req_size_i,
    input  data_t       req_wdata_i,
    output data_t       req_rdata_o,
    input  rw_cmd_e     req_rw_i,
    output logic        req_wait_o,
    output logic        req_err_o,
    input  amo_op_e     req_amo_op_i,
    input  mem_attr_t   req_attr_i,

    // Memory side
    output addr_t       mem_addr_o,
    output mem_width_e  mem_size_o,
    output data_t       mem_wdata_o,
    input  data_t       mem_rdata_i,
    output rw_cmd_e     mem_rw_o,
    input  logic        mem_wait_i,
    input  logic        mem_err_i,
    output amo_op_e     mem_amo_op_o
);

logic fault;

if (EnforcePmp) begin : gen_pmp_check
    logic check_en;
    logic access_r, access_w, access_x;
    logic chk_fault;

    // Do not take requests while servicing one
    logic r_busy;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) r_busy <= 1'b0;
        else         r_busy <= (mem_rw_o != RW_IDLE) && mem_wait_i;
    end

    assign check_en = (req_rw_i != RW_IDLE) && !r_busy;

    always_comb begin
        access_r = 1'b0;
        access_w = 1'b0;
        access_x = 1'b0;
        if (check_en) begin
            unique case (req_attr_i.src)
                MEM_SRC_INST: access_x = 1'b1;
                MEM_SRC_PTW:  access_r = 1'b1;
                MEM_SRC_DATA: begin
                    access_r = !req_attr_i.store_like || (req_amo_op_i != AMO_NONE);
                    access_w =  req_attr_i.store_like;
                end
                default: ;
            endcase
        end
    end

    friscv_pmp_check #(
        .PmpEntries ( PmpEntries )
    ) i_pmp_chk (
        .pa_i        ( req_addr_i      ),
        .access_r_i  ( access_r        ),
        .access_w_i  ( access_w        ),
        .access_x_i  ( access_x        ),
        .mode_i      ( req_attr_i.mode ),
        .pmp_table_i ( pmp_table_i     ),
        .fault_o     ( chk_fault       )
    );

    assign fault = chk_fault;
end else begin : gen_no_pmp_check
    assign fault = 1'b0;
end

// Suppress a denied request
assign mem_addr_o   = req_addr_i;
assign mem_size_o   = req_size_i;
assign mem_wdata_o  = req_wdata_i;
assign mem_rw_o     = fault ? RW_IDLE  : req_rw_i;
assign mem_amo_op_o = fault ? AMO_NONE : req_amo_op_i;

// Complete a denied request immediately (with an error)
assign req_rdata_o = mem_rdata_i;
assign req_wait_o  = fault ? 1'b0 : mem_wait_i;
assign req_err_o   = fault ? 1'b1 : mem_err_i;

endmodule
