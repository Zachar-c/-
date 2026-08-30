[CmdletBinding()]
param(
    [int]$KillAfterSaves = 3,
    [int]$KillDelaySeconds = 20
)

# Crash-recovery check (process level, 2026-08-29):
#   1. run    — a real Godot process plays via official commands and saves in
#               a loop; the orchestrator HARD-KILLS it (Stop-Process -Force)
#               at an arbitrary point.
#   2. verify — a fresh Godot process must resume the run from the last
#               durable save and keep playing.
#   3. tamper — a corrupted save must be rejected by checksum; a leftover
#               .tmp must be ignored.
# The player's real user:// saves are backed up before the run and restored
# at the end (§16.22: tools must not touch player saves).

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

# Resolve the Godot console executable through the shared tool resolver.
$godotExe = & (Join-Path $PSScriptRoot 'resolve-godot.ps1') -Console

$userDir = Join-Path $env:APPDATA 'Godot\app_userdata\蛊真人'
$backupDir = Join-Path $env:TEMP ('crash_recovery_backup_' + (Get-Date -Format 'yyyyMMddHHmmss'))
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$saveNames = @('nanjiang_smoke_save.json', 'nanjiang_smoke_meta.json', 'crash_recovery_marker.json')
foreach ($name in $saveNames) {
    $src = Join-Path $userDir $name
    if (Test-Path $src) { Copy-Item $src $backupDir -Force }
}
Write-Host "[crash] player saves backed up to $backupDir"

function Invoke-Phase {
    param([string]$Phase)
    $env:CRASH_PHASE = $Phase
    $env:CRASH_SAVE_BUDGET = [string]$KillAfterSaves
    $out = Join-Path $backupDir "out_$Phase.log"
    $err = Join-Path $backupDir "err_$Phase.log"
    return (Start-Process -FilePath $godotExe -ArgumentList @('--headless', '--path', $projectRoot, '-s', 'res://scripts/crash_recovery_driver.gd') -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err)
}

$failures = @()

# ── Phase 1: run + hard kill ──
$runner = Invoke-Phase 'run'
$deadline = (Get-Date).AddSeconds($KillDelaySeconds)
$savesSeen = 0
$markerPath = Join-Path $userDir 'crash_recovery_marker.json'
while ((Get-Date) -lt $deadline -and -not $runner.HasExited) {
    Start-Sleep -Milliseconds 300
    if (Test-Path $markerPath) {
        try {
            $entries = Get-Content $markerPath -Raw | ConvertFrom-Json
            $savesSeen = @($entries).Count
        } catch { $savesSeen = 0 }
        if ($savesSeen -ge $KillAfterSaves) { break }
    }
}
if (-not $runner.HasExited) {
    Stop-Process -Id $runner.Id -Force
    Write-Host "[crash] runner KILLED after $savesSeen durable saves (pid $($runner.Id))"
} else {
    $failures += 'runner exited before the kill window'
}
if ($savesSeen -lt 1) { $failures += "no durable saves recorded (saw $savesSeen)" }

# ── Phase 2: verify resume in a fresh process ──
$verifier = Invoke-Phase 'verify'
$verifier | Wait-Process -Timeout 120 -ErrorAction SilentlyContinue
if (-not $verifier.HasExited) { Stop-Process -Id $verifier.Id -Force; $failures += 'verify phase timed out' }
elseif ($verifier.ExitCode -ne 0) { $failures += "verify phase exited $($verifier.ExitCode)" }

# ── Phase 3: tamper + tmp leftover ──
$tamper = Invoke-Phase 'tamper'
$tamper | Wait-Process -Timeout 120 -ErrorAction SilentlyContinue
if (-not $tamper.HasExited) { Stop-Process -Id $tamper.Id -Force; $failures += 'tamper phase timed out' }
elseif ($tamper.ExitCode -ne 0) { $failures += "tamper phase exited $($tamper.ExitCode)" }

# ── restore player saves ──
foreach ($name in $saveNames) {
    $backup = Join-Path $backupDir $name
    $destFile = Join-Path $userDir $name
    if (Test-Path $backup) { Copy-Item $backup $destFile -Force }
    elseif (Test-Path $destFile) { Remove-Item $destFile -Force }
}
Write-Host '[crash] player saves restored'

if ($failures.Count -gt 0) {
    Write-Host '[crash] RESULT: FAIL'
    $failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host '[crash] RESULT: PASS'
exit 0
