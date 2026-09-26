// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
//
// Emil Popovic <mail@emilpopovic.me>

module friscv_axi_wrap #(
    // Must match sw/zsbl.ld
    parameter ZSBL_BASE       = 32'h0000_1000,
    parameter ZSBL_SIZE_BYTES = 1024,

    // Memory protection and address translation
    parameter ENABLE_MMU            = 1,
    parameter ENFORCE_PMP           = 1,
    parameter PMP_ENTRIES           = 16,
    parameter PMP_USABLE            = 5,
    // Must be a power of 2 greater than 1
    parameter ITLB_ENTRIES          = 4,
    parameter DTLB_ENTRIES          = 8,
    parameter ENABLE_FINE_TLB_FLUSH = 1,

    // Privilege modes and extensions
    parameter ENABLE_U_MODE         = 1,
    parameter ENABLE_S_MODE         = 1,
    parameter ENABLE_ISA_M          = 1,
    parameter ENABLE_FAST_MUL       = 1,
    parameter ENABLE_ISA_A          = 1,
    // If enabled, a write to 0x5000_0000 halts the core until reset
    parameter HALT_ON_END_ADDRESS   = 1
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axi, ASSOCIATED_RESET aresetn" *)
    input  wire aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire aresetn,

    output wire done,
    input  wire msip,
    input  wire mtip,
    input  wire meip,

    input  wire [63:0] mtime,

    // AXI4 Master Write Address Channel
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_awaddr,
    output wire [2:0]  m_axi_awsize,
    output wire [3:0]  m_axi_awcache,
    output wire [2:0]  m_axi_awprot,
    output wire [1:0]  m_axi_awburst,
    output wire [7:0]  m_axi_awlen,
    output wire        m_axi_awlock,
    output wire [3:0]  m_axi_awqos,

    // AXI4 Master Write Data Channel
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    output wire        m_axi_wlast,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,

    // AXI4 Master Write Response Channel
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    input  wire [1:0]  m_axi_bresp,

    // AXI4 Master Read Address Channel
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    output wire [31:0] m_axi_araddr,
    output wire [2:0]  m_axi_arsize,
    output wire [3:0]  m_axi_arcache,
    output wire [2:0]  m_axi_arprot,
    output wire [1:0]  m_axi_arburst,
    output wire [7:0]  m_axi_arlen,
    output wire        m_axi_arlock,
    output wire [3:0]  m_axi_arqos,

    // AXI4 Master Read Data Channel
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,
    input  wire        m_axi_rlast,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp
);

friscv_axi #(
    .ZsblBase           ( ZSBL_BASE             ),
    .ZsblSizeBytes      ( ZSBL_SIZE_BYTES       ),
    .EnableMmu          ( ENABLE_MMU            ),
    .EnforcePmp         ( ENFORCE_PMP           ),
    .PmpEntries         ( PMP_ENTRIES           ),
    .PmpUsable          ( PMP_USABLE            ),
    .ItlbEntries        ( ITLB_ENTRIES          ),
    .DtlbEntries        ( DTLB_ENTRIES          ),
    .EnableFineTlbFlush ( ENABLE_FINE_TLB_FLUSH ),
    .EnableUMode        ( ENABLE_U_MODE         ),
    .EnableSMode        ( ENABLE_S_MODE         ),
    .EnableIsaM         ( ENABLE_ISA_M          ),
    .EnableFastMul      ( ENABLE_FAST_MUL       ),
    .EnableIsaA         ( ENABLE_ISA_A          ),
    .HaltOnEndAddress   ( HALT_ON_END_ADDRESS   )
) i_friscv_axi (
    .clk_i          ( aclk          ),
    .rst_ni         ( aresetn       ),
    .end_o          ( done          ),
    .msip_i         ( msip          ),
    .mtip_i         ( mtip          ),
    .meip_i         ( meip          ),
    .mtime_i        ( mtime         ),
    .m_axi_awvalid  ( m_axi_awvalid ),
    .m_axi_awready  ( m_axi_awready ),
    .m_axi_awaddr   ( m_axi_awaddr  ),
    .m_axi_awsize   ( m_axi_awsize  ),
    .m_axi_awcache  ( m_axi_awcache ),
    .m_axi_awprot   ( m_axi_awprot  ),
    .m_axi_awburst  ( m_axi_awburst ),
    .m_axi_awlen    ( m_axi_awlen   ),
    .m_axi_awlock   ( m_axi_awlock  ),
    .m_axi_awqos    ( m_axi_awqos   ),
    .m_axi_wvalid   ( m_axi_wvalid  ),
    .m_axi_wready   ( m_axi_wready  ),
    .m_axi_wlast    ( m_axi_wlast   ),
    .m_axi_wdata    ( m_axi_wdata   ),
    .m_axi_wstrb    ( m_axi_wstrb   ),
    .m_axi_bvalid   ( m_axi_bvalid  ),
    .m_axi_bready   ( m_axi_bready  ),
    .m_axi_bresp    ( m_axi_bresp   ),
    .m_axi_arvalid  ( m_axi_arvalid ),
    .m_axi_arready  ( m_axi_arready ),
    .m_axi_araddr   ( m_axi_araddr  ),
    .m_axi_arsize   ( m_axi_arsize  ),
    .m_axi_arcache  ( m_axi_arcache ),
    .m_axi_arprot   ( m_axi_arprot  ),
    .m_axi_arburst  ( m_axi_arburst ),
    .m_axi_arlen    ( m_axi_arlen   ),
    .m_axi_arlock   ( m_axi_arlock  ),
    .m_axi_arqos    ( m_axi_arqos   ),
    .m_axi_rvalid   ( m_axi_rvalid  ),
    .m_axi_rready   ( m_axi_rready  ),
    .m_axi_rlast    ( m_axi_rlast   ),
    .m_axi_rdata    ( m_axi_rdata   ),
    .m_axi_rresp    ( m_axi_rresp   )
);

endmodule
