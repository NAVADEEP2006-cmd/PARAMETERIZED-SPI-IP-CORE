# ==============================================================================
# run_vivado.tcl - Reproducible AMD Vivado Automation Flow for SPI IP Core
#
# Supported execution modes:
#   -mode elaborate : Perform non-device-specific RTL elaboration & design analysis
#   -mode synth     : Synthesize IP core for the specified target FPGA part (OOC)
#   -mode impl      : Run complete flow: Synthesis -> opt -> place -> phys_opt -> route
#   -mode sim       : Execute functional verification using AMD Vivado XSim
#   -mode all       : Run implementation flow followed by XSim functional verification
#
# Usage examples:
#   vivado -mode batch -notrace -source scripts/vivado/run_vivado.tcl -tclargs -mode elaborate
#   vivado -mode batch -notrace -source scripts/vivado/run_vivado.tcl -tclargs -mode impl -part xc7a35tcsg324-1
#   vivado -mode batch -notrace -source scripts/vivado/run_vivado.tcl -tclargs -mode sim
# ==============================================================================

set SCRIPT_DIR  [file normalize [file dirname [info script]]]
set REPO_DIR    [file normalize "$SCRIPT_DIR/../.."]
set RTL_DIR     "$REPO_DIR/rtl"
set TB_DIR      "$REPO_DIR/tb"
set CONSTR_DIR  "$REPO_DIR/constraints"
set REPORTS_DIR "$REPO_DIR/reports/vivado"

# Default configuration
set MODE        "elaborate"
set TOP         "spi_master_top"
set PART        "xc7a35tcsg324-1"
set CONSTRAINTS "$CONSTR_DIR/spi_master_top.xdc"

# Parse command line arguments
for {set i 0} {$i < [llength $argv]} {incr i} {
    set arg [lindex $argv $i]
    switch -exact -- $arg {
        "-mode"  { incr i; set MODE [lindex $argv $i] }
        "-top"   { incr i; set TOP [lindex $argv $i] }
        "-part"  { incr i; set PART [lindex $argv $i] }
        "-xdc"   { incr i; set CONSTRAINTS [lindex $argv $i] }
        "-help"  {
            puts "Usage: vivado -mode batch -notrace -source run_vivado.tcl -tclargs \[-mode <elaborate|synth|impl|sim|all>\] \[-top <top_module>\] \[-part <fpga_part>\] \[-xdc <xdc_file>\]"
            exit 0
        }
    }
}

file mkdir $REPORTS_DIR

puts "=================================================================="
puts "  AMD Vivado IP Core Automation Flow"
puts "  Repository Root : $REPO_DIR"
puts "  Mode            : $MODE"
puts "  Top Module      : $TOP"
puts "  FPGA Part       : $PART"
puts "=================================================================="

# RTL Compilation Order: spi_pkg MUST be compiled first
set RTL_SOURCES [list \
    "$RTL_DIR/spi_pkg.sv" \
    "$RTL_DIR/spi_clock_gen.sv" \
    "$RTL_DIR/spi_bit_counter.sv" \
    "$RTL_DIR/spi_tx_shift.sv" \
    "$RTL_DIR/spi_rx_shift.sv" \
    "$RTL_DIR/spi_cs_ctrl.sv" \
    "$RTL_DIR/spi_master_fsm.sv" \
    "$RTL_DIR/spi_perf_counters.sv" \
    "$RTL_DIR/spi_master.sv" \
    "$RTL_DIR/spi_master_top.sv" \
    "$RTL_DIR/spi_top.sv" \
    "$RTL_DIR/spi_slave.sv" \
    "$RTL_DIR/spi_slave_top.sv" \
    "$RTL_DIR/spi_pad_wrapper.sv" \
]

proc read_all_rtl {} {
    global RTL_SOURCES
    puts "--- Reading SystemVerilog RTL Sources ---"
    foreach src $RTL_SOURCES {
        if {![file exists $src]} {
            error "ERROR: RTL file not found: $src"
        }
        read_verilog -sv $src
    }
}

proc run_xsim_sim {} {
    global REPO_DIR RTL_SOURCES TB_DIR
    set SIM_BUILD_DIR "$REPO_DIR/sim/xsim_build"
    file mkdir $SIM_BUILD_DIR
    
    set curr_dir [pwd]
    cd $SIM_BUILD_DIR
    
    puts "--- Compiling RTL & Testbench into XSim Work Library ---"
    set xvlog_args [list "xvlog" "-sv" "-nolog"]
    foreach src $RTL_SOURCES {
        lappend xvlog_args $src
    }
    lappend xvlog_args "$TB_DIR/spi_tb.sv"
    
    if {[catch {exec {*}$xvlog_args} xvlog_out]} {
        puts $xvlog_out
        error "ERROR: XSim xvlog compilation failed."
    }
    puts $xvlog_out
    
    puts "--- Elaborating Simulation Snapshot (xelab) ---"
    set xelab_args [list "xelab" "-debug" "typical" "-top" "spi_tb" "-snapshot" "spi_tb_snap" "-nolog"]
    if {[catch {exec {*}$xelab_args} xelab_out]} {
        puts $xelab_out
        error "ERROR: XSim xelab elaboration failed."
    }
    puts $xelab_out
    
    puts "--- Running Simulation (xsim) ---"
    if {[catch {exec cmd.exe /c xsim.bat spi_tb_snap -runall --onfinish quit -nolog} xsim_out]} {
        puts $xsim_out
        error "ERROR: XSim execution failed."
    }
    puts $xsim_out
    
    cd $curr_dir
    puts "\[INFO\] XSim simulation complete."
}

