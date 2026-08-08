param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$BookTitle = '',
    [string]$VolumeTitle = ''
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $SourcePath).Path
$encoding = [Text.Encoding]::GetEncoding(936)
$lines = [IO.File]::ReadAllLines($source, $encoding)
$result = [Collections.Generic.List[string]]::new()

function ConvertFrom-CodePoints([int[]]$CodePoints) {
    return -join ($CodePoints | ForEach-Object { [char]$_ })
}

if (-not $BookTitle) {
    $BookTitle = ConvertFrom-CodePoints @(0x300A, 0x86CA, 0x771F, 0x4EBA, 0x300B, 0x7CBE, 0x7F16, 0x7248)
}
if (-not $VolumeTitle) {
    $VolumeTitle = ConvertFrom-CodePoints @(0x7B2C, 0x4E00, 0x90E8, 0x0020, 0x9B54, 0x6027, 0x4E0D, 0x6539)
}

$siteMarker = ConvertFrom-CodePoints @(0x66F4, 0x591A, 0x7CBE, 0x5F69, 0x9605, 0x8BFB, 0x8BF7, 0x6536, 0x85CF)
$bodyPrefix = ConvertFrom-CodePoints @(0x6B63, 0x6587)
$unfinished = ConvertFrom-CodePoints @(0x672A, 0x5B8C, 0x5F85, 0x7EED)
$openQuote = ConvertFrom-CodePoints @(0x300C)
$closeQuote = ConvertFrom-CodePoints @(0x300D)
$forumMarker = ConvertFrom-CodePoints @(0x86CA, 0x771F, 0x4EBA, 0x5427)
$baiduMarker = ConvertFrom-CodePoints @(0x767E, 0x5EA6)
$watermarkPattern = [regex]::Escape($openQuote) + '[^' + [regex]::Escape($openQuote + $closeQuote) + ']*(?:' + [regex]::Escape($forumMarker) + '|' + [regex]::Escape($baiduMarker) + ')[^' + [regex]::Escape($openQuote + $closeQuote) + ']*' + [regex]::Escape($closeQuote)

$result.Add($BookTitle)
$result.Add('')
$result.Add($VolumeTitle)
$result.Add('')

foreach ($rawLine in $lines) {
    $line = $rawLine.TrimEnd()

    if ($line -match '^\s*CTRL\+D\s+') {
        continue
    }

    if ($line.TrimStart().StartsWith($siteMarker)) {
        continue
    }

    if ($line -match '^\s*[\uFF08(]\s*(?i:ps)\s*[\uFF1A:]') {
        continue
    }

    if ($line.StartsWith($bodyPrefix + ' ')) {
        $line = $line.Substring($bodyPrefix.Length).TrimStart()
        $line = $line -replace '\([^)]*\)\s*$',''
    }

    if ($line -match '^<b>.*</b>$') {
        continue
    }

    $line = $line -replace '^\s{4}', ''
    $line = $line -replace ('\(' + $unfinished + '[^)]*(?:\)|$)'), ''
    $line = $line -replace '</?dd>', ''
    $line = $line -replace 'RQ\s*$', ''
    $line = $line -replace $watermarkPattern, ''

    if ($line -eq '' -and $result.Count -gt 0 -and $result[$result.Count - 1] -eq '') {
        continue
    }
    $result.Add($line)
}

while ($result.Count -gt 0 -and $result[$result.Count - 1] -eq '') {
    $result.RemoveAt($result.Count - 1)
}

# Some scraped pages repeat the chapter heading once inside the body wrapper.
for ($index = $result.Count - 1; $index -ge 2; $index--) {
    if ($result[$index - 1] -eq '' -and $result[$index] -eq $result[$index - 2] -and $result[$index] -match ('^' + [char]0x7B2C + '.{1,12}' + [char]0x8282)) {
        $result.RemoveAt($index)
        $result.RemoveAt($index - 1)
    }
}
$result.Add('')

$output = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$parent = Split-Path -Parent $output
[IO.Directory]::CreateDirectory($parent) | Out-Null
[IO.File]::WriteAllLines($output, $result, [Text.UTF8Encoding]::new($false))
