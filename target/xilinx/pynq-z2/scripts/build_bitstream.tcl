# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

# Usage: vivado -mode batch -source build_bitstream.tcl -tclargs <project.xpr> <out_dir> <jobs>

if {$argc != 3} {
    puts "ERROR: usage: build_bitstream.tcl <project.xpr> <out_dir> <jobs>"
    exit 1
}
lassign $argv project_xpr out_dir jobs

file mkdir ${out_dir}
open_project ${project_xpr}

set bd_file [get_files design_1.bd]
open_bd_design ${bd_file}

set modrefs [get_ips -quiet -filter {IPDEF =~ "*:module_ref:*"}]
if {[llength ${modrefs}] > 0} {
    update_module_reference ${modrefs}
    foreach ip ${modrefs} {
        reset_run -quiet [get_runs -quiet ${ip}_synth_1]
    }
}

validate_bd_design -force
save_bd_design
generate_target all ${bd_file}

reset_run synth_1
launch_runs synth_1 -jobs ${jobs}
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: synthesis failed"
    exit 1
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs ${jobs}
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: implementation failed"
    exit 1
}

open_run impl_1
report_timing_summary -file ${out_dir}/timing_summary.rpt
report_utilization -file ${out_dir}/utilization.rpt

set impl_dir [get_property DIRECTORY [get_runs impl_1]]
file copy -force ${impl_dir}/design_1_wrapper.bit ${out_dir}/friscv.bit
file copy -force [lindex [get_files -all -of_objects ${bd_file} design_1.hwh] 0] ${out_dir}/friscv.hwh
write_hw_platform -fixed -include_bit -force -file ${out_dir}/friscv.xsa

set wns [get_property STATS.WNS [get_runs impl_1]]
set whs [get_property STATS.WHS [get_runs impl_1]]
puts "Timing: WNS ${wns} ns, WHS ${whs} ns"
if {$wns < 0 || $whs < 0} {
    puts "CRITICAL: timing not met, see ${out_dir}/timing_summary.rpt"
}