# ------------------------------------------------------------------------------
# 1. RTL Elaboration Mode
# ------------------------------------------------------------------------------
if {$MODE eq "elaborate"} {
    puts "\n=================================================================="
    puts "  Stage: RTL Elaboration & Design Analysis ($TOP)"
    puts "=================================================================="
    read_all_rtl
    
    if {$PART ne ""} {
        synth_design -rtl -top $TOP -part $PART
    } else {
        synth_design -rtl -top $TOP
    }
    
    set rpt_file "$REPORTS_DIR/elaboration_analysis.rpt"
    set fp [open $rpt_file w]
    puts $fp "=================================================================="
    puts $fp "  AMD Vivado RTL Elaboration Report"
    puts $fp "  Top Module : $TOP"
    puts $fp "  Part       : $PART"
    puts $fp "  Date       : [clock format [clock seconds]]"
    puts $fp "=================================================================="
    puts $fp "Elaborated Cells Count: [llength [get_cells -hierarchical]]"
    puts $fp "Hierarchical Cells: [get_cells -hierarchical]"
    close $fp
    puts "\[INFO\] Elaboration complete. Report written to $rpt_file"
}

# ------------------------------------------------------------------------------
# 2. Standalone Synthesis Mode
# ------------------------------------------------------------------------------
if {$MODE eq "synth"} {
    puts "\n=================================================================="
    puts "  Stage: Logic Synthesis ($TOP) on $PART"
    puts "=================================================================="
    if {$PART eq ""} {
        error "ERROR: FPGA target part must be specified via '-part <part>' for synthesis."
    }
    
    read_all_rtl
    
    if {[file exists $CONSTRAINTS]} {
        puts "\[INFO\] Reading constraint file: $CONSTRAINTS"
        read_xdc $CONSTRAINTS
    } else {
        puts "\[WARNING\] Constraint file not found: $CONSTRAINTS. Proceeding without timing constraints."
    }
    
    synth_design -top $TOP -part $PART -mode out_of_context
    
    report_utilization -file "$REPORTS_DIR/synthesis_utilization.rpt"
    report_timing_summary -file "$REPORTS_DIR/synthesis_timing.rpt"
    puts "\[INFO\] Synthesis complete. Reports written to $REPORTS_DIR"
}

# ------------------------------------------------------------------------------
# 3. Complete Implementation Flow (Synth -> Opt -> Place -> PhysOpt -> Route)
# ------------------------------------------------------------------------------
if {$MODE eq "impl" || $MODE eq "all"} {
    puts "\n=================================================================="
    puts "  Stage: Out-of-Context Logic Synthesis ($TOP) on $PART"
    puts "=================================================================="
    if {$PART eq ""} {
        error "ERROR: FPGA target part must be specified via '-part <part>' for implementation."
    }
    
    read_all_rtl
    
    if {[file exists $CONSTRAINTS]} {
        puts "\[INFO\] Reading constraint file: $CONSTRAINTS"
        read_xdc $CONSTRAINTS
    } else {
        puts "\[WARNING\] Constraint file not found: $CONSTRAINTS. Proceeding without timing constraints."
    }
    
    puts "--- Running synth_design (out-of-context) ---"
    synth_design -top $TOP -part $PART -mode out_of_context
    
    report_utilization -file "$REPORTS_DIR/synthesis_utilization.rpt"
    report_timing_summary -file "$REPORTS_DIR/synthesis_timing.rpt"
    
    puts "\n=================================================================="
    puts "  Stage: Implementation (Opt, Place, Phys_Opt, Route) on $PART"
    puts "=================================================================="
    
    puts "--- Running opt_design ---"
    opt_design
    
    puts "--- Running place_design ---"
    place_design
    
    puts "--- Running phys_opt_design ---"
    phys_opt_design
    
    puts "--- Running route_design ---"
    route_design
    
    puts "--- Generating Implementation Reports ---"
    report_utilization -file "$REPORTS_DIR/implementation_utilization.rpt"
    report_timing_summary -file "$REPORTS_DIR/implementation_timing.rpt"
    report_clock_utilization -file "$REPORTS_DIR/clock_summary.rpt"
    report_drc -file "$REPORTS_DIR/drc.rpt"
    
    puts "\[INFO\] Implementation complete. Reports written to $REPORTS_DIR"
}

# ------------------------------------------------------------------------------
# 4. Simulation Execution
# ------------------------------------------------------------------------------
if {$MODE eq "sim" || $MODE eq "all"} {
    puts "\n=================================================================="
    puts "  Stage: Vivado XSim Functional Simulation (spi_tb)"
    puts "=================================================================="
    run_xsim_sim
}

puts "\n=================================================================="
puts "  AMD Vivado Automation Flow Completed Successfully"
puts "=================================================================="
exit 0
