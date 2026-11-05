# ==============================================================================
# run_sim.ps1 - PowerShell Verification Automation Runner for SPI IP Core
#
# Supported Actions:
#   lint        - Run Verilator RTL and full testbench lint
#   clock_gen   - Execute Clock Generator unit test
#   bit_counter - Execute Bit Counter unit test
#   cs_ctrl     - Execute Chip-Select Controller unit test
#   shift_regs  - Execute TX/RX Shift Registers unit test
#   master_fsm  - Execute Master FSM unit test
#   unit        - Execute all 5 unit testbenches in sequence
#   integration - Execute complete 16-suite integration test with Icarus Verilog
#   sim         - Execute complete integration test with Verilator (--timing)
#   all         - Execute lint, all unit tests, and integration testbench
#   clean       - Clean simulation build artifacts
# ==============================================================================

param (
    [string]$Action = "lint"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $ScriptDir
$RtlDir = Join-Path $ProjectRoot "rtl"
$TbDir = Join-Path $ProjectRoot "tb"

$RtlAll = @(
    (Join-Path $RtlDir "common\spi_pkg.sv"),
    (Join-Path $RtlDir "master\spi_clock_gen.sv"),
    (Join-Path $RtlDir "master\spi_bit_counter.sv"),
    (Join-Path $RtlDir "master\spi_tx_shift.sv"),
    (Join-Path $RtlDir "master\spi_rx_shift.sv"),
    (Join-Path $RtlDir "master\spi_cs_ctrl.sv"),
    (Join-Path $RtlDir "master\spi_master_fsm.sv"),
    (Join-Path $RtlDir "master\spi_perf_counters.sv"),
    (Join-Path $RtlDir "master\spi_master.sv"),
    (Join-Path $RtlDir "master\spi_master_top.sv"),
    (Join-Path $RtlDir "master\spi_top.sv"),
    (Join-Path $RtlDir "slave\spi_slave.sv"),
    (Join-Path $RtlDir "slave\spi_slave_top.sv"),
    (Join-Path $RtlDir "common\spi_pad_wrapper.sv")
)
$RtlBoard = Join-Path $RtlDir "board\spi_pynq_z2_top.sv"
$TbIntegration = Join-Path $TbDir "integration\spi_tb.sv"

function Run-UnitTest {
    param(
        [string]$Name,
        [string]$Top,
        [string[]]$RtlFiles,
        [string]$TbFile
    )
    Write-Host "`n=== Running $Name ($Top) ===" -ForegroundColor Cyan
    $OutFile = Join-Path $ScriptDir "$Top.out"
    & iverilog -g2012 -Wall -s $Top -o $OutFile $RtlFiles $TbFile
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Compilation failed for $Name" -ForegroundColor Red
        return 1
    }
    & vvp $OutFile
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Execution failed for $Name" -ForegroundColor Red
        return 1
    }
    Write-Host "[SUCCESS] $Name passed!" -ForegroundColor Green
    return 0
}

