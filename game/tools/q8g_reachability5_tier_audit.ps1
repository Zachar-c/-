[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [switch]$Batch2,
    [switch]$Batch3,
    [switch]$Batch4
)

# Reachability-5 / E6 Loot-Tier Opportunity Audit: 8-seed measurement sweep.
# Opt-in env PLAYTHROUGH_E6_TIER_AUDIT=1; per-run full logs saved for the
# hypothesis analysis. Does not touch the Reachability-4 tools.

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = & (Join-Path $PSScriptRoot 'godot.ps1') -Console
}

$cases = @(
    @{ Seed = '20260927'; School = 'force' },
    @{ Seed = '11';       School = 'force' },
    @{ Seed = '33';       School = 'force' },
    @{ Seed = '55';       School = 'force' },
    @{ Seed = '20260927'; School = 'sword' },
    @{ Seed = '11';       School = 'sword' },
    @{ Seed = '33';       School = 'sword' },
    @{ Seed = '55';       School = 'sword' }
)
# Multi-seed confidence batch (inbox #17): fresh seeds, same protocol.
if ($Batch2) {
    $cases = @(
        @{ Seed = '101';  School = 'force' },
        @{ Seed = '202';  School = 'force' },
        @{ Seed = '303';  School = 'force' },
        @{ Seed = '404';  School = 'force' },
        @{ Seed = '101';  School = 'sword' },
        @{ Seed = '202';  School = 'sword' },
        @{ Seed = '303';  School = 'sword' },
        @{ Seed = '404';  School = 'sword' }
    )
}
# Reachability-7 design preflight (inbox #19): expand the corpus to 32+ runs.
if ($Batch3) {
    $cases = @(
        @{ Seed = '505';  School = 'force' },
        @{ Seed = '606';  School = 'force' },
        @{ Seed = '707';  School = 'force' },
        @{ Seed = '808';  School = 'force' },
        @{ Seed = '505';  School = 'sword' },
        @{ Seed = '606';  School = 'sword' },
        @{ Seed = '707';  School = 'sword' },
        @{ Seed = '808';  School = 'sword' }
    )
}
if ($Batch4) {
    $cases = @(
        @{ Seed = '909';  School = 'force' },
        @{ Seed = '1111'; School = 'force' },
        @{ Seed = '1212'; School = 'force' },
        @{ Seed = '1313'; School = 'force' },
        @{ Seed = '909';  School = 'sword' },
        @{ Seed = '1111'; School = 'sword' },
        @{ Seed = '1212'; School = 'sword' },
        @{ Seed = '1313'; School = 'sword' }
    )
}

$logDir = Join-Path $env:TEMP 'gu-zhenrens-r5-logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$rows = @()
foreach ($case in $cases) {
    $old = @{}
    foreach ($name in @(
        'PLAYTHROUGH_FULL',
        'PLAYTHROUGH_COMBAT_FIRST',
        'PLAYTHROUGH_SCHOOL',
        'PLAYTHROUGH_SEED',
        'PLAYTHROUGH_F1_OPPORTUNITY_PITY',
        'PLAYTHROUGH_E6_TIER_AUDIT'
    )) {
        $old[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
        $env:PLAYTHROUGH_FULL = '1'
        $env:PLAYTHROUGH_COMBAT_FIRST = '1'
        $env:PLAYTHROUGH_SCHOOL = $case.School
        $env:PLAYTHROUGH_SEED = $case.Seed
        $env:PLAYTHROUGH_F1_OPPORTUNITY_PITY = ''
        $env:PLAYTHROUGH_E6_TIER_AUDIT = '1'
        $lines = @(& $GodotPath --headless --path $projectRoot -s scripts/acceptance_driver.gd -- --mode=play 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        foreach ($name in $old.Keys) {
            [Environment]::SetEnvironmentVariable($name, $old[$name], 'Process')
        }
    }

    if ($code -ne 0) {
        throw "Reachability-5 sweep failed for $($case.School)/$($case.Seed), exit=$code`n$($lines -join "`n")"
    }
    $lines | Set-Content -Path (Join-Path $logDir "$($case.School)_$($case.Seed).log") -Encoding UTF8
    $output = $lines -join "`n"
    $summary = [regex]::Match($output, '^\[play\] R-5 summary: (.+)$', [Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $summary.Success) {
        throw "Reachability-5 summary missing for $($case.School)/$($case.Seed)."
    }
    # Gate B/C ride at the end of the R-5 summary line (ASCII), so no separate
    # match against the localized Gate lines is needed.
    $gates = [regex]::Match($summary.Groups[1].Value, 'gate_b=(?<b>\w+) gate_c=(?<c>\w+)')
    if (-not $gates.Success) {
        throw "Reachability-5 gates missing for $($case.School)/$($case.Seed)."
    }
    $rows += [pscustomobject]@{
        School = $case.School
        Seed = $case.Seed
        Gates = ("gate_b=$($gates.Groups['b'].Value) gate_c=$($gates.Groups['c'].Value)")
        Summary = $summary.Groups[1].Value
    }
}

$rows | Format-Table -AutoSize | Out-String -Width 400 | Write-Output
exit 0
