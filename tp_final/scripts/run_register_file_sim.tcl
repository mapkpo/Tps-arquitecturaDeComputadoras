set script_dir   [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
set project_file [file join $project_root vivado pipeline_test tp_final.xpr]

if {![file exists $project_file]} {
    error "No existe $project_file. Ejecutar primero scripts/create_project.tcl"
}

open_project $project_file
set_property top tb_rv32_register_file [get_filesets sim_1]
reset_simulation -simset sim_1
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral -scripts_only
close_project

set sim_dir [file join [file dirname $project_file] tp_final.sim sim_1 behav xsim]
set previous_dir [pwd]
cd $sim_dir

foreach command {
    {cmd.exe /d /c compile.bat}
    {cmd.exe /d /c elaborate.bat}
    {cmd.exe /d /c xsim.bat tb_rv32_register_file_behav -runall}
} {
    if {[catch {exec {*}$command 2>@1} output options]} {
        puts $output
        cd $previous_dir
        return -options $options $output
    }
    puts $output
}

cd $previous_dir
puts "REGISTER_FILE_SIMULATION_COMPLETE"
