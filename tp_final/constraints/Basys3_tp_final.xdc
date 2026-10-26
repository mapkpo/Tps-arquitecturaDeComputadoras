###############################################################################
## TP final RISC-V + Debug Unit - Basys 3
## Interfaz común de los tops incrementales: UART a 115200 baud, 8N1.
###############################################################################

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## Clock de placa: 100 MHz
set_property PACKAGE_PIN W5 [get_ports i_clk]
set_property IOSTANDARD LVCMOS33 [get_ports i_clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports i_clk]

## Reset activo en alto: botón central BTNC
set_property PACKAGE_PIN U18 [get_ports i_rst]
set_property IOSTANDARD LVCMOS33 [get_ports i_rst]

## Conversor USB-UART integrado de la Basys 3
set_property PACKAGE_PIN B18 [get_ports i_uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports i_uart_rx]
set_property PACKAGE_PIN A18 [get_ports o_uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports o_uart_tx]

## LED7:LED0 muestran el último byte recibido
set_property PACKAGE_PIN U16 [get_ports {o_leds[0]}]
set_property PACKAGE_PIN E19 [get_ports {o_leds[1]}]
set_property PACKAGE_PIN U19 [get_ports {o_leds[2]}]
set_property PACKAGE_PIN V19 [get_ports {o_leds[3]}]
set_property PACKAGE_PIN W18 [get_ports {o_leds[4]}]
set_property PACKAGE_PIN U15 [get_ports {o_leds[5]}]
set_property PACKAGE_PIN U14 [get_ports {o_leds[6]}]
set_property PACKAGE_PIN V14 [get_ports {o_leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[*]}]

## Diagnóstico UART: LED11 y LED12
set_property PACKAGE_PIN U3 [get_ports o_rx_overrun]
set_property PACKAGE_PIN P3 [get_ports o_frame_error]
set_property IOSTANDARD LVCMOS33 [get_ports {o_rx_overrun o_frame_error}]
