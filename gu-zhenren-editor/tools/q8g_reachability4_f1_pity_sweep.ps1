[CmdletBinding()]
param(
    [string]$GodotPath = ""
)

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

$rows = @()
foreach ($case in $cases) {
    $old = @{}
    foreach ($name in @(
        'PLAYTHROUGH_FULL',
        'PLAYTHROUGH_COMBAT_FIRST',
        'PLAYTHROUGH_SCHOOL',
        'PLAYTHROUGH_SEED',
        'PLAYTHROUGH_F1_OPPORTUNITY_PITY'
    )) {
        $old[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
        $env:PLAYTHROUGH_FULL = '1'
        $env:PLAYTHROUGH_COMBAT_FIRST = '1'
        $env:PLAYTHROUGH_SCHOOL = $case.School
        $env:PLAYTHROUGH_SEED = $case.Seed
        $env:PLAYTHROUGH_F1_OPPORTUNITY_PITY = '1'
        $lines = @(& $GodotPath --headless --path $projectRoot -s scripts/acceptance_driver.gd -- --mode=play 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        foreach ($name in $old.Keys) {
            [Environment]::SetEnvironmentVariable($name, $old[$name], 'Process')
        }
    }

    if ($code -ne 0) {
        throw "Reachability-4 sweep failed for $($case.School)/$($case.Seed), exit=$code`n$($lines -join "`n")"
    }
    # Reachability-4 inbox §7: keep per-battle streak traces for audit.
    $logDir = Join-Path $env:TEMP 'gu-zhenrens-r4-logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $lines | Set-Content -Path (Join-Path $logDir "$($case.School)_$($case.Seed).log") -Encoding UTF8
    $output = $lines -join "`n"
    $summary = [regex]::Match($output, '^\[play\] R-4 SIM summary: (.+)$', [Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $summary.Success) {
        throw "Reachability-4 summary missing for $($case.School)/$($case.Seed)."
    }
    $funnel = [regex]::Match($output, '^\[play\] R-4 actual funnel: (.+)$', [Text.RegularExpressions.RegexOptions]::Multiline)
    $gates = [regex]::Match($output, '^\[play\] R-4 actual gates: (.+)$', [Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $funnel.Success -or -not $gates.Success) {
        throw "Reachability-4 actual funnel/gates missing for $($case.School)/$($case.Seed)."
    }
    $rows += [pscustomobject]@{
        School = $case.School
        Seed = $case.Seed
        Summary = $summary.Groups[1].Value
        Funnel = $funnel.Groups[1].Value
        Gates = $gates.Groups[1].Value
    }
}

foreach ($row in $rows) {
    Write-Output "$($row.School)/$($row.Seed) | $($row.Summary)"
    Write-Output "  $($row.Funnel) | $($row.Gates)"
}
exit 0
