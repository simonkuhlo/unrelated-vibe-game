# Launch multiple instances of the game for local multiplayer testing.
# Uses the shared Godot binary resolution in _godot.ps1.
param(
    [int]$Instances = 2,
    [string]$Project = ".",
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_godot.ps1")

$root = Resolve-GodotProjectRoot -Project $Project
$godot = Resolve-GodotBinary -GodotBin $GodotBin -ProjectRoot $root
Assert-GodotVersion -Godot $godot -ProjectRoot $root

Write-Host "Launching $Instances instances using $godot" -ForegroundColor Cyan
for ($i = 0; $i -lt $Instances; $i++) {
    Start-Process -FilePath $godot -ArgumentList @("--path", $root)
    Start-Sleep -Milliseconds 500
}
Write-Host "Done." -ForegroundColor Green
