set script_dir   [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
set project_file [file join $project_root vivado pipeline_test tp_final.xpr]
set report_dir   [file join $project_root reports final]

if {![file exists $project_file]} {
    error "No existe $project_file. Ejecutar primero scripts/create_project.tcl"
}

file mkdir $report_dir
open_project $project_file

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set run_status [get_property STATUS [get_runs synth_1]]
puts "SYNTHESIS_STATUS: $run_status"
if {[string first "Complete" $run_status] < 0} {
    error "La síntesis no terminó correctamente: $run_status"
}

open_run synth_1
report_utilization -file [file join $report_dir synthesis_utilization_90mhz.rpt]
report_timing_summary -file [file join $report_dir synthesis_timing_90mhz.rpt]

close_project
puts "SYNTHESIS_COMPLETE"
