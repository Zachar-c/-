param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$RawIndexPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

function Convert-ChineseNumber([string]$value) {
    if ($value -match '^\d+$') {
        return [int64]$value
    }

    $digits = @{
        38646 = 0; 12295 = 0; 19968 = 1; 20108 = 2; 20004 = 2; 19977 = 3
        22235 = 4; 20116 = 5; 20845 = 6; 19971 = 7; 20843 = 8; 20061 = 9
    }
    $units = @{ 21313 = 10; 30334 = 100; 21315 = 1000; 19975 = 10000 }

    $total = 0L
    $section = 0L
    $number = 0L
    foreach ($character in $value.ToCharArray()) {
        $code = [int][char]$character
        if ($digits.ContainsKey($code)) {
            $number = [int64]$digits[$code]
            continue
        }
        if (-not $units.ContainsKey($code)) {
            continue
        }

        $unit = [int64]$units[$code]
        if ($number -eq 0) {
            $number = 1
        }
        if ($unit -eq 10000) {
            $section = ($section + $number) * $unit
            $total += $section
            $section = 0
        } else {
            $section += $number * $unit
        }
        $number = 0
    }
    return $total + $section + $number
}

function Get-NoiseFlags([string]$line, [string]$title) {
    $text = "$line $title"
    $flags = [System.Collections.Generic.List[string]]::new()
    if ($text -match '\u76EE\u5F55|\u7AE0\u8282\u76EE\u5F55|\u5F3A\u5F31\(\u7B2C\d+/\u7B2C\d+\u9875\)') {
        $flags.Add('directory_or_page')
    }
    if ($text -match '\u4F5C\u8005|\u4F5C\u5BB6|\u5377\u672B\u611F\u8A00|\u5B8C\u672C\u611F\u8A00|\u65B0\u4E66|\u66F4\u65B0|\u8BA2\u9605|\u6708\u7968|\u63A8\u8350\u7968|\u672A\u5B8C\u5F85\u7EED|\(?\s*(?:ps|PS)\s*[:\uFF1A]') {
        $flags.Add('author_or_site')
    }
    if ($text -match 'www\.|https?://|\u624B\u673A\u7528\u6237|\u8BF7\u6536\u85CF|\u7CBE\u5F69\u9605\u8BFB|</?\w+[^>]*>') {
        $flags.Add('site_markup')
    }
    return ($flags -join ';')
}

function Get-HeadingCandidate([string]$line, [int]$sourceLine) {
    $pattern = '^\s*(?:(\u6B63\u6587)\s*)?\u7B2C([\u96F6\u3007\u4E00\u4E8C\u4E24\u4E09\u56DB\u4E94\u516D\u4E03\u516B\u4E5D\u5341\u767E\u5343\u4E07\d]+)\u8282\s*[\uFF1A:]\s*(.*?)\s*$'
    if ($line -notmatch $pattern) {
        return $null
    }

    $title = $matches[3].Trim()
    if ([string]::IsNullOrWhiteSpace($title)) {
        return $null
    }

    $sectionText = $matches[2]
    return [pscustomobject]@{
        source_line = $sourceLine
        section_text = $sectionText
        section_number = Convert-ChineseNumber $sectionText
        title = $title
        noise_flags = Get-NoiseFlags $line $title
    }
}

