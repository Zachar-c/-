[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LoreArgs
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$PythonPath = ''
$forwardedArgs = [System.Collections.Generic.List[string]]::new()
for ($index = 0; $index -lt $LoreArgs.Count; $index++) {
    if ($LoreArgs[$index] -eq '-PythonPath' -and $index + 1 -lt $LoreArgs.Count) {
        $PythonPath = $LoreArgs[$index + 1]
        $index++
        continue
    }
    $forwardedArgs.Add($LoreArgs[$index])
}

$candidates = @(
    $PythonPath,
    [Environment]::GetEnvironmentVariable('LORE_PYTHON'),
    (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'),
    (Join-Path $env:USERPROFILE 'AppData\Local\Programs\Python\Python312\python.exe'),
    (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

if (-not $candidates) {
    Write-Error 'Python 3.12 was not found. Set -PythonPath or LORE_PYTHON to the executable path.'
    exit 2
}

$python = $candidates | Select-Object -First 1
Push-Location $projectRoot
try {
    & $python -m lore_engine.cli @forwardedArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
