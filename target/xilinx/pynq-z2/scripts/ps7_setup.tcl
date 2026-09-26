# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

connect
targets -set -filter {name =~ "ARM*#0"}
catch {stop}

configparams force-mem-accesses 1

set RESET_GPIO 0x41200000

set RESET_PREV ""
set pl_configured 0
catch {set pl_configured [string match -nocase "*FPGA is configured*" [fpga -state]]}
if {$pl_configured && ![catch {mrd -value $RESET_GPIO} value]} {
    set RESET_PREV $value
    catch {mwr $RESET_GPIO 0x0}
    after 10
}

source $ps7_init
if {[catch {ps7_init} result]} {
    puts "ERROR: ps7_init failed: $result"
    puts "The PS7 initialization script may not match the programmed bitstream."
    disconnect
    exit 1
}
if {[catch {ps7_post_config} result]} {
    puts "ERROR: ps7_post_config failed: $result"
    disconnect
    exit 1
}

configparams force-mem-accesses 1