switch ($Action.ToLower()) {
    "lint" {
        Write-Host "--- Running Verilator RTL Lint ---" -ForegroundColor Cyan
        & verilator --lint-only -Wall -sv $RtlAll --top-module spi_pad_wrapper
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        Write-Host "--- Running Verilator Board Top Lint ---" -ForegroundColor Cyan
        & verilator --lint-only -Wall -Wno-TIMESCALEMOD -Wno-PINCONNECTEMPTY -sv $RtlAll $RtlBoard --top-module spi_pynq_z2_top
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        Write-Host "--- Running Verilator Full Lint ---" -ForegroundColor Cyan
        & verilator --lint-only --timing -Wall -Wno-TIMESCALEMOD -Wno-PINCONNECTEMPTY -sv $RtlAll $TbIntegration --top-module spi_tb
        exit $LASTEXITCODE
    }
    "clock_gen" {
        $rc = Run-UnitTest -Name "Clock Generator Unit Test" -Top "tb_spi_clock_gen" -RtlFiles @((Join-Path $RtlDir "common\spi_pkg.sv"), (Join-Path $RtlDir "master\spi_clock_gen.sv")) -TbFile (Join-Path $TbDir "unit\tb_spi_clock_gen.sv")
        exit $rc
    }
    "bit_counter" {
        $rc = Run-UnitTest -Name "Bit Counter Unit Test" -Top "tb_spi_bit_counter" -RtlFiles @((Join-Path $RtlDir "common\spi_pkg.sv"), (Join-Path $RtlDir "master\spi_bit_counter.sv")) -TbFile (Join-Path $TbDir "unit\tb_spi_bit_counter.sv")
        exit $rc
    }
    "cs_ctrl" {
        $rc = Run-UnitTest -Name "Chip-Select Controller Unit Test" -Top "tb_spi_cs_ctrl" -RtlFiles @((Join-Path $RtlDir "common\spi_pkg.sv"), (Join-Path $RtlDir "master\spi_cs_ctrl.sv")) -TbFile (Join-Path $TbDir "unit\tb_spi_cs_ctrl.sv")
        exit $rc
    }
    "shift_regs" {
        $rc = Run-UnitTest -Name "TX/RX Shift Registers Unit Test" -Top "tb_spi_shift_regs" -RtlFiles @((Join-Path $RtlDir "master\spi_tx_shift.sv"), (Join-Path $RtlDir "master\spi_rx_shift.sv")) -TbFile (Join-Path $TbDir "unit\tb_spi_shift_regs.sv")
        exit $rc
    }
    "master_fsm" {
        $rc = Run-UnitTest -Name "Master FSM Unit Test" -Top "tb_spi_master_fsm" -RtlFiles @((Join-Path $RtlDir "master\spi_master_fsm.sv")) -TbFile (Join-Path $TbDir "unit\tb_spi_master_fsm.sv")
        exit $rc
    }
    "unit" {
        $tests = @(
            @{ Name="Clock Generator"; Top="tb_spi_clock_gen"; Rtl=@((Join-Path $RtlDir "common\spi_pkg.sv"), (Join-Path $RtlDir "master\spi_clock_gen.sv")); Tb=(Join-Path $TbDir "unit\tb_spi_clock_gen.sv") },
            @{ Name="Bit Counter"; Top="tb_spi_bit_counter"; Rtl=@((Join-Path $RtlDir "common\spi_pkg.sv"), (Join-Path $RtlDir "master\spi_bit_counter.sv")); Tb=(Join-Path $TbDir "unit\tb_spi_bit_counter.sv") },
            @{ Name="Chip Select Ctrl"; Top="tb_spi_cs_ctrl"; Rtl=@((Join-Path $RtlDir "common\spi_pkg.sv"), (Join-Path $RtlDir "master\spi_cs_ctrl.sv")); Tb=(Join-Path $TbDir "unit\tb_spi_cs_ctrl.sv") },
            @{ Name="Shift Registers"; Top="tb_spi_shift_regs"; Rtl=@((Join-Path $RtlDir "master\spi_tx_shift.sv"), (Join-Path $RtlDir "master\spi_rx_shift.sv")); Tb=(Join-Path $TbDir "unit\tb_spi_shift_regs.sv") },
            @{ Name="Master FSM"; Top="tb_spi_master_fsm"; Rtl=@((Join-Path $RtlDir "master\spi_master_fsm.sv")); Tb=(Join-Path $TbDir "unit\tb_spi_master_fsm.sv") }
        )
        foreach ($t in $tests) {
            $rc = Run-UnitTest -Name $t.Name -Top $t.Top -RtlFiles $t.Rtl -TbFile $t.Tb
            if ($rc -ne 0) { exit 1 }
        }
        Write-Host "`n[SUMMARY] All 5 unit testbenches PASSED!" -ForegroundColor Green
        exit 0
    }
    "integration" {
        Write-Host "--- Running Complete SPI Integration Test (Icarus Verilog) ---" -ForegroundColor Cyan
        $OutFile = Join-Path $ScriptDir "spi_tb.out"
        & iverilog -g2012 -Wall -s spi_tb -o $OutFile $RtlAll $TbIntegration
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & vvp $OutFile
        exit $LASTEXITCODE
    }
    "iverilog" {
        Write-Host "--- Running Complete SPI Integration Test (Icarus Verilog) ---" -ForegroundColor Cyan
        $OutFile = Join-Path $ScriptDir "spi_tb.out"
        & iverilog -g2012 -Wall -s spi_tb -o $OutFile $RtlAll $TbIntegration
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & vvp $OutFile
        exit $LASTEXITCODE
    }
    "sim" {
        Write-Host "--- Compiling and Running with Verilator ---" -ForegroundColor Cyan
        & verilator --binary --timing -Wall -Wno-TIMESCALEMOD -Wno-PINCONNECTEMPTY -sv $RtlAll $TbIntegration --top-module spi_tb --trace
        if ($LASTEXITCODE -eq 0) {
            & (Join-Path $ScriptDir "obj_dir\Vspi_tb.exe")
        }
        exit $LASTEXITCODE
    }
    "clean" {
        Write-Host "--- Cleaning simulation artifacts ---" -ForegroundColor Yellow
        Remove-Item -Recurse -Force (Join-Path $ScriptDir "obj_dir") -ErrorAction SilentlyContinue
        Remove-Item -Force (Join-Path $ScriptDir "*.vcd") -ErrorAction SilentlyContinue
        Remove-Item -Force (Join-Path $ScriptDir "*.out") -ErrorAction SilentlyContinue
        Remove-Item -Force (Join-Path $ScriptDir "*.log") -ErrorAction SilentlyContinue
        exit 0
    }
    Default {
        Write-Host "Unknown action: $Action. Use: lint, clock_gen, bit_counter, cs_ctrl, shift_regs, master_fsm, unit, integration, sim, clean" -ForegroundColor Red
        exit 1
    }
}
