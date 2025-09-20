# -----------------------------------------------------------------------------
# 360_2_yt.ps1
#
# Part of the 'toolbelt' project: https://github.com/jjakub-cz/toolbelt.git
# Author: Jakub Jakeš
# License: MIT
#
# Merges .mp4/.mov videos from a given folder (ASC, natural sort), generates chapters (MM:SS),
# re-encodes to a YouTube-friendly MP4 with CFR (x264 or NVENC), and injects 360° metadata.
# - If the max width > 4096 px, the GPU branch uses HEVC (hevc_nvenc, tag hvc1).
# - CFR is enforced via -vf "fps=..." + -fps_mode cfr (stable PTS, no jitter/tearing).
# -----------------------------------------------------------------------------


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    # Quality (higher number = smaller file). CPU: x264 CRF; GPU: NVENC CQ (analogous).
    [int]$Crf = 19,

    # Optional: force a target FPS (otherwise inferred from inputs - takes the maximum, capped at 60).
    [double]$TargetFps = $null,

    # Use dedicated GPU (NVENC)? Default yes. When false ? CPU x264.
    [bool]$UseGPU = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Format-MMSS([double]$seconds) {
    if ($seconds -lt 0) { $seconds = 0 }
    $totalSec = [math]::Floor($seconds)
    $totalMin = [int]([math]::Floor($totalSec / 60))
    $sec      = [int]($totalSec % 60)
    return "{0:00}:{1:00}" -f $totalMin, $sec
}

# "Natural sort" key: pads numeric blocks with leading zeros to a fixed length => correct lexicographic ordering
function Get-NaturalKey([string]$s) {
    return ([regex]::Replace($s, '\d+', { param($m) $m.Value.PadLeft(10,'0') }))
}

function Get-FpsInfo([string]$rateStr) {
    if ([string]::IsNullOrWhiteSpace($rateStr) -or $rateStr -eq "0/0") {
        return @{ float = 0.0; rational = $null }
    }
    $parts = $rateStr -split '/'
    if ($parts.Count -eq 2) {
        $num = [double]$parts[0]
        $den = [double]$parts[1]
        if ($den -ne 0) { return @{ float = ($num / $den); rational = "$num/$den" } }
    }
    return @{ float = 0.0; rational = $null }
}

