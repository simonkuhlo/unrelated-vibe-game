# Run the Godot project or editor using the shared binary resolution.
# Linux: uses GODOT_BIN, common install locations, then godot on PATH.
# Windows: also checks the Steam install as a fallback.
param(
    [string]$Project = ".",
    [string]$Scene = "",
    [switch]$Editor,
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_godot.ps1")

$root = Resolve-GodotProjectRoot -Project $Project
$godot = Resolve-GodotBinary -GodotBin $GodotBin -ProjectRoot $root
Assert-GodotVersion -Godot $godot -ProjectRoot $root

Write-Host "Using: $godot" -ForegroundColor Cyan

$godotArgs = @("--path", $root)
if ($Editor) {
    $godotArgs += "-e"
} elseif (-not [string]::IsNullOrWhiteSpace($Scene)) {
    $godotArgs += $Scene
}

& $godot @godotArgs
exit $LASTEXITCODE
