# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

# Usage: xsdb check_status.tcl <ps7_init.tcl>

lassign $argv ps7_init
source [file join [file dirname [info script]] ps7_setup.tcl]

puts "\nFirst instructions at 0x00100000:"
if {[catch {mrd 0x00100000 16} result]} {
    puts "ERROR reading memory at 0x00100000: $result"
} else {
    puts $result
}

# Continue if previously running
if {$RESET_PREV ne ""} {
    mwr $RESET_GPIO $RESET_PREV
}

disconnect
exit
