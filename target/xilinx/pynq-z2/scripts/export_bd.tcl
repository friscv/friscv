# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

# Usage: vivado -mode batch -source export_bd.tcl -tclargs <project.xpr>

if {$argc != 1} {
    puts "ERROR: usage: export_bd.tcl <project.xpr>"
    exit 1
}
lassign $argv project_xpr

set target_dir [file normalize [file dirname [info script]]/..]
set bd_tcl     ${target_dir}/bd/design1.tcl

open_project ${project_xpr}
open_bd_design [get_files design_1.bd]

if {[catch {validate_bd_design} err]} {
    puts "ERROR: block design validation failed, not exporting:\n${err}"
    exit 1
}

write_bd_tcl -force ${bd_tcl}
puts "Exported design_1 to ${bd_tcl}"
