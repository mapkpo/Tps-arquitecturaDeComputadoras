set script_dir   [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
if {[info exists ::env(TP_FINAL_VIVADO_DIR)]} {
    set project_file [file join [file normalize $::env(TP_FINAL_VIVADO_DIR)] tp_final.xpr]
} else {
    set project_file [file join $project_root vivado pipeline_test tp_final.xpr]
}

if {![file exists $project_file]} {
    error "No existe $project_file. Ejecutar primero scripts/create_project.tcl"
}

open_project $project_file
set_property top tb_top_memory_uart_smoke [get_filesets sim_1]
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
    {cmd.exe /d /c xsim.bat tb_top_memory_uart_smoke_behav -runall}
} {
    if {[catch {exec {*}$command 2>@1} output options]} {
        puts $output
        cd $previous_dir
        return -options $options $output
    }
    puts $output
}
set log_file [file join $sim_dir xsim.log]
set log_handle [open $log_file r]
set log_data [read $log_handle]
close $log_handle
if {[string first "RESULTADO: INTEGRACION UART-MEMORIAS RV32 OK" $log_data] < 0} {
    cd $previous_dir
    error "La simulación no alcanzó el resultado esperado. Revisar $log_file"
}
cd $previous_dir
puts "MEMORY_UART_SIMULATION_COMPLETE"
