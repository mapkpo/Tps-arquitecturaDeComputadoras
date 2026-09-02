###############################################################################
## ALU - Basys 3
##
## Entradas:
##   SW0-SW7  -> datos A, B y OP
##   BTN L    -> cargar registro A
##   BTN C    -> cargar registro B
##   BTN R    -> cargar registro OP
##
## Salidas:
##   LED0-7   -> resultado ALU
##   LED8     -> Zero
##   LED9     -> Carry
##   LED10    -> Overflow
###############################################################################


###############################################################################
## CLOCK 100 MHz
###############################################################################

set_property PACKAGE_PIN W5 [get_ports i_clk]
set_property IOSTANDARD LVCMOS33 [get_ports i_clk]

create_clock -period 10.000 -name sys_clk_pin \
    -waveform {0.000 5.000} [get_ports i_clk]


###############################################################################
## SWITCHES
###############################################################################

## SW0
set_property PACKAGE_PIN V17 [get_ports {i_switches[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[0]}]

## SW1
set_property PACKAGE_PIN V16 [get_ports {i_switches[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[1]}]

## SW2
set_property PACKAGE_PIN W16 [get_ports {i_switches[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[2]}]

## SW3
set_property PACKAGE_PIN W17 [get_ports {i_switches[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[3]}]

## SW4
set_property PACKAGE_PIN W15 [get_ports {i_switches[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[4]}]

## SW5
set_property PACKAGE_PIN V15 [get_ports {i_switches[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[5]}]

## SW6
set_property PACKAGE_PIN W14 [get_ports {i_switches[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[6]}]

## SW7
set_property PACKAGE_PIN W13 [get_ports {i_switches[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[7]}]


###############################################################################
## BOTONES
###############################################################################

## BTN LEFT - carga A
## W19
set_property PACKAGE_PIN W19 [get_ports i_btn_A]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_A]


## BTN CENTER - carga B
## U18
set_property PACKAGE_PIN U18 [get_ports i_btn_B]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_B]


## BTN RIGHT - carga OP
## T17
set_property PACKAGE_PIN T17 [get_ports i_btn_OP]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_OP]

## BTN UP - reset general
## T18
set_property PACKAGE_PIN T18 [get_ports i_btn_RST]
set_property IOSTANDARD LVCMOS33 [get_ports i_btn_RST]



###############################################################################
## LEDs - RESULTADO DE LA ALU
###############################################################################

## LED0
set_property PACKAGE_PIN U16 [get_ports {o_leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[0]}]

## LED1
set_property PACKAGE_PIN E19 [get_ports {o_leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[1]}]

## LED2
set_property PACKAGE_PIN U19 [get_ports {o_leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[2]}]

## LED3
set_property PACKAGE_PIN V19 [get_ports {o_leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[3]}]

## LED4
set_property PACKAGE_PIN W18 [get_ports {o_leds[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[4]}]

## LED5
set_property PACKAGE_PIN U15 [get_ports {o_leds[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[5]}]

## LED6
set_property PACKAGE_PIN U14 [get_ports {o_leds[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[6]}]

## LED7
set_property PACKAGE_PIN V14 [get_ports {o_leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[7]}]


###############################################################################
## FLAGS
###############################################################################

## LED8 - ZERO
set_property PACKAGE_PIN U3 [get_ports o_zero]
set_property IOSTANDARD LVCMOS33 [get_ports o_zero]


## LED9 - CARRY
set_property PACKAGE_PIN N3 [get_ports o_carry]
set_property IOSTANDARD LVCMOS33 [get_ports o_carry]


## LED10 - OVERFLOW
set_property PACKAGE_PIN L1 [get_ports o_overflow]
set_property IOSTANDARD LVCMOS33 [get_ports o_overflow]