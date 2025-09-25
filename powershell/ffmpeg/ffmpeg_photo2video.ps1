<#
Create GIF/MP4 from JPGs using ffmpeg.

Params:
  -path         : Input folder (required)
  -outputPath   : Output directory; default = same as -path
  -type         : "mp4" (default) or "gif"
  -fps          : Frames per second (default 15)
  -loop         : Palindrome sequence (1,2,3,2,1)
  -resolution   : "original" or positive integer (long-edge, aspect preserved)
  -repeat       : Duplicate whole (already looped) sequence N additional times
  -ffmpegPath   : Optional absolute path to ffmpeg.exe

Output filename is always "output" with the appropriate extension (.mp4 or .gif).
All console messages are in English.
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$path,

  [string]$outputPath,

  [ValidateSet('mp4','gif')]
  [string]$type = 'mp4',

  [int]$fps = 15,
  [bool]$loop = $false,
  [string]$resolution = "original",
  [int]$repeat = 0,
  [string]$ffmpegPath
)

Write-Host "[info] Starting build..." -ForegroundColor Cyan

# --- Resolve ffmpeg executable ---
$ffmpegExe = $null
if ($ffmpegPath) {
  if (-not (Test-Path -LiteralPath $ffmpegPath -PathType Leaf)) {
    Write-Error "[error] Provided ffmpegPath does not exist: $ffmpegPath"
    exit 1
  }
  $ffmpegExe = $ffmpegPath
} else {
  $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Error "[error] ffmpeg was not found in PATH. Provide -ffmpegPath or install ffmpeg."
    exit 1
  }
  $ffmpegExe = $cmd.Path
}

# --- Input folder check ---
if (-not (Test-Path -LiteralPath $path -PathType Container)) {
  Write-Error "[error] Input path does not exist or is not a directory: $path"
  exit 1
}

# --- Output directory default ---
if (-not $outputPath) {
  $outputPath = $path
}
if (-not (Test-Path -LiteralPath $outputPath)) {
  New-Item -ItemType Directory -Path $outputPath | Out-Null
}

# --- Collect JPGs (ASC by name) ---
$jpgs = Get-ChildItem -LiteralPath $path -File |
        Where-Object { $_.Extension -match '^\.(jpe?g)$' } |
        Sort-Object Name

if ($jpgs.Count -eq 0) {
  Write-Error "[error] No JPG/JPEG files found in: $path"
  exit 1
}
Write-Host "[info] Found $($jpgs.Count) image(s)." -ForegroundColor Cyan

# --- Build sequence (loop & repeat) ---
$sequence = [System.Collections.Generic.List[string]]::new()
$jpgs | ForEach-Object { $sequence.Add($_.FullName) }

if ($loop -and $sequence.Count -ge 2) {
  # Palindrome: A,B,C -> A,B,C,B,A ; A,B -> A,B,A
  if ($sequence.Count -gt 2) {
    $mid = $sequence[($sequence.Count-2)..1]  # second-to-last down to second
  } else {
    $mid = @($sequence[0])
  }
  foreach ($f in $mid) { $sequence.Add($f) }
  Write-Host "[info] Palindrome loop applied. Total frames after loop: $($sequence.Count)" -ForegroundColor Cyan
}

if ($repeat -gt 0) {
  $base = @($sequence)
  for ($i=1; $i -le $repeat; $i++) {
    foreach ($f in $base) { $sequence.Add($f) }
  }
  Write-Host "[info] Sequence repeated $repeat additional time(s). Total frames: $($sequence.Count)" -ForegroundColor Cyan
}

# --- FPS / concat list ---
if ($fps -le 0) {
  Write-Error "[error] FPS must be a positive integer."
  exit 1
}
$frameDuration = [math]::Round(1.0 / [double]$fps, 6)

$tempList = Join-Path $env:TEMP ("gif_list_{0}.txt" -f ([guid]::NewGuid().ToString("N")))
Write-Host "[info] Creating concat list at: $tempList" -ForegroundColor Cyan

$sb = New-Object System.Text.StringBuilder
for ($i = 0; $i -lt $sequence.Count; $i++) {
  $p = $sequence[$i].Replace("'", "''")
  [void]$sb.AppendLine("file '$p'")
  if ($i -lt $sequence.Count - 1) { [void]$sb.AppendLine("duration $frameDuration") }
}
if ($sequence.Count -gt 0) {
  $last = $sequence[-1].Replace("'", "''")
  [void]$sb.AppendLine("file '$last'")
}

# Write UTF-8 without BOM to avoid ï»¿file issue
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tempList, $sb.ToString(), $utf8NoBom)

# --- Video filter chain ---
$vf = "fps=$fps"
if ($resolution -ne "original") {
  if (-not ($resolution -as [int]) -or [int]$resolution -le 0) {
    Remove-Item -LiteralPath $tempList -ErrorAction SilentlyContinue
    Write-Error "[error] 'resolution' must be 'original' or a positive integer (long edge in pixels)."
    exit 1
  }
  $L = [int]$resolution
  $vf = "$vf,scale='if(gt(iw,ih),$L,-1)':'if(gt(ih,iw),$L,-1)':flags=lanczos"
}

# --- Output file (name is always 'output') ---
$ext = if ($type -eq 'gif') { '.gif' } else { '.mp4' }
$resolvedOutput = Join-Path -Path $outputPath -ChildPath ("output" + $ext)

# --- Build ffmpeg args by type ---
$ffArgs = @(
  "-y",
  "-f","concat",
  "-safe","0",
  "-i",$tempList
)

if ($type -eq 'gif') {
  # High-quality GIF with palette
  $vfGif = "$vf,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a"
  $ffArgs += @(
    "-vf",$vfGif,
    "-an",
    $resolvedOutput
  )
} else {
  # MP4 (H.264), yuv420p for compatibility, faststart for web
  $ffArgs += @(
    "-vf",$vf,
    "-an",
    "-c:v","libx264",
    "-pix_fmt","yuv420p",
    "-preset","medium",
    "-crf","19",
    "-movflags","+faststart",
    $resolvedOutput
  )
}

# --- Run ffmpeg ---
Write-Host "[info] Invoking ffmpeg..." -ForegroundColor Cyan
& $ffmpegExe @ffArgs
$exitCode = $LASTEXITCODE

Remove-Item -LiteralPath $tempList -ErrorAction SilentlyContinue

if ($exitCode -ne 0) {
  Write-Error "[error] ffmpeg failed with exit code $exitCode."
  exit $exitCode
}

Write-Host "[success] Created: $resolvedOutput" -ForegroundColor Green

<#
Examples:
# default MP4 into the same directory as input
.\ffmpeg_photo2video.ps1 -path "C:\images"

# GIF into explicit directory, 12 fps, palindrome, long edge 800, repeat twice
.\ffmpeg_photo2video.ps1 -path "C:\images" -outputPath "C:\out" -type gif -fps 12 -loop $true -resolution 800 -repeat 2

# Using a custom ffmpeg binary
.\ffmpeg_photo2video.ps1 -path "C:\images" -ffmpegPath "C:\tools\ffmpeg\bin\ffmpeg.exe"
#>

