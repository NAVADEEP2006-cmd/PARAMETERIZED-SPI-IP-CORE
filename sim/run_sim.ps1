# PowerShell Runner for SPI IP Core
param (
    [string]$Action = "lint"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $ScriptDir
$RtlDir = Join-Path $ProjectRoot "rtl"
$TbDir = Join-Path $ProjectRoot "tb"

$RtlSources = @(
    (Join-Path $RtlDir "spi_pkg.sv"),
    (Join-Path $RtlDir "spi_clock_gen.sv"),
    (Join-Path $RtlDir "spi_bit_counter.sv"),
    (Join-Path $RtlDir "spi_tx_shift.sv"),
    (Join-Path $RtlDir "spi_rx_shift.sv"),
    (Join-Path $RtlDir "spi_cs_ctrl.sv"),
    (Join-Path $RtlDir "spi_master_fsm.sv"),
    (Join-Path $RtlDir "spi_perf_counters.sv"),
    (Join-Path $RtlDir "spi_master.sv"),
    (Join-Path $RtlDir "spi_master_top.sv"),
    (Join-Path $RtlDir "spi_top.sv"),
    (Join-Path $RtlDir "spi_slave.sv"),
    (Join-Path $RtlDir "spi_slave_top.sv"),
    (Join-Path $RtlDir "spi_pad_wrapper.sv")
)
$TbSources = @(
    (Join-Path $TbDir "spi_tb.sv")
)

switch ($Action.ToLower()) {
    "lint" {
        Write-Host "--- Running Verilator Lint ---" -ForegroundColor Cyan
        & verilator --lint-only -Wall -sv $RtlSources $TbSources --top-module spi_tb
    }
    "sim" {
        Write-Host "--- Compiling and Running with Verilator ---" -ForegroundColor Cyan
        & verilator --binary --timing -Wall -sv $RtlSources $TbSources --top-module spi_tb --trace
        if ($LASTEXITCODE -eq 0) {
            & (Join-Path $ScriptDir "obj_dir\Vspi_tb.exe")
        }
    }
    "iverilog" {
        Write-Host "--- Compiling and Running with Icarus Verilog ---" -ForegroundColor Cyan
        $OutFile = Join-Path $ScriptDir "spi_tb.out"
        & iverilog -g2012 -Wall -o $OutFile $RtlSources $TbSources
        if ($LASTEXITCODE -eq 0) {
            & vvp $OutFile
        }
    }
    "clean" {
        Write-Host "--- Cleaning simulation artifacts ---" -ForegroundColor Yellow
        Remove-Item -Recurse -Force (Join-Path $ScriptDir "obj_dir") -ErrorAction SilentlyContinue
        Remove-Item -Force (Join-Path $ScriptDir "*.vcd") -ErrorAction SilentlyContinue
        Remove-Item -Force (Join-Path $ScriptDir "*.out") -ErrorAction SilentlyContinue
    }
    Default {
        Write-Host "Unknown action: $Action. Use: lint, sim, iverilog, clean" -ForegroundColor Red
    }
}
