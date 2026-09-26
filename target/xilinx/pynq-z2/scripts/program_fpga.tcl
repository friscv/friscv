# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

# Usage: vivado -mode batch -source program_fpga.tcl -tclargs <bitstream_path>

if { $argc != 1 } {
    puts "ERROR: Bitstream path required"
    puts "Usage: vivado -mode batch -source program_fpga.tcl -tclargs <bitstream.bit>"
    exit 1
}

set bitstream_path [lindex $argv 0]

if { ![file exists $bitstream_path] } {
    puts "ERROR: Bitstream file not found: $bitstream_path"
    exit 1
}

open_hw_manager

connect_hw_server -allow_non_jtag

# Auto-detect and open target
set targets [get_hw_targets]
if { [llength $targets] == 0 } {
    puts "ERROR: No hardware targets found. Is the board connected?"
    exit 1
}

open_hw_target [lindex $targets 0]

# Get the FPGA device
set devices [get_hw_devices]
if { [llength $devices] == 0 } {
    puts "ERROR: No FPGA devices found in the JTAG chain"
    exit 1
}

# Find the programmable FPGA device (skip ARM DAP)
set fpga_device ""
foreach device $devices {
    puts "Found device: $device"
    # Skip ARM Debug Access Port
    if { [string match "*arm_dap*" $device] } {
        puts "  -> Skipping (ARM DAP, not programmable)"
        continue
    }
    # This should be the FPGA
    set fpga_device $device
    puts "  -> Selected for programming"
    break
}

if { $fpga_device == "" } {
    puts "ERROR: No programmable FPGA device found in the JTAG chain"
    exit 1
}

# Set the bitstream
current_hw_device $fpga_device
set_property PROGRAM.FILE $bitstream_path $fpga_device

# Program the device
puts "Programming device..."
program_hw_devices $fpga_device

# Verify
refresh_hw_device $fpga_device

# Cleanup
close_hw_target
disconnect_hw_server
close_hw_manager
