[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskFile,
    [string]$Title = 'WorkBuddy Cloud Worker Task',
    [string]$BaseUrl = 'https://www.workbuddy.cn',
    [switch]$Wait,
    [switch]$DryRun,
    [int]$PollSeconds = 5,
    [int]$TimeoutSeconds = 1800
)

$ErrorActionPreference = 'Stop'

$systemRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $systemRoot
$taskPath = (Resolve-Path -LiteralPath $TaskFile).Path
$protocolPath = Join-Path $systemRoot 'WORKER_PROTOCOL.md'
$taskBody = Get-Content -Raw -LiteralPath $taskPath
$protocolBody = Get-Content -Raw -LiteralPath $protocolPath

$workerBody = @"
You are a one-shot WorkBuddy Worker Body operating in the cloud workspace attached to this task.
The caller's local repository path is $repoRoot. It is informational only and is not directly readable from the cloud.
Use the repository/workspace attached to this WorkBuddy task. If the target repository is not present, stop and report that prerequisite instead of inventing files.

Read and follow this Worker Protocol before acting:
--- WORKER PROTOCOL ---
$protocolBody
--- END WORKER PROTOCOL ---

Execute the task below inside the repository.
Protect existing user changes. Stay within the task scope. Do not commit, push, or merge.
Return the protocol-required summary, test results, and unverified risks.

--- TASK ---
$taskBody
--- END TASK ---
"@

$headers = @{
    Authorization = "Bearer $($env:WORKBUDDY_ACCESS_TOKEN)"
    Accept = 'application/json'
}
$payload = @{
    prompt = $workerBody
    name = $Title
} | ConvertTo-Json -Depth 5

if ($DryRun) {
    Write-Output 'mode=dry-run'
    Write-Output ('endpoint={0}' -f ('{0}/openapi/v2/tasks' -f $BaseUrl.TrimEnd('/')))
    Write-Output 'token=<redacted>'
    Write-Output $payload
    exit 0
}

if ([string]::IsNullOrWhiteSpace($env:WORKBUDDY_ACCESS_TOKEN)) {
    throw 'WORKBUDDY_ACCESS_TOKEN is not set. Complete WorkBuddy OAuth locally and expose only the access token through the local secret store or process environment.'
}

$tasksUri = '{0}/openapi/v2/tasks' -f $BaseUrl.TrimEnd('/')
try {
    $created = Invoke-RestMethod -Method Post -Uri $tasksUri -Headers $headers -ContentType 'application/json' -Body $payload
} catch {
    throw "WorkBuddy task creation failed: $($_.Exception.Message)"
}

if ($null -eq $created.task_id) {
    throw 'WorkBuddy returned no task_id. The response was not accepted as a Worker task.'
}

Write-Output ('task_id={0}' -f $created.task_id)
Write-Output ('status={0}' -f $created.status)
if ($created.name) { Write-Output ('name={0}' -f $created.name) }
if ($created.link) { Write-Output ('link={0}' -f $created.link) }
if ($created.expire_at) { Write-Output ('expire_at={0}' -f $created.expire_at) }
Write-Output 'token=<redacted>'

if (-not $Wait) {
    exit 0
}

$terminalStates = @('completed', 'failed', 'archived', 'deleted')
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$taskUri = '{0}/openapi/v2/tasks/{1}' -f $BaseUrl.TrimEnd('/'), $created.task_id
$status = [string]$created.status

while ($status -notin $terminalStates -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds ([Math]::Max(1, $PollSeconds))
    try {
        $current = Invoke-RestMethod -Method Get -Uri $taskUri -Headers $headers
    } catch {
        throw "WorkBuddy task query failed: $($_.Exception.Message)"
    }
    $status = [string]$current.status
    Write-Output ('status={0}' -f $status)
}

if ($status -notin $terminalStates) {
    throw "WorkBuddy task did not reach a terminal state within $TimeoutSeconds seconds. task_id=$($created.task_id)"
}

Write-Output ('final_status={0}' -f $status)
