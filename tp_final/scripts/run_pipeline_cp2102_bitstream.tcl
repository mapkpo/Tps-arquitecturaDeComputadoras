set script_dir   [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
if {[info exists ::env(TP_FINAL_VIVADO_DIR)]} {
    set project_file [file join [file normalize $::env(TP_FINAL_VIVADO_DIR)] tp_final.xpr]
} else {
    set project_file [file join $project_root vivado pipeline_test tp_final.xpr]
}
set report_dir [file join $project_root reports final]
set output_dir [file join $project_root output bitstream]
set integrated_xdc [file join $project_root constraints Basys3_tp_final.xdc]
set cp2102_xdc [file join $project_root constraints Basys3_tp_final_cp2102.xdc]

if {![file exists $project_file]} {
    error "No existe $project_file. Ejecutar primero scripts/create_project.tcl"
}
if {![file exists $cp2102_xdc]} {
    error "No existe la constraint CP2102: $cp2102_xdc"
}

file mkdir $report_dir
file mkdir $output_dir
open_project $project_file

if {[llength [get_files -quiet [list $cp2102_xdc]]] == 0} {
    add_files -fileset constrs_1 -norecurse [list $cp2102_xdc]
}

set_property USED_IN_SYNTHESIS false [get_files [list $integrated_xdc]]
set_property USED_IN_IMPLEMENTATION false [get_files [list $integrated_xdc]]
set_property USED_IN_SYNTHESIS true [get_files [list $cp2102_xdc]]
set_property USED_IN_IMPLEMENTATION true [get_files [list $cp2102_xdc]]
set_property target_constrs_file $cp2102_xdc [get_filesets constrs_1]

set_property top top_tp_final [get_filesets sources_1]
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set run_status [get_property STATUS [get_runs impl_1]]
puts "IMPLEMENTATION_STATUS: $run_status"
if {[string first "Complete" $run_status] < 0} {
    error "La implementacion CP2102 no termino correctamente: $run_status"
}

open_run impl_1
report_utilization -hierarchical -file [file join $report_dir utilization_90mhz_cp2102.rpt]
report_timing_summary -file [file join $report_dir timing_90mhz_cp2102.rpt]
report_drc -file [file join $report_dir drc_90mhz_cp2102.rpt]

set run_dir [get_property DIRECTORY [get_runs impl_1]]
set generated_bit [file join $run_dir top_tp_final.bit]
set stable_bit [file join $output_dir top_tp_final_90mhz_cp2102.bit]
if {![file exists $generated_bit]} {
    error "No se encontro el bitstream generado: $generated_bit"
}
file copy -force $generated_bit $stable_bit

## El proyecto queda nuevamente configurado para la variante integrada.
set_property USED_IN_SYNTHESIS true [get_files [list $integrated_xdc]]
set_property USED_IN_IMPLEMENTATION true [get_files [list $integrated_xdc]]
set_property USED_IN_SYNTHESIS false [get_files [list $cp2102_xdc]]
set_property USED_IN_IMPLEMENTATION false [get_files [list $cp2102_xdc]]
set_property target_constrs_file $integrated_xdc [get_filesets constrs_1]
close_project

puts "BITSTREAM_CP2102_READY: $stable_bit"
