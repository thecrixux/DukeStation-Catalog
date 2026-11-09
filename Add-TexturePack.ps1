<#
.SYNOPSIS
  Adds (or updates) a texture pack entry in textures-catalog.json.

.DESCRIPTION
  The app only needs a direct HTTPS link to a ZIP plus its exact size and SHA-256. This script measures both
  from the ZIP itself, counts the texture files inside it and writes the entry, so the JSON never has to be
  edited by hand. Running it again with the same -Id replaces that entry.

.EXAMPLE
  .\Add-TexturePack.ps1 -Id sotn-hd -Name "Symphony of the Night HD" -GameTitle "Castlevania: Symphony of the Night" `
      -Serials SLUS-00067 -Version 1.0 -Authors "Author name" `
      -Url https://github.com/author/repo/releases/download/v1.0/pack.zip `
      -SourceUrl https://github.com/author/repo -License "CC BY-NC 4.0"

.EXAMPLE
  # The ZIP is already on disk (for instance a file you are about to upload): measure it locally, publish the URL.
  .\Add-TexturePack.ps1 -Id my-pack -Name "My pack" -GameTitle "Some Game" -Serials SLUS-00001 -Version 1.0 `
      -Authors Me -Url https://example.com/my-pack.zip -SourceUrl https://example.com -File .\my-pack.zip
#>
param(
    [Parameter(Mandatory)][string]$Id,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$GameTitle,
    [Parameter(Mandatory)][string[]]$Serials,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string[]]$Authors,
    [Parameter(Mandatory)][string]$Url,
    [Parameter(Mandatory)][string]$SourceUrl,
    [string]$File,
    [string]$License = '',
    [string]$Credits = '',
    [string]$Description = '',
    [string[]]$PreviewUrls = @(),
    [string]$Catalog
)

$ErrorActionPreference = 'Stop'
# $PSScriptRoot is not available yet inside the param block on Windows PowerShell 5.1.
if (-not $Catalog) { $Catalog = Join-Path $PSScriptRoot 'textures-catalog.json' }
Add-Type -AssemblyName System.IO.Compression.FileSystem

$maxPartBytes = 2GB
$maxArchiveBytes = 16GB

foreach ($link in @($Url, $SourceUrl) + $PreviewUrls) {
    if ($link -notmatch '^https://[^\s/]+') { throw "Only HTTPS links are allowed: $link" }
}
if ($Id -notmatch '^[A-Za-z0-9._-]+$') { throw "-Id may only contain letters, digits, dot, dash and underscore." }

$normalizedSerials = @($Serials | ForEach-Object {
    $compact = ($_ -replace '[-_\s]', '').ToUpperInvariant()
    if ($compact -notmatch '^[A-Z]{4}[0-9]{5}$') { throw "Not a PS1 serial (expected something like SLUS-00067): $_" }
    $compact.Substring(0, 4) + '-' + $compact.Substring(4)
} | Select-Object -Unique)

$temporary = $null
try {
    if ($File) {
        $archive = (Resolve-Path -LiteralPath $File).Path
    } else {
        $temporary = Join-Path ([IO.Path]::GetTempPath()) ("catalog-pack-" + [guid]::NewGuid() + ".zip")
        Write-Host "Downloading $Url ..."
        Invoke-WebRequest -Uri $Url -OutFile $temporary -UseBasicParsing
        $archive = $temporary
    }

    $size = (Get-Item -LiteralPath $archive).Length
    if ($size -lt 1) { throw "The file is empty." }
    if ($size -gt $maxArchiveBytes) { throw "The app accepts archives up to 16 GB." }
    if ($size -gt $maxPartBytes) {
        throw "This archive is larger than 2 GB. Split it in parts of at most 2 GB and list them under 'parts' in the JSON by hand."
    }
    $sha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToUpperInvariant()

    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $fileCount = @($zip.Entries | Where-Object { $_.Name -match '\.(png|jpe?g|tga|bmp)$' }).Count
    } finally {
        $zip.Dispose()
    }
    if ($fileCount -lt 1) { throw "The ZIP has no PNG, JPG, TGA or BMP files, so the app could not install anything from it." }

    $entry = [ordered]@{
        id          = $Id
        name        = $Name
        gameTitle   = $GameTitle
        serials     = $normalizedSerials
        version     = $Version
        authors     = @($Authors)
        credits     = $Credits
        description = $Description
        downloadUrl = $Url
        sourceUrl   = $SourceUrl
        license     = $License
        sizeBytes   = $size
        sha256      = $sha256
        fileCount   = $fileCount
        previewUrls = @($PreviewUrls)
    }

    $entries = @()
    if (Test-Path -LiteralPath $Catalog) {
        $existing = Get-Content -LiteralPath $Catalog -Raw -Encoding UTF8 | ConvertFrom-Json
        $entries = @($existing.entries | Where-Object { $_.id -ne $Id })
    }
    $entries = @($entries) + [pscustomobject]$entry
    $entries = @($entries | Sort-Object gameTitle, name)

    $json = [ordered]@{ schemaVersion = 1; entries = $entries } | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($Catalog, $json + "`n", (New-Object Text.UTF8Encoding($false)))

    Write-Host ""
    Write-Host "Added '$Name' for $($normalizedSerials -join ', ')"
    Write-Host ("  size   : {0:N0} bytes" -f $size)
    Write-Host "  sha256 : $sha256"
    Write-Host "  files  : $fileCount"
    Write-Host "  catalog: $Catalog ($($entries.Count) entries)"
} finally {
    if ($temporary -and (Test-Path -LiteralPath $temporary)) { Remove-Item -LiteralPath $temporary -Force }
}
