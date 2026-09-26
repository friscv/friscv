# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

# Usage: xsdb init_ps.tcl <ps7_init.tcl>

lassign $argv ps7_init
source [file join [file dirname [info script]] ps7_setup.tcl]

disconnect
exit
