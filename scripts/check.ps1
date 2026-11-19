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
$exitCode = Invoke-Godot -Godot $godot -GodotArgs @("--headless", "--quiet", "--path", $root, "--import")
if ($exitCode -ne 0) {
    Write-Host "Project import failed (exit $exitCode)." -ForegroundColor Red
    exit $exitCode
}

Write-Host "== Parse ==" -ForegroundColor Cyan
$exitCode = Invoke-Godot -Godot $godot -GodotArgs @("--headless", "--path", $root, "-s", "res://tests/tools/check_scripts.gd")
if ($exitCode -ne 0) {
    Write-Host "Script parsing failed (exit $exitCode)." -ForegroundColor Red
    exit $exitCode
}

Write-Host "== Boot ==" -ForegroundColor Cyan
$exitCode = Invoke-Godot -Godot $godot -GodotArgs @("--headless", "--path", $root, "--quit-after", "2")
if ($exitCode -ne 0) {
    Write-Host "Main scene failed to boot (exit $exitCode)." -ForegroundColor Red
    exit $exitCode
}

Write-Host "Static checks passed." -ForegroundColor Green
