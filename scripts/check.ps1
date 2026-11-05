# Static checks: import, parse every first-party script, boot the main scene.
# This is the fast gate; it does not run tests.

[CmdletBinding()]
param(
    [string]$Project = "",
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_godot.ps1")

$root = Resolve-GodotProjectRoot -Project $Project
$godot = Resolve-GodotBinary -GodotBin $GodotBin -ProjectRoot $root
Assert-GodotVersion -Godot $godot -ProjectRoot $root

Write-Host "== Import ==" -ForegroundColor Cyan
# Piping forces PowerShell to wait for Godot and sets $LASTEXITCODE on Windows,
# where the editor executable is a GUI-subsystem binary.
& $godot --headless --quiet --path $root --import 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host "Project import failed (exit $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "== Parse ==" -ForegroundColor Cyan
& $godot --headless --path $root -s res://tests/tools/check_scripts.gd 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host "Script parsing failed (exit $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "== Boot ==" -ForegroundColor Cyan
& $godot --headless --path $root --quit-after 2 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host "Main scene failed to boot (exit $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Static checks passed." -ForegroundColor Green
