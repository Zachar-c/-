param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$encoding = [Text.Encoding]::GetEncoding(936)
$lines = [IO.File]::ReadAllLines($SourcePath, $encoding)
$headingPattern = '^\s*(?:\u6B63\u6587\s*)?\u7B2C([\u96F6\u3007\u4E00\u4E8C\u4E24\u4E09\u56DB\u4E94\u516D\u4E03\u516B\u4E5D\u5341\u767E\u5343\u4E07\d]+)\u8282[\uFF1A:]\s*(.+?)\s*$'

function Convert-ChineseNumber([string]$value) {
    if ($value -match '^\d+$') { return [int]$value }

    $digits = @{
        38646 = 0; 12295 = 0; 19968 = 1; 20108 = 2; 20004 = 2; 19977 = 3
        22235 = 4; 20116 = 5; 20845 = 6; 19971 = 7; 20843 = 8; 20061 = 9
    }
    $units = @{ 21313 = 10; 30334 = 100; 21315 = 1000; 19975 = 10000 }

    $total = 0
    $section = 0
    $number = 0
    foreach ($character in $value.ToCharArray()) {
        $code = [int][char]$character
        if ($digits.ContainsKey($code)) {
            $number = $digits[$code]
            continue
        }
        if ($units.ContainsKey($code)) {
            $unit = $units[$code]
            if ($number -eq 0) { $number = 1 }
            if ($unit -eq 10000) {
                $section = ($section + $number) * $unit
                $total += $section
                $section = 0
            } else {
                $section += $number * $unit
            }
            $number = 0
        }
    }
    return $total + $section + $number
}

function Get-NoiseFlags([string]$line, [string]$title) {
    $text = "$line $title"
    $flags = [System.Collections.Generic.List[string]]::new()
    if ($text -match '\u76EE\u5F55|\u7AE0\u8282\u76EE\u5F55') { $flags.Add('directory') }
    if ($text -match '\u4F5C\u8005|\u4F5C\u5BB6|\u5377\u672B\u611F\u8A00|\u5B8C\u672C\u611F\u8A00|\u65B0\u4E66|\u66F4\u65B0|\u8BA2\u9605|\u6708\u7968|\u63A8\u8350\u7968|\u672A\u5B8C\u5F85\u7EED|\uFF08?\s*(?:ps|PS)\s*[:\uFF1A]') {
        $flags.Add('author_or_site')
    }
    if ($text -match 'www\.|http://|https://|\u624B\u673A\u7528\u6237|\u8BF7\u6536\u85CF|\u7CBE\u5F69\u9605\u8BFB|</?\w+[^>]*>') {
        $flags.Add('site_markup')
    }
    return ($flags -join ';')
}

$headingRecords = [System.Collections.Generic.List[object]]::new()
$allTextCharacters = 0L
$hanCharacters = 0L
$nonEmptyLines = 0L

for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]
    $allTextCharacters += $line.Length
    $hanCharacters += ([regex]::Matches($line, '[\u3400-\u4DBF\u4E00-\u9FFF]').Count)
    if (-not [string]::IsNullOrWhiteSpace($line)) { $nonEmptyLines++ }

    if ($line -match $headingPattern) {
        $headingRecords.Add([pscustomobject]@{
                heading_id = $headingRecords.Count + 1
                line = $index + 1
                number_text = $matches[1]
                number = Convert-ChineseNumber $matches[1]
                title = $matches[2].Trim()
                flags = Get-NoiseFlags $line $matches[2]
            })
    }
}

for ($index = 0; $index -lt $headingRecords.Count; $index++) {
    $record = $headingRecords[$index]
    $nextLine = if ($index + 1 -lt $headingRecords.Count) {
        $headingRecords[$index + 1].line
    } else {
        $lines.Count + 1
    }
    $start = $record.line
    $end = $nextLine - 1
    $contentCharacters = 0L
    $containsAuthorPs = $false
    for ($lineIndex = $start; $lineIndex -lt $nextLine -and $lineIndex -le $lines.Count; $lineIndex++) {
        $contentCharacters += $lines[$lineIndex - 1].Length
        if ($lines[$lineIndex - 1] -match '\uFF08?\s*(?:ps|PS)\s*[:\uFF1A]|\u4F5C\u8005|\u672A\u5B8C\u5F85\u7EED') {
            $containsAuthorPs = $true
        }
    }
    $record | Add-Member -NotePropertyName end_line -NotePropertyValue $end
    $record | Add-Member -NotePropertyName content_characters -NotePropertyValue $contentCharacters
    $record | Add-Member -NotePropertyName contains_author_ps -NotePropertyValue $containsAuthorPs
}

$titleGroups = $headingRecords | Group-Object title
foreach ($group in $titleGroups) {
    $isDuplicate = $group.Count -gt 1
    foreach ($record in $group.Group) {
        $record | Add-Member -NotePropertyName duplicate_title -NotePropertyValue $isDuplicate
    }
}

$metadata = [pscustomobject]@{
    source_path = [IO.Path]::GetFullPath($SourcePath)
    source_bytes = (Get-Item -LiteralPath $SourcePath).Length
    encoding = 'CP936 / GBK'
    line_count = $lines.Count
    non_empty_lines = $nonEmptyLines
    decoded_characters_without_newlines = $allTextCharacters
    han_characters = $hanCharacters
    user_stated_characters = 14577005
    heading_hits = $headingRecords.Count
    generated_at = (Get-Date).ToString('s')
}

$metadata | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $OutputDirectory 'source-metadata.json')
$headingRecords | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDirectory 'chapter-headings.csv')
$headingRecords | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $OutputDirectory 'chapter-headings.json')

$summary = [System.Collections.Generic.List[object]]::new()
foreach ($numberGroup in ($headingRecords | Group-Object number | Sort-Object { [int]$_.Name })) {
    $first = $numberGroup.Group | Sort-Object line | Select-Object -First 1
    $last = $numberGroup.Group | Sort-Object line | Select-Object -Last 1
    $summary.Add([pscustomobject]@{
            number = [int]$numberGroup.Name
            occurrences = $numberGroup.Count
            first_line = $first.line
            first_title = $first.title
            last_line = $last.line
        })
}
$summary | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDirectory 'chapter-number-summary.csv')

Write-Output ($metadata | ConvertTo-Json)
