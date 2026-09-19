[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskFile,
    [ValidateSet('home', 'work')]
    [string]$Profile = 'home',
    [string]$Title = 'OpenCode Worker Task',
    [switch]$AutoApprove
)

$ErrorActionPreference = 'Stop'
$systemRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $systemRoot
# Console encoding here is gb2312; Windows PowerShell 5.1 Get-Content defaults to the
# ANSI codepage, which mangles the Chinese text in config/*.json and makes
# ConvertFrom-Json throw. Read those files as UTF8 explicitly.
# Keep this file ASCII-only: PS 5.1 parses BOM-less .ps1 as ANSI.
$common = Get-Content -Raw -Encoding UTF8 (Join-Path $systemRoot 'config/common.json') | ConvertFrom-Json
$profilePath = Join-Path $systemRoot ("config/{0}.json" -f $Profile)
$examplePath = Join-Path $systemRoot ("config/{0}.example.json" -f $Profile)
$machine = if (Test-Path -LiteralPath $profilePath) { Get-Content -Raw -Encoding UTF8 $profilePath | ConvertFrom-Json } else { Get-Content -Raw -Encoding UTF8 $examplePath | ConvertFrom-Json }
$opencode = Get-Command $machine.opencodeCommand -ErrorAction SilentlyContinue
if ($null -eq $opencode) { throw 'OpenCode CLI is not available on PATH.' }

# Do not run a worker against a silently substituted model. Bootstrap is the
# single check for the exact configured muse-spark-1.3-contributor-free model.
& (Join-Path $systemRoot 'bootstrap.ps1') -Profile $Profile -VerifyModel -Json | Out-Null

$taskPath = (Resolve-Path -LiteralPath $TaskFile).Path
$protocolPath = Join-Path $systemRoot 'WORKER_PROTOCOL.md'
$prompt = @"
Read the worker protocol at $protocolPath before acting.
Execute the task described in $taskPath inside repository $repoRoot.
Use only the requested scope. Protect existing user changes. Do not commit or push.
Return the protocol-required summary and test results.
"@

$args = @('run', $prompt, '--dir', $repoRoot, '--agent', $common.localFallbackWorker.agent, '--model', $common.localFallbackWorker.model, '--title', $Title)
if ($AutoApprove) { $args += '--auto' }
& $opencode.Source @args
exit $LASTEXITCODE