try {
    # --- Resolve & target directory ------------------------------------------------
    $Path = $Path.Trim()
    $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) { throw "The specified path is not a directory: $resolvedPath" }

    $targetDir = Join-Path -Path $resolvedPath -ChildPath '360-2-yt'
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -Path $resolvedPath -Name '360-2-yt' -ItemType Directory -Force | Out-Null
        Write-Host "Created folder: $targetDir"
    } else {
        Write-Host "Folder already exists: $targetDir"
    }

    # --- Find input files (ASC, natural sort) -------------------------------------
    $files = Get-ChildItem -LiteralPath $resolvedPath -File |
             Where-Object { $_.Extension -match '^\.(mp4|mov)$' -and $_.Length -gt 0 } |
             Sort-Object @{ Expression = { Get-NaturalKey $_.FullName } }, @{ Expression = { $_.FullName } }
    if (-not $files -or $files.Count -eq 0) { throw "No .mp4/.mov files found in the directory." }

    Write-Host "Files found: $($files.Count)"

    $ts           = Get-Date -Format "yyyyMMdd_HHmmss"
    $listPath     = Join-Path $targetDir "$ts`_inputs.txt"
    $outputPath   = Join-Path $targetDir "$ts`_output.mp4"
    $chaptersPath = Join-Path $targetDir "$ts`_chapters.txt"

    # --- Concat list (UTF-8 without BOM for diacritics; no BOM so ffmpeg accepts it) ---
    $listLines = foreach ($f in $files) { "file '$($f.FullName.Replace("'","'\''"))'" }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($listPath, $listLines, $utf8NoBom)

    # --- Measure durations, FPS, and max resolution (robustly) --------------------
    $durations     = @()
    $labels        = @()
    $fpsFloats     = @()
    $fpsRationals  = @()
    $widths        = @()
    $heights       = @()

    foreach ($f in $files) {
        # duration
        $durStr = & ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- "$($f.FullName)"
        if (-not $durStr) { throw "ffprobe did not return duration for: $($f.FullName)" }
        $durations += [double]::Parse($durStr, [Globalization.CultureInfo]::InvariantCulture)
        $labels    += [IO.Path]::GetFileNameWithoutExtension($f.Name)

        # fps
        $fpsStr = & ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nw=1:nk=1 -- "$($f.FullName)"
        $fi = Get-FpsInfo $fpsStr
        $fpsFloats    += $fi.float
        $fpsRationals += $fi.rational

        # resolution (JSON -> PowerShell object)
        $whJson = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of json -- "$($f.FullName)"
        if ($whJson) {
            try {
                $obj = $whJson | ConvertFrom-Json
                if ($obj.streams -and $obj.streams.Count -ge 1) {
                    $w = [int]$obj.streams[0].width
                    $h = [int]$obj.streams[0].height
                    if ($w -gt 0 -and $h -gt 0) { $widths += $w; $heights += $h }
                }
            } catch { }
        }
    }


    # --- Target FPS (CFR) robust selection ----------------------------------------
    if ($TargetFps -and $TargetFps -gt 0) {
        $fpsFloat    = [double]$TargetFps
        $fpsRational = $null
    } else {
        $validFps = $fpsFloats | Where-Object { $_ -gt 0 }
        $fpsFloat = ($validFps | Measure-Object -Maximum).Maximum
        if (-not $fpsFloat) { $fpsFloat = 30.0 }
    }

    if ($fpsFloat -gt 60) { $fpsFloat = 60.0 }  # cap at 60
    $candidates = @(59.94, 60, 50, 30, 29.97, 25, 24)
    $nearest = $candidates | Sort-Object { [math]::Abs($_ - $fpsFloat) } | Select-Object -First 1
    $fpsFloat = $nearest
    switch ($nearest) {
        59.94 { $fpsRational = "60000/1001" }
        29.97 { $fpsRational = "30000/1001" }
        default { $fpsRational = [string]$nearest }
    }

    $gop = [int][math]::Max(1, [math]::Round(2 * $fpsFloat))

    # --- Chapters (MM:SS, cumulative real times) ----------------------------------
    $chapterLines = @()
    $cum = 0.0
    for ($i=0; $i -lt $labels.Count; $i++) {
        $chapterLines += "$(Format-MMSS $cum) $($labels[$i])"
        $cum += $durations[$i]
    }
    [System.IO.File]::WriteAllLines($chaptersPath, $chapterLines, $utf8NoBom)
    Write-Host "Chapters file: $chaptersPath"

    # --- Re-encode for YouTube (CFR via -vf fps=..., avoid using -r) ---------------
    Write-Host "Re-encoding for YouTube (CFR)..."

    if ($UseGPU) {
        # --- PRE-PASS: remux each clip to MKV with reset timestamps ----------------
        $prepDir = Join-Path $targetDir "concat_prep"
        if (-not (Test-Path -LiteralPath $prepDir)) {
            New-Item -ItemType Directory -Path $prepDir | Out-Null
        }

        $prepFiles = @()
        $idx = 0
        foreach ($f in $files) {
            $base = "{0:D4}_{1}.mkv" -f $idx, ([IO.Path]::GetFileNameWithoutExtension($f.Name))
            $outPrep = Join-Path $prepDir $base
            # lossless remux + reset timestamps
            & ffmpeg -hide_banner -y `
                -i "$($f.FullName)" `
                -map 0:v:0 -map 0:a? `
                -c copy -reset_timestamps 1 -fflags +genpts -avoid_negative_ts make_zero `
                -movflags +faststart `
                "$outPrep"
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outPrep)) {
                throw "Pre-pass remux failed for: $($f.FullName)"
            }
            $prepFiles += $outPrep
            $idx++
        }

        # overwrite concat list with pre-pass MKV files
        $listLines = foreach ($p in $prepFiles) { "file '$($p.Replace("'", "''"))'" }
        [System.IO.File]::WriteAllLines($listPath, $listLines, $utf8NoBom)
    
        # Check availability of NVENC encoders
        $encList = & ffmpeg -hide_banner -encoders 2>$null
        if (-not ($encList -match '.*(h264_nvenc|hevc_nvenc).*')) {
            throw "NVIDIA NVENC is not available in this ffmpeg build. Run with -UseGPU:`$false or install an ffmpeg build with NVENC."
        }

        & ffmpeg -hide_banner -y `
          -fflags +genpts -avoid_negative_ts make_zero `
          -f concat -safe 0 -i "$listPath" `
          -vf "fps=$fpsRational" -fps_mode cfr -vsync cfr `
          -c:v hevc_nvenc -preset p5 -tune hq `
          -rc vbr -multipass fullres -cq $Crf -b:v 0 -maxrate 0 -profile:v main `
          -g $gop -bf 3 `
          -pix_fmt yuv420p `
          -color_primaries bt709 -color_trc bt709 -colorspace bt709 `
          -c:a aac -b:a 320k -ar 48000 `
          -movflags +faststart `
          -tag:v hvc1 `
          "$outputPath"

    } else {
        # CPU x264 (quality path)
        Write-Host "CPU mode: x264 (libx264)."
        & ffmpeg -hide_banner -y -f concat -safe 0 -i "$listPath" `
            -vf "fps=$fpsRational" -fps_mode cfr `
            -c:v libx264 -preset slow -crf $Crf -pix_fmt yuv420p `
            -g $gop -bf 3 `
            -color_primaries bt709 -color_trc bt709 -colorspace bt709 `
            -c:a aac -b:a 320k -ar 48000 `
            -movflags +faststart `
            "$outputPath"
    }

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputPath)) {
        throw "ffmpeg re-encode failed."
    }
    Write-Host "Video ready: $outputPath"

    # --- Inject 360° XMP metadata via exiftool (in-place) --------------------------
    $exifArgs = @(
        '-overwrite_original',
        '-XMP-GSpherical:Spherical=true',
        '-XMP-GSpherical:Stitched=true',
        '-XMP-GSpherical:ProjectionType=equirectangular',
        '-XMP-GSpherical:StereoMode=mono',
        '-XMP-GSpherical:StitchingSoftware=insta360-joiner/ffmpeg',
        '-XMP-GSpherical:SourceCount=1',
        '-XMP-GSpherical:InitialViewHeadingDegrees=0',
        $outputPath
    )
    & exiftool @exifArgs
    if ($LASTEXITCODE -ne 0) { Write-Error "ExifTool 360° metadata injection failed."; exit 1 }
    Write-Host "360° metadata injected (EXIF/XMP)."

    Write-Host "Chapters: $chaptersPath"

    # After $outputPath (MP4) is successfully created, also create:
    $localPath = [IO.Path]::ChangeExtension($outputPath, ".mkv")
    & ffmpeg -hide_banner -y -i "$outputPath" -map 0 -c copy "$localPath"
    Write-Host "Local (VLC) copy: $localPath"

    # --- Clean up temporary pre-pass files (concat_prep) ---------------------------
    try {
        $prepDir = Join-Path $targetDir 'concat_prep'
        if (Test-Path -LiteralPath $prepDir) {
            Write-Host "Cleanup: deleting temporary directory $prepDir ..."
            # Remove potential ReadOnly/Hidden attributes to avoid deletion failures.
            Get-ChildItem -LiteralPath $prepDir -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try { $_.Attributes = 'Normal' } catch { }
            }
            Remove-Item -LiteralPath $prepDir -Recurse -Force -ErrorAction Stop
            Write-Host "Done: concat_prep deleted."
        } else {
            Write-Host "Nothing to clean (concat_prep not found)."
        }
    } catch {
        Write-Warning "Cleanup of concat_prep failed: $($_.Exception.Message)"
    }

} catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
