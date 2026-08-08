param(
    [ValidateSet('baseline', 'outline', 'detail', 'final')]
    [string]$Phase = 'baseline',

    [string]$RepoRoot = (Get-Location).Path,

    [string[]]$Volume = @('vol1')
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$errors = [System.Collections.Generic.List[string]]::new()
$configPath = Join-Path $RepoRoot 'config\editorial-volumes.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw ('Missing editorial volume configuration: {0}' -f $configPath)
}
$volumeConfig = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$knownVolumeIds = @($volumeConfig.volumes | ForEach-Object { $_.id })
if ($Volume -contains 'all') {
    $Volume = $knownVolumeIds
}
$unknownVolumeIds = @($Volume | Where-Object { $_ -notin $knownVolumeIds })
if ($unknownVolumeIds.Count -gt 0) {
    throw ('Unknown volume id(s): {0}. Known ids: {1}' -f ($unknownVolumeIds -join ', '), ($knownVolumeIds -join ', '))
}
$selectedVolumes = @($volumeConfig.volumes | Where-Object { $_.id -in $Volume })

function Add-Error([string]$message) {
    $script:errors.Add($message)
}

function Get-RepoPath([string]$relativePath) {
    return (Join-Path $RepoRoot $relativePath)
}

function Test-StrictUtf8([string]$path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
    try {
        [void]$utf8.GetString($bytes)
        return $true
    } catch {
        Add-Error ('Invalid UTF-8: {0}' -f $path)
        return $false
    }
}

function Test-RequiredFile([string]$relativePath) {
    $path = Get-RepoPath $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Error ('Missing required file: {0}' -f $relativePath)
        return $false
    }
    return $true
}

function Test-TrackedSourceBoundary {
    $tracked = @(git -C $RepoRoot -c core.quotePath=false ls-files)
    $allowlist = @($volumeConfig.trackedSourceAllowlist)
    foreach ($path in $tracked) {
        if ($path -in $allowlist) {
            continue
        }
        $leaf = ($path -split '/')[-1]
        if ($leaf -eq ([string][char]0x86CA + [char]0x771F + [char]0x4EBA + '.txt') -or $leaf -match '^(source|complete|full).*(txt|docx?|pdf)$') {
            Add-Error ('Complete-source copy appears tracked: {0}' -f $path)
        }
    }
}

function Test-TrackedUtf8Assets {
    $tracked = @(git -C $RepoRoot -c core.quotePath=false ls-files)
    foreach ($relativePath in $tracked) {
        if ($relativePath -match '\.(md|csv|edited\.txt)$') {
            $path = Get-RepoPath $relativePath
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                [void](Test-StrictUtf8 $path)
            }
        }
    }
}

function Test-CsvAssets {
    $tracked = @(git -C $RepoRoot -c core.quotePath=false ls-files '*.csv')
    foreach ($relativePath in $tracked) {
        $path = Get-RepoPath $relativePath
        try {
            $rows = @(Import-Csv -LiteralPath $path -Encoding UTF8)
            if ((Get-Content -LiteralPath $path -Encoding UTF8 -TotalCount 1) -notmatch ',') {
                Add-Error ('CSV has no comma-delimited header: {0}' -f $relativePath)
            }
        } catch {
            Add-Error ('CSV cannot be imported: {0}; {1}' -f $relativePath, $_.Exception.Message)
        }
    }
}

function Test-EditedText {
    $files = @(Get-ChildItem -LiteralPath (Get-RepoPath 'volumes') -Filter '*.edited.txt' -Recurse -File -ErrorAction SilentlyContinue)
    $maxParagraphLength = 500
    $markers = @(
        ([string][char]0x7AD9 + [char]0x70B9),
        ([string][char]0x4F5C + [char]0x8005 + [char]0x6309 + [char]0x8BED),
        ([string][char]0x6253 + [char]0x8D4F),
        ([string][char]0x63A8 + [char]0x8350 + [char]0x7968),
        ([string][char]0x6708 + [char]0x7968),
        ([string][char]0x8BF7 + [char]0x6536 + [char]0x85CF),
        ([string][char]0x624B + [char]0x673A + [char]0x7528 + [char]0x6237),
        'CTRL+D',
        '<dd>',
        '</dd>',
        ([string][char]0x672A + [char]0x5B8C + [char]0x5F85 + [char]0x7EED)
    )
    foreach ($file in $files) {
        $content = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
        foreach ($marker in $markers) {
            if ($content.Contains($marker)) {
                Add-Error ('Edited text contains forbidden noise marker "{0}": {1}' -f $marker, $file.FullName)
            }
        }

        $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
        for ($index = 0; $index -lt $lines.Count; $index++) {
            if ($lines[$index].Length -gt $maxParagraphLength) {
                Add-Error ('Edited text has an overlong paragraph ({0} chars) at {1}:{2}' -f $lines[$index].Length, $file.FullName, ($index + 1))
            }
        }
    }
}

