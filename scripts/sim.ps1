# scripts/sim.ps1 - Run simulation on Parameterized SPI IP Core
param (
    [string]$Tool = "iverilog"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $ScriptDir
$SimDir = Join-Path $ProjectRoot "sim"

$Python = Get-Command python -ErrorAction SilentlyContinue
if ($Python) {
    & python (Join-Path $SimDir "run_sim.py") $Tool
} else {
    & powershell -File (Join-Path $SimDir "run_sim.ps1") -Action $Tool
}
