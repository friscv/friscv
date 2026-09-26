# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

# Usage: xsdb load_program.tcl <ps7_init.tcl> <program.bin> <dram_base>

lassign $argv ps7_init bin_file ddr_base
source [file join [file dirname [info script]] ps7_setup.tcl]

# Wait for DDR to stabilize
after 1000

mwr $RESET_GPIO 0x0

# Zero the program area rounded up to 4 KiB
set zero_words [expr {((([file size $bin_file] + 4095) / 4096) * 4096) / 4}]
set burst_words 1024
puts "Zeroing memory..."
for {set word_idx 0} {$word_idx < $zero_words} {incr word_idx $burst_words} {
    set words [expr {min($burst_words, $zero_words - $word_idx)}]
    mwr [expr {$ddr_base + $word_idx * 4}] 0x0 $words
}

puts "Loading program..."
dow -data $bin_file $ddr_base

disconnect
exit