function Test-DetailHeadings($volume) {
    $detailFiles = @(Get-ChildItem -LiteralPath (Get-RepoPath 'outlines\detail') -Filter $volume.detailPattern -File -ErrorAction SilentlyContinue)
    if ($detailFiles.Count -eq 0) {
        Add-Error ('No detail outline files found for {0}.' -f $volume.id)
        return
    }

    $sectionNumbers = [System.Collections.Generic.List[int]]::new()
    foreach ($file in $detailFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
        # Earlier batches use level-three headings; later batches use level-two headings.
        $matches = [regex]::Matches($content, '(?m)^#{2,3}\s+\u7B2C\s*(\d+)\s*\u8282[\uFF1A:]')
        foreach ($match in $matches) {
            $sectionNumbers.Add([int]$match.Groups[1].Value)
        }
    }
    $duplicates = @($sectionNumbers | Group-Object | Where-Object Count -gt 1)
    foreach ($duplicate in $duplicates) {
        Add-Error ('Duplicate detail section: {0}' -f $duplicate.Name)
    }
    $expected = 1..([int]$volume.sectionCount)
    if (($sectionNumbers | Sort-Object) -join ',' -ne ($expected -join ',')) {
        Add-Error ('{0} detail sections must cover exactly 1-{1}; found: {2}' -f $volume.id, $volume.sectionCount, (($sectionNumbers | Sort-Object) -join ','))
    }
}

function Test-VolumeSectionBatches($volume) {
    $volumeRoot = Get-RepoPath 'volumes'
    $directory = @(Get-ChildItem -LiteralPath $volumeRoot -Directory | Where-Object Name -Like $volume.directoryPattern)
    if ($directory.Count -ne 1) {
        Add-Error ('Expected exactly one directory for {0}; found: {1}' -f $volume.id, $directory.Count)
        return
    }
    $directory = $directory[0].FullName
    $total = 0
    foreach ($batch in $volume.batches) {
        $fileName = '{0}-sec{1}.edited.txt' -f $volume.id, $batch.range
        $path = Join-Path $directory $fileName
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-Error ('Missing {0} text batch: {1}' -f $volume.id, $fileName)
            continue
        }
        $content = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
        $matches = [regex]::Matches($content, '(?m)^\u7B2C[\u96F6\u4E00\u4E8C\u4E09\u56DB\u4E94\u516D\u4E03\u516B\u4E5D\u5341\u767E]+\u8282(?:[\uFF1A:]|\s+(?!\u8BFE))')
        if ($matches.Count -ne $batch.Count) {
            Add-Error ('Unexpected section count in {0}: expected {1}, found {2}' -f $fileName, $batch.count, $matches.Count)
        }
        $total += $matches.Count
    }
    if ($total -ne [int]$volume.sectionCount) {
        Add-Error ('{0} text must contain exactly {1} section headings; found: {2}' -f $volume.id, $volume.sectionCount, $total)
    }
}

function Test-OutlineReferences {
    $markdownFiles = @(Get-ChildItem -LiteralPath (Get-RepoPath 'outlines') -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue)
    foreach ($file in $markdownFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
        $matches = [regex]::Matches($content, '\]\(([^)#]+)\)')
        foreach ($match in $matches) {
            $target = $match.Groups[1].Value
            if ($target -match '^(https?|mailto):') {
                continue
            }
            $resolved = Join-Path $file.DirectoryName $target
            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-Error ('Broken outline reference in {0}: {1}' -f $file.FullName, $target)
            }
        }
    }
}

Test-TrackedSourceBoundary
Test-TrackedUtf8Assets
Test-CsvAssets
Test-EditedText

if ($Phase -in @('outline', 'detail', 'final')) {
    [void](Test-RequiredFile 'outlines/README.md')
    [void](Test-RequiredFile 'notes/fact-disputes.csv')
    [void](Test-RequiredFile 'scripts/validate_editorial_assets.ps1')
}

if ($Phase -in @('outline', 'detail', 'final')) {
    [void](Test-RequiredFile 'outlines/00-full-book-outline.md')
}

if ($Phase -in @('detail', 'final')) {
    foreach ($selectedVolume in $selectedVolumes) {
        foreach ($batch in $selectedVolume.batches) {
            [void](Test-RequiredFile ('outlines/detail/{0}-sec{1}.md' -f $selectedVolume.id, $batch.range))
        }
        Test-DetailHeadings $selectedVolume
        Test-VolumeSectionBatches $selectedVolume
    }
}

if ($Phase -in @('outline', 'detail', 'final')) {
    Test-OutlineReferences
}

$sourcePath = Get-RepoPath 'index/source-audit.json'
if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
    try {
        [void](Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch {
        Add-Error ('Source audit JSON cannot be parsed: {0}' -f $_.Exception.Message)
    }
}

if ($errors.Count -gt 0) {
    Write-Error (($errors | ForEach-Object { '- ' + $_ }) -join [Environment]::NewLine)
    exit 1
}

Write-Output ('Editorial asset validation passed: phase={0}; volume={1}' -f $Phase, ($Volume -join ','))
exit 0
