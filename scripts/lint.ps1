# scripts/lint.ps1 - Run Verilator lint check on Parameterized SPI IP Core
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $ScriptDir
$SimDir = Join-Path $ProjectRoot "sim"

$Python = Get-Command python -ErrorAction SilentlyContinue
if ($Python) {
    & python (Join-Path $SimDir "run_sim.py") lint
} else {
    & powershell -File (Join-Path $SimDir "run_sim.ps1") -Action lint
}
