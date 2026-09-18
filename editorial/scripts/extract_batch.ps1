param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [int]$StartLine,

    [Parameter(Mandatory = $true)]
    [int]$EndLine,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$encoding = [Text.Encoding]::GetEncoding(936)
$lines = [IO.File]::ReadAllLines($SourcePath, $encoding)
$start = [Math]::Max(1, $StartLine)
$end = [Math]::Min($EndLine, $lines.Count)
$selected = for ($index = $start - 1; $index -lt $end; $index++) { $lines[$index] }
$parentDirectory = Split-Path -Parent $OutputPath
if ($parentDirectory) {
    New-Item -ItemType Directory -Force -Path $parentDirectory | Out-Null
}
[IO.File]::WriteAllLines($OutputPath, $selected, $encoding)
Write-Output "Wrote $($selected.Count) lines to $OutputPath"
