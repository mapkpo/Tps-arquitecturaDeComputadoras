set script_dir  [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
if {[info exists ::env(TP_FINAL_VIVADO_DIR)]} {
    set project_dir [file normalize $::env(TP_FINAL_VIVADO_DIR)]
} else {
    set project_dir [file join $project_root vivado pipeline_test]
}

file mkdir [file dirname $project_dir]
create_project tp_final $project_dir -part xc7a35tcpg236-1 -force

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

set rtl_files [concat \
    [glob -nocomplain [file join $project_root rtl common *.v]] \
    [glob -nocomplain [file join $project_root rtl core *.v]] \
    [glob -nocomplain [file join $project_root rtl core *.sv]] \
    [glob -nocomplain [file join $project_root rtl memory *.v]] \
    [glob -nocomplain [file join $project_root rtl memory *.sv]] \
    [glob -nocomplain [file join $project_root rtl debug *.v]] \
    [glob -nocomplain [file join $project_root rtl debug *.sv]] \
    [glob -nocomplain [file join $project_root rtl top *.v]] \
    [glob -nocomplain [file join $project_root rtl top *.sv]]]

if {[llength $rtl_files] == 0} {
    error "No se encontraron fuentes RTL"
}

add_files -fileset sources_1 -norecurse $rtl_files
set_property top top_tp_final [get_filesets sources_1]

set constraint_file [file join $project_root constraints Basys3_tp_final.xdc]
set cp2102_constraint_file [file join $project_root constraints Basys3_tp_final_cp2102.xdc]
add_files -fileset constrs_1 -norecurse [list $constraint_file $cp2102_constraint_file]
set_property USED_IN_SYNTHESIS false [get_files [list $cp2102_constraint_file]]
set_property USED_IN_IMPLEMENTATION false [get_files [list $cp2102_constraint_file]]
set_property target_constrs_file $constraint_file [get_filesets constrs_1]

set sim_files [concat \
    [glob -nocomplain [file join $project_root sim unit *.v]] \
    [glob -nocomplain [file join $project_root sim unit *.sv]] \
    [glob -nocomplain [file join $project_root sim integration *.v]] \
    [glob -nocomplain [file join $project_root sim integration *.sv]]]

if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 -norecurse $sim_files
    set_property top tb_uart [get_filesets sim_1]
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "PROJECT_CREATED: [file join $project_dir tp_final.xpr]"
close_project
