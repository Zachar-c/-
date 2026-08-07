param(
    [ValidateSet('baseline', 'outline', 'detail', 'final')]
    [string]$Phase = 'baseline',

    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$errors = [System.Collections.Generic.List[string]]::new()

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
    foreach ($path in $tracked) {
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
    $markers = @(
        '**',
        ([string][char]0x7AD9 + [char]0x70B9),
        ([string][char]0x4F5C + [char]0x8005 + [char]0x6309 + [char]0x8BED),
        ([string][char]0x6253 + [char]0x8D4F),
        ([string][char]0x63A8 + [char]0x8350 + [char]0x7968),
        ([string][char]0x6708 + [char]0x7968),
        ([string][char]0x8BF7 + [char]0x6536 + [char]0x85CF),
        ([string][char]0x624B + [char]0x673A + [char]0x7528 + [char]0x6237)
    )
    foreach ($file in $files) {
        $content = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
        foreach ($marker in $markers) {
            if ($content.Contains($marker)) {
                Add-Error ('Edited text contains forbidden noise marker "{0}": {1}' -f $marker, $file.FullName)
            }
        }
    }
}

function Test-DetailHeadings {
    $detailFiles = @(Get-ChildItem -LiteralPath (Get-RepoPath 'outlines\detail') -Filter '*.md' -File -ErrorAction SilentlyContinue)
    if ($detailFiles.Count -eq 0) {
        Add-Error 'No detail outline files found.'
        return
    }

    $sectionNumbers = [System.Collections.Generic.List[int]]::new()
    foreach ($file in $detailFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
        $matches = [regex]::Matches($content, '(?m)^### \u7B2C\s*(\d+)\s*\u8282\uFF1A')
        foreach ($match in $matches) {
            $sectionNumbers.Add([int]$match.Groups[1].Value)
        }
    }
    $duplicates = @($sectionNumbers | Group-Object | Where-Object Count -gt 1)
    foreach ($duplicate in $duplicates) {
        Add-Error ('Duplicate detail section: {0}' -f $duplicate.Name)
    }
    $expected = 1..60
    if (($sectionNumbers | Sort-Object) -join ',' -ne ($expected -join ',')) {
        Add-Error ('Detail sections must cover exactly 1-60; found: {0}' -f (($sectionNumbers | Sort-Object) -join ','))
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
    [void](Test-RequiredFile 'outlines/detail/vol1-sec001-010.md')
    [void](Test-RequiredFile 'outlines/detail/vol1-sec011-020.md')
    [void](Test-RequiredFile 'outlines/detail/vol1-sec021-030.md')
    [void](Test-RequiredFile 'outlines/detail/vol1-sec031-060.md')
    Test-DetailHeadings
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

Write-Output ('Editorial asset validation passed: phase={0}' -f $Phase)
exit 0