function Get-SequenceStatus([object]$current, [object]$previous) {
    if ($null -eq $previous) {
        return 'run_start'
    }
    if ($current.section_number -eq ($previous.section_number + 1)) {
        return 'monotonic_next'
    }
    if ($current.section_number -eq $previous.section_number) {
        return 'duplicate_number'
    }
    if ($current.section_number -lt $previous.section_number) {
        return 'decrease_review_required'
    }
    return 'gap_review_required'
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$encoding = [Text.Encoding]::GetEncoding(936)
$sourceFullPath = (Resolve-Path -LiteralPath $SourcePath).Path
$sourceLines = [IO.File]::ReadAllLines($sourceFullPath, $encoding)
$rawRows = @(Import-Csv -LiteralPath $RawIndexPath -Encoding UTF8)

$candidates = [System.Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $sourceLines.Count; $index++) {
    $candidate = Get-HeadingCandidate $sourceLines[$index] ($index + 1)
    if ($null -ne $candidate) {
        $candidates.Add($candidate)
    }
}

$rawLineSet = @{}
foreach ($row in $rawRows) {
    $rawLineSet[[int]$row.line] = $true
}

$sequenceRun = 0
$previous = $null
$normalized = [System.Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $candidates.Count; $index++) {
    $candidate = $candidates[$index]
    $status = Get-SequenceStatus $candidate $previous
    if ($null -eq $previous -or $status -in @('decrease_review_required', 'gap_review_required')) {
        $sequenceRun++
    }

    $flags = @()
    if (-not [string]::IsNullOrWhiteSpace($candidate.noise_flags)) {
        $flags = $candidate.noise_flags -split ';'
    }
    $reviewRequired = ($status -match 'review_required') -or ($status -eq 'duplicate_number') -or ($flags.Count -gt 0)
    $normalized.Add([pscustomobject]@{
            source_line = $candidate.source_line
            section_number = [int64]$candidate.section_number
            section_text = $candidate.section_text
            title = $candidate.title
            noise_flags = $candidate.noise_flags
            sequence_run = $sequenceRun
            sequence_status = $status
            duplicate_group = ''
            canonical_candidate = $false
            review_required = $reviewRequired
        })
    $previous = $candidate
}

$duplicateGroups = @($normalized | Group-Object section_number | Where-Object { $_.Count -gt 1 })
foreach ($group in $duplicateGroups) {
    $groupId = "section-$($group.Name)"
    foreach ($row in $group.Group) {
        $row.duplicate_group = $groupId
    }
}

$runs = @($normalized | Group-Object sequence_run)
foreach ($run in $runs) {
    $runRows = @($run.Group | Sort-Object source_line)
    $cleanRows = [System.Collections.Generic.List[object]]::new()
    $lastCleanNumber = $null

    foreach ($row in $runRows) {
        # A repeated heading does not erase the preceding clean sequence. Keep
        # it in the CSV for audit, but skip it while choosing one candidate.
        if ($row.sequence_status -eq 'duplicate_number') {
            continue
        }

        if ($row.review_required -or $row.sequence_status -notin @('run_start', 'monotonic_next')) {
            if ($cleanRows.Count -ge 3) {
                foreach ($cleanRow in $cleanRows) {
                    $cleanRow.canonical_candidate = $true
                }
            }
            $cleanRows = [System.Collections.Generic.List[object]]::new()
            $lastCleanNumber = $null
            continue
        }

        if ($null -eq $lastCleanNumber -or $row.section_number -eq ($lastCleanNumber + 1)) {
            $cleanRows.Add($row)
            $lastCleanNumber = $row.section_number
            continue
        }

        if ($cleanRows.Count -ge 3) {
            foreach ($cleanRow in $cleanRows) {
                $cleanRow.canonical_candidate = $true
            }
        }
        $cleanRows = [System.Collections.Generic.List[object]]::new()
        $cleanRows.Add($row)
        $lastCleanNumber = $row.section_number
    }

    if ($cleanRows.Count -ge 3) {
        foreach ($cleanRow in $cleanRows) {
            $cleanRow.canonical_candidate = $true
        }
    }
}

$normalizedPath = Join-Path $OutputDirectory 'chapter-headings-normalized.csv'
$summaryPath = Join-Path $OutputDirectory 'chapter-number-summary-normalized.csv'
$auditJsonPath = Join-Path $OutputDirectory 'source-audit.json'
$auditMarkdownPath = Join-Path $OutputDirectory 'source-audit.md'

$normalized | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $normalizedPath

$summary = [System.Collections.Generic.List[object]]::new()
foreach ($group in ($normalized | Group-Object section_number | Sort-Object { [int64]$_.Name })) {
    $rows = @($group.Group | Sort-Object source_line)
    $summary.Add([pscustomobject]@{
            section_number = [int64]$group.Name
            occurrences = $rows.Count
            first_source_line = $rows[0].source_line
            last_source_line = $rows[-1].source_line
            titles = (($rows | ForEach-Object { $_.title } | Select-Object -Unique) -join ' | ')
            canonical_candidates = @($rows | Where-Object canonical_candidate).Count
            review_required = @($rows | Where-Object review_required).Count
        })
}
$summary | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $summaryPath

$runSummary = @($normalized | Group-Object sequence_run | ForEach-Object {
        $rows = @($_.Group | Sort-Object source_line)
        [pscustomobject]@{
            sequence_run = [int]$_.Name
            count = $rows.Count
            first_source_line = $rows[0].source_line
            last_source_line = $rows[-1].source_line
            first_section = $rows[0].section_number
            last_section = $rows[-1].section_number
            canonical_candidates = @($rows | Where-Object canonical_candidate).Count
            review_required = @($rows | Where-Object review_required).Count
        }
    })

$rawLineNumbers = @($rawRows | ForEach-Object { [int]$_.line })
$candidateLineNumbers = @($normalized | ForEach-Object { [int]$_.source_line })
$missingFromRaw = @($candidateLineNumbers | Where-Object { -not $rawLineSet.ContainsKey($_) })
$rawOnly = @($rawLineNumbers | Where-Object { $candidateLineNumbers -notcontains $_ })
$nonMonotonic = @($normalized | Where-Object { $_.sequence_status -match 'review_required' })

$sourceInfo = Get-Item -LiteralPath $sourceFullPath
$sourceAudit = [ordered]@{
    source_path = [IO.Path]::GetFullPath($sourceInfo.FullName)
    source_bytes = $sourceInfo.Length
    encoding = 'CP936 / GBK'
    source_line_count = $sourceLines.Count
    decoded_characters_without_newlines = (($sourceLines | ForEach-Object { $_.Length } | Measure-Object -Sum).Sum)
    user_stated_characters = 14577005
    raw_index_rows = $rawRows.Count
    parsed_heading_candidates = $normalized.Count
    duplicate_section_numbers = $duplicateGroups.Count
    sequence_runs = $runSummary.Count
    review_required_rows = @($normalized | Where-Object review_required).Count
    non_monotonic_or_gap_rows = $nonMonotonic.Count
    raw_index_lines_not_reparsed = $rawOnly.Count
    reparsed_lines_missing_from_raw_index = $missingFromRaw.Count
    generated_at = (Get-Date).ToString('s')
}
$sourceAudit | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -LiteralPath $auditJsonPath

$markdown = [System.Collections.Generic.List[string]]::new()
$markdown.Add('# Complete Source Index Audit')
$markdown.Add('')
$markdown.Add('This report audits and normalizes the index only. It does not modify or copy the complete source.')
$markdown.Add('')
$markdown.Add('## Source statistics')
$markdown.Add('')
$markdown.Add(('- Source path: `{0}`' -f $sourceAudit.source_path))
$markdown.Add(('- Encoding: {0}' -f $sourceAudit.encoding))
$markdown.Add(('- Bytes: {0}' -f $sourceAudit.source_bytes))
$markdown.Add(('- Lines: {0}' -f $sourceAudit.source_line_count))
$markdown.Add(('- Decoded characters excluding newlines: {0}' -f $sourceAudit.decoded_characters_without_newlines))
$markdown.Add(('- User-stated character count: {0}' -f $sourceAudit.user_stated_characters))
$markdown.Add(('- Existing raw index rows: {0}' -f $sourceAudit.raw_index_rows))
$markdown.Add(('- Reparsed heading candidates: {0}' -f $sourceAudit.parsed_heading_candidates))
$markdown.Add(('- Duplicate section numbers: {0}' -f $sourceAudit.duplicate_section_numbers))
$markdown.Add(('- Sequence runs: {0}' -f $sourceAudit.sequence_runs))
$markdown.Add(('- Rows requiring review: {0}' -f $sourceAudit.review_required_rows))
$markdown.Add('')
$markdown.Add('## Rules')
$markdown.Add('')
$markdown.Add('- Keep every recognizable section-heading candidate; never delete a duplicate silently.')
$markdown.Add('- Mark site, author, page, and directory candidates in noise_flags instead of treating them as clean story facts.')
$markdown.Add('- Mark only a clean, strictly increasing run of at least three candidates as canonical_candidate=true.')
$markdown.Add('- Keep duplicates, gaps, decreases, and noisy rows as review_required=true until an editor approves a source range.')
$markdown.Add('')
$markdown.Add('## Sequence runs')
$markdown.Add('')
$markdown.Add('| Run | Count | First line | Last line | First section | Last section | Canonical candidates | Review rows |')
$markdown.Add('| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |')
foreach ($run in $runSummary) {
    $markdown.Add((
        '| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |' -f
        $run.sequence_run,
        $run.count,
        $run.first_source_line,
        $run.last_source_line,
        $run.first_section,
        $run.last_section,
        $run.canonical_candidates,
        $run.review_required
    ))
}
$markdown.Add('')
$markdown.Add('## Raw index comparison')
$markdown.Add('')
$markdown.Add(('- Reparsed lines absent from the existing raw index: {0}' -f $missingFromRaw.Count))
$markdown.Add(('- Existing raw-index lines not reparsed by this script: {0}' -f $rawOnly.Count))
$markdown.Add('')
$markdown.Add('## Manual review boundary')
$markdown.Add('')
$markdown.Add('- canonical_candidate=true is a candidate only, not a final volume or arc boundary.')
$markdown.Add('- Later outlines may cite only source ranges that have been manually approved from source context.')
$markdown.Add('- Computed source statistics and the user-stated character count are kept as separate values.')
$markdown -join [Environment]::NewLine | Set-Content -Encoding UTF8 -LiteralPath $auditMarkdownPath

Write-Output ($sourceAudit | ConvertTo-Json -Depth 5)
