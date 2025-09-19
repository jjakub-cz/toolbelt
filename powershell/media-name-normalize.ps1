# -----------------------------------------------------------------------------
# media-name-normalize.ps1
#
# Part of the 'toolbelt' project: https://github.com/jjakub-cz/toolbelt.git
# Author: Jakub Jakeš
# License: MIT
#
# Prerequsities:
#   - ExifTool by Phil Harvey (https://exiftool.org/)
#   - Win path set for exif
#   - this script in same folder as exiftool.exe
#
# Tries to rename all media files in current directory to standardized output.
# Example output:
#   IMG8507.jpg -> 20240629_223487_IMG8507.jpg
#   VID8507.mov -> 20240629_223487_VID8507.mov
# -----------------------------------------------------------------------------

& exiftool.exe "-filename<CreateDate" -api QuickTimeUTC  -d "%Y%m%d_%H%M%S_%%f.%%e" .
