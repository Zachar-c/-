param(
    [string]$Source = "volumes/01-魔性不改/vol1-sec181-199.edited.txt",
    [string]$Destination = "volumes/02-魔子出山/vol2-sec001.edited.txt"
)

$encoding = [System.Text.UTF8Encoding]::new($false)
$sourcePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Source))
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Destination))
$text = [System.IO.File]::ReadAllText($sourcePath, $encoding)
$marker = "第一节：黄龙江上竹筏倾"
$first = $text.IndexOf($marker, [System.StringComparison]::Ordinal)

if ($first -lt 0) {
    throw "Boundary marker not found: $marker"
}

$volumeOne = $text.Substring(0, $first).TrimEnd() + "`r`n"
$volumeTwo = $text.Substring($first)
$duplicate = "$marker`r`n`r`n$marker"
$volumeTwo = $volumeTwo.Replace($duplicate, $marker).TrimEnd() + "`r`n"

$destinationDirectory = Split-Path -Parent $destinationPath
[System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null

[System.IO.File]::WriteAllText($sourcePath, $volumeOne, $encoding)
[System.IO.File]::WriteAllText($destinationPath, $volumeTwo, $encoding)

[pscustomobject]@{
    VolumeOneCharacters = $volumeOne.Length
    VolumeTwoCharacters = $volumeTwo.Length
    BoundaryOccurrences = ([regex]::Matches($volumeTwo, [regex]::Escape($marker))).Count
    VolumeOneEndsCorrectly = $volumeOne.TrimEnd().EndsWith('“中洲？！”方正震惊得大叫。')
} | Format-List
