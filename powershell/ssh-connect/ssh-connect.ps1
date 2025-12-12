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

    # Category: "# [prod]"
    if ($line -match "^#\s*\[(.+?)\]") {
        $currentCategory = $matches[1]
        return
    }

    # skip comments
    if ($line.StartsWith("#")) {
        return
    }

    # Host definition
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

# --- Menu ---
Write-Host ""
Write-Host "Avaliable SSH connections:" -ForegroundColor Cyan
Write-Host "---------------------"

$index = 1
$indexMap = @{}

$entries | Group-Object Category | ForEach-Object {
    Write-Host ""
    Write-Host ("[{0}]" -f $_.Name) -ForegroundColor Yellow

    foreach ($item in $_.Group) {
        Write-Host ("  [{0}] {1}" -f $index, $item.Name)
        $indexMap[$index] = $item.Name
        $index++
    }
}

Write-Host ""
$choice = Read-Host "Enter number of host to connect to (or Enter for cancel)"

if ([string]::IsNullOrWhiteSpace($choice)) {
    Write-Host "Canceling."
    exit 0
}

if (-not ($choice -as [int])) {
    Write-Host "Invalide choice (non existing index)." -ForegroundColor Red
    exit 1
}

$choice = [int]$choice

if (-not $indexMap.ContainsKey($choice)) {
    Write-Host "Invalide choice (index out of range)." -ForegroundColor Red
    exit 1
}

$selectedHost = $indexMap[$choice]

Write-Host ""
Write-Host "Connecting to '$selectedHost'..." -ForegroundColor Green
Write-Host ""

ssh $selectedHost

