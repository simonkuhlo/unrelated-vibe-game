# Run Godot project using Steam Godot if available
param(
    [string]$Project = ".",
    [string]$Scene = "",
    [switch]$Editor
)

$GodotPaths = @(
    "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
    "C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
)

$Godot = $null
foreach ($p in $GodotPaths) {
    if (Test-Path $p) { $Godot = $p; break }
}

if (-not $Godot) {
    # Try to find any godot exe
    $found = Get-ChildItem "C:\Program Files (x86)\Steam\steamapps\common" -Filter "godot*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $Godot = $found.FullName }
}

if (-not $Godot) {
    Write-Host "Godot executable not found. Install Godot via Steam or update scripts/run-godot.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "Using: $Godot" -ForegroundColor Cyan

if ($Editor) {
    & $Godot --path $Project
} elseif ($Scene) {
    & $Godot --path $Project $Scene
} else {
    & $Godot --path $Project
}
