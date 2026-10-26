set script_dir   [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
set project_file [file join $project_root vivado pipeline_test tp_final.xpr]

if {![file exists $project_file]} {
    error "No existe $project_file. Ejecutar primero scripts/create_project.tcl"
}

open_project $project_file
set_property top tb_rv32_alu [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
close_project

puts "ALU_SIMULATION_COMPLETE"
