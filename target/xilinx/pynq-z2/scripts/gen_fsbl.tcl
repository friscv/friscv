# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

# Usage: xsct gen_fsbl.tcl <xsa> <out_dir>

lassign $argv xsa_path out_dir

set hw [hsi::open_hw_design $xsa_path]
hsi::generate_app -hw $hw -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -compile -dir $out_dir
hsi::close_hw_design $hw

puts "FSBL generated in $out_dir"
