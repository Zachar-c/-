param(
    [Parameter(Mandatory = $true)]
    [string[]]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$BookTitle = '《蛊真人》精编版',
    [string]$PartTitle = '第一部　魔性不改'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Escape-Xml([string]$Value) {
    if ($null -eq $Value) { return '' }
    return [System.Security.SecurityElement]::Escape($Value)
}

function Convert-ChineseNumber([string]$Value) {
    if ($Value -match '^\d+$') { return [int]$Value }

    $digits = @{
        '零' = 0; '〇' = 0; '一' = 1; '二' = 2; '两' = 2; '三' = 3; '四' = 4
        '五' = 5; '六' = 6; '七' = 7; '八' = 8; '九' = 9
    }
    $units = @{ '十' = 10; '百' = 100; '千' = 1000; '万' = 10000 }
    $total = 0
    $section = 0
    $number = 0

    foreach ($character in $Value.ToCharArray()) {
        $text = [string]$character
        if ($digits.ContainsKey($text)) {
            $number = $digits[$text]
            continue
        }
        if ($units.ContainsKey($text)) {
            $unit = $units[$text]
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

function Convert-ToSafeFileName([string]$Value) {
    $invalid = [IO.Path]::GetInvalidFileNameChars()
    $result = $Value
    foreach ($character in $invalid) {
        $result = $result.Replace([string]$character, '_')
    }
    return $result
}

function Add-ZipEntry {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$EntryName,
        [string]$Content,
        [System.IO.Compression.CompressionLevel]$CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    )
    $entry = $Archive.CreateEntry($EntryName, $CompressionLevel)
    $stream = $entry.Open()
    try {
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        try {
            $writer.Write($Content)
        } finally {
            $writer.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Add-TextEntry {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$EntryName,
        [string]$Content
    )
    Add-ZipEntry -Archive $Archive -EntryName $EntryName -Content $Content -CompressionLevel ([System.IO.Compression.CompressionLevel]::Optimal)
}

function Set-UInt16LE([byte[]]$Bytes, [int]$Offset, [int]$Value) {
    [Array]::Copy([BitConverter]::GetBytes([UInt16]$Value), 0, $Bytes, $Offset, 2)
}

function Set-UInt32LE([byte[]]$Bytes, [int]$Offset, [long]$Value) {
    [Array]::Copy([BitConverter]::GetBytes([UInt32]$Value), 0, $Bytes, $Offset, 4)
}

function Find-Signature([byte[]]$Bytes, [byte[]]$Signature, [int]$StartAt) {
    for ($index = $StartAt; $index -le $Bytes.Length - $Signature.Length; $index++) {
        $matched = $true
        for ($part = 0; $part -lt $Signature.Length; $part++) {
            if ($Bytes[$index + $part] -ne $Signature[$part]) {
                $matched = $false
                break
            }
        }
        if ($matched) { return $index }
    }
    return -1
}

function Repair-MimetypeEntry([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ([BitConverter]::ToUInt32($bytes, 0) -ne 0x04034B50) {
        throw 'The EPUB does not begin with a local file header.'
    }

    $method = [BitConverter]::ToUInt16($bytes, 8)
    $compressedSize = [BitConverter]::ToUInt32($bytes, 18)
    $uncompressedSize = [BitConverter]::ToUInt32($bytes, 22)
    $nameLength = [BitConverter]::ToUInt16($bytes, 26)
    $extraLength = [BitConverter]::ToUInt16($bytes, 28)
    $name = [Text.Encoding]::UTF8.GetString($bytes, 30, $nameLength)
    $dataOffset = 30 + $nameLength + $extraLength

    if ($name -ne 'mimetype' -or $method -ne 8) { return }
    if ($compressedSize -ne $uncompressedSize + 5 -or $bytes[$dataOffset] -ne 1) {
        throw 'The mimetype entry is not the expected uncompressed Deflate block.'
    }
    $storedLength = [BitConverter]::ToUInt16($bytes, $dataOffset + 1)
    $storedLengthInverse = [BitConverter]::ToUInt16($bytes, $dataOffset + 3)
    if ($storedLength -ne $uncompressedSize -or $storedLengthInverse -ne (0xFFFF - $storedLength)) {
        throw 'The mimetype Deflate block length is invalid.'
    }

    $centralSignature = [byte[]](0x50, 0x4B, 0x01, 0x02)
    $centralOffset = Find-Signature -Bytes $bytes -Signature $centralSignature -StartAt ($dataOffset + $compressedSize)
    if ($centralOffset -lt 0) { throw 'The EPUB central directory was not found.' }

    $endSignature = [byte[]](0x50, 0x4B, 0x05, 0x06)
    $endOffset = Find-Signature -Bytes $bytes -Signature $endSignature -StartAt $centralOffset
    if ($endOffset -lt 0) { throw 'The EPUB end-of-central-directory record was not found.' }

    $newBytes = New-Object byte[] ($bytes.Length - 5)
    [Array]::Copy($bytes, 0, $newBytes, 0, $dataOffset)
    [Array]::Copy($bytes, $dataOffset + 5, $newBytes, $dataOffset, $bytes.Length - ($dataOffset + 5))
    Set-UInt16LE -Bytes $newBytes -Offset 8 -Value 0
    Set-UInt32LE -Bytes $newBytes -Offset 18 -Value $uncompressedSize

    $newCentralOffset = $centralOffset - 5
    Set-UInt16LE -Bytes $newBytes -Offset ($newCentralOffset + 10) -Value 0
    Set-UInt32LE -Bytes $newBytes -Offset ($newCentralOffset + 20) -Value $uncompressedSize

    $centralEntryOffset = $newCentralOffset
    while ($centralEntryOffset -lt ($endOffset - 5) -and [BitConverter]::ToUInt32($newBytes, $centralEntryOffset) -eq 0x02014B50) {
        $centralNameLength = [BitConverter]::ToUInt16($newBytes, $centralEntryOffset + 28)
        $centralExtraLength = [BitConverter]::ToUInt16($newBytes, $centralEntryOffset + 30)
        $centralCommentLength = [BitConverter]::ToUInt16($newBytes, $centralEntryOffset + 32)
        $localHeaderOffset = [BitConverter]::ToUInt32($newBytes, $centralEntryOffset + 42)
        if ($localHeaderOffset -gt 0) {
            Set-UInt32LE -Bytes $newBytes -Offset ($centralEntryOffset + 42) -Value ($localHeaderOffset - 5)
        }
        $centralEntryOffset += 46 + $centralNameLength + $centralExtraLength + $centralCommentLength
    }
    if ($centralEntryOffset -ne ($endOffset - 5)) {
        throw 'The central directory entries could not be traversed safely.'
    }
    Set-UInt32LE -Bytes $newBytes -Offset (($endOffset - 5) + 16) -Value $newCentralOffset
    [IO.File]::WriteAllBytes($Path, $newBytes)
}

if ($SourcePath.Count -eq 0) {
    throw 'At least one source text file is required.'
}

foreach ($source in $SourcePath) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Source file not found: $source"
    }
}

$chapters = [System.Collections.Generic.List[object]]::new()
$headingPattern = '^第(?<number>[零〇一二两三四五六七八九十百千万\d]+)节[：:\s　]*(?<title>.+?)\s*$'

foreach ($source in $SourcePath) {
    $lines = [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $source).Path, [Text.UTF8Encoding]::new($false, $true))
    $sourceName = [IO.Path]::GetFileName($source)
    $rangeMatch = [regex]::Match($sourceName, 'sec(?<start>\d+)-(?<end>\d+)\.edited\.txt$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $rangeStart = if ($rangeMatch.Success) { [int]$rangeMatch.Groups['start'].Value } else { $null }
    $rangeEnd = if ($rangeMatch.Success) { [int]$rangeMatch.Groups['end'].Value } else { $null }
    $current = $null
    $content = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        if ($line -match $headingPattern) {
            $chapterNumber = Convert-ChineseNumber $matches['number']
            if ($null -ne $rangeEnd -and ($chapterNumber -lt $rangeStart -or $chapterNumber -gt $rangeEnd)) {
                if ($null -ne $current) {
                    $current.content = @($content)
                    $chapters.Add($current)
                }
                $current = $null
                break
            }
            if ($null -ne $current) {
                $current.content = @($content)
                $chapters.Add($current)
            }
            $current = [pscustomobject]@{
                number = $matches['number']
                title = $matches['title'].Trim()
                content = @()
            }
            $content = [System.Collections.Generic.List[string]]::new()
            continue
        }

        if ($null -ne $current) {
            $content.Add($line)
        }
    }

    if ($null -ne $current) {
        $current.content = @($content)
        $chapters.Add($current)
    }
}

if ($chapters.Count -eq 0) {
    throw 'No chapter headings were found in the source files.'
}

$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [IO.Path]::GetDirectoryName($outputFullPath)
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('gu-zhenren-epub-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$archive = $null
$fileStream = $null
try {
    $fileStream = [IO.File]::Open($outputFullPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $archive = [IO.Compression.ZipArchive]::new($fileStream, [IO.Compression.ZipArchiveMode]::Create, $false)

    Add-ZipEntry -Archive $archive -EntryName 'mimetype' -Content 'application/epub+zip' -CompressionLevel ([System.IO.Compression.CompressionLevel]::NoCompression)

    $containerXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'@
    Add-TextEntry -Archive $archive -EntryName 'META-INF/container.xml' -Content $containerXml

    $stylesheet = @'
@charset "UTF-8";
body {
  margin: 0 1em;
  padding: 0;
  font-family: serif;
  line-height: 1.85;
  text-align: justify;
  word-wrap: break-word;
}
h1 {
  margin: 2.5em 0 1.5em;
  font-size: 1.35em;
  text-align: center;
  font-weight: bold;
  line-height: 1.5;
}
.title-page {
  margin-top: 30vh;
  text-align: center;
}
.title-page h1 {
  margin: 0 0 1em;
  font-size: 1.8em;
}
.title-page p {
  text-align: center;
  text-indent: 0;
}
p {
  margin: 0 0 0.9em;
  text-indent: 2em;
}
.toc {
  margin: 2em 0;
  padding: 0;
  list-style: none;
}
.toc li {
  margin: 0.65em 0;
  text-indent: 0;
}
a {
  color: inherit;
  text-decoration: none;
}
'@
    Add-TextEntry -Archive $archive -EntryName 'OEBPS/style.css' -Content $stylesheet

    $titleXhtml = @"
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-CN" lang="zh-CN">
  <head>
    <title>$(Escape-Xml $BookTitle)</title>
    <link rel="stylesheet" type="text/css" href="style.css"/>
  </head>
  <body class="title-page">
    <h1>$(Escape-Xml $BookTitle)</h1>
    <p>$(Escape-Xml $PartTitle)</p>
    <p><a href="nav.xhtml">进入目录</a></p>
  </body>
</html>
"@
    Add-TextEntry -Archive $archive -EntryName 'OEBPS/title.xhtml' -Content $titleXhtml

    $chapterManifest = [System.Text.StringBuilder]::new()
    $chapterSpine = [System.Text.StringBuilder]::new()
    $navItems = [System.Text.StringBuilder]::new()
    $ncxItems = [System.Text.StringBuilder]::new()
    $chapterIndex = 0

    foreach ($chapter in $chapters) {
        $chapterIndex++
        $id = 'chapter-' + $chapterIndex.ToString('D3')
        $fileName = $id + '.xhtml'
        $chapterTitle = '第' + $chapter.number + '节　' + $chapter.title
        $paragraphs = [System.Text.StringBuilder]::new()

        foreach ($line in $chapter.content) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                [void]$paragraphs.Append('<p>')
                [void]$paragraphs.Append((Escape-Xml $line.Trim()))
                [void]$paragraphs.AppendLine('</p>')
            }
        }

        $chapterXhtml = @"
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-CN" lang="zh-CN">
  <head>
    <title>$(Escape-Xml $chapterTitle)</title>
    <link rel="stylesheet" type="text/css" href="style.css"/>
  </head>
  <body>
    <h1 id="$id">$(Escape-Xml $chapterTitle)</h1>
    $($paragraphs.ToString())
  </body>
</html>
"@
        Add-TextEntry -Archive $archive -EntryName ('OEBPS/' + $fileName) -Content $chapterXhtml

        [void]$chapterManifest.AppendLine("    <item id='$id' href='$fileName' media-type='application/xhtml+xml'/>")
        [void]$chapterSpine.AppendLine("    <itemref idref='$id'/>")
        [void]$navItems.AppendLine("      <li><a href='$fileName'>$(Escape-Xml $chapterTitle)</a></li>")
        $playOrder = $chapterIndex + 1
        [void]$ncxItems.AppendLine("    <navPoint id='navPoint-$chapterIndex' playOrder='$playOrder'><navLabel><text>$(Escape-Xml $chapterTitle)</text></navLabel><content src='$fileName'/></navPoint>")
    }

    $navXhtml = @"
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="zh-CN" lang="zh-CN">
  <head>
    <title>目录</title>
    <link rel="stylesheet" type="text/css" href="style.css"/>
  </head>
  <body>
    <h1>$(Escape-Xml $BookTitle)</h1>
    <p>$(Escape-Xml $PartTitle)</p>
    <nav epub:type="toc" id="toc">
      <ol class="toc">
        <li><a href="title.xhtml">封面</a></li>
$($navItems.ToString())      </ol>
    </nav>
  </body>
</html>
"@
    Add-TextEntry -Archive $archive -EntryName 'OEBPS/nav.xhtml' -Content $navXhtml

    $ncx = @"
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="gu-zhenren-vol1-sec001-020"/>
  </head>
  <docTitle><text>$(Escape-Xml $BookTitle)</text></docTitle>
  <navMap>
    <navPoint id="navPoint-title" playOrder="1"><navLabel><text>封面</text></navLabel><content src="title.xhtml"/></navPoint>
$($ncxItems.ToString())  </navMap>
</ncx>
"@
    Add-TextEntry -Archive $archive -EntryName 'OEBPS/toc.ncx' -Content $ncx

    $modified = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $manifest = @"
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id" xml:lang="zh-CN">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">gu-zhenren-vol1-sec001-020</dc:identifier>
    <dc:title>$(Escape-Xml $BookTitle)</dc:title>
    <dc:language>zh-CN</dc:language>
    <dc:creator>古月</dc:creator>
    <meta property="dcterms:modified">$modified</meta>
  </metadata>
  <manifest>
    <item id="title" href="title.xhtml" media-type="application/xhtml+xml"/>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="css" href="style.css" media-type="text/css"/>
$($chapterManifest.ToString())  </manifest>
  <spine toc="ncx">
    <itemref idref="title"/>
$($chapterSpine.ToString())  </spine>
</package>
"@
    Add-TextEntry -Archive $archive -EntryName 'OEBPS/content.opf' -Content $manifest
} finally {
    if ($null -ne $archive) { $archive.Dispose() }
    if ($null -ne $fileStream) { $fileStream.Dispose() }
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Repair-MimetypeEntry -Path $outputFullPath

Write-Output "Created: $outputFullPath"
Write-Output "Chapters: $($chapters.Count)"
