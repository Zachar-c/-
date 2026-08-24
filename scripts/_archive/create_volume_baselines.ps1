param(
    [Parameter(Mandatory = $true)] [string]$SourcePath,
    [Parameter(Mandatory = $true)] [int]$StartLine,
    [Parameter(Mandatory = $true)] [int]$EndLine,
    [Parameter(Mandatory = $true)] [string]$OutputDirectory,
    [Parameter(Mandatory = $true)] [string]$VolumeId,
    [Parameter(Mandatory = $true)] [string]$VolumeTitle,
    [Parameter(Mandatory = $true)] [string[]]$Batches,
    [string[]]$ExcludeRanges = @()
)

$ErrorActionPreference = 'Stop'
$encoding = [Text.Encoding]::GetEncoding(936)
$allLines = [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $SourcePath), $encoding)
$excluded = [Collections.Generic.HashSet[int]]::new()
foreach ($range in $ExcludeRanges) {
    if ($range -notmatch '^(\d+)-(\d+)$') { throw "Invalid exclusion range: $range" }
    for ($line = [int]$Matches[1]; $line -le [int]$Matches[2]; $line++) { [void]$excluded.Add($line) }
}

$canonical = [Collections.Generic.List[object]]::new()
for ($line = $StartLine; $line -le $EndLine; $line++) {
    if (-not $excluded.Contains($line)) {
        $canonical.Add([pscustomobject]@{ SourceLine = $line; Text = $allLines[$line - 1] })
    }
}

$body = -join ([char]0x6B63,[char]0x6587)
$ordinal = [char]0x7B2C
$section = [char]0x8282
$fullColon = [char]0xFF1A
$headingPattern = '^' + $body + ' ' + $ordinal + '(.{1,12})' + $section + '(?:[' + $fullColon + ':]|\s{2,})'
$headings = @($canonical | Where-Object { $_.Text -match $headingPattern })
if ($headings.Count -ne 206) { throw "Expected 206 canonical headings; found $($headings.Count)" }

$numberMap = @{}
$numberMap[[char]0x4E00] = 1
$numberMap[[char]0x4E8C] = 2
$numberMap[[char]0x4E09] = 3
$numberMap[[char]0x56DB] = 4
$numberMap[[char]0x4E94] = 5
$numberMap[[char]0x516D] = 6
$numberMap[[char]0x4E03] = 7
$numberMap[[char]0x516B] = 8
$numberMap[[char]0x4E5D] = 9
$ten = [char]0x5341
$hundred = [char]0x767E
function Convert-ChineseSectionNumber([string]$value) {
    if ($value -eq $ten) { return 10 }
    $value = $value.Replace([string][char]0x96F6, '')
    $total = 0
    $hundredIndex = $value.IndexOf($hundred)
    if ($hundredIndex -ge 0) {
        $total += $numberMap[$value[0]] * 100
        $value = $value.Substring($hundredIndex + 1)
    }
    $tenIndex = $value.IndexOf($ten)
    if ($tenIndex -ge 0) {
        $total += if ($tenIndex -eq 0) { 10 } else { $numberMap[$value[0]] * 10 }
        $value = $value.Substring($tenIndex + 1)
    }
    if ($value.Length -gt 0) { $total += $numberMap[$value[0]] }
    return $total
}

$headingRows = for ($i = 0; $i -lt $headings.Count; $i++) {
    $match = [regex]::Match($headings[$i].Text, '^' + $body + ' ' + $ordinal + '(.{1,12})' + $section)
    [pscustomobject]@{
        Number = Convert-ChineseSectionNumber $match.Groups[1].Value
        SourceLine = $headings[$i].SourceLine
        Text = $headings[$i].Text
    }
}
if (($headingRows.Number -join ',') -ne ((1..206) -join ',')) { throw 'Canonical section numbers are not continuous 1-206.' }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('editorial-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
try {
    foreach ($batch in $Batches) {
        if ($batch -notmatch '^(\d{3})-(\d{3})$') { throw "Invalid batch: $batch" }
        $first = [int]$Matches[1]
        $last = [int]$Matches[2]
        $startSource = ($headingRows | Where-Object Number -eq $first).SourceLine
        $next = $headingRows | Where-Object Number -eq ($last + 1)
        $endSource = if ($next) { $next.SourceLine - 1 } else { $EndLine }
        $batchLines = @($canonical | Where-Object { $_.SourceLine -ge $startSource -and $_.SourceLine -le $endSource } | ForEach-Object Text)
        $temp = Join-Path $tempRoot "$VolumeId-sec$batch.cp936.txt"
        [IO.File]::WriteAllLines($temp, $batchLines, $encoding)
        $output = Join-Path $OutputDirectory "$VolumeId-sec$batch.edited.txt"
        & (Join-Path $PSScriptRoot 'create_edited_baseline.ps1') -SourcePath $temp -OutputPath $output -VolumeTitle $VolumeTitle
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

$headingRows | ConvertTo-Csv -NoTypeInformation | Set-Content -LiteralPath (Join-Path $OutputDirectory "$VolumeId-section-source-map.csv") -Encoding UTF8
