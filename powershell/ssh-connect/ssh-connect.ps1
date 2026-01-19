# ssh-connect.ps1
# SSH menu with category support defined in ~/.ssh/config with help of commentary "# [category]"

$sshConfigPath = Join-Path $HOME ".ssh\config"

if (-not (Test-Path $sshConfigPath)) {
    Write-Host "Soubor $sshConfigPath neexistuje." -ForegroundColor Red
    exit 1
}

$entries = @()
$currentCategory = "default"

Get-Content $sshConfigPath | ForEach-Object {
    $line = $_.Trim()

    if ([string]::IsNullOrWhiteSpace($line)) {
        return
    }

    if ($line -match "^#\s*\[(.+?)\]") {
        $currentCategory = $matches[1]
        return
    }

    if ($line.StartsWith("#")) {
        return
    }

    if ($line -like "Host *") {
        $parts = $line -split "\s+" | Select-Object -Skip 1

        foreach ($h in $parts) {
            if ($h -notmatch "[*?]") {
                $entries += [PSCustomObject]@{
                    Name     = $h
                    Category = $currentCategory
                }
            }
        }
    }
}

if ($entries.Count -eq 0) {
    Write-Host "There is no hosts entries found in $sshConfigPath " -ForegroundColor Yellow
    exit 0
}

function Read-MenuInput {
    param(
        [hashtable]$Map,
        [switch]$AllowBack
    )

    $buffer = ""

    while ($true) {
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {

            'Escape' {
                Write-Host "`nExit."
                exit 0
            }

            'Enter' {
                if ($buffer -match '^\d+$') {
                    $num = [int]$buffer
                    if ($Map.ContainsKey($num)) {
                        Write-Host ""
                        return $num
                    }
                }
            }

            'Backspace' {
                if ($buffer.Length -gt 0) {
                    $buffer = $buffer.Substring(0, $buffer.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
                elseif ($AllowBack) {
                    Write-Host ""
                    return "__BACK__"
                }
            }

            default {
                if ($key.KeyChar -match '\d') {
                    $buffer += $key.KeyChar
                    Write-Host $key.KeyChar -NoNewline
                }
            }
        }
    }
}

while ($true) {

    Clear-Host
    Write-Host ""
    Write-Host "Avaliable SSH connections (categories):" -ForegroundColor Cyan
    Write-Host "--------------------------------------"

    $catIndex = 1
    $catMap = @{}

    ($entries | Group-Object Category) | ForEach-Object {
        Write-Host ("  [{0}] {1}" -f $catIndex, $_.Name) -ForegroundColor Yellow
        $catMap[$catIndex] = $_.Name
        $catIndex++
    }

    Write-Host ""
    Write-Host "Select category number (Enter=confirm, Esc=exit): " -NoNewline

    $catChoice = Read-MenuInput -Map $catMap
    $selectedCategory = $catMap[$catChoice]

    while ($true) {

        Clear-Host
        Write-Host ""
        Write-Host ("Category: [{0}]" -f $selectedCategory) -ForegroundColor Yellow
        Write-Host "Avaliable SSH connections:" -ForegroundColor Cyan
        Write-Host "---------------------"

        $index = 1
        $indexMap = @{}

        $entries | Where-Object { $_.Category -eq $selectedCategory } | ForEach-Object {
            Write-Host ("  [{0}] {1}" -f $index, $_.Name)
            $indexMap[$index] = $_.Name
            $index++
        }

        Write-Host ""
        Write-Host "Select host (Enter=connect, Backspace=categories, Esc=exit): " -NoNewline

        $choice = Read-MenuInput -Map $indexMap -AllowBack

        if ($choice -eq "__BACK__") {
            break
        }

        $selectedHost = $indexMap[$choice]

        Write-Host ""
        Write-Host "Connecting to '$selectedHost'..." -ForegroundColor Green
        Write-Host ""

        ssh $selectedHost
        exit 0
    }
}
