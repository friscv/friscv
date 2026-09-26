// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
//
// Emil Popovic <mail@emilpopovic.me>

module friscv_axi
    import friscv_mem_pkg::friscv_mem_req_t;
    import friscv_mem_pkg::friscv_mem_rsp_t;
#(
    parameter int unsigned ZsblBase      = 32'h0000_1000,
    parameter int unsigned ZsblSizeBytes = 1024,

    parameter bit          EnableMmu          = 1,
    parameter bit          EnforcePmp         = 1,
    parameter int unsigned PmpEntries         = 16,
    parameter int unsigned PmpUsable          = 16,
    parameter int unsigned ItlbEntries        = 8,
    parameter int unsigned DtlbEntries        = 16,
    parameter bit          EnableFineTlbFlush = 0,
    parameter bit          EnableUMode        = 1,
    parameter bit          EnableSMode        = 1,
    parameter bit          EnableIsaM         = 1,
    parameter bit          EnableFastMul      = 0,
    parameter bit          EnableIsaA         = 1,
    parameter bit          HaltOnEndAddress   = 0
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    output logic        end_o,

    input  logic        msip_i,
    input  logic        mtip_i,
    input  logic        meip_i,

    input  logic [63:0] mtime_i,

    // AXI4 Manager Write Address Channel
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,
    output logic [31:0] m_axi_awaddr,
    output logic [2:0]  m_axi_awsize,
    output logic [3:0]  m_axi_awcache,
    output logic [2:0]  m_axi_awprot,
    output logic [1:0]  m_axi_awburst,
    output logic [7:0]  m_axi_awlen,
    output logic        m_axi_awlock,
    output logic [3:0]  m_axi_awqos,

    // AXI4 Manager Write Data Channel
    output logic        m_axi_wvalid,
    input  logic        m_axi_wready,
    output logic        m_axi_wlast,
    output logic [31:0] m_axi_wdata,
    output logic [3:0]  m_axi_wstrb,

    // AXI4 Manager Write Response Channel
    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,
    input  logic [1:0]  m_axi_bresp,

    // AXI4 Manager Read Address Channel
    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,
    output logic [31:0] m_axi_araddr,
    output logic [2:0]  m_axi_arsize,
    output logic [3:0]  m_axi_arcache,
    output logic [2:0]  m_axi_arprot,
    output logic [1:0]  m_axi_arburst,
    output logic [7:0]  m_axi_arlen,
    output logic        m_axi_arlock,
    output logic [3:0]  m_axi_arqos,

    // AXI4 Manager Read Data Channel
    input  logic        m_axi_rvalid,
    output logic        m_axi_rready,
    input  logic        m_axi_rlast,
    input  logic [31:0] m_axi_rdata,
    input  logic [1:0]  m_axi_rresp
);

localparam int unsigned DramBase = 32'h8000_0000;
localparam int unsigned ResetVec = (ZsblSizeBytes > 0) ? ZsblBase : DramBase;

// Reset synchronizer
logic w_rst_n;

