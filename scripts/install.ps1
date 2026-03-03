<#
.SYNOPSIS
    Downloads the latest WinWright MCP server binary from GitHub Releases.
.DESCRIPTION
    Fetches the latest win-x64 release zip from civyk-official/civyk-winwright,
    extracts it to the plugin bin/ directory, and verifies the binary runs.
.PARAMETER Version
    Specific version to install (e.g. "1.0.0-preview.1"). Defaults to latest.
.PARAMETER Arch
    Architecture: "x64" (default) or "arm64".
#>
param(
    [string]$Version = "",
    [ValidateSet("x64", "arm64")]
    [string]$Arch = "x64"
)

$ErrorActionPreference = "Stop"
$repo = "civyk-official/civyk-winwright"
$binDir = Join-Path (Join-Path $PSScriptRoot "..") "bin"

# Resolve version
if ($Version -eq "") {
    Write-Host "Fetching latest release..." -ForegroundColor Cyan
    $release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
    $Version = $release.tag_name -replace "^v", ""
} else {
    $release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/tags/v$Version"
}

$assetName = "winwright-$Version-win-$Arch.zip"
$asset = $release.assets | Where-Object { $_.name -eq $assetName }

if (-not $asset) {
    Write-Error "Asset '$assetName' not found in release v$Version. Available: $($release.assets.name -join ', ')"
    exit 1
}

# Download
$zipPath = Join-Path $env:TEMP $assetName
Write-Host "Downloading $assetName..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

# Extract
if (Test-Path $binDir) { Remove-Item $binDir -Recurse -Force }
New-Item -ItemType Directory -Path $binDir -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $binDir -Force
Remove-Item $zipPath

# Verify
$exe = Join-Path $binDir "Civyk.WinWright.Mcp.exe"
if (-not (Test-Path $exe)) {
    Write-Error "Binary not found after extraction: $exe"
    exit 1
}

$helpOutput = & $exe --help 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Binary verification failed."
    exit 1
}

Write-Host ""
Write-Host "WinWright v$Version ($Arch) installed successfully." -ForegroundColor Green
Write-Host "Binary: $exe" -ForegroundColor Gray
Write-Host ""
Write-Host "Usage:" -ForegroundColor Yellow
Write-Host "  Claude Code plugin:  /plugin install https://github.com/$repo"
Write-Host "  Manual stdio:        $exe mcp"
Write-Host "  Manual HTTP:         $exe serve --port 8765"
