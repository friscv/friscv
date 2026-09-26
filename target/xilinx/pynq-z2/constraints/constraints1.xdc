# End signal connected to LD5 green
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports { done_out }];
set_false_path -to [get_ports done_out]

# Reset signal connected to LD5 red
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { rst_out }];
set_false_path -to [get_ports rst_out]

# UART on RPI pins 8 and 10
set_property -dict { PACKAGE_PIN V6 IOSTANDARD LVCMOS33 } [get_ports uart_tx ];
set_property -dict { PACKAGE_PIN Y6 IOSTANDARD LVCMOS33 } [get_ports uart_rx ];
set_false_path -to [get_ports uart_tx]
set_false_path -from [get_ports uart_rx]

# LEDs
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led[3] }];
set_false_path -to [get_ports {led[*]}]

# Buttons
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {btns_in[0]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {btns_in[1]}]
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33} [get_ports {btns_in[2]}]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33} [get_ports {btns_in[3]}]
set_false_path -from [get_ports {btns_in[*]}]

# Switches
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { sw_in[0] }];
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { sw_in[1] }];
set_false_path -from [get_ports {sw_in[*]}]

# RGB LED via Baseboard
set_property -dict { PACKAGE_PIN W9 IOSTANDARD LVCMOS33 } [get_ports { rgb_out[0] }]; #red
set_property -dict { PACKAGE_PIN W8 IOSTANDARD LVCMOS33 } [get_ports { rgb_out[1] }]; #green
set_property -dict { PACKAGE_PIN Y8 IOSTANDARD LVCMOS33 } [get_ports { rgb_out[2] }]; #blue
set_false_path -to [get_ports {rgb_out[*]}]