sync #(
    .STAGES     ( 2    ),
    .ResetValue ( 1'b0 )
) i_rst_sync (
    .clk_i,
    .rst_ni,
    .serial_i ( 1'b1    ),
    .serial_o ( w_rst_n )
);

friscv_mem_req_t core_req, rom_req, axi_req;
friscv_mem_rsp_t core_rsp, rom_rsp;

friscv_axi_pkg::axi_req_t  m_axi_req;
friscv_axi_pkg::axi_resp_t m_axi_rsp;

////////////////////////////
// Deferred adapter reset //
////////////////////////////

/* verilator lint_off PROCASSINIT */
logic r_axi_busy = 1'b0;
logic r_axi_rst  = 1'b1;
/* verilator lint_on PROCASSINIT */
logic w_axi_idle;
logic r_rst_pending;
logic r_core_rst_n;
logic w_axi_rst_n;

assign w_axi_rst_n = !r_axi_rst;

assign w_axi_idle = !r_axi_busy && !m_axi_req.aw_valid && !m_axi_req.ar_valid;

always_ff @(posedge clk_i) begin
    if (r_axi_rst ||
        (m_axi_rsp.b_valid && m_axi_req.b_ready) ||
        (m_axi_rsp.r_valid && m_axi_req.r_ready && m_axi_rsp.r.last))
        r_axi_busy <= 1'b0;
    else if (m_axi_req.aw_valid || m_axi_req.ar_valid)
        r_axi_busy <= 1'b1;
end

always_ff @(posedge clk_i or negedge w_rst_n) begin
    if (!w_rst_n)
        r_rst_pending <= 1'b1;
    else if (r_axi_rst)
        r_rst_pending <= 1'b0;
end

always_ff @(posedge clk_i) begin
    if (!r_rst_pending)
        r_axi_rst <= 1'b0;
    else if (w_axi_idle)
        r_axi_rst <= 1'b1;
end

always_ff @(posedge clk_i or negedge w_rst_n) begin
    if (!w_rst_n)
        r_core_rst_n <= 1'b0;
    else
        r_core_rst_n <= !r_rst_pending && !r_axi_rst;
end

////////////////////////
// System connections //
////////////////////////

friscv #(
    .ResetVec           ( ResetVec           ),
    .EnableMmu          ( EnableMmu          ),
    .EnforcePmp         ( EnforcePmp         ),
    .PmpEntries         ( PmpEntries         ),
    .PmpUsable          ( PmpUsable          ),
    .ItlbEntries        ( ItlbEntries        ),
    .DtlbEntries        ( DtlbEntries        ),
    .EnableFineTlbFlush ( EnableFineTlbFlush ),
    .EnableUMode        ( EnableUMode        ),
    .EnableSMode        ( EnableSMode        ),
    .EnableIsaM         ( EnableIsaM         ),
    .EnableFastMul      ( EnableFastMul      ),
    .EnableIsaA         ( EnableIsaA         ),
    .HaltOnEndAddress   ( HaltOnEndAddress   )
) i_core (
    .clk_i,
    .rst_ni    ( r_core_rst_n ),
    .end_o,
    .msip_i,
    .mtip_i,
    .meip_i,
    .seip_i    ( 1'b0         ),
    .mtime_i,
    .mem_req_o ( core_req     ),
    .mem_rsp_i ( core_rsp     ),
    .dbg_req_i ( 1'b0         )
);

if (ZsblSizeBytes > 0) begin : gen_zsbl
    friscv_zsbl #(
        .Base      ( ZsblBase      ),
        .SizeBytes ( ZsblSizeBytes )
    ) i_zsbl (
        .clk_i,
        .rst_ni  ( r_core_rst_n ),
        .s_req_i ( core_req     ),
        .s_rsp_o ( core_rsp ),
        .m_req_o ( rom_req  ),
        .m_rsp_i ( rom_rsp  )
    );
end else begin : gen_no_zsbl
    assign rom_req  = core_req;
    assign core_rsp = rom_rsp;
end

// SoC-specific address remapping
logic [31:0] w_remapped_addr;

friscv_remap i_remap (
    .i_addr ( rom_req.addr    ),
    .o_addr ( w_remapped_addr )
);

always_comb begin
    axi_req      = rom_req;
    axi_req.addr = w_remapped_addr;
end

friscv_to_axi4_full i_to_axi (
    .clk_i,
    .rst_ni      ( w_axi_rst_n ),
    .s_req_i     ( axi_req     ),
    .s_rsp_o     ( rom_rsp     ),
    .m_axi_req_o ( m_axi_req   ),
    .m_axi_rsp_i ( m_axi_rsp   )
);

// Flatten AXI from structs
assign m_axi_awvalid = m_axi_req.aw_valid;
assign m_axi_awaddr  = m_axi_req.aw.addr;
assign m_axi_awsize  = m_axi_req.aw.size;
assign m_axi_awcache = m_axi_req.aw.cache;
assign m_axi_awprot  = m_axi_req.aw.prot;
assign m_axi_awburst = m_axi_req.aw.burst;
assign m_axi_awlen   = m_axi_req.aw.len;
assign m_axi_awlock  = m_axi_req.aw.lock;
assign m_axi_awqos   = m_axi_req.aw.qos;

assign m_axi_wvalid  = m_axi_req.w_valid;
assign m_axi_wlast   = m_axi_req.w.last;
assign m_axi_wdata   = m_axi_req.w.data;
assign m_axi_wstrb   = m_axi_req.w.strb;

assign m_axi_bready  = m_axi_req.b_ready;

assign m_axi_arvalid = m_axi_req.ar_valid;
assign m_axi_araddr  = m_axi_req.ar.addr;
assign m_axi_arsize  = m_axi_req.ar.size;
assign m_axi_arcache = m_axi_req.ar.cache;
assign m_axi_arprot  = m_axi_req.ar.prot;
assign m_axi_arburst = m_axi_req.ar.burst;
assign m_axi_arlen   = m_axi_req.ar.len;
assign m_axi_arlock  = m_axi_req.ar.lock;
assign m_axi_arqos   = m_axi_req.ar.qos;

assign m_axi_rready  = m_axi_req.r_ready;

always_comb begin
    m_axi_rsp          = '0;
    m_axi_rsp.aw_ready = m_axi_awready;
    m_axi_rsp.w_ready  = m_axi_wready;
    m_axi_rsp.b_valid  = m_axi_bvalid;
    m_axi_rsp.b.resp   = m_axi_bresp;
    m_axi_rsp.ar_ready = m_axi_arready;
    m_axi_rsp.r_valid  = m_axi_rvalid;
    m_axi_rsp.r.data   = m_axi_rdata;
    m_axi_rsp.r.resp   = m_axi_rresp;
    m_axi_rsp.r.last   = m_axi_rlast;
end

endmodule
