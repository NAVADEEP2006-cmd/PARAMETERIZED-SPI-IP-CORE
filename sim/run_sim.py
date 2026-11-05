#!/usr/bin/env python3
"""
run_sim.py - Cross-Platform Simulation and Verification Automation Runner
Supports Verilator (lint & modern sim), Icarus Verilog, and modular unit tests.

Supported Actions:
  lint        - Run Verilator RTL and full testbench lint
  clock_gen   - Execute Clock Generator unit testbench
  bit_counter - Execute Bit Counter unit testbench
  cs_ctrl     - Execute Chip-Select Controller unit testbench
  shift_regs  - Execute TX/RX Shift Registers unit testbench
  master_fsm  - Execute Master FSM unit testbench
  unit        - Execute all 5 unit testbenches in sequence
  integration - Execute complete 16-suite integration test with Icarus Verilog
  sim         - Execute complete integration test with Verilator (--timing)
  all         - Execute lint, all unit tests, and integration testbench
  clean       - Clean all simulation build artifacts, VCD traces, and logs
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

# Full RTL filelist for complete system integration & lint
RTL_ALL = [
    os.path.join(RTL_DIR, "common", "spi_pkg.sv"),
    os.path.join(RTL_DIR, "master", "spi_clock_gen.sv"),
    os.path.join(RTL_DIR, "master", "spi_bit_counter.sv"),
    os.path.join(RTL_DIR, "master", "spi_tx_shift.sv"),
    os.path.join(RTL_DIR, "master", "spi_rx_shift.sv"),
    os.path.join(RTL_DIR, "master", "spi_cs_ctrl.sv"),
    os.path.join(RTL_DIR, "master", "spi_master_fsm.sv"),
    os.path.join(RTL_DIR, "master", "spi_perf_counters.sv"),
    os.path.join(RTL_DIR, "master", "spi_master.sv"),
    os.path.join(RTL_DIR, "master", "spi_master_top.sv"),
    os.path.join(RTL_DIR, "master", "spi_top.sv"),
    os.path.join(RTL_DIR, "slave", "spi_slave.sv"),
    os.path.join(RTL_DIR, "slave", "spi_slave_top.sv"),
    os.path.join(RTL_DIR, "common", "spi_pad_wrapper.sv"),
    os.path.join(RTL_DIR, "board", "spi_pynq_z2_top.sv")
]

TB_INTEGRATION = [
    os.path.join(TB_DIR, "integration", "spi_tb.sv")
]

# Modular Unit Test Definitions: Testbench, exact RTL dependencies, and top module
UNIT_TEST_SPECS = {
    "clock_gen": {
        "name": "Clock Generator Unit Test",
        "tb": os.path.join(TB_DIR, "unit", "tb_spi_clock_gen.sv"),
        "top": "tb_spi_clock_gen",
        "rtl": [
            os.path.join(RTL_DIR, "common", "spi_pkg.sv"),
            os.path.join(RTL_DIR, "master", "spi_clock_gen.sv")
        ]
    },
    "bit_counter": {
        "name": "Bit Counter Unit Test",
        "tb": os.path.join(TB_DIR, "unit", "tb_spi_bit_counter.sv"),
        "top": "tb_spi_bit_counter",
        "rtl": [
            os.path.join(RTL_DIR, "common", "spi_pkg.sv"),
            os.path.join(RTL_DIR, "master", "spi_bit_counter.sv")
        ]
    },
    "cs_ctrl": {
        "name": "Chip-Select Controller Unit Test",
        "tb": os.path.join(TB_DIR, "unit", "tb_spi_cs_ctrl.sv"),
        "top": "tb_spi_cs_ctrl",
        "rtl": [
            os.path.join(RTL_DIR, "common", "spi_pkg.sv"),
            os.path.join(RTL_DIR, "master", "spi_cs_ctrl.sv")
        ]
    },
    "shift_regs": {
        "name": "TX/RX Shift Registers Unit Test",
        "tb": os.path.join(TB_DIR, "unit", "tb_spi_shift_regs.sv"),
        "top": "tb_spi_shift_regs",
        "rtl": [
            os.path.join(RTL_DIR, "master", "spi_tx_shift.sv"),
            os.path.join(RTL_DIR, "master", "spi_rx_shift.sv")
        ]
    },
    "master_fsm": {
        "name": "Master FSM Unit Test",
        "tb": os.path.join(TB_DIR, "unit", "tb_spi_master_fsm.sv"),
        "top": "tb_spi_master_fsm",
        "rtl": [
            os.path.join(RTL_DIR, "master", "spi_master_fsm.sv")
        ]
    }
}

def run_cmd(cmd, cwd=SIM_DIR):
    print(f"[EXEC] {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd)
    return result.returncode

def check_iverilog():
    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    if not iverilog or not vvp:
        print("[ERROR] 'iverilog' or 'vvp' not found in PATH.")
        return None, None
    return iverilog, vvp

def check_verilator():
    verilator = shutil.which("verilator")
    if not verilator:
        print("[ERROR] 'verilator' not found in PATH.")
        return None
    return verilator

def do_lint():
    verilator = check_verilator()
    if not verilator:
        return 1
    
    print("\n================ Running Verilator RTL Lint ================")
    # Exclude board demonstration top from OOC wrapper lint
    rtl_no_board = [f for f in RTL_ALL if "spi_pynq_z2_top.sv" not in f]
    cmd_rtl = [verilator, "--lint-only", "-Wall", "-sv"] + rtl_no_board + ["--top-module", "spi_pad_wrapper"]
    rc_rtl = run_cmd(cmd_rtl)
    if rc_rtl != 0:
        print("[FAIL] Verilator RTL lint failed.")
        return rc_rtl

    print("\n================ Running Verilator Board Top Lint ================")
    cmd_board = [verilator, "--lint-only", "-Wall", "-Wno-TIMESCALEMOD", "-Wno-PINCONNECTEMPTY", "-sv"] + RTL_ALL + ["--top-module", "spi_pynq_z2_top"]
    rc_board = run_cmd(cmd_board)
    if rc_board != 0:
        print("[FAIL] Verilator board top lint failed.")
        return rc_board
    
    print("\n================ Running Verilator Full Lint ================")
    cmd_tb = [verilator, "--lint-only", "--timing", "-Wall", "-Wno-TIMESCALEMOD", "-Wno-PINCONNECTEMPTY", "-sv"] + rtl_no_board + TB_INTEGRATION + ["--top-module", "spi_tb"]
    rc_tb = run_cmd(cmd_tb)
    if rc_tb == 0:
        print("[SUCCESS] Verilator lint passed with 0 warnings/errors!")
    else:
        print("[FAIL] Verilator full testbench lint failed.")
    return rc_tb

def run_single_unit_test(test_key):
    iverilog, vvp = check_iverilog()
    if not iverilog or not vvp:
        return 1

    spec = UNIT_TEST_SPECS[test_key]
    print(f"\n================ Running {spec['name']} ({spec['top']}) ================")
    out_file = os.path.join(SIM_DIR, f"{spec['top']}.out")
    
    cmd_compile = [iverilog, "-g2012", "-Wall", "-s", spec["top"], "-o", out_file] + spec["rtl"] + [spec["tb"]]
    rc = run_cmd(cmd_compile)
    if rc != 0:
        print(f"[FAIL] Compilation of {spec['name']} failed.")
        return rc
    
    cmd_run = [vvp, out_file]
    rc = run_cmd(cmd_run)
    if rc != 0:
        print(f"[FAIL] Execution of {spec['name']} failed.")
        return rc
    
    print(f"[SUCCESS] {spec['name']} passed!")
    return 0

def do_unit_tests():
    print("\n================ Running All Modular Unit Testbenches ================")
    failed = []
    for key, spec in UNIT_TEST_SPECS.items():
        rc = run_single_unit_test(key)
        if rc != 0:
            failed.append(spec["name"])
    
    if failed:
        print(f"\n[SUMMARY] Unit tests FAILED: {', '.join(failed)}")
        return 1
    else:
        print("\n[SUMMARY] All 5 unit testbenches PASSED successfully!")
        return 0

def do_sim_iverilog():
    iverilog, vvp = check_iverilog()
    if not iverilog or not vvp:
        return 1
    
    print("\n================ Compiling Complete Integration Test with Icarus Verilog ================")
    out_file = os.path.join(SIM_DIR, "spi_tb.out")
    rtl_no_board = [f for f in RTL_ALL if "spi_pynq_z2_top.sv" not in f]
    cmd_compile = [iverilog, "-g2012", "-Wall", "-s", "spi_tb", "-o", out_file] + rtl_no_board + TB_INTEGRATION
    rc = run_cmd(cmd_compile)
    if rc != 0:
        print("[FAIL] Icarus Verilog compilation failed.")
        return rc
    
    print("\n================ Executing Complete Integration Simulation Suite ================")
    cmd_run = [vvp, out_file]
    rc = run_cmd(cmd_run)
    if rc == 0:
        print("[SUCCESS] Complete SPI integration testbench passed!")
    else:
        print("[FAIL] Integration simulation failed.")
    return rc

def do_sim_verilator():
    verilator = check_verilator()
    if not verilator:
        return 1
    
    print("\n================ Compiling with Verilator (--binary --timing) ================")
    rtl_no_board = [f for f in RTL_ALL if "spi_pynq_z2_top.sv" not in f]
    cmd = [verilator, "--binary", "--timing", "-Wall", "-Wno-TIMESCALEMOD", "-Wno-PINCONNECTEMPTY", "-sv"] + rtl_no_board + TB_INTEGRATION + ["--top-module", "spi_tb", "--trace"]
    rc = run_cmd(cmd)
    if rc != 0:
        print("[FAIL] Verilator compilation failed.")
        return rc
    
    bin_path = os.path.join(SIM_DIR, "obj_dir", "Vspi_tb")
    if not os.path.exists(bin_path) and os.path.exists(bin_path + ".exe"):
        bin_path += ".exe"
    
    print("\n================ Running Verilator Simulation ================")
    rc = run_cmd([bin_path])
    if rc == 0:
        print("[SUCCESS] Verilator simulation passed!")
    else:
        print("[FAIL] Verilator simulation execution failed.")
    return rc

def do_clean():
    clean_items = ["obj_dir", "spi_tb.vcd", "spi_tb.out"] + [f"{s['top']}.out" for s in UNIT_TEST_SPECS.values()]
    for item in clean_items:
        p = os.path.join(SIM_DIR, item)
        if os.path.isdir(p):
            shutil.rmtree(p)
        elif os.path.isfile(p):
            os.remove(p)
    # Also clean any stray vcd or log files
    for f in os.listdir(SIM_DIR):
        if f.endswith(".vcd") or f.endswith(".out") or f.endswith(".log"):
            try:
                os.remove(os.path.join(SIM_DIR, f))
            except OSError:
                pass
    print("[INFO] Cleaned simulation artifacts.")
    return 0

def do_all():
    print("\n================ Starting Complete Verification Workflow ================")
    rc = do_lint()
    if rc != 0:
        return rc
    
    rc = do_unit_tests()
    if rc != 0:
        return rc
    
    rc = do_sim_iverilog()
    return rc

def main():
    parser = argparse.ArgumentParser(description="SPI IP Verification Automation Runner")
    parser.add_argument("action", choices=[
        "lint", "clock_gen", "bit_counter", "cs_ctrl", "shift_regs", "master_fsm",
        "unit", "integration", "iverilog", "sim", "all", "clean"
    ], default="lint", nargs="?",
    help="Verification action to execute")
    args = parser.parse_args()

    if args.action == "clean":
        return do_clean()
    elif args.action == "lint":
        return do_lint()
    elif args.action in UNIT_TEST_SPECS:
        return run_single_unit_test(args.action)
    elif args.action == "unit":
        return do_unit_tests()
    elif args.action in ["integration", "iverilog"]:
        return do_sim_iverilog()
    elif args.action == "sim":
        return do_sim_verilator()
    elif args.action == "all":
        return do_all()
    else:
        print(f"[ERROR] Unknown action: {args.action}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
