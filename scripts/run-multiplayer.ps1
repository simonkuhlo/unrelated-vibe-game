# Launch multiple instances of the game for local multiplayer testing
param(
    [int]$Instances = 2,
    [string]$Project = "."
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
    $found = Get-ChildItem "C:\Program Files (x86)\Steam\steamapps\common" -Filter "godot*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $Godot = $found.FullName }
}

if (-not $Godot) {
    Write-Host "Godot executable not found." -ForegroundColor Red
    exit 1
}

Write-Host "Launching $Instances instances using $Godot" -ForegroundColor Cyan
for ($i = 0; $i -lt $Instances; $i++) {
    Start-Process -FilePath $Godot -ArgumentList "--path", (Resolve-Path $Project)
    Start-Sleep -Milliseconds 500
}
Write-Host "Done." -ForegroundColor Green
