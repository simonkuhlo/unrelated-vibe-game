# Pre-PR gate: static checks followed by the test suites.
# Run this before opening a pull request.

[CmdletBinding()]
param(
    [ValidateSet("all", "unit", "integration", "content")]
    [string]$Tier = "all",
    [string]$Path = "",
    [string]$Project = "",
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"

$common = @{}
if (-not [string]::IsNullOrWhiteSpace($Project)) { $common["Project"] = $Project }
if (-not [string]::IsNullOrWhiteSpace($GodotBin)) { $common["GodotBin"] = $GodotBin }

& (Join-Path $PSScriptRoot "check.ps1") @common
if ($LASTEXITCODE -ne 0) {
    Write-Host "verify.ps1 stopped: static checks failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

$testArgs = @{ Tier = $Tier }
if (-not [string]::IsNullOrWhiteSpace($Path)) { $testArgs["Path"] = $Path }
foreach ($key in $common.Keys) { $testArgs[$key] = $common[$key] }

& (Join-Path $PSScriptRoot "test.ps1") @testArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "verify.ps1 stopped: tests failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "verify.ps1 passed." -ForegroundColor Green
