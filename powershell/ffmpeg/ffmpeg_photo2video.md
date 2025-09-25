# `ffmpeg_photo2video.ps1`

Create an animation (MP4 or GIF) from a folder of JPG/JPEG images using **ffmpeg**.
Supports palindrome looping, repeating, FPS control, and long-edge scaling.

## Features

* Input: JPG/JPEG files in a directory (sorted ascending by filename).
* Output: `output.mp4` or `output.gif` in a target directory.
* Palindrome loop: `1,2,3` → `1,2,3,2,1`.
    * takes precedence over repeat, repeat goes second...
* Repeat: duplicates the entire (already looped) sequence by N additional times.
* Long-edge scaling: set a single dimension; aspect ratio preserved.

## Parameters

| Name          | Type             | Default         | Description                                     |
| ------------- | ---------------- | --------------- | ----------------------------------------------- |
| `-path`       | string (folder)  | **required**    | Input directory with JPG/JPEG files.            |
| `-outputPath` | string (folder)  | same as `-path` | Output directory for the final file.            |
| `-type`       | `mp4` | `gif`    | `mp4`           | Output format.                                  |
| `-fps`        | int              | `15`            | Frames per second (controls speed).             |
| `-loop`       | bool             | `false`         | Palindrome the sequence (A…Z…A).                |
| `-repeat`     | int              | `0`             | Repeat the whole sequence N additional times.   |
| `-resolution` | `original` | int | `original`      | Long-edge pixels; aspect preserved.             |
| `-ffmpegPath` | string (file)    | autodetect      | Absolute path to `ffmpeg.exe` (if not on PATH). |

## Prerequisites

* Windows PowerShell
* `ffmpeg` installed (on PATH or pass `-ffmpegPath`)

## Usage Examples

### Minimal (default MP4 into the input directory)

```powershell
.\ffmpeg_photo2video.ps1 -path "C:\Photos\Trip"
```

### GIF output, 12 FPS, looping

```powershell
.\ffmpeg_photo2video.ps1 -path "C:\Photos\Trip" -type gif -fps 12 -loop $true
```

### Save to a different output directory

```powershell
.\ffmpeg_photo2video.ps1 -path "C:\Photos\Trip" -outputPath "C:\Renders"
```

### Long-edge scaling to 1080 (aspect preserved)

```powershell
.\ffmpeg_photo2video.ps1 -path "C:\Photos\Trip" -resolution 1080
```

### Repeat the sequence twice

```powershell
.\ffmpeg_photo2video.ps1 -path "C:\Photos\Trip" -repeat 2
```

### Use a custom ffmpeg binary

```powershell
.\ffmpeg_photo2video.ps1 -path "C:\Photos\Trip" -ffmpegPath "C:\tools\ffmpeg\bin\ffmpeg.exe"
```

### Full example (all key options)

```powershell
.\ffmpeg_photo2video.ps1 `
  -path "C:\Photos\Trip" `
  -outputPath "C:\Renders" `
  -type mp4 `
  -fps 24 `
  -loop $true `
  -resolution 1080 `
  -repeat 2 `
  -ffmpegPath "C:\tools\ffmpeg\bin\ffmpeg.exe"
```

&nbsp;
---
&nbsp;
Notes
* For GIFs, the script uses palette generation & dithering for quality.
* The concat list is written as **UTF-8 without BOM** to avoid `ï»¿file` issues in ffmpeg.
