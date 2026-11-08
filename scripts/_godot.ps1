# Shared helpers for the local test entry points.
# Dot-source this file; do not run it directly.

function Resolve-GodotProjectRoot {
    param([string]$Project)

    if ([string]::IsNullOrWhiteSpace($Project)) {
        return (Split-Path -Parent $PSScriptRoot)
    }
    return (Resolve-Path -LiteralPath $Project).Path
}

function Resolve-GodotBinary {
    param(
        [string]$GodotBin,
        [string]$ProjectRoot
    )

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($GodotBin)) { $candidates += $GodotBin }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) { $candidates += $env:GODOT_BIN }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) { $candidates += $env:GODOT }

    # Linux is the primary environment. These are common install locations; the
    # PATH lookup below covers distro packages and local builds.
    $candidates += @(
        "/usr/local/bin/godot",
        "/usr/bin/godot",
        "/opt/godot/godot",
        (Join-Path $HOME ".local/bin/godot")
    )

    # Windows fallback.
    $candidates += @(
        "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
        "C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
    )

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    foreach ($name in @("godot", "godot4")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command -and $command.Source) {
            return $command.Source
        }
    }

    throw "Godot executable not found. Set GODOT_BIN, pass -GodotBin, or add godot to PATH. See docs/getting-started.md."
}

function Assert-GodotVersion {
    param(
        [string]$Godot,
        [string]$ProjectRoot
    )

    $versionFile = Join-Path $ProjectRoot ".godot-version"
    if (-not (Test-Path -LiteralPath $versionFile)) {
        return
    }

    $expected = (Get-Content -LiteralPath $versionFile -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($expected)) {
        return
    }

    $actual = (& $Godot --version 2>$null | Select-Object -First 1)
    if ($null -eq $actual -or $actual -notmatch [regex]::Escape($expected)) {
        Write-Warning "Godot reports '$actual' but .godot-version pins $expected. Install the pinned version before trusting local results."
    }
}

function ConvertTo-ResPath {
    param(
        [string]$Path,
        [string]$ProjectRoot
    )

    if ($Path -like "res://*") {
        return $Path
    }

    $fullPath = (Resolve-Path -LiteralPath (Join-Path $ProjectRoot $Path)).Path
    $relative = $fullPath.Substring($ProjectRoot.Length).TrimStart("\", "/")
    return "res://" + ($relative -replace "\\", "/")
}
