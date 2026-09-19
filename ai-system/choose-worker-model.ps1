[CmdletBinding()]
param(
    [ValidateSet('normal', 'hard')]
    [string]$WorkerClass = 'normal',
    [switch]$OverseasReady,
    [switch]$DomesticReady,
    [string[]]$ExcludeCandidate = @(),
    [datetime]$Now = (Get-Date)
)

$ErrorActionPreference = 'Stop'
$policyPath = Join-Path $PSScriptRoot 'config\model-rules.json'
$policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json
$route = $policy.chains.PSObject.Properties[$WorkerClass].Value
if ($null -eq $route) {
    throw "Unknown worker class: $WorkerClass"
}

$nightWindow = ($Now.Hour -ge 23 -or $Now.Hour -lt 8)
$available = @()
$skipped = @()
$rank = 0

foreach ($candidateId in @($route)) {
    $rank++
    $candidateProperty = $policy.candidates.PSObject.Properties[$candidateId]
    if ($null -eq $candidateProperty) {
        $skipped += [pscustomobject]@{ candidate = $candidateId; reason = 'not-configured' }
        continue
    }

    $candidate = $candidateProperty.Value
    if (-not [bool]$candidate.enabled) {
        $skipped += [pscustomobject]@{ candidate = $candidateId; reason = 'disabled' }
        continue
    }
    if ($ExcludeCandidate -contains $candidateId) {
        $skipped += [pscustomobject]@{ candidate = $candidateId; reason = 'excluded-for-this-attempt' }
        continue
    }

    $bodyReady = ($candidate.workerBody -eq 'domestic' -and $DomesticReady) -or
        ($candidate.workerBody -eq 'overseas' -and $OverseasReady)
    if (-not $bodyReady) {
        $skipped += [pscustomobject]@{ candidate = $candidateId; reason = 'worker-body-not-ready' }
        continue
    }

    $availableNow = [string]$candidate.availability -eq 'always' -or
        ([string]$candidate.availability -eq '23:00-08:00-Asia/Shanghai' -and $nightWindow)
    if (-not $availableNow) {
        $skipped += [pscustomobject]@{ candidate = $candidateId; reason = 'outside-availability-window' }
        continue
    }

    $available += [pscustomobject]@{
        rank = $rank
        candidate = $candidateId
        workerBody = $candidate.workerBody
        modelSlot = $candidate.modelSlot
        selector = $candidate.selector
        quotaClass = $candidate.quotaClass
        availability = $candidate.availability
        costPolicy = $candidate.costPolicy
        fallbackToNext = [bool]$candidate.fallbackToNext
    }
}

if ($available.Count -eq 0) {
    [ordered]@{
        status = 'blocked'
        workerClass = $WorkerClass
        reason = 'No configured fallback candidate is currently available.'
        excludedCandidates = @($ExcludeCandidate)
        skipped = @($skipped)
    } | ConvertTo-Json -Depth 8
    exit 2
}

[ordered]@{
    status = 'selected'
    workerClass = $WorkerClass
    primary = $available[0]
    fallbackChain = @($available)
    skipped = @($skipped)
    note = 'This is a static ordered chain. The caller/Worker handles execution failure and requests the next candidate.'
} | ConvertTo-Json -Depth 8
