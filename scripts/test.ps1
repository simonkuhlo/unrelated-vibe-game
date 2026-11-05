# Run the gdUnit4 suites.
#
# Tiers map to directories under tests/. Use -Path to run a single suite.
# Exit codes from gdUnit4: 0 pass, 100 test failures, 101 warnings/orphans.
# All non-zero codes fail this script.

[CmdletBinding()]
param(
    [ValidateSet("all", "unit", "integration", "content")]
    [string]$Tier = "all",
    [string]$Path = "",
    [string]$Project = "",
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_godot.ps1")

$root = Resolve-GodotProjectRoot -Project $Project
$godot = Resolve-GodotBinary -GodotBin $GodotBin -ProjectRoot $root
Assert-GodotVersion -Godot $godot -ProjectRoot $root

$targets = @()
if (-not [string]::IsNullOrWhiteSpace($Path)) {
    $targets += ConvertTo-ResPath -Path $Path -ProjectRoot $root
} elseif ($Tier -eq "all") {
    foreach ($tier in @("unit", "integration", "content")) {
        # Build paths with Join-Path so the same script works on Linux CI.
        $candidate = Join-Path (Join-Path $root "tests") $tier
        if (Test-Path -LiteralPath $candidate) {
            $targets += "res://tests/$tier"
        }
    }
} else {
    $targets += "res://tests/$Tier"
}

if ($targets.Count -eq 0) {
    Write-Host "No test directories found." -ForegroundColor Red
    exit 1
}

$reportsDir = Join-Path $root "reports"
if (Test-Path -LiteralPath $reportsDir) {
    Remove-Item -LiteralPath $reportsDir -Recurse -Force
}

# A fresh clone (and the CI test job) has no import cache. Godot cannot resolve
# UID-based scene references without it, so import once when it is missing.
$importCache = Join-Path (Join-Path $root ".godot") "imported"
if (-not (Test-Path -LiteralPath $importCache)) {
    Write-Host "== Import ==" -ForegroundColor Cyan
    & $godot --headless --quiet --path $root --import 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Project import failed (exit $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

$godotArgs = @(
    "--headless",
    "--path", $root,
    "-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
    # gdUnit4 v6 requires this flag for headless runs, and it must be passed
    # after the -s script path. Revisit when v7 is adopted.
    "--ignoreHeadlessMode",
    "-c",
    "-rc", "1",
    "-rd", "res://reports"
)
foreach ($target in $targets) {
    $godotArgs += @("-a", $target)
}

Write-Host "Running tests in: $($targets -join ', ')" -ForegroundColor Cyan
# Tests deliberately exercise push_warning()/push_error(). Windows PowerShell
# treats native stderr as a terminating error when ErrorActionPreference is
# Stop, so relax it for the test process and restore it afterwards.
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& $godot @godotArgs 2>&1 | Out-Host
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorAction

$report = Get-ChildItem -LiteralPath $reportsDir -Recurse -Filter "results.xml" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

$testCount = 0
if ($report) {
    $content = Get-Content -LiteralPath $report.FullName -Raw
    $testCount = ([regex]::Matches($content, "<testcase[\s>]")).Count
    Write-Host "Report: $($report.FullName)" -ForegroundColor DarkGray
}

# gdUnit4 exits 0 when nothing was collected. That is indistinguishable from a
# green run, so treat it as a failure.
if ($testCount -eq 0) {
    Write-Host "No test cases were collected. Failing to avoid a false green." -ForegroundColor Red
    exit 1
}

if ($exitCode -ne 0) {
    Write-Host "Tests failed (gdUnit4 exit $exitCode) with $testCount test cases." -ForegroundColor Red
    exit $exitCode
}

Write-Host "Tests passed ($testCount test cases)." -ForegroundColor Green
