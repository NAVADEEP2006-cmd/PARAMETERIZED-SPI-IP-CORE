#!/usr/bin/env python3
"""
run_sim.py - Cross-Platform Automation Script for Parameterized SPI IP Core
Supports Verilator (lint & sim) and Icarus Verilog.
"""

import os
import sys
import shutil
import subprocess
import argparse

SIM_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SIM_DIR)
RTL_DIR = os.path.join(PROJECT_ROOT, "rtl")
TB_DIR = os.path.join(PROJECT_ROOT, "tb")

RTL_FILES = [
    os.path.join(RTL_DIR, "spi_pkg.sv"),
    os.path.join(RTL_DIR, "spi_clock_gen.sv"),
    os.path.join(RTL_DIR, "spi_bit_counter.sv"),
    os.path.join(RTL_DIR, "spi_tx_shift.sv"),
    os.path.join(RTL_DIR, "spi_rx_shift.sv"),
    os.path.join(RTL_DIR, "spi_cs_ctrl.sv"),
    os.path.join(RTL_DIR, "spi_master_fsm.sv"),
    os.path.join(RTL_DIR, "spi_perf_counters.sv"),
    os.path.join(RTL_DIR, "spi_master.sv"),
    os.path.join(RTL_DIR, "spi_master_top.sv"),
    os.path.join(RTL_DIR, "spi_top.sv"),
    os.path.join(RTL_DIR, "spi_slave.sv"),
    os.path.join(RTL_DIR, "spi_slave_top.sv"),
    os.path.join(RTL_DIR, "spi_pad_wrapper.sv")
]

TB_FILES = [
    os.path.join(TB_DIR, "spi_tb.sv")
]

def run_cmd(cmd, cwd=SIM_DIR):
    print(f"[EXEC] {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd)
    return result.returncode

def do_lint():
    verilator = shutil.which("verilator")
    if not verilator:
        print("[ERROR] 'verilator' not found in PATH.")
        return 1
    
    print("\n================ Running Verilator Lint ================")
    cmd = [verilator, "--lint-only", "-Wall", "-sv"] + RTL_FILES + TB_FILES + ["--top-module", "spi_tb"]
    rc = run_cmd(cmd)
    if rc == 0:
        print("[SUCCESS] Verilator lint passed with 0 warnings/errors!")
    return rc

def do_sim_verilator():
    verilator = shutil.which("verilator")
    if not verilator:
        print("[ERROR] 'verilator' not found in PATH.")
        return 1
    
    print("\n================ Compiling with Verilator ================")
    cmd = [verilator, "--binary", "--timing", "-Wall", "-sv"] + RTL_FILES + TB_FILES + ["--top-module", "spi_tb", "--trace"]
    rc = run_cmd(cmd)
    if rc != 0:
        print("[FAIL] Verilator compilation failed.")
        return rc
    
    bin_path = os.path.join(SIM_DIR, "obj_dir", "Vspi_tb")
    if not os.path.exists(bin_path) and os.path.exists(bin_path + ".exe"):
        bin_path += ".exe"
    
    print("\n================ Running Simulation ================")
    return run_cmd([bin_path])

def do_sim_iverilog():
    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    if not iverilog or not vvp:
        print("[ERROR] 'iverilog' or 'vvp' not found in PATH.")
        return 1
    
    out_file = os.path.join(SIM_DIR, "spi_tb.out")
    cmd_compile = [iverilog, "-g2012", "-Wall", "-o", out_file] + RTL_FILES + TB_FILES
    rc = run_cmd(cmd_compile)
    if rc != 0:
        return rc
    
    cmd_run = [vvp, out_file]
    return run_cmd(cmd_run)

def main():
    parser = argparse.ArgumentParser(description="SPI IP Simulation Runner")
    parser.add_argument("action", choices=["lint", "sim", "iverilog", "clean"], default="lint", nargs="?",
                        help="Action to perform: lint, sim (verilator), iverilog, clean")
    args = parser.parse_args()

    if args.action == "clean":
        for item in ["obj_dir", "spi_tb.vcd", "spi_tb.out"]:
            p = os.path.join(SIM_DIR, item)
            if os.path.isdir(p):
                shutil.rmtree(p)
            elif os.path.isfile(p):
                os.remove(p)
        print("[INFO] Cleaned simulation artifacts.")
        return 0
    elif args.action == "lint":
        return do_lint()
    elif args.action == "sim":
        return do_sim_verilator()
    elif args.action == "iverilog":
        return do_sim_iverilog()

if __name__ == "__main__":
    sys.exit(main())
