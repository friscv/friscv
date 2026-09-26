# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

# Usage: vivado -mode batch -source create_project.tcl -tclargs <project_dir> <project_name> <sources.tcl>

if {$argc != 3} {
    puts "ERROR: usage: create_project.tcl <project_dir> <project_name> <sources.tcl>"
    exit 1
}
lassign $argv project_dir project_name sources_tcl

set target_dir [file normalize [file dirname [info script]]/..]
set sim_dir    [file normalize ${target_dir}/../sim]

set part       "xc7z020clg400-1"
set board_part "tul.com.tw:pynq-z2:part0:1.0"

create_project ${project_name} ${project_dir} -part ${part} -force

if {[lsearch -exact [get_board_parts -quiet] ${board_part}] != -1} {
    set_property board_part ${board_part} [current_project]
} else {
    puts "WARNING: PYNQ-Z2 board files not found, creating the project with part ${part} only"
}

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

source ${sources_tcl}

foreach dir [get_property include_dirs [current_fileset]] {
    set headers [glob -nocomplain -types f -directory ${dir} *.svh */*.svh]
    if {[llength ${headers}] > 0} {
        add_files -norecurse ${headers}
        set_property file_type {Verilog Header} [get_files ${headers}]
    }
}

add_files -norecurse -fileset constrs_1 [glob ${target_dir}/constraints/*.xdc]

set ::origin_dir_loc ${project_dir}/bd
source ${target_dir}/bd/design1.tcl
set bd_file [get_files design_1.bd]
regenerate_bd_layout
validate_bd_design
save_bd_design
generate_target all ${bd_file}
add_files -norecurse [make_wrapper -files ${bd_file} -top]

set_property top design_1_wrapper [current_fileset]
set_property top_auto_set 0 [current_fileset]
update_compile_order -fileset sources_1

set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

add_files -norecurse -fileset sim_1 ${sim_dir}/tb_integration.sv
add_files -norecurse -fileset sim_1 ${sim_dir}/tb_integration_behav.wcfg
set_property top tb_integration [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property xsim.view ${sim_dir}/tb_integration_behav.wcfg [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Project created: ${project_dir}/${project_name}.xpr"
